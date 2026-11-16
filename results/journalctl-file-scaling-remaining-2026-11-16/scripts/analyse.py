#!/usr/bin/env python3
"""analyse.py TSV [KMIN] : median lines/s per (variant, K), and the exponent.
TSV columns: variant, K, run, lines, seconds.  K may look like 'all(553)'; the number in brackets is used.
Per-entry cost c(K) = seconds/lines (median over runs of the rate). With N proportional to K (a fixed
number of entries per file), the time to read everything is T = N*c ~ K * c, so
    b_total = 1 + slope of log c against log K, fitted over K >= KMIN (default 50).
"""
import math
import re
import statistics
import sys
from collections import defaultdict

rows = defaultdict(list)
for line in open(sys.argv[1]):
    p = line.rstrip("\n").split("\t")
    if len(p) != 5:
        continue
    v, k, _, n, s = p
    m = re.search(r"\((\d+)\)", k)
    k = int(m.group(1)) if m else int(k)
    if int(n) > 0 and float(s) > 0:
        rows[(v, k)].append(int(n) / float(s))
kmin = int(sys.argv[2]) if len(sys.argv) > 2 else 50
variants = sorted({v for v, _ in rows})
ks = sorted({k for _, k in rows})
print("lines/s (median of runs)")
print("variant " + " ".join(f"{k:>9}" for k in ks) + "   exponent b_total (K>=%d)   slope of cost" % kmin)
for v in variants:
    cells, xs, ys = [], [], []
    for k in ks:
        if (v, k) in rows:
            r = statistics.median(rows[(v, k)])
            cells.append(f"{r:9.0f}")
            if k >= kmin:
                xs.append(math.log(k)); ys.append(math.log(1.0 / r))
        else:
            cells.append(f"{'-':>9}")
    if len(xs) >= 2:
        mx, my = sum(xs) / len(xs), sum(ys) / len(ys)
        sl = sum((x - mx) * (y - my) for x, y in zip(xs, ys)) / sum((x - mx) ** 2 for x in xs)
        print(f"{v:7} " + " ".join(cells) + f"   {1 + sl:6.2f}   {sl:6.2f}")
    else:
        print(f"{v:7} " + " ".join(cells))
print()
print("per-entry cost, microseconds")
for v in variants:
    print(f"{v:7} " + " ".join(f"{1e6 / statistics.median(rows[(v, k)]):9.1f}" if (v, k) in rows else f"{'-':>9}" for k in ks))
