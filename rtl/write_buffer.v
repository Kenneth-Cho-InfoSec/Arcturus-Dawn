`timescale 1ns/1ps

module write_buffer #(
    parameter DEPTH = 4
) (
    input  wire        clk,
    input  wire        rst,
    input  wire [31:0] addr,
    input  wire [31:0] wdata,
    input  wire [2:0]  funct3,
    input  wire        push,
    input  wire        drain,
    output reg         full,
    output reg         empty,
    output reg  [31:0] out_addr,
    output reg  [31:0] out_wdata,
    output reg  [2:0]  out_funct3,
    output reg         pop
);

    localparam PTR_BITS = $clog2(DEPTH);

    reg [31:0] buffer_addr [0:DEPTH-1];
    reg [31:0] buffer_wdata [0:DEPTH-1];
    reg [2:0]  buffer_funct3 [0:DEPTH-1];
    reg [PTR_BITS:0] head;
    reg [PTR_BITS:0] tail;

    wire [PTR_BITS-1:0] head_idx = head[PTR_BITS-1:0];
    wire [PTR_BITS-1:0] tail_idx = tail[PTR_BITS-1:0];

    assign full = (head[PTR_BITS-1:0] == tail[PTR_BITS-1:0]) && (head[PTR_BITS] != tail[PTR_BITS]);
    assign empty = (head[PTR_BITS-1:0] == tail[PTR_BITS-1:0]) && (head[PTR_BITS] == tail[PTR_BITS]);

    integer i;
    always @(posedge clk) begin
        if (rst) begin
            head <= 0;
            tail <= 0;
            pop <= 1'b0;
            out_addr <= 32'h0;
            out_wdata <= 32'h0;
            out_funct3 <= 3'b0;
        end else begin
            pop <= 1'b0;

            if (push && !full) begin
                buffer_addr[head_idx] <= addr;
                buffer_wdata[head_idx] <= wdata;
                buffer_funct3[head_idx] <= funct3;
                head <= head + 1;
            end

            if (drain && !empty) begin
                out_addr <= buffer_addr[tail_idx];
                out_wdata <= buffer_wdata[tail_idx];
                out_funct3 <= buffer_funct3[tail_idx];
                pop <= 1'b1;
                tail <= tail + 1;
            end
        end
    end
endmodule