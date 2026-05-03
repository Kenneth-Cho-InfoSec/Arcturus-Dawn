`timescale 1ns/1ps

module cpu_core_7stage #(
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
    localparam OP_JALR   = 7'b1100111;
    localparam OP_LUI    = 7'b0110111;
    localparam OP_AUIPC  = 7'b0010111;
    localparam OP_EBREAK = 7'b1110011;

    reg [31:0] imem [0:IMEM_WORDS-1];
    reg [7:0]  dmem [0:DMEM_BYTES-1];
    reg [31:0] regs [0:31];

    reg [31:0] pc;
    reg [2:0]  halt_drain;

    reg        if_valid, id_valid, ex_valid, mem_valid, wb_valid;
    reg [31:0] if_pc, id_pc, ex_pc, mem_pc, wb_pc;
    reg [31:0] if_instr, id_instr, ex_instr, mem_instr, wb_instr;
    reg [4:0]  id_rd, ex_rd, mem_rd, wb_rd;
    reg [4:0]  id_rs1, id_rs2;
    reg [31:0] id_rs1_val, id_rs2_val;
    reg [31:0] ex_alu, mem_alu, wb_data;
    reg        ex_reg_write, mem_reg_write, wb_reg_write;
    reg        ex_mem_read, mem_mem_read;
    reg        ex_mem_write, mem_mem_write;
    reg [2:0]  mem_funct3;

    wire [6:0] id_opcode = id_instr[6:0];
    wire [6:0] ex_opcode = ex_instr[6:0];

    reg [31:0] cfi_push_addr;
    reg        cfi_push;
    reg        cfi_pop;
    wire       cfi_violation;
    wire [31:0] cfi_expected;
    wire [4:0]  cfi_depth;

    generate
        if (USE_SHADOW_STACK) begin : gen_ss
            shadow_stack ss (
                .clk(clk),
                .rst(rst),
                .push(cfi_push),
                .pop(cfi_pop),
                .ret_addr(cfi_push_addr),
                .enable(1'b1),
                .expected_ret(cfi_expected),
                .cfi_violation(cfi_violation),
                .depth(cfi_depth)
            );
        end else begin
            assign cfi_expected = 32'h0;
            assign cfi_violation = 1'b0;
            assign cfi_depth = 5'h0;
        end
    endgenerate

    wire [31:0] rs1_data = (id_rs1 == 5'd0) ? 32'h0 : regs[id_rs1];
    wire [31:0] rs2_data = (id_rs2 == 5'd0) ? 32'h0 : regs[id_rs2];

    initial begin
        for (i = 0; i < IMEM_WORDS; i = i + 1) imem[i] = 32'h00100073;
        for (i = 0; i < DMEM_BYTES; i = i + 1) dmem[i] = 8'h00;
        imem[0] = 32'h00000093;
        imem[1] = 32'h00100113;
        imem[2] = 32'h002081b3;
        imem[3] = 32'h00300213;
        imem[4] = 32'h004000b3;
        imem[5] = 32'h00100073;
        if (MEMFILE != "") $readmemh(MEMFILE, imem);
    end

    always @(posedge clk) begin
        if (rst) begin
            pc <= 32'h0;
            if_valid <= 1'b0;
            id_valid <= 1'b0;
            ex_valid <= 1'b0;
            mem_valid <= 1'b0;
            wb_valid <= 1'b0;
            halted <= 1'b0;
            debug_cycle <= 32'h0;
            debug_instret <= 32'h0;
            debug_pc <= 32'h0;
        end else begin
            debug_cycle <= debug_cycle + 1;

            if (ex_valid && ex_opcode == OP_EBREAK) begin
                halted <= 1'b1;
            end

            if (!halted) begin
                if_valid <= 1'b1;
                if_pc <= pc;
                if_instr <= imem[pc[31:2]];

                if (id_valid && id_opcode == OP_EBREAK) begin
                    pc <= pc;
                end else if (id_valid && (id_opcode == OP_JAL || id_opcode == OP_JALR)) begin
                    pc <= ex_alu;
                end else begin
                    pc <= pc + 32'd4;
                end
            end else begin
                if_valid <= 1'b0;
            end

            id_valid <= if_valid;
            id_pc <= if_pc;
            id_instr <= if_instr;
            id_rd <= if_instr[11:7];
            id_rs1 <= if_instr[19:15];
            id_rs2 <= if_instr[24:20];
            id_rs1_val <= rs1_data;
            id_rs2_val <= rs2_data;

            ex_valid <= id_valid;
            ex_pc <= id_pc;
            ex_instr <= id_instr;
            ex_rd <= id_rd;
            ex_reg_write <= 1'b0;
            ex_mem_read <= 1'b0;
            ex_mem_write <= 1'b0;

            if (id_opcode == OP_R) begin
                case (id_instr[14:12])
                    3'b000: ex_alu <= id_rs1_val + id_rs2_val;
                    3'b001: ex_alu <= id_rs1_val << id_rs2_val[4:0];
                    3'b010: ex_alu <= ($signed(id_rs1_val) < $signed(id_rs2_val)) ? 32'd1 : 32'd0;
                    3'b100: ex_alu <= id_rs1_val ^ id_rs2_val;
                    3'b110: ex_alu <= id_rs1_val | id_rs2_val;
                    3'b111: ex_alu <= id_rs1_val & id_rs2_val;
                    default: ex_alu <= 32'hdead0001;
                endcase
                ex_reg_write <= 1'b1;
            end else if (id_opcode == OP_I) begin
                ex_alu <= id_rs1_val + {{20{if_instr[31]}}, if_instr[31:20]};
                ex_reg_write <= 1'b1;
            end else if (id_opcode == OP_LUI) begin
                ex_alu <= {if_instr[31:12], 12'h000};
                ex_reg_write <= 1'b1;
            end else if (id_opcode == OP_AUIPC) begin
                ex_alu <= id_pc + {if_instr[31:12], 12'h000};
                ex_reg_write <= 1'b1;
            end else if (id_opcode == OP_JAL) begin
                ex_alu <= id_pc + 32'd4;
                ex_reg_write <= 1'b1;
                cfi_push <= 1'b1;
                cfi_push_addr <= id_pc + 32'd4;
            end else if (id_opcode == OP_JALR) begin
                ex_alu <= (id_rs1_val + {{20{if_instr[31]}}, if_instr[31:20]}) & 32'hfffffffe;
                ex_reg_write <= 1'b1;
                if (id_rd == 5'd0) begin
                    cfi_pop <= 1'b1;
                end
            end else if (id_opcode == OP_LOAD) begin
                ex_alu <= id_rs1_val + {{20{if_instr[31]}}, if_instr[31:20]};
                ex_mem_read <= 1'b1;
                ex_reg_write <= 1'b1;
            end else if (id_opcode == OP_STORE) begin
                ex_alu <= id_rs1_val + {{20{if_instr[31]}}, if_instr[31:25], if_instr[11:7]};
                ex_mem_write <= 1'b1;
            end

            mem_valid <= ex_valid;
            mem_pc <= ex_pc;
            mem_instr <= ex_instr;
            mem_alu <= ex_alu;
            mem_rd <= ex_rd;
            mem_reg_write <= ex_reg_write;
            mem_mem_read <= ex_mem_read;
            mem_mem_write <= ex_mem_write;
            mem_funct3 <= ex_instr[14:12];

            if (mem_mem_read) begin
                case (mem_funct3)
                    3'b000: wb_data <= {24'b0, dmem[mem_alu]};
                    3'b001: wb_data <= {16'b0, dmem[mem_alu+1], dmem[mem_alu]};
                    3'b010: wb_data <= {dmem[mem_alu+3], dmem[mem_alu+2], dmem[mem_alu+1], dmem[mem_alu]};
                endcase
            end else begin
                wb_data <= mem_alu;
            end

            if (mem_mem_write) begin
                dmem[mem_alu] <= id_rs2_val[7:0];
                if (mem_funct3[0]) begin
                    dmem[mem_alu+1] <= id_rs2_val[15:8];
                end
                if (mem_funct3[1]) begin
                    dmem[mem_alu+2] <= id_rs2_val[23:16];
                    dmem[mem_alu+3] <= id_rs2_val[31:24];
                end
            end

            wb_valid <= mem_valid;
            wb_pc <= mem_pc;
            wb_instr <= mem_instr;
            wb_rd <= mem_rd;
            wb_reg_write <= mem_reg_write;

            cfi_push <= 1'b0;
            cfi_pop <= 1'b0;

            if (wb_valid && wb_reg_write && wb_rd != 5'd0) begin
                regs[wb_rd] <= wb_data;
                debug_instret <= debug_instret + 1;
            end

            debug_pc <= wb_pc;
        end
    end
endmodule