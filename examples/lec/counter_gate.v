// Simple counter design - "gate" version for testing
// This version is functionally equivalent to the gold version
module counter (
    input  wire clk,
    input  wire rst,
    input  wire enable,
    output reg [7:0] count
);

    // Equivalent implementation using different style
    always @(posedge clk) begin
        if (rst) 
            count <= 0;
        else 
            count <= enable ? count + 1'b1 : count;
    end

endmodule
