# Paso 9 después de la reunión del 17.11.2026

En la reunión el profe pidió estos bloques y cambios. Todo está simulado y sintetiza con yosys
(`python tools/correr_pruebas.py --sintesis`: 15 testbenches y 6 síntesis, todo OK).

| Lo que pidió el profe | Qué es | Dónde quedó |
|---|---|---|
| register | banco de registros con los ajustes | `rtl/blocks/registros.v` |
| uart parser | entiende los comandos `W` / `R` de la Pi | `rtl/blocks/uart_parser.v` |
| PID (en las notas quedó "pin") | controlador PID para el lazo | `rtl/blocks/control_pid.v` |
| combine | suma, resta o producto de dos señales | `rtl/blocks/combinar.v` + `signalcombiner.v` (código del profe, corregido) |
| signal | generador de señales | `rtl/blocks/sig_gen.v` + `signalgenerator.v` + `urandgenerator.v` (código del profe, corregido) |
| hardware voltage speed | la demo: regular la velocidad de un motor DC con el voltaje | PID con salida de ±5 V, modelo del motor en `sim/modelo_motor_dc.v`, decisiones de hardware abajo |
| actualizar el CAD suite | OSS CAD Suite (yosys, iverilog, openFPGALoader…) | `tools/actualizar_oss_cad_suite.sh` (Pi/Linux) y `.ps1` (Windows), `build.sh`, CI de GitHub |

## Qué cambió en el Verilog

- **register + uart parser.** `regs_uart.v` se partió en los dos bloques. El protocolo y las
  direcciones no cambian. `regs_uart.v` queda como envoltorio (parser + registros) para que
  `top_paso5.v`, `top_paso7.v` y `tb_uart.v` sigan iguales, pero al compilarlos ahora hay que pasar
  también `uart_parser.v` y `registros.v` (ya está en `build.sh`, `hacer_bit.py` y en los testbenches).
  Nuevo en el parser: si un comando queda a medias (se perdió un byte), a los 2 ms vuelve a esperar
  un comando; antes el siguiente comando se leía corrido un byte.
- **Registros nuevos 0x0C (KI) y 0x0D (KD)** para el PID. Arrancan en 0, así que sin tocarlos el
  PID es un controlador P. Mapa completo: `docs/registros.md`.
- **PID en lugar del control_p de la guía** (`control_pid.v`):
  - `e = setpoint − medida`; `u = Kp·e + ΣKi·e + Kd·(medida anterior − medida)`; `y = 512 + u`.
  - La salida está centrada en 512 = 0 V, como el resto de la cadena. Con la etapa de op-amps de
    ±5 V el PID puede frenar o invertir el giro. El control_p de la guía sacaba 0..1023 con los
    negativos en 0: con la etapa de ±5 V, error 0 habría dado −5 V en el motor.
  - Calcula a 1 kHz (una vez cada 10 muestras del ADC). Si el ADC se detiene, el PID también y no
    integra un error viejo.
  - Anti-windup: la integral no crece mientras la salida está saturada y nunca pasa de ±512.
  - Derivada sobre la medida: mover el setpoint no da un pico.
  - Parámetros al compilar: `Y_MIN`/`Y_MAX` (límites de la salida; `Y_MIN = 512` si el driver solo
    acepta voltajes positivos), `Y_REPOSO` (salida con el lazo apagado, 512 = 0 V), `DIV`.
- **filtro_media** toma una muestra con cada `adc_nueva` (entrada `muestra`) en vez de tener su
  propio contador, y arranca en 512 (0 V).
- **top_template.v** usa los bloques por separado y ya no tiene `dir_lazo`. La cadena que dibuja el
  usuario vive ahora en su propio módulo `cadena` (molde: `rtl/cadena_template.v`). Así el top está
  completo, se puede simular y sintetizar sin el generador, y un cable mal escrito en el código
  generado es un error (`default_nettype none`) y no un cable nuevo de 1 bit.
- **Top de prueba del paso 9**: `rtl/top_template.v` + `rtl/paso9/cadena_paso9.v` (la demo de
  velocidad hecha a mano: ADC canal 0 → filtro → PID → salida 1; filtro → salida 2). Huella 0x0009.

Problemas de `known-issues` que esto resuelve: el P solo no llega al setpoint (ahora hay integral),
`dir_lazo` con varios drivers (ya no existe), el filtro con su propio contador, el UART que no se
resincronizaba y los cables implícitos en el código generado.

## Errores en el código del profe

Se comprobaron simulando sus archivos sin cambios (`signalgenerator_2.v`, `signalcombiner.v`,
`urandgenerator.v` de la carpeta `Vivado_Artix7_2025_06_24`). Cada arreglo está marcado en el código.

| | Error | Lo que se midió con el original |
|---|---|---|
| G1 | La interpolación del seno/coseno no funcionaba: mezcla de con signo y sin signo en `diff * phase[15:0]` (la cuenta se hace sin signo y en 18 bits), registros de 16 bits para una tabla de 18 y un pipeline que mezclaba tres muestras | el seno sale en escalones: saltos de hasta 810 de 65536 entre un ciclo y el siguiente (el corregido: 21) |
| G2 | La forma dependía de dos ajustes que tenían que coincidir (`clkcycles_per_period` e incremento); tabla de 255 pasos con un índice de 256 | con los valores del propio proyecto (N = 10000) la sierra llega a +37232 en vez de +32768 y el triángulo solo a +32245 |
| G3 | `offset + señal` sin saturación: pasa de +2.0 a −2.0 | (cuenta directa de 18 bits) |
| G4 | El LFSR del ruido no tiene valor inicial: sin pulso de reset se queda en 0 | el ruido no cambia nunca |
| C1 | Suma y resta del combinador en 18 bits, sin saturación | 1.5 + 1.5 = −1.0 |
| C2 | El producto toma bits fijos y se rompe si el resultado pasa de 2.0 | −2.0 × −2.0 = 0 |

Además: en este proyecto hay un solo reloj de 12 MHz y no hay reset global, así que los módulos
del profe usan reset síncrono (atado a 0) en vez de asíncrono. El generador ahora define la
frecuencia solo con el incremento: frecuencia = `GEN_FREQ` × 0.715 Hz, igual que antes en el registro
0x07. `GEN_FORMA` = 4 da ruido (nuevo). Lo que no se usó del proyecto del profe: los filtros IIR, el
XADC, el divisor de reloj y el reset global; el ESP32 lo reemplaza la Pi (su página web
`res/index.html` le puede servir a Patricio como referencia).

## Pruebas

| Prueba | Qué revisa | Resultado |
|---|---|---|
| `uart` | todos los registros (con KI y KD), lectura no partida, recuperación de un comando cortado | UART OK |
| `pid` | P, I, D, anti-windup, tick, salida solo positiva y lazo con el motor DC simulado | PID OK |
| `signal` | seno contra `$sin` (error 3 de 65536), formas, escala, período, coseno, ruido, saturación | SIGNAL OK |
| `combine` | casos de la guía + las dos correcciones | COMBINE OK |
| `filtro` | arranque, escalón, promedio | FILTRO OK |
| `paso9` | sistema completo: UART → PID → DAC → motor → AD7606 → filtro → PID, y la foto por SPI | PASO9 OK |
| las de antes | top, adc, dac (CLK_DIV 1 y 3), io, spi, sigma-delta, paso7, pwm | todas OK |

Síntesis con yosys (`synth_xilinx`, `check -assert`): top del paso 9 = 933 LUT, 1144 flip-flops,
3 DSP de 20 800 LUT y 90 DSP. También sintetizan el top del paso 7 y cada bloque por separado.

Comandos:
```
python tools/correr_pruebas.py                # todas las simulaciones (~1 min, paso9 tarda ~50 s)
python tools/correr_pruebas.py pid paso9      # solo esas
python tools/correr_pruebas.py --sintesis     # además yosys
```
GitHub corre lo mismo en cada push (`.github/workflows/pruebas.yml`) con la versión más nueva de
OSS CAD Suite.

## El PID y el motor DC

Resultado con el motor simulado (constante de tiempo 50 ms, zona muerta 0.3 V, setpoint +1.95 V):

- P solo (Kp = 2): se queda con 77 de error. Es lo que se esperaba de un P solo.
- PI (Kp = 2, Ki = 40 /s): error 0 en unos 200 ms, sin sobrepaso. También al revés (setpoint
  negativo) y con 30 % de carga en el eje.
- Con D (Kd = 10 ms) sigue estable.

Cómo ajustarlo con el motor real (`pi/prueba_pid.py --motor`):
1. Solo P (KI = KD = 0): subir KP hasta que responda rápido sin oscilar. Va a quedar con error.
2. Agregar I con Ti ≈ la constante de tiempo del motor (lo que tarda en llegar al 63 % de un
   escalón): Ki = Kp / Ti → `KI = Ki × 65.536`. Ejemplo: Kp = 2 y Ti = 50 ms → Ki = 40 /s → KI = 2621.
3. D normalmente no hace falta en un lazo de velocidad. Si se usa, siempre con el filtro antes.

## Decisiones de hardware pendientes (Persona 1 y el profe)

1. **Etapa de salida y "apagado".** Con la etapa de op-amps de 0..3.3 V → ±5 V (lo que dice el
   documento del equipo), el código 0 del DAC son −5 V en el SMA. Eso pasa con las salidas apagadas
   (CONTROL = 0) y al encender, antes de cargar la FPGA (el DAC arranca en 0). Con un motor
   conectado sería girar al revés a fondo. Hay que decidirlo antes de conectar el motor: un enable
   en el driver, una etapa de 0..+5 V (entonces `Y_MIN = 512` y `Y_REPOSO = 0`), o las dos cosas.
   Cambiar el "apagado" a 2048 en el top solo ayuda después de cargar la FPGA.
2. **Driver del motor:** ¿acepta voltajes negativos (gira en los dos sentidos)? Si no: `Y_MIN = 512`.
3. **Sensor de velocidad:** voltaje proporcional a la velocidad (tacogenerador) en el canal 0, con
   el rango del AD7606 (±5 V o ±10 V) elegido para que la velocidad máxima no sature. Un encoder
   necesitaría un bloque nuevo y pines (solo quedan los de reserva, DIP 7 a 10).
4. **Signo del lazo:** más voltaje → más velocidad → más voltaje del sensor. Si el sensor está al
   revés, el lazo se va al máximo: cambiar los cables del sensor.

## Prueba en la placa (Levi)

1. Compilar: `python hacer_bit.py paso9` (laptop, deja `bits/paso9.bit`) o en la Pi
   `./build.sh rtl/top_template.v rtl/paso9/cadena_paso9.v rtl/blocks/*.v`.
2. Sin motor: cable de la salida DAC1 a la entrada V1 del AD7606 y `python3 pi/prueba_pid.py`.
   Revisa que el P solo deja error y que el PI llega a 600, 700 y 800. Imprime `PID OK`.
3. Con el motor: `python3 pi/prueba_pid.py --motor --kp 512 --ki 2621 --sp 600 712 512`.

## OSS CAD Suite

Sale una versión cada noche (la del 17.11.2026 es la más nueva al escribir esto).
- **Pi y Linux:** `./tools/actualizar_oss_cad_suite.sh` (o con una fecha fija:
  `./tools/actualizar_oss_cad_suite.sh 2026-11-17`). Necesita Raspberry Pi OS de **64 bits**
  (OSS CAD Suite solo sale para linux-arm64). La versión anterior queda en `~/oss-cad-suite.anterior`.
- **Windows:** `powershell -ExecutionPolicy Bypass -File tools\actualizar_oss_cad_suite.ps1`
  (queda en `C:\oss-cad-suite`; después `. C:\oss-cad-suite\environment.ps1` en cada terminal).
  Para `hacer_bit.py` (apio): `apio packages update`.
- OSS CAD Suite **no trae** nextpnr-xilinx ni prjxray (openXC7): esos siguen como están.
  `build.sh` agrega `~/oss-cad-suite/bin` al PATH si no encuentra yosys (sin cambiar `python3`,
  que necesita `fasm2frames`) y anota las versiones usadas en `build/versiones.txt`.
- Usar la misma fecha en la Pi, en las laptops y en la CI evita que algo funcione en una máquina
  y no en otra.

## Cambios que afectan a otros (avisar antes de subir a main)

- **Patricio (UI):** registros nuevos KI (0x0C) y KD (0x0D) para los sliders, con la conversión de
  `docs/registros.md`; el bloque del controlador pasa a ser `control_pid` (entradas `setpoint` y
  `medida`, igual que `control_p`); `GEN_FORMA` = 4 es ruido. Después de "Synthesize & Flash" hay
  que volver a escribir también KI y KD.
- **Levi (Pi):** las listas de archivos de paso5/paso7 llevan `uart_parser.v` y `registros.v`;
  top del paso 9 y `pi/prueba_pid.py`; actualizar OSS CAD Suite con el script.
- **Persona 1:** las decisiones de hardware de arriba.

## Para el Paso 10 (generador de Verilog)

El generador ahora llena `rtl/cadena_template.v` (mismas señales que el hueco de la guía, más
`muestra`, `ki`, `kd`) y lo pega al final de `top_template.v`. Cambios en la `BIBLIOTECA` de la guía:

```python
"filtro_media": {"entradas": ["x"], "plantilla":
    "filtro_media #(.LOG2N({log2n})) u_{id} (.clk(clk), .muestra(muestra), .x({x}), .y({out}));"},
"control_pid":  {"entradas": ["setpoint", "medida"], "plantilla":
    "control_pid #(.Y_MIN({y_min})) u_{id} (.clk(clk), .enable(control[0] & control[1]), "
    ".muestra(muestra), .setpoint({setpoint}), .medida({medida}), .kp(kp), .ki(ki), .kd(kd), .y({out}));"},
"generador":    {"entradas": [], "plantilla":
    "sig_gen u_{id} (.clk(clk), .forma(gen_forma[2:0]), .inc(gen_freq), .amp(gen_amp[9:0]), "
    ".offset(gen_offset[9:0]), .y({out}));"},
OPS = {"suma": 2, "resta": 3, "producto": 4}   # codigos del combinador del profe
```
Ya no hace falta `assign dir_lazo = 1'b0;`. Valor por defecto de `y_min`: 0 (512 si el driver no
acepta voltajes negativos).
