`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 11/03/2019 06:12:03 PM
// Design Name: 
// Module Name: dual_port_ram_with_pass_through
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


/** @module : dual_port_ram_with_pass_through
 *  @author : Adaptive & Secure Computing Systems (ASCS) Laboratory

 *  Copyright (c) 2018 BRISC-V (ASCS/ECE/BU)
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
 
 module dual_port_ram_with_pass_through #(
parameter DATA_WIDTH    = 32,
          ADDRESS_WIDTH = 32,
          INDEX_BITS    = 6,
          RW            = "OLD_DATA"
)
(
input clock,
input we0, we1,
input  [DATA_WIDTH-1:0]    data_in0, 
input  [DATA_WIDTH-1:0]    data_in1, 
input  [ADDRESS_WIDTH-1:0] address0,
input  [ADDRESS_WIDTH-1:0] address1,
output [DATA_WIDTH-1:0]   data_out0,
output [DATA_WIDTH-1:0]   data_out1
);

reg r_we0, r_we1;
reg [ADDRESS_WIDTH-1:0] r_address0, r_address1;

wire [DATA_WIDTH-1:0] t_data_out0, t_data_out1;

always @(posedge clock)begin
  r_address0 <= address0;
  r_address1 <= address1;
  r_we0      <= we0;
  r_we1      <= we1;
end

// instantiate basic dual port RAM
dual_port_ram #(
  .DATA_WIDTH(DATA_WIDTH),
  .ADDRESS_WIDTH(ADDRESS_WIDTH),
  .INDEX_BITS(INDEX_BITS)
) RAM (
  .clock(clock),
  .we0(we0), 
  .we1(we1),
  .data_in0(data_in0), 
  .data_in1(data_in1), 
  .address0(address0),
  .address1(address1),
  .data_out0(t_data_out0),
  .data_out1(t_data_out1)
);

// pass through logic
assign data_out0 = r_we1 & (r_address1 == r_address0) & (RW == "NEW_DATA") ?
                   t_data_out1 : t_data_out0;
assign data_out1 = r_we0 & (r_address0 == r_address1) & (RW == "NEW_DATA") ?
                   t_data_out0 : t_data_out1;

endmodule

