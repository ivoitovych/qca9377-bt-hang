# journalctl's file-count scaling: the cause in the source, upstream's fixes, and one more (2026-11-14)

**Why this exists.**
- **The incident.** On 2026-11-14 a `journalctl -k -b all` ran 7 h 44 min on the laptop at a full
  CPU, and
  [`results/journalctl-file-scaling-2026-11-14/`](../journalctl-file-scaling-2026-11-14/README.md)
  measured why there: journalctl's rate falls in proportion to the journal files it has open (553
  files: 703 lines/s, against 196 451 for one file).
- **What that page asked next:** read `real_journal_next` on v255 and on upstream main, then
  reproduce with synthetic journals on both.
- **This page does that.** It also checks every upstream fix against 24.04's systemd, finds a
  cost upstream has not removed yet, and proposes and tests a fix for it.

**Where it was done.**
- **A development container, not the laptop:** 4 cores, nothing else running, the same systemd as
  the laptop (`255.4-1ubuntu8.18`).
- **Synthetic journals only.** They are written by this host's `systemd-journal-remote` from
  generated entries (one machine ID, kernel-like lines). Nothing was read from any machine's
  journal.
- **The upstream sources:**
  - v255.4 (`systemd-stable` tag `v255.4`, `387a14a`);
  - systemd main at `6bd4689` (2026-11-14), which reports itself as 263~devel.

## 1. The cause, in 255.4's source

`sd_journal_next()` → `real_journal_next()` walks every open file for every entry
(`src/libsystemd/sd-journal/sd-journal.c`, v255.4 line 935). Two things in that walk cost a
system call each:

- **The tail-timestamp refresh.** `next_beyond_location()` begins with
  `journal_file_read_tail_timestamp(j, f)` (line 810), and that function begins with
  `journal_file_fstat(f)`, an `fstat()` with no rate limit (`journal-file.c`). It runs for
  every file, on every entry.
- **Cross-boot comparisons.**
  - When the walk compares entries from two different boots, `compare_with_location()` (line
    516) and `compare_locations()` (line 908) call `compare_boot_ids()`.
  - That calls `journal_file_find_newest_for_boot_id()` once for each of the two boots.
  - Each of those reads a tail timestamp again, so another `fstat()` each.

**Measured:** with 100 files open, the installed `journalctl` makes **477.7 `fstat`-family
calls per printed line**, about 4.8 per open file per entry (`measure-scaling.sh`'s strace
step). That is the cost per entry that grows with the number of files. Rotation adds files as
the journal grows, so the whole read grows with the square of the journal's size.

## 2. Upstream has fixed most of it

| commit | what | first release |
|---|---|---|
| `99e6f682d3` (Yu Watanabe, 2024-01-03) | cache the last entry offset and file state, so `journal_file_read_tail_timestamp()` skips `fstat()` when the file has not changed | v256 |
| `51b2bcf835` (same day) | report to the caller whether a new entry appeared; the lookup per boot stops early when none did | v256 |
| `bd1af1d5fb`, `f7f062bf9f` | `SD_JOURNAL_ASSUME_IMMUTABLE`, set where a reader does not follow | v256 |
| `8f8ab4bf98` (2026-06-24) | rate-limit that refresh to once a second per file during iteration; its message describes this symptom ("O(N x files)", "~5 minutes on systems with many journal files") | v262 |
| `79e32e7c73` (2026-09-04) | read the clock once per walk instead of once per file per entry | not yet released |

- **Not in 24.04:** none of these is in Ubuntu 24.04's `255.4-1ubuntu8.18`, the newest in
  noble-updates and noble-security on 2026-11-14. Its changelog has no journal-performance
  backport.
- **Prior report:** a systemd-devel thread of May 2025 ("slowness reading persistent journal")
  describes the same mechanism, `fstat()` for each journal file for each line. No Launchpad bug
  for noble was found (search of 2026-11-14).

## 3. Reproduced, and the fixes measured (`measure-scaling.sh`)

- **The files:** 400 synthetic files (`make-journals.py`, 4 000 entries each, consecutive in
  time, 5 files per boot, so 80 boots), with the header's state set to ARCHIVED, as the laptop's
  rotated files are.
- **The runs:** the first K files, `journalctl --directory=… -o cat`, for at most 15 s.
- **The builds:** each was compiled here with the same options (`--buildtype=release`).

Lines per second:

| files | 255.4 as installed | 255.4 built | + `99e6f682d3` `51b2bcf835` | + those, `8f8ab4bf98` and `79e32e7c73` | + `99e6f682d3` `51b2bcf835` + boot-order cache (§4) | main | main + boot-order cache (§4) |
|---|---|---|---|---|---|---|---|
| 1 | 285 574 | 201 843 | 261 861 | 228 762 | 284 687 | 392 201 | 437 590 |
| 25 | 58 914 | 56 051 | 270 808 | 319 687 | 550 081 | 587 399 | 805 705 |
| 50 | 26 400 | 26 763 | 147 846 | 131 349 | 515 172 | 232 681 | 433 762 |
| 100 | 8 124 | 7 979 | 85 646 | 76 011 | 405 194 | 127 087 | 240 634 |
| 200 | 3 622 | 3 699 | 25 251 | 24 430 | 121 681 | 37 584 | 110 246 |
| 400 | 1 714 | 1 666 | 8 633 | 9 353 | 28 051 | 10 591 | 38 406 |
| syscalls per line, K = 100 | 477.8 | 477.8 | 0.1 | 0.1 | 0.1 | 0.1 | 0.1 |

How to read it:
- **The installed binary and the one built from v255.4 behave alike,** so the builds measure the
  same code. The one-file row is a 4 000-line run of 10–20 ms, dominated by start-up; read it as
  "fast".
- **The two 2024 commits remove the system calls entirely:** 477.8 per line becomes 0.1. They
  make 25 to 400 files 5 to 11 times faster. Both apply to v255.4 unchanged.
- **The two 2026 commits add nothing measurable on top here.** Once the `fstat()` is gone, the
  refresh they limit is cheap. They needed adapting to apply to 255.4 (§5); their value here is
  nil.
- **Upstream main is 1.2 to 2.2 times faster again, but the rate still falls at least in half each
  time the file count doubles.** The cost per entry still grows with the number of files, in
  main too.
- **Not mmap-cache thrashing,** the hypothesis of the laptop page: at 400 files there are 0.08
  mmap/munmap calls per printed line, mostly the first mapping of each file.

## 4. What main still spends, and a fix: cache the boot order

`callgrind` on a build of main with symbols (`--buildtype=debugoptimized`), the first 3 000 lines
at 200 files:

| inclusive instructions | main | main + boot-order cache |
|---|---|---|
| whole run | 1 086 M | 303 M |
| `real_journal_next` | 97.5 % | 91.0 % |
| `compare_boot_ids` | **88.2 %** | 55.6 % |
| `journal_file_find_newest_for_boot_id` | 82.7 % | — (only on a miss) |
| `newest_by_boot_id_compare` (the binary search over boots) | 36.1 % | — |

**Where the time goes:** main has removed the system calls, but `compare_boot_ids()` still takes
88 % of all instructions.
- **How often it runs:** for every comparison of two entries from different boots, which is
  nearly every open file on every entry.
- **What each call does:** it binary-searches the boots for both boots' newest files, peeks a
  priority queue and refreshes a tail timestamp.
- **When its answer can change:** only when some file's newest entry changes, or the set of
  boots does.

**The fix** (`patches/systemd/journal-file-scaling/boot-order-cache/`) keeps what
`compare_boot_ids()` needs in two places:
- with each journal file, for the boot of its current entry;
- with the `sd_journal`, for the boot of the `Location` compared against.

`newest_by_boot_id_generation` is a counter bumped wherever a file's newest data or the boot index
changes, in three places. Whenever it has moved, both caches are refilled.

The trade-off is one skipped refresh. On a cache hit, the tail-timestamp refresh that the lookup
used to do is skipped. Tail timestamps are still refreshed by `next_beyond_location()`, at most
once a second per file on main, as upstream chose in `8f8ab4bf98`, and a change found there moves
the counter.

The patch is 61 lines added and 8 removed, in `journal-file.h`, `journal-internal.h` and
`sd-journal.c`.

**Measured on main:**
- 1.4 to 3.6 times faster at 25 to 400 files (table in §3);
- about 22 to 30 times faster than 24.04's binary at 100 to 400 files.

**Same output.** `same-output.sh` prints each journal in export format (every field, the cursor
included) with both binaries, for eight queries:
- forward and reverse;
- the last 500 entries (`-n 500`);
- kernel only (`-k`);
- one boot by match, and one by offset (`-b -3`);
- a `--since`/`--until` window, and `--since` in reverse.

It compares the outputs by SHA-256. All 32 comparisons are identical: main against main with the
cache, on 50 and 100 of the files above and on two sets from `make-journals-interleaved.py`.
- **Those two sets:** 60 files over 12 boots whose time windows overlap, with each boot's files
  spread over the set, so that the order across boots depends on `compare_boot_ids()`. Every 7th
  file repeats 50 entries of the one before, and both binaries print each of those once
  (180 000 entries of 180 400 written).
- **The two sets differ only in state:** one has its files left OFFLINE as `journal-remote`
  wrote them, the other has them marked ARCHIVED.

**systemd's own tests.** These pass on main with the cache, as without it:
- `test-journal`;
- `test-journal-enum`, `-file`, `-flush`, `-init`, `-interleaving`, `-match`, `-stream`,
  `-verify`;
- `test-mmap-cache`.

`test-journal-append`, a writer-side stress loop, ran past the 600 s limit on both trees alike
(`data/systemd-tests.txt`).

**The 255.4 version of the same cache:**
- Its 24 comparisons (100 files, and both interleaved sets) are identical to 255.4 with the 2024
  commits.
- **On top of the 2024 commits it is faster again:** 405 194 lines/s at 100 files and 28 051 at
  400, against 85 646 and 8 633. Against 24.04's binary that is 50 and 16 times.

## 5. What is still open

- **The walk itself.** With the cache, the rest of the cost is the per-entry walk over every open
  file: the cache checks are 33 % of instructions on their own, the loop 23 % and the comparison
  17 %.
  - **The structural fix:** a priority queue of files ordered by their next entry, which would
    make an entry cost the logarithm of the file count, not the file count.
  - **Why it is not done here.** `compare_locations()` is not a strict ordering. It calls entries
    of two machines' boots "equal", and it mixes sequence numbers with time. So today's output
    order can depend on the order of the walk, and a heap could print some multi-machine or
    clock-broken journals in another order. That needs agreement upstream before code; it is
    written down here as a proposal, not tried.
- **Not done:**
  - **The laptop.** No patched build has run there; its 553 files, user journals among them,
    were not modelled.
  - **Live, growing files** are covered only by systemd's tests, not by a test of our own with a
    writer running.
  - **Ubuntu releases after 24.04** were not measured.

## 6. What it means, and what is the operator's to decide

1. **For 24.04, a backport of `99e6f682d3` and `51b2bcf835`.** Both are upstream commits and apply
   unchanged, and they remove 99.98 % of the system calls. That makes them a fit for an Ubuntu
   stable update.
   - **Candidate contribution:** a Launchpad bug against noble's `systemd`, with this page's
     synthetic reproduction and the two cherry-picks.
   - **Decided by the operator:** whether, when, and under which CO number.
2. **For upstream, the boot-order cache against main.** It is measured, gives the same output in
   every query tried, and passes systemd's journal tests.
   - **Candidate contribution:** a systemd pull request. It is new work, not upstream's, and
     nothing has been sent.
3. **For the laptop, until a fixed systemd arrives:**
   - **Fewer, larger journal files** (`SystemMaxFileSize=`) shrink the file count, which every
     version's cost depends on.
   - **A patched `journalctl` could be tried on the laptop's real journal:** 255.4 with the 2024
     commits, with or without the cache. The tool only reads, and could be installed as a separate
     binary, not replacing the packaged one.
   - **Both are the operator's decisions.**

## Files

| file | what |
|---|---|
| `make-journals.py` | 1…N consecutive journal files, some boots, written by `systemd-journal-remote` |
| `make-journals-interleaved.py` | journal files whose boots overlap in time, with copied stretches |
| `measure-scaling.sh` | rate for K files, and system calls per printed line |
| `same-output.sh` | do two `journalctl` binaries print the same journal, in eight queries |
| `data/rates.tsv` | every rate and system-call count above |
| `data/callgrind-main-200.txt`, `data/callgrind-main-cache-200.txt` | the profiles of §4, scratch paths removed |
| `data/same-output-*.txt` | the comparisons of §4 |
| `data/systemd-tests.txt` | systemd's journal tests on main, with and without the cache |
