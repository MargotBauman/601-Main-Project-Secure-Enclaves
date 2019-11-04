`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 11/03/2019 06:26:03 PM
// Design Name: 
// Module Name: priority_encoder
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


/** @module : priority_encoder
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

module priority_encoder #(
  parameter WIDTH    = 8,
  parameter PRIORITY = "MSB"
) (
  decode,
  encode,
  valid
);

//Define the log2 function
function integer log2;
input integer value;
begin
  value = value-1;
  for(log2=0; value>0; log2=log2+1)
    value = value>>1;
  end
endfunction

input [WIDTH-1 : 0] decode;
output [log2(WIDTH)-1 : 0] encode;
output valid;

generate
  wire encoded_half_valid;
  wire half_has_one;

  if (WIDTH==2)begin
    assign valid = decode[1] | decode [0];
    assign encode = ((PRIORITY == "LSB") & decode[0]) ? 0 : decode[1];
  end
  else begin
    assign half_has_one = (PRIORITY == "LSB") ? |decode[(WIDTH/2)-1 : 0] 
                        : |decode[WIDTH-1 : WIDTH/2];
    assign encode[log2(WIDTH)-1] = ((PRIORITY == "MSB") & half_has_one) ? 1 
                                 : ((PRIORITY == "LSB") & ~half_has_one & 
                                   valid) ? 1
                                 : 0;
    assign valid = half_has_one | encoded_half_valid;

    if(PRIORITY == "MSB")
      priority_encoder #((WIDTH/2), PRIORITY) 
      decode_half (
        .decode(half_has_one ? decode[WIDTH-1 : WIDTH/2] : 
          decode[(WIDTH/2)-1 : 0]),
        .encode(encode[log2(WIDTH)-2 : 0]),
        .valid(encoded_half_valid)	
      );

    else
      priority_encoder #((WIDTH/2), PRIORITY) 
      decode_half (
        .decode(half_has_one ? decode[(WIDTH/2)-1 : 0] : decode[WIDTH-1 :
         WIDTH/2]),
        .encode(encode[log2(WIDTH)-2 : 0]),
        .valid(encoded_half_valid)	
      );
  end
endgenerate


endmodule

