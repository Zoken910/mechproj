# Tabla de pines final (congelada el 08.11.2026)

Es el contrato entre la FPGA (`rtl/cmod_a7.xdc`) y la PCB. Después del pedido, cambiar un pin significa cambiar la PCB.
Todos los pines están revisados contra `Cmod-A7-Master.xdc` de Digilent.

Toda la lógica es de **3.3 V**. Antes de conectar un módulo, medir que ningún pin que llega a la FPGA pase de 3.3 V.

## Pines DIP de la CMOD (los que van a la PCB)

| DIP | Pin FPGA | Señal | Sentido | Va a |
|---|---|---|---|---|
| 1 | M3 | `dac_sync_n` | sale | PmodDA2 pin 1 (SYNC) |
| 2 | L3 | `dac_dina` | sale | PmodDA2 pin 2 (DINA, salida 1) |
| 3 | A16 | `dac_dinb` | sale | PmodDA2 pin 3 (DINB, salida 2) |
| 4 | K3 | `dac_sclk` | sale | PmodDA2 pin 4 (SCLK) |
| 5 | C15 | `sd_out[0]` | sale | filtro RC + op-amp de la salida 1 |
| 6 | H1 | `sd_out[1]` | sale | filtro RC + op-amp de la salida 2 |
| 7–10 | A15, B15, A14, J3 | reserva | — | header de reserva (recomendado) |
| 17 | M1 | `pi_sck` | entra | Pi GPIO11 (SCLK, pin 23 del header) |
| 18 | N3 | `pi_mosi` | entra | Pi GPIO10 (MOSI, pin 19) |
| 19 | P3 | `pi_miso` | sale | Pi GPIO9 (MISO, pin 21) |
| 20 | M2 | `pi_cs_n` | entra | Pi GPIO8 (CE0, pin 24) |
| 21 | N1 | UART (opcional) | entra | Pi GPIO14 (TXD, pin 8) |
| 22 | N2 | UART (opcional) | sale | Pi GPIO15 (RXD, pin 10) |

PmodDA2: pin 5 = GND, pin 6 = VCC a **3.3 V** (no a 5 V: la salida va de 0 a VCC).

## Pmod JA de la CMOD (ADC AD7606)

El ADC no va por los pines DIP: va por el conector Pmod JA que está en la propia CMOD. La PCB necesita un conector o un cable hasta JA.

| JA | Pin FPGA | Señal | Sentido |
|---|---|---|---|
| 1 | G17 | `adc_convst` | sale |
| 2 | G19 | `adc_reset` | sale |
| 3 | N18 | `adc_cs_n` | sale |
| 4 | L18 | `adc_sclk` | sale |
| 7 | H17 | `adc_douta` | entra |
| 8 | H19 | `adc_doutb` | entra |
| 9 | J19 | `adc_busy` | entra |

El módulo AD7606 tiene que estar en modo serie (PAR/SER/BYTE SEL en alto) y con **VDRIVE a 3.3 V**. Muchos módulos traen VDRIVE a 5 V, y así DOUTA, DOUTB y BUSY llegarían a la FPGA con 5 V.

## Dentro de la CMOD (no pasan por la PCB)

| Pin FPGA | Señal |
|---|---|
| L17 | `clk` (12 MHz) |
| J17 / J18 | UART por el USB (entrada / salida de la FPGA) |
| A17 / C16 | LEDs |

## Decisiones para la PCB

1. **UART.** El XDC usa el UART del USB (J17/J18), que ya funciona con el cable USB que de todos modos hace falta para programar la FPGA. Recomendado: llevar igual DIP 21 y 22 a GPIO14/15 de la Pi en la PCB. No cuesta nada, y si después se quiere el UART por la PCB basta con cambiar dos líneas del XDC, sin tocar la placa.
2. **Reserva.** Llevar DIP 7 a 10 a un header pequeño. Si algo sale después del pedido (softcore, una señal de depuración, el level shifter), hay pines sin rehacer la PCB.
3. **Salidas.** Cada salida puede ir por el PmodDA2 o por sigma-delta, nunca por las dos a la vez. La PCB lleva las dos rutas hasta el filtro de cada SMA, a menos que el profesor diga que basta una.
4. **SPI.** La Pi debe usar SCLK de 1 MHz como máximo (en simulación funciona hasta 2 MHz, a 3 MHz falla).
