#!/usr/bin/env python3
"""noble-md.py TSV : markdown tables of the noble default-impact measurements (median of runs).
Columns of the TSV: set, who, query, run, rc, wall_s, user_s, sys_s, lines_or_bytes, capped."""
import statistics
import sys
from collections import defaultdict

R = defaultdict(list)
sets = []
queries = []
for line in open(sys.argv[1]):
    p = line.rstrip("\n").split("\t")
    if len(p) != 10:
        continue
    s, who, q, run, rc, wall, u, sy, n, cap = p
    if s not in sets:
        sets.append(s)
    if q not in queries:
        queries.append(q)
    R[(s, q, who)].append((float(wall), float(u) + float(sy), int(n), int(cap)))

# the full-read size of each set, from the patched run that finished
total = {}
for s in sets:
    r = R.get((s, "-b all (full read)", "patched"))
    if r:
        total[s] = max(x[2] for x in r)


def fmt(sec):
    if sec >= 3600:
        return f"{sec / 3600:.1f} h"
    if sec >= 120:
        return f"{sec / 60:.1f} min"
    return f"{sec:.2f} s" if sec < 10 else f"{sec:.1f} s"


def cell(s, q, who):
    r = R.get((s, q, who))
    if not r:
        return None
    wall = statistics.median(x[0] for x in r)
    cpu = statistics.median(x[1] for x in r)
    n = max(x[2] for x in r)
    cap = max(x[3] for x in r)
    return wall, cpu, n, cap


names = {
    "list-boots": "`--list-boots`",
    "-u cron.service -n 10": "`-u cron.service -n 10` (what `systemctl status` shows)",
    "-b (newest boot)": "`-b` (the newest boot)",
    "-b -1": "`-b -1`",
    "-k -b all": "`-k -b all`",
    "-b all (full read)": "`-b all` (whole journal)",
    "apport JournalErrors: --priority=warning -b --lines=1000": "apport: `--priority=warning -b --lines=1000`",
    "apport recent_syslog: --quiet -b -a --system": "apport: `--quiet -b -a --system`",
    "sos journalctl --disk-usage": "sos: `--disk-usage`",
    "sos journalctl --list-boots": "sos: `--list-boots`",
    "sos full: --no-pager --reverse (first 100 MB)": "sos: `--no-pager --reverse`, first 100 MB",
    "sos this boot: --no-pager --boot --reverse (first 100 MB)": "sos: `--no-pager --boot --reverse`, first 100 MB",
    "sos last boot: --no-pager --boot -1 --reverse (first 100 MB)": "sos: `--no-pager --boot -1 --reverse`, first 100 MB",
}
for group, qs in (("journalctl queries", queries[:8]), ("tools", queries[8:])):
    pass
for s in sets:
    print(f"\n#### {s}\n")
    print("| query | stock wall | stock CPU | patched wall | patched CPU | speed-up | lines or bytes |")
    print("|---|---|---|---|---|---|---|")
    for q in queries:
        a, b = cell(s, q, "stock"), cell(s, q, "patched")
        if not a or not b:
            continue
        note = ""
        sw = f"{fmt(a[0])}"
        if a[3]:
            note = "capped"
            sw += " (cap)"
            if "full read" in q:
                # projected from the lines it had printed
                if a[2] > 0 and s in total:
                    proj = total[s] / (a[2] / a[0])
                    sw += f", about {fmt(proj)} projected"
                    sp = f"{proj / b[0]:.0f}x projected"
                else:
                    sp = ">%.0fx" % (a[0] / b[0])
            else:
                # sos: bytes printed of the 100 MB limit in the time cap
                sp = f">{a[0] / b[0]:.0f}x (timed out at {a[2] / 1e6:.0f} MB of 105 MB)"
        else:
            sp = f"{a[0] / b[0]:.1f}x" if b[0] >= 0.05 else "-"
        n = b[2]
        unit = "bytes" if q.startswith("sos full") or q.startswith("sos this") or q.startswith("sos last") else "lines"
        print(f"| {names.get(q, q)} | {sw} | {fmt(a[1])} | {fmt(b[0])} | {fmt(b[1])} | {sp} | {n:,} {unit} |")
