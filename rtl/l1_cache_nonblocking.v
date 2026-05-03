`timescale 1ns/1ps

module l1_cache_nonblocking #(
    parameter NUM_SETS = 8,
    parameter NUM_WAYS = 2,
    parameter LINE_SIZE = 32,
    parameter ADDR_BITS = 32,
    parameter MSHR_ENTRIES = 4
) (
    input  wire                  clk,
    input  wire                  rst,
    input  wire [ADDR_BITS-1:0]  addr,
    input  wire [31:0]           wdata,
    input  wire                  write,
    input  wire                  read,
    input  wire                  flush,
    output reg  [31:0]           rdata,
    output reg                   hit,
    output reg                   miss,
    output reg                   miss_pending,
    output reg                   ready,
    output wire [ADDR_BITS-1:0]  miss_addr,
    output wire                  miss_read
);

    localparam OFFSET_BITS = 5;
    localparam SET_BITS = 3;
    localparam TAG_BITS = ADDR_BITS - SET_BITS - OFFSET_BITS;

    reg [31:0] cache_data [0:7][0:1][0:7];
    reg [23:0] cache_tag   [0:7][0:1];
    reg        cache_valid[0:7][0:1];
    reg        cache_dirty [0:7][0:1];
    reg [1:0]  cache_lru   [0:7];

    reg [31:0] mshr_addr   [0:3];
    reg [2:0]  mshr_set    [0:3];
    reg [23:0] mshr_tag    [0:3];
    reg        mshr_valid [0:3];
    reg        mshr_write [0:3];

    reg [31:0] curr_addr;
    reg [31:0] curr_wdata;
    reg        curr_write;
    reg [2:0]  curr_set;
    reg [23:0] curr_tag;
    reg [2:0]  curr_offset;

    reg [2:0]  state;
    reg        has_request;

    assign miss_addr = mshr_addr[0];
    assign miss_read = mshr_valid[0] && !mshr_write[0];

    integer s, w;
    always @(posedge clk) begin
        if (rst) begin
            state <= 3'b0;
            hit <= 1'b0;
            miss <= 1'b0;
            miss_pending <= 1'b0;
            ready <= 1'b1;
            rdata <= 32'h0;
            has_request <= 1'b0;

            for (s = 0; s < 8; s = s + 1) begin
                cache_lru[s] <= 2'b00;
                for (w = 0; w < 2; w = w + 1) begin
                    cache_valid[s][w] <= 1'b0;
                    cache_dirty[s][w] <= 1'b0;
                end
            end
            for (w = 0; w < 4; w = w + 1) begin
                mshr_valid[w] <= 1'b0;
            end
        end else begin
            ready <= 1'b1;
            hit <= 1'b0;
            miss <= 1'b0;

            if (!has_request && (read || write)) begin
                has_request <= 1'b1;
                curr_addr <= addr;
                curr_wdata <= wdata;
                curr_write <= write;
                curr_set <= addr[7:5];
                curr_tag <= addr[31:8];
                curr_offset <= addr[4:2];
                ready <= 1'b0;
            end else if (has_request) begin
                begin : search_cache
                    for (w = 0; w < 2; w = w + 1) begin
                        if (cache_valid[curr_set][w] && cache_tag[curr_set][w] == curr_tag) begin
                            if (curr_write) begin
                                cache_data[curr_set][w][curr_offset] <= curr_wdata;
                                cache_dirty[curr_set][w] <= 1'b1;
                            end else begin
                                rdata <= cache_data[curr_set][w][curr_offset];
                            end
                            hit <= 1'b1;
                            cache_lru[curr_set] <= w;
                            has_request <= 1'b0;
                            ready <= 1'b1;
                        end
                    end
                end

                if (!hit) begin
                    begin : check_mshr
                        for (w = 0; w < 4; w = w + 1) begin
                            if (mshr_valid[w] && mshr_set[w] == curr_set && mshr_tag[w] == curr_tag) begin
                                hit <= 1'b1;
                                has_request <= 1'b0;
                                ready <= 1'b1;
                            end
                        end
                    end

                    if (!hit) begin
                        miss <= 1'b1;
                        miss_pending <= 1'b1;

                        for (w = 0; w < 4; w = w + 1) begin
                            if (!mshr_valid[w]) begin
                                mshr_addr[w] <= {curr_tag, curr_set, 5'b0};
                                mshr_set[w] <= curr_set;
                                mshr_tag[w] <= curr_tag;
                                mshr_valid[w] <= 1'b1;
                                mshr_write[w] <= curr_write;
                            end
                        end

                        begin : allocate_way
                            reg [1:0] repl_way;
                            repl_way = cache_lru[curr_set];
                            cache_valid[curr_set][repl_way] <= 1'b1;
                            cache_tag[curr_set][repl_way] <= curr_tag;
                            if (curr_write) begin
                                cache_data[curr_set][repl_way][curr_offset] <= curr_wdata;
                                cache_dirty[curr_set][repl_way] <= 1'b1;
                            end else begin
                                cache_data[curr_set][repl_way][curr_offset] <= 32'hDEADBEEF;
                            end
                            cache_lru[curr_set] <= cache_lru[curr_set] + 1;
                        end

                        miss_pending <= 1'b0;
                        has_request <= 1'b0;
                        ready <= 1'b1;
                    end
                end
            end
        end
    end
endmodule