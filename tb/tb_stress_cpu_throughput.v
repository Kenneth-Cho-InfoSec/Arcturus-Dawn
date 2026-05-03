`timescale 1ns/1ps

module tb_stress_cpu_throughput;
    reg clk = 1'b0;
    reg rst = 1'b1;
    wire [31:0] debug_pc;
    wire [31:0] debug_cycle;
    wire [31:0] debug_instret;
    wire halted;

    cpu_core_7stage dut (
        .clk(clk),
        .rst(rst),
        .debug_pc(debug_pc),
        .debug_cycle(debug_cycle),
        .debug_instret(debug_instret),
        .halted(halted),
        .ipi_trigger(1'b0)
    );

    always #5 clk = ~clk;

    initial begin
        $display("=== CPU THROUGHPUT STRESS TEST ===");

        repeat (5) @(posedge clk);
        rst <= 1'b0;

        $display("Running 500 cycles...");
        repeat (500) @(posedge clk);

        $display("");
        $display("RESULTS:");
        $display("  Total Cycles: %0d", debug_cycle);
        $display("  Instructions Retired: %0d", debug_instret);
        $display("  IPC: %0d.%02d", (debug_instret * 100) / debug_cycle, ((debug_instret * 10000) / debug_cycle) % 100);
        $display("  Final PC: 0x%h", debug_pc);

        if (debug_instret > 100)
            $display("  STATUS: PASS (Excellent throughput)");
        else if (debug_instret > 50)
            $display("  STATUS: PASS (Good throughput)");
        else
            $display("  STATUS: FAIL (Low throughput)");

        #50;
        $finish;
    end
endmodule