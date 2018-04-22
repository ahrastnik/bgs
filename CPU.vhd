library IEEE;
use IEEE.numeric_std.all;
use IEEE.std_logic_1164.all;
library work;
use work.INSTRUCTS.all;

entity CPU is
	generic(
		BUS_WIDTH: 	integer;
		PROG_WIDTH: integer;
		DATA_WIDTH: integer;
		GPR_NUM:	integer
	);
	port(
		clk, rst: in std_logic;
		-- Program Memory
		prog_adr_a, prog_adr_b: out unsigned((PROG_WIDTH - 1) downto 0);
		prog_data_a, prog_data_b: in unsigned((BUS_WIDTH - 1) downto 0);
		-- Data Memory
		data_adr: out unsigned((BUS_WIDTH - 1) downto 0) := (others => '0');
		data_i: in unsigned((BUS_WIDTH - 1) downto 0);
		data_o: out unsigned((BUS_WIDTH - 1) downto 0) := (others => '0');
		we: out std_logic := '0'
	);
end CPU;

architecture Malibu of CPU is
	-- Constants
	constant PROG_START: 	unsigned((BUS_WIDTH - 1) downto 0) := x"00000000";
	constant STACK_POINTER: unsigned((BUS_WIDTH - 1) downto 0) := x"000000C0";
	
	-- States
	type states is (boot, reset, prefetch, run, func); -- run state is the pipeline
	signal state: states := reset;

	signal prog_adr:	unsigned((PROG_WIDTH - 1) downto 0);
	
	-- Stage start
	signal fetch_s:	 	std_logic := '0';
	signal decode_s:	std_logic := '0';
	signal execute_s: 	std_logic := '0';

	-- CPU Properties
	signal pc: 		unsigned((BUS_WIDTH - 1) downto 0) := PROG_START;-- Program Counter starts after the Interrupt Vector Table
	signal stack: 	unsigned((BUS_WIDTH - 1) downto 0) := STACK_POINTER;-- Stack Pointer
	signal stat: 	unsigned((BUS_WIDTH - 1) downto 0) := (others => '0');
	
	signal inst, inst_n: 			unsigned((BUS_WIDTH - 1) downto 0) := (others => '0'); -- Decode stage: Instruction and next instruction
	signal exe_inst, exe_inst_n: 	unsigned((BUS_WIDTH - 1) downto 0) := (others => '0'); -- Decode stage: Instruction and next instruction
	
	-- General Purpose Registers
	type gpr is array(0 to (GPR_NUM - 1)) of unsigned((BUS_WIDTH - 1) downto 0);-- General Purpose register
	signal gprs: gpr := (others => (others => '0'));

	signal dependencies:	unsigned((GPR_NUM - 1) downto 0) := (others => '0'); -- Busy flags for general purpose registers
	
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

	function pc_increment(prev_pc, inst, inst_n: unsigned) return unsigned is
		variable pc: unsigned((BUS_WIDTH - 1) downto 0) := PROG_START;
	begin
		pc_inc:if(inst(31 downto 24) = jmp) then
			-- Set it explicitly if jump command was issued
			jmp_inst:case(inst(23 downto 20)) is
				when x"0" =>
					pc := inst_n;
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
					pc := (others => '0');
			end case jmp_inst;
		else
			-- Set the program counter
			if(inst(16) = '1') then
				pc := prev_pc + 2;
			else
				pc := prev_pc + 1;
			end if;
		end if pc_inc;
		return pc;
	end pc_increment;
	
	function dependency_checker(inst, regs: unsigned) return std_logic is
		variable pass: std_logic := '1';
	begin
		dep_chk:if(inst(17) = '0') then
			insts:case( inst(31 downto 24) ) is
				when mov =>
					mov_inst:case(inst(23 downto 20) ) is
						when x"0" =>
							if(regs(to_integer(inst(7 downto 4))) = '1') then
								pass := '0';
							end if;
						when x"3" =>
							if(regs(to_integer(inst(7 downto 4))) = '1') then
								pass := '0';
							end if;
						when others =>
							null;
					end case mov_inst;
				when lea =>
					if(regs(to_integer(inst(7 downto 4))) = '1') then
						pass := '0';
					end if;
				when push =>
					if(regs(to_integer(inst(11 downto 8))) = '1') then
						pass := '0';
					end if;
				when cmp =>
					cmp_chk:case(inst(23 downto 20)) is
						when x"0" =>
							if(regs(to_integer(inst(11 downto 8))) = '1' or regs(to_integer(inst(7 downto 4))) = '1') then
								pass := '0';
							end if;
						when x"1" =>
							if(regs(to_integer(inst(7 downto 4))) = '1') then
								pass := '0';
							end if;
						when others =>
							null;
					end case cmp_chk;
				when others =>
					pass := '1';
			end case insts;
		else
			alu_load:case(inst(23 downto 20) ) is
				when x"1" =>
					if(regs(to_integer(inst(7 downto 4))) = '1' or regs(to_integer(inst(3 downto 0))) = '1') then
						pass := '0';
					end if;
				when x"2" =>
					if(regs(to_integer(inst(11 downto 8))) = '1') then
						pass := '0';
					end if;
				when x"3" =>
					if(regs(to_integer(inst(7 downto 4))) = '1') then
						pass := '0';
					end if;
				when others =>
					if(regs(to_integer(inst(11 downto 8))) = '1' or regs(to_integer(inst(7 downto 4))) = '1') then
						pass := '0';
					end if;
			end case alu_load;
		end if dep_chk;

		return pass;
	end dependency_checker;

	function dependency_set(inst, regs_in: unsigned) return unsigned is
		variable regs_out: unsigned((GPR_NUM - 1) downto 0) := (others => '0');
	begin
		alu_req:if(inst(17) = '1') then
			-- Set dependencies for ALU instructions
			if(inst(23 downto 20) >= x"0" and inst(23 downto 20) < x"4") then
				regs_out(to_integer(inst(11 downto 8))) := '1';
			end if;
		else
			-- Set dependencies for other instructions
			depn:case(inst(31 downto 24)) is
				when mov =>
					if(inst(23 downto 20) >= x"0" and inst(23 downto 20) < x"3") then
						regs_out(to_integer(inst(11 downto 8))) := '1';
					end if;
				when pop =>
					if(inst(23 downto 20) = x"0") then
						regs_out(to_integer(inst(11 downto 8))) := '1';
					end if;
				when others =>
					null;
			end case depn;
		end if alu_req;

		return regs_out;
	end dependency_set;
	
begin
	-- Initialize components
	U_ALU: ALU generic map(BUS_WIDTH => BUS_WIDTH)
		port map(clk => clk, en => alu_en, op => exe_inst, a => op1, b => op2, result => result, zero => stat(0), signd => stat(1), carry => stat(2), overflow => stat(3));

	main:process(clk)
	begin
		clkr:if(rising_edge(clk)) then
			decode_s <= '0';
			execute_s <= '0';
			we <= '0';
			alu_en <= '0';
			state_m:case state is
				when boot =>
					null;
				when reset =>
					pc <= PROG_START;
					stack <= STACK_POINTER;
					-- Reset pipeline
					decode_s <= '0';
					if(rst = '1') then
						state <= run;
					end if;
				when prefetch =>
					pfetch_rst:if(rst = '1') then
						-- Set program counter
						pc <= pc_increment(pc, prog_data_a, prog_data_b);
						-- Run pipeline
						state <= run;
					else
						state <= reset;
					end if pfetch_rst;
				when run =>
					run_rst:if(rst = '1') then
						-- Fetch stage
						-- Set dependencies
						dependencies <= dependency_set(prog_data_a, dependencies);
						-- Check dependencies
						dep:if(dependency_checker(prog_data_a, dependencies) = '1') then
							-- Load current and next instructions for decoding
							inst 	<= prog_data_a;
							inst_n 	<= prog_data_b;
							-- Set program counter
							pc <= pc_increment(pc, prog_data_a, prog_data_b);
							-- Enable decode stage
							decode_s <= '1';
						end if dep;
						
						
						-- Decode stage
						dec_st:if(decode_s = '1') then
							-- Set the stage start flag
							execute_s <= '1';
							-- Load current and next instructions for decoding
							exe_inst 	<= inst;
							exe_inst_n 	<= inst_n;
							-- Check dependencies

							-- Load value from data memory
							if (inst(15 downto 12) > 0) then
								data_adr <= inst_n;
							end if;
							
							-- Handle ALU instructions
							alu_req:if(inst(17) = '1') then
								-- Enable ALU if instruction is of type Arithmetic or Logic
								alu_en <= '1';
								--  Load operands in ALU
								alu_load:case(inst(23 downto 20)) is
									when x"1" =>
										op1 <= gprs(to_integer(inst(7 downto 4)));
										op2 <= gprs(to_integer(inst(3 downto 0)));
									when x"2" =>
										op1 <= gprs(to_integer(inst(11 downto 8)));
										op2 <= inst_n;
									when x"3" =>
										op1 <= gprs(to_integer(inst(7 downto 4)));
										op2 <= inst_n;
									when others =>
										op1 <= gprs(to_integer(inst(11 downto 8)));
										op2 <= gprs(to_integer(inst(7 downto 4)));
								end case alu_load;
							end if alu_req;
						end if dec_st;
						
						-- Execute stage
						exe_st:if(execute_s = '1') then
							-- Handle instructions
							execute_inst:case(exe_inst(31 downto 24)) is
								when nop =>
									null;
								when mov =>
									mov_inst:case( exe_inst(23 downto 20) ) is
										when x"0" =>
											gprs(to_integer(exe_inst(11 downto 8))) <= gprs(to_integer(exe_inst(7 downto 4)));
										when x"1" =>
											gprs(to_integer(exe_inst(11 downto 8))) <= exe_inst_n;
										when x"2" =>
											gprs(to_integer(exe_inst(11 downto 8))) <= data_i;
										when x"3" =>
											data_o <= gprs(to_integer(exe_inst(7 downto 4)));
										when others =>
											null;
									end case mov_inst;
								when push =>
									null;
								when pop =>
									null;
								when inc =>
									if(exe_inst(23 downto 20) = x"0") then
										gprs(to_integer(exe_inst(11 downto 8))) <= result;
									elsif (exe_inst(23 downto 20) = x"1") then
										data_o <= result;
									end if;
								when dec =>
									if(exe_inst(23 downto 20) = x"0") then
										gprs(to_integer(exe_inst(11 downto 8))) <= result;
									elsif (exe_inst(23 downto 20) = x"1") then
										data_o <= result;
									end if;
								when others =>
									-- Retrieve the result from the ALU
									if(exe_inst(23 downto 20) >= x"0" and exe_inst(23 downto 20) < x"4") then
										gprs(to_integer(exe_inst(11 downto 8))) <= result;
									end if;
							end case execute_inst;
						end if exe_st;
						
						state <= run;
					else
						state <= reset;
					end if run_rst;
				when func =>
					func_rst:if(rst = '1') then
						state <= run;
					else
						state <= reset;
					end if func_rst;
			end case state_m;
		end if clkr;
	end process main;
	
	-- Set program address
	prog_adr 	<= PROG_START((PROG_WIDTH - 1) downto 0) when state = reset else
					prog_data_b((PROG_WIDTH - 1) downto 0) when state = run and prog_data_a(31 downto 24) = jmp else
					pc((PROG_WIDTH - 1) downto 0) when state = run and dependency_checker(prog_data_a, dependencies) = '0' else
					pc((PROG_WIDTH - 1) downto 0) + 1 when state = run and prog_data_a(16) = '0' else
					pc((PROG_WIDTH - 1) downto 0) + 2 when state = run and prog_data_a(16) = '1' else
					(others => '0');
	prog_adr_a 	<= prog_adr;
	prog_adr_b 	<= prog_adr + 1;
end Malibu;