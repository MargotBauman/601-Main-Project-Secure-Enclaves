`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 11/03/2019 05:38:54 PM
// Design Name: 
// Module Name: coherence_controller
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


/** @module : coherence_controller
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

module coherence_controller #(
parameter MSG_BITS       = 4,
          NUM_CACHES     = 4
)(
clock, reset,
cache2mem_msg,
mem2controller_msg,
bus_msg,
bus_control,
bus_en,
curr_master,
req_ready
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

//FROM C FILE
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
//END C FILE           

// Local parameters //
localparam BUS_PORTS     = NUM_CACHES + 1;
localparam MEM_PORT      = BUS_PORTS - 1;
localparam BUS_SIG_WIDTH = log2(BUS_PORTS);

// states
localparam IDLE            = 3'd0,
           WAIT_EN         = 3'd1,
           COHERENCE_OP    = 3'd2,
           WAIT_FOR_MEM    = 3'd3,
           HOLD            = 3'd4,
           END_TRANSACTION = 3'd5,
           MEM_HOLD        = 3'd6;

input clock, reset;
input [(NUM_CACHES*MSG_BITS)-1:0] cache2mem_msg;
input [MSG_BITS-1:             0] mem2controller_msg;
input [MSG_BITS-1:             0] bus_msg;
output reg [BUS_SIG_WIDTH-1:   0] bus_control;
output reg bus_en;
output reg req_ready;
output [NUM_CACHES-1 : 0] curr_master;


//internal variables
genvar i;
integer j;
reg  [2:0] state;
wire [MSG_BITS-1:        0] w_msg_in [NUM_CACHES-1:0];
wire [NUM_CACHES-1:      0] requests;
wire [log2(NUM_CACHES)-1:0] serve_next;
wire [NUM_CACHES-1:      0] tr_en_access, tr_coherence_op, tr_hold;
wire [log2(NUM_CACHES)-1:0] coh_op_cache;
wire coh_op_valid;
wire next_valid = 1;

reg [log2(NUM_CACHES)-1:0] r_curr_master;
reg [log2(NUM_CACHES)-1:0] transaction_owner;
reg r_curr_master_valid;


// separate bundled inputs
generate
  for(i=0; i<NUM_CACHES; i=i+1)begin : MSG_IN
    assign w_msg_in[i]     = cache2mem_msg   [i*MSG_BITS +: MSG_BITS];
  end
endgenerate


// instantiate arbiter
arbiter #(.WIDTH(NUM_CACHES))
  arbitrator(
    .clock(clock), 
    .reset(reset),
    .requests(requests),
    .grant(serve_next)
  );
  
// instantiate one-hot encoder
one_hot_encoder #(.WIDTH(NUM_CACHES))
  curr_master_encoder(
    .in(r_curr_master),
    .valid_input(r_curr_master_valid),
    .out(curr_master)
  );

// instantiate priority encoder
priority_encoder #(
  .WIDTH(NUM_CACHES),
  .PRIORITY("LSB")
) coh_op_encoder (
    .decode(tr_coherence_op),
    .encode(coh_op_cache),
    .valid(coh_op_valid)
  );


// track requests from caches
generate
  for(i=0; i<NUM_CACHES; i=i+1)begin : REQUESTS
    assign requests[i] = (w_msg_in[i] == R_REQ) | (w_msg_in[i] == WB_REQ  ) |
                         (w_msg_in[i] == FLUSH) | (w_msg_in[i] == WS_BCAST) |
                         (w_msg_in[i] == FLUSH_S ) | (w_msg_in[i] == RFO_BCAST);
  end
endgenerate

// track coherence messages from L1 caches
generate
  for(i=0; i<NUM_CACHES; i=i+1)begin : TR_COH_MSGS
    assign tr_coherence_op[i] = (w_msg_in[i] == C_WB)    |
                                (w_msg_in[i] == C_FLUSH) ;
    assign tr_en_access[i]    = (w_msg_in[i] == EN_ACCESS) | 
                                ((i == transaction_owner) & (bus_msg != REQ_FLUSH));
  end
endgenerate



//control logic
always @(posedge clock)begin
  if(reset)begin
    bus_control         <= {BUS_SIG_WIDTH{1'b0}};
    r_curr_master       <= {(log2(NUM_CACHES)){1'b0}};
    transaction_owner   <= {(log2(NUM_CACHES)){1'b0}};
    r_curr_master_valid <= 1'b0;
    bus_en              <= 1'b0;
    req_ready           <= 1'b0;
    state               <= IDLE;
  end
  else begin
    case(state)
      IDLE:begin
        if(|requests & next_valid)begin
          bus_control         <= serve_next;
          r_curr_master       <= serve_next;
          transaction_owner   <= serve_next;
          r_curr_master_valid <= 1'b1;
          bus_en              <= 1'b1;
          if((w_msg_in[serve_next] == WB_REQ) | (w_msg_in[serve_next] == FLUSH))
          begin
            req_ready <=         1'b1;
            state     <= WAIT_FOR_MEM;
          end
          else
            state     <=      WAIT_EN;
        end
        else begin
          state <= IDLE;
        end
      end
      WAIT_EN:begin
        if(&tr_en_access)begin
          if(bus_msg == WS_BCAST)begin
            bus_control <= {BUS_SIG_WIDTH{1'b0}};
            bus_en      <= 1'b0;
            req_ready   <= 1'b1;
            state       <= END_TRANSACTION;
          end
          else if(bus_msg == REQ_FLUSH)begin
            bus_control         <= {BUS_SIG_WIDTH{1'b0}};
            bus_en              <= 1'b0;
            req_ready           <= 1'b1;
            r_curr_master       <= transaction_owner;
            r_curr_master_valid <= 1'b1;
            state               <= WAIT_FOR_MEM;
          end
          else begin
            bus_control         <= transaction_owner;
            bus_en              <= 1'b1;
            req_ready           <= 1'b1;
            r_curr_master       <= transaction_owner;
            r_curr_master_valid <= 1'b1;
            state               <= WAIT_FOR_MEM;
          end
        end
        else if(coh_op_valid)begin
          bus_control         <= coh_op_cache;
          bus_en              <= 1'b1;
          r_curr_master       <= coh_op_cache;
          r_curr_master_valid <= 1'b1;
          state     <= COHERENCE_OP;
        end
        else if(bus_msg == NO_REQ)begin
          bus_control         <= {BUS_SIG_WIDTH{1'b0}};
          bus_en              <= 1'b0;
          req_ready           <= 1'b0;
          r_curr_master       <= {BUS_SIG_WIDTH{1'b0}};
          r_curr_master_valid <= 1'b0;
          state               <= IDLE;
        end
        else begin
          state <= WAIT_EN;
        end
      end
      WAIT_FOR_MEM:begin
        if(mem2controller_msg == REQ_FLUSH)begin
          bus_control         <= MEM_PORT;
          bus_en              <= 1'b1;
          r_curr_master       <= 0;
          r_curr_master_valid <= 1'b0;
          req_ready           <= 1'b0;
          state               <= WAIT_EN;
        end
        else if((mem2controller_msg == MEM_RESP) | (mem2controller_msg == 
        MEM_RESP_S) | (mem2controller_msg == MEM_C_RESP))begin
          bus_control         <= MEM_PORT;
          bus_en              <= 1'b1;
          r_curr_master       <= transaction_owner;
          r_curr_master_valid <= 1'b1;
          req_ready           <= 1'b0;
          state               <= END_TRANSACTION;
        end      
        else if(mem2controller_msg == HOLD_BUS)begin
          bus_control         <= MEM_PORT;
          bus_en              <= 1'b1;
          r_curr_master       <= MEM_PORT;
          r_curr_master_valid <= 1'b1;
          req_ready           <= 1'b0;
          state               <= MEM_HOLD;
        end
        else begin
          state <= WAIT_FOR_MEM;
        end
      end
      END_TRANSACTION:begin
        if(w_msg_in[r_curr_master] == EN_ACCESS)begin
          bus_control         <= {BUS_SIG_WIDTH{1'b0}};
          bus_en              <= 1'b0;
          r_curr_master       <= transaction_owner;
          r_curr_master_valid <= 1'b1;
          state               <= WAIT_EN;
        end
        else if(w_msg_in[r_curr_master] == HOLD_BUS)begin
          bus_control         <= r_curr_master;
          bus_en              <= 1'b1;
          state <= HOLD;
        end
        else if(w_msg_in[r_curr_master] == NO_REQ)begin
          bus_control         <= {BUS_SIG_WIDTH{1'b0}};
          bus_en              <= 1'b0;
          req_ready           <= 1'b0;
          r_curr_master       <= {(log2(NUM_CACHES)){1'b0}};
          r_curr_master_valid <= 1'b0;
          state               <= IDLE;
        end
        else begin
          state <= END_TRANSACTION;
        end
      end
      COHERENCE_OP:begin
          if(mem2controller_msg == MEM_C_RESP)begin
            bus_control         <= MEM_PORT;
            bus_en              <= 1'b1;
            state               <= END_TRANSACTION;
          end
      end
      HOLD:begin
        if(w_msg_in[r_curr_master] == EN_ACCESS)begin
          bus_control         <= {BUS_SIG_WIDTH{1'b0}};
          bus_en              <= 1'b0;
          r_curr_master       <= transaction_owner;
          r_curr_master_valid <= 1'b1;
          state               <= WAIT_EN;
        end
        else if((w_msg_in[r_curr_master] == C_WB) | (w_msg_in[r_curr_master] == 
        C_FLUSH))begin
          bus_control         <= r_curr_master;
          bus_en              <= 1'b1;
          r_curr_master_valid <= 1'b1;
          state               <= COHERENCE_OP;
        end
      end
      MEM_HOLD:begin
        if(mem2controller_msg == NO_REQ)begin
          bus_control         <= transaction_owner;
          bus_en              <= 1'b1;
          req_ready           <= 1'b0;
          r_curr_master       <= transaction_owner;
          r_curr_master_valid <= 1'b1;
          state               <= WAIT_EN;
        end
        else 
          state <= MEM_HOLD;
      end
      default:begin
        state <= IDLE;
      end
    endcase
  end
end

endmodule

