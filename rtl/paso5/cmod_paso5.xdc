# Pines para top_paso5.v (mismos que en cmod_a7.xdc final)
set_property PACKAGE_PIN L17 [get_ports clk]
set_property IOSTANDARD LVCMOS33 [get_ports clk]
# UART por el USB de la CMOD
set_property PACKAGE_PIN J17 [get_ports uart_rx_pin]
set_property IOSTANDARD LVCMOS33 [get_ports uart_rx_pin]
set_property PACKAGE_PIN J18 [get_ports uart_tx_pin]
set_property IOSTANDARD LVCMOS33 [get_ports uart_tx_pin]
# LEDs
set_property PACKAGE_PIN A17 [get_ports {led[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led[0]}]
set_property PACKAGE_PIN C16 [get_ports {led[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led[1]}]
