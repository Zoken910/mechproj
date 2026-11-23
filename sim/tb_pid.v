// Prueba del bloque PID (control_pid.v) y del lazo con un motor DC simulado.
// Correr:
//   iverilog -g2012 -o sim_pid sim/tb_pid.v sim/modelo_motor_dc.v rtl/blocks/control_pid.v && vvp sim_pid
// Listo cuando: imprime "PID OK" (ninguna linea "PID MAL").
// Revisa: P con redondeo y saturacion, enable, la integral (con anti-windup), la derivada sobre la
// medida, el tick cada DIV muestras, la salida solo positiva (Y_MIN = 512) y, con el modelo del
// motor (sim/modelo_motor_dc.v), que el P solo deja error y el PI lo lleva a cero, tambien al
// invertir el giro y con carga en el eje.
// Cada pulso de 'muestra' cuenta como una muestra del ADC (100 us de tiempo "fisico"); aqui llegan
// cada 8 ciclos para que la simulacion sea rapida. El PID solo ve los pulsos, no el tiempo.
`timescale 1ns/1ps
module tb_pid;
    reg clk = 0; always #41.667 clk = ~clk;              // 12 MHz

    // ---------- PID suelto, con las entradas manejadas a mano ----------
    reg        enable = 0, muestra = 0;
    reg  [9:0] sp = 512, pv = 512;
    reg [15:0] kp = 256, ki = 0, kd = 0;
    wire [9:0] y, y_pos, y10;
    control_pid #(.DIV(1)) dut (.clk(clk), .enable(enable), .muestra(muestra),
        .setpoint(sp), .medida(pv), .kp(kp), .ki(ki), .kd(kd), .y(y));
    // driver de motor que no acepta voltajes negativos: salida de 512 (0 V) para arriba
    control_pid #(.DIV(1), .Y_MIN(512)) dut_pos (.clk(clk), .enable(enable), .muestra(muestra),
        .setpoint(sp), .medida(pv), .kp(kp), .ki(ki), .kd(kd), .y(y_pos));
    // tick normal: un calculo cada 10 muestras (1 kHz con el ADC a 10 kHz)
    control_pid #(.DIV(10)) dut10 (.clk(clk), .enable(enable), .muestra(muestra),
        .setpoint(sp), .medida(pv), .kp(kp), .ki(ki), .kd(kd), .y(y10));

    integer errores = 0, n;

    // un pulso de 'muestra' y tiempo para los 4 pasos del calculo
    task una_muestra; begin
        @(negedge clk) muestra = 1;
        @(negedge clk) muestra = 0;
        repeat (6) @(negedge clk);
    end endtask

    task revisar(input [8*40-1:0] que, input [9:0] obtenido, input [9:0] esperado); begin
        if (obtenido !== esperado) begin
            $display("PID MAL (%0s): y = %0d, esperado %0d", que, obtenido, esperado);
            errores = errores + 1;
        end
    end endtask

    // ---------- lazo cerrado: PID (tick de 1 kHz) + motor DC simulado ----------
    reg        en_lazo = 0, m_lazo = 0;
    reg  [9:0] sp_lazo = 512;
    reg [15:0] kp_l = 256, ki_l = 0, kd_l = 0;
    wire [9:0] u_lazo;
    wire [15:0] adc_motor;
    wire [9:0] medida_lazo = adc_motor[15:6] ^ 10'h200;  // igual que el top: 16 bits -> cadena
    control_pid #(.DIV(10)) pid_lazo (.clk(clk), .enable(en_lazo), .muestra(m_lazo),
        .setpoint(sp_lazo), .medida(medida_lazo), .kp(kp_l), .ki(ki_l), .kd(kd_l), .y(u_lazo));
    motor_dc_modelo motor (.paso(m_lazo), .codigo_dac({u_lazo, 2'b00}), .codigo_adc(adc_motor));

    integer k, err, err_abs, pico, t_ms;
    // avanza 'ms' milisegundos de tiempo fisico (10 muestras del ADC por ms)
    task correr(input integer ms, input integer imprimir_cada); begin
        for (k = 0; k < ms * 10; k = k + 1) begin
            @(negedge clk) m_lazo = 1;
            @(negedge clk) m_lazo = 0;
            repeat (6) @(negedge clk);
            if (imprimir_cada > 0 && k % (imprimir_cada * 10) == 0)
                $display("    t = %3d ms  setpoint %4d  medida %4d  salida PID %4d (%5.2f V al motor)  %4.0f rpm",
                         t_ms + k / 10, sp_lazo, medida_lazo, u_lazo, (u_lazo - 512) * 5.0 / 512, motor.rpm);
            if (medida_lazo > pico) pico = medida_lazo;
        end
        t_ms = t_ms + ms;
        err = sp_lazo - medida_lazo;
        err_abs = err < 0 ? -err : err;
    end endtask

    initial begin
        $dumpfile("pid.vcd"); $dumpvars(0, tb_pid);
        repeat (5) @(negedge clk);

        // ---- 1. P: igual que el control_p de la guia, pero centrado en 512 = 0 V ----
        enable = 1; kp = 256; ki = 0; kd = 0;
        sp = 600; pv = 500; una_muestra; revisar("P e=+100", y, 612);
        sp = 500; pv = 600; una_muestra; revisar("P e=-100", y, 412);
        revisar("P e=-100 solo positivo", y_pos, 512);
        kp = 512; sp = 900; pv = 500; una_muestra; revisar("P saturado arriba", y, 1023);
        sp = 100; una_muestra; revisar("P saturado abajo", y, 0);
        kp = 384; sp = 501; pv = 500; una_muestra; revisar("P redondeo +1.5", y, 514);
        sp = 499; una_muestra; revisar("P redondeo -1.5", y, 511);

        // ---- 2. enable = 0: salida en 0 V aunque haya error ----
        enable = 0; @(negedge clk); @(negedge clk); revisar("enable = 0", y, 512);

        // ---- 3. integral: KI = 6554 (0.1 por tick), e = 100 -> +10 por tick ----
        kp = 0; ki = 6554; kd = 0; sp = 600; pv = 500; enable = 1;
        una_muestra; revisar("I 1 tick", y, 522);
        for (n = 1; n < 5; n = n + 1) una_muestra;
        revisar("I 5 ticks", y, 562);
        for (n = 5; n < 10; n = n + 1) una_muestra;
        revisar("I 10 ticks", y, 612);
        enable = 0; @(negedge clk); @(negedge clk); enable = 1;          // apagar borra la integral
        una_muestra; revisar("I despues de apagar", y, 522);

        // ---- 4. anti-windup: la integral se satura y sale de la saturacion enseguida ----
        enable = 0; @(negedge clk); ki = 16'd65535; enable = 1;          // e = 100 -> ~+100 por tick
        for (n = 0; n < 20; n = n + 1) una_muestra;                      // 20 ticks empujando arriba
        revisar("anti-windup saturado", y, 1023);
        sp = 400;                                                        // ahora e = -100
        una_muestra;
        if (y > 930 || y < 900) begin
            $display("PID MAL (anti-windup): tras invertir el error la salida es %0d (esperado ~924)", y);
            errores = errores + 1;
        end else $display("  anti-windup: 20 ticks saturado, un tick despues de invertir el error ya baja a %0d", y);

        // ---- 5. derivada sobre la medida (KD = 2560 = 10 por LSB y tick) ----
        enable = 0; @(negedge clk); kp = 0; ki = 0; kd = 2560; sp = 512; pv = 500; enable = 1;
        una_muestra; revisar("D sin cambio", y, 512);
        pv = 510; una_muestra; revisar("D medida +10", y, 412);          // -10 x 10 = -100
        una_muestra; revisar("D medida quieta", y, 512);
        sp = 700; una_muestra; revisar("D setpoint salta (sin pico)", y, 512);

        // ---- 6. tick cada 10 muestras ----
        enable = 0; @(negedge clk); kp = 256; ki = 0; kd = 0; sp = 600; pv = 500; enable = 1;
        for (n = 0; n < 9; n = n + 1) una_muestra;
        revisar("DIV=10 tras 9 muestras", y10, 512);
        una_muestra; revisar("DIV=10 tras 10 muestras", y10, 612);
        enable = 0;

        // ---- 7. lazo cerrado con el motor DC: P solo vs PI ----
        t_ms = 0; pico = 0;
        $display("  Lazo con el motor simulado (tau 50 ms, zona muerta 0.3 V), setpoint 712 = +1.95 V = 1172 rpm:");
        sp_lazo = 712; kp_l = 512; ki_l = 0; en_lazo = 1;                // Kp = 2, sin integral
        correr(400, 0);
        $display("  P solo (Kp = 2): medida %0d, error %0d (el P solo no llega)", medida_lazo, err);
        if (err_abs < 30) begin $display("PID MAL: el P solo deberia dejar error"); errores = errores + 1; end

        en_lazo = 0; correr(300, 0);                                     // apagar y dejar que se pare
        $display("  PI (Kp = 2, KI = 2621 = 40 /s), escalon desde parado:");
        pico = 0; ki_l = 2621; en_lazo = 1;
        correr(300, 20);
        $display("  PI: medida %0d, error %0d, pico %0d (sobrepaso %0d)", medida_lazo, err, pico, pico - sp_lazo);
        if (err_abs > 2) begin $display("PID MAL: el PI deberia llevar el error a 0 (+-2)"); errores = errores + 1; end
        if (pico > sp_lazo + 20) begin $display("PID MAL: sobrepaso grande"); errores = errores + 1; end

        sp_lazo = 362; correr(400, 0);                                   // girar al reves: -1.46 V
        $display("  PI al reves (setpoint 362): medida %0d, error %0d", medida_lazo, err);
        if (err_abs > 2) begin $display("PID MAL: no sigue el setpoint negativo"); errores = errores + 1; end

        sp_lazo = 712; correr(400, 0);
        motor.carga = 0.7;                                               // carga en el eje: -30 %
        correr(500, 0);
        $display("  PI con carga (-30 %% de velocidad): medida %0d, error %0d, %0d mV al motor",
                 medida_lazo, err, (u_lazo - 512) * 5000 / 512);
        if (err_abs > 2) begin $display("PID MAL: no compensa la carga"); errores = errores + 1; end

        kd_l = 2560; correr(300, 0);                                     // con D (10 ms) sigue estable
        $display("  PID (KD = 2560 = 10 ms): medida %0d, error %0d", medida_lazo, err);
        if (err_abs > 2) begin $display("PID MAL: inestable con D"); errores = errores + 1; end

        if (errores == 0) $display("PID OK");
        else              $display("PID MAL: %0d errores", errores);
        $finish;
    end
    initial begin #400_000_000 $display("PID MAL: timeout"); $finish; end
endmodule
