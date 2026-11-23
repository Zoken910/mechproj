// registros: bloque "register" (reunion con el profe del 17.11.2026).
// Banco de registros de 16 bits con los ajustes que la Pi cambia en vivo (sin recompilar), y la
// tabla de todo lo que la Pi puede leer. Lo escribe y lo lee uart_parser.v; el resto del diseno
// solo usa las salidas. Mapa completo en docs/registros.md.
//   0x00        ID = 0xA7A7                                   solo lectura
//   0x01..0x0B  CONTROL, DAC1/2_MANUAL, SETPOINT, KP, GEN_*, USR_P1/2   escritura y lectura
//   0x0C, 0x0D  KI, KD (nuevos: ganancias I y D del PID, arrancan en 0 = controlador P)
//   0x10..0x1D  ADC, DAC reales, salidas sigma-delta, huella, SPI_IN    solo lectura
//   otra        se lee 0xDEAD; escribir en una direccion de solo lectura no hace nada
// Todos los registros vuelven a su valor de arranque cuando se carga un bitstream nuevo:
// la UI los tiene que volver a escribir despues de "Synthesize & Flash".
module registros (
    input  wire         clk,
    // desde uart_parser
    input  wire         escribir,            // pulso de 1 ciclo
    input  wire [7:0]   dir,
    input  wire [15:0]  dato_w,
    output reg  [15:0]  dato_r,              // combinacional: lo que vale 'dir'
    // entradas de solo lectura
    input  wire [127:0] adc,                 // 8 canales x 16 bits con signo (AD7606)
    input  wire [11:0]  dac1_actual, dac2_actual,
    input  wire [1:0]   salidas_sd,          // que salida va por sigma-delta (la fija la cadena)
    input  wire [15:0]  build_id,            // huella del diagrama cargado (la fija la cadena)
    input  wire [15:0]  spi_in0, spi_in1,    // ultimos valores que mando la Pi por SPI
    // registros de escritura (todos se pueden leer de vuelta)
    output reg  [15:0]  control     = 16'd0,     // 0x01 bit 0 salidas on, bit 1 lazo cerrado
    output reg  [15:0]  dac1_manual = 16'd0,     // 0x02 0..4095
    output reg  [15:0]  dac2_manual = 16'd0,     // 0x03
    output reg  [15:0]  setpoint    = 16'd512,   // 0x04 0..1023, 512 = 0 V
    output reg  [15:0]  kp          = 16'd256,   // 0x05 256 = 1.0
    output reg  [15:0]  gen_forma   = 16'd0,     // 0x06 0 seno, 1 cuadrada, 2 triangulo, 3 sierra, 4 ruido
    output reg  [15:0]  gen_freq    = 16'd14,    // 0x07 x 0.715 Hz -> 10 Hz
    output reg  [15:0]  gen_amp     = 16'd256,   // 0x08 0..512 (512 = rango completo)
    output reg  [15:0]  gen_offset  = 16'd512,   // 0x09 512 = 0 V
    output reg  [15:0]  usr_p1      = 16'd0,     // 0x0A parametros libres del bloque Verilog
    output reg  [15:0]  usr_p2      = 16'd0,     // 0x0B
    output reg  [15:0]  ki          = 16'd0,     // 0x0C PID: 65536 = 1.0 por tick (1 kHz)
    output reg  [15:0]  kd          = 16'd0      // 0x0D PID: 256 = 1.0 por tick
);
    always @(*) begin                        // que se responde al leer
        case (dir)
            8'h00: dato_r = 16'hA7A7;
            8'h01: dato_r = control;      8'h02: dato_r = dac1_manual;
            8'h03: dato_r = dac2_manual;  8'h04: dato_r = setpoint;
            8'h05: dato_r = kp;
            8'h06: dato_r = gen_forma;    8'h07: dato_r = gen_freq;
            8'h08: dato_r = gen_amp;      8'h09: dato_r = gen_offset;
            8'h0A: dato_r = usr_p1;       8'h0B: dato_r = usr_p2;
            8'h0C: dato_r = ki;           8'h0D: dato_r = kd;
            8'h10: dato_r = adc[ 15:  0]; 8'h11: dato_r = adc[ 31: 16];
            8'h12: dato_r = adc[ 47: 32]; 8'h13: dato_r = adc[ 63: 48];
            8'h14: dato_r = adc[ 79: 64]; 8'h15: dato_r = adc[ 95: 80];
            8'h16: dato_r = adc[111: 96]; 8'h17: dato_r = adc[127:112];
            8'h18: dato_r = {4'd0, dac1_actual};
            8'h19: dato_r = {4'd0, dac2_actual};
            8'h1A: dato_r = {14'd0, salidas_sd};
            8'h1B: dato_r = build_id;
            8'h1C: dato_r = spi_in0;
            8'h1D: dato_r = spi_in1;
            default: dato_r = 16'hDEAD;
        endcase
    end

    always @(posedge clk)
        if (escribir)
            case (dir)
                8'h01: control     <= dato_w;
                8'h02: dac1_manual <= dato_w;
                8'h03: dac2_manual <= dato_w;
                8'h04: setpoint    <= dato_w;
                8'h05: kp          <= dato_w;
                8'h06: gen_forma   <= dato_w;
                8'h07: gen_freq    <= dato_w;
                8'h08: gen_amp     <= dato_w;
                8'h09: gen_offset  <= dato_w;
                8'h0A: usr_p1      <= dato_w;
                8'h0B: usr_p2      <= dato_w;
                8'h0C: ki          <= dato_w;
                8'h0D: kd          <= dato_w;
                default: ;                       // solo lectura o no existe: se ignora
            endcase
endmodule
