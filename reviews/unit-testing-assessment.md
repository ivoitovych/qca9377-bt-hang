# Unit testing in this repository — an assessment

**Date:** 2026-08-13
**Scope:** whether to introduce unit testing, and in what form
**Method:** read every tracked shell script and awk program; ran `tests/run-tests`,
`devtools/repo-validate` and `devtools/check`; measured coverage by execution, not by
intent.

---

## Summary

This repository **already has a test suite, and it is better than most shell projects
ever get.** `tests/run-tests` asserts 65 invariants in 1.8 seconds, every one of them
derived from a defect that actually shipped here. `devtools/assert-test-catches` is
mutation testing. `devtools/check` is a single pre-commit gate. That is a real testing
culture, not a gesture toward one.

So the question is not "should this project have tests". It is **"what is the existing
suite not reaching, and what does it cost to reach it"**.

The answer is concrete:

| | |
|---|---|
| Shell scripts tracked | 42 |
| Shell scripts **executed** by the suite | **4** (`bt-phase` indirectly, `bt-trial`, `bt-incident` as a stub, `repo-validate`) |
| The other 38 | `bash -n` only — syntax, not behaviour |
| awk libraries | 6 (543 lines) |
| awk libraries with dedicated fixtures | 4, most with a single case each |
| Unmediated `journalctl` call sites | **109, across 27 files** |
| CI | **none** — no `.github/` |

One structural fact explains nearly all of it: **the tools call `journalctl` directly,
with no seam.** A script that shells out to the host journal on line 37 cannot be run
against a fixture, so it cannot be tested — only syntax-checked. Everything else in this
report follows from that.

My recommendation is **yes, extend testing — but in four staged steps, and do not adopt
a test framework.** Details in [Recommendations](#recommendations).

---

## 1. What exists today

### 1.1 `tests/run-tests` — 1038 lines, 65 invariants, 1.8 s

Four sections: `bt-phase` invariants, `bt-capdiff` matching, the sandbox, and the
ontology through the production producer. The design principles are stated in its own
header and they are the right ones:

- **Each test encodes a defect that really shipped.** "Comments cannot be executed.
  These can."
- **Fixtures are built so the OLD behaviour fails.** A test that passes against both the
  bug and the fix is not a test.
- **The shell-file list is derived, not hand-written** — from every git-tracked file
  carrying a shell shebang. The header notes that hand-written lists have failed here
  four times, most recently by omitting `install.sh`, which held the defect the check
  was hunting.
- **`--section` addressing**, so reading one block does not cost a `sed` range that a
  static analyser cannot distinguish from a rewrite.

The suite also protects itself: the last check asserts that running the tests added
nothing to `evidence/sessions/`, with the baseline taken before anything else runs. That
check exists because ten fabricated incident directories once accumulated in the real
evidence tree.

### 1.2 `devtools/assert-test-catches` — mutation testing, already present

Appends a violating line to a file, runs the suite, asserts a **failing** line contains
an expected substring, restores unconditionally including on interrupt. It matches on
`✗.*$WANT` specifically, so a test that merely *mentions* an invariant cannot be mistaken
for one that enforces it.

This is the single most valuable testing asset in the repository and it is worth saying
plainly: most projects that talk about unit testing never build this.

### 1.3 `devtools/check` — one gate

`repo-validate` (syntax + awk parse + invariants + doc drift) then an informational
install-state comparison that deliberately does not set the exit code. Correct
separation: whether the running machine matches the checkout is not a property a commit
can change.

---

## 2. Where the coverage actually stops

### 2.1 Only four scripts are ever executed

`bash -n` proves a file parses. It proves nothing about whether it computes the right
number. Of 42 tracked shell scripts, 38 have **no behavioural coverage of any kind**.

That set includes tools whose output lands directly in exhibits and commit messages:

| Tool | Lines | Produces |
|---|---|---|
| `tools/bt-stage2` | 79 | stage-2 survival windows, censoring |
| `tools/bt-boot-provenance` | 120 | per-boot shutdown target, gap, firmware time |
| `tools/bt-state` | 61 | the BT-1 timeout count |
| `tools/bt-status` | 146 | the at-a-glance health verdict |
| `tools/bt-interval` | 54 | the interval arithmetic quoted in exhibits |
| `bin/bt-hang-watchdog` | 373 | the intervention decision itself |

`bt-boot-provenance` is the sharpest illustration. It printed `hci=no` for all six boots
— including boots whose journal plainly contained the device — and that is what exposed
the `pipefail`/`grep -q` inversion. The tool was wrong for its entire life, in a way a
single fixture would have caught on the first run.

### 2.2 The `journalctl` coupling is the blocker

109 call sites in 27 files, invoked directly:

```
tools/bt-stage2:63    journalctl -k -b all --no-pager -o short-iso-precise > "$TMP"
tools/bt-phase:83     journalctl -u bt-health-snapshot.service -b "$b" ...
tools/bt-status:37    WD=$(journalctl -u bt-hang-watchdog -b 0 --no-pager ...)
```

There is no wrapper function anywhere in `tools/` or `bin/`. This is why the suite tests
what it can reach — the awk that consumes the journal — rather than the tools that
produce it.

### 2.3 The `bt-phase` extraction hack

To test `bt-phase`, the suite runs a Python regex over the tool's **source** and pulls its
awk body out:

```python
m = re.search(r"awk -v igap=\"\$INCIDENT_GAP\" -v period=\"\$TIMER_PERIOD\" '(.*)' \"\$DATA\"\s*$", s, re.S)
```

The test is coupled to the tool's source layout. Reformat that invocation — change the
variable order, break the line — and extraction fails loudly (there is an `[[ -s ]]`
guard, which is good). But the deeper problem is the one the suite documents 60 lines
later, about `bt-capdiff`:

> Testing the real file rather than a copy extracted from the caller means the test
> cannot pass against a matcher the tool no longer runs — which is precisely how the
> `-f` trap slipped through: an extracted copy worked in the test while the shipped
> invocation silently loaded nothing.

The repository already learned this lesson and already fixed it for `bt-capdiff` by
moving the matcher into `tools/lib/capdiff-match.awk`. **`bt-phase` is the last holdout
running the pattern that is known here to have hidden a real bug.**

### 2.4 The awk libraries are the cheapest untapped coverage

Six libraries, 543 lines, and they are *already* pure text transforms invoked as
`awk -f lib.awk fixture` → stdout. No refactor is needed to test them; the suite already
does exactly this. What is missing is **breadth**: most get one fixture exercising one
path. `stage2.awk` (153 lines) and `trial-summary.awk` (177 lines) carry the most
branching logic in the repository and have the thinnest fixtures relative to their size.

### 2.5 No CI, and one thing that would break it

Nothing runs unless a human runs `devtools/check`. The repository's own history is the
argument: multiple defects shipped and were found later by review or by a wrong number
appearing in output.

**A verified obstacle:** `devtools/repo-validate` guards `udevadm`, `jq`, `python3` and
`awk` with `command -v`, but **not `systemd-analyze`** (line 45). I confirmed the
consequence by re-running it with a PATH that excludes it:

```
✗ unit  systemd/bt-capture.service
✗ unit  systemd/bt-dyndbg.service
✗ unit  systemd/bt-hang-watchdog.service
✗ unit  systemd/bt-health-snapshot-event.service
rc=1
```

Nine false failures and a non-zero exit on any runner without systemd. This is a
two-line fix and it must land **before** CI, or the first green-field CI run is red for a
reason that has nothing to do with the code.

### 2.6 The suite is undiscoverable, and it is the largest file here

`tests/` does not appear in the README's "Repository layout" block. Neither
`devtools/check` nor `devtools/assert-test-catches` appears in the `devtools/README.md`
table. A contributor reading the documentation has no way to learn the gate exists.

That matters more than usual here, because `repo-validate` enforces a doc-drift
invariant. The testing tooling is the part of the repository its own drift check does not
cover.

Separately: at 1038 lines `tests/run-tests` is the **largest shell file in the
repository** — larger than any tool it tests. Commit `4c9b7b4` records that two instances
of the `grep -q` inversion were found *inside `run-tests` itself*, one in a check added
that same session. A test file large enough to hide its own bugs is a real risk, not a
stylistic complaint.

---

## 3. Is "unit testing" even the right frame?

Partly. Being precise about it changes what to build.

The existing suite is mostly **characterisation and invariant testing** — it pins
observable behaviour of whole tools against fixtures. For a project whose output is
*evidence in a bug report*, that is the correct primary discipline. A number quoted in an
exhibit is wrong or right; it does not matter which internal function produced it.

True unit testing — isolating a function and asserting on it — has a narrower but real
place here:

- **The awk libraries are genuine units.** Pure, deterministic, stdin→stdout. Test them
  as units.
- **Shell functions inside the tools are not reachable as units.** These are scripts, not
  libraries; sourcing one executes it. Making them unit-testable would mean splitting
  every tool into a sourceable library plus a thin driver — a large refactor, on tools
  installed to a machine that is mid-experiment, for less benefit than the seam work in
  Stage 3.

So: **unit-test the awk; characterisation-test the tools; do not restructure the tools
into libraries.**

---

## 4. Recommendations

Ordered by value per unit of risk. Stages 1 and 2 need no production changes at all.

### Stage 1 — make the existing suite visible and automatic *(low risk)*

1. Guard `systemd-analyze` in `repo-validate` with `command -v`, matching the four checks
   around it. Verified necessary (§2.5).
2. Add `tests/` to the README's Repository layout block, and `check` /
   `assert-test-catches` to the `devtools/README.md` table.
3. Add `tests/README.md`: how to run, how to add an invariant, and the house rule that a
   new check must be observed to fail via `assert-test-catches` before it counts.
4. Add a GitHub Actions workflow running `devtools/repo-validate` and `tests/run-tests`.
   The suite is 1.8 s and hermetic — it sandboxes `bt-trial` and asserts it wrote nothing
   to the evidence tree — so it is genuinely CI-safe today. Do item 1 first.

### Stage 2 — widen awk-library coverage *(low risk, highest value per hour)*

Give each of the six libraries a fixture directory and a table-driven runner:
`tests/fixtures/<lib>/<case>.in` + `.expected`, compared with `diff`. Start with
`stage2.awk` and `trial-summary.awk` — most branches, thinnest current coverage.

This is the step I would call "introducing unit testing" in the strict sense. It needs no
change to any shipped tool.

### Stage 3 — introduce a journal seam *(the unlock; do it incrementally)*

Add one sourceable helper:

```sh
# tools/lib/journal.sh
bt_journal() {
    if [[ -n "${BT_JOURNAL_FIXTURE:-}" ]]; then
        cat "$BT_JOURNAL_FIXTURE"
    else
        journalctl "$@"
    fi
}
```

Then every tool becomes runnable against a canned journal, and the other 38 scripts
become testable at all.

**Do not convert all 109 sites at once.** These tools are installed on a machine that is
mid-experiment, and a bad conversion corrupts observations rather than merely failing.
Convert in order of consequence — the tools whose numbers reach exhibits first:
`bt-state`, `bt-stage2`, `bt-boot-provenance`, `bt-interval`, then the rest. Each
conversion lands with the fixture that proves it, and each is checked with
`assert-test-catches`.

Add an invariant asserting no *converted* tool regains a bare `journalctl` call — the
same derived-list technique the `grep -q` check already uses, so the guarantee cannot
rot into a hand-maintained list.

### Stage 4 — retire the extraction hack, and split the suite

1. Move `bt-phase`'s analysis body to `tools/lib/phase.awk` and load it with `-f`,
   exactly as `bt-capdiff` loads `capdiff-match.awk`. Delete the Python extractor. This
   closes the one place where the test runs a copy rather than the shipped code — the
   failure mode this repository has already been bitten by once.
   Note `install.sh` installs `tools/lib/*.awk` explicitly by name (lines 256-261), so
   the new library needs a line there, and the existing "no tool loads a `-f` library it
   does not ship" invariant will catch it if forgotten.
2. Split `tests/run-tests` into per-area files with a thin runner. It is the largest file
   in the repository and has already concealed two of its own defects.

### What I recommend against

- **Do not adopt `bats`, `shunit2` or similar.** It would add a dependency to a project
  whose install path is deliberately dependency-light, and would require rewriting 65
  working invariants — whose comments carry the provenance of the real defect each one
  encodes. That provenance is the most valuable thing in the suite and a mechanical port
  would shed it. The existing `ok`/`bad` harness with `--section` addressing is 1.8 s and
  does everything a framework would.
- **Do not set a line-coverage target.** "Every test encodes a defect that shipped" is a
  stronger rule than a percentage, and this project has the history to keep feeding it.
- **Do not restructure the tools into sourceable libraries** to make their shell functions
  unit-testable. Cost and risk exceed the benefit; Stage 3 gets most of the value.

---

## 5. Suggested sequence

| Stage | Touches shipped tools? | Effort | Payoff |
|---|---|---|---|
| 1 — visibility + CI | no (one guard in a devtool) | hours | every push checked |
| 2 — awk fixtures | no | 1–2 days | real unit coverage of 543 lines of logic |
| 3 — journal seam | yes, incrementally | ongoing | unlocks the other 38 scripts |
| 4 — `phase.awk`, split suite | yes, small | 1 day | removes a known-dangerous pattern |

Stages 1 and 2 are worth doing regardless of whether Stage 3 is ever started.

---

## 6. Verification behind this report

Everything above was measured on this checkout, not inferred:

- `tests/run-tests` → `all 65 invariants hold`, exit 0, 1.774 s wall clock.
- `devtools/repo-validate` → exit 0 with `systemd-analyze` present; exit 1 with nine
  false unit failures when it is absent from PATH.
- Shell-file inventory derived the same way `run-tests` derives it — shebang scan over
  `git ls-files` — giving 42 files.
- `journalctl` call sites counted with `grep -rn` over `tools/` and `bin/`; no wrapper
  function found in either tree.
- Executed-script coverage taken from the tool paths `run-tests` actually invokes.
