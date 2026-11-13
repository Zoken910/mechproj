import serial, serial.tools.list_ports
for p in serial.tools.list_ports.comports():
    try:
        s = serial.Serial(p.device, 115200, timeout=0.5)
        s.write(bytes([0x52, 0x00])); d = s.read(2); s.close()
        print(p.device, p.description, "->", d.hex() or "keine Antwort")
    except Exception as e:
        print(p.device, "-> Fehler:", e)