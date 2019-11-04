`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 11/03/2019 06:33:06 PM
// Design Name: 
// Module Name: main_memory
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


/** @module : main_memory
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

module main_memory #(
parameter DATA_WIDTH    = 32,
          ADDRESS_WIDTH = 32,
          MSG_BITS      = 4,
          INDEX_BITS    = 15,
          NUM_PORTS     = 1,
          INIT_FILE     = "./instructions.dat"
)(
clock, reset,
msg_in,
address,
data_in,
msg_out,
address_out,
data_out
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

input  clock, reset;
input  [NUM_PORTS*MSG_BITS-1 : 0]           msg_in;
input  [NUM_PORTS*ADDRESS_WIDTH-1 : 0]     address;
input  [NUM_PORTS*DATA_WIDTH-1 : 0]        data_in;
output [NUM_PORTS*MSG_BITS-1 : 0]          msg_out;
output [NUM_PORTS*ADDRESS_WIDTH-1 : 0] address_out;
output [NUM_PORTS*DATA_WIDTH-1 : 0]       data_out;

localparam MEM_DEPTH = 1 << INDEX_BITS;
localparam IDLE      = 0,
           SERVING   = 1,
           READ_OUT  = 2;

//START C FILE
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

genvar i;
integer j;

reg [1:0] state;
reg [log2(NUM_PORTS)-1 : 0] serving;
reg [MSG_BITS-1 : 0]      t_msg_out     [NUM_PORTS-1 : 0];
reg [ADDRESS_WIDTH-1 : 0] t_address_out [NUM_PORTS-1 : 0];
reg [MSG_BITS-1 : 0]          t_msg;
reg [ADDRESS_WIDTH-1 : 0] t_address;
reg [DATA_WIDTH-1 : 0]       t_data;

wire [NUM_PORTS-1 : 0] requests;
wire [log2(NUM_PORTS)-1 : 0] serv_next;
wire [MSG_BITS-1 : 0]      w_msg_in     [NUM_PORTS-1 : 0];
wire [ADDRESS_WIDTH-1 : 0] w_address_in [NUM_PORTS-1 : 0];
wire [DATA_WIDTH-1 : 0]    w_data_in    [NUM_PORTS-1 : 0];
wire [DATA_WIDTH-1 : 0]    w_data_out   [NUM_PORTS-1 : 0];
wire we0;
wire [DATA_WIDTH-1 : 0]    data_in0;
wire [ADDRESS_WIDTH-1 : 0] address0;
wire [DATA_WIDTH-1 : 0]  data_out0, data_out1;

generate
  for(i=0;i<NUM_PORTS; i=i+1)begin : SPLIT_INPUTS
    assign w_msg_in[i]     = msg_in[i*MSG_BITS +: MSG_BITS];
    assign w_data_in[i]    = data_in[i*DATA_WIDTH +: DATA_WIDTH];
    assign w_address_in[i] = address[i*ADDRESS_WIDTH +: ADDRESS_WIDTH];
    assign requests[i]     = (w_msg_in[i] == R_REQ) | (w_msg_in[i] == WB_REQ); 
  end
endgenerate

assign address0 = (state == SERVING) ? t_address : 0;
assign data_in0 = (state == SERVING) ? t_data    : 0;
assign we0      = (state == SERVING) & (t_msg == WB_REQ);

// Instantiate round-robin arbitrator
generate if(NUM_PORTS > 1)
  arbiter #(NUM_PORTS) arbitrtor_1 (clock, reset, requests, serv_next);
else
  assign serv_next = 0;
endgenerate


BRAM #(
  .DATA_WIDTH(DATA_WIDTH),
  .ADDR_WIDTH(INDEX_BITS)
) BRAM_inst (
  .clock(clock),
  .reset(1'b0),
  .readEnable(1'b1),
  .readAddress(address0[0 +: INDEX_BITS]),
  .readData(data_out0),
  .writeEnable(we0),
  .writeAddress(address0[0 +: INDEX_BITS]),
  .writeData(data_in0),
  .scan(1'b0)
);


// controller FSM
always @(posedge clock)begin
  if(reset)begin
    for(j=0; j<NUM_PORTS; j=j+1)begin
      t_msg_out[j]     <= NO_REQ;
      t_address_out[j] <= 0;
    end
    state <= IDLE;
  end
  else begin
    case(state)
      IDLE:begin
        if(|requests)begin
          t_msg     <=     w_msg_in[serv_next];
          t_address <= w_address_in[serv_next];
          t_data    <=    w_data_in[serv_next];
          serving   <=               serv_next;
          if(w_msg_in[serv_next] == WB_REQ)begin
            t_msg_out[serving]     <= MEM_RESP;
            t_address_out[serving] <= w_address_in[serv_next];
          end
          state <= SERVING;
        end
        else
          state <= IDLE;
      end
      SERVING:begin
        if(t_msg == R_REQ)begin
          t_msg_out[serving]     <= MEM_RESP;
          t_address_out[serving] <= w_address_in[serving];
          state <= READ_OUT;
        end
        else if(t_msg == WB_REQ)begin
          t_msg_out[serving]     <= NO_REQ;
          t_address_out[serving] <= 0;
          state <= IDLE;
        end 
      end
      READ_OUT:begin
        t_msg_out[serving]     <= NO_REQ;
        t_address_out[serving] <= 0;
        state <= IDLE;
      end
      default: state <= IDLE;
    endcase
  end
end

// Drive outputs
generate
  for(i=0; i<NUM_PORTS; i=i+1)begin : OUTPUTS
    assign w_data_out[i] = (i==serving) & (state==READ_OUT) ? data_out0 : 0;
    assign msg_out[i*MSG_BITS +: MSG_BITS ]              =     t_msg_out[i];
    assign address_out[i*ADDRESS_WIDTH +: ADDRESS_WIDTH] = t_address_out[i];
    assign data_out[i*DATA_WIDTH +: DATA_WIDTH]          =    w_data_out[i];
  end
endgenerate

endmodule

