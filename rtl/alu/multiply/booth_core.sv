module booth_core #(parameter int XLEN = 32) (
  input  logic signed [XLEN:0] op_a_ext,
  input  logic signed [XLEN:0] op_b_ext,
  output logic [XLEN*2-1:0]    pp [15:0]
);

  logic [15:0] signs, ones, twos;
  logic [XLEN*2-1:0] pps [15:0];

  genvar i;
  generate
    for (i = 0; i < 16; i++) begin
      logic [2:0] bth;
      if (i == 0) begin
        assign bth = {op_b_ext[1:0], 1'b0};
      end else assign bth = op_b_ext[2*i+1:2*i-1];
      encoder booth_encoder(.bth(bth), .sign(signs[i]), .one(ones[i]), .two(twos[i]));

      // Set partial products to booth encoded multiplier * multiplier
      // and << 2 for every consecutive PP.
      // 2*Q  = M << 1
      // 1*Q  = M
      // 0*Q  = 0
      // -1*Q = NOT(M)
      // -2*Q = NOT(M << 1)
      assign pps[i][XLEN*2-1:2*i] = (ones[i] & signs[i]) ? ~op_a_ext :
	                            (twos[i] & signs[i]) ? ~(op_a_ext << 1) :
		                    //(ones[i])            ? {{(XLEN*2-1-2*i){op_a_ext[XLEN]}}, op_a_ext}         :
		                    (ones[i])            ? op_a_ext         :
		                    (twos[i])            ? (op_a_ext << 1)  :
		                                           'b0;
      // Negative correction for -1*Q and -2*Q at
      assign pps[i+1][2*i] = (signs[i] & (ones[i] | twos[i]) & (i < 15)) ? 1'b1 : 1'b0;
    end 
  endgenerate

  assign pp = pps;
endmodule
