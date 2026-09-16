# Comprehensive code review — 2026-09-16T0420Z

**Covers:** the tree at `3cf4dd6` (`origin/main` tip at review start, 2026-09-14
"Stop leading with project-invented labels in outward-facing prose").
**Branch:** `review/2026-09-16T0420Z`. **Predecessor:** `2026-08-15T1752Z-comprehensive-code-review.md`
(covered `ed82166`) and its reaction, `2026-08-16T0022Z-fixes-and-elaboration-for-2026-08-15T1752Z-review.md`.

**Method.** Same protocol as the predecessor: state of the tree and the previous
reaction verified first; then every file, one by one, in priority order — foundation
documents, deployed runtime, tools, tests and devtools, registers, evidence; findings
appended per item as each is completed; the overall summary written last. No agents.
Severity scale: **HIGH** (wrong result or lost data possible), **MED** (misleading or
drift-prone), **LOW**, **NOTE** (record, no action), **GOOD** (keep — and now marked
`REVIEWED-KEEP 2026-09-16T0420Z` at the practice, per the convention the reaction introduced).

**Numbering.** Findings are `R2-nn` (second comprehensive review), so they cannot
collide with the predecessor's `CR-nn` in the register.

## 0. State of the tree, and whether the previous review's reaction survived

### 0.1 What the tips looked like at start

- Working tree clean; checkout on `claude/code-review-comprehensive-wtftwp` at `3cf4dd6`
  (equal to `origin/main`); a stale local `main` at `3fe3b6c`, three behind. Committer
  identity in the container was a tool's; reset to the operator's before the first commit.
- **The checkout was a shallow clone** (`.git/shallow`, 5 boundary commits). Every
  ancestry question answered wrong until `git fetch --unshallow`: `origin/main` showed 70
  commits with two "roots" both dated 2026-08-22, no merge base with `ed82166` or with any
  commit of the previous reaction, and `devtools/branch-status` reported **all 18 branches**
  carrying work main lacks and one false stale-merge claim. After unshallowing: 332
  commits, every reaction commit an ancestor of the tip, 6 carriers (the known set), one
  true notice (`origin/claude/unit-testing-intro-0jlol1` moved 9 commits past its merge
  `25074a5`).
- **`awk` is mawk 1.3.4 here**; gawk installed before running the suite, exactly as CI does.

### 0.2 The previous reaction (2026-08-16T0022Z) — verified present, content and history

Checked on the tip, not recalled: all 30 signatures sampled from the 84 dispositions are
present (the `wd_early_ok` column and migration, `RESCUED`, `trial-reclass.awk` and its
DEPS, the NOHEADER refusal, byte-aligned ID scan, `RATEARGS`, Historical-claim extractor,
`runaway string`, the python3 warning, `RAPID_MAX`, the twelve drift-guard assertions,
`BT_BS_ROOT` and the moved-claim notice); 66 `REVIEWED-KEEP` markers in 37 files; the
register's rows and the tracker's four addenda on main. Suite grew from 637 to 774
invariants since. **The reaction survived and was built on.**

The 2026-09-13 foundation-file review's reaction is **partial**: its two in-place fixes
(HISTORY forward pointers, BRIEF §5 scope) landed; its first recommendation — one sentence
in README — did not (§1 below); the `BT1-CURRENT` wording is legitimately waiting on the
operator; the bug-report rewrite has not started (§4.2).

### 0.3 Findings on the state itself

- **R2-01 [HIGH] `main` fails its own suite, and has on every CI run since at least
  2026-09-13.** `tests/run-tests`: **2 of 774 red**; `repo-validate` therefore red;
  `devtools/coverage` refuses on a "stale exclusion" that is really the executed `bad`
  branch of a failing test; GitHub Actions runs 236–247 (every push from `411d05e` to
  `3cf4dd6`) all conclude `failure`. Both tests were added in `d70cb2e` (2026-08-31):
  - `tests/run-tests:7887` — `[[ -s "$SNOF/snap"/*-boot0/f-otherfail.log ]]`. **`[[ ]]`
    does not expand globs**, so this assertion has been unable to pass since it was
    written. The suite's own comment at line 4880 records precisely this lesson from an
    earlier instance ("`[[ -e ]]` does not expand globs — it tests a path containing
    literal asterisks"). The invariant it guards (foreign unit failures kept in
    `f-otherfail.log`) is in fact satisfied — the tool writes the file; the check is what
    is broken.
  - `tests/run-tests:7410` — the `--check` SHORT case removes only `boot-*.export.zst`
    after writing a `.gz` replacement, so on any host without `zstd` (this one; the
    compressor falls back to `xz`) two archives coexist and `--check` reports
    `AMBIGUOUS`, not `SHORT`. A test that passes where its author's tools are installed
    and fails elsewhere — the family this repository has named five times.
  Because `repo-validate` is CI's first step and it runs the suite, **every gate behind it
  has not executed on main in that window** — the coverage floors, the comprehensiveness
  floor, the journal contract, the round trip, and `repo-scan --all`. That is Phase 29's
  own lesson ("a gate that runs first hides the state of every gate behind it")
  recurring, three weeks after it was written down. BRIEF §9 says "the suite has not run
  in a while" because `run-tests` refuses while a trial is open on the machine — but it
  runs on every push in CI, and nobody read the result.
- **R2-02 [MED] `devtools/branch-status` gives confident nonsense on a shallow clone.** It
  refuses on an empty branch list, and should refuse — same discipline — when
  `git rev-parse --is-shallow-repository` is true: `git cherry`, ahead/behind and the
  merge-claim check are all unknowable across a shallow boundary. CI checks out at depth 1
  by design, so any future CI use of this tool would hit exactly this.
- **R2-03 [NOTE]** The register (`reviews/README.md`) has no rows for the three reports
  written after 2026-08-17: `2026-08-23T2340Z-ex032-crash-sites-resolved.md`,
  `2026-08-17T0022Z` is there but `2026-09-13-foundation-file-consistency.md` is not — and
  that filename **violates the register's own naming convention** (`<UTC timestamp>` with
  time; "two assessments on one day is a normal outcome"). Its findings have no action
  IDs and no verify commands, so nothing mechanical decides whether they are done — which
  is how §1's sentence survived it.

## 1. `README.md` (730 lines)

- **R2-04 [HIGH] The sentence the 2026-09-13 review called the most misleading in the
  repository is still there, unchanged.** Line 65: *"treat `docs/issues.md` as
  authoritative — it is kept current and this front page is not yet."* `docs/issues.md`
  cites nothing past `EX-021`; README cites `EX-033`; the project is at `EX-041`. One
  README commit has landed since the review (`3cf4dd6`, the label rule) and did not touch
  it. The review's recommended order put this first ("one line, removes an active
  falsehood") and it was the cheapest item on the list.
- **R2-05 [HIGH] README asserts a retracted claim and its retraction, 200 lines apart.**
  "Is it working?" (line ~301): *"⚠️ That baseline is no longer re-derivable … a reviewer
  cannot reproduce them"*. Status table (line ~590): *"Observational denominator ✅
  re-derivable — 34 boots, 287 timeouts, 13 hung, from `evidence/baseline/baseline.tsv`"*.
  BRIEF §5 lists the first as **FALSE**; `docs/bug-report.md` carries the correction with
  the awk one-liner that reproduces the figures. A reader who stops at the first is told
  the opposite of the truth by the file that BRIEF exists to protect.
- **R2-06 [MED] A second retracted claim survives verbatim.** "Not a *recent* regression"
  (line ~530): *"then `Looking for Alt no :6` and `:3` (the two probes), **then silence** —
  because selecting alt 1 is the bare `else` and logs nothing."* BRIEF §5: *"alt probes,
  then silence" — FALSE — artefact of those exhibits' own grep; data was flowing*. The
  traffic that was "silence" is the condition itself (`len 27 mtu 9`, Phase 34).
- **R2-07 [MED] The central finding is not on the front page.** `n = 5` across three
  kernels, alt 1 read from `sysfs` three times, `27`-byte frames into a `9`-byte endpoint,
  `~2.15 s` — none of it. The Status table's last row ("Alt-1 fallback dated to v5.12 ✅
  source at ten tags, and observed on the machine (`EX-033`)") is the *predecessor* of the
  result. "What is currently established" carries the August `BT1-CURRENT` block — blocked
  on the operator, correctly, but the paragraph *around* the block is not gated and could
  say what is known today.
- **R2-08 [LOW] Layout and tool tables drifted again** (the CR-04 class). The tree says
  "`docs/` ten documents" — there are sixteen (`tooling-index`, `source-map`,
  `source-access`, `external-cache`, `external-review-brief` unlisted); no `comms/`,
  `lessons/`, `patches/`, `tests/coredump/`. The diagnostic-tools table omits
  `bt-snapshot`, `bt-archive`, `bt-retention`, `bt-backup-journal`, `bt-usbstate`,
  `bt-fault-window`, `bt-guards`, `bt-crash`; the contributing table omits eight devtools.
  `docs/tooling-index.md` now exists as the derived answer to "which tool" — README
  should link it once instead of maintaining a second hand-written list (house rule 2).
  Also: the Tests section names two CI floors; CI enforces four.
- **R2-09 [LOW] "Install" leads with `--apply`** ("install and arm") and reaches
  `--tools-only` a screen later, on a page whose own text says the armed watchdog has
  three demonstrations of destroying this controller. Order the safe verb first.
- **R2-10 [LOW] Header line 3** still says "sometimes stops answering HCI during audio
  transitions" — true, but the strongest one-line statement the project has is now
  specific (transparent SCO on alt 1). Same root as R2-07.
- **R2-11 [GOOD]** The opening ("not a watchdog project"), the three-streams table, and
  the label rule commit (`3cf4dd6`) with its gate in `run-tests` are exactly right for an
  outward-facing page. The three `REVIEWED-KEEP 2026-08-15T1752Z` markers did their job —
  none of the marked sections regressed. Marked again where the page is re-marked below.

## 2. `BRIEF.md` (197 lines)

- **R2-12 [MED] §9 item 4 is the wrong fact.** *"The suite has not run in a while:
  `run-tests` refuses while a trial is open, correctly."* It has run on every push, in CI,
  and has failed every time since at least 2026-09-13 (R2-01). The staleness check
  `devtools/save` performs (newest `EX-` named, line budget) cannot see CI; the open thread
  that belongs here is "CI red since `d70cb2e`", and it was available from the Actions tab
  on every one of the twelve pushes.
- **R2-13 [LOW] The header pins a tip hash that rots on every commit.** *"tip `7c9427b`"*
  was three commits stale at `3cf4dd6` within hours. Either derive it (the file is read
  after a reset, when `git log -1` is one command away) or drop it and keep only "newest
  exhibit", which the save hook actually checks.
- **R2-14 [GOOD]** §5 (RETRACTED) is the highest-value 30 lines in the repository and the
  09-13 correction to it — *name the scope of what you retract* — was the right one. §7's
  durable-rules move (out of an uncommitted memory store) is exactly the class of fix this
  review keeps asking for. The 200-line budget is at 197 physical lines; the save hook
  counts non-blank, so it is not yet binding, but the next addition must cut first.
- **R2-15 [NOTE]** §5's row *"the 287-timeout denominator can't be re-derived — FALSE"*
  is contradicted by README (R2-05) and by `docs/investigation-plan.md`'s revision section
  (§4.4). BRIEF is right; the others were never re-read against it. A mechanical check —
  each §5 retracted phrase grepped against the tree — would have caught all three.

## 3. `HISTORY.md` (2825 lines; Phases 28–34 new since the previous review)

- **R2-16 [LOW] The forward-pointer convention was applied three times and is needed in
  at least three more places.** Phase 28 "What is not done": *"A tools-only deployment
  path … does not exist yet"* — Phase 29 built it. Phase 30: *"`lore.kernel.org` is 403
  from both environments"* — Phase 31 shows a UA block, and BRIEF §5 retracts it. Phase 29:
  *"`0x0428` versus `0x043D` … the comparison worth designing a protocol around"* — Phase 30
  §2 kills it (opcode ≠ air mode). Every BRIEF §5 retraction has an origin phase; each
  origin should carry the `⚠️ SUPERSEDED` block the 09-13 review proposed, and that is
  checkable: for each §5 row, does the phase that first asserted it point forward?
- **R2-17 [LOW]** "## Current state — as of the end of Phase 8 … ⚠️ SUPERSEDED" is still
  the only "current state" heading in the file, and it does not point to `BRIEF.md`, which
  is now the current state by definition. One line.
- **R2-18 [GOOD]** Phases 28–34 are the best-written part of the record: each ends with
  "The shape" (a transferable lesson) and "What is not done"; Phase 34 is the first with a
  pre-registered prediction; Phases 30 and 34 record the author's own errors at the same
  weight as the findings. Keep the structure; it is what makes the 09-13 harvest (§6 of
  that review) possible for Phases 1–27.

## 4. `docs/` (16 files)

### 4.1 `docs/tooling-index.md` (151) — new

- **R2-19 [GOOD]** The right shape: question → tool, with the two paid-for warnings
  (present ≠ complete; the BlueZ health block is journal-derived) beside the tools they
  qualify. Marked `REVIEWED-KEEP`.
- **R2-20 [LOW]** "Writing commands so they do not prompt" is assistant-tooling mechanics
  in a user-facing document — BRIEF §7 itself says such material belongs in the memory
  store. Keep the *rule* ("extract the recurring question into a tool") here; move the
  permission-matcher paragraphs out, or a contributor reads a page about a tool they do
  not use.

### 4.2 `docs/issues.md` (503) — declared authoritative, stalest of the set

- **R2-21 [HIGH] `BT-1`'s entry does not contain the project's central result.** Highest
  exhibit `EX-021`. The entry still argues from `EX-006`/`EX-009` ("setup unanswered in
  one, teardown in the other — the constant is the path, not the opcode"), lists "the
  leading discriminant" as five candidates, and closes with *"Still unknown: … what makes a
  given SCO operation fatal"* — while `EX-033`–`EX-041` answer it at `n = 5` (transparent
  air mode → alt 1 → `len 27 mtu 9` → ~2.15 s), `EX-039` answers recovery, and `EX-026`
  and `EX-034` bear directly on "whether stage 2 occurs at all without intervention". The
  file README routes readers to as "kept current" is two phases behind HISTORY.
- **R2-22 [MED] The register is missing the project's first deliverable.** "Six distinct
  defects" — but the two BlueZ NULL dereferences (`EX-032`, `patches/bluez/0001`, `0002`,
  the latter with four prevented crashes) have no `BT-n` entry, nor does the third
  unrelated `free()` crash of 09-08 that BRIEF §6 explicitly separates from the
  submission. An issue register that omits the two issues with patches is not the
  register.
- **R2-23 [LOW]** `BT-4` still says *"Still needed before filing: a backtrace from the
  aborting process"* — `tools/bt-crash` and `systemd-coredump` exist now (Phase 29), and
  BRIEF §9 item 5 reports 33 btmon cores in one boot. Either the backtrace exists and the
  status is stale, or it is the next step and the entry should say so.
- **R2-24 [GOOD]** The evidence model (two capture paths, three states; the probe as an
  intervention) and the six-levels table remain the clearest methodological statement in
  the repository. The `REVIEWED-KEEP` markers held.

### 4.3 `docs/bug-report.md` (699) — the deliverable

- **R2-25 [HIGH] The file that leaves the project contradicts the record on its central
  timing.** It states *"SCO setup → first timeout is a distribution, not a constant:
  7.6–16.2 s across n = 4"* and elsewhere *"the interval spans 2.1–155.8 s across
  instances"*. Phase 32 and `EX-033`/`036`/`037`/`038`/`040` establish that anchored on the
  *answered* setup the interval is **2.076–2.191 s, spread 115 ms, n = 5** — and that the
  spread the report quotes was an artefact of anchoring on whichever named command timed
  out. The 09-13 review's #7 already asked for the rewrite; this is the specific sentence
  a maintainer would test first.
- **R2-26 [MED] Header and summary are internally inconsistent with the rest of the
  tree.** `Regression: No` — while README, BRIEF §1 and the investigation plan name a
  **v5.12 behaviour change** as the regression candidate and the plan calls the regression
  report "the only unblocked route to upstream". `Date: 2026-08-11`; kernel `7.0.0-28` in
  System information (the machine has run `-29`, `-30`, `-31` since, all faulting).
- **R2-27 [MED] "Workaround in use: a userspace watchdog … issues `USBDEVFS_RESET`"** —
  it is not in use, deliberately, and has three demonstrations of destroying the device
  (Phase 28, BRIEF §7). A maintainer reading this would assume the reset path is benign in
  practice.
- **R2-28 [NOTE]** The report is *clean* of invented labels (verified by the new gate) and
  its correction blocks (over-withdrawn denominator; "no USB error followed" is evidence
  about the moment) are exactly right. The problem is age, not discipline.

### 4.4 `docs/fix-proposal.md` (657)

- **R2-29 [MED] The suggested commit message asks upstream to install the operation the
  record now believes destroys the device.** *"Add the device to the QCA ROME entries so
  the standard command-timeout reset path applies."* — while `docs/investigation-plan.md`
  (revision 2026-08-22) states Build A "automates the operation we have three
  demonstrations of killing the device with, and fires it at +0 s", and BRIEF §3 says
  "No software recovery exists". The document carries no revision banner pointing at that
  reversal; a reader of §1–§3 gets the 2026-08-11 project. Two `REVIEWED-KEEP` sections
  (six behaviours; the conservative message) are still correct *as* sections — the problem
  is that the document's frame outlived its premise.
- **R2-30 [LOW] A fossil inside a "corrections" block.** §3a "Two related corrections":
  *"Stage 1 lasts ~53 s, not ~6 h"* — `EX-029` is 47 338 s of stage 1. Filed as a
  correction, it now reads as the current belief.
- **R2-31 [LOW]** §8 status table: "Checked against current mainline ⚠️ `3503` still
  absent as of 2026-08-11" and "Early reset recovers, but not durably ✅" are five weeks
  stale, and the latter is exactly the reset BRIEF §5 retracts as the recovery ladder
  "destroyed nothing" → FALSE.

### 4.5 `docs/source-map.md` (125), `docs/source-access.md` (273) — new

- **R2-32 [GOOD]** The source map is the right artefact: a register of components with
  *seen?* and *read?* columns, derived from the capture tools' `-u` arguments with the
  command shown, and an exclusions table with evidence. `source-access.md`'s
  "'blocked' is not one thing" table (four causes, one status code) is the best
  operational lesson of the month, and it is stated with its own error kept visible.
- **R2-33 [MED] The map's central claim — "GNOME is blind" — is derived from the wrong
  tools.** The *seen?* column comes from the `-u` arguments of `bt-incident`,
  `bt-snapshot`, `bt-evidence`, `bt-context`. `bt-snapshot` (Phase 29) takes *one coarse
  cut* of the journal and writes `all.log`; if that cut is unit-filtered the claim holds,
  if it is the whole journal then `gnome-shell`, `gsd-rfkill` and `wireplumber` are
  captured today and rows 1–4/16–17 are wrong. Verified below (§4.9); the map should say
  which, and derive the column from `bt-snapshot`'s actual selector.
- **R2-34 [LOW]** Both files carry the "which kernel ran when" table ending at
  `7.0.0-30` (`-1`, `0`) — the machine has run `-31` since 09-12 and boot indices have
  shifted many times. This is the copy-forward class both files warn about; the table
  should be produced by a tool (`bt-boot-list` can print the kernel per boot) and cited
  by date, not by index.

### 4.6 `docs/external-review-brief.md` (322), `docs/external-cache.md` + manifest — new

- **R2-35 [MED] The hand-out understates the strongest evidence the project has.** §6
  belief 4: *"We believe the driver selects USB alternate setting 1 … via a fallback that
  logs nothing"* — alt 1 has since been **read from `sysfs` three times** (`EX-037`,
  `038`, `040`), and the `len 27 mtu 9` traffic that OB-02 shows two lines of is the
  condition itself. An external reviewer working from this brief would reconstruct
  September's finding from August's data. It also lists kernels `-28`/`-29` only. The
  brief's §6.1 shows the right pattern ("settled since this was written") — the alt-1
  observation needs the same block.
- **R2-36 [GOOD]** The brief's ground rules (cite the version; open the URL; absence of a
  log line is not absence of the event; negative results required) and the merge format
  (findings keyed by component × observation, disagreements kept) are what an external
  review needs and rarely gets. The cache manifest with publisher-checksum verification is
  the right way to hold third-party artefacts outside a public tree.

### 4.7 `docs/investigation-plan.md` (789)

- **R2-37 [GOOD]** The 2026-08-22 revision section is the best example in the tree of
  superseding without rewriting: "where the two disagree, this section wins", each
  overturned item named with its exhibit, the regression route stated as the one
  unblocked path. `BL-04`'s addendum (the positive-control rule for zero results) and
  `BL-08`'s addendum (the operator's "not a control if it depends on remembering") are
  the two most transferable lessons in the repository. `REVIEWED-KEEP` held.
- **R2-38 [MED] The revision section is itself now stale on three claims it corrects
  others for.** *"`EX-018`'s '13 of 34 boots' is withdrawn — neither we nor a reviewer can
  re-derive it"* (BRIEF §5: FALSE); *"`:6` then `:3` and silence is the alt-1 signature"*
  (BRIEF §5: silence was an extraction artefact); *"the `0x0428` versus `0x043D`
  comparison … worth designing a protocol around"* (killed in Phase 30 §2, and the
  section's own later paragraph half-retracts it). Also *"a tools-only deployment path …
  does not exist yet"* under BL-08 — it has since 2026-08-19. A section that wins over
  the phases below it needs the same forward-correction discipline it introduced.
- **R2-39 [MED] Backlog items whose blocker was removed a month ago are still open,
  unmarked.** Checked on the tip: `BL-03` — `bt-trial abort` still `rm -rf`s with no
  `git ls-files` check (the fix is one line and the incident deleted tracked evidence);
  `BL-08` part 4 — `autostop` still calls `hci_alive`, i.e. **every shutdown of the
  family laptop still probes the controller**, contaminating every shutdown-terminated
  window by default; its stated prerequisite (`--tools-only`) shipped on 08-19. `BL-09`
  is done (`tools/lib/evidence-window.sh`) and not marked done. The backlog has no
  status column; it needs one, or the register's verify-command form.
- **R2-40 [LOW] "Revised order of work" item 2 — name the v5.12 commit — has no
  recorded outcome.** Twelve mentions of `BTUSB_USE_ALT1_FOR_WBS` across the docs and
  not one commit id. BRIEF §1 calls it the regression candidate; the plan calls the
  regression report the only unblocked route; the report needs the commit.

### 4.8 `docs/investigation.md` (549), `docs/firmware-hypothesis.md` (107)

- **R2-41 [NOTE]** `investigation.md` is banner-marked historical and reads as such;
  the CR-18/19/20 corrections held. Its §1 ("firmware-level lockup … not a BlueZ problem")
  and §6a (autosuspend as "the single most likely aggravating factor") are August-10
  beliefs BRIEF §5 retracts; the banner covers them. No new action.
- **R2-42 [LOW]** `firmware-hypothesis.md` still lists as step 2 "Read the same
  identifiers under Windows … the decisive one" with no outcome recorded five weeks on,
  and its supporting-facts table cites `evidence/diagnosis/root-cause-evidence.txt`
  (present) — fine. Its frame (ROM firmware vs rampatch) is now a secondary hypothesis
  next to the alt-1 finding and the file does not say so; one line at the top.

### 4.9 `docs/changes-applied.md` (401), `docs/restore-original-state.md` (188)

- **R2-43 [MED] `changes-applied.md` stops at 2026-08-13.** Since then the machine gained
  `bt-journal-backup.service`/`.timer` (writes under `/root`), `bt-capture` retention
  changes, `--tools-only` deployments (69 artefacts), a **patched `bluetoothd` under
  `/usr/local` with a systemd drop-in** (Phase 32 — the single most consequential system
  change of the project), `systemd-coredump`, and the `--tools-only` install itself. The
  file whose title is "OS modifications made during this investigation" does not
  contain the modification that replaced the Bluetooth daemon. `restore-original-state.md`
  likewise: the "path back" does not mention removing the drop-in or the patched binary.
- **R2-44 [GOOD]** The read-back-verification rule and its `REVIEWED-KEEP` block held;
  `restore-original-state.md` §2 still derives rather than enumerates (CR-36).
- **R2-45 [LOW]** `restore-original-state.md` §4 documents a user-wide assistant setting
  under `~/.claude` in a document about restoring the *machine* for a kernel-maintainer
  audience; and §7 gives a repo-delete command with an "irreversible" warning in a
  restore guide. Both belong in the operator's notes, not here.

### 4.10 `docs/pre-submission-checklist.md` (166), `docs/related-reports.md` (216)

- **R2-46 [MED] The checklist's evidence gates predate the regression route.** §2 lists
  A4, A0, Builds A/B/C/D and "confirm the SCO localisation reproduces" as the gates —
  A0 is done (plan revision), the SCO localisation is superseded by the alt-1 result at
  `n = 5`, and the plan's stated path upstream (a regression report keyed to a commit)
  has no gate here at all. §2a's readiness table has no row for the BlueZ patches. A
  checklist that is the last thing read before sending must describe the submission
  that will actually be sent.
- **R2-47 [GOOD]** §1's purge procedure (derive the list outside the tree) and its
  marker held. `related-reports.md`'s verification-status column (✅ / ⚠️ relayed / ❌
  corrected), with the one checkable entry that turned out not to say what was relayed,
  is the right way to hold prior art — and its `0x0c03 failed: -110` cross-reference to
  the project's own captures is exactly the bridge `EX-039` later built on.

### 4.11 `docs/tooling-index.md` — completeness, checked mechanically

- **R2-48 [MED]** All 28 tools it names exist. **23 tools it does not name exist**:
  `bt-trial`, `bt-trial-audit`, `bt-mode`, `bt-diagnose`, `bt-health-report.sh`,
  `bt-verify-install`, `verify-restored.sh`, `bt-actions`, `bt-context`, `bt-capdiff`,
  `bt-phase`, `bt-interval`, `bt-logvolume`, `bt-boot-stats`, `bt-boot-provenance`,
  `bt-env-history`, `bt-timeline.sh`, `bt-verify-kernel-mechanism`, and five devtools
  (`assert-test-catches`, `awk-coverage`, `py-coverage`, `repo-validate`,
  `coverage-exclude`). The file opens with "Every routine question in this project
  already has a tool … look here first". Half the tools are not here to be found, so
  the rule sends a reader to hand-type exactly the pipelines it warns against. A suite
  invariant — every `tools/*`, `devtools/*` name appears in the index — is cheap and is
  house rule 2 applied to documentation.

### 4.12 `docs/source-map.md` — the "blind" claim, verified

- **R2-33 confirmed [MED].** `tools/bt-snapshot` line 113: `bt_journal -b "$BOOT"
  --no-pager -o short-iso-precise > "$DIR/all.log"` — **the whole boot, no unit
  filter**. Since 2026-08-19, every snapshot has captured `gnome-shell`,
  `gsd-rfkill`, `wireplumber` and `pipewire` lines. The map's *seen?* column was derived
  from `-u` arguments and therefore missed the one tool that has none; rows 1–4 and
  16–17 read **blind**/**second-hand** for layers that are in every `all.log` on the
  machine. The consequence is not cosmetic: the map says "widening the capture scope
  is a prerequisite for the review", and the external brief's §5 priorities inherit it.
  The derivation should include tools whose selector is unfiltered.

## 5. `bin/` — the deployed runtime (8 files)

- **R2-49 [MED] `bt-hang-watchdog`'s header does not carry the project's own verdict on
  it.** The header still frames the tool as "a userspace recovery proxy for the missing
  handler" whose "timing … matters", and closes "Acting early is the point". The record
  since: three controlled demonstrations that its `USBDEVFS_RESET` destroys this
  controller (`EX-023`, 08-15, `EX-026`), README and BRIEF §7 saying never to arm it on
  this hardware, and it is not installed. Anyone deploying from the file's own
  description gets the August belief. The tool is fine to keep (it is the experiment);
  the header needs the four-line warning the README carries.
- **R2-50 [LOW] `bt-hang-watchdog` header facts now contradicted elsewhere:** *"Natural
  progression from HCI non-response to USB absence has NEVER been observed without an
  intervention in between (EX-018)"* — `EX-026` (a reset that was not ours, watchdog not
  installed) and `EX-034` (damage surfacing twenty minutes after a "harmless" ladder)
  complicate that; *"the one reset issued BEFORE any timeout recovered the controller"*
  — and it failed 132 s later (`EX-004`), which the sentence omits.
- **R2-51 [LOW] `bt-trace`/`bt-usbmon` name files at second resolution** and restart
  within one second on a crash; `bt-capture` fixed the same defect in itself and its
  comment names both siblings as still carrying it. With `POLL_SEC=1` a second
  `start_capture` inside one wall-clock second is reachable exactly in the persistent-
  failure case, where `btmon -w` would truncate the previous (near-empty) file — low
  cost, but the comment in `bt-capture` is a standing pointer to an unfixed defect.
- **R2-52 [LOW] `bt-trace` `disk_guard()`**: the first `free_gb` read is guarded against
  an empty result; the `while (( $(free_gb) < MIN_FREE_GB ))` loop is not — a transient
  `df` failure inside the loop is an arithmetic error on an empty operand.
- **R2-53 [GOOD]** `bt-capture`'s `_FileMonitor` seam with its loud provenance
  announcement, `prune()`'s return value ("the quiet one is the one that deletes the
  evidence"), and the second-resolution fix are model instrumentation; the `RAPID_MAX`
  seam in `bt-trace` and the `wd_early_ok` migration in `bt-health-snapshot` held;
  `bt-evidence`'s manifest counts the canonical patterns. All eleven `REVIEWED-KEEP`
  markers in `bin/` are intact. Marked again below where warranted.

## 6. `systemd/`, `etc/` (16 files)

- **R2-54 [MED] `bt-trial-auto.service` is the unit behind `BL-08`, and it is unchanged.**
  `ExecStop=bt-trial autostop` still issues an HCI command at every shutdown (§4.7,
  R2-39), and the unit sets no `TimeoutStopSec`, so the 90 s shutdown tax stands. The
  unit's comment says the classification "is by whether the controller still answers" —
  which is precisely the design the operator's decision converted into a defect.
- **R2-55 [LOW] `etc/modprobe.d/btusb-qca9377.conf`: `options btusb dyndbg=+p`
  enables every `btusb.c` site at load**, including the per-URB completion handlers
  that `bt-dyndbg`'s `NOISY_FUNCS` exists to suppress, for the ~3 s until
  `bt-dyndbg.service` runs. Bounded, and the comment argues the trade for `bluetooth.ko`
  — but not for `btusb`. Separately: the `len 27 mtu 9` lines that carry the alt-1
  finding are per-URB output from a `btusb.c` site, and nothing in `NOISY_FUNCS` or the
  modprobe file names which site produces them and why it must stay enabled. The next
  volume reduction will remove the evidence.
- **R2-56 [LOW] `bt-usbmon.service` ships `BT_USBMON_BUS=3`** — one machine's bus number
  in a unit file installed everywhere. The script's own comment explains the fallback;
  the value belongs in a drop-in written by `install.sh` from the detected bus, as
  `10-device.conf` already is for VID/PID.
- **R2-57 [NOTE]** `bt-journal-backup.service` under `/root/bt-journal-archive` with
  `Nice=19`/`IOSchedulingClass=idle`/`Persistent=true`, and its "no
  ConditionPathIsDirectory" comment, are exactly right. The `ProtectHome=yes` interaction
  the previous review asked the owner to verify (CR-49) is moot while the watchdog is not
  installed, and should be re-verified if it ever is. All six `REVIEWED-KEEP` markers in
  `etc/`/`systemd/` intact.


## 7. `install.sh`, `uninstall.sh`

- **R2-58 [HIGH] `install.sh --tools-only` silently reverted the experiment baseline on
  2026-08-19, and every trial since has run under a different treatment.** The mode guard
  is skipped for tools-only (`(( ! TOOLS_ONLY ))` on the experiment-mode `if`), and its
  refusal text promises "That deploys the files and arms nothing, so the mode stands." But
  `bt-mode experiment` implements the baseline by renaming
  `/etc/modprobe.d/btusb-qca9377.conf` and `50-bluetooth-no-autosuspend.rules` to
  `.disabled`, and `--tools-only` runs `install_file` / the udev `sed` for both — so the
  override and the power pin come back on disk, under their active names, and take effect
  at the next boot. The record shows exactly that: `evidence/trials/results.tsv` trial 5
  (opened 2026-08-19T18:38, measurement rev `9b3d750..068eebf` — the tools-only deploy
  HISTORY.md records at line 2108) ran under `autosusp=Y,power=auto,wd=off,probes=off`;
  trial 6, opened eleven minutes later on the new kernel, reads
  `autosusp=N,power=on,wd=off,probes=off`, and so do trials 8–12. HISTORY's account of the
  deploy ("watchdog still inactive and disabled, controller still at 0 timeouts") checked
  the watchdog and not the power policy; BRIEF §5 already retracts "autosuspend mitigation
  works (0/4 vs 3/4)" as "the split is chronological" without naming what made the split.
  Consequences: (a) the machine has been in an unrecorded half-mitigation for four weeks
  while its mode stamp still reads `experiment since …` — `bt-mode status` would print
  that stamp beside "modprobe conf ACTIVE", and nothing runs it; (b) bt-mode's closing
  line "Trials opened from now … are directly comparable with the A/B/C/D builds" is false
  for trials 6–12; (c) `bt-mode mitigation` will `mv` the stale `.disabled` copies back
  over the reinstalled files, which happens to be harmless, but `bt-mode experiment` will
  overwrite them, losing the originals. **No test covers `--tools-only` at all**: `grep -rn
  tools-only tests/ devtools/` matches nothing, although the `run()` comment says the gate
  order exists "so a test can assert this gate fired" and HISTORY says the mode was
  "verified under a staging root first" — by hand, once. Fix: tools-only must skip (or
  refuse on) any destination whose `.disabled` sibling exists, and the experiment-mode
  branch must not be bypassed for it; add the staged-`.disabled` regression test; on the
  machine, confirm with `ls -l /etc/modprobe.d/btusb-qca9377.conf* /etc/udev/rules.d/50-*`
  (expect an active file dated 08-19 beside an older `.disabled`), then decide which
  treatment the series continues under and record the break in `results.tsv`'s reading
  (trial-reclass cannot fix this one — the fingerprints are genuinely different).
- **R2-59 [MED] `--tools-only` writes the first-install stamp.** `installed-at` is
  "the moment the mitigation FIRST went in" for `bt-health-report`'s before/after split,
  and the stamp block runs on any `APPLY`, tools-only included. On a machine whose first
  contact is tools-only, every boot is labelled "after" a mitigation that was never armed.
  On the investigation machine the stamp predates 08-19 and was preserved, so no live
  consequence, but the write bypasses `run()` (a `>` redirect) and therefore the allowlist.
- **R2-60 [LOW] The allowlist comments disagree with the code.** `install.sh`'s `run()`
  says the allowlist is "install, rm, rmdir — and nothing else"; the case arm is
  `install|rm|rmdir|mkdir`. `uninstall.sh`'s says "rm and rmdir"; its arm is the same
  four. The drop-in, udev-rule and stamp writes are bare `mkdir -p` + redirection outside
  `run()`, so "deny by default" gates commands only; that is documented for staging but
  the tools-only paragraph ("nothing gets armed") reads as if it covered writes too.
- **R2-61 [LOW]** `--help` prints lines 2–15, which ends on the "Different controller:"
  heading and omits its one example line (16). The preflight still says "Recovery will
  still run" of a watchdog whose reset path the fix proposal is now trying to get out of
  the kernel (R2-29), and `[7/7] activate` still arms it by default under `--apply` —
  README's `--tools-only` warning is the only thing standing between a new reader and
  that path.
- **R2-62 [NOTE]** Not installed by `install.sh` and absent from `uninstall.sh`'s list:
  `bt-crash`, `bt-fault-window`, `bt-usbstate`, `bt-guards`, `verify-restored.sh`, and
  `tools/lib/coredump.sh`. The suite derives the pair's consistency from `install.sh`, so
  the pair is consistent — the question is whether the four tools are meant to exist only
  in a checkout; taken up per tool in §8.
- **R2-63 [GOOD]** The three-guard block (mode / failed-this-boot / open-trial) held; the
  counted `journalctl | grep -cE` at the btusb-reload site with its explanation is the
  right shape; `uninstall.sh`'s `FAILED` accumulator, the loud `rmdir` leftover listing,
  and the `.disabled` awareness in `verify-restored.sh` are all as the previous review
  asked. `REVIEWED-KEEP 2026-08-15T1752Z 2.5` intact.

## 8. `tools/` (34 tools, 14 lib files — 9 047 lines)

### 8.1 `bt-trial`, `bt-snapshot`, `bt-archive`, `bt-retention`, `bt-backup-journal`, `bt-trial-audit`

- **R2-64 [HIGH] `bt-trial abort` is still `rm -rf "$dir"; rm -f "$CUR"` with no
  "has anything been recorded?" check — BL-03 at the code site** (R2-39 for the register
  status). A trial with steps, marks and a fingerprint is deleted, not closed as
  `aborted`, although `trial_result=aborted` is in `trial-summary.awk`'s accepted domain
  and no writer ever produces it. Fix: `abort` should close the row with
  `trial_result=aborted` and move the state dir to an `aborted/` sidecar; deletion is for
  a dir with nothing but `start=`.
- **R2-65 [HIGH] `bt-trial autostop` still classifies by probing a live controller**
  (`if hci_alive; then exec "$0" ok; else exec "$0" hang`), which is BL-08 part 4 and the
  90 s shutdown tax in R2-54. The closer already computes `timeouts` from the journal for
  the row; the shutdown verdict should come from the same count, with the probe gone.
  While it stays, the `Finished`-only probe filter means a shutdown that hangs the probe
  is invisible to the audit.
- **R2-66 [MED] `bt-snapshot` hardcodes the USB port**: `[[ -e "$SYSFS/3-3" ]] &&
  PRESENT="yes"` and the `usb 3-3` grep for the USB-layer excerpt. Every other tool
  resolves the radio by VID/PID (`bt-mode radio_dir`, install preflight). On any other
  port — or this laptop after a dock — the snapshot reports the controller absent and an
  empty USB section, during the one minute it is being reached for.
- **R2-67 [MED] `bt-archive --check` and the failing suite test (R2-01).** The tool
  probes `zstd`, `xz`, `gzip` in order and names the archive by whichever it found; the
  test at `run-tests:7410` asserts `.zst`. The tool is right; the expectation carries the
  investigation machine's toolchain. The test should derive the suffix from the same probe
  (or the tool should expose it — `bt-archive --compressor`). Separately, an `AMBIGUOUS`
  row (two archives for one boot) is printed and then `continue`d without incrementing
  any counter, so the summary line "N complete, N SHORT, N not archived" can read clean
  while a boot is unverified — the very case the comment above it says must not pass
  quietly. Count it, and say so in the summary. (The exit-0-always design is deliberate and
  documented; not disputed.)
- **R2-68 [GOOD, retracting a draft finding]** `bt-snapshot`'s EX-032 shape test compares
  two line numbers within one journal cut rather than two parsed timestamps. On first read
  that looked fragile; the comment at line 309 explains that the cut is already in journal
  order and the comparison answers "since the last crash" without a date parser. Correct.
- **R2-69 [GOOD]** `bt-backup-journal` skipping boot 0 unless `--include-current`, and
  `bt-archive`'s tee-plus-FIFO read-back count before filing ("15 of 15") are the right
  discipline for evidence that has already rotated away once. `bt-retention`'s
  declared-versus-scanned evidence window, its `date -f -` parse-count check, and
  `bt-trial-audit`'s positive control (a fixture the audit must flag, run before the real
  read) are model tests-of-the-tool. `bt-snapshot`'s unfiltered `all.log` is what makes
  the source-map claim in R2-33 wrong, and is the right choice. `trial-reclass.awk` is a
  clean read-time correction that announces itself and refuses to launder real drift.

### 8.2 `bt-actions`, `bt-exhibit`, `bt-capdiff`, `bt-health-report.sh`, `sanitize-logs.sh`, `bt-postmortem`, `bt-mode`

- **R2-70 [MED] `sanitize-logs.sh` redacts Bluetooth SIG-assigned service UUIDs as if
  they identified the machine.** The UUID pass has no allowlist, so every
  `xxxxxxxx-0000-1000-8000-00805f9b34fb` — the public base-UUID form under which
  A2DP, HFP, AVRCP and OPP are named — becomes `<UUID-NN>`. In the 2026-09-13 session's
  `bluetoothd.log` four placeholders stand in for 144 profile references
  (`src/profile.c:ext_adapter_probe() ".../<UUID-01>" probed`), so which profile was
  probed, connected or torn down is unreadable in exactly the log that is supposed to show
  the HFP-versus-A2DP sequence behind the SCO finding. `bt-exhibit` inherits it: a
  `--cmd` that greps for a service UUID is refused as "an address appears in the
  extraction method". Fix: leave UUIDs whose last 96 bits are the SIG base untouched (and
  say so in the header's table); nothing about them is identifying.
- **R2-71 [MED] `bt-capdiff --since/--until` replace the overlap bounds instead of
  intersecting them.** The header promises "Compares only the overlapping time range …
  outside it a difference means 'not captured', not 'disagreement'". With `--since` set
  earlier than the later path's first record, `lo` is simply overwritten, and every record
  the earlier path captured before the other attached is listed as "present only in …".
  `lo=max(lo, SINCE)`, `hi=min(hi, UNTIL)`.
- **R2-72 [MED] `bt-postmortem` narrates a refuted hypothesis as the load-bearing
  question.** Its closing analysis is whether "the early signal actually arrived early"
  for "the 'cmd_timeout is too late' hypothesis", and its advice line is "Check the
  threshold/cooldown". `bt-mode`'s own header records that the early precursors were
  refuted as causal markers, and the central finding (§2) is a transport alt-setting
  event the tool does not look for. Read today, the verdict block explains a hang in
  terms the project has abandoned, with no marker saying so. Minimum: a one-line
  historical note in the output; better: an "alt setting 1 seen before first timeout?"
  row in the EVENT table, from the same journal it already reads.
- **R2-73 [MED] `bt-health-report.sh` has no mode awareness and grades the reverted
  baseline as correct.** Section 1 prints "expected after a cold power-off:
  autosuspend=N, power/control=on" unconditionally. On the investigation machine today
  (R2-58) that is the state the tools-only deploy silently restored, so the one report an
  operator would run to check the treatment says it is as expected while the mode stamp
  says `experiment`. Read the stamp `bt-mode` writes and print the expectation for the
  recorded mode, or print the stamp beside the state. Also: the `installed-at` path is the
  only input in the file not behind a seam (`BASELINE` and both sysfs roots are), so the
  before/after labelling cannot be driven by a test except through `BT_CHANGE_TIME`; the
  header's "35 boots retained" is a constant from another month.
- **R2-74 [LOW]** `bt-actions` documents four classes (USER/STACK/CTRL/WDOG) in its header
  and legend line but emits `PROF` and `PLAY` rows as well; its CTRL classifier has no
  rule for the isoc alt-setting change or the `len 27 mtu 9` frames, so the reconstructed
  timeline cannot show the mechanism the investigation now centres on. `bt-capdiff
  --help` prints lines 2–28 and its `Usage:` block begins at 36. `bt-exhibit` writes
  `13d3:3503 QCA9377 (ROME)` into every provenance table regardless of `BT_VID`/`BT_PID`,
  and its checkout search includes `/root/exp/qca9377-bt-hang` — the same
  one-machine-constant class as R2-56/R2-66.
- **R2-75 [GOOD]** `bt-capdiff`'s consumed one-to-one matcher, the tolerance-widened
  window with its explanation, the empty-overlap refusal, and the "DO NOT READ THIS AS"
  block are exactly the epistemic hygiene the tool exists for. `sanitize-logs.sh`'s
  two-direction awk gate and build-then-rename are intact and correctly marked
  `REVIEWED-KEEP`. `bt-exhibit`'s three refusals (127/126, missing sanitiser, address in
  the command) held. `bt-mode`'s single-call-site dry-run design and `.disabled`
  reversibility are right — R2-58 is `install.sh` failing to respect that convention, not
  a `bt-mode` defect. `bt-postmortem`'s incident clustering and live-state-outranks-log
  verdict are sound.
