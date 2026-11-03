// Modelo de simulacion de un DAC121S101 (cada canal del PmodDA2). Lo usan tb_dac.v y tb_paso7.v.
// Lo que asume el modelo (datasheet TI DAC121S101, SNAS265J, tabla de tiempos con VA = 3 V):
//   - DIN se lee en cada BAJADA de SCLK con SYNC en bajo; la salida cambia en la 16a bajada.
//   - Si SYNC sube antes de la 16a bajada, la trama se descarta (aqui eso es un error).
//   - Trama: DB15-14 no importan, DB13-12 = PD (00 normal), DB11-0 = dato, MSB primero.
//   - Minimos: tH = tL = 13 ns, tSUD = 5 ns, tDHD = 4.5 ns, tCS = 1 ns, tSYNC = 20 ns, fSCLK <= 30 MHz.
//   - tSUCL >= 0 ns (SYNC a subida de SCLK) se lee de la forma estricta: despues de bajar SYNC
//     tiene que haber una subida de SCLK antes de la primera bajada que cuenta.
`timescale 1ns/1ps

module dac121s101_modelo #(parameter [8*4-1:0] NOMBRE = "DAC?") (
    input wire sync_n, input wire sclk, input wire din
);
    localparam real T_H = 13, T_L = 13, T_SUD = 5, T_DHD = 4.5, T_CS = 1, T_SYNC = 20, T_SCLK = 33.3;
    reg  [15:0] sr = 0;
    reg  [11:0] codigo = 0;                 // al encender la salida esta en 0 V
    reg  [1:0]  pd = 0;
    integer     n = 0, actualizaciones = 0, errores = 0;
    reg         subio = 0;                  // hubo subida de SCLK desde que bajo SYNC
    realtime    t_sync_baja = -1e6, t_sync_sube = -1e6, t_sube = -1e6, t_baja = -1e6, t_din = -1e6;
    event       nueva;                      // se dispara cada vez que la salida se actualiza

    task mal(input [8*60-1:0] que, input real valor);
        begin
            if (errores < 5) $display("MAL %s: %0s (%0.1f) en t = %0.0f ns", NOMBRE, que, valor, $realtime);
            errores = errores + 1;
        end
    endtask

    always @(negedge sync_n) begin
        if (t_sync_sube > 0 && $realtime - t_sync_sube < T_SYNC) mal("SYNC en alto muy poco (tSYNC, ns)", $realtime - t_sync_sube);
        n = 0; subio = 0; t_sync_baja = $realtime;
    end

    always @(posedge sclk) if (sync_n === 1'b0) begin
        if ($realtime - t_baja < T_L)    mal("SCLK en bajo muy poco (tL, ns)", $realtime - t_baja);
        if ($realtime - t_sube < T_SCLK) mal("SCLK mas rapido que 30 MHz (periodo, ns)", $realtime - t_sube);
        if (!subio && $realtime - t_sync_baja < 0) mal("SYNC bajo despues de la subida (tSUCL)", 0);
        subio = 1; t_sube = $realtime;
    end else t_sube = $realtime;

    always @(negedge sclk) begin
        if (sync_n === 1'b0) begin
            if (n < 16) begin
                if (!subio)                      mal("bajada de SCLK sin subida tras bajar SYNC (tSUCL)", 0);
                if ($realtime - t_sube < T_H)    mal("SCLK en alto muy poco (tH, ns)", $realtime - t_sube);
                if ($realtime - t_din  < T_SUD)  mal("DIN cambio muy cerca de la bajada (tSUD, ns)", $realtime - t_din);
                sr = {sr[14:0], din};
                n  = n + 1;
                if (n == 16) begin
                    codigo = sr[11:0]; pd = sr[13:12];
                    actualizaciones = actualizaciones + 1;
                    if (pd != 2'b00) mal("bits PD distintos de 00 (salida apagada, PD)", pd);
                    -> nueva;
                end
            end else n = n + 1;             // bajadas de sobra: el DAC las ignora, pero no deben existir
        end
        t_baja = $realtime;
    end

    always @(din) begin
        if (sync_n === 1'b0 && n > 0 && n < 16 && $realtime - t_baja < T_DHD)
            mal("DIN cambio muy pronto tras la bajada (tDHD, ns)", $realtime - t_baja);
        t_din = $realtime;
    end

    always @(posedge sync_n) begin
        if (n > 0 && n < 16) mal("SYNC subio antes de la 16a bajada: trama descartada (bajadas)", n);
        if (n > 16)          mal("mas de 16 bajadas con SYNC en bajo (bajadas)", n);
        if (n == 16 && $realtime - t_baja < T_CS) mal("SYNC subio muy pronto tras la 16a bajada (tCS, ns)", $realtime - t_baja);
        t_sync_sube = $realtime;
    end
endmodule

