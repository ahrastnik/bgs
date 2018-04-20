library IEEE;
use IEEE.numeric_std.all;
use IEEE.std_logic_1164.all;

entity BGS is
	port(
		clk, rst: in std_logic;
		-- I/O
		pins: inout unsigned(7 downto 0)
		-- UART
		--tx: out std_logic;
		--rx: in std_logic
	);
end BGS;

architecture Malibu of BGS is
	-- Constants
	constant BUS_WIDTH: integer := 32;
	constant PROG_WIDTH: integer := 9;
	constant DATA_WIDTH: integer := 8;
	constant IO_WIDTH:	integer :=	6;
	
	-- CPU
	signal prog_adr_a, prog_adr_b: unsigned((PROG_WIDTH - 1) downto 0);
	signal prog_data_a, prog_data_b: unsigned((BUS_WIDTH - 1) downto 0);
	signal data_adr: unsigned((BUS_WIDTH - 1) downto 0);
	signal data_i, data_o: unsigned((BUS_WIDTH - 1) downto 0);
	signal we: std_logic;
	
	-- DMA
	-- IO bus
	signal io_we, io_mem: std_logic := '0';
	signal io_adr: unsigned(5 downto 0);
	type bus_conn is array(0 to 3) of unsigned((BUS_WIDTH - 1) downto 0);
	signal io_conn: bus_conn;
	-- Program Memory
	signal prog_we_a, prog_we_b: std_logic;
	signal prog_adr_a_o, prog_adr_b_o: std_logic_vector((PROG_WIDTH - 1) downto 0);
	signal prog_data_a_i, prog_data_b_i: std_logic_vector((BUS_WIDTH - 1) downto 0);
	signal prog_data_o: std_logic_vector((BUS_WIDTH - 1) downto 0);
	-- Data Memory
	signal data_en, data_we: std_logic;
	signal data_adr_o: std_logic_vector((DATA_WIDTH - 1) downto 0);
	signal data_data_i, data_data_o: std_logic_vector((BUS_WIDTH - 1) downto 0);
	
	component CPU
		generic(
			BUS_WIDTH: integer;
			PROG_WIDTH: integer;
			DATA_WIDTH: integer
		);
		port(
			clk, rst: in std_logic;
			-- Program Memory
			prog_adr_a, prog_adr_b: out unsigned((PROG_WIDTH - 1) downto 0);
			prog_data_a, prog_data_b: in unsigned((BUS_WIDTH - 1) downto 0);
			-- Data Memory
			data_adr: out unsigned((BUS_WIDTH - 1) downto 0);
			data_i: in unsigned((BUS_WIDTH - 1) downto 0);
			data_o: out unsigned((BUS_WIDTH - 1) downto 0);
			we: out std_logic := '0'
		);
	end component;
	
	component DMA
		generic(
			IO_SPACE 	: integer;
			SRAM_SPACE 	: integer;
			BUS_WIDTH	: integer;
			PROG_WIDTH	: integer;
			DATA_WIDTH	: integer
		);
		port(
			clk: in std_logic;
			-- CPU Inputs
			we_i: 	in std_logic;
			adr_i: 	in unsigned((BUS_WIDTH - 1) downto 0);
			prog_adr_a_i, prog_adr_b_i: 	in unsigned((PROG_WIDTH - 1) downto 0);
			data_i: 	in unsigned((BUS_WIDTH - 1) downto 0);
			-- CPU Outputs
			data_o: out unsigned((BUS_WIDTH - 1) downto 0);
			prog_a, prog_b: out unsigned((BUS_WIDTH - 1) downto 0);
			busy: out std_logic;
			-- IO Inputs
			io_data_i: 	in unsigned((BUS_WIDTH - 1) downto 0);
			io_mem: in std_logic := '0';
			-- IO Outputs
			io_we: 		out std_logic := '0';
			io_adr: 	out unsigned(5 downto 0);
			io_data_o: 	out unsigned((BUS_WIDTH - 1) downto 0);
			-- Program Memory
			prog_we_a, prog_we_b: out std_logic := '0';
			prog_adr_a_o, prog_adr_b_o: 	out std_logic_vector((PROG_WIDTH - 1) downto 0);
			prog_data_a_i, prog_data_b_i: in std_logic_vector((BUS_WIDTH - 1) downto 0);
			prog_data_o: out std_logic_vector((BUS_WIDTH - 1) downto 0);
			-- Data Memory
			data_en, data_we: out std_logic := '0';
			data_adr: 	out std_logic_vector((DATA_WIDTH - 1) downto 0);
			data_data_i: in std_logic_vector((BUS_WIDTH - 1) downto 0);
			data_data_o: out std_logic_vector((BUS_WIDTH - 1) downto 0)
		);
	end component;
	
	component MEM_PROG
		port(
			clock, wren_a, wren_b: in std_logic;
			data_a, data_b: in std_logic_vector((BUS_WIDTH - 1) downto 0);
			address_a, address_b: in std_logic_vector((PROG_WIDTH - 1) downto 0);
			q_a, q_b: out std_logic_vector((BUS_WIDTH - 1) downto 0)
		);
	end component;
	
	component MEM_DATA
		port(
			clock, clken, wren: in std_logic;
			data: in std_logic_vector((BUS_WIDTH - 1) downto 0);
			address: in std_logic_vector((DATA_WIDTH - 1) downto 0);
			q: out std_logic_vector((BUS_WIDTH - 1) downto 0)
		);
	end component;
	
	component TIMER
		generic(
			SIZE			: integer;
			BUS_WIDTH	: integer
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
	end component;
	
	component IO_PORT
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
	end component;
begin
	U_CPU: CPU generic map(BUS_WIDTH => BUS_WIDTH, PROG_WIDTH => PROG_WIDTH, DATA_WIDTH => DATA_WIDTH)
		port map(clk => clk, rst => rst, we => we,
		prog_adr_a => prog_adr_a, prog_adr_b => prog_adr_b, prog_data_a => prog_data_a, prog_data_b => prog_data_b,
		data_adr => data_adr, data_i => data_i, data_o => data_o);
		
	U_DMA: DMA generic map(IO_SPACE => 32, SRAM_SPACE => 128, BUS_WIDTH => BUS_WIDTH, PROG_WIDTH => PROG_WIDTH, DATA_WIDTH => DATA_WIDTH)
		port map(clk => clk, we_i => we, adr_i => data_adr, data_i => data_o, data_o => data_i,
			io_we => io_we, io_adr => io_adr, io_mem => io_mem, io_data_i => io_conn(2), io_data_o => io_conn(0),
			prog_we_a => prog_we_a, prog_we_b => prog_we_b, prog_adr_a_i => prog_adr_a, prog_adr_b_i => prog_adr_b, prog_adr_a_o => prog_adr_a_o, prog_adr_b_o => prog_adr_b_o,
			prog_a => prog_data_a, prog_b => prog_data_b, prog_data_a_i => prog_data_a_i, prog_data_b_i => prog_data_b_i, prog_data_o => prog_data_o,
			data_en => data_en, data_we => data_we, data_adr => data_adr_o, data_data_i => data_data_o, data_data_o => data_data_i);
			
	U_MEM_PROG: MEM_PROG port map(clock => clk, wren_a => prog_we_a, wren_b => prog_we_b,
			data_a => prog_data_o, data_b => prog_data_o, address_a => prog_adr_a_o, address_b => prog_adr_b_o,
			q_a => prog_data_a_i, q_b => prog_data_b_i);
			
	U_MEM_DATA: MEM_DATA port map(clock => clk, clken => data_en, wren => data_we,
			data => data_data_i, address => data_adr_o, q => data_data_o);
			
	U_T0: TIMER generic map(BUS_WIDTH => BUS_WIDTH, SIZE => 8)
		port map(clk => clk, rst => rst, irq => open, we_i => io_we, adr_i => io_adr, data_i => io_conn(0), data_o => io_conn(1));
	
	U_IO: IO_PORT generic map(BUS_WIDTH => BUS_WIDTH)
		port map(clk => clk, irqs => open, pins => pins, we_i => io_we, adr_i => io_adr, data_i => io_conn(1), data_o => io_conn(2));
end Malibu;