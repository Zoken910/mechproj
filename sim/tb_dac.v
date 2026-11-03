// Prueba del Paso 7 (dac_pmodda2) contra un modelo del DAC121S101 que revisa los tiempos.
// Correr:
//   iverilog -g2012 -o sim_dac sim/tb_dac.v sim/modelo_dac121s101.v rtl/blocks/dac_pmodda2.v && vvp sim_dac
//   iverilog -g2012 -P tb_dac.CLK_DIV=3 -o sim_dac3 sim/tb_dac.v sim/modelo_dac121s101.v rtl/blocks/dac_pmodda2.v && vvp sim_dac3
// Listo cuando: imprime "DAC OK" con CLK_DIV = 1 y con CLK_DIV = 3, sin ninguna linea "MAL".
//
// Supuestos del modelo del DAC (tiempos del datasheet): ver sim/modelo_dac121s101.v
`timescale 1ns/1ps

// ---------------- testbench ----------------
module tb_dac;
    parameter CLK_DIV = 1;
    localparam real T_CLK  = 83.333;                       // 12 MHz
    localparam real T_TRAMA = (3 + 32 * CLK_DIV) * T_CLK;   // lo que debe durar una trama

    reg clk = 0; always #41.667 clk = ~clk;

    reg  [11:0] valor_a = 0, valor_b = 0;
    wire sync_n, sclk, dina, dinb;
    dac_pmodda2 #(.CLK_DIV(CLK_DIV)) dut (.clk(clk), .valor_a(valor_a), .valor_b(valor_b),
                                         .sync_n(sync_n), .sclk(sclk), .dina(dina), .dinb(dinb));
    dac121s101_modelo #(.NOMBRE("DACA")) dac_a (.sync_n(sync_n), .sclk(sclk), .din(dina));
    dac121s101_modelo #(.NOMBRE("DACB")) dac_b (.sync_n(sync_n), .sclk(sclk), .din(dinb));

    integer errores = 0;
    function real voltios(input [11:0] c); voltios = c * 3.3 / 4096.0; endfunction

    // 1) pone un valor, mide cuanto tarda en salir y revisa que se quede
    task probar(input [11:0] a, input [11:0] b);
        realtime t0, lat;
        begin
            valor_a = a; valor_b = b; t0 = $realtime;
            while (dac_a.codigo !== a || dac_b.codigo !== b) @(dac_a.nueva or dac_b.nueva);
            #1 lat = $realtime - t0;
            repeat (3) @(dac_a.nueva);                     // tres tramas mas: debe seguir igual
            #1;
            if (dac_a.codigo !== a || dac_b.codigo !== b) begin
                $display("MAL: se pidio %h/%h y sale %h/%h", a, b, dac_a.codigo, dac_b.codigo);
                errores = errores + 1;
            end else if (lat > 2 * T_TRAMA + 1) begin
                $display("MAL: %h/%h tardo %0.0f ns en salir (maximo 2 tramas = %0.0f ns)", a, b, lat, 2 * T_TRAMA);
                errores = errores + 1;
            end else
                $display("  %h -> %0.4f V   %h -> %0.4f V   (sale en %0.2f us)",
                         a, voltios(a), b, voltios(b), lat / 1000.0);
        end
    endtask

    // 2) los valores cambian en momentos al azar: cada trama debe traer una pareja que de verdad
    //    se pidio (nunca bits mezclados de dos valores, ni A de un momento y B de otro)
    reg [11:0] hist_a [0:7], hist_b [0:7];
    integer h = 0, revisadas = 0, k, i;
    reg     azar = 0, ok;
    always @(dac_a.nueva) if (azar) begin
        #1 ok = 0;
        for (i = 0; i < 8; i = i + 1) if (dac_a.codigo === hist_a[i] && dac_b.codigo === hist_b[i]) ok = 1;
        if (!ok) begin
            $display("MAL: trama mezclada, salio %h/%h", dac_a.codigo, dac_b.codigo); errores = errores + 1;
        end
        revisadas = revisadas + 1;
    end

    realtime t1, t2;
    integer semilla = 7;
    initial begin
        $dumpfile("dac.vcd"); $dumpvars(0, tb_dac);
        $display("dac_pmodda2 con CLK_DIV = %0d: SCLK = %0.1f MHz", CLK_DIV, 12.0 / (2 * CLK_DIV));

        // ritmo de actualizacion
        @(dac_a.nueva); t1 = $realtime; @(dac_a.nueva); t2 = $realtime;
        $display("  una trama cada %0.3f us (%0.0f actualizaciones/s)", (t2 - t1) / 1000.0, 1e9 / (t2 - t1));
        if (t2 - t1 > T_TRAMA + 1 || t2 - t1 < T_TRAMA - 1) begin
            $display("MAL: la trama dura %0.1f ns, se esperaban %0.1f", t2 - t1, T_TRAMA); errores = errores + 1;
        end

        probar(12'hABC, 12'h123);                          // los de la guia (tb_io.v)
        probar(12'h000, 12'hFFF);                          // extremos
        probar(12'hFFF, 12'h000);
        probar(12'h800, 12'h800);                          // mitad: 1.65 V
        probar(12'h555, 12'hAAA);                          // bits alternos
        probar(12'h001, 12'hFFE);                          // el bit mas bajo
        probar(12'h800, 12'h7FF);                          // cambia casi todos los bits

        for (i = 0; i < 8; i = i + 1) begin hist_a[i] = 12'h800; hist_b[i] = 12'h7FF; end
        azar = 1;
        for (k = 0; k < 300; k = k + 1) begin
            #($urandom(semilla) % (2 * T_TRAMA));
            @(posedge clk) #1;                             // cambio sincrono, como en la FPGA
            valor_a = $urandom(semilla); valor_b = $urandom(semilla);
            h = (h + 1) % 8; hist_a[h] = valor_a; hist_b[h] = valor_b;
            semilla = semilla + 1;
        end
        repeat (3) @(dac_a.nueva);
        azar = 0;
        $display("  %0d tramas con cambios al azar revisadas", revisadas);

        errores = errores + dac_a.errores + dac_b.errores;
        if (errores == 0) $display("DAC OK (%0d tramas, tiempos del DAC121S101 cumplidos)", dac_a.actualizaciones);
        else              $display("DAC MAL: %0d errores", errores);
        $finish;
    end

    initial begin #20_000_000 $display("DAC MAL: timeout (el DAC no recibe tramas)"); $finish; end
endmodule
