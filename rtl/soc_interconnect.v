`timescale 1ns/1ps

module soc_interconnect (
    input  wire        clk,
    input  wire        rst,
    
    input  wire [3:0]   m0_addr,
    input  wire [31:0]  m0_wdata,
    input  wire        m0_valid,
    input  wire [3:0]  m0_be,
    input  wire        m0_write,
    output reg  [31:0]  m0_rdata,
    output reg         m0_ready,
    
    input  wire [3:0]   m1_addr,
    input  wire [31:0]  m1_wdata,
    input  wire        m1_valid,
    input  wire [3:0]  m1_be,
    input  wire        m1_write,
    output reg  [31:0]  m1_rdata,
    output reg         m1_ready,
    
    input  wire [3:0]   m2_addr,
    input  wire [31:0]  m2_wdata,
    input  wire        m2_valid,
    input  wire [3:0]  m2_be,
    input  wire        m2_write,
    output reg  [31:0]  m2_rdata,
    output reg         m2_ready,
    
    input  wire [3:0]   m3_addr,
    input  wire [31:0]  m3_wdata,
    input  wire        m3_valid,
    input  wire [3:0]  m3_be,
    input  wire        m3_write,
    output reg  [31:0]  m3_rdata,
    output reg         m3_ready,
    
    output reg  [31:0]  s0_rdata,
    output reg         s0_ready,
    output reg  [3:0]   s0_be,
    output reg         s0_write,
    output reg  [31:0]  s0_wdata,
    output reg  [3:0]   s0_addr,
    
    output reg  [31:0]  s1_rdata,
    output reg         s1_ready,
    output reg  [3:0]   s1_be,
    output reg         s1_write,
    output reg  [31:0]  s1_wdata,
    output reg  [3:0]   s1_addr,
    
    output reg  [31:0]  s2_rdata,
    output reg         s2_ready,
    output reg  [3:0]   s2_be,
    output reg         s2_write,
    output reg  [31:0]  s2_wdata,
    output reg  [3:0]   s2_addr,
    
    output reg  [31:0]  s3_rdata,
    output reg         s3_ready,
    output reg  [3:0]   s3_be,
    output reg         s3_write,
    output reg  [31:0]  s3_wdata,
    output reg  [3:0]   s3_addr
);

    localparam NUM_MASTERS = 4;
    localparam NUM_SLAVES = 4;
    
    reg [NUM_MASTERS-1:0] grant;
    reg [1:0] owner;
    reg [7:0] arb_cnt;

    wire [3:0] m0_sel = (m0_addr < 4'd1) ? 4'd0 :
                         (m0_addr < 4'd2) ? 4'd1 :
                         (m0_addr < 4'd3) ? 4'd2 : 4'd3;
    wire [3:0] m1_sel = (m1_addr < 4'd1) ? 4'd0 :
                         (m1_addr < 4'd2) ? 4'd1 :
                         (m1_addr < 4'd3) ? 4'd2 : 4'd3;
    wire [3:0] m2_sel = (m2_addr < 4'd1) ? 4'd0 :
                         (m2_addr < 4'd2) ? 4'd1 :
                         (m2_addr < 4'd3) ? 4'd2 : 4'd3;
    wire [3:0] m3_sel = (m3_addr < 4'd1) ? 4'd0 :
                         (m3_addr < 4'd2) ? 4'd1 :
                         (m3_addr < 4'd3) ? 4'd2 : 4'd3;

    always @(posedge clk) begin
        if (rst) begin
            grant <= 4'b0001;
            owner <= 2'd0;
            arb_cnt <= 0;
            m0_ready <= 1'b1;
            m1_ready <= 1'b1;
            m2_ready <= 1'b1;
            m3_ready <= 1'b1;
            m0_rdata <= 0;
            m1_rdata <= 0;
            m2_rdata <= 0;
            m3_rdata <= 0;
            s0_rdata <= 0;
            s1_rdata <= 0;
            s2_rdata <= 0;
            s3_rdata <= 0;
            s0_ready <= 1'b0;
            s1_ready <= 1'b0;
            s2_ready <= 1'b0;
            s3_ready <= 1'b0;
        end else begin
            m0_ready <= 1'b1;
            m1_ready <= 1'b1;
            m2_ready <= 1'b1;
            m3_ready <= 1'b1;
            
            if (m0_valid && grant[0]) begin
                s0_addr <= m0_addr;
                s0_wdata <= m0_wdata;
                s0_be <= m0_be;
                s0_write <= m0_write;
                s0_ready <= 1'b1;
                m0_rdata <= s0_rdata;
            end
            
            if (m1_valid && grant[1]) begin
                s1_addr <= m1_addr;
                s1_wdata <= m1_wdata;
                s1_be <= m1_be;
                s1_write <= m1_write;
                s1_ready <= 1'b1;
                m1_rdata <= s1_rdata;
            end
            
            if (m2_valid && grant[2]) begin
                s2_addr <= m2_addr;
                s2_wdata <= m2_wdata;
                s2_be <= m2_be;
                s2_write <= m2_write;
                s2_ready <= 1'b1;
                m2_rdata <= s2_rdata;
            end
            
            if (m3_valid && grant[3]) begin
                s3_addr <= m3_addr;
                s3_wdata <= m3_wdata;
                s3_be <= m3_be;
                s3_write <= m3_write;
                s3_ready <= 1'b1;
                m3_rdata <= s3_rdata;
            end
            
            if (arb_cnt < 8'd255) arb_cnt <= arb_cnt + 1;
            else begin
                grant <= {grant[2:0], grant[3]};
                arb_cnt <= 0;
            end
        end
    end
endmodule