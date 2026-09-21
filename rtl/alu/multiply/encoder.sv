module encoder (
    input  logic [2:0] bth,
    output logic       sign,
    output logic       one,
    output logic       two
);
  // if recoded value is negative
  assign sign = bth[2];
  // if recoded value is 1 or -1
  assign one  = bth[1] ^ bth[0];
  // if recoded value is 2 or -2
  assign two  = (bth[2] & ~bth[1] & ~bth[0]) | (~bth[2] & bth[1] & bth[0]);

endmodule
