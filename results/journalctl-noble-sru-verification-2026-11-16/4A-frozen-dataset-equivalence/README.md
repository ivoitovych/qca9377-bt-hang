# 4A: frozen-dataset equivalence, stock 255.4-1ubuntu8.19 against the 8.20 test build

Result: **no difference.** 36 comparisons over four frozen fixtures (9 queries each), every command exited 0, every
output was non-empty where output was required, and the sha256 of stock and patched output is identical in all of them
(`VERDICT ... SAME`; see `4A.txt`). Nothing was INVALID or DIFFERENT.

## What was compared

Stock = `255.4-1ubuntu8.19` from noble-proposed (obtainable; 8.18 was not needed). Patched = the 8.20 test debs (8.19 plus
99e6f682d3 and 51b2bcf835). Package hashes: `../scripts/PACKAGES.txt`. Both builds were run unpacked
(`../scripts/inside-extract.sh`) inside the ubuntu:24.04 image of `../scripts/Dockerfile`, against `--directory=<copy>`, so
no live directory is globbed (this replaces step 4 of the old test plan).

## Fixtures (independent copies, `cp`, never hard links; names and sha256 in `FIXTURE-SHA256.txt`)

| fixture | files | size | content |
|---|---|---|---|
| synth-seq | 30 | 241 MB | first 30 files of the sequential synthetic set, archived, 5 files per boot |
| synth-int3m | 30 | 241 MB | 30 files of the interleaved three-machine synthetic set, all covering the same time range |
| noble-mixed25 | 25 | 929 MB | the 25-file system+user model of a default noble desktop (synthetic) |
| real12 | 12 | 433 MB | copies of 12 archived files of the laptop's journal (renamed real-NN; active files never touched) |

The real copies existed only in the work directory; only digests, counts and sizes are recorded here. They are deleted at
the end of Part 4 (the top README records the deletion).

## Method and termination

`../scripts/cmp-lib.sh` (`runq`) runs one query with each build against the same directory, records exit status, line
count, byte count and sha256 of stdout (TSV columns: fixture, query, build, exit status, lines, bytes, sha256), and prints
a `VERDICT` line: SAME, DIFFERENT, or INVALID (non-zero exit, a timeout, or empty output where output is required).
Termination: every command ends by itself; the cap is 7200 s per command (never reached). Queries (`inside-4A.sh`):
`-o export` forward, `-o export -r`, `--list-boots`, `-b <newest boot id>`, `-k -b <newest boot id>`, `-u <unit>`,
`-n 100`, `-n 100 -r`, `-o export -n 100`. Commands: `prep-4A.sh` (copies), `run-4A.sh` (runs `inside-4A.sh` in the container).

## Table (stock output; the patched output has the same lines, bytes and sha256 in every row)

| fixture | `-o export` lines | bytes | `-k -b` lines | `-u` (unit) lines | all verdicts |
|---|---|---|---|---|---|
| synth-seq | 780000 | 28073283 | 10000 | 1 (`-- No entries --`) | SAME |
| synth-int3m | 390000 | 13379858 | 10000 | 1 (same) | SAME |
| noble-mixed25 | 28260480 | 982323218 | 18985 | 61446 (cron.service) | SAME |
| real12 | 24038888 | 795464835 | 1481674 | 6 (systemd-logind.service) | SAME |

The `-u` queries on the synthetic sets print only the "No entries" line, so they say little; the other queries carry the
equivalence. Raw rows with all hashes: `4A.txt`.
