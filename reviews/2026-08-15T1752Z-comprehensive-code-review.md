# Comprehensive code review — 2026-08-15T1752Z

Full-repository review, every file, in priority order. Findings are appended
per item immediately after each item is reviewed, so nothing depends on
reviewer memory. The overall summary is written last, after all items.

Severity scale used throughout:

- **[HIGH]** — wrong behaviour, wrong claim, or data loss possible on the
  supported path
- **[MED]** — a real defect or contradiction, but bounded in effect or on an
  unlikely path
- **[LOW]** — cosmetic, stylistic, drift risk, or a hardening suggestion
- **[NOTE]** — an observation, not a defect; recorded so it is not re-derived
  later
- **[GOOD]** — a practice worth keeping that a future edit might casually
  destroy

## Plan and priority order

1. **Foundation documents** — `README.md`, `HISTORY.md`, `docs/issues.md`,
   `docs/investigation.md`, remaining `docs/*.md`, `LICENSE`
2. **Deployed runtime** — `bin/*`, `systemd/*`, `etc/**`, `install.sh`,
   `uninstall.sh`, `tools/verify-restored.sh` (what runs as root on a user's
   machine gets the strictest reading)
3. **Diagnostic tools** — `tools/*`, `tools/lib/*` (the analysis layer;
   errors here silently corrupt conclusions)
4. **Test harness** — `tests/run-tests`, fixtures, journal corpus
5. **Contributor tooling and CI** — `devtools/*`, `.github/workflows/checks.yml`
6. **Prior reviews** — `reviews/*` (meta-review: are past findings closed?)
7. **Evidence corpus** — `evidence/` READMEs, exhibits, spot-checks of
   sessions/trials for internal consistency and sanitisation
8. **Cross-cutting checks and overall summary**

Method: read every file in full (evidence logs and fixtures are checked for
structure, sanitisation and consistency rather than line-by-line prose
review); verify documentation claims against the code they describe; run the
test suite and the repo's own validators; commit the review file after each
major section.

---

## 1. Foundation documents

### 1.1 `README.md`

The front page is unusually honest for a bug-investigation repo: refuted
hypotheses are kept and labelled as refuted, claims are graded (established /
unresolved / never tested), and censoring is named as censoring. That
discipline is the repository's core asset. The findings below are almost all
places where the prose has drifted behind the code — the exact failure mode
`tests/run-tests`' own header warns about.

- **[MED] Test-suite figures are stale.** Lines 564–569 say "96 invariants,
  ~2 s" and "Each of the 96 invariants…". The suite as shipped reports
  **"all 386 invariants hold"** and takes ~16 s (measured on this checkout).
  A fourfold undercount on the front page undersells the repo's strongest
  feature and — worse — signals that numbers here are not maintained. The
  coverage figure on line 571 ("18.3%, up from 13.1%", "38 of 44 scripts")
  needs re-measuring with `devtools/coverage` at the same time (verified
  below in this review; see §1.1-addendum).

- **[MED] The `BT_EARLY` trigger-pattern ratios are internally inconsistent
  and unsourced.** Lines 297–299 define the notation as "appearances overall
  vs. appearances in boots that hung", then give `avdtp_close failed` **4/3**
  and exclude `Device or resource busy` at **3/9**. Under the stated reading,
  3/9 is impossible (a signal cannot appear in more hung boots than it
  appears at all); under the reversed reading, 4/3 is impossible. One of the
  two is transposed. Additionally these ratios appear nowhere else in the
  repository — no exhibit, no doc, no script comment derives them — which is
  out of step with the house rule that numbers trace to an extraction
  command. Either cite the derivation (an exhibit or a `bt-boot-stats`
  transcript) or delete the table.

- **[LOW] Clone URL inconsistency.** The quick-check clones
  `github.com/ivoitovych/qca9377-bt-hang` (line 36); the Install section
  clones `github.com/<you>/qca9377-bt-hang` (line 192) with no explanation of
  the placeholder. Pick one form; if `<you>` is meant to suggest forking
  before installing, say so.

- **[LOW] Repository-layout block partially duplicates itself.** The tree at
  lines 421–446 lists `tests/` twice (once with children, once at the bottom
  as "invariants, each anchored to a real shipped defect") and appends
  `tools/lib/`, `evidence/exhibits/`, `evidence/trials/` after the closing
  entries rather than nesting them where `tools/` and `evidence/` already
  appear. Reads like two generations of the tree merged. Also `docs/` lists
  five files but the directory holds ten — `issues.md`,
  `firmware-hypothesis.md`, `investigation-plan.md`,
  `pre-submission-checklist.md`, `related-reports.md` are absent from the
  tree while being referenced elsewhere in the README itself.

- **[NOTE] Exit-code contract for `bt-diagnose` (0/1/2, line 44–45) is
  spot-checked as real** — the script exits 2 on no-controller / no-journal /
  missing lib paths; 0/1 verified in §3 when the tool is reviewed in full.

- **[GOOD] The "Publishing logs" section** explains *why* the sanitiser
  exists (BSSID → geolocation) rather than just prescribing it, and the
  in-place-safe behaviour is documented. Keep.

- **[GOOD] The candidate-fix section refuses its own temptation** — the
  "+0 s never tested" table is exactly the right shape, and the warning that
  `BTUSB_QCA_ROME` can brick setup if the module is not a true ROME variant
  is the kind of caveat most fix-proposals omit.

#### §1.1 addendum — coverage claim could not be re-measured

Attempting to verify README's "18.3%" coverage figure: `devtools/coverage`
**exits 2 on this HEAD** because its exclusion list is stale — it reports
three lines as "EXCLUDED but executed by the suite" (`tests/run-tests:1208`,
`tools/bt-trial:613`, `tools/bt-trial:615`) and refuses to print a total.
Filed as finding §5.x under devtools; consequence here is that the README
coverage number is both stale *and* currently unre-measurable with the
repo's own tool.

### 1.2 `HISTORY.md`

Read in full (1763 lines). As a document class this is exceptional: wrong
turns are preserved, corrections are dated, and the "Lessons added" blocks
distil each failure into a rule. The findings are about internal
consistency, not about the narrative.

- **[MED] "Current state" section is five days stale and contradicts the
  repository's present position.** The section titled "Current state"
  (lines 278–294) sits between Phase 8 and Phase 9 and freezes the world as
  of 2026-08-10 07:40: "Root cause identified ✅ confirmed", "nothing has
  hung since the power-off". Both were overturned by later phases (Phase 16
  demoted the mechanism claim; five hangs followed). A reader who lands
  here by search — and "current state" is exactly what one searches for —
  gets the refuted 2026-08-10 world presented in the present tense with no
  banner. Retitle it ("State as of end of Phase 8, 2026-08-10 — superseded")
  or add the same ⚠️-correction header used elsewhere in the file.

- **[LOW] Early phases carry later-refuted claims without forward pointers,
  inconsistently with the file's own convention.** The document *does*
  annotate some superseded passages in place (Phase 2's modinfo caveat,
  Phase 18's "⚠️ This paragraph originally overreached"). But Phase 1's
  foundational blockquote ("stage 1 … ~6 hours before decaying", "A warm
  reboot does not drop the M.2 power rail") and Phase 2/3's mechanism
  description (`btusb_qca_cmd_timeout()` after "5 consecutive" timeouts;
  watchdog threshold "3 rather than the kernel's 5"; `USBDEVFS_RESET` "the
  same ioctl") are all later corrected — Phases 9, 16 and 17 respectively —
  yet carry no marker. Chronology is a defensible design, but the file
  already mixes in-place corrections with chronological ones; a one-line
  "(superseded — see Phase 16)" on the known-wrong statements would cost
  nothing and match README's treatment of refuted content.

- **[LOW] Dangling commit reference.** Phase 5 says the 14 review findings
  were "all fixed in `4c4047d`" — that hash does not exist in this
  repository's history (checked with `git cat-file`; `fd24995` and
  `1990a45`, cited in Phases 22 and 23, do exist). Presumably lost in a
  history rewrite during publication. Either update the hash or drop it.

- **[NOTE] The README `BT_EARLY` ratio inconsistency (§1.1) is resolvable
  from this file.** Phase 12 uses the form "`cancel_request() Abort` 4/4,
  `Suspend` 2/2, `avdtp_connect_cb` 5/5 occurrences **fell in boots that
  hung**" — i.e. the notation is hung-boot-appearances *of* total, which
  makes README's "3/9 too noisy" coherent (3 of 9 in hung boots) and makes
  README's stated definition ("appearances overall vs. appearances in boots
  that hung") backwards, and its `avdtp_close failed` **4/3** the
  transposed datum. The fix is to correct README's definition order and the
  4/3 figure against whatever produced Phase 12's numbers.

- **[NOTE] Retained-boot counts drift across phases (34 → 18 → 23 → 22).**
  These are all correct at their respective times (journald retention rolls,
  and Phase 18a documents the deletion), but nothing in the text of Phases
  24–25 reminds the reader why the denominator changed since Phase 18a.
  Fine as is; flagged only so nobody "fixes" the numbers into agreement.

- **[GOOD] The lessons are mechanised, not just recorded.** Repeatedly the
  file notes that writing a lesson down did not prevent recurrence, and the
  fix was moving the rule into a tool or test (the 2×2 in `bt-trial`, the
  awk-`-f` grep in `run-tests`, provenance from unit names). That loop —
  lesson → invariant — is the repository's most transferable practice.

### 1.3 `docs/issues.md`

The register does what it promises: six defects, separately evidenced,
separately reportable, with the evidence model stated up front. Checked the
cross-tab numbers against `HISTORY.md` Phase 18 (16/8/2/8 — consistent), the
"fifteen windows" count against EX-018 + EX-021 (14 + 1 — consistent), and
the BT1-CURRENT block against the README's marker-delimited copy
(byte-identical).

- **[LOW] BT-4 contains two generations of text, imperfectly merged.**
  "Still needed before filing: a backtrace … and a check against current
  BlueZ" appears at line ~351 and again at line ~397 ("Not yet reported. The
  minimal reproducer now exists (below); a backtrace … still outstanding")
  — and that second passage says "(below)" although the reproducer is
  *above* it. The trailing paragraphs from "btmon -w aborts with a core
  dump…" read as the original section body left in place after the newer
  material was prepended. Fold the tail into the newer structure.

- **[NOTE] The "five levels" table is actually six rows (0–5) with level 0
  appended after 5.** The text explains why (added last, sits beneath), so
  this is deliberate; flagged only because the heading "five levels" now
  undercounts its own table — same species as the "96 invariants" drift,
  cheap to fix by renaming the section.

- **[GOOD] The BT-3 section argues both directions.** "Absence is
  suggestive, not proof" plus the deliberate-omission alternative, and the
  sign-of-effect honesty ("not a claim that the patch is harmful") — this
  is the discipline that makes the register credible.

- **[GOOD] The 9/5 reset-provenance caveat (lines ~166–172)** — the
  register refuses to cite its own headline zero ("no uncensored USB loss")
  as mechanically re-verified until the reclassification is re-captured.
  Exactly right.

### 1.4 `docs/investigation.md`

Explicitly a historical chronology with a do-not-quote banner and in-place
corrections (§10's strikethrough treatment of the `cmd_timeout` error is the
right pattern). Findings:

- **[LOW] Timeout counts for boot 0 disagree internally: 19 vs 22.** §4 says
  "Nineteen `tx timeout` lines this boot" and §7's table has boot 0 = 19; §9's
  table and §10's causal chain say 22. The published baseline log
  (`evidence/baseline/kernel-boot0.sanitized.log`) contains 22 `tx timeout`
  lines. The 19 was presumably an earlier snapshot of a live boot, but nothing
  says so — a one-line note ("counts grew as the boot continued; final count
  22") would stop a careful reader treating it as an error. Note the 22
  decomposes as 21 command timeouts + 1 link timeout (see §1.5 below).
- **[LOW] §13 says "35 boots retained" where every other figure in the repo
  says 34.** Likely 35 = 34 retained + current; worth normalising.
- **[LOW] Stray doubled horizontal rule** between §7 and §8 (lines 200–202).
- **[NOTE] §8's "no software recovery is possible / warm reboot does not drop
  the M.2 rail" is stated with a ✅** and is one of the places the
  warm-reboot inference appears as fact. `docs/issues.md` enumerates the
  locations of that untested assumption ("step 0, `bt-mode`, `install.sh`,
  `EX-005`, `related-reports.md`") but does **not** list this file — the
  enumeration itself is stale. The file-level banner covers it generically,
  so this is about completing the issues.md list, not editing history.
- **[GOOD] §13's synthetic-line disclosure** (3 injected `tx timeout` lines,
  with time and reason) is exactly the level of honesty attachments need.

### 1.5 `docs/bug-report.md`

Strong report; the do-not-submit banner, methodological caveat, and the
"what has and has not been tested" table are all in good shape. Findings:

- **[MED] The "Confidence" note contradicts the report's own count.** Line
  ~114: "Finding 2 rests on **two** failed late resets (+20 s and +11 s) and
  one successful early reset … Full logs for all **three** are attached."
  The same document says five failed late resets ("+11 s, +16 s, +20 s,
  +20 s and +33 s", line ~92; "five for five", line ~183). The note is a
  fossil from when n=3. In a document aimed at maintainers, an internal
  contradiction in the headline evidence count is the first thing a skeptical
  reader will find. Update the note (and its attachment count).
- **[LOW] The attachments section quotes the conflated timeout count.** "The
  22 `tx timeout` events they contain are all genuine" — per the repo's own
  Level-0 lesson (`EX-015`), the bare pattern conflates command and link
  timeouts; the published log holds 21 command + 1 link. Given this project
  built a test to stop exactly this conflation, its flagship report should
  say "21 command timeouts and 1 link timeout".
- **[NOTE] §"What provokes it" device list names three consumer devices** —
  deliberate, presumably, since they identify hardware not people; fine
  under the sanitisation policy, just confirming it was considered.
- **[GOOD] The Windows comparison is framed exactly right** ("Linux drives
  this controller into a state that Windows does not") — neither
  hardware-blaming nor Linux-blaming, and the report says which follows from
  which.

### 1.6 `docs/fix-proposal.md`

- **[MED] Stale small-n fossil, same as bug-report.md.** §3b ends "⚠️ Small
  n. Two failed late resets, one successful early reset, one incident with
  no early signal. Attach all three sessions" — while §3a in the same file
  says five late resets (+11/+16/+20/+20/+33 s). Two documents now carry the
  same fossilised count (see §1.5); fix both in one pass, and grep the tree
  for "two failed late resets" while at it — the Phase-17 lesson ("apply
  corrections by grepping the whole tree") applies to its own artefacts.
- **[LOW] Section numbering is out of order:** §1, §2, §3, §3a, §3b, then
  **§5a**, then §4, §5, §6, §7, §8. A reader following "see §5a" scrolls past
  §4 to find it *before* §4. Renumber or reorder.
- **[GOOD] §3's six-behaviour enumeration with verbatim source**, the WBS
  separation, and §5a's decision-rules table (benefit and harm as separate
  axes) are the strongest technical writing in the repo.
- **[GOOD] The suggested commit message** is properly conservative —
  "aggregate journal counts are consistent with these facts but do not
  establish them by themselves" is a sentence most submitters would not write.

### 1.7 `docs/firmware-hypothesis.md`

- **[MED] Carries the refuted "two things" model of `BTUSB_QCA_ROME`.** "What
  we already knew and mis-filed" states the flag "makes `btusb_probe()`
  install **two** things". Phase 17 established it installs six, and
  `fix-proposal.md` §3/§5a was corrected accordingly — this file was not.
  This is precisely the residue class HISTORY's own lesson describes ("a
  document is not corrected until its residues are"), in the very document
  `bug-report.md`'s do-not-submit banner sends readers to. The hypothesis
  itself only needs items 1 and 2, so the fix is one sentence ("two of the
  six things it installs — see fix-proposal §3").
- **[LOW] "Consequence for the bug report"** still phrases the current
  report as "this device gets no `cmd_timeout` handler" — the pre-Phase-16
  mechanism vocabulary. Cosmetic, but it is the one place a reader will
  compare before/after framings.

### 1.8 `docs/investigation-plan.md`

No defects found. The A1 downgrade note, the A4 gate, and the C1 ladder all
agree with fix-proposal §5a. The Backlog items (BL-01, BL-02) are unusually
well-formed: each states why it matters, what limitation travels with the
data, and when it must be done by. **[GOOD]** overall.

### 1.9 `docs/changes-applied.md`

- **[LOW] §0 "Summary of blast radius" reads as document-wide but is
  2026-08-10-scoped.** "New files added: ✅ 9 (+1)" was true on day one; the
  dated addenda below add roughly a dozen more scripts, four units, two
  drop-ins and a udev rule. The sections are individually complete, but the
  table a reader trusts first now under-reports the footprint several-fold.
  Add "as of 2026-08-10 — see dated sections below for the current total" or
  recompute the total from install.sh.
- **[GOOD] The "documented change that was never in effect" section**
  (BT_TRACE_KEEP) records the verification command alongside the fix — the
  rule it derives is applied in the same paragraph that states it.

### 1.10 `docs/restore-original-state.md`

- **[MED] §2's enumeration of what `uninstall.sh` removes is a stale
  hand-written list.** It names 11 commands; `install.sh` currently installs
  ~35 commands plus 8 `lib/` files (verified by deriving the set from
  `install.sh` itself). The sentence opens correctly ("Removes everything
  `install.sh` adds") — but then freezes an early manifest. This repository
  has documented four times that "the enumeration is the bug"
  (`HISTORY.md` Phase 25 postscript); the fix that matches house style is to
  *drop* the list and point at `bt-verify-install` / `install.sh` as the
  derived source of truth, not to update it by hand a fifth time.
- **[NOTE] §4 and two sibling passages disclose the development tooling by
  name** (`restore-original-state.md` §4, `HISTORY.md` Phase 4,
  `pre-submission-checklist.md` §5). `devtools/repo-scan`'s attribution
  check only blocks trailer forms (`co-authored-by:`/`generated with` plus
  the vendor name), so these pass the scan while still disclosing. If the
  policy is "no attribution trailers", the tree is consistent; if the intent
  is broader non-disclosure, these three are the residue. Owner's decision —
  flagged, not judged.

### 1.11 `docs/pre-submission-checklist.md` and `docs/related-reports.md`

No defects found in either. The checklist's §1 purge procedure derives the
address list from history rather than spelling it (after documenting the
first version's self-re-leak — a valuable warning), §2b's controlled-
environment table is the right prerequisite discipline, and related-reports
consistently holds the phenotype/cause line. **[GOOD]**.

### 1.12 `LICENSE`

GPL-2.0 text as stated in README. Not read line-by-line; length and header
match the canonical text.

## 2. Deployed runtime — `bin/`, `systemd/`, `etc/`, install/uninstall

Read in full: `bt-hang-watchdog`, `bt-health-snapshot`, `bt-capture`,
`bt-trace`, `bt-usbmon`, `bt-dyndbg`, `bt-mark`, `bt-evidence`, all nine
unit files, all five `etc/` configs, `install.sh`, `uninstall.sh`,
`tools/verify-restored.sh`. Overall: this layer is in notably good shape —
the seams (`BT_JOURNAL_FIXTURE`, `BT_SYSFS_USB`, `BT_DYNDBG_CTL`) are
principled, the load-bearing comments carry their measured justification,
and every past defect class I could think to probe (grep -c/-q pipefail,
chmod races, ring-buffer rotation, `awk -f` inlining) already has either a
fix or a test. Findings:

### 2.1 `bin/bt-hang-watchdog`

- **[LOW] `python3` is a hard dependency of the primary reset path but the
  watchdog never checks for it.** The capability probe covers
  `hciconfig`/`btmgmt` and logs a warning when absent; `usbfs_reset()`
  needs `python3` and, if it is missing, every intervention silently takes
  the "USBDEVFS_RESET failed" branch and escalates to unbind/bind — a
  *different treatment* than documented, with no startup warning.
  `install.sh` preflights python3, so the gap only bites hand-deployed
  copies — but the watchdog's own banner is the right place for the check,
  same as PROBE.
- **[LOW] The give-up message differs between paths.** The late path logs
  "Giving up… / A cold power-off is required. Watchdog is now idle until
  reboot."; the early path logs only the first line. Any log-scraping
  tool keying on the second line sees only late-path give-ups.
- **[GOOD]** The `O_CREAT`-less `os.open` note in `usbfs_reset` (avoiding a
  bogus devtmpfs file during the exact race it protects against), the
  wrong-radio guard in `hci_for_dev()`, and the loud
  reader-died exit path are all careful work.

### 2.2 `bin/bt-health-snapshot`

- **[MED] An early-intervention success is invisible in the metrics.**
  `wd_int` counts both "intervening" and "EARLY intervention" (the
  Phase-22 fix), and `wd_fail` counts both paths' failures — but `wd_rec`
  counts only "RECOVERED", which the early path deliberately never logs
  (it says "CONTROLLER RESPONDS AFTER EARLY INTERVENTION"). So an early
  intervention that left the controller answering produces
  `wd_interventions=1, wd_recovered=0, wd_failed=0` — indistinguishable
  from "attempted, unverifiable". The epistemic caution (not calling a
  censored outcome a recovery) is right, but the schema then needs a
  fourth counter (e.g. `wd_early_responds`) or the distinction is lost in
  the TSV that `bt-health-report` reads. This is the same species as the
  Phase-10 `wd_interventions=0 beside wd_recovered=1` bug, in mirror image.
  The same asymmetry exists in `bt-evidence`'s MANIFEST (`wd_recovered`
  line) — fix both.
- **[NOTE] The 15-minute timer pays an unbounded `journalctl -k -b 0` scan
  twice per tick** (timeouts + unexpected-event counts). On a long boot
  with dyndbg on, that is minutes of journal reading per snapshot. The
  ed82166 commit bounded exactly this pattern in `bt-trial`'s close path;
  the snapshot's counters genuinely need the whole boot, so this is a
  cost to know about, not a bug — but worth measuring once.

### 2.3 Capture stack (`bt-capture`, `bt-trace`, `bt-usbmon`, `bt-dyndbg`)

- **[GOOD] `bt-capture`'s btsnoop writer is correct** against the BlueZ
  monitor format (checked: magic/version/type 2001, `flags = index<<16 |
  opcode`, the 0x00E03AB44A676000 timestamp offset, record field order),
  and the clock-semantics warning at the timestamp write site is exactly
  where it belongs.
- **[GOOD] `bt-usbmon`'s ring-vs-rotate comment** (tcpdump `-C -W 1` is a
  ring, not an exit) documents a real trap, and the supervise-and-rotate
  design matches `bt-trace`'s. The never-delete-the-live-file rule is
  enforced in both floor loops.
- **[LOW] `bt-trace`'s script default `MIN_FREE_GB=10` disagrees with the
  value its unit sets (15).** (`bt-usbmon` is consistent: script default
  15, unit silent.) Harmless while the unit always sets it — but that is
  precisely the `BT_TRACE_KEEP=30` pattern the repo documented: a script
  default that differs from the value in effect misleads the next person
  who runs the script by hand. Align the default with the unit.
- **[NOTE] `bt-trace`'s gap log can grow one line per second** if btmon
  respawn-fails persistently (e.g. Bluetooth support absent); bounded in
  practice, unbounded in principle. A repeated-failure backoff would cap it.

### 2.4 `etc/` and unit files

- **[GOOD]** The modprobe dyndbg-at-module-load rationale, the udev
  `PRODUCT=%x/%x/%x` leading-zero comment (with `install.sh` actually
  substituting the stripped form), the journald drop-in's
  "DO NOT ADD MaxRetentionSec" warning, and the split snapshot units for
  probe provenance are each small pieces of unusually careful engineering.
- **[NOTE] `bt-hang-watchdog.service` hardening is modest** (no
  `ProtectSystem=`, no `PrivateTmp=`). `NoNewPrivileges` is off the table
  (notify uses `sudo -u`), and sysfs/usbfs writes need root, but
  `ProtectSystem=full` + `PrivateTmp=yes` would hold. Low value, low cost.

### 2.5 `install.sh`

- **[GOOD]** The three-guard structure (experiment mode, failed-this-boot,
  open-trial), the counted-not-`grep -q` discipline with its pipefail
  explanation at the exact site, the write-once install stamp, and
  derived-vs-hand-written device substitution in generated udev rules are
  all right. The FAILED accumulator + "INSTALL FAILED" exit honours the
  Phase-5 fix.
- **[NOTE] Guard override env var naming is subtle but sound**: the tools
  use `BT_STATE`; `tests/run-tests`' refuse-while-trial-open guard reads
  `BT_TRIAL_STATE_DIR` *deliberately*, so a test's sandbox override cannot
  defeat the suite-level guard. Recorded here so nobody "unifies" them.

### 2.6 `uninstall.sh`

- **[MED] No failure tracking — "UNINSTALL COMPLETE" prints even if steps
  failed.** `run()` reports errors to the eye but nothing accumulates
  them; a failed `systemctl disable` or an unremovable file still ends in
  the success banner. `install.sh` had exactly this defect and got the
  `FAILED` accumulator in the Phase-5 review; the uninstaller never did.
  Symmetric fix: track failures, exit non-zero, and point at
  `verify-restored.sh` (which does catch leftovers — the safety net
  exists, but the tool should still tell the truth about itself).
- **[NOTE] The FILES/UNITS lists are hand-written**, the repo's
  known-recidivist defect class — but here it is acceptable because
  `tests/run-tests` asserts the uninstall set against `install.sh` (the
  "Guard derived from install.sh" commit) and `verify-restored.sh`
  independently derives its list. Three overlapping checks; fine.

### 2.7 `bin/bt-evidence` and `tools/verify-restored.sh`

- **[GOOD] `verify-restored.sh` derives both its file list and unit list
  from `install.sh`**, refuses a false all-clear when the derivation looks
  broken (<10 artifacts), and knows about `bt-mode`'s `.disabled` moved-
  aside names. The `(( x++ ))` exit-status comment is a correct and
  little-known bash trap, worth the seven lines.
- **[LOW] `bt-evidence stop` records `wd_recovered` with the same early-
  success blind spot as §2.2** (counted there; noted here for the fix list).

## 3. Diagnostic tools — `tools/`, `tools/lib/`

Read in full: all 27 scripts and all 8 library files. Verified the Hinnant
`days_from_civil` algorithm in `timestamp.awk` against the reference
formulation; verified `bt-capture`'s btsnoop encoding against the BlueZ
monitor format; traced the consumptive two-pointer matcher in
`capdiff-match.awk`; checked the awk header-name resolution and refusal
paths in both trial report programs. The layer is strong. Findings, most
significant first:

### 3.1 Cross-cutting

- **[MED] `bt-trial` leaks its kernel-journal temp file on every `hang`/`ok`
  close.** `KJ=$(mktemp)` at line 361 receives the boot's entire kernel
  journal since trial start; `$WJ`, `$CUR` and the `status` verb's `$W` are
  all removed, but `$KJ` never is (verified: no `rm` references it). On the
  investigation machine `/tmp` is tmpfs, and a long dyndbg boot's kernel
  journal runs to hundreds of MB — RAM held until reboot, one file per
  mid-boot close. Add it to a trap alongside the others.

- **[MED] The civil-date arithmetic exists in four copies, three of them
  inline.** `tools/lib/timestamp.awk` opens with "one civil-date
  implementation, shared by every analysis tool" — but `bt-actions`
  (`days()`/`tosec()`), `bt-sco --window` (`days()`/`ts()`), and
  `bt-boot-stats` (`days()`/`s()`) each embed a private copy inside an
  inline awk string. All three copies are currently correct (checked
  against the lib), but this is the precise divergence risk the shared file
  was created to end — and inline strings are additionally the
  cannot-be-syntax-checked form the repo moved its report programs out of.
  `bt-capdiff` shows the fix: write the program to a temp file (or lib) and
  load `-f timestamp.awk -f <prog>`.

- **[MED] Probe counts derived from `journalctl -u <unit> | grep -c
  "<Description text>"` appear to double-count.** `bt-trial`'s `probes`
  column and `bt-env-history`'s `PROBES` column count matches of "Snapshot
  Bluetooth health metrics" in the units' journals — but `journalctl -u`
  includes systemd's own "Starting <desc>..." *and* "Finished <desc>."
  lines for a oneshot, i.e. two matches per invocation (the snapshot script
  itself prints nothing). The columns are documented as lower bounds on
  intervention exposure; a 2× overcount is the opposite direction. Verify
  once on the machine (`journalctl -u bt-health-snapshot.service -o cat -n
  20`) and either divide by the lifecycle-line pair or match only one form.
  Similarly `bt-trial`'s `btmon_aborts` greps `-u bt-trace` for "exited",
  which also matches systemd's "Main process exited" lines on service stop
  — a smaller overcount, same fix.

- **[NOTE] Not every tool reads the journal through the `bt_journal` seam.**
  `bt-trial`, `bt-window`, `bt-incident` call `journalctl` directly (their
  test strategy is PATH stubs and sandbox dirs instead). This looks
  deliberate — actuating tools get the sandbox treatment, analysis tools
  get the fixture seam — but nothing writes that rule down; a one-line note
  in `journal.sh`'s header would stop a future cleanup "fixing" it.

### 3.2 Individual tools

- **[MED] `trial-summary.awk` counts two buckets it never shows.** `rec[k]`
  ("confirmed, then rescued") is incremented and never referenced in END —
  the report has no column for watchdog-rescued confirmed failures, though
  the comment block argues that omitting it "understates the incidence …
  by exactly the watchdog success rate". And `unk[k]` (bt1_status=unknown)
  rows are excluded from every rate but appear in no output at all; a
  (type,build,treatment) key whose rows are *all* unknown vanishes from the
  report entirely, because the END loop iterates `tot`. Both contradict the
  file's own stated rule ("counted, shown, and excluded"). Add an UNKNOWN
  column (or a footer line) and either print `rec` or delete it.

- **[LOW] `trial-sco-table.awk` folds four distinct exclusion reasons into
  one `censored` counter** and prints them all as "censored by early
  watchdog intervention — excluded", which is wrong for CHANGED:/PERTURBED:
  and unknown rows. Split the message or the counter.

- **[LOW] `bt-trial` `next_trial_no` treats a headerless/foreign
  `results.tsv` as "no trials"** (NOHEADER → n=0 → numbering restarts at 1),
  which can overwrite `trial-01`'s auxiliary files. House style elsewhere is
  to refuse on an unjustifiable schema; this call site quietly starts over.

- **[LOW] `bt-verify-kernel-mechanism`'s byte-pair scan can match at a
  nibble boundary.** The module is rendered as one continuous hex string
  and `grep -qo "d313${lo}${hi}"` does not require even alignment, so a
  4-byte pattern can in principle match straddling two unrelated bytes —
  a false "present" in the tool whose job is proving absence. Probability
  is tiny (~2⁻³² per position) but the fix is one line: dump with offsets
  or require even offset before accepting a match.

- **[LOW] `bt-postmortem` labels `n_act` ("intervening" only) as
  "interventions" while `t_act` includes early ones** — the count and the
  timestamp row can disagree in an early-intervention incident. Cosmetic
  but confusing in the one report meant to be read under stress.

- **[LOW] `bt-logvolume`'s last-60s rate re-slices its argument array**
  (`${JARGS[@]:0:...}`) in a way that drops `-o cat` along with `--since`,
  so an empty last-minute window counts journalctl's "-- No entries --"
  line as 1 line/min. Rebuild the args instead of slicing.

- **[NOTE] `bt-mark`, `bt-boots`, `bt-boot-list`, `bt-context`,
  `bt-interval`, `bt-timeline`, `bt-state`, `bt-diagnose`, `bt-stage2`,
  `bt-window`, `bt-incident`, `bt-exhibit`, `bt-mode`, `bt-env-history`,
  `bt-health-report`, `bt-verify-install`: read in full, no defects found**
  beyond those above. Standouts worth naming: `bt-exhibit`'s three refusal
  paths (address in verbatim fields; command-did-not-run; missing/failing
  sanitiser treated identically), `bt-boot-list`'s four-stage fallback with
  loud degradation, `bt-verify-install`'s derived artifact/unit lists with
  the bt-mode interlock (two tools prevented from "fixing" each other in a
  loop), and `bt-mode`'s dry-run-through-the-same-call-site design.

- **[GOOD] `tools/sanitize-logs.sh` is the best small sanitiser I have
  reviewed.** The awk capability gate probes the regex engine in both
  directions (must-match-at-exact-length AND must-not-match) before
  trusting it; substitution and verification cover different form sets by
  construction; placeholders alias all three separator spellings to one
  key so cross-references survive; in-place use is atomic-rename-after-
  verify. One cosmetic note: past 99 distinct MACs the `%02d` placeholder
  grows a third digit ("AA:BB:CC:00:00:100") — still safe and still
  excluded by verification, just odd-looking.

## 4. Test harness — `tests/`

`tests/run-tests` read in full (4831 lines), plus the fixture layout, the
btmon text fixtures, and the journal corpus structure. Ran the suite: all
386 invariants pass in ~16 s. This file is the strongest artifact in the
repository — the PATH guard + decoy construction, the refuse-on-empty-
derivation rule, the sandboxed `trial()` discipline, the evidence-tree
footprint comparison, and the practice of asserting *qualifications* in
tool output (not just results) are all genuinely novel test engineering.
Findings:

- **[MED] Five invariants are accidentally nested inside the results.tsv
  width check's success branch.** At line ~1190, `if [[ -z "$WIDTH" ]];
  then` opens; its `ok "every row in results.tsv matches the header
  width"` does not arrive until line ~1245. In between sit the three
  `treatment_only_became_unreadable` tests (lines ~1203–1221) and the
  no-unbounded-journal-scan invariant (~1235–1243) — all inside the
  then-branch. If the live `results.tsv` ever has a row/width mismatch,
  those five invariants are silently skipped: the suite prints the `bad`
  for the width and never runs them, and since nothing pins the total
  count, the shrinkage is invisible. This is precisely the "check that
  cannot fail for the reason its name gives" class the file itself hunts.
  The interleaving looks like an editing accident (the "UNREADABLE IS NOT
  CHANGED" comment block was inserted between `then` and `ok`). Move the
  `ok/else/bad` up against the `WIDTH` computation.

- **[NOTE] The suite's self-guards held up under adversarial reading.** I
  specifically probed: the `--section` filter preserving the suite's exit
  code; the GUARDSTUB/DECOY heredoc expansions (correct quoting); the
  `combo()` stub-journalctl argument dispatch; the width-vs-blank-field
  distinction (the mutation-proofing note at ~3660); and the positive
  lifecycle-verb match for `trial()` enforcement. No further defects found.

- **[GOOD] Fixtures are drawn from the log they model, not from the shape
  the code expects** — the TMO_OPCODE_LINE lesson is applied throughout,
  and fixture addresses come from the documented placeholder space so the
  publish gate can stay strict. The refusal branches (mawk gate, empty
  derivations, unreadable journals) are asserted as behaviour, not skipped.

- **[NOTE] tests/README.md, tests/btmon/README.md and the fixture
  .in/.expected/.rc corpus were spot-checked for structure and
  consistency** with the harness's documented layout; consistent.

## 5. Contributor tooling and CI — `devtools/`, `.github/workflows/checks.yml`

Read in full: `check`, `coverage`, `coverage-exclude`, `awk-coverage`
(header + shim), `journal-contract`, `repo-scan`, `repo-save`,
`repo-validate`, `status`, `assert-test-catches`, the README, and the CI
workflow. Findings:

- **[HIGH] HEAD fails its own commit gate and its own CI.**
  `devtools/coverage` exits 2 on this checkout: its exclusion self-check
  reports three stale entries ("EXCLUDED lines were executed"), so
  `devtools/check` fails and the CI "coverage floor" step
  (`devtools/coverage --quiet --min 80`) fails. The cause is the final
  commit `ed82166`, which inserted lines into `tools/bt-trial` (shifting
  the `tools/bt-trial:613-621` exclusion range onto live code at 613/615)
  and edited `tests/run-tests`, without re-running the gate or updating
  `coverage-exclude`. The repository whose README calls `devtools/check`
  "the one command to run before committing" is currently red under it.
  Fix: re-derive the bt-trial range (the inline summary selector now
  starts ~10 lines later) and re-run `devtools/coverage`.

- **[MED] The third stale entry (`tests/run-tests:1208`) looks like an
  xtrace-attribution artifact worth root-causing, not just re-ranging.**
  Line 1208 is a `bad` branch, excluded by the shape rule and — in a green
  run — never executed. The likely mechanism: line ~1203 `eval`s the
  `treatment_only_became_unreadable` function out of `tools/bt-trial`, and
  bash attributes the eval'd body's LINENO relative to the eval site, so
  executing the function's Nth line lands on `tests/run-tests:1203+N` ≈
  1208 in the trace. If so, eval'd code can both falsely trip and falsely
  satisfy every line-pinned mechanism (exclusions *and* coverage). Sourcing
  the helper from a temp file instead of `eval` would restore honest
  attribution.

- **[NOTE] `coverage-exclude`'s line-pinned ranges rot by design** — the
  file says so itself and names the self-check as the arbiter. That is a
  defensible contract, but the failure mode just demonstrated is "CI goes
  red one commit after the edit", i.e. the arbiter fires post-hoc. The
  shape-based form (`path:/regex/`) already exists; migrating the inline-awk
  ranges to open/close-marker shapes would end the rot class.

- **[GOOD]** Too much to list briefly: `coverage`'s empty-trace refusal and
  `./install.sh` name-normalisation lesson; `awk-coverage`'s
  profile-hash-merge design and `/proc/$PPID/cmdline` sidecar;
  `journal-contract`'s phase-2 byte-equivalence over a built journal
  (including the recorded leading-separator divergence); `repo-save`'s
  message scanning with the counted-not-`grep -qv` fix; `repo-scan`'s
  assembled-from-fragments self-exemption and refuse-on-empty-read;
  `status`'s committed-vs-deployed contract; `assert-test-catches` as
  institutionalised mutation testing. The CI workflow's step ordering and
  its system-roundtrip gating (BT_SYSTEM_TEST=1 + clean-host predicates)
  are correct.

- **[LOW] `devtools/README.md` spot-checked** against the actual tool list
  — consistent; no drift found there.

## 6. Prior reviews — `reviews/`

Read: `README.md` (the register), `verify.sh` in full; the six reports and
the work log skimmed for structure and cross-checked against the register's
claims. Ran `reviews/verify.sh`: **11 verified, 1 open, 0 stale rows** —
the register is honest about itself. Its coverage line prints "(coverage
tool failed)", consistent with §5's HIGH finding.

- **[GOOD] The append-only report + live register + executable verifier
  design solves the exact drift problem the rest of the repo fights.**
  Reports are immutable snapshots; the register is current truth; every row
  carries a command that decides its own status; `verify.sh` exists because
  four of the first draft's verify commands were themselves wrong. This is
  the pattern the docs/ tree should envy (compare §1.5's fossilised
  "two failed late resets").
- **[NOTE] Genuinely open items, correctly recorded as open:** UT-10
  (journal-seam adoption 15 tools converted, 21 direct call sites left in
  8 files), UT-12 (split the 4831-line run-tests), CS-09 partial, HC-05..07
  (fold the round trip into measurement; work the uncovered tail; extract
  the remaining inline awk — HC-07 is the same fix as §3.1's civil-date
  duplication finding), HC-08 (100% floors, blocked on those), SE-05
  (worktree habit). Nothing recorded "done" was found to be undone.
- **[NOTE] The register's coverage trend footnote (85.0% at `251a6cb`)
  is the number README's "18.3%" should be quoting** — the front page is
  not just stale, it understates the repo's own achievement by 4–5×.

## 7. Evidence corpus — `evidence/`

Read: `evidence/README.md`, `evidence/exhibits/README.md` + spot-read
exhibits (EX-015, EX-018, EX-023 headers), `baseline/baseline.tsv`,
`trials/results.tsv` in full, session directory structure. Sanitisation
verified via `devtools/repo-scan . --all` (clean) — only placeholder-space
addresses appear anywhere in the tree.

- **[MED] Half the observational denominator is excluded by a
  since-fixed classifier bug, and the row was never re-emitted.**
  `evidence/trials/results.tsv` holds two data rows. Row 2 (trial stock
  #2, 2026-08-14, the 30-minute untreated window of EX-021/EX-022) carries
  `treatment=CHANGED:…power=auto->…power=?` — the exact "device-absent
  reads as treatment change" misclassification that HISTORY Phase 26
  documents and that `bt-trial` has since fixed (`treatment_only_became_
  unreadable`, with a test). The fix corrected the classifier, not the
  record: the row still pools with nothing and is excluded from every
  rate, so the observational record is currently 1 usable row of 2 — and
  trial stock #3's row was lost separately (documented in the final
  commit). The repo's no-hand-editing rule is right, but this needs a
  *tool-mediated* re-emission (or a documented standing correction the
  report applies), otherwise the A/B/C/D gate reads a denominator that
  silently omits the two most informative failures.

- **[LOW] EX-018's index row has an empty claim cell.** The exhibit was
  annotated (correctly, per the register discipline) by retitling its
  claim "**Historical claim.**" — which `bt-exhibit list/index` greps as
  `^\*\*Claim` and now misses, so `exhibits/README.md` shows EX-018 with
  no claim text. Either teach the grep the "Historical claim." form or
  keep the `**Claim.**` prefix and add the historical marker after it.

- **[NOTE] `20260810-072445-first-real-hang` predates the full session
  layout** (no MANIFEST.txt, no state-before/after) — collected by hand
  before `bt-evidence` existed. Consistent with HISTORY; fine, but worth a
  one-line README note so nobody reads the missing manifest as data loss.

- **[GOOD]** The baseline README's 34-vs-18-boots incomparability note,
  the 22-vs-25 synthetic-line arithmetic repeated at every point of use,
  the exhibits' single-pass command+output capture, and EX-018's
  historical-annotation-instead-of-silent-edit are all the right calls.

## 8. Cross-cutting observations and overall summary

### Cross-cutting

- **Prose-behind-code is the dominant defect class in this repo, and it is
  concentrated in exactly the places no invariant reaches**: README's test
  and coverage figures, the BT_EARLY ratio table, bug-report/fix-proposal's
  fossilised "two failed late resets", firmware-hypothesis's "two things",
  restore-original-state's 11-tool list. The machinery (BT1-CURRENT sync,
  retired-assertion scans, drift alarm) protects the claims someone thought
  to encode; everything found in §1 sits outside that fence. The cheapest
  systematic fix: extend the retired-assertion invariant with the handful
  of numeric claims ("96 invariants", "18.3%", "two failed late resets")
  the same way BT1-CURRENT is fenced.
- **The one rule the repo teaches but hasn't finished applying to itself**
  is "derive, don't enumerate": four inline copies of the civil-date
  arithmetic (§3.1), a hand-frozen uninstall list in prose (§1.10),
  line-pinned coverage exclusions (§5). Each has a derived counterpart
  elsewhere in the tree to copy.
- **Counting sites that read `journalctl -u <unit>` output as if it were
  only the unit's own lines** (probes ×2, aborts, §3.1) are the one
  uncorrected measurement-validity issue found; everything else of that
  species has already been caught by the repo's own history.

### Verdict

This is the most rigorously self-policing repository I have reviewed. The
epistemics — censoring discipline, refusal semantics, two-axis outcomes,
exhibits that carry their own extraction, tests that encode shipped
defects and are themselves mutation-tested — are consistently excellent,
and the shell/awk implementation quality is far above typical for the
genre. No finding in this review touches the central claims: the BT-3
device-table facts, the five-for-five late-reset record, the censoring
reclassification of the two-stage model, and the A/B/C/D gate logic all
survived adversarial reading intact.

### Findings by severity (fix in this order)

1. **[HIGH §5]** HEAD fails `devtools/check`/CI: stale `coverage-exclude`
   ranges from `ed82166`. One-line fixes; then root-cause the
   eval-attribution artifact (§5 MED).
2. **[MED §7]** results.tsv row 2's `CHANGED:` residue — re-emit via tool
   or the gate's denominator is wrong by construction.
3. **[MED §4]** Five invariants nested inside the width check's success
   branch in `tests/run-tests` (~lines 1190–1249).
4. **[MED §3.1]** `bt-trial` `$KJ` tmpfs leak; probe/abort double-count;
   civil-date ×4 duplication.
5. **[MED §3.2]** `trial-summary.awk`: dead `rec[]`, invisible `unknown`
   bucket (contradicts its own "counted, shown, excluded").
6. **[MED §2.2]** Early-intervention success invisible in metrics
   (`wd_rec` asymmetry, also in bt-evidence MANIFEST).
7. **[MED §1.x]** Documentation drift batch: README test/coverage figures
   and BT_EARLY ratios; bug-report + fix-proposal "two failed late
   resets" fossil; firmware-hypothesis "two things"; HISTORY "Current
   state" retitle; restore-original-state derived list.
8. **[LOW]** Everything else above, none urgent.

The review file itself: every item was written immediately after its
inspection, per the method stated in the plan; nothing in this file was
reconstructed from memory at the end.
