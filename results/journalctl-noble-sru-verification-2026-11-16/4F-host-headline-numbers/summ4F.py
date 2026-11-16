#!/usr/bin/env python3
"""summ4F.py 4F.tsv : markdown table per set: stock and patched wall seconds, speed-up, output size, exit statuses, caps.
Exit status 141 (SIGPIPE) is expected for the sos commands that stop reading at 100 MB (as sos does)."""
import collections
import sys

rows = collections.OrderedDict()
for line in open(sys.argv[1]):
    p = line.rstrip("\n").split("\t")
    if len(p) < 9:
        continue
    st, who, q, rc, wall, user, sys_, n, cap = p[:9]
    rows.setdefault(st, collections.OrderedDict()).setdefault(q, {})[who] = (int(rc), float(wall), float(user) + float(sys_), int(n), int(cap))

for st, qs in rows.items():
    print(f"\n### {st}\n")
    print("| query | stock wall s | patched wall s | speed-up | stock cpu s | patched cpu s | output (lines or bytes) | exit stock / patched | cap hit |")
    print("|---|---|---|---|---|---|---|---|---|")
    for q, d in qs.items():
        s, p = d["stock"], d["patched"]
        sp = f"{s[1] / p[1]:.1f}x" if p[1] >= 0.5 and s[1] >= 0.5 else "-"
        same = "same" if s[3] == p[3] else f"DIFFERENT ({s[3]} / {p[3]})"
        print(f"| {q} | {s[1]:.2f} | {p[1]:.2f} | {sp} | {s[2]:.1f} | {p[2]:.1f} | {p[3]} ({same}) | {s[0]} / {p[0]} | {'YES' if s[4] or p[4] else 'no'} |")
