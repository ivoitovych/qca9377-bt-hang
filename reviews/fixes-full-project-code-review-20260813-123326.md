# Fixes for the full project code review — 2026-08-13 12:33

**Companion to:** `reviews/review-full-project-code-review-20260813-111346.md`
**Fix commit:** `4077cec` — 45 files changed, 631 insertions(+), 164 deletions(−)
**Gates after fixing:** `tests/run-tests` **67/67** (up from 65 — two new invariants) ·
`devtools/repo-validate` clean · `devtools/repo-scan . --all` **clean** (was FAILED)

Finding numbers (F1…F26) refer to the consolidated table in the review file. Each entry
states what was changed, and how the fix was verified. Items that could not be fixed from
this environment are listed in §Deferred with reasons.

---

## HIGH findings

### F1 — `uninstall.sh` forgot four installed artifacts — **FIXED + INVARIANT ADDED**
- Added `/usr/local/bin/bt-interval`, `/usr/local/bin/bt-stage2`,
  `/usr/local/bin/bt-boot-provenance`, `/usr/local/bin/lib/stage2.awk` to the FILES list.
- Added a new suite section to `tests/run-tests` — *"uninstall.sh removes everything
  install.sh installs"* — which derives the installed set from `install.sh`'s
  `install_file` calls (backslash-continuation-aware, same parser as
  `bt-verify-install`) and asserts every destination appears in uninstall's FILES array.
  One-directional on purpose: uninstall may list more (generated rules, drop-ins).
- **Verified:** the invariant reports `53 checked` and passes; before the FILES addition
  it red-flagged exactly the four paths.

### F2 — `stage2.awk` biased toward false NATURALs — **FIXED + FIXTURE EXTENDED**
- `dev_error` is now reset at the `-- Boot` separator **and** when a new timeout window
  opens (it was never reset anywhere).
- USB-layer patterns (`reset …-speed`, descriptor/address errors, `USB disconnect`) are
  now anchored to the device's own usb path, learned from its enumeration line
  (`idVendor=/idProduct=`, passed as `-v vid/pid` from `bt-stage2` via
  `BT_VID`/`BT_PID`). A foreign device's disconnect can no longer terminate — least of
  all "naturally" — a stage-1 window. Boots with no enumeration line fall back to the
  old unfiltered behaviour **and the summary discloses it** ("N boot(s) had no
  enumeration line…"), rather than presenting their classification as anchored.
  `deregistering interface driver btusb` stays unanchored deliberately (driver-level;
  detaches every controller it drives).
- `tests/stage2-invariants.data` gained four boots: a natural progression with a
  *pre-terminator* bus error; a clean reset in the boot **after** it (under the old code
  the stale `dev_error` classified that reset as "hub recovery" and its disconnect as
  NATURAL — the cross-boot leak, now a failing fixture); a window in which only a
  foreign device (`usb 1-2`) disconnects (must end as shutdown, not disconnect); and a
  trailing window-less boot so the foreign-disconnect boot is not the journal's final
  ("ongoing") boot. Assertions updated: 2 natural / 3 intervened / 2 shutdown / 7 boots /
  5 RIGHT-CENSORED labels, plus a new assertion that unanchored boots are disclosed.
- **Verified:** fixture run shows the corrected classification; the pre-fix code was
  demonstrated failing on the same fixture shape during the review.

### F3 — the timeout-spelling invariant could not fail — **FIXED, PROVEN RED, SITES FIXED, PROVEN GREEN**
- The scan in `tests/run-tests` now matches any `grep`/`count`/`cnt` invocation with a
  single- **or** double-quoted pattern containing the phrase, with or without flags,
  excluding only the canonical spelling and comment lines. The phrase is assembled from
  a variable so the scanner cannot self-match.
- Run order, deliberately: widened scan first → suite went **red on exactly the six
  sites** the review predicted (`bin/bt-evidence:62`, `:175`, `tools/bt-incident:84`,
  `tools/bt-postmortem:50`, `:100`, `tools/bt-status:48`) → sites fixed → suite green →
  `devtools/assert-test-catches` driven with a **single-quoted** violation (the form the
  old scan was blind to): *PASS: the suite caught the violation*.
- Site fixes (also closes **F8**, **F9**):
  - `bt-evidence`: `count()` upgraded to `grep -cE`; snapshot and manifest counters use
    the canonical `command( 0x[0-9a-f]+)? tx timeout`; manifest `wd_interventions` now
    counts `intervening|EARLY intervention` (the Phase-22 defect had survived in the
    manifest path); dead `tail -n +2 … >/dev/null` line removed.
  - `bt-incident`: `count()` → `-cE`; manifest `tx_timeouts` canonical.
  - `bt-postmortem`: incident clustering (`mapfile TO`) and the per-incident `n_to`
    count use the canonical pattern — a burst of `link tx timeout` (ACL supervision,
    fires on a healthy controller when a device walks out of range) can no longer
    fabricate an incident or shift `t_first`, the anchor of every Δ in the output.
  - `bt-status`: `cnt()` → `-cE`; the "HCI command timeouts" row counts what its label
    says.
- The watchdog's deliberately-broad *trigger* patterns (which do include link timeouts)
  are untouched and now carry a comment stating that breadth is a detection choice, not
  a counting error — and why the scan does not flag them (case patterns, not greps).

### F4 — real device MACs in the working tree — **FIXED (tree); history purge still pending by owner decision**
- `docs/pre-submission-checklist.md` §1 no longer spells the addresses. The
  `filter-repo` procedure now **derives** them from git history into a local,
  uncommitted file at purge time, and a warning box records how the first version of
  the section re-leaked exactly what it scheduled for purging ("the working tree is
  clean" claim removed). Step 3 of the procedure is now `repo-scan . --all`.
- `devtools/check` now runs `repo-scan . --all --quiet` as a gating step, so
  already-committed leaks can no longer ride below the staged-additions scan forever.
- **Verified:** `repo-scan . --all` — previously FAILED on both addresses — is clean.
- **Not done here:** the history rewrite itself (`git filter-repo` + force-push). That
  is the owner's §1 decision, deliberately deferred in the checklist; nothing about this
  fix blocks it, and the tree no longer undoes it.

### F5 — EX-018 leaked a tooling scratchpad path — **FIXED**
- The extraction command now shows the documented regeneration invocation
  (`bt-stage2 --cache /var/tmp/stage2.log`), with an "Edited 2026-08-13, after capture"
  note explaining what was removed and why, and stating that the output is unchanged
  and remains the verbatim product of the original run. The embedded session UUID —
  which `repo-scan --all` flagged — is gone with the path.
- **Verified:** `repo-scan . --all` clean (the UUID finding is gone).

---

## MED findings

### F6 — `bt-status` printed the refuted conclusion — **FIXED**
The early-recovery verdict now states what is measured (userspace resets ≥ +11 s failed
five-for-five; one pre-timeout reset succeeded) and explicitly says what is **not**
implied — the kernel patch fires at +0 s, a point no experiment has occupied — pointing
at `fix-proposal.md` §3a and `issues.md` BT-3.

### F7 — watchdog header/FATAL carried the superseded model — **FIXED**
Header now states the measured facts with exhibit references (five-for-five late
failures, the one early success, no natural stage-2 ever observed, the watchdog's own
reaction time as a sampling rule) instead of "~6 hours", "a USB reset RECOVERS it" and
the unhedged rail claim. The FATAL journal message and desktop notification now say a
full power-off certainly recovers it and warm-reboot recovery is untested (EX-017) —
this text flows into evidence sessions, so the hedge propagates forward automatically.

### F8, F9 — see F3 (bt-postmortem clustering; bt-evidence/bt-incident manifests).

### F10 — `trial-sco-table.awk` admitted PERTURBED rows — **FIXED**
Exclusion is now `/^(CHANGED|PERTURBED):/`, matching `trial-summary.awk`, with a comment
explaining the two prefixes. The stale "`outcome` is mandatory" header comment now names
`bt1_status`. (The existing suite's perturbed-row invariant covers the summary table;
the cross-tab now applies the same rule.)

### F11 — sanitiser placeholder aliasing — **FIXED (verification limited, see Deferred)**
`gsub(/[_-]/, ":", key)` — colon, underscore and dash spellings of one address now map
to one placeholder, restoring the documented cross-reference property at exactly the
kernel↔bluetoothd boundary. Comment records that the underscore *leak* had been fixed
while the *aliasing* had not.

### F12 — `repo-scan` blind to underscore MACs — **FIXED**
Detector widened to `[:_-]`, allowlist normalisation to
`tr 'A-F_-' 'a-f::'` — the separator form that carried the historical 20-address leak is
now visible to the last line of defence. The same widening applied to `repo-save`'s
commit-message MAC check. Email allowlist gains the one benign kernel-copyright address
found in the baseline log (exact-match, not a domain).
**Verified:** `repo-scan --all` clean; a scratch test with an underscore-separated
address in staged content is caught (and the review file's own placeholders still pass).

### F13 — `bt-usbmon` retention collapsed to a one-file ring — **FIXED (defensively)**
Rewritten to supervise tcpdump the way `bt-trace` supervises btmon: plain `-w` to a
timestamped file, poll size every `BT_USBMON_CHECK_SEC` (30 s), rotate by restarting,
prune after every rotation, TERM/INT trap. The `-C $MAX_MB -W 1` invocation is gone —
with `-C`, `-W` is a ring and tcpdump never exits, so the old loop body never advanced:
retention was one 64 MB file overwritten from the beginning, destroying older USB
history (the only stage-2 record) at every wrap. Also: `prune()` refuses to delete the
live capture file (tcpdump holds the unlinked inode, so deleting it frees nothing and
the loop would then eat every other file), and the absent-device path idles instead of
exit-0 (which under `Restart=always` respawned every 5 s forever).
**Verified:** `bash -n`; tcpdump is not installed in this environment — see Deferred for
the on-host check.

### F14 — install's open-trial guard only ran in experiment mode — **FIXED**
The guard is hoisted out of the experiment-mode branch and runs on **every**
`--apply` — mitigation mode is the default and the mode in which `bt-trial-auto` opens
a trial on every boot, so it was the mode that most needed the warning. Comment records
the 2026-08-13 trial-stock-#2 contamination as the motivating incident.

### F15 — `bt-health-report` verdict without live state — **FIXED**
§3 now checks for a live `hci` node before interpreting any counter, mirroring
`bt-status`/`bt-postmortem`: with the controller down it prints "CONTROLLER IS DOWN
RIGHT NOW" (with on-bus state) instead of letting a historical recovery print
"WORKING". Comment names this as the third instance of the Phase-11 masking class.

### F16 — `verify-restored.sh` frozen at the original 11 files — **FIXED**
File list and unit list are now **derived from `install.sh`** (same parser as
`bt-verify-install`), plus the generated udev rules, drop-ins, and stamps written
outside `install_file`; refuses with "restoration NOT verifiable" rather than reporting
a clean system if the derivation fails or comes back implausibly small; and flags
`*.disabled` files left by the `bt-mode experiment` → `uninstall` path.
**Verified:** on this container it checks 53 derived artifacts plus units and reports
only the two genuine environment gaps (no bluez installed here) — previously it would
have reported full restoration around ~30 leftover artifacts.

### F17 — withdrawn 45–66 s trajectory in mail-ready text — **FIXED**
- `docs/bug-report.md`: "The failure" now states what is measured (HCI-dead,
  USB-enumerated) with an explicit withdrawal box for the 45–66 s claim citing
  EX-016/EX-018; the methodological-caveat bullet replaced with the censoring-aware
  statement; the stage-2 paragraph re-worded to observed incidents, with the rail claim
  hedged (EX-017/EX-019).
- `docs/fix-proposal.md` §3a: the "stage 1 measured at 45–66 s" support line replaced
  with the actual timing evidence and a withdrawal note; the **suggested commit
  message** — the text most likely to be pasted verbatim into `git send-email` — no
  longer contains the withdrawn trajectory or the rail claim.
- **Verified:** the only remaining "45–66" strings in docs/ are inside the withdrawal
  notices themselves.

### F18 — session NOTES asserting refuted conclusions — **FIXED**
Both `20260810-072445-first-real-hang/NOTES.md` and
`20260811-002156-early-mode-SUCCESS/NOTES.md` open with a correction banner (matching
the style used in `docs/investigation.md`): original text kept as the record, the
withdrawn inference named, and the reader pointed at `fix-proposal.md` §3a /
`issues.md` BT-3.

### F19 — EX-019's command never ran — **ANNOTATED + GATED**
The exhibit now carries a warning box directly under its output: the captured command
exited 127, the Reading table is hand-transcribed (its actual provenance — the EX-017
`bt-boot-provenance` run — is named), and it must be re-captured on the affected
machine before being cited upstream. `bt-exhibit` now **refuses** to write an exhibit
whose command exits 126/127 (did not run ≠ ran and found nothing; other non-zero exits
stay allowed because a zero-match grep can *be* the evidence). Re-capture itself needs
the affected machine — see Deferred.

---

## LOW findings

- **F20** — `bt-actions` `tosec()` and `bt-boot-stats` `hours` now use full civil-date
  (Hinnant) arithmetic; verified 26.0 h across June 29 → July 1 (the shape that
  produced EX-003's −678.4). *Meta-note:* my first attempt broke `bt-actions` with an
  apostrophe inside the single-quoted awk program — the exact class
  `tools/lib/*.awk` exists to end; caught by `bash -n` before commit, and the comment
  now says why it must stay apostrophe-free.
- **F21** — `bt-env-history`: boot DATE from the **first** journal entry (`head -1`),
  not `-n1` (the documented last-entry trap, third tool); `tr -d` string-mangling
  replaced with an explicit `sed -E` capture (verified on the banner format).
- **F22** — `bt-boot-provenance` filters `--list-boots` to numeric rows before `tail`,
  so a short retention no longer feeds the header row into arithmetic.
- **F23** — `bt-capdiff` usage text now documents full-ISO `--since/--until` values and
  warns that a bare HH:MM:SS silently empties the lexical window.
- **F24** — `bt-exhibit` resolves the checkout relative to itself (like its siblings)
  before falling back to the historical path; refuses with a message if none found.
- **F25** — `tools/lib/timestamp.awk` applies trailing ±HH:MM offsets (normalising to
  UTC), so a session spanning a CET↔CEST transition can no longer shift every interval
  by 3600 s. Verified: DST fall-back pair → 3600.000; month-boundary regression →
  3.000; naive btmon form unaffected. Interval expressions avoided (`[0-9][0-9]`, not
  `{2}`) so the file still parses on mawk. *Meta-note:* while verifying I invoked
  `awk -f timestamp.awk 'BEGIN{…}'` and got silence — the `-f` trap this repository
  documents, demonstrated on its reviewer; re-verified through `interval.awk`.
- **F26 (fixed subset)** — README: warm-reboot claim hedged (EX-017/EX-019), stale
  `data/` repository-layout entries replaced with the real tree; `.gitignore`: dead
  `data/` rules replaced with an `evidence/**/*.raw.log` guard; `evidence/README.md`:
  capture budget updated to the shipped 400-file/15 GB settings, sessions table marked
  partial, baseline-vs-EX-003 counting reconciliation added; `devtools/README.md`:
  `check` and `assert-test-catches` added to the table; `docs/investigation-plan.md`:
  the residual "fail at probe" corrected to "at HCI open"; `bt-diagnose` and
  `bt-postmortem` user-facing rail claims hedged; `bt-timeline` no longer emits
  journalctl's "-- No entries --" as a sorted pseudo-event; `bt-verify-install`'s udev
  semantic check matches the `idVendor}=="…"` attribute form, not the VID anywhere in
  the file; `bt-trial`'s no-SCO fallback text is now reachable (record-presence test,
  not file-emptiness); EX-003 annotated for its impossible negative HOURS rows; both
  trial-stock-2 session NOTES filled in with what happened and what came of it.

---

## Deferred, with reasons

| Item | Why deferred |
|---|---|
| Git-history MAC purge (F4's second half) | Owner's explicit checklist decision ("do it deliberately, on a day with time to check the result"); requires force-push to the public repo. The tree-side re-leak is fixed and `repo-scan --all` now guards it. |
| EX-019 re-capture | Needs the affected machine (journal + installed tools). The exhibit is annotated and the `bt-exhibit` gate prevents recurrence. |
| `bt-usbmon` on-host check (F13) | tcpdump absent in this environment. On the machine: `ls /var/log/bt-health/usbmon/` — one file per boot confirms the old ring behaviour; many timestamped files after this fix confirms rotation. `bash -n` clean; logic mirrors the proven `bt-trace` supervisor. |
| Sanitiser aliasing runtime test (F11) | This environment's awk is mawk, on which `sanitize-logs.sh` correctly *refuses to run* (its interval-expression guard — observed firing). The change is a one-charset `gsub`; run the tool's own verification on the target (gawk) machine. |
| `fix-proposal.md` section renumbering (F26) | Would break every `§3a`/`§5a` cross-reference in docs, exhibits, HISTORY and commit messages for a cosmetic gain. |
| `51-*` udev remove-rule leading-zero PRODUCT edge (F26) | Only affects non-default VID/PIDs with leading zeros via the `BT_VID` override path; needs a hardware test to get the kernel's PRODUCT formatting right rather than guessing a sed. Noted in the review; left as documented behaviour. |
| `bt-boots` silently skipping kernel-less boots (F26) | Cosmetic reporting choice; changing it alters the table shape consumers may parse. |
| DST-mixed naive/offset comparison (F25 residue) | No caller compares a btmon-naive timestamp against a journal-offset one; documented at `iso_secs()` rather than adding speculative complexity. |

## Verification summary

| Gate | Before fixes | After fixes |
|---|---|---|
| `tests/run-tests` | 65/65 (with two blind invariants) | **67/67**, including the two new invariants; intermediate red runs proved both new checks and the widened scan can fail |
| `devtools/repo-validate .` | clean | clean (58 of 192 files checkable) |
| `devtools/repo-scan . --all` | **FAILED** (2 real MACs, 1 UUID, 1 email) | **clean** |
| `devtools/assert-test-catches` (single-quoted timeout violation) | n/a — old scan blind | **PASS: the suite caught the violation** |
| stage2 fixture (cross-boot leak, foreign disconnect) | misclassified NATURAL | correctly intervened/shutdown, disclosed when unanchored |

Findings **not** addressed anywhere above: none — every F-numbered finding is either
fixed or in the Deferred table with a reason.
