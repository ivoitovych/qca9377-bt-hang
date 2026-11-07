#!/usr/bin/env python3
"""Summarise a cd-gaps run: read bursts on sr0 and the pw-top error counters over time.

  analyse.py <rundir>
"""
import re
import sys
from pathlib import Path

d = Path(sys.argv[1])
rows = [l.split("\t") for l in (d / "sr0.tsv").read_text().splitlines()[1:] if l.count("\t") == 2]

print("== sr0 read bursts (consecutive samples with sectors read) ==")
burst = None
last_end = None
for t, delta, inflight in rows:
    n = int(delta)
    if n > 0 and burst is None:
        burst = [t, t, n]
    elif n > 0:
        burst[1] = t
        burst[2] += n
    elif n == 0 and burst is not None:
        print(f"burst {burst[0]} .. {burst[1]}  sectors {burst[2]:>7}  (~{burst[2]*512/176400:.1f} s of audio)")
        burst = None
if burst:
    print(f"burst {burst[0]} .. {burst[1]}  sectors {burst[2]:>7}  (open)")

print("== pw-top: nodes with ERR > 0, first and changing values ==")
lastval = {}
block = 0
for line in (d / "pw-top.txt").read_text().splitlines():
    if line.startswith("S   ID"):
        block += 1
        continue
    m = re.match(r"^(\S)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\d+)\s+(.*)$", line)
    if not m:
        continue
    err = int(m.group(9))
    name = m.group(10).strip()
    key = (m.group(2), name)
    if err != lastval.get(key, 0):
        print(f"block {block:>4} (~{block}s)  id {m.group(2):>4} quant {m.group(3):>5} rate {m.group(4):>6} "
              f"wait {m.group(5):>8} busy {m.group(6):>8} ERR {err:>4}  {name}")
        lastval[key] = err
