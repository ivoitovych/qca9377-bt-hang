#!/usr/bin/env python3
"""Which disc sectors the drive was asked for, burst by burst (issue X1).

  lbas.py <usbmon.txt> [gap_s]

Reads trace.py's usbmon text, picks the bulk-out command blocks (USB mass storage CBW,
signature 55534243) whose SCSI command is READ CD (0xBE), and prints per burst (commands
closer than gap_s, default 1.0 s): wall-clock start, number of commands, first and last LBA,
sectors requested, and how many of those sectors had been requested before (re-reads).
Wall clock comes from the "# HH:MM:SS.ffffff monotonic N" header line trace.py writes: usbmon
text stamps are (CLOCK_MONOTONIC seconds mod 4096) * 1e6 + microseconds, so each command's
offset from the header's monotonic value is added to the header's wall time.
"""
import sys
from datetime import datetime, timedelta

path = sys.argv[1]
gap = float(sys.argv[2]) if len(sys.argv) > 2 else 1.0
anchor = None
cmds = []  # (usec, lba, count)
with open(path, errors="replace") as fh:
    for line in fh:
        if line.startswith("# ") and "monotonic" in line:
            w = line.split()
            anchor = datetime.strptime(w[1], "%H:%M:%S.%f")
            mono = float(w[3])
            # usbmon text stamps: (monotonic seconds mod 4096) * 1e6 + microseconds
            anchor_us = (int(mono) % 4096) * 1_000_000 + int((mono % 1) * 1e6)
            continue
        f = line.split()
        if len(f) < 8 or f[2] != "S" or not f[3].startswith("Bo:") or "=" not in f:
            continue
        hexs = "".join(f[f.index("=") + 1:])
        if not hexs.startswith("55534243") or len(hexs) < 62:
            continue
        cdb = bytes.fromhex(hexs[30:62])
        if cdb[0] != 0xBE:
            continue
        lba = int.from_bytes(cdb[2:6], "big")
        cnt = int.from_bytes(cdb[6:9], "big")
        cmds.append((int(f[1]), lba, cnt))

if not cmds:
    print("no READ CD commands found")
    sys.exit(0)
t0 = cmds[0][0]
seen = set()
bursts = []
cur = [cmds[0]]
for c in cmds[1:]:
    if (c[0] - cur[-1][0]) / 1e6 > gap:
        bursts.append(cur)
        cur = [c]
    else:
        cur.append(c)
bursts.append(cur)

print(f"{len(cmds)} READ CD commands in {len(bursts)} bursts; 75 sectors = 1 s of audio")
print("start            cmds  first_lba  last_lba  sectors  reread  audio_s  pause_before_s")
prev_end = None
for b in bursts:
    start_us = b[0][0]
    secs = sum(c[2] for c in b)
    reread = 0
    for _, lba, cnt in b:
        for s in range(lba, lba + cnt):
            if s in seen:
                reread += 1
            seen.add(s)
    if anchor:
        d = (start_us - anchor_us) % (4096 * 1_000_000)
        wall = (anchor + timedelta(microseconds=d)).strftime("%H:%M:%S.%f")[:-3]
    else:
        wall = f"+{(start_us - t0)/1e6:.3f}"
    pause = f"{(start_us - prev_end)/1e6:.2f}" if prev_end else "-"
    print(f"{wall:15}  {len(b):4}  {b[0][1]:9}  {b[-1][1] + b[-1][2] - 1:8}  {secs:7}  {reread:6}  {secs/75:7.1f}  {pause}")
    prev_end = b[-1][0]
