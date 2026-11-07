#!/usr/bin/python3 -I
"""Save lore archive messages (the 'm' blob of each archive commit) as
<outdir>/<commit>.eml.

Usage: lore-save.py <lore.git> <outdir> <commit> [<commit> ...]
"""
import os
import subprocess
import sys

LORE, OUT = sys.argv[1], sys.argv[2]
os.makedirs(OUT, exist_ok=True)
for c in sys.argv[3:]:
    data = subprocess.run(["git", "-C", LORE, "show", f"{c}:m"],
                          capture_output=True, check=True).stdout
    with open(os.path.join(OUT, f"{c}.eml"), "wb") as f:
        f.write(data)
    print(f"{c}\t{len(data)} bytes", file=sys.stderr)
