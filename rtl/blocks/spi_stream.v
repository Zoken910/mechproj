// spi_stream: SPI esclavo (modo 0) con la Raspberry Pi, en los dos sentidos (Paso 8).
// FPGA -> Pi (MISO): cada vez que la Pi baja CS, la FPGA congela una "foto" de PALABRAS x 16 bits
//                    y la manda, palabra 0 primero y de cada palabra el bit mas alto primero.
// Pi -> FPGA (MOSI): en la misma transferencia la Pi manda 3 palabras: 0x5A5A, valor0, valor1.
//                    Al subir CS, si llegaron 48 bits o mas y la primera palabra es 0x5A5A,
//                    rx0 y rx1 toman los valores nuevos. Si la Pi manda ceros (solo quiere leer),
//                    o corta la transferencia antes de 48 bits, rx0 y rx1 no cambian.
// SCK, CS y MOSI se sincronizan con el reloj de 12 MHz (3 flip-flops): la FPGA ve cada flanco
// ~250 ns tarde, por eso la Pi debe usar SCLK <= 1 MHz (en simulacion funciona hasta 2 MHz).
// Cambio respecto a la guia: la foto se recarga mientras CS esta en alto y el contador de bits se
// pone a 0 con CS en alto (no en el flanco de CS). Asi no importa cuanto tarde la Pi entre bajar
// CS y el primer flanco de SCLK (la version de la guia necesitaba >= 300 ns).
module spi_stream #(parameter PALABRAS = 12) (
    input  wire                    clk,
    input  wire                    sck,
    input  wire                    cs_n,
    input  wire                    mosi,
    output wire                    miso,
    input  wire [16*PALABRAS-1:0]  datos,           // palabra 0 en [15:0]
    output reg  [15:0]             rx0 = 16'd512,   // arrancan en 512 = 0 V
    output reg  [15:0]             rx1 = 16'd512
);
    reg [2:0] sck_s = 0, cs_s = 3'b111, mosi_s = 0;
    always @(posedge clk) begin
        sck_s  <= {sck_s[1:0],  sck};
        cs_s   <= {cs_s[1:0],   cs_n};
        mosi_s <= {mosi_s[1:0], mosi};
    end
    wire sck_baja = (sck_s[2:1] == 2'b10);
    wire sck_sube = (sck_s[2:1] == 2'b01);
    wire cs_sube  = (cs_s[2:1]  == 2'b01);
    wire activo   = !cs_s[1];

    // ---- salida hacia la Pi ----
    reg [16*PALABRAS-1:0] sr = 0;
    assign miso = sr[16*PALABRAS-1];                 // bit mas alto primero
    integer i;
    always @(posedge clk) begin
        if (!activo)                                 // con CS en alto la foto se recarga siempre:
            for (i = 0; i < PALABRAS; i = i + 1)     // al bajar CS el primer bit ya esta en MISO
                sr[16*(PALABRAS-1-i) +: 16] <= datos[16*i +: 16];   // (palabra 0 hasta arriba)
        else if (sck_baja)
            sr <= sr << 1;                           // en modo 0 el dato cambia en la bajada
    end

    // ---- entrada desde la Pi ----
    reg [47:0] rin = 0;
    reg [5:0]  n   = 0;                              // bits recibidos (se detiene en 48)
    always @(posedge clk) begin
        if (!activo) n <= 0;                         // CS en alto: lista para la siguiente
        else if (sck_sube && n < 48) begin           // en modo 0 se lee en la subida
            rin <= {rin[46:0], mosi_s[1]};
            n   <= n + 1;
        end
        if (cs_sube && n == 48 && rin[47:32] == 16'h5A5A) begin
            rx0 <= rin[31:16];
            rx1 <= rin[15:0];
        end
    end
endmodule
