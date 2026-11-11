#!/usr/bin/env python3
"""Read-only: list the Bluetooth devices PipeWire's quirk matcher has seen, with the exact
name string it matched on and the vendor/product/version ids it was given (the Modalias),
from the desktop user's journal lines "quirk property <key>=<value>" (WirePlumber debug
topic spa.bluez5.quirks, enabled on the laptop).  The address line is read but never printed.

  device-ids-from-journal.py --since "2026-11-12 14:00"    (a short range is fast; weeks are slow)
  device-ids-from-journal.py --from-file F                 (test mode: journalctl -o cat text)
"""
import argparse
import collections
import re
import subprocess
import sys

ap = argparse.ArgumentParser()
ap.add_argument("--since", default="1 hour ago")
ap.add_argument("--uid", default="1000")
ap.add_argument("--from-file")
args = ap.parse_args()

if args.from_file:
    text = open(args.from_file, errors="replace").read()
else:
    cmd = ["journalctl", "_UID=" + args.uid, "--no-pager", "-o", "cat",
           "--since", args.since, "-g", "quirk property "]
    text = subprocess.run(cmd, capture_output=True, text=True).stdout

pat = re.compile(r"quirk property ([a-z-]+)=(.*)")
seen = collections.Counter()
cur = {}
for line in text.splitlines():
    m = pat.search(line)
    if not m:
        continue
    key, val = m.group(1), m.group(2)
    if key == "address":
        if "name" in cur:
            ids = ", ".join("%s=%s" % (k, cur[k]) for k in ("vendor-id", "product-id", "version-id") if k in cur)
            seen[(cur["name"], ids or "no vendor/product ids given")] += 1
        cur = {}
        continue
    cur[key] = val
if not seen:
    print("no device blocks found (no headset connected in that range, or address lines missing)",
          file=sys.stderr)
    sys.exit(1)
print("count  name (exact)  |  ids PipeWire was given")
for (name, ids), n in sorted(seen.items()):
    print("%5d  %s  |  %s" % (n, name, ids))
