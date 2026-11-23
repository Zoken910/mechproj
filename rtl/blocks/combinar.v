// combinar: bloque "combine" de la cadena (Paso 9B.2, pedido por el profe el 27.10 y el 17.11).
// Por dentro usa el combinador del profesor (signalcombiner.v, corregido) y lo pasa al formato de
// la cadena: 10 bits sin signo, 512 = 0 V. La operacion se fija al compilar con OP, con los mismos
// codigos que el modulo del profe (en el JSON se escribe el nombre):
//   OP = 2 suma (a + b)   3 resta (a - b)   4 producto (a x b / 512)   0 solo a   1 solo b
// Ejemplo: el error del lazo es resta(setpoint, medida). El resultado se recorta a 0..1023.
module combinar #(parameter OP = 2) (
    input  wire       clk,
    input  wire [9:0] a,
    input  wire [9:0] b,
    output reg  [9:0] y = 10'd512
);
    // cadena -> Q2.16: 512 = 0, 1023 = +511/512, 0 = -1.0 (x 128)
    wire signed [10:0] da = $signed({1'b0, a}) - 11'sd512;
    wire signed [10:0] db = $signed({1'b0, b}) - 11'sd512;
    wire signed [17:0] sa = da <<< 7;
    wire signed [17:0] sb = db <<< 7;
    localparam [2:0] CODIGO = OP;
    wire signed [17:0] r;
    signalcombiner u_profe (.sig1(sa), .sig2(sb), .op(CODIGO), .clk(clk), .ce(1'b1), .rst(1'b0), .out(r));

    // Q2.16 -> cadena (/128) y recorte; el producto queda a x b / 512 en unidades de la cadena
    wire signed [18:0] v = 19'sd512 + (r >>> 7);
    always @(posedge clk)
        if      (v < 0)    y <= 10'd0;
        else if (v > 1023) y <= 10'd1023;
        else               y <= v[9:0];
endmodule
