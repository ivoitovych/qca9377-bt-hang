#!/usr/bin/env python3
"""check-hunks.py OLDREV : are the code hunks of the two patches byte-identical to those at OLDREV?
Prints the result, and the diff of the headers (the diff of the diffs)."""
import difflib
import subprocess
import sys

PKG = "$WORKDIR/pkg/packaging"
old = sys.argv[1]
names = [
    "lpNNNNNNN-sd-journal-cache-last-entry-offset-and-journal-file-state.patch",
    "lpNNNNNNN-sd-journal-make-journal_file_read_tail_timestamp-notify-to-the-caller.patch",
]
ok = True
for n in names:
    rel = f"debian/patches/{n}"
    a = subprocess.run(["git", "-C", PKG, "show", f"{old}:{rel}"], capture_output=True, check=True).stdout
    b = open(f"{PKG}/{rel}", "rb").read()
    ia, ib = a.index(b"diff --git "), b.index(b"diff --git ")
    same = a[ia:] == b[ib:]
    ok &= same
    print(f"{n}: code hunks {'BYTE-IDENTICAL' if same else 'DIFFERENT'} ({len(a) - ia} bytes)")
    print("".join(difflib.unified_diff(a[:ia].decode().splitlines(True), b[:ib].decode().splitlines(True),
                                       f"a/{rel} (old header)", f"b/{rel} (new header)", n=0)))
print("ALL IDENTICAL" if ok else "MISMATCH")
sys.exit(0 if ok else 1)
