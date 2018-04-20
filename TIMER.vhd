library IEEE;
use IEEE.numeric_std.all;
use IEEE.std_logic_1164.all;

entity TIMER is
	generic(
		BUS_WIDTH	: integer;
		SIZE			: integer
	);
	port(
		clk, rst: in std_logic;
		irq: out std_logic := '0';
		-- Data Bus
		data_i: in unsigned((BUS_WIDTH - 1) downto 0);
		adr_i: in unsigned(5 downto 0);
		we_i: in std_logic;
		data_o: out unsigned((BUS_WIDTH - 1) downto 0)
	);
end TIMER;

architecture Malibu of TIMER is
	component BUS_SLAVE
		generic(
			BUS_WIDTH	: integer;
			ADR_START	: integer;
			ADR_STOP		: integer
		);
		port(
			clk: in std_logic;
			-- Inputs
			we_i: in std_logic;
			adr_i: in unsigned(5 downto 0);
			data_i, data_read_i: in unsigned((BUS_WIDTH - 1) downto 0);
			-- Outputs
			data_o: out unsigned((BUS_WIDTH - 1) downto 0)
		);
	end component;
	
	-- Timer
	signal tcon: unsigned((BUS_WIDTH - 1) downto 0) := (others => '0');-- Timer Control: 7 -> Timer Enabled, 6 -> Interrupt Enable, 5 -> COMPA Enable, 4 ->, 3 ->, 2:0 -> PreScaler
	signal cmpa, cmpb: unsigned((BUS_WIDTH - 1) downto 0) := (others => '0');-- Compare A, Compare B
	signal T, preScaler: unsigned((BUS_WIDTH - 1) downto 0) := (others => '0');-- Timer Counter, PreScaler Counter
	signal clk_ms: unsigned((BUS_WIDTH - 1) downto 0) := (others => '0');-- Test ms counter
	
	-- Bus
	signal reg_data: unsigned((BUS_WIDTH - 1) downto 0);
	
begin
	-- Bus
	BUS_S: BUS_SLAVE generic map(BUS_WIDTH => BUS_WIDTH, ADR_START => 16, ADR_STOP => 20)
		port map(clk => clk, we_i => we_i, adr_i => adr_i, data_i => data_i, data_read_i => reg_data, data_o => data_o);
		
	-- Read Register
	reg_data <= T when adr_i = 16 else
			tcon when adr_i = 17 else
			cmpa when adr_i = 18 else
			(others => '0');
	
	-- Main
	main:process(clk)
	begin
	edg:if(rising_edge(clk)) then
		irq <= '0';
		wrt:if(we_i = '0') then
--			rs:if(rst = '0') then
--				T <= (others => '0');
			rs:if(tcon(7) = '1') then
				prs:if(preScaler = ((x"01" sll to_integer(tcon(2 downto 0))) - 1)) then
					cmp:if(tcon(5) = '1' and (T = (cmpa - 1))) then
						T <= (others => '0');
						tirq:if(tcon(6) = '1') then
							irq <= '1';
						end if tirq;
						clk_ms <= clk_ms + 1;
					else
						T <= T + 1;
					end if cmp;
					preScaler <= (others => '0');
				else
					preScaler <= preScaler + 1;
				end if prs;
			end if rs;
		else
			-- Write Register
			case adr_i is
				when "010000" => -- 16
					T <= data_i;
				when "010001" => -- 17
					tcon <= data_i;
				when "010010" => -- 18
					cmpa <= data_i;
				when "010011" => -- 19
					null;
				when others =>
					null;
			end case;
		end if wrt;
	end if edg;
	end process main;
end Malibu;