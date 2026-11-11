#!/usr/bin/env python3
"""u14.py: classify WirePlumber's automatic a2dp -> headset profile switches by the recorder stream created just before.
A switch is 'Chrome' when a 'Google Chrome input' CREATE_RECORD_STREAM was logged in the 3 s before it, 'Settings' for GNOME Settings, else 'none seen'."""
import glob
import re
from collections import Counter, defaultdict
from datetime import datetime

sw, cr = [], []
for p in glob.glob("/root/exp/agent-work/laptop-evidence-mining-20261111/ext/*.tsv"):
    for line in open(p, errors="replace"):
        if "Setting profile of" in line and "from: a2dp-sink to: headset" in line:
            f = line.rstrip("\n").split("\t", 6)
            sw.append((int(f[0]), re.search(r"profile of '([^']+)'", f[6]).group(1)))
        elif "CREATE_RECORD_STREAM" in line:
            f = line.rstrip("\n").split("\t", 6)
            c = re.search(r"\[([^\]]+)\]", f[6])
            cr.append((int(f[0]), c.group(1) if c else "?"))
sw.sort()
cr.sort()
res = defaultdict(Counter)
detail = []
for t, n in sw:
    cl = {c for t2, c in cr if -500_000 <= t - t2 <= 3_000_000}
    k = "+".join(sorted(cl)) if cl else "none seen"
    d = datetime.fromtimestamp(t / 1e6).strftime("%m-%d")
    res[d][k] += 1
    detail.append((t, n, k))
for d in sorted(res):
    print(d, dict(res[d]))
print("total", len(sw))
