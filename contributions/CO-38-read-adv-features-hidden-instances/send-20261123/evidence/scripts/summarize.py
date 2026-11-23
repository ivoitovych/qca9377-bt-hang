#!/usr/bin/env python3
"""summarize.py <runs-dir>: one line per log (totals, the new cases' verdicts, kernel reports), then the
cases whose verdict differs between base and patched for each line and tester."""
import os
import re
import sys

d = sys.argv[1]
ansi = re.compile(r"\x1b\[[0-9;]*m")
verdict = re.compile(r"^(.+?)\s+(Passed|Failed|Not Run|Timed out)\s+[\d.]+ seconds")
rep = re.compile(r"(BUG:|WARNING:|KASAN|possible circular locking|INFO: task .* blocked|Kernel panic|general protection)")
cases = {}
for f in sorted(os.listdir(d)):
    if not f.endswith(".log"):
        continue
    txt = ansi.sub("", open(os.path.join(d, f), errors="replace").read()).replace("\r", "")
    tline = re.findall(r"^Total: .*$", txt, re.M)
    tot = {k: v for k, v in re.findall(r"(Total|Passed|Failed|Not Run|Timed out): (\d+)", tline[-1])} if tline else {}
    ex = re.findall(r"^exit=(\d+)", txt, re.M)
    v = {}
    for line in txt.split("\n"):
        m = verdict.match(line.strip())
        if m:
            v[m.group(1).strip()] = m.group(2)
    reps = sorted(set(m.group(1) for m in rep.finditer(txt)))
    cases[f] = v
    print(f"{f}: exit={ex[-1] if ex else '?'} " + " ".join(f"{k}={tot[k]}" for k in tot) +
          (f" reports={reps}" if reps else ""))
print()
for f in sorted(cases):
    if "-base-" not in f:
        continue
    g = f.replace("-base-", "-patched-")
    if g not in cases:
        continue
    diff = [(c, cases[f].get(c), cases[g].get(c)) for c in sorted(set(cases[f]) | set(cases[g]))
            if cases[f].get(c) != cases[g].get(c)]
    print(f"{f} -> {g}: {len(diff)} changed")
    for c, a, b in diff:
        print(f"    {c}: {a} -> {b}")
