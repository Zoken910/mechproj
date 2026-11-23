// filtro_media: promedio movil de 2^LOG2N muestras (Paso 9.2). Formato de la cadena (512 = 0 V).
// Toma una muestra con cada pulso de 'muestra' (adc_nueva, 10 kHz): asi siempre promedia muestras
// distintas del ADC aunque se cambie la frecuencia de muestreo. (La version de la guia tenia su
// propio contador DIV = 1200 y dependia de que coincidiera con el del ADC: known issue 4.)
// Arranca lleno de 512 (0 V), no de 0 (-rango).
// Con LOG2N = 3: 8 muestras = 0.8 ms de ventana a 10 kHz. LOG2N entre 1 y 6.
module filtro_media #(parameter LOG2N = 3) (
    input  wire       clk,
    input  wire       muestra,        // pulso de 1 ciclo con cada muestra nueva
    input  wire [9:0] x,
    output reg  [9:0] y = 10'd512
);
    localparam N = 1 << LOG2N;
    reg [9:0]       hist [0:N-1];                 // las ultimas N muestras
    reg [LOG2N-1:0] p    = 0;                     // donde va la siguiente
    reg [9+LOG2N:0] suma = 512 * N;               // suma de las N muestras
    integer i;
    initial for (i = 0; i < N; i = i + 1) hist[i] = 10'd512;

    always @(posedge clk) begin
        if (muestra) begin
            suma    <= suma + x - hist[p];        // entra la nueva, sale la mas vieja
            hist[p] <= x;
            p       <= p + 1;
        end
        y <= suma[9+LOG2N:LOG2N];                 // dividir entre N = quitar LOG2N bits
    end
endmodule
