`ifndef CLK_RST_GEN_TB
`define CLK_RST_GEN_TB

// clk_rst_gen_tb.sv
// author: Tom Riley
// date: 2025-04-30

// This is a testbench for the clk_rst_gen module.
module clk_rst_gen_tb;
    initial begin
        $dumpfile("waves.vcd");
        $dumpvars(0, waves);
    end

    // Parameters
    parameter int CLK_PERIOD_NS = 1000;

    // Inputs
    logic reset_btn;
    logic manual_clk_sw;
    logic pulse_clk_btn;

    // Outputs
    /* verilator lint_off UNUSEDSIGNAL */
    logic clk;
    logic reset_n;
    /* verilator lint_on UNUSEDSIGNAL */

    // Instantiate the Unit Under Test (UUT)
    clk_rst_gen #(
        .CLK_PERIOD_NS(CLK_PERIOD_NS)
    ) uut (
        .reset_btn(reset_btn),
        .manual_clk_sw(manual_clk_sw),
        .pulse_clk_btn(pulse_clk_btn),
        .clk(clk),
        .reset_n(reset_n)
    );

    // Test sequence
    initial begin
        $display("Starting test sequence...");
        reset_btn = 1; // Apply reset
        manual_clk_sw = 0;
        pulse_clk_btn = 0;
        #50us;
        reset_btn = 0; // Release reset
        #100us;
        $display("Ending test sequence...");
        $finish; // End simulation
    end

endmodule: clk_rst_gen_tb

`endif // CLK_RST_GEN_TB

