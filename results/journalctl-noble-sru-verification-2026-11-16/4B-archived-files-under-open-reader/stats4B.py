#!/usr/bin/env python3
"""stats4B.py TSV... : pool all runs per (reader, mode, victim, build) and compare stock (s819) with patched (p820).
Per cell: runs, failures (exit status not 0; a negative number is a signal: -7 = SIGBUS, 1 = journalctl 'Bad message'),
mean entries, mean entries missing from surviving files, two-sided Fisher exact p for the failure counts."""
import collections
import math
import sys


def fisher(a, b, c, d):
    """two-sided Fisher exact p for [[a,b],[c,d]]"""
    n = a + b + c + d
    r1, c1 = a + b, a + c

    def pr(x):
        return math.comb(r1, x) * math.comb(n - r1, c1 - x) / math.comb(n, c1)
    p0 = pr(a)
    lo, hi = max(0, c1 - (n - r1)), min(r1, c1)
    return min(1.0, sum(pr(x) for x in range(lo, hi + 1) if pr(x) <= p0 * (1 + 1e-9)))


rows = collections.defaultdict(list)
for path in sys.argv[1:]:
    for line in open(path):
        p = line.rstrip("\n").split("\t")
        if p[0] == "build" or len(p) < 13:
            continue
        if len(p) > 13 and ("GDB:" in p[13] or "address space randomization" in p[13]):
            continue
        b, rd, mode, victim, rep, K, rem, rc, n, miss, dup, fr, order = p[:13]
        rows[(rd, mode, victim)].append((b, rc, int(n), int(miss), int(dup)))

print(f"{'reader':10} {'mode':9} {'victim':8} | {'runs':>4} {'fail':>4} {'miss':>7} | {'runs':>4} {'fail':>4} {'miss':>7} | Fisher p (failure counts)")
print(f"{'':29} | {'stock':^17} | {'patched':^17} |")
for key, rs in sorted(rows.items()):
    out = []
    cnt = {}
    for b in ("s819", "p820"):
        x = [r for r in rs if r[0] == b]
        f = sum(1 for r in x if r[1] not in ("0", "followed"))
        cnt[b] = (f, len(x) - f)
        out.append((len(x), f, sum(r[3] for r in x) / max(len(x), 1)))
    if out[0][0] < 3 or out[1][0] < 3:
        continue
    p = fisher(cnt["s819"][0], cnt["s819"][1], cnt["p820"][0], cnt["p820"][1])
    flag = "  <-- p < 0.05" if p < 0.05 else ""
    print(f"{key[0]:10} {key[1]:9} {key[2]:8} | {out[0][0]:4d} {out[0][1]:4d} {out[0][2]:7.0f} | {out[1][0]:4d} {out[1][1]:4d} {out[1][2]:7.0f} | {p:.3f}{flag}")
