// Tiny sequential design for STA experiments.
// This is intentionally small but includes a clocked element.

module tiny(
    input  wire clk,
    input  wire a,
    input  wire b,
    output wire y
);
    reg q;
    wire d;

    assign d = (a & b) ^ q;

    always @(posedge clk) begin
        q <= d;
    end

    assign y = q;
endmodule
