`timescale 1ns/1ps

module branch_predictor_enhanced #(
    parameter BTB_L0_ENTRIES = 16,
    parameter BTB_L1_SETS = 128,
    parameter BTB_L1_WAYS = 4,
    parameter BHT_ENTRIES = 128,
    parameter RAS_DEPTH = 12,
    parameter LOOPSIZE = 8
) (
    input  wire        clk,
    input  wire        rst,
    input  wire [31:0] fetch_addr,
    input  wire        fetch_valid,
    input  wire        fetch_enable,
    output reg  [31:0] predict_target,
    output reg         predict_taken,
    output reg         predict_valid,
    input  wire [31:0] resolved_pc,
    input  wire        resolved_taken,
    input  wire        resolved_valid,
    input  wire [31:0] resolved_target
);

    localparam BTB_L0_IDX = $clog2(BTB_L0_ENTRIES);
    localparam BTB_L1_IDX = $clog2(BTB_L1_SETS);
    localparam BTB_L1_TAG = 32 - BTB_L1_IDX - 2;
    localparam BHT_IDX = $clog2(BHT_ENTRIES);

    reg [31:0] btb_l0_tag    [0:BTB_L0_ENTRIES-1];
    reg [31:0] btb_l0_target [0:BTB_L0_ENTRIES-1];
    reg [1:0]  btb_l0_state  [0:BTB_L0_ENTRIES-1];
    reg        btb_l0_valid  [0:BTB_L0_ENTRIES-1];
    reg [3:0]  btb_l0_lru    [0:BTB_L0_ENTRIES-1];

    reg [BTB_L1_TAG-1:0] btb_l1_tag  [0:BTB_L1_SETS-1][0:BTB_L1_WAYS-1];
    reg [31:0]          btb_l1_target[0:BTB_L1_SETS-1][0:BTB_L1_WAYS-1];
    reg [1:0]           btb_l1_state [0:BTB_L1_SETS-1][0:BTB_L1_WAYS-1];
    reg                 btb_l1_valid [0:BTB_L1_SETS-1][0:BTB_L1_WAYS-1];
    reg [1:0]           btb_l1_lru   [0:BTB_L1_SETS-1];

    reg [1:0]           bht          [0:BHT_ENTRIES-1];

    reg [31:0]          ras_stack    [0:RAS_DEPTH-1];
    reg [3:0]           ras_ptr;
    reg [3:0]           ras_top;

    reg [31:0]          loop_buffer  [0:LOOPSIZE-1];
    reg [4:0]           loop_start;
    reg [4:0]           loop_end;
    reg [2:0]           loop_count;
    reg                 loop_valid;
    reg                 loop_mode;

    wire [BTB_L1_IDX-1:0] btb_l1_idx = fetch_addr[BTB_L1_IDX+1:2];
    wire [BTB_L1_TAG-1:0] btb_l1_tag_w = fetch_addr[31:BTB_L1_IDX+2];

    wire [BHT_IDX-1:0] bht_idx = {fetch_addr[7:2] ^ fetch_addr[13:8] ^ fetch_addr[19:14]};

    integer i, j;
    always @(posedge clk) begin
        if (rst) begin
            predict_target <= 32'h0;
            predict_taken <= 1'b0;
            predict_valid <= 1'b0;
            loop_valid <= 1'b0;
            loop_mode <= 1'b0;
            loop_count <= 3'b0;
            ras_ptr <= 4'b0;
            ras_top <= 4'b0;

            for (i = 0; i < BTB_L0_ENTRIES; i = i + 1) begin
                btb_l0_valid[i] <= 1'b0;
                btb_l0_state[i] <= 2'b01;
                btb_l0_lru[i] <= 4'hF;
            end
            for (i = 0; i < BTB_L1_SETS; i = i + 1) begin
                btb_l1_lru[i] <= 2'b00;
                for (j = 0; j < BTB_L1_WAYS; j = j + 1) begin
                    btb_l1_valid[i][j] <= 1'b0;
                    btb_l1_state[i][j] <= 2'b01;
                end
            end
            for (i = 0; i < BHT_ENTRIES; i = i + 1) begin
                bht[i] <= 2'b01;
            end
        end else begin
            predict_valid <= 1'b0;
            predict_taken <= 1'b0;

            if (fetch_valid && fetch_enable) begin
                predict_valid <= 1'b1;

                if (loop_valid && (fetch_addr == loop_start) && (loop_count > 0)) begin
                    predict_taken <= 1'b1;
                    predict_target <= loop_end;
                    loop_count <= loop_count - 1;
                end else begin
                    for (i = 0; i < BTB_L0_ENTRIES; i = i + 1) begin
                        if (btb_l0_valid[i] && (btb_l0_tag[i] == fetch_addr[31:4])) begin
                            predict_taken <= btb_l0_state[i][1];
                            predict_target <= btb_l0_target[i];
                        end
                    end

                    if (!predict_taken) begin
                        for (i = 0; i < BTB_L1_WAYS; i = i + 1) begin
                            if (btb_l1_valid[btb_l1_idx][i] && (btb_l1_tag[btb_l1_idx][i] == btb_l1_tag_w)) begin
                                predict_taken <= btb_l1_state[btb_l1_idx][i][1];
                                predict_target <= btb_l1_target[btb_l1_idx][i];
                            end
                        end
                    end

                    if (!predict_taken) begin
                        predict_taken <= bht[bht_idx][1];
                        predict_target <= fetch_addr + 4;
                    end
                end

                if (loop_mode && (fetch_addr == loop_end)) begin
                    loop_valid <= 1'b0;
                    loop_mode <= 1'b0;
                end

                if (!loop_valid && !loop_mode) begin
                    if (fetch_addr == (loop_start + (loop_end - loop_start))) begin
                        loop_mode <= 1'b1;
                        loop_count <= 3'd4;
                        loop_valid <= 1'b1;
                    end
                end
            end

            if (resolved_valid) begin
                if (bht[bht_idx][1] != resolved_taken) begin
                    bht[bht_idx] <= resolved_taken ? 2'b11 : 2'b00;
                end else if (resolved_taken && bht[bht_idx] != 2'b11) begin
                    bht[bht_idx] <= bht[bht_idx] + 1;
                end else if (!resolved_taken && bht[bht_idx] != 2'b00) begin
                    bht[bht_idx] <= bht[bht_idx] - 1;
                end

                if (resolved_taken) begin
                    for (i = 0; i < BTB_L0_ENTRIES; i = i + 1) begin
                        if (!btb_l0_valid[i] || (btb_l0_lru[i] == 4'h0)) begin
                            btb_l0_tag[i] <= resolved_pc[31:4];
                            btb_l0_target[i] <= resolved_target;
                            btb_l0_state[i] <= resolved_taken ? 2'b11 : 2'b01;
                            btb_l0_valid[i] <= 1'b1;
                            btb_l0_lru[i] <= 4'hF;
                        end
                    end

                    for (i = 0; i < BTB_L1_WAYS; i = i + 1) begin
                        if (!btb_l1_valid[btb_l1_idx][i]) begin
                            btb_l1_tag[btb_l1_idx][i] <= resolved_pc[31:BTB_L1_IDX+2];
                            btb_l1_target[btb_l1_idx][i] <= resolved_target;
                            btb_l1_state[btb_l1_idx][i] <= resolved_taken ? 2'b11 : 2'b01;
                            btb_l1_valid[btb_l1_idx][i] <= 1'b1;
                        end
                    end
                end
            end
        end
    end

    always @(posedge clk) begin
        if (rst) begin
            for (i = 0; i < RAS_DEPTH; i = i + 1)
                ras_stack[i] <= 32'h0;
        end
    end

    task push_ras;
        input [31:0] addr;
        begin
            ras_stack[ras_ptr] <= addr;
            ras_ptr <= (ras_ptr + 1) % RAS_DEPTH;
            ras_top <= ras_ptr;
        end
    endtask

    task pop_ras;
        output [31:0] addr;
        begin
            ras_ptr <= (ras_ptr - 1) % RAS_DEPTH;
            addr = ras_stack[ras_ptr];
        end
    endtask

endmodule