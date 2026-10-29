// Prueba del Paso 5: la "Pi" escribe y lee todos los registros por UART.
// Correr:
//   iverilog -g2012 -o sim_uart sim/tb_uart.v rtl/blocks/uart_rx.v rtl/blocks/uart_tx.v rtl/blocks/regs_uart.v && vvp sim_uart
// Listo cuando: imprime ID = a7a7, KP = 0180 y "UART OK" (ninguna linea "UART MAL").
// Supuesto del modelo de la Pi: 115200 baudios, 8N1, LSB primero (igual que pyserial).
`timescale 1ns/1ps
module tb_uart;
    reg clk = 0; always #41.667 clk = ~clk;          // 12 MHz
    localparam BIT_NS = 8680;                         // 1 / 115200 baudios

    // ---- el diseno: igual que en el top ----
    reg  pi_tx = 1;                                   // linea que la "Pi" manda a la FPGA
    wire fpga_tx;
    wire [7:0]  rx_data, tx_data;
    wire        rx_valid, tx_start, tx_busy;
    wire [15:0] control, dac1_manual, dac2_manual, setpoint, kp;
    wire [15:0] gen_forma, gen_freq, gen_amp, gen_offset, usr_p1, usr_p2;

    // entradas de solo lectura con valores conocidos (ch0 en [15:0] ... ch7 en [127:112])
    reg [127:0] adc = {16'h8001, 16'h7FFF, 16'h0F0F, 16'hABCD,
                       16'h0001, 16'hFFFF, 16'h5555, 16'h00FF};

    uart_rx u_rx (.clk(clk), .rx(pi_tx), .data(rx_data), .valid(rx_valid));
    uart_tx u_tx (.clk(clk), .start(tx_start), .data(tx_data), .tx(fpga_tx), .busy(tx_busy));
    regs_uart u_reg (.clk(clk), .rx_data(rx_data), .rx_valid(rx_valid),
                     .tx_data(tx_data), .tx_start(tx_start), .tx_busy(tx_busy),
                     .adc(adc), .dac1_actual(12'hABC), .dac2_actual(12'h123),
                     .salidas_sd(2'b10), .build_id(16'hF195),
                     .spi_in0(16'h1111), .spi_in1(16'h2222),
                     .control(control), .dac1_manual(dac1_manual), .dac2_manual(dac2_manual),
                     .setpoint(setpoint), .kp(kp),
                     .gen_forma(gen_forma), .gen_freq(gen_freq), .gen_amp(gen_amp),
                     .gen_offset(gen_offset), .usr_p1(usr_p1), .usr_p2(usr_p2));

    // ---- la "Pi" manda: un byte en serie (inicio, 8 bits LSB primero, parada) ----
    task mandar(input [7:0] b);
        integer i;
        begin
            pi_tx = 0; #BIT_NS;
            for (i = 0; i < 8; i = i + 1) begin pi_tx = b[i]; #BIT_NS; end
            pi_tx = 1; #BIT_NS;
        end
    endtask

    // ---- la "Pi" recibe: otro uart_rx escuchando la salida de la FPGA ----
    wire [7:0] r_data; wire r_valid;
    uart_rx u_pi (.clk(clk), .rx(fpga_tx), .data(r_data), .valid(r_valid));
    reg [7:0] resp [0:1];
    integer n = 0;
    always @(posedge clk) if (r_valid) begin resp[n] = r_data; n = n + 1; end

    task leer(input [7:0] addr, output [15:0] valor);
        begin
            n = 0;
            mandar("R"); mandar(addr);
            wait (n == 2);
            valor = {resp[0], resp[1]};
        end
    endtask

    task escribir(input [7:0] addr, input [15:0] valor);
        begin
            mandar("W"); mandar(addr); mandar(valor[15:8]); mandar(valor[7:0]);
        end
    endtask

    integer errores = 0;
    task comprobar(input [7:0] addr, input [15:0] esperado);
        reg [15:0] leido;
        begin
            leer(addr, leido);
            if (leido !== esperado) begin
                $display("UART MAL: R %h -> %h (esperado %h)", addr, leido, esperado);
                errores = errores + 1;
            end
        end
    endtask

    reg [15:0] v;
    initial begin
        $dumpfile("uart.vcd"); $dumpvars(0, tb_uart);
        #20000;

        // 1) lo minimo de la guia: ID y KP
        leer(8'h00, v); $display("ID = %h (debe ser a7a7)", v);
        if (v !== 16'hA7A7) errores = errores + 1;
        escribir(8'h05, 16'h0180);
        leer(8'h05, v); $display("KP = %h (debe ser 0180)", v);
        if (kp !== 16'h0180) begin $display("UART MAL: la salida kp vale %h", kp); errores = errores + 1; end

        // 2) valores de arranque (los que la UI espera despues de cargar la FPGA)
        comprobar(8'h01, 16'd0);   comprobar(8'h02, 16'd0);   comprobar(8'h03, 16'd0);
        comprobar(8'h04, 16'd512); comprobar(8'h06, 16'd0);   comprobar(8'h07, 16'd14);
        comprobar(8'h08, 16'd256); comprobar(8'h09, 16'd512); comprobar(8'h0A, 16'd0);
        comprobar(8'h0B, 16'd0);

        // 3) escribir todos los registros de escritura con valores distintos y leerlos de vuelta
        escribir(8'h01, 16'h0003); escribir(8'h02, 16'h0FFF); escribir(8'h03, 16'h0800);
        escribir(8'h04, 16'h0300); escribir(8'h06, 16'h0002); escribir(8'h07, 16'd1398);
        escribir(8'h08, 16'h0200); escribir(8'h09, 16'h0100); escribir(8'h0A, 16'hBEEF);
        escribir(8'h0B, 16'h1234);
        comprobar(8'h01, 16'h0003); comprobar(8'h02, 16'h0FFF); comprobar(8'h03, 16'h0800);
        comprobar(8'h04, 16'h0300); comprobar(8'h05, 16'h0180); comprobar(8'h06, 16'h0002);
        comprobar(8'h07, 16'd1398); comprobar(8'h08, 16'h0200); comprobar(8'h09, 16'h0100);
        comprobar(8'h0A, 16'hBEEF); comprobar(8'h0B, 16'h1234);
        if (control !== 16'h0003 || gen_freq !== 16'd1398 || usr_p2 !== 16'h1234) begin
            $display("UART MAL: las salidas del bloque no coinciden con lo escrito"); errores = errores + 1;
        end

        // 4) registros de solo lectura
        comprobar(8'h10, 16'h00FF); comprobar(8'h11, 16'h5555); comprobar(8'h12, 16'hFFFF);
        comprobar(8'h13, 16'h0001); comprobar(8'h14, 16'hABCD); comprobar(8'h15, 16'h0F0F);
        comprobar(8'h16, 16'h7FFF); comprobar(8'h17, 16'h8001);
        comprobar(8'h18, 16'h0ABC); comprobar(8'h19, 16'h0123); comprobar(8'h1A, 16'h0002);
        comprobar(8'h1B, 16'hF195); comprobar(8'h1C, 16'h1111); comprobar(8'h1D, 16'h2222);

        // 5) cosas que no deben romper nada
        escribir(8'h00, 16'h1234); comprobar(8'h00, 16'hA7A7);   // ID no se puede escribir
        escribir(8'h18, 16'h0FFF); comprobar(8'h18, 16'h0ABC);   // solo lectura
        comprobar(8'h0F, 16'hDEAD);                              // direccion que no existe
        mandar(8'h00); mandar(8'hFF);                            // basura antes de un comando
        comprobar(8'h00, 16'hA7A7);

        // 6) lectura "partida": el ADC cambia entre el byte alto y el bajo de la respuesta.
        //    Debe llegar el valor viejo completo (00ff), nunca una mezcla (0000).
        n = 0;
        mandar("R"); mandar(8'h10);
        wait (n == 1);
        adc[15:0] = 16'h0100;
        wait (n == 2);
        v = {resp[0], resp[1]};
        if (v !== 16'h00FF) begin
            $display("UART MAL: lectura partida, llego %h (esperado 00ff)", v); errores = errores + 1;
        end
        comprobar(8'h10, 16'h0100);                              // y la siguiente ya trae el nuevo

        if (errores == 0) $display("UART OK");
        else              $display("UART MAL: %0d errores", errores);
        $finish;
    end

    initial begin #60_000_000 $display("UART MAL: timeout (la FPGA no respondio)"); $finish; end
endmodule
