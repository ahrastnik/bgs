library IEEE;
use IEEE.numeric_std.all;
use IEEE.std_logic_1164.all;
library work;
use work.INSTRUCTS.all;

entity INTERRUPT is
	port(
		clk, ire, isr, clr: in std_logic; -- Clock, Interrupts Enabled, Interrupt Serviced
		irqs: in unsigned(5 downto 0); -- Interrupt Requests
		irq: out std_logic := '0'; -- Interrupt Request
		irq_adr: out unsigned(7 downto 0) := x"FF" -- Interrupt Address
	);
end INTERRUPT;

architecture Malibu of INTERRUPT is
	subtype irq_vect is unsigned(7 downto 0);
	constant RESET: irq_vect := x"00";
	constant INT0: irq_vect := x"02";
	constant INT1: irq_vect := x"04";
	constant TIMER: irq_vect := x"06";
	
	signal last_irqs: unsigned(5 downto 0) := (others => '1');
begin
	-- Interrupts
	process(clk)
	begin
	main:if(rising_edge(clk)) then
		rq:if((irqs(5)='1' or irqs(4)='1' or irqs(3)='1' or irqs(2)='1' or irqs(1)='1' or irqs(0)='1') and (irqs < last_irqs) and isr = '0') then
			irq <= '1';
			last_irqs <= irqs;
			
			vec:if(irqs(0) = '1') then
				irq_adr <= RESET;
			else
				vec1:if(irqs(1) = '1') then
					irq_adr <= INT0;
				else
					vec2:if(irqs(2) = '1') then
						irq_adr <= INT1;
					else
						irq_adr <= TIMER;
					end if vec2;
				end if vec1;
			end if vec;
			
		elsif(isr = '1') then
			irq <= '0';
		end if rq;
		
		-- Clear Interrupt Address
		cl:if(clr = '1') then
			irq_adr <= x"FF";
			last_irqs <= (others => '1');
		end if cl;
	end if main;
	end process;
end Malibu;