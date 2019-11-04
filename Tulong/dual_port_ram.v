`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 11/03/2019 05:44:09 PM
// Design Name: 
// Module Name: dual_port_ram
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


/** @module : dual_port_ram
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

module dual_port_ram
#(
parameter
DATA_WIDTH    = 32,
ADDRESS_WIDTH = 32,
INDEX_BITS    = 6
)
(
input clock,
input we0, we1,
input  [DATA_WIDTH-1:0]    data_in0, 
input  [DATA_WIDTH-1:0]    data_in1, 
input  [ADDRESS_WIDTH-1:0] address0,
input  [ADDRESS_WIDTH-1:0] address1,
output reg [DATA_WIDTH-1:0] data_out0,
output reg [DATA_WIDTH-1:0] data_out1
);
	
localparam RAM_DEPTH = 1 << INDEX_BITS;

reg [DATA_WIDTH-1:0] mem [0:RAM_DEPTH-1];

wire port0_we;

assign port0_we = we0 & ~(we1 & (address0 == address1));

// port A
always@(posedge clock)begin
  if(port0_we) begin
    mem[address0] <= data_in0;
	  data_out0     <= data_in0;
  end
  else begin
	  data_out0 <= mem[address0];
  end
end

// port B
always@(posedge clock)begin
  if(we1) begin
    mem[address1]  <= data_in1;
	  data_out1      <= data_in1;
  end
  else begin
	  data_out1 <= mem[address1];
  end
end


endmodule
