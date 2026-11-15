#!/usr/bin/env python3
"""Write synthetic journal files whose boots interleave, to test that a change to sd-journal's
cross-boot ordering keeps the output identical.

make-journals-interleaved.py OUTDIR NFILES ENTRIES_PER_FILE NBOOTS

File i belongs to boot i % NBOOTS, so each boot's files are spread over the whole set, and each
boot's realtime window overlaps its neighbours' (boot b starts 40 % of a window after boot b-1),
so entries of different boots interleave by wall clock and their order depends on how sd-journal
orders boots. Every 7th file repeats the first 50 entries of the file before it (same boot, same
timestamps, same message), as when a file is copied: sd-journal must print those once.
"""
import os
import subprocess
import sys

REMOTE = "/lib/systemd/systemd-journal-remote"
MACHINE = "0123456789abcdef0123456789abcdef"


def boot_id(n: int) -> str:
    return f"{n:08x}" + "1e57" * 6


def entry(realtime: int, mono: int, boot: int, msg: str) -> str:
    return (f"__REALTIME_TIMESTAMP={realtime}\n__MONOTONIC_TIMESTAMP={mono}\n"
            f"_BOOT_ID={boot_id(boot)}\n_MACHINE_ID={MACHINE}\n_HOSTNAME=decoy\n"
            f"_TRANSPORT=kernel\nSYSLOG_IDENTIFIER=kernel\nPRIORITY=6\nMESSAGE={msg}\n\n")


def main() -> int:
    outdir, nfiles, per_file, nboots = sys.argv[1], int(sys.argv[2]), int(sys.argv[3]), int(sys.argv[4])
    os.makedirs(outdir, exist_ok=True)
    files_per_boot = (nfiles + nboots - 1) // nboots
    window = files_per_boot * per_file * 2_000          # usec covered by one boot
    prev = None
    for i in range(nfiles):
        b, k = i % nboots, i // nboots                   # boot, and this file's index within its boot
        boot_start = 1_700_000_000_000_000 + b * (window * 4 // 10)
        lines = []
        if prev is not None and i % 7 == 0:
            lines.extend(prev[:50])                      # a copied stretch: the same entries again
        mine = []
        for e in range(per_file):
            off = (k * per_file + e) * 2_000
            mine.append(entry(boot_start + off, 5_000_000 + off, b, f"interleaved line {e} of file {i} boot {b}"))
        lines.extend(mine)
        prev = mine
        path = os.path.join(outdir, f"system@{i:05d}.journal")
        p = subprocess.run([REMOTE, f"--output={path}", "-"], input="".join(lines).encode(),
                           stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)
        if p.returncode != 0:
            sys.stderr.write(f"journal-remote failed on {path}: {p.stderr.decode()[-400:]}\n")
            return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
