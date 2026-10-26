// Prueba del PWM de practica. Se revisa sola: imprime "PWM OK" o "PWM MAL".
// Correr: iverilog -g2012 -o sim_pwm sim/tb_pwm.v rtl/practica/pwm.v && vvp sim_pwm
// Ver:    gtkwave pwm.vcd
//
// Idea: en CUALQUIER ventana de 1024 ciclos seguidos, cnt pasa una vez por cada
// valor 0..1023, asi que 'salida' debe estar en alto exactamente 'duty' ciclos.
`timescale 1ns/1ps
module tb_pwm;
    reg clk = 0; always #41.667 clk = ~clk;      // 12 MHz

    reg  [9:0] duty = 0;
    wire       salida;
    pwm dut (.clk(clk), .duty(duty), .salida(salida));

    integer errores = 0;
    integer i, altos;

    task probar(input [9:0] d);
        begin
            @(negedge clk) duty = d;              // cambiar lejos del flanco de subida
            repeat (2048) @(negedge clk);         // dejar pasar 2 periodos completos
            altos = 0;
            for (i = 0; i < 1024; i = i + 1) begin
                @(negedge clk);                   // muestrear a mitad de ciclo
                if (salida === 1'b1) altos = altos + 1;
                else if (salida !== 1'b0) begin
                    $display("PWM MAL: salida = %b (X o Z) con duty = %0d", salida, d);
                    errores = errores + 1;
                end
            end
            if (altos != d) begin
                $display("PWM MAL: duty = %0d -> %0d ciclos en alto (esperado %0d)", d, altos, d);
                errores = errores + 1;
            end else
                $display("duty = %4d -> %4d de 1024 ciclos en alto (%0d %%)", d, altos, (altos * 100) / 1024);
        end
    endtask

    initial begin
        $dumpfile("pwm.vcd"); $dumpvars(0, tb_pwm);
        probar(10'd256);    // 25 %, el caso de la guia
        probar(10'd0);      // siempre apagado
        probar(10'd1);      // el pulso mas corto: 1 ciclo
        probar(10'd512);    // 50 %
        probar(10'd1023);   // maximo: 1023 de 1024 (nunca llega al 100 %)
        if (errores == 0) $display("PWM OK");
        else              $display("PWM MAL: %0d errores", errores);
        $finish;
    end

    initial begin #5_000_000 $display("PWM MAL: timeout"); $finish; end   // vigilante
endmodule
