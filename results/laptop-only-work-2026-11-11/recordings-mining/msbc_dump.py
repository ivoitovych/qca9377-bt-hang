#!/usr/bin/env python3
"""msbc_dump.py <capture.btsnoop[.zst]> '<from>' '<to>' <out.msbc> [rx|tx]: write the mSBC frames (57 bytes each, syncword 0xAD) of one direction
of SCO data in the local-time window, for a decode test. Transient file: delete after use."""
import struct
import subprocess
import sys
from datetime import datetime

OFF = 0x00E03AB44A676000
U2000 = 946684800
path, t0, t1, out = sys.argv[1:5]
want = 7 if (len(sys.argv) < 6 or sys.argv[5] == "rx") else 6
t0 = datetime.strptime(t0, "%Y-%m-%d %H:%M:%S").timestamp()
t1 = datetime.strptime(t1, "%Y-%m-%d %H:%M:%S").timestamp()
data = subprocess.run(["zstd", "-dcq", path], capture_output=True, check=True).stdout if path.endswith(".zst") else open(path, "rb").read()
off, n = 16, len(data)
buf = bytearray()
while off + 24 <= n:
    _o, il, fl, _d, ts = struct.unpack_from(">IIIIq", data, off)
    off += 24
    if off + il > n:
        break
    if (fl & 0xFFFF) == want and (fl >> 16) == 0 and il >= 3:
        t = (ts - OFF) / 1e6 + U2000
        if t0 <= t <= t1:
            buf += data[off + 3:off + 3 + data[off + 2]]
    off += il
frames = 0
with open(out, "wb") as o:
    i = 0
    while i + 60 <= len(buf):
        if buf[i] == 1 and buf[i + 1] in (0x08, 0x38, 0xC8, 0xF8) and buf[i + 2] == 0xAD:
            o.write(bytes(buf[i + 2:i + 59]))
            frames += 1
            i += 60
        else:
            i += 1
print("frames", frames)
