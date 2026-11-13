import serial

# Passe 'COM4' an deinen tatsächlichen COM-Port im Gerätemanager an
ser = serial.Serial('COM4', 115200, timeout=1)

def r(addr):
    """Liest ein 16-Bit-Register aus (Opcode 0x00)."""
    ser.write(bytes([0x00, addr]))
    res = ser.read(2)
    if len(res) == 2:
        return f"{int.from_bytes(res, 'big'):04x}"
    return "Keine Antwort"

def w(addr, val):
    """Schreibt einen 16-Bit-Wert in ein Register (Opcode 0x01)."""
    val_msb = (val >> 8) & 0xFF
    val_lsb = val & 0xFF
    ser.write(bytes([0x01, addr, val_msb, val_lsb]))

# --- Dein Test-Ablauf ---
print("ID          ", r(0x00))   # erwartet a7a7
w(0x01, 1)
w(0x02, 4095)
print("CONTROL     ", r(0x01))   # erwartet 0001
print("DAC1_MANUAL ", r(0x02))   # erwartet 0fff
print("DAC1_ACTUAL ", r(0x18))   # erwartet 0fff