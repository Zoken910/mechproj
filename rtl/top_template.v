// top_template.v: el top final del sistema (Paso 9.3), para la tabla de pines rtl/cmod_a7.xdc.
// Bloques que pidio el profe (reunion del 17.11.2026):
//   register    -> rtl/blocks/registros.v     ajustes de la Pi (banco de registros)
//   uart parser -> rtl/blocks/uart_parser.v   protocolo 'W' / 'R' por el UART
//   PID         -> rtl/blocks/control_pid.v   \
//   combine     -> rtl/blocks/combinar.v       > bloques de la cadena que dibuja el usuario
//   signal      -> rtl/blocks/sig_gen.v       /
//
// Cambio respecto a la guia: la cadena que dibuja el usuario ya no se pega en un hueco de este
// archivo, vive en su propio modulo 'cadena' (mismas senales que antes). Asi este top esta completo,
// se puede simular y sintetizar sin el generador, y la cadena solo ve lo que le corresponde.
//   - El generador (Paso 10) toma rtl/cadena_template.v, llena su hueco // {{BLOQUES}} y pega el
//     modulo 'cadena' al final de este archivo (build_top.v = top_template.v + cadena).
//   - Para probar a mano: rtl/paso9/cadena_paso9.v (la demo de velocidad con el PID).
// Ya no existe dir_lazo: el PID saca un valor con signo alrededor de 512 (512 = 0 V).
`default_nettype none
module top (
    input  wire       clk,                                            // 12 MHz, L17
    input  wire       uart_rx_pin, output wire uart_tx_pin,           // ajustes (registros), ida y vuelta
    output wire       adc_convst, adc_reset, adc_cs_n, adc_sclk,      // ADC AD7606 (8 entradas)
    input  wire       adc_douta, adc_doutb, adc_busy,
    output wire       dac_sync_n, dac_sclk, dac_dina, dac_dinb,       // DAC PmodDA2 (salidas 1 y 2)
    output wire [1:0] sd_out,                                         // sigma-delta (salidas 1 y 2)
    input  wire       pi_sck, pi_cs_n, pi_mosi, output wire pi_miso,  // SPI rapido con la Pi
    output wire [1:0] led
);
    // ---- ajustes desde la Pi: UART -> uart parser -> register ----
    wire [7:0]   rx_data, tx_data;
    wire         rx_valid, tx_start, tx_busy;
    wire         escribir;
    wire [7:0]   dir;
    wire [15:0]  dato_w, dato_r;
    wire [15:0]  control, dac1_manual, dac2_manual, setpoint, kp, ki, kd;
    wire [15:0]  gen_forma, gen_freq, gen_amp, gen_offset, usr_p1, usr_p2;
    wire [15:0]  spi_in0, spi_in1;
    wire [127:0] adc;
    wire         adc_nueva;
    wire [9:0]   dac1_lazo, dac2_lazo;          // los escribe la cadena
    wire [1:0]   sd_sel;                        // bit 0 = salida 1 por sigma-delta, bit 1 = salida 2
    wire [15:0]  build_id;                      // huella del diagrama (la pone la cadena)

    // salidas: apagadas (CONTROL bit 0 = 0), lazo cerrado (bit 1 = 1) o modo manual
    // OJO: 0 = 0 V a la salida del DAC. Con la etapa de op-amps de +-5 V eso es -5 V en el SMA:
    // ver docs/paso9.md (decision pendiente con Persona 1 antes de conectar el motor).
    wire [11:0] dac1_final = !control[0] ? 12'd0 : (control[1] ? {dac1_lazo, 2'b00} : dac1_manual[11:0]);
    wire [11:0] dac2_final = !control[0] ? 12'd0 : (control[1] ? {dac2_lazo, 2'b00} : dac2_manual[11:0]);

    uart_rx u_rx (.clk(clk), .rx(uart_rx_pin), .data(rx_data), .valid(rx_valid));
    uart_tx u_tx (.clk(clk), .start(tx_start), .data(tx_data), .tx(uart_tx_pin), .busy(tx_busy));
    uart_parser u_parser (.clk(clk), .rx_data(rx_data), .rx_valid(rx_valid),
                          .tx_data(tx_data), .tx_start(tx_start), .tx_busy(tx_busy),
                          .escribir(escribir), .dir(dir), .dato_w(dato_w), .dato_r(dato_r));
    registros u_registros (.clk(clk), .escribir(escribir), .dir(dir), .dato_w(dato_w), .dato_r(dato_r),
                           .adc(adc), .dac1_actual(dac1_final), .dac2_actual(dac2_final),
                           .salidas_sd(sd_sel), .build_id(build_id),
                           .spi_in0(spi_in0), .spi_in1(spi_in1),
                           .control(control), .dac1_manual(dac1_manual), .dac2_manual(dac2_manual),
                           .setpoint(setpoint), .kp(kp), .ki(ki), .kd(kd),
                           .gen_forma(gen_forma), .gen_freq(gen_freq), .gen_amp(gen_amp),
                           .gen_offset(gen_offset), .usr_p1(usr_p1), .usr_p2(usr_p2));

    // ---- entradas analogicas (8 x SMA -> AD7606) ----
    adc_ad7606 u_adc (.clk(clk), .convst(adc_convst), .reset(adc_reset), .cs_n(adc_cs_n),
                      .sclk(adc_sclk), .douta(adc_douta), .doutb(adc_doutb), .busy(adc_busy),
                      .valores(adc), .nueva(adc_nueva));

    // 16 bits con signo -> 10 bits sin signo para la cadena (0 = -rango, 512 = 0 V, 1023 = +rango)
    wire [9:0] adc_ch0 = adc[ 15:  6] ^ 10'h200, adc_ch1 = adc[ 31: 22] ^ 10'h200,
               adc_ch2 = adc[ 47: 38] ^ 10'h200, adc_ch3 = adc[ 63: 54] ^ 10'h200,
               adc_ch4 = adc[ 79: 70] ^ 10'h200, adc_ch5 = adc[ 95: 86] ^ 10'h200,
               adc_ch6 = adc[111:102] ^ 10'h200, adc_ch7 = adc[127:118] ^ 10'h200;

    // ---- la cadena de procesamiento que dibujo el usuario (generada desde la UI) ----
    cadena u_cadena (.clk(clk), .muestra(adc_nueva),
                     .adc_ch0(adc_ch0), .adc_ch1(adc_ch1), .adc_ch2(adc_ch2), .adc_ch3(adc_ch3),
                     .adc_ch4(adc_ch4), .adc_ch5(adc_ch5), .adc_ch6(adc_ch6), .adc_ch7(adc_ch7),
                     .reg_setpoint(setpoint[9:0]), .spi_ch0(spi_in0[9:0]), .spi_ch1(spi_in1[9:0]),
                     .control(control), .kp(kp), .ki(ki), .kd(kd),
                     .gen_forma(gen_forma), .gen_freq(gen_freq), .gen_amp(gen_amp), .gen_offset(gen_offset),
                     .usr_p1(usr_p1), .usr_p2(usr_p2),
                     .dac1_lazo(dac1_lazo), .dac2_lazo(dac2_lazo), .sd_sel(sd_sel), .build_id(build_id));

    // ---- salidas analogicas: cada canal sale por el PmodDA2 o por sigma-delta, nunca por los dos ----
    dac_pmodda2 u_dac (.clk(clk), .valor_a(sd_sel[0] ? 12'd0 : dac1_final),
                       .valor_b(sd_sel[1] ? 12'd0 : dac2_final),
                       .sync_n(dac_sync_n), .sclk(dac_sclk), .dina(dac_dina), .dinb(dac_dinb));
    sigma_delta u_sd1 (.clk(clk), .x(sd_sel[0] ? dac1_final : 12'd0), .salida(sd_out[0]));
    sigma_delta u_sd2 (.clk(clk), .x(sd_sel[1] ? dac2_final : 12'd0), .salida(sd_out[1]));

    // ---- datos rapidos con la Pi (SPI): A5A5, contador, 8 canales, DAC1, DAC2 / de vuelta: 2 valores ----
    reg [15:0] contador = 0;
    always @(posedge clk) if (adc_nueva) contador <= contador + 1;
    spi_stream #(.PALABRAS(12)) u_spi (.clk(clk), .sck(pi_sck), .cs_n(pi_cs_n), .mosi(pi_mosi),
        .miso(pi_miso), .datos({4'd0, dac2_final, 4'd0, dac1_final, adc, contador, 16'hA5A5}),
        .rx0(spi_in0), .rx1(spi_in1));

    assign led[0] = control[0];                 // LED 0 = salidas habilitadas
    assign led[1] = control[1];                 // LED 1 = lazo cerrado
endmodule
`default_nettype wire
