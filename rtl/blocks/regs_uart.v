// regs_uart: envoltorio de compatibilidad = uart_parser.v + registros.v (desde el 17.11.2026).
// El profe pidio el parser del UART y el banco de registros como bloques separados; el top final
// (top_template.v) ya los usa asi. Este modulo junta los dos con los mismos puertos de siempre
// para que top_paso5.v, top_paso7.v y sim/tb_uart.v sigan funcionando sin cambios.
// Mismo protocolo y mismas direcciones que antes; nuevos: ki (0x0C) y kd (0x0D).
// Al compilar hay que pasar tambien rtl/blocks/uart_parser.v y rtl/blocks/registros.v.
module regs_uart (
    input  wire         clk,
    input  wire [7:0]   rx_data,
    input  wire         rx_valid,
    output wire [7:0]   tx_data,
    output wire         tx_start,
    input  wire         tx_busy,
    input  wire [127:0] adc,                 // 8 canales x 16 bits con signo (AD7606)
    input  wire [11:0]  dac1_actual, dac2_actual,
    input  wire [1:0]   salidas_sd,          // que canal sale por sigma-delta (lo fija el generador)
    input  wire [15:0]  build_id,            // huella del diagrama cargado (lo fija el generador)
    input  wire [15:0]  spi_in0, spi_in1,    // ultimos valores que mando la Pi por SPI
    output wire [15:0]  control, dac1_manual, dac2_manual, setpoint, kp,
    output wire [15:0]  gen_forma, gen_freq, gen_amp, gen_offset, usr_p1, usr_p2,
    output wire [15:0]  ki, kd
);
    wire        escribir;
    wire [7:0]  dir;
    wire [15:0] dato_w, dato_r;

    uart_parser u_parser (.clk(clk), .rx_data(rx_data), .rx_valid(rx_valid),
                          .tx_data(tx_data), .tx_start(tx_start), .tx_busy(tx_busy),
                          .escribir(escribir), .dir(dir), .dato_w(dato_w), .dato_r(dato_r));

    registros u_registros (.clk(clk), .escribir(escribir), .dir(dir), .dato_w(dato_w), .dato_r(dato_r),
                           .adc(adc), .dac1_actual(dac1_actual), .dac2_actual(dac2_actual),
                           .salidas_sd(salidas_sd), .build_id(build_id),
                           .spi_in0(spi_in0), .spi_in1(spi_in1),
                           .control(control), .dac1_manual(dac1_manual), .dac2_manual(dac2_manual),
                           .setpoint(setpoint), .kp(kp),
                           .gen_forma(gen_forma), .gen_freq(gen_freq), .gen_amp(gen_amp),
                           .gen_offset(gen_offset), .usr_p1(usr_p1), .usr_p2(usr_p2),
                           .ki(ki), .kd(kd));
endmodule
