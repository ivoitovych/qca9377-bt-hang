#!/usr/bin/env python3
"""parse-grep-output.py <journal-archive-grep output> <out.tsv>: one row per archive file.
Columns: boot, first_seen_linux_version, kernel, rampatch, patch_rome, startup_disconnects(first 180 s after the version line),
later_disconnects, failed_2007_202f, unexpected_cc, matches."""
import re
import sys
from datetime import datetime

rows = []
cur = []
for line in open(sys.argv[1], errors="replace"):
    line = line.rstrip("\n")
    m = re.match(r"^(boot-[0-9a-f]+)\.export\.zst: (\d+) match", line)
    if m:
        ev = cur
        cur = []
        t0 = None
        kern = ""
        for ts, msg in ev:
            if msg.startswith("Linux version"):
                t0 = ts
                kern = msg.split()[2]
        def dt(s):
            return datetime.strptime(s, "%Y-%m-%d %H:%M:%S")
        ramp = any("using rampatch" in msg for _, msg in ev)
        rome = any("QCA: patch rome" in msg for _, msg in ev)
        disc_s = disc_l = 0
        for ts, msg in ev:
            if "USB disconnect" in msg:
                if t0 and (dt(ts) - dt(t0)).total_seconds() <= 180:
                    disc_s += 1
                else:
                    disc_l += 1
        fail = sum(1 for _, msg in ev if re.search(r"Opcode 0x(2007|202f) failed", msg))
        ucc = sum(1 for _, msg in ev if "unexpected cc" in msg)
        rows.append([m.group(1)[5:], t0 or "(start not in export)", kern or "?", "yes" if ramp else "no", "yes" if rome else "no", str(disc_s), str(disc_l), str(fail), str(ucc), m.group(2)])
        continue
    m = re.match(r"^  (\d{4}-\d\d-\d\d \d\d:\d\d:\d\d)  (.*)$", line)
    if m:
        cur.append((m.group(1), m.group(2)))
rows.sort(key=lambda r: r[1])
with open(sys.argv[2], "w") as f:
    f.write("boot\tlinux_version_line_at\tkernel\trampatch_line\tpatch_rome_line\tdisconnect_within_180s\tdisconnect_later\topcode_2007_202f_failed\tunexpected_cc\tmatches\n")
    for r in rows:
        f.write("\t".join(r) + "\n")
print(len(rows), "rows")
