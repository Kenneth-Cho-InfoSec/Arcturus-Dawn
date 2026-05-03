`timescale 1ns/1ps

module memory_tagging_async #(
    parameter TAG_BITS = 4,
    parameter NUM_ENTRIES = 256,
    parameter ADDR_BITS = 32,
    parameter GRANULARITY = 16,
    parameter PIPELINE_STAGES = 1
) (
    input  wire                  clk,
    input  wire                  rst,
    input  wire                  write_access,
    input  wire                  read_access,
    input  wire [ADDR_BITS-1:0]  addr,
    input  wire [TAG_BITS-1:0]   ptr_tag,
    input  wire                  enable,
    output reg                   tag_violation,
    output reg                   ready,
    output reg  [TAG_BITS-1:0]   stored_tag
);

    localparam IDX_BITS = $clog2(NUM_ENTRIES);
    localparam ST_IDLE = 1'b0;
    localparam ST_CHECK = 1'b1;

    reg [TAG_BITS-1:0] tag_table [0:NUM_ENTRIES-1];
    wire [IDX_BITS-1:0] tag_idx = addr[$clog2(GRANULARITY) +: IDX_BITS];

    reg state;
    reg [ADDR_BITS-1:0] pending_addr;
    reg [TAG_BITS-1:0] pending_ptr_tag;
    reg [TAG_BITS-1:0] pending_stored_tag;
    reg pending_write;
    reg pending_read;

    integer k;
    always @(posedge clk) begin
        if (rst) begin
            for (k = 0; k < NUM_ENTRIES; k = k + 1)
                tag_table[k] <= 4'h0;
            tag_violation <= 1'b0;
            stored_tag <= 4'h0;
            ready <= 1'b1;
            state <= ST_IDLE;
            pending_write <= 1'b0;
            pending_read <= 1'b0;
        end else begin
            case (state)
                ST_IDLE: begin
                    ready <= 1'b1;
                    tag_violation <= 1'b0;

                    if (enable && (write_access || read_access)) begin
                        ready <= 1'b0;
                        pending_addr <= addr;
                        pending_ptr_tag <= ptr_tag;
                        pending_write <= write_access;
                        pending_read <= read_access;
                        state <= ST_CHECK;
                    end
                end

                ST_CHECK: begin
                    if (pending_write) begin
                        tag_table[pending_addr[$clog2(GRANULARITY) +: IDX_BITS]] <= pending_ptr_tag;
                        stored_tag <= pending_ptr_tag;
                        tag_violation <= 1'b0;
                    end else if (pending_read) begin
                        stored_tag <= tag_table[pending_addr[$clog2(GRANULARITY) +: IDX_BITS]];
                        if (pending_ptr_tag != tag_table[pending_addr[$clog2(GRANULARITY) +: IDX_BITS]]) begin
                            tag_violation <= 1'b1;
                        end else begin
                            tag_violation <= 1'b0;
                        end
                    end
                    ready <= 1'b1;
                    state <= ST_IDLE;
                end
            endcase
        end
    end
endmodule