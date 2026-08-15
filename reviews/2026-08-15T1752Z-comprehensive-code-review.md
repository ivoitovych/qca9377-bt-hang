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
