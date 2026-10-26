// Envoltura del blinky exportado de Icestudio (Paso 4.2).
// Se llama top_ice.v para no pisar rtl/top.v (Paso 3): los dos definen "module top",
// asi que NUNCA se compilan juntos. Levi compila solo:
//     rtl/top_ice.v  rtl/blinky_ice.v  rtl/cmod_a7.xdc
//
// Los nombres de ESTE modulo (clk, led) son los del XDC; los del modulo "main"
// los inventa Icestudio. Abre rtl/blinky_ice.v, busca "module main (" y copia
// aqui sus nombres reales. Icestudio pone el nombre de cada pin como comentario
// junto al puerto (// clk, // led), asi sabes cual es cual.
module top (
    input  wire       clk,
    output wire [1:0] led
);
    main u_icestudio (
        .clk_v18fa2f(clk),       // <- reemplaza por el puerto de entrada "clk" de main
        .led_v253fb0(led[0])     // <- reemplaza por el puerto de salida "led" de main
        // Si main tiene puertos extra (por ejemplo "vinit"), dejalos sin conectar.
    );
    assign led[1] = 1'b0;    // el blinky de Icestudio solo maneja un LED
endmodule
