# `TestRunner_mesh-tester` — Phase 2 results (reproduction and patch)

Started 2026-10-01. Follows §9.2 of `phase1-findings.md`. Updated after every step.
Everything runs inside qemu on a freshly built guest kernel; the host Bluetooth stack is
not touched. Writes only under `cache/bluez-upstream` (build products), `cache/mesh-guest`
(new kernel worktree) and `tmp/mesh-tester-ci/`.

Helper: `tmp/mesh-tester-ci/build.mk` — a Makefile whose targets run the multi-step
recipes (bootstrap/configure, test-runner invocations with their output captured to files
under `tmp/mesh-tester-ci/`). Every shell call is `make -C <dir> -f .../build.mk <target>`.

## Step 0 — environment (quoted)

- `cache/full-bt-next` is at `b00c0e4ee93d` (2026-09-24, "Bluetooth: MGMT: Fix status of
  pending commands flushed on power off"), i.e. bluetooth-next tip plus the operator's held
  patch; `.config` present, no bzImage. Not used, to keep the held branch untouched.
- New worktree `cache/mesh-guest` created from `bluetooth-next/master`
  (`671d566d3c3b`, 2026-09-23) — in progress.
- `/dev/kvm` present (`crw-rw----+ root kvm`); 16 CPUs; 70 GB free.

## Step 1 — BlueZ testers (in progress)

Recipe = the bot's (`ci/genericbuild.py`: `./bootstrap-configure` + params, then `make -jN`;
`ci/testrunnersetup.py` passes `--disable-lsan`). ELL cloned to `cache/ell` (depth 1) because
`bootstrap-configure` enables `--enable-mesh --enable-btpclient`, which take ELL from `../ell`
as the bot's `clone_ell` does.

- First `bootstrap-configure` attempt failed in `automake`: `configure.ac:36: error: required
  file './ltmain.sh' not found` (`tmp/mesh-tester-ci/bluez-configure.log`). `libtoolize
  --copy --force` run on its own then copied `./ltmain.sh` normally
  (`bluez-libtoolize.log`). **quoted**
- Second attempt: `configure: error: elfutils support is required` (`--enable-backtrace`);
  installed `libdw-dev` (plus `libcups2-dev` for `--enable-cups`; `libasound2-dev` was
  present). Third attempt configured (asan/lsan/ubsan detected, mesh, btpclient). **quoted**
- `make -j16`: failed once in `obexd/src/logind.c:23: fatal error: systemd/sd-login.h`;
  installed `libsystemd-dev`, resumed, completed. Built: `tools/test-runner` (120304 B),
  `tools/mesh-tester` (6121904 B), `tools/mgmt-tester` (9232656 B), `monitor/btmon`
  (12889344 B, the in-guest monitor test-runner `-m` starts from `monitor/btmon`). Testers are
  ASAN/UBSAN-instrumented like the bot's (`--enable-asan --enable-ubsan`, `--disable-lsan`).
  **quoted** (`bluez-make.log`)

## Step 2 — guest kernel (in progress)

Recipe = the bot's (`ci/generickernelbuild.py`): `cp doc/tester.config .config`,
`make olddefconfig`, full `make -jN`.

- `git worktree add --detach cache/mesh-guest bluetooth-next/master` inherited the clone's
  cone sparse checkout (`drivers/bluetooth include/net/bluetooth net/bluetooth`; 370 of
  96039 tracked files on disk), so `make olddefconfig` failed with
  `arch//Makefile: No such file or directory` (`kernel-olddefconfig.log`). Fixed with
  `git -C cache/mesh-guest sparse-checkout disable` (running; blobs are local because
  `cache/full-bt-next` is a full checkout of the same tip plus one patch). **quoted**
- After the full checkout (95531 files): `make olddefconfig` ok (`kernel-olddefconfig.log`:
  "configuration written to .config", 2938 lines; `CONFIG_BT=y`, `CONFIG_BT_HCIVHCI=y`,
  `CONFIG_NET_9P_VIRTIO=y`, `CONFIG_9P_FS=y`, `CONFIG_KVM_GUEST=y`, `CONFIG_HZ_250=y`,
  `CONFIG_PREEMPT_DYNAMIC=y`). Full `make -j16` done in ~4 min:
  `Kernel: arch/x86/boot/bzImage is ready  (#1)` — `cache/mesh-guest/arch/x86/boot/bzImage`,
  15815680 bytes (`kernel-build.log`). Source = `671d566d3c3b` unpatched. **quoted**

## Step 3 — unpatched runs (kernel `671d566d3c3b`, bzImage from Step 2)

### 3a. KVM, tester alone, `mesh-tester -d` (`run-unpatched-kvm.log`, 4592 lines) — **quoted**

Command: `make -C tmp/mesh-tester-ci -f build.mk run-mesh-kvm TAG=unpatched-kvm`
(= `tools/test-runner -k cache/mesh-guest/arch/x86/boot/bzImage -m -- tools/mesh-tester -d`).

    Controller setup                                     Passed      0.089 seconds
    Mesh - Enable 1                                      Passed      0.068 seconds
    Mesh - Enable 2                                      Passed      0.083 seconds
    Mesh - Read Mesh Features                            Passed      0.079 seconds
    Mesh - Read Mesh Features - Disabled                 Passed      0.068 seconds
    Mesh - Send                                          Passed      0.167 seconds
    Mesh - Send - too short                              Passed      0.080 seconds
    Mesh - Send - too long                               Passed      0.078 seconds
    Mesh - Send cancel - 1                               Timed out   2.083 seconds
    Mesh - Send cancel - 2                               Timed out   2.000 seconds
    Total: 10, Passed: 8 (80.0%), Failed: 2, Not Run: 0

Same result and signature as every bot run since 2026-05-25 (and March–April). The bot's
failure is reproduced on the first try.

Debug trace of "Mesh - Send cancel - 1" (log lines 3990–4057, hciemu `vhci:` = commands
the kernel sends to the emulated controller, `mgmt:` = the tester's mgmt socket): **quoted**

    Mesh - Send cancel - 1 - setup complete           (bthost client WRITE_SCAN_ENABLE done -> setup done)
    mgmt: command 0x000d complete                     (SET_LE)
    mgmt: command 0x004a complete / Mesh feature is enabled   (SET_EXP_FEATURE mesh)
    mgmt: command 0x0059 complete                     (MESH_SEND #1 -> handle 1)
    vhci: > 01 08 20 20 18 17 2b 01 ...   command 0x2008   (LE Set Advertising Data, the mesh PDU)
    vhci: > 01 05 20 06 53 c8 0d 1a 01 02 command 0x2005   (LE Set Random Address)
    mgmt: command 0x0059 complete                     (MESH_SEND #2 -> handle 2, queued)
    vhci: > 01 06 20 0f a0 00 f0 00 03 01 ... command 0x2006 (LE Set Advertising Parameters, ADV_NONCONN_IND)
    vhci: > 01 0a 20 01 01                command 0x200a   (LE Set Advertising Enable 0x01)
    Mesh - Send cancel - 1 - run
    Registering Mesh Packet Complete notification / Registering HCI command callback
    Sending Mesh Send Cancel (0x005a)
    mgmt-alt: event 0x0032 / New Mesh Packet Complete event received -> Test condition complete, 2 left
    mgmt: command 0x005a complete: 0x00 / Mesh Send Cancel: Success -> Test condition complete, 1 left
    mgmt-alt: event 0x0032                            (second MESH_PACKET_CMPLT: the kernel's 75 ms
                                                       mesh_send_done completing the OTHER handle)
    Mesh - Send cancel - 1 - test timed out           (no HCI command at all in the 2 s window)

**inferred from the quoted trace**: the only unmet condition is the expected
`LE Set Advertising Enable (0x00)`; the kernel sent no HCI command after the cancel, exactly
as the Phase 1 model predicted (`mesh_send_done_sync()` skips the disable because the mesh
instance keeps `adv_instances` non-empty, then completes `mgmt_mesh_next()` = handle 2).
The in-guest btmon did not start in this run ("Failed to locate Monitor binary": the runner
looks for `monitor/btmon` relative to its cwd); re-run from the BlueZ tree follows.

### 3b. KVM, tester alone, in-guest btmon running (`run-unpatched-kvm-btmon.log`) — **quoted**

Command: `make -C cache/bluez-upstream -f build.mk run-mesh-kvm TAG=unpatched-kvm-btmon`.
btmon started ("Using Monitor monitor/btmon", "Bluetooth monitor ver 5.87", guest
`Linux version 7.3.0-rc2-00461-g671d566d3c3b`).

    Mesh - Send cancel - 1                               Failed      0.177 seconds
    Mesh - Send cancel - 2                               Timed out   2.189 seconds
    Total: 10, Passed: 8 (80.0%), Failed: 2, Not Run: 0

Trace of case 1 (log lines 8104–8149): the `run` stage started while the kernel was still
in the middle of handle 1's start sequence — after `LE Set Advertising Data` but before
`LE Set Random Address` — so the freshly installed hook saw
`0x2005`, `0x2006`, then `0x200a` with parameter `01`:

    Registering HCI command callback
    Sending Mesh Send Cancel (0x005a)
    hciemu: vhci: > 01 05 20 06 ...   HCI Command 0x2005 length 6
    hciemu: vhci: > 01 06 20 0f ...   HCI Command 0x2006 length 15
    hciemu: vhci: > 01 0a 20 01 01    HCI Command 0x200a length 1
    Unexpected HCI command parameter value:
    > 01
    ! 00
    Mesh - Send cancel - 1 - test failed

**inferred**: this is the other arm of the race described in Phase 1 §6 — the test's
outcome depends on where the tester's idle `run` callback lands relative to the kernel's
start sequence and 75 ms timer. Both arms fail: the controller is never told to stop.

### 3c. TCG + valgrind, as the bot ran from 2026-05-05 to 09-09 (`run-unpatched-tcg-valgrind.log`) — **quoted**

Command: `make -C cache/bluez-upstream -f build.mk run-mesh-tcg-valgrind TAG=unpatched-tcg-valgrind`
(qemu via `tmp/mesh-tester-ci/qemu-tcg.sh`, which rewrites `accel=kvm:tcg` to `accel=tcg`).
The tester did not run:

    ==37== Command: /root/exp/qca9377-bt-hang/cache/bluez-upstream/tools/mesh-tester -d
    ==37==ASan runtime does not come first in initial library list; you should either link runtime to your application or manually preload it with LD_PRELOAD.
    ==37== ERROR SUMMARY: 0 errors from 0 contexts (suppressed: 0 from 0)
    Process 36 exited with status 1

Cause: today's bot builds the testers with ASAN (`--disable-lsan` only), valgrind refuses an
ASAN binary. In the valgrind era the bot built them with
`["--disable-lsan", "--disable-asan", "--disable-ubsan"]` (`ci/testrunnersetup.py` at
`f01e64b95f`; changed to `["--disable-lsan"]` by `c01507fbe2` on 2026-09-09) — **quoted**.
So the May configuration is: sanitizer-free testers under valgrind in TCG. A second BlueZ
worktree (`cache/bluez-noasan`, same HEAD `8b4a41760`) is being built with those flags.

### 3c'. TCG + valgrind with the sanitizer-free tester, `-m -d` (`run-unpatched-tcg-valgrind-noasan.log`) — **quoted**

Stopped by the 10-minute job limit after three cases (`qemu-system-x86_64: terminating on
signal 15`): `Controller setup - test timed out`, `Mesh - Enable 1 - test passed`,
`Mesh - Enable 2 - test timed out`. With valgrind, TCG, the in-guest btmon and `-d` debug
output together, this host is far slower than the bot's 60-second runs (even the 2 s
per-test budget is exceeded in setup). Re-run exactly as the bot did (no `-m`, no `-d`)
and limited to the "Mesh - Send" cases with the tester's `-p` prefix option.

### 3c''. TCG + valgrind, sanitizer-free tester, no btmon, no debug — the bot's May command
(`run-unpatched-tcg-valgrind-noasan-quiet.log`) — **quoted**

Command: `make -C cache/bluez-noasan -f build.mk run-custom BLUEZ=cache/bluez-noasan
BZIMAGE=tmp/mesh-tester-ci/bzImage-unpatched RUNNER_OPTS="-q tmp/mesh-tester-ci/qemu-tcg.sh"
CMD="valgrind --error-exitcode=65 cache/bluez-noasan/tools/mesh-tester -s Send"`.

    Mesh - Send                                          Passed      1.734 seconds
    Mesh - Send - too short                              Passed      0.276 seconds
    Mesh - Send - too long                               Passed      0.237 seconds
    Mesh - Send cancel - 1                               Timed out   2.555 seconds
    Mesh - Send cancel - 2                               Timed out   2.002 seconds
    Total: 5, Passed: 3 (60.0%), Failed: 2, Not Run: 0

**inferred**: the slow configuration does NOT pass the cancel cases on this host — the
bot's 18/18 passes of 2026-05-05..05-21 are not reproduced. On this host the slow path is
much slower than the bot's was ("Mesh - Send" 1.73 s vs. ~0.17 s under KVM; a whole
10-case run took > 10 min with btmon and debug, vs. the bot's 60 s), so the tester reaches
the cancel late but still inside the 2 s budget, and the kernel still never sends the
disable. Whatever interleaving produced the bot's May passes is not reachable with this
host's timing; it stays **not found**. It does not affect the diagnosis: unpatched, the
kernel never stops advertising after the cancel in any configuration tried here (3a, 3b,
3c'', 3d), and the two cases fail in all of them.

### 3e. KVM + valgrind, sanitizer-free tester, full suite (`run-unpatched-kvm-valgrind-noasan.log`) — **quoted**

    Mesh - Send                                          Passed      0.112 seconds
    Mesh - Send cancel - 1                               Timed out   1.773 seconds
    Mesh - Send cancel - 2                               Timed out   1.998 seconds
    Total: 10, Passed: 8 (80.0%), Failed: 2, Not Run: 0

Unpatched tally: 5 configurations (KVM; KVM + btmon; TCG; TCG + valgrind; KVM + valgrind),
the two cancel cases fail in all five (nine "Timed out", one "Failed" on the `0x01` arm).

### 3d. TCG, ASAN tester alone — the bot's March/April configuration (`run-unpatched-tcg.log`) — **quoted**

Command: `make -C cache/bluez-upstream -f build.mk run-mesh-tcg TAG=unpatched-tcg`.

    Mesh - Send                                          Passed      1.507 seconds
    Mesh - Send cancel - 1                               Timed out   2.787 seconds
    Mesh - Send cancel - 2                               Timed out   1.986 seconds
    Total: 10, Passed: 8 (80.0%), Failed: 2, Not Run: 0

Same as the bot's April results (e.g. `14533271`: "Timed out 2.627 / 1.994").

## Step 4 — patched runs

### 4a. The patch (applied, committed, exported) — **quoted**

- Unpatched image preserved as `tmp/mesh-tester-ci/bzImage-unpatched` (copy of the Step 2
  bzImage) so the remaining unpatched runs (valgrind) and the patched runs cannot be mixed up.
- `cache/mesh-guest/net/bluetooth/mgmt.c` `mesh_send_done_sync()` changed as in Phase 1 §9.1
  (remove the mesh instance `le_num_of_adv_sets + 1` under `hdev->lock` before the
  `list_empty()` check; complete the `mesh_tx` whose `instance` matches instead of
  `mgmt_mesh_next()`); committed on top of `671d566d3c3b` as `6cc1a7a507a9`
  ("Bluetooth: MGMT: stop advertising when a mesh transmission is done", author/committer
  Iaroslav Voitovych, `1 file changed, 26 insertions(+), 4 deletions(-)`), exported with
  `git format-patch -1` to `tmp/mesh-tester-ci/0001-Bluetooth-MGMT-stop-advertising-when-a-mesh-transmis.patch`.
- Patched kernel rebuilt (`Kernel: arch/x86/boot/bzImage is ready  (#2)`); `cmp` against
  `bzImage-unpatched`: `differ: byte 589`. **quoted**

### 4b. Patched, KVM, ASAN tester, `-m -d` — today's bot configuration (`run-patched-kvm.log`) — **quoted**

Command: `make -C cache/bluez-upstream -f build.mk run-mesh-kvm TAG=patched-kvm`.

    Controller setup                                     Passed      0.155 seconds
    Mesh - Enable 1                                      Passed      0.149 seconds
    Mesh - Enable 2                                      Passed      0.157 seconds
    Mesh - Read Mesh Features                            Passed      0.163 seconds
    Mesh - Read Mesh Features - Disabled                 Passed      0.123 seconds
    Mesh - Send                                          Passed      0.262 seconds
    Mesh - Send - too short                              Passed      0.143 seconds
    Mesh - Send - too long                               Passed      0.152 seconds
    Mesh - Send cancel - 1                               Passed      0.249 seconds
    Mesh - Send cancel - 2                               Passed      0.233 seconds
    Total: 10, Passed: 10 (100.0%), Failed: 0, Not Run: 0

Trace of case 1 (log lines 7701–8019; btmon timestamps in the guest): **quoted**

    Registering HCI command callback / Sending Mesh Send Cancel (0x005a)       05:58:57.268
    mgmt-alt: event 0x0032 / New Mesh Packet Complete event received -> 2 left
    Mesh Send Cancel (0x005a): Success (0x00)                        -> 1 left
    < HCI Command: LE Set Advertising Enable (0x08|0x000a) plen 1    05:58:57.346   (= 75 ms later)
            Advertising: Disabled (0x00)
    hciemu: vhci: > 01 0a 20 01 00 / HCI Command 0x200a length 1     -> 0 left
    Mesh - Send cancel - 1 - test passed
    hciemu: vhci: > 01 05 20 06 ...  (LE Set Random Address: handle 2 now actually starts)

"Mesh - Send" (line 5001) likewise ends with `01 0a 20 01 00` 75 ms after its `0x01`: a
single mesh transmission now stops advertising when its count is done, instead of staying
on air for 1000 s. Handle 2 is transmitted after the cancel of handle 1 (previously it was
reported complete without ever being sent).

### 4c. Patched, TCG + valgrind, sanitizer-free tester, no btmon — the bot's May configuration
(`run-patched-tcg-valgrind-noasan-quiet.log`) — **quoted**

    Mesh - Send                                          Passed      1.695 seconds
    Mesh - Send - too short                              Passed      0.275 seconds
    Mesh - Send - too long                               Passed      0.230 seconds
    Mesh - Send cancel - 1                               Passed      0.341 seconds
    Mesh - Send cancel - 2                               Passed      0.336 seconds
    Total: 5, Passed: 5 (100.0%), Failed: 0, Not Run: 0

The same slow configuration that failed unpatched (3c'') passes with the patch.

### 4d. Patched, mgmt-tester (full suite, KVM, ASAN tester) — regression check (`run-patched-mgmt-kvm.log`) — **quoted**

Command: `make -C cache/bluez-upstream -f build.mk run-mgmt-kvm TAG=patched-mgmt-kvm`.

    Total: 501, Passed: 501 (100.0%), Failed: 0, Not Run: 0

No case failed, timed out or was skipped; the advertising-instance bookkeeping the patch
touches (`hci_remove_adv_instance()` on the mesh-only instance, `cur_adv_instance`,
`adv_instance_expire`) does not disturb the 501 mgmt cases, which include the
Add/Remove Advertising and extended advertising suites. (The bot currently reports
`Total: 494 ... Failed: 1, Not Run: 4` for mgmt-tester since 2026-05-25 for an unrelated
reason, see Phase 1 §2.1; this build of BlueZ HEAD has 501 cases.)

### 4e. Patched, KVM + valgrind, sanitizer-free tester, full suite (`run-patched-kvm-valgrind-noasan.log`) — **quoted**

    Total: 10, Passed: 10 (100.0%), Failed: 0, Not Run: 0

## Step 5 — verdict

| configuration (same BlueZ HEAD `8b4a41760`, same guest config)         | unpatched `671d566d3c3b`            | patched `6cc1a7a507a9`      |
|---|---|---|
| KVM, ASAN tester, `-m -d` (today's bot, with trace)                     | 8/10: cancel-1 Timed out / Failed(0x01 arm), cancel-2 Timed out | **10/10** |
| KVM, ASAN tester, `-d` only                                             | 8/10: both cancel cases Timed out    | — (covered by the row above) |
| TCG, ASAN tester (bot of March/April)                                   | 8/10: both Timed out                 | — |
| TCG + valgrind, sanitizer-free tester (bot of 05-05..09-09), Send cases | 3/5: both Timed out                  | **5/5** |
| KVM + valgrind, sanitizer-free tester                                   | 8/10: both Timed out                 | **10/10** |
| mgmt-tester, KVM, ASAN tester (regression)                              | not run                              | **501/501** |

**Yes**: the patch makes both "Mesh - Send cancel" cases pass in every configuration tried,
fast (KVM) and slow (valgrind, TCG), with no mgmt-tester regression (501/501). The HCI
trace with the patch shows `LE Set Advertising Enable: Disabled (0x00)` 75 ms after the
cancel (`run-patched-kvm.log` 8000–8016), the cancelled handle's `MESH_PACKET_CMPLT`, and
the second queued packet then actually transmitted; unpatched, the kernel sends no HCI
command at all after the cancel (`run-unpatched-kvm.log` 4040–4057) — the controller is
left advertising the mesh PDU, which is the kernel bug the test has been catching since the
list check was added in June 2025.

What was not reproduced: the bot's 18 passes of 2026-05-05..05-21. On this host the
slow configuration still fails unpatched (3c''), so the bot's passing window remains
unexplained by experiment (Phase 1 §6). It has no bearing on the fix: the unpatched kernel
never stops advertising in any of the five configurations, and the patched one always does.

Deliverable for the operator (nothing has been sent anywhere):
- `tmp/mesh-tester-ci/0001-Bluetooth-MGMT-stop-advertising-when-a-mesh-transmis.patch` —
  against bluetooth-next `671d566d3c3b`, `Fixes: f3cb5676e5c1`, `Fixes: b338d91703fa`,
  `Cc: stable`, author/Signed-off-by Iaroslav Voitovych. Tested as above. Suggested
  Tested-with note for the cover text: "tools/mesh-tester 10/10 and tools/mgmt-tester
  501/501 under test-runner (KVM and TCG+valgrind), unpatched 8/10 in both."
- Review points before sending: `hci_remove_adv_instance()` is called under `hdev->lock`
  (as `hci_remove_adv_sync()` does) and silently returns `-ENOENT` if the instance was
  already gone; `mesh_tx->instance` is only set when `hci_add_adv_instance()` succeeded, so
  a transmission whose instance add failed is completed by `mesh_send_start_complete()`'s
  error path as before. Whether `MGMT_EV_ADVERTISING_REMOVED` should be emitted for the
  hidden mesh instance was deliberately not done (the instance is above `le_num_of_adv_sets`
  and invisible to Read Advertising Features).

Artifacts: `tmp/mesh-tester-ci/run-*.log` (9 runs), `bzImage-unpatched`, `build.mk`,
`qemu-tcg.sh`, `commit-msg.txt`, build logs. Trees: `cache/mesh-guest` (patched commit on
detached HEAD, worktree of `cache/linux`), `cache/bluez-upstream` (built, ASAN),
`cache/bluez-noasan` (worktree, built without sanitizers), `cache/ell`. Host Bluetooth
untouched; nothing written outside `cache/` and `tmp/mesh-tester-ci/` except the apt
packages the coordinator allowed (`libdw-dev libcups2-dev libsystemd-dev`).
