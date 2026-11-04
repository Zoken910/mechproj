// v_fpga_fpt2p16_2o_sdm: modulador sigma-delta de 2o orden del profesor (v_blinky_example.v,
// 04.11.2026), sin cambios salvo los integradores con saturacion (CORREGIDO (6)).
// Entrada d_i: Q2.16 con signo (65536 = 1.0), rango util -1.0 .. +1.0 -> proporcion de unos (d+1)/2.
// Ruido conformado con NTF = (1 - z^-1)^2 (ganancias 1/4, 1/2 y realimentacion 1/4).
module v_fpga_fpt2p16_2o_sdm
(
  output wire d_o,
  input wire clk_i,
  input wire ce_i,
  input wire [17:0] d_i,
  input wire rstb_i
);


  wire signed [35:0] Gain_cast;  // sfix36_En18
  wire signed [17:0] Gain_out1;  // sfix18_En16
  wire signed [17:0] Constant2_out1;  // sfix18_En16
  wire signed [17:0] Constant1_out1;  // sfix18_En16
  wire signed [17:0] Constant_out1;  // sfix18_En16
  wire signed [17:0] Switch_out1;  // sfix18_En16
  wire signed [35:0] Gain3_cast;  // sfix36_En34
  wire signed [17:0] Gain3_out1;  // sfix18_En16
  wire signed [35:0] Gain1_cast;  // sfix36_En18
  wire signed [17:0] Gain1_out1;  // sfix18_En16
  wire signed [17:0] Add_out1;  // sfix18_En16
  reg signed [17:0] Discrete_Time_Integrator_x_reg;  // sfix18_En16
 
  wire signed [17:0] Discrete_Time_Integrator_u_add;  // sfix18_En16
  wire signed [35:0] Gain2_cast;  // sfix36_En33
  wire signed [17:0] Gain2_out1;  // sfix18_En16
  wire signed [17:0] Add1_out1;  // sfix18_En16
  reg signed [17:0] Discrete_Time_Integrator1_x_reg;  // sfix18_En16
  wire signed [17:0] Discrete_Time_Integrator1_u_add;  // sfix18_En16
  initial begin
     Discrete_Time_Integrator_x_reg=0;
     Discrete_Time_Integrator1_x_reg=0;
  end


  assign Gain_cast = {{18{d_i[17]}}, d_i};
  assign Gain_out1 = Gain_cast[19:2];
  assign Constant2_out1 = 18'sb110000000000000000;
  assign Constant1_out1 = 18'sb010000000000000000;

  assign Constant_out1 = 18'sb000000000000000000;
  assign Gain3_cast = {{2{Switch_out1[17]}}, {Switch_out1, 16'b0000000000000000}};
  assign Gain3_out1 = Gain3_cast[35:18];
  assign Switch_out1 = (d_o == 1'b0 ? Constant2_out1 :
              Constant1_out1);
  assign Gain1_cast = {{18{Switch_out1[17]}}, Switch_out1};
  assign Gain1_out1 = Gain1_cast[19:2];
  assign Add_out1 = Gain_out1 - Gain1_out1;
  // CORREGIDO (6): integradores con saturacion. Antes desbordaban (vuelta de -2 a +2) con
  // |d_i| > ~0.93 y la salida se quedaba en ~50 % aunque se pidiera casi el maximo.
  wire signed [18:0] int0_sum = {Discrete_Time_Integrator_x_reg[17], Discrete_Time_Integrator_x_reg}
                              + {Add_out1[17], Add_out1};
  assign Discrete_Time_Integrator_u_add = (int0_sum >  19'sd131071) ?  18'sd131071 :
                                          (int0_sum < -19'sd131072) ? -18'sd131072 : int0_sum[17:0];

  always @(posedge clk_i or negedge rstb_i)
    begin : Discrete_Time_Integrator_reg_process
      if (!rstb_i) begin
        Discrete_Time_Integrator_x_reg <= 18'sb000000000000000000;
      end
      else begin
        if (ce_i) begin
          Discrete_Time_Integrator_x_reg <= Discrete_Time_Integrator_u_add;
        end
      end
    end
  assign Gain2_cast = {{2{Discrete_Time_Integrator_x_reg[17]}}, {Discrete_Time_Integrator_x_reg, 16'b0000000000000000}};
  assign Gain2_out1 = Gain2_cast[34:17];
  assign Add1_out1 = Gain2_out1 - Gain3_out1;
  wire signed [18:0] int1_sum = {Discrete_Time_Integrator1_x_reg[17], Discrete_Time_Integrator1_x_reg}
                              + {Add1_out1[17], Add1_out1};
  assign Discrete_Time_Integrator1_u_add = (int1_sum >  19'sd131071) ?  18'sd131071 :
                                           (int1_sum < -19'sd131072) ? -18'sd131072 : int1_sum[17:0];

  always @(posedge clk_i or negedge rstb_i)
    begin : Discrete_Time_Integrator1_reg_process
      if (!rstb_i) begin
        Discrete_Time_Integrator1_x_reg <= 18'sb000000000000000000;
      end
      else begin
        if (ce_i) begin
          Discrete_Time_Integrator1_x_reg <= Discrete_Time_Integrator1_u_add;
        end
      end
    end
  
  // assign d_o = Discrete_Time_Integrator1_x_reg > Constant_out1;
 
  assign d_o = ~Discrete_Time_Integrator1_x_reg[17];

endmodule
