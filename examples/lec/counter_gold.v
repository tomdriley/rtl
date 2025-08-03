// Simple counter design - "gold" reference version
module counter (
    input  wire clk,
    input  wire rst,
    input  wire enable,
    output reg [7:0] count
);

    always @(posedge clk) begin
        if (rst) begin
            count <= 8'b0;
        end else if (enable) begin
            count <= count + 1;
        end
    end

endmodule
