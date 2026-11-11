#!/usr/bin/env python3
"""patterns.py: group the extracted journal lines by normalised message.
Usage: patterns.py <extdir> <out.tsv> [since YYYY-MM-DD]
Keeps lines with priority <= 4 or whose message matches an error keyword.
Output: count, first, last, boots, prio_min, ident, normalised message, one example (addresses removed).
"""
import glob
import re
import sys
from datetime import datetime

ext, out = sys.argv[1], sys.argv[2]
since = datetime.strptime(sys.argv[3], "%Y-%m-%d").timestamp() * 1e6 if len(sys.argv) > 3 else 0
KW = re.compile(r"critical|assert|segfault|abort|fail|error|warn|refus|timeout|timed out|unexpected|invalid|unable|cannot|can't|denied|corrupt|leak|overflow|Call Trace|fault|not found|reject|unknown|lost|dropped|stuck|busy|\bBUG\b|\bE\b.*pw|crash|core", re.I)
MAC = re.compile(r"\b[0-9A-Fa-f]{2}(?:[:_][0-9A-Fa-f]{2}){5}\b")
NUM = re.compile(r"\b0x[0-9a-fA-F]+\b|\b\d+(?:\.\d+)?\b")
HEXLONG = re.compile(r"\b[0-9a-f]{8,}\b")
PTR = re.compile(r"\b0x[0-9a-f]{6,}\b")


DEV = re.compile(r"(dev|bluez_card|bluez_input|bluez_output)[._]([0-9A-Fa-f]{2}[_.:]){5}[0-9A-Fa-f]{2}")
LOW = re.compile(r"critical|assert|segfault|abort|fail|error|warn|denied|invalid|unable|cannot|can't|corrupt|leak|overflow|timeout|timed out|unexpected|Call Trace|\bBUG\b|crash", re.I)


def clean(m):
    return DEV.sub(r"\1_<MAC>", MAC.sub("<MAC>", m))


def norm(m):
    m = clean(m)
    m = PTR.sub("<PTR>", m)
    m = HEXLONG.sub("<HEX>", m)
    m = NUM.sub("N", m)
    return m[:300]


groups = {}
for path in sorted(glob.glob(ext + "/*.tsv")):
    boot = path.rsplit("-", 1)[1].split(".")[0]
    with open(path, errors="replace") as f:
        for line in f:
            p = line.rstrip("\n").split("\t", 6)
            if len(p) < 7:
                continue
            ts, ident, pid, prio, uid, unit, msg = p
            try:
                t = int(ts)
            except ValueError:
                continue
            if t < since:
                continue
            pr = int(prio) if prio.isdigit() else 6
            if not (pr <= 4 or (pr <= 5 and KW.search(msg)) or (pr >= 6 and LOW.search(msg))):
                continue
            if "test-spa" in ident or "cdsim" in msg or "btmon-stock" in msg or "btmon-archive" in msg or "btmon-fix1" in msg:
                continue
            k = (ident, norm(msg))
            g = groups.get(k)
            if g is None:
                groups[k] = [1, t, t, {boot}, pr, clean(msg)[:300]]
            else:
                g[0] += 1
                g[1] = min(g[1], t)
                g[2] = max(g[2], t)
                g[3].add(boot)
                g[4] = min(g[4], pr)

fmt = lambda t: datetime.fromtimestamp(t / 1e6).strftime("%Y-%m-%d %H:%M:%S")
with open(out, "w") as o:
    for (ident, nm), g in sorted(groups.items(), key=lambda kv: (kv[0][0], -kv[1][0])):
        o.write("\t".join([str(g[0]), fmt(g[1]), fmt(g[2]), str(len(g[3])), str(g[4]), ident, g[5]]) + "\n")
print(len(groups), "groups")
