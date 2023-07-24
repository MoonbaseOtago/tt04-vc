//
//	VC - minimal 32-bit C-only riscv - only has 8 regs
//
//	registers
//		1 	- lr  *
//		2	- sp  *
//		3	- epc *
//		4   - csr * bit 0 ie
//		8	- s0
//		9	- s1
//		10 	- a0
//		11	- a1
//		12	- a2
//		13	- a3
//		14	- a4
//		15      - a5
//
//		(*) only accessable with lwsp/stsp and mv (and register specfic instructions), epc can be the source for an indirect jump
//	
//
//	instructions:
//		C.LWSP
//		C.SWSP
//		C.LW
//		C.SW
//		C.J
//		C.JAL
//		C.JR
//		C.JALR
//		C.BEQZ
//		C.BNEZ
//		C.LI		**	constant is 8 bits sext
//		C.LUI		**  constant is 7 bits sext in 14:8
//		C.ADDI		**	constant is 8 bits sext
//		C.ADDIxSP	**  constant is 7 bits at 8:1 or 9:2 for 16/32 bits (aka "add sp, const")
//		C.ADDIxSPN	**  constant is 8 bits at 8:1 or 9:2 for 16/32 bits (aks "lea sp, const(sp)")
//		C.SLLI		(only by 1)
//		C.SRLI		(only by 1)
//		C.SRA		(only by 1)
//		C.ANDI	
//		C.MV
//		C.ADD		
//		C.AND
//		C.OR
//		C.XOR
//		C.SUB
//
//	new instructions
//		C.LB - replaces C.LD			
//		C.SB - replaces C.SD
//		C.LBSP - replaces C.LDSP		**
//		C.SBSP - replaces C.SDSP		**
//		C.LTZ 
//		C.GEZ
//
//	** extra bits
//		


`ifdef NOTDEF
module	mem(
	input clk,
	input [RV-1:RV/16]raddr,
	output [RV-1:0]rdata,
	input [RV-1:RV/16]waddr,
	input [(RV/8)-1:0]wmask,
	input [RV-1:0]wdata);

	parameter RV=32;
	parameter MSIZE=4096;

	reg [RV-1:0]m[0:MSIZE-1];
	assign rdata = m[raddr];


	reg [RV-1:0]w;
	wire [RV-1:0]w1;

	assign w1 = m[waddr];

	initial begin
`include "asm/a.out"
	end

	generate
	
		if (RV==16) begin 
			always @(*) begin
				w[15:8] = wmask[1]?wdata[15:8]:w1[15:8];
				w[7:0] = wmask[0]?wdata[7:0]:w1[7:0];
			end
		end else begin
			always @(*) begin
				w[31:24] = wmask[3]?wdata[31:24]:w1[31:24];
				w[23:16] = wmask[2]?wdata[23:16]:w1[23:16];
				w[15:8] = wmask[1]?wdata[15:8]:w1[15:8];
				w[7:0] = wmask[0]?wdata[7:0]:w1[7:0];
			end
		end
	
	endgenerate

	always @(posedge clk)
	if (|wmask)
		m[waddr] <= w;

endmodule
`endif

`define OP_ADD	0
`define OP_SUB	1
`define OP_XOR	2
`define OP_OR	3
`define OP_AND	4
`define OP_SLL	5
`define OP_SRA	6
`define OP_SRL	7

module decode(input clk, input reset,
	    input [15:0]ins, 

		output jmp,
		output br, 
		output [2:0]cond,
		output trap,
		output load,
		output store, 
		output alu, 
		output [2:0]op,
		output [3:0]rs1, output[3:0]rs2, output [3:0]rd,
		output needs_rs2, 
		output [RV-1:0]imm);

	parameter RV=32;	// register width

	reg		r_trap, c_trap; assign trap = r_trap;
	reg		r_load, c_load; assign load = r_load;
	reg		r_store, c_store; assign store = r_store;
	reg[2:0]r_cond, c_cond; assign cond = r_cond;
	reg		r_jmp, c_jmp; assign jmp = r_jmp;
	reg		r_br, c_br; assign br = r_br;
	reg		r_alu, c_alu; assign alu = r_alu;
	reg[2:0]r_op, c_op; assign op = r_op;
	reg[3:0]r_rs1, c_rs1; assign rs1 = r_rs1;
	reg[3:0]r_rs2, c_rs2; assign rs2 = r_rs2;
	reg[3:0]r_rd, c_rd; assign rd = r_rd;
	reg		r_needs_rs2, c_needs_rs2; assign needs_rs2 = r_needs_rs2;
	reg[RV-1:0]r_imm, c_imm; assign imm = r_imm;

	reg [RV-1:0]c_off;
	generate
		if (RV == 16) begin
			always @(*) begin
				c_off = {RV{1'bx}};
				case (ins[1:0]) // synthesis full_case parallel_case
				2'b00: case (ins[15:13]) // synthesis full_case parallel_case
				       3'b010: c_off = {{(RV-6){1'b0}}, ins[5], ins[12:10],ins[6], 1'b0};
				       3'b011: c_off = {{(RV-5){1'b0}},         ins[12:10],ins[6], ins[5]};
				       3'b110: c_off = {{(RV-6){1'b0}}, ins[5], ins[12:10],ins[6], 1'b0};
				       3'b111: c_off = {{(RV-5){1'b0}},         ins[12:10],ins[6], ins[5]};
					   default:;
				       endcase
				2'b10: case (ins[15:13]) // synthesis full_case parallel_case
				       3'b010: c_off = {{(RV-8){1'b0}}, ins[11], ins[3:2], ins[12],ins[6:4], 1'b0};
				       3'b011: c_off = {{(RV-7){1'b0}},          ins[3:2], ins[12],ins[6:4], ins[11]};
				       3'b110: c_off = {{(RV-8){1'b0}}, ins[11], ins[3:2], ins[12],ins[6:4], 1'b0};
				       3'b111: c_off = {{(RV-7){1'b0}},          ins[3:2], ins[12],ins[6:4], ins[11]};
					   default:;
				       endcase
				default:;
				endcase
			end
		end else begin
			always @(*) begin
				c_off = 'bx;
				case (ins[1:0]) // synthesis full_case parallel_case
				2'b00: case (ins[15:13]) // synthesis full_case parallel_case
				       3'b010: c_off = {{(RV-7){1'b0}}, ins[5], ins[12:10],ins[6], 2'b0};
				       3'b011: c_off = {{(RV-5){1'b0}},         ins[11:10],ins[6], ins[12], ins[5]};
				       3'b110: c_off = {{(RV-7){1'b0}}, ins[5], ins[12:10],ins[6], 2'b0};
				       3'b111: c_off = {{(RV-5){1'b0}},         ins[11:10],ins[6], ins[12], ins[5]};
					   default:;
				       endcase
				2'b10: case (ins[15:13]) // synthesis full_case parallel_case
				       3'b010: c_off = {{(RV-9){1'b0}}, ins[11], ins[3:2], ins[12],ins[6:4], 2'b0};
				       3'b011: c_off = {{(RV-7){1'b0}},          ins[2],   ins[12],ins[6:4], ins[11], ins[3]};
				       3'b110: c_off = {{(RV-9){1'b0}}, ins[11], ins[3:2], ins[12],ins[6:4], 2'b0};
				       3'b111: c_off = {{(RV-7){1'b0}},          ins[2],   ins[12],ins[6:4], ins[11], ins[3]};
					   default:;
				       endcase
				default:;
				endcase
			end
		end
	endgenerate



	

	always @(*) begin
		c_trap = 0;
		c_load = 0;
		c_store = 0;
		c_cond = 3'bx;
		c_needs_rs2 = 0;
		c_op = 3'bx;
		c_alu = 0;
		c_rs1 = 4'bx;
		c_rs2 = 4'bx;
		c_rd = 4'bx;
		c_imm = {RV{1'bx}};
		c_jmp = 0;
		c_br = 0;
		case (ins[1:0])  // synthesis full_case parallel_case
		2'b00:
			case (ins[15:13]) // synthesis full_case parallel_case
			3'b000: begin	// addi4sp
						c_alu = 1;
						c_op = `OP_ADD;
						c_trap = ins[11:2]==0;
						if (RV == 16) begin
							c_imm = {{(RV-9){1'b0}}, ins[10:7],ins[12:11],ins[5],ins[6],1'b0};
						end else begin
							c_imm = {{(RV-10){1'b0}}, ins[10:7],ins[12:11],ins[5],ins[6],2'b0};
						end
						c_rd = {1'b1, ins[4:2]};
						c_rs1 = 2;
					end
			3'b010: begin 	// lw
						c_load = 1;
						c_op = `OP_ADD;
						c_cond[0] = 0;
						c_rd = {1'b1, ins[4:2]};
						c_rs1 = {1'b1, ins[9:7]};
				    end
			3'b011: begin 	// lb
						c_load = 1;
						c_op = `OP_ADD;
						c_cond[0] = 1;
						c_rd = {1'b1, ins[4:2]};
						c_rs1 = {1'b1, ins[9:7]};
					end
			3'b110: begin 	// sw
						c_store = 1;
						c_cond[0] = 0;
						c_op = `OP_ADD;
						c_rs2 = {1'b1, ins[4:2]};
						c_rs1 = {1'b1, ins[9:7]};
					end
			3'b111: begin 	// sb
						c_store = 1;
						c_cond[0] = 1;
						c_op = `OP_ADD;
						c_rs2 = {1'b1, ins[4:2]};
						c_rs1 = {1'b1, ins[9:7]};
					end
			default: c_trap = 1;
			endcase
		2'b01:casez (ins[15:13]) // synthesis full_case parallel_case
			3'b000:	begin	// addi **
						c_alu = 1;
						c_op = `OP_ADD;
						c_rs1 = {1'b1, ins[9:7]};
						c_rd = {1'b1, ins[9:7]};
						c_imm = {{(RV-7){ins[11]}}, ins[10],  ins[12], ins[6:2]};
					end
			3'b001:	begin	// jal
						c_br = 1;
						c_cond = 3'b1x1;
						c_op = `OP_ADD;
						c_imm = {{(RV-11){ins[12]}}, ins[8], ins[10:9], ins[6],ins[7],ins[2],ins[11],ins[5:3],1'b0};			
						c_rd = 1;
					end
			3'b010:	begin	// li
						c_alu = 1;
						c_op = `OP_ADD;
						c_rs1 = 0;
						c_rd = {1'b1, ins[9:7]};
						c_imm = {{(RV-7){ins[11]}}, ins[10],  ins[12], ins[6:2]};
					end
			3'b011:	if (ins[10:7] == 2) begin	// addi4sp  ** 
						c_alu = 1;
						c_op = `OP_ADD;
						c_rd = 2;
						c_rs1 = 2;
						if (RV==16) begin
							c_imm = {{(RV-7){ins[11]}},ins[12],ins[4:3],ins[5],ins[2],ins[6],1'b0};
						end else begin
							c_imm = {{(RV-8){ins[11]}},ins[12],ins[4:3],ins[5],ins[2],ins[6],2'b00};
						end
					end else begin				// lui **
						c_alu = 1;
						c_op = `OP_ADD;
						c_rd = ins[10:7];
						c_rs1 = 0;
						c_imm = {{(RV-14){ins[10]}}, ins[12], ins[6:2],8'b0};
					end
			3'b100:	begin
						c_rd = {1'b1, ins[9:7]};
						c_rs1 = {1'b1, ins[9:7]};
						c_rs2 = {1'b1, ins[4:2]};
						c_imm = {{(RV-6){1'b0}}, ins[12],  ins[6:2]};
						c_alu = 1;
						case (ins[11:10]) // synthesis full_case parallel_case
						2'b00: c_op = `OP_SRL;
						2'b01: c_op = `OP_SRA;
						2'b10: c_op = `OP_AND;
						2'b11: begin
								c_needs_rs2 = 1;
								case ({ins[12],ins[6:5]}) // synthesis full_case parallel_case
								3'b0_00:	c_op = `OP_SUB;
								3'b0_01:	c_op = `OP_XOR;
								3'b0_10:	c_op = `OP_OR;
								3'b0_11:	c_op = `OP_AND;
								default: c_trap = 1;
								endcase
							   end
						endcase
					end
			3'b101:	begin	// j
						c_br = 1;
						c_cond = 3'b1x0;
						c_op = `OP_ADD;
						c_imm = {{(RV-11){ins[12]}}, ins[8], ins[10:9], ins[6],ins[7],ins[2],ins[11],ins[5:3],1'b0};
					end
			3'b11?:	begin	//  beqz/bnez
						c_br = 1;
						c_cond = {2'b00, ins[12]};	// beqz/bnez
						c_op = `OP_ADD;
						c_rs1 = {1'b1, ins[9:7]};
						c_imm =  {{(RV-8){ins[12]}},ins[6:5],ins[2],ins[11:10],ins[4:3],1'b0};
					end
			default: c_trap = 1;
			endcase
		2'b10:
			casez (ins[15:13])  // synthesis full_case parallel_case
			3'b000:	begin	// slli
						c_alu = 1;
						c_op = `OP_SLL;
						c_trap = ins[11:10]!=1;
						c_rd = {1'b1, ins[9:7]};
						c_rs1 = {1'b1, ins[9:7]};
					end
			3'b010:	begin	// lwsp  **
						c_load = 1;
						c_cond[0] = 0;
						c_op = `OP_ADD;
						c_rd = ins[10:7];
						c_rs1 = 2;
					end
			3'b011:	begin	// lbsp  **
						c_load = 1;
						c_cond[0] = 1;
						c_op = `OP_ADD;
						c_rd = ins[10:7];
						c_rs1 = 2;
					end
			3'b100:	if (!ins[12]) begin
						if (ins[6:2] == 0) begin	// jr
							c_jmp = 1;
							c_op = `OP_ADD;
							c_cond[0] = 0;
							c_rs1 = ins[10:7];
							c_rs2 = 0;
							c_needs_rs2 = 1;
						end else begin
							c_alu = 1;
							c_op = `OP_ADD;
							c_rd = ins[10:7];
							c_rs1 = 0;
							c_rs2 = ins[5:2];
							c_needs_rs2 = 1;
						end
					end else begin
						if (ins[6:2] == 0) begin	// jalr
							c_trap = ins[10:7]==0; // ebreak
							c_jmp = 1;
							c_cond[0] = 1;
							c_op = `OP_ADD;
							c_rd = 1;
							c_rs1 = ins[10:7];
							c_rs2 = 0;
							c_needs_rs2 = 1;
						end else begin
							c_alu = 1;
							c_op = `OP_ADD;
							c_rd = ins[10:7];
							c_rs1 = ins[10:7];
							c_rs2 = ins[5:2];
							c_needs_rs2 = 1;
						end
					end
			3'b110:	begin	// swsp  **
						c_store = 1;
						c_cond[0] = 0;
						c_rs2 = ins[10:7];
						c_op = `OP_ADD;
						c_rs1 = 2;
					end
			3'b111:	begin	// sbsp  **
						c_store = 1;
						c_cond[0] = 1;
						c_rs2 = ins[10:7];
						c_rs1 = 2;
						c_op = `OP_ADD;
					end
			default: c_trap = 1;
			endcase
		2'b11:	casez (ins[15:13]) // synthesis full_case parallel_case
			3'b11?:	begin	//  bltz/bgez
						c_br = 1;
						c_cond = {2'b01, ins[12]};	// bltz/bgez
						c_rs1 = {1'b1, ins[9:7]};
						c_op = `OP_ADD;
						c_imm =  {{(RV-8){ins[12]}},ins[6:5],ins[2],ins[11:10],ins[4:3],1'b0};
					end
			default: c_trap = 1;
		    endcase
		endcase
	end

	always @(posedge clk) begin
		r_trap <= c_trap;
		r_rs1 <= c_rs1;
		r_rs2 <= c_rs2;
		r_needs_rs2 <= c_needs_rs2;
		r_rd <= c_rd;
		r_imm <= (c_load||c_store?c_off:c_imm);
		r_store <= c_store;
		r_load <= c_load;
		r_alu <= c_alu;
		r_op <= c_op;
		r_br <= c_br;
		r_cond <= c_cond;
		r_jmp <= c_jmp;
	end


endmodule

module execute(input clk, input reset,
		input interrupt,
		input [3:0]rd, 
		input [3:0]rs1, 
		input [3:0]rs2, 
		input needs_rs2,
		input [RV-1:0]imm,
		input	load,
		input	store,
		input	trap,
		input	alu,
		input	[2:0]op,
		input   jmp, 
		input br, input [2:0]cond,
		
		output	[RV-1:1]pc,
		output	[RV-1:1]addr,
		output	[RV-1:0]wdata,
		output	[(RV/8)-1:0]wmask,
		output			rstrobe,
		input	[RV-1:0]rdata
	);
	parameter RV=32;

	assign pc = r_pc;
	assign rstrobe = r_read_stall;
	assign wdata = r_wdata;
	assign addr = r_wb[RV-1:1];
	assign  wmask = r_wmask;
	reg [(RV/8)-1:0]r_wmask;
	reg [RV-1:0]r_wdata;

	wire link = ((br&cond[2])||jmp)&cond[0];


	reg [RV-1:0]r1, r2;
	reg [RV-1:0]r_lr, r_sp, r_epc, r_8, r_9, r_10, r_11, r_12, r_13, r_14, r_15;

	always @(*) 
	if (br) begin
		r1 = {r_pc, 1'b0};
	end else
	if (rs1 == r_wb_addr) begin
		r1 = r_wb;
	end else
	case (rs1) // synthesis full_case parallel_case
	4'b0000:	r1 = 0;
	4'b0001:	r1 = r_lr;
	4'b0010:	r1 = r_sp;
	4'b0011:	r1 = r_epc;
	4'b0100:	r1 = {{(RV-1){1'b0}},r_ie};
	4'b1000:	r1 = r_8;
	4'b1001:	r1 = r_9;
	4'b1010:	r1 = r_10;
	4'b1011:	r1 = r_11;
	4'b1100:	r1 = r_12;
	4'b1101:	r1 = r_13;
	4'b1110:	r1 = r_14;
	4'b1111:	r1 = r_15;
	default: r1 = {RV{1'bx}};
	endcase

	reg br_taken;
	always @(*) begin
		casez (cond)  // synthesis full_case parallel_case
		3'b0_00:	br_taken = r1 == 0;	// beqz
		3'b0_01:	br_taken = r1 != 0;	// bnez
		3'b0_10:	br_taken = !r1[RV-1];// bgez
		3'b0_11:	br_taken = r1[RV-1];// bltz
		3'b1_??:	br_taken = 1;
		endcase
	end

	always @(*) 
	if (!needs_rs2) begin
		r2 = imm;
	end else
	if (rs2 == r_wb_addr) begin
		r2 = r_wb;
	end else
	case (rs2) // synthesis full_case parallel_case
	4'b0001:	r2 = r_lr;
	4'b0010:	r2 = r_sp;
	4'b0011:	r2 = r_epc;
	4'b1000:	r2 = r_8;
	4'b1001:	r2 = r_9;
	4'b1010:	r2 = r_10;
	4'b1011:	r2 = r_11;
	4'b1100:	r2 = r_12;
	4'b1101:	r2 = r_13;
	4'b1110:	r2 = r_14;
	4'b1111:	r2 = r_15;
	default: r2 = {RV{1'bx}};
	endcase
	
	reg [RV-1:0]sl, sra, srl;
	generate
		if (RV == 16) begin
			always @(*)
				sl = {r1[14:0], 1'b0};
			always @(*)
				srl = {1'b0, r1[15:1]};
			always @(*)
				sra = {{1{r1[15]}}, r1[15:1]};
		end else begin
			always @(*)
				sl = {r1[30:0], 1'b0};
			always @(*)
				srl = {1'b0, r1[31:1]};
			always @(*)
				sra = {{1{r1[31]}}, r1[31:1]};
		end
	endgenerate

	reg r_branch_stall;
	wire valid = !reset && !r_branch_stall;

	reg r_read_stall;
	always @(posedge clk)
		r_read_stall <= !reset && load;

	reg [RV-1:0]r_wb, c_wb;
	reg [3:0]r_wb_addr;
	reg r_ie;
	reg r_wb_valid;
	always @(*)
	case (op) // synthesis full_case parallel_case
	`OP_ADD:	c_wb = r1 + r2;
	`OP_SUB:	c_wb = r1 + ~r2 + 1;
	`OP_XOR:	c_wb = r1 ^ r2;
	`OP_OR:		c_wb = r1 | r2;
	`OP_AND:	c_wb = r1 & r2;
	`OP_SLL:	c_wb = sl;
	`OP_SRA:	c_wb = sra;
	`OP_SRL:	c_wb = srl;
	endcase
	

	always @(posedge clk)
	if (!reset && valid && !br && !(jmp&!link)) begin
		r_wb_valid <= !(load&!r_read_stall || store);
		r_wb_addr <= (reset ?0 : trap||(interrupt&r_ie) ? 3 : store? 0 : rd);
		r_wb <= link||trap||(interrupt&r_ie)?{r_pc, 1'b0}: r_read_stall? (cond[0] ?{{(RV-8){rdata[7]}}, rdata[7:0]}:rdata):c_wb;
	end else begin
		r_wb_valid <= 0;
	end

	always @(posedge clk)
	if (r_wb_valid)
	case (r_wb_addr) // synthesis full_case parallel_case
	4'b0001:	r_lr <= r_wb;
	4'b0010:	r_sp <= r_wb;
	4'b0011:	r_epc <= r_wb;
	4'b1000:	r_8 <= r_wb;
	4'b1001:	r_9 <= r_wb;
	4'b1010:	r_10 <= r_wb;
	4'b1011:	r_11 <= r_wb;
	4'b1100:	r_12 <= r_wb;
	4'b1101:	r_13 <= r_wb;
	4'b1110:	r_14 <= r_wb;
	4'b1111:	r_15 <= r_wb;
	default:;
	endcase

	reg [RV-1:1 ]r_pc, c_pc;

	always @(*)
	casez ({reset, r_read_stall, valid, trap, interrupt&r_ie, jmp, br&br_taken})  // synthesis full_case parallel_case
	7'b1??????:	c_pc = 0;
	7'b0011???:	c_pc = 2;	// 4
	7'b00101??:	c_pc = 4;	// 8
	7'b0010010:	c_pc = c_wb[RV-1:1];
	7'b00100?1:	c_pc = c_wb[RV-1:1];
	7'b0010000:	c_pc = r_pc+1;
	7'b01?????:	c_pc = r_pc;
	7'b000????:	c_pc = r_pc;
	default:	c_pc = r_pc;
	endcase

	always @(posedge clk) begin
		//r_trap <= !reset && valid && (trap || interrupt&&r_ie);
		r_ie <= reset ? 0 : valid && (trap || interrupt&&r_ie) ? 0: r_wb_valid && (r_wb_addr == 4) ? r_wb[0] : r_ie; 
		r_pc <= c_pc;
		r_wdata <= (cond[0]? {(RV/8){r2[7:0]}}:r2);
		r_branch_stall <= !reset&valid&(jmp|br&br_taken);
	end


	generate
		if (RV == 16) begin
			always @(posedge clk) 
				r_wmask <= reset||!valid||!store?0:!cond[0]? 2'b11: {c_wb[0], ~c_wb[0]};
		end else begin
			always @(posedge clk) 
				r_wmask <= reset||!valid||!store?0:!cond[0]? 4'b1111: {c_wb[1:0]==3, c_wb[1:0]==2, c_wb[1:0]==1, c_wb[1:0]==0};
		end
	endgenerate

endmodule

module cpu(input clk, input reset_in,
		input interrupt,
		output [RV-1:RV/16]raddr,
		output	rreq,
		input	rdone,
		input [RV-1:0]rdata,
		output [RV-1:RV/16]waddr,
		output [(RV/8)-1:0]wmask,
		output [RV-1:0]wdata,
		input wdone);

	parameter RV=16;

	assign raddr = rstrobe?addr[RV-1:RV/16]:pc[RV-1:RV/16];
	assign waddr = addr[RV-1:RV/16];

	assign rreq=1;


	reg r_reset;
	always @(posedge clk)
		r_reset <= reset_in;

	wire		jmp;
	wire		br; 
	wire   [2:0]cond;
	wire		trap;
	wire		load;
	wire		store; 
	wire		alu; 
	wire   [2:0]op;
	wire   [3:0]rs1, rs2, rd;
	wire		needs_rs2; 
	wire [RV-1:0]imm;

	wire [RV-1:1]pc;
	wire [RV-1:2]addr;
	wire [15:0]ins;
	wire         rstrobe;
	generate 
		if (RV == 16) begin
			assign ins = rdata;
		end else begin
			assign ins = pc[1]?rdata[31:16]:rdata[15:0];
		end
	endgenerate


	decode #(.RV(RV))dec(.clk(clk), .reset(r_reset),
		.ins(ins),
		.jmp(jmp),
		.br(br),
		.cond(cond),
		.trap(trap),
		.load(load),
		.store(store), 
		.alu(alu),
		.op(op),
		.rs1(rs1),
		.rs2(rs2),
		.rd(rd),
		.needs_rs2(needs_rs2), 
		.imm(imm));

	execute #(.RV(RV))ex(.clk(clk), .reset(r_reset),
		.interrupt(interrupt),
		.pc(pc),
		.rstrobe(rstrobe),
		.wmask(wmask),
		.addr(addr),
		.wdata(wdata),
		.rdata(rdata),
		.jmp(jmp),
		.br(br),
		.cond(cond),
		.trap(trap),
		.load(load),
		.store(store), 
		.alu(alu),
		.op(op),
		.rs1(rs1),
		.rs2(rs2),
		.rd(rd),
		.needs_rs2(needs_rs2), 
		.imm(imm));

		
	

endmodule

`ifdef NOTDEF
module test;
	reg reset, clk;
	initial begin
		reset = 1;
		clk = 0;#5 clk=1; #5
		clk = 0;#5 clk=1; #5
		reset = 0;
		forever begin		
			clk = 0;#5 clk=1; #5;
		end
	end
	initial begin
		$dumpfile("x.vcd");
        $dumpvars;
		#2000 $finish;
	end
	main m(.clk(clk), .reset_in(reset));
endmodule
`endif

/* For Emacs:
 * Local Variables:
 * mode:c
 * indent-tabs-mode:t
 * tab-width:4
 * c-basic-offset:4
 * End:
 * For VIM:
 * vim:set softtabstop=4 shiftwidth=4 tabstop=4:
 */
