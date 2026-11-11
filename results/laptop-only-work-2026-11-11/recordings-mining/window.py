#!/usr/bin/env python3
"""window.py <boot id> '<since>' '<until>' <regex> <out file> : read-only journal window (journalctl -b ID --since --until), keep lines matching regex,
MAC addresses and device-path addresses replaced by <MAC>."""
import re
import subprocess
import sys

boot, since, until, rx, out = sys.argv[1:6]
p = subprocess.run(["journalctl", "-b", boot, "--since", since, "--until", until, "--no-pager", "-o", "short-iso-precise"], capture_output=True, text=True, errors="replace")
mac = re.compile(r"\b[0-9A-Fa-f]{2}(?:[:_][0-9A-Fa-f]{2}){5}\b")
n = 0
with open(out, "w") as o:
    for line in p.stdout.splitlines():
        if re.search(rx, line):
            o.write(mac.sub("<MAC>", line)[:300] + "\n")
            n += 1
print(n, "lines kept of", len(p.stdout.splitlines()))
