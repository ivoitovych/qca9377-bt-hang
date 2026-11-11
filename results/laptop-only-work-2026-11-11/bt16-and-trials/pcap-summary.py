#!/usr/bin/env python3
"""pcap-summary.py <usbmon.pcap>: one line per URB record (file read only). Prints up to 24 data bytes in hex."""
import struct
import sys
from datetime import datetime

d = open(sys.argv[1], "rb").read()
magic = struct.unpack("<I", d[:4])[0]
e = "<" if magic in (0xA1B2C3D4, 0xA1B23C4D) else ">"
nano = magic in (0xA1B23C4D, 0x4D3CB2A1)
lt = struct.unpack(e + "I", d[20:24])[0]
print("linktype", lt, "bytes", len(d))
i = 24
n = 0
while i + 16 <= len(d):
    sec, frac, incl, orig = struct.unpack(e + "IIII", d[i:i + 16])
    i += 16
    rec = d[i:i + incl]
    i += incl
    hl = 64 if lt == 220 else 48
    (uid, typ, xf, ep, dev, bus, fs, fd, tsec, tus, st, ulen, dlen) = struct.unpack(e + "QBBBBHBBqiiII", rec[:40])
    setup = rec[40:48]
    data = rec[hl:hl + dlen]
    t = datetime.fromtimestamp(sec + frac / (1e9 if nano else 1e6)).strftime("%H:%M:%S.%f")
    kind = {0: "iso", 1: "int", 2: "ctrl", 3: "bulk"}.get(xf, str(xf))
    print(f"{t} {chr(typ)} {kind} ep{ep & 0x7f}{'in' if ep & 0x80 else 'out'} dev{dev} bus{bus} status {st} urb_len {ulen} data_len {dlen} setup {setup.hex() if fs == 0 else '-'} data {data[:24].hex()}")
    n += 1
print("records", n)
