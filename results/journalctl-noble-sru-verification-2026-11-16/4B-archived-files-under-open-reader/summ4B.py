#!/usr/bin/env python3
"""summ4B.py TSV : per (reader, mode, victim) cell, stock against patched: runs, exit statuses, entries, missing from surviving
files, from removed files, duplicates, ordering, messages. Prints one line per cell and flags differences."""
import collections
import sys

rows = collections.defaultdict(list)
for line in open(sys.argv[1]):
    p = line.rstrip("\n").split("\t")
    if p[0] == "build" or len(p) < 13:
        continue
    b, rd, mode, victim, rep, K, rem, rc, n, miss, dup, fr, order = p[:13]
    msg = p[13] if len(p) > 13 else ""
    rows[(rd, mode, victim)].append((b, int(rep), rc, int(n), int(miss), int(dup), int(fr), order, msg))


def agg(rs):
    rcs = collections.Counter(r[2] for r in rs)
    return (",".join(f"{k}x{v}" for k, v in sorted(rcs.items())), sum(r[4] for r in rs), sum(r[5] for r in rs),
            sum(r[3] for r in rs) / max(len(rs), 1), sum(r[6] for r in rs) / max(len(rs), 1),
            sum(1 for r in rs if r[7] != "ordered"), len({r[8][:60] for r in rs if r[8]}))


print(f"{'reader':10} {'mode':9} {'victim':8} | {'stock exit':14} {'miss':>5} {'dup':>4} {'entries':>8} {'fromRem':>8} {'unord':>5} | {'patched exit':14} {'miss':>5} {'dup':>4} {'entries':>8} {'fromRem':>8} {'unord':>5} | diff?")
for (rd, mode, victim), rs in sorted(rows.items()):
    s = agg([r for r in rs if r[0] == "s819"])
    p = agg([r for r in rs if r[0] == "p820"])
    flag = "" if s[:3] == p[:3] and abs(s[3] - p[3]) < 1 and abs(s[4] - p[4]) < 1 and s[5] == p[5] else "  <-- DIFFERENT"
    print(f"{rd:10} {mode:9} {victim:8} | {s[0]:14} {s[1]:5d} {s[2]:4d} {s[3]:8.0f} {s[4]:8.0f} {s[5]:5d} | {p[0]:14} {p[1]:5d} {p[2]:4d} {p[3]:8.0f} {p[4]:8.0f} {p[5]:5d} |{flag}")
