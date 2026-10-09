# `TestRunner_mesh-tester` — Phase 1 findings (read-only diagnosis)

Date of diagnosis: 2026-09-29. Trees read: `cache/linux` remote `bluetooth-next/master` at
`671d566d3c3ba4103b594b85e428bcb89a8482f5` (2026-09-23, "Merge branch 'bluetooth' into
bluetooth-next"); `cache/bluez-upstream` HEAD `8b4a4176063831476bc9244d20f43b552e4b5554`
(2026-09-23). Every claim below is marked **quoted** (command and output shown),
**inferred** (derived from quoted material, reasoning shown) or **not found**.

## 0. Verdict in five lines

1. The two cases fail because, after `MGMT_OP_MESH_SEND_CANCEL`, the kernel never sends
   `LE Set Advertising Enable (0x00)`: since kernel commit `f3cb5676e5c1` (2025-06-25,
   "Bluetooth: MGMT: mesh_send: check instances prior disabling advertising") the disable in
   `mesh_send_done_sync()` is guarded by `list_empty(&hdev->adv_instances)`, and the mesh
   packet's own advertising instance is always in that list, so the guard is never true for a
   mesh transmission. The controller is left advertising the mesh packet until the instance
   expires (1000 s). **quoted + inferred**
2. The test (`tools/mesh-tester.c`, expectation added by BlueZ `3b47cf5db`, 2022-09-27
   "tools: Fix mesh-tester to expect end of ADV") encodes the original 2022 kernel behaviour:
   cancel -> `MGMT_EV_MESH_PACKET_CMPLT(handle)` and the end of advertising. The expectation
   is legitimate; the kernel changed under it. **quoted**
3. The failure is **not** since 2026-06-01. The bot's record shows the check failing on
   every kernel patch from at least 2026-03-26 through 2026-04-30 (146 of 148 patches),
   passing from 2026-05-05 to 2026-05-21 (18 of 18), failing again from 2026-05-25 on
   (100 %). The passing window coincides exactly with the bot running the testers under
   valgrind in a TCG (non-KVM) qemu — mesh-tester took ~60 s instead of ~10-27 s. The
   outcome tracks the run's speed, not the code: the kernel and BlueZ code on the mesh
   path is identical on both sides of the 2026-05-21/25 flip. **quoted + inferred**
4. The remaining piece that reading cannot settle: the exact interleaving by which a slow
   tester made both "Send cancel" cases pass. A model consistent with the fast-run failures
   is given in §6; the slow-run passes need a run with `mesh-tester -d` and an HCI trace
   to be explained fully. **inferred / not found**
5. Fix: kernel patch to `net/bluetooth/mgmt.c` (§9) that removes the mesh advertising
   instance when the transmission is done and completes the transmission that was actually
   on air (not the queue head). No BlueZ change needed for the tester; a hardening note is
   given. Confidence in the cause (kernel leaves advertising on, test expects it stopped):
   high. Confidence that the draft patch makes the two cases pass deterministically: medium
   until Phase 2 runs it.

## 1. Pinning the flip (patchwork ids, dates, bot PRs)

Command (writes JSON under `tmp/patchwork/`):

    /root/exp/qca9377-bt-hang/scripts/patchwork-checks.sh --rate TestRunner_mesh-tester 250 2026-06-01

Output (kernel patches carrying the check, newest first; **quoted**):

    2026-05-31T18:53  14603888  fail      [v4] Bluetooth: fix memory leak in error path of hci_alloc_dev()
    2026-05-31T16:30  14603853  fail      [v2] Bluetooth: fix memory leak in error path of hci_alloc_dev()
    2026-05-29T13:12  14601083  fail      [1/1] Bluetooth: hci_codec: validate capability record length
    2026-05-29T08:54  14600598  fail      [1/1] Bluetooth: hci_sync: reject oversized Broadcast Announcement prepend
    2026-05-28T09:45  14598941  fail      [v3] Bluetooth: MGMT: validate advertising TLV before type checks
    2026-05-27T11:58  14597273  fail      Bluetooth: MGMT: Add management security level changed event
    2026-05-27T08:18  14596745  fail      [net] 6lowpan: fix off-by-one in multicast context address compression
    2026-05-26T19:48  14596093  fail      [v2] Bluetooth: hci_sync: fix UAF in hci_le_create_cis_sync
    2026-05-26T17:03  14595722  fail      [v1] Bluetooth: hci_sync: Add support for HCI_LE_Set_Host_Feature [v2]
    2026-05-26T13:50  14595156  fail      [v2,1/3] Bluetooth: hci_core: Rework hci_dev_do_reset() to use hci_sync functions
    2026-05-25T16:24  14593508  fail      Bluetooth: hci_sync: fix UAF in hci_le_create_cis_sync
    2026-05-25T12:11  14593220  fail      [v3] Bluetooth: Add Broadcom channel priority commands
    2026-05-21T08:04  14586063  success   Bluetooth: hci_conn: Fix memory leak in hci_le_big_terminate()
    2026-05-20T22:56  14585481  success   [v3] Bluetooth: HIDP: fix missing length checks in hidp_input_report()
    2026-05-20T21:41  14585274  success   [v2] Bluetooth: HIDP: fix missing length checks in hidp_input_report()
    2026-05-19T08:55  14581178  success   [v3,1/9] power: sequencing: pcie-m2: Fix inconsistent function prefixes
    2026-05-17T23:48  14577734  success   Bluetooth: HIDP: fix missing length checks in hidp_input_report()
    2026-05-16T18:15  14576557  success   [v4] Bluetooth: fix UAF in l2cap_sock_cleanup_listen() vs l2cap_conn_del()
    2026-05-16T11:14  14576398  success   [RFC,1/5] Bluetooth: af_bluetooth: Add minimal context analysis annotations
    2026-05-15T14:38  14575077  success   Bluetooth: MGMT: validate Add Extended Advertising Data length
    2026-05-14T13:42  14572936  success   [v1] Bluetooth: hci_sync: Fix not setting mask for HCI_EVT_LE_ALL_REMOTE_FEATURES_COMPLETE
    ...
    TestRunner_mesh-tester over the 250 most recent patches: fail 12   success 14   other 0

- Last pass: patch **14586063** (posted 2026-05-21T08:04, series 1098541), check recorded
  2026-05-21T12:21:41 — `grep -o '"context": *"TestRunner_mesh-tester".{0,400}' tmp/patchwork/checks-14586063.json`
  shows `"description":"TestRunner PASS"` and the neighbouring check dated
  `2026-05-21T12:21:41`. **quoted**
- First fail: patch **14593220** (posted 2026-05-25T12:11, series 1100446), check recorded
  2026-05-25T14:28:06 — same grep on `checks-14593220.json`:
  `"description":"TestRunner_mesh-tester: Total: 10, Passed: 8 (80.0%), Failed: 2, Not Run: 0"`. **quoted**
- The gap 05-21 -> 05-25 has no mesh-tester checks because the bot's `file-mapping`
  (`config.json`, §3) runs mesh-tester only for `net/bluetooth/mgmt*.c`, `hci*`, `af_bluetooth.c`
  and a few more; the patches in between were L2CAP/RFCOMM/bnep/driver-only. **quoted (config) + inferred**
- First failing comment (`curl .../patches/14593220/comments/ | grep -o 'Mesh - ...'`): **quoted**

      TestRunner_mesh-tester        FAIL      26.00 seconds
      Total: 10, Passed: 8 (80.0%), Failed: 2, Not Run: 0
      Mesh - Send cancel - 1                               Timed out    2.378 seconds
      Mesh - Send cancel - 2                               Timed out    1.987 seconds

Bot PRs (`gh api search/issues?q=repo:bluez/bluetooth-next+is:pr+created:2026-05-20..2026-05-27`): **quoted**

    237 2026-05-25T13:55:38Z closed [PW_SID:1100446] [v3] Bluetooth: Add Broadcom channel priority commands
    229 2026-05-21T10:58:17Z closed [PW_SID:1098541] Bluetooth: hci_conn: Fix memory leak in hci_le_big_terminate()

Exact kernel base of each run (head commit's parent chain; `gh api repos/bluez/bluetooth-next/commits/<sha>`): **quoted**

    PR 229 head c7a2e0b1cd57 -> parent b22743727efc "workflow/ci: Add checks:write permission..." (cd 2026-05-13T17:39:04Z)
      -> ... -> a9a4dd96b77c "Bluetooth: btusb: Add support for Intel Lizard Peak 2 (0x8087:0x0040)" (cd 2026-05-13T16:47:02Z)
    PR 237 head e677441be213 -> parent 133f77de6bca "workflow/ci: Add checks:write permission..." (cd 2026-05-21T16:53:02Z)
      -> d92080c5a723 (workflow commit, cd 2026-05-21T16:53:02Z) -> ... -> 3c2c428f25e2 "Bluetooth: btusb: Allow firmware re-download..." (cd 2026-05-21T15:23:01Z)

So the passing runs of 05-13..05-21 built on the upstream `bluetooth-next` tip of 05-13 (the
bot's `workflow` branch had not been rebased until 2026-05-21T16:53Z), the failing runs from
05-25 on the tip of 05-21. **inferred from the quoted chains**

The GitHub check run of the first failing PR (`gh api repos/bluez/bluetooth-next/commits/e677441be213.../check-runs`):
`TestRunner_mesh-tester failure 2026-05-25T14:27:14Z` with the same two "Timed out" lines;
the passing one (`.../c7a2e0b1cd57.../check-runs`): `TestRunner_mesh-tester success 2026-05-21T12:20:20Z`,
`Duration: 60.19 seconds`, no text. **quoted**

## 2. What changed between the two bases

### 2.1 Kernel (bot mirror compare, complete: 18 commits, 18 files)

    gh api repos/bluez/bluetooth-next/compare/a9a4dd96b77c...d92080c5a7233ac5bcab0417ea611b3367b97936

**quoted** (`ahead 18, behind 0`, merge_base a9a4dd96b77c):

    ffeee619a13b 2026-05-15 Bluetooth: bnep: Fix UAF read of dev->name
    085d13bf8612 2026-05-15 Bluetooth: hci_sync: Fix not setting mask for HCI_EVT_LE_ALL_REMOTE_FEATURES_COMPLETE
    663fc68494ce 2026-05-15 Bluetooth: btintel_pcie: Fix incorrect MAC access programming
    6aba94a49bc9 2026-05-15 Bluetooth: ISO: drop ISO_END frames received without prior ISO_START
    5daf96ab8398 2026-05-18 Bluetooth: btmtk: fix urb->setup_packet leak in error paths
    8f5b6b4b198e 2026-05-18 Bluetooth: MGMT: validate Add Extended Advertising Data length
    7db62a762f61 2026-05-19 Bluetooth: hci_uart: fix UAFs and race conditions in close and init paths
    0b580042a1a5 2026-05-20 Bluetooth: fix UAF in l2cap_sock_cleanup_listen() vs l2cap_conn_del()
    6dbf781d0885 2026-05-21 Bluetooth: hci_conn: Fix memory leak in hci_le_big_terminate()
    628669434306 2026-05-21 Bluetooth: L2CAP: fix chan ref leak in l2cap_chan_timeout() on !conn
    75780ca4c6a8 2026-05-21 Bluetooth: L2CAP: use chan timer to close channels in cleanup_listen()
    6522ecbcd122 2026-05-21 Bluetooth: HIDP: fix missing length checks in hidp_input_report()
    b3e1ce138148 2026-05-21 Bluetooth: btmtk: remove extra copy in cmd array init
    3c2c428f25e2 2026-05-21 Bluetooth: btusb: Allow firmware re-download when version matches
    (+ 4 workflow commits under .github/)
    files: net/bluetooth/mgmt.c +6/-0, net/bluetooth/hci_sync.c +3/-3, af_bluetooth.c, hci_conn.c,
           l2cap_*.c, hidp/core.c, iso.c, rfcomm/sock.c, sco.c, bnep/core.c, drivers/bluetooth/*

The only two touches of the mgmt/adv area (`... --jq '.files[] | select(.filename|test("hci_sync|mgmt.c"))|.patch'`): **quoted**

    mgmt.c  add_ext_adv_data(): +expected_len = struct_size(cp, data, cp->adv_data_len + cp->scan_rsp_len);
                                +if (expected_len != data_len) return mgmt_cmd_status(... MGMT_STATUS_INVALID_PARAMS);
    hci_sync.c hci_le_set_event_mask_sync(): +if (ll_ext_feature_capable(hdev)) events[5] |= BIT(2);
               hci_le_read_all_remote_features_sync(): -dead second return removed

Neither is on the mesh path. `ll_ext_feature_capable()` is false for the tester's emulated
controller: mesh-tester uses `HCIEMU_TYPE_BREDRLE` -> `BTDEV_TYPE_BREDRLE`
(`emulator/hciemu.c:419-420`), and `emulator/btdev.c:8259-8262` sets the LL Extended
Features bit only for `type >= BTDEV_TYPE_BREDRLE60`. `add_ext_adv_data` is not used by
mesh-tester (`grep -n ADD_EXT_ADV tools/mesh-tester.c` -> nothing). **quoted + inferred:
the kernel code the mesh cases exercise is identical on both sides of the flip.**

(Aside, same compare: `8f5b6b4b198e` explains why `TestRunner_mgmt-tester` flipped on the
same day — `python3` tabulation of `tmp/patchwork/checks-*.json` shows mgmt-tester
`success` through 05-21 and `TestRunner_mgmt-tester: Total: 494, Passed: 489, Failed: 1,
Not Run: 4` from 2026-05-25T14:27 on; the kernel later relaxed the check in
`149324fc762c` 2026-06-02 "MGMT: Fix backward compatibility with userspace". Not pursued.)

### 2.2 BlueZ master (bot clones `--depth=1` at run time: `entrypoint.sh clone_bluez`)

    git -C /root/exp/qca9377-bt-hang/cache/bluez-upstream log --format='%h ad=%ad cd=%cd %an %s' --date=iso --since=2026-05-18 --until=2026-05-27 HEAD

**quoted** (commits between the pass run at 05-21 12:21Z and the fail run at 05-25 14:28Z):

    b8d42b282 cd=2026-05-22 12:46 -0400 test-mesh-crypto: Don't attempt to run test if AF_ALG is not available
    f818e9d0c cd=2026-05-21 13:01 -0400 shared/bap: set QoS state when CIS is lost

Neither touches `tools/`, `emulator/`, `src/shared/tester.c`, `src/shared/mgmt.c`,
`src/shared/hci.c` or `doc/tester.config`. The tester-relevant commits nearest the window
(`git -C ... log ... -- tools/mesh-tester.c emulator/ src/shared/tester.c tools/test-runner.c doc/tester.config`) are all before the last pass: **quoted**

    0039e1bec cd=2026-05-26  emulator/btdev: Add LE Set Host Feature V2 command emulation   (after the flip; BREDRLE60-only)
    2470448ed cd=2026-05-19  tester.config: add missing CRYPTO_AES                            (in both runs)
    48cb22a57 cd=2026-05-14  doc: enable KVM paravirtualization & clock support in tester kernel config (in both)
    f1a303e1d cd=2026-05-14  emulator: btdev: clear more state on Reset                        (in both)
    e3dec62da / acd0a4950 cd=2026-05-06  tools/tester: retry with debug / fix crash when hciemu_new fails (in both)

### 2.3 The bot (`bluez/action-ci`)

    gh api "repos/bluez/action-ci/commits?since=2026-05-21T12:00:00Z&until=2026-05-26T00:00:00Z"

**quoted**:

    3dfee91519 cd=2026-05-21T18:47:24Z *.sh: Fix double quote errors from shellcheck   (entrypoint.sh, sync_repo.sh quoting only)
    0be0998f89 cd=2026-05-21T18:47:24Z all: Fix "exit" typos
    9b6d3efc84 cd=2026-05-21T18:39:48Z gitlint: ignore lines with URLs and enable regex-style-search
    f2343f58b6 cd=2026-05-21T18:35:26Z ci: use HEAD^2 in verify scripts to skip GitHub merge commit
    c1b86bca7c cd=2026-05-21T15:48:28Z ci: add verify_fixes and verify_signedoff checks for kernel patches (Dockerfile: +COPY scripts/*.sh)

None changes how the tester runs. Relevant bot facts, all **quoted** from the repo:

- `ci/testrunner.py` history: `f01e64b95f 2026-05-05 ci: run kernel testers under valgrind` ->
  `cmd = [test-runner, "-k", bzImage, "--", "valgrind", "--error-exitcode=65", tester]`;
  `c01507fbe2 2026-09-09 Use AddressSanitizer instead of Valgrind for testers` (now
  `/usr/bin/env ASAN_OPTIONS=... tester`). So valgrind ran from 05-05 to 09-09 — on both
  sides of the 05-21/25 flip.
- `action.yml` history: `835f93fdb4 2026-09-15 action: change action to pass --device /dev/kvm to docker`.
  Before that the action was a plain Docker container action (no `/dev/kvm`), and
  `tools/test-runner.c:816` uses `accel=kvm:tcg`, i.e. TCG fallback. KVM arrived four months
  after the flip.
- `Dockerfile` at the time: `FROM blueztestbot/bluez-build:latest`; Docker Hub
  (`curl https://hub.docker.com/v2/repositories/blueztestbot/bluez-build/tags/`) says
  `latest` was last pushed `2022-12-20`. Since 2026-09-09: `FROM ghcr.io/pv/bluez-ci-image:latest`.
- `config.json` `space_details.kernel.ci.TestRunner.tester-list` includes `mesh-tester`;
  `file-mapping.mgmt` = `mgmt.c, mgmt_util.c, mgmt_config.c, mgmt.h` -> `mgmt-tester, mesh-tester`;
  `hci`, `af`, `build`, `hci_vhci` -> `__all__`; `drivers/bluetooth/` -> `__none__`.
- TestRunnerSetup builds the kernel from `doc/tester.config` (`ci.py:520-523`) and BlueZ
  with `--disable-lsan` (`ci/testrunnersetup.py`).

## 3. The longer record: it was failing before, and the "pass" window is the slow window

    /root/exp/qca9377-bt-hang/scripts/patchwork-checks.sh --rate TestRunner_mesh-tester 250 2026-05-15
    /root/exp/qca9377-bt-hang/scripts/patchwork-checks.sh --rate TestRunner_mesh-tester 250 2026-04-28
    /root/exp/qca9377-bt-hang/scripts/patchwork-checks.sh --rate TestRunner_mesh-tester 250 2026-04-15

**quoted** totals and edges:

    before 05-15: fail 2  success 18   (passes 05-02 .. 05-14; fails 14548392 04-30 and 14544433 04-28)
    before 04-28: fail 57 success 1    (03-26 .. 04-23; the one pass is 14533755, 04-22)
    before 04-15: fail 89 success 0    (03-26 .. 04-14)

Signature of the April failures is the same (`curl .../patches/14533271/comments/`,
`.../14525932/comments/`): **quoted**

    TestRunner_mesh-tester        FAIL      12.18 seconds
    Mesh - Send cancel - 1                               Timed out    2.627 seconds
    Mesh - Send cancel - 2                               Timed out    1.994 seconds

Durations of the mesh-tester check by era (from the bot comments; **quoted**):

    2026-04-15  14525932  FAIL  12.19 s     (TCG, no valgrind)
    2026-04-22  14533755  PASS  26.96 s     (run where l2cap/bnep/mgmt/userchan testers FAIL in ~6.5 s — degraded run)
    2026-04-28  14544433  FAIL   9.97 s
    2026-04-30  14548392  FAIL  11.22 s
    2026-05-02  14551676  PASS  27.11 s     (same degraded pattern: other testers FAIL in ~6.6 s)
    2026-05-07  14559926  PASS  59.86 s     (valgrind from 05-05; mgmt-tester 2034 s, l2cap 378 s, iso 593 s)
    2026-05-14  14572936  PASS  59.94 s
    2026-05-21  14586063  PASS  60.19 s     (last pass)
    2026-05-25  14593220  FAIL  26.00 s     (first fail; mgmt-tester 211 s, l2cap 59 s, iso 77 s)
    2026-05-26  14596093  FAIL  25.88 s
    2026-09-24  14845586  FAIL   7.82 s     (KVM + ASAN; our own patch)

**inferred**: every run in which mesh-tester finished in <= ~26 s failed the two cases;
every run at ~60 s passed them; the two ~27 s passes were runs whose other testers crashed
early (degraded environment). The tester code, emulator and the mesh kernel path were the
same across all of these. The whole CI (all testers) became 2-10x faster between the
05-21 and 05-25 runs with no change to the action, its image or the guest kernel config;
what made the runner faster is **not found** in the repositories (GitHub-hosted runner
change is the only candidate left). It does not matter for the fix: the test outcome must
not depend on speed.

## 4. What "Mesh - Send cancel" expects

`tools/mesh-tester.c` (HEAD; **quoted**, lines 1346-1399, 1448-1456):

    static const uint8_t send_mesh_cancel_1[] = { 0x01 };
    static const uint8_t mesh_cancel_rsp_param_mesh[] = { 0x00 };
    static const struct generic_data mesh_send_mesh_cancel_1 = {
        .send_opcode = MGMT_OP_MESH_SEND_CANCEL,
        .send_param = send_mesh_cancel_1, .send_len = sizeof(send_mesh_cancel_1),
        .expect_status = MGMT_STATUS_SUCCESS,
        .expect_alt_ev = MGMT_EV_MESH_PACKET_CMPLT,
        .expect_alt_ev_param = send_mesh_cancel_1, .expect_alt_ev_len = 1,
        .expect_hci_command = BT_HCI_CMD_LE_SET_ADV_ENABLE,
        .expect_hci_param = mesh_cancel_rsp_param_mesh, .expect_hci_len = 1,
    };
    static void setup_multi_mesh_send(const void *test_data)
    {
        setup_enable_mesh(test_data);                       /* SET_POWERED, SET_LE, SET_EXP_FEATURE(mesh) */
        mgmt_send(data->mgmt, MGMT_OP_MESH_SEND, ..., send_mesh_1, NULL, NULL, NULL);   /* handle 1 */
        mgmt_send(data->mgmt, MGMT_OP_MESH_SEND, ..., send_mesh_1, NULL, NULL, NULL);   /* handle 2 */
    }
    test_bredrle("Mesh - Send cancel - 1", &mesh_send_mesh_cancel_1, setup_multi_mesh_send, test_command_generic);
    test_bredrle("Mesh - Send cancel - 2", &mesh_send_mesh_cancel_2, setup_multi_mesh_send, test_command_generic);

`send_mesh_1` (lines 1253-1263): addr type `BDADDR_LE_RANDOM`, `cnt = 0x03`,
`adv_data_len = 0x18`. `test_bredrle` = `test_full(..., timeout 2, HCIEMU_TYPE_BREDRLE ...)`
(lines 495-500) — the 2 s timer starts at test init (`src/shared/tester.c:483-486`) and
covers pre-setup, setup and run. Three conditions must all complete
(`test_command_generic`, lines 859-905): the cancel reply with status 0; the first
`MGMT_EV_MESH_PACKET_CMPLT` seen on the alternate mgmt socket, whose parameter must equal
the cancelled handle (`verify_alt_ev`, lines 736-757 — a different handle is a hard
"Failed"); and the first `LE Set Advertising Enable` the emulator sees after the hook is
installed, whose parameter must be `0x00` (`command_hci_callback`, lines 696-734 — a
`0x01` is a hard "Failed"). "Timed out" therefore means: one of the three never arrived.
**quoted + inferred**

The expectation's origin (`git -C .../bluez-upstream show 3b47cf5db`): **quoted**

    Author: Brian Gix  Date: Tue Sep 27 15:52:27 2022
    tools: Fix mesh-tester to expect end of ADV
    Tester was failing by not clearing the HCI queue of expected events
    +static const uint8_t mesh_cancel_rsp_param_mesh[] = { 0x00 };
    +	.expect_hci_command = BT_HCI_CMD_LE_SET_ADV_ENABLE,
    +	.expect_hci_param = mesh_cancel_rsp_param_mesh,   (both cancel cases)

`git -C .../bluez-upstream log -- tools/mesh-tester.c` shows no change to these
expectations since (only the 2025/2026 hciemu_new plumbing commits). **quoted**

## 5. What the kernel does now (bluetooth-next/master, `net/bluetooth/mgmt.c`)

`git -C /root/exp/qca9377-bt-hang/cache/linux grep -n -A 70 'static void mesh_send_complete' bluetooth-next/master -- net/bluetooth/mgmt.c` — **quoted**:

    1083 static void mesh_send_complete(struct hci_dev *hdev, struct mgmt_mesh_tx *mesh_tx, bool silent)
    1088 	if (!silent) mgmt_event(MGMT_EV_MESH_PACKET_CMPLT, hdev, &handle, sizeof(handle), NULL);
    1092 	mgmt_mesh_remove(mesh_tx);
    1095 static int mesh_send_done_sync(struct hci_dev *hdev, void *data)
    1099 	hci_dev_clear_flag(hdev, HCI_MESH_SENDING);
    1100 	if (list_empty(&hdev->adv_instances))
    1101 		hci_disable_advertising_sync(hdev);
    1102 	mesh_tx = mgmt_mesh_next(hdev, NULL);
    1104 	if (mesh_tx)
    1105 		mesh_send_complete(hdev, mesh_tx, false);
    1112 static void mesh_next(struct hci_dev *hdev, void *data, int err)
    1114 	struct mgmt_mesh_tx *mesh_tx = mgmt_mesh_next(hdev, NULL);
    1119 	err = hci_cmd_sync_queue(hdev, mesh_send_sync, mesh_tx, mesh_send_start_complete);
    1125 	else hci_dev_set_flag(hdev, HCI_MESH_SENDING);
    1128 static void mesh_send_done(struct work_struct *work)
    1136 	hci_cmd_sync_queue(hdev, mesh_send_done_sync, NULL, mesh_next);

`... grep -n -B 5 -A 60 'static void mesh_send_start_complete(struct hci_dev \*hdev, void \*data, int err)$' ...` — **quoted**:

    2322 	mesh_send_interval = msecs_to_jiffies((send->cnt) * 25);        /* cnt 3 -> 75 ms */
    2323 	queue_delayed_work(hdev->req_workqueue, &hdev->mesh_send_done, mesh_send_interval);
    2327 static int mesh_send_sync(struct hci_dev *hdev, void *data)
    2332 	u8 instance = hdev->le_num_of_adv_sets + 1;                       /* 6 on this emulator */
    2339 	timeout = 1000;
    2340 	duration = send->cnt * INTERVAL_TO_MS(hdev->le_adv_max_interval);
    2341 	adv = hci_add_adv_instance(hdev, instance, 0, send->adv_data_len, send->adv_data, 0, NULL,
                                       timeout, duration, ..., mesh_tx->handle);
    2350 	if (!IS_ERR(adv)) mesh_tx->instance = instance;
    2375 	if (instance) return hci_schedule_adv_instance_sync(hdev, instance, true);

`... grep -n -A 75 'static int send_cancel' ...` — **quoted** (state after `71af682ba469`, 2026-09-15):

    2435 		mesh_tx = mgmt_mesh_find(hdev, cancel->handle);
    2437 		if (mesh_tx && mesh_tx->sk == cmd->sk) {
    2438 			if (!hci_cmd_sync_dequeue(hdev, mesh_send_sync, mesh_tx, NULL))
    2440 				mesh_send_complete(hdev, mesh_tx, false);
    2444 	mgmt_cmd_complete(cmd->sk, hdev->id, MGMT_OP_MESH_SEND_CANCEL, 0, NULL, 0);
    2447 	if (!hci_dev_test_flag(hdev, HCI_MESH_SENDING))
    2448 		mesh_next(hdev, NULL, 0);

Supporting kernel facts, all **quoted** from `git grep` on the same tree:

- `mgmt_util.c:433-437 mgmt_mesh_remove()`: `list_del; sock_put; kfree` — it does not touch
  `adv_instances`. No caller removes the mesh instance (`grep -n -E '\->mesh\b|mesh_handle'`
  finds only `hci_core.c:1707-1711` setting `adv->mesh`). So instance 6 stays in
  `hdev->adv_instances` after the packet is done.
- `hci_sync.c:2082-2098 hci_schedule_adv_instance_sync()`: `timeout = adv->remaining_time`
  (1000, because `duration` 3 x 1280 ms > 1000) and
  `queue_delayed_work(... adv_instance_expire, secs_to_jiffies(timeout))` — the "ms units"
  promised by the comment in `hci_core.c:1707` were never implemented here (also absent in the
  original `b338d91703fa` hci_sync.c hunks): the mesh instance expires after **1000 seconds**.
- `hci_sync.c:2264-2277 hci_disable_advertising_sync()` returns without a command when
  `HCI_LE_ADV` is clear; `hci_sync.c:1951 hci_enable_advertising_sync()` first calls
  `hci_disable_advertising_sync()` (a `0x00` before every re-enable while advertising).
- All senders of `HCI_OP_LE_SET_ADV_ENABLE` (`grep -n HCI_OP_LE_SET_ADV_ENABLE -- net/bluetooth/`):
  `hci_sync.c:2007` (enable), `2275` (disable), `6777` (power-off path), `hci_conn.c:712`
  (directed adv). Nothing mesh-specific.

The regression commit (`git -C .../linux show f3cb5676e5c1`; first in `for-net-2025-06-27`,
`Cc: stable`): **quoted**

    Bluetooth: MGMT: mesh_send: check instances prior disabling advertising
    The unconditional call of hci_disable_advertising_sync() in mesh_send_done_sync() also
    disables other LE advertisings (non mesh related).
    I am not sure whether this call is required at all, but checking the adv_instances list
    (like done at other places) seems to solve the problem.
    Fixes: b338d91703fa ("Bluetooth: Implement support for Mesh")
    -	hci_disable_advertising_sync(hdev);
    +	if (list_empty(&hdev->adv_instances))
    +		hci_disable_advertising_sync(hdev);

The original 2022 code (`git -C .../linux show b338d91703fa:net/bluetooth/mgmt.c | grep -n -A 22 'static int mesh_send_done_sync'`): **quoted**

    hci_dev_clear_flag(hdev, HCI_MESH_SENDING);
    hci_disable_advertising_sync(hdev);
    mesh_tx = mgmt_mesh_next(hdev, NULL);
    if (mesh_tx) mesh_send_complete(hdev, mesh_tx, false);

**inferred**: with the 2022 code every mesh transmission ended with
`LE Set Advertising Enable (0x00)` 75 ms after it started — this is the "end of ADV" the
tester was fixed to expect four weeks later. Since `f3cb5676e5c1` the disable is guarded by a
condition that the mesh instance itself makes false, so after a mesh send (cancelled or
not) the controller keeps advertising the packet for 1000 s (or until the next send
rewrites instance 6). The guard was meant to protect other (bluetoothd) instances; it
should have excluded the mesh instance, not counted it.

## 6. Why the fast runs fail and (as far as reading goes) how the slow runs passed

Timeline of one cancel case, kernel side, from the quoted code (**inferred**):

    setup: SET_POWERED -> SET_LE -> SET_EXP_FEATURE(mesh) -> MESH_SEND #1 -> MESH_SEND #2
           (BlueZ src/shared/mgmt.c can_write_data(): requests are written one at a time,
            each after the previous reply)
    MESH_SEND #1 -> tx1 queued, mesh_send_sync(tx1): add instance 6, LE_SET_RANDOM_ADDR,
                    LE_SET_ADV_DATA/SCAN_RSP, LE_SET_ADV_PARAM, LE_SET_ADV_ENABLE(0x01)   = T0
                    mesh_send_start_complete -> mesh_send_done timer at T0 + 75 ms
    MESH_SEND #2 -> tx2 appended (HCI_MESH_SENDING set, nothing sent)
    run:  register MESH_PACKET_CMPLT on alt socket, install HCI hook, MESH_SEND_CANCEL(h)  = Tc

Fast run (Tc < T0 + 75 ms — the tester reaches the cancel a few main-loop iterations after
answering the 0x01; `tester_setup_complete()` schedules the run via `g_idle_add`, which
GLib runs only when no I/O source is ready):

    send_cancel(h): MESH_PACKET_CMPLT(h) -> condition met; tx(h) removed; HCI_MESH_SENDING still set
    T0+75: mesh_send_done_sync: adv_instances = {6} -> NO disable; mgmt_mesh_next() = the OTHER
           handle -> it is completed without ever being sent (second bug); mesh_next(): none left
    -> no LE_SET_ADV_ENABLE at all in the 2 s window -> "Timed out"   (matches all fast-run reports)

Slow run (Tc > T0 + 75 ms): `mesh_send_done_sync` runs first, completes tx1 (event 0x01),
`mesh_next()` starts tx2, whose `hci_enable_advertising_sync()` emits `0x00` then `0x01`,
and `hci_schedule_adv_instance_sync()` (remaining_time now 0) arms `adv_instance_expire`
with 0 s, whose `adv_timeout_expire_sync()` removes instance 6 and emits another `0x00`.
That yields the `0x00` for case 1 and, if the registration happened before the event, the
`0x01` event for case 1. It does **not** obviously yield a pass for case 2 (the first
event after registration would be handle 1, which `verify_alt_ev` rejects), yet the record
shows both cases passing in every slow run. **not found**: the ordering that lets case 2
pass. This is exactly what a Phase 2 run with `mesh-tester -d` and the in-VM `btmon` must
show; it does not change the diagnosis of the fast-run failure, which is what the bot has
reported for four months (and for March-April before the valgrind window).

Consistency checks (**quoted** data): "Mesh - Send" passes in every era — it expects
`0x01` and the handle-1 event, both produced at T0 and T0+75 regardless of speed. The bot's
failing output never shows "Failed" (parameter mismatch), only "Timed out", i.e. the missing
piece is always the `0x00`/event, never a wrong value.

## 7. Decision: what is wrong

- **Kernel** (primary): `mesh_send_done_sync()` no longer stops advertising after a mesh
  transmission because `f3cb5676e5c1` counts the mesh instance against itself; and it
  completes `mgmt_mesh_next()` (queue head) instead of the transmission that was on air,
  so after cancelling the in-flight handle the queued one is reported complete without
  being sent (present since `b338d91703fa`). Both are visible in the quoted code.
- **Test**: the expectation is the 2022 contract and is still the right behaviour (a
  mesh PDU must not stay on air for 1000 s after its count is exhausted or after cancel).
  Its only weakness is that it can be satisfied by the tx2-restart side effect in a slow
  environment, which hid the regression in the bot from 05-05 to 05-21.
- **Bot environment**: only sets the speed; no configuration, timeout or image change
  coincides with the flip (§2.3). Not the cause.

Confidence: high that the kernel leaves advertising on and that this is why the `0x00`
never comes in a fast run; medium that nothing else contributes until Phase 2 traces one
run each way.

## 8. The record

- Cached bot comments `tmp/patchwork/survey/comments-*.json` (392 files): `python3` scan of
  non-bot comments for `mesh[- ]tester|Send cancel|TestRunner_mesh` -> `0` hits. **quoted**
- `gh api search/issues?q=repo:bluez/bluez+mesh-tester` -> 68 results, none about this
  failure: `#1685 2025-11-25 open "When launching mesh-tester, the computer either reboots
  or freezes"` (bluez 5.84, no kernel version given, one maintainer question, stale),
  `#1686 mgmt-tester autotests are failing`, the rest are bot PR mirrors. **quoted**
- `gh api search/issues?q=repo:bluez/bluez+"Send cancel"` -> nothing relevant; two mesh
  issues (`#1950` 2026-03-09 100 % scan duty cycle / Command Disallowed on RPi 4,
  `#2527` 2026-09-14 random-address change in generic IO) concern bluetooth-meshd's HCI
  paths, not this mgmt path. **quoted**
- Kernel history: after `f3cb5676e5c1` the only mesh commits are `302a1f674c00`,
  `e8785404de06`, `55fb52ffdd62`, `17f89341cb42`, `bda93eec78cd`, `3c742feda8fc`
  (2026-08-06, frees the cancel command) and `71af682ba469` (2026-09-15, dequeues pending
  `mesh_send_sync` on cancel) — none touches the disable or the completed-handle choice
  (`git -C .../linux log -i --grep=mesh --since=2022-08-01 bluetooth-next/master -- net/bluetooth/mgmt.c ...`). **quoted**
- **not found**: any list thread or bot comment where a human mentions mesh-tester failing.

## 9. Draft fix (kernel) and reproduction plan

### 9.1 Kernel patch (draft, untested — Phase 2 builds and runs it)

    From: Iaroslav Voitovych <yaroslav.voytovych@gmail.com>
    Subject: [PATCH] Bluetooth: MGMT: stop advertising when a mesh transmission is done

    Since the advertising instance used for a mesh packet is itself on
    hdev->adv_instances, the list_empty() check added to mesh_send_done_sync()
    is never true for a mesh transmission and LE Set Advertising Enable (0x00)
    is never sent: the controller keeps advertising the packet until the
    instance expires 1000 seconds later, instead of stopping after the
    requested count.

    In addition, mesh_send_done_sync() completes the head of mesh_pending
    rather than the transmission that was on air, so after a Mesh Send Cancel
    of the in-flight handle the next queued packet is reported complete
    without ever being sent.

    Remove the mesh instance when the transmission is done, so the existing
    check only accounts for other instances, and complete the mesh_tx that
    owns the instance. This restores the end-of-advertising behaviour that
    tools/mesh-tester "Mesh - Send cancel" has expected since 2022.

    Fixes: f3cb5676e5c1 ("Bluetooth: MGMT: mesh_send: check instances prior disabling advertising")
    Fixes: b338d91703fa ("Bluetooth: Implement support for Mesh")
    Cc: stable@vger.kernel.org
    Signed-off-by: Iaroslav Voitovych <yaroslav.voytovych@gmail.com>
    ---
     net/bluetooth/mgmt.c | 28 ++++++++++++++++++++++++----
    diff --git a/net/bluetooth/mgmt.c b/net/bluetooth/mgmt.c
    --- a/net/bluetooth/mgmt.c
    +++ b/net/bluetooth/mgmt.c
    @@ static int mesh_send_done_sync(struct hci_dev *hdev, void *data)
     {
    -	struct mgmt_mesh_tx *mesh_tx;
    +	struct mgmt_mesh_tx *mesh_tx, *sent = NULL;
    +	u8 instance = hdev->le_num_of_adv_sets + 1;
     
     	hci_dev_clear_flag(hdev, HCI_MESH_SENDING);
    +
    +	/* The packet was advertised through the mesh-only instance; drop it
    +	 * before deciding whether advertising must stay on, otherwise it is
    +	 * what keeps adv_instances non-empty.
    +	 */
    +	hci_dev_lock(hdev);
    +	hci_remove_adv_instance(hdev, instance);
    +	hci_dev_unlock(hdev);
    +
     	if (list_empty(&hdev->adv_instances))
     		hci_disable_advertising_sync(hdev);
    -	mesh_tx = mgmt_mesh_next(hdev, NULL);
     
    -	if (mesh_tx)
    -		mesh_send_complete(hdev, mesh_tx, false);
    +	/* Complete the transmission that was on air, not the queue head: after
    +	 * a Mesh Send Cancel of the in-flight handle the head is the next,
    +	 * still unsent, packet.
    +	 */
    +	list_for_each_entry(mesh_tx, &hdev->mesh_pending, list) {
    +		if (mesh_tx->instance == instance) {
    +			sent = mesh_tx;
    +			break;
    +		}
    +	}
    +
    +	if (sent)
    +		mesh_send_complete(hdev, sent, false);
     
     	return 0;
     }

Notes for Phase 2 review (**inferred** from the quoted code): `hci_remove_adv_instance()`
(`hci_core.c:1598-1624`) clears `cur_adv_instance` and the bogus 1000 s
`adv_instance_expire` when removing the current instance, and is called under
`hdev->lock` elsewhere (`hci_remove_adv_sync`); `mesh_tx->instance` is set in
`mesh_send_sync()` only when the add succeeded (`mgmt.c:2350`), so unsent entries have
`instance == 0`. With the patch, "Send cancel - 1" gives: cancel -> event(1); at +75 ms
instance removed -> `0x00`; no owner found -> nothing completed; `mesh_next()` -> tx2 sent
(`0x01`), done at +150 ms -> `0x00`, event(2). "Send cancel - 2": cancel -> event(2); +75 ms
-> `0x00`, event(1). Both independent of tester speed. `bluetooth-meshd`
(`mesh/mesh-io-mgmt.c:353, 498`) only consumes `MESH_PACKET_CMPLT` per handle and cancels
the last handle before a new send; it is unaffected by the change of which handle is
reported when, beyond receiving the correct one.

Alternative considered (**inferred**): changing the tester to accept "no end of ADV" would
codify the regression and make "Mesh - Send" leave the emulated controller advertising —
rejected. A tester hardening worth doing regardless: the 2 s per-test timer starts at
init (`tester.c:483-486`) and includes pre-setup/setup; a 4 s `test_bredrle_full` for the
two-send cases would remove one speed dependence. Optional.

### 9.2 Reproduction plan (Phase 2, needs operator approval)

Nothing touches the host Bluetooth stack: everything runs inside qemu on a freshly built
guest kernel and the BlueZ testers from the source tree (no install).

1. Build the testers: `cache/bluez-upstream` has no `configure` yet (`ls .../configure` ->
   no such file). `./bootstrap-configure --disable-lsan` then `make tools/test-runner
   tools/mesh-tester` (autotools, ell not needed for these targets). Cost: ~5-10 min on 16
   CPUs; writes only inside `cache/bluez-upstream`.
2. Build the guest kernel: `cache/linux` is blobless with `028ef9c96e96` (7.0) checked out;
   use worktree `cache/linux-bt-next` (`c9c15d4d8956`, bluetooth-next tip of 2026-09-23) or
   `git -C cache/linux worktree add cache/mesh-tester-ci/linux bluetooth-next/master`
   (blob fetch of a full tree: ~1-2 GB network), `make O=... KCONFIG_ALLCONFIG=.../doc/tester.config
   allnoconfig` (or `olddefconfig` on a copy of `tester.config`, as the bot's BuildKernel
   does) and `make O=... bzImage -j16`. Cost: 10-25 min; ~2 GB disk under `cache/`.
3. Run unpatched, fast: `tools/test-runner -k <bzImage> -- tools/mesh-tester -d` (host has
   `/dev/kvm`, so `accel=kvm`), plus a second run with `--monitor`/`btmon` inside the VM if
   `test-runner -m` is available (`tools/test-runner.c` options to be checked). Expected: the
   two cases "Timed out"; the trace shows `LE Set Advertising Enable 0x01` for tx1 and no
   `0x00` after the cancel; `mesh_send_done` completes the other handle. This fixes claim 1.
4. Run unpatched, slow: same under `-- valgrind tools/mesh-tester -d`, and with
   `-H/--qemu-host-cpu` off or `accel=tcg` forced if the option exists. Expected: passes, and
   the trace shows the tx2 restart producing `0x00`. This resolves the §6 open point.
5. Apply the §9.1 patch to the worktree, rebuild `bzImage` (incremental, ~2 min), repeat
   step 3 fast and slow. Expected: 10/10 in both; trace shows `0x00` 75 ms after each
   transmission and the correct handle in each `MESH_PACKET_CMPLT`.
6. Run the full `tools/mgmt-tester` once on the patched kernel to check the advertising
   instance bookkeeping did not regress (mgmt-tester takes ~1-4 min under KVM).
7. Only then: the patch and the tester note go to the operator for sending; nothing is
   posted from here.

Total cost: ~1 h wall clock, ~3 GB under `cache/`, no reboot, no host adapter use.

## 10. Evidence files

- `tmp/patchwork/patches.json`, `tmp/patchwork/checks-*.json` — raw patchwork data from the
  four `--rate` runs (before 2026-06-01, 05-15, 04-28, 04-15).
- `tmp/patchwork/comments-*.json`, `tmp/patchwork/patch-14845586-comments.json` — bot
  comments (the ones quoted above were fetched ad hoc with `curl` and grep; re-fetch with
  `scripts/patchwork-checks.sh --patch ID` for the checks or the URL shown).
- This file. No other files were written.
