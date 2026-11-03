#!/usr/bin/env python3
"""Prueba del Paso 7 en la placa real (corre en la Pi, despues de cargar top_paso7).
Uso:
  python3 prueba_dac.py [/dev/ttyUSB1]            # mide DAC1 y DAC2 con el multimetro
  python3 prueba_dac.py [/dev/ttyUSB1] --lazo     # con un cable de DAC1 a V1 del AD7606
  (--rango 10 si el AD7606 esta en +-10 V; por defecto +-5 V)
Antes de conectar el PmodDA2: VCC del Pmod a 3.3 V, y medir que ningun pin hacia la FPGA pase de 3.3 V."""
import argparse, time, serial  # pip install pyserial

p = argparse.ArgumentParser()
p.add_argument("puerto", nargs="?", default="/dev/ttyUSB1")   # canal B del FTDI = UART
p.add_argument("--lazo", action="store_true", help="cable de DAC1 a la entrada V1 del AD7606")
p.add_argument("--rango", type=float, default=5.0, choices=[5.0, 10.0], help="rango del AD7606 (+-V)")
a = p.parse_args()
lazo, rango = a.lazo, a.rango

s = serial.Serial(a.puerto, 115200, timeout=0.2)
s.reset_input_buffer()

def escribir(addr, valor):
    s.write(bytes([ord("W"), addr, (valor >> 8) & 0xFF, valor & 0xFF]))

def leer(addr):
    s.reset_input_buffer()
    s.write(bytes([ord("R"), addr]))
    r = s.read(2)
    if len(r) != 2:
        raise RuntimeError(f"sin respuesta al leer 0x{addr:02X} (puerto/baudios/pines?)")
    return (r[0] << 8) | r[1]

def adc_voltios(addr):
    v = leer(addr)
    v = v - 65536 if v & 0x8000 else v                # 16 bits con signo
    return v * rango / 32768

errores = 0
def comprobar(nombre, addr, esperado):
    global errores
    v = leer(addr)
    ok = v == esperado
    errores += not ok
    print(f"{nombre:9s} R 0x{addr:02X} = 0x{v:04X}  (esperado 0x{esperado:04X}) {'ok' if ok else 'MAL'}")

comprobar("ID", 0x00, 0xA7A7)
comprobar("BUILD", 0x1B, 0x0007)                       # top_paso7

escribir(0x01, 0x0001)                                 # salidas habilitadas (LED 0 encendido)
for codigo in (0, 1024, 2048, 3072, 4095):
    escribir(0x02, codigo)
    escribir(0x03, 4095 - codigo)
    comprobar("DAC1", 0x18, codigo)
    comprobar("DAC2", 0x19, 4095 - codigo)
    v1, v2 = codigo * 3.3 / 4096, (4095 - codigo) * 3.3 / 4096
    if lazo:
        time.sleep(0.01)
        medido = sum(adc_voltios(0x10) for _ in range(8)) / 8
        ok = abs(medido - v1) < 0.05                   # el DAC da VA*codigo/4096; VA del Pmod ~3.3 V
        errores += not ok
        print(f"          DAC1 {v1:.3f} V -> ADC V1 lee {medido:.3f} V  {'ok' if ok else 'MAL'}")
    else:
        input(f"          mide: DAC1 ~ {v1:.2f} V, DAC2 ~ {v2:.2f} V (Enter para seguir) ")

escribir(0x01, 0x0000)                                 # apagar: las dos salidas a 0 V
comprobar("APAGADO", 0x18, 0)
print("DAC OK" if errores == 0 else f"DAC MAL: {errores} errores")
