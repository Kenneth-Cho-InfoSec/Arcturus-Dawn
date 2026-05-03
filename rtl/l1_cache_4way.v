`timescale 1ns/1ps

module l1_cache_4way #(
    parameter NUM_SETS = 128,
    parameter NUM_WAYS = 4,
    parameter LINE_SIZE = 32,
    parameter ADDR_BITS = 32
) (
    input  wire                  clk,
    input  wire                  rst,
    input  wire [ADDR_BITS-1:0]  addr,
    input  wire [31:0]           wdata,
    input  wire                  write,
    input  wire                  read,
    output reg  [31:0]           rdata,
    output reg                   hit,
    output reg                   miss,
    output reg                   ready
);

    localparam OFFSET_BITS = $clog2(LINE_SIZE);
    localparam SET_BITS = $clog2(NUM_SETS);
    localparam TAG_BITS = ADDR_BITS - SET_BITS - OFFSET_BITS;

    localparam ST_IDLE = 2'b00;
    localparam ST_READ = 2'b01;
    localparam ST_MISS = 2'b10;
    localparam ST_WRITE = 2'b11;

    wire [SET_BITS-1:0] set_idx = addr[OFFSET_BITS +: SET_BITS];
    wire [TAG_BITS-1:0] tag = addr[OFFSET_BITS + SET_BITS +: TAG_BITS];
    wire [OFFSET_BITS-1:0] offset = addr[0 +: OFFSET_BITS];

    reg [31:0] cache_data [0:NUM_SETS-1][0:NUM_WAYS-1][0:LINE_SIZE/4-1];
    reg [TAG_BITS-1:0] cache_tag  [0:NUM_SETS-1][0:NUM_WAYS-1];
    reg        cache_valid[0:NUM_SETS-1][0:NUM_WAYS-1];
    reg [1:0]  cache_lru   [0:NUM_SETS-1];
    reg [1:0]  state;
    reg [SET_BITS-1:0] pending_set;
    reg [TAG_BITS-1:0] pending_tag;
    reg [31:0] pending_wdata;
    reg [OFFSET_BITS-1:0] pending_offset;
    reg pending_write;

    integer s, w, b;
    always @(posedge clk) begin
        if (rst) begin
            state <= ST_IDLE;
            hit <= 1'b0;
            miss <= 1'b0;
            ready <= 1'b1;
            rdata <= 32'h0;
            for (s = 0; s < NUM_SETS; s = s + 1) begin
                cache_lru[s] <= 2'b00;
                for (w = 0; w < NUM_WAYS; w = w + 1) begin
                    cache_valid[s][w] <= 1'b0;
                end
            end
        end else begin
            case (state)
                ST_IDLE: begin
                    if (read || write) begin
                        ready <= 1'b0;
                        state <= ST_READ;
                    end
                end

                ST_READ: begin
                    begin : search_ways
                        for (w = 0; w < NUM_WAYS; w = w + 1) begin
                            if (cache_valid[set_idx][w] && cache_tag[set_idx][w] == tag) begin
                                rdata <= cache_data[set_idx][w][offset[4:2]];
                                hit <= 1'b1;
                                miss <= 1'b0;
                                cache_lru[set_idx] <= w;
                                state <= ST_IDLE;
                                ready <= 1'b1;
                            end
                        end
                    end
                    if (state == ST_READ) begin
                        hit <= 1'b0;
                        miss <= 1'b1;
                        pending_set <= set_idx;
                        pending_tag <= tag;
                        pending_wdata <= wdata;
                        pending_offset <= offset;
                        pending_write <= write;
                        state <= ST_MISS;
                    end
                end

                ST_MISS: begin
                    begin : find_lru_way
                        reg [1:0] lru_way;
                        lru_way = cache_lru[pending_set];
                        cache_valid[pending_set][lru_way] <= 1'b1;
                        cache_tag[pending_set][lru_way] <= pending_tag;
                        cache_data[pending_set][lru_way][pending_offset[4:2]] <= pending_write ? pending_wdata : 32'hDEADBEEF;
                        cache_lru[pending_set] <= cache_lru[pending_set] + 1;
                    end
                    hit <= 1'b0;
                    miss <= 1'b0;
                    state <= ST_IDLE;
                    ready <= 1'b1;
                    if (read) begin
                        rdata <= 32'hCAFEBABE;
                    end
                end
            endcase
        end
    end
endmodule