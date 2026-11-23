// signalcombiner: combinador de senales del profesor (proyecto Vivado_Artix7_2025_06_24),
// corregido. Lo usa combinar.v (bloque "combine" de la cadena). Formato Q2.16 con signo
// (65536 = 1.0, rango -2.0 .. +1.99998).
//   op: 000 = sig1, 001 = sig2, 010 = sig1 + sig2, 011 = sig1 - sig2, 100 = sig1 x sig2
// Errores comprobados simulando el original sin cambios:
// CORREGIDO (C1): la suma y la resta se hacian en 18 bits y, al pasar de +-2.0, daban la vuelta
//   (1.5 + 1.5 salia -1.0). Ahora se calculan con un bit mas y se saturan.
// CORREGIDO (C2): el producto tomaba {product[35], product[32], product[31:16]}: bien mientras
//   |sig1 x sig2| < 2.0, pero con resultados mayores salia cualquier cosa (-2.0 x -2.0 daba 0). Ahora se toma product >>> 16 y se satura.
// ADAPTADO: reset sincrono (en este proyecto no hay reset global; el top lo deja en 0).
module signalcombiner (
    input  wire signed [17:0] sig1,      // primera senal
    input  wire signed [17:0] sig2,      // segunda senal
    input  wire        [2:0]  op,        // operacion (ver arriba)
    input  wire               clk,       // reloj del sistema (12 MHz)
    input  wire               ce,        // clock enable
    input  wire               rst,       // reset sincrono
    output reg  signed [17:0] out = 18'sd0
);
    localparam signed [21:0] MAXIMO = 22'sd131071, MINIMO = -22'sd131072;

    wire signed [35:0] product    = sig1 * sig2;
    wire signed [21:0] sum        = sig1 + sig2;           // CORREGIDO (C1): sin vuelta
    wire signed [21:0] difference = sig1 - sig2;
    wire signed [21:0] prod_q216  = product >>> 16;        // CORREGIDO (C2): Q4.32 -> Q2.16 (+-4.0 cabe)

    function signed [17:0] saturar(input signed [21:0] x);
        saturar = (x > MAXIMO) ? 18'sd131071 : (x < MINIMO) ? -18'sd131072 : x[17:0];
    endfunction

    always @(posedge clk) begin
        if (rst)
            out <= 18'sd0;
        else if (ce) begin
            case (op)
                3'b000:  out <= sig1;                      // solo sig1
                3'b001:  out <= sig2;                      // solo sig2
                3'b010:  out <= saturar(sum);              // suma
                3'b011:  out <= saturar(difference);       // resta
                3'b100:  out <= saturar(prod_q216);        // producto
                default: out <= sig1;
            endcase
        end
    end
endmodule
