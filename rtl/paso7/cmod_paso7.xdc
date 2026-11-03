# Pines para top_paso7.v: los mismos de la tabla del Paso 9.4 (cmod_a7.xdc final).
# Reloj de 12 MHz
set_property PACKAGE_PIN L17 [get_ports clk]
set_property IOSTANDARD LVCMOS33 [get_ports clk]

# UART por el USB de la CMOD
set_property PACKAGE_PIN J17 [get_ports uart_rx_pin]
set_property IOSTANDARD LVCMOS33 [get_ports uart_rx_pin]
set_property PACKAGE_PIN J18 [get_ports uart_tx_pin]
set_property IOSTANDARD LVCMOS33 [get_ports uart_tx_pin]

# ADC AD7606 en el Pmod JA (1 a 4 salidas, 7 a 9 entradas)
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

# PmodDA2 en los pines DIP 1 a 4, en el mismo orden que el conector del Pmod:
#   Pmod 1 = SYNC -> DIP 1, Pmod 2 = DINA -> DIP 2, Pmod 3 = DINB -> DIP 3, Pmod 4 = SCLK -> DIP 4
#   Pmod 5 = GND, Pmod 6 = VCC 3.3 V (de la CMOD, no de 5 V)
set_property PACKAGE_PIN M3 [get_ports dac_sync_n]
set_property IOSTANDARD LVCMOS33 [get_ports dac_sync_n]
set_property PACKAGE_PIN L3 [get_ports dac_dina]
set_property IOSTANDARD LVCMOS33 [get_ports dac_dina]
set_property PACKAGE_PIN A16 [get_ports dac_dinb]
set_property IOSTANDARD LVCMOS33 [get_ports dac_dinb]
set_property PACKAGE_PIN K3 [get_ports dac_sclk]
set_property IOSTANDARD LVCMOS33 [get_ports dac_sclk]

# LEDs
set_property PACKAGE_PIN A17 [get_ports {led[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led[0]}]
set_property PACKAGE_PIN C16 [get_ports {led[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led[1]}]
