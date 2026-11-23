#!/usr/bin/env python3
"""compare-tips.py <runs-dir> : for the current-tips runs (run-tips.sh), per tree:
- the targeted cases: CO-38's case on base and co38, CO-44's case on base and co44, 3 runs each (pass counts);
- every tester's full run on base, co38 and co44: the cases whose verdict differs from base, by name;
- HUNG lines (watchdog) with their case, which must be the same on all three images.
Verdicts are read through ANSI codes and CRLF line ends."""
import re
import sys
from pathlib import Path

ANSI = re.compile(r"\x1b\[[0-9;]*m")
VERD = re.compile(r"^(.+?)\s+(Passed|Failed|Not Run|Timed out)\s+[\d.]+ seconds")
d = Path(sys.argv[1])
TREES = ["next", "main", "7.3", "6.18", "6.12", "6.6", "6.1"]
TESTERS = ["bnep", "iso", "l2cap", "mgmt", "rfcomm", "sco", "ioctl", "mesh", "smp", "userchan"]


def read(p):
    if not p.exists():
        return None
    lines = [ANSI.sub("", l).rstrip("\r") for l in p.read_text(encoding="utf-8", errors="replace").split("\n")]
    v = {}
    for l in lines:
        m = VERD.match(l)
        if m:
            v[m.group(1).strip()] = m.group(2)
    hung = next((l[len("HUNG in: "):].split(" (guest")[0] for l in lines if l.startswith("HUNG in:")), None)
    total = next((l for l in reversed(lines) if l.startswith("Total:")), None)
    return v, hung, total


problems = 0
for t in TREES:
    print(f"== {t}")
    for case, pv in (("co38", "co38"), ("co44", "co44")):
        res = []
        for v in ("base", pv):
            passed = 0
            for k in (1, 2, 3):
                r = read(d / f"{t}-{v}-{case}-case{k}.log")
                if r and r[2] and "Passed: 1 " in r[2]:
                    passed += 1
            res.append(f"{v} {passed}/3 pass")
        print(f"  {case} case: {', '.join(res)}")
    for s in TESTERS:
        rb = read(d / f"{t}-base-{s}-full.log")
        if rb is None:
            print(f"  {s}: no base log")
            problems += 1
            continue
        for v in ("co38", "co44"):
            rv = read(d / f"{t}-{v}-{s}-full.log")
            if rv is None:
                print(f"  {s} {v}: no log")
                problems += 1
                continue
            diffs = [f"{c}: {rb[0].get(c, '-')} -> {rv[0].get(c, '-')}" for c in sorted(set(rb[0]) | set(rv[0]))
                     if rb[0].get(c) != rv[0].get(c)]
            if rb[1] != rv[1]:
                diffs.append(f"HUNG differs: base {rb[1]!r}, {v} {rv[1]!r}")
            note = f" (both HUNG in {rb[1]!r})" if rb[1] and rb[1] == rv[1] else ""
            if diffs:
                print(f"  {s} {v}: {len(diffs)} changed{note}")
                for x in diffs:
                    print(f"      {x}")
            elif note:
                print(f"  {s} {v}: no change{note}")
print(f"missing logs: {problems}")
