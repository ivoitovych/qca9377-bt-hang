#!/usr/bin/env python3
"""Write SHA256SUMS (relative names, sorted) for the files of a directory.
The SHA256SUMS file itself and symlinks are skipped.
Usage: make-sums.py <dir> [--recursive] [--exclude <relative path>]..."""
import hashlib
import os
import sys

args = sys.argv[1:]
d = args[0]
rec = "--recursive" in args
excl = set()
for i, a in enumerate(args):
    if a == "--exclude":
        excl.add(args[i + 1])
rows = []
for dp, dn, fn in os.walk(d):
    for f in fn:
        p = os.path.join(dp, f)
        rel = os.path.relpath(p, d)
        if rel == "SHA256SUMS" or os.path.islink(p) or rel in excl:
            continue
        h = hashlib.sha256(open(p, "rb").read()).hexdigest()
        rows.append("%s  %s\n" % (h, rel))
    if not rec:
        break
rows.sort(key=lambda r: r.split("  ", 1)[1])
open(os.path.join(d, "SHA256SUMS"), "w").write("".join(rows))
print("wrote %d rows to %s/SHA256SUMS" % (len(rows), d))
