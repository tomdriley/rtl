`ifndef CLK_RST_GEN
`define CLK_RST_GEN

// clk_rst_gen.sv
// author: Tom Riley
// date: 2025-04-30

// This module generates a clock and reset signal for the system.
// It is not synthesizable since it uses a non-synthesizable clock generation method.
module clk_rst_gen#(
    parameter int CLK_PERIOD_NS = 1000
) (1
    input logic reset_btn,
    input logic manual_clk_sw,
    input logic pulse_clk_btn,
    output logic clk,
    output logic reset_n
);

    logic internal_clk;

    always_comb reset_n = ~reset_btn;
    always_comb clk = manual_clk_sw ? pulse_clk_btn : internal_clk;

    // Non-synthesizable clock generation
    initial internal_clk = 0;
    always # (CLK_PERIOD_NS * 1ns / 2) internal_clk = ~internal_clk;

endmodule: clk_rst_gen

`endif // CLK_RST_GEN

    


