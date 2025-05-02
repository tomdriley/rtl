`ifndef ALU_TB
`define ALU_TB

// alu_tb.sv
// author: Tom Riley
// date: 2025-05-01

// Testbench for the ALU module
module alu_tb;
    // Parameters
    localparam DATA_WIDTH = 8;

    // Signals
    logic [DATA_WIDTH-1:0] op_a;
    logic [DATA_WIDTH-1:0] op_b;
    alu_func_e func;
    logic [DATA_WIDTH-1:0] out;
    logic signed_overflow;
    logic carry_flag;

    // Instantiate the ALU
    alu #(
        .DATA_WIDTH(DATA_WIDTH)
    ) u_alu (
        .op_a(op_a),
        .op_b(op_b),
        .func(func),
        .out(out),
        .signed_overflow(signed_overflow),
        .carry_flag(carry_flag)
    );

    // Task to generate random test cases
    task automatic generate_random_test();
        logic [DATA_WIDTH-1:0] rand_op_a;
        logic [DATA_WIDTH-1:0] rand_op_b;
        alu_func_e rand_func;

        begin
            // Generate random operands and function
            rand_op_a = $urandom_range(0, 2**DATA_WIDTH - 1)[DATA_WIDTH-1:0];
            rand_op_b = $urandom_range(0, 2**DATA_WIDTH - 1)[DATA_WIDTH-1:0];
            rand_func = alu_func_e'($urandom_range(0, 32'b111)[2:0]);

            // Apply random values to the ALU
            op_a = rand_op_a;
            op_b = rand_op_b;
            func = rand_func;

            // Wait for a clock cycle
            #10;
        end
    endtask

    // Test sequence
    initial begin
        $dumpfile("waves.vcd");
        $dumpvars(0, waves);
        $monitor("Time: %0t | op_a: 0x%2h | op_b: 0x%2h | func: %s | out: 0x%2h | signed_overflow: 0b%b | carry_flag: 0b%b",
             $time, op_a, op_b, func.name(), out, signed_overflow, carry_flag);

        repeat(10000) generate_random_test();

        // End simulation
        $display("All tests passed!");
        $finish;
    end

endmodule

`endif // ALU_TB
