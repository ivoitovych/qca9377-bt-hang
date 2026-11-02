#!/usr/bin/env python3
"""List slow system calls in an strace -tt -T file, and a per-call-type summary.

  slowcalls.py <strace.txt> [threshold_seconds]
"""
import re
import sys
from collections import defaultdict

thr = float(sys.argv[2]) if len(sys.argv) > 2 else 0.05
rx = re.compile(r"^(\d+)\s+(\d\d:\d\d:\d\d\.\d+)\s+(\w+)\((.*)\)\s+=\s+(-?\w+).*<(\d+\.\d+)>$")
stats = defaultdict(lambda: [0, 0.0, 0.0])
slow = []
for line in open(sys.argv[1], errors="replace"):
    m = rx.match(line.rstrip())
    if not m:
        continue
    pid, ts, call, args, ret, dur = m.groups()
    dur = float(dur)
    key = call
    if call == "ioctl":
        a = args.split(",")
        key = "ioctl " + (a[1].strip() if len(a) > 1 else "?")
    s = stats[key]
    s[0] += 1
    s[1] += dur
    s[2] = max(s[2], dur)
    if dur >= thr:
        slow.append((ts, pid, key, ret, dur))

print("== per call type: count, total s, max s ==")
for k, (n, tot, mx) in sorted(stats.items(), key=lambda x: -x[1][1]):
    print(f"{k:40s} {n:8d} {tot:9.3f} {mx:8.3f}")
print(f"== calls >= {thr} s ==")
for ts, pid, key, ret, dur in slow:
    print(f"{ts} pid {pid} {key:30s} ret {ret:>8} {dur:7.3f} s")
