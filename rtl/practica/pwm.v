// PWM de practica (Paso 4.3). No se usa en el sistema final:
// vive en rtl/practica/ para que no entre en el "rtl/blocks/*.v" de yosys (Paso 9.5).
// 12 MHz / 2^BITS = 11.7 kHz con BITS = 10.
module pwm #(parameter BITS = 10) (
    input  wire            clk,
    input  wire [BITS-1:0] duty,     // 0 = apagado, 1023 = casi 100 %
    output reg             salida = 0
);
    reg [BITS-1:0] cnt = 0;
    always @(posedge clk) begin
        cnt    <= cnt + 1;
        salida <= (cnt < duty);      // registrada: va un ciclo detras de cnt
    end
endmodule
