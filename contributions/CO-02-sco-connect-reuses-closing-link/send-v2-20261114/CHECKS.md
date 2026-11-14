# CO-02 v2: checks and test results

Every result: measured unless marked. Work area `/root/exp/agent-work/lane2-sco-20261114/` (here
`$W`); logs in `$W/logs/`, bot output in `$W/project/tmp/`, scripts in `$W/scripts/`. Hashes of the
raw logs: `SHA256SUMS` in this directory (and `logs/SHA256SUMS`). Clock times are guest or host
clock as printed in the logs; the host clock ran 02:0x to 05:xx on 2026-11-14.

## 1. checkpatch --strict: run on the host

Run on the host (`cache/checkpatch/checkpatch.pl --strict --no-tree`, 2026-11-14) on all five patches (3 kernel, 2 BlueZ). Results: kernel: only the missing
Signed-off-by and `--no-tree`'s "Unknown commit id" warnings; BlueZ: kernel-style alignment checks
and split-string warnings, which BlueZ's own CheckPatch (the bot, which passed) does not apply.
No change needed. The bot's own CheckPatch (non-strict, `--ignore UNKNOWN_COMMIT_ID`) is in section 5.

## 2. Upstream state on 2026-11-14

Nothing merged, superseded or answered; stop condition not met.

| Check | Command | Result |
|---|---|---|
| Patchwork state of our four patches | `python3 -I project/scripts/patchwork-state.py 14919266 14919267 14919268 14919269` | all four `new`, 2026-10-27 16:50; comments: 1 on patch 1 and 2 on the BlueZ mail, all the CI bot's |
| Replies on the thread | local lore archive `cache/lore-linux-bluetooth-0.git` (newest entry 2026-11-13 00:25 UTC), `git log --since=2026-10-27 -i --grep=sco` | only `bluez.test.bot` mails for our series: 10-27 20:16 and 21:24 (CI results) and **11-12 00:36 (the CI's sweep closing the BlueZ PR 2724: "never applied to the tree"; a bot sweep, not a review)**; no human |
| Any patch since 10-27 on `hci_connect_sco`/SCO reuse | `patchwork-recent.py 2026-10-27 'sco\|hci_conn\|reuse\|abort'` (27 of 719 patches) | nothing equivalent. Related: Wentao Liang "Bluetooth: delete the new SCO link if linking it fails" (14942649, 11-04, `new`; same function, textual conflict with our patch 1 hunk 2 — checked with `patch --dry-run`, see NOTES); Zijun Hu "Fix SCO/eSCO Transport_Unit_Size" (applied, 3efdadae3a25, other lines) |
| bluetooth-next tip | GitHub API `commits?path=net/bluetooth/hci_conn.c` and `sco.c` since 2026-10-27 | tip `da3cc02587c6` (2026-11-12). hci_conn.c: EKS, HDT PHY, ISO QoS, "Initialize the device before hash insertion", Transport_Unit_Size, conn flags bitmap; sco.c: no commit. None is ours or equivalent |
| bluetooth (fixes) tip | `git fetch --shallow-since=2026-10-27 …/bluetooth.git master`, then `git log -- net/bluetooth/hci_conn.c net/bluetooth/sco.c` | tip `3b069de8a` (11-12); same unrelated commits, nothing for SCO reuse |
| Our base applies | `git am` of the three v2 patches on `da3cc02587c6` | clean (bot's `git am`, section 5) |

## 3. Kernel series v2: what was built

`$W/linux-bn` (shallow clone of github.com/bluez/bluetooth-next, tip `da3cc02587c6`, "Bluetooth:
hci_vhci: Report write readiness with queued input", 2026-11-12). Branch `co02-v2-final`:

1. `hold a reused SCO connection for its caller` (v1 patch 1, unchanged; `Cc: stable # 6.6.x`)
2. `don't reuse an aborting SCO connection` (v1 patches 2 and 3 folded; second check with
   `READ_ONCE()`; `Cc: stable`)
3. `don't change the parameters of a SCO link in use` (new; the 11-02 mismatch patch reworked: -EBUSY
   split, in-flight cases, field compare)

Kernels under test (config = BlueZ `doc/tester.config` plus KASAN, lockdep, `DEBUG_ATOMIC_SLEEP`,
SMP 4, the earlier area's `img/config-base`; `img/bzImage-<tag>.commit` records the commit):
`base` = `da3cc0258`, `p12` = patches 1-2 (`3c72ae5a62a3`), `p123` = all three (`6ab80e175065`, tree
identical to `co02-v2-final`, checked with `git diff`: empty). Builds: `logs/kernel-build-*.log`, no
warning from `net/bluetooth` (`img/*.commit`).

## 4. Guest tests (QEMU/KVM, 4 CPUs, 256 MB guest, btmon in the guest)

Tester binaries: BlueZ master `20ffd285b58f` plus our two sco-tester patches (`bin/sco-tester-v2b`
first, `v2c` after the line-wrap fixes the bot asked for in section 6; same tests). Runner:
`scripts/run-matrix.sh`; summaries: `results/*.txt`.

| Suite | base | p12 (1+2) | p123 (1+2+3) | file |
|---|---|---|---|---|
| sco-tester, 35 cases, v2b, 3 runs each | 31 pass, 4 fail ×3 | 33 pass, 2 fail ×3 | **35 pass ×3** | `results/sco-tester.txt` |
| sco-tester v2c (final binary), 3 runs each | 31 / 4 fail ×3 | 33 / 2 fail ×3 | **35 ×3** | `results/sco-tester-final.txt` |
| mgmt-tester (526), 1 run | 526 pass | not run | 526 pass | `results/mgmt-iso-tester.txt` |
| iso-tester (213), 1 run | 213 pass | not run | 213 pass | same |
| l2cap-tester (144) | 12 of 12 runs pass | 6 of 6 | 10 of 12 pass; **2 stalled** | `results/l2cap-tester.txt` |

- Cases that fail on base: "Reconnect During Disconnect", "Connect Twice" (fixed by patches 1+2),
  "Connect Twice Other Voice Setting" and "Connect Twice Other Voice Retry" (need patch 3; fail on
  p12 too, 0/3). Nothing else changes in sco-tester: the other 31 cases pass on all three.
- Why the two new cases fail on p12 (log lines, `logs/run-probe-p12-1.log`): ACL-pending case,
  "Setup Synchronous Connection #1, coding 0x03" (the second socket's transparent setting reached the
  first socket's setup); retry case, "Setup … #1, coding 0x02" then "#2, coding 0x03" (the retried
  setup after the injected 0x1f carries the second socket's setting). On base both fail earlier:
  the second connect() drops the first socket's hold and the first link is reset ("first socket
  failed: Connection reset by peer", `logs/run-probe-base-1.log`). With patch 3, setup #1 and #2
  carry coding 0x02 and the second connect() returns EBUSY. **This is the in-flight-setup
  measurement (F-80) the dossier asked for.**
- **Race patch 2 closes (parked worker), debug-only kernels** `parkA` (hold + abort check without the
  wait = the old patch 2 alone) and `parkB` (the fold), both with a scratch `msleep()` in
  `hci_conn_timeout()` after it saw `refcnt == 0` (commits `exp-parkA`/`exp-parkB` in `linux-bn`, not
  part of any mail); tester `bin/sco-tester-park -p EXPERIMENT` (from the 11-01 work area), 3 runs
  each: parkA fails both cases 3/3 ("RACE CONFIRMED: second socket was connected and then killed by
  the parked abort"), parkB passes both 3/3 (second connect() returns ECONNABORTED). Linked and
  remote-set-up ("Incoming Race Park") cases. `results/park-race.txt`.
- **l2cap-tester stalls: not caused by the series (see section 4a).** Two of the first 12 l2cap runs
  on p123 at 256 MB stalled: `run-l2cap-p123-1.log` (95 cases passed, stuck in the teardown of
  "L2CAP LE Server - Set HDT 2M") and `run-l2cap-p123-3.log` (97 passed, stuck after "Set HDT 3M"
  started), until the 25-minute guest limit.
- `kernel-report-scan.py` on all guest logs (`results/kernel-report-scan.txt`): the SCO, park and
  stalled logs are clean (no WARNING, BUG, KASAN, lockdep, refcount, UBSAN, RCU stall, hung task); the
  only `Call Trace:` lines are the guest OOM killer taking btmon in l2cap/mgmt/iso logs, on base as
  well (`grep -c "invoked oom-killer"`: 1 in each of the logs checked).
- Aborted runs, not results: `logs/run-l2capy-*.log` (a typo in my `timeout` argument, no guest ran).

## 4a. The l2cap-tester stalls, followed up (task 2)

Question: does the series cause the two stalls? Method: the same kernel images (`base`, `p12`,
`p123`) and the final tester (`l2cap-tester-v2c`, same binary as before), the guest memory raised
to 3 GB (`scripts/qemu-3g.sh`, `scripts/run-matrix-3g.sh`; nothing else changed) so that the guest OOM
killer cannot take btmon, 700 s guest limit (600 s for the 3 GB runs).

| Guest | base | p12 (1+2) | p123 (1+2+3) | OOM lines | files |
|---|---|---|---|---|---|
| **3 GB**, 32 runs each (labels `l2cap3g` 12, `l2cap3gb` 20) | 32 of 32 pass 144/144 | 32 of 32 | **32 of 32** | **0 in all 96** (`oom=0`, `grep -c "invoked oom-killer"`) | `results/l2cap3g.txt`, `results/l2cap3gb.txt` |
| 256 MB, new runs (label `l2cap256`, 15 each) | 15 of 15 | not run | 15 of 15 | 1 per log: btmon killed | `results/l2cap256.txt` |
| 256 MB, earlier (labels `l2cap`, `l2capz`, `l2capw`) | 12 of 12 | 6 of 6 | 10 of 12, **2 stalled** | 1 per completed log | `results/l2cap-tester.txt` |

Totals at 256 MB: p123 2 stalls in 27 runs, base 0 in 27, p12 0 in 6; Fisher exact two-sided
p = 0.49 for p123 vs base, so the data do not separate the kernels. At 3 GB there is no stall on any
kernel in 96 runs, every run 144 of 144. The earlier correlation (stalled runs = the two where btmon
was not OOM-killed) is **refuted as a cause**: at 3 GB btmon is never killed and nothing stalls.

Why the series cannot be involved (source, inferred from reading): `hci_connect_sco()` has one
caller, `sco_connect()` (`net/bluetooth/sco.c:380`, a SCO socket `connect()`), and the l2cap-tester
opens no SCO socket, so patch 3 and the hold/abort checks of patches 1 and 2 never run in it. The
one line of the series every connection passes is the `WRITE_ONCE(conn->abort_reason, …)` in
`hci_abort_conn()` (patch 2), and p12 carries it too. The stalled cases are LE Server HDT cases
(BlueZ `a7f03764f`/`a7d89aa0e`, new on master since 11-01). No test-only debug build was needed.

Conclusion: not reproduced in 96 + 30 runs with the memory confound removed or kept; the two stalls
remain unexplained and are not attributable to any patch of the series. It is reported as
"two of 27 l2cap-tester guest runs at 256 MB stalled in an LE Server HDT case with the series, none
of 27 without; 0 of 96 stalled with 3 GB guests". The 11-01 research (`research-2026-11-01/sco/`)
logged a similar stall of the same tester (guest stopped in the teardown of an LE case, no Total) on
another kernel/tester pairing, so a pre-existing tester flake is plausible; not proven.

## 5. The list bot's checks, kernel (`scripts/bot-ci-local.sh`, base vs patched)

Run: `scripts/bot-kernel.sh bot-kernel-v2c` (base `da3cc0258`, BlueZ `20ffd285b58f`, the three
patch mails; the cover letter is not fed to `git am`). Output `project/tmp/bot-kernel-v2c/`
(`summary.txt`, `patched/report.txt`, `base/report.txt`, `compare-*.txt`). Bot image
`bluez-action-ci:60348956fc7b`. Two earlier attempts failed at the setup, not at a check
(`bot-kernel-v2`: the cover mail is an empty patch; `bot-kernel-v2b`: the container could not see
the mails outside the project).

| Check | Patched | Base | Comment |
|---|---|---|---|
| BuildKernel, CheckAllWarning, CheckSparse, BuildKernel32, CheckKernelLLVM | PASS | PASS | |
| TestRunnerSetup and all 11 TestRunner_* (incl. sco, l2cap, mgmt, iso) | PASS | PASS | `not-passed sets identical: True (A 0, B 0)` for all 11; the bot's sco-tester is the unpatched BlueZ one (30 cases) |
| IncrementalBuild | PASS | n/a | |
| SubjectPrefix | PASS | n/a | |
| kernel-report-scan on the bot's tester logs | exit 0 | exit 0 | |
| **CheckPatch** | FAIL | n/a | the only finding on each patch: `ERROR: Missing Signed-off-by` (1 error, 0 warnings, 0 checks) |
| **GitLint**, **VerifySignedoff** | FAIL | n/a | the missing Signed-off-by only |
| **VerifyFixes** | FAIL | n/a | patch 3 only: "Target SHA1 does not exist" for `10c62ddc6f03`. **Artifact of the clone** (history since 2023-01-01 only): the commit exists, "Bluetooth: Parameters for outgoing SCO connections", 2013-08-21 (`api.github.com/repos/torvalds/linux/commits/10c62ddc6f03`), and is an ancestor of bluetooth-next `da3cc02587c6` (compare API: `status: ahead`, `ahead_by 1115858`). Patches 1 and 2 pass |

Same patch-level checks on copies of the mails with a `Signed-off-by` of the author added (local
check only, `scripts/bot-kernel-sob.sh`, `scripts/add-sob.py`): **CheckPatch PASS, GitLint PASS,
VerifySignedoff PASS, SubjectPrefix PASS** (`project/tmp/bot-kernel-sob/summary.txt`). So with the
operator's own Signed-off-by the patch-level checks are clean; the bot's CheckPatch runs without
`--strict` (see section 1).

Stable heads, textual apply (scratch copy of `hci_conn.c` from `cache/stable-{6.6,6.12,6.18,7.2}.y`,
`scripts/stable-check.sh`, `logs/stable-check.txt`): patches 1, 2, 3 apply in order to all four with
offsets only. This says nothing about which trees contain the `Fixes:` commits.

## 6. The list bot's checks, BlueZ (`--space user`)

Two runs (`scripts/bot-bluez.sh`, `scripts/bot-bluez-final.sh`; outputs `project/tmp/bot-bluez-v2/`,
`project/tmp/bot-bluez-final/`), base BlueZ `20ffd285b58f`, the two sco-tester patch mails (no
Signed-off-by), `--kernel-image` = the p123 guest kernel.

- **First run** (mails before the fixes below): CheckPatch **WARNING on patch 2** (three lines of 81
  columns: `tester_print("Holding back the Synchronous Connection Complete")`, a `tester_warn()`
  and a declaration line) and GitLint **FAIL** (a) the notes block `git format-patch --notes` writes had
  4-space blank lines = trailing whitespace on patch 1, (b) patch 2's title was 85 > 80 characters
  with the bot's `[BlueZ,v2,2/2]` prefix. Real findings, fixed: lines wrapped, notes' blank lines
  made empty (`scripts/strip-notes-ws.py`), patch 2 renamed "tools/sco-tester: Add connect twice
  with other voice tests". Its TestFunctional: **PASS (53 passed, 1 skipped, 11 deselected)**.
- **Final mails** (patched side only, the checks the fixes can change): CheckPatch **PASS**,
  GitLint **PASS**, BuildEll PASS, BluezMake PASS (ASan/UBSan build, no warning), IncrementalBuild
  PASS, **CheckSmatch WARNING**: `./lib/bluetooth/bluetooth.h:351:15: warning: array of flexible
  structures` (and `:356:31`) "in included file" of `tools/sco-tester.c`. It comes from the unmodified
  header; the same note was the only non-PASS on v1 (README of the dossier, 2026-10-28: "all PASS but
  the expected CheckSmatch note"). **The first run's base side (completed 07:41) also gives CheckSmatch
  WARNING**, so the note pre-exists on master; base BuildEll, BluezMake, bluezmakeextell,
  TestFunctional and ScanBuild PASS; patched (first mails) BuildEll, BluezMake, bluezmakeextell,
  TestFunctional (53 passed), IncrementalBuild and ScanBuild PASS. Only CheckPatch/GitLint (fixed, above)
  and the same CheckSmatch note differ from base.
- The final `sco-tester` binary (`v2c`) differs from the one in the first bot run and in the first
  guest matrix (`v2b`) only in those line wraps (`git diff` of the commit amend); the guest matrix was
  repeated with `v2c` (section 4), same result.

## 7. Commands that produced the numbers

    scripts/build-kernel.sh <tag> <ref>            # base, p12, p123, parkA, parkB (make -j4)
    scripts/build-bluez.sh v2b | v2c                # sco-tester etc. from ../bluez (ASan build, -j4)
    scripts/run-matrix.sh <label> <runs> <kernels> <tester tag> <tester> [args]
    scripts/summarize.py <label> <kernels>          # per-case pass counts
    scripts/results.sh                              # writes results/*.txt
    scripts/bot-kernel.sh / bot-bluez.sh / bot-bluez-final.sh / bot-kernel-sob.sh
