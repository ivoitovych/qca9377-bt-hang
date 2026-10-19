# tests

```bash
tests/run-tests                       # every invariant, its sections on every core
tests/run-tests --serial              # the same run in one process, in file order
tests/run-tests --jobs 4              # at most 4 workers at a time (or BT_SUITE_JOBS=4)
tests/run-tests --section "stage2"    # one block, without a sed range
devtools/check                        # what to run before committing
devtools/coverage                     # how much of the shell these actually run
```

Exit status is the suite's. `--section` filters the output but still reports the
whole run's verdict — a section with no failures must not look like a pass for a
run that failed elsewhere.

## What is being asserted

Not "does the code work". **Every invariant here encodes a defect that really
shipped in this repository**, with a fixture built so the OLD behaviour fails
it. The suite exists because an external review found the prose had run ahead of
the code: `bt-phase`'s header claimed it used only exogenous timer-driven probes
while the implementation kept probes 600 s apart and called that provenance.
Every commit message described the intended behaviour correctly. Only reading
the implementation found the gap.

Comments cannot be executed. These can.

## The house rules

**1. A new check must be observed to fail.** A test that has never gone red is
evidence that the test ran, not that the invariant holds. This repository has
shipped several checks that could not fail — the SCO cross-tab never executed at
all (a braceless `if`), and `bt-verify-install` reported a clean system from a
hand-maintained list missing six tools. Each printed a tick.

```bash
devtools/assert-test-catches tools/bt-state 'x=$(journalctl -k | grep -c "tx timeout")' \
                             "spelling the timeout pattern differently"
```

It appends the violating line, runs the suite, asserts a **failing** line
matches, and restores the file on every exit path including interrupt. Note it
only *appends*: for an invariant that a trailing line cannot disturb, break the
decision by hand, watch it go red, and put it back.

**2. Lists are derived, never written by hand.** The set of shell files comes
from a shebang scan over `git ls-files`. Hand-maintained path lists have failed
here four times, most recently by omitting `install.sh` — which held the exact
defect the check was hunting.

**3. Fixtures, never the live journal.** Testing through `journalctl` would make
the results depend on the machine's own history, which is the thing under
investigation. It would also make them unrepeatable.

**4. Nothing may touch the real evidence tree.** `bt-trial` runs the real
`bt-incident` on a failed trial, and `bt-incident` resolves its destination from
`BT_EVIDENCE_REPO` — a *different* variable from the `BT_REPO` the tests
redirect. One call site missed a stub, and once the machine's own controller
died, every run of this suite deposited a fabricated incident directory into
`evidence/sessions/`. Ten accumulated beside one genuine collection. Now:
- every `bt-trial` call goes through one of five wrappers (`trial`, `trial_in`,
  `tl`, `tlt`, `tlnh`), and a check requires each to set both `BT_REPO` (where
  `results.tsv` is written) and `BT_EVIDENCE_REPO` (where `bt-incident` writes);
- a second check fails on a spelled-out `tools/bt-trial <verb>` call outside
  them (the read-only `report` calls set `BT_REPO` on their own line);
- `BT_EVIDENCE_REPO` points at the declared machine for the whole run, so a
  forgotten seam writes there, not here;
- and at the end, `final_resource_report` compares `evidence/sessions/`, the
  real trial state, every tracked file and `/usr/bin` with how they were before
  the run, from the EXIT trap too.

**5. No verdict may come from the machine.** Rule 3 said it about the journal;
on 2026-09-29 `devtools/sandbox` measured what it missed. Run in a world whose
every answer disagrees with every fixture, the suite made 312 calls of real
machine tools per run — 20 of them `logger`, writing "TRIAL stock #1 START" into
the real journal — read the host's USB tree, btusb parameter, boot id and install
stamp, created `~/bt-journal-archive` beside the real archives, and 12 of its
verdicts changed with the machine. Here and in CI those answers were empty,
which is what an empty fixture returns, so every one of them passed.

The layers, from cheapest to strictest:

- **The machine tripwire.** Every command in [`machine-tools`](machine-tools)
  answers from a tripwire for the whole run — nothing, exit 1, one logged line —
  and `farm_dir` links it in place of the real binary. A test whose subject meets
  one of those tools *declares* it: `machine_stub <dir> systemctl uname …` gives
  a quiet, defined machine (no unit running, an empty readable journal, a kernel
  release no machine has, a `logger` that writes a file). The run fails on any
  call that reached the tripwire, naming the tool, its caller chain and the
  assertion before it. A canary proves the tripwire is recording.
- **The declared machine.** `/proc`, the USB bus, btusb's parameters, the
  Bluetooth class, the install stamp, the unit directory, the health directory
  and the journal archive all resolve through `BT_*` seams, and the suite points
  every one of them at a declared machine for the whole run: empty, except a
  fixture `/proc` (a boot id, an uptime, a modules line with btusb loaded). A
  test that needs a device builds one; a test that forgets meets that machine,
  never this one.
- **The PATH guard.** Every name `install.sh` puts in `/usr/local/bin` or
  `/usr/local/sbin` answers first from a recording stub that prints nothing, so
  no test can reach an installed copy of a project tool. The cost: a tool that
  calls a sibling "where installed" meets the stub, never the sibling. Before
  2026-10-16 no close of a trial had run with the real `bt-state` and `bt-mark`,
  and the real `bt-state`'s whole-boot journal read, ahead of the results row,
  could cost the row at shutdown. Where it matters a test puts the real
  siblings first on the PATH, in install.sh's layout (`lib/` beside them).
- **The decoy world**, [`devtools/sandbox`](../devtools/README.md), in CI: the
  whole suite in namespaces where every machine answer is marked, every real
  directory is under a throwaway overlay, and four detectors — calls, marked
  output, reads, writes — must all stay silent.

The one sanctioned door to the real machine is `real_tool <check> <tool>`, for a
contract check that compares a fixture's shape with the real tool's output (the
coredumpctl contract). The sandbox lists those calls apart, and an invariant
keeps the tag they carry inside that function.

**6. A namespace is only worth its proof.** A seam replaces the default it guards,
so the shipped paths (`/var/log/bt-health/ui`, the kernel's dynamic-debug control
file, `/usr/share/applications`, the effective uid) never run under a seam. Where a test needs them, it runs
the tool inside `unshare -Urm` with a tmpfs over each real path. That's root
without a seam, on paths only that process tree can see. Before anything runs in
it, the namespace proves itself:
- a marker file created inside each redirected directory must be readable inside;
- the same file must not exist on the machine afterwards, an existence test that
  reads nothing real;
- the uid inside must be 0.

A namespace that fails this proof is a red invariant, and nothing runs in it. A
host that cannot build one (Ubuntu 24.04's default, CI before its sysctl) reports
the tests as **not asked**, never as passed. The proof was seen to fail: with its
tmpfs over `/var/log` removed, the suite went red on exactly that check, and
nothing ran inside.

The **checkout world** does the same for tools that act on the checkout they
live in: `devtools/held`, `devtools/save`, `devtools/review-open`. They switch
branches, commit and push, so they run in place under `unshare -Urmn`. An
overlay of the checkout is mounted over its own path, and a network namespace
cuts it off. Every write lands in a throwaway layer, and every push reaches
only scratch bare repositories. The world's proof:
- a file and a commit made inside are there inside, absent outside;
- HEAD, every ref and the status are unchanged outside;
- the real origin is unreachable from inside.

It was seen to fail both ways. Without the overlay, the proof commit landed in
the checkout. Without the network namespace, origin answered. Each time the
world went red and nothing ran in it. It sets its own git identity and accepts
a shallow push, because CI's checkout has neither. It is built only where the
checkout holds its own git directory: in a git worktree the overlay cannot hold
the writes. Its tests are four sections (held; held sync; save; review-open),
and each proves its own world before anything runs in it.

**7. An instrument is measured too.** `devtools/awk-coverage` runs the suite,
so the suite never ran it, and its counting was trusted unseen. `BT_SUITE` now
points it at a toy suite whose right answer was worked out by hand. Measured
that way (2026-10-08), it had three counting errors, all making the figure low:
- one program run by three scripts was filed as three programs;
- gawk's `BEGIN {` / `END {` headers, which never carry a count, were counted as
  statements that never ran;
- repo-validate's parse check of every `*.awk` file over `/dev/null` filed each
  file a second time.

89.8% of 1941 statements became 97.8% of 1340 (on this line, 2026-10-19: 89.6% of
2224 became 97.7% of 1447). A suite run inside a suite run is
refused (`SUITE_RUN_ID`), so an instrument that loses its seam stops at once
instead of starting the suite inside itself.

**8. An access that answers nothing is still an access.** The tripwire catches a
machine *tool*. The decoy world catches a machine *answer*, by its marks and by
access times. Neither sees these:
- an existence check of a path that is absent here;
- a read of a file that is missing in CI and present on the laptop;
- a lookup of a path no test names.

Each passes everywhere except where it matters. `devtools/access-audit` runs the
suite under `strace -f` and classifies every file access, made or attempted, by
where it landed:
- the run's scratch space;
- the checkout;
- system software;
- a namespace world's own mounts;
- the machine.

An access to the machine fails the audit unless
[`access-allowlist`](access-allowlist) names it with a reason, and an allow line
nothing matched fails it too.

Its first run (2026-10-09) found nine kinds of access the decoy world had passed:
- jq's `~/.jq`, git's `~/.config/git/ignore` and `/etc/gitattributes`, and
  Python's user site-packages;
- the real trial state, read by repo-save's tests;
- the real `/var/log/bt-health/trace`, read by `bt-status` and `bt-incident`;
- the real `/etc` and `/usr/local`, read by `uninstall.sh`'s dry run and by
  `verify-restored.sh`;
- `/tmp` outside the run.

Each was a seam to declare, not a line to allow. The run now has a home of its
own, its own trial state, and a health directory every tool derives its trace,
capture and usbmon directories from. The audit's self-test plants each kind of
access, and each must be caught. It also runs clean controls: scratch, software,
a checkout read, a namespace world's own mount and an allowed path, and none
may be flagged. CI runs the full audit as a job of its own.

CI's first audit found more, from what CI has and this host lacks:
- the checkout world's network proof resolving github.com through the host's
  `/etc/resolv.conf`;
- `id -g` for the bt-ui-capture tests' user, answered by systemd's user
  database;
- Ubuntu's crash reporter, run by a Python syntax error `repo-validate` left
  uncaught;
- `pkill -f` reading every process on the runner;
- the coredump contract reading the host's journal;
- the journal-contract phase that the suite could not use.

Each was closed by a seam or a change in the test, except two kinds:
- **The coredump contract's reads.** They go through `real_tool`, the suite's
  one door to the real machine, and the audit classes them as `contract`.
- **What the AT-SPI test's private `dbus-daemon` asks about its clients.**
  These are allow lines for that command only, tied to that check.

**9. A section stands alone.** A run hands its sections to worker processes, as
many at a time as there are cores (`--jobs N` caps them; `--serial` runs one
process in file order). Every worker builds the setup at the top of `run-tests`
afresh: its own guard, tripwire, declared machine and temp tree. So a section
sees that setup and nothing else, whatever ran before it in the file.
- **Shared fixtures and helpers belong in the setup.** `farm_dir`, `$FIX`,
  `$INCENV`, two empty fixtures and the awk interval probe moved there on
  2026-10-18.
- **A section that reads what an earlier one built says so**, under its heading:
  `# PARALLEL: runs after "<heading>", in the same worker:` and what it reads.
  Three do, each because it reads a fixture its parent builds and removes.
  `# PARALLEL: long` starts a section first when its length in lines
  understates its time.
- **A fixture several sections build alike is a setup function**: `lc_machine`
  builds the producer sections' fabricated machine, once in each.
- **The parent process keeps the run's account.** It takes the before-snapshots,
  merges what the workers hand back (counts, output printed in file order,
  tripwire logs, each with its worker's canary, the processes they left, the
  NOT ASKED notes), and runs the last section, the run's own report, once over
  the whole run. A parallel run adds one check: every section finished in exactly
  one worker.
- **How this was established (2026-10-18).** Each section was run alone with only
  the setup, and gave the serial run's verdicts, except six that read another's
  definitions. Four of those were fixed by moving fixtures into the setup, two by
  the marker. The first parallel run found two more: an unbound `$EMPTYLIB`,
  and, by the tripwire, 39 unstubbed `bt-incident` calls (`$INCENV` lived in the
  watchdog section). Then the two modes were compared check by check:
  the same 1012 checks in the same order.
- **The instruments measure a parallel run.** A worker runs each of its
  sections from a copy of their lines padded to their own line numbers and named
  `tests/run-tests` (`suite_copy_lines`), so a trace, an error message and
  `devtools/coverage` see the real file and line, not `/dev/fd/63`. Bash, awk
  and Python coverage, comprehensiveness, the decoy world and `access-audit`
  all run the suite in parallel. Compared with serial runs of the same tree (2026-10-18): every
  line, statement and Python line a serial run covers, a parallel run covers;
  the only additions are the parallel runner's own lines. `devtools/mutate`
  runs `--serial`, because it runs its mutants in parallel itself.
- **What breaks it, both ways.** A section added later that reads another's
  state passes serially and fails in parallel: an unbound variable, a missing
  function, or a tripwire hit. A section that leaves state behind (a variable, a
  stub on `PATH`, a file in a shared temp tree) and so breaks a later one passes
  in parallel, where the later one gets a fresh process, and fails serially. CI
  runs the suite in parallel in repo-validate and under every instrument, and
  serially in a job of its own, so both modes run on every push.

Measured here on 4 cores (2026-10-19): 142 s serially, 59 s in parallel; the
work is processor-bound. With cores to spare the floor is the longest unit
instead, and a parallel run names its three longest on its last line, with their
times. A section that tops that line is the next to split, at a boundary where
nothing below reads what was built above. On 2026-10-18 four sections were split
that way (the watchdog section, about 25 tools in 3232 lines, into six; the
bt-trial lifecycle, the producer and bt-trace), and the longest of those units
went from about 27 s to 10 s. On 2026-10-19 the checkout world, one section of
about 40 s, became four, each proving its own world; the longest two are now
held's and save's, about 20 s each, most of it repo-save validating and scanning
the whole checkout inside the world. On 16 cores that predicts about 21 s (20 s
for the longest unit and 0.9 s for a worker's setup; the processor bound there is
about 9 s). It is a prediction: no 16-core host has run it yet.
Under the instruments, serial against parallel (2026-10-18, before the access
audit and the checkout world): bash coverage 120 s and 56 s, awk 162 s and 97 s,
Python 119 s and 45 s, comprehensiveness 118 s and 53 s.

## Fixtures

| Path | Feeds |
|---|---|
| `phase-invariants.data` | `phase.awk` — probe/timeout records, `<boot> <kind> <timestamp>` |
| `stage2-invariants.data` | `stage2.awk` and `bt-stage2 --from` — journal lines across five boots |
| `trial-results.tsv` | `trial-summary.awk` / `trial-sco-table.awk` |
| `journal/phase/` | `bt-phase` end to end, via `BT_JOURNAL_FIXTURE` |
| `journal/provenance/` | `bt-boot-provenance` end to end |
| `journal/crash/` | `bt-crash` — three boots: two segfaults at one offset, one segfault, and two binaries competing for the majority |
| `journal/snapshot-bluez/` | `bt-snapshot`'s BlueZ section — boot 0 is the `EX-032` shape (clean controller, dead daemon), boot -1 a quiet day ending in an rfkill block |
| `coredump/held/` | `bt-crash` — a core store with two `bluetoothd` cores, a `btmon` core and an unrelated one, via `BT_COREDUMP_FIXTURE` |
| `coredump/nonbt/` | `bt-crash` — a store holding cores, none of them Bluetooth's |
| `fixtures/<library>/` | golden cases for `stage2.awk`, `trial-sco-table.awk` and `trial-summary.awk`: `<case>.in`, `.expected` (stdout and stderr), `.rc` |
| `btmon/` | decoded `btmon` text for the capture readers ([its README](btmon/README.md)) |
| `sanitize-invariants.log` | `sanitize-logs.sh` |

`journal/` holds 46 directories in all; the table names the ones a reader meets
first, and each test names the one it uses.

### Driving a tool without a journal

Tools that read the journal go through `bt_journal` in
[`tools/lib/journal.sh`](../tools/lib/journal.sh). Point `BT_JOURNAL_FIXTURE` at
a directory and the query is answered from a file instead of the host:

```bash
BT_JOURNAL_FIXTURE=tests/journal/provenance tools/bt-boot-provenance
```

Files are chosen from the query — `list-boots.log`, `unit-<name>.log`,
`kernel.log`, `default.log` — with an optional `.b<boot>` infix taking
precedence, so a fixture only spells out the boots a test distinguishes. A
missing file is an empty journal, not an error, which is what a real journal
returns for a unit that never logged.

Only tools that source `journal.sh` can be driven this way. An invariant asserts
that no converted tool has quietly regained a direct `journalctl` call, because
the seam is worth nothing if it is not the only way in.

### Driving a tool without a retained core

`bt-crash` answers from two sources, and the second is
[`tools/lib/coredump.sh`](../tools/lib/coredump.sh). `BT_COREDUMP_FIXTURE`
works the same way, with files chosen from the verb:

```bash
BT_JOURNAL_FIXTURE=tests/journal/crash \
BT_COREDUMP_FIXTURE=tests/coredump/held tools/bt-crash
```

`list.txt` answers `coredumpctl list` and **must carry the header row**, because
every caller strips one; `info-<pid>.txt` answers `coredumpctl info <pid>`. A
missing file means "no cores", which here means **exit 1**, not exit 0 — that is
what the real tool does with nothing retained, and journal.sh's rule is *be the
honest analogue*, not *always exit 0*.

A fixture is a claim about the real tool's output, so the suite checks three of
them — the header row, the pid being whitespace field 5, and `info` carrying a
`Stack trace of thread` line — against real `coredumpctl` whenever the host has
a core to ask about, and says out loud when it could not.

## The system tests: the round trip and the upgrade

`tests/system-roundtrip` and `tests/system-upgrade` are the two tests that write
to the machine. They are not part of `tests/run-tests`, and CI runs them on its
ephemeral VM.

The round trip runs `install.sh --apply`, verifies, runs `uninstall.sh --apply`,
and checks that nothing survives. It tests the claim `install.sh` makes in its
header, that uninstalling is a complete restoration. That claim is a property of
the install/uninstall PAIR, so it cannot be established by reading either script.
The pair has already shipped out of step, twice.
- **Until 2026-10-16 it never ran.** It asked `systemctl is-system-running`,
  which exits non-zero for `degraded` too, and a CI VM is commonly degraded. It
  skipped on every CI run, and the step passed. It now asks that systemd is
  PID 1 and running or degraded, and a skip names the state it saw.
- **On 2026-10-18 it skipped again, from a new cause.** With CI's checks split
  into parallel jobs, it ran ten seconds after its runner booted, met systemd
  still `starting`, and the step passed. Both tests now wait (up to 180 s) for a
  booting host to finish, and CI runs them with `BT_SYSTEM_TEST=required`: on a
  host chosen to run them, a skip exits 3, and the step fails.
- **On CI two of its checks still skip**, for want of bluez: `bt-verify-install`
  and `verify-restored.sh`. Its direct check covers the `install_file`
  destinations only, not the files `install.sh` writes by redirect (udev rules,
  drop-ins, the stamp).

The upgrade rehearsal is what the investigation machine's next deploy does.
- **The setup.** The tools that machine runs (the 2026-09-18 tree, `cccf0fe`) are
  installed for real. The old `bt-trial` opens a trial, optionally under
  `bt-mode experiment`. Then this checkout is deployed over it with
  `install.sh --tools-only`, followed by `systemctl daemon-reload`.
- **The shutdown.** `systemctl stop bt-trial-auto`, as a shutdown runs it,
  closes the old trial with the new `bt-trial`.
- **The way back.** `uninstall.sh --apply`.
- **What it asserts** (17 checks):
  - the deploy ran nothing but file operations;
  - every destination holds the new file, and nothing else changed (a hash
    snapshot of every place an install writes, redirect-written files included);
  - no `.pre-qca9377-bt-hang` copy of the project's own files;
  - units, the open trial's state, the mode stamp and the `.disabled` files are
    all as before, also after `daemon-reload`;
  - the close writes its row inside the stop timeout, and the installed
    `report` reads it;
  - after the uninstall, every watched path is as it was before the old install.
- **What it cannot show:** the controller, btusb with E3, that machine's kernel.

```bash
BT_SYSTEM_TEST=1 tests/system-roundtrip                       # plus root, and see below
BT_SYSTEM_TEST=1 tests/system-upgrade <old-tree> [mitigation|experiment]
BT_SYSTEM_TEST=required …                                     # as CI runs them: a skip fails
```

Both refuse unless every gate holds:
- `BT_SYSTEM_TEST=1` (or `required`) set explicitly — no default, no flag a shell history could
  replay by accident
- no existing installation (`/usr/local/share/qca9377-bt-hang` absent)
- no open trial, no experiment mode — the two states in which an install is
  known to destroy a measurement in progress
- a live systemd, or it skips: without one `install.sh --apply` cannot succeed
  and the failure would describe the host, not the installer. Under
  `required`, that skip and the not-root one are failures instead
- for the upgrade, also: no `/root/exp/qca9377-bt-hang` (that machine's checkout)

The investigation machine fails the second gate even if the variable is set.

## Coverage

`devtools/coverage` runs the suite under `xtrace` and records every line bash
actually executed. It is a **lower bound**, so use it to rank files and watch a
trend, not as an exact figure:
- a command spanning several lines is traced at one of them: a simple command at
  its first line, a command substitution or a backslash-continued assignment at
  its last, an array literal at its closing line (`devtools/coverage-exclude`
  says which ranges this moves);
- `case` labels are never traced;
- a tool run through a symlink is counted under the link's path.

Coverage is not a target. "Every test encodes a defect that shipped" is the
rule; the percentage is a ratchet in CI to stop it falling silently as tools
grow. The current figures are CI's: the coverage, awk, python and
comprehension steps each print theirs and hold a floor (80, 85, 80 and 75 on
the branch `main` takes). [The 2026-08-13 assessment](../reviews/2026-08-13T1214Z-unit-testing-assessment.md)
is where the measurement started (65 invariants, 13% of lines), not where it
stands.
