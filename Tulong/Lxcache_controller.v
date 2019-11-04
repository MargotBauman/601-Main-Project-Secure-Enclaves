`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 11/03/2019 06:20:17 PM
// Design Name: 
// Module Name: Lxcache_controller
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


/** @module : Lxcache_controller
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

module Lxcache_controller #(
parameter STATUS_BITS      = 3, // Valid bit + Dirty bit + inclusion bit
          COHERENCE_BITS   = 2,
          OFFSET_BITS      = 2,
          DATA_WIDTH       = 32,
          NUMBER_OF_WAYS   = 4,
          ADDRESS_BITS     = 32,
          INDEX_BITS       = 10,
          MSG_BITS         = 4
)(
clock,
reset,
address,
data_in,
msg_in,
report,
data_out,
out_address,
msg_out,

mem2cache_msg,
mem2cache_address,
mem2cache_data,
cache2mem_msg,
cache2mem_address,
cache2mem_data,

read0, write0, invalidate0,
index0,
tag0,
meta_data0,
data0,
way_select0,
i_reset,
data_in0,
tag_in0,
matched_way0,
coh_bits0,
status_bits0,
hit0
);

//Define the log2 function
function integer log2;
input integer value;
begin
  value = value-1;
  for(log2=0; value>0; log2=log2+1)
    value = value >> 1;
  end
endfunction

localparam CACHE_WORDS = 1 << OFFSET_BITS; //number of words in one line.
localparam CACHE_WIDTH = DATA_WIDTH*CACHE_WORDS;
localparam MBITS       = COHERENCE_BITS + STATUS_BITS;
localparam TAG_BITS    = ADDRESS_BITS - OFFSET_BITS - INDEX_BITS;
localparam WAY_BITS    = (NUMBER_OF_WAYS > 1) ? log2(NUMBER_OF_WAYS) : 1;
localparam CACHE_DEPTH = 1 << INDEX_BITS;

localparam IDLE       = 4'd0,
           READING    = 4'd1,
           SERVING    = 4'd2,
           RESPOND    = 4'd3,
           WRITE_BACK = 4'd4,
           READ_STATE = 4'd5,
           READ_WAIT  = 4'd6,
           FLUSH_WAIT = 4'd7,
           RESET      = 4'd8;

//THIS SECTION FROM C FILE
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
//END C FILE SECTION           

input clock;
input reset;
//signals to/from bus interface
input  [ADDRESS_BITS-1:0] address;
input  [CACHE_WIDTH-1 :0] data_in;
input  [MSG_BITS-1    :0] msg_in;
input  report;
output [CACHE_WIDTH-1 :0] data_out;
output [ADDRESS_BITS-1:0] out_address;
output [MSG_BITS-1    :0] msg_out;
//signals to/from next level cache/memory
input  [MSG_BITS-1    :0] mem2cache_msg;
input  [ADDRESS_BITS-1:0] mem2cache_address;
input  [CACHE_WIDTH-1 :0] mem2cache_data;
output [MSG_BITS-1    :0] cache2mem_msg;
output [ADDRESS_BITS-1:0] cache2mem_address;
output [CACHE_WIDTH-1 :0] cache2mem_data;
//signals to/from cache_memory
output read0, write0, invalidate0;
output [INDEX_BITS-1  :0] index0;
output [TAG_BITS-1    :0] tag0;
output [MBITS-1       :0] meta_data0;
output [CACHE_WIDTH-1 :0] data0;
output [WAY_BITS-1    :0] way_select0;
output i_reset;
input  [CACHE_WIDTH-1 :0] data_in0;
input  [TAG_BITS-1    :0] tag_in0;
input  [WAY_BITS-1    :0] matched_way0;
input  [COHERENCE_BITS-1:0] coh_bits0;
input  [STATUS_BITS-1 :0] status_bits0;
input  hit0;

genvar i;
integer j;

reg [3:0] state;
reg [INDEX_BITS-1:0] reset_counter;
reg read, write, invalidate;
reg [MSG_BITS-1:0] r_msg;
reg [ADDRESS_BITS-1:0] r_address;
reg [DATA_WIDTH-1:0] r_data [CACHE_WORDS-1:0];
reg [DATA_WIDTH-1:0] r_data_out [CACHE_WORDS-1:0];
reg r_hit, r_dirty, r_include;
reg [COHERENCE_BITS-1:0] r_coh_bits;
reg [TAG_BITS-1:0] r_tag, r_tag_out;
reg [WAY_BITS-1:0] r_matched_way, r_way_select;
reg [MSG_BITS-1:0] r_msg_out;
reg [MBITS-1       :0] r_meta_data;
reg [MSG_BITS-1    :0] r_cache2mem_msg;
reg [ADDRESS_BITS-1:0] r_cache2mem_address;
reg flush_active;


wire request;
wire coh_request;
wire read_req, write_req;
wire [DATA_WIDTH-1:0] w_data_in   [CACHE_WORDS-1:0];
wire [DATA_WIDTH-1:0] w_read_data [CACHE_WORDS-1:0];
wire [DATA_WIDTH-1:0] w_mem_data  [CACHE_WORDS-1:0];


//assignments
assign i_reset = reset | (state == RESET);

assign coh_request = (msg_in == C_WB) | (msg_in == C_FLUSH);

assign request = (msg_in == WB_REQ   ) | (msg_in == R_REQ) |
                 (msg_in == RFO_BCAST) | (msg_in == FLUSH) |
                 (msg_in == FLUSH_S  ) | coh_request       ;

assign read_req  = (r_msg == R_REQ) | (r_msg == RFO_BCAST) | (r_msg == FLUSH_S);

assign write_req = (r_msg == C_WB) | (r_msg == C_FLUSH) | (r_msg == WB_REQ) |
                   (r_msg == FLUSH);

generate
  for(i=0; i<CACHE_WORDS; i=i+1)begin:SEPARATE_INPUTS
    assign w_data_in[i]   = data_in[i*DATA_WIDTH +: DATA_WIDTH];
    assign w_read_data[i] = data_in0[i*DATA_WIDTH +: DATA_WIDTH];
    assign w_mem_data[i]  = mem2cache_data[i*DATA_WIDTH +: DATA_WIDTH];
  end
endgenerate


/*FSM*/
always @(posedge clock)begin
  if(reset & (state != RESET))begin
    reset_counter       <= {INDEX_BITS{1'b0}};
    read                <= 1'b0;
    write               <= 1'b0;
    invalidate          <= 1'b1;
    flush_active        <= 1'b0;
    r_cache2mem_msg     <= NO_REQ;
    r_cache2mem_address <= {ADDRESS_BITS{1'b0}};
    r_msg               <= NO_REQ;
    r_address           <= {ADDRESS_BITS{1'b0}};
    r_hit               <= 1'b0;
    r_dirty             <= 1'b0;
    r_include           <= 1'b0;
    r_coh_bits          <= {COHERENCE_BITS{1'b0}};
    r_tag               <= {TAG_BITS{1'b0}};
    r_tag_out           <= {TAG_BITS{1'b0}};
    r_matched_way       <= {WAY_BITS{1'b0}};
    r_way_select        <= {WAY_BITS{1'b0}};
    r_msg_out           <= NO_REQ;
    r_meta_data         <= {MBITS{1'b0}};
    for(j=0; j<CACHE_WORDS; j=j+1)begin
      r_data[j]         <= {DATA_WIDTH{1'b0}};
      r_data_out[j]     <= {DATA_WIDTH{1'b0}};
    end
    state               <= RESET;
  end
  else begin
    case(state)
      RESET:begin
        if(reset_counter < CACHE_DEPTH-1)begin
          reset_counter <= reset_counter + 1;
        end
        else if((reset_counter == CACHE_DEPTH-1) & ~reset)begin
          reset_counter <= {INDEX_BITS{1'b0}};
          invalidate    <= 1'b0;
          state         <= IDLE;
        end
        else
          state <= RESET;
      end
      IDLE:begin
        if(request)begin
          r_msg     <= msg_in;
          r_address <= address;
          for(j=0; j<CACHE_WORDS; j=j+1)begin
            r_data[j] <= w_data_in[j];
          end
          state <= READING;
        end
        else
          state <= IDLE;
      end
      READING:begin
        r_hit         <= hit0;
        r_dirty       <= status_bits0[STATUS_BITS-2];
        r_include     <= status_bits0[STATUS_BITS-3];
        r_coh_bits    <= coh_bits0;
        r_tag         <= tag_in0;
        r_matched_way <= matched_way0;
        for(j=0; j<CACHE_WORDS; j=j+1)begin
          r_data_out[j] <= w_read_data[j];
        end
        state <= SERVING;
      end
      SERVING:begin
        case(r_msg)
          R_REQ:begin
            if(r_hit)begin
              r_msg_out    <= (r_coh_bits==INVALID) ? MEM_RESP : MEM_RESP_S;
              write        <= 1'b1;
              r_tag_out    <= r_tag;
              r_way_select <= r_matched_way;
              r_meta_data  <= (r_coh_bits == INVALID) ? 
                              {1'b1, r_dirty, 1'b1, EXCLUSIVE} :
                              {1'b1, r_dirty, 1'b1, SHARED   } ;
              for(j=0; j<CACHE_WORDS; j=j+1)begin
                r_data[j] <= r_data_out[j];
              end
              state <= RESPOND;
            end
            else begin
              if(r_include)begin
                flush_active                          <= 1'b1;
                r_msg_out                             <= REQ_FLUSH;
                r_address[ADDRESS_BITS-1 -: TAG_BITS] <= r_tag;
                state                                 <= RESPOND;
              end
              else if(r_dirty)begin
                r_cache2mem_msg     <= WB_REQ;
                r_cache2mem_address <= {r_tag, r_address[OFFSET_BITS +: 
                                       INDEX_BITS], {OFFSET_BITS{1'b0}}};
                for(j=0; j<CACHE_WORDS; j=j+1)begin
                  r_data[j] <= r_data_out[j];
                end
                state               <= WRITE_BACK;
              end
              else begin
                r_cache2mem_msg     <= R_REQ;
                r_cache2mem_address <= {r_address[ADDRESS_BITS-1:OFFSET_BITS], 
                                       {OFFSET_BITS{1'b0}}};
                state               <= READ_WAIT;
              end
            end
          end
          RFO_BCAST:begin
            if(r_hit)begin
              r_msg_out <= MEM_RESP;
              write     <= 1'b1;
              r_tag_out    <= r_tag;
              r_way_select <= r_matched_way;
              r_meta_data  <= {1'b1, r_dirty, 1'b1, EXCLUSIVE};
              for(j=0; j<CACHE_WORDS; j=j+1)begin
                r_data[j] <= r_data_out[j];
              end
              state <= RESPOND;
            end
            else begin
              if(r_include)begin
                flush_active                          <= 1'b1;
                r_msg_out                             <= REQ_FLUSH;
                r_address[ADDRESS_BITS-1 -: TAG_BITS] <= r_tag;
                state                                 <= RESPOND;
              end
              else if(r_dirty)begin
                r_cache2mem_msg     <= WB_REQ;
                r_cache2mem_address <= {r_tag, r_address[OFFSET_BITS +: 
                                       INDEX_BITS], {OFFSET_BITS{1'b0}}};
                for(j=0; j<CACHE_WORDS; j=j+1)begin
                  r_data[j] <= r_data_out[j];
                end
                state               <= WRITE_BACK;
              end
              else begin
                r_cache2mem_msg     <= R_REQ;
                r_cache2mem_address <= {r_address[ADDRESS_BITS-1:OFFSET_BITS], 
                                       {OFFSET_BITS{1'b0}}};
                state               <= READ_WAIT;
              end
            end
          end
          WB_REQ:begin
            write         <= 1'b1;
            r_tag_out     <= r_tag;
            r_way_select  <= r_matched_way;
            r_meta_data   <= (r_coh_bits == EXCLUSIVE) ? {3'b110, INVALID} :
                             {3'b111, SHARED};
            r_msg_out     <= MEM_RESP;
            state         <= RESPOND;
          end
          FLUSH:begin
            flush_active <= 1'b1;
            r_tag_out    <= r_tag;
            r_msg_out    <= REQ_FLUSH;
            state        <= RESPOND;
          end
          FLUSH_S:begin
            if(flush_active)begin
              if(r_hit & r_dirty)begin
                invalidate          <= 1'b1;
                r_tag_out           <= r_tag;
                r_way_select        <= r_matched_way;
                r_cache2mem_address <= r_address;
                for(j=0; j<CACHE_WORDS; j=j+1)begin
                  r_data[j] <= r_data_out[j];
                end
                r_cache2mem_msg     <= FLUSH;
                flush_active        <= 1'b0;
                state               <= FLUSH_WAIT;
              end
              else if(r_hit & ~r_dirty)begin
                invalidate   <= 1'b1;
                r_msg_out    <= MEM_RESP;
                flush_active <= 1'b0;
                state        <= RESPOND;
              end
              /**/
              else begin
                r_msg_out    <= MEM_RESP;
                flush_active <= 1'b0;
                state        <= RESPOND;
              end
            end
            else begin
              if(r_hit)begin
                flush_active <= 1'b1;
                r_tag_out    <= r_tag;
                r_msg_out    <= REQ_FLUSH;
                state        <= RESPOND;
              end
              else begin
                r_msg_out <= MEM_RESP;
                state     <= RESPOND;
              end
            end
          end
          C_WB:begin
            write         <= 1'b1;
            r_tag_out     <= r_tag;
            r_way_select  <= r_matched_way;
            r_meta_data   <= (r_coh_bits == EXCLUSIVE) ? {3'b110, INVALID} :
                             {3'b111, SHARED};
            r_msg_out     <= MEM_C_RESP;
            state         <= RESPOND;
          end
          C_FLUSH:begin
            invalidate          <= 1'b1;
            r_tag_out           <= r_tag;
            r_way_select        <= r_matched_way;
            r_cache2mem_address <= r_address;
            r_cache2mem_msg     <= FLUSH;
            state               <= FLUSH_WAIT;
          end
          default:begin
            state <= IDLE;
          end
        endcase
      end
      WRITE_BACK:begin
        if(mem2cache_msg == MEM_RESP)begin
          r_cache2mem_msg     <= NO_REQ;
          r_cache2mem_address <= {ADDRESS_BITS{1'b0}};
          invalidate          <= 1'b1;
          state               <= READ_STATE;
        end
        else
          state <= WRITE_BACK;
      end
      READ_STATE:begin
        invalidate          <= 1'b0;
        r_cache2mem_msg     <= R_REQ;
        r_cache2mem_address <= {r_address[ADDRESS_BITS-1:OFFSET_BITS], 
                               {OFFSET_BITS{1'b0}}};
        state               <= READ_WAIT;
      end
      READ_WAIT:begin
        if(mem2cache_msg == MEM_RESP)begin
          r_msg_out <= MEM_RESP;
          for(j=0; j<CACHE_WORDS; j=j+1)begin
            r_data[j]     <= w_mem_data[j];
            r_data_out[j] <= w_mem_data[j];
          end
          r_tag_out           <= r_address[ADDRESS_BITS-1 -: TAG_BITS];
          r_way_select        <= r_matched_way;
          r_meta_data         <= {3'b101, EXCLUSIVE};
          write               <= 1'b1;
          r_cache2mem_msg     <= NO_REQ;
          r_cache2mem_address <= {ADDRESS_BITS{1'b0}};
          state               <= RESPOND;
        end
        else
          state <= READ_WAIT;
      end
      RESPOND:begin
        write      <= 1'b0;
        invalidate <= 1'b0;
        r_msg_out  <= NO_REQ;
        state      <= IDLE;
      end
      FLUSH_WAIT:begin
        invalidate          <= 1'b0;
        if(mem2cache_msg == MEM_RESP)begin
          r_msg_out           <= MEM_C_RESP;
          r_cache2mem_msg     <= NO_REQ;
          r_cache2mem_address <= {ADDRESS_BITS{1'b0}};
          state               <= RESPOND;
        end
        else
          state <= FLUSH_WAIT;
      end
      default:begin
        state <= IDLE;
      end
    endcase
  end
end

//assign outputs
assign read0       = (state == IDLE) & (msg_in != NO_REQ);
assign write0      = write;
assign invalidate0 = invalidate;
assign tag0        = (state == IDLE) ? address[ADDRESS_BITS-1 -: TAG_BITS] : 
                     r_tag_out;
assign meta_data0  = r_meta_data;
assign way_select0 = r_way_select;

assign index0 = (state == RESET) ? reset_counter :
                (state == IDLE ) ? address[OFFSET_BITS +: INDEX_BITS] :
                r_address[OFFSET_BITS +: INDEX_BITS];

assign msg_out     = r_msg_out;
assign out_address = r_address;

generate
  for(i=0; i<CACHE_WORDS; i=i+1)begin: DATAOUT
    assign data_out[i*DATA_WIDTH +: DATA_WIDTH] = r_data_out[i]; 
  end
  for(i=0; i<CACHE_WORDS; i=i+1)begin: C2MDATA
    assign cache2mem_data[i*DATA_WIDTH +: DATA_WIDTH] = r_data[i]; 
  end
  for(i=0; i<CACHE_WORDS; i=i+1)begin: DATA0
    assign data0[i*DATA_WIDTH +: DATA_WIDTH] = r_data[i]; 
  end
endgenerate

assign cache2mem_msg     = r_cache2mem_msg;
assign cache2mem_address = r_cache2mem_address;


endmodule

