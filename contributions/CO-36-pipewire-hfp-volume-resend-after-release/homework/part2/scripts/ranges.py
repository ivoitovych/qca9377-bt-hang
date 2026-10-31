#!/usr/bin/env python3
"""
Per test name: number of single-link records, how many ended before
1.5 s, how many of those had a late +VGM, the range of link ends (ms) and
of the late frames' times (ms from acquire complete); and, for each late
pair, the time from the link's end to the late +VGM.

Usage: python3 -I ranges.py <results.jsonl>...
"""
import json
import sys
from collections import defaultdict

recs = defaultdict(list)
for path in sys.argv[1:]:
    for line in open(path):
        e = json.loads(line)
        if e["test"] == "ledger":
            continue
        if "down_ms" in e:
            recs[e["test"]].append(e)
        for key in ("first", "second"):
            if key in e and "down_ms" in e[key]:
                recs[f"{e['test']}:{key}"].append(e[key])
        for i, link in enumerate(e.get("links") or []):
            recs[f"{e['test']}:links"].append(link)

for name in sorted(recs):
    rs = recs[name]
    short = [r for r in rs if r["down_ms"] is not None and r["down_ms"] < 1500
             and (r.get("next_up_ms") is None or r["next_up_ms"] >= 1500)]
    leak = [r for r in short if any(f["frame"] == "VGM" for f in r["after_down"])]
    downs = [r["down_ms"] for r in rs if r["down_ms"] is not None]
    late = [f["ms"] for r in leak for f in r["after_down"] if f["frame"] == "VGM"]
    gaps = [round(min(f["ms"] for f in r["after_down"] if f["frame"] == "VGM") - r["down_ms"], 1) for r in leak]
    print(f"{name}: n={len(rs)} short={len(short)} leak={len(leak)} "
          f"down=[{min(downs) if downs else None}..{max(downs) if downs else None}] "
          f"lateVGM=[{min(late) if late else None}..{max(late) if late else None}] "
          f"end_to_late=[{min(gaps) if gaps else None}..{max(gaps) if gaps else None}]")
