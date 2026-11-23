// cadena_template.v: el molde del modulo 'cadena' que escribe el generador de Verilog (Paso 10).
// El generador cambia la linea // {{BLOQUES}} por los bloques y cables del diagrama de la UI y
// pega el resultado al final de top_template.v (build_top.v). Las senales son las mismas que la
// guia daba al hueco del top, mas 'muestra', ki y kd.
//
// Lo que la cadena puede usar (formato de la cadena: 10 bits sin signo, 512 = 0 V):
//   adc_ch0..adc_ch7   las 8 entradas analogicas            spi_ch0, spi_ch1   lo que manda la Pi por SPI
//   reg_setpoint       registro 0x04 (slider de la UI)       muestra            pulso con cada muestra del ADC (10 kHz)
//   control, kp, ki, kd, gen_*, usr_p1, usr_p2: registros de 16 bits (ver docs/registros.md)
// Lo que la cadena TIENE que dar:
//   dac1_lazo, dac2_lazo   lo que sale por las salidas 1 y 2 en lazo cerrado (512 = 0 V)
//   sd_sel                 bit 0 = salida 1 por sigma-delta, bit 1 = salida 2 (0 = por el PmodDA2)
//   build_id               huella del diagrama (la UI la lee en el registro 0x1B)
// `default_nettype none: un cable mal escrito (s_filtr en vez de s_filt) es un error y no un cable
// nuevo de 1 bit que nadie maneja.
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
    // {{BLOQUES}}
endmodule
`default_nettype wire
