# Full project code review — 2026-08-13 11:13

**Scope:** every file in the repository, read start to finish (large raw evidence logs
skimmed/sampled rather than read line-by-line — noted per item below).
**Method:** manual read in dependency order — foundation documents → configuration →
installer pair → systemd units → `bin/` daemons → `tools/` → `tools/lib` → `devtools/` →
`tests/` → `evidence/`. Findings are appended per item immediately after each item is
reviewed. Severity scale: **HIGH** (wrong result / data loss / claim inverted),
**MED** (misleading output, drift between doc and code, missed cleanup),
**LOW** (nitpick, robustness, portability), **NOTE** (observation, no action required).

A consolidated findings table and overall assessment are at the end of this file.

---

## 1. Foundation documents

### 1.1 `README.md`
- **NOTE** — Unusually honest front page: it separates established facts from refuted
  hypotheses and points to `docs/issues.md` as authoritative. The self-flag at the top
  ("sections below are being rewritten") is a good pattern.
- **LOW** — The README states "**A warm reboot is often not enough** — it doesn't drop
  the M.2 power rail" (§ two-stage failure) as fact, while `docs/issues.md` BT-1 flags
  exactly this claim as an *untested assumption* (EX-017/EX-019). The README instance is
  not flagged. Since the issue register explicitly lists the places carrying the claim,
  the README should be on that list or carry the same caveat.
- **LOW** — "Repository layout" section lists `data/ baseline.tsv, logs/` — no `data/`
  directory exists in the tree (baseline lives in `evidence/baseline/`). Stale layout entry.
  It also omits `tests/`, `reviews/`-class dirs, `systemd/` is present but `tools/lib` and
  `evidence/exhibits`, `evidence/trials` are not mentioned.
- **NOTE** — The status table and the "candidate fix" section carry the corrected +0s/+11s
  framing consistently with `fix-proposal.md` §3a. Cross-checked: no contradiction found.

### 1.2 `LICENSE`
- **NOTE** — Verbatim GPL-2.0 text, 338 lines. Matches the README's license statement.
  No copyright holder line was added at the top of the file (GPLv2 template retained
  as-is); acceptable, but a `Copyright (C) 2026 <author>` line in the README or LICENSE
  header would make attribution unambiguous.

### 1.3 `HISTORY.md` (1688 lines, read fully)
- **NOTE** — Chronological record including refuted claims and the reasoning errors that
  produced them; phases 16–25 document two external review passes and the corrections.
  This file is the project's strongest asset for a future maintainer.
- **LOW** — Phase ordering wobbles: "Current state" appears between Phase 8 and Phase 9,
  and "Recurring lessons" sits between Phase 17 and Phase 18, so the file is not strictly
  chronological reading order. A one-line note at the top ("sections appended in the order
  they were written") would explain the interleaving.
- **NOTE** — Phase 5 says a review returned "14 findings, all fixed in `4c4047d`"; that
  commit does not resolve in the current history (`git cat-file -t` fails), so the
  reference is dangling — likely a pre-restructure hash. The other cited hashes checked
  (`fd24995`, `1990a45`, `96c3c90`) all resolve.

### 1.4 `docs/issues.md`
- **NOTE** — The issue register (BT-1…BT-6) with per-issue reportability is the
  authoritative current-state document, and it is internally consistent with README and
  fix-proposal on every load-bearing claim I cross-checked (two-stage model demoted,
  reset-direction unknown, desync non-causal).
- **LOW** — The "five levels a timestamp has to survive" table numbers levels 1–5 then
  adds "0 — recognition" at the bottom; the prose in `bt-phase`/`tests` refers to "the
  five-levels table" while it now has six rows. Cosmetic inconsistency.
- **NOTE** — The untested-assumption box (warm reboot / M.2 rail) lists the places the
  claim appears: "step 0, `bt-mode`, `install.sh`, `EX-005`, `docs/related-reports.md`" —
  it *misses* `README.md`, `bin/bt-hang-watchdog` (header and FATAL log text), and
  `tools/bt-diagnose` / `bt-postmortem` / `bt-status` output strings, which all still
  assert the claim unhedged (see per-file entries below).

### 1.5 `docs/investigation-plan.md`
- **NOTE** — Clear, risk-ordered plan; A0/A4 gating consistent with fix-proposal §5a and
  the pre-submission checklist.
- **LOW** — C1's risk paragraph still says `btusb_setup_qca()` "may fail **at probe**"
  while §C1's own body and fix-proposal §4 correct this to "at HCI open". One residual
  instance of the corrected claim (the correction discipline the repo itself preaches:
  grep the tree for the wrong claim). Line: "⚠ Risk, unchanged from fix-proposal §4: if
  this module is not a true ROME variant, `btusb_setup_qca()` may fail at probe…".

### 1.6 `docs/investigation.md`
- **NOTE** — Kept as an as-it-happened record with correction banners rather than
  rewritten; the corrected mechanism (hdev->reset) is prominently cross-referenced. Good.
- **LOW** — §8/§10 still carry the "~6 hour recoverable window" and the "firmware degrades
  … by Aug 10 02:46" narrative uncorrected inside the causal-chain diagram; the correction
  exists elsewhere (stage-1 duration ≠ recoverable window; stage-2 progression unobserved
  without intervention). The file is explicitly historical, so this is acceptable — but
  the causal-chain diagram in §10 is the single most-quotable artifact in the file and
  carries no inline warning box, unlike §3/§10's other corrections.
- **NOTE** — §13's metrics column list matches the actual `bt-health-snapshot` TSV header
  (verified against `bin/bt-health-snapshot`).

### 1.7 `docs/bug-report.md`
- **NOTE** — Carries a do-not-submit banner and points at the checklist; confidence
  statements are per-claim. Internally consistent with fix-proposal.
- **MED** — "The failure" section still states: "Roughly 45–66 s later it stops answering
  USB control transfers, and shortly after that it leaves the bus" — presented as the
  fault's trajectory. `docs/issues.md` (later) demotes exactly this: every 45–66 s
  observation contained our own reset, and the uncensored observations ran 72 min / 6.5 h
  with no progression. The same stale figure appears again in the "Methodological caveat"
  ("stage 1 measured at 45–66 s in every instrumented case") and in the §"suggested commit
  message" of `fix-proposal.md`. Since this document is the one intended to be mailed, the
  stale trajectory claim is the most consequential doc defect in the repo.
  *(The banner does say the report is under revision, which mitigates.)*
- **LOW** — "each requiring a full power-off" / "warm reboot… does not drop the M.2 power
  rail" stated as fact (see 1.4 — known-untested assumption, unflagged here).

### 1.8 `docs/firmware-hypothesis.md`
- **NOTE** — Clean statement of an untested hypothesis, clearly labelled. The correction
  ("hardware can still participate") is applied in place. No issues found.

### 1.9 `docs/fix-proposal.md`
- **NOTE** — The strongest technical document: mechanism verified two ways, corrections
  preserved with reasoning, A/B/C/D ladder with per-build instrumentation notes.
- **MED** — §6 "Suggested commit message" still contains: "The controller stops answering
  HCI, then ~45-66 s later stops answering USB control transfers, then leaves the bus." —
  the demoted trajectory stated as fact in the exact text proposed for `git send-email`.
  Also "a warm reset does not drop the M.2 power rail" in the same paragraph (untested
  assumption). Both would need rewording before submission; neither carries a flag here.
- **LOW** — Section numbering is disordered: §1, §2, §3, §3a, §3b, §5a, §4, §5, §6, §7, §8
  (§4 appears after §5a; there is no §5 before §5a). Harmless but confusing to cite.
- **NOTE** — §3b's title says "earlier works" and the 2026-08-12 update then heavily
  qualifies it (early reset recovered but not durably). The qualification is complete; the
  headline could mislead a skimmer but the body is correct.

### 1.10 `docs/changes-applied.md`
- **NOTE** — Blast-radius table, per-change revert instructions, and honest records of the
  two self-inflicted data losses (MaxRetentionSec, BT_TRACE_KEEP override). Verified the
  §1 file list against `install.sh`: §1 lists only the *original* 9-10 files; the later
  dated sections cover the rest of what install.sh now ships. The document is cumulative
  rather than current-state; a "files currently installed" pointer to `bt-verify-install`
  would help.
- **LOW** — §5 manual rollback list is the *original* set only (predates ~15 later tools
  and units) — correct for its date, but a reader following "Manual — the complete set"
  today would leave most of the current install behind. The heading "the complete set" is
  now false; `uninstall.sh` is the real list (which itself has gaps — see §3.2 below).

### 1.11 `docs/pre-submission-checklist.md`
- **NOTE** — The MAC-purge item documents real leaked device addresses and the
  filter-repo command to fix history — good that it exists and is honest about deferral.
- **NOTE** — §5 records the no-AI-attribution decision for this repository explicitly, and
  correctly separates it from the kernel-submission disclosure decision (DCO point is
  accurate). The legal-name/transliteration note is a thoughtful touch.
- **LOW** — The purge command's replace-text file rewrites two specific MACs; the grep
  shown to verify cleanliness excludes `^AA[:_-]BB…` and `^11:11:11` placeholders but the
  evidence tree also uses `AA:BB:CC:DD:EE:FF` and `11:11:11:11:11:01` forms *inside* line
  content (not line-start), so `grep -rhoEi … | grep -viE "^AA…"` works only because `-o`
  makes matches line-initial. Correct, but subtle enough to deserve a comment.

### 1.12 `docs/related-reports.md`
- **NOTE** — Phenotype-vs-cause discipline applied; the 203535 comparison is fair. The
  M.2-rail sentence here *is* correctly hedged ("untested inference… EX-017, EX-019").
  No issues.

### 1.13 `docs/restore-original-state.md`
- **NOTE** — §4 documents the user-global `~/.claude/settings.json` attribution change —
  i.e. the no-AI-attribution config predates this review and is an established project
  policy. §7's warning that repo deletion doesn't un-publish is correct.
- **LOW** — §2's list of what uninstall removes is stale relative to current `install.sh`
  (no mention of bt-capture, bt-usbmon, bt-dyndbg, dyndbg/journald/bluetoothd drop-ins,
  awk libs, trial machinery). The referenced `verify-restored.sh` is the enforcing tool,
  so impact is low, but the prose list is out of date.

---

## 2. Root configuration

### 2.1 `.gitignore`
- **NOTE** — Coherent with the privacy posture: raw logs, btsnoop, backups, metrics,
  `.claude/`/`.cursor/`/`.aider*` all excluded. `evidence/sessions/latest` (the symlink
  `bt-incident` creates) is correctly ignored.
- **LOW** — `data/logs/*.log` / `!data/logs/*.sanitized.log` refer to a `data/` directory
  that no longer exists (evidence moved to `evidence/baseline/`); the *sanitized* logs now
  live in `evidence/baseline/` and are committed because nothing excludes them — works,
  but the `data/` rules are dead weight and the actual rule protecting `evidence/`
  sessions from raw logs is… nothing. Raw (unsanitised) logs written into
  `evidence/sessions/` by a failed sanitiser run would be committable. The tools sanitise
  before writing, and `repo-scan` is the backstop, so this is defence-in-depth criticism,
  not a hole in the primary path.

---

## 3. Installer pair

### 3.1 `install.sh` (read fully)
- **NOTE** — Dry-run by default, `FAILED` accumulation with a real failure banner, the
  experiment-mode guard, the open-trial warning, and the counted-not-`grep -q` timeout
  guard are all consistent with the documented history. The first-install stamp logic is
  correct (write-once).
- **MED** — The **open-trial guard runs only inside the experiment-mode branch**
  (`if grep -q '^experiment' "$MODE_STAMP"` … `if [[ -e "${BT_STATE:-/run/bt-trial}/current" ]]`).
  In mitigation mode (the default), `bt-trial-auto` still opens a trial every boot, and
  `install.sh --apply` will reload btusb with **no trial warning at all** — exactly the
  contamination Phase "trial stock #2" documents. The `failed_this_boot` reload guard
  (correctly outside the mode branch) covers the has-already-failed case, but a healthy
  controller mid-trial gets reset with only the row-level `perturbed` detection in
  `bt-trial` to catch it after the fact. Given the 2026-08-13 incident, the trial-open
  check belongs outside the experiment-mode conditional.
- **LOW** — `install_file` warns "already exists — will be OVERWRITTEN" even in dry-run
  mode where nothing is overwritten (message is accurate as a prediction; fine), but the
  warning is emitted *before* `run`, so in apply mode the OVERWRITTEN warning prints even
  if the copy then fails.
- **LOW** — On `--apply` with `METRICS=0`, the `51-bluetooth-health-snapshot.rules` udev
  rule is skipped (correct) but `bt-health-snapshot-event.service` is also only installed
  under METRICS — consistent. However `bt-state`/`bt-evidence` reference
  `bt-health-snapshot.timer` in status output regardless. Cosmetic.
- **NOTE** — The `sleep 10` + Ctrl-C pattern for warnings is a deliberate "warn but do not
  refuse" choice, documented inline with the EX-016 rationale. Reasonable.

### 3.2 `uninstall.sh` (read fully) — **the main defect found in this pair**
- **HIGH** — The FILES list is a hand-written enumeration and it has drifted: it is
  **missing four artifacts that `install.sh` installs**:
  `/usr/local/bin/bt-interval`, `/usr/local/bin/bt-stage2`,
  `/usr/local/bin/bt-boot-provenance`, and `/usr/local/bin/lib/stage2.awk`.
  After `uninstall.sh --apply`, those four remain on the system while the script prints
  "Uninstall is a complete restoration" — the exact "fourth hand-written path list"
  failure class the project's own HISTORY (Phase 25 postscript) documents, recurring in
  the one script whose correctness *is* the restoration promise. (Verified by diffing
  `install_file` destinations in install.sh against the FILES array; see consolidated
  table for the diff.) `verify-restored.sh`/`repo-validate` should also be checked for
  whether they would catch this — see their entries.
- **MED** — The uninstall does not remove `/etc/systemd/system/bt-hang-watchdog.service.d/`
  drop-ins other than `10-device.conf`/`20-verbose.conf`; a `30-*.conf` or an
  `override.conf` from `systemctl edit` is intentionally surfaced by the DIRS loop
  ("still contains files not installed by this project") — good — but `install.sh` never
  writes `20-verbose.conf` either; that name comes from documentation telling the user to
  create overrides. Fine, but the asymmetric knowledge (list contains one user-created
  file name but not others) shows the list is curated by memory.
- **LOW** — `bt-mode` moves configs aside as `*.disabled`; uninstall removes the active
  names only. After `bt-mode experiment` + `uninstall.sh --apply`, the `.disabled` copies
  of the modprobe conf and udev rules survive in `/etc` (and the mode stamp is removed, so
  nothing records why). `verify-restored.sh` needs to catch this case — checked below.

---

## 4. `etc/` configuration files

### 4.1 `etc/modprobe.d/btusb-qca9377.conf`
- **NOTE** — Sets `enable_autosuspend=0` plus module-load-time dyndbg for btusb and the
  bluetooth core with the per-packet files excluded by query syntax. The header explains
  why service-time dyndbg is too late (probe already happened) — verified consistent with
  `bt-dyndbg.service` ordering. No issues.

### 4.2 `etc/systemd/bluetooth.service.d/10-debug.conf`
- **NOTE** — Standard ExecStart= reset + `-d`. Hardcodes the Ubuntu path
  `/usr/libexec/bluetooth/bluetoothd` — fine for the target distro; would break the unit
  on Fedora/Arch paths. **LOW** portability note only.

### 4.3 `etc/systemd/journald.conf.d/10-bt-investigation.conf`
- **NOTE** — 16G/20G caps with the MaxRetentionSec post-mortem embedded as a warning
  comment. Exactly right.

### 4.4 `etc/udev/rules.d/50-bluetooth-no-autosuspend.rules`
- **NOTE** — `TEST=="power/control"` guard before writing the attr; `ACTION=="add"` only.
  Correct and minimal.

### 4.5 `etc/udev/rules.d/51-bluetooth-health-snapshot.rules`
- **NOTE** — Targets the `-event` unit (provenance split) with `--no-block`. The remove
  rule matches `ENV{PRODUCT}=="13d3/3503*"` because attrs are gone on remove — correct
  technique. `install.sh`'s sed rewrites both the attr and PRODUCT forms for non-default
  devices (checked the three sed expressions cover all four lines). **LOW**: PRODUCT
  matching uses lowercase hex without leading zeros (`13d3/3503/*` form is
  `vvvv/pppp/rrrr`); for a VID like `0cf3` the PRODUCT string is `cf3/e300/...` (kernel
  strips leading zeros) — so the sed-generated remove rule for an overridden device with
  a leading-zero VID/PID would never match. Edge case, default device unaffected.

---

## 5. `systemd/` units

### 5.1 `bt-capture.service` — **NOTE** UMask/MemoryMax/root-only dir rationale inline; correct.
### 5.2 `bt-dyndbg.service` — **NOTE** sysinit ordering + ConditionPathIsReadWrite; correct.
### 5.3 `bt-hang-watchdog.service` — **NOTE** the 64M→256M MemoryMax story inline;
  deliberately does not set BT_VID/PID (documented why). Correct.
### 5.4 `bt-health-snapshot-event.service` / `bt-health-snapshot.service` — **NOTE** the
  provenance-split rationale is in the unit itself. Correct.
### 5.5 `bt-trace.service` — **NOTE** documents the KEEP override failure in place. Correct.
### 5.6 `bt-trial-auto.service` — **NOTE** `Before=bluetooth.service` + ExecStop close;
  BT_BUILD documented. Correct.
### 5.7 `bt-usbmon.service` — **NOTE** BT_USBMON_BUS fallback documented. See 6.8 for the
  script-side rotation concern.
### 5.8 `bt-health-snapshot.timer` — **NOTE** the "Persistent= is a no-op on monotonic
  timers" comment is accurate. Correct.

---

## 6. `bin/` scripts

### 6.1 `bin/bt-hang-watchdog` (read fully)
- **MED** — The header comment still carries the **superseded model**: "stage 1 … a USB
  reset RECOVERS it", "On the affected host stage 1 lasted ~6 hours before decaying to
  stage 2", and "needs a cold power-off, because a warm reboot does not drop the M.2
  power rail". All three are demoted/refuted claims (5-for-5 late resets failed; the ~6 h
  figure was re-measured; the rail claim is flagged untested in issues.md). The FATAL
  log message repeats the rail claim verbatim into the journal — which then flows into
  evidence sessions. Doc-drift inside the most load-bearing script.
- **NOTE** — The `late` classification patterns (`*hci*"tx timeout"*`) deliberately match
  the named, unnamed, and *link* timeout forms. For a watchdog trigger, over-matching is
  arguably correct (any of the three warrants attention), but it is inconsistent with the
  Phase-24 command-timeout discipline and is not commented as a deliberate choice — an
  ACL supervision timeout (`link tx timeout`) can fire on a healthy controller when a
  device walks out of range, and three of those in 60 s would reset a working controller.
  Worth an explicit comment (or the canonical pattern plus a deliberate link-timeout rule).
- **NOTE** — Window arrays, cooldown logging, `rc=2` unverifiable handling, process
  substitution (not pipe) for the journal reader, and the give-up idle loop are all
  correct and well-commented. `usbfs_reset`'s O_WRONLY-without-O_CREAT rationale is a
  nice touch.
- **LOW** — `recover()` stops `bluetooth.service` then sleeps, resets, restarts — but if
  `find_usb_dev` succeeded and the device disappears mid-recovery, the unbind/bind writes
  fail silently (`2>/dev/null`) and the function still restarts bluetooth and probes —
  acceptable, but the FATAL branch's `bt-trial hang` close is only reached on the *next*
  intervention, not this one.

### 6.2 `bin/bt-capture` (read fully)
- **NOTE** — The btsnoop monitor-format writer is byte-correct (magic, type 2001, the
  0x00E03AB44A676000 epoch offset, flags = index<<16|opcode, 24-byte record header).
  The sockaddr_hci ctypes bind workaround is documented. The userspace-receive-time
  clock caveat is documented at the write site — exemplary.
- **LOW** — `prune()` sorts by mtime at call time; the file currently being written is
  never in `files` (created after), so it cannot self-prune — correct. But on rotation
  the *just-closed* file is prunable while `keep` counts it, fine. No real issue.
- **LOW** — `recv(65536)` with no MSG_TRUNC handling: a monitor frame larger than 64 KiB
  would be silently truncated and the btsnoop record would still claim the truncated
  length (consistent lengths, so readers won't crash). HCI monitor frames can carry up to
  HCI_MAX_FRAME_SIZE (~1028) plus header, so 64 KiB is far above any real frame. Non-issue
  in practice; a comment would inoculate it.

### 6.3 `bin/bt-dyndbg` (read fully)
- **NOTE** — File-level enable then function-level suppression, with the measured
  NOISY_FUNCS list (including the four found by counting). `count_enabled`'s regex
  matches `=[a-z]+` so `=_` (disabled) is excluded — correct.
- **LOW** — `status` computes per-file totals with `grep -c "^[^ ]*$f:"` where `$f`
  contains an unescaped `.` — matches any char; harmless here since filenames are
  distinct, but `hci_core.c` also matches nothing else in practice. Nit.

### 6.4 `bin/bt-evidence` (read fully)
- **MED** — The MANIFEST counters use the **stale patterns** the project fixed elsewhere:
  `tx_timeouts_in_window=$(count 'tx timeout' …)` (bare form — conflates command and link
  timeouts) and `wd_interventions=$(count 'intervening' …)` (misses `EARLY intervention:`
  — the exact six-call-site defect Phase 22 documents as fixed). The snapshot_state
  function ten lines above uses the *corrected* intervention pattern, so the file
  disagrees with itself. Manifest counters for early-mode sessions under-report.
  *(Cross-checked against `tests/run-tests` — see §9: the tx-timeout spelling invariant
  scans for `grep`-with-`tx timeout` variants; whether these `count` calls are exempted
  needs the test text — recorded there.)*
- **LOW** — `cmd)` records `${PIPESTATUS[0]}` after a `"$@" 2>&1 | sed` pipeline —
  correct. The stray `tail -n +2 … >/dev/null` after it is a no-op left behind; delete.
- **NOTE** — `count()` helper (grep -c || true, head -1) is the documented shared fix for
  the double-zero bug. Good.

### 6.5 `bin/bt-health-snapshot` (read fully)
- **NOTE** — Uses the canonical command-timeout regex with the exhibit reference, both
  intervention forms, per-device hci resolution with the spare-dongle rationale.
  Correct throughout. (This is the file the stale `bt-evidence` manifest should copy.)

### 6.6 `bin/bt-mark` (read fully)
- **NOTE** — The `|| true` + newline-strip for `grep -c` is correct and documented.
  Correct throughout.

### 6.7 `bin/bt-trace` (read fully)
- **NOTE** — umask-before-spawn (chmod race fix), 1 s liveness poll with gap logging,
  disk floor with never-delete-current guard, stop-rather-than-fill behavior. Correct.
- **LOW** — `disk_guard`'s inner `while` deletes oldest until floor met, but calls
  `free_gb` per iteration with `df` — fine. If *only* the current file remains it breaks
  out and then kills btmon and idles forever; service `Restart=always` will not restart
  it because the process stays alive in `sleep 3600` — deliberate (comment says restart
  manually). OK.

### 6.8 `bin/bt-usbmon` (read fully)
- **MED (suspected — verify on host)** — The capture loop relies on `tcpdump -C $MAX_MB
  -W 1` *exiting* when the file reaches the size limit, so the outer `while true` can
  start a new timestamped file and `prune()` can run. Per tcpdump's documented `-W`
  semantics, `-W` with `-C` creates a **ring buffer**: with `-W 1`, tcpdump *overwrites
  the single `out0` file from the beginning* rather than exiting. If that behavior holds
  on the shipped tcpdump, then: (a) the loop body never iterates while tcpdump lives,
  (b) retention is one 64 MB ring file per service start rather than KEEP=60 timestamped
  files, and (c) old USB history — the *only* record of stage 2 — is silently destroyed
  at each wrap. The `[[ -e "${out}0" ]] && mv` normalisation only ever runs after
  tcpdump exits (crash/stop), consistent with the exit assumption never being exercised
  in the happy path. **Action:** verify on the target machine (`ls /var/log/bt-health/usbmon`
  — many timestamped files ⇒ fine; one file per boot ⇒ defect). If confirmed, use
  `-C $MAX_MB -W 2` with post-exit renaming, or drop `-W` and let tcpdump rotate names
  itself, or rotate by killing tcpdump on a timer.
- **LOW** — `prune()`'s free-space loop can delete the file tcpdump is currently writing
  (no `$CURRENT`-style guard as bt-trace has). On low disk it would unlink the active
  capture; tcpdump keeps writing to the unlinked inode, so space is *not* reclaimed until
  tcpdump exits — the loop then deletes every other file and exits the loop with the
  floor still breached. Two defects compounding: add an is-newest guard.
- **LOW** — When the device is absent and `BT_USBMON_BUS` unset, the script exits 0
  ("nothing to capture"); with `Restart=always` the unit respawns it every
  `RestartSec=5s` forever. Exit code or unit policy should make this state quiet.

---

## 7. `tools/` — diagnostics and analysis

### 7.1 `tools/bt-diagnose`
- **NOTE** — Auto-detection of any USB BT controller, three-way fallback for boot
  enumeration via `bt-boot-list`, canonical timeout regex with exhibit reference, and a
  correct little-endian byte-scan hint (`${VID:2:2}${VID:0:2}${PID:2:2}${PID:0:2}` —
  verified: 13d3:3503 → `d3130335`). Exit-code contract (0/1/2) honoured on all paths.
- **LOW** — "a warm reset does not drop an M.2 card's power rail" stated as fact in the
  no-controller advice (the known-untested assumption, unflagged — cf. §1.4).

### 7.2 `tools/bt-boot-list`
- **NOTE** — The JSON → `-q` → header-stripped fallback ladder with a loud
  current-boot-only fallback. This is the fix for the silent `--no-legend` failure and it
  is correct. No issues.

### 7.3 `tools/bt-boots`
- **NOTE** — Canonical timeout regex, both intervention forms, first-entry (not `-n1`)
  boot date. Correct. **LOW**: skips boots whose kernel line rotated away
  (`[[ -z "$k" ]] && continue`) — silently omits rows rather than printing `?`; a boot
  whose early journal was truncated disappears from the table without a trace.

### 7.4 `tools/bt-state`
- **NOTE** — Auto-detect with pinned-device override; canonical patterns; TSV mode.
  Correct. (Its `hciconfig <hci> name` probe is the documented btmon-abort trigger —
  recorded as a known perturbation in issues.md BT-4; the tool itself carries no warning
  comment. **LOW**.)

### 7.5 `tools/bt-actions`
- **NOTE** — Single-awk classifier, full-ISO sort (midnight-safe), collapse-with-cadence
  rendering, and the µs/ms lesson encoded in `tosec()`. MGMT pass from captures for
  operator intent. Well built.
- **LOW** — `tosec()` computes `day_of_month * 24 + hour` — correct across midnight but
  wrong across a **month boundary** (Aug 31 → Sep 1 yields a negative span in the cadence
  arithmetic). The shared `tools/lib/timestamp.awk` exists precisely for this
  (`bt-trial`'s header even says "day_of_month * 24 … silently catastrophic across a
  month boundary"), but bt-actions still carries a private, month-unsafe copy. Same for
  `bt-boot-stats`'s `hours` function (7.7). The defect class the lib was created to end
  survives in two tools.

### 7.6 `tools/bt-boot-provenance`
- **NOTE** — Honest about what shutdown-target provenance can/cannot prove; the
  `date -d "$first + 180 seconds"` timezone-parse trap and the `-n1` trap are both
  documented and avoided. Epoch-based `--until` bound; counted-not-`grep -q` device
  check.
- **LOW** — `mapfile -t BOOTS < <(journalctl --list-boots | tail -n "$N")` — when fewer
  than N boots are retained, the header row ("IDX BOOT-ID …") lands in BOOTS; `off`
  becomes `IDX` and `journalctl -b "$((off - 1))"` fails arithmetically (bash error on
  non-numeric). Filter `$1 ~ /^-?[0-9]+$/` as bt-env-history does.

### 7.7 `tools/bt-boot-stats`
- **NOTE** — The honest-correlation 2×2 with false-positive/false-negative rows; TMO vs
  BUSLOST distinction documented; explicit non-comparability note vs the frozen baseline.
- **LOW** — Inline `hours` awk uses day-of-month arithmetic — month-boundary unsafe
  (see 7.5). A boot spanning Aug 31→Sep 1 reports a negative/absurd HOURS value.
- **LOW** — Summary line "boots with >=1 command timeout" is stored in a variable named
  `hung` and the 2×2 labels say "hung" — but the column note correctly says TMO ≠ hang.
  The summary text uses "command timeout" wording, so output is accurate; only the
  variable names mislead. Nit.

### 7.8 `tools/bt-capdiff`
- **NOTE** — Consumptive two-pointer matching via shared awk libs, tolerance-based
  matching with clock-semantics rationale, refusal to give a verdict on unmatched
  records, bookkeeping exclusion. The header's "what independent does not mean" is
  exactly right. `touch` after the matcher plus `sort -o` — note the Phase-23 bug
  (empty files created by touch masking a never-run matcher) is now mitigated by
  `tests/run-tests` checking the `-f` pattern, not by this script itself.
- **LOW** — `--since`/`--until` values are compared lexically against full
  `YYYY-MM-DDTHH:MM:SS.mmm` keys; the usage text says `--since "HH:MM:SS"` — a bare
  HH:MM:SS compares lexically against a full ISO key and matches nothing (all keys start
  with digits `2…` < `HH`? actually `"0…"` vs `"2026-…"` — `lo="06:00:00"` < any
  `2026-…` is false, so the window filter empties). Usage text and implementation
  disagree; passing a full ISO timestamp works. Fix the help text or normalise inputs.

### 7.9 `tools/bt-context`
- **NOTE** — The inverse filter with KNOWN suppression and shape-collapsing. Good
  design; MAC redaction applied to the raw windows (`--full`) and the summary.
- **LOW** — The `--full` MAC scrub only replaces colon-separated uppercase-hex MACs
  (`[0-9A-F]{2}(:…)`); lowercase MACs (kernel prints lowercase in some paths) and
  dash/underscore forms pass through unredacted. This tool prints to a terminal, not to
  committed files (sanitize-logs covers those), so impact is low — but the scrub gives
  a false sense of coverage. Use the sanitiser's character classes.

### 7.10 `tools/bt-env-history`
- **NOTE** — Positive-evidence-only reconstruction with `?` for unknowns and the
  different-experiments warning; header-name column resolution for metrics.tsv.
- **LOW** — `date=$(journalctl -b "$idx" -n1 …)` — `-n1` returns the boot's **last**
  entry; the column header is DATE (of the boot). For a boot spanning midnight the shown
  date is the end date. This is precisely the `-n1` trap HISTORY Phase 5 documents and
  `bt-health-report`/`bt-boot-provenance` explicitly avoid; the third tool forgot.
- **LOW** — `tr -d 'threshold '` deletes a *character set*, not the string — works here
  by accident (digits and `/` survive) but strips the trailing `s` of `60s` only because
  `s` is in the set; a threshold banner format change breaks it silently. Use sed.

### 7.11 `tools/bt-exhibit`
- **NOTE** — The one-pass command+output capture with sanitiser-or-refuse, stable EX-NNN
  numbering, redaction notice, provenance table, auto-index. The refuse-to-write-if-
  sanitiser-fails branch is the right call.
- **LOW** — `REPO="${BT_REPO:-/root/exp/qca9377-bt-hang}"` — hardcoded operator path as
  the default (bt-evidence/bt-incident resolve relative to the script first; this one
  does not). Running an installed `bt-exhibit` on another machine writes exhibits into a
  nonexistent path and dies. Resolve relative to `BASH_SOURCE` first like its siblings.
- **NOTE** — Numbering scans `[0-9][0-9][0-9]-*.md`; `README.md` is excluded by the glob.
  Correct.

### 7.12 `tools/bt-interval`
- **NOTE** — Thin wrapper over the shared libs with parse/negative guards and the
  permission-allowlist rationale. Correct.

### 7.13 `tools/bt-logvolume`
- **NOTE** — Shape-collapsing volume reporter with boot-average vs current-rate split.
  Correct. **LOW**: the GB/day projection multiplies `lines/min × 60 × 24 × 80 bytes`
  — the `now` variable is lines in the last 60 s but the label says lines/min (same
  thing; fine) — arithmetic checks out. Nit: 80 bytes/line assumption is stated.

### 7.14 `tools/bt-health-report.sh`
- **NOTE** — Stamp-based before/after split (the `-n1` and mtime traps both documented
  and avoided), canonical patterns throughout.
- **MED** — §3's verdict logic aggregates the **whole journal** (`journalctl -u
  bt-hang-watchdog` with no `-b`) and prints "VERDICT: WORKING. N hang(s) recovered…"
  whenever any historical recovery exists — with no live-state check. This is the exact
  masking flaw Phase 11 documents as fixed "in both tools" (bt-status, bt-postmortem):
  an evening early-recovery success makes the report read WORKING while the controller
  is off the bus *right now*. bt-status/bt-postmortem check live state before
  interpreting counters; bt-health-report does not. Third instance of the class.
- **LOW** — §2 counts use `grep -cE` without `|| true`; harmless without `set -e`
  (assignment survives), but inconsistent with the guarded style everywhere else.

### 7.15 `tools/bt-incident`
- **NOTE** — Retroactive collection, sanitise-in-place, referenced-not-copied captures,
  gap-log inclusion, `latest` symlink rationale. Split early/late intervention counters
  (the Phase-10 fix) present.
- **MED** — `tx_timeouts=$(count 'tx timeout' …)` — bare pattern in the MANIFEST:
  conflates command timeouts with `link tx timeout` (and would count a `command tx
  timeout` line inside any quoted text). Same stale-pattern class as bt-evidence (6.4).
  For an incident manifest that feeds bug-report numbers, the count should use the
  canonical regex from EX-015.
- **LOW** — `find … -newermt "$SINCE"` requires `date`-parsable input; the default
  `-15min` parses under GNU date, but journalctl-style inputs like `"07:20"` work while
  `"@1234567890"` (used by bt-trial's call: `--since "@$((start-60))"`) is passed to
  `-newermt "@…"` — GNU find accepts `@epoch`? (`-newermt` uses the same parser as
  `date -d`, which accepts `@epoch`.) OK — verified reasoning, no defect; noting the
  chain for future readers.

### 7.16 `tools/bt-mode`
- **NOTE** — Move-aside `.disabled` reversibility, runtime + persistent state both
  handled, passive-capture distinction, status view with counted `grep -c`. The
  experiment-mode warning correctly hedges the warm-reboot claim ("believed … untested —
  EX-017"). Good.
- **LOW** — `set_mitigation` writes `echo 0 >` while `set_experiment` writes `echo Y >`
  to `enable_autosuspend` (kernel bool accepts both; inconsistent style only).
- **LOW** — `set_experiment` disables the udev snapshot rule by renaming to
  `*.disabled`; `uninstall.sh` removes only the active name — after
  experiment-mode + uninstall, `51-….rules.disabled` (and the modprobe/udev `.disabled`
  pairs) survive (cf. §3.2). `bt-mode mitigation` restores them, so the leak needs the
  experiment→uninstall path specifically.

### 7.17 `tools/bt-phase`
- **NOTE** — The five-invariants header, provenance self-check with refusal, correct
  civil-date epoch conversion (proper `days()` — this tool got the shared-lib treatment
  in inline form), cluster-not-line counting, per-boot isolation, small-n honesty in the
  output. This is the strongest single script in the repo. No defects found.
- **NOTE** — Inline `days()`/`s()` duplicates `tools/lib/timestamp.awk` rather than
  loading it (the lib exists; bt-phase predates it per HISTORY). Consistency nit only —
  the arithmetic is the correct algorithm in both places.

### 7.18 `tools/bt-postmortem`
- **NOTE** — Incident clustering with GAP, per-incident scoping, live-state check before
  the verdict, early-signal timing analysis. The −40065 s lesson is properly encoded.
- **MED** — Clustering and counting use the **bare** `grep "tx timeout"` (three sites:
  the `mapfile TO`, the `n_to` count, and implicitly the incident boundaries). `link tx
  timeout` events (ACL supervision — fires when a headset walks out of range, on a
  healthy controller) are clustered as controller-hang incidents; a link timeout burst
  with no command timeout would produce a full postmortem for a non-incident, and a link
  timeout adjacent to a real incident shifts `t_first` (the "0s" anchor every Δ in the
  output is measured from). The EX-015 canonical pattern exists precisely for this and
  is used by the sibling tools.
- **LOW** — The stage-2 verdict text asserts "a warm reboot does not drop the M.2 power
  rail" unhedged (untested assumption; cf. §1.4).

### 7.19 `tools/bt-sco`
- **NOTE** — Honest about not pairing request/completion; `--window` compares paths, not
  fields, with full civil-date windows; the supported-commands-bitmap false-match is
  documented. Counts guard req>cpl with a rotation caveat. Good.
- **LOW** — `--window` seconds resolution (`ts()` drops the fractional part) means a
  ±2 s window is quantised to whole seconds — fine for its purpose; nit only.
- **LOW** — In the default (pairing-free) mode, the awk resets `insetup/incompl` on any
  `^[<>@=!]` line — but btmon *continuation* lines for the matched command are indented,
  so this works; however a command whose decode block contains an unindented line (btmon
  truncation artifacts at narrow COLUMNS) would splice. COLUMNS=200 mitigates. Nit.

### 7.20 `tools/bt-stage2`
- **NOTE** — Cache-with-partial-file protection (`.partial` + rename), `-b all`
  requirement documented, refusal on failed reads, delegation of classification to the
  shared `stage2.awk`. Correct. (stage2.awk itself reviewed at §8.)
- **LOW** — `boots=$(grep -c '^-- Boot ' "$DUMP")` then prints `$((boots + 1))` — off by
  one when the dump contains exactly one boot with no separator (prints 1 — correct) and
  when journalctl emits separators for *every* boot including the first (would print
  n+1). Depends on journalctl version behavior; cosmetic (stderr info line only).

### 7.21 `tools/bt-status`
- **NOTE** — Live-state-first verdict (the Phase-11 fix), usage-alongside-failures, repo
  drift check. Structure is right.
- **MED** — The early-recovery verdict branch still prints the **refuted conclusion**:
  "Implication: cmd_timeout fires too late for this failure mode, so adding the device
  to btusb's quirks table would not be sufficient." Phase 16 established that the late
  resets never tested the +0 s kernel path, `issues.md` BT-3 says the direction of the
  patch's effect is *unmeasured*, and the README/fix-proposal were corrected — but this
  output string still asserts the pre-Phase-16 claim every time an early recovery
  occurs. A tool that prints a refuted inference as an "Implication" is doc-drift in the
  most visible place: live terminal output.
- **LOW** — `tx=$(cnt "tx timeout" "$KE")` — bare pattern for the "HCI command timeouts:"
  row (conflates link timeouts; labelled as command timeouts). Canonical regex exists.

### 7.22 `tools/bt-timeline.sh`
- **NOTE** — Multi-stream merge with per-stream filtering, epoch sort, highlight set.
  Correct. **LOW**: `msg=${msg#*: }` strips through the first ": " — for MARK lines the
  logger prefix is removed correctly, but a kernel line with no colon (rare) passes
  through with hostname attached. Nit.
- **LOW** — Sorts with `sort -n -k1,1` on epoch-with-fraction — numeric sort on
  `1691646123.456789` is correct. Footer counts use `grep -c $'\tTAG\t' || true` —
  correct under pipefail. No defects.

### 7.23 `tools/bt-trial` (read fully — the core instrument)
- **NOTE** — This script encodes most of the project's methodology: two-axis outcome
  (`bt1_status` × `trial_result`), treatment fingerprint at start with drift and
  interior-perturbation detection, trial_type separation, header-resolved column access,
  checked journal acquisition (unreadable ≠ zero), nearest-preceding-SCO heuristic
  labelled as heuristic, probe-count-as-lower-bound caveat, shutdown-provenance fields.
  The inline comments document every past defect at its fix site. Exemplary.
- **LOW** — `autostop` runs `exec "$0" ok` at shutdown; `ok` path calls
  `env_fingerprint` → `systemctl is-active` and `journalctl` during shutdown ordering —
  services being stopped concurrently may make the fingerprint read `wd=off/probes=off`
  for a boot that ran them throughout. The captured-at-start `treat_start` protects the
  treatment column (equality check fails → CHANGED:… → excluded from pooling), but that
  means every shutdown-closed trial whose services stopped before bt-trial-auto's
  ExecStop risks being marked CHANGED and excluded. Ordering: bt-trial-auto has
  `Before=bluetooth.service` (so its ExecStop runs *after* bluetooth stops at shutdown)
  and no ordering vs the watchdog/timer — so this is a real, systematic possibility for
  auto-trials. Worth checking rows in results.tsv for spurious `CHANGED:` treatments
  from clean shutdowns. *(Cross-checked evidence/trials/results.tsv — see §10; the
  recorded rows show `autostop`-closed trials did not hit this, but n is small.)*
- **LOW** — `hang|ok)` case: `auto=$(grep -c '^auto=1' "$CUR" || true)` then
  `if (( auto ))` — fine. `outcome="$1"` at top is immediately shadowed later
  (`outcome="$trial_result"`), and the early `outcome` assignment is dead. Nit.
- **LOW** — `sco_to_tmo` uses kernel-log `opcode 0x0428` lines, which exist only when
  dyndbg is on; with dyndbg off, `sco_sent=0` and the SCO columns read "no stimulus"
  for a trial that did carry SCO traffic (visible only in captures). The 2×2 then
  under-fills its top row. The dependency on dyndbg being enabled is not stated in the
  column documentation.

### 7.24 `tools/bt-verify-kernel-mechanism`
- **NOTE** — Symbol-presence check with the btqca.ko/strings-are-comments corrections
  encoded as comments; LE byte-scan via hexdump with correct byte order (verified
  3563 → `d3136335`); vendor classification explicitly sourced from upstream, not
  inferred. Correct.
- **LOW** — `strings "$TMP"` on a ~4 MB module into a shell variable, then five
  herestring greps — fine. `hexdump` temp `.hex` file ~8 MB; removed. Nit: `grep -qo`
  (the `-o` is pointless with `-q`). No defects.

### 7.25 `tools/bt-verify-install`
- **NOTE** — Artifact list and unit list both *derived* from `install.sh`
  (backslash-continuation joining handled), refusal on an empty parse, `.disabled`
  awareness so it doesn't fight `bt-mode`, experiment-mode-aware Services block, and
  template udev rules checked semantically rather than byte-wise. This is the corrected
  pattern the hand-written lists elsewhere should follow.
- **LOW** — The udev semantic check `grep -q "$VID" "$f"` matches the VID anywhere in
  the file — including in a comment — so a rule generated for the wrong device but
  carrying the default device in its header comment would pass. Match the
  `idVendor}=="$VID"` form instead.
- **LOW** — INTERVENING match list contains `bt-hang-watchdog` twice (bare and
  `.service`) — deliberate (units list mixes suffixes) and commented; fine.

### 7.26 `tools/verify-restored.sh`
- **MED** — §1's "Installed files removed" list is a **hand-written 11-file list frozen
  at the original install set**. It does not check ~30 later artifacts (`bt-capture`,
  `bt-usbmon`, `bt-dyndbg` + their units, the dyndbg/journald/bluetoothd drop-ins, the
  awk libs, `bt-trial`, the `51-*` udev rule, the mode stamp, …). Consequently it will
  print "System matches its pre-investigation state" while the machine still runs the
  capture stack — and it also cannot catch the four files `uninstall.sh` forgets (§3.2),
  nor `.disabled` leftovers from experiment mode (§7.16). This is the *fifth* hand-written
  path list (HISTORY Phase 25 counts four), in the script whose one job is proving the
  hand-written-list script (`uninstall.sh`) worked. Derive both from `install.sh` the way
  `bt-verify-install` does.
- **NOTE** — The `(( x++ ))`-returns-1 footnote on the helper functions is correct and
  the kind of comment this repo does well.
- **NOTE** — §7 checks the user-global editor-tooling settings file for the attribution
  block — consistent with `docs/restore-original-state.md` §4.

### 7.27 `tools/sanitize-logs.sh`
- **NOTE** — In-place-safe (temp + rename after verification), incremental rebuild loop
  (the infinite-loop lesson), awk interval-expression capability check with refusal,
  `{5,}` long-run consumption, three-form verification, deterministic placeholders. The
  verification-covers-every-substituted-form discipline is real here.
- **MED** — **Underscore forms do not alias to colon forms in the placeholder map**:
  `key = tolower(raw); gsub(/-/, ":", key)` normalises dash→colon but leaves
  underscores, so the same device seen as `AA:BB:CC:DD:EE:FF` (kernel log) and
  `dev_AA_BB_CC_DD_EE_FF` (bluetoothd D-Bus path) receives **two different
  placeholders**. Privacy is unaffected (both are replaced), but the header's promise —
  "the same input always maps to the same placeholder, so cross-references within the
  log stay readable" — is broken precisely for the kernel↔bluetoothd cross-reference a
  maintainer would follow in a merged timeline. Fix: `gsub(/[_-]/, ":", key)`.
  *(Verified against `evidence/` logs: e.g. the first-real-hang session shows both
  colon- and underscore-separated placeholders — see §10.)*
- **LOW** — Replacement preserves the original separator? No: the placeholder is always
  colon-form `AA:BB:CC:00:00:NN`, so a sanitised D-Bus path reads
  `/org/bluez/hci0/dev_AA:BB:CC:00:00:07` — mildly misleading (real paths use
  underscores) but harmless.
- **LOW** — Beyond 99 distinct MACs the `%02d` placeholder grows a 3-digit last group
  (`…:00:100`) — no longer MAC-shaped; verification still passes it (the `-o` extraction
  matches only the first 6 groups, which the allowlist accepts). Cosmetic.
- **LOW** — IPv6 addresses and hostnames are out of scope and the docs say so; worth a
  one-line "NOT covered" list in the header so the scope claim is explicit at the tool.

### 7.28 shell library duplication (cross-cutting)
- **NOTE** — The `boot_indices()` fallback block is copy-pasted identically into
  bt-diagnose, bt-boots, bt-health-report; `find_usb_dev`-style loops appear in ~10
  scripts; the hciconfig/btmgmt probe in ~6. All are small and stable; the project has
  explicitly chosen policed duplication over a shared sourced library for load-order
  reasons (HISTORY Phase 24). Consistent with that decision; no action.

---

## 8. `tools/lib/*.awk`

### 8.1 `timestamp.awk`
- **NOTE** — Hinnant `days_from_civil`, correct; sub-second precision kept; timezone
  offset deliberately ignored with the caveat documented (same host, offsets cancel).
- **LOW** — The documented caveat is real: a session spanning a **DST transition**
  (CET↔CEST, this machine's zone) makes intervals wrong by ±3600 s — `bt-interval`'s
  negative-interval guard would catch the backward case but not the forward one. The
  header says "would need that handled"; noting that the machine's own timezone has two
  DST changes a year, this is a when-not-if for a months-long investigation. Parsing the
  offset is ~4 lines.
- **LOW** — `iso_secs` returns −1 for pre-1970 / unparseable, and callers test `< 0` —
  but `interval.awk` via `bt-interval` is the only guarded path; `capdiff-match.awk`
  calls `iso_secs($1)` unchecked (a malformed line yields −1 and pairs nonsense).
  Records there come from its own extractor, which regex-verifies the timestamp, so the
  risk is contained. Nit.

### 8.2 `interval.awk`
- **NOTE** — Correct; the exit-1-on-unparseable contract is honoured by `bt-interval`'s
  wrapper checks. No issues.

### 8.3 `capdiff-match.awk`
- **NOTE** — Greedy two-pointer consumptive matching per descriptor; correct given
  per-descriptor time ordering (guaranteed by the sorted input). The false-agreement
  post-mortem is embedded. No defects found.

### 8.4 `stage2.awk` — **two real defects in the headline analysis**
- **HIGH** — **`dev_error` is never reset** — not on the `/^-- Boot /` separator (which
  resets `have_tmo`, `intervened`, `term_kind`, `nev` but not `dev_error`), and not when
  a new timeout window opens. After the first boot in the journal that logged any USB
  bus error, *every* subsequent `reset …-speed USB device` line in *all later boots* is
  classified as "hub recovery" (symptom) instead of "OURS" (intervention) — so
  `intervened` is never set on that path, and a later `USB disconnect` in such a boot is
  classified **NATURAL**. The tool exists to answer "has natural progression to stage 2
  ever been observed?", and this defect biases it *toward* the false NATURAL answer —
  the exact wrong direction. (Today's output is saved by most intervened boots being
  unload-terminated, but the classification is unsound.) Fix: reset `dev_error=0` in the
  boot-separator rule and when a new window opens.
- **MED** — **No device filtering on the USB-layer patterns.** `USB disconnect, device
  number`, `reset …-speed USB device`, and the error patterns match *any* USB device on
  the machine. Unplugging a mouse (or any hub error on another port) during a stage-1
  window terminates the window as "disconnect", potentially **NATURAL** — a false
  observation of the very event the project says it has never seen. The kernel dump has
  no VID:PID on these lines, but it does have the `usb 3-3:` path prefix; the watchdog
  resolves the device's path and other tools filter by it. stage2.awk should carry the
  device path (or at least warn that it is device-agnostic).
- **CONFIRMED** — Both stage2.awk defects above were verified with a two-boot fixture
  (boot 1: timeout → descriptor error → disconnect; boot 2: timeout → our reset →
  disconnect). Output classifies boot 2's reset as "hub recovery" and its disconnect as
  **NATURAL**, reporting "ended naturally 2". The shipped test fixture
  (`tests/stage2-invariants.data`) escapes the leak only by accident: its sole
  descriptor-error line sits *after* a terminator, where the `term_kind != ""` skip rule
  prevents `dev_error` from ever being set — so the suite's stage2 invariants pass while
  the leak is live.
- **LOW** — `term_line` is assigned twice and never printed. Dead variable.
- **LOW** — `emit()` prints `substr(boot_id, 1, 12)`; the `-- Boot <id> --` line's `$3`
  carries the id with journalctl ≥ v246 — fine on target.

### 8.5 `trial-summary.awk`
- **NOTE** — Required-schema precondition, domain checks on both axes, END-after-exit
  guard, censored/unknown/drift exclusion with visible counts, treatment-in-key,
  incidence vs unrecovered split. This file is the project's methodology distilled;
  no defects found.
- **LOW** — `split("build …", need, " "); for (k in need)` — iterates values correctly.
  `mean dur` divides by `tot[k]` (confirmed + not_observed rows) — includes surviving
  trials' full durations; label is just "mean dur", fine. Nit only.

### 8.6 `trial-sco-table.awk`
- **MED** — **Excludes `CHANGED:` treatments but not `PERTURBED:`.** `bt-trial` writes
  a `PERTURBED:<what>:<treatment>` prefix when the interior of the window was acted on
  while the endpoints match, and `trial-summary.awk` excludes both prefixes
  (`e ~ /^(CHANGED|PERTURBED):/`) — but this cross-tab tests only
  `$col["treatment"] ~ /^CHANGED:/`. A purely-interior-perturbed trial (the actual
  2026-08-13 case that motivated the PERTURBED mechanism) is excluded from the rate
  table but **included in the SCO 2×2**, whose own comment says a mid-trial
  reconfiguration "is itself a candidate cause". The two consumers of the same column
  disagree about the exclusion rule.
- **LOW** — Header comment says "`outcome` is mandatory" — stale name; the schema check
  (correctly) requires `bt1_status`. The comment survived the outcome→two-axes rename.

---

## 9. `devtools/`

### 9.1 `devtools/README.md`
- **NOTE** — Accurate description of the three scripts plus `check`/`assert-test-catches`
  (the table omits the latter two — **LOW**, table lists 3 of 5 scripts).

### 9.2 `devtools/check`
- **NOTE** — Thin, correct composition; install-state step correctly informational.
  No issues.

### 9.3 `devtools/assert-test-catches`
- **NOTE** — Break-the-invariant-and-watch-it-fail as a named tool, restore-on-any-exit
  trap, failing-line-specific match (`✗.*$WANT`). Correct. **LOW**: appending the
  violating line to the *end* of a script places it after any `exit`/`case` dispatch —
  for `tools/bt-state` the appended line executes (top-level script), but for tools
  whose body is a `case` dispatch the appended line still executes (after esac) — fine;
  for `run-tests`'s *static grep* invariants execution doesn't matter anyway. No defect.

### 9.4 `devtools/repo-scan`
- **NOTE** — Root-anchored, staged-additions-by-default with the removes-a-secret
  rationale, empty-read-refusal, normalised MAC allowlist, SIG-UUID allowlist, email
  check with self-referential-pattern fix, AI-attribution check assembled from fragments
  so the tool doesn't match itself, binary-capture check. Well built.
- **LOW** — The MAC detector here matches colon/dash only (`[:-]`) — **not underscore** —
  while `sanitize-logs.sh` learned the underscore lesson (20 leaked addresses) and scans
  `[:_-]`. As the last line of defence, repo-scan would pass an underscore-separated real
  address (`dev_80_C3_BA_…`) that slipped past sanitisation. The exact form that caused
  the historical leak is the one form the backstop doesn't check. Fix: `[:_-]` here too
  (the allowlist normalisation then needs `tr '_' ':'` as well).
- **LOW** — `report "real MAC/BSSID found:" $macs` — unquoted expansion is deliberate
  (one arg per address) but a glob-metacharacter in content could expand; `set -f` or
  quoting with a loop would be safer. Theoretical.

### 9.5 `devtools/repo-validate`
- **NOTE** — Tracked∪staged enumeration, per-type checks with skip-vs-fail
  distinction, awk parse-against-/dev/null with diagnostic-based judgement, the
  enumerated-vs-checked zero distinction, test-suite integration, and the
  documentation-drift alarm with its two limits stated. No defects found.
- **LOW** — `jq -e . "$f" 2>&1 >/dev/null` — captures stderr only (stdout discarded);
  correct but subtle ordering; fine. The systemd-analyze filter drops "is not
  executable" noise — fine.

### 9.6 `devtools/repo-save`
- **NOTE** — Stage-first-then-validate ordering (with rationale), unknown-flag refusal,
  stream-safe `-F` snapshot, message scanned for attribution and MACs (counted, not
  `grep -q`), push-then-verify-remote-hash. Correct.
- **LOW** — `git push -q origin "$br" 2>&1 | tail -3` — a push *failure* is reduced to
  its last 3 lines and the pipeline's status is discarded (pipefail would flag it, but
  `tail` succeeds; actually pipefail preserves push's status — but the `if` tests the
  *hash comparison* later, so a failed push is caught by the mismatch check anyway).
  Chain is sound end-to-end; the intermediate error text may be truncated. Nit.
- **LOW** — `git add -A` stages *everything*, including untracked files the caller may
  not have meant to publish; combined with the scan this is the documented workflow, but
  a `--dry-run`-style listing before staging (or `git add -u` default) would reduce
  surprise. Policy choice, noted only.

---

## 10. `tests/`

### 10.1 `tests/run-tests` (1039 lines, read fully; suite executed — all 65 invariants pass)
- **NOTE** — The suite is the strongest of its kind I have reviewed: every invariant is
  anchored to a real shipped defect, fixtures are built so the *old* behaviour fails
  (2-vs-1 matching, tolerance-zero, month boundary, permuted header, missing/broken awk
  program, stubbed dead controller, unreadable watchdog journal, link-vs-command
  timeout), the producer is driven as well as the consumer, and the suite polices its
  own sandboxing (`trial()`-only invocation + before/after count of the real evidence
  tree). The `--section` self-filter and the PIPEFAIL-DEMO marked exemption are careful
  touches.
- **HIGH** — **The "one spelling of the BT-1 timeout" invariant cannot see most of the
  remaining violations.** Its scan regex — `-c\?E\?[[:space:]]*"[^"]*tx timeout` —
  requires a literal `-` (from a `-c`/`-cE` flag) immediately before a **double-quoted**
  pattern. Verified by replicating the scan: it reports zero strays while **six live
  sites still count with the bare pattern**, all invisible to it:
  - `bin/bt-evidence:62` — `grep -c 'tx timeout'` (single quotes)
  - `bin/bt-evidence:175` — `count 'tx timeout' …` (helper, single quotes)
  - `tools/bt-incident:84` — `count 'tx timeout' …` (helper, single quotes)
  - `tools/bt-postmortem:47` — `grep "tx timeout"` (no `-c` flag → no leading `-`)
  - `tools/bt-postmortem:100` — `grep 'tx timeout'` (single quotes)
  - `tools/bt-status` — `cnt "tx timeout" "$KE"` (helper, no flag)
  The invariant's own comment claims "no grep-family call anywhere may spell it any
  other way", and the suite prints a green tick. By the project's own doctrine
  (assert-test-catches: "a test that has never been observed to fail is not evidence
  the invariant holds"), this check needs to be driven with each of the six forms —
  `devtools/assert-test-catches` with a single-quoted violation would have exposed the
  gap immediately. Fix the scan to catch single quotes and helper-call forms (or
  centralise counting in one function per file and scan for the helper).
- **NOTE** — The bt-phase extraction (`python3` regex over the tool source) tests a
  *copy* of the analysis body — the exact anti-pattern the capdiff section warns about
  ("testing the artefact the tool actually runs, not a copy"). It is mitigated (the
  extraction fails loudly if the pattern is missing, and the body is verbatim), but
  moving bt-phase's awk into `tools/lib/` like the others would let the suite drive the
  shipped file. **LOW.**
- **LOW** — `--section` re-invokes the full suite (`out=$("$0")`) — every section view
  costs a complete run (~lifecycle tests included). Fine for this suite's size; noted.
- **LOW** — There is **no invariant covering the install/uninstall pairing** — the gap
  found in §3.2 (four artifacts installed but not uninstalled) is precisely a derivable
  list comparison (`install_file` destinations vs uninstall's FILES array) and would be
  a 10-line addition in the established style of this suite.

### 10.2 `tests/phase-invariants.data`
- **NOTE** — Ten records: month-boundary gap, burst-vs-cluster, per-boot isolation.
  Matches the assertions. No issues.

### 10.3 `tests/stage2-invariants.data`
- **NOTE** — Five boots covering natural/unload/ongoing/reset/link-timeout. See §8.4:
  the fixture's descriptor-error line sits post-terminator, so it cannot exercise the
  `dev_error` reset defect — add a boot with a *pre-terminator* error followed by a
  later boot with a clean reset. **LOW** (fixture blind spot).

### 10.4 `tests/trial-results.tsv`
- **NOTE** — Seven rows exercising both axes, censored, CHANGED, differing
  measurement_rev. Header is the 20-column pre-`prev_shutdown` schema — deliberate
  (consumers resolve by name; the width invariant checks the *live* file). No issues.

---


## 11. `evidence/`

*(Method note: every markdown, TSV, MANIFEST, NOTES, state and small log file was read in
full; the five large raw logs — `baseline/kernel-boot0.sanitized.log` (2794 lines),
`sessions/20260811-002156…/kernel.log`+`timeline.txt`, and
`sessions/20260813-051938…/bluetoothd.log`+`kernel.log`+`timeline.txt` (~10k lines
combined) — were skimmed head/tail plus targeted greps, including an independent
sanitisation check.)*

### 11.1 `evidence/README.md`
- **NOTE** — Accurate description of the session structure and the sanitisation
  posture; the "ad-hoc, not a procedure" caveat is prominent.
- **LOW** — The capture-budget paragraph is stale: "128 MB × 30 ≈ 3.8 GB … free space
  fall below 10 GB" describes the old `KEEP=30`/10 GB settings; the service now ships
  `KEEP=400` / floor 15 GB (and this very stale-retention episode is documented in
  `changes-applied.md`). Also the "sessions so far" table lists 4 of the current 9.

### 11.2 `evidence/exhibits/` (README + EX-001…EX-019, all read)
- **NOTE** — The exhibit discipline (claim / verbatim command / verbatim output /
  relevance / provenance, one pass) is genuinely followed, and several exhibits carry
  in-place corrections and integrity notes (EX-003's destroyed-dataset note, EX-007's
  refutation, EX-009's packet-count correction, EX-017's comparison-class correction).
  As an evidence corpus this is far above the norm.
- **HIGH (privacy/policy)** — **EX-018's extraction command leaks a local AI-tooling
  scratchpad path** (`bt-stage2 --from /tmp/<ai-tool>-0/-root-exp/<session-uuid>/scratchpad/stage2.log`).
  Three problems: (a) the path names the AI coding tool, in a repository whose explicit,
  documented policy (checklist §5, HISTORY Phase 4) is that no AI attribution appears
  anywhere; (b) the embedded session UUID is exactly what `repo-scan` flags — and does
  flag (see 11.5); (c) the "re-runnable as-is" promise is broken — the command reads a
  temp cache that exists on no machine, including the affected one. The exhibit's
  "Reproducing this" section gives the real command, so the fix is to swap it into the
  Extraction section and drop the temp path (then regenerate the index).
- **MED** — **EX-019's captured output is `command not found`, exit 127.** The
  extraction section faithfully records that the command *failed to run*
  (`bt-boot-provenance` was not on PATH), and the exhibit's "Reading" table is
  hand-transcribed from some other run — precisely the command/output drift
  `bt-exhibit` exists to make impossible. The one-pass guarantee held (the failure was
  recorded honestly); what is missing is a gate: `bt-exhibit` happily publishes an
  exhibit whose evidence-producing command exited 127, and nothing in `cmd_new` warns,
  let alone refuses. Re-capture EX-019 with the correct PATH, and make `bt-exhibit` at
  least warn on exit 127/126.
- **NOTE** — EX-003's table is itself live proof of the `bt-boot-stats` month-boundary
  defect (§7.7): rows `-26` and `-15` show **HOURS = −678.4 and −538.6**. Committed
  evidence carrying visibly-impossible values from a known-class arithmetic bug — worth
  an annotation in the exhibit.
- **NOTE** — EX-002/EX-014 embed `/root/exp/...` operator paths in extraction commands
  ("re-runnable as-is" only on the original machine). Acceptable, but inconsistent with
  exhibits that use installed tool names.
- **NOTE** — EX-001 and EX-004…EX-019 cross-check cleanly against the claims made for
  them in `issues.md`, README and `fix-proposal.md` — I found no case where a document
  cites an exhibit for more than the exhibit shows. (The reverse — code *output*
  overclaiming, §7.21 — is where the drift actually lives.)

### 11.3 `evidence/baseline/`, `evidence/diagnosis/`
- **NOTE** — `baseline.tsv` totals (287 timeouts / 34 boots / 13 hung) agree with every
  quotation of them in docs. `per-boot-history.txt` is consistent with `baseline.tsv`
  row-for-row (spot-checked ~10 rows). `root-cause-evidence.txt`'s byte-scan hex is
  correct (`d3130335` little-endian, validated against the known-ID control).
- **LOW** — Both baseline logs verified: an independent grep for MAC-like tokens finds
  only `AA:BB:CC:00:00:NN` placeholders. The one email in the tree
  (`kernel-boot0.sanitized.log` line 452) is a kernel `pps_core` copyright line — a
  benign upstream constant, but it turns the repo's own `--all` scan red (11.5); an
  allowlist entry is warranted.
- **LOW** — `baseline.tsv`'s `hung` column means timeouts>0 (13 of 34); EX-003 counts
  18 such boots over a different retention window with the same criterion. Both are
  explained locally, but a reader meeting "13 of 34" and EX-003's totals side by side
  has to reconcile them alone; one line in `evidence/README.md` would do it.

### 11.4 `evidence/sessions/`, `evidence/trials/`
- **MED** — The two most-cited session NOTES (`20260810-072445-first-real-hang`,
  `20260811-002156-early-mode-SUCCESS`) still contain, uncorrected and unbannered, the
  **refuted pre-Phase-16 conclusions**: "btusb_qca_cmd_timeout() … would have fired at
  roughly the same moment … adding 13d3:3503 would most likely not have prevented this
  hang", and "`hdev->cmd_timeout` is architecturally too late … correct but
  insufficient". `docs/investigation.md` received correction banners for exactly this
  class of residue; the session records — which README and `fix-proposal.md` link to as
  supporting evidence — did not. A maintainer following the "late reset failed" link
  lands on a document asserting the refuted mechanism with full confidence. Add the
  same ⚠-banner pointing to `fix-proposal.md` §3a.
- **LOW** — `20260813-020706-trial-stock-2` and `20260813-020830-trial-stock-2` are
  duplicate near-empty collections two minutes apart (17-byte logs, template NOTES never
  filled), with no matching trial directory or results row. Bookkeeping residue of the
  contaminated trial #2 — fill the NOTES with one line ("contaminated by install.sh
  btusb reload, discarded") or remove one of the pair.
- **LOW** — `trials/stock/trial-01/sco-params.txt` shows the two source headers with no
  records and no explanation. The "(no Setup Synchronous Connection inside this trial's
  window…)" fallback in `bt-trial` fires only when the file is completely empty, and
  the always-written headers guarantee it never is — the fallback is unreachable
  (cf. §7.23).
- **NOTE** — `trials/results.tsv`'s single row is the EX-015-corrected trial stock #1;
  every field cross-checks against EX-015/EX-016 (timeouts=5, sco_to_timeout=13.746,
  wd=off treatment; `perturbed=none` is correct — the btusb reload at 06:26:42 fell
  after this trial's close at ~05:19).
- **LOW** — Session `timeline.txt` files open with a spurious first row
  `-- WDOG No entries --`: `bt-timeline`'s `grab()` passes journalctl's "-- No
  entries --" notice through as an event (ts `--`, sorts first). Cosmetic.

### 11.5 The repository's own publication gate, run as part of this review
- **HIGH (privacy)** — `devtools/repo-scan . --all` **FAILS on the current tree**, on
  three findings (each verified individually):
  1. **The two real Bluetooth device MAC addresses are present in the working tree**, in
     `docs/pre-submission-checklist.md` lines 37–38 — as the literal arguments of the
     very `git filter-repo --replace-text` command §1 provides for purging those
     addresses from history. The section's opening claim, "The working tree is clean",
     is false: the purge instructions re-leak the addresses in both colon and
     underscore forms, and every commit re-publishes them. (BT device addresses, not
     BSSIDs — low severity by the project's own triage — but the history purge is
     pointless while the tree re-introduces them. Keep the address list outside the
     repo, or spell it in a non-matching obfuscated form.)
  2. The EX-018 scratchpad path's session UUID (see 11.2).
  3. The `pps_core` copyright email in the baseline log (see 11.3) — allowlist gap,
     not a leak.
  Because `repo-save` scans **staged additions** by default, all three ride along
  silently with every commit; only `--all` reveals them. The last line of defence
  currently reports FAIL on its own repository — a periodic `--all` run belongs in
  `devtools/check`.

---

## 12. Consolidated findings

Ordered by severity; file:line references are to the tree at the review commit.

| # | Sev | Where | Finding |
|---|-----|-------|---------|
| F1 | HIGH | `uninstall.sh` FILES list | Four installed artifacts never removed: `bt-interval`, `bt-stage2`, `bt-boot-provenance`, `lib/stage2.awk` (verified by mechanical diff against `install.sh`). "Uninstall is a complete restoration" is false; fifth instance of the hand-written-list class. Derive the list from `install.sh` as `bt-verify-install` does, and add a suite invariant. |
| F2 | HIGH | `tools/lib/stage2.awk` | `dev_error` never reset at boot boundaries → in any boot after the first bus error in the journal, our resets are classified "hub recovery" and a following disconnect as **NATURAL** (confirmed with fixture). Biases the headline "no natural stage 2 ever observed" analysis toward false NATURALs. Also: no per-device filtering — any USB device's disconnect can terminate (even "naturally") a stage-1 window. |
| F3 | HIGH | `tests/run-tests` timeout-spelling invariant | The scan regex only sees `-c`/`-cE` + double-quoted patterns; six live bare-pattern counting sites (bt-evidence ×2, bt-incident, bt-postmortem ×2, bt-status) pass unseen while the suite prints a green tick and claims repo-wide coverage. |
| F4 | HIGH | `docs/pre-submission-checklist.md:37` | The two real device MACs are in the working tree as the filter-repo arguments; `repo-scan --all` fails on them; "working tree is clean" is self-contradicted. |
| F5 | HIGH | `evidence/exhibits/018…md:12` | Extraction command leaks an AI-tool-named scratchpad path + session UUID, violating the repo's own no-AI-attribution policy and the re-runnability promise. |
| F6 | MED | `tools/bt-status` verdict | Prints the refuted pre-Phase-16 conclusion ("adding the device to btusb's quirks table would not be sufficient") on every early recovery. |
| F7 | MED | `bin/bt-hang-watchdog` header/FATAL text | Superseded model asserted as fact (~6 h stage 1, "USB reset recovers it", M.2-rail claim) — flows into journals and evidence. |
| F8 | MED | `tools/bt-postmortem` | Clusters and counts with bare `tx timeout` — link-supervision timeouts can fabricate or shift incidents (the "0s" anchor of every Δ). |
| F9 | MED | `bin/bt-evidence` / `tools/bt-incident` manifests | Stale counting patterns: bare `tx timeout`, and bt-evidence's `wd_interventions` misses `EARLY intervention` (the exact Phase-22 defect, surviving in the manifest path). |
| F10 | MED | `tools/lib/trial-sco-table.awk` | Excludes `CHANGED:` but not `PERTURBED:` treatments — interior-perturbed trials enter the SCO 2×2 while `trial-summary.awk` excludes them; the two consumers disagree. |
| F11 | MED | `tools/sanitize-logs.sh` | Underscore MAC forms don't alias to colon forms in the placeholder map — the same device gets different placeholders across kernel/bluetoothd streams, breaking the documented cross-reference property (privacy unaffected). |
| F12 | MED | `devtools/repo-scan` | MAC detector matches `[:-]` but not `_` — the exact separator form that caused the historical 20-address leak is invisible to the last-line-of-defence scan. |
| F13 | MED | `bin/bt-usbmon` | `tcpdump -C -W 1` is a 1-file ring (overwrites, never exits) per documented tcpdump semantics → timestamped rotation/prune loop likely never runs; usbmon history collapses to ≤64 MB, and stage-2's only record can be overwritten. Verify on host; also prune can delete the live capture file (no current-file guard). |
| F14 | MED | `install.sh` | Open-trial guard only runs in experiment mode; in default mitigation mode an install reloads btusb mid-auto-trial with no warning (post-hoc `perturbed` detection is the only net). |
| F15 | MED | `tools/bt-health-report.sh` §3 | Whole-journal watchdog verdict with no live-state check — "VERDICT: WORKING" can print while the controller is off the bus (third instance of the Phase-11 masking class). |
| F16 | MED | `tools/verify-restored.sh` | Hand-written 11-file check frozen at the original install set — reports full restoration while ~30 later artifacts (and the F1 leftovers, and bt-mode `.disabled` files) remain. |
| F17 | MED | `docs/bug-report.md`, `fix-proposal.md` §6 | The demoted 45–66 s stage-2 trajectory still stated as fact in the mail-ready text (incl. the suggested commit message), alongside the untested M.2-rail claim. |
| F18 | MED | `evidence/sessions/*/NOTES.md` | The two most-cited session NOTES assert refuted conclusions with no correction banner (unlike docs/). |
| F19 | MED | `evidence/exhibits/019…md` | Captured command failed (exit 127); Reading table hand-transcribed — the drift the exhibit tool exists to prevent; no non-zero-exit gate in `bt-exhibit`. |
| F20 | LOW | `tools/bt-actions`, `tools/bt-boot-stats` | Private day-of-month time arithmetic, month-boundary unsafe (EX-003 shows −678 h in committed output); the shared lib exists and isn't used. |
| F21 | LOW | `tools/bt-env-history` | `journalctl -n1` for the boot DATE column — the documented `-n1` trap, third tool; also fragile `tr -d` string handling. |
| F22 | LOW | `tools/bt-boot-provenance` | Header row parsed as a boot when fewer than N boots retained. |
| F23 | LOW | `tools/bt-capdiff` | `--since "HH:MM:SS"` usage text incompatible with full-ISO lexical window filter. |
| F24 | LOW | `tools/bt-exhibit` | Hardcoded `/root/exp/...` default repo path (siblings resolve via BASH_SOURCE). |
| F25 | LOW | `tools/lib/timestamp.awk` | TZ offset ignored — DST transition (twice a year on this machine's zone) shifts intervals ±3600 s; documented but unhandled. |
| F26 | LOW | misc | Stale README repo-layout (`data/`), stale evidence/README budget, `.gitignore` dead `data/` rules, unfilled duplicate trial-stock-2 sessions, `-- No entries --` timeline artifact, `51-*` udev remove-rule leading-zero PRODUCT edge, devtools README lists 3 of 5 scripts, fix-proposal section numbering, `20-verbose.conf` asymmetry, watchdog link-timeout trigger uncommented, `bt-usbmon` exit-0 respawn loop, EX-002/EX-014 operator paths, `repo-scan` email allowlist gap. |

## 13. Overall assessment

This is an exceptionally disciplined repository. The documentation practices —
refutations kept in place with banners, an issue register that separates six defects,
exhibits that carry their own extraction commands, a HISTORY that records every wrong
turn, and a test suite where each invariant is anchored to a real shipped defect — are
better than the overwhelming majority of professional projects. The shell code is
careful (counted-not-`grep -q`, umask-before-spawn, write-once stamps, checked
acquisition, refusal-over-guessing), and the statistical self-discipline
(censoring, provenance, outcome-dependent sampling, two-axis outcomes) is the
repository's real contribution.

The defects that remain are, almost without exception, **instances of the classes the
project itself identified and documented** — which is both a compliment (the taxonomy is
right) and the sharpest criticism (the enforcement is incomplete exactly where the
project believes it is complete):

1. **Hand-written lists that drifted** — F1 (uninstall), F16 (verify-restored) — the
   documented "fourth instance" class, now at five and six.
2. **Checks that cannot fail** — F3 (the timeout-spelling invariant's blind spot), the
   stage2 fixture's accidental avoidance of the `dev_error` leak — the exact
   `assert-test-catches` doctrine, not applied to the newest checks.
3. **Corrections not propagated to every residue** — F6, F7, F17, F18 — the "a document
   is not corrected until its residues are" lesson, with the residues now living in
   tool *output strings* and session records rather than in docs/.
4. **The instrument participating in the measurement** — F2 (stage2 classifier bias),
   F13 (usbmon retention), F14 (installer mid-trial) — the Phase-24/25 class.
5. **Privacy gate gaps** — F4, F5, F11, F12 — where the sanitiser learned the
   underscore lesson but the backstop scanner did not, and the checklist re-leaked what
   it purges.

Priorities if I were fixing: F4/F5 first (public-repo privacy/policy, minutes of work),
then F1+F16 together (derive both lists from install.sh), F2 (two-line fix + fixture),
F3 (widen the scan and drive it with assert-test-catches), F13 (verify on host), and
the F6/F7/F17/F18 residue sweep (grep the tree for "would not be sufficient",
"45-66", "M.2", "6 hours" and re-hedge each site).

No finding invalidates the project's central measured claims (quirks-table absence,
five-for-five late-reset failures, censoring critique of the two-stage model, the
BT-2/BT-4 characterisations). F2 is the only finding that touches a headline analysis
(EX-018), and there it biases toward the *conservative* conclusion being wrong in the
project's favour — today's "0 natural" result survives because the current journal's
intervened boots end by unload, not reset; the classifier is unsound, not the current
number. All findings above were verified by reading, and where feasible by execution
(test suite run: 65/65 green; repo-scan: FAIL as described; stage2 fixture: NATURAL
misclassification reproduced; uninstall diff: mechanical).

*Review performed file-by-file with no automation beyond the verification commands
quoted above. Large raw logs skimmed as noted in §11.*
