#!/usr/bin/env python3
"""make-sums.py <dir>: write <dir>/SHA256SUMS for every regular file in <dir> (not recursive, not SHA256SUMS itself)."""
import hashlib
import os
import sys

d = sys.argv[1]
lines = []
for n in sorted(os.listdir(d)):
    p = os.path.join(d, n)
    if n == "SHA256SUMS" or not os.path.isfile(p):
        continue
    lines.append(hashlib.sha256(open(p, "rb").read()).hexdigest() + "  " + n)
with open(os.path.join(d, "SHA256SUMS"), "w") as f:
    f.write("\n".join(lines) + "\n")
print(len(lines), "files")
