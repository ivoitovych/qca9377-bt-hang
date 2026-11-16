# The per-entry cost that still grows with the number of files: upstream PR #44579 against our priority-queue prototype (2026-11-16)

After the two 2024 commits `journalctl` no longer makes system calls per file per entry, but it still compares the
candidate entry of every open file for every entry it prints, so the cost per entry grows with the number of files F.
Two designs remove that comparison: upstream PR #44579 (a cached winner and runner-up) and our prototype g (a priority
queue). This page reads the PR, measures both on the same base, and checks them against the unpatched code.

**Nothing was posted, commented, reacted to or subscribed to on GitHub; the PR was only read** (plain GET requests and a
`git fetch` of its head ref). Nothing was installed on the host. Builds and tests ran in a container at `nice -n 19`,
`ionice -c 3`, one job at a time; timings ran on the bare host, read only, under `nice -n 19` and `ionice -c 3`.

**Short answers**
- **PR #44579 removes the F-dependence for sequential (rotated) files and not for interleaved files.** On the host its
  per-entry cost is 2.2 to 2.5 microseconds from 25 to 800 sequential files and on the laptop's real journal (25 to 491
  files), and the same as unpatched main for interleaved files (7.6 microseconds at 400 files, against 2.7 at 25).
- **Our prototype g removes it in all three layouts** (2.7 to 4.3 microseconds sequential, 2.5 to 2.7 interleaved on one
  machine, 1.8 to 2.0 on three machines), but is a bit slower than the PR on sequential files.
- **Output:** on every journal of the kinds a real system produces, g and the PR print exactly what main prints (hundreds of
  byte-for-byte comparisons, a followed live file, files added and removed mid-read). They differ from main, and from each
  other, only on journals that break journald's own invariants, where main's own output is already incomplete
  (section 4).

## 1. PR #44579, read

Fetched read-only (`scripts/fetch-pr.sh`, digest `data/pr44579-digest.txt`, the commit `data/pr44579-f26f6637ac-commit.diff`).

| item | value |
|---|---|
| title, author | "sd-journal: don't compare all files for every entry", Ar-maan05 |
| state | open, not merged, not draft; created 2026-11-01, last push 2026-11-02 14:13 UTC; nothing newer as of 2026-11-16 (the API's `updated_at` is 2026-11-03, a label event) |
| **head** | **`f26f6637ac580c02f9cb845b40b128378fdc97f2`**, one commit, branch `perf/journal-next-runner-up` |
| base | its parent `32d75628c4` (main when it was written; main was `2361f7b6881f` when fetched) |
| pushes | the head was force-pushed twice (to `5e95e068b1` at 03:57, to `f26f6637ac` at 14:13 on 2026-11-02); the automated review ran on the first two |
| size | 3 files: `journal-internal.h` +6, `sd-journal.c` +89 -5, `test-journal-interleaving.c` +46 |
| labels | `journal`, `tests`, `please-review`, `claude-review` |

**Review.** The only human comment is from yuwata, 2026-11-02 03:48: "Please address suggestions by Claude, at first."
The suggestions are those of an automated review (the `github-actions` bot): two must-fix
(a file at EOF is not rechecked, so `-f` can lose an entry; the first scan after a seek must not be cached), two suggestions
(skip the EOF rule when the journal is `SD_JOURNAL_ASSUME_IMMUTABLE`; read `header->state` before the lookup), five nits
(clear both pointers on removal, move a comment, `static inline _always_inline_`, a dead `: -1`, share the 1 s constant with
`tail_timestamp_ratelimit`). The author fixed all but the shared constant (the last open item). There is no human review
of the code yet, and no comment from yuwata on the design.

**The algorithm, exactly.** State in `sd_journal`: `scan_winner`, `scan_runner_up`, `scan_direction`, `scan_valid_until`,
`scan_same_file`.
1. **Fast path** (`journal_next_from_previous_scan`), tried first in `real_journal_next()`. It is taken only if all hold:
   `scan_winner` is set and equals `j->current_file` (the file the last entry came from); `current_location.type` is
   `LOCATION_DISCRETE`; the direction equals `scan_direction`; `now(CLOCK_BOOTTIME) < scan_valid_until` (one second after
   the full scan that stored it). Then it advances only the winner (`next_beyond_location`); if that returns EOF or an
   error it gives up; if there is a runner-up it compares the winner's new candidate with the runner-up's cached candidate
   (`compare_locations`) and gives up unless it is strictly before (forward) or strictly after (backward); with no runner-up
   it accepts. If the entry cannot be read (`journal_file_move_to_object` fails) it falls to the full scan.
2. **Full scan** (the old loop over every file), plus bookkeeping. At its start `scan_winner = NULL`. It reads
   `header->state` before each file's lookup. It tracks the runner-up (the best candidate among the non-winners) only if
   `track_runner_up`, which is `scan_same_file && current_location.type == LOCATION_DISCRETE`, and is switched off for
   this scan if a file hit EOF while reading forward, is not archived and the journal is not `ASSUME_IMMUTABLE`.
   After choosing the file: `scan_same_file = (new_file == j->current_file)`; if `track_runner_up` and the choice was not an
   `exact_match` override, it stores winner, runner-up, direction and `scan_valid_until = now + 1 s`.
3. **When it falls back to the full scan:** the winner changed or hit EOF; the new candidate is not strictly ahead of the
   runner-up (a tie included); one second has passed since the last full scan (so the other files still get their tail
   timestamp refresh and new entries are noticed); the direction changed; the location is not DISCRETE (any seek, head
   or tail); `current_file` is not the winner; a file was added or removed; the runner-up was not tracked (the winner has
   not won twice in a row, or a non-archived file was at EOF going forward).
4. **Seeks, direction, matches, files.** A seek leaves the location SEEK/HEAD/TAIL (and `detach_location()` clears
   `current_file`), so the next call is a full scan, and the scan after it is not tracked either (the second scan after a
   seek must retry files where the seek lookup found nothing); the shortcut returns after the winner has won twice in a
   row. A direction change is a full scan. Matches: the fast path calls the same `next_beyond_location()` and so the same
   `next_with_matches()`; adding or flushing a match goes through `detach_location()`, which breaks the `current_file` test.
   A file added (`add_any_file`) sets `scan_winner = NULL`; a file removed (`remove_file_real`) clears winner and runner-up.
   Going backwards the EOF restriction does not apply (a new entry appended to a live file sorts after the reader).
5. **Complexity.**
   - *Sequential archived files* (rotation): O(1) per entry (one comparison with the cached runner-up), and a full scan
     of O(F) at every file boundary (the winner reaches EOF) and every second. A whole read of K files of E entries costs
     O(N + K^2) with N = K E: the quadratic part is the K boundaries times K files, small compared with N while E is large
     (measured, section 3: nothing visible at E = 2000, K <= 800).
   - *Interleaved files* (the next entry usually comes from another file): the winner rarely wins twice, so the runner-up is
     not tracked and every entry is a full scan, O(F) per entry as before. The PR's own table shows 100 interleaved files
     "0.87 s -> 0.88 s"; it is not an improvement for them, and it is not meant to be.
   - *One live file* next to archived ones: with `journalctl` without `-f` (the flag `ASSUME_IMMUTABLE` is set in
     `journalctl.c`) the shortcut stays on. In follow mode it is switched off for every scan in which the live file has hit
     EOF reading forward, which is the state of a reader that has caught up; during the catch-up through older archived
     files the live file has candidates and the shortcut works. I did not measure follow mode against many files.

## 2. What was built (container, `scripts/inside-build-pr.sh`)

| variant | tree |
|---|---|
| e2 | main at the PR's base, `32d75628c4` |
| p2 | e2 + the PR's commit `f26f6637ac` |
| g2 | e2 + our priority-queue prototype (`patches/systemd/journal-file-scaling/heap/0001-*`), applied with `git apply --3way`: **cleanly, with offsets only; the patch had been made against `6bd4689`** (`data/g2-on-32d75628c4.diff` is the result) |

(The prototype does not apply on top of the PR: `sd-journal.c` conflicts in `real_journal_next()`; both rewrite that function.)
Release builds of `journalctl` and `systemd-journal-remote` only; nothing installed.

## 3. Rates on the host

Bare host, outside any container, one run at a time at the lowest priority; 3 runs, median; the system's IO pressure is
recorded per run (last column of `data/pr-*.tsv`). `-o short` to a line counter, at most 200 000 lines or 45 s (the cap
is `LINES`/`SECS`; "full" rows read the whole journal). The synthetic sets are 2 000 entries per file (sequential, archived,
5 files per boot, as before) and 1 000 per file for the two interleaved layouts:
- `int1`: K files, one machine, one boot, round robin: file i holds entries e*K+i, so the next entry comes from a
  different file every time;
- `int3m`: the same with three machine IDs (clocks 0, 3 and 7 s apart), so entries of different machines compare by
  realtime only.

Lines per second (`data/rates-summary.txt` has the per-entry costs and the exponents; b is the exponent of the time to read
everything, 2 = quadratic, 1 = linear):

| layout | variant | 25 | 50 | 100 | 200 | 400 | 800 / all | b |
|---|---|---|---|---|---|---|---|---|
| sequential | e2 | 320 538 | 231 502 | 137 931 | 51 387 | 19 633 | 6 997 | 2.29 |
| | p2 | 431 069 | 450 491 | 450 450 | 437 637 | 417 537 | 396 825 | **1.05** |
| | g2 | 378 818 | 374 566 | 346 021 | 298 954 | 265 604 | 235 018 | **1.17** |
| sequential, whole journal | e2 | 318 497 | 235 315 | 142 261 | 73 510 | 33 172 | 13 362 | 2.04 |
| (file boundaries included) | p2 | 434 817 | 456 662 | 448 473 | 449 482 | 442 766 | 411 141 | **1.03** |
| | g2 | 381 710 | 371 781 | 346 054 | 320 287 | 290 199 | 249 674 | **1.14** |
| interleaved, 1 machine | e2 | 367 647 | 337 838 | 294 985 | 218 341 | 130 976 | | 1.45 |
| | p2 | 357 143 | 352 113 | 303 030 | 221 239 | 132 188 | | **1.47** |
| | g2 | 390 625 | 406 504 | 401 606 | 401 606 | 376 648 | | **1.03** |
| interleaved, 3 machines | e2 | 447 477 | 359 345 | 238 367 | 136 893 | 72 124 | | 1.78 |
| | p2 | 451 698 | 356 751 | 244 253 | 138 408 | 70 299 | | **1.78** |
| | g2 | 570 000 | 584 734 | 566 891 | 519 481 | 497 512 | | **1.08** |
| the laptop's real journal (newest K files; all = 491) | e2 | 356 295 | 314 136 | 245 902 | 109 930 | 75 453 | 62 305 | 1.74 |
| | p2 | 409 836 | 406 504 | 383 142 | 376 884 | 397 351 | 391 645 | **1.01** |
| | g2 | 371 287 | 366 748 | 338 983 | 291 829 | 318 471 | 319 489 | **1.06** |

Per-entry cost in microseconds at the largest K: sequential p2 2.4, g2 4.0 (whole journal, 800 files), e2 74.8;
interleaved 1 machine p2 7.6, g2 2.7, e2 7.6 (400 files); interleaved 3 machines p2 14.2, g2 2.0, e2 13.9;
real journal p2 2.6, g2 3.1, e2 16.1.

**Reverse and matches, 400 sequential files** (lines per second; 400 interleaved files for the last row):

| query | e2 | p2 | g2 |
|---|---|---|---|
| `-r` | 18 918 | 388 350 | 247 525 |
| match `SYSLOG_IDENTIFIER=kernel` (every entry) | 18 255 | 375 235 | 237 530 |
| OR of 40 boots (`_BOOT_ID=a + _BOOT_ID=b + ...`) | 33 450 | 218 341 | 170 068 |
| `-r` on the 400 interleaved files (1 machine) | 126 743 | 144 823 | 345 423 |

**Reading it.**
- **The PR's quadratic term is not visible here.** The whole-journal exponent is 1.03 up to 800 files of 2 000 entries; the
  boundary cost is about 0.5 microseconds times K per file, 0.3 s of 3.9 s at K = 800, and shrinks as files hold more entries.
- **The PR is faster than g on layouts where it works** (sequential and the real journal: 1.1 to 1.7 times), because it
  does one comparison per entry; g pays a priority-queue operation and its comparisons, about 2.5 to 4 microseconds.
- **g is faster where the PR does not work** (interleaved: 2.8 times at 400 files with one machine, 7 times with three).
- **Both keep the cost flat only within their layout.** In the PR's own terms a journal mixing a rotated archive with many
  parallel per-user files is the interleaved case for the parallel files.
- **Reverse and matches follow the same pattern;** the match runs through the same `next_with_matches()`.

## 4. Correctness against main (`test/`)

e2 is the reference; "byte-identical" means the SHA-256 of the full `-o export` output (every field, cursors included).

| check | sets | result |
|---|---|---|
| 24 query kinds (forward, reverse, `-n`, `-k`, a boot, `-b -3`, `--since`/`--until`, `-r --since`, `-r -n`, `--lines=+N`, `--cursor` and `--after-cursor` in both directions, matches: all entries, OR of boots, AND and OR across fields, in both directions, matches with cursors) | `plain` (60 files, 12 boots), `interleaved` (60 files, 12 overlapping boots, copied stretches), `twomachines` (2 machine IDs), `int1-50`, `int3m-50` and `int3m-100` (3 machine IDs), `seq-100` | **p2 and g2 identical to e2 in all 336 comparisons** (144 in the first pass, 192 in the second; 34 of the second pass's have an empty result, trivially equal: the single-boot sets have no boot to match) |
| `-f` on a file still being written (`systemd-journal-remote` stdin, 3 batches, the file stays ONLINE; 20 archived files in front), three readers at once, then a file added to the directory while they follow | 21 files, 24 800 entries | follow reads (21 943 entries) and final reads (24 800) identical for e2, p2, g2 |
| files added and removed while the directory is read, through the API with inotify active: a newer file, one interleaved with the unread part, an older one, one of another machine ID; a future file removed, the current file removed, 20 of 24 files removed; each forward and backward, without a match, with `SYSLOG_IDENTIFIER=kernel`, and with an OR of two boots | 24 files of one machine, monotonic time rising across the files of a boot (42 scenarios per variant) | **identical for e2, p2, g2** (`test/midread-rising-*.txt`) |
| the same, with monotonic time restarting in every file of a boot (not what journald writes; the first pass) | 42 scenarios | identical except **two scenarios of g2**, see below |
| systemd's journal unit tests (`test-journal`, `-interleaving`, `-enum`, `-flush`, `-init`, `-match`, `-stream`, `-verify`, `-file`, `-send`, `test-mmap-cache`) | e2, p2 (with the PR's new test), g2, and g2 with the queue forced on for any number of files | 44 of 44 pass |

**The differences, with a reproducer each. All are on journals that break journald's invariants.**
1. **Monotonic time restarts in each file of one boot, a file of another machine added mid-read, backward** (`test/midread-e2.txt`
   against `midread-g2.txt`, lines "add_twomachines backwards"): e2 and p2 return 11 504 entries, g2 returns all 12 500.
   Reproducer: `python3 -I test/midread-test.py <libsystemd.so> <systemd-journal-remote> <dir>` (the default mode). The same data with monotonic
   time rising across the files of the boot gives identical results. Which is right: the files of one boot overlap in
   monotonic time, `compare_locations()` orders entries of one boot by monotonic time and entries of different machines by
   realtime, and the two orders disagree about the same entries, so the merge has no consistent answer; e2 and p2 print fewer
   entries than the 12 000 static ones alone, g2 prints all 12 500. The input is not a journal journald writes.
2. **The same seqnum ID with repeating sequence numbers** (`test/make-seqnum-set.py <remote> <dir> <files per group>`, 3 groups, group 0
   and group 1 each with one seqnum ID, interleaved in time, one machine ID per group; the header's `seqnum_id` is overwritten).
   `test/seqmix-output.txt`: number of entries printed, of the written entries:

   | files per group | written | e2 fwd / rev | p2 fwd / rev | g2 fwd / rev |
   |---|---|---|---|---|
   | 1 | 900 | 900 / 900 | 900 / 900 | 900 / 900 |
   | 2 | 1 800 | 606 / 606 | 606 / 606 | 606 / 606 |
   | 3 | 2 700 | 1 504 / 1 202 | 1 504 / **607** | 1 504 / 1 202 |
   | 5 | 4 500 | 1 507 / 1 505 | same | same |
   | 6 | 5 400 | 2 110 / 1 511 | 2 110 / 1 511 | **3 907** / **4 356** |
   | 10 | 9 000 | 2 416 / 2 702 | **2 415** / 2 702 | **6 903** / **5 749** |

   **Main itself prints at most a third of the entries on these journals, and forward and backward disagree with each other.** So
   neither the PR (it differs from main at 3 files per group, backward, and by one entry at 10) nor g (it differs from 6 files
   per group on, where the queue is built) is "wrong" against a defined order: the order is not defined there.
   Control: the same entries with every file keeping its own random seqnum ID: 9 000 of 9 000 entries and the same hash for e2, p2 and g2.
   `compare_locations()` (`sd-journal.c`) says what the order is: for two files with the same `seqnum_id` it compares sequence numbers
   first; if the boot IDs are equal it compares monotonic time, otherwise it compares boots through `compare_boot_ids()`
   (which says "equal" for different machines); then realtime, then the data hash. Mixing sequence numbers, boots and
   realtime makes it a total order only for journals whose sequence numbers rise with time, whose monotonic time rises
   within a boot and whose machines' realtime clocks agree with their boots; on other input it can have cycles, and the
   output then depends on which file the scan visits first, in main as in the PR and in g.

## 5. Assessment (facts)

| | PR #44579 | prototype g |
|---|---|---|
| sequential archived files (rotation) | per entry O(1); O(F) at each file boundary and each second | O(log F) per entry |
| interleaved files | O(F) per entry (no change) | O(log F) per entry |
| many boots, several machines | as main when interleaved | flat in the three-machine test |
| matches, reverse | same path, same gain | same path, same gain |
| one live file | shortcut off in follow mode while it is at EOF; on for non-follow `journalctl` | live (not archived) files are walked linearly each call (O(U)), the archived ones through the queue; correct in the follow test, not measured with many files |
| follow mode, files added or removed | cache dropped on add and remove | queue dropped on add, remove, seek, match change; rebuilt by the next linear walk (O(F log F)) |
| code | +89 -5 in `sd-journal.c`, +6 in the header, +46 test | about 225 lines added in all, no test |
| uses `ASSUME_IMMUTABLE` | yes (keeps the shortcut) | no: it keys on each file's header state ARCHIVED; the flag could replace it |
| assumptions | the 1 s refresh interval; the winner's next entry compared with a cached runner-up | archived files do not change while open; the comparison is a consistent order |
| review | automated review done, nine items, eight fixed; no human review yet | none |

**Does either remove the F-dependence for interleaved files?** The PR does not (measured: identical to main). g does
(flat, 2.5 to 2.7 microseconds with one machine and 1.8 to 2.0 with three, from 25 to 400 files).

**What g would need before it could be proposed upstream** (facts from the tree at the base):
- **A test.** There is none. `test-journal-interleaving.c` creates journals programmatically; forced-on, it found a real bug
  in the first version (the queue was built while files were unsettled after a seek). A test needs at least 16 archived
  files (or a lower threshold), seeks in both directions, matches, files added and removed, and several machine IDs.
- **Rebase on main.** It applies to `32d75628c4` with offsets. It conflicts textually with the PR in `real_journal_next()`.
- **`docs/CODING_STYLE.md`:** lines of about 109 columns at most (two added lines are 110 and 120); component prefix in the
  subject ("sd-journal: ...") and no `Signed-Off-By`; use the `tests.h` assertion macros in tests; `_cleanup_` destructors;
  the prototype's `#ifndef HEAP_MIN_FILES` is a test hook the tree does not otherwise use. Comments belong in the code, not the pull-request
  text.
- **clang-tidy.** The tree's agent-guidance file (below) says to run the clang-tidy suite of every changed directory before
  committing; it was not run on g.
- **The README marker rule.** The agent-guidance file at the tree's root (`CLAUDE.md`, headed `AGENTS.md`) says, as a "HARD RULE":
  when modifying any source file, prepend the two lines `> [!IMPORTANT]` and `> Remove this line to confirm you've
  reviewed this PR before submitting.` to `README.md` if not already present, and never remove them (a human author removes
  them to confirm review). **I did not apply it**: nothing was committed to a systemd tree; the rule is recorded here only.
- **The contribution policy** (`docs/CONTRIBUTING.md`, "Policy on the use of LLMs and AI tooling"): the author must understand
  and be able to explain every part; "Do not let an AI agent open pull requests or post for you"; text written for the project
  must be written by the author; pull requests are made against a recent tip of `main`; the local test suite must pass
  before posting.
- **Open design points.** Ordering on inputs where `compare_locations()` is not transitive (section 4: g and the PR behave
  as main does, with different arbitrary results); whether the queue should key on `ASSUME_IMMUTABLE` rather than on the
  header state; memory: one priority-queue index per file; the interaction with the PR if both were to land (both rewrite the
  same function).

**What I could not do.**
- **No follow-mode timing with many files and a live file,** so the PR's follow-mode cost and g's O(U) are analysed, not measured.
- **The real journal was not compared byte for byte at this base** (it was, for g, on the earlier base); the new real-journal
  numbers are rates only. The real journal is live and re-listed before each run.
- **No human-written review comment on the PR exists to quote beyond yuwata's one line.** The rest is an automated review.
- **The "which is right" question has no answer where the order is undefined** (section 4); I could only show that all three
  disagree and that main's own output is incomplete there.
- **Disk:** the interleaved sets are 13 GB under `<work dir>/data/inter-sets` (regenerable with
  `scripts/make-interleaved-sets.py`); the host disk is at 80 %.

## 6. Commands

`<work dir>` is the scratch directory; scripts use `$WORKDIR` and `$REPO`.
```console
$ <work dir>/bin/fetch-pr.sh                                   # GET requests only; git fetch of pull/44579/head
$ <work dir>/bin/dk.sh inside-build-pr.sh e2 p2 g2             # the three builds in the container
$ <work dir>/bin/dk.sh inside-mkint.sh                         # the interleaved sets
$ <work dir>/bin/run-host-pr.sh                                # host rates: synthetic, interleaved, reverse, matches, real journal
$ <work dir>/bin/run-host-pr2.sh                               # whole-journal reads of the sequential sets
$ <work dir>/bin/run-pr-after-host.sh                          # libsystemd for the API test, correctness pass 1, unit tests
$ <work dir>/bin/run-correct2.sh                               # correctness pass 2
$ <work dir>/bin/analyse-pr.sh <tsv>                           # medians and exponents
```

| file | what |
|---|---|
| `data/pr44579-digest.txt`, `data/pr44579-f26f6637ac-commit.diff` | the PR as fetched, and its commit |
| `data/rates-summary.txt`, `data/pr-*.tsv` | rates (columns: env, variant, set, K, run, lines, seconds, IO stall in microseconds) |
| `data/g2-on-32d75628c4.diff` | the prototype on the PR's base |
| `test/` | the correctness scripts and outputs; `correctness-pass1-output.txt` is superseded for its int/seq sets (hard links across filesystems failed) and its live test (an unset library path), both redone in pass 2 |
| `scripts/` | the scripts |
