# reviews

Assessments of **this repository** — its testing, its tooling, its own claims.

**One report reaches past the tree's edge, and it is stated here rather than
smuggled in.** `2026-08-17T0022Z-source-investigation-2026-08-16-2353.md` reads Linux
source, because this repository's central claims *are* claims about Linux source and
checking them cannot stop at our own files — it corrects `EX-006` from `EX-006`'s own
output. It belongs here rather than in `docs/` because it is a dated snapshot of what was
known on one evening, not living documentation; `docs/` is where the living account is
kept. Everything else here diagnoses only us.

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
| 2026-08-15T15:04Z | [Verification on the investigation machine](2026-08-15T1504Z-verification-on-the-investigation-machine.md) | `9a11ab7` merged on `ed82166` | 566/567 where the tools are installed, **system binaries byte-identical** before and after — `farm_dir()` verified on the configuration that destroyed three of them 90 minutes earlier. Names the fourth instance of *a test whose subject is a tool's behaviour cannot be validated where the tool is missing* |
| 2026-08-15T17:52Z | [Comprehensive code review](2026-08-15T1752Z-comprehensive-code-review.md) | the tree at `ed82166` | Every file, in priority order. **`main` fails its own coverage gate** on three stale exclusion ranges; five invariants nested inside another check's success branch in `tests/run-tests`; prose-behind-code named as the dominant defect class, concentrated where no invariant reaches |
| 2026-08-16T00:22Z | [Fixes & elaboration for the code review](2026-08-16T0022Z-fixes-and-elaboration-for-2026-08-15T1752Z-review.md) | `main` at `944b1eb`, branch `review/2026-08-15T1752Z-fixes` | All 84 findings dispositioned — fixed / fixed-on-main / kept (REVIEWED-KEEP markers) / recorded; suite 602 green, coverage 89.6%, awk 88.0%. Adds CR-84 (mawk skips) and `tools/lib/trial-reclass.awk` |
| 2026-08-17T00:22Z | [Source investigation 2026-08-16-2353](2026-08-17T0022Z-source-investigation-2026-08-16-2353.md) | Linux source, against `main` @ `1c336e7` | The one report here that reads the kernel rather than us. Locates `BT-1` as a chain across four components, and names the structural finding: the HCI core has **two watchdogs and one escalation path**, and `BT-1` is the case the escalation cannot reach. Corrects `EX-006` from its own output — `0x0428` *was* answered — which `EX-033` then observed directly six days later |
| 2026-08-23T23:40Z | [EX-032 crash sites resolved](2026-08-23T2340Z-ex032-crash-sites-resolved.md) | `bluez 5.72-0ubuntu5.5`, stripped | Both `bluetoothd` crash sites named to file and line from the shipped binary, without symbols; falsifier stated and later confirmed against a core |
| 2026-09-13 | [Foundation-file consistency](2026-09-13-foundation-file-consistency.md) | `5fbd6c2` | README, BRIEF, HISTORY: the central finding is in none of them. (Filename lacks the UTC time the convention requires — recorded, not renamed) |
| 2026-09-16T04:20Z | [Comprehensive code review](2026-09-16T0420Z-comprehensive-code-review.md) | the tree at `3cf4dd6` | Every file again. **`main` fails its own suite** (2 of 774, since `d70cb2e`) and CI has been red since 08-25 with nothing reading it; **`install.sh --tools-only` silently reverted the experiment baseline on 08-19** — trials 6–12 ran under `autosusp=N,power=on` with the mode stamp still saying experiment; docs outrun by the alt-1 evidence in README, BRIEF, evidence/README, the bug report and three tools' verdicts. 122 findings: 10 HIGH, 39 MED |
| 2026-09-17T22:51Z | [Front-door review](2026-09-17T2251Z-front-door-review.md) | `0f25bea` — README, BRIEF, `patches/bluez/`, `docs/bug-report.md`, `docs/issues.md`, read as a maintainer arriving from a patch and as a stranger with a different controller | Everything both readers need exists and is not where they look: README disowns 660 of its 746 lines and presents the retired model; the mails carry no way back to the record; the bug report asks for the fix its own body argues against; `issues.md` stops at EX-021. Delivers a README skeleton, the patch mail-body note, and the order of work |

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
| TX-04 | `bin/bt-capture` is Python; no instrument here measures it | done — instrumented, not stated: `devtools/py-coverage`, 85.9%, CI floor 80 | `2026-08-22` | `devtools/py-coverage --min 80` |
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

### From `2026-08-15T1752Z-comprehensive-code-review.md`

The complete per-finding disposition — all 84 CR IDs with statuses — is the catalogue
table in [the fixes document](2026-08-16T0022Z-fixes-and-elaboration-for-2026-08-15T1752Z-review.md);
[GOOD] practices carry `REVIEWED-KEEP 2026-08-15T1752Z` markers at their source sites
(`grep -rn 'REVIEWED-KEEP' --include='*' .` enumerates them). The rows below are the
HIGH/MED items only. Every behavioural change on the fixes branch is pinned by a
suite assertion observed to fail (tracker Addendum 2). The one gap Addendum 2
accepted — bt-trace's crash backoff — was closed on main (`e93319a`,
BT_TRACE_RAPID_MAX seam, bt-trace at 99%); tracker Addendum 3 records the
correction.

| ID | Item | Status | Landed | Verify |
|---|---|---|---|---|
| CR-01 | README volatile numbers replaced by executable sources | done | fixes branch | `grep -c '18.3%' README.md` → 0 |
| CR-42 | metrics.tsv gains `wd_early_ok` with tool-mediated migration | done | fixes branch | `tests/run-tests --section "bt-health-snapshot"` |
| CR-52 | uninstall.sh failure accumulator + INCOMPLETE banner | done | fixes branch | `grep -c 'UNINSTALL INCOMPLETE' uninstall.sh` → 1 |
| CR-56 | bt-trial `$KJ` cleanup trap | done | fixes branch | `grep -c "trap 'rm -f \"\$KJ\"' EXIT" tools/bt-trial` → 1 |
| CR-57 | civil-date arithmetic deduplicated into `tools/lib/` | done | fixes branch | `ls tools/lib/boot-hours.awk tools/lib/sco-window.awk tools/lib/actions-render.awk` |
| CR-58 | probe/abort counts exclude systemd lifecycle noise | done | fixes branch | `grep -c '^Finished Snapshot' tools/bt-trial tools/bt-env-history` → 1 each |
| CR-60 | trial-summary RESCUED column (rec[] was dead) | done | fixes branch | `tests/run-tests --section "awk libraries"` — `rescued-shown` case |
| CR-64 | postmortem counts EARLY interventions | done | fixes branch | `tests/run-tests` — "counted as an intervention" |
| CR-68 | width-check nesting | done on main | `944b1eb` | comment at the unnested block cites the finding |
| CR-72 | stale coverage exclusions | done on main; re-derived here | fixes branch | `devtools/coverage --quiet --min 80` |
| CR-73 | eval'd helper xtrace corruption | done on main | `944b1eb` | helper is sourced from a temp file |
| CR-80 | pre-fix CHANGED row re-enters the denominator at read time | done | fixes branch | `test -r tools/lib/trial-reclass.awk`; report prints the reclassification note |
| CR-84 | mawk hosts: loud skips; repo-validate blind spot | done | fixes branch | run the suite with mawk first on PATH → 582 green with skip notes |

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

### From `2026-09-16T0420Z-comprehensive-code-review.md`

The per-finding list is the report itself (`R2-01`..`R2-122`, severity in the label).
Rows below are the HIGH items and the MED items that change what the record means;
everything else is fixed or declined by the reaction, which will add its own tracker.

| ID | Item | Status | Landed | Verify |
|---|---|---|---|---|
| R2-01 / R2-100 | Two suite invariants cannot pass on any host; CI red since 08-25 | **closed** | `456daba` | `compgen -G` at `:7887`; suffix derived at `:7410`; each driven to fail on purpose. Actions green on `456daba` (run 35148266458), `00138a7`, `2839ecc` — first greens since `d70cb2e` |
| R2-58 | `--tools-only` reinstalls files `bt-mode experiment` moved aside; baseline reverted 08-19 | **tool fixed; machine pending operator** | `456daba` | `install_file()` and the generated udev rule skip any destination with a `.disabled` sibling and say so; both-direction staged test in `tests/run-tests` (R2-102). Verified live: active files dated **Sep 1 05:45 — this side's own deploy** beside `.disabled` from Aug 15. The pair is still on the machine: which treatment the series continues under was the operator's decision (`BRIEF` §9.5, decided 09-16: original configuration, executed 09-17), recorded in `EX-042` |
| R2-04 / R2-05 / R2-07 | README: "kept current", contradictory baseline claims, no central finding | **partial** — R2-04 closed, R2-05/R2-07 open | `456daba` (R2-04) | "kept current" now points at `BRIEF.md` and says `issues.md` stops at `EX-021`. The alt-1 finding is still absent from README (`grep -c 'alt-1' README.md` in a finding paragraph → 0); waits on the bug-report rewrite |
| R2-21 | `docs/issues.md` stale at EX-021 | open | — | `grep -c 'EX-04' docs/issues.md` → ≥1 |
| R2-25 | bug-report timing 7.6–16.2 s vs measured 2.076–2.191 s | open | — | `grep -c '2.19' docs/bug-report.md` → ≥1 |
| R2-64 / R2-65 | `bt-trial abort` deletes tracked evidence; `autostop` probes a live controller (BL-03, BL-08) | open | — | `grep -c 'ls-files' tools/bt-trial` → ≥1; `grep -c hci_alive tools/bt-trial` → 0 in `autostop)` |
| R2-105 | Commit path on the machine never runs the suite and nothing reads CI | **partial** — CI is read; suite still refused while a trial is open | this commit | `devtools/ci [sha]` reads the verdict on the machine (`--wait`, `--recent`); `devtools/status` prints a CI row and goes rc=1 on a red. The suite-on-machine half stays as designed: `run-tests` refuses during an open trial, correctly, so CI is the verdict while one is open |
| R2-70 | `sanitize-logs.sh` redacts SIG base UUIDs; profile identity lost in every session log | open | — | `echo 0000110b-0000-1000-8000-00805f9b34fb \| tools/sanitize-logs.sh /dev/stdin /dev/stdout` prints it unchanged |
| R2-76 | `bt-status` counts `discovery` lines as audio | **closed** | `456daba` | `\bsco\b` and `\besco\b`; the bare form is gone from `tools/bt-status` |
| R2-81 / R2-106 | verifiers and `devtools/status` advise `--apply` in experiment mode; `.disabled` + active pair invisible | open | — | `tools/bt-verify-install` reports CONFLICT on a staged pair |
| R2-111 | Four instruments disagree on what a red suite means | open | — | each of the four exits non-zero without a figure on a red run |
| R2-114 | Exhibit index truncates 16 of 41 claims | **closed** | `2839ecc` | Extractor takes the whole `**Claim.**` paragraph; 42 rows, 0 cut, 0 empty (17 of 42 were cut at the tip). A wrapped-claim test fails against the old `grep -m1` on the same file. ⚠️ The verify command as written matches every table row — `' |$'` is the row terminator; the honest check is "no claim cell ends without `.`/`!`/`?`/`)`/`` ` ``/`*`" |
| R2-117 | patches README says the guards were never watched firing; EX-041 shows four | **closed** | `456daba` | The runtime paragraph now separates the two: `0002` fired four times (watched preventing it), `0001`'s guard has not, the 09-08 `free()` is a third crash and stays out of the submission |
| R2-119 | `reviews/verify.sh` covers 13 of ≈60 register rows | open | — | `reviews/verify.sh` prints a line per block |


### From `2026-09-17T2251Z-front-door-review.md`

The per-finding disposition — all 25 `FD` IDs — is the catalogue in
[the fixes document](2026-09-17T2251Z-fixes-for-front-door-review.md), on branch
`review/2026-09-17T2251Z-fixes`.

| ID | Item | Status | Landed | Verify |
|---|---|---|---|---|
| FD-01 / FD-03 / FD-05 / FD-06 | README rewritten to the §7.1 skeleton; watchdog material moved to `docs/install.md`; branch map; no retired numbers | **fixed** | `b07a4ef` | `wc -l README.md` ≤ ~200; `grep -c 'being rewritten' README.md` → 0; `grep -c '287' README.md` → 0 |
| FD-02 | "For maintainers" block on the front page (BRIEF §6 + crash-site link + reproduction shape) | **fixed** | `b07a4ef` | `grep -c 'EX-041' README.md` → ≥1; `grep -c '2026-08-23T2340Z' README.md` → ≥1 |
| FD-04 / FD-24 | "Is this your problem?" — four failure modes, what transfers to another controller, why this class goes unreported | **fixed** | `b07a4ef` | `grep -c 'different controller' README.md` → ≥1 |
| FD-09 | README carries its own status copy; BRIEF labelled internal | **fixed** | `b07a4ef` | README Status block names the newest exhibit (extend `devtools/save`) |
| FD-12 | Mail-body note below `---` in both patch mails (§7.2) | **fixed** — notes written; mails not yet sent | `b07a4ef` `139deb5` | `git format-patch --notes` output shows the note below `---` and `git am` drops it |
| FD-13 | Track the `git am` verification script the README quotes | **fixed and run** — against the real BlueZ tree at `c73fa2f9a`, 6/6, after a trailer-exemption fix (its first real run flagged `0001`'s 75-column `Fixes:` as a body line) | `b07a4ef`, `694e365` | `git ls-files patches/bluez devtools \| grep -c am-check` → 1 |
| FD-14 / FD-15 | `patches/bluez/README.md` in the maintainer's order; 5.72-build sentence | **fixed** | `139deb5` | first heading after the table is the environment/runtime block |
| FD-17 / FD-18 / FD-19 / FD-20 | `docs/bug-report.md` rewritten around BRIEF §1–§3; one gate; no revision history | **fixed** — rewritten; still gated on a kernel patch before sending | `139deb5` | `grep -c 'alt' docs/bug-report.md` → ≥5; `grep -c 'Do not send' docs/bug-report.md` → 1 |
| FD-22 / FD-23 | `docs/issues.md`: BT-1 stage-2 closed against EX-023/025/029/042; alt-1 and EX-032 entries; BT-3 and BT-5 restated | **fixed** | `139deb5` | `grep -c 'EX-04' docs/issues.md` → ≥3 |

## Adding a report

```bash
date -u +%Y-%m-%dT%H%MZ          # the timestamp for the filename
```

Give every recommendation an ID (`<PREFIX>-nn`) and a command that decides whether it has
been done. A recommendation nobody can mechanically check is a recommendation that gets
argued about instead of finished — the same reason `tests/run-tests` exists rather than a
document describing the invariants.

Then add a row to **Reports** and a block to the **Action register**.
