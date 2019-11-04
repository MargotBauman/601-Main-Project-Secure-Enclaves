`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 11/03/2019 06:15:53 PM
// Design Name: 
// Module Name: L1cache_wrapper
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


/** @module : L1cache_wrapper
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
 
module L1cache_wrapper #(
parameter STATUS_BITS       =  2,
          COHERENCE_BITS    =  2,
          CACHE_OFFSET_BITS =  2,
          DATA_WIDTH        = 32,
          NUMBER_OF_WAYS    =  4,
          ADDRESS_BITS      = 32,
          INDEX_BITS        =  8,
          MSG_BITS          =  4,
		      BUS_OFFSET_BITS   =  0,
		      MAX_OFFSET_BITS   =  3,
          REPLACEMENT_MODE  =  1'b0,
          CORE              =  0,
          CACHE_NO          =  0
)(
  clock,
  reset,
  //processor interface
  read, 
  write, 
  invalidate, 
  flush,
  address,
  data_in,
  report,
  data_out,
  out_address,
  ready,
  valid,
  //bus interface
  bus_msg_in,
  bus_address_in,
  bus_data_in,
  bus_msg_out,
  bus_address_out,
  bus_data_out,
  active_offset,
  bus_master,
  req_ready,
  curr_offset
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

//local parameters
localparam CACHE_WORDS = 1 << CACHE_OFFSET_BITS;
localparam BUS_WORDS   = 1 << BUS_OFFSET_BITS;
localparam CACHE_WIDTH = CACHE_WORDS * DATA_WIDTH;
localparam BUS_WIDTH   = BUS_WORDS   * DATA_WIDTH; 
localparam TAG_BITS    = ADDRESS_BITS - INDEX_BITS - CACHE_OFFSET_BITS;
localparam WAY_BITS    = (NUMBER_OF_WAYS > 1) ? log2(NUMBER_OF_WAYS) : 1;
localparam SBITS       = COHERENCE_BITS + STATUS_BITS;

//THIS SECTION ADDED FROM C FILE
//bus messages
localparam NO_REQ     = 4'd0,
           R_REQ      = 4'd1,
           WB_REQ     = 4'd2,
           FLUSH      = 4'd3,
           FLUSH_S    = 4'd4,
           WS_BCAST   = 4'd5,
           RFO_BCAST  = 4'd6,
           C_WB       = 4'd7,
           C_FLUSH    = 4'd8,
           EN_ACCESS  = 4'd9,
           MEM_RESP   = 4'd10,
           MEM_RESP_S = 4'd11,
           MEM_C_RESP = 4'd12,
           REQ_FLUSH  = 4'd13,
           HOLD_BUS   = 4'd14;



// coherence states
localparam INVALID   = 2'b00,
           EXCLUSIVE = 2'b01,
           SHARED    = 2'b11,
           MODIFIED  = 2'b10;
//END DECTION FROM C FILE

//port definitions
input  clock, reset;
input  read, write, invalidate, flush;
input  [ADDRESS_BITS-1:0] address;
input  [DATA_WIDTH-1  :0] data_in;
input  report;
output [DATA_WIDTH-1  :0] data_out;
output [ADDRESS_BITS-1:0] out_address;
output ready, valid;

input  [MSG_BITS-1    :0] bus_msg_in;
input  [ADDRESS_BITS-1:0] bus_address_in;
input  [BUS_WIDTH-1   :0] bus_data_in;
input  bus_master;
input  req_ready;
input [log2(MAX_OFFSET_BITS):0] curr_offset;
output [MSG_BITS-1    :0] bus_msg_out;
output [ADDRESS_BITS-1:0] bus_address_out;
output [BUS_WIDTH-1   :0] bus_data_out;
output [log2(MAX_OFFSET_BITS):0] active_offset;


//internal wires
wire i_reset;
wire snoop_action;

wire [CACHE_WIDTH-1   :0] ctrl_data_out0, ctrl_data_out1;
wire [CACHE_WIDTH-1   :0] ctrl_data_in0;
wire [INDEX_BITS-1    :0] ctrl_index0, ctrl_index1;
wire [TAG_BITS-1      :0] ctrl_tag_in0, ctrl_tag_out0, ctrl_tag_out1;
wire [COHERENCE_BITS-1:0] ctrl_coh_bits0, ctrl_coh_bits1;
wire [SBITS-1         :0] ctrl_metadata0, ctrl_metadata1;
wire [WAY_BITS-1      :0] ctrl_matched_way0;
wire [WAY_BITS-1      :0] ctrl_way_select0, ctrl_way_select1;
wire [STATUS_BITS-1   :0] ctrl_status_bits0;
wire ctrl_hit0;
wire ctrl_read0, ctrl_write0, ctrl_invalidate0;
wire ctrl_read1, ctrl_write1, ctrl_invalidate1;

wire [CACHE_WIDTH-1   :0] mem_data_in0, mem_data_in1;
wire [CACHE_WIDTH-1   :0] mem_data_out0, mem_data_out1;
wire [INDEX_BITS-1    :0] mem_index0, mem_index1;
wire [TAG_BITS-1      :0] mem_tag_in0, mem_tag_in1, mem_tag_out0, mem_tag_out1;
wire [WAY_BITS-1      :0] mem_matched_way0, mem_matched_way1;
wire [WAY_BITS-1      :0] mem_way_select0, mem_way_select1;
wire [COHERENCE_BITS-1:0] mem_coh_bits0, mem_coh_bits1;
wire [SBITS-1         :0] mem_metadata0, mem_metadata1;
wire [STATUS_BITS-1   :0] mem_status_bits0, mem_status_bits1;
wire mem_hit0, mem_hit1;
wire mem_read0, mem_read1, mem_write0, mem_write1;
wire mem_invalidate0, mem_invalidate1;

wire [CACHE_WIDTH-1   :0] snooper_data_in, snooper_data_out;
wire [TAG_BITS-1      :0] snooper_tag_out;
wire [INDEX_BITS-1    :0] snooper_index;
wire [WAY_BITS-1      :0] snooper_matched_way;
wire [WAY_BITS-1      :0] snooper_way_select;
wire [COHERENCE_BITS-1:0] snooper_coh_bits;
wire [SBITS-1         :0] snooper_metadata;
wire [STATUS_BITS-1   :0] snooper_status_bits;
wire snooper_hit;
wire snooper_read, snooper_write, snooper_invalidate;

wire [MSG_BITS-1    :0] cache2intf_msg, intf2cache_msg;
wire [ADDRESS_BITS-1:0] cache2intf_addr, intf2cache_addr;
wire [CACHE_WIDTH-1 :0] cache2intf_data, intf2cache_data;
wire [MSG_BITS-1    :0] snooper2intf_msg, intf2snooper_msg;
wire [ADDRESS_BITS-1:0] snooper2intf_addr, intf2snooper_addr;
wire [CACHE_WIDTH-1 :0] snooper2intf_data, intf2snooper_data;



//assignments
assign snoop_action = snooper_read | snooper_write | snooper_invalidate;

assign mem_read0       = ctrl_read0;
assign mem_write0      = ctrl_write0;
assign mem_invalidate0 = ctrl_invalidate0;
assign mem_index0      = ctrl_index0;
assign mem_tag_in0     = ctrl_tag_out0;
assign mem_metadata0   = ctrl_metadata0;
assign mem_data_in0    = ctrl_data_out0;
assign mem_way_select0 = ctrl_way_select0;
assign mem_read1       = snoop_action ? snooper_read : ctrl_read1;
assign mem_write1      = snoop_action ? snooper_write : ctrl_write1;
assign mem_invalidate1 = snoop_action ? snooper_invalidate : ctrl_invalidate1;
assign mem_index1      = snoop_action ? snooper_index : ctrl_index1;
assign mem_tag_in1     = snoop_action ? snooper_tag_out : ctrl_tag_out1;
assign mem_metadata1   = snoop_action ? snooper_metadata : ctrl_metadata1;
assign mem_data_in1    = snoop_action ? snooper_data_out : ctrl_data_out1;
assign mem_way_select1 = snoop_action ? snooper_way_select : ctrl_way_select1;

assign ctrl_data_in0     = mem_data_out0;
assign ctrl_tag_in0      = mem_tag_out0;
assign ctrl_matched_way0 = mem_matched_way0;
assign ctrl_coh_bits0    = mem_coh_bits0;
assign ctrl_status_bits0 = mem_status_bits0;
assign ctrl_hit0         = mem_hit0;

assign snooper_data_in     = mem_data_out1;
assign snooper_matched_way = mem_matched_way1;
assign snooper_coh_bits    = mem_coh_bits1;
assign snooper_status_bits = mem_status_bits1;
assign snooper_hit         = mem_hit1;



//instantiate cache controller
cache_controller #(
  .STATUS_BITS(STATUS_BITS),
  .COHERENCE_BITS(COHERENCE_BITS),
  .OFFSET_BITS(CACHE_OFFSET_BITS),
  .DATA_WIDTH(DATA_WIDTH),
  .NUMBER_OF_WAYS(NUMBER_OF_WAYS),
  .ADDRESS_BITS(ADDRESS_BITS),
  .INDEX_BITS(INDEX_BITS),
  .MSG_BITS(MSG_BITS),
  .CORE(0),
  .CACHE_NO(0)
) controller (
  .clock(clock), 
  .reset(reset),
  .read(read), 
  .write(write),
  .invalidate(invalidate), 
  .flush(flush),
  .address(address),
  .data_in(data_in),
  .report(report),
  .data_out(data_out),
  .out_address(out_address),
  .ready(ready),
  .valid(valid),

  .data_in0(ctrl_data_in0),
  .tag_in0(ctrl_tag_in0),
  .matched_way0(ctrl_matched_way0),
  .coh_bits0(ctrl_coh_bits0),
  .status_bits0(ctrl_status_bits0),
  .hit0(ctrl_hit0),
  .read0(ctrl_read0), 
  .write0(ctrl_write0), 
  .invalidate0(ctrl_invalidate0),
  .index0(ctrl_index0),
  .tag0(ctrl_tag_out0),
  .meta_data0(ctrl_metadata0),
  .data_out0(ctrl_data_out0),
  .way_select0(ctrl_way_select0),
  .read1(ctrl_read1), 
  .write1(ctrl_write1), 
  .invalidate1(ctrl_invalidate1),
  .index1(ctrl_index1),
  .tag1(ctrl_tag_out1),
  .meta_data1(ctrl_metadata1),
  .data_out1(ctrl_data_out1),
  .way_select1(ctrl_way_select1),
  .i_reset(i_reset),

  .mem2cache_msg(intf2cache_msg),
  .mem2cache_data(intf2cache_data),
  .mem2cache_address(intf2cache_addr),
  .cache2mem_msg(cache2intf_msg),
  .cache2mem_data(cache2intf_data),
  .cache2mem_address(cache2intf_addr),

  .snoop_address({snooper_tag_out, snooper_index, {CACHE_OFFSET_BITS{1'b0}}}),
  .snoop_read(snooper_read),
  .snoop_modify(snooper_write | snooper_invalidate)
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
  .read0(mem_read0), 
  .write0(mem_write0),
  .invalidate0(mem_invalidate0),
  .index0(mem_index0),
  .tag0(mem_tag_in0),
  .meta_data0(mem_metadata0),
  .data_in0(mem_data_in0),
  .way_select0(mem_way_select0),
  .data_out0(mem_data_out0),
  .tag_out0(mem_tag_out0),
  .matched_way0(mem_matched_way0),
  .coh_bits0(mem_coh_bits0),
  .status_bits0(mem_status_bits0),
  .hit0(mem_hit0),
  //port 1
  .read1(mem_read1),
  .write1(mem_write1),
  .invalidate1(mem_invalidate1),
  .index1(mem_index1),
  .tag1(mem_tag_in1),
  .meta_data1(mem_metadata1),
  .data_in1(mem_data_in1),
  .way_select1(mem_way_select1),
  .data_out1(mem_data_out1),
  .tag_out1(mem_tag_out1),
  .matched_way1(mem_matched_way1),
  .coh_bits1(mem_coh_bits1),
  .status_bits1(mem_status_bits1),
  .hit1(mem_hit1),
  
  .report(report)
);


//instantiate snooper
snooper #(
  .CACHE_OFFSET_BITS(CACHE_OFFSET_BITS),
  .BUS_OFFSET_BITS(BUS_OFFSET_BITS),
  .DATA_WIDTH(DATA_WIDTH),
  .ADDRESS_WIDTH(ADDRESS_BITS),
  .MSG_BITS(MSG_BITS),
  .INDEX_BITS(INDEX_BITS),
  .COHERENCE_BITS(COHERENCE_BITS),
  .STATUS_BITS(STATUS_BITS),
  .NUMBER_OF_WAYS(NUMBER_OF_WAYS),
  .MAX_OFFSET_BITS(MAX_OFFSET_BITS)
) snooper (
  .clock(clock),
  .reset(i_reset),
  .data_in(snooper_data_in),
  .matched_way(snooper_matched_way),
  .coh_bits(snooper_coh_bits),
  .status_bits(snooper_status_bits),
  .hit(snooper_hit),
  .read(snooper_read), 
  .write(snooper_write),
  .invalidate(snooper_invalidate),
  .index(snooper_index),
  .tag(snooper_tag_out),
  .meta_data(snooper_metadata),
  .data_out(snooper_data_out),
  .way_select(snooper_way_select),
  
  .intf_msg(intf2snooper_msg),
  .intf_address(intf2snooper_addr),
  .intf_data(intf2snooper_data),
  .snoop_msg(snooper2intf_msg),
  .snoop_address(snooper2intf_addr),
  .snoop_data(snooper2intf_data),
  
  .bus_msg(bus_msg_in),
  .bus_address(bus_address_in),
  .req_ready(req_ready),
  .bus_master(bus_master),
  .curr_offset(curr_offset)
);


//instantiate bus interface
L1_bus_interface #(
  .CACHE_OFFSET_BITS(CACHE_OFFSET_BITS),
  .BUS_OFFSET_BITS(BUS_OFFSET_BITS),
  .DATA_WIDTH(DATA_WIDTH),
  .ADDRESS_WIDTH(ADDRESS_BITS),
  .MSG_BITS(MSG_BITS),
  .MAX_OFFSET_BITS(MAX_OFFSET_BITS)
) bus_interface (
  .clock(clock), 
  .reset(i_reset),
  .cache_offset(CACHE_OFFSET_BITS),
  
  .cache_msg_in(cache2intf_msg),
  .cache_address_in(cache2intf_addr),
  .cache_data_in(cache2intf_data),
  .cache_msg_out(intf2cache_msg),
  .cache_address_out(intf2cache_addr),
  .cache_data_out(intf2cache_data),
  
  .snoop_msg_in(snooper2intf_msg),
  .snoop_address_in(snooper2intf_addr),
  .snoop_data_in(snooper2intf_data),
  .snoop_msg_out(intf2snooper_msg),
  .snoop_address_out(intf2snooper_addr),
  .snoop_data_out(intf2snooper_data),
  
  .bus_msg_in(bus_msg_in),
  .bus_address_in(bus_address_in),
  .bus_data_in(bus_data_in),
  .bus_msg_out(bus_msg_out),
  .bus_address_out(bus_address_out),
  .bus_data_out(bus_data_out),
  .active_offset(active_offset),
 
  .bus_master(bus_master),
  .req_ready(req_ready)
);

endmodule

