#!/usr/bin/env python3
"""Write synthetic journal files for measuring journalctl's cost per open file.

make-journals.py OUTDIR NFILES ENTRIES_PER_FILE [FILES_PER_BOOT]

Each file is written by systemd-journal-remote from an export-format stream, so the files are
real journal files in the format of the journal-remote on this host. File i holds the entries
of one time slice; consecutive slices follow each other in time, as rotated files do. Every
FILES_PER_BOOT files share a boot ID (monotonic time restarts with each boot), so the merge
compares entries across boots, as on a machine with many boots in its journal. All entries
are kernel-like lines with one machine ID. Nothing is read from this host's journal.
"""
import os
import subprocess
import sys

REMOTE = "/lib/systemd/systemd-journal-remote"
MACHINE = "0123456789abcdef0123456789abcdef"


def boot_id(n: int) -> str:
    return f"{n:08x}" + "b007" * 6


def main() -> int:
    outdir, nfiles, per_file = sys.argv[1], int(sys.argv[2]), int(sys.argv[3])
    per_boot = int(sys.argv[4]) if len(sys.argv) > 4 else 5
    os.makedirs(outdir, exist_ok=True)
    realtime = 1_700_000_000_000_000          # usec, 2023-11-14
    step = 2_000                              # 2 ms between entries
    seq = 0
    for i in range(nfiles):
        b = i // per_boot
        if i % per_boot == 0:
            realtime += 60_000_000            # a minute between boots
            mono = 5_000_000
        path = os.path.join(outdir, f"system@{i:05d}.journal")
        proc = subprocess.Popen([REMOTE, f"--output={path}", "-"], stdin=subprocess.PIPE,
                                stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)
        lines = []
        for _ in range(per_file):
            seq += 1
            realtime += step
            mono += step
            lines.append(
                f"__REALTIME_TIMESTAMP={realtime}\n"
                f"__MONOTONIC_TIMESTAMP={mono}\n"
                f"_BOOT_ID={boot_id(b)}\n"
                f"_MACHINE_ID={MACHINE}\n"
                f"_HOSTNAME=decoy\n"
                f"_TRANSPORT=kernel\n"
                f"SYSLOG_IDENTIFIER=kernel\n"
                f"PRIORITY=6\n"
                f"MESSAGE=synthetic kernel line {seq} in file {i} boot {b}\n\n")
        _, err = proc.communicate("".join(lines).encode())
        if proc.returncode != 0:
            sys.stderr.write(f"journal-remote failed on {path}: {err.decode()[-400:]}\n")
            return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
