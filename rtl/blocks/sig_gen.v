// sig_gen: bloque "signal" de la cadena (Paso 9B.1, pedido por el profe el 27.10 y el 17.11).
// Por dentro usa el generador del profesor (signalgenerator.v, corregido) y lo pasa al formato
// de la cadena: 10 bits sin signo, 512 = 0 V. Se ajusta en vivo con los registros 0x06 a 0x09:
//   forma  (0x06): 0 seno, 1 cuadrada, 2 triangulo, 3 sierra, 4 ruido (nuevo)
//   inc    (0x07): frecuencia = inc x 12 MHz / 2^24 = inc x 0.715 Hz (14 -> 10 Hz, 1398 -> 1 kHz)
//   amp    (0x08): 0..512 (512 = de 0 a 1023, todo el rango); hasta 1023 recorta la forma
//   offset (0x09): 0..1023 (512 = centrado en 0 V)
// y = offset + amp x w, con w entre -1 y +1, recortada a 0..1023.
// Los puertos son los de la guia (salvo 'forma', que ahora tiene 3 bits por el ruido): el generador
// de Verilog del Paso 10 lo instancia igual.
module sig_gen (
    input  wire        clk,
    input  wire [2:0]  forma,
    input  wire [15:0] inc,
    input  wire [9:0]  amp,
    input  wire [9:0]  offset,
    output reg  [9:0]  y = 10'd512
);
    // numeros de la UI -> codigos del modulo del profe (0 cuadrada, 1 triangulo, 2 sierra, 4 seno, 5 ruido)
    // (con assign y no con always @(*): asi en simulacion tambien vale desde el tiempo 0)
    wire [2:0] tipo = (forma == 3'd1) ? 3'd0 :      // cuadrada
                      (forma == 3'd2) ? 3'd1 :      // triangulo
                      (forma == 3'd3) ? 3'd2 :      // sierra
                      (forma == 3'd4) ? 3'd5 :      // ruido
                                        3'd4;       // 0 (y lo que no exista): seno

    // el modulo del profe da (forma - 0.5) x escala en Q2.16: con escala = amp x 128 (512 -> 1.0)
    // sale +-0.5 = +-32768, que en la cadena es +-512: dividir entre 64
    wire signed [17:0] escala = {1'b0, amp, 7'd0};
    wire signed [17:0] s;
    signalgenerator u_profe (.clock_enable(1'b1), .signal_type(tipo), .offset(18'sd0), .rst(1'b0),
                             .clk(clk), .increment_per_cycle({2'b00, inc}), .signal_scale(escala),
                             .signal_out(s));

    wire signed [18:0] v = $signed({9'd0, offset}) + (s >>> 6);
    always @(posedge clk)
        if      (v < 0)    y <= 10'd0;                   // saturacion
        else if (v > 1023) y <= 10'd1023;
        else               y <= v[9:0];
endmodule
