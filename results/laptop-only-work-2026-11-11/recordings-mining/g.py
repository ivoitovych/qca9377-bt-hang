#!/usr/bin/env python3
"""g.py <regex> [--ident REGEX] [--max N] [--from 'YYYY-MM-DD HH:MM'] [--to ...] [--count-only] [--maxprio N]
Search ext/*.tsv; print 'local-time boot ident[pid] prio message' with MAC addresses replaced by <MAC>."""
import argparse
import glob
import re
from datetime import datetime

ap = argparse.ArgumentParser()
ap.add_argument("rx")
ap.add_argument("--ident")
ap.add_argument("--max", type=int, default=60)
ap.add_argument("--from", dest="t0")
ap.add_argument("--to", dest="t1")
ap.add_argument("--count-only", action="store_true")
ap.add_argument("--group")
ap.add_argument("--maxprio", type=int, default=9)
ap.add_argument("--width", type=int, default=260)
ap.add_argument("--dir", default="/root/exp/agent-work/laptop-evidence-mining-20261111/ext")
a = ap.parse_args()
rx = re.compile(a.rx)
irx = re.compile(a.ident) if a.ident else None
MAC = re.compile(r"\b[0-9A-Fa-f]{2}(?:[:_][0-9A-Fa-f]{2}){5}\b")
f = lambda s: datetime.strptime(s, "%Y-%m-%d %H:%M").timestamp() * 1e6 if s else None
t0, t1 = f(a.t0), f(a.t1)
rows = []
for path in glob.glob(a.dir + "/*.tsv"):
    boot = path.rsplit("-", 1)[1].split(".")[0]
    with open(path, errors="replace") as fh:
        for line in fh:
            p = line.rstrip("\n").split("\t", 6)
            if len(p) < 7:
                continue
            if not rx.search(p[6]):
                continue
            if irx and not irx.search(p[1]):
                continue
            try:
                t = int(p[0])
            except ValueError:
                continue
            if (t0 and t < t0) or (t1 and t > t1):
                continue
            if p[3].isdigit() and int(p[3]) > a.maxprio:
                continue
            rows.append((t, boot, p))
rows.sort(key=lambda r: r[0])
byboot = {}
for t, b, p in rows:
    byboot[b] = byboot.get(b, 0) + 1
print("total", len(rows), "per boot:", " ".join(f"{b}={n}" for b, n in sorted(byboot.items())))
if a.group:
    gx = re.compile(a.group)
    cnt = {}
    for t, b, p in rows:
        if a.group == "DAY":
            k = datetime.fromtimestamp(t / 1e6).strftime("%Y-%m-%d")
        else:
            m = gx.search(p[6])
            k = (m.group(1) if m.groups() else m.group(0)) if m else "?"
        c = cnt.setdefault(k, [0, t, t, set()])
        c[0] += 1
        c[2] = t
        c[3].add(b)
    for k, c in sorted(cnt.items(), key=lambda kv: -kv[1][0]):
        fm = lambda x: datetime.fromtimestamp(x / 1e6).strftime("%m-%d %H:%M:%S")
        print(f"{c[0]:6d}  {fm(c[1])} .. {fm(c[2])}  boots={len(c[3])}  {k[:150]}")
    raise SystemExit
if not a.count_only:
    seen = set()
    for t, b, p in rows[: a.max]:
        d = datetime.fromtimestamp(t / 1e6).strftime("%Y-%m-%d %H:%M:%S.%f")
        print(d, b[:4], f"{p[1]}[{p[2]}]", p[3], MAC.sub("<MAC>", p[6])[: a.width])
