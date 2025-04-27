module waves;
    initial $display("Starting wave test");

    reg clk;
    reg reset_n;
    reg [7:0] count;

    always #5 clk = ~clk;

    initial begin
        reset_n = 0;
        #20 reset_n = 1;
        #200
        $display("Simulation finished");
        $finish;
    end

    initial begin
        $dumpfile("waves.vcd");
        $dumpvars(0, waves);
    end

    always @(posedge clk) begin
        if (!reset_n) begin
            count <= 0;
        end else begin
            count <= count + 1;
        end
    end

    initial begin
        /* verilator lint_off SYNCASYNCNET */
        $monitor("At time %t, count = %d", $time, count);
        /* verilator lint_on SYNCASYNCNET */
    end
endmodule: waves
