// control_pid: bloque "PID" (reunion con el profe del 17.11.2026). Reemplaza al control_p de la
// guia (Paso 9.1): con KI = KD = 0 hace lo mismo que un controlador P.
// La demo: regular la velocidad de un motor DC con el voltaje que le llega.
//
//   e = setpoint - medida
//   u = Kp*e  +  suma de Ki*e  +  Kd*(medida_anterior - medida)
//   y = 512 + u, recortada a Y_MIN..Y_MAX
//
// Formato de la cadena (10 bits, 512 = 0 V). Con la etapa de salida de los op-amps
// (0..3.3 V -> +-5 V) 512 sale como 0 V, 1023 como +5 V y 0 como -5 V: el PID puede frenar, no
// solo "dejar de empujar". Si el driver del motor solo acepta voltajes positivos, instanciar con
// Y_MIN = 512. (El control_p de la guia sacaba 0..1023 con los negativos en 0: con la etapa de
// +-5 V, error 0 hubiera dado -5 V en el motor.)
//
// Ganancias (registros de 16 bits sin signo, se cambian en vivo desde la UI):
//   KP (0x05): 256 = 1.0 (igual que antes)
//   KI (0x0C): por tick, 65536 = 1.0.  Con el tick de 1 kHz: Ki [1/s] = KI x 1000 / 65536 = KI x 0.0153
//   KD (0x0D): por tick, 256 = 1.0.    Con el tick de 1 kHz: Kd [s]   = KD / 256 / 1000   = KD x 3.9 us
// Tick: el PID calcula una vez cada DIV muestras nuevas del ADC ('muestra' = adc_nueva, 10 kHz;
// DIV = 10 -> 1 kHz). Si el ADC deja de mandar muestras, el PID se queda quieto: no integra un
// error viejo (eso llevaria el motor al maximo).
// enable = 0 (salidas apagadas o modo manual): y = Y_REPOSO y la integral se borra, asi no se
// acumula error mientras el lazo esta abierto.
// Anti-windup: la integral no crece mientras la salida esta saturada en la direccion del error,
// y nunca pasa de +-512 (lo que cabe en la salida).
// Derivada sobre la medida (no sobre el error): mover el setpoint no da un pico en la salida.
// La derivada amplifica el ruido: poner un filtro_media antes de la entrada 'medida'.
module control_pid #(parameter DIV      = 10,     // muestras del ADC por calculo (10 -> 1 kHz)
                     parameter Y_MIN    = 0,      // limites de la salida (512 = 0 V)
                     parameter Y_MAX    = 1023,
                     parameter Y_REPOSO = 512) (  // salida con el lazo apagado (512 = 0 V)
    input  wire        clk,
    input  wire        enable,          // control[0] & control[1]: salidas on y lazo cerrado
    input  wire        muestra,         // pulso de 1 ciclo con cada muestra nueva del ADC
    input  wire [9:0]  setpoint,        // 0..1023, 512 = 0 V
    input  wire [9:0]  medida,
    input  wire [15:0] kp, ki, kd,
    output reg  [9:0]  y = Y_REPOSO
);
    localparam signed [31:0] I_MAX = 32'sd512 <<< 16;     // integral maxima: 512 LSB de salida
    localparam signed [24:0] YMIN  = Y_MIN, YMAX = Y_MAX;

    // ---- tick: una vez cada DIV muestras (el primero, DIV muestras despues de encender) ----
    reg [15:0] cuenta = 0;
    reg        tick   = 0;
    always @(posedge clk) begin
        tick <= 0;
        if (!enable) cuenta <= 0;
        else if (muestra) begin
            if (cuenta >= DIV - 1) begin cuenta <= 0; tick <= 1; end
            else cuenta <= cuenta + 1;
        end
    end

    // ---- el calculo, en 4 pasos despues de cada tick (4 ciclos = 0.3 us, nada frente a 1 ms) ----
    reg [2:0]          paso       = 0;
    reg [9:0]          medida_ant = 0;
    reg signed [11:0]  e          = 0;        // setpoint - medida: -1023..+1023
    reg signed [11:0]  dm         = 0;        // medida_anterior - medida
    reg signed [28:0]  p_prod     = 0;        // e x KP   (8 bits de fraccion)
    reg signed [28:0]  i_prod     = 0;        // e x KI   (16 bits de fraccion)
    reg signed [28:0]  d_prod     = 0;        // dm x KD  (8 bits de fraccion)
    reg signed [31:0]  integral   = 0;        // suma de e x KI (16 bits de fraccion)
    reg                sat_alto   = 0, sat_bajo = 0;   // la ultima salida quedo recortada

    wire signed [32:0] i_nueva = integral + i_prod;
    // u con 16 bits de fraccion; +32768 = redondear al entero mas cercano
    wire signed [39:0] u_q16   = (p_prod <<< 8) + integral + (d_prod <<< 8) + 40'sd32768;
    wire signed [24:0] v       = 25'sd512 + (u_q16 >>> 16);

    always @(posedge clk) begin
        if (!enable) begin
            y          <= Y_REPOSO;
            integral   <= 0;
            sat_alto   <= 0;
            sat_bajo   <= 0;
            medida_ant <= medida;                 // al encender, la derivada no ve un salto viejo
            paso       <= 0;
        end else case (paso)
            0: if (tick) begin
                   e          <= $signed({2'b00, setpoint}) - $signed({2'b00, medida});
                   dm         <= $signed({2'b00, medida_ant}) - $signed({2'b00, medida});
                   medida_ant <= medida;
                   paso       <= 1;
               end
            1: begin
                   p_prod <= e  * $signed({1'b0, kp});
                   i_prod <= e  * $signed({1'b0, ki});
                   d_prod <= dm * $signed({1'b0, kd});
                   paso   <= 2;
               end
            2: begin                              // integral con anti-windup
                   if (!(sat_alto && e > 0) && !(sat_bajo && e < 0)) begin
                       if      (i_nueva >  I_MAX) integral <=  I_MAX;
                       else if (i_nueva < -I_MAX) integral <= -I_MAX;
                       else                       integral <= i_nueva[31:0];
                   end
                   paso <= 3;
               end
            3: begin                              // salida recortada
                   if      (v > YMAX) y <= Y_MAX;
                   else if (v < YMIN) y <= Y_MIN;
                   else               y <= v[9:0];
                   sat_alto <= (v > YMAX);
                   sat_bajo <= (v < YMIN);
                   paso     <= 0;
               end
            default: paso <= 0;
        endcase
    end
endmodule
