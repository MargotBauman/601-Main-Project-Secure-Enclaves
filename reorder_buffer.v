`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 11/20/2019 12:34:43 PM
// Design Name: 
// Module Name: reorder_buffer
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

//CODE BASED ON: 
//https://github.com/mattame/eecs470/blob/master/vsimp_base/verilog/reorder_buffer.v
//MAYBE MIPS?


////////////////////////////////////////////////////////////////
// This file houses modules for the inner workings of the ROB //
////////////////////////////////////////////////////////////////

/***
*   Each ROB Entry needs:
*     State
*     Register to be written to
*     Value to be written
***/
module reorder_buffer_entry #(
// parameters //
parameter ZERO_REG     = 5'd0,
parameter RSTAG_NULL   = 8'hFF,
parameter ROB_ENTRIES  = 32,//how many want?
parameter UNUSED_TAG_BITS = 3,//how many truly usused? what is theur tag?
//parameter SD #1;//what is SD?

// rob entry states //
parameter ROBE_EMPTY    = 2'b00,
parameter ROBE_INUSE    = 2'b01,
parameter ROBE_COMPLETE = 2'b10,
parameter ROBE_UNUSED   = 2'b11,

parameter DATA_WIDTH    = 32)
  /***  inputs  ***/
(  input reset, clock, write,
  input [7:0] tag_in,
  input [4:0] reg_in,

  input [(DATA_WIDTH -1):0] cdb1_value_in, cdb2_value_in,//WHAT IS CDB?? (SMTHING W/BRANCHES)
  input [7:0] cdb1_tag_in, cdb2_tag_in,
  input cdb1_mispredicted_in,cdb2_mispredicted_in,
  
  /***  outputs  ***/
  output reg [(DATA_WIDTH-1):0] value_out,
  output reg [4:0] reg_out,
  output reg [1:0] state_out,
  output reg mispredicted_out
  );

  /***  internals  ***/
  wire  [(DATA_WIDTH-1):0]  n_value;
  wire  [4:0]  n_reg;
  wire  [1:0]  n_state;
  wire  n_mispredicted;

  // combinational assignments //  WHY ARE THESE IN AN ALWAYS @ * block??
 assign n_state = (write) ? ROBE_INUSE : 
        (~write && ((tag_in == cdb1_tag_in) || (tag_in == cdb2_tag_in))) ? ROBE_COMPLETE :
        state_out;
        
 assign n_value = (write) ? 32'b0 :
        (~write && (tag_in == cdb1_tag_in)) ? cdb1_value_in :
        (~write && (tag_in == cdb2_tag_in)) ? cdb2_value_in :
        value_out;
        
 assign n_reg = (write) ? reg_in : reg_out;    
 
 assign n_mispredicted = (write) ? 1'b0 :
        (~write && (tag_in == cdb1_tag_in)) ? cdb1_mispredicted_in :
        (~write && (tag_in == cdb2_tag_in)) ? cdb2_mispredicted_in :
        mispredicted_out;          

  // clock synchronous events //
  always@(posedge clock)
  begin
     if (reset)
     begin
        state_out        <= ROBE_EMPTY;
        value_out        <= 32'b0;
        reg_out          <= RSTAG_NULL;
        mispredicted_out <= 1'b0;
     end
     else
     begin
        state_out        <= n_state;
        value_out        <= n_value;
        reg_out          <= n_reg;
        mispredicted_out <= n_mispredicted;
     end
  end

endmodule



/////////////////////
// main ROB module //
/////////////////////
// todo: integrate with rob entry module and set correct inputs for latching
// instruction 
// also, forwarding for the case of a full rob and trying to add instructions
// while retiring is not added, probably should be
module reorder_buffer #( 
// parameters //
parameter ZERO_REG     = 5'd0,
parameter RSTAG_NULL   = 8'hFF,
parameter ROB_ENTRIES  = 32,//how many want?
parameter UNUSED_TAG_BITS = 3,//how many truly usused? what is theur tag?
//parameter SD #1;//what is SD?

// rob entry states //
parameter ROBE_EMPTY    = 2'b00,
parameter ROBE_INUSE    = 2'b01,
parameter ROBE_COMPLETE = 2'b10,
parameter ROBE_UNUSED   = 2'b11,

parameter DATA_WIDTH    = 32)
   // inputs //
( input clock, reset, inst1_valid_in, inst2_valid_in,
   input [4:0] inst1_dest_in,
   input [4:0] inst2_dest_in,

   input [7:0] inst1_rs1_tag_in,
   input [7:0] inst1_rs2_tag_in,
   input [7:0] inst2_rs1_tag_in,
   input [7:0] inst2_rs2_tag_in,

   input [7:0]  cdb1_tag_in,
   input [7:0]  cdb2_tag_in,
   input [(DATA_WIDTH-1):0] cdb1_value_in,
   input [(DATA_WIDTH-1):0] cdb2_value_in,
   input cdb1_mispredicted_in,
   input cdb2_mispredicted_in,


   // outputs //
   output [7:0] inst1_tag_out,
   output [7:0] inst2_tag_out,

   output [(DATA_WIDTH-1):0] inst1_rs1_value_out,
   output [(DATA_WIDTH-1):0] inst1_rs2_value_out,
   output [(DATA_WIDTH-1):0] inst2_rs1_value_out,
   output [(DATA_WIDTH-1):0] inst2_rs2_value_out,

   output [4:0]  inst1_dest_out,
   output [(DATA_WIDTH-1):0] inst1_value_out,
   output [4:0]  inst2_dest_out,
   output [(DATA_WIDTH-1):0] inst2_value_out,

   output inst1_mispredicted_out,
   output inst2_mispredicted_out
   );

   wand rob_full;


   // internal regs/wires //
   wire [7:0] head_plus_one;
   wire [7:0] head_plus_two;
   wire [7:0] tail_plus_one; 
   wire [7:0] tail_plus_two;
   wire [7:0] tail_minus_one;
   reg  [7:0]   head;
   wire [7:0] n_head;
   reg  [7:0]   tail;
   wire [7:0] n_tail;
   wand    rob_empty;


   // regs/wires for talking directly to the reorder buffer entries //
   wire [(ROB_ENTRIES-1):0] resets;
   wire [(ROB_ENTRIES-1):0] writes;
   wire [7:0]  tags_in       [(ROB_ENTRIES-1):0];
   wire [4:0]  registers_in  [(ROB_ENTRIES-1):0];
   wire [63:0] values_out    [(ROB_ENTRIES-1):0];
   wire [4:0]  registers_out [(ROB_ENTRIES-1):0];
   wire [1:0]  states_out    [(ROB_ENTRIES-1):0]; 
   wire [(ROB_ENTRIES-1):0] mispredicteds_out; 
   
   wire inst1_retire, inst2_retire, inst1_dispatch, inst2_dispatch;

   // combinational assignments for head/tail plus one and two. accounts //
   // for overflow  //
   assign head_plus_one  = (head==(ROB_ENTRIES-1)) ? 8'd0 : head+8'd1;
   assign head_plus_two  = (head==(ROB_ENTRIES-1)) ? 8'd1 : ( (head==(ROB_ENTRIES-2)) ? 8'd0 : head+8'd2 );
   assign tail_plus_one  = (tail==(ROB_ENTRIES-1)) ? 8'd0 : tail+8'd1;                                         
   assign tail_plus_two  = (tail==(ROB_ENTRIES-1)) ? 8'd1 : ( (tail==(ROB_ENTRIES-2)) ? 8'd0 : tail+8'd2 );
   assign tail_minus_one = (tail==8'd0) ? (ROB_ENTRIES-1) : tail-8'd1;

   // combinational assignments for signals //
   assign inst1_retire   =                  (states_out[head         ]==ROBE_COMPLETE);
   assign inst2_retire   = (inst1_retire && (states_out[head_plus_one]==ROBE_COMPLETE) );
   assign inst1_dispatch = ( ~rob_full && (inst1_valid_in || (~inst1_valid_in && inst2_valid_in)) ); 
   assign inst2_dispatch = ( ~rob_full && (inst1_valid_in && inst2_valid_in) );


   // insternal assignments for tag comparisions //
   //assign head_lt_tail = (head<tail);   


   // combinational assignments for next state signals //
   assign n_head = ( inst1_retire   ? (inst2_retire   ? head_plus_two : head_plus_one) : head );   // if retiring one inst, inc by one. if two, inc by two
   assign n_tail = ( inst1_dispatch ? (inst2_dispatch ? tail_plus_two : tail_plus_one) : tail );   // if dispatching one inst, inc by one. if two, inc by two


   // for tag outputs (to rs) //
   assign inst1_tag_out = (inst1_dispatch ? tail_minus_one : RSTAG_NULL);
   assign inst2_tag_out = (inst2_dispatch ? tail           : RSTAG_NULL);

   // assign appropriate outputs for from-rob values //
   // tags in are broken down to remove the ready-in-rob-bit //
   assign inst1_rs1_value_out = values_out[ { {UNUSED_TAG_BITS{1'b0}}, inst1_rs1_tag_in[(7-UNUSED_TAG_BITS):0] } ]; 
   assign inst1_rs2_value_out = values_out[ { {UNUSED_TAG_BITS{1'b0}}, inst1_rs2_tag_in[(7-UNUSED_TAG_BITS):0] } ];
   assign inst2_rs1_value_out = values_out[ { {UNUSED_TAG_BITS{1'b0}}, inst2_rs1_tag_in[(7-UNUSED_TAG_BITS):0] } ];
   assign inst2_rs2_value_out = values_out[ { {UNUSED_TAG_BITS{1'b0}}, inst2_rs2_tag_in[(7-UNUSED_TAG_BITS):0] } ];


   // assignments for reg file outputs //
   assign inst1_dest_out  = (inst1_retire ? registers_out[head         ] : ZERO_REG);
   assign inst1_value_out = (inst1_retire ? values_out[   head         ] : 32'd0);
   assign inst2_dest_out  = (inst2_retire ? registers_out[head_plus_one] : ZERO_REG);
   assign inst2_value_out = (inst2_retire ? values_out[   head_plus_one] : 32'd0);

   // mispredicted out assignments //
   assign inst1_mispredicted_out = (inst1_retire ? mispredicteds_out[head         ] : 1'b0);
   assign inst2_mispredicted_out = (inst2_retire ? mispredicteds_out[head_plus_one] : 1'b0);

   // assignments for rob entry inputs //
   genvar i;
   generate
      for (i=0; i<ROB_ENTRIES; i=i+1)
      begin : ASSIGNROBEINPUTS
         assign resets[i]       = (reset || (head==i && inst1_retire) || (head_plus_one==i && inst2_retire));
         assign writes[i]       = (tail_plus_one==i && inst1_dispatch) || (tail_plus_two==i && inst2_dispatch); 
         assign registers_in[i] = (tail_plus_one==i) ? inst1_dest_in : ((tail_plus_two==i) ? inst2_dest_in : ZERO_REG);
      end
   endgenerate
   
   
   // assignments for rob empty/full states //
   generate
      for (i=0; i<ROB_ENTRIES; i=i+1)
	  begin : ASSIGNEMPTYFULLSTATES
	     assign rob_empty = (states_out[i]==ROBE_EMPTY);                                    // this is a wand
	     assign rob_full  = (states_out[i]==ROBE_INUSE || states_out[i]==ROBE_COMPLETE);   // again, a wand
	  end
   endgenerate

   // internal modules for ROB entries //
   generate 
      for (i=0; i<ROB_ENTRIES; i=i+1)
      begin : CREATEROBES

      reorder_buffer_entry entries ( .clock(clock), .reset(resets[i]), .write(writes[i]),
                                       
                    .tag_in( i[7:0] ),
                    .reg_in(registers_in[i]),       
               
                    .cdb1_tag_in(cdb1_tag_in), .cdb1_value_in(cdb1_value_in),
                    .cdb2_tag_in(cdb2_tag_in), .cdb2_value_in(cdb2_value_in),
                    .cdb1_mispredicted_in(cdb1_mispredicted_in), .cdb2_mispredicted_in(cdb2_mispredicted_in),

                    .value_out(values_out[i]),
                    .reg_out(registers_out[i]),
                    .state_out(states_out[i]),
                    .mispredicted_out(mispredicteds_out[i])

                         );

      end
   endgenerate


   // clock-synchronouse assignments for //
   always@(posedge clock)
   begin
      if (reset)
      begin
         head      <= 8'd0;
         tail      <= (ROB_ENTRIES-1);
      end
      else
      begin
         head      <= n_head;
         tail      <= n_tail;
      end
   end

endmodule
