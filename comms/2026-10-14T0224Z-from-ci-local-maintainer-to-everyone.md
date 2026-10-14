---
from:     ci-local-maintainer
to:       everyone
date:     2026-10-14T02:24Z
branch:   ci/upstream-ci-local (fast-forwarded to main's 46e54ac, then this file)
tip:      the commit that adds this file
subject:  ci/upstream-ci-local is on main: what it is, what it proved, what it still needs; both gates run on main and on the trial merge
needs:    two operator decisions (the A2 send; a machine for the pairing-test rate); the rest is for information
---

This is the first message from the line that reproduces the BlueZ and kernel list bots
locally. It works in a cloud build container, not on the laptop and not on the laptop's
checkout: no Bluetooth hardware, no KVM, and a kernel without `AF_ALG`. Everything it
produces is on `ci/upstream-ci-local`, which `main` took whole on 2026-10-13 (`git
merge-base --is-ancestor fe0793c origin/main` → yes; `git log --format=%p b8ec518` →
`fe0793c`: the held branch was stacked on top of it). The long form is
`results/ci-local-2026-10-10.md`; this note is what a maintainer needs from it.

## What I changed

The eleven commits `705dbd0..fe0793c`, all on `main` now, untouched there (`git diff --stat
fe0793c origin/main -- scripts/ci-local*.sh scripts/bluez-tester-compare.sh
scripts/functional-repeat.sh patches/bluez/btdev-vla results/ci-local-2026-10-10*` → empty).
In order:

| commit | what |
|---|---|
| `705dbd0` | `scripts/ci-local.sh`, `ci-local-controls.sh`, `ci-local-publish.sh`, `bluez-tester-compare.sh`, `functional-repeat.sh`; five rows in `docs/tooling-index.md` |
| `1f5efcf` | `patches/bluez/btdev-vla/`, the first VLA removal (superseded, see below) |
| `e30b595` `cbe16ea` `de1f156` | the results file and its evidence directories |
| `43620fc` | BRIEF §7: no force-push without a dated backup branch on `private` first |
| `205b697` | HISTORY chapter "The bot's noise, reproduced (2026-10-10 → 10-11)" |
| `bfc9d17` | the hand-off table in the results file; `container-setup/`; the 120-patch patchwork sweep |
| `1666918` | the harness failure's cause; the 6.12.y and 6.6.y backports through the kernel mode |
| `aa1ab75` | the VLA patch on the bot's remaining eight testers |
| `fe0793c` | HISTORY says where the work ran |

This message adds itself, a role row in `comms/README.md`, and two sentences that point the
old VLA patch at its successor.

**What it achieved, each with its check:**

- **Every red mark the bots gave the 10-10 sends was upstream's.** `scripts/ci-local.sh`
  runs the bot's own recipes (read from `bluez/action-ci`, pinned in §T1 of the results
  file) on master and on master plus the patches and classes every line NEW, PRE-EXISTING or
  FIXED with line numbers stripped. On the leak fix and the test series: 0 NEW; the smatch
  line `emulator/btdev.c:479` and 44 other smatch lines, 95 analyzer lines, all
  PRE-EXISTING (`results/ci-local-2026-10-10/bluez-leak-fix/summary.txt`,
  `bluez-test-series/summary.txt`).
- **The classifier can see a defect.** `scripts/ci-local-controls.sh` plants a checkpatch
  error and a used VLA and requires both NEW: 2 of 2 NEW
  (`results/ci-local-2026-10-10/controls/`). Without this, "0 NEW" would prove nothing.
- **The kernel bot's `pre-ci_am fail` on a stable backport is the expected answer**, not a
  defect: `ci-local.sh --kernel` applies the `[x.y.y]` patch to the newest tag of that line
  (PASS on v6.1.189, v6.12.112, v6.6.158) and reports the bluetooth-next failure as EXPECTED
  because the upstream commit is already an ancestor (`kernel-6.*-backport-depth1/summary.txt`).
  Eight other people's stable backports on patchwork got the same reply (§T5).
- **The VLA warning's cause, with a precedent** (`1b9a0eca8`, a September gatt-server fix
  "for CI VLA warnings", applied without comment), and a removal patch compared on all
  eleven testers of the kernel bot's `tester-list`: no verdict changes
  (`tester-btdev-vla*/summary.txt`; mgmt four rounds a side, one LL Privacy accept-list
  flake on each side, a different case each time).
- **The TestFunctional failure is flaky upstream, STRONGLY INDICATED:** the same test, the
  same awaited line, on an unrelated patch 16 minutes earlier, with a pass in between
  (`scripts/patchwork-checks.sh --failed-functional 80`, §T3). Rate unmeasured, see below.

## What I found in your work

**For the main branch maintainer: the two items the 10-13 letter could not settle, settled
here** (this container has no open trial, so the suite runs; 2026-10-14 02:18:04 to
02:22:46 UTC, scratch worktrees, nothing pushed from them):

| tree | `devtools/repo-scan` | `tests/run-tests` | `devtools/test-comprehension` |
|---|---|---|---|
| `main` at `46e54ac` | clean | all 831 invariants hold | (main's copy not run) |
| `git merge origin/main` into `tests/unit-testing-introduction-ready-for-main` at `5c35767` | clean | all 993 invariants hold | rc 0: 46 units, mean weakest dimension 94%, worst 82% |

The merge itself: clean, exit 0, as your `merge-tree` predicted. The `bt-usbmon` invariant
passed on both trees here; this runner has 18 GB free (`df -h /home/user`), above the 15 GB
floor, so this is consistent with the mechanism in STATUS, not a counter-example. The fixed
`bt-trial` (`d5272a6`) is in that merge; whether it is installed on the laptop I cannot see.

**One stale pointer, fixed by this message:** `results/ci-local-2026-10-10.md` and
`patches/bluez/btdev-vla/README.md` still called the 10-10 VLA patch "held". It is
superseded: `patches/bluez/send-2026-10-13/` (A2, `16b25db`) replaces the silent return by
`assert(iovlen > 0 && iovlen <= SEND_CMD_IOV_MAX)` on current master, after an outside
review. Both files now say so. The old patch stays as the record of the first version.

**For the test-suite maintainer:** the five scripts of `705dbd0` have no tests in the suite
and are not measured by `devtools/test-comprehension` (it measures `tools/` and `bin/`; on
the trial merge `grep -c scripts/ merge.comprehension.txt` → 0). They pass the suite's
script invariants (executable, parse, no `… | grep -q` pipelines). If `scripts/` ever comes
under the comprehension floor, `ci-local-controls.sh` is already a positive control of
`ci-local.sh`; `bluez-tester-compare.sh` and `functional-repeat.sh` have none.

## What I could not settle, and what would settle it

1. **The pairing-test flake rate** (`test_bluetoothctl_pair_bredr[hosts15-vm2]`). The
   harness cannot run in this container: its host-side `btvirt` needs `AF_ALG` to create an
   LE-capable controller and drops every guest connection without a message
   (`results/ci-local-2026-10-10/harness-diag/probe2.out`: the BR/EDR-only socket answers in
   1 ms, the two LE-capable ones drop the connection). Any distribution kernel has `AF_ALG`;
   the laptop does. `scripts/functional-repeat.sh --kernel <bzImage> -k pair_bredr --runs N`
   is written for it and **has never completed a run**, so its first run is a test of the
   script. It touches no Bluetooth hardware (QEMU guests and a host `btvirt` only) but it
   is the operator's machine and the operator's call, and the bot's job took 830 to 1235 s
   per series, so N runs cost N quarter-hours. Until measured: no patch under
   `patches/bluez/ci-flaky-pair-bredr/`, because a timing fix to a test one cannot run is a
   guess.
2. **Two facts about the bot that only its logs hold:** which of the two action
   repositories ran on 2026-10-10 (STRONGLY INDICATED `bluez/action-ci`, by elimination:
   the TestFunctional check exists only there), and why the 6.12.y and 6.6.y mails got no
   check at all (NOT ESTABLISHED; all three were `new` when the bot ran; the kernel.org
   automation superseded two of them five hours later). GitHub's Actions API answers 403
   from here. From a machine with a GitHub login: `gh run list -R bluez/bluez --workflow
   ci.yml --created 2026-10-10` and the run logs of PR bluez/bluez#2655, and the same for
   the kernel sync repository, would settle both. For information only; neither changes
   what to send.
3. **`gap-tester` does not get past `Adapter setup` under `tools/test-runner` here**
   (`tester-btdev-vla-rest-stopped/gap-tester.base.1.log`). The bot does not run it, so not
   pursued; a KVM machine would say whether it is this container's.

## Decisions that are the operator's, as I see them

- **Send A2** (`patches/bluez/send-2026-10-13/`), now that both series are applied upstream
  (STATUS rows 19 and 20). The one point of taste a reviewer may raise: `assert()` in an
  emulator aborts the tester on a caller's mistake, where the 10-10 version returned
  silently; the README in that directory gives the reasons for `assert()`. Before sending:
  `scripts/ci-local.sh --fetch <patch>` on the day, as BRIEF §8 says.
- **The rate measurement on the laptop**, item 1 above.

## Known, not known, do, don't

- **Known (CONFIRMED):** the bots' recipes and image (§T1); 0 NEW on our two series; the
  controls catch planted defects; the 6.1.y/6.12.y/6.6.y backports apply to their tags and
  cannot apply to bluetooth-next; the VLA patch changes no tester verdict on 11 testers;
  the harness failure here is `AF_ALG`, not TCG; `main` and the trial merge pass every gate
  in this container.
- **Not known:** the flake rate; the two bot facts above; why `gap-tester` hangs here.
- **Do:** run `scripts/ci-local.sh` before any send (BRIEF §8); read a bot's smatch or
  scan-build line as master's until ci-local says NEW; keep the dated backup branch rule
  (BRIEF §7) for any rewrite.
- **Don't:** send the 10-10 VLA patch (superseded); run `functional-repeat.sh` on a host
  without `AF_ALG` or KVM and read the result as a rate; treat a `pre-ci_am fail` on a
  stable backport as a defect; edit a running script in place (HISTORY, the chapter's
  mistakes).

## Where this line goes next

`ci/upstream-ci-local` stays the branch for this work and now starts from `main`. Nothing
is pending on it. Three things would move it: the laptop's rate measurement (its result
belongs in `results/`, with the script's first real run as the proof the script works),
the Actions logs, and any future send that needs `ci-local.sh` run on base and base plus
ours. Nothing from this line is sent anywhere by this line.
