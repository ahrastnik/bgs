library IEEE;
use IEEE.numeric_std.all;
use IEEE.std_logic_1164.all;
library work;
use work.INSTRUCTS.all;

entity ALU is
	generic(
		BUS_WIDTH: integer
	);
	port(
		clk, en: in std_logic;
		op, a, b: in unsigned((BUS_WIDTH - 1) downto 0) := (others => '0');
		result: out unsigned((BUS_WIDTH - 1) downto 0) := (others => '0');
		carry, zero, signd, overflow: out std_logic := '0'
	);
end ALU;

architecture Malibu of ALU is
	signal acu: unsigned(BUS_WIDTH downto 0) := (others => '0');
begin	
	-- Handle Arithmetic & Logical operations
	process(clk, en)
	begin
		if(rising_edge(clk) and en = '1') then
			case op(31 downto 24) is
				-- Arithmetic operations
				when add =>
					acu <= resize(a, BUS_WIDTH + 1) + b;
				when sbt =>
					acu <= resize(a, BUS_WIDTH + 1) - b;
				when mul =>
					acu <= resize(resize(a, BUS_WIDTH + 1) * b, BUS_WIDTH + 1);
				when div =>
					acu <= (others => '0'); -- TODO
				when idiv =>
					acu <= (others => '0'); -- TODO
				when inc =>
					acu <= resize(a, BUS_WIDTH + 1) + 1;
				when dec =>
					acu <= resize(a, BUS_WIDTH + 1) - 1;
					
				-- Logical operations
				when test =>
					acu <= (others => '0');
				when inot =>
					acu <= resize(not a, BUS_WIDTH + 1);
				when ineg =>
					acu <= resize((not a) + 1, BUS_WIDTH + 1);
				when iand =>
					acu <= resize(a and b, BUS_WIDTH + 1);
				when ior =>
					acu <= resize(a or b, BUS_WIDTH + 1);
				when ixor =>
					acu <= resize(a xor b, BUS_WIDTH + 1);
				when ishl =>
					acu <= shift_left(resize(a, BUS_WIDTH + 1), to_integer(b));
				when ishr =>
					acu <= shift_right(resize(a, BUS_WIDTH + 1), to_integer(b));
				when irol =>
					acu <= rotate_left(resize(a, BUS_WIDTH + 1), to_integer(b));
				when iror =>
					acu <= rotate_right(resize(a, BUS_WIDTH + 1), to_integer(b));
				when others =>
					null;
			end case;
		end if;
	end process;
	
	-- Set operation flags
	result <= acu((BUS_WIDTH - 1) downto 0);
	overflow <= (a(BUS_WIDTH - 1) and b(BUS_WIDTH - 1) and not acu(BUS_WIDTH - 1)) or (not a(BUS_WIDTH - 1) and not b(BUS_WIDTH - 1) and acu(BUS_WIDTH - 1));
	carry <= acu(BUS_WIDTH);
	signd <= acu(BUS_WIDTH - 1);
	zero <= '1' when acu = ('0' & x"00000000") else '0';
		
end Malibu;