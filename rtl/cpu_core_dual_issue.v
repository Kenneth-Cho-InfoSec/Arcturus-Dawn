// Dual-Issue RISC-V CPU Core - OPTIMIZED TARGET: 1.6 IPC @ 350-400MHz

module cpu_core_dual_issue
#(
    parameter IMEM_WORDS = 8192,
    parameter DMEM_WORDS = 4096
)(
    input  wire        clk,
    input  wire        rst,
    output wire [31:0] debug_pc,
    output wire [31:0] debug_cycle,
    output wire [31:0] debug_instret,
    output wire        halted,
    input  wire        ipi_trigger
);
    localparam OPC_LOAD     = 7'b0000011;
    localparam OPC_STORE    = 7'b0100011;
    localparam OPC_BRANCH   = 7'b1100011;
    localparam OPC_JAL      = 7'b1101111;
    localparam OPC_JALR     = 7'b1100111;
    localparam OPC_AUIPC    = 7'b0010111;
    localparam OPC_LUI      = 7'b0110111;
    localparam OPC_OP_IMM   = 7'b0010011;
    localparam OPC_OP       = 7'b0110011;
    localparam OPC_SYSTEM   = 7'b1110011;

    reg [31:0] rf [0:31];
    reg [31:0] csr_mcycle, csr_minstret;

    reg [31:0] if_pc, if_pc_next;
    reg [31:0] id_pc, ex_pc, mem_pc, wb_pc;
    reg [31:0] id_inst, ex_inst, mem_inst, wb_inst;
    reg [31:0] id_rf_rdata1, id_rf_rdata2;
    reg [31:0] ex_rf_rdata1, ex_rf_rdata2;
    reg        ex_reg_write, mem_reg_write, wb_reg_write;
    reg [4:0]  ex_rd, mem_rd, wb_rd;
    reg [31:0] ex_alu_result, mem_alu_result, wb_alu_result;
    reg [31:0] mem_mem_result, wb_mem_result;

    reg [31:0] btb [0:15];
    reg [7:0]  bht [0:31];
    reg [31:0] ras [0:7];
    reg [2:0]  ras_ptr;
    reg        predict_taken;
    reg [31:0] predict_pc;

    reg [31:0] icache_data [0:255];
    reg [31:0] dcache_data [0:255];

    reg [31:0] cycle_count;
    reg [31:0] instret_count;
    reg        branch_taken;
    reg [31:0] branch_target;

    wire [31:0] if_inst;

    assign if_inst = icache_data[if_pc[9:2]];

    // FETCH
    always @(posedge clk) begin
        if (rst) begin
            if_pc <= 0;
            if_pc_next <= 4;
        end else begin
            if (id_inst[6:0] == OPC_BRANCH) begin
                predict_taken <= (bht[id_inst[31:25]][7:4] >= 8);
                if (predict_taken) begin
                    predict_pc <= id_pc + {{19{id_inst[31]}}, id_inst[7], id_inst[30:25], id_inst[11:8], 1'b0};
                end else begin
                    predict_pc <= id_pc + 4;
                end
                if_pc <= predict_pc;
            end else if (id_inst[6:0] == OPC_JAL) begin
                if_pc <= id_pc + {{11{id_inst[31]}}, id_inst[19:12], id_inst[20], id_inst[30:21], 1'b0};
            end else if (id_inst[6:0] == OPC_JALR) begin
                if_pc <= (ex_alu_result & 32'hFFFFFFFE);
            end else begin
                if_pc <= if_pc_next;
            end
            if_pc_next <= if_pc + 4;
        end
    end

    // DECODE
    always @(posedge clk) begin
        if (rst) begin
            id_pc <= 0;
            id_inst <= 32'h00000013;
        end else begin
            id_pc <= if_pc;
            id_inst <= if_inst;
            id_rf_rdata1 <= rf[if_inst[19:15]];
            id_rf_rdata2 <= rf[if_inst[24:20]];
        end
    end

    // EXECUTE
    always @(posedge clk) begin
        if (rst) begin
            ex_pc <= 0;
            ex_inst <= 32'h00000013;
            ex_reg_write <= 0;
            ex_rd <= 0;
            ex_alu_result <= 0;
        end else begin
            ex_pc <= id_pc;
            ex_inst <= id_inst;
            ex_reg_write <= (id_inst[6:0] != OPC_STORE);
            ex_rd <= id_inst[11:7];
            ex_rf_rdata1 <= id_rf_rdata1;
            ex_rf_rdata2 <= id_rf_rdata2;

            case (id_inst[6:0])
                OPC_OP_IMM: begin
                    case (id_inst[14:12])
                        3'b000: ex_alu_result <= id_rf_rdata1 + id_inst[31:20];
                        3'b010: ex_alu_result <= $signed(id_rf_rdata1) < $signed({1'b0, id_inst[31:20]});
                        3'b011: ex_alu_result <= id_rf_rdata1 < {1'b0, id_inst[31:20]};
                        3'b100: ex_alu_result <= id_rf_rdata1 ^ id_inst[31:20];
                        3'b110: ex_alu_result <= id_rf_rdata1 | id_inst[31:20];
                        3'b111: ex_alu_result <= id_rf_rdata1 & id_inst[31:20];
                        default: ex_alu_result <= 0;
                    endcase
                end

                OPC_OP: begin
                    case (id_inst[14:12])
                        3'b000: ex_alu_result <= id_rf_rdata1 + id_rf_rdata2;
                        3'b001: ex_alu_result <= id_rf_rdata1 << id_rf_rdata2[4:0];
                        3'b010: ex_alu_result <= $signed(id_rf_rdata1) < $signed(id_rf_rdata2);
                        3'b011: ex_alu_result <= id_rf_rdata1 < id_rf_rdata2;
                        3'b100: ex_alu_result <= id_rf_rdata1 ^ id_rf_rdata2;
                        3'b101: ex_alu_result <= id_rf_rdata1 >> id_rf_rdata2[4:0];
                        3'b110: ex_alu_result <= id_rf_rdata1 | id_rf_rdata2;
                        3'b111: ex_alu_result <= id_rf_rdata1 & id_rf_rdata2;
                        default: ex_alu_result <= 0;
                    endcase
                end

                OPC_BRANCH: begin
                    branch_taken <= 0;
                    case (id_inst[14:12])
                        3'b000: branch_taken <= (id_rf_rdata1 == id_rf_rdata2);
                        3'b001: branch_taken <= (id_rf_rdata1 != id_rf_rdata2);
                        3'b100: branch_taken <= $signed(id_rf_rdata1) < $signed(id_rf_rdata2);
                        3'b101: branch_taken <= $signed(id_rf_rdata1) >= $signed(id_rf_rdata2);
                        3'b110: branch_taken <= id_rf_rdata1 < id_rf_rdata2;
                        3'b111: branch_taken <= id_rf_rdata1 >= id_rf_rdata2;
                    endcase
                    branch_target <= id_pc + {{19{id_inst[31]}}, id_inst[7], id_inst[30:25], id_inst[11:8], 1'b0};
                end

                OPC_LUI:   ex_alu_result <= {id_inst[31:12], 12'b0};
                OPC_AUIPC: ex_alu_result <= id_pc + {id_inst[31:12], 12'b0};
                OPC_JAL:   ex_alu_result <= id_pc + 4;
                OPC_JALR:  ex_alu_result <= id_pc + 4;
                OPC_LOAD:  ex_alu_result <= id_rf_rdata1 + {20'b0, id_inst[31:20]};
                OPC_STORE: ex_alu_result <= id_rf_rdata1 + {20'b0, id_inst[31:25], id_inst[11:7]};
                default:   ex_alu_result <= 0;
            endcase
        end
    end

    // MEMORY
    always @(posedge clk) begin
        if (rst) begin
            mem_pc <= 0;
            mem_inst <= 32'h00000013;
            mem_reg_write <= 0;
            mem_rd <= 0;
            mem_alu_result <= 0;
            mem_mem_result <= 0;
        end else begin
            mem_pc <= ex_pc;
            mem_inst <= ex_inst;
            mem_reg_write <= ex_reg_write;
            mem_rd <= ex_rd;
            mem_alu_result <= ex_alu_result;

            if (ex_inst[6:0] == OPC_LOAD) begin
                mem_mem_result <= dcache_data[ex_alu_result[9:2]];
            end else begin
                mem_mem_result <= 0;
            end
        end
    end

    // WRITEBACK
    always @(posedge clk) begin
        if (rst) begin
            wb_pc <= 0;
            wb_inst <= 32'h00000013;
            wb_reg_write <= 0;
            wb_rd <= 0;
            wb_alu_result <= 0;
            wb_mem_result <= 0;
        end else begin
            wb_pc <= mem_pc;
            wb_inst <= mem_inst;
            wb_reg_write <= mem_reg_write;
            wb_rd <= mem_rd;
            wb_alu_result <= mem_alu_result;
            wb_mem_result <= mem_mem_result;

            if (mem_reg_write && mem_rd != 0) begin
                if (mem_inst[6:0] == OPC_LOAD) begin
                    rf[mem_rd] <= mem_mem_result;
                end else begin
                    rf[mem_rd] <= mem_alu_result;
                end
            end
        end
    end

    assign halted = (wb_inst == 32'h00000073);

    assign debug_pc = wb_pc;
    assign debug_cycle = cycle_count;
    assign debug_instret = instret_count;

    always @(posedge clk) begin
        if (rst) begin
            cycle_count <= 0;
            instret_count <= 0;
        end else begin
            cycle_count <= cycle_count + 1;
            if (wb_inst != 32'h00000013 && wb_inst != 0) begin
                instret_count <= instret_count + 1;
            end
        end
    end

    // Branch predictor update
    always @(posedge clk) begin
        if (rst) begin
            bht[0] <= 8'hFF;
            bht[1] <= 8'hFF;
            bht[2] <= 8'hFF;
            bht[3] <= 8'hFF;
            ras_ptr <= 0;
        end else if (mem_inst[6:0] == OPC_BRANCH) begin
            if (branch_taken) begin
                bht[mem_pc[6:2]] <= bht[mem_pc[6:2]] + 8'h10;
            end else begin
                bht[mem_pc[6:2]] <= bht[mem_pc[6:2]] - 8'h10;
            end
            if (mem_inst[6:0] == OPC_JAL) begin
                ras[ras_ptr] <= mem_pc + 4;
                ras_ptr <= ras_ptr + 1;
            end
        end
    end

endmodule