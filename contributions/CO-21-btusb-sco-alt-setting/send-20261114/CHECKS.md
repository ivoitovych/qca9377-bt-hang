# CO-21 - checks, with commands and results (2026-11-14)

Paths are under `/root/exp/agent-work/lane1-btusb-20261114/` (the work directory) unless absolute.
Nothing was sent. Nothing touched this machine's Bluetooth (every kernel ran in a QEMU guest or in the
bot's Docker image).

## The patches and the tip

| | |
|---|---|
| patches | `0001-Bluetooth-Keep-the-air-mode-of-SCO-links-that-came-u.patch`, `0002-Bluetooth-btusb-Pick-the-SCO-alt-setting-from-links-.patch` (this directory), exported from branch `lane1-co21` of `lx/` (`b3081ed5919f`, `18500f5259e2`) |
| bluetooth-next tip | `da3cc02587c629420603df4395179ec82955c941` "Bluetooth: hci_vhci: Report write readiness with queued input" (`git ls-remote https://git.kernel.org/pub/scm/linux/kernel/git/bluetooth/bluetooth-next.git refs/heads/master` returned it on 2026-11-14) |
| from | the patches of `contributions/CO-21-btusb-sco-alt-setting/patches-20261101/` (base `42b8c2d72926`), applied to the tip with `git am --3way`: no conflict. Changes: patch 2's subject (75 to 65 characters, "alternate" to "alt", "the links" to "links"), the Signed-off-by lines removed |
| `Fixes:` target | `baac6276c0a9f36f1fe1f00590ef00d2ba5ba626` "Bluetooth: btusb: handle mSBC audio over USB Endpoints", 2020-04-03 (`git log -1`, found in the history) |

## checkpatch `--strict`

`harness/checkpatch-docker.sh <patch>` (the tree's `scripts/checkpatch.pl --strict` in the list bot's image,
commit ids resolved in the project's `cache/linux`):

```
== checkpatch --strict 0001-...
ERROR: Missing Signed-off-by: line(s)
total: 1 errors, 0 warnings, 0 checks, 63 lines checked
== checkpatch --strict 0002-...
ERROR: Missing Signed-off-by: line(s)
total: 1 errors, 0 warnings, 0 checks, 65 lines checked
```

The only finding on each is the Signed-off-by you add. (Plain `perl scripts/checkpatch.pl --strict --no-tree`
gives the same, plus the no-tree warning for the `Fixes:` id on patch 2.)

## get_maintainer.pl

`harness/get-maintainer-docker.sh <patch>` (default options, top of the tree, bot image):

```
0001: Marcel Holtmann <marcel@holtmann.org> (maintainer:BLUETOOTH SUBSYSTEM)
      Luiz Augusto von Dentz <luiz.dentz@gmail.com> (maintainer:BLUETOOTH SUBSYSTEM)
      linux-bluetooth@vger.kernel.org (open list:BLUETOOTH SUBSYSTEM)
      linux-kernel@vger.kernel.org (open list)
0002: Marcel Holtmann <marcel@holtmann.org> (maintainer:BLUETOOTH DRIVERS,blamed_fixes:1/1=100%)
      Luiz Augusto von Dentz <luiz.dentz@gmail.com> (maintainer:BLUETOOTH DRIVERS)
      Hsin-Yu Chao <hychao@chromium.org> (blamed_fixes:1/1=100%)
      Chethan T N <chethan.tumkur.narayan@intel.com> (blamed_fixes:1/1=100%)
      Johan Hedberg <johan.hedberg@intel.com> (blamed_fixes:1/1=100%)
      Amit K Bag <amit.k.bag@intel.com> (blamed_fixes:1/1=100%)
      linux-bluetooth@vger.kernel.org (open list:BLUETOOTH DRIVERS)
      linux-kernel@vger.kernel.org (open list)
```

## VerifyFixes with full history

The bot's patched-side run has a partial history here (the project's kernel repository has holes: "Could not
read 10d97b74e2ee"), so its VerifyFixes says "Target SHA should be an ancestor of your tree". The bot's own
`verify_fixes.sh` on patch 2's message, committed on mainline master in a repository with the complete
history (`harness/verifyfixes-full.sh`, output `logs/verifyfixes-full-0002-...txt`):

```
== verify_fixes.sh master..37e815da42ba (0 Signed-off-by line(s))
	Fixes tag: Fixes: baac6276c0a9 ("Bluetooth: btusb: handle mSBC audio over USB Endpoints")
	Has these problem(s):
		- empty lines surround the Fixes tag
== exit 1
== verify_fixes.sh master..2026116af3f3 (1 Signed-off-by line(s))
== exit 0
```

Without a Signed-off-by, `Fixes:` is the body's last line, which the script reads as surrounded by empty
lines. With your Signed-off-by right after it, VerifyFixes passes: id, subject and ancestry are right. The
same as CO-43 E.

## The five usbip scenarios, base against patched, on the rebased tree

The emulator of 2026-11-11 (`harness/usbip-bt-emu.py`, `usbip-bt-emu.py` of the CO-21 results; the only change is
that it exits non-zero on FAIL and prints `BT17-EXIT`): a userspace controller attached to `vhci_hcd` in a QEMU
guest (4 CPUs), the real btusb and core. Kernels: `base` = bluetooth-next `da3cc02587c6` (image of the
CO-43 emulation work, same config family), `co21` = the same plus the two patches (`img/bzImage-co21`, KASAN
and lockdep config of `img/config-co21`). Commands: `harness/run-batch-usbip.sh harness/spec-co21.txt
logs/summary-co21.txt`; logs `logs/runs/*-c21-*.log` (`logs/SHA256SUMS`).

| scenario | base (2 runs) | patched (2 runs) |
|---|---|---|
| msbc-two-links-first | FAIL, FAIL | PASS, PASS |
| msbc-two-links-second | FAIL, FAIL | PASS, PASS |
| cvsd-two-links-first | FAIL, FAIL | PASS, PASS |
| msbc-single-race | FAIL, FAIL | PASS, PASS |
| cvsd-single-race | FAIL, FAIL | PASS, PASS |

Unpatched: 0 of 10; patched: 10 of 10. The same as 2026-11-11 (5 of 5 each way). In each failing run the
alternate setting is wrong at the step the scenario names (alt 0 after one of two links hangs up, or never
set after the single-link race), in the logs' `STATE ... WRONG` lines.

## The bot's CI, run locally

`harness/run-bot-co21.sh`: the project clone's `scripts/bot-ci-local.sh` (`project/`, a clone of the project made
in this work directory), the list bot's own code (action-ci `c7d077f185cd`, image
`bluez-action-ci:c7d077f185cd`) in Docker, dry run, nothing posted. Base `da3cc02587c6`, BlueZ `20ffd285b58f`,
ELL `002b32d7c091`. Results: `project/tmp/bot-ci-local/co21-20261114/` (`summary.txt`, `patched/`, `base/`,
`compare-*.txt`, `kernel-report-scan.txt`; the `work/` tree deleted after the run).

Local changes to that clone's script (each marked in it): the three of the CO-43 E package (the patched side
gets a `--shared` clone of this tree instead of kernel.org's blobless history clone, which is slow; the
tree's common git directory mounted read-only; Docker limited to 6 CPUs), and a read-only mount of the
tree's object-store alternates.

| check | patched (base + 2 patches) | base |
|---|---|---|
| CheckPatch | FAIL: only `Missing Signed-off-by` (both patches) | - |
| VerifyFixes | FAIL: `Target SHA should be an ancestor of your tree` (the project's partial history; passes with full history, see above) | - |
| VerifySignedoff | FAIL: author and committer Signed-off-by missing | - |
| GitLint | FAIL: only `CC1 Body does not contain a 'Signed-off-by' line` (no title-length message on either patch) | - |
| SubjectPrefix | PASS | - |
| BuildKernel | PASS | PASS |
| CheckAllWarning | PASS | PASS |
| CheckSparse | WARNING | WARNING (identical output: a `note: in included file` line for `hci_event.c`; the sparse log shows only existing "array of flexible structures" warnings in `hci.h` and `hci_core.h`, with the bot's own verdict line `PASS`) |
| BuildKernel32 | PASS | PASS |
| CheckKernelLLVM | PASS | PASS |
| TestRunnerSetup | PASS | PASS |
| TestRunner_* (l2cap, iso, bnep, mgmt, rfcomm, sco, ioctl, mesh, smp, userchan, 6lowpan) | all PASS | all PASS |
| IncrementalBuild | PASS | - |

`compare-TestRunner_*.txt`: the not-passed sets are identical on both sides for every tester (0 and 0), including
`TestRunner_sco-tester`. `kernel-report-scan.txt`: every tester log of both sides is `clean`. Every failure
on the patched side is the missing Signed-off-by or the project's partial history; none comes from the change.

GitLint's title-length rule (80 characters) does not fire on either title (the new 65-character one, or the
old 75-character one: the README's "81 characters" was not reproduced). The bot's note on a `Fixes:` that is
the last line of the body is VerifyFixes's, handled by the position of your Signed-off-by.

## W=1 builds

`harness/build-kernel.sh co21`: the guest kernel build of the series (the config with KASAN and lockdep,
`-j4`): `make rc=0`. The bot's BuildKernel, CheckAllWarning (W=1 for the changed files), BuildKernel32 and
CheckKernelLLVM passed on the patched side (table above).
