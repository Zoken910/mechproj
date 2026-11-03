// dac_pmodda2: driver del PmodDA2 (dos DAC121S101 de 12 bits con SYNC y SCLK compartidos).
// Salida: valor 0 = 0 V ... 4095 = 3.3 V (VA del Pmod = 3.3 V). Se actualiza continuamente.
//
// Trama de 16 bits por canal, el bit mas alto primero (datasheet DAC121S101):
//   DB15..DB14 = no importan, DB13..DB12 = PD1 PD0 (00 = funcionamiento normal), DB11..DB0 = dato
// El DAC lee DIN en cada BAJADA de SCLK y actualiza la salida en la 16a bajada. Si SYNC sube
// antes de la 16a bajada, la trama se descarta.
//
// Cambio respecto a la guia: SCLK descansa en BAJO. Asi SYNC baja con SCLK quieto en bajo, luego
// viene una subida (tSUCL >= 0 ns se cumple al pie de la letra) y despues las 16 bajadas.
// DIN cambia en cada subida y el DAC lo lee en la bajada: medio periodo de setup y de hold.
// Los puertos y el parametro son los mismos de la guia, top_template.v no cambia.
//
// Con CLK_DIV = 1: SCLK = 12 MHz / 2 = 6 MHz (maximo 30 MHz). Una trama dura 3 + 32*CLK_DIV
// ciclos = 35 ciclos = 2.9 us, unas 343 000 actualizaciones por segundo: mucho mas rapido que
// el ADC (10 000/s) y que el tiempo de asentamiento del DAC (~8 us).
module dac_pmodda2 #(parameter CLK_DIV = 1) (   // medio periodo de SCLK = CLK_DIV ciclos de 12 MHz
    input  wire        clk,
    input  wire [11:0] valor_a,                 // DAC 1 (DINA)
    input  wire [11:0] valor_b,                 // DAC 2 (DINB)
    output reg         sync_n = 1,
    output reg         sclk   = 0,
    output wire        dina,
    output wire        dinb
);
    localparam CARGA = 0, ENVIO = 1, FIN = 2, PAUSA = 3;
    reg [15:0] sa = 0, sb = 0;
    reg [3:0]  bit_cnt = 0;                     // bajadas ya dadas (0..15)
    reg [7:0]  div     = 0;
    reg [1:0]  estado  = CARGA;

    assign dina = sa[15];
    assign dinb = sb[15];

    always @(posedge clk) begin
        case (estado)
            CARGA: begin                        // copia los valores UNA vez por trama: nunca sale
                sa <= {4'b0000, valor_a};       // una trama mezclada si el valor cambia a mitad
                sb <= {4'b0000, valor_b};
                sync_n <= 0; bit_cnt <= 0; div <= 0; estado <= ENVIO;
            end
            ENVIO: if (div == CLK_DIV - 1) begin
                div <= 0;
                if (!sclk) begin                // subida: el DAC no lee aqui; pasa al bit siguiente
                    sclk <= 1;                  // (la primera subida no mueve nada: DB15 ya esta en DIN)
                    if (bit_cnt != 0) begin sa <= sa << 1; sb <= sb << 1; end
                end else begin                  // bajada: el DAC lee DINA y DINB
                    sclk <= 0;
                    bit_cnt <= bit_cnt + 1;
                    if (bit_cnt == 15) estado <= FIN;   // fue la 16a bajada: el DAC ya actualizo
                end
            end else div <= div + 1;
            FIN:   begin sync_n <= 1; estado <= PAUSA; end   // SYNC sube 1 ciclo despues de la 16a bajada
            PAUSA: estado <= CARGA;                          // SYNC en alto 2 ciclos = 167 ns (min 20 ns)
        endcase
    end
endmodule
