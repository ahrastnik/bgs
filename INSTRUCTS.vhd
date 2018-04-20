library IEEE;
use IEEE.numeric_std.all;
use IEEE.std_logic_1164.all;

package INSTRUCTS is
	subtype instruct is unsigned(7 downto 0);
	subtype sub_inst is unsigned(3 downto 0);
	--subtype reg is unsigned(3 downto 0);
	subtype len is unsigned(3 downto 0);
	-- Managment
	constant nop: instruct := 	x"00"; -- No OPeration
	constant mov: instruct := 	x"01"; -- Move register to another register or memory location
	constant lea: instruct :=	x"02"; -- Load effective address
	constant push:	instruct := x"03"; -- Push register on stack
	constant pop:	instruct := x"04"; -- Pop register from stack
	constant cmp: instruct :=	x"05"; -- Compare registers
	constant jmp: instruct := 	x"06"; -- jump to location
	constant call: instruct := x"07"; -- call function
	constant ret: instruct 	:= x"08"; -- Return from Function or Interrupt
	constant sti: instruct 	:= x"09"; -- Set global interrupts flag
	constant cli: instruct 	:= x"0A"; -- Clear global interrupts flag
	
	-- Conditional jumps
	constant je: sub_inst :=	x"1"; -- Jump if equal
	constant jne: sub_inst :=	x"2"; -- Jump if not equal
	constant jz: sub_inst :=	x"3"; -- Jump if zero
	constant jnz: sub_inst :=	x"4"; -- Jump if not equal
	constant jg: sub_inst :=	x"5"; -- Jump if greater
	constant jge: sub_inst :=	x"6"; -- Jump if greater or equal
	constant jl: sub_inst :=	x"7"; -- Jump if less
	constant jle: sub_inst :=	x"8"; -- Jump if less or equal
	constant jc: sub_inst :=	x"9"; -- Jump if carry
	constant jnc: sub_inst :=	x"A"; -- Jump if not carry
	constant jo: sub_inst :=	x"B"; -- Jump if overflow
	constant jno: sub_inst :=	x"C"; -- Jump if not overflow
	constant js: sub_inst :=	x"D"; -- Jump if signed
	constant jns: sub_inst :=	x"E"; -- Jump if not signed
	
	-- Arithmetic
	constant add: instruct := 	x"20"; -- add
	constant adc: instruct :=	x"21"; -- add with carry
	constant sbt: instruct := 	x"22"; -- subtract
	constant mul: instruct :=	x"23"; -- multiply
	constant div: instruct :=	x"24"; -- divide
	constant idiv: instruct :=	x"25"; -- signed divide
	constant inc: instruct :=	x"26"; -- increment
	constant dec: instruct :=	x"27"; -- decrement
	
	-- Logical
	constant test: instruct := x"40"; -- test registers
	constant inot: instruct := x"41"; -- one's complement negation
	constant ineg: instruct := x"42"; -- two's complement negation
	constant iand: instruct := x"43"; -- and
	constant ior: instruct := 	x"44"; -- or
	constant ixor: instruct := x"45"; -- Xor
	constant ishr: instruct := x"46"; -- shift left
	constant ishl: instruct := x"47"; -- shift right
	constant irol: instruct := x"48"; -- rotate left
	constant iror: instruct := x"49"; -- rotate right
	
	-- Floats
	constant fadd: instruct := x"60"; -- float add
	constant fsbt: instruct := x"61"; -- float subtract
	constant fmul: instruct :=	x"62"; -- float multiply
	constant fdiv: instruct :=	x"63"; -- float divide
	
	-- REGISTERS
	--constant r0: reg := x"0";
	--constant r1: reg := x"1";
	--constant r2: reg := x"2";
	--constant r3: reg := x"3";
	
	-- Instruction length
	constant db: len := x"0"; -- Data byte 8 bits
	constant dw: len := x"1"; -- Data word 16 bits
	constant dd: len := x"2"; -- Double word 32 bits
	constant dq: len := x"3"; -- Quad word 64 bits
	
end INSTRUCTS;