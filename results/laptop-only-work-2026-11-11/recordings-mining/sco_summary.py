#!/usr/bin/env python3
"""sco_summary.py <scoDir>... : join links.tsv, names.tsv and perlink_sec.tsv per run directory.
Prints one row per link: setup, headset name, air, held s, close, rx/tx frame totals, crc ok %, signal-frame %, mean max scale factor,
and for CVSD the non-idle byte % and 3-bit-run rate."""
import sys
from collections import defaultdict

print("setup\theadset\tair\theld_s\tclose\trx_frames\trx_crc%\trx_sig%\trx_maxsf\ttx_frames\ttx_sig%\ttx_maxsf\trx_nonidle%\trx_runs/s\ttx_nonidle%")
for d in sys.argv[1:]:
    names = {}
    for line in open(d + "/names.tsv"):
        k, v = line.rstrip("\n").split("\t")
        names[k] = v
    agg = defaultdict(lambda: defaultdict(float))
    for line in list(open(d + "/perlink_sec.tsv"))[1:]:
        p = line.rstrip("\n").split("\t")
        lid, dr = p[0], p[1]
        a = agg[(lid, dr)]
        a["pk"] += int(p[3])
        a["bytes"] += int(p[4])
        a["fr"] += int(p[5])
        a["ok"] += int(p[6])
        a["sig"] += int(p[7])
        a["maxsf"] += float(p[8]) * int(p[5])
        a["nonidle"] += int(p[9])
        a["runs"] += int(p[10])
        a["secs"] += 1
    for line in list(open(d + "/links.tsv"))[1:]:
        p = line.rstrip("\n").split("\t")
        lid = p[0]
        if lid == "-":
            print(f"{p[2]}\t{names.get(p[3], '?')}\t{p[6]}\t-\t{p[7]}")
            continue
        rx, tx = agg[(lid, "rx")], agg[(lid, "tx")]
        f = lambda a, k: (100.0 * a[k] / a["fr"]) if a["fr"] else 0.0
        mf = lambda a: (a["maxsf"] / a["fr"]) if a["fr"] else 0.0
        nb = lambda a: (100.0 * a["nonidle"] / a["bytes"]) if a["bytes"] else 0.0
        print("\t".join([p[2][:19], names.get(p[3], "?"), "mSBC" if p[6] == "3" else ("CVSD" if p[6] == "2" else p[6]), p[9][:7], p[7] + ":" + p[8],
                         "%d" % rx["fr"], "%.0f" % f(rx, "ok"), "%.1f" % f(rx, "sig"), "%.2f" % mf(rx),
                         "%d" % tx["fr"], "%.1f" % f(tx, "sig"), "%.2f" % mf(tx),
                         "%.1f" % nb(rx), "%.1f" % (rx["runs"] / max(rx["secs"], 1)), "%.1f" % nb(tx)]))
