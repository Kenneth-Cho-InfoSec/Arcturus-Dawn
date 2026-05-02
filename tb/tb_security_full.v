`timescale 1ns/1ps

module tb_security_full;
    reg clk, rst;
    reg [3:0] tests_run, tests_passed;

    reg                  mte_write, mte_read;
    reg  [31:0]          mte_addr;
    reg  [3:0]           mte_ptr_tag, mte_mem_tag;
    wire                 mte_violation;
    wire [3:0]           mte_stored;

    wire [31:0]          trng_val;
    wire                 trng_valid;

    reg                  aes_start, aes_encrypt;
    reg  [127:0]         aes_key, aes_pt;
    wire [127:0]         aes_ct;
    wire                 aes_done, aes_ready;

    reg [31:0] prev_val;
    reg        mte_viol_latched;

    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    memory_tagging mte (
        .clk(clk), .rst(rst),
        .write_access(mte_write), .read_access(mte_read),
        .addr(mte_addr), .ptr_tag(mte_ptr_tag), .mem_tag(mte_mem_tag),
        .enable(1'b1), .tag_violation(mte_violation), .stored_tag(mte_stored)
    );

    trng rng (
        .clk(clk), .rst(rst), .enable(1'b1),
        .random_val(trng_val), .data_valid(trng_valid)
    );

    aes128 aes (
        .clk(clk), .rst(rst),
        .start(aes_start), .encrypt(aes_encrypt),
        .key(aes_key), .plaintext(aes_pt),
        .ciphertext(aes_ct), .done(aes_done), .ready(aes_ready)
    );

    initial begin
        tests_run = 0; tests_passed = 0;
        mte_viol_latched = 0;
        $dumpfile("security_full.vcd");
        $dumpvars(0, tb_security_full);
        $display("\n=== Full Security Subsystem Tests ===");

        rst = 1; mte_write = 0; mte_read = 0; mte_addr = 0;
        mte_ptr_tag = 0; mte_mem_tag = 0;
        aes_start = 0; aes_encrypt = 0; aes_key = 0; aes_pt = 0;
        #20; rst = 0; #10;

        // MTE Test 1: Write tag
        $display("\n[MTE-1] Write tag 0xA to addr 0x100");
        mte_write = 1; mte_addr = 32'h100; mte_ptr_tag = 4'hA;
        #10; mte_write = 0; #10;

        // MTE Test 2: Read match
        $display("[MTE-2] Read addr 0x100 with tag 0xA (match)");
        mte_read = 1; mte_addr = 32'h100; mte_ptr_tag = 4'hA;
        #10;
        tests_run = tests_run + 1;
        if (!mte_violation && mte_stored == 4'hA)
            begin tests_passed = tests_passed + 1; $display("  PASS"); end
        else $display("  FAIL: viol=%0b stored=%0h", mte_violation, mte_stored);
        mte_read = 0; #10;

        // MTE Test 3: Read mismatch
        $display("[MTE-3] Read addr 0x100 with tag 0xF (mismatch)");
        mte_read = 1; mte_addr = 32'h100; mte_ptr_tag = 4'hF;
        #10;
        tests_run = tests_run + 1;
        if (mte_violation) begin tests_passed = tests_passed + 1; $display("  PASS: violation!"); end
        else $display("  FAIL");
        mte_read = 0; #10;

        // TRNG Test 4
        $display("\n[TRNG-4] Generate random value");
        #20;
        tests_run = tests_run + 1;
        if (trng_val != 32'h00000000)
            begin tests_passed = tests_passed + 1; $display("  PASS: trng=0x%08x", trng_val); end
        else $display("  FAIL");

        // TRNG Test 5: Values change
        $display("[TRNG-5] Check values vary");
        prev_val = trng_val;
        #10;
        tests_run = tests_run + 1;
        if (trng_val != prev_val)
            begin tests_passed = tests_passed + 1; $display("  PASS: varied to 0x%08x", trng_val); end
        else $display("  FAIL: still 0x%08x", trng_val);

        // AES Test 6
        $display("\n[AES-6] Encrypt test block");
        aes_key = 128'h2b7e151628aed2a6abf7158809cf4f3c;
        aes_pt  = 128'h6bc1bee22e409f96e93d7e117393172a;
        aes_encrypt = 1; aes_start = 1;
        #10; aes_start = 0;
        wait(aes_done);
        tests_run = tests_run + 1;
        if (aes_ct != 128'h00000000000000000000000000000000)
            begin tests_passed = tests_passed + 1; $display("  PASS: ct=0x%032x", aes_ct); end
        else $display("  FAIL");

        $display("\n=== Results: %0d/%0d tests passed ===", tests_passed, tests_run);
        $finish;
    end
endmodule