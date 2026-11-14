import csv, collections, sys
for s in sys.argv[1:]:
    D = "/root/exp/agent-work/lane5-status-stable-20261114/task4/work/results/%s/results.tsv" % s
    rows = list(csv.DictReader(open(D), delimiter="\t"))
    cells = collections.OrderedDict()
    for r in rows:
        cells.setdefault((r["capture"], r["opts"], r["width"]), {})[r["variant"]] = r
    sa = pa = ident = diff = 0; diffs = []
    for k, v in cells.items():
        a, b = v["stock"], v["patched"]
        sa += a["exit"] == "134"; pa += b["exit"] != "0"
        if a["exit"] == "0" and b["exit"] == "0":
            if a["stdout_sha256"] == b["stdout_sha256"]: ident += 1
            else: diff += 1; diffs.append(k)
    print("==", s, "runs", len(rows), "cells", len(cells), "| stock aborts (134):", sa,
          "at widths", sorted({k[2] for k, v in cells.items() if v["stock"]["exit"] == "134"}),
          "| patched non-zero exits:", pa, "| both exit 0: identical", ident, "different", diff)
    for k in diffs:
        print("   differs:", k)
