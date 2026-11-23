// Modelo de simulacion del AD7606 en modo serie, como modulo para reusar (lo usa tb_paso9.v).
// Mismo supuesto que tb_adc.v y tb_io.v (revisarlo contra el datasheet):
//   - con la subida de CONVST copia los 8 canales; BUSY sube 40 ns despues y dura 4 us;
//   - al bajar CS pone el MSB del canal 0 (DOUTA) y del canal 4 (DOUTB);
//   - cambia al bit siguiente 10 ns despues de cada SUBIDA de SCLK (la FPGA lee antes de la subida);
//   - DOUTA saca V1..V4 y DOUTB V5..V8, 16 bits cada uno, MSB primero.
`timescale 1ns/1ps
module ad7606_modelo (
    input  wire         convst,
    input  wire         cs_n,
    input  wire         sclk,
    input  wire [127:0] canales,          // canal 0 en [15:0] ... canal 7 en [127:112], con signo
    output reg          busy = 0,
    output wire         douta,
    output wire         doutb
);
    reg [127:0] copia = 0;
    reg [63:0]  sha = 0, shb = 0;
    integer     conversiones = 0;
    assign douta = sha[63];
    assign doutb = shb[63];

    always @(posedge convst) begin
        copia = canales;
        conversiones = conversiones + 1;
        #40 busy = 1;
        #4000 busy = 0;
    end
    always @(negedge cs_n) begin
        sha = {copia[15:0],  copia[31:16],  copia[47:32],   copia[63:48]};
        shb = {copia[79:64], copia[95:80],  copia[111:96],  copia[127:112]};
    end
    always @(posedge sclk) if (!cs_n) begin #10 sha = sha << 1; shb = shb << 1; end
endmodule
