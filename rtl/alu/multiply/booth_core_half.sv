module booth_core_half #(parameter int XLEN = 32) (
  input  logic signed [17:0] op_a_ext,
  input  logic signed [17:0] op_b_ext,
  output logic [XLEN*2-1:0]    pp [8:0]
);

  logic [8:0] signs, ones, twos;
  logic [XLEN*2-1:0] pps [8:0];
  logic [XLEN*2-1:0] op_a_XLEN_sign_ext;
  logic [XLEN*2-1:0] op_b_XLEN_sign_ext;
  logic [2:0] bth [9:0];

  assign op_a_XLEN_sign_ext = (op_a_ext[17]) ? {{(2*XLEN - 18){1'b1}}, op_a_ext} : {{(2*XLEN - 18){1'b0}}, op_a_ext};
  assign op_b_XLEN_sign_ext = (op_b_ext[17]) ? {{(2*XLEN - 18){1'b1}}, op_b_ext} : {{(2*XLEN - 18){1'b0}}, op_b_ext};

  genvar i;
  generate
    for (i = 0; i < 9; i++) begin

      assign bth[i] = (i == 0) ? {op_b_ext[1:0], 1'b0} : op_b_ext[2*i+1:2*i-1];
      encoder booth_encoder(.bth(bth[i]), .sign(signs[i]), .one(ones[i]), .two(twos[i]));

      // Set partial products to booth encoded multiplier * multiplier
      // and << 2 for every consecutive PP.
      // 2*Q  = M << 1
      // 1*Q  = M
      // 0*Q  = 0
      // -1*Q = NOT(M)
      // -2*Q = NOT(M << 1)

      always_comb begin

        pps[i] = '0;

        pps[i][2*XLEN-1:2*i] = (ones[i] & signs[i]) ? ((~op_a_XLEN_sign_ext) + 1)        :
	                       (twos[i] & signs[i]) ? (~(op_a_XLEN_sign_ext << 1) + 1) :
		               (ones[i])            ? (op_a_XLEN_sign_ext)             :
		               (twos[i])            ? ((op_a_XLEN_sign_ext << 1))      :
		                                      'b0;
      end

      // Negative correction for -1*Q and -2*Q at
//      assign pps[i+1][2*i] = (signs[i] & (ones[i] | twos[i]) & (i < 7)) ? 1'b1 : 1'b0;
    end 
  endgenerate



  assign pp = pps;
endmodule
