#!/usr/bin/env python3
"""links_analysis.py <dir>...: combine links.tsv of several scan directories. Prints totals per headset and codec,
concurrent-link overlaps, unknown-handle SCO data counts, and links per outcome."""
import sys
from collections import Counter, defaultdict
from datetime import datetime

rows = []
unk = Counter()
unkfiles = Counter()
for d in sys.argv[1:]:
    names = dict(l.rstrip("\n").split("\t") for l in open(d + "/names.tsv"))
    for l in list(open(d + "/links.tsv"))[1:]:
        p = l.rstrip("\n").split("\t")
        t0 = datetime.strptime(p[2], "%Y-%m-%d %H:%M:%S.%f")
        held = float(p[9]) if p[9] != "-" else None
        rows.append(dict(t0=t0, name=names.get(p[3], "?"), air=p[6], out=p[7], held=held, dc=p[8], by=p[10], file=p[1], rx=int(p[11]), tx=int(p[12]), rrx=int(p[16]) if len(p) > 16 else 0, rtx=int(p[17]) if len(p) > 17 else 0, rlast=float(p[18]) if len(p) > 18 else 0.0))
    try:
        for l in list(open(d + "/unknown_data.tsv"))[1:]:
            p = l.rstrip("\n").split("\t")
            unk[p[0]] += int(p[2])
            unkfiles[p[0]] += 1
    except OSError:
        pass
rows.sort(key=lambda r: r["t0"])
print("links total", len(rows))
c = Counter((r["name"], {"3": "mSBC", "2": "CVSD"}.get(r["air"], r["air"]), r["out"].split(":")[0] if not r["out"].startswith("failed") else r["out"]) for r in rows)
for k, v in sorted(c.items()):
    print(" ", k, v)
# overlaps
from datetime import timedelta
ov = []
iv = [(r["t0"], r["t0"] + timedelta(seconds=r["held"]), r) for r in rows if r["held"] is not None and r["out"].startswith("closed")]
for i in range(len(iv)):
    for j in range(i + 1, len(iv)):
        if iv[j][0] >= iv[i][1]:
            break
        ov.append((iv[i], iv[j]))
print("overlapping closed-link pairs:", len(ov))
for a, b in ov:
    print("  ", a[0], a[2]["name"], "and", b[0], b[2]["name"])
print("sco data packets for a handle that was not open (after DC), by direction:", dict(unk), "in files:", dict(unkfiles))
print("non-closed outcomes:")
for r in rows:
    if not r["out"].startswith("closed"):
        print("  ", r["t0"], r["name"], r["out"], r["held"])
cl = [r for r in rows if r["out"].startswith("closed")]
withres = [r for r in cl if r["rrx"] or r["rtx"]]
print("closed links with SCO data for the handle after the Disconnection Complete (within 3 s):", len(withres), "of", len(cl))
print("  residue rx packets total", sum(r["rrx"] for r in cl), " tx total", sum(r["rtx"] for r in cl), " max rx per link", max([r["rrx"] for r in cl] or [0]), " longest after DC ms", max([r["rlast"] for r in cl] or [0]))
byc = Counter()
for r in cl:
    byc[(r["name"], r["air"], bool(r["rrx"] or r["rtx"]))] += 1
print("  by headset/air/has-residue:", dict(byc))
print("close by:", Counter(r["by"] for r in rows if r["out"].startswith("closed")))
print("dc status/reason:", Counter(r["dc"] for r in rows if r["out"].startswith("closed")))
