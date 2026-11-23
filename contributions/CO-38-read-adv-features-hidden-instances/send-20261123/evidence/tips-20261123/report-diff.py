#!/usr/bin/env python3
"""report-diff.py <runs-dir> : kernel reports (BUG, WARNING, KASAN, lockdep, UBSAN, refcount, list corruption,
general protection fault, Oops) per tree and tester, base against co38 and co44. Hung-task reports are left out:
compare-tips.py handles them (HUNG lines). Prints the report headlines that differ from base."""
import re
import sys
from pathlib import Path

ANSI = re.compile(r"\x1b\[[0-9;]*m")
REP = re.compile(r"(BUG: .*|WARNING: .*|KASAN: .*|possible circular locking dependency.*|possible recursive locking.*|"
                 r"inconsistent lock state.*|UBSAN: .*|refcount_t: .*|list_(?:add|del) corruption.*|"
                 r"general protection fault.*|Oops: .*)")
d = Path(sys.argv[1])
TREES = ["next", "main", "7.3", "6.18", "6.12", "6.6", "6.1"]
TESTERS = ["bnep", "iso", "l2cap", "mgmt", "rfcomm", "sco", "ioctl", "mesh", "smp", "userchan"]


def heads(p):
    if not p.exists():
        return None
    out = set()
    for l in p.read_text(encoding="utf-8", errors="replace").split("\n"):
        m = REP.search(ANSI.sub("", l))
        if m:
            h = re.sub(r"\+0x[0-9a-f]+/0x[0-9a-f]+", "", m.group(1))
            h = re.sub(r"ffff[0-9a-f]{12}", "ADDR", h)
            out.add(h.strip()[:120])
    return out


any_report = 0
for t in TREES:
    for s in TESTERS:
        b = heads(d / f"{t}-base-{s}-full.log")
        for v in ("co38", "co44"):
            x = heads(d / f"{t}-{v}-{s}-full.log")
            if b is None or x is None:
                continue
            if b or x:
                any_report += 1
            new, gone = sorted(x - b), sorted(b - x)
            if new or gone:
                print(f"{t} {s} {v}: new {new} gone {gone}")
            elif b:
                print(f"{t} {s} {v}: same reports as base: {sorted(b)}")
print(f"pairs with any report: {any_report}")
