`timescale 1ns/1ps

module tb_cpu_optimized_dual;
    reg clk = 0;
    reg rst = 1;
    wire [31:0] pc, cycle, instret;
    wire halted;

    always #5 clk = ~clk;

    cpu_core_dual_issue #(.IMEM_WORDS(256), .DMEM_WORDS(128)) dut (
        .clk(clk), .rst(rst),
        .debug_pc(pc), .debug_cycle(cycle),
        .debug_instret(instret), .halted(halted),
        .ipi_trigger(1'b0)
    );

    initial begin
        $display("=====================================================");
        $display("   OPTIMIZED DUAL-ISSUE CPU TEST");
        $display("   Target: ~1.6 IPC @ 350-400MHz");
        $display("=====================================================");

        rst <= 1'b1;
        repeat(5) @(posedge clk);
        rst <= 1'b0;

        repeat(200) @(posedge clk);

        $display("");
        $display("=== RESULTS ===");
        $display("Cycles: %0d", cycle);
        $display("Instructions: %0d", instret);
        $display("IPC: %0d.%02d", (instret * 100) / cycle, ((instret * 10000) / cycle) % 100);
        $display("Final PC: 0x%08h", pc);
        $display("Halted: %b", halted);

        if (instret > 0 && cycle > 0) begin
            $display("");
            $display("STATUS: PASS");
        end else begin
            $display("STATUS: FAIL");
        end

        #50;
        $finish;
    end
endmodule