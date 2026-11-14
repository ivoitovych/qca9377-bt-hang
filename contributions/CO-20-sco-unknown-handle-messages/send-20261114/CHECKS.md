# CO-20 - checks, with commands and results (2026-11-14)

Paths are under `/root/exp/agent-work/lane1-btusb-20261114/` unless absolute. Nothing was sent; nothing
touched this machine's Bluetooth (QEMU guests and the bot's Docker image only).

## The patches and the tip

| | |
|---|---|
| patches | `0001-Bluetooth-btusb-Report-SCO-receive-failures-by-cause.patch`, `0002-Bluetooth-btusb-Log-SCO-data-for-a-just-closed-link-.patch` (this directory), branch `lane1-co20` of `lx/` |
| bluetooth-next tip | `da3cc02587c629420603df4395179ec82955c941` (`git ls-remote` of kernel.org, 2026-11-14) |
| from | the 2026-11-11 prototype `0003-co20-...` and `0004-co20-...` (`results/laptop-only-work-2026-11-11/btusb-modules-and-emulator/patches/`), made for the older `btusb.c`; converted to `btusb_main.c` with `scripts/convert-patch.py` and applied with `git apply --3way`: clean. Messages kept, the review-free wording as in the prototype; no `Fixes:` tag; no Signed-off-by |
| the newline fix | mainline's `f51ee3bb5fbe` "Bluetooth: Add missing newline to bt_dev_{err,warn}_ratelimited()" is an ancestor of the tip (`git merge-base --is-ancestor`): `bt_dev_err_ratelimited()` ends its line, so the new messages are complete records |

## What the patches do (and do not)

1. Distinct errors from `btusb_recv_isoc()`: `-ENOMEM`, `-EILSEQ` (the length check, still "corrupted SCO
   packet"), `-ENOENT` (header whose handle is not a live link; its own message naming the handle, rate
   limited). All three still count in `err_rx`.
2. `-ENOTCONN`: the handle equals the last header that validated, i.e. data of the link that has just closed:
   debug level, not counted. The remembered handle is under `rxlock` and forgotten with the reassembly
   state, on an alternate-setting change, in `btusb_free_frags()`, and when the last SCO link is gone.
   Not changed: the core's "SCO packet for unknown connection handle" (`hci_core.c`), which the emulator
   still shows (1 to 6 per run); and with two links up, data of the closed link after a packet of the
   remaining one is still reported (the patch says so).

## checkpatch `--strict`

`harness/checkpatch-docker.sh <patch>` (bot image, tree `lx`):

```
== checkpatch --strict 0001-...   ERROR: Missing Signed-off-by: line(s)  total: 1 errors, 0 warnings, 0 checks, 67 lines checked
== checkpatch --strict 0002-...   ERROR: Missing Signed-off-by: line(s)  total: 1 errors, 0 warnings, 0 checks, 98 lines checked
```

The only finding is the Signed-off-by you add.

## get_maintainer.pl

`harness/get-maintainer-docker.sh <patch>`, the same output for both patches:

```
Marcel Holtmann <marcel@holtmann.org> (maintainer:BLUETOOTH DRIVERS)
Luiz Augusto von Dentz <luiz.dentz@gmail.com> (maintainer:BLUETOOTH DRIVERS)
linux-bluetooth@vger.kernel.org (open list:BLUETOOTH DRIVERS)
linux-kernel@vger.kernel.org (open list)
```

## Emulator, base against patched

The usbip emulator of 2026-11-11 (`harness/usbip-bt-emu.py`; changes: exits non-zero on FAIL, and a `JUDGE` of
the kernel's SCO receive messages with `--expect clean|noisy`): a userspace controller attached to `vhci_hcd`
in a QEMU guest (4 CPUs), real btusb and core. Kernels: `base` = bluetooth-next `da3cc02587c6`, `co20` = the
same plus the two patches (`img/bzImage-co20`). Commands: `harness/run-batch-usbip.sh harness/spec-co20.txt
logs/summary-co20.txt`, then `spec-co20-rerun.txt` -> `summary-co20-rerun.txt`; logs `logs/runs/*-c20-*.log`.

- **`rx-cycles`:** 20 times, one mSBC link up with SCO data flowing, hung up with data still in flight. Counts
  from `dmesg` per run:

  | run | base: "corrupted SCO packet" | patched: "corrupted" / "unknown handle dropped" / debug "closed handle" |
  |---|---|---|
  | 1 | 17 | 0 / 0 / 15 |
  | 2 | 19 (rerun `2b`; the first base run lost its emulator socket, `OSError 77`, no verdict) | 0 / 0 / 16 |
  | 3 | 24 | 0 / 0 / 18 |

  The patched kernel logs nothing above debug level for the hang-ups; the unpatched one logs an error for
  most of them.
- **`rx-unknown`:** two mSBC links up with data, a packet for a handle that is no link injected five times,
  then both closed.

  | runs | base: "corrupted SCO packet" | patched: "unknown handle dropped" (corrupted was 0 in every run) |
  |---|---|---|
  | first batch, 1 to 3 | 7, 7, 6 | 5, 6, 6 (runs 2 and 3 judged WRONG by the first, strict judge, below) |
  | rerun, `r1` to `r5` | 6 (`r1`) | 5, 7, 6, 6, 6 |

  The injected five are still reported, as `unknown handle dropped`, and none as `corrupted`. The extra one or
  two are data of the link that closed first, after a packet of the other: the limitation stated in patch 2.
  My first judge demanded exactly five and called runs 2 and 3 of the patched kernel WRONG; it is relaxed to "at
  least five and no `corrupted`" (`usbip-bt-emu.py`, `judge_counts()`), and the rerun runs `r1` to `r5` use it.
  The first runs are kept as they were.
- **The first batch:** 12 runs, exit 1 on three: the base `rx-cycles-2` (socket lost, rerun), and the two patched
  `rx-unknown` runs under the strict judge. The rerun batch: 7 runs, 0 FAIL.

## The bot's CI, run locally

`harness/run-bot-co20.sh`: as for CO-21 (`CHECKS.md` there lists the three local changes to the clone's
`bot-ci-local.sh` and the added alternates mount): list bot's code `c7d077f185cd` in Docker, dry run, base
`da3cc02587c6`, BlueZ `20ffd285b58f`, ELL `002b32d7c091`. Results:
`project/tmp/bot-ci-local/co20-20261114/` (`summary.txt`, `patched/`, `base/`; `work/` deleted).

| check | patched (base + 2 patches) | base |
|---|---|---|
| CheckPatch | FAIL: only `Missing Signed-off-by` | - |
| VerifyFixes | PASS (no `Fixes:` tag) | - |
| VerifySignedoff | FAIL: author and committer Signed-off-by missing | - |
| GitLint | FAIL: only `CC1 Body does not contain a 'Signed-off-by' line` | - |
| SubjectPrefix | PASS | - |
| BuildKernel | PASS | PASS |
| CheckAllWarning | PASS | PASS |
| CheckSparse | PASS | PASS |
| BuildKernel32 | PASS | PASS |
| CheckKernelLLVM | PASS | PASS |
| TestRunnerSetup | PASS | PASS |
| IncrementalBuild | PASS | - |

The bot's file mapping selects no `TestRunner_*` tester for a btusb-only change, so there is nothing to compare
between the sides; the emulator above is what exercises the code. Every patched-side failure is the missing
Signed-off-by.

`harness/build-kernel.sh co20`: `make rc=0` (the guest kernel with KASAN and lockdep).
