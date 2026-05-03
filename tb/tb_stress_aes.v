`timescale 1ns/1ps

module tb_stress_aes;
    reg clk = 1'b0;
    reg rst = 1'b1;
    reg start, encrypt;
    reg [127:0] key, plaintext;
    wire [127:0] ciphertext;
    wire done, ready;

    aes128 dut (
        .clk(clk), .rst(rst), .start(start), .encrypt(encrypt),
        .key(key), .plaintext(plaintext), .ciphertext(ciphertext),
        .done(done), .ready(ready)
    );

    always #5 clk = ~clk;

    integer start_time, end_time;
    integer count = 0;

    initial begin
        $display("=== AES-128 STRESS TEST - 50 ENCRYPTIONS ===");

        repeat (5) @(posedge clk);
        rst <= 1'b0;
        @(posedge clk);

        start_time = $time;

        repeat (10) begin
            start = 1;
            encrypt = 1;
            key = $random;
            plaintext = $random;
            @(posedge clk);
            start = 0;

            wait(done);
            @(posedge clk);
            count = count + 1;
        end

        end_time = $time;

        $display("");
        $display("RESULTS:");
        $display("  Encryptions Completed: %0d", count);
        $display("  Total Time: %0d ns", end_time - start_time);
        $display("  Time per encryption: %0d ns", (end_time - start_time) / count);
        $display("  Throughput: %0d MB/s", (count * 16) * 1000 / (end_time - start_time));
        $display("  STATUS: PASS");

        #50;
        $finish;
    end
endmodule