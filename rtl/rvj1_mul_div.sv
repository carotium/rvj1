// Multiple cycle multiplication
module rvj1_mul_div import rvj1_pkg::*; (
  input  logic            clk_i,
  input  logic            rstn_i,
  input  logic [XLEN-1:0] op_a_i, // Multiplicand | Dividend
  input  logic [XLEN-1:0] op_b_i, // Multiplier   | Divisor
  input  mul_op_e         sel_i,
  input  logic            mul_div_en_i,  // Enable
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
  booth_fsm_e booth_state, booth_state_next;

  typedef enum logic [1:0] {
    eDIV_IDLE,
    eDIV_CALC,
    eDIV_DBZ,
    eDIV_DONE
  } div_fsm_e;
  div_fsm_e div_state, div_state_n;

  /******* Multiplication *******/
  logic [15:0]   op_a_H, op_a_L, op_b_H, op_b_L;
  logic [16:0]   op_a_H_ext, op_a_L_ext, op_b_H_ext, op_b_L_ext;

  logic [16:0]   booth_mul_a, booth_mul_b;
  logic [XLEN*2-1:0] booth_pp [8:0];
  logic [XLEN*2-1:0] booth_pp_acc;
  logic [6:0] booth_shift;

  logic [XLEN*2:0] booth_res_acc;
  logic [XLEN*2:0] booth_res_acc_n;

  logic [XLEN*2-1:0] res_mul;
  logic is_mul;
  logic is_mul_lower;
  logic is_mul_upper;
  logic is_mul_a_signed;
  logic is_mul_b_signed;

  /******* Division *******/
  logic [COUNT_WIDTH-1:0] div_counter;
  logic [XLEN-1:0]        quo, quo_n;
  logic [XLEN:0]          acc, acc_n;
  logic                   a_sign, b_sign, sign_diff;
  logic [XLEN-1:0]        au, bu;                     // Unsigned operands
  logic dbz;
  logic signed_operation;

  logic is_div;
  logic is_div_div;
  logic is_div_rem;

  assign is_mul_lower = (sel_i == MUL_OP_MUL);
  assign is_mul_upper = (sel_i == MUL_OP_MULH || sel_i == MUL_OP_MULHU || sel_i == MUL_OP_MULHSU);
  assign is_mul_a_signed = (sel_i == MUL_OP_MUL || sel_i == MUL_OP_MULH || sel_i == MUL_OP_MULHSU);
  assign is_mul_b_signed = (sel_i == MUL_OP_MUL || sel_i == MUL_OP_MULH);
  assign is_mul = (is_mul_lower || is_mul_upper);

  assign is_div_div = (sel_i == MUL_OP_DIV || sel_i == MUL_OP_DIVU);
  assign is_div_rem = (sel_i == MUL_OP_REM || sel_i == MUL_OP_REMU);
  assign is_div = (is_div_div || is_div_rem);

  assign op_a_H = op_a_i[XLEN-1:16];
  assign op_a_L = op_a_i[15:0];
  assign op_b_H = op_b_i[XLEN-1:16];
  assign op_b_L = op_b_i[15:0];

  assign op_a_H_ext = (is_mul_a_signed) ? {op_a_H[15], op_a_H} : {1'b0, op_a_H};
  assign op_a_L_ext = {1'b0, op_a_L};
  assign op_b_H_ext = (is_mul_b_signed) ? {op_b_H[15], op_b_H} : {1'b0, op_b_H};
  assign op_b_L_ext = {1'b0, op_b_L};

  booth_core_half #(.XLEN(XLEN)) booth_mult (
    .op_a_ext(booth_mul_a),
    .op_b_ext(booth_mul_b),
    .pp(booth_pp)
  );

    // Preveri else assign (ce je potreben)
    // Sinteza ali je sestevalnik tree ali seq
    assign booth_pp_acc = ~(booth_state == eBOOTH_IDLE || booth_state == eBOOTH_DONE) ? (booth_pp[0] + booth_pp[1] + booth_pp[2] + booth_pp[3]
                 + booth_pp[4] + booth_pp[5] + booth_pp[6] + booth_pp[7] + booth_pp[8]) : '0;

  always_comb begin
    booth_mul_a = '0;
    booth_mul_b = '0;
    booth_shift = '0;
    unique case(booth_state)
      eBOOTH_IDLE: begin
	if (is_mul) begin
	  booth_mul_a = '0;
	  booth_mul_b = '0;
	  booth_state_next = (mul_div_en_i) ? eBOOTH_LL : eBOOTH_IDLE;
	end else begin
          booth_state_next = eBOOTH_IDLE;
	end
      end
      eBOOTH_LL: begin
	if (is_mul) begin
	  booth_mul_a = op_a_L_ext;
	  booth_mul_b = op_b_L_ext;
	  booth_shift = '0;
	  booth_state_next = eBOOTH_LH;
	end
      end
      eBOOTH_LH: begin
	if (is_mul) begin
          booth_mul_a = op_a_L_ext;
	  booth_mul_b = op_b_H_ext;
	  booth_shift = 16;
	  booth_state_next = eBOOTH_HL;
	end
      end
      eBOOTH_HL: begin
	if (is_mul) begin
	  booth_mul_a = op_a_H_ext;
	  booth_mul_b = op_b_L_ext;
	  booth_shift = 16;
	  booth_state_next = (sel_i == MUL_OP_MUL) ? eBOOTH_DONE : eBOOTH_HH;
	end
      end
      eBOOTH_HH: begin
        if (sel_i == MUL_OP_MULH || sel_i == MUL_OP_MULHSU || sel_i == MUL_OP_MULHU) begin
	  booth_mul_a = op_a_H_ext;
	  booth_mul_b = op_b_H_ext;
	  booth_shift = 32;
	  booth_state_next = eBOOTH_DONE;
	end
      end
      eBOOTH_DONE: begin
        res_mul = booth_res_acc[63:0];
	booth_state_next = eBOOTH_IDLE;
      end
    endcase
  end

  assign signed_operation = (sel_i == MUL_OP_DIV || sel_i == MUL_OP_REM);
  assign a_sign = op_a_i[XLEN-1] & signed_operation;
  assign b_sign = op_b_i[XLEN-1] & signed_operation;
  assign sign_diff = (a_sign ^ b_sign);

  assign au = (a_sign) ? -op_a_i[XLEN-1:0] : op_a_i[XLEN-1:0];
  assign bu = (b_sign) ? -op_b_i[XLEN-1:0] : op_b_i[XLEN-1:0];
  
  // spremeni ime booth_res_acc
//  assign quotient = booth_res_acc[32:0];
//  assign remainder = booth_res_acc[64:33];

//  pogoj kot signal
 
//  assign booth_res_acc_n = (signed_operation && sign_diff) ? -{acc, quo} : 
//	                   (signed_operation)              ?  {acc, quo} : '0;

  always_comb begin
    unique case(div_state)
      eDIV_IDLE: begin
        dbz     = 1'b0;
        div_state_n = eDIV_IDLE;
        if (mul_div_en_i && (is_div)) begin
          div_state_n = eDIV_CALC;
          if (op_b_i == '0) begin     // Division by zero
            div_state_n = eDIV_DBZ;
            dbz = 1'b1;
          end else {acc_n, quo_n} = {{(XLEN){1'b0}}, au, 1'b0};
        end
      end
      eDIV_CALC: begin
        if (div_counter <= XLEN - 1) begin
          if (acc >= bu) begin
	          acc_n = acc - bu;
	          {acc_n, quo_n} = {acc_n[XLEN-1:0], quo, 1'b1};
      	  end else {acc_n, quo_n} = {acc, quo} << 1;
	        if (div_counter == XLEN - 1) div_state_n = eDIV_DONE;
        end
      end
      eDIV_DBZ: begin
	      if (div_counter == XLEN - 1) div_state_n = eDIV_DONE;
      end
      eDIV_DONE: begin
	      div_state_n = eDIV_IDLE;
      end
      default:;
    endcase
  end

  assign booth_res_acc_n = (is_mul) ? booth_res_acc + (booth_pp_acc << booth_shift) : {acc_n, quo_n};

  assign res_o =  (is_div_div && dbz)                                     ?  '1                     :
	                (sel_i == MUL_OP_DIV && sign_diff)                      ? -booth_res_acc_n[31:0]  :
	  	            (is_div_div)           ?  booth_res_acc_n[31:0]  :
		              (is_div_rem && dbz)  ?  op_a_i                 :
	                (sel_i == MUL_OP_REM && a_sign)                         ? -booth_res_acc_n[64:33] :
	                (is_div_rem)                                            ?  booth_res_acc_n[64:33] :
		              (is_mul_lower)                                          ?  booth_res_acc_n[31:0]  :
		              (is_mul_upper)                                          ? booth_res_acc_n[63:32]  : '0;

  cntr #(
    .WORD_WIDTH($clog2(XLEN)),
    .RESET_VALUE(0)
  ) div_counter_inst (
    .clk   (clk_i),
    .rstn  (rstn_i),
    .clear (div_state == eDIV_IDLE),
    .ce    (div_state == eDIV_CALC || div_state == eDIV_DBZ),
    .count (div_counter)
  );

  register #(
    .DTYPE(logic [XLEN-1:0]),
    .RESET_VALUE(0)
  ) quo_inst (
    .clk  (clk_i),
    .rstn (rstn_i),
    .ce   (1'b1),
    .in   (quo_n),
    .out  (quo)
  );

  register #(
    .DTYPE(logic [XLEN:0]),
    .RESET_VALUE(0)
  ) acc_inst (
    .clk  (clk_i),
    .rstn (rstn_i),
    .ce   (1'b1),
    .in   (acc_n),
    .out  (acc)
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

  register #(
    .DTYPE(booth_fsm_e),
    .RESET_VALUE(eBOOTH_IDLE)
  ) booth_state_inst (
    .clk  (clk_i),
    .rstn (rstn_i),
    .ce   (1'b1),
    .in   (booth_state_next),
    .out  (booth_state)
  );

  register_wclear #(
    .DTYPE(logic [65:0])
  ) booth_res_acc_inst (
    .clk  (clk_i),
    .rstn (rstn_i),
    .clear ((div_counter == XLEN) || (booth_state == eBOOTH_DONE)),
    .ce   (((booth_state != eBOOTH_IDLE)) && booth_state != eBOOTH_DONE),
    .in   (booth_res_acc_n),
    .out  (booth_res_acc)
  );

endmodule
