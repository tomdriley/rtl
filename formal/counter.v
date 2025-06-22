// Simple counter module for formal verification example
module counter(
    input wire clk,
    input wire rst_n,
    output reg [7:0] count
);

    // Simple 8-bit counter
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            count <= 8'b0;
        end else begin
            count <= count + 1;
        end
    end

    // Formal verification properties
    `ifdef FORMAL
        // Default clock and reset for formal verification
        reg f_past_valid = 0;
        always @(posedge clk)
            f_past_valid <= 1;

        // Reset behavior: counter should be 0 when reset is asserted
        always @(posedge clk) begin
            if (!rst_n) begin
                assert(count == 8'b0);
            end
        end

        // After reset is released, counter should increment by 1 each cycle
        always @(posedge clk) begin
            if (f_past_valid && $past(rst_n) && rst_n) begin
                if ($past(count) == 8'hFF) begin
                    // Overflow case: counter wraps to 0
                    assert(count == 8'h00);
                end else begin
                    // Normal case: counter increments by 1
                    assert(count == $past(count) + 1);
                end
            end
        end

        // Assume reset is properly controlled - stays high for at least 2 cycles initially
        initial assume(!rst_n);
        
        // Cover properties to ensure we reach interesting states
        always @(posedge clk) begin
            if (f_past_valid && rst_n) begin
                if (count == 8'h10) begin
                    cover(1); // Reach count 16
                end
                if (count == 8'hFF) begin
                    cover(1); // Reach maximum count  
                end
                if ($past(count) == 8'hFF && count == 8'h00) begin
                    cover(1); // Cover overflow
                end
            end
        end
    `endif

endmodule
