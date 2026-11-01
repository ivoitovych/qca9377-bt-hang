#!/usr/bin/env python3
"""Per-test outcome counts from pytest -v stdout logs.
Usage: outcomes.py <label>=<stdout log>[,<log>...] ...
Prints a markdown table: test | label1 | label2 ..."""
import re
import sys
from collections import OrderedDict, defaultdict

PAT = re.compile(r"::(test_[A-Za-z0-9_]+)(\[[^\]]*\])? (PASSED|FAILED|ERROR|SKIPPED|XFAIL|XPASS)")

labels = []
counts = defaultdict(lambda: defaultdict(lambda: defaultdict(int)))
order = OrderedDict()
for arg in sys.argv[1:]:
    label, paths = arg.split("=", 1)
    labels.append(label)
    for path in paths.split(","):
        for line in open(path, errors="replace"):
            m = PAT.search(line)
            if m:
                name = m.group(1)
                order[name] = None
                counts[name][label][m.group(3)] += 1


def cell(c):
    if not c:
        return "not run"
    return ", ".join(f"{k.lower()} {v}" for k, v in sorted(c.items()))


print("| test | " + " | ".join(labels) + " |")
print("|---|" + "---|" * len(labels))
for name in sorted(order):
    print(f"| {name} | " + " | ".join(cell(counts[name][l]) for l in labels) + " |")
