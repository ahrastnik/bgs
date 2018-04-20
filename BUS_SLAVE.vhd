library IEEE;
use IEEE.numeric_std.all;
use IEEE.std_logic_1164.all;

entity BUS_SLAVE is
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
end BUS_SLAVE;

architecture Malibu of BUS_SLAVE is
	signal adr_match: std_logic;
begin
	adr_match <= '1' when adr_i >= ADR_START and adr_i < ADR_STOP else '0';
	data_o <= (others => '0') when adr_match = '1' and we_i = '1' else
			data_read_i when adr_match = '1' and we_i = '0' else
			data_i;
end Malibu;