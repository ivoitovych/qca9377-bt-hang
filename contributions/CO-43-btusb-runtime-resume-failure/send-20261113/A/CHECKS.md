# A — checks, with commands and results (2026-11-13)

All paths are under `/root/exp/agent-work/co43-ea-send-20261113/` unless absolute. Nothing was
sent; nothing touched this machine's Bluetooth (the kernel ran in a QEMU guest).

## The patch and the tips

| | |
|---|---|
| patch | `0001-Bluetooth-btusb-Report-a-failed-runtime-resume-for-d.patch`, from commit `5d5bdb6ee077` (branch `ea-a-20261113`) |
| bluetooth-next tip | `da3cc02587c629420603df4395179ec82955c941` (2026-11-12 14:37 -0500) |
| bluetooth tip | `3b069de8a5d688c7e8381b99d6cdb7467fcae0de` (2026-11-12 14:35 -0500) |

Fetched today (`git ls-remote` and `git fetch` of both masters, as in `../E/CHECKS.md`);
`drivers/bluetooth/btusb_main.c` is identical on both tips.

**Changed against the reviewed patch:**
- the subject ("runtime");
- the message, reworded after the reviews: no claim that nothing else logs the failure, that
  `-EACCES` is system sleep only, or that `btusb_resume()` always sends the data;
- the comment, now the one line `/* -EACCES: runtime PM is disabled, e.g. during system sleep */`.

The code is otherwise unchanged: the two patch files' diffs differ only in the comment (read side
by side).
The patch ids differ for that reason: `0a6b0596…` (project `patch/0001`), `bd3d8cdf…` (the
package; `scripts/patch-ids.sh`).

## Applies and builds: alone, and with E in either order, on both tips

`scripts/apply-build.sh` (logs `build/apply-build-bluetooth-next.log`, `build/apply-build-bluetooth.log`):

```
RESULT bluetooth-next unpatched build rc=0
RESULT bluetooth-next A git-am=OK build rc=0 warnings_or_errors=0
RESULT bluetooth-next E+A git-am=OK build rc=0 warnings_or_errors=0
RESULT bluetooth-next A+E git-am=OK build rc=0 warnings_or_errors=0
RESULT bluetooth unpatched build rc=0
RESULT bluetooth A git-am=OK build rc=0 warnings_or_errors=0
RESULT bluetooth E+A git-am=OK build rc=0 warnings_or_errors=0
RESULT bluetooth A+E git-am=OK build rc=0 warnings_or_errors=0
```

(`W=1`, `drivers/bluetooth/btusb_main.o`, the guest config.) The full guest kernel with A alone
(`img/bzImage-ea-a`) built as well (`build/build-all.log`).

## checkpatch `--strict`

`scripts/checkpatch-docker.sh <patch>` (the tree's checkpatch in the list bot's image):

```
ERROR: Missing Signed-off-by: line(s)
total: 1 errors, 0 warnings, 0 checks, 14 lines checked
```

The only finding is the Signed-off-by you add. Control: with a Signed-off-by line added
(`tmp/checkpatch-control/A-with-sob.patch`): `total: 0 errors, 0 warnings, 0 checks, 14 lines
checked`, "no obvious style problems and is ready for submission".

## get_maintainer.pl

`scripts/get-maintainer-docker.sh <patch>`:

```
Marcel Holtmann <marcel@holtmann.org> (maintainer:BLUETOOTH DRIVERS)
Luiz Augusto von Dentz <luiz.dentz@gmail.com> (maintainer:BLUETOOTH DRIVERS)
linux-bluetooth@vger.kernel.org (open list:BLUETOOTH DRIVERS)
linux-kernel@vger.kernel.org (open list)
```

## The emulator run: the dead device, base + A

The harness (`stress/harness/`), its `bt17` scenario unchanged: the emulated QCA9377 autosuspends,
a MGMT Set Device Class starts a resume whose GET_STATUS the device never answers, and the device is
dead afterwards (`--fail-at 1`). Kernel `ea-a` = bluetooth-next + A (`7.3.0-g5d5bdb6ee077`),
KASAN, lockdep, hung-task detector, kmemleak.

```
$ stress/harness/run-guest.sh ea-a a-bt17-2 bt17 --fail-at 1
Bluetooth: hci0: command 0x0c24 tx timeout
Bluetooth: hci0: Failed to resume device for deferred data: -16
Bluetooth: hci0: Failed to resume device for deferred data: -16
  10.793 [mono  16.594006] RESULT bt17 fail_at=1 recover=False class-write-status=0x05 hci0_removed=True back=False powered=False class_write_after=none
run-guest: ea-a a-bt17-2 verdict=BT17-EXIT 0 exit=0
```

Exit 0: the scenario's success condition held (the dead device is removed). The kernel's own
sequence (`stress/logs/ea-a-a-bt17-2.log`, kernel time):

| | kernel time |
|---|---|
| Set Device Class sent | 9.378 |
| `command 0x0c24 tx timeout` | 11.412 |
| `retry with reset-resume` | 14.645 |
| `gone after usb resume? status -19` | 16.532 |
| **`Failed to resume device for deferred data: -16`** (the new line) | 16.533 |
| `Failed usb_autopm_get_interface: -16` (btusb's reset path, already there before A) | 16.533 |
| `USB disconnect, device number 2` | 16.534 |
| **`Failed to resume device for deferred data: -16`** (the waker's second run) | 16.534 |

The new line names the failed resume and its error. As the reviewers said, the existing
`Failed usb_autopm_get_interface` line appears at the same moment; the message no longer says
otherwise. An earlier run with the harness revision of that time
(`stress/logs/ea-a-a-bt17-1.log`) gave the same result: exit 0, the new line twice, -16.
`kernel-report-scan.py` over both logs: clean (`stress/kernel-report-scan.txt`).

## Bot CI

The project's `scripts/bot-ci-local.sh` from this work directory's clone, as for E: the bot's code
(action-ci `c7d077f185cd`, image `bluez-action-ci:c7d077f185cd`), the same three local changes
(`../E/CHECKS.md`, "Bot CI"), base bluetooth-next `da3cc02587c6`, BlueZ `20ffd285b58f`. Results in
`project/tmp/bot-ci-local/A4-20261113/` (`work/` deleted after the run). The patched side only: the
base side is the same commit, and it passed every tree check in E's run (BuildKernel,
CheckAllWarning, CheckSparse, BuildKernel32, CheckKernelLLVM, TestRunnerSetup:
`project/tmp/bot-ci-local/E4-20261113/base/`).

```
CheckPatch                    FAIL     (only: ERROR: Missing Signed-off-by: line(s))
VerifyFixes                   PASS     (A has no Fixes: tag)
VerifySignedoff               FAIL     (author and committer Signed-off-by missing)
GitLint                       FAIL     (only: CC1 Body does not contain a 'Signed-off-by' line)
SubjectPrefix                 PASS
BuildKernel                   PASS
CheckAllWarning               PASS
CheckSparse                   PASS
BuildKernel32                 PASS
CheckKernelLLVM               PASS
TestRunnerSetup               PASS
IncrementalBuild              PASS
```

No tester is selected for a btusb-only change. Every failure is the missing Signed-off-by.
