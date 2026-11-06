// Multiple cycle multiplication
module rvj1_mul_div import rvj1_pkg::*; (
  input  logic            clk_i,
  input  logic            rstn_i,
  input  logic [XLEN-1:0] op_a_i, // Multiplicand | Dividend
  input  logic [XLEN-1:0] op_b_i, // Multiplier   | Divisor
  input  mul_op_e         sel_i,
  input  logic            mul_div_en_i,  // Start on enable pulse
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
  booth_fsm_e booth_state, booth_state_n;

  typedef enum logic [1:0] {
    eDIV_IDLE,
    eDIV_CALC,
    eDIV_DBZ
  } div_fsm_e;
  div_fsm_e div_state, div_state_n;

  logic [XLEN*2:0] res_acc;
  logic [XLEN*2:0] res_acc_n;

  /******* Multiplication *******/
  logic [15:0]   op_a_H, op_a_L, op_b_H, op_b_L;
  logic [16:0]   op_a_H_ext, op_a_L_ext, op_b_H_ext, op_b_L_ext;

  logic [16:0]   booth_mul_a, booth_mul_b;
  logic [XLEN*2-1:0] booth_pp [8:0];
  logic [XLEN*2-1:0] booth_pp_acc;
  logic [6:0] booth_shift;

  logic is_mul;
  logic is_mul_lower;
  logic is_mul_upper;
  logic is_mul_a_signed;
  logic is_mul_b_signed;

  /******* Division *******/
  logic [COUNT_WIDTH-1:0] div_counter;
  logic                   a_sign, b_sign, sign_diff;
  logic [XLEN-1:0]        au, bu; // Unsigned operands

  logic dbz;
  logic is_div_signed;
  logic is_div_div;
  logic is_div_rem;
  logic is_div;

  /******* Multiplication *******/
  assign is_mul_a_signed = (sel_i == MUL_OP_MUL || sel_i == MUL_OP_MULH || sel_i == MUL_OP_MULHSU);
  assign is_mul_b_signed = (sel_i == MUL_OP_MUL || sel_i == MUL_OP_MULH);
  assign is_mul_lower = (sel_i == MUL_OP_MUL);
  assign is_mul_upper = (sel_i == MUL_OP_MULH || sel_i == MUL_OP_MULHU || sel_i == MUL_OP_MULHSU);
  assign is_mul = (is_mul_lower || is_mul_upper);

  assign op_a_H = op_a_i[XLEN-1:16];
  assign op_a_L = op_a_i[15:0];
  assign op_b_H = op_b_i[XLEN-1:16];
  assign op_b_L = op_b_i[15:0];

  assign op_a_H_ext = (is_mul_a_signed) ? {op_a_H[15], op_a_H} : {1'b0, op_a_H};
  assign op_a_L_ext = {1'b0, op_a_L};
  assign op_b_H_ext = (is_mul_b_signed) ? {op_b_H[15], op_b_H} : {1'b0, op_b_H};
  assign op_b_L_ext = {1'b0, op_b_L};

  // Check synthesis for type of adder (tree or sequential)
  // Maybe resolve with using parantheses
  assign booth_pp_acc = (booth_pp[0] + booth_pp[1] + booth_pp[2] + booth_pp[3] + booth_pp[4] + 
                         booth_pp[5] + booth_pp[6] + booth_pp[7] + booth_pp[8]);

  always_comb begin
    booth_mul_a = '0;
    booth_mul_b = '0;
    booth_shift = '0;
    if (is_mul) res_acc_n   = '0;

    unique case(booth_state)
      eBOOTH_IDLE: begin
	      if (is_mul) booth_state_n = (mul_div_en_i) ? eBOOTH_LL : eBOOTH_IDLE;
        else booth_state_n = eBOOTH_IDLE;
      end
      eBOOTH_LL: begin
      	if (is_mul) begin
          booth_state_n = eBOOTH_LH;
          booth_mul_a      = op_a_L_ext;
          booth_mul_b      = op_b_L_ext;
          booth_shift      = '0;
	      end
      end
      eBOOTH_LH: begin
	      if (is_mul) begin
          booth_state_n = eBOOTH_HL;
          booth_mul_a      = op_a_L_ext;
          booth_mul_b      = op_b_H_ext;
          booth_shift      = 16;
	      end
      end
      eBOOTH_HL: begin
        if (is_mul) begin
          booth_state_n = (is_mul_lower) ? eBOOTH_DONE : eBOOTH_HH;
          booth_mul_a      = op_a_H_ext;
          booth_mul_b      = op_b_L_ext;
          booth_shift      = 16;
        end
      end
      eBOOTH_HH: begin
        if (is_mul_upper) begin
          booth_state_n = eBOOTH_DONE;
          booth_mul_a      = op_a_H_ext;
          booth_mul_b      = op_b_H_ext;
          booth_shift      = 32;
	      end
      end
      eBOOTH_DONE: begin
      	booth_state_n = eBOOTH_IDLE;
      end
    endcase

    if (is_mul && booth_state != eBOOTH_IDLE) res_acc_n = (res_acc + (booth_pp_acc << booth_shift));

  end

  booth_core_half #(.XLEN(XLEN)) booth_mult (
    .op_a_ext(booth_mul_a),
    .op_b_ext(booth_mul_b),
    .pp(booth_pp)
  );

  /******* Division *******/
  assign dbz = (op_b_i == '0);

  assign is_div_signed = (sel_i == MUL_OP_DIV || sel_i == MUL_OP_REM);
  assign is_div_div = (sel_i == MUL_OP_DIV || sel_i == MUL_OP_DIVU);
  assign is_div_rem = (sel_i == MUL_OP_REM || sel_i == MUL_OP_REMU);
  assign is_div = (is_div_div || is_div_rem);  

  assign a_sign = op_a_i[XLEN-1] & is_div_signed;
  assign b_sign = op_b_i[XLEN-1] & is_div_signed;
  assign sign_diff = (a_sign ^ b_sign);

  assign au = (a_sign) ? -op_a_i[XLEN-1:0] : op_a_i[XLEN-1:0];
  assign bu = (b_sign) ? -op_b_i[XLEN-1:0] : op_b_i[XLEN-1:0];

  always_comb begin
    div_state_n = eDIV_IDLE;
    res_acc_n = '0;
    unique case(div_state)
      eDIV_IDLE: begin
        div_state_n = eDIV_IDLE;
        if (mul_div_en_i && is_div) begin
          div_state_n = (op_b_i == '0) ? eDIV_DBZ : eDIV_CALC;
          res_acc_n = {{(XLEN){1'b0}}, au, 1'b0};
        end else res_acc_n = res_acc;
      end
      eDIV_CALC: begin
        if (div_counter <= (XLEN - 1)) begin
          div_state_n = (div_counter == XLEN - 1) ? eDIV_IDLE : eDIV_CALC;
          if (res_acc[64:32] >= bu) begin
	          res_acc_n[64:32] = res_acc[64:32] - bu;
	          res_acc_n = {res_acc_n[63:32], res_acc[31:0], 1'b1};
          end else res_acc_n = res_acc << 1;
        end
      end
      eDIV_DBZ: begin
        div_state_n = (div_counter == XLEN - 1) ? eDIV_IDLE : eDIV_DBZ;
      end
      default:;
    endcase
  end

  assign res_o =  (div_state == eDIV_IDLE || booth_state == eBOOTH_DONE)  ?
                  ((is_div_div && dbz)                ?  '1               :
	                 (sel_i == MUL_OP_DIV && sign_diff) ? -res_acc_n[31:0]  :
	  	             (is_div_div)                       ?  res_acc_n[31:0]  :
		               (is_div_rem && dbz)                ?  op_a_i           :
	                 (sel_i == MUL_OP_REM && a_sign)    ? -res_acc_n[64:33] :
	                 (is_div_rem)                       ?  res_acc_n[64:33] :
		               (is_mul_lower)                     ?  res_acc_n[31:0]  :
		               (is_mul_upper)                     ?  res_acc_n[63:32] : '0) : '0;

  cntr #(
    .WORD_WIDTH ($clog2(XLEN)),
    .RESET_VALUE(0)
  ) div_counter_inst (
    .clk   (clk_i),
    .rstn  (rstn_i),
    .clear (div_state == eDIV_IDLE),
    .ce    (div_state == eDIV_CALC || div_state == eDIV_DBZ),
    .count (div_counter)
  );

  register #(
    .DTYPE(logic [65:0])
  ) res_acc_inst (
    .clk  (clk_i),
    .rstn (rstn_i),
    .ce   (1'b1),
    .in   (res_acc_n),
    .out  (res_acc)
  );

  register #(
    .DTYPE(booth_fsm_e),
    .RESET_VALUE(eBOOTH_IDLE)
  ) booth_state_inst (
    .clk  (clk_i),
    .rstn (rstn_i),
    .ce   (1'b1),
    .in   (booth_state_n),
    .out  (booth_state)
  );

  register #(
    .DTYPE(div_fsm_e),
    .RESET_VALUE(eDIV_IDLE)
  ) div_state_inst (
    .clk  (clk_i),
    .rstn (rstn_i),
    .ce   (1'b1),
    .in   (div_state_n),
    .out  (div_state)
  );

endmodule
