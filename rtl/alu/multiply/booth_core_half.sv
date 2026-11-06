module booth_core_half #(parameter int XLEN = 32) (
  input  logic signed [16:0] op_a_ext,
  input  logic signed [16:0] op_b_ext,
  output logic [XLEN*2-1:0]    pp [8:0]
);

  logic [8:0] signs, ones, twos;
  logic [XLEN*2-1:0] pps [8:0];
  logic [XLEN*2-1:0] op_a_XLEN_sign_ext;
  logic [2:0] bth [8:0];

  logic [2*XLEN-1:0] neg_a;
  logic [2*XLEN-1:0] neg_two_a;
  logic [2*XLEN-1:0] two_a;

  assign neg_a = (~op_a_XLEN_sign_ext) + 1;
  assign neg_two_a = ~(op_a_XLEN_sign_ext << 1) + 1;
  assign two_a = op_a_XLEN_sign_ext << 1;

  assign op_a_XLEN_sign_ext = (op_a_ext[16]) ? {{(2*XLEN - 17){1'b1}}, op_a_ext} : {{(2*XLEN - 17){1'b0}}, op_a_ext};

  genvar i;
  generate
    for (i = 0; i < 9; i++) begin: booth_pp_gen

      assign bth[i] = (i == 0) ? {op_b_ext[1:0], 1'b0} :
                      (i == 8) ? {op_b_ext[16], op_b_ext[16:15]} : op_b_ext[2*i+1:2*i-1];
                      
      encoder booth_encoder(.bth(bth[i]), .sign(signs[i]), .one(ones[i]), .two(twos[i]));

      /*
      Set partial products to booth encoded multiplier * multiplier
      and << 2 for every consecutive PP.
      2*Q  = M << 1
      1*Q  = M
      0*Q  = 0
      -1*Q = NOT(M)
      -2*Q = NOT(M << 1) 
      */

      always_comb begin

        pps[i] = '0;

        pps[i][2*XLEN-1:2*i] = (ones[i] & signs[i]) ? neg_a[2*XLEN-1-2*i:0]              : 
	                             (twos[i] & signs[i]) ? neg_two_a[2*XLEN-1-2*i:0]          :
		                           (ones[i])            ? op_a_XLEN_sign_ext[2*XLEN-1-2*i:0] :
		                           (twos[i])            ? two_a[2*XLEN-1-2*i:0]              : '0;
      end
    end 
  endgenerate

  assign pp = pps;
endmodule
