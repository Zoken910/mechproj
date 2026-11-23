// Prueba de filtro_media.v (Paso 9.2).
// Correr:
//   iverilog -g2012 -o sim_filtro sim/tb_filtro.v rtl/blocks/filtro_media.v && vvp sim_filtro
// Listo cuando: imprime "FILTRO OK" (ninguna linea "FILTRO MAL").
// Revisa: arranca en 512 (0 V), solo cambia con los pulsos de 'muestra', el escalon de 512 a 800
// sube en 8 muestras (exacto a la mitad), el promedio de valores distintos y LOG2N = 1.
`timescale 1ns/1ps
module tb_filtro;
    reg clk = 0; always #41.667 clk = ~clk;          // 12 MHz
    reg        muestra = 0;
    reg  [9:0] x = 512;
    wire [9:0] y, y2;
    filtro_media #(.LOG2N(3)) dut  (.clk(clk), .muestra(muestra), .x(x), .y(y));
    filtro_media #(.LOG2N(1)) dut2 (.clk(clk), .muestra(muestra), .x(x), .y(y2));

    integer errores = 0, n;
    task una_muestra; begin
        @(negedge clk) muestra = 1;
        @(negedge clk) muestra = 0;
        repeat (2) @(negedge clk);
    end endtask
    task revisar(input [8*30-1:0] que, input [9:0] obtenido, input [9:0] esperado); begin
        if (obtenido !== esperado) begin
            $display("FILTRO MAL (%0s): y = %0d, esperado %0d", que, obtenido, esperado);
            errores = errores + 1;
        end
    end endtask

    initial begin
        repeat (3) @(negedge clk);
        revisar("arranque", y, 512);
        x = 800; repeat (50) @(negedge clk);
        revisar("sin muestras no cambia", y, 512);
        for (n = 0; n < 4; n = n + 1) una_muestra;
        revisar("4 de 8 muestras", y, 656);              // (4 x 800 + 4 x 512) / 8
        revisar("LOG2N=1 lleno", y2, 800);
        for (n = 4; n < 8; n = n + 1) una_muestra;
        revisar("8 de 8 muestras", y, 800);
        for (n = 0; n < 8; n = n + 1) begin x = (n % 2) ? 10'd100 : 10'd900; una_muestra; end
        revisar("alterna 100/900", y, 500);
        if (errores == 0) $display("FILTRO OK"); else $display("FILTRO MAL: %0d errores", errores);
        $finish;
    end
endmodule
