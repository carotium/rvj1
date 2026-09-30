module rvj1_mul_div import rvj1_pkg::*; (
  input  logic            clk_i,
  input  logic            rstn_i,
  input  logic [XLEN-1:0] op_a_i, // Multiplicand | Dividend
  input  logic [XLEN-1:0] op_b_i, // Multiplier   | Divisor
  input  mul_op_e         sel_i,
  input  logic            mul_div_en_i,  // Enable
  output logic            ready,
  output logic [XLEN-1:0] res_o
);

  logic [XLEN-1:0] res_mux;

  logic [XLEN:0] op_a_ext, op_b_ext;
  assign op_a_ext = {op_a_i[XLEN-1], op_a_i};
  assign op_b_ext = {op_b_i[XLEN-1], op_b_i};

  logic [XLEN*2-1:0] pp [15:0];

  booth_core #(.XLEN(XLEN)) booth_mult (
    .op_a_ext(op_a_ext),
    .op_b_ext(op_b_ext),
    .pp(pp)
  );

  logic [XLEN*2-1:0] res_mul;
  always_comb begin
    // Add partial products
    res_mul = pp[0] + pp[1] + pp[2] + pp[3] +
	  pp[4] + pp[5] + pp[6] + pp[7] +
	  pp[8] + pp[9] + pp[10] + pp[11] +
	  pp[12] + pp[13] + pp[14] + pp[15];
  end

localparam int unsigned COUNT_WIDTH = $clog2(XLEN);

  logic r_ready;
  logic r_signed_ope;
  logic [COUNT_WIDTH-1:0] r_count;
  logic [XLEN-1:0] r_quotient;
  logic w_dividend_sign;
  logic r_dividend_sign;
  logic remainder_sign;
  logic [XLEN:0] r_remainder;
  logic [XLEN-1:0] r_divisor;
  logic [XLEN:0] divisor_ext;
  logic divisor_sign;
  logic [XLEN:0] rem_quo;
  logic                diff_sign;
  logic [XLEN:0] sub_add;

  assign ready = r_ready;
  assign divisor_sign = r_divisor[XLEN-1] & r_signed_ope;
  assign divisor_ext = {divisor_sign, r_divisor};
  assign remainder_sign = r_remainder[XLEN];

  assign rem_quo = {r_remainder[XLEN-1:0], r_quotient[XLEN-1]};
  assign diff_sign = remainder_sign ^ divisor_sign;
  assign sub_add = diff_sign ? rem_quo + divisor_ext :
                               rem_quo - divisor_ext;

  logic [XLEN-1:0] res_rem, res_div;
  // after process
  always_comb begin
    res_div  = (r_quotient << 1) | 1;
    res_rem = r_remainder[XLEN-1:0];

    if (r_remainder == 0) begin
      // do nothing
    end else if (r_remainder == divisor_ext) begin
      res_div  = res_div + 1;
      res_rem = res_rem - r_divisor;
    end else if (r_remainder == -divisor_ext) begin
      res_div  = res_div - 1;
      res_rem = res_rem + r_divisor;
    end else if (remainder_sign ^ r_dividend_sign) begin
      if (diff_sign) begin
        res_div  = res_div - 1;
        res_rem = res_rem + r_divisor;
      end else begin
        res_div  = res_div + 1;
        res_rem = res_rem - r_divisor;
      end
    end
  end

  logic signed_ope;
  assign signed_ope = (sel_i == MUL_OP_DIV || sel_i == MUL_OP_REM);
  assign w_dividend_sign = op_a_i[XLEN-1] & signed_ope;

  always @(posedge clk_i or negedge rstn_i) begin
    if (~rstn_i) begin
      r_quotient      <=  '0;
      r_dividend_sign <=  '0;
      r_remainder     <=  '0;
      r_divisor       <=  '0;
      r_count         <=  '0;
      r_ready         <=  1'b1;
      r_signed_ope    <=  1'b0;
    end else begin
      if (mul_div_en_i) begin
        // RISC-V's div by 0 spec
        if (op_b_i == '0) begin
            r_quotient  <=  '1;
            r_remainder <=  {w_dividend_sign, op_a_i};
        end else begin
            r_quotient  <=  op_a_i;
            r_remainder <=  {(XLEN+1){w_dividend_sign}};
            r_ready     <=  1'b0;
        end
        r_count         <=  '0;
        r_dividend_sign <=  w_dividend_sign;
        r_divisor       <=  op_b_i;
        r_signed_ope    <=  signed_ope;
      end else if (~ready) begin
        r_quotient  <=  {r_quotient[XLEN-2:0], ~diff_sign};
        r_remainder <=  sub_add[XLEN:0];
        r_count     <=  r_count + 1;
        if (r_count == XLEN - 1) begin
          r_ready <=  1'b1;
        end
      end
    end
  end

  // Output assignment
  always_comb begin
    unique case (sel_i)
      MUL_OP_MUL: begin
        res_mux = res_mul[XLEN-1:0];
      end
      MUL_OP_MULH, MUL_OP_MULHSU, MUL_OP_MULHU: begin
	res_mux = res_mul[XLEN*2-1:XLEN];
      end
      MUL_OP_DIV, MUL_OP_DIVU: begin
	res_mux = res_div;
      end
      MUL_OP_REM, MUL_OP_REMU: begin
	res_mux = res_rem;
      end
    endcase
  end

  register #(
    .DTYPE(logic [XLEN-1:0]),
    .RESET_VALUE(0)
  ) res_reg_inst (
    .clk  (clk_i),
    .rstn (rstn_i),
    .ce   (1'b1),
    .in   (res_mux),
    .out  (res_o)
  );

endmodule
