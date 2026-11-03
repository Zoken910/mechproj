// Prueba de top_paso7.v completo: la "Pi" escribe por UART y el DAC saca el valor.
// Correr:
//   iverilog -g2012 -o sim_paso7 sim/tb_paso7.v sim/modelo_dac121s101.v rtl/paso7/top_paso7.v rtl/blocks/uart_rx.v rtl/blocks/uart_tx.v rtl/blocks/regs_uart.v rtl/blocks/adc_ad7606.v rtl/blocks/dac_pmodda2.v && vvp sim_paso7
// Listo cuando: imprime "PASO7 OK". Es lo mismo que hace pi/prueba_dac.py en la placa.
`timescale 1ns/1ps
module tb_paso7;
    reg clk = 0; always #41.667 clk = ~clk;          // 12 MHz
    localparam BIT_NS = 8680;                         // 115200 baudios

    reg  pi_tx = 1;
    wire fpga_tx, dsync, dsclk, da, db;
    wire [1:0] led;
    top dut (.clk(clk), .uart_rx_pin(pi_tx), .uart_tx_pin(fpga_tx),
             .adc_convst(), .adc_reset(), .adc_cs_n(), .adc_sclk(),
             .adc_douta(1'b0), .adc_doutb(1'b0), .adc_busy(1'b0),    // ADC sin conectar
             .dac_sync_n(dsync), .dac_sclk(dsclk), .dac_dina(da), .dac_dinb(db), .led(led));
    dac121s101_modelo #(.NOMBRE("DAC1")) dac1 (.sync_n(dsync), .sclk(dsclk), .din(da));
    dac121s101_modelo #(.NOMBRE("DAC2")) dac2 (.sync_n(dsync), .sclk(dsclk), .din(db));

    // ---- la "Pi" (igual que en tb_uart.v) ----
    task mandar(input [7:0] b); integer i; begin
        pi_tx = 0; #BIT_NS;
        for (i = 0; i < 8; i = i + 1) begin pi_tx = b[i]; #BIT_NS; end
        pi_tx = 1; #BIT_NS;
    end endtask
    wire [7:0] r_data; wire r_valid;
    uart_rx u_pi (.clk(clk), .rx(fpga_tx), .data(r_data), .valid(r_valid));
    reg [7:0] resp [0:1]; integer n = 0;
    always @(posedge clk) if (r_valid) begin resp[n] = r_data; n = n + 1; end
    task escribir(input [7:0] a, input [15:0] v); begin
        mandar("W"); mandar(a); mandar(v[15:8]); mandar(v[7:0]);
    end endtask

    integer errores = 0;
    task leer(input [7:0] a, input [15:0] esperado); begin
        n = 0; mandar("R"); mandar(a); wait (n == 2);
        if ({resp[0], resp[1]} !== esperado) begin
            $display("PASO7 MAL: R 0x%h -> %h%h (esperado %h)", a, resp[0], resp[1], esperado);
            errores = errores + 1;
        end
    end endtask
    task salida(input [11:0] e1, input [11:0] e2); begin
        repeat (2) @(dac1.nueva); #1;                 // dos tramas: el valor nuevo ya salio
        if (dac1.codigo !== e1 || dac2.codigo !== e2) begin
            $display("PASO7 MAL: el DAC saca %h/%h (esperado %h/%h)", dac1.codigo, dac2.codigo, e1, e2);
            errores = errores + 1;
        end else
            $display("  DAC1 = %h (%0.3f V)  DAC2 = %h (%0.3f V)  LEDs = %b",
                     e1, e1 * 3.3 / 4096, e2, e2 * 3.3 / 4096, led);
    end endtask

    initial begin
        #20000;
        leer(8'h00, 16'hA7A7);
        leer(8'h1B, 16'h0007);
        escribir(8'h02, 16'h0ABC); escribir(8'h03, 16'h0123);
        salida(12'h000, 12'h000);                     // CONTROL = 0: salidas apagadas aunque haya valor
        leer(8'h18, 16'h0000);
        escribir(8'h01, 16'h0001);                    // habilitar salidas
        salida(12'hABC, 12'h123);
        leer(8'h18, 16'h0ABC); leer(8'h19, 16'h0123);
        escribir(8'h02, 16'd2048); escribir(8'h03, 16'd4095);
        salida(12'd2048, 12'd4095);                   // 1.65 V y 3.3 V
        escribir(8'h01, 16'h0003);                    // lazo cerrado sin cadena: 0 V
        salida(12'h000, 12'h000);
        escribir(8'h01, 16'h0000);
        salida(12'h000, 12'h000);
        errores = errores + dac1.errores + dac2.errores;
        if (errores == 0) $display("PASO7 OK");
        else              $display("PASO7 MAL: %0d errores", errores);
        $finish;
    end
    initial begin #60_000_000 $display("PASO7 MAL: timeout"); $finish; end
endmodule
