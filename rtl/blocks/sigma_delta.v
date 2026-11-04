// sigma_delta: salida analogica sin chip DAC (Paso 9B.3) con el modulador de 2o orden del profesor
// (v_fpga_fpt2p16_2o_sdm.v). Mismos puertos que el de la guia: top_template.v no cambia.
// x = 0 -> 0 % de unos (0 V) ... 4095 -> ~100 % (3.3 V), igual que el PmodDA2. Despues del pin va
// el filtro paso bajo (RC + op-amp). El valor se pasa al formato del profesor (Q2.16 con signo,
// -1.0 .. +1.0): d = (x - 2048) * 32.
module sigma_delta (
    input  wire        clk,
    input  wire [11:0] x,          // 0 = 0 V ... 4095 = 3.3 V
    output wire        salida
);
    wire signed [17:0] d = ($signed({6'd0, x}) - 18'sd2048) <<< 5;
    v_fpga_fpt2p16_2o_sdm u_sdm (.d_o(salida), .clk_i(clk), .ce_i(1'b1), .d_i(d), .rstb_i(1'b1));
endmodule
