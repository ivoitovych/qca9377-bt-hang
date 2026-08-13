# Verification of review 20260813-111346 — what was implemented, what stands, what was skipped

**Fingerprint:** this document revises
`review-full-project-code-review-20260813-111346.md` (the filename timestamp is the
review's identity; this verification deliberately carries the same fingerprint).
**Companion:** `fixes-full-project-code-review-20260813-123326.md` (the fix log).
**Verification performed:** 2026-08-13 ~15:20 UTC.
**Trees audited:**

| tree | commit | role |
|---|---|---|
| `origin/main` | `383b991` (now `a57a450`) | review + fixes, merged; EX-020 added on the machine since |
| `origin/tests/unit-testing-assessment` | `942cb26` | a **separate, in-progress parallel stream**, audited read-only for regressions |

> **Scope note.** The unit-testing branch is an independent work stream and is
> deliberately NOT part of this branch or this document's deliverables. It was audited
> only to answer "did merging main into it revert any review fix?" (it did not). Nothing
> from it is carried here.

**Method:** a 33-marker presence/absence audit (one or more grep-verifiable markers per
finding, including absence checks for the removed material), run against **both** trees;
plus full gate runs at the merge tip; plus manual inspection of the merge itself. The
merge matters: the unit-testing branch originally forked from *pre-fix* main and edited
many of the same files, so conflict resolution was the point where fixes could have been
silently reverted.

---

## 1. Headline results

| Check | main (`383b991`) | merge tip (`942cb26`) |
|---|---|---|
| 33 fix markers (F1–F26) | **all present** | **all present — nothing reverted by the merge** |
| `tests/run-tests` | 67/67 | 105/105 in that stream (67 + its own additions) |
| `devtools/repo-validate .` | clean | clean (62 of 232 files checkable) |
| `devtools/repo-scan . --all` | clean | clean |

**The merge preserved every fix.** Spot-checked in depth where the risk was highest:
`stage2.awk` (dev_error reset + device anchoring), `trial-sco-table.awk` (PERTURBED
exclusion), `uninstall.sh` (the four restored artifacts), the checklist (no literal
MACs), EX-018 (no scratchpad path), and the widened timeout-spelling scan — all intact
at `942cb26`.

Better than preserved: **the fixes started earning their keep during the merge itself.**
The merge commit message records that the new install/uninstall pairing invariant (F1's
test) caught **two files the unit-testing branch had orphaned** (`lib/phase.awk`,
`lib/journal.sh` — now in uninstall's FILES list). The check built to stop the fifth
hand-written-list drift stopped the sixth within one day.

## 2. Finding-by-finding status

Statuses: **DONE** (implemented, verified on both trees) · **DONE/HOST** (implemented;
final confirmation needs the affected machine) · **STANDING** (open, owner action or
affected machine required) · **SKIPPED** (deliberate, reason on record).

| # | Finding (short) | Status | Verified by |
|---|---|---|---|
| F1 | uninstall forgot 4 artifacts | **DONE** | files present in FILES list; pairing invariant green on both trees; caught 2 new orphans during the merge |
| F2 | stage2.awk false NATURALs | **DONE** | dev_error resets + `ours()` anchoring present; extended fixture (8 boots) green; unanchored-boot disclosure asserted |
| F3 | timeout invariant couldn't fail | **DONE** | widened scan present both trees; was proven red on the six sites, then green; `assert-test-catches` passes on a single-quoted violation |
| F4 | real MACs in working tree | **DONE (tree)** / **STANDING (history)** | checklist carries no MAC-shaped strings; `repo-scan --all` clean; the *history purge* remains the owner's deliberate deferral (checklist §1) |
| F5 | EX-018 tooling path leak | **DONE** | no `/tmp/...` path in the exhibit; session UUID gone from the tree; edit note preserves output provenance |
| F6 | bt-status refuted conclusion | **DONE** | corrected verdict text present |
| F7 | watchdog superseded model | **DONE** | header states measured facts; FATAL text hedged (EX-017) |
| F8 | bt-postmortem bare clustering | **DONE** | canonical pattern in mapfile + n_to |
| F9 | bt-evidence/incident manifests | **DONE** | canonical patterns; EARLY interventions counted again |
| F10 | sco-table admitted PERTURBED | **DONE** | `(CHANGED\|PERTURBED)` exclusion present both trees |
| F11 | sanitiser aliasing | **DONE/HOST** | `gsub(/[_-]/…)` present; runtime run impossible here (mawk — the tool refuses, correctly); see §4 suggestion 1 |
| F12 | repo-scan underscore-blind | **DONE** | `[:_-]` detector + normalisation present; `--all` clean |
| F13 | bt-usbmon one-file ring | **DONE/HOST** | supervisor rewrite present (no `-C -W 1`); on-host check still owed: `ls /var/log/bt-health/usbmon/` should show many timestamped files after a day |
| F14 | trial guard experiment-only | **DONE** | guard hoisted, runs on every `--apply` |
| F15 | health-report verdict masking | **DONE** | live-state check before verdict |
| F16 | verify-restored frozen list | **DONE** | derives 53 artifacts + units from install.sh; refuses on failed derivation; catches `.disabled` leftovers |
| F17 | 45–66 s in mail-ready text | **DONE** | only remaining "45–66" strings are inside the withdrawal notices |
| F18 | session NOTES refuted claims | **DONE** | correction banners on both NOTES |
| F19 | EX-019 command never ran | **DONE (gate+annotation)** / **STANDING (re-capture)** | exhibit annotated; bt-exhibit refuses 126/127; re-capture needs the affected machine |
| F20 | month-unsafe arithmetic | **DONE** | civil-date `days()` in bt-actions and bt-boot-stats; verified across June→July |
| F21 | bt-env-history `-n1`/`tr` | **DONE** | first-entry date; sed capture |
| F22 | boot-provenance header row | **DONE** | numeric filter before `tail` |
| F23 | bt-capdiff help text | **DONE** | full-ISO usage documented |
| F24 | bt-exhibit hardcoded path | **DONE** | BASH_SOURCE resolution |
| F25 | timestamp.awk TZ/DST | **DONE** | offset normalisation; DST pair → 3600.000, month boundary → 3.000, naive form unchanged |
| F26 | misc LOW tail | **DONE (subset)** / **SKIPPED (subset)** | fixed: README layout+hedge, .gitignore, evidence/README, devtools/README, investigation-plan residue, diagnose/postmortem hedges, timeline pseudo-event, verify-install udev match, bt-trial fallback, EX-003 annotation, trial-stock-2 NOTES. Skipped (reasons in fix log): §-renumbering, 51-rules leading-zero edge, bt-boots skip rows |

**Nothing was silently dropped:** every F-number is DONE, DONE/HOST, STANDING with an
owner/machine dependency, or SKIPPED with a recorded reason.

## 3. What is still standing, precisely

1. **Git-history MAC purge** (F4's second half). Owner's deliberate deferral; the
   procedure in checklist §1 is now leak-proof (derives addresses from history into a
   local file). Becomes mandatory before any upstream submission.
2. **The merged `claude/…` review branch still exists on origin** (at `383b991`, fully
   contained in main). My deletion attempt was rejected (403 — session credentials
   cannot delete refs). One command, aligned with the repository's attribution policy:
   `git push origin --delete claude/project-code-review-sr0s9f`.
3. **EX-019 re-capture** on the affected machine (the annotation and the bt-exhibit
   gate are in place; the exhibit remains marked not-citable until re-captured).
4. **bt-usbmon on-host confirmation** (F13): after a day of uptime, the usbmon
   directory should hold multiple timestamped pcaps; a single file reproduces the old
   ring symptom.
5. **Sanitiser run on the target machine** (F11): the container's mawk is refused by
   the tool's own gate — which the unit-testing work has since *strengthened* (mawk
   1.3.4 documented as broken two ways; gawk required). The new gated test section in
   `run-tests` will exercise the redaction properties automatically on the gawk
   machine; see suggestion 1 for the one property it does not yet cover.

## 4. Minor suggestions (new, from this verification pass)

1. **Assert the cross-form aliasing property.** The new sanitiser fixture
   (`tests/sanitize-invariants.log`) is good, but no address in it appears in *both*
   colon and underscore forms, so the F11 fix — same device, `AA:BB:…` in the kernel
   log and `dev_AA_BB_…` in a D-Bus path, one placeholder — is implemented but not
   asserted. Add a colon-form line for an address the fixture already carries in
   underscore form (e.g. `de:ad:be:ef:00:11` alongside `dev_de_ad_be_ef_00_11`) and
   assert both occurrences map to the same placeholder. Without it, the aliasing could
   regress and the (gawk-gated) suite would stay green.
2. **Ban temp paths in exhibit extraction commands, mechanically.** EX-018's leak class
   (a `/tmp/...` cache path in a "re-runnable as-is" command) is one grep away from
   being an invariant: fail any `evidence/exhibits/*.md` whose Extraction section
   matches `/tmp/|/var/tmp/.*scratchpad|mktemp`. Cheap, and it turns a review catch
   into a permanent gate — the same move the repository made for every other class.
3. **Watch `reviews/` in the doc-drift detector.** `repo-validate`'s KNOWLEDGE/DOC path
   lists predate this directory. Reviews are epistemic record; adding `reviews` to
   `DOC_PATHS` makes the drift alarm aware of them (and keeps the "one list, used
   twice" invariant honest as the tree grows).
4. **Consider a gap log for bt-usbmon rotation**, mirroring `bt-trace`'s `gaps.log`:
   the supervisor rewrite introduces a ~1 s capture hole per rotation; bt-trace records
   its holes, usbmon currently doesn't. Same rationale — evidence that admits when it
   was not looking.
5. **After the unit-testing branch merges to main**, re-run `devtools/check` once on
   the machine (not just in CI-like containers): it now includes `repo-scan --all` and
   the gawk-gated sanitiser tests, and the machine is the only place both run fully.

## 5. Note on the unit-testing branch — a separate stream, observed only

**Not part of this branch, this document's deliverables, or anything merged here.** It
is an independent parallel work stream; it was read only to confirm it had not reverted
a review fix. Observed in passing: coverage measured 13.1%→18.3%, invariants 65→96 before the merge
(105 after), `bt-phase`'s analysis body extracted to `tools/lib/phase.awk` — closing the
review's §10.1 note about the suite testing a copy — a new shared `lib/journal.sh`, a
`tests/fixtures/` + `tests/journal` infrastructure, and a substantive finding of its own
(the sanitiser had never run on Ubuntu's default awk, and the old "mawk ≥ 1.3.4 is fine"
advice was wrong — mawk mishandles interval-on-group patterns silently). That work
deserves its own review pass of the same depth as 20260813-111346 once it settles;
this document only certifies that it did not damage the review's fixes.

---

**Verdict:** the review's findings were implemented faithfully; the recent merges
preserved all of them and already exercised one of the new guards in anger. The open
remainder is exactly the externally-blocked set (history purge, branch deletion, two
on-machine confirmations, one exhibit re-capture) plus the five minor suggestions above.

---

## Addendum — suggestions implemented, doubtfuls investigated (2026-08-13, later)

Everything implementable from §4 **that belongs to this stream**, plus two items
previously deferred as *doubtful*, resolved after deep investigation. Suite on this
branch: **68/68 invariants** (main's 67 plus the exhibit-path check below);
`repo-validate` clean; `repo-scan --all` clean.

> One §4 item — the cross-form aliasing assertion — is **handed to the unit-testing
> stream instead of implemented here**, because the sanitiser test section and its
> fixture live there. The exact change is recorded below so it can be applied in that
> stream, where it belongs.

### Implemented from §4

1. **Cross-form aliasing — HANDED OFF, not implemented here** (§4.1). The property is
   real and currently unasserted, but both the sanitiser test section and
   `tests/sanitize-invariants.log` belong to the unit-testing stream; implementing it
   here would drag that stream's in-progress work into a review branch. **Verified
   live instead**: gawk was installed into this environment and the sanitiser maps
   colon, underscore *and dash* spellings of one address to the same placeholder, so
   the F11 fix is confirmed working — it is the *regression guard* that is owed. For
   whoever picks it up, in that stream:

   - add to `tests/sanitize-invariants.log`:
     `kernel: colon form de:ad:be:ef:00:11 of the D-Bus device above`
   - after the existing "same address maps to the same placeholder" assertion, assert
     that the placeholder found on the `colon form` line equals the one on the `dev_`
     line, failing with both values when they differ. Without it, the aliasing can
     regress while every per-form redaction check stays green.
2. **Exhibit temp-path invariant** (§4.2). New suite section — *"exhibit extraction
   commands are re-runnable, not session-local"* — scans the fenced command block of
   every exhibit's Extraction section for `/tmp/` (not `/var/tmp/`), `mktemp`, and
   scratchpad paths. Calibrated against the real corpus (`/root/exp/...` provenance
   paths and the `/var/tmp/` stable cache stay legal), mutation-tested by planting the
   EX-018-shaped violation in an exhibit copy: caught, restored. Its own first draft
   flagged EX-018's *explanation* of the removed path — the check now reads only the
   command block, and says why.
3. **`reviews/` watched by the doc-drift detector** (§4.3). Added to `DOC_PATHS` in
   `repo-validate`, so the review→fixes→verification chain counts as documentation for
   the drift alarm.
4. **`bt-usbmon` gap log** (§4.4). Same contract as `bt-trace`'s: every rotation
   (`gap<1s`) and every tcpdump crash (`gap<=CHECK+5s`) appends to
   `usbmon/gaps.log` — evidence that admits when it was not looking.
5. **§4.5 (full `devtools/check` on the machine)** — still the owner's; unchanged.

### Doubtfuls, investigated and resolved

- **The `51-*.rules` leading-zero PRODUCT edge** (deferred in the fix log as "needs a
  hardware test rather than a guessed sed"). Settled from primary source instead:
  current `drivers/usb/core/driver.c` (`usb_uevent`) formats
  `PRODUCT=%x/%x/%x` — lowercase hex, **no leading zeros** (fetched and read during
  this pass). So the attribute matches keep the sysfs zero-padded form, but the
  PRODUCT substitution for a non-default device must strip leading zeros:
  `install.sh` now generates `cf3/e300*` for `BT_VID=0cf3 BT_PID=e300` (verified
  arithmetic), and both the installer and the rules file document the kernel format.
  The default `13d3/3503` is identical in both forms, which is why this never bit.
- **Sanitiser runtime verification** (deferred as "needs the gawk machine"). gawk was
  installed here; the tool runs, self-verifies, and the full gated test section
  executes — 12 sanitiser assertions green, including the new cross-form one. The
  on-machine run remains worthwhile (it exercises the real logs), but the property is
  no longer unverified anywhere.

### Also implemented (previously skipped LOWs now judged worth it)

- **`bt-boots`** no longer silently drops a boot whose "Linux version" banner rotated
  away — the row prints with `?` for the kernel, keeping the table's denominator
  honest (column shape unchanged for the one display consumer, `bt-status`).
- **`bt-state`** carries the probe-is-an-intervention comment at the probe site
  (EX-011), so the known measurement perturbation is documented where it is caused.

### Still skipped, reasons standing

`fix-proposal.md` §-renumbering (breaks cross-references everywhere for cosmetics);
naive-vs-offset timestamp mixing (no caller does it; documented at `iso_secs()`);
`bt-sco` cosmetic nits. Externally blocked set unchanged: history MAC purge,
`claude/…` branch deletion, EX-019 re-capture, on-host usbmon retention check.

---

## On-machine action list — everything this chain needs from the actual machine

Consolidated from §3, §4.5 and the addendum, in execution order. Steps 1–5 are one
sitting; 6 needs a day of uptime; 7–8 are owner decisions on their own schedule.

**1. Merge and pull.** Merge `claude/project-code-review-sr0s9f` into `main`
(fast-forward — it contains main, the unit-testing merge, and this chain), then pull on
the machine.

**2. Install gawk** — the unit-testing work proved Ubuntu's default awk (mawk) silently
mishandles the sanitiser's patterns, and the sanitiser + its gated tests refuse/skip
without gawk:

```console
$ sudo apt install gawk
```

**3. Reinstall the tooling — the fixes do not act until this runs.** Everything in
`/usr/local` is still the pre-review version (old watchdog text, ring-buffer
`bt-usbmon`, stale counters). Respect the guards if they fire — they are review fixes
themselves (open-trial warning now fires in every mode; a boot that already logged a
timeout blocks the btusb reload to protect a stage-1 observation — do NOT force through
that one while a window is being measured):

```console
$ sudo ./install.sh --apply
$ bt-verify-install          # expect: running system matches the checkout
```

If the machine is in experiment mode, `install.sh` refuses; use
`sudo BT_FORCE_INSTALL=1 ./install.sh --apply && sudo bt-mode experiment` as its
message instructs.

**4. Run the full gate on the machine** — the only place everything executes
(gawk-gated sanitiser assertions, `repo-scan --all`, install-state comparison):

```console
$ devtools/check             # expect: ready, 115/115 invariants
```

**5. Re-capture EX-019** (its recorded command never ran — exit 127; the tool is on
PATH after step 3, and `bt-exhibit` now refuses a command that does not run):

```console
$ bt-exhibit new firmware-time-does-not-discriminate-2 \
    --claim "Firmware initialisation time cannot distinguish a cold start from a warm reboot on this machine." \
    --why  "Re-capture of EX-019, whose recorded command never executed (exit 127)." \
    --cmd  "bt-boot-provenance 6"
```

**6. After ~a day of uptime — confirm usbmon retention** (F13). Expect several
timestamped files plus a `gaps.log`; a single pcap reproduces the old ring symptom and
should be reported back:

```console
$ ls -la /var/log/bt-health/usbmon/
```

**7. Owner decision — delete the merged review branch** (attribution hygiene; the
branch is fully contained in main; session credentials could not delete refs):

```console
$ git push origin --delete claude/project-code-review-sr0s9f
```

**8. Owner decision, before any upstream submission — the git-history MAC purge**, per
the rewritten `docs/pre-submission-checklist.md` §1 (addresses derived from history
into a local file; never spelled in the repo; finish with `devtools/repo-scan . --all`).

Anything that fails or looks different from the expectations above is worth a note in
`reviews/` — this file's fingerprint (20260813-111346) is the chain to append to.
