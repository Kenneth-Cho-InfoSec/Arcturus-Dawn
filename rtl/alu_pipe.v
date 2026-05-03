`timescale 1ns/1ps

module alu_pipe #(
    parameter PIPELINE_STAGES = 2
) (
    input  wire        clk,
    input  wire        rst,
    input  wire [31:0] a,
    input  wire [31:0] b,
    input  wire [2:0]  funct3,
    input  wire [6:0]  funct7,
    input  wire        start,
    output reg  [31:0] result,
    output reg         done
);

    reg [3:0] cycle_count;
    reg [63:0] mul_result;
    reg [63:0] div_result;
    reg [31:0] div_remainder;
    reg [31:0] div_divisor;
    reg [31:0] div_dividend;

    always @(posedge clk) begin
        if (rst) begin
            result <= 32'h0;
            done <= 1'b0;
            cycle_count <= 4'd0;
            mul_result <= 64'h0;
            div_result <= 64'h0;
            div_remainder <= 32'h0;
            div_divisor <= 32'h0;
            div_dividend <= 32'h0;
        end else if (start) begin
            done <= 1'b0;
            case ({funct7, funct3})
                {7'b0000000, 3'b000}: begin
                    result <= a + b;
                    done <= 1'b1;
                end
                {7'b0100000, 3'b000}: begin
                    result <= a - b;
                    done <= 1'b1;
                end
                {7'b0000000, 3'b111}: begin
                    result <= a & b;
                    done <= 1'b1;
                end
                {7'b0000000, 3'b110}: begin
                    result <= a | b;
                    done <= 1'b1;
                end
                {7'b0000000, 3'b100}: begin
                    result <= a ^ b;
                    done <= 1'b1;
                end
                {7'b0000000, 3'b010}: begin
                    result <= ($signed(a) < $signed(b)) ? 32'd1 : 32'd0;
                    done <= 1'b1;
                end
                {7'b0000000, 3'b001}: begin
                    result <= a << b[4:0];
                    done <= 1'b1;
                end
                {7'b0000000, 3'b101}: begin
                    result <= a >> b[4:0];
                    done <= 1'b1;
                end
                {7'b0000001, 3'b000}: begin
                    if (cycle_count == 0) begin
                        mul_result <= {32'h0, a} * {32'h0, b};
                        cycle_count <= cycle_count + 1;
                    end else if (cycle_count == 1) begin
                        result <= mul_result[31:0];
                        done <= 1'b1;
                        cycle_count <= 4'd0;
                    end
                end
                {7'b0000001, 3'b100}: begin
                    if (cycle_count == 0) begin
                        div_dividend <= a;
                        div_divisor <= b;
                        div_remainder <= 32'h0;
                        cycle_count <= 1;
                    end else if (cycle_count < 17) begin
                        {div_remainder, div_dividend} <= {div_remainder, div_dividend} << 1;
                        if (div_remainder >= div_divisor) begin
                            div_remainder <= div_remainder - div_divisor;
                            div_dividend[0] <= 1'b1;
                        end else begin
                            div_dividend[0] <= 1'b0;
                        end
                        cycle_count <= cycle_count + 1;
                    end else begin
                        result <= div_dividend;
                        done <= 1'b1;
                        cycle_count <= 4'd0;
                    end
                end
                default: begin
                    result <= 32'hbad00001;
                    done <= 1'b1;
                end
            endcase
        end
    end
endmodule