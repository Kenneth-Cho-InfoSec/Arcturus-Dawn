`timescale 1ns/1ps

module tb_soc_cluster;
    reg clk = 1'b0;
    reg rst = 1'b1;
    integer cycle = 0;
    integer timeout = 500;

    wire [31:0] debug_pc_cluster;
    wire [31:0] debug_cycles;
    wire [31:0] debug_instrets;
    wire [3:0]  debug_halted;
    wire        simulation_complete;

    always #5 clk = ~clk;

    soc_cluster #(
        .NUM_CORES(4)
    ) dut (
        .clk(clk),
        .rst(rst),
        .debug_pc_cluster(debug_pc_cluster),
        .debug_cycles(debug_cycles),
        .debug_instrets(debug_instrets),
        .debug_halted(debug_halted),
        .simulation_complete(simulation_complete)
    );

    initial begin
        $dumpfile("build/soc_cluster.vcd");
        $dumpvars(0, tb_soc_cluster);
        repeat (3) @(posedge clk);
        rst <= 1'b0;
    end

    always @(posedge clk) begin
        if (!rst) begin
            cycle <= cycle + 1;

            if (cycle % 10 == 0)
                $display("cycle=%0d pc=%08h halted=%b", cycle, debug_pc_cluster, debug_halted);

            if (debug_cycles > 100 && debug_instrets > 0) begin
                $display("PASS: 4-core cluster boot and execution");
                $display("INFO: total_instructions=%0d cycles=%0d", debug_instrets, debug_cycles);
                $finish;
            end

            if (cycle > timeout) begin
                $display("FAIL: timeout after %0d cycles", timeout);
                $finish;
            end
        end
    end
endmodule