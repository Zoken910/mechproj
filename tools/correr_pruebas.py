#!/usr/bin/env python3
"""Corre todos los testbenches de sim/ con Icarus Verilog y dice cuales pasan.
Funciona igual en Windows, Linux y en la CI de GitHub (solo usa la biblioteca de Python).

Uso (desde la carpeta principal del repo, con OSS CAD Suite en el PATH):
    python tools/correr_pruebas.py                  # todas las pruebas
    python tools/correr_pruebas.py pid paso9        # solo esas
    python tools/correr_pruebas.py --sintesis       # ademas: yosys sintetiza el top del paso 9
    python tools/correr_pruebas.py --lista          # que pruebas hay
Una prueba pasa si imprime su linea "... OK" y ninguna linea con "MAL" o "ERROR".
Regla del repo: solo se sube a main lo que pasa aqui, y en el commit se dice que prueba se corrio.
Las salidas (sim_*, *.vcd, logs) quedan en build/pruebas/ (no se suben: build/ esta en .gitignore).
Las herramientas se llaman con rutas relativas a la carpeta del repo: asi funciona aunque la ruta
tenga espacios (por ejemplo "Hochschule Esslingen"), que en Windows suele romper iverilog y yosys.
"""
import shutil
import subprocess
import sys
import time
from pathlib import Path

RAIZ = Path(__file__).resolve().parent.parent
B = "rtl/blocks/"
UART = [B + "uart_rx.v", B + "uart_tx.v", B + "regs_uart.v", B + "uart_parser.v", B + "registros.v"]
TOP9 = ["rtl/top_template.v", "rtl/paso9/cadena_paso9.v", B + "uart_rx.v", B + "uart_tx.v",
        B + "uart_parser.v", B + "registros.v", B + "adc_ad7606.v", B + "dac_pmodda2.v",
        B + "spi_stream.v", B + "sigma_delta.v", B + "v_fpga_fpt2p16_2o_sdm.v",
        B + "filtro_media.v", B + "control_pid.v"]

# nombre: (archivos, texto que dice que paso)
PRUEBAS = {
    "top":     (["sim/tb_top.v", "rtl/top.v"], "TOP OK"),
    "uart":    (["sim/tb_uart.v", *UART], "UART OK"),
    "adc":     (["sim/tb_adc.v", B + "adc_ad7606.v"], "ADC OK"),
    "dac":     (["sim/tb_dac.v", "sim/modelo_dac121s101.v", B + "dac_pmodda2.v"], "DAC OK"),
    "dac3":    (["-P", "tb_dac.CLK_DIV=3", "sim/tb_dac.v", "sim/modelo_dac121s101.v", B + "dac_pmodda2.v"], "DAC OK"),
    "io":      (["sim/tb_io.v", B + "adc_ad7606.v", B + "dac_pmodda2.v", B + "spi_stream.v"], "IO OK"),
    "spi":     (["sim/tb_spi.v", B + "spi_stream.v"], "SPI OK"),
    "sd":      (["sim/tb_sigma_delta.v", B + "sigma_delta.v", B + "v_fpga_fpt2p16_2o_sdm.v"], "SIGMA-DELTA OK"),
    "paso7":   (["sim/tb_paso7.v", "sim/modelo_dac121s101.v", "rtl/paso7/top_paso7.v", *UART,
                 B + "adc_ad7606.v", B + "dac_pmodda2.v"], "PASO7 OK"),
    "filtro":  (["sim/tb_filtro.v", B + "filtro_media.v"], "FILTRO OK"),
    "pid":     (["sim/tb_pid.v", "sim/modelo_motor_dc.v", B + "control_pid.v"], "PID OK"),
    "signal":  (["sim/tb_sig_gen.v", B + "sig_gen.v", B + "signalgenerator.v", B + "urandgenerator.v"], "SIGNAL OK"),
    "combine": (["sim/tb_combinar.v", B + "combinar.v", B + "signalcombiner.v"], "COMBINE OK"),
    "paso9":   (["sim/tb_paso9.v", "sim/modelo_ad7606.v", "sim/modelo_dac121s101.v",
                 "sim/modelo_motor_dc.v", *TOP9], "PASO9 OK"),
    "pwm":     (["sim/tb_pwm.v", "rtl/practica/pwm.v"], "PWM OK"),
}

# lo que se sintetiza con --sintesis: el top del paso 9 entero y cada bloque de la cadena solo
# (asi tambien se revisan los bloques que la cadena del paso 9 no usa)
SINTESIS = [   # (nombre, modulo top, archivos, comandos de yosys antes de sintetizar)
    ("top del paso 9", "top", TOP9, ""),
    ("top del paso 7", "top", ["rtl/paso7/top_paso7.v", *UART, B + "adc_ad7606.v", B + "dac_pmodda2.v"], ""),
    ("signal",         "sig_gen",      [B + "sig_gen.v", B + "signalgenerator.v", B + "urandgenerator.v"], ""),
    ("combine (x)",    "combinar",     [B + "combinar.v", B + "signalcombiner.v"], "chparam -set OP 4 combinar"),
    ("PID",            "control_pid",  [B + "control_pid.v"], ""),
    ("filtro",         "filtro_media", [B + "filtro_media.v"], ""),
]


def herramienta(nombre):
    ruta = shutil.which(nombre)
    if not ruta:
        print(f"ERROR: no encuentro {nombre}. Abre OSS CAD Suite primero:")
        print("  Windows:  C:\\oss-cad-suite\\environment.bat   (o start.bat)")
        print("  Linux/Pi: source ~/oss-cad-suite/environment")
        print("  (para instalarla o actualizarla: tools/actualizar_oss_cad_suite.sh o .ps1)")
        sys.exit(2)
    return ruta


def version(cmd):
    try:
        r = subprocess.run(cmd, capture_output=True, text=True, timeout=30)
        return (r.stdout or r.stderr).strip().splitlines()[0]
    except Exception:
        return "?"


def correr(nombre, archivos, ok, salida):
    opciones = [f for f in archivos if f.startswith("-") or "=" in f]       # por ejemplo -P tb.X=3
    archivos = [f for f in archivos if f not in opciones]
    faltan = [f for f in archivos if not (RAIZ / f).is_file()]
    if faltan:
        return False, f"faltan archivos: {', '.join(faltan)}", 0.0
    exe = f"sim_{nombre}"
    t0 = time.time()
    comp = subprocess.run([herramienta("iverilog"), "-g2012", *opciones,
                           "-o", (salida / exe).relative_to(RAIZ).as_posix(), *archivos],
                          capture_output=True, text=True, cwd=RAIZ)
    if comp.returncode != 0:
        return False, "no compila:\n" + comp.stderr.strip(), time.time() - t0
    sim = subprocess.run([herramienta("vvp"), "-n", exe], capture_output=True, text=True, cwd=salida)
    texto = sim.stdout + sim.stderr
    (salida / f"{nombre}.log").write_text(texto)
    lineas = texto.splitlines()
    malas = [l for l in lineas if "MAL" in l or "ERROR" in l]
    paso = any(ok in l for l in lineas) and not malas and sim.returncode == 0
    detalle = ok if paso else "\n".join(malas[:8]) or f"no imprimio '{ok}' (ver build/pruebas/{nombre}.log)"
    return paso, detalle, time.time() - t0


def sintesis(salida, nombre, top, archivos, previo):
    yosys = herramienta("yosys")
    base = (salida / ("yosys_" + "".join(c if c.isalnum() else "_" for c in nombre))).relative_to(RAIZ).as_posix()
    script = ((previo + "; " if previo else "") +
              "synth_xilinx -flatten -abc9 -arch xc7 -top " + top + "; check -assert; "
              f"tee -o {base}_recursos.txt stat")
    r = subprocess.run([yosys, "-q", "-l", f"{base}.log", "-p", script, *archivos],
                       capture_output=True, text=True, cwd=RAIZ)
    if r.returncode != 0:
        return False, (r.stdout + r.stderr).strip()[-2000:]
    stat = (RAIZ / f"{base}_recursos.txt").read_text()
    celdas = {}
    for l in stat.splitlines():
        partes = l.split()
        if len(partes) >= 2 and partes[0].isdigit() and partes[1].startswith(("LUT", "FD", "DSP48", "RAM", "CARRY")):
            celdas[partes[1]] = celdas.get(partes[1], 0) + int(partes[0])
        elif len(partes) >= 2 and partes[-1].isdigit() and partes[0].startswith(("LUT", "FD", "DSP48", "RAM", "CARRY")):
            celdas[partes[0]] = celdas.get(partes[0], 0) + int(partes[-1])
    luts = sum(v for k, v in celdas.items() if k.startswith("LUT"))
    ffs = sum(v for k, v in celdas.items() if k.startswith("FD"))
    dsp = sum(v for k, v in celdas.items() if k.startswith("DSP48"))
    ram = sum(v for k, v in celdas.items() if k.startswith("RAM"))
    return True, f"{luts} LUT, {ffs} flip-flops, {dsp} DSP, {ram} RAM (de 20800 LUT y 90 DSP)"


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    if "--lista" in sys.argv:
        for n, (archivos, ok) in PRUEBAS.items():
            print(f"{n:8s} -> {ok:15s} {' '.join(archivos)}")
        return 0
    elegidas = args or list(PRUEBAS)
    desconocidas = [a for a in elegidas if a not in PRUEBAS]
    if desconocidas:
        print(f"ERROR: no existe la prueba {', '.join(desconocidas)}. Hay: {', '.join(PRUEBAS)}")
        return 2
    salida = RAIZ / "build" / "pruebas"
    salida.mkdir(parents=True, exist_ok=True)
    print(f"iverilog: {version([herramienta('iverilog'), '-V'])}")
    fallaron = []
    for n in elegidas:
        archivos, ok = PRUEBAS[n]
        print(f"- {n:8s} ...", end=" ", flush=True)
        paso, detalle, dt = correr(n, archivos, ok, salida)
        print(f"{'OK ' if paso else 'MAL'} ({dt:.0f} s)" + ("" if paso else "\n    " + detalle.replace("\n", "\n    ")))
        if not paso:
            fallaron.append(n)
    if "--sintesis" in sys.argv:
        print(f"yosys: {version([herramienta('yosys'), '-V'])}")
        for nombre, top, archivos, previo in SINTESIS:
            print(f"- sintesis {nombre:15s} ...", end=" ", flush=True)
            paso, detalle = sintesis(salida, nombre, top, archivos, previo)
            print(("OK  " if paso else "MAL\n    ") + detalle.replace("\n", "\n    "))
            if not paso:
                fallaron.append(f"sintesis {nombre}")
    print()
    if fallaron:
        print(f"PRUEBAS MAL: {', '.join(fallaron)}")
        return 1
    print(f"TODAS LAS PRUEBAS OK ({len(elegidas)}{' + sintesis' if '--sintesis' in sys.argv else ''})")
    return 0


if __name__ == "__main__":
    sys.exit(main())
