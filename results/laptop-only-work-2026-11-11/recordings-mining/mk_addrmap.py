#!/usr/bin/env python3
"""mk_addrmap.py <outfile>: scan ext/*.tsv for WirePlumber 'Name (ADDR): connected' lines and write a PRIVATE address -> name table
(deleted at the end of the work; never quoted)."""
import glob
import re
import sys

rx = re.compile(r"([A-Za-z0-9][A-Za-z0-9 ._-]*?) \(([0-9A-F]{2}(?::[0-9A-F]{2}){5})\): (?:dis)?connected")
m = {}
for p in glob.glob("/root/exp/agent-work/laptop-evidence-mining-20261111/ext/*.tsv"):
    for line in open(p, errors="replace"):
        if "): " not in line:
            continue
        r = rx.search(line)
        if r:
            name = r.group(1).split(", ")[-1].strip()
            m[r.group(2)] = name
with open(sys.argv[1], "w") as o:
    for a, n in sorted(m.items()):
        o.write(f"{a}\t{n}\n")
print(len(m), "addresses,", len(set(m.values())), "names:", sorted(set(m.values())))
