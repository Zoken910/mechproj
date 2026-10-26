// Prueba del LED parpadeante (Paso 3), version que se revisa sola.
// Correr: iverilog -g2012 -o sim_top sim/tb_top.v rtl/top.v && vvp sim_top
// Ver:    gtkwave top.vcd
//
// Con BIT = 3: led[0] = contador[3] cambia cada 8 ciclos, y led[1] siempre es lo contrario.
`timescale 1ns/1ps
module tb_top;
    reg clk = 0; always #41.667 clk = ~clk;      // 12 MHz

    wire [1:0] led;
    top #(.BIT(3)) dut (.clk(clk), .led(led));

    integer errores = 0, ciclos = 0, ultimo = -1, cambios = 0;
    reg     led0_antes;

    always @(negedge clk) begin                  // muestrear a mitad de ciclo
        ciclos = ciclos + 1;
        if (led[1] !== ~led[0]) begin
            $display("TOP MAL: ciclo %0d, led = %b (led[1] debe ser ~led[0])", ciclos, led);
            errores = errores + 1;
        end
        if (ciclos > 1 && led[0] !== led0_antes) begin
            if (ultimo >= 0 && ciclos - ultimo != 8) begin
                $display("TOP MAL: led[0] cambio despues de %0d ciclos (esperado 8)", ciclos - ultimo);
                errores = errores + 1;
            end
            ultimo  = ciclos;
            cambios = cambios + 1;
        end
        led0_antes = led[0];
    end

    initial begin
        $dumpfile("top.vcd"); $dumpvars(0, tb_top);
        repeat (100) @(posedge clk);
        if (cambios < 10) begin
            $display("TOP MAL: led[0] solo cambio %0d veces en 100 ciclos", cambios);
            errores = errores + 1;
        end
        if (errores == 0) $display("TOP OK (%0d cambios, cada 8 ciclos)", cambios);
        else              $display("TOP MAL: %0d errores", errores);
        $finish;
    end

    initial begin #1_000_000 $display("TOP MAL: timeout"); $finish; end   // vigilante
endmodule
