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
