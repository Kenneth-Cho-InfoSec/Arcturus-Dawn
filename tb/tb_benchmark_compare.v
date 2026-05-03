`timescale 1ns/1ps

module tb_benchmark_compare;
    reg clk = 1'b0;
    reg rst = 1'b1;

    integer before_cycles, before_instret;
    integer after_cycles, after_instret;

    always #5 clk = ~clk;

    initial begin
        $display("================================================================================");
        $display("         ARCTURUS DAWN - COMPREHENSIVE BENCHMARK COMPARISON");
        $display("================================================================================");
        $display("");

        rst <= 1'b1;
        repeat (5) @(posedge clk);
        rst <= 1'b0;

        $display("=== BEFORE: Original 5-Stage, Single-Issue Design ===");

        begin
            wire [31:0] pc1, cycle1, instret1;
            wire halted1;
            cpu_core #(.IMEM_WORDS(512)) dut_before (
                .clk(clk), .rst(rst), .debug_pc(pc1),
                .debug_cycle(cycle1), .debug_instret(instret1),
                .halted(halted1), .ipi_trigger(1'b0)
            );

            repeat (500) @(posedge clk);
            before_cycles = cycle1;
            before_instret = instret1;

            $display("RESULT: Cycles=%d, Instructions=%d", before_cycles, before_instret);
        end

        $display("");
        rst <= 1'b1;
        repeat (5) @(posedge clk);
        rst <= 1'b0;

        $display("=== AFTER: Optimized 7-Stage Design ===");

        begin
            wire [31:0] pc2, cycle2, instret2;
            wire halted2;
            cpu_core_7stage #(.IMEM_WORDS(512)) dut_after (
                .clk(clk), .rst(rst), .debug_pc(pc2),
                .debug_cycle(cycle2), .debug_instret(instret2),
                .halted(halted2), .ipi_trigger(1'b0)
            );

            repeat (500) @(posedge clk);
            after_cycles = cycle2;
            after_instret = instret2;

            $display("RESULT: Cycles=%d, Instructions=%d", after_cycles, after_instret);
        end

        $display("");
        $display("================================================================================");
        $display("                        COMPARISON SUMMARY");
        $display("================================================================================");

        integer pct_improvement;
        pct_improvement = ((after_instret - before_instret) * 100) / (before_instret + 1);

        $display("");
        $display("Metric          BEFORE      AFTER       IMPROVEMENT");
        $display("-----------------------------------------------------");
        $display("Cycles          %4d        %4d", before_cycles, after_cycles);
        $display("Instructions    %4d        %4d        +%3d%%", before_instret, after_instret, pct_improvement);
        $display("IPC             %0d.%02d       %0d.%02d", 
            (before_instret * 100) / before_cycles,
            ((before_instret * 10000) / before_cycles) % 100,
            (after_instret * 100) / after_cycles,
            ((after_instret * 10000) / after_cycles) % 100);
        $display("-----------------------------------------------------");

        #50;
        $finish;
    end
endmodule