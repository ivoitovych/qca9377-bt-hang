#!/usr/bin/env python3
"""convert-patch.py <in.patch> <out.patch> <old path> <new path>

Copy of a mail-format patch for the build here: the diff header paths <old path>
become <new path> (btusb_main.c of bluetooth-next to btusb.c of Ubuntu's tree), and
the From:, Date: and Signed-off-by: lines of the mail header are dropped, so that
no address is copied into this work area. Refuses to overwrite.
"""
import os
import sys

src, dst, old, new = sys.argv[1:5]
if os.path.exists(dst):
    sys.exit(f"exists: {dst}")
out = []
n = 0
in_diff = False
for line in open(src):
    if line.startswith("diff --git "):
        in_diff = True
    if not in_diff and line.startswith(("From: ", "Date: ", "Signed-off-by: ")):
        continue
    if line.startswith(("diff --git ", "--- a/", "+++ b/")) and old in line:
        line = line.replace(old, new)
        n += 1
    out.append(line)
open(dst, "w").write("".join(out))
print(f"{n} header lines rewritten into {dst}")
