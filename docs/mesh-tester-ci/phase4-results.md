# `TestRunner_mesh-tester` — Phase 4 results (series v2 after the outside review)

Started 2026-10-02. Follows `phase3-results.md`, `review-series-2026-10-02.md` and
`PHASE4-TASK.md`. Updated after every step. Everything runs inside qemu on freshly built
guest kernels; the host Bluetooth stack is not touched. Writes only under `cache/` and
`tmp/mesh-tester-ci/`. Every claim is marked **quoted** (command and output shown),
**inferred** (derived from quoted material) or **not found**.

"v2" names this revision internally; nothing was ever sent, so the exported patches carry
plain `[PATCH n/3]` subjects.

## Step 0 — trees (quoted)

- `git -C cache/linux fetch bluetooth` → no output (nothing new);
  `git -C cache/linux log --oneline -1 bluetooth/master` →
  `86ef0f58bdec Bluetooth: MGMT: Fix status of pending commands flushed on power off`
  — the same base as phase 3. `git -C cache/linux fetch bluetooth-next` →
  `fdd5964bd389..3b44711c52ea  master -> bluetooth-next/master`. `git -C cache/linux fetch stable`
  → no output.
- `git -C cache/mesh-guest status --short --branch` → `## mesh/phase3-series-on-bluetooth-next-2026-10-02`
  (plus the untracked `make-c1.log`, `make-w1.log`). New branch for v2:
  `git -C cache/mesh-guest checkout -b mesh/phase4-series-v2-on-bluetooth-master-2026-10-02 bluetooth/master`
  → `Switched to a new branch 'mesh/phase4-series-v2-on-bluetooth-master-2026-10-02'`.
- `cache/full-bt-next` HEAD `a23f1c3b10f3` (phase-3 1/2) is on
  `keep/full-bt-next-phase3-series-on-bluetooth-master-4fc05c920590`
  (`git branch --contains a23f1c3b10f3`); reset for the preflight with
  `git -C cache/full-bt-next checkout --detach bluetooth/master` → `HEAD is now at 86ef0f58bdec`.
- `which codespell sparse` → only `/usr/bin/sparse`; `apt-get install -y codespell` →
  `Setting up codespell (2.2.6-1)`.
- BlueZ: `git -C cache/bluez-upstream fetch origin` → `8b4a41760..ae69dcddd  master -> origin/master`.
  `git diff --stat 8b4a41760 origin/master -- tools/mesh-tester.c emulator/ src/shared/tester.c
  src/shared/mgmt.c doc/mgmt-protocol.rst doc/coding-style.rst HACKING` → `tools/mesh-tester.c`,
  `src/shared/mgmt.c`, `doc/coding-style.rst`, `HACKING` unchanged; `doc/mgmt-protocol.rst`
  +45, `emulator/main.c` +55/-3, `emulator/server.c`, `emulator/server.h`, `src/shared/tester.c`
  +19 changed (none of the emulator files is in `tools_mesh_tester_SOURCES`:
  `tools/mesh-tester.c monitor/bt.h emulator/hciemu.[ch] emulator/vhci.[ch] emulator/btdev.[ch]
  emulator/bthost.[ch] emulator/smp.c`). `doc/tester.config` gained `CONFIG_HIDRAW=y` (the
  v2 guest kernels are built with it; `kernel-all` copies that file). The mesh sections of
  `doc/mgmt-protocol.rst` are still at 4075 (Transmit), 4123 (Cancel), 5469 (Complete) at
  `origin/master` (`git grep -n` on the three headings). The v2 tester branch is taken from
  `origin/master` (`ae69dcddd`): `git -C cache/bluez-upstream checkout -b
  mesh-tester/phase4-lifecycle-tests-2026-10-02 origin/master`. The sanitizer-free tree
  `cache/bluez-noasan` is a worktree of the same clone (`git worktree list`).
- The guest config has lock debugging on (`grep` in `doc/tester.config`:
  `CONFIG_PROVE_LOCKING=y`, `CONFIG_DEBUG_ATOMIC_SLEEP=y`, `CONFIG_LOCKDEP=y`,
  `CONFIG_DEBUG_MUTEXES=y`, `CONFIG_KASAN=y`), so a lock-order inversion or a sleep under a
  spinlock introduced by the series would print in the run logs. Every run log below was
  grepped for `lockdep|circular|WARNING|BUG:|KASAN|possible|INFO: |deadlock|sleeping
  function|tx timeout`.

## Design of v2 (inferred from the quoted kernel code; answers review finding 1 / task §A)

**The protocol.** `HCI_MESH_SENDING` means "a mesh transmission is queued, running, on air
or being torn down". It is set when a start is queued (by `mesh_send()` under `hdev->lock`,
unchanged) and from then on stays set until the owner hands over: `mesh_next()` — now a
plain function called with `hdev->lock` held, no longer the destroy callback of the done
work — picks the head of `hdev->mesh_pending`, queues its `mesh_send_sync()` (flag stays
set) and, only when nothing is pending, clears the flag. Because `mesh_send()` tests the
flag under the same lock, a start is queued for each request exactly once, and always for
the head of the list (FIFO): when the flag is clear the list is empty (invariant: the flag
is cleared only when `mgmt_mesh_next()` returned NULL under the lock), so the request
`mesh_send()` queues is the head.

Who calls `mesh_next()`:

- `mesh_send_done_sync()` — after the tear-down and the (existing) `list_empty() →
  hci_disable_advertising_sync()`, both without `hdev->lock`; then `hci_dev_lock()`,
  complete the finished request, `mesh_next()`, unlock. The done work is queued with a
  NULL destroy callback.
- `mesh_send_start_complete()` on an error other than `-ECANCELED` (a destroy callback run
  by `hci_cmd_sync_work()` after the func, not under `cmd_sync_work_lock`): lock, complete
  the failed request, `mesh_next()`, unlock. With `-ECANCELED` the callback runs under
  `cmd_sync_work_lock` (from `hci_cmd_sync_dequeue()` in `send_cancel()`, or from
  `hci_cmd_sync_clear()` at unregister) and taking `hdev->lock` there would invert the
  `hdev->lock → cmd_sync_work_lock` order that `mesh_send()` → `hci_cmd_sync_queue()`
  establishes; so it only completes the request and leaves the hand-over to the caller.
- `send_cancel()` — now under `hdev->lock` around the whole removal; it calls `mesh_next()`
  exactly when `hci_cmd_sync_dequeue()` returned true, i.e. when the cancelled request's
  start was still queued: that start was the next owner, nothing else will hand over. A
  cancelled request on air is handed over by its done work (which still fires); a cancelled
  request queued behind the owner changes nothing. This replaces the `!flag → mesh_next()`
  test that relied on the `-ECANCELED` destroy clearing the flag outside the lock.

`hdev->lock` is never held across a controller command: the tear-down and the disable run
before it is taken; `hci_cmd_sync_queue()` under it is what `mesh_send()` already does.
The pre-existing paths the review listed as out of scope are unchanged: the error path of
`mesh_send_sync()` after a successful `hci_add_adv_instance()`, `mgmt_cleanup()` (socket
close completes the socket's requests without `hdev->lock` and without dequeuing a queued
start), and power transitions (`mesh_send_done()` → `hci_cmd_sync_queue()` fails with
`-ENETDOWN` when the device is down and the flag stays set; before the series the flag
stayed set in that case too). [Note 2026-10-04: this sentence is about the *done work*
(`hci_cmd_sync_queue()` checks `HCI_RUNNING` before queueing) and phase 5 confirmed it in a
guest and fixed it (`phase5-results.md` §D0). It is not the argument the review of
2026-10-03 refuted, which was about *already accepted starts*: Power-off does not dequeue
already accepted mesh starts through hci_cmd_sync_clear(). The worker may execute them
after close. Their internal synchronous HCI path has no general down-device guard
guaranteeing -ENETDOWN. The resulting timeout/error and scheduler recovery behavior has
not been established by the recorded tests.]

**Why a prerequisite patch.** The clear-before-`mesh_next()` window exists since
`b338d91703fa` (microseconds wide before the series; `hci_disable_advertising_sync()`
sleeps in it only when the list is empty, i.e. when the mesh instance is not there). The
tear-down patch widens it to a controller round trip, so the protocol has to be in place
*before* the tear-down lands — otherwise the intermediate commit would carry the race the
review reproduced in principle and this phase reproduces in practice (§3a). As its own
patch it has its own `Fixes:` and can be reviewed on its own; the tear-down patch then
only adds the controller commands and the event guard, and the owner-match patch stays as
small as before. Order: 1/3 protocol, 2/3 tear-down (+ event guard), 3/3 owner match.

**Stable.** 1/3 changes `send_cancel()` as `71af682ba469` ("Bluetooth: mgmt: Dequeue
pending mesh_send_sync entries on cancel", v7.3-rc5, `Fixes: b338d91703fa`, **no**
`Cc: stable`) left it; that commit is in none of the five live stable lines (§4d), so the
series needs it first there. 1/3 carries the prerequisite in the stable tag
(`Cc: <stable@vger.kernel.org> # 6.1.x: 71af682ba469: …`, the form of
`Documentation/process/stable-kernel-rules.rst:85-98`); 2/3 and 3/3 depend only on 1/3,
which the same document says need not be listed (lines 100-109). `3c742feda8fc` is
already in all five lines (§4d).

## Step 1 — the kernel series (quoted)

Branch `mesh/phase4-series-v2-on-bluetooth-master-2026-10-02`, three commits on
`86ef0f58bdec` (`git log --oneline --stat -3`):

    2e3465d11517 Bluetooth: MGMT: complete the mesh transmission that owned the instance   net/bluetooth/mgmt.c | 13 ++++++++++---  (10+, 3-)
    d2e60145113f Bluetooth: MGMT: remove the mesh advertising instance when done           net/bluetooth/mgmt.c | 19 +++++++++++++++++++
    696f53a24ba6 Bluetooth: MGMT: hand mesh transmissions over under hdev->lock            include/net/bluetooth/hci.h | 3 ++ ; net/bluetooth/mgmt.c | 96 ++++++++++++++++++++++++++++++++-------------  (71+, 28-)

These are the commits the images below were built from; they are preserved on
`keep/phase4-series-v2-as-tested-2e3465d11517`. After the stable dependency was found
(§4d) the message of 1/3 was amended (two `Cc: <stable@vger.kernel.org>` lines instead of
one; the diff is unchanged) in `cache/full-bt-next` and 2/3, 3/3 re-applied on top; the
exported series in `series-v2/` is from that tree (§1b below). Messages:
`series-v2/msg-0001.txt`, `msg-0002.txt`, `msg-0003.txt`.

What each patch does, against the review's items:

- **1/3** (`Fixes: b338d91703fa`): the protocol above. Comment at the flag in `hci.h`
  ("set and cleared under hdev->lock, see mesh_next()"), the invariant comment at
  `mesh_next()`, a two-line comment at the `sending` test in `mesh_send()`.
- **2/3** (`Fixes: f3cb5676e5c1`): `hci_remove_advertising_sync(hdev, NULL, instance, true)`
  before the `list_empty()` check (as phase 3's 1/2), the `instance > le_num_of_adv_sets`
  early return in `mgmt_advertising_removed()` with the shorter comment of review B3. The
  message drops nothing from phase 3 except that it now says the hand-over stays behind the
  tear-down under `hdev->lock`; the return value of the tear-down is documented as not acted
  on (the comment says why; review E4's cleanup gap is pre-existing and not claimed).
- **3/3** (`Fixes: b338d91703fa`): the owner match inside the locked section, with the
  review's D3 comment text; message per §C: the two bluetooth-meshd sentences are gone,
  replaced by the review's sentence, and `doc/mgmt-protocol.rst` is quoted for the event
  and the cancel. "On air" is not used for the owner.

Guest kernels (`make -C cache/mesh-guest -f tmp/mesh-tester-ci/build.mk kernel-all KTAG=…`,
each with a `.commit` file; `grep 'is ready' kernel-build-<KTAG>.log`):

    bzImage-v2-1of3   696f53a24ba6 (1/3 only)        Kernel: arch/x86/boot/bzImage is ready  (#6)
    bzImage-v2-2of3   d2e60145113f (1/3 + 2/3)       Kernel: arch/x86/boot/bzImage is ready  (#7)
    bzImage-v2-3of3   2e3465d11517 (the series)      Kernel: arch/x86/boot/bzImage is ready  (#8)

plus phase 3's `bzImage-bluetooth-unpatched` (`86ef0f58bdec`) and `bzImage-bluetooth-patched`
(`0ca34eea2330`, the phase-3 two-patch series = "v1"), reused as they are.

## Step 2 — the BlueZ tester (quoted)

Branch `mesh-tester/phase4-lifecycle-tests-2026-10-02` on `ae69dcddd`; the phase-3 branch
is untouched. Design against review F2 / task §D:

- **State per request** (`struct mesh_tx_req`: handle from the Mesh Send reply, number of
  advertising starts attributed to it, number of Mesh Packet Complete events for it). The
  two requests carry **distinct packets** (`send_mesh_1`, new `send_mesh_2`); the HCI hook
  records which request's packet the last `LE Set Advertising Data` / `LE Set Extended
  Advertising Data` (handle 4) carried and attributes the next enable of the mesh set to it,
  so the test asserts the **sequence** of starts by request number (`{1, 2}`, `{1}`), not a
  count. Tear-downs: `LE Set Advertising Enable 0x00` / `LE Remove Advertising Set 4`.
- **Cancel gate**: the Cancel is issued only once request 1 is acknowledged *and started*,
  request 2 is acknowledged and has *not* started, and nothing has completed; a completion
  before the Cancel went out fails the test ("Handle %u completed before the Cancel was
  issued"), a start of request 2 before it fails too. Every Mesh Send reply and the Cancel
  reply are test conditions (`test_add_condition()`), the Cancel reply must be success with
  no parameters; each handle may complete once; a completion for a handle that was never
  acknowledged fails.
- **Ordinary set** (coexistence): the hook walks every set entry of `LE Set Extended
  Advertising Enable`; a disable of handle 1, a disable of all sets, `LE Remove Advertising
  Set 1`, `LE Clear Advertising Sets` and (legacy) any `LE Set Advertising Enable 0x00` count
  as hits on the ordinary advertiser and fail the coexistence cases. Setup is gated on the
  Add Advertising reply (`test_add_setup_condition()` before `setup_enable_mesh()`,
  `test_setup_condition_complete()` in the callback, instance must be 1) and on
  `mgmt_send()` returning non-zero. The legacy coexistence case leaves the start count
  unchecked (`mesh_tx_starts_unchecked`), per review E3: it asserts that the ordinary
  advertiser is left alone, not that the mesh packet is or is not aired.
- **Diagnostics bounded**: the Read Advertising Features reply must have
  `length == sizeof(*rp) + rp->num_instances` before any instance byte is read;
  `mgmt_register()` must return non-zero ids for both events and
  `hciemu_add_central_post_command_hook()` must succeed, else the test fails before any send.
- **The race test, "Mesh - Send queue - send in tear-down"** (task §B). The deterministic
  lever is the emulator's **pre-command hook** (`hciemu_add_hook(HCIEMU_HOOK_PRE_CMD, …)`,
  `emulator/btdev.c:8742-8744`: a hook returning false drops the command before it is
  processed, so no Command Complete is sent and the kernel's `__hci_cmd_sync_sk()` keeps
  waiting — up to `HCI_CMD_TIMEOUT`, 2 s). The hook holds the **first tear-down command after
  request 1 started** (`LE Set Advertising Enable 0x00`, or `LE Set Extended Advertising
  Enable` with enable 0), copies it as an H4 packet, and issues Mesh Send 2 from inside the
  hook; the reply to Mesh Send 2 (handle 2, while the kernel is still inside the tear-down)
  **releases** the command with `btdev_receive_h4()` (`emulator/btdev.h:103`, the function
  `hciemu.c:233` itself uses for data from the vhci), where it passes the hook again and is
  processed. The test asserts: the hold happened before any completion (a completion with
  the hold still armed fails: "completed without a held tear-down"), request 2 was
  acknowledged while the command was held, starts `{1, 2}`, completions `{1, 2}` each once,
  2 tear-downs. The hold lasts one mgmt round trip (sub-millisecond under KVM), far below
  the 2-s command timeout. `mgmt-tester`'s own `hook_delay_cmd` (`mgmt-tester.c:11987`)
  is the precedent for a pre-command hook on a race; it sleeps in the hook, which would also
  block the tester's mgmt socket and so cannot be used to *send* during the hold.
- Style: every new multi-line comment starts on the second line (`doc/coding-style.rst` M2);
  subject `tools/mesh-tester: Test mesh advertising lifecycle` (50 characters). The patch
  includes `emulator/btdev.h` (already in `tools_mesh_tester_SOURCES`), as `mgmt-tester.c:37`
  does.

Commit `f921c4769` ("tools/mesh-tester: Test mesh advertising lifecycle", `1 file changed,
1024 insertions(+)`), then amended (see §4c: a spelling and two case names; the test logic
is unchanged; §4b) and once more for the hook leak (§3f) — final commit `1ba13eff8`.
`make -C cache/bluez-upstream tools/mesh-tester`
→ `CC tools/mesh-tester.o`, `CCLD tools/mesh-tester`, no warnings (also rebuilt
`src/shared/libshared_glib_la-tester.lo` after the move to `origin/master`). The 25 cases:
the 10 pre-existing ones, 3 Ext Adv variants of Send/cancel (as phase 3), and 12 lifecycle
cases (6 per emulator: cancel active, cancel queued, cancel all, two completions, send in
tear-down, coexist).

## Step 3 — runs (quoted)

All KVM, no in-guest monitor, ASAN tester, one VM at a time
(`make -C cache/bluez-upstream -f tmp/mesh-tester-ci/build.mk run-mesh-kvm-nomon TAG=<tag>
BZIMAGE=<image>` = `tools/test-runner -k <image> -- tools/mesh-tester -d`); the guest
kernel is the `Linux version` line of each log. Tester commits: §3a-3d `f921c4769`; the
first runs of §3f `e0d534e02` (two case names and a comment changed); §3g-3i `1ba13eff8`
(the hook removed at teardown). The test logic is the same in all three.

### 3a. The review's interleaving, reproduced on the phase-3 series ("v1")

`run-p4-v1series-kvm-nomon.log`, `Linux version 7.3.0-rc2-00393-g0ca34eea2330`:

    Mesh - Send queue - send during tear-down            Failed      0.663 seconds
    Mesh - Send queue - send during tear-down - Ext Adv  Failed      0.664 seconds
    (all 23 other cases)                                 Passed
    Total: 25, Passed: 23 (92.0%), Failed: 2, Not Run: 0

The legacy trace (lines 8961-9111; `>` is a command from the kernel, `<` the emulator's
reply):

    Mesh Send 1: handle 1
    > 01 08 20 20 18 17 2b 01 00 ...                 LE Set Advertising Data (packet of request 1)
    > 01 05 20 ..., > 01 06 20 ...                   LE Set Random Address, LE Set Advertising Parameters
    > 01 0a 20 01 01                                 LE Set Advertising Enable 0x01
    Mesh set started for request 1 (1)
    > 01 0a 20 01 00                                 LE Set Advertising Enable 0x00  (the tear-down, +75 ms)
    Holding tear-down command 0x200a
    Sending Mesh Send 2
    Mesh Send 2: handle 2                            (acknowledged while the kernel waits in the tear-down)
    Releasing the held tear-down command
    > 01 0a 20 01 00  → < 04 0e 04 01 0a 20 00       (processed now, Command Complete)
    Mesh Packet Complete handle 1 (1 of 2)
    > 01 08 20 20 18 17 2b 02 00 ...                 LE Set Advertising Data (packet of request 2)
    > 01 05 20, > 01 06 20, > 01 0a 20 01 01         start of request 2
    Mesh set started for request 2 (1)
    > 01 0a 20 01 00                                 disable
    > 01 05 20, > 01 06 20, > 01 0a 20 01 01         start of request 2 AGAIN (mesh_next's second queueing)
    Mesh set started for request 2 (2)
    > 01 0a 20 01 00
    Mesh Packet Complete handle 2 (2 of 2)
    Mesh set started 3 times, torn down 3 times
      start 1: request 1 / start 2: request 2 / start 3: request 2
    Expected 2 starts of the mesh set, in order

The Ext Adv variant: `Holding tear-down command 0x2039` … `Mesh set started 3 times, torn
down 2 times` (lines 12555-12687). This is the review's table of finding 1, step for step:
the Mesh Send that lands while `mesh_send_done_sync()` sleeps in the disable sees the flag
clear and queues a start; `mesh_next()` queues the head again afterwards; the packet is
started twice. **Reproduced, not only derived from source.**

### 3b. The v2 series

`run-p4-v2-3of3-kvm-nomon.log`, `Linux version 7.3.0-rc2-00394-g2e3465d11517`:

    Controller setup                                     Passed      0.088 seconds
    Mesh - Enable 1                                      Passed      0.068 seconds
    Mesh - Enable 2                                      Passed      0.082 seconds
    Mesh - Read Mesh Features                            Passed      0.077 seconds
    Mesh - Read Mesh Features - Disabled                 Passed      0.067 seconds
    Mesh - Send                                          Passed      0.171 seconds
    Mesh - Send - too short                              Passed      0.079 seconds
    Mesh - Send - too long                               Passed      0.078 seconds
    Mesh - Send cancel - 1                               Passed      0.171 seconds
    Mesh - Send cancel - 2                               Passed      0.165 seconds
    Mesh - Send - Ext Adv                                Passed      0.179 seconds
    Mesh - Send cancel - 1 - Ext Adv                     Passed      0.182 seconds
    Mesh - Send cancel - 2 - Ext Adv                     Passed      0.177 seconds
    Mesh - Send queue - cancel active                    Passed      0.660 seconds
    Mesh - Send queue - cancel queued                    Passed      0.571 seconds
    Mesh - Send queue - cancel all                       Passed      0.496 seconds
    Mesh - Send queue - two completions                  Passed      0.667 seconds
    Mesh - Send queue - send during tear-down            Passed      0.664 seconds
    Mesh - Send coexist - instance remains               Passed      0.571 seconds
    Mesh - Send queue - cancel active - Ext Adv          Passed      0.675 seconds
    Mesh - Send queue - cancel queued - Ext Adv          Passed      0.580 seconds
    Mesh - Send queue - cancel all - Ext Adv             Passed      0.503 seconds
    Mesh - Send queue - two completions - Ext Adv        Passed      0.676 seconds
    Mesh - Send queue - send during tear-down - Ext Adv  Passed      0.675 seconds
    Mesh - Send coexist - instance remains - Ext Adv     Passed      0.592 seconds
    Total: 25, Passed: 25 (100.0%), Failed: 0, Not Run: 0

The race test's trace on v2 (lines 8965-9074): `Holding tear-down command 0x200a`,
`Mesh Send 2: handle 2`, `Releasing…`, `Mesh Packet Complete handle 1 (1 of 2)`,
`Mesh set started for request 2 (1)`, `Mesh Packet Complete handle 2 (2 of 2)`,
`Mesh set started 2 times, torn down 2 times` — one start per request, in order. The
lockdep/KASAN grep over the log: nothing.

### 3c. The intermediate commits (each buildable and tested)

`run-p4-v2-1of3-kvm-nomon.log`, `Linux version 7.3.0-rc2-00392-g696f53a24ba6` (1/3 only):
`Total: 25, Passed: 10 (40.0%), Failed: 15` — the same 10 as the unpatched kernel (§3d):
the four pre-existing cancel cases `Timed out`, the lifecycle cases `Failed`
(`Expected 2 starts of the mesh set, in order` for cancel active; `Expected 1/2 tear-downs`
for the others); the race test fails fast at 0.168 s with `Handle 1 completed without a held
tear-down` — without the tear-down patch there is no controller command to hold. So the
protocol alone changes nothing visible to these tests, as intended. No splat in the log.

`run-p4-v2-2of3-kvm-nomon.log`, `Linux version 7.3.0-rc2-00393-gd2e60145113f` (1/3 + 2/3):
`Total: 25, Passed: 23 (92.0%), Failed: 2` — only the two "cancel active" cases fail
(`Expected 2 starts of the mesh set, in order`: the cancelled request 1 is completed by
the cancel, the done work then completes the queue head, request 2, which is never
started — the defect 3/3 fixes); the race test passes on both emulators (the protocol is in
place from 1/3). No splat.

### 3d. The unpatched bluetooth tip, revised tester

`run-p4-bluetooth-unpatched-kvm-nomon.log`, `Linux version 7.3.0-rc2-00391-g86ef0f58bdec`:
`Total: 25, Passed: 10 (40.0%), Failed: 15`; the four cancel cases `Timed out`
(1.822-2.074 s), the lifecycle cases `Failed`; the race test `Failed` at 0.169/0.176 s
with `Handle 1 completed without a held tear-down`. (The revised tester gives the same
verdicts on this image as phase 3's did, plus the two new cases.)

### 3e. Full mgmt-tester on the v2 series

`make -C cache/bluez-upstream -f tmp/mesh-tester-ci/build.mk run-mgmt-kvm TAG=p4-v2-3of3-mgmt-kvm
BZIMAGE=tmp/mesh-tester-ci/bzImage-v2-3of3` → `run-p4-v2-3of3-mgmt-kvm.log`,
`Linux version 7.3.0-rc2-00394-g2e3465d11517`:

    Total: 501, Passed: 501 (100.0%), Failed: 0, Not Run: 0

(`grep -E 'Timed out|Failed  |Not Run '` on the result lines: nothing.) The splat grep finds
two `Bluetooth: hci0: command 0x0405 tx timeout` / `command 0x1405 tx timeout` lines;
`grep -c 'tx timeout' run-p3-bluetooth-patched-mgmt-kvm.log` → `2` as well — mgmt-tester's
own timeout cases, unchanged from phase 3.

### 3f. TCG + valgrind, sanitizer-free tester, the "Send" cases

`make -C cache/bluez-noasan -f tmp/mesh-tester-ci/build.mk run-custom BLUEZ=cache/bluez-noasan
BZIMAGE=<image> TAG=<tag> RUNNER_OPTS="-q tmp/mesh-tester-ci/qemu-tcg.sh" CMD="valgrind
--error-exitcode=65 cache/bluez-noasan/tools/mesh-tester -s Send"` (absolute paths in the
real call). `-s Send` now selects 20 cases (the two "send in tear-down" cases match too).

First run, tester `e0d534e02`, `run-p4-v2-3of3-tcg-valgrind-noasan.log`,
`Linux version 7.3.0-rc2-00394-g2e3465d11517`: `Total: 20, Passed: 20 (100.0%)`,
`==36== ERROR SUMMARY: 9 errors from 9 contexts` — **two more than phase 3's seven.** The
two new ones (lines 1018, 1493) are `24 (+24) bytes in 1 (+1) blocks are definitely lost`,
allocated `by 0x128BB0: btdev_add_hook (btdev.c:8916) by 0x1150E5: test_mesh_tx
(mesh-tester.c:2322)`, reported at the teardown of the two "send in tear-down" cases: the
emulator never frees its hook list (`btdev_destroy()`, `btdev.c:8450-8464`, frees
connections, advertising sets and the like, not `hook_list`; `mgmt-tester`'s `hook_delay_cmd`
registration has the same fate), so the hold hook must be removed by the test. Fixed in the
tester (`hciemu_del_hook()` in `test_post_teardown()` when a hold hook was registered, with
a small `mesh_tx_teardown_opcode()` helper shared by the three places that need the
opcode; `git diff e0d534e02 1ba13eff8 --stat` → `1 file changed, 18 insertions(+), 11
deletions(-)`), final tester commit **`1ba13eff8`**; rerun in §3g.

Unpatched for comparison, `run-p4-bluetooth-unpatched-tcg-valgrind-noasan.log`,
`Linux version 7.3.0-rc2-00391-g86ef0f58bdec` (tester `e0d534e02`):
`Total: 20, Passed: 5 (25.0%), Failed: 15` (four cancel cases `Timed out` 1.987-2.521 s,
eleven `Failed`), `==37== ERROR SUMMARY: 9 errors from 9 contexts` — the same nine, so the
findings are tester-side and kernel-independent, as in phase 3.

### 3g. TCG + valgrind with the final tester (`1ba13eff8`)

`run-p4-v2-3of3-tcg-valgrind-noasan-final.log`, `Linux version 7.3.0-rc2-00394-g2e3465d11517`:

    Total: 20, Passed: 20 (100.0%), Failed: 0, Not Run: 0
    ==37== ERROR SUMMARY: 7 errors from 7 contexts (suppressed: 0 from 0)

The seven are phase 3's seven (one `socketcall.bind(my_addr.rc_bdaddr) points to
uninitialised byte(s)` in `bt_log_open`, six 40-byte `mgmt_register` blocks from the generic
`expect_alt_ev` cases); the two hook blocks are gone. **18 of the 20 cases are the functional
ones phase 3 counted as 18/18; the other two are the new hold cases.**

### 3h. KVM with the final tester: the v2 series and bluetooth-next + series

`run-p4-v2-3of3-kvm-nomon-final2.log`, `Linux version 7.3.0-rc2-00394-g2e3465d11517`:
`Total: 25, Passed: 25 (100.0%), Failed: 0, Not Run: 0` (0.067-0.683 s per case; the
renamed cases "Mesh - Send queue - send in tear-down[ - Ext Adv]" 0.670 / 0.683 s).

`run-p4-v2-bt-next-kvm-nomon.log`, `Linux version 7.3.0-rc2-00484-g8631ac092b6a`
(bluetooth-next `3b44711c52ea` + the series, §4e): `Total: 25, Passed: 25 (100.0%),
Failed: 0, Not Run: 0`.

The splat grep over all v2 logs (1of3, 2of3, 3of3 ×3, bt-next, mgmt, TCG): nothing apart
from mgmt-tester's own two `tx timeout` lines (§3e). With `CONFIG_PROVE_LOCKING=y` in the
guest (§0), the new `hdev->lock` sections in `mesh_send_done_sync()`, `send_cancel()` and
`mesh_send_start_complete()` ran through every case without a lockdep report. **quoted**
[Corrected 2026-10-04 after the review of 2026-10-03 (A1.2): an earlier wording here said the
runs included "the cancel of a queued start". The named cancel-queued case cancels request 2
before its start is queued, so `hci_cmd_sync_dequeue()` returns false there. No lockdep report
was recorded in these runs. Successful dequeue of a queued mesh_send_sync entry, the
-ECANCELED callback under cmd_sync_work_lock, and unregister with such an entry require
explicit branch evidence or dedicated tests. Phase 5 supplies them, `phase5-results.md` §C.]

### 3i. Five repeated runs: the cancel cases and the hold cases (KVM, final tester)

`make -C cache/bluez-upstream -f tmp/mesh-tester-ci/build.mk run-mesh-repeat
TAG=p4-v2-3of3-repeat-cancel BZIMAGE=tmp/mesh-tester-ci/bzImage-v2-3of3 STR=cancel` (five
times `tools/test-runner -k <image> -- tools/mesh-tester -s cancel`, the 10 cases whose name
contains "cancel": the two pre-existing ones, their Ext Adv variants, the six "Send queue -
cancel …" lifecycle cases), `run-p4-v2-3of3-repeat-cancel-summary.txt`:

    repeat-cancel-1.log: Total: 10, Passed: 10 (100.0%), Failed: 0, Not Run: 0
    repeat-cancel-2.log: Total: 10, Passed: 10 (100.0%), Failed: 0, Not Run: 0
    repeat-cancel-3.log: Total: 10, Passed: 10 (100.0%), Failed: 0, Not Run: 0
    repeat-cancel-4.log: Total: 10, Passed: 10 (100.0%), Failed: 0, Not Run: 0
    repeat-cancel-5.log: Total: 10, Passed: 10 (100.0%), Failed: 0, Not Run: 0

(`grep -c Passed` over the summary's case lines: 50.) The same with `STR=tear-down`
(the two hold cases), `run-p4-v2-3of3-repeat-teardown-summary.txt`: five times
`Total: 2, Passed: 2 (100.0%)`, per-case times 0.606-0.609 s (legacy) and 0.586-0.589 s
(Ext Adv). **60 of 60.** The hold case is deterministic (the emulator holds the command
until the tester decides), so no ≥200-iteration stress run was needed in place of it; the
five repeats are the regression check the task asked for.

## Step 4 — hygiene (quoted)

### 4a. Kernel checkpatch `--strict --codespell`

`perl cache/full-bt-next/scripts/checkpatch.pl --strict --codespell --ignore UNKNOWN_COMMIT_ID
series-v2/0001-*.patch series-v2/0002-*.patch series-v2/0003-*.patch` (run on the patch
files, outside the tree, hence the ignored "Unknown commit id" of the Fixes hashes — the
in-tree `-g HEAD` run of the preflight resolves them, §4f; codespell's dictionary was
present, checkpatch did not print its "No codespell typos will be found" notice):

    0001-…: total: 0 errors, 0 warnings, 0 checks, 168 lines checked
    0002-…: total: 0 errors, 0 warnings, 0 checks, 31 lines checked
    0003-…: total: 0 errors, 0 warnings, 0 checks, 19 lines checked

(including the 118-character `Cc: <stable@vger.kernel.org> # 6.1.x: 71af682ba469: …` line
of 1/3, which checkpatch does not flag.)

### 4b. BlueZ patch checks

- `scripts/gitlint-check.sh cache/bluez-upstream series-v2/bluez/0001-tools-mesh-tester-Test-mesh-advertising-lifecycle.patch`
  → `PASS  no violations` (first and final export).
- `BT_PATCH_DIR=series-v2/bluez patches/bluez/checkpatch-check.sh cache/bluez-upstream
  cache/full-bt-next/scripts/checkpatch.pl` (BlueZ's `.checkpatch.conf`) on the first export
  (`f921c4769`): `WARNING:TYPO_SPELLING: 'acknowledgement' may be misspelled` (a comment)
  and `WARNING:LONG_LINE_STRING: line length of 82 exceeds 80 columns` (the registration
  line of "Mesh - Send queue - send during tear-down - Ext Adv") → `total: 0 errors, 2
  warnings`. Fixed: the comment says "reply", the two cases are "Mesh - Send queue - send in
  tear-down[ - Ext Adv]" (`git diff f921c4769 e0d534e02`: those three hunks only). Final
  export (`1ba13eff8`): `total: 0 errors, 0 warnings, 1078 lines checked … has no obvious
  style problems and is ready for submission.`

### 4c. Recipients (`scripts/get-maintainers.sh cache/full-bt-next <patch>`)

1/3 and 3/3 (`Fixes: b338d91703fa`): Marcel Holtmann (maintainer:BLUETOOTH SUBSYSTEM),
Luiz Augusto von Dentz (maintainer:BLUETOOTH SUBSYSTEM, blamed_fixes:1/1=100%), Brian Gix
(blamed_fixes:1/1=100%), linux-bluetooth@vger.kernel.org (open list:BLUETOOTH SUBSYSTEM),
linux-kernel@vger.kernel.org (open list). 2/3 (`Fixes: f3cb5676e5c1`): the same with
Christian Eggers (blamed_fixes:1/1=100%) in place of Brian Gix. Addresses as printed by the
script are not stored here; take them from the script at send time. `Cc: stable` in the
bodies is a tag, not a recipient (`git send-email --suppress-cc=bodycc`).

### 4d. Stable (`scripts/series-backport-check.sh`, after `git -C cache/linux fetch stable`)

The series alone:

    stable/linux-7.2.y     FAILS at patch 1: Hunk #3 FAILED at 2323.   [tip 9a66fdc0d7fd]
    stable/linux-6.18.y    FAILS at patch 1: Hunk #3 FAILED at 2323.   [tip 1b357ecb3213]
    stable/linux-6.12.y    FAILS at patch 1: Hunk #3 FAILED at 2323.   [tip e2acc2211022]
    stable/linux-6.6.y     FAILS at patch 1: Hunk #3 FAILED at 2323.   [tip 79643295eba1]
    stable/linux-6.1.y     FAILS at patch 1: Hunk #3 FAILED at 2323.   [tip 1a8763b93150]

Hunk #3 of 1/3 is `send_cancel()`, whose context is the `hci_cmd_sync_dequeue()` form of
`71af682ba469` ("Bluetooth: mgmt: Dequeue pending mesh_send_sync entries on cancel",
`git describe --contains` → `for-net-2026-09-21~11`, i.e. v7.3-rc5; its message carries
`Fixes: b338d91703fa` and **no** `Cc: stable` — `git show -s --format=%B 71af682ba469`).
`scripts/backport-check.sh 71af682ba469 <five lines>` → `APPLIES` on all five (so it is in
none of them); `scripts/backport-check.sh 3c742feda8fc …` → `PRESENT` on all five
(`fa46d428c014`, `05438d338a87`, `88e30d036d77`, `416fabca9b72`, `b609341ee569`). With
`71af682ba469` exported (`git format-patch -1 71af682ba469 -o series-v2/deps`) and applied
first:

    stable/linux-7.2.y     APPLIES  [1: offset -6 lines] [2: offset -2 lines ×7] [3: offset -2 lines ×2] [4: offset -2 lines]    [tip 9a66fdc0d7fd]
    stable/linux-6.18.y    APPLIES  [1: offset -3 lines] [2: offset 3/1 lines]   [3: offset 1 line ×2]    [4: offset 1 line]      [tip 1b357ecb3213]
    stable/linux-6.12.y    APPLIES  [1: offset -26 lines] [2: offset 1/-22 lines] [3: offset -22 lines ×2] [4: offset -22 lines]  [tip e2acc2211022]
    stable/linux-6.6.y     APPLIES  [1: offset -33 lines] [2: offset -31/-21/-29 lines] [3: offset -21 lines ×2] [4: offset -21 lines]  [tip 79643295eba1]
    stable/linux-6.1.y     APPLIES  [1: offset -99 lines] [2: offset -74/-27/-95 lines] [3: offset -27 lines ×2] [4: offset -27 lines]  [tip 1a8763b93150]

(patch 1 in that output is the prerequisite, 2-4 the series; offsets abbreviated here, the
full lines are in the shell record). Hence the two-line stable tag on 1/3 (design section).
A text check only: no stable kernel was built or run. **quoted + inferred**

### 4e. bluetooth-next

`git -C cache/mesh-guest checkout -b mesh/phase4-series-v2-on-bluetooth-next-2026-10-02
bluetooth-next/master` (`3b44711c52ea Bluetooth: MGMT: Add management security level
changed event`), `git am` of the three final patches → `Applying: …` ×3, no offset or fuzz
reported; `kernel-all KTAG=v2-bt-next` → `Kernel: arch/x86/boot/bzImage is ready  (#9)`,
`bzImage-v2-bt-next.commit` = `8631ac092b6a`. Run in §3h. (`git diff --stat 988f5c0f7476
8631ac092b6a -- net/bluetooth/mgmt.c include/net/bluetooth/hci.h` → `mgmt.c | 80 +-` — the
bluetooth-next-only changes around the series, none in the mesh path, as in phase 3 §0.)

### 4f. Kernel preflight (`BT_SPARSE=cache/sparse/sparse scripts/kernel-preflight.sh cache/full-bt-next`)

`cache/full-bt-next` reset to `bluetooth/master` (`86ef0f58bdec`), the three final patches
applied with `git am` (`Applying: …` ×3, no fuzz) → `a1d3fdc784df`, `4d61bee7e0d3`,
`988f5c0f7476`; the script run once per commit, from the tip down with `git checkout
--detach HEAD~1` in between (`preflight-v2-0003.log`, `-0002.log`, `-0001.log`):

    tree: 988f5c0f7476 Bluetooth: MGMT: complete the mesh transmission that owned the instance
    base: 4d61bee7e0d3 Bluetooth: MGMT: remove the mesh advertising instance when done
    ── checkpatch --strict -g HEAD
    total: 0 errors, 0 warnings, 0 checks, 19 lines checked
    ── W=1 build of net/bluetooth
       W=1 -Werror: clean
    ── sparse (C=1) on mgmt.c, patched vs base
       findings in mgmt.c: base 0, patched 0
       no new sparse finding introduced by the patch

    tree: 4d61bee7e0d3 Bluetooth: MGMT: remove the mesh advertising instance when done
    base: a1d3fdc784df Bluetooth: MGMT: hand mesh transmissions over under hdev->lock
    total: 0 errors, 0 warnings, 0 checks, 31 lines checked
       W=1 -Werror: clean
       findings in mgmt.c: base 0, patched 0 / no new sparse finding introduced by the patch

    tree: a1d3fdc784df Bluetooth: MGMT: hand mesh transmissions over under hdev->lock
    base: 86ef0f58bdec Bluetooth: MGMT: Fix status of pending commands flushed on power off
    total: 0 errors, 0 warnings, 0 checks, 168 lines checked
       W=1 -Werror: clean
       findings in mgmt.c: base 0, patched 0 / no new sparse finding introduced by the patch

(The in-tree `-g HEAD` run resolves the Fixes hashes, so the "Unknown commit id" of §4a does
not appear; the sparse positive control held — the script exits 1 without a `CHECK … mgmt.c`
line and exited 0 three times.) The recipients the script prints are those of §4c. The tree
was left at `988f5c0f7476`, preserved on `keep/full-bt-next-phase4-v2-final-988f5c0f7476`.

## Step 5 — the duration note (task §E)

`tmp/mesh-tester-ci/duration-overflow-note-v2.md`: the table now reads 655 → 65,176 →
6517 → **65.17 s**, with 656 (0.64 s), 1000 (16.96 s) and 8192 (0 → no finite duration)
added; "every timeout above 65 s stops early" replaced by the exact statement (66 s and up
are wrong; multiples of 8192 s give 0 and the set runs until disabled — and
`hci_schedule_adv_instance_sync()` arms no kernel timer for extended advertising,
`hci_sync.c:2099-2105`, quoted); the clamp conclusion replaced by the review's wording;
provenance "present in hci_sync since the conversion (`cba6b758711c`); the expression
predates it in hci_request; the introducing commit not yet identified" — the pickaxe over
`hci_request.c` on the blobless clone printed nothing (**not found**). The reproducer plan
gained the 655/656/1000/8192 boundary cases.

## Summary

**What changed since phase 3 and why.** The review's blocker (finding 1) was real and is
now *reproduced*: with the phase-3 series, a Mesh Send that lands while
`mesh_send_done_sync()` waits for the controller is started twice (§3a, both emulators). v2
is a three-patch series: **1/3** keeps `HCI_MESH_SENDING` set through the tear-down and
makes the "next packet or idle" decision in `mesh_next()` under `hdev->lock`, the lock
`mesh_send()` tests the flag under; `send_cancel()` and the failed-start path use the same
hand-over; the `-ECANCELED` destroy callback only completes its request (no `hdev->lock`
under `cmd_sync_work_lock`); `hdev->lock` is never held across a controller command. **2/3**
is phase 3's tear-down (now safe behind 1/3) with the shorter event-guard comment. **3/3** is
the owner match, with the bluetooth-meshd sentences removed and `doc/mgmt-protocol.rst`
quoted. The cover letter carries the review's exact replacements (75 ms nominal, valgrind
with its seven tester-side errors, legacy coexistence scope, the E4 scope sentence, no
"on air", no CI-history claims) and the stable prerequisite `71af682ba469`. The BlueZ
tester gates every scenario on observed state, attributes starts to requests by their
distinct packets, watches every set entry for the ordinary advertiser, checks every return
value, bounds its diagnostic, starts multi-line comments on the second line, and adds the
deterministic hold test. The duration note is corrected.

**Results** (all quoted above; final tester `1ba13eff8`, images from `2e3465d11517` and
`8631ac092b6a`):

| configuration | unpatched `86ef0f58bdec` | phase-3 series (v1) | 1/3 | 1/3+2/3 | v2 series | bluetooth-next + v2 |
|---|---|---|---|---|---|---|
| mesh-tester 25 cases, KVM | 10/25 | 23/25 (hold cases fail: packet started twice) | 10/25 | 23/25 (cancel active fails) | **25/25** (×3 runs) | **25/25** |
| 20 Send cases, TCG + valgrind | 5/20 (tester `e0d534e02`: 9 errors = the 7 pre-existing + the 2 hook blocks fixed in `1ba13eff8`) | — | — | — | **20/20**, 7 pre-existing errors | — |
| cancel ×5, hold ×5 | — | — | — | — | **50/50, 10/10** | — |
| mgmt-tester 501 | — | — | — | — | **501/501** | — |
| checkpatch --strict (+codespell) / W=1 -Werror / sparse | — | — | 0/0/0, clean, 0 new | 0/0/0, clean, 0 new | 0/0/0, clean, 0 new | — |
| stable 7.2/6.18/6.12/6.6/6.1 (text apply) | — | — | FAILS alone; APPLIES after `71af682ba469` | | | |
| lockdep / KASAN reports in any run | none | none | none | none | none | none |

**Deliverables** (nothing sent or posted; written to `tmp/mesh-tester-ci/series-v2/`, committed
here as `patches/mesh-tester/series-v2/`): `0000-cover-letter.patch`,
`0001-Bluetooth-MGMT-hand-mesh-transmissions-over-under-hd.patch`,
`0002-Bluetooth-MGMT-remove-the-mesh-advertising-instance-.patch`,
`0003-Bluetooth-MGMT-complete-the-mesh-transmission-that-o.patch` (base-commit
`86ef0f58bdec`, from `cache/full-bt-next` `988f5c0f7476`), `msg-000{1,2,3}.txt`,
`bluez/0001-tools-mesh-tester-Test-mesh-advertising-lifecycle.patch` (`msg-bluez-mesh-tester.txt`),
the two upstream commits used for the stable check (`71af682ba469`, `3c742feda8fc`; their
patch files stay in `tmp/`, uncommitted, because they carry a third party's address),
`duration-overflow-note-v2.md`,
this file, the logs `run-p4-*.log`, `preflight-v2-000{1,2,3}.log`, `kernel-build-v2-*.log`,
the images `bzImage-v2-{1of3,2of3,3of3,bt-next}` with `.commit` files. Branches:
`mesh/phase4-series-v2-on-bluetooth-master-2026-10-02` (= `988f5c0f7476`),
`mesh/phase4-series-v2-on-bluetooth-next-2026-10-02` (checked out in `cache/mesh-guest`),
`keep/phase4-series-v2-as-tested-2e3465d11517`, `keep/full-bt-next-phase4-v2-am-6695ebe9a2ed`,
`keep/full-bt-next-phase4-v2-final-988f5c0f7476` (cache/linux);
`mesh-tester/phase4-lifecycle-tests-2026-10-02` (= `1ba13eff8`, checked out in
`cache/bluez-upstream`; `cache/bluez-noasan` detached at the same commit),
`keep/mesh-tester-phase4-first-commit-f921c4769`, `keep/mesh-tester-phase4-second-commit-e0d534e02`.

## Open (not settled here)

1. **Stable needs `71af682ba469` first** (§4d). It carries no `Cc: stable`; 1/3 lists it as
   a prerequisite in the stable tag. Whether the stable team takes it on that line, or the
   operator sends a separate backport request for it, is for send time. No stable kernel
   was built or run (text apply only).
2. **Attribution.** The kernel patches carry the project author's `Signed-off-by`; the BlueZ
   patch names the same author in its `From:` and carries no `Signed-off-by`, as BlueZ
   requires. No other attribution anywhere, as in every file of this project. (Corrected
   2026-10-03: an earlier wording here said "every patch, kernel and BlueZ, carries
   Signed-off-by", which the v2 review caught.)
3. **Pre-existing, unchanged, not claimed**: the `mesh_send_sync()` error path after a
   successful `hci_add_adv_instance()` (instance left, no done work); `mgmt_cleanup()`
   completing a socket's requests without `hdev->lock` and without dequeuing a queued
   start; the flag staying set when `mesh_send_done()` cannot queue its work on a device
   that went down; legacy coexistence not airing the mesh packet while an ordinary instance
   rotates (`hdev->adv_instance_timeout` = the instance's 2-s default duration →
   `instance = 0` in `mesh_send_sync()`). The return value of
   `hci_remove_advertising_sync()` in 2/3 is deliberately not acted on (comment in the code).
4. **The pre-existing "Mesh - Send cancel - 1/2" cases are still load-sensitive** by
   construction (phase 3 §3a); every run here was one VM at a time and they passed
   throughout.
5. **The duration overflow** has a corrected note and a reproducer plan, no patch.
6. **The emulator leaks registered hooks** (`btdev_destroy()` does not free `hook_list`);
   the tester works around it by deleting its hook at teardown. A one-line emulator fix
   would be a separate BlueZ patch; not written here.
