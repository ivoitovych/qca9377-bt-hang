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

## Two document classes

**Reports** are snapshots: `<UTC timestamp>-<topic>.md`, never edited after writing.

**Work logs** are append-only journals of an effort, keyed to the timestamp of the report
that opened it, so every artifact of one effort sorts together. Nothing already written
in a log is revised or deleted — corrections appear as later entries. A log records the
wrong turns, which a clean summary loses.

| Log | Effort |
|---|---|
| [Coverage effort work log](2026-08-13T1214Z-coverage-effort-worklog.md) | the test-coverage effort opened by the 12:14Z assessment |

## Reports

| Written | Report | Covers | Verdict |
|---|---|---|---|
| 2026-08-13T12:14Z | [Unit testing](2026-08-13T1214Z-unit-testing-assessment.md) | the tree at `6c0491c` | The suite is good; its *reach* is 13.1% of the shipped shell |
| 2026-08-13T12:44Z | [Coverage strategy](2026-08-13T1244Z-coverage-strategy.md) | the tree at `10404b2` | Re-prioritises the above: 31% of the code needs **no** seam. Supersedes its §5 ordering |
| 2026-08-13T15:17Z | [Test classes & mocks](2026-08-13T1517Z-test-classes-and-mocks.md) | the tree at 28.5% | Assesses the owner's two proposals; settles CS-08's design; adds the system round trip |
| 2026-08-14T04:43Z | [Why 100% is hard here](2026-08-14T0443Z-why-100-percent-is-hard-here.md) | the tree at `331e7a2` | A third of the "untested" was **unmeasurable by construction**. Adds a second coverage tool for awk, an uncovered-line report, and an exclusion list a 100% floor can stand on |
| 2026-08-14T13:28Z | [Sandbox escape postmortem](2026-08-14T1328Z-sandbox-escape-postmortem.md) | `251a6cb` | The suite **closed a live trial** on the investigation machine. A bare-name `bt-trial` in the watchdog, invisible on any checkout with nothing installed. Guard + decoy; four of the maintainer's findings dispositioned |
| 2026-08-14T16:03Z | [Verified on the investigation machine](2026-08-14T1603Z-verified-on-the-investigation-machine.md) | the tree at `795705e`, now `main` | 402/402 green where the tools are installed; `bt-mark` injections **549 → 0**. Two more environment-coupled checks found *by that host*. Supersedes §7 of the postmortem; **SE-05 stays open** |
| 2026-08-15T00:18Z | [Suite runtime](2026-08-15T0018Z-suite-runtime.md) | the tree at `ce854c0` | 81% of a 52-second run was waiting on clocks, not working. 52 s -> 28 s. Every slow test was slow because it waited for time instead of a condition — and was a weaker assertion for the same reason. Exposed two `bt-usbmon` defects |
| 2026-08-15T01:42Z | [Test comprehensiveness](2026-08-15T0142Z-test-comprehensiveness.md) | the tree at `eaa9a14` | 90.1% line coverage, **76% mean comprehensiveness**. `bt-window` shipped and never executed; `bt-capdiff` at 93% of lines and **1 of 5 modes**; `bin/bt-capture` is Python and no instrument sees it. Adds `devtools/test-comprehension` |

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
| UT-07 | Fixtures for `trial-sco-table.awk`, `stage2.awk` | done | `795705e` | `tests/run-tests --section "awk libraries"` — 17 cases across 3 libraries |
| UT-08 | Journal seam `tools/lib/journal.sh` | done | `d016249` | `test -r tools/lib/journal.sh` |
| UT-09 | Convert `bt-phase`, `bt-boot-provenance` | done | `d016249` | `tests/run-tests --section "whole tools" \| grep 'journal seam'` |
| UT-10 | Convert the remaining journal-reading tools | **partial** 15/25 | `8abfd75` | `reviews/verify.sh` — prints converted vs remaining |
| UT-11 | `lib/phase.awk`; delete the Python extractor | done | `d016249` | `test -r tools/lib/phase.awk`; extractor gone: `grep -c re.search tests/run-tests` → 0 |
| UT-12 | Split `tests/run-tests` into per-area files | **open** — now the single largest file in the repo | — | `wc -l tests/run-tests` |
| UT-13 | Settle `repo-scan`'s pre-existing hits, then add to CI | done | `383b991` + merge | `devtools/repo-scan . --all` → clean; step present in `checks.yml` |

### From `2026-08-13T1244Z-coverage-strategy.md`

| ID | Item | Status | Landed | Verify |
|---|---|---|---|---|
| CS-01 | Test `sanitize-logs.sh` (+ fix its awk gate) | done | `795705e` | `tests/run-tests --section "sanitize-logs"` |
| CS-02 | Test `install.sh` / `uninstall.sh` dry run | done | `795705e` | `tests/run-tests --section "install.sh and uninstall"` |
| CS-03 | Test the devtools against a scratch repo | done | `795705e` | `tests/run-tests --section "publish gates"` |
| CS-04 | Test `bt-capdiff`/`bt-sco`/`bt-context`/`bt-incident` via `BT_*` overrides | **done** — btmon was never the blocker; it emits text, so it is a `PATH` stub | `7276bb0` | `tests/run-tests`; fixtures in `tests/btmon/` |
| CS-05 | Convert + test `bt-actions` (seam) | done | `795705e` | `grep -c 'journal.sh' tools/bt-actions` → 2; `tests/run-tests --section "whole tools"` |
| CS-06 | `bt-logvolume`, `bt-boot-stats`, `bt-timeline.sh` | done | `def19bc` | `tests/run-tests --section "whole tools"` |
| CS-07 | `bt-env-history`, `bt-boot-list`, `bt-boots` | done | `def19bc` | `tests/run-tests --section "whole tools"` |
| CS-08 | A sysfs/device seam, then `bin/bt-hang-watchdog` | done | `795705e` | `devtools/coverage \| grep bt-hang-watchdog` → 81.8% |
| CS-09 | Argument/refusal paths only for the hardware-bound five | **partial** — `bt-sco`/`bt-capdiff` remain (need `btmon`) | `8abfd75` | `tests/run-tests --section "whole tools"` |

### From session 3 — the reporting tools and the machine-bound tools

Not a new report: these close CS-08's successors and the Group 1/2 work described in the
[work log](2026-08-13T1214Z-coverage-effort-worklog.md). Each row is a tool that was at
0% and the seam that reached it.

| Tool | Was | Now | Seam added | Findings |
|---|---|---|---|---|
| `bt-status` | 0% | 81.7% | `BT_SYSFS_USB`, `BT_SYSFS_BT`, journal | one verdict, two exit codes |
| `bt-postmortem` | 0% | 73.2% | sysfs + journal | — (introduced `SEAM-ADVICE`) |
| `bt-health-report.sh` | 0% | 78.0% | `BT_SYSFS_MODULE`, `BT_METRICS`, journal | `column(1)` unguarded; advice line corrupted by my own seam pass |
| `bt-exhibit` | 0% | 94.7% | none needed (`BT_REPO` existed) | missing sanitiser treated as safe; address in `--cmd` published verbatim |
| `bt-verify-install` | 0% | 82.4% | `BT_UDEV_DIR`, `BT_MODE_STAMP` | — |
| `verify-restored.sh` | 0% | 86.1% | `BT_INSTALL_SH`, `BT_HEALTH_DIR`, sysfs, journal | — |
| `bt-diagnose` | 0% | 91.8% | `BT_SYSFS_USB`, journal | — (added `bt_journal_available`) |
| `bt-mode` | 0% | 98.0% | every path, plus `--dry-run` | — |
| `bt-verify-kernel-mechanism` | 0% | 95.9% | `BT_MODULES_DIR` | `hexdump` absent ⇒ every device ID reported ABSENT |
| `bt-state` | 0% | 94.9% | sysfs + journal | — |
| `bt-health-snapshot` | 0% | 100% | `BT_METRICS`, sysfs, journal | — |
| `bt-evidence` | 0% | 92.8% | `BT_EVIDENCE_STATE`, `BT_TRACE_DIR`, sysfs, journal | — |
| `bt-mark` | 0% | 100% | `BT_SYSFS_USB` | — |
| `bt-dyndbg` | 0% | 73.6% | `BT_DYNDBG_CTL`, append-writes | — |
| `bt-sco` | 0% | 59.0% | **btmon on `PATH`** | — |
| `bt-capdiff` | 0% | 86.6% | **btmon on `PATH`** | overlap bound manufactured disagreements at both edges; one-sided loss described as two-sided |
| `bt-trace` | 0% | 38.0% | `--check` | — |
| `bt-usbmon` | 0% | 53.1% | `--check`, `BT_USBMON_DEBUGFS` | tracked mode 100644 — exits 126 from a checkout |
| `devtools/repo-save` | 0% | 83.3% | none needed (scratch repo + `--no-push`) | — |

**Two figures in the table below are floors, not gaps.** `tools/bt-actions` (16.4%) and
`tools/bt-trial` (62.2%) embed large inline awk programs, and bash traces a multi-line
command once at its opening line — so the bodies count as uncovered and can never be
otherwise. `devtools/coverage` documents this bias in its own header. A change to exclude
them was implemented and **backed out** when it moved the numerator by six unexplained
lines; see the work log. The remedy is extraction to `tools/lib/`, as was done for
`phase.awk`, and it is open.

Verify: `tests/run-tests` (329 invariants) and `devtools/coverage`.

**Three assertions written during this work could not fail for the reason their names
gave** — a row-width check blind to a blank column, a sandbox check using `[[ -e ]]` with
a glob, and a `PIPESTATUS` check that `$?` satisfied under `pipefail`. All three were
written carefully and all three passed. They are recorded in the work log, and they are
the argument for mutation-testing *every* new check rather than the interesting ones.

### From `2026-08-13T1517Z-test-classes-and-mocks.md`

| ID | Item | Status | Landed | Verify |
|---|---|---|---|---|
| TC-01 | Action-tool mocks + spy for the watchdog | done — **not as `device.sh`** | `795705e` | `tests/run-tests --section "bt-hang-watchdog"` |
| TC-02 | CI-gated system round trip (`--apply` both ways) | done | `795705e` | `BT_SYSTEM_TEST=1 tests/system-roundtrip`; CI step in `checks.yml` |
| TC-03 | Fixture provenance comments + real-tool contract check | **partial** | `795705e` | `devtools/journal-contract` |
| TC-04 | Mock-equivalence: real journalctl over a BUILT journal, diffed vs fixtures | done | `def19bc` | `devtools/journal-contract` — phase 2 runs without a host journal |

**TC-01 deviated from its report's design, deliberately.** The report proposed
`tools/lib/device.sh` wrapper functions; the implementation uses PATH stubs written by
the test (each recording to a spy log) plus two env-var sysfs seams (`BT_SYSFS_USB`,
`BT_SYSFS_DRIVERS`) in the watchdog itself. Wrappers would have rewritten every action
call site in the single most safety-critical tool; PATH resolution substitutes the same
tools with a two-line production diff. The report stays as written — the register records
what was built, and why it differs.

### From `2026-08-14T0443Z-why-100-percent-is-hard-here.md`

| ID | Item | Status | Landed | Verify |
|---|---|---|---|---|
| HC-01 | `devtools/coverage --uncovered` — list the missing lines | done | `7e9e9f2` | `devtools/coverage --uncovered tools/bt-sco` |
| HC-02 | `devtools/awk-coverage` — statement coverage via `gawk --profile` | done | `eeef93d` | `devtools/awk-coverage` → 88.2% |
| HC-03 | Exclusion list with reasons + executed-line self-check | done | `d58866f` | add a bogus entry; the run aborts |
| HC-04 | Two CI floors, one per language | done | `331e7a2` | `--min 80` shell, `--min 85` awk in `checks.yml` |
| HC-05 | Fold the CI-gated round trip into the measurement (206 lines) | **open** — recommended first | — | see §5 of the report |
| HC-06 | Work the long tail with `--uncovered` (~266 lines, ~25 tools) | **open** | — | `devtools/coverage --uncovered` |
| HC-07 | Extract remaining inline awk to `tools/lib/*.awk` | **open** | — | shrinks the exclusion list rather than growing it |
| HC-08 | Raise both floors to 100% | **blocked** on HC-05..07 | — | judgement call; see §5 |
| HC-09 | The numerator counted traced lines per file and clamped to the total | done — every total before this was inflated | this commit | `devtools/coverage` vs `--uncovered`: (coverable − covered) must equal the uncovered count, for every file |
| HC-10 | `done`/`fi` with a redirect, and commented function headers, were in the denominator | done — untraceable by construction, derived by tracing both forms | this commit | `bash -x` a loop with `done < f` and with `done < <(cmd)`: only the second is traced |

### From `2026-08-15T0142Z-test-comprehensiveness.md`

| ID | Item | Status | Landed | Verify |
|---|---|---|---|---|
| TX-01 | `tools/bt-window` is shipped and has never been executed | done — 0% → 91%, 15 scenarios | this commit | `devtools/test-comprehension bt-window` |
| TX-02 | Drive every mode of the four units below 35% (16 verbs/flags) | done — worst unit is now 80% | this commit | `devtools/test-comprehension --min 75` |
| TX-03 | Drive the 14 refusal paths nothing has reached | done — 2 remain, both argued | this commit | `devtools/test-comprehension` — "never exercised" section |
| TX-04 | `bin/bt-capture` is Python; no instrument here measures it | **open** — decide: instrument or state it | — | `devtools/test-comprehension` — "not measurable" section |
| TX-05 | Untested watchdog seams decide WHEN it intervenes (`BT_WINDOW`, `BT_EARLY_*`) | done — 13/13 seams driven | this commit | `devtools/test-comprehension bt-hang-watchdog` |
| TX-06 | A comprehensiveness floor in CI | done — `--min 75`, a ratchet below the current 80 | this commit | `grep -c "comprehensiveness floor" .github/workflows/checks.yml` → 1 |

### From `2026-08-14T1328Z-sandbox-escape-postmortem.md`

| ID | Item | Status | Landed | Verify |
|---|---|---|---|---|
| SE-01 | PATH guard for every bare-name project tool | done | `251a6cb`, corrected `6f12ad3` | reverse the guard's PATH order → 3 invariants fail |
| SE-06 | Derive the guard from `install.sh`, not from call-site spellings | done — the first derivation missed `bt-boots`, invoked via a `have()` wrapper | `6f12ad3` | break the derivation → the suite exits 2 rather than running unguarded |
| SE-02 | Decoy behind the guard, so the hazard is constructed not inherited | done | `251a6cb` | `tests/run-tests` — "no bare-name call reached a tool behind the guard" |
| SE-03 | Route every `install.sh` dry run through `BT_MODE_STAMP` | done | `251a6cb` | `grep -n './install.sh' tests/run-tests` → only via `install_dry()` |
| SE-04 | Replace the unsatisfiable `/root/exp` assertion | done | `251a6cb` | reinstate the discarding fallback in `bt-incident` → 4 invariants fail |
| SE-05 | Run the suite only in a worktree on the investigation machine | **open** — a habit, not a patch | — | see §7 of the report |
| SE-07 | The open-trial refusal is a window check — nothing re-reads the state | done — detection, not prevention | `795705e` | snapshot a trial after the baseline is taken → the closing check goes red |
| SE-08 | `bt-mode` seam check asserted absolute state, not a change | done — failed on the investigation machine for its correct configuration | `795705e` | delete a real `.disabled` mid-section → "A SEAM LEAKED" names the file |
| SE-09 | Missing-baseline branch unreachable where the project is installed | done — `BT_SHARE_DIR` / `BT_HEALTH_DIR` seams | `795705e` | drop the two seams with `baseline.tsv` installed → the assertion fails |
| SE-10 | An exclusion entry pointing at a blank line, excluding nothing | done | `795705e` | `devtools/coverage --uncovered tools/bt-health-report.sh` → 0, not 1 |

### Check every row at once

```bash
reviews/verify.sh              # runs every row's check and prints pass/fail
devtools/coverage --uncovered  # WHICH lines are missing, not just how many
devtools/awk-coverage          # the other language, measured separately
devtools/check                 # syntax, invariants, drift, install state
devtools/coverage              # the number UT-05..UT-11 were meant to move
```

`verify.sh` is the register in executable form. It exists because the first draft of this
table shipped four verify commands that did not work — one pointed `--section` at a
comment rather than a heading, one asserted `python3` had left `run-tests` when three
legitimate uses remain, and two quoted counts that were simply wrong. A register nobody
runs rots exactly like the documentation it was meant to replace.

Coverage was **13.1%** (503/3846) when the report was written, **18.3%** at `d016249`,
**28.5%** after UT-07 + CS-02/03/05, **38.3%** (1692/4423) after the watchdog, the six
seam conversions and `bt-incident`, and **72.6%** (3685/5073) after session 3's twenty
tools. The CI floor is a ratchet below the current figure — 30 until session 3, now 65.
If `devtools/coverage` prints materially less than the last figure, something regressed
and the register is stale. (Two of those points are not comparable naively: main's merge and the `./`-prefix
join fix in `devtools/coverage` both moved the denominator — the trend is what matters.)

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
