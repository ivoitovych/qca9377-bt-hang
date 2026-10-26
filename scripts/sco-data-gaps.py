#!/usr/bin/env python3
"""sco-data-gaps.py — did SCO voice data flow without a break on a link through a time window?
Per direction (host->controller and controller->host) and handle: packet count, first and last
packet, and the largest gap between two packets inside the window. A link that dropped and came
back with the same handle shows as a gap; a steady link shows gaps of a few ms (one packet per
7.5 ms at mSBC/CVSD rates).

  python3 -I scripts/sco-data-gaps.py <capture.btsnoop> "<from>" "<to>"
      from/to as "2026-10-26 05:40:30" (local time); bt-capture's monitor-format files.

Read-only; prints handles, never addresses. Timestamps are bt-capture's receive times.
"""
import struct
import sys
from datetime import datetime

BTSNOOP_TS_OFFSET = 0x00E03AB44A676000
UNIX_2000 = 946684800
MON_SCO_TX, MON_SCO_RX = 6, 7


def local(us):
    return datetime.fromtimestamp((us - BTSNOOP_TS_OFFSET) / 1e6 + UNIX_2000)


def main(argv):
    if len(argv) != 4:
        sys.exit(__doc__)
    path = argv[1]
    t_from = datetime.strptime(argv[2], "%Y-%m-%d %H:%M:%S")
    t_to = datetime.strptime(argv[3], "%Y-%m-%d %H:%M:%S")
    with open(path, "rb") as f:
        data = f.read()
    if data[:8] != b"btsnoop\0" or struct.unpack_from(">I", data, 12)[0] != 2001:
        sys.exit(f"{path}: not a monitor-format btsnoop file")
    stats = {}
    off, n = 16, len(data)
    while off + 24 <= n:
        _olen, ilen, flags, _drops, ts = struct.unpack_from(">IIIIq", data, off)
        off += 24
        if off + ilen > n:
            break
        op = flags & 0xFFFF
        if (flags >> 16) == 0 and op in (MON_SCO_TX, MON_SCO_RX) and ilen >= 3:
            t = local(ts)
            if t_from <= t <= t_to:
                h = struct.unpack_from("<H", data, off)[0] & 0x0FFF
                key = ("host->ctrl" if op == MON_SCO_TX else "ctrl->host", h)
                s = stats.setdefault(key, {"n": 0, "first": ts, "last": ts, "gap": 0, "at": ts})
                if s["n"] and ts - s["last"] > s["gap"]:
                    s["gap"], s["at"] = ts - s["last"], s["last"]
                s["n"] += 1
                s["last"] = ts
        off += ilen
    if not stats:
        print("no SCO data in the window")
        return 1
    for (d, h), s in sorted(stats.items()):
        print(f"{d}  handle {h}: {s['n']} packets, "
              f"{local(s['first']).isoformat(sep=' ', timespec='microseconds')} to "
              f"{local(s['last']).isoformat(sep=' ', timespec='microseconds')}, "
              f"largest gap {s['gap'] / 1e3:.1f} ms after "
              f"{local(s['at']).isoformat(sep=' ', timespec='microseconds')}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
