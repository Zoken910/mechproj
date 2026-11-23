// cadena_paso9.v: la cadena de la demo de velocidad, escrita a mano (Paso 9), para probar el
// lazo cerrado en la placa antes de tener el generador del Paso 10. Es lo que el generador va a
// sacar de ejemplos/velocidad.json con el bloque PID en lugar del control_p:
//
//   setpoint (0x04) ----------------------------> PID.setpoint
//   ADC canal 0 (sensor de velocidad) -> filtro_media (8 muestras) -> PID.medida
//   PID -> salida 1 (PmodDA2) -> driver del motor
//   filtro -> salida 2 (PmodDA2) -> osciloscopio (la velocidad filtrada)
//
// Compilar (Levi): rtl/top_template.v + este archivo + los bloques; pines rtl/cmod_a7.xdc
// (ver build.sh o "python hacer_bit.py paso9"). La huella (registro 0x1B) es 0x0009 = "paso 9".
// Uso desde la Pi: KP (0x05), KI (0x0C), KD (0x0D), SETPOINT (0x04), CONTROL (0x01) = 3 cierra el lazo.
`default_nettype none
module cadena (
    input  wire        clk,
    input  wire        muestra,
    input  wire [9:0]  adc_ch0, adc_ch1, adc_ch2, adc_ch3, adc_ch4, adc_ch5, adc_ch6, adc_ch7,
    input  wire [9:0]  reg_setpoint,
    input  wire [9:0]  spi_ch0, spi_ch1,
    input  wire [15:0] control, kp, ki, kd,
    input  wire [15:0] gen_forma, gen_freq, gen_amp, gen_offset,
    input  wire [15:0] usr_p1, usr_p2,
    output wire [9:0]  dac1_lazo, dac2_lazo,
    output wire [1:0]  sd_sel,
    output wire [15:0] build_id
);
    wire [9:0] s_ref, s_vel, s_filt, s_ctrl;
    assign s_ref = reg_setpoint;                                              // ref:  setpoint_reg
    assign s_vel = adc_ch0;                                                   // vel:  adc_in, canal 0
    filtro_media #(.LOG2N(3)) u_filt (.clk(clk), .muestra(muestra),           // filt: filtro_media
                                      .x(s_vel), .y(s_filt));
    control_pid u_ctrl (.clk(clk), .enable(control[0] & control[1]),         // ctrl: PID
                        .muestra(muestra), .setpoint(s_ref), .medida(s_filt),
                        .kp(kp), .ki(ki), .kd(kd), .y(s_ctrl));
    assign dac1_lazo = s_ctrl;                                                // mot:  salida 1
    assign dac2_lazo = s_filt;                                                // mon:  salida 2
    assign sd_sel    = 2'b00;                                                 // las dos por el PmodDA2
    assign build_id  = 16'h0009;                                              // "paso 9"
endmodule
`default_nettype wire
