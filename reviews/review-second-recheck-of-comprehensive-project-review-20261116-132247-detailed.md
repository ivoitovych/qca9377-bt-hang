# Detailed verification behind the second recheck of 2026-11-16

Each part's verification of `main` at `bbec102f` against the maintainer's list, as written.
The main page is [`review-second-recheck-of-comprehensive-project-review-20261116-132247.md`](review-second-recheck-of-comprehensive-project-review-20261116-132247.md). The CO-02 part is the last section.

---

# Part: code-bin-install

## Recheck 2: code-bin-install (the checkout of main tip bbec102f)
Maintainer items 9 (guard) and 12/11: item 9's `guard()` / runtime-mgmt-test.sh is not in my part (not checked). Items 11 and 12 are, below.

### uninstall.sh btusb reload / restore+changes docs (was PARTLY)
- verdict: FIXED
- now: uninstall.sh:285-294 never reloads; docs/restore-original-state.md:88 "`btusb` is never reloaded"; docs/changes-applied.md:94-96 historical record marked "FORBIDDEN since", :205 "Do NOT reload btusb". Trivial leftover: restore-original-state.md:65 "restores `enable_autosuspend=Y`" (applies at next boot).
- what is left: nothing material.

### bt-raw-archive.service hard-coded path (was PARTLY)
- verdict: FIXED (as designed: conditional)
- now: systemd/bt-raw-archive.service:15 still /root/exp/...; docs/install.md "installed and enabled only from the checkout its unit's ExecStart names"; docs/tooling-index.md:93 "tools/bt-verify-install expects it on the same condition".
- what is left: nothing.

### bt-journal-files not installed/removed (was NOT ADDRESSED)
- verdict: FIXED
- now: install.sh installs tool + 3 units when zstd exists (`if command -v zstd`, JOURNALFILES) and enables timer and shutdown unit; uninstall.sh FILES has all four, UNITS has both enabled units; tooling-index:85 "installed ... by install.sh together with its three units, when zstd is there".
- what is left: nothing.

### Event snapshot unit gets no drop-in (was NOT ADDRESSED)
- verdict: FIXED
- now: install.sh:389-391 SNAPEV_DROPIN written (:406-409) and dry-run line; uninstall.sh FILES+DIRS and verify-restored.sh:86 list it.
- what is left: nothing (bt-usbmon.service still gets no device env, minor).

### bt-usbmon not root-only (was NOT ADDRESSED)
- verdict: FIXED
- now: bin/bt-usbmon:57,59 `umask 077` / `chmod 0700 "$DIR"`.
- what is left: nothing.

### modprobe dyndbg vs bt-dyndbg / experiment mode (was NOT ADDRESSED)
- verdict: FIXED (documented, behaviour unchanged)
- now: etc/modprobe.d/btusb-qca9377.conf:31-44 says oneshot does NOT rerun on reload and `bt-mode experiment` moves the file aside; tools/bt-mode:29-35 header states the exception.
- what is left: nothing.

### --tools-only writes first-install stamp (was NOT ADDRESSED)
- verdict: NOT ADDRESSED
- now: install.sh stamp block ("# --- first-install stamp", under `if (( APPLY ))`) has no TOOLS_ONLY test.
- what is left: skip or document.

### "every file installed is NEW" vs generated files (was NOT ADDRESSED)
- verdict: NOT ADDRESSED
- now: 10-device.conf (both) and the 50/51 rules still written by redirect with no .pre- copy (install.sh:~395-445).
- what is left: back up or qualify claim.

### two vs three demonstrations (was PARTLY)
- verdict: FIXED
- now: "two" everywhere: docs/tooling-index.md:240, docs/fix-proposal.md:9, docs/investigation-plan.md:55 and :723, install.sh:11, README.md:311.
- what is left: nothing.

### docs/install.md stale references (was NOT ADDRESSED)
- verdict: FIXED
- now: docs/install.md step 3 now says bt-verify-install names `--tools-only`; step 7 "The kernel module is untouched ... values are whatever the machine had"; "What it installs" has the authority paragraph (about seventy files, eleven units; I counted 74 install_file calls and 11 `enable --now` lines).
- what is left: nothing.

### changes-applied.md "complete set" (was NOT ADDRESSED)
- verdict: FIXED
- now: docs/changes-applied.md:169 heading "... OF THE 2026-08-10 INSTALL (not today's)" plus warning. (Dated sections still stop at 2026-08-13; the warning points to uninstall.sh.)
- what is left: nothing.

### restore-original-state.md contradicts uninstall; leftover data (was NOT ADDRESSED)
- verdict: PARTLY
- now: fixed: :46 now describes .pre-qca9377-bt-hang and .disabled. Not fixed: §3 (:99-105) still names only metrics.tsv as kept data; /var/log/bt-health/{trace,capture,usbmon}, /root/bt-journal-archive still unlisted.
- what is left: widen §3.

### bt-evidence HCI probe (was NOT ADDRESSED)
- verdict: FIXED
- now: bin/bt-evidence:14-16 and snapshot_state: `alive=unprobed` unless `BT_EVIDENCE_PROBE` == 1.
- what is left: nothing.

### bt-verify-install false all-clear (was NOT ADDRESSED)
- verdict: PARTLY
- now: fixed: "missing in repo" now `✗ MISSING IN CHECKOUT` counted in nosrc and exits 1. Remaining: bt-trace/bt-sco/bt-capdiff/bt-usbmon pairs (conditional on btmon/tcpdump) and `--no-metrics` units are still always expected (only raw-archive and zstd items got conditions).
- what is left: condition those too.

### install.sh -h / tools-only banner (was NOT ADDRESSED)
- verdict: PARTLY
- now: fixed: install.sh:55 `sed -n '2,/^$/p'` (whole header; same in bt-mode, bt-evidence). Remaining: install.sh:367 "Installing anyway; the watchdog arms itself at boot." and :819 "# expect N" still printed under --tools-only.
- what is left: conditional text.

### BRIEF "all 3 skip now" dates (was NOT ADDRESSED)
- verdict: NOT ADDRESSED
- now: BRIEF.md:427-431 "Until 2026-09-16 ... all 3 skip now" vs install.sh 08-19/09-01/09-18 comments.
- what is left: lead's call.

### Minor orphans (was NOT ADDRESSED)
- verdict: PARTLY
- now: fixed: uninstall.sh:108-109 comment explains 20-verbose.conf. Not fixed: systemd/bt-usbmon.service:18 `BT_USBMON_BUS=3` (bin/bt-usbmon comment "recorded at install time"); journald conf:9 "88 GB free".
- what is left: trivial.

### New defect 1 (recheck1): raw-archive condition not in verifiers
- verdict: FIXED
- now: tools/bt-verify-install RAW_HERE logic ("not expected from this checkout") and the UNITS filter.

### New defect 2 (recheck1): restore doc :84 described reload
- verdict: FIXED
- now: restore-original-state.md:88-92.

## Maintainer claims (item 11, 12)
- "install.sh installs bt-journal-files and its three units where zstd exists" CONFIRMED (install.sh `command -v zstd`, 4 install_file).
- "the event unit gets the device drop-in" CONFIRMED (install.sh:389, 406).
- "uninstall.sh and verify-restored.sh remove them" CONFIRMED (uninstall FILES/UNITS/DIRS; verify-restored derives from install.sh, plus the explicit event drop-in at :86).
- "bt-verify-install does not demand the raw-archive unit from another checkout" CONFIRMED.
- "bt-evidence sends no HCI unless BT_EVIDENCE_PROBE=1" CONFIRMED.
- "bt-usbmon writes 0700/0600" CONFIRMED (umask 077 -> 0600; chmod 0700).
- "verify-restored.sh and uninstall.sh needed no change for N-09" CONFIRMED.
- Item 12: "two demonstrations plus EX-026 in plan, proposal, tooling index" CONFIRMED; "install guide says what is installed and how to verify" CONFIRMED (authority paragraph; verification stays bt-verify-install in step 6).
- "reload described only as a marked historical record" CONFIRMED (changes-applied :94-96, :205-206, restore doc :136).

## New defects introduced by this round
- tools/verify-restored.sh:128 `N) bad "... still the mitigation value"` is unchanged, while uninstall.sh now never reloads btusb and docs/restore-original-state.md:84,88 say `N` is expected until the next boot. The documented sequence (uninstall --apply then verify-restored.sh) now exits 1 on a correct uninstall every time the module is loaded; should be `info` (as power/control "on" is).
- bt-verify-install skips conditional items only for raw-archive and zstd, so the same "NOT INSTALLED where no install could fix it" remains for btmon/tcpdump/--no-metrics (see above); the new `nosrc` branch also prints the "To update the files: --tools-only" advice for a defect of the checkout that no deploy fixes.

---

# Part: code-tools-a

## recheck2 code-tools-a — main tip bbec102f (checkout the checkout of main)

### Maintainer item 7 / bt-backup-journal prefix + bt-archive --replace + sweep (High / Medium)
- verdict: FIXED
- now: tools/bt-archive:362-387 the count runs unconditionally (`shopt -s nullglob; OLD_N=0; for old in "$DEST_ABS"/boot-"${BID:0:8}".export.*`), skips `*.prefix`/`*.partial`, counts with the extension's own decompressor, `on=-1` when no decompressor -> `OLD_N=$(( SRC_N + 1 ))` -> refusal "NOT replaced; the new export is kept as $SIDE". Sweep (bt-archive ~408) is after it. Uncountable archive: never swept (test run-tests:15866-15870 with a .lz4). `.prefix`: skipped in the count, not touched on refusal (the `.prefix` rm/creation is after the guard). Usage: bt-archive:9-11 and `sed -n '2,11p'` list `--replace`. Tests: run-tests:15805-15880 (same ext, other ext, uncountable, equal-length control, --help): the maintainer's "4 checks" is 5-6 assertions; claim CONFIRMED in substance.
- what is left: see "New defects" (corrupt old archive counts 0; repeated refusal loop with a `.prefix` marker; N-11).

### Maintainer item 7 claim: "--replace is in the usage"
- verdict: CLAIM CONFIRMED
- now: tools/bt-archive:9 "#   bt-archive <boot-index> --replace   re-archive a boot that already has an"; help range 2,11.
- what is left: nothing

### BRIEF.md description of bt-trial (directory overwritten / build=stock)
- verdict: FIXED
- now: BRIEF.md:880-884 "opens a new trial with the same number; ... **Corrected 2026-11-16:** `tools/bt-trial` ... sets an existing directory aside as `trial-NN.unclosed-<time>`"; BRIEF.md:829-830 "`bt-trial` labelled them `build=stock` when no other build is named ... qualified here". Note BRIEF.md:882 attributes the set-aside to "since 2026-11-15, review item T-09"; autostart already set aside before (it existed at a8d0eb45); the 11-15 change added it to manual `start`.
- what is left: nothing material (the T-09 date applies only to `start`).

### Close paths that send an HCI command (header)
- verdict: FIXED
- now: tools/bt-trial:14-22 "MANUAL `hang`, `ok` AND `start` SEND HCI ... `start` once, `ok` twice ..., `hang` once". Matches code: start 376, ok 826 + resp_after 987, hang only resp_after 987.
- what is left: nothing

### hci_alive's rc 2 read as dead
- verdict: FIXED
- now: tools/bt-trial:138-139 `command -v hciconfig ... || return 2` / `timeout 6 hciconfig ... || return 1`; start 376-383 (only 1 refuses), autostop 488-492 (only 1 -> hang), close 822-828 (`_alive == 2` -> ended_unprobed), 986-989 (`2) resp_after=unprobed`). Claim in checks doc CONFIRMED.
- what is left: nothing

### Failed trial with bt1_status=not_observed counted as survival (previously FIXED)
- verdict: FIXED (spot-check, no regression)
- now: tools/lib/trial-summary.awk fnx block still present; wording at ~199-203 now generic ("the older closer probed late; docs/STATUS.md names the trials").
- what is left: nothing

### bt-trial header/usage text stale or truncated
- verdict: FIXED
- now: tools/bt-trial:9 "bt-trial abort [--discard]  close without a row; the directory is kept"; status/autostart/autostop listed (11-14); usage `sed -n '2,22p'` (1301) ends at the HCI paragraph (line 22); banner `protocol | sed -n '11,22p'` (407) checked: prints steps 2-7 exactly.
- what is left: nothing

### bt-trial header comment says bt-state sends raw HCI
- verdict: FIXED
- now: tools/bt-trial ~930 "(bt-state and bt-status send nothing unless given --probe)". Wording: "That one is operator- or script-driven and leave no dedicated journal entry" (grammar slip, trivial).
- what is left: nothing

### bt-snapshot header: autostop probes at every shutdown
- verdict: FIXED
- now: tools/bt-snapshot:23-27 "historically: until 2026-09-19 its hci_alive() issued ... `autostop` is passive now and probes only under BT_TRIAL_PROBE=1."
- what is left: nothing

### bt-trial-audit claims independent detectors
- verdict: FIXED
- now: tools/bt-trial-audit:19-30 "IT KEEPS ITS OWN COPY OF THE DETECTORS ... TODAY THE REGEXES ARE IDENTICAL"; tools/bt-trial:359-363 same admission. The duplication itself remains, but the false claim is gone.
- what is left: nothing (optional: a single source for the patterns)

### Maintainer item 10 / bt-trial-audit unreadable window reads as "agrees"
- verdict: FIXED
- now: tools/bt-trial-audit ~251-258 `wrc=$?` after `W=$(bt_journal_lines ...)`; `(( wrc >= 2 ))` -> "UNRESOLVED — the journal window of boot $b could not be read completely", exit 2 via the unresolved counter. tools/lib/journal.sh:194-214 bt_journal_lines returns 2 for jr>=2 or jr==1 with non-empty stderr, else the grep status. `W=$(...); wrc=$?` correctly takes the substitution status. Remaining small point: a recorded `perturbed=unknown` is still reported as DISAGREES (audit compares to none/...; unchanged).
- what is left: treat recorded `unknown` as "not auditable" instead of a disagreement (Low).

### lib/journal.sh fast path discards per-file reader failures
- verdict: PARTLY
- now: fixed inside the fast path: tools/lib/journal.sh ~280 (`[[ -e "$f" && ! -r "$f" ]] && echo "$f" >> "$tmp/unreadable"`), per-file `.rc` files, `failed=1` and `return 2` with a stderr message. Remaining: only bt_journal_lines (and through it the audit) looks at status 2. bt_journal_count (journal.sh:169-176) and bt_journal_first are unchanged (`2>/dev/null | grep -cE ... || true`), and every direct `bt_journal ... | grep` caller still sees a partial read as a normal answer; the new stderr message goes to /dev/null in those helpers. Maintainer's "journal.sh ends in status 2 on any failed or unreadable file" is true of bt_journal_kernel_fast/bt_journal, not of the count/first helpers.
- what is left: make bt_journal_count/first propagate status 2 (or print an "unread" marker) so bt-state/bt-snapshot/bt-archive --check do not report a partial count as complete.

### bt-trial close: unbudgeted journalctl reads before the row
- verdict: NOT ADDRESSED
- now: tools/bt-trial:782 `journalctl -u bt-hang-watchdog ...`, 1032 `journalctl -b -1 -n 400`, 1056 `journalctl --list-boots`; no timeout (still needs-check on cost).
- what is left: budget them or move after the row.

### bt-trial probes/aborts/t_probe/prev_shutdown reads ignore failures
- verdict: NOT ADDRESSED
- now: unchanged `journalctl ... 2>/dev/null | grep -c ... || true` for probes/aborts.
- what is left: record `?` when the read failed or journal_files=0.

### bt-trial journal seam bypass (observation)
- verdict: NOT ADDRESSED
- now: unchanged by design (bt-trial direct journalctl calls).
- what is left: nothing required.

### bt-archive --replace / sweep, usage
- verdict: FIXED
- now: see item 7.
- what is left: nothing

### bt-snapshot hardcodes USB path 3-3
- verdict: FIXED
- now: tools/bt-snapshot:129-140 resolves USBDEV by VID/PID; PRESENT 238-240 `if [[ -n "$USBDEV" ]]; then PRESENT="yes" elif (( ! USBTREE )) && [[ -e "$SYSFS/3-3" ]]`; f-usb filter `usb ${USBDEV:-3-3}`. Residual: device absent with a USB tree -> filter uses 3-3 (documented in the comment).
- what is left: nothing

### bt-snapshot raw cuts under /var/tmp
- verdict: NOT ADDRESSED
- now: tools/bt-snapshot:58 `DEST="${BT_SNAPSHOT_DIR:-/var/tmp/bt-snapshots}"` (needs-check stays).
- what is left: decide/document retention.

### bt-exhibit option without value loops
- verdict: FIXED (spot-check)
- now: tools/bt-exhibit:69-72 `shift 2 || { ... exit 2; }`; tests/run-tests:15797-15802 derive "no unguarded shift 2 in tools/ or bin/".
- what is left: nothing

### bt-exhibit help cut off
- verdict: FIXED
- now: tools/bt-exhibit help `sed -n '2,32p'`; line 32 is the `--cmd` line, the whole example prints.
- what is left: nothing

### bt-retention closing note contradicts the header
- verdict: FIXED
- now: tools/bt-retention:289-293 "is not used to place the evidence ... It is used in one direction only, as an upper bound".
- what is left: nothing

### evidence-window.sh duplicated prefix
- verdict: FIXED
- now: tools/lib/evidence-window.sh:70-77 `awk -v p="$BT_EW_PREFIX" ... index($0, p) == 1 { $0 = substr($0, length(p) + 1); sub(/^[[:space:]]+/, "") ...`. Equivalent to the old sub; one literal. (`-v p=` with backslash-free prefix: `**Evidence window.**` has no escapes, fine.)
- what is left: nothing

### bt-backup-journal --status/--dry-run "re-archiving"
- verdict: FIXED
- now: tools/bt-backup-journal:128-134 "would be re-archived in full" under STATUS||DRY.
- what is left: nothing

### bt-trial abort --discard deletes untracked evidence
- verdict: NOT ADDRESSED
- now: tools/bt-trial:1210 `rm -rf "$dir"; rm -f "$CUR"` (opt-in, documented in header 9-10).
- what is left: operator decision vs the never-delete rule.

### bt-journal-files no repository guard
- verdict: FIXED
- now: tools/bt-journal-files:48-56 `REPO=...; DEST_ABS=$(realpath -m "$DEST_ROOT"); case "$DEST_ABS/" in "$REPO"/*) refuse ...`.
- what is left: nothing

### New defect (recheck 1): different-extension replacement bypassed the guard
- verdict: FIXED
- now: bt-archive:362-387 (see item 7); test run-tests:15838-15871.

### New defect (recheck 1): shorter-boot-* exports invisible to --list/--check/--repair  (maintainer N-11)
- verdict: NOT ADDRESSED
- now: tools/bt-archive:126 `for a in "$DEST_ABS"/boot-*.export.*` (the side file is named `shorter-boot-...` at 385); tests/run-tests:15832 asserts `--list` does NOT show it. The maintainer's reason ("an existing test asserts that they are not") is accurate; the refusal text does name the file. The test asserts the wrong thing for an operator (a possibly longer/newer export that nothing lists), but it is a decision, so "open" is honest.
- what is left: list `shorter-boot-*` in --list (flagged), or say in --check; change the test with it.

### New defect (recheck 1): trial-summary warning names "E3 #3 and #4, STATUS 2026-11-07"
- verdict: FIXED
- now: tools/lib/trial-summary.awk:202-203 "the older closer probed late; docs/STATUS.md names the trials where that was the cause" (one printed line is now ~110 chars, cosmetic).
- what is left: nothing

### Maintainer item 10 claim: "`bt-trial`'s header says which verbs send HCI"
- verdict: CLAIM CONFIRMED
- now: bt-trial:14-22.

### Maintainer item 11 claim: bin/bt-mark probe-free (spot-check, outside my files)
- verdict: CLAIM CONFIRMED (bt-mark unchanged and `--probe`-only at a8d0eb45; not in this round's diff)

## New defects introduced by this round
- tools/bt-archive:362-387 (Low): the refusal leaves the `.prefix` marker and the old archive in place, so for a boot with a marker and a ring that has since lost its early records, tools/bt-backup-journal:156-158 (`(( prefixed )) && REPL=(--replace)`) retries and is refused on EVERY run: each run prints FAILED, exits 1 (bt-backup-journal `(( failed > 0 )) && exit 1`) and overwrites `shorter-boot-<id>...` with `mv -f`; the marker is never cleared although the longer archive is the final one. The timer unit then fails permanently. Nothing tells the operator the right action (clear the marker by hand).
- tools/bt-archive:371-377 (Low): a corrupt old archive that decompresses partly or not at all counts as `grep -c ... || true` = 0, so it is treated as countable and replaceable; only a missing decompressor blocks. (Acceptable for a truncated file; for a file that cannot be decompressed at all the "cannot be counted" protection does not apply.) Also the refusal message prints `${OLD_N}` = SRC_N+1 for an uncountable archive as if it were a record count.
- tools/bt-trial:376-383 vs 407: no defect found in the start path change; comment ids: the code comments label both the set-aside in `start` (bt-trial ~367) and the hci_alive change (bt-trial:122) "review T-09" while the checks document gives T-09 to hci_alive only and T-08/T-10 to others. Cosmetic.
- tools/lib/journal.sh: bt_journal_count/first not updated (see PARTLY above): the fix is in one of three sibling helpers.
No elided "…" identifiers or references to missing paths found in the changed files of my part.

---

# Part: code-tools-b

(the checkout of main = bbec102f. 12 spot-checks of earlier FIXED items: bt-sco:52 `--window) WINDOW=2; if [[ ... =~ ^[0-9]+$ ]]`; `shift 2 ||` still in bt-sco/actions/capdiff/context/logvolume/phase (1/3/3/2/3/2 hits); bt-diagnose:51 `if (( boots == 0 ))`; bt-window:9 "`bt-status --probe` and `bt-state --probe`"; bt-sco usage. None regressed; those files unchanged since a8d0eb45.)

### README "every tool takes BT_VID/BT_PID" (maintainer item 14, T-04: "partly")
- verdict: FIXED (maintainer partly-right; I accept the correction)
- now: README.md:133-136 "the tools that look the controller up by its USB id take `BT_VID`/`BT_PID` (`bt-state` detects the device when they are unset; `bt-status` defaults to `13d3:3503`; `bt-crash`, `bt-boots` and `sanitize-logs.sh` do not read them)". Claim check: tools/bt-status:93 `"${BT_VID:-13d3}"` is a default the variable overrides, not a hard-code: my word "hard-codes" was imprecise; the real point (no autodetect, unlike bt-state) is now stated in the README. "27 of 38 tools never read the variable": CONFIRMED for 27 (40 tracked files directly under tools/, 13 contain BT_VID/BT_PID: bt-boot-provenance bt-health-report.sh bt-mode bt-postmortem bt-snapshot bt-stage2 bt-state bt-status bt-trial bt-usbstate bt-verify-install bt-window verify-restored.sh, so 27 do not), but the denominator is 40, not 38.
- what is left: README omits bt-diagnose from the "do not read them" list although it names it as working on any controller (it autodetects; harmless).

### bt-incident timeline from PATH only (Low)
- verdict: PARTLY
- now: tools/bt-incident:105-110 sibling `bt-timeline.sh` first, then PATH; else `echo "bt-incident: bt-timeline.sh not found ... no timeline.txt written" >&2`. The comment at :103-104 says "the manifest says so", but nothing is written to MANIFEST.txt (:191); only stderr. Header :12 still says "a merged timeline".
- what is left: record the missing timeline in MANIFEST.txt as the comment promises (or fix the comment).

### sanitize-logs.sh IPv6 / other forms not covered (Low)
- verdict: PARTLY (documented, not fixed)
- now: tools/sanitize-logs.sh:17-25 "WHAT IT DOES NOT COVER ... IPv6 addresses ... the dotted form ... a bare run of 12 hex digits ... any AA:BB:CC:00:00:NN as already sanitised". The final line of the script still says "verified: no MACs, BSSIDs, UUIDs or IPv4 addresses remain"; README:~299 still says it "replaces MACs, BSSIDs and IPv4 addresses ... and verifies none survived" without the limit.
- what is left: nothing required; optionally one clause in README.

### Index lists git-ignored paths as if tracked (Medium)
- verdict: FIXED
- now: docs/tooling-index.md new paragraph "Which paths are in a clone. `tmp/`, `cache/` and `archive/` are git-ignored ..."; row :93 "A script `tmp/raw-archive-timer/install-timer.sh` ... is **git-ignored and exists only on that machine**". Maintainer claim (item 12 "right") confirmed for this part.
- what is left: nothing

### Executables missing from the index (Medium)
- verdict: FIXED
- now: docs/tooling-index.md section "### Single-purpose scripts and proofs" lists all 15 (devtools/access-classify, assert-test-catches, journal-speed/bench*.sh, scripts/dbg-autostop-calls.sh ... uncovered-code-report.py). Mechanical re-run on the checkout of main: every 100755 file in tools/ bin/ scripts/ devtools/ top level is named in the index (no NOTINDEX output), and every `scripts/…`/`devtools/…` path in backticks exists in the tree.
- what is left: nothing

### tools/test-runner ambiguity (Low)
- verdict: FIXED
- now: docs/tooling-index.md:140 "BlueZ's own `tools/test-runner` (in its checkout, not ours)"
- what is left: nothing

### bt-incident --help truncated (Low)
- verdict: FIXED
- now: tools/bt-incident:26,36 `sed -n '2,13p'`
- what is left: nothing

### Probe contract note (bluetoothctl in bt-state)
- verdict: NOT ADDRESSED (no defect; unchanged)
- now: tools/bt-state:78 `timeout 8 bluetoothctl devices Connected`
- what is left: nothing

### New-defect items from recheck 1
- `-h` printing past the header: FIXED, tools/bt-ui-capture:~1015 `sed -n '2,/^$/p' "$0"` (prints to the first blank line).
- Header "passive monitors" vs light-mode registration: FIXED, tools/bt-ui-capture:29-30 (`"passive" = they only listen; see the light-mode note below`) and the "NOT PASSIVE, ONE STEP" block at :81-87.
- start_light_main edge (units active but no `current` pointer): FIXED in effect: start-light now reuses/creates one directory and starts only missing units (light_unit_present per unit), `--new` stops them first.

### N-10 light mode (maintainer: "partly", exercised only by scripts/prove-ui-capture.sh)
- verdict: CLAIM CONFIRMED
- now: scripts/prove-ui-capture.sh is the only place that mentions the keeper/light units outside docs; 159 checks per index :~112 (was 112). Header names the one non-passive step (tools/bt-ui-capture:81-87). Not run against a real session.

## New defects introduced by this round
Reviewed tools/bt-ui-capture enable-light / disable-light / reworked start-light (diff a8d0eb45..HEAD). No hang-class defect; findings:
1. Low, privilege: enable-light (tools/bt-ui-capture, keeper_service heredoc) writes /etc/systemd/system/bt-ui-light-keeper.service whose ExecStart runs `"$SELF" start-light` as root every 2 minutes. SELF is the checkout copy; nothing checks that SELF or its directory is root-owned and not writable by others, so a user-owned checkout turns into root code execution on a 2-minute timer. needs-check (depends on where the checkout lives on the machine; /root/exp would be fine).
2. Low, naming: option `--quiet-if-no-session` (start_light_main) does not do what its name says; it suppresses output whenever nothing changed (`(( ! quiet || LCHANGED > 0 || LFAILED > 0 ))`), session or not. The header describes it correctly ("print only on a change"); the name misleads.
3. Low, wording vs code: tools/bt-incident:103-104 comment "the manifest says so" but only stderr is written (see above).
4. Low: disable_light_main ignores the result of `systemctl disable --now ... >/dev/null 2>&1` and prints "stopped and disabled" regardless.
5. Low, upgrade step: light_ensure_user_unit treats a present unit with no `.stamp.<unit>` file as "login changed: 'unknown'" and stops/starts it, so the first keeper run after upgrading restarts units that were started by the older start-light (one-time gap in the record). Intended probably; undocumented.
6. Low, doc: docs/tooling-index.md keeper row and header say "every 2 min" and the unit has OnBootSec=1min, OnUnitActiveSec=2min, AccuracySec=10s, so it is "about every 2 minutes"; stop-light note says "within 2 minutes". Cosmetic.
7. Low, README: the controller sentence (README.md:133-136) lists bt-crash/bt-boots/sanitize-logs.sh as not reading BT_VID but omits bt-diagnose, which also does not.
No new references to missing paths, no elided identifiers in the new tool text. Everything the index's new single-purpose table names exists.

---

# Part: code-scripts-a

## Recheck 2 of code-scripts-a against the checkout of main (bbec102f)

Files of my part changed in a8d0eb45..HEAD: README.md, bt-device-record.sh, bt-ui-atspi.py, bt17-provoke.py, btusb-has-device.py, build-bluetooth-fulltree.sh, build-btusb-stable-matrix.sh, build-v2.sh, ci-local.sh, compile-mgmt-at.sh, desktop-capture-archive.sh, discovery-stop-race.py, export-kernel-review.sh, export-local-work.py, get-maintainers.sh, gitlint-check.sh, journal-archive-grep.py, kernel-preflight.sh (also bot-ci-local/harness.py, bt17-review-pack/build.py outside my list). All other files are byte-identical to a8d0eb45, so their items stay as they were.

## Items I left PARTLY / NOT ADDRESSED / WORSE

### build-btusb-stable-matrix.sh: -Werror fallback lost in a subshell
- verdict: FIXED
- now: scripts/build-btusb-stable-matrix.sh:54-72 `build()` sets `BUILD`, called as `build unpatched; un=$BUILD`; :82 `[[ "$un" == rc=0* ]] || { un="$un (CONTROL FAILED ...)"; rc=1; }`; header :17 now says "every unpatched control build succeeds".
- what is left: nothing.

### build-btusb-stable-matrix.sh: pass condition hard-wired to 13d3:3503
- verdict: NOT ADDRESSED
- now: build-btusb-stable-matrix.sh:78 `grep -c "0x13d3, 0x3503"`, :80 `"$entry" == 1 ]] || rc=1`; header unchanged.
- what is left: document or parameterise the entry check.

### build-btusb-stable-matrix.sh / backport-check.sh: default branch list snapshot
- verdict: NOT ADDRESSED
- now: build-btusb-stable-matrix.sh:11,22; backport-check.sh:7,20 (no 7.3.y)
- what is left: add 7.3.y or derive the list.

### build-bluetooth-fulltree.sh: failed patch not detected
- verdict: FIXED
- now: build-bluetooth-fulltree.sh:46-51 `if ! pout=$(patch -p1 < "$PATCH" 2>&1); then ... NOT BUILT ... exit 1`
- what is left: nothing.

### build-btusb-module.sh: exit 0 with no .ko
- verdict: NOT ADDRESSED
- now: build-btusb-module.sh:55 `[[ -f "$KO" ]] || exit "${rc:-1}"` (file unchanged)
- what is left: non-zero exit when the .ko is missing.

### build-bluetooth-module.sh: --ubuntu undocumented / hard-coded
- verdict: NOT ADDRESSED
- now: build-bluetooth-module.sh:28 `cache/ubuntu-7.0.0-31`
- what is left: document or drop.

### bt17-arm-usb-debug.sh: --off reports success unchecked
- verdict: NOT ADDRESSED
- now: bt17-arm-usb-debug.sh:29-30
- what is left: check the debugfs writes.

### bluez-tester-compare.sh: --help prints a code line
- verdict: NOT ADDRESSED
- now: bluez-tester-compare.sh:54 `sed -n '2,30p'` (header now ends line 29)
- what is left: change to 2,29.

### bluez-tester-compare.sh: rc 2 hides "RESULT: regressions found"
- verdict: NOT ADDRESSED
- now: bluez-tester-compare.sh:180-181 (file unchanged)
- what is left: print the regression result even when rc==2 or print both.

### backport-check.sh: `| head -1 || echo` never fires
- verdict: NOT ADDRESSED
- now: backport-check.sh:27
- what is left: test for empty output.

### bluez-accepted-survey.py: cache never refreshed
- verdict: NOT ADDRESSED
- now: bluez-accepted-survey.py:41
- what is left: refresh switch or a note.

### archive-budget-check.py: empty root silent
- verdict: NOT ADDRESSED
- now: archive-budget-check.py:53 area unchanged
- what is left: print "no stores".

### btusb-has-device.py: errors exit 1; xz/gz read as ABSENT
- verdict: FIXED
- now: btusb-has-device.py:5-9 docstring, `read_module` handles .zst/.xz/.gz; `except (OSError, CalledProcessError, LZMAError, EOFError)` prints "NOT CHECKED" exit 2; empty file also exit 2.
- what is left: nothing.

### bt17-provoke.py: exit status on FAILURE; vanished device loops
- verdict: PARTLY
- now fixed: bt17-provoke.py:144 `failed = True`, :152-158 exit 1 on failure, exit 3 "NOT RUN" when n == 0.
- remaining: :131 still `"... (something keeps it awake); waiting"` and `continue`s when the device is gone, so a device that vanishes after cycle 1 gives exit 0 at the end (n>0, failed False).
- what is left: treat a missing sysfs device as FAILURE.

### bt17-provoke.py: docstring "addresses never read" vs dmesg dump
- verdict: NOT ADDRESSED
- now: bt17-provoke.py:22 vs :138-139
- what is left: reword.

### bt-device-record.sh: unreadable store reported as "no stored device"
- verdict: FIXED
- now: bt-device-record.sh:16-29 `STORE=...`, readable/unreadable counts, `NOT LOOKED AT: no readable device record under $STORE ... root is needed` exit 2.
- what is left: nothing.

### bt-trace-archive.py: /root path; digest set unused
- verdict: NOT ADDRESSED
- now: bt-trace-archive.py:20,35 `/root/bt-trace-keep`; :127-132 identical branches. This now also contradicts the new scripts/README.md rule "No machine's paths ... an environment variable with no default of that kind".
- what is left: no default or derive it.

### boot-bt-summary.sh: `|| echo "(none)"` covers journalctl failure
- verdict: NOT ADDRESSED
- now: boot-bt-summary.sh:20,22
- what is left: separate exit 1 from other failures.

### build-v2.sh: header says awaiting decision; BRIEF line
- verdict: PARTLY
- now fixed: build-v2.sh:16-17 "The v2 it derives was posted to the list (patches/bluez/README.md keeps the state)".
- remaining: BRIEF.md:747 still "Operator's decision. **v2 is prepared in patches/bluez/v2/**".
- what is left: update the BRIEF line.

### build-mails.sh: fixed to the September pair
- verdict: NOT ADDRESSED
- now: build-mails.sh:21
- what is left: mark as record.

### ci-local-controls.sh: banner names btdev.c:479
- verdict: NOT ADDRESSED
- now: ci-local-controls.sh:98
- what is left: reword.

### ci-run-images.sh: no arg check / hard-coded repo
- verdict: NOT ADDRESSED
- now: ci-run-images.sh:6
- what is left: usage and error exit.

### desktop-capture-archive.sh: 3 GB default rewrites the budget
- verdict: FIXED
- now: desktop-capture-archive.sh:21 `BUDGET="${BT_ARCHIVE_BUDGET_GB:-}"`, :32-35 reads archive/hci-capture/BUDGET_GB, else "no budget given and none stored ... pass --budget-gb N" exit 2; header :10-12.
- what is left: nothing.

### commit-in-tree.py: traceback paths
- verdict: NOT ADDRESSED
- now: commit-in-tree.py:34,75
- what is left: handle both.

### discovery-stop-race.py: btmon exit status ignored
- verdict: FIXED
- now: discovery-stop-race.py:59-63 `rc = p.wait(); if rc != 0: raise RuntimeError(...)`; :221-225 `NOT RUN — ...; no counts printed` exit 2.
- what is left: nothing.

### discovery-stop-race.py: docstring vs excluded outcomes
- verdict: NOT ADDRESSED
- now: discovery-stop-race.py:23-24 docstring vs :187 (code includes "off done first, stopped")
- what is left: fix the docstring.

### device-adv-summary.py / hfp-gain-by-device.py / hfp-late-vgm-scan.py / journal-archive-grep.py: former names in docstrings
- verdict: NOT ADDRESSED
- now: device-adv-summary.py:7 `adv-summary.py`; hfp-gain-by-device.py:2,6; hfp-late-vgm-scan.py:2,13; journal-archive-grep.py:2,4 (`archive-grep.py`)
- what is left: fix names.

### export-kernel-review.sh: held branch / brief off main
- verdict: FIXED
- now: export-kernel-review.sh:2-9 "The source is `main` by default (the files are on main since 2026-10-09)"; :14 `BR="${BT_HELD_BRANCH:-main}"`. The date matches patches/kernel/REVIEW-TASK.md line 3-4 "Ported to main 2026-10-09". (Residual: exhibits 044/049/050 still hard-coded in the case filter.)
- what is left: nothing material.

### export-local-work.py: git failures swallowed
- verdict: FIXED
- now: export-local-work.py:30-36 `git_must()` raises SystemExit "NOTHING WAS SAVED"; used for rev-list, diff, ls-files, rev-parse, format-patch.
- what is left: nothing.

### ci-local.sh: exit 0 although checks did not run
- verdict: PARTLY
- now fixed: ci-local.sh:586, :657, :743 each now `SKIPPED+=(...)` after NOT RUN "git am failed".
- remaining: functional configure/build/junit failures still write findings "configure failed" (:659), "build failed" (:660), "no junit result" (:669) that compare as PRE-EXISTING and exit 0.
- what is left: make a functional side that did not run NOT RUN.

### ci-local.sh: header names cache/action-ci
- verdict: NOT ADDRESSED
- now: ci-local.sh:19
- what is left: name cache/action-ci-bluez.

### gitlint-check.sh vs ci-local.sh
- verdict: FIXED
- now: gitlint-check.sh:2-7 "NOT the file the BlueZ CI bot uses ... scripts/ci-local.sh runs that one (default <action-ci>/gitlint)"; ci-local.sh:22 consistent.
- what is left: nothing.

### get-maintainers.sh: relative patch path
- verdict: FIXED
- now: get-maintainers.sh:9-10 `PATCH="$(readlink -f -- "$PATCH")"; [[ -r "$PATCH" ]] || ... exit 2` before the cd.
- what is left: nothing.

### functional-repeat.sh: skips count as 0 failures; always exit 0
- verdict: NOT ADDRESSED
- now: functional-repeat.sh:116, :132
- what is left: count skips, non-zero exit on NO-RESULT.

### hci-key-records.py: datalink unchecked, local time
- verdict: NOT ADDRESSED
- now: hci-key-records.py:45
- what is left: check datalink; state tz.

### kernel-preflight.sh: C=2 vs C=1; relative sparse path
- verdict: FIXED
- now: kernel-preflight.sh:8-10 "C=1 (sparse on the files that are rebuilt: mgmt.c is touched first)"; :17-20 `REPO=...` absolute, `BT_SPARSE="$(readlink -f -- "$BT_SPARSE")"`.
- what is left: nothing.

### journal-archive-grep.py: failures read as "0 match(es)"
- verdict: FIXED
- now: journal-archive-grep.py:29-33 "NOT SEARCHED (unknown extension ...)", :48-53 "NOT SEARCHED COMPLETELY (... failed ...)", :56-58 `ERROR: ... not (fully) searched` return 2.
- what is left: nothing.

### journal-scan-time.sh: failed journalctl reports "lines 0"
- verdict: NOT ADDRESSED
- now: journal-scan-time.sh:11-12
- what is left: check status.

### scripts/README.md: "tracked and tested" for four scripts
- verdict: FIXED
- now: scripts/README.md:30-36 "tracked for that reason. Of those four, sco-ledger.sh and sco-ledger-boots.sh have tests ...; boot-bt-summary.sh and build-btusb-stable-matrix.sh have none". Confirmed: tests/run-tests:15977-15991 (sco-ledger.sh), sco-ledger-boots tested; `grep -rln "boot-bt-summary\|build-btusb-stable-matrix" tests devtools tools` finds nothing.
- what is left: nothing.

### scripts/README.md: rules vs the directory
- verdict: PARTLY
- now fixed: docs/tooling-index.md now has one row each for dbg-autostop-calls, exhibit-relabel-boot-id, export-kernel-review.
- remaining: README.md still lists none of the four subdirectories (bot-ci-local/, bt17-review-pack/, cd-trace/, kernel-review-pack/) and does not point to docs/tooling-index.md; the "run more than twice is promoted" rule (README.md:17-19) is still not followed by ci-local.sh and bot-ci-local.sh.
- what is left: one sentence pointing to the index and the subdirectories.

### bt-ui-atspi.py: first sentence "without changing anything in the session"
- verdict: NOT ADDRESSED
- now: bt-ui-atspi.py:3 (the new non-passive paragraph qualifies it, the opening sentence is unchanged)
- what is left: add "unless --register-shell-events".

### bt-ui-atspi.py: clock filter drops legitimate names with d.dd
- verdict: NOT ADDRESSED
- now: bt-ui-atspi.py:93 `CLOCK_TEXT = re.compile(r"\b\d{1,2}[:.]\d{2}\b")`
- what is left: tighten to `\d{1,2}:\d{2}` or document.

### bt-ui-atspi.py: start line claims registration although all failed
- verdict: FIXED
- now: bt-ui-atspi.py `registration_mode(done, failed)`: "passive in effect: opted in, but ALL n registrations FAILED ..." / "NOT passive: registered d of n ... (k FAILED)".
- what is left: nothing (exit status still 0 on all-failed; the start line says so).

### ci-local.sh three NOT RUN paths not in SKIPPED (my "new defect")
- verdict: FIXED (see ci-local.sh exit item for the functional remainder)

## The maintainer's claims (checks document, item 10, and the two commits)

### Item 10: "compile-mgmt-at.sh goes by patch's exit status"
- verdict: CLAIM CONFIRMED
- now: compile-mgmt-at.sh:29-33 `if ! pout=$(patch -p1 -d "$OUT" < "$PATCH" 2>&1); then echo "patch did not apply" ... exit 1; fi`; :35 `printf '%s\n' "$pout" | grep -E "Hunk" || true`. My High finding was right and is fixed.
- what is left: nothing.

### Item 10: "Each listed script exits non-zero or says NOT RUN when it did not measure"
- verdict: CLAIM CONFIRMED for the scripts named in commit 0d3a1b9f that are in my part (btusb-has-device, bt-device-record, discovery-stop-race, journal-archive-grep, export-local-work, bt17-provoke, ci-local, stable-matrix, fulltree, harness.py: each checked above; harness.py:171-175 `NOT RUN: no test was selected` return 2). Not every not-measured case in my part is covered (see NOT ADDRESSED: functional-repeat.sh, journal-scan-time.sh, hci-key-records.py, boot-bt-summary.sh, archive-budget-check.py, bt-trace-archive.py), but the commit does not claim them.

### Commit 02d7b5b3 "find the checkout from the script's own place ... fix relative paths and stale headers"
- verdict: CLAIM CONFIRMED for the named files (get-maintainers.sh, kernel-preflight.sh, export-kernel-review.sh, build-v2.sh, gitlint-check.sh headers; bt17-review-pack/build.py:13-17 derives ROOT, `BT17_BASE_TREE` env; README rules added at README.md:20-30).
- what is left: scripts/README.md rule "No machine's paths ... an environment variable with no default of that kind" is not kept by bt-trace-archive.py:35 (`/root/bt-trace-keep`) or the /root mentions at raw-capture-archive-all.sh:6 and bt-audio-policy.py (docstring); and "a `|| true` is allowed only where the status it hides is named in a comment next to it" is not kept at ci-local.sh:292-293, :606, :664, compile-mgmt-at.sh:35 (partly commented), build-btusb-stable-matrix.sh:39,84.

### Items I spot-checked as FIXED earlier (no regression)
- verdict: CLAIM CONFIRMED (4 of 4 unregressed: bluez-tester-compare.sh:148/180 NO VERDICTS and incomplete; bluez-release-contains.sh:6-7 and case on rc; ci-local-publish.sh:78-83 rm and exit 2; ci-local.sh:453 `grep -q '^total:'` NOT RUN). All four files are unchanged since a8d0eb45.

## New defects introduced by this round

- scripts/README.md rules contradict the scripts (rule-vs-practice, Low): see the claims block above (`/root/bt-trace-keep` default; unannotated `|| true`).
- desktop-capture-archive.sh:10-14 (Low, cosmetic): the budget sentence is now glued to the next sentence on one over-long comment line ("... it has no default of its own. How much this store may take is the operator's call: 10 GB ..."); the stored-budget regex at :34 accepts decimals while `--budget-gb` at :23 accepts integers only.
- bt17-provoke.py:152-158 (Low): exit 3 "NOT RUN" is reached only after the full --hours loop when the device never suspends; and a device that disappears mid-run still exits 0 (see PARTLY).
- build-bluetooth-fulltree.sh:46-50 / compile-mgmt-at.sh:29-33 (Low): the apply failure path exits 1 but a `.rej`/`.orig` left by patch in the copied tree is not cleaned in compile-mgmt-at.sh (it recreates OUT each loop, so harmless there) and fulltree restores with `git checkout -- net/bluetooth` (does not remove untracked .rej files); a later run starts from a tree with stray .rej files. Needs-check.
- Otherwise none found in the diffs of bt-device-record.sh, btusb-has-device.py, discovery-stop-race.py, export-local-work.py, journal-archive-grep.py, get-maintainers.sh, kernel-preflight.sh, harness.py.

---

# Part: code-scripts-b

## Third pass, code-scripts-b, the checkout of main tip bbec102f (diff a8d0eb45..HEAD read for all changed files of my part)

## Maintainer item 8: sco-ledger.sh no-match logic, line by line
### Item 8 claim: "a no-match with empty stderr is now a measured zero; any other failure stays exit 2"
- verdict: CLAIM CONFIRMED (one caveat, below)
- now: scripts/sco-ledger.sh:34-37 probe `journalctl -k -b "$BOOT" --no-pager -q -n 1 -o cat 2>&1` must succeed AND print a line, else exit 2. Then :57-62 `RAW=$(journalctl ... --grep '...' 2>"$ERRF"); jrc=$?` / `if (( jrc > 1 )) || { (( jrc == 1 )) && [[ -s "$ERRF" ]]; }; then ... exit 2`. So: rc 0 = lines; rc 1 with an empty stderr = zero; rc 1 with any stderr text or rc >= 2 = exit 2. The awk reads `<<<"$RAW"` (:106), so an empty RAW prints the header and "links 0 ..." with exit 0. Tests: tests/run-tests:16244-16267 (readable boot with no SCO line = exit 0; "exit 1 or above" with a failure = exit 2; boots wrapper both ways).
- caveat: a real read failure that exits 1 with an EMPTY stderr would now be a zero. I found no such case for the second read: errors go to stderr; the only message `-q` suppresses on the second read is the info hint ("No journal files were opened due to insufficient permissions"), and a permission problem is already caught by the probe, which prints nothing without access (empty PROBE -> exit 2). A permission or journal loss between the probe and the read is a race, not a normal path. The test stub for the failing case (:15981) writes to stderr, so the "exit 1, silent, but really broken" case is not covered by a test, only by the probe's logic.
- what is left: nothing required; optionally a test that a silent exit 1 after a passing probe is the zero (it is at :16244+), and a note that the zero depends on the probe.

## Maintainer item 9: runtime-mgmt-test.sh
### Item 9 claims (refusal, removed code, usage, guard fails closed, verbs described, test with stubs)
- verdict: CLAIM CONFIRMED
- now: scripts/runtime-mgmt-test.sh:94-98 `load|restore) ... exit 2`; the unload_stack/finish_stack/stop_holders/load_disabled/restore_disabled code is gone (diff shows ~80 lines removed; grep finds no `modprobe -r` or `insmod`); usage is `sed -n '2,/^set -uo/{/^set -uo/!p}'` and the header no longer lists load/restore as verbs (:11-14); header :16-22 "stock-daemon ... RESTART bluetoothd", "trigger ... POWER-CYCLE THE ADAPTER", "REFUSES (exit 3) ... also when it cannot tell"; guard() at :50-70 refuses when either tool is missing/not executable, when bt-window exits non-zero or is silent, when bt-trial status is not "no trial open"*. tests/run-tests:16124-16180 runs with modprobe/rmmod/insmod/systemctl/btmon/... stubbed first on PATH and asserts no stub was called, plus the seven guard cases.
- what is left: see new defect 1 (guard refuses on bt-window exit 1).

## My earlier recheck items (those not FIXED, plus New defects)
### trial-close-now.sh: tmp dir leaked, rc not propagated, unknown argument ignored
- verdict: NOT ADDRESSED
- now: trial-close-now.sh:43 `empty=$(mktemp -d ...)` never removed; :62 `echo "sco decode: rc=$?, ..."` only printed; :64 `[[ "${1:-}" == --reopen ]]`.
- what is left: rm the dir, propagate rc, reject unknown args.

### Hard-coded /root/exp paths
- verdict: FIXED (one leftover)
- now: no `/root/exp` left under scripts/ (grep). move-brief-block.py:11 `root = Path(__file__).resolve().parent.parent`, with an argv count check and a range check before writing; prove-archive-budget-check.py:16 and prove-bt-trace-archive.py:17 use `os.path.dirname(HERE)/tmp`; prove-held-branch-guard.sh:6 `cd "$(dirname "${BASH_SOURCE[0]}")/.."`; bt17-review-pack/build.py:13-17 ROOT from HERE and TREE from BT17_BASE_TREE (default cache/linux); x1-check-submission.py:13 `Path(__file__).resolve().parents[2] / ...`.
- what is left: prove-bt-trace-archive.py:49 still falls back to the untracked `tmp/evidence-20261011-sbc-xq-bt-20261011-003713.btsnoop` without saying it is local-only (see "Hard-coded machine specifics").

### "prove-*" scripts that cannot fail
- verdict: FIXED
- now: prove-trial-closer.sh:64-65 and prove-trial-nomatch.sh:59-60 `(( FAILED == 0 ))` with `bad()` counting; prove-trial-build-label.sh `expect()` compares the wanted `build=` lines and ends `(( FAILED == 0 ))`; prove-ci-cwd.sh `if [[ -z "$OUT" || "$OUT" == *"no run found"* ]]; then ... exit 1`; prove-audio-policy-metadata.py ends `sys.exit(0 if kept and removed else 1)`.
- what is left: nothing.

### patch-id-compare.sh, patch-code-compare.py: exit status
- verdict: NOT ADDRESSED
- now: patch-id-compare.sh last line `if [[ -n "$a" && "$a" == "$b" ]]; then echo "SAME"; else echo "DIFFERENT"; fi` (exit 0); patch-code-compare.py:61 `sys.exit(__doc__)` (exit 1).
- what is left: exit 1 on DIFFERENT, 2 on usage.

### patchwork-checks.sh: failed fetches skipped silently
- verdict: NOT ADDRESSED
- now: patchwork-checks.sh:68, :71, :104 `... || continue`; :83/:110 `exit 0`.
- what is left: count skipped patches, report, exit 2.

### sco-switch-windows.sh: `|| true`
- verdict: FIXED
- now: sco-switch-windows.sh:26-31 `"$HERE/capture-window.sh" ... ; rc=$?` then `if (( rc != 0 && rc != 141 )); then echo "   NOT READ: ..."`, and :36-39 `exit 2` when any window failed. (The comment above still describes the 141 case although capture-window.sh already maps 141 to 0; harmless.)
- what is left: nothing material.

### sco-ledger.sh / sco-ledger-boots.sh (was WORSE)
- verdict: FIXED
- now: see item 8. sco-ledger-boots.sh (unchanged this round) still excludes failed boots and exits 2; now a zero-link boot exits 0 from sco-ledger.sh so it is counted. tests/run-tests:16263-16267 test the nomatch/match boots through the wrapper.
- what is left: nothing.

### r2-checks.sh: `c()` double "0"
- verdict: NOT ADDRESSED
- now: r2-checks.sh:9 `c() { grep -cE "$2" "$1" 2>/dev/null || echo 0; }`.
- what is left: `|| true` plus an existence check.

### runtime-mgmt-test.sh: guard fail-open
- verdict: FIXED (see item 9).

### prove-audio-policy-metadata.py, supported-commands-survey.sh, bot-ci-local/harness.py
- verdict: FIXED
- now: prove-audio-policy-metadata.py:39 `sys.exit(0 if kept and removed else 1)`; supported-commands-survey.sh:26 `mkdir -p "$REPO/tmp"`, `brc=${PIPESTATUS[0]}` with "NOT READ: btmon failed on ...", and exit 2 at the end if `n == 0` or any file unread; harness.py:174-178 `if not tests: ... print('NOT RUN: no test was selected') ... return 2`.
- what is left: harness.py now exits 2 both for "nothing ran" and for two failing tests (its header says the exit status is the failure count) - Low ambiguity.

### cd-trace: README passivity wording; hard-coded device/user; trace.py end-of-run
- verdict: PARTLY
- now: fixed: user is `BT_DESKTOP_USER` (default i) with uid from `id -u` in cdda-remount.sh:6, totem-debug.sh:24, totem-quit.sh:5, and from `pwd.getpwnam` in record.py:22-25 and trace.py:47-50. Left: cd-trace/README.md:3-4 "Nothing here sends anything to a device or changes a setting" unchanged though cdda-remount.sh unmounts/mounts the CD; trace.py:41-42 `Path("/sys/bus/usb/devices/1-1/busnum")` still hard-coded and still uncaught (strace already started, never terminated).
- what is left: reword README; handle missing 1-1 and terminate strace on error.

### cd-trace/x1-check-submission.py: stale name, no timeout
- verdict: PARTLY
- now: fixed: :13 path from `__file__`. Left: :2 `"""check-submission.py — ...`; :21 and :83 `urlopen(...)` without timeout; a network error still exits 1 like "no longer matches".
- what is left: rename in the docstring, add timeouts and a distinct exit for network errors.

### Network fetches without timeout / error status (stable-queue-check.sh)
- verdict: NOT ADDRESSED
- now: stable-queue-check.sh:19 `curl -s -f "$BASE/queue-$v" || { ... rc=1; continue; }` (no --max-time; same rc as "not in queue").
- what is left: `--max-time`, rc 2 for a failed fetch.

### Stale/incorrect headers
- verdict: PARTLY
- now: runtime-mgmt-test.sh "Everything is reversible" is gone. Left: ubuntu-bluez-patches-check.py:5 `Usage: dev-release-patches.py`; prove-held-branch-guard.sh:2 "the two suite assertions"; ubuntu-series-versions.py:21 `[:4]` vs the docstring; x1-check-submission.py:2.
- what is left: fix those four.

### sent-mail-check.py: missing local file reported as unreachable; empty filter exits 0
- verdict: NOT ADDRESSED
- now: sent-mail-check.py:289 `except OSError as e:` (unchanged).
- what is left: separate local OSError; exit 2 on zero rows.

### prove-dr-followup.sh / prove-dr-review.sh live uninstall via stubs
- verdict: NOT ADDRESSED
- now: prove-dr-followup.sh:64, prove-dr-review.sh:47 unchanged.
- what is left: assert the stub wins, or accept as is (Low, needs-check).

### module-updates.sh: `remove` has no open-trial check
- verdict: NOT ADDRESSED
- now: module-updates.sh `remove)` block: `[[ -f "$DST" ]] && rm -f "$DST"; depmod -a "$KREL"` without the trial check.
- what is left: add the check or say so in the header.

### smtp-login-check.sh: silent exit 2 on missing git config (residual of a FIXED item)
- verdict: NOT ADDRESSED
- now: smtp-login-check.sh:20-22 `HOST=$(git -C "$REPO" config sendemail.smtpserver) || exit 2` prints nothing.
- what is left: one line of stderr.

### Hard-coded machine specifics not marked local-only
- verdict: PARTLY
- now: desktop user has an override in cd-trace (above), as it already had in user-*.sh. Left: trace.py:41 USB path 1-1; prove-bt-trace-archive.py:49 untracked tmp fallback; cache/linux dependence of prepare-ubuntu-ksrc.sh, series-backport-check.sh, stable-*.sh and now bt17 build.py (:17) unmarked.
- what is left: say "local-only" in the headers.

### Spot-check of items that were FIXED in my second pass (5 checked)
- verdict: FIXED (no regression)
- now: smtp-login-check.sh (unchanged since a8d0eb45; INCONCLUSIVE exit 3 still there); privacy re-scan of changed files in my part (only `00:11:22:33:44:55` / `DE:AD:BE:EF:00:01` placeholders in prove-ui-capture.sh, `test@example.com`); kernel-review-pack: not re-hashed (the review file and packages did not change in scripts/; see below). runtime-mgmt-test.sh and sco-ledger.sh re-read in full. The 53 SHA pairs: re-ran on the checkout of main, see next block.

### kernel-review-pack SHA control on the checkout of main
- verdict: CLAIM CONFIRMED (control still holds if the parse below is clean)
- now: see the result line appended at the end of this file.

### New defects 2-4 of the earlier pass
- dead swap code in runtime-mgmt-test.sh: FIXED (removed; tests/run-tests:16145 greps that none is left).
- send-table-check.py: FIXED. send-table-check.py:26-30 `rows <= 0 ... sys.exit(2)`; :39 `"..." in path`; :45-46 a row that names no path is a problem.
- prove-ui-capture.sh hard-coded `7/10` counts: NOT ADDRESSED (unchanged, Low; the keeper/session tests added this round are asserted and the script still ends on the counter).

## New defects introduced by this round
1. runtime-mgmt-test.sh guard() (Low): it requires tools/bt-window to exit 0, but bt-window exits 1 whenever a window exists and is not "untreated and running" (tools/bt-window:156 `exit 1`, header "Exit 0 while the device is still enumerated, 1 once it has left the bus"). After a hang or an intervention, guard() therefore refuses with "gave no usable answer (exit 1)" - fail-closed and arguably right, but the message is wrong, and the test case at tests/run-tests:16164 uses `echo "No HCI command timeout this boot."; exit 1`, whereas the real tool prints that line and exits 0 (tools/bt-window:77-80), so the test models an exit status the tool does not have in that state.
2. scripts/cd-trace/trace.py:47-50 and record.py:22-25 (Low): `__import__("pwd").getpwnam(__import__("os").environ.get(...))` inside the Popen argument list; an unknown BT_DESKTOP_USER raises KeyError there, in trace.py after strace has already been started and with no terminate (same leak as for a missing 1-1). The shell scripts fail cleanly (`id -u "$U" || exit 2`); the Python ones do not.
3. scripts/prove-held-branch-guard.sh:9-10 (Low): the new `export BT_REPO_SAVE_CONFIG_IDENTITY=1` is exported for the whole script. devtools/repo-save:52-73 refuses it in this checkout, any clone, non-local remotes and URL rewrites, and tests/system-resources.md:133 documents it, so it is guarded; the header of the script still says "the two suite assertions" (stale, listed above).
4. scripts/sco-switch-windows.sh (Low): the new `rc != 141` branch is dead (capture-window.sh already returns 0 for 141, capture-window.sh:28-33), and the comment above still says the pipeline "reports 141".

SHA control on the checkout of main: 53 pairs, 1 problems
MISMATCH contributions/CO-21-btusb-sco-alt-setting/review-fixes-20261114/0000-cover-letter.patch

5. (Medium, confirmed) reviews/2026-11-14T0300Z-kernel-patches-ready-to-send-for-outside-review.md no longer matches the tree: its SHA-256 header for `contributions/CO-21-btusb-sco-alt-setting/review-fixes-20261114/0000-cover-letter.patch` (item 9/CO-21) differs from the file. Commit 9fdee116 (2026-11-16, "CO-21 and CO-20 recipients and notes") rewrote the cover's "Changes since the first draft" paragraph (11 lines changed). The other 52 pairs match. scripts/kernel-review-pack/build.py:6-9 says "Rerun after any package is regenerated: the document then follows the files", and the document's intro says "the text you review is the text that would be mailed"; the document was not rerun and carries no note. If the 11-14 document is meant as a dated record this is only a stale hash; if it is still the text to send, the cover sent would not be the cover reviewed.

---

# Part: code-devtools

## recheck2 code-devtools (the checkout of main = bbec102f; paths in that checkout). Read only; nothing run.
Changed in my part since a8d0eb45: checks.yml, .gitignore, devtools/{README.md, access-classify, awk-coverage, ci, coverage-exclude, held, journal-contract, journal-speed/bench.sh, repo-save, repo-scan, repo-scan-public-addresses, repo-validate, test-bt-journal-files.sh, test-journal-fast.sh}. Unchanged: save, review-open, assert-test-catches, status, py-coverage, branch-status, doc-main-hashes, hooks/*.

### Identity switch refuses clones, pushurl, url rewrites (maintainer item 9; my New defect 1)
- verdict: FIXED (small residue)
- now: devtools/repo-save:48-77 early block: refuses own checkout, a clone (HEAD commit known to the project, shared root commit, or tracked devtools/repo-save), `remote.*.(push)?url` not local, and `url.*.(push)?insteadof` ("a URL rewrite is configured"), before staging. tests/run-tests:16276-16330 builds each case (pushurl, insteadOf, pushInsteadOf, clone, clone+own commit, tracked repo-save, local control) and asserts no commit; the suite no longer exports it suite-wide (tests/run-tests:556 comment; a group-scoped `export` remains at :15309, unset at :15534). Claim "no longer exported suite-wide, and tests/system-resources.md lists it": CONFIRMED (:16329-16330 checks both).
- what is left: a non-clone scratch repo with no remotes passes (intended); it remains an env switch that anyone can set for such a target.

### Maintainer item 9 claim: "refused in any clone ... before anything is staged"
- verdict: CLAIM CONFIRMED
- now: repo-save:48-77 sits before the "stage FIRST" step.
- what is left: nothing.

### repo-save push check skips commits any remote has
- verdict: FIXED
- now: devtools/repo-save:~273-286: `if [[ "$remote" == origin ]]; then excl=(--remotes=origin); else excl=(--remotes); fi`; `if ! push_commits="$(git rev-list "$br" --not "${excl[@]}" 2>&1)"` aborts with "could not list the commits". Commits only on private are judged for a push to origin.
- what is left: README.md:328-329 still says "on every commit" (now closer to true).

### repo-save / README identity wording (devtools/README.md:248, held:19)
- verdict: FIXED
- now: devtools/README.md (identity paragraph): "the `WANT` value of the identity job in `.github/workflows/checks.yml` ... not from the checkout's git configuration ... `held` takes the same identity from the same place"; devtools/held:19-27 reads WANT, refuses to guess.
- what is left: nothing.

### CI identity job passes with 0 commits on a forced update
- verdict: PARTLY
- now: checks.yml:63-70 `mapfile -t commits < <(git rev-list "$range")`; empty range -> `::warning::... examining the pushed tip $AFTER alone`, so n is never 0.
- what is left: on a force-push to main only the tip commit is examined; the rewritten earlier commits are still not. PR-event behaviour (empty `before`, synthetic merge commit) still not examined.

### pre-push hook scans only the net diff
- verdict: PARTLY
- now: devtools/repo-scan:61-72: net diff plus `git log -p --format= base..head` ("the lines each commit in between adds"); for a new branch (all-zero base) `git log -p ... "$RANGE_HEAD" --not --remotes`. devtools/README.md repo-scan row says so. Test of the hook now runs in the suite (below).
- what is left: (a) for a new/unknown-tip push the exclusion is `--not --remotes`, which includes `private`: commits that exist only on private (where real addresses are allowed) are not scanned commit by commit when a public branch is cut from them. (b) `git log -p` shows no diff for merge commits (no `-m`/`--cc`), so content introduced inside a merge is only seen in the net diff. (c) install-hooks.sh still does not report `core.hooksPath` overriding .git/hooks (unchanged, needs-check).

### repo-validate parses Python only for *.py
- verdict: FIXED
- now: devtools/repo-validate:125-131 `*.py) ;; *) first=$(head -n 1 "$f" ...); [[ "$first" =~ ^'#!'.*python ]] || continue`.
- what is left: devtools/py-coverage header ("exactly one Python file — bin/bt-capture") and tests/run-tests:9102/9107 ("the only Python here") unchanged.

### repo-scan accepts more emails than documented
- verdict: NOT ADDRESSED
- now: devtools/repo-scan:239-242 `grep -viFx 'giometti@linux.it'`, `'^(noreply|no-reply)@'`, `'^modprobe@|^systemd-'` unchanged; example.org still in :235-ish; devtools/README.md "Email: ..." sentence still lists only committer/lists/example.com.
- what is left: narrow `^systemd-` / `noreply@` to hosts, move giometti into the list, document or drop.

### public-addresses: Message-ID fragment a token ending in the mail host (G-02)
- verdict: CLAIM CONFIRMED
- now: devtools/repo-scan-public-addresses (end, "a FRAGMENT, not an address ... Matched whole ... any other address at that host is still refused ... cannot be listed per quoting file ... the gjzNncQ one, further up"). The substring argument holds (`git grep -F` finds the list file's own a token ending in the mail host line). Test: tests/run-tests:16417-16425 passes a token ending in the mail host and refuses a token ending in the mail host.
- what is left: nothing. (Judgement: my earlier note, "not an address", agrees with the maintainer; no finding.)

### held sync ignores failed push; relative msgfile
- verdict: NOT ADDRESSED
- now: devtools/held:69 `git push -q private "$HELD" 2>&1 | tail -1`; :74 `msg="${2:?devtools/held commit <msgfile>}"` after the `cd "$REPO"` (:17).
- what is left: check the push status; resolve the message path before the cd.

### Gates that pass when they did not run (awk-coverage, journal-contract, ci --recent)
- verdict: PARTLY
- now: FIXED: awk-coverage:75-77 "NOT RUN — gawk is required ... exit 2"; journal-contract:44-46 exit 2 without journalctl, and :211-214 exit 2 when `pass == 0`; ci:130-140 `--recent` exits 2 with "NO RUNS WERE READ" and on an empty answer (suite check at tests/run-tests:16470-16476). Remaining: awk-coverage:379-384 turns a red suite into exit 1 only inside `if [[ -n "$MIN" ]]`; without --min a red run still exits 0.
- what is left: make the red-suite exit unconditional (as devtools/coverage does).

### checks.yml "EIGHT JOBS"
- verdict: FIXED
- now: checks.yml:26 "# NINE JOBS, ON NINE RUNNERS AT ONCE (eight at the split of 2026-10-18; the identity job below is the ninth)".
- what is left: nothing.

### BRIEF "now says about a minute" / "seven in CI's check job"
- verdict: FIXED
- now: BRIEF.md:849 "this text said the header 'says about a minute', which it does not"; :857-859 "nine on 2026-11-16, and its header now says 'NINE JOBS'".
- what is left: nothing.

### Branch convention: README points to reviews/README.md
- verdict: PARTLY
- now: README.md:299-303 "By the convention in reviews/README.md, an assessment is written on a branch review/<UTC timestamp> ...; which remote holds such a branch at a given time is not fixed (the 16 old remote branches were deleted ...)". repo-save still routes review/* to private only.
- what is left: reviews/README.md:17-31 ("The convention") still defines only file names, no branch rule; so the cited convention still does not contain the branch convention.

### devtools/README: commit-message scan, review-open words, Notes list
- verdict: NOT ADDRESSED
- now: devtools/README.md:246 "`repo-save` also scans the **commit message** for addresses" (code: MAC/BSSID shapes only); devtools/review-open unchanged; Notes list not extended.
- what is left: reword to "MAC/BSSID-shaped addresses"; align review-open closed words and the Notes list.

### devtools/save output filter / budget count
- verdict: NOT ADDRESSED
- now: devtools/save:160 filter unchanged (`all syntax`, `  ✓ message`, ... no `all checks passed`, `✓ tests`, `nothing to commit`).
- what is left: extend the filter.

### Tests for hook and journal-files tool run by nothing
- verdict: FIXED (one script remains manual, honestly labelled)
- now: tests/run-tests:16478-16498 runs hooks/test-pre-push.sh ("passed 8, failed 0") and test-bt-journal-files.sh (if zstd) in a scratch world; test-journal-fast.sh header (:6-8) says "it is NOT run by the suite or CI ... says NOT RUN with exit 2 where there is no boot -1"; the day defaults to the day boot -1 ended (`D=${1:-$(date -d "$B1END" +%F)}`), no hard-coded date (asserted at tests/run-tests:~16500).
- what is left: windows fixed at 09:00-13:00 of that day can still be empty on both sides and print PASS (vacuous compare), unchanged.

### Stale comments (.gitignore, assert-test-catches, status)
- verdict: PARTLY
- now: .gitignore:6-11 rewritten ("a name rule and nothing more ... logs under other names are tracked too") FIXED; assert-test-catches:24 REVIEWED-KEEP paragraph still splits the sentence and `grep -q "✗.*$WANT"` unchanged; status "NOT on the bus" unchanged.
- what is left: cosmetic.

### Executable-bit check edge cases (my New defect 3)
- verdict: PARTLY
- now: devtools/repo-validate:~210-214 `git ls-files -s -- ":(literal)$f" | head -1`; `[[ "$mode" == 120000 ]] && { nexec=$((nexec - 1)); continue; }` fixes symlink and glob issues.
- what is left: still silently skipped when .github/workflows/checks.yml is absent (repo-validate:~200 `if [[ -f ... ]]`); by design for scratch repos.

### Spot-check of items I had FIXED in recheck (identity from WANT, coverage-exclude ranges)
- verdict: FIXED (2 spot-checked, no regression)
- now: repo-save:201 reads WANT from checks.yml; checks.yml:52 still `WANT: "Iaroslav Voitovych <yaroslav.voytovych@gmail.com>"`. coverage-exclude diff not re-derived against changed tools this round (file changed by 14 lines; ranges for devtools/ files unchanged; devtools/awk-coverage grew by 5+ lines at :72-77 and :376-384 but its excluded ranges 210-251 / 292-358 are earlier/later: re-derived, no problem (see New defects 1)).

### Maintainer item 24: scan pattern for work-area paths / working-arrangement wording
- verdict: CLAIM CONFIRMED (operator, not done)
- now: devtools/repo-scan diff a8d0eb45..HEAD adds only the --range commit-by-commit scan and help-line range; no pattern for work-area paths or arrangement wording. grep of repo-scan for "/root/exp", "/home/user", "work area": no hits.
- what is left: operator's decision.

## New defects introduced by this round
1. WITHDRAWN after checking: coverage-exclude was re-derived in this round (devtools/coverage-exclude:142-143 now 211-252 and 293-359, +1 each, matching the awk-coverage edit; sed shows 211 and 252 open/close the profile reader). Original worry: devtools/awk-coverage:75-77 gained 2 lines (comment line + NOT RUN message) before the excluded inline programs (`devtools/awk-coverage:210-251`, `:292-358` in devtools/coverage-exclude). The coverage-exclude diff this round touched 14 lines but I did not see these two ranges re-derived; if the ranges were not shifted, the stale-exclusion check (CI) would fail or hide lines. Not verified (file not recomputed).
2. repo-scan --range for a new branch uses `--not --remotes` (repo-scan:~64) while the identity push check was deliberately changed to `--remotes=origin` for the same reason (repo-save comment: "a commit that exists only on `private` has not been published"). Same defect class left in the scan: private-only commits (which may hold real addresses) are skipped when a public branch is built from them. Medium.
3. devtools/journal-contract:18 header typo "# # host with no usable journal" (stray `#`), cosmetic.
4. devtools/repo-scan-public-addresses new entries add `@lists.alioth.debian.org` and `@lists.ubuntu.com` host patterns (list hosts, consistent with the rule) and person addresses with comment citing systemd/Ubuntu source packages; a journal file name, a journal file name, a journal file name are exact tokens that are not addresses and pass in every file (documented). Low.
5. No elided "…" identifiers and no machine-local paths found in the new text of the changed devtools files; bench.sh now derives its path from the script (fixes /root/exp/...).

---

# Part: tests-1

## tests-1 recheck2 against the checkout of main bbec102f (tests/run-tests now 17214 lines)

### Upgrade rehearsal "17 checks" (was NOT ADDRESSED)
- verdict: FIXED
- now: tests/README.md:381 "(20 checks, the `ok` lines of `tests/system-upgrade`; its last line, "all N upgrade checks pass", gives the count of a run)"; tests/system-upgrade still has 20 `ok "` sites and the "all $pass upgrade checks pass" line
- what is left: nothing (the bullet list below still omits three checks; cosmetic)

### autostop missing from the bt-trial guard (was NOT ADDRESSED)
- verdict: FIXED
- now: tests/run-tests:16747 `BT_TRIAL_ACTING_VERBS='autostart|autostop|start|ok|hang|abort|step'`, :16749 LOOSE and :16752 TRIALCALLS use it; plus a new check that derives the verbs from tools/bt-trial and fails on an unknown one (`tools/bt-trial has verb(s) the guard knows nothing about`, ~17015)
- what is left: nothing

### README rule 4: report calls "set BT_REPO on their own line" (was NOT ADDRESSED)
- verdict: NOT ADDRESSED (low)
- now: tests/README.md:67 "the `report` calls set `BT_REPO` on their own line"; run-tests:2355, :5653 `env -u BT_REPO ... report` still unset it on purpose
- what is left: say "except the discovery tests, which unset it"

### awk -f trap check: `|| true`, misleading count (was NOT ADDRESSED)
- verdict: PARTLY
- now: fixed: tests/run-tests:2205 `if [[ -z "$offenders" ]] && (( ${#SHFILES[@]} > 0 )) && [[ -d tools && -d bin ]]` (missing directories now fail). Left: :2203 still `grep -rnE ... tools/ bin/ 2>/dev/null | grep -vE ... || true` (a grep error with the dirs present is still "no offenders") and :2206 still prints `(${#SHFILES[@]} files)` although only tools/ and bin/ are scanned. The exhibit-scan check also still ends in `|| true` at :3964 with no count of what it scanned.
- what is left: read grep's rc and print the scanned file count

### results.tsv width check vacuous (was NOT ADDRESSED)
- verdict: FIXED
- now: tests/run-tests:3496 `if [[ -z "$WIDTH" ]] && (( $(wc -l < evidence/trials/results.tsv 2>/dev/null || echo 0) >= 2 ))` (a missing or header-only file now fails)
- what is left: nothing

### whole-boot-reads.txt: all 41 pending (was NOT ADDRESSED)
- verdict: NOT ADDRESSED (maintainer lists it as open)
- now: 43 entries, 41 still `pending`; header tests/whole-boot-reads.txt now says "the other 41 are still "pending" — the scan counts them, the tools' owners decide". Scan widened to devtools/ (two reasoned entries added).
- what is left: decide each of the 41 reads

### Stale counts and comments (was NOT ADDRESSED)
- verdict: PARTLY
- now: fixed: run-tests:481 now "every other mktemp of the run live inside it". Left: :268 "This file calls mktemp in 80 places"; :2031 "The fixture holds 5 rows"; :3779 and :3790 `grep -o '...[^\n]*'`; :5054 `CHAIN'"'"'S LAST RUNG`
- what is left: four stale or cosmetic lines

### `--section` ignores --serial/--jobs (was NOT ADDRESSED)
- verdict: FIXED
- now: tests/run-tests:167 `out=$("$0" --jobs "$SUITE_JOBS"); rc=$?`, with a test (SECJ) that asserts the line
- what is left: nothing

### README fixtures table: sanitize-logs.sh path, missing files (was NOT ADDRESSED)
- verdict: NOT ADDRESSED
- now: tests/README.md:301 `| sanitize-invariants.log | sanitize-logs.sh |`; whole-boot-reads.txt, unit-state-changes.awk, system-resources.md still not named in README
- what is left: path and three mentions

### NEW: six wrappers vs "five" in README and comment (was a new defect)
- verdict: FIXED
- now: tests/README.md:61 "one of six wrappers (`trial`, `trial_in`, `tl`, `tlt`, `tlnh`, `tlru`)"; run-tests:17022 "Six functions run"; check :17031 `>= 6`

### NEW: suite-wide BT_REPO_SAVE_CONFIG_IDENTITY bypass (was a new defect)
- verdict: FIXED
- now: tests/run-tests no longer exports it suite-wide (comment :556 "never here, never suite-wide"); set at :15309 for one group and unset at :15534; tests/system-resources.md:133 lists it with the refusal rules; extra tests at :15909 and :15920 (empty identity, network remote)
- what is left: nothing

### NEW: bt-incident session counts compare a total over two directories (was a new defect)
- verdict: NOT ADDRESSED (theoretical, low)
- now: tests/run-tests:8124, :8192 `ls -1 evidence/sessions "${BT_EVIDENCE_REPO:?}/evidence/sessions" 2>/dev/null | wc -l`
- what is left: nothing needed unless the tightening is wanted

## Spot-check of earlier FIXED items
- 2 of 2 still fixed: README awk floor 95 (tests/README.md:~427, checks.yml:301); PIPEFAIL demo `bad` branch (run-tests ~3500s, text "the rule's premise no longer holds").

## Maintainer's claims (reviews/2026-11-16T0000Z-project-review-recheck-checks.md, "Tests (item 23)")
- "counts in tests/README.md and whole-boot-reads.txt": CLAIM CONFIRMED (README:381 20 checks, six wrappers; whole-boot-reads.txt header states 43 and 41 pending).
- "`autostop` in the bt-trial guard": CLAIM CONFIRMED (run-tests:16747).
- "`--section` keeping `--serial`": CLAIM CONFIRMED (run-tests:167).
- "the vacuous width check": CLAIM CONFIRMED (run-tests:3496).
- "the four `|| true` checks": CLAIM REFUTED in part: the awk -f trap check (run-tests:2203) and the exhibit scan (:3964) still end in `|| true` with no rc check. I cannot tell which four the maintainer means; four other `|| true` sites in the new tests (e.g. TJF_DATES, CLNR) are count pipelines and fine.
- "fixture built from the live results.tsv": CLAIM CONFIRMED (run-tests ~9780 `TA_HDR=$'timestamp\t...'`, ta_repo no longer reads evidence/trials/results.tsv).
- "the system-roundtrip gate and empty list": CLAIM CONFIRMED (tests/system-roundtrip diff: `NDEST` guard `(( ${NDEST:-0} < 10 )) -> bad`; gate order comment). The reordered gate block in the diff is shown with identical lines, so the specific-refusals-first reorder was not independently checked.
- "the silent skips": CLAIM CONFIRMED in effect: run-tests:41 `command -v python3 ... || { echo "run-tests: python3 is required"...; exit 2; }`; the four `if command -v python3` blocks remain (:9125, :14665, :15101, :15141) but can no longer be skipped.
- "weak globs", "duplicate description": not verified.
- "Open: the 41 pending reads; missing commands in tests/machine-tools and staged --apply tests": consistent with the files (pending still 41; I did not check machine-tools).
- "A review-fix section (37 checks) and 16 blocks (40 checks)": not verified (count requires a run).

## New defects introduced by this round
- Low: new check "every tracked executable is named in docs/tooling-index.md" (run-tests ~3385, `tix_named`) accepts a match on the bare file name as a substring anywhere in the index. For 9 of the executables it is the only match (bin/bt-hang-watchdog, bin/bt-mark, bin/bt-trace, devtools/repo-validate, devtools/journal-speed/bench*.sh, scripts/bt17-review-pack/build*.py), so "named" can mean "the word occurs in prose". It does fail for an unmentioned tool (tix_n >= 100 guard present), so it is weak, not vacuous.
- Low: the four `if command -v python3 ...; then ... fi` blocks with no else remain (run-tests:9125, 14665, 15101, 15141); harmless now that line 41 requires python3, but dead conditionals.
- Other new checks read in the first third of the diff (hciconfig unprobed/ended_unprobed with control, tooling-index, restore/changes docs, dyndbg comment, bt-verify-install raw-archive with control, bt-evidence passive with control, bt-env-history by column, bt-usbmon 0700, bt-trial-audit UNRESOLVED with control, journal.sh fast path with control, bt-retention note): each has a control or a negative that can fail. No new elided paths or machine-local paths seen.

---

# Part: tests-2

## tests-2 recheck 2 against the checkout of main (bbec102f); line numbers are the checkout of main's tests/run-tests unless noted

### Weak glob assertions (5439, 5496, 7828 before)
- verdict: FIXED
- now: 5558 `grep -qE '^  HCI command timeouts:[[:space:]]+2$' <<<"$SOK"`; 5615 `grep -qE '^  btsnoop files:[[:space:]]+2$' ... '^  capture gaps logged:[[:space:]]+3$'`; ~8057 the join is now checked by column with awk `$4 == "N" && $5 == "on"` (3 rows with metrics, 3 rows of ? without)
- what is left: nothing

### README rule 4 vs the six-verb guard
- verdict: FIXED
- now: tests/README.md:64-70 "a second check fails on a spelled-out `tools/bt-trial <verb>` call of a verb that ACTS (`autostart`, `autostop`, ...). The read-only verbs (`report`, `status`, `audit`) are not in that guard"; run-tests ~16740 BT_TRIAL_ACTING_VERBS / BT_TRIAL_READING_VERBS, ~17009 a derived-verb check over tools/bt-trial's case labels (audit, start, autostart, autostop, step, hang, ok, abort, report, status = 10, check needs >=9)
- what is left: nothing (9941 `audit --help` stays outside the guard, now by documented design)

### Duplicate check description
- verdict: FIXED
- now: 8312 `ok "bt-usbmon rejects an unknown argument"` and 8772 `... also with every seam declared (the um harness)`
- what is left: nothing

### Fixture derived from the real tracked evidence/trials/results.tsv
- verdict: FIXED (in my range)
- now: 9786 `TA_HDR=$'timestamp\ttrial_type\t...'` literal header; ta_repo (9787) and 9827 `TAU=$(ta_repo none 2026-07-01T00:00:00+02:00)` no longer read evidence/trials/results.tsv. (3703/3717 still `head -1 evidence/trials/results.tsv`, outside my range, read-only, header only.)
- what is left: nothing in range

### Stale/dangling comments
- verdict: NOT ADDRESSED
- now: 6538 "Declared here; it is READ 4000 lines below" (read is at 17170); 6706 "THE SANDBOX ITSELF ..." comment above `else`; 9961 "THE POSITIVE CONTROL, WHICH IS THE WHOLE ANSWER ..." above an unrelated heading; 6567 "these nine" (assertions) vs 6611 "turning eleven assertions red"
- what is left: fix or delete the four comments

### New defect: suite ran runtime-mgmt-test.sh load/restore unstubbed (maintainer item 9)
- verdict: FIXED; maintainer claim CONFIRMED
- now: old call removed (15805 comment "moved to review fixes of 2026-11-16"). New block 16124-16140: ten stubs (modprobe rmmod insmod systemctl bluetoothctl btmgmt btmon rfkill loginctl hciconfig) each `echo "<tool> $*" >> $RM/calls.log`; `PATH="$RM/stubs:$PATH" scripts/runtime-mgmt-test.sh "$_v" patched`; assert `[[ -z "$RMBAD" && ! -e "$RM/calls.log" ]]`. Stubs are first on PATH and the assertion is that no stub was called. In scripts/runtime-mgmt-test.sh the `load|restore)` case (line 94) is above `guard` (50, root check at 69) so the refusal is reached also as non-root; the swap code is gone (line 97 only prints REFUSED ... EX-046). guard() now fails closed (lines 53, 64, 67 "gave no usable answer"); the test drives 8 fail-closed cases with `trigger x` and asserts no stub call.
- what is left: nothing (a stub list cannot catch an absolute-path call, but the swap code no longer exists and a test greps for it: `! grep -qE 'load_disabled|restore_disabled|modprobe -r|insmod "'`)

### New defect: unguarded `shift 2` scan excludes tools/lib/journal.sh wholesale
- verdict: NOT ADDRESSED
- now: ~15800 `| grep -vE 'tools/lib/journal\.sh' || true)`; pattern still `shift 2( ;;|;|$)`
- what is left: guard journal.sh's shift in the tool and drop the path exception, or name the line

### New defect: weak globs in new checks
- verdict: NOT ADDRESSED
- now: 16098 `*"no SCO setup"*" 0 "*" 1"*`; 16094 `*"1/2"*"50%"*`
- what is left: match the table row with awk by column

### New defect: hard-coded "all 18 option loops"
- verdict: NOT ADDRESSED
- now: 15788 `ok "... in all 18 option loops, none spins"` (list has 18 entries; text is not derived)
- what is left: print "${#_specs[@]}" instead of 18 (Low)

### Spot checks of FIXED items from recheck 1 (3 of 3)
- capdiff window check 7841 `*"The paths agree"* && != *"coverage question"*`; sessions counts 7886-ish still `ls -1 evidence/sessions "${BT_EVIDENCE_REPO:?}/evidence/sessions"`; `--replace` check `[[ -s "$BKJ/calls.log" ]]` still present. No regression.

## Maintainer claims (tests/ part of reviews/2026-11-16T0000Z-project-review-recheck-checks.md)
### Item 9, "stubbed first on the path and asserts that none was called"
- verdict: CLAIM CONFIRMED (see above)
### Item 23, "counts in tests/README.md and whole-boot-reads.txt"
- verdict: CLAIM CONFIRMED
- now: tests/README.md "20 checks, the `ok` lines of tests/system-upgrade"; `grep -cE 'ok "' tests/system-upgrade` = 20 and line 321 `echo "all $pass upgrade checks pass"`; whole-boot-reads.txt header "43 reads in 23 files ... the other 41 are still pending". "six wrappers" in README matches the new tlru (guard requires >= 6).
### Item 23, "autostop in the guard", "--section keeping --serial", "system-roundtrip gate and empty list"
- verdict: CLAIM CONFIRMED
- now: BT_TRIAL_ACTING_VERBS='autostart|autostop|start|ok|hang|abort|step'; SECJ check (`out=.*--jobs "$SUITE_JOBS"`); tests/system-roundtrip: specific refusals first, installation gate last, and `if (( ${NDEST:-0} < 10 )); then bad "only ... derived"`.
### Item 23, "Open: 41 pending reads; machine-tools missing commands; staged --apply tests only 0cf3:e300"
- verdict: CLAIM CONFIRMED as open (whole-boot-reads.txt says pending); not re-verified for machine-tools.

## New defects introduced by this round (diff a8d0eb45..HEAD, tests/run-tests +1261 lines; read from ~line 640 of the diff to the end, plus the head)
- Low: tools/sanitize-logs.sh test (SLD block, ~14000) asserts that link-local IPv6, dotted `0011.2233.4455` and bare 12-hex strings are LEFT in the output and fails when the tool starts to redact them. The suite's own rule (comment at ~9168 on a test that "asserts the defect") warns against this; the message does say "update the header (and this test)", so it is a deliberate pin, but it makes a safe improvement fail the suite.
- Low: `NINE JOBS` check greps checks.yml's header text and counts jobs (9) - a doc-coupled hard number; fails on adding a job without editing the header (intended).
- Low: BT_REPO_SAVE_CONFIG_IDENTITY is exported at the start of the repo-save group and unset after "the last repo-save call of the group"; a failure or reordering in between leaves it exported for later checks in that worker. The later check "is not set in this section's environment" only proves it for its own section.
- No new check found that cannot fail in the ~1,260 added lines beyond the above; every new block carries a control case (clean/identical/valid input) or a guard on the extracted artifact (`[[ -s job.sh ]]`, `[[ -s compare.py ]]`). All new scripts referenced exist on the checkout of main.

---

# Part: tests-3

(the checkout of main = tip bbec102f. tests/run-tests grew to 17214 lines; located by text.)

### machine-tools omits machine tools shipped code calls
- verdict: NOT ADDRESSED
- now: tests/machine-tools unchanged (line 28 still names pw-metadata and gsettings only in the runuser comment); gsettings, pw-metadata, dbus-monitor, dpkg, getent, ps, df, pgrep still unlisted. The checks doc (item 23) lists it as open, "waits for a full suite run": consistent.
- what is left: add the tools to the list.

### run-tests comment cites stale line numbers of its own file
- verdict: NOT ADDRESSED
- now: tests/run-tests:16808-16810 still "line 34 / line 70 / line 133"; actual `$0` uses are lines 35, 77 and 170 (grep -nE '"\$0"'). The file moved further (line 170 now `out=$("$0" --jobs "$SUITE_JOBS")`).
- what is left: update or drop the numbers.

### negative greps without a positive control (STRAY / SNTOUCH / CRTOUCH)
- verdict: FIXED
- now: run-tests:11079 `[[ -z "$STRAY" && -s "$SNDIR/summary.txt" ]]`; 11501 `[[ -z "$SNTOUCH" && -s tools/bt-snapshot ]]`; 11750 `[[ -z "$CRTOUCH" && -s tools/bt-crash ]]` (existence guard; not a planted-line control, adequate).
- what is left: nothing

### README floors / 17 checks
- verdict: FIXED (README floors, still 95); the "17 checks" line now reads tests/README.md "(20 checks, the `ok` lines of `tests/system-upgrade`; its last line ... gives the count of a run)" — matches the 20 `ok "` sites.

### system-roundtrip: unreachable experiment-mode gate
- verdict: FIXED
- now: tests/system-roundtrip:74-85: the trial and mode gates come first, comment "The order matters: the mode stamp lives INSIDE the installation directory", general "already has an installation" gate last.
- what is left: nothing

### system-roundtrip: empty derivation passes
- verdict: FIXED
- now: system-roundtrip `NDEST=$(grep -c . <<<"$DEST" || true)`; `if (( ${NDEST:-0} < 10 )); then bad "only ... install_file destination(s) derived"`.
- what is left: nothing (system-upgrade still compares counts only, as before).

### Silent skips (python3 / zstd / tool-absent)
- verdict: PARTLY
- fixed: run-tests:41 `command -v python3 ... || { echo "run-tests: python3 is required ..." ; exit 2; }` removes the python3 silent skips.
- left: run-tests:10505 (`if ! command -v zstd ...` still skips the copy cases, reported only inside an ok text); `kcheck()` (14651) still `command -v "$3" || return 0`; the new `command -v xz && xz -k` (btusb-has-device test) and the zstd branch for test-bt-journal-files.sh (prints "· zstd is not installed: ... did NOT run", but not in the final NOT ASKED block, 17180 `for _ns in ...` unchanged).
- what is left: route those to a *_SKIPPED note.

### staged --apply only with the positive-control device
- verdict: NOT ADDRESSED
- now: run-tests:12927 and 13047 `stage_install BT_VID=0cf3 BT_PID=e300` (doc item 23 lists it as open).

### btmon README cases table
- verdict: NOT ADDRESSED (tests/btmon unchanged; not in the checks doc).

### NEW 1: light mode and its filter fixture untested by the suite
- verdict: PARTLY
- now: light mode IS in the suite on the checkout of main: run-tests:12111-12112 (`uistub logger`), 12539ff `status-light`, `start-light`, repeated-tick, reboot case, `enable-light`/`disable-light`/`stop-light`, root refusal (12586-12607), header check 12622 ("NOT PASSIVE, ONE STEP"... "--register-shell-events"); `bt-ui-atspi.py` registration_mode at 16688-16701. Commits 58d98049 ("17 uiok" checks) and 700122cb are right. The checks doc (item N-10: "Light mode is still exercised only by scripts/prove-ui-capture.sh: open") is WRONG for the verbs — the doc was not updated after those commits (WITHDRAWN as to the maintainer's own "open").
- still true: the shell filter (`bt-ui-atspi.py --check-filter`) and tests/fixtures/ui-atspi-shell-filter.tsv are referenced only by scripts/prove-ui-capture.sh:504-507 (grep run-tests: no `check-filter`, no fixture name); tests/README.md fixtures table does not list the fixture; no CI/devtools runs prove-ui-capture.sh.
- what is left: a run-tests check feeding the fixture through `--check-filter`; correct the checks doc.

### NEW 2: bt-raw-archive install test takes one branch per checkout path
- verdict: NOT ADDRESSED
- now: run-tests:12945-12951 `SIRAWSRC=...; if [[ "$SIRAWSRC" == "$PWD/scripts/raw-capture-archive-all.sh" ]]` unchanged.

### NEW 3: whole-boot-reads header count
- verdict: FIXED
- now: tests/whole-boot-reads.txt:13-15 "...41 reads in 21 files. Since 2026-11-15 ... 43 reads in 23 files (the two added have their reason; the other 41 are still "pending"...)". 

### NEW 4: BT_REPO_SAVE_CONFIG_IDENTITY bypass
- verdict: FIXED
- now: no longer exported suite-wide; exported at run-tests:15309 and unset at 15534 within the one "publish gates" section; tests/system-resources.md lists it ("It is **not** exported for the run"); tests at 16276ff/15909-15920 cover a network pushurl, url.*.insteadOf/pushInsteadOf, a clone of the project, a repo tracking devtools/repo-save.
- note: export/unset sit in the same section, so no leak into other workers; if a check between them aborts the shell the unset is skipped (section-local only).

### NEW 5: leftovers (marker, runtime-mgmt-test for real, shift-2 scan, ok-text)
- verdict: PARTLY
- fixed: `MARKER-NEW-TESTS-END` gone; runtime-mgmt-test load/restore now run with modprobe, rmmod, insmod, systemctl, bluetoothctl, btmgmt, btmon, rfkill, loginctl, hciconfig stubbed first on PATH and `! -e calls.log` asserted (16124-16140); the script's swap code is removed.
- left: run-tests:15799 `RFUNG=$(grep -rnE 'shift 2...' tools bin ... || true)` still scans only tools/ and bin/ with no positive control; run-tests:15391 ok-text still "refuses an author that is not the checkout's identity" while the asserted message (15390) is "not the expected identity".

### Maintainer claims checked
- "bt-archive ... Test: 4 checks" (item 7): CLAIM CONFIRMED — run-tests:15861, 15869, 15876, 15880 (plus the 3 earlier --replace ok lines at 15828-15840).
- "A review-fix section (37 checks) and 16 blocks (40 checks)": CLAIM REFUTED (minor): `ok "` lines added by cb982cb5 = 39 and by 8cf56cc7 = 38; the 2026-11-16 section has 38 (16116-16722). Counts off by 1-2.
- "the four `|| true` checks ... fixed", "the silent skips": CONFIRMED for the four greps; the silent-skip claim is only partly true (see above).
- "`--section` keeping `--serial`": CONFIRMED — run-tests:170 `out=$("$0" --jobs "$SUITE_JOBS")`, and a check at the end of the 11-16 section (SECJ).
- "counts in tests/README.md and whole-boot-reads.txt": CONFIRMED (six wrappers incl. `tlru`, 20 checks, 43 reads in 23 files; wrapper check now `>= 6`, 17032).
- "`autostop` in the bt-trial guard": CONFIRMED — run-tests:16741 `BT_TRIAL_ACTING_VERBS='autostart|autostop|start|ok|hang|abort|step'` and a derived-verb check (17009ff).
- "N-10 light mode: still only prove-ui-capture.sh": CLAIM REFUTED for the verbs (see NEW 1); the commit messages "light mode and its keeper tested in place" and "block stubs logger" are true (58d98049, 700122cb); true only for the shell filter fixture.
- "system-roundtrip gate and empty list": CONFIRMED.

## New defects introduced by this round
- Low: run-tests new section 16116-16722 hard-codes counts of other files: `"passed 8, failed 0"` from devtools/hooks/test-pre-push.sh and the string 'NINE JOBS' / 9 jobs in checks.yml: legitimate doc-coupling, but brittle (breaks on any added case/job).
- Low: the 2026-11-16 section runs many real scripts (`devtools/*`, `scripts/*`) from the real checkout with only per-test PATH stubs; machine-tools protection still applies, but `scripts/sco-ledger.sh`, `bt-device-record.sh` etc. run under `BT_BLUEZ_STORE` only (seam added to system-resources.md, good).
- Low: checks doc counts (37/40 checks) and the N-10 line are out of step with the tree (see above).
- Otherwise none found in the added tests: stubs are placed first on PATH, scratch repos and mktemp dirs, placeholders AA:BB:CC:00:00:0x and "Test Headset" only.

---

# Part: history

## recheck2, history part (the checkout of main bbec102f). Paths below are the checkout of main lines.

### Milestones: BlueZ "Phase 36" (HISTORY.md:6)
- verdict: FIXED
- now: HISTORY.md:6 "BlueZ patches made ready in Phase 36, sent (09-19) and applied (09-21) in Phase 37"
- what is left: nothing

### Milestones stop at 2026-11-07 (HISTORY.md:11-15)
- verdict: PARTLY
- now: four new milestone entries for 11-07..11-16 were added (HISTORY.md:16-21), but HISTORY.md:11-12 still says "the hand-off blocks BRIEF carried from 2026-10-03 to 2026-11-07, verbatim, at the end"; the last moved block is the 11-12 block (:5709, moved 11-14)
- what is left: change "2026-11-07" to "2026-11-12"

### Phase 34 "pushed into a 9-byte endpoint"
- verdict: FIXED
- now: HISTORY.md:2727-2730 "[Note, 2026-11-16: 'pushed into a 9-byte endpoint' is the wording the fourth review withdrew; ... `len 27 mtu 9` is that split, not an overflow; DR-02 ...]"
- what is left: nothing

### Phase 18 "first EARLY reset ever captured" vs Phase 10
- verdict: PARTLY
- now: HISTORY.md:913-915 note "conflicts with Phase 10 ... Which capture was first has not been settled here; read the sentence as this incident's". The conflict is flagged, not resolved; the exhibits settle it (EX-004 window is 2026-08-12 00:09; Phase 10's session evidence/sessions/20260811-002156-early-mode-SUCCESS is a day earlier), and BRIEF §3 still says "the one reset issued before any timeout recovered it" (BRIEF.md:315-317).
- what is left: say Phase 10's was first; BRIEF §3 "the one" is then also wrong or must name which

### Phase 30 "Eight residual sentences" names seven
- verdict: FIXED (by dated note)
- now: HISTORY.md:3278-3280 "[Note, 2026-11-16: the count says eight and the list names seven; which eighth sentence was meant is not recorded here.]"
- what is left: nothing

### 1836 s vs 1837 s
- verdict: FIXED (by dated note)
- now: HISTORY.md:1861-1863 note: EX-021 gives 1836.465 s; "the same number rounded two ways". Spot-check: evidence/exhibits has EX-021 (exists). CLAIM CONFIRMED that EX-025/EX-029 say 1837 (not re-opened).
- what is left: nothing

### CO-04 competing patch 9 of 12 vs 8/12
- verdict: PARTLY
- now: HISTORY.md:4122-4124 note says the two counts "are not reconciled in the repository" (4121 and 5306 say 9 of 12, 5602 says 8/12). Honest, but unresolved.
- what is left: re-count and state one number (contributions/README.md CO-04 row says 8 of 12)

### Identifier elision after 2026-09-18
- verdict: PARTLY
- now: FIXED: HISTORY.md:4496 `reviews/2026-11-14T0300Z-kernel-patches-ready-to-send-for-outside-review.md` in full. NOT ADDRESSED (moved-verbatim blocks, maintainer item 20/21 keeps them unchanged): Message-IDs `…` at :5093, :5121, :5412 (and the 10-29 one), srcversion/sha `…` at :4818, :4828, :4832; paths `patches/mesh-tester/0001-…` :4739. BRIEF.md:825 still has `815e7378…b90b72` (09-24 text).
- what is left: either write the Message-IDs/hashes in full or state in the heading that verbatim blocks keep their elisions; BRIEF:825 sha

### Broken references inside moved blocks
- verdict: NOT ADDRESSED
- now: HISTORY.md:5020 `patches/mesh-tester/bluez-shared-mgmt-notify-leak-on-d84171e6c-2026-10-08/` (tree dir has no date suffix); :5030 and :5146 `power-off-compare-2026-10-05.md` (not tracked)
- what is left: an inline dated note in each block, as was done for the chapters

### BRIEF §10 pointer
- verdict: FIXED (re-verified, not regressed)
- now: BRIEF.md:907 "dated chapters to 2026-11-16" ; HISTORY.md:4602 is the 2026-11-16 chapter

## Maintainer's claims about my part (checks doc items 13 and 20)

### Item 13 (BRIEF lines): "right"
- verdict: CLAIM CONFIRMED (with exceptions listed in the next sections)
- now, each checked in the checkout of main: -42 line BRIEF.md:19-ish "the laptop left `-42` on 11-12 (above; corrected 2026-11-16)"; persistent timer "replaced 2026-11-13 by the persistent `bt-raw-archive.timer`" (:105, :137); open investigations "BT-12 to BT-15 are released, queued upstream or not ours" (:138); branch names ":51" `tests/test-suite`; "Last updated: 2026-11-16" (:155); survivals plural BRIEF.md:338-341 "The two survivals"; trial dir "trial-NN.unclosed-<time>" matches tools/bt-trial:312 `$1.unclosed-$(date -u +%Y%m%dT%H%M%S)`; `build=stock` qualified, tools/bt-trial:143 "`build=stock` names the KERNEL and nothing else"; nine CI jobs: .github/workflows/checks.yml:26 "NINE JOBS" and 9 job keys (identity, suite, serial, coverage, comprehension, awk-coverage, python-coverage, isolation, system); §9.2 survey "the operator dropped it" with comms/2026-10-19T0601Z-... which exists.
- what is left: nothing for those items

### Item 20 (HISTORY.md "dated correction notes ... blocks moved there verbatim unchanged"): "partly"
- verdict: CLAIM CONFIRMED
- now: six dated notes added (HISTORY.md:913, 1861, 2727, 3278, 3343, 4122), moved blocks not edited (consistent with "verbatim"). The reviewer's partly stands: the notes for the Phase 18 and CO-04 items do not resolve the conflict.

## Contradictions remaining inside BRIEF.md (the checkout of main)
1. State block heading BRIEF.md:79 still "(2026-10-28; machine lines 2026-10-30; stale lines corrected 2026-11-15 where marked ...)" while its body now mixes 10-28, 11-12, 11-15, 11-16 text; the "Waiting for replies" line is now honestly labelled "not re-read since" (:94) - acceptable, but CO-02 "no human reply on 10-28 ... 2026-11-02" (:97) is older than the hand-off's v2 status ("Not ready: CO-02 v2 ... deadlocks ... 3 of 3, 11-15").
2. Hand-off line "CI: green on every push since `2a3f253` (11-14)" (BRIEF.md:225) is not marked superseded, while HISTORY.md:4562-4580 and :4660-ish say CI went red five times on 11-15 and three more times on 11-16 (green again on `d5695d8`). The hand-off block is "the one of 11-14" per :155, so this is a dated statement, but "Last updated 2026-11-16" and the "corrected where marked" convention leave it looking current.
3. The 11-14 hand-off block (BRIEF.md:171-250) does not mention anything of 11-15/11-16: CO-46 (journalctl), the bt-ui-capture light mode, U21's second occurrence, the whole-project review and its recheck, the CI reds. `grep CO-46\|light mode\|U21 BRIEF.md` = no hit. The §0 rule says the hand-off is "one block ... replaced, not topped up" and "carries forward every pending send and open decision"; HISTORY's 11-15/11-16 chapters hold decisions (the operator's CO-46 backport request, reviewer 7's asks, lane 11) that BRIEF's hand-off does not carry.
4. §9.9 BRIEF.md:~783-796: the Updated 11-16 parenthetical and consequence (a) now both say load/restore are refused (exit 2); the line "A reboot restores all" was removed; consistent. But the block's heading still reads "Closed ... The record below is kept as written" while being edited in place twice (11-15, 11-16): mild convention conflict, not a factual one.
5. §4 vs §2: now consistent (two survivals; §2 table has one survival row and the second is EX-031 in §3, explicitly cross-referenced at BRIEF.md:338-341).
6. BRIEF.md:825 `sha256 815e7378…b90b72` is an elided identifier in BRIEF's own rule §7 (":504 Write identifiers in full ... Never `…`"); BRIEF.md:49 "`EX-033`…`EX-053`" is a range, not an identifier.
7. §6 CI-bot sentence (BRIEF.md:~393) now says only "time zone not settled ... read as UTC 3 h 21 min and 3 h 26 min"; patches/bluez/README.md:148-153 (noted 11-16) gives a most-likely reading, CEST, 81 and 86 minutes "consistent with 'within 90 minutes'". BRIEF omits that likelier reading, HISTORY.md:3343-3347 also; the three documents give the reader three framings.

## BRIEF vs HISTORY (new text)
- HISTORY.md:3346 "`BRIEF.md` §3 has the same correction": wrong section. The CI-bot correction is in BRIEF §6 ("## 6. The BlueZ patches", BRIEF.md:365 heading; the sentence is at ~:393); BRIEF §3 (:301) has none. NEW DEFECT.
- BRIEF §10 :907 "dated chapters to 2026-11-16" matches HISTORY.md:4602.
- BRIEF.md:224-229 (16 old branches deleted, public repo has `main`, `tests/test-suite`, `research/journalctl-file-scaling` and the review branch) agrees with HISTORY.md "The operator deleted the 16 old remote branches" (11-15 chapter).
- BRIEF.md hand-off "Not ready: CO-02 v2 ... 3 of 3, 11-15" agrees with HISTORY.md:4540-4547 ("11-15: the CO-02 v2 claim withdrawn ... 3 of 3 times").
- HISTORY 11-15/11-16 chapters vs BRIEF hand-off: they agree where both speak (CO-02 v2, branches, trial open so CI is the gate), but BRIEF's hand-off is silent on CO-46, light mode, U21 (see 3 above). HISTORY says (:4520-ish) "a chapter is now owed before each break ... session start reports"; BRIEF §10 repeats it.
- Referenced files in new chapters exist: reviews/2026-11-15T1751Z-project-review-fixes-reaction-checks.md, reviews/2026-11-16T0000Z-project-review-recheck-checks.md, contributions/CO-46-.../build-review-package.py, CO-02 .../review-fixes-20261115/, commits 700122c and d5695d8.

## New defects introduced by this round
1. HISTORY.md:3346 cites `BRIEF.md` §3 for the CI-bot correction; it is in §6.
2. HISTORY.md:11-12 milestone still says blocks "to 2026-11-07" though four entries were appended after it (:16-21): the paragraph now contradicts itself within the same bullet chain.
3. BRIEF hand-off CI line (:225) not marked superseded after HISTORY records red CI on 11-15/16 (see BRIEF contradiction 2).
4. HISTORY.md:4122-4124 note and :3343-3347 note leave their conflicts open ("not reconciled", "not established") while patches/bluez/README.md:150-153 offers a most-likely reading: three documents, three framings.
5. Elided identifiers in new text: none found in the new 11-15/11-16 chapters (HISTORY.md:4519-4709 contain no "…" identifiers).

---

# Part: exhibits

## Recheck 2: exhibits part against main tip bbec102f (checkout the checkout of main)
the checkout of main = the checkout of main. Evidence changed in 3 commits (2217cdf2, 3101f38d, 85c16ea9).

### Index rows repeat refuted/superseded claims (EX-007, 006, 086, 093, 058, 033, 036) [maintainer item 17; was NOT ADDRESSED]
- verdict: PARTLY
- now: the seven exhibits' own labels are now "**Historical claim (...)**" (e.g. evidence/exhibits/093-...md "**Historical claim (superseded by EX-094).**", 006 "(superseded in part by EX-009; one observation, `BRIEF.md` §5)"); the index cell is generated by tools/bt-exhibit:276 (`s/^\*\*Historical [Cc]laim[^*]*\*\* /Historical claim: /`), which keeps the word but drops the parenthesis. I regenerated the comparison with that rule: 97 rows / 97 files, 0 differences, all links and titles match. Index rows now read "Historical claim: No kernel error and no HCI command timeout on boot af3f9840 ..." (EX-093), EX-006/007/033/036/058/086 likewise; EX-018/020 as before.
- what is left: the index cell does not say WHICH exhibit supersedes (EX-093 row has no "superseded by EX-094", EX-086 none of EX-087); only EX-094's row says "Corrects EX-093". Low. Claim in the checks document ("through each exhibit's own title, so the generated index keeps them"): CONFIRMED for the word "Historical claim", REFUTED for the supersession target.
- "retitling broke references": no. Exhibit "# EX-nnn — slug" titles and file names are unchanged (only the claim label changed); `grep` for the old labels ("Claim (CORRECTED", "Claim (unsupported here)") finds nothing outside the exhibits; tools/bt-exhibit:195/257-276 and tests/run-tests:5963-5975 already handle "Historical claim" and have a test for it.

### EX-043 has no exit status and no redaction statement [item 17; was NOT ADDRESSED]
- verdict: FIXED (as a stated gap)
- now: evidence/exhibits/043-first-command-into-alt1-stream-dies.md:113 "| exit status | not recorded in this exhibit (added 2026-11-16 as a statement of the gap ...)", :114 "| redacted | not recorded in this exhibit ...". Also :61 a correction note that the "~90 ms" for EX-042 is unsupported - the source of BRIEF's old cell (the exhibit's own table line 58 "`EX-042` | ~90 ms" still stands, with the note beside it).
- what is left: nothing (the gap cannot be recovered). CLAIM CONFIRMED ("EX-043 ... state their gaps").

### EX-038 command contains an elided "…" [item 17; was NOT ADDRESSED]
- verdict: PARTLY
- now: evidence/exhibits/038-alt1-wedge-on-a-new-kernel-clean-window.md:42 still "journalctl --file /root/bt-journal-archive/boot-f5de8066.export.zst …", followed by :44 "*Note, 2026-11-16: the arguments after the file name were elided when this exhibit was written and are not recoverable ... not re-runnable as shown*".
- what is left: nothing practical; the elision is now declared. CLAIM CONFIRMED.

### EX-057 "all 16 answered" vs "-107" [item 17; was NOT ADDRESSED]
- verdict: FIXED (reading added)
- now: evidence/exhibits/057-e3-upstream-entry-16-links-two-headsets.md:89 note: "00:55:33.107 plus 270.68 s is 01:00:03.79 ... the -107 Disconnect is most likely that link's own hang-up, one of the 16 ... Whether the ledger's "answered" and the kernel's "-107" describe the same Disconnect was not checked against the capture." Arithmetic verified (ledger line 69 "00:55:33.107307 ... 270.68 hangup-ok 59 ms"; kernel line 39-40 at 01:00:03). The claim text still says "one Disconnect answered -107".
- what is left: nothing (honestly hedged).

### E1 headline: EX-056 subset of EX-058 [was NOT ADDRESSED]
- verdict: FIXED
- now: BRIEF.md:319-320 "`EX-058` carries the 58; `EX-056`'s 7 links are on boot `226965f1`, which `EX-058` also counts, and `EX-055` shows the setup loading, so the three are not summed"

### EX-031 "alt 1" not shown in exhibit [was PARTLY]
- verdict: WITHDRAWN (overstated)
- now: BRIEF.md:326-327 "transparent (wideband) link on alt 1 (`evt 5`, `len 27 mtu 9`)": the exhibit does contain `evt 5` and `len 27 mtu 9` lines (031:36-55, 82), which are the alt-1 width signature; only a sysfs read is missing. Inference, not an error.

### results.tsv: duplicate trial numbers (#5, #11) [was PARTLY]
- verdict: FIXED
- now: BRIEF.md:139 "E3 #5 and #11 also reused a trial number (...NOTE-two-uses-of-this-number.md, ...NOTE-two-trials-one-number.md); that reuse is recorded in those note files only, not in `results.tsv`."

### results.tsv "failed" rows unexplained for #6-#8, #10, #11 [was PARTLY]
- verdict: PARTLY
- now: BRIEF.md:139 "E3 #3 to #11 all carry the verdict `failed` with 0 links ... #6, #7, #8, #10 and #11 have none [notes], so their `failed` is not explained in the repository. The trial reports ... exclude a `failed` row with BT-1 not observed" - disclosed; tools/lib/trial-summary.awk:121 exclusion confirmed. Notes themselves still absent (evidence/trials/E3/trial-06..10 hold only state/steps/sco-params).
- what is left: per-trial notes (or accept the disclosure). Minor wording: "E3 #3 to #11 all carry `failed`" also covers #9, whose row is bt1_status `confirmed` (BT-17); explained elsewhere.

### evidence/README.md stale (off-topic; sessions table) [was NOT ADDRESSED]
- verdict: PARTLY
- now: evidence/README.md tree now has "  off-topic/   evidence for the items outside Bluetooth (X1, ...)"; the sessions table still says "(This table lists the first four; ..." (README.md:85), now 30 sessions.
- what is left: none needed (self-declared).

### Evidence model "n = 2 ... never to its end" [was NOT ADDRESSED]
- verdict: FIXED (dated note)
- now: docs/issues.md:161 "*Dated note, 2026-11-16: the two rules below stand. The causal graph and the EX-016/EX-021 paragraphs are the model of 2026-09 ... Read the graph as history*"; the counts at :220 "(n = 2, both censored)" remain, now labelled history.

### M-1 and M-2 have no sections; M-rows out of order [was NOT ADDRESSED] [item 15]
- verdict: PARTLY
- now: docs/STATUS.md:97-101 rows now M-1, M-2, M-3, M-4, M-5 (CLAIM CONFIRMED, "the M rows in order"). docs/issues.md:1273 "*Note, 2026-11-16: ... (and the mesh issues `M-1` and `M-2`) have a row ... but no section of their own in this file.*" - disclosed, not added. issues.md still has M-3 (:725), M-4 (:753), M-5 (:787) between BT-8 (:697) and BT-9 (:809).
- what is left: nothing required; M sections remain chronological, not numeric.

### M-3 section lacks the 5.88 release [was NOT ADDRESSED] [item 16]
- verdict: FIXED
- now: docs/issues.md:727 "**Status 2026-11-05 (added 2026-11-16 from the `docs/STATUS.md` row `M-3`): released in BlueZ 5.88** (tagged 2026-11-05; both commits in it; nothing left to do)."

### BT-9 header "Status 2026-10-09 ... missing from ... 6.1" and "Next: replies" [was PARTLY, issues.md side]
- verdict: NOT ADDRESSED
- now: docs/issues.md:811 "**Status 2026-10-09: already fixed upstream; missing from the 6.12, 6.6 and 6.1 stable" and :840 "**Next:** replies." (still followed by the "Since:" paragraph; maintainer item 16 = "partly", this header not dated)
- what is left: optional one-line dated note.

### Elided "…" identifiers (CO-02-…, CO-35-…, CO-43-…) [was WORSE]
- verdict: FIXED
- now: docs/issues.md: `contributions/CO-02-sco-connect-reuses-closing-link/log.md`, `contributions/CO-35-l2cap-ecred-defer-hang-stable/experiments/...`, `contributions/CO-43-btusb-runtime-resume-failure/send-bt24-bt25-20261114/` (two places); `grep -E 'CO-[0-9]+-…' docs/issues.md docs/STATUS.md BRIEF.md` returns nothing. (CLAIM CONFIRMED, "19 elided ... written in full"; I did not count 19.) Log-line "…" (e.g. `New Index … hci0`) remain, correctly excluded.

### Items previously FIXED, spot-check (5 checked)
- BRIEF survival row "**0** (8 × `len 90 mtu 9`, `EX-037`)" and EX-042 "not recorded" (BRIEF §2): still present, no regression. STATUS BT-1 "E3 is retired", STATUS BT-9 "released for 6.1 in 6.1.191": still present. BRIEF E3 #3 "row 3 there is a later boot ... 63 links": still present.

## New defects introduced by this round
- New session evidence/sessions/20261116-002107-shure-paired-in-handsfree-no-codec-row/NOTES.md:40-42 prints a real local user name/home path ("/home/i/.local/state/wireplumber/..."); the rest of evidence/ had no such path (earlier scan found no /home/ names). Addresses in that session are placeholders (AA:BB:CC:00:00:01..06), no IPv4. Low, privacy.
- Index claim cells lose the parenthetical (see first block): EX-086/EX-093 cells give no pointer to EX-087/EX-094. Low.
- EX-043:58 keeps the unsupported "~90 ms" row (flagged by the note at :61). Cosmetic.
- No broken reference found from the retitling (index vs titles 97/97; test fixture covers the new label form).

---

# Part: patches

## Recheck 2, patches part, the checkout of main bbec102f (diff a8d0eb45..HEAD touched: bluez/README.md, btdev-vla/README.md, checkpatch-check.sh, git-am-check.sh, diag/README.md, kernel/README.md, bt9-stable/README.md, README.md map)

### Bot "within 90 min" vs UTC times
- verdict: PARTLY
- now: patches/bluez/README.md:150-153 new note "most likely ... mailbox's own clock, CEST ... 20:05 / 20:10 UTC, 81 and 86 minutes ... The heading's 'UTC' is then wrong." BRIEF.md:393 rewritten "time zone not settled ... read as UTC they are 3 h 21 min and 3 h 26 min after". Still unchanged: patches/bluez/README.md:145 "### The list's CI bot, 2026-09-19 22:05 / 22:10 UTC"; reviews/2026-09-20T0300Z-bluez-ci-bot-results.md:3-4 "within ninety minutes ... 22:05 UTC".
- what is left: relabel the heading and the review file (the note itself now agrees with our reading); acceptable to leave as "unsettled" if the maintainer insists.

### patches/kernel/README.md stale "Reaches mainline" (finding 2) and live "How to send" (finding 7)
- verdict: FIXED
- now: patches/kernel/README.md:3-9 dated note "done on every line it was queued for ... v7.3-rc7 (2026-10-13), v7.3 ... 2026-10-18 ... 7.2.11, 6.18.57 and 6.12.113 (2026-10-15), 6.6.160 ... 6.1.191 ... nothing is pending here"; names "reaches mainline" text and "How to send" (line 260) as pre-send text kept as written.
- what is left: nothing (original lines kept under the note, as the maintainer's convention).

### Kernel CI-bot date 09-25 vs mail 09-24 21:33
- verdict: NOT ADDRESSED
- now: patches/kernel/README.md:22 "**CI bot** | ✅ 2026-09-25 (mail 2026-09-24 21:33 local)"
- what is left: verify against the bot mail and align (needs-check item, low).

### checkpatch-check.sh / git-am-check.sh relative BT_PATCH_DIR (finding 3)
- verdict: FIXED
- now: patches/bluez/checkpatch-check.sh:28-30 `HERE="$(cd "$HERE" 2>/dev/null && pwd)" || { ... exit 2; }` before `cd "$TREE"`; :40-47 `if ! grep -q '^total: ' <<<"$out"; then printf '... NOT RUN ...'; rc=2`; :55 `no 0*.patch file ... exit 2`. git-am-check.sh:32-34 same absolute resolution before the `git -C ... am`.
- what is left: nothing. Claim in checks doc item 18 ("both check scripts resolve a relative BT_PATCH_DIR; checkpatch with no total: line is NOT RUN") CONFIRMED by the lines above (not executed). Logic read: rc stays 2 once NOT RUN, errors only raise rc from 0; CP made absolute before cd.

### diag/README.md stale (E1 37 links; -42 "running since"; no E3 result)
- verdict: PARTLY
- now: patches/diag/README.md:3-10 dated note: E3 builds "retired ... 7.0.0-43 ... since 2026-11-12", "the 'E1 result' below (37 links, two boots, one headset) is the count of 2026-09-29; other pages ... give later, larger counts ... not reconciled here". Body lines unchanged (:52 "37 SCO links over two boots", :126 "running since"). README.md map now: "the E1 diagnostic btusb patch, the recipes for E3 (the upstream entry, built per kernel; no patch file)".
- what is left: the E1 numbers (58/3 boots/2 headsets, EX-058) and E3 16 links (EX-057) are still not stated in this file; the note admits it. Map part of the finding FIXED.

### README.md repository map (rest)
- verdict: PARTLY
- now: diag entry fixed (README.md:281-282). Still not listed: patches/bluez/sent/, v2/, btdev-vla/, send-2026-10-13/; patches/kernel REVIEW-TASK/repro scripts; patches/mesh-tester still has no README (ls: 0).
- what is left: add the directories or accept as editorial.

### bluez README "What is kept": v2/ "on the list, unhandled"
- verdict: FIXED
- now: patches/bluez/README.md:118 "on the list, unhandled when this row was written (2026-11-16: the a2dp v2, 14836500, was later applied on 2026-10-07 as `d84171e6cd68`; the adapter v2 is moot ...)"
- what is left: nothing.

### checkpatch-check.sh picks lexically last linux-headers
- verdict: NOT ADDRESSED
- now: patches/bluez/checkpatch-check.sh:18 `for c in /usr/src/linux-headers-*/scripts/checkpatch.pl; do`
- what is left: sort -V (low).

### git-am-check.sh "Read-only on the checkout"
- verdict: NOT ADDRESSED
- now: patches/bluez/git-am-check.sh:9 "the checkout itself is not modified", :23 "Read-only on the checkout." (script still runs `git worktree add/remove` in $TREE)
- what is left: reword (low).

### Broken path ...-on-d84171e6c-2026-10-08/
- verdict: NOT ADDRESSED
- now: HISTORY.md:5020 and docs/mesh-tester-ci/review-response-4-bluez-shared-mgmt-2026-10-08.md:8 still cite the dated directory name; real dir is patches/mesh-tester/bluez-shared-mgmt-notify-leak-on-d84171e6c/.
- what is left: drop suffix or add a rename note.

### stable-request "next" row without release
- verdict: NOT ADDRESSED
- now: patches/diag/stable-request-dc16388d45ec.md:9 "... then the Ubuntu kernel that carries it; nothing owed"
- what is left: record the releases (low).

### bt9-stable README ("Before sending", 497-498, ci-bot file)
- verdict: PARTLY
- now: FIXED: patches/kernel/bt9-stable/README.md:104-107 "between 496 and 498 of 506 ... (corrected 2026-11-16 ...)" and :144-145 dated note "pre-send checklist, kept as written ... nothing here is pending". Remaining: results/ci-bot-2026-10-10.md still not listed in the "results/" row (grep ci-bot-2026 in README: 0).
- what is left: list the file (trivial).

### sent-mails.tsv hashes of address-elided copies
- verdict: NOT ADDRESSED
- now: docs/sent-mails.tsv:11-13 unchanged, header "send_date contribution path message_id patchwork_id list sha256" (file unchanged in the round).
- what is left: mark rows as "elided copy" (low).

### btdev-vla README header
- verdict: FIXED
- now: patches/bluez/btdev-vla/README.md:3-4 "State 2026-10-10 (kept as written; superseded, see the next two paragraphs) ... Nothing had been mailed of this version."
- what is left: nothing.

### TEST-REPORT machine-local path
- verdict: NOT ADDRESSED
- now: patches/bluez/send-2026-10-18/TEST-REPORT.md:12 "`/root/exp/qca9377-bt-hang/tmp/bluez-a1a2-20261018/`"
- what is left: nothing required (low).

### Previously FIXED: STATUS BT-9 row (6.1 release)
- verdict: FIXED (spot-checked 1 of 1, no regression)
- now: docs/STATUS.md:80 still carries "corrected 2026-11-15: this cell still said 'not yet released for 6.1'" and 6.1.191 (2026-10-30).

### Maintainer's checks document, claims about my part
- item 18 "Dated notes; both check scripts resolve a relative BT_PATCH_DIR; checkpatch with no total: line is NOT RUN": CLAIM CONFIRMED (notes at kernel/README.md:3, diag/README.md:3, bt9-stable/README.md:144, btdev-vla/README.md:3, bluez/README.md:150; script lines above). But "right" overstates completeness: the README.md:22 CI-bot date, stable-request row, tsv, HISTORY path, checkpatch glob and git-am "read-only" wording were not touched.
- bot-time item ("time zone not settled" in "Not raised by the reviewer" list): CLAIM CONFIRMED that it is marked unsettled in BRIEF.md:393 and bluez/README.md:150-153; our finding (CEST mislabelled UTC) stands as "likely", not proven (headers not in repo) - not withdrawn.

## New defects introduced by this round
none found. Minor wording check (needs-check, not a defect): kernel/README.md:6 says "v7.3-rc7 (2026-10-13)"; it matches docs/STATUS.md:63 ("first in v7.3-rc7 (2026-10-13"), but v7.3 released 2026-10-18 normally implies rc7 on 2026-10-11; the date is the maintainer's own and consistent across files.

---

# Part: co-a

## Recheck 2 (co-a) against the checkout of main bbec102f. Paths under contributions/ unless stated.
Changed on the checkout of main in my part since a8d0eb45: README.md, rd-2026-11-14.md, CO-03/README.md, CO-09/README.md, ubuntu-bluez-5.72-0ubuntu5.9-bundle/BUNDLE.md (+SHA256SUMS), BRIEF.md. Unchanged: CO-01, 04, 05, 06, 07, 08, 10, 11, 12, 14 dossier files.

### CO-04/CO-05 review-fixes not pointed to (was PARTLY)
- verdict: PARTLY
- now: FIXED in README.md:89-90 ("2026-11-16: the package to send is `review-fixes-20261114/` ... `send-20261114/` is superseded"). Still open: CO-04/send-20261114/README.md:4 "The send file is `patch/0001-…`"; CO-04/README.md:3 and CO-05/README.md:9 "State (2026-10-29)"; no pointer in either dossier README.
- what is left: one line in each dossier README and in send-20261114/README.md (the marker is a separate SUPERSEDED.md, not at the README's top).

### No NOTES-FOR-OPERATOR.md in CO-04, CO-05, CO-12 packages
- verdict: NOT ADDRESSED
- now: `ls` CO-04/review-fixes-20261114, CO-05/review-fixes-20261114, CO-12/send-20261114: none; README.md:43 mentions a notes file only for CO-35.
- what is left: add or say the table's last column replaces it.

### CO-04/CO-05 front pages show the 10-29 state
- verdict: NOT ADDRESSED
- now: CO-04/README.md:3, CO-05/README.md:9 unchanged; CO-04/log.md has no 11-14 entry. (Maintainer item 20 claims dossiers corrected; not for these two.)
- what is left: update.

### send-20261114/README "…" path
- verdict: NOT ADDRESSED
- now: CO-04/send-20261114/README.md:4 "`patch/0001-…`".
- what is left: write in full.

### CO-09 body "State: waiting" vs banner (Medium)
- verdict: PARTLY
- now: FIXED for the State paragraph: CO-09/README.md:17-19 "Note of 2026-11-16: the 'State' paragraph below is ... superseded by the banner above: done" and "State (2026-11-11, superseded)". Still present, unmarked: :34 "It is in the 6.6, 6.1, 5.15 and 5.10 release candidates (STATUS)", :43-46 "## Until then ... rebuild E3", :48 "## Next".
- what is left: say the facts/Until then/Next sections are history too.

### CO-09 banner 22:57 vs 22:55; "…" in command
- verdict: NOT ADDRESSED
- now: CO-09/README.md:5 still "22:57"; :7 "control `… 0cf3 e300`". New note :18-19 says "Which is right is not settled here: it needs the boot's journal". Settled by files already: docs/issues.md:43 "stock btusb since 11-12 22:55 (boot `46cc4812`)", BRIEF.md:82,116,179 "22:55", docs/issues.md:1070 shows 22:57 is a USB-attribute read ("2026-11-12 22:57, after the power-off ... off ~8.4 min since 22:4x"); results/bt16-third-2026-11-13 says trial E3 #11 opened 22:55:12. The maintainer's "unsettled" (checks doc, last bullets) is refuted by those lines; our finding stands.
- what is left: change the banner to 22:55.

### CO-11 front page points at the superseded ready-20261102 (was WORSE)
- verdict: NOT ADDRESSED (still WORSE)
- now: CO-11/README.md:6 "the filing package is `ubuntu/ready-20261102/`"; README.md:96 index row same; README.md:54 table row and ready-20261102/SUPERSEDED.md say send from the bundle. Index lines 128/130 also still cite `ubuntu/ready-20261102/` (dated 11-02 sections, acceptable).
- what is left: update CO-11 banner and row.

### CO-03 front page lags; "0/70 → 70/70" ambiguous (Medium/Low)
- verdict: PARTLY
- now: FIXED: README.md:88 (index row corrected: "lost A2DP 70 of 70 times before and 0 of 70 after ... corrected 2026-11-16"; names co03.1 five-patch with BT-7 vs bundle without), CO-03/README.md:12-26 note of 2026-11-16 (both builds named), BUNDLE.md:"Note of 2026-11-16" (same), BRIEF.md:203-206 and :107 (staged co03.1 carries BT-7; bundle build does not), rd-2026-11-14.md "Corrections of 2026-11-16". Agreement check across dossier, BRIEF, STATUS, BUNDLE: all say co03.1 = five patches incl. BT-7, bundle = ten patches without BT-7; STATUS.md:267 stays as the staged-build record. Still open: CO-03/README.md:3 "State (2026-10-31) ... waiting for the operator's test" and :9 "0/70 → 70/70 on the trigger" (dossier body not corrected, only the index row); the index "next step" (README.md:88) still "the operator installs" although staged 11-13 (the row's own text says staged).
- what is left: fix CO-03/README.md:9; say "staged 11-13, not running" in the State line.

### Index row CO-07 "not built"
- verdict: FIXED (index) / dossier NOT ADDRESSED
- now: README.md:92 "not built as of 11-01; 2026-11-14: built ... build-20261114/"; CO-07/README.md:9 still "State: idea. One reading is missing before a request."
- what is left: CO-07/README.md:9.

### Old "State:" lines under banners (CO-01, 06, 07, 08, 10)
- verdict: NOT ADDRESSED
- now: CO-01/README.md:9 "State: idea; nothing run yet."; CO-06/README.md:9 "State: blocked (2026-10-28) ... must be re-run"; CO-07/README.md:9. BRIEF.md:111 also still "its comparison must be re-run first, CO-06" (contradicts CO-06 banner :4 "The rerun is done").
- what is left: mark as history; fix BRIEF.md:111.

### CO-14/04/05/12 state words in index and rd table
- verdict: PARTLY
- now: rd-2026-11-14.md "Corrections of 2026-11-16" says the table is the 11-14 snapshot and lists CO-02,03,30,35,38,39,40,41,43,22 as overtaken, but not CO-04, CO-05, CO-12, CO-14 (rows still "package ready 10-29", "reproduced; draft clamp", "idea"). README.md:99 CO-14 row still "idea; research 2026-11-01".
- what is left: add those four to the corrections list; CO-14 state.

### SHA256SUMS list files not in the repo; CO-14 mismatch; 515 vs 526; CO-01 cover id
- verdict: NOT ADDRESSED (all four)
- now: `sha256sum -c` in the checkout of main: CO-12/send-20261114 29 FAILED (+ missing), CO-04 6, CO-05 13, CO-14 patches 4, CO-14 logs 1 mismatch; CO-14/fix-20261114/RESULTS.md:87 "515 cases"; CO-01/refs.md:4 "cover 14157860".
- what is left: unchanged.

### "…" elision in identifiers/paths
- verdict: NOT ADDRESSED
- now: CO-04/send-20261114/README.md:4, CO-09/README.md:7, CO-14/README.md:37, CO-07/build-20261114/README.md:12 unchanged. Maintainer item 21 claims 19 `CO-nn-…` paths in STATUS/issues/BRIEF written in full; not in dossier READMEs.
- what is left: spell out.

### Round-1 "New defects" items
- table text "every older directory carries a superseded line at its top": README.md:22 unchanged; marker is a separate SUPERSEDED.md (CO-04/CO-05/CO-11 exist) - NOT ADDRESSED (Low).
- `<AUTHOR-EMAIL>` in ready-20261102 debdiffs: still there, directory marked superseded - acceptable/unchanged.
- CO-11 README names superseded dir: see above, NOT ADDRESSED.
- "no Signed-off-by" sentence: README.md:24-26 now has an explicit exception for CO-35 - FIXED.

### Maintainer claims checked (checks doc)
- Item 3 "index rows carry dated pointers; markers": CLAIM CONFIRMED for CO-04/05 (README.md:89-90) and SUPERSEDED.md in CO-04/CO-05/CO-11 replaced dirs; CLAIM REFUTED for "six without a marker" being all that was left only insofar as CO-11's own README/row still point at the marked dir.
- Item 6 "both documents were right about their own build; BRIEF and the dossier now name both": CLAIM CONFIRMED (CO-03/README.md:12-26, BRIEF.md:203-206, BUNDLE.md Left out, README.md:88). The sha `ffbedfd78fcd...` equals results/laptop-only-work-2026-11-11/headset-session/SESSION-CHECKLIST.md:709. The `.deb` itself and `artifacts/` are not on main (ls artifacts: absent), so "read with dpkg-deb" cannot be checked from the repo; the bluetoothd hash is only "`59d2ea79...`".
- Item 20 "Dossiers and rd corrected": PARTLY refuted: of my dossiers only CO-03 and CO-09 got notes; CO-01, 04, 05, 06, 07, 11, 14 front pages unchanged. The "CO-09 boot time unsettled" claim is refuted (see above). The "CO-04 counts of 9 and 8 of 12" is not mine.

## New defects introduced by this round
- CO-03/README.md:14-22 quotes the bluetoothd hash as "`59d2ea79...`" (elided identifier, new text; STATUS.md:267 has the same "59d2ea79…" so no full value exists in any file), and names `artifacts/bluez-5.72-0ubuntu5.9~co03.1/...deb`, a path that is not on main (the kit lives on the laptop); the .deb read cannot be reproduced from the repository. Low.
- STATUS.md:267 reads "`bluez_..._amd64.deb`, SHA-256 `59d2ea79…`" which attributes that hash to the deb in grammar, while CO-03's note says it is the bluetoothd hash and the deb's is `ffbedfd7...`: two different hashes, ambiguous wording. Low (needs-check).
- README.md:88 CO-03 row now long and still ends "the operator installs" next step while its own text says the build is staged; BRIEF.md:111 "comparison must be re-run first, CO-06" survives the round and contradicts CO-06's banner. Low.

---

# Part: co-b

## recheck2 co-b against the checkout of main bbec102f (paths relative to a checkout of main)

### Maintainer item 1: CO-35 mails copied byte for byte, COPIED-FROM.md, SHA256SUMS, table row
- verdict: CLAIM CONFIRMED
- now: `sha256sum` over all 11 files of contributions/CO-35-…/send-20261114/mail/ (2 .eml + 3x(cover + 2 patches)) and of review-fixes-20261114/mail-from-send-20261114/ (excluding COPIED-FROM.md and SHA256SUMS): `diff` empty, IDENTICAL. `sha256sum -c SHA256SUMS` inside mail-from-send-20261114/ passes; review-fixes-20261114/SHA256SUMS passes. COPIED-FROM.md: "a plain copy of them (same bytes; nothing in `../../send-20261114/` was moved or changed)" with a file table. Table row contributions/README.md CO-35 names review-fixes-20261114/ plus mail-from-send-20261114/ and says "a copy of the mail directory of the superseded send-20261114 package, 2026-11-16". send-20261114/SUPERSEDED.md still says "Send from ../review-fixes-20261114/" (now true). Four more SUPERSEDED.md (send/, send-20261102/, send-20261101-draft/ in CO-35; CO-21 patches-20261101/) exist: confirmed by `find`.
- what is left: nothing for the copy. See new defect 1 (covers vs reduced option).

### Maintainer item 2 (CO-30 note) and my CO-30 finding (base path, 10-21/11-01, base predates CO-02 fixes)
- verdict: PARTLY
- now: FIXED as a note: contributions/CO-30-…/rfc-20261114/README.md (new top note) "the base named above (`../co02-v2/kernel/`) is not in the repository, and that 2/2 is the sleeping one, which can deadlock ... The RFC has not been re-tested on that candidate; this is open"; table row CO-30 in contributions/README.md says "tested on the withdrawn sleeping 2/2 ... **not re-tested**". Not fixed: README.md:3 and :27 still name `../co02-v2/kernel/` and `../co02-v2/logs/SHA256SUMS`; :10 "10-21 prototype" vs dossier README.md:11 "11-01 prototype" unchanged; the dossier-level contributions/CO-30-…/README.md has no note (its "applies to CO-02 v2 ... passes 3/3" text is unmarked).
- what is left: re-test on alt-2of2 (open, kernel work); reconcile 10-21/11-01; add the note to the dossier front page.

### CO-30: SHA256SUMS lists files that fail or are not shipped
- verdict: NOT ADDRESSED
- now: rfc-20261114: `sha256sum -c SHA256SUMS`: "./bot/bot-rfc2/patched/harness.log: FAILED open or read" (and CHECKS-CO30.md mismatch earlier, logs-SHA256SUMS missing logs).
- what is left: regenerate or annotate.

### Maintainer item 3: markers; CO-20 and CO-21 recipients and notes; index rows
- verdict: PARTLY (the markers and replacement notes are done; rows still lead with the old directory)
- now: FIXED: SUPERSEDED.md in CO-35 send/, send-20261102/, send-20261101-draft/, CO-21 patches-20261101/ (table text at contributions/README.md "every package's older directory" is now true for my dossiers). CO-20: patch1-standalone-20261114/recipients.txt added ("written 2026-11-16 from ../send-20261114/recipients.txt ... not re-run ... re-run it from the project checkout"); CO-21: review-fixes-20261114/NOTES-FOR-OPERATOR.md + NOTES-FOR-OPERATOR-from-send-20261114.md + recipients-from-send-20261114.txt, with the differences stated; both SHA256SUMS verify (no failures). Index rows (contributions/README.md CO-20, CO-21, CO-35 dossier rows) now end "2026-11-16: the package to send is `patch1-standalone-20261114/` / `review-fixes-20261114/`"; rd-2026-11-14.md has a "Corrections of 2026-11-16" block naming the replacements (CO-21, CO-20, CO-35). CO-35 README.md:3-9 has a dated note that send-20261102 is out of date.
- remaining: the rows still print "2026-11-14: send package ready, nothing sent (`CO-20-…/send-20261114/`)" before the 11-16 sentence (dated, so acceptable); CO-20 has no NOTES-FOR-OPERATOR.md of its own (NOTES.md + the superseded one); CO-21 cover letter "Changes since the first draft" FIXED (0000-cover-letter.patch now "The air mode is stored before the connection is marked connected. One helper ...").
- what is left: nothing required.

### CO-21 / CO-20 / CO-23 high items (index names replaced dirs)
- verdict: FIXED for CO-21 and CO-20 (dated pointers, SUPERSEDED, notes); PARTLY for CO-23
- now: CO-23: contributions/CO-23-one-off-events/README.md:6 still "send package ready (`patch/send/README.md`"; patch/send-20261114/README.md:12 still "as in `../send/README.md`"; patch/send/send.sh still present (ls: README.md SHA256SUMS SUPERSEDED.md send.sh); NOTES-FOR-OPERATOR.md "Still wrong or stale" list unchanged. No CO-23 file changed in this round.
- what is left: repoint those two references; mark or remove send.sh; mark the notes list done.

### Maintainer item 15: STATUS names the v4 draft (CO-25)
- verdict: CLAIM CONFIRMED
- now: docs/STATUS.md:50 "the current draft is v4, `contributions/CO-25-qualcomm-rom-report/drafts/reply-1-zijun-hu-v4.eml` of 2026-11-02; the first draft `drafts/reply-1-zijun-hu.em…" (the first draft is kept as history). Also STATUS CO-34 cell now says "it is in BlueZ 5.88, the state cell above" (my CO-34 stale remark: FIXED); sent-mails.tsv:27 CO-34 row still has date only, no time (Low, NOT ADDRESSED).
- what is left: nothing.

### Maintainer item 20: dossier front pages, rd-2026-11-14.md corrected
- verdict: PARTLY
- now: rd-2026-11-14.md new "Corrections of 2026-11-16" block (checked above). CO-27: README.md new note "the GNOME half ... is now held by CO-42" and STATUS U13 "the BlueZ side: CO-27; the GNOME side is CO-42" (FIXED); CO-27 README step 4 "GNOME's tracker are not searched yet" unchanged. CO-34 patch/send/README.md note "this package was sent and applied" (FIXED). CO-28 README.md:52 "Watch for each review mail" still present (NOT ADDRESSED, Low). CO-25 README, EVIDENCE.md, pinned commits unchanged (NOT ADDRESSED, Low/needs-check). CO-23 unchanged (above).
- what is left: those three Lows.

### Table-claim checks
- verdict: CLAIM CONFIRMED (checks doc item 3 "dated pointers"; item 1 "holds a byte-identical copy ... own SHA256SUMS; the table row points at it"; item 21 "19 elided CO-nn-… ... written in full in STATUS and docs/issues.md"): `grep -c 'CO-[0-9]*-…'`: docs/STATUS.md 0 (was 13), docs/issues.md 0 (was 5), README.md 0, BRIEF 0.
- remaining: contributions/README.md 3 hits (the CO-20, CO-21, CO-30 dossier rows) and rd-2026-11-14.md 10 hits (kept "as written", by its own correction note); CO-20 README.md:55 "`257d1599…`" boot id elided (the checks doc says log-line ellipses are not identifiers; a boot id is).

### README.md:22 / :23 claims from the earlier recheck (new defects 2 and 3)
- verdict: FIXED
- now: older dirs now carry SUPERSEDED.md for CO-35 and CO-21; S-o-b exception written at contributions/README.md ("Exception, noted 2026-11-16: the six CO-35 backports carry the original authors' chain and, since 2026-11-02, a Signed-off-by of the operator ... the operator confirms it at send time").

### CO-35 pointers (dossier README, issues.md)
- verdict: PARTLY
- now: FIXED: CO-35 README.md top note. NOT ADDRESSED: docs/issues.md:898-900 "**Reportable:** the CO-35 send package (an option-2 request for 7.3.y and 7.2.y ... (`send-20261102/`); nothing sent as of 11-12"; CO-35 README.md:14 and :20 old banner/state text (labelled out of date).
- what is left: update issues.md:898.

### Items I had as FIXED, spot-check
- README.md L2CAP wording ("7.3, 6.18, 6.12 and 6.6 lines, and the older lines only with the non-default `enable_ecred`") and BRIEF CO-28/CO-35 lines: still correct (2 spot-checked, no regression).

## New defects introduced by this round
1. CO-35 mail-from-send-20261114: the covers and request say the prerequisite "is 78 changed lines (a 149-line diff) ... and is sent whole as it was merged" (6.6.y/0000-cover-letter-20261114.patch:19-20). COPIED-FROM.md offers the reduced patch 1 as a drop-in for 0001 without saying the covers/request must be rewritten; with the reduced patch they would be false. (Low, doc.)
2. contributions/README.md CO-30 row and the CO-30 rfc note both reference a base directory that does not exist (`co02-v2/kernel`) by design; fine, but the broken reference stays in rfc README.md:3,27.
3. CO-20 recipients.txt records get_maintainer output "not re-run for this directory" and is dated 11-16 though copied from 11-14 output; stated honestly, no defect.
No new machine-local paths, no new "…" identifiers in my dossiers' changed files.

---

# Part: co-c

## co-c recheck2 against the checkout of main (tip bbec102f). Paths are relative to the checkout of main.

### Maintainer item 4: CO-43 HELD notes, BT-18 row, "five patches", kmemleak counts
- verdict: PARTLY
- now: FIXED: contributions/CO-43-.../send-series-20261114/HELD.md ("Note of 2026-11-16: patch 3's message ... rest on a premise that the D v2 finding above refutes ... Do not reuse those texts") and SUPERSEDED.md (new); CO-43/README.md:28 ("the state is no longer 'five patches'"); contributions/README.md CO-43 row ("2026-11-16: the series is E, then A, B2, D v2 ..."); STATUS BT-18 row now "D v2 registers .reset_resume, which suppresses needs_binding ... held" (the earlier "unchanged by reading only" is gone). STILL OPEN: docs/STATUS.md:88 (BT-17) "CO-43 (btusb, five patches)" and docs/issues.md:1102 "patch candidates in CO-43 (five)" (issues.md:22 adds an explanatory note). NEW DEFECT: see below on the kmemleak sentence.
- what is left: BT-17 wording; fix HELD.md's kmemleak sentence.

### Maintainer item 4, kmemleak claim "the series cover quotes the re-run"
- verdict: CLAIM REFUTED
- now: HELD.md (new note) "The cover's kmemleak line ('1 to 4 objects per run, then none in 12 of 12 runs') quotes the re-run kept in ../send-bt24-bt25-20261114/logs/ (12 of 12 leaking on E alone)". send-series-20261114/0000-cover-letter.patch:52 says "1 to 4 kmemleak objects per run", but the re-run send-bt24-bt25-20261114/logs/kml-e.txt:8 has objects=5 (k-dead-1). So "1 to 4" is the first run (max 4), not the re-run (max 5). CO-43/README.md:36-38 "The send package's cover quotes the re-run" is true only for send-bt24-bt25's cover (3,3,1/2,1,2/5,3,4/2,2,2). The reconciliation itself (11 of 12 first run, 12 of 12 re-run, both real) is confirmed by the logs.
- what is left: change HELD.md to "quotes the first run".

### Maintainer item 5: CO-38 cover From
- verdict: CLAIM CONFIRMED
- now: contributions/CO-38-.../send-20261114/bluez-cover-body.txt:1 "From: Iaroslav Voitovych <yaroslav.voytovych@gmail.com>"; send-20261114/SHA256SUMS now verifies (no FAILED). Other `<AUTHOR-EMAIL>` files remain only in directories marked SUPERSEDED (CO-38 send-20261102, CO-37 work/patches/*-20261102, CO-11 ready-20261102). CO-37/send-20261114/README.md:51 still says the 11-02 mails with a placeholder author were "Left in the work area" although they are on main (marked superseded).
- what is left: reword CO-37 README:51 (Low).

### Maintainer item 16: docs/issues.md BT-18 to BT-23
- verdict: FIXED
- now: docs/issues.md ~1108 (BT-18) "Status 2026-11-14 (added 2026-11-16 from the STATUS row BT-18) ... HELD"; ~1127 BT-19 "B2 ... needs D"; ~1149 BT-20 "A-review-fixes-20261114/ ... replaces A/"; ~1157 BT-21 "send package, ready"; ~1174 BT-23; BT-24 :1187 and BT-25 :1208 with the Next line dated ("Next (the 11-13 plan; done 2026-11-14 ...)"); `agent-work/bt17-mgmt-timeout` reference gone. Residue: docs/issues.md:1345 still `tmp/ui-screenshots/...-…png` with truncated sha (U4 text); :1984 `/root/exp/agent-work/...`; STATUS.md:123 U22 "…" (identifier elision, Low; maintainer says only log-line ellipses and three truncated hashes are open).
- what is left: nothing for BT-18..BT-23; Low residue as listed.

### Maintainer item 20: dossier front pages CO-37, CO-38, CO-39, CO-41, CO-44; bundle notes
- verdict: PARTLY
- now: FIXED: "Note of 2026-11-16" blocks at the top of CO-37, CO-38 (names split series-a/series-b-held, flake 2 of 8 / 1 of 7), CO-39 (also covers the missing "v3 cover letter file"), CO-41 READMEs; CO-44 patch/SUPERSEDED.md (new); BUNDLE.md:17 and :55 now say the trailer carries the operator's address; rd-2026-11-14.md has "Corrections of 2026-11-16" naming the overtaken rows; contributions/README.md rows CO-37 (5.88), CO-38 ("2026-11-16: shown to be a flake"), CO-39 (base side read), CO-41 (send package) fixed; the "What to send" CO-39 cell now reads "the bot's base side was read on 11-14" (the stale cell I flagged is fixed). NOT FIXED: (a) contributions/CO-38-.../send-20261114/README.md:14-16 still "TestFunctional failed 2 of 3 ... but is **not shown** to be" (the new front-page note contradicts it); no NOTES-FOR-OPERATOR.md in send-20261114/bluez-split-20261114; (b) contributions/README.md:138 CO-40 row still "bundle with the other 5.72 updates (CO-03, CO-11a, CO-37) or file alone" and CO-40/README.md:21 "Next: bundle with ..."; (c) CO-39/send-20261114/README.md:1 still "one bot run still to read"; (d) CO-44/README.md:18-23 still "The patch: patch/0001-..." (marker only in patch/); (e) bundle SHA256SUMS still fails for 7 edited files (bin/build-series.py, changelog-entry.txt, CHECKS.md, deliver/*.debdiff, 3 patches); BUNDLE.md hash line was refreshed but not those.
- what is left: items (a)-(e).

### Remaining PARTLY / NOT ADDRESSED items from recheck 1
- CO-43 patch A residue (A-review-fixes has no NOTES/send-commands; A/NOTES still says "Done ... Result: OK"): PARTLY, unchanged; table says "to make".
- rd-2026-11-14.md table vs results: FIXED by the "Corrections" block (table kept as dated).
- Dossier READMEs frozen (CO-38/39/41/37): FIXED (notes). CO-40: NOT ADDRESSED (README unchanged).
- "…" elision in CO-44 NOTES (2 hits), A-review-fixes README (1), results READMEs, CO-36, X1 hashes, bundle LP-…: NOT ADDRESSED; the maintainer says 19 elided CO-nn paths in STATUS/issues are written in full (confirmed: no "CO-43-…" remains in STATUS/issues) and three hashes remain open.
- CO-36 README:184 "fix variants ... next (Phase 1)" and README "test plan of 111 tests": NOT ADDRESSED.
- BRIEF.md:215-216 "3 CO-38's BlueZ TestFunctional failures (2 of 3 patched; flake not shown) ... 4 CO-41 and CO-39 (no report yet)": NOT ADDRESSED (lane bullet kept); the "Patch ready" list was fixed earlier.
- U23 row: FIXED (issues.md now says the counts are CO-03's reproduction counts with the path). U24: FIXED (5.88).
- BT-17 "five patches": NOT ADDRESSED (above).
Spot-checked FIXED items for regression: 6 (A-review-fixes superseded marker, HELD, table rows for CO-44/E/BT-24-25, STATUS BT-20 row, CO-37 row, U24) - no regression.

### Maintainer claims in the checks document concerning my part
- Item 4 "Notes in HELD.md and the dossier; STATUS BT-18 says ... needs_binding; 'Five patches' corrected": CLAIM CONFIRMED for HELD, dossier README and STATUS BT-18; "five patches" corrected in the dossier and index but still in STATUS BT-17 / issues.md:1102 (partly refuted). "The kmemleak counts are both real: 11 of 12 ... 12 of 12": CLAIM CONFIRMED (kml-e.txt 12 nonzero; RESULTS.md 11 of 12); but see the HELD.md refutation above.
- Item 5 "CO-38 cover's From: now has the author's address": CLAIM CONFIRMED.
- Item 16 "BT-18 to BT-23 brought to 11-14": CLAIM CONFIRMED.
- Item 20 "Dossiers and rd-2026-11-14.md corrected": PARTLY (see above: CO-38 send README, CO-40, CO-39 heading, CO-44 README untouched). "The CO-38 row ... named a work area that no longer exists; it now says so": not re-checked in detail.
- "marked superseded": CONFIRMED for CO-43 send-series, CO-44 patch/, CO-38 send-20261102 and send-20261114/patch/bluez, CO-37 work/patches.

### CO-46 (new material): dossier vs register row vs STATUS
- verdict: NEW DEFECTS (see list)
- now: CO-46/README.md "State (2026-11-16): cause found in the source; upstream's fix identified ... SRU drafted in sru-noble/" vs contributions/README.md:151 (CO-46 row) "measured, recorded 2026-11-14 ... not yet checked against systemd main | read sd-journal.c on v255 and main; search upstream; reproduce ... in a VM" and rd-2026-11-14.md:86 "— (not started)". CO-46 has no row in the "What to send" table (grep CO-46 contributions/README.md gives only line 151) although it has a drafted request, patches and debdiff. docs/STATUS.md:412 only links the dossier.
- what is left: update the index row and add CO-46 to "What to send" (or say it is a draft).

### CO-46: references to files not on main
- verdict: NEW DEFECT (Medium)
- now: CO-46/README.md "Where the data and scripts are (branch research/journalctl-file-scaling)": results/journalctl-file-scaling-cause-2026-11-14/, -verify-2026-11-15/, -host-2026-11-16/, results/journalctl-file-scaling-remaining-2026-11-16/, results/journalctl-sru-packaging-2026-11-16/, patches/systemd/journal-file-scaling/ are not in the checkout of main (only results/journalctl-file-scaling-2026-11-14/ exists; `git ls-files | grep -c journalctl-file-scaling` = 5). The branch exists only as origin/research/journalctl-file-scaling. Every measurement in the README (tables, exponents 2.15/1.50/1.13, #44579 numbers, 336 comparisons) therefore has its source outside main; the README says so only for "data and scripts".
- what is left: merge the result directories or say per figure that it is branch-only.

### CO-46: placeholders and checksums in sru-noble/
- verdict: NEW DEFECT (Low)
- now: sru-noble/patches/ubuntu-noble-branch-commit.patch:2 "From: <AUTHOR-NAME> <AUTHOR-EMAIL>", :36 the changelog trailer the same; "Bug-Ubuntu: .../+bug/NNNNNNN" and file names `lpNNNNNNN-*.patch` in patches/debian-patches/, the debdiff and the commit patch. sru-noble/README.md:25 explains them ("NNNNNNN stands for the Launchpad bug number ... Both are filled in, and the patch files renamed, once the bug exists"), but the author placeholder is not the project's author identity (Iaroslav Voitovych <yaroslav.voytovych@gmail.com>) and the README names no operator step for the identity. No SHA256SUMS in CO-46/ or sru-noble/ although the README calls the directory "self-contained" and the project's packages carry sums.
- what is left: add SHA256SUMS; decide the author line; mention it in the operator's steps.

### CO-46: numbers and local paths
- verdict: PARTLY (Low)
- now: README "477.7 fstat-family calls per printed line" vs sru-noble/evidence.md:45 "strace counted 477.8 system calls"; the other figures match (19 218 -> 178 586 9x, 29 194 -> 201 342 7x, 2 292 -> 56 894 24.8x, exponent 2.15/1.50, journalctl -b 48.2 s vs about 28 min = 35x). No /root, /home/<user>, agent-work or project/tool names in sru-noble/, review-package.md or sru-noble-review-request.md (grep clean); build-review-package.py:25 carries the deny-list. The reproducer's output.txt shows temp paths of a container only.
- what is left: align 477.7/477.8.

## New defects introduced by this round
- HELD.md's note misdescribes the series cover's kmemleak line ("quotes the re-run"; the cover says "1 to 4", the re-run reaches 5). CO-43/README.md and the cover itself are consistent with the first run.
- CO-38/send-20261114/README.md still says "not shown to be" a flake directly under the dossier front page that says it is one.
- CO-46 dossier says "State 2026-11-16: SRU drafted" while the index row and rd say "not started"; CO-46 missing from "What to send"; six data/patch paths named only on a branch.
- CO-46 sru-noble has `<AUTHOR-EMAIL>` in the packaging commit and no checksums.
- Bundle SHA256SUMS still fails for 7 files (unchanged), now with a BUNDLE.md hash refreshed but not the others.

---

# Part: co-register

## co-register recheck 2 against the checkout of main (bbec102f)
Paths relative to the checkout of main. Maintainer's document: reviews/2026-11-16T0000Z-project-review-recheck-checks.md (cited as M#).

## Re-verification of the "What to send" table (contributions/README.md:~19-55, mechanical)
- 20 rows; python over every backticked path with "/" in the send / replaces / commands columns: 0 missing, 0 "…" in the table. Expansion of elided forms: none needed (the table uses full directory names).
- Every "replaces" directory has SUPERSEDED.md (own or, for CO-04's `send-20261114/patch/`, the parent `send-20261114/`). The three that lacked one last time now have it: CO-43 `send-series-20261114/` ("Marker added 2026-11-16"), CO-02 `review-fixes-20261115/patches/main-v2/` ("# Not to be sent: this 2/2 can deadlock"), and `send-v2-20261114/` is marked. Also CO-35 `send/`, `send-20261102/`, `send-20261101-draft/`, CO-21 `patches-20261101/` have markers (M3 confirmed).
- Table vs index rows: CO-02, CO-04, CO-05, CO-20, CO-21, CO-35 index rows now carry "2026-11-16: the package to send is ... (the table's ... row); ... superseded" pointers. CO-12, CO-23, CO-37, CO-39 rows name directories that are current, so agree.
- Table vs rd-2026-11-14.md: rd now has "## Corrections of 2026-11-16" naming each replaced directory and saying "This page is not the page of record ... the table ... is". Agrees.
- Table vs BRIEF: BRIEF.md:171-173 "the 'What to send' table ... (the record; rd ... is the 11-14 working page ... it is not kept current)". Agrees, except two stale bullets in the same hand-off (below).
- Table vs STATUS: STATUS.md:8-14 agrees on CO-02 (sleeping 2/2 not to be sent).
- Table vs reviews/2026-11-15T0115Z-submitted-contributions-status.md: file UNCHANGED since a8d0eb45, still disagrees on CO-02 (see below).

## Items from recheck 1 that were not FIXED

### Index rows and rd name replaced directories; BRIEF vs table (M3 / maintainer item 3)
- verdict: FIXED (M3 CLAIM CONFIRMED)
- now: contributions/README.md CO-02/04/05/20/21/35 rows end with "2026-11-16: the package to send is `review-fixes-20261114/` ... `send-20261114/` is superseded"; rd-2026-11-14.md "Corrections of 2026-11-16"; BRIEF.md:171-173.
- what is left: nothing

### New defect 5/6 (README claims every older directory has a superseded line; CO-43 send-series and CO-02 main-v2 lack one)
- verdict: FIXED
- now: CO-43-…/send-series-20261114/SUPERSEDED.md and CO-02-…/patches/main-v2/SUPERSEDED.md exist (full paths in the table check above).
- what is left: nothing

### CO-38/CO-39 rows stale
- verdict: PARTLY
- now: fixed in contributions/README.md (CO-38 index row "2026-11-16: shown to be a flake", the table's CO-39 row "the bot's base side was read on 11-14: PASS but a CheckValgrind failure ... on master"). Remaining: (a) the CO-38 row says "over all 8 runs of the day patched failed 2 of 8 and base 1 of 7, the same case" while CO-38-…/send-20261114/CHECKS.md:59 says "patched 2 FAIL of 8 (two different BAP/BASS cases), base 1 FAIL of 7 (the same case ... that failed on patched in the first run)"; (b) BRIEF.md (hand-off, "Lanes still running at this writing") still says "CO-38's BlueZ TestFunctional failures (2 of 3 patched; flake not shown) ... 4 CO-41 and CO-39 (no report yet) ... the btmon CVE" and "CVE-2026-105460 (btmon) not yet checked on 5.72", against rd (affects 5.72, shown).
- what is left: correct "the same case" in the row; update or date the BRIEF "lanes" bullet and the CVE sentence.

### CO-07/CO-34 rows
- verdict: FIXED
- now: README CO-07 "(not built as of 11-01; 2026-11-14: built ... build-20261114/)"; CO-34 "released in BlueZ 5.88 (2026-11-05)", next step "none".
- what is left: nothing

### rd table stale against its own Results
- verdict: FIXED (as a dated note; the table itself is kept as written, which the note says)
- now: rd-2026-11-14.md "Table rows that the results below overtake: CO-02 ..., CO-35 (refreshed 11-14, not 'package ready 11-02'), CO-38 ..., CO-39 ..., CO-22 (request v3 ...)".
- what is left: nothing

### Register intro: dossier "as soon as anything is written"
- verdict: PARTLY
- now: contributions/README.md CO-29/31/32/33 rows now say "(no dossier; the material is in docs/issues.md, U14/U17/U19/U20)". Remaining: README.md:164 "Items without a link have no dossier yet. One is opened as soon as anything is written about the item." still; CO-22 (send-ready, own package) still has no CO-22 folder.
- what is left: reword the rule or open CO-22.

### NOTES-FOR-OPERATOR.md / "open decisions are in each package's notes"
- verdict: PARTLY
- now: README.md:25-26 "The open decisions are in each package's notes and in `../reviews/2026-11-14T1400Z-...`" unchanged. CO-21 review-fixes-20261114/ now has NOTES-FOR-OPERATOR.md (+ -from-send-20261114.md); CO-35 has one. None in CO-02 review-fixes-20261115/, CO-05 review-fixes-20261114/, CO-38 send-20261114/, CO-22 refresh-20261114/; CO-04 and CO-12 only `notes.txt`; CO-20 `NOTES.md`.
- what is left: say "most", or add the files.

### CO-03 contents (dossier/reviews vs bundle)
- verdict: FIXED (M6 "partly" is right: both documents were right about their own build; my finding overstated it as a contradiction of one document)
- now: CO-03-bluez-u12-backport/README.md:12 "Note of 2026-11-16 (which build is staged): ... the staged `~co03.1` build does carry the BT-7 fixes ... The Ubuntu bundle's `5.72-0ubuntu5.9` is a different build and does not"; README.md index CO-03 row; BRIEF.md:202-206. BUNDLE.md:23 unchanged and correct. The note's claim about the .deb (`dpkg-deb`) I cannot check (not in the repo).
- what is left: nothing

### D1-D14 wording
- verdict: FIXED for the points raised
- now: table row CO-12 "(D5, open in `review-2026-11-02/followups.md`: its revised recommendation is an RFC ... the 11-14 lane recommended the clamp now)"; bundle row: "not filed; D6 (open in `review-2026-11-02/followups.md`) recommended CO-03 + CO-11a in one upload and CO-37's 5.72 backports as a separate SRU after D3, while this bundle merges all four: the operator has not decided". Remaining nit: the CO-12 index row (README.md:97) still says "the lane recommends the clamp now" without the D5 qualification.
- what is left: optional one clause in the CO-12 index row.

### CO-02 row does not carry the CI "must be resent"
- verdict: NOT ADDRESSED in the register row (fixed in STATUS.md:5 "the CI bot's rule makes v2 a resend")
- now: contributions/README.md CO-02 row: "closed by its bot in a sweep ... which is not a review" (no "resend").
- what is left: one clause.

### "All twelve" vs "eleven" BlueZ commits
- verdict: NOT ADDRESSED
- now: reviews/2026-11-13T0120Z-registers-and-contributions-status.md:257 "All twelve of our BlueZ commits"; file unchanged, README says eleven.
- what is left: nothing required (dated snapshot) or a note that the twelfth is d84171e6cd68.

### Elided identifiers (maintainer item 21, M21 "partly")
- verdict: PARTLY (M21 CLAIM CONFIRMED for the files it names; wider remainder below)
- now: counts of lines... I counted code spans containing "…" (python over `git show`), a8d0eb45 -> bbec102f: README.md 1 -> 0; BRIEF.md 12 -> 8; docs/STATUS.md 51 -> 33; docs/issues.md 61 -> 56; contributions/README.md 4 -> 4; contributions/rd-2026-11-14.md 11 -> 11. M21's "19 elided CO-nn-… / comms/ paths written in full" is confirmed: occurrences of `CO-nn-…`-style/`comms/…` in STATUS 13 -> 0, issues.md 5 -> 0, README.md 1 -> 0 (= 19), BRIEF 0.
  Remaining at HEAD, by kind: 
  - paths: contributions/README.md:105 `CO-20-…/send-20261114/`, :106 `CO-21-…/send-20261114/`, :115 `CO-30-…/rfc-20261114/`, :162 `X1…/patch1/` (4); rd-2026-11-14.md:102,102,103,108,113,116,126,129,139,143,149 (11, `CO-nn-…/...`); docs/STATUS.md:203 two `…/kernel/drivers/bluetooth/btusb.ko.zst` / `.../bluetooth.ko.zst`; docs/issues.md:1345 `tmp/ui-screenshots/2026-09-26T2255-…png`, :1807, :1910 `archive/…/journal-user-0755-0812.txt`, :1987 (placeholder `dev_…`); reviews/2026-11-15T0115Z-submitted-contributions-status.md:40 `CO-25-…/drafts/reply-1-zijun-hu-v4.eml`, :95 `CO-02-…/send-v2-review-fixes-20261114/`; contributions/CO-14-mesh-at-device-removal/README.md:37 `CO-04-…/send-20261114/circular-count.txt`.
  - hashes: docs/STATUS.md 14 spans (e.g. :50 `1f81392a…cbf7`, :65 `655b5286…2abc`, :133/231 `36175938…`, :231 `e60fcf37…` `7ccf101e…`, :238 `702186d9…`, :259 `17cfdfc4…` `d479d374…`, :267 `59d2ea79…`, :268 `0ec72957…`, :283 `e8152eae…`); docs/issues.md :1346 `b08cab16…`, :1977 `53a71259…`, :2009 `4661cc83…`; BRIEF.md:825 `815e7378…b90b72`.
  - log lines / commands (not identifiers): docs/issues.md ~49 spans (e.g. :1725 `Pair Device … Status: Authentication Failed (0x05)`, :1775 `rfcomm_emit_volume_changed(…, ...)`), STATUS 17 (e.g. :120 `[GNOME Settings] CREATE_RECORD_STREAM tag:478 … source-name:53`, :123 `heap-use-after-free … a2dp.c:2173 in a2dp_reconfig`), BRIEF 7 (`journalctl … | grep`, `AA:BB:CC:…`).
- what is left: contributions/README.md (4) and rd (11) `CO-nn-…` paths, the other 3 files above, and the hashes (the maintainer lists three with no full value; STATUS shows 14 truncated hash spans, issues 3, BRIEF 1, so more than three are truncated — whether full values exist elsewhere was not checked for all).

### /root/exp and machine-local paths
- verdict: PARTLY
- now: README CO-38 row fixed: "(built in a work area that no longer exists)"; BRIEF.md "`tmp/port-check/check.sh` (a machine-local script, not in a clone ...)" now labelled. Remaining: rd-2026-11-14.md:158 `/root/exp/agent-work/lane5-status-stable-20261114/status/`, :179 `/root/exp/agent-work/`.
- what is left: label as removed/untracked (rd is a dated page).

### CO-11a / CO-11b defined only inside one row
- verdict: NOT ADDRESSED
- now: README.md index row is "CO-11" with (a)/(b); table row :54 uses "CO-11a".
- what is left: one sentence.

### docs/contributions-roadmap.md; REVIEW-ROUND-2026-11-01.md
- verdict: NOT ADDRESSED (both unchanged: `git diff a8d0eb45 HEAD --name-only` lists neither)
- now: roadmap :3 "unchanged in substance", :25 BZ-free row with CO-23, :90 "BZ-free: one crash, no mechanism. Not a contribution until..."
- what is left: optional date markers.

### New defect 2: 0115 report vs table/STATUS on CO-02
- verdict: NOT ADDRESSED
- now: reviews/2026-11-15T0115Z-submitted-contributions-status.md unchanged (no diff since a8d0eb45): still "a possible lock cycle ... Reachability is not settled", names `send-v2-review-fixes-20261114/` as the v2 package; table/STATUS say the cycle is real and that package superseded. The report is a dated snapshot and its header says "Revised ... ~02:45 UTC"; nothing marks it superseded on CO-02.
- what is left: a dated note at its top or in the checks file.

### New defect 3: new "…" in STATUS and the 0115 report
- verdict: PARTLY — STATUS paths fixed (13 -> 0 for CO-nn-…), the 0115 report's two and CO-14 README:37 remain (see above).

### New defect 4 / 6: CO-02 current package lacks NOTES-FOR-OPERATOR; "cover to do"
- verdict: PARTLY
- now: the cover now exists: CO-02-…/review-fixes-20261115/msg/cover-alt.txt (lines 17-28 quote sco-tester 35 cases, mgmt-tester 526, iso-tester 213; "The l2cap-tester was not run with these two patches"; "These patches were not run on the laptop"), and the table row says so. Still no NOTES-FOR-OPERATOR.md in that directory (the superseded send-v2-20261114/ has one). BRIEF.md hand-off still says "Checkpatch, the bot's CI and a cover are still to do."
- what is left: fix "and a cover" in BRIEF; add notes or point to the old ones.

## Spot checks of items that were FIXED in recheck 1 (3: BRIEF ready list; CO-37 "in 5.88"; 'U24'): all still hold
- BRIEF ready list (CO-39, CO-41, CO-12, CO-23, CO-37 listed) unchanged; CO-37 row "in BlueZ 5.88; corrected 2026-11-15" unchanged. 2 of 2 spot-checked, no regression.

## Maintainer claims checked (checks document)
- M1 CO-35 "mail-from-send-20261114/ holds a byte-identical copy of send-20261114/mail/, with COPIED-FROM.md and its own SHA256SUMS": CLAIM CONFIRMED. `diff -r send-20261114/mail review-fixes-20261114/mail-from-send-20261114` shows only COPIED-FROM.md and SHA256SUMS extra; `sha256sum -c` has 0 failures.
- M2 cover-alt.txt "quotes only numbers recorded for that candidate ... l2cap-tester and the laptop 'not run'": CLAIM CONFIRMED against cover-alt.txt:17-28, 39 and README.md:118 ("33 of the 35 posted cases ..., mgmt-tester 526/526"). Note the cover text at :20 says "35 posted cases ... without the patches 31 pass" (not rechecked against the logs; not opened).
- M3 markers and dated pointers: CLAIM CONFIRMED (above). "BRIEF calls the README table the record": CLAIM CONFIRMED (BRIEF.md:171-173).
- M5 CO-38 cover From: no `<AUTHOR-EMAIL>`: CLAIM CONFIRMED for current packages (grep AUTHOR-EMAIL only hits CO-37's superseded `work/patches/5.72-3-20261102` and `master-final-6-20261102`, both marked SUPERSEDED.md).
- M6 CO-03 "partly": CLAIM CONFIRMED; the maintainer is right, my "contradiction" was one of unlabelled builds (see above). The `.deb` inspection itself is outside the repo and was not verified.
- M20 "Dossiers and rd-2026-11-14.md corrected; D-01/D-02 open": CONFIRMED for rd (Corrections section) and the dossiers I sampled (CO-03, CO-35, CO-04/05/20/21 index rows); older docs not in my part.
- M21 "19 elided paths written in full in STATUS, issues.md, BRIEF; three truncated hashes open": the 19 is CONFIRMED (13+5+1); "three truncated hashes" is REFUTED as a count (18 truncated hash spans in STATUS/issues/BRIEF, see above), though it may mean three with no full value anywhere.
- M "The CO-38 row of contributions/README.md named a work area that no longer exists; it now says so": CLAIM CONFIRMED.
- M14 "README.md (root): CO-02 and CO-25 bullets follow the send table": not checked in depth (root README is another reviewer's part).

## New defects introduced by this round
1. CO-38 index row misstates the flake: "patched failed 2 of 8 and base 1 of 7, the same case" vs CHECKS.md:59 ("two different BAP/BASS cases" on patched). Low.
2. BRIEF hand-off still carries stale bullets inside the block that now calls the table the record: "Checkpatch, the bot's CI and a cover are still to do" (cover exists), the "lanes still running" bullet, the CVE "not yet checked". Low.
3. New truncated hash with ASCII dots in CO-03-bluez-u12-backport/README.md:~19 `59d2ea79...` (identifier rule). Low.
4. contributions/README.md:23-26 now has an exception for CO-35 Signed-off-by ("the six CO-35 backports carry ... a Signed-off-by of the operator") in the middle of "Each package carries no Signed-off-by"; BRIEF.md "Packages made since 11-13 carry no Signed-off-by" has no such exception (the packages are from 11-14 and 11-02). Low, wording contradiction between README and BRIEF.
5. README.md:25 sentence "The open decisions are in each package's notes" got longer (parenthesis inserted mid-sentence) and still overclaims. Low.

---

# Part: docs-a

## docs-a recheck2 against the checkout of main (tip bbec102f)
Basis: `git diff a8d0eb45 HEAD --stat -- docs/` touches only STATUS, changes-applied, fix-proposal, install, investigation-plan, issues, restore-original-state, tooling-index, ui-capture; plus README.md. Of my 13 files only fix-proposal.md and investigation-plan.md changed; sent-mails.tsv, bug-report, missing-quirks-entry, kernel-send-package, pre-submission-checklist, external-review-brief, review-task, related-reports, investigation.md, firmware-hypothesis are byte-identical.

## Items from my recheck file that were NOT ADDRESSED / PARTLY

### kernel-send-package.md unlabelled; "does not exist yet"; README quote
- verdict: NOT ADDRESSED
- now: docs/kernel-send-package.md:27 "that one does not exist yet (`BT-1`, BRIEF §9.6)", :129 unchanged (file untouched)
- what is left: banner + fix the present-tense text

### kernel-send-package.md cites BRIEF §9.6/§9.9
- verdict: NOT ADDRESSED
- now: docs/kernel-send-package.md:27, :83, :134 unchanged
- what is left: repoint

### pre-submission-checklist.md purge/gates/obsolete items
- verdict: NOT ADDRESSED
- now: docs/pre-submission-checklist.md:23-24 "must happen before submission" unchanged
- what is left: mark superseded (maintainer item 20: D-02 "open", so consistent)

### pre-submission-checklist.md §2b autosuspend
- verdict: NOT ADDRESSED
- now: docs/pre-submission-checklist.md:112, :117-125 unchanged
- what is left: optional

### missing-quirks-entry.md missing Harcsa / v7.3-rc1 / stable list / 74 / 12 / -38,-42,-43
- verdict: NOT ADDRESSED
- now: file unchanged; README.md:103-106 still calls it "The full argument"
- what is left: add a current-facts banner

### missing-quirks-entry.md "untested here" banner
- verdict: NOT ADDRESSED
- now: docs/missing-quirks-entry.md:19 unchanged
- what is left: optional

### bug-report.md EX-nnn labels, "seven deaths"
- verdict: NOT ADDRESSED
- now: docs/bug-report.md:174 unchanged
- what is left: operator's call on EX-nnn

### external-review-brief.md no status label
- verdict: NOT ADDRESSED
- now: docs/external-review-brief.md:1-5 unchanged
- what is left: banner

### review-task-bluez-patches.md unlabelled
- verdict: NOT ADDRESSED
- now: docs/review-task-bluez-patches.md:1 unchanged
- what is left: one-line label

### related-reports.md "only unblocked path upstream"
- verdict: NOT ADDRESSED
- now: docs/related-reports.md:172 unchanged
- what is left: label

### investigation-plan.md 0x0428 vs 0x043D at line 44
- verdict: NOT ADDRESSED
- now: docs/investigation-plan.md:44 unchanged (retraction :112-118)
- what is left: inline marker

### investigation.md Tier-1 autosuspend
- verdict: NOT ADDRESSED
- now: docs/investigation.md:425-436 unchanged
- what is left: optional

### sent-mails.tsv stable-request row path cell
- verdict: NOT ADDRESSED
- now: docs/sent-mails.tsv:7 "not kept in the repository"; patches/diag/stable-request-dc16388d45ec.md exists
- what is left: point the cell at it

### Link/path/elision checks
- verdict: PARTLY
- now: fixed: README.md link text is now `contributions/CO-02-sco-connect-reuses-closing-link/` (README.md:163). Remaining: docs/missing-quirks-entry.md:18 "`7.0.0-28…31`", docs/investigation-plan.md:556-559 "…/symtest/repo" (the latter is a path in a command transcript).
- what is left: write the kernel names in full

### README: CO-02/CO-25 bullets stale vs STATUS
- verdict: FIXED
- now: README.md:153-162 "no maintainer reply as of 2026-11-15 ... hangs the test guest with debug-only delays (3 of 3, 2026-11-15) and is not to be sent; the candidate is a non-sleeping 2/2"; :179 "(read again 2026-11-15; no other reply)"
- what is left: but see new defect "cover still to do" below

### README: Next candidates vs "What to send" table
- verdict: FIXED
- now: README.md:176-198 now names CO-35, CO-43, CO-44, CO-04, CO-05, CO-22, CO-38, CO-21, CO-20 (patch 1 alone), CO-12, CO-23, CO-37, CO-39, CO-41, the Ubuntu bundle (CO-11/03/37/40) and says which wait for the route (CO-12, CO-23, CO-37, CO-35). Held CO-43 B2/D v2, CO-30 RFC and CO-02 v2 not named in that list (CO-02 v2 is in its own bullet).
- what is left: nothing

### README: "every tool takes BT_VID/BT_PID"
- verdict: FIXED
- now: README.md:133-136 "the tools that look the controller up by its USB id take BT_VID/BT_PID (bt-state detects the device when they are unset; bt-status defaults to 13d3:3503; bt-crash, bt-boots and sanitize-logs.sh do not read them)". Checked in the checkout of main: bt-state:22 `VID="${BT_VID:-}"`, bt-status:93 `${BT_VID:-13d3}`; grep -c BT_VID: bt-crash 0, bt-boots 0, bt-diagnose 0, bt-incident 0, bt-fault-window 0, sanitize-logs.sh 0.
- what is left: nothing

### README "two controlled demonstrations" vs plan/proposal ("three")
- verdict: PARTLY
- now: fixed: docs/fix-proposal.md:9-11 "two controlled demonstrations ... and a third case after a reset this project did not issue (`EX-026`)"; docs/investigation-plan.md:55-57 same; :723-724 "two controlled demonstrations ... (and a third case ...)". Remaining: docs/investigation-plan.md:60-61 "It **automates the operation we have three demonstrations of killing the device with**" (same paragraph that was just corrected).
- what is left: change "three" to "two controlled (plus one not ours)"

### README CO-35 scope vs dossier
- verdict: FIXED
- now: contributions/CO-35-l2cap-ecred-defer-hang-stable/README.md:3-10 "Note of 2026-11-16 ... The mails cover 7.3.y, 6.18.y, 6.12.y and 6.6.y; 6.1.y, 5.15.y and 5.10.y hang only with the non-default enable_ecred parameter"; matches README.md:186-188.
- what is left: nothing

### README Environment BlueZ line vs staged CO-03 bluetoothd
- verdict: NOT ADDRESSED
- now: README.md:222 "BlueZ : 5.72 (the running patched daemon is a rebuild of 5.72-0ubuntu5.5; the package is 5.72-0ubuntu5.8 ...)"; BRIEF.md:107 and :179-180 "CO-03's bluetoothd is staged on disk (11-13), not running until bluetoothd restarts"; STATUS machine section says the same
- what is left: add "CO-03's 5.72-0ubuntu5.9~co03.1 bluetoothd staged on disk, not running"

### New-defects section of my recheck: dossier READMEs naming older send-* dirs
- verdict: FIXED (spot-checked CO-35)
- now: CO-35 README.md:3-10 newer note; contributions/README.md:22 "every package's older directory carries a "superseded" line"
- what is left: nothing

## Spot-check of items I had FIXED
- README tree map "the applied BlueZ patches" (1 item): still README.md "patches/bluez/        the applied BlueZ patches, ..."; no regression.

## Maintainer's claims about my part (checks document)
### Item 12 "two controlled demonstrations plus EX-026 in the plan, the proposal and the tooling index"
- verdict: CLAIM CONFIRMED with one leftover
- now: fix-proposal.md:9-11, investigation-plan.md:55-57 and :723-724, tooling-index.md:240 "two controlled demonstrations". Leftover: investigation-plan.md:60 "three demonstrations". Our finding was right.
- what is left: that one phrase

### Item 14 "T-04: bt-status does not hard-code the device; 27 of 38 tools never read the variable"
- verdict: CLAIM CONFIRMED
- now: tools/bt-status:93 `"${BT_VID:-13d3}"` (a default, overridden by the variable). Count on the checkout of main: 26 of 38 `tools/bt-*` files lack the token (maintainer says 27; counts differ by one, depends on file set). My earlier finding was about "every tool", which was false; I did not claim bt-status hard-codes it, so nothing to withdraw.
- what is left: nothing

### Item 14 "CO-02 and CO-25 bullets and the next candidates follow the send table"
- verdict: CLAIM CONFIRMED (CO-02 v2 cover caveat below)
- now: README.md:153-162, :179, :182-197

### Item 20 "older docs/ files without a date label: open"
- verdict: CLAIM CONFIRMED
- now: git diff a8d0eb45..HEAD empty for kernel-send-package, pre-submission-checklist, missing-quirks-entry, external-review-brief, review-task-bluez-patches, related-reports, investigation, bug-report, sent-mails.tsv. So D-01/D-02 remain, as declared.

## Other README statements still disagreeing with BRIEF hand-off / STATUS / "What to send"
1. README.md:161 "with its checks and cover still to do" vs contributions/README.md:47 "the cover for the two patches is `.../review-fixes-20261115/msg/cover-alt.txt` (rewritten 2026-11-16 ...)" (file exists: msg/cover-alt.txt) and the checks document item 2 ("Checksums made"). BRIEF.md:193 "Checkpatch, the bot's CI and a cover are still to do." is the same stale phrase. Medium-low: README/BRIEF say no cover, the table says there is one; only checkpatch and CI are open.
2. README.md:222 BlueZ environment line omits the staged CO-03 bluetoothd (above).
3. README.md:194-195 route-decision list "(CO-12, CO-23, CO-37, CO-35)" vs BRIEF.md:185-186 which also names CO-05 + CO-26 as having operator decisions open (table row: "operator: the variant and the order"). Low.
4. README.md:149 heading "Current direction — 2026-11-15" while the section was edited on 11-16 and cites a 11-16 table state; the "no maintainer reply as of 2026-11-15" is consistent with STATUS top (11-15). Cosmetic.
5. Verified consistent: Kernels line vs BRIEF:178-180 and STATUS machine bullet (-43 stock since 11-12 22:55, E3 retired); BT-16 three boots; "twelve instances"; patches/diag map line (patches/diag has only README.md, the E1 patch, stable-request file); Branches paragraph vs BRIEF:228-235 (16 branches deleted 11-15).

## New defects introduced by this round
- docs/investigation-plan.md:60-61 keeps "three demonstrations of killing the device" two lines below the corrected paragraph (:55-57 says two + one not ours): the fix is applied in two of three places in the same file.
- README.md:161 and BRIEF.md:193 "cover still to do" contradict contributions/README.md:47 (cover-alt.txt rewritten 2026-11-16).
- No new "…" identifiers in README or the two changed docs; no new reference to a path missing on main (README links I checked: contributions/CO-02-sco-connect-reuses-closing-link/README.md, patches/diag/, reviews/2026-11-12T1508Z-upstream-contributions-status.md exist).

---

# Part: docs-b

## Recheck 2, docs-b, against the checkout of main (bbec102f). Files of my part changed since a8d0eb45: README.md, docs/STATUS.md, docs/issues.md, docs/ui-capture.md, tools/bt-ui-capture, scripts/bt-ui-atspi.py, scripts/prove-ui-capture.sh. Everything else (docs/source-*, external-cache*, ui-capture-research, userspace-upstream-check, mesh-tester-ci, results/, retest/) unchanged.

### external-cache.md cache location vs BRIEF §7
- verdict: NOT ADDRESSED
- now: docs/external-cache.md:28 "/var/cache/bt-investigation/<topic>/" (file unchanged); ui-capture-research.md:16,20 same
- what is left: say cache/ (git-ignored, patch exports) is the practice, or mark superseded. Maintainer item 20 "D-01 ... open" is CLAIM CONFIRMED.

### external-cache-manifest.tsv row 4; source-map/source-access undated
- verdict: NOT ADDRESSED (both files unchanged)
- what is left: as before

### 5.88 release check: 5.87 control output not shipped
- verdict: NOT ADDRESSED
- now: results/bluez-5.88-release-check-2026-11-07/ holds README.md and output.txt only; README.md:18 "→ 11 lines, each `NOT in 5.87`"
- what is left: ship output-5.87.txt

### Privacy: /root/exp, /home/i paths
- verdict: NOT ADDRESSED (unchanged) and see new defect 2
- what is left: placeholder paths

### mesh-tester-ci/README.md omits instrumentation-from-cache-20261114/
- verdict: NOT ADDRESSED (file unchanged)

### U12 section "Next" already done
- verdict: FIXED
- now: docs/issues.md Next list "1. Build our bluetoothd ... **Done 2026-10-31:** `5.72-0ubuntu5.9~co03.1`, tested in VMs (70 of 70 before, 0 of 70 after ...)"; step 2 "Still open", step 3 "Not filed"
- what is left: nothing

### U8 section "that test is next" / STATUS U8 row
- verdict: PARTLY
- now: fixed: docs/issues.md after the U8 text a new "State 2026-11-16 ... silence is on their side; CO-18 was dropped ... E3 is retired". Left: docs/issues.md:1550 still "that test is next." (kept above the dated note); docs/STATUS.md:109 U8 row unchanged: "a btusb debug patch is written, installable only after trial E3 #1 closes"
- what is left: fix the STATUS row (maintainer's item 15 did not touch it)

### U13 owners
- verdict: PARTLY
- now: fixed: docs/STATUS.md U13 row "(the BlueZ side: contributions/CO-27-le-only-pairing-u13/; the GNOME side is contributions/CO-42-gnome-bluetooth-silent-pairing-failure/, a comment drafted, local only; corrected 2...". Maintainer's "two owners, CO-27 and CO-42" is CLAIM CONFIRMED (and my earlier "CO-27 vs CO-42" was only partly right: both own a part). Left: the issues.md U13 section "Three parts, three owners" names no CO id for the BlueZ/GNOME parts (only one stray CO mention in its first 25 lines)
- what is left: add the CO ids to the section

### U29 owners CO-39..42
- verdict: NOT ADDRESSED
- now: U29 section in docs/issues.md still has no CO-39/40/41/42

### U12 occurrence history 3 vs 9+1; counts
- verdict: NOT ADDRESSED (no reconciling sentence); numbers themselves still agree

### U10: 858 Dual Channel frames vs CO-08 single-channel
- verdict: PARTLY
- now: new "State 2026-11-16: unchanged; ... Its dossier is contributions/CO-08-pipewire-u10-sbc-xq/ (the decisive test is the operator's 10-minute marked A-B-A-B test)"; docs/issues.md:1567 "858 Dual Channel frames" still unreconciled with CO-08's "every SBC-XQ test sound was single-channel"
- what is left: one sentence

### "On the wider claim" contradicts README
- verdict: FIXED (for the section); PARTLY for its neighbour
- now: docs/issues.md ~2083 new "Dated note, 2026-11-16: ... the cause is the missing 13d3:3503 device-table entry ... superseded for the unpatched case ... the Android comparison above is a clue that was not tested". Left: "Why this class of bug goes unreported" docs/issues.md:2122 "The only fix is a cold power-off", :2130 "roughly fifteen purpose-built tools" unchanged and undated
- what is left: one dated line for that section

### Evidence paths outside repo and elisions in issues.md
- verdict: PARTLY
- now: fixed: CO-nn-… elisions (0 left in issues.md/STATUS.md/README.md; claim "19 elided CO-nn-… written in full" CLAIM CONFIRMED), tools/suspend-cycles.py corrected to results/incident-2026-11-12-1803/tools/. Left: issues.md:1910 `archive/…/journal-user-0755-0812.txt`, 1977 `53a71259…`, 1984 `/root/exp/agent-work/u29-t1-a2dp-backport/`, 2009 `4661cc83…`; `tmp/u16-dup-check/cmp.sh` unmarked. Maintainer says three truncated hashes with no full value are "open": consistent.

### Register order / no sections for U21-U28, U30, U31
- verdict: FIXED
- now: docs/issues.md ~1273-1277 "*Note, 2026-11-16: U21 to U28, U30 and U31 (and ... M-1 and M-2) have a row in the table above and in docs/STATUS.md but no section of their own in this file ...*" (U8 after U9 ordering unchanged, cosmetic)

### Spot-checks of items I had FIXED (3)
- README BT-16: README.md:169 "At three boots (2026-11-05, ...": ok. README results/ map still the extended list (README.md:273): ok. ccfc358 withdrawn item: unaffected. No regression.

### Maintainer claims checked
- Item 16 "BT-18 to BT-23 brought to 11-14; U8, U10, U12, M-3, Evidence model, On the wider claim dated": CLAIM CONFIRMED for the dated notes seen in docs/issues.md diff (U8, U10, U12 states, M-3 status, wider claim, BT-18..23 status lines). Exception noted above (U8 line 1550 and the STATUS row).
- Item 20 "D-01 open": CLAIM CONFIRMED (docs/external-cache.md, source-*.md still undated).
- Item 21 "19 elided CO-nn-… written in full": CLAIM CONFIRMED; "log-line ellipses are not identifiers": accepted.
- Item 15 (STATUS): "U26 and U27 evidence rewritten": diff shows U26/U27 rows changed; accepted.
- U21 text of 2026-11-16 (docs/issues.md, "2026-11-16 00:16, the Shure again"): CLAIM CONFIRMED against evidence/sessions/20261116-002107-shure-paired-in-handsfree-no-codec-row/NOTES.md: 5 A2DP + 3 hands-free profiles listed, "profile-route = MISMATCH active #261 routes [3]", off -> headset-head-unit-msbc 6 ms (00:15:45.406 -> .412), Settings process started Nov 15 09:47:43, "Found default profile headset-head-unit-msbc" with no recording application. Times consistent (paired 00:15:43, screenshot 00:16:06). Minor: issues.md row says "00:15", section heading "00:16" (STATUS has both).
- docs/ui-capture.md keeper section vs tools/bt-ui-capture: CLAIM CONFIRMED point by point: enable-light/disable-light exist; keeper writes bt-ui-light-keeper.service (oneshot, `start-light --quiet-if-no-session`) and .timer (OnBootSec=1min, OnUnitActiveSec=2min, Persistent=false) into /etc/systemd/system (BT_UI_UNITDIR); path with space/quote refused (case `*[!A-Za-z0-9_./+:@-]*`); gone path -> exit 0 with one message; ONE directory reused via `current`, `--new` opens another; `.stamp.<unit>` per user unit, restart once if no stamp, stop/start on login change; greeter session = no session -> only sysbus unit; marks only when something changed (START vs CHANGE); stop-light prints NOTE that keeper restarts within 2 min; status-light shows keeper enabled/last run; disable-light leaves units and logs. scripts/prove-ui-capture.sh adds ~50 assertions covering these (reboot reuse, repeated call silent, greeter, new login, logout, enable/disable idempotent, refusal without root, space path). Help now `sed -n '2,/^$/p'` and prints exactly the header (blank line at 101).

## New defects introduced by this round
1. Medium, needs-check: `enable-light` installs a root systemd unit under /etc/systemd/system that every 2 minutes runs `/bin/sh -c 'exec "<checkout>/tools/bt-ui-capture" start-light ...'` as root from the repository checkout (tools/bt-ui-capture:keeper_service). If the checkout or its parents are writable by the desktop user, that user can obtain root; docs/ui-capture.md ("The path of the tool is written into the unit") does not warn, and the tool does not check the owner/mode of $SELF or $REPO/scripts/bt-ui-atspi.py (which is copied and run as the user, so only the tool itself is the root hazard).
2. Low, privacy: the new evidence record evidence/sessions/20261116-002107-shure-paired-in-handsfree-no-codec-row/NOTES.md publishes `/home/i/.local/state/wireplumber/...`, `ls` lines with owner `i i`, and `bt-audio-policy.py --user i` (the desktop user's login name and home), plus "run with the real address" commands.
3. Low, new elided identifier: docs/STATUS.md:50 "SHA-256 `1f81392a…cbf7`" (full value is in contributions/CO-25-qualcomm-rom-report/log.md:270, so it can be written in full).
4. Low, naming: the option `--quiet-if-no-session` suppresses output on "no change", not only "no session" (tools/bt-ui-capture start_light_main), so the name mis-describes the behaviour that docs/ui-capture.md ("no output with --quiet-if-no-session") documents correctly.
5. Low: docs/issues.md U8 section now contradicts itself in place: line 1550 "that test is next" followed by the dated "State 2026-11-16" saying it is answered (only the new note is current).
No parser regression found in bt-ui-atspi.py (registration_mode reports failed registrations); no missing referenced path in the changed text of README/STATUS/issues/ui-capture (all backticked repo paths exist).

---

# Part: comms-reviews

## Recheck 2 against the checkout of main (bbec102f; shallow clone, 135 commits visible). Remote not checked.

### Item: reviews/README.md unlisted files (was NOT ADDRESSED) / maintainer item 19 "65 unlisted files indexed"
- verdict: CLAIM CONFIRMED (65), PARTLY for the register as a whole
- now: reviews/README.md "## Files not listed in the tables above" has 65 rows (`sed -n '/^## Files not listed/,/^## Adding/p' | grep -c '^| \['` -> 65). My script over README links/mentions vs `ls reviews` (118 files besides README): only 2 not named anywhere: reviews/2026-11-16T0000Z-project-review-recheck-checks.md and 2026-11-16T1300Z-co46-noble-sru-review-reviewer-7-verbatim.md (both added after the index). The index says "no verdict is given here" (README intro of that section).
- what is left: list the two new files; each later review will repeat the gap unless the Adding-a-report step is followed.

### Item: R2-21, R2-25, R2-64/65 (maintainer 19) (was NOT ADDRESSED)
- verdict: FIXED for R2-21/R2-25; PARTLY for R2-64/65
- now: README:310-312 "**done** (re-run 2026-11-16)". Checks reproduced: `grep -c 'EX-04' docs/issues.md` 7; `grep -c '2.19' docs/bug-report.md` 1 and `grep -c -E '7\.6|16\.2'` 0; `grep -c ls-files tools/bt-trial` 2. R2-64/65 cell says "`BT_TRIAL_PROBE=1` (`tools/bt-trial:465-466`)": in the checkout of main lines 465-466 are `echo "auto=1"` / `[[ "$declared" != ...`; the opt-in `hci_alive` call is at tools/bt-trial:490 (inside `if [[ "${BT_TRIAL_PROBE:-}" == 1 ]]`, autostop starts :474). Substance (passive by default, probe opt-in) is right.
- what is left: correct the cite to :487-491.

### Item: CO-01..CO-10 block vs contributions/README (was NOT ADDRESSED)
- verdict: PARTLY
- now: README.md after :452 adds "*State on 2026-11-16, for the rows whose Status above is stale ...* CO-09: `7.0.0-43` ... CO-10: sent 2026-10-21 ...". Table rows unchanged (`| CO-09 | ... | open — watch`, `| CO-10 | ... | **blocked**`), and the paragraph uses contributions numbering for CO-02/CO-03 ("series was sent on 2026-10-27", "built and tested ... staged") while the row CO-02 above it still reads "Re-read `U7` against the kernel's SCO connect path".
- what is left: nothing essential; ids still mean two things in one section.

### Item: register text floors/counts (was NOT ADDRESSED)
- verdict: PARTLY
- now: fixed: HC-04 row now "... `--min 85` awk in `checks.yml` when it landed; on 2026-11-16 `checks.yml` has `--min 80` shell and `--min 95` awk"; :283 "now 65" -> "then 65 (the shell floor in `checks.yml` is 80 on 2026-11-16)". Remaining: reviews/README.md:170 "`tests/run-tests` (329 invariants)" unchanged; "this commit" still in 8 Landed cells (HC-09, HC-10, TX-01..03, TX-05, TX-06, R2-105).
- what is left: update or date the 329 and the "this commit" cells.

### Item: Naming schemes (was NOT ADDRESSED)
- verdict: NOT ADDRESSED
- now: reviews/README.md convention section untouched by `git diff a8d0eb45 HEAD`; only the unlisted-table was added.
- what is left: document the other schemes or ignore.

### Item: README "Branches" paragraph (was NOT ADDRESSED)
- verdict: PARTLY
- now: README.md:299-303 "By the convention in reviews/README.md, an assessment is written on a branch `review/<UTC timestamp>` ... which remote holds such a branch at a given time is not fixed (the 16 old remote branches were deleted on 2026-11-15; BRIEF, hand-off, 'Old remote branches' lists what remains)". Hedged, but "By the convention in reviews/README.md" is wrong: reviews/README.md states no branch convention (checked: no "review/" branch rule in its Convention section); reviews/README.md:63 and :326ff still cite `review/2026-08-15T1752Z-fixes` / `review/2026-09-17T2251Z-fixes`.
- what is left: say the convention is the project's, not reviews/README's, or add it there.

### Item: ci-local eb2e6d6/6ada2a1 (was PARTLY)
- verdict: PARTLY
- now: fixed: docs/STATUS.md:463 "**Superseded 2026-11-15 (corrected 2026-11-16):** ... `ci/upstream-ci-local`'s two commits are on `main` as the ports `8b71499` and `a56141e`"; STATUS:466 list marked "the state of 10-18, not a to-do". Problem: in the checkout of main `git branch -a --contains 8b71499` lists only old remote branches (land/branches-20261018, ci/deploy-rehearsal-20261017, tests/unit-testing-introduction ...), and `git merge-base --is-ancestor 8b71499 HEAD` is false (same for a56141e); subjects are the ci-local line's ("comms: the ci-local line reports to both maintainers ...", "results, comms: the 10-13 send package through the list bot's checks ..."), i.e. the old branch copies, not main's ports. The clone is shallow so main's own ids cannot be seen. BRIEF.md:144 still "landed on `main` that day [10-13]".
- what is left: give main's own commit ids (or say the content, not the ids, is on main); the cited ids vanish with the deleted branches.

### Item: delete-command contradiction / N-06 (was FIXED in BRIEF, comms contradiction)
- verdict: FIXED (maintainer item N-06 CLAIM CONFIRMED)
- now: BRIEF.md:228-233 "Old remote branches: done 2026-11-15 ... `comms/2026-11-15T2130Z-...` still says the deletion 'remains the operator's' and quotes this file as saying the 11-13 note 'gives no command and no count'; both were true of the text it read, neither is true now, and `comms/` is append-only, so this line is the correction (2026-11-16)." This matches what I found. README.md:299-303 also consistent. `git branch -r` in the checkout of main still lists 20 remote-tracking branches (stale clone; remote itself not checked).
- what is left: nothing.

### Item: BRIEF §9.2 six tasks / device survey (was NOT ADDRESSED, NOT ADDRESSED)
- verdict: survey: FIXED; "six tasks" list: NOT ADDRESSED (maintainer item 13 CLAIM CONFIRMED for survey)
- now: BRIEF.md:693-695 "the device survey had no record of its scope on either side, and **the operator dropped it** the same day, accepting the four recommendations (`comms/2026-10-19T0601Z-from-test-suite-maintainer-to-main-branch-maintainer.md`; corrected 2026-11-16)". BRIEF.md:689-691 still lists "(source review, instrumented `btusb` logging ..., bug-report audit, `BL-09`, `bt-crash` tests, device survey)" which is not the six of comms 2026-08-22T1215Z §3 (bug-report, BL-09, bt-crash, bt-snapshot, source branch, BuildID); the rename "Test Branch Maintainer" -> "test-suite maintainer" added.
- what is left: reconcile the list with 08-22T1215Z, or say the survey was never one of the 08-22 six.

### Item: BRIEF "Who works where" names retired branches (was NOT ADDRESSED)
- verdict: PARTLY
- now: BRIEF.md:145 "works on the branch `tests/test-suite` and merges `main` into it on their side (`comms/`; the branches ... named before 2026-11-16 are among the 16 deleted on 2026-11-15)". Names fixed. "merges main into it" disagrees with comms 2026-11-13T0100Z ("the branch is rebased onto it, commit by commit") and with comms 11-15T2010Z lines (move the branch to main's tip by force-push, else merge).
- what is left: say "rebased onto/moved to main" or "kept at main's tip".

### Item: §8a rules' instances not in lessons (was NOT ADDRESSED)
- verdict: NOT ADDRESSED
- now: BRIEF.md:573 still points to lessons/2026-08-22... and 08-27...; `lessons/` unchanged since a8d0eb45.
- what is left: add instances or retarget.

### Item: lessons 08-27 edited after its stamp (was NOT ADDRESSED)
- verdict: NOT ADDRESSED (unchanged, low)
- now: lessons/2026-08-27T1200Z-test-suite-maintainer.md two "Corrected 2026-09-18" blocks still there.
- what is left: nothing/accept.

### Item: BRIEF-cited ids (informational) ; naming ; comms conventions (23 files lack front matter; two 11-15 messages)
- verdict: NOT ADDRESSED
- now: comms/README.md and comms/ unchanged since a8d0eb45 (`git diff --name-only` lists no comms file). 2026-11-15T2010Z and 2130Z still lack front matter; 2130Z timestamp (21:30Z) still later than its commit c6589ccc (21:12+01:00).
- what is left: only a new message can add the correction (append-only); the maintainer put N-06 in BRIEF.

### Item: elision in file names (was NOT ADDRESSED)
- verdict: FIXED in BRIEF; PARTLY overall
- now: BRIEF.md:691 `comms/2026-10-19T0504Z-from-test-suite-maintainer-to-main-branch-maintainer.md` in full; no `Z-…` left in BRIEF (grep). STATUS:398-area not rechecked beyond grep. Remaining: BRIEF.md:825 "sha256 `815e7378…b90b72`" (maintainer item 21 says three truncated hashes are open). comms files (09-24T0923Z:22, 10-19T0504Z:247, 10-21T0225Z:4) are immutable and unchanged.
- what is left: write the hash in full.

### Item: Open requests with no answer (was PARTLY)
- verdict: PARTLY
- now: comms 11-15 (2130Z) answered the 11-07 questions; install.sh now installs bt-journal-files: install.sh:547-553 `install_file "$SRC/tools/bt-journal-files" /usr/local/bin/bt-journal-files 0755` plus its units (maintainer item 11 CLAIM CONFIRMED). Still open: T1/SR1 (STATUS "Left before the deploy"), second-maintainer questions (hooks branch, history-rewrite-stopped.md), 10-21 main->second questions, ci-local flake-rate item; no new comms since a8d0eb45.
- what is left: record closure or "dropped" for those.

### Item: Private working arrangements in comms (was NOT ADDRESSED)
- verdict: NOT ADDRESSED (maintainer item 24: operator)
- now: unchanged; checks file reviews/2026-11-16T0000Z-project-review-recheck-checks.md:64 "The working arrangement in the text, and a scan pattern ... **operator** | Asked again on 2026-11-16, with N-01 named." New files add to the inventory (below).
- what is left: the author's decision.

### Maintainer claims in reviews/2026-11-16T0000Z-project-review-recheck-checks.md concerning my part
- item 13 (BRIEF branch names, survey dropped, "written in full"): CLAIM CONFIRMED with the two exceptions above (BRIEF:145 merge wording; BRIEF:825 truncated hash).
- item 19 (65 indexed; R2 rows): CLAIM CONFIRMED (65; R2-21/25 greps) with the wrong line cite :465-466.
- N-06: CLAIM CONFIRMED (BRIEF:228-233).
- item 21 "comms/ paths written in full in BRIEF": CLAIM CONFIRMED for BRIEF (no `Z-…` left).
- item 11 install.sh claim: CLAIM CONFIRMED (install.sh:547-553).
- header "The recheck itself (`3f8e8f62`) is on a separate branch": cannot be verified (branch not in this clone).
- None of our findings was judged "wrong" in the part I checked; none withdrawn.

## Privacy inventory: files added to reviews/ and comms/ since a8d0eb45 (no judgement)
`git diff --name-only a8d0eb45 HEAD -- comms reviews`: no comms file; reviews: three new files + README.md.
1. reviews/2026-11-16T0000Z-project-review-recheck-reaction-verbatim.md (54 lines). Pasted message, "kept as received, except that one branch name is replaced by '[a separate branch]'" (lines 3-7). Describes how work is done:
   - lines 12, 14, 16, 18, 38, 44, 50 and 52-54 (not repeated here; the file was later removed from the tip of main).
   - :16 (publish scan) "The publish scan flags one quoted Message-ID fragment ... rewording it, then committing and pushing."
2. reviews/2026-11-16T1300Z-co46-noble-sru-review-reviewer-7-verbatim.md (112 lines). Pasted, "Received 2026-11-16 ~13:00 UTC, relayed by the operator ... Kept as received" (:3-6). Tool residue ":10 Worked for 3m 1s"; :14 "I reviewed the supplied package ... I did not independently rebuild the Ubuntu packages or reproduce the reported timings." No lines about sessions/hooks/identities found by grep (words session, worker, agent, hook, identity, branch only as technical content: :38 "Upstream PR #30209", :103 "packaging-branch MP").
3. reviews/2026-11-16T0000Z-project-review-recheck-checks.md (81 lines). Not a pasted message (maintainer's own checks). Lines about arrangement: :4 "The recheck itself (`3f8e8f62`, two files) is on a separate branch, like the review (`162d3b9`)"; :11 "operator: waits for the operator's decision"; :64 "The working arrangement in the text, and a scan pattern (P-01 to P-03, S-11, N-01) | operator | Asked again"; :66 "Where the review files live | operator".
4. reviews/README.md: new sections are an index and dated notes; no arrangement text.
No new comms/ files; earlier pasted-transcript comms/2026-11-15T2010Z-from-test-suite-maintainer-relayed-by-operator.md (header ":2-4 Received ... pasted by the operator. Kept as received") is unchanged.

## New defects introduced by this round
1. reviews/2026-11-16T1300Z-co46-noble-sru-review-reviewer-7-verbatim.md:5-6 promises `2026-11-16T1300Z-co46-noble-sru-review-checks.md`; that file is not on the checkout of main (ls reviews | grep co46 -> only the verbatim). Also the verbatim and the new checks file are not in the "Files not listed" index.
2. reviews/README.md R2-64/65 cell cites `tools/bt-trial:465-466` (wrong; :490).
3. BRIEF.md:228-231 cites `8b71499`/`a56141e` as "ports on `main`"; in the checkout of main they are reachable only from the deleted branches' tracking refs, not from HEAD (shallow, needs-check).
4. BRIEF.md:145 "merges `main` into it" vs the 11-13 comms "rebased" and the 11-15T2010Z plan.
5. README.md:299 "By the convention in reviews/README.md" - that file has no branch convention.
6. No new "…" identifier in the new BRIEF/README text; the old truncated hash at BRIEF.md:825 remains (listed open by the maintainer).

---

# Part: co-02

## co-02 recheck2 against the checkout of main bbec102f (D = contributions/CO-02-sco-connect-reuses-closing-link)

### Second v2 package unreferenced / which package is current (was PARTLY)
- verdict: PARTLY
- now: agree: contributions/README.md:47 (table) "1/2 + the **non-sleeping** 2/2: .../review-fixes-20261115/patches/alt-2of2/"; README.md:159-161 "the first v2 candidate ... is not to be sent; the candidate is a non-sleeping 2/2"; BRIEF.md:191; docs/STATUS.md:9-14 (top block); D/README.md:1-14 (new note); D/log.md (2026-11-16 entry); contributions/README.md:87 (index row ends "the current candidate is the table's 'CO-02 v2' row"); D/send-v2-20261114/SUPERSEDED.md now names alt-2of2 and cover-alt; D/review-fixes-20261115/patches/main-v2/SUPERSEDED.md added; rd-2026-11-14.md "Corrections of 2026-11-16". Still disagreeing: (a) the cover: table row 47 says "the cover ... is msg/cover-alt.txt (rewritten 2026-11-16)", but README.md:161 "with its checks and cover still to do" and BRIEF.md:191 "Checkpatch, the bot's CI and a cover are still to do"; (b) the STATUS CO-02 submission row (docs/STATUS.md:52) has no entry after the 11-13 note (no v2 built, no deadlock), and the dossier note calls "STATUS (its top block and row U7)" the current record, but row U7 (docs/STATUS.md:108) ends "Sent 2026-10-27 (the CO-02 submission row above)" with nothing on v2; (c) BRIEF.md:93 still has the 11-02 v2 description ("possibly the mismatch patch").
- what is left: say "cover rewritten, checkpatch/CI still to do" in README.md:161 and BRIEF.md:191; add a one-line 11-15/16 entry to STATUS.md:52.

### Dossier README, log.md lack 11-14/15 state (was NOT ADDRESSED)
- verdict: FIXED
- now: D/README.md:1-15 "**Note of 2026-11-16 (newer than the banner below ...):** ... **v2 is not sent.** ... The candidate is patch 1 plus the non-sleeping 2/2"; D/log.md "## 2026-11-16 — the entries after 11-02 (added from the records; nothing new was run)". The old 11-12 banner is kept below, labelled older.
- what is left: nothing.

### Root README.md CO-02 text (was NOT ADDRESSED)
- verdict: PARTLY
- now: README.md:155-161 now mentions the deadlock, the non-sleeping 2/2 and "its rule makes v2 also a resend"; but :161 "with its checks and cover still to do" (cover now written, see above).
- what is left: the cover wording.

### Missing raw logs / stale SHA256SUMS (was NOT ADDRESSED)
- verdict: PARTLY
- now: new dir fixed: D/review-fixes-20261115/SHA256SUMS (44 lines, `sha256sum -c`: 44 OK, 44 files besides it; none missing). Old dir unchanged: D/send-v2-20261114: 30 listed files missing, CHECKS.md and NOTES-FOR-OPERATOR.md FAILED (checked again). The directory is superseded.
- what is left: nothing required for a superseded dir. (New README says raw guest logs are not in the dir: stated, README "Note of 2026-11-16".)

### NOTES-FOR-OPERATOR "task brief"; BRIEF D1/D2 gloss (was NOT ADDRESSED)
- verdict: NOT ADDRESSED
- now: D/send-v2-20261114/NOTES-FOR-OPERATOR.md:14 "**Label mix-up in the task brief:**"; BRIEF.md:242 "D1/D2 (CO-02 v2: -EBUSY on a live link, -ECONNABORTED only when nothing holds it)" (followups.md D1 = when/label).
- what is left: reword BRIEF.md:242.

### "…" elision (was NOT ADDRESSED)
- verdict: PARTLY
- now: fixed: README.md:163 and docs/STATUS.md:13 now full paths (`contributions/CO-02-sco-connect-reuses-closing-link/`), issues.md no longer elided. Remaining: D/log.md:452 "cold boot `257d1599…`", :761 "`148564f5…c94f3d`", D/send-v2-20261114/CHECKS.md:25 "`…/bluetooth.git`", contributions/rd-2026-11-14.md:113 "`CO-02-…/send-v2-20261114/`" (the new corrections block above it uses full paths), contributions/README.md CO-30 row "CO-30-…/rfc-20261114/" (row 115).
- what is left: boot id / hash / URL / two paths.

### Dossier README:10 relative link (was NOT ADDRESSED)
- verdict: FIXED
- now: D/README.md:14-15 "`reviews/2026-11-12T1508Z-…` is at the project's top level: `../../reviews/2026-11-12T1508Z-upstream-contributions-status.md`" (the banner's own relative path at :24 stays, now explained).
- what is left: nothing.

### EX-067..074 vs EX-073; run windows (was NOT ADDRESSED, cosmetic)
- verdict: NOT ADDRESSED
- now: D/log.md:451 "exhibits `EX-067` to `EX-073`" (unchanged).
- what is left: nothing essential.

### New defect 1 (cover-alt.txt a three-patch cover) — Maintainer item 2
- verdict: FIXED
- now: D/review-fixes-20261115/msg/cover-alt.txt is two-patch: "Patch 1 ... Patch 2 refuses ... without waiting for it"; no patch 3 in testing or changelog ("v1 patches 2 and 3 are one patch ... does not sleep: it refuses a connection whose disconnect worker is running instead of waiting"). Counts: alt-2of2 has 2 patches, "[PATCH v2 1/2]", "[PATCH v2 2/2]" ✓. Quoted numbers vs the directory: "35 posted cases: base 31 pass; patches 1 and 2: 33 pass, 2 fail (3 runs)" - README.md:60-62 records "44 cases (35 posted, 9 research): 35 pass, 2 fail, 7 not run, in each of 3 runs"; "33 of 35 posted" is the maintainer's derivation (35 pass minus 2 research passes), not a recorded figure; base 31 comes from send-v2-20261114/CHECKS.md, not this directory. mgmt 526 / iso 213 ✓ (README.md:62). Race cases "2 of 2 on alternative, 1 of 2 on base" ✓ (README.md:63). "l2cap not run", "not run on the laptop" - stated. Stable text "6.18.y and 7.3.y", "patch 2 depends on patch 1" ✓ matches patch 2 ("must not be backported without it"). Checksums: SHA256SUMS 44/44 OK.
- what is left: the "33 of 35" derivation is not written in README section 2 (only the 44-case total); raw logs absent.

### New defect 2 (alt patch 2 carries stable trailer while README says operator's call)
- verdict: NOT ADDRESSED (operator item, acknowledged)
- now: patches/alt-2of2/v2-0002...:"Cc: stable@vger.kernel.org # see patch description, needs "Bluetooth: hci_conn: hold ...""; table row 47 "operator: the stable trailer form".
- what is left: operator's decision.

### New defect 3 ("CO-02-…" elision in STATUS.md:13)
- verdict: FIXED
- now: docs/STATUS.md:13 "`contributions/CO-02-sco-connect-reuses-closing-link/review-fixes-20261115/`".

### Maintainer item 3 (markers): "SUPERSEDED.md ... CO-02 patches/main-v2/; send-v2-20261114/SUPERSEDED.md names alt-2of2/"
- verdict: CLAIM CONFIRMED
- now: D/review-fixes-20261115/patches/main-v2/SUPERSEDED.md "# Not to be sent: this 2/2 can deadlock"; D/send-v2-20261114/SUPERSEDED.md "...`../review-fixes-20261115/patches/alt-2of2/`". Third marker D/send-v2-review-fixes-20261114/SUPERSEDED.md also present. Row 87 of contributions/README.md carries the dated pointer. Item 14 ("CO-02 bullet follows the send table"): CLAIM PARTLY REFUTED because of the "cover still to do" line (README.md:161).

### Maintainer item 2 "Checksums made"
- verdict: CLAIM CONFIRMED (44/44, see above). "quotes only numbers recorded for that candidate": CLAIM PARTLY CONFIRMED (the 33 of 35 and the 31 base are derived/from another directory).

## New defects introduced by this round
1. README.md:161 and BRIEF.md:191 still say the cover is to do, while contributions/README.md:47 and D/review-fixes-20261115/README.md (last section) say it was rewritten 2026-11-16 (Low-Medium; contradiction).
2. alt-2of2 patch 2 message has an over-long line (">75 chars": "unregistered. work_busy() only reads the work's state. Once the hold is taken nothing can queue", about 96 chars) from a hand edit, and neither alt patch has a "Notes: v2: ..." block (the 11-14 versions had them); the changelog exists only in the cover. checkpatch is still to do per the README (Low).
3. The new cover drops the v1 laptop result altogether ("These patches were not run on the laptop"); true for the changed 2/2, deliberate per README, but v1's patch 1 (identical code in alt 1/2) did run there 3 of 3 (EX-075..077); disclosure choice for the operator (Low).
