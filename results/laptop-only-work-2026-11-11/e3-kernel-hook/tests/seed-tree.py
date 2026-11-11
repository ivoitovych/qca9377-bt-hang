#!/usr/bin/python3 -I
"""Test helper: pre-fill the hook's source-tree cache for one kernel package version from files that
are already on disk and verified against a .dsc (used for 7.0.0-38, whose source the archive no
longer lists). Uses the hook's own functions, so the tree is made exactly as the hook makes it.

    seed-tree.py <pkg> <version> <dsc> <diff.gz> <orig.tar.gz>"""
import importlib.machinery
import importlib.util
import json
import os
import re
import shutil
import sys

pkg, ver, dsc, diff, orig = sys.argv[1:6]
loader = importlib.machinery.SourceFileLoader("e3", "/usr/local/sbin/btusb-e3")
spec = importlib.util.spec_from_loader("e3", loader)
e3 = importlib.util.module_from_spec(spec)
loader.exec_module(e3)

want = {}
txt = open(dsc).read()
sec = txt.split("Checksums-Sha256:")[1].split("\nFiles:")[0]
for line in sec.strip().splitlines():
    h, s, n = line.split()
    want[n] = h
for path in (diff, orig):
    n = os.path.basename(path)
    key = n if n in want else re.sub(r"^.*?(linux-hwe-7.0_7.0.0.orig.tar.gz)$", r"\1", n)
    got = e3.sha256_file(path)
    assert want[key] == got, f"{n}: sha256 {got} != .dsc {want[key]}"
    print(f"verified against the .dsc: {n} {got}")
tree = os.path.join(e3.CACHE, "tree", f"{pkg}_{ver}")
shutil.rmtree(tree, ignore_errors=True)
os.makedirs(tree)
e3.extract_orig(orig, tree)
kept = e3.filter_diff(diff, "/tmp/seed.diff")
import subprocess
r = subprocess.run(["patch", "-p1", "--fuzz=0", "--no-backup-if-mismatch", "-s", "-d", tree, "-i", "/tmp/seed.diff"])
assert r.returncode == 0
json.dump({"seeded_from": "local files verified against the .dsc", "diff_sections_kept": kept},
          open(os.path.join(tree, ".complete"), "w"))
print("seeded", tree, "sections", kept)
