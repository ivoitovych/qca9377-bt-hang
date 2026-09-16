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

