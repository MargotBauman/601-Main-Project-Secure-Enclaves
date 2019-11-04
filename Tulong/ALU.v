`timescale 1ns / 1ps
/** @module : ALU
 *  @author : Adaptive & Secure Computing Systems (ASCS) Laboratory

 *  Copyright (c) 2019 BRISC-V (ASCS/ECE/BU)
 *  Permission is hereby granted, free of charge, to any person obtaining a copy
 *  of this software and associated documentation files (the "Software"), to deal
 *  in the Software without restriction, including without limitation the rights
 *  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 *  copies of the Software, and to permit persons to whom the Software is
 *  furnished to do so, subject to the following conditions:
 *  The above copyright notice and this permission notice shall be included in
 *  all copies or substantial portions of the Software.

 *  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 *  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 *  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 *  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 *  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 *  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 *  THE SOFTWARE.
 */

module ALU #(
  parameter DATA_WIDTH = 32
) (
  input [5:0] ALU_operation,
  input [DATA_WIDTH-1:0] operand_A,
  input [DATA_WIDTH-1:0] operand_B,
  output [DATA_WIDTH-1:0] ALU_result
);

wire signed [DATA_WIDTH-1:0] signed_operand_A;
wire signed [DATA_WIDTH-1:0] signed_operand_B;

wire [4:0] shamt;

// wires for signed operations
wire [(DATA_WIDTH*2)-1:0] arithmetic_right_shift_double;
wire [DATA_WIDTH-1:0] arithmetic_right_shift;
wire signed [DATA_WIDTH-1:0] signed_less_than;
wire signed [DATA_WIDTH-1:0] signed_greater_than_equal;

assign shamt = operand_B [4:0];     // I_immediate[4:0];

assign signed_operand_A = operand_A;
assign signed_operand_B = operand_B;

// Signed Operations
assign arithmetic_right_shift_double = ({ {DATA_WIDTH{operand_A[DATA_WIDTH-1]}}, operand_A }) >> shamt;
assign arithmetic_right_shift = arithmetic_right_shift_double[DATA_WIDTH-1:0];
assign signed_less_than = signed_operand_A < signed_operand_B;
assign signed_greater_than_equal = signed_operand_A >= signed_operand_B;

assign ALU_result =
  (ALU_operation == 6'd0 )? operand_A + operand_B:     /* ADD, ADDI, LB, LH, LW,
                                                          LBU, LHU, SB, SH, SW,
                                                          AUIPC, LUI */
  (ALU_operation == 6'd1 )? operand_A:                 /* JAL, JALR */
  (ALU_operation == 6'd2 )? operand_A == operand_B:    /* BEQ */
  (ALU_operation == 6'd3 )? operand_A != operand_B:    /* BNE */
  (ALU_operation == 6'd4 )? signed_less_than:          /* BLT, SLTI, SLT */
  (ALU_operation == 6'd5 )? signed_greater_than_equal: /* BGE */
  (ALU_operation == 6'd6 )? operand_A < operand_B:     /* BLTU, SLTIU, SLTU*/
  (ALU_operation == 6'd7 )? operand_A >= operand_B:    /* BGEU */
  (ALU_operation == 6'd8 )? operand_A ^ operand_B:     /* XOR, XORI*/
  (ALU_operation == 6'd9 )? operand_A | operand_B:     /* OR, ORI */
  (ALU_operation == 6'd10)? operand_A & operand_B:     /* AND, ANDI */
  (ALU_operation == 6'd11)? operand_A << shamt:        /* SLL, SLLI */
  (ALU_operation == 6'd12)? operand_A >> shamt:        /* SRL, SRLI */
  (ALU_operation == 6'd13)? arithmetic_right_shift:    /* SRA, SRAI */
  (ALU_operation == 6'd14)? operand_A - operand_B:     /* SUB */
  {DATA_WIDTH{1'b0}};

endmodule
