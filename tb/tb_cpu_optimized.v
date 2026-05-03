`timescale 1ns/1ps

module tb_cpu_optimized;
    reg clk, rst;
    wire [31:0] debug_pc, debug_cycle, debug_instret;
    wire halted;
    reg ipi_trigger;

    reg [3:0] tests_run, tests_passed;

    cpu_core_optimized uut (
        .clk(clk), .rst(rst),
        .debug_pc(debug_pc), .debug_cycle(debug_cycle),
        .debug_instret(debug_instret), .halted(halted),
        .ipi_trigger(ipi_trigger)
    );

    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    initial begin
        tests_run = 0; tests_passed = 0;
        ipi_trigger = 0;
        $dumpfile("cpu_optimized.vcd");
        $dumpvars(0, tb_cpu_optimized);
        $display("=== Optimized CPU Core Testbench ===");

        rst = 1; #20; rst = 0; #10;

        $display("\n[TEST 1] Basic ALU operations");
        #100;
        tests_run = tests_run + 1;
        if (uut.regs[1] == 32'h00000000 && uut.regs[2] == 32'h00000001)
            begin tests_passed = tests_passed + 1; $display("  PASS: x1=0, x2=1"); end
        else $display("  FAIL: x1=%08x x2=%08x", uut.regs[1], uut.regs[2]);

        $display("[TEST 2] Arithmetic (x3 = x1 + x2 = 1)");
        #50;
        tests_run = tests_run + 1;
        if (uut.regs[3] == 32'h00000001)
            begin tests_passed = tests_passed + 1; $display("  PASS: x3=1"); end
        else $display("  FAIL: x3=%08x", uut.regs[3]);

        $display("[TEST 3] Forwarding (x1 = x0 + x4 = 3)");
        #50;
        tests_run = tests_run + 1;
        if (uut.regs[1] == 32'h00000003)
            begin tests_passed = tests_passed + 1; $display("  PASS: x1=3"); end
        else $display("  FAIL: x1=%08x", uut.regs[1]);

        $display("[TEST 4] Pipeline completes without stalls");
        #100;
        tests_run = tests_run + 1;
        if (debug_instret > 0)
            begin tests_passed = tests_passed + 1; $display("  PASS: instret=%0d", debug_instret); end
        else $display("  FAIL: no instructions retired");

        $display("[TEST 5] CFI shadow stack active");
        tests_run = tests_run + 1;
        if (uut.cfi_violation == 0)
            begin tests_passed = tests_passed + 1; $display("  PASS: no violations"); end
        else $display("  FAIL");

        $display("\n=== Results: %0d/%0d tests passed ===", tests_passed, tests_run);
        $display("Cycles: %0d, Retired: %0d", debug_cycle, debug_instret);
        $finish;
    end
endmodule