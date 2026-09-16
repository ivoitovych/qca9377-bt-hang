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

