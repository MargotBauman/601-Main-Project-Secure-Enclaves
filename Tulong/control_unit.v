`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 11/03/2019 05:14:24 PM
// Design Name: 
// Module Name: control_unit
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module control_unit #(
  parameter CORE = 0,
  parameter ADDRESS_BITS = 20,
  parameter SCAN_CYCLES_MIN = 0,
  parameter SCAN_CYCLES_MAX = 1000
) (
  input clock,
  input reset,
  input [6:0] opcode_decode,
  input [6:0] opcode_execute,
  input [2:0] funct3, // decode
  input [6:0] funct7, // decode

  input [ADDRESS_BITS-1:0] JALR_target_execute,
  input [ADDRESS_BITS-1:0] branch_target_execute,
  input [ADDRESS_BITS-1:0] JAL_target_decode,
  input branch_execute,

  input true_data_hazard,
  input d_mem_hazard,
  input i_mem_hazard,
  input JALR_branch_hazard,
  input JAL_hazard,

  output branch_op,
  output memRead,
  output [5:0] ALU_operation, // use 6-bits to leave room for extensions
  output memWrite,
  output [1:0] next_PC_sel,
  output [1:0] operand_A_sel,
  output operand_B_sel,
  output [1:0] extend_sel,
  output regWrite,

  output [ADDRESS_BITS-1:0] target_PC,
  output i_mem_read,

  input  scan
);

localparam [6:0]R_TYPE  = 7'b0110011,
                I_TYPE  = 7'b0010011,
                STORE   = 7'b0100011,
                LOAD    = 7'b0000011,
                BRANCH  = 7'b1100011,
                JALR    = 7'b1100111,
                JAL     = 7'b1101111,
                AUIPC   = 7'b0010111,
                LUI     = 7'b0110111,
                FENCES  = 7'b0001111,
                SYSCALL = 7'b1110011;


assign regWrite      = (opcode_decode == R_TYPE) | (opcode_decode == I_TYPE) | (opcode_decode == LOAD)
                       | (opcode_decode == JALR) | (opcode_decode == JAL)    | (opcode_decode == AUIPC)
                       | (opcode_decode == LUI);

assign memWrite      = (opcode_decode == STORE);
assign branch_op     = (opcode_decode == BRANCH);
assign memRead       = (opcode_decode == LOAD);

/* old
assign ALU_operation = (opcode_decode == R_TYPE) ?  3'b000 :
                       (opcode_decode == I_TYPE) ?  3'b001 :
                       (opcode_decode == STORE)  ?  3'b101 :
                       (opcode_decode == LOAD)   ?  3'b100 :
                       (opcode_decode == BRANCH) ?  3'b010 :
                       ((opcode_decode == JALR)  | (opcode_decode == JAL)) ? 3'b011 :
                       ((opcode_decode == AUIPC) | (opcode_decode == LUI)) ? 3'b110 : 2'b00;
*/

// Check for operations other than addition. Use addition as default case
assign ALU_operation =
  (opcode_decode == JAL) ? 6'd1 : // JAL: Pass through
  (opcode_decode == JALR & funct3 == 3'b000) ? 6'd1 : // JALR: Pass through
  (opcode_decode == BRANCH & funct3 == 3'b000) ? 6'd2 : // BEQ: equal
  (opcode_decode == BRANCH & funct3 == 3'b001) ? 6'd3 : // BNE: not equal
  (opcode_decode == BRANCH & funct3 == 3'b100) ? 6'd4 : // BLT: signed less than
  (opcode_decode == BRANCH & funct3 == 3'b101) ? 6'd5 : // BGE: signed greater than, equal
  (opcode_decode == BRANCH & funct3 == 3'b110) ? 6'd6 : // BLTU: unsigned less than
  (opcode_decode == BRANCH & funct3 == 3'b111) ? 6'd7 : // BGEU: unsigned greater than, equal
  (opcode_decode == I_TYPE & funct3 == 3'b010) ? 6'd4 : // SLTI: signed less than
  (opcode_decode == I_TYPE & funct3 == 3'b011) ? 6'd6 : // SLTIU: unsigned less than
  (opcode_decode == I_TYPE & funct3 == 3'b100) ? 6'd8 : // XORI: xor
  (opcode_decode == I_TYPE & funct3 == 3'b110) ? 6'd9 : // ORI: or
  (opcode_decode == I_TYPE & funct3 == 3'b111) ? 6'd10 : // ANDI: and
  (opcode_decode == I_TYPE & funct3 == 3'b001 & funct7 == 7'b0000000) ? 6'd11 : // SLLI: logical left shift
  (opcode_decode == I_TYPE & funct3 == 3'b101 & funct7 == 7'b0000000) ? 6'd12 : // SRLI: logical right shift
  (opcode_decode == I_TYPE & funct3 == 3'b101 & funct7 == 7'b0100000) ? 6'd13 : // SRAI: arithemtic right shift
  (opcode_decode == R_TYPE & funct3 == 3'b000 & funct7 == 7'b0100000) ? 6'd14 : // SUB: subtract
  (opcode_decode == R_TYPE & funct3 == 3'b001 & funct7 == 7'b0000000) ? 6'd11 : // SLL: logical left shift
  (opcode_decode == R_TYPE & funct3 == 3'b010 & funct7 == 7'b0000000) ? 6'd4  : // SLT: signed less than
  (opcode_decode == R_TYPE & funct3 == 3'b011 & funct7 == 7'b0000000) ? 6'd6  : // SLTU: signed less than
  (opcode_decode == R_TYPE & funct3 == 3'b100 & funct7 == 7'b0000000) ? 6'd8  : // XOR: xor
  (opcode_decode == R_TYPE & funct3 == 3'b101 & funct7 == 7'b0000000) ? 6'd12 : // SRL: logical right shift
  (opcode_decode == R_TYPE & funct3 == 3'b101 & funct7 == 7'b0100000) ? 6'd13 : // SRA: arithmetic right shift
  (opcode_decode == R_TYPE & funct3 == 3'b110 & funct7 == 7'b0000000) ? 6'd9  : // OR: or
  (opcode_decode == R_TYPE & funct3 == 3'b111 & funct7 == 7'b0000000) ? 6'd10 : // AND: and
  6'd0; // Use addition by default

assign operand_A_sel = (opcode_decode == AUIPC) ?  2'b01 :
                       (opcode_decode == LUI)   ?  2'b11 :
                       ((opcode_decode == JALR)  | (opcode_decode == JAL)) ? 2'b10 : 2'b00;

assign operand_B_sel = (opcode_decode == I_TYPE) | (opcode_decode == STORE) |
                       (opcode_decode == LOAD)   | (opcode_decode == AUIPC) |
                       (opcode_decode == LUI);

assign extend_sel    = ((opcode_decode == I_TYPE) | (opcode_decode == LOAD)) ? 2'b00 :
                       (opcode_decode == STORE)                       ? 2'b01 :
                       ((opcode_decode == AUIPC)  | (opcode_decode == LUI))  ? 2'b10 : 2'b00;

assign target_PC = (opcode_execute == JALR)                    ? JALR_target_execute   :
                   (opcode_execute == BRANCH) & branch_execute ? branch_target_execute :
                   (opcode_decode  == JAL)                     ? JAL_target_decode     :
                   {ADDRESS_BITS{1'b0}};

assign next_PC_sel = JALR_branch_hazard ? 2'b10 : // target_PC
                     true_data_hazard   ? 2'b01 : // stall
                     JAL_hazard         ? 2'b10 : // targeet_PC
                     i_mem_hazard       ? 2'b01 : // stall
                     d_mem_hazard       ? 2'b01 : // stall
                     2'b00;                       // PC + 4

assign i_mem_read = 1'b1;

reg [31: 0] cycles;
always @ (posedge clock) begin
  cycles <= reset? 0 : cycles + 1;
  if (scan  & ((cycles >= SCAN_CYCLES_MIN) & (cycles <= SCAN_CYCLES_MAX)) )begin
    $display ("------ Core %d Control Unit - Current Cycle %d ------", CORE, cycles);
    $display ("| Opcode decode  [%b]", opcode_decode);
    $display ("| Opcode execute [%b]", opcode_execute);
    $display ("| Branch_op      [%b]", branch_op);
    $display ("| memRead        [%b]", memRead);
    $display ("| memWrite       [%b]", memWrite);
    $display ("| RegWrite       [%b]", regWrite);
    $display ("| ALU_operation  [%b]", ALU_operation);
    $display ("| Extend_sel     [%b]", extend_sel);
    $display ("| ALUSrc_A       [%b]", operand_A_sel);
    $display ("| ALUSrc_B       [%b]", operand_B_sel);
    $display ("| Next PC sel    [%b]", next_PC_sel);
    $display ("| Target PC      [%h]", target_PC);
    $display ("----------------------------------------------------------------------");
  end
end
endmodule
