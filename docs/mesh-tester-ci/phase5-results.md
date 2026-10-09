# `TestRunner_mesh-tester` — Phase 5 results (series v3 after the v2 review of 2026-10-03)

Started 2026-10-03. Follows `phase4-results.md`, `review-series-v2-2026-10-03.md` and
`PHASE5-TASK.md`. Updated after every step; if this file ends abruptly, the last section
written is where the work stopped. Everything runs inside qemu on freshly built guest kernels;
the host Bluetooth stack is not touched. Writes only under `cache/` and `tmp/mesh-tester-ci/`.
Every claim is marked **quoted** (command and output shown), **inferred** (derived from quoted
material) or **not found**. Raw logs of every run and build are kept this time in
`tmp/mesh-tester-ci/logs/phase5/` with a sha256 list (`SHA256SUMS`), see §G.

"v3" names this revision internally; nothing was ever sent, so the exported patches carry plain
`[PATCH n/N]` subjects.

## Step 0 — trees (quoted)

- `git -C cache/linux fetch bluetooth` → no output; `git -C cache/linux fetch bluetooth-next` →
  no output (both already current). `git -C cache/linux log --oneline -1 bluetooth/master` →
  `08e90633377f Bluetooth: RFCOMM: Fix NULL tty_dev dereference in rfcomm_dev_shutdown`;
  `… -1 bluetooth-next/master` → `036d4119079a Bluetooth: btusb: add ASUS 0b05:1825 to QCA Rome
  quirks`. The bluetooth tree moved by two commits since the phase-4 base
  (`git log --oneline 86ef0f58bdec..bluetooth/master` → `08e90633377f Bluetooth: RFCOMM: Fix
  NULL tty_dev dereference in rfcomm_dev_shutdown`, `25016fe8c1ed Bluetooth: btintel_pcie: use
  managed IRQ teardown`); `git diff --stat 86ef0f58bdec bluetooth/master -- net/bluetooth/mgmt.c
  net/bluetooth/hci_sync.c net/bluetooth/mgmt_util.c include/net/bluetooth/hci.h
  include/net/bluetooth/hci_core.h` → no output: none of the files the series touches changed.
  **The v3 base is `08e90633377f`.**
- `git -C cache/linux log --oneline -i --grep=mesh_tx bluetooth/master bluetooth-next/master` →
  `71af682ba469 Bluetooth: mgmt: Dequeue pending mesh_send_sync entries on cancel`,
  `2185e0fdbb21 Bluetooth: Fix a buffer overflow in mgmt_mesh_add()` — **the 2026-09-19 leak fix
  is in neither tree** (see §A).
- `git -C cache/mesh-guest status --short --branch` →
  `## mesh/phase4-series-v2-on-bluetooth-next-2026-10-02...bluetooth-next/master [ahead 3,
  behind 5]` plus the untracked `make-c1.log`, `make-w1.log`. `git -C cache/mesh-guest branch
  --list` shows the phase-3/4 `mesh/*` and `keep/*` branches intact.
- `git -C cache/full-bt-next log --oneline -1` → `988f5c0f7476 Bluetooth: MGMT: complete the mesh
  transmission that owned the instance` (the phase-4 v2 tip, on
  `keep/full-bt-next-phase4-v2-final-988f5c0f7476`).
- BlueZ: `git -C cache/bluez-upstream status --short --branch` →
  `## mesh-tester/phase4-lifecycle-tests-2026-10-02...origin/master [ahead 1]` (untracked
  `attrib/`, `unit/test-gattrib` build products); `git worktree list` →
  `cache/bluez-upstream 1ba13eff8 [mesh-tester/phase4-lifecycle-tests-2026-10-02]`,
  `cache/bluez-noasan 1ba13eff8 (detached HEAD)`.
- `git -C cache/mesh-tester-ci status --short --branch` → `## diag/mesh-tester-ci` (clean; this
  worktree receives no commits in this phase).
- `ls /dev/kvm cache/sparse/sparse` → both present. `gcc --version` → `gcc (Ubuntu
  13.3.0-6ubuntu2~24.04.1) 13.3.0`.
- Guest config (`grep` in `cache/bluez-upstream/doc/tester.config`): `CONFIG_DEBUG_FS=y`,
  `CONFIG_PROVE_LOCKING=y`, `CONFIG_KASAN=y`, `CONFIG_LOCKDEP=y`, `CONFIG_DEBUG_ATOMIC_SLEEP=y`,
  `CONFIG_BT=y`, `CONFIG_BT_HCIVHCI=y`; **no** `CONFIG_FAULT_INJECTION`, `CONFIG_FAILSLAB`,
  `CONFIG_FAULT_INJECTION_DEBUG_FS` or `CONFIG_KCSAN` (`grep -n -E 'FAULT_INJECTION|FAILSLAB|
  KCSAN' doc/tester.config` → nothing). `tools/test-runner.c:212` mounts
  `{ "debugfs", "/sys/kernel/debug", NULL, 0 }` in the guest.
- Phase-4 images reused as they are: `bzImage-v2-3of3.commit` →
  `2e3465d11517 Bluetooth: MGMT: complete the mesh transmission that owned the instance`;
  `bzImage-bluetooth-unpatched.commit` → `86ef0f58bdec …`.

## A — the dependency (quoted) and the failing-allocation test

### A1. Where the 2026-09-19 cleanup fix stands

- Trees: not in `bluetooth/master` `08e90633377f`, not in `bluetooth-next/master` `036d4119079a`
  (Step 0 grep; the `mesh_send()` error path in both still reads `if (mesh_tx) { if (sending)
  mgmt_mesh_remove(mesh_tx); }` — `cache/full-bt-next/net/bluetooth/mgmt.c:2610-2613` at the v2
  tip, identical in the base).
- Patchwork (`tmp/mesh-tester-ci/pw-search.sh bluetooth mesh_tx leak`, read-only, raw JSON in
  `logs/phase5/patchwork-bluetooth-mesh_tx-leak.json`):

      hits: 2
      2026-09-19T11:54  14831271  new            Bluetooth: MGMT: fix mesh_tx leak on hci_cmd_sync_queue() failure
      2026-09-19T11:25  14831256  new            [v3] Bluetooth: MGMT: Fix mesh_tx Use-After-Free and leak in mesh_send()

  `tmp/mesh-tester-ci/pw-patch.sh 14831271` (metadata only is saved,
  `logs/phase5/patchwork-patch-14831271.txt`; the diff was read on the terminal and is copied
  nowhere): submitter Hui Peng, Message-ID `<20260919115436.3998954-1-…>` (the author's
  address is elided in this repository; the lkml link in the cover reaches the mail),
  state `new`, delegate none, `Fixes: b338d91703fa`, no `Cc: stable`; the author's own note
  below the `---`: it is "the remaining half" of the v3 UAF+leak patch (14831256,
  `<20260919112517.3871992-1-…>`), "which I am withdrawing", because
  `71af682ba469` already fixed the use-after-free; "Found by code inspection … I have not
  reproduced the leak on its own … Compile tested only." CI checks on 14831271:
  `BuildKernel:success … CheckPatch:success CheckSparse:success GitLint:fail …
  TestRunner_mesh-tester:fail TestRunner_mgmt-tester:fail VerifyFixes:success`. The
  `TestRunner_mesh-tester:fail` is the bot's standing failure on every kernel patch of that
  period (phase 4 §0 / `scripts/patchwork-checks.sh --rate TestRunner_mesh-tester`: 20 of 20
  kernel patches 09-19 → 09-27 fail it); 14831256 has only `pre-ci_am:fail` (it was written
  against mainline and did not apply to bluetooth-next, as its author says).
- lore is blocked for `curl` from here (tooling index); the lkml mirror
  `https://lkml.iu.edu/2609.2/10074.html` was read: same subject, author, date (Sat 19 Sep 2026),
  `Fixes:` and testing statement as the patchwork copy. **quoted**
- **Conclusion (inferred):** the fix is public (one author, two postings, the second superseding
  the first), unapplied as of 2026-10-03 and compile-tested only. Per the task, v3 **does not
  carry it**: the cover letter names it as the assumed prerequisite with its subject, author's
  thread and date; 1/N's comment at the flag states the invariant *given that cleanup*; the diff
  is not included anywhere in this project. For the guest tests the equivalent one-line change
  is applied locally on a scratch branch named `scratch/with-upstream-leak-fix` (see A2), and
  only there.

## Step 1 — the v3 kernel branch, the images and the tester (quoted)

- Kernel: `git -C cache/mesh-guest fetch bluetooth` → no output; `git checkout -b
  mesh/phase5-series-v3-on-bluetooth-master-2026-10-03 bluetooth/master`; the three v2 patches
  applied one at a time with `git am` (each `Applying: …`, no fuzz) and 1/N and 2/N amended
  (`git commit --amend -a -F series-v3/msg-000{1,2}.txt`): 1/N gains `lockdep_assert_held(&hdev->lock)`
  at the top of `mesh_next()` and the invariant comment now ends "…nothing is pending, given
  that mesh_send() removes a request whose first start could not be queued."; its message
  gains the dependency paragraph. 2/N's comment carries the review's replacement ("Account for
  the request even if teardown fails. Recovery of a residual advertising instance is not
  handled here."). `git log --oneline -4` →

      99a396470835 Bluetooth: MGMT: complete the mesh transmission that owned the instance
      d5869ecb9834 Bluetooth: MGMT: remove the mesh advertising instance when done
      f40c7a65bcb2 Bluetooth: MGMT: hand mesh transmissions over under hdev->lock
      08e90633377f Bluetooth: RFCOMM: Fix NULL tty_dev dereference in rfcomm_dev_shutdown

  Scratch: `git checkout -b scratch/with-upstream-leak-fix` on `99a396470835`, the two-line
  change to `mesh_send()`'s error path (`if (mesh_tx) mgmt_mesh_remove(mesh_tx);`) committed as
  `41309428a5f4 scratch: local equivalent of the posted mesh_tx cleanup fix (not for submission)`.
  Nothing from the posted patch was copied; the change is the one the review's finding 1
  describes.
- Config fragment `tmp/mesh-tester-ci/frag-fault.config` (`CONFIG_FAULT_INJECTION=y`,
  `CONFIG_FAILSLAB=y`, `CONFIG_FAULT_INJECTION_DEBUG_FS=y`) appended to `doc/tester.config` by
  the new `FRAG=` argument of `build.mk kernel-all`; `grep` in `config-v3` → all three `=y`,
  `CONFIG_KASAN=y`, `CONFIG_PROVE_LOCKING=y`. Images (`kernel-all KTAG=… FRAG=…
  LOGDIR=logs/phase5`, each log ends `Kernel: arch/x86/boot/bzImage is ready`):

      bzImage-v3                41309428a5f4^ = 99a396470835  (the series)            kernel-build-v3.log (#10)
      bzImage-v3-leakfix        41309428a5f4  (series + scratch cleanup)              kernel-build-v3-leakfix.log
      bzImage-v3base-unpatched  08e90633377f  (bluetooth/master, nothing applied)     kernel-build-v3base-unpatched.log

- BlueZ: `git -C cache/bluez-upstream checkout -b mesh-tester/phase5-lifecycle-tests-2026-10-03
  origin/master` (`ae69dcddd`); first commit `8e1574ed6 emulator/hciemu: Add hooks on client
  controllers` (`hciemu_client_add_hook()`/`hciemu_client_del_hook()`, the type mapping shared
  with the central variants; 2 files, 61+/30-); the phase-4 tester brought back with `git
  checkout 1ba13eff8 -- tools/mesh-tester.c` and extended (design in §C-§E below);
  `doc/tester.config` gains the three fault-injection options. Compile:
  `make -C cache/bluez-upstream -f build.mk bluez-make-testers BTAG=asan-phase5-try2` → no
  warnings (`grep -E 'error|warning' logs/phase5/bluez-make-testers-asan-phase5-try2.log` →
  nothing; try1 had one `-Werror=unused-const-variable` on a table that was then removed).
- Helpers written for this phase (all under `tmp/mesh-tester-ci/`): `pw-search.sh`,
  `pw-patch.sh` (patchwork, read-only, metadata only saved), `case-trace.sh <log> "<case>"`
  (one case's tester lines out of a run log), `build.mk` (`LOGDIR`, `FRAG`,
  `run-mesh-kvm-nomon-str`, `splat-grep`).

### First run (tester before the final two fixes), `run-p5-v3-leakfix-kvm-nomon-try1.log`

`Linux version 7.3.0-rc2-00397-g41309428a5f4`: `Total: 51, Passed: 46 (90.2%), Failed: 5,
Not Run: 0`. The five: `Mesh - Send queue - rejected start` (legacy) and the four receiver
cases. Both were tester defects, not kernel findings: (a) on the legacy path the kernel does not
reload advertising data it already set (`hci_update_adv_data_sync()` compares with
`hdev->adv_data`), so when the previous probe's request 2 had carried the same packet the
rejected-start case saw no `LE Set Advertising Data` before the enable and attributed the start
to no request ("Expected 2 starts of the mesh set, in order"); the probe bookkeeping no longer
forgets the packet the controller holds. The extended variant passed in the same run. (b) The
emulator broadcasts from inside `LE Set Extended Advertising Enable`, before the Command
Complete the tester counts as the start, so the first report preceded the start by 2 ms and the
window check rejected it ("Packet 1 received outside the enabled window"); the check now allows
a 20 ms lead. The measurements of that run are the ones reported in §B (they do not depend on
the check). All other 46 cases passed, among them the two causal cancel cases, the six
power-off cases, the four unregister cases and the four socket-close cases; the splat grep over
the log found only the `FAULT_INJECTION: forcing a failure.` dumps of the probes (expected,
§A2), nothing else.

## Resumption (2026-10-03 21:38 CEST)

The work was resumed from the state on disk at 21:38 (`date` → `Sat Oct  3 09:38:31 PM CEST
2026`). Checked read-only before anything else:

- `git -C cache/mesh-guest log --oneline -5 mesh/phase5-series-v3-on-bluetooth-master-2026-10-03
  scratch/with-upstream-leak-fix` → `41309428a5f4 scratch: local equivalent of the posted
  mesh_tx cleanup fix (not for submission)`, `99a396470835 Bluetooth: MGMT: complete the mesh
  transmission that owned the instance`, `d5869ecb9834 Bluetooth: MGMT: remove the mesh
  advertising instance when done`, `f40c7a65bcb2 Bluetooth: MGMT: hand mesh transmissions over
  under hdev->lock`, `08e90633377f Bluetooth: RFCOMM: Fix NULL tty_dev dereference in
  rfcomm_dev_shutdown`. The tree was detached at `08e90633377f` (the last image built);
  `git checkout mesh/phase5-series-v3-on-bluetooth-master-2026-10-03` for reading.
- `git -C cache/bluez-upstream log --oneline -2` → `8e1574ed6 emulator/hciemu: Add hooks on
  client controllers`, `ae69dcddd client: Display SecurityLevel in device info`; `status` →
  `MM tools/mesh-tester.c`, ` M doc/tester.config`: **the extended tester was not committed**
  (`git diff --stat HEAD` → `tools/mesh-tester.c | 2711 ++++…`, `doc/tester.config | 3 +`).
  A copy was taken before any edit: `logs/phase5/mesh-tester.c.wip-2026-10-03-2140`. The
  binary `tools/mesh-tester` (21:27:03) is newer than the source (21:26:41), so try2 ran this
  source.
- Images present: `bzImage-v3`, `bzImage-v3-leakfix`, `bzImage-v3base-unpatched` with their
  `.commit` and `config-*` files (`ls -la tmp/mesh-tester-ci/`). An unused
  `frag-kcsan.config` (KCSAN instead of KASAN, plus fault injection) was found, written 21:28;
  no KCSAN image exists.
- The try2 log ends (`tail -n 80`): `Total: 55, Passed: 51 (92.7%), Failed: 4, Not Run: 0`,
  `Overall execution time: 50.5 seconds`, then `==38==ERROR: LeakSanitizer: detected memory
  leaks` / `Direct leak of 240 byte(s) in 6 object(s) allocated from: … #1 … in util_malloc
  src/shared/util.c:46` / `SUMMARY: AddressSanitizer: 240 byte(s) leaked in 6 allocation(s).`
  The four failures, all `Timed out` (≈6.0 s):

      Mesh - Send power - off 300 ms, active request       Timed out    6.303 seconds
      Mesh - Send power - off 300 ms, queued request       Timed out    6.000 seconds
      Mesh - Send power - off 300 ms, active - Ext         Timed out    5.999 seconds
      Mesh - Send power - off 300 ms, queued - Ext         Timed out    6.000 seconds

## Step D0 — diagnosis of the four failures (started 21:45)

### D0.1 The four "off 300 ms" time-outs are a kernel finding: a stale `HCI_MESH_SENDING` after reopen

Trace (`case-trace.sh run-p5-v3-leakfix-kvm-nomon-try2.log "Mesh - Send power - off 300 ms,
active request"`, quoted, HCI hexdumps elided):

    Mesh Send 1 at +1 ms: handle 1
    HCI Command 0x2008 / 0x2005 / 0x2006 / 0x200a      (start of request 1)
    Mesh set started for request 1 (1) at +8 ms
    Sending Set Powered off at +8 ms
    Set Powered off at +9 ms: Success (0x00)
    Sending Set Powered on at +312 ms
    … the power-on HCI sequence …
    Set Powered on at +380 ms: Success (0x00)
    Sending Mesh Send 3 at +380 ms
    Mesh Send 3 at +381 ms: handle 2
    Mesh - Send power - off 300 ms, active request - test timed out

Mesh Send 3 is acknowledged and nothing is ever started for it; no Mesh Packet Complete for
handle 1 either. The same in the three other cases (the Ext ones: `Mesh Send 3 at +386 ms:
handle 3`, then the time-out). The same cases with an immediate power-on pass in the same
run; their trace shows why: `Set Powered on at +71 ms`, `Mesh Packet Complete handle 1 at +86
ms` — the done work (armed for 25 ms × Count 3 = 75 ms at the start, +7 ms) fires after the
controller is up again.

Source (quoted, `cache/mesh-guest` at `99a396470835`): `mesh_send_done()` ends in
`hci_cmd_sync_queue(hdev, mesh_send_done_sync, NULL, NULL);` (`mgmt.c:1170`), and
`hci_cmd_sync_queue()` begins `if (!test_bit(HCI_RUNNING, &hdev->flags)) return -ENETDOWN;`
(`hci_sync.c:757-758`). The work is cancelled only at index removal
(`cancel_delayed_work_sync(&hdev->mesh_send_done)`, `mgmt.c:9864`, in `mgmt_index_removed()`),
not at power-off; `hci_dev_close_sync()` (`hci_sync.c:5536-5685`) does not touch
`mesh_pending`, and `__mgmt_power_off()` (`mgmt.c:9891-9924`) handles `mgmt_pending` only.
**Inferred:** when the done work fires while the controller is off, the queue attempt fails
silently, nobody completes the owner or clears `HCI_MESH_SENDING`, and every later
`mesh_send()` sees the flag set and only appends (`sending = hci_dev_test_flag(...)`,
`mgmt.c:2599`). Runtime confirmation: the tester now issues a Read Mesh Features right after
Set Powered on (recorded, not checked; tester change below). On the three-patch kernel
(`bzImage-v3-leakfix`, `Linux version 7.3.0-rc2-00397-g41309428a5f4`, log
`run-p5-v3-leakfix-power300-recorded.log`, run 21:55, ≈ 30 s):

    Read Mesh Features at +383 ms: 1 of 3 handles pending / handle 1               (active)
    Read Mesh Features at +375 ms: 2 of 3 handles pending / handle 1 / handle 2    (queued)
    Read Mesh Features at +389 ms: 1 of 3 handles pending / handle 1               (active - Ext)
    Read Mesh Features at +386 ms: 2 of 3 handles pending / handle 1 / handle 2    (queued - Ext)
    Total: 4, Passed: 0 (0.0%), Failed: 4, Not Run: 0   (all four "Timed out")

**Pre-existing, not introduced by the series (quoted + inferred).** The unpatched base has the
identical tail: `git grep -n -A10 "static void mesh_send_done(struct work_struct"
08e90633377f -- net/bluetooth/mgmt.c` → `if (!hci_dev_test_flag(hdev, HCI_MESH_SENDING))
return;` / `hci_cmd_sync_queue(hdev, mesh_send_done_sync, NULL, mesh_next);` — the flag is
cleared only inside `mesh_send_done_sync()`, which never runs. A runtime differential on the
unpatched base cannot reach the reopen: `run-p5-v3base-unpatched-power300.log` (21:46; the
make argument `STR=off\ 300` selected all ten "power - off" cases) fails every case within
0.09-0.26 s at `Advertising Removed for instance 6` during the power-off — the event 2/N
suppresses for the internal instance — before Set Powered on is sent.

**Decision: fixed, as a separate patch** (it is a real, user-visible defect — after a power
cycle that falls into a transmission, mesh sending stays dead until the controller is removed
— and the fix is one call). New commit on the v3 branch, `a5db4cda33d2 Bluetooth: MGMT:
finish a mesh transmission that ends while powered off` (`Fixes: b338d91703fa`, `Cc: stable`):
`mesh_send_done()` queues its work with `hci_cmd_sync_submit()`, which checks only
`HCI_UNREGISTER` (`hci_sync.c:714-745`), so the done work still runs while the device is down;
its controller commands cannot reach the closed device (`hci_send_frame()` returns `-EINVAL`
when `HCI_RUNNING` is clear, `hci_core.c:3037-3040`, and `hci_send_cmd_sync()` then cancels
the waiting request, `hci_core.c:4128-4131`), the owner is completed and `mesh_next()`
completes what is pending (its `hci_cmd_sync_queue()` fails while down) and clears the flag.
It is independent of the count/deadline question and can be dropped on its own (it touches
only `mesh_send_done()`).

Image `bzImage-v3-4of4-leakfix` (`3bee3d3d4d70` = `a5db4cda33d2` + the scratch cleanup
cherry-picked, branch `scratch/with-upstream-leak-fix-on-a5db4cda33d2`; build log ends
`Kernel: arch/x86/boot/bzImage is ready  (#13)`). Full run `run-p5-v3-4of4-leakfix-kvm-nomon-try3.log`
(21:52-21:53, `Overall execution time: 30.3 seconds`), `Linux version
7.3.0-rc2-00398-g3bee3d3d4d70`: **`Total: 55, Passed: 55 (100.0%), Failed: 0, Not Run: 0`**.
The fixed queued Ext case (quoted):

    Mesh set started for request 1 (1) at +8 ms
    Set Powered off at +12 ms: Success (0x00)
    Mesh Packet Complete handle 1 at +88 ms, 0 tear-downs so far     (while off: at the 75 ms deadline, no 2-s command time-out)
    Mesh Packet Complete handle 2 at +89 ms, 0 tear-downs so far     (the queued one, completed by mesh_next())
    Set Powered on at +388 ms: Success (0x00)
    Read Mesh Features at +389 ms: 0 of 3 handles pending
    Mesh Send 3 at +390 ms: handle 3
    Mesh set started for request 3 (1) at +396 ms
    Mesh Packet Complete handle 3 at +480 ms, 1 tear-downs so far
    Read Mesh Features at +886 ms: 0 of 3 handles pending
    Advertising instances left: 0

Scope of the fix: power-off through Set Powered (what the tester drives). Close through other
paths (rfkill, `HCIDEVDOWN`) skips `hci_power_off_sync()`'s `hci_clear_adv_sync()`; the done
work then runs the same way, but whether a residual mesh instance is re-enabled at the next
power-on is **not tested**.

### D0.2 The LeakSanitizer report is a BlueZ library defect, pre-existing

`Direct leak of 240 byte(s) in 6 object(s) … util_malloc` appears identically in phase 4's
runs: `grep -c -E "LeakSanitizer|leaked in"` → `2` in `run-p4-v2-3of3-kvm-nomon-final2.log`,
`run-p4-bluetooth-unpatched-kvm-nomon.log` and `run-p5-v3-leakfix-kvm-nomon-try1.log`, with
`Direct leak of 240 byte(s) in 6 object(s)` in the first (line 13254). So it is neither the
kernel nor the new cases. 40 bytes is `struct mgmt_notify` (`src/shared/mgmt.c:69-77`: id,
event, index, removed, three pointers). `mgmt_unregister()` (`src/shared/mgmt.c:995-1016` at
`ae69dcddd`) does `notify = queue_remove_if(mgmt->notify_list, …)` and then, when
`mgmt->in_notify`, only `notify->removed = true; mgmt->need_notify_cleanup = true;` — but
`process_notify()` (`:355-372`) frees removed entries by walking `notify_list`, which no
longer holds this one. The generic event cases of mesh-tester unregister from inside their
callback (`command_generic_event_alt()`, `mesh-tester.c:975`). The code dates from
`872729a91 shared/mgmt: Fix crash when removing index` (`git log -L995,1016:src/shared/mgmt.c`).
These are the "six 40-byte `mgmt_register` blocks" phase 3/4 saw under valgrind.

**Fixed in BlueZ, separately from the tester:** `60888a265 shared/mgmt: Fix leak when
unregistering from a notify callback` (`1 file changed, 16 insertions(+), 7 deletions(-)`):
while notifying, the entry is found with `queue_find()`, left on the list and marked, as
`mgmt_unregister_index()`/`mgmt_unregister_all()` already do. Build
`bluez-make-testers-asan-phase5-try4.log` (`CC src/shared/libshared_glib_la-mgmt.lo`,
`CCLD tools/mesh-tester`, no warning). The try3 run above ends without any LeakSanitizer
report (`grep -a -E "LeakSanitizer|leaked in"` → nothing).

### D0.3 Tester change

`mesh_tx_power_callback()` now sends a Read Mesh Features (new check kind
`MESH_TX_FEATURES_RECORD`, printed only) right after Set Powered on, before the Mesh Send of
the reopened controller. Not committed yet (the tester is committed once, after §C/§D).

Step D0 ended 22:05.

## B — Count and the done deadline (started 22:05; the clock of this machine then jumped from about 22:45 on 10-03 to 05:13 on 10-04 between two commands — the times below are as `date` printed them)

### B1. What the code does (quoted)

- Deadline: `mesh_send_interval = msecs_to_jiffies((send->cnt) * 25);` in
  `mesh_send_start_complete()`; instance: `duration = send->cnt *
  INTERVAL_TO_MS(hdev->le_adv_max_interval);` and `hci_add_adv_instance(…, timeout,
  duration, …, hdev->le_adv_min_interval, hdev->le_adv_max_interval, …)` with `timeout =
  1000` in `mesh_send_sync()`. Both lines come from the mesh introduction: `git grep -n -E
  "cnt\) \* 25|duration = send->cnt" b338d91703fa -- net/bluetooth/mgmt.c` →
  `mgmt.c:2251: mesh_send_interval = msecs_to_jiffies((send->cnt) * 25);`, `mgmt.c:2269:
  duration = send->cnt * INTERVAL_TO_MS(hdev->le_adv_max_interval);`; the same at
  `b338d91703fa^` → nothing.
- Default interval: `hci_core.c:2450-2451` `hdev->le_adv_min_interval = 0x0800;`
  `hdev->le_adv_max_interval = 0x0800;` (1280 ms); settable with Set Default System
  Configuration parameters 0x000a/0x000b (`mgmt_config.c:105-106, 271-274`).
- Extended enable (`hci_sync.c:1669-1677`): `set->duration` comes from `adv->timeout`
  (1000 s → the u16 overflow, 1696 = 16.96 s, see the duration note), Max_Extended_Advertising_Events
  is left 0 (`memset(set, 0, …)`); `duration` (cnt × interval) is used only for legacy
  instance rotation.
- The protocol (`doc/mgmt-protocol.rst:4107-4109` at BlueZ `ae69dcddd`): "The Count parameter
  must be sent to a non-Zero value indicating the number of times this packet will be sent
  before transmission completes."
- The only known client: `mesh/mesh-io-mgmt.c:540` `send->cnt = 1;` in `send_pkt()`, and
  `tx_to()` (`:555-603`) re-sends a packet itself, `count` times, every `interval` ms of its
  own transmit timing — bluetooth-meshd never asks the kernel for more than one event per
  Mesh Send.
- Before the series nothing tore the instance down at the deadline: on the legacy path it
  stayed scheduled for 1000 s, with extended advertising the set stayed enabled for the
  16.96 s Duration (inferred from the quoted code; phase 3/4 recorded the `a0 06` Duration
  bytes in every mesh enable). So the unpatched kernel does not honour Count either — it
  sends the packet for seconds whatever Count is.

### B2. The receiver measurement (extended emulator, quoted)

Cases "Mesh - Send receiver - Count 1/3[ - 20 ms interval]" (BREDRLE50): the client
controller of the emulator scans passively with duplicate filtering off (client hooks of
`8e1574ed6`); every LE Extended Advertising Report carrying request 1's packet is counted and
timed against the start (Command Complete of the enable) and the tear-down of the mesh set.
The 20 ms cases set LE Advertisement Min/Max Interval 0x0020 with Set Default System
Configuration first. A report is required; the counts are recorded, not asserted (so the
tester passes on kernels with either option below).

Option 2 code (deadline unchanged) — three runs, three kernels with the same deadline code,
identical counts:

| case | try1 `41309428a5f4` | try2 `41309428a5f4` | try3 `3bee3d3d4d70` |
|---|---|---|---|
| Count 1, 0x0800 (1280 ms) | 1 packet; enable +13, tear-down +48 | 1; +13/+46 | 1; +13/+48 |
| Count 3, 0x0800 | 1 packet; +12/+94 | 1; +12/+95 | 1; +14/+96 |
| Count 1, 0x0020 (20 ms) | 2 packets (+10, +34); +12/+45 | 2 (+10, +34) | 2 (+11, +33) |
| Count 3, 0x0020 | 4 packets (+10, +36, +59, +84); +12/+95 | 4 (+11, +35, +59, +83) | 4 (+11, +35, +59, +83) |

(`grep -a -E "Receiver: Count|packet [0-9]+ received at"` on `run-p5-v3-leakfix-kvm-nomon-try1.log`,
`-try2.log`, `run-p5-v3-4of4-leakfix-kvm-nomon-try3.log`.) The emulator broadcasts once
from inside the enable command and then about every 24 ms for a 20 ms interval.

### B3. The two options

**Option 1 — fix the deadline (prerequisite).** Written and kept: `99ccb3ab4861 Bluetooth:
MGMT: leave room for cnt events in the mesh done deadline` (deadline = 25 ms + (cnt − 1) ×
(interval + 10 ms advDelay); a cnt of 1 keeps 25 ms), placed before the tear-down, on branch
`mesh/phase5-alternative-count-deadline-on-bluetooth-master-2026-10-03` (`b78e2dd67680`, five
patches) in `cache/mesh-guest`; image `bzImage-v3final-leakfix` (`718a10000190` = that +
the scratch cleanup). Run `run-p5-option1-deadline-leakfix-kvm-nomon.log` (22:07-22:10 on
10-03, **while a kernel build was running on the same machine**, so the absolute times are
stretched), `Linux version 7.3.0-rc2-00399-g718a10000190`:

    Receiver: Count 1, advertising interval 0x0800, … 1 packets received   (+35)
    Receiver: Count 3, advertising interval 0x0800, mesh set enabled at +37 ms, torn down at +2803 ms, 3 packets received   (+31, +1330, +2601)
    Receiver: Count 1, advertising interval 0x0020, … 2 packets received   (+27, +67)
    Receiver: Count 3, advertising interval 0x0020, mesh set enabled at +42 ms, torn down at +221 ms, 5 packets received
    Total: 55, Passed: 18 (32.7%), Failed: 37, Not Run: 0     Overall execution time: 189 seconds

Count 3 at the default interval now gives the 3 events the protocol text describes. But the
37 failures are every case that waits for the end of a Count-3 transmission: the six
pre-existing upstream cases `Mesh - Send`, `Mesh - Send cancel - 1`, `- 2` and their Ext Adv
variants (`Timed out` at 1.98-2.51 s; their timeout is 2 s, `test_bredrle()` →
`test_bredrle_full(…, 2)`, `mesh-tester.c:706-707`), and the lifecycle cases (4-6 s
timeouts, each transmission now 2.6 s). Consequences: completion latency of a Count-3 Mesh
Send at the default interval goes from 75 ms to ≈ 2.6 s (×35) while it holds the single mesh
slot; the existing `TestRunner_mesh-tester` cases would start timing out on every kernel
patch until the tester changes; bluetooth-meshd (cnt 1) unaffected; at short intervals the
host timer still overshoots (5 events for Count 3 at 20 ms, more than today's 4). Exact
counts at short intervals would need the controller to count (Max_Extended_Advertising_Events
= cnt, extended only; no legacy equivalent).

**Option 2 — document the limitation (recommended).** Keep the deadline; state in the code,
the cover and the results that Count is honoured only when cnt × 25 ms matches the
configured interval: one event at the default 1280 ms whatever Count is, about Count + 1 at
20 ms (B2). Consequences: nothing changes for bluetooth-meshd or the existing test suite; a
hypothetical client relying on Count > 1 at the default interval gets one event (before the
series it got seconds of advertising, B1); the protocol mismatch stays open as a separate
change that needs its own compatibility discussion and a coordinated tester update.

**Recommendation and patch.** Option 2, because the series is a stable fix whose purpose
does not depend on Count, Option 1 measurably breaks the existing upstream test cases and
multiplies latency for Count > 1, and the only known client is served by the current
deadline. Implemented as a separate, last, comment-only patch, clearly droppable:
`a4023e09b21d Bluetooth: MGMT: note what the mesh done deadline does to Count` (7 lines of
comment in `mesh_send_start_complete()`, no `Fixes:`, no stable tag). **This is the
operator's decision point:** keep 5/5 (Option 2), drop it (nothing else changes), or take
Option 1 from the alternative branch instead (then the tester's Count-3 cases and timeouts
have to change first).

Until the operator decides, the cover keeps the review's interim sentence (§F).

Step B ended 05:20 (10-04).

## The final sequence (quoted)

`git -C cache/mesh-guest log --format='%h %s' -6 mesh/phase5-series-v3-final-on-bluetooth-master-2026-10-03`:

    a4023e09b21d Bluetooth: MGMT: note what the mesh done deadline does to Count          (5/5, droppable, comment only)
    319c4bdbf89d Bluetooth: MGMT: finish a mesh transmission that ends while powered off  (4/5, new, §D0)
    7cdb27a87fac Bluetooth: MGMT: complete the mesh transmission that owned the instance  (3/5 = v2 3/3)
    c0b18e7ca30f Bluetooth: MGMT: remove the mesh advertising instance when done          (2/5 = v2 2/3, message §F)
    f40c7a65bcb2 Bluetooth: MGMT: hand mesh transmissions over under hdev->lock           (1/5 = v2 1/3 + lockdep_assert_held, message §A)
    08e90633377f Bluetooth: RFCOMM: Fix NULL tty_dev dereference in rfcomm_dev_shutdown

`git diff --stat a5db4cda33d2 319c4bdbf89d` → no output: patches 1-4 carry exactly the code
tested as `bzImage-v3-4of4-leakfix` (try3). Other branches kept, nothing deleted:
`mesh/phase5-series-v3-on-bluetooth-master-2026-10-03` (`a5db4cda33d2`, the four patches with
the earlier message of 2/N), `keep/phase5-v3-four-patches-a5db4cda33d2`,
`keep/phase5-v3-final-draft-9d7228dae3bd`, `mesh/phase5-alternative-count-deadline-on-bluetooth-master-2026-10-03`
(`b78e2dd67680`, Option 1), scratch branches `scratch/with-upstream-leak-fix`,
`…-on-a5db4cda33d2`, `…-on-b78e2dd67680`, `…-on-a4023e09b21d` (each = its base + the local
cleanup, never for submission).

Images of the final sequence (built 05:13-05:19 on 10-04 by `build-chain-v3series.sh`, all
with `frag-fault.config` unless noted; each `.commit` file names the commit):

    bzImage-v3-series-leakfix         c4ae5857e5d1 = a4023e09b21d + local cleanup     (the gate image)
    bzImage-v3-series-leakfix-trace   the same + CONFIG_KPROBE_EVENTS (frag-fault-kprobe.config)
    bzImage-v3-series                 a4023e09b21d alone
    bzImage-v3base-unpatched          08e90633377f (from step 1)

`v3-series-leakfix-kcsan` failed to link: `ld: vmlinux.o: in function 'do_syscall_64':
(.noinstr.text+0x4d2): undefined reference to 'syscall_enter_audit'`
(`kernel-build-v3-series-leakfix-kcsan.log:1825-1826`; `include/linux/entry-common.h:105-106`
calls it under `audit_context()`, `kernel/entry/syscall-common.c:21-30` defines it only with
`CONFIG_AUDITSYSCALL`, which this config lacks — a tree/config problem, not ours). Retried
with `frag-kcsan-audit.config` (adds `CONFIG_AUDIT=y`), §E.

## C — cancellation with causal evidence (quoted)

Branch evidence comes from kprobe events inside the guest: `guest-kprobe-trace.sh` (runs in
qemu only) installs `p:` probes on `mesh_send_sync`, `mesh_send_start_complete` (with
`err=$arg3`), `mesh_send_done_sync`, `send_cancel`, `mesh_next`, `hci_cmd_sync_clear`,
`mgmt_cleanup` and `p:`/`r:` on `hci_cmd_sync_dequeue` (`data=$arg3`, `ret=$retval`), runs
`mesh-tester -d -s <filter>` and prints the trace buffer; `run-trace.sh` starts it on
`bzImage-v3-series-leakfix-trace` (`Linux version 7.3.0-rc2-00399-gc4ae5857e5d1 … #18`). All
nine probes were accepted (`kprobe added: …` ×9, no `kprobe NOT added`). Runs (10-04):
`run-p5-trace-held.log` (05:17:23 to 05:17:36, `Total: 8, Passed: 8`), `run-p5-trace-close.log`
(05:18:32 to 05:18:42, 4/4), `run-p5-trace-unregister.log` (08:13:36 to 08:13:39, 4/4),
`run-p5-trace-power.log` (08:13:43 to 08:13:53, 10/10).

**C1. Active cancel, held start** ("Mesh - Send queue - cancel active - held start"). Tester
(`case-trace.sh run-p5-trace-held.log …`):

    Holding start command 0x200a at +28 ms                     (request 1's enable, never answered yet)
    Sending Mesh Send Cancel for handle 1 at +29 ms with the command held
    Barrier answered at +33 ms with the command held: 2 handles pending / handle 1 / handle 2
    Releasing the held command at +37 ms
    Mesh set started for request 1 (1) at +47 ms
    Mesh Packet Complete handle 1 at +49 ms, 0 tear-downs so far (1 of 2)
    Mesh Send Cancel at +51 ms: Success (0x00)
    Mesh set started for request 2 (1) at +151 ms
    Mesh Packet Complete handle 2 at +260 ms, 2 tear-downs so far (2 of 2)

Kernel (same run, trace lines 5781-5791):

    4.202410: send_sync: data=0xffff888002a38880                              (request 1's start, blocked on the held enable)
    4.243369: start_complete: data=0xffff888002a38880 err=0                   (released)
    4.243395: send_cancel:                                                    (next work item: the Cancel was queued behind the start)
    4.243400: dequeue_in: … data=0xffff888002a38880
    4.243404: dequeue_ret: (send_cancel+0x2c0 <- hci_cmd_sync_dequeue) ret=0  (nothing queued for it: it already ran)
    4.320215: done_sync:                                                      (request 1's done work, 75 ms after its start)
    4.327858: mesh_next:
    4.327888: send_sync: data=0xffff888001ef9600                              (request 2, once)

The barrier (a Read Mesh Features written with `mgmt_send_nowait()` right behind the Cancel on
the same socket; it is answered from the caller's context, so it cannot wait behind the
serialized Cancel reply) was answered while the enable was still held, and `send_cancel` is the
work item right after the released start: **Cancel(A) was queued before A's transmission could
end**. A then completes before any tear-down, the Cancel reply comes only after the release
(the case fails on `mesh_tx_cancel_acked_held`), B is started once, each handle completes once.
This is the review's finding 3 replacement test; a natural A-then-B sequence fails it on three
counts (A would complete after a tear-down, the barrier would not be answered while held, and
A's completion would come ~75 ms after its start). The pre-existing timing-based "cancel active"
cases stay as they are.

**C2. Queued-start dequeue** ("Mesh - Send queue - cancel queued - held tear-down"):

    Holding tear-down command 0x200a at +111 ms
    Sending Mesh Send Cancel for handle 2 at +114 ms with the command held
    Barrier answered at +118 ms with the command held: 2 handles pending / handle 1 / handle 2
    Releasing the held command at +120 ms
    Mesh Packet Complete handle 1 at +126 ms, 1 tear-downs so far (1 of 3)
    Mesh Packet Complete handle 2 at +128 ms, 1 tear-downs so far (2 of 3)
    Mesh Send 3 at +132 ms: handle 3
    Mesh set started for request 3 (1) at +149 ms
    Mesh Packet Complete handle 3 at +241 ms, 2 tear-downs so far (3 of 3)
    request 2: handle 2, 0 starts, 1 completions

Kernel (trace lines 5795-5807):

    5.291993: done_sync:                                                     (request 1's tear-down, held)
    5.312392: mesh_next:                                                     (after the release: queues request 2's start)
    5.312426: send_cancel:                                                   (the Cancel, queued during the hold, runs next)
    5.312432: dequeue_in: … data=0xffff8880028cb200
    5.312436: start_complete: data=0xffff8880028cb200 err=-125               (-ECANCELED, called from inside the dequeue, under cmd_sync_work_lock)
    5.312647: dequeue_ret: (send_cancel+0x2c0 <- hci_cmd_sync_dequeue) ret=1  (the successful dequeue)
    5.312725: mesh_next:                                                     (send_cancel's hand-over, `if (dequeued)`)
    5.319493: send_sync: data=0xffff888002bc3180                             (request 3)

**Branch evidence for all three items the review listed as unexercised** (A1.2): a successful
`hci_cmd_sync_dequeue()` of a queued `mesh_send_sync` (`ret=1`), the `-ECANCELED` callback
(`err=-125` between `dequeue_in` and `dequeue_ret`, i.e. under `cmd_sync_work_lock`), and the
hand-over after it (request 3 started; without the `mesh_next()` the flag would stay set and
request 3 would never start, as §D0 showed for the stale flag). The Ext variants repeat both
patterns (trace lines 5811-5837). Unregister with a queued `mesh_send_sync` entry: §D3.

**C3. Two sockets** ("cancel from other socket"): request 2 and Cancel(handle 1) on a second
socket; Cancel acknowledged, handle 1 left alone, both complete in order (`mesh_tx_stops_1_2`).
Passed in every run (try3, final, repeats).

**Scope of the return checks:** the *new lifecycle operations* (every Mesh Send, Cancel, Set
Powered, Read Mesh Features, Read Advertising Features, Set Default System Configuration,
register/hook calls of `test_mesh_tx()`) check their returns; the pre-existing generic helpers
(`setup_enable_mesh()`, `test_command_generic()`, …) still contain unchecked sends — not every
send in the file is checked.

## D — power transitions and unregister (quoted)

**D1. The corrected argument** (review finding 4) replaced in `REVIEW-TASK-SERIES-V2.md` (the
`-ENETDOWN` sentence of question 3) and annotated in both copies of `phase4-results.md` (its
sentence is about the done work and is true, §D0; the refuted claim was about accepted starts).
`BRIEF.md` lives outside the writable area; its line 51-52 already states the correction.

**D2. What actually happens to an accepted start after close** — measured. "power - off with held
tear-down": the tear-down of request 1 is held, Set Powered off is sent during the hold, the
kernel cancels the held command (`Bluetooth: hci0: Opcode 0x200a failed: -112`, line 2560;
Ext `Opcode 0x2039 failed: -112`, line 9755), finishes the done work, `mesh_next()` queues request 2's start, which runs **after** the close: trace
`run-p5-trace-power.log` lines 10391-10396:

    3.022964: done_sync:
    3.025703: mesh_next:
    3.026076: send_sync: data=0xffff888001ca8280                 (request 2's start, device closed)
    3.026403: start_complete: data=0xffff888001ca8280 err=-22    (-EINVAL after 0.3 ms: hci_send_frame() refuses with HCI_RUNNING clear)
    3.026503: mesh_next:                                         (failed-start path hands over)

(kernel line 2561 `Bluetooth: hci0: Opcode 0x2008 failed: -22`; Ext: trace lines
10477-10479, `err=-22` after 0.3 ms, kernel line 9791 `Opcode 0x2036 failed: -22`.) So in this emulator setup the accepted start fails promptly with `-EINVAL`, not
`-ENETDOWN` and not the 2-s command timeout; the request is completed (`Mesh Packet Complete
handle 2 at +96 ms` legacy / `+100 ms` Ext) and the scheduler hands over. The review's sentence
stays true as a general statement (no down-device guard in that path; a real driver's `send`
may behave differently); what is now established is this path on this emulator.

**D3. Results of the power and unregister cases** (final gate run and trace runs; all pass):

| case | what the kernel did (trace / tester) |
|---|---|
| off with active request (on at once) | done work fires after reopen; request 3 started and completes; `Read Mesh Features … 0 of 3` |
| off with queued request (on at once) | after reopen: handle 1 completes, request 2 started, then request 3 — order kept |
| off with held tear-down | §D2: request 2's start fails with `-EINVAL` on the closed device, completed; request 3 works after reopen |
| off 300 ms, active / queued | done work runs while off (4/5): handles complete at +86-90 ms; after reopen `0 of 3 handles pending`, request 3 started and completes |
| unregister with backlog | request 1 on air, request 2 pending; `hci_cmd_sync_clear` runs (no mesh entry on the sync list), the done work is cancelled by `mgmt_index_removed()`; removal completes, no report |
| unregister with held tear-down | the held tear-down is cancelled, the done work goes on: `Mesh Packet Complete handle 1 at +94 ms`, `handle 2 at +95 ms` (its start could not be queued, `HCI_UNREGISTER`); removal completes |

`splat-check.sh` (new helper: counts only lines that *start* a kernel report — `BUG:`,
`WARNING:`, KASAN, KCSAN, lockdep circular/recursive/other, hung task, sleep in atomic,
Oops/GPF, `tx timeout`, kmemleak — and the FAULT_INJECTION dumps separately) on the four trace
logs and the gate logs: `report headers: clean` for each; the only dumps are the 8
`FAULT_INJECTION: forcing a failure.` of the rejected-start probes. (The make target
`splat-grep` also matches `? lockdep_hardirqs_on_prepare` frames *inside* those dumps — 9 lines
per run — which is why the new helper exists.)

**D4. Findings recorded, not fixed (pre-existing; inferred from the traces and the source):**

1. *Unregister with a backlog leaks the pending requests.* `mesh_pending` entries are freed only
   through `mesh_send_complete()`/`mgmt_mesh_remove()` (`grep -rn -E
   "mesh_pending|mgmt_mesh_remove|mesh_send_complete\(" net/bluetooth/` → only `mgmt.c` and
   `mgmt_util.c` sites, none on the unregister path; `hci_core.c:2501` only initialises the
   list). With the done work cancelled at index removal, requests 1 and 2 of the backlog case are
   never completed or freed, and since each `mesh_tx` holds `sock_hold(sk)`
   (`mgmt_util.c:425-426`) the requesting socket is never destroyed: in
   `run-p5-trace-unregister.log` the backlog cases show one `mgmt_cleanup` at teardown (lines
   2240, 2251) where every other case shows two. Same code before the series. No kmemleak in
   the guest config, so the leak itself is inferred, not reported by a tool.
2. *A start that fails after `hci_add_adv_instance()` leaves the instance* (phase-4 Open 3) —
   now with its consequence: in "power - off with held tear-down - Ext" the power-on sequence
   re-programs and re-enables the mesh set with request 2's packet (`HCI Command 0x2036 / 0x2037
   / 0x2035 / 0x2039` during power-on, tester: `Mesh set started for request 2 (1) at +168 ms`)
   although handle 2 had completed at +100 ms; it is on air until request 3 replaces it at
   +182 ms. Without a next request it would stay until the extended Duration (16.96 s) ends.
   Legacy does not re-enable it in this run. Not introduced by the series (`mesh_send_sync()` is
   unchanged); 2/5's message already says recovery of a residual instance is not handled.
3. The 4/5 fix covers power-off through Set Powered; rfkill/`HCIDEVDOWN` are not tested (§D0).

Step C/D written 08:25-17:40 on 10-04 (wall clock with the machine's suspend gaps).

## E — socket close and lifetime: differential runs (quoted + inferred)

**What closing the socket does to its requests (quoted trace, inferred mechanism).** Each
`mesh_tx` pins its socket: `mgmt_mesh_add()` does `mesh_tx->sk = sk; sock_hold(sk);` and
`mgmt_mesh_remove()` `sock_put(mesh_tx->sk)` (`mgmt_util.c:425-426, 436`), and
`mgmt_cleanup()` is called only from the socket destructor (`hci_sock.c:2177-2183`,
`hci_sock_destruct()` → `mgmt_cleanup(sk)`). So a closed socket is not destroyed while one of
its requests is pending, and `mgmt_cleanup()` then finds nothing of its own to remove: the
requests run to completion. `run-p5-trace-close.log` ("close - socket closed in tear-down",
since renamed "close - in held tear-down"): the socket is closed at +118 ms with requests 1
and 2 pending, `Mesh Packet Complete handle 1 at +151 ms`, `Mesh set started for request 2
(1) at +169 ms`, `handle 2 at +272 ms`, and the kernel trace shows the destructor running
inside the done work of the last request, between `done_sync` and `mesh_next`:

    5.051363: done_sync:
    5.074041: mgmt_cleanup:      (the closed socket's last sock_put, under hdev->lock in mesh_send_done_sync())
    5.074072: mesh_next:

The race the review described (A1.4: socket close freeing an element the loop or queued work
still holds) is therefore not reachable through closing the requesting socket in these paths
(inferred from the code above, consistent with every trace); `mgmt_cleanup()` still walks
*other* adapters' `mesh_pending` lists without their `hdev->lock` — pre-existing, unchanged,
not exercised here (one adapter). **One change the series does make:** on the unpatched
kernel the last `mesh_send_complete()` of a closed socket, and with it the destructor and
`mgmt_cleanup()`'s `read_lock(&hci_dev_list_lock)`, ran without `hdev->lock`
(`git grep -n -A28 "^static int mesh_send_done_sync" 08e90633377f` → no lock in it); with
the series it runs under `hdev->lock` (done work, `send_cancel()`, `mesh_next()`'s drain) or
under `cmd_sync_work_lock` (the `-ECANCELED` callback). Taking an rwlock reader inside a mutex
is a valid order and nothing takes `hdev->lock` inside `hci_dev_list_lock` (a mutex cannot be
taken under a spinning lock); lockdep (PROVE_LOCKING) recorded nothing in the runs where the
destructor ran there (trace above; all close cases below). No `hdev->lock` was added to
`mgmt_cleanup()`.

**Differential runs, 10-04, final tester build** (`gates-e-diff.sh`; `splat-check.sh` on each log):

| run | kernel | result | kernel reports |
|---|---|---|---|
| `run-p5-e-close-unpatched-kasan.log` 17:55:14 to 17:55:19 | `08e90633377f`, KASAN+lockdep | close cases 4/4 | clean |
| `run-p5-e-close-series-kasan.log` 17:55:20 to 17:55:25 | `c4ae5857e5d1` (series + cleanup), KASAN+lockdep | 4/4 | clean |
| `run-p5-e-all-unpatched-kcsan.log` 17:55:25 to 17:55:50 | `08e90633377f`, KCSAN+lockdep (`frag-kcsan-audit.config`) | 18/55 | 1: `BUG: KCSAN: data-race in lapic_cal_handler / setup_boot_APIC_clock` (line 39, boot) |
| `run-p5-e-all-series-kcsan.log` 17:55:51 to 17:56:26 | `c4ae5857e5d1`, KCSAN+lockdep | **55/55** | the same single boot-time report, nothing else |

Plus the KASAN+lockdep full runs of §G (both kernels, clean). Caveat on comparability: on the
unpatched kernel there is no tear-down command, so the "held tear-down" close case holds the
next start's `LE Set Advertising Enable 0x00` instead (`run-p5-unpatched-kvm-nomon.log`
trace: `Holding tear-down command 0x200a at +93 ms` *after* `Mesh Packet Complete handle 1 at
+89 ms`); both kernels see a socket closed while a held command keeps the sync worker busy.
KCSAN samples watchpoints, so a clean run is not proof of absence.

**Non-regression statement.** In these runs neither KASAN, lockdep nor KCSAN reported anything
from Bluetooth code on either kernel; closing the requesting socket does not free its pending
requests on either kernel (they pin the socket); the series moves the socket's final release
under `hdev->lock`, which lockdep accepted in every run. No regression found; the cross-adapter
unlocked walk in `mgmt_cleanup()` and the general list/work lifetime design remain the
pre-existing, scoped risk. Context, not prerequisites: the two public locking/lifetime
proposals of 7 August (lists.openwall.net/linux-kernel/2026/08/07/798 and /800), the latter of
which lets a cancelled queued send run.

## F — messages, cover and duration note (quoted)

- 2/5's comment carries the review's replacement ("Account for the request even if teardown
  fails. Recovery of a residual advertising instance is not handled here." — wrapped into the
  block comment at `mgmt.c:1133-1135` of the final tip, `git grep -n -E "teardown
  fails|residual advertising" 71a4243699c8` → `mgmt.c:1134: * the request even if teardown
  fails. Recovery of a residual`); its message says the same and no longer claims a relationship to Count
  ("The tear-down happens when the done work fires; this patch does not change when that is.").
- 1/5: `lockdep_assert_held(&hdev->lock)` at the top of `mesh_next()` (`mgmt.c:1110` at
  `71a4243699c8`; exercised by every run with PROVE_LOCKING, no assertion fired); the dependency paragraph names the posted cleanup by subject and date;
  **the stable prerequisite line for `71af682ba469` is dropped**: `stable-dep-check.sh` (10-04
  17:48) → `stable/linux-7.2.y: 03ced4687fb7 v7.2.9~402 … [ Upstream commit
  71af682ba4692c2ed9ace4c3d4ca462ae368c029 ]`, `6.18.y: 2189a219397d v6.18.55~348`, `6.12.y:
  084be9094863 v6.12.112~527`, `6.6.y: 718a8ffa180d v6.6.158~216`, `6.1.y: f84e52829021
  v6.1.189~155` (releases of 2026-10-03). The final branch was re-created with only that line
  changed (`rebuild-final-branch.sh`; `git diff --stat a4023e09b21d 71a4243699c8` → empty).
- Cover (`series-v3/0000-cover-letter.patch`): "With only the tear-down applied…" replaced by the
  review's sentence, adapted only in naming the prerequisite "(patch 1)" instead of "v2"
  because no earlier revision was posted; "microseconds" removed; "no stable kernel was built or
  run" kept; the scope sentence of §B kept verbatim (with "Count x 25 ms" for the
  multiplication sign, ASCII); the review's compatibility statement verbatim; the posted cleanup
  named by subject, author, date and archive URL, its diff not included; the testing table says
  what was and was not tested. `python3 … >72` over the cover → only the Subject header line.
- `duration-overflow-note-v3.md`: the remainder-8 row (6357 → 6,357,000 → 8 → 0) and the
  review's paragraph were already in (an earlier step); added the exhaustive re-check command and
  its output and the line numbers at the final tip.
- Record corrections (review item 6) in `phase4-results.md` (both copies): the Signed-off-by
  sentence had been corrected on 10-03; the "cancel of a queued start" claim of §3h is now
  bracketed with the review's correction text; the `-ENETDOWN` sentence annotated (§D1).

Step E/F written 17:56-18:10 on 10-04.

## G — every gate on the final sequence (quoted)

### G0. What "final" is

- Kernel: `mesh/phase5-series-v3-final-on-bluetooth-master-2026-10-03` = **`71a4243699c8`**
  (`266dda8daee0` 1/5, `27de7c1e6e96` 2/5, `9085912a65bc` 3/5, `3503c91ec6f2` 4/5,
  `71a4243699c8` 5/5) on `08e90633377f`. It replaces the sequence `a4023e09b21d` quoted in
  "The final sequence" above only by the message of 1/5 (§F; `git diff --stat a4023e09b21d
  71a4243699c8` → empty), so the runs on images built from `a4023e09b21d`/`c4ae5857e5d1`
  (trace, KCSAN, the first gate pass) ran the same code. Kept: `keep/phase5-v3-final-a4023e09b21d`.
- Gate images rebuilt from the final hashes (`gates-final.sh`, 17:57:28 to 18:00:34; `make -s`,
  so the build logs are empty and the `.commit` files are the record):
  `bzImage-v3-final-leakfix` (`64bd2d50f5de` = `71a4243699c8` + local cleanup,
  `scratch/with-upstream-leak-fix-on-71a4243699c8`) and `bzImage-v3-final` (`71a4243699c8`).
- BlueZ: `mesh-tester/phase5-lifecycle-tests-2026-10-03` = `8e1574ed6` (emulator hooks),
  `60888a265` (shared/mgmt leak), `05e973d72` (tester.config), **`6640247e6`** (tester). The
  tester commit `f620a4976` (kept on `keep/mesh-tester-phase5-tester-f620a4976`) was amended
  after BlueZ checkpatch reported 22 `LONG_LINE*` warnings (first export; the phase-4 tester
  had none): lines re-wrapped and six case names shortened so the registrations fit 80
  columns — "cancel active - held start" → "cancel held start", "cancel queued - held
  tear-down" → "cancel held tear-down", "cancel from other socket" → "cancel other socket",
  "unregister - with held tear-down" → "unregister - held tear-down", "close - socket closed in
  start/tear-down" → "close - in held start/tear-down" (the earlier sections quote the old
  names). `git diff --stat f620a4976 6640247e6` → `tools/mesh-tester.c | 75 ++++…---, 43
  insertions(+), 32 deletions(-)`; no behaviour change (one condition now uses the equal local
  `n + 1` instead of `data->mesh_tx_cmplt_count`, which was just set to it).
  `cache/bluez-noasan` detached at `6640247e6`, rebuilt (`bluez-make-testers-noasan-phase5-final2.log`, 0 error/warning lines).
  After the gates the message of the shared/mgmt patch gained the mgmt-tester figure (G2):
  branch re-created by `rebuild-bluez-branch.sh` → **`8e1574ed6`, `2a32642aa`, `be159716a`,
  `7c62b76f4`** (`git diff --stat 6640247e6 7c62b76f4` → empty; old tip kept on
  `keep/mesh-tester-phase5-6640247e6`). The binaries tested are built from this same code.

### G1. Static gates (`gates-static.log` 17:42-17:44, `gates-static2.log` 17:47-17:47, 10-04)

- Kernel checkpatch `--strict --codespell` (codespell `/usr/bin/codespell`) on the exported
  files: 1/5 `total: 0 errors, 0 warnings, 0 checks, 171 lines checked`; 2/5 `… 31 lines`;
  3/5 `… 19 lines`; 4/5 `… 13 lines`; 5/5 `… 13 lines`; alternative `… 20 lines`; the revised
  1/5 again after the message change → `0 errors, 0 warnings, 0 checks, 171 lines checked`.
- In-tree preflight (`scripts/kernel-preflight.sh` with `BT_SPARSE=cache/sparse/sparse`, run by
  the gate script) on `cache/full-bt-next` after `git am` of the five (`9ef4e0dd8248` tip, kept
  on `keep/full-bt-next-phase5-v3-final-9ef4e0dd8248`), tip first: every commit
  `checkpatch --strict -g HEAD … 0 errors, 0 warnings, 0 checks`, `W=1 -Werror: clean`,
  `findings in mgmt.c: base 0, patched 0`, `no new sparse finding introduced by the patch`,
  exit 0 ×5 (the script refuses without a `CHECK … mgmt.c` line, so sparse did run).
- BlueZ gitlint: `PASS no violations` ×4 (final export). BlueZ checkpatch (BlueZ's
  `.checkpatch.conf`): `0 error(s), 0 warning(s), 0 check(s)` ×4 (118, 34, 9, 2803 lines).
- Stable (fetch 17:47 → new tips `v7.2.9`, `v6.18.55`, `v6.12.112`, `v6.6.158`, `v6.1.189`,
  all 2026-10-03): the five patches alone **APPLY** on all five, offsets only (`[1: offset -6
  lines …]` on 7.2.y … `[1: offset -74 lines …]` on 6.1.y); `71af682ba469` first now gives
  `Reversed (or previously applied) patch detected` on all five — it is in them (§F).
  Text application only, through `series-backport-check-local.sh` (a line-for-line copy of
  `scripts/series-backport-check.sh` whose scratch directory is under `tmp/mesh-tester-ci/`).
- Recipients (`scripts/get-maintainers.sh cache/full-bt-next <patch>`): all five — Marcel
  Holtmann and Luiz Augusto von Dentz (maintainers, BLUETOOTH SUBSYSTEM), linux-bluetooth,
  linux-kernel; plus Brian Gix (`blamed_fixes`) on 1/5, 3/5, 4/5 (`Fixes: b338d91703fa`) and
  Christian Eggers on 2/5 (`Fixes: f3cb5676e5c1`); 5/5 has no `Fixes:`. Addresses are in the
  raw log, not here.
- Revised 1/5 in-tree (`gates-final.log`, 18:09): `git am` on `08e90633377f` → `8abc0fb87492`;
  `checkpatch --strict -g HEAD` `0 errors, 0 warnings, 0 checks, 171 lines checked`, `W=1
  -Werror: clean`, sparse `base 0, patched 0`, `no new sparse finding` (kept on
  `keep/full-bt-next-phase5-v3-final-patch1`).
- The inverted cleanup is in the stable lines too (`git grep -n -A2 "if (mesh_tx) {"
  stable/linux-6.1.y stable/linux-7.2.y -- net/bluetooth/mgmt.c` → `6.1.y mgmt.c:2449-2451`,
  `7.2.y mgmt.c:2538-2540`: `if (mesh_tx) { if (sending) mgmt_mesh_remove(mesh_tx);`), so the
  posted cleanup is needed there as well (cover).

### G2. VM gates (`gates-final.sh`, 10-04 17:57:28 to 18:09:51, one VM at a time; `gates-final.log`)

Tester `6640247e6` (= `7c62b76f4` code), ASAN build for KVM, sanitizer-free build under
valgrind for TCG; every log checked with `splat-check.sh` (positive control: it reports the
two `tx timeout` lines of mgmt-tester's own timeout cases, `command 0x0405 tx timeout`,
also present on the unpatched kernel and in phase 4).

| run (log `run-<tag>.log`) | kernel (`Linux version …-g`) | result | kernel reports | tester leaks |
|---|---|---|---|---|
| `p5-G-final-leakfix-kvm` 18:00:34 to 18:01:06 | `64bd2d50f5de` (final + cleanup) | **55/55** (BREDRLE and BREDRLE50 cases) | clean; 8 fault-injection dumps (the probes) | none (no LeakSanitizer line) |
| `p5-G-final-alone-kvm` 18:01:07 to 18:01:37 | `71a4243699c8` (final, no cleanup) | 53/55: the two rejected-start cases (`Expected only handle … (request 2) to be pending` — the dependency) | clean | none |
| `p5-G-unpatched-kvm` 18:01:38 to 18:02:00 | `08e90633377f` | 18/55 (4 cancel `Timed out`, 33 `Failed`) | clean | none |
| `p5-G-option1-leakfix-kvm` 18:02:00 to 18:05:03 (unloaded rerun) | `718a10000190` (Option 1 + cleanup) | 20/55: `Mesh - Send` 2.359 s, `Mesh - Send - Ext Adv` 2.000 s and the four `Send cancel` cases `Timed out`, plus 29 lifecycle cases | clean | none |
| `p5-G-final-leakfix-mgmt` 18:05:04 to 18:06:01 | `64bd2d50f5de` | 501/503 (`Pairing Acceptor - SSP/LE Security Level Changed` `Timed out`; also on the unpatched kernel, §G earlier runs) | 2 × `tx timeout` (mgmt-tester's own) | 120 B in 5 objects from `btdev_add_hook` (emulator hook list, phase-4 Open 6); phase 4's run had in addition `9000 byte(s) in 225 object(s)` from `util_malloc` — gone with the shared/mgmt fix |
| `p5-G-repeat-cancel-1..5` 18:06:01 to 18:06:44 | `64bd2d50f5de` | 16/16 ×5 = **80/80** | clean ×5 | — |
| `p5-G-repeat-tear-down-1..5` 18:06:44 to 18:07:20 | same | 10/10 ×5 = **50/50** | clean ×5 | — |
| `p5-G-repeat-receiver-1..5` 18:07:20 to 18:07:38 | same | 4/4 ×5 = **20/20** | clean ×5 | — |
| `p5-G-final-leakfix-tcg-valgrind` 18:07:38 to 18:08:41 | `64bd2d50f5de`, TCG | **50/50** ("Send" cases) | clean | `ERROR SUMMARY: 1 errors from 1 contexts` (the pre-existing `bt_log_open` bind, phase 3/4's first of seven; the six `mgmt_register` blocks are gone), `definitely lost: 0` |
| `p5-G-unpatched-tcg-valgrind` 18:08:41 to 18:09:34 | `08e90633377f`, TCG | 13/50 | clean | the same 1 error |

Earlier passes on the same code (images from `a4023e09b21d`/`c4ae5857e5d1`, tester
`f620a4976`; `gates-vm-kvm.sh` 08:15-08:19 and `gates-mgmt-diff.sh`/`gates-tcg-valgrind.sh`
17:35-17:39 on 10-04): 55/55, 53/55, 18/55, mgmt 500/503 then 501/503 (the extra failure of the
first run, `LL Privacy - Start Discovery 1 (Disable RL)`, `Unexpected HCI command parameter
value` on `0x202d`, did not recur in the second run on the same image nor on the unpatched
kernel; unrelated to mesh), repeats 80/80, 50/50, 20/20, TCG 50/50 and 13/50 — the same
results. Receiver counts in the final run: Count 1/3 at 0x0800 → 1/1 packet, at 0x0020 → 2/4,
identical to B2.

Step G ended 18:20 (10-04).

## Summary

**What changed since phase 4 and why.** v3 is five kernel patches on `08e90633377f`
(`71a4243699c8`) and a four-patch BlueZ series (`7c62b76f4`). 1/5-3/5 are v2's three patches:
1/5 with `lockdep_assert_held()` in `mesh_next()`, the dependency paragraph and the obsolete
`71af682ba469` stable prerequisite dropped (that commit reached all five stable lines on
10-03); 2/5 with the review's teardown sentence and no Count claim. 4/5 is new: the stale
`HCI_MESH_SENDING` after a power-off that falls into a transmission, found by the new power
tests, pre-existing since `b338d91703fa`, fixed by submitting the done work with
`hci_cmd_sync_submit()`. 5/5 is the droppable comment documenting the Count/deadline
limitation (Option 2); Option 1 is written, measured and kept as the alternative. The posted
mesh_tx cleanup of 2026-09-19 is assumed and named, never copied; every guest test that needs
it ran with a local scratch equivalent. BlueZ: hooks on the emulator's client controllers, a
`src/shared/mgmt.c` leak fix (the LeakSanitizer report: 6 objects in mesh-tester, 225 in
mgmt-tester), fault injection in `doc/tester.config`, and the tester (55 cases, 30 new:
causal cancel, queued-start dequeue, other socket, rejected start, 10 power, 4 unregister, 4
close, 4 receiver).

**Results** (quoted in §D0-§G):

| configuration | unpatched `08e90633377f` | final alone `71a4243699c8` | final + cleanup | 3/5 + cleanup (`41309428a5f4`) | 4/5 + cleanup (`3bee3d3d4d70`) | Option 1 + cleanup (`718a10000190`) |
|---|---|---|---|---|---|---|
| mesh-tester 55, KVM, KASAN+lockdep | 18/55 | 53/55 (rejected start ×2: the dependency) | **55/55** (two KASAN passes) | 51/55 (off 300 ms ×4: stale flag) | 55/55 | 20/55 (every Count-3 wait, incl. 6 pre-existing cases) |
| 50 Send, TCG + valgrind | 13/50, 1 err | — | **50/50**, 1 err (pre-existing) | — | — | — |
| cancel / tear-down / receiver ×5 | — | — | **80/80, 50/50, 20/20** | — | — | — |
| mgmt-tester 503 | 501/503 | — | **501/503** (the 2 need bluetooth-next) | — | — | — |
| mesh-tester, KCSAN+lockdep | 18/55 | — | **55/55** | — | — | — |
| close cases, KASAN+lockdep | 4/4 | — | 4/4 | — | — | — |
| kprobe branch evidence (held/close/unregister/power) | — | — | 26/26 cases traced | — | — | — |
| kernel reports in any run | KCSAN: 1 boot race (APIC) | none | none (KCSAN: same boot race) | none | none | none |
| checkpatch --strict --codespell / W=1 / sparse, per commit | — | 0/0/0, clean, 0 new ×5 | | | | alternative 0/0/0 |
| stable 7.2.9/6.18.55/6.12.112/6.6.158/6.1.189 (text) | — | APPLIES ×5, offsets only | | | | |
| BlueZ gitlint / checkpatch | — | 4/4 pass, 0/0/0 ×4 | | | | |
| tester LeakSanitizer | 240 B/6 before the BlueZ fix | none after | none | | | |

**Deliverables** (nothing sent, posted or committed in this repository): `tmp/mesh-tester-ci/series-v3/`
— `0000-cover-letter.patch` (base-commit `08e90633377f…`), `0001…0005-*.patch`,
`msg-0001…0005.txt`; `bluez/0000…0004-*.patch` (`[PATCH BlueZ n/4]`, base-commit `ae69dcddd…`),
`bluez/msg-0001…0004.txt`; `alternative/0001-Bluetooth-MGMT-leave-room-for-cnt-events-in-the-mesh.patch`
(Option 1; base `f40c7a65bcb2` = v3 1/5's code, applies in place of 5/5); earlier exports kept
in `kernel-first-export-a4023e09b21d/`, `bluez-first-export-f620a4976/`,
`bluez-second-export-6640247e6/`. `duration-overflow-note-v3.md`, this file, raw logs in
`logs/phase5/` with `logs/phase5/SHA256SUMS`, copied with the series and the helpers to
`cache/mesh-tester-ci-phase5/` (§Archive). Branches: `cache/mesh-guest`
`mesh/phase5-series-v3-final-on-bluetooth-master-2026-10-03` (final),
`mesh/phase5-alternative-count-deadline-on-bluetooth-master-2026-10-03`, the `keep/phase5-*`
and `scratch/*` branches listed above; `cache/bluez-upstream`
`mesh-tester/phase5-lifecycle-tests-2026-10-03` (final) and `keep/mesh-tester-phase5-*`;
`cache/linux` `keep/full-bt-next-phase5-v3-final-*`.

**Decision points for the operator.** (1) Count/deadline: keep 5/5 (recommended), drop it, or
replace it by Option 1 (needs the Count-3 tester cases changed first). (2) 4/5: a fix for a
pre-existing defect beyond the review's scope — send with the series, separately, or hold. (3)
Order relative to the posted cleanup: the maintainers decide; refresh bluetooth,
bluetooth-next and patchwork at send time.

**The review's five findings.**

| finding | status | evidence |
|---|---|---|
| 1. initial enqueue failure | **closed for this series**; the cleanup itself is another author's pending patch (dependency stated, not included) | guest fault injection: series alone → rejected handle still listed (53/55); with the cleanup → absent, never started or completed, next requests progress (55/55); cover and 1/5 message |
| 2. Count vs deadline | **decided with evidence; operator to confirm** | receiver counts for both options (§B, §G2); Option 1 breaks 6 pre-existing mesh-tester cases; cover carries the interim scope sentence and no "ends after its requested count" |
| 3. active-cancel false positive | **closed** | "cancel held start": barrier answered while the start is held, `send_cancel` right after the released start, `dequeue ret=0`, completion before any tear-down, request 2 started once (§C1); queued-start dequeue with `ret=1` and `err=-125` (§C2) |
| 4. power-off argument | **closed** (argument replaced in the review task and annotated in phase 4; behaviour tested) | §D: accepted start after close fails with `-EINVAL` in 0.3 ms (trace), 10 power + 4 unregister cases pass, stale flag found and fixed (4/5); two pre-existing defects recorded |
| 5. duration note remainder 8 | **closed** | row 6357 and the review's paragraph in `duration-overflow-note-v3.md`; exhaustive check re-run and quoted |

Record errors (review item 6): Signed-off-by sentence (corrected 10-03), the queued-start
dequeue claim (corrected, now evidenced), "microseconds" (gone from the cover), the valgrind
baseline (now unpatched and patched with the same tester: 13/50 and 50/50, one identical
error).

## Open (not settled here)

1. **Operator decision — Count/deadline (§B).** Keep 5/5 (comment only, Option 2, recommended),
   drop it (nothing else changes), or replace it with Option 1
   (`series-v3/alternative/0001-…`; `series-backport-check-local.sh bluetooth/master 0001
   alternative/0001 0002 0003 0004` → `bluetooth/master APPLIES [tip 08e90633377f]`), which
   then needs the tester's Count-3 cases and timeouts changed first.
2. **Operator decision — 4/5 (power-off hand-over, §D0).** A new fix for a pre-existing defect the
   new tests found; independent of the rest; can be sent with the series, separately, or held.
3. **Dependency — the posted cleanup** ("Bluetooth: MGMT: fix mesh_tx leak on
   hci_cmd_sync_queue() failure", 2026-09-19, compile-tested by its author). Not in bluetooth,
   bluetooth-next or stable as of 10-04 17:48 (`stable-dep-check.sh`: no match on any of
   them). The series is tested only with a local equivalent (scratch branches, never for
   submission); the cover says the series assumes it. Refresh at send time; if it lands, name
   its hash as a prerequisite in 1/5's stable tag.
4. **Recorded, not fixed (pre-existing):** unregister with a backlog leaves the pending requests
   allocated and their socket pinned (§D4.1); a start that fails after `hci_add_adv_instance()`
   leaves the instance, which extended advertising re-enables at the next power on (§D4.2);
   `mgmt_cleanup()` walks other adapters' `mesh_pending` lists without their lock (§E);
   power-off through rfkill/`HCIDEVDOWN` not tested (§D0); the emulator never frees its hook
   list (`btdev_add_hook`, 120 B in mgmt-tester, phase-4 Open 6); the mgmt-tester case "LL
   Privacy - Start Discovery 1 (Disable RL)" failed in one of three runs on the series image
   and passed in the other two and on the unpatched kernel; the duration overflow (note, no
   patch).
5. **Not done:** no stable kernel built or run (text application only); no real controller or
   radio (emulator only); KCSAN sampling is not proof of absence; `BRIEF.md` is outside the
   writable area and was not edited (its lines 51-52 already carry the power-off correction);
   nothing sent, posted, or committed in this repository or its `cache/mesh-tester-ci`
   worktree.

## Archive

`sha256-phase5.sh` writes `logs/phase5/SHA256SUMS` (every raw log and build log of this
phase, the exported series, the images and configs, the helpers; this results file is not in
it because it quotes the list's own hash), then `copy-phase5-to-cache.sh` copies logs,
series, results, note and helpers to `cache/mesh-tester-ci-phase5/` and verifies the copy
against the list. Output below.

    sha256-phase5.sh      → 253 logs/phase5/SHA256SUMS
                            32eb206905130dc603534aef21d02dcbf80db0089961b40775fa70e719ec1fd4  logs/phase5/SHA256SUMS
    copy-phase5-to-cache.sh → source: all SHA256SUMS entries OK
                              copy: logs/phase5 and series-v3 entries OK
                              46M  cache/mesh-tester-ci-phase5

Verify later: `sha256sum -c logs/phase5/SHA256SUMS` from `tmp/mesh-tester-ci/` (or the
`logs/` and `series-v3/` entries from `cache/mesh-tester-ci-phase5/`). This file was copied
there again after this section was written.

Phase 5 ended 2026-10-04 18:21.


