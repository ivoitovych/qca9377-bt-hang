# Disposition of the 2026-09-16T04:20Z comprehensive review (R2-01 … R2-122) — 2026-09-19T15:00Z

**Why this exists.** The operator's condition for submitting anything: every finding from
every review processed — fixed, or consciously left with the reason written down. The R2
review carried 122 findings; the register held rows for 14. This file dispositions all
122 against the tree at `e4482a5`, each status from a command run today
(`scripts/r2-checks.sh`, `scripts/r2-checks-2.sh`), not from memory. Where the check is a
count, the count is given; where it needed a line of context, the line is quoted in the
scripts' output and summarised here.

**Status words.** `done` — verified fixed on the tree; `open` — verified still present;
`partial` — part fixed, part named; `kept` — deliberately left, reason given; `n/a` — a
GOOD or NOTE finding with nothing to fix. Severity is the review's.

**Totals.** 122 findings: **n/a 37** (30 GOOD, 7 NOTE) · **done 41** · **partial 6** ·
**kept 2** · **open 36** (HIGH 2, MED 15, LOW 19). The open list, in the order the review
itself recommended, is at the end.

## §0 State of the tree

| ID | sev | finding | status | evidence |
|---|---|---|---|---|
| R2-01 | HIGH | `main` fails its own suite; CI red since 08-25 | **done** | fixed 09-16 (`456daba`); CI green on every push since, read by `devtools/ci` |
| R2-02 | MED | `branch-status` confident on a shallow clone | **open** | `grep -c is-shallow-repository devtools/branch-status` → 0 |
| R2-03 | NOTE | register lacks rows for two reports; 09-13 filename convention | **done** | both reports in the Reports table; filename kept, violation recorded in its row |

## §1 README

| ID | sev | finding | status | evidence |
|---|---|---|---|---|
| R2-04 | HIGH | "kept current" sentence | **done** | 0 matches; README rewritten (`b07a4ef`, FD-01) |
| R2-05 | HIGH | retracted denominator claim beside its retraction | **done** | 0 matches |
| R2-06 | MED | "then silence" verbatim | **done** | 0 in README; the one `docs/` hit is the correction paragraph in `missing-quirks-entry.md:238` |
| R2-07 | MED | central finding absent from the front page | **done** | README names alt 1 (6), `mtu 9`/9-byte (2), sysfs (2); Status block |
| R2-08 | LOW | layout/tool tables drifted | **done** | "ten documents" 0; links `tooling-index` twice |
| R2-09 | LOW | Install leads with `--apply` | **done** | line 199 names `--tools-only` first and warns on `--apply` |
| R2-10 | LOW | header line not the specific statement | **open** | lines 1–8: "stops answering during hands-free audio" — true, not alt-1-specific; one line |
| R2-11 | GOOD | opening, streams table, label gate | n/a | — |

## §2 BRIEF

| ID | sev | finding | status | evidence |
|---|---|---|---|---|
| R2-12 | MED | §9.4 wrong fact (suite "has not run") | **done** | §9.4 now the CI-red thread with green confirmation |
| R2-13 | LOW | tip hash rots | **done** | header: "no tip hash: it rotted within hours (`R2-13`)" |
| R2-14 | GOOD | §5, §7 durable rules | n/a | — |
| R2-15 | NOTE | README/plan contradict §5's denominator row | **partial** | README fixed (R2-05); `docs/investigation-plan.md:69` still says "neither we nor a reviewer can re-derive it" — see R2-38 |

## §3 HISTORY

| ID | sev | finding | status | evidence |
|---|---|---|---|---|
| R2-16 | LOW | forward pointers needed at Phases 28/29/30 | **partial** | 2 `SUPERSEDED` blocks (line 288, Phase 30 at 2075); Phase 28 "tools-only path does not exist" and Phase 29 `0x0428`/`0x043D` still lack one |
| R2-17 | LOW | "Current state" heading does not point to BRIEF | **done** | lines 290–291 |
| R2-18 | GOOD | Phases 28–34 structure | n/a | — |

## §4 docs/

| ID | sev | finding | status | evidence |
|---|---|---|---|---|
| R2-19 | GOOD | tooling-index shape | n/a | — |
| R2-20 | LOW | prompt-mechanics section in a user-facing doc | **kept** | the operator asked on 09-13 and again on 09-19 for fewer prompts and for the reasoning to be findable; the section is the record of what was measured (65% compound) and now of `scripts/`. Marked as kept here rather than moved |
| R2-21 | HIGH | `issues.md` BT-1 lacks the central result | **done** | 8 citations of EX-033…EX-04x (FD-22/23) |
| R2-22 | MED | register lacks the BlueZ crash entries | **done** | 5 mentions of the patches |
| R2-23 | LOW | BT-4 "still needed: a backtrace" stale | **open** | phrase still present (1) |
| R2-24 | GOOD | evidence model | n/a | — |
| R2-25 | HIGH | bug report's 7.6–16.2 s timing | **done** | 0 matches; rewritten around EX-037–043 (FD-17…20) |
| R2-26 | MED | `Regression: No`, kernel `-28` | **done** | 0 / names `-31` |
| R2-27 | MED | "Workaround in use" | **done** | 0 |
| R2-28 | NOTE | report clean of labels | n/a | — |
| R2-29 | MED | fix-proposal frame outlived its premise; no banner | **open** | three *historical corrections* inside, none saying the reset path is now believed destructive |
| R2-30 | LOW | "~53 s" fossil | **open** | 2 matches |
| R2-31 | LOW | §8 stale rows dated 2026-08-11 | **open** | 1 match |
| R2-32 | GOOD | source map / source access | n/a | — |
| R2-33 | MED | "GNOME is blind" derived from `-u` args, misses `bt-snapshot` | **open** | `source-map.md:19` still the `grep -ohE '\-u …'` derivation |
| R2-34 | LOW | kernel-per-boot table by index | **done** | no `7.0.0-30`/`-31` table in either file; only the package names in the download transcript |
| R2-35 | MED | external brief understates alt-1 (no sysfs reading) | **open** | `sysfs` 0, `EX-04x` 0 in `external-review-brief.md` |
| R2-36 | GOOD | brief's ground rules | n/a | — |
| R2-37 | GOOD | plan's revision section | n/a | — |
| R2-38 | MED | revision section stale on three claims | **open** | line 68 "13 of 34 … withdrawn … cannot re-derive", line 103 "silence *is* the alt-1 signature" |
| R2-39 | MED | backlog items with removed blockers unmarked; no status column | **open** | BL-01…BL-09 headings carry no status; BL-03/BL-08 still open at the code (R2-64/65) |
| R2-40 | LOW | v5.12 commit not named | **partial** | `docs/bug-report.md` names `517b693351a2`; `investigation-plan.md` does not |
| R2-41 | NOTE | investigation.md banner covers it | n/a | — |
| R2-42 | LOW | firmware-hypothesis lacks "secondary to alt-1" line | **open** | 0 mentions of alt |
| R2-43 | MED | changes-applied stops at 08-13 | **done** | 24 mentions of the patched daemon / drop-in; restore guide 2 |
| R2-44 | GOOD | read-back rule | n/a | — |
| R2-45 | LOW | restore guide carries a user-wide tool setting and repo `rm -rf` | **open** | 1 / 1 |
| R2-46 | MED | checklist gates predate the regression route; no patches row | **open** | 0 / 0 |
| R2-47 | GOOD | purge procedure, related-reports | n/a | — |
| R2-48 | MED | 23 tools absent from tooling-index | **open** | 23 still absent (list in `scripts/r2-checks.sh` output); a suite invariant was proposed |

## §5 bin/

| ID | sev | finding | status | evidence |
|---|---|---|---|---|
| R2-49 | MED | watchdog header lacks the project's verdict | **done** | line 69: "an early intervention destroys the …" |
| R2-50 | LOW | "NEVER been observed" claim | **done** | 0 |
| R2-51 | LOW | second-resolution filenames in bt-trace/bt-usbmon | **done** | both use `%N`/epoch forms (4 / 3 matches) |
| R2-52 | LOW | `disk_guard()` loop unguarded | **open** | `bin/bt-trace:112` `while (( $(free_gb) < MIN_FREE_GB ))` |
| R2-53 | GOOD | bt-capture seam, prune | n/a | — |

## §6 systemd/, etc/

| ID | sev | finding | status | evidence |
|---|---|---|---|---|
| R2-54 | MED | `bt-trial-auto` ExecStop probes; no `TimeoutStopSec` | **open** | `ExecStop=/usr/local/bin/bt-trial autostop`, no timeout — with R2-65 |
| R2-55 | LOW | modprobe dyndbg comment does not name the `len 27 mtu 9` site | **open** | 0 in the conf; the string appears in one tool |
| R2-56 | LOW | `BT_USBMON_BUS=3` in a unit | **open** | 1 |
| R2-57 | NOTE | journal-backup unit | n/a | — |

## §7 install.sh, uninstall.sh

| ID | sev | finding | status | evidence |
|---|---|---|---|---|
| R2-58 | HIGH | `--tools-only` reverted the baseline | **done** | fixed 09-16 for two files, third file 09-18 (register row) |
| R2-59 | MED | `--tools-only` writes the first-install stamp | **open** | stamp block at `install.sh:576` not re-verified for a tools-only guard; treated as open |
| R2-60 | LOW | allowlist comments vs `mkdir` in the arm | **open** | arm is `install\|rm\|rmdir\|mkdir`; comment not re-read — treated as open |
| R2-61 | LOW | `--help` range ends one line early | **open** | `sed -n '2,15p'`; line 16 is the example |
| R2-62 | NOTE | four tools checkout-only | n/a | justified by R2-87 |
| R2-63 | GOOD | three-guard block | n/a | — |

## §8 tools/

| ID | sev | finding | status | evidence |
|---|---|---|---|---|
| R2-64 | HIGH | `bt-trial abort` deletes tracked evidence (BL-03) | **open** | `ls-files` 0 in `tools/bt-trial` |
| R2-65 | HIGH | `bt-trial autostop` probes a live controller (BL-08) | **open** | `hci_alive` at `tools/bt-trial:286` |
| R2-66 | MED | `bt-snapshot` hardcodes `3-3` | **open** | 2 |
| R2-67 | MED | archive suffix test; AMBIGUOUS uncounted | **partial** | suite half fixed (R2-100); `bt-archive:186` still `continue`s without a counter |
| R2-68 | GOOD | snapshot shape test | n/a | — |
| R2-69 | GOOD | backup/archive discipline | n/a | — |
| R2-70 | MED | sanitiser redacts SIG base UUIDs | **open** | `00805f9b34fb` 0 in `sanitize-logs.sh`; the test-suite maintainer's sanitiser gating touches the same file — coordinate |
| R2-71 | MED | `bt-capdiff --since/--until` replace instead of intersect | **open** | lines 135–136 assign |
| R2-72 | MED | `bt-postmortem` narrates the refuted hypothesis | **open** | line 176 "cmd_timeout is too late" hypothesis still the frame |
| R2-73 | MED | `bt-health-report.sh` not mode-aware | **open** | 0 |
| R2-74 | LOW | `bt-exhibit` hardcodes `13d3:3503`; `bt-actions` classes | **open** | 1 / PROF present — EX-044's provenance table shows the hardcode |
| R2-75 | GOOD | capdiff, sanitiser gate, exhibit refusals | n/a | — |
| R2-76 | MED | `bt-status` counts discovery as audio | **done** | `\bsco\b` (2) |
| R2-77 | MED | `bt-incident` manifest `sanitised=yes` regardless | **open** | only header mentions |
| R2-78 | MED | `bt-diagnose` sends HCI | **done** | `--probe` opt-in (3) |
| R2-79 | LOW | hypothesis-era text; dated constants | **open** | 1 / 1 / 3 |
| R2-80 | GOOD | verify-restored, incident, status | n/a | — |
| R2-81 | MED | `bt-verify-install` cannot see `X`+`X.disabled`; advises `--apply` | **partial** | reports "disabled by bt-mode" for `.disabled`-only; no CONFLICT for both present; line 166 still `--apply` |
| R2-82 | LOW | `strings` without fallback | **open** | line 48 bare `strings` |
| R2-83 | GOOD | device-ID match, derived list | n/a | — |
| R2-84 | MED | `bt-sco` prints the retracted signature | **partial** | signature line present (1); `--window` now in usage |
| R2-85 | LOW | `bt-window` header exit contract; `lsusb` | **open** | 0 / 1 |
| R2-86 | LOW | `bt-fault-window --at` drops the zone | **open** | line 87 re-parses date and time without offset |
| R2-87 | GOOD | fault-window instrument | n/a | — |
| R2-88 | LOW | `bt-usbstate` port baked in | **done** | resolves by `idVendor` (1) |
| R2-89 | NOTE | env-history `?` | n/a | — |
| R2-90 | GOOD | provenance, usbstate, phase | n/a | — |
| R2-91 | LOW | `bt-context` half-redaction | **open** | upper-case colon form only, lines 90/113 |
| R2-92 | LOW | `bt-guards` bypasses the seam | **open** | 4 direct `journalctl`, 0 seam; the `_COMM=` form is the point — seam needs a field form |
| R2-93 | GOOD | logvolume, context, boot-stats | n/a | — |
| R2-94 | MED | `bt-state` probe via two callers | **done** | `--probe` (3); `bt-incident` writes `bt-usbstate` (2) |
| R2-95 | LOW | `bt-stage2` direct fields; `boot_indices()` triplicated | **open** | not changed |
| R2-96 | GOOD | boot-list ladder | n/a | — |
| R2-97 | LOW | fixture parser keeps only the last `-u` | **open** | `journal.sh:224` single `unit=` |
| R2-98 | LOW | `iso_secs()` ignores `Z` | **open** | 0 `Z` handling |
| R2-99 | GOOD | journal.sh seam | n/a | — |

## §9 tests/

| ID | sev | finding | status | evidence |
|---|---|---|---|---|
| R2-100 | HIGH | two invariants cannot pass | **done** | 09-16; green since |
| R2-101 | MED | tests pin BL-03/BL-08 behaviour without saying so | **open** | 0 `BL-03`/`BL-08` in `run-tests` |
| R2-102 | MED | no `--tools-only` test | **done** | "tools-only leaves …" invariant, three files since 09-18 |
| R2-103 | LOW | `tests/README.md` stale | **open** | "~2 s" at line 4 |
| R2-104 | GOOD | self-guards | n/a | — |

## §10 devtools/

| ID | sev | finding | status | evidence |
|---|---|---|---|---|
| R2-105 | HIGH | nothing reads CI | **done** | `devtools/ci`, `devtools/status` CI row (R2-105 register) |
| R2-106 | MED | `devtools/status` advises `--apply` unconditionally | **open** | line 107 — seen live on 09-18 in experiment mode |
| R2-107 | LOW | `devtools/README.md` lists 7 of 15 | **open** | now missing 8: `awk-coverage branch-status ci coverage-exclude py-coverage review-open status test-comprehension` |
| R2-108 | GOOD | repo-save, save, status, check | n/a | — |
| R2-109 | MED | = R2-02 | **open** | see R2-02 |
| R2-110 | GOOD | repo-scan, journal-contract | n/a | — |
| R2-111 | MED | four instruments disagree on a red run | **open** | `awk-coverage` 0 mentions of a red-run rule |
| R2-112 | LOW | eighteen line-pinned exclusion ranges | **open** | not re-derived; `devtools/coverage` cannot run here while a trial is open — CI is the check |
| R2-113 | GOOD | instruments individually | n/a | — |

## §11 evidence/, patches/, reviews/, comms/

| ID | sev | finding | status | evidence |
|---|---|---|---|---|
| R2-114 | MED | exhibit index truncates claims | **done** | 0 rows ending mid-sentence; extractor joins the paragraph |
| R2-115 | MED | `evidence/README.md` lacks exhibits/ and the finding | **open** | `exhibits/` 0; alt 2 |
| R2-116 | GOOD | incomparability note | n/a | — |
| R2-117 | MED | patches README "not watched preventing" | **done** | "fired four times" present |
| R2-118 | GOOD | both patches | n/a | — |
| R2-119 | MED | `verify.sh` covers one block | **open** | 14 IDs of 97 register rows |
| R2-120 | LOW | register claims `verify.sh` "runs every row's check" | **open** | `reviews/README.md:242` still says so |
| R2-121 | GOOD | crash-site resolution | n/a | — |
| R2-122 | GOOD | comms, lessons | n/a | — |

## Open, in the review's own order of work

1. **BL-03 / BL-08 at the code** — R2-64, R2-65, with R2-54 (the unit) and R2-101 (the two tests that pin today's behaviour, to be changed on purpose). The operator decided BL-08 on 2026-08-22; the tool has not caught up.
2. **Advice that reverts the baseline** — R2-106 (`devtools/status`), R2-81 (`bt-verify-install` CONFLICT + remedy). Both print `--apply` in experiment mode today.
3. **Sanitiser and instruments** — R2-70 (SIG UUIDs; coordinate with the test-suite maintainer's gating), R2-111 (one red-run rule), R2-02/R2-109 (shallow refuse).
4. **Docs outrun by evidence** — R2-29/30/31 (fix-proposal), R2-33 (source-map derivation), R2-35 (external brief), R2-38/39/40 (plan revision + backlog status), R2-42, R2-46 (checklist), R2-48 (tooling-index completeness, as a suite invariant), R2-115 (evidence/README), R2-10, R2-23, R2-45.
5. **Tool verdict text and one-machine constants** — R2-72, R2-73, R2-84 (verdicts); R2-66, R2-74, R2-79, R2-56 (constants); R2-71, R2-77 (correctness).
6. **Small** — R2-16, R2-52, R2-55, R2-59, R2-60, R2-61, R2-67, R2-82, R2-85, R2-86, R2-91, R2-92, R2-95, R2-97, R2-98, R2-103, R2-107, R2-112, R2-119/120.

Work on this list is recorded as register rows in `reviews/README.md` §R2 as each closes;
this file is the baseline it is measured against and is not edited afterwards.
