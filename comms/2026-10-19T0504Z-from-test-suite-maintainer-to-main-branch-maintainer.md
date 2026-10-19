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

## §3. CI and the instruments

### 3.1 The jobs [verified: `.github/workflows/checks.yml` at `704224a`]

Eight jobs on eight runners at once (nine on the working branch). Each starts with the same
preamble: checkout at full depth, the public repository fetched as `public` (so
`doc-main-hashes` judges against the public `main`), `apt-get install gawk
systemd-journal-remote fakeroot` (plus `strace` on the working branch, whose suite runs the
access-audit self-test), and a version line.

| job | steps | runs the suite |
|---|---|---|
| suite | `repo-validate` (syntax, awk parse, invariants, doc drift, **the suite in parallel**); journal contract; `repo-scan . --all` | 1 |
| serial | `tests/run-tests --serial` | 1 |
| coverage | `devtools/coverage --quiet --min 80` | 1 |
| comprehension | `devtools/test-comprehension --min 75` (runs coverage itself) | 1 |
| awk-coverage | `devtools/awk-coverage --min 85` (95 on the working branch) | 1 |
| python-coverage | `devtools/py-coverage --min 80` | 1 |
| isolation | userns sysctl lifted; `devtools/sandbox --self-test`; `devtools/mutate --self-test`; `devtools/sandbox` | 1 |
| system | `BT_SYSTEM_TEST=required` round trip; the two deploy rehearsals over `cccf0fe` | 0 |
| access-audit (working only) | self-test; `devtools/access-audit --report`; upload the trace on failure | 1 |

A whole run takes about 2.5 to 3 minutes [measured: runs 39118779312, 39131271277,
39141552599]; it took about 9 minutes as one job before 10-18. The longest job is now
`serial` (about 2:20: a serial run on a 4-core runner).

### 3.2 Why the suite runs seven times per push [verified reasoning; recommendation at the end]

The operator asked why, and whether runs can be cut. They should not be, and here is why:

| run | what only it shows |
|---|---|
| `repo-validate` | the gate every commit passes; CI repeats it because the laptop's commits skip the suite while a trial is open, so CI is the first run for them |
| serial | a section that breaks a later one (the only mode where the later one inherits state) |
| bash coverage | which shell lines ran; a ratchet at 80% |
| comprehensiveness | per tool: modes, refusals, seams, branches reached; a ratchet on the weakest dimension of the worst unit at 75% |
| awk coverage | awk statements: bash's trace sees an awk program as one line |
| Python coverage | `bin/bt-capture` |
| decoy world | that no verdict depends on what the machine answers |
| (access audit) | every access, including those that return nothing; working branch only |

**They cannot share a run.** Each changes the run it measures: xtrace through `BASH_ENV` and
a descriptor in every bash; an `awk` shim; a Python `sitecustomize`; user, mount and pid
namespaces; `strace -f`, about six times slower and exclusive (ptrace cannot nest). Stacked,
their overheads add, and timing-sensitive checks fail for the wrong reason (§4.4 is one); and a
red would no longer say which property failed. The one true duplicate is comprehensiveness
re-running coverage instead of reading the coverage job's trace (`--dump DIR` exists for
that); since the jobs now run side by side, removing it would save runner minutes and no wall
time. [recommendation: keep all seven]

### 3.3 The instruments, briefly [verified]

- **`devtools/coverage`**: a `BASH_ENV` file sets `PS4='+@@C@@${BASH_SOURCE}@@${LINENO}@@'`,
  `BASH_XTRACEFD=9` and xtrace; every bash the suite starts inherits it. Executed lines are
  joined with coverable lines. A **lower bound** (a multi-line command is traced at one of its
  lines; `case` labels never). `devtools/coverage-exclude` lists ranges with a reason each; a
  range that the trace shows executed fails the run ("the exclusion is stale and is hiding live
  code"), so **every edit above an excluded range must re-derive it by content**. This bit me
  three times on 10-18 (§6).
- **`devtools/awk-coverage`**: an `awk` shim that execs `gawk --profile=<unique>` per process,
  with the caller's command line beside it; profiles hashed by program, merged.
- **`devtools/py-coverage`**: a `sitecustomize.py` on `PYTHONPATH` starts `trace.Trace` and
  writes one counts file per pid at exit.
- **`devtools/test-comprehension`**: asks coverage for its tables (`coverage --dump`), then
  scores each unit on asserts, modes, refusals, seams, branches.
- **`devtools/sandbox`**, **`devtools/mutate`** (applies each listed mutant, runs the suite,
  lists survivors), **`devtools/journal-contract`**, **`devtools/access-audit`**.
- **Since `cf9b304` (not yet on `main`)**: when the suite goes red under coverage, awk or
  Python coverage, the instrument prints the failing checks of the run it measured, and
  comprehensiveness no longer discards what coverage said. Before, a red under an instrument
  could not be named (§7.1).

## §4. Findings of 2026-10-16 to 10-18, with evidence

Already sent and not repeated here: the 10-16 notes (`comms/2026-10-16T1528Z…`,
`…T2022Z…`: the close could lose its row where the tools are installed; `bt-trial` alone is a
partial deploy; the round trip had never run), the 10-17 note (the deploy rehearsed in CI; an
upgrade took the project's own files for foreign ones) and the 10-18 note (the SCO decode ran
before the row; `299a0b3`, on `main` as `c1883b4`).

### 4.1 What crossed between sections, found by splitting [verified]

The setup-only rule (§2.4) was established by running every section alone, then by parallel
runs, where an unbound variable names what crosses. Found and fixed, in order:
- run alone (10-18, before the runner): `$FIX`, `farm_dir`, `$RD`, `cd_run`/`$CD`, the awk
  interval probe, a fixture repository; four moved to the setup, two became chains;
- the first parallel run: `$EMPTYLIB`, unbound; and **39 calls of `bt-incident` that reached
  `systemctl` and `journalctl`, caught by the tripwire**, because the publish gates drove
  `bt-incident` through `$INCENV`, built in the watchdog section;
- the watchdog section's split (`e57c1bb`): `$BJ` (through the chain), `ex_awk_ok` (a copy of
  the setup's probe, read by a later block);
- the bt-trial lifecycle's split (`04f994c`): `rt_line` (a retention helper the snapshot and
  crash tests used), and the snapshot fixture `$SN`, which outlived the first cut point;
- my own first timing line: an associative-array lookup inside `$(( ))` is an arithmetic syntax
  error, and **bash abandoned the whole dispatch block and ran the remaining sections in the
  parent**; the report's own check went red ("of 36 sections, 5 finished in a worker").

### 4.2 The real `python3` ran the watchdog's USB reset [verified]

- **What.** The watchdog's no-probe scenario copied `systemctl`, `sleep` and `loginctl` into its
  own stub directory but not the `python3` spy every other scenario uses, and its farm linked
  the real interpreter. The watchdog's `usbfs_reset` therefore ran its ioctl program in the
  real `python3` against the declared usbfs root, where it failed (no device node).
- **Why it showed only now.** The scenario used to be stopped at startup (§4.3); once it ran to a
  recovery, the reset ran every time.
- **Who saw it.** Not the decoy world (`python3` is not a machine tool) and not the suite. The
  working branch's CI access-audit job did, run 39129858672: 30 accesses outside the allow list,
  all by `python3 - 3 99 …/machine/devfs-usb`: Ubuntu's apport hook, on the uncaught
  `FileNotFoundError`, read `/etc/default/apport`, apt's configuration, `/var/lib/dpkg/status`,
  `/etc/os-release`. Locally the same exec showed in the trace as `noprobe-farm/python3` (this
  container has no apport). Read from `python3-apport` 2.28.3's `apport_python_hook.py`: the hook
  reads `/etc/default/apport` on **any** uncaught exception, before it decides anything.
- **Fixed** in `e57c1bb` (on `main` as `6640bb7`): the copy includes the spy, and a check
  requires the reset in the spy's log. Red before, green 3 of 3 after. The ready line carried the
  leak for one commit (`fb297d7`); harmless where it ran (the declared root has no device), but a
  real-tool call.

### 4.3 A watchdog check that judged nothing about half the time [verified]

The no-probe test stopped the watchdog at "cannot be confirmed", the warning it prints at
startup. In about half the runs no recovery had run yet, and "an unverifiable recovery is not
counted as a failure" passed with nothing to judge. Seen as coverage of `bin/bt-hang-watchdog`
lines 139, 244 and 245 coming and going between identical runs. A mutant counting the
unverifiable answer as a failure passed 1 run in 6. Now it stops at "suppressed by cooldown"
(logged after the answer is counted), and a new check requires the recovery to have run:
the mutant fails 6 in 6 (`fb297d7`, on `main` as `6b007df`).

### 4.4 A deadline that was a budget [verified]

The bt-capture rotation check gave the capture `--duration 5` for 1.2 MB of frames. Under
`strace` with four workers a correct build did not reach 1 MB in time ("rc=0 files=1
prune_calls=1"). Reproduced on one core shared with eight busy loops: 5 s failed the same way,
30 s passed twice. The deadline only ends a broken build; it is 30 s (`e57c1bb`).

### 4.5 The checkout world wrote through a git worktree [verified; working branch only]

Run from a `git worktree`, the checkout world's overlay covered the worktree directory, but
`.git` there is a file naming the main repository's directory, outside the overlay. **The
world's proof commit landed in the shared repository, and the world's `git config user.name
"Checkout World"` / `user.email world@example.com` replaced the shared `.git/config` identity.**
The proof saw the moved refs and went red, but after the writes. I restored the identity and the
refs by hand. `8a4aef8` adds `co_git_inside`: both the git directory and the common directory
must lie inside the checkout, or the world is NOT ASKED; a scratch repository and worktree pin
it. **If you run the working branch's suite from a worktree before `8a4aef8`, check
`.git/config`'s identity afterwards.**

### 4.6 CI's install tests skipped silently after the split [verified]

In the first run of the six-job layout the system job started ten seconds after its runner
booted; `systemctl is-system-running` said `starting`; the round trip and both rehearsals
skipped and their steps passed (run 39114530101, 0 s each). Fixed by `required` mode and a
bounded wait (`c494f4f`); the next run took 69, 84 and 14 s and passed 5, 17 and 17.

### 4.7 The SCO decode check's record time [verified]

The fast-`btmon` stub printed the time it ran as the record's time; under strace the close was
slow enough that the record fell a second after the window's end, and a correct decode went red.
The time is now fixed after the trial opens and before its close (`376b4d1`, on `main` as
`315437a`).

### 4.8 Host facts that cost time [verified]

- `devtools/sandbox` cannot build its world in this cloud container (rc=99 before any probe, the
  same on an unchanged tree): its self-test fails here. CI runs it green.
- In this container's locale a grep bracket expression with `✓`/`✗` matched nothing; compare
  check lines with Python or a literal sequence.
- `wait -n` returns process-substitution pids too; the pool ignores pids it did not start.
- Editing a tracked file while a suite runs in the same checkout makes that run fail its
  tracked-files check: twice on 10-18 that was me.

## §5. Decisions, and the approaches that failed *(in progress)*

## §6. Lessons that are not yet rules in a document *(in progress)*

## §7. Open problems and hypotheses *(in progress)*

## §8. Your open requests, and my answers *(in progress)*

## §9. Decisions I need, and recommendations *(in progress)*

## §10. `main` since `91ce9b2`, against my branches *(in progress)*

## §11. Log of this handoff

- 05:04Z: file created; §1 complete.
- §2 complete: the suite's structure, isolation layers, parallel runner, numbers, the working branch's extra commits.
- §3 and §4 complete: CI's jobs, why seven runs, the instruments; the findings of 10-16 to 10-18 with their evidence.
