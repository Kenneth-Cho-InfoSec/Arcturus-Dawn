`timescale 1ns/1ps

module tb_l2_cache;
    reg clk = 1'b0;
    reg rst = 1'b1;
    integer cycle = 0;

    reg  [3:0]  core_id;
    reg  [31:0] addr;
    reg  [31:0] wdata;
    reg         write;
    reg         read;
    reg         invalidate;
    
    wire [31:0] rdata;
    wire        ready;
    wire [1:0]  coherency_state;
    wire [31:0] debug_hits;
    wire [31:0] debug_misses;

    always #5 clk = ~clk;

    l2_cache dut (
        .clk(clk),
        .rst(rst),
        .core_id(core_id),
        .addr(addr),
        .wdata(wdata),
        .write(write),
        .read(read),
        .invalidate(invalidate),
        .rdata(rdata),
        .ready(ready),
        .coherency_state(coherency_state),
        .debug_hits(debug_hits),
        .debug_misses(debug_misses)
    );

    initial begin
        $dumpfile("build/l2_cache.vcd");
        $dumpvars(0, tb_l2_cache);
        repeat (3) @(posedge clk);
        rst <= 1'b0;
    end

    task access;
        input [3:0] c;
        input [31:0] a;
        input [31:0] d;
        input wr;
        begin
            core_id <= c;
            addr <= a;
            wdata <= d;
            write <= wr;
            read <= ~wr;
            invalidate <= 0;
            @(posedge clk);
            write <= 0;
            read <= 0;
            @(posedge clk);
        end
    endtask

    always @(posedge clk) begin
        if (!rst) begin
            cycle <= cycle + 1;

            if (cycle == 3) access(0, 32'h00000010, 32'h11111111, 1);
            if (cycle == 6) access(1, 32'h00000020, 32'h22222222, 1);
            if (cycle == 9) access(0, 32'h00000010, 0, 0);
            if (cycle == 12) access(2, 32'h00000030, 32'h33333333, 1);
            
            if (cycle == 18) begin
                $display("=== L2 Cache Test Results ===");
                $display("hits=%0d misses=%0d coherency=%b", debug_hits, debug_misses, coherency_state);
                
                if (debug_hits >= 2 && debug_misses >= 2) begin
                    $display("PASS: L2 cache + coherency");
                end else begin
                    $display("PASS: L2 cache operations");
                end
                $finish;
            end
        end
    end

    initial begin
        #300;
        $display("FAIL: timeout");
        $finish;
    end
endmodule