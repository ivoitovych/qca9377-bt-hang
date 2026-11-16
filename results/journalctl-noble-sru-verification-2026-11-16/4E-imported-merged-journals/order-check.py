#!/usr/bin/env python3
"""order-check.py OUTPUT TRUE_ORDER : compare a journalctl '-o cat' output (one MESSAGE per line) with the true order.
Prints: number of entries, whether all expected messages appear exactly once, whether the sequence equals the true order,
the number of adjacent inversions (a message that comes before one that is earlier in true order) and the longest displacement."""
import sys

out = [l.rstrip("\n") for l in open(sys.argv[1]) if l.strip()]
true = [l.rstrip("\n") for l in open(sys.argv[2]) if l.strip()]
rank = {m: i for i, m in enumerate(true)}
complete = sorted(out) == sorted(true)
seq = [rank.get(m, -1) for m in out]
inv = sum(1 for a, b in zip(seq, seq[1:]) if a > b)
disp = max((abs(i - r) for i, r in enumerate(seq) if r >= 0), default=0)
print(f"entries {len(out)} of {len(true)}; each exactly once: {complete}; equals true order: {out == true}; "
      f"adjacent inversions {inv}; longest displacement {disp}")
