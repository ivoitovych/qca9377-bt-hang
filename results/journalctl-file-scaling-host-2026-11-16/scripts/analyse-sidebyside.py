#!/usr/bin/env python3
"""analyse-sidebyside.py CONTAINER_SYNTH CONTAINER_REAL HOST_TSV HOST_ALL_TSV
Median lines/s per (what, env, variant, K), the speed-up b over a in each environment, and the host/container ratio.
Container files: variant, K, run, lines, seconds (K may be like 'all(481)'). Host files: env, variant, what, K, run, lines, seconds, io.
In the host files K = the file count at the time; rows of K above 400 are the 'all' run."""
import re
import statistics
import sys
from collections import defaultdict

R = defaultdict(list)   # (what, env, variant, kkey) -> rates
IO = defaultdict(list)


def add(what, env, v, k, n, s, io=None):
    if int(n) > 0 and float(s) > 0:
        R[(what, env, v, k)].append(int(n) / float(s))
        if io is not None:
            IO[(what, env, v, k)].append(int(io))


def kkey(k):
    m = re.search(r"\((\d+)\)", k)
    k = int(m.group(1)) if m else int(k)
    return "all" if k > 400 and k < 1000 and False else k


for path, what in ((sys.argv[1], "synthetic"), (sys.argv[2], "real")):
    for line in open(path):
        p = line.rstrip("\n").split("\t")
        if len(p) == 5:
            add(what, "container", p[0], ("all" if p[1].startswith("all") else int(p[1].split("(")[0])), p[3], p[4])
for path in sys.argv[3:5]:
    for line in open(path):
        p = line.rstrip("\n").split("\t")
        if len(p) != 8:
            continue
        env, v, what, k, r, n, s, io = p
        what = "synthetic" if what == "synth" else "real"
        k = int(k)
        add(what, "host", v, "all" if (what == "real" and k > 400) else k, n, s, io)

for what in ("synthetic", "real"):
    ks = [25, 50, 100, 200, 400] + ([800] if what == "synthetic" else ["all"])
    print(f"\n== {what}: lines/s, median of runs")
    print(f"{'env':10} {'var':4} " + " ".join(f"{str(k):>9}" for k in ks))
    for env in ("host", "container"):
        for v in "abg":
            cells = []
            for k in ks:
                r = R.get((what, env, v, k))
                cells.append(f"{statistics.median(r):9.0f}" if r else f"{'-':>9}")
            print(f"{env:10} {v:4} " + " ".join(cells))
    for env in ("host", "container"):
        cells = []
        for k in ks:
            a, b = R.get((what, env, "a", k)), R.get((what, env, "b", k))
            cells.append(f"{statistics.median(b) / statistics.median(a):9.1f}" if a and b else f"{'-':>9}")
        print(f"{env:10} {'b/a':4} " + " ".join(cells))
    cells = []
    for k in ks:
        h, c = R.get((what, "host", "a", k)), R.get((what, "container", "a", k))
        cells.append(f"{statistics.median(h) / statistics.median(c):9.2f}" if h and c else f"{'-':>9}")
    print(f"{'host/cont':10} {'a':4} " + " ".join(cells))
    cells = []
    for k in ks:
        h, c = R.get((what, "host", "b", k)), R.get((what, "container", "b", k))
        cells.append(f"{statistics.median(h) / statistics.median(c):9.2f}" if h and c else f"{'-':>9}")
    print(f"{'host/cont':10} {'b':4} " + " ".join(cells))
print("\nhost IO pressure (some, total stall microseconds during the run; whole system, so noisy): median per cell")
for what in ("synthetic", "real"):
    for v in "abg":
        cells = []
        for k in [25, 50, 100, 200, 400, 800 if what == "synthetic" else "all"]:
            x = IO.get((what, "host", v, k))
            cells.append(f"{statistics.median(x):9.0f}" if x else f"{'-':>9}")
        print(f"{what:10} {v:4} " + " ".join(cells))
