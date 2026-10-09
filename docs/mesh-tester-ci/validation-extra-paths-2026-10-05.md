# Extra failure paths of the posted mesh_tx cleanup (exact patch) — 2026-10-05

Extends `validation-2026-10-05.md` (same control and exact-patch commits: bluetooth-next
`036d4119079a` and `19fdd346e00c` = `036d4119079a` + patchwork 14831271 by `git am`). That
validation covered only the -ENOMEM return of `hci_cmd_sync_queue()` (failslab). This file covers
the other returns (-ENETDOWN, -ENODEV), a kmemleak proof, a 4-CPU round and full-suite reruns.
QEMU guests only; nothing sent. Every claim is marked **quoted** (command and output shown),
**inferred** (derived from quoted material) or **not found**. Raw logs:
`tmp/mesh-tester-ci/logs-val2/` with `SHA256SUMS`. All paths below are relative to
`tmp/mesh-tester-ci/` unless they start with `cache/`.

## Setup (quoted)

- **Kernels under test unchanged.** The validation's images `bzImage-val-btnext-control`
  (`036d4119079a`) and `bzImage-val-btnext-hui` (`19fdd346e00c`) are used as they are for A and
  for the full mesh-tester of E; the branches `control/…` and `validate/…` were only read
  (`git rev-parse` → `036d4119079a757c…`, `19fdd346e00ce3f1…`).
- **New kernels** in a new worktree `cache/val2-guest` (`git -C cache/linux worktree add --detach
  cache/val2-guest 036d4119079a…`; the worktree inherited the sparse checkout of `cache/linux` and
  the first build stopped at `scripts/Makefile.warn: No such file or directory`; `git -C
  cache/val2-guest sparse-checkout disable`, per-worktree config, `cache/linux` itself still
  `core.sparseCheckout=true` in its own `config.worktree`). Script `val2-build-chain.sh`, log
  `logs-val2/val2-build-chain-try2.log` (12:58:08 to 13:09:44), toolchain `gcc (Ubuntu
  13.3.0-6ubuntu2~24.04.1) 13.3.0`, each `doc/tester.config` (of `cache/val2-bluez`, `8488ba994`) +
  a fragment, `make olddefconfig`, `make -j16`, rc 0 each:
  - baseline check: tester.config + `frag-fault.config` gives
    `d9d228fed92a835d8cc16361e57d228c437f358c381c88195dcecfaf891a6d59` and `baseline: identical
    to config-val-btnext-control` (quoted): the new worktree reproduces the validation's config.

  | image | commit | fragment | config sha256 | bzImage sha256 | guest `uname -r` |
  |---|---|---|---|---|---|
  | `bzImage-val2-kml-control` | `036d4119079a` | `frag-val2-kmemleak.config` | `27b1e8e0…f842` | `a498aaf5…ee4f` | `7.3.0-rc2-00486-g036d4119079a` |
  | `bzImage-val2-kml-hui` | `19fdd346e00c` (exact patch) | same | `27b1e8e0…f842` (identical) | `61c388d2…0252` | `7.3.0-rc2-00487-g19fdd346e00c` |
  | `bzImage-val2-diag-control` | `036d4119079a` + DIAGNOSTIC delay | same | `27b1e8e0…f842` | `774831d0…8004` | `…-g036d4119079a-dirty` |
  | `bzImage-val2-diag-hui` | `19fdd346e00c` + DIAGNOSTIC delay | same | `27b1e8e0…f842` | `81948d46…e9ed` | `…-g19fdd346e00c-dirty` |
  | `bzImage-val2-smp-control` | `036d4119079a` | `frag-val2-smp.config` | `59c014f5…63ea` | `bb7d289f…d426` | `7.3.0-rc2-00486-g036d4119079a`, `SMP` |
  | `bzImage-val2-smp-hui` | `19fdd346e00c` (exact patch) | same | `59c014f5…63ea` (identical) | `0dda5c17…3ec4` | `7.3.0-rc2-00487-g19fdd346e00c`, `SMP` |

  `diff config-val-btnext-control config-val2-kml-control` → only `CONFIG_DEBUG_KMEMLEAK=y`,
  `…_MEM_POOL_SIZE=16000`, `# …_DEFAULT_OFF is not set`, `# …_AUTO_SCAN is not set` (quoted). The
  SMP configs differ from the validation's by `CONFIG_SMP=y`, `CONFIG_NR_CPUS=4` and what those
  select. All six: `CONFIG_KASAN=y`, `CONFIG_PROVE_LOCKING=y`, failslab (grep in the build log).
  Control and patched of each pair: same config file, same base, differ only by the posted patch.
- **Diagnostic delay** (B only, never in a kernel whose result is the Tested-by):
  `val2-diag-mesh-send-delay.patch` (47 lines, sha256 `2f92ca6f…1bbb`), applied uncommitted (`git
  apply`; kernel version `-dirty`). It adds a module parameter `bluetooth.diag_mesh_send_delay_ms`
  and, inside `mesh_send()` right after `hci_dev_lock(hdev)`, `msleep()` for that long between
  two `bt_dev_info()` lines (`diag: mesh_send holds hdev->lock for %u ms` / `diag: mesh_send
  resumes, HCI_UNREGISTER %d HCI_RUNNING %d`). Default 0: no effect unless the tester sets it.
- **Tester**: new worktree `cache/val2-bluez` (`worktree add --detach … 8488ba994`, the
  validation's tester commit; `cache/bluez-upstream` is in use by another comparison and was not
  touched). Built by `val2-build-bluez.sh` (`./bootstrap-configure --disable-lsan`, ASAN), final
  build `cases-3` 13:47:23 to 13:47:27, `warnings/errors: 0`; binary sha256 `18a88b1a…be9`. The
  new cases are uncommitted; their full diff is `val2-mesh-tester-cases.diff` (929 lines, sha256
  `bfc6f5db…ed8`). Note: `libtoolize` in this worktree wrote `ltmain.sh` into the repository root
  (it takes the root's `install.sh` as an aux dir; git-ignored, `/.gitignore` lines 24-26; the
  root `install.sh` is unchanged, mtime 2026-09-22); the worktree got `/usr/share/libtool/
  build-aux/ltmain.sh` instead.
- **Runs**: `val2-runs.sh <set> [suffix]` through `val2-runs-chain.sh`; each VM:
  `cache/val2-bluez/tools/test-runner [-q qemu-smp.sh] -k bzImage-<img> -- val2-guest.sh
  <alias>`; `val2-guest.sh` (runs inside the guest) picks the tester command by alias (test-runner
  splits arguments on spaces), raises the console log level to 8 for targeted aliases, clears
  kmemleak before the tester and, after it, scans twice and prints `/sys/kernel/debug/kmemleak`.
  Summaries: `val2-summary.py`, `val2-table.py` (`logs-val2/tables-all.txt`),
  `val2-fp-groups.py`, `splat-check.sh` via `val2-splats.sh` (`logs-val2/splat-summary.txt`).
  The final results are the runs with suffix `-t3` (tester `cases-3`); earlier runs are kept and
  are marked superseded where they differ.

## The new tester cases (all in `val2-mesh-tester-cases.diff`)

- `Mesh - Send - poweroff-cycle` (legacy) and `… - Ext Adv`: the six assertions (a)-(f) of the
  validation's failed-start case, with the failing sends made **with the controller powered off
  instead of fail-nth** (no fault injection at all). Prelude, all recorded: Set Mesh Receiver
  (enable) while powered; then disable it again (this variant); Set Powered off (settings
  recorded); wait until `HCIGETDEVINFO` shows `HCI_RUNNING` clear; Set Mesh Receiver while
  powered off; Set LE on while powered off; then packet 0 (Mesh Send while off) → Read Mesh
  Features while off → Set Powered on → Read Mesh Features → packets 1-3 back to back (d) →
  Set Powered off (wait for `HCI_RUNNING` clear) → packet 0 five times (max_handles + 2), a Read
  Mesh Features after each (e) → Set Powered on → packet 4 (f). A send while powered off must be
  answered Failed and consume a handle, otherwise the case fails as "path not reached".
- `Mesh - Send - poweroff-rx-cycle` and `… - Ext Adv`: the same with the mesh receiver kept on.
- `Mesh - Send - poweroff-once` and `… - Ext Adv`: power off, one Mesh Send, one Read Mesh
  Features, verdict on (a); the controller is then removed by the teardown (for kmemleak).
- `Mesh - Send - unregister-in-send`: diagnostic kernel only (otherwise `Not Run`): sets the delay
  to 1500 ms, forks a child that closes every inherited descriptor, opens its own management
  socket and sends one Mesh Send; 150 ms later the parent closes the vhci device (controller
  removal); the child's exit status is the answer to its Mesh Send.

## A — powered off (-ENETDOWN)

### A0 code (quoted, `git show 036d4119079a:<file>` via `sm-showlines.sh`)

- `mesh_send()` checks only `lmp_le_capable`, `HCI_MESH_EXPERIMENTAL` (mgmt.c:2503-2506) and
  `HCI_LE_ENABLED` (2507-2509), the length (2511-2518) and the handle budget (2525-2531); then
  `mgmt_mesh_add()` (2534) and `hci_cmd_sync_queue()` (2539). Its handler entry has no flag
  beyond `HCI_MGMT_VAR_LEN` (9746-9747). No power check anywhere on the path.
- `hci_cmd_sync_queue()`: `if (!test_bit(HCI_RUNNING, &hdev->flags)) return -ENETDOWN;`
  (hci_sync.c:757-758). `HCI_RUNNING` is cleared in `hci_dev_drop_last_cmd_req_and_close()`
  (5401), called from `hci_dev_close_sync()` (5663), and set again only in `hci_dev_open_sync()`
  (5459).
- `set_le()` while not powered only toggles `HCI_LE_ENABLED` (2602-2606); `set_mgmt_mesh_func()`
  sets `HCI_MESH_EXPERIMENTAL` with no power check (4860-4862). Nothing in the close path or in
  `__mgmt_power_off()` (9835-9868) touches `mesh_pending`; the only frees of an entry are
  `mesh_send_complete()` → `mgmt_mesh_remove()` (1084-1094) and the patched error branch.
- The reply to Set Powered off is sent by `__mgmt_power_off()` (`mgmt_pending_foreach(
  MGMT_OP_SET_POWERED, …settings_rsp…)`, mgmt.c:9840), called at hci_sync.c:5621, i.e. **before**
  `HCI_RUNNING` is cleared at 5663 → 5401.
- **Inferred:** with LE enabled and the experimental feature set, a Mesh Send while powered off
  reaches `hci_cmd_sync_queue()` and fails with -ENETDOWN after `mgmt_mesh_add()`; the unpatched
  error branch frees the entry only `if (sending)`, and `HCI_MESH_SENDING` is not set while
  powered off, so the entry stays on `mesh_pending`.

### A1 answers to "can it be set up" (quoted, every run identical; e.g. `run-val2-A-control-1-t3.log`)

- LE is kept across Set Powered off: `Set Powered off at +37 ms: Success (0x00), settings
  0x00000280 (LE on, powered no)` (0x200 = LE).
- Set LE while powered off: `Set LE on while powered off: Success (0x00), settings 0x00000280`.
- Set Mesh Receiver while powered: `Success (0x00)`; **while powered off: `Failed (0x03)`** (its
  own `hci_cmd_sync_queue()` fails; inferred from set_mesh() 2286-2295). The receiver is not
  needed for the leak: `mesh_send()` does not test `HCI_MESH`.
- Read Mesh Features works while powered off (it is answered; the reads 1 below are made while
  off: `Read Mesh Features 1: 1 handles pending` on control).
- `HCI_RUNNING clear at +40 ms (after 0 polls of 10 ms following the Set Powered off reply)` on
  one CPU.

### A2 runs (quoted)

Command per run: `test-runner -k bzImage-val-btnext-{control,hui} -- val2-guest.sh @off-cycle`
(and `@off-rx`); set `A-t3`, 13:50:19 to 13:52:17 (`logs-val2/runs-A-t3.log`); five runs per
kernel and variant; each run holds the legacy and the Ext Adv case. `val2-fp-groups.py
logs-val2/tables-all.txt`:

| | control `036d4119079a` | exact patch `19fdd346e00c` |
|---|---|---|
| poweroff-cycle, 5 runs | fingerprint `ac7f838ba741` ×5; legacy and Ext Adv `F7 P F1 F2 F2 F1` | fingerprint `297f0cdd47f5` ×5; legacy and Ext Adv `P P P P P P` |
| kernel lines per run | `Bluetooth: hci0: Send Mesh Failed -100` ×8 (1 + 3 per case; the 2 Busy answers never reach the queue) | `… Send Mesh Failed -100` ×12 (1 + 5 per case) |
| case verdicts | Failed / Failed ×5 | Passed / Passed ×5 |

(-100 = -ENETDOWN.) Control, legacy, quoted from `run-val2-A-control-1-t3.log`:
`Powered off fails the start: packet 0 was given handle 1 and answered Failed, packet 1
(powered on) got handle 2`; `Handle 1 was pending after its Mesh Send was answered Failed`;
`Handle 1 was still pending after power on`; `Mesh Send of packet 3 answered Busy with 2 of 3
handles in use by accepted requests`; `Handle 1 completed although its Mesh Send was answered
Failed`; `packet 1: handle 2, 1 loads, 2 starts, 1 completions` (the accepted packet 1 put on air
twice); reads while powered off after the repeated failures `1, 2, 3, 3, 3` handles pending;
`3 failed and 2 answered Busy`; `Mesh Send of packet 4 answered Busy: the failed requests used up
the handles`. Patched: `3 of 3 capacity sends accepted, then 5 failed and 0 answered Busy`,
every read `0 handles pending`, `packet 4: handle 10, 1 loads, 1 starts, 1 completions` (10 = 4 +
5 failed + 1: every failing send consumed a handle, i.e. reached `hci_cmd_sync_queue()`).

**Receiver kept on** (`poweroff-rx-cycle`, 5 runs each, fingerprints `93d1dbc2a275` ×5 control,
`94e2d664bf7c` ×5 patched): Ext Adv as above (control `F7 P F1 F2 F2 F1`, patched all PASS).
Legacy: control `F7 F1 F1 F3 F2 F1`, patched `P P P F3 P F1`. The legacy (d)/(f) failures on
**both** kernels are not the patch: after power on with the receiver on, every legacy start fails
at LE Set Random Address — `hci_cc_le_set_random_addr:1414: hci0: status 0x0c` / `Bluetooth: hci0:
Opcode 0x2005 failed: -16` (`run-val2-try-hui.log` 4376-4380, quoted), i.e. the emulated 4.x
controller answers Command Disallowed while passive scanning is on, and the request is completed
without advertising enable. On control this exposes one more effect of the leak: (b) fails —
`Packet 0 loaded into the mesh set at +404 ms` (`run-val2-A-control-rx-1-t3.log:4489`): when a
start fails, `mesh_next()` takes the oldest pending entry, which is the request answered Failed
(inferred from mgmt.c:1113-1121 and 2314-2319), and loads its data into the controller. Never on
the patched kernel.

Earlier tester versions: set `A` (13:12:03 to 13:14:06, tester cases-2, no HCI_RUNNING wait) gave
the same fingerprints on all 20 logs (quoted, `tables-all.txt`); `try`/`try2` the same.

**Verdict A:** a Mesh Send while powered off, without any fault injection, reaches the error
branch with -ENETDOWN on both kernels (quoted). On the unpatched kernel the request stays pending
across power on, is completed in place of the next accepted request, makes that request go on air
twice, and three of them make every later Mesh Send answer Busy (quoted). With the exact patch
none of this happens, 10/10 cases per variant (quoted).

## B — controller being removed (-ENODEV)

### B0 reachability from the code (quoted lines, inferred conclusion)

- `hci_mgmt_cmd()` looks the index up with `hci_dev_get(index)` (hci_sock.c:1692) and checks
  `HCI_SETUP`, `HCI_CONFIG`, `HCI_USER_CHANNEL`, `HCI_UNCONFIGURED` (1699-1712), **not**
  `HCI_UNREGISTER`; the lookup takes no lock that excludes unregistration.
- `hci_unregister_dev()` sets `HCI_UNREGISTER` under `unregister_lock` (hci_core.c:2670-2672) and
  only then removes the device from `hci_dev_list` (2674-2676); `HCI_RUNNING` is cleared later, in
  `hci_dev_do_close()` (2694) → `hci_dev_close_sync()`, after it has taken `hci_dev_lock()`
  (hci_sync.c:5613) and released it, at 5663 → 5401.
- `hci_cmd_sync_submit()` returns -ENODEV when `HCI_UNREGISTER` is set (hci_sync.c:720-723).
- **Inferred:** -ENODEV is reachable when a Mesh Send has looked the device up before 2675 and
  reaches `hci_cmd_sync_queue()` after 2671 but before 5401. Since `mesh_send()` holds
  `hci_dev_lock()` from 2520 to 2559 and the close path needs that lock before clearing
  `HCI_RUNNING`, a `mesh_send()` that is inside the lock when unregistration starts always sees
  `HCI_UNREGISTER` set and `HCI_RUNNING` still set. Without a delay the window between the lookup
  and the queue call is a few instructions, so on the exact kernels it is **not deterministically
  hittable**; no attempt to race it on the exact kernels was made.

### B1 diagnostic runs (quoted; DIAGNOSTIC kernels, not a Tested-by result)

Command: `test-runner -k bzImage-val2-diag-{control,hui} -- val2-guest.sh @unreg`, set `B-t3`
13:47:44 to 13:49:10, three runs each (`logs-val2/runs-B-t3.log`). Every run, both kernels:

    Child 45 sends a Mesh Send (kernel delay 1500 ms); the controller is removed in 150 ms
    Closing the vhci device (controller removal) at +165 ms
    Bluetooth: hci0: diag: mesh_send holds hdev->lock for 1500 ms
    Bluetooth: hci0: diag: mesh_send resumes, HCI_UNREGISTER 1 HCI_RUNNING 1
    Bluetooth: hci0: Send Mesh Failed -19
    vhci device closed at +1555 ms
    Child 45 done at +1559 ms, exit status 0x03
    Removal during a Mesh Send: the send was answered 0x03 (Failed)

(-19 = -ENODEV; lines from `run-val2-B-diag-control-1-t3.log`.) kmemleak after the run
(controller gone): control **1 object each run** —

    unreferenced object 0xffff888003d38700 (size 96):
      comm "mesh-tester", pid 45, jiffies 4294893368
      backtrace (crc f70a6628):
        __kmalloc_cache_noprof+0x2d6/0x4b0
        mgmt_mesh_add+0x4f/0x300
        mesh_send+0x313/0x790
        hci_sock_sendmsg+0x119d/0x2260
        sock_write_iter+0x43e/0x4d0
        vfs_write+0xbd0/0xff0
        ksys_write+0x17a/0x1c0

(`run-val2-B-diag-control-1-t3.log:2246-2258`, hex dump omitted; pid 45 is the child.) Unlike the
other paths, the child's socket was not reported (not found why). — patched: `kmemleak: 0 unreferenced objects` in all three runs (summaries quoted from
`runs-B-t3.log`). The exact kernels: `Needs the diagnostic kernel (…diag_mesh_send_delay_ms): not
run`, `Total: 1, Passed: 0 (0.0%), Failed: 0, Not Run: 1` (quoted).

Superseded try (set `B`, 13:14:06 to 13:15:25): the child inherited the vhci descriptor, so the
device was removed only when the child exited: `diag: mesh_send resumes, HCI_UNREGISTER 0
HCI_RUNNING 1`, send answered `0x00 (Success)` on both kernels (quoted) — path not reached; fixed
by closing inherited descriptors in the child.

**Verdict B:** reachable in principle on the exact kernels (inferred from the code), not hittable
on demand without an injected delay; with the delay (diagnostic kernels only) the -ENODEV branch
is reached 3/3 on each kernel and the unpatched kernel leaks exactly the request (96-byte object
allocated in `mgmt_mesh_add()`), the patched kernel leaks nothing (quoted).

## C — kmemleak (quoted)

Images `bzImage-val2-kml-{control,hui}` (validation config + kmemleak only, same commit, same
compiler). Set `C-t3`, 13:52:17 to 13:54:18 (`logs-val2/runs-C-t3.log`), commands
`… -- val2-guest.sh @off-once` (×2), `@failed-start`, `@off-cycle`. kmemleak is read after the
tester exits, i.e. after every controller of the run was removed (two scans; `val2-summary.py`
groups the objects by size, task and first frames):

| run | control | exact patch |
|---|---|---|
| poweroff-once ×2 (A path, 1 failed send per case, 2 cases) | `Send Mesh Failed -100` ×2; **4 objects**: `x2 size 96 … mgmt_mesh_add < mesh_send < hci_sock_sendmsg < sock_write_iter` and `x2 size 2048 … sk_alloc < bt_sock_alloc < hci_sock_create` (both runs) | `Send Mesh Failed -100` ×2; **0 objects** (both runs) |
| failed start (ENOMEM path, fail-nth) | `Send Mesh Failed -12` ×10; `fail-nth 11 fails the start`; **7 objects**: `x5 size 96 … mgmt_mesh_add …`, `x2 size 2048 … sk_alloc …` | `Send Mesh Failed -12` ×14; all six assertions PASS both variants; **0 objects** |
| poweroff-cycle (A path) | **7 objects**: `x5 size 96 … mgmt_mesh_add …`, `x2 size 2048 … sk_alloc …` | **0 objects** |
| unregister-in-send (B path, diagnostic + kmemleak) | 1 object, `size 96 … mgmt_mesh_add …` ×3 runs | 0 objects ×3 runs |

- The 96-byte objects are the `struct mgmt_mesh_tx` entries (inferred: allocated by
  `mgmt_mesh_add()`, mgmt_util.c:413). The 2048-byte objects are the tester's management sockets:
  each leaked entry holds `sock_hold(sk)` (mgmt_util.c:426) and only `mgmt_mesh_remove()` drops it
  (436), so the socket outlives its close (inferred). poweroff-cycle and failed start each end with
  3 failed requests pending per case (`Read Mesh Features 8: 3 handles pending`, quoted), 6 in
  all; kmemleak reports 5 (inferred: kmemleak is conservative, one object still looked referenced).
- The failed-start case needed the console log level left at its default: with level 8, fail-nth
  was consumed by the console driver (`should_failslab … alloc_buf … put_chars …
  hvc_console_print`, `run-val2-C-kml-hui-failed-start.log:2119-2132`) and the case reported `No
  fault point up to 16 …` on both kernels (superseded set `C`, 13:15:25 to 13:17:32).
- Full suites on the kmemleak kernels (E) also show `mgmt_mesh_add` objects on the **patched**
  kernel: `x23 size 96 … mgmt_mesh_add …` (control `x48`). These come from cases outside this
  patch's path — requests still pending when the controller is powered off or removed (the
  phase-5 lifecycle cases), which nothing frees (inferred from A0: no `mesh_pending` cleanup on
  power off or unregister). Every targeted run of the three error paths shows 0 such objects on
  the patched kernel (quoted above).

**Verdict C:** kmemleak reports the leaked request (and the socket it pins) on the unpatched
kernel for all three error returns (-ENETDOWN, -ENOMEM, -ENODEV), and nothing on the patched
kernel (quoted).

## D — 4-CPU guest (quoted)

Images `bzImage-val2-smp-{control,hui}`, `test-runner -q qemu-smp.sh -k … -- val2-guest.sh
@off-cycle` / `@off-rx`, guest `CPUs online 4` (quoted). Set `D-t3`, 13:49:10 to 13:50:04
(`logs-val2/runs-D-t3.log`; the step log's "13:49:55" is wrong), two runs per kernel and variant:
fingerprints **identical to the uniprocessor runs** — control `ac7f838ba741` ×2 and
`93d1dbc2a275` ×2, patched `297f0cdd47f5` ×2 and `94e2d664bf7c` ×2; `Send Mesh Failed -100` ×8
(control) / ×12 (patched). `HCI_RUNNING clear at …` after 0 or 1 polls of 10 ms.

Found on 4 CPUs (superseded set `D`, 13:17:32 to 13:18:16, tester without the HCI_RUNNING wait):
a Mesh Send issued immediately after the Set Powered off reply was **accepted** —
`Sending Mesh Send of packet 0 while powered off at +975 ms` → `Mesh Send of packet 0 at +979
ms: Success (0x00), handle 5`, then `Bluetooth: hci0: Opcode 0x2008 failed: -22` and `Mesh Packet
Complete handle 5 at +1000 ms` (`run-val2-D-smp-hui-1.log` 4956-5042, quoted). Explained by A0
(inferred): the reply is sent at hci_sync.c:5621, `HCI_RUNNING` is cleared at 5663 → 5401. That
request was not leaked (it completed); it is a property of power-off ordering, independent of the
patch (same on control). The final tester waits for `HCI_RUNNING` clear before its sends.

Splats over all 124 val2 logs (`val2-splats.sh`): `other report headers: none` (no BUG, WARNING,
KASAN, KCSAN, lockdep, hung task, sleep in atomic, Oops); only kmemleak reports (28 logs, C/E)
and mgmt-tester's own `command 0x0405 tx timeout` (and once `0x1405`) in mgmt-tester logs, on
control and patched alike (quoted, `logs-val2/splat-summary.txt`).

**Verdict D:** on 4 CPUs the behaviour of both kernels is identical to one CPU; no KASAN, lockdep
or WARN on either kernel (quoted).

## E — full suites on the new kernels (quoted)

Set `E-t3`, 13:54:18 to 14:07:58 (`logs-val2/runs-E-t3.log`), tester `cases-3` (64 mesh cases:
the validation's 57 + 7 new), mgmt-tester 503; `python3 compare-verdicts.py <control> <patched>`:

| kernel pair | mesh-tester control / patched | differing cases | mgmt-tester control / patched | differing |
|---|---|---|---|---|
| exact (`val-btnext-*`) | `Total: 64, Passed: 18, Failed: 45, Not Run: 1` / `Passed: 26, Failed: 37, Not Run: 1` | 8: failed start ×2, poweroff-cycle ×2, poweroff-once ×2, poweroff-rx-cycle Ext Adv, rejected start — all Failed → Passed | (validation: 502/503 both, identical) | — |
| kmemleak | `Passed: 18 … Not Run: 1` / `Passed: 26 … Not Run: 1` | the same 8, Failed → Passed | `Passed: 502, Failed: 1` / `Passed: 501, Failed: 2` | 1: `LL Privacy - Remove Device 3 (Disable RL)` Passed → Failed |
| diagnostic | `Passed: 19, Failed: 45` / `Passed: 27, Failed: 37` (unregister-in-send Passed on both) | the same 8 | `Passed: 502, Failed: 1` / `Passed: 502, Failed: 1` | 0 |
| SMP, 4 CPUs | `Passed: 18 … Not Run: 1` / `Passed: 24 … Not Run: 1` | 8: the same 7 minus `failed start` (legacy), plus `Send unregister - held tear-down - Ext` Passed → Failed | `Passed: 493, Failed: 9, Timed out: 1` both | 0 |

- The kmemleak mgmt-tester difference does not repeat: rerun E2 (14:08:45 to 14:11:06) gave
  patched `Passed: 500, Failed: 3` with two **other** cases (`LL Privacy - Add Device 3 (AL is
  full)`: `Incorrect Device Added event parameters`; `Pairing Acceptor - SMP over BR/EDR 2`: `test
  timed out`) and control `Passed: 502, Failed: 1` (quoted). mgmt-tester never sends Mesh Send
  (`grep -c -E "MGMT_OP_MESH_SEND\b|MESH_SEND" tools/mgmt-tester.c` → `0`), so the patched line
  cannot run in it (inferred: timing on the slower kmemleak kernel).
- SMP: the legacy `failed start` failed on the patched kernel with `fail-nth 6 no longer fails
  the start` (`run-val2-E-smp-hui-mesh-full-t3.log:19263`): the fail-nth fault point moved during
  the run (tester method, not a kernel result; its Ext Adv variant passed all six assertions on the
  same run). `Send unregister - held tear-down - Ext` is a series-v3 lifecycle case expected to fail
  without the series (validation §A5); it passed once on control under SMP.
- Superseded: set `E` (13:18:16 to 13:31:37) ran tester `cases-2`; kept, not used.

**Verdict E:** apart from the new error-path cases (Failed → Passed) the suites give the same
verdicts on control and patched, except single non-mesh cases that change from run to run on the
kmemleak kernel and two tester-timing effects on 4 CPUs (quoted, inferred as stated).

## Facts for a maintainer (no process, only what was tested and what happened)

1. Base bluetooth-next `036d4119079a`, the posted patch applied with `git am` (`19fdd346e00c`),
   doc/tester.config (+ fault injection), KASAN and lockdep on; emulated controllers (vhci) in
   qemu; legacy and extended advertising.
2. **No fault injection needed:** with the adapter powered off and LE enabled, MGMT Mesh Send
   reaches `hci_cmd_sync_queue()`, which fails with -ENETDOWN (`Send Mesh Failed -100`); the
   command is answered Failed. Set LE and the mesh experimental feature work while powered off;
   Read Mesh Features answers while powered off.
3. Without the patch the failed request stays pending: Read Mesh Features lists it while off and
   after power on; after power on it is completed (Mesh Packet Complete for a handle that was
   answered Failed) in place of the next accepted request, which is then transmitted twice; with
   the receiver on (legacy advertising) its data is loaded into the controller; three such
   failures make every further Mesh Send answer Busy until the controller is removed.
4. With the patch none of the above in 10 of 10 runs per case (5 runs × legacy/extended), also on
   a 4-CPU guest.
5. kmemleak (same base and config plus CONFIG_DEBUG_KMEMLEAK): without the patch the request
   (96-byte object from `mgmt_mesh_add()`) and the management socket it holds are reported after
   the controller is removed, for -ENETDOWN (powered off), -ENOMEM (failslab) and -ENODEV; with the
   patch nothing from these paths.
6. -ENODEV was reached only with a test-only delay inside `mesh_send()` (under `hci_dev_lock()`)
   while the controller was removed: `Send Mesh Failed -19`, answered Failed; unpatched leaks the
   request, patched does not. Without such a delay the window is too narrow to hit on demand.
7. Full mgmt-tester and mesh-tester: no verdict change attributable to the patch; no KASAN,
   lockdep or WARNING on either kernel.
8. Seen in passing, not related to the patch: (a) the Set Powered off reply is sent before
   `HCI_RUNNING` is cleared, so on SMP a Mesh Send sent right after it is still accepted (and then
   fails at the controller and completes); (b) with legacy advertising and the mesh receiver on,
   LE Set Random Address is answered Command Disallowed after a power cycle and every Mesh Send
   completes without being advertised; (c) requests still pending when the controller is powered
   off or removed are never freed (kmemleak, patched kernel too).

## Could not be tested, with the reason

- -ENODEV on the exact kernels: the race window (device lookup before `hci_unregister_dev()`
  removes it from the list, queue call after it sets `HCI_UNREGISTER`) is a few instructions wide
  without an injected delay; no deterministic trigger exists without changing the kernel, and a
  changed kernel is not the exact patch. Covered only by the diagnostic builds (B1).
- Real hardware controllers: emulator only (vhci); the legacy Command Disallowed observation is
  the emulator's answer and was not checked against a real 4.x controller.
- kmemleak on the 4-CPU kernels: not built (D used the usual tester config + SMP; C used one CPU).
- The validation's failslab case on 4 CPUs is not reliable as a method (fault point moves, E).

## Archive

See the end of the step log for the `SHA256SUMS` line. Helpers written for this step (all in
`tmp/mesh-tester-ci/`): `val2-step.sh`, `val2-save-diag.sh`, `val2-build-chain.sh`,
`val2-build-bluez.sh`, `val2-guest.sh`, `val2-runs.sh`, `val2-runs-chain.sh`, `val2-summary.py`,
`val2-table.py`, `val2-fp-groups.py`, `val2-tables-all.sh`, `val2-splats.sh`, `val2-sha256.sh`;
fragments `frag-val2-kmemleak.config`, `frag-val2-smp.config`. Worktrees created:
`cache/val2-guest` (detached, left at `19fdd346e00c`, clean) and `cache/val2-bluez` (detached at
`8488ba994`, the cases uncommitted, diff saved). No commits anywhere; nothing sent.

## Step log (appended at the start and end of every step)

- 2026-10-05 12:52:47 S0 start: code reading (mesh_send, hci_cmd_sync_queue, power off, unregister); own worktrees cache/val2-guest and cache/val2-bluez
- 2026-10-05 12:56:26 S0 end: code read (quoted in section A0/B0); S1 start: six guest kernels in cache/val2-guest (val2-build-chain.sh, background): kml-control, kml-hui, diag-hui, diag-control, smp-control, smp-hui; diagnostic delay saved as val2-diag-mesh-send-delay.patch
- 2026-10-05 12:58:11 S1 try1 failed (12:56:25 to 12:56:27, log val2-build-chain.log): the new worktree inherited the sparse checkout of cache/linux (scripts/Makefile.warn missing); git sparse-checkout disable in cache/val2-guest only (per-worktree config); S1 try2 started (val2-build-chain-try2.log)
- 2026-10-05 13:05:10 S2 start: BlueZ tester worktree cache/val2-bluez (8488ba994) configure+build; try1 12:58:33 failed (libtoolize wrote ltmain.sh to the repository root, a known git-ignored artifact, /.gitignore line 24-26; configure: required file ./ltmain.sh not found); the system ltmain.sh copied into the worktree; try2 started; new cases being written
- 2026-10-05 13:09:26 S2 end: BlueZ build cases-1 13:07:51 to 13:08:18, 0 warnings (val2-mesh-tester-cases.diff 791 lines); S1 progress: baseline config identical to config-val-btnext-control, kml-control/kml-hui/diag-hui/diag-control built; S3 start: machinery try (val2-runs.sh try)
- 2026-10-05 13:12:05 S1 end: six kernels 12:58:12 to 13:09:44, rc 0 each (val2-build-chain-try2.log); S3 end: try 13:09:28 to 13:09:42 and try2 13:11:20 to 13:11:44 (legacy with the receiver kept on: LE Set Random Address answered Command Disallowed after power on on both kernels, so a receiver-off variant poweroff-cycle and a receiver-on variant poweroff-rx-cycle; tester build cases-2 0 warnings); S4 start: sets A, B, C, D, E in the background (runs-chain-ABCDE.log), expected about 25 min
- 2026-10-05 13:16:14 S4 progress: set A 13:12:03 to 13:14:06 done (stable fingerprints, 5/5 per kernel and variant); set B try1 13:14:06 to 13:15:25 inconclusive: the forked child inherited the vhci descriptor, so the controller was removed only when the child exited (diag line: HCI_UNREGISTER 0 HCI_RUNNING 1, send answered Success on both diagnostic kernels); child now closes inherited descriptors, delay 1500 ms; rebuild and B rerun after the chain
- 2026-10-05 13:47:43 S4 end (chain 13:12:03 to 13:31:37; A, C, D, E with tester cases-2): C failed-start on the kmemleak kernels never reached the fault point (fail-nth consumed by the console driver, printk 8 raised by the guest script: alias fixed); D on 4 CPUs: a Mesh Send issued right after the Set Powered off reply was accepted (HCI_RUNNING still set), tester now waits for HCI_RUNNING clear (HCIGETDEVINFO); E ran with the old binary. Tester cases-3 built 13:47:23 to 13:47:27, 0 warnings. S5 start: final runs with suffix -t3 (B, D first)
- 2026-10-05 13:50:20 S5 progress: B-t3 13:47:44 to 13:49:10 (-ENODEV reached 3/3 per diagnostic kernel; kmemleak 1 object control, 0 patched), D-t3 13:49:10 to 13:49:55 (4 CPUs, same fingerprints as uniprocessor); A, C, E with -t3 started in the background (runs-chain-t3-ACE.log), expected about 25 min
- 2026-10-05 14:08:47 S5 end: A-t3, C-t3, E-t3 13:50:20 to 14:07:58 (runs-chain-t3-ACE.log); E differences: kml-hui mgmt-tester LL Privacy - Remove Device 3 (Disable RL) failed on the patched kmemleak kernel only; S6 start: E2 repeat of mgmt-tester on both kmemleak kernels
- 2026-10-05 14:11:47 S6 end: E2 14:08:45 to 14:11:06: kml-hui mgmt-tester 500/503 with two other cases failing this time (LL Privacy - Add Device 3, Pairing Acceptor - SMP over BR/EDR 2 timed out), kml-control 502/503; S7 start: write-up and SHA256SUMS
- 2026-10-05 14:14:25 S7 end: sections A-E, maintainer facts, untested list written; val2-sha256.sh: 207 entries in logs-val2/SHA256SUMS, all entries OK, list hash df11dbe6a326eb7d0c68759e019f56817e5a5aee0c38de29ad5eb7b0c2689a0d (this results file is not in it); verify from /root/exp/qca9377-bt-hang with sha256sum -c tmp/mesh-tester-ci/logs-val2/SHA256SUMS
