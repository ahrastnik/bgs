library IEEE;
use IEEE.numeric_std.all;
use IEEE.std_logic_1164.all;

entity DMA is
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
end DMA;

architecture Malibu of DMA is
	-- Register Spaces
	type reg_spaces is (cpu, io, sram);
	signal space: reg_spaces;
	-- Operation modes
	type op_modes is (burst, cycle, transparent);
	signal mode: op_modes;
begin
	-- Set Address Space
	space <= cpu when adr_i < IO_SPACE else
				io when adr_i >= IO_SPACE and adr_i < SRAM_SPACE else
				sram;
				
	-- Handle Busy flag
	busy <= io_mem;
				
	-- Program Memory
	-- Forward memory address
	prog_adr_a_o <= std_logic_vector(prog_adr_a_i);
	prog_adr_b_o <= std_logic_vector(prog_adr_b_i);
	-- Forward data from program memory
	prog_a <= unsigned(prog_data_a_i) when io_mem = '0' else (others => '0');
	prog_b <= unsigned(prog_data_b_i) when io_mem = '0' else (others => '0');
	-- Enable Write on Program Memory if Peripheral Selected requested it
	prog_we_a <= io_mem; -- Only enable writing on port A
	prog_we_b <= '0'; -- Disable port B
	-- Write in Program Memory
	prog_data_o <= std_logic_vector(io_data_i) when io_mem = '1' else (others => '0');
	
	-- Data Memory
	-- Enable Data Memory if Selected
	data_en <= '1' when space = sram else '0';
	-- Forward Register Address
	io_adr	<= adr_i(5 downto 0) when space = io else (others => '0');
	data_adr	<= std_logic_vector(adr_i(DATA_WIDTH - 1 downto 0)) when space = sram else (others => '0');
	-- Forward WE -> Write Enable
	io_we		<= we_i when space = io 	else '0';
	data_we	<= we_i when space = sram 	else '0';
	-- Forward Data to CPU
	data_o <= io_data_i when space = io and we_i = '0' else
				unsigned(data_data_i) when space = sram	and we_i = '0'	else
				(others => '0');
	-- Forward Data to Data Memory
	data_data_o 	<= std_logic_vector(data_i) when space = sram and we_i = '1' else (others => '0');
	-- Forward Data to Peripherals
	io_data_o 	<= data_i when space = io and we_i = '1' else (others => '0');
	
end Malibu;