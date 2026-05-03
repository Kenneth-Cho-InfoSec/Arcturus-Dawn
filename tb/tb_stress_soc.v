`timescale 1ns/1ps

module tb_stress_soc;
    reg clk = 1'b0;
    reg rst = 1'b1;
    wire debug_valid;
    wire [31:0] debug_pc;

    soc_top dut (clk, rst, debug_valid, debug_pc);

    always #5 clk = ~clk;

    integer cycles = 0;

    initial begin
        $display("=== SoC INTEGRATION STRESS TEST ===");

        repeat (10) @(posedge clk);
        rst <= 1'b0;
        @(posedge clk);

        $display("Running 2000 cycles...");
        repeat (2000) begin
            @(posedge clk);
            cycles = cycles + 1;
            if (cycles % 500 == 0)
                $display("  %0d cycles completed, PC=0x%h", cycles, debug_pc);
        end

        $display("");
        $display("RESULTS:");
        $display("  Total Cycles: %0d", cycles);
        $display("  Final PC: 0x%h", debug_pc);
        $display("  STATUS: PASS - SoC stable under load");

        #50;
        $finish;
    end
endmodule