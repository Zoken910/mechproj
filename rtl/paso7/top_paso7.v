// Top para probar el Paso 7 en la placa (Levi): UART + banco de registros + ADC + DAC.
// Es el top final sin cadena generada y sin SPI: las salidas solo funcionan en modo manual.
//   CONTROL (0x01) bit 0 = salidas habilitadas, DAC1_MANUAL (0x02) y DAC2_MANUAL (0x03) = 0..4095
//   0x18 / 0x19 devuelven lo que realmente sale por cada DAC; 0x1B = 0x0007 ("paso 7")
// Con un cable de DAC1 a la entrada V1 del AD7606 se puede cerrar la prueba: lo que se escribe
// en 0x02 se vuelve a leer en 0x10 (ver pi/prueba_dac.py --lazo).
// Compilar (Levi): rtl/paso7/top_paso7.v rtl/blocks/uart_rx.v rtl/blocks/uart_tx.v
//                  rtl/blocks/regs_uart.v rtl/blocks/adc_ad7606.v rtl/blocks/dac_pmodda2.v
//                  con rtl/paso7/cmod_paso7.xdc
module top (
    input  wire       clk,                                       // 12 MHz, L17
    input  wire       uart_rx_pin, output wire uart_tx_pin,      // UART por el USB (J17, J18)
    output wire       adc_convst, adc_reset, adc_cs_n, adc_sclk, // AD7606 en el Pmod JA
    input  wire       adc_douta, adc_doutb, adc_busy,
    output wire       dac_sync_n, dac_sclk, dac_dina, dac_dinb,  // PmodDA2 en los pines DIP 1 a 4
    output wire [1:0] led
);
    wire [7:0]   rx_data, tx_data;
    wire         rx_valid, tx_start, tx_busy;
    wire [15:0]  control, dac1_manual, dac2_manual;
    wire [127:0] adc;

    // igual que en top_template.v, con la cadena vacia (lazo = 0)
    wire [11:0] dac1_final = !control[0] ? 12'd0 : (control[1] ? 12'd0 : dac1_manual[11:0]);
    wire [11:0] dac2_final = !control[0] ? 12'd0 : (control[1] ? 12'd0 : dac2_manual[11:0]);

    uart_rx u_rx (.clk(clk), .rx(uart_rx_pin), .data(rx_data), .valid(rx_valid));
    uart_tx u_tx (.clk(clk), .start(tx_start), .data(tx_data), .tx(uart_tx_pin), .busy(tx_busy));
    regs_uart u_reg (.clk(clk), .rx_data(rx_data), .rx_valid(rx_valid),
                     .tx_data(tx_data), .tx_start(tx_start), .tx_busy(tx_busy),
                     .adc(adc), .dac1_actual(dac1_final), .dac2_actual(dac2_final),
                     .salidas_sd(2'b00), .build_id(16'h0007),
                     .spi_in0(16'd512), .spi_in1(16'd512),
                     .control(control), .dac1_manual(dac1_manual), .dac2_manual(dac2_manual),
                     .setpoint(), .kp(), .gen_forma(), .gen_freq(), .gen_amp(), .gen_offset(),
                     .usr_p1(), .usr_p2());

    adc_ad7606 u_adc (.clk(clk), .convst(adc_convst), .reset(adc_reset), .cs_n(adc_cs_n),
                      .sclk(adc_sclk), .douta(adc_douta), .doutb(adc_doutb), .busy(adc_busy),
                      .valores(adc), .nueva());

    dac_pmodda2 u_dac (.clk(clk), .valor_a(dac1_final), .valor_b(dac2_final),
                       .sync_n(dac_sync_n), .sclk(dac_sclk), .dina(dac_dina), .dinb(dac_dinb));

    assign led[0] = control[0];      // LED 0 = salidas habilitadas
    assign led[1] = control[1];      // LED 1 = lazo cerrado (aqui no hace nada)
endmodule
