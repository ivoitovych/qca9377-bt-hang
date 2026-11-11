#!/usr/bin/env python3
"""vgm_timeline.py: per day and headset name, the +VGM values the laptop sent ('RFCOMM >> +VGM: n') and the AT+VGM values the headset
reported ('RFCOMM << AT+VGM=nn'), attributed to the last HFPAG NewConnection (device path -> name via the private address map).
Output has names only."""
import glob
import re
from collections import defaultdict
from datetime import datetime

amap = {}
for ln in open("/root/exp/agent-work/laptop-evidence-mining-20261111/addrmap.private"):
    a, n = ln.rstrip("\n").split("\t")
    amap[a.replace(":", "_")] = n
ev = []
for p in glob.glob("/root/exp/agent-work/laptop-evidence-mining-20261111/ext/*.tsv"):
    for line in open(p, errors="replace"):
        if "RFCOMM" in line or "HFPAG" in line:
            f = line.rstrip("\n").split("\t", 6)
            if len(f) == 7 and f[1] == "wireplumber":
                ev.append((int(f[0]), f[6]))
ev.sort()
conn = re.compile(r"NewConnection path=/org/bluez/hci0/dev_([0-9A-F_]+), .*HFPAG")
sent = re.compile(r"RFCOMM >> \+VG([MS]): (\d+)")
rep = re.compile(r"RFCOMM << AT\+VG([MS])=(\d+)")
cur = "?"
agg = defaultdict(lambda: defaultdict(int))
for t, m in ev:
    c = conn.search(m)
    if c:
        cur = amap.get(c.group(1), "unknown")
        continue
    day = datetime.fromtimestamp(t / 1e6).strftime("%m-%d")
    s = sent.search(m)
    if s:
        agg[(day, cur)][f"sent+VG{s.group(1)}={s.group(2)}"] += 1
    r = rep.search(m)
    if r:
        agg[(day, cur)][f"rep AT+VG{r.group(1)}={int(r.group(2))}"] += 1
for (day, name), c in sorted(agg.items()):
    print(day, name, " ".join(f"{k}x{v}" for k, v in sorted(c.items())))
