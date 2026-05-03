`timescale 1ns/1ps

module hardware_prefetcher #(
    parameter STREAMS = 4,
    parameter ADDR_BITS = 32
) (
    input  wire        clk,
    input  wire        rst,
    input  wire        enable,
    input  wire [ADDR_BITS-1:0] access_addr,
    input  wire        access_valid,
    input  wire        access_read,
    output reg  [ADDR_BITS-1:0] prefetch_addr,
    output reg         prefetch_valid,
    output reg  [1:0]  prefetch_priority
);

    localparam STRIDE_BITS = 8;

    reg [ADDR_BITS-1:0] stream_base   [0:STREAMS-1];
    reg [ADDR_BITS-1:0] stream_last   [0:STREAMS-1];
    reg [STRIDE_BITS-1:0] stream_stride [0:STREAMS-1];
    reg [1:0] stream_confidence [0:STREAMS-1];
    reg [1:0] stream_state [0:STREAMS-1];
    reg [3:0] stream_age [0:STREAMS-1];
    reg [STREAMS-1:0] stream_valid;

    reg [ADDR_BITS-1:0] global_last_addr;
    reg [STRIDE_BITS-1:0] global_stride;
    reg [1:0] global_confidence;
    reg global_valid;

    integer i;
    always @(posedge clk) begin
        if (rst) begin
            prefetch_valid <= 1'b0;
            prefetch_addr <= 32'h0;
            prefetch_priority <= 2'b00;
            global_valid <= 1'b0;
            global_last_addr <= 32'h0;
            global_stride <= 8'h0;
            global_confidence <= 2'b00;

            for (i = 0; i < STREAMS; i = i + 1) begin
                stream_valid[i] <= 1'b0;
                stream_state[i] <= 2'b00;
                stream_confidence[i] <= 2'b00;
                stream_age[i] <= 4'h0;
            end
        end else if (enable) begin
            prefetch_valid <= 1'b0;

            if (access_valid && access_read) begin
                global_valid <= 1'b1;

                if (global_valid && (access_addr == (global_last_addr + global_stride))) begin
                    if (global_confidence != 2'b11) begin
                        global_confidence <= global_confidence + 1;
                    end
                end else if (global_valid && (access_addr == (global_last_addr + 4))) begin
                    global_stride <= 4;
                    global_confidence <= 2'b01;
                end else if (global_valid) begin
                    global_confidence <= 2'b00;
                end

                global_last_addr <= access_addr;

                if (global_confidence >= 2'b10) begin
                    prefetch_valid <= 1'b1;
                    prefetch_addr <= access_addr + (global_stride * 2);
                    prefetch_priority <= 2'b01;
                end

                begin : stream_matching
                    for (i = 0; i < STREAMS; i = i + 1) begin
                        if (stream_valid[i] && (access_addr == stream_last[i] + stream_stride[i])) begin
                            if (stream_confidence[i] != 2'b11) begin
                                stream_confidence[i] <= stream_confidence[i] + 1;
                            end

                            if (stream_confidence[i] >= 2'b10) begin
                                prefetch_valid <= 1'b1;
                                prefetch_addr <= access_addr + stream_stride[i];
                                prefetch_priority <= 2'b10;
                            end
                        end else if (stream_valid[i] && (access_addr == stream_last[i] + 4)) begin
                            stream_stride[i] <= 4;
                            stream_confidence[i] <= 2'b01;
                        end else if (stream_valid[i] && (stream_confidence[i] == 2'b00)) begin
                            if (stream_age[i] > 4'hF) begin
                                stream_valid[i] <= 1'b0;
                            end else begin
                                stream_age[i] <= stream_age[i] + 1;
                            end
                        end

                        stream_last[i] <= access_addr;
                    end
                end

                if (!prefetch_valid && global_confidence >= 2'b01) begin
                    begin : allocate_stream
                        for (i = 0; i < STREAMS; i = i + 1) begin
                            if (!stream_valid[i]) begin
                                stream_valid[i] <= 1'b1;
                                stream_base[i] <= access_addr;
                                stream_last[i] <= access_addr;
                                stream_stride[i] <= 4;
                                stream_confidence[i] <= 2'b01;
                                stream_age[i] <= 4'h0;
                                i = STREAMS;
                            end
                        end
                    end
                end
            end
        end
    end
endmodule