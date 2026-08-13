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
| 2026-08-13T15:17Z | [Test classes & mocks](2026-08-13T1517Z-test-classes-and-mocks.md) | the tree at 28.5% | Assesses the owner's two proposals; settles CS-08's design; adds the system round trip |

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
| UT-07 | Fixtures for `trial-sco-table.awk`, `stage2.awk` | done | this commit | `tests/run-tests --section "awk libraries"` — 17 cases across 3 libraries |
| UT-08 | Journal seam `tools/lib/journal.sh` | done | `d016249` | `test -r tools/lib/journal.sh` |
| UT-09 | Convert `bt-phase`, `bt-boot-provenance` | done | `d016249` | `tests/run-tests --section "whole tools" \| grep 'journal seam'` |
| UT-10 | Convert the remaining journal-reading tools | **partial** 10/21 | `def19bc` | `sh reviews/verify.sh` — prints converted vs remaining |
| UT-11 | `lib/phase.awk`; delete the Python extractor | done | `d016249` | `test -r tools/lib/phase.awk`; extractor gone: `grep -c re.search tests/run-tests` → 0 |
| UT-12 | Split `tests/run-tests` into per-area files | **open** | — | `wc -l tests/run-tests` — 1353 at `d016249`, was 1038 |
| UT-13 | Settle `repo-scan`'s pre-existing hits, then add to CI | **blocked** | — | see below |

### From `2026-08-13T1244Z-coverage-strategy.md`

| ID | Item | Status | Landed | Verify |
|---|---|---|---|---|
| CS-01 | Test `sanitize-logs.sh` (+ fix its awk gate) | done | this commit | `tests/run-tests --section "sanitize-logs"` |
| CS-02 | Test `install.sh` / `uninstall.sh` dry run | done | this commit | `tests/run-tests --section "install.sh and uninstall"` |
| CS-03 | Test the devtools against a scratch repo | done | this commit | `tests/run-tests --section "publish gates"` |
| CS-04 | Test `bt-capdiff`/`bt-sco`/`bt-context`/`bt-incident` via `BT_*` overrides | **partial** — `bt-incident` done (and its sandbox fixed); `bt-sco`/`bt-capdiff` need btmon | `2fcef33` | `tests/run-tests --section "whole tools"` |
| CS-05 | Convert + test `bt-actions` (seam) | done | this commit | `grep -c 'journal.sh' tools/bt-actions` → 2; `tests/run-tests --section "whole tools"` |
| CS-06 | `bt-logvolume`, `bt-boot-stats`, `bt-timeline.sh` | done | `def19bc` | `tests/run-tests --section "whole tools"` |
| CS-07 | `bt-env-history`, `bt-boot-list`, `bt-boots` | done | `def19bc` | `tests/run-tests --section "whole tools"` |
| CS-08 | A sysfs/device seam, then `bin/bt-hang-watchdog` | done | this commit | `devtools/coverage \| grep bt-hang-watchdog` → 81.8% |
| CS-09 | Argument/refusal paths only for the hardware-bound five | **open** | — | judgement call; see the report |

### From `2026-08-13T1517Z-test-classes-and-mocks.md`

| ID | Item | Status | Landed | Verify |
|---|---|---|---|---|
| TC-01 | Action-tool mocks + spy for the watchdog | done — **not as `device.sh`** | this commit | `tests/run-tests --section "bt-hang-watchdog"` |
| TC-02 | CI-gated system round trip (`--apply` both ways) | done | this commit | `BT_SYSTEM_TEST=1 tests/system-roundtrip`; CI step in `checks.yml` |
| TC-03 | Fixture provenance comments + real-tool contract check | **partial** | this commit | `devtools/journal-contract` |
| TC-04 | Mock-equivalence: real journalctl over a BUILT journal, diffed vs fixtures | done | `def19bc` | `devtools/journal-contract` — phase 2 runs without a host journal |

**TC-01 deviated from its report's design, deliberately.** The report proposed
`tools/lib/device.sh` wrapper functions; the implementation uses PATH stubs written by
the test (each recording to a spy log) plus two env-var sysfs seams (`BT_SYSFS_USB`,
`BT_SYSFS_DRIVERS`) in the watchdog itself. Wrappers would have rewritten every action
call site in the single most safety-critical tool; PATH resolution substitutes the same
tools with a two-line production diff. The report stays as written — the register records
what was built, and why it differs.

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

Coverage was **13.1%** (503/3846) when the report was written, **18.3%** at `d016249`,
**28.5%** after UT-07 + CS-02/03/05, and **38.3%** (1692/4423) after the watchdog, the
six seam conversions and `bt-incident`. If `devtools/coverage`
prints materially less than the last figure, something regressed and the register is
stale. (Two of those points are not comparable naively: main's merge and the `./`-prefix
join fix in `devtools/coverage` both moved the denominator — the trend is what matters.)

### UT-13 — what is blocked, and on what

`devtools/repo-scan` cannot yet run in CI. With nothing staged it falls back to scanning
every tracked file, where it fails on two pre-existing items in
`evidence/baseline/kernel-boot0.sanitized.log`: a kernel maintainer's address carried in
a `MODULE_AUTHOR` string, and a filesystem UUID.

Neither is a leak. But `repo-scan`'s email allowlist covers mailing lists and
`example.com`, not individual maintainers, so the scan is red on the current tree.

**This is a publish-safety policy decision, not a testing one**, which is why it is
blocked rather than open. Three coherent answers:

1. Widen the allowlist to accept addresses that appear inside quoted kernel log lines.
2. Redact the two items in the sanitised log, as `tools/sanitize-logs.sh` does elsewhere.
3. Leave both, and keep `repo-scan` out of CI permanently — `devtools/repo-save` runs it
   on every commit over the staged diff, where it is precise.

Once one is chosen, add the step back to `.github/workflows/checks.yml`; the reason it
was left out is recorded in the workflow itself.

## Adding a report

```bash
date -u +%Y-%m-%dT%H%MZ          # the timestamp for the filename
```

Give every recommendation an ID (`<PREFIX>-nn`) and a command that decides whether it has
been done. A recommendation nobody can mechanically check is a recommendation that gets
argued about instead of finished — the same reason `tests/run-tests` exists rather than a
document describing the invariants.

Then add a row to **Reports** and a block to the **Action register**.
