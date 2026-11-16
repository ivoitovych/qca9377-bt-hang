# Measurements: journalctl on noble with and without the two v256 commits

Everything here was measured in November 2026. Only numbers are given; journal messages are not
shared. Raw records (commands, termination conditions, per-run rows) are in the branch
`research/journalctl-file-scaling` of the repository this request was prepared in, under the paths
named for each section. "Stock" is 255.4-1ubuntu8.19 from noble-proposed (downloaded; hashes in
`results/journalctl-noble-sru-verification-2026-11-16/scripts/PACKAGES.txt`); "patched" is the exact
test packages built from 8.19 plus 99e6f682d3 and 51b2bcf835 (version 255.4-1ubuntu8.20, same file). Where
an older section below used 8.18, it says so.

## 1. Headline: completed host runs on frozen copies (stock 8.19 against patched)

Path: `results/journalctl-noble-sru-verification-2026-11-16/4F-host-headline-numbers/` (`README.md`,
raw rows `4F.tsv`, scripts `host-4F.sh`, `prep-4F.py`).

| item | value |
|---|---|
| where | the host itself, no container; the unpacked packages run with `LD_LIBRARY_PATH`, nothing installed |
| data | independent copies (`cp`) of a synthetic journal modelled on a default noble install: `mixed-N` = the N newest files of system and user files together, `sys-N` = the N newest system files; N = 25, 50, 100 |
| load | one run at a time, `nice -n 19 ionice -c 3`; one run per query and build |
| termination | each query ended by itself; cap 7200 s per run, 300 s for the sos commands (sos's own limit); no cap was hit; exit status 141 is SIGPIPE from the 100 MB cut |

`journalctl -b all` (full read), wall seconds:

| files | mixed stock | mixed patched | x | system-only stock | system-only patched | x | lines (mixed / system) |
|---|---|---|---|---|---|---|---|
| 25 | 42.85 | 8.33 | 5.1 | 54.56 | 10.51 | 5.2 | 1 038 001 / 1 200 002 |
| 50 | 195.39 | 24.24 | 8.1 | 249.61 | 30.17 | 8.3 | 2 094 003 / 2 400 004 |
| 100 | 907.79 | 83.75 | 10.8 | 1098.30 | 93.11 | 11.8 | 4 188 006 / 4 800 009 |

Other queries at 100 files (wall seconds, stock / patched): `-b` mixed 47.45 / 6.54, system 37.53 / 4.64;
`-k -b all` mixed 20.22 / 3.92, system 43.87 / 7.90; apport's `--quiet -b -a --system` mixed 23.61 / 2.91,
system 36.58 / 3.39; sos's `--no-pager --reverse` (first 100 MB) mixed 220.20 / 19.59, system 233.77 /
19.63; sos's `--boot --reverse` mixed 48.78 / 7.13, system 37.87 / 4.34; `--boot -1 --reverse` mixed
48.66 / 7.62, system 37.87 / 4.40. `--disk-usage` and `--list-boots` take under 0.5 s in both builds and
are not claimed to gain: ten alternating runs per build of `--list-boots` (`4F-listboots.tsv`) gave
sys-100 0.081 s stock, 0.076 s patched, and a first single run that looked slower patched was a cold-cache
effect. Output line or byte counts were equal for every pair; all exit statuses as expected.

**Structural check** (`strace -c -f`, host, 100 files, `-o cat -n N`; `4F-strace.tsv`, `strace/`):

| set | build | lines printed | fstat-family calls | all system calls | fstat-family per printed line |
|---|---|---|---|---|---|
| sys-100 | stock | 3 000 | 1 680 174 | 1 682 527 | 560 |
| sys-100 | stock | 30 000 | 16 800 174 | 16 803 407 | 560 |
| sys-100 | patched | 3 000 | 355 | 2 708 | 0 |
| sys-100 | patched | 30 000 | 355 | 3 588 | 0 |
| mixed-100 | stock | 3 000 | 1 620 185 | 1 625 711 | 540 |
| mixed-100 | stock | 30 000 | 16 200 185 | 16 255 759 | 540 |
| mixed-100 | patched | 3 000 | 355 | 5 881 | 0 |
| mixed-100 | patched | 30 000 | 355 | 55 929 | 0 |

(fstat family: fstat, newfstatat, statx, fstatfs.) A time ratio is a property of one machine; this count
is not.

## 2. Equivalence and safety checks on the exact packages (stock 8.19 against patched)

Each comparison checks that both journalctl runs exit 0, that the output is not empty where output is
expected, and then compares sha256. Paths are under `results/journalctl-noble-sru-verification-2026-11-16/`.

| check | path | result |
|---|---|---|
| frozen copies: 4 fixtures (30 + 30 synthetic files, a 25-file system+user model, 12 archived files of a real journal), 9 queries each: `-o export` forward and `-r`, `--list-boots`, `-b`, `-k -b`, `-u`, `-n 100`, `-n 100 -r`, `-o export -n 100` | `4A-frozen-dataset-equivalence/` (names and sha256 of the copies in `FIXTURE-SHA256.txt`; the real-journal copies were deleted afterwards) | 36 of 36 identical |
| booted noble guest (QEMU/KVM, noble cloud image), journald writing and rotating (`SystemMaxFileSize=1M`, three `journalctl --rotate` per phase), two numbered streams of 24 000 lines (system service and user session), concurrent `journalctl -f` and a later full read; stock phase, then the patched packages installed over it | `4C-booted-noble-vm/` | every number once and in order in both readers, in both phases (8 of 8 stream/reader results); `journalctl --verify` 38 of 38 and 76 of 76 files; final static journal identical in `-o export`, `-o export -r`, `-o cat -a` |
| older format: 12 files written by systemd 249 (header_size 256, no `tail_entry_offset`), a mixed set (6 old, 6 new) and a new-format set; 7 queries each | `4D-old-journal-format/` | 21 of 21 identical; under a debugger the patched build called `journal_file_read_tail_timestamp` with header_size 256 on every call for the old files (264 calls), 96 old and 168 new for the mixed set |
| imported and merged journals: 3 originating machines, 6 boots with overlapping ranges, 24 files; 5 fixtures that vary the header machine ID (one receiver ID, the entries' IDs, unrelated IDs per file, swapped IDs) and the entry `_MACHINE_ID`; 9 queries each | `4E-imported-merged-journals/` | 45 of 45 identical |
| archived files removed under an open reader | `4B-archived-files-under-open-reader/` | section 3 |

**The "two machine IDs" fixture.** The fixture named `twomachines` that was used earlier (section 6)
varied only the entries' `_MACHINE_ID` (two values); every file header carried the one ID the
writer, systemd-journal-remote, gives it (receiver ID; measured: 1 distinct header ID, 2 distinct entry IDs,
40 files). It therefore did not exercise the case of different header IDs. The 4E fixtures do, and
document for each fixture how many distinct header IDs and entry IDs it holds.

**Order against the true order (4E).** `-o cat` output was compared with the entries' realtime order.
Where one header ID covers several entry machine IDs (the shape journal-remote produces), stock 8.19 does
not print the true order (5 adjacent inversions among 9 600 entries, longest displacement 1 999) and the
patched build prints exactly the same sequence. All other 4E fixtures print the true order in both. This
is the ordering defect that upstream ae940730c6 (v262) fixes; it exists without the two commits, and
ae940730c6 was deliberately not added. Equal output proves equivalence, not correct ordering.

## 3. Archived files removed while a reader has them open

Path: `4B-archived-files-under-open-reader/` (`README.md`, raw rows `4B.tsv`, `4B3.tsv`, `4B4.tsv`,
statistics `4B-stats.txt`, scripts `run4B.py`, `reader.c`, `inside-4B*.sh`).

Method: a fixture of 16 archived files (600 entries each), freshly copied for every run (own inodes);
a reader consumes slowly and, after a random number of entries (K), the victim files are removed. Readers:
`journalctl -o export` forward, with `-r`, and `-f`; and a small sd-journal program (forward, backward),
each linked against the build's own libsystemd. Removals: `unlink`; the deallocation of
`unlinkat_deallocate()` of v255 (open for writing, unlink, hole-punch with KEEP_SIZE); `truncate` (unlink,
then truncate to 0, the fallback of `unlinkat_deallocate()`). Victims: the file being read, the next one,
the one after that, the previous one. About 1 400 runs in all; one run ends when the reader exits or after
30 s without output (4 s for the follower).

| case | stock 8.19 | patched |
|---|---|---|
| `unlink`, any victim, any reader | exit 0, no lost entry | same |
| `journalctl -o export`, next file hole-punched (`dealloc`) | 22 of 26 runs exit 1, "Failed to iterate through journal: Bad message" | 20 of 26 |
| `journalctl -o export`, next file truncated | 20 of 26 exit 1 (same message) | 18 of 26 |
| `journalctl -o export -r`, next file truncated | 22 of 26 | 19 of 26 |
| sd-journal program, forward, current file truncated | 17 of 56 killed by SIGBUS | 21 of 56 (p = 0.55) |
| sd-journal program, backward, current file truncated | 10 of 26 | 4 of 26 (p = 0.12) |
| every other cell | no cell differs at p < 0.05 (Fisher exact test on failure counts, `4B-stats.txt`) | |

A first pass with six runs per cell had shown the forward program case as 0 of 6 failures for stock and 3 of 6
for patched; 56 runs per build showed it was timing. The failure there is the process killed by SIGBUS
(exit status -7): under gdb the patched build stops in `journal_file_read_tail_timestamp` at the read of the
mapped header (`sd-journal.c:2413` of the test source); the stock fault is in an unresolved function of
libsystemd (its debug symbols were not fetched). The library does not install a SIGBUS handler;
`journalctl` and journald do, and `journalctl` was not killed by SIGBUS in any run. Upstream 101b8633c2 is not
included in either build and was not tested. The `jc-follow` rows compare exit behaviour only: the harness stops
that reader after 4 s without output, so its entry counts are not complete in either build.

## 4. File counts at the default limits

Path: `4G-file-counts-at-defaults/README.md`. From the 255.4 source: `SystemMaxUse` 10% of the file system,
clamped to 1 MiB to 4 GiB (`journal-file.c`); `SystemMaxFileSize` that divided by 8, at most 128 MiB;
`SystemMaxFiles` 100, counted in `journal_directory_vacuum()` as `left = n_active_files + n_list - i`, so active
files count and only archived files are deleted; `MaxFileSec` one month; `SplitMode=uid`. At the size limits
alone a journal holds about 8 to 32 full-size files. The estimate that a default single-user desktop holds
roughly 10 to 40 files, and that 50 to 100 need many small files (unclean shutdowns, monthly rotation, hash-table
rotation, other users), is an estimate from those rules and public reports, not a measured population.
Public reports read: a server with 1 044 `user-*.journal` files (systemd-devel, 2024-02-01), a systemd 254
system with fewer than 20 files making 41 million fstat calls (2025-05), and a user raising
`SystemMaxFileSize=20G` to limit the number of files (2018-07). No count for an unmodified Ubuntu desktop was
found. The 479-file machine of sections 5 and 6 reaches its count through its own settings.

## 5. Earlier measurements: output rate and everyday queries (8.18 and patched, host)

These were made before the exact 8.19 packages existed, with 8.18 built from source, patched by applying the
two commits; they are kept as additional evidence. Records: `results/journalctl-file-scaling-host-2026-11-16/`
(`data/host-synthetic-summary.txt`, `data/host-real-summary.txt`, `data/queries-host.tsv`,
`data/queries-summary.txt`) and `results/journalctl-file-scaling-cause-2026-11-14/data/rates.tsv`.

| item | value |
|---|---|
| machine | Ubuntu 24.04.5, AMD Ryzen 7 5825U (8 cores, 16 threads), 30 GB RAM, NVMe, ext4 |
| installed systemd | 255.4-1ubuntu8.18 |
| its journal | 479 files, 15.9 GB; journald settings not the default: `SystemMaxUse=16G`, `SystemMaxFiles=1000` |
| binaries | **8.18**: the 255.4-1ubuntu8.18 source package built with meson, release mode. **patched**: the same tree plus the two commits. Run from a build directory with their own libsystemd-shared. Nothing was installed |
| synthetic journals | K archived files of 2 000 entries each, 5 files per boot, one machine ID, written by systemd-journal-remote |
| real journal | the newest K files of the machine's journal, passed as `--file=`, read only |
| one rate | `journalctl -o short --no-pager` on the K files, stopped after the first 200 000 lines or 45 s (synthetic), or 300 000 lines or 60 s (real); lines per second is lines over wall time; median of 3 runs. These are rates over a prefix of the output, not times for a complete read |

Lines per second:

| files | synthetic 8.18 | patched | x | real journal 8.18 | patched | x |
|---|---|---|---|---|---|---|
| 25 | 19 218 | 178 586 | 9.3 | 29 194 | 201 342 | 6.9 |
| 50 | 8 269 | 123 012 | 14.9 | 19 438 | 190 355 | 9.8 |
| 100 | 4 563 | 84 104 | 18.4 | 11 361 | 133 097 | 11.7 |
| 200 | 1 395 | 34 043 | 24.4 | 5 847 | 119 474 | 20.4 |
| 400 | 633 | 13 787 | 21.8 | 2 885 | 71 685 | 24.8 |
| 800 / 479 (all) | 308 | 5 603 | 18.2 | 2 292 | 56 894 | 24.8 |

The remaining cost per entry still grows with the number of files after the two commits, because each entry
still compares the position of every open file. That is the broader topic of upstream issue 31486 and is not
part of this request. (Earlier drafts fitted time against K with exponents; those fits come from capped or
prefix runs, are estimates, and are not used in the argument. The reference output of the reproducer
(section 7) still prints such an "exponent" line; read it the same way.)

Everyday queries on the 479-file machine (each capped at 120 s, run twice, median):

| query | 8.18 | patched |
|---|---|---|
| `journalctl -b` | capped at 120 s, 2 678 lines/s | 4.5 M lines in 48.2 s. The time 8.18 would need, about 28 min, is an estimate from its rate |
| `journalctl -k -b` | capped, 2 568 lines/s | 5.0 M lines in 53.9 s; estimate for 8.18 about 33 min |
| `journalctl -g <rare word>`, newest 25 files | 42.8 s | 2.33 s |
| `journalctl -u systemd-logind.service` | 0.29 s | 0.07 s |
| `journalctl -n 100` | 0.32 s | 0.10 s |
| `journalctl --list-boots` | 0.18 s | 0.15 s |

The journal is live and grew between runs, so `-b` and `-k -b` print different numbers of lines and the
two lines above should not be compared with each other; the headline in section 1 uses one frozen set. On
800 synthetic files: `-b` (10 000 entries) 7.07 s against 0.22 s, `--list-boots` 4.35 s against 0.56 s,
`-n 100` 0.52 s against 0.11 s.

## 6. Earlier same-output checks (8.18, 8.19, patched)

Records: `results/journalctl-file-scaling-verify-2026-11-15/` and `results/journalctl-sru-packaging-2026-11-16/`.
The patched build printed byte-identical `-o export` output to 8.18 in 36 comparisons on synthetic data and 2
on the machine's own journal (the newest 25 files, the first 600 000 export lines, forward and with `-r`).
Synthetic sets: 25 archived files in sequence, and archived files whose time ranges interleave; each read
forward and with `-r`, with `-n 500`, `-k`, a `_BOOT_ID=` match, `-b -3`, `--since`/`--until`, `-r --since`,
`--reverse -n 3000`, `--lines=+3000`, and `--cursor` and `--after-cursor`, forward and reverse, at two positions.
The built package (255.4-1ubuntu8.20) installed over 8.18 in a fresh ubuntu:24.04 container was compared with
stock 8.18 and stock 8.19 on four synthetic sets (plain, 12 overlapping boots, `twomachines` and the
reproducer's files), 14 kinds of query, 112 comparisons, all identical. A file still being written, fed
through systemd-journal-remote while `journalctl -f` read it, gave identical followed output (21 643 entries)
and final read (24 500). These do not replace section 2's checks on active journald, the archived-file
lifecycle, the older format and imported journals.

## 7. The same runs in a container (reproducibility information only)

On the same machine inside a container 8.18 ran 2 to 5 times slower than on the host while the patched build
ran at the same speed, so the gains look larger there (15 to 77 times). The cause of the slower baseline in
that container setup was not isolated, and these figures are not used in the Impact.

| files | synthetic 8.18 / patched | x | real journal 8.18 / patched | x |
|---|---|---|---|---|
| 25 | 6 843 / 177 319 | 25.9 | 14 714 / 227 017 | 15.4 |
| 100 | 899 / 68 729 | 76.5 | 4 493 / 146 994 | 32.7 |
| 400 | 229 / 13 471 | 58.8 | 1 251 / 77 419 | 61.9 |

**The reproducer (fresh ubuntu:24.04 container, unprivileged user, network off).** The script and its test
are in `reproducer/`; the output below is `reproducer/output.txt`: 1 000 entries per file, at most 100 000
lines or 40 s per run, median of 3 runs. Termination: the lines limit or the time limit, whichever comes
first; the "exponent" lines are fits to those capped runs, estimates, not measurements of a complete read.

```
stock /usr/bin/journalctl (255.4-1ubuntu8.18)
     K      lines    seconds      lines/s       us/entry
    25      25004       2.92         8564          116.8
    50      50009      12.79         3910          255.7
   100      56432      40.01         1411          708.9
   200      21737      40.01          543         1840.4
   400      10576      40.01          264         3782.9
exponent: 2.30

255.4-1ubuntu8.18 + 99e6f682d3 + 51b2bcf835
     K      lines    seconds      lines/s       us/entry
    25      25004       0.12       207589            4.8
    50      50009       0.35       140990            7.1
   100     100000       1.11        89837           11.1
   200     100000       2.94        34043           29.4
   400     100000       6.68        14962           66.8
exponent: 2.11
```

**Safety check of that test.** It records path, type, size and mtime of everything under /var/log,
/run/log and /etc/systemd, and of the contents of /tmp and /var/tmp, before and after both runs:
52 entries, identical. No temporary directory was left behind. `journalctl --verify` on the reproducer's
400 files reported no failure. With the installed patched package, the reproducer gave 189 958 lines/s at 25
files and 11 567 at 400.

`reproducer/compare-frozen.sh` (new) is the frozen-dataset comparison of the Test Plan; it was tested on a
30-file synthetic directory with stock 8.19 and the patched build: identical output files, exit 0.
