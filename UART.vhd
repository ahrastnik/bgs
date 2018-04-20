library IEEE;
use IEEE.numeric_std.all;
use IEEE.std_logic_1164.all;

entity UART is
	port(
		clk: in std_logic;
		rx, tx_send: in std_logic;
		tx: out std_logic := '1';
		irq_tx, irq_rx: out std_logic := '0';
		-- Data Bus
		data_i: in unsigned(7 downto 0);
		adr_i: in unsigned(5 downto 0);
		we_i: in std_logic;
		data_o: out unsigned(7 downto 0)
	);
end UART;

architecture Malibu of UART is
	component BUS_SLAVE
		generic(
			ADR_START	: integer;
			ADR_STOP		: integer
		);
		port(
			clk: in std_logic;
			-- Inputs
			we_i: in std_logic;
			adr_i: in unsigned(5 downto 0);
			data_i, data_read_i: in unsigned(7 downto 0);
			-- Outputs
			data_o: out unsigned(7 downto 0)
		);
	end component;
	
	signal TX_buf: unsigned(7 downto 0);
	signal RX_buf: unsigned(7 downto 0) := (others => '0');
	signal ucmp: unsigned(7 downto 0) := x"1A";-- Baudrate Compare
	signal uconta: unsigned(7 downto 0) := "11000000";-- UART Control: 7 -> Enable TX, 6 -> Enable RX, 5 -> Enable TX Empty Interrupt
	--, 4 -> Enable RX Full Interrupt, 3 -> RX samples 8/16, 2 ->, 1 ->, 0 ->
	signal ucontb: unsigned(7 downto 0) := "00100000";-- UART Control: 7:5 -> PreScaler, 4 -> 1 or 2 stop bits
	--, 3:2 -> Parity(00:Disabled, 01:Reserved, 10:Even, 11:Odd), 1:0 -> Data size(00:8 bits, 01:7 bits, 10:6 bits, 11:5 bits)
	signal ustat: unsigned(7 downto 0) := (others => '0');-- UART Status: 7 -> RX Received, 6 -> TX Sent, 5 ->, 4 ->, 3 ->, 2 ->, 1 -> Frame Error, 0 -> Parity Error
	signal cnts: unsigned(7 downto 0) := (others => '0');-- UART Bit Counters: 7:4 -> RX Bit Counter, 3:0 -> TX Bit Counter
	signal T, preScaler, baud_cnt, rx_sync_cnt: unsigned(7 downto 0) := (others => '0');
	signal clk_baud, clk_tx, clk_rx, rx_sync, rx_desync: std_logic := '0';-- TX Clock, RX Clock
	signal debug_value: std_logic;
	signal rx_data: unsigned(7 downto 0);
	-- Bus
	signal reg_data: unsigned(7 downto 0);
	-- States
	type uart_states is (idle, start, bits, bitParity, stop1, stop2);
	signal tx_st: uart_states;
	signal rx_st: uart_states := start;
	
	-- Calculate Parity
	function parity(vect: unsigned; odd: std_logic) return std_logic is
	
	variable tmp: std_logic := '0';
	begin
		for i in vect'range loop
--			prtl:if(vect(i) = '1') then
--				tmp := tmp xor vect(i);
--			end if prtl;
			tmp := tmp xor vect(i);
		end loop;
		-- Flip the parity bit if odd parity is measured
		if(odd = '1') then
			tmp := not tmp;
		end if;
		return tmp;
	end parity;
begin
	-- Bus
	BUS_S: BUS_SLAVE generic map(ADR_START => 24, ADR_STOP => 30)
		port map(clk => clk, we_i => we_i, adr_i => adr_i, data_i => data_i, data_read_i => reg_data, data_o => data_o);
		
	-- Read Register
	reg_data <= TX_buf when adr_i = 24 	else
					RX_buf when adr_i = 25 	else
					uconta when adr_i = 26 	else
					ucontb when adr_i = 27 	else
					ucmp when adr_i = 28 	else
					ustat when adr_i = 29 	else
					(others => '0');
	
	-- Oversampling Clock Generator
	baud_ov:process(clk)
	begin
	edg:if(rising_edge(clk)) then
		-- Clear Baud Clock
		clk_baud <= '0';
		wrt:if(we_i = '0') then
			-- Baudrate Clock Generator
			en:if(uconta(7) = '1' or uconta(6) = '1') then
				tm:if(T = ucmp) then
					c_tx:if(preScaler = ((x"01" sll to_integer(ucontb(7 downto 5))) - 1)) then
						preScaler <= (others => '0');
						-- Tick Oversampled Baud Clock
						clk_baud <= '1';
					else
						preScaler <= preScaler + 1;
					end if c_tx;
					
					T <= (others => '0');
				else
					T <= T + 1;
				end if tm;
			end if en;
		else
			-- Write Register
			case adr_i is
				when "011000" => -- 24
					TX_buf <= data_i;
				when "011010" => -- 26
					uconta <= data_i;
				when "011011" => -- 27
					ucontb <= data_i;
				when "011100" => -- 28
					ucmp <= data_i;
				when others =>
					null;
			end case;
		end if wrt;
	
	end if edg;
	end process baud_ov;
	
	-- Baud Clock Generator
	baud:process(clk_baud)
	begin
	edg:if(rising_edge(clk_baud)) then
		clk_tx <= '0';
		clk_rx <= '0';
		
		-- RX Clock Synchronization/Desynchronization
		sync:if(rx_st = start and rx = '0' and rx_sync = '0') then
			rx_sync <= '1';
			samp_sync:if(uconta(3) = '0') then
				rx_sync_cnt(2 downto 0) <= baud_cnt(2 downto 0) + 4;
			else
				rx_sync_cnt(3 downto 0) <= baud_cnt(3 downto 0) + 8;
			end if samp_sync;
		elsif(rx_st = start and rx_sync = '1' and clk_rx = '1') then
			rx_sync <= '0';
		end if sync;
		
		-- Tick TX Clock
		bd_ct:if((uconta(3) = '0' and baud_cnt = 7) or (uconta(3) = '1' and baud_cnt = 15)) then
			baud_cnt <= (others => '0');
			clk_tx <= '1';
		else
			baud_cnt <= baud_cnt + 1;
		end if bd_ct;
		
		-- Tick RX Clock
		rx_sn:if((baud_cnt = rx_sync_cnt and rx_sync = '1')) then
			clk_rx <= '1';
		end if rx_sn;
	end if edg;
	end process baud;
	
	-- TX
	tx_proc:process(clk_tx)
	begin
	edg:if(rising_edge(clk_tx)) then
		-- Clear output line
		tx <= '1';
		-- Clear Interrupt
		irq_tx <= '0';
		
		-- TX State Machine
		tx_en:if(uconta(7) = '1') then
			tx_c:case tx_st is
				when idle =>
					idl_tx:if(tx_send = '1') then
						tx_st <= start;
					end if idl_tx;
				when start =>
					-- Start Condition
					tx <= '0';
					tx_st <= bits;
				when bits =>
					bt:if(cnts(3 downto 0) = (7-to_integer(ucontb(1 downto 0)))) then
						-- Reset Counter and procede to stop or parity
						cnts(3 downto 0) <= (others => '0');
						par:if(ucontb(3) = '0') then
							-- Stop
							tx_st <= stop1;
						else
							-- Check Parity
							tx_st <= bitParity;
						end if par;
					else
						cnts(3 downto 0) <= cnts(3 downto 0) + 1;
					end if bt;
					-- Send a bit on the TX line
					tx <= TX_buf(to_integer(cnts(3 downto 0)));
				when bitParity =>
					-- Send parity bit on the TX line
					tx <= parity(TX_buf, ucontb(2));
					tx_st <= stop1;
				when stop1 =>
					-- Stop Condition
					if(ucontb(4) = '0') then
						ustat(6) <= '1';
						if(uconta(5) = '1') then
							irq_tx <= '1';
						end if;
						tx_st <= idle;
					else
						tx_st <= stop2;
					end if;
				when stop2 =>
					-- Second Stop Condition
					ustat(6) <= '1';
					if(uconta(5) = '1') then
						irq_tx <= '1';
					end if;
					tx_st <= idle;
			end case tx_c;
		end if tx_en;
	end if edg;
	end process tx_proc;
	
	-- RX
	rx_proc:process(clk_rx)
	begin
	edg:if(rising_edge(clk_rx)) then
		-- Clear Interrupt
		irq_rx <= '0';
		
		-- RX State Machine
		rx_en:if(uconta(6) = '1') then
			rx_c:case rx_st is
				when idle =>
					rx_st <= start;
				when start =>
					-- Communication Synchronized
					idl_rx:if(rx_sync = '1') then
						rx_st <= bits;
					end if idl_rx;
					
--					rx_st <= bits;
				when bits =>
					bt_rx:if(cnts(7 downto 4) = (7-to_integer(ucontb(1 downto 0)))) then
						-- Reset Counter and procede to stop or parity
						cnts(7 downto 4) <= (others => '0');
						par_rx:if(ucontb(3) = '0') then
							-- Stop
							rx_st <= stop1;
						else
							-- Check Parity
							rx_st <= bitParity;
						end if par_rx;
					else
						cnts(7 downto 4) <= cnts(7 downto 4) + 1;
					end if bt_rx;
					-- Receive a bit on the RX line
					RX_buf(to_integer(cnts(7 downto 4))) <= rx;
					-- Store RX data in a register so it can be checked by the Parity Control
					rx_data(to_integer(cnts(7 downto 4))) <= rx;
				when bitParity =>
					-- Check Parity
					ustat(0) <= parity(rx_data, ucontb(2));
					rx_st <= stop1;
				when stop1 =>
					-- Stop Condition
					fe:if(rx = '1') then
						st2:if(ucontb(4) = '0') then
							ustat(7) <= '1';
							-- Set Interrupt
							ir_rx:if(uconta(4) = '1') then
								irq_rx <= '1';
							end if ir_rx;
							-- Return to idle
							rx_st <= start;
						else
							rx_st <= stop2;
						end if st2;
					else
						ustat(1) <= '1';
						-- Return to idle
						rx_st <= start;
					end if fe;
				when stop2 =>
					-- Second Stop Condition
					fe2:if(rx = '1') then
						ustat(7) <= '1';
						-- Set Interrupt
						ir2_rx:if(uconta(4) = '1') then
							irq_rx <= '1';
						end if ir2_rx;
					else
						ustat(1) <= '1';
					end if fe2;
					-- Return to idle
					rx_st <= start;
			end case rx_c;
		end if rx_en;
	end if edg;
	end process rx_proc;
end Malibu;