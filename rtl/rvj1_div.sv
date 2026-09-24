module rvj1_div import rvj1_pkg::*; (
  input logic             clk_i,
  input logic [XLEN-1:0]  op_a_i, // Dividend
  input logic [XLEN-1:0]  op_b_i, // Divisor
  input alu_op_e          div_op,
  output logic [XLEN-1:0] res_o
);

  logic [2*XLEN:0] op_a_ext [XLEN-1:0]; // w
  logic [XLEN:0] op_b_ext;   // d
  logic [XLEN-1:0]   q, q_new; // Quotient
  logic [XLEN-1:0]   r; // Remainder
  logic se_ab, se_bb; // sign(op_a_ext[x]) == sign(op_b_ext)
  logic div_active;
  assign div_active = (div_op == ALU_OP_DIV | div_op == ALU_OP_DIVU);

  assign op_b_ext    = {op_b_i[XLEN-1], op_b_i};

  assign op_a_ext[0] = {op_a_i[XLEN-1], op_a_i, {XLEN{1'b0}}};
  assign se_ab = (op_a_ext[0][2*XLEN] == op_b_ext[XLEN]);
  assign op_a_ext[1] = (se_ab) ?
	  {op_a_ext[0][2*XLEN-1:0], 1'b0} - op_b_ext :
	  {op_a_ext[0][2*XLEN-1:0], 1'b0} + op_b_ext;

  int i = 1;

  always_ff @(posedge clk_i & div_active) begin
//  always_comb begin
    if (div_active) begin
      if(i < XLEN) begin
//      for (i = 1; i < XLEN; i++) begin
        se_bb = (op_a_ext[i][2*XLEN-1] == op_b_ext[XLEN-1]);
        if (se_bb) begin
          q[XLEN-i] = 1'b1;
  	op_a_ext[i+1] = {op_a_ext[i][2*XLEN-2:0], 1'b0} - op_b_ext;
        end else op_a_ext[i+1] = {op_a_ext[i][2*XLEN-2:0], 1'b0} + op_b_ext;
	i = i + 1;
      end
  
      se_bb = (op_a_ext[XLEN-1][2*XLEN-1] == op_a_i[XLEN-1]);
      q[0] = se_bb; // Zero quotient bit also serves as correction indicator
      if (~se_bb) begin
        if (op_a_i[XLEN-1]) op_a_ext[XLEN-1] = op_a_ext[XLEN-1] + op_b_ext;
        else op_a_ext[XLEN-1] = op_a_ext[XLEN-1] - op_b_ext;
      end
    end
  end

  assign q_new = {~q[XLEN-2], q[XLEN-3:0], ~q[0]};
  assign r = op_a_ext[XLEN-1][XLEN*2-1:XLEN];

  assign res_o = (div_op == ALU_OP_DIV | div_op == ALU_OP_DIVU) ? q_new :
	         (div_op == ALU_OP_REM | div_op == ALU_OP_REMU) ? r :
		                                                'b0;
endmodule
