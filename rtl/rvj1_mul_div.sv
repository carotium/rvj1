// Multiple cycle multiplication
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

  localparam int unsigned COUNT_WIDTH = $clog2(XLEN);

  typedef enum logic [2:0] {
    eBOOTH_IDLE,
    eBOOTH_LL,
    eBOOTH_LH,
    eBOOTH_HL,
    eBOOTH_HH,
    eBOOTH_DONE
  } booth_fsm_e;
  booth_fsm_e state, state_next;

  logic [15:0]   op_a_H, op_a_L, op_b_H, op_b_L;
  logic [17:0]   op_a_H_ext, op_a_L_ext, op_b_H_ext, op_b_L_ext;

  logic [17:0]   booth_mul_a, booth_mul_b;
  logic [XLEN*2-1:0] booth_pp [8:0];
  logic [XLEN*2-1:0] booth_pp_acc;
  logic [6:0] booth_shift;

  logic [XLEN*2-1:0] booth_res_acc;
  logic [XLEN*2-1:0] res_mul;
  logic              is_mul;

  assign op_a_H = op_a_i[XLEN-1:16];
  assign op_a_L = op_a_i[15:0];
  assign op_b_H = op_b_i[XLEN-1:16];
  assign op_b_L = op_b_i[15:0];

  assign op_a_H_ext = (sel_i == MUL_OP_MUL || sel_i == MUL_OP_MULH || sel_i == MUL_OP_MULHSU) ? {{2{op_a_H[15]}}, op_a_H} : {2'b0, op_a_H};
  assign op_a_L_ext = {2'b0, op_a_L};
  assign op_b_H_ext = (sel_i == MUL_OP_MUL || sel_i == MUL_OP_MULH) ? {{2{op_b_H[15]}}, op_b_H} : {2'b0, op_b_H};
  assign op_b_L_ext = {2'b0, op_b_L};

  booth_core_half #(.XLEN(XLEN)) booth_mult (
    .op_a_ext(booth_mul_a),
    .op_b_ext(booth_mul_b),
    .pp(booth_pp)
  );

  always_comb begin
    is_mul = 1'b0;
    booth_pp_acc = ~(state == eBOOTH_IDLE || state == eBOOTH_DONE) ? (booth_pp[0] + booth_pp[1] + booth_pp[2] + booth_pp[3]
                 + booth_pp[4] + booth_pp[5] + booth_pp[6] + booth_pp[7] + booth_pp[8]) : '0;
    booth_mul_a = '0;
    booth_mul_b = '0;
    booth_shift = '0;
    unique case(state)
      eBOOTH_IDLE: begin
	if (sel_i == MUL_OP_MUL || sel_i == MUL_OP_MULH || sel_i == MUL_OP_MULHSU || sel_i == MUL_OP_MULHU) begin
//	  booth_pp_acc = '0;
	  booth_mul_a = '0;
	  booth_mul_b = '0;
	  state_next = (mul_div_en_i) ? eBOOTH_LL : eBOOTH_IDLE;
	end else begin
          state_next = eBOOTH_IDLE;
	end
      end
      eBOOTH_LL: begin
	if (sel_i == MUL_OP_MUL || sel_i == MUL_OP_MULH || sel_i == MUL_OP_MULHSU || sel_i == MUL_OP_MULHU) begin
	  is_mul      = 1'b1;
	  booth_mul_a = op_a_L_ext;
	  booth_mul_b = op_b_L_ext;
	  booth_shift = '0;
	  state_next = eBOOTH_LH;
	end
      end
      eBOOTH_LH: begin
	if (sel_i == MUL_OP_MUL || sel_i == MUL_OP_MULH || sel_i == MUL_OP_MULHSU || sel_i == MUL_OP_MULHU) begin
	  is_mul      = 1'b1;
          booth_mul_a = op_a_L_ext;
	  booth_mul_b = op_b_H_ext;
	  booth_shift = 16;
	  state_next = eBOOTH_HL;
	end
      end
      eBOOTH_HL: begin
	if (sel_i == MUL_OP_MUL || sel_i == MUL_OP_MULH || sel_i == MUL_OP_MULHSU || sel_i == MUL_OP_MULHU) begin
	  is_mul      = 1'b1;
	  booth_mul_a = op_a_H_ext;
	  booth_mul_b = op_b_L_ext;
	  booth_shift = 16;
	  state_next = (sel_i == MUL_OP_MUL) ? eBOOTH_DONE : eBOOTH_HH;
	end
      end
      eBOOTH_HH: begin
	  is_mul      = 1'b1;
        if (sel_i == MUL_OP_MULH || sel_i == MUL_OP_MULHSU || sel_i == MUL_OP_MULHU) begin
	  booth_mul_a = op_a_H_ext;
	  booth_mul_b = op_b_H_ext;
	  booth_shift = 32;
	  state_next = eBOOTH_DONE;
	end
      end
      eBOOTH_DONE: begin
        res_mul = booth_res_acc;
	state_next = eBOOTH_IDLE;
      end
    endcase
  end

  always_ff @(posedge clk_i) begin
    if (~rstn_i) begin
      state <= eBOOTH_IDLE;
    end else state <= state_next;
//    end else if (mul_div_en_i) begin
//      state <= eBOOTH_LL;
//    end else if (state = eBOOTH_LL) begin
//      state <= state_next;
//    end else
//      state <= eBOOTH_IDLE;
  end

  register_wclear #(.DTYPE(logic [63:0])
  ) booth_res_acc_inst (
    .clk  (clk_i),
    .rstn (rstn_i),
    .clear (state == eBOOTH_IDLE),
    .ce   (state != eBOOTH_IDLE),
    .in   (booth_res_acc + (booth_pp_acc << booth_shift)),
    .out  (booth_res_acc)
  );


  logic [XLEN-1:0] res_rem, res_div, res_mux;

  logic                   r_ready;
  logic                   r_signed_ope;
  logic [COUNT_WIDTH-1:0] r_count;
  logic [XLEN-1:0]        r_quotient;
  logic                   w_dividend_sign;
  logic                   r_dividend_sign;
  logic                   remainder_sign;
  logic [XLEN:0]          r_remainder;
  logic [XLEN-1:0]        r_divisor;
  logic [XLEN:0]          divisor_ext;
  logic                   divisor_sign;
  logic [XLEN:0]          rem_quo;
  logic                   diff_sign;
  logic [XLEN:0]          sub_add;
  logic                   signed_ope;

  assign signed_ope = (sel_i == MUL_OP_DIV || sel_i == MUL_OP_REM);
  assign w_dividend_sign = op_a_i[XLEN-1] & signed_ope;
  assign ready = r_ready;
  assign divisor_sign = r_divisor[XLEN-1] & r_signed_ope;
  assign divisor_ext = {divisor_sign, r_divisor};
  assign remainder_sign = r_remainder[XLEN];
  assign rem_quo = {r_remainder[XLEN-1:0], r_quotient[XLEN-1]};
  assign diff_sign = remainder_sign ^ divisor_sign;
  assign sub_add = diff_sign ? rem_quo + divisor_ext :
                               rem_quo - divisor_ext;

  // After process
  always_comb begin
    res_div  = (r_quotient << 1) | 1;
    res_rem = r_remainder[XLEN-1:0];

    if (r_remainder == 0) begin
      // Do nothing
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

  always_ff @(posedge clk_i) begin
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
        r_quotient      <=  {r_quotient[XLEN-2:0], ~diff_sign};
        r_remainder     <=  sub_add[XLEN:0];
        r_count         <=  r_count + 1;
        if (r_count == XLEN - 1) begin
          r_ready       <=  1'b1;
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
