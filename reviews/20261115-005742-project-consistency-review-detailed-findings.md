> **Findings-only copy, made 2026-11-16.** This page keeps the findings, ids, severities,
> `file:line` references, verdicts and tables of the reviewer's page of the same name; it is not
> the original. Sections that describe how the review was organised are left out, and a line that
> quoted or described the working arrangement (the review's "P-01 class") is replaced by one
> marker line. The original pages are on the reviewer's branch: the review at commit `162d3b9`,
> the first recheck at `3f8e8f6`, the second at `50bd289` and the third at `17f8ac6` (which also
> carries the final wording of the second). Line numbers in the text are those of the tree the
> reviewer read, not of this copy.

# Detailed findings behind the comprehensive project review of 2026-11-15

[wording of the P-01 class omitted] The main report is [`review-comprehensive-project-consistency-review-20261115-005742.md`](review-comprehensive-project-consistency-review-20261115-005742.md); it says which of these the lead reviewer re-read ("checked") and corrects two (T-08 confirmed; K-02's severity and line number). Everything here is a lead until checked on the file.


---

# Part: code-bin-install

## Findings: code-bin-install

### uninstall.sh reloads btusb with no wedged-controller / open-trial / experiment guard
- severity: High
- kind: code-defect
- where: uninstall.sh:284-308 ([5/5]); contrast install.sh:694-755; docs/restore-original-state.md:84-85
- evidence: uninstall.sh:299-302 `uc=$(awk '/^btusb/ {print $3}' ...); if [[ "${uc:-0}" == "0" ]]; then run modprobe -r btusb; run modprobe btusb`. install.sh:694-710 documents that exactly this "usecount 0 means safe" test is INVERTED for a wedged controller (usecount is 0 because it is wedged) and added `failed_this_boot` (n_tmo) and open-trial guards (install.sh:310). uninstall.sh has neither, and no experiment-mode check. restore-original-state.md:84-85 only says "If the module is in use the script says so".
- why it matters: `uninstall.sh --apply` on a machine with an HCI timeout this boot, an open trial or experiment mode resets/unbinds the controller (project rule: never unload/reload btusb) and ends a stage-1 observation; the docs do not warn. No guard, no `--no-reload` option.
- confidence: confirmed

### bt-raw-archive.service hard-codes the operator's checkout path; install.sh still enables it everywhere
- severity: Medium
- kind: code-defect
- where: systemd/bt-raw-archive.service (ExecStart line), install.sh:537-538 and 680, scripts/raw-capture-archive-all.sh:20-21, docs/tooling-index.md:86
- evidence: `ExecStart=/root/exp/qca9377-bt-hang/scripts/raw-capture-archive-all.sh`; install.sh installs the unit/timer and runs `systemctl enable --now bt-raw-archive.timer` unconditionally ("Enabled unconditionally"); the script writes into `$REPO/archive/...` (the git checkout). tooling-index says "installed by install.sh".
- why it matters: the installer copies units, not the scripts they run. From any other clone location the unit fails every 10 min; bt-verify-install cannot see it (it compares only install_file pairs); no other unit ExecStart points into a checkout.
- confidence: confirmed

### bt-journal-files tool and its three units are shipped but installed/removed by nothing
- severity: Medium
- kind: doc-vs-code
- where: systemd/bt-journal-files.service, bt-journal-files.timer, bt-journal-files-shutdown.service; tools/bt-journal-files; install.sh (no reference), uninstall.sh (no reference); docs/tooling-index.md:78; HISTORY.md:4975
- evidence: tooling-index.md:78 "`tools/bt-journal-files` (installed in `/usr/local/bin`) ... Runs 5 min after boot and every 3 h (`bt-journal-files.timer`) and at shutdown (`bt-journal-files-shutdown.service`)". `grep bt-journal-files install.sh uninstall.sh` finds nothing; install.sh installs only bt-backup-journal + bt-journal-backup.{service,timer}.
- why it matters: a fresh `install.sh --apply` does not give the journal protection the docs call installed; on the machine it was hand-installed, uninstall.sh/verify-restored.sh/bt-verify-install are blind to it, so "UNINSTALL COMPLETE ... complete restoration" is false there. The suite's installed-vs-uninstalled invariant cannot catch a file installed by neither script.
- confidence: confirmed (hand-install on the machine is inferred from HISTORY.md:4975)

### Non-default device: the event-triggered snapshot unit gets no BT_VID/BT_PID drop-in
- severity: Medium
- kind: code-defect
- where: install.sh:385-401 (SNAP_DROPIN only for bt-health-snapshot.service.d), install.sh:611-612, etc/udev/rules.d/51-bluetooth-health-snapshot.rules (RUN+= bt-health-snapshot-event.service), systemd/bt-health-snapshot-event.service
- evidence: comment at install.sh:394 "The metrics collector must watch the same device, or its columns describe hardware the watchdog is not managing", yet the drop-in is written to `bt-health-snapshot.service.d/10-device.conf` only; `bt-health-snapshot-event.service` runs the same `/usr/local/sbin/bt-health-snapshot` with no Environment. uninstall.sh:103-105 and verify-restored.sh:84-85 likewise know only the two drop-ins. (bt-usbmon.service, bt-trial-auto also get no device env.)
- why it matters: with `BT_VID=0cf3 BT_PID=e300 ... --apply` (documented in install.md:136) every udev-triggered row describes 13d3:3503 (dev_present=0), mixing wrong-device rows into metrics.tsv.
- confidence: confirmed

### bt-usbmon capture directory/files are not root-only although the script says they must be
- severity: Medium
- kind: code-defect
- where: bin/bt-usbmon:53 (`mkdir -p "$DIR"`), :171-178, systemd/bt-usbmon.service (no UMask), docs/changes-applied.md:312; contrast bin/bt-trace:71-77, systemd/bt-capture.service (UMask=0077)
- evidence: bt-usbmon:175-177 "the capture directory must stay root-only, because USB traffic to a Bluetooth controller carries link keys"; but the script sets no umask/chmod and the unit has no UMask=. changes-applied.md:312 "Capture directories are root-only (0700, UMask=0077)". bt-trace does `mkdir -p; chmod 0700; umask 077`.
- why it matters: pcaps likely created 0644 in a 0755 dir (unless /var/log/bt-health or usbmon/ was chmod-ed by hand). Link keys readable by any local user, contradicting the doc.
- confidence: needs-check (on the machine: `stat -c %a /var/log/bt-health /var/log/bt-health/usbmon`; read-only)

### modprobe dyndbg options + bt-dyndbg.service: claimed "covers reload by hand" is not true, and experiment mode drops load-time dyndbg
- severity: Medium
- kind: contradiction
- where: etc/modprobe.d/btusb-qca9377.conf (comment "bt-dyndbg.service stays, because it still covers the case where btusb is reloaded by hand"; `options btusb dyndbg=+p`; `options bluetooth dyndbg="file hci_core.c +p; ..."`), bin/bt-dyndbg:45-81 (NOISY_FUNCS, 5.8 GB/h), systemd/bt-dyndbg.service (oneshot RemainAfterExit), tools/bt-mode:29-30 and :99
- evidence: `dyndbg=+p` turns on every site in btusb.c / hci_core.c incl. the per-URB and tx-scheduler functions bt-dyndbg exists to suppress; bt-dyndbg runs once at boot (oneshot) and is not re-run on a hand reload, so a reload re-enables the flood. bt-mode header: "Passive capture (bt-capture, bt-trace, bt-usbmon, dynamic debug) stays on in BOTH modes", but `bt-mode experiment` renames this same modprobe conf to .disabled, removing the only load-time dyndbg hook the conf calls "the only hook early enough".
- why it matters: unbounded journal volume after any btusb reload (the journal cap / evidence the header protects), and experiment mode silently loses the probe-time debug lines that the conf says would otherwise be invisible.
- confidence: likely (dynamic-debug semantics of module params not run here)

### --tools-only writes the first-install stamp that bt-health-report reads as "mitigation first went in"
- severity: Low
- kind: doc-vs-code
- where: install.sh:621-638 (stamp written under APPLY, which --tools-only sets), tools/bt-health-report.sh:69, install.sh:622-625
- evidence: "bt-health-report needs the moment the mitigation FIRST went in ... Write it once"; `--tools-only) APPLY=1; TOOLS_ONLY=1`, no TOOLS_ONLY test around the stamp; install.sh:212 also uses the stamp to classify files as "our earlier deploy".
- why it matters: a tools-only deploy on a machine that never armed anything stamps a before/after split date for a mitigation that does not exist.
- confidence: likely (did not read bt-health-report's use in depth)

### "every file installed is NEW / .pre-qca9377-bt-hang" does not cover the generated files
- severity: Low
- kind: contradiction
- where: install.sh:18-23, 385-408 (10-device.conf via printf >), 427-442 (50 rule via sed >), 580-595 (51 rule via sed >); docs/install.md:91-94; README claim
- evidence: install_file() is the only place that makes a `.pre-qca9377-bt-hang` copy; the three generated files are written by redirect and overwrite any foreign file of that name; uninstall then deletes it.
- why it matters: the "complete restoration" statement is not true for these paths (low probability, but the stated property is unconditional).
- confidence: confirmed

### Doc says "two" controlled demonstrations; install.sh (and others) say "three"
- severity: Medium
- kind: contradiction
- where: install.sh:11 and :36 ("THREE controlled demonstrations ... (EX-023, the 2026-08-15 test, EX-026)") vs docs/install.md:6, 26, 45; README.md:288 ("two controlled demonstrations ... EX-023 and the 2026-08-15 boot ... EX-026")
- evidence: also docs/tooling-index.md:231, docs/fix-proposal.md:9, docs/investigation-plan.md:55 say three (EX-023 11.2 s, 08-15 test 85.6 s, EX-026 85.6 s); docs/issues.md:454 says "two controlled tests".
- why it matters: the headline reason for --tools-only is quoted with different counts; installs.md counts EX-023 and the 2026-08-15 boot as the same item.
- confidence: confirmed (count disagreement); which is right needs the exhibits

### docs/install.md references that no longer match the code or machine
- severity: Medium
- kind: stale
- where: docs/install.md:78-80, :85-86, :107-125
- evidence: (a) :78-79 "`./install.sh --apply` (printed by `bt-verify-install` on any drift)" - bt-verify-install:165-166 now prints `sudo ./install.sh --tools-only, then systemctl daemon-reload, bt-verify-install, bt-mode status`. (b) :85-86 "E3 untouched: srcversion D1DEA96A0C95BFAB05CEE01, and modinfo -n btusb names .../updates/btusb.ko" - E3 retired and stock btusb since 2026-11-12 (briefing). (c) "What it installs" lists 3 items (watchdog, autosuspend, metrics collector) but install.sh installs ~70 files and enables bt-trace, bt-capture, bt-trial-auto, bt-dyndbg, bt-usbmon, journal-backup and raw-archive timers (install.sh:669-685), plus journald and bluetoothd drop-ins, and restarts systemd-journald.
- why it matters: step 7 of the "investigation machine" route would be read as failing; a reader of "What it installs" does not learn that --apply also restarts journald and bluetooth debug.
- confidence: confirmed

### docs/changes-applied.md "Manual - the complete set" is day-one only
- severity: Medium
- kind: stale
- where: docs/changes-applied.md:166-196, :6, :12-15, :253-401
- evidence: heading "Manual — the complete set" lists ~15 commands/files; install.sh/uninstall.sh now handle ~70 files and 9 units (bt-trace, bt-capture, bt-dyndbg, bt-usbmon, bt-trial-auto, bt-journal-backup.timer, bt-raw-archive.timer). The banner at :12 admits §0 is day-one only but §5 is not caveated. The dated sections stop at 2026-08-13: no entry for journal-backup/raw-archive timers, bt-mode/.disabled files, `SystemMaxFiles=1000` (etc/systemd/journald.conf.d, :264 lists only MaxUse/KeepFree), `.pre-qca9377-bt-hang`. Line 6 points to itself ("see docs/changes-applied.md §5").
- why it matters: someone following the manual rollback leaves nine units enabled and running (capture daemons, timers) while believing the rollback complete.
- confidence: confirmed

### docs/restore-original-state.md contradicts the current uninstall and omits leftovers
- severity: Low
- kind: contradiction
- where: docs/restore-original-state.md:46, :58-68, :92-99; uninstall.sh:239-245; install.sh:209-220
- evidence: :46 "restoration is *deletion of added files*, not restoration from backup" vs install.md:91-94 and uninstall.sh:242-244 (moves `<dst>.pre-qca9377-bt-hang` back). The doc never mentions `.disabled`/`.pre-qca9377-bt-hang` handling. §3 lists only metrics.tsv as kept data; also left behind: /var/log/bt-health/{trace,capture,usbmon}, /root/bt-journal-archive (bt-journal-backup.service), /root/exp checkout archive/ (raw-archive).
- why it matters: the data-left-behind list understates what an uninstall leaves, and the restoration mechanism described is the pre-2026-09-20 one.
- confidence: confirmed

### bt-evidence start/stop send an HCI command to the controller (hciconfig name), twice per session, with no opt-out
- severity: Medium
- kind: rule-vs-practice
- where: bin/bt-evidence:69-71 (snapshot_state, called at :105 and :161); contrast bin/bt-mark:12-18 and docs/install.md:88-89
- evidence: bt-evidence:70 `timeout 6 hciconfig "$hci" name >/dev/null 2>&1 && alive=yes || alive=no`. bt-mark is "PROBE-FREE BY DEFAULT since 2026-09-19 ... an HCI Read Local Name sent to the controller under study on EVERY mark ... `--probe` measures it, on purpose". install.sh:781 recommends `bt-evidence start`.
- why it matters: probes are interventions on the machine being observed; the project removed this exact probe from bt-mark/bt-trial but left it in the recorder used around hang reproductions. bt-health-snapshot:89-91 also probes every 15 min and on every udev event (documented as "periodic HCI probes", off in experiment mode; but install.md:124-125 describes the collector without saying it sends an HCI command).
- confidence: confirmed

### bt-verify-install reports success with artefacts missing from the repo
- severity: Low
- kind: code-defect
- where: tools/bt-verify-install:88-91 and :170-176
- evidence: `printf '  %s?%s missing in repo: ...'; continue` increments neither `drift` nor `missing`, so the final line is `N artifacts in sync; running system matches the checkout` with exit 0. Also the loop treats conditionally installed items (bt-trace, bt-sco, bt-capdiff, bt-usbmon, only when btmon/tcpdump exist, install.sh:507-561) and `--no-metrics` units as NOT INSTALLED/drift.
- why it matters: the header's own stated hazard ("silently omits artefacts ... false all-clear"); on machines without btmon/tcpdump or with --no-metrics it reports drift that install.sh itself would not fix.
- confidence: confirmed

### install.sh -h cuts off mid-section; tools-only banner says "watchdog arms itself at boot"
- severity: Low
- kind: stale
- where: install.sh:53 (`sed -n '2,15p'`), :362-365, :771-786
- evidence: help prints through line 15 "# Different controller:" and omits the BT_VID example (line 16) and "Reverse with"; preflight (:365) says "Installing anyway; the watchdog arms itself at boot." and the final INSTALLED block prints "Verify: systemctl status bt-hang-watchdog / expect N / expect on" even under --tools-only (install.md:78-80 tells the reader to ignore this).
- why it matters: advice printed by the tool is known-wrong for its recommended mode.
- confidence: confirmed

### BRIEF "all 3 skip now" vs install.sh dates (08-19 and 09-01 reversions, "09-16 fixed")
- severity: Low
- kind: contradiction
- where: BRIEF.md:409-413 vs install.sh:166-170, :575-579 (not my file; noted for the lead)
- evidence: BRIEF "Until 2026-09-16 --tools-only reinstalled the two files ... caught 09-18 ... all 3 skip now"; install.sh says reversions on 08-19 and 09-01 and that the 51 rule was still written on 2026-09-18 "one rule over". The "all 3 skip" claim itself is CONFIRMED correct in code: install_file() skips modprobe conf via `.disabled` sibling (:173), 50 rule (:427), 51 rule (:580) - exactly the three files bt-mode:99-105 moves.
- confidence: confirmed (code); BRIEF wording is the lead's to check

### Minor: stale/orphan names
- severity: Low
- kind: stale
- where: uninstall.sh:104 (`20-verbose.conf` in FILES; nothing in the repo creates it - grep finds only reviews/), systemd/bt-usbmon.service `BT_USBMON_BUS=3` vs bin/bt-usbmon:74-77 comment "bus recorded at install time" (install.sh records nothing), etc/systemd/journald.conf.d header "16 GB against 88 GB free"
- confidence: confirmed

---

# Part: code-tools-a

## code-tools-a findings (tools/bt-trial, bt-trial-audit, lib/*, bt-snapshot, bt-archive, bt-retention, bt-exhibit, bt-backup-journal, bt-journal-files)

### bt-backup-journal re-archives a PREFIX with --replace and can replace a larger archive by a smaller one
- severity: High
- kind: code-defect
- where: tools/bt-backup-journal:131-135 (`(( prefixed )) && REPL=(--replace)`), tools/bt-archive:268-270 (`mv -f "$TMP" "$OUT"`), tools/bt-archive:288-292 (sweep `rm -f "$stale"`); premise text tools/bt-backup-journal:44-48, tools/bt-journal-files:5-8
- evidence: bt-backup-journal: "A PREFIX IS NOT AN ARCHIVE ... re-archive it while they still exist" then `REPL=(--replace)`. bt-archive checks only read-back (`ARC_N != SRC_N`, count of the stream just written); it never compares the new archive's record count with the existing one. The 2026-10-23 correction in bt-backup-journal's own header says a running boot loses its OLDEST files ("the 10-19 boot its first ~14 h"). A prefix taken while live therefore holds the early records that the finished boot no longer has on the ring.
- why it matters: the prefix archive of the live boot may be the only copy of the early part of that boot; re-archiving after the boot ends silently overwrites it (and removes `.prefix` and any other-extension copy) with a smaller export that verifies fine against itself. Evidence deleted by the tool that exists to keep it. `bt-archive --repair` is safe (it re-archives only when archived < on-ring) but bt-backup-journal has no such test; manual `bt-archive <idx> --replace` has none either although the header (bt-archive:104-107) claims "the refusal above is what stops a good archive being replaced by a worse one".
- confidence: likely (code read; the rotation premise is from the 10-23 note, not re-measured)

### bt-trial `start` (manual) reuses an existing trial directory and truncates steps.log / overwrites state-before.txt
- severity: Medium
- kind: code-defect
- where: tools/bt-trial:351-359 (start) vs tools/bt-trial:411-416 (autostart sets an existing dir aside)
- evidence: start: `dir=...; mkdir -p "$dir"` ... `bt-state > "$dir/state-before.txt"`; `: > "$dir/steps.log"`. autostart has the guard "An existing directory is set aside, never reused: the row can be rebuilt from the journal, the directory cannot."
- why it matters: the numbering comes from results.tsv rows, so a trial whose close lost its row (the very case the autostart guard was written for) is re-numbered, and a manual start destroys that directory's steps.log and state-before.txt.
- confidence: confirmed

### BRIEF.md description of bt-trial differs from main's code in three places
- severity: Medium
- kind: doc-vs-code
- where: BRIEF.md:852-855 vs tools/bt-trial:405-416; BRIEF.md:805 vs tools/bt-trial:238-246, 395-399; BRIEF.md:675 vs whole file
- evidence: (a) BRIEF: "next boot's bt-trial-auto opens a new trial with the same number in the same directory, overwriting state-before.txt and steps.log". Code: same NUMBER yes, but an existing directory is renamed `<dir>.unclosed-<stamp>` and a new directory made (autostart only; manual start still overwrites, see above). (b) BRIEF: "bt-trial labels them build=stock" (patched bluetooth.ko). Code: autostart relabels a declared `stock` to the btusb version suffix when /sys/module/btusb/version has a "-" (module_build, since 2026-09-26) and keeps the declaration in `build_declared=`; so it is true for a patched bluetooth.ko (not examined anywhere), and for a btusb whose version string has no "-", and for manual `start <build>`; false for a suffixed diagnostic btusb. (c) "does not record which bluetoothd runs": confirmed, no `bluetoothd` string in bt-trial or bt-trial-audit; fingerprint is autosusp,power,wd,probes only. (d) /run/bt-trial/current on tmpfs: confirmed (`STATE="${BT_STATE:-/run/bt-trial}"`). (e) row written before bt-state, bt-mark and SCO decode: confirmed (row printf at 1031-1035; bt-state/bt-mark 1045-1046; decode 1071-1109).
- why it matters: a reader acting on BRIEF would believe the directory is overwritten at boot and that every module build is mislabelled; both are narrower than stated.
- confidence: confirmed

### Close paths that send an HCI command (answer to checklist 2)
- severity: Medium
- kind: doc-vs-code
- where: tools/bt-trial:111-123 (hci_alive = `timeout 6 hciconfig "$h" name`), 346 (start), 445-447 (autostop with BT_TRIAL_PROBE=1), 777 (ok classification), 936-937 (resp_after)
- evidence: manual `ok` calls hci_alive twice (777, 937); manual `hang` once (937); `start` once (346); autostop only with BT_TRIAL_PROBE=1 (then `exec "$0" ok|hang` WITHOUT BT_TRIAL_PASSIVE). Default autostop is passive (BT_TRIAL_PASSIVE=1 -> trial_result=ended_unprobed, resp_after=unprobed). bt-state (1045) is probe-free unless `--probe`; bin/bt-mark is probe-free unless `--probe` (read both). bt-incident after a failed row: not examined for HCI beyond grep (its hciconfig is behind PROBE, line 37).
- why it matters: a manual `hang` close is not passive: it sends an HCI Read Local Name into a window that is by definition hung; the header (line 8) says `ok` "verifies the controller answers" but does not say `hang` also probes.
- confidence: confirmed

### hci_alive's "cannot tell" status (rc 2) is read as dead
- severity: Medium
- kind: code-defect
- where: tools/bt-trial:121 (`command -v hciconfig ... || return 2`), 346, 777, 937
- evidence: `elif hci_alive; then resp_after=yes; else resp_after=no`, `{ ... ! hci_alive; }` -> trial_result=failed, and `start` prints "Controller is not responding" for any non-zero.
- why it matters: on a machine without hciconfig a manual `ok` records trial_result=failed / responds_after=no for a controller that was never asked; return 2 was written to mean "unknown".
- confidence: confirmed

### Failed trial with bt1_status=not_observed counts as a survival in both reports
- severity: Medium
- kind: code-defect
- where: tools/bt-trial:754-771 (bt1_status independent of trial_result), 777-778; tools/lib/trial-summary.awk (`tot[k]++ ... if (bs == "confirmed") {... if (tr == "failed") h[k]++ }`); tools/lib/trial-sco-table.awk (`f = (o == "confirmed")`)
- evidence: a manual `bt-trial hang` (or `ok` with a dead controller) on a window without a logged `tx timeout` gives bt1_status=not_observed + trial_result=failed. The row enters tot[k] but neither h[] nor inc[], and the SCO table counts it in the "survived" column. No warning line counts such rows.
- why it matters: summary.awk's own comment says miscounting a failure as a survival is "the one direction an error here must never take".
- confidence: likely (logic read, not run)

### bt-trial: header/usage text stale or truncated
- severity: Low
- kind: doc-vs-code
- where: tools/bt-trial:9, 1249, 364; tools/bt-trial-audit:19-22
- evidence: line 9 "bt-trial abort   discard the open trial" but code (1140-1175) renames the directory to `.aborted-<stamp>` and deletes nothing unless `--discard`. Usage `sed -n '2,18p'` (1249) lists no `status`, `autostart`, `autostop`, `abort --discard`, and cuts mid-sentence ("...the operator's steps with"). `start` prints `protocol | sed -n '3,10p'` (364): since the BELIEVED paragraph was added to step 0 this prints only step 0 and the line "1. bt-trial start <build>"; steps 2-7 are not shown.
- confidence: confirmed

### bt-trial header comment claims bt-state sends raw HCI; it is probe-free since 2026-09-18
- severity: Low
- kind: stale
- where: tools/bt-trial:880-882; tools/bt-state:40-48 (`PROBE=0`, `--probe` only)
- evidence: bt-trial: "Other raw-HCI probes happen and are NOT counted here: ... every bt-state invocation, which does the same". bt-state: "PROBE-FREE BY DEFAULT since 2026-09-18 (R2-94)".
- confidence: confirmed

### bt-snapshot header says bt-trial autostop issues HCI Read_Local_Name at every shutdown (stale)
- severity: Low
- kind: stale
- where: tools/bt-snapshot:20-23; tools/bt-trial:433-441
- evidence: bt-snapshot: "`bt-trial autostop` is the cautionary example — its hci_alive() issues an HCI Read_Local_Name at every shutdown". bt-trial: "PASSIVELY, since 2026-09-19 ... BT_TRIAL_PROBE=1 restores the old behaviour".
- confidence: confirmed

### bt-trial-audit claims independence from bt-trial's detectors; the patterns are identical
- severity: Low
- kind: doc-vs-code
- where: tools/bt-trial-audit:15-20, 52-55; tools/bt-trial:294, 688-697
- evidence: audit: "IT DOES NOT SHARE bt-trial's DETECTORS ... The patterns below are written independently". RE_RESET='reset (full|high|low)-speed USB device|Resetting usb device|usb_queue_reset_device', RE_RELOAD='deregistering interface driver btusb', RE_TIMEOUT='command( 0x[0-9a-f]+)? tx timeout' are the same alternatives as bt-trial's KJ_RE / n_reset / n_reload / tmo greps. The positive control only proves they match the author's own control lines.
- why it matters: the stated safeguard (an independent regex cannot share a blind spot) does not exist; it is a second copy, as the stage-2 / journal.sh comments already warn against.
- confidence: confirmed

### bt-trial-audit: unreadable journal for a window reads as "agrees"
- severity: Medium
- kind: code-defect
- where: tools/bt-trial-audit:215-223, tools/lib/journal.sh:194-199 (bt_journal_lines)
- evidence: `W=$(bt_journal_lines ... )` is `bt_journal ... 2>/dev/null | grep -E`; status and stderr are discarded, so a failed read, a read with no journal files (exit 0) or a partial read gives W="" -> n_*=0 -> expect=none -> a recorded `perturbed=none` / `not_observed` is reported as agreeing. Only boot enumeration is guarded. Conversely a recorded `perturbed=unknown` (bt-trial:711) is reported as DISAGREES (expect none) with no mention it is the "could not read" marker.
- why it matters: exact class of defect (journal exit 0 read as "checked, zero") the project documents fixing in bt-trial; the audit is the control meant to catch it.
- confidence: likely

### lib/journal.sh fast path discards per-file reader failures
- severity: Medium
- kind: code-defect
- where: tools/lib/journal.sh:262-285 (bt_journal_kernel_fast)
- evidence: `[[ -r "$f" ]] || continue` skips unreadable files; each `journalctl --file="$f" ... 2>/dev/null &` has no exit status collected; result is `cat` of the .out files, rc 0 (or 1 only when empty AND --grep given); with no --grep and nothing read it prints "-- No entries --" and returns 0.
- why it matters: a non-root caller or one corrupt/vanished file yields a silently partial kernel journal with exit 0, which callers (bt_journal_count, bt_journal_lines, bt-snapshot, bt-archive --check "ln") read as "checked, N". Real journalctl would fail or say "No journal files were opened".
- confidence: likely

### bt-trial close: several unbudgeted journalctl reads sit between the verdict and the results row
- severity: Medium
- kind: code-defect
- where: tools/bt-trial:736-737 (`journalctl -u bt-hang-watchdog`), 900-902, 907-908, 923-925 (`-u bt-health-snapshot...`, `-u bt-trace`), 980 (`-b -1 -n 400`), 1004 (`--list-boots`); row at 1031-1035
- evidence: only the -k reads (567, 1020) run under `timeout "${BT_TRIAL_SCAN_BUDGET:-20}"`. Comments at 989-1001 and 1037-1044 say the row was lost twice to unbounded reads before the row and that "every budget above protects" it. These -u reads have no timeout and no -p/--grep.
- why it matters: if one is slow on a dynamic-debug day the 30/90 s stop timeout kills the close before the row, the loss the file claims to have closed.
- confidence: needs-check (journalctl -u cost on the real journal not measured)

### bt-trial: journal reads for probes/aborts/t_probe/prev_shutdown ignore failures (the pattern the file fixed for -k)
- severity: Low
- kind: code-defect
- where: tools/bt-trial:900-908, 923-925, 980-981
- evidence: `journalctl ... 2>/dev/null | grep -c ... || true` with a numeric 0 fallback; `${probes:-?}` is never "?" because grep -c prints 0. A failed or empty read is recorded as `probes=0`, `btmon_aborts=0`, `probe_to_timeout=?`.
- why it matters: the file's own comment (722-728) says unreadable evidence must not become negative evidence; these columns are only "lower bounds" but are recorded as 0 when journal_files=0.
- confidence: confirmed

### bt-trial journal seam: bt-trial calls journalctl directly (documented), bt-trial-audit does not
- severity: Low
- kind: other
- where: tools/bt-trial:306, 457, 523, 567, 737, 900, 907, 923, 980, 1004, 1020, 1223; tools/bt-journal-files:58 (`journalctl --rotate`); tools/bt-archive:402 (SEAM-ADVICE, printed text only)
- evidence: bt-trial-audit, bt-retention, bt-archive, bt-backup-journal, bt-snapshot all go through bt_journal. bt-trial is exempt per lib/journal.sh:52-69 ("bt-trial and bt-incident remain sandbox-only"), but that paragraph only justifies it for actuation; bt-trial's -u and --list-boots reads are plain reads and the header comment at bt-trial:519-520 explains only the -k stderr case. `status` (1223) also bypasses. bt-journal-files --rotate is an action, correct to bypass. No other bypass in my part.
- confidence: confirmed

### bt-archive --replace / sweep can delete a more complete archive; --replace undocumented in usage
- severity: Medium
- kind: code-defect
- where: tools/bt-archive:95-99 (--replace comment), 279-293, 8 (usage `sed -n '2,8p'`)
- evidence: "requires the operator to have been told which file is defective" but nothing checks that; `rm -f "$stale"` removes every other `boot-<id>.export.*` (a good .zst) after writing a new .gz without comparing counts. Usage (`-h` prints lines 2-8) omits `--replace`; only --list/--check/--repair shown.
- confidence: confirmed (code), likely (impact)

### bt-snapshot hardcodes USB path 3-3
- severity: Low
- kind: code-defect
- where: tools/bt-snapshot:177 (`[[ -e "$SYSFS/3-3" ]] && PRESENT=yes`), 128 (`usb 3-3` filter)
- evidence: bt-trial:938-939 and bin/bt-mark resolve by VID/PID because "after a reset it can re-enumerate at a different address". bt-snapshot reports `controller on bus no` for a present controller on another port/after re-enumeration, and f-usb.log misses its lines.
- confidence: confirmed

### bt-snapshot writes raw unsanitised cuts under /var/tmp with no retention note
- severity: Low
- kind: rule-vs-practice
- where: tools/bt-snapshot:48-50 (`DEST=${BT_SNAPSHOT_DIR:-/var/tmp/bt-snapshots}`)
- evidence: raw captures (kernel/all journal of a boot) are placed in /var/tmp, which systemd-tmpfiles normally ages out; the tool states no copy-out. reviews/review-comprehensive-code-review-20261019-014718.md:454 (SN2) says the opposite worry (unbounded growth). Whether tmpfiles cleans /var/tmp on this machine: needs-check.
- confidence: needs-check

### bt-exhibit new: option without value loops forever
- severity: Medium
- kind: code-defect
- where: tools/bt-exhibit:76-83
- evidence: `--claim) claim="${2:-}"; shift 2 ;;` inside `while (( $# ))`; with `--claim` as the last argument `shift 2` fails (count out of range) without shifting, so the loop never ends (verified with a bash snippet: $# stays 1). Same for --why/--cmd/--boots.
- confidence: confirmed

### bt-exhibit help is cut off mid-example
- severity: Low
- kind: doc-vs-code
- where: tools/bt-exhibit:2,30 (`sed -n '2,30p'`)
- evidence: output ends at the `--claim ... \` line of the example; the `--why`/`--cmd` lines (31-33) are not printed.
- confidence: confirmed

### bt-retention end-of-run text contradicts the code and the header on the capture time
- severity: Low
- kind: contradiction
- where: tools/bt-retention:55-60 and 233-237 (code at 230-246) vs final message 285-289
- evidence: header/code: "THE CAPTURE TIME IS STILL USED — IN THE ONE DIRECTION IT CANNOT LIE" (exhibit captured before oldest boot => GONE, counted in `bound`). Final "NOT JUDGEABLE" note: "The capture time in the provenance is deliberately not used for this".
- confidence: confirmed

### lib/evidence-window.sh: "written once" prefix is duplicated in the reader
- severity: Low
- kind: stale
- where: tools/lib/evidence-window.sh:68-70 (BT_EW_PREFIX "so it is written once") vs 76-86 (bt_ew_read awk uses its own literal `"**Evidence window.**"` and regex)
- confidence: confirmed

### bt-backup-journal: --status/--dry-run print "re-archiving in full"; "Read-only" claim
- severity: Low
- kind: doc-vs-code
- where: tools/bt-backup-journal:121-123, 63
- evidence: `PREFIX on disk — re-archiving in full` is printed before the STATUS/DRY branches, so a status or dry run says it is re-archiving. Header says "Read-only with respect to the system" while it writes archives (to DEST).
- confidence: confirmed

### bt-trial abort --discard deletes untracked trial evidence
- severity: Low
- kind: rule-vs-practice
- where: tools/bt-trial:1150-1160
- evidence: `rm -rf "$dir"` allowed whenever no file in it is git-tracked; newly captured evidence is untracked "by definition" (own comment 1142-1143). Opt-in and documented, but contradicts "evidence is never deleted".
- confidence: confirmed

### bt-journal-files has no repository guard (bt-archive/bt-snapshot do)
- severity: Low
- kind: rule-vs-practice
- where: tools/bt-journal-files:34 (`DEST_ROOT=${BT_JOURNAL_FILES_DIR:-/root/bt-journal-archive/files}`), no `refuse` for a path inside the repo; compare tools/bt-archive:71-76, bt-snapshot:60-63
- evidence: unsanitised journal files (MACs/BSSIDs) can be written inside the checkout by an override; the other two tools refuse mechanically.
- confidence: confirmed

---

# Part: code-tools-b

### bt-sco --window (the index's own invocation) loops forever; same trap in 5 more tools
- severity: High
- kind: code-defect
- where: tools/bt-sco:44-49 (while (( $# )) ... `--window) WINDOW="${2:-2}"; shift 2 ;;`), docs/tooling-index.md:84 ("`tools/bt-sco --window`"); same pattern tools/bt-actions:68-72 (-b/--since/--until), tools/bt-capdiff:60-64, tools/bt-context:41-44 (-b, -C), tools/bt-logvolume:44-48, tools/bt-phase:67-70; contrast tools/bt-stage2:36-37 (`shift 2 || exit 2`)
- evidence: `--window) WINDOW="${2:-2}"; shift 2` — the `:-2` default implies bare `--window` is valid, and the index shows it bare. With only one argument left `shift 2` fails without shifting (no `set -e`), $# stays 1, the loop never ends. Reproduced the loop shape in a scratch bash (`set -- --window` -> LOOPS). Same for `bt-sco --dir` as last arg and `bt-actions -b`, `bt-context -C`, etc. as last arg.
- why it matters: the documented one-liner for "Compare SCO event windows" spins at 100% CPU instead of running; a typo'd trailing flag hangs rather than erroring. (I did not run the tool; shape reproduced separately.)
- confidence: confirmed (code read, loop shape reproduced outside the repo)

### bt-sco usage text omits --window and -h cuts off the Usage block
- severity: Medium
- kind: doc-vs-code
- where: tools/bt-sco:27-31 (Usage lists only `[--dir <trace-dir>] [--raw]`), tools/bt-sco:48 (--window implemented), tools/bt-sco:49 (`-h|--help) sed -n '2,26p'`), docs/tooling-index.md:84
- evidence: usage line `#   bt-sco [--dir <trace-dir>] [--raw]`; code accepts `--window`; help prints lines 2-26, which ends before the "# Usage:" line (27), so `bt-sco -h` prints the history but not the options. Header line 24 says "Use --window" but never gives its argument (seconds, default 2).
- why it matters: the only option the header tells you to use is undocumented in the usage and is unreachable from -h.
- confidence: confirmed

### bt-window header says bt-status/bt-state run `hciconfig name`; they have been probe-free since 09-18
- severity: Medium
- kind: stale
- where: tools/bt-window:8-11 vs tools/bt-state:40-49,59-70, tools/bt-status:22-24, tools/bt-incident:104-108, docs/tooling-index.md:66
- evidence: bt-window: "`bt-status` and `bt-state` run `hciconfig <dev> name`, which is a real HCI command/response exchange"; bt-state: "PROBE-FREE BY DEFAULT since 2026-09-18 ... Liveness is now a deliberate act: `--probe`"; index line 66 "probe-free by default".
- why it matters: a reader of the window tool (the one meant to be consulted in an open wedge) is told to avoid the two commands that are in fact safe, and the premise of the tool is stated wrongly.
- confidence: confirmed

### Probe contract verified: no default path sends an HCI command (note, no defect)
- severity: Low
- kind: other
- where: tools/bt-state:59-70 (hciconfig/btmgmt only under (( PROBE ))), tools/bt-diagnose:125-134 (only with --probe), tools/bt-status:24,141-147 (PROBE passed through only if --probe), tools/bt-incident:104-114 (calls sibling bt-state without --probe)
- evidence: grep of all 28 tools for hciconfig|hcitool|btmgmt|bluetoothctl|usbfs|/dev/bus: hciconfig/btmgmt appear only in those two gated blocks; bt-usbstate:28 says "nothing through usbfs". One default-path residual: tools/bt-state:78 runs `bluetoothctl devices Connected` on every run (D-Bus query to bluetoothd, not an HCI command, in my reading; not run). README:119-121 and BRIEF:470 match the code for bt-diagnose/bt-state/bt-status/bt-incident.
- why it matters: records that the claim holds; the bluetoothctl call is the only thing worth a one-line caveat in the "probe-free" statement.
- confidence: likely (bluetoothctl behaviour not executed)

### bt-diagnose exits 0 "NOT observed" when zero boots could be examined
- severity: Medium
- kind: code-defect
- where: tools/bt-diagnose:155-167 (boots counted only if `bt_journal -k -b "$b"` succeeds), tools/bt-diagnose:44-54 (timeouts==0 -> return 0), README.md:119-120
- evidence: `bt_journal -k -b "$b" >/dev/null 2>&1 || continue` leaves boots=0, timeouts=0; verdict prints "No HCI command timeouts were found in the retained kernel journal." and returns 0. Journal access denied for a non-root user without systemd-journal group, or no persistent boots, gives this path. README: "2 = cannot determine".
- why it matters: a stranger running the standalone tool as an unprivileged user can get a green "not observed" from an empty search; the contract says that case is exit 2. (The verdict text does hedge, but the exit code does not.)
- confidence: likely (depends on journal.sh behaviour when unreadable; code path read)

### README "every tool takes BT_VID/BT_PID" and "bt-diagnose ... work on any controller" — partly false
- severity: Medium
- kind: doc-vs-code
- where: README.md:132-133; tools/bt-diagnose (no BT_VID/BT_PID anywhere; autodetects, :85-94,115); tools/bt-status:93 and tools/bt-postmortem:140, tools/bt-window:30, tools/bt-usbstate:41, tools/bt-boot-provenance:43, tools/bt-stage2:88, tools/bt-health-report.sh:56-57 (default 13d3:3503 with override); tools/bt-state:22-31 (autodetects, else 13d3:3503)
- evidence: grep -L BT_VID over the 28 tools lists 21 with no BT_VID/BT_PID reference (bt-actions bt-boot-list bt-boot-stats bt-boots bt-capdiff bt-context bt-crash bt-ctrl-window bt-diagnose bt-env-history bt-fault-window bt-guards bt-incident bt-interval bt-logvolume bt-phase bt-sco bt-timeline.sh bt-ui-capture bt-verify-kernel-mechanism sanitize-logs.sh). Most are device-agnostic log tools, so the "any controller" part holds, but the sentence "every tool takes BT_VID/BT_PID" does not, and setting BT_VID on bt-diagnose (the one README names) does nothing. Also bt-status:90-94 verdict uses BT_VID default 13d3 without the autodetect that bt-state has, so on another controller with no hci it can say "Enumerated but btusb has created no adapter"/"Off the USB bus" about the wrong device.
- why it matters: a stranger with a different controller is told a pin knob exists everywhere.
- confidence: confirmed

### "Standalone, no installation": bt-diagnose/bt-state/bt-boots/bt-boot-list depend on tools/lib/journal.sh (in tree) — OK; but bt-status/bt-incident fall back to installed copies
- severity: Low
- kind: doc-vs-code
- where: README.md:110,295; tools/bt-diagnose:20-35, tools/bt-boots:21 (fallback /usr/local/bin/bt-boot-list), tools/bt-status:35-38 (REPO fallback /root/exp/qca9377-bt-hang), tools/bt-incident:114 (`command -v bt-timeline`: PATH only)
- evidence: bt-diagnose/bt-state resolve siblings next to the script first, so "no installation" holds for the five named. bt-incident:101 calls `bt-timeline` from PATH (installed copy) and silently skips the merged timeline if not installed, yet the session is then described as having one (header line 11: "a merged timeline"). bt-status hard-codes /root/exp/qca9377-bt-hang as a search location.
- why it matters: minor; incident sessions from a bare clone lack timeline.txt without a message.
- confidence: likely

### sanitize-logs.sh: claims match code for MAC/BSSID/IPv4; IPv6 and other forms not covered or verified
- severity: Low
- kind: other
- where: tools/sanitize-logs.sh:111-113,165,182,197-218; README.md:296-299
- evidence: README "replaces MACs, BSSIDs and IPv4 addresses ... and verifies none survived": true (pass 2 colon/underscore/dash, case-insensitive; pass 3 IPv4; verification greps -i for the same forms; builds in temp, mv after pass; mawk gate at :81-135 probes both directions). Gaps: no IPv6 pattern or verification (link-local fe80:: EUI-64 addresses embed the MAC; a MAC in `aabb.ccdd.eeff` or bare 12-hex `AABBCCDDEEFF` form is untouched and passes verification). Verification exempts any `aa:bb:cc:00:00:NN`, so a real address of that shape would pass. Final line says "no MACs, BSSIDs, UUIDs or IPv4 addresses remain" which is scoped to those forms and is accurate. README does not mention UUIDs being replaced (tool does).
- why it matters: only matters if such forms occur in published logs; README does not claim them.
- confidence: confirmed (code read; tool not run)

### Index lists git-ignored paths as if they were repository files
- severity: Medium
- kind: broken-reference
- where: docs/tooling-index.md:86 (`tmp/raw-archive-timer/install-timer.sh` "installed by `install.sh` and by ..."), :126-134,151 (`cache/...`, `tmp/patchwork/survey/`, `tmp/backport-check/` etc.), :33 (`/var/tmp/bt-snapshots/latest/`)
- evidence: `git check-ignore -v tmp/raw-archive-timer/install-timer.sh` -> `.gitignore:22:tmp/`. A scan of every backticked path in the index against `git ls-files` found these ignored-and-untracked: tmp/raw-archive-timer/install-timer.sh, tmp/backport-check/, tmp/bot-ci-local/, tmp/btusb-build/, tmp/btusb-matrix/, tmp/kernel-regenerated/, tmp/series-backport-check/, tmp/supported-commands-survey.tsv, tmp/mesh-tester-ci/bzImage-val-btnext-control, tmp/ci-local/base-cache/, tmp/ci-local/controls-20261027T140703Z, cache/{bluez,linux,linux-6.1.y,linux-6.12.y,linux-bt-next,full-bt-next,full-6.1.y,lore-stable-2.git,sparse,ubuntu-src,sent-upstream,action-ci,bluez-upstream,...}. Also `addr-pseudonym.py` (line 89) is "kept separately ... never in this checkout" (stated honestly). Install.sh itself (537-538,680) installs systemd/bt-raw-archive.{service,timer}, so the "and by tmp/..." installer is redundant and absent from a fresh clone.
- why it matters: a reader following the index from a fresh clone hits missing paths; only some entries say "git-ignored".
- confidence: confirmed

### Executables missing from the tooling index
- severity: Medium
- kind: other
- where: docs/tooling-index.md (whole); git ls-files mode 100755 under devtools/ and scripts/
- evidence: not mentioned anywhere in the index (path or basename): devtools/access-classify, devtools/assert-test-catches, scripts/dbg-autostop-calls.sh, scripts/exhibit-relabel-boot-id.py, scripts/export-kernel-review.sh, scripts/patch-id-compare.sh, scripts/prove-ci-cwd.sh, scripts/prove-ci-stub.sh, scripts/prove-dr-followup.sh, scripts/prove-dr-review.sh, scripts/prove-neg-search.sh, scripts/r2-checks-2.sh, scripts/r2-checks.sh, scripts/suite-timing.sh, scripts/uncovered-code-report.py. All tools/*, bin/* executables ARE indexed (bin/bt-hang-watchdog, bin/bt-mark, bin/bt-trace by basename only). Index states "Every routine question in this project already has a tool."
- why it matters: index is the stated entry point; these are unreachable from it (several are probably one-off proofs, but that is not said).
- confidence: confirmed (mechanical: basename search with word boundaries; may miss mentions with unusual spelling)

### Index tools/test-runner is a path inside the BlueZ checkout, not this tree
- severity: Low
- kind: broken-reference
- where: docs/tooling-index.md:132 (`tools/test-runner` in QEMU), also `doc/tester.config`, `test/test-functional`
- evidence: `tools/test-runner` not in git ls-files; context is BlueZ's emulator tester. Ambiguous next to this repo's own tools/ paths.
- confidence: likely

### bt-incident --help prints a truncated header
- severity: Low
- kind: doc-vs-code
- where: tools/bt-incident:30,41 (`sed -n '2,12p' "$0"`)
- evidence: header block runs to line 13 ("# Binary btsnoop captures are referenced..."), help stops at line 12, cutting the sentence about writing evidence/sessions/ and the NOTES.md skeleton. Cosmetic.
- confidence: confirmed

---

# Part: code-scripts-a

## code-scripts-a findings

### build-btusb-stable-matrix.sh: -Werror fallback is lost in a command-substitution subshell
- severity: Medium
- kind: code-defect
- where: scripts/build-btusb-stable-matrix.sh:53-67, :75
- evidence: `werror=KCFLAGS=-Werror` ... inside build(): `werror=""` / `build "$label"` when the control fails; called as `un=$(build unpatched)` and `pa=$(build picked)`. The assignment happens in the $(...) subshell, so the parent still has werror=KCFLAGS=-Werror. Header :6-7 promises "with -Werror where the tree's own control build takes it".
- why it matters: on a line whose control cannot take -Werror the picked build still runs with -Werror (spurious FAILED -> rc=1), and the "(-Werror)" printed in the result column (:77) is based on the parent value, so it can claim -Werror for a build that retried without it.
- confidence: confirmed

### build-btusb-stable-matrix.sh: "<commit>" is generic but the pass condition is hard-wired to 13d3:3503
- severity: Medium
- kind: doc-vs-code
- where: scripts/build-btusb-stable-matrix.sh:10, :74, :76
- evidence: usage `<commit> [<stable-branch>…]`; `entry=$(grep -c "0x13d3, 0x3503" ...btusb.c)`; `[[ "$pick" == OK && "$pa" == rc=0* && "$entry" == 1 ]] || rc=1`; header "Exit 0 when every cherry-pick and every picked build succeeds" (no mention of the entry check).
- why it matters: for any other commit the script exits 1 even if all picks/builds succeed; and if a line already has the entry (count would be 1 before pick, pick conflicts/empty) result semantics differ from the documented exit contract.
- confidence: confirmed

### build-btusb-stable-matrix.sh: default branch list is a dated snapshot (no 7.3.y)
- severity: Low
- kind: stale
- where: scripts/build-btusb-stable-matrix.sh:11, :22
- evidence: "default branches: the lines live on kernel.org on 2026-10-02"; list starts at stable/linux-7.2.y. 7.3 was released 2026-10-18 (BRIEF facts).
- why it matters: a rerun without arguments silently omits the newest line; header says dated, so Low.
- confidence: likely

### build-bluetooth-fulltree.sh: failed `patch` is not detected, "patched" build can pass unpatched
- severity: Medium
- kind: code-defect
- where: scripts/build-bluetooth-fulltree.sh:46, :14
- evidence: `patch -p1 < "$PATCH" | grep -E "Hunk|FAILED"` under `set -uo pipefail` (no -e), no check of patch status (pipeline status of the whole `if` body is ignored; a reject leaves .rej and a partly or un-patched tree). Header :12-13 "Exit 0 when both builds succeed".
- why it matters: a patch that fails to apply (or applies only partly) still yields "patched make rc=0" and exit 0, a false positive for the very check that backport claims rest on. The sibling build-bluetooth-module.sh:44 does check `patch ... || exit 1`.
- confidence: confirmed

### build-btusb-module.sh: exits 0 if make "succeeds" but produced no btusb.ko
- severity: Low
- kind: code-defect
- where: scripts/build-btusb-module.sh:55
- evidence: `[[ -f "$KO" ]] || exit "${rc:-1}"` - rc is make's status; rc=0 with no .ko gives exit 0 and no vermagic check.
- why it matters: a zero without the artefact; project rule "a zero needs a positive control".
- confidence: confirmed

### build-bluetooth-module.sh: --ubuntu option is undocumented and hard-codes a retired tree
- severity: Low
- kind: doc-vs-code
- where: scripts/build-bluetooth-module.sh:6-8, :28
- evidence: usage block lists no --ubuntu; code `[[ "${1:-}" == "--ubuntu" ]] && { SRC="$HERE/cache/ubuntu-7.0.0-31"; shift; }`. Also order dependence: --ksrc must precede --ubuntu/--krel.
- why it matters: kernel 7.0.0-31 is long past (machine is -43); the option points at a tree that is local-only (cache/) and unmentioned.
- confidence: confirmed

### bt17-arm-usb-debug.sh: --off reports success without checking, and hard-codes this laptop's bus
- severity: Low
- kind: code-defect
- where: scripts/bt17-arm-usb-debug.sh:26-31, :41
- evidence: --off branch has no writability/root check (`echo ... >"$ctl"` errors ignored) then prints "USB core debug off"; `pkill -f "bt17-usbmon-capture" && echo ...` prints nothing if none. Line 41 `|| echo 3` fallback and "3-3" hard-coded.
- why it matters: "off" is printed even when debugfs write failed. Safety: script does not touch btusb/HCI (consistent with its header); no guard problem.
- confidence: confirmed

### bluez-tester-compare.sh: a tester that produced no Test Summary yields "no case passes ... fails" and exit 0
- severity: Medium
- kind: code-defect
- where: scripts/bluez-tester-compare.sh:95-108 (verdicts), :128-129, :143-156, :171-173
- evidence: verdicts() does `if not m: sys.exit(0)` (empty verdict file, no error); the compare step only requires the verdict files to exist; with no cases it prints "== t: 0 case names" and "REGRESSIONS: 0"; final `(( rc == 0 )) && echo "RESULT: no case passes on the base and fails with the patches"`. A case present on base but missing on patched is only tagged "(case removed)" and not counted (:152).
- why it matters: if test-runner crashes/times out (qemu failure, kernel mismatch) on both sides, or the patched side dies midway, the verdict is a clean zero without a positive control. Header :28 only promises exit 1 on regression.
- confidence: confirmed (by reading; not run)

### bluez-tester-compare.sh: --help prints two non-comment lines; undocumented exit 2
- severity: Low
- kind: doc-vs-code
- where: scripts/bluez-tester-compare.sh:53, :28-29, :112
- evidence: `-h|--help) sed -n '2,30p' "$0"` but the header ends at line 28, so `set -uo pipefail` and `export LC_ALL=C` are printed; build failure sets `rc=2` (:112) while header :28 documents only "Exit status 1".
- confidence: confirmed

### bluez-release-contains.sh: a bad tag is reported as "NOT in <tag>"; exit status always 0
- severity: Medium
- kind: code-defect
- where: scripts/bluez-release-contains.sh:6-7, :25-29
- evidence: `elif git -C "$REPO" merge-base --is-ancestor "$sha" "$TAG"; then ... else echo "NOT in $TAG  $line"`. is-ancestor returns 1 for "not ancestor" and 128 for an unknown/typo'd tag; both go to the else branch. Last command is an echo, so the script exits 0 whatever it printed; no usage message for missing args (`REPO="$1"` -> "unbound variable").
- why it matters: a mistyped or not-fetched tag gives eleven "NOT in" lines, the wrong claim for a release check (results/bluez-5.88-release-check-2026-11-07 is the cited use). Commit list itself matches README's 11 BlueZ commits.
- confidence: confirmed

### backport-check.sh: `| head -1 || echo 'no release tag'` fallback can never fire
- severity: Low
- kind: code-defect
- where: scripts/backport-check.sh:27
- evidence: `echo "in:      $(git ... tag --contains "$C" --list 'v*' | head -1 || echo 'no release tag')"` - the pipeline status is head's (0), so an unreleased commit prints an empty "in:" line.
- confidence: confirmed

### backport-check.sh: default stable list is a 2026-10-02 snapshot; no 7.3.y
- severity: Low
- kind: stale
- where: scripts/backport-check.sh:7-9, :20
- evidence: "lines kernel.org listed as live on 2026-10-02"; list starts at 7.2.y; (header does say to check releases.json). Same as build-btusb-stable-matrix.sh:22.
- confidence: likely

### bluez-accepted-survey.py: page cache is never refreshed, so "most recent PAGES x 100" is frozen at first run
- severity: Low
- kind: doc-vs-code
- where: scripts/bluez-accepted-survey.py:39-42, :94, header :8-11
- evidence: `if os.path.exists(path): return json.load(open(path))` for `patches-p{n}.json` and per-patch checks/comments (states change, e.g. new, then accepted).
- why it matters: a re-run reports old states/pages with no warning; bluez-human-ci-mentions.py reads the same cache. Intentional ("claim ships with its data") but not stated as a refresh caveat.
- confidence: likely

### archive-budget-check.py: empty archive root is silent (zero without a message)
- severity: Low
- kind: other
- where: scripts/archive-budget-check.py:6, :51-53 (archive/ is gitignored, .gitignore:43, so absent in the checkout: fine)
- evidence: default root `<project>/archive`; header names "archive/bt-trace, archive/hci-capture". With a missing directory it prints a note and returns 0 even under --warn-only; a root with no MANIFEST.tsv store prints nothing and returns 0.
- why it matters: for a session-start-hook check, "nothing found" is indistinguishable from "all OK"; (it does say why for the missing-dir case, so only the empty-root case lacks a message).
- confidence: confirmed

### btusb-has-device.py: any error exits 1, the same as "ABSENT"; unsupported compression reads as ABSENT
- severity: Medium
- kind: code-defect
- where: scripts/btusb-has-device.py:339, :347-355
- evidence: header "Prints FOUND with the count, or ABSENT; exit 0 / 1." Missing file, unreadable file or zstd failure (`check=True`) raise an uncaught exception, whose exit status is also 1. A `.ko.xz`/`.ko.gz` is read as raw compressed bytes (only `.zst` is decompressed) and reports ABSENT.
- why it matters: the script is the check for "does this btusb carry the 13d3:3503 entry"; a typo'd path or a differently compressed module looks like "entry missing" (the BT-1 verdict). No positive control built in.
- confidence: confirmed

### bt17-provoke.py: exit status 0 on FAILURE; a vanished device makes the loop spin instead of stopping
- severity: Medium
- kind: code-defect
- where: scripts/bt17-provoke.py:301-319, :325, :328-329
- evidence: on no answer it logs "FAILURE at cycle" and `break`s, then main() returns None (exit 0). If the controller disappears from USB (the failure BT-17 hunts), `rd(.../runtime_status)` returns "<No such file or directory>", which is != "suspended", so line 306-309 logs "device <...> after 10 s (something keeps it awake); waiting" and `continue`s until --hours elapses; the cycle counter is not advanced. `s.send()` on a gone hci0 would raise an uncaught OSError with no log line.
- why it matters: the one outcome the tool exists to detect is reported as "waiting" or as an exit 0; docstring :193 promises "It stops at the first command without an answer".
- confidence: likely (reasoned from code, not run)

### bt17-provoke.py: docstring "Device addresses are never read or printed" vs full dmesg dump
- severity: Low
- kind: doc-vs-code
- where: scripts/bt17-provoke.py:197-198 vs :314-315
- evidence: `subprocess.run(["dmesg","-T"], ...).stdout[-200000:]` is written to provoke-<stamp>-dmesg.txt under /var/log/bt-health/ (local); kernel log can carry device addresses.
- why it matters: statement is true of the script's own reads only; the saved file is local-only, but it is the kind of file that must never be published (not said here).
- confidence: confirmed
- note: safety guard present (needs --yes, prints warning); sends HCI Read Local Name only when run by the operator.

### bt-device-record.sh: unreadable /var/lib/bluetooth (non-root) reports "no stored device matches"
- severity: Medium
- kind: code-defect
- where: scripts/bt-device-record.sh:15-16, :23
- evidence: `for f in /var/lib/bluetooth/*/*/info; do [[ -r "$f" ]] || continue` - as a normal user the glob does not expand (directory is 0700 root), the loop body never runs, and the script prints "no stored device matches: $want" with exit 1. Header does not say root is needed.
- why it matters: "could not look" is reported as "nothing matches"; a zero/negative without a positive control.
- confidence: likely (directory permissions are the stock bluez ones; not checked on this machine)

### bt-trace-archive.py: machine-specific default /root/bt-trace-keep; digest set recorded but never compared
- severity: Low
- kind: other
- where: scripts/bt-trace-archive.py:20, :35, :95, :127-132
- evidence: `KEEP_DIR = os.environ.get("BT_TRACE_KEEP_DIR", "/root/bt-trace-keep")`; manifest `done.setdefault(cells[0], set()).add(cells[2])` stores sha256 per name but `if name in done: skipped += 1; continue` ignores it (the two branches at :127-132 are identical), so a same-named capture with different content is skipped as "already archived". Exit 1 (failures) is not in the header, which lists only exit 3.
- why it matters: the /root path is one machine's layout (documented as "copies kept by hand", not marked local-only); name-only dedup contradicts the apparent design (digest, `final` name with digest at :145).
- confidence: confirmed

### boot-bt-summary.sh: `|| echo "   (none)"` also covers journalctl failure
- severity: Low
- kind: code-defect
- where: scripts/boot-bt-summary.sh:20, :22
- evidence: `journalctl -k -b "$B" ... --grep '...' || echo "   (none)"` - journalctl exits non-zero both for "no match" and for an unknown boot / no permission to read the journal; output says "(none)" in both cases. These summaries become published exhibits (README of scripts lists it).
- confidence: likely

### build-v2.sh: header still presents the v2 as awaiting the operator's decision (CB-02); v2 was sent 2026-09-21
- severity: Medium
- kind: stale
- where: scripts/build-v2.sh:48, :61-62; reviews/README.md:431; BRIEF.md:725-729; docs/tooling-index.md:137
- evidence: build-v2.sh: "changing ONLY what the list's CI bot flagged on 2026-09-19" / "Prepared for the operator's decision (CB-02); nothing here sends anything." reviews/README.md:431: "CB-02 | ... **fixed — v2 sent 2026-09-21 22:47 CEST on the operator's word**". BRIEF.md:726-727: "Operator's decision. **v2 is prepared in `patches/bluez/v2/`**" (both patches are in BlueZ 5.88 per README).
- why it matters: a reader of the script or BRIEF would think the v2 is still unsent. The earlier review (reviews/review-comprehensive-code-review-20261019-014718.md:2471 "BV1 ... Say so in their headers, or drop the default") was not applied to build-v2.sh or to build-bluetooth-module.sh's `--ubuntu`.
- confidence: confirmed (BRIEF line is outside my part; flagged for the lead)

### build-mails.sh: header says "the two BlueZ patch mails" and sends to patches/bluez, which now holds only the retired v1 pair
- severity: Low
- kind: stale
- where: scripts/build-mails.sh:2-14, :21-24
- evidence: loop is fixed to `for n in 0001 0002`; note path `patches/bluez/mail-notes/$n.txt` regardless of BT_PATCH_DIR. All later BlueZ sends live in patches/bluez/send-2026-10-13, send-2026-10-18, shared-mgmt, ... which the script cannot build. `ls "$PDIR"/"$n"-*.patch` with two matches would yield a two-word $src.
- confidence: confirmed (specific to the September pair; fine as a record)

### ci-local-publish.sh: if the repository sanitiser refuses (or is absent), the file stays in the tracked results dir with MACs/IPv4 unsanitised and the script exits 0
- severity: Medium
- kind: privacy
- where: scripts/ci-local-publish.sh:183-187, :212; tools/sanitize-logs.sh:7-8
- evidence: `if [[ -x "$REPO/tools/sanitize-logs.sh" ]]; then "$REPO/tools/sanitize-logs.sh" "$2" "$2" >/dev/null 2>&1 || echo "ci-local-publish: sanitize-logs refused $2" >&2; fi`. sanitize-logs.sh is "safe in place ... renamed only after verification passes", i.e. on refusal the previous content (only e-mail-elided) is left at $2. The script keeps going, prints "n file(s) from ... to ...", exit 0; a missing/non-executable sanitiser is skipped silently.
- why it matters: the stated purpose is to produce files fit to commit; a refused file (the one with an unmasked address) is indistinguishable in the exit status from a clean one.
- confidence: confirmed (by reading both scripts)

### ci-local-controls.sh: banner names btdev.c:479 as the PRE-EXISTING control, the check no longer requires it
- severity: Low
- kind: stale
- where: scripts/ci-local-controls.sh:98 vs :101-103, header :13-14
- evidence: `echo "### control 2: VLA must be NEW for smatch, with btdev.c:479 PRE-EXISTING"`; comment :101-102 "btdev.c:479 until A2 (7bc9684dc ...) removed it; any other VLA line since"; the grep at :103 accepts any `^PRE-EXISTING: .*Variable length array`.
- confidence: confirmed

### ci-run-images.sh: no argument check, hard-coded repo, no failure signal
- severity: Low
- kind: code-defect
- where: scripts/ci-run-images.sh:246-253
- evidence: with no run ids the loop is empty and the script exits 0 silently; a failed `gh` leaves $concl/$img empty and the line is still printed, exit 0. `repo=ivoitovych/qca9377-bt-hang` is fixed.
- confidence: confirmed

### ci-local.sh: exit 0 although checks did not run; header promises "2 = could not run"
- severity: Medium
- kind: code-defect
- where: scripts/ci-local.sh:78 (header "Exit status: 0 = no NEW finding, 1 = a NEW finding, 2 = could not run"), :713-766 (end), :583-585 (two_sided "git am failed unexpectedly"), :743 (kernel "git am failed" `continue`), :655-670 (functional)
- evidence: NOT RUN checks are only collected in SKIPPED and the script ends `log "RESULT: no NEW finding; not run: ${SKIPPED[*]}" ... exit 0`. Some NOT RUN paths do not even add to SKIPPED (`verdict "$check" "NOT RUN" "git am failed unexpectedly"; return` and `verdict "$check" "NOT RUN" "git am failed"; continue`), so the result line says plain "RESULT: no NEW finding". For TestFunctional a configure/build failure or missing junit writes "configure failed" / "functional: no junit result (...)" into both sides' findings, which classify as PRE-EXISTING (exit 4 -> "none new") and exit 0. verdict_from_classes also has no branch for classify exit codes other than 0/1/3/4.
- why it matters: a caller testing `$?` (ci-local-controls.sh does not, but pre-send flows may) gets a zero when e.g. smatch, ScanBuild or the whole functional suite did not run: "a zero needs a positive control". Exit 2 is never produced after the argument checks.
- confidence: confirmed

### ci-local.sh: checkpatch that fails to run counts as PASS
- severity: Medium
- kind: code-defect
- where: scripts/ci-local.sh:454-471
- evidence: `( cd "$cpdir" && perl "$CHECKPATCH" "${args[@]}" "$p" ) >"$out" 2>&1` - exit status not read; verdict is decided only by `grep -q '^ERROR:'` / `'^WARNING:'`; with no matches: `verdict checkpatch PASS "no ERROR or WARNING from checkpatch (version $(perl "$CHECKPATCH" --version ... | awk '/Version/{print $2}'))"` (the version would be empty if perl failed).
- why it matters: a missing perl module, a broken checkpatch.pl or a crashed run is reported as a clean pass (only ci-local-controls.sh's separate positive control would notice).
- confidence: confirmed

### ci-local.sh: header names cache/action-ci, default is cache/action-ci-bluez
- severity: Low
- kind: stale
- where: scripts/ci-local.sh:20 vs :104-106, :83-84
- evidence: header "read from bluez/action-ci (cache/action-ci, see results/ci-local-2026-10-10.md §T1 for the pinned commit)"; option list `--action-ci DIR ... (default cache/action-ci-bluez)`; comment :104 "cache/action-ci was found on 2026-10-27 to be a clone of the old fork".
- confidence: confirmed

### compile-mgmt-at.sh: apply check is inverted (`patch | grep -E "Hunk|FAILED" || exit 1`)
- severity: High
- kind: code-defect
- where: scripts/compile-mgmt-at.sh:165
- evidence: `patch -p1 -d "$OUT" < "$PATCH" | grep -E "Hunk|FAILED" || { echo "patch did not apply" >&2; exit 1; }`. GNU patch prints "Hunk #N succeeded at ... (offset ...)" only for offset/fuzz, "Hunk #N FAILED at ..." on a reject, and just "patching file ..." for a clean apply. The pipeline status is grep's: clean apply -> grep finds nothing -> "patch did not apply", exit 1; rejected hunk -> grep matches "FAILED" -> success, and the script goes on to compile a partly patched or unpatched mgmt.c and can print "patched make rc=0", exit 0. Header :150 "Exit 0 when both compiles succeed".
- why it matters: the "patched" compile result (used as proof that a kernel patch builds at another tip) can be a pass for a patch that did not apply, and a clean patch is reported as failing.
- confidence: likely (reasoned from patch's documented output; not run per BRIEF)

### desktop-capture-archive.sh: default budget 3 GB silently lowers the recorded budget the operator raised to 20 GB
- severity: Medium
- kind: doc-vs-code
- where: scripts/desktop-capture-archive.sh:242-245, :252; scripts/bt-trace-archive.py:114-115; scripts/archive-budget-check.py:9-10
- evidence: header "Budget: 3 GB by default ... raised to 20 GB the same night when 10 GB filled"; bt-trace-archive.py writes `BUDGET_GB` on every run from BT_ARCHIVE_BUDGET_GB; archive-budget-check.py: "Its budget is the BUDGET_GB file the archiver writes on every run".
- why it matters: a later run without --budget-gb (or without the env var) rewrites BUDGET_GB to 3 while the store holds up to 20 GB: the archiver stops with exit 3 ("BUDGET REACHED") and archive-budget-check.py reports FULL for a store the operator had sized. The operator's 20 GB decision exists only in a comment.
- confidence: likely

### commit-in-tree.py: documented "Exit 0; 2 on a usage error" - IndexError/CalledProcessError otherwise
- severity: Low
- kind: code-defect
- where: scripts/commit-in-tree.py:14, :34, :75
- evidence: `out.check_returncode()` (bad commit -> traceback, exit 1); `verdicts[0]` raises IndexError for a commit that touches no added-line files (e.g. deletions or merge). Exit code is 0 for ABSENT as well as PRESENT (documented, the verdict is text only).
- confidence: confirmed

### discovery-stop-race.py: btmon's exit status is ignored; a truncated decode reads as "never stopped"
- severity: Medium
- kind: code-defect
- where: scripts/discovery-stop-race.py:46-58 (packets()), :194-211
- evidence: `p.wait()` result discarded, `stderr=subprocess.DEVNULL`. capture-window.sh:150-154 documents that btmon can die with 134 on a BT-4 abort ("the decode is incomplete") and handles it; here an aborted btmon just ends the packet stream. Outcomes then read "never stopped in these traces" / "start with no reply in the trace" / "end not in trace".
- why it matters: counts in a published survey of discovery cycles can be inflated by a decoder crash with no warning, and a missing btmon is a bare traceback.
- confidence: likely

### discovery-stop-race.py: docstring vs code on which outcomes are listed
- severity: Low
- kind: doc-vs-code
- where: scripts/discovery-stop-race.py:23-24 vs :193, :210
- evidence: docstring "one line per cycle that is not 'IC first, stopped'/'cancelled, stopped'"; code excludes `("IC first, stopped", "cancelled, stopped", "off done first, stopped")` and prints the heading "cycles other than '<IC first | off done first | cancelled>, stopped'".
- confidence: confirmed

### device-adv-summary.py: usage line names a different file; no argument check
- severity: Low
- kind: doc-vs-code
- where: scripts/device-adv-summary.py:7, :12
- evidence: "usage: adv-summary.py <decode.txt> <address> ..." (the file is device-adv-summary.py); `path, addr, qfrom, qto = sys.argv[1:5]` gives a ValueError traceback on missing args. The address is matched case-sensitively against btmon's upper-case text.
- confidence: confirmed

### export-kernel-review.sh: describes a "held" branch and a brief kept off main; the patch is accepted upstream and REVIEW-TASK.md is on main
- severity: Medium
- kind: stale
- where: scripts/export-kernel-review.sh:2-4, :6-7, :81, :84-95; patches/kernel/REVIEW-TASK.md (tracked on main)
- why it matters: run as documented it prints "nothing exported" (exit 1, stderr suppressed by mapfile of an error); the header's claim about where the brief lives contradicts main.
- confidence: confirmed

### export-local-work.py: failures of git format-patch / rev-parse are swallowed; exit 0 with "N commit(s)" printed
- severity: Medium
- kind: code-defect
- where: scripts/export-local-work.py:122-124, :132, :139-141, :170
- evidence: `git()` returns None on any non-zero status; `git(tree, "format-patch", "-q", "-o", out, f"{base}..HEAD")` result is not checked, and the final line prints `len(local)` commits regardless; `git(tree,"rev-parse",...).strip()` would AttributeError on None; main() returns 0.
- why it matters: this is the script that "saves what exists only in local trees"; a format-patch failure produces an out-dir with BASE.txt and no patches while reporting success. Also `base` = parent of the oldest local commit, so a merge of upstream among local commits makes `base..HEAD` include non-local commits.
- confidence: likely

### gitlint-check.sh vs ci-local.sh: which gitlint config "the bot" uses
- severity: Medium
- kind: contradiction
- where: scripts/gitlint-check.sh:2-3, :194, :213; scripts/ci-local.sh:21-23 (and `GITLINT_CFG="$ACTION_CI/gitlint"`)
- evidence: gitlint-check.sh: "run gitlint ... the way the BlueZ CI bot does: BlueZ's own .gitlint" (`-C "$TREE/.gitlint"`). ci-local.sh: "GitLint (the bot's own gitlint file, NOT BlueZ's .gitlint: title limit 80, Fixes:/Link:/URL body lines ignored ...)".
- why it matters: one of the two descriptions of the bot is wrong; gitlint-check.sh can pass/fail messages differently from the bot (title limit, ignored lines). ci-local.sh's comment dates the finding to the 2026-10-27 cache/action-ci discovery, so gitlint-check.sh's header is the older, unrevised one.
- confidence: confirmed (both headers read; behaviour difference not run)

### get-maintainers.sh: relative patch path breaks after `cd "$TREE"`
- severity: Medium
- kind: code-defect
- where: scripts/get-maintainers.sh:140-144
- evidence: `TREE=...; PATCH=...; cd "$TREE" || exit 2; perl scripts/get_maintainer.pl --no-git-fallback "$PATCH"`: `$PATCH` is used unresolved after the directory change, so `scripts/get-maintainers.sh cache/linux tmp/kernel-0001.patch` (the form used in sibling headers, e.g. build-bluetooth-fulltree.sh:9) looks for the patch inside the kernel tree. Exit status is that of the second perl only.
- why it matters: the recipient list for a kernel mail is an input to a send; an error here is easy to misread as "no recipients".
- confidence: confirmed

### functional-repeat.sh: skipped tests count as "0 failures"; always exits 0
- severity: Low
- kind: code-defect
- where: scripts/functional-repeat.sh:115-116, :126, :132
- evidence: a testcase with `<skipped>` prints "SKIP ..." which the failure grep `'^(FAIL|NO-RESULT)'` ignores, so "base: 0 failure(s) in 10 run(s)" is printed for a selection that skipped everything; final `exit 0` even when a build/ run produced NO-RESULT (counted but not signalled). Header :28 describes only the summary text.
- confidence: confirmed

### hci-key-records.py: "none" / exit 0 for non-btsnoop or non-monitor datalink; timestamps in local time
- severity: Low
- kind: code-defect
- where: scripts/hci-key-records.py:25-27, :32-34, :45, :53
- evidence: only the 8-byte magic is checked (datalink bytes 12-16 ignored) while opcodes 2/3/4/5 are interpreted as btmon-monitor opcodes; a file in another datalink prints "  none" as if no key records exist. `datetime.fromtimestamp(...)` is the reader's local time, not stated. "not btsnoop" still exits 0.
- why it matters: it is used to assert that captures contain no key material (a negative claim); no positive control, and the timezone of the printed times is undocumented.
- confidence: likely

### kernel-preflight.sh: header says sparse C=2, code runs C=1; relative default sparse path breaks after `cd`
- severity: Medium
- kind: doc-vs-code
- where: scripts/kernel-preflight.sh:66-67 vs :97, :101; :75-77
- evidence: header "3. make M=net/bluetooth C=2 (sparse on every file)"; code `make -j"$J" M=net/bluetooth C=1 CHECK="$SPARSE" ...` and echo "sparse (C=1) on mgmt.c". Separately, `BT_SPARSE="${BT_SPARSE:-$(dirname "${BASH_SOURCE[0]}")/../cache/sparse/sparse}"` is relative when the script is run as `scripts/kernel-preflight.sh`; it is tested with `-x` before `cd "$TREE"` (:76-77) and used after it, so the default sparse path no longer resolves and the positive control at :106-109 then reports "sparse DID NOT RUN" although sparse exists.
- why it matters: the checklist header (used as the preflight record for kernel submissions) names a different sparse level than the one run; the relative path makes the documented default invocation fail.
- confidence: confirmed (code read; not run)

### journal-archive-grep.py: decompressor failure and unknown extensions yield "0 match(es)" / "total: 0", exit 0
- severity: Medium
- kind: code-defect
- where: scripts/journal-archive-grep.py:25-27, :38-42
- evidence: `if not cmd: continue` (silently skips any file not ending in .zst/.xz/.gz); `p.wait()` result ignored (corrupt or truncated archive, missing zstd); always `return 0`. Docstring :1,:4 names it "archive-grep.py".
- why it matters: a negative search over archived journals (used to claim "never happened") cannot be told from a search that read nothing.
- confidence: confirmed

### journal-scan-time.sh: failed journalctl reports "lines 0"
- severity: Low
- kind: code-defect
- where: scripts/journal-scan-time.sh:56-58
- evidence: `journalctl --no-pager "$@" 2>/dev/null | wc -l` hides errors and exit status; `bc` is assumed.
- confidence: confirmed

### scripts/README.md: "tracked and tested" is true for one of the four named scripts
- severity: Medium
- kind: doc-vs-code
- where: scripts/README.md:20-24
- evidence: "several published exhibits are produced by them (`sco-ledger.sh`, `sco-ledger-boots.sh`, `boot-bt-summary.sh`, `build-btusb-stable-matrix.sh`), and they are tracked and tested for that reason." `grep -rn "boot-bt-summary\|sco-ledger-boots\|build-btusb-stable-matrix" tests devtools tools` finds nothing; only sco-ledger.sh is referenced from tests/run-tests (:13145 and the tests/journal fixtures). (Defects found here in boot-bt-summary.sh and build-btusb-stable-matrix.sh would have been caught by a test.)
- why it matters: a reader relying on "tested" for exhibit-producing scripts is told something untrue for three of them.
- confidence: confirmed (grep over tests/ devtools/ tools/)

### scripts/README.md: rules vs the directory (promotion rule, subdirectories, index)
- severity: Low
- kind: rule-vs-practice
- where: scripts/README.md:13-17, whole file (24 lines); docs/tooling-index.md
- evidence: "If a script is run more than twice it is promoted to `tools/` or `devtools/` with a test" while scripts/ holds 140 tracked top-level files, including 766-line ci-local.sh and 189-line bot-ci-local.sh reused for every send; the README does not mention the subdirectories (bot-ci-local/, bt17-review-pack/, cd-trace/, kernel-review-pack/) or point to docs/tooling-index.md, which does index scripts (97 `scripts/` lines) but not dbg-autostop-calls.sh, exhibit-relabel-boot-id.py or export-kernel-review.sh. "Outputs go to `tmp/` ... never into evidence/ directly" vs exhibit-relabel-boot-id.py --write, which rewrites evidence/exhibits/*.md in place (named in its header, run once 2026-10-29). The README lists no individual script, so it cannot list one that does not exist; no mismatch of that kind.
- confidence: confirmed

### hfp-gain-by-device.py / hfp-late-vgm-scan.py / device-adv-summary.py / journal-archive-grep.py: docstrings name the scripts by former file names
- severity: Low
- kind: doc-vs-code
- where: scripts/hfp-gain-by-device.py:2,6 ("gain-by-device.py"); scripts/hfp-late-vgm-scan.py:1,12 ("late-vgm-scan.py"); scripts/device-adv-summary.py:7 ("adv-summary.py"); scripts/journal-archive-grep.py:1,4 ("archive-grep.py")
- evidence: usage lines quote the old names; the tracked files carry the hfp-/device-/journal- prefixes.
- why it matters: copy-pasting the usage line fails. hfp-gain-by-device.py also reads "journal-user-gain-history.txt of the 2026-10-23 MOMENTUM incident", which is not in the repository (no tracked file of that name) and is not marked local-only; its output prints raw device paths (header says to publish only via the pseudonym table).
- confidence: confirmed

---

# Part: code-scripts-b

## code-scripts-b findings

### runtime-mgmt-test.sh: load/restore carry only a comment warning, no refusal; usage text omits the warning
- severity: High
- kind: code-defect
- where: scripts/runtime-mgmt-test.sh:22-27 (warning), :148-165 (load, restore code), :190 (usage prints `sed -n '2,20p'`); docs/tooling-index.md:150; BRIEF.md:761-763
- evidence: header "⚠️ 2026-09-23: `load`/`restore` WEDGED THE CONTROLLER (EX-046) ... Do not run load/restore on a live system here". Code: `load)` -> `guard; ... unload_stack || exit 1` and `restore)` -> `guard; unload_stack`; guard() only refuses on "Untreated and running" or "trial OPEN" (:38-47), nothing refuses these two verbs; `unload_stack` does `modprobe -r btusb ... bluetooth`. Usage fallthrough `sed -n '2,20p' "$0"` ends before the warning (lines 22-27). Line 4-6 still says "Everything is reversible". docs/tooling-index.md:150 says "Retired; never run `load` or `restore`"; BRIEF.md:761-763 still advertises "`load`/`restore` swap the module" as the runbook without that warning in that paragraph.
- why it matters: the tool that wedged a healthy controller (EX-046) still performs a live btusb/bluetooth unload when the guard conditions are quiet (no open window, no open trial); retirement exists only in prose. Header line "Everything is reversible" contradicts the warning.
- confidence: confirmed

### smtp-login-check.sh: network/TLS errors exit 1, the same code as REVOKED (the wanted result)
- severity: High
- kind: code-defect
- where: scripts/smtp-login-check.sh:10-12 (header), :28-45 (python)
- evidence: header "exit 0 and ALIVE if the login is accepted (the password must still be revoked); exit 1 and REVOKED ... if refused". Python catches only SMTPAuthenticationError (exit 1) and SMTPServerDisconnected during login (exit 3, undocumented). `smtplib.SMTP_SSL(...)`, `s.ehlo()`, `s.starttls()` are outside any try: a timeout, ConnectionRefused, ssl.SSLError or SMTPServerDisconnected during starttls ends in a Python traceback, exit status 1.
- why it matters: since a revoked password is the expected outcome, a caller that treats exit 1 as "revoked, good" gets a false pass when the check could not run at all (offline, blocked port 587 as on 2026-10-02). Exit 3 INCONCLUSIVE is not in the header either. Also `git config sendemail.*` failures exit 2 with no message.
- confidence: confirmed (read code)

### trial-close-now.sh: exit status hides failures; tmp dir leaked; unknown argument ignored
- severity: Low
- kind: code-defect
- where: scripts/trial-close-now.sh:43 (mktemp), :52-53 ($rc only printed), :58-59 (sco decode rc only printed), :61 (`--reopen` test)
- evidence: `empty=$(mktemp -d "$HERE/tmp/trial-close-nocapture.XXXXXX")` never removed; `echo "close: rc=$rc"` then exit depends only on whether $CUR still exists; `echo "sco decode: rc=$?"` not propagated; `[[ "${1:-}" == --reopen ]]` so `--reopn` silently closes without reopening. Passivity checked: only tools/bt-trial autostop/autostart/step with PATH to the repo tools; no direct HCI command; "row first" is delegated to bt-trial autostop (not verified here).
- why it matters: a failed SCO decode (sco-params.txt missing the data) exits 0; each run leaves a tmp dir.
- confidence: confirmed

### kernel-review-pack: all 53 path+SHA-256 pairs in the 2026-11-14T0300Z review match the tree (positive result)
- severity: Low (none; recorded as a control)
- kind: other
- where: reviews/2026-11-14T0300Z-kernel-patches-ready-to-send-for-outside-review.md ; scripts/kernel-review-pack/build.py
- evidence: python parse of every `**`path`** (SHA-256 `hex`)` header (53 of them; build.py lists 53 (path, lang) tuples) and sha256 of each file in the working tree: 0 MISSING, 0 MISMATCH. Working tree clean for tracked files at HEAD da23558 (git status shows only an untracked reviews/review-comprehensive-... file).
- why it matters: the "text reviewed is the text that would be sent" claim holds as of now. Only the hash headers were compared, not the embedded bodies against the hashes.
- confidence: confirmed

### Hard-coded /root/exp/qca9377-bt-hang paths (another machine's checkout) in scripts that write or create things
- severity: Medium
- kind: code-defect
- [wording of the P-01 class omitted]
- evidence: /root/exp does not exist on this machine (`ls -d /root/exp` fails); the clone is at /home/user/qca9377-bt-hang. Other scripts in the same directory derive the root from __file__ (prove-neg-search.sh:7 even comments "the checkout this script lives in, wherever it was cloned").
- why it matters: on any other checkout move-brief-block.py edits (or fails on) a different tree than the one the script sits in; the two prove-*.py create /root/exp/... directories; prove-held-branch-guard.sh exits 2 and tests a different checkout's devtools/repo-save. Neither says it is local-only. move-brief-block.py is also redundant with move-lines.sh (which takes paths), non-atomic (HISTORY.md is written before BRIEF.md) and does no range check (first<1 or last>len silently slices).
- confidence: confirmed

### "prove-*" scripts that cannot fail: exit 0 whatever happens
- severity: Medium
- kind: test-defect
- where: scripts/prove-trial-closer.sh:9-12,38-45,63-68 (ok/bad only echo; last command `rm -rf "$LC"`); scripts/prove-trial-nomatch.sh:10-13 (same, last command rm -rf); scripts/prove-trial-build-label.sh:20-32 (prints three `build` lines, compares nothing, header promises "the trial opens as E1 with build_declared=stock"); scripts/prove-ci-cwd.sh:11 (`... "$REPO/devtools/ci" "$SHA"; echo "rc=$?"; rmdir`; exits with rmdir's status, no assertion); prove-neg-search.sh (informational, always exit 0, ends with `rm -f "$T"`)
- evidence: contrast prove-ci-stub.sh:35, prove-dr-review.sh:end, prove-exhibit-boots.sh:end, prove-held-branch-guard.sh:end which finish with `(( F == 0 ))` / `(( fail == 0 ))`. In prove-trial-closer.sh `bad "slow-journal close: ..."` is printed but the shell exits 0.
- why it matters: project rule "a zero needs a positive control": a wrapper or CI that runs these on exit status sees success when a check failed (the ✗ line is the only signal). prove-ci-cwd.sh additionally calls the real gh/network (header: "one network call") and relies on a human reading the output.
- confidence: confirmed

### patch-id-compare.sh, patch-code-compare.py: exit status / usage
- severity: Low
- kind: code-defect
- where: scripts/patch-id-compare.sh:20-22 (prints SAME/DIFFERENT, always exits 0; no pipefail so a failing `git show` is only seen as empty id); scripts/patch-code-compare.py:49-52 (`sys.exit(__doc__)` gives exit 1, same as the documented "Exit 1: a difference")
- evidence: `if [[ -n "$a" && "$a" == "$b" ]]; then echo "SAME"; else echo "DIFFERENT"; fi`; docstring "Exit 0: ... Exit 1: a difference (printed). Exit 2: the sets do not pair up".
- why it matters: wrong-usage and a real difference are indistinguishable by status; DIFFERENT is exit 0.
- confidence: confirmed

### patchwork-checks.sh --rate/--failed-functional: failed fetches are skipped silently, exit 0
- severity: Low
- kind: code-defect
- where: scripts/patchwork-checks.sh:73 and :104 (`line=$(checks_line "$id") || continue`), :83,:110 (`exit 0`); header :26 "Exits 2 when the API cannot be reached"
- evidence: only the first listing fetch exits 2; per-patch fetch failures are dropped, then the final line reads "$CTX over the $N most recent patches: fail $fail success $ok other $other" with fewer than N patches counted. For --failed-functional an unreachable checks API prints only stderr "cannot fetch" and no failing patches, exit 0.
- why it matters: a "no TestFunctional failure" or a low failure rate can be produced by fetch errors; the total does not say how many were skipped.
- confidence: confirmed

### sco-switch-windows.sh: `|| true` and its comment are stale since capture-window.sh handles 141 itself
- severity: Medium
- kind: code-defect
- where: scripts/sco-switch-windows.sh:19-21 (comment + `"$HERE/capture-window.sh" ... || true`); scripts/capture-window.sh:28-33 (own PIPESTATUS handling)
- evidence: sco-switch-windows.sh: "capture-window.sh ends in awk `exit` once past the window, so btmon gets SIGPIPE and the pipeline reports 141 under pipefail; that is the normal end." capture-window.sh: "Until 2026-10-19 pipefail returned it from every run that reached <to>; any other btmon status, a BT-4 abort's 134 among them, still means the decode is incomplete and is returned." ending `(( st[0] == 0 || st[0] == 141 )) || exit "${st[0]}"`.
- why it matters: the premise is gone; `|| true` now throws away the exit code that signals an incomplete decode (BT-4 abort 134) or an unreadable capture (exit 2), so a window with no packets and a window that could not be decoded look the same.
- confidence: confirmed

### sco-ledger.sh / sco-ledger-boots.sh: a boot the journal cannot read prints "links 0 ... timeouts 0"
- severity: Medium
- kind: code-defect
- where: scripts/sco-ledger.sh:~47-75 (journalctl ... | awk, END prints `links %d hang-ups answered %d timeouts %d`); scripts/sco-ledger-boots.sh:14-17 (`"$HERE/sco-ledger.sh" "$b" | tee -a "$TMP"`, status ignored), :28-31 (TOTAL)
- evidence: journalctl's own failure (unknown boot, no permission on the kernel journal) is on stderr/pipe status only; the awk END block always prints the zero line, and sco-ledger-boots adds it into "TOTAL over N boot(s): links 0 ... timeouts 0". Header presents it as the count "against the stock driver's 12/12 deaths" (E1: 0 timeouts).
- why it matters: a "0 timeouts" total with no positive control (project rule "a zero needs a positive control") can come from a boot that was never read; the script neither names a boot that produced no rows nor fails. Also dead code at sco-ledger-boots.sh:21 (`{ n = NF; if (...) { } }`).
- confidence: confirmed (read; not run)

### r2-checks.sh: `c()` prints "0" twice on no match and "0" for a missing file
- severity: Low
- kind: code-defect
- where: scripts/r2-checks.sh:11 (`c() { grep -cE "$2" "$1" 2>/dev/null || echo 0; }`)
- evidence: `grep -c` prints 0 and exits 1 when nothing matches, so `|| echo 0` appends a second "0" (verified: `v="$(grep -cE zzz f || echo 0)"` gives two lines `0`/`0`); a nonexistent file prints nothing and exit 2, so the fallback "0" is indistinguishable from "string gone" - most R2 expectations are "X gone". All files the script names currently exist (checked), so no wrong answer today.
- why it matters: historical 2026-09-16 tool, but a renamed file would read as a pass.
- confidence: confirmed

### runtime-mgmt-test.sh: guard is fail-open; stock-daemon/patched-daemon/trigger are HCI interventions with the same weak guard
- severity: Medium
- kind: code-defect
- where: scripts/runtime-mgmt-test.sh:38-47 (guard), :136-145 (stock-daemon/patched-daemon: `systemctl restart bluetooth`), :168-190 (trigger: `bluetoothctl power on/off`, scan)
- evidence: guard() runs `win=$("$REPO/tools/bt-window" 2>&1); tri=$("$REPO/tools/bt-trial" status 2>&1)` and refuses only if the text contains "Untreated and running" or starts with "trial OPEN"; if either tool is missing or fails, its error text passes the guard. (Colour codes are not a problem: bt-trial/bt-window blank B/O when stdout is not a tty.) Header (:25-27) says `status`, `stock-daemon`, `patched-daemon` and `trigger` "remain usable". Project rule (BRIEF reference facts): "probes (anything sending an HCI command) are interventions".
- why it matters: `trigger` power-cycles the adapter and `systemctl restart bluetooth` makes bluetoothd re-initialise it; neither is flagged as an intervention in the header, and a broken tools/ path silently disables the only refusal.
- confidence: confirmed (read); behaviour on the controller not tested (rule)

### prove-audio-policy-metadata.py cannot fail
- severity: Low
- kind: test-defect
- where: scripts/prove-audio-policy-metadata.py:36-39
- evidence: prints "kept"/"lost {s}" and "removed"/"not-removed" and falls off the end (exit 0); header: "Prints "kept" and "removed" on the fixed code; "lost …" / "not-removed" on the 2026-09-26 code." Also the header's usage line names scripts/prove-audio-policy-metadata.py but the default path resolves os.path.join(dirname(dirname(file)), "scripts", "bt-audio-policy.py") (fine).
- why it matters: same class as the prove-* finding above.
- confidence: confirmed

### supported-commands-survey.sh: no `mkdir -p tmp`, btmon aborts are silent
- severity: Medium
- kind: code-defect
- where: scripts/supported-commands-survey.sh:26,40,43
- evidence: `OUT="$REPO/tmp/supported-commands-survey.tsv"`; `printf ... > "$OUT"` with tmp/ untracked (.gitignore: "tmp/ transient outputs") fails on a fresh clone, then `$(wc -l < "$OUT")` fails; contrast mail-html-to-text.sh:11 and patchwork-checks.sh:29 which `mkdir -p`. The loop `btmon ... 2>/dev/null | awk ... >> "$OUT"` ignores btmon's status: a capture on which btmon aborts (BT-4) yields no row, and the summary "replies found: N" cannot tell that from a capture without the reply. scripts/mgmt-replies.sh:46-47 handles exactly this ("an abort is reported per file, never read as no replies").
- why it matters: the survey answers "what did the controller advertise in every retained capture"; silent skips make "no row" ambiguous.
- confidence: confirmed

### bot-ci-local/harness.py: exit status 0 when no test ran
- severity: Medium
- kind: code-defect
- where: scripts/bot-ci-local/harness.py:11-12 (header "Exit status: the number of tests whose verdict is not PASS"), :158-165 (--only / --side base filters), :204-205 (`return sum(...)`)
- evidence: `tests = [t for t in tests if t.name in only or ...]` can leave an empty list (typo in --only, or --side base filter); the report then reads "Test Summary:" with no rows and the process exits 0. `sys.exit(sum(...))` also wraps at 256 failures.
- why it matters: a local CI run that selected nothing looks like a clean pass (zero without a positive control). No guard like "if not tests: exit 2".
- confidence: confirmed

### cd-trace: README says "Nothing here ... changes a setting"; hard-coded device/user; trace.py end-of-run
- severity: Low
- kind: doc-vs-code
- where: scripts/cd-trace/README.md:3-4 ("passive tracing ... Nothing here sends anything to a device or changes a setting"); scripts/cd-trace/cdda-remount.sh:7-12 (`gio mount -u cdda://sr0/` then `gio mount`), totem-quit.sh:9 (quits the user's Totem), totem-debug.sh:20 (starts Totem); scripts/cd-trace/trace.py:36,40 (`/sys/bus/usb/devices/1-1`), :44 (`runuser -u i`), :19-20 vs :47-52
- evidence: the README's own table lists cdda-remount.sh as "unmounts and remounts the audio CD"; remount issues drive commands. trace.py hard-codes the drive at USB path 1-1 and user `i`/uid 1000 (README discloses "The desktop user is `i` (uid 1000)" but not 1-1); if 1-1 is absent `Path(...).read_text()` raises after strace and pw-top were already started, and they are never terminated. The usbmon loop checks `time.time() > end` only when a line arrives, so a quiet bus never ends the run on time. Attaching `strace -f` to gvfsd-cdda is not "alongside": it slows the traced syscalls (observer effect on the 16 s stall timing) - needs-check.
- why it matters: wording overstates passivity; leftover strace processes.
- confidence: confirmed (code), needs-check (observer effect)

### cd-trace/x1-check-submission.py: stale docstring name, no timeout, errors look like mismatches
- severity: Low
- kind: code-defect
- where: scripts/cd-trace/x1-check-submission.py:2 (docstring "check-submission.py"), :21 and :83 (`urllib.request.urlopen(url)` with no timeout), :13 (/root/exp path), README.md:12 ("exit 1 if anything no longer matches")
- evidence: a network failure raises a traceback and exits 1, the same status as "no longer matches"; commit hashes 98dc71aa.../610794dc... and PROGRAM_SHA are hard-coded (any later push to an MR reads as a mismatch, which is the intent).
- why it matters: exit 1 is ambiguous; a hung GitLab hangs the script.
- confidence: confirmed

### Network fetches without timeout / error status
- severity: Low
- kind: code-defect
- where: scripts/stable-queue-check.sh:19 (`curl -s -f` no --max-time; failure -> "? fetch failed", rc=1 same as "not in queue"); scripts/cd-trace/x1-check-submission.py:21,83; scripts/ubuntu-bluez-patches-check.py:20-24 (timeout 120 present; no argv check, `[0]` IndexError if version unknown); scripts/ubuntu-series-versions.py:15
- evidence: stable-queue-check.sh sets rc=1 for both "fetch failed" and "not in queue", so a network failure and a negative are the same exit status (the printed line differs). Other fetchers (patchwork-*.sh, sent-mail-check.py) do have timeouts and a distinct exit 2.
- why it matters: minor; the stable-queue verdict is the evidence for "queued".
- confidence: confirmed

### Stale/incorrect headers
- severity: Low
- kind: doc-vs-code
- where: scripts/ubuntu-bluez-patches-check.py:5 ("Usage: dev-release-patches.py <version> <outdir>" - wrong file name); scripts/prove-held-branch-guard.sh:2-4 ("the two suite assertions" but the script has four checks: kernel/*, plan/*, config/*, no private remote); scripts/runtime-mgmt-test.sh:4-6 ("Everything is reversible" vs the EX-046 warning below it); scripts/ubuntu-series-versions.py:1-2 ("published in the newest series" but loops over the first four series, :18); scripts/mail-body-sha.py:22 usage text absent (IndexError on no argument, or on a mail without an empty line).
- confidence: confirmed

### sent-mail-check.py: missing local file reported as "unreachable" (exit 2); empty filter exits 0
- severity: Low
- kind: code-defect
- where: scripts/sent-mail-check.py:25-26 (header "2 when patchwork cannot be reached"), :174-180 (`compare()` opens the local file; `except OSError` -> "unreachable", return 2), :276-278 (`only` filter)
- evidence: check_hash() has already counted MISSING, but in default mode compare() raises FileNotFoundError, caught by the same `except OSError` as a network failure. A bare word matching no row gives "summary: of 0" and exit 0.
- why it matters: wrong diagnosis; zero rows checked reads as success.
- confidence: confirmed
- control result: docs/sent-mails.tsv has 27 rows; the --hashes logic re-done by hand: 26 ok, 1 skipped ("not kept in the repository"), 0 changed, 0 missing.

### prove-dr-followup.sh / prove-dr-review.sh run install.sh and uninstall.sh --apply in the live checkout (safe only through PATH stubs)
- severity: Low
- kind: rule-vs-practice
- where: scripts/prove-dr-followup.sh:64 (uninstall) and :62 (install --tools-only); scripts/prove-dr-review.sh:47
- evidence: `env PATH="$SS/bin:$PATH" BT_DESTDIR="$SR" ./uninstall.sh --apply` - BT_DESTDIR is honoured (uninstall.sh:147-153) and systemctl/udevadm/modprobe are stubbed on PATH; uninstall.sh:160-169 admits an earlier version of this promise "was FALSE" (a real `modprobe -r btusb` reset the controller). BRIEF rule: never `install.sh --apply`.
- why it matters: not wrong today (stubs checked by reading), but safety rests on the stub list covering every system command install/uninstall call (rmmod, rfkill, usbreset not stubbed). needs-check on whether a test asserts the stub wins.
- confidence: needs-check

### module-updates.sh: `remove` does not check for an open trial (install does)
- severity: Low
- kind: doc-vs-code
- where: scripts/module-updates.sh:96-102 (install: refuses when /run/bt-trial/current exists), :111-117 (remove: no such check); header :14-15
- evidence: install comment "A new module changes the conditions of an open trial (BRIEF §7)"; remove deletes the updates/ module and runs depmod with no trial check. Confirmed it never loads/unloads: code only does mkdir, install -m 644, depmod -a, rm -f of "$UPD/$MOD.ko" (matches BRIEF §9.9 "installs into updates/ only"); on the running kernel the change takes effect at next boot (the trial of this boot is unaffected), so the asymmetry only matters with --krel.
- why it matters: minor; header does not say remove skips the check.
- confidence: confirmed

### Hard-coded machine specifics not marked local-only (user `i`, uid 1000, USB 1-1, /var/log/bt-health, tmp/, cache/)
- severity: Low
- kind: other
- where: scripts/user-audio-streams.sh:13, user-journal.sh:17, user-pw-dump.sh:17 (default user `i`, BT_DESKTOP_USER overrides - documented); scripts/cd-trace/totem-debug.sh:20-22, totem-quit.sh:6, cdda-remount.sh:6 (uid 1000, wayland-0, user `i`, no override); scripts/prove-bt-trace-archive.py:47-49 (reads /var/log/bt-health/trace and the untracked tmp/evidence-20261011-sbc-xq-bt-20261011-003713.btsnoop as fallback; fails with FileNotFoundError anywhere else); scripts/bt17-review-pack/build.py:112-116 (tmp/bot-ci-local/... "MISSING" printed on stdout only and the document is still written); scripts/prepare-ubuntu-ksrc.sh, series-backport-check.sh, stable-*.sh (need cache/linux, which is untracked)
- evidence: only cd-trace/README.md says the prerequisites are "present on the laptop"; the scripts themselves and prove-bt-trace-archive.py's docstring ("copies of three small captures") do not say they need this machine's files.
- why it matters: on a fresh clone these fail or, for build.py, silently produce a document without section 10.
- confidence: confirmed

### Privacy scan of scripts/ (mail-body-sha.py ... end, all subdirectories): no finding
- severity: Low (control)
- kind: privacy
- where: scripts/prove-ui-capture.sh:356,375; scripts/prove-dr-followup.sh:43; prove-dr-review.sh:77; prove-held-branch-guard.sh:11
- evidence: grep for MAC-like, IPv4, e-mail, smtp/gmail/hostname/ssid strings: only the placeholder `00:11:22:33:44:55`/`DE:AD:BE:EF:00:01` (prove-ui-capture.sh, a fixture the test requires to be removed) and `test@example.com`. smtp-login-check.sh reads host/port/user from `git config sendemail.*` and the password from $BT_SMTP_PASS (no account detail embedded); sent-mail-check.py has none; x1-check-submission.py has the public GitLab username "ivoitovych" and project id/upload URL (public). This checkout has no sendemail config, so smtp-login-check.sh would exit 2 silently here (`|| exit 2` prints nothing).
- confidence: confirmed (grep)

---

# Part: code-devtools

## code-devtools findings (devtools/, .github/workflows, .gitignore)

### repo-save compares the commit identity with the checkout's own git config, not with the project author
- severity: High
- kind: doc-vs-code
- where: devtools/repo-save:129-152 (want_name/want_mail from `git config user.name/email`; `want="$want_name <$want_mail>"`); devtools/repo-save:170-181 (push-range check against the same `$want`); README.md:320-321; BRIEF.md:489-491; .github/workflows/checks.yml:51 (`WANT: "Iaroslav Voitovych <yaroslav.voytovych@gmail.com>"`)
- evidence: README.md: "Every commit in this repository is authored and committed by the project author; `devtools/repo-save` and CI check both fields on every commit." BRIEF.md: "`repo-save` refuses a commit whose author or committer identity is missing or was assigned by the environment (a reinit reset a collaborator's git config on 09-18; caught by eye, now gated)". Code: `want_name="$(git config user.name ...)"; want_mail="$(git config user.email ...)"` then `[[ "$ident" != "$want" ]]`. Only a literal identity is hard-coded in CI (checks.yml:51) and, separately, in devtools/held:19.
- why it matters: the 09-18 incident was a reset of the git CONFIG. If config holds another name/email, repo-save's "want" is that same wrong identity, author and committer both match it, and the commit is made and pushed. Only an unset config, or GIT_AUTHOR_*/GIT_COMMITTER_* that differ from config, are refused. The wrong-identity commit is caught only by CI after it is already on origin. The README's "project author" wording is also not what the code compares against (the devtools/README says "the identity configured in the checkout", which is the accurate one).
- confidence: confirmed

### repo-save's per-commit push check skips every commit that any remote (including `private`) already has
- severity: Medium
- kind: doc-vs-code
- where: devtools/repo-save:179 (`git rev-list "$br" --not --remotes`); devtools/repo-save:166-171 comment; README.md:320
- evidence: comment "Commits already on some remote were published before and are not this checkout's to judge"; code `done < <(git rev-list "$br" --not --remotes ...)`. `--remotes` includes `private`, a non-public remote.
- why it matters: README says both fields are checked "on every commit". A commit that sits only on `private` (held branches, kernel/*, review/*) is not examined when it is later pushed to `origin` via main. "Published before" is true only for public remotes. Also commits made with plain `git commit` are not checked until a push goes through repo-save; a direct `git push` goes only through hooks/pre-push, which runs repo-scan and no identity check.
- confidence: confirmed (reading); effect needs a commit that reaches main via private

### CI identity job passes with "0 commit(s) examined" on a forced update of main
- severity: Medium
- kind: code-defect
- where: .github/workflows/checks.yml:55-60, 71-72
- evidence: `if [[ -z "$base" || ... ]] || ! git merge-base --is-ancestor "$base" "$AFTER" ...; then git fetch --quiet --no-tags origin main; base=$(git merge-base "$AFTER" origin/main ...)`; `echo "$n commit(s) examined in $range"`; `(( bad == 0 )) || exit 1`. The comment at line 37-40 says "a forced update, is measured from the merge base with main".
- why it matters: on a force-push to main, `origin/main` fetched in the job is already AFTER, so merge-base = AFTER, range `AFTER..AFTER` is empty, n=0, and the job is green although the rewritten commits were never examined. A zero count is not treated as "could not check". (For a new branch built on main the range is right; for pull_request events `github.event.before` is empty and AFTER is the synthetic merge commit: needs-check whether its author/committer passes WANT.)
- confidence: confirmed (reading); PR-event behaviour needs-check

### pre-push hook scans the net diff between tips, so a leak added and removed inside one push is published unscanned
- severity: Medium
- kind: code-defect
- where: devtools/repo-scan:59 (`CONTENT=$(git diff "$base" "$RANGE_HEAD" -- | grep '^+' ...)`); devtools/hooks/pre-push:27-29; devtools/repo-scan:8-9 ("the ADDED LINES between two commits (what a push would introduce)")
- evidence: `git diff base head` shows only the final difference. Commit A adds a real BSSID, commit B removes it, both pushed together: the range diff has no such line, scan clean, but the public history contains A.
- why it matters: the hook exists because a plain `git push` bypassed the scan (pre-push:5-8); the project's worst past incident was addresses reaching public commits. repo-save scans each commit's staged additions so the normal path is covered; this is the backstop for direct pushes and does not cover intermediate commits. Also (hook install) install-hooks.sh links into `git rev-parse --git-path hooks` and does not report when `core.hooksPath` is set elsewhere, in which case the link is never run (needs-check on any given clone).
- confidence: confirmed (reading)

### repo-validate's Python/awk parse covers only *.py / *.awk; three tracked Python programs without extension are never parsed
- severity: Medium
- kind: doc-vs-code
- where: devtools/repo-validate:125 (`case "$f" in *.py) ;; *) continue ;; esac`) and :155 (`*.awk`); devtools/README.md table row for `repo-validate` ("over every tracked or staged file: ... a Python parse (`ast.parse` ...), an awk parse")
- evidence: `bin/bt-capture`, `devtools/access-classify`, `devtools/mutants` have `#!/usr/bin/env python3` and no `.py` suffix (shell files are found by shebang at line 68, Python is not). Searched tests/run-tests for ast.parse/py_compile: none.
- why it matters: a syntax error in bin/bt-capture (the capture that survives btmon aborts) is not caught by the validator; only by whatever test happens to run it. The README sentence reads as complete coverage. Related stale text: devtools/py-coverage:12 says "this tree has exactly one Python file — `bin/bt-capture`", and tests/run-tests:8800 says "the only Python here"; devtools/access-classify and devtools/mutants are Python and are measured (py-coverage picks them up by shebang).
- confidence: confirmed

### repo-scan accepts more than the documented email allowlist (systemd-*, noreply@any-host, modprobe@, giometti@linux.it, example.org, tip-commit author)
- severity: Medium
- kind: doc-vs-code
- where: devtools/repo-scan:224-232; devtools/repo-scan:175,190 (ALLOW_MAIL falls back to `git log -1 --format=%ae`); devtools/README.md "Email: the committer's own address (from `git config user.email`), public kernel mailing lists, and `example.com` are allowed; anything else fails."; BRIEF.md:446-452; devtools/repo-scan-public-addresses:1-14
- evidence: code lines `grep -viE '@(vger\.kernel\.org|lists\.linux\.dev|example\.(com|org))$'`, `grep -viFx 'giometti@linux.it'`, `grep -viE '^(noreply|no-reply)@'`, `grep -viE '^modprobe@|^systemd-'`. The list file header says "Never an organisation's or a mail provider's domain".
- why it matters: `^systemd-` passes any `systemd-<anything>@gmail.com`; `^(noreply|no-reply)@` passes that local part at any host; one person's address is hard-coded in the script instead of in the reviewed list; example.org is not in the README. This is the same class (prefix/suffix patterns) BRIEF says was removed. In CI the allowed own address is the tip commit's author, i.e. for an outside fork PR the allowed address is the contributor's. The three documents (README, BRIEF, list header) disagree with the script.
- confidence: confirmed

### repo-scan-public-addresses / quoted-examples: checked, no organisation-domain or suffix entries; no quoted-example file is missing
- severity: Low
- kind: other
- where: devtools/repo-scan-public-addresses:18 (only `@lists.linaro.org`); devtools/repo-scan-quoted-examples:17-31
- evidence: the only `@host` entry is a mailing-list host. All three files named in quoted-examples (reviews/2026-10-21-recheck-of-v4.md, -v5.md, -v6.md under contributions/CO-10-stable-6.6.160-rc2/) exist, and each listed token still occurs in its file (`git grep -lF`). Non-address tokens sit in the "published addresses" list (`+@pytest.mark.parametrize` at line 130, `getty@tty1.service` at line 119; the second also names no person) and pass in every file; `gjzNncQ@mail.gmail.com` is a fragment of a Message-ID (documented at lines 154-156). Nothing detects a quoted-example entry whose file stops containing the token (stale entries are silent).
- why it matters: statement in BRIEF holds; remaining nits only.
- confidence: confirmed

### held sync ignores a failed push to private; held commit takes a relative message path against the wrong directory
- severity: Low
- kind: code-defect
- where: devtools/held:61 (`git push -q private "$HELD" 2>&1 | tail -1`), devtools/held:17,66-68
- evidence: the pipeline status is tail's, the script then runs `back_to_main` and `"$0" status`, exit 0 even when the push was rejected (status shows local vs private, but the exit is 0). `cd "$REPO"` at line 17 runs before `msg="${2:?...}"`, so a relative `<msgfile>` is resolved against the repo root (repo-save resolves relative to PWD, which is now REPO); contrast repo-save:28-32, which resolves "before the cd" for this reason. The identity is hard-coded in held:19 (`IDENT=(-c user.name=... -c user.email=...)`) and used only on the conflict path (an automatic merge commit at line 48 uses plain config); neither merge commit goes through repo-validate/scan.
- why it matters: a failed push is silent in the exit code; relative message paths can point at the wrong file (or fail).
- confidence: confirmed

### awk-coverage exits 0 on a red suite and when gawk is missing; journal-contract exits 0 without journalctl; ci --recent exits 0 when gh fails
- severity: Medium
- kind: code-defect
- where: devtools/awk-coverage:74-77 (`gawk is required ... — skipping`, `exit 0`) and :105-108 (suite exit status never captured; end of file has no `exit` based on it); devtools/journal-contract:43-44 (`journalctl not installed ... (exit 0)`); devtools/ci:107-111 (`gh run list ... 2>/dev/null | awk ...; exit 0`)
- evidence: devtools/coverage ends `exit $(( SUITE_RC != 0 ))` and py-coverage refuses a failing run ("coverage from a failing run is not a measurement"); awk-coverage prints "a red run is measured too" and exits 0 if the floor is met. ci --recent prints the header and nothing when gh fails, exit 0, although fetch() (ci:72-79) says an empty answer from a broken query must never read as "no run".
- why it matters: "a gate that passes when it could not run" is the project's named defect class. In CI gawk and journalctl are present so the live risk is the red-suite case (the other jobs would still fail) and local use on a mawk host.
- confidence: confirmed

### checks.yml says "EIGHT JOBS, ON EIGHT RUNNERS" but defines nine
- severity: Low
- kind: contradiction
- where: .github/workflows/checks.yml:26 and jobs at :41, :75, :162, :200, :234, :269, :304, :341, :407
- evidence: "# EIGHT JOBS, ON EIGHT RUNNERS AT ONCE." Jobs: identity, suite, serial, coverage, comprehension, awk-coverage, python-coverage, isolation, system = 9 (a tenth workflow, access-audit.yml, is separate).
- why it matters: the identity job was added without updating the comment; a reader reconciling the comment with the Actions tab finds a mismatch.
- confidence: confirmed

### BRIEF claims checks.yml "now says about a minute"; no such text exists in checks.yml
- severity: Low
- kind: stale
- where: BRIEF.md:821-823; .github/workflows/checks.yml:8-15
- evidence: BRIEF: [wording of the P-01 class omitted] The only duration in devtools/ci:110-112 is "a run here takes ~4-8 minutes".
- why it matters: the quoted state of a file is not the file's state. Same BRIEF item (lines 830-832) still says the gates that re-run the suite are "seven in CI's check job on 2026-10-17" and that "the split" is open, while checks.yml:26-35 records the job split done on 2026-10-18 (dated text, so only a pointer for a reader).
- confidence: confirmed

### Branch convention: README points to reviews/README.md, which defines no branch convention; review/* branches go only to `private`
- severity: Medium
- kind: broken-reference
- where: README.md:278-280; reviews/README.md:17-31 ("The convention" is about file names); devtools/repo-save:155-159 (`review/*` listed among the private-only families); origin heads (`git ls-remote --heads origin`): ci/, docs/, fix/, land/, tests/, ui/ and main only
- evidence: README: "`review/<UTC timestamp>` holds one assessment (report first, then the reaction on `review/<timestamp>-fixes`), per the convention in [`reviews/README.md`]". reviews/README.md names branches only inside table rows (e.g. line 63 "branch `review/2026-08-15T1752Z-fixes`", line 327). repo-save pushes review/* to `private` and never to origin; none exists on the public remote.
- why it matters: a stranger reading the public README is told the branches exist and where the convention is; neither the convention nor the branches are reachable.
- confidence: confirmed

### devtools/README.md: commit-message scan, review-open closed-word list, "Notes: These write" list
- severity: Low
- kind: doc-vs-code
- where: devtools/README.md ("`repo-save` also scans the **commit message** for addresses, which `repo-scan` cannot see"); devtools/repo-save:100-111; devtools/review-open:14-16 vs :32-33; devtools/README.md Notes section
- evidence: (a) repo-save scans the message only for MAC/BSSID-shaped hex groups (`grep -oEi '[0-9a-f]{2}([:_-][0-9a-f]{2}){5,}'`); no email, UUID or IPv4 check, so "addresses" is MAC only. (b) review-open header lists closed words "fixed, done, no action, recorded, refuted, superseded, answered, withdrawn, agreed, kept, n/a, not applicable, confirmed, verified, merged, retracted"; the awk adds `closed` and `tool fixed`; and rows whose status starts "agrees" (reviews/README.md:365, 379, 380), "adopted" (376, 420) or "already fixed" (417) are listed as open because those words are on neither list (emulated read-only in Python: 42 non-closed rows, 6 of these are closed in meaning). (c) Notes says only repo-save, save, held, assert-test-catches, mutate, ci, `sandbox --report` write; `access-audit --report <dir>` (used in access-audit.yml), test-bt-journal-files.sh and test-journal-fast.sh (write under tmp/), hooks/install-hooks.sh (writes .git/hooks) also write.
- why it matters: small, but (b) makes the "what is still open" answer list closed rows.
- confidence: confirmed

### devtools/save prints no gate conclusion on a normal run and nothing when there is nothing to commit
- severity: Low
- kind: doc-vs-code
- where: devtools/save:155 (the `grep -E` filter) vs devtools/repo-validate:289, :204 and devtools/repo-save:77-79; devtools/save:123 comment
- evidence: filter `'^(── |  staged:|all syntax|scan clean|  ✓ message|  ✓ identity|  [0-9a-f]{7,}  |  author:|  ⚠|  ✓ remote|  · tests)'`. repo-validate's normal last line is "all checks passed (...)" and the suite line is "  ✓ tests ..."; neither matches (`all syntax` is the `--no-suite` wording; `  · tests` is the skipped form). "  nothing to commit" also matches nothing, so `devtools/save` prints only "── stage ──" and exits 0. Comment: "The lines that carry the outcome: what was staged, what the gates concluded...".
- why it matters: the quiet-on-success wrapper hides the validation verdict that its comment promises to show. Also: devtools/save:117 budget counts non-empty lines (`grep -c .`, 829 now; `wc -l` 879) while BRIEF.md:14 says "1200 lines"; both under budget, so no contradiction in effect.
- confidence: confirmed

### Tests for the publish-scan hook and the journal-files tool are run by nothing
- severity: Medium
- kind: test-defect
- where: devtools/hooks/test-pre-push.sh; devtools/test-bt-journal-files.sh; devtools/test-journal-fast.sh; .github/workflows/checks.yml (no step); tests/run-tests (no call)
- evidence: `grep -n "test-pre-push\|test-bt-journal-files\|test-journal-fast" tests/run-tests .github/workflows/*.yml devtools/repo-validate devtools/check` -> no hits; only docs/tooling-index.md:146 and devtools/README.md mention them. test-journal-fast.sh:9 defaults its day to `2026-10-22` and compares boot -1 with the real journal, so it is meaningful only on the one machine at the time; windows with no data compare two empty outputs and print PASS.
- why it matters: the hook is the gate against publishing addresses and its only test never runs in CI or in `devtools/check`; a regression in pre-push is invisible. (Item 5 of the brief: the project's own rule is that a gate must be observed to fail.)
- confidence: confirmed

### Stale/inaccurate comments in .gitignore and devtools scripts
- severity: Low
- kind: stale
- where: .gitignore:6-8; devtools/assert-test-catches:23-28 and :67; devtools/status:143-148
- evidence: .gitignore: "Raw (unsanitised) logs — only *.sanitized.log may be committed" while 147 tracked evidence/**/*.log files are not named `.sanitized.log` (`git ls-files evidence | grep -E '\.log$' | grep -vc sanitized` = 147) and the rule is only `evidence/**/*.raw.log`. assert-test-catches: an inserted REVIEWED-KEEP paragraph splits the sentence "break the thing it checks and / ... / watch it go red"; `grep -q "✗.*$WANT"` uses WANT as a regex, and an empty WANT passes on any failing line. status: prints "controller NOT on the bus — cold power-off required" whenever `lsusb` is absent or the ID is not present (e.g. CI or a different machine), as advice.
- why it matters: cosmetic or minor.
- confidence: confirmed

### Checked and consistent (no finding)
- BRIEF "Budget: 1200 lines (devtools/save warns above it)": BRIEF_BUDGET=1200 in devtools/save:117, warns (never blocks).
- BRIEF "repo-save pushes held branches to the separate remote only": repo-save:155-162 maps kernel/plan/diag/review/attribution/postponed/config to `private`, refuses if no `private` remote.
- BRIEF 8a "system round trip must not pass by skipping": checks.yml uses `BT_SYSTEM_TEST=required`; tests/system-roundtrip:57-67 and tests/system-upgrade:50-60 fail on a skip.
- .gitignore vs README map: archive/, cache/, tmp/ are ignored (`git check-ignore -v`), nothing tracked under them (`git ls-files -ci --exclude-standard` empty).
- coverage-exclude: every whole-file entry and every file:range entry names a tracked file, and every range lies inside the file's length (read-only Python check); the first/last lines of each range are the inline awk programs the comments describe, the two `tests/run-tests` shape patterns match 2 lines each. Not executed.
- devtools/README.md table lists every script in the directory; none described contrary to its code apart from the points above.
- Python and bash syntax: `python3 -I ast.parse` on the three Python tools OK; `bash -n` on all devtools bash scripts OK; no shellcheck installed.

---

# Part: tests-1

## tests-1 findings (tests/run-tests 1-5200, tests/README.md)

### README coverage floor for awk (85) disagrees with CI (95)
- severity: Medium
- kind: doc-vs-code
- where: tests/README.md (last section "Coverage", sentence "the coverage, awk, python and comprehension steps each print theirs and hold a floor (80, 85, 80 and 75 on the branch `main` takes)"); .github/workflows/checks.yml:230, :266, :301, :338
- evidence: README order is coverage, awk, python, comprehension = 80, 85, 80, 75. CI: `devtools/coverage --quiet --min 80`, `devtools/test-comprehension --min 75`, `devtools/awk-coverage --min 95`, `devtools/py-coverage --min 80`. Only the awk floor differs (85 vs 95). README last touched 2026-11-13 (d63bff7), checks.yml 2026-11-13.
- why it matters: a reader relying on README thinks a drop to 90% awk coverage passes; CI fails it.
- confidence: confirmed

### README says the upgrade rehearsal asserts 17 checks; tests/system-upgrade has 20 ok sites
- severity: Low
- kind: doc-vs-code
- where: tests/README.md ("What it asserts (17 checks):" under the upgrade rehearsal); tests/system-upgrade lines 175,185,204,211,217,229,240,243,246,248,252,259,274,282,291,297,301,305,308,312
- evidence: `grep -nE '\bok "' tests/system-upgrade` gives 20 distinct ok call sites (185/187 and 300/301 are pass/fail pairs, so 20 counted once each). README's bullet list also omits the tools-only-reads-no-whole-boot check (l.217), the VI1 advice check (l.274) and the MODE2 passive-units check (l.282). Count not run-verified (script must not be run) -> static count only.
- why it matters: stale count and incomplete list of what the system test asserts.
- confidence: likely

### Guard "no bt-trial lifecycle verb outside the wrappers" does not list autostop
- severity: Low (hole in a safety guard; no current violation in lines 1-5200)
- kind: test-defect
- where: tests/run-tests:15144 (LOOSE grep, outside my range, read to verify), tests/README.md rule 4 ("a second check fails on a spelled-out `tools/bt-trial <verb>` call outside them"); tools/bt-trial:343,369,432,466,476,1140 (verbs start, autostart, autostop, step, hang|ok, abort)
- evidence: `LOOSE=$(grep -HnE 'tools/bt-trial +(autostart|start|ok|hang|abort|step)\b' ...)` - `autostop` (the unit's ExecStop: closes a trial, may run bt-incident) is a real verb absent from the alternation. A literal `tools/bt-trial autostop` in the suite would pass the check. TRIALCALLS (l.15147) also omits it. Currently all literal calls in 1-5200 are `report` (lines 1988,2065,2091,2113,2139,2140,3141,3151,3169,3193,3250) and autostop is only reached through trial_in.
- why it matters: rule 4 states the check fails on any such call; for autostop it would not.
- confidence: confirmed (pattern read; no violating call found)

### README rule 4: report calls "set BT_REPO on their own line" - one does not
- severity: Low
- kind: rule-vs-practice
- where: tests/README.md rule 4 (bullet 2); tests/run-tests:2316
- evidence: README: "(the read-only `report` calls set `BT_REPO` on their own line)". Line 2316: `COF=$(cd "$CO/elsewhere" && env -u BT_REPO "$CO/co/tools/bt-trial" report 2>&1)` deliberately unsets BT_REPO (tests discovery). Safe (report is read-only, BT_EVIDENCE_REPO is the declared-machine export from l.542) but contradicts the sentence.
- why it matters: minor; the README rule is stated without this exception.
- confidence: confirmed

### Discovery/scan check with `|| true` and a misleading file count (awk -f trap)
- severity: Low
- kind: test-defect
- where: tests/run-tests:2164-2167
- evidence: `offenders=$(grep -rnE "awk[^|]*-f [^ ]+\.awk[^|]*'" tools/ bin/ 2>/dev/null | grep -vE ... || true)` then `ok "no tool passes an inline program alongside awk -f (${#SHFILES[@]} files)"`. `|| true` plus `2>/dev/null` turns a failed grep (rc 2, e.g. missing dir) into "no offenders"; the printed count is SHFILES (all tracked shell files incl. devtools/, install.sh) but the scan covers only tools/ and bin/ (and non-shell files there). The file's own rule (l.1793-1803, l.1329) says a search failure must not read as a negative and a derived check reports the size of what it checked.
- why it matters: the tick claims more coverage (N files, repo-wide) than the check performs; devtools/ and install.sh are not scanned.
- confidence: confirmed

### "PIPEFAIL-DEMO" check passes on both outcomes
- severity: Low
- kind: test-defect
- where: tests/run-tests:3357-3363
- evidence: `if (( $? != 0 )); then ok "confirmed: ..." else ok "grep -q pipeline is not inverted on this shell — rule kept regardless"; fi` - both branches call ok, so it can never fail (README rule 1: a check must be observed to fail).
- why it matters: counts as an invariant in the totals but asserts nothing; acknowledged in the text ("rule kept regardless") but still counted as a pass.
- confidence: confirmed

### results.tsv width/header checks read the live evidence file and pass vacuously if it is absent
- severity: Low
- kind: test-defect
- where: tests/run-tests:3381-3388 (WIDTH), 3586 (n_col), 3600 (PERT header)
- evidence: `WIDTH=$(awk ... evidence/trials/results.tsv 2>/dev/null)`; `if [[ -z "$WIDTH" ]]; then ok "every row in results.tsv matches the header width"`. A missing file or awk error gives empty output = ok (no count of rows checked, unlike the file's own "report the SIZE of what it checked" rule at l.1329). The header-column loop (3586) does fail when the file is missing, so the two are inconsistent. (File currently exists: 26 lines.) Read-only access to the real tree, by design ("The live file is checked").
- why it matters: a vacuous tick in a clone without evidence/.
- confidence: confirmed

### tests/whole-boot-reads.txt: all 41 entries are "pending", yet the invariant passes
- severity: Low
- kind: rule-vs-practice
- where: tests/whole-boot-reads.txt (41 non-comment lines, 41 with third field `pending`); tests/run-tests:3568-3576
- evidence: run-tests l.3570 `ok "every unbounded journal read in the tools (...) is listed in tests/whole-boot-reads.txt, $WBPEND still pending a reason or a fix"`; file header says each read is listed "with its reason, or 'pending' until it has one"; `grep -v '^#' tests/whole-boot-reads.txt | cut -f3 | grep -c '^pending'` = 41 of 41. Not silent (count printed), but the check is a snapshot baseline, none reasoned. docs/tooling-index.md:79 itself says direct journalctl callers "do not get [the fast path] yet".
- why it matters: the green tick suggests the whole-boot-read decisions were made; none was.
- confidence: confirmed

### Stale counts and comments in run-tests
- severity: Low
- kind: stale
- where: tests/run-tests:259 and 475; 1990-1992; 3662, 3673; 4904
- evidence: (a) l.259 "This file calls mktemp in 80 places ... the other 77", l.475 "all 79 other mktemps" - `grep -c mktemp tests/run-tests` = 183. (b) l.1990-1992 "The fixture holds 2 hangs ... The fixture holds 5 rows" - tests/trial-results.tsv has 7 data rows (T1..T7, as the comment at l.1998-2001 itself lists). (c) l.3662/3673 `grep -o 'longest uncensored[^\n]*'`: inside a bracket `\n` is "not backslash, not n", so the failure diagnostic is cut at the first letter n (diagnostic only; check itself is fine). (d) l.4904 comment contains the literal shell-quoting residue `CHAIN'"'"'S` ("THE FALLBACK CHAIN'"'"'S LAST RUNG").
- why it matters: stale numbers/diagnostics only.
- confidence: confirmed

### `--section` ignores --serial/--jobs given on the same command line
- severity: Low
- kind: doc-vs-code
- where: tests/run-tests:129-133, 155-169; tests/README.md (command block: `--serial`, `--jobs 4`, `--section`)
- evidence: --jobs/--serial are parsed into the non-exported shell variable SUITE_JOBS (l.129-133), then the --section branch runs `out=$("$0"); rc=$?` with no arguments; the child run therefore uses BT_SUITE_JOBS from the environment or nproc. `tests/run-tests --serial --section X` runs in parallel. README does not state this.
- why it matters: minor; the user asked for serial (e.g. for an instrument) and gets parallel.
- confidence: confirmed (read; not run)

### README fixtures table names `sanitize-logs.sh` without its path
- severity: Low
- kind: broken-reference
- where: tests/README.md Fixtures table, last row (`sanitize-invariants.log` | `sanitize-logs.sh`)
- evidence: `git ls-files --error-unmatch sanitize-logs.sh` fails; the file is tools/sanitize-logs.sh. Every other tool in the table is likewise unpathed, so a reader can resolve it; the README does not mention tests/whole-boot-reads.txt, tests/unit-state-changes.awk or tests/system-resources.md at all (all three exist, are used by run-tests / system-upgrade).
- why it matters: minor incompleteness.
- confidence: confirmed

## Checked and found consistent (no finding)
- README rule 4 "five wrappers (trial, trial_in, tl, tlt, tlnh)": all five exist (run-tests:1235, 1244, 9054, 9399, 9424); wrapper-sets-both-variables check at 15410-15420 is sound for trial/trial_in (BT_REPO and BT_EVIDENCE_REPO at 1237 and 1250); BT_EVIDENCE_REPO exported to declared machine (l.542).
- README rule 9 "Three do" PARALLEL markers: exactly three at 2253, 7652, 11349; the 4 other `# PARALLEL: long` markers are separate. Mechanical cross-section scan (top-level functions/variables defined in a section and used in another) in 1-5200: no unmarked dependency; only hits are re-assignments or the marked pairs.
- README "journal/ holds 46 directories": 46. fixtures/ has stage2, trial-sco-table, trial-summary. "four checkout-world sections": headings at 12038, 12101, 12157, 12198. All devtools/ files and docs named by README exist in git ls-files.
- Seam rules in 1-5200: every bt-trial lifecycle call goes through trial/trial_in; fixtures use 192.0.2.x (l.1004), example.com (l.955, 2425), no real-looking addresses seen. BT_* declared-machine seams are exported before first test.
- No silent skips in 1-5200 (only *_SKIPPED notes at l.987-1008, which the parent reports).

NOT covered: run-tests lines 5201-15600 (other reviewer), README claims needing a run (1012 checks, timings 142 s/59 s, 312 calls), and tests/system-roundtrip, tests/system-upgrade beyond the check count and gate text.

---

# Part: tests-2

## tests-2: tests/run-tests lines 5200-10400 (read in full)

### bt-capdiff window check matches the tool's own title, cannot fail
- severity: Medium
- kind: test-defect
- where: tests/run-tests:7572-7575 ; tools/bt-capdiff:117
- evidence: `CDW=$(cd_run capdiff-a capdiff-a --since ... --until ...)` then `[[ "$CDW" == *"agree"* || "$CDW" == *"agreement"* ]] && ok "bt-capdiff accepts an explicit window and still compares inside it"`. bt-capdiff always prints `echo "Capture path agreement"` (line 117) before any branch, and the empty-overlap message says "coverage question, not agreement". Any output at all contains "agree".
- why it matters: the check is meant to prove a --since/--until window does not break or empty the comparison; a window that excludes everything (the case named in the comment at 7577) satisfies it too.
- confidence: confirmed

### "evidence/sessions untouched" checks cannot see a leak since BT_EVIDENCE_REPO is globally redirected
- severity: Medium
- kind: test-defect
- where: tests/run-tests:7846,7857 (INCSESS2) ; 7914,7925 (INCSESS_BEFORE) ; 542-543
- evidence: 543 `export BT_EVIDENCE_REPO="$SUITE_MACHINE/evidence-repo"` for the whole run; 7849/7915/7922 call `tools/bt-incident a-slug --bogus` / `--help` / no slug with that variable inherited, then 7925 `[[ "$(ls -1 evidence/sessions ... | wc -l)" == "$INCSESS_BEFORE" ]] && ok "no usage path collects anything - evidence/sessions/ is untouched"`.
- why it matters: if an option path did collect, the directory would appear under the declared machine's evidence-repo, not in this checkout's evidence/sessions, so these four counts stay equal and the "none of the option paths collected" ticks (7858, 7926) cannot go red. Comment at 7910-7913 describes the pre-redirect era.
- confidence: confirmed (the redirect and the check are both read; what a real leak would write to is inferred from bt-incident resolving its destination from BT_EVIDENCE_REPO, which README rule 4 states)

### Weak glob assertions that any later digit satisfies (the comment at 5405 says this was fixed)
- severity: Low
- kind: test-defect
- where: tests/run-tests:5408 ; 5465 ; 7788
- evidence: 5408 `[[ "$SOK" == *"HCI command timeouts"*"2"* || ... ]]` (comment 5405-5407 says "Anchored to the LABEL ... any timestamp, count or version string satisfies"; "2" after the label still matches any later 2 in the output). 5465 `*"btsnoop files:"*"2"* && *"capture gaps logged:"*"3"*` same shape. 7788 `[[ "$EHR" == *"N"*"on"* ]]` matches any "N" followed later by "on".
- why it matters: fixture-vs-host provenance of these counts is what the checks claim to pin; they would pass on a host-derived number or an empty join.
- confidence: confirmed

### Negative grep on a file that may not exist
- severity: Low
- kind: test-defect
- where: tests/run-tests:10279-10284
- evidence: `BKJ=$(bkj_setup); bkj_run "$BKJ" >/dev/null` then `if ! grep -q -- '--replace' "$BKJ/calls.log"; then ok "--replace is passed only for a marked prefix, never routinely"`. If bt-backup-journal refuses or never calls the stub, calls.log does not exist, grep exits 2, `!` makes it true.
- why it matters: passes when the driver did nothing at all; the neighbouring checks assert call counts, this one does not.
- confidence: confirmed

### README rule 4 says any spelled-out bt-trial call fails; the guard covers six verbs
- severity: Low
- kind: doc-vs-code
- where: tests/README.md:64-65 ; tests/run-tests:15144,15147 ; tests/run-tests:9541, 5503
- evidence: README "a second check fails on a spelled-out `tools/bt-trial <verb>` call outside them (the read-only `report` calls set `BT_REPO` on their own line)". The check is `grep -HnE 'tools/bt-trial +(autostart|start|ok|hang|abort|step)\b'`. Line 9541 `TADISP=$(BT_REPO="$TL" tools/bt-trial audit --help ...)` is a spelled-out call with only BT_REPO on the line, and 5503 `"$W/tools/bt-trial" report` (quoted path, `env -u BT_REPO`) is not matched by the pattern at all.
- why it matters: the two calls are harmless (read-only; BT_EVIDENCE_REPO is inherited from the declared machine), but the contract as written is wider than what is enforced.
- confidence: confirmed

### Duplicate check description
- severity: Low
- kind: test-defect
- where: tests/run-tests:8034 and 8494
- evidence: both `ok "bt-usbmon rejects an unknown argument"` (two sections-in-one-section: --check section and supervision-loop section; the first runs `bin/bt-usbmon --bogus` at 8033, the second `um --bogus` at 8493).
- why it matters: indistinguishable lines in output; a failure of one cannot be told from the other by text.
- confidence: confirmed

### Fixture derived from the real, tracked evidence/trials/results.tsv
- severity: Low
- kind: rule-vs-practice
- where: tests/run-tests:9459-9460 (ta_repo), 9498-9499
- evidence: `{ head -1 evidence/trials/results.tsv ...` builds the audit fixture's header from the real file; 9499 `head -2 evidence/trials/results.tsv | tail -1` copies the real row 1 and expects UNRESOLVED (boot has rotated away from fixture journal).
- why it matters: read-only, but the verdicts depend on the real evidence tree's header and first row (README rule 3/5: fixtures, not live data); a change in the real file's first row timestamp could flip the expected UNRESOLVED.
- confidence: confirmed

### Stale/dangling comments
- severity: Low
- kind: stale
- where: tests/run-tests:6318-6322 ; 6486-6489 ; 9561-9565 ; 6347-6348 vs 6391
- evidence: 6318 "Declared here; it is READ 4000 lines below" - the read is at 15556 (about 9,000 lines away). 6486-6489 a comment "THE SANDBOX ITSELF ... every assertion above ran bt-mode in APPLY mode" sits directly above `else` with no assertion (the check is at 6497-6507). 9561-9564 "THE POSITIVE CONTROL, WHICH IS THE WHOLE ANSWER TO A CONFIDENT ZERO" is followed by the unrelated "AND ITS COST MUST NOT SCALE" heading; the positive-control code is at 9606-9613. 6347 "these nine assertions" vs 6391 "turning eleven assertions red".
- why it matters: comments no longer sit by the code they describe.
- confidence: confirmed

## Checked and found clean (in range)
- Seam rules: tl (9054), tlt (9399), tlnh (9424) each set BT_REPO and BT_EVIDENCE_REPO; every bt-incident call carries INCENV/BT_EVIDENCE_REPO or env -u deliberately (7900). Fixture addresses are AA:BB:CC:00:00:01 or de:ad:be:ef:... (test-only), no real-looking data found. real_override_state (6305) reads /etc but is allow-listed in tests/access-allowlist:40-42,54-55.
- Section independence: only 7652 marker section reads cd_run/$CD from an earlier section (marked, and $CD removed at 7929). Helpers used elsewhere ($FIX, $BJ, $INCENV, $EMPTYLIB, $EMPTYDUMP, awk_intervals_ok, SETSID, SHFILES, rt_line) are all defined in the setup (lines 922-1296). No unmarked cross-section dependency found by reading plus a scripted scan (hits were false positives).
- Paths: every tools/bin/devtools/scripts/tests path named in the range exists in git ls-files.
- Doc-coupled assertions: none in this range (no assertion reads README.md, BRIEF.md or docs/*); fixture strings like 7.0.0-28 and EX-0xx are fixture data only.

NOT covered: lines 1-5199 and 10400-15600 of run-tests (only the setup helpers around 828-1300, the PARALLEL markers and the 15140/15408 guard checks were read); I did not execute anything, so "cannot fail" claims are by reading.

---

# Part: tests-3

### machine-tools omits machine tools that shipped code calls
- severity: Medium
- kind: rule-vs-practice
- where: tests/machine-tools (whole file; line 13 comment "runuser ... pw-metadata and gsettings"); tools/bt-ui-capture:242,229,235,149,365,370; tools/verify-restored.sh:155; bin/bt-trace:106; bin/bt-usbmon:118; scripts/cd-trace/cdda-remount.sh:9
- evidence: machine-tools line `runuser           # likewise: bt-ui-capture runs pw-metadata and gsettings as the desktop user` lists runuser but neither pw-metadata nor gsettings. Not listed and called by shipped code: gsettings (bt-ui-capture:242 `as_user gsettings get ...`), pw-metadata, dbus-monitor (bt-ui-capture:365), dpkg / dpkg-query (verify-restored.sh:155 `dpkg --verify bluez`; bt-ui-capture:229), getent (bt-ui-capture:149), ps (bt-ui-capture:235 `ps -o lstart=`), df (bin/bt-trace:106, bin/bt-usbmon:118 free-space verdict from the host disk), pgrep (scripts/cd-trace/*). Command: grep over git ls-files bin tools install.sh uninstall.sh scripts against the list from `sed 's/#.*//' tests/machine-tools`.
- why it matters: these are not tripwired nor decoyed; run-tests stubs dbus-monitor/gsettings/dpkg-query by hand in the UI tests (run-tests:11627,11638,11642) but a test that forgets meets the host. The file's own header admits it is hand-written and relies on devtools/sandbox as backstop (README rule 5 states "Every command ... answers from a tripwire").
- confidence: confirmed (list vs. grep); df/ps/getent runtime reach not checked

### run-tests comment cites stale line numbers of its own file
- severity: Low
- kind: stale
- where: tests/run-tests:15203-15205 vs tests/run-tests:35, 71, 161
- evidence: comment says "line 34 `cd "$(dirname "$0")/.."`", "line 70 `suite_file_set "$0" …`", "line 133 `out=$("$0")`"; actual lines are 35, 71 and 161 (grep -nE '"\$0"').
- why it matters: the check at 15310 counts three legitimate `$0` uses; a maintainer matching the comment to lines finds none.
- confidence: confirmed

### bt-snapshot "no unlabelled number" check cannot fail on a missing summary
- severity: Low
- kind: test-defect
- where: tests/run-tests:10628-10631 (and 11050-11054, 11278-11282 for the "touches no controller" greps)
- evidence: `STRAY=$(grep -nE '^[[:space:]]*[0-9]+[[:space:]]*$' "$SNDIR/summary.txt" || true)` then `[[ -z "$STRAY" ]] && ok`. If $SNDIR is empty/summary missing, grep errors, `|| true` hides it, STRAY is empty and the check prints a tick. Same shape: `SNTOUCH=$(grep -nE '(hciconfig|...)' tools/bt-snapshot | grep -vE ... || true)`, `CRTOUCH=$(grep ... tools/bt-crash ...|| true)` — a renamed/moved tool also yields empty and passes.
- why it matters: negative searches with no positive control; (10581 asserts summary.txt exists separately, so the first is covered indirectly, the two controller-touch scans are not.)
- confidence: confirmed (reading); needs-check whether a mutation run flags them

### tests/README.md coverage floors disagree with CI (awk 85 vs 95)
- severity: Medium
- kind: doc-vs-code
- where: tests/README.md:422-424; .github/workflows/checks.yml:301
- evidence: README: "the coverage, awk, python and comprehension steps each print theirs and hold a floor (80, 85, 80 and 75 on the branch `main` takes)". checks.yml: `run: devtools/awk-coverage --min 95` (coverage --min 80, py-coverage --min 80, test-comprehension --min 75 match).
- why it matters: a reader of the contract gets the awk ratchet wrong by 10 points; the workflow line was last touched in d63bff7 (2026-11-13) without the README.
- confidence: confirmed

### tests/README.md says the upgrade rehearsal asserts 17 checks; the script has 20 ok() sites
- severity: Low
- kind: stale
- where: tests/README.md:376 ("What it asserts (17 checks)"); tests/system-upgrade:175-312
- evidence: `grep -c 'ok "' tests/system-upgrade` = 20 (lines 175,185,204,211,217,229,240,243,246,248,252,259,274,282,291,297,301,305,308,312). Some are conditional/alternative, but at least 19 run on every pass (line 301 is the `|| ok` arm).
- confidence: confirmed (count); the bullet list under it does not enumerate 17 either

### system-roundtrip: the "experiment mode" gate is unreachable
- severity: Low
- kind: test-defect
- where: tests/system-roundtrip:60-63 (gate 2) vs :70-73 (gate 4); tests/README.md:397-400
- evidence: gate 2 `if [[ -e /usr/local/share/qca9377-bt-hang ]]; then ... exit 1` runs first; gate 4 `if [[ -r /usr/local/share/qca9377-bt-hang/mode ]]` can only be true when that directory exists, so it never fires and its message ("in experiment mode") is never shown. README lists them as separate gates.
- why it matters: the experiment-mode refusal is dead code; the host is refused with the "has an installation" message instead (safe outcome, wrong reason).
- confidence: confirmed

### system-roundtrip final "nothing survives" check passes on an empty derivation
- severity: Low
- kind: test-defect
- where: tests/system-roundtrip:181-193
- evidence: `LEFT=$(awk ... install.sh | grep -oE 'install_file[[:space:]]+"\$SRC/[^"]+"[[:space:]]+[^[:space:]]+' | awk '{print $3}' | sort -u | while read -r p; do [[ -e "$p" ]] && echo "$p"; done)` then `[[ -z "$LEFT" ]] && ok`. If the pattern stops matching install.sh (it matches 70 lines today) LEFT is empty and the tick prints; there is no non-empty guard on the derived list (system-upgrade has the same shape, lines 124-129, but compares counts). Redirect-written files (udev rules, drop-ins, stamp) are not covered, as tests/README.md:364-366 admits.
- confidence: confirmed (reading)

### Silent skips inside run-tests: python3 / zstd / tool-absent branches print nothing
- severity: Low
- kind: test-defect
- where: tests/run-tests:14039, 14475, 14515 (`if command -v python3 ...; then ... fi`, no else); 14026 `kcheck` `command -v "$3" || return 0`; 10440-10445 (zstd absent: the whole copy suite skipped, reported only inside an ok text)
- evidence: none of these set a *_SKIPPED variable; the final "NOT ASKED HERE" block (15556-15580) only reads PRIV/UIATSPI/UINS/COWORLD/AWKCOV/AUDIT/COREDUMP_SKIPPED and the farm/validator tool list. A host without python3 or zstd shows a smaller green run with no note (the file's own rule, 15462-15470, is that skipping silently is what is wrong).
- confidence: confirmed; severity low because CI has all of them

### staged --apply tests only ever install the positive-control device
- severity: Low
- kind: other
- where: tests/run-tests:12338, 12436 (`stage_install BT_VID=0cf3 BT_PID=e300`); no staged --apply without BT_VID
- evidence: every `stage_install` call passes `BT_VID=0cf3 BT_PID=e300`; the shipped default 13d3:3503 is covered by the dry run only (run-tests:8366-8376 "install.sh plans no drop-in for the default device"). The staged mode/policy/removability checks (12351-12405, 12457-12486) therefore never run on the default install that a user performs (no drop-ins).
- confidence: likely (other --apply calls at 12648-12714 are guard tests)

### tests/btmon/README.md "The cases" table lists 3 of the btmon fixtures
- severity: Low
- kind: stale
- where: tests/btmon/README.md (table at the end: sco-paired, sco-unanswered, sco-bitmap-only); files present: sco-enhanced.txt, capdiff-a/b.txt, capdiff-dup-a/b.txt, ctrl-window.txt, render, real/
- evidence: `ls tests/btmon`; the README opening says it covers `bt-sco`, `bt-capdiff` and `bt-ctrl-window`, but the cases table names only the sco ones.
- confidence: confirmed

## Fixture privacy scan (checklist 5): CLEAN
- tests/btmon, tests/btmon/real, tests/journal (46 dirs), tests/coredump, tests/fixtures, *.data/*.tsv/*.log: 231 files scanned.
- Bluetooth/MAC-shaped strings: only AA:BB:CC:00:00:01/02, AA:BB:CC:DD:EE:FF (btmon, journal/context-anchors, journal/actions-all, real/mkcap.py; documented placeholder OUI), 00:00:00:00:00:00 (journal/window), and sanitize-invariants.log patterns 11:11:11:22:33:44, 00:11:22:33:44:55 (test inputs). No `dev_XX_..` forms.
- IPv4 outside 0.0.0.0/127/192.0.2: none (sanitize-invariants.log only 255.255.255.255, 127.0.0.1, 0.0.0.0).
- Hostnames: `host`, `n`, `h` only; no /home paths, emails, UUIDs, serials, device names. Coredump fixtures carry Hostname: n, Machine ID 1111..., Boot ID 0000...
- run-tests 10400-15600 inline fixtures: same placeholders; `dc:a6` `32:11` `22:33` (run-tests:14884) is a split real-OUI pseudonym built to test the MAC gate (allowed since 2026-10-11).

## Checked and found consistent
- BRIEF §8a condition in system-roundtrip/system-upgrade: now asks `/run/systemd/system` + state running|degraded, waits up to 180 s on starting/initializing; skip prints state and exits 3 under BT_SYSTEM_TEST=required; CI (.github/workflows/checks.yml:453,471,474) passes `required`. Skip is visible and says why.
- Five bt-trial wrappers (trial 1235, trial_in 1244, tl 9054, tlt 9399, tlnh 9424) each set BT_REPO and BT_EVIDENCE_REPO per the check at 15412-15420.
- Section independence in 10400-15600: scripted var/function-use scan found no use of another section's definitions except 11347 which carries the PARALLEL marker.
- Paths named in 10400-15600 exist or are fixtures built at run time; seam defaults in tests/system-resources.md §1 match the code (spot-checked 16 seams); whole-boot-reads.txt 41 entries/21 files matches its header.

---

# Part: history

## history findings

### BRIEF §10 says HISTORY has dated chapters only "to 2026-10-28"; HISTORY has chapters to 2026-11-14
- severity: Low
- kind: stale
- where: BRIEF.md:877; HISTORY.md:4434 (last dated chapter "(2026-11-13 → 11-14)"), :4397, :4340
- evidence: BRIEF: "HISTORY.md (37 phases, dated chapters to 2026-10-28, and the retired hand-off blocks)"; [wording of the P-01 class omitted] Phases counted: `grep -c '^## Phase' HISTORY.md` = 37, numbered 1..37 consecutively, no gaps/duplicates.
- why it matters: BRIEF's index of where detail lives is stale by 17 days; the retired blocks it describes run to 11-12 (moved 11-14).
- confidence: confirmed

### Structure check (no finding): 37 phases, numbered 1..37 consecutively, no gaps or duplicates
- kind: other / severity: Low (informational)
- where: HISTORY.md:25 (Phase 1) ... :3023 (Phase 37); `grep -o '^## Phase [0-9]*'`
- evidence: phases 1-37 present once each; "Phase 18a" is a ### subsection (:1030). 19 dated chapters follow (:3566 ... :4434), in chronological order, last = "(2026-11-13 -> 11-14)" at :4434. Retired blocks all present at the end: 10-03 move (:4496; nine blocks, only five literally titled RESUME HERE), 10-05 (:4703), 10-08 (:4771), "as it stood on 2026-10-18" (:4850, the 10-12..10-15 items), 10-28 move holding the 10-18..10-23 hand-off (:4960), 10-28 hand-off moved 10-30 (:5248), 10-29/30 block moved 11-02 (:5346), X1 bullet 11-07 (:5417), 11-12 block moved 11-14 (:5491). BRIEF/README "37 phases" is correct.
- confidence: confirmed

### Milestones paragraph says BlueZ patches "sent and applied, Phase 36"; they are in Phase 37
- severity: Low
- kind: contradiction
- where: HISTORY.md:5-7 (milestone line); :3185 "### Sent" and :3371 "### Applied -- and the v2 that was already moot" (both inside Phase 37, which starts :3023 and ends :3566); Phase 36 is :2944-3022 (BlueZ conventions, return to stock config, EX-043)
- evidence: ":6 BlueZ patches sent and applied, Phase 36"; Phase 36 text has no send or apply. Sent 2026-09-19 and applied 09-21 are narrated under Phase 37.
- why it matters: the milestone index sends readers to the wrong phase.
- confidence: confirmed

### Milestones paragraph stops at 2026-11-07; retired blocks run to 11-12 and chapters to 11-14
- severity: Low
- kind: stale
- where: HISTORY.md:11-15 ("the hand-off blocks BRIEF carried from 2026-10-03 to 2026-11-07, verbatim, at the end"; last milestone "(2026-11-07)"); actual: :4397 (11-07 -> 11-12 chapter), :4434 (11-13 -> 11-14 chapter), :5491 (11-12 block "moved verbatim on 2026-11-14")
- why it matters: front matter of HISTORY understates what the file holds (BRIEF §10 has the same staleness, see first finding).
- confidence: confirmed

### Phase 34 still says "27-byte mSBC frames pushed into a 9-byte endpoint" with no correction note; the 4th-review chapter says that wording was "withdrawn everywhere it stood"
- severity: Medium
- kind: contradiction (unflagged old claim)
- where: HISTORY.md:2715 vs :3213-3218 (also :2914 uses neutral "27-byte frames on the 9-byte endpoint")
- evidence: :2715 "680, 682, 1562 27-byte mSBC frames pushed into a 9-byte endpoint, each followed by a bare command tx timeout"; :3215-3218 "'27-byte frames into a 9-byte endpoint' ... implied a transport-size violation the log never showed ... The mechanism claim does not [survive], and it is withdrawn everywhere it stood." Other superseded Phase 29/30/32 passages carry inline SUPERSEDED/corrected notes; this one has none. (BRIEF §1 itself uses "three 9-byte packets ... not an overflow".)
- why it matters: a reader of Phase 34 meets the withdrawn mechanism claim as current.
- confidence: confirmed

### Phase 18 calls EX-004's reset "the first EARLY reset ever captured"; Phase 10 already recorded a successful early reset the night before
- severity: Medium
- kind: contradiction
- where: HISTORY.md:901-902 ("This incident contained the first EARLY reset ever captured -- the watchdog fired 134 s before any HCI timeout") vs :383-410 (Phase 10, "EARLY recovery SUCCEEDED", "Zero tx timeout events for the entire boot", boot ending 08-11 00:21; session dir evidence/sessions/20260811-002156-early-mode-SUCCESS) and :457 ("the only reset issued before one succeeded"); EX-004 extraction window is 2026-08-12 00:09:20 to 00:14:30 (evidence/exhibits/004-*.md)
- evidence: Phase 10 and Phase 18 each present "the" early reset; they are different events one day apart (Phase 10 had no timeout in its boot; EX-004 timed out 132 s after). Later text (:952 "five late resets failed and one early one succeeded"; BRIEF §3 "the one reset issued before any timeout recovered it ... failed again 132 s later (EX-004)") counts only one early reset, so either the count or "first" is wrong.
- why it matters: n of early resets (1 vs 2) is load-bearing for the Phase 10/11/17 argument and for BRIEF §3.
- confidence: likely (needs-check: whether the Phase 10 and EX-004 early resets are two events; the exhibit dates say yes)

### Phase 30 "Eight residual sentences" names seven
- severity: Low
- kind: contradiction
- where: HISTORY.md:3261-3264
- evidence: 'Eight residual sentences -- "any HCI command", "no harm", "CVSD is safe", "this hardware falsifies", "finds no alternate setting 6 or 3", "not in a stable release yet", "every tested recovery failed" --' (7 quoted; and the last is the replacement wording introduced earlier at :3221-3223, not a residual sentence)
- confidence: confirmed

### Same figure written two ways: 1836 s vs 1837 s (the 30 m 36 s untreated window)
- severity: Low
- kind: contradiction
- where: HISTORY.md:1774 ("1836 s against 45-66 s") vs :1850 ("12107 s, 8884 s, 4332 s, 1837 s")
- confidence: confirmed (30 m 36 s = 1836 s; rounding only)

### CO-04 competing patch: "9 of 12 boots" vs "8/12 power boots"
- severity: Low
- kind: contradiction (needs-check: may be a different boot subset)
- where: HISTORY.md:4100 and :5088 ("lock inversion (9 of 12 boots)") vs :5384 ("14888791 as posted gives a lockdep circular dependency in 8/12 power boots, ours 0/12")
- confidence: needs-check

### Identifier elision ("...") in text written after 2026-09-18 (project rule: "Write identifiers in full ... Never ...", BRIEF.md:486-488; Message-IDs "never mask, elide" BRIEF.md:431-435)
- severity: Medium (rule-vs-practice); the 4473 hit is outside the verbatim-moved blocks
- kind: rule-vs-practice
- where / evidence (HISTORY.md line: elided text; full name exists in tree where noted):
  - :4473 `reviews/2026-11-14T0300Z-...` in a 11-13/14 chapter (full file: reviews/2026-11-14T0300Z-kernel-patches-ready-to-send-for-outside-review.md, named in BRIEF.md:192). Not in a moved block: clearest violation.
  - Public Message-IDs elided (BRIEF §7 says never): :4875 `<20261010022523.2789588-{1,2,3}-...>`, :4877 `<20261010031846.2842837-1-...>`, `<20261010031852.2842893-1..4-...>`, :4903 `<20261008034102.707451-1-...>`, :5194 `<20261018043903.1756818-1-...>` / `<20261018043911.1756937-1-...>`, :5368 `<20261029013350.360574-1-...>` (10-29, after the 10-13/10-21 rule). Same Message-IDs are given in full elsewhere in the repo (e.g. :4707 and :4785 show the 10-02 and 10-06 ones in full).
  - srcversion / sha / hash prefixes with ellipsis: :4600 `36ADEF2A...`, :4610 `f13d86c4...`, :4614, :4674 `f635c447...`, :4969 `D1DEA96A...`, :4988 `702186d9...`, :4989, :5464 `e60fcf37...ec6e`, :5474 `36175938...`.
  - paths: :4521 `patches/mesh-tester/0001-...`, :5036 `contributions/CO-02-.../patch/v5/`, :5162 `...T0225Z`, :5264 `work/...-20261028`, :5290-5291 `CO-35-...`, `CO-11-...`, :5324 `comms/2026-10-28T0300Z-...`, :5373 `CO-25-...`, :5381 `CO-05-...`, `CO-04-...`, :5389 `CO-23-...`, :5421 `cdda:host=sr0/...`.
  - Caveat: all but :4473 are inside blocks the file labels "moved verbatim" (written in BRIEF 09-26..11-07), so fixing them would conflict with "verbatim"; the rule and the label cannot both hold. Quotes/commands with "..." (:3220, :3282, :3305, :3348, :4367) are not identifiers and are not counted.
- confidence: confirmed (grep -n '...' on lines > 3185)

### Broken references (paths absent from `git ls-files`), all inside moved-verbatim blocks
- severity: Low
- kind: broken-reference
- where / evidence:
  - HISTORY.md:4802 `patches/mesh-tester/bluez-shared-mgmt-notify-leak-on-d84171e6c-2026-10-08/`: tree has `patches/mesh-tester/bluez-shared-mgmt-notify-leak-on-d84171e6c/` (no date suffix).
  - HISTORY.md:4812 `docs/mesh-tester-ci/power-off-compare-2026-10-05.md` and :4928 `power-off-compare-2026-10-05.md`: not tracked (docs/mesh-tester-ci/ has no such file); :4928 itself says "kept separately", :4812 presents it as a committed doc path.
  - HISTORY.md:5139 `reviews/2026-10-21-recheck-of-v6.md`: actual path contributions/CO-10-stable-6.6.160-rc2/reviews/2026-10-21-recheck-of-v6.md (dossier-relative, ambiguous).
  - Dossier-relative paths without a prefix (:4992 `experiments/hardware-run-plan.md`, :5016, :5047, :5078, :5084, :5290; :5259 `send/README.md`; :4974 `trial-02/NOTE-journal-window.txt`; :5432 `patch-track/`) resolve only under contributions/CO-02-sco-connect-reuses-closing-link/, CO-35-l2cap-ecred-defer-hang-stable/, evidence/trials/E3/, X1-gvfs-cdda-readahead/ respectively.
  - All 97 EX-nnn numbers cited exist (exhibits 001..097 present); all other tracked-path references (scripts/, docs/, reviews/, results/, comms/) resolve. Untracked tmp/, cache/, archive/ and branch names (kernel/mgmt-flush-status, fix/ci-invariants-2026-10-03, docs/second-edit-2026-10-03) are git-ignored/held by design and not counted.
- confidence: confirmed (script: backtick tokens vs git ls-files)

### BRIEF phase pointers checked: all five correct
- Phase 14 (:548) operator-did vs controller-responded: yes. Phase 17 (:712,:718) six behaviours of BTUSB_QCA_ROME: yes (the six are listed). Phase 19 (:1062,:1073) EX-006 one unanswered 0x0428: yes. Phase 25 (:1625,:1629) bt-stage2 over 22 boots: yes. Phase 29 addendum (:2206) EX-034 reboot withdrawal: yes.
- Retractions of BRIEF §5 in HISTORY carry nearby correction notes: "anonymous by construction" (:2094 SUPERSEDED, :2571 bracket), "alt probes, then silence" (:2279, :2292, :2561), "287 denominator" (:2033 bracket; Phase 30 item 4), "evt 5" (:2288 corrected in Phase 30 item 3), EX-038 boot id error (:2809 Phase 34 "wrong boot id"; neither c128a59a nor f5de8066 appears in HISTORY), "0002 never fired" (Phase 34, "Two errors, both the same error"), EX-034 / ladder (:2206-2252), discovery-stuck-until-reboot (:3907 corrected 2026-10-14). No unflagged re-assertion found except the 9-byte-endpoint wording above.

---

# Part: exhibits

## Findings: evidence/ (exhibits, trials, baseline, diagnosis, sessions README)

### BRIEF signature table: survival row counts 8 packets in the `len 27 mtu 9` column; exhibit says 0
- severity: Medium
- kind: contradiction
- where: BRIEF.md:277 (`| *survival* | 09-01 | -30 | modified | **8** | — | *lived* |`); evidence/exhibits/037-sustained-alt1-traffic-precedes-the-wedge.md:14-23; evidence/exhibits/033-...md:11-12
- evidence: BRIEF column header `len 27 mtu 9`, survival cell "**8**". EX-037 table: "| 2026-09-01 daytime — 3 transparent links | **0** | **alive** |" and "carrying **eight** `len 90 mtu 9` packets ... the survival has none." EX-033: "the one recorded survival ... carries **none**."
- why it matters: the table suggests the survivor had 8 len-27 frames; the exhibit says 0 len-27 frames (8 is the count of len-90 packets). It is the key contrast of the alt-1 hypothesis.
- confidence: confirmed

### BRIEF signature table: EX-042 first-command delay "~90 ms" is not in EX-042 (or any exhibit)
- severity: Low
- kind: contradiction (unsupported cell)
- where: BRIEF.md:271 (`| EX-042 | 09-16 | -31 | modified | 1595¹ | ~90 ms | 2.147 s |`); evidence/exhibits/042-sixth-instance-and-the-treatment-stamp-was-wrong.md (whole file)
- evidence: `grep -n -i -E 'first command|dying|queued|0x0406|~90|90 ms' 042*` returns nothing; the output shows only 0x0428 (+83.8 ms answered), evt 5, alts, tx timeout at 2.147 s. EX-040's table (lines 77-84) compares only 033/036/037/038/040. 0x0428 answered +83.8 ms is the nearest "90".
- why it matters: the cell may be the answer-latency (83.8 ms) mislabelled, or an unrecorded estimate; neither is in the exhibit.
- confidence: confirmed (absent); source of ~90 needs-check
- Other 11 rows: date, kernel, config, count and setup->fault checked and agree (033 835/36 ms/2.076; 036 87/279/2.152; 037 680/39/2.151; 038 682/35 [via EX-040 table]/2.191; 040 1562/34/2.140; 043 910/9650/11.874; 045 735/2.018; 047 717/2.053; 051 1857/3.672 & 2.020; 052 3605/2.051; 053 2432/7.331 s/9.421). EX-038 boot id is f5de8066 everywhere in evidence/; the only c128a59a in evidence/ is the explicit correction at 038:154.

### Index rows repeat claims that the exhibit itself refutes, corrects or supersedes (EX-007, 006, 086, 093, 058, 033, 036)
- severity: Medium
- kind: register-integrity
- where: evidence/exhibits/README.md rows EX-007, EX-006, EX-086, EX-093, EX-058 (and 033, 036); exhibits 007:3 and 007 "Refuted on 2026-08-12", 006:5, 086:3, 093:3, 058 "Correction, 2026-10-29", 033/036 "CORRECTION — 2026-09-02"
- evidence: index EX-093: "No kernel error and no HCI command timeout on boot af3f9840 ... the controller is not involved." while 093:3 "**Superseded by EX-094 (2026-11-13).** ... the output contradicts it". Index EX-086 gives the full claim; 086:3 "**Superseded by EX-087.** ... this exhibit supports nothing". Index EX-007: "The hang requires no operator action at the moment it occurs..." (exhibit: claim "CORRECTED ... Refuted"). Index EX-006 states "The controller's loss of HCI responsiveness begins at that boundary" (006:5 "Superseded in part by EX-009"). Index EX-058 repeats "applies only the QCA setup part ... isolates" whose correction is in the exhibit. Only EX-018 and EX-020 are marked ("Historical claim:") in the index. EX-094 is marked as correcting EX-093 (one direction only).
- why it matters: the project asks that supersession be marked in both places; a reader of the index alone (the stated entry point) acts on false claims; EX-093 is exactly the one named in the brief.
- confidence: confirmed (`grep -E '^\| EX-(007|058|086|093|006) ' README.md | grep -ci 'correct|refut|supersed'` gives 0 for these except EX-094's "Corrects EX-093")

### Index/exhibit numbering and integrity otherwise clean
- severity: Low (informational, no defect)
- kind: register-integrity
- where: evidence/exhibits/README.md; evidence/exhibits/
- evidence: python check: 97 index rows, 97 files, EX-001..EX-097 with no gaps and no duplicates, link text/target/title match; index claim text equals each exhibit's Claim verbatim except EX-018/EX-020 ("Historical claim:" prefix) and EX-007/EX-086 (exhibit prefixes "(CORRECTED...)", "(unsupported here)" in the Claim label). No directory-form exhibits; all are .md.
- confidence: confirmed

### EX-043 has no exit status and no redaction statement (and is hand-form)
- severity: Medium
- kind: rule-vs-practice
- where: evidence/exhibits/043-first-command-into-alt1-stream-dies.md:20-27 (commands), :96-110 (Provenance table)
- evidence: Provenance table has kernel, bluez, boot id, treatment, trial, session, confirms, refines; no `| exit status |` and no `| redacted |` row. The other 96 exhibits have both (`grep -c '| exit status'`). Extraction block lists 4 commands, header says only "Re-runnable while boot eddd1961 is retained" and its output block has no "Verbatim, N line(s), exit status" line. Also the 4th command's tool paths are relative (`tools/bt-fault-window`) — the same flaw EX-047 documents in its 2026-09-26 correction.
- why it matters: breaks "every claim ships command + output + exit status + redaction"; EX-043 is the pivot exhibit of the signature (9.65 s of stream before the first command).
- confidence: confirmed. (All other exhibits carry command, output, exit status row, redacted row; EX-018/020 use "Historical claim" instead of "Claim"; exit status 127 in none, status `1` in 015,019,072,078,083,086,088, status 1 plausibly grep no-match — not checked each.)

### E1 headline: EX-056 is a subset of EX-058, they do not "sum"
- severity: Low
- kind: contradiction (wording)
- where: evidence/exhibits/056-e1-seven-wideband-disconnects-answered.md:3; 058-e1-setup-only-58-links-three-boots.md:3,22-95; 055 (no links)
- evidence: EX-058 ledger: boot 226965f1 "links 34", boot 855a927e "links 21", boot 8709ee7c "links 3", "TOTAL over 3 boot(s): links 58 hang-ups answered 58 timeouts 0" (34+21+3=58 verified). EX-056 covers 7 links on the same boot 226965f1, 2026-09-26 21:52-21:55 (EX-058 lists 21:52:50 and 21:53:23 on that boot). EX-055 has no SCO links. Two headsets (MOMENTUM 4, GM2 pro) in EX-058; EX-057: "16 links ... 0 command timeouts and 0 unexpected-event 0x2005", ledger "links 16 hang-ups answered 16 timeouts 0" and 2 headsets - agree. 58+16=74 holds only if EX-058 alone is E1.
- why it matters: if anything states "EX-055+056+058" are summed, 7 links would be double-counted; E1 total is EX-058 alone.
- confidence: confirmed

### EX-057 headline "all 16 hang-ups answered" sits beside an "Opcode 0x0406 failed: -107"
- severity: Low
- kind: contradiction (wording)
- where: evidence/exhibits/057-e3-upstream-entry-16-links-two-headsets.md:3, :39-40
- evidence: claim "16 SCO links ... all 16 hang-ups answered"; claim also lists "one Disconnect answered -107 at 01:00:03 when the adapter was switched off by rfkill"; output line 40 "Opcode 0x0406 failed: -107". The ledger counts 16 answered. A Disconnect that failed with -107 (ENOTCONN) is not a controller answer; whether that link is one of the 16 is not shown.
- confidence: needs-check

### Index claims for E1/EX-031 checked as stated
- severity: Low
- kind: other
- where: evidence/exhibits/031-enhanced-sco-setup-answered-and-survived.md:3-6,53-55,104-108
- evidence: BRIEF describes EX-031 as a transparent link on alt 1; EX-031 says "completed the USB alternate-setting switch" (Looking for Alt no :6 then :3), "evt 5 ... transparent (wideband)", ~17 min, Enhanced 0x043D answered in 64.7 ms; it contains no sysfs read of alt 1 (no bt-usbstate then); "alt 1" appears nowhere in the file (`grep -i 'alt 1\|alt-1' 031*` empty); it only has `len 90/len 27 mtu 9` debug lines.
- why it matters: "survived on alt 1" is inferred, not observed there (the signature elsewhere relies on direct sysfs reads).
- confidence: confirmed (absence)

### Other claims verified as stated (no finding)
- EX-041: "fired four times in 19 days" = 08-26 (1) + 09-02 (3), window 2026-08-25→09-13 = 19 days; the 09-08 line is "Wrong size of start discovery", not a firing.
- EX-059: seven lines, all cherry-pick OK, entry x1, -Werror rc=0 unpatched and picked, exit status 0. EX-061: seven lines QUEUED, request 2026-10-02 (captured 2026-10-03T21:43+02). EX-062: two stuck cycles, 8 h 18 min (29893 s) / Busy 0x0a at 13:57:53/59. EX-023 (11.15 s to USB disconnect after reset), EX-026 (rfkill, -110, foreign reset, disconnect 85.6 s, not back on bus), EX-046 (09-23, Reset 0x0c03 -110 on healthy controller), EX-006 (one unanswered 0x0428, 2.169 s; superseded in part by EX-009).
- baseline/baseline.tsv: 34 boots, tx_timeouts sum 287, 13 YES; matches evidence/README.md:~33 "287 timeouts, 13 of 34 boots hung". kernel-boot0.sanitized.log has 22 "tx timeout" lines as README says.

### results.tsv: BRIEF "E3 #3 has no row" vs a row labelled "E3 #3" in results.tsv; duplicate trial numbers
- severity: Medium
- kind: register-integrity
- where: BRIEF.md:139-141; evidence/trials/results.tsv (E3 row with trial=3, 2026-10-30T19:52:04+01:00, `failed`, duration 1752); evidence/trials/E3/trial-03/NOTE-not-plain-E3.txt:1; NOTE-verdict-of-2026-10-30-is-an-artefact.txt:1-4; E3/trial-05/NOTE-two-uses-of-this-number.md; E3/trial-11/NOTE-two-trials-one-number.md
- evidence: BRIEF "E3 #3 ended at that shutdown and has **no row** in `evidence/trials/results.tsv`". results.tsv does hold an "E3 ... 3 ... failed ... 1752 ... 7.0.0-42" row (a different boot, 46cb5188, plain E3), which the trial-03 NOTE says "holds two trials". Same number reuse: E3 #5 ("The number 5 was opened twice": first use, boot 045caff5, no row; second use, the row) and E3 #11 (boot 46cc4812 no row; row 11 is boot 680c448c). Also three uses of E3 #1 (-34 lost; -38 lost 10-13; the closed one) and two of #2 per BRIEF 127-133. results.tsv itself has no duplicate (type,build,trial) keys and every row has 23 columns (checked by script).
- why it matters: reading the tsv by trial number attaches the wrong boot to #3/#5/#11; the BRIEF sentence is only true for the CO-02 boot, and nothing in the tsv rows marks the reuse.
- confidence: confirmed

### results.tsv rows E1: #1 and #2 rows match BRIEF; "failed" rows are not annotated
- severity: Medium
- kind: register-integrity
- where: evidence/trials/results.tsv (E3 rows 1-11); E3/hang-verdicts-check-2026-11-07/README.md:60-72; E3/trial-03|04|05 NOTEs; BRIEF.md:158
- evidence: Verified: E3 #1 row 2026-10-18T17:03:54, `ended_unprobed`, sco_sent 13, timeouts 0, 419657 s, -38 (matches "13 SCO setups, 0 timeouts"); E3 #2 row 2026-10-23T09:34:50, sco_sent 55, timeouts 0 (matches). But 9 of 11 E3 rows read `trial_result failed` / `responds_after no`: only #3, #4 (and #5 via its NOTE) are shown to be closer artefacts ("NOT a hang"); #6, #7, #8, #10, #11 have no NOTE (trial-06..10 dirs hold only state/sco-params/steps.log; #6 has usb_lost 82, #11 usb_lost 1) and #9 is `confirmed` with a usb_reset perturbation. The word "HANG" appears only in closer output, not in a tsv column; the two examined verdicts' rows still say `failed` with no `NOTE`/flag column. The closer output at trial-01/close-output.txt lists "UNRECOV 4/6" style aggregates that count such rows.
- why it matters: a denominator computed from `trial_result` counts artefact boots as failures; BRIEF says only two verdicts were examined, which leaves #6-#8, #10, #11 unexplained.
- confidence: likely (aggregation behaviour of closer needs-check; the missing notes confirmed)

### evidence/README.md stale in places
- severity: Low
- kind: stale
- where: evidence/README.md (tree block near top; "The sessions so far" table)
- evidence: tree lists baseline, diagnosis, sessions, exhibits, trials but `evidence/off-topic/` exists (X1-cd-playback-underflow-every-16s.md); sessions table says "lists the first four" but the directory holds 29 sessions (self-declared, so low).
- confidence: confirmed

### Privacy scan of evidence/ (no real addresses found)
- severity: Low (negative result)
- kind: privacy
- where: evidence/ (all text)
- evidence: colon/dash BT-address regex over evidence/: 91 files match, only AA:BB:CC:00:00:01..18 (counts 2712 ... 2), AA:BB:CC:DD:EE:FF (1, in evidence/README.md usage example) and 00:00:00:00:00:00 (1). Underscore form: AA_BB_CC_00_00_01 (exhibit 030). No IPv4 (excluding 0.0.0.0/127.0.0.1) found, no link-key values (only mentions: exhibit 035:165 "new key for <peer>", bluetoothd get_ltk_info lines with placeholder addresses), no machine-id / SSID values (wlp2s0 interface name and placeholder BSSIDs only); 'hostname' hits are bluetoothd plugin names. No pseudonym-with-real-OUI files, so no "this file says so" duty arises. Absolute paths `/root/exp/qca9377-bt-hang/...` occur in command lines (not an address). USB root-hub serials 0000:03:00.x (PCI addresses) in baseline log.
- confidence: confirmed

### EX-038 command contains an elided "…"
- severity: Low
- kind: rule-vs-practice
- where: evidence/exhibits/038-alt1-wedge-on-a-new-kernel-clean-window.md:42
- evidence: `$ journalctl --file /root/bt-journal-archive/boot-f5de8066.export.zst …` — the project rule says identifiers in full (no "…" elision).
- confidence: confirmed (command truncation; cosmetic)

## Follow-up: docs/issues.md 145-1000

### STATUS BT-1 row still tells the reader to avoid -42 without E3; STATUS itself and BRIEF say E3 is retired
- severity: Medium
- kind: stale
- where: docs/STATUS.md:59 (BT-1 row, "next" cell); docs/STATUS.md:170 and :185; BRIEF.md:120-122, :181
- evidence: STATUS:59 "the Ubuntu kernel carrying it: `-39`, in proposed, does not, and **neither does `7.0.0-42.42~24.04.1`** ... **no boot into `-42` without E3 built for it** ... more headsets on E3 meanwhile". STATUS:170 "`7.0.0-43.43~24.04.1` ... carries `13d3:3503` in its stock btusb ... **2026-11-12: published in noble-updates**"; STATUS:185 "Ubuntu's `7.0.0-43-generic` with the stock btusb and the stock `bluetooth.ko`; E3 is retired". BRIEF:181 "**E3 is retired; CO-09 is done.**"
- why it matters: the register row's next-step is done; a reader of the issue table would still plan E3 builds.
- confidence: confirmed

### STATUS BT-9 row contradicts itself: "not yet released for 6.1" and "released ... 6.1.191 (2026-10-30)" in one row
- severity: Medium
- kind: contradiction
- where: docs/STATUS.md:67 (BT-9 row, status cell vs next cell); docs/issues.md:819-820
- evidence: STATUS:67 status cell "**not yet released for 6.1** (in 6.1.191-rc1, 2026-10-17, still open on 2026-10-28 ...)" ; same row, next cell "released in 6.6.160 (2026-10-21) and 6.1.191 (2026-10-30) ... done (corrected 2026-11-12: ...)". issues.md:819 "the backports are released in 6.12.113 (10-15), 6.6.160 (10-21) and 6.1.191 (10-30) ... Nothing is owed". Also BT-9 section header issues.md:789 still reads "Status 2026-10-09 ... missing from the 6.12, 6.6 and 6.1 stable lines, which the backport is about to expose" and line 818 "**Next:** replies" (followed by "**Since:**", so labelled).
- why it matters: STATUS (the current-state page) says 6.1 unreleased in the status cell; issues.md and the same row's next cell say released. Same pattern BT-8 got corrected for on 11-12 (STATUS:66) but BT-9's status cell was not.
- confidence: confirmed

### Evidence model section still states "n = 2 ... never to its end" and "open question in BT-1"
- severity: Low
- kind: stale
- where: docs/issues.md:200, :203-206, :212; :400-402 (BT-1 "Still unknown"), :358-363 ("The experiment that settles it"), :376-381
- evidence: "(n = 2, both censored)"; "The right-hand branch has been walked twice — `EX-016` ... and `EX-021` ... and never to its end"; "Across fifteen windows, a USB collapse has never once begun before something touched the controller"; BT-1 "Still unknown: ... whether stage 2 occurs at all without intervention, whether firmware download prevents the fault"; "With two fatal and three survived observations". Exhibits: EX-025 "untreated ... window of 8883.7 s", EX-029 "47338.1 s — 13 h 8 m 58 s with zero [USB lines]", EX-033 35113.4 s, EX-054 "untreated for 12 h 34 min ... USB layer logged nothing"; E1/E3 answer the firmware question (BT-1 header 258-261). The Evidence-model section carries no "as written" banner (BT-1's body does, lines 261-262).
- why it matters: the branch counts (n=2, fifteen windows) are contradicted by exhibits; the BT-1 header says the rest is "kept as written", the Evidence-model section does not.
- confidence: confirmed

### M-1 and M-2 have STATUS rows but no section in issues.md; M-rows out of numeric order in both files
- severity: Low
- kind: register-integrity
- where: docs/STATUS.md:84 (M-1), :88 (M-2); docs/issues.md:705 (M-3), :731 (M-4), :765 (M-5) placed between BT-8 and BT-9; STATUS row order M-1, M-4, M-5, M-3, M-2 (lines 84-88)
- evidence: `grep -n '^## M-' docs/issues.md` gives only M-3, M-4, M-5; M-1/M-2 appear only in the old "Current state" bullets (issues.md:65, :100-104). All BT-1..BT-25 STATUS rows have sections (BT-17..25 at issues.md:1012-1165). issues.md:857 itself notes BT-10..13 had earlier been omitted.
- why it matters: reviewers searching the register for M-1/M-2 find no entry; STATUS M-2 row is the longest and has no counterpart.
- confidence: confirmed

### M-3 section does not carry the BlueZ 5.88 release that STATUS records
- severity: Low
- kind: stale
- where: docs/issues.md:707-727; docs/STATUS.md:87
- evidence: issues "**Status 2026-10-08: accepted.**" ... "Reportable: sent 2026-10-08"; STATUS:87 "**released in BlueZ 5.88** (2026-11-05; accepted 2026-10-08 as `ae23df052290`, `6f5eeb402d3b`)". BT-7 and BT-12 sections were updated to say 5.88; M-3 was not.
- confidence: confirmed

### Path elisions "…" in identifiers (rule: identifiers in full)
- severity: Low
- kind: rule-vs-practice
- where: docs/issues.md:905 (`contributions/CO-02-…/log.md`), :922 and :944 (`contributions/CO-35-…/experiments/results-*.md`), :969 and :983 (`New Index … hci0`, quoted log, harmless); docs/STATUS.md:71, :78-83 (`CO-02-…/log.md`, `CO-43-…/send-20261113/A/`, `CO-44-…/send-20261113/`)
- evidence: e.g. issues.md:905 "(`contributions/CO-02-…/log.md`, 2026-10-27)"; STATUS:78 "(`CO-43-…/send-20261113/A/`)".
- confidence: confirmed

### Checked, no disagreement
- BT-2 (34 boots, 8 / 2, 228/2480 runs), BT-3 (74 links = 58+16; stable "released"), BT-5 (EX-043 910 frames / 9.65 s), BT-6 (15 lines 08-12..08-19; 12 instants), BT-7 (0002 fired 4× in 19 days; 5 premise instances; BlueZ 5.88), BT-8 (86ef0f58bdec; 7.2.11, 6.18.57, 6.12.113, 6.6.160, 6.1.191; v7.3 2026-10-18), M-4/M-5 numbers (10 boots, 120 sends, 86 objects, 22/23 sockets; 35 boots 2/2/0/0), BT-10 (hangs, 111/111, 7.3.y only, nothing sent), BT-11 (-42 resolves; 141/141), BT-12 (3e5b0da969c2, 5.88), BT-13, BT-14 (78/111, 14907537), BT-15, BT-16 (boots 7323fc85, 5e459fa0, 680c448c; three occurrences), EX cross-refs (EX-016 4331.99 s, EX-021 30 m 36 s / 12.8 s, EX-009, EX-008 31.4 s, EX-062 8 h 18 min) agree with STATUS rows and exhibits. None of the BRIEF §5 retractions is re-asserted in lines 145-1000 (EX-033/036 "silence" hits are BT-5's own "idle link" wording; c128a59a absent). BT-4 "67 aborts" vs EX-010 "74 in a single boot": EX-011 says "67-74 aborts per boot", so consistent.
- BT-16 minor: STATUS:74 status cell leads "observed twice ... 2 of 12 E3 boots" then adds the third; title already says three (cosmetic).

---

# Part: patches

## (heading omitted: it quotes the working arrangement)

Cross-checks that AGREE (no finding): subjects 49/46 chars and no Signed-off-by in every BlueZ patch; kernel patch
ff7646085b90 has Fixes:, Cc: stable, Signed-off-by; v1/v2 Message-IDs, patchwork ids (14831546/47, 1169362/63, 14836499/500,
1170690/91, 14919266-69, 14873330/31, 14878736-82, 14897668/69) agree between patches/bluez/README.md, BRIEF s6, STATUS and
docs/sent-mails.tsv; all 26 sha256 in sent-mails.tsv match the files; Message-ID time stamps match the stated +0200/+0100
send times; weekdays in Date: headers are right; 38 days (08-14 -> 09-21) is right; "git am 6/6" matches the script's six PASS lines;
bt9-stable README run counts (7/7, 8/8, 4/4, 3/3, 5/5, 10/14, 11/14) match results/summary-*.txt; no Received:/X-Google-Smtp-Source/IP
headers anywhere under patches/ (and none in any tracked *.eml).

### "Within 90 min" bot answer is not supported by the stated UTC times
- severity: Medium
- kind: contradiction
- where: BRIEF.md:375; patches/bluez/README.md:145 and :20 ("v1 mail" row); reviews/2026-09-20T0300Z-bluez-ci-bot-results.md:3-4; reviews/README.md:71
- evidence: BRIEF.md:375 "The list's CI bot answered both v1 mails within 90 min (09-19 22:05/22:10 UTC; register §CB)"; patches/bluez/README.md:145 "### The list's CI bot, 2026-09-19 22:05 / 22:10 UTC"; reviews file "answered both mails within ninety minutes of receipt (0001 at 2026-09-19 22:05 UTC, 0002 at 22:10 UTC)". v1 was mailed 18:44 UTC (README.md:55 table "09-19 18:44 | v1 of both mailed"; Message-ID 20260919184425 / 184435; patchwork list time "2026-09-19T18:44"). 18:44 -> 22:05 is 3 h 21 min.
- why it matters: either the "UTC" label is wrong (the bot mails were read from the operator's mailbox, which is CEST: 22:05/22:10 CEST = 20:05/20:10 UTC = 81/86 min, which fits "90 min"; the v2 bot times in the same README are correctly converted: "00:42 / 01:20 CEST" = 22:42/23:20 UTC) or the 90-minute claim is wrong. The sources support the CEST reading, so "22:05/22:10 UTC" is the likely defect in 4 places.
- confidence: confirmed (the inconsistency); likely (cause = CEST mislabelled UTC)

### patches/kernel/README.md still says the fix has not reached mainline/stable
- severity: Medium
- kind: stale
- where: patches/kernel/README.md:3 ("State at a glance - 2026-10-01"), :7; contrast README.md:39, docs/STATUS.md (MGMT row)
- evidence: kernel README:7 "Reaches mainline with the next bluetooth-next pull; the `Fixes:` tag then carries it to stable on its own". The file contains no mention of v7.3, 7.2.11, 6.18.57, 6.12.113, 6.6.160 or 6.1.191 (grep). Reference facts / README.md:39: "in v7.3, released 2026-10-18, first in v7.3-rc7; stable 7.2.11, 6.18.57, 6.12.113, 6.6.160 and 6.1.191".
- why it matters: the directory's own README is the "state" page for the patch and stops at 10-01 while the map in README.md points readers to it as "the MGMT fix as sent"; the heading date is honest but nothing says it is superseded by STATUS.
- confidence: confirmed

### patches/kernel/README.md carries live-looking "How to send" and open review items for a patch that was sent 09-24
- severity: Low
- kind: stale
- where: patches/kernel/README.md:259-283 ("## How to send - on the operator's word only"), :219-222 (ER4-5..ER4-8 "open"), :89 ("re-run before any send")
- evidence: ":259 ## How to send - on the operator's word only" with steps "1. Freshness, minutes before ... 3. Dry run, then send"; ER4-5/6/7 marked "open"; top table says "sent 2026-09-24 19:11:58". repro-mgmt-flush-status.py:633 still says "the low 8 bits of match->sk" (ER4-5 still open in code, consistent).
- why it matters: the procedure section reads as pending. Low because the top table is dated and clearly says sent.
- confidence: confirmed

### CI-bot date for the kernel patch: 2026-09-25 vs mail of 2026-09-24 21:33 local
- severity: Low
- kind: contradiction
- where: patches/kernel/README.md:14
- evidence: "**CI bot** | OK 2026-09-25 (mail 2026-09-24 21:33 local)". The patch went out 2026-09-24 19:11:58 +0200 (Message-ID 20260924171158); 21:33 local on 09-24 is not 09-25 in any zone east of UTC-3.
- why it matters: one of the two dates is wrong; no other file in the repo states the bot time (grep 21:33).
- confidence: needs-check (maybe the 09-25 is the patchwork/PR date)

### patches/bluez/README.md "What is kept" table calls v2/ "on the list, unhandled"
- severity: Low
- kind: stale
- where: patches/bluez/README.md:~121 (table row `v2/0001-*.patch`, `v2/0002-*.patch`)
- evidence: "`v2/0001-*.patch`, `v2/0002-*.patch` | **v2**, derived by `scripts/build-v2.sh`; on the list, unhandled"; the next paragraph and :104-110 say the a2dp v2 was applied 2026-10-07 as d84171e6c.
- why it matters: same file contradicts itself for `0002` v2 (the paragraph below does explain it).
- confidence: confirmed

### Documented BT_PATCH_DIR invocations break (checkpatch-check.sh: false "0 errors"; git-am-check.sh: FAIL) with a relative path
- severity: Medium
- kind: code-defect
- where: patches/bluez/checkpatch-check.sh:26-31 (`HERE="${BT_PATCH_DIR:-$HERE}"` then `cd "$TREE"` then `for p in "$HERE"/0*.patch`; `out=$(perl "$CP" "$p" 2>&1)`; errors counted only by `grep -c '^ERROR:'`); patches/bluez/git-am-check.sh:30,60 (`git -C "$W/wt" am -q "$@"` with patch paths built from the same HERE); patches/bluez/README.md:~196-200 (documented commands `BT_PATCH_DIR=patches/bluez/v2 patches/bluez/checkpatch-check.sh <tree>` and `BT_PATCH_DIR=patches/bluez/v2 patches/bluez/git-am-check.sh <tree> c73fa2f9a`, results "0 errors, 0 warnings", "6/6")
- evidence: default HERE is made absolute (`cd ... && pwd`) but BT_PATCH_DIR is taken verbatim; the README examples pass it relative. checkpatch-check.sh then cd's into the BlueZ tree, so the glob does not match and the literal pattern is passed to checkpatch; any checkpatch failure text contains no "ERROR:" line, so the summary prints "0 error(s), 0 warning(s), 0 check(s)" and exits 0. git -C <worktree> am resolves a relative patch path against the worktree, so git-am-check.sh reports FAIL. (Read from the code; scripts not run per rules.)
- why it matters: the verification quoted for v2 in README can only be reproduced with an absolute path, and checkpatch-check.sh can report a pass when checkpatch never ran (no check of perl's exit status or of "total:" line either).
- confidence: confirmed by reading (not executed)

### checkpatch-check.sh picks the lexically last linux-headers checkpatch, not the newest
- severity: Low
- kind: code-defect
- where: patches/bluez/checkpatch-check.sh:17-20
- evidence: `for c in /usr/src/linux-headers-*/scripts/checkpatch.pl; do [[ -f "$c" ]] && CP="$c"; done` - glob order is lexical, so 7.0.0-9 beats 7.0.0-31; results then depend on which headers are installed.
- why it matters: reproducibility of "0 errors" claims; minor.
- confidence: confirmed

### git-am-check.sh header says "Read-only on the checkout"
- severity: Low
- kind: doc-vs-code
- where: patches/bluez/git-am-check.sh:14 vs :44-55,60
- evidence: header "Everything happens in a throwaway worktree under mktemp; the checkout itself is not modified." but the script runs `git -C "$TREE" worktree add/remove`, which writes .git/worktrees/* in the checkout (and leaves a stale entry if killed before the trap).
- confidence: confirmed

### README.md repository map vs what patches/ really holds
- severity: Low
- kind: doc-vs-code
- where: README.md:256-263
- evidence: (a) "patches/bluez/ the two applied BlueZ patches, their verification script and mail notes" - the directory also holds two scripts (checkpatch-check.sh, git-am-check.sh), `sent/` (v1/v2 as mailed), `v2/`, `btdev-vla/` (2026-10-10 draft of A2, README says superseded), `send-2026-10-13/` (superseded set with TEST-REPORT.md); the map lists only shared-mgmt/, send-2026-10-18/, cleanup/. (b) "patches/diag/ diagnostic btusb builds (E1, E3)" - only btusb-e1-qca-rome-setup-no-reset.patch exists; the E3 patch is the unchanged upstream commit kept in `tmp/runtime-e3/` "not committed" (diag/README.md "E3 - the exact upstream entry"). (c) "patches/kernel/ the MGMT fix ... as sent, and bt9-stable/" - also REVIEW-TASK.md and the two repro-mgmt-flush-status*.py. (d) "patches/mesh-tester/" has no README of its own (reviews/review-entry-level-ingestion-second-maintainer-20261019-223627.md:303 already notes this); it also holds a v0 single patch (0001-Bluetooth-MGMT-stop-advertising..., 10-01), series/ (v1), val2-mesh-tester-cases.diff, msg-*.txt.
- confidence: confirmed

### Broken path to a patches/mesh-tester directory (HISTORY.md, review-response-4)
- severity: Low
- kind: broken-reference
- where: HISTORY.md:4802; docs/mesh-tester-ci/review-response-4-bluez-shared-mgmt-2026-10-08.md:8
- evidence: both cite `patches/mesh-tester/bluez-shared-mgmt-notify-leak-on-d84171e6c-2026-10-08/`; the directory is `patches/mesh-tester/bluez-shared-mgmt-notify-leak-on-d84171e6c/` (git ls-files; the same review-response-4 line 10 and review-response-2 use the name without the date suffix).
- confidence: confirmed

### diag/README.md E1 result and E3-for-7.0.0-42 state are stale against the reference facts
- severity: Medium
- kind: stale
- where: patches/diag/README.md ("E1 result (2026-09-26 -> 29)"; heading "E3 for 7.0.0-42 (... booted 2026-10-30 04:31 and running since)"; "Next: E3")
- evidence: "37 SCO links over two boots, 37 hang-ups answered, 0 timeouts ... all one headset (MOMENTUM 4)" vs README.md/EX-058 and stable-request-dc16388d45ec.md "58 links over three boots ... two headset models (MOMENTUM, Lenovo)" (EX-058 title "e1-setup-only-58-links-three-boots"); no E3 result (EX-057: 16 links, 2 headsets, 0 timeouts) appears in diag/README.md; "-42 ... running since" vs reference "-43 with STOCK btusb and bluetooth.ko since 2026-11-12 22:55; E3 retired; CO-09 done". Install instructions are written for `module-updates.sh install` with no note that E3 is now retired.
- why it matters: a reader of the diag README gets 37 instead of 58 for E1 and believes E3 is still live on the machine.
- confidence: confirmed

### stable-request-dc16388d45ec.md "next" row does not say it was released
- severity: Low
- kind: stale
- where: patches/diag/stable-request-dc16388d45ec.md:12 (row "next")
- evidence: "each line's next stable release (the patch moves from `queue-<v>/` to `releases/<v>.<n>/`), then the Ubuntu kernel that carries it; nothing owed" vs README.md:62 "released in 7.2.10 and 6.18.56 (2026-10-11), 6.12.113 (10-15), 6.6.160 (10-21) and 6.1.191, 5.15.224 and 5.10.273 (10-30)". Title still "draft v4c - SENT 2026-10-02".
- confidence: confirmed

### bt9-stable/README.md: "Before sending (operator's word)" and full-mgmt totals
- severity: Low
- kind: stale / doc-vs-data
- where: patches/kernel/bt9-stable/README.md (last section "Before sending (operator's word)"; paragraph "Full mgmt-tester, compared by test name"); results/compare-full-recheck.txt:3
- evidence: (a) the last section still instructs "Re-check on the day ... The backport request goes to the stable list as three separate mails" although the top of the same file says all were sent 10-10 and released. (b) README: "the totals vary between 497 and 498 of 506 without the series" but compare-full-recheck.txt line 3: "run-fixed-mgmtfull-master.log: Total: 506, Passed: 496 (98.0%), Failed: 10" - the 6-run range is 496-498. (c) results/ci-bot-2026-10-10.md is not listed in the README "results/" row.
- confidence: confirmed

### sent-mails.tsv hashes of the three stable backport mails are of the address-elided copies
- severity: Low
- kind: register-integrity
- where: docs/sent-mails.tsv rows 2026-10-10 "BT-9 stable 6.12.y/6.6.y/6.1.y" (sha256 3f2951e2..., 8fa0c80f..., feea708b...); patches/kernel/bt9-stable/send/*/0001-*.patch (`From: Jiajia Liu <<address elided>>`, `Signed-off-by: Jiajia Liu <<address elided>>`); bt9-stable/README.md (end: "other people's e-mail addresses are replaced by `<address elided>`")
- evidence: the column "sha256" is verified for every row (all match the file), but for these rows the file is explicitly NOT the bytes that were mailed (real addresses elided; bt9 README says "Identical to the sendable files apart from the elided addresses"). Same for the Tested-by reply (patches/mesh-tester/hui-peng-tested-by-reply.txt is a body without headers).
- why it matters: the register implies the hash identifies what was sent; for these rows it cannot be reproduced from a sent mail.
- confidence: confirmed

### STATUS.md BT-9 row contradicts itself on the 6.1 release
- severity: Medium
- kind: contradiction
- where: docs/STATUS.md:67 (issue row BT-9)
- evidence: "**not yet released for 6.1** (in 6.1.191-rc1, 2026-10-17, still open on 2026-10-28 ...)" and, in the last cell of the same row, "released in 6.6.160 (2026-10-21) and 6.1.191 (2026-10-30) ... done (corrected 2026-11-12 ...)". Reference: 6.1.191 released 2026-10-30.
- why it matters: a reader of the middle cell is told 6.1 is unreleased. (Outside my directory; found while cross-checking STATUS rows.)
- confidence: confirmed

### btdev-vla/README.md header contradicts its own "Superseded" lines
- severity: Low
- kind: stale
- where: patches/bluez/btdev-vla/README.md:3 vs :4-6
- evidence: ":3 **State 2026-10-10: a file for the operator's review. Nothing has been mailed.**" next lines "**Superseded:** ... redone as `newa()` and sent on 2026-10-18 as A2 (... patchwork 14897669)". send-2026-10-13/README.md title "NOT SENT in this form (superseded)" is consistent; this one is not.
- confidence: confirmed

### send-2026-10-18/TEST-REPORT.md and 10-13 TEST-REPORT.md point at local-only paths
- severity: Low
- kind: other
- where: patches/bluez/send-2026-10-18/TEST-REPORT.md:12 ("`/root/exp/qca9377-bt-hang/tmp/bluez-a1a2-20261018/`"), patches/kernel/bt9-stable/results/compare-full-recheck.txt:1, lint-*.log, w1-positive-control.log; also references `patches/a1`, `patches/a2` (send-2026-10-13/TEST-REPORT.md:85,154-157) which do not exist in the repo
- evidence: hard-coded absolute paths of the build machine; the kept summaries do say "kept on the machine that ran them", so not misleading, only not reproducible.
- confidence: confirmed

### Privacy: no raw relay headers found
- severity: (none)
- kind: privacy
- where: patches/ (all), all tracked *.eml
- evidence: `grep -rIl -E '^(Received|X-Google-Smtp-Source|X-Received|Return-Path|Authentication-Results|DKIM-Signature|X-Mailer|User-Agent)'` -> no hits; no IP addresses; only addresses present are the author's own, stable@/linux-bluetooth@/linux-kernel@ lists; third-party addresses are elided as `<address elided>`; BT addresses are AA:BB:CC:00:00:01 pseudonyms.
- confidence: confirmed

NOT COVERED: contents of the large logs/results (only the numbers quoted in READMEs were cross-checked), the mesh-tester series v1-v3 patch bodies/msg-*.txt (headers, trailers and SOB rule checked, not the technical content), TEST-REPORT tables, and external lore/patchwork/kernel.org facts (no web access).

---

# Part: co-02

## co-02 findings (CO-02 dossier review)

### Second v2 package (send-v2-review-fixes-20261114) exists and is referenced nowhere; the "v2" every register describes is the superseded one
- severity: High
- kind: stale / register-integrity
- where: contributions/CO-02-sco-connect-reuses-closing-link/send-v2-review-fixes-20261114/README.md:1-3, :34-37, OPERATOR-NOTES.txt:77; contributions/CO-02-.../send-v2-20261114/NOTES-FOR-OPERATOR.md:3; contributions/rd-2026-11-14.md:86-87; BRIEF.md:187, 226; contributions/README.md:47; docs/STATUS.md:39
- evidence: review-fixes README: "# CO-02 v2 after the 2026-11-14 outside review ... Two layouts for the operator ... (a) a-two-plus-one ... (b) b-three ... The stable line is '6.18.y and 7.3.y'". Commits: 62d7eec 08:48 (send-v2-20261114), f84f686 16:30 (review-fixes). `grep -rn send-v2-review-fixes --include=*.md .` finds no reference outside the directory itself. rd-2026-11-14:86 "CO-02 v2 (three kernel patches, two BlueZ tests) in CO-02-…/send-v2-20261114/"; BRIEF:187 same; contributions/README.md:47 "2026-11-14: v2 built, nothing sent (send-v2-20261114/)". diff of the two packages: kernel cover, patch 2, patch 3 and BlueZ cover differ (18/17/36/2 changed lines): send-v2-20261114 cover says "trees with e6720779ae61 (6.18.y and 7.2.y)", review-fixes b-three says "which is in v6.13 and later (of the stable trees, 6.18.y and 7.3.y)"; review-fixes also offers a two-patch layout (a) "[PATCH v2 0/2]" + separate "[PATCH]" patch 3.
- why it matters: the operator is told the v2 to send is send-v2-20261114 (NOTES-FOR-OPERATOR.md "Nothing here is sent. The mails are in kernel/ (cover plus 3 patches)"), but the later directory holds corrected mails (stable line 7.2 is EOL per its notes, "no causal evidence found" wording, remote-set-up-link sentence) and a layout choice. send-v2-20261114 is not marked superseded, and "v2" is described in four places without the second package.
- confidence: confirmed

### Dossier README, log.md and STATUS row do not record the 11-14 v2 package
- severity: Medium
- kind: stale
- where: contributions/CO-02-.../README.md:3-12 ("Current state, 2026-11-12"); log.md (last heading line 924 "## 2026-11-02 — the mismatch check written as its own patch"); docs/STATUS.md:39
- evidence: README.md:3-12 "the next posting is **v2** ..., folding patches 2 and 3, with the air-mode mismatch check tested on 11-02 ... The BlueZ test needs a port". log.md has no entry after 2026-11-02 (958 lines; nothing for 11-12, 11-13, 11-14, no mention of send-v2-20261114 or send-v2-review-fixes-20261114: `grep -n "send-v2" log.md` none). STATUS.md:39 ends at the 2026-11-13 note "so v2 is also the resend"; the 11-14 build is only in contributions/README.md:47 and rd-2026-11-14.md.
- why it matters: the dossier README (the file a reader opens first) says the port is still owed and the mismatch check is a separate 11-02 patch; in fact the port is done, the mismatch patch was reworked (-EBUSY split) and is patch 3 of v2. The dossier README also carries the 11-12 reading "closed by its bot ... not a review" that STATUS 11-13 corrects ("so v2 is also the resend"); README.md:154-156 (root) repeats the uncorrected reading.
- confidence: confirmed

### Root README.md describes CO-02 with the 11-12 reading and no v2 content
- severity: Low
- kind: stale
- where: README.md:150-157; BRIEF.md:97
- evidence: README.md:152-155 "the next posting will be a v2 (no maintainer reply as of 2026-11-12 ... the CI's own mirror pull requests were closed by its bot on 2026-11-11/12, which is not a review". BRIEF.md:97 (dated 2026-11-02 within the line) "the next posting is **v2** (the fold of 2 and 3, the BlueZ test port, possibly the mismatch patch)". Actual v2 (send-v2-20261114/kernel, bluez): kernel cover + 3 patches (hold, fold of old 2+3, new parameter guard), BlueZ cover + 2 patches (port of v1's 3 cases; 2 new cases for patch 3). BRIEF.md:187/226 and rd-2026-11-14 give the correct "three kernel patches + two BlueZ tests". So BRIEF:97 "possibly the mismatch patch" is superseded by BRIEF:187 but both stay in the file; README.md lines 72-77 (state of submission) and 150-157 do not mention that v2 is built and ready.
- why it matters: minor; readers of the root README get the 11-12 picture.
- confidence: confirmed

### Raw logs named by the v2 package are absent; SHA256SUMS list 240 missing files and two files whose hash no longer matches
- severity: Medium
- kind: broken-reference / register-integrity
- where: send-v2-20261114/SHA256SUMS (114 lines), send-v2-20261114/logs/SHA256SUMS (210 lines), NOTES-FOR-OPERATOR.md:"Logs of the two stalls: `logs/run-l2cap-p123-1.log`, `logs/run-l2cap-p123-3.log`", CHECKS.md:3-5
- evidence: `sha256sum -c SHA256SUMS` in send-v2-20261114: 30 "No such file" (bot/*/harness.log, TestFunctional.log ...), plus "./CHECKS.md: FAILED" and "./NOTES-FOR-OPERATOR.md: FAILED" (hash differs: edited after the sums were made). `cd logs; sha256sum -c SHA256SUMS`: 210 "No such file" (e.g. run-final-base-1.log); logs/ holds only SHA256SUMS and SHA256SUMS-binaries. [wording of the P-01 class omitted]
- why it matters: the stall logs the NOTES point the operator to do not exist in the repo; every number in CHECKS.md (35 cases, 96 of 96, 2 of 27) can only be checked against summaries.
- confidence: confirmed

### NOTES-FOR-OPERATOR.md names an internal "task brief" and says D1/D2 labels differ; BRIEF's "D1/D2" gloss does not match followups.md
- severity: Low
- kind: contradiction
- where: send-v2-20261114/NOTES-FOR-OPERATOR.md ("Label mix-up in the task brief"); BRIEF.md:226; contributions/rd-2026-11-14.md:16; contributions/review-2026-11-02/followups.md:27-28
- evidence: followups.md:27 "| D1 | **CO-02: when to post the next version, and its label.**" ... :28 "| D2 | **CO-02 mismatch patch: error code, and whether to send it yet.** ... -EBUSY for a link still in use; -ECONNABORTED only for a closing link". BRIEF.md:226 "D1/D2 (CO-02 v2: -EBUSY on a live link, -ECONNABORTED only when nothing holds it)" (D1 is timing/label; only D2 is the error code). NOTES says "the brief calls D1 '-EBUSY on a live link' and D2 'in-flight test'. In followups.md D1 is 'when to post v2 and its label (v2)'". Implementation check: v2 patch 3 returns `atomic_read(&sco->refcnt) ? -EBUSY : -ECONNABORTED` (refcnt==0 split, as R6 in D2 proposed) and patch 2 returns -ECONNABORTED for abort_reason; so D2 is reflected in the code. D1's "label v2" is reflected (all subjects "[PATCH v2 ...]"). The in-flight case (F-80) is covered by BlueZ patch 2 ("Connect Twice Other Voice Setting/Retry").
- [wording of the P-01 class omitted] Decisions in NOTES (3 vs 2 kernel patches, stable tags, Signed-off-by) are consistent with D2 ("then the guard goes out with v2").
- confidence: confirmed

### Identifier elision ("…") in CO-02 files and the register rows about it
- severity: Low
- kind: rule-vs-practice
- where: contributions/CO-02-.../log.md:109, :452, :761; send-v2-20261114/CHECKS.md:25, :64, :108; docs/STATUS.md:95 (also :224); README.md:157; contributions/rd-2026-11-14.md:86-90; docs/issues.md:905
- evidence: log.md:452 "cold boot `257d1599…` at 2026-10-23 11:04:40"; log.md:761 "SHA-256 `148564f5…c94f3d`"; log.md:109 "`20f80382…`, `106cab62…`"; CHECKS.md:25 "`git fetch --shallow-since=2026-10-27 …/bluetooth.git master`"; STATUS.md:95 "boot `257d1599…`"; README.md:157 "`contributions/CO-02-…/README.md`" (path elided, also in rd-2026-11-14.md:86-90 `CO-02-…/send-v2-20261114/`, issues.md:905 `contributions/CO-02-…/log.md`).
- why it matters: project rule says boot ids/paths/branch names are written in full; the full boot id and the module sha are given elsewhere (evidence/exhibits/071...md uses `702186d9d17dc6cc…` also truncated).
- confidence: confirmed

### Dossier README links `reviews/2026-11-12T1508Z-...` relative to the dossier, where it does not exist
- severity: Low
- kind: broken-reference
- where: contributions/CO-02-.../README.md:10 ("(`reviews/2026-11-12T1508Z-upstream-contributions-status.md`)")
- evidence: file exists only as /home/user/qca9377-bt-hang/reviews/2026-11-12T1508Z-upstream-contributions-status.md; the dossier's own reviews/ holds only 2026-10-22 files.
- why it matters: the dossier has its own reviews/ directory, so the repo-root-relative path reads as a missing file.
- confidence: confirmed

### Exhibit range EX-067..EX-074 for the laptop run vs log.md "EX-067 to EX-073"; run windows differ per document
- severity: Low
- kind: contradiction
- where: README.md(dossier):31 "(`EX-067` to `EX-074`)"; log.md:451 "exhibits `EX-067` to `EX-073`" (but line 456 cites EX-074); docs/STATUS.md:95 "`EX-067`–`EX-073` ... (`EX-074`)"; root README.md:156-157 "ran from 2026-10-23 to 10-29"; dossier README.md:30 and v7 cover "from 23 to 25 October"; STATUS.md:225 "E3 #3 ... 2026-10-23 11:04 to 10-29 15:20"
- evidence: quotes above. Not wrong (module loaded to 10-29; analysed window 10-23..25; 36 links) but the same event is given three windows and two exhibit ranges; EX-072 itself says "27 or more SCO links ... about 1.5 days" vs EX-073/EX-074 36 links.
- why it matters: cosmetic; the cover text ("from 23 to 25 October", "36 SCO links") is consistent with EX-074.
- confidence: confirmed

## Checked and consistent (no finding)
- Send record: log.md:697-716, STATUS.md:39, docs/sent-mails.tsv:22-26 agree: 17:50:06-09 +0100, cover <20261027165009.2401154-1-...>, BlueZ <20261027165059.2402360-1-...>, patchwork 14919266-14919269; sha256 of the five v7-candidate files match sent-mails.tsv. Lore link in README.md:155 and v2 cover changelog agree.
- v7 patch tags: P1 Fixes 8a5b0135d4a5 + Cc stable # 6.6.x; P2 and P3 Fixes e6720779ae61 + Cc stable; all with Signed-off-by (kernel rule). v2 files: subjects "[PATCH v2 n/3]", "[PATCH BlueZ v2 n/2]", changelog "Changes in v2 (v1: lore link)", per-patch "Notes: v2: ...", no Signed-off-by anywhere (matches rule); v2 patch 2 Fixes e6720779ae61 + Cc stable, patch 3 Fixes 10c62ddc6f03 no Cc stable (as NOTES says).
- Numbers: sco-tester 31/33/35 of 35 (30 old + 5 new, 4 fail), l2cap 2 of 27 stalls / 96 of 96, 12+15=27, consistent across v2 cover, BlueZ cover, NOTES, CHECKS, rd-2026-11-14, contributions/README. Stable lines 6.6.y/6.12.y/6.18.y/7.2.y (6.1 has no reuse path) are the same everywhere (except the later review-fixes package: 7.3.y). srcversion 0D084A056A9EEFB98E8F331 consistent in STATUS:224, EX-071, log, results. Three headsets: 3 earbuds refusals + 8 other switches consistent.
- Files named by dossier README all exist (patch/v1..v7-candidate, experiments/results-*, drafts), except the relative reviews/ link above. Superseded directories listed in README "Superseded and kept as history" (v1-v5, kernel*, rfc-defer); v6 and v7-candidate described; v8-prep-20261101 and mismatch-20261102 and send-v2-* are not listed in that superseded list.

---

# Part: co-a

## co-a findings (CO-01,03,04,05,06,07,08,09,10,11,12,14)

### CO-04/CO-05: review-fixes-20261114 supersedes the send package, but no index, README or rd points to it
- severity: Medium
- kind: stale
- where: contributions/CO-04-mesh-test-14888791/review-fixes-20261114/README.md:3-4; contributions/CO-04-mesh-test-14888791/send-20261114/README.md:4; contributions/CO-05-mesh-adv-list-lock-i12/review-fixes-20261114/README.md; contributions/CO-05-mesh-adv-list-lock-i12/send-20261114/README.md:4; contributions/README.md:49,50 (CO-04/CO-05 rows); contributions/rd-2026-11-14.md CO-04/CO-05 rows
- evidence: review-fixes README: "`patch/` (mail form) and `patch-bare/` replace `../send-20261114/patch/` for the send. Their code is unchanged: only the message, one comment and the notes below `---` differ." The send README still says "The send file is `patch/0001-…`" and the index rows name `send-20261114/` as the refreshed package. CO-05: review-fixes has `variant-A-with-fixes/`/`variant-B-without-fixes/` ("The operator chooses") while send-20261114/patch/0002 still carries the Fixes: line. `grep -rn review-fixes-20261114 --include=*.md` outside reviews/ finds only a CO-35 file.
- why it matters: an operator following the index sends the older mail text (message and comment the review changed); the open choice A/B for CO-26's Fixes tag is invisible from the front page.
- confidence: confirmed

### CO-04/CO-05 (and CO-12): send packages have no NOTES-FOR-OPERATOR.md
- severity: Low
- kind: other
- where: contributions/CO-04-mesh-test-14888791/send-20261114/, contributions/CO-05-mesh-adv-list-lock-i12/send-20261114/, contributions/CO-12-m2-adv-duration-overflow/send-20261114/
- evidence: `find contributions -name NOTES-FOR-OPERATOR.md` lists CO-02, 20, 21, 23, 35, 37, 39, 41, 43, 44 but none for CO-04, CO-05, CO-12 although all three are "package ready/refreshed" (README.md:49,50,56).
- why it matters: briefing expects each ready package to carry the operator's notes (decisions: Cc stable, Fixes variants, recipients).
- confidence: confirmed (only the file name checked)

### CO-04/CO-05 dossier README front pages still show the 10-29 state
- severity: Low
- kind: stale
- where: contributions/CO-04-mesh-test-14888791/README.md:3-4 ("State (2026-10-29) ... on bluetooth-next `1081a6ef8f1e0`"); contributions/CO-05-mesh-adv-list-lock-i12/README.md:9 (same); vs contributions/README.md:49,50 ("refreshed on `da3cc02587c6`")
- evidence: neither README mentions da3cc02587c6, the 11-14 refresh, or the new M-5 lockdep finding; CO-04 log.md ends at 2026-10-29 (tail -40 shows no 11-14 entry) although README.md layout says log.md is the append-only journal.
- why it matters: the dossier front page names a base commit that is two refreshes old.
- confidence: confirmed

### send-20261114/README uses "…" in a path
- severity: Low
- kind: rule-vs-practice
- where: contributions/CO-04-mesh-test-14888791/send-20261114/README.md:4 ("`patch/0001-…`"); contributions/CO-04.../send-20261114/CHECKS.md ("`patch/0001-...patch`")
- evidence: "The send file is `patch/0001-…`, authored ..." while the real name is `0001-Bluetooth-MGMT-Fix-use-after-free-in-mesh_send_sync.patch`.
- why it matters: project rule: identifiers/paths written in full.
- confidence: confirmed

### CO-09: banner says "done", the page body still says "State: waiting" and "Until then"
- severity: Medium
- kind: contradiction
- where: contributions/CO-09-ubuntu-kernel-qca9377-entry/README.md:3-14 (banner "done"); :17 ("**State:** waiting. ... `7.0.0-43.43~24.04.1`, in noble-proposed since 11-05 ... not yet in updates or security"); :30 ("It is in the 6.6, 6.1, 5.15 and 5.10 release candidates (STATUS)"); :39-44 ("## Until then ... If it reports ABSENT, rebuild E3", "## Next Watch each new `linux-hwe-7.0` upload")
- evidence: the body is not labelled as history, unlike CO-01/06/07/08/10 banners; docs/STATUS.md:52 says the entry is released in 6.6.160, 6.1.191, 5.15.224, 5.10.273 ("in every live stable line").
- why it matters: a reader of the body (state, next step) gets the pre-11-12 picture; two statements (waiting vs done; "release candidates" vs released) disagree on one page.
- confidence: confirmed

### CO-09 banner: boot time 22:57 vs 22:55 elsewhere, and a command with "…"
- severity: Low
- kind: contradiction
- where: contributions/CO-09-ubuntu-kernel-qca9377-entry/README.md:4-5 ("`docs/issues.md` records `-43` stock boots from 2026-11-12 22:57, boot `46cc4812`"); docs/issues.md:29 ("stock btusb since 11-12 22:55 (boot `46cc4812`)"); BRIEF.md:121,180 ("since 2026-11-12 22:55"); docs/STATUS.md:193 ("`46cc4812` (11-12 22:55)")
- evidence: 22:57 is the time of a USB attribute read (docs/issues.md:1048), the boot is 22:55. README.md:7 also shows the control command as `control `… 0cf3 e300``.
- why it matters: the banner cites issues.md for a time issues.md does not give; elided command contradicts the "commands in full" rule.
- confidence: confirmed

### CO-11 front page points at the 11-02 package whose debdiff versions were taken; no pointer to ready-20261114 or the bundle
- severity: Medium
- kind: stale
- where: contributions/CO-11-small-btmon-and-flaky-test/README.md:3-9 (banner, "the filing package is `ubuntu/ready-20261102/`; one upload together with CO-03 is proposed"), :11-17 ("the debdiff `ubuntu/bluez_5.72-0ubuntu5.8_5.72-0ubuntu5.9.debdiff` ... approved ... The operator files"); contributions/README.md:56 (CO-11 row); vs contributions/CO-11.../ubuntu/ready-20261114/README.md:6-12 and contributions/ubuntu-bluez-5.72-0ubuntu5.9-bundle/README.md
- evidence: ready-20261114 README: "Ubuntu put unrelated uploads into proposed on 2026-11-10 ... under the versions CO-11a's debdiffs had proposed ... `../ready-20261102/`'s tenacious debdiff is obsolete"; "for noble the btmon fixes now travel in the one 5.72 bundle". The CO-11 README and the index row never mention it (index row line 56 ends at the 11-02 state; the bundle is mentioned only in the paragraph above the table).
- why it matters: the standalone `5.72-0ubuntu5.9` debdiff (btmon only) and the bundle's `5.72-0ubuntu5.9` (ten patches) are two different uploads with the same version; an operator following the CO-11 front page and filing it would collide with the bundle, and ready-20261102's resolute/stonking/tenacious debdiffs are no longer valid.
- confidence: confirmed

### CO-03 front page: "operator installs / laptop test" and "five commits" lag behind the staged build and the 3-patch candidate
- severity: Medium
- kind: stale
- where: contributions/CO-03-bluez-u12-backport/README.md:3-11 ("State (2026-10-31) ... waiting for the operator's test ... five commits ... `5.72-0ubuntu5.9~co03.1`"); contributions/README.md:48 ("next step: the operator's laptop test ... the operator installs"); docs/STATUS.md:252-256 ("Staged 2026-11-13 19:2x CET ... CO-03's `bluetoothd` ... replaced `/usr/local/libexec/bluetooth/bluetoothd` ... Nothing was restarted"); contributions/CO-03-bluez-u12-backport/backport/README.md:349-370 (§9 "the exact three-patch package", `~ppa1`); contributions/ubuntu-bluez-5.72-0ubuntu5.9-bundle/BUNDLE.md ("Left out on purpose: the two BT-7 crash fixes ... the final CO-03 candidate left them out")
- evidence: neither CO-03 README nor the index row says the co03.1 binary is already on the laptop (staged, not running), that it is the five-patch build with BT-7 while the final candidate and the bundle are three-patch/ten-patch without BT-7, or that CO-03 now travels in the bundle. rd-2026-11-14.md:17 does say "staged on the laptop 11-13, not restarted".
- why it matters: the index says the operator still has to install; STATUS says it is installed. After the bundle, the laptop's drop-in binary (with BT-7 fixes) and the Ubuntu package (without) differ, which the CO-03 page does not warn about.
- confidence: confirmed

### CO-03 "0/70 → 70/70" quoted without saying what is counted
- severity: Low
- kind: contradiction
- where: contributions/README.md:48 ("trigger 0/70 → 70/70"); CO-03.../README.md:11-12 ("0/70 → 70/70 on the trigger"); vs ubuntu-bluez-5.72-0ubuntu5.9-bundle/README.md:22 ("U12 trigger 70/70 lost → 0/70"); CO-03.../backport/README.md:100 ("0/70 pass | 70/70 pass")
- evidence: same experiment, opposite-looking numbers; index/README omit "pass".
- why it matters: reader may read 0/70 → 70/70 as failures increasing.
- confidence: confirmed

### Index row CO-07 says the six commits are "not built"; they were built 11-14
- severity: Low
- kind: stale
- [wording of the P-01 class omitted]
- evidence: quoted above; CO-07 README.md:9 still "State: idea. One reading is missing before a request." and its Next list (draft bug, one recorder reading) ignores build-20261114.
- why it matters: index and dossier say not built; the dossier's own build folder says built.
- confidence: confirmed

### Old "State:" lines left under "Current state" banners (CO-01, CO-06, CO-07, CO-08, CO-10)
- severity: Low
- kind: contradiction
- where: CO-01/README.md:9 ("State: idea; nothing run yet.") vs banner :3-8 (QEMU matrix ran 11-01); CO-06/README.md:9-11 ("blocked ... must be re-run on today's bluetooth-next before any reply"; ## Next "1. re-run the comparison") vs banner :3-7 ("The rerun is done (2026-11-01): 8/26 -> 21/26 and 20/26"); CO-07/README.md:9 ("State: idea") vs banner (merged with CO-32); CO-10/README.md:8-18 ("It waits for the operator's decision and an app password... The deadline is 2026-10-22") vs banner :3-4 ("done. Sent 2026-10-21 03:05 UTC")
- evidence: the banners say "the index is the current record" but the old text is not marked as history in CO-01/06/07 (CO-10 does mark "Any Next below predates that"). CO-06 is the sharpest: the brief's "comparison must be re-run" is the old state; the index (README.md:50) says the rerun was done and the refresh left is ~1 h.
- why it matters: a reader of the State line gets the opposite of the banner.
- confidence: confirmed

### CO-14, CO-04, CO-05, CO-12 state words not updated in the index and rd table
- severity: Low
- kind: stale
- [wording of the P-01 class omitted]
- evidence: the table's state column is the morning snapshot; the Results section below supersedes it, but the page header says "This page answers ... is development complete" and does not say the table is the start-of-day state. The README states list ("patch written") would be CO-14's state.
- why it matters: a reader scanning the table sees open R&D that the same page lists as done.
- confidence: confirmed

### SHA256SUMS in send/fix folders list files that are not in the repository
- severity: Low
- kind: broken-reference
- where: contributions/CO-12-m2-adv-duration-overflow/send-20261114/SHA256SUMS (59 of 38+ lines fail: `bin/mgmt-tester-advdur`, `fetched/hci_sync-tip.c`, `logs/Add-clamp-1.log` ...); CO-04-mesh-test-14888791/send-20261114/SHA256SUMS (13 fail: `logs/bot-co04-k/patched/TestRunner_mgmt-tester.log`, `lore-mesh_send_sync.xml`, `patch-next-bare/...`, `tmp-notes.patch`); CO-05-mesh-adv-list-lock-i12/send-20261114/SHA256SUMS (27 fail: `pw-14927631.diff`, `lore-luiz-reply-14927631.txt`, `patch-next-bare/...`); CO-14-mesh-at-device-removal/fix-20261114/patches/SHA256SUMS (paths `patches/...`, `in/co04.patch` do not resolve from that directory)
- evidence: `cd <dir> && sha256sum -c SHA256SUMS | grep -v ': OK$'`. The READMEs say "Left in the work area: ... the bot's large logs" (CO-04/05) but not that SHA256SUMS lists them; CO-12 README says only "the guest logs, a tester binary and the fetched pages stay there".
- why it matters: the checksum files cannot be verified as shipped; two CO-04/05 patch-next-bare files are named as intermediate yet checksummed.
- confidence: confirmed

### CO-14: one checksum mismatch, disclosed only in the README
- severity: Low
- kind: register-integrity
- where: contributions/CO-14-mesh-at-device-removal/fix-20261114/logs/SHA256SUMS (`runs/tester-mgmt-tester-m-co04-1.log: FAILED`); README.md:50-51 ("Changed on copy: ... one mgmt-tester log line (qemu naming the process that stopped it) carry the operator's address / '(the harness)'")
- evidence: `sha256sum -c` reports 1 mismatch; the README discloses the edit but does not name the file; RESULTS.md says logs are in `logs/runs/` with `logs/SHA256SUMS` without that caveat.
- why it matters: low; the edit is disclosed but the verifying checksum file was not regenerated.
- confidence: confirmed

### mgmt-tester case count: 515 (CO-14) vs 526 (CO-04/05) on the same bluetooth-next da3cc02587c6
- severity: Low
- kind: contradiction
- where: contributions/CO-14-mesh-at-device-removal/fix-20261114/RESULTS.md ("`mgmt-tester` (515 cases)", "217 of 515", README.md:44); contributions/CO-04-mesh-test-14888791/send-20261114/CHECKS.md ("TestRunner_mgmt-tester (`Total: 526, Passed: 526`)"); CO-04 patch notes ("mgmt-tester (526 cases)")
- evidence: both on the same kernel tip; CO-10's 6.6 count is 508 (different kernel). Likely a different tester binary (project prebuilt vs the bot's), not stated.
- why it matters: the "full mgmt-tester still owed" task for CO-14 will be sized/compared against the wrong count.
- confidence: needs-check

### "…" elision in identifiers and paths in authored files
- severity: Low
- kind: rule-vs-practice
- where: CO-04/send-20261114/README.md:4 (`patch/0001-…`); CO-07/build-20261114/README.md:12 (`gnome-control-center_…_1-46.7-0ubuntu0.24.04.7.debdiff`), :24 (`target not found … destroy node`, quoted log, acceptable); CO-09/README.md:7 (`control `… 0cf3 e300``); CO-14/README.md:37 (`../CO-04-…/send-20261114/circular-count.txt`); docs/STATUS.md:85 (`CO-14-…/README.md`)
- evidence: project rule "identifiers are written in full (no "…" elision of branch names/paths/boot ids)".
- why it matters: rule breach in files the operator will follow.
- confidence: confirmed

### CO-01 refs: patchwork cover id 14157860 is out of sequence with the patches
- severity: Low
- kind: other
- where: contributions/CO-01-sco-abandoned-setup-series/refs.md:4,7 ("cover 14157860, patches 14875449 to 14875454"); contributions/CO-02.../refs.md:37 repeats it
- evidence: cover and patches share patchwork's id counter, a cover sent with patches 14875449-54 would be ~14875448; 14157860 would predate 14831271 (09-19). I did not query patchwork.
- why it matters: if wrong, every `api/covers/` link in the dossier is dead.
- confidence: needs-check

---

# Part: co-b

## co-b findings

### CO-21: index and operator notes point at a send package that its own review replaced
- severity: High
- kind: contradiction
- where: contributions/README.md:66 (CO-21 row); contributions/rd-2026-11-14.md:76; contributions/CO-21-btusb-sco-alt-setting/send-20261114/NOTES-FOR-OPERATOR.md:3-10; contributions/CO-21-btusb-sco-alt-setting/review-fixes-20261114/README.md:3-4; contributions/CO-21-btusb-sco-alt-setting/README.md (no mention of send-20261114 or review-fixes-20261114 beyond lines 9-12)
- evidence: README row: "2026-11-14: send package ready, nothing sent (`CO-21-…/send-20261114/`)"; rd:76 "CO-21's send package (`CO-21-…/send-20261114/`)". review-fixes-20261114/README.md:3-4: "These patches replace `../send-20261114/` for the send (`../../../reviews/2026-11-14T1400Z-…-checks.md` §9)". Changes: air_mode set first, one-pass count under hdev->lock, cover letter asks the mixed CVSD/transparent question. `grep -rln review-fixes-20261114 --include=*.md .` finds only the two reviews/ files and CO-35's results.md; none of README.md, rd, STATUS, the CO-21 README.
- why it matters: the operator following the index sends the superseded send-20261114 (two-count version, which the dossier's own test shows picks alt 0 with a CVSD link up 3 of 3 runs) instead of review-fixes-20261114; the latter has no NOTES-FOR-OPERATOR.md, recipients.txt or cover-letter text beyond 0000-cover-letter.patch.
- confidence: confirmed

### CO-20: index says two-patch send package ready, but patch 2 is held and patch 1 alone is the package
- severity: High
- kind: contradiction
- where: contributions/README.md:65 (CO-20 row); contributions/rd-2026-11-14.md:77; contributions/CO-20-sco-unknown-handle-messages/send-20261114/NOTES-FOR-OPERATOR.md:3-5; contributions/CO-20-sco-unknown-handle-messages/patch1-standalone-20261114/README.md:3-4,13-14 and NOTES.md:3-12
- evidence: README row: "send package ready, nothing sent (`CO-20-…/send-20261114/`): two btusb patches"; standalone README: "All five outside reviewers say patch 1 can go alone and patch 2 should wait"; "**Patch 2 is held.**"; NOTES.md: "Patch 2 … is not sent and not changed." Neither README.md, rd, STATUS nor the CO-20 README names patch1-standalone-20261114 (grep above).
- why it matters: the index tells the operator to send both patches; the reviewers' conclusion (and the dossier's newer folder) says send patch 1 only. The standalone folder also has no NOTES-FOR-OPERATOR.md (it has NOTES.md, which says "the sender adds his own" S-o-b).
- confidence: confirmed

### CO-25: STATUS names the first reply draft, which the log calls wrong, and stops at v3
- severity: Medium
- kind: stale
- where: docs/STATUS.md:37 (CO-25 row, last column); contributions/CO-25-qualcomm-rom-report/log.md:331-333,348-351; contributions/README.md:70; contributions/rd-2026-11-14.md:40
- evidence: STATUS: "A clarifying answer is drafted (`drafts/reply-1-zijun-hu.eml`), not sent … **2026-11-02:** reply draft v3 … reviewed by five outside reviewers … Not sent". log.md:331-333: "The first draft is wrong where it matters (an outside reviewer, checked here)"; log.md:348-351: v4 is the current draft. README row and rd:40: "reply v4 ready" (`drafts/reply-1-zijun-hu-v4.eml`).
- why it matters: STATUS (a current-state register) points the operator at the superseded, known-wrong draft and does not mention v4, which README and rd name as the one to send.
- confidence: confirmed

### CO-25: pinned commits of the sent mail cannot be resolved in this repository
- severity: Low
- kind: broken-reference
- where: contributions/CO-25-qualcomm-rom-report/send/report.eml:105; contributions/CO-25-qualcomm-rom-report/README.md:12; docs/STATUS.md:37
- evidence: mail links `.../blob/4b56813d311d/contributions/CO-25-.../EVIDENCE.md`; README "as reviewed at `cb645f5`"; `git cat-file -t 4b56813d311d` and `git cat-file -t cb645f5` both: "Not a valid object name" (repo has 50 commits; oldest 17db9f8-era). `git hash-object EVIDENCE.md` = 667dcd3134ce…, equal to the blob log/reviews say is at 4b56813d311d, so the content matches.
- why it matters: a reader cannot check the pinned link or the "reviewed at" commit from the checkout (history was evidently compacted or the commits live in another repo); the dossier does not say so.
- confidence: needs-check (public repo may still hold them)

### CO-25: stranger-facing evidence page uses project-internal labels
- severity: Low
- kind: rule-vs-practice
- where: contributions/CO-25-qualcomm-rom-report/EVIDENCE.md:11-28 (EX-053, EX-054 … EX-058), :20 "BRIEF.md, section 2"; linked from send/report.eml:105
- evidence: table cells "[EX-053](../../evidence/exhibits/053-…md) | The instance quoted in the report …"; "tabulated in [BRIEF.md, section 2](../../BRIEF.md#…)". The mail body itself carries no BT-/EX-/CO-/U- label (grep over report.eml and reply v4: only the URL line matches).
- why it matters: the report body is clean, but the page it links to is labelled in project ids (EX-nnn) and points to the internal BRIEF; Qualcomm readers get ids with no plain naming beyond the link titles. Minor, since each row also has a plain description.
- confidence: confirmed

### CO-23: superseded 10-29 send package (with a working send.sh) not marked as superseded; 11-14 package has no send script and defers to it
- severity: Medium
- kind: stale
- where: contributions/CO-23-one-off-events/patch/send/README.md:1-8 and patch/send/send.sh:1-30; patch/send-20261114/README.md:12-13; CO-23 README.md:3-7
- evidence: patch/send/README.md:1,3: "the send package (for review before sending) … The files to send, exactly as they stand"; commits on master `82667d713949`. send.sh checks SHA256SUMS then `git send-email` ("--send" mode). Neither file mentions send-20261114 (`grep -n 'send-20261114' README.md patch/send/README.md` hits only log.md:74's 11-01 draft). send-20261114/README.md: "Recipients, route and the reviewer questions are as in `../send/README.md`". CO-23 README.md:6: "send package ready (`patch/send/README.md`)".
- why it matters: the dossier README and the executable send script lead to the 11-01/10-29 patches (test merges badly with master's new test_a2dp_reconnect_pending_disconnect), not the refreshed 11-14 mails the index (README.md:68, rd:38) calls current; send-20261114 itself has no send.sh and borrows recipients from the old README.
- confidence: confirmed

### CO-23: operator notes' list of "still wrong" BT-6/U22 records is already fixed
- severity: Low
- kind: stale
- where: contributions/CO-23-one-off-events/patch/send-20261114/NOTES-FOR-OPERATOR.md:38-61 ; docs/issues.md:610-628; docs/STATUS.md:64,110
- evidence: notes: "`docs/issues.md:~617` `**Reportable:** ❌ no — a single occurrence…`", "`docs/STATUS.md:64` … say 'none since 10-12'", "`docs/STATUS.md:110` says 'master re-checked 2026-10-29'". Now issues.md:616-618 "**Reportable:** ❌ no — a benign race … Until 2026-11-14 this said 'a single occurrence…'", STATUS:64 "until 11-14 this said 'none since 10-12'", STATUS:110 "master re-checked 2026-11-14 at `20ffd285b58f`". issues.md:610 heading still "Controller delivers ACL data…" (item 3, optional).
- why it matters: an operator reading the notes would redo edits already made; the notes carry no "done" marker.
- confidence: confirmed

### CO-30: RFC package's base path does not exist; "10-21 prototype" vs "11-01 prototype"; base may predate CO-02's review fixes
- severity: Medium
- kind: broken-reference
- where: contributions/CO-30-sco-deferred-connect-rfc/rfc-20261114/README.md:3-4,10; contributions/CO-30-sco-deferred-connect-rfc/README.md:11; contributions/CO-02-sco-connect-reuses-closing-link/send-v2-review-fixes-20261114/README.md:1-12
- evidence: rfc README:3-4 "Base: CO-02 v2 (`../co02-v2/kernel/`, branch `co02-v2-final` in `$W/linux-bn`)": no `co02-v2` directory exists under CO-30 (`ls contributions/CO-30-…/rfc-20261114` shows only CHECKS-CO30.md README.md SHA256SUMS … kernel results bot); CO-02 holds `send-v2-20261114/` and `send-v2-review-fixes-20261114/`. rfc README:10 "Code unchanged from the 10-21 prototype" vs README.md:11 "unchanged from the 11-01 prototype". CO-02 review-fixes README: "CO-02 v2 after the 2026-11-14 outside review … Two layouts … (a) two plus one … (b) three", while CHECKS-CO30.md:3-4 tested on `p123` = `6ab80e175065` (the earlier v2). Reading of tested counts in CO-30 (35/36 pass) is for that earlier v2.
- why it matters: the dossier names a base that cannot be found in the repo, and the RFC's stated base may no longer be the v2 that will be sent (needs a re-test on the review-fixes layout).
- confidence: confirmed (path, date wording); needs-check (whether review-fixes changes sco.c)

### CO-30: SHA256SUMS lists files that fail or are not shipped
- severity: Low
- kind: register-integrity
- where: contributions/CO-30-sco-deferred-connect-rfc/rfc-20261114/SHA256SUMS; logs-SHA256SUMS; binaries-SHA256SUMS
- evidence: `sha256sum -c SHA256SUMS`: "./CHECKS-CO30.md: FAILED" (hash differs), "./bot/bot-rfc/patched/harness.log: [wording of the P-01 class omitted] README.md:2 of the dossier says large logs were "left there"; the sums files do not say so.
- why it matters: a reader running the shipped checksum file gets failures; CHECKS-CO30.md was edited after the sums were taken.
- confidence: confirmed

### CO-35: the "ready" send-20261114 has no NOTES-FOR-OPERATOR.md, no recipients/operator decisions file, and keeps Signed-off-by lines
- severity: Medium
- kind: rule-vs-practice
- where: contributions/CO-35-l2cap-ecred-defer-hang-stable/send-20261114/ (no NOTES-FOR-OPERATOR.md; `ls` shows CHECKS.md README.md SHA256SUMS … mail/); BRIEF.md:186-190; send-20261114/mail/6.18.y/0001-…patch:24, 0002-…patch:24; mail/6.12.y/…:24,28; mail/6.6.y/…:24,28
- evidence: BRIEF.md:186-190 "Ready to send, each with `NOTES-FOR-OPERATOR.md` (his decisions) … CO-35 (`send-20261114/`…) … **Packages made since 11-13 carry no Signed-off-by**". `ls contributions/CO-35-…/send-20261114 | grep -i notes` returns nothing. `grep -n Signed-off-by mail/*/000[12]-*.patch`: each of the six patches ends with "Signed-off-by: Iaroslav Voitovych <yaroslav.voytovych@gmail.com>" after Pauli Virtanen's and Luiz Augusto von Dentz's. The package README (:6-8) says the two patches are "byte-identical to ../send-20261102/", the 0000 covers are new (11-14, no Signed-off-by needed).
- why it matters: stable backports do need the submitter's Signed-off-by (so keeping it is right for the kernel), but then the "no Signed-off-by since 11-13" rule statement is not true of this package and the package does not say why; and the operator has no notes file listing his decisions (7.3.y request, SCI request as a separate mail, which series order, Cc lines) as BRIEF promises for every ready package.
- confidence: confirmed

### CO-35: dossier README and BRIEF still describe the 11-02 / 10-28 package
- severity: Medium
- kind: stale
- where: contributions/CO-35-l2cap-ecred-defer-hang-stable/README.md:3-8,11-16 (and log.md ends 11-02, no 11-14 entry); BRIEF.md:109; docs/issues.md:876-879; README.md:175
- evidence: CO-35 README:5 "the final package is `send-20261102/`"; :11-14 "`send/` holds four mails … an option-2 request for 7.3.y and 7.2.y (`request-v2.eml`)". BRIEF.md:109: "CO-35 (the package in `send/`: 7.3.y + 7.2.y request and three backport series, after its outside review)"; BRIEF.md:186 (11-14 block) says "CO-35 (`send-20261114/`, stable tips of 11-14)". issues.md:876 "an option-2 request for 7.3.y and 7.2.y" then :878 "7.2.y has ended … 7.3.y only (`send-20261102/`)". The current package (send-20261114/README.md:5-9): request-v4 for 7.3.y only plus a separate SCI request `request-sci-7.3.y-20261114.eml` and three series; `send/` and `send-20261102/` still sit beside it.
- why it matters: three live pointers (send/, send-20261102/, send-20261114/) with BRIEF:109 still naming the 7.2.y request that no longer exists as a request (7.2.y has ended) and not the separate SCI request.
- confidence: confirmed

### README.md: "a stable request for an L2CAP hang that every released kernel has" overstates CO-35
- severity: Medium
- kind: contradiction
- where: README.md:175; contributions/CO-35-l2cap-ecred-defer-hang-stable/send-20261114/mail/request-v4-20261114.eml (last paragraph)
- evidence: README.md:174-175: "a stable request for an L2CAP hang that every released kernel has (`CO-35`)". request-v4: "6.1.y, 5.15.y and 5.10.y do not have ab4eedb790ca, and ECRED is off there unless the bluetooth module parameter enable_ecred is set … The two commits do not apply to those lines, so this request does not cover them." CO-35 row (contributions/README.md:80): "6.1.y/5.15.y/5.10.y hang too with ECRED enabled (not covered)"; the tested hangs are v7.3.4, v6.18.63, v6.12.117, v6.6.162 (logs/summary-*-base.txt "HANG").
- why it matters: the front page says every released kernel; the package covers four stable lines and the older three hang only with a non-default module parameter and have no fix prepared.
- confidence: confirmed

### CO-27: README says GNOME tracker "not searched yet" and U13 still points the GNOME report at CO-27, though CO-42 now holds it
- severity: Low
- kind: stale
- where: contributions/CO-27-le-only-pairing-u13/README.md:49-50 and :22-25; docs/STATUS.md:101 (U13 row); contributions/README.md:84 (CO-42 row)
- evidence: CO-27 README:49 "4. The BlueZ mailing list and GNOME's tracker are not searched yet."; STATUS U13: "next a BlueZ patch candidate (Flags presence) and a GNOME report for the silent failure (`contributions/CO-27-…/`)". CO-42 row: "issue #18 (2009) and the other author's MR !137 exist … comment drafted". `grep -c CO-42` in CO-27 README.md and log.md: 0 and 0.
- why it matters: the GNOME half of CO-27 was split off as CO-42 (reproduced, existing issue and MR found); CO-27 and STATUS still route the silent-failure report to CO-27 and say the tracker was not searched.
- confidence: confirmed

### CO-28: README keeps a "Next / watch for review mails" tail and a rc1 table under a closed state; BRIEF still says "CO-28 waits"
- severity: Low
- kind: stale
- where: contributions/CO-28-stable-6.1-5.15-5.10-reviews/README.md:1-5,51-55; BRIEF.md:102; contributions/README.md:73; rd-2026-11-14.md:42
- evidence: README.md:3 "closed, nothing sent. The review deadlines (5.15.224-rc1 and 5.10.273-rc1 on 10-30, 6.1.191-rc2 on 10-31) passed without a test run. All three were released on 2026-10-30"; the dossier tail still reads "Watch for each review mail. If one appears, run the comparison …". BRIEF.md:102 (the 10-28/29 block): "no review mail found for them (… CO-28 waits)". README row and rd: closed. Also internal: 6.1.191 was released 10-30, one day before the stated 10-31 deadline of its rc2, so "deadline passed" is not quite what happened for 6.1.
- why it matters: the closed state is consistent in README.md/rd/STATUS-level records, so this is only a stale tail and one BRIEF line that still presents CO-28 as waiting.
- confidence: confirmed

### CO-21 review-fixes cover letter contains review history and talks of a "first draft" in a first posting
- severity: Low
- kind: rule-vs-practice
- where: contributions/CO-21-btusb-sco-alt-setting/review-fixes-20261114/0000-cover-letter.patch (paragraph "Changes since the first draft"); contributions/CO-21-btusb-sco-alt-setting/send-20261114/NOTES-FOR-OPERATOR.md:56-57 ("`cover-letter.txt` is a short draft (facts only, no review history)")
- evidence: cover letter: "Changes since the first draft: the air mode is stored before the connection is marked connected; one helper takes both counts in one pass …". Nothing was ever posted, so there is no earlier version for the list.
- why it matters: the series has not been sent; a "[PATCH 0/2]" with "changes since" reads as a v2 and names a draft the recipients never saw (the send-20261114 cover was explicitly "no review history").
- confidence: confirmed

### Index-wide: "…" elision used in path/id identifiers that the rules say are written in full
- severity: Low
- kind: rule-vs-practice
- where: contributions/README.md (3 lines), contributions/rd-2026-11-14.md (10 lines), docs/STATUS.md (10 lines), docs/issues.md (3 lines): `grep -c 'CO-[0-9]*-…'`; contributions/CO-20-sco-unknown-handle-messages/README.md:55 (boot id "`257d1599…`"); contributions/CO-25-qualcomm-rom-report/log.md:138,289,346; contributions/CO-34-ioctl-tester-duplicate-name/log.md:57 ("SHA-256 `c3ac8cee…7567a`"); docs/STATUS.md:37 ("SHA-256 `1f81392a…cbf7`")
- evidence: e.g. README.md:65 "(`CO-20-…/send-20261114/`)"; CO-20 README:55 "The CO-02 boot (`257d1599…`, 2026-10-23 to 26)"; STATUS:37 "`contributions/CO-25-…/send/report.eml`". The full sha256s exist in docs/sent-mails.tsv (CO-34 c3ac8cee…ebff7567a, CO-25 1f81392a…).
- why it matters: the project rule ("no '…' elision of branch names/paths/boot ids") is broken in the operator-facing index where a path must be typed or pasted; the boot id in CO-20 is not given in full there.
- confidence: confirmed

### CO-34: send README and tsv row not brought to the sent state
- severity: Low
- kind: stale
- where: contributions/CO-34-ioctl-tester-duplicate-name/patch/send/README.md:3 ("One mail, BlueZ, not sent."), :26-30 ("The send (only on the operator's word)"); docs/sent-mails.tsv (CO-34 row: date "2026-10-28", no time, empty patchwork_id); contributions/CO-34-ioctl-tester-duplicate-name/log.md:63 ("the patchwork id goes into the inventory"); docs/STATUS.md:38
- evidence: README:3 "**One mail, BlueZ, not sent.**"; tsv row "2026-10-28	CO-34 ioctl-tester 3-DH name	…	<20261028051620.3167775-1-…>		linux-bluetooth	c3ac8cee…" versus other rows "2026-10-29 02:33:50 +0100"; STATUS:38 first cell "released in BlueZ 5.88" while its last cell still says "no BlueZ release yet" (the header notes this predates). Verified: `sha256sum` of the patch = c3ac8cee…7567a (matches tsv); `git patch-id --stable` = 78ae012404e3 (matches README/STATUS).
- why it matters: facts agree (applied `3e5b0da969c2` 10-28, BlueZ 5.88), but the package README still reads as unsent and the inventory lacks the send time.
- confidence: confirmed

### CO-35 send-20261114: SHA256SUMS fails on two scripts changed on copy and lists missing kernel images
- severity: Low
- kind: register-integrity
- where: contributions/CO-35-l2cap-ecred-defer-hang-stable/send-20261114/SHA256SUMS; send-20261114/README.md:18-21; send-20261102/SHA256SUMS
- evidence: `sha256sum -c SHA256SUMS`: "./apply-check.sh: FAILED", "./apply-old.sh: FAILED", "./img/bzImage-v6.12.117-base: FAILED open or read"; send-20261102/SHA256SUMS lists `ci-local-6.12.y/…patch` and `am-bluetooth-next.err` which do not exist. README:18-21 documents the two script edits ("check@example.com … where the run used `@example.invalid`") and that images stayed in the work area, but the sums file was not regenerated.
- why it matters: the shipped checksum file cannot be verified; the placeholder domain is only in helper scripts, not in a mail (no @example.* in any mail, patch or recipients file of the ten dossiers).
- confidence: confirmed

---

# Part: co-c

## co-c findings

### CO-43: three different versions of patch A; the "dry run OK" package carries the superseded text, the series carries it too
- severity: High
- kind: contradiction
- where: contributions/CO-43-btusb-runtime-resume-failure/send-20261113/A/0001-Bluetooth-btusb-Report-a-failed-runtime-resume-for-d.patch (sha256 5ef19422...); .../send-20261113/A/NOTES-FOR-OPERATOR.md ("## The dry run"); .../send-20261113/A-review-fixes-20261114/README.md:3; .../send-series-20261114/0001-Bluetooth-btusb-Report-a-failed-runtime-resume-for-d.patch (sha256 db069aa7...); results/co43-d2-series-bt24-bt25-2026-11-14/RESULTS.md ("0001 A (the send package's text, unchanged)"); docs/STATUS.md BT-20 row; BRIEF.md hand-off ("CO-43 E and A ... dry runs OK")
- evidence: A-review-fixes README: "This patch replaces `../A/0001-...` for the send ... It replaces 'then ends in a command timeout two seconds later', which had the order reversed." and "rate-limited with bt_dev_err_ratelimited()". `diff` of the three patches: send-20261113/A and send-series 0001 both still have "An HCI command in it then ends in a command timeout two seconds later" and plain `bt_dev_err(...)`; only A-review-fixes has `bt_dev_err_ratelimited`. Nothing in A/NOTES-FOR-OPERATOR.md, A/send-commands.txt, A/CHECKS.md, the dossier README, STATUS BT-20 ("send package ready, dry run OK ... send-20261113/A/") or BRIEF points to A-review-fixes-20261114; its own README says "the bot was not run again" and it has no NOTES/recipients/send-commands; the dry run of 11-14 was on the old A. Command: diff of the three files.
- why it matters: an operator following A/NOTES-FOR-OPERATOR.md sends the text the 11-14 review called wrong (reversed order, no rate limit), and the series' patch 1 repeats it; the registers say "ready, dry run OK" for the old file only.
- confidence: confirmed

### CO-43 send-series-20261114: no README/NOTES, and STATUS/README say D v2 closes the system path while the dossier's open item 0 says patch 3 must be held
- severity: High
- kind: contradiction
- where: contributions/CO-43-btusb-runtime-resume-failure/README.md:74-86 (item 0); send-series-20261114/0003-Bluetooth-btusb-Recover-after-a-runtime-reset-resume.patch (message: "The system resume path is meant to stay as it is"); send-series-20261114/0000-cover-letter.patch ("this was checked in the source only"); docs/STATUS.md:76 (BT-18); contributions/rd-2026-11-14.md:70-72; results/co43-d2-series-bt24-bt25-2026-11-14/README.md:11-17; reviews/2026-11-14T1300Z-bt17-open-work-reviewer-3-checks.md (section 1)
- evidence: README item 0: "D v2 (patch 3 of send-series-20261114/) breaks the system-resume rebind ... Patch 3, and patch 2 which needs it, are held". Reviewer-3 file: "In the source, it does not [stay as it is] ... With patch 3, a reset-resume during a system resume ... no rebind ... this is the 2013 behaviour that was reverted ... patch 3 must not go out as it is." Opposite sides: STATUS BT-18 "the system path unchanged by reading only"; rd "D v2 closes the system-path hole by reading"; patch 3's own message and the cover letter still say the system path stays as it is. The D v2 analysis (RPM_RESUMING discriminator) never addresses needs_binding. The directory has no README/NOTES-FOR-OPERATOR.md stating "held".
- why it matters: the series text and two registers assert something the dossier's own review shows false (Realtek and Dell reset-resume devices would lose their firmware reload); a reader of STATUS/rd would not know patches 2-3 are held.
- confidence: confirmed (the needs_binding claim itself is the review's reading of source, not run)

### CO-43: patch 2 (B2) precedes patch 3 (D v2) although it depends on it; two overlapping BT-24/BT-25 packages that differ
- severity: Medium
- kind: other
- where: send-series-20261114/0000-cover-letter.patch ("Patch 2 depends on patch 3 ... (0 of 3 runs recovered with patch 2 alone) ... Please apply them together"); send-series-20261114/0004,0005 vs send-bt24-bt25-20261114/0001,0002; send-bt24-bt25-20261114/README.md
- evidence: cover letter order 1 A, 2 B2, 3 D v2 with that dependency text: after patch 2 alone the device does not recover (bisect regression). Patch 0004 in the series has an added line `clear_bit(BTUSB_CMD_DEFERRED, &data->flags);` that send-bt24-bt25/0001 lacks; series 0005's message lacks the btusb_close() paragraph of bt24-bt25/0002 (`diff` of the pairs). Neither README/cover says which pair is for sending; the bt24-bt25 README says it is the extraction "four reviewers asked for", the series cover says 4/5 "can only be exercised once 2 is applied" while bt24-bt25's cover says patch 1 relies only on E. sha256 differ (c80bfc00... vs b3d77d13...; 3dd27572... vs 9e5bd839...).
- why it matters: send order breaks bisection; two non-identical versions of the same two fixes with no statement of which is authoritative.
- confidence: confirmed

### CO-43: dossier README, register row and rd state say "five patches ... B and D in R&D"; nothing there points to send-series-20261114 or send-bt24-bt25-20261114
- severity: Medium
- kind: stale
- where: contributions/CO-43-btusb-runtime-resume-failure/README.md:28-60 ("State (2026-11-13): five patches ... nothing sent", table A,B,D,E,C); contributions/README.md:106; docs/issues.md:1153-1182 (BT-24, BT-25)
- evidence: README.md:106 "E and A packaged ... [wording of the P-01 class omitted] "Status 2026-11-13: ... not reproduced; no fix yet" and BT-25 "Next: a kmemleak run ...; then a fix together with BT-24" while docs/STATUS.md:82-83 (BT-24 "reproduced 2026-11-14 on the B2 tree ... patch 4", BT-25 kmemleak done, patch 5) and the results README say both are done. Also kmemleak numbers for the same scenarios differ between send-bt24-bt25/README.md (E only "3, 3, 1 / 2, 1, 2 / 5, 3, 4 / 2, 2, 2" -> all 12 runs nonzero) and results/co43-d2.../README.md (E alone "2, 1, 1 / 1, 2, 0 / 4, 3, 2 / 1, 1, 3", STATUS "11 of 12"), two separate run sets nowhere reconciled (series cover: "1 to 4 per run", bt24-bt25 cover up to 5).
- why it matters: two registers disagree on whether BT-24 is reproduced/fixed; the index row hides the packages that exist.
- confidence: confirmed

### Register rd-2026-11-14.md table contradicts its own "Results so far"
- severity: Medium
- kind: stale
- where: contributions/rd-2026-11-14.md:52-55 (table rows CO-38, CO-39, CO-40, CO-41), :57 (CO-43), vs :62-135 (results)
- evidence: table: CO-39 "patch written, bot run from 11-08 unfinished"; CO-41 "idea, confirmed in source"; CO-38 "package ready 11-02"; CO-43 "B blocked by its counterexample; D not as a fix". Same file: [wording of the P-01 class omitted] CO-41 (...3/3 fail -> 3/3 pass) and CO-39 (...7/7)"; [wording of the P-01 class omitted] B2 replaces B ... D v2"; [wording of the P-01 class omitted] CO-40". Also the header says "The index (README.md) ... stay the authority".
- why it matters: the page of record (per BRIEF) gives wrong state for four items in its own table.
- confidence: confirmed

### contributions/README.md rows CO-38, CO-39, CO-37, CO-40, CO-41 stale against their own newer packages
- severity: Medium
- kind: stale
- where: contributions/README.md:82 (CO-38), :95 (CO-39), :83 (CO-37), :96 (CO-40), :97 (CO-41)
- evidence: CO-38 row: "BlueZ TestFunctional failed 2 of 3 patched (BAP cases, likely a flake, not shown)" vs CO-38/send-20261114/CHECKS.md section 5 "TestFunctional settled ... base 1 FAIL of 7 ... a flake of the BAP/BASS acquire tests, not caused by the series" and rd:80 "a flake (5 more pairs...)"; CO-39 row: "bot patched side passes; base side still to read" vs CO-39/send-20261114/README.md "The bot's base side (master), finished 11-14 ... every check PASS but CheckValgrind (unit/test-hog)"; CO-37 row: "U24 is fixed upstream by 7e3212fa233e (not released)" vs CO-37/send-20261114/README.md "U24's fix 7e3212fa233e is in master and in 5.88" and rd:140; CO-40 row: "bundle with the other 5.72 updates ... or file alone" vs the bundle existing (README.md:35-37, "built and tested, not filed"). CO-37/README.md:121 also "in no release yet; the newest tag is 5.87".
- why it matters: reader of the index gets pre-11-14 facts for items whose packages moved on; the register that BRIEF calls the authority.
- confidence: confirmed

### Dossier READMEs of CO-38, CO-39, CO-41, CO-40, CO-37 are frozen at 11-02/11-08 and do not mention their send-20261114 / bundle
- severity: Medium
- kind: stale
- where: CO-38-read-adv-features-hidden-instances/README.md:11 ("State (2026-11-02): ready to send ... The From line carries a placeholder", no mention of send-20261114/ or bluez-split-20261114/); CO-39.../README.md:20 ("State (2026-11-08): ... validation in progress ... Running: bot"); CO-41.../README.md:11 ("State (2026-11-07): idea ... no patch yet"); CO-40.../README.md:17 ("Next: bundle ... or file it alone"); CO-37.../README.md:3 (box "Current state, 2026-11-12", no link to send-20261114)
- evidence: quotes above; `grep send-20261114` in those four README files returns nothing (CO-37's has a work/ pointer only).
- why it matters: someone opening the dossier gets "no patch yet" / "placeholder From" while a send package exists; same pattern as the register rows.
- confidence: confirmed

### CO-38 send-20261114: README says "2 of 3 ... not shown" but CHECKS says settled; no NOTES-FOR-OPERATOR.md; old and split BlueZ series both present with no ruling
- severity: Medium
- kind: contradiction
- where: contributions/CO-38-read-adv-features-hidden-instances/send-20261114/README.md:14-16; .../send-20261114/CHECKS.md:~50-59 (section 5); .../bluez-split-20261114/README.md:3-8; BRIEF.md hand-off ("Ready to send, each with NOTES-FOR-OPERATOR.md ... CO-38")
- evidence: README: "TestFunctional failed 2 of 3 on the patched side ... looks like a flake ... but is **not shown** to be." CHECKS.md section 5: "So the failure appears on base, with no patch: a flake of the BAP/BASS acquire tests, not caused by the series." `ls`: no NOTES-FOR-OPERATOR.md in send-20261114 or bluez-split-20261114 (every other ready package in my part has one). bluez-split README: "Four of five reviewers asked for this: the old [PATCH BlueZ 0/3] installed duration cases that fail until CO-12", yet send-20261114/patch/bluez/ still holds that 0/3 series and the register row/README do not say the split replaces it. Also send-20261114/README.md:22 says CHECKS.md and mk-kernel-patch.sh "name the placeholder address as example.com (the run used example.invalid)" - both files carry `author@example.com` (CHECKS.md:35, mk-kernel-patch.sh:12) and their SHA256SUMS entries FAIL (files edited after hashing; the README lacks a "Changed on copy" line).
- why it matters: the operator has no decision list for CO-38 and cannot tell which BlueZ series to send.
- confidence: confirmed

### Placeholder author `<AUTHOR-EMAIL>` committed in authored mails, contradicting the dossier that says they stayed in the work area
- severity: Medium
- kind: rule-vs-practice
- where: contributions/CO-38-read-adv-features-hidden-instances/send-20261102/ (5 files: 0001-...patch, bluez/0000-cover-letter.patch, bluez/0001..0003); contributions/CO-37-bluez-media-endpoint-exit-uaf/work/patches/master-final-6-20261102/ (6 files) and work/patches/5.72-3-20261102/ (3 files); contributions/CO-37-bluez-media-endpoint-exit-uaf/send-20261114/README.md ("Left in the work area: ... the 11-02 mails with a placeholder author")
- evidence: `grep -n '^From:'` gives "From: Iaroslav Voitovych <AUTHOR-EMAIL>" in those 14 files; BRIEF.md says placeholders "become the operator's real one in authored files". CO-37 README.md:3-6 and the register row still cite master-final-6-20261102/ and 5.72-3-20261102/ as the series; CO-38 README still cites send-20261102/ as "the send".
- why it matters: a patch with a placeholder From could be sent by mistake; the "left in the work area" statement is false for CO-37.
- confidence: confirmed

### Ubuntu bundle: BUNDLE.md says the changelog trailer is a placeholder; the file and README say the operator's address
- severity: Medium
- kind: contradiction
- where: contributions/ubuntu-bluez-5.72-0ubuntu5.9-bundle/BUNDLE.md ("The changelog entry ... the changelog trailer address is a placeholder to replace before upload"; Open point 6 "uses a placeholder address"); README.md ("Changed on copy: ... the changelog trailer give the operator's own address"); changelog-entry.txt (last line); CHECKS.md:31
- evidence: changelog-entry.txt: " -- Iaroslav Voitovych <yaroslav.voytovych@gmail.com>  Sat, 14 Nov 2026 12:00:00 +0000"; debdiff line 35 the same. README Open point wording otherwise unchanged.
- why it matters: reader is told to replace something already replaced (or to doubt the file). Also the bundle's SHA256SUMS fail for 7 edited files (bin/build-series.py, changelog-entry.txt, CHECKS.md, the debdiff, 3 patches) and 1188 of 1239 listed files are absent (raw runs left in the work area); the README explains the patches/changelog edits but not build-series.py/CHECKS.md.
- confidence: confirmed (`sha256sum -c SHA256SUMS`)

### "..." elision inside identifiers and paths in authored files
- severity: Low
- kind: rule-vs-practice
- where: CO-44-.../send-20261113/NOTES-FOR-OPERATOR.md:8,11 (`kernel/0001-...patch`, `bluez/0001-...patch`); CO-44-.../send-20261113/send-commands.txt (`send-email ...`); CO-43-.../send-20261113/A-review-fixes-20261114/README.md:3 (`../A/0001-...`); results/co43-b2-and-runtime-d-2026-11-14/README.md (`patches/0002-...`), results/co43-d2-series-bt24-bt25-2026-11-14/README.md (`patches/on-E/0002-...`); CO-36-.../README.md (`/org/bluez/hci0/dev_.../fdNN`, `(..., true)`); X1-gvfs-cdda-readahead/README.md (SHA-256 `07426241...0a7`, `2710b35c...796`, `7ccf101e...cc18`, `36175938...`, `e60fcf37...`); ubuntu bundle README.md ("LP-..." placeholders); contributions/README.md:120 ("X1.../patch1/")
- evidence: `grep -c` of the ellipsis character: 2, 1, 3, 2, 4, 6 hits in those files; BRIEF rule: identifiers written in full, no elision of paths/ids.
- why it matters: a path or checksum that cannot be pasted or verified (the X1 hashes are the ones the README itself says were once wrong).
- confidence: confirmed

### CO-36: README "Next" step 4 and the register omit that fix variants V2/V3 already ran; "111 tests" not found
- severity: Low
- kind: stale
- where: contributions/CO-36-pipewire-hfp-volume-resend-after-release/README.md:182-184 ("fix variants through the same tests next (Phase 1)"); .../homework/README.md:174-199 ("V2 against V3 (2026-11-01 ...)"); contributions/README.md:81 ("test plan of 111 tests")
- evidence: homework README reports V0/V2/V3 L1 3 runs and L2 runs done on 11-01; `grep -oE '^- T[0-9]+' homework/TEST-PLAN.md | sort -u | wc -l` = 113; "111" appears nowhere in the CO-36 files.
- why it matters: the dossier claims variants are future work; the register's count has no source.
- confidence: likely (the 111 vs 113 depends on how tests are counted)

### CO-39: notes cite a cover-letter file that is not in the repository; title says a bot run is still open
- severity: Low
- kind: broken-reference
- where: CO-39-.../send-20261114/NOTES-FOR-OPERATOR.md ("the v3 cover letter file still has placeholders"); .../send-20261114/README.md:1 ("one bot run still to read") vs its own body; README.md:7 ("CHECKS.md (if present)")
- evidence: `ls CO-39*/send-20261114` shows no cover-letter file; title says a bot run is outstanding while the body says "The bot's base side (master), finished 11-14"; CHECKS.md exists.
- why it matters: stale heading, dangling reference; hedged wording about a file that exists.
- confidence: confirmed

### (heading omitted: it quotes the working arrangement)
- severity: Low
- kind: stale
- where: BRIEF.md:~188-205 (hand-off 11-14) vs contributions/README.md:95,97 and rd-2026-11-14.md:80,93
- evidence: BRIEF: [wording of the P-01 class omitted]
- why it matters: the hand-off a new reader starts from understates what is ready.
- confidence: confirmed

### CO-44: README's "State (2026-11-13)" still names patch/ as "the patch" whose message differs from the send package
- severity: Low
- kind: stale
- where: contributions/CO-44-mgmt-timeout-reported-as-auth-failed/README.md ("The patch: patch/0001-Bluetooth-MGMT-Report-..."); patch/ vs send-20261113/kernel/
- evidence: `diff` of the two kernel patches: different commit message (the send one has Link:, "Host Timeout (0x10)" wording); the README's 11-14 paragraph points to kernel/ but does not mark patch/ superseded.
- why it matters: two kernel patches with different messages, no explicit authoritative one.
- confidence: confirmed

(Checked and consistent, no finding: CO-44 dry runs (4 x Result: OK), no Signed-off-by and author line in all send packages since 11-13, cover-letter counts (5 and 2 files), CO-38 base-commit da3cc02587c6 / BlueZ 20ffd285b58f, CO-37 patch counts 6 and 4, X1 MR/issue ids and H1-H73, CO-46 numbers against results README.)

## Follow-up: docs/issues.md 1000-1450

### BT-24 and BT-25 sections say "not reproduced, no fix yet" / "Next: a kmemleak run"; STATUS says reproduced, fixed, in series
- severity: High
- kind: contradiction
- where: docs/issues.md:1155 (BT-24 status), :1161-1164 (BT-24 "Next"), :1167 (BT-25 status), :1182 (BT-25 "Next"); docs/STATUS.md:82, :83
- evidence: issues.md BT-24 "**Status 2026-11-13: race from source ...; not reproduced; no fix yet; not BT-17.**" and "Next: an emulator test ... Then the fix: scuttle under `txlock`, or clear the flag first"; BT-25 "Next: a kmemleak run in emulation that closes hci0 with a command deferred; then a fix together with BT-24". STATUS BT-24: "reproduced 2026-11-14 on the B2 tree (not reachable on E alone): a URB left parked 3/3, none 3/3 with the fix" -> "CO-43 series patch 4"; BT-25: "kmemleak finds leaked HCI command skbs in 11 of 12 fault runs on E alone, none of 12 with the fix" -> "series patch 5". (Both "next steps" are done: results/co43-d2-series-bt24-bt25-2026-11-14/.)
- why it matters: the issue register, the place a reader opens per issue, says the work has not started.
- confidence: confirmed

### BT-18, BT-19, BT-20, BT-21, BT-23 sections stop at 11-13 "fix candidate"; STATUS has 11-14 packages and a changed D
- severity: Medium
- kind: stale
- where: docs/issues.md:1086-1099 (BT-18: "fix candidate CO-43 D ... D is not to be sent as a fix ... Next: the question goes to linux-usb"), :1103-1119 (BT-19: "fix candidate CO-43 B ... B is on hold ... The rewrite waits for the BT-18 decision"), :1123 (BT-20 "fix candidate CO-43 A"), :1129 (BT-21 "fix candidate CO-44"), :1144 (BT-23 "fix candidate CO-43 E"); docs/STATUS.md:76-79, :81
- evidence: STATUS BT-18: "D v2 (reset queued only inside a runtime resume, PM reference held): runtime matrix 18/18 ... CO-43 D v2 in send-series-20261114/"; BT-19: "B2 removes the block (5.380 s -> 0.002 s) and keeps that reset (3/3), but needs D"; BT-20/21/23: "send package ready, dry run OK 2026-11-14". issues.md names the superseded B and the wide D and no send package; [wording of the P-01 class omitted] The section for BT-18 also does not carry the 11-14 review finding (D v2 loses the core's needs_binding rebind) that CO-43 README item 0 records.
- why it matters: the two registers describe different patches (B vs B2, D vs D v2).
- confidence: confirmed

### BT-17: "five patches" and the outside-review step
- severity: Low
- kind: stale
- where: docs/STATUS.md:75 ("CO-43 (btusb, five patches)"); docs/issues.md:1082 ("patch candidates in CO-43 (five) and CO-44")
- evidence: the CO-43 series now has A, B2, D v2, E, BT-24 fix, BT-25 fix (send-series-20261114 has 5 mails plus E separate). Numbers otherwise agree (5.29/5.38 s, 18:03:16, boot 08956069, five reviews, E3 #9, "nine E3 trials and 74 links").
- confidence: confirmed

### U24 and U23 rows: "not released / newest tag is 5.87" and "later CO-03 package"
- severity: Medium
- kind: stale
- where: docs/issues.md:1217 (U24 "fixed upstream by `7e3212fa233e` (not released)"); docs/STATUS.md:112 (U24 "in no release, the newest tag is 5.87 ... next to U12's in a later CO-03 package, on the operator's word")
- evidence: contributions/CO-37.../send-20261114/README.md "U24's fix 7e3212fa233e is in master and in 5.88"; rd-2026-11-14.md "U24: its fix ... is released in BlueZ 5.88"; the 5.72 backport is already patch 3 of the ubuntu-bluez-5.72-0ubuntu5.9-bundle.
- confidence: confirmed

### U23 numbers: issues.md and STATUS agree (3 of 10, 2 of 10) with each other but not with CO-37 per se
- severity: Low
- kind: other
- where: docs/issues.md:1216 ("3 of 10 runs on 5.72 and 2 of 10 on 5.72 with the CO-03 backport"); docs/STATUS.md:111 (same); CO-37 README results table ("5.72: 10/10 failing; 5.72 + backport 0/10")
- evidence: the two earlier counts are from CO-03's runs (T311/T310, different harness); the later counts are CO-37's; both rows keep only the old ones in the evidence column and mention CO-37 only for master. Not wrong, but a reader sees "2 of 10 with the backport" and "0/10 with the backport" for the same bug.
- confidence: likely

### STATUS U22 row quotes an ellipsis in an identifier; issues.md has elisions and out-of-repo paths as evidence
- severity: Low
- kind: rule-vs-practice
- [wording of the P-01 class omitted] STATUS.md:75/82 cite `reviews/` (in repo, fine)
- evidence: the lines quoted. The screenshot path and hash are truncated, so they cannot be matched to a file.
- why it matters: rule "identifiers in full"; evidence a reader cannot open.
- confidence: confirmed

### Coverage of ids
- severity: Low
- kind: other
- where: docs/issues.md:1186-1218 (table U1-U31) vs narrative bullets from :1250
- evidence: no BT row lacks a section in range (BT-16 section starts at line 951, before the requested range; BT-17-25 all have one). The U1-U31 table is the only text for U22-U31 inside 1000-1450; the narrative bullets I read (U1-U7) were not compared line by line to STATUS.
- confidence: needs-check for U-narratives beyond U7

(Not covered in this follow-up: U8-U31 narrative bullets after line ~1380, and BT-16's section body before line 1000.)

---

# Part: co-register

## co-register findings (contribution register part)

Mechanical results (commands: ls contributions; grep -o '^| CO-[0-9]*' contributions/README.md; same for rd-2026-11-14.md; grep -o 'CO-[0-9]+[a-z]?' over README.md, BRIEF.md, docs/STATUS.md, docs/issues.md)
- Register rows = 46 ids (CO-01..CO-46), rd-2026-11-14.md rows = the same 46 (CO-05+CO-26 and CO-11a/b, X1, X2-X4 folded). No gaps, no id defined twice.
- Directories without a row: none (X1-gvfs-cdda-readahead has the X1 row, "Off-topic" table, contributions/README.md:115; ubuntu-bluez-5.72-0ubuntu5.9-bundle is announced at README.md:35-37 without an id).
- Rows without a directory: CO-13 15 16 17 18 22 24 26 29 31 32 33 45. Each row says where the material lives or why, EXCEPT: CO-29, CO-31, CO-32, CO-33 (state only, no pointer; CO-32 points to docs/issues.md), CO-45 (explained: not ours), CO-22 (points to research-2026-11-01/qca-ids/, OK), CO-26 (in CO-05's package, OK). See finding on "opened as soon as anything is written".
- Ids referenced in README.md, BRIEF.md, docs/STATUS.md, docs/issues.md that the register does not define: none (only the sub-labels CO-11a/CO-11b, see below).
- research-2026-11-01/qca-ids/refresh-20261114/ exists (README.md, CHECKS.md, queue-refresh-20261114.md, mail/stable-request-asus-rome-v3.eml, logs/, SHA256SUMS) and holds what README row CO-22 and BRIEF.md:186-187 say (v3 on seven tips, owners call v2 without 0cf3:e303 in ../drafts/). policy/notes/CO-08,15,16,24.md exist. All relative Markdown links in the 14 files in my part resolve (script over all [..](..) targets; 0 broken).

### CO-37 row still says U24's fix is "not released"; BlueZ 5.88 contains it
- severity: Medium
- kind: stale
- where: contributions/README.md:83 (CO-37 row); contributions/rd-2026-11-14.md:~142 ("U24: its fix `7e3212fa233e` is released in BlueZ 5.88"); contributions/CO-37-bluez-media-endpoint-exit-uaf/send-20261114/CHECKS.md:15; reviews/2026-11-12T1537Z-all-contributions-explained.md (R6 "U24 is fixed upstream but not released")
- evidence: README row: "U24 is fixed upstream by `7e3212fa233e` (not released); its 5.72 backport gives 10/10 -> 0/10" in the same row that also carries the "11-14: rebased on master 20ffd285b58f" update. CHECKS.md:15: "in master and in the 5.88 tag (`git tag --contains`: 5.88)". The bundle README (ubuntu-bluez-5.72-0ubuntu5.9-bundle/README.md:11) says "(in 5.88)". BlueZ 5.88 was tagged 2026-11-05, before the 11-12 review that also says "not released".
- why it matters: a reader of the register would think the upstream fix is still unreleased and that the 5.72 backport is a pre-release stopgap.
- confidence: confirmed

### (heading omitted: it quotes the working arrangement)
- severity: Low
- kind: stale
- [wording of the P-01 class omitted]
- evidence: README CO-38: "BlueZ TestFunctional failed 2 of 3 patched (BAP cases, likely a flake, not shown)"; rd: "CO-38's BlueZ TestFunctional failures are a flake (5 more pairs: the same BAP case failed once on base, never on patched)". README CO-39: "bot patched side passes; base side still to read"; rd: "CO-39's bot base side: PASS but a `unit/test-hog` CheckValgrind failure on master, not ours". BRIEF.md:207-208 has the same stale form ("flake not shown", "CO-41 and CO-39 (no report yet)").
- why it matters: the index is declared the authority for state (rd line 3) but lags the same day's results; the operator would re-do checks already done.
- confidence: confirmed

### CO-07/CO-34 rows not updated by the 11-14 results
- severity: Low
- kind: stale
- [wording of the P-01 class omitted]
- evidence: rd Results: "CO-32's WirePlumber fix and CO-07's six GNOME commits built for noble for the first time ... (27/27, 5/5)"; rd table CO-34: "released in 5.88". README CO-32 row (:77) also lacks the build.
- why it matters: register and rd disagree on whether the Ubuntu GNOME/WirePlumber packages were built.
- confidence: confirmed

### rd-2026-11-14.md table is stale against its own "Results so far" section
- severity: Low
- kind: contradiction
- where: contributions/rd-2026-11-14.md table rows CO-04, CO-05+26, CO-12, CO-14, CO-20, CO-21, CO-22, CO-30, CO-35, CO-38, CO-39, CO-41 vs "Results so far (2026-11-14)" bullets
- evidence: table CO-22 "stable request v2 ready since 11-02 ... R&D yes: has stable taken the pair meanwhile; refresh"; Results "CO-22 rechecked on seven tips (request v3, owners call v2...)". Table CO-35 "package ready 11-02 ... R&D yes: refresh"; Results "CO-35 refreshed on today's stable tips". Table CO-39 "bot run from 11-08 unfinished"; Results: bot rerun done.
- why it matters: one page gives two states for the same item; it names the index as the authority, but the table (the part a reader scans) is the morning snapshot.
- confidence: confirmed

### Register intro says every item gets a folder "as soon as anything is written"; 13 rows have none, several with ready packages
- severity: Low
- kind: register-integrity
- where: contributions/README.md:122-123 ("Items without a link have no dossier yet. One is opened as soon as anything is written about the item."), :3-4 ("Every possible ... contribution gets a folder here"); rows CO-13,15,16,17,18,22,24,26,29,31,32,33; reviews/2026-11-12T1508Z-upstream-contributions-status.md §6 "CO-20, CO-21, CO-22 and CO-38 have dossiers and no issue row"
- evidence: CO-22 has drafts, a v3 mail and a checks run (research-2026-11-01/qca-ids/, refresh-20261114/) and is "ready to send" in BRIEF.md:186 but has no CO-22 directory; CO-32/CO-29/CO-33/CO-31 have confirmed findings and drafted fixes (README rows) and no folder; 1508 §6 calls CO-22 a dossier.
- why it matters: the stated rule is not what is practised, and CO-22 (a send-ready item) lacks the NOTES-FOR-OPERATOR/CHECKS layout the other send items have.
- confidence: confirmed

### "NOTES-FOR-OPERATOR.md" claimed for every ready package; five have none
- severity: Medium
- kind: doc-vs-code
- where: BRIEF.md:183-189 ("Ready to send, each with `NOTES-FOR-OPERATOR.md` (his decisions) and nothing sent: CO-44 ..., CO-43 E and A, CO-38, CO-04, CO-05 + CO-26, CO-35, CO-22, CO-21 and CO-20, CO-02 v2"); contributions/CO-04-mesh-test-14888791/send-20261114/, CO-05-.../send-20261114/, CO-38-.../send-20261114/, CO-35-.../send-20261114/, contributions/research-2026-11-01/qca-ids/refresh-20261114/
- evidence: `find contributions -name NOTES-FOR-OPERATOR.md` lists only CO-02 send-v2, CO-20, CO-21, CO-23, CO-37, CO-39, CO-41, CO-44, CO-43 E and A, CO-35 review-fixes-20261114 (a different folder), CO-43 drafts. None in CO-04, CO-05, CO-38, CO-12 send-20261114 or CO-22 refresh. 
- why it matters: the operator is told each package carries his decisions list; for CO-04/05/38/22 there is no such file (and CO-35's is not in send-20261114/).
- confidence: confirmed

### Ready-to-send lists disagree: BRIEF omits CO-23, CO-37, CO-39, CO-41, CO-12
- severity: Low
- kind: contradiction
- where: [wording of the P-01 class omitted]
- evidence: BRIEF ready list = CO-44, CO-43 E/A, CO-38, CO-04, CO-05+26, CO-35, CO-22, CO-21, CO-20, CO-02 v2 (also the briefing's reference list). Register shows CO-23, CO-37, CO-39, CO-41 and CO-12 with 11-14 `send-20261114/` packages, all with the same "nothing sent" status; CO-23/37/39/41 also have NOTES-FOR-OPERATOR.md.
- why it matters: the hand-off under-reports what the operator can send.
- confidence: confirmed

### CO-03's contents: dossier and 11-12/13 reviews say it carries the BT-7 fixes; the 11-14 bundle says the final candidate left them out
- severity: Medium
- kind: contradiction
- where: contributions/CO-03-bluez-u12-backport/README.md:6 ("five commits on `5.72-0ubuntu5.8`: BT-7, the helper part of `3d9900eb754d`, `a14d59725ef3` and `664a5d3785a1`"); reviews/2026-11-12T1537Z-all-contributions-explained.md R9 ("also carrying A2/A3 and October's security fixes"), 11-13 review R9 ("Ubuntu SRU: bluetoothd loses A2DP + the BT-7 fixes"); contributions/ubuntu-bluez-5.72-0ubuntu5.9-bundle/BUNDLE.md:23 and CHECKS.md:30
- evidence: bundle: "The two BT-7 crash fixes of CO-03's five-patch build (`a734b06059cb`, `0bed9886cff3`) are **not** in the bundle: the final CO-03 candidate left them out, they were never exercised by a test, and no Ubuntu series carries them." Register top (README.md:35) and BRIEF.md:196 present the bundle as carrying CO-03.
- why it matters: Ubuntu 24.04 users' crash fixes (BT-7) are dropped from the proposed upload while three documents still say CO-03 delivers them; D6 is open so the operator could file believing BT-7 is included.
- confidence: confirmed

### Decisions D1-D14: all open in followups.md, but 11-14 packages and the register present several as taken
- severity: Medium
- kind: contradiction
- where: contributions/review-2026-11-02/followups.md (intro: [wording of the P-01 class omitted] BRIEF.md:224-228
- evidence: BRIEF.md:224-228: "decisions D1-D14 ... stay the operator's; today's packages put D1/D2 ... and D6 ... in front of him as built options, not as decisions taken" (consistent). But: (a) followups D6 recommends "The CO-37 5.72 backports as a separate SRU, after the upstream route (D3) is settled", while the bundle (BUNDLE.md, README.md table rows 3-6) and README.md:35 include CO-37's backports in the one upload with no "D6 open" note at the register top; [wording of the P-01 class omitted] (c) followups D2 says the guard "goes out with v2" and the CO-02 NOTES-FOR-OPERATOR.md:11 treats that as support, though D1/D2 are open; (d) followups.md is dated 11-02 and was never updated, so it still says nothing was acted on. CO-02 dossier README.md:11 correctly says "Decisions D1/D2 are the operator's"; the CO-02 NOTES file calls "the task brief" mislabelled (D1/D2 meanings) - BRIEF.md:226 lumps D1/D2 as "-EBUSY on a live link", whereas followups D1 is timing/label and D2 is the guard.
- why it matters: D1-D14 are open (none recorded decided anywhere), but the register wording lets a reader take D1/D2/D6 as settled and the bundle contradicts D6's own recommendation.
- confidence: confirmed (open/decided status), likely (impact)
- note: D3, D4, D5, D7-D14: no document anywhere claims them decided. D4 mentions the operator's "29 October decision" (a different, earlier decision on mesh reproducers), not D4 itself.

### CO-02 row does not carry the CI's "must be resent" mail that the 11-13 review says settles the closure cause
- severity: Low
- kind: stale
- where: contributions/README.md:47 ("closed by its bot in a sweep that also closed another author's pending patch, which is not a review"); reviews/2026-11-12T1508Z-upstream-contributions-status.md §3 ("why ... is not established"); reviews/2026-11-13T0120Z-registers-and-contributions-status.md:96, :273-276, §4 item 3
- evidence: 1508: "So the series of 10-27 dropped out of the bot's list as a group; why ... is not established". 1508 also says the PRs were "closed without a comment". 11-13: "the CI closed both mirror pull requests and **mailed (BlueZ test) that the series must be resent to be considered**"; §4.3 "This corrects yesterday's §3 ... a two-week staleness rule, not a query failure"; §5: "prepare and send v2. The CI now requires a resend in any case." README row (11-12 text) never records the resend mail, and says "it is not a review" only.
- why it matters: the 11-12 review text (still linked from the register) is explicitly corrected one day later; the register keeps the superseded reading and a reader of the register misses that a resend is required.
- confidence: confirmed

### "All twelve" vs "eleven" BlueZ commits
- severity: Low
- kind: contradiction
- where: reviews/2026-11-13T0120Z-registers-and-contributions-status.md:257 vs reviews/2026-11-12T1537Z-all-contributions-explained.md:382, README.md:13,51,187
- evidence: 11-13: "**All twelve of our BlueZ commits are in BlueZ 5.88**"; 11-12: "one kernel fix, eleven BlueZ commits"; README.md: "All eleven BlueZ commits". The difference is d84171e6cd68 (redundant a2dp v2) which the 11-13 table lists inside A3 ("+ v2 d84171e6cd68").
- why it matters: one-off count mismatch between reviews of adjacent days; the briefing's number is eleven.
- confidence: confirmed

### Elided identifiers ("...") in paths in the register and rd page
- severity: Low
- kind: rule-vs-practice
- where: contributions/README.md:65 (`CO-20-…/send-20261114/`), :66 (`CO-21-…/send-20261114/`), :75 (`CO-30-…/rfc-20261114/`), :120 (`X1…/patch1/`); contributions/rd-2026-11-14.md:76 (`CO-43-…/send-series-20261114/`, `CO-21-…/send-20261114/`), :77, :82, :87, :90, :100, :103, :113, :117, :123 (e.g. `CO-12-…/send-20261114/`, `CO-02-…/send-v2-20261114/`); reviews/2026-11-12T1508Z-...md:53 (`…/issues/1009/events`, `…/2724/events`); reviews/2026-11-13T0120Z-...md:160 (`/lib/modules/7.0.0-43-generic/kernel/…`)
- evidence: grep -n -o '[A-Za-z0-9_./-]*…[A-Za-z0-9_./-]*' over the files. Rule: identifiers/paths written in full, no "…" elision.
- why it matters: 14+ path occurrences violate the written rule; several are in the register's own state column.
- confidence: confirmed

### Register points to work-area paths that are not in the repository
- severity: Low
- kind: broken-reference
- where: contributions/README.md:82 (CO-38: [wording of the P-01 class omitted]
- evidence: README intro says the dossier "links to everything else" and nothing is untracked-only; this path is outside the repo (git-ignored/untracked work area), so it cannot be verified from a clone. (CO-38's send-20261102/ and send-20261114/ exist in the repo.)
- why it matters: a reader cannot follow the pointer.
- confidence: likely

### Sub-labels CO-11a / CO-11b are used everywhere but defined only inside one row
- severity: Low
- kind: register-integrity
- where: contributions/README.md:56 (row "CO-11", parts "(a)" and "(b)"); contributions/rd-2026-11-14.md:23-24 (rows "CO-11a", "CO-11b"); BRIEF.md:196, STATUS (CO-11a x5)
- evidence: grep: CO-11a appears 5 times in the foundation docs; the register has only "CO-11" with (a)/(b).
- why it matters: minor; id used but not an index key.
- confidence: confirmed

### docs/contributions-roadmap.md: labelled historical, but internally inconsistent after a partial update
- severity: Low
- kind: stale
- where: docs/contributions-roadmap.md:3 ("kept separately until 2026-10-09, unchanged in substance; the current state of every item is `docs/STATUS.md`"), :25 (BZ-free row with CO-23 (2026-10-29)), :90 (§3 "BZ-free: one crash, no mechanism. Not a contribution until a second instance or a mechanism.")
- evidence: the header says "(as of 2026-09-26)" and points to STATUS, so it is not presented as a current plan (OK). But row :25 was updated on 10-29 ("use-after-free in `a2dp_reconfig()` ... **CO-23** (2026-10-29): reproduced under ASan"), contradicting both "unchanged in substance" and the §3 text at :90 still saying no mechanism; §6 "Order of work" (E3 first, stable request next) and BT-1 row ("E3 ... then the request") contradict the register (CO-09 done, E3 retired). Nothing current links to it as a plan (only HISTORY.md and CO-23 notes cite it).
- why it matters: a reader of the file sees the same item as both "no mechanism" and "CO-23 fixed"; low risk because of the historical header.
- confidence: confirmed

### contributions/REVIEW-ROUND-2026-11-01.md is dated but not marked superseded
- severity: Low
- kind: stale
- where: contributions/REVIEW-ROUND-2026-11-01.md ("Not in this round": CO-12 "the fix is not in the repository yet", CO-21 "a candidate fix exists only in a work area")
- evidence: README.md:57 (CO-12 draft in `patch/draft-2026-11-01/`, `send-20261114/`), :66 (CO-21 `send-20261114/`) contradict it now; the file says "An intermediate round", is dated in its name, and its links all resolve; nothing in the register points to it as current (grep: no reference outside itself).
- why it matters: historical and dated, so only informational.
- confidence: confirmed

### D-table in followups.md and the two 11-12 reviews: checked, no contradictions beyond the above
- severity: Low
- kind: other
- where: reviews/2026-11-12T1508Z..., 2026-11-12T1537Z..., 2026-11-13T0120Z...
- evidence: all three agree on the accepted/released facts (86ef0f58bdec, 5.88 commits, stable lines, CO-02 sent 10-27, CO-25 10-29, CO-10 10-21, Hui Peng Tested-by 10-06, X1 11-07); the same-day pair 1508/1537 agree (1537 lists CO-22 as request v2, CO-39 bot result unrecorded, consistent with 11-12 state); later states (11-13 BT-17 P15 "no CO id yet" -> CO-43; E3 retirement) were picked up in the register. Disagreements with the register are those listed above.
- confidence: confirmed

NOT covered: the bodies of review-2026-11-02/review-package.md (489 KB, skimmed only via README/followups), the per-item F-01..F-92 rows beyond F-1..F-39 + F-80..F-91, the dossier front pages' own state lines (only the register rows were compared), and the research-2026-11-01 subdirectories' content (not opened; only existence and the Markdown README).

---

# Part: docs-a

## docs-a findings

### kernel-send-package.md is unlabelled-as-historical and states as current what is false (BT-1 patch "does not exist yet", README "No kernel patch exists yet", bug-report "unresolved")
- severity: Medium
- kind: stale
- where: docs/kernel-send-package.md:1-5 (only a "Written 2026-09-24 ... Kept separately until 2026-10-09" note), :26-28, :35-36 (bug-report), :82-84, :129-134
- evidence: ":27 `named after — that one does not exist yet (`BT-1`, BRIEF §9.6)`"; ":35 `bug-report.md is about the controller fault — a different, unresolved defect`"; ":129 `README.md says "No kernel patch exists yet." True for the controller fault, false for this one — it changes on the day.`" (grep: README.md contains no such sentence); ":134 `BRIEF §9.8–§9.9 move from "prepared" to "sent", and patches/kernel/ comes to main`". Reference facts: BT-1's cause is the missing entry, fixed by dc16388d45ec; the MGMT patch was sent 09-24 and is in v7.3.
- why it matters: the file's present-tense procedure ("what must be true on the day", "the held branch kernel/mgmt-flush-status", §5 "changes on the day") describes a send that happened 2026-09-24; a reader following §5 would look for README text that does not exist and a branch that is not in the repo (git branch -a lists only main).
- confidence: confirmed

### kernel-send-package.md cites BRIEF §9.6 and §9.9 for things those items no longer say
- severity: Medium
- kind: broken-reference
- where: docs/kernel-send-package.md:27, :83, :134 vs BRIEF.md (item 6 at ~line 667, item 9 at ~line 749)
- evidence: package: "`BT-1`, BRIEF §9.6" = the unsolved controller patch; "the text BRIEF §9.9 records as neutralised on `main` but still in history"; "BRIEF §9.8–§9.9 move from prepared to sent". BRIEF.md §9.6 is "Done 09-26 → 10-01: E1 (setup only) and E3 (the exact entry) ran, 0 timeouts in 74"; §9.9 is "Closed: the patch ran here 09-24 ... applied upstream 09-29 (86ef0f58bdec)" (a runtime test record). grep "neutralis" BRIEF.md: no hit at all.
- why it matters: three cross-references on a "main route" point at items whose content changed; the "neutralised text" statement cannot be found anywhere in BRIEF.
- confidence: confirmed

### pre-submission-checklist.md: privacy purge "must happen before submission" contradicts practice and current privacy rule; other open items obsolete
- severity: Medium
- kind: rule-vs-practice
- where: docs/pre-submission-checklist.md:1-8 (Note labels the gates "the record of that time"), :23-24 "Status: deferred by decision, must happen before submission", :33-35, :86-95 (§2 "none of these are met yet", A4/Builds A/B/C/D), :104-110 (§2a BT-3 "patch trivial, justification missing", BT-1 "blocked"), :160-ish §4 "Remove the 'under active revision' banner from bug-report.md"
- evidence: README.md "Evidence published from 2026-10-11 on uses pseudonymous device addresses"; README/BRIEF show 1 kernel + 11 BlueZ + stable mails were all sent with no history purge (git history not rewritten, BRIEF:416 "Before any history rewrite..." only). bug-report.md has no "active revision" banner (grep -i "active revision" bug-report.md: none; it has a "Historical record (2026-10-03)" banner).
- why it matters: the Note at the top softens the file but §1 still says purge is mandatory before anything is sent to linux-bluetooth, which has been done 27 times; the checklist items BT-3/§4 refer to banners and states that no longer exist.
- confidence: likely (purge never happened: needs-check against git log, I did not rewrite-scan history)

### pre-submission-checklist.md §2b recommends/discusses autosuspend as a factor (retracted claim)
- severity: Low
- kind: stale
- where: docs/pre-submission-checklist.md:112, :117-125
- evidence: "| USB autosuspend | **restored to `Y`** | disabling it changes the controller's operating conditions ...it is a workaround under test"; "If autosuspend is worth testing as a factor... `stock N`". The retraction (autosuspend 0/4 vs 3/4) is not mentioned; protocol is moot.
- why it matters: low, the file is labelled as a record of August; mentioned only because it still reads as a design to follow.
- confidence: likely

### missing-quirks-entry.md lacks several of the numbers that README calls "the full argument"
- severity: Medium
- kind: stale
- where: docs/missing-quirks-entry.md:3-10 (superseding banner), :12-20, README.md:101-106
- evidence: README.md:101-106 sends the reader there for "The full argument". grep in the file for Harcsa, v7.3, rc1, "74", twelve/12 instances, 7.2.10/6.18.56/6.6.160, 7.0.0-38/-42/-43, retired: NO hit. Present: E1 "58 ... three boots ... 0 command timeouts" (:5), E3 "16 links on two headsets ... 0 timeouts ... 0 0x2005 errors" (:6-8), built for 7.0.0-34 (:6). Missing/contradicting: (a) no author name (Tibor Harcsa) - :14-15 only "Commit dc16388d45ec ... authored 2026-06-29, committed 2026-08-07"; (b) :16-18 says the entry is "in master and absent from v7.0, linux-6.6.y and linux-6.12.y" - never updated to v7.3-rc1 / queued for seven lines (EX-061) / released 7.2.10, 6.18.56 (10-11), 6.12.113 (10-15), 6.6.160 (10-21), 6.1.191, 5.15.224, 5.10.273 (10-30); (c) E3 "later rebuilt for -38 (10-11) and -42 (10-30), retired on -43" absent; (d) no total of 74, no "12 instances"; (e) the "2026-08-07" date is right per the file but the doc also says second banner ":18 the kernels this project ran (`7.0.0-28…31`)" vs the reference four kernels -29,-30,-31,-34 (also uses the "…" elision for kernel names).
- why it matters: the stable-release/author/instance facts live only in README, so the "full argument" document stays at its 09-26 state; the second banner (:10-20) still asserts "the setup and reset paths the entry installs are untested here" two paragraphs after the first banner says the opposite (the first banner says it "supersedes").
- confidence: confirmed

### missing-quirks-entry.md internal contradiction after banners: "untested here" / "NOT established as the fix" headings remain
- severity: Low
- kind: contradiction
- where: docs/missing-quirks-entry.md:10-20 vs :3-9; section "A candidate fix — NOT established as the fix" (~:127), "+0 s — what the patch would do | never tested" (~:146)
- evidence: ":19 `the setup and reset paths the entry installs are **untested here**`" vs ":4 `The entry's setup path is no longer "untested here"`"; section body: "Untested — and our experiments did not test it."
- why it matters: the file says "kept as written" and the first banner supersedes; low because banner explicit.
- confidence: confirmed

### bug-report.md: labelled historical (good) but carries EX-nnn exhibit ids; no BT-/CO-/U-/R2-/DR- labels
- severity: Low
- kind: rule-vs-practice
- where: docs/bug-report.md:6,7 (banner), :60-66, :71, :73, :91, :102-104, :109, :120-125, :129, :137, :159, :164, :168, :186, :249, :251, :254
- evidence: grep -nE '\b(BT-[0-9]+|CO-[0-9]+|U-?[0-9]+|R2-[0-9]+|DR-[0-9]+|DP-[0-9]+|M-[0-9]+)\b' docs/bug-report.md: NO hits (BT-1..4 gate in tests/run-tests:1840 passes). `EX-0nn` appears ~36 times (e.g. :60 "| `EX-033` | 08-22 | `-29` |", :6 "validated here (`EX-055`–`EX-058`) ... `EX-061`"). Label banner is present at :3-8 ("Historical record (2026-10-03) ... pre-fix draft ... never sent"), consistent with BRIEF §9.1.
- why it matters: the BRIEF rule bans only BT-n, so EX-nnn is permitted by the gate; if the lead's stricter list (EX-nnn too) applies, they are in the file. Also stale body: ":174 `Correlation across seven deaths and one survival`" (BRIEF:320 notes "12 deaths / 1 survival ('7' when this was written)") - acceptable under the historical label.
- confidence: confirmed

### external-review-brief.md has no status/date label; presents August beliefs as "what we currently believe"
- severity: Medium
- kind: stale
- where: docs/external-review-brief.md:1-5 (no label, "Hand this to a reviewer as-is"), :56-64 (Kernel 7.0.0-28/-29, peers), §6 "What we currently believe" (~:216-239), §6.1; only date in file is :256
- evidence: ":1 `# External review brief — the whole Bluetooth stack...` / `:3 **Hand this to a reviewer as-is.**`; §6: "This USB ID matches no entry in the btusb quirks table. It therefore receives no vendor firmware-download path and no hdev->reset callback"; "We believe the driver selects USB alternate setting 1"; ":12 only a full power-off restores it — a reboot does not". No mention of dc16388d45ec, the fix, E1/E3.
- why it matters: README's map says docs/ holds "historical plans and drafts, each labelled"; this one is not, and a reader (or new reviewer, as instructed) would take the sealed beliefs as current.
- confidence: confirmed

### review-task-bluez-patches.md is unlabelled and speaks of unsent/unapplied patches
- severity: Low
- kind: stale
- where: docs/review-task-bluez-patches.md:1-4, :3 "before they are mailed", :54-56 "will be sent as two separate mails", :100 "last verified against BlueZ master c73fa2f9a"
- evidence: ":1 `# Review task — two BlueZ patches, before they are mailed`"; only "Written 2026-09-19". Reference: both applied 2026-09-21 (a734b06059cb, 0bed9886cff3), released in 5.88; links point to patches/bluez/0001-*.patch, 0002-* (exist per git ls-files).
- why it matters: no historical label; the dated line is the only cue. Low because the date is explicit.
- confidence: confirmed

### related-reports.md unlabelled; calls the v5.12 regression route "the only unblocked path upstream"
- severity: Low
- kind: stale
- where: docs/related-reports.md:171-172 (also :1-6 dated "gathered 2026-08-11")
- evidence: ":172 `which is the route this project currently considers its only unblocked path upstream`"; ":19-21 ... compatible with the firmware hypothesis". The actual route was a device-table entry (dc16388d45ec) + stable request.
- why it matters: present-tense "currently" on an August statement, no historical banner.
- confidence: confirmed

### investigation-plan.md: 0x0428 vs 0x043D comparison stated as "sharpest available" 70 lines before its retraction
- severity: Low
- kind: contradiction
- where: docs/investigation-plan.md:44-47 vs :112-118
- evidence: ":44 `What replaced it as the sharpest available comparison is 0x0428 versus 0x043D`"; ":112-117 `that 0x0428 means CVSD. It does not. ... any argument resting on that equivalence — including the 0x0428-versus-0x043D comparison ... must be restated`". Labelled: ":16 `2026-10-03: this plan is preserved as written; the active queue is docs/STATUS.md`". No inline marker at :44.
- why it matters: retraction exists and is in the same section; low.
- confidence: confirmed

### investigation.md Tier-1 recommendation (disable autosuspend) not annotated at the point of recommendation
- severity: Low
- kind: stale
- where: docs/investigation.md:425-436 (§11 Tier 1 A), :149-155 (§6a "most actionable"), :521 ("autosuspend was the trigger"); banner at :8-11
- evidence: "**A. Disable USB autosuspend for the BT radio. Removes the suspend/resume race that opens the window for the wedge (§6a).**" Banner (:8) says "Historical chronology... do not quote an unannotated section". Retracted: autosuspend 0/4 vs 3/4 (BRIEF §9.5 treats it as unchanged-code config).
- why it matters: labelled historical, so low.
- confidence: confirmed

### docs/sent-mails.tsv: all expected mails present; hashes and Message-IDs consistent; one path cell says "not kept in the repository" though the request is kept
- severity: Low
- kind: contradiction
- where: docs/sent-mails.tsv:7 (row 2026-10-02), patches/diag/stable-request-dc16388d45ec.md:1-6, README.md:262
- evidence: tsv: "2026-10-02 03:25:42 +0200 | QCA9377 stable request dc16388d45ec | not kept in the repository | <20261002012542.473669-1-...>"; README:262 "patches/diag/ diagnostic btusb builds (E1, E3) and the stable request for dc16388d45ec"; the tracked file patches/diag/stable-request-dc16388d45ec.md records the draft v4c "SENT 2026-10-02" with the same Message-ID (the .eml itself is local-only: "tmp/stable-backport/request-v4.eml").
- why it matters: the sha256 column is empty for this row while the draft is tracked; can be pointed to it.
- confidence: confirmed
- Checks performed (no defect): 27 rows, all 7 columns; every file with a hash re-hashed with sha256 and equals the recorded value; the 7 lore Message-IDs in README.md lines 63-77 (stable 20261002012542.473669-1, Tested-by 20261006201800.3597400-1, BT-9 ...2789588-1/-2/-3, CO-10 20261021030542.1434603-1, CO-02 20261027165009.2401154-1) match the tsv rows; Message-ID timestamps are the UTC form of the row's local time for all rows with a time; patchwork 14919266-14919269 (CO-02) match; all listed mails (BlueZ v1 09-19, v2 09-21, MGMT 09-24, stable 10-02, Tested-by 10-06, shared-mgmt 10-08, BT-9 x3 10-10, emulator/mgmt-tester 10-10 (briefing's "10-12" = application date, not send date), cleanups 10-18, CO-10 10-21, CO-02 10-27 (0/3+3 + BlueZ test), CO-34 10-28, CO-25 10-29) have rows. Minor: shared-mgmt row has time 05:41:01/05:41:02 while Message-IDs are ...034102.../...-2 (1 s apart, fine); rows for v1/v2 BlueZ and CO-34 carry date only.

### README.md tree map (line ~255) still says "the two applied BlueZ patches"
- severity: Low
- kind: stale
- where: README.md:255 vs README.md:8-9, 18-19 (eleven BlueZ commits)
- evidence: "patches/bluez/        the two applied BlueZ patches, their verification script and mail notes;" vs "eleven BlueZ commits ... all released in BlueZ 5.88". The sub-lines (shared-mgmt, send-2026-10-18) then list others.
- why it matters: minor internal count mismatch on the front page.
- confidence: confirmed

### Link and path checks
- Result: all relative markdown links and github blob/tree links in README.md and the 12 docs resolve to tracked files/dirs (script over git ls-files). Backticked tool paths in kernel-send-package/pre-submission-checklist/review-task/external-review-brief resolve (scripts/pre-send-check.sh, scripts/export-kernel-review.sh, devtools/held, patches/bluez/git-am-check.sh etc.); only scripts/get_maintainer.pl is missing, and it is the kernel tree's own script (not a defect). "…" elision of identifiers: docs/missing-quirks-entry.md:18 (`7.0.0-28…31`, kernel names) and docs/investigation-plan.md:556-559 (`…/symtest/repo`, path elision inside a command transcript); other "…" hits are numeric ranges or log excerpts.
- BlueZ/kernel convention check: kernel-send-package.md §2-§4 (Signed-off-by mandatory in kernel, error in BlueZ; Fixes:; Cc: stable as trailer, never to stable list alone; both trees on send day) agrees with BRIEF §9.8; checked against patches/kernel/0001-*.patch (Fixes:, Cc: stable, Signed-off-by present).
- bluez-issue-1554-reply-2026-10-09.md and firmware-hypothesis.md/fix-proposal.md carry clear status labels (the reply is an as-posted comment; firmware-hypothesis has a revised status line; fix-proposal has SUPERSEDED banner). No finding.

---

# Part: docs-b

## (heading omitted: it quotes the working arrangement)

### README says BT-16 happened "Twice"; later documents record three occurrences
- severity: Medium
- kind: contradiction
- where: README.md:163 ; docs/STATUS.md:74 ; docs/issues.md:999,1003 ; results/bt16-third-2026-11-13/README.md:1 ; BRIEF.md:229
- evidence: README.md:163 "Twice (boots of 2026-11-05 and 11-11) the controller came up reporting its firmware patch as already loaded"; STATUS.md:74 "At three boots (2026-11-05, 11-11 and 11-13)"; issues.md:1003 "3 occurrences now."
- why it matters: front-door file understates the open problem, and the third one is the first on stock btusb (rules out the E3 module as a condition).
- confidence: confirmed

### README.md map describes results/ as two things; it holds 18 entries
- severity: Low
- kind: stale
- where: README.md:254-255
- evidence: "results/  dated results of runs that belong to no single dossier (the list's CI run locally; the L2CAP hang sweep)". results/ holds 16 directories + ci-local-2026-10-10.md + sent-mail-check-2026-10-28.md (bt17-emulation, co43-*(3), incident-2026-11-12-1803, bt16-third, u29-*(3), laptop-only-work, suite-timing, journalctl-file-scaling, supported-commands-survey, bluez-5.88-release-check, ...). Orphan check (git grep of each name in *.md outside results/): no orphans, every entry has >=1 inbound reference; the weakest are suite-timing-2026-11-08 (1 ref, comms/2026-11-09T1625Z-from-test-suite-maintainer-to-everyone.md:22 only; no register/STATUS/BRIEF link), co43-co21-co20-packages-2026-11-14 (2), u29-lifetime-patch-2026-11-07 (2), supported-commands-survey (2), sent-mail-check (2).
- why it matters: the map is the entry point and names 2 of 18.
- confidence: confirmed

### external-cache.md says the cache lives outside the repo in /var/cache/bt-investigation; BRIEF §7 and .gitignore say cache/ inside the checkout
- severity: Medium
- kind: rule-vs-practice
- where: docs/external-cache.md:27-31 ; docs/external-cache-manifest.tsv:4 ; docs/source-access.md:262-266 (sec. 7 "scratch directory outside the repository") ; BRIEF.md:460,749 ; .gitignore (cache/ entry)
- evidence: external-cache.md: "/var/cache/bt-investigation/<topic>/ ... Outside the tree, deliberately"; BRIEF.md:460 "commits made inside upstream checkouts under `cache/`. Those go as patch exports, never as the trees"; .gitignore "cache/  third-party sources (kernel, BlueZ)". grep for "var/cache/bt-investigation" finds only external-cache.md. Manifest row 3 names `bluez/` (git, --depth 200) while the real clone is cache/bluez-upstream (results/bluez-5.88-release-check README). No file says external-cache.md is superseded and none of README/BRIEF/tooling-index links it (only reviews/ and comms/ do).
- why it matters: a reader following the doc caches under /var/cache; the actual practice (cache/ gitignored, exported as patches) is undocumented there; BRIEF §7 contradicts the location.
- confidence: confirmed

### external-cache-manifest.tsv: row 3 does not fit the schema, content stale
- severity: Low
- kind: register-integrity
- where: docs/external-cache-manifest.tsv:4 ; docs/external-cache.md:53-59
- evidence: header `sha256 bytes`; row 4 gives `commit c73fa2f9ae2d366cb8a4f101fa9a5ccd9f33a4ea` in the sha256 column and `22M` in the bytes column. The "Current contents" table of external-cache.md lists only kernel-source, not the bluez row. Row 3 `verified_against` ends with elision "(b11f88c0…, 1977266 bytes)" (full hash is in col 3). The kernel table (external-cache.md:63-67) stops at 7.0.0-30; machine is on 7.0.0-43.
- why it matters: manifest cannot be machine-verified; identifier elision against project rule; no tracked path in the manifest is missing (the files are by design outside the tree).
- confidence: confirmed

### source-map.md / source-access.md are undated-as-current but describe the 2026-08-23 state
- severity: Low
- kind: stale
- where: docs/source-map.md:5-9,25-40 (rows 1-4 "blind", "read? no", "two components read"; "Widening the capture scope is therefore a prerequisite") ; docs/source-access.md:12 ("executed and verified on 2026-08-23"), :22 (git.kernel.org, lore refused) ; docs/source-access.md:225-228
- evidence: since then tools/bt-ui-capture (GNOME/WirePlumber/AT-SPI capture) exists and docs/userspace-upstream-check-2026-10-03.md read gnome-control-center, PipeWire; results/bluez-5.88-release-check README fetches from git.kernel.org; BRIEF §9 uses cache/linux with kernel.org remotes. The quoted command `grep -ohE '\-u ...'` still returns the same three units (verified). Neither file carries a "historical / as of" status line.
- why it matters: a reader would plan around a capability gap (GNOME blind, kernel.org unreachable) that no longer holds; neither file is linked from README/BRIEF.
- confidence: likely (blocked-host status may be per-machine)

### 5.88 release check: control output for 5.87 is not shipped
- severity: Low
- kind: rule-vs-practice
- where: results/bluez-5.88-release-check-2026-11-07/README.md:14-15 ; output.txt ; BRIEF.md:353
- evidence: README: "Control ... on the previous tag ... 11 lines, each `NOT in 5.87`" but the directory holds only README.md and output.txt (5.88 run). output.txt: 11 lines `in 5.88`, ids a734b06059cb, 0bed9886cff3, ae23df052290, 6f5eeb402d3b, 8da7e648a9fb, f3344d20d904, 2942883d2738, 49a70562f0bf, b79d4a887, 7bc9684dc, 3e5b0da969c2: all eleven match the reference list. BRIEF.md:353 "none was in 5.87" rests on the unshipped control output.
- why it matters: "every claim ships its command and output" is broken for the half of the check that shows it can say no.
- confidence: confirmed

### Retest kit counts agree (no finding) / pinned commit not in clone
- severity: Low
- kind: broken-reference
- where: patches/mesh-tester/hui-peng-tested-by-reply.txt (last lines) ; HISTORY.md:4787 ; docs/sent-mails.tsv:8
- evidence: git ls-files retest -> 159 *.log; REPORT.md:80,93,112 "159 VM runs" and its table sums to 159 (36+4+2+24+6+4+63+20), per-dir file counts match; README.md:64 "159 VM logs" OK; reply file sha256 cd39b136... equals sent-mails.tsv:8. The sent mail links `.../tree/ccfc358e2cd866948aea3ec81bfabd5298e30618/retest/mesh-tx-leak`; `git cat-file -t ccfc358e...` fails here (clone has 50 commits; HISTORY.md:4787 names it as `ccfc358`). 
- why it matters: counts consistent; but the immutable public link is unverifiable from this clone.
- confidence: needs-check (public repo may hold the commit)

### results/*: published text carries the build machine's and desktop user's paths
- severity: Low
- kind: privacy
- where: results/ (612 files, ~4670 hits "/root/exp/..."; e.g. docs/mesh-tester-ci/gates-2026-10-05.md:549 `/root/exp/qca9377-bt-hang`; docs/userspace-upstream-check-2026-10-03.md 13 hits, :542 "/root/exp/qca9377-bt-hang/tmp/u7-u6-upstream-check-2026-10-03.md"); "/home/i/" (desktop user's home): docs/ui-capture-research.md:244 `/home/i/.local/state/wireplumber/default-routes`, results/laptop-only-work-2026-11-11/headset-session/SESSION-CHECKLIST.md:77 `... /home/i/headset-kit` (35 hits); "/root/Downloads" 87 hits in 27 u29-gnome-pairing-feedback runs/*.stdout.log (container path, harmless).
- evidence: grep -E '/root/|/home/[a-z]'. MAC scan: every colon-address in these parts is AA:BB:CC:00:00:NN, 00:AA:01:..., 11:22:33:44:55:66, 00:11:22:33:44:NN, 00:01:02:03:04:05 or the emulator's BC:9A:78:56:34:11: no real-looking address. No IPv4 (non-loopback), no BSSID found.
- why it matters: low-grade identifying detail (machine layout, login name); addresses clean.
- confidence: confirmed

### mesh-tester-ci/README.md omits the directory added 2026-11-14
- severity: Low
- kind: stale
- where: docs/mesh-tester-ci/README.md:36-52 ; docs/mesh-tester-ci/instrumentation-from-cache-20261114/
- evidence: README lists contents "(listed 2026-10-28)"; grep -c instrumentation README.md = 0; the directory (README.md + 0001-scratch-hold-hci_unregister_dev-...patch) is new. Banners "Kept separately until sent" are explained away by README:7.
- confidence: confirmed

### Checked, no finding
- Links: 75 Markdown files in my parts, 0 broken relative links (a scratch script).
- userspace-upstream-check-2026-10-03.md vs issues.md U6/U7: consistent (U6 fixed in GNOME 47, 6 commits; U7 "no upstream commit fixes", later became CO-02); the doc is dated and only linked as a source.
- ui-capture.md vs tools/bt-ui-capture, scripts/bt-ui-atspi.py, prove-ui-capture.sh: subcommands, BT_UI_MAX_BYTES/KEEP (3 rotated + current = four), PW level 3, base /var/log/bt-health/ui, placeholders AA:BB:CC:00:00:NN, referenced scripts all match.
- suite-timing-2026-11-08: 57.1 s parallel run matches BRIEF §9.10 "~60 s"; "seven gates" is not in this README (BRIEF says seven in CI on 2026-10-17), no conflict.
- incident-2026-11-12-1803 (BT-17, -42 with E3, "not BT-16") and bt16-third (680c448c, -43 stock) agree with STATUS/issues; only README.md:163 lags.
- "…" elision: only in dated quote-trimming (marked) and in manifest/source-access hash prefixes ("35f9f529…", "68cf12fa3ae5…"), results/co43-*/README.md patch names `0003-…`, u29-emulator README:17 SHA-256 `53a7125948f2…`, ci-local-2026-10-10.md:41,45,372 (`d6f0c33468c3d4db…`, `[ Upstream commit 96d006ae6445… ]`).

## Follow-up: docs/issues.md 1450-2056

Scope note: lines 1450-2056 hold full sections only for U9, the U4/U1 marks, U8, U10-U20, U29, X1-X4, "On the wider claim" and "Why this class of bug goes unreported". U21-U28, U30, U31 have NO section anywhere in issues.md (only table rows at 1210-1220); U1-U7 are earlier (U5 section 1351, withdrawn, consistent with STATUS:93).

### U12 section's "Next" is already done per STATUS and the issues.md table
- severity: Medium
- kind: stale
- where: docs/issues.md:1636-1642 ; docs/STATUS.md:100 ; docs/issues.md:1201
- evidence: issues.md "Next (the contribution is a backport request): 1. Build our bluetoothd from 5.72-0ubuntu5.8's source ... with the BT-7 fixes and `a14d59725`. 2. The operator installs it ..."; STATUS:100 "built (2026-10-31): `5.72-0ubuntu5.9~co03.1` is 5.8's source with the BT-7 fixes, `a14d59725` and its companion `664a5d3785a1`. In the VMs the trigger lost A2DP 70/70 before and 0/70 after".
- why it matters: reader of the full section sees step 1 as open; also the section never names the companion commit 664a5d3785a1 and says "CO-03's bluetoothd ... awaiting install" only at :1634.
- confidence: confirmed

### U8 section ends "that test is next"; later rows say it was answered (and STATUS:96 conflicts with STATUS:177)
- severity: Medium
- kind: stale
- where: docs/issues.md:1485-1486 ; docs/issues.md:1197 ; docs/STATUS.md:96 ; docs/STATUS.md:177
- evidence: issues.md:1486 "U8 is earbud-specific unless the earbuds also go silent on E3 — that test is next."; issues.md:1197 "2026-11-01: no fault on the host side of the HCI boundary"; STATUS:177 "U8: the earbuds receive 100 % CRC-valid mSBC with signal, so the silence is on their side"; STATUS:96 still "lead; ... a btusb debug patch is written, installable only after trial E3 #1 closes" (E3 is retired per briefing).
- why it matters: the same item is "open lead", "test next" and "answered" in three places; the STATUS row is the stale one, the issues.md section sits above the row that supersedes it.
- confidence: confirmed

### U13 GNOME-report owner: STATUS says CO-27, CO-42 covers it, issues.md names neither
- severity: Medium
- kind: contradiction
- where: docs/STATUS.md:101 ; docs/issues.md:1649-1672 (U13 owners "Three parts, three owners", item 3) ; contributions/CO-42-gnome-bluetooth-silent-pairing-failure/README.md:1,5-7 ; contributions/README.md:72,98
- evidence: STATUS:101 "next a BlueZ patch candidate (Flags presence) and a GNOME report for the silent failure (`contributions/CO-27-le-only-pairing-u13/`)"; CO-42 title "gnome-bluetooth: a failed setup shows the user nothing (U29, U13)" ("AuthenticationFailed (U13) ... give nothing at all", "comment drafted, local only", issue #18 and MR !137 exist); issues.md U13 item 3 says only "Read in source 2026-11-07 (U29): ... //FIXME show an error?" and issues.md has no CO-27 or CO-42 id in the U13 section (the only CO ids in 1450-2056 are CO-02/03/30/31).
- why it matters: STATUS tells a reader a new GNOME report is planned under CO-27; the real owner is CO-42, which is a comment on existing #18/!137, not a new report.
- confidence: confirmed

### U29: STATUS lists CO-39/40/41/42; the issues.md section names none
- severity: Low
- kind: contradiction
- where: docs/STATUS.md:117 ; docs/issues.md:1899-1951 (Owners and Next paragraphs) ; contributions/README.md:95-98
- evidence: STATUS:117 carries CO-39, CO-40, CO-41, CO-42; issues.md U29 "Next: for the silent setup failure, not a new report: gnome-bluetooth #18 ... and MR !137" and "Owners: gnome-bluetooth ...; BlueZ ..." with no CO id; CO-39 ("patch written, validation in progress, nothing sent"), CO-40 ("tested in QEMU, not filed"), CO-41 ("send package ready 2026-11-14") exist only in contributions/README.md. Details otherwise agree (a6ac17f0e393 in 5.78, 10/10 vs 10/10, 153.9 s, 30 s).
- confidence: confirmed

### Counts in STATUS:177 reconcile with the mining output; U12's "nine" is "within 1 s" subset of 11
- severity: Low
- kind: other
- where: docs/STATUS.md:177 ; docs/issues.md:1201,1203,1208 ; results/laptop-only-work-2026-11-11/recordings-mining/results/u12.txt, u14.txt, u19.txt
- evidence: u12.txt has 11 lines; 9 have "switch-to-headset within 1 s: True" (the "nine occurrences"), 2 (11-06 15:54, 11-07 09:41) are False; 9 minus 10-19 and 10-31 = "seven not recorded before"; entries on 11-07, 11-08, 11-09 = "three after 11-02" (11-07 09:41 and 11-06 are False; 11-07 20:19, 11-08, 11-09 are True). u14.txt "total 87"; u19.txt "events: 325". STATUS:177, issues.md:1201/1203/1208 agree. But the U12 section (1583-1647) records only three occurrences (10-19, 10-31, 11-13) and never mentions the earlier 10-11, 10-14, 10-17, 10-27 or the 11-07..11-09 events, and calls 10-19 the first ("confirmed ... 2026-10-19"); u12.txt shows 10-11 23:01, 10-14, 10-17 earlier, so "seven not recorded" applies to all of them except two.
- why it matters: numbers are consistent; the section's occurrence history (3) vs the register's (9 + 11-13 = 10) differs and no sentence reconciles them. No "87"/"325" number appears in the sections themselves.
- confidence: confirmed

### U10: STATUS row omits CO-08 research result; section "Next" 1-3 unchanged
- severity: Low
- kind: stale
- where: docs/STATUS.md:98 ; docs/issues.md:1487-1518 (Next) ; contributions/README.md:53
- evidence: contributions/README.md:53 CO-08 "evidence re-read ...: every SBC-XQ test sound was single-channel; the decisive test is designed"; issues.md:1487+ "Real signal was sent only during the Settings test sounds ... (858 Dual Channel frames)"; STATUS:98 "real signal sent on SBC-XQ only for the Settings test sounds", state "observed", next steps = same three.
- why it matters: the "858 Dual Channel frames" and the later "single-channel" reading are not reconciled in the U10 text.
- confidence: likely (did not open CO-08 dossier)

### "On the wider claim" contradicts README's current account of the cause
- severity: Medium
- kind: contradiction
- where: docs/issues.md:2012-2035 ; README.md:210-211 ; docs/issues.md:2037-2060
- evidence: issues.md:2020-2022 "Windows drives this controller through the same silicon without failure, so hardware alone is not a sufficient explanation. It may still be a controller or firmware defect that only Linux's command sequence reaches." and :2031-2033 "our own evidence points at the SCO and isochronous path, those converge". README:210-211 "Windows loads the controller's firmware, which is what the missing entry withheld on Linux" (BT-1 = missing btusb table entry, fixed by dc16388d45ec). Next section :2043-2045 "The only fix is a cold power-off" and "roughly fifteen purpose-built tools" (bin/ + tools/ hold 52 files). No status/date label on either section; written 2026-09 (cited by reviews/2026-09-17T2251Z-front-door-review.md:239).
- why it matters: the section still argues from "Windows works, so maybe SCO/firmware" while the settled finding is that Linux never loaded the firmware; a reader would act on the old cause. Android/Fluoride/PCM-I2S statements are unsourced in the repo.
- confidence: confirmed

### Evidence paths outside the repository, and identifier elisions in 1450-2056
- severity: Low
- kind: rule-vs-practice
- [wording of the P-01 class omitted]
- evidence: archive/incidents/* paths are mostly marked ("on this machine only" at 1730, 1874; "local" at 1710, 1969 tmp/cd-gaps); tmp/ and archive/ are git-ignored (.gitignore:22,43) but 1752 names tmp/u16-dup-check/cmp.sh as the verification of a "textually identical" claim with no note it is untracked; 1913 gives an absolute /root/exp path (also privacy-low). Elisions: "53a71259…", "4661cc83…" (hash prefixes in a project that writes identifiers in full), and "archive/…/journal-user-0755-0812.txt" (path elided; the dir 20261024-shure-mic-meter-and-vgm is named at 1874).
- confidence: confirmed

### Order/numbering in the register
- severity: Low
- kind: register-integrity
- where: docs/issues.md:1450-1487 ; 1194 ; 1210-1220
- evidence: the section list runs U9, "U4/U1 operator marks", U8, U10, U11, ... (U8 after U9); U5 appears as a table row (1194) and a section (1351), withdrawn in both and in STATUS:93; every STATUS row U1-U31 and X1-X4 has an issues.md table row (all present), but U21-U28, U30, U31 have no section (their detail lives in CO dossiers/results), which issues.md does not say. STATUS and issues agree on U22/CO-23, U23-U27/CO-37, U24 "fixed upstream by 7e3212fa233e", U17/CO-02,30,31, U12/CO-03 (apart from the items above).
- confidence: confirmed

### No disagreement found on
X1 (!368/!369, #893/#894, dates 2026-11-07) between issues.md:1952-1971, STATUS:120 and README; X2-X4 (master 2d30ce9b, line refs :426-432, :917/924/931, :958, :922, :854, :714) match STATUS:121-123; U13 (13 attempts, 06:20:39 to 06:23:10), U17 (130 µs, 5 s, 06:12:22/06:12:47), U19 (08:04:59, 08:08:42), U20 (08:04:05 to 08:04:43) agree between sections and STATUS rows.

---

# Part: comms-reviews

## comms-reviews findings

NOTE on method: the repo clone holds only 50 commits (git rev-list --count HEAD = 50), so almost every commit id quoted in reviews/README.md, comms/ and BRIEF (e.g. 456daba, d016249, 400c5df, eb2e6d6, 6ada2a1, b735297, 3e59ad0, 7fb09fe) gives "fatal: Not a valid object name" under `git cat-file -t`. I therefore report commit-id absence only once, as needs-check, and not per row.

### reviews/README.md lists about 60 of the 107 review files only partly: ~58 files are in no table
- severity: Medium
- kind: register-integrity
- where: reviews/README.md:44-98 (Reports table) vs the directory
- evidence: script (python re over README links/mentions vs os.listdir) gives no linked-but-missing file, but these exist and are named nowhere in README.md: 2026-09-19T2100Z-first-reviewer-followup-kernel-mgmt-status.md; 2026-09-20T0200Z-deep-review-followup-verbatim.md; 2026-09-26-source-review-report.md; 2026-09-26-source-review-followup.md; 2026-09-27-research-gnome-settings.md; 2026-09-27-research-pipewire-wireplumber.md; 2026-10-13T0200Z-u11-outside-research{,-text,-web-sources}.md; 2026-11-12T1508Z-upstream-contributions-status.md; 2026-11-12T1537Z-all-contributions-explained.md; 2026-11-13T0003Z-bt17-source-investigation-task.md; 2026-11-13T0120Z-registers-and-contributions-status.md; five 2026-11-13T02xx-04xxZ bt17-source-investigation-reviewer-{1,2,3,6,7}-verbatim.md; 2026-11-13T1100Z-bt17-patches-intermediate-review.md; 2026-11-13T1530Z/1600Z/1700Z bt17-patches-review*-verbatim (7 files); 2026-11-13T1600Z-bt17-patches-reviews-checks-and-plan.md; five 2026-11-13T1740Z-bt17-open-work-answer-*-verbatim.md; 2026-11-13T1740Z-bt17-open-work-for-outside-reviewers.md; 2026-11-13T1750Z-bt17-open-work-answers-checks.md; 2026-11-14T0300Z-kernel-patches-ready-to-send-for-outside-review.md + five reviewer-verbatim; 2026-11-14T1300Z-bt17-open-work-reviewer-3-checks.md; 2026-11-14T1400Z-kernel-patches-review-answers-checks.md; EXTERNAL-SOURCES-TASK.md; coverage-of-review-full-project-code-review-20260813-111346.md; elaboration-of-review-results-20260813-165243.md; fixes-full-project-code-review-20260813-123326.md; verification-of-review-full-project-code-review-20260813-111346.md; review-full-project-code-review-20260813-111346.md; review-comprehensive-code-review-20261019-014718.md; review-reaction-plan-20261019-045758.md; project-completion-plan-20261019-045758.md; test-suite-synchronization-plan-20261019-045758.md; review-entry-level-ingestion-second-maintainer-20261019-223627.md; report-test-suite-work-for-main-branch-maintainer-20261019-110000{,-corrected}.md; report-uncovered-code-for-outside-reviewers-20261108-052325.md; review-comprehensive-project-consistency-review-20261115-005742.md (untracked, git status ??). The last Reports row is 2026-11-07T20:00Z; nothing from 11-12 .. 11-14 and nothing of the whole BT-17 / kernel-patch review rounds is listed. README.md:98 itself ("the reviews register's backfill open", in the 2026-10-28 row) admits it.
- why it matters: README.md:1-2 and :105-106 call the register "the current truth" and the Adding-a-report rule says "add a row to Reports"; a reader cannot find the BT-17 and 11-13/11-14 review rounds or the 2026-10-19 plans from it. The 11-13 and 11-14 checked files are the ones BRIEF's newest hand-off depends on.
- confidence: confirmed

### Three-plus naming schemes; the stated convention covers one; README admits one exception, not the rest
- severity: Low
- kind: rule-vs-practice
- where: reviews/README.md:18-33 (convention) and :45-46 / :81 (`2026-09-13-foundation-file-consistency.md` noted as exception); files
- evidence: README: "named `<UTC timestamp>-<topic>.md`" and "Filename lacks the UTC time the convention requires — recorded, not renamed" (only for 2026-09-13). Present in the directory without UTC time: 2026-09-26-source-review-followup.md, 2026-09-26-source-review-report.md, 2026-09-27-research-gnome-settings.md, 2026-09-27-research-pipewire-wireplumber.md. Scheme 3 (review-<topic>-YYYYMMDD-HHMMSS / <topic>-YYYYMMDD-HHMMSS.md, local-time stamps?): 14 files, e.g. review-full-project-code-review-20260813-111346.md, project-completion-plan-20261019-045758.md, report-uncovered-code-for-outside-reviewers-20261108-052325.md; also 2 task files with no date (EXTERNAL-SOURCES-TASK.md, SOURCE-REVIEW-TASK.md) and verify.sh. "-verbatim" files: 2026-09-20T0200Z-deep-review-followup-verbatim.md has no checked counterpart (the 0100Z/0000Z/2200Z ones do); the 11-07 u29-*-verbatim and 11-13/11-14 reviewer verbatims have counterparts only as the aggregated "…checks…" files, not 1:1.
- why it matters: the stated rule ("a timestamp in a filename is a promise") cannot be checked mechanically; sorting by name does not give chronology (scheme 3 files sort after everything).
- confidence: confirmed (whether scheme-3 stamps are UTC or local not checked: needs-check)

### README "Branches" paragraph: review/<timestamp> branches do not exist in the repository / were retired
- severity: Medium
- kind: stale
- where: README.md:278-279 ("`review/<UTC timestamp>` holds one assessment (report first, then the reaction on `review/<timestamp>-fixes`)"); reviews/README.md:63 (branch `review/2026-08-15T1752Z-fixes`), :326 (branch `review/2026-09-17T2251Z-fixes`); comms/2026-11-13T0100Z...everyone.md ("Once this branch is green ... every branch except `main` and `tests/test-suite` is deleted from the public repository")
- why it matters: a reader told to look at `review/<timestamp>-fixes` for the reaction finds nothing; README's branch map is out of date after the 11-13 retirement. 
- confidence: likely (remote state not checked; local clone has no such branches)

### Register rows marked open whose own verify command now passes (R2-21, R2-25) and R2-64/65 open vs DR-07 fixed
- severity: Medium
- kind: register-integrity
- where: reviews/README.md:310 (R2-21 open), :311 (R2-25 open), :312 (R2-64 / R2-65 open) vs :392 (DR-07 "fixed in the checkout")
- evidence: R2-21 "open | — | `grep -c 'EX-04' docs/issues.md` → ≥1": I ran that grep, result 7 (docs/issues.md:128,139,594,... mention EX-04x; entry for BT-5 cites EX-043). R2-25 "open | `grep -c '2.19' docs/bug-report.md` → ≥1": result 2 (and docs/bug-report.md:3-9 is now marked "Historical record (2026-10-03)... never sent"). R2-64/R2-65 (BL-03/BL-08) row: "open | `grep -c 'ls-files' tools/bt-trial` → ≥1; `grep -c hci_alive tools/bt-trial` → 0 in `autostop)`"; ls-files count is 2; but the DR table says "DR-07 | `bt-trial autostop` probes at shutdown (BL-08, R2-65); `abort` deletes tracked evidence (BL-03, R2-64) ... | **fixed in the checkout** + tests" and DRF F5 "abort ... fixed". tools/bt-trial:436-446 still contains a comment about hci_alive and `if hci_alive; then exec "$0" ok` (line 446) so the second check as written cannot read 0 (needs-check whether that is the non-passive path).
- why it matters: the README states "This table is the current truth" and "Each row carries a command that decides its own status"; for these rows the command and the status disagree, and two rows of the same register (R2-64/65 open, DR-07 fixed) describe the same defect with opposite status.
- confidence: confirmed for R2-21/R2-25 (grep run); likely for R2-64/65

### Register CO-nn block (CO-01..CO-10) shows states contradicted by contributions/README.md, and reuses ids with different meaning
- severity: Medium
- kind: stale
- where: reviews/README.md:443-453 (CO table; header at :438-441 says "Superseded on 2026-10-21 ... kept as it stood that day"), contributions/README.md:46-55
- evidence: reviews CO-09 "open — watch" vs contributions/README.md:54 "**done (2026-11-14): the laptop runs `7.0.0-43` with the stock btusb**"; CO-10 "**blocked** — operator's decision; due 2026-10-22 07:53 UTC" vs :55 "**sent** 2026-10-21 03:05 UTC"; CO-02 here = "Re-read `U7` against the kernel's SCO connect path" vs contributions CO-02 = patch series "A new SCO connect reuses the closing link" (sent 2026-10-27), CO-04 here = "Test Igor Putko's mesh patch 14888791" vs contributions CO-04 = "syzbot's mesh_send_sync use-after-free: our independent fix". Register preamble (reviews/README.md:104-105) "This table is the current truth; the report is history."
- why it matters: the table is labelled superseded, so partly excused, but it still sits in the section the README calls current truth, and the ids CO-02/CO-04 mean different things in the two places; BRIEF uses the contributions meaning.
- confidence: confirmed

### Ids BRIEF cites: all defined somewhere; only R2-13 and BL-09 are not in the register
- severity: Low
- kind: other
- where: BRIEF.md:172 (R2-13), :669 (BL-09)
- evidence: R2-58, R2-100, R2-105, UT-12, DR-01..DR-04, CB-02 are defined in reviews/README.md (rows at lines 308,307,313,117,386-389,431). R2-13 is only in reviews/2026-09-16T0420Z-comprehensive-code-review.md:148 and 2026-09-19T1500Z-r2-disposition.md:45 (register says at :299 "The per-finding list is the report itself", acceptable). BL-09 is defined in docs/investigation-plan.md:733, and no reader is told that from BRIEF.md:669. No duplicate ids in the register (checked by script).
- why it matters: informational; no dangling id found.
- confidence: confirmed

### ci-local's eb2e6d6/6ada2a1: BRIEF and the 11-13 note say "not on main"; the 10-18 note says they landed, and their files are on main
- severity: High
- kind: contradiction
- where: BRIEF.md:219-220 ("land or drop `ci/upstream-ci-local`'s `eb2e6d6`/`6ada2a1`"); comms/2026-11-13T0100Z-from-test-suite-maintainer-to-everyone.md ("`ci/upstream-ci-local`. Its two commits are not on `main`: `eb2e6d6` ... and `6ada2a1` ... Whoever wants them can have them back on request"); comms/2026-10-18T1532Z-from-main-branch-maintainer-to-test-suite-maintainer.md ("Also landed: the ci-local line's `eb2e6d6` and `6ada2a1`, with today's stale pointers folded in."); docs/STATUS.md:403 (survey of 10-18, earlier that day, lists them as "Not on `main`, fit to land")
- evidence: the content of both commits is in the tree: comms/2026-10-14T0224Z-from-ci-local-maintainer-to-everyone.md and comms/2026-10-16T1343Z-from-ci-local-maintainer-to-main-branch-maintainer.md are tracked on main (`git ls-files comms | grep ci-local` -> 2), and results/ci-local-2026-10-10/send-2026-10-13-a1-a2dp-sendcheck and .../send-2026-10-13-a2-vla-sendcheck exist (the 10-16 letter names them as the dirs `6ada2a1` carries). Cherry-picked ids differ from eb2e6d6/6ada2a1 (and neither id resolves here), so a patch-id/ancestor check on the branch ids reports "not on main" while the work is.
- why it matters: BRIEF §hand-off puts a decision "land or drop" in front of the operator for work already landed; the 11-13 note's retirement of the branch is described as losing commits that main has, and its list "Eight branches already wholly on main" vs this one is built on the same ancestry check that the 11-13 note itself says (hides cherry-picked copies) gives false "missing" results.
- confidence: confirmed for the file presence and the 10-18 sentence; the ids themselves needs-check (history absent in this clone)

### BRIEF says the 11-13 note holds "the command" to delete 16 old remote branches; the note contains no command and lists 16 differently
- severity: High
- kind: contradiction
- where: BRIEF.md:219-220 ("delete the 16 old remote branches (the command is in the test-suite maintainer's 11-13 note)"); comms/2026-11-13T0100Z-from-test-suite-maintainer-to-everyone.md ("Retired from the public repository")
- evidence: `cat` of the note: it says "Once this branch is green in CI, every branch except `main` and `tests/test-suite` is deleted from the public repository" in the passive voice, lists the branches (7 test-suite-side + 8 "wholly on main" + `ci/upstream-ci-local` = 16) and the backup naming ("each one under its own name plus `-backup-` and the date and time"), but no `git push --delete` or `gh api` command anywhere (grep -n "push\|delete" shows only prose). It also says "Once this branch is green in CI" - the note does not say whether the deletion was done; BRIEF treats it as still the operator's. The note's second statement "every branch except main and tests/test-suite is deleted" would also remove the review/* and other branches, not only those 16, with no list of them. Also: the note's list contains `tests/deploy-rehearsal-checks-awaiting-main-fixes` and `ci/deploy-rehearsal-*` but it is "7" test-suite branches while the sub-bullets name 3 + 4 = 7: consistent.
- why it matters: an operator following BRIEF cannot find the command; if executed per the prose "every branch except two" it deletes more than the 16 BRIEF counts.
- confidence: confirmed (no command in the note); whether the deletion was already done: needs-check (this clone has no remote branches besides main)

### BRIEF §9.2's "six tasks" are not the six tasks of the source message; "device survey" appears in neither source
- severity: Medium
- kind: contradiction
- where: BRIEF.md:668-673 ("Six tasks delegated to the Test Branch Maintainer (source review, instrumented `btusb` logging of the chosen `new_alts`, bug-report audit, `BL-09`, `bt-crash` tests, device survey)"); comms/2026-10-19T0504Z-from-test-suite-maintainer-to-main-branch-maintainer.md:572-584 (§10.5 table, same six); comms/2026-08-22T1215Z-from-main-branch-maintainer-to-test-suite-maintainer.md:54 ("## 3. Six tasks") and :75, :92 etc.; comms/2026-08-23T0930Z-from-main-branch-maintainer-to-test-suite-maintainer.md:52,81
- evidence: 08-22T1215Z "Six tasks" are 3.1 bug-report read, 3.2 `BL-09`, 3.3 `bt-crash` tests, 3.4 `bt-snapshot` double-zero, 3.5 "The source-investigation branch", 3.6 the `bluetoothd` BuildID. 08-23T0930Z adds two more: "## 3. An all-layers source review" and "### 4.1 An instrumented `btusb` that logs the alt setting it CHOOSES". BRIEF/0504Z §10.5 merge parts of both into "six" and add a "device survey" that `grep -i survey` finds in none of comms/2026-08-22*, 08-23*, 08-24*. 0504Z §10.5 itself says "device survey | no record | nothing in `git log`, `comms/`, `reviews/` or `docs/`". Tasks 3.4, 3.5, 3.6 of the original six have no recorded state in §10.5 or BRIEF.
- why it matters: BRIEF §9.2 says the survey "has no record of its scope on either side, so it stays open" - the likelier cause is that the list was mis-assembled (survey = one of 3.4/3.5/3.6 or a mislabelled item), leaving three real delegated tasks unaccounted for. The statement of the six being "done/moot/dropped" otherwise matches §10.5 (source review, BL-09 and bt-crash done, new_alts dropped, survey open) - that part of BRIEF is a faithful copy.
- confidence: confirmed that the lists differ; that no "survey" task exists: confirmed by grep of comms 08-22..08-24 only (not of all docs)

### BRIEF §9.2 and comms cite file names with "…" elision after 2026-09-18
- severity: Low
- kind: rule-vs-practice
- where: BRIEF.md:670 ("`comms/2026-10-19T0504Z-…` §10.5"); docs/STATUS.md:402 ("`comms/2026-10-19T0601Z-…`"); comms/2026-10-19T0504Z...md:575-576 ("`comms/2026-08-22T1106Z…`", "`comms/2026-08-24T0330Z…`", "`reviews/2026-08-17T0022Z-source-investigation-…`"); comms/2026-10-21T0225Z-...md ("`2026-10-21T0204Z-…`"); comms/2026-08-23T0930Z...md:3 ("`comms/2026-08-22T1217Z-…`" - older than 09-18, listed only for pattern)
- evidence: project rule (briefing): identifiers written in full, no "…" elision of paths after 2026-09-18. Quoted above; the dated-after-09-18 ones are BRIEF (11-14), STATUS, 10-19T0504Z, 10-21T0225Z. A complete grep: `grep -n "…" comms/2026-1*.md | grep "comms/\|T[0-9]\{4\}Z-\?…"`.
- why it matters: breaks the rule the project states; the targets are unique, so low impact, but 0504Z §10.5 cites its own evidence by elided names (the two checked ones exist: 2026-08-22T1106Z-from-test-suite..., 2026-08-24T0330Z-from-test-suite...).
- confidence: confirmed

### BRIEF §9.2 still calls the device survey "open"; the operator's decision to drop it is recorded in comms the same day
- severity: Medium
- kind: stale
- where: BRIEF.md:672-674 ("the device survey has no record of its scope on either side, so it stays open until the operator says what it was or drops it"); comms/2026-10-19T0601Z-from-test-suite-maintainer-to-main-branch-maintainer.md ("The operator accepted your four recommendations: the `--columns` fix yes and first; the device survey dropped; the access audit in a workflow of its own; ...")
- evidence: 0601Z (06:01Z, "The operator's aim") records "the device survey dropped"; 0541Z (05:41Z) said "it stays open until the operator names it or drops it" - BRIEF copies the earlier 0541Z state although it cites 0504Z/10-19; `grep -n -i survey BRIEF.md` -> only :670/:673 (and an unrelated line 460).
- why it matters: BRIEF §9 is the hand-off list; it presents as an open decision something already decided (dropped).
- confidence: confirmed

### BRIEF §8a says each rule's instance and cost are in the two lessons files; most of the rules have none there (the files end 2026-08-27)
- severity: Medium
- kind: broken-reference
- where: BRIEF.md:562-565 ("the instance that taught it and what it cost are in lessons/2026-08-22T1101Z-test-suite-maintainer.md and lessons/2026-08-27T1200Z-test-suite-maintainer.md"), rules at BRIEF.md:567-660; lessons/README.md:36-43 ("an entry missing the second [the instance] is not a lesson"); the lessons files
- evidence: both files exist. Instances present in them: the "must be observed to fail" family (08-22 §4 "five times in ten days", 08-27 §10 "A sixth check that could not fail"), "ENUMERATED == 0 is a refusal. CHECKED == 0 is a result" (08-22 §6), bounded search "reporting its bound" (08-27 §2, a `--depth 50` clone, 29,242 commits), the 76 ms anchor (08-27 §9), the Signed-off-by/HACKING measured-vs-assumed trailer (08-27 §7). NOT in either file (grep for the key terms returns 0): "312 calls" and "20 fake trial lines" (they are in comms/2026-09-29T0400Z...:19-22 and tests/README.md:74), "141 commits ... 401" (comms/2026-09-18T0630Z...:14 "401 of 401 ... 141 was a ..."; the lessons file's instance is a different one, 29,242), "the seventh was `rg || true`" and "the eighth (2026-09-24)" (comms/2026-09-24T0923Z...:85 "an eighth check that could not fail"; the lessons files stop at "sixth"), mawk 1.3.4 and the five sanitiser assertions, `degraded`/is-system-running (2026-10-16), the silent PATH-guard stubs (10-16), "A deploy is an upgrade" (10-17), "A section stands alone" and "Rehearse with the stimulus present" (10-18), "Ids on main are main's". The numbers BRIEF quotes agree with the comms files (312, 20, 141/401, eighth on 09-24, 76 ms with its 09-18 correction in the lessons file) - the disagreement is only about where the instance lives. 11 of the 17 §8a rules (by my count) have no instance in the cited lessons files; the date line "Written 2026-09-24 ... updated 2026-10-17" cannot be matched by files dated 08-22/08-27.
- why it matters: the project's own rule (lessons/README.md) says a rule with no instance is an opinion; BRIEF sends the reader to documents that cannot contain the instances (the lessons are not extended after 08-27, though the README says one per milestone). 
- confidence: confirmed (greps over both files and comms)

### lessons/2026-08-27T1200Z... was edited after its timestamp (two "Corrected 2026-09-18" blocks)
- severity: Low
- kind: rule-vs-practice
- where: lessons/2026-08-27T1200Z-test-suite-maintainer.md:276, :344; reviews/README.md:18-30 (the "never edited after it is written" convention that lessons/README.md:21-23 says it shares: "Same `YYYY-MM-DDTHHMMZ` shape as `reviews/`")
- evidence: ":276 ⚠️ **Corrected 2026-09-18.** This item originally said ..." and ":344 > ⚠️ **Corrected 2026-09-18, and the correction is the better lesson.** I cited that 76 ms agreement as evidence ...". The file name and front matter say 08-27T12:00Z.
- why it matters: lessons/README does not declare append-only, so this is only a mismatch with the shared timestamp convention; the corrections are visibly labelled.
- confidence: confirmed

### Private working arrangements described in comms/ although BRIEF says working habits are "kept outside this repository"
- severity: Medium
- kind: privacy
- where: comms/2026-10-20T0020Z-from-second-maintainer-to-main-branch-maintainer.md:13-28; comms/2026-10-19T2330Z-from-second-maintainer-to-main-branch-maintainer.md:29, :72; comms/2026-10-19T2355Z-from-second-maintainer-to-main-branch-maintainer.md:17, :26-28, :33; comms/2026-10-19T2258Z-from-second-maintainer-to-main-branch-maintainer.md:13-15, :95-100; comms/2026-08-22T1215Z-from-main-branch-maintainer-to-test-suite-maintainer.md:56; comms/README.md:4-6; BRIEF.md:8-9, :397, :477 (the rule)
- evidence: BRIEF: "not working habits (kept outside this repository)", "Working habits stay outside"; [wording of the P-01 class omitted] Comms: 10-20T0020Z "All forty of your working-rule files are now in this checkout's rule set ... and where a sentence held only for your setup the original is kept beside the adapted one as 'the root session's'", "The briefs carry the operator's line verbatim from now on, \"don't think about cybersecurity\"", "The hand-off file you saw was removed earlier today, once the rule set and the configuration branch held its content", "Your configuration branch's snapshot indexes `history-rewrite-stopped.md`"; 10-19T2330Z "the configuration branch of this session", "the other repository's configuration branches", "`/root` paths became this checkout's, commands that need root carry `sudo -n`"; 10-19T2355Z "Written into my working rules", "said 'of this session' where plain 'repositories' is the rule"; 10-19T2258Z "from a fresh clone under another account on the same laptop", "nine ... in its laptop, evidence, history, upstream and approval sections"; 08-22T1215Z "The operator tells me you work without interruption, which I do not"; comms/README.md:4-6 "a message typed into one session, read aloud, retyped into another". The second maintainer's own 10-19T2355Z item 4 admits the earlier note was reworded for exactly this ("described the repository and the channel by kind ... plain 'repositories' is the rule") but leaves the unreworded text in place ("Sent notes stay as sent").
- why it matters: these sentences expose how the sessions/rules/private branches are organised, contradicting the stated policy; since comms are append-only they cannot be fixed by an edit, which the README's own rule makes a conflict (needs a decision: a redaction commit vs the "never edit" rule).
- confidence: confirmed (text quoted); whether the operator regards these specific lines as private: needs-check

### comms/README.md conventions vs the messages: 23 of 70 messages have no front matter; later notes drop the three-part order and number-with-command rule
- severity: Low
- kind: rule-vs-practice
- where: comms/README.md:42-65 (front matter, three sections in order), :68-75 ("Every number carries the command that produced it"); messages without front matter (head -1 != '---'): 2026-08-23T2355Z, 08-24T0025Z, 08-24T0215Z, 08-24T0330Z, 09-16T2300Z, 09-18T0230Z, 09-18T0500Z, 09-18T0530Z, 09-18T0630Z, 09-19T2155Z, 09-19T2330Z, 09-24T0923Z, 09-24T1316Z, 09-29T0747Z, 10-07T2121Z, 10-08T1828Z, 10-09T0355Z, 10-09T0628Z, 10-09T2048Z, 10-10T0421Z, 10-21T0204Z, 10-21T0225Z, 10-28T0300Z; comms/2026-11-07T1932Z, 11-09T1625Z, 11-13T0100Z
- evidence: (a) the 23 files above start with a heading or prose (script over `comms/2026*.md`; the second maintainer's 10-19T2258Z §8 counts "20 comms without front matter", it is 23 now, and the three newest main-branch notes 10-21T0204Z, 10-21T0225Z, 10-28T0300Z, i.e. after that count, are in the list). (b) 11-07T1932Z, 11-09T1625Z, 11-13T0100Z have front matter but no "What I changed / What I found in your work / What I could not settle" order, and state figures with no command: "1103 checks, 56 s in parallel on 4 cores", "bash coverage 86%", "awk 97%, python 89%", "161 coverable lines at 0%", "the parallel suite 57 s on 4 cores ... 46 units, about 200 s of work", "A sample of eight commits ... found the same subject and the same change each time", "`git cherry` counted all 99 originals as missing" (11-07 marks only "[verified on `7fb09fe`]"). (c) 11-09T1625Z front matter `from:     test-suite maintainer` (space) vs the role name `test-suite-maintainer` in README.md:22 and every other file. (d) README.md:20-28 lists "review branch maintainer" as a writer; no message is from that role (ls comms | grep review -> none).
- why it matters: mild; the README says "Nothing here is a gate", but the specific rule "every number carries the command" is the one the README says cost two public withdrawals.
- confidence: confirmed

### BRIEF "Who works where" still names the two test-suite branches and a merge workflow that the 11-13 note retired
- severity: Medium
- kind: stale
- where: BRIEF.md:148 ("The test-suite maintainer works on `tests/unit-testing-introduction` and `tests/unit-testing-introduction-ready-for-main`, and merges `main` into them on their side (`comms/`)"); BRIEF.md:147 ("`ci/upstream-ci-local` were landed on `main` that day [10-13]") vs BRIEF.md:219-220; comms/2026-11-13T0100Z-from-test-suite-maintainer-to-everyone.md ("`tests/test-suite` (from now on the test-suite side's only branch)", "When `main` moves, the branch is rebased onto it, commit by commit")
- evidence: BRIEF line 148 is in the same file (last updated 2026-11-14, :151) as the §hand-off lines 219-220 which say the 16 old branches (incl. both of those names) are to be deleted; `grep -n "tests/test-suite" BRIEF.md docs/STATUS.md README.md` -> no hit, so the branch the test-suite side now works on, and the open request that main fast-forward to it ("main: take tests/test-suite as it is ... while main is at 400c5df"), appear nowhere in BRIEF or STATUS. Also BRIEF:147 says ci/upstream-ci-local was landed 10-13 while :220 offers "land or drop" its two commits (and the 10-18T1532Z note says they landed 10-18).
- why it matters: a reader resuming from BRIEF is pointed to branches slated for deletion, and does not learn of a pending request that main take 8 commits.
- confidence: confirmed

### Addendum to the elision finding (exact lines)
- severity: Low
- kind: rule-vs-practice
- where: comms/2026-09-24T0923Z-from-test-suite-maintainer-to-main-branch-maintainer.md:22 ("`comms/2026-09-19T2155Z-…`"); comms/2026-10-19T0504Z-...md:247-248 ("`comms/2026-10-16T1528Z…`, `…T2022Z…`"); comms/2026-10-21T0225Z-...md:4 ("`2026-10-21T0204Z-…`"); BRIEF.md:670; docs/STATUS.md:398 ("`comms/2026-10-19T0601Z-…`")
- evidence: as quoted; all are file names cut with "…" in files dated after 2026-09-18 (09-24 is after the cutoff).
- confidence: confirmed

### Open requests in comms/ with no later answer or closure found (most recent first)
- severity: Medium
- kind: other
- where: see list
- evidence / list:
  1. comms/2026-11-13T0100Z...everyone.md: "main: take `tests/test-suite` as it is, commit by commit (a fast-forward while main is at `400c5df`)"; no later message; main is now at da23558 (this clone) and BRIEF does not mention the branch. Also its deletion step ("Once this branch is green in CI, every branch except `main` and `tests/test-suite` is deleted") has no recorded outcome; BRIEF treats it as the operator's.
  2. comms/2026-11-07T1932Z...everyone.md §4: three questions to main (standalone devtools scripts: suite / out of coverage / retired; should `install.sh` install `bt-journal-files` and its units; is the T1/SR1/item-11 order agreed) and one to the second maintainer (pre-push hook tests into the suite?). 11-09T1625Z "the four questions ... stand" and 11-13T0100Z "Still open" confirm no answer. (`grep -n bt-journal-files install.sh` -> no hit: the second question is still effectively "no".)
  3. comms/2026-10-19T1739Z...main-to-test-suite.md §4: T1, SR1 (in `bt-verify-install`) and the `0x043d` column, test-first, both sides; the 11-07/11-09/11-13 notes still list them as "next". Not done.
  4. comms/2026-10-19T2330Z / 2355Z / 10-20T0020Z (second -> main): which configuration branch to take the commit hooks from; "check the live `history-rewrite-stopped.md` exists and run your backup"; fixes split (main side: bin/bt-trace:129, compile-mgmt-at.sh, bt-trial verdict lines, uninstall.sh guards, verify-restored.sh:188). The only main replies afterwards (10-21T0204Z, 10-21T0225Z) are about repo-scan's address list and do not answer these. Completion of the second maintainer's §2 list is not recorded in comms (needs-check in STATUS).
  5. comms/2026-10-21T0204Z / 0225Z (main -> second): "Whether the list belongs in `devtools/`"; "Whether `repo-save`'s identity check needs the same idea" - unanswered (low).
  6. comms/2026-10-18T1532Z / 10-19T1739Z: BT-4 D-Bus rework "waits for the first trial after the deploy" - the deploy is still pending (BRIEF), so open by design.
  7. comms/2026-10-14T0224Z...ci-local: (a) the pairing-test flake rate measured on the laptop (`scripts/functional-repeat.sh`, "has never completed a run"), (b) the two bot facts needing a GitHub login (`gh run list -R bluez/bluez ...`), (c) operator decision to send A2. (c) is closed (A2 is in STATUS.md:41 as sent/applied); `grep -n "pair_bredr\|functional-repeat" BRIEF.md docs/STATUS.md` finds nothing about (a)/(b) -> needs-check.
  Closed, for completeness: 10-28T0300Z's bt-journal-files tests (11-07T1932Z "done"), 10-16T2022Z runner pinning (`.github/workflows/*.yml` use `runs-on: ubuntu-24.04`), the 0601Z log-times request (11-13T0100Z "`0b21019`: the 0601Z note's four log times, set from git log"), BRIEF §9.2's six tasks (see other finding).
- why it matters: BRIEF's "Open for the operator" list does not carry items 1-5.
- confidence: confirmed for what the messages say; "no answer" is limited to comms/, BRIEF, STATUS greps

### Register text with floors and counts that disagree with checks.yml and with itself
- severity: Low
- kind: stale
- where: reviews/README.md:202 (HC-04: "`--min 80` shell, `--min 85` awk in `checks.yml`"), :283 ("The CI floor is a ratchet below the current figure — 30 until session 3, now 65."), :170 ("`tests/run-tests` (329 invariants)"), :111/:215-219 etc. (Landed column "this commit" in HC-09, HC-10, TX-01..TX-06, R2-105)
- evidence: .github/workflows/checks.yml:230 `devtools/coverage --quiet --min 80`, :301 `devtools/awk-coverage --min 95` (HC-04's row says 85, marked done with that as its verify); README :283 says the shell floor is 65 while :202 of the same register says 80; the suite has 1100+ checks (comms/2026-11-07T1932Z "1103 checks"); "this commit" cannot be resolved by a reader (no id) in 8 lines (`grep -c "this commit" reviews/README.md` -> 8).
- why it matters: the register is described as executable truth ("run it rather than trusting the column"); these cells fail that.
- confidence: confirmed (workflow lines read)
