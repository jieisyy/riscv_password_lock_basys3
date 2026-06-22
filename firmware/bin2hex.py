#!/usr/bin/env python3
import sys
from pathlib import Path

if len(sys.argv) != 3:
    print('usage: bin2hex.py input.bin output.hex')
    sys.exit(1)

bin_path = Path(sys.argv[1])
hex_path = Path(sys.argv[2])
data = bin_path.read_bytes()
# pad to 32-bit words
if len(data) % 4:
    data += bytes(4 - (len(data) % 4))

with hex_path.open('w') as f:
    for i in range(0, len(data), 4):
        word = data[i] | (data[i+1] << 8) | (data[i+2] << 16) | (data[i+3] << 24)
        f.write(f'{word:08x}\n')
