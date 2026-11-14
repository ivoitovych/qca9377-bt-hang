# CO-41 checks (2026-11-14)

Master used: `20ffd285b58facfd1f2478d159a5f941b09d5be1` (2026-11-12, "shared/gatt-client: Track pending discovery Database Hash reads"), fetched from https://github.com/bluez/bluez at 2026-11-14.
Work clone: `/root/exp/agent-work/lane4-bluez-20261114/bluez` (branch `co41`; `co41-testonly` = master plus patch 2 only).
Clock: host-local times in the logs are UTC+1; harness.log lines are UTC.

## Upstream state (checked 2026-11-14)

- **Not fixed on master** (measured): `emulator/btdev.c` `cmd_io_cap_negative_reply()` at 20ffd285b still ends with `ssp_complete(dev, cmd->bdaddr, BT_HCI_ERR_AUTH_FAILURE, false);`. Command: `git -C bluez show 20ffd285b:emulator/btdev.c`, lines 3510-3525.
- **No posted equivalent** (measured): `python3 -I scripts/patchwork-recent.py 2026-10-15 "io.cap|negative|reason|AuthenticationRejected|ssp|emulator|btdev"` listed 33 of 895 patches since 2026-10-15; none changes the negative-reply handling (the emulator ones are the HDT series, the VLA fix, vhost-user/time-travel, advertising sets).
- **No tester reaches the case today** (measured): `bthost.c` never sends IO Capability Request Negative Reply (grep of `emulator/bthost.c`: only `BT_HCI_CMD_IO_CAPABILITY_REQUEST_REPLY`). The only existing negative reply in the testers is the kernel's own, in `Pairing Acceptor - SSP 4` (`mgmt-tester.c`, `client_io_cap_reject_param_func`, reason 0x18), whose Authentication Failed event was checked for length 8 only.

## The patches

```
0001-emulator-Use-the-reason-of-IO-Capability-Request-Neg.patch   emulator/btdev.c   +1 -1
0002-mgmt-tester-Check-the-status-of-Authentication-Faile.patch   tools/mgmt-tester.c +34
```

1. `emulator: Use the reason of IO Capability Request Negative Reply` — `ssp_complete(dev, cmd->bdaddr, cmd->reason, false)`.
2. `mgmt-tester: Check the status of Authentication Failed in SSP 4` — `verify_auth_failed_rejected()` (address, address type BR/EDR, status `MGMT_STATUS_REJECTED`) wired into the existing case `Pairing Acceptor - SSP 4` by `.verify_alt_ev_func`. No new case, no change to any other case.

Chain (inferred from source, and the test measures its first two links): the host answers the IO Capability Request with reason 0x18 -> emulated controller sends Simple Pairing Complete(0x18) -> kernel `hci_simple_pair_complete_evt()` -> `mgmt_auth_failed()` -> `mgmt_status_table[0x18]` = `MGMT_STATUS_REJECTED` -> `src/device.c` maps `MGMT_STATUS_REJECTED` to `org.bluez.Error.AuthenticationRejected`. The mgmt event status is what the tester now checks; the D-Bus error is not exercised by a tester (not tested).

Author line: Iaroslav Voitovych <yaroslav.voytovych@gmail.com>. No Signed-off-by (BlueZ doc/maintainer-guidelines.rst, Rule 2).

## Results

### Decisive: the case fails on the base and passes patched (measured)

Command: `co41/scripts/run-testonly-vs-fix.sh` (wraps `scripts/bluez-tester-compare.sh --kernel project/tmp/kernel/bzImage-base --tree bluez --base co41-testonly --testers mgmt-tester --runs 3 --jobs 4 ... <patch 1>`).
Base = master + patch 2 (test only, `cce87ff5b`); patched = base + patch 1. QEMU/KVM guest, BlueZ built with ASan (the bot's TestRunnerSetup), kernel = bluetooth-next `da3cc0258` (2026-11-12) with `doc/tester.config`.
Log: `logs/tester-testonly-vs-fix/summary.txt`.

```
mgmt-tester base    run 1..3: Total 526, Passed 525, Failed 1
mgmt-tester patched run 1..3: Total 526, Passed 526, Failed 0
Pairing Acceptor - SSP 4: base [Failed x3] patched [Passed x3]
cases with identical verdicts on both sides: 525   REGRESSIONS: 0
```

The base failure, quoted from `logs/tester-testonly-vs-fix/mgmt-tester.base.1.log` lines 10235-10237: `Authentication Failed status 0x05 != 0x0b` / `Incorrect Authentication Failed event parameters` / `Pairing Acceptor - SSP 4 - test failed`. 0x05 is Authentication Failure, the value the emulator sent whatever the host said; 0x0b is `MGMT_STATUS_REJECTED`.

### The rest of the tester unchanged (measured)

Master vs master + both patches, same kernel, 3 runs each: `logs/tester-compare/summary.txt`.

```
mgmt-tester base    run 1..3: Total 526, Passed 526
mgmt-tester patched run 1..3: Total 526, Passed 526
526 case names, identical verdicts on both sides: 526, REGRESSIONS: 0
```

Only mgmt-tester was run. The other emulator testers (l2cap-, sco-, iso-, mesh-tester, ...) were not run; only the SSP path in btdev.c changed and the unit tests do not use it (not tested for the other testers). The bot's TestFunctional (below) boots btvirt guests, which use btdev too.

### make check (measured)

`co41/scripts/build-check.sh`, container `co03-noble-build:1`, log `logs/build-check-patched.log`: `# TOTAL: 35 # PASS: 35 # FAIL: 0`, `make exit 0`; no compiler warning in the log (grep `warning:` finds only make's jobserver notice).

### checkpatch and the bot's other checks (measured)

`co41/scripts/bot-ci.sh` = `scripts/bot-ci-local.sh --space user --base 20ffd285b... --tree bluez --cache <lane cache> --kernel-image tmp/kernel/bzImage-base <both mails>`; image `bluez-action-ci:c7d077f185cd` (github.com/bluez/action-ci main, `c7d077f1`), ELL `002b32d7c091`. Output: `logs/bot-co41-r2/` (`summary.txt`, `patched/`, `base/`). Exit 0.

| check | patched (master + 2 patches) | base (master) |
|---|---|---|
| CheckPatch | PASS (0 errors, 0 warnings on both mails: 8 and 46 lines) | not run by the bot on base |
| GitLint | PASS | not run |
| BuildEll | PASS | PASS |
| BluezMake | PASS | PASS |
| CheckSmatch | PASS | PASS |
| bluezmakeextell | PASS | PASS |
| TestFunctional | PASS (53 passed) | PASS (53 passed) |
| IncrementalBuild | PASS | not run |
| ScanBuild | PASS | PASS (the bot never checks out the base for ScanBuild, so this is the patched tree compared with itself; see tooling-index) |

The bot picked no unit-test check for these files. A first attempt (`project/tmp/bot-co41/`, not kept) stopped at once because the mails were outside the container mount; the second run is the one above. TestFunctional's pytest line on each side: `53 passed, 1 skipped, 11 deselected`.

### Not done

- D-Bus level: no run shows `Device1.Pair` returning `AuthenticationRejected` against an emulated refusing peer (the tester stops at the mgmt event). A functional-suite test for it would need a peer that refuses; not written.
- Other testers (see above), other kernels (only bluetooth-next `da3cc0258` was used; the new check depends on that kernel mapping 0x18 to `MGMT_STATUS_REJECTED`, which older kernels were not checked for).
