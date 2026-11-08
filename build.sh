#!/bin/bash
# build.sh: Verilog -> bitstream -> CMOD-A7 con la toolchain abierta (yosys + openXC7).
# Version corregida del 08.11.2026: el XDC se elige al llamar, revisa todo antes de empezar
# y, si un paso falla, dice cual y muestra el error (antes solo faltaba el .bit al final).
#
# Uso (desde la carpeta principal del repo):
#   XDC=rtl/paso3/cmod_paso3.xdc ./build.sh rtl/top.v
#   XDC=rtl/paso5/cmod_paso5.xdc ./build.sh rtl/paso5/top_paso5.v rtl/blocks/uart_rx.v rtl/blocks/uart_tx.v rtl/blocks/regs_uart.v
#   XDC=rtl/paso7/cmod_paso7.xdc ./build.sh rtl/paso7/top_paso7.v rtl/blocks/uart_rx.v rtl/blocks/uart_tx.v rtl/blocks/regs_uart.v rtl/blocks/adc_ad7606.v rtl/blocks/dac_pmodda2.v
# Sin XDC=... usa rtl/cmod_a7.xdc (la tabla de pines completa, para el top final).
# SIN_CARGAR=1 ./build.sh ...   solo compila, no carga la FPGA.
# El resultado queda en build/top.bit y los registros de cada paso en build/*.log.

set -uo pipefail
PART=xc7a35tcpg236-1
CHIPDB=${CHIPDB:-$HOME/openxc7/chipdb/xc7a35tcpg236-1.bin}
XDC=${XDC:-rtl/cmod_a7.xdc}
OUT=build

paso()  { echo; echo "=== $1 ==="; }
falla() { echo; echo "ERROR: $1"; exit 1; }
muestra_log() { echo "--- ultimas lineas de $1 ---"; tail -n 25 "$1"; }

# ---- revisar todo antes de empezar ----
[ $# -ge 1 ] || falla "faltan los archivos .v. Ejemplo: XDC=rtl/paso3/cmod_paso3.xdc ./build.sh rtl/top.v"
for f in "$@"; do [ -f "$f" ] || falla "no existe $f (git pull hecho? estas en la carpeta del repo?)"; done
[ -f "$XDC" ] || falla "no existe el XDC $XDC"
for t in yosys nextpnr-xilinx fasm2frames xc7frames2bit openFPGALoader; do
    command -v "$t" >/dev/null || falla "no se encuentra $t (falta 'source ~/oss-cad-suite/environment' o la instalacion de openXC7)"
done
[ -f "$CHIPDB" ] || falla "no existe la chipdb $CHIPDB. Pon la ruta real: export CHIPDB=/ruta/a/xc7a35tcpg236-1.bin"
[ -n "${PRJXRAY_DB_DIR:-}" ] || falla "PRJXRAY_DB_DIR no esta definida (la define la instalacion de openXC7; revisa ~/.bashrc)"
DB=$PRJXRAY_DB_DIR/artix7
[ -f "$DB/$PART/part.yaml" ] || falla "no existe $DB/$PART/part.yaml: PRJXRAY_DB_DIR apunta a otro lugar"
echo "XDC: $XDC"
echo "Archivos: $*"
mkdir -p "$OUT"
rm -f "$OUT/top.json" "$OUT/top.fasm" "$OUT/top.frames" "$OUT/top.bit"

# ---- 1) Sintesis: Verilog -> netlist ----
paso "1/5 Sintesis (yosys)"
yosys -q -l "$OUT/yosys.log" -p "synth_xilinx -flatten -abc9 -arch xc7 -top top; write_json $OUT/top.json" "$@" \
    || { muestra_log "$OUT/yosys.log"; falla "fallo la sintesis (paso 1): error en el Verilog o falta un archivo .v"; }

# ---- 2) Place & Route: netlist -> ubicacion fisica en el chip ----
paso "2/5 Place & Route (nextpnr-xilinx), puede tardar unos minutos"
nextpnr-xilinx --chipdb "$CHIPDB" --xdc "$XDC" --json "$OUT/top.json" --fasm "$OUT/top.fasm" > "$OUT/nextpnr.log" 2>&1 \
    || { muestra_log "$OUT/nextpnr.log"; falla "fallo place & route (paso 2). Si habla de un puerto sin pin: el XDC no es el de este top"; }

# ---- 3) y 4) FASM -> frames -> bitstream ----
paso "3/5 FASM a frames"
fasm2frames --part "$PART" --db-root "$DB" "$OUT/top.fasm" > "$OUT/top.frames" 2> "$OUT/fasm2frames.log" \
    || { muestra_log "$OUT/fasm2frames.log"; falla "fallo fasm2frames (paso 3)"; }
paso "4/5 Frames a bitstream"
xc7frames2bit --part_file "$DB/$PART/part.yaml" --part_name "$PART" \
    --frm_file "$OUT/top.frames" --output_file "$OUT/top.bit" > "$OUT/xc7frames2bit.log" 2>&1 \
    || { muestra_log "$OUT/xc7frames2bit.log"; falla "fallo xc7frames2bit (paso 4)"; }
[ -s "$OUT/top.bit" ] || falla "xc7frames2bit termino pero no hay $OUT/top.bit"
echo "Bitstream listo: $OUT/top.bit"

# ---- 5) Cargar en la FPGA (a la RAM: se pierde al quitar la corriente) ----
if [ -n "${SIN_CARGAR:-}" ]; then echo; echo "LISTO (sin cargar): $OUT/top.bit"; exit 0; fi
paso "5/5 Cargar en la FPGA (openFPGALoader)"
openFPGALoader -b cmoda7_35t "$OUT/top.bit" \
    || falla "no se pudo cargar (paso 5). Prueba 'openFPGALoader --detect': cable de datos y reglas udev"
echo; echo "LISTO: $OUT/top.bit cargado en la CMOD"
