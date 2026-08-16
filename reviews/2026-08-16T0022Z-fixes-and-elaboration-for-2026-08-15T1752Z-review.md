# Fixes and elaboration — every finding of the 2026-08-15T1752Z review

**Covers:** the tree at `944b1eb1841699b483e795cb06d31fa57e1f6047` (`main`,
the merge of `origin/tests/unit-testing-assessment`) — the base of branch
`review/2026-08-15T1752Z-fixes`, on which every fix below lands.

**Relation to the review.** The review
(`2026-08-15T1752Z-comprehensive-code-review.md`, covering `ed82166`) is on
`main` byte-identically (blob `ba761c4c…` on both). `main` has since gained
the unit-testing-assessment merge (+4558/−91 across 54 files), so every
finding is re-verified against `main` before being touched: some were
already fixed there, and those are recorded as such rather than re-patched.

**What this document is.** One entry per finding — every severity,
including `[NOTE]` and `[GOOD]` — with an ID, an elaboration (what it is,
why it matters, what was decided), and a disposition. Entries are appended
immediately as each item is completed, and the table below is updated in
the same commit, so the document never claims more than has been done.

**Dispositions:**
- **fixed** — changed on this branch (commit named in the entry)
- **fixed-on-main** — already addressed by the merge; verified, not re-done
- **kept** — a `[GOOD]` practice, now marked in the source
- **recorded** — a `[NOTE]`/decision documented here and, where useful, in
  the source, so follow-up reviews do not re-derive it
- **declined** — deliberately not changed, with the reason

**The `REVIEWED-KEEP` convention, introduced here.** A `[GOOD]` finding is
a practice a future edit could casually destroy and a future review will
waste effort re-deriving. Each now carries a one-line marker at the
practice itself — `REVIEWED-KEEP 2026-08-15T1752Z §x.y: <what to keep>` in
shell/config comments, `<!-- REVIEWED-KEEP … -->` in markdown — citing the
review section that argued for it. Grep `REVIEWED-KEEP` to enumerate them.

## Catalogue and status

| ID | Sev | Review § | Target | Finding (short) | Status |
|---|---|---|---|---|---|
| CR-01 | MED | 1.1 | README.md | stale suite/coverage figures (96 invariants, ~2 s, 18.3%) | fixed |
| CR-02 | MED | 1.1 | README.md + bin/bt-hang-watchdog | BT_EARLY ratio notation inconsistent; unsourced | fixed |
| CR-03 | LOW | 1.1 | README.md | clone URL inconsistency | fixed |
| CR-04 | LOW | 1.1 | README.md | layout tree self-duplication; docs/ half-listed | fixed |
| CR-05 | NOTE | 1.1 | tools/bt-diagnose | exit-code contract verified real | recorded |
| CR-06 | GOOD | 1.1 | README.md | publishing-logs section explains why | kept |
| CR-07 | GOOD | 1.1 | README.md | candidate-fix "+0 s never tested" table | kept |
| CR-08 | MED | 1.2 | HISTORY.md | "Current state" section stale, no banner | fixed |
| CR-09 | LOW | 1.2 | HISTORY.md | superseded early-phase claims lack forward pointers | fixed |
| CR-10 | LOW | 1.2 | HISTORY.md | dangling commit hash 4c4047d | fixed |
| CR-11 | NOTE | 1.2 | HISTORY.md | Phase 12 resolves the CR-02 notation | recorded |
| CR-12 | NOTE | 1.2 | HISTORY.md | retained-boot counts drift 34→18→23→22 | recorded |
| CR-13 | GOOD | 1.2 | HISTORY.md | lessons are mechanised, not just recorded | kept |
| CR-14 | LOW | 1.3 | docs/issues.md | BT-4 carries two merged text generations | fixed |
| CR-15 | NOTE | 1.3 | docs/issues.md | "five levels" table has six rows | fixed |
| CR-16 | GOOD | 1.3 | docs/issues.md | BT-3 argues both directions | kept |
| CR-17 | GOOD | 1.3 | docs/issues.md | 9/5 reset-provenance caveat | kept |
| CR-18 | LOW | 1.4 | docs/investigation.md | boot-0 timeout counts 19 vs 22 unannotated | fixed |
| CR-19 | LOW | 1.4 | docs/investigation.md | "35 boots retained" vs 34 elsewhere | fixed |
| CR-20 | LOW | 1.4 | docs/investigation.md | doubled horizontal rule | fixed |
| CR-21 | NOTE | 1.4 | docs/issues.md | warm-reboot claim list misses investigation.md §8 | fixed |
| CR-22 | GOOD | 1.4 | docs/investigation.md | synthetic-line disclosure | kept |
| CR-23 | MED | 1.5 | docs/bug-report.md | Confidence note fossilised at n=3 | fixed |
| CR-24 | LOW | 1.5 | docs/bug-report.md | attachments quote conflated 22 count | fixed |
| CR-25 | NOTE | 1.5 | docs/bug-report.md | consumer device names deliberate | recorded |
| CR-26 | GOOD | 1.5 | docs/bug-report.md | Windows-comparison framing | kept |
| CR-27 | MED | 1.6 | docs/fix-proposal.md | §3b small-n fossil ("two failed late resets") | fixed |
| CR-28 | LOW | 1.6 | docs/fix-proposal.md | section order 3b→5a→4→5 | fixed |
| CR-29 | GOOD | 1.6 | docs/fix-proposal.md | six-behaviour enumeration; two-axis decision rules | kept |
| CR-30 | GOOD | 1.6 | docs/fix-proposal.md | conservative suggested commit message | kept |
| CR-31 | MED | 1.7 | docs/firmware-hypothesis.md | refuted "two things" model retained | fixed |
| CR-32 | LOW | 1.7 | docs/firmware-hypothesis.md | pre-Phase-16 cmd_timeout vocabulary | fixed |
| CR-33 | GOOD | 1.8 | docs/investigation-plan.md | A1 downgrade; BL-01/BL-02 form | kept |
| CR-34 | LOW | 1.9 | docs/changes-applied.md | §0 blast radius reads document-wide, is day-one | fixed |
| CR-35 | GOOD | 1.9 | docs/changes-applied.md | verification-command-beside-change rule | kept |
| CR-36 | MED | 1.10 | docs/restore-original-state.md | §2 hand-frozen 11-command list | fixed |
| CR-37 | NOTE | 1.10 | three docs | tooling disclosure — owner's decision | recorded |
| CR-38 | GOOD | 1.11 | pre-submission-checklist, related-reports | purge procedure; phenotype/cause line | kept |
| CR-39 | LOW | 2.1 | bin/bt-hang-watchdog | python3 dependency unchecked at startup | pending |
| CR-40 | LOW | 2.1 | bin/bt-hang-watchdog | give-up message differs early vs late | pending |
| CR-41 | GOOD | 2.1 | bin/bt-hang-watchdog | O_CREAT-less open; wrong-radio guard; loud exit | pending |
| CR-42 | MED | 2.2 | bin/bt-health-snapshot | early-intervention success invisible in metrics | pending |
| CR-43 | NOTE | 2.2 | bin/bt-health-snapshot | unbounded per-tick whole-boot scans | pending |
| CR-44 | GOOD | 2.3 | bin/bt-capture | btsnoop encoding verified; clock-semantics note | pending |
| CR-45 | GOOD | 2.3 | bin/bt-usbmon | ring-vs-rotate; never-delete-live-file | pending |
| CR-46 | LOW | 2.3 | bin/bt-trace | script MIN_FREE_GB default 10 vs unit 15 | pending |
| CR-47 | NOTE | 2.3 | bin/bt-trace | gaps.log one line/second on persistent crash | pending |
| CR-48 | GOOD | 2.4 | etc/** | modprobe dyndbg; PRODUCT form; journald warning; split units | pending |
| CR-49 | NOTE | 2.4 | systemd/bt-hang-watchdog.service | hardening modest; interactions to verify | pending |
| CR-50 | GOOD | 2.5 | install.sh | three guards; counted discipline; write-once stamp | pending |
| CR-51 | NOTE | 2.5 | install.sh / tests/run-tests | BT_STATE vs BT_TRIAL_STATE_DIR deliberate | pending |
| CR-52 | MED | 2.6 | uninstall.sh | no failure tracking; success banner unconditional | pending |
| CR-53 | NOTE | 2.6 | uninstall.sh | hand lists acceptable (suite derives + asserts) | pending |
| CR-54 | GOOD | 2.7 | tools/verify-restored.sh | derived lists; refusal; .disabled awareness | pending |
| CR-55 | LOW | 2.7 | bin/bt-evidence | MANIFEST wd_recovered early blind spot | pending |
| CR-56 | MED | 3.1 | tools/bt-trial | $KJ temp file never removed | pending |
| CR-57 | MED | 3.1 | bt-actions, bt-sco, bt-boot-stats | civil-date arithmetic ×4 copies | pending |
| CR-58 | MED | 3.1 | bt-trial, bt-env-history | probe/abort counts include systemd lifecycle lines | pending |
| CR-59 | NOTE | 3.1 | tools/lib/journal.sh | seam-vs-PATH-stub rule unwritten | pending |
| CR-60 | MED | 3.2 | tools/lib/trial-summary.awk | rec[] dead; unknown bucket invisible | pending |
| CR-61 | LOW | 3.2 | tools/lib/trial-sco-table.awk | four exclusion reasons one message | pending |
| CR-62 | LOW | 3.2 | tools/bt-trial | NOHEADER results.tsv restarts numbering at 1 | pending |
| CR-63 | LOW | 3.2 | tools/bt-verify-kernel-mechanism | hex scan can match at nibble offset | pending |
| CR-64 | LOW | 3.2 | tools/bt-postmortem | n_act counts late only; t_act includes early | pending |
| CR-65 | LOW | 3.2 | tools/bt-logvolume | arg-slice drops -o cat; counts "-- No entries --" | pending |
| CR-66 | NOTE | 3.2 | tools/* | remaining tools read clean; standouts named | pending |
| CR-67 | GOOD | 3.2 | tools/sanitize-logs.sh | two-direction engine gate; atomic in-place | pending |
| CR-68 | MED | 4 | tests/run-tests | five invariants nested in width-check branch | pending |
| CR-69 | NOTE | 4 | tests/run-tests | self-guards held under adversarial reading | pending |
| CR-70 | GOOD | 4 | tests/run-tests + fixtures | fixtures drawn from real log text | pending |
| CR-71 | NOTE | 4 | tests/ | fixture corpus consistent with harness docs | pending |
| CR-72 | HIGH | 5 | devtools/coverage-exclude | HEAD failed own gate: stale exclusions | pending |
| CR-73 | MED | 5 | tests/run-tests | eval'd helper corrupts xtrace line attribution | pending |
| CR-74 | NOTE | 5 | devtools/coverage-exclude | line-pinned ranges rot by design | pending |
| CR-75 | GOOD | 5 | devtools/* | coverage refusals; journal-contract phase 2; etc. | pending |
| CR-76 | NOTE | 5 | devtools/README.md | consistent with tool list | pending |
| CR-77 | GOOD | 6 | reviews/ | report+register+verifier design | pending |
| CR-78 | NOTE | 6 | reviews/README.md | open items accurately recorded | pending |
| CR-79 | NOTE | 6 | README.md | register's 85% is the number to quote (feeds CR-01) | pending |
| CR-80 | MED | 7 | evidence/trials/results.tsv readers | pre-fix CHANGED: row excluded from denominator | pending |
| CR-81 | LOW | 7 | tools/bt-exhibit + exhibits/README.md | EX-018 index claim cell empty | pending |
| CR-82 | NOTE | 7 | evidence/README.md | first-real-hang predates full session layout | pending |
| CR-83 | GOOD | 7 | evidence/ | baseline incomparability notes; exhibit capture | pending |

Entries follow, appended one by one as each is completed.

---

## Section A — foundation documents

### CR-01 [MED] README's suite and coverage figures were stale — **fixed**

**Elaboration.** The front page said "96 invariants, ~2 s" and "coverage
18.3%, 38 of 44 scripts at zero". At `ed82166` the suite held 386
invariants; at `944b1eb` it holds 591, coverage is 87.3%, and 10 of 53
files execute zero lines. The deeper defect is not the wrong numbers but
the *kind* of claim: these move with nearly every commit, so any pasted
snapshot is wrong within days, and a wrong number on the front page
teaches readers that numbers here are unmaintained.

**Fix.** The volatile numbers are REMOVED, not refreshed. The Tests
section now points at the executable sources (`tests/run-tests` prints
"all N invariants hold"; `devtools/coverage` / `devtools/awk-coverage`
print the current figures; CI enforces the floors), keeps only the
anchored historical 13.1% starting point, and carries an HTML comment
explaining why no snapshot may be pasted back. Drift-proof by
construction rather than corrected-until-next-time.

### CR-02 [MED] BT_EARLY ratio notation inconsistent and unsourced — **fixed**

**Elaboration.** README defined the ratios as "appearances overall vs. in
boots that hung", under which its own "3/9 excluded" datum is impossible;
`HISTORY.md` Phase 12 uses the opposite order ("4/4 occurrences fell in
boots that hung"), under which the impossible datum is `avdtp_close
failed 4/3`. The ratios also appear nowhere else — no exhibit derives
them, and the source boots were destroyed by the 2026-08-12 retention
accident, so they can never be re-derived.

**Fix.** Both copies (README and the `bin/bt-hang-watchdog` comment) now
state the Phase-12 notation — *in-hung / overall* — and correct the
transposed datum to `3/4`. Both carry an explicit "historical, not
re-derivable" caveat citing the EX-003 precedent and each other, so the
two copies cannot drift apart silently again. Recorded honestly: the 3/4
orientation is inferred from Phase 12's usage, not re-measured — nothing
can re-measure it.

### CR-03 [LOW] Clone URL inconsistency — **fixed**

The Install section's `github.com/<you>/…` placeholder is now the
canonical `ivoitovych` URL with "or your fork", matching the quick-check.

### CR-04 [LOW] Repository-layout tree self-duplication — **fixed**

The tree was two generations merged: `tests/` listed twice, `tools/lib/`,
`exhibits/`, `trials/` dangling after the closing entries, and half of
`docs/` missing. Rebuilt as one tree, one entry per path, all ten docs
accounted for, with a comment recording why (so the next merge of two
generations is recognisable).

### CR-05 [NOTE] bt-diagnose exit-code contract — **recorded**

Verified real during the review (0 = not observed, 1 = observed, 2 =
cannot determine; all three asserted distinct by the suite). No change
needed; recorded so follow-ups cite the suite's three-codes-distinct
invariant instead of re-checking by hand.

### CR-06 [GOOD] Publishing-logs section — **kept**

`REVIEWED-KEEP` marker added: the section's value is that it keeps the
*reason* (BSSID → geolocation) attached to the rule; an edit that trims
the explanation to "run the sanitiser" would survive review as a
harmless shortening and lose the thing that makes people comply.

### CR-07 [GOOD] Candidate-fix section refuses its own temptation — **kept**

`REVIEWED-KEEP` marker added above the section naming its two
load-bearing elements: the "+0 s never tested" table and the
setup-failure warning. Removing either turns the hypothesis back into
"the fix".

### CR-08 [MED] HISTORY's "Current state" presented a superseded world as present — **fixed**

The section froze 2026-08-10 07:40 ("Root cause identified ✅", "nothing has
hung since") between Phases 8 and 9, under the one title a searcher lands
on. Retitled "as of the end of Phase 8 … ⚠️ SUPERSEDED" with a banner
naming what overturned each claim and pointing at `docs/issues.md`.
Chronology preserved; only the frame changed.

### CR-09 [LOW] Superseded early-phase claims lacked forward pointers — **fixed**

The file already annotates some corrected passages in place (Phase 2's
modinfo caveat, Phase 18's overreach) but not others. Added italic
"(superseded — see Phase N)" notes at the three known-wrong load-bearing
spots: Phase 1's two-stage blockquote (~6 h figure, M.2-rail claim),
Phase 2's `btusb_qca_cmd_timeout`/5-timeouts mechanism, Phase 3's
"same ioctl" and "kernel's 5" claims. The original text stands unedited —
the annotations say only where the correction lives.

### CR-10 [LOW] Dangling commit hash `4c4047d` — **fixed**

Annotated as a hash from the pre-publication working repository, absent
from this repository's rewritten history (verified with `git cat-file`).
The reference is now honest about what it can and cannot resolve.

### CR-11 [NOTE] Phase 12 resolves the ratio notation — **recorded**

Used as the authority for CR-02's fix; no separate change. Recorded so the
derivation of the 3/4 orientation is traceable to Phase 12's wording.

### CR-12 [NOTE] Retained-boot counts drift across phases — **recorded**

One parenthetical added at Phase 24's "23 retained boots" explaining the
rolling denominator (34 → 18 → shrinking) and warning against "correcting"
the phases into agreement. The other counts stand as written.

### CR-13 [GOOD] Lessons are mechanised — **kept**

`REVIEWED-KEEP` marker at the "corrections belong in the machinery"
section: future lessons should keep landing as tools/tests, not prose.

### CR-14 [LOW] BT-4 carried two merged text generations — **fixed**

The stale trailing paragraph (duplicate "still needed" list, "(below)"
pointing the wrong way) is replaced by a note recording the removal; the
filing blockers are stated once, at the reproducer.

### CR-15 [NOTE] "Five levels", six rows — **fixed**

Heading now "The six levels (0–5)…", with a sentence explaining the
history (level 0 added last, beneath the rest). The one live code
reference (`tools/bt-trial` comment) updated to match; HISTORY's mention
left as chronology.

### CR-16 / CR-17 [GOOD] BT-3 argues both directions; the 9/5 caveat — **kept**

Both marked with `REVIEWED-KEEP` comments in `docs/issues.md`: the
deliberate-omission alternative + unmeasured-sign caution in BT-3, and the
refusal to cite the register's own headline zero as re-verified.

### CR-18 [LOW] investigation.md boot-0 counts 19 vs 22 — **fixed**

Annotated at the 19: the file was appended to during a live boot; 19 and
22 are timestamps of a moving count, and the published log's final 22
decomposes as 21 command + 1 link timeout. Nothing rewritten.

### CR-19 [LOW] "35 boots retained" vs 34 — **fixed**

Annotated: 35 includes the then-current boot; the 34 quoted everywhere
else excludes it.

### CR-20 [LOW] Doubled horizontal rule — **fixed** (one removed).

### CR-21 [NOTE] issues.md's warm-reboot enumeration missed investigation.md §8 — **fixed**

The BT-1 "untested assumption" list now includes `docs/investigation.md`
§8, noting it states the claim with a ✅ under that file's historical
banner — so the enumeration of *where the claim appears* is itself
complete again.

### CR-22 [GOOD] Synthetic-line disclosure — **kept** (`REVIEWED-KEEP` marker).

### CR-23 [MED] bug-report Confidence note fossilised at n=3 — **fixed**

Now counts the same five late resets the rest of the report counts, notes
the fossil's origin, and no longer promises "all three" attachments.

### CR-24 [LOW] Conflated 22 in attachments — **fixed**

"22 `tx timeout` lines … 21 HCI command timeouts plus 1 `link tx timeout`",
with the EX-015 do-not-pool pointer — the report now obeys its own Level-0
lesson at the last place it didn't.

### CR-25 [NOTE] Consumer device names in the report — **recorded**

Deliberate (they identify hardware, not people) and consistent with the
sanitisation policy. Recorded so follow-ups don't re-raise it.

### CR-26 [GOOD] Windows-comparison framing — **kept** (`REVIEWED-KEEP` marker).

### CR-27 [MED] fix-proposal §3b small-n fossil — **fixed**

Same fossil as CR-23, in the second document, proving the review's point
that corrections must be applied by grepping the tree. Now: five late
resets with their timings, all five instrumented sessions listed
(including `194254-early-threshold-missed` and `195623-no-early-signal-fast`,
which the old list omitted), plus a note telling future editors to grep
for the old phrase.

### CR-28 [LOW] Section order 3b→5a→4→5 — **fixed**

§5a physically moved to sit after §5; all section NUMBERS kept (too many
documents cite "§5a" to renumber), with a comment recording the decision.
Verified no directional ("below/above") references broke.

### CR-29 / CR-30 [GOOD] Six-behaviour enumeration; conservative commit message — **kept**

Both marked: collapsing the enumeration back to "reset + firmware"
re-creates the Phase-17 flaw; strengthening the commit message outruns the
evidence gates.

### CR-31 [MED] firmware-hypothesis carried the refuted "two things" model — **fixed**

Now: "six things (enumerated verbatim in fix-proposal §3) … the two that
matter for THIS hypothesis", with the history of the residue named. The
hypothesis itself is untouched — it genuinely depends only on items 1–2.

### CR-32 [LOW] Pre-Phase-16 vocabulary in "Consequence" — **fixed**

"no `cmd_timeout` handler, and that handler would not have helped anyway"
→ "no reset callback (`hdev->reset` stays NULL) … with the +0 s point
untested" — the before/after comparison now compares against the corrected
mechanism.

### CR-33 [GOOD] investigation-plan.md — **kept** (file-top `REVIEWED-KEEP`
naming the A1 downgrade, the A4 gate, and the BL-01/BL-02 form).

### CR-34 [LOW] changes-applied §0 scope — **fixed**

Retitled "as of 2026-08-10, the first install" with a scope banner
pointing at the dated sections and at `install.sh` as the current
manifest.

### CR-35 [GOOD] Verification-command-beside-change rule — **kept** (marker).

### CR-36 [MED] restore-original-state's hand-frozen 11-command list — **fixed**

The enumeration is *removed*, not refreshed — per the repo's own
"the enumeration is the bug" lesson. The paragraph now names `install.sh`
as the authoritative manifest and cites the two mechanical guarantees
(the suite's install/uninstall pairing invariant; `verify-restored.sh`'s
run-time derivation), with the rot history recorded in place.

### CR-37 [NOTE] Tooling disclosure in three docs — **recorded, deliberately unchanged**

`restore-original-state.md` §4, `HISTORY.md` Phase 4 and
`pre-submission-checklist.md` §5 name the development tooling; the publish
scan blocks only attribution-trailer forms, so these pass it. Whether
that is the intended policy line is the owner's decision alone — this pass
changes nothing there, and records the decision point so follow-up reviews
cite this entry instead of re-raising it.

### CR-38 [GOOD] Purge procedure; phenotype/cause line — **kept** (markers in both files).
