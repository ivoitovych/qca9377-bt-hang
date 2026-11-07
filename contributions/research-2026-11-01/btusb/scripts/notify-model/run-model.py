#!/usr/bin/env python3
"""run-model.py <btusb.c> <out dir>

Copies btusb_notify() and btusb_work() verbatim out of the given btusb.c,
puts them between prelude.h (stubs) and scenarios.c (a scripted core), builds
the result with the host's gcc and runs it. Prints the scenarios' output.
The out dir must not exist.
"""
import os
import re
import subprocess
import sys

here = os.path.dirname(os.path.abspath(__file__))
src, out = sys.argv[1], sys.argv[2]
if os.path.exists(out):
    sys.exit(f"exists: {out}")
os.makedirs(out)
text = open(src).read()


def extract(name):
    m = re.search(r"^static void " + name + r"\(.*?^}\n", text, re.S | re.M)
    if not m:
        sys.exit(f"{name} not found in {src}")
    return m.group(0)


body = "\n".join([
    open(os.path.join(here, "prelude.h")).read(),
    f"/* ---- verbatim from {src} ---- */",
    extract("btusb_notify"),
    extract("btusb_work"),
    "/* ---- end of verbatim code ---- */",
    open(os.path.join(here, "scenarios.c")).read(),
])
c = os.path.join(out, "model.c")
open(c, "w").write(body)
exe = os.path.join(out, "model")
r = subprocess.run(["gcc", "-O0", "-Wall", "-Wno-unused-function", "-o", exe, c],
                   capture_output=True, text=True)
print(r.stdout + r.stderr, end="")
if r.returncode:
    sys.exit(f"gcc failed ({r.returncode})")
r = subprocess.run([exe], capture_output=True, text=True)
print(r.stdout, end="")
sys.exit(r.returncode)
