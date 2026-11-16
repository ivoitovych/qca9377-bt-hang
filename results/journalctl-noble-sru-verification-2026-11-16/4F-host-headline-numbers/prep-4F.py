#!/usr/bin/env python3
"""prep-4F.py : independent COPIES (cp, not hard links) of the synthetic noble-default journal subsets, on the host.
Same selection as the generator of the default-install model (newest first by boot and position):
  mixed-K  the K newest files of system and user files together (K = 25, 50, 100)
  sys-K    the K newest system files (K = 25, 50, 100)
Writes <work dir>/verify/data/4F/<set>/ and FIXTURE-SHA256.txt (names, sizes, sha256 are recorded for the 25-file sets only,
to keep the record small; all sets are built from the same source files)."""
import os
import shutil
import sys

W = "<work dir>"
SRC = f"{W}/data/noble-default/all"
OUT = f"{W}/verify/data/4F"
sysf = sorted(os.listdir(f"{SRC}/system"))
usrf = sorted(os.listdir(f"{SRC}/user"))


def key(kind, name):
    b = int(name.split("@")[1][:3])
    k = int(name.split("@")[1][3:6])
    per = 10 if kind == "s" else 5
    return (b, (k + 1) / per)


allf = [(key("s", n), "system", n) for n in sysf] + [(key("u", n), "user", n) for n in usrf]
allf.sort(reverse=True)
sysnew = sorted([(key("s", n), n) for n in sysf], reverse=True)
sets = {}
for K in (25, 50, 100):
    sets[f"mixed-{K}"] = [(s, n) for _, s, n in allf[:K]]
    sets[f"sys-{K}"] = [("system", n) for _, n in sysnew[:K]]
for name, items in sets.items():
    d = f"{OUT}/{name}"
    os.makedirs(d, exist_ok=True)
    for sub, n in items:
        if not os.path.exists(f"{d}/{n}"):
            shutil.copyfile(f"{SRC}/{sub}/{n}", f"{d}/{n}")
    nu = sum(1 for n in os.listdir(d) if n.startswith("user-"))
    print(f"{name}: {len(items)} files, {nu} user files", flush=True)
