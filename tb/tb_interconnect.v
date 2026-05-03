`timescale 1ns/1ps

module tb_interconnect;
    reg clk = 1'b0;
    reg rst = 1'b1;
    integer cycle = 0;

    reg  [3:0]  m0_addr;
    reg  [31:0] m0_wdata;
    reg         m0_valid;
    reg  [3:0] m0_be;
    reg         m0_write;
    wire [31:0] m0_rdata;
    wire        m0_ready;
    
    reg  [3:0]  m1_addr;
    reg  [31:0] m1_wdata;
    reg         m1_valid;
    reg  [3:0] m1_be;
    reg         m1_write;
    wire [31:0] m1_rdata;
    wire        m1_ready;
    
    reg  [3:0]  m2_addr;
    reg  [31:0] m2_wdata;
    reg         m2_valid;
    reg  [3:0] m2_be;
    reg         m2_write;
    wire [31:0] m2_rdata;
    wire        m2_ready;
    
    reg  [3:0]  m3_addr;
    reg  [31:0] m3_wdata;
    reg         m3_valid;
    reg  [3:0] m3_be;
    reg         m3_write;
    wire [31:0] m3_rdata;
    wire        m3_ready;

    wire [31:0] s0_rdata;
    wire        s0_ready;
    wire [3:0] s0_be;
    wire        s0_write;
    wire [31:0] s0_wdata;
    wire [3:0] s0_addr;
    
    wire [31:0] s1_rdata;
    wire        s1_ready;
    wire [3:0] s1_be;
    wire        s1_write;
    wire [31:0] s1_wdata;
    wire [3:0] s1_addr;
    
    wire [31:0] s2_rdata;
    wire        s2_ready;
    wire [3:0] s2_be;
    wire        s2_write;
    wire [31:0] s2_wdata;
    wire [3:0] s2_addr;
    
    wire [31:0] s3_rdata;
    wire        s3_ready;
    wire [3:0] s3_be;
    wire        s3_write;
    wire [31:0] s3_wdata;
    wire [3:0] s3_addr;

    always #5 clk = ~clk;

    soc_interconnect dut (
        .clk(clk),
        .rst(rst),
        .m0_addr(m0_addr),
        .m0_wdata(m0_wdata),
        .m0_valid(m0_valid),
        .m0_be(m0_be),
        .m0_write(m0_write),
        .m0_rdata(m0_rdata),
        .m0_ready(m0_ready),
        .m1_addr(m1_addr),
        .m1_wdata(m1_wdata),
        .m1_valid(m1_valid),
        .m1_be(m1_be),
        .m1_write(m1_write),
        .m1_rdata(m1_rdata),
        .m1_ready(m1_ready),
        .m2_addr(m2_addr),
        .m2_wdata(m2_wdata),
        .m2_valid(m2_valid),
        .m2_be(m2_be),
        .m2_write(m2_write),
        .m2_rdata(m2_rdata),
        .m2_ready(m2_ready),
        .m3_addr(m3_addr),
        .m3_wdata(m3_wdata),
        .m3_valid(m3_valid),
        .m3_be(m3_be),
        .m3_write(m3_write),
        .m3_rdata(m3_rdata),
        .m3_ready(m3_ready),
        .s0_rdata(s0_rdata),
        .s0_ready(s0_ready),
        .s0_be(s0_be),
        .s0_write(s0_write),
        .s0_wdata(s0_wdata),
        .s0_addr(s0_addr),
        .s1_rdata(s1_rdata),
        .s1_ready(s1_ready),
        .s1_be(s1_be),
        .s1_write(s1_write),
        .s1_wdata(s1_wdata),
        .s1_addr(s1_addr),
        .s2_rdata(s2_rdata),
        .s2_ready(s2_ready),
        .s2_be(s2_be),
        .s2_write(s2_write),
        .s2_wdata(s2_wdata),
        .s2_addr(s2_addr),
        .s3_rdata(s3_rdata),
        .s3_ready(s3_ready),
        .s3_be(s3_be),
        .s3_write(s3_write),
        .s3_wdata(s3_wdata),
        .s3_addr(s3_addr)
    );

    initial begin
        $dumpfile("build/interconnect.vcd");
        $dumpvars(0, tb_interconnect);
        repeat (3) @(posedge clk);
        rst <= 1'b0;
    end

    always @(posedge clk) begin
        if (!rst) begin
            cycle <= cycle + 1;

            if (cycle == 2) begin
                m0_addr <= 0;
                m0_wdata <= 32'h11111111;
                m0_valid <= 1;
                m0_be <= 4'hF;
                m0_write <= 1;
            end else begin
                m0_valid <= 0;
                m0_write <= 0;
            end
            
            if (cycle == 5) begin
                m1_addr <= 1;
                m1_wdata <= 32'h22222222;
                m1_valid <= 1;
                m1_be <= 4'hF;
                m1_write <= 1;
            end else begin
                m1_valid <= 0;
                m1_write <= 0;
            end
            
            if (cycle == 10 && m0_ready && m1_ready) begin
                $display("PASS: SoC interconnect arbitration");
                $finish;
            end
        end
    end

    initial begin
        #200;
        $display("FAIL: timeout");
        $finish;
    end
endmodule