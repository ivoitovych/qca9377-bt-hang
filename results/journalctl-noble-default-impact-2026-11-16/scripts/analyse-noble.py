#!/usr/bin/env python3
"""analyse-noble.py TSV : per set and query, stock against patched (median of runs): wall, CPU (user+sys), lines, speed-up.
TSV columns: set, who, query, run, rc, wall_s, user_s, sys_s, lines_or_bytes, capped."""
import statistics
import sys
from collections import defaultdict

R = defaultdict(list)
order = []
for line in open(sys.argv[1]):
    p = line.rstrip("\n").split("\t")
    if len(p) != 10:
        continue
    s, who, q, run, rc, wall, u, sy, n, cap = p
    key = (s, q)
    if key not in order:
        order.append(key)
    R[(key, who)].append((float(wall), float(u) + float(sy), int(n), int(cap), int(rc)))


def med(key, who):
    r = R.get((key, who))
    if not r:
        return None
    return (statistics.median(x[0] for x in r), statistics.median(x[1] for x in r), max(x[2] for x in r), max(x[3] for x in r))


cur = None
for key in order:
    s, q = key
    if s != cur:
        cur = s
        print(f"\n== {s}")
        print(f"{'query':72} {'stock wall':>10} {'stock cpu':>10} {'patch wall':>10} {'patch cpu':>10} {'lines/bytes':>12}  speed-up (wall)")
    a, b = med(key, "stock"), med(key, "patched")
    if not a or not b:
        continue
    sp = f"{a[0] / b[0]:.1f}x" if b[0] > 0.02 else "-"
    flag = " STOCK TIMED OUT" if a[3] else ""
    print(f"{q[:72]:72} {a[0]:10.2f} {a[1]:10.2f} {b[0]:10.2f} {b[1]:10.2f} {b[2]:12d}  {sp}{flag}")
