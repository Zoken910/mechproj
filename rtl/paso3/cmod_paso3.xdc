# cmod_a7.xdc: pines del LED parpadeante (Paso 3).
# Numeros tomados de Cmod-A7-Master.xdc de Digilent. En el Paso 9.4 este archivo
# se reemplaza por el XDC completo (UART, ADC, DAC, SPI).

# Reloj de 12 MHz
set_property PACKAGE_PIN L17 [get_ports clk]
set_property IOSTANDARD LVCMOS33 [get_ports clk]
# Opcional: periodo del reloj para el analisis de tiempos (83.33 ns = 12 MHz).
# Si nextpnr-xilinx se queja de esta linea, dejala comentada.
# create_clock -period 83.33 -name sys_clk_pin [get_ports clk]

# LEDs de la placa
set_property PACKAGE_PIN A17 [get_ports {led[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led[0]}]
set_property PACKAGE_PIN C16 [get_ports {led[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led[1]}]
