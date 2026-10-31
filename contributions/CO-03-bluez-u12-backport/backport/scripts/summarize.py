#!/usr/bin/env python3
"""Summarise CO-03 results.jsonl files: one row per (test, variant) with
the number of runs, invariant failures and key measurements.

Usage: summarize.py <results.jsonl>...
"""
import json
import sys
from collections import OrderedDict, defaultdict


def verdict_u12(e):
    """The U12 invariants of u12_case (I1 I2 I3 I4 I8)"""
    bad = []
    if e.get("lost_ms") is not None or not e.get("transport_alive", True):
        bad.append("I1")
    if not e.get("probe", {}).get("flowed"):
        bad.append("I2")
    if e.get("acquire", {}).get("reply") in ("none", "ok"):
        bad.append("I3")
    if e.get("abort_sent"):
        bad.append("I4")
    if e.get("sanitizer"):
        bad.append("I8")
    return bad


rows = defaultdict(list)
order = OrderedDict()
for path in sys.argv[1:]:
    with open(path) as f:
        for line in f:
            e = json.loads(line)
            key = (e["test"], e.get("variant", ""), e.get("mode", ""))
            rows[key].append(e)
            order[key] = None

print("| test | build | remote | runs | Acquire reply | Release reply | ABORT sent | A2DP lost (ms after Acquire) | later Acquire + media | sanitizer |")
print("|---|---|---|---|---|---|---|---|---|---|")
for key in order:
    test, variant, mode = key
    es = rows[key]
    n = len(es)

    def col(get):
        vals = defaultdict(int)
        for e in es:
            try:
                v = get(e)
            except Exception:
                v = "-"
            vals[str(v)] += 1
        return ", ".join(f"{k} ×{c}" if n > 1 else k for k, c in vals.items())

    acq = col(lambda e: e["acquire"]["reply"] if "acquire" in e else e["ops"][0]["reply"])
    rel = col(lambda e: e["release"]["reply"] if "release" in e else e["ops"][1]["reply"])
    abort = col(lambda e: e.get("abort_sent", "-"))
    lost = [e.get("lost_ms") for e in es]
    lost_n = sum(1 for x in lost if x is not None)
    lost_vals = sorted(x for x in lost if x is not None)
    lost_s = f"{lost_n}/{n}" + (f" ({lost_vals[0]}–{lost_vals[-1]})" if lost_vals else "")
    flowed = sum(1 for e in es if (e.get("probe") or e.get("after") or {}).get("flowed")
                 or e.get("audio"))
    san = sum(1 for e in es if e.get("sanitizer"))
    print(f"| {test} | {variant} | {mode} | {n} | {acq} | {rel} | {abort} | {lost_s} | {flowed}/{n} | {san} |")
