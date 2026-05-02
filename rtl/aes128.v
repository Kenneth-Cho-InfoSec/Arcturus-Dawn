`timescale 1ns/1ps

module aes128 #(
    parameter KEY_BITS = 128,
    parameter DATA_BITS = 128,
    parameter ROUNDS = 10
) (
    input  wire                  clk,
    input  wire                  rst,
    input  wire                  start,
    input  wire                  encrypt,
    input  wire [KEY_BITS-1:0]   key,
    input  wire [DATA_BITS-1:0]  plaintext,
    output reg  [DATA_BITS-1:0]  ciphertext,
    output reg                   done,
    output reg                   ready
);

    reg [3:0] round;
    reg [127:0] state;
    reg [127:0] round_keys [0:ROUNDS];
    reg busy;
    reg [31:0] cycle_count;

    function [7:0] sbox;
        input [7:0] byte;
        reg [7:0] result;
        reg [7:0] b;
        begin
            result = byte;
            for (integer i = 0; i < 4; i = i + 1) begin
                b = result;
                result[0] = b[7]^b[6]^b[5]^b[4]^b[0]^1;
                result[1] = b[0]^b[7]^b[6]^b[5]^b[1]^1;
                result[2] = b[1]^b[0]^b[7]^b[6]^b[2]^1;
                result[3] = b[2]^b[1]^b[0]^b[7]^b[3]^1;
                result[4] = b[3]^b[2]^b[1]^b[0]^b[4]^1;
                result[5] = b[4]^b[3]^b[2]^b[1]^b[5]^1;
                result[6] = b[5]^b[4]^b[3]^b[2]^b[6]^1;
                result[7] = b[6]^b[5]^b[4]^b[3]^b[7]^1;
            end
            sbox = result;
        end
    endfunction

    task add_round_key;
        input [127:0] rk;
        begin
            state = state ^ rk;
        end
    endtask

    task sub_bytes;
        integer i;
        begin
            for (i = 0; i < 16; i = i + 1)
                state[i*8+7 -: 8] = sbox(state[i*8+7 -: 8]);
        end
    endtask

    task shift_rows;
        reg [127:0] tmp;
        begin
            tmp[7:0]   = state[7:0];
            tmp[15:8]  = state[47:40];
            tmp[23:16] = state[87:80];
            tmp[31:24] = state[127:120];
            tmp[39:32] = state[39:32];
            tmp[47:40] = state[79:72];
            tmp[55:48] = state[119:112];
            tmp[63:56] = state[15:8];
            tmp[71:64] = state[71:64];
            tmp[79:72] = state[111:104];
            tmp[87:80] = state[23:16];
            tmp[95:88] = state[55:48];
            tmp[103:96] = state[103:96];
            tmp[111:104] = state[15:8];
            tmp[119:112] = state[55:48];
            tmp[127:120] = state[95:88];
            state = tmp;
        end
    endtask

    function [7:0] xtime;
        input [7:0] b;
        begin
            xtime = (b << 1) ^ ((b[7]) ? 8'b00011011 : 8'b00000000);
        end
    endfunction

    task mix_columns;
        reg [7:0] a0, a1, a2, a3;
        reg [7:0] r0, r1, r2, r3;
        integer col;
        begin
            for (col = 0; col < 4; col = col + 1) begin
                a0 = state[col*32+7 -: 8];
                a1 = state[col*32+15 -: 8];
                a2 = state[col*32+23 -: 8];
                a3 = state[col*32+31 -: 8];
                r0 = xtime(a0) ^ xtime(a1) ^ a1 ^ a2 ^ a3;
                r1 = a0 ^ xtime(a1) ^ xtime(a2) ^ a2 ^ a3;
                r2 = a0 ^ a1 ^ xtime(a2) ^ xtime(a3) ^ a3;
                r3 = xtime(a0) ^ a0 ^ a1 ^ a2 ^ xtime(a3);
                state[col*32+7 -: 8] = r0;
                state[col*32+15 -: 8] = r1;
                state[col*32+23 -: 8] = r2;
                state[col*32+31 -: 8] = r3;
            end
        end
    endtask

    task key_expansion;
        input [127:0] k;
        reg [31:0] w [0:43];
        integer i;
        begin
            w[0] = k[31:0]; w[1] = k[63:32]; w[2] = k[95:64]; w[3] = k[127:96];
            for (i = 4; i < 44; i = i + 1) begin
                if (i % 4 == 0)
                    w[i] = w[i-4] ^ ({8'h01, 24'h0} << (i-4));
                else
                    w[i] = w[i-4] ^ w[i-1];
            end
            for (i = 0; i <= ROUNDS; i = i + 1)
                round_keys[i] = {w[i*4+3], w[i*4+2], w[i*4+1], w[i*4]};
        end
    endtask

    always @(posedge clk) begin
        if (rst) begin
            round <= 0;
            state <= 0;
            ciphertext <= 0;
            done <= 0;
            ready <= 1;
            busy <= 0;
            cycle_count <= 0;
            for (integer i = 0; i <= ROUNDS; i = i + 1)
                round_keys[i] <= 0;
        end else begin
            cycle_count <= cycle_count + 1;
            done <= 0;
            if (start && ready) begin
                busy <= 1;
                ready <= 0;
                round <= 0;
                state <= plaintext;
                key_expansion(key);
                add_round_key(round_keys[0]);
            end else if (busy && !ready) begin
                if (round < ROUNDS) begin
                    sub_bytes();
                    shift_rows();
                    mix_columns();
                    add_round_key(round_keys[round+1]);
                    round <= round + 1;
                end else begin
                    ciphertext <= state;
                    done <= 1;
                    ready <= 1;
                    busy <= 0;
                end
            end
        end
    end
endmodule