// Technology mapping for 74LS series flip-flops

// Map $_SDFFE_PP0P_ (DFF with sync reset and enable) to 7474 D flip-flop
module \$_SDFFE_PP0P_ (input C, input D, input R, input E, output Q);
  wire _TECHMAP_FAIL_ = 0;
  wire d_gated;
  
  // Enable logic: D_out = E ? D : Q (hold current value when not enabled)
  \74157_4x1MUX2  enable_mux (
    .A(Q),     // When E=0, keep current value
    .B(D),     // When E=1, use new D input
    .S(E),     // Enable signal as select
    .Y(d_gated)
  );
  
  // Main flip-flop with reset capability
  \7474_2x1DFF  _TECHMAP_REPLACE_ (
    .CLK(C), 
    .D(d_gated), 
    .CLR(~R),     // Active-low clear (R=1 means reset)
    .PRE(1'b1),   // No preset (tie high)
    .Q(Q),
    .QN()         // Unused inverted output
  );
endmodule
