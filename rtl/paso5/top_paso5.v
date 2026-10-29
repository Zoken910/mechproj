// Top minimo para probar el Paso 5 en la placa (Levi), antes de tener el top completo.
// LED 0 = control bit 0 (salidas habilitadas), LED 1 = control bit 1 (lazo cerrado),
// igual que en el top final. Las entradas que aun no existen van a valores fijos.
module top (
    input  wire       clk,           // 12 MHz, L17
    input  wire       uart_rx_pin,   // J17: entra a la FPGA
    output wire       uart_tx_pin,   // J18: sale de la FPGA
    output wire [1:0] led
);
    wire [7:0]  rx_data, tx_data;
    wire        rx_valid, tx_start, tx_busy;
    wire [15:0] control;

    uart_rx u_rx (.clk(clk), .rx(uart_rx_pin), .data(rx_data), .valid(rx_valid));
    uart_tx u_tx (.clk(clk), .start(tx_start), .data(tx_data), .tx(uart_tx_pin), .busy(tx_busy));
    regs_uart u_reg (.clk(clk), .rx_data(rx_data), .rx_valid(rx_valid),
                     .tx_data(tx_data), .tx_start(tx_start), .tx_busy(tx_busy),
                     .adc({8{16'h0000}}), .dac1_actual(12'd0), .dac2_actual(12'd0),
                     .salidas_sd(2'b00), .build_id(16'h0005),   // 0x0005 = "paso 5"
                     .spi_in0(16'd0), .spi_in1(16'd0),
                     .control(control), .dac1_manual(), .dac2_manual(), .setpoint(), .kp(),
                     .gen_forma(), .gen_freq(), .gen_amp(), .gen_offset(), .usr_p1(), .usr_p2());

    assign led[0] = control[0];
    assign led[1] = control[1];
endmodule
