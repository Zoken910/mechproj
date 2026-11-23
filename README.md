# Mechatronisches Projekt: Raspberry Pi + FPGA

Una caja que lee 8 señales analógicas, las procesa en tiempo real en una FPGA (CMOD-A7-35T) y saca
2 señales analógicas. La demo: regular la velocidad de un motor DC con un PID que corre en la FPGA.
La Raspberry Pi configura (UART) y observa (SPI); el lazo rápido no depende de ella.

## Carpetas

| Carpeta | Qué hay |
|---|---|
| `rtl/blocks/` | Los bloques de Verilog: `uart_parser` + `registros` (ajustes por UART), `adc_ad7606`, `dac_pmodda2`, `sigma_delta`, `spi_stream`, y los de la cadena: `control_pid`, `filtro_media`, `sig_gen` (signal), `combinar` (combine) |
| `rtl/top_template.v` | El top final; la cadena del usuario va en el módulo `cadena` (`rtl/cadena_template.v`) |
| `rtl/cmod_a7.xdc` | La tabla de pines final (congelada el 08.11; ver `docs/tabla_pines.md`) |
| `rtl/paso3`, `paso5`, `paso7`, `paso9` | Tops de prueba de cada paso para la placa |
| `sim/` | Testbenches (`tb_*.v`) y modelos de los chips y del motor DC |
| `pi/` | Pruebas en la placa desde la Pi (`prueba_uart.py`, `prueba_dac.py`, `prueba_pid.py`) |
| `tools/` | `correr_pruebas.py` (todas las simulaciones) y `actualizar_oss_cad_suite.sh` / `.ps1` |
| `docs/` | `registros.md` (mapa de registros), `tabla_pines.md`, `paso9.md` (cambios de la reunión del 17.11) |
| `bits/` | Bitstreams de prueba compilados en la laptop para cargar en la Pi |

## Probar antes de subir

Con OSS CAD Suite en el PATH (instalar o actualizar: `tools/actualizar_oss_cad_suite.sh` o `.ps1`):

```
python tools/correr_pruebas.py --sintesis
```

Regla del equipo: solo se sube a `main` lo que pasa, y en el commit se dice qué prueba se corrió.
GitHub corre las mismas pruebas en cada push.

## Compilar y cargar

- En la Pi: `./build.sh rtl/top_template.v rtl/paso9/cadena_paso9.v rtl/blocks/*.v`
- En la laptop (apio): `python hacer_bit.py paso9` y en la Pi `openFPGALoader -b cmoda7_35t bits/paso9.bit`
