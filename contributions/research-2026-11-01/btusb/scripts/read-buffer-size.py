#!/usr/bin/env python3
"""read-buffer-size.py <capture.btsnoop[.zst]> - every Read Buffer Size
(0x1005) Command Complete in the capture: ACL MTU, SCO MTU, ACL packets,
SCO packets. Stops after the first 200000 records."""
import struct
import subprocess
import sys
from datetime import datetime

DELTA = 0x00DCDDB30F2F8000
path = sys.argv[1]
if path.endswith(".zst"):
    p = subprocess.Popen(["zstd", "-dc", path], stdout=subprocess.PIPE)
    f = p.stdout
else:
    p, f = None, open(path, "rb")
f.read(16)
n = 0
while n < 200000:
    h = f.read(24)
    if len(h) < 24:
        break
    _o, il, flags, _d, ts = struct.unpack(">IIIIq", h)
    b = f.read(il)
    n += 1
    if flags & 0xFFFF == 3 and len(b) >= 13 and b[0] == 0x0E and struct.unpack_from("<H", b, 3)[0] == 0x1005:
        st, acl_mtu, sco_mtu, acl_pkts, sco_pkts = struct.unpack_from("<BHBHH", b, 5)
        t = datetime.fromtimestamp((ts - DELTA) / 1e6)
        print(f"{t} hci{flags >> 16} Read Buffer Size: status 0x{st:02x} ACL MTU {acl_mtu} x {acl_pkts}, SCO MTU {sco_mtu} x {sco_pkts}")
f.close()
if p:
    p.kill()
