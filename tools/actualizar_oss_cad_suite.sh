#!/bin/bash
# actualizar_oss_cad_suite.sh: instala o actualiza OSS CAD Suite (yosys, iverilog, gtkwave,
# openFPGALoader, verilator...) en ~/oss-cad-suite. Lo pidio el profe en la reunion del 17.11.2026.
# Sirve para la Raspberry Pi (Raspberry Pi OS de 64 bits), Linux y macOS. En Windows: el .ps1.
#
# Uso (desde la carpeta principal del repo):
#   ./tools/actualizar_oss_cad_suite.sh              # la version mas nueva (sale una cada noche)
#   ./tools/actualizar_oss_cad_suite.sh 2026-11-17   # una fecha fija: la misma en todas las maquinas
# Despues, en cada terminal nueva:
#   export PATH="$HOME/oss-cad-suite/bin:$PATH"      # (build.sh lo hace solo si no encuentra yosys)
# o "source ~/oss-cad-suite/environment", que ademas cambia python3 por el de OSS CAD Suite: en la
# Pi eso puede romper fasm2frames de openXC7 (usa el python3 del sistema). Por eso se recomienda PATH.
#
# OSS CAD Suite NO trae nextpnr-xilinx ni la base de datos prjxray (openXC7): esos se quedan como
# estan y build.sh los sigue buscando en el mismo lugar. La version anterior queda en
# ~/oss-cad-suite.anterior por si algo deja de funcionar (para volver: borrar la nueva y renombrar).
set -euo pipefail

DESTINO=${OSS_CAD_SUITE:-$HOME/oss-cad-suite}
FECHA=${1:-}
falla() { echo "ERROR: $1"; exit 1; }

case "$(uname -s)-$(uname -m)" in
    Linux-x86_64)               PLAT=linux-x64 ;;
    Linux-aarch64)              PLAT=linux-arm64 ;;   # Raspberry Pi 4/5 con sistema de 64 bits
    Darwin-arm64)               PLAT=darwin-arm64 ;;
    Darwin-x86_64)              PLAT=darwin-x64 ;;
    Linux-armv7l|Linux-armv6l)  falla "sistema de 32 bits. OSS CAD Suite solo sale para linux-arm64: instala Raspberry Pi OS de 64 bits" ;;
    *)                          falla "sistema no reconocido: $(uname -s) $(uname -m)" ;;
esac
for t in curl tar python3; do command -v "$t" >/dev/null || falla "falta $t"; done

API=https://api.github.com/repos/YosysHQ/oss-cad-suite-build/releases
if [ -n "$FECHA" ]; then URL_API="$API/tags/$FECHA"; else URL_API="$API/latest"; fi
echo "Buscando OSS CAD Suite ${FECHA:-(la mas nueva)} para $PLAT ..."
INFO=$(curl -fsSL -H "User-Agent: mechproj" "$URL_API") || falla "no pude leer $URL_API (red? fecha que no existe?)"
read -r URL TAM ETIQUETA < <(printf '%s' "$INFO" | python3 -c "
import json, sys
r = json.load(sys.stdin)
for a in r.get('assets', []):
    if a['name'].startswith('oss-cad-suite-$PLAT-') and a['name'].endswith('.tgz'):
        print(a['browser_download_url'], a['size'], r.get('tag_name', '?'))
        break
") || true
[ -n "${URL:-}" ] || falla "no encontre oss-cad-suite-$PLAT-*.tgz en esa version"

if [ -x "$DESTINO/bin/yosys" ]; then
    echo "Instalada ahora: $("$DESTINO/bin/yosys" -V 2>/dev/null | head -1)"
fi
echo "Nueva: $ETIQUETA ($((TAM / 1048576)) MB comprimida; descomprimida ocupa varias veces eso)"
PADRE=$(dirname "$DESTINO")
mkdir -p "$PADRE"
LIBRE_MB=$(df -Pm "$PADRE" | awk 'NR == 2 {print $4}')
[ "$LIBRE_MB" -gt $((TAM * 5 / 1048576)) ] || falla "poco espacio libre en $PADRE: ${LIBRE_MB} MB"

TMP=$(mktemp -d "$PADRE/.oss-cad-suite-nueva.XXXXXX")
trap 'rm -rf "$TMP"' EXIT
echo "Descargando $(basename "$URL") ..."
curl -fL --progress-bar -o "$TMP/suite.tgz" "$URL" || falla "fallo la descarga"
echo "Descomprimiendo ..."
tar -xzf "$TMP/suite.tgz" -C "$TMP" || falla "fallo al descomprimir"
rm -f "$TMP/suite.tgz"
[ -x "$TMP/oss-cad-suite/bin/yosys" ] || falla "el archivo no trae oss-cad-suite/bin/yosys"

if [ -e "$DESTINO" ]; then
    rm -rf "$DESTINO.anterior"
    mv "$DESTINO" "$DESTINO.anterior"
    echo "La version anterior quedo en $DESTINO.anterior"
fi
mv "$TMP/oss-cad-suite" "$DESTINO"
[ "$(uname -s)" = Darwin ] && (cd "$DESTINO" && ./activate >/dev/null 2>&1 || true)

echo
echo "LISTO: OSS CAD Suite $ETIQUETA en $DESTINO"
for c in "yosys -V" "iverilog -V" "openFPGALoader --Version" "gtkwave --version"; do
    set -- $c
    printf '  %-15s %s\n' "$1" "$("$DESTINO/bin/$1" "${@:2}" 2>&1 | head -1)"
done
echo
echo "Para usarla en esta terminal:  export PATH=\"$DESTINO/bin:\$PATH\""
echo "Probar el repo:                python3 tools/correr_pruebas.py --sintesis"
