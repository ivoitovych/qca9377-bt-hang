#!/usr/bin/env python3
"""gain-by-device.py - for each headset, the AT+VGM/AT+VGS values it reported to WirePlumber's HFP
AG, attributed to the last HFPAG NewConnection before the line. Reads a journal extract
(journal-user-gain-history.txt of the 2026-10-23 MOMENTUM incident). Prints the device path as in
the journal: run it locally; publish only through the pseudonym table.
Usage: gain-by-device.py <journal extract>"""
import collections
import re
import sys

conn = re.compile(r"NewConnection path=/org/bluez/hci0/dev_([0-9A-F_]+), .*HFPAG")
gain = re.compile(r"RFCOMM << AT\+(VG[MS])=(\d+)")
cur = None
counts = collections.defaultdict(collections.Counter)
first = {}
last = {}
for line in open(sys.argv[1], errors="replace"):
    m = conn.search(line)
    if m:
        cur = m.group(1)
        continue
    m = gain.search(line)
    if m and cur:
        key = (cur, m.group(1), int(m.group(2)))
        counts[cur][(m.group(1), int(m.group(2)))] += 1
        ts = line.split()[0]
        first.setdefault(key, ts)
        last[key] = ts
for dev in sorted(counts):
    print(dev)
    for (kind, val), n in sorted(counts[dev].items()):
        print(f"  AT+{kind}={val:02d}  x{n:<4} first {first[(dev, kind, val)]}  last {last[(dev, kind, val)]}")
