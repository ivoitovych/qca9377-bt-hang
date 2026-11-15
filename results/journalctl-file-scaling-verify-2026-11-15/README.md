# Does the 24.04 backport remove journalctl's quadratic slowdown? (2026-11-15)

**The question.** The 2024 upstream fix (`99e6f682d3`, `51b2bcf835`) removes the `fstat()` calls that
`journalctl` made for every open journal file on every entry. The earlier page
([`../journalctl-file-scaling-cause-2026-11-14/`](../journalctl-file-scaling-cause-2026-11-14/README.md))
measured a 5 to 11 times speed-up, but also saw the rate still halve each time the file count doubles.
If the per-entry cost is proportional to the number of files F, and F grows with the journal, then
reading N entries costs about N x F: still quadratic in the journal's size, with a smaller constant.

**The answer: yes, the quadratic growth stays.** With a fixed number of entries per file, the time to
read the whole journal grows as K^2.1 (K = number of files) for 24.04's systemd with the backport,
against K^2.1 without it. Only the constant changed. Upstream main and the earlier boot-order cache
shrink the constant again (K^2.2 and K^1.7 to K^1.9). A priority queue of the files, prototyped here
on main, brings it to K^1.15, which is linear plus a small start-up cost.

## 1. Setup

| item | value |
|---|---|
| machine | the laptop the slowdown was found on: 16 cores, Ubuntu 24.04, systemd `255.4-1ubuntu8.18` installed |
| where the code ran | a container (Ubuntu 24.04 image with systemd's build dependencies); `nice -n 19`, `--cpus=6`, builds with at most 6 jobs. A Bluetooth timing experiment ran on the machine at the same time, so absolute rates carry some noise |
| builds | `journalctl` and `systemd-journal-remote` only, `--buildtype=release`, never installed |
| source of 255.4 | `apt-get source systemd=255.4-1ubuntu8.18` (Ubuntu's own source, patches applied) |
| source of main | systemd git at `6bd4689` (the revision the earlier page used, 263~devel) |

Variants (the same letters are used in the data files):

| | what |
|---|---|
| a | 255.4-1ubuntu8.18 as shipped |
| b | a + the two 2024 commits (`0001`, `0002` of `patches/systemd/journal-file-scaling/`) |
| c | b + the two 2026 commits, adapted (`0003`, `0004`) |
| d | b + the boot-order cache for 255.4 (`boot-order-cache/*-255.4.patch`) |
| e | upstream main `6bd4689` |
| f | e + the boot-order cache for main |
| g | e + the priority-queue prototype of this page (`heap/0001-*.patch`) |

**Same output.** For b, c, d against a and for f, g against e (14 query kinds, export format, so every
field and the cursor are compared by SHA-256): 272 comparisons on synthetic sets and 18 on the laptop's
journal, none different (section 5).

## 2. Synthetic journals, a fixed number of entries per file

- **Files:** K = 25 ... 800 files of 2 000 entries each, written by `systemd-journal-remote` from
  generated entries by `scripts/make-journals-fixed.py` (the earlier page's generator, with the header
  state set to ARCHIVED = 2, as rotated files are; 5 files per boot, so K/5 boots; one machine ID).
  The total number of entries is N = 2000 K.
- **Run:** `journalctl --directory=<first K files> -o short --no-pager`, into a line counter; at most
  200 000 lines or 45 s: the whole journal was read for K <= 100, except by a (45 s cap from K = 100); for
  larger K only the first 200 000 lines. 3 runs, median of the rates. The cost per entry is the same whether the whole journal or its first 200 000 lines are read,
  because all K files are open for every entry, so the time to read everything is N x (cost per entry).
  The start-up (opening K files) is inside the measurement.

Lines per second:

| variant | 25 | 50 | 100 | 200 | 400 | 800 | exponent b |
|---|---|---|---|---|---|---|---|
| a, shipped | 6 843 | 2 976 | 899 | 407 | 229 | 113 | **2.14** |
| b, + 2024 commits | 177 319 | 121 518 | 68 729 | 28 003 | 13 471 | 5 956 | **2.11** |
| c, + 2026 pair | 174 839 | 117 935 | 66 689 | 27 394 | 13 399 | 5 988 | **2.09** |
| d, b + boot cache | 232 577 | 206 630 | 145 879 | 102 564 | 58 945 | 30 211 | **1.69** |
| e, main | 219 316 | 168 649 | 103 040 | 38 617 | 14 700 | 5 996 | **2.24** |
| f, main + boot cache | 271 761 | 232 579 | 174 064 | 98 232 | 47 562 | 22 599 | **1.86** |
| g, main + queue | 287 379 | 308 670 | 278 164 | 244 499 | 215 517 | 205 339 | **1.15** |

Exponent b: the slope of log(total time) against log(K) over K >= 50, with total time = N x cost per
entry and N proportional to K, so b = 1 + (slope of log cost against log K). b = 2 is quadratic, b = 1 is
linear. `data/synthetic-summary.txt` has the per-entry cost in microseconds:

| cost per entry, microseconds | 25 | 50 | 100 | 200 | 400 | 800 |
|---|---|---|---|---|---|---|
| a | 146.1 | 336.1 | 1 112.5 | 2 454.9 | 4 367.3 | 8 814.4 |
| b | 5.6 | 8.2 | 14.5 | 35.7 | 74.2 | 167.9 |
| d | 4.3 | 4.8 | 6.9 | 9.8 | 17.0 | 33.1 |
| e | 4.6 | 5.9 | 9.7 | 25.9 | 68.0 | 166.8 |
| f | 3.7 | 4.3 | 5.7 | 10.2 | 21.0 | 44.2 |
| g | 3.5 | 3.2 | 3.6 | 4.1 | 4.6 | 4.9 |

**Reading it.**
- **b against a:** 26 times faster at 25 files, 53 times at 800. The constant is much smaller, but b's
  cost per entry still grows 30 times from 25 to 800 files (32 times more files), so b is quadratic.
  The speed-up is larger here than on the earlier page (5 to 11 times) because this container makes
  system calls expensive: a, which makes about 480 per entry, runs 9 times slower here than there.
  The backport's gain is therefore environment dependent; the exponent is not.
- **c is b:** the 2026 pair changes nothing measurable, as the earlier page found.
- **e (main) is b again** at large K: main's loop is as O(F) as 255.4's once the `fstat()` calls are gone.
- **d and f (the boot-order cache) cut the constant 5 times at 800 files and the exponent by about 0.4**,
  but the per-entry walk over every file remains: 33 and 44 microseconds per entry at 800 files.
- **g (queue):** the cost per entry is flat, 3.5 to 4.9 microseconds from 25 to 800 files. The rise at
  the largest K is start-up (opening 800 files inside the 200 000-line window).

## 3. The laptop's own journal (read only)

- **Files:** the newest K of the laptop's journal files by mtime (K = 25, 50, 100, 200, 400 and all 481
  that exist now), passed as `--file=`, as `results/journalctl-file-scaling-2026-11-14/` did. The directory
  was mounted read-only into the container; every read ran under `nice -n 19` and `ionice -c 3`.
- **Run:** `-o short`, output counted and never kept, at most 300 000 lines or 60 s, 2 runs, median.
  Nothing from the journal is stored in this repository: only line counts, times and hashes.

Lines per second:

| variant | 25 | 50 | 100 | 200 | 400 | 481 (all) | exponent b |
|---|---|---|---|---|---|---|---|
| a, shipped | 14 714 | 8 410 | 4 493 | 2 271 | 1 251 | 1 072 | **1.91** |
| b, + 2024 commits | 227 017 | 195 567 | 146 994 | 119 888 | 77 419 | 69 382 | **1.45** |
| c, + 2026 pair | 227 537 | 188 206 | 147 646 | 135 394 | 82 843 | 76 578 | **1.40** |
| d, b + boot cache | 246 815 | 217 395 | 131 487 | 129 606 | 78 729 | 68 390 | **1.47** |
| e, main | 326 442 | 273 628 | 215 951 | 141 258 | 93 241 | 80 402 | **1.55** |
| f, main + boot cache | 337 695 | 294 736 | 233 737 | 156 057 | 95 755 | 82 356 | **1.57** |
| g, main + queue | 272 661 | 278 789 | 299 107 | 311 733 | 286 938 | 286 425 | **0.99** |

| cost per entry, microseconds | 25 | 50 | 100 | 200 | 400 | 481 |
|---|---|---|---|---|---|---|
| a | 68.0 | 118.9 | 222.6 | 440.3 | 799.5 | 933.3 |
| b | 4.4 | 5.1 | 6.8 | 8.3 | 12.9 | 14.4 |
| d | 4.1 | 4.6 | 7.6 | 7.7 | 12.7 | 14.6 |
| e | 3.1 | 3.7 | 4.6 | 7.1 | 10.7 | 12.4 |
| g | 3.7 | 3.6 | 3.3 | 3.2 | 3.5 | 3.5 |

**Reading it.**
- **The shipped binary** (a): 1 072 lines/s with all files (the earlier page measured 703 on 553 files);
  exponent 1.9, close to quadratic.
- **With the 2024 backport** (b): 65 times faster at all 481 files, but the cost per entry still grows
  3.3 times from 25 to 481 files (19 times more files); b's exponent is 1.45, not 1.
  It is lower than on the synthetic files because a fixed cost per entry (reading and formatting, about
  3.5 microseconds, the value of g) dominates at small K; the part that grows with K is
  `data/real-summary.txt`'s difference b minus g: 0.9, 1.6, 3.3, 4.9, 9.4, 10.9 microseconds at K = 25 ... 481,
  about 0.02 microseconds per file per entry. That part is proportional to K, so as the journal grows
  past the point where it dominates, the exponent goes to 2.
- **The journal's real shape differs from the synthetic one** (fewer boots per file, different file sizes,
  user journals among the files), so the two exponents are not expected to agree; both show the same
  direction.
- **g** is flat: 3.5 microseconds per entry at every K.

## 4. Where the per-entry cost is (callgrind, 400 synthetic files, first 3 000 lines)

Instructions, whole run, at 400 files (`data/callgrind-*`; release builds, so inlined functions are
folded into their callers):

| | total | what is in it |
|---|---|---|
| b | 3 078 M | `real_journal_next` 95 %; `compare_boot_ids` 89 %; its lookup `journal_file_find_newest_for_boot_id` 85 % |
| e (main) | 2 436 M | `compare_locations` 46 %; `compare_boot_ids` 44 %; `newest_by_boot_id_compare` (the search over boots) 38 %; `journal_file_read_tail_timestamp` 8 % |
| d | 651 M | `real_journal_next` 76 %, of which `compare_boot_ids` 48 % (`boot_newest_cached` 30 % on its own), the loop itself 19 %, `journal_file_read_tail_timestamp` 8 % |
| g (queue) | 181 M | formatting 53 %; `heap_next` 37 %, mostly `heap_compare` 30 % (profile of the first build, before the fix of section 5) |

So the O(F) per entry is the loop in `real_journal_next()`: for every entry it calls
`next_beyond_location()` and `compare_locations()` for each open file, and `compare_locations()` calls
`compare_boot_ids()` whenever two entries come from different boots. The cache (d, f) makes each of
those calls cheaper; only a structure that avoids visiting every file changes the growth.

## 5. The prototype: a priority queue of the archived files (variant g)

`patches/systemd/journal-file-scaling/heap/0001-*-PROTOTYPE.patch`, against main `6bd4689`; about 225 lines
added in `sd-journal.c`, `journal-file.h`, `journal-internal.h`.

**How it works.** After a linear walk, the archived files that hold a candidate entry go into a `Prioq`
ordered by the same `compare_locations()` the linear walk uses, ties broken by the file's position in the
linear walk (the linear walk keeps the first of equal candidates). The next call:
1. advances only the file the last entry came from and queues it again;
2. walks the files that are not archived (they may grow) linearly, as before;
3. drops queue tops that are copies of the entry just returned (what the linear walk does for every file);
4. takes the smaller of the queue's top and the best unarchived candidate.

An entry costs O(log F) plus the number of unarchived files (one or two on a normal machine). Any seek, any
change of matches and any added or removed file drops the queue; the next call is linear and builds it
again. It is not built below 16 files.

**Why the order is the same.** The queue is ordered by the comparison the linear scan uses, and the tie
rule reproduces the scan's "first of equal wins". The two can still disagree where `compare_locations()`
is not transitive. That function compares sequence numbers only between files with the same sequence ID,
boots through `compare_boot_ids()` only between entries of the same machine, and otherwise time; for files
with different machine IDs or boots whose time ranges overlap, A < B, B < C and C < A can all hold.
A linear scan returns an answer that depends on the order it visits the files in; a heap returns another.
So equality is not guaranteed, and the evidence below is evidence, not proof.

**What was tried, and the result.**

| check | result |
|---|---|
| export-format output, 14 query kinds (forward, reverse, `-n`, `-k`, one boot by match and by offset, `--since`/`--until`, `--since` in reverse, `-r -n 3000`, `--lines=+3000`, and four cursor seeks) on 25 and 50 files, a 40-file set with three ONLINE files, and the 60-file, 12-boot sets with overlapping time windows and copied stretches (OFFLINE and ARCHIVED): g and f against e | identical, `data/same-output-*.txt` |
| the same for b, c, d against a on 25 files and the interleaved archived set | identical |
| the laptop's real journal, newest 25, 50, 200 and all 481 files, first 600 000 export lines, forward and reverse (reverse ends one hour ago, because the newest file is live): f, g against e; b, c, d against a (25 files) | identical, `data/same-output-real.txt` (hashes only) |
| systemd's `test-journal`, `-interleaving`, `-enum`, `-flush`, `-init`, `-match`, `-stream`, `-verify`, `-file`, `test-mmap-cache` | pass, also with the queue forced on for any number of files (`-DHEAP_MIN_FILES=2`), which the small journals of those tests need to exercise it |

**A bug the forced-on test found, fixed.** The first version failed `test-journal-interleaving`
(`sd_journal_previous()` returned 0 too early after a monotonic seek): the first walk after a seek leaves
files without an entry unsettled (they are looked at again on the next walk), and the queue treated
them as finished. The queue is now built only when every archived file is settled in the walk's direction.
All figures on this page for g are from the fixed build; the first build's rows are not used.

**Not done.**
- No test with a writer running (follow mode, `-f`), and none for files that change while open.
- Only one machine ID was tested; journals from several machines, or with a wrong clock, are the cases
  where `compare_locations()` is not an order. Needs a test set of that kind, and agreement upstream on
  what the output order must be there.
- No test was added to systemd's suite; the code is not formatted for review, not checked with clang-tidy.
- The queue is not built when any archived file is unsettled or below 16 files; the rule for online
  files (kept out of the queue, walked each time) assumes few of them.
- Not measured against the boot-order cache combined with the queue (g is already flat).

## 6. For the report

- **What the 24.04 backport gives.** Backporting the two 2024 commits (`99e6f682d3`, `51b2bcf835`) removes
  the system calls and makes `journalctl` 26 to 53 times faster on synthetic journals here (65 times at all
  481 files of the laptop's journal). They apply to 255.4 unchanged. That is worth shipping.
- **Is the quadratic growth gone?** No. After the backport the cost per entry still grows in proportion
  to the number of open files: exponent 2.1 on synthetic journals, 1.45 and rising on the laptop's real
  one. A journal that doubles in size takes about four times as long to read (twice the entries, each
  costing about twice as much once the per-file part dominates). The backport shifts the curve down by an
  order of magnitude; it does not change its shape. Upstream main behaves the same (2.2 and 1.55).
- **What remains for upstream.** The per-entry walk over every open file in `real_journal_next()`.
  - The boot-order cache (an existing patch, not sent) cuts the constant 3 to 5 times at 400 to 800 files
    and the exponent to 1.7 to 1.9.
  - A priority queue of the files makes the cost per entry flat (exponent 1.15 on synthetic journals, 0.99 on the laptop's
    journal), but it needs agreement on the order of entries for journals where
    `compare_locations()` is not an order, and tests with live files, before it can be proposed.
- **Until then, on the laptop:** fewer, larger journal files (`SystemMaxFileSize=`) reduce F, which every
  variant's cost depends on. Reading `-b` or a time window, not `-b all`, avoids the whole walk.

## 7. Exact commands

All of them run in the build container (image with systemd's build dependencies); `<work dir>` is the scratch
directory, `<repo>` this repository. The scripts in `scripts/` use `$WORKDIR` and `$REPO` for them and expect
to be copied to `<work dir>/bin/`.

```console
$ <work dir>/bin/dk.sh inside-build.sh fetch          # apt source of 255.4-1ubuntu8.18 and systemd main
$ <work dir>/bin/build-all.sh a b c d e f             # the six variants; then: dk.sh inside-build.sh build g
$ <work dir>/bin/dk.sh inside-synth.sh gen            # 800 archived files, 2000 entries each, sets for K
$ <work dir>/bin/dk.sh inside-synth.sh run            # a b c d;  VARS="e f g" for the main-based ones
$ <work dir>/bin/run-real.sh                          # the laptop's journal, read only (VARS="a b c d e f g")
$ <work dir>/bin/run-equiv.sh                         # same-output checks on synthetic sets
$ <work dir>/bin/run-realequiv.sh                     # same-output checks on the real journal (hashes only)
$ python3 -I <work dir>/bin/analyse.py <tsv>          # medians and exponents
$ <work dir>/bin/dk.sh inside-callgrind.sh d 400 3000 # valgrind --tool=callgrind, then callgrind_annotate
$ <work dir>/bin/dk.sh inside-tests.sh g              # systemd's journal tests; inside-tests-min2.sh forces the queue on
```

Raw medians come from `data/synthetic-rates.tsv` and `data/real-rates.tsv` (columns: variant, K, run, lines,
seconds).

## Files

| file | what |
|---|---|
| `scripts/` | build, generate, measure, compare, analyse |
| `data/synthetic-rates.tsv`, `data/synthetic-summary.txt` | every synthetic run; medians, exponents, cost per entry |
| `data/real-rates.tsv`, `data/real-summary.txt` | the same for the laptop's journal (counts and times only) |
| `data/walk-cost-*.txt` | the part of the cost per entry that grows with K, an estimate |
| `data/same-output-synthetic.txt`, `data/same-output-real.txt` | the comparisons |
| `data/callgrind-*.txt` | profiles at 400 files |
| `data/systemd-tests.txt` | systemd's journal tests with the queue |
| `../../patches/systemd/journal-file-scaling/heap/` | the prototype |
