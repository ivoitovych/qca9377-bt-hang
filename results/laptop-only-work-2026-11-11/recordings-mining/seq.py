#!/usr/bin/env python3
"""seq.py <anchor-regex> <follow-regex> <window s> [--ident R] [--from T] [--to T] [--max N]
For each entry matching anchor (within ident), print the entries matching follow-regex within the window after it, as '+dt shortmsg'."""
import argparse
import glob
import re
from datetime import datetime

ap = argparse.ArgumentParser()
ap.add_argument("anchor")
ap.add_argument("follow")
ap.add_argument("win", type=float)
ap.add_argument("--ident", default="bluetoothd")
ap.add_argument("--from", dest="t0")
ap.add_argument("--to", dest="t1")
ap.add_argument("--max", type=int, default=40)
ap.add_argument("--short", default=r"(?:[a-z_]+\.c:)?([a-z_]+)\(\)(.{0,60})")
a = ap.parse_args()
f = lambda s: datetime.strptime(s, "%Y-%m-%d %H:%M").timestamp() * 1e6 if s else None
t0, t1 = f(a.t0), f(a.t1)
irx = re.compile(a.ident)
arx, frx, srx = re.compile(a.anchor), re.compile(a.follow), re.compile(a.short)
MAC = re.compile(r"\b[0-9A-Fa-f]{2}(?:[:_][0-9A-Fa-f]{2}){5}\b")
byboot = {}
for p in glob.glob("/root/exp/agent-work/laptop-evidence-mining-20261111/ext/*.tsv"):
    rows = []
    for line in open(p, errors="replace"):
        q = line.rstrip("\n").split("\t", 6)
        if len(q) == 7 and irx.search(q[1]):
            t = int(q[0])
            if (t0 and t < t0) or (t1 and t > t1):
                continue
            rows.append((t, q[6]))
    rows.sort()
    byboot[p] = rows
allrows = []
for rows in byboot.values():
    n = len(rows)
    for i, (t, m) in enumerate(rows):
        if arx.search(m):
            fol = []
            for t2, m2 in rows[i + 1:i + 300]:
                if t2 - t > a.win * 1e6:
                    break
                if frx.search(m2):
                    s = srx.search(m2)
                    fol.append("+%.2f %s" % ((t2 - t) / 1e6, MAC.sub("<MAC>", (s.group(0) if s else m2))[:70]))
            allrows.append((t, MAC.sub("<MAC>", m)[:60], fol))
allrows.sort()
print("anchors:", len(allrows))
for t, m, fol in allrows[: a.max]:
    print(datetime.fromtimestamp(t / 1e6).strftime("%m-%d %H:%M:%S"), m, "|", " ; ".join(fol[:8]))
