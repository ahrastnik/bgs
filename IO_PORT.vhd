library IEEE;
use IEEE.numeric_std.all;
use IEEE.std_logic_1164.all;

entity IO_PORT is
	generic(
		BUS_WIDTH : integer
	);
	port(
		clk: in std_logic;
		irqs: out unsigned(1 downto 0) := (others => '0');
		pins: inout unsigned(7 downto 0);
		-- Data Bus
		data_i: in unsigned((BUS_WIDTH - 1) downto 0);
		adr_i: in unsigned(5 downto 0);
		we_i: in std_logic;
		data_o: out unsigned((BUS_WIDTH - 1) downto 0)
	);
end IO_PORT;

architecture Malibu of IO_PORT is
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
	
	-- Registers
	signal pin, dir, ire, ir_trg: unsigned((BUS_WIDTH - 1) downto 0) := (others => '0');
	
	-- Internal
	signal pin_buff: unsigned((BUS_WIDTH - 1) downto 0) := (others => '0');
	
	-- Bus
	signal reg_data: unsigned((BUS_WIDTH - 1) downto 0);
	
begin
	-- Bus
	BUS_S: BUS_SLAVE generic map(BUS_WIDTH => BUS_WIDTH, ADR_START => 36, ADR_STOP => 40)
		port map(clk => clk, we_i => we_i, adr_i => adr_i, data_i => data_i, data_read_i => reg_data, data_o => data_o);
		
	-- Read Register
	reg_data <= pin when adr_i = 36 else
			dir when adr_i = 37 else
			ire when adr_i = 38 else
			ir_trg when adr_i = 39 else
			(others => '0');
	
	-- Generate a tri-state buffer for all the pins
	tristate:for i in 0 to 7 generate
		pins(i) <= pin(i) when dir(i) = '0' else 'Z';
	end generate tristate;
	
	-- Main
	main:process(clk)
	begin
	edg:if(rising_edge(clk)) then
		-- Reset IRQs
		irqs(1 downto 0) <= "00";
		
		wrt:if(we_i = '0') then
			-- Interrupts
			pin_irq:for i in 0 to 1 loop
				if_in:if(dir(i) = '1') then
					pin_buff(i) <= pins(i);
					-- Check Edge Trigger
					if_irq:if(((pin_buff(i) = '0' and pins(i) = '1' and ir_trg(i) = '0') or (pin_buff(i) = '1' and pins(i) = '0' and ir_trg(i) = '1')) and ire(i) = '1') then 
						irqs(i) <= '1';
					end if if_irq;
					
				end if if_in;
			end loop pin_irq;
		else
			-- Write Register
			sel_wrt:case adr_i is
				when "100100" => -- 36
					pin <= data_i;
				when "100101" => -- 37
					dir <= data_i;
				when "100110" => -- 38
					ire <= data_i;
				when "100111" => -- 39
					ir_trg <= data_i;
				when others =>
					null;
			end case sel_wrt;
		end if wrt;
	end if edg;
	end process main;
end Malibu;