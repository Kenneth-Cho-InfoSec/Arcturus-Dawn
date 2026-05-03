`timescale 1ns/1ps

module soc_top (
    input  wire        clk,
    input  wire        rst,
    output wire        debug_valid,
    output wire [31:0] debug_pc
);

    wire [31:0] cluster_pc;
    wire [31:0] cluster_cycles;
    wire [31:0] cluster_instret;
    wire [3:0]  cluster_halted;
    wire        cluster_complete;

    soc_cluster cluster (
        .clk(clk),
        .rst(rst),
        .debug_pc_cluster(cluster_pc),
        .debug_cycles(cluster_cycles),
        .debug_instrets(cluster_instret),
        .debug_halted(cluster_halted),
        .simulation_complete(cluster_complete)
    );

    assign debug_valid = cluster_complete;
    assign debug_pc = cluster_pc;

endmodule