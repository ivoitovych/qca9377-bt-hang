# Entry-level review for ingestion: a second project maintainer — 2026-10-19 22:36 UTC

**What this is.** The record of a second maintainer reading the whole repository for the first
time, on `main` at `4814c6f` (2026-10-19), from a fresh clone under a different account on the
same laptop. Its purpose is twofold: to build the maintainer's own working knowledge of the
project, and to write down every defect, contradiction or stale statement met on the way, as it
is met, so that nothing found during the reading is lost. Findings are appended as they arrive;
the file is a snapshot and is not edited afterwards. Progress on the findings is recorded in the
action register (`reviews/README.md`), not here.

**Method.** The tree was read area by area (bin and tools, devtools, scripts, tests, docs, the
evidence trees, patches, comms and reviews, the deploy scripts and CI, the four entry documents).
Each area was read against the project's own descriptions (`README.md`, `BRIEF.md`,
`docs/STATUS.md`, `docs/tooling-index.md`, the area's README) and, where a claim pointed outside
the repository, against the outside record: git.kernel.org and its GitHub mirror, kernel.org's
stable ChangeLogs, patchwork.kernel.org, the BlueZ tree, Launchpad. Nothing on the laptop was
changed, installed, reloaded or probed; the suite was not run (a trial is open on this host).
Each finding is marked **CONFIRMED** (reproduced, or read in two places that disagree, or checked
against the outside record) or **SUSPICION** (read, not reproduced). Addresses and e-mail
addresses are never quoted here.

**How to read this.** §1 to §11 follow the areas in the order they were read. §12 is the
consolidated ranked list. §13 holds the open questions for the main-branch maintainer and the
operator. The per-area working notes, which are longer and name every file read, are kept outside
the repository.

---

## 1. Entry documents: `README.md`, `BRIEF.md`, `docs/STATUS.md`, `HISTORY.md`

Read whole (HISTORY by headings and its last 400 lines). `LICENSE` is GPL-2.0 and matches the
README badge. Every relative link in the four files resolves. No retracted claim of BRIEF §5 is
asserted anywhere in the four.

- **1.1 CONFIRMED, stale.** `docs/STATUS.md:27` says mainline "has not released v7.3 yet". The
  `v7.3` tag exists (committer date 2026-10-18 23:14 UTC) and `86ef0f58bdec` is an ancestor of it
  (checked on the GitHub mirror of torvalds/linux; git.kernel.org answered 403 to the checker).
  `README.md:37` and `BRIEF.md:84` say "mainline since v7.3-rc7"; all three can now say "in v7.3".
- **1.2 CONFIRMED, count.** `README.md:13` says "eight BlueZ commits". `README.md:39` and
  `docs/STATUS.md:24` name a ninth applied commit, the redundant a2dp v2 `d84171e6cd68`.
  `BRIEF.md:84-88` omits it. Decide whether the redundant commit counts, and make the three agree.
- **1.3 CONFIRMED, contradiction.** `README.md:145-147` presents an Ubuntu SRU as "next";
  `docs/STATUS.md:29` and `BRIEF.md:105` list it as an open operator decision.
- **1.4 CONFIRMED, rule breach.** `docs/STATUS.md:172-174` says STATUS is the only "current"
  paragraph; `README.md:142` and `BRIEF.md:78` each carry one of their own, and `README.md:142`
  lacks U12 and the bluetoothd CVE finding of 10-19.
- **1.5 CONFIRMED, date skew.** `docs/STATUS.md:3` says "As of 2026-10-18" while the page holds
  2026-10-19 facts (lines 39, 59, 84, 149, 151; its last commit is 2026-10-19).
- **1.6 SUSPICION, count.** "three stable backports" (`README.md:13` and the badge on line 6)
  leaves out the `dc16388d45ec` backport request described at `README.md:59`; `README.md:44` counts
  the emulator commit `8da7e648a9fb` among the "fixes".
- **Verified outside:** `86ef0f58bdec` in `v7.3-rc7` and `v7.3`; stable tags 7.2.10, 7.2.11,
  6.18.56, 6.18.57 and 6.12.113 exist and their ChangeLogs carry the named commits; kernel.org's
  front page listed 7.2.11, 6.18.57 and 6.12.113 as current on 2026-10-15.

## 2. `docs/` (the 26 files directly in it)

Ninety relative links checked by script: none broken.

- **2.1 CONFIRMED, stale register.** `docs/issues.md:17` says the BT-9 stuck discovery ended with
  a reboot on 10-11; `docs/STATUS.md:44` and `:75` (and BRIEF §5, corrected 10-14) say it ended at
  the 10-10 adapter power cycle. `docs/issues.md:216-218` still calls BT-1's mechanism open. The
  U-table heading at `docs/issues.md:724` says U1 to U10 but the table lists U12. M-1 and M-2 have
  no register section.
- **2.2 CONFIRMED, stale without a banner.** `docs/external-review-brief.md:225` says the USB ID
  has no quirks entry (false since 2026-08-07). `docs/review-task-bluez-patches.md` still speaks
  of patches "before they are mailed".
- **2.3 CONFIRMED, unreachable references.** `docs/contributions-roadmap.md:87-100` and
  `docs/kernel-send-package.md:32` point into git-ignored `tmp/`, which a new maintainer cannot open.
- **Verified outside:** every kernel and BlueZ commit id cited in STATUS's Submissions table, the
  stable ChangeLogs named there, the 6.6.160-rc1 patch, patchwork 14897668 and 14897669 (both
  `new` on 2026-10-19), BlueZ issues #1104, #294 and #1554, Launchpad. Unreachable: the 6.1.191-rc1
  patch (404), lore (403 to a plain fetch).

## 3. `docs/mesh-tester-ci/` and `docs/ui-capture-patches/`

- **3.1 CONFIRMED, stale after an upstream change.** `87a49b610708` (bluetooth.git, 2026-10-05)
  makes the mesh timeout milliseconds. The expiry figures of 16.96 s and 1000 s in
  `duration-overflow-note-v3.md:57,85-88,96`, `phase5-results.md:341`, `PHASE3-TASK.md:21-24` and
  `REVIEW-TASK.md:23,25` describe the pre-fix tree; only STATUS mentions the fix. Series v3 was
  tested on the pre-fix base.
- **3.2 SUSPICION.** After that fix the controller stops a mesh set at 1 s, which truncates a Send
  only when the count exceeds 40 (the done deadline is count × 25 ms); meshd sends count = 1
  (`mesh-io-mgmt.c:540`), so nothing is affected today. Worth one line in the duration note.
- **3.3 SUSPICION.** `series-v3/bluez/0002` looks like the already accepted leak fix
  `ae23df052290`; the content was not diffed.
- **3.4 CONFIRMED.** `review-response-4-bluez-shared-mgmt-2026-10-08.md:8` names a directory that
  does not exist (the `-2026-10-08` suffix is missing). The `SHA256SUMS` files list raw logs under
  `tmp/` and `logs/phase5/`, both untracked; 28 of 34 `tools-phase5` scripts hard-code `cache/`
  or `tmp/` paths. The README's reading order matches the files that exist but omits the current
  duration note, the validation extra-paths file, the retest reviews and the briefs; notes v1 and
  v2 carry no superseded banner.
- **3.5 Minor.** `docs/ui-capture.md:87` says "four kept" while the `KEEP` default is 3.
- **Verified outside:** the duration arithmetic and the 15-value list; the Count text in
  `mgmt-protocol.rst`; the GNOME patch applies to 46.7; the btusb patch applies to mainline with
  an offset.

## 4. `bin/` and `tools/`

`bash -n` passes on every shell file; `bt-capture` parses. `shellcheck` is not installed on this
host.

- **4.1 CONFIRMED, evidence loss.** `bin/bt-trace:129` deletes the capture file it is writing when
  the disk-floor stop fires.
- **4.2 CONFIRMED, sanitiser gap.** `bin/bt-evidence:93` and `:207`: a sanitiser failure leaves
  raw text in place while the manifest still says `sanitised=yes`. `tools/bt-incident` was fixed
  for the same pattern; `bt-evidence` was not brought into line.
- **4.3 CONFIRMED, probe.** `bin/bt-health-snapshot:90` sends an HCI Read Local Name every 15
  minutes from its timer, against the probe-free rule stated in `tools/bt-snapshot` and BRIEF §0;
  BRIEF does not mention this probe.
- **4.4 CONFIRMED, live drift.** `bt-verify-install`, run read-only, reports 25 installed files
  differing from the checkout (exit 1); 42 match `main`, the 25 match `cccf0fe` (2026-09-18). The
  `--tools-only` deploy of BRIEF's hand-off is still pending (see §10).
- **4.5 CONFIRMED, wrong banner.** `tools/bt-trial:1130-1134` prints "survived" for
  `ended_unprobed`, against its own comment at `:780-785`.
- **4.6 CONFIRMED.** `tools/bt-trial status` (`:1222-1228`) judges by exit status only and has no
  "no journal files" check, so it can print "clean" with no readable journal.
- **4.7 CONFIRMED, reproduced.** `tools/bt-fault-window:141` has an arithmetic syntax error when
  every line is filtered out. `tools/bt-mode --dry-run` prints "stopped and disabled" success lines
  although nothing ran.
- **4.8 CONFIRMED, hard-coded.** The USB port `3-3` in `tools/bt-snapshot:129` and `:225`;
  `BT_USBMON_BUS=3` in `systemd/bt-usbmon.service:18` (the `bin/bt-usbmon` comment wrongly says it
  falls back to an install-time bus); user `i` in `tools/bt-ui-capture`'s fallback.
- **4.9 CONFIRMED, docs vs install.** `bt-crash`, `bt-ctrl-window`, `bt-fault-window` and
  `bt-guards` are not installed, yet `README.md:279` tells the reader to run `bt-fault-window`
  bare. `tools/lib/coredump.sh` is not installed; `bt-usbstate` is not installed although the
  tooling index recommends it for untreated windows. The installed `bt-trial-audit` resolves its
  default repository path to `/usr/local`, so it refuses unless `BT_REPO` is set (from the code).
- **4.10 CONFIRMED, stale comments.** `tools/bt-window:23` gets the exit codes wrong;
  `tools/bt-trial:9` describes the old `abort` behaviour. `bt-status:161` and several `bt-trial`
  calls run the PATH copies despite the sibling rule stated in `bt-status:139-144`.
- **4.11 CONFIRMED, label.** `tools/bt-verify-kernel-mechanism:157` labels `13d3:3503` "not in
  upstream"; upstream master lists it as `QCA_ROME` since `dc16388d45ec`.
- **4.12 SUSPICION.** `tools/bt-ui-capture collect` skips `bt-capture`'s collision-suffixed
  filenames. `tools/sanitize-logs.sh` covers MACs, UUIDs and IPv4 only, narrower than the README
  and tooling index suggest.
- **Verified outside:** `btmon -w` and `--columns` (man page); the kernel dynamic-debug syntax used
  by `bin/bt-dyndbg`; master's `hci_cmd_timeout` calls `hdev->reset` on the first timeout, which
  supports the tool's reading. Not verified: the btsnoop epoch and flags (BlueZ `btsnoop.c` was
  unreachable).

## 5. `devtools/`

Twelve of 24 files read whole, the rest by header and grep; `bash -n` passes on all 20 shell
files.

- **5.1 CONFIRMED, medium.** `devtools/access-classify:423` excuses any access by a process tagged
  `BT_MACHINE_CONTRACT`, writes and network calls included, and the tag is inherited by children
  (reproduced with a synthetic trace).
- **5.2 CONFIRMED.** `devtools/access-classify:375-377` treats non-project executables under
  `/usr/local/bin`, `/usr/local/lib` and `/opt` as benign (reproduced).
- **5.3 CONFIRMED, handover.** `devtools/held sync` pushes to the second remote with no validate, scan or
  identity check; its conflict-path commit uses a hard-coded identity (`held:19`, `held:59`).
- **5.4 CONFIRMED.** `devtools/repo-scan`'s MAC pattern also matches dash-separated timestamps, so
  a staged file with such a name fails the scan (the tree is clean today).
- **5.5 CONFIRMED, low.** A detached HEAD commits before failing on push; `devtools/ci` swallows
  `gh` errors in `--recent` and `audit_line`; `held sync` hides merge failures; `held status`
  checks only `kernel/*` on origin, not the other held families.
- **5.6 CONFIRMED, docs.** `devtools/README.md`'s table omits 10 scripts and describes the e-mail
  allow-list incompletely.
- **Note.** `/run/bt-trial/current` exists on this host, so `save` and `repo-save` commit without
  the suite here, as BRIEF says they do while a trial is open.

## 6. `scripts/`

`bash -n` and Python parsing pass on all 81 files.

- **6.1 CONFIRMED, tested.** `scripts/compile-mgmt-at.sh:29` reports "patch did not apply" for
  every clean patch: under `pipefail`, `patch | grep` fails when grep finds no "Hunk" line, so the
  patched compile never runs.
- **6.2 CONFIRMED, tested.** `scripts/export-local-work.py:44` passes a relative `-o` through
  `git -C`, so the exported patches land inside the tree; line 42 crashes when the first local
  commit is a root commit.
- **6.3 CONFIRMED, tested.** `scripts/build-btusb-stable-matrix.sh` loses its `werror` change
  inside `$(...)`, so a picked build can fail on `-Werror` after the control had to drop it.
- **6.4 CONFIRMED.** `scripts/kernel-preflight.sh` with the documented relative `BT_SPARSE`
  resolves the sparse path after `cd`, so sparse never runs.
- **6.5 CONFIRMED.** `scripts/ci-local.sh:487` runs `make install` for ELL and reports any failure
  as "does not build here"; lines 66-67 say the script touches only local trees, but it fetches
  from origin and from git.kernel.org; `:96` still expects `btdev.c:479`, which the tooling index
  says changes once A2 lands.
- **6.6 CONFIRMED, rule.** The owner's e-mail address is a literal in `scripts/ci-local-publish.sh:26`
  and `scripts/kernel-regenerate.sh:27`, against the `scripts/README.md` rule (it is public upstream
  metadata, so this is a style rule, not a privacy one).
- **6.7 CONFIRMED, safety.** `scripts/runtime-mgmt-test.sh:20-25` and the tooling index say the
  load and restore steps must never run, but `:148-166` still implements them and `guard()`
  (`:42-52`) does not refuse them; the recovery path at `:111` re-probes btusb.
- **6.8 CONFIRMED.** `scripts/smtp-login-check.sh:31-38`: smtplib's default context does not
  verify the server certificate (Python 3.12), so the app password travels over an unverified TLS
  session. Use `ssl.create_default_context()`.
- **6.9 CONFIRMED, scratch repo.** `scripts/pre-send-check.sh:36` and `scripts/stable-rc-check.sh:32`
  use `git log --grep`, which matches the whole message, so a patch whose body quotes another
  subject is reported as already applied. `pre-send-check.sh:21-22` checks `origin/master`, which
  is not the BlueZ tree when run on `cache/linux` (documented in `docs/kernel-send-package.md:113`,
  not guarded).
- **6.10 CONFIRMED.** `scripts/prove-held-branch-guard.sh:6` and `scripts/prove-bt-trace-archive.py:17`
  hard-code `/root/exp/...`. `scripts/mail-lint.sh`: the header says four headers, the code checks
  three, and the 72-column rule is applied to diff lines too. `scripts/series-backport-check.sh:38`:
  with GNU patch 2.7.6, `-N` still exits 1 on an already applied patch, so it is reported as FAILS.
  `scripts/stop-own-process.sh:28` matches the repository path as a substring, so a sibling
  checkout whose path extends it would match.
- **Verified outside:** kernel.org `releases.json` matches the default stable lines in
  `scripts/backport-check.sh:20`; the stable-queue and stable-rc endpoints behave as the scripts
  assume (queue-7.1 is 404). The patchwork API shape was unreachable from the checker.

## 7. `tests/`

The suite was not run: a trial is open on this host, the suite must run from a separate worktree,
and unprivileged user namespaces are restricted here, so the namespace worlds would report NOT
ASKED. The fixtures hold only placeholder address prefixes and `example.com` domains. All 29 seam
rows in `tests/system-resources.md` exist in code.

- **7.1 CONFIRMED.** `tests/README.md:422` gives the awk coverage floor as 85;
  `.github/workflows/checks.yml:254` enforces 95. The other three floors agree.
- **7.2 CONFIRMED.** `tests/system-roundtrip` and `tests/system-upgrade` install for real and have
  no EXIT trap: an interrupt, or an unbound variable under `set -u`, leaves the install in place
  and the gates then refuse the next run.
- **7.3 CONFIRMED.** `tests/whole-boot-reads.txt` has 41 entries still `pending`; the check at
  `tests/run-tests:3555-3565` enforces list membership only, and the README never mentions the file.
- **7.4 SUSPICION.** `tests/machine-tools` omits `getent`, `ps` and `dbus-monitor`, which
  `tools/bt-ui-capture` calls at lines 149, 235 and 365 (`dbus-monitor` is stubbed at
  `run-tests:11469`).
- **7.5 SUSPICION.** `tests/btmon/real/mkcap.py:10` uses local time, so regenerated captures depend
  on the host's time zone.

## 8. `evidence/`, `results/`, `retest/`

The exhibit index is clean: 64 exhibits, 64 files, no gaps, duplicates or broken links; the index's
claims match the files'; the nine exhibits BRIEF's Foundation cites all exist and say what BRIEF
says. The mesh retest report checks out (159 logs, the two expected non-zero exits, totals match).

- **8.1 CONFIRMED, published number.** `evidence/baseline.tsv:34` counts 25 timeouts for the failing
  boot; the sanitised log holds 22, and `evidence/README.md:34-37` says the 25 must be corrected.
  The quoted total of 287 would become 284.
- **8.2 CONFIRMED, exhibits not verbatim.** EX-034 is hand-written although the index header says
  every exhibit is captured in one pass; EX-038, EX-040 and EX-042 are trimmed or joined; EX-043
  has a reformatted tally line; EX-030 says 13 lines and holds 12. Label them as hand-edited or
  re-capture them.
- **8.3 CONFIRMED, references.** `results/ci-local-2026-10-10.md:383` links a directory that does
  not exist; `retest/mesh-tx-leak/REPORT.md:246,248` cite commits `4af3736` and `c41ce63` that are
  not in this repository; the retest README omits two log directories; nineteen exhibits hard-code
  `/root/exp` paths while claiming to be re-runnable as-is.
- **8.4 CONFIRMED, trial 15.** No results row and empty files; the only explanation is in
  `HISTORY.md:4116-4118`. The layout promised by `evidence/README.md` names state files that 26 of
  28 sessions lack.
- **Privacy check (counts only):** 31 distinct MAC-shaped values across 110 files, 29 of them exact
  `AA:BB:CC:00:00:NN` placeholders, the other two an all-zero address and a documentation dummy;
  11 distinct e-mail-shaped strings in 57 files, 39 of them under `results/…/patchwork/` (public
  list metadata).

## 9. `comms/`, `reviews/`, `lessons/`

The front matter of all 58 messages read, the 12 most recent whole; the three most recent plans
whole, the 203 KB comprehensive review by headings and summaries; both lessons whole.

- **9.1 CONFIRMED, format.** 20 of 58 messages lack the front matter `comms/README.md` requires.
  The review-branch role has written no message.
- **9.2 Open asks with no reply on record.** To the test-suite side: T1, SR1 and the `0x043d`
  column (`tools/bt-trial` has none of them yet); `devtools/ci:114` still uses `--limit 30`. The
  09-29 request to check the laptop for the USB reset has no answer in `comms/`.
- **9.3 Reaction plan state (`reviews/review-reaction-plan-20261019-045758.md`).** Phase 1 is
  mostly done; T1 and SR1 open. KR1, MODE1 (`tools/bt-mode:191` still arms the watchdog), I1/UN1,
  RS1 and CAP1 open. Phases 3 to 8 only partly checked in code.
- **9.4 CONFIRMED, contradiction.** BRIEF §9.2 says the device survey stays open; the 10-19 log
  says the operator dropped it.
- **9.5 CONFIRMED, stale.** The 6.6.160-rc1 review window closed 2026-10-19 16:02 UTC and no
  outcome is recorded. Pinned line numbers in the plans are off (`tests/run-tests` is 15,279 lines,
  not 14,195). Three entries in the 10-19 log do not match the commit times.
- **9.6 CONFIRMED, unsafe advice.** `tools/verify-restored.sh:188` still advises
  `uninstall.sh --apply` (see §10.3).
- **9.7 CONFIRMED.** About 30 commit ids cited in `comms/` and `reviews/` are absent from this
  clone, mostly pre-rebase test-suite tips; they are not recoverable from the public history.
- **9.8 Privacy, counts only.** Eight MAC-shaped strings in four review files; they look like
  placeholders and were not printed. Worth one pass of `devtools/repo-scan` over `reviews/`.

## 10. `install.sh`, `uninstall.sh`, `systemd/`, `etc/`, `.github/`

`bash -n` passes on both scripts; `udevadm verify` passes on both rules; `systemd-analyze verify`
printed nothing. Nothing was installed, enabled, reloaded or run.

- **10.1 Deploy state, read-only.** 42 installed files match `main`; 25 match `cccf0fe`
  (2026-09-18) and differ from `main`; the `.disabled` siblings of the modprobe conf and both udev
  rules are in place; experiment mode is on. The `--tools-only` deploy is still pending.
- **10.2 CONFIRMED, by reading.** The installed `bt-trial-auto`'s ExecStop still probes the
  controller over HCI at shutdown (BRIEF's hand-off says so), and `uninstall.sh --apply` disables
  and stops that unit, so an uninstall would run the probe on the live machine.
- **10.3 CONFIRMED.** `uninstall.sh` has none of `install.sh`'s guards (open trial, experiment
  mode, failed-this-boot). At `uninstall.sh:296-299` it reloads btusb whenever the usecount is 0,
  which is the wedged-controller case, against BRIEF §0's rule.
- **10.4 CONFIRMED, by reading.** The watchdog unit's `ProtectHome=yes` hides `/root`, where the
  checkout that `bt-trial` writes into lives, so the watchdog's auto-trial close would fail silently
  (the watchdog is not enabled on the laptop).
- **10.5 CONFIRMED.** An undocumented `BT_EARLY=1` drop-in that `uninstall.sh` removes; a reload
  command printed as advice at `install.sh:741`; `docs/install.md` omits most of the installed set;
  a stale comment at `checks.yml:410-412` (`cccf0fe` is on `main`); the btusb srcversion in the
  documents and in the live override's comment disagree.

## 11. `patches/`

Every README under `patches/` read whole; every patch header listed; the send packages sampled.

- **11.1 CONFIRMED, missing.** `patches/README.md` does not exist, although other documents point
  at it as the index of the directory; `patches/mesh-tester/` has no README at all.
- **11.2 CONFIRMED, stale states.** The BlueZ a2dp v2 patchwork entries 14836499 and 14836500 are
  still `new` on patchwork although the fix is in master (`d84171e6cd68`); nothing in `patches/`
  says so. `patches/bluez/README.md` is headed "2026-09-22" but holds later facts. The kernel
  README's items ER4-5 to ER4-8 are still marked open.
- **11.3 UNVERIFIED, not disproved.** The 6.6.160-rc1 and 6.1.191-rc1 commit ids named in STATUS,
  BRIEF and `patches/kernel/bt9-stable/README.md` could not be found on git.kernel.org and both rc
  tags return 404 (rc tags live in the stable-rc tree, which the checker did not reach).
- **Verified outside:** all nine BlueZ commits exist with matching subjects (committer dates
  checked for `a734b06059cb` and `0bed9886cff3`); kernel `86ef0f58bdec` and `96d006ae6445` exist
  in bluetooth-next and mainline; the stable ChangeLogs carry `86ef0f58bdec` in 7.2.11, 6.18.57
  and 6.12.113 and `dc16388d45ec` in 7.2.10, 6.18.56 and 6.12.113; the 6.12.113 backport
  `9a328ae01489` is present; the five stable releases are on cdn.kernel.org; the patchwork states
  of every id named in the READMEs match, A1 and A2 (14897668, 14897669) `new`. Lore answered 403
  to every fetch, so mail-level claims (Message-IDs, replies) remain unverified from here.

---

## 12. Consolidated ranked list

Ranked by what it costs if left alone. Owners as in the reaction plan: **main**, **suite**,
**operator**. Each item names its section above.

1. **Safety on the laptop (main).** `uninstall.sh` reloads btusb on a wedged controller and stops
   a unit whose ExecStop probes the controller (10.2, 10.3); `tools/verify-restored.sh:188` advises
   `uninstall.sh --apply` (9.6); `scripts/runtime-mgmt-test.sh` still contains the forbidden load
   and restore steps (6.7); `bin/bt-health-snapshot` probes every 15 minutes (4.3);
   `tools/bt-mode:191` still arms the watchdog (9.3). Each contradicts BRIEF §0's hazards.
2. **Evidence loss (main).** `bin/bt-trace:129` deletes the capture it is writing (4.1);
   `bin/bt-evidence` marks unsanitised text as sanitised (4.2); the two system tests leave a real
   install behind on interrupt (7.2).
3. **The deploy (operator, main).** 25 installed files are the 09-18 copies (4.4, 10.1); until the
   `--tools-only` deploy every shutdown with a trial open probes the controller, as BRIEF says.
4. **Published numbers and states that are wrong today (main).** The v7.3 release (1.1, 11.2);
   "eight" BlueZ commits and "three" backports (1.2, 1.6); STATUS's date (1.5); the a2dp v2
   patchwork entries (11.2); the mesh duration figures after `87a49b610708` (3.1); the baseline
   timeout count 25 vs 22 (8.1); the 6.6.160-rc1 window outcome (9.5); the BT-9 end in
   `docs/issues.md` (2.1); the device survey (9.4).
5. **Tools whose verdict can be wrong (main).** `bt-trial` "survived" for `ended_unprobed` (4.5)
   and "clean" with no journal (4.6); `bt-fault-window` arithmetic error (4.7); `bt-mode --dry-run`
   false success (4.7); `compile-mgmt-at.sh` never compiles the patched tree (6.1);
   `pre-send-check.sh` and `stable-rc-check.sh` grep the whole message (6.9);
   `series-backport-check.sh` misreads an applied patch (6.10); `export-local-work.py` exports
   into the tree (6.2); `build-btusb-stable-matrix.sh` loses `werror` (6.3); `kernel-preflight.sh`
   never runs sparse (6.4).
6. **Measurement instruments with holes (suite).** `access-classify` excuses a whole tagged process
   tree and everything under `/usr/local` and `/opt` (5.1, 5.2); the awk floor disagrees between
   README and CI (7.1); 41 whole-boot reads pending (7.3); three machine tools outside the
   tripwire list (7.4).
7. **Exhibits that are not what the index says (main).** Hand-written or trimmed EX-030, 034,
   038, 040, 042, 043 (8.2); nineteen exhibits with `/root/exp` paths (8.3); trial 15 unexplained
   in place (8.4).
8. **Hand-over debt (main).** `patches/README.md` missing (11.1); `devtools/README.md` missing
   ten tools (5.6); `docs/install.md` incomplete (10.5); tools documented but not installed
   (4.9); `/root/exp` paths in scripts (6.10) and exhibits (8.3); 20 comms without front matter
   (9.1); references to `tmp/` and to commits not in the repository (2.3, 8.3, 9.7); stale task
   documents without banners (2.2, 3.4); `held sync` without the save gates (5.3).
9. **Housekeeping (main).** `smtp-login-check.sh` without certificate verification (6.8); the
   owner's address as a literal (6.6); hard-coded USB port, bus and user name (4.8); `mail-lint.sh`
   header vs code (6.10); `repo-scan` matching timestamps (5.4); a one-line note on the 1 s mesh
   stop (3.2); `series-v3/bluez/0002` vs `ae23df052290` (3.3).

## 13. Open questions

For the operator:
- **Q1.** The `--tools-only` deploy (item 3): when? The review found nothing in `main`'s tool set
  that would make the deploy worse than the 09-18 copies, and two things that make it better (the
  row-first close, the `--columns` fix).
- **Q2.** Should `uninstall.sh` get `install.sh`'s guards before anyone is ever tempted to run it
  (item 1)? Until then, is it worth a one-line warning at its top?
- **Q3.** Which baseline total is the published one, 287 or 284 (8.1)?
- **Q4.** Does the redundant a2dp v2 count as one of "our" BlueZ commits (1.2)? The counts in the
  README, BRIEF and STATUS follow from the answer.
- **Q5.** The second maintainer's checkout is a fresh clone under another account on the same
  laptop. The installed tools and the open trial write into the other account's checkout. Should
  trial rows and new exhibits keep landing there and come to `main` through git, or should the
  installed tools be pointed at one checkout?

For the main-branch maintainer:
- **Q6.** The mesh duration documents: add a post-`87a49b610708` note, or mark the series v3
  documents as tested on the pre-fix base (3.1, 3.2)?
- **Q7.** Are the hand-edited exhibits to be labelled or re-captured (8.2)?
- **Q8.** Is `bt-health-snapshot`'s 15-minute probe intended on this machine (4.3)? BRIEF §0 does
  not list it among the probes.
- **Q9.** The 6.6.160-rc1 and 6.1.191-rc1 outcomes (9.5): were the three patches released?

For the test-suite maintainer:
- **Q10.** awk floor 85 or 95 (7.1)? Should the system tests get an EXIT trap (7.2)? Are `getent`,
  `ps` and `dbus-monitor` deliberately outside the tripwire list (7.4)? Should the
  `BT_MACHINE_CONTRACT` exemption be narrowed to reads (5.1)?
