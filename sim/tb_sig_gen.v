// Prueba del bloque "signal": sig_gen.v (formato de la cadena) con el generador del profesor
// corregido (signalgenerator.v + urandgenerator.v).
// Correr:
//   iverilog -g2012 -o sim_sig sim/tb_sig_gen.v rtl/blocks/sig_gen.v rtl/blocks/signalgenerator.v \
//            rtl/blocks/urandgenerator.v && vvp sim_sig
// Listo cuando: imprime "SIGNAL OK" (ninguna linea "SIGNAL MAL").
// Revisa: el seno contra $sin (error de la interpolacion), que cada forma llegue a los extremos, la
// escala y el offset, el periodo (inc = 4096 -> 4096 ciclos), que el coseno vaya 90 grados antes
// que el seno, que el ruido no este plano (CORREGIDO (G4)) y la saturacion (CORREGIDO (G3)).
`timescale 1ns/1ps
module tb_sig_gen;
    reg clk = 0; always #41.667 clk = ~clk;          // 12 MHz

    // ---------- el bloque de la cadena ----------
    reg [2:0]  forma  = 0;
    reg [15:0] inc    = 16'd4096;                     // una vuelta en 4096 ciclos (rapido para simular)
    reg [9:0]  amp    = 512, offset = 512;
    wire [9:0] y;
    sig_gen dut (.clk(clk), .forma(forma), .inc(inc), .amp(amp), .offset(offset), .y(y));

    // ---------- el modulo del profe solo, en Q2.16 ----------
    reg  [2:0]         tipo = 4;
    reg  signed [17:0] escala = 18'sd65536, desplaz = 18'sd0;
    wire signed [17:0] s;
    signalgenerator nucleo (.clock_enable(1'b1), .signal_type(tipo), .offset(desplaz), .rst(1'b0),
                            .clk(clk), .increment_per_cycle(18'd4096), .signal_scale(escala),
                            .signal_out(s));

    integer errores = 0, k, mn, mx, suma, periodo, peor;
    real    ideal, dif, t0, t1;

    task medir; begin                                  // min y max de y en 4 vueltas
        repeat (40) @(posedge clk);                    // dejar que el pipeline se llene
        mn = 2000; mx = 0; suma = 0;
        for (k = 0; k < 4 * 4096; k = k + 1) begin
            @(posedge clk); #1;
            if (y < mn) mn = y;
            if (y > mx) mx = y;
            suma = suma + y;
        end
    end endtask

    task rango(input [8*24-1:0] que, input integer min_max, input integer max_min); begin
        medir;
        $display("  %0s: min %0d max %0d media %0d", que, mn, mx, suma / (4 * 4096));
        if (mn > min_max || mx < max_min) begin
            $display("SIGNAL MAL: %0s no llega a los extremos", que); errores = errores + 1;
        end
    end endtask

    initial begin
        $dumpfile("sig_gen.vcd"); $dumpvars(0, tb_sig_gen);

        // 1) seno del modulo del profe contra el seno ideal: (0.5 + 0.5 sin - 0.5) x 1.0
        //    La salida va 7 ciclos atrasada respecto al acumulador de fase (pipeline de 7 etapas).
        repeat (100) @(posedge clk);
        peor = 0;
        for (k = 0; k < 8192; k = k + 1) begin
            @(posedge clk); #1;
            ideal = 0.5 * $sin(2.0 * 3.14159265358979 * ((nucleo.phase_accumulator - 7 * 4096) % 16777216) / 16777216.0) * 65536.0;
            dif = s - ideal; if (dif < 0) dif = -dif;
            if (dif > peor) peor = dif;
        end
        $display("  seno del profe (corregido) contra $sin: peor diferencia %0d de 65536 (%.4f %%)", peor, peor * 100.0 / 65536);
        if (peor > 6) begin $display("SIGNAL MAL: el seno se aleja del ideal"); errores = errores + 1; end

        // 2) saturacion (CORREGIDO (G3)): offset 1.75 + seno x 1.0 pasaria de 2.0
        desplaz = 18'sd114688;                         // 1.75
        repeat (40) @(posedge clk);
        mn = 300000; mx = -300000;
        for (k = 0; k < 4096; k = k + 1) begin
            @(posedge clk); #1;
            if (s < mn) mn = s;
            if (s > mx) mx = s;
        end
        $display("  offset 1.75 + seno: min %0d max %0d (el original daba la vuelta a -2.0)", mn, mx);
        if (mn < 70000 || mx != 131071) begin $display("SIGNAL MAL: no satura"); errores = errores + 1; end
        desplaz = 0;

        // 3) coseno = seno adelantado 90 grados: cuando el seno cruza 0 subiendo, el coseno esta arriba
        tipo = 3; repeat (40) @(posedge clk);
        wait (nucleo.phase_accumulator == 24'd0); repeat (7) @(posedge clk); #1;
        $display("  coseno en fase 0: %0d (debe ser ~ +32768)", s);
        if (s < 32700) begin $display("SIGNAL MAL: el coseno no empieza arriba"); errores = errores + 1; end

        // 4) las formas del bloque de la cadena llegan a 0 y a 1023 (amp 512, offset 512)
        forma = 0; rango("seno",       2, 1021);
        forma = 1; rango("cuadrada",   0, 1023);
        forma = 2; rango("triangulo",  2, 1021);
        forma = 3; rango("sierra",     2, 1015);
        forma = 4; rango("ruido",    120,  900);
        if (suma / (4 * 4096) < 480 || suma / (4 * 4096) > 544) begin
            $display("SIGNAL MAL: el ruido no esta centrado en 512"); errores = errores + 1;
        end

        // 5) escala y offset: amplitud 1/2 alrededor de 600 -> 344..856
        forma = 0; amp = 256; offset = 600; medir;
        $display("  seno amp 256 offset 600: min %0d max %0d (esperado 344 y 856)", mn, mx);
        if (mn < 343 || mn > 345 || mx < 855 || mx > 857) begin $display("SIGNAL MAL: escala"); errores = errores + 1; end
        amp = 0; offset = 300; medir;
        if (mn != 300 || mx != 300) begin $display("SIGNAL MAL: amp 0 debe dar el offset fijo"); errores = errores + 1; end

        // 6) periodo: la sierra baja de golpe una vez por vuelta
        forma = 3; amp = 512; offset = 512; repeat (40) @(posedge clk);
        @(negedge y[9]); t0 = $realtime;
        @(negedge y[9]); t1 = $realtime;
        periodo = $rtoi((t1 - t0) / 83.3333 + 0.5);
        $display("  periodo con inc = 4096: %0d ciclos (esperado 4096 = 2^24 / 4096)", periodo);
        if (periodo < 4094 || periodo > 4098) begin $display("SIGNAL MAL: periodo"); errores = errores + 1; end

        if (errores == 0) $display("SIGNAL OK"); else $display("SIGNAL MAL: %0d errores", errores);
        $finish;
    end
    initial begin #50_000_000 $display("SIGNAL MAL: timeout"); $finish; end
endmodule
