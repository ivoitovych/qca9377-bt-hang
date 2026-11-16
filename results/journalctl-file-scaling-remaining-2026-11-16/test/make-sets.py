#!/usr/bin/env python3
"""make-sets.py REMOTE OUTROOT : the equivalence sets for the packaging test, all under OUTROOT.
  plain/       60 files, 12 boots (5 files per boot), one machine, ARCHIVED
  interleaved/ 60 files over 12 boots whose time windows overlap, copied stretches, ARCHIVED   (as on the earlier page)
  twomachines/ 40 files: two machine IDs, each with its own boots, time ranges overlapping, ARCHIVED
  Files are written by systemd-journal-remote from export streams; header state byte (offset 16) set to ARCHIVED."""
import os
import subprocess
import sys

REMOTE, ROOT = sys.argv[1], sys.argv[2]
M1 = "0123456789abcdef0123456789abcdef"
M2 = "fedcba9876543210fedcba9876543210"


def entry(rt, mono, boot, machine, msg):
    return (f"__REALTIME_TIMESTAMP={rt}\n__MONOTONIC_TIMESTAMP={mono}\n_BOOT_ID={boot}\n_MACHINE_ID={machine}\n"
            f"_HOSTNAME=repro\n_TRANSPORT=kernel\nSYSLOG_IDENTIFIER=kernel\nPRIORITY=6\nMESSAGE={msg}\n\n")


def write(path, text, archived=True):
    p = subprocess.run([REMOTE, f"--output={path}", "-"], input=text.encode(), stdout=subprocess.DEVNULL,
                       stderr=subprocess.PIPE)
    if p.returncode != 0:
        sys.exit(f"journal-remote failed on {path}: {p.stderr.decode()[-300:]}")
    if archived:
        with open(path, "r+b") as f:
            f.seek(16)
            f.write(b"\x02")


def plain():
    d = f"{ROOT}/plain"; os.makedirs(d)
    rt = 1_700_000_000_000_000
    seq = 0
    for i in range(60):
        b = i // 5
        if i % 5 == 0:
            rt += 60_000_000; mono = 5_000_000
        lines = []
        for _ in range(400):
            seq += 1; rt += 2000; mono += 2000
            lines.append(entry(rt, mono, f"{b:08x}" + "b007" * 6, M1, f"plain {seq} file {i} boot {b}"))
        write(f"{d}/system@{i:05d}.journal", "".join(lines))


def interleaved():
    d = f"{ROOT}/interleaved"; os.makedirs(d)
    nfiles, per_file, nboots = 60, 400, 12
    fpb = (nfiles + nboots - 1) // nboots
    window = fpb * per_file * 2000
    prev = None
    for i in range(nfiles):
        b, k = i % nboots, i // nboots
        start = 1_700_000_000_000_000 + b * (window * 4 // 10)
        lines = []
        if prev is not None and i % 7 == 0:
            lines.extend(prev[:50])
        mine = []
        for e in range(per_file):
            off = (k * per_file + e) * 2000
            mine.append(entry(start + off, 5_000_000 + off, f"{b:08x}" + "1e57" * 6, M1, f"interleaved {e} file {i} boot {b}"))
        lines.extend(mine); prev = mine
        write(f"{d}/system@{i:05d}.journal", "".join(lines))


def twomachines():
    d = f"{ROOT}/twomachines"; os.makedirs(d)
    # machine 1 and machine 2 alternate by file; 4 boots each, windows overlapping; machine 2's clock is 7 s ahead
    per_file = 400
    nboots = 4
    for i in range(40):
        m = M1 if i % 2 == 0 else M2
        j = i // 2                    # index of this file within its machine
        b = j // 5
        skew = 0 if m == M1 else 7_000_000
        start = 1_700_000_000_000_000 + skew + b * 30_000_000   # boots of one machine 30 s apart: overlap in time
        lines = []
        for e in range(per_file):
            off = ((j % 5) * per_file + e) * 2000
            tag = "a" if m == M1 else "c"
            lines.append(entry(start + off, 5_000_000 + off, f"{b:08x}" + (tag + "d0d") * 6, m, f"twomach {e} file {i} machine {1 if m == M1 else 2} boot {b}"))
        write(f"{d}/system@{i:05d}.journal", "".join(lines))


plain(); interleaved(); twomachines()
print("sets written under", ROOT)
