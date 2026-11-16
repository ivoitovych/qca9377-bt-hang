# The journalctl backport on the bare host: rates, common queries, and a reproducer (2026-11-16)

**What this page is for.** An Ubuntu 24.04 stable-update request (SRU) for the two 2024 upstream commits
(`99e6f682d3`, `51b2bcf835`) needs numbers a reader can trust. The earlier page
([`../journalctl-file-scaling-verify-2026-11-15/`](../journalctl-file-scaling-verify-2026-11-15/README.md))
measured in a container. This page repeats the measurements **directly on the machine where the slowdown was
found**, adds the queries people actually run, and ships a script a maintainer can run in minutes.

**The short version.**
- **The speed-up to quote is the host's.** On the host the shipped binary (a) is 2 to 5 times faster than in
  the container, while the backport (b) runs at the same speed in both. So the gain of b over a is **9 to 24
  times on synthetic journals and 7 to 25 times on the laptop's real journal** (the container showed 26 to 77
  and 15 to 65). The container's 7 to 9 times slowdown of a that the coordinator expected did not appear; it was
  2 to 5 times (section 2).
- **The quadratic growth is there on the host too.** Exponent 2.15 (b, synthetic), 1.50 (b, real journal), the
  same as in the container (section 2).
- **Common queries:** the ones that read many entries (`-b`, `-k -b`, `--since`, `-g`) are 26 to 36 times
  faster with b; the ones that do not (`-u`, `-n 100`, `--list-boots`) gain 1.2 to 4.3 times because their cost
  is opening the files (section 3).
- **A reproducer** needs no root, installs nothing and writes only into one `mktemp -d` directory (section 4).

## 1. Setup

| item | value |
|---|---|
| machine | the laptop: 16 cores, Ubuntu 24.04.5, systemd `255.4-1ubuntu8.18` installed |
| host runs | the binaries of the earlier page (a, b, g), run **outside any container** from `<work dir>/bins/<variant>/`, each with `LD_LIBRARY_PATH` pointing at its own `libsystemd-shared`. Every library they need is present on the host (`ldd` resolves all of them), so no workaround was needed. Nothing was installed or replaced; `/usr/bin/journalctl` and the system's `libsystemd-shared` were never touched |
| container runs | the same binaries in the build container, the real journal mounted read-only |
| priority | every run: `nice -n 19` and `ionice -c 3`, one run at a time, no parallel jobs. Another experiment was running on the machine, so absolute rates carry some noise |
| synthetic journals | as before: K = 25 ... 800 archived files of 2 000 entries each, 5 files per boot, one machine ID; the first 200 000 lines or 45 s, 3 runs, median |
| real journal | the newest K of the laptop's journal files (K = 25 ... 400 and all, 479 now), `-o short`, the first 300 000 lines or 60 s, 3 runs on the host (2 in the container), median. Read only, with `--file=`; not copied anywhere (see section 5) |
| recorded per run | wall time, lines, lines/s, K, variant, host or container, and the system's IO pressure (`/proc/pressure/io`, "some" total stall in microseconds during the run) |

Variants: a = 255.4-1ubuntu8.18 as shipped; b = a + the two 2024 commits; g = the priority-queue prototype on
upstream main (details on the earlier page).

## 2. Host against container, side by side

Lines per second (median of runs); `b/a` is b's rate over a's. Full output: `data/host-vs-container.txt`.

**Synthetic journals (2 000 entries per file)**

| env | variant | 25 | 50 | 100 | 200 | 400 | 800 |
|---|---|---|---|---|---|---|---|
| host | a | 19 218 | 8 269 | 4 563 | 1 395 | 633 | 308 |
| host | b | 178 586 | 123 012 | 84 104 | 34 043 | 13 787 | 5 603 |
| host | g | 280 921 | 284 926 | 304 414 | 269 542 | 231 214 | 205 761 |
| container | a | 6 843 | 2 976 | 899 | 407 | 229 | 113 |
| container | b | 177 319 | 121 518 | 68 729 | 28 003 | 13 471 | 5 956 |
| container | g | 287 379 | 308 670 | 278 164 | 244 499 | 215 517 | 205 339 |
| host | **b / a** | **9.3** | **14.9** | **18.4** | **24.4** | **21.8** | **18.2** |
| container | b / a | 25.9 | 40.8 | 76.5 | 68.7 | 58.8 | 52.5 |
| | a, host / container | 2.8 | 2.8 | 5.1 | 3.4 | 2.8 | 2.7 |
| | b, host / container | 1.0 | 1.0 | 1.2 | 1.2 | 1.0 | 0.9 |

**The laptop's real journal (newest K files; "all" = 479 files on the host, 481 in the container run)**

| env | variant | 25 | 50 | 100 | 200 | 400 | all |
|---|---|---|---|---|---|---|---|
| host | a | 29 194 | 19 438 | 11 361 | 5 847 | 2 885 | 2 292 |
| host | b | 201 342 | 190 355 | 133 097 | 119 474 | 71 685 | 56 894 |
| host | g | 321 199 | 309 278 | 282 486 | 305 188 | 292 113 | 294 985 |
| container | a | 14 714 | 8 410 | 4 493 | 2 271 | 1 251 | 1 072 |
| container | b | 227 017 | 195 567 | 146 994 | 119 888 | 77 419 | 69 382 |
| container | g | 272 661 | 278 789 | 299 107 | 311 733 | 286 938 | 286 425 |
| host | **b / a** | **6.9** | **9.8** | **11.7** | **20.4** | **24.8** | **24.8** |
| container | b / a | 15.4 | 23.3 | 32.7 | 52.8 | 61.9 | 64.8 |
| | a, host / container | 2.0 | 2.3 | 2.5 | 2.6 | 2.3 | 2.1 |
| | b, host / container | 0.9 | 1.0 | 0.9 | 1.0 | 0.9 | 0.8 |

**Exponents** (time to read everything ~ K^b over K >= 50; 2 = quadratic, 1 = linear)

| | host synthetic | container synthetic | host real | container real |
|---|---|---|---|---|
| a | 2.23 | 2.14 | 1.95 | 1.91 |
| b | **2.15** | 2.11 | **1.50** | 1.45 |
| g | 1.13 | 1.15 | 1.01 | 0.99 |

**Reading it.**
- **a is the variable one.** It makes about 480 `fstat()` calls for every printed line, and the container makes
  each system call 2 to 5 times dearer than the host. b and g make almost none, so they run at the same speed
  in both. That is why the quoted speed-up must be the host's.
- **The backport removes the system calls, not the growth.** On the host b's exponent is 2.15 on synthetic
  files and 1.50 on the real journal, as in the container. The real journal's exponent is lower because a fixed
  cost per entry (about 3.4 microseconds, g's value) dominates at small K; the part that grows with K is about
  0.03 microseconds per file per entry and, as the journal grows, takes over.
- **g (the prototype) is flat on the host too:** 3.1 to 3.5 microseconds per entry on the real journal at
  every K.
- **The 2026-11-14 table** (stock 255.4: 45 657 lines/s with 25 files) was measured on a different selection of
  files, at `nice -n 10` and `ionice -c 2`, with a journal that has since changed. This run gives 29 194 for the
  newest 25 files and 19 218 for the synthetic 25. The figures of this page are internally comparable; the old
  table is not directly.
- **IO pressure** (`data/host-vs-container.txt`, last block): the "some" stall during a runs is 2 to 22 times that
  of b runs, and g's is lower still (for example 716 ms against 33 ms over a 60 s run on the full real journal), consistent with
  a's many `fstat()` calls; it is a system-wide figure and noisy, so it is recorded, not interpreted. The runs
  were CPU-bound.

## 3. Common queries (a and b, host and container)

- **Real journal:** all 479 files (the host table; 481 in the container run), a time cap of 120 s per run, 2 runs, median.
- **Synthetic:** the 800-file set.
- **`speed-up`:** the ratio of times when both finished; otherwise (a cap was hit) the ratio of lines per second,
  marked `rate`.
- **Live journal:** it grows while the queries run (the current boot holds millions of lines and gains thousands
  a minute), so line counts differ between a and b and between host and container; they matter only for rates.
- **The `-u` unit** is a generic system unit (`systemd-logind.service`). The `--since` time is one day before now,
  because the journal's newest entry is current. On the synthetic set, `--since` is a time inside its range, so it covers
  nearly all of it; `-u` finds nothing there (the cost of an empty match).

Host (authoritative):

| set | query | a time s | b time s | a lines | b lines | capped a/b | speed-up |
|---|---|---|---|---|---|---|---|
| real | `-b` | 120.0 | 48.2 | 321 336 | 4 535 424 | yes / no | 35x (rate) |
| real | `-b -1` | 120.0 | 120.0 | 313 888 | 8 317 266 | yes / yes | 27x (rate) |
| real | `-u <unit>` | 0.29 | 0.07 | 38 | 38 | no / no | 4.3x (time) |
| real | `--since "1 day before end"` | 120.0 | 120.0 | 268 576 | 7 160 422 | yes / yes | 27x (rate) |
| real | `-n 100` | 0.32 | 0.10 | 100 | 100 | no / no | 3.2x (time) |
| real | `-k -b` | 120.0 | 53.9 | 308 170 | 5 011 216 | yes / no | 36x (rate) |
| real | `--list-boots` | 0.18 | 0.15 | 3 | 3 | no / no | 1.2x (time) |
| real | `-g <rare word>` (full scan) | 120.0 | 120.0 | 0 | 0 | yes / yes | not finished |
| real, newest 25 files | `-g <rare word>` | 42.8 | 2.33 | 1 | 1 | no / no | **18x (time)** |
| synthetic 800 | `-b` | 7.07 | 0.22 | 10 000 | 10 000 | no / no | 33x (time) |
| synthetic 800 | `-b -1` | 7.38 | 0.22 | 10 000 | 10 000 | no / no | 33x (time) |
| synthetic 800 | `-u <unit>` (no match) | 0.46 | 0.07 | 1 | 1 | no / no | 6.3x (time) |
| synthetic 800 | `--since` | 120.0 | 120.0 | 30 963 | 866 212 | yes / yes | 28x (rate) |
| synthetic 800 | `-n 100` | 0.52 | 0.11 | 100 | 100 | no / no | 4.7x (time) |
| synthetic 800 | `-k -b` | 6.81 | 0.21 | 10 000 | 10 000 | no / no | 32x (time) |
| synthetic 800 | `--list-boots` | 4.35 | 0.56 | 161 | 161 | no / no | 7.7x (time) |
| synthetic 25 | `-g <rare word>` | 2.29 | 0.13 | 5 | 5 | no / no | 17x (time) |

What a run costs when it does not finish: for the real journal `-b` b needed 48 s for 4.5 million lines; a ran at
2 678 lines/s, so it would take about 28 minutes for the same output (`-k -b`: 54 s against about 33 minutes).

Container (for comparison; the shipped binary's figures are the ones the container distorts), full list in
`data/queries-summary.txt`:

| set | query | a time s | b time s | speed-up |
|---|---|---|---|---|
| real | `-b` | 120.0 | 97.1 | 84x (rate) |
| real | `-u <unit>` | 0.38 | 0.07 | 5.2x (time) |
| real | `-n 100` | 0.84 | 0.10 | 8.8x (time) |
| real | `-k -b` | 120.0 | 105.3 | 91x (rate) |
| real | `--list-boots` | 76.1 | 0.15 | not comparable, see below |
| synthetic 800 | `-b` | 13.8 | 0.19 | 72x (time) |
| synthetic 800 | `-n 100` | 1.10 | 0.09 | 12.5x (time) |
| real, newest 25 files | `-g <rare word>` | 108.1 | 2.25 | 48x (time) |

**Which queries do not care about the number of files (much).**
- **`--list-boots`** reads the first and the last entry of each file: one visit per file, not one per entry.
  On the real journal it takes 0.15 to 0.18 s for both. (On the synthetic 800 files it costs 4.4 s for a,
  because its `fstat()` calls multiply with the 800 files.) In the container the first `a` run took 32 s and the second
  hit the 120 s cap with no output, against 0.18 s on the host; I cannot explain that, and treat it as a
  container artefact (an idle-class IO queue behind other work on the machine is my guess, not something I measured).
- **`-u <unit>`** and other matches use the journal's indexes, so the cost follows the number of matching entries
  (38 here), plus opening the files: 0.29 against 0.07 s.
- **`-n 100`** seeks to the end and prints 100 entries; it costs opening the files and reading their tails:
  0.32 against 0.10 s on the real journal.

**Which do.** Everything that walks entries in order across the files: `-b`, `-b -1`, `-k -b`, `--since` over
a large window, `-g` (a full scan), `-o export` of anything big. On the real journal a prints 2 600 to 2 700
lines/s against 93 000 to 94 000 for b.
- **Even a "narrow" query depends on the number of files** when the window is a boot: on the synthetic set `-b`
  prints 10 000 entries and still takes 7 s with a, because every entry costs a walk over all 800 files.
- **The `-g` full scan** on the 479-file real journal did not finish within 120 s for either binary (the
  journal holds more than the 8 million lines b reaches in that time), so its speed-up is measured on the
  newest 25 files: 18 times on the host.

## 4. The reproducer

`reproducer/journalctl-file-scaling-repro.sh JOURNALCTL [K...]`

- **What it does:** writes K synthetic journal files (1 000 entries each, archived, 5 per boot) with
  `systemd-journal-remote` from an export stream, in one `mktemp -d` directory, and prints the lines per second
  of the binary under test against K and the exponent.
- **Safe:** needs no root; installs nothing; does not read or write the system journal, `/var/log/journal` or
  journald; writes only inside its temporary directory, which it removes at the end; reads only with
  `journalctl --directory=<that directory>/...`. The only dependency is the package `systemd-journal-remote`
  (or `REMOTE=<path>`); the files are written without any daemon.
- **A binary to test is an argument**, so two can be compared without installing either:
  ```console
  $ ./journalctl-file-scaling-repro.sh /usr/bin/journalctl            # the archive's
  $ ninja -C build journalctl                                        # in a systemd source tree; nothing installed
  $ ./journalctl-file-scaling-repro.sh /path/to/tree/build/journalctl # the patched build
  ```
  A binary from a build tree finds its `libsystemd-shared-*.so` next to itself or in `<its directory>/src/shared`;
  the script puts those on `LD_LIBRARY_PATH` for that one process only.
- **Tuning:** `K` as arguments (default `25 50 100 200 400`), `ENTRIES`, `LINES`, `SECS`, `RUNS`.

**Tested** in a fresh `ubuntu:24.04` container as the unprivileged user `tester` (uid 1001), network disabled,
with the archive's `systemd` and `systemd-journal-remote` installed (`reproducer/test/Dockerfile`), against
the archive's `/usr/bin/journalctl` (255.4-1ubuntu8.18) and against variant b mounted read-only
(`reproducer/test/inside-repro-test.sh`, `reproducer/test/output.txt`). The runs take about 6 minutes in
total (the stock binary dominates: it reaches the 40 s cap from K = 100).

```
################ /usr/bin/journalctl   (stock 255.4-1ubuntu8.18)
     K      lines    seconds      lines/s       us/entry
    25      25004       2.92         8564          116.8
    50      50009      12.79         3910          255.7
   100      56432      40.01         1411          708.9
   200      21737      40.01          543         1840.4
   400      10576      40.01          264         3782.9
exponent b of (time to read everything) ~ K^b, K >= 50: 2.30   (2 = quadratic, 1 = linear)

################ /bins/b/journalctl   (the two 2024 commits)
     K      lines    seconds      lines/s       us/entry
    25      25004       0.12       207589            4.8
    50      50009       0.35       140990            7.1
   100     100000       1.11        89837           11.1
   200     100000       2.94        34043           29.4
   400     100000       6.68        14962           66.8
exponent b of (time to read everything) ~ K^b, K >= 50: 2.11   (2 = quadratic, 1 = linear)
```

**Safety check.** Before and after both runs the test lists path, type, size and mtime of everything under
`/var/log`, `/run/log` (absent) and `/etc/systemd`, and of what is inside `/tmp` and `/var/tmp`:

```
identical: 52 entries (path type size mtime), no difference
journal directories present after: ls: cannot access '/run/log/journal': No such file or directory /var/log/journal
leftover scaling directories in /tmp: 0
```

(`/var/log/journal` is the empty directory the `systemd` package creates in the image; it is unchanged.)
The first test run reported a difference: `/tmp`'s own mtime, because the script's temporary directory is
created and removed directly in it. The check was refined to list what is inside `/tmp`; the first output is
kept as `reproducer/test/output-first-run-snapshot-too-strict.txt`.

## 5. What could not be done, and why

- **No copy of the real journal.** The brief of this work forbids copying the journal's entries into the work
  area, so the real-journal numbers come from `--file=` reads of the original files, read only. The journal is
  live and rotates often (the newest file is renamed, old ones are vacuumed), so a file list made
  earlier can name a file that is gone: the first host runs of the "all files" rows, and the first host
  real-journal query run, failed at once with "Failed to open files". The scripts now list the files just before
  each run and start again if one vanished; the failed attempts are kept as
  `data/host-rates-run1.tsv` (rows with 0 lines) and `data/queries-host-real-first-attempt-rotated-files.tsv`.
  Sets of files differ by a few files between runs, so "all" is 478 to 480 files.
- **`-g` over all files** did not finish in 120 s for either binary; measured on the newest 25 files instead.
- **The container's `--list-boots` anomaly** (section 3) is unexplained.
- **Not measured on the host:** the 255.4 + 2024 + 2026 variant (c) and the boot-order-cache variants (d, f), and
  main (e); they are in the container data of the earlier page. The queries used 2 runs each, not 3.
- **The reproducer was tested with variant b copied out of the build area,** not with a fresh in-tree build of a
  source tree; the instruction for that is in the script's header and above.

## 6. Exact commands

`<work dir>` is the scratch directory, `<repo>` this repository; the scripts in `scripts/` use `$WORKDIR` and
`$REPO` and expect to be copied to `<work dir>/bin/`. Binaries are in `<work dir>/bins/<variant>/`, built as on the
earlier page.

```console
# host runs: synthetic and real journal, variants a b g, one run at a time at the lowest priority
$ <work dir>/bin/run-host.sh
$ <work dir>/bin/run-host-all.sh                # the "all files" rows again, with the file list made per run
# common queries
$ WHATS=real <work dir>/bin/run-queries.sh host     # (the synthetic half runs first when WHATS is not set)
$ <work dir>/bin/run-rest3.sh                       # container queries, the -g runs on 25 files, the reproducer test
# analysis
$ python3 -I <work dir>/bin/analyse-sidebyside.py <container synthetic tsv> <container real tsv> <host tsv> <host all tsv>
$ python3 -I <work dir>/bin/analyse-queries.py <host queries tsv> <container queries tsv>
# the reproducer, on any machine
$ ./reproducer/journalctl-file-scaling-repro.sh /usr/bin/journalctl
```

Per-run records (columns: env, variant, set, K, run, lines, seconds, IO stall) are `data/host-rates-run1.tsv` and
`data/host-rates-real-all-rerun.tsv`; query records (env, variant, set, query, lines, seconds, capped) are
`data/queries-*.tsv`.

## Files

| file | what |
|---|---|
| `data/host-vs-container.txt` | the side-by-side tables, with IO pressure |
| `data/host-*-summary.txt` | host medians, exponents, cost per entry |
| `data/queries-summary.txt`, `data/queries-g-25-files-summary.txt` | the query tables |
| `data/container-*-rates.tsv` | the container runs of the earlier page |
| `reproducer/` | the script, and `test/` with the container recipe and the outputs |
| `scripts/` | measurement and analysis scripts |
