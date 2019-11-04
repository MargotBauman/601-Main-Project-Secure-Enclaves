`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 11/03/2019 05:36:59 PM
// Design Name: 
// Module Name: cache_memory
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


/** @module : cache_memory
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

module cache_memory #(
parameter STATUS_BITS      =  2,
          COHERENCE_BITS   =  2,
          OFFSET_BITS      =  2,
          DATA_WIDTH       = 32,
          NUMBER_OF_WAYS   =  4,
          REPLACEMENT_MODE =  0,
          ADDRESS_BITS     = 32,
          INDEX_BITS       =  8
)(
clock, reset,
//port 0
read0, write0, invalidate0,
index0,
tag0,
meta_data0,
data_in0,
way_select0,
data_out0,
tag_out0,
matched_way0,
coh_bits0,
status_bits0,
hit0,
//port 1
read1, write1, invalidate1,
index1,
tag1,
meta_data1,
data_in1,
way_select1,
data_out1,
tag_out1,
matched_way1,
coh_bits1,
status_bits1,
hit1,

report
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

// Local parameters
localparam WORDS_PER_LINE = 1 << OFFSET_BITS;
localparam BLOCK_WIDTH    = DATA_WIDTH*WORDS_PER_LINE;
localparam SBITS          = COHERENCE_BITS + STATUS_BITS;
localparam TAG_BITS       = ADDRESS_BITS - OFFSET_BITS - INDEX_BITS;
localparam MBITS          = SBITS + TAG_BITS;
localparam WAY_BITS       = (NUMBER_OF_WAYS > 1) ? log2(NUMBER_OF_WAYS) : 1;
localparam CACHE_DEPTH    = 1 << INDEX_BITS;


input clock, reset;
input read0, write0, invalidate0;
input  [INDEX_BITS-1    :0] index0;
input  [TAG_BITS-1      :0] tag0;
input  [SBITS-1         :0] meta_data0;
input  [BLOCK_WIDTH-1   :0] data_in0;
input  [WAY_BITS-1      :0] way_select0;
output [BLOCK_WIDTH-1   :0] data_out0;
output [TAG_BITS-1      :0] tag_out0;
output [WAY_BITS-1      :0] matched_way0;
output [COHERENCE_BITS-1:0] coh_bits0;
output [STATUS_BITS-1   :0] status_bits0;
output hit0;

input read1, write1, invalidate1;
input  [INDEX_BITS-1    :0] index1;
input  [TAG_BITS-1      :0] tag1;
input  [SBITS-1         :0] meta_data1;
input  [BLOCK_WIDTH-1   :0] data_in1;
input  [WAY_BITS-1      :0] way_select1;
output [BLOCK_WIDTH-1   :0] data_out1;
output [TAG_BITS-1      :0] tag_out1;
output [WAY_BITS-1      :0] matched_way1;
output [COHERENCE_BITS-1:0] coh_bits1;
output [STATUS_BITS-1   :0] status_bits1;
output hit1;

input  report;


genvar i;

reg r_read0, r_read1;
reg [TAG_BITS-1:0] r_tag0, r_tag1;

//connections to BRAMs for data blocks
wire [NUMBER_OF_WAYS-1:0] we0_d, we1_d;
wire [BLOCK_WIDTH-1   :0] data_out0_d [NUMBER_OF_WAYS-1:0];
wire [BLOCK_WIDTH-1   :0] data_out1_d [NUMBER_OF_WAYS-1:0];

//connections to BRAMs for meta data storage (tag and status bits)
wire [NUMBER_OF_WAYS-1:0] we0_m, we1_m;
wire [MBITS-1         :0] data_in0_m   [NUMBER_OF_WAYS-1:0];
wire [MBITS-1         :0] data_in1_m   [NUMBER_OF_WAYS-1:0];
wire [COHERENCE_BITS-1:0] cohbits_out0 [NUMBER_OF_WAYS-1:0];
wire [COHERENCE_BITS-1:0] cohbits_out1 [NUMBER_OF_WAYS-1:0];
wire [TAG_BITS-1      :0] tag_0        [NUMBER_OF_WAYS-1:0];
wire [TAG_BITS-1      :0] tag_1        [NUMBER_OF_WAYS-1:0];
wire [STATUS_BITS-1   :0] status_line0 [NUMBER_OF_WAYS-1:0];
wire [STATUS_BITS-1   :0] status_line1 [NUMBER_OF_WAYS-1:0];
wire [NUMBER_OF_WAYS-1:0] valid_line0, valid_line1;

wire [NUMBER_OF_WAYS-1:0] tag_match0, tag_match1;
wire [WAY_BITS-1      :0] decoded_tag_match0, decoded_tag_match1;
wire valid_tag_match0, valid_tag_match1;

wire [NUMBER_OF_WAYS-1:0] replace_way_encoded;
wire [WAY_BITS-1      :0] replace_way;
wire valid_replace_way;
wire [INDEX_BITS-1    :0] replace_index;
wire [NUMBER_OF_WAYS-1:0] ways_in_use;
wire [WAY_BITS-1      :0] current_access;
wire access_valid;


//instantiate BRAMs
generate
  for(i=0; i<NUMBER_OF_WAYS; i=i+1)begin: DATA
    dual_port_ram_with_pass_through #(
      .DATA_WIDTH(BLOCK_WIDTH), 
      .ADDRESS_WIDTH(INDEX_BITS), 
      .INDEX_BITS(INDEX_BITS), 
      .RW("OLD_DATA")
    ) data_bram (
      .clock(clock),
      .we0(we0_d[i]),
      .we1(we1_d[i]),
      .data_in0(data_in0), 
      .data_in1(data_in1), 
      .address0(index0),
      .address1(index1),
      .data_out0(data_out0_d[i]),
      .data_out1(data_out1_d[i])
    );
  end
  for(i=0; i<NUMBER_OF_WAYS; i=i+1)begin: MDATA
    dual_port_ram_with_pass_through #(
      .DATA_WIDTH(MBITS), 
      .ADDRESS_WIDTH(INDEX_BITS), 
      .INDEX_BITS(INDEX_BITS), 
      .RW("OLD_DATA")
    ) mdata_bram (
      .clock(clock),
      .we0(we0_m[i]),
      .we1(we1_m[i]),
      .data_in0(data_in0_m[i]), 
      .data_in1(data_in1_m[i]), 
      .address0(index0),
      .address1(index1),
      .data_out0({status_line0[i], cohbits_out0[i], tag_0[i]}),
      .data_out1({status_line1[i], cohbits_out1[i], tag_1[i]})
    );
  end
endgenerate

//instantiate one-hot-decoders
generate
if(NUMBER_OF_WAYS > 1)begin
one_hot_decoder #(NUMBER_OF_WAYS) 
  decoder_0 (tag_match0, decoded_tag_match0, valid_tag_match0);
one_hot_decoder #(NUMBER_OF_WAYS) 
  decoder_1 (tag_match1, decoded_tag_match1, valid_tag_match1);
one_hot_decoder #(NUMBER_OF_WAYS) 
  decoder_2 (replace_way_encoded, replace_way, valid_replace_way);
end
else begin
  assign decoded_tag_match0 = 0;
  assign valid_tag_match0   = tag_match0;
  assign decoded_tag_match1 = 0;
  assign valid_tag_match1   = tag_match1;
  assign replace_way        = 0;
  assign valid_replace_way  = replace_way_encoded;
end
endgenerate

//instantiate replacement controller
generate
if(NUMBER_OF_WAYS > 1)begin: REPLACE
replacement_controller #(NUMBER_OF_WAYS, INDEX_BITS) 
  replace_inst(clock, reset, ways_in_use, replace_index, REPLACEMENT_MODE, 
  current_access, access_valid, report, replace_way_encoded);
end else
  assign replace_way_encoded = 1;
endgenerate


generate
  for(i=0; i<NUMBER_OF_WAYS; i=i+1)begin: VALID
    assign valid_line0[i] = status_line0[i][STATUS_BITS-1];
    assign valid_line1[i] = status_line1[i][STATUS_BITS-1];
  end
endgenerate

//tag comparison
generate
  for(i=0; i<NUMBER_OF_WAYS; i=i+1)begin: TAG_COMP
    assign tag_match0[i] = valid_line0[i] & (r_tag0 == tag_0[i]);
    assign tag_match1[i] = valid_line1[i] & (r_tag1 == tag_1[i]);
  end
endgenerate

assign ways_in_use    = valid_line0;
assign replace_index  = index0;
assign current_access = write0 ? way_select0 : decoded_tag_match0;
assign access_valid   = write0 | (r_read0 & valid_tag_match0);

generate
  for(i=0; i<NUMBER_OF_WAYS; i=i+1)begin: W_EN
    assign we0_d[i] = ((i == way_select0) & write0 & ~((index0 == index1) & 
                      (way_select0 == way_select1) & write1)) | reset;
    assign we1_d[i] = (i == way_select1) & write1;
    assign we0_m[i] = reset | ((i == way_select0) & (write0 | invalidate0) & 
                      ~((index0 == index1) & (way_select0 == way_select1) &
                      (write1 | invalidate1)));
    assign we1_m[i] = (i == way_select1) & (write1 | invalidate1);

    assign data_in0_m[i] = ((way_select0 == i) & (invalidate0)) | reset ? 
                           {MBITS{1'b0}}    : {meta_data0, tag0};
    assign data_in1_m[i] = ((way_select1 == i) & (invalidate1)) | reset ? 
                           {MBITS{1'b0}}    : {meta_data1, tag1};
  end
endgenerate


//sequential logic
always @(posedge clock)begin
  if(reset)begin
    r_read0 <= 1'b0;
    r_read1 <= 1'b0;
    r_tag0  <= {TAG_BITS{1'b0}};
    r_tag1  <= {TAG_BITS{1'b0}};
  end
  else begin
    r_read0 <= read0;
    r_read1 <= read1;
    r_tag0  <= tag0;
    r_tag1  <= tag1;
  end
end


// drive outputs
assign hit0 = r_read0 & valid_tag_match0;
assign hit1 = r_read1 & valid_tag_match1;

assign matched_way0 = valid_tag_match0 ? decoded_tag_match0 : replace_way;
assign matched_way1 = decoded_tag_match1;

assign data_out0 = hit0 ? data_out0_d[decoded_tag_match0] : 
                   data_out0_d[replace_way];
assign data_out1 = hit1 ? data_out1_d[decoded_tag_match1] : {BLOCK_WIDTH{1'b0}};

assign tag_out0 = hit0 ? tag_0[decoded_tag_match0] : tag_0[replace_way];
assign tag_out1 = {TAG_BITS{1'b0}};

assign coh_bits0 = hit0 ? cohbits_out0[decoded_tag_match0] : 
                   cohbits_out0[replace_way];
assign coh_bits1 = hit1 ? cohbits_out1[decoded_tag_match0] : 0;

assign status_bits0 = hit0 ? status_line0[decoded_tag_match0] : 
                      status_line0[replace_way];
assign status_bits1 = hit1 ? status_line1[decoded_tag_match1] : 
                      {STATUS_BITS{1'b0}};

endmodule


