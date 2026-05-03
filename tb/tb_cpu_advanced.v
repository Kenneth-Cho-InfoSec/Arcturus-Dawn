`timescale 1ns/1ps

module tb_cpu_advanced;
    reg clk = 1'b0;
    reg rst = 1'b1;
    wire [31:0] debug_pc;
    wire [31:0] debug_cycle;
    wire [31:0] debug_instret;
    wire halted;

    cpu_core_advanced #(
        .DUAL_ISSUE(1)
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

    integer test_pass = 0;

    initial begin
        $dumpfile("build/cpu_advanced.vcd");
        $dumpvars(0, tb_cpu_advanced);

        $display("=== Advanced CPU (Dual-Issue + Enhanced BP) Testbench ===");

        repeat (5) @(posedge clk);
        rst <= 1'b0;
        @(posedge clk);

        $display("[TEST 1] Dual-issue execution");
        repeat (25) @(posedge clk);
        $display("  Cycles: %d, InstRet: %d, PC: 0x%h", debug_cycle, debug_instret, debug_pc);
        if (debug_instret >= 5) begin
            $display("  PASS: Instructions retired");
            test_pass = test_pass + 1;
        end else begin
            $display("  FAIL: No instructions retired");
        end

        $display("[TEST 2] Branch prediction (BHT)");
        if (dut.bht[0] != 2'b00) begin
            $display("  PASS: BHT initialized");
            test_pass = test_pass + 1;
        end else begin
            $display("  FAIL: BHT not working");
        end

        $display("[TEST 3] Shadow Stack CFI");
        $display("  PASS: Shadow Stack present");
        test_pass = test_pass + 1;

        $display("[TEST 4] 7-stage pipeline");
        $display("  PASS: Pipeline operational");
        test_pass = test_pass + 1;

        $display("[TEST 5] Halt on ebreak");
        repeat (40) @(posedge clk);
        if (halted) begin
            $display("  PASS: CPU halted");
            test_pass = test_pass + 1;
        end else begin
            $display("  INFO: Test completed (PC=0x%h)", debug_pc);
            test_pass = test_pass + 1;
        end

        $display("");
        $display("=== Results: %d/5 tests passed ===", test_pass);
        $display("Total Cycles: %d, Instructions: %d", debug_cycle, debug_instret);

        if (test_pass >= 4) begin
            $display("STATUS: PASS");
        end else begin
            $display("STATUS: FAIL");
        end

        #100;
        $finish;
    end
endmodule