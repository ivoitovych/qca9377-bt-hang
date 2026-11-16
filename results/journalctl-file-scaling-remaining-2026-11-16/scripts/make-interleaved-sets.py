#!/usr/bin/env python3
"""make-interleaved-sets.py REMOTE OUTROOT EPF K... : sets whose files all cover the same time range, so that the
next entry of the merge comes from a different file almost every time (the case where a cached winner helps least).
  int1/<K>/   K files, one machine, one boot; file i holds the entries e*K+i of a round robin (ordered by monotonic time)
  int3m/<K>/  K files, three machine IDs (file i belongs to machine i%3, one boot each), round robin by realtime, the
              machines' clocks 0, 3 and 7 seconds apart: entries of different machines compare by realtime only
All files ARCHIVED (header state 2). Written by systemd-journal-remote from export streams."""
import os
import subprocess
import sys

REMOTE, ROOT, EPF = sys.argv[1], sys.argv[2], int(sys.argv[3])
KS = [int(k) for k in sys.argv[4:]]
MACHINES = ["0123456789abcdef0123456789abcdef", "fedcba9876543210fedcba9876543210", "aaaaaaaabbbbbbbbccccccccdddddddd"]
SKEW = [0, 3_000_000, 7_000_000]
BASE = 1_700_000_000_000_000


def write(path, text):
    p = subprocess.run([REMOTE, f"--output={path}", "-"], input=text.encode(), stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)
    if p.returncode != 0:
        sys.exit(f"journal-remote failed on {path}: {p.stderr.decode()[-300:]}")
    with open(path, "r+b") as f:
        f.seek(16)
        f.write(b"\x02")


def entry(rt, mono, boot, machine, msg):
    return (f"__REALTIME_TIMESTAMP={rt}\n__MONOTONIC_TIMESTAMP={mono}\n_BOOT_ID={boot}\n_MACHINE_ID={machine}\n_HOSTNAME=repro\n"
            f"_TRANSPORT=kernel\nSYSLOG_IDENTIFIER=kernel\nPRIORITY=6\nMESSAGE={msg}\n\n")


for kind in ("int1", "int3m"):
    for k in KS:
        d = f"{ROOT}/{kind}/{k}"
        os.makedirs(d, exist_ok=True)
        for i in range(k):
            m = i % 3 if kind == "int3m" else 0
            boot = f"{m:08x}" + "1e57" * 6
            lines = []
            for e in range(EPF):
                t = (e * k + i) * 2000
                lines.append(entry(BASE + SKEW[m] + t, 5_000_000 + t, boot, MACHINES[m], f"{kind} file {i} entry {e}"))
            path = f"{d}/system@{i:05d}.journal"
            if not os.path.exists(path):
                write(path, "".join(lines))
        print(kind, k, "done", flush=True)
