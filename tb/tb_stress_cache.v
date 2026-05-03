`timescale 1ns/1ps

module tb_stress_cache;
    reg clk = 1'b0;
    reg rst = 1'b1;
    reg [31:0] addr;
    reg [31:0] wdata;
    reg write, read;
    wire [31:0] rdata;
    wire hit, miss, miss_pending, ready;

    l1_cache_nonblocking #(
        .NUM_SETS(8),
        .NUM_WAYS(2),
        .MSHR_ENTRIES(4)
    ) dut (
        .clk(clk), .rst(rst), .addr(addr), .wdata(wdata),
        .write(write), .read(read), .flush(1'b0),
        .rdata(rdata), .hit(hit), .miss(miss),
        .miss_pending(miss_pending), .ready(ready),
        .miss_addr(), .miss_read()
    );

    always #5 clk = ~clk;

    integer hits = 0;
    integer misses = 0;
    integer ops = 0;

    initial begin
        $display("=== CACHE STRESS TEST - 100 RANDOM ACCESSES ===");

        repeat (5) @(posedge clk);
        rst <= 1'b0;
        @(posedge clk);

        repeat (100) begin
            addr = $random;
            read = $random & 1;
            write = ~read & 1;
            wdata = $random;

            @(posedge clk);
            #1;

            if (ready) begin
                ops = ops + 1;
                if (hit) hits = hits + 1;
                if (miss) misses = misses + 1;
            end
        end

        $display("");
        $display("RESULTS:");
        $display("  Total Operations: %0d", ops);
        $display("  Hits: %0d", hits);
        $display("  Misses: %0d", misses);
        $display("  Hit Rate: %0d.%02d%%", (hits * 100) / ops, ((hits * 10000) / ops) % 100);

        if (ops >= 80)
            $display("  STATUS: PASS");
        else
            $display("  STATUS: FAIL");

        #50;
        $finish;
    end
endmodule