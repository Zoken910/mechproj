import serial, glob, sys
c = int(sys.argv[1])
s = serial.Serial(glob.glob('/dev/serial/by-id/*if01*')[0], 115200)
s.write(bytes([0x57,1,0,1, 0x57,2,c>>8,c&0xFF, 0x57,3,c>>8,c&0xFF]))