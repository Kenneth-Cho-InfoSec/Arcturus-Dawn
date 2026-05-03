`timescale 1ns/1ps

module tb_stress_cpu_continuous;
    reg clk = 1'b0;
    reg rst = 1'b1;
    wire [31:0] debug_pc;
    wire [31:0] debug_cycle;
    wire [31:0] debug_instret;
    wire halted;

    cpu_core_7stage #(
        .IMEM_WORDS(1024)
    ) dut (
        .clk(clk),
        .rst(rst),
        .debug_pc(debug_pc),
        .debug_cycle(debug_cycle),
        .debug_instret(debug_instret),
        .halted(halted),
        .ipi_trigger(1'b0)
    );

    always #5 clk = ~clk;

    integer i;
    initial begin
        for (i = 0; i < 1024; i = i + 1) begin
            dut.imem[i] = 32'h00000093;
        end
    end

    initial begin
        $display("=== CPU CONTINUOUS STRESS TEST ===");

        repeat (5) @(posedge clk);
        rst <= 1'b0;

        $display("Running 1000 cycles...");
        repeat (1000) @(posedge clk);

        $display("");
        $display("RESULTS:");
        $display("  Cycles: %0d", debug_cycle);
        $display("  Instructions: %0d", debug_instret);
        $display("  IPC: %0d.%02d", (debug_instret * 100) / debug_cycle, ((debug_instret * 10000) / debug_cycle) % 100);

        if (debug_instret > 900) $display("  STATUS: EXCELLENT (>90% efficiency)");
        else if (debug_instret > 700) $display("  STATUS: VERY GOOD (>70%)");
        else if (debug_instret > 500) $display("  STATUS: GOOD (>50%)");
        else $display("  STATUS: NEEDS IMPROVEMENT");

        #50;
        $finish;
    end
endmodule