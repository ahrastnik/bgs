library IEEE;
use IEEE.numeric_std.all;
use IEEE.std_logic_1164.all;

entity NWI_108A1 is
	port(
		clk, rst: in std_logic;
		-- I/O
		pins: inout unsigned(7 downto 0)
		-- UART
		--tx: out std_logic;
		--rx: in std_logic
	);
end NWI_108A1;

architecture Malibu of NWI_108A1 is
	signal we: std_logic;
	signal ram_adr_o, data_out, ram_data: unsigned(7 downto 0);
	signal irqs: unsigned(5 downto 0) := (others => '0');
	
	-- ROM
	signal rom_adr_a, rom_adr_b: std_logic_vector(9 downto 0);
	signal rom_data_a, rom_data_b: std_logic_vector(7 downto 0);
	
	-- BUS MASTER
	signal adr: unsigned(9 downto 0);
	signal data_i, data_o: unsigned(7 downto 0);
	-- RAM BUS
	signal ram_data_i, ram_data_o: std_logic_vector(7 downto 0);
	signal ram_adr: std_logic_vector(9 downto 0);
	signal ram_en, ram_we: std_logic;
	-- IO BUS
	type bus_conn is array(0 to 3) of unsigned(7 downto 0);
	signal io_conn: bus_conn;
	signal io_adr: unsigned(5 downto 0);
	signal io_we: std_logic;

	component CPU
		port(
			clk, rst: in std_logic;
			we: out std_logic := '0';
			irqs: in unsigned(5 downto 0) := (others => '0');
			-- ROM
			rom_adr_a, rom_adr_b: out std_logic_vector(9 downto 0);
			rom_data_a, rom_data_b: in std_logic_vector(7 downto 0);
			-- BUS
			address: out unsigned(9 downto 0);
			data_o: 	out unsigned(7 downto 0);
			data_i: 	in unsigned(7 downto 0)
		);
	end component;
	
	component ROM
		port(
			clock: in std_logic;
			address_a, address_b: in std_logic_vector(9 downto 0);
			q_a, q_b: out std_logic_vector(7 downto 0)
		);
	end component;
	
	component RAM
		port(
			clock, clken, wren: in std_logic;
			data: in std_logic_vector(7 downto 0);
			q: out std_logic_vector(7 downto 0);
			address: in std_logic_vector(9 downto 0)
		);
	end component;
	
	component BUS_MASTER
		generic(
			IO_SPACE 	: integer;
			SRAM_SPACE 	: integer
		);
		port(
			clk: in std_logic;
			-- CPU Inputs
			we_i: 	in std_logic;
			adr_i: 	in unsigned(9 downto 0);
			data_i: 	in unsigned(7 downto 0);
			-- CPU Outputs
			data_o: out unsigned(7 downto 0);
			-- IO Inputs
			io_data_i: 	in unsigned(7 downto 0);
			-- IO Outputs
			io_we: 		out std_logic := '0';
			io_adr: 		out unsigned(5 downto 0);
			io_data_o: 	out unsigned(7 downto 0);
			-- RAM Outputs
			ram_en, ram_we: out std_logic := '0';
			ram_adr: 	out std_logic_vector(9 downto 0);
			ram_data_i: in std_logic_vector(7 downto 0);
			ram_data_o: out std_logic_vector(7 downto 0)
		);
	end component;
	
	component TIMER
		port(
			clk, rst: in std_logic;
			irq: out std_logic;
			-- Data Bus
			data_i: in unsigned(7 downto 0);
			adr_i: in unsigned(5 downto 0);
			we_i: in std_logic;
			data_o: out unsigned(7 downto 0)
		);
	end component;
	
	component UART
		port(
			clk: in std_logic;
			rx, tx_send: in std_logic;
			tx, irq_tx, irq_rx: out std_logic;
			-- Data Bus
			data_i: in unsigned(7 downto 0);
			adr_i: in unsigned(5 downto 0);
			we_i: in std_logic;
			data_o: out unsigned(7 downto 0)
		);
	end component;
	
	component IO_PORT
		port(
			clk: in std_logic;
			irqs: out unsigned(1 downto 0);
			pins: inout unsigned(7 downto 0);
			-- Data Bus
			data_i: in unsigned(7 downto 0);
			adr_i: in unsigned(5 downto 0);
			we_i: in std_logic;
			data_o: out unsigned(7 downto 0)
		);
	end component;
begin
	U_CPU: CPU port map(clk => clk, rst => rst, we => we, irqs => irqs,
		rom_adr_a => rom_adr_a, rom_adr_b => rom_adr_b, rom_data_a => rom_data_a, rom_data_b => rom_data_b,
		address => adr, data_i => data_o, data_o => data_i);
		
	FLASH: ROM port map(clock => clk, address_a => rom_adr_a, address_b => rom_adr_b, q_a => rom_data_a, q_b => rom_data_b);
	
	SRAM: RAM port map(clock => clk, wren => ram_we, clken => ram_en, address => ram_adr, data => ram_data_i, q => ram_data_o);
		
	BUS_M: BUS_MASTER generic map(IO_SPACE => 16, SRAM_SPACE => 64)
		port map(clk => clk, we_i => we, adr_i => adr, data_i => data_i, data_o => data_o,
		io_adr => io_adr, io_we => io_we, io_data_o => io_conn(0), io_data_i => io_conn(3),
		ram_adr => ram_adr, ram_data_i => ram_data_o, ram_data_o => ram_data_i, ram_en => ram_en, ram_we => ram_we);
		
	T0: TIMER port map(clk => clk, rst => rst, irq => irqs(3),
		data_o => io_conn(1), data_i => io_conn(0), adr_i => io_adr, we_i => io_we);
	
	UA0: UART port map(clk => clk, rx => '0', tx => open, irq_tx => irqs(5), irq_rx => irqs(4), tx_send => '1',
		data_o => io_conn(2), data_i => io_conn(1), adr_i => io_adr, we_i => io_we);
		
	BANK0: IO_PORT port map(clk => clk, irqs => irqs(2 downto 1), pins => pins,
		data_o => io_conn(3), data_i => io_conn(2), adr_i => io_adr, we_i => io_we);
	
	irqs(0) <= '0';-- rst
end Malibu;