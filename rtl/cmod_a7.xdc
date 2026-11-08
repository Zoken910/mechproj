# cmod_a7.xdc: tabla de pines FINAL del sistema (Paso 9.4), para top_template.v.
# CONGELADA el 08.11.2026 para el pedido de la PCB: cambiar un pin de aqui = cambiar la PCB.
# Todos los pines revisados contra Cmod-A7-Master.xdc de Digilent (github.com/Digilent/digilent-xdc).
# La misma tabla, con hacia donde va cada senal en la PCB, esta en docs/tabla_pines.md.

# Reloj de 12 MHz
set_property PACKAGE_PIN L17 [get_ports clk]
set_property IOSTANDARD LVCMOS33 [get_ports clk]
# Opcional: periodo del reloj para el analisis de tiempos (83.33 ns = 12 MHz).
# Si nextpnr-xilinx se queja de esta linea, dejala comentada.
# create_clock -period 83.33 -name sys_clk_pin [get_ports clk]

# UART por el USB de la CMOD (J17 = entrada a la FPGA, J18 = salida de la FPGA)
set_property PACKAGE_PIN J17 [get_ports uart_rx_pin]
set_property IOSTANDARD LVCMOS33 [get_ports uart_rx_pin]
set_property PACKAGE_PIN J18 [get_ports uart_tx_pin]
set_property IOSTANDARD LVCMOS33 [get_ports uart_tx_pin]
# Alternativa por la PCB (UART de los GPIO 14/15 de la Pi): cambiar las dos lineas de arriba por
#   uart_rx_pin -> N1 (DIP 21, desde GPIO14 TXD de la Pi)
#   uart_tx_pin -> N2 (DIP 22, hacia GPIO15 RXD de la Pi)

# ADC AD7606 en el Pmod JA de la CMOD (JA 1 a 4 salidas, JA 7 a 9 entradas)
set_property PACKAGE_PIN G17 [get_ports adc_convst]
set_property IOSTANDARD LVCMOS33 [get_ports adc_convst]
set_property PACKAGE_PIN G19 [get_ports adc_reset]
set_property IOSTANDARD LVCMOS33 [get_ports adc_reset]
set_property PACKAGE_PIN N18 [get_ports adc_cs_n]
set_property IOSTANDARD LVCMOS33 [get_ports adc_cs_n]
set_property PACKAGE_PIN L18 [get_ports adc_sclk]
set_property IOSTANDARD LVCMOS33 [get_ports adc_sclk]
set_property PACKAGE_PIN H17 [get_ports adc_douta]
set_property IOSTANDARD LVCMOS33 [get_ports adc_douta]
set_property PACKAGE_PIN H19 [get_ports adc_doutb]
set_property IOSTANDARD LVCMOS33 [get_ports adc_doutb]
set_property PACKAGE_PIN J19 [get_ports adc_busy]
set_property IOSTANDARD LVCMOS33 [get_ports adc_busy]

# DAC PmodDA2 en los pines DIP 1 a 4 (mismo orden que el conector del Pmod: SYNC, DINA, DINB, SCLK)
set_property PACKAGE_PIN M3 [get_ports dac_sync_n]
set_property IOSTANDARD LVCMOS33 [get_ports dac_sync_n]
set_property PACKAGE_PIN L3 [get_ports dac_dina]
set_property IOSTANDARD LVCMOS33 [get_ports dac_dina]
set_property PACKAGE_PIN A16 [get_ports dac_dinb]
set_property IOSTANDARD LVCMOS33 [get_ports dac_dinb]
set_property PACKAGE_PIN K3 [get_ports dac_sclk]
set_property IOSTANDARD LVCMOS33 [get_ports dac_sclk]

# Sigma-delta (salidas 1 y 2) en los pines DIP 5 y 6 -> filtro RC + op-amp de cada salida
set_property PACKAGE_PIN C15 [get_ports {sd_out[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {sd_out[0]}]
set_property PACKAGE_PIN H1 [get_ports {sd_out[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {sd_out[1]}]

# SPI con la Raspberry Pi en los pines DIP 17 a 20 (GPIO 11, 10, 9 y 8 de la Pi)
set_property PACKAGE_PIN M1 [get_ports pi_sck]
set_property IOSTANDARD LVCMOS33 [get_ports pi_sck]
set_property PACKAGE_PIN N3 [get_ports pi_mosi]
set_property IOSTANDARD LVCMOS33 [get_ports pi_mosi]
set_property PACKAGE_PIN P3 [get_ports pi_miso]
set_property IOSTANDARD LVCMOS33 [get_ports pi_miso]
set_property PACKAGE_PIN M2 [get_ports pi_cs_n]
set_property IOSTANDARD LVCMOS33 [get_ports pi_cs_n]

# LEDs de la placa
set_property PACKAGE_PIN A17 [get_ports {led[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led[0]}]
set_property PACKAGE_PIN C16 [get_ports {led[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led[1]}]

# Reserva: pines DIP 7 a 10 sin usar, llevados a un header en la PCB por si hace falta algo
# despues del pedido (por ejemplo, un softcore, una senal de depuracion o el level shifter).
#   DIP 7 = A15, DIP 8 = B15, DIP 9 = A14, DIP 10 = J3
