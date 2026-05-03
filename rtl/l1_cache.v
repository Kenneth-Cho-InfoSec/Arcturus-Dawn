`timescale 1ns/1ps

module l1_cache_simple (
    input  wire        clk,
    input  wire        rst,
    
    input  wire [31:0] addr,
    input  wire [31:0] wdata,
    input  wire        write,
    input  wire        read,
    
    output reg  [31:0] rdata,
    output reg         hit,
    output reg         miss,
    output reg         ready
);

    localparam NUM_LINES = 8;
    integer i;

    reg [1:0] state;
    localparam ST_IDLE = 2'd0;
    localparam ST_HIT = 2'd1;
    localparam ST_MISS = 2'd2;

    reg [25:0] tag [0:NUM_LINES-1];
    reg [127:0] line_data [0:NUM_LINES-1];
    reg [NUM_LINES-1:0] valid;

    wire [2:0] index = addr[4:2];
    wire [25:0] addr_tag = addr[31:5];
    wire [2:0] offset = addr[4:2];

    wire tag_match = (tag[index] == addr_tag) && valid[index];

    always @(posedge clk) begin
        if (rst) begin
            for (i = 0; i < NUM_LINES; i = i + 1) begin
                tag[i] <= 0;
                line_data[i] <= 0;
                valid[i] <= 1'b0;
            end
            rdata <= 0;
            hit <= 1'b0;
            miss <= 1'b0;
            ready <= 1'b1;
            state <= ST_IDLE;
        end else begin
            hit <= 1'b0;
            miss <= 1'b0;
            ready <= 1'b1;
            
            case (state)
                ST_IDLE: begin
                    if (read) begin
                        if (tag_match) begin
                            rdata <= line_data[index][offset * 8 +: 31];
                            hit <= 1'b1;
                            state <= ST_HIT;
                        end else begin
                            miss <= 1'b1;
                            tag[index] <= addr_tag;
                            line_data[index] <= {96'h0, wdata};
                            valid[index] <= 1'b1;
                            state <= ST_MISS;
                        end
                    end else if (write) begin
                        if (tag_match) begin
                            line_data[index][offset * 8 +: 32] <= wdata;
                            hit <= 1'b1;
                            state <= ST_HIT;
                        end else begin
                            miss <= 1'b1;
                            tag[index] <= addr_tag;
                            line_data[index] <= {96'h0, wdata};
                            valid[index] <= 1'b1;
                            state <= ST_MISS;
                        end
                    end
                end

                ST_HIT, ST_MISS: begin
                    state <= ST_IDLE;
                end
            endcase
        end
    end
endmodule