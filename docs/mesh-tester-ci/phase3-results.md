# `TestRunner_mesh-tester` — Phase 3 results (two-patch series, ext-adv, tests)

Started 2026-10-02. Follows `phase2-results.md` and `PHASE3-TASK.md`. Updated after every
step. Everything runs inside qemu on freshly built guest kernels; the host Bluetooth stack
is not touched. Writes only under `cache/` (worktrees, build products) and
`tmp/mesh-tester-ci/`. Every claim is marked **quoted** (command and output shown),
**inferred** (derived from quoted material) or **not found**.

## Step 0 — trees and preservation (quoted)

- `git -C cache/linux fetch bluetooth` →
  `c9c15d4d8956..86ef0f58bdec  master -> bluetooth/master`, new tag `for-net-2026-09-28`.
  `bluetooth/master` tip: `86ef0f58bdec Bluetooth: MGMT: Fix status of pending commands
  flushed on power off` (the subject of the operator's held patch `b00c0e4ee93d` — it is
  upstream in the fixes tree now; not pursued here).
- `git merge-base bluetooth/master 671d566d3c3b` = `c9c15d4d8956`. The fixes tree and the
  phase-2 base differ in the five files the series could touch
  (`diff --stat`: hci_core.h 50, hci_core.c 97, hci_event.c 68, hci_sync.c 83, mgmt.c 16
  lines), but **the mesh path is identical** on both: `mesh_send_done_sync()` and
  `send_cancel()` printed from `bluetooth/master:net/bluetooth/mgmt.c` (lines 1093-1106,
  2416-2449) are byte-for-byte the text quoted in phase 1 §5 from `bluetooth-next`. The
  fixes-tree-only changes in `mgmt.c`/`hci_sync.c` since the merge base
  (`git diff c9c15d4d8956 bluetooth/master -- net/bluetooth/mgmt.c net/bluetooth/hci_sync.c`)
  are `cmd_complete_rsp()` (one line), `hci_cmd_sync_work()/hci_cmd_sync_clear()`,
  `hci_stop_discovery_sync()` and `hci_acl_create_conn_sync()` — none on the advertising
  or mesh paths.
- Preserved before anything was reset (both commits were on no branch, detached only):
  `keep/full-bt-next-phase2-mesh-patch-on-held-patch-8804074f2980` (the `cache/full-bt-next`
  HEAD: phase-2 patch on top of the held patch on top of `671d566d3c3b`) and
  `keep/phase2-mesh-patch-on-bluetooth-next-6cc1a7a507a9` (the phase-2 commit).
- New branch `mesh/phase3-series-on-bluetooth-master-2026-10-02` from `bluetooth/master`,
  checked out in `cache/mesh-guest` (the built guest tree; `.config` kept).
- Emulator facts for the tests: `emulator/btdev.c:81 #define MAX_EXT_ADV_SETS 3` → on
  `HCIEMU_TYPE_BREDRLE50` the kernel's `le_num_of_adv_sets` is 3 and the mesh instance is
  **4**; on `HCIEMU_TYPE_BREDRLE` (no ext adv) it is `HCI_MAX_ADV_INSTANCES` = 5
  (`hci_core.c:2467`) and the mesh instance is **6**. `btdev.c:5695-5697` arms a timer of
  `duration * 10` ms per set and `adv_set_terminate()` (5584-5603) sends
  `LE Advertising Set Terminated` with `BT_HCI_ERR_ADV_TIMEOUT` — so the emulator does
  honour the ext-adv duration (relevant to the overflow note, §F).

## Design (inferred from the quoted kernel code; see PHASE3-TASK.md items 1-2)

**Patch 1/2** — `mesh_send_done_sync()` tears the mesh instance down through
`hci_remove_advertising_sync(hdev, NULL, instance, true)` followed by the existing
`list_empty() → hci_disable_advertising_sync()` — i.e. exactly what
`remove_advertising_sync()` (`mgmt.c:9538-9552`) does for MGMT Remove Advertising:

- legacy: `hci_remove_adv_sync()` drops the instance under `hdev->lock`, the
  `cur_adv_instance == instance` branch cancels the 1000-s `adv_instance_expire` timer
  (`cancel_adv_timeout`), and if another instance is current/next it is rescheduled
  (`hci_schedule_adv_instance_sync(next)`); then the list is empty only when no other
  advertiser exists → `LE Set Advertising Enable (0x00)`;
- extended: `hci_remove_ext_adv_instance_sync()` disables **that set only**
  (`LE Set Extended Advertising Enable {0x00, 1 set, handle}`) and sends
  `LE Remove Advertising Set`; `hci_cc_le_remove_adv_set()` removes the instance under the
  lock. Other sets keep running; the global disable follows only when the list is empty.
- The event: every removal path ends in `mgmt_advertising_removed()`, and the mesh
  instance is freed before the call, so `adv->mesh` cannot be consulted there. The
  instance number can: the mesh instance is `le_num_of_adv_sets + 1` by construction,
  `add_advertising()` rejects `instance > le_num_of_adv_sets`, and `read_adv_features()`
  already hides it ("Only instances 1-le_num_of_adv_sets are externally visible",
  `mgmt.c:8837`). So `mgmt_advertising_removed()` returns early for
  `instance > hdev->le_num_of_adv_sets` — one hunk, covering the ext-adv Command Complete,
  the legacy removal, the clear-all paths (`hci_clear_adv_sync`, power off, Set LE off)
  and `LE Advertising Set Terminated`. Userspace never received Advertising Added for it.

**Patch 2/2** — complete the `mesh_tx` whose `->instance` is the mesh instance (set only in
`mesh_send_sync()` when the add succeeded, `mgmt.c:2372-2373`, present since
`b338d91703fa`), with the comment from task item 6.

Checked against the quoted code (inferred): legacy, mesh alone → `0x00` at +75 ms, timer
cancelled; legacy with an ordinary instance rotating → the mesh instance is dropped from
the list, no `0x00`, the ordinary instance keeps advertising (the packet is not aired in
this case — pre-existing: `mesh_send_sync()` sets `instance = 0` when
`hdev->adv_instance_timeout` is set, `mgmt.c:2390-2395`; recorded as an open question);
ext, mesh alone → set 4 disabled and removed, then (if `HCI_LE_ADV` is still set) the
global disable; ext with an ordinary set 1 → set 4 disabled and removed, set 1 untouched,
no global disable (list not empty).

## Step 1 — the kernel series (quoted)

Branch `mesh/phase3-series-on-bluetooth-master-2026-10-02` in `cache/mesh-guest`, two
commits on `86ef0f58bdec`:

    de2b51ad33e4 Bluetooth: MGMT: remove the mesh advertising instance when done   (1 file changed, 21 insertions(+))
    0ca34eea2330 Bluetooth: MGMT: complete the mesh transmission that was on air    (1 file changed, 17 insertions(+), 4 deletions(-))

`git format-patch -2 --cover-letter --base=auto -o tmp/mesh-tester-ci/series` →
`0000-cover-letter.patch` (subject and blurb written; `base-commit: 86ef0f58bdec…`),
`0001-Bluetooth-MGMT-remove-the-mesh-advertising-instance-.patch`,
`0002-Bluetooth-MGMT-complete-the-mesh-transmission-that-w.patch`. Commit messages are in
`series/msg-0001.txt`, `series/msg-0002.txt`. 1/2: `Fixes: f3cb5676e5c1`, `Cc: stable`;
2/2: `Fixes: b338d91703fa`, `Cc: stable` (range reasoning in §E).

Applies on bluetooth-next: branch `mesh/phase3-series-on-bluetooth-next-2026-10-02` from
`671d566d3c3b`, `git am 0001… 0002…` →

    Applying: Bluetooth: MGMT: remove the mesh advertising instance when done
    Applying: Bluetooth: MGMT: complete the mesh transmission that was on air

(no offset or fuzz reported). The same `git am` in `cache/full-bt-next` (reset to
`bluetooth/master` `86ef0f58bdec` after preserving its old HEAD) applied identically.

Guest kernels (`make -C cache/mesh-guest -f tmp/mesh-tester-ci/build.mk kernel-all KTAG=…`:
`cp doc/tester.config .config; make olddefconfig; make -j16; cp bzImage`), each with a
`.commit` file naming its source commit:

    bzImage-bluetooth-patched    0ca34eea2330 (bluetooth tip + 1/2 + 2/2)   kernel-build-bluetooth-patched.log: "Kernel: arch/x86/boot/bzImage is ready  (#3)"
    bzImage-bluetooth-unpatched  86ef0f58bdec (bluetooth tip)               kernel-build-bluetooth-unpatched.log
    bzImage-bt-next-patched      (bluetooth-next 671d566d3c3b + series)     building
    bzImage-unpatched            671d566d3c3b (phase 2's image, kept)

## Step 2 — the BlueZ tests (quoted)

Branch `mesh-tester/phase3-ext-adv-coexistence-queue-2026-10-02` in `cache/bluez-upstream`
on `8b4a41760`; git identity set in that tree with two `git config` calls. `tools/mesh-tester.c`:

- `test_bredrle50` variants: "Mesh - Send - Ext Adv" (expects
  `LE Set Extended Advertising Enable` with enable=1, one set, handle 4 — the duration bytes
  are not compared, via `expect_hci_param_check_func`, because they derive from the instance
  timeout, see §F), "Mesh - Send cancel - 1/2 - Ext Adv" (expect
  `LE Remove Advertising Set` handle 4 — unambiguous, immune to the hook-before-start race
  seen in phase 2 §3b).
- `test_mesh_tx()` sequence tests on both emulators, 4 s timeout, run stage issues the
  sends (so the HCI hook sees the whole sequence) and optionally a cancel right after the
  second send is acknowledged: asserts every `MESH_PACKET_CMPLT` handle in order, counts
  starts (`LE Set Advertising Enable 0x01` / ext enable of set 4) and tear-downs
  (`LE Set Advertising Enable 0x00` / `LE Remove Advertising Set 4`), fails on any
  `MGMT_EV_ADVERTISING_REMOVED`, waits 400 ms after the last completion, then checks the
  counts and `MGMT_OP_READ_ADV_FEATURES` (no instance left; `{1}` in the coexistence case):
  "cancel active" (1 then 2; starts 2, stops 2), "cancel queued" (2 then 1; 1, 1),
  "cancel all" (1, 2; 1, 1), "two completions" (1, 2; 2, 2), "coexist - instance remains"
  (setup adds ordinary instance 1; legacy: stops 0, starts not checked; ext: starts 1,
  stops 1, no `LE Set Extended Advertising Enable {0x00, 0 sets}`).
- Expected unpatched behaviour (inferred): legacy "two completions" emits
  `ADVERTISING_REMOVED(6)` through `adv_timeout_expire` when the second send re-arms the
  exhausted instance with a 0-s timeout (phase 1 §6's slow-run mechanism) → "Failed";
  the cancel sequences keep the handles but reach 0 tear-downs → "Failed" at the settle
  check; ext coexistence: 0 tear-downs. Legacy coexistence does not distinguish (the
  mesh instance is hidden by `read_adv_features()`, `mgmt.c:8837-8844`) — it is a guard
  for the property `f3cb5676e5c1` protected.

`make -C cache/bluez-upstream tools/mesh-tester` → `CC tools/mesh-tester.o`,
`CCLD tools/mesh-tester`, no warnings. Committed as `51ab024b5` ("tools/mesh-tester: Add
extended advertising and send sequence tests", `1 file changed, 577 insertions(+)`);
exported as `series/bluez-0001-tools-mesh-tester-Add-extended-advertising-and-send-sequence-tests.patch`
(message `series/msg-bluez-mesh-tester.txt`). `cache/bluez-noasan` (sanitizer-free, for
valgrind) checked out at the same commit and its `tools/mesh-tester` rebuilt.

## Step 3 — runs

Tester: `cache/bluez-upstream/tools/mesh-tester` (ASAN/UBSAN, 23 cases) unless stated. All
logs under `tmp/mesh-tester-ci/run-p3-*.log`; the guest kernel is identified by the
`Linux version` line quoted from each log.

### 3a. First pass, KVM, `-m -d` (in-guest btmon + debug), three images — run while two
VMs and a kernel build shared the host (quoted)

Commands: `make -C cache/bluez-upstream -f tmp/mesh-tester-ci/build.mk run-mesh-kvm TAG=<tag> BZIMAGE=<image>`
(= `tools/test-runner -k <image> -m -- tools/mesh-tester -d`).

`run-p3-bluetooth-patched-kvm.log` — `Linux version 7.3.0-rc2-00393-g0ca34eea2330` (bluetooth tip + series):

    Mesh - Send                                          Passed      0.685 seconds
    Mesh - Send cancel - 1                               Passed      0.547 seconds
    Mesh - Send cancel - 2                               Failed      0.452 seconds
    Mesh - Send - Ext Adv                                Passed      0.631 seconds
    Mesh - Send cancel - 1 - Ext Adv                     Passed      0.726 seconds
    Mesh - Send cancel - 2 - Ext Adv                     Passed      0.604 seconds
    Mesh - Send queue - cancel active                    Passed      1.216 seconds
    Mesh - Send queue - cancel queued                    Passed      1.348 seconds
    Mesh - Send queue - cancel all                       Passed      1.105 seconds
    Mesh - Send queue - two completions                  Timed out   4.643 seconds
    Mesh - Send coexist - instance remains               Passed      0.991 seconds
    Mesh - Send queue - cancel active - Ext Adv          Passed      1.083 seconds
    Mesh - Send queue - cancel queued - Ext Adv          Passed      0.915 seconds
    Mesh - Send queue - cancel all - Ext Adv             Passed      0.686 seconds
    Mesh - Send queue - two completions - Ext Adv        Passed      0.960 seconds
    Mesh - Send coexist - instance remains - Ext Adv     Passed      0.849 seconds
    Total: 23, Passed: 21 (91.3%), Failed: 2, Not Run: 0

The two non-passes, from the log (quoted):
- "Mesh - Send cancel - 2" (lines 8913-8995): the run stage began before the setup's own
  commands had completed — `Registering HCI command callback`, `Sending Mesh Send Cancel`
  (8916-8918), then `command 0x000d complete` (SET_LE, 8931), `command 0x004a complete`
  (8934), the two `0x0059` replies (8937, 8963) and the first send's `01 0a 20 01 01`
  (8980) → `Unexpected HCI command parameter value: > 01 / ! 00`. This is the pre-existing
  test's race arm already seen unpatched in phase 2 §3b (setup sends are fire-and-forget,
  the tester's idle `run` callback can land anywhere in the kernel's start sequence); the
  host load made it more likely. **inferred**
- "Mesh - Send queue - two completions" (19023-19211): the guest ran out of memory —
  `mesh-tester invoked oom-killer`, `Out of memory: Killed process 36 (btmon)
  total-vm:21474909760kB, anon-rss:88836kB` (19080-19155; the ASAN btmon plus the ASAN
  tester in the tester VM's RAM: `65406 pages RAM, 32707 pages reserved`). The trace that
  follows shows the full expected sequence — `01 0a 20 01 01`, `01 0a 20 01 00`,
  `Mesh Packet Complete handle 1 (1 of 2)`, restart `01 0a 20 01 01`, `01 0a 20 01 00`,
  `Mesh Packet Complete handle 2 (2 of 2)` (19156-19210) — but the stall consumed the 4-s
  budget. Environmental; the remaining runs are without `-m`, as the bot runs. **quoted + inferred**

`run-p3-bluetooth-unpatched-kvm.log` — `Linux version 7.3.0-rc2-00391-g86ef0f58bdec` (bluetooth tip):

    Mesh - Send                                          Passed      0.972 seconds
    Mesh - Send cancel - 1                               Timed out   1.881 seconds
    Mesh - Send cancel - 2                               Failed      0.641 seconds
    Mesh - Send - Ext Adv                                Passed      0.718 seconds
    Mesh - Send cancel - 1 - Ext Adv                     Timed out   2.642 seconds
    Mesh - Send cancel - 2 - Ext Adv                     Timed out   1.945 seconds
    Mesh - Send queue - cancel active                    Failed      1.118 seconds
    Mesh - Send queue - cancel queued                    Failed      1.240 seconds
    Mesh - Send queue - cancel all                       Failed      1.906 seconds
    Mesh - Send queue - two completions                  Failed      0.970 seconds
    Mesh - Send coexist - instance remains               Passed      0.818 seconds
    Mesh - Send queue - cancel active - Ext Adv          Failed      0.886 seconds
    Mesh - Send queue - cancel queued - Ext Adv          Failed      0.710 seconds
    Mesh - Send queue - cancel all - Ext Adv             Failed      0.527 seconds
    Mesh - Send queue - two completions - Ext Adv        Failed      0.663 seconds
    Mesh - Send coexist - instance remains - Ext Adv     Failed      0.584 seconds
    Total: 23, Passed: 10 (43.5%), Failed: 13, Not Run: 0

Failure reasons printed by the new tests (quoted, `grep 'Expected'`): "cancel active":
`Expected 2 starts of the mesh set` (both emulators); "cancel queued", "cancel all",
ext coexistence: `Expected 1 tear-downs of the mesh set`; "two completions":
`Expected 2 tear-downs of the mesh set`. The legacy "two completions" trace (19054-19142)
shows what the unpatched kernel does with two back-to-back sends: `01 0a 20 01 01`,
`Mesh Packet Complete handle 1`, then for the second packet `01 0a 20 01 00` (the
disable `hci_enable_advertising_sync()` issues before re-enabling), `01 0a 20 01 01`,
`Mesh Packet Complete handle 2` — and nothing after it: `Mesh set starts 2 stops 1` — the
second packet stays on air. (Phase 1 §6 expected an `adv_timeout_expire` here; it does not
come because `hci_add_adv_instance()` on the existing instance resets `remaining_time` to
1000 — corrected model, **inferred** from `hci_core.c:1716-1717` and this trace.) Legacy
coexistence passes unpatched as predicted (it guards `f3cb5676e5c1`'s property).

`run-p3-bt-next-patched-kvm.log` — `Linux version 7.3.0-rc2-00463-g2d49b68ce8fe`
(bluetooth-next `671d566d3c3b` + series), run while the preflight's `make -j16` ran:

    Mesh - Send cancel - 1                               Failed      0.168 seconds
    Mesh - Send cancel - 2                               Failed      0.164 seconds
    (all 21 other cases, including every new one)       Passed
    Total: 23, Passed: 21 (91.3%), Failed: 2, Not Run: 0

Both failures are the same `> 01 / ! 00` arm (`grep -B3 -A3 'Unexpected HCI command
parameter value'`, lines 8109-8111, 8970-8973). So the series behaves identically on
bluetooth-next; the two pre-existing cancel cases are load-sensitive by construction and
are re-run below without the monitor and without concurrent load.

### 3b. KVM, ASAN tester, `-d`, no in-guest monitor (the bot's configuration), one VM at a
time, nothing else running (quoted)

Command: `make -C cache/bluez-upstream -f tmp/mesh-tester-ci/build.mk run-mesh-kvm-nomon TAG=<tag> BZIMAGE=<image>`
(= `tools/test-runner -k <image> -- tools/mesh-tester -d`).

`run-p3-bluetooth-patched-kvm-nomon.log` — `Linux version 7.3.0-rc2-00393-g0ca34eea2330`:

    Controller setup                                     Passed      0.090 seconds
    Mesh - Enable 1                                      Passed      0.070 seconds
    Mesh - Enable 2                                      Passed      0.089 seconds
    Mesh - Read Mesh Features                            Passed      0.080 seconds
    Mesh - Read Mesh Features - Disabled                 Passed      0.068 seconds
    Mesh - Send                                          Passed      0.170 seconds
    Mesh - Send - too short                              Passed      0.081 seconds
    Mesh - Send - too long                               Passed      0.081 seconds
    Mesh - Send cancel - 1                               Passed      0.172 seconds
    Mesh - Send cancel - 2                               Passed      0.165 seconds
    Mesh - Send - Ext Adv                                Passed      0.184 seconds
    Mesh - Send cancel - 1 - Ext Adv                     Passed      0.185 seconds
    Mesh - Send cancel - 2 - Ext Adv                     Passed      0.173 seconds
    Mesh - Send queue - cancel active                    Passed      0.659 seconds
    Mesh - Send queue - cancel queued                    Passed      0.576 seconds
    Mesh - Send queue - cancel all                       Passed      0.499 seconds
    Mesh - Send queue - two completions                  Passed      0.659 seconds
    Mesh - Send coexist - instance remains               Passed      0.571 seconds
    Mesh - Send queue - cancel active - Ext Adv          Passed      0.676 seconds
    Mesh - Send queue - cancel queued - Ext Adv          Passed      0.584 seconds
    Mesh - Send queue - cancel all - Ext Adv             Passed      0.503 seconds
    Mesh - Send queue - two completions - Ext Adv        Passed      0.680 seconds
    Mesh - Send coexist - instance remains - Ext Adv     Passed      0.587 seconds
    Total: 23, Passed: 23 (100.0%), Failed: 0, Not Run: 0

`run-p3-bt-next-patched-kvm-nomon.log` — `Linux version 7.3.0-rc2-00463-g2d49b68ce8fe`
(bluetooth-next + series): all 23 lines `Passed` (0.069-0.668 s),
`Total: 23, Passed: 23 (100.0%), Failed: 0, Not Run: 0`.

`run-p3-bluetooth-unpatched-kvm-nomon.log` — `Linux version 7.3.0-rc2-00391-g86ef0f58bdec`:

    Mesh - Send cancel - 1                               Timed out   2.082 seconds
    Mesh - Send cancel - 2                               Timed out   2.000 seconds
    Mesh - Send cancel - 1 - Ext Adv                     Timed out   1.827 seconds
    Mesh - Send cancel - 2 - Ext Adv                     Timed out   1.999 seconds
    Mesh - Send queue - cancel active                    Failed      0.568 seconds
    Mesh - Send queue - cancel queued                    Failed      0.572 seconds
    Mesh - Send queue - cancel all                       Failed      0.491 seconds
    Mesh - Send queue - two completions                  Failed      0.652 seconds
    Mesh - Send coexist - instance remains               Passed      0.567 seconds
    Mesh - Send queue - cancel active - Ext Adv          Failed      0.575 seconds
    Mesh - Send queue - cancel queued - Ext Adv          Failed      0.576 seconds
    Mesh - Send queue - cancel all - Ext Adv             Failed      0.499 seconds
    Mesh - Send queue - two completions - Ext Adv        Failed      0.661 seconds
    Mesh - Send coexist - instance remains - Ext Adv     Failed      0.585 seconds
    Total: 23, Passed: 10 (43.5%), Failed: 13, Not Run: 0

`run-p3-bt-next-unpatched-kvm-nomon.log` — `Linux version 7.3.0-rc2-00461-g671d566d3c3b`
(phase 2's unpatched image): the same 13 cases fail the same way (four `Timed out`
1.824-2.068 s, nine `Failed`), `Total: 23, Passed: 10 (43.5%), Failed: 13, Not Run: 0`.

The extended-advertising teardown on the wire (`grep 'vhci: > 01 (39|3c) 20'` on the
patched no-monitor log, "Mesh - Send - Ext Adv", lines 5132-5149; `0x2039` = LE Set
Extended Advertising Enable, `0x203c` = LE Remove Advertising Set):

    hciemu: vhci: > 01 39 20 06 01 01 04 a0 06 00     enable, 1 set, handle 4, duration 0x06a0 (= 1696 x 10 ms, see §F)
    hciemu: vhci: > 01 39 20 06 00 01 04 00 00 00     disable, 1 set, handle 4            (+75 ms)
    hciemu: vhci: > 01 3c 20 01 04                    remove advertising set 4

No `01 39 20 02 00 00` (disable all sets) appears anywhere in the patched log; the ext
coexistence case shows set 1's own enable from the setup (`01 39 20 06 01 01 01 00 00 00`,
line 11835) and then only set 4's enable/disable/remove. The unpatched log has the set-4
enables and **no** `01 3c 20` at all; its only set-4 disable (line 10932, "two completions
- Ext Adv") is the one `hci_setup_ext_adv_instance_sync()` issues before re-parametrising
the still-enabled set for the second packet. **quoted + inferred**

### 3c. Full mgmt-tester, KVM, ASAN tester, patched bluetooth kernel (quoted)

Command: `make -C cache/bluez-upstream -f tmp/mesh-tester-ci/build.mk run-mgmt-kvm TAG=p3-bluetooth-patched-mgmt-kvm BZIMAGE=tmp/mesh-tester-ci/bzImage-bluetooth-patched`
(= `tools/test-runner -k <image> -- tools/mgmt-tester`). `run-p3-bluetooth-patched-mgmt-kvm.log`,
`Linux version 7.3.0-rc2-00393-g0ca34eea2330`:

    Total: 501, Passed: 501 (100.0%), Failed: 0, Not Run: 0

(`grep -E 'Timed out|Failed  |Not Run '` on the result lines: nothing.) The 501 cases include
the Add/Remove Advertising and extended-advertising suites that exercise
`hci_remove_advertising_sync()` and `mgmt_advertising_removed()`; the early return added to
the latter for `instance > le_num_of_adv_sets` changes none of their expectations (every
instance they add is ≤ `le_num_of_adv_sets`).

### 3d. TCG + valgrind, sanitizer-free tester (`cache/bluez-noasan`), the bot's May
configuration, "Send" cases (quoted)

Command: `make -C cache/bluez-noasan -f tmp/mesh-tester-ci/build.mk run-custom BLUEZ=cache/bluez-noasan BZIMAGE=<image> TAG=<tag> RUNNER_OPTS="-q tmp/mesh-tester-ci/qemu-tcg.sh" CMD="valgrind --error-exitcode=65 cache/bluez-noasan/tools/mesh-tester -s Send"`
(absolute paths in the real call; `qemu-tcg.sh` forces `accel=tcg`).

`run-p3-bluetooth-patched-tcg-valgrind-noasan.log` — `Linux version 7.3.0-rc2-00393-g0ca34eea2330`:

    Mesh - Send                                          Passed      1.773 seconds
    Mesh - Send - too short                              Passed      0.291 seconds
    Mesh - Send - too long                               Passed      0.255 seconds
    Mesh - Send cancel - 1                               Passed      0.361 seconds
    Mesh - Send cancel - 2                               Passed      0.337 seconds
    Mesh - Send - Ext Adv                                Passed      0.513 seconds
    Mesh - Send cancel - 1 - Ext Adv                     Passed      0.387 seconds
    Mesh - Send cancel - 2 - Ext Adv                     Passed      0.376 seconds
    Mesh - Send queue - cancel active                    Passed      0.963 seconds
    Mesh - Send queue - cancel queued                    Passed      0.775 seconds
    Mesh - Send queue - cancel all                       Passed      0.692 seconds
    Mesh - Send queue - two completions                  Passed      0.871 seconds
    Mesh - Send coexist - instance remains               Passed      0.778 seconds
    Mesh - Send queue - cancel active - Ext Adv          Passed      0.914 seconds
    Mesh - Send queue - cancel queued - Ext Adv          Passed      0.795 seconds
    Mesh - Send queue - cancel all - Ext Adv             Passed      0.715 seconds
    Mesh - Send queue - two completions - Ext Adv        Passed      0.893 seconds
    Mesh - Send coexist - instance remains - Ext Adv     Passed      0.794 seconds
    Total: 18, Passed: 18 (100.0%), Failed: 0, Not Run: 0
    ==37== ERROR SUMMARY: 7 errors from 7 contexts (suppressed: 0 from 0)

The 7 valgrind findings are not from the new code: one
`Syscall param socketcall.bind(my_addr.rc_bdaddr) points to uninitialised byte(s)` in
`bt_log_open (log.c:118)` (also in phase 2's logs, line 65 of both), and six
`40 (+40) bytes in 1 (+1) blocks are definitely lost` allocated by `mgmt_register
(mgmt.c:974)` from `test_command_generic (mesh-tester.c:894)` — the `expect_alt_ev`
registration of the generic cases; phase 2's runs (`run-patched-tcg-valgrind-noasan-quiet.log`)
show 3 such for the 3 generic alt-event cases then run, now 6 for 6 ("Mesh - Send",
"Send cancel - 1/2" and their Ext Adv variants). `test_mesh_tx()`'s registrations are
released with `mgmt_alt` and are not reported. **quoted + inferred**

`run-p3-bluetooth-unpatched-tcg-valgrind-noasan.log` — `Linux version 7.3.0-rc2-00391-g86ef0f58bdec`:

    Mesh - Send                                          Passed      1.744 seconds
    Mesh - Send cancel - 1                               Timed out   2.298 seconds
    Mesh - Send cancel - 2                               Timed out   1.984 seconds
    Mesh - Send - Ext Adv                                Passed      0.490 seconds
    Mesh - Send cancel - 1 - Ext Adv                     Timed out   2.501 seconds
    Mesh - Send cancel - 2 - Ext Adv                     Timed out   1.999 seconds
    Mesh - Send queue - cancel active                    Failed      0.815 seconds
    Mesh - Send queue - cancel queued                    Failed      0.770 seconds
    Mesh - Send queue - cancel all                       Failed      0.695 seconds
    Mesh - Send queue - two completions                  Failed      0.856 seconds
    Mesh - Send coexist - instance remains               Passed      0.781 seconds
    Mesh - Send queue - cancel active - Ext Adv          Failed      0.780 seconds
    Mesh - Send queue - cancel queued - Ext Adv          Failed      0.778 seconds
    Mesh - Send queue - cancel all - Ext Adv             Failed      0.698 seconds
    Mesh - Send queue - two completions - Ext Adv        Failed      0.876 seconds
    Mesh - Send coexist - instance remains - Ext Adv     Failed      0.782 seconds
    Total: 18, Passed: 5 (27.8%), Failed: 13, Not Run: 0
    ==36== ERROR SUMMARY: 7 errors from 7 contexts (suppressed: 0 from 0)

Same 13 failures as under KVM, same valgrind signature (so the 7 findings are independent
of the kernel, as expected for tester-side reports).

### 3e. Five repeated runs of the cancel cases, KVM, ASAN tester (quoted)

Command: `make -C cache/bluez-upstream -f tmp/mesh-tester-ci/build.mk run-mesh-repeat TAG=p3-bluetooth-patched-repeat BZIMAGE=tmp/mesh-tester-ci/bzImage-bluetooth-patched STR=cancel`
(= five times `tools/test-runner -k <image> -- tools/mesh-tester -s cancel`, logs
`run-p3-bluetooth-patched-repeat-{1..5}.log`, grep'd into
`run-p3-bluetooth-patched-repeat-summary.txt`). `-s cancel` selects the 10 cases whose
name contains "cancel": the two pre-existing ones, their Ext Adv variants, and the six
"Send queue - cancel …" sequences on both emulators.

    repeat-1.log: Total: 10, Passed: 10 (100.0%), Failed: 0, Not Run: 0
    repeat-2.log: Total: 10, Passed: 10 (100.0%), Failed: 0, Not Run: 0
    repeat-3.log: Total: 10, Passed: 10 (100.0%), Failed: 0, Not Run: 0
    repeat-4.log: Total: 10, Passed: 10 (100.0%), Failed: 0, Not Run: 0
    repeat-5.log: Total: 10, Passed: 10 (100.0%), Failed: 0, Not Run: 0

Per-case times are stable across the five runs (e.g. "Mesh - Send cancel - 1" 0.119-0.120 s,
"Send queue - cancel active" 0.579-0.588 s, "Send queue - cancel all - Ext Adv" 0.421-0.424 s);
50 of 50 cancel cases pass on the patched kernel.

### 3f. The same five runs on the unpatched bluetooth kernel (quoted)

`TAG=p3-bluetooth-unpatched-repeat BZIMAGE=tmp/mesh-tester-ci/bzImage-bluetooth-unpatched`,
`run-p3-bluetooth-unpatched-repeat-summary.txt`:

    repeat-1.log: Total: 10, Passed: 0 (0.0%), Failed: 10, Not Run: 0
    repeat-2.log: Total: 10, Passed: 0 (0.0%), Failed: 10, Not Run: 0
    repeat-3.log: Total: 10, Passed: 0 (0.0%), Failed: 10, Not Run: 0
    repeat-4.log: Total: 10, Passed: 0 (0.0%), Failed: 10, Not Run: 0
    repeat-5.log: Total: 10, Passed: 0 (0.0%), Failed: 10, Not Run: 0

`grep -c 'Passed  '` over the five summaries: 0. Unpatched 0/50, patched 50/50, same
tester, same host, back to back.

## Step 4 — hygiene (quoted)

### 4a. Kernel preflight (`scripts/kernel-preflight.sh cache/full-bt-next`, HEAD = the patch)

`cache/full-bt-next` reset to `bluetooth/master` (`86ef0f58bdec`), `make -j8 modules_prepare`,
`git am` of the two patches (`Applying: …` ×2, no fuzz), then the script once with HEAD =
2/2 (`preflight-0002.log`) and once after `git checkout --detach HEAD~1` with HEAD = 1/2
(`preflight-0001.log`; the 2/2 commit kept on
`keep/full-bt-next-phase3-series-on-bluetooth-master-4fc05c920590`).

`preflight-0001.log`:

    tree: a23f1c3b10f3 Bluetooth: MGMT: remove the mesh advertising instance when done
    base: 86ef0f58bdec Bluetooth: MGMT: Fix status of pending commands flushed on power off
    ── checkpatch --strict -g HEAD
    total: 0 errors, 0 warnings, 0 checks, 35 lines checked
    ── W=1 build of net/bluetooth
       W=1 -Werror: clean
    ── sparse (C=1) on mgmt.c, patched vs base
       findings in mgmt.c: base 0, patched 0
       no new sparse finding introduced by the patch

`preflight-0002.log`:

    tree: 4fc05c920590 Bluetooth: MGMT: complete the mesh transmission that was on air
    base: a23f1c3b10f3 Bluetooth: MGMT: remove the mesh advertising instance when done
    ── checkpatch --strict -g HEAD
    total: 0 errors, 0 warnings, 0 checks, 34 lines checked
    ── W=1 build of net/bluetooth
       W=1 -Werror: clean
    ── sparse (C=1) on mgmt.c, patched vs base
       findings in mgmt.c: base 0, patched 0
       no new sparse finding introduced by the patch

(The sparse positive control held: the script exits 1 unless a `CHECK … mgmt.c` line is in
`make-c1.log`; it exited 0 both times.)

### 4b. Recipients (`scripts/get-maintainers.sh cache/full-bt-next <patch>`)

1/2:

    Marcel Holtmann (maintainer:BLUETOOTH SUBSYSTEM)
    Luiz Augusto von Dentz (maintainer:BLUETOOTH SUBSYSTEM,blamed_fixes:1/1=100%)
    Christian Eggers (blamed_fixes:1/1=100%)
    (addresses as printed by the script are not stored in this repository; take them from
    `scripts/get-maintainers.sh` at send time)
    linux-bluetooth@vger.kernel.org (open list:BLUETOOTH SUBSYSTEM)
    linux-kernel@vger.kernel.org (open list)

2/2: the same with `Brian Gix (blamed_fixes:1/1=100%)` in place of
Christian Eggers. `Cc: stable@vger.kernel.org` in the bodies is a tag, not a recipient
(`git send-email --suppress-cc=bodycc`, as the preflight script notes).

### 4c. BlueZ patch checks

- `scripts/gitlint-check.sh cache/bluez-upstream series/bluez-0001-….patch` →
  `gitlint, version 0.19.1 … PASS  no violations`.
- `BT_PATCH_DIR=series/bluez-checkpatch patches/bluez/checkpatch-check.sh cache/bluez-upstream cache/full-bt-next/scripts/checkpatch.pl`
  (BlueZ's own `.checkpatch.conf`) → `total: 0 errors, 0 warnings, 606 lines checked …
  has no obvious style problems and is ready for submission.`

### 4d. Stable range (§E of the task)

- `scripts/backport-check.sh f3cb5676e5c1` (after `git -C cache/linux fetch stable`):
  `in: v6.16`; `stable/linux-6.12.y PRESENT (a99f80c88a97)`, `6.6.y PRESENT (0506547f6e3d)`,
  `6.1.y PRESENT (9514f361fcdf)`; `7.2.y`/`6.18.y` reported `FAILS` with no hunk message —
  the dry run sees an already-applied patch, and `git merge-base --is-ancestor f3cb5676e5c1
  stable/linux-7.2.y` and `… stable/linux-6.18.y` both exit 0: the commit is in those lines
  by ancestry. `5.15.y`/`5.10.y`: `Hunk #1 FAILED` — no mesh support there (`b338d91703fa` is
  v6.1). **quoted + inferred**
- `scripts/series-backport-check.sh` (new helper, read-only: copies the touched files from
  each branch and applies the series cumulatively with `patch -p1`):

      stable/linux-7.2.y     APPLIES  [1: offset -2 lines] [2: offset -2 lines]    [tip 9a66fdc0d7fd]
      stable/linux-6.18.y    APPLIES  [1: offset 1 line]   [2: offset 1 line]      [tip 1b357ecb3213]
      stable/linux-6.12.y    APPLIES  [1: offset -22 lines] [2: offset -22 lines]  [tip e2acc2211022]
      stable/linux-6.6.y     APPLIES  [1: offset -21 lines] [2: offset -21 lines]  [tip 79643295eba1]
      stable/linux-6.1.y     APPLIES  [1: offset -27 lines] [2: offset -27 lines]  [tip 1a8763b93150]
      stable/linux-5.15.y    FAILS at patch 1: Hunk #1 FAILED at 1093.
      stable/linux-5.10.y    FAILS at patch 1: Hunk #1 FAILED at 1093.

- Does 2/2 depend on `71af682ba469` ("Bluetooth: mgmt: Dequeue pending mesh_send_sync
  entries on cancel", v7.3-rc5)? `scripts/backport-check.sh 71af682ba469` → `APPLIES` on
  every line from 6.1.y to 7.2.y, i.e. it is in **none** of them yet. 2/2 only changes which
  `mesh_tx` `mesh_send_done_sync()` completes; `71af682ba469` changes what `send_cancel()`
  does with a not-yet-started entry (dequeue its `mesh_send_sync`). Without
  `71af682ba469`, cancelling the in-flight handle still removes it from `mesh_pending`
  before `mesh_send_done_sync()` runs, so 2/2's "no owner found → complete nothing, let
  `mesh_next()` send the queued one" holds there too; cancelling a queued entry completes
  it in both versions (the dequeue only closes a use-after-free window that is independent
  of 2/2). So both patches can carry `Cc: stable` for 6.1.y+ without `71af682ba469`.
  **inferred**; not run on a stable kernel (apply-check only; a build on 6.1.y would need
  `cache/full-6.1.y` + `make M=net/bluetooth`, not done).

## Step 5 — the duration overflow (task item 3 / §F)

Written up separately in `tmp/mesh-tester-ci/duration-overflow-note.md` (code, table of
truncated values, consequence for ordinary instances with `timeout > 65 s` on
extended-advertising controllers, candidate fix, reproducer plan with two mgmt-tester
cases). The truncation is visible on the wire in this phase's logs: every mesh set enable
carries `a0 06` = 1696 × 10 ms (§3b). Not part of the series; the series' messages claim
1000 s only for the legacy path.

## Summary

**What the series does.** Patch 1/2 (`Fixes: f3cb5676e5c1`, `Cc: stable`) makes
`mesh_send_done_sync()` tear the mesh advertising instance (`le_num_of_adv_sets + 1`) down
through `hci_remove_advertising_sync()` — the same path MGMT Remove Advertising uses — before
the existing `list_empty()` check: on the legacy path the instance is dropped, its 1000-s
timer cancelled and `LE Set Advertising Enable (0x00)` follows when no other instance is
left; with extended advertising that set alone is disabled and removed
(`LE Set Extended Advertising Enable {0x00, 1 set, handle}`, `LE Remove Advertising Set`)
while other sets keep running. `mgmt_advertising_removed()` returns early for the internal
instance (`> le_num_of_adv_sets`), so userspace never sees an Advertising Removed for an
instance it never added. Patch 2/2 (`Fixes: b338d91703fa`, `Cc: stable`) completes the
`mesh_tx` whose `->instance` is the mesh instance instead of the queue head, so after
cancelling the in-flight handle the queued packet is sent rather than reported complete
unsent. The BlueZ patch adds the BREDRLE50 variants of Send/cancel and ten sequence cases
asserting handles, start/tear-down counts, the absence of Advertising Removed and the
Read Advertising Features contents.

**Results** (all quoted above):

| configuration | unpatched (`86ef0f58bdec` / `671d566d3c3b`) | patched (bluetooth + series / bluetooth-next + series) |
|---|---|---|
| mesh-tester 23 cases, KVM, ASAN, no monitor (§3b) | 10/23 (4 cancel cases Timed out, 9 sequence cases Failed) | **23/23** and **23/23** |
| mesh-tester, KVM, ASAN, `-m -d`, under host load (§3a) | 10/23 | 21/23 (pre-existing cancel race arm; btmon OOM) |
| mesh-tester "Send" cases, TCG + valgrind, no sanitizers (§3d) | 5/18 | **18/18** (valgrind: 7 pre-existing tester findings, identical unpatched) |
| cancel cases × 5 runs, KVM (§3e, §3f) | 0/50 | **50/50** |
| mgmt-tester 501 cases, KVM (§3c) | not run (phase 2: n/a) | **501/501** |
| checkpatch --strict / W=1 -Werror / sparse (§4a) | — | 0/0/0, clean, 0 new — both patches |
| applies: bluetooth-next (`git am`), stable 6.1.y–7.2.y (dry run) (§1, §4d) | — | clean / APPLIES with offsets |

**Deliverables** (nothing sent or posted): `tmp/mesh-tester-ci/series/0000-cover-letter.patch`,
`0001-Bluetooth-MGMT-remove-the-mesh-advertising-instance-.patch`,
`0002-Bluetooth-MGMT-complete-the-mesh-transmission-that-w.patch` (base-commit
`86ef0f58bdec`), `bluez-0001-tools-mesh-tester-Add-extended-advertising-and-send-sequence-tests.patch`,
`duration-overflow-note.md`, this file, the run logs `run-p3-*.log`, `preflight-000{1,2}.log`,
the images `bzImage-{bluetooth-patched,bluetooth-unpatched,bt-next-patched}` with `.commit`
files, `build.mk` (new targets `kernel-all`, `run-mesh-kvm-nomon`, `run-mesh-repeat`),
`scripts/series-backport-check.sh`. Branches: `mesh/phase3-series-on-bluetooth-master-2026-10-02`,
`mesh/phase3-series-on-bluetooth-next-2026-10-02` (cache/linux),
`mesh-tester/phase3-ext-adv-coexistence-queue-2026-10-02` (cache/bluez-upstream), and the
`keep/…` branches preserving every commit that was detached before.

## Open questions (not settled here)

1. **Legacy coexistence does not air the mesh packet.** With an ordinary instance rotating
   on a legacy controller, `mesh_send_sync()` takes the `hdev->adv_instance_timeout` branch
   (`instance = 0`, `mgmt.c:2390-2395`) and sends nothing; 75 ms later the series tears the
   (never started) mesh instance down and completes the handle. Pre-existing behaviour,
   unchanged by the series, asserted by "Mesh - Send coexist - instance remains" only in
   the form "nothing is disabled, instance 1 remains". Whether mesh sends should pre-empt
   the rotation on single-set controllers is a design question for the maintainers.
2. **The pre-existing "Mesh - Send cancel - 1/2" cases are load-sensitive** (their setup
   sends are fire-and-forget; the run stage can start before the kernel's start sequence
   and then sees the `0x01`). Seen in §3a under host load, never in §3b-3d. The BlueZ patch
   does not change them; a follow-up could move the two sends into the run stage as
   `test_mesh_tx()` does. Not done, to keep the tester patch to additions.
3. **`read_adv_features()` hides by `instance > adv_instance_cnt`**, not by
   `> le_num_of_adv_sets` as its comment says (`mgmt.c:8837-8838`): an ordinary instance
   numbered higher than the count of instances (e.g. instance 5 alone) is hidden too.
   Unrelated to mesh; noted, not pursued.
4. **The bot's 2026-05-05..05-21 passes** remain unexplained by experiment (phase 2 §3c'').
   Phase 1 §6's model of a 0-s `adv_timeout_expire` is corrected by this phase's unpatched
   "two completions" trace (the re-add resets `remaining_time`); so that mechanism was not
   it either. Not needed for the fix.
5. **Stable builds** of the series were not done (apply-check only, §4d); the preflight
   built on the `bluetooth` tip only. `scripts/build-bluetooth-fulltree.sh` could do 6.1.y
   if the operator wants a built proof before the `Cc: stable` tags go out.
6. **A kernel patch for the duration overflow** is not written; the note has the plan.
