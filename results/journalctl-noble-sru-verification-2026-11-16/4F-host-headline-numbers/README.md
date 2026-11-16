# 4F: host headline numbers (no container), stock 8.19 against the 8.20 test build

Result: on the host, on frozen synthetic copies, every query ran to completion (no cap was hit, no run was cut short, no
projection is used), every exit status was as expected, output sizes are identical between the builds, and the patched build is
faster in every journal-reading query from 25 files up. Full read of the newest-boot journal (`-b all`) at 100 files:
stock 907.8 s (mixed) and 1098.3 s (system only) against patched 83.8 s and 93.1 s (10.8x and 11.8x).

## Method

* Binaries: the unpacked stock 255.4-1ubuntu8.19 and 8.20 test packages (`../scripts/PACKAGES.txt`), run on the host with
  `LD_LIBRARY_PATH` pointing at the unpacked tree (wrappers `hjc-s819`, `hjc-p820`); nothing installed, the host's own
  `journalctl` and journal untouched; `--directory=<copy>` only.
* Data: independent copies (`cp`, `prep-4F.py`) of the synthetic noble-default model, never the live journal: `mixed-25/50/100`
  (system and user files together, newest first: 9, 17 and 34 user files) and `sys-25/50/100` (system files only).
  Records: `4F-prep.txt`.
* Queries (`host-4F.sh`): `-b` (newest boot), `-k -b all`, apport's `--quiet -b -a --system`, sos's collection commands with
  their own 300 s limit (`--disk-usage`, `--list-boots`, and `--no-pager --reverse`, `--boot --reverse`, `--boot -1 --reverse`
  cut at 100 MB as sos does with `head -c`), and the full read `-b all`.
* Termination: every query ends by itself; cap 7200 s per run (2 h), 300 s for the sos commands; a cap hit would show as exit
  status 124 and `cap hit = YES`. None did. Exit status 141 is SIGPIPE from the 100 MB cut (expected, identical in both builds).
* One run per query and build, nothing else heavy on the machine (`nice -n 19 ionice -c 3`); per set, patched ran first, then
  stock. Wall seconds; the cpu columns are user plus system.
* Output check: the line or byte count is compared for each pair (all `same`). Equivalence of content (sha256) is in 4A, 4D, 4E.

## Table (`4F.tsv` has the raw rows)

### mixed-25

| query | stock wall s | patched wall s | speed-up | stock cpu s | patched cpu s | output (lines or bytes) | exit stock / patched | cap hit |
|---|---|---|---|---|---|---|---|---|
| -b (newest boot) | 13.98 | 4.72 | 3.0x | 14.1 | 4.8 | 630000 (same) | 0 / 0 | no |
| -k -b all | 1.01 | 0.44 | - | 1.0 | 0.3 | 30553 (same) | 0 / 0 | no |
| apport: --quiet -b -a --system | 7.34 | 2.53 | 2.9x | 7.4 | 2.6 | 480000 (same) | 0 / 0 | no |
| sos: --disk-usage | 0.01 | 0.01 | - | 0.0 | 0.0 | 1 (same) | 0 / 0 | no |
| sos: --list-boots | 0.01 | 0.02 | - | 0.0 | 0.0 | 3 (same) | 0 / 0 | no |
| sos full: --no-pager --reverse (first 100 MB) | 31.37 | 5.46 | 5.7x | 31.7 | 5.7 | 104857600 (same) | 141 / 141 | no |
| sos this boot: --no-pager --boot --reverse (first 100 MB) | 13.93 | 4.33 | 3.2x | 14.2 | 4.6 | 104857600 (same) | 141 / 141 | no |
| sos last boot: --no-pager --boot -1 --reverse (first 100 MB) | 9.29 | 3.13 | 3.0x | 9.5 | 3.2 | 69854630 (same) | 0 / 0 | no |
| -b all (full read) | 42.85 | 8.33 | 5.1x | 43.1 | 8.5 | 1038001 (same) | 0 / 0 | no |

### sys-25

| query | stock wall s | patched wall s | speed-up | stock cpu s | patched cpu s | output (lines or bytes) | exit stock / patched | cap hit |
|---|---|---|---|---|---|---|---|---|
| -b (newest boot) | 11.43 | 3.51 | 3.3x | 11.6 | 3.5 | 480000 (same) | 0 / 0 | no |
| -k -b all | 2.71 | 1.10 | 2.5x | 2.7 | 0.6 | 47697 (same) | 0 / 0 | no |
| apport: --quiet -b -a --system | 10.77 | 2.53 | 4.3x | 10.9 | 2.6 | 480000 (same) | 0 / 0 | no |
| sos: --disk-usage | 0.01 | 0.01 | - | 0.0 | 0.0 | 1 (same) | 0 / 0 | no |
| sos: --list-boots | 0.01 | 0.03 | - | 0.0 | 0.0 | 4 (same) | 0 / 0 | no |
| sos full: --no-pager --reverse (first 100 MB) | 39.03 | 5.90 | 6.6x | 39.4 | 6.2 | 104857600 (same) | 141 / 141 | no |
| sos this boot: --no-pager --boot --reverse (first 100 MB) | 11.26 | 3.40 | 3.3x | 11.5 | 3.6 | 81675309 (same) | 0 / 0 | no |
| sos last boot: --no-pager --boot -1 --reverse (first 100 MB) | 11.37 | 3.71 | 3.1x | 11.6 | 3.7 | 81666085 (same) | 0 / 0 | no |
| -b all (full read) | 54.56 | 10.51 | 5.2x | 54.9 | 10.8 | 1200002 (same) | 0 / 0 | no |

### mixed-50

| query | stock wall s | patched wall s | speed-up | stock cpu s | patched cpu s | output (lines or bytes) | exit stock / patched | cap hit |
|---|---|---|---|---|---|---|---|---|
| -b (newest boot) | 24.55 | 5.13 | 4.8x | 24.7 | 5.1 | 630000 (same) | 0 / 0 | no |
| -k -b all | 4.64 | 1.61 | 2.9x | 4.7 | 0.8 | 62993 (same) | 0 / 0 | no |
| apport: --quiet -b -a --system | 13.83 | 2.61 | 5.3x | 14.0 | 2.7 | 480000 (same) | 0 / 0 | no |
| sos: --disk-usage | 0.01 | 0.01 | - | 0.0 | 0.0 | 1 (same) | 0 / 0 | no |
| sos: --list-boots | 0.03 | 0.08 | - | 0.0 | 0.0 | 5 (same) | 0 / 0 | no |
| sos full: --no-pager --reverse (first 100 MB) | 89.78 | 9.29 | 9.7x | 90.2 | 9.6 | 104857600 (same) | 141 / 141 | no |
| sos this boot: --no-pager --boot --reverse (first 100 MB) | 23.84 | 4.72 | 5.1x | 24.2 | 5.0 | 104857600 (same) | 141 / 141 | no |
| sos last boot: --no-pager --boot -1 --reverse (first 100 MB) | 23.73 | 5.44 | 4.4x | 24.1 | 5.5 | 104857600 (same) | 141 / 141 | no |
| -b all (full read) | 195.39 | 24.24 | 8.1x | 196.0 | 24.7 | 2094003 (same) | 0 / 0 | no |

### sys-50

| query | stock wall s | patched wall s | speed-up | stock cpu s | patched cpu s | output (lines or bytes) | exit stock / patched | cap hit |
|---|---|---|---|---|---|---|---|---|
| -b (newest boot) | 19.35 | 4.01 | 4.8x | 19.5 | 3.9 | 480000 (same) | 0 / 0 | no |
| -k -b all | 9.99 | 2.69 | 3.7x | 10.0 | 1.6 | 95837 (same) | 0 / 0 | no |
| apport: --quiet -b -a --system | 18.59 | 2.90 | 6.4x | 18.7 | 3.0 | 480000 (same) | 0 / 0 | no |
| sos: --disk-usage | 0.01 | 0.01 | - | 0.0 | 0.0 | 1 (same) | 0 / 0 | no |
| sos: --list-boots | 0.03 | 0.10 | - | 0.0 | 0.1 | 6 (same) | 0 / 0 | no |
| sos full: --no-pager --reverse (first 100 MB) | 102.86 | 10.94 | 9.4x | 103.2 | 10.3 | 104857600 (same) | 141 / 141 | no |
| sos this boot: --no-pager --boot --reverse (first 100 MB) | 23.89 | 4.16 | 5.7x | 24.2 | 4.4 | 81675309 (same) | 0 / 0 | no |
| sos last boot: --no-pager --boot -1 --reverse (first 100 MB) | 20.03 | 3.71 | 5.4x | 20.3 | 3.9 | 81666085 (same) | 0 / 0 | no |
| -b all (full read) | 249.61 | 30.17 | 8.3x | 250.0 | 30.5 | 2400004 (same) | 0 / 0 | no |

### mixed-100

| query | stock wall s | patched wall s | speed-up | stock cpu s | patched cpu s | output (lines or bytes) | exit stock / patched | cap hit |
|---|---|---|---|---|---|---|---|---|
| -b (newest boot) | 47.45 | 6.54 | 7.3x | 47.6 | 6.4 | 630000 (same) | 0 / 0 | no |
| -k -b all | 20.22 | 3.92 | 5.2x | 20.2 | 2.5 | 126439 (same) | 0 / 0 | no |
| apport: --quiet -b -a --system | 23.61 | 2.91 | 8.1x | 23.7 | 3.0 | 480000 (same) | 0 / 0 | no |
| sos: --disk-usage | 0.01 | 0.01 | - | 0.0 | 0.0 | 1 (same) | 0 / 0 | no |
| sos: --list-boots | 0.06 | 0.24 | - | 0.1 | 0.1 | 8 (same) | 0 / 0 | no |
| sos full: --no-pager --reverse (first 100 MB) | 220.20 | 19.59 | 11.2x | 220.4 | 19.9 | 104857600 (same) | 141 / 141 | no |
| sos this boot: --no-pager --boot --reverse (first 100 MB) | 48.78 | 7.13 | 6.8x | 49.1 | 7.4 | 104857600 (same) | 141 / 141 | no |
| sos last boot: --no-pager --boot -1 --reverse (first 100 MB) | 48.66 | 7.62 | 6.4x | 49.0 | 7.7 | 104857600 (same) | 141 / 141 | no |
| -b all (full read) | 907.79 | 83.75 | 10.8x | 908.4 | 84.5 | 4188006 (same) | 0 / 0 | no |

### sys-100

| query | stock wall s | patched wall s | speed-up | stock cpu s | patched cpu s | output (lines or bytes) | exit stock / patched | cap hit |
|---|---|---|---|---|---|---|---|---|
| -b (newest boot) | 37.53 | 4.64 | 8.1x | 37.7 | 4.5 | 480000 (same) | 0 / 0 | no |
| -k -b all | 43.87 | 7.90 | 5.6x | 44.0 | 5.5 | 191997 (same) | 0 / 0 | no |
| apport: --quiet -b -a --system | 36.58 | 3.39 | 10.8x | 36.8 | 3.5 | 480000 (same) | 0 / 0 | no |
| sos: --disk-usage | 0.01 | 0.01 | - | 0.0 | 0.0 | 1 (same) | 0 / 0 | no |
| sos: --list-boots | 0.08 | 0.35 | - | 0.1 | 0.2 | 11 (same) | 0 / 0 | no |
| sos full: --no-pager --reverse (first 100 MB) | 233.77 | 19.63 | 11.9x | 234.3 | 19.9 | 104857600 (same) | 141 / 141 | no |
| sos this boot: --no-pager --boot --reverse (first 100 MB) | 37.87 | 4.34 | 8.7x | 38.2 | 4.6 | 81675309 (same) | 0 / 0 | no |
| sos last boot: --no-pager --boot -1 --reverse (first 100 MB) | 37.87 | 4.40 | 8.6x | 38.2 | 4.6 | 81666085 (same) | 0 / 0 | no |
| -b all (full read) | 1098.30 | 93.11 | 11.8x | 1100.0 | 94.2 | 4800009 (same) | 0 / 0 | no |


## Notes on single numbers

* The first single run of `--list-boots` on the 100-file sets showed patched slower (0.35 s against 0.08 s at sys-100; 0.24 s
  against 0.06 s at mixed-100). Ten alternating repetitions per build (`listboots-4F.sh`, `4F-listboots.tsv`) show no such
  difference: sys-100 stock 0.081 s mean (0.078 to 0.087), patched 0.076 s (0.074 to 0.079); mixed-100 stock 0.088 s
  (0.059 to 0.330, one outlier), patched 0.058 s (0.055 to 0.060); sys-50 0.035 against 0.028 s; sys-25 0.015 against 0.012 s.
  The first values were a cold-cache first run after copying the data. All repetitions exited 0.
* The sos `--disk-usage` and `--list-boots` queries are below 0.5 s in both builds at every size; no speed-up is claimed for them.

## Structural check: system calls per printed line (`strace -c -f`, 100 files, host)

`strace-4F.sh` runs `journalctl --directory=<copy> --no-pager -o cat -n N` (N = 3000 and 30000 lines printed, so both builds
print the same lines) under `strace -c -f`; the fstat family is `fstat`, `newfstatat`, `statx`, `fstatfs`; per-run tables are
in `strace/`, the summary in `4F-strace.tsv`.

| set | build | lines printed | fstat-family calls | all syscalls | fstat-family per printed line |
|---|---|---|---|---|---|
| sys-100 | stock | 3000 | 1,680,174 | 1,682,527 | 560 |
| sys-100 | stock | 30000 | 16,800,174 | 16,803,407 | 560 |
| sys-100 | patched | 3000 | 355 | 2,708 | 0 |
| sys-100 | patched | 30000 | 355 | 3,588 | 0 |
| mixed-100 | stock | 3000 | 1,620,185 | 1,625,711 | 540 |
| mixed-100 | stock | 30000 | 16,200,185 | 16,255,759 | 540 |
| mixed-100 | patched | 3000 | 355 | 5,881 | 0 |
| mixed-100 | patched | 30000 | 355 | 55,929 | 0 |

Stock performs about 5.4 to 5.6 fstat-family calls per file per printed line (540 to 560 at 100 files), growing linearly with
the lines printed; the patched build's 355 calls are a constant (about 3.5 per file, from opening the files) and do not grow
with the output. This is the structure of the 2025 SLES report (41 million `fstat` calls in one run).
