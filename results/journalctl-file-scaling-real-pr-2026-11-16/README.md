# PR #44579, our priority queue and the combined build on the laptop's real journal (2026-11-16)

Part 2 of three. The real journal is the one the slowdown was found on; this page reads it with five builds of
`journalctl` from main at `32d75628c4` (the PR's base).

| name | what |
|---|---|
| e2 | main at `32d75628c4` |
| p2 | e2 + upstream PR #44579 (`f26f6637ac`) |
| g2 | e2 + our priority-queue prototype |
| pg2a | heap only (the prototype, the PR's cache redundant) |
| pg2b | the PR's winner/runner-up check in front of the heap |

(The last two are described in `../journalctl-file-scaling-combined-2026-11-16/README.md`.)

**Method.**
- **Read only, in place.** The journal is read where it lives, with `--file=` arguments naming its files, never copied
  and never written; `journalctl` opens files read only. Nothing from the journal is kept here: only counts, times and
  SHA-256 digests.
- **Live journal.** It rotates, so the file list is made again just before each run, and a run is repeated if a listed
  file vanished before it opened. The number of files was 492 at the time ("all").
- **Priority.** Every run went through a wrapper at `nice -n 19` and `ionice -c 3`, one at a time. The machine was busy
  with another experiment, so absolute rates carry some noise.
- **Runs.** The newest K files by modification time (K = 25, 50, 100, 200 and all), `-o short` to a line counter (never
  kept), at most 300 000 lines or 60 s, 3 runs, median; the system's IO pressure is recorded per run (`data/real-pr.tsv`, last column).
- **Identity.** The newest 25 files, `-o export` forward and `-r`, each ending at a fixed time one hour back (the newest
  file is live, so without it two runs seconds apart would differ), with the same file list for all five builds.

## Rates (lines per second; `data/real-pr.tsv`, `data/rates-summary.txt`)

| build | 25 | 50 | 100 | 200 | all (492) | exponent b |
|---|---|---|---|---|---|---|
| e2 | 367 647 | 299 401 | 248 963 | 104 785 | 57 826 | 1.77 |
| p2 | 414 365 | 400 000 | 381 194 | 353 774 | 352 526 | **1.06** |
| g2 | 389 610 | 367 197 | 340 909 | 286 260 | 289 017 | **1.12** |
| pg2a | 376 884 | 371 287 | 340 909 | 284 630 | 288 184 | 1.12 |
| **pg2b** | 403 769 | 396 301 | 351 288 | 340 136 | 347 222 | **1.05** |

Per-entry cost in microseconds, 25 to 492 files: e2 2.7 to 17.3; p2 2.4 to 2.8; g2 2.6 to 3.5; pg2a 2.7 to 3.5; pg2b 2.5 to 2.9.
b is the exponent of the time to read everything over K >= 50 (2 = quadratic, 1 = linear).

**Reading it.**
- **Unpatched main** is at 17 microseconds per entry at all 492 files, six times its cost at 25 files.
- **The PR and the combined build are flat** (2.4 to 2.9 microseconds): this journal's files are sequential (rotated),
  the case the PR was written for. The PR is the fastest on it, the combined build within 3 %.
- **g and pg2a are flat too but a little higher** (3.5 microseconds at 492 files): the price of a queue operation per entry
  where the plain cached winner would do.
- **The real journal is mostly the sequential case,** and the interleaved gains of g (previous page) do not show here:
  only the system and the user journals of the same hours interleave, a few files at a time.

## Output identity (`data/real-identity.txt`)

The newest 25 files, ending one hour back: 2 108 395 entries in each direction.

| query | e2 | p2 | g2 | pg2a | pg2b |
|---|---|---|---|---|---|
| `-o export`, forward | `f073ab07eb568481` | same | same | same | same |
| `-o export -r` | `1fe4ea36f7ac6089` | same | same | same | same |

(SHA-256 of the whole output, first 16 hex digits; every build gives the same digest as e2, in both directions.)

## Commands

`<work dir>` is the scratch directory; the scripts use `$WORKDIR`.
```console
$ <work dir>/bin/run-real-pr.sh        # rates (measure-runs.sh, WHAT=real, 5 builds), then real-identity.sh
```
`scripts/measure-runs.sh` lists the files with `ls -t` just before each run and passes them as `--file=`; `scripts/real-identity.sh`
does the same once for all builds. Raw rows: `data/real-pr.tsv` (columns: env, variant, set, K, run, lines, seconds, IO stall in microseconds).

## Not done

- Not measured: follow mode on the real journal, and a build that reads it as another user. Only forward reads and the
  `-r` identity check were run, as asked.
- The identity check covers the newest 25 files, as asked, not the whole journal.
