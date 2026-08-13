# tests

```bash
tests/run-tests                       # every invariant, ~2 s
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

## Fixtures

| Path | Feeds |
|---|---|
| `phase-invariants.data` | `phase.awk` — probe/timeout records, `<boot> <kind> <timestamp>` |
| `stage2-invariants.data` | `stage2.awk` and `bt-stage2 --from` — journal lines across five boots |
| `trial-results.tsv` | `trial-summary.awk` / `trial-sco-table.awk` |
| `journal/phase/` | `bt-phase` end to end, via `BT_JOURNAL_FIXTURE` |
| `journal/provenance/` | `bt-boot-provenance` end to end |

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

## Coverage

`devtools/coverage` runs the suite under `xtrace` and records every line bash
actually executed. It is a **lower bound** — a command spanning several lines is
traced once, at its first line — so use it to rank files and watch a trend, not
as an exact figure.

Coverage is not a target. "Every test encodes a defect that shipped" is the
rule; the percentage is a ratchet in CI to stop it falling silently as tools
grow. See [`reviews/unit-testing-assessment.md`](../reviews/unit-testing-assessment.md)
for the measurement and what remains.
