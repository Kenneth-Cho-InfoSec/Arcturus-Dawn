`timescale 1ns/1ps

module cpu_core #(
    parameter IMEM_WORDS = 512,
    parameter DMEM_BYTES = 2048,
    parameter MEMFILE = "",
    parameter CORE_ID = 0,
    parameter USE_SHADOW_STACK = 1
) (
    input  wire        clk,
    input  wire        rst,
    output reg  [31:0] debug_pc,
    output reg  [31:0] debug_cycle,
    output reg  [31:0] debug_instret,
    output reg         halted,
    input  wire        ipi_trigger
);
    integer i;

    localparam OP_R      = 7'b0110011;
    localparam OP_I      = 7'b0010011;
    localparam OP_LOAD   = 7'b0000011;
    localparam OP_STORE  = 7'b0100011;
    localparam OP_BRANCH = 7'b1100011;
    localparam OP_JAL    = 7'b1101111;
    localparam OP_JALR  = 7'b1100111;
    localparam OP_LUI   = 7'b0110111;
    localparam OP_AUIPC = 7'b0010111;
    localparam OP_EBREAK = 7'b1110011;

    reg [31:0] imem [0:IMEM_WORDS-1];
    reg [7:0]  dmem [0:DMEM_BYTES-1];
    reg [31:0] regs [0:31];

    reg [31:0] pc;
    reg [2:0]  halt_drain;
    reg        ipi_pending;

    reg        if_id_valid;
    reg [31:0] if_id_pc;
    reg [31:0] if_id_instr;

    reg        id_ex_valid;
    reg [31:0] id_ex_pc;
    reg [31:0] id_ex_instr;
    reg [31:0] id_ex_rs1_val;
    reg [31:0] id_ex_rs2_val;
    reg [31:0] id_ex_imm_i;
    reg [31:0] id_ex_imm_s;
    reg [31:0] id_ex_imm_b;
    reg [31:0] id_ex_imm_u;
    reg [31:0] id_ex_imm_j;
    reg [4:0]  id_ex_rs1;
    reg [4:0]  id_ex_rs2;
    reg [4:0]  id_ex_rd;
    reg [2:0]  id_ex_funct3;
    reg [6:0]  id_ex_funct7;
    reg [6:0]  id_ex_opcode;

    reg        ex_mem_valid;
    reg [31:0] ex_mem_pc;
    reg [31:0] ex_mem_instr;
    reg [31:0] ex_mem_alu;
    reg [31:0] ex_mem_rs2_val;
    reg [4:0]  ex_mem_rd;
    reg [2:0]  ex_mem_funct3;
    reg        ex_mem_reg_write;
    reg        ex_mem_mem_read;
    reg        ex_mem_mem_write;

    reg        mem_wb_valid;
    reg [31:0] mem_wb_pc;
    reg [31:0] mem_wb_instr;
    reg [31:0] mem_wb_data;
    reg [4:0]  mem_wb_rd;
    reg        mem_wb_reg_write;

    wire [6:0] id_opcode = if_id_instr[6:0];
    wire [4:0] id_rd = if_id_instr[11:7];
    wire [2:0] id_funct3 = if_id_instr[14:12];
    wire [4:0] id_rs1 = if_id_instr[19:15];
    wire [4:0] id_rs2 = if_id_instr[24:20];
    wire [6:0] id_funct7 = if_id_instr[31:25];
    wire [31:0] id_imm_i = {{20{if_id_instr[31]}}, if_id_instr[31:20]};
    wire [31:0] id_imm_s = {{20{if_id_instr[31]}}, if_id_instr[31:25], if_id_instr[11:7]};
    wire [31:0] id_imm_b = {{19{if_id_instr[31]}}, if_id_instr[31], if_id_instr[7], if_id_instr[30:25], if_id_instr[11:8], 1'b0};
    wire [31:0] id_imm_u = {if_id_instr[31:12], 12'h000};
    wire [31:0] id_imm_j = {{11{if_id_instr[31]}}, if_id_instr[31], if_id_instr[19:12], if_id_instr[20], if_id_instr[30:21], 1'b0};

    wire load_use_hazard = id_ex_valid && id_ex_opcode == OP_LOAD && id_ex_rd != 5'd0 &&
                       if_id_valid && (id_ex_rd == id_rs1 || id_ex_rd == id_rs2);

    wire [31:0] rs1_file = (id_rs1 == 5'd0) ? 32'h00000000 : regs[id_rs1];
    wire [31:0] rs2_file = (id_rs2 == 5'd0) ? 32'h00000000 : regs[id_rs2];

    wire [31:0] fwd_rs1_a = (ex_mem_valid && ex_mem_reg_write && !ex_mem_mem_read && ex_mem_rd != 5'd0 && ex_mem_rd == id_ex_rs1) ? ex_mem_alu :
                             (mem_wb_valid && mem_wb_reg_write && mem_wb_rd != 5'd0 && mem_wb_rd == id_ex_rs1) ? mem_wb_data :
                             id_ex_rs1_val;
    wire [31:0] fwd_rs2_a = (ex_mem_valid && ex_mem_reg_write && !ex_mem_mem_read && ex_mem_rd != 5'd0 && ex_mem_rd == id_ex_rs2) ? ex_mem_alu :
                             (mem_wb_valid && mem_wb_reg_write && mem_wb_rd != 5'd0 && mem_wb_rd == id_ex_rs2) ? mem_wb_data :
                             id_ex_rs2_val;

    reg [31:0] ex_alu;
    reg [31:0] ex_next_pc;
    reg        ex_take_branch;
    reg        ex_reg_write;
    reg        ex_mem_read;
    reg        ex_mem_write;

    // Shadow Stack signals
    reg        cfi_push;
    reg        cfi_pop;
    reg [31:0] cfi_ret_addr;
    wire       cfi_violation;
    wire [31:0] cfi_expected;
    wire [4:0]  cfi_depth;

    generate
        if (USE_SHADOW_STACK) begin
            shadow_stack ss (
                .clk(clk),
                .rst(rst),
                .push(cfi_push),
                .pop(cfi_pop),
                .ret_addr(cfi_ret_addr),
                .enable(1'b1),
                .expected_ret(cfi_expected),
                .cfi_violation(cfi_violation),
                .depth(cfi_depth)
            );
        end
    endgenerate

    function [31:0] load_word;
        input [31:0] addr;
        begin
            load_word = {dmem[addr + 3], dmem[addr + 2], dmem[addr + 1], dmem[addr]};
        end
    endfunction

    task store_word;
        input [31:0] addr;
        input [31:0] value;
        begin
            dmem[addr] <= value[7:0];
            dmem[addr + 1] <= value[15:8];
            dmem[addr + 2] <= value[23:16];
            dmem[addr + 3] <= value[31:24];
        end
    endtask

    initial begin
        for (i = 0; i < IMEM_WORDS; i = i + 1) imem[i] = 32'h00100073;
        for (i = 0; i < DMEM_BYTES; i = i + 1) dmem[i] = 8'h00;
        
        imem[0] = 32'h00000093;  // addi x1, x0, 0
        imem[1] = 32'h00100113;  // addi x2, x0, 1
        imem[2] = 32'h002081b3;  // add x3, x1, x2
        imem[3] = 32'h00300213;  // addi x4, x0, 3
        imem[4] = 32'h004000b3;  // add x1, x0, x4
        imem[5] = 32'h00100073;  // ebreak
        
        if (MEMFILE != "") $readmemh(MEMFILE, imem);
    end

    always @(*) begin
        ex_alu = 32'h00000000;
        ex_next_pc = id_ex_pc + 32'd4;
        ex_take_branch = 1'b0;
        ex_reg_write = 1'b0;
        ex_mem_read = 1'b0;
        ex_mem_write = 1'b0;

        if (id_ex_opcode == OP_EBREAK) begin
            ex_reg_write = 1'b0;
            ex_alu = 32'h00000000;
        end else begin
        case (id_ex_opcode)
            OP_R: begin
                ex_reg_write = 1'b1;
                case ({id_ex_funct7, id_ex_funct3})
                    {7'b0000000, 3'b000}: ex_alu = fwd_rs1_a + fwd_rs2_a;
                    {7'b0100000, 3'b000}: ex_alu = fwd_rs1_a - fwd_rs2_a;
                    {7'b0000000, 3'b111}: ex_alu = fwd_rs1_a & fwd_rs2_a;
                    {7'b0000000, 3'b110}: ex_alu = fwd_rs1_a | fwd_rs2_a;
                    {7'b0000000, 3'b100}: ex_alu = fwd_rs1_a ^ fwd_rs2_a;
                    {7'b0000000, 3'b010}: ex_alu = (fwd_rs1_a < fwd_rs2_a) ? 32'd1 : 32'd0;
                    {7'b0000000, 3'b001}: ex_alu = fwd_rs1_a << fwd_rs2_a[4:0];
                    {7'b0000000, 3'b101}: ex_alu = fwd_rs1_a >> fwd_rs2_a[4:0];
                    default: ex_alu = 32'hbad00001;
                endcase
            end
            OP_I: begin
                ex_reg_write = 1'b1;
                case (id_ex_funct3)
                    3'b000: ex_alu = fwd_rs1_a + id_ex_imm_i;
                    3'b111: ex_alu = fwd_rs1_a & id_ex_imm_i;
                    3'b110: ex_alu = fwd_rs1_a | id_ex_imm_i;
                    3'b100: ex_alu = fwd_rs1_a ^ id_ex_imm_i;
                    3'b010: ex_alu = (fwd_rs1_a < id_ex_imm_i) ? 32'd1 : 32'd0;
                    3'b001: ex_alu = fwd_rs1_a << id_ex_imm_i[4:0];
                    3'b101: ex_alu = fwd_rs1_a >> id_ex_imm_i[4:0];
                    default: ex_alu = 32'hbad00002;
                endcase
            end
            OP_LOAD: begin
                ex_mem_read = 1'b1;
                ex_alu = fwd_rs1_a + id_ex_imm_i;
            end
            OP_STORE: begin
                ex_mem_write = 1'b1;
                ex_alu = fwd_rs1_a + id_ex_imm_s;
            end
            OP_BRANCH: begin
                case (id_ex_funct3)
                    3'b000: ex_take_branch = (fwd_rs1_a == fwd_rs2_a);
                    3'b001: ex_take_branch = (fwd_rs1_a != fwd_rs2_a);
                    3'b100: ex_take_branch = ($signed(fwd_rs1_a) < $signed(fwd_rs2_a));
                    3'b101: ex_take_branch = ($signed(fwd_rs1_a) >= $signed(fwd_rs2_a));
                    default: ex_take_branch = 1'b0;
                endcase
                if (ex_take_branch) ex_next_pc = id_ex_pc + id_ex_imm_b;
            end
            OP_JAL: begin
                ex_reg_write = 1'b1;
                ex_alu = id_ex_pc + 32'd4;
                ex_next_pc = id_ex_pc + id_ex_imm_j;
            end
            OP_JALR: begin
                ex_reg_write = 1'b1;
                ex_alu = id_ex_pc + 32'd4;
                ex_next_pc = (fwd_rs1_a + id_ex_imm_i) & 32'hFFFFFFFE;
            end
            OP_LUI: begin
                ex_reg_write = 1'b1;
                ex_alu = id_ex_imm_u;
            end
            OP_AUIPC: begin
                ex_reg_write = 1'b1;
                ex_alu = id_ex_pc + id_ex_imm_u;
            end
        endcase
        end
    end

    always @(posedge clk) begin
        if (rst) begin
            pc <= 32'h00000000;
            halt_drain <= 3'd0;
            if_id_valid <= 1'b0;
            id_ex_valid <= 1'b0;
            ex_mem_valid <= 1'b0;
            mem_wb_valid <= 1'b0;
            halted <= 1'b0;
            debug_pc <= 32'h00000000;
            debug_cycle <= 32'h00000000;
            debug_instret <= 32'h00000000;
            ipi_pending <= 1'b0;
            cfi_push <= 1'b0;
            cfi_pop <= 1'b0;
            cfi_ret_addr <= 32'h00000000;
            for (i = 0; i < 32; i = i + 1) regs[i] <= 32'h00000000;
        end else begin
            debug_cycle <= debug_cycle + 32'd1;

            if (ipi_trigger) begin
                ipi_pending <= 1'b1;
            end

            // CFI push on jal
            cfi_push <= (if_id_valid && id_opcode == OP_JAL);
            cfi_ret_addr <= pc;
            
            // CFI pop on jalr with rd=0 (ret)
            cfi_pop <= (id_ex_valid && id_ex_opcode == OP_JALR && id_ex_rd == 5'd0);

            if (!halted) begin
                if (cfi_violation) begin
                    halted <= 1'b1;
                end else if (if_id_valid && if_id_instr == 32'h00100073) begin
                    if (halt_drain == 3'd0) halt_drain <= 3'd1;
                    else if (halt_drain < 3'd7) halt_drain <= halt_drain + 3'd1;
                    else halted <= 1'b1;
                end

                if (!if_id_valid && !id_ex_valid && !load_use_hazard) begin
                    if_id_valid <= 1'b1;
                    if_id_pc <= pc;
                    if_id_instr <= imem[pc[31:2]];
                    if (CORE_ID == 0) debug_pc <= pc;
                    pc <= pc + 32'd4;
                end

                if (if_id_valid && !id_ex_valid) begin
                    id_ex_valid <= 1'b1;
                    id_ex_pc <= if_id_pc;
                    id_ex_instr <= if_id_instr;
                    id_ex_rs1_val <= rs1_file;
                    id_ex_rs2_val <= rs2_file;
                    id_ex_imm_i <= id_imm_i;
                    id_ex_imm_s <= id_imm_s;
                    id_ex_imm_b <= id_imm_b;
                    id_ex_imm_u <= id_imm_u;
                    id_ex_imm_j <= id_imm_j;
                    id_ex_rs1 <= id_rs1;
                    id_ex_rs2 <= id_rs2;
                    id_ex_rd <= id_rd;
                    id_ex_funct3 <= id_funct3;
                    id_ex_funct7 <= id_funct7;
                    id_ex_opcode <= id_opcode;
                end else begin
                    id_ex_valid <= 1'b0;
                end

                if (id_ex_valid && !ex_mem_valid) begin
                    ex_mem_valid <= 1'b1;
                    ex_mem_pc <= id_ex_pc;
                    ex_mem_instr <= id_ex_instr;
                    ex_mem_alu <= ex_alu;
                    ex_mem_rs2_val <= id_ex_rs2_val;
                    ex_mem_rd <= id_ex_rd;
                    ex_mem_funct3 <= id_ex_funct3;
                    ex_mem_reg_write <= ex_reg_write;
                    ex_mem_mem_read <= ex_mem_read;
                    ex_mem_mem_write <= ex_mem_write;
                end else begin
                    ex_mem_valid <= 1'b0;
                end

                if (ex_mem_valid && !mem_wb_valid) begin
                    mem_wb_valid <= 1'b1;
                    mem_wb_pc <= ex_mem_pc;
                    mem_wb_instr <= ex_mem_instr;
                    mem_wb_rd <= ex_mem_rd;
                    mem_wb_reg_write <= ex_mem_reg_write;

                    if (ex_mem_mem_read) begin
                        if (ex_mem_funct3 == 3'b010) mem_wb_data <= {dmem[ex_mem_alu + 3], dmem[ex_mem_alu + 2], dmem[ex_mem_alu + 1], dmem[ex_mem_alu]};
                        else if (ex_mem_funct3 == 3'b000) mem_wb_data <= {{24{dmem[ex_mem_alu][7]}}, dmem[ex_mem_alu]};
                        else mem_wb_data <= 32'h00000000;
                    end else begin
                        mem_wb_data <= ex_mem_alu;
                    end

                    if (ex_mem_mem_write) begin
                        store_word(ex_mem_alu, ex_mem_rs2_val);
                    end
                end else begin
                    mem_wb_valid <= 1'b0;
                end

                if (mem_wb_valid && mem_wb_reg_write && mem_wb_rd != 5'd0) begin
                    regs[mem_wb_rd] <= mem_wb_data;
                    debug_instret <= debug_instret + 32'd1;
                end

                if (ex_take_branch) pc <= ex_next_pc;
                else if (id_ex_valid && (id_ex_opcode == OP_JAL || id_ex_opcode == OP_JALR)) pc <= ex_next_pc;
            end
        end
    end
endmodule