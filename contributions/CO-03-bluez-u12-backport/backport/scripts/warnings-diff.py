#!/usr/bin/env python3
"""Compiler warnings of two build logs, normalised (file:line:col dropped
to file + message, so that line shifts from the patches do not count as
changes), and the difference.

Usage: warnings-diff.py <log A> <log B>
"""
import re
import sys
from collections import Counter

PAT = re.compile(r"^(?P<file>[^\s:]+\.[ch]):(?P<line>\d+):(?P<col>\d+): warning: (?P<msg>.*)$")


def warnings(path):
    out = Counter()
    raw = []
    for line in open(path, encoding="utf-8", errors="replace"):
        m = PAT.match(line.strip())
        if m:
            f = m.group("file").split("/./")[-1]
            out[(f, m.group("msg"))] += 1
            raw.append(line.strip())
    return out, raw


a, ra = warnings(sys.argv[1])
b, rb = warnings(sys.argv[2])
print(f"A: {sum(a.values())} warnings ({len(a)} distinct) {sys.argv[1]}")
print(f"B: {sum(b.values())} warnings ({len(b)} distinct) {sys.argv[2]}")
only_a = a - b
only_b = b - a
print(f"only in A: {sum(only_a.values())}")
for (f, msg), c in sorted(only_a.items()):
    print(f"  - {f}: {msg} (x{c})")
print(f"only in B: {sum(only_b.values())}")
for (f, msg), c in sorted(only_b.items()):
    print(f"  + {f}: {msg} (x{c})")
touched = ("transport.c", "a2dp.c", "adapter.c")
print("warnings in the touched files (A, then B):")
for r in ra:
    if any(t in r for t in touched):
        print("  A", r)
for r in rb:
    if any(t in r for t in touched):
        print("  B", r)
