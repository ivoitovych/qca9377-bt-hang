# 4B: archived files removed under an open reader (stock 8.19 against the 8.20 test build)

## Answer

**No stock/patched difference was found.** The single case that looked worse for the patched build in the first pass
(sd-journal API reader, forward, files truncated, victim = the file being read: stock 0 of 6 failures, patched 3 of 6)
was timing luck: over 56 runs per build stock failed 17 times and patched 21 times (Fisher exact p = 0.55). Every failure
there is the reader process being killed by SIGBUS (exit status -7), in both builds. After about 1400 runs no cell differs at
p < 0.05 (`4B-stats.txt`).

## Setup (disposable fixtures in the container of `../scripts/Dockerfile`)

Fixture: 16 archived files (4 boots x 4 files), 600 entries each, `MESSAGE=B f<file> e<entry>`, written by
systemd-journal-remote. Every run uses a fresh COPY (own inodes; with hard links nlink stays above zero and the
deallocation would not happen). A reader consumes slowly; when it has read K entries (K random, 150 to ~8000, same seed
sequence for both builds) the victims are removed (`run4B.py`):

* readers: `jc-fwd` (`journalctl -o export`), `jc-rev` (`-r`), `jc-follow` (`-f -n all`), `api-fwd` and `api-bwd`
  (`reader.c`, the sd-journal API: `sd_journal_open_directory`, `sd_journal_get_fd`, `next`/`previous`, `get_data`,
  `sd_journal_process` every 100 entries, 10 ms pause), each linked against the build's own `libsystemd.so.0`;
* removals: `unlink` (plain `unlink()`), `dealloc` (what `unlinkat_deallocate()` of v255 `src/basic/fs-util.c:697` does:
  open `O_WRONLY|O_NONBLOCK|O_NOFOLLOW`, unlink, fstat, then `fallocate(PUNCH_HOLE|KEEP_SIZE)` over the size rounded up to
  the block size; this file system supports hole punching, so the file keeps its size and reads as zeros), `truncate` (unlink,
  then `ftruncate(0)`: the fallback of `unlinkat_deallocate` where hole punching is unsupported);
* victims: `current` (the file the reader is in), `future` (next file in reading order), `future2` (the next two after
  that), `past` (the file before);
* per run recorded: exit status, stderr, entries output, entries missing from the surviving files, duplicates, entries
  read from removed files, order (columns of the TSVs).

Controls (no removal) read all 9600 entries, ordered, exit 0, in both builds. Termination: each run ends when the reader
exits, or after 30 s of no output (4 s for the follower, which is then stopped with SIGTERM).

Passes: first pass `4B.tsv` (751 runs, 6 repetitions per cell, `inside-4B.sh`); the api-fwd/truncate/current case,
`4B3.tsv` (50 runs per build, 20 `unlink` runs per build, and 12 runs per build under gdb; `inside-4B3.sh`); the noise
check of every cell the first pass had flagged, `4B4.tsv` (20 runs per build per cell, `inside-4B4.sh`). Statistics over
all three: `4B-stats.txt` (`stats4B.py`: failures = exit status other than 0, Fisher exact test on failure counts); the
first-pass per-cell table is `4B-first-pass-summary.txt`.

## Results by removal mode

| removal | what both builds do (identical in stock and patched) |
|---|---|
| `unlink`, any victim | no error, exit 0, nothing missing: the reader keeps its open file descriptors and reads the deleted files to the end (entries from removed files counted in the TSV) |
| `dealloc` (hole punch), victim current or past | exit 0, no errors; |
| `dealloc`, victim future / future2 | journalctl: exit 1 `Failed to iterate through journal: Bad message` in most runs, stock 22 of 26 and patched 20 of 26 (`jc-fwd`); API readers: mostly continue (stock 1 of 26 returns -74 = EBADMSG, patched 0 of 26) |
| `truncate`, victim future / future2 | journalctl: same exit 1 `Bad message` in both (jc-fwd future: stock 20 of 26, patched 18 of 26; jc-rev future: 22 and 19 of 26). The API reader dies with SIGBUS in about 40% of runs in both (api-bwd future: stock 11 of 26, patched 9) |
| `truncate`, victim current / past | journalctl: exit 0 (it installs a SIGBUS handler; the data of the dropped file is lost, nothing else). API reader: SIGBUS in about 30% of runs in both builds |

Selected cells from `4B-stats.txt` (failures / runs; "miss" = mean entries missing from surviving files):

| reader / removal / victim | stock | patched | Fisher p |
|---|---|---|---|
| api-fwd / truncate / current | 17 / 56 | 21 / 56 | 0.55 |
| api-bwd / truncate / current | 10 / 26 | 4 / 26 | 0.12 (patched better, not significant) |
| api-bwd / truncate / future | 11 / 26 | 9 / 26 | 0.78 |
| jc-fwd / dealloc / future | 22 / 26 | 20 / 26 | 0.73 |
| jc-fwd / truncate / future | 20 / 26 | 18 / 26 | 0.76 |
| jc-rev / truncate / future | 22 / 26 | 19 / 26 | 0.50 |
| jc-rev / dealloc / current | 2 / 26 | 0 / 26 | 0.49 |
| api-fwd / dealloc / future | 1 / 26 | 0 / 26 | 1.0 |
| all `unlink` cells (any reader) | 0 failures | 0 failures | 1.0 |

The follower (`jc-follow`) rows only compare exit behaviour: its entry counts are limited by the harness (it stops after
4 s without output, so even the controls read only ~2400 of 9600 entries in both builds); do not read completeness from them.

## The api-fwd / truncate / current case in detail

* Which call fails: the process is killed by SIGBUS (exit status -7), not an error return. Under gdb (12 runs per build,
  `4B3.tsv`, messages column) the patched build stops in `journal_file_read_tail_timestamp` at `sd-journal.c:2413`
  (reading `f->header->state` through the mmap of the file header), called from `next_beyond_location` /
  `real_journal_next`; the stock build stops in an unresolved function of `libsystemd.so.0` called from `main` (the stock
  debug symbols were not downloaded, so it is not named; the same header is read in the stock iteration).
* Why: the library does not install a SIGBUS handler. In v255 `journalctl` and `journald` call `sigbus_install()`
  (`src/journal/journalctl.c:2210`, `journald.c:49`); the small API program of this test does not, so a truncated mapped
  file kills it. `journalctl` itself did not die by SIGBUS in any of its runs. The cached tail offset (`newest_entry_offset`)
  is not involved: the faulting access is the header page, which both builds read in the same iteration step.
* Is stock's 0 of 6 real? No, luck: the observed stock failure rate is 17/56 = 30%, so six clean runs have a probability
  of about 12%. Patched 21/56 = 38%; the two rates are statistically indistinguishable.
* Mapped pages of a truncated file are the failure in both builds; the 2024 commits neither add a new kind of access nor
  remove one.

## Notes

* The upstream change 101b8633c2 ("journal: recover iteration over vacuumed files") is in neither build and was not
  tested; the `Bad message` exit seen here (journalctl, forward and reverse, with future files deallocated or truncated)
  is the behaviour it addresses, and it is identical in stock and patched.
* A real vacuum deletes the OLDEST archived files; a forward reader reaches those first, so `past`/`current` are the
  likely roles for a vacuum under a `journalctl` that has just started; `future` is the risky one and fails equally in both.
* A second pass `4B2` (more repetitions of every first-pass cell) was stopped before it finished;
  its partial output is not used.
