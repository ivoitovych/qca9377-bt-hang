#!/usr/bin/env python3
"""inventory.py: per headset name (no addresses): connects seen by WirePlumber, A2DP sink 'connected' transitions, A2DP codec endpoints
(SetConfiguration within 10 s before the connect), first/last day. Reads ext/*.tsv and the private address map."""
import glob
import re
from collections import Counter, defaultdict
from datetime import datetime

amap = {}
for ln in open("/root/exp/agent-work/laptop-evidence-mining-20261111/addrmap.private"):
    a, n = ln.rstrip("\n").split("\t")
    amap[a] = n
ev = []
for p in glob.glob("/root/exp/agent-work/laptop-evidence-mining-20261111/ext/*.tsv"):
    for line in open(p, errors="replace"):
        f = line.rstrip("\n").split("\t", 6)
        if len(f) < 7:
            continue
        m = f[6]
        if ("): connected" in m and f[1] == "wireplumber") or "profile a2dp-sink state changed" in m or "SetConfiguration: name" in m or "profile hfp-hf state changed" in m or "profile hsp-hs state changed" in m:
            ev.append((int(f[0]), f[1], m))
ev.sort()
rx_conn = re.compile(r"([A-Za-z0-9][A-Za-z0-9 ._-]*?) \(([0-9A-F:]{17})\): connected")
rx_a2 = re.compile(r"device ([0-9A-F:]{17}) profile a2dp-sink state changed: (\w+) -> connected")
rx_hf = re.compile(r"device ([0-9A-F:]{17}) profile (hfp-hf|hsp-hs) state changed: (\w+) -> connected")
rx_cfg = re.compile(r"A2DPSource/(\w+)")
connects = Counter()
last_wp = {}
a2 = Counter()
hf = Counter()
codecs = defaultdict(Counter)
days = defaultdict(set)
lastcfg = None
for t, ident, m in ev:
    if "SetConfiguration" in m:
        c = rx_cfg.search(m)
        lastcfg = (t, c.group(1) if c else "?")
        continue
    r = rx_conn.search(m)
    if r:
        n = r.group(1).split(", ")[-1].strip()
        if t - last_wp.get(n, 0) > 2_000_000:
            connects[n] += 1
            days[n].add(datetime.fromtimestamp(t / 1e6).strftime("%m-%d"))
        last_wp[n] = t
        continue
    r = rx_a2.search(m)
    if r:
        n = amap.get(r.group(1), "?")
        a2[n] += 1
        if lastcfg and t - lastcfg[0] < 10_000_000:
            codecs[n][lastcfg[1]] += 1
        else:
            codecs[n]["(no SetConfiguration within 10 s)"] += 1
        continue
    r = rx_hf.search(m)
    if r:
        hf[amap.get(r.group(1), "?")] += 1
for n in sorted(set(connects) | set(a2)):
    ds = sorted(days[n])
    print(f"{n}: WP connected {connects[n]}  a2dp-sink connected {a2[n]}  hfp/hsp profile connected {hf[n]}  days {ds[0] if ds else '-'}..{ds[-1] if ds else '-'} ({len(ds)} days)  a2dp codecs {dict(codecs[n])}")
