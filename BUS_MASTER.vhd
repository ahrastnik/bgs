library IEEE;
use IEEE.numeric_std.all;
use IEEE.std_logic_1164.all;

entity BUS_MASTER is
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
end BUS_MASTER;

architecture Malibu of BUS_MASTER is
	-- Register Spaces
	type reg_spaces is (cpu, io, sram);
	signal space: reg_spaces;
begin
	-- Set Address Space
	space <= cpu when adr_i < IO_SPACE else
					io when adr_i >= IO_SPACE and adr_i < SRAM_SPACE else
					sram;
	
	-- Enable RAM if Selected
	ram_en <= '1' when space = sram else '0';
	-- Forward Register Address
	io_adr	<= adr_i(5 downto 0) when space = io else (others => '0');
	ram_adr	<= std_logic_vector(adr_i) when space = sram else (others => '0');
	-- Forward WE -> Write Enable
	io_we		<= we_i when space = io 	else '0';
	ram_we	<= we_i when space = sram 	else '0';
	-- Forward Data to CPU
	data_o <= io_data_i when space = io and we_i = '0' else
				unsigned(ram_data_i) when space = sram	and we_i = '0'	else
				(others => '0');
	-- Forward Data to RAM
	ram_data_o 	<= std_logic_vector(data_i) when space = sram and we_i = '1' else (others => '0');
	-- Forward Data to Peripherals
	io_data_o 	<= data_i when space = io and we_i = '1' else (others => '0');
	
end Malibu;