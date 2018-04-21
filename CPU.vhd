library IEEE;
use IEEE.numeric_std.all;
use IEEE.std_logic_1164.all;
library work;
use work.INSTRUCTS.all;

entity CPU is
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
end CPU;

architecture Malibu of CPU is
	-- Constants
	constant PROG_START: 	unsigned((BUS_WIDTH - 1) downto 0) := x"00000008";
	constant STACK_POINTER: unsigned((BUS_WIDTH - 1) downto 0) := x"000000C0";
	
	-- States
	type states is (boot, reset, run, func); -- run state is the pipeline
	signal state: states := reset;
	
	-- Stage start
	signal fetch_s: std_logic := '0';
	signal decode_s: std_logic := '0';

	-- CPU Properties
	signal pc: unsigned((BUS_WIDTH - 1) downto 0) := PROG_START;-- Program Counter starts after the Interrupt Vector Table
	signal stack: unsigned((BUS_WIDTH - 1) downto 0) := STACK_POINTER;-- Stack Pointer
	signal stat: unsigned((BUS_WIDTH - 1) downto 0) := (others => '0');
	
	signal inst, inst_n: unsigned((BUS_WIDTH - 1) downto 0) := (others => '0'); -- Instruction and next instruction
	
	-- General Purpose Registers
	type gpr is array(0 to 15) of unsigned((BUS_WIDTH - 1) downto 0);-- General Purpose register
	signal gprs: gpr := (others => (others => '0'));
	
	-- ALU
	signal alu_en: std_logic := '0';
	signal op1, op2, result: unsigned((BUS_WIDTH - 1) downto 0) := (others => '0');
	
	component ALU
		generic(
			BUS_WIDTH: integer
		);
		port(
			clk, en: in std_logic;
			op, a, b: in unsigned((BUS_WIDTH - 1) downto 0) := (others => '0');
			result: out unsigned((BUS_WIDTH - 1) downto 0) := (others => '0');
			carry, zero, signd, overflow: out std_logic := '0'
		);
	end component;
	
begin
	-- Initialize components
	U_ALU: ALU generic map(BUS_WIDTH => BUS_WIDTH)
		port map(clk => clk, en => alu_en, op => inst, a => op1, b => op2, result => result, zero => stat(0), signd => stat(1), carry => stat(2), overflow => stat(3));

	main:process(clk)
	begin
		clkr:if(rising_edge(clk)) then
			we <= '0';
			alu_en <= '0';
			state_m:case state is
				when boot =>
					null;
				when reset =>
					pc <= PROG_START;
					stack <= STACK_POINTER;
					-- Reset pipeline
					fetch_s <= '0';
					decode_s <= '0';
					if(rst = '1') then
						state <= run;
					end if;
				when run =>
					run_rst:if(rst = '1') then
						-- Fetch stage
						fetch_s <= '1';
						-- Increment the program counter
						pc <= pc + 1;
						-- Load current and next instructions
						inst 	<= prog_data_a;
						inst_n 	<= prog_data_b;
						
						-- Decode stage
						dec_st:if(fetch_s = '1') then
							-- Set the stage start flag
							decode_s <= '1';
							-- Load value from data memory
							if (inst(16) = '1') then
								data_adr <= inst_n;
							end if ;
							-- Enable ALU if instruction is of type Arithmetic or Logic
							if(inst(17) = '1') then
								alu_en <= '1';
								op1 <= gprs(to_integer(inst(7 downto 4)));
								op2 <= gprs(to_integer(inst(3 downto 0)));
							end if;
						end if dec_st;
						
						-- Execute stage
						exe_st:if(decode_s = '1') then
							exe_inst:case( inst(31 downto 24) ) is
								when nop =>
									null;
								when mov =>
									mov_inst:case( inst(23 downto 20) ) is
										when x"0" =>
											gprs(to_integer(inst(7 downto 4))) <= gprs(to_integer(inst(3 downto 0)));
										when x"1" =>
											gprs(to_integer(inst(7 downto 4))) <= inst_n;
										when x"2" =>
											gprs(to_integer(inst(7 downto 4))) <= data_i;
										when x"3" =>
											data_o <= gprs(to_integer(inst(3 downto 0)));
										when others =>
											null;
									end case mov_inst;
									gprs(to_integer(inst(7 downto 4))) <= gprs(to_integer(inst(3 downto 0)));
								when jmp =>
									jmp_inst:case( inst(23 downto 20) ) is
										when x"0" =>
											pc <= inst_n;
										-- COMPILATION MEMORY OVERFLOW ISSUE!!!(stat register is the cause)
										-- when jz =>
										-- 	if(stat(0) = '1') then
										-- 		pc <= inst_n;
										-- 	end if;
										-- when jnz =>
										-- 	if(stat(0) = '0') then
										-- 		pc <= inst_n;
										-- 	end if;
										-- when jc =>
										-- 	if(stat(2) = '1') then
										-- 		pc <= inst_n;
										-- 	end if;
										-- when jnc =>
										-- 	if(stat(2) = '0') then
										-- 		pc <= inst_n;
										-- 	end if;
										-- when js =>
										-- 	if(stat(1) = '1') then
										-- 		pc <= inst_n;
										-- 	end if;
										-- when jns =>
										-- 	if(stat(1) = '0') then
										-- 		pc <= inst_n;
										-- 	end if;
										when others =>
											null;
									end case jmp_inst;
								when inc =>
									null;
								when dec =>
									null;
								when others =>
									-- Retrieve the result from the ALU
									if(inst(23 downto 20) >= x"0" and inst(23 downto 20) < x"4") then
										gprs(to_integer(inst(7 downto 4))) <= result;
									end if;
							end case exe_inst;
						end if exe_st;
						
						state <= run;
					else
						state <= reset;
					end if run_rst;
				when func =>
					func_rst:if(rst = '1') then
						null;
					else
						state <= reset;
					end if func_rst;
			end case state_m;
		end if clkr;
	end process main;
	
	-- Set program address
	prog_adr_a <= pc((PROG_WIDTH - 1) downto 0);
	prog_adr_b <= pc((PROG_WIDTH - 1) downto 0) + 1;
end Malibu;