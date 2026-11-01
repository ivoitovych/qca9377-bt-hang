#!/usr/bin/env python3
"""Print every HCI command and the SCO-relevant events of a btsnoop
monitor capture between two UTC times, one line each, no addresses.

Usage: sco-cmd-timeline.py <capture.btsnoop> "<from UTC>" "<to UTC>"
       times as YYYY-MM-DD HH:MM:SS
"""
import struct
import sys
from datetime import datetime, timezone

EPOCH_DELTA = 0x00DCDDB30F2F8000
NAMES = {0x0405: "Create Connection", 0x0406: "Disconnect", 0x0408: "Create Connection Cancel",
         0x0428: "Setup Synchronous Connection", 0x043D: "Enhanced Setup Synchronous Connection",
         0x0429: "Accept Synchronous Connection", 0x0803: "Sniff Mode", 0x0804: "Exit Sniff Mode",
         0x0C03: "Reset"}
EVENTS = {0x03: "Connection Complete", 0x05: "Disconnection Complete", 0x0E: "Command Complete",
          0x0F: "Command Status", 0x14: "Mode Change", 0x2C: "Synchronous Connect Complete",
          0x10: "Hardware Error"}


def t(s):
    return int(datetime.strptime(s, "%Y-%m-%d %H:%M:%S").replace(tzinfo=timezone.utc).timestamp() * 1e6)


def main(path, frm, to):
    lo, hi = t(frm), t(to)
    with open(path, "rb") as f:
        f.read(16)
        rh = struct.Struct(">IIIIq")
        while True:
            h = f.read(24)
            if len(h) < 24:
                break
            _o, incl, flags, _d, ts = rh.unpack(h)
            data = f.read(incl)
            us = ts - EPOCH_DELTA
            if us < lo:
                continue
            if us > hi:
                break
            op = flags & 0xFFFF
            when = datetime.fromtimestamp(us / 1e6, tz=timezone.utc).strftime("%H:%M:%S.%f")
            if op == 2 and incl >= 3:
                oc = data[0] | (data[1] << 8)
                print(f"{when}  < CMD 0x{oc:04x} {NAMES.get(oc, '')}")
            elif op == 3 and incl >= 2:
                e = data[0]
                p = data[2:]
                extra = ""
                if e == 0x0F and len(p) >= 4:
                    extra = f"status=0x{p[0]:02x} opcode=0x{p[2] | (p[3] << 8):04x}"
                elif e == 0x0E and len(p) >= 4:
                    extra = f"opcode=0x{p[1] | (p[2] << 8):04x} status=0x{p[3]:02x}"
                elif e in (0x2C, 0x03) and len(p) >= 10:
                    extra = f"status=0x{p[0]:02x} handle=0x{(p[1] | (p[2] << 8)) & 0xfff:03x} type={p[9]}"
                elif e == 0x05 and len(p) >= 4:
                    extra = f"status=0x{p[0]:02x} handle=0x{(p[1] | (p[2] << 8)) & 0xfff:03x} reason=0x{p[3]:02x}"
                elif e == 0x14 and len(p) >= 4:
                    extra = f"status=0x{p[0]:02x} mode={p[3]}"
                if e in EVENTS:
                    print(f"{when}  > EVT {EVENTS[e]} {extra}")
            elif op in (0, 1, 8, 9, 10, 11, 12):
                print(f"{when}  # monitor op {op}")


if __name__ == "__main__":
    main(*sys.argv[1:4])
