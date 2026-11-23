// Prueba del sistema completo del Paso 9: top_template.v + la cadena de la demo de velocidad
// (rtl/paso9/cadena_paso9.v) con el lazo cerrado sobre un motor DC simulado.
//   "Pi" por UART -> uart parser -> register -> PID -> DAC1 (modelo DAC121S101) -> motor DC
//   (modelo) -> sensor -> AD7606 (modelo) canal 0 -> filtro -> PID ... y la "Pi" mira por SPI.
// Correr (tarda ~1 minuto: simula 0.15 s de tiempo real a 12 MHz con todo el top):
//   iverilog -g2012 -o sim_paso9 sim/tb_paso9.v sim/modelo_ad7606.v sim/modelo_dac121s101.v \
//            sim/modelo_motor_dc.v rtl/top_template.v rtl/paso9/cadena_paso9.v rtl/blocks/uart_rx.v \
//            rtl/blocks/uart_tx.v rtl/blocks/uart_parser.v rtl/blocks/registros.v rtl/blocks/adc_ad7606.v \
//            rtl/blocks/dac_pmodda2.v rtl/blocks/spi_stream.v rtl/blocks/sigma_delta.v \
//            rtl/blocks/v_fpga_fpt2p16_2o_sdm.v rtl/blocks/filtro_media.v rtl/blocks/control_pid.v && vvp sim_paso9
// Listo cuando: imprime "PASO9 OK". Es lo mismo que hace pi/prueba_pid.py en la placa.
// Motor del modelo con tau = 10 ms (para que la simulacion no tarde mucho); con el motor real
// las ganancias seran otras: ver docs/paso9.md (como ajustar el PID).
`timescale 1ns/1ps
module tb_paso9;
    reg clk = 0; always #41.667 clk = ~clk;          // 12 MHz
    localparam BIT_NS = 8680;                         // 115200 baudios

    reg  pi_tx = 1, sck = 0, cs_n = 1;
    wire fpga_tx, miso, convst, adc_rst, adc_cs, adc_sclk, busy, douta, doutb;
    wire dsync, dsclk, da, db;
    wire [1:0] sd, led;
    top dut (.clk(clk), .uart_rx_pin(pi_tx), .uart_tx_pin(fpga_tx),
             .adc_convst(convst), .adc_reset(adc_rst), .adc_cs_n(adc_cs), .adc_sclk(adc_sclk),
             .adc_douta(douta), .adc_doutb(doutb), .adc_busy(busy),
             .dac_sync_n(dsync), .dac_sclk(dsclk), .dac_dina(da), .dac_dinb(db), .sd_out(sd),
             .pi_sck(sck), .pi_cs_n(cs_n), .pi_mosi(1'b0), .pi_miso(miso), .led(led));

    // ---- el hardware alrededor: DAC, motor con su sensor y ADC ----
    dac121s101_modelo #(.NOMBRE("DAC1")) dac1 (.sync_n(dsync), .sclk(dsclk), .din(da));
    dac121s101_modelo #(.NOMBRE("DAC2")) dac2 (.sync_n(dsync), .sclk(dsclk), .din(db));
    wire [11:0] codigo_dac1 = dac1.codigo;
    wire [15:0] sensor;
    motor_dc_modelo #(.TAU(0.01)) motor (.paso(convst), .codigo_dac(codigo_dac1), .codigo_adc(sensor));
    // canal 0 = sensor de velocidad; los demas, valores fijos para ver que no se mezclan
    ad7606_modelo adc (.convst(convst), .cs_n(adc_cs), .sclk(adc_sclk), .busy(busy), .douta(douta), .doutb(doutb),
                       .canales({16'h7000, 16'h6000, 16'h5000, 16'h4000, 16'h3000, 16'h2000, 16'h1000, sensor}));

    // ---- la "Pi" por UART (igual que tb_paso7.v) ----
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
    reg [15:0] leido;
    task leer(input [7:0] a); begin
        n = 0; mandar("R"); mandar(a); wait (n == 2); leido = {resp[0], resp[1]};
    end endtask

    integer errores = 0;
    task comprobar(input [7:0] a, input [15:0] esperado); begin
        leer(a);
        if (leido !== esperado) begin
            $display("PASO9 MAL: R 0x%h -> %h (esperado %h)", a, leido, esperado); errores = errores + 1;
        end
    end endtask

    // ---- la "Pi" por SPI: una foto de 12 palabras (modo 0, 1 MHz) ----
    reg [191:0] foto;
    task leer_spi; integer k; begin
        cs_n = 0; #2000;
        for (k = 0; k < 192; k = k + 1) begin sck = 1; foto = {foto[190:0], miso}; #500; sck = 0; #500; end
        #1000 cs_n = 1; #2000;
    end endtask

    // medida del lazo vista por la Pi: R 0x10 (ADC canal 0) pasado a la cadena
    integer medida, error, error_abs, t_ms = 0, k2;
    task medir_lazo(input [9:0] setpoint); begin
        leer(8'h10);
        medida = {~leido[15], leido[14:6]};
        error = setpoint - medida;
        error_abs = error < 0 ? -error : error;
    end endtask
    task esperar_ms(input integer ms, input integer imprimir); begin
        for (k2 = 0; k2 < ms; k2 = k2 + 1) begin
            #1_000_000;
            if (imprimir && k2 % 4 == 0)
                $display("    t = %3d ms  medida (sensor) %4d  DAC1 %4d (%5.2f V al motor)  %5.0f rpm",
                         t_ms, {~sensor[15], sensor[14:6]}, codigo_dac1, (codigo_dac1 * 3.3 / 4096 - 1.65) * 5 / 1.65, motor.rpm);
            t_ms = t_ms + 1;
        end
    end endtask

    initial begin
        #200_000;
        // 1) lo basico: ID, huella "paso 9", ganancias de arranque, salidas apagadas
        comprobar(8'h00, 16'hA7A7);
        comprobar(8'h1B, 16'h0009);
        comprobar(8'h05, 16'd256); comprobar(8'h0C, 16'd0); comprobar(8'h0D, 16'd0);
        comprobar(8'h18, 16'd0);

        // 2) modo manual: DAC1 = 2048 = 1.65 V = 0 V al motor
        escribir(8'h02, 16'd2048); escribir(8'h01, 16'h0001);
        esperar_ms(2, 0);
        if (codigo_dac1 !== 12'd2048) begin $display("PASO9 MAL: manual, DAC1 = %0d", codigo_dac1); errores = errores + 1; end

        // 3) lazo cerrado, solo P (Kp = 2): llega pero con error
        escribir(8'h05, 16'd512); escribir(8'h04, 16'd712); escribir(8'h01, 16'h0003);
        esperar_ms(40, 0);
        medir_lazo(712);
        $display("  P solo (KP = 512): setpoint 712, medida %0d, error %0d", medida, error);
        if (error_abs < 20) begin $display("PASO9 MAL: el P solo deberia dejar error"); errores = errores + 1; end

        // 4) PI: KI = 13107 (200 /s, Ti = 10 ms = tau del motor del modelo)
        escribir(8'h0C, 16'd13107);
        esperar_ms(50, 1);
        medir_lazo(712);
        $display("  PI (KI = 13107): medida %0d, error %0d", medida, error);
        if (error_abs > 3) begin $display("PASO9 MAL: el PI no llevo el error a 0"); errores = errores + 1; end
        comprobar(8'h0C, 16'd13107);

        // 5) escalon del setpoint hacia abajo (el motor gira al reves)
        escribir(8'h04, 16'd412);
        esperar_ms(50, 0);
        medir_lazo(412);
        $display("  setpoint 412 (al reves): medida %0d, error %0d", medida, error);
        if (error_abs > 3) begin $display("PASO9 MAL: no sigue el setpoint"); errores = errores + 1; end

        // 6) la foto por SPI: A5A5, contador, canales fijos y lo que sale por el DAC1
        leer_spi;
        $display("  SPI: palabra 0 = %h, contador = %0d, canal 1 = %h, DAC1 = %0d (modelo del DAC: %0d)",
                 foto[191:176], foto[175:160], foto[143:128], foto[31:16], codigo_dac1);
        if (foto[191:176] !== 16'hA5A5 || foto[143:128] !== 16'h1000
            || ($signed(foto[159:144]) > $signed(sensor) + 128) || ($signed(foto[159:144]) + 128 < $signed(sensor))
            || (foto[31:16] > codigo_dac1 + 8) || (foto[31:16] + 8 < codigo_dac1)) begin
            $display("PASO9 MAL: la foto SPI no coincide"); errores = errores + 1;
        end

        // 7) apagar: la salida vuelve a 0 y el PID se reinicia
        escribir(8'h01, 16'h0000);
        esperar_ms(1, 0);
        if (codigo_dac1 !== 12'd0 || led !== 2'b00) begin
            $display("PASO9 MAL: apagado, DAC1 = %0d, LEDs = %b", codigo_dac1, led); errores = errores + 1;
        end

        errores = errores + dac1.errores + dac2.errores;
        if (errores == 0) $display("PASO9 OK");
        else              $display("PASO9 MAL: %0d errores", errores);
        $finish;
    end
    initial begin #400_000_000 $display("PASO9 MAL: timeout"); $finish; end
endmodule
