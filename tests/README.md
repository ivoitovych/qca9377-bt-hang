# tests

```bash
tests/run-tests                       # every invariant, about a minute
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
`evidence/sessions/`. Ten accumulated beside one genuine collection. Every
`bt-trial` call now goes through the sandboxed `trial()` helper, and the last
check in the file counts `evidence/sessions/` before and after.

**5. No verdict may come from the machine.** Rule 3 said it about the journal;
on 2026-09-29 `devtools/sandbox` measured what it missed. Run in a world whose
every answer disagrees with every fixture, the suite made 312 calls of real
machine tools per run — 20 of them `logger`, writing "TRIAL stock #1 START" into
the real journal — read the host's USB tree, btusb parameter, boot id and install
stamp, created `~/bt-journal-archive` beside the real archives, and 12 of its
verdicts changed with the machine. Here and in CI those answers were empty,
which is what an empty fixture returns, so every one of them passed.

Three layers now, from cheapest to strictest:

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
  every one of them at an empty machine for the whole run. A test that needs a
  device builds one; a test that forgets meets that empty machine, never this one.
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
file, the effective uid) never run under a seam. Where a test needs them, it runs
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
a shallow push, because CI's checkout has neither.

**7. An instrument is measured too.** `devtools/awk-coverage` runs the suite,
so the suite never ran it, and its counting was trusted unseen. `BT_SUITE` now
points it at a toy suite whose right answer was worked out by hand. Measured
that way (2026-10-08), it had three counting errors, all making the figure low:
- one program run by three scripts was filed as three programs;
- gawk's `BEGIN {` / `END {` headers, which never carry a count, were counted as
  statements that never ran;
- repo-validate's parse check of every `*.awk` file over `/dev/null` filed each
  file a second time.

89.8% of 1941 statements became 97.8% of 1340. A suite run inside a suite run is
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

## The system round trip

`tests/system-roundtrip` is the one test that writes to the machine: it runs
`install.sh --apply`, verifies, runs `uninstall.sh --apply`, and checks that
nothing survives. It tests the README's front-page claim — *"uninstalling is a
complete restoration"* — which is a property of the install/uninstall PAIR and
so cannot be established by reading either script. The pair has already shipped
out of step, twice.

It is **not** part of `tests/run-tests`, and it refuses to run unless every
gate holds:

```bash
BT_SYSTEM_TEST=1 tests/system-roundtrip     # plus root, and see below
```

- `BT_SYSTEM_TEST=1` set explicitly — no default, no flag a shell history could
  replay by accident
- no existing installation (`/usr/local/share/qca9377-bt-hang` absent)
- no open trial, no experiment mode — the two states in which an install is
  known to destroy a measurement in progress
- a live systemd, or it skips: without one `install.sh --apply` cannot succeed
  and the failure would describe the host, not the installer

The investigation machine fails the second gate even if the variable is set.
CI runs it on an ephemeral VM.

## Coverage

`devtools/coverage` runs the suite under `xtrace` and records every line bash
actually executed. It is a **lower bound** — a command spanning several lines is
traced once, at its first line — so use it to rank files and watch a trend, not
as an exact figure.

Coverage is not a target. "Every test encodes a defect that shipped" is the
rule; the percentage is a ratchet in CI to stop it falling silently as tools
grow. See [the unit-testing assessment](../reviews/2026-08-13T1214Z-unit-testing-assessment.md)
for the measurement and what remains.
