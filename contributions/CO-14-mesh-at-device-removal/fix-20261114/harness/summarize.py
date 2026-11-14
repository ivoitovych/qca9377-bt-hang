#!/usr/bin/env python3
"""summarize.py <summary file>...: per kernel tag, boots and the sums of the RESULT fields of the
mesh-removal runs (sends, complete, never completed, kmemleak mesh objects, sockets, lockdep cycles)."""
import re
import sys

KEYS = ("sends", "complete_before", "complete_after", "never_completed", "kmemleak_mesh", "kmemleak_sock",
        "lockdep_circular", "other_kernel_reports")


def main():
    agg = {}
    for path in sys.argv[1:]:
        for line in open(path):
            if line.startswith("batch:") or "RESULT" not in line:
                continue
            tag = line.split()[0]
            d = dict(re.findall(r"(\w+)=([^\s]+)", line.split("RESULT", 1)[1]))
            a = agg.setdefault(tag, {"boots": 0, "pass": 0, "boots_leak": 0, "boots_circ": 0,
                                     "max_close_s": 0.0, **{k: 0 for k in KEYS}})
            a["boots"] += 1
            a["pass"] += 1 if " PASS " in line else 0
            for k in KEYS:
                a[k] += int(d.get(k, 0))
            if int(d.get("kmemleak_mesh", 0)) or int(d.get("kmemleak_sock", 0)):
                a["boots_leak"] += 1
            if int(d.get("lockdep_circular", 0)):
                a["boots_circ"] += 1
            a["max_close_s"] = max(a["max_close_s"], float(d.get("close_max_s", 0)))
    for tag, a in agg.items():
        print("%-8s boots %d, verdict PASS %d, boots with a kmemleak mesh/socket object %d, boots with a lockdep "
              "cycle %d | sends %d, completed %d (before the removal) + %d (during it), never completed %d, "
              "kmemleak mesh objects %d, sockets %d, lockdep cycles %d, other kernel reports %d, longest close() %.6f s" %
              (tag, a["boots"], a["pass"], a["boots_leak"], a["boots_circ"], a["sends"], a["complete_before"],
               a["complete_after"], a["never_completed"], a["kmemleak_mesh"], a["kmemleak_sock"],
               a["lockdep_circular"], a["other_kernel_reports"], a["max_close_s"]))


if __name__ == "__main__":
    main()
