// top.v: LED parpadeante (Paso 3), el "hola mundo" de la CMOD-A7.
// Con BIT = 23 y reloj de 12 MHz, cada LED cambia cada 2^23 / 12e6 = 0.70 s.
// En simulacion se usa BIT = 3 para que cambie cada 8 ciclos.
module top #(parameter BIT = 23) (
    input  wire       clk,   // reloj de 12 MHz de la CMOD-A7 (pin L17)
    output wire [1:0] led    // LEDs de la placa (A17, C16), activos en alto
);
    reg [BIT:0] contador = 0;          // sin reset global: el valor inicial lo pone el bitstream

    always @(posedge clk)
        contador <= contador + 1;      // cuenta 12 millones de veces por segundo

    assign led[0] =  contador[BIT];    // cambia cada 2^BIT ciclos
    assign led[1] = ~contador[BIT];    // siempre al reves que led[0]
endmodule
