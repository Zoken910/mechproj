#!/usr/bin/env python3
"""Prueba del Paso 9 en la placa real (corre en la Pi, despues de cargar el top del paso 9:
rtl/top_template.v + rtl/paso9/cadena_paso9.v, huella 0x0009).

Sin motor (lo primero): un cable de la salida DAC1 del PmodDA2 a la entrada V1 del AD7606
(igual que prueba_dac.py --lazo). El "motor" es entonces el cable: lo que saca el PID vuelve
por el ADC. Revisa que el P solo deja error y que el PI lo lleva a cero en varios setpoints.
    python3 prueba_pid.py [/dev/ttyUSB1]
Con el motor (para ajustar las ganancias): sensor de velocidad en V1, DAC1 -> etapa de
op-amps -> driver. Da escalones de setpoint y muestra la medida cada 50 ms.
    python3 prueba_pid.py [/dev/ttyUSB1] --motor --kp 512 --ki 2621 --kd 0 --sp 600 712 512
(--rango 10 si el AD7606 esta en +-10 V; por defecto +-5 V)
Antes de conectar nada: medir que ningun pin que llega a la FPGA pase de 3.3 V.
"""
import argparse, time, serial  # pip install pyserial

p = argparse.ArgumentParser()
p.add_argument("puerto", nargs="?", default="/dev/ttyUSB1")     # canal B del FTDI = UART
p.add_argument("--motor", action="store_true", help="con el motor real: solo escalones y mediciones")
p.add_argument("--kp", type=int, default=512, help="KP (0x05), 256 = 1.0")
p.add_argument("--ki", type=int, default=2621, help="KI (0x0C), 65536 = 1.0 por ms (2621 = 40 /s)")
p.add_argument("--kd", type=int, default=0, help="KD (0x0D), 256 = 1.0 por ms")
p.add_argument("--sp", type=int, nargs="+", default=[600, 712, 512], help="setpoints (512 = 0 V)")
p.add_argument("--segundos", type=float, default=2.0, help="tiempo en cada setpoint (con --motor)")
a = p.parse_args()

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

def medida():
    """ADC canal 0 en el formato de la cadena (0..1023, 512 = 0 V), promedio de 4 lecturas."""
    total = 0
    for _ in range(4):
        v = leer(0x10)
        total += (v >> 6) ^ 0x200                  # igual que el top: 16 bits con signo -> 10 bits
    return round(total / 4)

errores = 0
def comprobar(nombre, addr, esperado):
    global errores
    v = leer(addr)
    ok = v == esperado
    errores += not ok
    print(f"{nombre:9s} R 0x{addr:02X} = 0x{v:04X}  (esperado 0x{esperado:04X}) {'ok' if ok else 'MAL'}")

comprobar("ID", 0x00, 0xA7A7)
comprobar("BUILD", 0x1B, 0x0009)                    # top del paso 9
comprobar("KI", 0x0C, 0)                            # arranca en 0 = controlador P
comprobar("KD", 0x0D, 0)

def lazo(kp, ki, kd):
    escribir(0x05, kp); escribir(0x0C, ki); escribir(0x0D, kd)
    escribir(0x01, 0x0003)                          # salidas on + lazo cerrado (LED 0 y LED 1)

if a.motor:
    lazo(a.kp, a.ki, a.kd)
    print(f"KP={a.kp} KI={a.ki} KD={a.kd}. Ctrl+C para parar (apaga las salidas).")
    try:
        for sp in a.sp:
            escribir(0x04, sp)
            t0 = time.time()
            while time.time() - t0 < a.segundos:
                m = medida()
                print(f"  t={time.time() - t0:5.2f} s  setpoint {sp:4d}  medida {m:4d}  error {sp - m:+5d}"
                      f"  DAC1 {leer(0x18):4d}")
                time.sleep(0.05)
    finally:
        escribir(0x01, 0x0000)
    raise SystemExit(0)

# ---- sin motor: cable DAC1 -> V1. Rango alcanzable: 512 (0 V) a ~850 (3.3 V) con el ADC en +-5 V ----
# Con el cable la salida 512 (1.65 V) ya se lee como ~681: el P solo con setpoint 600 se queda en
# ~661 (error ~-60). El PI encuentra solo el voltaje que hace falta.
for sp, kp, ki, debe_llegar in ((600, 256, 0, False), (600, 256, 6554, True),
                                (700, 256, 6554, True), (800, 256, 6554, True)):
    escribir(0x01, 0x0000); time.sleep(0.05)       # apagar borra la integral
    escribir(0x04, sp)
    lazo(kp, ki, 0)
    time.sleep(1.0)
    m = medida()
    llego = abs(sp - m) <= 4
    ok = llego == debe_llegar
    errores += not ok
    tipo = "P solo" if ki == 0 else "PI"
    print(f"{tipo:6s} setpoint {sp}: medida {m}, error {sp - m:+d}  "
          f"({'llega' if llego else 'no llega'}, se esperaba que {'llegue' if debe_llegar else 'no llegue'}) "
          f"{'ok' if ok else 'MAL'}")

escribir(0x01, 0x0000)                              # apagar: salidas a 0 V
comprobar("APAGADO", 0x18, 0)
print("PID OK" if errores == 0 else f"PID MAL: {errores} errores")
