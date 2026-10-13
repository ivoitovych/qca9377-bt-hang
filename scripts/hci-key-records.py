#!/usr/bin/env python3
"""hci-key-records.py: count HCI records that carry key material, never printing it.

Usage: hci-key-records.py <capture.btsnoop>...

Counts, per file: Link Key Request Reply (cmd 0x040b), Link Key Notification (evt 0x18),
LE Start Encryption (cmd 0x2019), LE Long Term Key Request Reply (cmd 0x201a), and ACL
packets on the SMP channel (CID 0x0006, LE) or BR/EDR SMP (CID 0x0007). Prints counts and
the first record's time and length only.
"""
import struct
import sys
from datetime import datetime

EPOCH = 0x00DCDDB30F2F8000
CMDS = {0x040B: "Link Key Request Reply (cmd 0x040b)", 0x2019: "LE Start Encryption (cmd 0x2019)",
        0x201A: "LE LTK Request Reply (cmd 0x201a)"}
EVTS = {0x18: "Link Key Notification (evt 0x18)"}


def main(paths):
    for path in paths:
        found = {}
        with open(path, "rb") as f:
            if f.read(16)[:8] != b"btsnoop\0":
                print(f"{path}: not btsnoop")
                continue
            while True:
                rec = f.read(24)
                if len(rec) < 24:
                    break
                _o, incl, flags, _d, ts = struct.unpack(">IIIIq", rec)
                data = f.read(incl)
                op = flags & 0xFFFF
                name = None
                if op == 2 and len(data) >= 3:
                    name = CMDS.get(struct.unpack("<H", data[:2])[0])
                elif op == 3 and len(data) >= 2:
                    name = EVTS.get(data[0])
                elif op in (4, 5) and len(data) >= 8 and ((data[1] >> 4) & 3) != 1:
                    cid = struct.unpack("<H", data[6:8])[0]
                    if cid in (0x0006, 0x0007):
                        name = f"SMP PDU (CID 0x{cid:04x})"
                if name:
                    when = datetime.fromtimestamp((ts - EPOCH) / 1e6).strftime("%Y-%m-%d %H:%M:%S")
                    entry = found.setdefault(name, [0, when, len(data)])
                    entry[0] += 1
        print(path)
        if not found:
            print("  none")
        for name, (n, when, length) in found.items():
            print(f"  {name}: {n} (first {when}, {length} bytes)")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
