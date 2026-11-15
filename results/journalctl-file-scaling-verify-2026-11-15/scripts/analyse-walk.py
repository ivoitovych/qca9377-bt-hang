#!/usr/bin/env python3
"""analyse-walk.py TSV REF [KMIN] : the part of the per-entry cost that grows with the file count.
Per-entry cost c(v, K) = 1/median(lines/s). The cost that does not depend on the number of files (formatting,
reading the entry) is estimated by the REF variant's cost at the largest K (the queue-based prototype, whose walk
costs O(log F)); walk(v, K) = c(v, K) - that. Fit log walk against log K for K >= KMIN: the walk's exponent w,
and the total time of a read (N proportional to K) then grows like K^(1+w) once the walk dominates."""
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
ref = sys.argv[2]
kmin = int(sys.argv[3]) if len(sys.argv) > 3 else 50
ks = sorted({k for _, k in rows})
fixed = 1e6 / statistics.median(rows[(ref, ks[-1])])
print(f"fixed cost per entry (variant {ref} at K={ks[-1]}): {fixed:.2f} us")
print("walk cost per entry, us (cost minus fixed), and exponent w over K >= %d" % kmin)
print("variant " + " ".join(f"{k:>8}" for k in ks) + "     w")
for v in sorted({v for v, _ in rows}):
    if v == ref:
        continue
    cells, xs, ys = [], [], []
    for k in ks:
        if (v, k) not in rows:
            cells.append(f"{'-':>8}")
            continue
        w = 1e6 / statistics.median(rows[(v, k)]) - fixed
        cells.append(f"{w:8.2f}")
        if k >= kmin and w > 0:
            xs.append(math.log(k)); ys.append(math.log(w))
    sl = ""
    if len(xs) >= 2:
        mx, my = sum(xs) / len(xs), sum(ys) / len(ys)
        sl = f"{sum((x - mx) * (y - my) for x, y in zip(xs, ys)) / sum((x - mx) ** 2 for x in xs):6.2f}"
    print(f"{v:7} " + " ".join(cells) + f"  {sl}")
