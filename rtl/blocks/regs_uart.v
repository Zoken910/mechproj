// regs_uart: interpreta los comandos de la Pi y guarda los registros
//   Escribir: 'W' (0x57), direccion, dato alto, dato bajo   -> sin respuesta
//   Leer:     'R' (0x52), direccion                        -> dato alto, dato bajo
// Cambio respecto a la guia: el valor leido se congela (dato_lat) al empezar la
// respuesta. Sin esto, el byte alto y el bajo salen con ~87 us de diferencia y
// un registro que cambia solo (ADC cada 100 us, SPI_IN) puede llegar "partido"
// (alto de una muestra, bajo de la siguiente). El protocolo no cambia.
module regs_uart (
    input  wire         clk,
    input  wire [7:0]   rx_data,
    input  wire         rx_valid,
    output reg  [7:0]   tx_data  = 0,
    output reg          tx_start = 0,
    input  wire         tx_busy,
    input  wire [127:0] adc,                 // 8 canales x 16 bits con signo (AD7606)
    input  wire [11:0]  dac1_actual, dac2_actual,
    input  wire [1:0]   salidas_sd,          // que canal sale por sigma-delta (lo fija el generador)
    input  wire [15:0]  build_id,            // huella del diagrama cargado (lo fija el generador)
    input  wire [15:0]  spi_in0, spi_in1,    // ultimos valores que mando la Pi por SPI
    // registros de escritura (todos se pueden leer de vuelta con "R")
    output reg  [15:0]  control     = 0,
    output reg  [15:0]  dac1_manual = 0,
    output reg  [15:0]  dac2_manual = 0,
    output reg  [15:0]  setpoint    = 16'd512,
    output reg  [15:0]  kp          = 16'd256,
    output reg  [15:0]  gen_forma   = 16'd0,    // 0 seno, 1 cuadrada, 2 triangulo, 3 sierra
    output reg  [15:0]  gen_freq    = 16'd14,   // x 0.715 Hz -> 10 Hz
    output reg  [15:0]  gen_amp     = 16'd256,  // 0..512
    output reg  [15:0]  gen_offset  = 16'd512,  // 512 = 0 V
    output reg  [15:0]  usr_p1      = 16'd0,    // parametros libres del bloque Verilog
    output reg  [15:0]  usr_p2      = 16'd0
);
    reg [2:0]  st  = 0;
    reg [7:0]  cmd = 0, addr = 0, hi = 0;
    reg [15:0] dato;                 // combinacional: lo que vale la direccion pedida
    reg [15:0] dato_lat = 0;         // copia congelada mientras se manda la respuesta

    always @(*) begin                // que se responde al leer
        case (addr)
            8'h00: dato = 16'hA7A7;
            8'h01: dato = control;     8'h02: dato = dac1_manual;
            8'h03: dato = dac2_manual; 8'h04: dato = setpoint;
            8'h05: dato = kp;
            8'h06: dato = gen_forma;   8'h07: dato = gen_freq;
            8'h08: dato = gen_amp;     8'h09: dato = gen_offset;
            8'h0A: dato = usr_p1;      8'h0B: dato = usr_p2;
            8'h10: dato = adc[ 15:  0]; 8'h11: dato = adc[ 31: 16];
            8'h12: dato = adc[ 47: 32]; 8'h13: dato = adc[ 63: 48];
            8'h14: dato = adc[ 79: 64]; 8'h15: dato = adc[ 95: 80];
            8'h16: dato = adc[111: 96]; 8'h17: dato = adc[127:112];
            8'h18: dato = {4'd0, dac1_actual};
            8'h19: dato = {4'd0, dac2_actual};
            8'h1A: dato = {14'd0, salidas_sd};
            8'h1B: dato = build_id;
            8'h1C: dato = spi_in0;
            8'h1D: dato = spi_in1;
            default: dato = 16'hDEAD;
        endcase
    end

    always @(posedge clk) begin
        tx_start <= 0;
        case (st)
            0: if (rx_valid) begin cmd <= rx_data; if (rx_data == "W" || rx_data == "R") st <= 1; end
            1: if (rx_valid) begin addr <= rx_data; st <= (cmd == "R") ? 4 : 2; end
            2: if (rx_valid) begin hi <= rx_data; st <= 3; end
            3: if (rx_valid) begin
                   case (addr)
                       8'h01: control     <= {hi, rx_data};
                       8'h02: dac1_manual <= {hi, rx_data};
                       8'h03: dac2_manual <= {hi, rx_data};
                       8'h04: setpoint    <= {hi, rx_data};
                       8'h05: kp          <= {hi, rx_data};
                       8'h06: gen_forma   <= {hi, rx_data};
                       8'h07: gen_freq    <= {hi, rx_data};
                       8'h08: gen_amp     <= {hi, rx_data};
                       8'h09: gen_offset  <= {hi, rx_data};
                       8'h0A: usr_p1      <= {hi, rx_data};
                       8'h0B: usr_p2      <= {hi, rx_data};
                       default: ;                       // solo lectura o no existe: se ignora
                   endcase
                   st <= 0;
               end
            4: if (!tx_busy) begin
                   dato_lat <= dato;                    // congela el valor completo
                   tx_data  <= dato[15:8]; tx_start <= 1; st <= 5;
               end
            5: st <= 6;                                  // da tiempo a que tx_busy suba
            6: if (!tx_busy) begin tx_data <= dato_lat[7:0]; tx_start <= 1; st <= 0; end
            default: st <= 0;
        endcase
    end
endmodule
