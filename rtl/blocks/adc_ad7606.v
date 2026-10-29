// AD7606 en modo serie (pin SER/PAR/BYTE SEL en alto en el modulo).
// Lee los 8 canales cada PERIODO ciclos: 12 MHz / 1200 = 10 000 muestras/s por canal.
module adc_ad7606 #(parameter CLK_DIV = 3,     // SCLK = 12 MHz / (2*3) = 2 MHz
                    parameter PERIODO = 1200) (
    input  wire         clk,
    output reg          convst = 1,     // flanco de subida = empieza la conversion
    output reg          reset  = 1,     // pulso al encender
    output reg          cs_n   = 1,
    output reg          sclk   = 1,
    input  wire         douta,          // canales V1..V4
    input  wire         doutb,          // canales V5..V8
    input  wire         busy,           // en alto mientras convierte
    output reg  [127:0] valores = 0,    // canal 0 en [15:0] ... canal 7 en [127:112], con signo
    output reg          nueva   = 0     // pulso de 1 ciclo con cada juego de 8 valores
);
    localparam RST = 0, PAUSA = 1, CONV = 2, ESP_ALTO = 3, ESP_BAJO = 4, LEER = 5, FIN = 6;
    reg [2:0]  estado  = RST;
    reg [10:0] t       = 0;     // cuenta el periodo de muestreo
    reg [3:0]  div     = 0;
    reg [6:0]  bit_cnt = 0;
    reg [63:0] sa = 0, sb = 0;
    reg [1:0]  busy_s  = 0;     // sincronizar BUSY con nuestro reloj

    always @(posedge clk) begin
        busy_s <= {busy_s[0], busy};
        nueva  <= 0;
        t      <= (t == PERIODO - 1) ? 0 : t + 1;
        case (estado)
            RST:      if (t == 15) begin reset <= 0; estado <= PAUSA; end
            PAUSA:    if (t == PERIODO - 1) begin convst <= 0; estado <= CONV; end
            CONV:     begin convst <= 1; estado <= ESP_ALTO; end   // 83 ns en bajo (minimo 25 ns)
            ESP_ALTO: if (busy_s[1]) estado <= ESP_BAJO;
            ESP_BAJO: if (!busy_s[1]) begin cs_n <= 0; div <= 0; bit_cnt <= 0; estado <= LEER; end
            LEER: begin
                if (div == CLK_DIV - 1) begin
                    div <= 0;
                    if (sclk) sclk <= 0;                 // bajada
                    else begin                           // leer justo antes de la subida
                        sa <= {sa[62:0], douta};
                        sb <= {sb[62:0], doutb};
                        sclk <= 1;
                        bit_cnt <= bit_cnt + 1;
                        if (bit_cnt == 63) estado <= FIN;
                    end
                end else div <= div + 1;
            end
            FIN: begin
                cs_n    <= 1;
                valores <= {sb[15:0], sb[31:16], sb[47:32], sb[63:48],
                            sa[15:0], sa[31:16], sa[47:32], sa[63:48]};
                nueva   <= 1;
                estado  <= PAUSA;
            end
        endcase
    end
endmodule
