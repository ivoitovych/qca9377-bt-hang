#!/usr/bin/env python3
"""Show the read rhythm of gvfsd-cdda: bursts of disc ioctls and the pauses between them,
and the client-socket writes, against a list of underflow times.

  rhythm.py <strace.txt> <underflow HH:MM:SS.ffffff> [...]
"""
import re
import sys
from datetime import datetime

rx = re.compile(r"^(\d+)\s+(\d\d:\d\d:\d\d\.\d+)\s+(\w+)\((.*)\)\s+=\s+(-?\w+).*<(\d+\.\d+)>$")


def t(s):
    return datetime.strptime(s, "%H:%M:%S.%f")


under = [t(u) for u in sys.argv[2:]]
ioctls, writes = [], []
for line in open(sys.argv[1], errors="replace"):
    m = rx.match(line.rstrip())
    if not m:
        continue
    pid, ts, call, args, ret, dur = m.groups()
    if call == "ioctl" and "CDROM_SEND_PACKET" in args:
        ioctls.append((t(ts), float(dur)))
    elif call == "write":
        writes.append((t(ts), int(ret) if ret.lstrip("-").isdigit() else 0))

print("== disc-read bursts (ioctls closer than 1 s) ==")
bursts = []
cur = None
for ts, dur in ioctls:
    if cur and (ts - cur[1]).total_seconds() < 1.0:
        cur[1] = ts
        cur[2] += 1
    else:
        if cur:
            bursts.append(cur)
        cur = [ts, ts, 1]
if cur:
    bursts.append(cur)
prev_end = None
for b in bursts:
    pause = f"pause {(b[0]-prev_end).total_seconds():6.2f} s before" if prev_end else ""
    print(f"{b[0].time()} .. {b[1].time()}  {b[2]:4d} reads  {(b[1]-b[0]).total_seconds():5.2f} s  {pause}")
    prev_end = b[1]

print("== around each underflow: last disc read before, first after; bytes written to the client in the 3 s before ==")
for u in under:
    before = [x for x, _ in ioctls if x <= u]
    after = [x for x, _ in ioctls if x > u]
    wbytes = sum(n for x, n in writes if 0 <= (u - x).total_seconds() <= 3)
    lb = f"{(u-before[-1]).total_seconds():6.2f} s before" if before else "none"
    fa = f"{(after[0]-u).total_seconds():6.2f} s after" if after else "none"
    print(f"underflow {u.time()}: last read {lb}; next read {fa}; client writes in prior 3 s: {wbytes} bytes")
