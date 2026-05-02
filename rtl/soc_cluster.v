`timescale 1ns/1ps

module soc_cluster #(
    parameter IMEM_WORDS = 128,
    parameter DMEM_BYTES = 512,
    parameter NUM_CORES = 4
) (
    input  wire        clk,
    input  wire        rst,
    output wire [31:0] debug_pc_cluster,
    output wire [31:0] debug_cycles,
    output wire [31:0] debug_instrets,
    output wire [3:0]  debug_halted,
    output wire        simulation_complete
);

    wire [31:0] core0_pc, core1_pc, core2_pc, core3_pc;
    wire [31:0] core0_cycles, core1_cycles, core2_cycles, core3_cycles;
    wire [31:0] core0_instret, core1_instret, core2_instret, core3_instret;
    wire [3:0] core_halted;

    reg [31:0] global_cycles;
    reg         all_halted;
    reg [3:0]  halt_count;

    assign debug_pc_cluster = core0_pc;
    assign debug_cycles = global_cycles;
    assign debug_instrets = core0_instret + core1_instret + core2_instret + core3_instret;
    assign debug_halted = core_halted;
    assign simulation_complete = all_halted;

    cpu_core #(
        .IMEM_WORDS(IMEM_WORDS),
        .DMEM_BYTES(DMEM_BYTES),
        .CORE_ID(0)
    ) core0 (
        .clk(clk),
        .rst(rst),
        .debug_pc(core0_pc),
        .debug_cycle(core0_cycles),
        .debug_instret(core0_instret),
        .halted(core_halted[0]),
        .ipi_trigger(1'b0)
    );

    cpu_core #(
        .IMEM_WORDS(IMEM_WORDS),
        .DMEM_BYTES(DMEM_BYTES),
        .CORE_ID(1)
    ) core1 (
        .clk(clk),
        .rst(rst),
        .debug_pc(core1_pc),
        .debug_cycle(core1_cycles),
        .debug_instret(core1_instret),
        .halted(core_halted[1]),
        .ipi_trigger(1'b0)
    );

    cpu_core #(
        .IMEM_WORDS(IMEM_WORDS),
        .DMEM_BYTES(DMEM_BYTES),
        .CORE_ID(2)
    ) core2 (
        .clk(clk),
        .rst(rst),
        .debug_pc(core2_pc),
        .debug_cycle(core2_cycles),
        .debug_instret(core2_instret),
        .halted(core_halted[2]),
        .ipi_trigger(1'b0)
    );

    cpu_core #(
        .IMEM_WORDS(IMEM_WORDS),
        .DMEM_BYTES(DMEM_BYTES),
        .CORE_ID(3)
    ) core3 (
        .clk(clk),
        .rst(rst),
        .debug_pc(core3_pc),
        .debug_cycle(core3_cycles),
        .debug_instret(core3_instret),
        .halted(core_halted[3]),
        .ipi_trigger(1'b0)
    );

    always @(posedge clk) begin
        if (rst) begin
            global_cycles <= 32'h00000000;
            all_halted <= 1'b0;
            halt_count <= 4'd0;
        end else begin
            global_cycles <= global_cycles + 32'd1;

            halt_count <= core_halted;
            if (core_halted == 4'b1111) begin
                all_halted <= 1'b1;
            end
        end
    end
endmodule