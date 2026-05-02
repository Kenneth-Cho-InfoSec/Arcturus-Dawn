`timescale 1ns/1ps

module tb_shadow_stack;
    reg clk, rst, push, pop, enable;
    reg [31:0] ret_addr;
    wire [31:0] expected_ret;
    wire cfi_violation;
    wire [4:0] depth;

    shadow_stack uut (
        .clk(clk), .rst(rst), .push(push), .pop(pop),
        .ret_addr(ret_addr), .enable(enable),
        .expected_ret(expected_ret), .cfi_violation(cfi_violation), .depth(depth)
    );

    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    reg [3:0] tests_run;
    reg [3:0] tests_passed;

    initial begin
        tests_run = 0; tests_passed = 0;
        $dumpfile("shadow_stack.vcd");
        $dumpvars(0, tb_shadow_stack);

        $display("=== Shadow Stack CFI Testbench ===");

        rst = 1; push = 0; pop = 0; ret_addr = 0; enable = 1;
        #20;
        rst = 0;
        #10;

        // Test 1: Push return address
        $display("[TEST 1] Push ret_addr=0x100");
        push = 1; ret_addr = 32'h00000100;
        #10; push = 0;
        #10;
        tests_run = tests_run + 1;
        if (depth == 1) begin tests_passed = tests_passed + 1; $display("  PASS: depth=1"); end
        else $display("  FAIL: depth=%0d expected=1", depth);

        // Test 2: Push second address
        $display("[TEST 2] Push ret_addr=0x200");
        push = 1; ret_addr = 32'h00000200;
        #10; push = 0;
        #10;
        tests_run = tests_run + 1;
        if (depth == 2) begin tests_passed = tests_passed + 1; $display("  PASS: depth=2"); end
        else $display("  FAIL: depth=%0d expected=2", depth);

        // Test 3: Pop - should return 0x200 (match)
        $display("[TEST 3] Pop - expect 0x200");
        pop = 1; ret_addr = 32'h00000200;
        #10; pop = 0;
        #10;
        tests_run = tests_run + 1;
        if (depth == 1 && !cfi_violation && expected_ret == 32'h00000200)
            begin tests_passed = tests_passed + 1; $display("  PASS: depth=1, no violation, expected=0x200"); end
        else $display("  FAIL: depth=%0d, violation=%0b, expected=0x%08x", depth, cfi_violation, expected_ret);

        // Test 4: CFI violation - wrong return address
        $display("[TEST 4] CFI violation - wrong ret_addr");
        pop = 1; ret_addr = 32'h00000BAD;
        #10;
        tests_run = tests_run + 1;
        if (cfi_violation) begin tests_passed = tests_passed + 1; $display("  PASS: cfi_violation=1 detected!"); end
        else $display("  FAIL: cfi_violation not detected");
        pop = 0;
        #10;

        // Test 5: Underflow protection
        $display("[TEST 5] Underflow protection - pop when empty");
        pop = 1; ret_addr = 32'h00000000;
        #10; pop = 0;
        #10;
        tests_run = tests_run + 1;
        if (depth == 0) begin tests_passed = tests_passed + 1; $display("  PASS: depth=0 (underflow prevented)"); end
        else $display("  FAIL: depth=%0d expected=0", depth);

        // Test 6: Overflow protection (depth=16 max)
        $display("[TEST 6] Overflow protection");
        for (integer k = 0; k < 18; k = k + 1) begin
            push = 1; ret_addr = 32'h00001000 + k;
            #10; push = 0; #10;
        end
        tests_run = tests_run + 1;
        if (depth == 16) begin tests_passed = tests_passed + 1; $display("  PASS: depth=16 (overflow prevented)"); end
        else $display("  FAIL: depth=%0d expected=16", depth);

        $display("\n=== Results: %0d/%0d tests passed ===", tests_passed, tests_run);
        $finish;
    end
endmodule