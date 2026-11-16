#!/usr/bin/env python3
"""analyse-queries.py TSV... : per (env, what, query): median wall time for a and b, lines, whether capped, speed-up.
Input columns: env, variant, what, query, lines, seconds, capped.
Speed-up = time(a)/time(b) when both runs finished; when a run hit the cap, the rates (lines/s) are compared
instead and marked 'rate'. Queries that print (almost) nothing and were capped (a full scan with no hits) cannot be
compared this way and are marked 'not finished'."""
import statistics
import sys
from collections import defaultdict

rows = defaultdict(list)
order = []
for path in sys.argv[1:]:
    for line in open(path):
        p = line.rstrip("\n").split("\t")
        if len(p) != 7:
            continue
        env, v, what, q, n, s, cap = p
        key = (env, what, q)
        if key not in order:
            order.append(key)
        rows[(key, v)].append((int(n), float(s), int(cap)))


def med(key, v):
    r = rows.get((key, v))
    if not r:
        return None
    return (statistics.median(x[0] for x in r), statistics.median(x[1] for x in r), max(x[2] for x in r))


print(f"{'env':9} {'set':6} {'query':26} {'a time s':>9} {'b time s':>9} {'a lines':>10} {'b lines':>10} {'capped a/b':>10}  speed-up")
for key in order:
    a, b = med(key, "a"), med(key, "b")
    if not a or not b:
        continue
    env, what, q = key
    if a[2] == 0 and b[2] == 0:
        sp = f"{a[1] / b[1]:.1f}x (time)"
    elif a[0] > 0 and b[0] > 0 and (a[2] or b[2]) and max(a[0], b[0]) > 1000:
        sp = f"{(b[0] / b[1]) / (a[0] / a[1]):.1f}x (rate)"
    else:
        sp = "not finished"
    print(f"{env:9} {what:6} {q:26} {a[1]:9.2f} {b[1]:9.2f} {a[0]:10.0f} {b[0]:10.0f} {a[2]}/{b[2]:<8}  {sp}")
