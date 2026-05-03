`timescale 1ns/1ps

module peripheral_uart (
    input  wire        clk,
    input  wire        rst,
    input  wire [3:0]  addr,
    input  wire [31:0] wdata,
    input  wire        write,
    input  wire        read,
    output reg  [31:0] rdata,
    output reg         tx,
    input          rx
);

    reg [7:0] tx_data;
    reg [7:0] rx_data;
    reg [31:0] baud_div;
    reg [31:0] control;
    reg [31:0] status;
    reg [7:0] tx_fifo [0:3];
    reg [1:0] tx_head;
    reg [1:0] tx_tail;
    reg [3:0] tx_count;

    localparam ADDR_DATA = 4'd0;
    localparam ADDR_STATUS = 4'd1;
    localparam ADDR_CONTROL = 4'd2;
    localparam ADDR_BAUD = 4'd3;

    localparam STATUS_TX_READY = 0;
    localparam STATUS_RX_READY = 1;

    always @(posedge clk) begin
        if (rst) begin
            tx_data <= 0;
            rx_data <= 0;
            baud_div <= 32'd867;
            control <= 0;
            status <= 32'h00000001;
            tx <= 1;
            tx_head <= 0;
            tx_tail <= 0;
            tx_count <= 0;
        end else begin
            status[STATUS_TX_READY] <= (tx_count < 4);
            status[STATUS_RX_READY] <= 1;
            
            if (write) begin
                case (addr)
                    ADDR_DATA: begin
                        tx_fifo[tx_head] <= wdata[7:0];
                        tx_head <= tx_head + 1;
                        tx_count <= tx_count + 1;
                    end
                    ADDR_CONTROL: control <= wdata;
                    ADDR_BAUD: baud_div <= wdata;
                endcase
            end
            
            if (read) begin
                case (addr)
                    ADDR_DATA: rdata <= {24'h0, rx_data};
                    ADDR_STATUS: rdata <= status;
                    ADDR_CONTROL: rdata <= control;
                    ADDR_BAUD: rdata <= baud_div;
                    default: rdata <= 0;
                endcase
            end
            
            if (tx_count > 0) begin
                tx <= 0;
                tx_data <= tx_fifo[tx_tail];
                tx_tail <= tx_tail + 1;
                tx_count <= tx_count - 1;
            end else begin
                tx <= 1;
            end
        end
    end
endmodule

module peripheral_gpio (
    input  wire        clk,
    input  wire        rst,
    input  wire [3:0]  addr,
    input  wire [31:0] wdata,
    input  wire        write,
    input  wire        read,
    output reg  [31:0] rdata,
    output reg  [31:0] gpio_out,
    input  [31:0]  gpio_in
);

    reg [31:0] gpio_dir;
    reg [31:0] gpio_data;

    always @(posedge clk) begin
        if (rst) begin
            gpio_dir <= 32'hFFFFFFFF;
            gpio_data <= 0;
        end else begin
            if (write) begin
                case (addr)
                    4'd0: gpio_data <= wdata;
                    4'd1: gpio_dir <= wdata;
                endcase
            end
            
            if (read) begin
                case (addr)
                    4'd0: rdata <= gpio_data;
                    4'd1: rdata <= gpio_dir;
                    default: rdata <= 0;
                endcase
            end
        end
        
        gpio_out <= gpio_data;
        rdata <= gpio_data;
    end
endmodule

module peripheral_timer (
    input  wire        clk,
    input  wire        rst,
    input  wire [3:0]  addr,
    input  wire [31:0] wdata,
    input  wire        write,
    input  wire        read,
    output reg  [31:0] rdata,
    output reg         irq,
    input  [31:0]  compare
);

    reg [31:0] counter;
    reg [31:0] reload;
    reg [31:0] control;
    reg [31:0] current;

    always @(posedge clk) begin
        if (rst) begin
            counter <= 0;
            reload <= 32'h10000000;
            control <= 0;
            irq <= 0;
        end else begin
            if (control[0]) begin
                counter <= counter + 1;
                current <= counter + 1;
            end else begin
                counter <= 0;
            end
            
            if (compare > 0 && counter >= compare) begin
                irq <= 1;
                if (control[1]) counter <= reload;
            end else begin
                irq <= 0;
            end
            
            if (write) begin
                case (addr)
                    4'd0: begin
                        control <= wdata;
                        if (wdata[0]) counter <= 0;
                    end
                    4'd1: reload <= wdata;
                    4'd2: begin end
                    4'd3: begin end
                endcase
            end
            
            if (read) begin
                case (addr)
                    4'd0: rdata <= control;
                    4'd1: rdata <= reload;
                    4'd2: rdata <= counter;
                    4'd3: rdata <= compare;
                    default: rdata <= 0;
                endcase
            end
        end
    end
endmodule