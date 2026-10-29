// uart_rx: recibe bytes por UART (1 inicio, 8 datos LSB primero, 1 parada)
// 12 MHz / 115200 baudios = 104 ciclos por bit (error 0.16 %, sin problema)
module uart_rx #(parameter CLKS_PER_BIT = 104) (
    input  wire       clk,
    input  wire       rx,
    output reg  [7:0] data  = 0,
    output reg        valid = 0      // pulso de 1 ciclo con cada byte nuevo
);
    reg [1:0] sync = 2'b11;          // sincronizador (2 FF) contra metaestabilidad
    reg [7:0] cnt  = 0;
    reg [2:0] bitn = 0;
    reg [1:0] st   = 0;

    always @(posedge clk) begin
        sync  <= {sync[0], rx};
        valid <= 0;
        case (st)
            0: if (!sync[1]) begin cnt <= CLKS_PER_BIT/2; st <= 1; end      // posible bit de inicio
            1: if (cnt == 0) begin                                          // mitad del bit de inicio
                   if (!sync[1]) begin cnt <= CLKS_PER_BIT-1; bitn <= 0; st <= 2; end
                   else st <= 0;                                            // era ruido
               end else cnt <= cnt - 1;
            2: if (cnt == 0) begin                                          // centro de cada bit
                   data <= {sync[1], data[7:1]};
                   cnt  <= CLKS_PER_BIT-1;
                   if (bitn == 7) st <= 3; else bitn <= bitn + 1;
               end else cnt <= cnt - 1;
            3: if (cnt == 0) begin valid <= 1; st <= 0; end                 // bit de parada
               else cnt <= cnt - 1;
        endcase
    end
endmodule
