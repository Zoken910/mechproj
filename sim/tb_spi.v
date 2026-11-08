// Prueba de spi_stream.v en los dos sentidos (Paso 8) y de sus limites de tiempo con la Pi.
// Correr:
//   iverilog -g2012 -o sim_spi sim/tb_spi.v rtl/blocks/spi_stream.v && vvp sim_spi
// Listo cuando: imprime "SPI OK". Al final imprime con que velocidad de SCLK y que espera entre
// bajar CS y el primer flanco sigue funcionando (para fpga_stream.py de Levi).
`timescale 1ns/1ps
module tb_spi;
    reg clk = 0; always #41.667 clk = ~clk;              // 12 MHz

    reg  sck = 0, cs_n = 1, mosi = 0;
    wire miso;
    reg  [191:0] datos;
    wire [15:0]  rx0, rx1;
    spi_stream #(.PALABRAS(12)) dut (.clk(clk), .sck(sck), .cs_n(cs_n), .mosi(mosi), .miso(miso),
                                     .datos(datos), .rx0(rx0), .rx1(rx1));

    // la Pi: maestro en modo 0. MOSI cambia en la bajada, MISO se lee en la subida.
    reg [191:0] recibido;
    task transferir(input [191:0] tx, input integer nbits, input integer medio_ns, input integer espera_cs_ns);
        integer k;
        begin
            recibido = 0;
            cs_n = 0; mosi = tx[191]; #(espera_cs_ns);
            for (k = 0; k < nbits; k = k + 1) begin
                sck = 1; recibido = {recibido[190:0], miso}; #(medio_ns);
                sck = 0; if (k + 1 < nbits) mosi = tx[190 - k]; #(medio_ns);
            end
            cs_n = 1; mosi = 0; #2000;
        end
    endtask

    // la trama que espera la Pi: palabra 0 primero
    function [191:0] esperado(input [191:0] d);
        integer w;
        for (w = 0; w < 12; w = w + 1) esperado[16*(11-w) +: 16] = d[16*w +: 16];
    endfunction

    integer errores = 0, w, sp, med;
    reg [191:0] foto;
    task revisar(input [8*48-1:0] que, input ok); begin
        if (!ok) begin $display("MAL: %0s", que); errores = errores + 1; end
        else $display("  ok: %0s", que);
    end endtask

    initial begin
        for (w = 0; w < 12; w = w + 1) datos[16*w +: 16] = 16'h1000 * w + 16'h0111 * w + 16'h0042;
        datos[15:0] = 16'hA5A5;
        #3000;

        transferir(192'd0, 192, 500, 500);
        revisar("solo leer: la Pi recibe la foto completa", recibido === esperado(datos));
        revisar("solo leer: rx0/rx1 siguen en 512 (0 V)", rx0 === 16'd512 && rx1 === 16'd512);

        transferir({16'h5A5A, 16'h0123, 16'h0345, 144'd0}, 192, 500, 500);
        revisar("escribir y leer a la vez: foto correcta", recibido === esperado(datos));
        revisar("escribir: rx0 = 0x0123, rx1 = 0x0345", rx0 === 16'h0123 && rx1 === 16'h0345);

        transferir(192'd0, 192, 500, 500);
        revisar("una lectura con ceros no borra rx0/rx1", rx0 === 16'h0123 && rx1 === 16'h0345);

        transferir({16'h5A5B, 16'h0001, 16'h0002, 144'd0}, 192, 500, 500);
        revisar("marca equivocada (0x5A5B): se ignora", rx0 === 16'h0123 && rx1 === 16'h0345);

        transferir({16'h5A5A, 16'h0001, 16'h0002, 144'd0}, 40, 500, 500);
        revisar("transferencia cortada (40 bits): se ignora", rx0 === 16'h0123 && rx1 === 16'h0345);

        transferir({16'h5A5A, 16'h0200, 16'h03FF, 144'd0}, 48, 500, 500);
        revisar("solo 48 bits (sin leer la foto): rx se actualiza", rx0 === 16'h0200 && rx1 === 16'h03FF);

        // la foto se congela al bajar CS aunque los datos cambien durante la transferencia
        foto = datos;
        fork
            transferir(192'd0, 192, 500, 500);
            begin #50000 datos[159:144] = 16'hFFFF; datos[31:16] = 16'hEEEE; end
        join
        revisar("la foto se congela al bajar CS", recibido === esperado(foto));

        // dos transferencias seguidas con CS en alto solo 1 us
        foto = datos;
        cs_n = 0; #500; cs_n = 1; #1000;                  // pulso corto de CS (sin reloj): no rompe nada
        transferir(192'd0, 192, 500, 500);
        revisar("CS en alto solo 1 us entre transferencias", recibido === esperado(foto));

        // ---- limites para fpga_stream.py ----
        $display("  limites (foto correcta con estos tiempos):");
        for (sp = 0; sp < 4; sp = sp + 1) begin
            med = (sp == 0) ? 500 : (sp == 1) ? 333 : (sp == 2) ? 250 : 167;   // 1, 1.5, 2, 3 MHz
            transferir(192'd0, 192, med, med);
            $display("    SCLK %0.1f MHz (espera de CS = medio periodo): %s", 500.0 / med, recibido === esperado(datos) ? "bien" : "FALLA");
        end
        for (sp = 20; sp <= 420; sp = sp + 100) begin
            transferir(192'd0, 192, 500, sp);
            $display("    SCLK 1 MHz, espera CS -> primer flanco %0d ns: %s", sp, recibido === esperado(datos) ? "bien" : "FALLA");
        end

        transferir({16'h5A5A, 16'h0077, 16'h0099, 144'd0}, 192, 500, 20);
        revisar("escribir con solo 20 ns entre CS y SCLK", rx0 === 16'h0077 && rx1 === 16'h0099 && recibido === esperado(datos));

        if (errores == 0) $display("SPI OK"); else $display("SPI MAL: %0d errores", errores);
        $finish;
    end
endmodule
