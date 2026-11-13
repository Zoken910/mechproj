import serial
s = serial.Serial('COM4', 115200, timeout=0.5)
def w(a, v): s.write(bytes([0x57, a, v >> 8, v & 0xFF]))
def r(a): s.write(bytes([0x52, a])); d = s.read(2); return d.hex()

print("ID:", r(0x00))                       # muss a7a7 sein
input("J2 Pin 1 messen -> 0 V? Enter")
w(0x01, 1)                                   # Ausgänge an (LED 0 leuchtet)
for c in (0, 1024, 2048, 3072, 4095):
    w(0x02, c); w(0x03, c)
    input(f"Code {c}: erwartet {c*3.3/4095:.3f} V an J2 Pin 1 und Pin 3. Enter")
w(0x02, 1024); w(0x03, 3072)
input("Pin 1 ≈ 0.83 V, Pin 3 ≈ 2.48 V? Enter")
w(0x01, 0)
print("fertig")