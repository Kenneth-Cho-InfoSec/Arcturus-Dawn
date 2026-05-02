`timescale 1ns/1ps

module memory_tagging #(
    parameter TAG_BITS = 4,
    parameter NUM_ENTRIES = 256,
    parameter ADDR_BITS = 32,
    parameter GRANULARITY = 16
) (
    input  wire                  clk,
    input  wire                  rst,
    input  wire                  write_access,
    input  wire                  read_access,
    input  wire [ADDR_BITS-1:0]  addr,
    input  wire [TAG_BITS-1:0]   ptr_tag,
    input  wire [TAG_BITS-1:0]   mem_tag,
    input  wire                  enable,
    output reg                   tag_violation,
    output reg  [TAG_BITS-1:0]   stored_tag
);

    localparam IDX_BITS = $clog2(NUM_ENTRIES);
    reg [TAG_BITS-1:0] tag_table [0:NUM_ENTRIES-1];
    wire [IDX_BITS-1:0] tag_idx = addr[$clog2(GRANULARITY) +: IDX_BITS];

    always @(posedge clk) begin
        if (rst) begin
            for (integer i = 0; i < NUM_ENTRIES; i = i + 1)
                tag_table[i] <= 4'h0;
            tag_violation <= 1'b0;
            stored_tag <= 4'h0;
        end else if (enable) begin
            if (write_access) begin
                tag_table[tag_idx] <= ptr_tag;
                stored_tag <= ptr_tag;
                tag_violation <= 1'b0;
            end else if (read_access) begin
                stored_tag <= tag_table[tag_idx];
                if (ptr_tag != tag_table[tag_idx]) begin
                    tag_violation <= 1'b1;
                end
            end
        end
    end
endmodule