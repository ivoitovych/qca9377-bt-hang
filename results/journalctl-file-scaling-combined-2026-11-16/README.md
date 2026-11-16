# The PR's winner/runner-up check and our priority queue, combined (2026-11-16)

Part 1 of three. Question: if the cached winner of upstream PR #44579 and our priority-queue prototype (g) are put
together, does one build keep the PR's speed on sequential (rotated) files and g's on interleaved files, and does it
still print what unpatched main prints?

**Where and how.** The laptop (16 cores), measurements on the bare host, one run at a time at `nice -n 19` and
`ionice -c 3`; builds and tests in a container (`make`/`ninja -j4` at most), nothing installed on the host. Base is main at
`32d75628c4`, the PR's parent. Another experiment was running on the machine, so absolute rates carry some noise.

## 1. The builds

| name | what | diff kept |
|---|---|---|
| e2 | main at `32d75628c4` | |
| p2 | e2 + PR #44579 (head `f26f6637ac580c02f9cb845b40b128378fdc97f2`) | |
| g2 | e2 + our prototype (applies cleanly, offsets only) | |
| **pg2a** | **heap only.** The prototype on the base, plus the PR's test; the PR's cache is not there, because the heap makes it redundant (a file that wins repeatedly is just the top of the queue) | `data/pg2a-on-base.diff` |
| **pg2b** | **the PR's check as a fast path in front of the heap.** The PR head with the prototype put on top, the two conflicting hunks resolved by hand (below) | `data/pg2b-on-pr-head.diff` |

How pg2b works. `real_journal_next()` first tries the PR's `journal_next_from_previous_scan()` (the file the last entry
came from wins again if its next entry is strictly ahead of the cached runner-up); if that gives up it uses the heap
(`heap_next()`); if the heap is not valid it does the linear scan and builds the heap. The two parts needed gluing:
1. the heap path does not hold the file the last entry came from (it is popped), and the fast path advances only that file,
   so after a fast-path step the state is exactly what `heap_next()` leaves, and no extra bookkeeping is needed;
2. the PR's cache must be refilled when the heap path chooses an entry, or the fast path would never be used after the
   first heap step. `heap_next()` now computes the runner-up (the best candidate of all other files: the queue's top after the
   pop, and the best two of the files that are not archived) and stores winner, runner-up, direction and a one second
   validity, but only after the same file has won twice in a row, and not when a non-archived file is at its end while
   reading forward (the PR's own rule, waived for `ASSUME_IMMUTABLE`).
The PR's `scan_*` fields are cleared on every heap step before being refilled, and on adding or removing a file as in the PR.

## 2. Rates on the host (lines per second, median of 3 runs; `data/pg-*.tsv`, `data/rates-summary.txt`)

`-o short` into a line counter, at most 200 000 lines or 45 s; the "whole" rows read the whole journal (up to 2 million
lines or 150 s). The last column is the exponent b of the time to read everything (2 = quadratic, 1 = linear). The IO
stall of each run is the last column of the TSV.

| layout | variant | 25 | 50 | 100 | 200 | 400 | 800 | b |
|---|---|---|---|---|---|---|---|---|
| sequential | e2 | 314 491 | 233 121 | 139 567 | 51 086 | 19 627 | 7 383 | 2.28 |
| | p2 | 438 632 | 442 518 | 444 444 | 421 053 | 423 729 | 390 625 | 1.04 |
| | g2 | 387 628 | 369 037 | 344 234 | 297 177 | 264 901 | 236 128 | 1.17 |
| | pg2a | 370 400 | 367 680 | 348 432 | 298 954 | 269 906 | 230 415 | 1.17 |
| | **pg2b** | 434 817 | 446 469 | 434 783 | 442 478 | 433 839 | 406 504 | **1.03** |
| sequential, whole | e2 | | | 137 187 | | 32 566 | 12 887 | 2.12 |
| | p2 | | | 439 602 | | 392 966 | 416 166 | 1.03 |
| | g2 | | | 336 166 | | 255 616 | 229 151 | 1.19 |
| | pg2a | | | 340 748 | | 276 366 | 229 446 | 1.18 |
| | **pg2b** | | | 443 501 | | 426 936 | 382 630 | **1.06** |
| interleaved, 1 machine | e2 | 352 113 | 344 828 | 291 545 | 224 719 | 133 601 | | 1.45 |
| | p2 | 367 647 | 344 828 | 297 619 | 226 501 | 132 714 | | 1.45 |
| | g2 | 390 625 | 400 000 | 400 000 | 398 406 | 377 358 | | 1.03 |
| | pg2a | 396 825 | 406 504 | 409 836 | 409 836 | 382 409 | | 1.03 |
| | **pg2b** | 396 825 | 400 000 | 400 000 | 408 163 | 318 471 | | **1.10** |
| interleaved, 3 machines | e2 | 435 273 | 361 978 | 242 160 | 139 665 | 75 103 | | 1.76 |
| | p2 | 447 477 | 361 978 | 246 382 | 142 959 | 72 727 | | 1.77 |
| | g2 | 576 867 | 584 734 | 587 077 | 557 103 | 523 560 | | 1.06 |
| | pg2a | 583 902 | 598 909 | 581 897 | 560 224 | 524 934 | | 1.06 |
| | **pg2b** | 537 978 | 581 294 | 585 340 | 549 451 | 526 316 | | **1.05** |

Per-entry cost in microseconds at the largest K: sequential (800 files) p2 2.6, g2 4.2, pg2a 4.3, **pg2b 2.5**;
interleaved 1 machine (400) p2 7.5, g2 2.7, pg2a 2.6, pg2b 3.1; interleaved 3 machines (400) p2 13.8, g2 1.9, pg2a 1.9,
pg2b 1.9; e2 135, 7.5 and 13.3.

**Reading it.**
- **pg2b keeps both gains.** It matches the PR on sequential files (2.3 to 2.5 microseconds per entry from 25 to 800
  files, the PR's 2.2 to 2.6) and matches g on interleaved files (1.9 microseconds with three machines at 400 files, against
  the PR's 13.8). pg2a (the heap alone) equals g2, as expected: the PR's cache adds nothing to a queue except where
  the queue's own cost is the limit, which is what the fast path in pg2b removes.
- **pg2b is a little slower than g2 in one cell:** interleaved, one machine, 400 files: 3.1 against 2.7 microseconds in the
  median (one of its three runs was 0.82 s against 0.52 s; the other two match g2). Not repeated.
- **No variant makes anything worse for e2's best cases**; at 25 files the differences are within 15 %.

## 3. Correctness against e2 (`test/`)

Byte for byte, SHA-256 of the complete `-o export` output, e2 the reference; the same 24 query kinds and 7 sets as the
336 comparisons of the earlier page (`plain`, `interleaved` with 12 overlapping boots, `twomachines`, `int1-50`, `int3m-50`,
`int3m-100`, `seq-100`), now for pg2a and pg2b: 336 comparisons, **all identical** (34 have an empty result and are trivially
equal: the single-boot sets have no boot to match).

| check | result |
|---|---|
| a file still being written, followed by `-f`, then a file added to the directory while following (e2, pg2a, pg2b as concurrent readers) | follow reads identical (21 943 entries), final reads identical (24 800) |
| files added and removed while the directory is read through the API with inotify active (42 scenarios per build: newer, interleaved, older and other-machine files added; a future file, the current file and 20 of 24 files removed; forward and backward; with no match, a match on every entry, an OR of two boots; monotonic time rising across the files of a boot) | pg2a and pg2b identical to e2 |
| systemd's journal unit tests (`test-journal`, `-interleaving`, `-enum`, `-flush`, `-init`, `-match`, `-stream`, `-verify`, `-file`, `-send`, `test-mmap-cache`) | pass for pg2a and pg2b as built and with the queue forced on for any number of files (`-DHEAP_MIN_FILES=2`): 44 of 44; the PR's new test is in both |

Not repeated here: the journals that break journald's invariants (the earlier page, section 4), where no output is "right"
and all builds differ from main in arbitrary ways.

## 4. Does g still apply to main without the PR, and do the PR and g conflict?

(`data/apply-check.txt`, `scripts/inside-applycheck2.sh`.)
- **g on main without the PR: yes, cleanly.** `git apply --check` and `git apply --3way` succeed, with offsets only, on
  `6bd4689` (the base it was written against), on `32d75628c4` (the PR's base) and on main's tip when checked,
  `6016a8af8329646ae5e8bd5c4e9a390aea414729` (2026-11-16 10:51 +0100).
- **g and the PR conflict textually: yes, in two hunks of `sd-journal.c`** in both orders (the prototype on the PR head, and the PR
  commit cherry-picked onto the prototype): both insert code before `real_journal_next()` and both add their step at
  the end of it. The headers (`journal-internal.h`, `journal-file.h`) merge without conflict.

## 5. What was not done

- **pg2b was not read on the real journal for output identity in this part;** Part 2 does that.
- **The combined design is a prototype of a prototype**: the runner-up computation in `heap_next()` and the fast path's
  interplay with the queue are checked by 336 comparisons, the follow and API tests and the unit tests, not by a proof.
- **Two upstream-style problems carry over from g**: no test of its own for the queue (the PR's test is there), lines over
  109 columns in the added code, and the `#ifndef HEAP_MIN_FILES` hook.

## 6. Commands

`<work dir>` is the scratch directory; `scripts/` use `$WORKDIR` and `$REPO`.
```console
$ <work dir>/bin/dk.sh inside-mk-pg.sh                 # the combined trees, conflicts left in place (resolved by hand afterwards)
$ <work dir>/bin/dk.sh inside-build-pg.sh pg2a pg2b    # the builds
$ <work dir>/bin/run-host-pg.sh                        # host rates
$ <work dir>/bin/run-pg-after.sh                       # libsystemd for the API test, correctness, unit tests
$ <work dir>/bin/dk.sh inside-applycheck2.sh           # does g apply to main, does it conflict with the PR
$ <work dir>/bin/analyse-pr.sh pg-synth-seq.tsv ...    # medians and exponents
```

| file | what |
|---|---|
| `data/pg-*.tsv`, `data/rates-summary.txt` | rates (columns: env, variant, set, K, run, lines, seconds, IO stall in microseconds) |
| `data/pg2a-on-base.diff`, `data/pg2b-on-pr-head.diff` | the two combined builds as diffs |
| `data/apply-check.txt` | the apply and conflict checks |
| `test/` | correctness and unit-test outputs, and the scripts |
| `scripts/` | build and measurement scripts |
