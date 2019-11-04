/** @module : memory_issue
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

module memory_issue #(
  parameter CORE            =    0,
  parameter DATA_WIDTH      =   32,
  parameter ADDRESS_BITS    =   20,
  parameter SCAN_CYCLES_MIN =    0,
  parameter SCAN_CYCLES_MAX = 1000
) (

  // Execute stage interface
  input load,
  input store,
  input [ADDRESS_BITS-1:0] address,
  input [DATA_WIDTH-1:0] store_data,

  // Memory interface
  output memory_read,
  output memory_write,
  output [ADDRESS_BITS-1:0] memory_address,
  output [DATA_WIDTH-1:0] memory_data,

  // Scan signal
  input scan

);


assign memory_read    = load;
assign memory_write   = store;
assign memory_address = address >> 2;
assign memory_data    = store_data;

endmodule
