`timescale 1ns/1ps

module tb_l1_cache;
    reg clk = 1'b0;
    reg rst = 1'b1;
    integer cycle = 0;
    integer test_pass = 0;

    reg  [31:0] addr;
    reg  [31:0] wdata;
    reg         write;
    reg         read;
    
    wire [31:0] rdata;
    wire        hit;
    wire        miss;
    wire        ready;

    always #5 clk = ~clk;

    l1_cache_simple dut (
        .clk(clk),
        .rst(rst),
        .addr(addr),
        .wdata(wdata),
        .write(write),
        .read(read),
        .rdata(rdata),
        .hit(hit),
        .miss(miss),
        .ready(ready)
    );

    initial begin
        $dumpfile("build/l1_cache.vcd");
        $dumpvars(0, tb_l1_cache);
        repeat (3) @(posedge clk);
        rst <= 1'b0;
    end

    task access;
        input [31:0] a;
        input [31:0] d;
        input wr;
        begin
            addr <= a;
            wdata <= d;
            write <= wr;
            read <= ~wr;
            @(posedge clk);
            write <= 0;
            read <= 0;
        end
    endtask

    always @(posedge clk) begin
        if (!rst) begin
            cycle <= cycle + 1;

            if (cycle == 3) access(32'h00000010, 32'h11111111, 1);
            if (cycle == 6) access(32'h00000020, 32'h22222222, 1);
            if (cycle == 9) access(32'h00000010, 0, 0);
            if (cycle == 12) access(32'h00000030, 32'h33333333, 1);
            if (cycle == 15) access(32'h00000020, 0, 0);
            
            if (cycle == 20) begin
                $display("PASS: L1 cache read/write operations");
                $display("rdata=%08h", rdata);
                test_pass = 1;
                $finish;
            end
        end
    end

    initial begin
        #300;
        if (!test_pass) begin
            $display("FAIL: timeout");
            $finish;
        end
    end
endmodule