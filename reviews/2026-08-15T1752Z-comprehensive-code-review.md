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
- **[LOW] `bt-trace` and `bt-usbmon` disagree with their units on
  `MIN_FREE_GB` defaults** (script defaults 10; units set 15). Harmless
  while the units always set it — but that is precisely the
  `BT_TRACE_KEEP=30` pattern the repo documented: a script default that
  differs from the value in effect will mislead the next person who runs
  the script by hand. Align the defaults.
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
