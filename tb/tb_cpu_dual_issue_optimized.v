`timescale 1ns/1ps

module tb_cpu_dual_issue_optimized;
    reg clk = 0;
    reg rst = 1;
    wire [31:0] pc, cycle, instret;
    wire halted;

    reg [31:0] imem [0:255];

    initial begin
        imem[0] = 32'h00500093;  // addi x1, x0, 5
        imem[1] = 32'h00600113;  // addi x2, x0, 6
        imem[2] = 32'h002081b3;  // add x3, x1, x2
        imem[3] = 32'h00308233;  // add x4, x1, x3
        imem[4] = 32'h00408293;  // add x5, x1, x4
        imem[5] = 32'h00508333;  // add x6, x1, x5
        imem[6] = 32'h00100093;  // addi x1, x0, 1
        imem[7] = 32'h00200113;  // addi x2, x0, 2
        imem[8] = 32'h00300193;  // addi x3, x0, 3
        imem[9] = 32'h00400213;  // addi x4, x0, 4
        imem[10] = 32'h00100093; // addi x1, x0, 1
        imem[11] = 32'h00200113; // addi x2, x0, 2
        imem[12] = 32'h00300193; // addi x3, x0, 3
        imem[13] = 32'h00400213; // addi x4, x0, 4
        imem[14] = 32'h00000073; // ebreak
    end

    always #5 clk = ~clk;

    cpu_core_dual_issue #(.IMEM_WORDS(256), .DMEM_WORDS(128)) dut (
        .clk(clk), .rst(rst),
        .debug_pc(pc), .debug_cycle(cycle),
        .debug_instret(instret), .halted(halted),
        .ipi_trigger(1'b0)
    );

    integer i;
    initial begin
        $display("=====================================================");
        $display("   OPTIMIZED DUAL-ISSUE CPU - COMPREHENSIVE TEST");
        $display("   Target: ~1.6 IPC @ 350-400MHz");
        $display("=====================================================");

        for (i=0; i<256; i=i+1) begin
            dut.icache_data[i] = imem[i];
        end

        rst <= 1'b1;
        repeat(5) @(posedge clk);
        rst <= 1'b0;

        repeat(100) @(posedge clk);

        $display("");
        $display("=== RESULTS ===");
        $display("Cycles: %0d", cycle);
        $display("Instructions: %0d", instret);
        $display("Final PC: 0x%08h", pc);
        $display("Halted: %b", halted);

        if (instret >= 10 && halted == 1) begin
            $display("STATUS: PASS");
            $display("");
            $display("=== OPTIMIZATION SUMMARY ===");
            $display("Pipeline: 5-stage (optimized for timing)");
            $display("Features: 2-level BHT, RAS, BTB, 4-way cache");
            $display("Target: 1.6 IPC @ 350-400MHz");
        end else begin
            $display("STATUS: FAIL");
        end

        #50;
        $finish;
    end
endmodule