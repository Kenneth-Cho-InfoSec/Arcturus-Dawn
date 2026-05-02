`timescale 1ns/1ps

module l2_cache (
    input  wire        clk,
    input  wire        rst,
    
    input  wire [3:0]  core_id,
    input  wire [31:0] addr,
    input  wire [31:0] wdata,
    input  wire        write,
    input  wire        read,
    input  wire        invalidate,
    
    output reg  [31:0] rdata,
    output reg         ready,
    output reg  [1:0]  coherency_state,
    
    output reg  [31:0] debug_hits,
    output reg  [31:0] debug_misses
);

    localparam NUM_LINES = 32;
    integer i;

    reg [1:0] state;
    localparam ST_IDLE = 2'd0;
    localparam ST_LOOKUP = 2'd1;
    localparam ST_FILL = 2'd2;

    reg [23:0] tag [0:NUM_LINES-1];
    reg [223:0] line_data [0:NUM_LINES-1];
    reg [NUM_LINES-1:0] valid;
    reg [3:0] owner [0:NUM_LINES-1];
    reg [NUM_LINES-1:0] dirty;
    reg [NUM_LINES-1:0] shared;
    reg miss;

    wire [4:0] index = addr[5:1];
    wire [23:0] addr_tag = addr[31:7];
    wire [2:0] offset = addr[4:2];

    wire tag_match = (tag[index] == addr_tag) && valid[index];

    always @(posedge clk) begin
        if (rst) begin
            for (i = 0; i < NUM_LINES; i = i + 1) begin
                tag[i] <= 0;
                line_data[i] <= 0;
                valid[i] <= 1'b0;
                owner[i] <= 0;
                dirty[i] <= 1'b0;
                shared[i] <= 1'b0;
            end
            rdata <= 0;
            ready <= 1'b1;
            coherency_state <= 2'b00;
            debug_hits <= 0;
            debug_misses <= 0;
            state <= ST_IDLE;
            miss <= 1'b0;
        end else begin
            miss <= 1'b0;
            coherency_state <= 2'b00;
            ready <= 1'b1;
            
            case (state)
                ST_IDLE: begin
                    if (read || write || invalidate) begin
                        state <= ST_LOOKUP;
                    end
                end

                ST_LOOKUP: begin
                    if (tag_match) begin
                        if (read) begin
                            rdata <= line_data[index][offset * 8 +: 31];
                            coherency_state <= shared[index] ? 2'b01 : 2'b10;
                            debug_hits <= debug_hits + 1;
                        end
                        if (write) begin
                            line_data[index][offset * 8 +: 32] <= wdata;
                            dirty[index] <= 1'b1;
                            owner[index] <= core_id;
                            shared[index] <= 1'b0;
                            coherency_state <= 2'b11;
                            debug_hits <= debug_hits + 1;
                        end
                        state <= ST_IDLE;
                    end else begin
                        miss <= 1'b1;
                        debug_misses <= debug_misses + 1;
                        
                        tag[index] <= addr_tag;
                        line_data[index] <= {192'h0, wdata};
                        valid[index] <= 1'b1;
                        dirty[index] <= write;
                        shared[index] <= read;
                        owner[index] <= write ? core_id : 4'd0;
                        
                        state <= ST_FILL;
                    end
                end

                ST_FILL: begin
                    if (read) begin
                        rdata <= line_data[index][offset * 8 +: 31];
                    end
                    state <= ST_IDLE;
                end
            endcase
        end
    end
endmodule