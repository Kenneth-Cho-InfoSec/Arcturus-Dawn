`timescale 1ns/1ps

module shadow_stack #(
    parameter DEPTH = 16,
    parameter PTR_BITS = $clog2(DEPTH)
) (
    input  wire        clk,
    input  wire        rst,
    input  wire        push,
    input  wire        pop,
    input  wire [31:0] ret_addr,
    input  wire        enable,
    output reg  [31:0] expected_ret,
    output reg         cfi_violation,
    output reg  [4:0]  depth
);

    reg [31:0] stack [0:DEPTH-1];
    reg [PTR_BITS:0] sp;

    always @(posedge clk) begin
        if (rst) begin
            for (integer i = 0; i < DEPTH; i = i + 1)
                stack[i] <= 32'h00000000;
            sp <= 0;
            cfi_violation <= 1'b0;
            expected_ret <= 32'h00000000;
            depth <= 0;
        end else begin
            if (enable) begin
                if (push && (sp < DEPTH)) begin
                    stack[sp] <= ret_addr;
                    sp <= sp + 1'b1;
                    depth <= depth + 1'b1;
                    cfi_violation <= 1'b0;
                end else if (pop && (sp > 0)) begin
                    expected_ret <= stack[sp-1];
                    if (ret_addr != stack[sp-1]) begin
                        cfi_violation <= 1'b1;
                    end else begin
                        cfi_violation <= 1'b0;
                    end
                    sp <= sp - 1'b1;
                    depth <= depth - 1'b1;
                end else begin
                    cfi_violation <= 1'b0;
                end
            end
        end
    end
endmodule