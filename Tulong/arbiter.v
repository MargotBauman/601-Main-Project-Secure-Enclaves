`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 11/03/2019 05:30:59 PM
// Design Name: 
// Module Name: arbiter
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


/** @module : arbiter
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

module arbiter #(
  parameter WIDTH = 4
) (
  clock, 
  reset,
  requests,
  grant
);

//define the log2 function
function integer log2;
input integer value;
begin
  value = value-1;
  for (log2=0; value>0; log2=log2+1)
    value = value >> 1;
end
endfunction

input clock, reset;
input [WIDTH-1 : 0] requests;
output [log2(WIDTH)-1 : 0] grant;

integer j;
reg [WIDTH-1 : 0] mask;
wire [WIDTH-1 : 0] masked_requests;
wire masked_valid, unmasked_valid;
wire [log2(WIDTH)-1 : 0] masked_encoded, unmasked_encoded;


// Instantiate priority encoders
priority_encoder #(WIDTH, "LSB") 
  masked_encoder(masked_requests, masked_encoded, masked_valid);
priority_encoder #(WIDTH, "LSB") 
  unmasked_encoder(requests, unmasked_encoded, unmasked_valid);

always @(posedge clock)begin
  if(reset)
    mask       <= {WIDTH{1'b1}};
  else begin
    for(j=0; j<WIDTH; j=j+1)begin
      mask[j] <= (j < grant) ? 0 : 1;
    end
  end
end

assign masked_requests = requests & mask;
assign grant = (masked_requests == 0)   ? unmasked_encoded : masked_encoded;

endmodule
