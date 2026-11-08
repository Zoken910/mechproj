// Prueba de los Pasos 6 a 8 juntos (guia, Paso 8): ADC + DAC + SPI hacia la Pi.
// Correr:
//   iverilog -g2012 -o sim_io sim/tb_io.v rtl/blocks/adc_ad7606.v rtl/blocks/dac_pmodda2.v rtl/blocks/spi_stream.v && vvp sim_io
// Listo cuando: imprime "ADC: 5555ffff0001abcd0f0f7fff80011234", "SPI OK" y mas de 0 tramas de DAC
// correctas, sin ningun "MAL".
`timescale 1ns/1ps
module tb_io;
    reg clk = 0; always #41.667 clk = ~clk;          // 12 MHz

    // ---- modelo sencillo del AD7606: 8 valores fijos conocidos ----
    reg [15:0] ch [0:7];
    initial begin
        ch[0] = 16'h1234; ch[1] = 16'h8001; ch[2] = 16'h7FFF; ch[3] = 16'h0F0F;
        ch[4] = 16'hABCD; ch[5] = 16'h0001; ch[6] = 16'hFFFF; ch[7] = 16'h5555;
    end
    wire convst, rst, cs_n, sclk; reg busy = 0;
    reg [63:0] sha, shb;
    always @(posedge convst) begin #40 busy = 1; #4000 busy = 0; end              // convierte 4 us
    always @(negedge cs_n) begin sha = {ch[0], ch[1], ch[2], ch[3]}; shb = {ch[4], ch[5], ch[6], ch[7]}; end
    always @(posedge sclk) if (!cs_n) begin #10 sha = sha << 1; shb = shb << 1; end
    wire [127:0] valores; wire nueva;
    adc_ad7606 u_adc (.clk(clk), .convst(convst), .reset(rst), .cs_n(cs_n), .sclk(sclk),
                      .douta(sha[63]), .doutb(shb[63]), .busy(busy), .valores(valores), .nueva(nueva));

    // ---- DAC: se capturan los 16 bits en cada bajada de SCLK ----
    wire dsync, dsclk, da, db; reg [15:0] ra, rb; integer nbits = 0, tramas_ok = 0, dac_mal = 0;
    dac_pmodda2 u_dac (.clk(clk), .valor_a(12'hABC), .valor_b(12'h123),
                       .sync_n(dsync), .sclk(dsclk), .dina(da), .dinb(db));
    always @(negedge dsclk) if (!dsync) begin ra = {ra[14:0], da}; rb = {rb[14:0], db}; nbits = nbits + 1; end
    always @(posedge dsync) begin
        if (nbits == 16 && ra == 16'h0ABC && rb == 16'h0123) tramas_ok = tramas_ok + 1;
        else if (nbits != 0) begin $display("DAC MAL: %0d bits, %h %h", nbits, ra, rb); dac_mal = dac_mal + 1; end
        nbits = 0;
    end

    // ---- la Pi como maestro SPI a 1 MHz, modo 0 ----
    reg pck = 0, pcs = 1; wire pmiso; reg [191:0] rx;
    spi_stream #(.PALABRAS(12)) u_spi (.clk(clk), .sck(pck), .cs_n(pcs), .mosi(1'b0), .miso(pmiso),
        .datos({16'h0123, 16'h0ABC, valores, 16'h0007, 16'hA5A5}), .rx0(), .rx1());

    integer k, i, mal = 0;
    initial begin
        @(posedge nueva); @(posedge nueva);                                      // dos lecturas completas
        for (i = 0; i < 8; i = i + 1)
            if (valores[16*i +: 16] !== ch[i]) begin
                $display("ADC MAL canal %0d: %h", i, valores[16*i +: 16]); mal = mal + 1;
            end
        $display("ADC: %h", valores);
        pcs = 0; #1000;
        for (k = 0; k < 192; k = k + 1) begin #500 pck = 1; rx = {rx[190:0], pmiso}; #500 pck = 0; end
        #500 pcs = 1;
        if (rx === {16'hA5A5, 16'h0007, ch[0], ch[1], ch[2], ch[3], ch[4], ch[5], ch[6], ch[7], 16'h0ABC, 16'h0123})
            $display("SPI OK");
        else begin $display("SPI MAL: %h", rx); mal = mal + 1; end
        $display("DAC: %0d tramas correctas", tramas_ok);
        if (mal == 0 && dac_mal == 0 && tramas_ok > 0) $display("IO OK"); else $display("IO MAL");
        $finish;
    end
endmodule
