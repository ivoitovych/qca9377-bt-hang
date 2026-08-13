# reviews

Assessments of **this repository** — its testing, its tooling, its own claims. Nothing
here diagnoses Bluetooth.

## The convention

**One file per assessment, named `<UTC timestamp>-<topic>.md`, never edited after it is
written.**

```
2026-08-13T1214Z-unit-testing-assessment.md
```

A timestamp in a filename is a promise that the contents are the state of the world at
that moment. Editing the file breaks that promise silently — the name still says
`T1214Z` while the text has moved on, and a reader who compares two quotations from it
months apart has no way to know they came from different documents. So the reports are
append-only in practice: **corrections go in a new report, and current status goes in the
register below.**

The date is UTC and the time is included because two assessments of the same thing on the
same day is a normal outcome, not an unusual one.

## Reports

| Written | Report | Covers | Verdict |
|---|---|---|---|
| 2026-08-13T12:14Z | [Unit testing](2026-08-13T1214Z-unit-testing-assessment.md) | the tree at `6c0491c` | The suite is good; its *reach* is 13.1% of the shipped shell |
| 2026-08-13T12:44Z | [Coverage strategy](2026-08-13T1244Z-coverage-strategy.md) | the tree at `10404b2` | Re-prioritises the above: 31% of the code needs **no** seam. Supersedes its §5 ordering |

---

## Action register

Live status of every recommendation, keyed to the IDs in the report. **This table is the
current truth; the report is history.** Each row carries a command that decides its own
status — run it rather than trusting the column.

Legend: **done** · **partial** · **open** · **blocked** (waiting on a decision, not on work)

### From `2026-08-13T1214Z-unit-testing-assessment.md`

| ID | Item | Status | Landed | Verify |
|---|---|---|---|---|
| UT-01 | Guard `systemd-analyze` in `repo-validate` | done | `d016249` | `grep -c 'command -v systemd-analyze' devtools/repo-validate` → 1 |
| UT-02 | `tests/` + devtools in both READMEs | done | `d0a4704` | `grep -c 'devtools/coverage' README.md` → ≥1 |
| UT-03 | `tests/README.md` house rules | done | `d016249` | `test -r tests/README.md` |
| UT-04 | CI: validate + suite + coverage floor | done | `d016249` | `test -r .github/workflows/checks.yml` |
| UT-05 | Table-driven awk fixture harness | done | `d016249` | `tests/run-tests --section "awk libraries"` |
| UT-06 | Fixtures for `trial-summary.awk` | done | `d016249` | `ls tests/fixtures/trial-summary/*.in \| wc -l` → 5 |
| UT-07 | Fixtures for `trial-sco-table.awk`, `stage2.awk` | **open** | — | `ls tests/fixtures/` — expect a directory per library |
| UT-08 | Journal seam `tools/lib/journal.sh` | done | `d016249` | `test -r tools/lib/journal.sh` |
| UT-09 | Convert `bt-phase`, `bt-boot-provenance` | done | `d016249` | `tests/run-tests --section "whole tools" \| grep 'journal seam'` |
| UT-10 | Convert the remaining journal-reading tools | **partial** 2/21 | `d016249` | `sh reviews/verify.sh` — prints converted vs remaining |
| UT-11 | `lib/phase.awk`; delete the Python extractor | done | `d016249` | `test -r tools/lib/phase.awk`; extractor gone: `grep -c re.search tests/run-tests` → 0 |
| UT-12 | Split `tests/run-tests` into per-area files | **open** | — | `wc -l tests/run-tests` — 1353 at `d016249`, was 1038 |
| UT-13 | Settle `repo-scan`'s pre-existing hits, then add to CI | done | `383b991` + merge | `devtools/repo-scan . --all` → clean; step present in `checks.yml` |

### From `2026-08-13T1244Z-coverage-strategy.md`

| ID | Item | Status | Landed | Verify |
|---|---|---|---|---|
| CS-01 | Test `sanitize-logs.sh` (+ fix its awk gate) | done | this commit | `tests/run-tests --section "sanitize-logs"` |
| CS-02 | Test `install.sh` / `uninstall.sh` dry run | **open** | — | `./install.sh >/dev/null; echo $?` → 0, writes nothing |
| CS-03 | Test the devtools against a scratch repo | **open** | — | `devtools/coverage \| grep devtools/` — expect non-zero rows |
| CS-04 | Test `bt-capdiff`/`bt-sco`/`bt-context`/`bt-incident` via `BT_*` overrides | **open** | — | as above for `tools/` rows |
| CS-05 | Convert + test `bt-actions` (seam) | **open** | — | `grep -c journal.sh tools/bt-actions` → 1 |
| CS-06 | `bt-logvolume`, `bt-boot-stats`, `bt-timeline.sh` | **open** | — | as CS-05 |
| CS-07 | `bt-env-history`, `bt-boot-list`, `bt-boots` | **open** | — | as CS-05 |
| CS-08 | A sysfs/device seam, then `bin/bt-hang-watchdog` | **open** | — | `devtools/coverage \| grep bt-hang-watchdog` |
| CS-09 | Argument/refusal paths only for the hardware-bound five | **open** | — | judgement call; see the report |

### Check every row at once

```bash
sh reviews/verify.sh           # runs every row's check and prints pass/fail
devtools/check                 # syntax, invariants, drift, install state
devtools/coverage              # the number UT-05..UT-11 were meant to move
```

`verify.sh` is the register in executable form. It exists because the first draft of this
table shipped four verify commands that did not work — one pointed `--section` at a
comment rather than a heading, one asserted `python3` had left `run-tests` when three
legitimate uses remain, and two quoted counts that were simply wrong. A register nobody
runs rots exactly like the documentation it was meant to replace.

Coverage was **13.1%** (503/3846 lines) when the report was written and **18.3%**
(713/3898) at `d016249`. If `devtools/coverage` prints materially less than that,
something regressed and the register is stale.

### UT-13 — closed, from the other side

This was blocked on a publish-safety decision, not on work: `repo-scan . --all` failed on
a kernel `MODULE_AUTHOR` address and a filesystem UUID in a sanitised log, and choosing
between widening the allowlist, redacting, or dropping the check was the owner's call.

Main settled it (`b9cbf9e`..`383b991`) and went further — `devtools/check` now gates on
`repo-scan . --all` locally. The CI step has been added to match, so a pull request from a
fork is screened before anyone reads it. `devtools/repo-scan . --all` is clean on the
merged tree.

## Adding a report

```bash
date -u +%Y-%m-%dT%H%MZ          # the timestamp for the filename
```

Give every recommendation an ID (`<PREFIX>-nn`) and a command that decides whether it has
been done. A recommendation nobody can mechanically check is a recommendation that gets
argued about instead of finished — the same reason `tests/run-tests` exists rather than a
document describing the invariants.

Then add a row to **Reports** and a block to the **Action register**.
