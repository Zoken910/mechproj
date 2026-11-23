// uart_parser: bloque "UART parser" (reunion con el profe del 17.11.2026).
// Entiende el protocolo de la Pi y lo convierte en accesos al bloque de registros (registros.v).
// No guarda ningun ajuste: los ajustes viven en registros.v.
//   Escribir: 'W' (0x57), direccion, dato alto, dato bajo   -> pulso 'escribir' de 1 ciclo, sin respuesta
//   Leer:     'R' (0x52), direccion                        -> manda dato alto y dato bajo por uart_tx
// Es la mitad "protocolo" del antiguo regs_uart.v: el protocolo y las direcciones no cambian.
//
// Igual que antes, el valor leido se congela (dato_lat) al empezar la respuesta: entre el byte
// alto y el bajo pasan ~87 us y un registro que cambia solo (ADC, SPI_IN) no llega "partido".
//
// Nuevo (known issue 6): si un comando queda a medias (se perdio un byte) y no llega nada en
// TIMEOUT ciclos (2 ms), el parser vuelve a esperar un comando. Antes se quedaba esperando y el
// siguiente comando se leia corrido un byte (la direccion como dato, etc.). Entre los bytes de un
// comando normal hay 87 us, asi que 2 ms nunca corta un comando bueno.
module uart_parser #(parameter TIMEOUT = 24000) (   // 24000 ciclos de 12 MHz = 2 ms
    input  wire        clk,
    input  wire [7:0]  rx_data,                     // de uart_rx
    input  wire        rx_valid,
    output reg  [7:0]  tx_data  = 0,                // hacia uart_tx
    output reg         tx_start = 0,
    input  wire        tx_busy,
    // hacia el bloque de registros
    output reg         escribir = 0,                // pulso de 1 ciclo: guardar dato_w en dir
    output reg  [7:0]  dir      = 0,                // direccion pedida (escritura y lectura)
    output reg  [15:0] dato_w   = 0,
    input  wire [15:0] dato_r                       // lo que vale 'dir' (lo calcula registros.v)
);
    localparam ESPERA_CMD = 0, ESPERA_DIR = 1, ESPERA_HI = 2, ESPERA_LO = 3,
               MANDA_HI = 4, PAUSA = 5, MANDA_LO = 6;
    reg [2:0]  st         = ESPERA_CMD;
    reg        es_lectura = 0;
    reg [7:0]  hi         = 0;
    reg [15:0] dato_lat   = 0;                      // copia congelada mientras se responde
    reg [15:0] quieto     = 0;                      // ciclos sin bytes a mitad de un comando
    wire       vencido    = (quieto == TIMEOUT - 1);

    always @(posedge clk) begin
        tx_start <= 0;
        escribir <= 0;
        // cuenta el tiempo sin bytes solo mientras faltan bytes de un comando
        if (rx_valid || st == ESPERA_CMD || st >= MANDA_HI) quieto <= 0;
        else quieto <= quieto + 1;

        case (st)
            ESPERA_CMD: if (rx_valid && (rx_data == "W" || rx_data == "R")) begin
                            es_lectura <= (rx_data == "R");
                            st <= ESPERA_DIR;
                        end                                   // cualquier otro byte se ignora
            ESPERA_DIR: if (rx_valid) begin
                            dir <= rx_data;
                            st  <= es_lectura ? MANDA_HI : ESPERA_HI;
                        end else if (vencido) st <= ESPERA_CMD;
            ESPERA_HI:  if (rx_valid) begin hi <= rx_data; st <= ESPERA_LO; end
                        else if (vencido) st <= ESPERA_CMD;
            ESPERA_LO:  if (rx_valid) begin
                            dato_w   <= {hi, rx_data};
                            escribir <= 1;                    // registros.v lo guarda en el siguiente ciclo
                            st       <= ESPERA_CMD;
                        end else if (vencido) st <= ESPERA_CMD;
            MANDA_HI:   if (!tx_busy) begin
                            dato_lat <= dato_r;               // congela el valor completo
                            tx_data  <= dato_r[15:8];
                            tx_start <= 1;
                            st       <= PAUSA;
                        end
            PAUSA:      st <= MANDA_LO;                       // da tiempo a que tx_busy suba
            MANDA_LO:   if (!tx_busy) begin
                            tx_data  <= dato_lat[7:0];
                            tx_start <= 1;
                            st       <= ESPERA_CMD;
                        end
            default:    st <= ESPERA_CMD;
        endcase
    end
endmodule
