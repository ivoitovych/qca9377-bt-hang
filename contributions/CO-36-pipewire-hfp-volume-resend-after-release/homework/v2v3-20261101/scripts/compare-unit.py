"""Compare L1 outcome lines across runs and variants.

Usage: python3 -I compare-unit.py <output file> <log>...
Each log name is unit-<variant>-run<n>.log or extras-<variant>-run<n>.log.
Writes (and prints): per variant, whether all its runs give byte-identical
test lines; then per test the verdict per variant, whether V2's and V3's
lines are byte-identical to V0's (unchanged outcome) and to each other.
"""
import re
import sys
from pathlib import Path

out_path = sys.argv[1]
runs = {}
for p in sys.argv[2:]:
    m = re.match(r"(unit|extras)-(v\d)-run(\d+)\.log", Path(p).name)
    lines = {}
    for line in Path(p).read_text(errors="replace").splitlines():
        t = re.match(r"(T\d+[a-z]?|X\d+[a-z]?) (PASS|FAIL)( .*)?$", line)
        if t:
            lines[t.group(1)] = line
    runs.setdefault(m.group(2), []).append((p, lines))

out = []
out.append("# inputs: " + " ".join(sys.argv[2:]))
out.append("# determinism: every run of a variant gives identical test lines")
for v, rs in sorted(runs.items()):
    ref = rs[0][1]
    same = all(r[1] == ref for r in rs[1:])
    out.append(f"{v}: {len(rs)} runs, {len(ref)} tests, identical across runs: {same}")

out.append("# per test: verdict per variant; line equal to V0's; V2 line == V3 line")
variants = sorted(runs)
first = {v: runs[v][0][1] for v in variants}
for tid in first[variants[0]]:
    cells = []
    for v in variants:
        line = first[v].get(tid, "")
        cells.append(f"{v}={line.split(' ')[1] if line else 'missing'}")
    v0 = first.get("v0", {}).get(tid)
    v2 = first.get("v2", {}).get(tid)
    v3 = first.get("v3", {}).get(tid)
    out.append(f"{tid} {' '.join(cells)} v2==v0:{v2 == v0} v3==v0:{v3 == v0} v2==v3:{v2 == v3}")

Path(out_path).write_text("\n".join(out) + "\n")
print("\n".join(out))
