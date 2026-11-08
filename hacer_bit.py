#!/usr/bin/env python3
"""Plan B mientras la Pi no tiene openXC7: compila un top de prueba en la laptop con apio
(Windows, Linux PC o Mac) y deja el bitstream en bits/<nombre>.bit para que Levi lo cargue
en la Pi con openFPGALoader. Ni apio ni este script tocan los archivos de rtl/: copian lo
necesario a build_apio/<nombre>/ (apio compila todos los .v de su carpeta, y el repo tiene
varios modulos "top").

Uso (desde la carpeta principal del repo):
    python hacer_bit.py blinky     # rtl/top.v + rtl/paso3/cmod_paso3.xdc
    python hacer_bit.py paso5      # UART + registros
    python hacer_bit.py paso7      # UART + registros + ADC + DAC
Despues:
    git add bits/<nombre>.bit && git commit -m "bit de <nombre>" && git push
En la Pi (Levi):
    git pull && openFPGALoader -b cmoda7_35t bits/<nombre>.bit
"""
import shutil
import subprocess
import sys
from pathlib import Path

RAIZ = Path(__file__).resolve().parent
UART = ["rtl/blocks/uart_rx.v", "rtl/blocks/uart_tx.v", "rtl/blocks/regs_uart.v"]
PRUEBAS = {
    "blinky": ("rtl/paso3/cmod_paso3.xdc", ["rtl/top.v"]),
    "paso5": ("rtl/paso5/cmod_paso5.xdc", ["rtl/paso5/top_paso5.v", *UART]),
    "paso7": ("rtl/paso7/cmod_paso7.xdc", ["rtl/paso7/top_paso7.v", *UART,
                                           "rtl/blocks/adc_ad7606.v", "rtl/blocks/dac_pmodda2.v"]),
}
APIO_INI = """[env:default]
board = cmod-a7-35t
top-module = top
constraint-file = pines.xdc
"""


def error(msg):
    print(f"ERROR: {msg}")
    sys.exit(1)


def comando_apio():
    if shutil.which("apio"):
        return [shutil.which("apio")]
    try:                                     # apio instalado con pip pero no en el PATH
        import apio  # noqa: F401
        return [sys.executable, "-m", "apio"]
    except ImportError:
        error("no encuentro apio. Instalalo con: pip install apio")


def main():
    if len(sys.argv) != 2 or sys.argv[1] not in PRUEBAS:
        error(f"uso: python hacer_bit.py {' | '.join(PRUEBAS)}")
    nombre = sys.argv[1]
    xdc, fuentes = PRUEBAS[nombre]
    for f in [xdc, *fuentes]:
        if not (RAIZ / f).is_file():
            error(f"no existe {f} (git pull hecho?)")

    proyecto = RAIZ / "build_apio" / nombre
    if proyecto.exists():
        shutil.rmtree(proyecto)
    proyecto.mkdir(parents=True)
    for f in fuentes:
        shutil.copy(RAIZ / f, proyecto / Path(f).name)
    shutil.copy(RAIZ / xdc, proyecto / "pines.xdc")
    (proyecto / "apio.ini").write_text(APIO_INI)
    print(f"Proyecto apio en {proyecto.relative_to(RAIZ)}: {', '.join(Path(f).name for f in fuentes)} + {xdc}")

    print("Compilando con apio (la primera vez descarga la toolchain y tarda unos minutos)...")
    r = subprocess.run([*comando_apio(), "build"], cwd=proyecto)
    if r.returncode != 0:
        error("apio build fallo (mira el mensaje de arriba). Si faltan paquetes: apio packages install")

    bits = sorted(proyecto.glob("_build/**/*.bit"))
    if not bits:
        error("apio termino pero no encuentro el .bit en build_apio/<nombre>/_build/")
    destino = RAIZ / "bits" / f"{nombre}.bit"
    destino.parent.mkdir(exist_ok=True)
    shutil.copy(bits[0], destino)
    print(f"\nLISTO: bits/{nombre}.bit ({destino.stat().st_size // 1024} KB)")
    print(f"Subirlo:   git add bits/{nombre}.bit && git commit -m \"bit de {nombre}\" && git push")
    print(f"En la Pi:  git pull && openFPGALoader -b cmoda7_35t bits/{nombre}.bit")


if __name__ == "__main__":
    main()
