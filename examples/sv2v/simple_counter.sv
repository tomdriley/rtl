// Simple SystemVerilog counter module for sv2v testing
// This uses only basic SystemVerilog features that sv2v supports

module simple_counter #(
    parameter int WIDTH = 8
)(
    input  logic                clk,
    input  logic                reset_n,
    input  logic                enable,
    output logic [WIDTH-1:0]    count,
    output logic                overflow
);

    logic [WIDTH-1:0] count_next;
    
    // Sequential logic
    always_ff @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            count <= '0;
        end else if (enable) begin
            count <= count_next;
        end
    end
    
    // Combinational logic using always @(*) instead of always_comb
    always @(*) begin
        count_next = count + 1'b1;
        overflow = (count == {WIDTH{1'b1}}) && enable;
    end

endmodule
