#!/usr/bin/env python3
# DAC-Test (Schritt 7): setzt DAC1/DAC2 über UART und fragt nach der Messung.
# Vorher: openFPGALoader -b cmoda7_35t paso7.bit
# Messen: Schwarz an PmodDA2 J2 Pin 5 (GND), Rot an J2 Pin 1 (Kanal A) bzw. J2 Pin 3 (Kanal B)
import glob, sys
import serial

ports = glob.glob('/dev/serial/by-id/*if01*')
if not ports:
    sys.exit("Kein UART-Port (*if01*) gefunden. Ist die CMOD per USB am Pi? -> ls /dev/serial/by-id/")
port = ports[0]
s = serial.Serial(port, 115200, timeout=0.5)

def w(a, v):
    s.write(bytes([0x57, a, v >> 8, v & 0xFF]))

def r(a):
    s.write(bytes([0x52, a]))
    return s.read(2).hex() or "keine Antwort"

print("Port:", port)
ident = r(0x00)
print("ID:", ident, "(muss a7a7 sein)")
if ident != "a7a7":
    sys.exit("UART antwortet nicht richtig. Bitstream neu laden oder paso5.bit / blinky.bit testen.")

input("Ausgänge sind noch aus: J2 Pin 1 sollte 0 V zeigen. Enter...")
w(0x01, 1)  # CONTROL = 1: Ausgänge an, manueller Modus (LED 0 leuchtet)
print("CONTROL:", r(0x01), "(erwartet 0001)")

for c in (0, 1024, 2048, 3072, 4095):
    w(0x02, c)
    w(0x03, c)
    print(f"\nCode {c}: FPGA meldet DAC1={r(0x18)} DAC2={r(0x19)}")
    input(f"  erwartet {c*3.3/4095:.3f} V an J2 Pin 1 und J2 Pin 3. Messen, dann Enter...")

w(0x02, 1024)
w(0x03, 3072)
input("\nKanaltest: Pin 1 ≈ 0.83 V, Pin 3 ≈ 2.48 V? (vertauscht = DINA/DINB vertauscht) Enter...")

w(0x01, 0)  # Ausgänge aus
print("Fertig, Ausgänge aus (beide Kanäle 0 V).")
