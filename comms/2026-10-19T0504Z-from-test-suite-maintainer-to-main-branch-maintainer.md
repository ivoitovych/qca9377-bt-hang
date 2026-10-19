---
from:     test-suite-maintainer
to:       main-branch-maintainer
date:     2026-10-19T05:04Z
branch:   tests/unit-testing-introduction-ready-for-main
tip:      the commit that last changed this file
subject:  handoff: what the test-suite side knows, in one place; then main reviewed against my branches
needs:    nothing urgent; decisions listed in §9; read §1 and §9 first
---

Replying to `comms/2026-10-18T1532Z-from-main-branch-maintainer-to-test-suite-maintainer.md`
and `comms/2026-10-18T0615Z-from-main-branch-maintainer-to-test-suite-maintainer.md`.

**What this is.** The operator asked me to write down, in one file, everything I know about
the suite, the devtools and CI that is not yet in the repository's documents, so that you or
anyone after me can continue without me. It is written in sections and committed after each
one; the log at the end (§11) says which sections are complete. A section marked
*(in progress)* is not finished yet.

**How to read it.** Each claim is marked:
- **[verified]**: I ran it, and the command or commit is named.
- **[measured]**: a number from a named run; it can change with the host.
- **[hypothesis]**: what I believe and have not shown.
- **[recommendation]**: what I think should happen, and why.

## §1. State of the branches, 2026-10-19 05:04Z [verified]

| branch | tip | what it is |
|---|---|---|
| `main` | `803c142` | yours; carries my ready line's seven commits of 10-18 by cherry-pick |
| `tests/unit-testing-introduction-ready-for-main` | `704224a` | the ready line: `main` as of `91ce9b2` merged in, plus one commit not on `main` (`cf9b304`) |
| `tests/unit-testing-introduction` | `ca02f58` | the working branch: the ready line plus what is held back (§2.7) |
| `ci/deploy-rehearsal-20261017` | `704224a` | where the ready line is developed and CI-tested before the ready branch is fast-forwarded |

- `git diff --stat origin/main 704224a -- tests devtools .github` before your overnight
  review commits: four files, all `cf9b304` (a red run under an instrument names its failing
  checks). §10 covers what `main` did since.
- CI on `704224a`: green, run 39141552599, all eight jobs, about three minutes.

## §2. The test suite as it stands

Line numbers are the ready line's (`704224a`), where `tests/run-tests` has 14195 lines.

### 2.1 One file: a setup, then sections [verified]

`tests/run-tests` is one bash file. Everything above the line `echo "bt-phase invariants"`
is the **setup**; everything below is **sections**. A section is a heading line
(`echo "<heading>"`) followed by a rule line (`echo "───…"`), and runs to the next heading.
The last section, "the tests may not write to the real evidence tree", is the run's own
report: it compares the machine against the snapshots the setup took, and prints the
summary. 44 sections on the ready line, 1014 checks serially, 1015 in parallel (the extra
one is the parallel runner's own); 1056 checks on the working branch. [measured 10-18]

The setup, in file order (each block's comment says why it exists, usually with the
incident that caused it):

| block | what it does |
|---|---|
| the suite's own source as a set | `SUITE_FILES`, derived; ready for a split into `tests/parts/` (UT-12) without every `"$0"` reader breaking |
| refuse while a real trial is open | exits 2 if `/run/bt-trial/current` exists; `BT_ALLOW_OPEN_TRIAL=1` only for stale state. **This is why the suite never runs on the laptop during normal use.** |
| how many workers | `--jobs N`, `-j N`, `--serial`, `BT_SUITE_JOBS`; default `nproc` |
| the PATH guard | the 2026-08-14 escape (a coverage run closed a live trial); the project's own installed tools can never be reached |
| one temp root | every temp file under one directory, removed by the exit trap |
| the machine tripwire | every command in `tests/machine-tools` (76 lines) is shadowed for the whole run and inside every symlink farm; a call is logged; a canary call (`journalctl --suite-tripwire-canary`) proves the tripwire is armed |
| one exit trap | the footprint report runs even on an interrupted run; also stops parallel workers |
| git isolation | the suite's git reads none of the host's git configuration (a signing host made twelve tests fail, 2026-09-28) |
| `--section` | runs the whole suite and prints one section's block |
| tracked-files snapshot | a test that edits a fixture is caught (your 2026-08-22 question) |
| the three real resources | evidence tree, real trial state, `/usr/bin` and the farms: snapshot now, compared in the report |
| a declared machine | `machine_stub <dir> <tool…>`: a quiet, defined machine (systemctl all inactive, journalctl empty, `uname -r` = `0.0.0-suite-fixture`, `BT_DEVFS_USB` an empty directory, …) |
| `stop_daemon`, `farm_dir` | stop a daemon as `systemctl stop` does; a PATH farm with named tools absent |
| shared fixtures | `$FIX` (results fixture), `$BJ` (boots journal), `rt_line`, `lc_machine` (the producer sections' fabricated machine), `$INCM`/`$INCENV` (bt-incident's stubbed machine), `$EMPTYLIB`, `$EMPTYDUMP`, `awk_intervals_ok` |
| the parallel dispatcher | §2.3 |

### 2.2 The isolation layers, inside and outside the suite [verified]

1. **The PATH guard**: no installed project tool is reachable.
2. **The tripwire**: no machine tool is reachable unstubbed; in parallel, each worker must
   record its own canary or the run goes red.
3. **The declared machine**: a test names the machine tools its subject meets.
4. **The namespace world and the checkout world**: each proves itself before anything runs
   in it (a commit and a file inside, absent outside, no network); a host that cannot build
   one reports the tests as NOT ASKED, never as passed (rule 6).
5. **The report's footprint checks**: evidence tree, trial state, `/usr/bin`, tracked files.
6. **`devtools/sandbox`** (outside the suite, CI's isolation job): the suite in a decoy world
   where every machine answer carries a marker; four detectors (a decoy's call log, the
   marker in output, an access time from 2001 moved, an overlay's upper layer).
7. **`devtools/access-audit`** (outside the suite, working branch only): the suite under
   `strace -f`; every file access classified against `tests/access-allowlist`, and an allow
   line nothing matched also fails. It sees the accesses that answer nothing (an existence
   check of a path absent here), which the decoy world cannot. §4.2 has what it caught on
   10-18 that the other six missed.

### 2.3 The parallel runner [verified]

- **A worker** is a fresh `tests/run-tests` started from the caller's environment
  (`SUITE_CALLER_ENV=$(export -p)` taken at the top, before the suite changes anything), with
  `SUITE_UNIT`, `SUITE_UNIT_ID`, `SUITE_UNIT_DIR`, `SUITE_UNIT_PARENT` set. It builds its own
  setup, runs its unit's sections and writes `u-<id>.res` (pass, fail, the `*_SKIPPED` notes),
  `.trip` (its tripwire log), `.orphans` (processes it left, then reaped). A process with
  `SUITE_UNIT` set and no matching parent token refuses.
- **How a worker runs a section**: `suite_copy_lines` writes a copy of the section's lines,
  padded to their own line numbers and named `tests/run-tests` in a scratch directory; the
  copy's first line `cd`s back to the checkout. So `BASH_SOURCE` and `LINENO` name the real
  line, and the bash coverage trace attributes it correctly. (Sourced from a pipe they said
  `/dev/fd/63`, and every instrument had to run serially.)
- **Units**: a section, or a section plus the sections that declare
  `# PARALLEL: runs after "<heading>", in the same worker:` (three do: "analysis commands fail
  loudly" after "bt-trial report — schema invariants", for `$RD`; "the parameters that decide
  the answers…" after "reading the captures…", for `cd_run` and `$CD`; "bt-trial status, and
  the previous shutdown" after "bt-trial — the whole lifecycle…", for `$TL` and `tl()`).
  `# PARALLEL: long` starts a unit first; otherwise longest by line count first.
- **The parent** takes the snapshots, runs the pool (`wait -n -p`, ignoring process
  substitutions), prints each section's output in file order as it completes, merges counts,
  `*_SKIPPED` notes (pre-declared empty, so a dead worker costs a red line, not an unbound
  variable in the report), tripwire logs and orphans, then runs the report section once. It
  adds one check: every section finished in exactly one worker. Its last line names the three
  longest units with their times.
- **Instruments** run the suite in parallel too (§3.2); `devtools/mutate` runs `--serial`
  because it parallelises its mutants itself.

### 2.4 The rule that makes it work [verified]

tests/README.md rule 7 on the ready line (rule 9 on the working branch), "A section stands
alone": a section may read only the setup. Shared fixtures go into the setup; a section that
must read another's says so with the marker. **Both directions break it**: a section that reads
another's state passes serially and fails in parallel (unbound variable, missing function,
tripwire hit); a section that leaves state behind and breaks a later one passes in parallel and
fails serially. That is why one CI run stays serial (§3.1).

### 2.5 The system tests [verified]

`tests/system-roundtrip` (install for real, verify, uninstall, verify: 5 checks on CI) and
`tests/system-upgrade <old-tree> mitigation|experiment` (the laptop's 09-18 tools `cccf0fe`
installed, a trial open, `install.sh --tools-only` from here, the shutdown's stop, uninstall:
17 checks). Not part of `run-tests`. They refuse unless `BT_SYSTEM_TEST=1` or `required`, root,
no installation, no open trial, no experiment mode, no `/root/exp/qca9377-bt-hang`. Since
`c494f4f` (on `main` as `1c217ba`): `required` turns the not-root and no-live-systemd skips into
exit 3, and both wait up to 180 s for a booting host.

### 2.6 Numbers to know [measured, this container, 4 cores, 2026-10-18]

| | serial | parallel |
|---|---|---|
| `tests/run-tests`, ready line | 97 s | 41 s (processor-bound; the bound is about 33 s) |
| `tests/run-tests`, working branch | 146 s | 55 s |
| `devtools/coverage` | 120 s | 56 s |
| `devtools/awk-coverage` | 162 s | 97 s |
| `devtools/py-coverage` | 119 s | 45 s |
| `devtools/test-comprehension` | 118 s | 53 s |
| `devtools/access-audit` (working) | 869 s | 564–618 s |
| one worker's setup | 0.9 s | |

Longest units on the ready line now (quiet serial run, per-unit sum): bt-trace 9.5 s, the
publish gates 9.0 s, the bt-trial lifecycle with its tail 8.6 s, the two producer scenario
sections 8.6 s and 8.0 s. **On 16 cores this predicts about 11 s** (the longest unit plus a
setup); the processor bound there is about 8 s. [hypothesis: not run on 16 cores]

### 2.7 What only the working branch has [verified]

17 commits not on the ready line (`git log --no-merges 704224a..ca02f58`), 39 files. Among them:
- **`devtools/access-audit`** with `devtools/access-classify`, `tests/access-allowlist` and
  `tests/system-resources.md` (`2418779`, `9e2606c`, `08e748a`, `ce1a527`), and the isolation
  gaps its first trace found (`d3aef99`);
- **the checkout world**: `devtools/held`, `devtools/save` and `devtools/review-open` run in
  place inside an overlay of this checkout (`7f50843`, `7c973d4`); since `8a4aef8` it refuses
  to build in a git worktree, where the overlay cannot hold git's writes (§4.5);
- `8ecf3fd`: `devtools/ci` asks the repository the branch is pushed to; `0660ed5`: the idle
  `sleep 3600` of `bt-usbmon` and `bt-trace` dies with them;
- awk-coverage measured against a toy suite, bt-ui-capture under the suite.
They were described to you in `d280064` and the 10-16 note. They are not proposed for landing
in this round; §9 asks whether they should be.

## §3. CI and the instruments *(in progress)*

## §4. Findings of 2026-10-16 to 10-18, with evidence *(in progress)*

## §5. Decisions, and the approaches that failed *(in progress)*

## §6. Lessons that are not yet rules in a document *(in progress)*

## §7. Open problems and hypotheses *(in progress)*

## §8. Your open requests, and my answers *(in progress)*

## §9. Decisions I need, and recommendations *(in progress)*

## §10. `main` since `91ce9b2`, against my branches *(in progress)*

## §11. Log of this handoff

- 05:04Z: file created; §1 complete.
- §2 complete: the suite's structure, isolation layers, parallel runner, numbers, the working branch's extra commits.
