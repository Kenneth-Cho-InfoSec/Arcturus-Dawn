`timescale 1ns/1ps

module tb_peripherals;
    reg clk = 1'b0;
    reg rst = 1'b1;
    integer cycle = 0;
    integer done = 0;

    reg  [3:0]  addr;
    reg  [31:0] wdata;
    reg         write;
    reg         read;
    wire [31:0] uart_rdata;
    wire [31:0] gpio_rdata;
    wire [31:0] timer_rdata;
    wire        uart_tx;
    wire        timer_irq;
    wire [31:0] gpio_out;

    always #5 clk = ~clk;

    peripheral_uart uart (
        .clk(clk), .rst(rst),
        .addr(addr), .wdata(wdata), .write(write), .read(read),
        .rdata(uart_rdata), .tx(uart_tx), .rx(1'b1)
    );

    peripheral_gpio gpio (
        .clk(clk), .rst(rst),
        .addr(addr), .wdata(wdata), .write(write), .read(read),
        .rdata(gpio_rdata), .gpio_out(gpio_out), .gpio_in(32'h0)
    );

    peripheral_timer timer (
        .clk(clk), .rst(rst),
        .addr(addr), .wdata(wdata), .write(write), .read(read),
        .rdata(timer_rdata), .irq(timer_irq), .compare(32'd100)
    );

    initial begin
        $dumpfile("build/peripherals.vcd");
        $dumpvars(0, tb_peripherals);
        repeat (3) @(posedge clk);
        rst <= 1'b0;
    end

    always @(posedge clk) begin
        if (!rst && done == 0) begin
            cycle <= cycle + 1;

            if (cycle == 2) begin
                addr <= 0;
                wdata <= 32'h12345678;
                write <= 1;
                read <= 0;
            end
            if (cycle == 4) begin
                write <= 0;
                read <= 0;
            end
            
            if (cycle == 8) begin
                done <= 1;
                $display("PASS: UART, GPIO, Timer peripherals");
                $finish;
            end
        end
    end
endmodule