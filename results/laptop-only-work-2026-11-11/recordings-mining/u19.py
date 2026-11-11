#!/usr/bin/env python3
"""u19.py: find U19-shaped events: wireplumber 'preventing non-Bluetooth devices from linking' followed within 3 s by a
GNOME Settings CREATE_RECORD_STREAM (tag N) and, within 5 s, an ERROR line for the same tag. Also counts the same for recorders
(other client names) that were killed with an ERROR within 5 s. Prints one line per event."""
import glob
import re
from datetime import datetime

ev = []
for p in glob.glob("/root/exp/agent-work/laptop-evidence-mining-20261111/ext/*.tsv"):
    boot = p.rsplit("-", 1)[1].split(".")[0]
    for line in open(p, errors="replace"):
        if ("preventing non-Bluetooth" in line) or ("CREATE_RECORD_STREAM" in line) or ("ERROR" in line and "tag:" in line):
            f = line.rstrip("\n").split("\t", 6)
            if len(f) == 7:
                ev.append((int(f[0]), boot, f[1], f[6]))
ev.sort()
tagrx = re.compile(r"tag:(\d+)")
clientrx = re.compile(r"\[([^\]]+)\].*CREATE_RECORD_STREAM")
out = []
for i, (t, b, ident, m) in enumerate(ev):
    if "preventing non-Bluetooth" not in m:
        continue
    creates = []
    errs = []
    for t2, b2, i2, m2 in ev[i + 1:i + 400]:
        if t2 - t > 5_000_000:
            break
        if "CREATE_RECORD_STREAM" in m2:
            tg = tagrx.search(m2)
            cl = clientrx.search(m2)
            creates.append((tg.group(1) if tg else "?", cl.group(1) if cl else "?", t2))
        elif "ERROR" in m2:
            tg = tagrx.search(m2)
            if tg:
                errs.append((tg.group(1), t2))
    for tg, cl, t2 in creates:
        if t2 - t <= 3_000_000 and any(e[0] == tg for e in errs):
            out.append((t, b, cl))
print("events:", len(out))
byday = {}
for t, b, cl in out:
    d = datetime.fromtimestamp(t / 1e6).strftime("%Y-%m-%d")
    byday.setdefault((d, cl), []).append(datetime.fromtimestamp(t / 1e6).strftime("%H:%M:%S"))
for (d, cl), ts in sorted(byday.items()):
    print(d, cl, len(ts), " ".join(ts[:12]))
