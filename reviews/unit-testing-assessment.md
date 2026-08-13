# Unit testing in this repository — an assessment

**Date:** 2026-08-13
**Scope:** whether to introduce unit testing, in what form, and how much of the code the
existing suite actually covers
**Method:** read every tracked shell script and awk program; ran `tests/run-tests`,
`devtools/repo-validate` and `devtools/check`; then **measured** line coverage by
executing the suite under trace rather than inferring it from which tools the suite
mentions.

---

## Summary

This repository **already has a test suite, and it is better than most shell projects
ever get.** `tests/run-tests` asserts 65 invariants in 1.8 seconds, every one of them
derived from a defect that actually shipped here. `devtools/assert-test-catches` is
mutation testing. `devtools/check` is a single pre-commit gate. That is a real testing
culture, not a gesture toward one.

So the question is not "should this project have tests". It is **"what is the existing
suite not reaching, and what does it cost to reach it"**.

Measured, not estimated:

| | |
|---|---|
| Tracked shell scripts | 43 |
| Scripts executing **at least one line** under the suite | **2** — `tests/run-tests` (84.0%) and `tools/bt-trial` (62.4%) |
| Scripts with **zero** executed lines | **41 of 43** |
| Total line coverage | **13.1%** (503 of 3846 coverable lines) |
| Coverage of shipped code, excluding the suite itself | **5.6%** (194 of 3478) |
| awk libraries | 6 (543 lines), all loaded, most on a single path |
| Unmediated `journalctl` call sites | **109, across 27 files** |
| CI | **none** — no `.github/` |

One structural fact explains nearly all of it: **the tools call `journalctl` directly,
with no seam.** A script that shells out to the host journal on line 37 cannot be run
against a fixture, so it cannot be tested — only syntax-checked. Everything else in this
report follows from that.

My recommendation is **yes, extend testing — but in four staged steps, and do not adopt
a test framework.** Details in [Recommendations](#5-recommendations).

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

## 2. Measured coverage

### 2.1 How it was measured

`devtools/coverage` (added with this report) runs the suite under `xtrace` with a `PS4`
carrying `${BASH_SOURCE}` and `${LINENO}`, and records every line bash actually
executed.

The mechanism is worth one paragraph, because the obvious implementation is silently
wrong. `PS4` is **reset to its default at startup and is not inherited**, so exporting a
tagged `PS4` yields a trace with no file or line information. The seam that does work is
`BASH_ENV`, which every non-interactive bash sources before running its script. An
earlier revision propagated `xtrace` from the parent via an exported `SHELLOPTS`; that
worked intermittently and, when it failed, produced an **empty trace, a green suite, and
every file reported at 0%** — a fabricated finding that reads exactly like a real one.
`xtrace` is therefore enabled inside the `BASH_ENV` file itself, and the tool now
**refuses with exit 2 rather than reporting 0%** if the trace comes back empty. That
refusal is verified: pointing `BASH_ENV` at `/dev/null` produces the refusal, not a
zero.

**The figures are a conservative lower bound.** bash traces simple commands, not syntax,
so blank lines, comments, bare keywords, function headers, here-document bodies and
backslash continuations are excluded from the denominator. Two things still inflate it: a
command spanning several lines is traced once at its first line, and `case` pattern
labels are counted but never traced. True coverage is somewhat higher than printed. This
is a number for ranking files and watching a trend, not one to quote as exact.

### 2.2 The result

```
  62.4%    194/311    tools/bt-trial
  84.0%    309/368    tests/run-tests
   0.0%       …       every one of the other 41 files

files with zero executed lines: 41 of 43
TOTAL: 13.1% (503 of 3846 coverable lines)
```

**Correction to an earlier draft of this report.** Reading the suite, I counted four
scripts as exercised — `bt-phase`, `bt-trial`, `bt-incident` and `repo-validate`.
Measurement says **two**. The other three fail for three different reasons, and each is
instructive:

- **`tools/bt-phase` — 0.0% of 117 lines.** The suite tests bt-phase by extracting its
  awk body from its own source with a Python regex and running *that*. The awk is
  covered; the script that ships is never executed. This is the single sharpest
  vindication of §2.4 below.
- **`tools/bt-incident` — 0.0% of 65 lines.** The suite replaces it with a stub, by
  design, so a failed trial cannot write into the real evidence tree. Correct behaviour,
  zero coverage.
- **`devtools/repo-validate` — 0.0% of 90 lines.** I had the dependency backwards:
  `repo-validate` runs `run-tests`, not the reverse.

Two of those three I would not have caught by reading more carefully; I would have caught
them by measuring, which is the argument for the tool.

The rest of the tree is what the totals suggest. Ranked by size, the largest wholly
unexecuted files:

| Lines | File |
|---|---|
| 253 | `install.sh` |
| 183 | `bin/bt-hang-watchdog` |
| 167 | `tools/bt-actions` |
| 144 | `uninstall.sh` |
| 124 | `tools/bt-exhibit` |
| 119 | `bin/bt-evidence` |
| 117 | `tools/bt-phase` |
| 107 | `tools/bt-postmortem` |
| 107 | `tools/bt-health-report.sh` |
| 106 | `tools/bt-capdiff` |

`bin/bt-hang-watchdog` is the one I would flag hardest: 183 lines that decide **whether
to intervene on a live controller**, with no line ever executed under test.

### 2.3 The awk libraries

All six are loaded by the suite, but most along a single path:

| Loads | Library | Lines |
|---|---|---|
| 7 | `timestamp.awk` | 46 |
| 4 | `capdiff-match.awk` | 34 |
| 3 | `interval.awk` | 19 |
| 2 | `stage2.awk` | **153** |
| 2 | `trial-summary.awk` | **177** |
| 1 | `trial-sco-table.awk` | **114** |

The inversion is the finding: **the three largest libraries are the three least
exercised.** `trial-sco-table.awk` is 114 lines entered once. Load count is not line
coverage — statement-level awk coverage needs `gawk --profile` and this machine ships
`mawk`, which has no profiler — but a 177-line program with branching entered twice is
not meaningfully covered by any definition.

### 2.4 The `journalctl` coupling is the blocker

109 call sites in 27 files, invoked directly:

```
tools/bt-stage2:63    journalctl -k -b all --no-pager -o short-iso-precise > "$TMP"
tools/bt-phase:83     journalctl -u bt-health-snapshot.service -b "$b" ...
tools/bt-status:37    WD=$(journalctl -u bt-hang-watchdog -b 0 --no-pager ...)
```

There is no wrapper function anywhere in `tools/` or `bin/`. This is why the suite tests
what it can reach — the awk that consumes the journal — rather than the tools that
produce it. It is the direct cause of the 5.6% figure.

`bt-boot-provenance` is the sharpest illustration of the cost. It printed `hci=no` for
all six boots — including boots whose journal plainly contained the device — and that is
what exposed the `pipefail`/`grep -q` inversion. The tool was wrong for its entire life,
in a way a single fixture would have caught on the first run. It is 36 coverable lines.

### 2.5 The `bt-phase` extraction hack

To test `bt-phase`, the suite runs a Python regex over the tool's **source** and pulls its
awk body out:

```python
m = re.search(r"awk -v igap=\"\$INCIDENT_GAP\" -v period=\"\$TIMER_PERIOD\" '(.*)' \"\$DATA\"\s*$", s, re.S)
```

The test is coupled to the tool's source layout. Reformat that invocation and extraction
fails loudly (there is an `[[ -s ]]` guard, which is good). But the deeper problem is the
one the suite documents 60 lines later, about `bt-capdiff`:

> Testing the real file rather than a copy extracted from the caller means the test
> cannot pass against a matcher the tool no longer runs — which is precisely how the
> `-f` trap slipped through: an extracted copy worked in the test while the shipped
> invocation silently loaded nothing.

The repository already learned this lesson and already fixed it for `bt-capdiff` by
moving the matcher into `tools/lib/capdiff-match.awk`. **`bt-phase` is the last holdout
running the pattern that is known here to have hidden a real bug** — and the measurement
now puts a number on it: 0.0% of 117 lines.

### 2.6 No CI, and one thing that would break it

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

### 2.7 The suite is the largest file here

At 1038 lines `tests/run-tests` is the **largest shell file in the repository** — larger
than any tool it tests. Commit `4c9b7b4` records that two instances of the `grep -q`
inversion were found *inside `run-tests` itself*, one in a check added that same session.
A test file large enough to hide its own bugs is a real risk, not a stylistic complaint.

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
  as units. §2.3 shows this is where the least work has been done relative to size.
- **Shell functions inside the tools are not reachable as units.** These are scripts, not
  libraries; sourcing one executes it. Making them unit-testable would mean splitting
  every tool into a sourceable library plus a thin driver — a large refactor, on tools
  installed to a machine that is mid-experiment, for less benefit than the seam work in
  Stage 3.

So: **unit-test the awk; characterisation-test the tools; do not restructure the tools
into libraries.**

---

## 4. What a coverage target should and should not be

Do not adopt a percentage target as a goal. This project's rule — *every test encodes a
defect that shipped* — is stronger, and it has a queue of real defects to keep feeding it.

Use the number for two things only:

1. **Ranking.** 183 unexecuted lines in `bt-hang-watchdog` is a more urgent fact than
   17 unexecuted lines in `bt-mark`.
2. **A ratchet.** Once CI exists, `devtools/coverage --min N` set a point or two *below*
   the current figure stops coverage silently regressing when a tool grows. Raise the
   floor when a stage lands; never let it fall.

For scale, a realistic projection rather than an aspiration: bringing the ten largest
journal-reading tools to 50% — the level a fixture-driven characterisation test
typically reaches on a tool with one main path and a few error branches — adds about 620
covered lines and moves the total from **13.1% to roughly 29%**. That is the honest size
of the Stage 3 prize. It does not come from Stages 1 or 2.

Note that awk lines are **not** in the shell denominator at all, so Stage 2 will not move
the percentage even though it is the highest-value-per-hour work available. That is a
limitation of the metric, not a reason to skip the work — and a good illustration of why
the percentage must not become the goal.

---

## 5. Recommendations

Ordered by value per unit of risk. Stages 1 and 2 need no production changes at all.

### Stage 1 — make the existing suite visible and automatic *(low risk)*

1. Guard `systemd-analyze` in `repo-validate` with `command -v`, matching the four checks
   around it. Verified necessary (§2.6).
2. Add `tests/` to the README's Repository layout block, and `check`, `coverage` and
   `assert-test-catches` to the `devtools/README.md` table. *(Done in this commit.)*
3. Add `tests/README.md`: how to run, how to add an invariant, and the house rule that a
   new check must be observed to fail via `assert-test-catches` before it counts.
4. Add a GitHub Actions workflow running `devtools/repo-validate`, `tests/run-tests` and
   `devtools/coverage --min 12`. The suite is 1.8 s and hermetic — it sandboxes
   `bt-trial` and asserts it wrote nothing to the evidence tree — so it is genuinely
   CI-safe today. Do item 1 first.

### Stage 2 — widen awk-library coverage *(low risk, highest value per hour)*

Give each of the six libraries a fixture directory and a table-driven runner:
`tests/fixtures/<lib>/<case>.in` + `.expected`, compared with `diff`. Start with
`trial-summary.awk` (177 lines, 2 loads), `trial-sco-table.awk` (114 lines, **1 load**)
and `stage2.awk` (153 lines, 2 loads) — the three largest and least exercised.

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

Then every tool becomes runnable against a canned journal, and the other 41 scripts
become testable at all. This is where the 13% → ~29% comes from.

**Do not convert all 109 sites at once.** These tools are installed on a machine that is
mid-experiment, and a bad conversion corrupts observations rather than merely failing.
Convert in order of consequence — the tools whose numbers reach exhibits first:
`bt-state` (34 lines), `bt-stage2` (35), `bt-boot-provenance` (36), `bt-interval` (17),
then the larger `bt-status`, `bt-actions` and `bt-hang-watchdog`. Each conversion lands
with the fixture that proves it, each is checked with `assert-test-catches`, and
`devtools/coverage` shows the file move off 0.0%.

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
- **Do not chase the percentage.** See §4.
- **Do not restructure the tools into sourceable libraries** to make their shell functions
  unit-testable. Cost and risk exceed the benefit; Stage 3 gets most of the value.

---

## 6. Suggested sequence

| Stage | Touches shipped tools? | Effort | Coverage effect | Payoff |
|---|---|---|---|---|
| 1 — visibility + CI | no (one guard in a devtool) | hours | none | every push checked; ratchet installed |
| 2 — awk fixtures | no | 1–2 days | none *(awk is outside the metric)* | real unit coverage of the 444 least-tested lines |
| 3 — journal seam | yes, incrementally | ongoing | **13% → ~29%** | unlocks the other 41 scripts |
| 4 — `phase.awk`, split suite | yes, small | 1 day | +117 lines become reachable | removes a known-dangerous pattern |

Stages 1 and 2 are worth doing regardless of whether Stage 3 is ever started.

---

## 7. Verification behind this report

Everything above was measured on this checkout, not inferred:

- `tests/run-tests` → `all 65 invariants hold`, exit 0, 1.774 s wall clock.
- `devtools/coverage` → 13.1% total, 503/3846 coverable lines, 41 of 43 files at zero;
  measurement taken from a green suite run, 2.4 s including the traced run.
- The coverage tool's own failure mode was tested: with `BASH_ENV` pointed at
  `/dev/null`, it exits 2 with "the trace is empty — instrumentation failed, refusing to
  report 0%" rather than reporting a false zero.
- `devtools/repo-validate` → exit 0 with `systemd-analyze` present; exit 1 with nine
  false unit failures when it is absent from PATH.
- Shell-file inventory derived the same way `run-tests` derives it — shebang scan over
  `git ls-files` — giving 43 files (42 before this commit added `devtools/coverage`).
- `journalctl` call sites counted with `grep -rn` over `tools/` and `bin/`; no wrapper
  function found in either tree.
- awk library load counts read from the same trace as the line coverage.
