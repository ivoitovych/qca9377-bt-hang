#!/usr/bin/env python3
"""make4D.py REMOTE OUTDIR FIRST NFILES [STATE] : NFILES journal files named by index FIRST.. written by REMOTE
(systemd-journal-remote) from export streams: 3 boots of one machine, 1000 entries per file, MESSAGE "D f<i> e<n>",
sequential in time. STATE 'archived' sets the header state byte (offset 16) to 2; default leaves what the writer wrote."""
import os
import subprocess
import sys

remote, out, first, n = sys.argv[1], sys.argv[2], int(sys.argv[3]), int(sys.argv[4])
state = sys.argv[5] if len(sys.argv) > 5 else ""
os.makedirs(out, exist_ok=True)
M = "0123456789abcdef0123456789abcdef"
rt = 1_700_000_000_000_000 + first * 20_000_000
mono = 5_000_000 + (first % 4) * 2_000_000
for i in range(first, first + n):
    b = i // 4
    if i % 4 == 0:
        mono = 5_000_000
    lines = []
    for e in range(1000):
        rt += 2000
        mono += 2000
        lines.append(f"__REALTIME_TIMESTAMP={rt}\n__MONOTONIC_TIMESTAMP={mono}\n_BOOT_ID={b:08x}{'b007' * 6}\n_MACHINE_ID={M}\n"
                     f"_HOSTNAME=fx\n_TRANSPORT=kernel\nSYSLOG_IDENTIFIER=kernel\nPRIORITY=6\nMESSAGE=D f{i:02d} e{e:04d}\n\n")
    p = f"{out}/system@{i:05d}.journal"
    r = subprocess.run([remote, f"--output={p}", "-"], input="".join(lines).encode(), stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)
    if r.returncode != 0:
        sys.exit(f"{remote} failed: {r.stderr.decode()[-200:]}")
    if state == "archived":
        with open(p, "r+b") as f:
            f.seek(16); f.write(b"\x02")
print(f"wrote {n} files from index {first} into {out}")
