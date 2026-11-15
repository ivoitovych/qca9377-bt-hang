# What is left of the comprehensive project review: `main` rechecked

- **Written:** 2026-11-15T20:44Z (UTC), on the branch that holds the review.
- **The review:** [`review-comprehensive-project-consistency-review-20261115-005742.md`](review-comprehensive-project-consistency-review-20261115-005742.md)
  (commit `162d3b9`), made on `main` at `da23558`. Ids below (F-01, S-01, T-08 …) are its ids.
- **Rechecked against:** `main` at `a8d0eb45` ("BRIEF: the 16 old remote branches are
  deleted", 2026-11-15 21:36 +0100), 26 commits after `da23558`.
- **How:** every finding of the review and every finding of the companion file was looked up
  again in a checkout of `a8d0eb45`: the lead reviewer's own findings by the lead reviewer,
  each part's findings by the worker that made them. Files were read; nothing was run except
  `scripts/send-table-check.py` (read-only). The remote itself was not queried beyond a fetch.
- **Verdicts:** **fixed** · **partly** (what is left is named) · **not addressed** ·
  **waits for the author** (recorded by the maintainer as a decision for the operator) ·
  **new** (introduced by the changes) · **withdrawn** (the review was wrong).
- The maintainer's own record of the first round is
  `reviews/2026-11-15T1751Z-project-review-fixes-reaction-checks.md` on `main`; where it and this
  page differ, section 5 says so.

Findings are written here in the order rechecked; the summary and the list of what is left are
in sections 1 and 2, written last.

## 1. Summary

The reaction on `main` was fast and aimed at the right things. Of the review's 83 findings:

| | fixed | partly | not addressed | waits for the author |
|---|---|---|---|---|
| High (15) | 7 | 5 | 0 | 3 |
| Medium (49) | 13 | 16 | 19 | 1 |
| Low (19) | 7 | 5 | 7 | 0 |
| **all (83)** | **27** | **26** | **26** | **4** |

One part of one finding is withdrawn (D-01: the pinned commit of the Tested-by mail exists),
and one count in the review was wrong (C-06: 20 files, not 17). Eleven new items came with the
changes (3.8), none High.

- **What to send (the review's group A): solved in the main.** One table names the directory of
  every package, a script checks it, replaced directories are marked. The copies below the
  table and in `rd-2026-11-14.md` were not brought along, and two rows point at a directory
  that does not hold the whole package (CO-35) or whose cover describes another series (CO-02).
- **Unsafe code (group C): solved, with one gap.** `uninstall.sh` and `runtime-mgmt-test.sh` no
  longer touch the modules, the option loops are fixed. The archive guard misses the case its
  own comment describes: an older archive made with another compressor is still deleted without
  a count (T-08).
- **Clean answers without looking (group D): about half.** The identity gate, the SCO ledger,
  `bt-diagnose`, the trial reports and the mail check are fixed; the ledger fix probably turns a
  boot with no calls into an error (N-02). About fifteen scripts and twenty test assertions are
  as they were.
- **Drift between documents (group B): the front pages are fixed, the second row is not.**
  `README.md`, the STATUS rows named in the review, the BRIEF table and budgets now agree. The
  dossier front pages, `docs/issues.md`'s sections, `patches/*/README.md`, the older `docs/`
  files, `reviews/README.md`, `HISTORY.md`, `evidence/exhibits/README.md` and
  `contributions/rd-2026-11-14.md` were not touched, and the corrections of 11-15 were again
  applied to one copy at a time: BRIEF now disagrees with itself in four new places (the bot
  time, the survivals, the branch names, load/restore), and the README's re-dated block kept two
  bullets of 11-12.
- **The working arrangement in the text (group E): waiting for the author's decision,** as the
  maintainer records. Meanwhile one more file of that kind was committed (N-01), and no scan
  pattern exists yet, so the forward-only approach that was proposed is not in force either.

## 2. What is left, in the order suggested

**Before any send**
1. CO-35: put the request, the covers and the backports where the table says to send from, or
   point the table at them (N-03).
2. CO-02: a cover for the two-patch candidate; decide the stable trailer once; re-test CO-30 on
   it (N-08).
3. The index rows of `contributions/README.md` (`:82`, `:84-85`, `:100`, `:101`, `:115`, `:122`)
   and `contributions/rd-2026-11-14.md:76-77` still name replaced directories; the six replaced
   directories without a marker; the one `SUPERSEDED.md` that points at a superseded directory
   (C-02).
4. CO-43: the BT-18 row's evidence cell, patch 3's message and the series cover still say the
   system path is unchanged (C-05).
5. `<AUTHOR-EMAIL>` in `CO-38-…/send-20261114/bluez-cover-body.txt`, a current package (C-06).
6. CO-03 against the Ubuntu bundle: which build is staged (R-01; needs the laptop).

**Code**
7. `tools/bt-archive`: count every `boot-<id>.export.*` before the sweep (T-08).
8. `scripts/sco-ledger.sh`: a boot with no SCO line must not read as unreadable (N-02).
9. The test that calls `runtime-mgmt-test.sh load` for real (N-05); the identity switch's
   remaining holes (N-04); `guard()` failing open (K-01).
10. The scripts that still give a verdict they did not measure (K-04 list), `compile-mgmt-at.sh`
    (K-02), `bt-trial-audit` and `journal.sh` (T-10), `hci_alive` (T-09).
11. `install.sh`/`uninstall.sh`/`bt-verify-install` for `bt-journal-files` and the conditional
    archive unit (I-03, N-09); `bin/bt-evidence`'s probe.

**Documents that still say the old thing**
12. `docs/restore-original-state.md:84` and `docs/changes-applied.md` (they still describe or
    perform the btusb reload, I-01); "three demonstrations" in three `docs/` files (I-04);
    `docs/install.md` (I-05).
13. `BRIEF.md`: `:94`, `:105`, `:108`, `:141`, `:142`, `:145`, `:148`, `:333`, `:384`, `:677-683`,
    `:781`, `:815`, `:832`, `:841`, `:863` (F-07, F-08, F-09, T-09, G-02, M-02).
14. `README.md:133-134`, `:153`, `:173-186`, `:264-271`, `:286` (T-04, N-07, PA-01, M-02).
15. `docs/STATUS.md:50`, `:51`, `:114`, `:127`, `:128`, `:154`, `:191`, `:463-465`, the M rows' order
    (C-03, IS-07, S-13, S-07, L-01, S-14, S-09).
16. `docs/issues.md`: BT-18 to BT-23, `:1212`, U8, U12, U13, M-3, the "Evidence model" section,
    "On the wider claim" (IS-03, IS-06, IS-07).
17. `evidence/exhibits/README.md` (seven unmarked rows) and EX-043 (E-03, E-04).
18. `patches/kernel/README.md`, `patches/diag/README.md`, the two check scripts (PA-01).
19. `reviews/README.md` (about 67 unlisted files, four stale rows and blocks) (M-02).
20. The dossier front pages and `rd-2026-11-14.md` (C-01, C-03, C-07); the older `docs/` files
    without a date label (D-01, D-02); `HISTORY.md` (H-01).
21. Identifiers in full (S-10): the count went up in STATUS and `docs/issues.md`.
22. One place for "current" (S-12): the maintainer's record leaves it as an editorial decision.

**Tests**
23. The 23 assertions and lists of 3.4; the light mode into the suite (N-10).

**The author's decisions**
24. The working arrangement in the text (P-01 to P-03, S-11, N-01), and until it is decided a
    scan pattern on the save path so that no new file adds to it.
25. Whether all fifteen passwords of P-04 were revoked.
26. Where the review files live (they are on this branch only; `docs/STATUS.md` names the commit).


## 3. Recheck in detail

Line numbers are those of `main` at `a8d0eb45`.

### 3.1 The lead reviewer's findings (review sections 3.1 to 3.3, 3.5, 3.6)

| id | was | now | what is left |
|---|---|---|---|
| F-01 | Medium | **fixed** | `README.md:149` is dated 2026-11-15 and points at STATUS; the Environment block ends at `7.0.0-43` stock (`:207-208`) |
| F-02 | Medium | **fixed** | `README.md:164` "At three boots (2026-11-05, 11-11 and 11-13 …" |
| F-03 | Medium | **fixed** | `README.md:175-181` names CO-43 and CO-44 |
| F-04 | Low | **fixed** | `README.md:46` "the three BlueZ fixes in the daemon and its shared code" |
| F-05 | Low | **fixed** | `README.md:261-263` lists what `results/` holds |
| F-06 | Medium | **fixed** | `BRIEF.md:433` and `:471`: 20 GB for bt-trace, 25 GB for the desktop captures |
| F-07 | Medium | **partly** | The block's heading (`BRIEF.md:79`) now says "stale lines corrected 2026-11-15 where marked". Still unmarked: `:94` "re-checked 2026-10-28"; `:105` "`-42` runs without it" beside `:102`, which says the laptop left `-42`; `:108` and `:141` call the archive timer "transient, gone at every reboot" while `docs/STATUS.md:295` says a persistent `bt-raw-archive.timer` replaced it on 11-13; `:142` "Open investigations" still stops at BT-11. `:148` "Last updated: 2026-11-14" was not moved although the file was corrected on 11-15 |
| F-08 | Low | **partly** | `BRIEF.md:329` now counts "12 deaths / 2 survivals"; `:333-334` still says "The survival was the peripheral's choice" in the singular, and §2 still has one survival row |
| F-09 | Low | **partly** | `BRIEF.md:384` now reads "within 90 min (… which against the 18:44 UTC send is 3 h 21 min, not 90 …)": one sentence asserts and denies the same thing. `patches/bluez/README.md:145` keeps the heading "22:05 / 22:10 UTC"; `reviews/2026-09-20T0300Z-bluez-ci-bot-results.md:3-4`, `reviews/README.md:71` and `HISTORY.md:3318` ("within ninety minutes of receipt") are unchanged. The mailbox is CEST, which gives 20:05/20:10 UTC and 81/86 minutes; the maintainer's record says the headers are not in the repository, so it is left open. Either relabel the times as local, or drop "within 90 min" |
| F-10 | Low | **fixed** | `BRIEF.md:342` "(the count when this was written; §2 has 12 now)" |
| F-11 | Low | **partly** | `BRIEF.md:214` now says `tmp/port-check/check.sh` is "a machine-local script, not in a clone"; `:545` (`tmp/bt9-repro/ratatoskr-scan.py`) and `:208` (the work-area path) are unchanged |
| F-13 | Low | **fixed** | footnote ² is below the table (`BRIEF.md:291`) |
| P-01 | High | **waits for the author** | unchanged: 2,716 files, 11,068 lines (`git grep -l -I 'agent-work' \| wc -l`); no file was added to the set since the review. The maintainer's record (point 13) says a forward-only approach was put to the operator |
| P-02 | High | **waits for the author** | every quoted line is still there (`HISTORY.md:5378`, `BRIEF.md:156`, `:174`, `:208`, `docs/STATUS.md:165`, `:373-382`) |
| P-03 | High | **waits for the author** | the four places with product names or tool-specific paths are unchanged |
| P-04 | Medium | **not addressed** | `contributions/CO-25-qualcomm-rom-report/log.md:272-277` still does not say whether all fifteen passwords were revoked. The check script itself is fixed (K-03) |
| S-01 | High | **fixed** | `contributions/README.md:19` "What to send" names one directory per package; `scripts/send-table-check.py` → "20 rows, 0 problem(s)" (run on the checkout); `BRIEF.md` and STATUS point at the table. Remains of it are under C-01 to C-07 below |
| S-02 | Medium | **fixed** | `docs/STATUS.md:80` (BT-9), with a dated correction |
| S-03 | Medium | **fixed** | `docs/STATUS.md:72` (BT-1), with a dated correction |
| S-04 | Medium | **fixed** | `docs/STATUS.md:81` (BT-10) names the 11-14 package and the lines the request covers |
| S-05 | Low | **fixed** | `docs/STATUS.md:87` (BT-16): three occurrences, `-42` with E3 and `-43` stock |
| S-06 | Medium | **fixed** | no `tmp/review-doc-20261102/followups.md` left in STATUS |
| S-07 | Low | **not addressed** | `docs/STATUS.md:154` "has been stopped since 10-13" against `BRIEF.md:141` "Paused from 2026-10-11" |
| S-08 | Low | **fixed** | the U8 row no longer waits for trial E3 #1 |
| S-09 | Low | **not addressed** | rows still M-1, M-4, M-5, M-3, M-2 (`docs/STATUS.md:97-101`) |
| S-10 | Medium | **not addressed, slightly worse** | lines with an elided identifier in a code span: `BRIEF.md` 12 (was 12), `docs/STATUS.md` 40 (was 36), `docs/issues.md` 46 (was 44), `contributions/rd-2026-11-14.md` 10, `contributions/README.md` 4, `README.md` 1. The new "What to send" table is written in full; the new STATUS and issues.md text of 11-15 is not (`docs/STATUS.md:13` `CO-02-…/review-fixes-20261115/`, `docs/issues.md:1172`, `:1189`) |
| S-11 | Medium | **waits for the author** | as P-01 to P-03 |
| S-12 | Medium | **partly** | `README.md:149` and `docs/issues.md:16` now say they are summaries or pointers and that STATUS has the state. The blocks themselves remain: six "Current state" blocks in `docs/issues.md` (a seventh, the pointer, was added on top), `BRIEF.md:79`, `docs/STATUS.md:181`, `reviews/README.md:97`. The maintainer's record calls removing them an editorial decision not yet made |
| S-13 | Medium | **partly** | `BRIEF.md` now says the work areas were deleted on 11-14. `docs/STATUS.md:127` (U26) and `:128` (U27) still give only the deleted areas as their evidence |
| S-14 | Low | **partly** | the E3 #3 line is corrected (`docs/STATUS.md:238`, `BRIEF.md:132-138`); `docs/STATUS.md:463-465` still lists `ci/upstream-ci-local` as "Not on `main`, fit to land" |
| IS-01 | Low | **fixed** | `docs/issues.md:4-5`: twenty-five BT, five M, thirty-one U, four X |
| R-02 | Low | **not addressed** | `contributions/README.md:83` still "trigger 0/70 → 70/70"; the row states still are not the defined states |
| L-01 | Low | **not addressed** | `docs/STATUS.md:191` `scripts/usbip-bt-emu.py`, `docs/issues.md:1068` `tools/suspend-cycles.py`, `BRIEF.md:122`, `:145` the retired branch names |

### 3.2 Code: `tools/`, `bin/`, the installer (T-01 to T-11, I-01 to I-05)

| id | was | now | what is left |
|---|---|---|---|
| T-01 | High | **fixed** | `tools/bt-sco`, `bt-actions`, `bt-capdiff`, `bt-context`, `bt-logvolume`, `bt-phase` exit 2 on a missing value; `--window --raw` is handled |
| T-02 | Medium | **fixed** | `tools/bt-window:8-13` |
| T-03 | Medium | **fixed** | `tools/bt-diagnose:51-55` returns 2 when no boot was read |
| T-04 | Medium | **not addressed** | `README.md:133-134` "every tool takes `BT_VID`/`BT_PID`"; `tools/bt-status:93` still hard-codes the default |
| T-05 | Medium | **not addressed** | `docs/tooling-index.md:86`, `:126-134`, `:151` still list git-ignored paths without a mark; the same 15 executables are missing from the index |
| T-06 | Low | **partly** | `bt-sco` usage fixed; `tools/bt-incident:26`, `:36`, `:103` and `tools/sanitize-logs.sh` unchanged |
| T-08 | High | **partly** (checked) | `tools/bt-archive:362-383` now counts the records of the archive on disk and refuses a shorter export. The guard is inside `if [[ -e "$OUT" ]]`, that is, only when an archive with the *same* extension exists. When the old archive was made with another compressor (`.gz` on disk, `.zst` now), the guard is skipped and the sweep at `:403-407` (`rm -f "$stale"` for every other `boot-<id>.export.*`) still deletes the older, possibly longer archive. The comment above the sweep (`:386-396`) describes exactly that two-compressor case. Left: run the count over every `boot-<id>.export.*` before the sweep, whatever `$OUT` is. The usage text still omits `--replace` |
| T-09 | Medium | **partly** | `tools/bt-trial:370-374`: `start` now sets an existing directory aside. Not addressed: `BRIEF.md:863-864` still says the directory is overwritten and `:815` still says `build=stock` without qualification; manual `ok` and `hang` still send HCI and the header does not say so; `hci_alive` returning 2 is still read as dead; the reads before the row still have no budget; the header, usage and banner ranges and the stale comments (`tools/bt-trial:901`, `tools/bt-snapshot:24`) |
| T-10 | Medium | **partly** | the two awk reports now exclude a `failed` row with BT-1 not observed and name it (`tools/lib/trial-summary.awk:121`, `tools/lib/trial-sco-table.awk:94`). Not addressed: `tools/bt-trial-audit` still "agrees" on an unreadable journal; `tools/lib/journal.sh`'s fast path still drops per-file failures |
| T-11 | Medium | **fixed** | `tools/bt-exhibit:69-72`. The Low items listed with it are unchanged |
| I-01 | High | **partly** | `uninstall.sh:285-294` never reloads btusb. `docs/restore-original-state.md:84` still says the setting "only flips back if btusb can be reloaded", and the manual rollback in `docs/changes-applied.md` still runs `modprobe -r btusb` |
| I-02 | Medium | **partly** | `install.sh:539-553` installs and enables the unit only from the checkout its `ExecStart` names. `systemd/bt-raw-archive.service:15` still has the absolute path; `docs/tooling-index.md:86` still says "installed by install.sh" with no condition; `BRIEF.md:108`, `:141` still call the timer transient |
| I-03 | Medium | **not addressed** | all six bullets (`bt-journal-files` not installed, the event unit's drop-in, `bin/bt-evidence`'s probe, `bin/bt-usbmon`'s mode, the dyndbg options, `20-verbose.conf`, `bt-verify-install`'s count). The maintainer's 11-15 message to the test-suite maintainer promises `bt-journal-files` in `install.sh`; not done yet |
| I-04 | Medium | **partly** | `install.sh:11`, `:36` now say two. `docs/tooling-index.md:233`, `docs/fix-proposal.md:9`, `docs/investigation-plan.md:55` still say three |
| I-05 | Medium | **not addressed** | `docs/install.md:79`, `:85`, the "What it installs" list; `docs/changes-applied.md:166`; `docs/restore-original-state.md:46`; `BRIEF.md:418-422` |

### 3.3 `scripts/`, `devtools/`, CI (K-01 to K-05, G-01, G-02)

| id | was | now | what is left |
|---|---|---|---|
| K-01 | High | **fixed** | `scripts/runtime-mgmt-test.sh:150-155` refuses `load` and `restore` with exit 2; the header no longer says "Everything is reversible". Left over: `:14-15` still list `load` and `restore` as verbs; the old swap code is kept under the labels `load_disabled)` and `restore_disabled)`; `guard()` (`:44-52`) still passes when `bt-window` or `bt-trial` is missing, and `trigger` and the daemon verbs, which power-cycle the adapter and restart bluetoothd, are still called "usable"; `BRIEF.md:772` says the verbs are refused by the code and `:781` still says they "must not be run" |
| K-02 | Medium | **not addressed** | `scripts/compile-mgmt-at.sh:29` unchanged: a patch that applies cleanly is refused |
| K-03 | High | **fixed** | `scripts/smtp-login-check.sh`: anything but the server's own refusal is INCONCLUSIVE, exit 3 |
| K-04 | Medium | **partly** | Fixed: `sco-ledger.sh`, `sco-ledger-boots.sh` (but see N-02), `bluez-tester-compare.sh`, `bluez-release-contains.sh`, `ci-local-publish.sh`, the checkpatch case of `ci-local.sh`. Left: three NOT RUN paths of `scripts/ci-local.sh` (`:586`, `:657`, `:743`) still end "no NEW finding" with exit 0; `btusb-has-device.py:18`, `:26`; `build-bluetooth-fulltree.sh:46`; `build-btusb-stable-matrix.sh:60-76`; `discovery-stop-race.py:59`; `journal-archive-grep.py:26`, `:38`; `bt-device-record.sh:16`, `:23`; `export-local-work.py:44`; `bt17-provoke.py:127-143`; the five `prove-*` scripts with no failing exit; `bot-ci-local/harness.py:207`; `sco-switch-windows.sh:24`; `desktop-capture-archive.sh:10`, `:20` (its 3 GB default still rewrites `BUDGET_GB`, now against the 25 GB of `BRIEF.md:433`); `supported-commands-survey.sh:23` |
| K-05 | Medium | **not addressed** | the `/root/exp/…` paths in six scripts, the stale headers of `export-kernel-review.sh` and `build-v2.sh`, `gitlint-check.sh:3` against `ci-local.sh:22`, `kernel-preflight.sh:8` against `:39`, the relative-path defects, `scripts/README.md:20-23` (now two of four named scripts have tests) |
| G-01 | High | **fixed** | `devtools/repo-save` reads the author from `WANT` in `.github/workflows/checks.yml` and refuses to guess. See N-04 for its test switch. `devtools/README.md:248` still says "the identity configured in the checkout"; `devtools/held:19` holds a third copy of the identity |
| G-02 | Medium | **not addressed** | every bullet: the push-range check (`devtools/repo-save:256`), CI's identity job on a forced update (`checks.yml:55-72`), `repo-scan --range` on the net diff, `repo-validate` parsing only `*.py`, the wider address allow-list (two entries were added on 11-15, one a fragment of a Message-ID), the gates that exit 0 when their tool is missing, the three test scripts nothing runs, "EIGHT JOBS" for nine (`checks.yml:26`), `BRIEF.md:832`, `:841`, `.gitignore:6-8` |

### 3.4 Tests (T-07, T-12, T-13)

Fixed, 6 of 29 items: the bt-capdiff window check (`tests/run-tests:7613`), the two
"evidence/sessions untouched" checks (`:7886`, `:7954`), the `--replace` negative grep
(`:10345`), the pipefail demo (`:3391`), the coverage floors in `tests/README.md:422`.

Not addressed, 23 items, all as in the review: the upgrade rehearsal's "17 checks" for 20
(`tests/README.md:376`); `autostop` missing from the bt-trial guard (`tests/run-tests:15549`);
rule 4's wording against `:2345`, `:5534`, `:5536`, `:9604`; the `|| true` checks (`:2193`,
`:10693`, `:11115`, `:11343`); the vacuous `results.tsv` check (`:3410`); 41 of 43 entries of
`tests/whole-boot-reads.txt` still "pending"; `--section` dropping `--serial` (`:161`); the weak
globs (`:5439`, `:5496`, `:7828`); the duplicate description (`:8074`, `:8534`); the fixture
built from the real `evidence/trials/results.tsv` (`:9522`, `:9561`); `tests/machine-tools`
without `gsettings`, `pw-metadata`, `dbus-monitor`, `dpkg`, `getent`, `ps`, `df`, `pgrep`; the
unreachable gate and the empty-list case in `tests/system-roundtrip`; the silent skips (`:14124`,
`:14560`, `:14600`, `:8863`, `:14110`, `:10505`); the staged `--apply` tests on `0cf3:e300` only;
the stale comments and counts.

### 3.5 Evidence, exhibits, `HISTORY.md` (E-01 to E-04, H-01)

| id | was | now | what is left |
|---|---|---|---|
| E-01 | Medium | **fixed** | `BRIEF.md:282` "**0** (8 × `len 90 mtu 9`, `EX-037`)"; EX-042's delay is "not recorded" |
| E-02 | Medium | **partly** | `BRIEF.md:132-138` now says row 3 is a later boot that reused the number, and that the CO-02 boot's result was recovered (63 links, 0 timeouts). The reuse of E3 #5 and #11 is only in their note files; E3 #6, #7, #8, #10, #11 still have no note saying what their `failed` means (the reports now exclude them, T-10) |
| E-03 | Medium | **not addressed** | `evidence/` is unchanged: the index still lacks the marks for EX-093, EX-086, EX-007, EX-006, EX-058, EX-033, EX-036 |
| E-04 | Low | **not addressed** | EX-043 without `exit status` and `redacted`; `BRIEF.md:311-312` still reads as a sum over EX-055, EX-056, EX-058; EX-057's `-107`; `EX-038:42`; `evidence/README.md` |
| H-01 | Medium | **partly** | `BRIEF.md:887` now "dated chapters to 2026-11-14". `HISTORY.md` itself is untouched: `:901` (first early reset), `:2715` (the withdrawn wording), `:6`, `:11-15`, `:3261`, `:1774`/`:1850`, `:4100`/`:5384`, `:4802`, and the elided identifiers (`:4473` is outside any "moved verbatim" block) |

### 3.6 `docs/`, `patches/`, `comms/`, `reviews/` (D-01, D-02, PA-01, M-01, M-02, IS-02 to IS-08)

| id | was | now | what is left |
|---|---|---|---|
| D-01 | Medium | **not addressed** | `docs/external-cache.md:28`, the manifest's row 4, `docs/source-map.md` and `source-access.md` without a date, the 5.87 control output not shipped, `docs/mesh-tester-ci/README.md`. **Withdrawn** from it: the Tested-by mail's pinned commit `ccfc358…` exists on `main` and holds the 159 logs; the review's clone was too shallow to see it |
| D-02 | Medium | **not addressed** | `docs/kernel-send-package.md`, `pre-submission-checklist.md`, `missing-quirks-entry.md` (still "the full argument" at `README.md:103-106` without the author, v7.3-rc1, the stable list, the totals), `external-review-brief.md`, `review-task-bluez-patches.md`, `related-reports.md:172`, `bug-report.md:174`, the stable-request row of `docs/sent-mails.tsv`. Fixed in it: `README.md:264` "the applied BlueZ patches" |
| PA-01 | Medium | **not addressed** | `patches/kernel/README.md:7` ("with the next bluetooth-next pull"), `:252`; `patches/diag/README.md:52`, `:118`; the two check scripts with a relative `BT_PATCH_DIR`; `patches/kernel/bt9-stable/README.md:104`, `:140`; `patches/bluez/README.md:118`; `patches/bluez/btdev-vla/README.md:3`; `README.md:264-271` "(E1, E3)"; `HISTORY.md:4802`. The bot-time part is F-09 |
| M-01 | High | **partly** | `BRIEF.md:222-227`: the two commits are on `main` as the ports `8b71499` and `a56141e`, and the 16 branches are reported deleted. `docs/STATUS.md:463-465` still says "Not on `main`, fit to land"; and see N-06 |
| M-02 | Medium | **partly** | Answered in `comms/2026-11-15T2130Z-…`: the four questions of 11-07 and the `tests/test-suite` request. Not addressed: `reviews/README.md` lists none of the nine new files of 11-15 (about 67 unlisted now), rows R2-21, R2-25, R2-64/65 (`:310-312`), the CO-01…CO-10 block (`:443-453`), `:202`, `:283`; `BRIEF.md:145` (retired branch names, against `:226`); `BRIEF.md:677-683` (§9.2, the device survey); `BRIEF.md:573` (lessons); `README.md:286` (the `review/…` branch convention); the requests of 10-19/20/21 to and from the second maintainer |
| IS-02 | High | **fixed** | `docs/issues.md` BT-24 and BT-25 have status blocks dated 11-14. `:1212` still says "Next: a kmemleak run" under the new block |
| IS-03 | Medium | **not addressed** | `docs/issues.md:1099`, `:1116`, `:1136`, `:1142`, `:1157` (BT-18 to BT-23) still stop at 11-13 |
| IS-04 | Medium | **fixed** | U24 in `docs/STATUS.md` and the register row (`contributions/README.md:118`) |
| IS-05 | Low | **not addressed** | U23's two sets of counts; evidence under `tmp/`, `cache/` and the deleted work areas |
| IS-06 | Medium | **not addressed** | `docs/issues.md:2042` ("On the wider claim"), `:2073`, `:2081` |
| IS-07 | Medium | **not addressed** | U12 (`docs/issues.md:1673`), U8 (`:1516`), U13's owner (CO-27 in `docs/STATUS.md:114`, CO-42 in fact), M-3 (`:720`), the "Evidence model" section (`:213-224`), U10 |
| IS-08 | Low | **not addressed** | M-1 and M-2 without sections; U21–U28, U30, U31 as rows only |

### 3.7 Contribution packages and dossiers (C-01 to C-07, R-01)

| id | was | now | what is left |
|---|---|---|---|
| C-02 | High | **partly** | The table (`contributions/README.md:31-52`) and a `SUPERSEDED.md` in each replaced directory name the right package for CO-04, CO-05, CO-20, CO-21, CO-23, CO-11. Left: the index rows of the same file still name the replaced directories (`:82` CO-02 `send-v2-20261114/`, `:84-85` CO-04 and CO-05, `:100` CO-20 "two btusb patches", `:101` CO-21, `:115` and `:122` CO-35 `send-20261102/`), and so does `contributions/rd-2026-11-14.md:76-77`, which `BRIEF.md:171-173` still calls "the page of record". `contributions/README.md:22` says every older directory carries a superseded line; missing in `CO-35-…/send/`, `send-20261102/`, `send-20261101-draft/`, `CO-21-…/patches-20261101/`, `CO-43-…/send-series-20261114/` (it has `HELD.md`), `CO-02-…/review-fixes-20261115/patches/main-v2/`. `CO-02-…/send-v2-20261114/SUPERSEDED.md` sends the reader to `send-v2-review-fixes-20261114/`, which is itself superseded. The replacement directories of CO-20 and CO-21 have no recipients or notes; CO-21's cover still says "Changes since the first draft" |
| C-04 | High | **fixed** | the table names `A-review-fixes-20261114/`; `A/` carries `SUPERSEDED.md`; `docs/STATUS.md` BT-20 follows |
| C-05 | High | **partly** | `HELD.md` and the table say B2 and D v2 are held; the BT-24/25 pair is settled (`send-bt24-bt25-20261114/`). Left: the evidence cell of `docs/STATUS.md` BT-18 still says "the system path unchanged by reading only" beside "held" in the same row; patch 3's message and the series cover are unchanged; the dossier README and the register row still say "five patches"; the kmemleak counts (11 of 12, 12 of 12) are not reconciled |
| C-06 | Medium | **partly** | the three old directories now carry `SUPERSEDED.md` and the maintainer keeps the placeholders as the record of what was reviewed. One is in a current package: `contributions/CO-38-…/send-20261114/bluez-cover-body.txt` has `From: … <AUTHOR-EMAIL>`. **Correction to the review:** it counted 17 files; there were 20 at `da23558` and there are 20 now (the maintainer's point 11 is right) |
| C-01 | Medium | **not addressed** | the CO-02 dossier `README.md` (state 2026-11-12) and `log.md` (ends 11-02); `README.md:150-158` of the repository (see N-07); the checksum file of `send-v2-20261114/`; `BRIEF.md:234` (D1/D2); the dossier's relative link |
| C-03 | Medium | **partly** | Fixed: `README.md:178-180` (the L2CAP lines), `BRIEF.md:104`, STATUS BT-10, "CO-28 waits". Left: CO-35's dossier README (`:5`), `docs/issues.md:889-891`, the `Signed-off-by` on patch 2 of each CO-35 line against `contributions/README.md:23` ("Each package carries no Signed-off-by"); `docs/STATUS.md:50` (CO-25: `reply-1-zijun-hu.eml`, v3); CO-30 (N-08); CO-09's body; CO-03's front page; CO-27; CO-34's `send/README.md:3` and `docs/STATUS.md:51` ("no BlueZ release yet"); the failing `SHA256SUMS` files |
| C-07 | Medium | **not addressed** | the dossier READMEs of CO-37, CO-38, CO-39, CO-41; `rd-2026-11-14.md`'s table against its own results; CO-38's README ("not shown") against its `CHECKS.md` ("flake"); the bundle's `BUNDLE.md:17`, `:55` and its checksum file; CO-44's `patch/`; CO-39's notes |
| R-01 | Medium | **partly** | Fixed: CO-37's row; BRIEF's list of packages; the claim that each package has `NOTES-FOR-OPERATOR.md` was dropped (now "in each package's notes", which CO-04, CO-05, CO-12, CO-20, CO-21, CO-22, CO-38 and CO-02 still lack). Left: **CO-03 against the bundle** (the maintainer's record keeps it open: it needs a read of the staged package on the laptop); D5 and D6 shown as taken (`contributions/README.md:92`, `:52`, `:70-72`); CO-29, CO-31, CO-32, CO-33 without a pointer; the stale rows CO-07 (`:87`), CO-34 (`:114`), CO-38 (`:117`), CO-39 (`:130`), CO-40, CO-41; "All twelve" in the 11-13 review; the roadmap and `REVIEW-ROUND-2026-11-01.md` |

### 3.8 New since the review (introduced by the changes, or found while rechecking)

- **N-01 (Medium, privacy, checked):** `comms/2026-11-15T2010Z-from-test-suite-maintainer-relayed-by-operator.md`
  is a pasted transcript. It keeps the running commentary of a working session (`:126`, `:128`:
  "… still running in the background after the worker restarted. I'm now checking the repository
  conventions …", "I'm setting up … as its own branch"), with "pasted by the operator" in its
  head. It was added after the review's section 3.2 was known, and `comms/` is append-only by its
  own rule. It has no front matter and no recipient in its name.
- **N-02 (Medium, likely, read not run):** `scripts/sco-ledger.sh:49` ends in
  `journalctl … --grep '…' | awk '…'` under `set -uo pipefail` (`:30`). `journalctl --grep` exits 1
  when nothing matched (the project's own `scripts/prove-trial-nomatch.sh` is about this), so a
  readable boot with no SCO line makes the script exit non-zero, and the fixed
  `scripts/sco-ledger-boots.sh` then prints "UNREADABLE — excluded from the totals" for it and
  exits 2. A boot without calls now breaks the multi-boot count. To confirm on the laptop with a
  boot that had no call.
- **N-03 (Medium, checked):** the table's CO-35 row (`contributions/README.md:41`) sends from
  `CO-35-…/review-fixes-20261114/`, and `send-20261114/SUPERSEDED.md` says the same. That
  directory holds notes, the reduced patches and scripts; the request, the SCI request, the
  covers and the full backports are only in the superseded `send-20261114/mail/`. The
  replacement is thinner than what it replaces.
- **N-04 (Medium):** `BT_REPO_SAVE_CONFIG_IDENTITY=1` (`devtools/repo-save:148-170`) restores the
  configuration-based identity check. It is refused in the project's own checkout and when a
  `remote.*.url` is not a local path; it does not look at `pushurl` or `url.*.insteadOf`, it
  passes in another local clone of the project, and `tests/run-tests:548` exports it for the
  whole suite. It is not listed in `tests/system-resources.md`.
- **N-05 (Medium):** the new test block runs `scripts/runtime-mgmt-test.sh load patched` and
  `restore patched` from the checkout (`tests/run-tests:15260`) and relies on the refusal it is
  testing. The suite can run as root on the investigation machine; if the refusal regressed, the
  test would perform the swap. Reading the refusal from the source, or stubbing `modprobe`,
  `rmmod` and `insmod`, would test the same thing without that.
- **N-06 (Medium):** `comms/2026-11-15T2130Z-from-main-branch-maintainer-to-test-suite-maintainer.md`
  says "Deleting the 16 branches remains the operator's" while `BRIEF.md:222` (commit `a8d0eb45`,
  24 minutes later) says they are deleted, and it quotes `BRIEF.md` as saying the 11-13 note
  "gives no command and no count", which `BRIEF.md` no longer says. The file is stamped 21:30Z;
  the commit that adds it (`c6589ccc`) is dated 20:12Z. This clone still shows the branches
  (`git branch -r`); the remote was not queried.
- **N-07 (Medium):** `README.md:149` is re-dated 2026-11-15, but its CO-02 bullet (`:153`) still
  says "as of 2026-11-12 … the next posting will be a v2" while `docs/STATUS.md:3-14` says the
  sleeping 2/2 deadlocks 3 of 3 and "is not to be sent"; the CO-25 bullet (`:173-174`) is at
  11-12 too. Its "Next candidates" (`:175-186`) omit CO-21, CO-20, CO-12, CO-23, CO-39 and CO-41,
  which the table lists as ready, and list CO-37 and CO-11 as ready packages.
  `reviews/2026-11-15T0115Z-submitted-contributions-status.md` still calls the lock cycle
  "possible … not settled" and names `send-v2-review-fixes-20261114/` as the v2 package.
- **N-08 (Medium):** CO-02's new candidate. `contributions/CO-02-…/review-fixes-20261115/msg/cover-alt.txt`
  is a three-patch cover for the two-patch candidate (it has three mentions of "Patch 3" and
  quotes the sco-tester totals measured on the sleeping 2/2); the directory has no checksum
  file; `alt-2of2` patch 2 already carries a `Cc: stable` trailer whose form the table leaves to
  the operator. CO-30's RFC (`rfc-20261114/README.md:3`: base `../co02-v2/kernel/`, which does not
  exist) was tested on the 2/2 that is now withdrawn; the table says only "waits for CO-02 v2".
- **N-09 (Low):** the conditional install of `bt-raw-archive` was not carried to
  `tools/bt-verify-install`, `tools/verify-restored.sh` or `uninstall.sh`: on any other checkout
  `bt-verify-install` will report the unit as not installed, and its advice cannot fix that. The
  staged-install test takes one branch per host and skips the other without a note
  (`tests/run-tests:12413-12432`).
- **N-10 (Low):** the light mode of `tools/bt-ui-capture` is exercised only by
  `scripts/prove-ui-capture.sh`, which neither the suite nor CI runs; the tool's header still
  says "passive monitors" although light mode registers events with the accessibility registry
  (the new `docs/ui-capture.md` says so); `-h` prints lines 2–80, into the code.
  `scripts/bt-ui-atspi.py` prints "NOT passive: registered …" even when every registration
  failed.
- **N-11 (Low):** `tools/bt-archive:380-381` keeps a refused export as
  `shorter-boot-<id>.export.<ext>`, which `--list`, `--check` and `--repair` do not see;
  `tools/lib/trial-summary.awk` names "E3 #3 and #4" in a general tool's warning text;
  `tests/README.md:61` says five bt-trial wrappers and there are six; `tests/whole-boot-reads.txt:13`
  says 41 reads in 21 files and has 43 in 23; a stray `# MARKER-NEW-TESTS-END` at
  `tests/run-tests:15525`; `scripts/send-table-check.py` passes an empty table and an ASCII
  "..."; the executable-bit check in `devtools/repo-validate:199-212` flags a tracked symlink to
  a script and treats a file name as a glob.

## 4. Where this page and the maintainer's record differ

`reviews/2026-11-15T1751Z-project-review-fixes-reaction-checks.md` (on `main`) answered the
earlier short reaction point by point. Compared with this recheck:

- Its points 1, 2, 4, 6, 7, 8, 9, 10 and 12 ("right", fixed) are confirmed here, with the
  remains listed above under F-07, F-08, F-09, K-01, I-02, I-04 and T-09.
- Point 3 (the identity switch): fixed as far as stated; N-04 lists what the guard does not see.
- Point 5 (the review is not on `main`): confirmed; item 26 above.
- Point 11 (`<AUTHOR-EMAIL>`): the record is right about the count, and this page corrects the
  review. One placeholder is in a current package (C-06).
- Point 13: confirmed as waiting; N-01 is new since.
- The record's STATUS summary says `bt-archive --replace` "keeps the old archive when the new
  export holds fewer records". That holds only when the old archive has the same extension
  (T-08).
- The record's "Left for a later pass" (S-08, S-14, C-03, C-07, D-02, PA-01): S-08 is in fact
  fixed; the others are as listed here. Not in the record at all, and not addressed: the tests
  (3.4), `tools/` beyond the items fixed (T-04 to T-06, T-09's remains, T-10's remains), `scripts/`
  beyond the six files changed (K-02, K-04's remains, K-05), `devtools/` (G-02), the installer
  (I-03, I-05), the exhibits (E-03, E-04), `HISTORY.md` (H-01), `docs/issues.md` (IS-03, IS-05 to
  IS-08), `reviews/` and `comms/` (M-02), the dossiers (C-01).

## 5. Companion file

The recheck of every single finding of the review's companion file, as each worker wrote it,
with the current line and a short quote, is in the companion file named below. The table
verdicts above were set by the lead reviewer from those and from his own reads; where a worker
rated a remaining part differently, this page is the later reading.

[`review-reaction-to-comprehensive-project-review-20261115-204454-detailed-recheck.md`](review-reaction-to-comprehensive-project-review-20261115-204454-detailed-recheck.md)
