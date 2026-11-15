#!/usr/bin/env python3
"""fixstate.py DIR... : set the header state byte (offset 16) of every .journal file to 2 (ARCHIVED)."""
import glob
import sys

for d in sys.argv[1:]:
    for p in sorted(glob.glob(d + "/*.journal")):
        with open(p, "r+b") as f:
            f.seek(16)
            f.write(b"\x02")
