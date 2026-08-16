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
| CR-39 | LOW | 2.1 | bin/bt-hang-watchdog | python3 dependency unchecked at startup | fixed |
| CR-40 | LOW | 2.1 | bin/bt-hang-watchdog | give-up message differs early vs late | fixed |
| CR-41 | GOOD | 2.1 | bin/bt-hang-watchdog | O_CREAT-less open; wrong-radio guard; loud exit | kept |
| CR-42 | MED | 2.2 | bin/bt-health-snapshot | early-intervention success invisible in metrics | fixed |
| CR-43 | NOTE | 2.2 | bin/bt-health-snapshot | unbounded per-tick whole-boot scans | recorded |
| CR-44 | GOOD | 2.3 | bin/bt-capture | btsnoop encoding verified; clock-semantics note | kept |
| CR-45 | GOOD | 2.3 | bin/bt-usbmon | ring-vs-rotate; never-delete-live-file | kept |
| CR-46 | LOW | 2.3 | bin/bt-trace | script MIN_FREE_GB default 10 vs unit 15 | fixed |
| CR-47 | NOTE | 2.3 | bin/bt-trace | gaps.log one line/second on persistent crash | fixed |
| CR-48 | GOOD | 2.4 | etc/** | modprobe dyndbg; PRODUCT form; journald warning; split units | kept |
| CR-49 | NOTE | 2.4 | systemd/bt-hang-watchdog.service | hardening modest; interactions to verify | recorded |
| CR-50 | GOOD | 2.5 | install.sh | three guards; counted discipline; write-once stamp | kept |
| CR-51 | NOTE | 2.5 | install.sh / tests/run-tests | BT_STATE vs BT_TRIAL_STATE_DIR deliberate | recorded |
| CR-52 | MED | 2.6 | uninstall.sh | no failure tracking; success banner unconditional | fixed |
| CR-53 | NOTE | 2.6 | uninstall.sh | hand lists acceptable (suite derives + asserts) | recorded |
| CR-54 | GOOD | 2.7 | tools/verify-restored.sh | derived lists; refusal; .disabled awareness | kept |
| CR-55 | LOW | 2.7 | bin/bt-evidence | MANIFEST wd_recovered early blind spot | fixed |
| CR-56 | MED | 3.1 | tools/bt-trial | $KJ temp file never removed | fixed |
| CR-57 | MED | 3.1 | bt-actions, bt-sco, bt-boot-stats | civil-date arithmetic ×4 copies | fixed |
| CR-58 | MED | 3.1 | bt-trial, bt-env-history | probe/abort counts include systemd lifecycle lines | fixed |
| CR-59 | NOTE | 3.1 | tools/lib/journal.sh | seam-vs-PATH-stub rule unwritten | recorded |
| CR-60 | MED | 3.2 | tools/lib/trial-summary.awk | rec[] dead; unknown bucket invisible | fixed |
| CR-61 | LOW | 3.2 | tools/lib/trial-sco-table.awk | four exclusion reasons one message | fixed |
| CR-62 | LOW | 3.2 | tools/bt-trial | NOHEADER results.tsv restarts numbering at 1 | fixed |
| CR-63 | LOW | 3.2 | tools/bt-verify-kernel-mechanism | hex scan can match at nibble offset | fixed |
| CR-64 | LOW | 3.2 | tools/bt-postmortem | n_act counts late only; t_act includes early | fixed |
| CR-65 | LOW | 3.2 | tools/bt-logvolume | arg-slice drops -o cat; counts "-- No entries --" | fixed |
| CR-66 | NOTE | 3.2 | tools/* | remaining tools read clean; standouts named | kept |
| CR-67 | GOOD | 3.2 | tools/sanitize-logs.sh | two-direction engine gate; atomic in-place | kept |
| CR-68 | MED | 4 | tests/run-tests | five invariants nested in width-check branch | fixed-on-main |
| CR-69 | NOTE | 4 | tests/run-tests | self-guards held under adversarial reading | kept |
| CR-70 | GOOD | 4 | tests/run-tests + fixtures | fixtures drawn from real log text | kept |
| CR-71 | NOTE | 4 | tests/ | fixture corpus consistent with harness docs | recorded |
| CR-72 | HIGH | 5 | devtools/coverage-exclude | HEAD failed own gate: stale exclusions | recorded |
| CR-73 | MED | 5 | tests/run-tests | eval'd helper corrupts xtrace line attribution | fixed-on-main |
| CR-74 | NOTE | 5 | devtools/coverage-exclude | line-pinned ranges rot by design | recorded |
| CR-75 | GOOD | 5 | devtools/* | coverage refusals; journal-contract phase 2; etc. | kept |
| CR-76 | NOTE | 5 | devtools/README.md | consistent with tool list | recorded |
| CR-77 | GOOD | 6 | reviews/ | report+register+verifier design | kept |
| CR-78 | NOTE | 6 | reviews/README.md | open items accurately recorded | recorded |
| CR-79 | NOTE | 6 | README.md | register's 85% is the number to quote (feeds CR-01) | fixed |
| CR-80 | MED | 7 | evidence/trials/results.tsv readers | pre-fix CHANGED: row excluded from denominator | fixed |
| CR-81 | LOW | 7 | tools/bt-exhibit + exhibits/README.md | EX-018 index claim cell empty | fixed |
| CR-82 | NOTE | 7 | evidence/README.md | first-real-hang predates full session layout | fixed |
| CR-83 | GOOD | 7 | evidence/ | baseline incomparability notes; exhibit capture | kept |
| CR-84 | MED | new | tests/run-tests, devtools/repo-validate | gawk-dependent tests fail on mawk; validator blind to mawk diagnostics | fixed |

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

## Section B — deployed runtime (`bin/`, `systemd/`, `etc/`, install/uninstall)

### CR-39 [LOW] Watchdog never checked for python3 — **fixed**

`usbfs_reset()` needs python3; without it every intervention silently
became unbind/bind — a different treatment than documented, with no
warning. The startup banner now warns exactly as it does for the missing
probe tools. `install.sh` already preflights python3, so this covers the
hand-deployed copy — the one with no other warning.

### CR-40 [LOW] Give-up message differed between paths — **fixed**

The early path now logs the same two lines as the late path, so a log
scraper keying on "A cold power-off is required" sees every give-up.

### CR-41 [GOOD] Three watchdog practices — **kept**

`REVIEWED-KEEP` markers at the O_CREAT-less `os.open` (the devtmpfs race),
the resolve-hci-from-our-device rule (spare-dongle trap), and the loud
journal-reader-died exit.

### CR-42 [MED] Early-intervention success invisible in metrics — **fixed**

The schema deliberately refuses to call a censored outcome a recovery —
but then had no column for it, so "intervened, controller answers" was
indistinguishable from "attempted, unverifiable" in the TSV (the mirror
image of the Phase-10 undercount). `bt-health-snapshot` now writes a 15th
column `wd_early_ok` (current + legacy message forms), with a one-time,
atomic, in-writer migration of pre-existing files: header extended, legacy
rows get `-` (not recorded — never 0, which would claim the outcome was
measured and absent). Two new invariants: the early success lands in
`wd_early_ok` and does NOT inflate `wd_recovered`; and the migration
leaves every row 15 wide with the legacy row's new cell `-`. The suite's
own pipefail invariant caught the first draft of the migration guard
(`head | grep -q`) — rewritten pipeline-free; that catch is the checks
working as designed.

### CR-43 [NOTE] Snapshot's whole-boot scans — **recorded**

The counters genuinely need the whole boot, the tick is a timer (not a
shutdown-critical path), and main's merge already routed them through
`bt_journal_count`. Known cost, documented here; not a defect.

### CR-44 / CR-45 [GOOD] bt-capture encoding; bt-usbmon rotation — **kept**

Markers added: the verified btsnoop monitor encoding + clock-semantics
warning; supervise-and-rotate (never `tcpdump -C -W`) + never delete the
live capture.

### CR-46 [LOW] bt-trace default MIN_FREE_GB 10 vs unit's 15 — **fixed**

Script default raised to 15 with a comment naming this as the
BT_TRACE_KEEP pattern (a default differing from the value in effect).

### CR-47 [NOTE] gaps.log growth under persistent btmon failure — **fixed**

After 10 consecutive instant deaths the respawner logs once, backs off to
CHECK_SEC, and suppresses per-second gap lines; any restart surviving a
full poll resets the streak, so the ordinary BT-4 crash-restart path is
untouched.

### CR-48 [GOOD] Four etc/ decisions — **kept**

Markers on: dyndbg-at-module-load + per-file selection (modprobe conf),
the PRODUCT %x-format note (udev rule), the MaxRetentionSec warning
(journald drop-in), and the probe-provenance unit split (event unit).

### CR-49 [NOTE] Watchdog unit hardening — **recorded, with a question for the owner**

A comment in the unit now explains why the lockdown stops where it does
(NoNewPrivileges would break notify()'s sudo; nothing was added
sight-unseen to the one unit whose failure mode is "the recovery path dies
when needed"). It also records an interaction to verify on the machine:
ProtectHome=yes vs the watchdog's `bt-trial hang` writing a results row
into a checkout that may live under /root — with the exact journalctl
command to check whether past closures actually produced rows.

### CR-50 / CR-51 [GOOD+NOTE] install.sh guards; BT_STATE naming — **kept/recorded**

Marker over the three-guard block (each protects a distinct asset), and a
do-not-unify note at the open-trial guard explaining why `BT_STATE` and
the suite's `BT_TRIAL_STATE_DIR` are deliberately different variables.

### CR-52 [MED] uninstall.sh printed success over failures — **fixed**

`run()` now accumulates failures (deliberately not aborting: later
removals are independent, and a partial revert should still remove what it
can), and the final banner splits: `UNINSTALL INCOMPLETE`, exit 1, and a
pointer to `verify-restored.sh` when anything failed. This is the same
accumulator install.sh received in the Phase-5 review; the pair is now
symmetric. Verified compatible with main's new BT_DESTDIR staging mode.

### CR-53 [NOTE] uninstall's hand lists — **recorded**

Header comment added: the lists are hand-written by accepted decision,
because three derived checks police them (the suite's pairing invariant,
verify-restored's run-time derivation); the rule is "extend install.sh and
let the invariant fail until this file catches up", never a fourth list.

### CR-55 [LOW] bt-evidence MANIFEST early blind spot — **fixed**

MANIFEST gains `wd_early_ok=` (current + legacy forms), matching
bt-incident's split and the CR-42 column, with the same
censored-not-recovered rationale in place.

Suite after Section B: **all 593 invariants hold** (591 + the two CR-42
tests).

## Section C — tools/ (CR-56 .. CR-67, CR-80)

### CR-56 [MED] bt-trial's $KJ temp file never removed — **fixed**

`trap 'rm -f "$KJ"' EXIT` immediately after the mktemp. It cannot be
removed inline like `$WJ` — `jk()` reads it all the way down to the
SCO-timing block — so the trap covers the normal return and every early
exit between. The comment marks it as the script's only EXIT trap, to be
extended rather than replaced (the run-tests one-EXIT-trap lesson,
applied preemptively).

### CR-57 [MED] civil-date arithmetic, four copies — **fixed**

Three new libraries under `tools/lib/`, each built on `timestamp.awk`'s
`iso_secs()` (the one implementation that already handles month/year
boundaries and TZ offsets):

- `boot-hours.awk` — hours between two ISO stamps (bt-boot-stats);
  verified 2.5h across a month boundary where the old
  `(dd*24+hh)+mm/60` delta arithmetic returns garbage.
- `sco-window.awk` — the two-pass SCO-window mark/selection
  (bt-sco --window).
- `actions-render.awk` — the collapse-cadence renderer (bt-actions).

The three consumers now load them with `-f` beside `timestamp.awk`
(never inline programs beside `-f` — the repo's own trap), with
lib-presence guards matching the existing style. install.sh /
uninstall.sh carry all three, keeping the pairing invariant derivable.

### CR-58 [MED] probe/abort counts include systemd lifecycle noise — **fixed**

Both bt-trial counters and bt-env-history's probes column: a oneshot run
logs `Starting <desc>...` AND `Finished <desc>.`, so matching the unit
description counted every probe twice (and counted runs that died before
probing). All three sites now count `^Finished Snapshot Bluetooth health
metrics` only; `probe_to_tmo`'s nearest-preceding-probe lookup matches
`Finished` for the same reason. `aborts` matches bt-trace's actual
message `btmon exited` instead of bare `exited`. Comments carry the
systemd-wording caveat (old systemd said "Started"; re-verify after an
upgrade). New envhist fixture (3 Starting / 2 Finished) pins the
completed-runs-only semantics; the suite asserts the row ends in 2,
not 5.

### CR-59 [NOTE] seam-vs-PATH-stub strategy unwritten — **recorded**

journal.sh header now states the rule: reading tools are driven through
the fixture seam; actuating tools (bt-trial, bt-window, bt-incident) are
driven in the PATH-stub sandbox because their risk is acting on a real
controller, not reading the wrong journal — so a tool missing from the
UT-10 conversion list is not necessarily a coverage gap.

### CR-60 [MED] trial-summary's rec[] counted, never shown — **fixed**

The table gains a RESCUED column (`rec/inc`). It is not derivable from
the others: INC − UNRECOV also contains confirmed rows whose controller
came back *without* intervention. New fixture `rescued-shown` pins
exactly that distinction (UNRECOV 1/4, INC 3/4, RESCUED 1/3 — the
fourth confirmed row survived unaided). The UNKNOWN display half of the
original finding was already fixed on main; verified, and the
regenerated `.expected` files carry both.

### CR-61 [LOW] sco-table: four exclusion reasons, one message — **fixed**

`censored`/`drifted`/`unread` are now separate counters with separate
messages; "censored by early watchdog intervention" is claimed only for
`censored_pre_failure` rows. The `censored-excluded` fixture (which holds
one of each) now shows three one-count lines instead of one false
three-count line.

### CR-62 [LOW] headerless results.tsv restarts numbering at 1 — **fixed**

`next_trial_no()` distinguishes a missing file (legitimately trial 1)
from an existing file whose first line is not the header: the latter
refuses with an explanation, and both callers (`start`, `autostart`)
propagate the refusal with `|| exit 1`. Fixing it exposed a second
defect: the awk printed NOHEADER inline *and* a count from END (awk runs
END after `exit`), so the caller's compare saw neither token — the
verdict now comes from END alone. Three new sandboxed tests drive a
corrupt file through both entry points and assert the file is left
untouched for inspection.

### CR-63 [LOW] device-ID hex scan can match at nibble offset — **fixed**

`check_id()` replaces the bare substring grep with a byte-aligned awk
match (1-based position must be odd). A mid-byte match spells the ID out
of bytes that are not `d3 13 …` and reports a device present in a table
it is not in — the opposite of the section's argument. Both directions
verified against synthetic hex streams.

### CR-64 [LOW] postmortem n_act missed EARLY interventions — **fixed**

`n_act` now matches `intervening|EARLY intervention`, same as the
timeline's `t_act` — previously one incident printed "watchdog
intervened <time>" beside "interventions 0". Suite asserts
`interventions 1 (early 1)` over the pm-early fixture.

### CR-65 [LOW] logvolume rate slice drops -o cat; counts "-- No entries --" — **fixed**

The 60-second window rebuilds its argument list explicitly (RATEARGS)
instead of slicing JARGS by index — the slice silently went stale
whenever JARGS changed shape. An empty window's `-- No entries --`
stdout line is excluded from the count (one phantom line per quiet
minute otherwise).

### CR-66 / CR-67 [NOTE+GOOD] tool standouts — **kept**

REVIEWED-KEEP markers placed at the five standouts: sanitize-logs.sh
(two-direction engine gate + build-then-rename in-place path),
bt-exhibit (did-not-run refusal + missing-sanitiser treated as failing),
bt-boot-list (three-rung --list-boots ladder, each rung a real systemd
breakage), bt-verify-install (derivation from install.sh + `.disabled`
interlock), bt-mode (single-call-site dry-run).

### CR-80 [MED] pre-fix CHANGED row excluded from the real denominator — **fixed**

New `tools/lib/trial-reclass.awk`: a read-time corrector loaded with
`-f` before both results.tsv consumers (bt-trial report does it; the
fixtures load it via DEPS). A `CHANGED:a->b` treatment where `b` differs
from `a` only by fields whose closing value is `?` is classified under
`a` — the same correction the writer now applies
(`treatment_only_became_unreadable`), applied to rows the pre-fix writer
already recorded. Real changes pass through untouched; PERTURBED rows
are never touched; both reports print a reclassification note so the
report and the raw TSV cannot silently disagree. The evidence file is
not rewritten (the no-hand-editing rule stands). Fixtures:
`reclassified-unreadable` (both consumers) and `changed-real-excluded`
(a genuine change stays out). Over the real record, trial stock #2 —
one of the two most informative failures — re-enters the observational
denominator.

Suite after Section C: **all 602 invariants hold** (599 + the three new
reclass/rescued fixture cases).

## Section D — tests/ and devtools/ (CR-68 .. CR-76, CR-84)

### CR-68 [MED] five invariants nested inside the width check — **fixed on main**

Verified at 944b1eb: the block is unnested (the `ok`/`bad` pair now sits
beside its own check) and the comment above it cites this finding. No
further action.

### CR-69 / CR-70 [NOTE+GOOD] run-tests self-guards; real-text fixtures — **kept**

One REVIEWED-KEEP block in the file header records both: every self-guard
encodes an escape that actually happened (none tolerates an exception
list), and fixtures are drawn from real log wording — the recurring
failure mode being patterns written on the machine where the other half
never appears.

### CR-71 [NOTE] fixture corpus consistent with harness docs — **recorded**

Re-checked after this branch's additions (envhist snapshot log, four new
fixture cases, two DEPS files): layout still matches the documented
grammar in journal.sh and the fixtures section of tests/README.md.
Recorded here; nothing to change.

### CR-72 [HIGH] coverage-exclude stale at ed82166 — **fixed on main; recurs below**

Main repaired the exclusions (87.3% at the merge). This branch's edits
shift lines again; the final phase of this document re-derives the
affected ranges before the gate runs. The finding's lesson is CR-74's
note.

### CR-73 [MED] eval'd helper corrupted xtrace attribution — **fixed on main**

Verified: the helper is extracted to a temp file and sourced, with the
full rationale in place (xtrace attributes eval'd code to unrelated line
numbers in the sourcing file; coverage then counts excluded lines as
executed). No further action.

### CR-74 [NOTE] line-pinned exclusion ranges rot by design — **recorded**

coverage-exclude's header now says so explicitly: the rot is the accepted
cost of the self-check (an auto-tracking exclusion could silently keep
hiding code), with the repair rule — re-derive, re-read the reason, drop
if it no longer holds, expect to touch the file in the same commit as any
edit to a listed file.

### CR-75 [GOOD] devtools standouts — **kept**

REVIEWED-KEEP markers at each named site: coverage (empty-trace refusal),
awk-coverage (hash-merge + $PPID sidecar), journal-contract (phase-2 byte
equivalence), repo-save (counted message scan), repo-scan (fragment
assembly + refuse-on-empty-read), status (committed-vs-deployed rows),
assert-test-catches (observed-to-fail made mechanical). The CI workflow's
ordering and system-roundtrip gating are recorded here as reviewed-good;
the workflow file itself is unannotated because CI YAML comments do not
survive the runner's log view, where a reviewer would look.

### CR-76 [NOTE] devtools/README.md consistent — **recorded**

Spot-checked again after this branch's marker edits; still consistent
with the tool list. Nothing to change.

### CR-84 [MED — new this branch] gawk-dependent tests fail on mawk instead of skipping — **fixed**

Found while running the suite on this container (default awk is mawk
1.3.4): two failures that read as regressions but were awk-flavor
assumptions. (1) The batch-mode `-i` sanitise test asserted redaction
unconditionally; it now sits behind the same ERE-intervals capability
probe as the older redaction block — on an incapable awk it asserts the
refusal direction (non-zero exit, files byte-identical) and skips loudly.
(2) Worse, repo-validate's awk validator judged on diagnostics matching
`syntax error|unexpected|…|unterminated` — mawk's wording for an
unterminated string is `runaway string constant`, which matches none of
them, so a genuinely broken program PASSED validation on any mawk host:
the silently-matching-nothing failure inside the validator itself. The
pattern now includes `runaway string`. Verified both ways: 582 green
under mawk (with loud skips), 602 under gawk.

## Section E — reviews/ register and evidence/ (CR-77 .. CR-79, CR-81 .. CR-83)

### CR-77 / CR-78 [GOOD+NOTE] register design; open items accurate — **kept/recorded**

The report + register + executable verify.sh triad held under reading;
open items in reviews/README.md matched reality at review time. The
register row and action entries for this branch are added in the final
phase below, which is also the live demonstration of the design being
followed.

### CR-79 [NOTE] the register's 85% is the number README should quote — **fixed via CR-01**

README's volatile numbers were removed in Section A (CR-01): the front
page now points at run-tests/coverage/CI floors instead of pasted
snapshots, which is this finding's fix generalised. Recorded here so §6's
instance is traceable to it.

### CR-81 [LOW] EX-018's index claim cell empty — **fixed**

`bt-exhibit` list/index now share one extractor that accepts the
"**Historical claim.**" retitling and keeps the marker visible in the
cell ("Historical claim: …") — which claims are current is what the index
is for. Regenerating the index fixed EX-018 AND EX-020, a second instance
nobody had noticed. exhibits/README.md regenerated by the tool, not
edited.

### CR-82 [NOTE] first-real-hang predates the session layout — **fixed**

evidence/README.md now says `20260810-072445-first-real-hang` was
hand-collected before bt-evidence existed (no MANIFEST.txt, no
state-before/after) — when it was collected, not data loss.

### CR-83 [GOOD] baseline disclosures; exhibit capture — **kept**

REVIEWED-KEEP in evidence/README.md over the 34-vs-18 incomparability
note and the synthetic-line correction. bt-exhibit's single-pass
command+output capture is already load-bearing in its index header text
("provably the command that produced the output") and marked at the
refusal site (CR-66).

Suite after Sections D+E: **all 602 invariants hold** under gawk; **582**
under mawk with loud skips (CR-84's point). repo-validate: all checks
passed, 74 of 433 files checkable.
