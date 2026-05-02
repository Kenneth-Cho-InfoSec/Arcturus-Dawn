`timescale 1ns/1ps

module trng #(
    parameter LFSR_WIDTH = 32,
    parameter TAPS = 32'b10000000000000000000000000000101
) (
    input  wire        clk,
    input  wire        rst,
    input  wire        enable,
    output reg  [31:0] random_val,
    output reg         data_valid
);

    reg [LFSR_WIDTH-1:0] lfsr;

    always @(posedge clk) begin
        if (rst) begin
            lfsr <= 32'hDEADBEEF;
            random_val <= 32'h00000000;
            data_valid <= 1'b0;
        end else if (enable) begin
            lfsr[0] <= ^(lfsr & TAPS);
            lfsr[LFSR_WIDTH-1:1] <= lfsr[LFSR_WIDTH-2:0];
            random_val <= lfsr;
            data_valid <= 1'b1;
        end else begin
            data_valid <= 1'b0;
        end
    end
endmodule