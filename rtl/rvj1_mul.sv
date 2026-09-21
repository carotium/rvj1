module rvj1_mul import rvj1_pkg::*; (
  input  logic [XLEN-1:0] op_a_i,
  input  logic [XLEN-1:0] op_b_i,
  input  alu_op_e         mul_op,
  output logic [XLEN*2-1:0] res_o
);

  /*******************************
  * STAGE 1
  *******************************/
  logic op_a_signed, op_b_signed;
  // MUL, MULH or MULHSU opcode
  assign op_a_signed = (mul_op == ALU_OP_MUL || mul_op == ALU_OP_MULH || mul_op == ALU_OP_MULHSU);
  // MUL, MULH opcode
  assign op_b_signed = (mul_op == ALU_OP_MUL || mul_op ==  ALU_OP_MULH);

  logic [XLEN:0] op_a_ext, op_b_ext;
  assign op_a_ext = op_a_signed ? {op_a_i[XLEN-1], op_a_i} : {1'b0, op_a_i};
  assign op_b_ext = op_b_signed ? {op_b_i[XLEN-1], op_b_i} : {1'b0, op_b_i};

  logic [XLEN*2-1:0] pp [15:0];

  booth_core #(.XLEN(XLEN)) booth_mult (
    .op_a_ext(op_a_ext),
    .op_b_ext(op_b_ext),
    .pp(pp)
  );

  logic [XLEN*2-1:0] res;
  always_comb begin
    // Add partial products
    res = pp[0] + pp[1] + pp[2] + pp[3] +
	  pp[4] + pp[5] + pp[6] + pp[7] +
	  pp[8] + pp[9] + pp[10] + pp[11] +
	  pp[12] + pp[13] + pp[14] + pp[15];
  end

  assign res_o = res;

endmodule
