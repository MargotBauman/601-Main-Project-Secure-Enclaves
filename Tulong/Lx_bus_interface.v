`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 11/03/2019 06:18:53 PM
// Design Name: 
// Module Name: Lx_bus_interface
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


/** @module : Lx_bus_interface
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

module Lx_bus_interface #(
parameter CACHE_OFFSET_BITS =  2, //max offset bits from cache side
          BUS_OFFSET_BITS   =  1, //determines width of the bus
          DATA_WIDTH        = 32,
          ADDRESS_WIDTH     = 32,
          MSG_BITS          =  4,
          MAX_OFFSET_BITS   =  3
)(
clock,
reset,

bus_msg_in,
bus_address_in,
bus_data_in,
bus_msg_out,
bus_address_out,
bus_data_out,
req_offset,
req_ready,
active_offset,

cache_msg_in,
cache_address_in,
cache_data_in,
cache_msg_out,
cache_address_out,
cache_data_out
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

localparam CACHE_WORDS = 1 << CACHE_OFFSET_BITS; //number of words in one line.
localparam BUS_WORDS   = 1 << BUS_OFFSET_BITS; //width of data bus.
localparam MAX_WORDS   = 1 << MAX_OFFSET_BITS;
localparam CACHE_WIDTH = DATA_WIDTH*CACHE_WORDS;
localparam BUS_WIDTH   = DATA_WIDTH*BUS_WORDS;
localparam CACHE2BUS_OFFSETDIFF = (CACHE_OFFSET_BITS >= BUS_OFFSET_BITS ) ? 
                                  (CACHE_OFFSET_BITS -  BUS_OFFSET_BITS ) :
                                  (BUS_OFFSET_BITS   - CACHE_OFFSET_BITS) ;
localparam CACHE2BUS_RATIO = 1 << CACHE2BUS_OFFSETDIFF;

localparam IDLE            = 4'd0 ,
           RECEIVE         = 4'd1 ,
           SEND_ADDR       = 4'd2 ,
           SEND_TO_CACHE   = 4'd3 ,
           READ_DATA       = 4'd4 ,
           READ_FILLER     = 4'd5 ,
           TRANSFER        = 4'd6 ,
           WAIT_FOR_RESP   = 4'd7 ,
           WAIT_BUS_CLEAR  = 4'd8 ,
           WAIT_FLUSH_RESP = 4'd9 , 
           GET_BUS         = 4'd10;

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
//END SECTION FROM C FILE           

input clock, reset;

input  [MSG_BITS-1:      0]     bus_msg_in;
input  [ADDRESS_WIDTH-1: 0] bus_address_in;
input  [BUS_WIDTH-1:     0]    bus_data_in;
input  req_ready;
input  [log2(MAX_OFFSET_BITS):0] req_offset;
output [MSG_BITS-1:      0]     bus_msg_out;
output [ADDRESS_WIDTH-1: 0] bus_address_out;
output [BUS_WIDTH-1:     0]    bus_data_out;
output  [log2(MAX_OFFSET_BITS):0] active_offset;

input  [MSG_BITS-1:      0] cache_msg_in     ;
input  [ADDRESS_WIDTH-1: 0] cache_address_in ;
input  [CACHE_WIDTH-1:   0] cache_data_in    ;
output [MSG_BITS-1:      0] cache_msg_out    ;
output [ADDRESS_WIDTH-1: 0] cache_address_out;
output [CACHE_WIDTH-1:   0] cache_data_out   ;


genvar i;
integer j;
reg [3:0] state;
reg [DATA_WIDTH-1:0] r_cache_data_out [CACHE_WORDS-1:0];
reg [DATA_WIDTH-1:0] r_bus_data_out   [BUS_WORDS-1:  0];

reg [MSG_BITS-1:     0] r_cache_msg_out, r_bus_msg_out;
reg [ADDRESS_WIDTH-1:0] r_cache_address_out, r_bus_address_out;
reg [MAX_OFFSET_BITS:0] block_counter, word_counter;

reg [MSG_BITS-1:0] curr_msg;
reg [ADDRESS_WIDTH-1:0] curr_address;
reg [CACHE_OFFSET_BITS-1:0] curr_offset;
reg [DATA_WIDTH-1:0] curr_data [MAX_WORDS-1:0];
reg [MAX_OFFSET_BITS-1:0] r_req_offset;

reg shared_line;

reg flush_active;
reg [ADDRESS_WIDTH-1:0] flush_address;

wire [DATA_WIDTH-1:0] w_cache_data_in [CACHE_WORDS-1: 0];
wire [DATA_WIDTH-1:0] w_bus_data_in   [BUS_WORDS-1:   0];

wire [MAX_OFFSET_BITS-1:0] cache2req_offsetdiff;
wire [MAX_OFFSET_BITS  :0] cache2req_ratio;
wire [MAX_OFFSET_BITS-1:0] req2bus_offsetdiff;
wire [MAX_OFFSET_BITS  :0] req2bus_ratio;
wire [MAX_OFFSET_BITS  :0] req_words;
wire cache_wt_bus, cache_wt_req, bus_wt_cache, bus_wt_req,
     req_wt_cache, req_wt_bus, bus_wt_flush;
wire cache_req, coh_req;
wire read_req, receive_req;


//assignments
assign cache2req_offsetdiff = (CACHE_OFFSET_BITS > r_req_offset) ?
                              (CACHE_OFFSET_BITS - r_req_offset) :
                              (r_req_offset - CACHE_OFFSET_BITS) ;
assign cache2req_ratio = 1 << cache2req_offsetdiff;

assign req2bus_offsetdiff = (r_req_offset > BUS_OFFSET_BITS) ?
                            (r_req_offset - BUS_OFFSET_BITS) :
                            (BUS_OFFSET_BITS - r_req_offset) ;
assign req2bus_ratio = 1 << req2bus_offsetdiff;


assign cache_wt_bus = CACHE_OFFSET_BITS > BUS_OFFSET_BITS;
assign cache_wt_req = CACHE_OFFSET_BITS > r_req_offset;
assign bus_wt_cache = BUS_OFFSET_BITS > CACHE_OFFSET_BITS;
assign bus_wt_req   = BUS_OFFSET_BITS > r_req_offset;
assign req_wt_cache = r_req_offset > CACHE_OFFSET_BITS;
assign req_wt_bus   = r_req_offset > BUS_OFFSET_BITS;

assign req_words = 1 << r_req_offset;

generate
  for(i=0; i<CACHE_WORDS; i=i+1)begin : SPLIT_CACHELINE
    assign w_cache_data_in[i] = cache_data_in[i*DATA_WIDTH +: DATA_WIDTH];
  end
  for(i=0; i<BUS_WORDS; i=i+1)begin: SPLIT_BUS
    assign w_bus_data_in[i] = bus_data_in[i*DATA_WIDTH +: DATA_WIDTH];
  end
endgenerate

assign cache_req = (bus_msg_in == R_REQ) | (bus_msg_in == WB_REQ ) |
                   (bus_msg_in == FLUSH) | (bus_msg_in == FLUSH_S) |
                   (bus_msg_in == RFO_BCAST);

assign coh_req   = (bus_msg_in == C_WB) | (bus_msg_in == C_FLUSH);

assign read_req = (bus_msg_in == R_REQ) | (bus_msg_in == RFO_BCAST);
assign receive_req = (bus_msg_in == WB_REQ) | (bus_msg_in == FLUSH) | coh_req;


/*FSM*/
always @(posedge clock)begin
  if(reset)begin
    r_cache_msg_out     <= NO_REQ;
    r_bus_msg_out       <= NO_REQ;
    r_cache_address_out <= {ADDRESS_WIDTH{1'b0}};
    r_bus_address_out   <= {ADDRESS_WIDTH{1'b0}};
    block_counter       <= {MAX_OFFSET_BITS{1'b0}};
    word_counter        <= {MAX_OFFSET_BITS{1'b0}};
    curr_msg            <= NO_REQ;
    curr_address        <= {ADDRESS_WIDTH{1'b0}};
    curr_offset         <= {CACHE_OFFSET_BITS{1'b0}};
    r_req_offset        <= {MAX_OFFSET_BITS{1'b0}};
	  shared_line         <= 1'b0;
    flush_active        <= 1'b0;
    flush_address       <= {ADDRESS_WIDTH{1'b0}};
    for(j=0; j<MAX_WORDS; j=j+1)begin
      curr_data[j] <= {DATA_WIDTH{1'b0}};
    end
    for(j=0; j<BUS_WORDS; j=j+1)begin
      r_bus_data_out[j] <= {DATA_WIDTH{1'b0}};
    end
    for(j=0; j<CACHE_WORDS; j=j+1)begin
      r_cache_data_out[j] <= {DATA_WIDTH{1'b0}};
    end
    state  <= IDLE;
  end
  else begin
    case(state)
      IDLE:begin
        if((cache_req & req_ready) | coh_req)begin
          curr_msg        <= bus_msg_in;
          curr_address    <= bus_address_in;
          curr_offset     <= bus_address_in[0 +: CACHE_OFFSET_BITS];
          r_req_offset    <= req_offset;
          if(receive_req)begin
            block_counter <= 1;
            word_counter  <= 0;
            state         <= RECEIVE;
          end
          else begin
            block_counter       <= 1;
            word_counter        <= 0;
			      shared_line         <= 1'b0;
            state               <= SEND_ADDR;
          end
        end
        else if(req_ready & (bus_msg_in == NO_REQ) & flush_active)begin
          r_bus_msg_out       <= HOLD_BUS;
          r_bus_address_out   <= {ADDRESS_WIDTH{1'b0}};
          r_cache_msg_out     <= FLUSH_S;
          r_cache_address_out <= flush_address;
          flush_active        <= 1'b0;
          state               <= WAIT_FLUSH_RESP;
        end
        else
          state <= IDLE;
      end
      RECEIVE:begin
        for(j=0; j<BUS_WORDS; j=j+1)begin
          curr_data[word_counter + j] <= w_bus_data_in[j];
        end
        if(req_wt_bus)begin
          if(block_counter == req2bus_ratio)begin
            block_counter <= 1;
            word_counter  <= 0;
            state         <= SEND_TO_CACHE;
          end
          else begin
            block_counter <= block_counter + 1;
            word_counter  <= word_counter + BUS_WORDS;
            state         <= RECEIVE;
          end
        end
        else begin
          if(cache2req_ratio == 1)begin
            r_cache_msg_out     <= curr_msg;
            r_cache_address_out <= curr_address;
            block_counter       <= 1;
            word_counter        <= 0;
            for(j=0; j<CACHE_WORDS; j=j+1)begin
              r_cache_data_out[j] <= (j<BUS_WORDS) ? w_bus_data_in[j] :
                                     {DATA_WIDTH{1'b0}};
            end
            state <= WAIT_FOR_RESP;
          end
          else begin
            r_cache_msg_out     <= R_REQ;
            r_cache_address_out <= (curr_address >> CACHE_OFFSET_BITS) <<
                                   CACHE_OFFSET_BITS;
            state               <= READ_FILLER;
          end
        end
      end
      READ_FILLER:begin
        if((cache_msg_in == MEM_RESP) | (cache_msg_in == MEM_RESP_S))begin
          for(j=0; j<CACHE_WORDS; j=j+1)begin
            r_cache_data_out[j] <= w_cache_data_in[j];
          end
          r_cache_msg_out     <= NO_REQ;
          r_cache_address_out <= {ADDRESS_WIDTH{1'b0}};
          block_counter       <= 1;
          word_counter        <= 0;
          state               <= SEND_TO_CACHE;
        end
        else if(cache_msg_in == REQ_FLUSH)begin
          r_bus_msg_out     <= REQ_FLUSH;
          r_bus_address_out <= cache_address_in;
          flush_active      <= 1'b1;
          flush_address     <= cache_address_in;
          r_cache_msg_out   <= NO_REQ;
          state             <= GET_BUS;
        end
        else
          state <= READ_FILLER;
      end
      SEND_TO_CACHE:begin
        if(req_wt_cache)begin
          r_cache_msg_out     <= curr_msg;
          r_cache_address_out <= curr_address + word_counter;
          for(j=0; j<CACHE_WORDS; j=j+1)begin
            r_cache_data_out[j] <= curr_data[word_counter + j];
          end
        end
        else begin
          r_cache_msg_out     <= curr_msg;
          r_cache_address_out <= (curr_address >> CACHE_OFFSET_BITS) <<
                                 CACHE_OFFSET_BITS;
          for(j=0; j<CACHE_WORDS; j=j+1)begin
            r_cache_data_out[j] <= (j>=curr_offset & j<(curr_offset+req_words))
                                   ? curr_data[j-curr_offset] : 
                                   r_cache_data_out[j];
          end
        end
        state <= WAIT_FOR_RESP;
      end
      WAIT_FOR_RESP:begin
        if((cache_msg_in == MEM_RESP) | (cache_msg_in == MEM_C_RESP))begin
          if((block_counter == cache2req_ratio) | cache_wt_req)begin
            r_bus_msg_out     <= cache_msg_in;
            r_bus_address_out <= curr_address;
            for(j=0; j<BUS_WORDS; j=j+1)begin
              r_bus_data_out[j] <= {DATA_WIDTH{1'b0}};
            end
            state <= WAIT_BUS_CLEAR;
          end
          else begin
            block_counter   <= block_counter + 1;
            word_counter    <= word_counter + CACHE_WORDS;
			      r_cache_msg_out <= NO_REQ;
            state           <= SEND_TO_CACHE;
          end
          r_cache_msg_out     <= NO_REQ;
          r_cache_address_out <= {ADDRESS_WIDTH{1'b0}};
        end
        else
          state <= WAIT_FOR_RESP;
      end
      SEND_ADDR:begin
        r_cache_msg_out     <= curr_msg;
        r_cache_address_out <= ((curr_address >> CACHE_OFFSET_BITS) <<
                               CACHE_OFFSET_BITS) + word_counter;
        state               <= READ_DATA;
      end
      READ_DATA:begin
        if((cache_msg_in == MEM_RESP) | (cache_msg_in == MEM_RESP_S))begin
          r_cache_msg_out <= NO_REQ;
          for(j=0; j<CACHE_WORDS; j=j+1)begin
            curr_data[word_counter + j] <= w_cache_data_in[j];
          end
          if((block_counter == cache2req_ratio) | cache_wt_req)begin
            block_counter     <= 0;
            word_counter      <= curr_offset;
            r_bus_msg_out     <= (shared_line | (cache_msg_in == MEM_RESP_S)) ?
			                           MEM_RESP_S : MEM_RESP; 
            r_bus_address_out <= curr_address;
            state             <= (curr_msg == FLUSH_S) ? WAIT_BUS_CLEAR : 
                                 TRANSFER;
          end
          else begin
            block_counter <= block_counter + 1;
            word_counter  <= word_counter + CACHE_WORDS;
      			shared_line   <= shared_line | (cache_msg_in == MEM_RESP_S);
            state         <= SEND_ADDR;
          end
        end
        else if(cache_msg_in == REQ_FLUSH)begin
          r_bus_msg_out     <= REQ_FLUSH;
          r_bus_address_out <= cache_address_in;
          flush_active      <= 1'b1;
          flush_address     <= cache_address_in;
          r_cache_msg_out   <= NO_REQ;
          state             <= GET_BUS;
        end
        else
          state <= READ_DATA;
      end
      TRANSFER:begin
        if((block_counter == req2bus_ratio) | (bus_wt_req & (block_counter==1)))
        begin
          state <= WAIT_BUS_CLEAR;
		      for(j=0; j<BUS_WORDS; j=j+1)begin
            r_bus_data_out[j] <= {DATA_WIDTH{1'b0}};
          end
		      r_bus_msg_out     <= NO_REQ;
		      r_bus_address_out <= {ADDRESS_WIDTH{1'b0}};
        end
        else begin
		      for(j=0; j<BUS_WORDS; j=j+1)begin
            r_bus_data_out[j] <= curr_data[word_counter + j];
          end
          block_counter <= block_counter + 1;
          word_counter  <= word_counter + BUS_WORDS;
          state         <= TRANSFER;
        end
      end
      WAIT_BUS_CLEAR:begin
        if(bus_msg_in == NO_REQ)begin
          if(flush_active)begin
            r_bus_msg_out     <= REQ_FLUSH;
            r_bus_address_out <= flush_address;
            state             <= IDLE;
          end
          else begin
            r_bus_msg_out     <= NO_REQ;
            r_bus_address_out <= {ADDRESS_WIDTH{1'b0}};
            for(j=0; j<BUS_WORDS; j=j+1)begin
              r_bus_data_out[j] <= {DATA_WIDTH{1'b0}};
            end
            state <= IDLE;
          end
        end
        else
          state <= WAIT_BUS_CLEAR;
      end
      WAIT_FLUSH_RESP:begin
        if(cache_msg_in == MEM_RESP)begin
          r_cache_msg_out     <= NO_REQ;
          r_cache_address_out <= {ADDRESS_WIDTH{1'b0}};
          r_bus_msg_out       <= NO_REQ;
          r_bus_address_out   <= {ADDRESS_WIDTH{1'b0}};
          state               <= IDLE;
        end
        else
          state <= WAIT_FLUSH_RESP;
      end
      GET_BUS:begin
        state <= IDLE;
      end
      default:begin
        state <= IDLE;
      end
    endcase
  end
end

//Assign outputs//
assign bus_msg_out       = r_bus_msg_out;
assign bus_address_out   = r_bus_address_out;
assign cache_msg_out     = r_cache_msg_out;
assign cache_address_out = r_cache_address_out;
assign active_offset     = CACHE_OFFSET_BITS;

generate
  for(i=0; i<BUS_WORDS; i=i+1)begin: BUS_DATA
    assign bus_data_out[i*DATA_WIDTH +: DATA_WIDTH] = r_bus_data_out[i];
  end
  for(i=0; i<CACHE_WORDS; i=i+1)begin: CACHE_DATA
    assign cache_data_out[i*DATA_WIDTH +: DATA_WIDTH] = r_cache_data_out[i];
  end
endgenerate

endmodule

