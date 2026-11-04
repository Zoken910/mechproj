// Prueba de sigma_delta.v (modulador de 2o orden del profesor, corregido).
// Correr:
//   iverilog -g2012 -o sim_sd sim/tb_sigma_delta.v rtl/blocks/sigma_delta.v rtl/blocks/v_fpga_fpt2p16_2o_sdm.v && vvp sim_sd
// Listo cuando: imprime "SIGMA-DELTA OK".
// Revisa: proporcion de unos = x / 4096 en todo el rango (tambien en los extremos, donde el
// original desbordaba), que se recupera de saltos bruscos 0 <-> 4095 y que nunca se queda pegado.
`timescale 1ns/1ps
module tb_sigma_delta;
    reg clk = 0; always #41.667 clk = ~clk;          // 12 MHz
    reg  [11:0] x = 2048;
    wire sd;
    sigma_delta dut (.clk(clk), .x(x), .salida(sd));

    integer errores = 0, unos, i, k, peor = 0, dif;
    task medir(input [11:0] v, input integer asentar); begin
        x = v; repeat (asentar) @(posedge clk);
        unos = 0;
        for (i = 0; i < 65536; i = i + 1) begin @(posedge clk); #1; unos = unos + sd; end
        dif = unos - 16 * v;                               // esperado: v / 4096 * 65536
        if (dif < 0) dif = -dif;
        if (dif > peor) peor = dif;
        if (dif > 8) begin
            $display("MAL: x = %0d -> %0d unos de 65536 (esperado %0d)", v, unos, 16 * v); errores = errores + 1;
        end
    end endtask

    reg [11:0] niveles [0:13];
    initial begin
        niveles[0] = 0;    niveles[1] = 1;    niveles[2] = 2;    niveles[3] = 64;   niveles[4] = 1024;
        niveles[5] = 2047; niveles[6] = 2048; niveles[7] = 2049; niveles[8] = 3000; niveles[9] = 3900;
        niveles[10] = 4000; niveles[11] = 4050; niveles[12] = 4094; niveles[13] = 4095;
        for (k = 0; k < 14; k = k + 1) medir(niveles[k], 2000);
        $display("  14 niveles de 0 a 4095: peor diferencia %0d unos de 65536 (%.4f %%)", peor, peor * 100.0 / 65536);
        // saltos bruscos entre extremos (el caso del motor: de 0 a maximo y de vuelta)
        peor = 0;
        for (k = 0; k < 6; k = k + 1) medir((k % 2) ? 12'd0 : 12'd4095, 200);
        $display("  saltos 0 <-> 4095 con solo 200 ciclos para asentarse: peor diferencia %0d unos", peor);
        if (errores == 0) $display("SIGMA-DELTA OK"); else $display("SIGMA-DELTA MAL: %0d errores", errores);
        $finish;
    end
endmodule
