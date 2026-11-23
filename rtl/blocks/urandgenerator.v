// urandgenerator: ruido uniforme del profesor (proyecto Vivado_Artix7_2025_06_24), lo usa
// signalgenerator.v para la forma "ruido". LFSR de Fibonacci de 32 bits (taps B89ADA1C).
// Salida en Q2.16: 0.0 .. ~0.99998 (los 16 bits bajos del registro).
// CORREGIDO (G4): q no tenia valor inicial. Un LFSR con XOR que arranca en 0 se queda en 0 para
// siempre, y en este proyecto no hay pulso de reset: el ruido salia plano. Ahora arranca en
// 0xAAAAAAAA (el mismo valor que el original ponia con el reset).
// ADAPTADO: reset sincrono, como el resto del proyecto.
module urandgenerator (
    input  wire               clk,
    input  wire               ce,
    input  wire               rst,
    output wire signed [17:0] out
);
    reg [31:0] q = 32'haaaaaaaa;
    wire feedback = q[31] ^ q[29] ^ q[28] ^ q[27] ^ q[23] ^ q[20] ^ q[19] ^ q[17] ^
                    q[15] ^ q[14] ^ q[12] ^ q[11] ^ q[9]  ^ q[4]  ^ q[3]  ^ q[2];
    // tabla de terminos: http://www.ece.cmu.edu/~koopman/lfsr/index.html

    assign out = {2'b00, q[15:0]};                 // Q2.16: 0.0 .. ~0.99998

    always @(posedge clk)
        if (rst)     q <= 32'haaaaaaaa;
        else if (ce) q <= {q[30:0], feedback};
endmodule
