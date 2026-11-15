# Detailed recheck behind the reaction report of 2026-11-15

Each worker reviewer's recheck of its own findings against `main` at `a8d0eb45`, as written.
The main page is [`review-reaction-to-comprehensive-project-review-20261115-204454.md`](review-reaction-to-comprehensive-project-review-20261115-204454.md).

---

# Part: code-bin-install

## Recheck: code-bin-install (main tip a8d0eb45)
Changed on main in my part: install.sh, uninstall.sh only (plus README.md, BRIEF.md, docs/tooling-index.md in passing). bin/, systemd/, etc/, tools/bt-mode, bt-verify-install, verify-restored.sh, docs/install.md, restore-original-state.md, changes-applied.md are UNCHANGED.

### uninstall.sh reloads btusb with no guard
- original severity: High
- verdict: PARTLY
- now: FIXED in code: uninstall.sh:285-294 "The module is NEVER unloaded or reloaded here ... the restored default simply applies the next time btusb loads"; line 293 "btusb is loaded (usecount=...) and is left loaded". REMAINING doc: docs/restore-original-state.md:84 still "`enable_autosuspend` only flips back if `btusb` can be reloaded. If the module is in use the script says so"; docs/changes-applied.md manual rollback (`modprobe -r btusb && modprobe btusb`, ~:195) unchanged.
- what is left to do: update restore-original-state.md:84-85 to "applies at next boot; never reloaded".

### bt-raw-archive.service hard-codes the operator's checkout path
- original severity: Medium
- verdict: PARTLY
- now: install.sh:539-553 installs and enables the unit only when `$RAWEXEC == "$SRC/scripts/raw-capture-archive-all.sh"`, else prints "not installed"; enable guarded by `(( RAWARCHIVE )) && run systemctl enable --now bt-raw-archive.timer`. systemd/bt-raw-archive.service:15 still `ExecStart=/root/exp/qca9377-bt-hang/scripts/...`. docs/tooling-index.md:86 still says "installed by `install.sh`" with no condition.
- what is left to do: say in tooling-index (and install.md) that it is installed only from /root/exp; see new defect below for verifiers.

### bt-journal-files tool and units installed/removed by nothing
- original severity: Medium
- verdict: NOT ADDRESSED
- now: `grep journal-files install.sh uninstall.sh` empty in main; docs/tooling-index.md:78 unchanged.
- what is left to do: add to install/uninstall or reword the doc.

### Non-default device: event snapshot unit gets no drop-in
- original severity: Medium
- verdict: NOT ADDRESSED
- now: install.sh:388 `SNAP_DROPIN=.../bt-health-snapshot.service.d/10-device.conf` only; no `bt-health-snapshot-event.service.d`.
- what is left to do: write the same drop-in for the -event unit (and list it in uninstall/verify-restored).

### bt-usbmon capture dir/files not root-only
- original severity: Medium (needs-check)
- verdict: NOT ADDRESSED
- now: grep umask/UMask/chmod in bin/bt-usbmon and systemd/bt-usbmon.service: no match. (Still needs the on-machine stat to settle.)
- what is left to do: umask 077 + chmod 0700 like bt-trace, or UMask=0077 in the unit.

### modprobe dyndbg vs bt-dyndbg / experiment mode
- original severity: Medium
- verdict: NOT ADDRESSED
- now: etc/modprobe.d/btusb-qca9377.conf:33,41 unchanged (`options btusb dyndbg=+p`), comment :31 "bt-dyndbg.service stays, because it still covers the case where btusb is reloaded by hand"; tools/bt-mode unchanged.
- what is left to do: correct the comment / reconcile with bt-mode header.

### --tools-only writes the first-install stamp
- original severity: Low
- verdict: NOT ADDRESSED
- now: install.sh stamp block unchanged (no TOOLS_ONLY test).
- what is left to do: skip the stamp under --tools-only or document it.

### "every file installed is NEW" does not cover generated files
- original severity: Low
- verdict: NOT ADDRESSED
- now: install.sh:385-440 and the 51 rule block still written by redirect without .pre- backup.
- what is left to do: back them up too, or qualify the claim.

### Doc says "two", install.sh says "three" demonstrations
- original severity: Medium
- verdict: PARTLY
- now: install.sh:11 and :36-38 now say "two ... (a third case ... EX-026 ... did not issue)", matching README.md:296, docs/install.md:6,26,45, docs/issues.md:467. Still "three": docs/tooling-index.md:233, docs/fix-proposal.md:9, docs/investigation-plan.md:55.
- what is left to do: align the three remaining places (or reword as "two + one external").

### docs/install.md stale references
- original severity: Medium
- verdict: NOT ADDRESSED
- now: docs/install.md:79 "`./install.sh --apply` (printed by `bt-verify-install` on any drift)" (bt-verify-install:167-170 no longer prints it); :85 "E3 untouched: ... D1DEA96A0C95BFAB05CEE01"; "What it installs" still 3 items.
- what is left to do: fix the three points.

### changes-applied.md "Manual - the complete set" day-one only
- original severity: Medium
- verdict: NOT ADDRESSED
- now: docs/changes-applied.md:166 heading unchanged.
- what is left to do: retitle or extend.

### restore-original-state.md contradicts current uninstall
- original severity: Low
- verdict: NOT ADDRESSED
- now: docs/restore-original-state.md:46 "restoration is *deletion of added files*, not restoration from backup" unchanged; §3 still lists only metrics.tsv.
- what is left to do: mention .pre-qca9377-bt-hang / .disabled and the other leftover data.

### bt-evidence sends HCI command in snapshot_state
- original severity: Medium
- verdict: NOT ADDRESSED
- now: bin/bt-evidence:70 `timeout 6 hciconfig "$hci" name ...` unchanged.
- what is left to do: make it opt-in like bt-mark --probe.

### bt-verify-install reports success with artefacts missing in repo
- original severity: Low
- verdict: NOT ADDRESSED
- now: tools/bt-verify-install:74 `printf ... missing in repo ...; continue` still uncounted.
- what is left to do: count as drift.

### install.sh -h cut / tools-only banner text
- original severity: Low
- verdict: NOT ADDRESSED
- now: install.sh:53 now `sed -n '2,16p'`, but the header grew by one line, so it still ends at "# Different controller:" (line 16) and the example is line 17; preflight "the watchdog arms itself at boot" and final Verify block unchanged.
- what is left to do: `2,18p` and conditional final text.

### BRIEF "all 3 skip now" dates
- original severity: Low
- verdict: NOT ADDRESSED
- now: BRIEF.md:418-422 "Until 2026-09-16 --tools-only reinstalled the two files ... all 3 skip now" unchanged; install.sh dates unchanged.
- what is left to do: lead's call.

### Minor: 20-verbose.conf, BT_USBMON_BUS, 88 GB
- original severity: Low
- verdict: NOT ADDRESSED
- now: uninstall.sh:104 still lists 20-verbose.conf; systemd/bt-usbmon.service:18 `BT_USBMON_BUS=3`; journald conf:9 "88 GB free".
- what is left to do: nothing urgent.

## New defects introduced by the changes
- bt-raw-archive now conditionally installed, but tools/bt-verify-install (install_file pairs and `systemctl enable --now` grep) and tools/verify-restored.sh (same derivation) and uninstall.sh were not told: on any checkout other than /root/exp, bt-verify-install will report bt-raw-archive.service/.timer "NOT INSTALLED" and the timer as drift ✗, and its advice (--tools-only) cannot fix it. Low-Medium.
- install.sh `-h` change `2,16p` does not fix the truncation (see above); it only compensates for the added line.
- docs/restore-original-state.md:84 now describes the removed reload behaviour (stale after eacbb61f).

---

# Part: code-tools-a

## Recheck of code-tools-a against main a8d0eb45 (files changed in my part: bt-archive, bt-exhibit, bt-trial, lib/trial-summary.awk, lib/trial-sco-table.awk; BRIEF.md)

### bt-backup-journal re-archives a PREFIX with --replace and can replace a larger archive by a smaller one
- original severity: High
- verdict: PARTLY
- now: fixed for the same-extension case: tools/bt-archive:362-383 counts every existing archive of the boot and refuses/keeps the new export as `shorter-boot-<id>...` if SRC_N < OLD_N. Remaining: the guard is `if [[ -e "$OUT" ]]` (362); when the new archive has a different extension from the old (e.g. new .gz, old .zst) OUT does not exist, the guard is skipped, and the sweep at bt-archive:408 `rm -f "$stale"` still deletes the old, possibly longer archive. tools/bt-backup-journal:152 `(( prefixed )) && REPL=(--replace)` unchanged; the header comment (bt-archive "the refusal above is what stops...") unchanged.
- what is left to do: run the record-count comparison before the sweep irrespective of `-e "$OUT"` (compare against every `boot-<id>.export.*`).

### bt-trial `start` (manual) reuses an existing trial directory
- original severity: Medium
- verdict: FIXED
- now: tools/bt-trial:370-374 `if [[ -e "$dir" ]]; then aside=$(set_aside "$dir") ...` with set_aside (290) using free name and `mv -T`; autostart uses it too (433).
- what is left to do: nothing

### BRIEF.md description of bt-trial differs from main's code in three places
- original severity: Medium
- verdict: NOT ADDRESSED
- now: BRIEF.md:863-864 "opens a new trial with the same number in the same directory, overwriting `state-before.txt` and `steps.log`" (code: directory set aside, bt-trial:433); BRIEF.md:815 "`bt-trial` labels them `build=stock`" (still unqualified: autostart relabels on a btusb version suffix, bt-trial module_build). Other points (no bluetoothd record, 684; tmpfs) were correct.
- what is left to do: correct 863-864 (number reused, directory set aside as `.unclosed-<stamp>`) and qualify 815 (true for bluetooth.ko / suffixless btusb only).

### Close paths that send an HCI command
- original severity: Medium
- verdict: NOT ADDRESSED
- now: unchanged in tools/bt-trial (hci_alive in ok/hang/start; header line 8 still says `ok` verifies, no mention that `hang` probes).
- what is left to do: say in the header that manual `ok` and `hang` probe (or make `hang` passive).

### hci_alive's "cannot tell" status (rc 2) is read as dead
- original severity: Medium
- verdict: NOT ADDRESSED
- now: tools/bt-trial still `elif hci_alive; then resp_after=yes; else resp_after=no` and `! hci_alive` -> failed (diff touched none of it).
- what is left to do: treat rc 2 as unprobed/unknown.

### Failed trial with bt1_status=not_observed counts as a survival in both reports
- original severity: Medium
- verdict: FIXED
- now: tools/lib/trial-summary.awk:121 `if (bs == "not_observed" && tr == "failed") { fnx[k]++; seen[k]++; next }` with a warning block; tools/lib/trial-sco-table.awk:94 `failedunx++; next` with counter line and adjusted "bottom row empty" text.
- what is left to do: nothing (the writer still produces failed+not_observed rows, now visibly excluded)

### bt-trial: header/usage text stale or truncated
- original severity: Low
- verdict: NOT ADDRESSED
- now: tools/bt-trial:9 "discard the open trial"; 1269 `sed -n '2,18p'`; 385 `protocol | sed -n '3,10p'` (line numbers shifted, text unchanged).
- what is left to do: fix header line 9, usage range, banner range.

### bt-trial header comment claims bt-state sends raw HCI
- original severity: Low
- verdict: NOT ADDRESSED
- now: tools/bt-trial:901 "* every bt-state invocation, which does the same"
- what is left to do: delete the bt-state bullet.

### bt-snapshot header says autostop issues HCI at every shutdown (stale)
- original severity: Low
- verdict: NOT ADDRESSED
- now: tools/bt-snapshot:24 "cautionary example — its hci_alive() issues an HCI Read_Local_Name at every shutdown"
- what is left to do: reword as historical (passive since 2026-09-19).

### bt-trial-audit claims independence from bt-trial's detectors; the patterns are identical
- original severity: Low
- verdict: NOT ADDRESSED (file unchanged on main)
- what is left to do: drop the claim or source the patterns from one place.

### bt-trial-audit: unreadable journal for a window reads as "agrees"
- original severity: Medium
- verdict: NOT ADDRESSED (tools/bt-trial-audit and lib/journal.sh unchanged)
- what is left to do: check the read status / "No journal files" in the audit window read.

### lib/journal.sh fast path discards per-file reader failures
- original severity: Medium
- verdict: NOT ADDRESSED (lib/journal.sh unchanged)
- what is left to do: collect each per-file exit status, return non-zero on failure.

### bt-trial close: unbudgeted journalctl reads before the row
- original severity: Medium
- verdict: NOT ADDRESSED (-u, -b -1 and --list-boots reads unchanged; still needs-check on cost)
- what is left to do: put them under the scan budget or after the row.

### bt-trial: probes/aborts/t_probe/prev_shutdown reads ignore failures
- original severity: Low
- verdict: NOT ADDRESSED
- what is left to do: record `?` when journal_files=0 or the read fails.

### bt-trial journal seam: bt-trial calls journalctl directly
- original severity: Low
- verdict: NOT ADDRESSED (observation; unchanged by design)
- what is left to do: nothing required; optionally document the -u reads as exempt.

### bt-archive --replace / sweep can delete a more complete archive; --replace undocumented in usage
- original severity: Medium
- verdict: PARTLY
- now: count guard added (bt-archive:353-383, for same-extension OUT only; see first finding). Sweep still at bt-archive:408. Usage `sed -n '2,8p'` still omits `--replace`.
- what is left to do: as in the first finding, plus list --replace in usage.

### bt-snapshot hardcodes USB path 3-3
- original severity: Low
- verdict: NOT ADDRESSED (file unchanged)
- what is left to do: resolve by VID/PID.

### bt-snapshot writes raw unsanitised cuts under /var/tmp
- original severity: Low
- verdict: NOT ADDRESSED (unchanged; still needs-check)
- what is left to do: decide/document retention.

### bt-exhibit new: option without value loops forever
- original severity: Medium
- verdict: FIXED
- now: tools/bt-exhibit:69-72 `shift 2 || { echo "${0##*/}: $1 needs a value" >&2; exit 2; }`
- what is left to do: nothing

### bt-exhibit help is cut off mid-example
- original severity: Low
- verdict: NOT ADDRESSED (`sed -n '2,30p'` unchanged)
- what is left to do: extend range to 33.

### bt-retention end-of-run text contradicts header on capture time
- original severity: Low
- verdict: NOT ADDRESSED (file unchanged)
- what is left to do: reword the closing note.

### lib/evidence-window.sh: "written once" prefix duplicated
- original severity: Low
- verdict: NOT ADDRESSED (file unchanged)
- what is left to do: use $BT_EW_PREFIX in bt_ew_read.

### bt-backup-journal: --status/--dry-run print "re-archiving in full"; "Read-only" claim
- original severity: Low
- verdict: NOT ADDRESSED (file unchanged)
- what is left to do: print the PREFIX line only when actually archiving.

### bt-trial abort --discard deletes untracked trial evidence
- original severity: Low
- verdict: NOT ADDRESSED (unchanged, documented opt-in)
- what is left to do: decide whether to keep given the never-delete rule.

### bt-journal-files has no repository guard
- original severity: Low
- verdict: NOT ADDRESSED (file unchanged)
- what is left to do: add the inside-repo refusal.

## New defects introduced by the changes
- tools/bt-archive:362-383: the new guard covers only `-e "$OUT"` (see first finding); a different-extension replacement bypasses it. Also an old archive that is corrupt (decompresses with errors) counts as 0 records via `grep -c ... || true`, so it is replaceable; an old archive with no decompressor correctly blocks (on=-1).
- tools/bt-archive:380-381: on refusal the new export is kept as `shorter-boot-<id>.export.<ext>` in DEST; `--list` globs only `boot-*.export.*`, so these are invisible to --list/--check/--repair and not mentioned except in the refusal text. Low.
- tools/lib/trial-summary.awk:121 and trial-sco-table.awk:94: a manual `bt-trial hang` with no logged timeout is now excluded from every rate and not counted as failure in the numerator; the warning text attributes it to "E3 #3 and #4 ... STATUS 2026-11-07" (project-specific, dated, in a generic tool). Low. trial-sco-table.awk:94 resolves `trial_result` optionally while trial-summary requires it; consistent enough.
- tools/bt-trial set_aside (290-299): no problem found; `mv -T` and free-name loop correct. bt-exhibit fix: no new problem found. No elided "…" paths or references to missing files in the diffs.

---

# Part: code-tools-b

### bt-sco --window loops forever; same trap in 5 more tools
- original severity: High
- verdict: FIXED
- now: tools/bt-sco:48 `--dir) ... shift 2 || { echo "${0##*/}: $1 needs a value" >&2; exit 2; }`, :52 `--window) WINDOW=2; if [[ "${2:-}" =~ ^[0-9]+$ ]]; then WINDOW="$2"; shift; fi; shift ;;` (bare --window ok); bt-actions:70-72, bt-capdiff:62-64, bt-context:43-44, bt-logvolume:46-48, bt-phase:69-70 all `shift 2 || ... exit 2`
- what is left to do: nothing

### bt-sco usage text omits --window and -h cuts off the Usage block
- original severity: Medium
- verdict: FIXED
- now: tools/bt-sco:28 `bt-sco [--dir <trace-dir>] [--raw] [--window [<seconds>]]`, :53 `sed -n '2,33p'` (covers the Usage block)
- what is left to do: nothing

### bt-window header says bt-status/bt-state run hciconfig name
- original severity: Medium
- verdict: FIXED
- now: tools/bt-window:9-12 "`bt-status --probe` and `bt-state --probe` run `hciconfig <dev> name` ... Without --probe both are passive (since 2026-09-18)"
- what is left to do: nothing

### Probe contract verified (note)
- original severity: Low
- verdict: NOT ADDRESSED (nothing to address; still holds)
- now: tools/bt-state:78 still `timeout 8 bluetoothctl devices Connected`; hciconfig/btmgmt still only under --probe
- what is left to do: nothing (optional one-line caveat)

### bt-diagnose exits 0 "NOT observed" when zero boots could be examined
- original severity: Medium
- verdict: FIXED
- now: tools/bt-diagnose:51-55 `if (( boots == 0 )); then ... "Cannot determine: no retained boot's kernel journal could be read." ... return 2`; :185-186 verdict_rc propagated
- what is left to do: nothing

### README "every tool takes BT_VID/BT_PID" overbroad
- original severity: Medium
- verdict: NOT ADDRESSED
- now: README.md:133-134 "work on any USB controller; every tool takes `BT_VID`/`BT_PID`" unchanged (README edited elsewhere); tools/bt-diagnose still has no BT_VID; tools/bt-status verdict still uses `${BT_VID:-13d3}` default
- what is left to do: reword to "the device-specific tools" and make bt-diagnose/bt-status honour or autodetect

### "Standalone, no installation": bt-incident timeline from PATH
- original severity: Low
- verdict: NOT ADDRESSED
- now: tools/bt-incident:103 `command -v bt-timeline >/dev/null 2>&1 && bt-timeline "$SINCE" --raw > ... || true` (PATH only, silent skip)
- what is left to do: resolve sibling next to the script like bt-state/bt-usbstate, or print a notice

### sanitize-logs.sh: IPv6 / other forms not covered
- original severity: Low
- verdict: NOT ADDRESSED
- now: tools/sanitize-logs.sh unchanged on main (no diff); no IPv6 pattern
- what is left to do: add IPv6 (fe80:: EUI-64) pattern and verification, or state the limit in README

### Index lists git-ignored paths as if tracked
- original severity: Medium
- verdict: NOT ADDRESSED
- now: docs/tooling-index.md:86 still names `tmp/raw-archive-timer/install-timer.sh`; cache/ and tmp/ entries at :126-134,151 unchanged
- what is left to do: mark ignored paths as local-only or drop them

### Executables missing from the tooling index
- original severity: Medium
- verdict: NOT ADDRESSED
- now: same 15 still absent (devtools/access-classify, devtools/assert-test-catches, scripts/dbg-autostop-calls.sh, exhibit-relabel-boot-id.py, export-kernel-review.sh, patch-id-compare.sh, prove-ci-cwd.sh, prove-ci-stub.sh, prove-dr-followup.sh, prove-dr-review.sh, prove-neg-search.sh, r2-checks-2.sh, r2-checks.sh, suite-timing.sh, uncovered-code-report.py). New tools/bt-archive is indexed.
- what is left to do: add them or state the index is not exhaustive

### tools/test-runner is a path in the BlueZ checkout
- original severity: Low
- verdict: NOT ADDRESSED
- now: docs/tooling-index.md:132 still "`tools/test-runner` in QEMU"
- what is left to do: say "BlueZ's tools/test-runner"

### bt-incident --help prints a truncated header
- original severity: Low
- verdict: NOT ADDRESSED
- now: tools/bt-incident:26,36 `sed -n '2,12p' "$0"`
- what is left to do: extend to 2,13

## New defects introduced by the changes
- Low: tools/bt-ui-capture:828 `-h|--help|help) sed -n '2,80p' "$0"` now also prints the code lines 77-79 (a blank, `set -uo pipefail`) after the header; cosmetic.
- Low: light mode's AT-SPI recorder registers events with the AT-SPI registry (`--register-shell-events`, tools/bt-ui-capture ~:386-392; docs/ui-capture.md:~105 "the one non-passive step"), while the tool header's `start` text still speaks of "passive monitors" and the index row (tooling-index.md ~:106) says "Three units ... only" without flagging it in that row; the doc and the code are honest, the tool header does not mention it for start-light (lines 39-48).
- Low: start_light_main: if light_any_active is true but light_current fails, a new directory is made while running units keep writing to the old one (tools/bt-ui-capture start_light_main). Edge case, needs-check.
- All new index references exist on main (scripts/send-table-check.py, tests/fixtures/ui-atspi-shell-filter.tsv, scripts/bt-ui-atspi.py with --comm/--register-shell-events/--check-filter, docs/ui-capture.md "Always-on light mode"). Index "20 MiB x 5 per file" matches code (20971520 x (4+1)). No elided paths in new text apart from the index row quoting `…` as the thing the new check looks for.

---

# Part: code-scripts-a

## Recheck of code-scripts-a against main a8d0eb45

Method: every script of my range was compared byte for byte with the old tree. Only these differ on main: bluez-release-contains.sh, bluez-tester-compare.sh, bt-ui-atspi.py, ci-local-publish.sh, ci-local.sh (plus runtime-mgmt-test.sh, sco-ledger*.sh, smtp-login-check.sh, prove-ui-capture.sh, send-table-check.py, which are outside my range). scripts/README.md is unchanged. All other findings are therefore NOT ADDRESSED; line numbers below are the current ones in main.

CORRECTION to my first report: in the first findings file, line numbers for the second and later files of each multi-file `cat -n` listing were cumulative (e.g. compile-mgmt-at.sh:165 is really compile-mgmt-at.sh:29; ci-local-controls.sh/ci-run-images.sh/bt17-provoke.py etc. likewise). The quoted text is right; use the line numbers given here.

### build-btusb-stable-matrix.sh: -Werror fallback lost in a subshell
- original severity: Medium
- verdict: NOT ADDRESSED
- now: build-btusb-stable-matrix.sh:60 `werror=""` inside build(), called at :67 `un=$(build unpatched)`
- what is left to do: set werror outside the command substitution (e.g. build writes its result to a variable/file).

### build-btusb-stable-matrix.sh: pass condition hard-wired to 13d3:3503
- original severity: Medium
- verdict: NOT ADDRESSED
- now: build-btusb-stable-matrix.sh:74 `grep -c "0x13d3, 0x3503"`, :76 `"$entry" == 1 ]] || rc=1`
- what is left to do: make the entry check optional/parameterised or document it in the exit contract.

### build-btusb-stable-matrix.sh: default branch list is a dated snapshot
- original severity: Low
- verdict: NOT ADDRESSED
- now: build-btusb-stable-matrix.sh:11 "the lines live on kernel.org on 2026-10-02", :22 list starts at stable/linux-7.2.y
- what is left to do: add 7.3.y or derive the list.

### build-bluetooth-fulltree.sh: failed patch not detected
- original severity: Medium
- verdict: NOT ADDRESSED
- now: build-bluetooth-fulltree.sh:46 `patch -p1 < "$PATCH" | grep -E "Hunk|FAILED"`
- what is left to do: check patch's status (`patch ... || exit 1`).

### build-btusb-module.sh: exit 0 with no btusb.ko
- original severity: Low
- verdict: NOT ADDRESSED
- now: build-btusb-module.sh:55 `[[ -f "$KO" ]] || exit "${rc:-1}"`
- what is left to do: exit non-zero when the .ko is missing.

### build-bluetooth-module.sh: --ubuntu undocumented, hard-codes a retired tree
- original severity: Low
- verdict: NOT ADDRESSED
- now: build-bluetooth-module.sh:28 `SRC="$HERE/cache/ubuntu-7.0.0-31"`
- what is left to do: document or drop the option.

### bt17-arm-usb-debug.sh: --off reports success without checking; hard-coded bus
- original severity: Low
- verdict: NOT ADDRESSED
- now: bt17-arm-usb-debug.sh:29-30 `pkill ... && echo ...`, `echo "USB core debug off"`
- what is left to do: check the debugfs writes.

### bluez-tester-compare.sh: no Test Summary reads as "no case passes ... fails", exit 0
- original severity: Medium
- verdict: FIXED
- now: bluez-tester-compare.sh:148 `NO VERDICTS from the ... side ... NOT compared` then exit 2; :180 `RESULT: incomplete — ...`; header :28-29 documents exit 2.
- what is left to do: nothing. (Residual: a case missing on the patched side is still only tagged "(case removed)", not counted.)

### bluez-tester-compare.sh: --help prints code lines; exit 2 undocumented
- original severity: Low
- verdict: PARTLY
- now: exit 2 is now documented (:28-29); `-h|--help) sed -n '2,30p'` at :54 still runs one line past the header (prints `set -uo pipefail`, line 30).
- what is left to do: change 30 to 29.

### bluez-release-contains.sh: bad tag reported as "NOT in"; exit always 0
- original severity: Medium
- verdict: FIXED
- now: bluez-release-contains.sh:6-7 `${1:?usage...}`, rev-parse check exits 2 ("nothing was checked"), case on rc 0/1/other with `ERROR` and `exit "${err:-0}"`.
- what is left to do: nothing.

### backport-check.sh: `| head -1 || echo` fallback never fires
- original severity: Low
- verdict: NOT ADDRESSED
- now: backport-check.sh:27
- what is left to do: test for empty output instead.

### backport-check.sh: default stable list is a 2026-10-02 snapshot
- original severity: Low
- verdict: NOT ADDRESSED
- now: backport-check.sh:7, :20
- what is left to do: add 7.3.y.

### bluez-accepted-survey.py: page cache never refreshed
- original severity: Low
- verdict: NOT ADDRESSED
- now: bluez-accepted-survey.py:41 `if os.path.exists(path):`
- what is left to do: add a refresh switch or a note.

### archive-budget-check.py: empty root silent
- original severity: Low
- verdict: NOT ADDRESSED
- now: archive-budget-check.py:53 (missing dir) unchanged; loop prints nothing for a root without stores.
- what is left to do: print "no stores" when none found.

### btusb-has-device.py: errors exit 1 like ABSENT; xz/gz read as ABSENT
- original severity: Medium
- verdict: NOT ADDRESSED
- now: btusb-has-device.py:18 only `.zst`; :26 `sys.exit(0 if n else 1)`
- what is left to do: catch errors with a distinct exit code; handle other compressions.

### bt17-provoke.py: exit 0 on FAILURE; vanished device loops
- original severity: Medium
- verdict: NOT ADDRESSED
- now: bt17-provoke.py:143 `break` (main returns None), :127/:131 "(something keeps it awake); waiting"
- what is left to do: exit non-zero on failure; stop when the device is gone.

### bt17-provoke.py: "addresses never read or printed" vs full dmesg dump
- original severity: Low
- verdict: NOT ADDRESSED
- now: bt17-provoke.py:22 vs :138-139
- what is left to do: reword.

### bt-device-record.sh: unreadable store reported as "no stored device matches"
- original severity: Medium
- verdict: NOT ADDRESSED
- now: bt-device-record.sh:16 `[[ -r "$f" ]] || continue`, :23
- what is left to do: say "needs root" when the directory is unreadable.

### bt-trace-archive.py: /root path; digest set unused
- original severity: Low
- verdict: NOT ADDRESSED
- now: bt-trace-archive.py:20, :35 `/root/bt-trace-keep`; :127-132 identical branches
- what is left to do: mark local-only; compare digests.

### boot-bt-summary.sh: `|| echo "(none)"` covers journalctl failure
- original severity: Low
- verdict: NOT ADDRESSED
- now: boot-bt-summary.sh:20, :22
- what is left to do: distinguish exit 1 (no match) from other failures.

### build-v2.sh: header presents v2 as awaiting decision
- original severity: Medium
- verdict: NOT ADDRESSED
- now: build-v2.sh:16 "Prepared for the operator's decision (CB-02)"; BRIEF.md:735 "Operator's decision. **v2 is" (reviews/README.md:431 still says sent 2026-09-21).
- what is left to do: update the header and the BRIEF line.

### build-mails.sh: fixed to the September pair
- original severity: Low
- verdict: NOT ADDRESSED
- now: build-mails.sh:21 `for n in 0001 0002`
- what is left to do: mark as a record or generalise.

### ci-local-publish.sh: refused sanitiser leaves unsanitised file, exit 0
- original severity: Medium
- verdict: FIXED
- now: ci-local-publish.sh:78-83 `rm -f "$2"; ... not published ... return 1`, per-file failure counted, `exit 2` at the end; header :17-18 documents it.
- what is left to do: nothing.

### ci-local-controls.sh: banner names btdev.c:479
- original severity: Low
- verdict: NOT ADDRESSED
- now: ci-local-controls.sh:98 vs :101
- what is left to do: reword banner.

### ci-run-images.sh: no arg check, hard-coded repo, no failure signal
- original severity: Low
- verdict: NOT ADDRESSED
- now: ci-run-images.sh:6
- what is left to do: add usage and error exit.

### compile-mgmt-at.sh: apply check inverted
- original severity: High
- verdict: NOT ADDRESSED
- now: compile-mgmt-at.sh:29 `patch -p1 -d "$OUT" < "$PATCH" | grep -E "Hunk|FAILED" || { echo "patch did not apply" >&2; exit 1; }`
- what is left to do: check patch's own exit status (and reject .rej), not grep's.

### desktop-capture-archive.sh: default 3 GB rewrites the recorded budget
- original severity: Medium
- verdict: NOT ADDRESSED
- now: desktop-capture-archive.sh:10 "Budget: 3 GB by default", :20 `BUDGET="${BT_ARCHIVE_BUDGET_GB:-3}"`; bt-trace-archive.py:114 writes BUDGET_GB each run. BRIEF.md now says "archive budgets 20/25 GB" (commit 9cde439c) but the script default and header are unchanged.
- what is left to do: take the recorded budget as default or raise the default to the BRIEF values.

### commit-in-tree.py: traceback paths
- original severity: Low
- verdict: NOT ADDRESSED
- now: commit-in-tree.py:34 `out.check_returncode()`, :75 `verdicts[0]`
- what is left to do: handle both.

### discovery-stop-race.py: btmon exit status ignored
- original severity: Medium
- verdict: NOT ADDRESSED
- now: discovery-stop-race.py:59 `p.wait()` discarded
- what is left to do: check status (141 aside) and warn on a truncated decode.

### discovery-stop-race.py: docstring vs excluded outcomes
- original severity: Low
- verdict: NOT ADDRESSED
- now: discovery-stop-race.py:183 includes "off done first, stopped"; docstring :23-24 does not
- what is left to do: fix the docstring.

### device-adv-summary.py: usage names a different file
- original severity: Low
- verdict: NOT ADDRESSED
- now: device-adv-summary.py:7 `usage: adv-summary.py`
- what is left to do: rename in the usage line.

### export-kernel-review.sh: held branch / brief off main
- original severity: Medium
- verdict: NOT ADDRESSED
- now: export-kernel-review.sh:2-7 still "held kernel patch ... held branch ... The brief itself lives on the held branch, not here"; patches/kernel/REVIEW-TASK.md is on main; default branch `kernel/mgmt-flush-status` (:13) is not in the repo.
- what is left to do: rewrite for the post-acceptance state or retire the script.

### export-local-work.py: git failures swallowed
- original severity: Medium
- verdict: NOT ADDRESSED
- now: export-local-work.py:44 format-patch result unchecked
- what is left to do: check status, exit non-zero.

### ci-local.sh: exit 0 although checks did not run
- original severity: Medium
- verdict: PARTLY
- now fixed: ci-local.sh:768-770 `RESULT: no NEW finding in what ran; NOT RUN: ... — incomplete, exit 2` / `exit 2`; the header's "2 = could not run" now holds for everything in SKIPPED.
- remaining: NOT RUN paths that do not add to SKIPPED, so they still end "RESULT: no NEW finding", exit 0: ci-local.sh:586 (two_sided "git am failed unexpectedly"), :657 (functional "git am failed"), :743 (kernel "git am failed", `continue`). Functional configure/build/junit failures still write "configure failed"/"build failed"/"no junit result" findings (:659, :660, :669) that classify as PRE-EXISTING (none new).
- what is left to do: add `SKIPPED+=` at those three places; make functional failures NOT RUN.

### ci-local.sh: checkpatch that fails to run counts as PASS
- original severity: Medium
- verdict: FIXED
- now: ci-local.sh:453 `grep -q '^total:' "$out" || cp_notrun+=...` and a NOT RUN verdict with `SKIPPED+=(checkpatch)`.
- what is left to do: nothing.

### ci-local.sh: header names cache/action-ci
- original severity: Low
- verdict: NOT ADDRESSED
- now: ci-local.sh:19 "(cache/action-ci, see results/ci-local-2026-10-10.md §T1"
- what is left to do: name cache/action-ci-bluez.

### gitlint-check.sh vs ci-local.sh: which gitlint config the bot uses
- original severity: Medium
- verdict: NOT ADDRESSED
- now: gitlint-check.sh:3 "BlueZ's own .gitlint" vs ci-local.sh:22 "bot's own gitlint file, NOT BlueZ's .gitlint"
- what is left to do: correct gitlint-check.sh's header (or use the bot's config).

### get-maintainers.sh: relative patch path breaks after cd
- original severity: Medium
- verdict: NOT ADDRESSED
- now: get-maintainers.sh:8-10 `cd "$TREE"` before `"$PATCH"`
- what is left to do: `PATCH=$(readlink -f ...)` before the cd.

### functional-repeat.sh: skipped = 0 failures; always exit 0
- original severity: Low
- verdict: NOT ADDRESSED
- now: functional-repeat.sh:116 (SKIP printed, not counted), :132 `exit 0`
- what is left to do: count skips; non-zero exit on NO-RESULT.

### hci-key-records.py: datalink unchecked, local time
- original severity: Low
- verdict: NOT ADDRESSED
- now: hci-key-records.py:45 `datetime.fromtimestamp`
- what is left to do: check datalink; state timezone.

### kernel-preflight.sh: C=2 vs C=1; relative sparse path after cd
- original severity: Medium
- verdict: NOT ADDRESSED
- now: kernel-preflight.sh:8 "C=2" vs :39 `C=1`; :17-18 relative BT_SPARSE tested before the `cd`
- what is left to do: header to C=1; resolve BT_SPARSE with readlink -f.

### journal-archive-grep.py: failures yield "0 match(es)"
- original severity: Medium
- verdict: NOT ADDRESSED
- now: journal-archive-grep.py:26 `if not cmd: continue`, :38 `p.wait()` ignored
- what is left to do: report skips and decompressor failures; non-zero exit.

### journal-scan-time.sh: failed journalctl reports "lines 0"
- original severity: Low
- verdict: NOT ADDRESSED
- now: journal-scan-time.sh:11-12 (`2>/dev/null`, `bc`)
- what is left to do: check status.

### scripts/README.md: "tracked and tested" is true for one of the four named scripts
- original severity: Medium
- verdict: PARTLY
- now: tests/run-tests:15407-15418 now tests sco-ledger-boots.sh (unreadable boot excluded); sco-ledger.sh was already tested. `grep -rln "boot-bt-summary\|build-btusb-stable-matrix" tests devtools tools` finds nothing; scripts/README.md:20-23 unchanged.
- what is left to do: add tests for boot-bt-summary.sh and build-btusb-stable-matrix.sh or narrow the README claim.

### scripts/README.md: rules vs the directory
- original severity: Low
- verdict: NOT ADDRESSED
- now: scripts/README.md unchanged (24 lines); docs/tooling-index.md still lacks dbg-autostop-calls.sh, exhibit-relabel-boot-id.py, export-kernel-review.sh.
- what is left to do: mention subdirectories/index; index the three scripts.

### Docstrings name scripts by former file names
- original severity: Low
- verdict: NOT ADDRESSED
- now: hfp-gain-by-device.py:2,6; hfp-late-vgm-scan.py:2,13; journal-archive-grep.py:2,4 (device-adv-summary.py:7 above)
- what is left to do: fix the names.

## New defects introduced by the changes

Scope: diff of bt-ui-atspi.py, ci-local.sh, ci-local-publish.sh, bluez-release-contains.sh, bluez-tester-compare.sh.

### bt-ui-atspi.py: header still says "without changing anything in the session" / "nothing has to be switched on" while the new option does change registry state
- severity: Low
- where: scripts/bt-ui-atspi.py:2-3 (unchanged first sentence) and the new paragraph at :23-35 ("THE ONE NON-PASSIVE STEP"); the "HOW IT STAYS PASSIVE" paragraph that follows still says "It does NOT register ... RegisterEvent". The new text qualifies it ("Without the option the recorder stays passive, as below"), so it is consistent but the first sentence is now conditional.
- note: tests/prove-ui-capture.sh were extended; not reviewed in depth.

### bt-ui-atspi.py: clock filter also drops legitimate names containing `d:dd` or `d.dd`
- severity: Low
- where: scripts/bt-ui-atspi.py (CLOCK_TEXT = `\b\d{1,2}[:.]\d{2}\b`, used in keep_shell)
- evidence: `if CLOCK_TEXT.search(str(name)) or CLOCK_TEXT.search(str(value)): return False` — any toggle name/description with a number like "0.50", "5.00" or a version "1.20" is dropped from the shell record, silently.
- why it matters: a recorder meant to show what the shell drew loses such label/name changes with no counter; low risk for toggle names but undocumented.

### bt-ui-atspi.py: the NameOwnerChanged re-registration lambda and a failed registration do not change the exit status
- severity: Low
- where: scripts/bt-ui-atspi.py register_shell_events() `except GLib.Error as e: out("# register FAILED ...")`; main() mode string is set to "NOT passive: registered the shell's event types" even when every RegisterEvent failed.
- why it matters: the start line claims registration happened although all calls may have failed; only the earlier "register FAILED" lines say otherwise.

### ci-local.sh: three NOT RUN paths still not in SKIPPED (see PARTLY above)
- severity: Medium (unchanged), so the new "exit 2" is incomplete: ci-local.sh:586, :657, :743.

### bluez-tester-compare.sh: rc ordering
- severity: none found beyond: a later regression (cmp_rc 1) after an earlier incomplete tester (rc 2) keeps rc 2, and the "RESULT: regressions found" line is then not printed (`(( rc == 1 ))` false); the regression lines themselves still appear in the summary. Low.

### ci-local-publish.sh, bluez-release-contains.sh: none found.

---

# Part: code-scripts-b

## Recheck of code-scripts-b against main a8d0eb45
Changed on main in my part: runtime-mgmt-test.sh, smtp-login-check.sh, sco-ledger.sh, sco-ledger-boots.sh, prove-ui-capture.sh, new send-table-check.py. All other scripts in my range and all subdirectories are unchanged (git diff 162d3b9~1 HEAD --stat). Line numbers below are main's.

### runtime-mgmt-test.sh: load/restore carry only a comment warning, no refusal; usage text omits the warning
- original severity: High
- verdict: FIXED (small leftovers)
- now: scripts/runtime-mgmt-test.sh:150-155 `load|restore) ... echo "REFUSED: '$cmd' unloads and reloads btusb ..." >&2; exit 2`; usage `sed -n '2,22p'` now reaches the warning (:22); BRIEF.md:772 "now refused by the code, exit 2"; tests/run-tests:15257-15263 asserts it. Leftover: the header usage lines still list the verbs as working (:14 "load unpatched|patched   swap bluetooth.ko", :15 "restore   back to the stock on-disk bluetooth.ko"); dead cases `load_disabled)` (:156) and `restore_disabled)` (:168) keep the old code.
- what is left to do: mark :14-15 as refused (or delete the dead cases).

### smtp-login-check.sh: network/TLS errors exit 1, the same code as REVOKED
- original severity: High
- verdict: FIXED
- now: scripts/smtp-login-check.sh: connection and STARTTLS moved inside the try; `except BaseException ... print("INCONCLUSIVE — no verdict, ...") sys.exit(3)`; header lines 13-16 document "exit 3 and INCONCLUSIVE". Residual: lines 20-22 `git config sendemail.* ) || exit 2` still print nothing.
- what is left to do: print a one-line message before `exit 2` (Low).

### trial-close-now.sh: exit status hides failures; tmp dir leaked; unknown argument ignored
- original severity: Low
- verdict: NOT ADDRESSED
- now: trial-close-now.sh:43 `empty=$(mktemp -d ...)` never removed; :62 `echo "sco decode: rc=$?` not propagated; :64 `[[ "${1:-}" == --reopen ]]`.
- what is left to do: rm the dir, propagate rc, reject unknown args.

### kernel-review-pack: all 53 path+SHA-256 pairs match (control)
- original severity: Low
- verdict: FIXED (still holds)
- now: re-ran the parse on main: 53 pairs, 0 missing, 0 mismatch. docs/sent-mails.tsv re-done by hand: 26 ok, 0 changed, 0 missing.
- what is left to do: nothing

### Hard-coded /root/exp/qca9377-bt-hang paths
- original severity: Medium
- verdict: NOT ADDRESSED
- now: move-brief-block.py:11, prove-archive-budget-check.py:16, prove-bt-trace-archive.py:17, prove-held-branch-guard.sh:6, bt17-review-pack/build.py:13-14, cd-trace/x1-check-submission.py:13 all unchanged.
- what is left to do: derive the root from __file__.

### "prove-*" scripts that cannot fail
- original severity: Medium
- verdict: NOT ADDRESSED
- now: prove-trial-closer.sh:44 `exit 0`; prove-trial-nomatch.sh:27 `exit 0`; prove-trial-build-label.sh and prove-ci-cwd.sh still have no assertion/exit status; unchanged.
- what is left to do: count failures and `exit $((fail>0))`.

### patch-id-compare.sh, patch-code-compare.py: exit status / usage
- original severity: Low
- verdict: NOT ADDRESSED
- now: patch-id-compare.sh:last line `if [[ -n "$a" && "$a" == "$b" ]]; then echo "SAME"; else echo "DIFFERENT"; fi` (exit 0); patch-code-compare.py:61 `sys.exit(__doc__)`.
- what is left to do: exit 1 on DIFFERENT, 2 on usage.

### patchwork-checks.sh: failed fetches skipped silently, exit 0
- original severity: Low
- verdict: NOT ADDRESSED
- now: patchwork-checks.sh:68 and :104 `line=$(checks_line "$id") || continue` (my earlier line numbers 73/83 were off; file unchanged).
- what is left to do: count and report skipped patches, exit 2 if any.

### sco-switch-windows.sh: `|| true` and stale 141 comment
- original severity: Medium
- verdict: NOT ADDRESSED
- now: sco-switch-windows.sh:24 `"$HERE/capture-window.sh" "$f" "$from" "$to" "$PAT" || true`, comment at :22-23 unchanged.
- what is left to do: drop `|| true`, record rc per window, fix the comment.

### sco-ledger.sh / sco-ledger-boots.sh: unreadable boot prints "links 0 ..."
- original severity: Medium
- verdict: WORSE (the original is fixed, a new defect replaces it)
- now: fixed: sco-ledger.sh:34-37 probe `journalctl -k -b "$BOOT" ... -n 1` -> "no counts, not a zero" exit 2; sco-ledger-boots.sh excludes unreadable boots, `boots="$good"`, final `ERROR: ... NOT in the totals` exit 2. New defect: see section below (a readable boot with zero SCO lines).
- what is left to do: see new defect 1.

### r2-checks.sh: `c()` prints "0" twice / "0" for a missing file
- original severity: Low
- verdict: NOT ADDRESSED
- now: r2-checks.sh:9 `c() { grep -cE "$2" "$1" 2>/dev/null || echo 0; }`.
- what is left to do: `|| true` and a file-exists check.

### runtime-mgmt-test.sh: guard fail-open; daemon/trigger verbs are HCI interventions
- original severity: Medium
- verdict: NOT ADDRESSED
- now: runtime-mgmt-test.sh:44-52 guard unchanged (string match on bt-window/bt-trial output); :27 "`status`, `stock-daemon`, `patched-daemon` and `trigger` remain usable." unchanged.
- what is left to do: refuse when bt-window/bt-trial cannot be run; say trigger/daemon verbs send HCI commands.

### prove-audio-policy-metadata.py cannot fail
- original severity: Low
- verdict: NOT ADDRESSED
- now: unchanged (prints kept/lost, exits 0).
- what is left to do: exit 1 on "lost"/"not-removed".

### supported-commands-survey.sh: no mkdir tmp, btmon aborts silent
- original severity: Medium
- verdict: NOT ADDRESSED
- now: supported-commands-survey.sh:23 `OUT="$REPO/tmp/supported-commands-survey.tsv"`, no mkdir; btmon status ignored.
- what is left to do: `mkdir -p`, report btmon rc per file.

### bot-ci-local/harness.py: exit 0 when no test ran
- original severity: Medium
- verdict: NOT ADDRESSED
- now: harness.py:207 `return sum(1 for t in tests if t.verdict != ci.Verdict.PASS)`, no empty-list guard.
- what is left to do: exit 2 if `tests` is empty.

### cd-trace: README "changes a setting"; hard-coded device/user; trace.py end-of-run
- original severity: Low
- verdict: NOT ADDRESSED
- now: cd-trace/README.md:3-4 unchanged; trace.py/totem-*.sh unchanged.
- what is left to do: reword README; handle missing 1-1.

### cd-trace/x1-check-submission.py: stale name, no timeout
- original severity: Low
- verdict: NOT ADDRESSED
- now: x1-check-submission.py:2 "check-submission.py", :21 and :83 `urlopen(...)` without timeout.
- what is left to do: add timeout, distinct exit for network errors.

### Network fetches without timeout / error status
- original severity: Low
- verdict: NOT ADDRESSED
- now: stable-queue-check.sh:19 `curl -s -f` no --max-time, rc=1 for fetch failure and for not queued.
- what is left to do: --max-time, rc 2 for fetch failure.

### Stale/incorrect headers
- original severity: Low
- verdict: NOT ADDRESSED
- now: ubuntu-bluez-patches-check.py:5 "Usage: dev-release-patches.py"; prove-held-branch-guard.sh:3 "two suite assertions"; ubuntu-series-versions.py:21 `[:4]`; x1-check-submission.py:2. (The "Everything is reversible" part of this block is fixed in runtime-mgmt-test.sh:6.)
- what is left to do: fix the four headers.

### sent-mail-check.py: missing local file -> "unreachable"; empty filter exits 0
- original severity: Low
- verdict: NOT ADDRESSED
- now: sent-mail-check.py:289 `except OSError as e:` ... return 2; :269 filter unchanged.
- what is left to do: separate local OSError; exit 2 on zero rows.

### prove-dr-followup.sh / prove-dr-review.sh run uninstall.sh --apply via PATH stubs
- original severity: Low (needs-check)
- verdict: NOT ADDRESSED
- now: unchanged.
- what is left to do: assert the stub wins (or drop).

### module-updates.sh: `remove` has no open-trial check
- original severity: Low
- verdict: NOT ADDRESSED
- now: module-updates.sh unchanged (install-only trial check).
- what is left to do: say so in the header or check in remove.

### Hard-coded machine specifics not marked local-only
- original severity: Low
- verdict: NOT ADDRESSED
- now: user `i`/uid 1000 in user-*.sh and cd-trace/*.sh; prove-bt-trace-archive.py:49 fallback to untracked tmp file; bt17 build.py unchanged.
- what is left to do: mark as local-only or add overrides.

### Privacy scan of scripts/
- original severity: Low (control)
- verdict: FIXED (still holds)
- now: re-scan of the changed files: only the placeholders `00:11:22:33:44:55` / `DE:AD:BE:EF:00:01` (prove-ui-capture.sh:552,571); send-table-check.py has none.
- what is left to do: nothing

## New defects introduced by the changes
1. sco-ledger.sh / sco-ledger-boots.sh (Medium, likely): a readable boot with no SCO lines is now reported UNREADABLE. sco-ledger.sh:49 ends in the pipeline `journalctl -k -b "$BOOT" ... --grep '...' | awk ...` under `set -uo pipefail` (:34 region); journalctl exits 1 when --grep matches nothing (the project's own scripts/prove-trial-nomatch.sh header: "a journalctl --grep read that matched nothing exits 1 with a silent stderr (systemd 255)"). So the table is printed with zeros but sco-ledger.sh exits 1, and sco-ledger-boots.sh:`if OUT=$("$HERE/sco-ledger.sh" "$b"); then ... else echo "   UNREADABLE — excluded from the totals"` drops the table and ends with exit 2. A boot with genuinely zero SCO links (the readable-zero case the probe was meant to keep) is therefore excluded and fails the whole run; the probe at :34 already proves readability, so the pipeline status is the wrong signal. Needs-check on the exact journalctl version, but the repo documents the behaviour.
2. runtime-mgmt-test.sh (Low): the refusal leaves `load_disabled)` and `restore_disabled)` as dead code with the whole old swap path, and the header usage still advertises both verbs (:14-15); a later rename of the case labels would re-enable them silently.
3. send-table-check.py (Low): reviewed, works on main (I redid its logic by hand: 20 rows, 0 problems). Weaknesses: zero rows found gives "0 rows, 0 problem(s)" exit 0 (no positive control in the script itself; tests/run-tests:15345 covers the scratch-table case); only the Unicode "…" is detected, not an ASCII "..."; a backticked token with no "/" is skipped, so an elided single name is not checked; paths are tested with `(root / path).exists()` so an absolute path or `..` passes if present.
4. prove-ui-capture.sh (Low): new light-mode block reviewed. All new checks are asserted and the script still ends on the pass/fail counter. The AT-SPI/light-mode registry checks sit inside the `dbus-daemon && python3-gi` branch, so on a host without them they are one FAIL, not a skip (as before). Registry stub PID is killed only on the happy path (:431); cleanup() kills only BUS_PID, which ends the stub anyway. References tests/fixtures/ui-atspi-shell-filter.tsv and `bt-ui-atspi.py --check-filter`, both present on main. Hard-coded counts `7/10` for keep/drop in the fixture check will need editing with every fixture change.

---

# Part: code-devtools

## recheck code-devtools (main a8d0eb45; paths are in the main checkout)
Changed on main in my part: devtools/repo-save, devtools/repo-validate, devtools/coverage-exclude, devtools/repo-scan-public-addresses (plus README.md, BRIEF.md). .github/, .gitignore, all other devtools/ files unchanged.

### repo-save compares the commit identity with the checkout's own git config
- original severity: High
- verdict: FIXED (with a bypass switch, see New defects)
- now: devtools/repo-save:~156-182: `want="$(sed -n 's/^[[:space:]]*WANT:...' "$HERE/../.github/workflows/checks.yml" ...)"` and refusal "the project author could not be read from .github/workflows/checks.yml (WANT) — refusing to guess". Messages now say "not the expected identity".
- what is left to do: devtools/README.md:248 still says "the identity configured in the checkout" (stale); devtools/held:19 keeps a third hard-coded copy of the identity.

### repo-save's per-commit push check skips commits any remote has
- original severity: Medium
- verdict: NOT ADDRESSED
- now: devtools/repo-save:256 `done < <(git rev-list "$br" --not --remotes 2>/dev/null)`; comment about "already on some remote" unchanged; README.md:328-329 still "check both fields on every commit".
- what is left to do: exclude only public remotes, or reword.

### CI identity job passes with 0 commits on a forced update
- original severity: Medium
- verdict: NOT ADDRESSED
- now: .github/workflows/checks.yml:55-72 unchanged (merge-base with origin/main; `echo "$n commit(s) examined in $range"`; no failure on n=0 / empty range).
- what is left to do: treat an empty range after a non-ancestor `before` as an error.

### pre-push hook scans net diff
- original severity: Medium
- verdict: NOT ADDRESSED
- now: devtools/repo-scan:59 and devtools/hooks/pre-push unchanged.
- what is left to do: scan per commit (`git log -p`/each commit's added lines) in --range.

### repo-validate parses Python only for *.py
- original severity: Medium
- verdict: NOT ADDRESSED
- now: devtools/repo-validate:125 `case "$f" in *.py) ;; *) continue ;; esac`; devtools/py-coverage:12 "exactly one Python file" unchanged.
- what is left to do: also parse files whose first line has a python shebang; fix py-coverage/tests wording.

### repo-scan accepts more emails than documented
- original severity: Medium
- verdict: NOT ADDRESSED
- now: devtools/repo-scan unchanged (`^modprobe@|^systemd-`, `^(noreply|no-reply)@`, `giometti@linux.it`, example.org). Two entries added to devtools/repo-scan-public-addresses (a Message-ID, and a token ending in the mail host (a fragment of a Message-ID), a Message-ID tail the scanner cut at "=": another fragment token, not an address, passes in every file; commented as such).
- what is left to do: drop the broad patterns or document them.

### public-addresses / quoted-examples check
- original severity: Low
- verdict: NOT ADDRESSED (no defect then; unchanged)
- now: still only `@lists.linaro.org` as host entry; quoted-examples unchanged and files exist. New fragment entry a token ending in the mail host (a fragment of a Message-ID) (public-addresses, end of file) is a 1-char-local-part token at gmail's mail host; matches only that exact string.
- what is left to do: nothing required.

### held sync ignores failed push; relative msgfile
- original severity: Low
- verdict: NOT ADDRESSED
- now: devtools/held:61 `git push -q private "$HELD" 2>&1 | tail -1`; held:19 IDENT unchanged.
- what is left to do: check push status; resolve msgfile before cd.

### awk-coverage exits 0 on red suite / missing gawk; journal-contract; ci --recent
- original severity: Medium
- verdict: NOT ADDRESSED
- now: devtools/awk-coverage:74-77, journal-contract:43-44, ci --recent branch unchanged (all files unchanged).
- what is left to do: capture the suite status in awk-coverage; make skips non-zero or loud in CI.

### checks.yml "EIGHT JOBS"
- original severity: Low
- verdict: NOT ADDRESSED
- now: .github/workflows/checks.yml:26 "# EIGHT JOBS, ON EIGHT RUNNERS AT ONCE." (nine jobs).
- what is left to do: change to nine.

### BRIEF "now says about a minute"
- original severity: Low
- verdict: NOT ADDRESSED
- now: BRIEF.md:832 "it now says about a minute"; BRIEF.md:841 "seven in CI's check job on 2026-10-17, an eighth in the audit job"; checks.yml has no such text.
- what is left to do: correct or drop the quotation.

### Branch convention in README / review/* private only
- original severity: Medium
- verdict: NOT ADDRESSED
- now: README.md:286-288 "`review/<UTC timestamp>` holds one assessment ... per the convention in [`reviews/README.md`]"; repo-save still routes review/* to private. (BRIEF's deletion of 16 remote branches does not touch this.)
- what is left to do: say the branches are private, point to the real convention.

### devtools/README: commit-message scan, review-open words, Notes list
- original severity: Low
- verdict: NOT ADDRESSED
- now: devtools/README.md unchanged; devtools/review-open unchanged; repo-save message scan still MAC-only.
- what is left to do: reword / extend lists.

### devtools/save output filter and budget count
- original severity: Low
- verdict: NOT ADDRESSED
- now: devtools/save unchanged.
- what is left to do: add `all checks passed`, `✓ tests`, `nothing to commit` to the filter.

### Tests for hook and journal-files tool run by nothing
- original severity: Medium
- verdict: NOT ADDRESSED
- now: grep of tests/run-tests and .github/workflows for test-pre-push: no hits in main either.
- what is left to do: wire them into the suite/CI.

### Stale comments (.gitignore, assert-test-catches, status)
- original severity: Low
- verdict: NOT ADDRESSED
- now: .gitignore and those scripts unchanged.
- what is left to do: nothing urgent.

### coverage-exclude, checked-consistent item
- verdict: still consistent for the changed entries: bt-sco:121-129 (awk .. `' "$TMP"`), bt-trial:1109-1117, tests/run-tests:652-658, bt-window:89-91 and 111-113 all open/close on the expected awk lines (read; not executed).

## New defects introduced by the changes
1. repo-save identity bypass switch BT_REPO_SAVE_CONFIG_IDENTITY (devtools/repo-save, seam block): with =1 the identity is taken from the target's own git config, i.e. the old tautological check. Guard is a heuristic: refused only if the target is this project's checkout or any `remote.*.url` is not an absolute path / file:///. Gaps: `pushurl` and `url.*.insteadOf` are not inspected (a scratch target with local `url` but an https `pushurl` passes and can push); a target with no remotes passes; a different clone/worktree of the project with local-path remotes passes; relative-path remote urls (`../x`) are refused though local. tests/run-tests:548 exports the variable for the whole suite, so every repo-save/held run made from within the suite inherits it (they are scratch targets). Message prints `remote ${_key#remote.}` which keeps the `.url` suffix (cosmetic). Severity Medium (it is a documented-as-test-only bypass of the gate the High finding was about).
2. devtools/README.md:248 still says "the identity configured in the checkout" while repo-save now reads WANT from checks.yml; README.md:328 / BRIEF.md:499 are consistent with the new logic. Low.
3. Executable-bit check (devtools/repo-validate:199-212): works on the index mode (`git ls-files -s`), runs also under --no-suite, good. Edge defects: a tracked symlink (mode 120000) whose target starts with `#!` is reported as "no executable bit"; `git ls-files -s -- "$f"` treats `$f` as a glob pathspec, so a filename containing `[`, `*` or `?` can yield several lines and a false report; the check is skipped silently when .github/workflows/checks.yml is absent (a tree that is the project's own but lacks the file). Low.
4. No elided "…" paths or references to missing files found in the new text of the four changed devtools files; the two new public-addresses comments cite reviews/2026-11-15T0115Z-submitted-status-review-reviewer-2-verbatim.md and reviews/2026-11-15T0300Z-submitted-status-review-checks.md (existence not checked here).

---

# Part: tests-1

## tests-1 recheck against main a8d0eb45 (tests/run-tests now 16005 lines)

### README coverage floor for awk (85) disagrees with CI (95)
- original severity: Medium
- verdict: FIXED
- now: tests/README.md:422 "hold a floor (80, 95, 80 and 75 on"; checks.yml:301 `--min 95`
- what is left to do: nothing

### README says the upgrade rehearsal asserts 17 checks; tests/system-upgrade has 20 ok sites
- original severity: Low
- verdict: NOT ADDRESSED
- now: tests/README.md:376 "What it asserts (17 checks):"; `grep -cE '\bok "' tests/system-upgrade` still 20
- what is left to do: update the count and the bullet list

### Guard "no bt-trial lifecycle verb outside the wrappers" does not list autostop
- original severity: Low
- verdict: NOT ADDRESSED
- now: tests/run-tests:15549 `tools/bt-trial +(autostart|start|ok|hang|abort|step)\b`, :15552 same plus report
- what is left to do: add autostop to both alternations

### README rule 4: report calls "set BT_REPO on their own line" - one does not
- original severity: Low
- verdict: NOT ADDRESSED (two more of the same shape added)
- now: tests/run-tests:2345 `env -u BT_REPO "$CO/co/tools/bt-trial" report`; new :5534, :5536 `env -u BT_REPO "$W/tools/bt-trial" report`; README unchanged
- what is left to do: reword the README sentence (read-only report calls that unset BT_REPO on purpose are allowed)

### Discovery/scan check with `|| true` and a misleading file count (awk -f trap)
- original severity: Low
- verdict: NOT ADDRESSED
- now: tests/run-tests:2193 `offenders=$(grep -rnE ... tools/ bin/ 2>/dev/null ...`, :2196 `ok "... (${#SHFILES[@]} files)"`
- what is left to do: check grep rc, print the scanned count

### "PIPEFAIL-DEMO" check passes on both outcomes
- original severity: Low
- verdict: FIXED
- now: tests/run-tests:3391 `bad "a matching grep -q pipeline exited 0 under pipefail: the rule's premise no longer holds on this shell"`
- what is left to do: nothing

### results.tsv width/header checks read the live evidence file and pass vacuously if absent
- original severity: Low
- verdict: NOT ADDRESSED
- now: tests/run-tests:3410 `WIDTH=$(awk ... evidence/trials/results.tsv 2>/dev/null)` still ok on empty; :3617 n_col unchanged
- what is left to do: fail when the file is missing or print the row count checked

### tests/whole-boot-reads.txt: all 41 entries are "pending", yet the invariant passes
- original severity: Low
- verdict: NOT ADDRESSED (scope widened, 2 reasoned entries added)
- now: whole-boot-reads.txt has 43 entries, 41 `pending`; the 2 new ones (devtools/journal-contract, devtools/sandbox) carry reasons. wb_scan now includes devtools/* (run-tests ~3582).
- what is left to do: give the 41 pending reads a reason or bound them

### Stale counts and comments in run-tests
- original severity: Low
- verdict: NOT ADDRESSED
- now: run-tests:259 "mktemp in 80 places", :475 "79 other mktemps", :2021 "The fixture holds 5 rows", :3693 and :3704 `[^\n]*`, :4935 `CHAIN'"'"'S LAST RUNG`
- what is left to do: fix the five items

### `--section` ignores --serial/--jobs given on the same command line
- original severity: Low
- verdict: NOT ADDRESSED
- now: tests/run-tests:161 `out=$("$0"); rc=$?` (no arguments passed)
- what is left to do: pass the parsed jobs option to the child, or document it

### README fixtures table names `sanitize-logs.sh` without its path
- original severity: Low
- verdict: NOT ADDRESSED
- now: tests/README.md:296 `| sanitize-invariants.log | sanitize-logs.sh |`; whole-boot-reads.txt, unit-state-changes.awk, system-resources.md still not named in README
- what is left to do: path and mention the three files

## New defects introduced by the changes
- README and comment still say "five wrappers" but a sixth now exists: `tlru()` at tests/run-tests:9493 runs `tools/bt-trial "$@"` with BT_REPO and BT_EVIDENCE_REPO set (compliant). Stale text: tests/README.md:61 "one of five wrappers (`trial`, `trial_in`,", run-tests:15813 "Five functions run `tools/bt-trial "$@"` — trial, trial_in, tl, tlt, tlnh —". The check at ~15820 uses `>= 5`, so it still passes. Low.
- New suite-wide bypass switch: tests/run-tests (~544) `export BT_REPO_SAVE_CONFIG_IDENTITY=1` makes devtools/repo-save accept the repository's own configured identity (devtools/repo-save:148-164, refused in the project checkout). It is a documented test seam, and the checkout world unsets it. Not listed in tests/system-resources.md or README rules (only BT_UI_LIGHT_BASE and BT_UI_LIGHT_ADAPTER were added there, which is correct for those two). Low, informational.
- New check at run-tests ~7885, ~7897, ~7954, ~7965 (bt-incident session counts): `ls -1 evidence/sessions "$BT_EVIDENCE_REPO/evidence/sessions" | wc -l` compares a total over two directories; one entry removed and one added would cancel. Low, theoretical.
- Other new checks reviewed in the first third of the diff and able to fail: bt-diagnose "Cannot determine" (exit 2 asserted, `! grep 'NOT observed'`), end-to-end unreadable journal, `bt-sco --window --raw`, bt-capdiff "The paths agree" (the old always-true `agree` match was fixed), bkj `[[ -s calls.log ]]` guard, TLRU unclosed-directory set-aside (asserts content of both the aside copy and the new empty steps.log). tlru uses $TL defined earlier in the same section (run-tests:9019), so no independence break.

---

# Part: tests-2

## tests-2 recheck against main a8d0eb45 (tests/run-tests; line numbers are main's)

### bt-capdiff window check matches the tool's own title, cannot fail
- original severity: Medium
- verdict: FIXED
- now: tests/run-tests:7613 `[[ "$CDW" == *"The paths agree"* && "$CDW" != *"coverage question"* ]]`
- what is left to do: nothing

### "evidence/sessions untouched" checks cannot see a leak (BT_EVIDENCE_REPO redirected)
- original severity: Medium
- verdict: FIXED
- now: 7886, 7897, 7954, 7965 `ls -1 evidence/sessions "${BT_EVIDENCE_REPO:?}/evidence/sessions" ... | wc -l` (both trees counted)
- what is left to do: nothing

### Weak glob assertions
- original severity: Low
- verdict: NOT ADDRESSED
- now: 5439 `*"HCI command timeouts"*"2"*`; 5496 `*"btsnoop files:"*"2"* && *"capture gaps logged:"*"3"*`; 7828 `[[ "$EHR" == *"N"*"on"* ]]`
- what is left to do: anchor each to the label's own line (grep the line, then compare the field)

### Negative grep on a file that may not exist
- original severity: Low
- verdict: FIXED
- now: 10345 `if [[ -s "$BKJ/calls.log" ]] && ! grep -q -- '--replace' ...` with comment "The log must EXIST and hold calls"
- what is left to do: nothing

### README rule 4 vs guard (six verbs)
- original severity: Low
- verdict: NOT ADDRESSED
- now: tests/README.md:64 still "a second check fails on a spelled-out `tools/bt-trial <verb>` call"; run-tests:15549 still `(autostart|start|ok|hang|abort|step)`; 9604 `BT_REPO="$TL" tools/bt-trial audit --help` unchanged
- what is left to do: say "the six mutating verbs" in the README, or widen the pattern to every verb

### Duplicate check description
- original severity: Low
- verdict: NOT ADDRESSED
- now: 8074 and 8534 both `ok "bt-usbmon rejects an unknown argument"`
- what is left to do: make one say "--check section" / "supervision loop"

### Fixture derived from real tracked results.tsv
- original severity: Low
- verdict: NOT ADDRESSED
- now: 9522-9523 `head -1 evidence/trials/results.tsv`, 9561-9562 `head -2 evidence/trials/results.tsv | tail -1`
- what is left to do: build the header and row from a tests/ fixture (tests/trial-results.tsv, $FIX)

### Stale/dangling comments
- original severity: Low
- verdict: NOT ADDRESSED
- now: 6349 "it is READ 4000 lines below" (read is now near 15900); 6517-6520 "THE SANDBOX ITSELF ..." comment above `else`; 9624 "THE POSITIVE CONTROL ..." above unrelated heading; 6376-6378 "these nine assertions" vs 6422 "turning eleven assertions red"
- what is left to do: fix or delete the four comments

## New defects introduced by the changes (diff 162d3b9~1..HEAD of tests/run-tests reviewed: all hunks, middle third in detail)
- Medium: the suite now runs a machine-dangerous script. New block "review fixes of 2026-11-15" (~15210 onward) loops `scripts/runtime-mgmt-test.sh "$_v" patched` for load and restore, straight from the checkout with no stub, PATH farm or namespace. The script's own comment says these verbs wedged the controller (EX-046); the refusal is at scripts/runtime-mgmt-test.sh:153 inside the case. If that refusal ever regressed, the suite (which runs as root on the investigation machine) would swap bluetooth.ko live. Also no tests/machine-tools / access-allowlist entry mentions it. Fix: run it with `machine_stub` dir or a copy whose swap commands are stubs, or assert the refusal by reading the source.
- Low: unguarded `shift 2` scan (RFUNG, new) excludes the whole of tools/lib/journal.sh by path (`grep -vE 'tools/lib/journal\.sh'`) and only matches `shift 2` followed by ` ;;`, `;` or EOL; it is an exception list in a rule that README rule 2 says takes none.
- Low: weak globs again in new checks: trial-sco-table `*"no SCO setup"*" 0 "*" 1"*` and trial-summary `*"1/2"*"50%"*` accept any later " 0 " / " 1" or any "50%" after "1/2" anywhere in the output.
- Low: hard-coded "all 18 option loops" in the ok text; the list has 18 entries today, so it will drift silently when one is added.
- No elided "..." paths except the intentional scratch fixture `CO-02-…/send/` (fixture for send-table-check, expected to be refused); all new scripts referenced (send-table-check.py, sco-ledger-boots.sh, ci-local-publish.sh, smtp-login-check.sh, bluez-release-contains.sh) exist on main.

---

# Part: tests-3

(main = a checkout of main, tip a8d0eb45. tests/system-roundtrip, tests/system-upgrade, tests/machine-tools, tests/access-allowlist, tests/btmon/* are unchanged on main.)

### machine-tools omits machine tools that shipped code calls
- original severity: Medium
- verdict: NOT ADDRESSED
- now: tests/machine-tools:28 still `runuser  # likewise: bt-ui-capture runs pw-metadata and gsettings...`; gsettings, pw-metadata, dbus-monitor, dpkg, getent, ps, df, pgrep still unlisted (grep of the file).
- what is left to do: add the tools (or declare why not) and derive/verify the list against the code.

### run-tests comment cites stale line numbers of its own file
- original severity: Low
- verdict: NOT ADDRESSED
- now: tests/run-tests:15608-15610 still "line 34 / line 70 / line 133"; actual lines 35, 71, 161 (grep -nE '"\$0"').
- what is left to do: update the three numbers or drop them.

### bt-snapshot "no unlabelled number" check cannot fail on a missing summary
- original severity: Low
- verdict: NOT ADDRESSED
- now: tests/run-tests:10693 `STRAY=$(grep -nE ... "$SNDIR/summary.txt" || true)`; 11115 `SNTOUCH=$(grep -nE '(hciconfig|...)' tools/bt-snapshot | grep -vE ... || true)`; 11343 `CRTOUCH=$(grep -nE ... tools/bt-crash ...`
- what is left to do: add a positive control (file exists / pattern matches a planted line).

### tests/README.md coverage floors disagree with CI (awk 85 vs 95)
- original severity: Medium
- verdict: FIXED
- now: tests/README.md:422 "hold a floor (80, 95, 80 and 75"; .github/workflows/checks.yml:301 `devtools/awk-coverage --min 95`.
- what is left to do: nothing

### tests/README.md says the upgrade rehearsal asserts 17 checks; script has 20 ok() sites
- original severity: Low
- verdict: NOT ADDRESSED
- now: tests/README.md:376 "What it asserts (17 checks):"; tests/system-upgrade still has 20 `ok "` sites.
- what is left to do: change the number (or state it as "about").

### system-roundtrip: the "experiment mode" gate is unreachable
- original severity: Low
- verdict: NOT ADDRESSED
- now: file unchanged: gate 2 (-e dir) precedes the `-r .../mode` gate.
- what is left to do: drop the dead gate or move it before gate 2.

### system-roundtrip final "nothing survives" check passes on an empty derivation
- original severity: Low
- verdict: NOT ADDRESSED (file unchanged)
- what is left to do: assert the derived list is non-empty.

### Silent skips inside run-tests: python3 / zstd / tool-absent branches
- original severity: Low
- verdict: NOT ADDRESSED
- now: tests/run-tests:14124, 14560, 14600, 8863 `if command -v python3 ...` (no else), 14110 `kcheck()`, 10505-10510 zstd branch; the NOT ASKED block (15971 `for _ns in ...`) lists no python3/zstd note. The new tests (15200-15525) also call python3 and zstd/xz/gzip unconditionally with no skip note.
- what is left to do: add *_SKIPPED notes or require the tools.

### staged --apply tests only ever install the positive-control device
- original severity: Low
- verdict: NOT ADDRESSED
- now: tests/run-tests:12403, 12523 `stage_install BT_VID=0cf3 BT_PID=e300`.
- what is left to do: one staged apply with the default device.

### tests/btmon/README.md "The cases" table lists 3 fixtures
- original severity: Low
- verdict: NOT ADDRESSED (file unchanged)
- what is left to do: add the other fixtures.

### Fixture privacy scan (clean) / Checked-consistent list
- verdict: still holds. New fixture tests/fixtures/ui-atspi-shell-filter.tsv: no addresses, hosts or real device names ("Headset A", clock text only). The new run-tests code adds only example.com, 127.0.0.1, example-owner/public-repo and the maintainer's checks.yml identity read at run time.

## New defects introduced by the changes
### The light-mode feature and its fixture are not tested by the suite or CI
- severity: Medium; kind: rule-vs-practice
- where: tests/fixtures/ui-atspi-shell-filter.tsv (consumed only at scripts/prove-ui-capture.sh:504-507); tests/run-tests has no `start-light`, `stop-light`, `status-light`, `--check-filter` or `--register-shell-events` (grep: none); no workflow or devtools script runs prove-ui-capture.sh (grep .github devtools: none). run-tests:11631-11635 itself records that a bt-ui-capture feature with only a standalone proof left the comprehension floor red. The fixture is also absent from the fixtures table in tests/README.md.
- what is left: carry the light-mode checks and the filter fixture into run-tests (the suite only declares the two new seams, run-tests:537).

### bt-raw-archive install test takes one branch per checkout location
- severity: Low; kind: test-defect
- where: tests/run-tests:12413-12432 (`if [[ "$SIRAWSRC" == "$PWD/scripts/raw-capture-archive-all.sh" ]]`).
- the positive branch runs only from the investigation machine's checkout path, the negative only elsewhere (CI); each host silently skips the other, and nothing says which was asked (no NOT ASKED note).

### tests/whole-boot-reads.txt header count stale after two lines were added
- severity: Low; kind: stale
- where: tests/whole-boot-reads.txt:13 "41 reads in 21 files"; the file now lists 43 entries in 23 files (devtools/journal-contract, devtools/sandbox added at the end, with reasons).

### New env bypass BT_REPO_SAVE_CONFIG_IDENTITY exported for the whole suite
- severity: Low; kind: other
- where: tests/run-tests:548 (export), devtools/repo-save:148-170. It is guarded (refused for the project checkout or non-local remotes) and tested (run-tests:15309-15336), so not a defect in itself; but it is a new bypass switch of the identity gate that is documented only in repo-save and run-tests comments, not in tests/README.md or system-resources.md. The guard checks `remote.*.url` only (pushurl is not read).

### Leftover development marker and a test executing a controller-wedging script
- severity: Low
- where: tests/run-tests:15525 `# MARKER-NEW-TESTS-END` (stray marker). Also run-tests:15249ff runs `scripts/runtime-mgmt-test.sh load|restore` directly (EX-046 wedged the controller); safety rests on the refusal and on modprobe/insmod being tripwired on PATH (absolute-path calls would not be).
- minor: run-tests:15200ff `RFUNG` scans only tools/ and bin/ for unguarded `shift 2` (scripts/ and devtools/ not scanned), ends `|| true` with no positive control; the repo-save identity tests' ok-text at ~14845 still says "not the checkout's identity" while the message asserted is now "the expected identity".

---

# Part: history

## Recheck, history part (main a8d0eb45). HISTORY.md is unchanged on main (git diff 162d3b9~1 HEAD -- HISTORY.md is empty), so every HISTORY finding keeps its old line numbers.

### BRIEF §10 says HISTORY has dated chapters only "to 2026-10-28"
- original severity: Low
- verdict: FIXED
- now: BRIEF.md:887 "`HISTORY.md` (37 phases, dated chapters to 2026-11-14, and the retired hand-off blocks)"
- what is left to do: nothing

### Structure check (37 phases etc.)
- original severity: informational
- verdict: FIXED (nothing to fix; still true: 37 phases, last chapter HISTORY.md:4434)
- what is left to do: nothing

### Milestones paragraph says BlueZ patches "sent and applied, Phase 36"
- original severity: Low
- verdict: NOT ADDRESSED
- now: HISTORY.md:6 unchanged
- what is left to do: change to Phase 37

### Milestones paragraph stops at 2026-11-07
- original severity: Low
- verdict: NOT ADDRESSED
- now: HISTORY.md:11-15 unchanged
- what is left to do: extend to 11-12 block / 11-14 chapters

### Phase 34 "pushed into a 9-byte endpoint" without correction note
- original severity: Medium
- verdict: NOT ADDRESSED
- now: HISTORY.md:2715 unchanged
- what is left to do: add a bracketed note pointing to the fourth-review chapter (:3213-3218)

### Phase 18 "first EARLY reset ever captured" vs Phase 10
- original severity: Medium
- verdict: NOT ADDRESSED
- now: HISTORY.md:901 unchanged
- what is left to do: reword ("first early reset that was followed by a hang") or note the 08-11 session

### Phase 30 "Eight residual sentences" names seven
- original severity: Low
- verdict: NOT ADDRESSED
- now: HISTORY.md:3261
- what is left to do: fix the count or the list

### 1836 s vs 1837 s
- original severity: Low
- verdict: NOT ADDRESSED
- now: HISTORY.md:1774, :1850
- what is left to do: make both 1836 s

### CO-04 competing patch 9 of 12 vs 8/12
- original severity: Low (needs-check)
- verdict: NOT ADDRESSED
- now: HISTORY.md:4100, :5088 (9 of 12) vs :5384 (8/12 power boots)
- what is left to do: state the subset or reconcile

### Identifier elision after 2026-09-18
- original severity: Medium
- verdict: NOT ADDRESSED
- now: HISTORY.md:4473 `reviews/2026-11-14T0300Z-…` and the Message-ID / hash / path elisions in the moved blocks (:4875, :4877, :4903, :5194, :5368, :4600, :4610 ...) all unchanged
- what is left to do: write :4473 in full; decide whether "moved verbatim" blocks may be corrected

### Broken references inside moved blocks
- original severity: Low
- verdict: NOT ADDRESSED
- now: HISTORY.md:4802 (dated directory), :4812/:4928 (power-off-compare file) unchanged
- what is left to do: annotate as renamed/kept separately

### BRIEF phase pointers all correct
- verdict: unchanged / still correct (BRIEF.md:552-557 text untouched)

## BRIEF.md on main (extra task)

### (a) Contradictions remaining INSIDE BRIEF.md
1. State block still dated "2026-10-28" and mixes eras. BRIEF.md:79 heading "(2026-10-28; machine lines 2026-10-30; stale lines corrected 2026-11-15 where marked ...)"; unmarked stale lines remain: :94 "Waiting for replies (re-checked 2026-10-28)", :105 "the CO-02 module on the laptop: ... `-42` runs without it (above)" (laptop left -42 on 11-12, :102), :108 and :141 still describe the archive timer as "transient: gone at every reboot" while STATUS.md:295 says the persistent bt-raw-archive.timer replaced it on 2026-11-13.
2. "Last updated: 2026-11-14" (BRIEF.md:151) although this file was edited 2026-11-15 (corrections marked "corrected 2026-11-15" at :82, :97, :102, :120, :136, :174-ff); the update trail does not mention the 11-15 edits.
3. Branch names: BRIEF.md:145 "The test-suite maintainer works on `tests/unit-testing-introduction` and `tests/unit-testing-introduction-ready-for-main`" vs BRIEF.md:226 "The public repository now has `main`, `tests/test-suite`, ..." (after the 16 branches were deleted). :145 is stale or :226 is wrong; STATUS.md:460/464 still use the old names.
4. CI bot timing, BRIEF.md:384 area (the new text): the sentence still opens "answered both v1 mails within 90 min" and the parenthetical says "which against the 18:44 UTC send is 3 h 21 min, not 90". Self-contradicting in one sentence; and HISTORY.md:3318 still says "within ninety minutes of receipt" (BRIEF now disagrees with HISTORY, and HISTORY was not updated).
5. Survival row: §2 title "n = 12 ... both configurations" and the table now shows one survival row "**0** (8 × `len 90 mtu 9`, `EX-037`)", while §4 (:329) says "12 deaths / 2 survivals (§2's 09-01 link, and `EX-031`'s ...)" and the next bullet (:333-334) still says "The survival was the peripheral's choice" (singular). The table has one survival row, text says two. HISTORY Phase 34 (:2700-2705) says "8 setup packets, then CVSD" - BRIEF says "8 × `len 90 mtu 9`"; the two descriptions of the 8 packets differ.
6. §5 retraction row (BRIEF.md:342) "answered in all 5 alt-1 instances (the count when this was written; §2 has 12 now)" is fine; but §3 :301-308 still carries "12 deaths ... 74 links" consistent. No issue.
7. §9.9 (:769-790): header says closed, :772 now says load/restore "are now refused by the code, exit 2; see the warning below", :781 still says "`load`/`restore` must not be run" as an instruction. Consistent in direction, but the "(Updated 11-15)" parenthetical sits inside the runbook sentence and :764 "A reboot restores all" was dropped while :781(b)/(c) still describe reboot-based reversal; the code claim (exit 2) is not checked here against scripts/runtime-mgmt-test.sh.
8. §9.2 (:677-684) unchanged: "Six tasks ... Test Branch Maintainer"; elsewhere (:145, :226 area, §8a) the role is "test-suite maintainer"; device survey "stays open until the operator says what it was" has no owner or date. Not a contradiction, but naming mismatch remains.
9. Archive budgets: now consistent at :433 and :471 (bt-trace 20 GB, desktop 25 GB); :108 narrates the desktop budget history (10 GB -> 20 GB on 10-29) without the later 25 GB, acceptable as history; STATUS.md:164 carries a "corrected 2026-11-15" note.
10. Hand-off (:174-ff): "What to send ... table at the top of contributions/README.md" - that table exists (contributions/README.md:19). Elided/broken: `tmp/port-check/check.sh` is now flagged "a machine-local script, not in a clone" (good, matches HISTORY.md:4483). Commits `8b71499` and `a56141e` exist in main.
11. §10 "dated chapters to 2026-11-14" now correct.

### (b) New BRIEF text vs HISTORY.md
- BRIEF.md:384 CI-bot timing (item 4 above) vs HISTORY.md:3318 "within ninety minutes".
- BRIEF.md:329 "2 survivals" and :282 "0 (8 × len 90 mtu 9)" vs HISTORY.md:2700-2705 (survival row "0 (8 setup packets, then CVSD)") and HISTORY Phase 29/37 (EX-031 is a link that survived, not counted as a survival row there).
- BRIEF.md:226 "tests/test-suite" vs HISTORY.md: no mention; BRIEF.md:145 old names vs HISTORY.md:4000-ff, "tests/unit-testing-introduction" era text (history, fine).
- BRIEF.md:136 "row 3 there is a later boot ... that reused the number" vs HISTORY.md:5352 (10-29/30 block: "E3 #3 has no row ... the row is still to be written") - HISTORY is a dated block, fine; no conflict.
- BRIEF.md:82 / :102 (laptop on -43 since 11-12 22:55) matches HISTORY.md:4397-4433 chapters.

## New defects introduced by the changes
- BRIEF.md "Last updated" line not bumped (item 2); the CI-bot sentence contradicts itself (item 4) and now disagrees with HISTORY.md:3318; "2 survivals" vs one survival row (item 5); :145 vs :226 branch names (item 3) is newly visible because :226 was added. HISTORY.md itself was not touched, so none of the HISTORY-side findings moved.

---

# Part: exhibits

## Recheck: exhibits findings against main a8d0eb45
`git diff --stat 162d3b9~1 HEAD -- evidence` is empty: evidence/ is unchanged. Changed on main in my scope: BRIEF.md, docs/STATUS.md, docs/issues.md, tools/bt-trial, tools/lib/trial-summary.awk.
(main = main)

### Signature table: survival row counts 8 in the `len 27 mtu 9` column
- original severity: Medium
- verdict: FIXED
- now: BRIEF.md:282 "| *survival* | 09-01 | `-30` | modified | **0** (8 × `len 90 mtu 9`, `EX-037`) | — | *lived* |"
- what is left to do: nothing

### Signature table: EX-042 first-command delay "~90 ms" unsupported
- original severity: Low
- verdict: FIXED
- now: BRIEF.md:275 "| `EX-042` | 09-16 | `-31` | modified | 1595¹ | not recorded | 2.147 s |"
- what is left to do: nothing

### Index rows repeat claims the exhibit refutes/corrects/supersedes (EX-007, 006, 086, 093, 058, 033, 036)
- original severity: Medium
- verdict: NOT ADDRESSED
- now: evidence/ unchanged; evidence/exhibits/README.md rows EX-093 ("No kernel error and no HCI command timeout on boot af3f9840 ... the controller is not involved."), EX-086, EX-007, EX-006, EX-058 still carry the uncorrected claims
- what is left to do: add "Superseded by/Corrected" markers to the index rows

### Index/exhibit numbering clean (informational)
- original severity: Low
- verdict: NOT ADDRESSED (nothing to fix; still holds, 97/97)
- now: unchanged
- what is left to do: nothing

### EX-043 has no exit status and no redaction statement
- original severity: Medium
- verdict: NOT ADDRESSED
- now: evidence/exhibits/043-first-command-into-alt1-stream-dies.md unchanged (Provenance table lacks `exit status` and `redacted` rows)
- what is left to do: add both rows (and full tool paths)

### E1 headline: EX-056 is a subset of EX-058, they do not "sum"
- original severity: Low
- verdict: NOT ADDRESSED
- now: BRIEF.md:311-312 still "ran 58 links / 3 boots / 2 headsets with 0 timeouts (`EX-055`, `EX-056`, `EX-058`)"; EX-056 (7 links) lies inside EX-058's 34 on boot 226965f1. It only lists the exhibits, it does not add them, so the wording is weaker than I feared; still ambiguous.
- what is left to do: say EX-058 carries the 58, EX-056/055 are detail

### EX-057 "all 16 hang-ups answered" beside "Opcode 0x0406 failed: -107"
- original severity: Low (needs-check)
- verdict: NOT ADDRESSED
- now: evidence/exhibits/057-... unchanged
- what is left to do: state whether the -107 link is among the 16

### EX-031 "alt 1" not shown in the exhibit
- original severity: Low
- verdict: PARTLY
- now: BRIEF.md:329-330 now says "Correlation across 12 deaths / 2 survivals (§2's 09-01 link, and `EX-031`'s Enhanced-setup link, §3 ...)" - no "alt 1" claim for EX-031 there; exhibit itself unchanged (no "alt 1" text)
- what is left to do: nothing required unless BRIEF §3 still calls EX-031 "on alt 1" (not rechecked)

### results.tsv: BRIEF "E3 #3 has no row" vs a row labelled E3 #3; duplicate trial numbers
- original severity: Medium
- verdict: PARTLY
- now: fixed in BRIEF.md:132-138: "has **no row** in `evidence/trials/results.tsv` (row 3 there is a later boot, 10-30 on `-42`, that reused the number and the directory); its result was recovered from the journal ... 63 links, 0 timeouts (`.../RESULT-boot-257d1599-from-journal.md`; corrected 2026-11-15)" (63 verified, RESULT file line 19). Remaining: E3 #5 and #11 reuse is still recorded only in their NOTE files (evidence/trials/E3/trial-05/NOTE-two-uses-of-this-number.md, trial-11/NOTE-two-trials-one-number.md); results.tsv rows carry no marker. tools/bt-trial now sets an existing trial directory aside (new `set_aside`, "kept as ...") so new reuse is prevented.
- what is left to do: optionally mention #5/#11 in BRIEF; no tsv change needed

### results.tsv: "failed" rows not annotated; only #3, #4, #5 explained
- original severity: Medium
- verdict: PARTLY
- now: tools/lib/trial-summary.awk (new): `if (bs == "not_observed" && tr == "failed") { fnx[k]++; ...; next }` and the printed block "trial(s) FAILED with BT-1 NOT OBSERVED, excluded from every rate above" - so these rows no longer count as survivals. Remaining: results.tsv rows E3 #6-#8, #10, #11 still have no NOTE (trial-06..10 dirs), and the comment cites only "E3 #3 and #4" as the known artefacts.
- what is left to do: per-trial notes or a one-line statement for #6-#8, #10, #11

### evidence/README.md stale (off-topic dir, sessions table)
- original severity: Low
- verdict: NOT ADDRESSED
- now: evidence/ unchanged
- what is left to do: update tree list

### Privacy scan (negative result)
- original severity: Low
- verdict: n/a (no defect); evidence/ unchanged, still holds

### EX-038 command contains "…"
- original severity: Low
- verdict: NOT ADDRESSED
- now: evidence/exhibits/038-...md:42 unchanged
- what is left to do: write the command in full

## Follow-up: docs/issues.md 145-1000

### STATUS BT-1 row: "no boot into -42 without E3"
- original severity: Medium
- verdict: FIXED
- now: docs/STATUS.md:72 "the laptop runs Ubuntu `7.0.0-43`, whose stock btusb carries the entry, since 2026-11-12 22:55; E3 is retired ... (corrected 2026-11-15: this cell still said "no boot in...")"
- what is left to do: nothing

### STATUS BT-9 row contradicts itself on 6.1
- original severity: Medium
- verdict: FIXED (STATUS) / PARTLY (issues.md)
- now: docs/STATUS.md:80 "**released for 6.1 in 6.1.191** (2026-10-30, `dafb564a498e` ...". Still stale in issues.md: :802 "**Status 2026-10-09: already fixed upstream; missing from the 6.12, 6.6 and 6.1 stable ..." and :831 "**Next:** replies." (both followed by a "Since:" paragraph at :832-833)
- what is left to do: optionally update the BT-9 header line

### Evidence model section "n = 2 ... never to its end"
- original severity: Low
- verdict: NOT ADDRESSED
- now: docs/issues.md:213 "(n = 2, both censored)", :216 "walked twice", :224 "Across fifteen windows"
- what is left to do: add an "as written" banner or update counts

### M-1 and M-2 have STATUS rows but no section; M-rows out of order
- original severity: Low
- verdict: NOT ADDRESSED
- now: docs/STATUS.md:97-101 order M-1, M-4, M-5, M-3, M-2; docs/issues.md sections only M-3 (:718), M-4 (:744), M-5 (:778), still between BT-8 and BT-9. The new "Current state 2026-11-15" block does explain the M- naming but adds no M-1/M-2 sections.
- what is left to do: add the two sections or a pointer

### M-3 section lacks the BlueZ 5.88 release
- original severity: Low
- verdict: NOT ADDRESSED
- now: docs/issues.md:720 still "**Status 2026-10-08: accepted.**"; no 5.88 in the M-3 section
- what is left to do: add "released in BlueZ 5.88 (2026-11-05)"

### Path elisions "…" in identifiers
- original severity: Low
- verdict: WORSE
- now: still in old text (docs/issues.md:918 `CO-02-…/log.md`, :935, :957 `CO-35-…`; docs/STATUS.md 6 lines with `CO-43-…`); new text adds more: docs/issues.md:1172 "`contributions/CO-43-…/send-bt24-bt25-20261114/`" and :1189 same.
- what is left to do: write the directory names in full

## New defects introduced by the changes
- docs/issues.md:1172 and :1189 (new BT-24/BT-25 status lines) elide the CO-43 directory name with "…" (rule: identifiers in full). Listed above.
- tools/bt-trial: new comment cites "review T-09, 2026-11-15"; the id exists in reviews/2026-11-15T1751Z-project-review-fixes-reaction-checks.md (found by grep), so no broken reference. No other new defect found in the evidence-related diffs. Not examined: the bt-trial `mv -T` behaviour on other platforms, and whether the awk exclusion changes any printed denominator in tests.

---

# Part: patches

## Recheck, patches part, against main a8d0eb45
Changed in my part on main: only patches/bluez/README.md (+4 lines, the bot-time note). Nothing else under patches/ or docs/sent-mails.tsv changed; BRIEF.md, README.md, docs/STATUS.md changed elsewhere.

### "Within 90 min" bot answer not supported by UTC times
- original severity: Medium
- verdict: PARTLY
- now: fixed/acknowledged: patches/bluez/README.md:147-149 "noted 2026-11-15 ... 22:05 UTC is 3 h 21 min later, which contradicts 'within 90 minutes' ... probably in another time zone"; BRIEF.md:384 "(09-19 22:05/22:10 as recorded, which against the 18:44 UTC send is 3 h 21 min, not 90; ...)". Remaining: patches/bluez/README.md:145 heading still "2026-09-19 22:05 / 22:10 UTC"; reviews/2026-09-20T0300Z-bluez-ci-bot-results.md:3-4 still "within ninety minutes ... 22:05 UTC"; reviews/README.md:71 still "22:05/22:10 UTC"; BRIEF.md:384 still says "within 90 min" in bold.
- what is left to do: the sources support CEST (22:05/22:10 CEST = 20:05/20:10 UTC = 81/86 min; the v2 times in the same README are converted CEST->UTC); correct the label in the 4 places instead of an open note.

### patches/kernel/README.md still says fix has not reached mainline/stable
- original severity: Medium
- verdict: NOT ADDRESSED
- now: patches/kernel/README.md:7 "Reaches mainline with the next bluetooth-next pull; the `Fixes:` tag then carries it to stable on its own"
- what is left to do: add the v7.3 / stable release facts or a "superseded by STATUS" line.

### checkpatch-check.sh / git-am-check.sh break with relative BT_PATCH_DIR
- original severity: Medium
- verdict: NOT ADDRESSED
- now: patches/bluez/checkpatch-check.sh:27-28 `HERE="${BT_PATCH_DIR:-$HERE}"` then `cd "$TREE" || exit 2`; git-am-check.sh unchanged.
- what is left to do: resolve BT_PATCH_DIR to an absolute path before the cd, check perl's exit status.

### diag/README.md stale (E1 37 links; -42 "running since"; no E3 result)
- original severity: Medium
- verdict: NOT ADDRESSED
- now: patches/diag/README.md:52 "37 SCO links over two boots"; :118 "booted 2026-10-30 04:31 and running since"
- what is left to do: update to 58/3 boots/2 headsets, add E3 16 links, note E3 retired 11-12.

### STATUS.md BT-9 row contradicts itself on 6.1
- original severity: Medium
- verdict: FIXED
- now: docs/STATUS.md:80 "released ... in 6.1.191 (2026-10-30, `dafb564a498e` ...; corrected 2026-11-15: this cell still said 'not yet released for 6.1')"
- what is left to do: nothing

### Kernel CI-bot date 09-25 vs mail 09-24 21:33
- original severity: Low
- verdict: NOT ADDRESSED
- now: patches/kernel/README.md:14 "2026-09-25 (mail 2026-09-24 21:33 local)"
- what is left to do: verify and align the date.

### kernel README live-looking "How to send" / open ER4 items
- original severity: Low
- verdict: NOT ADDRESSED
- now: patches/kernel/README.md:252 "## How to send — on the operator's word only"
- what is left to do: mark as historical.

### bluez README "What is kept": v2/ "on the list, unhandled"
- original severity: Low
- verdict: NOT ADDRESSED
- now: patches/bluez/README.md:118 "**v2**, derived by `scripts/build-v2.sh`; on the list, unhandled"
- what is left to do: say 0002 v2 was applied 10-07.

### Documented/checkpatch picks lexically last headers
- original severity: Low
- verdict: NOT ADDRESSED
- now: patches/bluez/checkpatch-check.sh:18 `for c in /usr/src/linux-headers-*/scripts/checkpatch.pl; do`
- what is left to do: sort -V.

### git-am-check.sh "Read-only on the checkout"
- original severity: Low
- verdict: NOT ADDRESSED
- now: patches/bluez/git-am-check.sh:9 and :23 unchanged
- what is left to do: say it adds/removes a temporary worktree.

### README.md repository map vs patches/
- original severity: Low
- verdict: NOT ADDRESSED (cosmetic edit only)
- now: README.md:264 "patches/bluez/ the applied BlueZ patches, their verification script and mail notes;" (was "the two applied"); :269 still "(E1, E3)"; sent/, v2/, btdev-vla/, send-2026-10-13/ still unmentioned; patches/mesh-tester has no README.
- what is left to do: list the omitted directories; say E3 is not committed.

### Broken path ...-on-d84171e6c-2026-10-08/
- original severity: Low
- verdict: NOT ADDRESSED
- now: HISTORY.md:4802 and docs/mesh-tester-ci/review-response-4-bluez-shared-mgmt-2026-10-08.md:8 unchanged
- what is left to do: drop the date suffix (or note the rename).

### stable-request "next" row lacks release
- original severity: Low
- verdict: NOT ADDRESSED
- now: patches/diag/stable-request-dc16388d45ec.md:9 "...then the Ubuntu kernel that carries it; nothing owed"
- what is left to do: record the releases.

### bt9-stable README: "Before sending", 497-498, ci-bot file unlisted
- original severity: Low
- verdict: NOT ADDRESSED
- now: patches/kernel/bt9-stable/README.md:140 "## Before sending (operator's word)"; :104 "between 497 and 498 of 506"
- what is left to do: fix range to 496-498, mark section historical.

### sent-mails.tsv hashes of elided copies
- original severity: Low
- verdict: NOT ADDRESSED
- now: docs/sent-mails.tsv rows at lines 11-13 unchanged
- what is left to do: add a note column "elided copy".

### btdev-vla/README.md header contradicts Superseded
- original severity: Low
- verdict: NOT ADDRESSED
- now: patches/bluez/btdev-vla/README.md:3 "**State 2026-10-10: ... Nothing has been mailed.**"
- what is left to do: reword.

### TEST-REPORT local-only paths
- original severity: Low
- verdict: NOT ADDRESSED
- now: patches/bluez/send-2026-10-18/TEST-REPORT.md:12 "/root/exp/qca9377-bt-hang/tmp/bluez-a1a2-20261018/"
- what is left to do: nothing required (Low).

### Privacy: no raw relay headers
- verdict: unchanged (no finding)

## New defects introduced by the changes
none found. (The new note at patches/bluez/README.md:147-149 says the time zone "is not settled" although the repo's own v2 times show the CEST convention; this is a weakness of the fix, covered under finding 1.)

---

# Part: co-02

## co-02 recheck against main a8d0eb45 (paths relative to main; D = contributions/CO-02-sco-connect-reuses-closing-link)

### Second v2 package exists and is referenced nowhere
- original severity: High
- verdict: PARTLY
- now: fixed: contributions/README.md:19 "What to send" table, row 45: "CO-02 v2 | 1/2 + the **non-sleeping** 2/2: .../review-fixes-20261115/patches/alt-2of2/ ... | send-v2-review-fixes-20261114/ and .../patches/main-v2/: their 2/2 **can deadlock**"; D/send-v2-20261114/SUPERSEDED.md ("Send from ../send-v2-review-fixes-20261114/ instead") and D/send-v2-review-fixes-20261114/SUPERSEDED.md (points to review-fixes-20261115); BRIEF.md:189-190 "Not ready: CO-02 v2 ... candidate is the non-sleeping 2/2 in review-fixes-20261115/"; docs/STATUS.md:9-14. Remaining: (a) send-v2-20261114/SUPERSEDED.md sends the reader to a directory that is itself superseded (chain, not the current package); (b) contributions/README.md:82 (index row) still ends "2026-11-14: v2 built, nothing sent (send-v2-20261114/)" and "| the operator, for any reply or v2" -- it names the superseded package as current, contradicting row 45 of the table 60 lines above; (c) docs/STATUS.md:52 (CO-02 submission row) has no 11-14/11-15 entry at all (ends at the 11-13 note) and its next-step cell still says "the operator's decision on Sashiko's patch-2 finding"; (d) README.md:150-157 unchanged ("the next posting will be a v2 (no maintainer reply as of 2026-11-12 ... which is not a review"); (e) BRIEF.md:93 still carries the 11-02 v2 description ("possibly the mismatch patch"); (f) contributions/rd-2026-11-14.md:86-87 still "CO-02 v2 ... in CO-02-…/send-v2-20261114/" (dated, acceptable). Also send-v2-20261114/NOTES-FOR-OPERATOR.md still opens "Nothing here is sent. The mails are in kernel/ ..." with no pointer to SUPERSEDED.md (the SUPERSEDED.md is the only marker).
- what is left to do: update contributions/README.md:82 and docs/STATUS.md:52 to name review-fixes-20261115 (alt-2of2 + standalone-3) as current; make send-v2-20261114/SUPERSEDED.md point at the table.

### Dossier README, log.md and STATUS row do not record the 11-14 v2 package
- original severity: Medium
- verdict: NOT ADDRESSED
- now: D/README.md:3 still "**Current state, 2026-11-12**" ("The BlueZ test needs a port ... next posting is v2 folding patches 2 and 3"); `git diff 162d3b9~1 HEAD` shows D/README.md and D/log.md unchanged; `grep review-fixes-20261115 D/README.md D/log.md` -> nothing; log.md still ends at "## 2026-11-02". docs/STATUS.md:52 ends at 2026-11-13. (STATUS.md:13 and the table do now carry the 11-15 state, but the dossier's own README/log do not.)
- what is left to do: add a current-state block and a log entry for 11-14/11-15 (v2 built, lock cycle found, non-sleeping 2/2) to D/README.md and D/log.md.

### Root README.md describes CO-02 with the 11-12 reading and no v2 content
- original severity: Low
- verdict: NOT ADDRESSED
- now: README.md:150-157 "the next posting will be a v2 (no maintainer reply as of 2026-11-12; ... which is not a review: [reviews/2026-11-12T1508Z-...])"; README.md:158 `contributions/CO-02-…`. No mention that v2 exists/is not ready; the 11-13 correction ("v2 is also the resend") is still missing here.
- what is left to do: one sentence with the current state and the pointer to the "What to send" table.

### Raw logs named by the v2 package absent; SHA256SUMS list missing files / stale hashes
- original severity: Medium
- verdict: NOT ADDRESSED
- now: D/send-v2-20261114: `sha256sum -c SHA256SUMS` still 30 missing + CHECKS.md and NOTES-FOR-OPERATOR.md FAILED; logs/ holds only SHA256SUMS(-binaries); NOTES still cites logs/run-l2cap-p123-1.log. The directory is now marked superseded, which lowers the impact, but the SHA256SUMS were not corrected. The new review-fixes-20261115 has no checksum file at all; its README says "Checked on copy in the raw guest logs" and "Left in the work area" only extracts (evidence/*.txt) are in the repo, and says "(The KCSAN counts were not re-read in the raw logs.)".
- what is left to do: nothing required for the superseded dir (or drop its SHA256SUMS); for review-fixes-20261115 add a SHA256SUMS of what is there.

### NOTES-FOR-OPERATOR names an internal "task brief"; BRIEF's D1/D2 gloss
- original severity: Low
- verdict: NOT ADDRESSED
- now: D/send-v2-20261114/NOTES-FOR-OPERATOR.md:14 "**Label mix-up in the task brief:** the brief calls D1 ..."; BRIEF.md:234 still "D1/D2 (CO-02 v2: -EBUSY on a live link, -ECONNABORTED only when nothing holds it)" (D1 in followups.md is timing/label).
- what is left to do: reword BRIEF.md:234 ("D2 ...; D1's label v2 done").

### Identifier elision "…"
- original severity: Low
- verdict: NOT ADDRESSED (and spread)
- now: D/log.md:452 "cold boot `257d1599…`", :761 "`148564f5…c94f3d`"; D/send-v2-20261114/CHECKS.md:25 "…/bluetooth.git"; README.md:158 "contributions/CO-02-…"; docs/STATUS.md:13 "contributions/CO-02-…/review-fixes-20261115/" (NEW, in the newly written text); docs/issues.md:918; rd-2026-11-14.md:87.
- what is left to do: write the full path in STATUS.md:13 at least.

### Dossier README links reviews/2026-11-12T1508Z... relative to the dossier
- original severity: Low
- verdict: NOT ADDRESSED
- now: D/README.md:10 "(`reviews/2026-11-12T1508Z-upstream-contributions-status.md`)"; D/reviews/ still holds only 2026-10-22 files.
- what is left to do: prefix `../../`.

### EX-067..074 vs EX-073 in log; run windows
- original severity: Low
- verdict: NOT ADDRESSED (unchanged, cosmetic)
- now: D/log.md:451 "exhibits `EX-067` to `EX-073`"; D/README.md:31 "EX-067 to EX-074"; README.md:157 "10-23 to 10-29" vs cover "23 to 25 October".
- what is left to do: nothing essential.

## Consistency of the new package, as asked
- Names the same current package: contributions/README.md:45 (table), BRIEF.md:189-190, docs/STATUS.md:9-14, D/send-v2-review-fixes-20261114/SUPERSEDED.md all say: 1/2 + non-sleeping 2/2 (review-fixes-20261115/patches/alt-2of2/), mismatch patch later alone (patches/standalone-3/). NOT the same: contributions/README.md:82 and docs/STATUS.md:52 (index/submission rows; name send-v2-20261114 or nothing), README.md:150-157, D/README.md, D/log.md, send-v2-20261114/SUPERSEDED.md (names the superseded dir).
- review-fixes-20261115 README vs files: README section headings match files (analysis/, evidence/, msg/, patches/{alt-2of2 (2 patches), main-v2 (cover+3), standalone-3 (1), wentao-then-v2 (2)}, test-only/{bluez 17, kernel on-alt/on-base 3 each}); the review file ../../../reviews/2026-11-15T0300Z-submitted-status-review-checks.md exists; alt-2of2 2/2 uses `work_busy(...) & WORK_BUSY_RUNNING` and READ_ONCE/WRITE_ONCE, no `cancel_delayed_work_sync`; main-v2 patch 2 message says "The wait sleeps with hdev->lock held" (README: "drop 'the wait is safe'" matches). No checksums in the directory.

## New defects introduced by the changes
1. **msg/cover-alt.txt is a 3-patch cover for a 2-patch candidate** (Medium). review-fixes-20261115/msg/cover-alt.txt differs from cover-main.txt in only 3 lines (patch 2 description and "without the second check"); it still says line 9 "Patch 3 keeps the parameters ...", "sco-tester, 35 cases without the series 31 passed, with patches 1 and 2 33, with all three 35", the failing-case list "(patch 3)", "Changes in v2: v1 patches 2 and 3 are one patch, so that no commit leaves the race open; ... - Patch 3 is new." But the candidate is alt-2of2 (2 patches) with patch 3 sent later alone, and the 31/33/35 numbers were measured on the sleeping 2/2, not alt (README measures alt as 35 pass, 2 fail in a 44-case run). The README's "a new cover to do" covers this only implicitly. Also msg/ contains cover-alt.txt but patches/alt-2of2/ has no cover patch file.
2. **alt-2of2 patch 2 already carries a stable trailer** `Cc: stable@vger.kernel.org # see patch description, needs "Bluetooth: hci_conn: hold ..."` (patches/alt-2of2/v2-0002...:81) while README.md section 6 says the trailer form is "the operator's call" and the table lists "operator: the stable trailer form" (Low). The same non-standard comment form is in main-v2 and wentao-then-v2.
3. **New "CO-02-…" elision** in docs/STATUS.md:13 (Low, see above).
4. The 11-14 claim "not new" about the lock cycle is withdrawn in review-fixes-20261115/README.md section 1, but still stands in superseded dirs (send-v2-review-fixes-20261114/cancel-sync-analysis.txt, README "Audits"); covered by SUPERSEDED.md, acceptable.

---

# Part: co-a

## Recheck co-a against main a8d0eb45 (paths relative to contributions/ in main)
Files of my dossiers changed on main: README.md (new "What to send" table, lines 19-52), CO-04/send-20261114/SUPERSEDED.md, CO-05/send-20261114/SUPERSEDED.md, CO-11/ubuntu/ready-20261102/SUPERSEDED.md. Nothing else in CO-01,03-14 or rd-2026-11-14.md changed.

Table check: CO-04 row (README.md:39) names review-fixes-20261114/patch/ and patch-bare/ - both exist with the 0001 patch; replaced dir send-20261114/patch/ exists and send-20261114/SUPERSEDED.md exists. CO-05 row (:40) names review-fixes-20261114/ - exists with variant-A-with-fixes/, variant-B-without-fixes/, cover-body.txt; send-20261114/SUPERSEDED.md exists. CO-12 row (:46) send-20261114/ exists with patch/0001; no replaced dir (none claimed). Bundle row (:50 area, CO-11a/CO-03/CO-37 5.72/CO-40) names ubuntu-bluez-5.72-0ubuntu5.9-bundle/ (exists, with deliver/, patches/) and ready-20261114/ (exists); replaced CO-11 ubuntu/ready-20261102/ carries SUPERSEDED.md. CO-03 and CO-14 have no own row (CO-03 only inside the bundle row; CO-14 not listed, fix is not "ready").

### CO-04/CO-05: review-fixes-20261114 supersedes the send package, but no index, README or rd points to it
- original severity: Medium
- verdict: PARTLY
- now: FIXED in contributions/README.md:39-40 (table names review-fixes-20261114/ and lists the old dir as "it replaces") and CO-04/send-20261114/SUPERSEDED.md:1 ("Send from ../review-fixes-20261114/patch/ instead"), CO-05/send-20261114/SUPERSEDED.md:1. NOT fixed: CO-04/send-20261114/README.md:4 still "The send file is `patch/0001-…`" (no pointer in the README itself); CO-04/README.md and CO-05/README.md and the index rows (README.md:84-85) still name only send-20261114/; rd-2026-11-14.md rows unchanged.
- what is left to do: add a one-line pointer in the two dossier READMEs and the index rows (the table is the only route now).

### CO-04/CO-05 (and CO-12): send packages have no NOTES-FOR-OPERATOR.md
- original severity: Low
- verdict: NOT ADDRESSED
- now: `ls` of CO-04/send-20261114, CO-04/review-fixes-20261114, CO-05/send-20261114, CO-05/review-fixes-20261114, CO-12/send-20261114: no NOTES-FOR-OPERATOR.md. README.md:19-30 says CO-35 has one ("with its NOTES-FOR-OPERATOR.md") but not these; the operator decisions for CO-04/05/12 appear only in the table's last column.
- what is left to do: add the notes file or state in the table that the last column is the notes.

### CO-04/CO-05 dossier README front pages still show the 10-29 state
- original severity: Low
- verdict: NOT ADDRESSED
- now: CO-04/README.md:3 "State (2026-10-29) ... on bluetooth-next `1081a6ef8f1e0`"; CO-05/README.md:9 same; CO-04/log.md has no 11-14 entry.
- what is left to do: add the 11-14 state line and a log entry.

### send-20261114/README uses "…" in a path
- original severity: Low
- verdict: NOT ADDRESSED
- now: CO-04/send-20261114/README.md:4 "The send file is `patch/0001-…`".
- what is left to do: write the file name in full.

### CO-09: banner says "done", the page body still says "State: waiting" and "Until then"
- original severity: Medium
- verdict: NOT ADDRESSED
- now: CO-09/README.md:3 banner "done"; :17 "**State:** waiting. ..."; the "Until then" and "Next: Watch each new linux-hwe-7.0 upload" sections unchanged.
- what is left to do: mark the body as history or rewrite it.

### CO-09 banner: boot time 22:57 vs 22:55 elsewhere, and a command with "…"
- original severity: Low
- verdict: NOT ADDRESSED
- now: CO-09/README.md:5 "22:57"; :7 "control `… 0cf3 e300`".
- what is left to do: 22:55 and the full command.

### CO-11 front page points at the 11-02 package ...
- original severity: Medium
- verdict: WORSE
- now: CO-11/README.md:6 still "the filing package is `ubuntu/ready-20261102/`" and :11-17 names the standalone debdiff as ready to file; but main now has CO-11/ubuntu/ready-20261102/SUPERSEDED.md ("Send from ../../../ubuntu-bluez-5.72-0ubuntu5.9-bundle/ instead"). The dossier's front page and its index row (README.md:91) therefore point the operator to a directory that declares itself superseded; table row (README.md:50 area) is right.
- what is left to do: update CO-11/README.md banner and index row to point to the bundle and ready-20261114/.

### CO-03 front page: "operator installs / laptop test" and "five commits" lag behind ...
- original severity: Medium
- verdict: NOT ADDRESSED
- now: CO-03/README.md:3 "State (2026-10-31) ... waiting for the operator's test"; README.md:83 index row still "the operator's laptop test ... the operator installs". CO-03 has no own row in the table (only inside the bundle row), and nothing says the BT-7 fixes are not in the bundle.
- what is left to do: update the README and index row (staged 11-13, three-patch candidate, bundle without BT-7).

### CO-03 "0/70 → 70/70" quoted without saying what is counted
- original severity: Low
- verdict: NOT ADDRESSED
- now: README.md:83 and CO-03/README.md:11 unchanged.
- what is left to do: add "pass".

### Index row CO-07 says the six commits are "not built"
- original severity: Low
- verdict: NOT ADDRESSED
- now: README.md:87 still "(not built)"; CO-07/README.md:9 "State: idea."
- what is left to do: update.

### Old "State:" lines left under "Current state" banners (CO-01, CO-06, CO-07, CO-08, CO-10)
- original severity: Low
- verdict: NOT ADDRESSED
- now: CO-01/README.md:9, CO-06/README.md:9, CO-07/README.md:9 unchanged.
- what is left to do: mark as history.

### CO-14, CO-04, CO-05, CO-12 state words not updated in the index and rd table
- original severity: Low
- verdict: NOT ADDRESSED
- now: README.md:94 (CO-14 "idea; ..."), rd-2026-11-14.md:27,29 unchanged ("reproduced; draft clamp", "idea"). The new table gives the send state for CO-04/05/12 but CO-14 is absent from it.
- what is left to do: change the CO-14 state, say the rd table is the morning snapshot.

### SHA256SUMS in send/fix folders list files that are not in the repository
- original severity: Low
- verdict: NOT ADDRESSED
- now: `sha256sum -c` in main on CO-12/send-20261114 still reports the same missing files (59 non-OK lines); CO-04, CO-05, CO-14 unchanged.
- what is left to do: regenerate or note.

### CO-14: one checksum mismatch, disclosed only in the README
- original severity: Low
- verdict: NOT ADDRESSED
- now: unchanged.
- what is left to do: name the file in the README.

### mgmt-tester case count: 515 (CO-14) vs 526 (CO-04/05)
- original severity: Low (needs-check)
- verdict: NOT ADDRESSED
- now: CO-14/fix-20261114/RESULTS.md unchanged.
- what is left to do: state which binary.

### "…" elision in identifiers and paths in authored files
- original severity: Low
- verdict: NOT ADDRESSED
- now: CO-04/send-20261114/README.md:4, CO-09/README.md:7, CO-14/README.md:37 unchanged; CO-07/build-20261114/README.md:12 unchanged. New table (README.md:19-52) writes all paths in full.
- what is left to do: spell out.

### CO-01 refs: patchwork cover id 14157860 out of sequence
- original severity: Low (needs-check)
- verdict: NOT ADDRESSED
- now: CO-01/refs.md:4,7 unchanged.
- what is left to do: query patchwork.

## New defects introduced by the changes
- README.md:21-22 says "every package's older directory carries a 'superseded' line at its top". The marker is a separate SUPERSEDED.md file; the replaced directories' own README.md (e.g. CO-04/send-20261114/README.md:1, CO-05/send-20261114/README.md:1) still start with the old title and no superseded line, so a reader opening the README first does not see it. Low.
- CO-11/ubuntu/ready-20261102/SUPERSEDED.md mentions "`<AUTHOR-EMAIL>` placeholders" that remain in the old debdiffs (bluez_5.85-4ubuntu0.4_5.85-4ubuntu0.5.debdiff, bluez_5.87-4_..., bluez_5.87-5_...: grep finds them); acceptable only because the directory is marked unsent, but the debdiffs there carry no per-file marker. Low.
- CO-11/README.md still names the superseded directory as the filing package (see WORSE above). Low-Medium.
- README.md:41-45 table claims "Each package carries no Signed-off-by"; CO-12/patch/draft-2026-11-01 (not the send dir) still has one, so the sentence holds only for the listed directories. Low.

---

# Part: co-b

## Recheck co-b against main a8d0eb45 (checkout: a checkout of main; paths below are relative to it)
Dossier files of CO-19/20/21/23/25/27/28/30/34/35 are unchanged on main except the added SUPERSEDED.md files (`git diff --stat 162d3b9~1 HEAD -- contributions` shows no other change in them), plus new dir CO-35 review-fixes-20261114/.

### "What to send" table: rows for my dossiers vs the directories (new check)
- verdict: PARTLY (rows name existing dirs; two rows hold less than they say; one claim false)
- now: contributions/README.md:41 CO-35 `review-fixes-20261114/` "(with its NOTES-FOR-OPERATOR.md)": the dir exists and has NOTES-FOR-OPERATOR.md, but holds only the reduced-prerequisite patches (reduced/<line>/), TASK1-4 notes, scripts, logs. It has NO request mail, SCI request or cover letters, and no full patches. Those stay in `send-20261114/mail/`, whose SUPERSEDED.md says "Send from `../review-fixes-20261114/` instead". Its own README: "the full prerequisite with the exception request (the current package), or the reduced one (this folder)". So the superseded dir is still the only place with the mails.
- :43 CO-21 `review-fixes-20261114/` exists: 0000-cover-letter.patch + two patches (no NOTES-FOR-OPERATOR.md, no recipients.txt; those, with the Cc-stable decision, remain only in the superseded send-20261114/).
- :44 CO-20 `patch1-standalone-20261114/` exists: one patch, NOTES.md; no cover, no recipients (in superseded send-20261114/).
- :47 CO-23 `patch/send-20261114/` exists with mails/, NOTES-FOR-OPERATOR.md; :51 CO-30 `rfc-20261114/` exists. No row for CO-19/25/27/28/34 (correct: not to send / done).
- SUPERSEDED.md present: CO-20/send-20261114, CO-21/send-20261114, CO-23/patch/send, CO-23/patch/send-20261101-draft, CO-35/send-20261114 (all say what to use instead; checked each text). Absent: CO-35 `send/`, `send-20261101-draft/`, `send-20261102/` (older, but contributions/README.md:22 says "every package's older directory carries a 'superseded' line"), CO-21 `patches-20261101/`.
- what is left to do: for CO-35 either put the request/cover mails into review-fixes (or say they are still in send-20261114/ and make its SUPERSEDED.md say so); give CO-20/CO-21 replacement dirs their recipients/notes or point to the old files; soften "every" at README.md:22.

### CO-21: index and operator notes point at a send package that its own review replaced
- original severity: High
- verdict: PARTLY
- now: FIXED in the new table, contributions/README.md:43 and send-20261114/SUPERSEDED.md ("Send from `../review-fixes-20261114/` instead"). NOT ADDRESSED: the dossier index row contributions/README.md:101 still "2026-11-14: send package ready, nothing sent (`CO-21-…/send-20261114/`)"; rd-2026-11-14.md:76 unchanged; CO-21 README.md has no mention of send-20261114/review-fixes (grep: none); send-20261114/NOTES-FOR-OPERATOR.md unchanged (no pointer inside, only the SUPERSEDED.md beside it).
- what is left to do: change README.md:101 (and the CO-21 dossier README) to review-fixes-20261114.

### CO-20: index says two-patch send package ready, but patch 2 is held
- original severity: High
- verdict: PARTLY
- now: FIXED in table :44 ("patch 1 alone ... patch 2 held") and send-20261114/SUPERSEDED.md. NOT ADDRESSED: contributions/README.md:100 still "send package ready, nothing sent (`CO-20-…/send-20261114/`): two btusb patches"; rd:77 unchanged; CO-20 README.md no mention.
- what is left to do: update README.md:100 and the CO-20 README.

### CO-23: superseded 10-29 send package (working send.sh) not marked superseded
- original severity: Medium
- verdict: PARTLY
- now: patch/send/SUPERSEDED.md and patch/send-20261101-draft/SUPERSEDED.md added ("Send from `../send-20261114/` instead"); table :47. Remaining: patch/send/send.sh still present and still sha-checks and sends the old pair (`ls patch/send`: ... SUPERSEDED.md send.sh), patch/send/README.md:1 unchanged ("The files to send, exactly as they stand"); CO-23 README.md:6 still "send package ready (`patch/send/README.md`)"; patch/send-20261114/README.md:12 still "Recipients, route and the reviewer questions are as in `../send/README.md`" (now a superseded dir).
- what is left to do: point CO-23 README.md:6 and send-20261114/README.md:12 at send-20261114; consider removing or disabling send.sh.

### CO-23: operator notes' list of "still wrong" BT-6/U22 records already fixed
- original severity: Low
- verdict: NOT ADDRESSED
- now: contributions/CO-23-one-off-events/patch/send-20261114/NOTES-FOR-OPERATOR.md:44,48 "lines still wrong ... **Still wrong or stale:**" unchanged.
- what is left to do: mark the list done.

### CO-25: STATUS names the first reply draft, stops at v3
- original severity: Medium
- verdict: NOT ADDRESSED
- now: docs/STATUS.md:50 "A clarifying answer is drafted (`drafts/reply-1-zijun-hu.eml`), not sent ... **2026-11-02:** reply draft v3"; README says v4.
- what is left to do: name drafts/reply-1-zijun-hu-v4.eml.

### CO-25: pinned commits not resolvable in the repo
- original severity: Low
- verdict: NOT ADDRESSED
- now: contributions/CO-25-qualcomm-rom-report/README.md:12 and send/report.eml:105 unchanged (needs-check stays).
- what is left to do: say where 4b56813d311d / cb645f5 live.

### CO-25: evidence page uses project-internal labels
- original severity: Low
- verdict: NOT ADDRESSED
- now: contributions/CO-25-qualcomm-rom-report/EVIDENCE.md:11 "[EX-053](…)" unchanged.
- what is left to do: nothing required unless the page is meant to stand alone.

### CO-30: base path does not exist; 10-21 vs 11-01 prototype; base may predate CO-02 fixes
- original severity: Medium
- verdict: WORSE
- now: rfc-20261114/README.md:3 "Base: CO-02 v2 (`../co02-v2/kernel/` ..." unchanged, dir still absent; :10 "10-21 prototype" vs dossier README.md:11 "11-01 prototype" unchanged. The base question is now answered against it: contributions/CO-02-…/send-v2-review-fixes-20261114/SUPERSEDED.md "Its 2/2 waits for the disconnect worker under `hdev->lock` and can deadlock ... hangs 3 of 3 (2026-11-15)"; CHECKS-CO30.md:3-4 tested on `p123` = `6ab80e175065` (that v2). Table :51 says only "waits for CO-02 v2".
- what is left to do: rebase and re-test the RFC on the non-sleeping 2/2 (review-fixes-20261115/patches/alt-2of2/), fix the base path, say so in :51.

### CO-30: SHA256SUMS lists files that fail or are not shipped
- original severity: Low
- verdict: NOT ADDRESSED
- now: rfc-20261114/SHA256SUMS, logs-SHA256SUMS, binaries-SHA256SUMS unchanged (CHECKS-CO30.md hash mismatch, missing logs).
- what is left to do: regenerate or annotate.

### CO-35: send-20261114 has no NOTES-FOR-OPERATOR.md, keeps Signed-off-by
- original severity: Medium
- verdict: PARTLY
- now: notes exist now: CO-35 review-fixes-20261114/NOTES-FOR-OPERATOR.md (covers CO-35 + CO-22; decisions listed). Signed-off-by: reduced/6.12.y/0002-…patch:28, reduced/6.18.y/0002:24, reduced/6.6.y/0002:24 carry "Signed-off-by: Iaroslav Voitovych <…>" (patch 1 does not; notes say add yours); the unreduced send-20261114 patches still carry it. Yet contributions/README.md:23-24 says "Each package carries no Signed-off-by".
- what is left to do: either state the stable-backport exception at README.md:23 or strip his line as elsewhere.

### CO-35: dossier README and BRIEF still describe the 11-02 / 10-28 package
- original severity: Medium
- verdict: PARTLY
- now: FIXED: BRIEF.md:104 "CO-35 (the package named in `contributions/README.md`, \"What to send\")"; docs/STATUS.md BT-10 row now ends "replaced by `review-fixes-20261114/`". NOT ADDRESSED: contributions/CO-35-…/README.md:5 "the final package is `send-20261102/`" and :11 "`send/` holds four mails ... 7.2.y"; docs/issues.md:889-891 "an option-2 request for 7.3.y and 7.2.y ... (`send-20261102/`); nothing sent as of 11-12"; contributions/README.md:80 row text unchanged; CO-35 log.md still ends 11-02.
- what is left to do: update CO-35 README header and issues.md:889.

### README.md: "an L2CAP hang that every released kernel has" overstates CO-35
- original severity: Medium
- verdict: FIXED
- now: README.md:178-180 "an L2CAP deferred-accept hang that affects the 7.3, 6.18, 6.12 and 6.6 lines, and the older lines only with the non-default `enable_ecred` parameter (`CO-35`)".
- what is left to do: nothing.

### CO-27: README says GNOME tracker not searched; U13 still routes GNOME report to CO-27
- original severity: Low
- verdict: NOT ADDRESSED
- now: contributions/CO-27-…/README.md:52 "4. The BlueZ mailing list and GNOME's tracker are not searched yet."; docs/STATUS.md:114 (U13) "a GNOME report for the silent failure (`contributions/CO-27-le-only-pairing-u13/`)".
- what is left to do: point at CO-42.

### CO-28: stale tail; BRIEF says "CO-28 waits"
- original severity: Low
- verdict: PARTLY
- now: BRIEF "CO-28 waits" removed (grep: none). CO-28 README.md:52 "Watch for each review mail. If one appears ..." unchanged; 10-31 vs 10-30 release wording unchanged.
- what is left to do: drop the tail.

### CO-21 review-fixes cover letter has review history / "first draft"
- original severity: Low
- verdict: NOT ADDRESSED
- now: contributions/CO-21-…/review-fixes-20261114/0000-cover-letter.patch:23 "Changes since the first draft: the air mode is stored before ..." — and this dir is now the one the table says to send.
- what is left to do: remove that paragraph before the send.

### Index-wide "…" elision
- original severity: Low
- verdict: WORSE
- now: counts of `CO-nn-…` on main (was): README.md 1 (0), contributions/README.md 3 (3), rd 10 (10), docs/STATUS.md 13 (10), docs/issues.md 5 (3), BRIEF 0. New in changed text: STATUS "`contributions/CO-43-…/send-bt24-bt25-20261114/`" (issues.md/STATUS), "`contributions/CO-02-…/review-fixes-20261115/`" (README.md), "`eacbb61`…`ac71f16`", "srcversion `66D38200…`". CO-20 README.md:55 "`257d1599…`" unchanged. The new table itself writes every path in full (good).
- what is left to do: expand the new `CO-nn-…` paths; the old ones too.

### CO-34: send README and tsv row not brought to sent state
- original severity: Low
- verdict: NOT ADDRESSED
- now: contributions/CO-34-…/patch/send/README.md:3 "**One mail, BlueZ, not sent.**"; docs/sent-mails.tsv:27 row has date "2026-10-28" only; docs/STATUS.md:51 still "no BlueZ release yet" in the same row.
- what is left to do: nothing urgent.

### CO-35 send-20261114: SHA256SUMS fails
- original severity: Low
- verdict: NOT ADDRESSED
- now: `sha256sum -c` in main: ./apply-check.sh FAILED, ./apply-old.sh FAILED, ./img/bzImage-v6.12.117-base missing. New review-fixes-20261114/SHA256SUMS: verifies clean (no output).
- what is left to do: nothing (the dir is superseded; annotate).

## New defects introduced by the changes
- CO-30's RFC package is built on the CO-02 v2 whose 2/2 the maintainer now says can deadlock (3 of 3); the table row (:51) says "waits for CO-02 v2" with no re-test note, and CO-30 README/rfc README unchanged. (listed above as WORSE)
- contributions/README.md:22 claims "every package's older directory carries a 'superseded' line"; false for CO-35 `send/`, `send-20261102/`, `send-20261101-draft/`, CO-21 `patches-20261101/`.
- contributions/README.md:23 "Each package carries no Signed-off-by" is false for CO-35 (stable backports keep his Signed-off-by in patch 2 of every line, reduced/ and send-20261114/).
- Replacement packages are thinner than the replaced ones: CO-35 review-fixes lacks the mails; CO-20/CO-21 replacements lack recipients/notes (see first block).
- Index rows contributions/README.md:100-101 and rd:76-77 still name the replaced dirs, so the file now contradicts its own table 55 lines above.

---

# Part: co-c

## co-c recheck against main a8d0eb45 (M = a checkout of main)

### CO-43: three different versions of patch A
- original severity: High
- verdict: FIXED (one residue)
- now: M/contributions/CO-43-.../send-20261113/A/SUPERSEDED.md ("Send from ../A-review-fixes-20261114/ instead"); M/contributions/README.md "What to send" row "CO-43 A ... replaces .../A/ ... to make (A/send-commands.txt names the old file)"; M/docs/STATUS.md BT-20 "A-review-fixes-20261114/ ... it replaces A/"; BRIEF.md:185-187 "Send commands and a checked dry run exist only for CO-44 and CO-43 E". send-series 0001 still has the old text (grep -c ratelimited = 0) but HELD.md says 0001 is replaced.
- what is left to do: A-review-fixes still has no NOTES-FOR-OPERATOR/recipients/send-commands (table says "to make"); A/NOTES-FOR-OPERATOR.md still says "Done 2026-11-14 ... Result: OK" (covered only by the SUPERSEDED marker).

### CO-43 send-series: no README/NOTES; D v2 "closes the system path" vs "held"
- original severity: High
- verdict: PARTLY
- now: fixed: M/contributions/CO-43-.../send-series-20261114/HELD.md ("D v2 registers .reset_resume, which suppresses needs_binding ... held"); README "What to send" row "CO-43 B2, D v2 ... held"; STATUS BT-18/19 "held"; BRIEF.md:192 "Held". Remaining: STATUS BT-18 evidence column still says "the system path unchanged by reading only"; patch 3's message and the series cover letter still claim the system path stays as is (files unchanged, now covered by HELD.md); CO-43 README open item 0 unchanged but consistent.
- what is left to do: reword the STATUS BT-18 evidence cell; nothing needed in the patches while held.

### CO-43: patch 2 (B2) precedes patch 3 (D v2); two overlapping BT-24/25 packages
- original severity: Medium
- verdict: FIXED
- now: HELD.md lists 0002/0003 as held and "0004 and 0005 ... replaced by ../send-bt24-bt25-20261114/"; README table row "CO-43 BT-24/25 ... replaces patches 4-5 of send-series".
- what is left to do: nothing

### CO-43 dossier README / register row / issues.md stale (five patches, BT-24/25 "no fix yet")
- original severity: Medium
- verdict: PARTLY
- now: fixed: issues.md:1168 "Status 2026-11-14: reproduced in emulation and fixed", :1189 BT-25 "Status 2026-11-14: fixed"; README table lists send-series/send-bt24-bt25. Remaining: issues.md:1212 BT-25 still "**Next:** a kmemleak run in emulation ... then a fix together with BT-24" (the 11-13 text kept under the new status, which says "the text below is the 11-13 state" only for BT-24); issues.md:1099 BT-18 still "Status 2026-11-13 ... fix candidate CO-43 D", :1116 BT-19 "fix candidate CO-43 B", :1136 BT-20 "fix candidate CO-43 A", :1142 BT-21, :1157 BT-23 (no 11-14 status lines); STATUS BT-17 still "CO-43 (btusb, five patches)" and issues.md:1093 "patch candidates in CO-43 (five)"; CO-43/README.md:28 "State (2026-11-13): five patches" and register row (README.md CO-43 row) unchanged. kmemleak counts: issues.md BT-25 now quotes the bt24-bt25 set (3/3/1 ...) while STATUS BT-25 says "11 of 12" (other set) - still unreconciled.
- what is left to do: add 11-14 status lines to BT-18..BT-21/BT-23 sections, delete BT-25's stale Next, update the CO-43 README state block.

### rd-2026-11-14.md table contradicts its own results
- original severity: Medium
- verdict: NOT ADDRESSED
- now: M/contributions/rd-2026-11-14.md (file unchanged): "CO-39 | ... bot run from 11-08 unfinished", "CO-41 | ... idea, confirmed in source", "CO-38 | ... package ready 11-02", "CO-43 | ... B blocked by its counterexample; D not as a fix". The new "What to send" table in contributions/README.md supersedes it in practice, but rd does not say so.
- what is left to do: mark the rd table as the morning snapshot or update it.

### contributions/README.md rows stale (CO-38, CO-39, CO-37, CO-40, CO-41)
- original severity: Medium
- verdict: PARTLY
- now: fixed: CO-37 row (README.md:~116 "in BlueZ 5.88; corrected 2026-11-15, this said 'not released'"). Not fixed: CO-38 row :117 "likely a flake, not shown" (CHECKS §5 says settled); CO-39 row :130 "base side still to read" and the new table row 49 "the bot's base side still to read" (README of the package says finished 11-14); CO-40 row :131 "bundle with the other 5.72 updates ... or file alone"; CO-41 row :132 "idea, confirmed in source" (the new table row for CO-41 says ready).
- what is left to do: update the CO-38, CO-39, CO-40, CO-41 index rows and the CO-39 table cell.

### Dossier READMEs of CO-38/39/41/40/37 frozen, no link to send-20261114
- original severity: Medium
- verdict: NOT ADDRESSED
- now: grep -c 'send-20261114|bundle' in CO-38, CO-39, CO-41, CO-37 READMEs = 0 (CO-40 = 1); files unchanged (git diff empty). The central table in contributions/README.md now supplies the pointer instead.
- what is left to do: one "see send-20261114" line per README, or accept the table as the pointer.

### CO-38 send-20261114: README "not shown" vs CHECKS; no NOTES; old and split BlueZ series
- original severity: Medium
- verdict: PARTLY
- now: fixed: M/contributions/CO-38-.../send-20261114/patch/bluez/SUPERSEDED.md ("Send from ../../../bluez-split-20261114/series-a/ instead"); README table row CO-38 names kernel patch/ and series-a/ and what it replaces. Remaining: send-20261114/README.md:14-16 still "2 of 3 ... not **shown** to be [a flake]" vs CHECKS §5 "a flake"; no NOTES-FOR-OPERATOR.md in send-20261114 or bluez-split-20261114; README says CHECKS.md/mk-kernel-patch.sh example.com unchanged.
- what is left to do: fix the README sentence; add a NOTES file.

### Placeholder `<AUTHOR-EMAIL>` committed in authored mails
- original severity: Medium
- verdict: PARTLY
- now: files unchanged (git grep -l AUTHOR-EMAIL in main: CO-38 send-20261102 x6, CO-37 work/patches/5.72-3-20261102 x3 and master-final-6-20261102 x6, plus CO-11 ready-20261102). Each of those directories now has SUPERSEDED.md saying "its <AUTHOR-EMAIL> placeholders were never filled in, because nothing is sent from here", and CO-37 send-20261114/README.md:51 "Left in the work area" is now true only in spirit (they are on main but marked). NEW/missed: M/contributions/CO-38-.../send-20261114/bluez-cover-body.txt:1 "From: Iaroslav Voitovych <AUTHOR-EMAIL>" sits inside the CURRENT package directory and is not covered by any SUPERSEDED marker; not named in the README.
- what is left to do: fix or remove send-20261114/bluez-cover-body.txt (or state it is a template); correct CO-37 README.md:51 wording.

### Ubuntu bundle: BUNDLE.md placeholder trailer vs real address; SHA256SUMS
- original severity: Medium
- verdict: NOT ADDRESSED
- now: M/contributions/ubuntu-bluez-5.72-0ubuntu5.9-bundle/BUNDLE.md:17 "the changelog trailer address is a placeholder to replace before upload" and :55 "The changelog trailer uses a placeholder address"; changelog-entry.txt still carries the real address. Bundle dir unchanged on main.
- what is left to do: reword BUNDLE.md lines 17 and 55; regenerate SHA256SUMS.

### "…" elision in identifiers and paths
- original severity: Low
- verdict: NOT ADDRESSED (and spread to new text)
- now: original places unchanged (CO-44 NOTES 2 hits, A-review-fixes README, results READMEs, CO-36, X1, bundle LP-…); new text adds `contributions/CO-43-…/send-bt24-bt25-20261114/` in docs/issues.md:1171,1189 and `CO-43-…/` in STATUS BT-18/20 rows. The new "What to send" table itself uses full paths (good).
- what is left to do: write the full directory names in the new issues/STATUS text.

### CO-36: README Next step 4 stale; "111 tests"
- original severity: Low
- verdict: NOT ADDRESSED
- now: M/contributions/CO-36-.../README.md:184 "fix variants through the same tests next (Phase 1)"; README.md:"test plan of 111 tests" unchanged.
- what is left to do: update Next; check the 111/113.

### CO-39: notes cite missing cover-letter; heading says a bot run is open
- original severity: Low
- verdict: NOT ADDRESSED
- now: CO-39-.../send-20261114/README.md:1 "one bot run still to read"; NOTES-FOR-OPERATOR.md:8 "the v3 cover letter file still has placeholders".
- what is left to do: edit both lines.

### BRIEF hand-off lists lanes 3/4 as running; CO-39/41 missing from ready list
- original severity: Low
- verdict: PARTLY
- now: fixed: BRIEF.md:185-186 "Patch ready: CO-44, CO-38, CO-43 E, A and BT-24/25, CO-04, CO-22, CO-21, CO-20 patch 1, CO-39, CO-41; ... CO-12, CO-23 and CO-37 with operator decisions open". Remaining: BRIEF.md:210-211 "3 CO-38's BlueZ TestFunctional failures (2 of 3 patched; flake not shown) ... 4 CO-41 and CO-39 (no report yet)" still in the "Lanes still running" bullet.
- what is left to do: drop or update that bullet.

### CO-44: README names patch/ as "the patch"; differs from send package
- original severity: Low
- verdict: NOT ADDRESSED
- now: CO-44 README unchanged; patch/ not marked superseded; the new table names send-20261113/ as the package.
- what is left to do: one line in README.

## Follow-up: docs/issues.md 1000-1450

### BT-24 and BT-25 sections "not reproduced / Next: kmemleak"
- original severity: High
- verdict: PARTLY
- now: fixed: docs/issues.md:1168 and :1189 new 11-14 status blocks. Remaining: :1212 BT-25 "Next: a kmemleak run in emulation ... then a fix together with BT-24"; BT-24's 11-13 block (line ~1178 "not reproduced; no fix yet") is kept below with the note "the text below is the 11-13 state" (acceptable); BT-25 kmemleak set differs from STATUS BT-25's "11 of 12".
- what is left to do: remove or date-stamp BT-25's Next line.

### BT-18..BT-21, BT-23 sections stop at 11-13
- original severity: Medium
- verdict: NOT ADDRESSED
- now: docs/issues.md:1099, :1116, :1136, :1142, :1157 still "Status 2026-11-13 ... fix candidate CO-43 D / B / A / CO-44 / E"; :1144 still cites `agent-work/bt17-mgmt-timeout/`. STATUS rows were updated (BT-18 "held", BT-20 "A-review-fixes").
- what is left to do: add 11-14 lines to those sections.

### BT-17 "five patches"
- original severity: Low
- verdict: NOT ADDRESSED
- now: docs/issues.md:1093 "patch candidates in CO-43 (five)"; STATUS BT-17 "CO-43 (btusb, five patches)".
- what is left to do: reword.

### U24 / U23 rows
- original severity: Medium (U24), Low (U23)
- verdict: U24 FIXED; U23 NOT ADDRESSED
- now: docs/issues.md:1243 U24 "in BlueZ 5.88; corrected 2026-11-15, this said 'not released'"; STATUS U24 "in BlueZ 5.88, tagged 2026-11-05". U23 row (issues.md:1242, STATUS:124) still gives only "3 of 10 / 2 of 10".
- what is left to do: U23: add CO-37's 10/10 -> 0/10 or a pointer. (Check that STATUS U24's "next to U12's in a later CO-03 package" was also dropped: the new row ends differently; not re-read in full.)

### Elisions / out-of-repo evidence
- original severity: Low
- verdict: NOT ADDRESSED
- now: STATUS:123 (U22) still "heap-use-after-free … a2dp.c:2173"; issues.md screenshot path/hash with "…" and `tmp/ui-screenshots/`, `cache/linux` unchanged.
- what is left to do: as before.

### Coverage of ids
- original severity: Low
- verdict: WITHDRAWN (informational; no defect claimed)
- now: n/a
- what is left to do: nothing

## New defects introduced by the changes
- contributions/README.md "What to send" table, CO-39 row: state cell "the bot's base side still to read" contradicts CO-39/send-20261114/README.md ("finished 11-14") - the new table copied a stale fact.
- contributions/README.md table, CO-11a/CO-03/CO-37 5.72/CO-40 row: "commands: — (filed by the operator on Launchpad)", fine; but the row for CO-38 lists send-20261114/patch/ as the package while send-20261114/bluez-cover-body.txt (placeholder From) remains beside it unmarked.
- SUPERSEDED.md texts for CO-11/CO-37/CO-38 say the placeholders "were never filled in, because nothing is sent from here", yet CO-37/send-20261114/README.md:51 still says those mails "stay in the work area" (they are on main).
- New `CO-43-…/` elisions in docs/issues.md:1171,1189 and STATUS BT-18/BT-20 rows (project rule).
- STATUS BT-18 row now says both "the system path unchanged by reading only" (evidence column) and "held ... breaks the system-resume rebind" (next column).
- Paths all exist: every directory named in the table rows for CO-44, CO-38, CO-43 E/A/BT-24-25/held, CO-37, CO-39, CO-41 and the bundle exists on main with the patch files; only the "commands" gaps stated in the table are real.

---

# Part: co-register

## co-register recheck against main (a8d0eb45)
Paths below are relative to the main checkout. Line numbers are main's.

### CO-37 row says U24's fix is "not released"
- original severity: Medium
- verdict: FIXED
- now: contributions/README.md:118 "U24 is fixed upstream by `7e3212fa233e` (in BlueZ 5.88; corrected 2026-11-15, this said "not released")". (The 11-12 review text is a dated snapshot and is unchanged.)
- what is left to do: nothing

### CO-38 and CO-39 rows carry open points that rd/lane results say are closed
- original severity: Low
- verdict: NOT ADDRESSED
- now: contributions/README.md:117 "likely a flake, not shown"; :130 "base side still to read"; also the new table row README.md:49 (CO-39) "the bot's base side still to read"; BRIEF.md:210 "CO-38's BlueZ TestFunctional failures (2 of 3 patched; flake not shown)" and "CO-41 and CO-39 (no report yet)". rd-2026-11-14.md Results still say the opposite.
- what is left to do: update the rows, the new table row and the BRIEF "lanes still running" bullet (also: BRIEF.md still says CVE-2026-105460 "not yet checked on 5.72", rd says affects 5.72).

### CO-07/CO-34 rows not updated by the 11-14 results
- original severity: Low
- verdict: NOT ADDRESSED
- now: contributions/README.md:87 "(not built)" (CO-07); :114 "release tracking" (CO-34); rd-2026-11-14.md:48 says CO-34 "released in 5.88".
- what is left to do: update the two rows.

### rd-2026-11-14.md table stale against its own "Results so far"
- original severity: Low
- verdict: NOT ADDRESSED (file unchanged on main)
- now: contributions/rd-2026-11-14.md:37 "stable request v2 ready since 11-02", :49 "package ready 11-02", :52, :53 "bot run from 11-08 unfinished". It also still names directories the new README table marks as replaced (see new defects).
- what is left to do: mark the table as the 11-14 morning snapshot or update it, and point to the README "What to send" table.

### Register intro: dossier opened "as soon as anything is written"; 13 rows have none
- original severity: Low
- verdict: NOT ADDRESSED
- now: contributions/README.md:157 "Items without a link have no dossier yet. One is opened as soon as anything is written about the item." CO-22 is still a table row ("research-2026-11-01/qca-ids/refresh-20261114/") with no CO-22 directory.
- what is left to do: reword the rule or open CO-22.

### NOTES-FOR-OPERATOR.md claimed for every ready package; five have none
- original severity: Medium
- verdict: PARTLY
- now: fixed: the BRIEF hand-off no longer claims it (grep NOTES in BRIEF.md: no hit; BRIEF.md:180-190 describes the table instead). Remaining: contributions/README.md:23-24 says "The open decisions are in each package's notes and in ../reviews/2026-11-14T1400Z-..." but the current packages of CO-04 (review-fixes-20261114/), CO-05, CO-21, CO-20 (patch1-standalone-20261114/), CO-38, CO-12, CO-22 and CO-02 (review-fixes-20261115/) contain no NOTES-FOR-OPERATOR.md (CO-20's has NOTES.md; find shows NOTES-FOR-OPERATOR.md only in CO-35 review-fixes, CO-23, CO-37, CO-39, CO-41, CO-44, CO-43 E and A(superseded), and the superseded CO-02 send-v2-20261114, CO-20 send-20261114, CO-21 send-20261114).
- what is left to do: say "most packages' notes" or add the files; notes of CO-02/20/21 sit in the replaced directories.

### BRIEF ready-to-send list omits CO-23, CO-37, CO-39, CO-41, CO-12
- original severity: Low
- verdict: FIXED
- now: BRIEF.md:185-186 "Patch ready: CO-44, CO-38, CO-43 E, A and BT-24/25, CO-04, CO-22, CO-21, CO-20 patch 1, CO-39, CO-41; CO-35, CO-05 + CO-26, CO-12, CO-23 and CO-37 with operator decisions open."
- what is left to do: nothing

### CO-03's contents: BT-7 fixes in dossier/reviews vs bundle left out
- original severity: Medium
- verdict: NOT ADDRESSED
- now: contributions/CO-03-bluez-u12-backport/README.md:6 "five commits ...: BT-7, ..."; ubuntu-bluez-5.72-0ubuntu5.9-bundle/BUNDLE.md:23 "The two BT-7 crash fixes ... are **not** in the bundle"; reviews/2026-11-13T0120Z-registers-and-contributions-status.md R9 unchanged. README.md:70 still says the bundle is for CO-03 without that caveat.
- what is left to do: one line on CO-03's README and the bundle row in the table.

### Decisions D1-D14: all open, register wording lets D1/D2/D6 look settled
- original severity: Medium
- verdict: PARTLY
- now: improved: the new table marks open items as operator decisions: README.md:46 "operator: the clamp now, or an RFC first (D5)", :47 "(D3)", :48 "(D3)", CO-04 "(D4)"; CO-02 v2 "operator: the stable trailer form", and STATUS.md:13 / table say the sleeping 2/2 is not to be sent (so D2's packaging is overtaken by a real defect). Remaining: README.md:92 (CO-12 index row) still "the lane recommends the clamp now" against D5's RFC recommendation; README.md:70-72 still presents one Ubuntu upload with CO-37's backports without "D6 open"; the table row for the bundle (README.md:52) has no D6 note; followups.md unchanged ("Nothing on it has been acted on yet").
- what is left to do: add "D6 open" to the bundle row and drop/qualify "recommends the clamp now".

### CO-02 row does not carry the CI's "must be resent" mail
- original severity: Low
- verdict: PARTLY
- now: fixed in STATUS.md:4 "the CI bot's rule makes v2 a resend" and in reviews/2026-11-15T0115Z-submitted-contributions-status.md ("The mirror PR closed on 11-11, but v2 is needed ..."). Unchanged: contributions/README.md:82 "closed by its bot in a sweep ... which is not a review" (no mention of the resend rule or that the 11-12 reading was corrected on 11-13).
- what is left to do: one clause in the CO-02 index row.

### "All twelve" vs "eleven" BlueZ commits
- original severity: Low
- verdict: NOT ADDRESSED
- now: reviews/2026-11-13T0120Z-registers-and-contributions-status.md:257 "**All twelve of our BlueZ commits are in BlueZ 5.88**" and :232 "12 BlueZ commits"; README.md still says eleven.
- what is left to do: add a note that the twelfth is the redundant v2 d84171e6cd68 (or leave: dated snapshot).

### Elided identifiers ("…") in paths
- original severity: Low
- verdict: WORSE
- now: old ones remain: contributions/README.md:100 `CO-20-…/send-20261114/`, :101, :110 `CO-30-…/rfc-20261114/`, `X1…/patch1/`; rd-2026-11-14.md lines 76-123 unchanged. Fixed in the new table itself (full names; scripts/send-table-check.py checks it only for that table). New elisions in text added on 11-15: docs/STATUS.md:13 `CO-02-…/review-fixes-20261115/`, :89, :91 `CO-43-…/send-20261113/A-review-fixes-20261114/`, :92, :94-96, :98-99 (`CO-04-…/send-20261114/circular-count.txt`); reviews/2026-11-15T0115Z-submitted-contributions-status.md:40 `CO-25-…/drafts/reply-1-zijun-hu-v4.eml`, :95 `CO-02-…/send-v2-review-fixes-20261114/`.
- what is left to do: expand them; extend send-table-check.py (or a repo check) to the other 11-15 files.

### Register points to work-area paths outside the repository
- original severity: Low
- verdict: NOT ADDRESSED
- now: contributions/README.md:117 `/root/exp/agent-work/co12-rework-20261101/patches/listfix-on-clamp/`; rd-2026-11-14.md:132 `/root/exp/agent-work/lane5-status-stable-20261114/status/`.
- what is left to do: mark as untracked or drop.

### CO-11a / CO-11b defined only inside one row
- original severity: Low
- verdict: NOT ADDRESSED
- now: README.md:52 new table row "CO-11a, CO-03, CO-37 5.72, CO-40" uses CO-11a; the index row is still "CO-11" with (a)/(b).
- what is left to do: one sentence defining CO-11a/b.

### docs/contributions-roadmap.md internally inconsistent
- original severity: Low
- verdict: NOT ADDRESSED (file unchanged)
- now: docs/contributions-roadmap.md:3 "unchanged in substance", :25 BZ-free row with CO-23, :90 "BZ-free: one crash, no mechanism. Not a contribution until ..."
- what is left to do: fix :90 or say the table row was updated.

### REVIEW-ROUND-2026-11-01.md not marked superseded
- original severity: Low
- verdict: NOT ADDRESSED
- now: file unchanged; line 1-4 "An intermediate round."
- what is left to do: nothing needed beyond a one-line "historical" marker (optional).

### D-table / the three reviews "checked, no contradictions beyond the above"
- original severity: Low (informational)
- verdict: WITHDRAWN as a finding (it was a summary note); its content stands.
- now: n/a
- what is left to do: nothing

## Verification of the new "What to send" table (contributions/README.md:19-53) and scripts/send-table-check.py
- Elision: the table uses full directory names, not `CO-nn-…/` forms (so no expansion was needed); `…` appears nowhere in lines 19-53. The README.md:119-ish `CO-20-…`, `CO-21-…`, `CO-30-…` index-row elisions remain below the table (see above).
- Existence: I extracted every backticked path with a "/" from the "send this", "it replaces" and "commands" columns and tested it in the main tree: all exist (0 missing). send-table-check.py only checks "no …" and existence of such paths (read, not run; its `../reviews/...` tokens resolve against contributions/). It does not check SUPERSEDED.md or agreement with other documents.
- "It replaces" dirs and SUPERSEDED.md: present in 11 of 14 named dirs. Missing: (1) CO-43 BT-24/25 row: replaces `CO-43-btusb-runtime-resume-failure/send-series-20261114/` (patches 4-5) - no SUPERSEDED.md, only HELD.md in it (which explains the split, so defensible, but the README says "every package's older directory carries a 'superseded' line at its top"); (2) CO-04: `CO-04-mesh-test-14888791/send-20261114/patch/` has no SUPERSEDED.md of its own, the parent send-20261114/ has one (OK); (3) CO-02 v2: `CO-02-sco-connect-reuses-closing-link/review-fixes-20261115/patches/main-v2/` has none (it is a subdirectory of the new package, containing the deadlocking 2/2; the table says it replaces it). `send-v2-20261114/` (the older still, which rd and the CO-02 index row name) has SUPERSEDED.md but is not listed in the table's "replaces" column.
- Table vs index rows below it: disagree for every replaced package. Index rows still name the replaced directories as the package: CO-04 and CO-05 (README.md ~91-92 "`send-20261114/`"), CO-21 and CO-20 (`CO-21-…/send-20261114/`, `CO-20-…/send-20261114/`, "two btusb patches" vs table "patch 1 alone, patch 2 held"), CO-35 (`send-20261114/`), CO-23 (`patch/send-20261114` is current: agrees), CO-02 (index row "v2 built ... `send-v2-20261114/`" and "sco-tester 31 -> 35 of 35" vs table "not ready ... its 2/2 can deadlock"). None of these index rows carries a "replaced" pointer to the table.
- Table vs rd-2026-11-14.md: rd (unchanged) names the replaced directories as results (lines 76-90, 113: send-v2-20261114, send-20261114 of CO-20/21/35) and has no pointer to the table; BRIEF.md:171-173 still calls rd "the page of record for today's work" while the table claims to be "the one place that says which directory holds the text to send".
- Table vs BRIEF hand-off (BRIEF.md:180-196): consistent on ready/held/not ready (CO-02 v2 not ready; CO-43 B2/D v2 held; commands only for CO-44 and CO-43 E). BRIEF lists CO-04, CO-22, CO-39, CO-41 as "patch ready" like the table. Stale bullets in the same hand-off remain (BRIEF.md:210).
- Table vs STATUS: consistent on CO-02 (STATUS.md:8-14 sleeping 2/2 not to be sent; alternative in review-fixes-20261115). STATUS.md:91-99 rows name `A-review-fixes-20261114`, `send-bt24-bt25-20261114`, as the table does.
- Table vs reviews/2026-11-15T0115Z-submitted-contributions-status.md: disagree on CO-02. The report (revised 02:45) says the lock cycle is "possible ... Reachability is not settled", names "(a) `[PATCH v2 0/2]`" and the package `send-v2-review-fixes-20261114/` as the v2 package, and lists "a non-sleeping alternative ... if the cycle is reachable" as work in progress; the table and STATUS (later commit 6c5fbab8) say the cycle is real (3 of 3 hangs) and that package is superseded. The report's "Options 1" still says "v2 in layout (a), after the lock question is settled". Also CO-05: report "CO-05 + CO-26 and CO-14 stay held" vs table "ready" (the table's last column does say mesh held for now - OK). CO-39 and CO-12 not covered by the report. No contradiction on CO-25, X1, Hui Peng.
- Table internal: CO-39 "the bot's base side still to read" is stale (rd Results: base side PASS plus a test-hog failure on master).

## New defects introduced by the changes
1. Index rows (contributions/README.md CO-02, CO-04, CO-05, CO-20, CO-21, CO-35) and rd-2026-11-14.md still direct a reader to the replaced directories with no pointer to the new table (the table says it is the one place; the rows below it contradict it). Medium.
2. The 0115 report (revised before commit 6c5fbab8) is stale against STATUS and the table about CO-02's lock cycle and the current package (see above). Medium.
3. New "…" paths in STATUS.md (13, 89, 91, 92, 94-96, 98-99) and in the 0115 report (40, 95); the table's checker covers only the table. Low.
4. README.md:23-24 says the open decisions are in each package's notes; most current packages have no NOTES-FOR-OPERATOR.md. Low.
5. README.md:19-20 claims every older directory carries a "superseded" line: CO-43 `send-series-20261114/` (only HELD.md) and CO-02 `patches/main-v2/` do not. Low.
6. CO-02 v2's current package (review-fixes-20261115/) has no NOTES-FOR-OPERATOR.md while the replaced send-v2-20261114/ does; the "to make" commands and cover are not there. Low.

---

# Part: docs-a

## docs-a recheck against main a8d0eb45
Basis: `git diff --stat 162d3b9~1 HEAD` for my 12 docs + sent-mails.tsv shows NO change; only README.md changed (30+/22-). So every docs finding is unchanged and keeps its old line number.

### kernel-send-package.md unlabelled; BT-1 patch "does not exist yet", README quote, "unresolved" bug report
- original severity: Medium
- verdict: NOT ADDRESSED
- now: docs/kernel-send-package.md:27 "that one does not exist yet (`BT-1`, BRIEF §9.6)", :129 `README.md says "No kernel patch exists yet."` (README on main still has no such sentence), :134 unchanged; file not touched by the 26 commits.
- what is left to do: add a historical banner and fix present-tense passages.

### kernel-send-package.md cites BRIEF §9.6/§9.9 for items that no longer say that
- original severity: Medium
- verdict: NOT ADDRESSED
- now: docs/kernel-send-package.md:27, :83, :134; main BRIEF.md:718 item 6 is "Done 09-26 → 10-01: E1 ... E3", :761 item 9 is "Closed: the patch ran here 09-24"; `grep neutralis BRIEF.md` still empty.
- what is left to do: repoint or delete the three references.

### pre-submission-checklist.md: purge "must happen before submission", obsolete gates
- original severity: Medium
- verdict: NOT ADDRESSED
- now: docs/pre-submission-checklist.md:23-24 unchanged; bug-report.md still has no "active revision" banner.
- what is left to do: mark §1/§2/§2a/§4 superseded or remove.

### pre-submission-checklist.md §2b autosuspend factor
- original severity: Low
- verdict: NOT ADDRESSED
- now: docs/pre-submission-checklist.md:112, :117-125 unchanged.
- what is left to do: nothing urgent (historical note present).

### missing-quirks-entry.md lacks Harcsa / v7.3-rc1 / stable list / 74 / 12 / -38,-42,-43 values
- original severity: Medium
- verdict: NOT ADDRESSED
- now: docs/missing-quirks-entry.md unchanged (banners :3-20; ":18 `7.0.0-28…31`"); README on main still links it as "the full argument" (README:103-106).
- what is left to do: add a current-facts banner or stop calling it the full argument.

### missing-quirks-entry.md "untested here" second banner vs first banner
- original severity: Low
- verdict: NOT ADDRESSED
- now: docs/missing-quirks-entry.md:19 unchanged.
- what is left to do: nothing or trim.

### bug-report.md carries EX-nnn (no BT/CO/U/R2/DR labels); "seven deaths"
- original severity: Low
- verdict: NOT ADDRESSED
- now: docs/bug-report.md unchanged (":174 seven deaths and one survival", EX-0nn x36); still no BT-n label, historical banner at :3-8.
- what is left to do: decide whether EX-nnn is allowed; otherwise nothing.

### external-review-brief.md no status label
- original severity: Medium
- verdict: NOT ADDRESSED
- now: docs/external-review-brief.md:1-5 unchanged.
- what is left to do: add a historical banner.

### review-task-bluez-patches.md unlabelled
- original severity: Low
- verdict: NOT ADDRESSED
- now: docs/review-task-bluez-patches.md:1 unchanged.
- what is left to do: add a one-line "applied 2026-09-21" label.

### related-reports.md "only unblocked path upstream"
- original severity: Low
- verdict: NOT ADDRESSED
- now: docs/related-reports.md:171-172 unchanged.
- what is left to do: label historical.

### investigation-plan.md 0x0428 vs 0x043D comparison before retraction
- original severity: Low
- verdict: NOT ADDRESSED
- now: docs/investigation-plan.md:44 unchanged, retraction :112-118.
- what is left to do: inline marker.

### investigation.md Tier-1 autosuspend not annotated
- original severity: Low
- verdict: NOT ADDRESSED
- now: docs/investigation.md:425-436 unchanged (banner :8-11).
- what is left to do: optional marker.

### sent-mails.tsv stable-request row "not kept in the repository"
- original severity: Low
- verdict: NOT ADDRESSED
- now: docs/sent-mails.tsv:7 unchanged; patches/diag/stable-request-dc16388d45ec.md exists on main.
- what is left to do: point the path cell to it.

### README tree map "the two applied BlueZ patches"
- original severity: Low
- verdict: FIXED
- now: README.md:264 "patches/bluez/        the applied BlueZ patches, their verification script and mail notes;"
- what is left to do: nothing

### Link/path/elision checks
- original severity: Low
- verdict: PARTLY (informational)
- now: still no broken links in docs. README.md:158 link text "`contributions/CO-02-…`" is an elided identifier (unchanged, rule: identifiers in full); README.md:147-... other occurrence none new.
- what is left to do: write the dossier name in full.

## README.md on main: statements still disagreeing with main's BRIEF hand-off (174-240) / docs/STATUS.md / contributions/README.md

I read main's README in full (diff of README is the only change in my part). Items fixed by the diff: Environment kernels line now has 7.0.0-43 stock btusb, E3 retired, since 2026-11-12 22:55 (matches BRIEF:176-178, STATUS:197-198); "Current direction" now 2026-11-15; E3 "retired" in the stable bullet; BT-16 now three boots incl. 11-13 on -43 (BRIEF "third occurrence 11-13"); results/ and patches/bluez map lines; split of BlueZ fixes (3 daemon/shared fixes vs 8da7e648a9fb).

### README "Current direction" heading re-dated 2026-11-15 but CO-02 and CO-25 bullets are still as of 11-12
- severity: Medium
- where: README.md:149 vs :153-158 and :172-174
- evidence: heading "Current direction — 2026-11-15"; bullet ":153 `no maintainer reply as of 2026-11-12`", ":173-174 `a clarifying answer is drafted, not sent (2026-11-12)`". STATUS.md:3-14 (2026-11-15): CO-02 patches still new; v2 revised after five outside reviews, "the sleeping 2/2 is not to be sent", new candidate in `review-fixes-20261115/`; "reply v4 is unsent". BRIEF.md (hand-off): "Not ready: CO-02 v2 ... Its sleeping 2/2 deadlocks with debug delays (3 of 3, 11-15)".
- why it matters: the heading claims a 11-15 state, the bullet says "the next posting will be a v2" without saying that v2 is not ready and its previously prepared 2/2 was found deadlocking; the reply is v4 per STATUS, README gives no version.
- confidence: confirmed

### README "Next candidates" does not match the table "What to send" in contributions/README.md
- severity: Medium
- where: README.md:175-186 vs contributions/README.md:31-52
- evidence: README names CO-35, CO-43, CO-44, CO-04, CO-05, CO-22, CO-37, CO-38, CO-11 and says "send packages ready or in preparation". The table also lists as ready: CO-21 (`review-fixes-20261114/`), CO-20 (patch 1 alone), CO-12, CO-23, CO-39, CO-41; plus CO-02 v2 (not ready), CO-30 (RFC), CO-43 B2/D v2 (held), and CO-11a/CO-03/CO-37 5.72/CO-40 as one Ubuntu bundle (built, not filed). BRIEF:185 "Patch ready: CO-44, CO-38, CO-43 E, A and BT-24/25, CO-04, CO-22, CO-21, CO-20 patch 1, CO-39, CO-41; CO-35, CO-05 + CO-26, CO-12, CO-23 and CO-37 with operator decisions open". README says nothing of CO-21/20/12/23/39/41 and calls CO-37/CO-11 equally ready (CO-11a is "not filed", CO-37 operator route question open).
- why it matters: the README list is the public summary and is shorter and differently graded than the one table said to be "the one place".
- confidence: confirmed

### README "every tool takes BT_VID/BT_PID" is false
- severity: Medium
- where: README.md:133-134
- evidence: "`bt-boots`, `bt-crash` and `sanitize-logs.sh` work on any USB controller; every tool takes `BT_VID`/`BT_PID`". `grep -L BT_VID tools/bt-*` on main: 27 of 38 files (including bt-diagnose, bt-incident, bt-fault-window, bt-exhibit, bt-boots, bt-crash, bt-sco, bt-interval, bt-guards, bt-snapshot) do not mention BT_VID; only bt-usbstate, bt-trial, bt-postmortem, bt-state, bt-status, bt-mode, bt-window, bt-stage2, bt-verify-install, bt-boot-provenance, bt-health-report.sh and some bin/ do. tools/bt-exhibit:245 hard-codes "`13d3:3503` QCA9377".
- why it matters: a stranger with another controller is told every tool is parameterised; most are not (bt-diagnose derives the ID from sysfs; bt-exhibit prints a fixed device line).
- confidence: confirmed (grep of the token; tools that take other variables or read sysfs were not individually run)

### README "two controlled demonstrations" vs docs that say "three"
- severity: Low
- where: README.md:296-299 (and BRIEF:415, docs/install.md:6, 26, 45 = "2 controlled demonstrations + a third case EX-026 that was not our reset") vs docs/fix-proposal.md:9 and docs/investigation-plan.md:55 ("three controlled demonstrations")
- evidence: README ":296 `two controlled demonstrations ... (EX-023 and the 2026-08-15 boot), and the same outcome followed a USB reset this project did not issue (EX-026)`"; fix-proposal.md:9 "has three controlled demonstrations ... (`EX-023`, `EX-026`, the 08-15 boot)"; investigation-plan.md:55 "three controlled demonstrations that a USB reset destroys this controller — EX-023, the 2026-08-15 test (85.6 s), and EX-026 (85.6 s, and the reset was not even ours)".
- why it matters: README/BRIEF/install agree (2 + 1 not-ours); two historical docs count EX-026 as controlled, which BRIEF says it is not.
- confidence: confirmed

### README CO-35 description vs the CO-35 dossier front page
- severity: Low
- where: README.md:178-181 vs contributions/CO-35-l2cap-ecred-defer-hang-stable/README.md:4-7
- evidence: README "a stable request for an L2CAP deferred-accept hang that affects the 7.3, 6.18, 6.12 and 6.6 lines, and the older lines only with ... enable_ecred"; dossier banner (2026-11-12) "7.2.y has ended (7.2.15), so the request is for 7.3.y only; the final package is `send-20261102/`" while the table in contributions/README.md:41 sends `review-fixes-20261114/` and replaces `send-20261114/`. STATUS BT-10 row (line 81) lists hangs on 7.2.12, 6.18.58, 6.12.114, 6.6.160, matching README.
- why it matters: README and STATUS agree with each other; the dossier banner is stale (outside my part), README's "affects 6.18/6.12/6.6" is not what the dossier says the request covers.
- confidence: likely (not read in the review-fixes package)

### README Environment BlueZ line vs STATUS/BRIEF machine state
- severity: Low
- where: README.md Environment block "BlueZ : 5.72 (the running patched daemon is a rebuild of 5.72-0ubuntu5.5; the package is 5.72-0ubuntu5.8 since 2026-10-14)"
- evidence: STATUS.md:292 says the same (running daemon still the 5.5 rebuild started 10-14), but STATUS.md:207-208 / BRIEF hand-off say CO-03's `bluetoothd` (5.72-0ubuntu5.9~co03.1) is "staged on disk since 11-13, not running" and STATUS:266 says it replaced `/usr/local/libexec/bluetooth/bluetoothd`. README does not say a different binary is on disk.
- why it matters: consistent with "running", incomplete regarding the staged binary; low.
- confidence: likely

### README "Kernels" line and "twelve instances" unchanged and consistent
- Checked: README "7.0.0-29, -30, -31, -34 (the twelve instances)", E3 from 10-11 (-38), -42 from 10-30, -43 stock since 2026-11-12 22:55, E3 retired: all agree with BRIEF.md:174-180 and STATUS.md:197-209. "Ready to send but not sent" lists are not in README (no conflict). README states no "Signed-off-by" convention (no conflict).

## New defects introduced by the changes
- README.md:158 keeps the elided identifier `contributions/CO-02-…` (link text) in a section that was edited on this commit; project rule says identifiers in full (also in new text? the new "Next candidates" text has no elision).
- README.md:175-186 now says "send packages ready or in preparation" and points to the table, but the table's directories for CO-04/05/21/35/12 etc. are `review-fixes-20261114/` while the paragraphs in each dossier README still name older `send-*` directories (e.g. CO-35 README:5 "the final package is `send-20261102/`"); the README pointer is correct, the dossiers are stale.
- No new broken links in README (script over git ls-files on main README links not re-run; README diff adds only text and one link already in the old README).

---

# Part: docs-b

## Recheck docs-b against main a8d0eb45
Main's diff touched in my part: README.md, docs/issues.md, docs/STATUS.md, docs/ui-capture.md, tools/bt-ui-capture, scripts/bt-ui-atspi.py, scripts/prove-ui-capture.sh. Nothing under docs/source-*, external-cache*, ui-capture-research, userspace-upstream-check, mesh-tester-ci, results/, retest/ changed (git diff --stat 162d3b9~1 HEAD).

### README says BT-16 happened "Twice"
- original severity: Medium
- verdict: FIXED
- now: README.md:164 "At three boots (2026-11-05, 11-11 and 11-13, the ..."
- what is left to do: nothing

### README.md map describes results/ as two things; it holds 18 entries
- original severity: Low
- verdict: FIXED (largely)
- now: README.md:261-263 "(the list's CI run locally, the L2CAP hang sweep, the BlueZ 5.88 release check, the start-up and resume failure records, the btusb emulation runs; most have their own README.md)"; still a summary, not all 18, but no longer wrong
- what is left to do: nothing required

### external-cache.md cache location vs BRIEF §7 / .gitignore
- original severity: Medium
- verdict: NOT ADDRESSED
- now: docs/external-cache.md:28 "/var/cache/bt-investigation/<topic>/" (file unchanged); docs/ui-capture-research.md:16,20 still use /var/cache/bt-investigation too
- what is left to do: state that cache/ (git-ignored, exported as patches) is the practice, or mark the doc superseded

### external-cache-manifest.tsv row 3 schema / elision / stale tables
- original severity: Low
- verdict: NOT ADDRESSED (file unchanged)
- now: docs/external-cache-manifest.tsv:4 still `commit c73fa2f9...` in the sha256 column, `22M` in bytes
- what is left to do: normalise row, drop the elision, add bluez row to external-cache.md table

### source-map.md / source-access.md describe 2026-08-23 as current
- original severity: Low
- verdict: NOT ADDRESSED (files unchanged)
- now: no "as of" banner; still not linked from README/BRIEF
- what is left to do: add a dated/historical status line

### 5.88 release check: control output for 5.87 not shipped
- original severity: Low
- verdict: NOT ADDRESSED
- now: results/bluez-5.88-release-check-2026-11-07/ still holds only README.md and output.txt
- what is left to do: add output-5.87.txt (or drop the claim)

### Tested-by link pins ccfc358 not in clone
- original severity: Low (needs-check)
- verdict: WITHDRAWN
- now: in main's repository `git cat-file -t ccfc358e2cd866948aea3ec81bfabd5298e30618` = commit and `git ls-tree -r` of it lists 159 retest/mesh-tx-leak *.log; the commit exists (the old clone just had less history). Counts 159 in README.md:272 still match.
- what is left to do: nothing

### results/*: paths of the build machine and desktop user in published text
- original severity: Low
- verdict: NOT ADDRESSED (files unchanged)
- now: /root/exp, /home/i/ unchanged in docs/ui-capture-research.md:244, results/laptop-only-work-2026-11-11/headset-session/SESSION-CHECKLIST.md:77, docs/userspace-upstream-check-2026-10-03.md:542
- what is left to do: placeholder paths if desired

### mesh-tester-ci/README.md omits the 2026-11-14 directory
- original severity: Low
- verdict: NOT ADDRESSED
- now: grep -c instrumentation docs/mesh-tester-ci/README.md = 0
- what is left to do: list instrumentation-from-cache-20261114/

## Follow-up (docs/issues.md 1450-2056 region, line numbers shifted by about +30)

### U12 section's "Next" already done per STATUS
- original severity: Medium
- verdict: NOT ADDRESSED
- now: docs/issues.md:1673 "1. Build our bluetoothd from 5.72-0ubuntu5.8's source, ..."; STATUS.md:113 still says built `5.72-0ubuntu5.9~co03.1`
- what is left to do: mark step 1 done in the section

### U8 section ends "that test is next"; STATUS:96 vs :177
- original severity: Medium
- verdict: NOT ADDRESSED
- now: docs/issues.md:1516 "...— that test is next."; docs/STATUS.md:109 U8 row still "installable only after trial E3 #1 closes"
- what is left to do: update both

### U13 GNOME-report owner CO-27 vs CO-42
- original severity: Medium
- verdict: NOT ADDRESSED
- now: STATUS U13 row still names only CO-27 (CO-42 only in the U29 row); issues.md U13 section has no CO id
- what is left to do: add CO-42 to the U13 row and section

### U29: STATUS lists CO-39..42; section names none
- original severity: Low
- verdict: NOT ADDRESSED
- now: issues.md U29 section (about 1929-1990): 0 occurrences of "CO-4"
- what is left to do: name owners in the section

### Counts in STATUS:177 vs mining output / U12 history
- original severity: Low
- verdict: NOT ADDRESSED (consistency note only; numbers still agree; U12 section still lists three occurrences)
- what is left to do: one sentence reconciling 3 vs 9+1 occurrences

### U10 STATUS row omits CO-08 research result
- original severity: Low (likely)
- verdict: NOT ADDRESSED
- what is left to do: reconcile "858 Dual Channel frames" with CO-08's single-channel finding

### "On the wider claim" contradicts README cause
- original severity: Medium
- verdict: NOT ADDRESSED
- now: docs/issues.md:2042 heading unchanged, "roughly fifteen purpose-built tools" :2081, "The only fix is a cold power-off" :2073; no label
- what is left to do: label as historical (2026-09) or rewrite around BT-1 cause

### Evidence paths outside repo and elisions in issues.md
- original severity: Low
- verdict: NOT ADDRESSED
- now: docs/issues.md:1782 (tmp/u16-dup-check, unmarked), :1869 `archive/…/journal-user-0755-0812.txt`, :1936 `53a71259…`, :1943 /root/exp/agent-work/u29-t1-a2dp-backport/, :1946 `4661cc83…`, :1968 `dev_…`
- what is left to do: full identifiers; mark local paths

### Order/numbering in the register
- original severity: Low
- verdict: NOT ADDRESSED (no section for U21-U28, U30, U31; U8 after U9)
- what is left to do: one note that those have table rows only

## ui-capture docs vs tool on main (new light mode) - checked
docs/ui-capture.md "Always-on light mode" vs tools/bt-ui-capture and scripts/bt-ui-atspi.py: subcommands start-light/status-light/stop-light exist (tool ~l.540-600); unit names bt-ui-light-atspi/-sysbus/-sessbus match LIGHT_UNITS; base /var/log/bt-ui-light, UTC-named dir, `current` pointer; 20 MiB x (4+1) = 100 MiB per file, 300 MiB total matches LIGHT_MAX_BYTES=20971520, LIGHT_KEEP=4; env names BT_UI_LIGHT_MAX_BYTES/KEEP/BASE match; mode 0640 files (tool chmod 0640); twelve registered types = 10 SHELL_STATES + name + description matches; "--register-shell-events" opt-in exists in bt-ui-atspi.py main(); sysbus match rules (exact path, arg0path) match doc; "no bt-mark, logger" matches; stop does not touch light units both ways (separate unit lists).

## New defects introduced by the changes
1. Low, new "…" elision of identifiers/paths in new text: docs/issues.md (new "Current state 2026-11-15" block and BT-24/BT-25 status lines) writes `contributions/CO-43-…/send-bt24-bt25-20261114/` (x2); docs/STATUS.md writes `CO-43-…/drafts/`, `CO-43-…/send-20261113/A-review-fixes-20261114/`, `contributions/CO-02-…/patch/v7-candidate/send/`, `contributions/CO-02-…/review-fixes-20261115/`. The directories exist (contributions/CO-43-btusb-runtime-resume-failure/send-bt24-bt25-20261114) but the project rule says identifiers are written in full.
2. Low, cosmetic: tools/bt-ui-capture `help` now prints `sed -n '2,80p'`, which includes the non-comment lines `set -uo pipefail` (l.79) after the Seams block; harmless.
3. Medium, doc claim vs fact (needs-check): docs/ui-capture.md light-mode text says `status-light` needs "no root", and tool's status_light_main uses no need_root, but the recorder is in a "NOT passive" mode (registers events with the AT-SPI registry) while the tool header's NEVER/passive wording and ui-capture.md intro ("never touches...") were not qualified for the full mode only; the new text discloses it, so only the old header sentence "passive monitors" (tool l.~47) is now imprecise for light-atspi. Low in practice.
4. Not found: option-parser regressions in bt-ui-atspi.py (--address is checked after --check-filter; error if missing), no new bypass switch except opt-in --register-shell-events.

---

# Part: comms-reviews

## Recheck against main a8d0eb45 (checkout a checkout of main). Remote itself not checked; `git branch -r` there still lists 20 remote-tracking branches (this clone's stale knowledge).

### reviews/README.md lists only part of the directory (~58 unlisted)
- original severity: Medium
- verdict: NOT ADDRESSED (worse: 9 more files)
- now: reviews/README.md unchanged by the 26 commits (`git diff 162d3b9~1 HEAD --stat -- reviews` touches only 9 new files). Unlisted additions: 2026-11-15T0115Z-submitted-contributions-status.md, five 2026-11-15T0115Z-submitted-status-review-reviewer-*-verbatim.md, 2026-11-15T0300Z-submitted-status-review-checks.md, 2026-11-15T1751Z-project-review-fixes-reaction-checks.md and -verbatim.md. Last Reports row is still 2026-11-07T20:00Z.
- what is left to do: add the ~67 unlisted files (or state that the register stopped on 11-07).

### Naming schemes
- original severity: Low
- verdict: NOT ADDRESSED
- now: README.md still states only the 09-13 exception; new files use the T-scheme (consistent). 
- what is left to do: document the extra schemes.

### README "Branches" paragraph: review/<timestamp> branches
- original severity: Medium
- verdict: NOT ADDRESSED
- now: README.md:286-287 "`review/<UTC timestamp>` holds one assessment (report first, then the reaction on `review/<timestamp>-fixes`)". BRIEF:223-227 says the public repository now has only `main`, `tests/test-suite`, `research/journalctl-file-scaling` and the whole-project review's branch, so the review/* convention text is unchanged and unsupported; reviews/README.md:63,326 unchanged.
- what is left to do: update README Branches and the two reviews/README branch mentions.

### Register rows open whose checks pass (R2-21, R2-25) / R2-64/65 vs DR-07
- original severity: Medium
- verdict: NOT ADDRESSED
- now: reviews/README.md unchanged.
- what is left to do: re-run the checks and set statuses.

### Register CO-01..CO-10 block vs contributions/README.md
- original severity: Medium
- verdict: NOT ADDRESSED
- now: reviews/README.md unchanged.
- what is left to do: mark rows with the contributions/README states or drop the block.

### Ids BRIEF cites (informational)
- original severity: Low
- verdict: NOT ADDRESSED (nothing to fix; no change)
- now: unchanged.
- what is left to do: nothing.

### ci-local's eb2e6d6/6ada2a1: "not on main" vs landed
- original severity: High
- verdict: PARTLY
- now fixed: BRIEF.md:223-225 "`ci/upstream-ci-local` among them (its two commits are on `main` as the ports `8b71499` and `a56141e`)"; both ids resolve in the main checkout (`git cat-file -t 8b71499` -> commit). The "land or drop" item is gone.
- remaining: docs/STATUS.md:465 still lists the two as "Not on main, fit to land" (a dated 10-18 survey block, labelled); BRIEF.md:144 still says ci-local "landed on main that day [10-13]" while the ports are 10-18/11-xx; comms 11-13 note unchanged (immutable by rule). a56141e not checked.
- what is left to do: nothing essential; optionally date the BRIEF:144 sentence.

### BRIEF says the delete command is in the 11-13 note
- original severity: High
- verdict: FIXED in BRIEF, new contradiction in comms
- now: BRIEF.md:222-227 replaced it by "Old remote branches: done 2026-11-15. The operator deleted the 16 ... (each backed up first) ... (`ls-remote`, 2026-11-15)". But comms/2026-11-15T2130Z... says "BRIEF now says the 11-13 note 'gives no command and no count'" (grep of BRIEF for that phrase: none) and "Deleting the 16 branches remains the operator's" - written after/alongside a BRIEF that says done (BRIEF commit a8d0eb45 21:36+01:00, comms commit 21:12+01:00).
- what is left to do: either a short comms note that the deletion is done, or accept the 21:12 state; fix 2130Z's misquote only by a new message.

### BRIEF §9.2 "six tasks" differ from the source's six; "device survey"
- original severity: Medium
- verdict: NOT ADDRESSED
- now: BRIEF.md:677-683 unchanged text (shifted).
- what is left to do: as before.

### BRIEF §9.2 still calls the device survey open
- original severity: Medium
- verdict: NOT ADDRESSED
- now: BRIEF.md:681-683 "the device survey has no record of its scope ... stays open until the operator says what it was or drops it".
- what is left to do: record "dropped (operator, 2026-10-19, comms 0601Z)".

### §8a instances not in the lessons files
- original severity: Medium
- verdict: NOT ADDRESSED
- now: BRIEF.md:573 still sends to the two lessons files; lessons/ unchanged.
- what is left to do: add a 2026-10 lessons entry or point rules to comms.

### lessons 08-27 edited after its stamp
- original severity: Low
- verdict: NOT ADDRESSED
- now: lessons/2026-08-27T1200Z...:276, :344 unchanged.
- what is left to do: nothing/accept.

### Private working arrangements in comms
- original severity: Medium
- verdict: NOT ADDRESSED (and extended)
- now: all earlier lines unchanged; new comms/2026-11-15T2010Z-from-test-suite-maintainer-relayed-by-operator.md (203 lines) is a pasted agent-session transcript: "I'm checking whether `main` replied...", "Resetting it to `main` is cleanest but needs a force-push, which the proxy may refuse", "the push was halted by the checkout's publish scan", "saved in the private repo at a16b208", "pasted by the operator".
- what is left to do: decide on redaction vs append-only rule.

### comms/README conventions vs messages
- original severity: Low
- verdict: NOT ADDRESSED (two more offenders)
- now: both new 11-15 files lack front matter (first line "# From ..."); 2010Z has no recipient in its name (`from-test-suite-maintainer-relayed-by-operator`, README naming `...-from-<sender>-to-<recipient>.md`); 2130Z has no commands behind figures ("837 files", "nine times today", "17:55:43 to 18:11:09" - only the last names its source). 
- what is left to do: front matter/name fix in a new message; README unchanged.

### BRIEF "Who works where" names retired branches
- original severity: Medium
- verdict: NOT ADDRESSED
- now: BRIEF.md:145 "works on `tests/unit-testing-introduction` and `tests/unit-testing-introduction-ready-for-main`, and merges `main` into them" - those branches were deleted per BRIEF:222-227 (same file). `tests/test-suite` is now mentioned at BRIEF:226 only as existing, not as the working branch.
- what is left to do: rewrite line 145.

### Elision addendum (file names with "…")
- original severity: Low
- verdict: NOT ADDRESSED
- now: BRIEF.md:679 "`comms/2026-10-19T0504Z-…`", :739 and :749 "`reviews/2026-09-21T0900Z-…`", "`reviews/2026-09-22T1700Z-…`", though BRIEF.md:495 states "Write identifiers in full ... Never `…`". New comms 11-15 files: none.
- what is left to do: write the names in full.

### Open requests with no answer
- original severity: Medium
- verdict: PARTLY
- now answered: (1) 11-13 "main take tests/test-suite": 2010Z (relayed) says main cherry-picked the 8 commits on 11-13 22:19 UTC and the branch was moved to main's tip 0a8c191 (not verified by me; comms only). (2) 11-07 four questions: answered in comms/2026-11-15T2130Z... items 1-4 (retire/exclude scripts; install bt-journal-files "yes"; order agreed; pre-push tests "yes").
- still open: T1, SR1, 0x043d (agreed, "go ahead"; STATUS "Left before the deploy: SR1, T1"); second-maintainer requests (hooks branch, history-rewrite-stopped.md backup) and the 10-21 main->second questions: no answer; ci-local flake-rate/bot-log items: no answer found; new open asks in 2130Z: test-suite to send the coverage-exclude hunk, add findings to CO-46's "R&D left", operator's "exact list" for deleting devtools/test-bt-journal-files.sh; the 11-15 test-suite question "bring the branch up / draft reminder" resolved in the transcript only.
- what is left to do: record the second-maintainer items as closed or open.

### Register text: floors and counts
- original severity: Low
- verdict: NOT ADDRESSED
- now: reviews/README.md:202 "--min 85 awk", :283 "now 65", :170 "329 invariants", 8 "this commit" rows unchanged.
- what is left to do: update.

## New defects introduced by the changes
1. comms/2026-11-15T2130Z-from-main-branch-maintainer-to-test-suite-maintainer.md: file name time 21:30Z is later than the commit that adds it (c6589ccc, 2026-11-15T21:12:25+01:00 = 20:12Z); README says the timestamp is when written.
2. Same file misquotes BRIEF ("BRIEF now says the 11-13 note 'gives no command and no count'"; not in BRIEF at a8d0eb45) and says branch deletion "remains the operator's" while BRIEF.md:222 (later commit) says done.
3. comms/2026-11-15T2010Z-...relayed-by-operator.md: not a sender-to-recipient message, no front matter, contains session narration and tool status lines (see privacy above); it is the only comms file with this shape.
4. 2130Z promises "I will add it to install.sh and uninstall.sh" (bt-journal-files); not done in the tree yet (open commitment, not a defect).
5. reviews/: nine new files unlisted (see first block); the "-reaction-checks"/"-verbatim" pair 2026-11-15T1751Z follows the verbatim/checked pairing.
6. No "…" elision found in the new 11-15 comms text.
