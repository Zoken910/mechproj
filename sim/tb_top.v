// tb_top.v: prueba del LED parpadeante con BIT = 3 (no hay que esperar millones de ciclos).
// Revisa sola que:
//   1) led[0] cambia exactamente cada 8 ciclos de reloj,
//   2) led[1] es siempre lo contrario de led[0] (y nunca X).
// Correr: iverilog -o sim_top sim/tb_top.v rtl/top.v && vvp sim_top
// Ver ondas: gtkwave top.vcd
`timescale 1ns/1ps
module tb_top;
    reg clk = 0;
    always #41.667 clk = ~clk;                 // 12 MHz

    wire [1:0] led;
    top #(.BIT(3)) dut (.clk(clk), .led(led));

    integer ciclos = 0;                        // flancos de subida vistos
    integer ultimo_cambio = 0;                 // ciclo del ultimo cambio de led[0]
    integer cambios = 0, errores = 0;
    reg led0_ant = 0;                          // el contador arranca en 0, asi que led[0] = 0

    always @(posedge clk) ciclos = ciclos + 1;

    // Se revisa en la bajada del reloj, cuando las salidas ya estan estables
    always @(negedge clk) begin
        if (led[1] !== ~led[0]) begin
            errores = errores + 1;
            $display("MAL: en el ciclo %0d led = %b, led[1] debe ser lo contrario de led[0]", ciclos, led);
        end
        if (led[0] !== led0_ant) begin
            if (ciclos - ultimo_cambio != 8) begin
                errores = errores + 1;
                $display("MAL: led[0] cambio despues de %0d ciclos (debe ser 8)", ciclos - ultimo_cambio);
            end
            ultimo_cambio = ciclos;
            cambios       = cambios + 1;
            led0_ant      = led[0];
        end
    end

    initial begin
        $dumpfile("top.vcd");
        $dumpvars(0, tb_top);
        repeat (200) @(posedge clk);           // unos 16.7 us simulados
        if (errores == 0 && cambios >= 20)
            $display("BLINKY OK: led[0] cambio %0d veces, cada 8 ciclos; led[1] siempre invertido", cambios);
        else
            $display("BLINKY MAL: %0d errores, %0d cambios de led[0]", errores, cambios);
        $finish;
    end
endmodule
