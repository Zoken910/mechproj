// Prueba del bloque "combine": combinar.v (formato de la cadena) con el combinador del profesor
// corregido (signalcombiner.v).
// Correr:
//   iverilog -g2012 -o sim_comb sim/tb_combinar.v rtl/blocks/combinar.v rtl/blocks/signalcombiner.v && vvp sim_comb
// Listo cuando: imprime "COMBINE OK" (ninguna linea "COMBINE MAL").
// Revisa los casos de la guia (Paso 9B.4: suma, resta, producto y saturacion), las operaciones
// "solo a" y "solo b" del modulo del profe, y las dos correcciones del original con valores grandes.
`timescale 1ns/1ps
module tb_combinar;
    reg clk = 0; always #41.667 clk = ~clk;          // 12 MHz
    integer errores = 0;

    // ---------- los bloques de la cadena ----------
    reg  [9:0] ca = 512, cb = 512;
    wire [9:0] y_suma, y_resta, y_prod, y_a, y_b;
    combinar #(.OP(2)) u_suma  (.clk(clk), .a(ca), .b(cb), .y(y_suma));
    combinar #(.OP(3)) u_resta (.clk(clk), .a(ca), .b(cb), .y(y_resta));
    combinar #(.OP(4)) u_prod  (.clk(clk), .a(ca), .b(cb), .y(y_prod));
    combinar #(.OP(0)) u_a     (.clk(clk), .a(ca), .b(cb), .y(y_a));
    combinar #(.OP(1)) u_b     (.clk(clk), .a(ca), .b(cb), .y(y_b));

    task revisar(input [9:0] a, input [9:0] b, input [9:0] es, input [9:0] er, input [9:0] ep); begin
        ca = a; cb = b; @(posedge clk); @(posedge clk); #1;
        if (y_suma !== es || y_resta !== er || y_prod !== ep || y_a !== a || y_b !== b) begin
            $display("COMBINE MAL a=%0d b=%0d: suma %0d (esp %0d) resta %0d (esp %0d) prod %0d (esp %0d) a %0d b %0d",
                     a, b, y_suma, es, y_resta, er, y_prod, ep, y_a, y_b);
            errores = errores + 1;
        end
    end endtask

    // ---------- el modulo del profe solo, en Q2.16 ----------
    reg  signed [17:0] s1 = 0, s2 = 0;
    reg  [2:0]         op = 0;
    wire signed [17:0] r;
    signalcombiner nucleo (.sig1(s1), .sig2(s2), .op(op), .clk(clk), .ce(1'b1), .rst(1'b0), .out(r));

    task grande(input [2:0] o, input signed [17:0] a, input signed [17:0] b, input signed [17:0] esperado); begin
        op = o; s1 = a; s2 = b; @(posedge clk); #1;
        if (r !== esperado) begin
            $display("COMBINE MAL (modulo del profe) op %0d: %0d, %0d -> %0d (esperado %0d)", o, a, b, r, esperado);
            errores = errores + 1;
        end
    end endtask

    initial begin
        // casos de la guia (Paso 9B.4)
        revisar(512, 512, 512, 512, 512);
        revisar(700, 600, 788, 612, 544);      // 188+88=276; 188-88=100; 188*88/512=32
        revisar(1023, 1023, 1023, 512, 1022);  // suma saturada
        revisar(0, 1023, 511, 0, 1);           // resta saturada
        revisar(300, 900, 688, 0, 351);        // -212+388=176; -600 -> 0; -212*388/512 = -160.7 -> -161 (hacia abajo)

        // correcciones del modulo del profe (65536 = 1.0)
        grande(3'b010,  18'sd98304,  18'sd98304,  18'sd131071);   // 1.5 + 1.5 = 3.0 -> 1.99998 (antes -1.0)
        grande(3'b011, -18'sd131072, 18'sd98304, -18'sd131072);   // -2.0 - 1.5 -> -2.0
        grande(3'b100, -18'sd131072, -18'sd131072, 18'sd131071);  // -2.0 x -2.0 = 4.0 -> 1.99998
        grande(3'b100,  18'sd98304,  18'sd98304,  18'sd131071);   // 1.5 x 1.5 = 2.25 -> 1.99998
        grande(3'b100,  18'sd32768, -18'sd98304, -18'sd49152);    // 0.5 x -1.5 = -0.75 (sin cambio)
        grande(3'b010,  18'sd32768,  18'sd16384,  18'sd49152);    // 0.5 + 0.25 = 0.75 (sin cambio)

        if (errores == 0) $display("COMBINE OK"); else $display("COMBINE MAL: %0d errores", errores);
        $finish;
    end
endmodule
