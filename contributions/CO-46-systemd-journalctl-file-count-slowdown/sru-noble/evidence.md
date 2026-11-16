# Measurements: journalctl on noble with and without the two v256 commits

Everything here was measured on one machine in November 2026. Only numbers are given. The journal
contents are not shared, but the raw per-run records can be provided on request.

## Machine and method

| item | value |
|---|---|
| machine | Ubuntu 24.04.5, AMD Ryzen 7 5825U (8 cores, 16 threads), 30 GB RAM, NVMe, ext4 |
| installed systemd | 255.4-1ubuntu8.18 |
| its journal | 479 files, 15.9 GB; journald settings not the default: `SystemMaxUse=16G`, `SystemMaxFiles=1000` |
| binaries | **8.18**: the 255.4-1ubuntu8.18 source package (`dpkg-source -x`, all Ubuntu patches) built with meson, release mode. **patched**: the same tree plus 99e6f682d3 and 51b2bcf835 applied with `patch -p1`. Run from a build directory with their own libsystemd-shared. Nothing was installed |
| where | on the host, outside any container. Each run under `nice -n 19` and `ionice -c 3`, one at a time; other work ran on the machine, so absolute rates carry some noise |
| synthetic journals | K archived files of 2 000 entries each, 5 files per boot, one machine ID, written by systemd-journal-remote |
| real journal | the newest K files of the machine's journal, passed as `--file=`, read only |
| one run | `journalctl -o short --no-pager` on the K files, stopped after the first 200 000 lines or 45 s (synthetic), or 300 000 lines or 60 s (real). Lines/s is lines over wall time; median of 3 runs |

## 1. Output rate against the number of files (host)

Lines per second.

**Synthetic files**

| files | 8.18 | patched | patched / 8.18 |
|---|---|---|---|
| 25 | 19 218 | 178 586 | 9.3 |
| 50 | 8 269 | 123 012 | 14.9 |
| 100 | 4 563 | 84 104 | 18.4 |
| 200 | 1 395 | 34 043 | 24.4 |
| 400 | 633 | 13 787 | 21.8 |
| 800 | 308 | 5 603 | 18.2 |

**The machine's own journal (newest K files)**

| files | 8.18 | patched | patched / 8.18 |
|---|---|---|---|
| 25 | 29 194 | 201 342 | 6.9 |
| 50 | 19 438 | 190 355 | 9.8 |
| 100 | 11 361 | 133 097 | 11.7 |
| 200 | 5 847 | 119 474 | 20.4 |
| 400 | 2 885 | 71 685 | 24.8 |
| 479 (all) | 2 292 | 56 894 | 24.8 |

**System calls.** In a separate run on synthetic files at K = 100, strace counted 477.8 system calls
per printed line for 8.18 and 0.1 for the patched build. Almost all of 8.18's calls are fstat().

**Growth.** Fit time ∝ K^b for K ≥ 50, where 2 means quadratic and 1 linear:

| | synthetic | real journal |
|---|---|---|
| 8.18 | 2.23 | 1.95 |
| patched | 2.15 | 1.50 |

The backport removes the system calls, not the per-file comparison. Each entry still compares the
current position of every open file, so the cost still grows with the number of files. This is
upstream issue #31486 and is not part of this request.

## 2. Everyday queries (host, the machine's journal, 479 files)

Each query was capped at 120 s and run twice; the median is shown. The journal is live and grows
during the runs, so where a cap was hit, rates are compared, not line counts.

| query | 8.18 | patched | gain |
|---|---|---|---|
| `journalctl -b` | capped at 120 s, 2 678 lines/s | 4.5 M lines in 48.2 s (94 000 lines/s) | 35x (rate); 8.18 would need about 28 min |
| `journalctl -k -b` | capped, 2 568 lines/s | 5.0 M lines in 53.9 s | 36x (rate); about 33 min |
| `journalctl -b -1` | capped | capped | 27x (rate) |
| `journalctl --since "1 day ago"` | capped | capped | 27x (rate) |
| `journalctl -g <rare word>`, newest 25 files | 42.8 s | 2.33 s | 18x |
| `journalctl -u systemd-logind.service` | 0.29 s | 0.07 s | 4.3x |
| `journalctl -n 100` | 0.32 s | 0.10 s | 3.2x |
| `journalctl --list-boots` | 0.18 s | 0.15 s | 1.2x |

- Queries that walk entries in order across files gain most: `-b`, `-k -b`, `--since`, `-g` and
  export.
- Queries that use the indexes or read only file tails gain less: `-u`, `-n` and `--list-boots`.

The same queries on 800 synthetic files:

| query | 8.18 | patched | gain |
|---|---|---|---|
| `-b`, 10 000 entries | 7.07 s | 0.22 s | 33x |
| `-k -b`, 10 000 entries | 6.81 s | 0.21 s | 32x |
| `--list-boots` | 4.35 s | 0.56 s | 7.7x |
| `-n 100` | 0.52 s | 0.11 s | 4.7x |

## 3. The same runs in a container

These figures are for comparison only. On the same machine, inside a container, 8.18 ran 2 to 5 times
slower than on the host, while the patched build ran at the same speed. A container makes each
system call dearer, and 8.18 makes about 478 of them per line. The gains therefore look larger in a
container, so the host figures above are the ones to quote.

| files | synthetic 8.18 / patched | gain | real journal 8.18 / patched | gain |
|---|---|---|---|---|
| 25 | 6 843 / 177 319 | 25.9x | 14 714 / 227 017 | 15.4x |
| 100 | 899 / 68 729 | 76.5x | 4 493 / 146 994 | 32.7x |
| 400 | 229 / 13 471 | 58.8x | 1 251 / 77 419 | 61.9x |

## 4. The reproducer (fresh ubuntu:24.04 container, unprivileged user, network off)

The script and its test are in `reproducer/`. The output below is `reproducer/output.txt`:
1 000 entries per file, at most 100 000 lines or 40 s per run, median of 3 runs.

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
52 entries, identical. No temporary directory was left behind.

## 5. Same output

The patched build printed byte-identical `-o export` output to 8.18 in 36 comparisons on synthetic
data and 2 on the machine's own journal.

**Synthetic data** came in two sets: 25 archived files in sequence, and archived files whose time
ranges interleave. Each set was read with:
 - everything, forward and with `-r`;
 - `-n 500`, `-k`, a `_BOOT_ID=` match and `-b -3`;
 - `--since`/`--until`, and `-r --since`;
 - `--reverse -n 3000` and `--lines=+3000`;
 - `--cursor` and `--after-cursor`, forward and reverse, at two positions.

**The machine's journal:** the newest 25 files, the first 600 000 export lines, forward and with `-r`.

**The built package (255.4-1ubuntu8.20 test build of 8.19 plus the two commits),** installed over
8.18 in a fresh ubuntu:24.04 container, was compared with stock 8.18 and stock 8.19 on four synthetic
sets:
 - plain archived files;
 - 12 boots whose files overlap in time;
 - two machine IDs;
 - the reproducer's files.

Each set was read with 14 kinds of query, 112 comparisons in all, and all were identical.

**A file still being written,** fed through systemd-journal-remote while `journalctl -f` read it with
8.18, 8.19 and the patched build. The followed output was identical (21 643 entries), and so was the
final read (24 500).

`journalctl --verify` on the reproducer's 400 files reported no failure. With the installed patched
package, the reproducer gave 189 958 lines/s at 25 files and 11 567 at 400.

Not tested: entries arriving through a running journald, because the container has no systemd as
PID 1. Step 5 of the bug's Test Plan covers that on a real machine.
