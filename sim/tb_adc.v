// Prueba solo del Paso 6 (adc_ad7606), sin esperar al tb_io.v del Paso 8.
// Correr: iverilog -g2012 -o sim_adc sim/tb_adc.v rtl/blocks/adc_ad7606.v && vvp sim_adc
// Supuesto del modelo (igual que tb_io.v): el AD7606 pone el MSB al bajar CS y
// cambia al siguiente bit en cada SUBIDA de SCLK. Revisarlo contra el datasheet.
`timescale 1ns/1ps
module tb_adc;
    reg clk = 0; always #41.667 clk = ~clk;      // 12 MHz

    // ---- modelo del AD7606: valores distintos en cada conversion ----
    reg [15:0] tabla [0:3][0:7];                  // 4 rondas x 8 canales
    reg [15:0] ch [0:7];
    integer ronda = -1, j;
    initial begin
        // ronda 0: los de tb_io.v
        tabla[0][0]=16'h1234; tabla[0][1]=16'h8001; tabla[0][2]=16'h7FFF; tabla[0][3]=16'h0F0F;
        tabla[0][4]=16'hABCD; tabla[0][5]=16'h0001; tabla[0][6]=16'hFFFF; tabla[0][7]=16'h5555;
        // ronda 1: extremos (-rango, +rango, 0 V, -1)
        tabla[1][0]=16'h8000; tabla[1][1]=16'h7FFF; tabla[1][2]=16'h0000; tabla[1][3]=16'hFFFF;
        tabla[1][4]=16'h0000; tabla[1][5]=16'h8000; tabla[1][6]=16'h7FFF; tabla[1][7]=16'h0001;
        // ronda 2: cada canal con su numero (detecta canales cruzados)
        for (j = 0; j < 8; j = j + 1) tabla[2][j] = 16'h1000 * (j + 1) + j;
        // ronda 3: patron alterno (detecta bits corridos)
        for (j = 0; j < 8; j = j + 1) tabla[3][j] = (j % 2) ? 16'hAAAA : 16'h5555;
    end

    wire convst, rst, cs_n, sclk; reg busy = 0;
    reg [63:0] sha = 0, shb = 0;
    always @(posedge convst) begin
        ronda = ronda + 1;
        for (j = 0; j < 8; j = j + 1) ch[j] = tabla[ronda % 4][j];
        #40 busy = 1; #4000 busy = 0;            // convierte 4 us
    end
    always @(negedge cs_n) begin sha = {ch[0],ch[1],ch[2],ch[3]}; shb = {ch[4],ch[5],ch[6],ch[7]}; end
    always @(posedge sclk) if (!cs_n) begin #10 sha = sha << 1; shb = shb << 1; end

    wire [127:0] valores; wire nueva;
    adc_ad7606 dut (.clk(clk), .convst(convst), .reset(rst), .cs_n(cs_n), .sclk(sclk),
                    .douta(sha[63]), .doutb(shb[63]), .busy(busy),
                    .valores(valores), .nueva(nueva));

    // ---- revisiones de tiempos ----
    integer errores = 0, flancos = 0;
    realtime t_baja_convst, t_ult_nueva = 0, t_baja_cs, t_ini_nueva;
    always @(negedge convst) t_baja_convst = $realtime;
    always @(posedge convst) if ($realtime - t_baja_convst < 25) begin
        $display("MAL: CONVST en bajo solo %0.1f ns (minimo 25)", $realtime - t_baja_convst); errores = errores + 1; end
    always @(negedge cs_n) begin flancos = 0; t_baja_cs = $realtime;
        if (busy) begin $display("MAL: CS bajo con BUSY en alto"); errores = errores + 1; end end
    always @(posedge sclk) if (!cs_n) flancos = flancos + 1;
    always @(posedge cs_n) if (flancos != 64) begin
        $display("MAL: %0d flancos de SCLK con CS bajo (deben ser 64)", flancos); errores = errores + 1; end
    always @(posedge nueva) t_ini_nueva = $realtime;
    always @(negedge nueva) if ($realtime - t_ini_nueva > 90) begin
        $display("MAL: 'nueva' dura mas de 1 ciclo"); errores = errores + 1; end

    // ---- de 16 bits con signo a la cadena de 10 bits (lo hara el top en el Paso 9) ----
    function [9:0] a_cadena(input [15:0] v); a_cadena = {~v[15], v[14:6]}; endfunction

    integer r, i;
    initial begin
        #10; if (rst !== 1) begin $display("MAL: RESET no arranca en alto"); errores = errores + 1; end
        for (r = 0; r < 4; r = r + 1) begin
            @(posedge nueva); #1;
            if (r > 0 && ($realtime - t_ult_nueva < 99_900 || $realtime - t_ult_nueva > 100_100)) begin
                $display("MAL: periodo %0.0f ns (debe ser 100 000)", $realtime - t_ult_nueva); errores = errores + 1; end
            t_ult_nueva = $realtime;
            for (i = 0; i < 8; i = i + 1)
                if (valores[16*i +: 16] !== tabla[r][i]) begin
                    $display("MAL ronda %0d canal %0d: leido %h, esperado %h", r, i, valores[16*i +: 16], tabla[r][i]);
                    errores = errores + 1; end
            $display("ronda %0d: %h  (lectura de %0.1f us)", r, valores, ($realtime - t_baja_cs) / 1000);
        end
        $display("cadena: -rango -> %0d, 0 V -> %0d, +rango -> %0d (deben ser 0, 512, 1023)",
                 a_cadena(16'h8000), a_cadena(16'h0000), a_cadena(16'h7FFF));
        if (a_cadena(16'h8000) != 0 || a_cadena(16'h0000) != 512 || a_cadena(16'h7FFF) != 1023) errores = errores + 1;
        if (errores == 0) $display("ADC OK"); else $display("ADC MAL: %0d errores", errores);
        $finish;
    end
endmodule
