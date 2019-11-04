`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 11/03/2019 06:21:46 PM
// Design Name: 
// Module Name: Lxcache_wrapper
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


/** @module : Lxcache_wrapper
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

module Lxcache_wrapper #(
parameter STATUS_BITS       = 3,
          COHERENCE_BITS    = 2,
          CACHE_OFFSET_BITS = 2,
          DATA_WIDTH        = 32,
          NUMBER_OF_WAYS    = 4,
          REPLACEMENT_MODE  = 0,
          ADDRESS_BITS      = 32,
          INDEX_BITS        = 10,
          MSG_BITS          = 4,
          BUS_OFFSET_BITS   = 1,
          MAX_OFFSET_BITS   = 3
)(
clock, 
reset,
address,
data_in,
msg_in,
req_ready,
req_offset,
report,
data_out,
out_address,
msg_out,
active_offset,

mem2cache_msg,
mem2cache_address,
mem2cache_data,
cache2mem_msg,
cache2mem_address,
cache2mem_data
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

//localparameters
localparam CACHE_WORDS = 1 << CACHE_OFFSET_BITS;
localparam BUS_WORDS   = 1 << BUS_OFFSET_BITS;
localparam CACHE_WIDTH = DATA_WIDTH*CACHE_WORDS;
localparam BUS_WIDTH   = DATA_WIDTH*BUS_WORDS;
localparam TAG_BITS    = ADDRESS_BITS - CACHE_OFFSET_BITS - INDEX_BITS;
localparam MBITS       = COHERENCE_BITS + STATUS_BITS;
localparam WAY_BITS    = (NUMBER_OF_WAYS > 1) ? log2(NUMBER_OF_WAYS) : 1;


input  clock; 
input  reset;
input  [ADDRESS_BITS-1:0] address;
input  [BUS_WIDTH-1   :0] data_in;
input  [MSG_BITS-1    :0] msg_in;
input  req_ready;
input  [log2(MAX_OFFSET_BITS):0] req_offset;
input  report;
output [BUS_WIDTH-1   :0] data_out;
output [ADDRESS_BITS-1:0] out_address;
output [MSG_BITS-1    :0] msg_out;
output [log2(MAX_OFFSET_BITS):0] active_offset;

input  [MSG_BITS-1    :0] mem2cache_msg;
input  [ADDRESS_BITS-1:0] mem2cache_address;
input  [CACHE_WIDTH-1 :0] mem2cache_data;
output [MSG_BITS-1    :0] cache2mem_msg;
output [ADDRESS_BITS-1:0] cache2mem_address;
output [CACHE_WIDTH-1 :0] cache2mem_data;


//internal connections
wire [MSG_BITS-1:0] intf2ctrl_msg;
wire [ADDRESS_BITS-1:0] intf2ctrl_address;
wire [CACHE_WIDTH-1:0] intf2ctrl_data;
wire [MSG_BITS-1:0] ctrl2intf_msg;
wire [ADDRESS_BITS-1:0] ctrl2intf_address;
wire [CACHE_WIDTH-1:0] ctrl2intf_data;
wire read0;
wire write0;
wire invalidate0;
wire [INDEX_BITS-1:0] index0;
wire [TAG_BITS-1:0] tag0;
wire [MBITS-1:0] meta_data0;
wire [CACHE_WIDTH-1:0] data0;
wire [WAY_BITS-1:0] way_select0;
wire [CACHE_WIDTH-1:0] data_in0;
wire [TAG_BITS-1:0] tag_in0;
wire [WAY_BITS-1:0] matched_way0;
wire [COHERENCE_BITS-1:0] coh_bits0;
wire [STATUS_BITS-1:0] status_bits0;
wire hit0;
wire i_reset;


//instantiate Lx_bus_interface
Lx_bus_interface #(
  .CACHE_OFFSET_BITS(CACHE_OFFSET_BITS),
  .BUS_OFFSET_BITS(BUS_OFFSET_BITS),
  .DATA_WIDTH(DATA_WIDTH),
  .ADDRESS_WIDTH(ADDRESS_BITS),
  .MSG_BITS(MSG_BITS),
  .MAX_OFFSET_BITS(MAX_OFFSET_BITS)
) bus_interface (
  .clock(clock),
  .reset(reset),
  
  .bus_msg_in(msg_in),
  .bus_address_in(address),
  .bus_data_in(data_in),
  .bus_msg_out(msg_out),
  .bus_address_out(out_address),
  .bus_data_out(data_out),
  .req_offset(req_offset),
  .req_ready(req_ready),
  .active_offset(active_offset),
  
  .cache_msg_in(ctrl2intf_msg),
  .cache_address_in(ctrl2intf_address),
  .cache_data_in(ctrl2intf_data),
  .cache_msg_out(intf2ctrl_msg),
  .cache_address_out(intf2ctrl_address),
  .cache_data_out(intf2ctrl_data)
);


//instantiate cache_memory
cache_memory #(
  .STATUS_BITS(STATUS_BITS),
  .COHERENCE_BITS(COHERENCE_BITS),
  .OFFSET_BITS(CACHE_OFFSET_BITS),
  .DATA_WIDTH(DATA_WIDTH),
  .NUMBER_OF_WAYS(NUMBER_OF_WAYS),
  .REPLACEMENT_MODE(REPLACEMENT_MODE),
  .ADDRESS_BITS(ADDRESS_BITS),
  .INDEX_BITS(INDEX_BITS)
) memory (
  .clock(clock), 
  .reset(i_reset),
  //port 0
  .read0(read0),
  .write0(write0),
  .invalidate0(invalidate0),
  .index0(index0),
  .tag0(tag0),
  .meta_data0(meta_data0),
  .data_in0(data0),
  .way_select0(way_select0),
  .data_out0(data_in0),
  .tag_out0(tag_in0),
  .matched_way0(matched_way0),
  .coh_bits0(coh_bits0),
  .status_bits0(status_bits0),
  .hit0(hit0),
  //port 1
  .read1(1'b0),
  .write1(1'b0),
  .invalidate1(1'b0),
  .index1({INDEX_BITS{1'b0}}),
  .tag1({TAG_BITS{1'b0}}),
  .meta_data1({MBITS{1'b0}}),
  .data_in1({CACHE_WIDTH{1'b0}}),
  .way_select1({WAY_BITS{1'b0}}),
  .data_out1(),
  .tag_out1(),
  .matched_way1(),
  .coh_bits1(),
  .status_bits1(),
  .hit1(),
  
  .report(report)
);


//instantiate Lxcache_controller
Lxcache_controller #(
  .STATUS_BITS(STATUS_BITS),
  .COHERENCE_BITS(COHERENCE_BITS),
  .OFFSET_BITS(CACHE_OFFSET_BITS),
  .DATA_WIDTH(DATA_WIDTH),
  .NUMBER_OF_WAYS(NUMBER_OF_WAYS),
  .ADDRESS_BITS(ADDRESS_BITS),
  .INDEX_BITS(INDEX_BITS),
  .MSG_BITS(MSG_BITS)
) controller (
  .clock(clock),
  .reset(reset),
  .address(intf2ctrl_address),
  .data_in(intf2ctrl_data),
  .msg_in(intf2ctrl_msg),
  .report(report),
  .data_out(ctrl2intf_data),
  .out_address(ctrl2intf_address),
  .msg_out(ctrl2intf_msg),
  
  .mem2cache_msg(mem2cache_msg),
  .mem2cache_address(mem2cache_address),
  .mem2cache_data(mem2cache_data),
  .cache2mem_msg(cache2mem_msg),
  .cache2mem_address(cache2mem_address),
  .cache2mem_data(cache2mem_data),
  
  .read0(read0),
  .write0(write0),
  .invalidate0(invalidate0),
  .index0(index0),
  .tag0(tag0),
  .meta_data0(meta_data0),
  .data0(data0),
  .way_select0(way_select0),
  .i_reset(i_reset),
  .data_in0(data_in0),
  .tag_in0(tag_in0),
  .matched_way0(matched_way0),
  .coh_bits0(coh_bits0),
  .status_bits0(status_bits0),
  .hit0(hit0)
);


endmodule

