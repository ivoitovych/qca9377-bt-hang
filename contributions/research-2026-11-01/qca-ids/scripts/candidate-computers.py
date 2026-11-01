#!/usr/bin/python3 -I
"""Per candidate USB ID: number of linuxhw probes, distinct computers (the
hashed computer id in the probe path), distinct models, and the newest kernel
seen, from the LsUSB tree.

Usage: candidate-computers.py <LsUSB> <out.tsv> <vid:pid> [...]
"""
import collections
import os
import re
import subprocess
import sys

LSUSB, OUT, IDS = sys.argv[1], sys.argv[2], sys.argv[3:]
args = ["grep", "-r", "-o", "-F"]
for cid in IDS:
    args += ["-e", f"ID {cid} "]
r = subprocess.run(args + [LSUSB], capture_output=True, text=True, errors="replace")
by_id = collections.defaultdict(set)
for line in r.stdout.splitlines():
    path, _, match = line.rpartition(":ID ")
    by_id[match.strip()].add(path)
with open(OUT, "w") as f:
    f.write("id\tprobes\tcomputers\tmodels\ttypes\tnewest_kernel\tmodels_list\n")
    for cid in IDS:
        paths = [os.path.relpath(p, LSUSB).split("/") for p in sorted(by_id[cid])]
        comps = {p[4] for p in paths if len(p) > 5}
        models = collections.Counter(" / ".join(p[1:4]) for p in paths)
        types = collections.Counter(p[0] for p in paths)
        kv = [tuple(int(x) for x in m.groups()) for p in paths
              for m in [re.match(r"(\d+)\.(\d+)\.(\d+)", p[6] if len(p) > 6 else "")] if m]
        newest = ".".join(map(str, max(kv))) if kv else "?"
        f.write("\t".join([cid, str(len(paths)), str(len(comps)), str(len(models)),
                           "; ".join(f"{k} {v}" for k, v in types.most_common()), newest,
                           "; ".join(m for m, _ in models.most_common())]) + "\n")
        print(cid, len(paths), len(comps), file=sys.stderr)
