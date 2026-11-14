# E — checks, with commands and results (2026-11-13)

All paths are under `/root/exp/agent-work/co43-ea-send-20261113/` unless absolute. Nothing was
sent; nothing touched this machine's Bluetooth (every kernel ran in a QEMU guest).

## The patch and the tips

| | |
|---|---|
| patch | `0001-Bluetooth-btusb-Anchor-a-deferred-URB-under-txlock.patch`, from commit `d4b60eb0fcf7` (branch `ea-e-20261113`) |
| bluetooth-next tip | `da3cc02587c629420603df4395179ec82955c941` "Bluetooth: hci_vhci: Report write readiness with queued input" (2026-11-12 14:37 -0500) |
| bluetooth tip | `3b069de8a5d688c7e8381b99d6cdb7467fcae0de` "Bluetooth: L2CAP: Fix size check for receive buffer space" (2026-11-12 14:35 -0500) |
| `Fixes:` target | `7bee549e197c9c0e92b89857a409675c1d5e9dff` "Bluetooth: Add USB autosuspend support to btusb driver", Oliver Neukum, 2009-08-24 |

Fetched today into the worktree `linux/` (a worktree of the emulator directory's repository):

```
$ git ls-remote https://git.kernel.org/pub/scm/linux/kernel/git/bluetooth/bluetooth-next.git refs/heads/master
da3cc02587c629420603df4395179ec82955c941	refs/heads/master
$ git ls-remote https://git.kernel.org/pub/scm/linux/kernel/git/bluetooth/bluetooth.git refs/heads/master
3b069de8a5d688c7e8381b99d6cdb7467fcae0de	refs/heads/master
$ git -C linux fetch <bluetooth-next> master:refs/ea/bluetooth-next-master   # and bluetooth master:refs/ea/bluetooth-master
$ git -C linux diff --stat refs/ea/bluetooth-master refs/ea/bluetooth-next-master -- drivers/bluetooth/btusb_main.c
(no output: the file is identical on both tips)
```

The bluetooth-next tip is the base the emulator work was done on; it has not moved.

**The code is the reviewed code** (`scripts/patch-ids.sh`, `git patch-id --stable`): the package's
E and the project's `patch/0004` both give `8a9f4a2ea9e09f093191ab48410844659ac7d63b`. Only the
message changed.

## Applies and builds: alone, and with A in either order, on both tips

`scripts/apply-build.sh <name> <worktree> <base> <obj>`: a detached checkout of the tip, `git am` of
the package files, `make W=1 drivers/bluetooth/btusb_main.o` (the guest config); logs
`build/apply-build-bluetooth-next.log`, `build/apply-build-bluetooth.log`.

```
RESULT bluetooth-next unpatched build rc=0
RESULT bluetooth-next E git-am=OK build rc=0 warnings_or_errors=0
RESULT bluetooth-next A git-am=OK build rc=0 warnings_or_errors=0
RESULT bluetooth-next E+A git-am=OK build rc=0 warnings_or_errors=0
RESULT bluetooth-next A+E git-am=OK build rc=0 warnings_or_errors=0
RESULT bluetooth unpatched build rc=0
RESULT bluetooth E git-am=OK build rc=0 warnings_or_errors=0
RESULT bluetooth A git-am=OK build rc=0 warnings_or_errors=0
RESULT bluetooth E+A git-am=OK build rc=0 warnings_or_errors=0
RESULT bluetooth A+E git-am=OK build rc=0 warnings_or_errors=0
```

## checkpatch `--strict`

`scripts/checkpatch-docker.sh <patch>`: the tree's `scripts/checkpatch.pl --strict`, run in the
list bot's image (this machine's guard refuses the tree's scripts on the host), with commit ids
resolved in the project's `cache/linux` (full mainline history).

```
ERROR: Missing Signed-off-by: line(s)
total: 1 errors, 0 warnings, 0 checks, 22 lines checked
```

The only finding is the Signed-off-by you add. Two controls (`tmp/checkpatch-control/`):
- with a Signed-off-by line added: `total: 0 errors, 0 warnings, 0 checks, 22 lines checked`, "no
  obvious style problems and is ready for submission";
- with the Fixes: id changed to `7bee549e197d`:
  `WARNING: Unknown commit id '7bee549e197d', maybe rebased or not pulled?`. So the commit-id
  check is live, and the real `7bee549e197c` passes it.

## get_maintainer.pl

`scripts/get-maintainer-docker.sh <patch>` (default options, top of the bluetooth-next worktree):

```
Marcel Holtmann <marcel@holtmann.org> (maintainer:BLUETOOTH DRIVERS,blamed_fixes:1/1=100%)
Luiz Augusto von Dentz <luiz.dentz@gmail.com> (maintainer:BLUETOOTH DRIVERS)
Oliver Neukum <oliver@neukum.org> (blamed_fixes:1/1=100%)
linux-bluetooth@vger.kernel.org (open list:BLUETOOTH DRIVERS)
linux-kernel@vger.kernel.org (open list)
```

## VerifyFixes with full history

The bot's patched-side clone holds bluetooth-next history since 2023, without the 2009 target. So
`scripts/verifyfixes-full.sh` runs the bot's own `verify_fixes.sh` on E's message, committed on
mainline master in a treeless clone of the complete history (`cache/linux-treeless`); output
`tmp/verifyfixes-full.txt`:

```
mainline master: 2800868f63227c8237d70c41e70d441c919620d6 ... Merge tag 'sound-7.4-rc3' ...
Fixes target: 7bee549e197c9c0e92b89857a409675c1d5e9dff Bluetooth: Add USB autosuspend support to btusb driver
== verify_fixes.sh master..aa63bed96d26 (0 Signed-off-by line(s))
	Fixes tag: Fixes: 7bee549e197c ("Bluetooth: Add USB autosuspend support to btusb driver")
	Has these problem(s):
		- empty lines surround the Fixes tag
== exit 1
== verify_fixes.sh master..02e9aa12e9bd (1 Signed-off-by line(s))
== exit 0
```

Without a Signed-off-by, `Fixes:` is the body's last line and the script reads it as surrounded by
empty lines. With your Signed-off-by right after it, VerifyFixes passes: id, subject and ancestry
are right.

## The bot's CI, run locally

See "Bot CI" at the end.

## Stress test (base and base + E)

**Harness:** `stress/harness/bt17-emu.py`, a copy of the emulator's hardened harness with a
`stress` scenario added (`stress/harness/bt17-emu.diff` is the change). It keeps the emulated
QCA9377 (`13d3:3503`) over usbip in a QEMU guest (4 CPUs). Kernels: bluetooth-next `da3cc02587c6`
(`ea-base`) and the same plus E (`ea-e`), each with KASAN, lockdep (`PROVE_LOCKING`), the hung-task
detector (20 s), the soft-lockup and workqueue watchdogs, and kmemleak
(`stress/kernels/*.commit`, `frag-stress.config`).

**One run** = 100 cycles, seed 1000 + run number (the same seeds on both kernels):
- **A normal cycle (95 per run):** the autosuspend delay is set at random to 20, 50, 100 or 250 ms.
  Then three waves, each started on a suspended device. In each wave, 9 threads start together (the senders send two packets
  each, 0 to 40 ms apart; 42 packets per cycle):
  - three raw HCI sockets send Write Page Timeout (command queue, credit-controlled);
  - two send a vendor command (`0xfc55`, raw queue);
  - two send ACL data (raw queue);
  - one sends a MGMT Set Device Class;
  - one forces resumes by writing `power/control` `on` and `auto` at random intervals.

  Every packet carries a key that the emulator records on arrival. After the third wave
  `power/control` is set to `on`, so the device cannot suspend again. A packet that has not arrived
  2.5 s later is parked on an active device (BT-23's symptom) and fails the cycle.
- **Disruptions (5 per run):** in cycles 10, 30, 70 and 90, MGMT Set Powered off during a wave,
  then on. In cycle 50, a usbip detach during a wave, then a new emulated device is attached, hci0
  comes back and is powered.
- **The end:** one more wave with a detach in it; kmemleak scanned twice; 25 s for the hung-task
  detector; tasks in D state listed.
- **Verdict (exit status, `BT17-EXIT`):** every normal cycle delivered and its MGMT writes
  answered 0x00; every disruption recovered; no kernel report among every kernel record (read
  live from `/dev/kmsg`); no `tx timeout` outside a detach window.
  - Reports: `BUG:`, `WARNING:`, KASAN, lockdep's circular/recursive/inconsistent-lock reports,
    hung task, soft lockup, workqueue lockup, RCU, UBSAN, refcount and list corruption.
  - A command outstanding when the device is detached times out before vhci has reported the
    disconnect (about 2.4 s later). That is expected and listed apart, as "teardown".

**Results, final harness** (`stress/logs/ea-{base,e}-s2-<n>.log`; `matrix-ea-base-s2-1-10.txt`,
`matrix-ea-e-s2-1-10.txt`; table by `scripts/summarize-stress.py`):

| log | runner rc | BT17-EXIT | cycles | normal ok | disruptions recovered | packets | device suspends/resumes | parked | tx timeouts | teardown timeouts | kernel reports | kmemleak (BT-25 sig./other) | events re-queued |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| ea-base-s2-1 | 0 | 0 | 100 | 95/95 | 5/5 | 4059 | 321/319 | 0 | 0 | 2 | 0 | 26/0 | 0 |
| ea-base-s2-2 | 0 | 0 | 100 | 95/95 | 5/5 | 4059 | 313/311 | 0 | 0 | 2 | 0 | 27/0 | 0 |
| ea-base-s2-3 | 0 | 0 | 100 | 95/95 | 5/5 | 4058 | 315/313 | 0 | 0 | 2 | 0 | 24/0 | 0 |
| ea-base-s2-4 | 0 | 0 | 100 | 95/95 | 5/5 | 4056 | 316/314 | 0 | 0 | 2 | 0 | 30/0 | 0 |
| ea-base-s2-5 | 0 | 0 | 100 | 95/95 | 5/5 | 4059 | 319/317 | 0 | 0 | 2 | 0 | 26/0 | 0 |
| ea-base-s2-6 | 0 | 0 | 100 | 95/95 | 5/5 | 4059 | 317/315 | 0 | 0 | 2 | 0 | 27/0 | 0 |
| ea-base-s2-7 | 0 | 0 | 100 | 95/95 | 5/5 | 4058 | 322/320 | 0 | 0 | 2 | 0 | 23/0 | 0 |
| ea-base-s2-8 | 0 | 0 | 100 | 95/95 | 5/5 | 4057 | 311/309 | 0 | 0 | 1 | 0 | 25/0 | 0 |
| ea-base-s2-9 | 0 | 0 | 100 | 95/95 | 5/5 | 4058 | 320/318 | 0 | 0 | 2 | 0 | 26/0 | 0 |
| ea-base-s2-10 | 0 | 0 | 100 | 95/95 | 5/5 | 4060 | 315/313 | 0 | 0 | 2 | 0 | 28/0 | 0 |
| ea-e-s2-1 | 0 | 0 | 100 | 95/95 | 5/5 | 4057 | 325/323 | 0 | 0 | 2 | 0 | 26/0 | 0 |
| ea-e-s2-2 | 0 | 0 | 100 | 95/95 | 5/5 | 4060 | 312/310 | 0 | 0 | 2 | 0 | 25/0 | 0 |
| ea-e-s2-3 | 0 | 0 | 100 | 95/95 | 5/5 | 4058 | 310/308 | 0 | 0 | 2 | 0 | 29/0 | 0 |
| ea-e-s2-4 | 0 | 0 | 100 | 95/95 | 5/5 | 4058 | 320/318 | 0 | 0 | 2 | 0 | 26/0 | 0 |
| ea-e-s2-5 | 0 | 0 | 100 | 95/95 | 5/5 | 4058 | 317/315 | 0 | 0 | 2 | 0 | 25/0 | 0 |
| ea-e-s2-6 | 0 | 0 | 100 | 95/95 | 5/5 | 4055 | 318/316 | 0 | 0 | 2 | 0 | 29/0 | 0 |
| ea-e-s2-7 | 0 | 0 | 100 | 95/95 | 5/5 | 4059 | 319/317 | 0 | 0 | 2 | 0 | 18/0 | 0 |
| ea-e-s2-8 | 0 | 0 | 100 | 95/95 | 5/5 | 4057 | 305/303 | 0 | 0 | 2 | 0 | 26/0 | 0 |
| ea-e-s2-9 | 0 | 0 | 100 | 95/95 | 5/5 | 4059 | 316/314 | 0 | 0 | 2 | 0 | 24/0 | 0 |
| ea-e-s2-10 | 0 | 0 | 100 | 95/95 | 5/5 | 4060 | 318/316 | 0 | 0 | 2 | 0 | 28/0 | 0 |

In total: 20 runs, 2,000 cycles, about 81,000 packets and 6,300 device suspend/resume pairs; every
run exit 0; no parked packet, no kernel report, no hung task, no tx timeout outside a detach, no
task in D state at the end, on either kernel. Each run took 100 to 110 s. The project's
`scripts/kernel-report-scan.py` over all 42 guest logs of this task (`stress/kernel-report-scan.txt`):
each booted the intended kernel (`7.3.0-gda3cc02587c6` base, `-gd4b60eb0fcf7` E, `-g0b9b673826f5`
and `-g2ab3144295a3` the debug-only pair, `-g5d5bdb6ee077` A), and every one is `clean`.

**kmemleak:** 18 to 30 objects per run on both kernels, all with BT-25's signature (an skb from
the HCI socket or command path, or an 8-byte setup packet from `alloc_ctrl_urb()`, owned by a URB
that was still deferred when hci0 was powered off or detached). The counts do not differ between
the kernels (base 23–30, E 18–29). That is the registered BT-25 leak, not E's.

**The positive control: the harness sees parking when it happens** (kernels with the debug-only
`bt23_delay_ms` parameter of `results/bt17-emulation-2026-11-13/patches/debug-only/`, set to
30 ms for the whole run; `stress/logs/ea-{base,e}-dbg-ctl-<n>.log`, `matrix-bt23-controls.txt`):

| kernel | run | exit | normal ok | parked | kernel reports |
|---|---|---|---|---|---|
| base + debug delay | ctl-1 | 1 | 19/95 | 76 | 0 |
| base + debug delay | ctl-2 | 1 | 25/95 | 70 | 0 |
| base + E + debug delay | ctl-1 | 0 | 95/95 | 0 | 0 |
| base + E + debug delay | ctl-2 | 0 | 95/95 | 0 | 0 |

All 146 parked packets on the base kernel were raw-queue packets (vendor commands and ACL data),
and each was sent only at the next resume. No queued HCI command was parked there: the 60 ms resume
most likely outlasts the 30 ms delay when a command starts the resume itself (not traced), so
there was no tx timeout. The `bt23` scenario below parks a command.

**The `bt23` scenario, rerun** (the same debug-only delay, 400 ms; a resume forced inside it by
`power/control=on`; `stress/logs/ea-{base,e}-dbg-bt23-<n>.log`):

| kernel | run 1 | run 2 | run 3 |
|---|---|---|---|
| base + debug delay (`0b9b673826f5`) | exit 1: status 0x05 after 2.028 s (`Opcode 0x0c24 failed: -110`) | exit 1: 0x05 after 2.020 s | exit 1: 0x05 after 2.028 s |
| base + E + debug delay (`2ab3144295a3`) | exit 0: 0x00 after 0.399 s | exit 0: 0x00 after 0.399 s | exit 0: 0x00 after 0.399 s |

Parked on base, 3 of 3; answered with E after the delay itself, 3 of 3. That is the earlier
result (3/3 and 2/2), on today's E.

**Every other run, kept and listed:**

| logs | harness | what |
|---|---|---|
| `ea-base-smoke-1`, `ea-e-smoke-2`, `ea-base-dbg-ctl-smoke-1`, `ea-base-smoke-3` | development versions (sha256 in each log) | short runs (10–30 cycles) while the scenario was written. smoke-1 exit 1: two teardown timeouts counted as failures, before the detach window existed. ctl-smoke-1 exit 1: the positive control, 4 parked. smoke-2 and smoke-3 exit 0 |
| `ea-{base,e}-st-1`, `-st-2` (complete), `-st-3` (stopped) | first full version | exit 1 on both kernels (base st-1, E st-1 and st-2) and exit 0 (base st-2), **from an emulator artifact**, below |

**The artifact behind the first runs' failures.** The emulator answered an HCI command's event
on the interrupt URB just as the host unlinked that URB for a suspend. vhci then gives the URB back
with the unlink status: `vhci_hcd: the urb (seqnum 415) was already given back`
(`ea-base-st-1.log`, 23.50). btusb drops the bytes, the command credit never returns, and the
commands queued behind it never reach the driver. After 2 s comes `command 0x0c18 tx timeout`
and a USB reset. The run then cascades, because the reset re-enumerates hci0 under a new index.
- Every one of those failures has this line about 2.1 s before its timeout (base st-1: 23.50 →
  25.65 and 88.82 → 90.94; E st-1: 31.12 → 33.09; E st-2: 27.60 → 29.67).
- The "parked" packets of those runs were not on the anchor: 13 suspend/resume cycles passed
  after them, and any of those resumes would have sent an anchored URB.

A real device keeps an unread event until it is polled, so the final harness puts those bytes back
for the next interrupt URB. In the final runs the condition did not occur again (0 re-queued, no
"already given back" line), so the fix was not exercised there.

**SHA256SUMS:** `stress/SHA256SUMS` covers the harness, every log, the kernel records and the five
images.

## Bot CI

The project's `scripts/bot-ci-local.sh`, run from this work directory's clone of the project
(`project/`, via `scripts/run-bot2.sh`): the list bot's own code (github.com/bluez/action-ci main
`c7d077f185cd`, image `bluez-action-ci:c7d077f185cd`) in Docker, dry-run, nothing posted. Base
bluetooth-next `da3cc02587c6`, BlueZ `20ffd285b58f`, ELL `002b32d7c091`. Results in
`project/tmp/bot-ci-local/E4-20261113/` (`summary.txt`, `patched/`, `base/`; the `work/` tree
deleted after the run).

**Three local changes to that clone's script, each marked in it:**
- Docker limited to 6 CPUs.
- The patched side uses a `--shared` clone of this task's tree instead of a fresh blobless clone
  of bluetooth-next history. kernel.org delivered that clone at a few MB per minute today; the
  first attempts are kept, stopped while still cloning
  (`project/tmp/bot-ci-local/E-20261113`, `A2-20261113`; `E3-20261113` failed at once because the
  mail lay outside the container's view).
- The tree's common git directory is mounted read-only.

| check | patched (base + E) | base |
|---|---|---|
| CheckPatch | FAIL: only `Missing Signed-off-by` | — |
| VerifyFixes | FAIL: `Target SHA1 does not exist` (the tree here has no 2009 history; with full history it passes once the Signed-off-by follows `Fixes:`, see "VerifyFixes with full history") | — |
| VerifySignedoff | FAIL: author and committer Signed-off-by missing | — |
| GitLint | FAIL: only `CC1 Body does not contain a 'Signed-off-by' line` | — |
| SubjectPrefix | PASS | — |
| BuildKernel | PASS | PASS |
| CheckAllWarning | PASS | PASS |
| CheckSparse | PASS | PASS |
| BuildKernel32 | PASS | PASS |
| CheckKernelLLVM | PASS | PASS |
| TestRunnerSetup | PASS | PASS |
| IncrementalBuild | PASS | — |

The bot's file mapping selects no tester (`TestRunner_*`) for a btusb-only change, so there is
nothing to compare between the sides. Every failure is the missing Signed-off-by, or the shallow
history here; none is from the change.
