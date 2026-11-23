# Mapa de registros (UART)

Contrato entre la FPGA (`rtl/blocks/registros.v`) y la Pi (`fpga_io.py`, la UI de Patricio).
Actualizado el 17.11.2026: **nuevos 0x0C (KI) y 0x0D (KD)** para el PID. Todo lo demás no cambia.

## Protocolo

115200 baudios, 8N1, por el USB de la CMOD. Lo interpreta `rtl/blocks/uart_parser.v`.

| Comando | Bytes que manda la Pi | Respuesta de la FPGA |
|---|---|---|
| Escribir | `0x57` ('W'), dirección, dato alto, dato bajo | ninguna |
| Leer | `0x52` ('R'), dirección | dato alto, dato bajo |

- No hay ACK: para confirmar un ajuste, leerlo de vuelta.
- Nuevo: si un comando queda a medias (se perdió un byte), a los **2 ms** sin bytes el parser
  vuelve a esperar un comando. Entre los bytes de un comando normal hay 87 µs. Si la Pi manda los
  bytes de un comando con pausas de más de 2 ms, el comando se pierde.
- Todos los registros vuelven a su valor de arranque al cargar un bitstream: la UI los tiene que
  volver a escribir después de "Synthesize & Flash".

## Registros

| Dir. | Nombre | Tipo | Arranque | Significado |
|---|---|---|---|---|
| 0x00 | ID | R | 0xA7A7 | Siempre 0xA7A7 (prueba de comunicación) |
| 0x01 | CONTROL | W | 0 | bit 0 = salidas encendidas, bit 1 = lazo cerrado (0 = modo manual) |
| 0x02 | DAC1_MANUAL | W | 0 | Salida 1 en modo manual, 0..4095 (0..3.3 V en el DAC) |
| 0x03 | DAC2_MANUAL | W | 0 | Salida 2 en modo manual |
| 0x04 | SETPOINT | W | 512 | Referencia del lazo, 0..1023 (512 = 0 V) |
| 0x05 | KP | W | 256 | Ganancia proporcional, 256 = 1.0 |
| 0x06 | GEN_FORMA | W | 0 | 0 seno, 1 cuadrada, 2 triángulo, 3 sierra, **4 ruido (nuevo)** |
| 0x07 | GEN_FREQ | W | 14 | Frecuencia = valor × 0.715 Hz (14 → 10 Hz, 1398 → 1 kHz) |
| 0x08 | GEN_AMP | W | 256 | 0..512 (512 = todo el rango); hasta 1023 recorta la forma |
| 0x09 | GEN_OFFSET | W | 512 | Centro de la señal, 512 = 0 V |
| 0x0A | USR_P1 | W | 0 | Parámetro libre del bloque Verilog del usuario |
| 0x0B | USR_P2 | W | 0 | Parámetro libre del bloque Verilog del usuario |
| **0x0C** | **KI** | W | **0** | **Ganancia integral del PID**, por tick: 65536 = 1.0. Con el tick de 1 kHz: Ki [1/s] = KI × 0.0153 |
| **0x0D** | **KD** | W | **0** | **Ganancia derivativa del PID**, por tick: 256 = 1.0. Con el tick de 1 kHz: Kd [s] = KD × 3.9 µs |
| 0x10..0x17 | ADC_CH0..7 | R | — | Última lectura de cada entrada, 16 bits con signo |
| 0x18 | DAC1_ACTUAL | R | — | Lo que sale de verdad por la salida 1 (12 bits) |
| 0x19 | DAC2_ACTUAL | R | — | Lo que sale de verdad por la salida 2 |
| 0x1A | SALIDAS_SD | R | — | bit 0 / bit 1 = salida 1 / 2 por sigma-delta |
| 0x1B | BUILD_ID | R | — | Huella del diagrama cargado (0x0009 = top de prueba del paso 9) |
| 0x1C | SPI_IN0 | R | 512 | Último valor 0 que mandó la Pi por SPI |
| 0x1D | SPI_IN1 | R | 512 | Último valor 1 que mandó la Pi por SPI |
| otra | — | R | 0xDEAD | Dirección que no existe |

Los "W" también se pueden leer. Escribir en una dirección de solo lectura no hace nada.
Con KI = KD = 0 (el arranque) el PID es exactamente un controlador P: lo que ya existía sigue igual.

## Convertir unidades a registros (para la UI)

```python
KP = round(kp * 256)                 # kp sin unidades: 1.0 -> 256
KI = round(ki_por_segundo * 65.536)  # Ki en 1/s con el tick de 1 kHz: 40 /s -> 2621
KD = round(kd_segundos * 256000)     # Kd en segundos con el tick de 1 kHz: 0.01 s -> 2560
```
Máximos: KP 255.99, Ki 1000 /s, Kd 0.256 s.

## Trama SPI (sin cambios)

12 palabras de 16 bits, la palabra 0 primero: `0xA5A5`, contador de muestras, ADC canal 0..7,
DAC1, DAC2. La Pi también puede mandar `0x5A5A, valor0, valor1` en la misma transferencia
(bloques `spi_in`). Modo 0, SCLK de 1 MHz como máximo.
