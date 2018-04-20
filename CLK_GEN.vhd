library IEEE;
use IEEE.numeric_std.all;
use IEEE.std_logic_1164.all;

entity CLK_GEN is
	port(
		clk: in std_logic;
		out_clk: out std_logic;
		cont: in unsigned(7 downto 0) := (others => '0');-- UART Control: 7 -> Clock Generator Enabled, 6 -> Enable Compare, 5 -> 
		--, 4 -> , 3:0 -> PreScaler
		cmp: in unsigned(7 downto 0) := (others => '0') -- Compare Value
	);
end CLK_GEN;

architecture Malibu of CLK_GEN is
	signal T, preScaler: unsigned(7 downto 0);
begin
	main:process(clk)
	begin
	edg:if(rising_edge(clk)) then
		out_clk <= '0';
		en:if(cont(7) = '1') then
			prs:if(preScaler = ((x"01" sll to_integer(cont(2 downto 0))) - 1)) then
				cmpr:if(T = (cmp - 1)) then
					T <= (others => '0');
					out_clk <= '1';
				else
					T <= T + 1;
				end if cmpr;
				preScaler <= (others => '0');
			else
				preScaler <= preScaler + 1;
			end if prs;
		end if en;
	end if edg;
	end process main;
end Malibu;