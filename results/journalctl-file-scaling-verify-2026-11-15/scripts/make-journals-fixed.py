#!/usr/bin/env python3
"""make-journals-fixed.py REMOTE OUTDIR NFILES ENTRIES_PER_FILE [FILES_PER_BOOT]

Same method as the other maintainer's make-journals.py (journal files written by
systemd-journal-remote from generated export streams, consecutive slices, FILES_PER_BOOT files
per boot, one machine ID), with two changes: the journal-remote binary is an argument, and each
file's header state is set to ARCHIVED (1), as rotated files are. Files can be added later
(the first K files are always the same as in a smaller run).
"""
import os
import subprocess
import sys

MACHINE = "0123456789abcdef0123456789abcdef"


def boot_id(n: int) -> str:
    return f"{n:08x}" + "b007" * 6


def main() -> int:
    remote, outdir, nfiles, per_file = sys.argv[1], sys.argv[2], int(sys.argv[3]), int(sys.argv[4])
    per_boot = int(sys.argv[5]) if len(sys.argv) > 5 else 5
    os.makedirs(outdir, exist_ok=True)
    realtime = 1_700_000_000_000_000
    step = 2_000
    seq = 0
    for i in range(nfiles):
        b = i // per_boot
        if i % per_boot == 0:
            realtime += 60_000_000
            mono = 5_000_000
        path = os.path.join(outdir, f"system@{i:05d}.journal")
        lines = []
        for _ in range(per_file):
            seq += 1
            realtime += step
            mono += step
            lines.append(
                f"__REALTIME_TIMESTAMP={realtime}\n__MONOTONIC_TIMESTAMP={mono}\n"
                f"_BOOT_ID={boot_id(b)}\n_MACHINE_ID={MACHINE}\n_HOSTNAME=decoy\n"
                f"_TRANSPORT=kernel\nSYSLOG_IDENTIFIER=kernel\nPRIORITY=6\n"
                f"MESSAGE=synthetic kernel line {seq} in file {i} boot {b}\n\n")
        if os.path.exists(path):
            continue
        proc = subprocess.run([remote, f"--output={path}.tmp.journal", "-"], input="".join(lines).encode(),
                              stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)
        if proc.returncode != 0:
            sys.stderr.write(f"journal-remote failed on {path}: {proc.stderr.decode()[-400:]}\n")
            return 1
        with open(path + ".tmp.journal", "r+b") as f:
            f.seek(16)
            f.write(b"\x02")          # header state: STATE_ARCHIVED (2)
        os.rename(path + ".tmp.journal", path)
    return 0


if __name__ == "__main__":
    sys.exit(main())
