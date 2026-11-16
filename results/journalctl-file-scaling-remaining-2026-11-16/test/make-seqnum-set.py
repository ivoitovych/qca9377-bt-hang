#!/usr/bin/env python3
"""make-seqnum-set.py REMOTE OUTDIR [FILES_PER_GROUP [ENTRIES]] : 3 groups of FILES_PER_GROUP files (default 10, 300 entries).
The files of group 0 all carry one seqnum ID and those of group 1 another (the header's seqnum_id, offset 72, is
overwritten); group 2 keeps a random ID per file. Every file's entries are numbered 1..N by journal-remote, so within
a group the sequence numbers repeat from file to file, while the groups' time ranges interleave and each group is its
own machine ID. That is not a journal journald would write (the sequence numbers of one seqnum ID rise with time);
it is an input on which compare_locations() mixes two orders, sequence numbers for files of the same ID and time for
the rest, so it is not transitive. Used to see how the linear scan, PR #44579 and a heap behave on such input."""
import os
import subprocess
import sys

REMOTE, OUT = sys.argv[1], sys.argv[2]
FPG = int(sys.argv[3]) if len(sys.argv) > 3 else 10
N = int(sys.argv[4]) if len(sys.argv) > 4 else 300
os.makedirs(OUT)
MS = ["0123456789abcdef0123456789abcdef", "fedcba9876543210fedcba9876543210", "aaaaaaaabbbbbbbbccccccccdddddddd"]
BASE = 1_700_000_000_000_000
IDS = [bytes.fromhex("11" * 16), bytes.fromhex("22" * 16), None]
for i in range(3 * FPG):
    g = i // FPG
    k = i % FPG
    lines = []
    for e in range(N):
        slot = (k * N + e) * 3 + g          # groups interleave in time
        t = slot * 2000
        lines.append(f"__REALTIME_TIMESTAMP={BASE + t}\n__MONOTONIC_TIMESTAMP={5_000_000 + t}\n_BOOT_ID={g:08x}" + "5e9d" * 6 +
                     f"\n_MACHINE_ID={MS[g]}\n_HOSTNAME=repro\n_TRANSPORT=kernel\nSYSLOG_IDENTIFIER=kernel\nPRIORITY=6\nMESSAGE=seq g{g} f{k} e{e}\n\n")
    p = f"{OUT}/system@{i:05d}.journal"
    q = subprocess.run([REMOTE, f"--output={p}", "-"], input="".join(lines).encode(), stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)
    if q.returncode != 0:
        sys.exit(q.stderr.decode()[-200:])
    with open(p, "r+b") as f:
        f.seek(16); f.write(b"\x02")
        if IDS[g] and not os.environ.get("NOIDS"):
            f.seek(72); f.write(IDS[g])
