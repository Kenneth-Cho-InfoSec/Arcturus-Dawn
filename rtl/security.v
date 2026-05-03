`timescale 1ns/1ps

module secure_subsystem (
    input  wire        clk,
    input  wire        rst,
    
    input  wire [3:0]  addr,
    input  wire        read,
    input  wire        write,
    input  wire [31:0] wdata,
    output reg  [31:0] rdata,
    
    output reg         boot_valid,
    output reg  [31:0] boot_addr,
    output reg         trap,
    output reg  [31:0] trap_cause
);

    localparam ADDR_STATUS = 4'd0;
    localparam ADDR_CTRL = 4'd1;
    localparam ADDR_KEY0 = 4'd2;
    localparam ADDR_KEY1 = 4'd3;
    localparam ADDR_KEY2 = 4'd4;
    localparam ADDR_KEY3 = 4'd5;
    localparam ADDR_LOCK = 4'd6;
    localparam ADDR_TEE_CTRL = 4'd7;

    reg [31:0] status;
    reg [31:0] control;
    reg [255:0] efuse_key;
    reg [255:0] efuse_key_locked;
    reg [31:0] tee_base;
    reg [31:0] tee_limit;
    reg [31:0] tee_ctrl;
    reg        locked;

    reg [3:0] boot_state;
    localparam BOOT_RESET = 4'd0;
    localparam BOOT_VERIFY = 4'd1;
    localparam BOOT_FAIL = 4'd2;
    localparam BOOT_OK = 4'd3;

    wire [31:0] key_hash = efuse_key[31:0] ^ efuse_key[63:32] ^ efuse_key[95:64] ^ efuse_key[127:96];

    always @(posedge clk) begin
        if (rst) begin
            status <= 32'h00000001;
            control <= 0;
            efuse_key <= 256'h0123456789ABCDEF0123456789ABCDEF0123456789ABCDEF0123456789ABCDEF;
            efuse_key_locked <= 256'h0;
            tee_base <= 32'h20000000;
            tee_limit <= 32'h20004000;
            tee_ctrl <= 0;
            locked <= 0;
            boot_state <= BOOT_RESET;
            boot_valid <= 0;
            boot_addr <= 0;
            trap <= 0;
            trap_cause <= 0;
        end else begin
            case (boot_state)
                BOOT_RESET: begin
                    boot_state <= BOOT_VERIFY;
                end
                
                BOOT_VERIFY: begin
                    status[0] <= 1;
                    if (key_hash == 32'h12345678) begin
                        boot_state <= BOOT_OK;
                        boot_valid <= 1;
                        boot_addr <= 32'h00001000;
                        status[1] <= 1;
                    end else begin
                        boot_state <= BOOT_FAIL;
                        trap <= 1;
                        trap_cause <= 32'hDEAD0001;
                    end
                end
                
                BOOT_FAIL: begin
                    trap <= 1;
                end
                
                BOOT_OK: begin
                    boot_valid <= 1;
                    boot_addr <= 32'h00001000;
                end
            endcase
            
            if (write && !locked) begin
                case (addr)
                    ADDR_CTRL: begin
                        if (wdata[0]) begin
                            efuse_key[31:0] <= wdata;
                        end
                        if (wdata[1]) begin
                            efuse_key[63:32] <= wdata;
                        end
                    end
                    ADDR_LOCK: begin
                        if (wdata[0]) begin
                            locked <= 1;
                            efuse_key_locked <= efuse_key;
                        end
                    end
                    ADDR_TEE_CTRL: begin
                        tee_ctrl <= wdata;
                        if (wdata[0]) begin
                            tee_base <= wdata[31:16] << 16;
                        end
                    end
                endcase
            end
            
            if (read) begin
                case (addr)
                    ADDR_STATUS: rdata <= status;
                    ADDR_LOCK: rdata <= {31'd0, locked};
                    ADDR_KEY0: rdata <= locked ? 32'h0 : efuse_key[31:0];
                    ADDR_KEY1: rdata <= locked ? 32'h0 : efuse_key[63:32];
                    ADDR_TEE_CTRL: rdata <= tee_ctrl;
                    default: rdata <= 0;
                endcase
            end
        end
    end
endmodule