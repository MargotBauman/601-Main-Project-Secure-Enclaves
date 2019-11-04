/** @module : memory_unit
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

module memory_unit #(
  parameter CORE = 0,
  parameter DATA_WIDTH = 32,
  parameter ADDRESS_BITS = 20,
  parameter SCAN_CYCLES_MIN = 0,
  parameter SCAN_CYCLES_MAX = 1000
) (
  input clock,
  input reset,

  // Execute stage interface
  input load,
  input store,
  input [ADDRESS_BITS-1:0] address,
  input [DATA_WIDTH-1:0] store_data,

  // Memory interface
  input memory_ready,
  input memory_valid,
  input [DATA_WIDTH-1:0] memory_data_out,
  input [ADDRESS_BITS-1:0] memory_address_out,
  output memory_read,
  output memory_write,
  output [ADDRESS_BITS-1:0] memory_address,
  output [DATA_WIDTH-1:0] memory_data,

  // Writeback interface
  output [DATA_WIDTH-1:0] load_data,

  input scan


);

memory_issue #(
  .CORE(CORE),
  .DATA_WIDTH(DATA_WIDTH),
  .ADDRESS_BITS(ADDRESS_BITS)
) mem_issue (

  // Execute stage interface
  .load(load),
  .store(store),
  .address(address),
  .store_data(store_data),

  // Memory interface
  .memory_ready(memory_ready),
  .memory_read(memory_read),
  .memory_write(memory_write),
  .memory_address(memory_address),
  .memory_data(memory_data),

  .scan(scan)

);


memory_receive #(
  .CORE(CORE),
  .DATA_WIDTH(DATA_WIDTH),
  .ADDRESS_BITS(ADDRESS_BITS)
) mem_receive (
  // Memory interface
  .memory_valid(memory_valid),
  .memory_data_out(memory_data_out),
  .memory_address_out(memory_address_out),

  // Writeback interface
  .load_data(load_data),

  .scan(scan)

);

reg [31: 0] cycles;
always @ (posedge clock) begin
  cycles <= reset? 0 : cycles + 1;
  if (scan  & ((cycles >= SCAN_CYCLES_MIN) & (cycles <= SCAN_CYCLES_MAX)) )begin
    $display ("------ Core %d Memory Unit - Current Cycle %d -------", CORE, cycles);
    $display ("| Address            [%h]", address);
    $display ("| Load               [%b]", load);
    $display ("| Load Data          [%h]", load_data);
    $display ("| Store              [%b]", store);
    $display ("| Store Data         [%h]", store_data);
    $display ("| Memory Ready       [%b]", memory_ready);
    $display ("| Memory Valid       [%b]", memory_valid);
    $display ("| Memory Data Out    [%h]", memory_data_out);
    $display ("| Memory Address Out [%h]", memory_address_out);
    $display ("| Memory Read        [%b]", memory_read);
    $display ("| Memory Write       [%b]", memory_write);
    $display ("| Memory Address     [%h]", memory_address);
    $display ("| Memory Data        [%h]", memory_data);
    $display ("----------------------------------------------------------------------");
  end
end

endmodule
