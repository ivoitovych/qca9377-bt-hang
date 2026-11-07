#!/usr/bin/env python3
"""Per-test outcome counts from pytest -vv stdout logs, side by side.
Usage: l2-outcomes.py <label>=<stdout.log>..."""
import re
import sys
from collections import defaultdict

PAT = re.compile(r"::(test_\w+)\[[^\]]*\] (PASSED|FAILED|ERROR|SKIPPED)")
cols = []
table = defaultdict(dict)
for arg in sys.argv[1:]:
    label, path = arg.split("=", 1)
    cols.append(label)
    for line in open(path, encoding="utf-8", errors="replace"):
        m = PAT.search(line)
        if m:
            d = table[m.group(1)].setdefault(label, defaultdict(int))
            d[m.group(2)] += 1
print("| test | " + " | ".join(cols) + " |")
print("|---|" + "---|" * len(cols))
for t in sorted(table):
    cells = []
    for c in cols:
        d = table[t].get(c)
        cells.append("-" if not d else ", ".join(f"{k} {v}" for k, v in sorted(d.items())))
    print(f"| {t.split('_')[1]} | " + " | ".join(cells) + " |")
