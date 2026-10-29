#!/usr/bin/env python3
"""Prueba del Paso 5 en la placa real (corre en la Pi, despues de cargar top_paso5).
Uso: python3 prueba_uart.py [/dev/ttyUSB1]
Imprime UART OK si ID, escritura/lectura y LEDs responden."""
import sys, time, serial  # pip install pyserial

puerto = sys.argv[1] if len(sys.argv) > 1 else "/dev/ttyUSB1"   # canal B del FTDI = UART
s = serial.Serial(puerto, 115200, timeout=0.2)
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

errores = 0
def comprobar(nombre, addr, esperado):
    global errores
    v = leer(addr)
    ok = v == esperado
    errores += not ok
    print(f"{nombre:8s} R 0x{addr:02X} = 0x{v:04X}  (esperado 0x{esperado:04X}) {'ok' if ok else 'MAL'}")

comprobar("ID", 0x00, 0xA7A7)
comprobar("BUILD", 0x1B, 0x0005)
comprobar("SETPOINT", 0x04, 512)          # valor de arranque
escribir(0x05, 0x0180); comprobar("KP", 0x05, 0x0180)
escribir(0x0A, 0xBEEF); comprobar("USR_P1", 0x0A, 0xBEEF)
comprobar("NO_EXIST", 0x0F, 0xDEAD)

for c in (0b01, 0b10, 0b11, 0b00):
    escribir(0x01, c)
    print(f"CONTROL = {c:02b}: mira los LEDs (LED0={c & 1}, LED1={c >> 1})")
    time.sleep(1)

print("UART OK" if errores == 0 else f"UART MAL: {errores} errores")
