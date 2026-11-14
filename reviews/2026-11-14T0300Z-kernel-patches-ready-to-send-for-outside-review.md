# Linux kernel Bluetooth patches ready to send: a self-contained review document

*Prepared 2026-11-14 by the project <https://github.com/ivoitovych/qca9377-bt-hang> (fixes for
the Linux Bluetooth stack found on a laptop with a QCA9377 controller, USB `13d3:3503`). Nothing
in this document has been sent. Every patch is reproduced verbatim from the file named above it,
with that file's SHA-256, so the text you review is the text that would be mailed. Most items carry
no Signed-off-by yet: the author adds it when sending. Items 4 to 7 were prepared earlier and
already carry it; please ignore that line.*

## A. What we ask of you

You are reviewing as a kernel maintainer would, before the patches reach the list. For each item:

1. **Is the change correct?** Locking, reference counting, error paths, races with teardown
   (device removal, power-off, unregister), and behaviour on other devices than ours.
2. **Is the commit message accurate?** Every claim about the code should hold at the stated base.
   Point at any sentence that overstates what was shown, and at any missing `Fixes:` or a wrong one.
3. **Is the form right for the target tree?** Subject prefix and length, trailers, `Cc: stable`
   (where we ask you to weigh it), the text below `---`, the recipients.
4. **Is anything missing that a maintainer will ask for?** A test, a measurement, a split or a
   merge of patches, a different approach.
5. **Should any of them not be sent?** Say so plainly, with the reason.

Please answer per item, by its number below, and quote the line you mean. A short "no
objection" for an item is a useful answer too.

## B. How the patches were tested

No patch here has been run on the laptop's own controller (the laptop is in daily use, and a
dead controller there needs a power-off). Everything was tested in QEMU guests and containers:

- **The bot's checks, locally.** The linux-bluetooth list runs a CI bot on every posting
  (`github.com/bluez/action-ci`). Its own check code was run here in its own container, on the
  base tree and on base plus the patch, and only the difference was judged. A missing
  Signed-off-by fails three of its checks (CheckPatch, VerifySignedoff, GitLint); that is the
  line the author adds.
- **BlueZ's testers** (`mgmt-tester`, `l2cap-tester`, `smp-tester`, `mesh-tester`, `sco-tester`)
  in QEMU guests built from BlueZ's `doc/tester.config`, on the base and the patched kernel.
- **For btusb:** real btusb in a guest, driven by an emulated `13d3:3503` through usbip
  (`vhci_hcd`), with KASAN, lockdep and kmemleak; for races, 4-CPU guests.

Each item says which of these it had, and where the logs are in the repository.

## C. Contents

| # | item | target | patches |
|---|---|---|---|
| 1 | CO-44: a timed-out MGMT command reported as Authentication Failed | bluetooth-next | 1 (+ its BlueZ test) |
| 2 | CO-43 E: btusb anchors a deferred URB outside `txlock` | bluetooth-next | 1 |
| 3 | CO-43 A: btusb's runtime-resume waker swallows a failed resume | bluetooth-next | 1 |
| 4 | CO-38: Read Advertising Features hides instances | bluetooth-next | 1 (+ BlueZ tests) |
| 5 | CO-04: a use-after-free in `mesh_send_sync()` | bluetooth-next | 1 |
| 6 | CO-05 + CO-26: `mesh_send_sync()` without `hdev->lock`, and a lost failed add | bluetooth-next | 2 + cover letter |
| 7 | CO-35: the L2CAP ECRED deferred-accept hang, backported to stable (retested 2026-11-14) | 6.18.y, 6.12.y, 6.6.y (and a request for 7.3.y) | 2 per line + covers |
| 8 | CO-22: two ASUS QCA ROME device-table entries for stable (rechecked 2026-11-14) | stable (request only) | — |
| 9 | CO-21: btusb picks alternate setting 0 while a SCO link is up (added 2026-11-14) | bluetooth-next | 2 + cover letter |
| 10 | CO-20: btusb logs the data of a just-closed SCO link as corruption (added 2026-11-14) | bluetooth-next | 2 + cover letter |
| 11 | CO-43, the rest: btusb when a resume fails (for review; not yet to send) | bluetooth-next, on top of item 2 | 4 shown + cover letter |

Items 1 to 10 are ready to send. Item 11 is complete and tested in emulation, but one of its
paths can only be argued from the source, so it is here for review before anyone sends it.

**Not included:** CO-02's SCO series is already on the list (2026-10-27); its v2 is built and one
test result is still being explained. CO-12's advertising-duration clamp waits on a design
decision and on another author's overlapping patch.

---

## 1. CO-44 — MGMT: a timed-out command reported as Authentication Failed

**The defect.** When an HCI command sent from an MGMT handler gets no answer, the sync layer
returns `-ETIMEDOUT`, and `mgmt_errno_status()` has no case for it, so user space is told
`MGMT_STATUS_AUTH_FAILED` (0x05). bluetoothd then prints "Authentication Failed" for a Set
Device Class or a Set Powered that simply timed out; users and maintainers read it as a pairing
problem. The table for HCI statuses already maps the controller's own timeouts (0x08, 0x10) to
`MGMT_STATUS_TIMEOUT`, and a timed-out pairing connection already reports 0x08; the patch makes
`-ETIMEDOUT` agree. `Fixes: 161510ccf91c`.

**Tested** (bluetooth-next `da3cc02587c6`, BlueZ master): a new mgmt-tester case drops the Write
Class of Device command and expects Timeout; on the base kernel it gets 0x05 and fails, patched it
passes. Full mgmt-tester 526 + the new case: only that case changes; l2cap-tester 144/144 and
smp-tester 8/8 on both kernels. The bot's checks locally: only the three Signed-off-by checks
differ. The BlueZ test is a separate mail to BlueZ the same day; it is reproduced after the kernel
patch for context.

**Questions for you.** `Cc: stable` or not (the maintainer took two MGMT status fixes with it in
the last months; the last two changes to this function went in without it). Whether the `Link:`
to a 2022 BlueZ posting that names the symptom is useful or noise. Subject wording.

**`contributions/CO-44-mgmt-timeout-reported-as-auth-failed/send-20261113/kernel/0001-Bluetooth-MGMT-Report-a-timed-out-command-as-MGMT_ST.patch`** (SHA-256 `8a265e321fc37c1a8b3f434764826ec0ca933968a59b0dd57aacaf51c7686fd9`)

```diff
From b7df6ff0a81755c09edcf5e5751bf1edc409b257 Mon Sep 17 00:00:00 2001
From: Iaroslav Voitovych <yaroslav.voytovych@gmail.com>
Date: Fri, 13 Nov 2026 04:19:58 +0100
Subject: [PATCH] Bluetooth: MGMT: Report a timed out command as
 MGMT_STATUS_TIMEOUT

mgmt_errno_status() maps -ETIMEDOUT to MGMT_STATUS_AUTH_FAILED. The
sync command path returns -ETIMEDOUT when the controller does not
answer a command in time, and for the two HCI statuses that
bt_to_errno() maps to ETIMEDOUT, Connection Timeout (0x08) and Host
Timeout (0x10). None of these is an authentication failure, and
mgmt_status_table[] maps both HCI statuses to MGMT_STATUS_TIMEOUT.

So when the controller stops answering, commands such as Set Powered,
Add UUID, Remove UUID or Set Device Class fail with Authentication
Failed although no authentication took place. With a Write Class of
Device timing out during Remove UUID, btmon showed "Remove UUID
(0x0011) ... Status: Authentication Failed (0x05)" and bluetoothd
logged "Failed to remove UUID: Authentication Failed (0x05)", which
points at pairing and keys instead of at the controller.

A timed out LE connection attempt is already reported as
MGMT_STATUS_TIMEOUT: create_le_conn_complete() calls
hci_conn_failed(conn, bt_status(err)), bt_status(-ETIMEDOUT) is 0x08,
and mgmt_status_table[] maps 0x08 to MGMT_STATUS_TIMEOUT.

Map -ETIMEDOUT to MGMT_STATUS_TIMEOUT in mgmt_errno_status().

Fixes: 161510ccf91c ("Bluetooth: hci_sync: Make use of hci_cmd_sync_queue set 1")
Link: https://lore.kernel.org/linux-bluetooth/20220823121541.Bluez.v2.1.I541cbea9d6295f531c796bf3bda96b22db76bc19@changeid/
---
User-visible change: an MGMT command that fails with -ETIMEDOUT now
completes with Timeout (0x08) instead of Authentication Failed (0x05).
In BlueZ only the text changes for these commands: bluetoothd and
btmgmt print the status with mgmt_errstr(), and bluetoothd's D-Bus
error for a failed mode change stays org.bluez.Error.Failed. Pairing
results take HCI statuses through mgmt_status_table[] and are
unchanged.

A command that gets no answer has no entry in mgmt_status_table[]: it
reaches mgmt_errno_status() directly as -ETIMEDOUT. This change makes
that outcome agree with the table's entries for HCI 0x08 and 0x10.
161510ccf91c gives no reason for the old value; if it was deliberate,
please say.

The mgmt-tester case is sent to BlueZ separately as "mgmt-tester: Add
Set Device Class timeout test". Its emulated controller drops Write
Class of Device.

With BlueZ's doc/tester.config, on bluetooth-next da3cc02587c6 and
BlueZ master plus that case, in QEMU:
  mgmt-tester:  526 of 527 pass without this patch (the new case gets
                Authentication Failed (0x05)), 527 of 527 with it
  l2cap-tester: 144 of 144 pass, with and without
  smp-tester:   8 of 8 pass, with and without
One other case sees the new status: in "Get Conn Info - Power off" a
Read RSSI times out during the power off, and the reply carries 0x08
instead of 0x05. That case is fail_tolerant and passes either way.

Not marked for stable, since the status is visible to user space; a
backport is left to your judgment.

 net/bluetooth/mgmt.c | 2 +-
 1 file changed, 1 insertion(+), 1 deletion(-)

diff --git a/net/bluetooth/mgmt.c b/net/bluetooth/mgmt.c
index 6ed3bf6f17..0056e34842 100644
--- a/net/bluetooth/mgmt.c
+++ b/net/bluetooth/mgmt.c
@@ -295,7 +295,7 @@ static u8 mgmt_errno_status(int err)
 	case -EBUSY:
 		return MGMT_STATUS_BUSY;
 	case -ETIMEDOUT:
-		return MGMT_STATUS_AUTH_FAILED;
+		return MGMT_STATUS_TIMEOUT;
 	case -ENOMEM:
 		return MGMT_STATUS_NO_RESOURCES;
 	case -EISCONN:

base-commit: da3cc02587c629420603df4395179ec82955c941
-- 
2.43.0

```

**`contributions/CO-44-mgmt-timeout-reported-as-auth-failed/send-20261113/cc-stable-variant.txt`** (SHA-256 `33b33f7730bd7028760d669bfb559cac052fc039673c86289906748711ee86e2`)

```text
Cc: stable variant of kernel/0001-Bluetooth-MGMT-Report-a-timed-out-command-as-MGMT_ST.patch
==========================================================================================

The patch as packaged carries no Cc: stable. If you decide for it, make two edits in the patch
file, nothing else:

1. Add this one line directly under the Fixes: line (above Link:):

Cc: stable@vger.kernel.org

   The trailers then read:

Fixes: 161510ccf91c ("Bluetooth: hci_sync: Make use of hci_cmd_sync_queue set 1")
Cc: stable@vger.kernel.org
Link: https://lore.kernel.org/linux-bluetooth/20220823121541.Bluez.v2.1.I541cbea9d6295f531c796bf3bda96b22db76bc19@changeid/
Signed-off-by: <your name and address>

2. Below the '---' line, delete the last paragraph (it says the opposite):

Not marked for stable, since the status is visible to user space; a
backport is left to your judgment.

git send-email turns the trailer into a Cc to stable@vger.kernel.org (the dry run in
send-commands.txt, variant B, shows it as an extra RCPT TO). Do not send to the stable list
separately.

For and against, with the precedents: NOTES-FOR-OPERATOR.md, "Cc: stable".
```

**`contributions/CO-44-mgmt-timeout-reported-as-auth-failed/send-20261113/bluez/0001-mgmt-tester-Add-Set-Device-Class-timeout-test.patch`** (SHA-256 `f50518d35c97bc73a1c88cf422a69e7fc84c87ae25b64ad6f5b2aa66cd6f5956`)

```diff
From 0e5d0c431cb113015ac6f5d8349f0190c729c576 Mon Sep 17 00:00:00 2001
From: Iaroslav Voitovych <yaroslav.voytovych@gmail.com>
Date: Fri, 13 Nov 2026 05:07:23 +0100
Subject: [PATCH BlueZ] mgmt-tester: Add Set Device Class timeout test

The emulated controller drops Write Class of Device, so the kernel's
HCI command times out and Set Device Class shall complete with Timeout
(0x08). The hook completes a test condition, so the test cannot pass
unless the command was sent and dropped.

Without the kernel fix "Bluetooth: MGMT: Report a timed out command as
MGMT_STATUS_TIMEOUT" the command completes with Authentication Failed
(0x05), which is what mgmt_errno_status() returns for -ETIMEDOUT.
---
This test needs the kernel fix named above, which is sent to
linux-bluetooth separately:
@KERNEL_PATCH_LINK@

Without it the new case fails with "Unexpected status got
Authentication Failed (0x05) expected Timeout (0x08)"; with it the
case passes and the rest of mgmt-tester is unchanged.

 tools/mgmt-tester.c | 40 ++++++++++++++++++++++++++++++++++++++++
 1 file changed, 40 insertions(+)

diff --git a/tools/mgmt-tester.c b/tools/mgmt-tester.c
index b7126dc36..42e2a6837 100644
--- a/tools/mgmt-tester.c
+++ b/tools/mgmt-tester.c
@@ -2493,6 +2493,16 @@ static const struct generic_data set_dev_class_invalid_param_test_1 = {
 	.expect_status = MGMT_STATUS_INVALID_PARAMS,
 };
 
+static const struct generic_data set_dev_class_timeout_test_1 = {
+	.setup_settings = settings_powered,
+	.send_opcode = MGMT_OP_SET_DEV_CLASS,
+	.send_param = set_dev_class_valid_param,
+	.send_len = sizeof(set_dev_class_valid_param),
+	.expect_status = MGMT_STATUS_TIMEOUT,
+	.expect_param = set_dev_class_zero_rsp,
+	.expect_len = sizeof(set_dev_class_zero_rsp),
+};
+
 static const char add_spp_uuid_param[] = {
 			0xfb, 0x34, 0x9b, 0x5f, 0x80, 0x00, 0x00, 0x80,
 			0x00, 0x10, 0x00, 0x00, 0x01, 0x11, 0x00, 0x00,
@@ -12703,6 +12713,33 @@ static bool hook_delay_cmd(const void *data, uint16_t len, void *user_data)
 	return true;
 }
 
+static bool hook_drop_cmd(const void *data, uint16_t len, void *user_data)
+{
+	struct test_data *test_data = user_data;
+
+	tester_print("Dropping HCI command, no response from emulator");
+	test_condition_complete(test_data);
+
+	return false;
+}
+
+static void test_set_dev_class_timeout(const void *test_data)
+{
+	struct test_data *data = tester_get_data();
+
+	/* The controller never answers Write Class of Device, so the
+	 * kernel's HCI command times out and the MGMT command shall
+	 * complete with Timeout rather than Authentication Failed.
+	 * The condition makes sure the command was actually dropped.
+	 */
+	test_add_condition(data);
+	hciemu_add_hook(data->hciemu, HCIEMU_HOOK_PRE_CMD,
+					BT_HCI_CMD_WRITE_CLASS_OF_DEV,
+					hook_drop_cmd, data);
+
+	test_command_generic(test_data);
+}
+
 static void test_add_remove_device_nowait(const void *test_data)
 {
 	struct test_data *data = tester_get_data();
@@ -14926,6 +14963,9 @@ int main(int argc, char *argv[])
 	test_bredrle("Set Device Class - Invalid parameters 1",
 				&set_dev_class_invalid_param_test_1,
 				NULL, test_command_generic);
+	test_bredrle_full("Set Device Class - Timeout 1",
+				&set_dev_class_timeout_test_1,
+				NULL, test_set_dev_class_timeout, 5);
 
 	test_bredrle("Add UUID - UUID-16 1",
 				&add_uuid16_test_1,

base-commit: 20ffd285b58facfd1f2478d159a5f941b09d5be1
-- 
2.43.0

```

**`contributions/CO-44-mgmt-timeout-reported-as-auth-failed/send-20261113/CHECKS.md`** (SHA-256 `554e797b6936983c45642e77523c1119ae06d7f3310e4c0537cca0b282da1d1f`)

````markdown
# CO-44 send package: every check, its command and its result (2026-11-13)

Work directory `W=/root/exp/agent-work/co44-send-20261113`. Scripts in `$W/scripts/`, logs in
`$W/logs/`. Nothing was sent, posted or mailed.

## Tips used

| tree | tip | source |
|---|---|---|
| bluetooth-next `master` | `da3cc02587c629420603df4395179ec82955c941` "Bluetooth: hci_vhci: Report write readiness with queued input" (2026-11-12) | `git ls-remote` of git.kernel.org; objects from the GitHub mirror `bluez/bluetooth-next`, same id |
| bluetooth `master` | `3b069de8a5d688c7e8381b99d6cdb7467fcae0de` "Bluetooth: L2CAP: Fix size check for receive buffer space" (2026-11-12) | git.kernel.org, fetched |
| BlueZ `master` | `20ffd285b58facfd1f2478d159a5f941b09d5be1` "shared/gatt-client: Track pending discovery Database Hash reads" (2026-11-12) | git.kernel.org, fetched |
| ELL `master` | `002b32d7c091993c5036956bf92d2444aca1c799` "Release 0.83" | fetched |
| bot image | `bluez-action-ci:c7d077f185cd` (bluez/action-ci `main` `c7d077f185cd`, new on 2026-11-12; base `ghcr.io/pv/bluez-ci-image@sha256:8d31a3fc…`) | fetched |

Fetched 2026-11-13 18:57–19:09 UTC (`logs/kernel-tips.txt`, `logs/bluez-tips.txt`). Both
bluetooth-next and BlueZ master are the same commits the dossier tested on; bluetooth `master`
moved since the project's cache (`11701044c532`, 2026-10-30).

A full clone of bluetooth-next from git.kernel.org was reset mid-transfer ("RPC failed; curl 56
Recv failure: Connection reset by peer"), so the local tree is a treeless clone of the GitHub
mirror (history since 2021-06-01, so `161510ccf91c` resolves), with the tip id checked against
kernel.org's `ls-remote`.

## Kernel patch

**Commits:** `b7df6ff0a817` on bluetooth-next `da3cc0258`; the mail is `git format-patch -1
--base=da3cc0258`, with the below-`---` text put in by `scripts/insert-below-line.py`.

| check | command | result |
|---|---|---|
| applies to bluetooth-next | `git am` on `da3cc0258` (`scripts/kernel-prepare.sh`, `logs/kernel-prepare.txt`) | applied, `net/bluetooth/mgmt.c | 2 +-` |
| applies to bluetooth | `git am package/kernel/0001-…patch` on `3b069de8a5d6` (worktree `$W/linux-bt`) | applied; result `856cc4c0b7c6`; the same line 297 in both trees; `git log -1 --format=%B` shows the message ends at `Link:` (the note below `---` is dropped) |
| the cited code is the same in both trees | `git grep` of `create_le_conn_complete`, `hci_conn_failed(conn, bt_status(err))`, the table's Connection/Host Timeout entries, `lib.c`'s `ETIMEDOUT` cases | identical: `bt_to_errno()` returns `ETIMEDOUT` only for 0x08 and 0x10; `bt_status(-ETIMEDOUT)` is 0x08 |
| checkpatch `--strict` | `scripts/kernel-tree-checks.sh` → `scripts/checkpatch.pl --strict` from inside the tree at `b7df6ff0a817` | `ERROR: Missing Signed-off-by: line(s)`, `total: 1 errors, 0 warnings, 0 checks` (`logs/final-kernel-checkpatch.txt`). No "Unknown commit id": the `Fixes:` commit resolves |
| checkpatch control | the same on a local copy with a Signed-off-by line added (`controls/kernel-with-sob-local-check-only.patch`, never to be sent) | `total: 0 errors, 0 warnings, 0 checks` … "no obvious style problems" |
| recipients | `scripts/get_maintainer.pl` on the packaged mail | Marcel Holtmann, Luiz Augusto von Dentz (maintainers; both `blamed_fixes`), linux-bluetooth, linux-kernel (`recipients-kernel.txt`) |
| `Link:` target exists | lore web answers 403 here (`curl … /raw` → `403`); lore's git archive (`git grep … e9acdab51 -- m`: Message-Id, subject, "returns Authentication Failed because disconnection takes too long."); patchwork API `?msgid=…` | patchwork `12951690`, "[Bluez,v2] adapter: Reset pending settings when receiving MGMT error", accepted, BlueZ `ede7b915980f` (`logs/link-check-patchwork-12951690.json`) |
| Fixes: target | `git log -1 161510ccf91c` | "Bluetooth: hci_sync: Make use of hci_cmd_sync_queue set 1", Luiz Augusto von Dentz, 2021-10-27 — the subject in the tag is exact |

### Testers in QEMU (BlueZ `doc/tester.config` kernels)

Built by `scripts/build-kernels.sh` with BlueZ master's `doc/tester.config` + `olddefconfig`:
base `da3cc02587c6` (`bzImage-base`, sha256 `bd38430d…`), patched `b7df6ff0a817`
(`bzImage-patched`, sha256 `c5ea91ce…`); no warning in either build log. BlueZ: master + the
new test (`co44-test`, `0e5d0c431cb1`), `./bootstrap-configure --disable-lsan`, no warning.
Run by `scripts/run-testers.sh` through `tools/test-runner`; judged by the project's
`compare-tester-verdicts.py` and `kernel-report-scan.py` (`logs/testers-analysis.txt`, with
every log's SHA-256).

| tester | base | patched | difference |
|---|---|---|---|
| mgmt-tester (527) | 526 passed, 1 failed | 527 passed | only "Set Device Class - Timeout 1": Failed → Passed |
| l2cap-tester (144) | 144 passed | 144 passed | none |
| smp-tester (8) | 8 passed | 8 passed | none |
| kernel reports (13 kinds) | clean, `7.3.0-gda3cc02587c6` | clean, `7.3.0-gb7df6ff0a817` | — |

- **The new case, base:** "Dropping HCI command" → `Opcode 0x0c24 failed: -110` → "Unexpected
  status got Authentication Failed (0x05) expected Timeout (0x08)" → test failed (2.050 s).
- **Patched:** the same drop and timeout → "Set Dev Class (0x000e): Timeout (0x08)" → "Test
  condition complete, 0 left" → test passed (2.032 s). The hook fired once in the whole run.
- **"Get Conn Info - Power off"** (`fail_tolerant = true`): Read RSSI `0x1405` times out;
  "Unexpected status got 5 expected 15" on base, "got 8 expected 15" patched; passed on both.
- "Unexpected status got 15 expected 14" (another case) is in both logs at the same line: not
  ours, unchanged.

## BlueZ test

**Commit** `0e5d0c431cb1` on master `20ffd285b`; mail `git format-patch -1 --subject-prefix="PATCH
BlueZ" --base=origin/master`, the below-`---` text put in by `scripts/insert-below-line.py`.

- **Reviewer 2's point, done in the neighbours' style:** the test adds a condition before
  registering the hook, and the hook completes it (as `test_adv_enable_hook()` does), so the test
  cannot pass unless Write Class of Device was sent and dropped.
- **Negative control** (`scripts/control-no-condition.sh`, `controls/control-no-condition.txt`):
  a scratch build whose hook drops the command but does not complete the condition, full
  mgmt-tester on the patched kernel: "Set Device Class - Timeout 1" **Timed out** (527 cases,
  526 passed), every other verdict as in the real run. Source restored and rebuilt afterwards;
  `git status` clean.
- **Base and patched kernels:** the tester table above (the same runs).

## The list's CI bot, run locally on the kernel mail

`scripts/bot-ci-local.sh` (from a clone of the project in `$W/project`, `--cache $W/cache`), image
`bluez-action-ci:c7d077f185cd`, base `da3cc02587c6`, BlueZ `20ffd285b`, ELL `002b32d7`,
`--history-since 2021-06-01` for VerifyFixes. Wrappers `scripts/bot-kernel.sh` and
`scripts/bot-kernel-base.sh`; outputs in `$W/project/tmp/bot-ci-local/co44-kernel-send-20261113/`
(patched) and `…-base/` (base). Their `work/` trees were deleted once the summaries and reports
existed.

| check | base | patched | reason for a non-pass |
|---|---|---|---|
| CheckPatch | — | FAIL | `ERROR: Missing Signed-off-by: line(s)` only (0 warnings, 0 checks) |
| VerifyFixes | — | PASS | (the dossier's run had "empty lines surround the Fixes tag"; the `Link:` line now follows `Fixes:`) |
| VerifySignedoff | — | FAIL | "author Signed-off-by missing / committer Signed-off-by missing" only |
| GitLint | — | FAIL | `CC1 Body does not contain a 'Signed-off-by' line` only |
| SubjectPrefix | — | PASS | |
| BuildKernel, CheckAllWarning, CheckSparse, BuildKernel32, CheckKernelLLVM | PASS | PASS | |
| TestRunnerSetup | PASS | PASS | |
| TestRunner_mgmt-tester (BlueZ master, 526 cases, without our new case) | PASS, 526/526 | PASS, 526/526 | `compare-tester-verdicts.py`: 0 cases differ, not-passed sets identical |
| TestRunner_mesh-tester (10) | PASS, 10/10 | PASS, 10/10 | identical (the dossier's run had one unrelated base-side mesh failure; not today) |
| IncrementalBuild | — | PASS | |
| kernel-report-scan of the four TestRunner logs | clean | clean | |

**The difference:** only the three Signed-off-by checks, all from the line you add; the control
in the kernel table shows checkpatch clean once it is there.

**One run problem, not the patch's:** the first run's base workspace failed ("could not fetch
1e14f023db71… from promisor remote"): the bot's `--shared` clone of my treeless kernel clone
lacked objects. The base side was rerun alone (`--side base`) with the patched side's own complete
bluetooth-next clone as `--tree`, same base commit; the comparison above is between those two runs
(`…-base/compare-split-run.txt`, `scripts/compare-bot-kernel.sh`).

## The list's CI bot, run locally on the BlueZ mail

`scripts/bot-ci-local.sh --space user` (wrapper `scripts/bot-bluez.sh`), image
`bluez-action-ci:c7d077f185cd`, base BlueZ `20ffd285b`, ELL `002b32d7`, TestFunctional booting
the patched tester.config kernel (`b7df6ff0a817`). Output
`$W/project/tmp/bot-ci-local/co44-bluez-send-20261113/`; `work/` deleted afterwards.

| check | base | patched |
|---|---|---|
| CheckPatch | — | PASS (no "Unknown commit id": the message names the kernel fix by subject, not by id) |
| GitLint | — | PASS |
| BuildEll, BluezMake, CheckSmatch, bluezmakeextell, TestFunctional, ScanBuild | PASS | PASS |
| IncrementalBuild | — | PASS |

0 not PASS on either side. The bot's user-space checks do not run mgmt-tester; the new case's
own runs are the tester table above. (ScanBuild, per the script's header, compares the patched
tree with itself.)

## The checked mails

Every check above ran on these exact files (the bot runs on byte-identical copies in
`$W/project/tmp/co44-mails/`):

```
8a265e321fc37c1a8b3f434764826ec0ca933968a59b0dd57aacaf51c7686fd9  kernel/0001-Bluetooth-MGMT-Report-a-timed-out-command-as-MGMT_ST.patch
f50518d35c97bc73a1c88cf422a69e7fc84c87ae25b64ad6f5b2aa66cd6f5956  bluez/0001-mgmt-tester-Add-Set-Device-Class-timeout-test.patch
```

Adding your Signed-off-by (kernel) and the lore link (BlueZ) changes them; nothing else may.
A wording scan of both mails (`grep -i` for internal and private wording) found nothing.

## Dry runs of git send-email (2026-11-14)

Run from the project checkout with `dry-run-20261114/run.sh`, which applies the commands of
`send-commands.txt` with `--dry-run --confirm=never`. Four forms, four `Result: OK`
(`dry-run-20261114/dry-run-co44-*.txt`); the RCPT TO lines match `send-commands.txt`.
````

---

## 2. CO-43 E — btusb: anchor a deferred URB under `txlock`

**The defect** (present since `7bee549e197c`, 2009). `submit_or_queue_tx_urb()` decides under
`data->txlock` that the device is suspending and the URB must be deferred, drops the lock, and only
then anchors the URB on `data->deferred`. A resume that runs `play_deferred()` in that window
does not see it: the URB stays parked until the next suspend/resume cycle, and the HCI command in
it times out. The patch anchors it before the lock is dropped.

**Tested** (bluetooth-next `da3cc02587c6`): with a debug-only delay that widens the window and a
resume forced inside it, the unpatched kernel parked the command and timed out 3 of 3; with the
patch it was answered. Without the delay, 10 runs of 100 suspend/resume cycles on each kernel,
KASAN, lockdep and kmemleak on: no report and no parked packet on either. The bot's checks: only
the Signed-off-by checks fail. It applies and builds alone and together with item 3 in either
order.

**Questions for you.** The lock order and the teardown cases (disconnect while URBs are
deferred). `Cc: stable` or not: the hang was reproduced only with the window widened, and nobody
has reported it in the field.

**`contributions/CO-43-btusb-runtime-resume-failure/send-20261113/E/0001-Bluetooth-btusb-Anchor-a-deferred-URB-under-txlock.patch`** (SHA-256 `f314eb6b5536c040e79a70f4724b335a748ecd5042c688e6ea7eb231bfe1052d`)

```diff
From d4b60eb0fcf71f84e4019c7178639e175c9357ee Mon Sep 17 00:00:00 2001
From: Iaroslav Voitovych <yaroslav.voytovych@gmail.com>
Date: Fri, 13 Nov 2026 04:42:06 +0100
Subject: [PATCH] Bluetooth: btusb: Anchor a deferred URB under txlock

submit_or_queue_tx_urb() tests BTUSB_SUSPENDING under txlock, drops
the lock, and only then anchors the URB on data->deferred.
btusb_resume() sends the deferred URBs and clears BTUSB_SUSPENDING
under txlock. A resume that completes in between leaves the URB
anchored on an active device: the waker it schedules finds nothing to
resume, and the URB waits for the next suspend and resume. An HCI
command in it times out.

Anchor the URB in the same critical section as the flag test, so that
it is ordered against the replay and the clearing of the flag.
btusb_resume() already takes the anchor's lock inside txlock, so the
lock order does not change.

Fixes: 7bee549e197c ("Bluetooth: Add USB autosuspend support to btusb driver")
---
Tested with an emulated device attached over usbip in a QEMU guest. With
the window widened by a debug-only delay and a resume forced inside it,
a command was parked and timed out without this change, and was sent at
that resume with it. A stress run with concurrent senders, forced
resumes, power cycles and disconnects showed no lockdep, KASAN or
hung-task report and left nothing parked.

 drivers/bluetooth/btusb_main.c | 7 ++++++-
 1 file changed, 6 insertions(+), 1 deletion(-)

diff --git a/drivers/bluetooth/btusb_main.c b/drivers/bluetooth/btusb_main.c
index 95398e2ca..5f6d90d43 100644
--- a/drivers/bluetooth/btusb_main.c
+++ b/drivers/bluetooth/btusb_main.c
@@ -2391,16 +2391,21 @@ static int submit_or_queue_tx_urb(struct hci_dev *hdev, struct urb *urb)
 	unsigned long flags;
 	bool suspending;
 
+	/* Decide and anchor under txlock: btusb_resume() sends the deferred
+	 * URBs and clears BTUSB_SUSPENDING under the same lock, so a URB
+	 * anchored after that would wait for the next resume.
+	 */
 	spin_lock_irqsave(&data->txlock, flags);
 	suspending = test_bit(BTUSB_SUSPENDING, &data->flags);
 	if (!suspending)
 		data->tx_in_flight++;
+	else
+		usb_anchor_urb(urb, &data->deferred);
 	spin_unlock_irqrestore(&data->txlock, flags);
 
 	if (!suspending)
 		return submit_tx_urb(hdev, urb);
 
-	usb_anchor_urb(urb, &data->deferred);
 	schedule_work(&data->waker);
 
 	usb_free_urb(urb);

base-commit: da3cc02587c629420603df4395179ec82955c941
-- 
2.43.0

```

**`contributions/CO-43-btusb-runtime-resume-failure/send-20261113/E/CHECKS.md`** (SHA-256 `693b55a55da5343d38b5f34b8182834703c61758cb000f5347c33c89f38d99c5`)

````markdown
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
````

---

## 3. CO-43 A — btusb: report a failed runtime resume for deferred data

**The defect.** `btusb_waker()` calls `usb_autopm_get_interface()` to resume the device for
deferred data and ignores a failure, so a device that does not come back leaves no trace of why
the HCI traffic stalls. The patch logs the failure, except `-EACCES` (runtime PM disabled, for
example during a system sleep transition). No `Fixes:`, no `Cc: stable`: it adds a message only.

**Tested:** in the emulator run where the device fails its resume, the new line appears at the
moment of the failure. The bot's checks: only the Signed-off-by checks fail.

**Questions for you.** Whether the message is worth having upstream at all, and its wording; the
subject ("runtime resume", since the waker's resume is a runtime one).

**`contributions/CO-43-btusb-runtime-resume-failure/send-20261113/A/0001-Bluetooth-btusb-Report-a-failed-runtime-resume-for-d.patch`** (SHA-256 `5ef19422293d0868e3404a806474c01cbe7bba588e30972eb260b721ef9b26cf`)

```diff
From 5d5bdb6ee077524626eba0e412ca41e468da379e Mon Sep 17 00:00:00 2001
From: Iaroslav Voitovych <yaroslav.voytovych@gmail.com>
Date: Fri, 13 Nov 2026 04:24:55 +0100
Subject: [PATCH] Bluetooth: btusb: Report a failed runtime resume for deferred
 data

When data is sent while the device is runtime suspended,
submit_or_queue_tx_urb() anchors the URB on data->deferred and
btusb_waker() resumes the device with usb_autopm_get_interface(). If
that fails, the waker returns without a message and the URB stays on
the anchor. An HCI command in it then ends in a command timeout two
seconds later, which points at the controller rather than at the
failed resume.

Log the error in the waker. Leave out -EACCES, which is returned while
runtime PM is disabled, for example during a system sleep transition.
---
Tested with an emulated device attached over usbip in a QEMU guest
whose runtime resume never completes: the waker now logs the error
(-16) when the USB core gives up on the resume, just before the
disconnect.

 drivers/bluetooth/btusb_main.c | 7 ++++++-
 1 file changed, 6 insertions(+), 1 deletion(-)

diff --git a/drivers/bluetooth/btusb_main.c b/drivers/bluetooth/btusb_main.c
index 95398e2ca..0013d87ff 100644
--- a/drivers/bluetooth/btusb_main.c
+++ b/drivers/bluetooth/btusb_main.c
@@ -2659,8 +2659,13 @@ static void btusb_waker(struct work_struct *work)
 	int err;
 
 	err = usb_autopm_get_interface(data->intf);
-	if (err < 0)
+	if (err < 0) {
+		/* -EACCES: runtime PM is disabled, e.g. during system sleep */
+		if (err != -EACCES)
+			bt_dev_err(data->hdev, "Failed to resume device for deferred data: %d",
+				   err);
 		return;
+	}
 
 	usb_autopm_put_interface(data->intf);
 }

base-commit: da3cc02587c629420603df4395179ec82955c941
-- 
2.43.0

```

**`contributions/CO-43-btusb-runtime-resume-failure/send-20261113/A/CHECKS.md`** (SHA-256 `746e22212fa8871b800aab26eb1f99bee3cca3431d7301411a981807ec599149`)

````markdown
# A — checks, with commands and results (2026-11-13)

All paths are under `/root/exp/agent-work/co43-ea-send-20261113/` unless absolute. Nothing was
sent; nothing touched this machine's Bluetooth (the kernel ran in a QEMU guest).

## The patch and the tips

| | |
|---|---|
| patch | `0001-Bluetooth-btusb-Report-a-failed-runtime-resume-for-d.patch`, from commit `5d5bdb6ee077` (branch `ea-a-20261113`) |
| bluetooth-next tip | `da3cc02587c629420603df4395179ec82955c941` (2026-11-12 14:37 -0500) |
| bluetooth tip | `3b069de8a5d688c7e8381b99d6cdb7467fcae0de` (2026-11-12 14:35 -0500) |

Fetched today (`git ls-remote` and `git fetch` of both masters, as in `../E/CHECKS.md`);
`drivers/bluetooth/btusb_main.c` is identical on both tips.

**Changed against the reviewed patch:**
- the subject ("runtime");
- the message, reworded after the reviews: no claim that nothing else logs the failure, that
  `-EACCES` is system sleep only, or that `btusb_resume()` always sends the data;
- the comment, now the one line `/* -EACCES: runtime PM is disabled, e.g. during system sleep */`.

The code is otherwise unchanged: the two patch files' diffs differ only in the comment (read side
by side).
The patch ids differ for that reason: `0a6b0596…` (project `patch/0001`), `bd3d8cdf…` (the
package; `scripts/patch-ids.sh`).

## Applies and builds: alone, and with E in either order, on both tips

`scripts/apply-build.sh` (logs `build/apply-build-bluetooth-next.log`, `build/apply-build-bluetooth.log`):

```
RESULT bluetooth-next unpatched build rc=0
RESULT bluetooth-next A git-am=OK build rc=0 warnings_or_errors=0
RESULT bluetooth-next E+A git-am=OK build rc=0 warnings_or_errors=0
RESULT bluetooth-next A+E git-am=OK build rc=0 warnings_or_errors=0
RESULT bluetooth unpatched build rc=0
RESULT bluetooth A git-am=OK build rc=0 warnings_or_errors=0
RESULT bluetooth E+A git-am=OK build rc=0 warnings_or_errors=0
RESULT bluetooth A+E git-am=OK build rc=0 warnings_or_errors=0
```

(`W=1`, `drivers/bluetooth/btusb_main.o`, the guest config.) The full guest kernel with A alone
(`img/bzImage-ea-a`) built as well (`build/build-all.log`).

## checkpatch `--strict`

`scripts/checkpatch-docker.sh <patch>` (the tree's checkpatch in the list bot's image):

```
ERROR: Missing Signed-off-by: line(s)
total: 1 errors, 0 warnings, 0 checks, 14 lines checked
```

The only finding is the Signed-off-by you add. Control: with a Signed-off-by line added
(`tmp/checkpatch-control/A-with-sob.patch`): `total: 0 errors, 0 warnings, 0 checks, 14 lines
checked`, "no obvious style problems and is ready for submission".

## get_maintainer.pl

`scripts/get-maintainer-docker.sh <patch>`:

```
Marcel Holtmann <marcel@holtmann.org> (maintainer:BLUETOOTH DRIVERS)
Luiz Augusto von Dentz <luiz.dentz@gmail.com> (maintainer:BLUETOOTH DRIVERS)
linux-bluetooth@vger.kernel.org (open list:BLUETOOTH DRIVERS)
linux-kernel@vger.kernel.org (open list)
```

## The emulator run: the dead device, base + A

The harness (`stress/harness/`), its `bt17` scenario unchanged: the emulated QCA9377 autosuspends,
a MGMT Set Device Class starts a resume whose GET_STATUS the device never answers, and the device is
dead afterwards (`--fail-at 1`). Kernel `ea-a` = bluetooth-next + A (`7.3.0-g5d5bdb6ee077`),
KASAN, lockdep, hung-task detector, kmemleak.

```
$ stress/harness/run-guest.sh ea-a a-bt17-2 bt17 --fail-at 1
Bluetooth: hci0: command 0x0c24 tx timeout
Bluetooth: hci0: Failed to resume device for deferred data: -16
Bluetooth: hci0: Failed to resume device for deferred data: -16
  10.793 [mono  16.594006] RESULT bt17 fail_at=1 recover=False class-write-status=0x05 hci0_removed=True back=False powered=False class_write_after=none
run-guest: ea-a a-bt17-2 verdict=BT17-EXIT 0 exit=0
```

Exit 0: the scenario's success condition held (the dead device is removed). The kernel's own
sequence (`stress/logs/ea-a-a-bt17-2.log`, kernel time):

| | kernel time |
|---|---|
| Set Device Class sent | 9.378 |
| `command 0x0c24 tx timeout` | 11.412 |
| `retry with reset-resume` | 14.645 |
| `gone after usb resume? status -19` | 16.532 |
| **`Failed to resume device for deferred data: -16`** (the new line) | 16.533 |
| `Failed usb_autopm_get_interface: -16` (btusb's reset path, already there before A) | 16.533 |
| `USB disconnect, device number 2` | 16.534 |
| **`Failed to resume device for deferred data: -16`** (the waker's second run) | 16.534 |

The new line names the failed resume and its error. As the reviewers said, the existing
`Failed usb_autopm_get_interface` line appears at the same moment; the message no longer says
otherwise. An earlier run with the harness revision of that time
(`stress/logs/ea-a-a-bt17-1.log`) gave the same result: exit 0, the new line twice, -16.
`kernel-report-scan.py` over both logs: clean (`stress/kernel-report-scan.txt`).

## Bot CI

The project's `scripts/bot-ci-local.sh` from this work directory's clone, as for E: the bot's code
(action-ci `c7d077f185cd`, image `bluez-action-ci:c7d077f185cd`), the same three local changes
(`../E/CHECKS.md`, "Bot CI"), base bluetooth-next `da3cc02587c6`, BlueZ `20ffd285b58f`. Results in
`project/tmp/bot-ci-local/A4-20261113/` (`work/` deleted after the run). The patched side only: the
base side is the same commit, and it passed every tree check in E's run (BuildKernel,
CheckAllWarning, CheckSparse, BuildKernel32, CheckKernelLLVM, TestRunnerSetup:
`project/tmp/bot-ci-local/E4-20261113/base/`).

```
CheckPatch                    FAIL     (only: ERROR: Missing Signed-off-by: line(s))
VerifyFixes                   PASS     (A has no Fixes: tag)
VerifySignedoff               FAIL     (author and committer Signed-off-by missing)
GitLint                       FAIL     (only: CC1 Body does not contain a 'Signed-off-by' line)
SubjectPrefix                 PASS
BuildKernel                   PASS
CheckAllWarning               PASS
CheckSparse                   PASS
BuildKernel32                 PASS
CheckKernelLLVM               PASS
TestRunnerSetup               PASS
IncrementalBuild              PASS
```

No tester is selected for a btusb-only change. Every failure is the missing Signed-off-by.
````

---

## 4. CO-38 — MGMT: Read Advertising Features hides instances

**The defect** (from `b338d91703fa`, 2022; in 6.1.y to bluetooth-next). `read_adv_features()`
skips every instance whose number is above `hdev->adv_instance_cnt`, the count of instances,
instead of the controller's number of sets. After instance 1 is removed, instance 2 is no longer
listed, though it still advertises. Found by the tests of another item (CO-12, the
advertising-duration clamp, not in this document).

**Tested** (bluetooth-next `1081a6ef8f1e0`, 2026-11-02): the one-line fix passes all 128 mgmt-tester
"Add" cases and a new case that lists a remaining instance (BlueZ tests reproduced after the
patch). **Being refreshed today on the current tip**, and checked against a newer patch on the
list, "mgmt: drop advertising instances the controller cannot carry" (patchwork 14976301), which
may touch the same function.

**`contributions/CO-38-read-adv-features-hidden-instances/send-20261102/0001-Bluetooth-MGMT-Fix-Read-Advertising-Features-hiding-.patch`** (SHA-256 `51af5c3f85e0e14118f3af83b914b066296f1d26f819ffde1bc219da2780a470`)

```diff
From e3379d40f6f1eeb7f1703d5387869daf6f55f93e Mon Sep 17 00:00:00 2001
From: Iaroslav Voitovych <AUTHOR-EMAIL>
Date: Mon, 2 Nov 2026 14:37:08 +0100
Subject: [PATCH] Bluetooth: MGMT: Fix Read Advertising Features hiding
 instances

read_adv_features() means to hide only the mesh instance, which is
numbered one past the controller's advertising sets, but it compares
each instance number with the number of instances instead of the number
of sets. Whenever the instance numbers are not 1 to n, an instance is
left out: with instances 1 and 2 added and instance 1 removed, for
example after its timeout, instance 2 is no longer reported.

Compare with le_num_of_adv_sets, as the comment says.

Fixes: b338d91703fa ("Bluetooth: Implement support for Mesh")
Signed-off-by: Iaroslav Voitovych <yaroslav.voytovych@gmail.com>
---
 net/bluetooth/mgmt.c | 2 +-
 1 file changed, 1 insertion(+), 1 deletion(-)

diff --git a/net/bluetooth/mgmt.c b/net/bluetooth/mgmt.c
index cf5256f4a89e6..f948ebb657df6 100644
--- a/net/bluetooth/mgmt.c
+++ b/net/bluetooth/mgmt.c
@@ -8866,7 +8866,7 @@ static int read_adv_features(struct sock *sk, struct hci_dev *hdev,
 	instance = rp->instance;
 	list_for_each_entry(adv_instance, &hdev->adv_instances, list) {
 		/* Only instances 1-le_num_of_adv_sets are externally visible */
-		if (adv_instance->instance <= hdev->adv_instance_cnt) {
+		if (adv_instance->instance <= hdev->le_num_of_adv_sets) {
 			*instance = adv_instance->instance;
 			instance++;
 		} else {

base-commit: 42b8c2d729268a65a2d98064e8dc59ff53646b14
-- 
2.43.0

```

**`contributions/CO-38-read-adv-features-hidden-instances/send-20261102/bluez/0000-cover-letter.patch`** (SHA-256 `0a2a6e7d2d6e8bcf9b25e2bd80f4433e931c774c212f8e5c5a49f352a7bb3cdf`)

```diff
From: Iaroslav Voitovych <AUTHOR-EMAIL>
Subject: [PATCH BlueZ 0/3] mgmt-tester, mesh-tester: Add advertising timeout tests

This series adds 16 test cases: 15 to mgmt-tester (14 in 1/3, one in
2/3) and one to mesh-tester (3/3).

On an extended advertising controller the kernel passes the timeout of
an advertising instance to the controller as the Duration of LE Set
Extended Advertising Enable (units of 10 ms) and removes the instance
when the controller ends the set. The new cases check the Duration for
timeouts from 0 s to 65535 s, that an instance is still present before
its timeout and removed after it, and that Read Advertising Features
lists the instances that are left.

Results on bluetooth-next 42b8c2d72926 (BlueZ master 14bd6ab65f4a), in
QEMU with doc/tester.config, three runs each:

 - "Add Ext Advertising - Instance 2 listed alone" (2/3) fails on
   current kernels until "Bluetooth: MGMT: Fix Read Advertising Features
   hiding instances" is applied; it passes with that patch.

 - "Timeout 66 s", "655 s", "656 s (limit)", "6357 s (limit)",
   "8192 s (limit)", "65535 s (limit)", "66 s (Params)" and
   "66 s and 1 s" of 1/3 fail on current kernels until the separate fix
   for the extended advertising duration overflow in hci_sync.c lands.

 - All other new cases, including "Mesh - Send (Ext Adv Duration)", pass
   on current kernels. No existing case changes its result.

Iaroslav Voitovych (3):
  mgmt-tester: Add extended advertising timeout tests
  mgmt-tester: Add test for listing a remaining instance 2
  mesh-tester: Add Mesh Send test with extended advertising

 tools/mesh-tester.c |  32 +++
 tools/mgmt-tester.c | 526 ++++++++++++++++++++++++++++++++++++++++++++
 2 files changed, 558 insertions(+)

base-commit: 14bd6ab65f4a647302edbd6df27f6faa91bee8a8
--
2.43.0
```

**`contributions/CO-38-read-adv-features-hidden-instances/send-20261102/bluez/0001-mgmt-tester-Add-extended-advertising-timeout-tests.patch`** (SHA-256 `3f796506f9db57d0906986ea0f28586c7c29c3f6cfc46bcfc1b8bf3a4d33f3cd`)

```diff
From e3cc46981c3494cf43a16abcbb19ef80179e166b Mon Sep 17 00:00:00 2001
From: Iaroslav Voitovych <AUTHOR-EMAIL>
Date: Sun, 1 Nov 2026 18:46:34 +0100
Subject: [PATCH BlueZ 1/3] mgmt-tester: Add extended advertising timeout tests

On an extended advertising controller the kernel passes the instance
timeout as the Duration of LE Set Extended Advertising Enable, in units
of 10 ms, and removes the instance when the controller ends the set.

Check the Duration for timeouts of 0, 1, 65, 66 and 655 s and for
timeouts above the 655.35 s the field can hold, which are expected at
0xffff; check that an instance is still present before its timeout and
that a 1 s instance is removed after 1 s, through Add Advertising and
through Add Extended Advertising Parameters. Also cover an instance
added again with another timeout before the first expires, and two
instances with different timeouts.
---
 tools/mgmt-tester.c | 506 ++++++++++++++++++++++++++++++++++++++++++++
 1 file changed, 506 insertions(+)

diff --git a/tools/mgmt-tester.c b/tools/mgmt-tester.c
index 201bd4396..6450b2ba5 100644
--- a/tools/mgmt-tester.c
+++ b/tools/mgmt-tester.c
@@ -20,6 +20,7 @@
 #include <sys/types.h>
 #include <fcntl.h>
 #include <errno.h>
+#include <time.h>
 #include <unistd.h>
 
 #include <linux/rfkill.h>
@@ -54,6 +55,17 @@ struct simult_discovery {
 	unsigned int restart_id;
 };
 
+#define ADV_TIMEOUT_MAX_INST	2
+
+struct adv_timeout_state {
+	uint64_t enabled_ms[ADV_TIMEOUT_MAX_INST];
+	bool removed[ADV_TIMEOUT_MAX_INST];
+	uint8_t added;
+	unsigned int replace_id;
+	unsigned int check_id;
+	bool done;
+};
+
 struct test_data {
 	tester_data_func_t test_setup;
 	const void *test_data;
@@ -80,6 +92,7 @@ struct test_data {
 	unsigned int settle_id;
 	int sk;
 	struct simult_discovery simult;
+	struct adv_timeout_state adv_timeout;
 };
 
 static void print_debug(const char *str, void *user_data)
@@ -115,11 +128,29 @@ static void simult_discovery_cleanup(struct test_data *data)
 	memset(simult, 0, sizeof(*simult));
 }
 
+static void adv_timeout_cleanup(struct test_data *data)
+{
+	struct adv_timeout_state *state = &data->adv_timeout;
+
+	if (state->replace_id) {
+		timeout_remove(state->replace_id);
+		state->replace_id = 0;
+	}
+
+	if (state->check_id) {
+		timeout_remove(state->check_id);
+		state->check_id = 0;
+	}
+
+	state->done = true;
+}
+
 static void test_post_teardown(const void *test_data)
 {
 	struct test_data *data = tester_get_data();
 
 	simult_discovery_cleanup(data);
+	adv_timeout_cleanup(data);
 
 	if (data->settle_id) {
 		timeout_remove(data->settle_id);
@@ -363,6 +394,21 @@ struct hci_entry {
 	const struct hci_cmd_data *cmd_data;
 };
 
+struct adv_timeout_inst {
+	uint8_t instance;
+	uint16_t timeout;		/* MGMT timeout in seconds */
+	uint16_t duration;		/* expected HCI Duration, N * 10 ms */
+	bool expire;			/* removal expected within the test */
+};
+
+struct adv_timeout_test {
+	struct adv_timeout_inst inst[ADV_TIMEOUT_MAX_INST];
+	uint8_t num_inst;
+	bool ext_params;		/* Add Ext Adv Params + Data */
+	unsigned int replace_ms;	/* inst[1] replaces inst[0] */
+	unsigned int check_ms;		/* final check after first enable */
+};
+
 struct generic_data {
 	bdaddr_t *setup_bdaddr;
 	bool setup_le_states;
@@ -429,6 +475,7 @@ struct generic_data {
 	uint8_t adv_data_len;
 	const struct devcoredump_test_data *dump_data;
 	const char (*expect_dump_data)[MAX_COREDUMP_LINE_LEN];
+	const struct adv_timeout_test *adv_timeout;
 };
 
 static const uint8_t set_exp_feat_param_debug[] = {
@@ -14253,6 +14300,418 @@ static void test_hci_devcd(const void *test_data)
 	tester_wait(test->dump_data->timeout + 1, verify_devcd, NULL);
 }
 
+/* An extended advertising controller is given the instance timeout as the
+ * Duration of LE Set Extended Advertising Enable (N * 10 ms) and ends the
+ * set itself, after which the kernel removes the instance. The field holds
+ * at most 0xffff (655.35 s), so longer timeouts are expected at that limit.
+ * Removal is expected Duration * 10 ms after the enable.
+ */
+#define ADV_TIMEOUT_EARLY_MS	50
+#define ADV_TIMEOUT_LATE_MS	1000
+
+#define ADV_TIMEOUT_TEST(_name, _timeout, _duration, _expire, _check) \
+	static const struct adv_timeout_test adv_timeout_##_name = { \
+		.inst = { { 0x01, _timeout, _duration, _expire } }, \
+		.num_inst = 1, \
+		.check_ms = _check, \
+	}; \
+	static const struct generic_data add_ext_adv_timeout_##_name = { \
+		.setup_settings = settings_powered_le, \
+		.adv_timeout = &adv_timeout_##_name, \
+	}
+
+ADV_TIMEOUT_TEST(1, 1, 100, true, 2500);
+ADV_TIMEOUT_TEST(0, 0, 0, false, 2000);
+ADV_TIMEOUT_TEST(65, 65, 6500, false, 2000);
+ADV_TIMEOUT_TEST(66, 66, 6600, false, 2000);
+ADV_TIMEOUT_TEST(655, 655, 65500, false, 2000);
+ADV_TIMEOUT_TEST(656, 656, 0xffff, false, 2000);
+ADV_TIMEOUT_TEST(6357, 6357, 0xffff, false, 2000);
+ADV_TIMEOUT_TEST(8192, 8192, 0xffff, false, 2000);
+ADV_TIMEOUT_TEST(65535, 65535, 0xffff, false, 2000);
+
+static const struct adv_timeout_test adv_timeout_params_1 = {
+	.inst = { { 0x01, 1, 100, true } },
+	.num_inst = 1,
+	.ext_params = true,
+	.check_ms = 2500,
+};
+
+static const struct generic_data add_ext_adv_timeout_params_1 = {
+	.setup_settings = settings_powered_le,
+	.adv_timeout = &adv_timeout_params_1,
+};
+
+static const struct adv_timeout_test adv_timeout_params_66 = {
+	.inst = { { 0x01, 66, 6600, false } },
+	.num_inst = 1,
+	.ext_params = true,
+	.check_ms = 2000,
+};
+
+static const struct generic_data add_ext_adv_timeout_params_66 = {
+	.setup_settings = settings_powered_le,
+	.adv_timeout = &adv_timeout_params_66,
+};
+
+/* Instance 1 is added again with another timeout before its first one
+ * expires: only the second timeout applies.
+ */
+static const struct adv_timeout_test adv_timeout_replace = {
+	.inst = {
+		{ 0x01, 2, 200, false },
+		{ 0x01, 3, 300, true },
+	},
+	.num_inst = 2,
+	.replace_ms = 1000,
+	.check_ms = 5500,
+};
+
+static const struct generic_data add_ext_adv_timeout_replace = {
+	.setup_settings = settings_powered_le,
+	.adv_timeout = &adv_timeout_replace,
+};
+
+static const struct adv_timeout_test adv_timeout_two_1_2 = {
+	.inst = {
+		{ 0x01, 1, 100, true },
+		{ 0x02, 2, 200, true },
+	},
+	.num_inst = 2,
+	.check_ms = 3500,
+};
+
+static const struct generic_data add_ext_adv_timeout_two_1_2 = {
+	.setup_settings = settings_powered_le,
+	.adv_timeout = &adv_timeout_two_1_2,
+};
+
+static const struct adv_timeout_test adv_timeout_two_66_1 = {
+	.inst = {
+		{ 0x01, 66, 6600, false },
+		{ 0x02, 1, 100, true },
+	},
+	.num_inst = 2,
+	.check_ms = 2500,
+};
+
+static const struct generic_data add_ext_adv_timeout_two_66_1 = {
+	.setup_settings = settings_powered_le,
+	.adv_timeout = &adv_timeout_two_66_1,
+};
+
+static uint64_t adv_timeout_now_ms(void)
+{
+	struct timespec ts;
+
+	clock_gettime(CLOCK_MONOTONIC, &ts);
+
+	return (uint64_t) ts.tv_sec * 1000 + ts.tv_nsec / 1000000;
+}
+
+static void adv_timeout_finish(struct test_data *data, bool passed)
+{
+	adv_timeout_cleanup(data);
+
+	if (passed)
+		tester_test_passed();
+	else
+		tester_test_failed();
+}
+
+/* The entry of inst[] that was added last for the instance */
+static int adv_timeout_slot(struct test_data *data, uint8_t instance)
+{
+	const struct generic_data *test = data->test_data;
+	const struct adv_timeout_test *t = test->adv_timeout;
+	int i;
+
+	for (i = data->adv_timeout.added - 1; i >= 0; i--) {
+		if (t->inst[i].instance == instance)
+			return i;
+	}
+
+	return -1;
+}
+
+static void adv_timeout_add(struct test_data *data);
+
+static void adv_timeout_add_callback(uint8_t status, uint16_t length,
+					const void *param, void *user_data)
+{
+	struct test_data *data = tester_get_data();
+	const struct generic_data *test = data->test_data;
+	const struct adv_timeout_test *t = test->adv_timeout;
+	const struct mgmt_rp_add_advertising *rp = param;
+
+	if (data->adv_timeout.done)
+		return;
+
+	if (status != MGMT_STATUS_SUCCESS || length < sizeof(*rp)) {
+		tester_warn("Adding the instance failed: %s (0x%02x)",
+						mgmt_errstr(status), status);
+		adv_timeout_finish(data, false);
+		return;
+	}
+
+	tester_print("Instance %u added", rp->instance);
+
+	if (!t->replace_ms && data->adv_timeout.added < t->num_inst)
+		adv_timeout_add(data);
+}
+
+static void adv_timeout_params_callback(uint8_t status, uint16_t length,
+					const void *param, void *user_data)
+{
+	struct test_data *data = tester_get_data();
+	const struct mgmt_rp_add_ext_adv_params *rp = param;
+	struct mgmt_cp_add_ext_adv_data *cp;
+	uint8_t buf[sizeof(*cp) + TESTER_ADD_ADV_DATA_LEN];
+
+	if (data->adv_timeout.done)
+		return;
+
+	if (status != MGMT_STATUS_SUCCESS || length < sizeof(*rp)) {
+		tester_warn("Adding the parameters failed: %s (0x%02x)",
+						mgmt_errstr(status), status);
+		adv_timeout_finish(data, false);
+		return;
+	}
+
+	memset(buf, 0, sizeof(buf));
+	cp = (void *) buf;
+	cp->instance = rp->instance;
+	cp->adv_data_len = TESTER_ADD_ADV_DATA_LEN;
+	cp->data[0] = TESTER_ADD_ADV_DATA_LEN - 1;	/* AD len */
+	cp->data[1] = 0x08;		/* AD type: shortened local name */
+	memcpy(cp->data + 2, "test", 4);
+	cp->data[6] = '0' + rp->instance;
+
+	mgmt_send(data->mgmt, MGMT_OP_ADD_EXT_ADV_DATA, data->mgmt_index,
+					sizeof(buf), buf,
+					adv_timeout_add_callback, NULL, NULL);
+}
+
+static void adv_timeout_add(struct test_data *data)
+{
+	const struct generic_data *test = data->test_data;
+	const struct adv_timeout_test *t = test->adv_timeout;
+	const struct adv_timeout_inst *inst;
+	struct mgmt_cp_add_ext_adv_params params;
+	struct mgmt_cp_add_advertising *cp;
+	uint8_t buf[sizeof(*cp) + TESTER_ADD_ADV_DATA_LEN];
+
+	inst = &t->inst[data->adv_timeout.added++];
+
+	tester_print("Adding instance %u with timeout %u s", inst->instance,
+							inst->timeout);
+
+	if (t->ext_params) {
+		memset(&params, 0, sizeof(params));
+		params.instance = inst->instance;
+		put_le32(MGMT_ADV_PARAM_TIMEOUT, &params.flags);
+		put_le16(inst->timeout, &params.timeout);
+
+		mgmt_send(data->mgmt, MGMT_OP_ADD_EXT_ADV_PARAMS,
+				data->mgmt_index, sizeof(params), &params,
+				adv_timeout_params_callback, NULL, NULL);
+		return;
+	}
+
+	cp = (void *) buf;
+	setup_add_adv_param(cp, inst->instance);
+	put_le16(inst->timeout, &cp->timeout);
+
+	mgmt_send(data->mgmt, MGMT_OP_ADD_ADVERTISING, data->mgmt_index,
+					sizeof(buf), buf,
+					adv_timeout_add_callback, NULL, NULL);
+}
+
+static void adv_timeout_features(uint8_t status, uint16_t length,
+					const void *param, void *user_data)
+{
+	struct test_data *data = tester_get_data();
+	const struct generic_data *test = data->test_data;
+	const struct adv_timeout_test *t = test->adv_timeout;
+	struct adv_timeout_state *state = &data->adv_timeout;
+	const struct mgmt_rp_read_adv_features *rp = param;
+	int i;
+
+	if (state->done)
+		return;
+
+	if (status != MGMT_STATUS_SUCCESS || length < sizeof(*rp) ||
+				length < sizeof(*rp) + rp->num_instances) {
+		tester_warn("Read Advertising Features failed");
+		adv_timeout_finish(data, false);
+		return;
+	}
+
+	if (state->added < t->num_inst) {
+		tester_warn("Only %u of %u instances added", state->added,
+								t->num_inst);
+		adv_timeout_finish(data, false);
+		return;
+	}
+
+	for (i = 0; i < state->added; i++) {
+		const struct adv_timeout_inst *inst = &t->inst[i];
+		bool listed;
+
+		/* Replaced by a later entry */
+		if (adv_timeout_slot(data, inst->instance) != i)
+			continue;
+
+		listed = memchr(rp->instance, inst->instance,
+						rp->num_instances) != NULL;
+
+		if (inst->expire && (!state->removed[i] || listed)) {
+			tester_warn("Instance %u not removed after %u ms",
+					inst->instance, inst->duration * 10);
+			adv_timeout_finish(data, false);
+			return;
+		}
+
+		if (!inst->expire && !listed) {
+			tester_warn("Instance %u missing before its timeout",
+							inst->instance);
+			adv_timeout_finish(data, false);
+			return;
+		}
+	}
+
+	adv_timeout_finish(data, true);
+}
+
+static bool adv_timeout_check(void *user_data)
+{
+	struct test_data *data = user_data;
+
+	data->adv_timeout.check_id = 0;
+
+	mgmt_send(data->mgmt, MGMT_OP_READ_ADV_FEATURES, data->mgmt_index,
+				0, NULL, adv_timeout_features, NULL, NULL);
+
+	return false;
+}
+
+static bool adv_timeout_readd(void *user_data)
+{
+	struct test_data *data = user_data;
+
+	data->adv_timeout.replace_id = 0;
+	adv_timeout_add(data);
+
+	return false;
+}
+
+static void adv_timeout_hci(uint16_t opcode, const void *param,
+					uint8_t length, void *user_data)
+{
+	struct test_data *data = user_data;
+	const struct generic_data *test = data->test_data;
+	const struct adv_timeout_test *t = test->adv_timeout;
+	struct adv_timeout_state *state = &data->adv_timeout;
+	const struct bt_hci_cmd_le_set_ext_adv_enable *cp = param;
+	const struct bt_hci_cmd_ext_adv_set *set;
+	uint8_t i;
+
+	if (opcode != BT_HCI_CMD_LE_SET_EXT_ADV_ENABLE || state->done)
+		return;
+
+	if (length < sizeof(*cp) || !cp->enable ||
+			length < sizeof(*cp) + cp->num_of_sets * sizeof(*set))
+		return;
+
+	set = (const void *) (cp + 1);
+
+	for (i = 0; i < cp->num_of_sets; i++, set++) {
+		uint16_t duration = get_le16(&set->duration);
+		int slot = adv_timeout_slot(data, set->handle);
+
+		if (slot < 0)
+			continue;
+
+		tester_print("Instance %u enabled, Duration %u (%u ms)",
+					set->handle, duration, duration * 10);
+
+		if (duration != t->inst[slot].duration) {
+			tester_warn("Expected Duration %u",
+						t->inst[slot].duration);
+			adv_timeout_finish(data, false);
+			return;
+		}
+
+		state->enabled_ms[slot] = adv_timeout_now_ms();
+
+		if (slot || state->check_id)
+			continue;
+
+		state->check_id = timeout_add(t->check_ms, adv_timeout_check,
+								data, NULL);
+
+		if (t->replace_ms)
+			state->replace_id = timeout_add(t->replace_ms,
+							adv_timeout_readd,
+							data, NULL);
+	}
+}
+
+static void adv_timeout_removed(uint16_t index, uint16_t length,
+					const void *param, void *user_data)
+{
+	struct test_data *data = tester_get_data();
+	const struct generic_data *test = data->test_data;
+	const struct adv_timeout_test *t = test->adv_timeout;
+	struct adv_timeout_state *state = &data->adv_timeout;
+	const struct mgmt_ev_advertising_removed *ev = param;
+	const struct adv_timeout_inst *inst;
+	uint64_t elapsed, expected;
+	int slot;
+
+	if (state->done || length < sizeof(*ev))
+		return;
+
+	slot = adv_timeout_slot(data, ev->instance);
+	if (slot < 0 || !state->enabled_ms[slot]) {
+		tester_warn("Instance %u removed before it was enabled",
+								ev->instance);
+		adv_timeout_finish(data, false);
+		return;
+	}
+
+	inst = &t->inst[slot];
+	elapsed = adv_timeout_now_ms() - state->enabled_ms[slot];
+	expected = inst->duration * 10;
+
+	tester_print("Instance %u removed %llu ms after its enable",
+				ev->instance, (unsigned long long) elapsed);
+
+	if (!inst->expire || elapsed + ADV_TIMEOUT_EARLY_MS < expected ||
+				elapsed > expected + ADV_TIMEOUT_LATE_MS) {
+		tester_warn("Expected removal after %llu ms",
+					(unsigned long long) expected);
+		adv_timeout_finish(data, false);
+		return;
+	}
+
+	state->removed[slot] = true;
+}
+
+static void test_add_adv_timeout(const void *test_data)
+{
+	struct test_data *data = tester_get_data();
+
+	hciemu_add_central_post_command_hook(data->hciemu, adv_timeout_hci,
+									data);
+
+	mgmt_register(data->mgmt_alt, MGMT_EV_ADVERTISING_REMOVED,
+				data->mgmt_index, adv_timeout_removed,
+				NULL, NULL);
+
+	adv_timeout_add(data);
+}
+
 int main(int argc, char *argv[])
 {
 	tester_init(&argc, &argv);
@@ -15613,6 +16072,53 @@ int main(int argc, char *argv[])
 					setup_add_advertising_timeout,
 					test_command_generic, 3);
 
+	/* The timeout is passed to the controller as the Duration of the
+	 * advertising set, in units of 10 ms and at most 655.35 s, and the
+	 * instance is removed when the set ends.
+	 */
+	test_bredrle50_full("Add Ext Advertising - Timeout 1 s (expires)",
+					&add_ext_adv_timeout_1, NULL,
+					test_add_adv_timeout, 5);
+	test_bredrle50_full("Add Ext Advertising - Timeout 0 s (none)",
+					&add_ext_adv_timeout_0, NULL,
+					test_add_adv_timeout, 5);
+	test_bredrle50_full("Add Ext Advertising - Timeout 65 s",
+					&add_ext_adv_timeout_65, NULL,
+					test_add_adv_timeout, 5);
+	test_bredrle50_full("Add Ext Advertising - Timeout 66 s",
+					&add_ext_adv_timeout_66, NULL,
+					test_add_adv_timeout, 5);
+	test_bredrle50_full("Add Ext Advertising - Timeout 655 s",
+					&add_ext_adv_timeout_655, NULL,
+					test_add_adv_timeout, 5);
+	test_bredrle50_full("Add Ext Advertising - Timeout 656 s (limit)",
+					&add_ext_adv_timeout_656, NULL,
+					test_add_adv_timeout, 5);
+	test_bredrle50_full("Add Ext Advertising - Timeout 6357 s (limit)",
+					&add_ext_adv_timeout_6357, NULL,
+					test_add_adv_timeout, 5);
+	test_bredrle50_full("Add Ext Advertising - Timeout 8192 s (limit)",
+					&add_ext_adv_timeout_8192, NULL,
+					test_add_adv_timeout, 5);
+	test_bredrle50_full("Add Ext Advertising - Timeout 65535 s (limit)",
+					&add_ext_adv_timeout_65535, NULL,
+					test_add_adv_timeout, 5);
+	test_bredrle50_full("Add Ext Advertising - Timeout 1 s (Params)",
+					&add_ext_adv_timeout_params_1, NULL,
+					test_add_adv_timeout, 5);
+	test_bredrle50_full("Add Ext Advertising - Timeout 66 s (Params)",
+					&add_ext_adv_timeout_params_66, NULL,
+					test_add_adv_timeout, 5);
+	test_bredrle50_full("Add Ext Advertising - Timeout replaced",
+					&add_ext_adv_timeout_replace, NULL,
+					test_add_adv_timeout, 9);
+	test_bredrle50_full("Add Ext Advertising - Timeout 1 s and 2 s",
+					&add_ext_adv_timeout_two_1_2, NULL,
+					test_add_adv_timeout, 6);
+	test_bredrle50_full("Add Ext Advertising - Timeout 66 s and 1 s",
+					&add_ext_adv_timeout_two_66_1, NULL,
+					test_add_adv_timeout, 5);
+
 	/* LE off will clear (remove) all instances. */
 	test_bredrle50("Add Ext Advertising - Success 22 (LE -> off, Remove)",
 					&add_ext_advertising_le_off,
-- 
2.43.0

```

**`contributions/CO-38-read-adv-features-hidden-instances/send-20261102/bluez/0002-mgmt-tester-Add-test-for-listing-a-remaining-instanc.patch`** (SHA-256 `7e7b5e2c54d4373912bf30c992c53c4e3937129a25f0eae42b244f441d36e859`)

```diff
From 57f697bc0491595a99f94bcb7fee54c03b9d7d02 Mon Sep 17 00:00:00 2001
From: Iaroslav Voitovych <AUTHOR-EMAIL>
Date: Mon, 2 Nov 2026 14:37:37 +0100
Subject: [PATCH BlueZ 2/3] mgmt-tester: Add test for listing a remaining
 instance 2

Add instances 1 and 2 on an extended advertising controller, let
instance 1 expire after 1 s, and check that Read Advertising Features
still lists instance 2.
---
 tools/mgmt-tester.c | 20 ++++++++++++++++++++
 1 file changed, 20 insertions(+)

diff --git a/tools/mgmt-tester.c b/tools/mgmt-tester.c
index 6450b2ba5..45b7109e8 100644
--- a/tools/mgmt-tester.c
+++ b/tools/mgmt-tester.c
@@ -14400,6 +14400,23 @@ static const struct generic_data add_ext_adv_timeout_two_66_1 = {
 	.adv_timeout = &adv_timeout_two_66_1,
 };
 
+/* Once instance 1 has expired, instance 2 is the only instance left and
+ * Read Advertising Features still has to list it.
+ */
+static const struct adv_timeout_test adv_timeout_list_2 = {
+	.inst = {
+		{ 0x01, 1, 100, true },
+		{ 0x02, 0, 0, false },
+	},
+	.num_inst = 2,
+	.check_ms = 2500,
+};
+
+static const struct generic_data add_ext_adv_timeout_list_2 = {
+	.setup_settings = settings_powered_le,
+	.adv_timeout = &adv_timeout_list_2,
+};
+
 static uint64_t adv_timeout_now_ms(void)
 {
 	struct timespec ts;
@@ -16118,6 +16135,9 @@ int main(int argc, char *argv[])
 	test_bredrle50_full("Add Ext Advertising - Timeout 66 s and 1 s",
 					&add_ext_adv_timeout_two_66_1, NULL,
 					test_add_adv_timeout, 5);
+	test_bredrle50_full("Add Ext Advertising - Instance 2 listed alone",
+					&add_ext_adv_timeout_list_2, NULL,
+					test_add_adv_timeout, 5);
 
 	/* LE off will clear (remove) all instances. */
 	test_bredrle50("Add Ext Advertising - Success 22 (LE -> off, Remove)",
-- 
2.43.0

```

**`contributions/CO-38-read-adv-features-hidden-instances/send-20261102/bluez/0003-mesh-tester-Add-Mesh-Send-test-with-extended-adverti.patch`** (SHA-256 `cf70b35dfbc8a010d8b58baa0e9e4d85e6f219fdd3ec436c7a7711a4609437da`)

```diff
From 8affb456c44aee70deabeeb4156c141e13181b73 Mon Sep 17 00:00:00 2001
From: Iaroslav Voitovych <AUTHOR-EMAIL>
Date: Sun, 1 Nov 2026 18:46:36 +0100
Subject: [PATCH BlueZ 3/3] mesh-tester: Add Mesh Send test with extended
 advertising

The mesh advertising instance timeout is in milliseconds. Check that an
extended advertising controller gets a Duration of 100 (1000 ms) for
it.
---
 tools/mesh-tester.c | 32 ++++++++++++++++++++++++++++++++
 1 file changed, 32 insertions(+)

diff --git a/tools/mesh-tester.c b/tools/mesh-tester.c
index 896cfd1f2..febcb91c4 100644
--- a/tools/mesh-tester.c
+++ b/tools/mesh-tester.c
@@ -1294,6 +1294,33 @@ static const struct generic_data mesh_send_mesh_1 = {
 	.expect_hci_len = sizeof(mesh_send_rsp_param_mesh),
 };
 
+/* The mesh instance timeout is 1000 ms, handed to the controller as a
+ * Duration of 100 (N * 10 ms). The instance is the one past the
+ * controller's three advertising sets.
+ */
+static const uint8_t mesh_send_ext_adv_enable[] = {
+	0x01,				/* Enable */
+	0x01,				/* Number of sets */
+	0x04,				/* Handle */
+	0x64, 0x00,			/* Duration */
+	0x00,				/* Max events */
+};
+
+static const struct generic_data mesh_send_mesh_ext_adv = {
+	.send_opcode = MGMT_OP_MESH_SEND,
+	.send_param = send_mesh_1,
+	.send_len = sizeof(send_mesh_1),
+	.expect_param = mesh_send_rsp_param_mesh,
+	.expect_len = sizeof(mesh_send_rsp_param_mesh),
+	.expect_status = MGMT_STATUS_SUCCESS,
+	.expect_alt_ev = MGMT_EV_MESH_PACKET_CMPLT,
+	.expect_alt_ev_param = mesh_send_rsp_param_mesh,
+	.expect_alt_ev_len = sizeof(mesh_send_rsp_param_mesh),
+	.expect_hci_command = BT_HCI_CMD_LE_SET_EXT_ADV_ENABLE,
+	.expect_hci_param = mesh_send_ext_adv_enable,
+	.expect_hci_len = sizeof(mesh_send_ext_adv_enable),
+};
+
 static const struct generic_data mesh_send_mesh_too_short = {
 	.send_opcode = MGMT_OP_MESH_SEND,
 	.send_param = send_mesh_1,
@@ -1434,6 +1461,11 @@ int main(int argc, char *argv[])
 			setup_enable_mesh,
 			test_command_generic);
 
+	test_bredrle50("Mesh - Send (Ext Adv Duration)",
+			&mesh_send_mesh_ext_adv,
+			setup_enable_mesh,
+			test_command_generic);
+
 	test_bredrle("Mesh - Send - too short",
 			&mesh_send_mesh_too_short,
 			setup_enable_mesh,
-- 
2.43.0

```

**`contributions/CO-38-read-adv-features-hidden-instances/send-20261102/RESULTS.md`** (SHA-256 `1dcff0a6362bef149e8186e99418152ba863f0ab2857b638cdfca37e19d84c8b`)

```markdown
# CO-38 kernel fix and BlueZ test series: results (2026-11-02)

Nothing was sent. Area: /root/exp/agent-work/co38-ready-20261102/ (below "area"). Claims are marked
[measured] (a command's output, logs listed in SHA256SUMS), [source] (read from a file) or [inferred].

## Bases [measured: git log of the fetched tips]

- bluetooth-next master 42b8c2d729268a65a2d98064e8dc59ff53646b14, committer date 2026-10-30 09:55:58 -0400,
  "Merge branch 'bluetooth' into bluetooth-next". Fetched 2026-11-02 into cache/linux-bt-next
  (`git fetch bluetooth-next master`); the tip is the same as on 2026-11-01.
- BlueZ master 14bd6ab65f4a647302edbd6df27f6faa91bee8a8, committer date 2026-10-29 14:37:49 -0400,
  "doc/virtio: Update measurements of the testers". Fetched 2026-11-02 into cache/bluez-upstream; unchanged.

## Kernel patch (final/0001-Bluetooth-MGMT-Fix-Read-Advertising-Features-hiding-.patch)

- Commit e3379d40f6f1e on 42b8c2d72926 in area/linux (worktree of the bt-next cache; sparse checkout
  disabled in that worktree only, a full tree is needed to build). Message = commit-msg-listfix.txt unchanged;
  author and Signed-off-by exactly as in the old patch; no Cc: stable.
- `git format-patch -1 --base=42b8c2d729268a65a2d98064e8dc59ff53646b14`: trailer
  `base-commit: 42b8c2d729268a65a2d98064e8dc59ff53646b14`. Diff blob ids (cf5256f4a89e6..f948ebb657df6)
  are identical to the old patch's. In the final copy From: is `Iaroslav Voitovych <AUTHOR-EMAIL>`; the
  Signed-off-by line keeps the address, as the old patch has it. Subject: 63 columns.
- checkpatch.pl --strict (scripts/checkpatch.pl of the tree at the fix, so Fixes: is checked in history),
  log logs/checkpatch-kernel.log [measured]:
  - on the patch with the real From: `total: 0 errors, 0 warnings, 0 checks, 8 lines checked`
  - on the final copy with the placeholder: `ERROR: Missing Signed-off-by: line by nominal patch author ''`.
    This is only the placeholder From: not matching the Signed-off-by; it goes away with the real address.
  - Note: the host's isolation hook blocks a direct call of checkpatch.pl (it contains the word "reboot");
    it was run through scripts/checkpatch-kernel.sh, as the earlier area did.

## BlueZ series (final/bluez/0000-cover-letter.patch ... 0003-*.patch), on 14bd6ab65f4a

| # | subject | columns | new cases |
|---|---|---|---|
| 1/3 | mgmt-tester: Add extended advertising timeout tests | 51 | 14 |
| 2/3 | mgmt-tester: Add test for listing a remaining instance 2 | 56 | 1 |
| 3/3 | mesh-tester: Add Mesh Send test with extended advertising | 57 | 1 |

- Subjects over 50 columns, not changed: all three (51, 56, 57).
- Prefix `[PATCH BlueZ n/3]` (`git format-patch --subject-prefix="PATCH BlueZ" --cover-letter`), no
  Signed-off-by, bodies wrapped at 72 or less. From: placeholder `<AUTHOR-EMAIL>` as for the kernel patch.
- No "Research only", "LongAdv" or "not for submission" text anywhere (`grep -c` = 0 on the tester sources
  and on all four files); the four long-running cases of the old patch 3 are not in the series.
  The listing case was re-made on the clean 1/3 by hand (not from the old 4/4, whose context was the research code).
- New cases, counted from the final series [measured: `grep -c -E '^\+\s+test_bredrle(50)?(_full)?\('` on
  each patch: 14, 1, 1]: **16 new cases = 15 in mgmt-tester (14 + the listing case) + 1 in mesh-tester**.
  The earlier "15 new mgmt cases" in the CO-12 log was 14 mgmt + 1 mesh before the listing case; with it the
  series has 16, of which 15 are mgmt. The old final table's 15 rows (mgmt only) match the 15 mgmt cases; the
  number to quote is 16 in total (15 mgmt + 1 mesh).

## QEMU runs [measured]

Kernels (config = doc/tester.config + SMP/kprobe fragment + KASAN + lockdep, the CO-12 config-A-base,
`CONFIG_KASAN=y` and `CONFIG_PROVE_LOCKING=y` confirmed in img/config-*):
- plain: 42b8c2d72926 (bzImage sha256 3d7eb69e16af79260869f75cb9a51ec6ef903ef76a6786602c3235e544a8810f), 7.3.0-rc6-01714-g42b8c2d72926
- fix: plain + e3379d40f6f1 alone (bzImage sha256 3087e66253c673118d6a2015273cb39546d27085f5516c3084fe99102ed90745), 7.3.0-rc6-01715-ge3379d40f6f1
- The CO-12 clamp is in neither.

Tester: tools/mgmt-tester and tools/mesh-tester built from the series HEAD (area/bluez, 8affb456c); test-runner
from the same tree, 4 CPUs, 2 GB per guest (scripts/run-vm.sh, scripts/run-matrix.sh).
Commands: `mgmt-tester-series -p Add` (all 128 "Add" cases: Add UUID, Add Device, Add Advertising, Add Ext
Advertising) and `mesh-tester-series -p Mesh` (10 cases), 3 runs per kernel: logs/mgmt-{plain,fix}-{1,2,3}.log,
logs/mesh-{plain,fix}-{1,2,3}.log; tables logs/table-mgmt.md, logs/table-mesh.md.

mgmt-tester, 128 cases per run:
- plain: Passed 119, Failed 9 in all three runs (identical sets).
- fix: Passed 120, Failed 8 in all three runs (identical sets).
- The only case that changes verdict: "Add Ext Advertising - Instance 2 listed alone": Failed (3 of 3) on plain,
  Passed (3 of 3) with the fix. Every other of the 127 cases has the same verdict on both kernels in all runs.
- Expected failures on both kernels (need the separate CO-12 duration fix; 8 cases, 3 of 3 runs each):
  "Add Ext Advertising - Timeout 66 s", "- Timeout 655 s", "- Timeout 656 s (limit)",
  "- Timeout 6357 s (limit)", "- Timeout 8192 s (limit)", "- Timeout 65535 s (limit)",
  "- Timeout 66 s (Params)", "- Timeout 66 s and 1 s".
- Pass on both kernels: "Timeout 1 s (expires)", "Timeout 0 s (none)", "Timeout 65 s", "Timeout 1 s (Params)",
  "Timeout replaced", "Timeout 1 s and 2 s" (6 cases). Of the 15 new mgmt cases: 6 pass on both kernels,
  8 fail on both (CO-12), 1 fails on plain only (CO-38). 6 + 8 = the 14 cases of 1/3.
- No unexpected verdict change.

mesh-tester, 10 cases per run: 8 Passed, 2 Failed on both kernels in all runs; the failures are
"Mesh - Send cancel - 1" and "- 2" (existing cases, not touched by the series, same on both kernels).
The new "Mesh - Send (Ext Adv Duration)" passes on both kernels (a 1000 ms mesh timeout needs no clamp).

Guest log scan [measured]: python3 -I scripts/kernel-report-scan.py over all 12 guest logs: all "clean"
(logs/kernel-report-scan.txt, exit 0); additionally `grep -c -a -E "KASAN|lockdep|WARNING|BUG"` = 0 in each of
the 12 logs.

## BlueZ CI bot checks, run locally [measured]

Tool: botroot/scripts/bot-ci-local.sh (a copy of the project's scripts/ directory, because the script needs its
output and mails inside its own root; the project checkout was not written), image bluez-action-ci:60348956fc7b
(bluez/action-ci main 60348956fc7b), `--space user --base 14bd6ab65f4a647302edbd6df27f6faa91bee8a8`,
`--kernel-image` = bzImage-plain, mails = the three patches with the real From: (the placeholder cannot be
applied by git am as an identity).

Run 1 (botroot/out-bluez2, patched side and base side; --tree = the area's BlueZ worktree):

| check | patched | base |
|---|---|---|
| CheckPatch | PASS (0 errors, 0 warnings, 559 + 32 + 44 lines) | not run on base |
| GitLint | PASS | not run on base |
| BuildEll | PASS | PASS |
| BluezMake | PASS | PASS |
| CheckSmatch | PASS | PASS |
| bluezmakeextell | PASS | PASS |
| TestFunctional | FAIL (test_bluetoothctl_pair_bredr, pexpect timeout "Changing pairable on succeeded") | PASS |
| IncrementalBuild | FAIL "Failed to reset to base commit" | not run on base |
| ScanBuild | FAIL "Setup failed" / "Failed to checkout to patched branch" | FAIL "Setup failed" |

The IncrementalBuild and ScanBuild failures are a local setup defect, not findings: the shared clone made from a
worktree has an alternates path into cache/bluez-upstream/.git/objects, which the container does not mount
("unable to normalize alternate object path", harness.log). The same failure hits the base side's ScanBuild.

Run 2 (botroot/out-bluez3, patched side only, `--only TestFunctional,IncrementalBuild,ScanBuild`,
--tree /root/exp/qca9377-bt-hang/cache/bluez-upstream, read only): TestFunctional PASS (531 s),
IncrementalBuild PASS (258 s), ScanBuild PASS (846 s); exit 0.

Judgement: no check differs from base once the setup defect is removed. The single TestFunctional failure of
run 1 did not repeat in run 2, on the same patched tree. The series changes only tools/mgmt-tester.c and
tools/mesh-tester.c, which test_bluetoothctl_pair_bredr does not use [inferred], so it is judged flaky; it was
re-run once only (scripts/functional-repeat.sh not used). Run 1's patched TestFunctional took 934 s against
522 s on base and 531 s in run 2 (slow run, pexpect timeout).
ScanBuild in this bot compares the patched tree with itself (known, tooling-index), so its PASS is weak.

## Not done / caveats

- The whole `bot-ci-local.sh --space kernel` check set for the kernel patch was not run (task asked only for
  checkpatch on it). The fix compiled in the QEMU kernel build; img/build-fix.log has no "warning:" or "error:" line.
- The 16 cases were run on the plain tip and the fix tip only; the CO-12 clamp kernel was not rebuilt here.
- Problem 5 of the brief: see the count above; problem 2: the fix was now tested alone; problem 1: base-commit is
  the public bluetooth-next tip; problems 3 and 4: renumbered, rebuilt on public master.
```

---

## 5. CO-04 — MGMT: a use-after-free in `mesh_send_sync()`

**The defect** (a syzbot report; `Fixes: b338d91703fa`, `Cc: stable`). `mesh_send()` tests
`HCI_MESH_SENDING` under `hdev->lock`, but the completion paths clear it without the lock before
`mesh_next()` queues the next start, so a Mesh Send in between can queue a second start for the
same request; if the first start fails and frees it, the second reads freed memory (the patch's
message has the KASAN trace). The patch keeps the flag set until the next-or-idle decision is made
under `hdev->lock`, and takes `hdev->lock` nowhere under `cmd_sync_work_lock`.

**Tested** (bluetooth-next `1081a6ef8f1e0`, 2026-10-29): no lockdep or KASAN report in 48 boots
per image of the mesh tests, verdicts unchanged; the bot's checks pass. The use-after-free itself
was not reproduced. A different fix for the same report is pending on the list (patchwork
14888791, now archived); in the same boots it showed a lock-order inversion in 8 of 12. **Being
refreshed today on the current tip.**

**Questions for you.** Whether the hand-over closes every path the syzbot trace shows, and
whether "not reproduced" needs saying below the `---`.

**`contributions/CO-04-mesh-test-14888791/patch/0001-Bluetooth-MGMT-Fix-use-after-free-in-mesh_send_sync.patch`** (SHA-256 `f0ee05e2b1b1de932523f40e0766a67bdc0d77ad1abc8ac2a480044445a288c8`)

```diff
From 6d7ae083f6165f1d3e90508edb1c8ecf0f1af74c Mon Sep 17 00:00:00 2001
From: Iaroslav Voitovych <yaroslav.voytovych@gmail.com>
Date: Thu, 29 Oct 2026 11:51:17 +0100
Subject: [PATCH] Bluetooth: MGMT: Fix use-after-free in mesh_send_sync()

mesh_send() tests HCI_MESH_SENDING under hdev->lock and, when it is
clear, queues mesh_send_sync() for the request it has just added.
mesh_send_start_complete(), after a failed start, and
mesh_send_done_sync() clear the flag without hdev->lock and only then
complete the finished request and call mesh_next(), which queues
mesh_send_sync() for the head of hdev->mesh_pending. A Mesh Send that
runs in between sees the flag clear and queues a start for its new
request. When that request is the head, mesh_next() queues a second
start for the same mgmt_mesh_tx, as hci_cmd_sync_queue() does not
check for duplicates. If the first start fails,
mesh_send_start_complete() frees the request and the second start
reads it:

  BUG: KASAN: slab-use-after-free in mesh_send_sync+0x3de/0x440
  Read of size 1 at addr ffff88804e2ea83b by task kworker/u34:4/5875
  Workqueue: hci0 hci_cmd_sync_work
  ...
  Freed by task 5875:
   kfree+0x22b/0x6d0 mm/slub.c:6802
   mesh_send_complete net/bluetooth/mgmt.c:1090 [inline]
   mesh_send_start_complete+0x1a1/0x210 net/bluetooth/mgmt.c:2314
   hci_cmd_sync_work+0x20a/0x4c0 net/bluetooth/hci_sync.c:338

The byte read, 59 bytes into the 96-byte object, is send->cnt. When
the first start succeeds instead, the same packet is started twice.

Keep the flag set until the decision to start the next request or to
go idle has been made, and make that decision under hdev->lock, the
lock mesh_send() tests the flag under. mesh_next() now runs with
hdev->lock held and either queues the start of the head or clears the
flag when nothing is pending. It is called from mesh_send_done_sync()
itself, after a failed start, and from send_cancel(), which also takes
hdev->lock and hands over when it dequeued the queued start or found
mesh sending idle.

hdev->lock is not taken under cmd_sync_work_lock: hci_cmd_sync_dequeue()
and hci_cmd_sync_clear() call mesh_send_start_complete() with
-ECANCELED while holding it, and MGMT calls hci_cmd_sync_queue(), which
takes it, with hdev->lock held. On -ECANCELED the callback therefore
only completes the request, as before; from send_cancel() hdev->lock
is already held. mesh_send_done_sync() no longer has a destroy
callback, so hci_cmd_sync_clear() no longer calls hci_cmd_sync_queue()
through mesh_next() at unregister. hdev->lock is not held across any
HCI command.

Fixes: b338d91703fa ("Bluetooth: Implement support for Mesh")
Reported-by: syzbot+f20755f37da70df33a16@syzkaller.appspotmail.com
Closes: https://syzkaller.appspot.com/bug?extid=f20755f37da70df33a16
Cc: stable@vger.kernel.org
Signed-off-by: Iaroslav Voitovych <yaroslav.voytovych@gmail.com>
---
An earlier proposal for this report,
https://lore.kernel.org/all/20261014160504.42527-1-igorpetindev@gmail.com/
takes hdev->lock in mesh_next() and mesh_send_start_complete(), which
hci_cmd_sync_clear() calls with cmd_sync_work_lock held, while MGMT
holds hdev->lock when it calls hci_cmd_sync_queue(); lockdep reports
that order inversion. Here hdev->lock is taken only where
cmd_sync_work_lock is not held.

This conflicts textually with the pending "Bluetooth: MGMT: protect
hdev->mesh_pending with hdev->lock",
https://lore.kernel.org/all/20260807101529.17348-3-baul.lee@xbow.com/
which uses the same -ECANCELED rule but still clears the flag before
the hand-over and no longer applies to bluetooth-next, and with
"Bluetooth: mgmt: handle mesh send completion queue failure",
https://lore.kernel.org/all/20261003081205.433725-1-yaojiale02@163.com/
which calls mesh_next() with its old arguments.

Not tested with syzbot's reproducer; the analysis is from the report
and the source. Tested on bluetooth-next 1081a6ef8f1e0 in a 4 CPU QEMU
guest with BlueZ's emulated controller, KASAN and lockdep:
mgmt-tester (515 cases) and mesh-tester (10) pass with the patch, and
a set of mesh transmit tests (queueing, cancel, power off, socket
close, controller removal; 48 boots per kernel) gives the same results
with and without it, apart from timing-dependent cases that also vary
between unpatched runs. No lockdep, KASAN or WARNING report, so the
new lockdep_assert_held() did not fire; KCSAN, 20 boots, reported
nothing in the changed functions.

 net/bluetooth/mgmt.c | 96 +++++++++++++++++++++++++++++++-------------
 1 file changed, 68 insertions(+), 28 deletions(-)

diff --git a/net/bluetooth/mgmt.c b/net/bluetooth/mgmt.c
index 3cb4f9ece83cb..0d78bd65f2239 100644
--- a/net/bluetooth/mgmt.c
+++ b/net/bluetooth/mgmt.c
@@ -1095,37 +1095,53 @@ static void mesh_send_complete(struct hci_dev *hdev,
 	mgmt_mesh_remove(mesh_tx);
 }
 
-static int mesh_send_done_sync(struct hci_dev *hdev, void *data)
+static int mesh_send_sync(struct hci_dev *hdev, void *data);
+static void mesh_send_start_complete(struct hci_dev *hdev, void *data, int err);
+
+/* Queue the start of the oldest pending transmission, or mark mesh
+ * sending idle when nothing is pending. Called with hdev->lock held by
+ * whoever is done with the current transmission. HCI_MESH_SENDING stays
+ * set from the moment a start is queued until this hand-over, so
+ * mesh_send(), which tests the flag under the same lock, cannot queue a
+ * start of its own for an entry that is handed over here as well.
+ */
+static void mesh_next(struct hci_dev *hdev)
 {
 	struct mgmt_mesh_tx *mesh_tx;
 
-	hci_dev_clear_flag(hdev, HCI_MESH_SENDING);
-	if (list_empty(&hdev->adv_instances))
-		hci_disable_advertising_sync(hdev);
-	mesh_tx = mgmt_mesh_next(hdev, NULL);
+	lockdep_assert_held(&hdev->lock);
+
+	while ((mesh_tx = mgmt_mesh_next(hdev, NULL))) {
+		if (!hci_cmd_sync_queue(hdev, mesh_send_sync, mesh_tx,
+					mesh_send_start_complete)) {
+			hci_dev_set_flag(hdev, HCI_MESH_SENDING);
+			return;
+		}
 
-	if (mesh_tx)
 		mesh_send_complete(hdev, mesh_tx, false);
+	}
 
-	return 0;
+	hci_dev_clear_flag(hdev, HCI_MESH_SENDING);
 }
 
-static int mesh_send_sync(struct hci_dev *hdev, void *data);
-static void mesh_send_start_complete(struct hci_dev *hdev, void *data, int err);
-static void mesh_next(struct hci_dev *hdev, void *data, int err)
+static int mesh_send_done_sync(struct hci_dev *hdev, void *data)
 {
-	struct mgmt_mesh_tx *mesh_tx = mgmt_mesh_next(hdev, NULL);
+	struct mgmt_mesh_tx *mesh_tx;
 
-	if (!mesh_tx)
-		return;
+	if (list_empty(&hdev->adv_instances))
+		hci_disable_advertising_sync(hdev);
 
-	err = hci_cmd_sync_queue(hdev, mesh_send_sync, mesh_tx,
-				 mesh_send_start_complete);
+	hci_dev_lock(hdev);
 
-	if (err < 0)
+	mesh_tx = mgmt_mesh_next(hdev, NULL);
+	if (mesh_tx)
 		mesh_send_complete(hdev, mesh_tx, false);
-	else
-		hci_dev_set_flag(hdev, HCI_MESH_SENDING);
+
+	mesh_next(hdev);
+
+	hci_dev_unlock(hdev);
+
+	return 0;
 }
 
 static void mesh_send_done(struct work_struct *work)
@@ -1136,7 +1152,7 @@ static void mesh_send_done(struct work_struct *work)
 	if (!hci_dev_test_flag(hdev, HCI_MESH_SENDING))
 		return;
 
-	hci_cmd_sync_queue(hdev, mesh_send_done_sync, NULL, mesh_next);
+	hci_cmd_sync_queue(hdev, mesh_send_done_sync, NULL, NULL);
 }
 
 static void mgmt_init_hdev(struct sock *sk, struct hci_dev *hdev)
@@ -2314,11 +2330,22 @@ static void mesh_send_start_complete(struct hci_dev *hdev, void *data, int err)
 	/* Report any errors here, but don't report completion */
 
 	if (mgmt_err) {
-		hci_dev_clear_flag(hdev, HCI_MESH_SENDING);
+		/* -ECANCELED: the start was dequeued before it ran, by
+		 * send_cancel() or by hci_cmd_sync_clear(), both with
+		 * cmd_sync_work_lock held. hdev->lock must not be taken
+		 * under it; send_cancel() holds it already and hands over
+		 * itself.
+		 */
+		if (err == -ECANCELED) {
+			mesh_send_complete(hdev, mesh_tx, false);
+			return;
+		}
+
+		hci_dev_lock(hdev);
 		/* Send Complete Error Code for handle */
 		mesh_send_complete(hdev, mesh_tx, false);
-		if (err != -ECANCELED)
-			mesh_next(hdev, NULL, 0);
+		mesh_next(hdev);
+		hci_dev_unlock(hdev);
 		return;
 	}
 
@@ -2423,14 +2450,19 @@ static int send_cancel(struct hci_dev *hdev, void *data)
 	struct mgmt_pending_cmd *cmd = data;
 	struct mgmt_cp_mesh_send_cancel *cancel = (void *)cmd->param;
 	struct mgmt_mesh_tx *mesh_tx;
+	bool dequeued = false;
+
+	hci_dev_lock(hdev);
 
 	if (!cancel->handle) {
 		do {
 			mesh_tx = mgmt_mesh_next(hdev, cmd->sk);
 
 			if (mesh_tx) {
-				if (!hci_cmd_sync_dequeue(hdev, mesh_send_sync,
-							  mesh_tx, NULL))
+				if (hci_cmd_sync_dequeue(hdev, mesh_send_sync,
+							 mesh_tx, NULL))
+					dequeued = true;
+				else
 					mesh_send_complete(hdev, mesh_tx, false);
 			}
 		} while (mesh_tx);
@@ -2438,8 +2470,10 @@ static int send_cancel(struct hci_dev *hdev, void *data)
 		mesh_tx = mgmt_mesh_find(hdev, cancel->handle);
 
 		if (mesh_tx && mesh_tx->sk == cmd->sk) {
-			if (!hci_cmd_sync_dequeue(hdev, mesh_send_sync,
-						  mesh_tx, NULL))
+			if (hci_cmd_sync_dequeue(hdev, mesh_send_sync,
+						 mesh_tx, NULL))
+				dequeued = true;
+			else
 				mesh_send_complete(hdev, mesh_tx, false);
 		}
 	}
@@ -2447,8 +2481,14 @@ static int send_cancel(struct hci_dev *hdev, void *data)
 	mgmt_cmd_complete(cmd->sk, hdev->id, MGMT_OP_MESH_SEND_CANCEL,
 			  0, NULL, 0);
 
-	if (!hci_dev_test_flag(hdev, HCI_MESH_SENDING))
-		mesh_next(hdev, NULL, 0);
+	/* A dequeued start was the next transmission and nobody else will
+	 * hand over for it. A cancelled transmission that is already on air
+	 * is handed over by mesh_send_done_sync().
+	 */
+	if (dequeued || !hci_dev_test_flag(hdev, HCI_MESH_SENDING))
+		mesh_next(hdev);
+
+	hci_dev_unlock(hdev);
 
 	return 0;
 }

base-commit: 1081a6ef8f1e0661fd52eb3f878691b0b96cdff9
-- 
2.43.0

```

---

## 6. CO-05 + CO-26 — `mesh_send_sync()` and the advertising list

**The defects.** (1) `mesh_send_sync()` adds and removes an advertising instance without
`hdev->lock`, while other paths walk the list under it (lockdep and KCSAN warnings). (2) When the
add fails, it loses the error and schedules an instance that does not exist (`Fixes:
b338d91703fa`).

**Tested** (bluetooth-next `1081a6ef8f1e0`, 2026-10-29): warnings 3 → 0; KCSAN reports in
`mesh_send_sync()` 1 → 0 of 45 boots; a fault-injection trace for (2); the bot's checks pass.
**Being refreshed today on the current tip.**

**Questions for you.** The series order relative to item 5 (they touch the same function), and
whether patch 2 belongs in the same series or alone.

**`contributions/CO-05-mesh-adv-list-lock-i12/patch/0000-cover-letter.patch`** (SHA-256 `547b8dd91b515d1ddff7405ded03cd9adeb35c60f73647963c53807ed1f8cb21`)

```diff
From 0e1fa9ca43d972e9ae92a97a9e79066ac4be2bb1 Mon Sep 17 00:00:00 2001
From: Iaroslav Voitovych <yaroslav.voytovych@gmail.com>
Date: Thu, 29 Oct 2026 13:36:21 +0100
Subject: [PATCH 0/2] Bluetooth: MGMT: mesh_send_sync() and the advertising list

mesh_send_sync() adds the mesh packet's advertising instance with
hci_add_adv_instance() without hdev->lock, which that function
requires, and reads the instance count and walks the instance list
unlocked while Add Advertising changes them under the lock (1/2). When
the add fails, it carries on and schedules an instance that was never
added (2/2).

Notes:
- 1/2 takes hdev->lock after req_lock, as hci_clear_adv_sync() and
  hci_remove_adv_sync() do, and drops it before
  hci_schedule_adv_instance_sync(), which sends HCI commands. That
  function still looks the instance up without the lock; it is shared
  with other callers and is left alone here.
- The same lock was part of an earlier patch that was withdrawn:
  https://lore.kernel.org/all/20260919112517.3871992-1-benquike@gmail.com/
- Three other callers change the advertising list without hdev->lock
  (ISO broadcast, Set LE off and the advertising timeout); they are
  not part of this series.
- The lifetime of the mgmt_mesh_tx that mesh_send_sync() reads is a
  separate fix, "Bluetooth: MGMT: Fix use-after-free in
  mesh_send_sync()"; the two apply in either order.

Tested on bluetooth-next 1081a6ef8f1e0 in a 4 CPU QEMU guest with
BlueZ's emulated controller, KASAN and lockdep. With
lockdep_assert_held(&hdev->lock) added to hci_add_adv_instance() for
the test only, mesh-tester warned three times from mesh_send_sync()
without the series and not with it. KCSAN, 45 boots each, of a test
that adds and removes an advertising instance on one socket while
another socket sends mesh packets: without the series, one boot
reported races in mesh_send_sync() itself and three in
hci_schedule_adv_instance_sync() called from it; with the series, none
in mesh_send_sync(), and one boot reported a race below
hci_start_adv_sync(), which the series does not change. mgmt-tester
(515 cases) and mesh-tester (10) pass with the series; no lockdep,
KASAN or WARNING report.

Iaroslav Voitovych (2):
  Bluetooth: MGMT: Take hdev->lock in mesh_send_sync()
  Bluetooth: MGMT: Stop mesh_send_sync() when it cannot add the instance

 net/bluetooth/mgmt.c | 21 ++++++++++++++-------
 1 file changed, 14 insertions(+), 7 deletions(-)


base-commit: 1081a6ef8f1e0661fd52eb3f878691b0b96cdff9
-- 
2.43.0

```

**`contributions/CO-05-mesh-adv-list-lock-i12/patch/0001-Bluetooth-MGMT-Take-hdev-lock-in-mesh_send_sync.patch`** (SHA-256 `774db32af7abecf338c20bb49c09aa54a608864b4f241e120ec07ac821733761`)

```diff
From 30e3424fba50ca927af513fdb6a6775af5c39ae7 Mon Sep 17 00:00:00 2001
From: Iaroslav Voitovych <yaroslav.voytovych@gmail.com>
Date: Wed, 21 Oct 2026 07:43:46 +0200
Subject: [PATCH 1/2] Bluetooth: MGMT: Take hdev->lock in mesh_send_sync()

mesh_send_sync() runs on the cmd_sync worker, which holds req_lock but
not hdev->lock. It adds the packet's advertising instance with
hci_add_adv_instance(), which requires hdev->lock, and it reads
hdev->adv_instance_cnt, hdev->cur_adv_instance and
hdev->adv_instance_timeout and walks hdev->adv_instances through
hci_get_next_instance() without it.

Add Advertising changes the same list and counters under hdev->lock from
the MGMT socket, so on SMP the two can run at the same time. KCSAN
reports it, for example:

  BUG: KCSAN: data-race in hci_add_adv_instance / mesh_send_sync

  write to 0xffffa29c413d5dc0 of 4 bytes by task 61 on cpu 1:
   hci_add_adv_instance+0x463/0x490
   add_advertising+0x3e7/0x6b0
   hci_sock_sendmsg+0x924/0xfb0
  read to 0xffffa29c413d5dc0 of 4 bytes by task 70 on cpu 2:
   mesh_send_sync+0x3e/0x1c0
   hci_cmd_sync_work+0x172/0x230
  value changed: 0x00000001 -> 0x00000002

The reader there is the capacity check, so the check and the add are
not atomic with respect to Add Advertising either.

Take hdev->lock after the worker has taken req_lock, the order
hci_clear_adv_sync() and hci_remove_adv_sync() already use, around the
capacity check, the add and the list walk. Drop it before
hci_schedule_adv_instance_sync(), which sends HCI commands and must not
run under hdev->lock; only the instance number is carried across the
unlock, never the adv_info pointer.

hci_schedule_adv_instance_sync() looks the instance up without the lock
itself. It is shared with other callers and is not changed here.

Fixes: b338d91703fa ("Bluetooth: Implement support for Mesh")
Signed-off-by: Iaroslav Voitovych <yaroslav.voytovych@gmail.com>
---
 net/bluetooth/mgmt.c | 8 +++++++-
 1 file changed, 7 insertions(+), 1 deletion(-)

diff --git a/net/bluetooth/mgmt.c b/net/bluetooth/mgmt.c
index 3cb4f9ece83cb..8f7f3cdb2eebc 100644
--- a/net/bluetooth/mgmt.c
+++ b/net/bluetooth/mgmt.c
@@ -2336,8 +2336,12 @@ static int mesh_send_sync(struct hci_dev *hdev, void *data)
 	u16 timeout, duration;
 	int err = 0;
 
-	if (hdev->le_num_of_adv_sets <= hdev->adv_instance_cnt)
+	hci_dev_lock(hdev);
+
+	if (hdev->le_num_of_adv_sets <= hdev->adv_instance_cnt) {
+		hci_dev_unlock(hdev);
 		return MGMT_STATUS_BUSY;
+	}
 
 	timeout = 1000;
 	duration = send->cnt * INTERVAL_TO_MS(hdev->le_adv_max_interval);
@@ -2375,6 +2379,8 @@ static int mesh_send_sync(struct hci_dev *hdev, void *data)
 		instance = 0;
 	}
 
+	hci_dev_unlock(hdev);
+
 	if (instance)
 		return hci_schedule_adv_instance_sync(hdev, instance, true);
 
-- 
2.43.0

```

**`contributions/CO-05-mesh-adv-list-lock-i12/patch/0002-Bluetooth-MGMT-Stop-mesh_send_sync-when-it-cannot-ad.patch`** (SHA-256 `8326c8dab14d0bbe5434b2270c10a7d1797e07e10d036b56c4b98a3ef0c86176`)

```diff
From 0e1fa9ca43d972e9ae92a97a9e79066ac4be2bb1 Mon Sep 17 00:00:00 2001
From: Iaroslav Voitovych <yaroslav.voytovych@gmail.com>
Date: Wed, 21 Oct 2026 07:43:50 +0200
Subject: [PATCH 2/2] Bluetooth: MGMT: Stop mesh_send_sync() when it cannot add
 the instance

When hci_add_adv_instance() fails, mesh_send_sync() keeps the error in
err and carries on. It then returns the result of
hci_schedule_adv_instance_sync() for an instance that was never added,
and the original error is lost.

Return the error at once instead. hci_schedule_adv_instance_sync() is no
longer called for a missing instance and mesh_send_start_complete()
gets the real error.

With a failing allocation injected into hci_add_adv_instance() for the
first Mesh Send, as seen in a kprobe trace of bluetooth-next
1081a6ef8f1e0:

  before: hci_add_adv_instance -> -ENOMEM, then
          hci_schedule_adv_instance_sync(instance 6) -> -ENOENT,
          mesh_send_sync -> -2, mesh_send_start_complete(err=-2)
  after:  hci_add_adv_instance -> -ENOMEM,
          mesh_send_sync -> -12, mesh_send_start_complete(err=-12)

User space gets the same Mesh Packet Complete event in both cases, so
this is a cleanup of the error path and not a change in what a client
sees.

Fixes: b338d91703fa ("Bluetooth: Implement support for Mesh")
Signed-off-by: Iaroslav Voitovych <yaroslav.voytovych@gmail.com>
---
 net/bluetooth/mgmt.c | 13 +++++++------
 1 file changed, 7 insertions(+), 6 deletions(-)

diff --git a/net/bluetooth/mgmt.c b/net/bluetooth/mgmt.c
index 8f7f3cdb2eebc..e11925b707d5f 100644
--- a/net/bluetooth/mgmt.c
+++ b/net/bluetooth/mgmt.c
@@ -2334,7 +2334,6 @@ static int mesh_send_sync(struct hci_dev *hdev, void *data)
 	struct adv_info *adv, *next_instance;
 	u8 instance = hdev->le_num_of_adv_sets + 1;
 	u16 timeout, duration;
-	int err = 0;
 
 	hci_dev_lock(hdev);
 
@@ -2354,10 +2353,12 @@ static int mesh_send_sync(struct hci_dev *hdev, void *data)
 				   hdev->le_adv_max_interval,
 				   mesh_tx->handle);
 
-	if (!IS_ERR(adv))
-		mesh_tx->instance = instance;
-	else
-		err = PTR_ERR(adv);
+	if (IS_ERR(adv)) {
+		hci_dev_unlock(hdev);
+		return PTR_ERR(adv);
+	}
+
+	mesh_tx->instance = instance;
 
 	if (hdev->cur_adv_instance == instance) {
 		/* If the currently advertised instance is being changed then
@@ -2384,7 +2385,7 @@ static int mesh_send_sync(struct hci_dev *hdev, void *data)
 	if (instance)
 		return hci_schedule_adv_instance_sync(hdev, instance, true);
 
-	return err;
+	return 0;
 }
 
 static void send_count(struct mgmt_mesh_tx *mesh_tx, void *data)
-- 
2.43.0

```

---

## 7. CO-35 — the L2CAP ECRED deferred-accept hang, for stable

**The defect.** With a deferred ECRED accept, the socket lock is taken twice on the same path, a
self-deadlock present since v6.3 (`9aa9d9473f15`). Pauli Virtanen fixed it in mainline with
`608e0b7a675b` and `32d86e048d8e` (7.4 merge window), without `Cc: stable`; neither is in a stable
release or queue (checked 2026-11-14).

**This package:** a request that 7.3.y take the two commits as they are; backports of the pair for
6.18.y, 6.12.y and 6.6.y as `[PATCH <line> 0/2]` series (code changed only where the older trees
need it); and a separate request for 7.3.y to take `5874f8d03268`, without which plain v7.3 fails
l2cap-tester's SCI cases for an unrelated reason (7.3.4 still lacks it). **Tested again on today's
tips** (2026-11-14, QEMU, 4 CPUs, hung-task detector): "L2CAP Ext-Flowctl Server - Accept 2 Close
1" hangs on unpatched v7.3.4, v6.18.63, v6.12.117 and v6.6.162 (7 hung-task reports each) and
passes with the pair (1.0 to 1.2 s); the whole l2cap-tester with the pair: 7.3.4 111/111 with the
SCI fix, and on the older lines the same non-passes as on 11-02 (18 "Set PHY" cases on 6.18.y;
32 on 6.12.y and 6.6.y). An unpatched full run cannot finish there (it hangs), so that these are
not the pair's rests on the pooled case verdicts of 11-01. No lockdep, KASAN or hung-task report
patched. The
backports are byte-identical to the 11-02 ones; only the covers' release numbers changed. 6.1.y,
5.15.y and 5.10.y also carry the bug and are not covered (patch 2 conflicts there).

**Questions for you.** The backports' changes against the mainline commits (the cover letters
list them); whether the two requests should be one mail.

**`contributions/CO-35-l2cap-ecred-defer-hang-stable/send-20261114/mail/request-v4-20261114.eml`** (SHA-256 `43cb9c09cbd6d0f4a47891ff9636537662c1359af7566cc0345d03cafe39bea1`)

```text
From: Iaroslav Voitovych <yaroslav.voytovych@gmail.com>
To: stable@vger.kernel.org
Cc: Pauli Virtanen <pav@iki.fi>,
 Marcel Holtmann <marcel@holtmann.org>,
 Luiz Augusto von Dentz <luiz.dentz@gmail.com>,
 linux-bluetooth@vger.kernel.org
Subject: Please backport 608e0b7a675b and 32d86e048d8e to 7.3.y

Hello,

please apply these two mainline commits to 7.3.y, in this order:

  608e0b7a675b2affbbf38167cad0fa63d8e064f7
  ("Bluetooth: L2CAP: add l2cap_chan_close_unlocked() and locking
  helpers")

  32d86e048d8efedb7aa6cbbd3c36c3c435401c92
  ("Bluetooth: L2CAP: hold conn->lock for
  __l2cap_ecred_conn_rsp_defer")

The second fixes ab4eedb790ca ("Bluetooth: L2CAP: Fix corrupted list in
hci_chan_del"), which 7.3.y has. The deadlock path it removes predates
ab4eedb790ca; it comes from 9aa9d9473f15 (v6.3). The second commit
calls l2cap_chan_lock_conn() and l2cap_chan_unlock_conn(), which only
the first adds. The first changes 78 lines (a 149-line diff), more
than the 100 lines the stable rules allow; I am asking for it whole,
as merged, because that is the conservative choice compared with a
smaller locking patch written only for stable. Both are
in mainline since the 7.4 merge window (v7.4-rc1) and carry no Cc:
stable tag. They are patches 2 and 7 of the series "Bluetooth: L2CAP:
fix and annotate l2cap_conn::chan_l locking"; the other patches are not
needed for the problem below and were not tested here. One of them,
dc1ddc65f06d ("Bluetooth: L2CAP: take lock for l2cap_chan_del in
l2cap_ecred_rsp_defer"), is not requested: l2cap_ecred_rsp_defer()
calls l2cap_chan_del() on the sibling channels without their
chan->lock only in its refusal branch, which is a lock context issue
separate from the caller's own socket lock that hangs the case below;
the case passes with and without it.

Without them, BlueZ's l2cap-tester case "L2CAP Ext-Flowctl Server -
Accept 2 Close 1" (a deferred ECRED accept of two channels, the first
accepted and closed before the second) never finishes on v7.3.4: the
test stops after "Accept deferred setup". With CONFIG_DETECT_HUNG_TASK
enabled on v7.3.4, the tester's task is reported blocked holding its
socket's lock from l2cap_sock_recvmsg() while waiting for the same lock
in l2cap_sock_teardown_cb() (taken nested, so lockdep stays silent).
32d86e048d8e releases the socket lock before
__l2cap_ecred_conn_rsp_defer() is called.

Both commits cherry-pick cleanly onto v7.3.4. Tested in QEMU/KVM
(4 vCPUs) with BlueZ's doc/tester.config: with the two commits the case
passes; without them it never finishes. No lockdep or KASAN report.

On v7.3.4 the whole l2cap-tester stalls earlier, in an SCI case that
has nothing to do with these commits; I am asking for its fix in a
separate mail. With that fix and these two commits the whole
l2cap-tester passes 111 of 111 on v7.3.4.

6.18.y, 6.12.y and 6.6.y hang on the same case and need small
adjustments; backports for them follow as separate series.

6.1.y, 5.15.y and 5.10.y do not have ab4eedb790ca, and ECRED is off
there unless the bluetooth module parameter enable_ecred is set. With
it set, the case never finishes on v6.1.190, v5.15.223 and v5.10.272
either, and on v6.1.190 the hung-task detector shows the same two
socket locks. The two commits do not apply to those lines, so this
request does not cover them.

Thanks,
Iaroslav
```

**`contributions/CO-35-l2cap-ecred-defer-hang-stable/send-20261114/mail/request-sci-7.3.y-20261114.eml`** (SHA-256 `d2b125ede382e0d638269b1f5e0ae93248a9308fdf2190ee721ab24d698ac934`)

```text
From: Iaroslav Voitovych <yaroslav.voytovych@gmail.com>
To: stable@vger.kernel.org
Cc: Luiz Augusto von Dentz <luiz.dentz@gmail.com>,
 Marcel Holtmann <marcel@holtmann.org>,
 linux-bluetooth@vger.kernel.org
Subject: Please backport 5874f8d03268 (Bluetooth: SCI response fix) to 7.3.y

Hello,

please apply this mainline commit to 7.3.y:

  5874f8d03268d34189c6c12c56586b64d26a8bcc
  ("Bluetooth: Fix the LE Read Connection Interval response layout")

It fixes 2f8784cfe8a9 ("Bluetooth: Add support for Shorter Connection
Interval (SCI) feature"), which v7.3.4 has and v6.18.63 does not, so
7.3.y is the only stable line concerned. The commit is in mainline
since the 7.4 merge window (v7.4-rc1), carries a Fixes: tag, and is not
in queue-7.3 of the stable-queue tree (checked 2026-11-14 01:21 UTC);
v7.3.4 does not have it.

Without it, on v7.3.4 BlueZ's l2cap-tester stalls in the case "L2CAP LE
Client - SCI Fast Mode", which times out with "Invalid response length
for 0x20a3" in the kernel log, and the run does not get past it. The
commit cherry-picks cleanly onto v7.3.4. Tested in QEMU/KVM (4 vCPUs)
with BlueZ's doc/tester.config: with it applied, the eight SCI cases
pass, and with it and the two L2CAP commits from my other mail applied,
the whole l2cap-tester passes 111 of 111 on v7.3.4.

Thanks,
Iaroslav
```

**`contributions/CO-35-l2cap-ecred-defer-hang-stable/send-20261114/mail/6.18.y/0000-cover-letter-20261114.patch`** (SHA-256 `da40550b6510f686f58390860485cc6807401f0976dbab9a84e37a7b9feb3bc3`)

```diff
From e514ee712fa454c91dbe9ff7b5ebed5d1dbf053b Mon Sep 17 00:00:00 2001
From: Iaroslav Voitovych <yaroslav.voytovych@gmail.com>
Date: Sat, 14 Nov 2026 12:00:00 +0100
Subject: [PATCH 6.18.y 0/2] Bluetooth: L2CAP: fix the deferred ECRED accept hang

Hello,

this is a backport to 6.18.y of two mainline commits by Pauli Virtanen,
in this order:

  608e0b7a675b ("Bluetooth: L2CAP: add l2cap_chan_close_unlocked() and
  locking helpers")
  32d86e048d8e ("Bluetooth: L2CAP: hold conn->lock for
  __l2cap_ecred_conn_rsp_defer")

The second fixes ab4eedb790ca ("Bluetooth: L2CAP: Fix corrupted list in
hci_chan_del"), which 6.18.y has. It calls l2cap_chan_lock_conn() and
l2cap_chan_unlock_conn(), which only the first adds; the first is
78 changed lines (a 149-line diff), more than the 100 lines the stable
rules allow, and is sent whole as it was merged because that is the
conservative choice compared with a smaller locking patch written only
for stable. Neither carries Cc: stable. They are patches 2 and 7 of the
series "Bluetooth: L2CAP: fix and annotate l2cap_conn::chan_l
locking"; the other patches are not needed for the problem below and
were not tested here. One of them, dc1ddc65f06d ("Bluetooth: L2CAP:
take lock for l2cap_chan_del in l2cap_ecred_rsp_defer"), is not
requested: in v6.18.63, l2cap_ecred_rsp_defer() calls l2cap_chan_del()
on the sibling channels without their chan->lock only in its refusal
branch, which is a lock context issue separate from the caller's own
socket lock that hangs the case below.

Without them, BlueZ's l2cap-tester case "L2CAP Ext-Flowctl Server -
Accept 2 Close 1" never finishes on v6.18.63: the test stops after
"Accept deferred setup". With CONFIG_DETECT_HUNG_TASK enabled, the
tester's task is reported blocked holding its socket's lock from
l2cap_sock_recvmsg() and waiting for the same lock in
l2cap_sock_teardown_cb(); patch 2 releases the socket lock before
__l2cap_ecred_conn_rsp_defer().

The commits do not build on 6.18.y as they are. Deviations:
- patch 1: the context-analysis annotations 6.18.y lacks are dropped
  (__must_not_hold, the __cond_acquires on l2cap_chan_lock_conn(),
  __context_unsafe); the code is unchanged;
- patch 2: none.

Tested on v6.18.63 in QEMU/KVM (4 vCPUs) with BlueZ's
doc/tester.config: with the series the case passes, and the whole
l2cap-tester ends with 93 of 111 passed; all other non-passes are
pre-existing on plain v6.18.63 (features the tree lacks). Without the
series the case never finishes. No lockdep or KASAN report with the
series.

The two commits are requested for 7.3.y as they are, in a separate
mail; backports for 6.12.y and 6.6.y are separate series.

Thanks,
Iaroslav

Pauli Virtanen (2):
  Bluetooth: L2CAP: add l2cap_chan_close_unlocked() and locking helpers
  Bluetooth: L2CAP: hold conn->lock for __l2cap_ecred_conn_rsp_defer

 include/net/bluetooth/l2cap.h | 16 +++++++++
 net/bluetooth/l2cap_core.c    | 60 ++++++++++++++++++++++++++++---
 net/bluetooth/l2cap_sock.c    | 68 ++++++++++++++++++++++++-----------
 3 files changed, 119 insertions(+), 25 deletions(-)


base-commit: 1cdda838e8475edf89b73ff0cc952005dd0b1fa7
-- 
2.43.0

```

**`contributions/CO-35-l2cap-ecred-defer-hang-stable/send-20261114/mail/6.18.y/0001-Bluetooth-L2CAP-add-l2cap_chan_close_unlocked-and-lo.patch`** (SHA-256 `edd7ebe755c695b55945f175f85264b0f3185f939c6bed899bfca5881d4e56dc`)

```diff
From 7413635ff762800d3f856de42cd0fc3727ad2bb0 Mon Sep 17 00:00:00 2001
From: Pauli Virtanen <pav@iki.fi>
Date: Sat, 29 Aug 2026 17:19:57 +0300
Subject: [PATCH 6.18.y 1/2] Bluetooth: L2CAP: add l2cap_chan_close_unlocked()
 and locking helpers

[ Upstream commit 608e0b7a675b2affbbf38167cad0fa63d8e064f7 ]

l2cap_chan_close() requires holding chan->lock and chan->conn->lock if
associated chan->conn exists, to guard eg. conn->chan_l. Taking the
locks with right ordering requires handling a race condition.

Add helper function l2cap_chan_(un)lock_conn that do the locking right.

Add l2cap_chan_close_unlocked() that does not require locks to be held,
as all callsites do this lock -> close -> unlock pattern.

Link: https://syzkaller.appspot.com/bug?extid=0e4ebcc970728e056324
Signed-off-by: Pauli Virtanen <pav@iki.fi>
Signed-off-by: Luiz Augusto von Dentz <luiz.von.dentz@intel.com>
[ backport: dropped the context-analysis annotations 6.18 lacks
  (__must_not_hold, __cond_acquires, __context_unsafe); code
  unchanged ]
Signed-off-by: Iaroslav Voitovych <yaroslav.voytovych@gmail.com>
---
 include/net/bluetooth/l2cap.h | 16 ++++++++++
 net/bluetooth/l2cap_core.c    | 60 ++++++++++++++++++++++++++++++++---
 2 files changed, 71 insertions(+), 5 deletions(-)

diff --git a/include/net/bluetooth/l2cap.h b/include/net/bluetooth/l2cap.h
index 2f7c367d68ce4..18c6990cd5f9c 100644
--- a/include/net/bluetooth/l2cap.h
+++ b/include/net/bluetooth/l2cap.h
@@ -963,6 +963,7 @@ int l2cap_add_scid(struct l2cap_chan *chan,  __u16 scid);
 
 struct l2cap_chan *l2cap_chan_create(void);
 void l2cap_chan_close(struct l2cap_chan *chan, int reason);
+void l2cap_chan_close_unlocked(struct l2cap_chan *chan, int reason);
 int l2cap_chan_connect(struct l2cap_chan *chan, __le16 psm, u16 cid,
 		       bdaddr_t *dst, u8 dst_type, u16 timeout);
 int l2cap_chan_reconfigure(struct l2cap_chan *chan, __u16 mtu);
@@ -988,4 +989,19 @@ void l2cap_conn_put(struct l2cap_conn *conn);
 int l2cap_register_user(struct l2cap_conn *conn, struct l2cap_user *user);
 void l2cap_unregister_user(struct l2cap_conn *conn, struct l2cap_user *user);
 
+bool l2cap_chan_lock_conn(struct l2cap_chan *chan)
+	__acquires(&chan->lock);
+
+/* Release macro for l2cap_chan_lock_conn, so context analysis understands it */
+#define l2cap_chan_unlock_conn(chan, conn_locked)			\
+	({								\
+		struct l2cap_chan *__chan = (chan);			\
+		struct l2cap_conn *__conn = __chan->conn;		\
+		l2cap_chan_unlock(__chan);				\
+		if (conn_locked) {					\
+			mutex_unlock(&__conn->lock);			\
+			l2cap_conn_put(__conn);				\
+		}							\
+	})
+
 #endif /* __L2CAP_H */
diff --git a/net/bluetooth/l2cap_core.c b/net/bluetooth/l2cap_core.c
index 462667a6e6ac2..4a92c6a7a08a9 100644
--- a/net/bluetooth/l2cap_core.c
+++ b/net/bluetooth/l2cap_core.c
@@ -62,6 +62,7 @@ static void l2cap_tx(struct l2cap_chan *chan, struct l2cap_ctrl *control,
 static void l2cap_retrans_timeout(struct work_struct *work);
 static void l2cap_monitor_timeout(struct work_struct *work);
 static void l2cap_ack_timeout(struct work_struct *work);
+static void __l2cap_chan_close(struct l2cap_chan *chan, int reason);
 
 static inline u8 bdaddr_type(u8 link_type, u8 bdaddr_type)
 {
@@ -433,7 +434,7 @@ static void l2cap_chan_timeout(struct work_struct *work)
 	else
 		reason = ETIMEDOUT;
 
-	l2cap_chan_close(chan, reason);
+	__l2cap_chan_close(chan, reason);
 
 	chan->ops->close(chan);
 
@@ -842,7 +843,7 @@ static void l2cap_chan_connect_reject(struct l2cap_chan *chan)
 	l2cap_send_cmd(conn, chan->ident, L2CAP_CONN_RSP, sizeof(rsp), &rsp);
 }
 
-void l2cap_chan_close(struct l2cap_chan *chan, int reason)
+static void __l2cap_chan_close(struct l2cap_chan *chan, int reason)
 {
 	struct l2cap_conn *conn = chan->conn;
 
@@ -891,8 +892,57 @@ void l2cap_chan_close(struct l2cap_chan *chan, int reason)
 		break;
 	}
 }
+
+void l2cap_chan_close(struct l2cap_chan *chan, int reason)
+{
+	__l2cap_chan_close(chan, reason);
+}
 EXPORT_SYMBOL(l2cap_chan_close);
 
+/* Take chan->lock. If chan->conn is non-NULL, take new reference on it, take
+ * chan->conn->lock, and return true. Otherwise return false.
+ */
+bool l2cap_chan_lock_conn(struct l2cap_chan *chan)
+{
+	/* Handle conn->lock > chan->lock ordering + race on chan->conn */
+	for (;;) {
+		struct l2cap_conn *conn;
+
+		l2cap_chan_lock(chan);
+		conn = chan->conn;
+		if (conn)
+			l2cap_conn_get(conn);
+		l2cap_chan_unlock(chan);
+
+		if (conn)
+			mutex_lock(&conn->lock);
+
+		l2cap_chan_lock(chan);
+
+		if (chan->conn != conn) {
+			l2cap_chan_unlock(chan);
+			if (conn) {
+				mutex_unlock(&conn->lock);
+				l2cap_conn_put(conn);
+			}
+			schedule();
+			continue;
+		}
+
+		return chan->conn;
+	}
+}
+
+void l2cap_chan_close_unlocked(struct l2cap_chan *chan, int reason)
+{
+	bool have_conn;
+
+	have_conn = l2cap_chan_lock_conn(chan);
+	__l2cap_chan_close(chan, reason);
+	l2cap_chan_unlock_conn(chan, have_conn);
+}
+EXPORT_SYMBOL(l2cap_chan_close_unlocked);
+
 static inline u8 l2cap_get_auth_type(struct l2cap_chan *chan)
 {
 	switch (chan->chan_type) {
@@ -1583,7 +1633,7 @@ static void l2cap_conn_start(struct l2cap_conn *conn)
 			if (!l2cap_mode_supported(chan->mode, conn->feat_mask)
 			    && test_bit(CONF_STATE2_DEVICE,
 					&chan->conf_state)) {
-				l2cap_chan_close(chan, ECONNRESET);
+				__l2cap_chan_close(chan, ECONNRESET);
 				l2cap_chan_unlock(chan);
 				continue;
 			}
@@ -1591,7 +1641,7 @@ static void l2cap_conn_start(struct l2cap_conn *conn)
 			if (l2cap_check_enc_key_size(conn->hcon, chan))
 				l2cap_start_connection(chan);
 			else
-				l2cap_chan_close(chan, ECONNREFUSED);
+				__l2cap_chan_close(chan, ECONNREFUSED);
 
 		} else if (chan->state == BT_CONNECT2) {
 			struct l2cap_conn_rsp rsp;
@@ -7647,7 +7697,7 @@ static inline void l2cap_check_encryption(struct l2cap_chan *chan, u8 encrypt)
 			__set_chan_timer(chan, L2CAP_ENC_TIMEOUT);
 		} else if (chan->sec_level == BT_SECURITY_HIGH ||
 			   chan->sec_level == BT_SECURITY_FIPS)
-			l2cap_chan_close(chan, ECONNREFUSED);
+			__l2cap_chan_close(chan, ECONNREFUSED);
 	} else {
 		if (chan->sec_level == BT_SECURITY_MEDIUM)
 			__clear_chan_timer(chan);
-- 
2.43.0

```

**`contributions/CO-35-l2cap-ecred-defer-hang-stable/send-20261114/mail/6.18.y/0002-Bluetooth-L2CAP-hold-conn-lock-for-__l2cap_ecred_con.patch`** (SHA-256 `e1971cb8a7b2e21d8cdce698fa249dd559ba94b4b6409fb5c0d1503d99d3e4f5`)

```diff
From e514ee712fa454c91dbe9ff7b5ebed5d1dbf053b Mon Sep 17 00:00:00 2001
From: Pauli Virtanen <pav@iki.fi>
Date: Sat, 29 Aug 2026 17:20:02 +0300
Subject: [PATCH 6.18.y 2/2] Bluetooth: L2CAP: hold conn->lock for
 __l2cap_ecred_conn_rsp_defer

[ Upstream commit 32d86e048d8efedb7aa6cbbd3c36c3c435401c92 ]

__l2cap_ecred_conn_rsp_defer() > __l2cap_chan_list_id() accesses
conn->chan_l which is guarded by conn->lock. The lock fails to be held
when calling from l2cap_sock.c.

Fix by using l2cap_chan_conn_lock(), and taking the locks in required
order l2cap_conn::lock > l2cap_chan::lock > sk.  Leave fast path with
sk->sk_state precheck.  Move the L2CAP defer handling to
l2cap_sock_defer().

The code should also take l2cap_chan_lock() for sibling channels, but
that needs separate fix due to lock nesting.

Fixes: ab4eedb790ca ("Bluetooth: L2CAP: Fix corrupted list in hci_chan_del")
Signed-off-by: Pauli Virtanen <pav@iki.fi>
Signed-off-by: Luiz Augusto von Dentz <luiz.von.dentz@intel.com>
Signed-off-by: Iaroslav Voitovych <yaroslav.voytovych@gmail.com>
---
 net/bluetooth/l2cap_sock.c | 68 +++++++++++++++++++++++++++-----------
 1 file changed, 48 insertions(+), 20 deletions(-)

diff --git a/net/bluetooth/l2cap_sock.c b/net/bluetooth/l2cap_sock.c
index e78866e02bfc2..9dfd4d088a67b 100644
--- a/net/bluetooth/l2cap_sock.c
+++ b/net/bluetooth/l2cap_sock.c
@@ -1220,40 +1220,68 @@ static void l2cap_publish_rx_avail(struct l2cap_chan *chan)
 		l2cap_chan_rx_avail(chan, -1);
 }
 
-static int l2cap_sock_recvmsg(struct socket *sock, struct msghdr *msg,
-			      size_t len, int flags)
+static int l2cap_sock_defer(struct sock *sk)
 {
-	struct sock *sk = sock->sk;
-	struct l2cap_pinfo *pi = l2cap_pi(sk);
-	int err;
+	struct l2cap_chan *chan = l2cap_pi(sk)->chan;
+	bool have_conn;
+	int err = 0;
 
-	if (unlikely(flags & MSG_ERRQUEUE))
-		return sock_recv_errqueue(sk, msg, len, SOL_BLUETOOTH,
-					  BT_SCM_ERROR);
+	/* Fast path check */
+	lock_sock(sk);
+	if (sk->sk_state != BT_CONNECT2) {
+		release_sock(sk);
+		return 0;
+	}
+	release_sock(sk);
 
+	have_conn = l2cap_chan_lock_conn(chan);
 	lock_sock(sk);
 
 	if (sk->sk_state == BT_CONNECT2 && test_bit(BT_SK_DEFER_SETUP,
 						    &bt_sk(sk)->flags)) {
-		if (pi->chan->mode == L2CAP_MODE_EXT_FLOWCTL) {
+		err = 1;
+
+		if (!have_conn) {
+			release_sock(sk);
+			err = -ENOTCONN;
+		} else if (chan->mode == L2CAP_MODE_EXT_FLOWCTL) {
 			sk->sk_state = BT_CONNECTED;
-			pi->chan->state = BT_CONNECTED;
-			__l2cap_ecred_conn_rsp_defer(pi->chan);
-		} else if (bdaddr_type_is_le(pi->chan->src_type)) {
+			chan->state = BT_CONNECTED;
+			release_sock(sk);
+			__l2cap_ecred_conn_rsp_defer(chan);
+		} else if (bdaddr_type_is_le(chan->src_type)) {
 			sk->sk_state = BT_CONNECTED;
-			pi->chan->state = BT_CONNECTED;
-			__l2cap_le_connect_rsp_defer(pi->chan);
+			chan->state = BT_CONNECTED;
+			release_sock(sk);
+			__l2cap_le_connect_rsp_defer(chan);
 		} else {
 			sk->sk_state = BT_CONFIG;
-			pi->chan->state = BT_CONFIG;
-			__l2cap_connect_rsp_defer(pi->chan);
+			chan->state = BT_CONFIG;
+			release_sock(sk);
+			__l2cap_connect_rsp_defer(chan);
 		}
-
-		err = 0;
-		goto done;
+	} else {
+		release_sock(sk);
 	}
 
-	release_sock(sk);
+	l2cap_chan_unlock_conn(chan, have_conn);
+	return err;
+}
+
+static int l2cap_sock_recvmsg(struct socket *sock, struct msghdr *msg,
+			      size_t len, int flags)
+{
+	struct sock *sk = sock->sk;
+	struct l2cap_pinfo *pi = l2cap_pi(sk);
+	int err;
+
+	if (unlikely(flags & MSG_ERRQUEUE))
+		return sock_recv_errqueue(sk, msg, len, SOL_BLUETOOTH,
+					  BT_SCM_ERROR);
+
+	err = l2cap_sock_defer(sk);
+	if (err)
+		return err < 0 ? err : 0;
 
 	if (sock->type == SOCK_STREAM)
 		err = bt_sock_stream_recvmsg(sock, msg, len, flags);
-- 
2.43.0

```

**`contributions/CO-35-l2cap-ecred-defer-hang-stable/send-20261114/mail/6.12.y/0000-cover-letter-20261114.patch`** (SHA-256 `9b6351aa1ffd4f9e070fc3185178d59c4efa5257b7d00ac8bc47a84f40a4aec8`)

```diff
From 9794c6835f5fa6b23d057423e1849b39ed776600 Mon Sep 17 00:00:00 2001
From: Iaroslav Voitovych <yaroslav.voytovych@gmail.com>
Date: Sat, 14 Nov 2026 12:00:00 +0100
Subject: [PATCH 6.12.y 0/2] Bluetooth: L2CAP: fix the deferred ECRED accept hang

Hello,

this is a backport to 6.12.y of two mainline commits by Pauli Virtanen,
in this order:

  608e0b7a675b ("Bluetooth: L2CAP: add l2cap_chan_close_unlocked() and
  locking helpers")
  32d86e048d8e ("Bluetooth: L2CAP: hold conn->lock for
  __l2cap_ecred_conn_rsp_defer")

The second fixes ab4eedb790ca ("Bluetooth: L2CAP: Fix corrupted list in
hci_chan_del"), which 6.12.y has as f87271d21dd4. It calls
l2cap_chan_lock_conn() and l2cap_chan_unlock_conn(), which only the
first adds; the first is 78 changed lines (a 149-line diff), more than
the 100 lines the stable rules allow, and is sent whole as it was
merged because that is the conservative choice compared with a smaller
locking patch written only for stable. Neither carries Cc: stable.
They are patches 2 and 7 of the series "Bluetooth: L2CAP: fix and
annotate l2cap_conn::chan_l locking"; the other patches are not needed
for the problem below and were not tested here. One of them,
dc1ddc65f06d ("Bluetooth: L2CAP: take lock for l2cap_chan_del in
l2cap_ecred_rsp_defer"), is not requested: in v6.12.117,
l2cap_ecred_rsp_defer() calls l2cap_chan_del() on the sibling channels
without their chan->lock only in its refusal branch, which is a lock
context issue separate from the caller's own socket lock that hangs the
case below.

Without them, BlueZ's l2cap-tester case "L2CAP Ext-Flowctl Server -
Accept 2 Close 1" never finishes on v6.12.117: the test stops after
"Accept deferred setup". With CONFIG_DETECT_HUNG_TASK enabled, the
tester's task is reported blocked holding its socket's lock from
l2cap_sock_recvmsg() and waiting for the same lock in
l2cap_sock_teardown_cb(); patch 2 releases the socket lock before
__l2cap_ecred_conn_rsp_defer().

On 6.12.y patch 1 does not build and patch 2 does not apply as they
are. Deviations:
- patch 1: the context-analysis annotations 6.12.y lacks are dropped
  (__must_not_hold, the __cond_acquires on l2cap_chan_lock_conn(),
  __context_unsafe); the code is unchanged;
- patch 2: l2cap_sock_recvmsg() in 6.12.y has no MSG_ERRQUEUE block,
  so the three MSG_ERRQUEUE lines that precede the new
  l2cap_sock_defer() call upstream are absent; l2cap_sock_defer() and
  its call are as upstream.

Tested on v6.12.117 in QEMU/KVM (4 vCPUs) with BlueZ's
doc/tester.config: with the series the case passes, and the whole
l2cap-tester ends with 79 of 111 passed; all other non-passes are
pre-existing on plain v6.12.117 (features the tree lacks). Without the
series the case never finishes. No lockdep or KASAN report with the
series.

The two commits are requested for 7.3.y as they are, in a separate
mail; backports for 6.18.y and 6.6.y are separate series.

Thanks,
Iaroslav

Pauli Virtanen (2):
  Bluetooth: L2CAP: add l2cap_chan_close_unlocked() and locking helpers
  Bluetooth: L2CAP: hold conn->lock for __l2cap_ecred_conn_rsp_defer

 include/net/bluetooth/l2cap.h | 16 +++++++++
 net/bluetooth/l2cap_core.c    | 60 ++++++++++++++++++++++++++++++---
 net/bluetooth/l2cap_sock.c    | 62 +++++++++++++++++++++++++----------
 3 files changed, 116 insertions(+), 22 deletions(-)


base-commit: d3417611a3b40b7f04a29e558cebac2bf69889d7
-- 
2.43.0

```

**`contributions/CO-35-l2cap-ecred-defer-hang-stable/send-20261114/mail/6.12.y/0001-Bluetooth-L2CAP-add-l2cap_chan_close_unlocked-and-lo.patch`** (SHA-256 `4d7788dcac0cc33f8283d0d1aefe9c1334f803b9942654ca58a8b5ebc9e26c4d`)

```diff
From f740f66b8116439e35aef67208a13dd6d10fd6d3 Mon Sep 17 00:00:00 2001
From: Pauli Virtanen <pav@iki.fi>
Date: Sat, 29 Aug 2026 17:19:57 +0300
Subject: [PATCH 6.12.y 1/2] Bluetooth: L2CAP: add l2cap_chan_close_unlocked()
 and locking helpers

[ Upstream commit 608e0b7a675b2affbbf38167cad0fa63d8e064f7 ]

l2cap_chan_close() requires holding chan->lock and chan->conn->lock if
associated chan->conn exists, to guard eg. conn->chan_l. Taking the
locks with right ordering requires handling a race condition.

Add helper function l2cap_chan_(un)lock_conn that do the locking right.

Add l2cap_chan_close_unlocked() that does not require locks to be held,
as all callsites do this lock -> close -> unlock pattern.

Link: https://syzkaller.appspot.com/bug?extid=0e4ebcc970728e056324
Signed-off-by: Pauli Virtanen <pav@iki.fi>
Signed-off-by: Luiz Augusto von Dentz <luiz.von.dentz@intel.com>
[ backport: dropped the context-analysis annotations 6.12 lacks
  (__must_not_hold, __cond_acquires, __context_unsafe); code
  unchanged ]
Signed-off-by: Iaroslav Voitovych <yaroslav.voytovych@gmail.com>
---
 include/net/bluetooth/l2cap.h | 16 ++++++++++
 net/bluetooth/l2cap_core.c    | 60 ++++++++++++++++++++++++++++++++---
 2 files changed, 71 insertions(+), 5 deletions(-)

diff --git a/include/net/bluetooth/l2cap.h b/include/net/bluetooth/l2cap.h
index f5f91373022f0..2b13f26444d69 100644
--- a/include/net/bluetooth/l2cap.h
+++ b/include/net/bluetooth/l2cap.h
@@ -963,6 +963,7 @@ int l2cap_add_scid(struct l2cap_chan *chan,  __u16 scid);
 
 struct l2cap_chan *l2cap_chan_create(void);
 void l2cap_chan_close(struct l2cap_chan *chan, int reason);
+void l2cap_chan_close_unlocked(struct l2cap_chan *chan, int reason);
 int l2cap_chan_connect(struct l2cap_chan *chan, __le16 psm, u16 cid,
 		       bdaddr_t *dst, u8 dst_type, u16 timeout);
 int l2cap_chan_reconfigure(struct l2cap_chan *chan, __u16 mtu);
@@ -987,4 +988,19 @@ void l2cap_conn_put(struct l2cap_conn *conn);
 int l2cap_register_user(struct l2cap_conn *conn, struct l2cap_user *user);
 void l2cap_unregister_user(struct l2cap_conn *conn, struct l2cap_user *user);
 
+bool l2cap_chan_lock_conn(struct l2cap_chan *chan)
+	__acquires(&chan->lock);
+
+/* Release macro for l2cap_chan_lock_conn, so context analysis understands it */
+#define l2cap_chan_unlock_conn(chan, conn_locked)			\
+	({								\
+		struct l2cap_chan *__chan = (chan);			\
+		struct l2cap_conn *__conn = __chan->conn;		\
+		l2cap_chan_unlock(__chan);				\
+		if (conn_locked) {					\
+			mutex_unlock(&__conn->lock);			\
+			l2cap_conn_put(__conn);				\
+		}							\
+	})
+
 #endif /* __L2CAP_H */
diff --git a/net/bluetooth/l2cap_core.c b/net/bluetooth/l2cap_core.c
index 894fcd779bd03..02fb2bdb65689 100644
--- a/net/bluetooth/l2cap_core.c
+++ b/net/bluetooth/l2cap_core.c
@@ -62,6 +62,7 @@ static void l2cap_tx(struct l2cap_chan *chan, struct l2cap_ctrl *control,
 static void l2cap_retrans_timeout(struct work_struct *work);
 static void l2cap_monitor_timeout(struct work_struct *work);
 static void l2cap_ack_timeout(struct work_struct *work);
+static void __l2cap_chan_close(struct l2cap_chan *chan, int reason);
 
 static inline u8 bdaddr_type(u8 link_type, u8 bdaddr_type)
 {
@@ -433,7 +434,7 @@ static void l2cap_chan_timeout(struct work_struct *work)
 	else
 		reason = ETIMEDOUT;
 
-	l2cap_chan_close(chan, reason);
+	__l2cap_chan_close(chan, reason);
 
 	chan->ops->close(chan);
 
@@ -842,7 +843,7 @@ static void l2cap_chan_connect_reject(struct l2cap_chan *chan)
 	l2cap_send_cmd(conn, chan->ident, L2CAP_CONN_RSP, sizeof(rsp), &rsp);
 }
 
-void l2cap_chan_close(struct l2cap_chan *chan, int reason)
+static void __l2cap_chan_close(struct l2cap_chan *chan, int reason)
 {
 	struct l2cap_conn *conn = chan->conn;
 
@@ -891,8 +892,57 @@ void l2cap_chan_close(struct l2cap_chan *chan, int reason)
 		break;
 	}
 }
+
+void l2cap_chan_close(struct l2cap_chan *chan, int reason)
+{
+	__l2cap_chan_close(chan, reason);
+}
 EXPORT_SYMBOL(l2cap_chan_close);
 
+/* Take chan->lock. If chan->conn is non-NULL, take new reference on it, take
+ * chan->conn->lock, and return true. Otherwise return false.
+ */
+bool l2cap_chan_lock_conn(struct l2cap_chan *chan)
+{
+	/* Handle conn->lock > chan->lock ordering + race on chan->conn */
+	for (;;) {
+		struct l2cap_conn *conn;
+
+		l2cap_chan_lock(chan);
+		conn = chan->conn;
+		if (conn)
+			l2cap_conn_get(conn);
+		l2cap_chan_unlock(chan);
+
+		if (conn)
+			mutex_lock(&conn->lock);
+
+		l2cap_chan_lock(chan);
+
+		if (chan->conn != conn) {
+			l2cap_chan_unlock(chan);
+			if (conn) {
+				mutex_unlock(&conn->lock);
+				l2cap_conn_put(conn);
+			}
+			schedule();
+			continue;
+		}
+
+		return chan->conn;
+	}
+}
+
+void l2cap_chan_close_unlocked(struct l2cap_chan *chan, int reason)
+{
+	bool have_conn;
+
+	have_conn = l2cap_chan_lock_conn(chan);
+	__l2cap_chan_close(chan, reason);
+	l2cap_chan_unlock_conn(chan, have_conn);
+}
+EXPORT_SYMBOL(l2cap_chan_close_unlocked);
+
 static inline u8 l2cap_get_auth_type(struct l2cap_chan *chan)
 {
 	switch (chan->chan_type) {
@@ -1583,7 +1633,7 @@ static void l2cap_conn_start(struct l2cap_conn *conn)
 			if (!l2cap_mode_supported(chan->mode, conn->feat_mask)
 			    && test_bit(CONF_STATE2_DEVICE,
 					&chan->conf_state)) {
-				l2cap_chan_close(chan, ECONNRESET);
+				__l2cap_chan_close(chan, ECONNRESET);
 				l2cap_chan_unlock(chan);
 				continue;
 			}
@@ -1591,7 +1641,7 @@ static void l2cap_conn_start(struct l2cap_conn *conn)
 			if (l2cap_check_enc_key_size(conn->hcon, chan))
 				l2cap_start_connection(chan);
 			else
-				l2cap_chan_close(chan, ECONNREFUSED);
+				__l2cap_chan_close(chan, ECONNREFUSED);
 
 		} else if (chan->state == BT_CONNECT2) {
 			struct l2cap_conn_rsp rsp;
@@ -7630,7 +7680,7 @@ static inline void l2cap_check_encryption(struct l2cap_chan *chan, u8 encrypt)
 			__set_chan_timer(chan, L2CAP_ENC_TIMEOUT);
 		} else if (chan->sec_level == BT_SECURITY_HIGH ||
 			   chan->sec_level == BT_SECURITY_FIPS)
-			l2cap_chan_close(chan, ECONNREFUSED);
+			__l2cap_chan_close(chan, ECONNREFUSED);
 	} else {
 		if (chan->sec_level == BT_SECURITY_MEDIUM)
 			__clear_chan_timer(chan);
-- 
2.43.0

```

**`contributions/CO-35-l2cap-ecred-defer-hang-stable/send-20261114/mail/6.12.y/0002-Bluetooth-L2CAP-hold-conn-lock-for-__l2cap_ecred_con.patch`** (SHA-256 `9bf710210435402e667f9dd386350d1998ecb7339a7990670935c8ef6024d5a3`)

```diff
From 9794c6835f5fa6b23d057423e1849b39ed776600 Mon Sep 17 00:00:00 2001
From: Pauli Virtanen <pav@iki.fi>
Date: Sat, 29 Aug 2026 17:20:02 +0300
Subject: [PATCH 6.12.y 2/2] Bluetooth: L2CAP: hold conn->lock for
 __l2cap_ecred_conn_rsp_defer

[ Upstream commit 32d86e048d8efedb7aa6cbbd3c36c3c435401c92 ]

__l2cap_ecred_conn_rsp_defer() > __l2cap_chan_list_id() accesses
conn->chan_l which is guarded by conn->lock. The lock fails to be held
when calling from l2cap_sock.c.

Fix by using l2cap_chan_conn_lock(), and taking the locks in required
order l2cap_conn::lock > l2cap_chan::lock > sk.  Leave fast path with
sk->sk_state precheck.  Move the L2CAP defer handling to
l2cap_sock_defer().

The code should also take l2cap_chan_lock() for sibling channels, but
that needs separate fix due to lock nesting.

Fixes: ab4eedb790ca ("Bluetooth: L2CAP: Fix corrupted list in hci_chan_del")
Signed-off-by: Pauli Virtanen <pav@iki.fi>
Signed-off-by: Luiz Augusto von Dentz <luiz.von.dentz@intel.com>
[ backport: 6.12 has no MSG_ERRQUEUE handling in
  l2cap_sock_recvmsg(), so the hunk is adapted to its context and
  the new l2cap_sock_defer() call replaces the old inline defer
  block; no other change ]
Signed-off-by: Iaroslav Voitovych <yaroslav.voytovych@gmail.com>
---
 net/bluetooth/l2cap_sock.c | 62 +++++++++++++++++++++++++++-----------
 1 file changed, 45 insertions(+), 17 deletions(-)

diff --git a/net/bluetooth/l2cap_sock.c b/net/bluetooth/l2cap_sock.c
index f08512a57ab58..9b4f0a3319aa1 100644
--- a/net/bluetooth/l2cap_sock.c
+++ b/net/bluetooth/l2cap_sock.c
@@ -1224,36 +1224,64 @@ static void l2cap_publish_rx_avail(struct l2cap_chan *chan)
 		l2cap_chan_rx_avail(chan, -1);
 }
 
-static int l2cap_sock_recvmsg(struct socket *sock, struct msghdr *msg,
-			      size_t len, int flags)
+static int l2cap_sock_defer(struct sock *sk)
 {
-	struct sock *sk = sock->sk;
-	struct l2cap_pinfo *pi = l2cap_pi(sk);
-	int err;
+	struct l2cap_chan *chan = l2cap_pi(sk)->chan;
+	bool have_conn;
+	int err = 0;
 
+	/* Fast path check */
+	lock_sock(sk);
+	if (sk->sk_state != BT_CONNECT2) {
+		release_sock(sk);
+		return 0;
+	}
+	release_sock(sk);
+
+	have_conn = l2cap_chan_lock_conn(chan);
 	lock_sock(sk);
 
 	if (sk->sk_state == BT_CONNECT2 && test_bit(BT_SK_DEFER_SETUP,
 						    &bt_sk(sk)->flags)) {
-		if (pi->chan->mode == L2CAP_MODE_EXT_FLOWCTL) {
+		err = 1;
+
+		if (!have_conn) {
+			release_sock(sk);
+			err = -ENOTCONN;
+		} else if (chan->mode == L2CAP_MODE_EXT_FLOWCTL) {
 			sk->sk_state = BT_CONNECTED;
-			pi->chan->state = BT_CONNECTED;
-			__l2cap_ecred_conn_rsp_defer(pi->chan);
-		} else if (bdaddr_type_is_le(pi->chan->src_type)) {
+			chan->state = BT_CONNECTED;
+			release_sock(sk);
+			__l2cap_ecred_conn_rsp_defer(chan);
+		} else if (bdaddr_type_is_le(chan->src_type)) {
 			sk->sk_state = BT_CONNECTED;
-			pi->chan->state = BT_CONNECTED;
-			__l2cap_le_connect_rsp_defer(pi->chan);
+			chan->state = BT_CONNECTED;
+			release_sock(sk);
+			__l2cap_le_connect_rsp_defer(chan);
 		} else {
 			sk->sk_state = BT_CONFIG;
-			pi->chan->state = BT_CONFIG;
-			__l2cap_connect_rsp_defer(pi->chan);
+			chan->state = BT_CONFIG;
+			release_sock(sk);
+			__l2cap_connect_rsp_defer(chan);
 		}
-
-		err = 0;
-		goto done;
+	} else {
+		release_sock(sk);
 	}
 
-	release_sock(sk);
+	l2cap_chan_unlock_conn(chan, have_conn);
+	return err;
+}
+
+static int l2cap_sock_recvmsg(struct socket *sock, struct msghdr *msg,
+			      size_t len, int flags)
+{
+	struct sock *sk = sock->sk;
+	struct l2cap_pinfo *pi = l2cap_pi(sk);
+	int err;
+
+	err = l2cap_sock_defer(sk);
+	if (err)
+		return err < 0 ? err : 0;
 
 	if (sock->type == SOCK_STREAM)
 		err = bt_sock_stream_recvmsg(sock, msg, len, flags);
-- 
2.43.0

```

**`contributions/CO-35-l2cap-ecred-defer-hang-stable/send-20261114/mail/6.6.y/0000-cover-letter-20261114.patch`** (SHA-256 `57c31c851e949855a2163c259cad9a974c75780596e9e1f73cdeea15ba80ef03`)

```diff
From d7cbfc80bd814aa1953397ffd7129b0b940cff23 Mon Sep 17 00:00:00 2001
From: Iaroslav Voitovych <yaroslav.voytovych@gmail.com>
Date: Sat, 14 Nov 2026 12:00:00 +0100
Subject: [PATCH 6.6.y 0/2] Bluetooth: L2CAP: fix the deferred ECRED accept hang

Hello,

this is a backport to 6.6.y of two mainline commits by Pauli Virtanen,
in this order:

  608e0b7a675b ("Bluetooth: L2CAP: add l2cap_chan_close_unlocked() and
  locking helpers")
  32d86e048d8e ("Bluetooth: L2CAP: hold conn->lock for
  __l2cap_ecred_conn_rsp_defer")

The second fixes ab4eedb790ca ("Bluetooth: L2CAP: Fix corrupted list in
hci_chan_del"), which 6.6.y has as efc30877bd4b. It calls
l2cap_chan_lock_conn() and l2cap_chan_unlock_conn(), which only the
first adds; the first is 78 changed lines (a 149-line diff), more than
the 100 lines the stable rules allow, and is sent whole as it was
merged because that is the conservative choice compared with a smaller
locking patch written only for stable. Neither carries Cc: stable.
They are patches 2 and 7 of the series "Bluetooth: L2CAP: fix and
annotate l2cap_conn::chan_l locking"; the other patches are not needed
for the problem below and were not tested here. One of them,
dc1ddc65f06d ("Bluetooth: L2CAP: take lock for l2cap_chan_del in
l2cap_ecred_rsp_defer"), is not requested: in v6.6.162,
l2cap_ecred_rsp_defer() calls l2cap_chan_del() on the sibling channels
without their chan->lock only in its refusal branch, which is a lock
context issue separate from the caller's own socket lock that hangs the
case below.

Without them, BlueZ's l2cap-tester case "L2CAP Ext-Flowctl Server -
Accept 2 Close 1" never finishes on v6.6.162: the test stops after
"Accept deferred setup". With CONFIG_DETECT_HUNG_TASK enabled, the
tester's task is reported blocked holding its socket's lock from
l2cap_sock_recvmsg() and waiting for the same lock in
l2cap_sock_teardown_cb(); patch 2 releases the socket lock before
__l2cap_ecred_conn_rsp_defer().

On 6.6.y patch 1 does not build and patch 2 does not apply as they
are. Deviations:
- patch 1: the context-analysis annotations 6.6.y lacks are dropped
  (__must_not_hold, the __cond_acquires on l2cap_chan_lock_conn(),
  __context_unsafe); the code is unchanged;
- patch 2: l2cap_sock_recvmsg() in 6.6.y has no MSG_ERRQUEUE block,
  so the three MSG_ERRQUEUE lines that precede the new
  l2cap_sock_defer() call upstream are absent; l2cap_sock_defer() and
  its call are as upstream.

Tested on v6.6.162 in QEMU/KVM (4 vCPUs) with BlueZ's
doc/tester.config: with the series the case passes, and the whole
l2cap-tester ends with 79 of 111 passed; all other non-passes are
pre-existing on plain v6.6.162 (features the tree lacks). Without the
series the case never finishes. No lockdep or KASAN report with the
series.

The two commits are requested for 7.3.y as they are, in a separate
mail; backports for 6.18.y and 6.12.y are separate series.

Thanks,
Iaroslav

Pauli Virtanen (2):
  Bluetooth: L2CAP: add l2cap_chan_close_unlocked() and locking helpers
  Bluetooth: L2CAP: hold conn->lock for __l2cap_ecred_conn_rsp_defer

 include/net/bluetooth/l2cap.h | 16 +++++++++
 net/bluetooth/l2cap_core.c    | 60 ++++++++++++++++++++++++++++++---
 net/bluetooth/l2cap_sock.c    | 62 +++++++++++++++++++++++++----------
 3 files changed, 116 insertions(+), 22 deletions(-)


base-commit: 5139929c698c273e07cb0635732f6a918a7b8e78
-- 
2.43.0

```

**`contributions/CO-35-l2cap-ecred-defer-hang-stable/send-20261114/mail/6.6.y/0001-Bluetooth-L2CAP-add-l2cap_chan_close_unlocked-and-lo.patch`** (SHA-256 `d4b0bcf067dce96df0cc958146a7500c8ca2fde4173571bbebdf4fcc9f9d94ac`)

```diff
From 8c6716dbd1ddce90551d0526cda80ca0187950ce Mon Sep 17 00:00:00 2001
From: Pauli Virtanen <pav@iki.fi>
Date: Sat, 29 Aug 2026 17:19:57 +0300
Subject: [PATCH 6.6.y 1/2] Bluetooth: L2CAP: add l2cap_chan_close_unlocked()
 and locking helpers

[ Upstream commit 608e0b7a675b2affbbf38167cad0fa63d8e064f7 ]

l2cap_chan_close() requires holding chan->lock and chan->conn->lock if
associated chan->conn exists, to guard eg. conn->chan_l. Taking the
locks with right ordering requires handling a race condition.

Add helper function l2cap_chan_(un)lock_conn that do the locking right.

Add l2cap_chan_close_unlocked() that does not require locks to be held,
as all callsites do this lock -> close -> unlock pattern.

Link: https://syzkaller.appspot.com/bug?extid=0e4ebcc970728e056324
Signed-off-by: Pauli Virtanen <pav@iki.fi>
Signed-off-by: Luiz Augusto von Dentz <luiz.von.dentz@intel.com>
[ backport: dropped the context-analysis annotations 6.6 lacks
  (__must_not_hold, __cond_acquires, __context_unsafe); code
  unchanged ]
Signed-off-by: Iaroslav Voitovych <yaroslav.voytovych@gmail.com>
---
 include/net/bluetooth/l2cap.h | 16 ++++++++++
 net/bluetooth/l2cap_core.c    | 60 ++++++++++++++++++++++++++++++++---
 2 files changed, 71 insertions(+), 5 deletions(-)

diff --git a/include/net/bluetooth/l2cap.h b/include/net/bluetooth/l2cap.h
index 767df6d832c81..775aad5bd990a 100644
--- a/include/net/bluetooth/l2cap.h
+++ b/include/net/bluetooth/l2cap.h
@@ -957,6 +957,7 @@ int l2cap_add_scid(struct l2cap_chan *chan,  __u16 scid);
 
 struct l2cap_chan *l2cap_chan_create(void);
 void l2cap_chan_close(struct l2cap_chan *chan, int reason);
+void l2cap_chan_close_unlocked(struct l2cap_chan *chan, int reason);
 int l2cap_chan_connect(struct l2cap_chan *chan, __le16 psm, u16 cid,
 		       bdaddr_t *dst, u8 dst_type);
 int l2cap_chan_reconfigure(struct l2cap_chan *chan, __u16 mtu);
@@ -985,4 +986,19 @@ void l2cap_conn_put(struct l2cap_conn *conn);
 int l2cap_register_user(struct l2cap_conn *conn, struct l2cap_user *user);
 void l2cap_unregister_user(struct l2cap_conn *conn, struct l2cap_user *user);
 
+bool l2cap_chan_lock_conn(struct l2cap_chan *chan)
+	__acquires(&chan->lock);
+
+/* Release macro for l2cap_chan_lock_conn, so context analysis understands it */
+#define l2cap_chan_unlock_conn(chan, conn_locked)			\
+	({								\
+		struct l2cap_chan *__chan = (chan);			\
+		struct l2cap_conn *__conn = __chan->conn;		\
+		l2cap_chan_unlock(__chan);				\
+		if (conn_locked) {					\
+			mutex_unlock(&__conn->lock);			\
+			l2cap_conn_put(__conn);				\
+		}							\
+	})
+
 #endif /* __L2CAP_H */
diff --git a/net/bluetooth/l2cap_core.c b/net/bluetooth/l2cap_core.c
index 94fddc456ac57..8ceb27abc125c 100644
--- a/net/bluetooth/l2cap_core.c
+++ b/net/bluetooth/l2cap_core.c
@@ -62,6 +62,7 @@ static void l2cap_tx(struct l2cap_chan *chan, struct l2cap_ctrl *control,
 static void l2cap_retrans_timeout(struct work_struct *work);
 static void l2cap_monitor_timeout(struct work_struct *work);
 static void l2cap_ack_timeout(struct work_struct *work);
+static void __l2cap_chan_close(struct l2cap_chan *chan, int reason);
 
 static inline u8 bdaddr_type(u8 link_type, u8 bdaddr_type)
 {
@@ -433,7 +434,7 @@ static void l2cap_chan_timeout(struct work_struct *work)
 	else
 		reason = ETIMEDOUT;
 
-	l2cap_chan_close(chan, reason);
+	__l2cap_chan_close(chan, reason);
 
 	chan->ops->close(chan);
 
@@ -842,7 +843,7 @@ static void l2cap_chan_connect_reject(struct l2cap_chan *chan)
 	l2cap_send_cmd(conn, chan->ident, L2CAP_CONN_RSP, sizeof(rsp), &rsp);
 }
 
-void l2cap_chan_close(struct l2cap_chan *chan, int reason)
+static void __l2cap_chan_close(struct l2cap_chan *chan, int reason)
 {
 	struct l2cap_conn *conn = chan->conn;
 
@@ -891,8 +892,57 @@ void l2cap_chan_close(struct l2cap_chan *chan, int reason)
 		break;
 	}
 }
+
+void l2cap_chan_close(struct l2cap_chan *chan, int reason)
+{
+	__l2cap_chan_close(chan, reason);
+}
 EXPORT_SYMBOL(l2cap_chan_close);
 
+/* Take chan->lock. If chan->conn is non-NULL, take new reference on it, take
+ * chan->conn->lock, and return true. Otherwise return false.
+ */
+bool l2cap_chan_lock_conn(struct l2cap_chan *chan)
+{
+	/* Handle conn->lock > chan->lock ordering + race on chan->conn */
+	for (;;) {
+		struct l2cap_conn *conn;
+
+		l2cap_chan_lock(chan);
+		conn = chan->conn;
+		if (conn)
+			l2cap_conn_get(conn);
+		l2cap_chan_unlock(chan);
+
+		if (conn)
+			mutex_lock(&conn->lock);
+
+		l2cap_chan_lock(chan);
+
+		if (chan->conn != conn) {
+			l2cap_chan_unlock(chan);
+			if (conn) {
+				mutex_unlock(&conn->lock);
+				l2cap_conn_put(conn);
+			}
+			schedule();
+			continue;
+		}
+
+		return chan->conn;
+	}
+}
+
+void l2cap_chan_close_unlocked(struct l2cap_chan *chan, int reason)
+{
+	bool have_conn;
+
+	have_conn = l2cap_chan_lock_conn(chan);
+	__l2cap_chan_close(chan, reason);
+	l2cap_chan_unlock_conn(chan, have_conn);
+}
+EXPORT_SYMBOL(l2cap_chan_close_unlocked);
+
 static inline u8 l2cap_get_auth_type(struct l2cap_chan *chan)
 {
 	switch (chan->chan_type) {
@@ -1568,7 +1618,7 @@ static void l2cap_conn_start(struct l2cap_conn *conn)
 			if (!l2cap_mode_supported(chan->mode, conn->feat_mask)
 			    && test_bit(CONF_STATE2_DEVICE,
 					&chan->conf_state)) {
-				l2cap_chan_close(chan, ECONNRESET);
+				__l2cap_chan_close(chan, ECONNRESET);
 				l2cap_chan_unlock(chan);
 				continue;
 			}
@@ -1576,7 +1626,7 @@ static void l2cap_conn_start(struct l2cap_conn *conn)
 			if (l2cap_check_enc_key_size(conn->hcon, chan))
 				l2cap_start_connection(chan);
 			else
-				l2cap_chan_close(chan, ECONNREFUSED);
+				__l2cap_chan_close(chan, ECONNREFUSED);
 
 		} else if (chan->state == BT_CONNECT2) {
 			struct l2cap_conn_rsp rsp;
@@ -7577,7 +7627,7 @@ static inline void l2cap_check_encryption(struct l2cap_chan *chan, u8 encrypt)
 			__set_chan_timer(chan, L2CAP_ENC_TIMEOUT);
 		} else if (chan->sec_level == BT_SECURITY_HIGH ||
 			   chan->sec_level == BT_SECURITY_FIPS)
-			l2cap_chan_close(chan, ECONNREFUSED);
+			__l2cap_chan_close(chan, ECONNREFUSED);
 	} else {
 		if (chan->sec_level == BT_SECURITY_MEDIUM)
 			__clear_chan_timer(chan);
-- 
2.43.0

```

**`contributions/CO-35-l2cap-ecred-defer-hang-stable/send-20261114/mail/6.6.y/0002-Bluetooth-L2CAP-hold-conn-lock-for-__l2cap_ecred_con.patch`** (SHA-256 `32d994abd4059c9d5508def1c174a20c5e843f01f164c305a53fbfad28e2a7ee`)

```diff
From d7cbfc80bd814aa1953397ffd7129b0b940cff23 Mon Sep 17 00:00:00 2001
From: Pauli Virtanen <pav@iki.fi>
Date: Sat, 29 Aug 2026 17:20:02 +0300
Subject: [PATCH 6.6.y 2/2] Bluetooth: L2CAP: hold conn->lock for
 __l2cap_ecred_conn_rsp_defer

[ Upstream commit 32d86e048d8efedb7aa6cbbd3c36c3c435401c92 ]

__l2cap_ecred_conn_rsp_defer() > __l2cap_chan_list_id() accesses
conn->chan_l which is guarded by conn->lock. The lock fails to be held
when calling from l2cap_sock.c.

Fix by using l2cap_chan_conn_lock(), and taking the locks in required
order l2cap_conn::lock > l2cap_chan::lock > sk.  Leave fast path with
sk->sk_state precheck.  Move the L2CAP defer handling to
l2cap_sock_defer().

The code should also take l2cap_chan_lock() for sibling channels, but
that needs separate fix due to lock nesting.

Fixes: ab4eedb790ca ("Bluetooth: L2CAP: Fix corrupted list in hci_chan_del")
Signed-off-by: Pauli Virtanen <pav@iki.fi>
Signed-off-by: Luiz Augusto von Dentz <luiz.von.dentz@intel.com>
[ backport: 6.6 has no MSG_ERRQUEUE handling in
  l2cap_sock_recvmsg(), so the hunk is adapted to its context and
  the new l2cap_sock_defer() call replaces the old inline defer
  block; no other change ]
Signed-off-by: Iaroslav Voitovych <yaroslav.voytovych@gmail.com>
---
 net/bluetooth/l2cap_sock.c | 62 +++++++++++++++++++++++++++-----------
 1 file changed, 45 insertions(+), 17 deletions(-)

diff --git a/net/bluetooth/l2cap_sock.c b/net/bluetooth/l2cap_sock.c
index 7d2e59e97c2c1..a7531477a4521 100644
--- a/net/bluetooth/l2cap_sock.c
+++ b/net/bluetooth/l2cap_sock.c
@@ -1208,36 +1208,64 @@ static void l2cap_publish_rx_avail(struct l2cap_chan *chan)
 		l2cap_chan_rx_avail(chan, -1);
 }
 
-static int l2cap_sock_recvmsg(struct socket *sock, struct msghdr *msg,
-			      size_t len, int flags)
+static int l2cap_sock_defer(struct sock *sk)
 {
-	struct sock *sk = sock->sk;
-	struct l2cap_pinfo *pi = l2cap_pi(sk);
-	int err;
+	struct l2cap_chan *chan = l2cap_pi(sk)->chan;
+	bool have_conn;
+	int err = 0;
 
+	/* Fast path check */
+	lock_sock(sk);
+	if (sk->sk_state != BT_CONNECT2) {
+		release_sock(sk);
+		return 0;
+	}
+	release_sock(sk);
+
+	have_conn = l2cap_chan_lock_conn(chan);
 	lock_sock(sk);
 
 	if (sk->sk_state == BT_CONNECT2 && test_bit(BT_SK_DEFER_SETUP,
 						    &bt_sk(sk)->flags)) {
-		if (pi->chan->mode == L2CAP_MODE_EXT_FLOWCTL) {
+		err = 1;
+
+		if (!have_conn) {
+			release_sock(sk);
+			err = -ENOTCONN;
+		} else if (chan->mode == L2CAP_MODE_EXT_FLOWCTL) {
 			sk->sk_state = BT_CONNECTED;
-			pi->chan->state = BT_CONNECTED;
-			__l2cap_ecred_conn_rsp_defer(pi->chan);
-		} else if (bdaddr_type_is_le(pi->chan->src_type)) {
+			chan->state = BT_CONNECTED;
+			release_sock(sk);
+			__l2cap_ecred_conn_rsp_defer(chan);
+		} else if (bdaddr_type_is_le(chan->src_type)) {
 			sk->sk_state = BT_CONNECTED;
-			pi->chan->state = BT_CONNECTED;
-			__l2cap_le_connect_rsp_defer(pi->chan);
+			chan->state = BT_CONNECTED;
+			release_sock(sk);
+			__l2cap_le_connect_rsp_defer(chan);
 		} else {
 			sk->sk_state = BT_CONFIG;
-			pi->chan->state = BT_CONFIG;
-			__l2cap_connect_rsp_defer(pi->chan);
+			chan->state = BT_CONFIG;
+			release_sock(sk);
+			__l2cap_connect_rsp_defer(chan);
 		}
-
-		err = 0;
-		goto done;
+	} else {
+		release_sock(sk);
 	}
 
-	release_sock(sk);
+	l2cap_chan_unlock_conn(chan, have_conn);
+	return err;
+}
+
+static int l2cap_sock_recvmsg(struct socket *sock, struct msghdr *msg,
+			      size_t len, int flags)
+{
+	struct sock *sk = sock->sk;
+	struct l2cap_pinfo *pi = l2cap_pi(sk);
+	int err;
+
+	err = l2cap_sock_defer(sk);
+	if (err)
+		return err < 0 ? err : 0;
 
 	if (sock->type == SOCK_STREAM)
 		err = bt_sock_stream_recvmsg(sock, msg, len, flags);
-- 
2.43.0

```

**`contributions/CO-35-l2cap-ecred-defer-hang-stable/send-20261114/CHECKS.md`** (SHA-256 `20ba77fb386f6871c5f149f112c8d4343ffeb6f4d440626f572af01561223d25`)

```markdown
# CO-35 refresh against today's stable tips, 2026-11-14 (UTC)

Work area: `/root/exp/agent-work/lane5-status-stable-20261114/co35/` (scripts at the top level, logs in `logs/`, kernel images in `img/`, mails in `mail/`; hashes in `SHA256SUMS`). Nothing was sent. The project tree was not written to.
"measured" = run today, log named; "from source" / "inferred" as marked. Tests: QEMU/KVM, 4 vCPUs, BlueZ `doc/tester.config` plus `CONFIG_DETECT_HUNG_TASK`, 20 s; one guest at a time; `make -j4`; scripts `build.sh`, `run-test.sh`, `run-all.sh`, `run-extra.sh` (the 2026-11-02 scripts, paths changed). Kernel trees: depth-1 fetches of the tags from the GitHub mirror (`k-fetch.sh`, log `logs/k-fetch.log`), because the project's `cache/linux` is a partial clone that cannot be cloned with `--shared`.

## 1. Facts (measured)

| what | value | source |
|---|---|---|
| newest tags | v7.3.4 (2026-11-10), v6.18.63 (11-10), v6.12.117 (11-10), v6.6.162 (11-06), v6.1.192 (11-06); mainline v7.4-rc2 (11-09) | kernel.org `releases.json` 2026-11-14 00:40Z; `git ls-remote` tips equal the tags |
| the pair in mainline | both in v7.4-rc1 and in master (commit dates 2026-10-14 17:24 and 17:25 UTC) | `gh api repos/torvalds/linux/commits/<sha>`; `l2cap_core.c` history of v7.4-rc2 and master |
| the pair in a stable release or queue | not in v7.3.4, v6.18.63, v6.12.117, v6.6.162, v6.1.192; `stable-queue-check.sh` for `bluetooth-l2cap-hold-conn-lock-for` and `bluetooth-l2cap-add-l2cap_chan_close_unlocked`: "not in queue" for 7.3, 6.18, 6.12, 6.6, 6.1 (2026-11-14 01:05-01:06 UTC) | `raw/command-outputs.txt` of the status check |
| `5874f8d03268` (SCI fix) on 7.3.y | **still not there**: not among the 100 newest `net/bluetooth` commits of v7.3.4 (`gh api`), not in queue-7.3 (`stable-queue-check.sh bluetooth-fix-the-le-read-connection-interval`, 01:21 UTC), and `git cherry-pick -x 5874f8d03268` onto v7.3.4 is not empty (5 insertions, 12 deletions in `hci_event.c`, `hci.h`) | `logs/apply-v7.3.4.log` |
| 7.3.4 newly has nearby L2CAP commits | `d3afd7803f9b` "refuse __l2cap_chan_add if chan already has conn" (10-30), "Reject mode changes on connected channels", TxWindow fixes (11-10) | `gh api commits?sha=v7.3.4&path=net/bluetooth`; they did not disturb the pair (next row) |

## 2. Does the pair apply today (measured, `logs/apply-<tag>.log`)

| tag | how | result |
|---|---|---|
| v7.3.4 | `git cherry-pick -x 608e0b7a675b2 32d86e048d8ef` (auto-merging `l2cap.h`, `l2cap_core.c`, `l2cap_sock.c`) | rc=0, clean; 5 files with the SCI fix added (`5874f8d03268` also clean) |
| v6.18.63, v6.12.117, v6.6.162 | `git am` of the unchanged 2026-11-02 backports (strict, no fuzz, no 3-way) | rc=0 on all three; the six patch files are byte-identical to `send-20261102/` (`cmp`, `logs/mail-lint-new.log`), so nothing was regenerated |
| v6.1.192, v5.15.225, v5.10.274 (not requested) | `git cherry-pick -x` of the pair (`logs/apply-old-*.log`) | patch 1 applies textually; **patch 2 conflicts in `net/bluetooth/l2cap_sock.c`** on all three. These lines have no `l2cap_chan_lock_conn()` and lack `ab4eedb790ca`; not built, not tested today. The 11-02 statement that the pair "does not apply" is confirmed for the pair as a whole |

## 3. Builds and tests (measured; times in `progress.log`)

Case "L2CAP Ext-Flowctl Server - Accept 2 Close 1" alone, 180 s limit (`logs/case-<tag>-<variant>.log`, `logs/summary-*.txt`):

| tag | plain (base) | with the pair | counts on 2026-11-02 |
|---|---|---|---|
| v7.3.4 | **HANG** (limit 180 s; hung-task reports: 7) | Passed 1.007 s; with the SCI fix too, 1.025 s; with the pair plus `dc1ddc65f06d`, 1.040 s | v7.3.1: hang; pass 1.034 / 1.040 s |
| v6.18.63 | **HANG** (7) | Passed 1.242 s | v6.18.60: hang (7); 1.067 s |
| v6.12.117 | **HANG** (7) | Passed 1.041 s | v6.12.115: hang (7); 1.074 s |
| v6.6.162 | **HANG** (7) | Passed 1.113 s | v6.6.161: hang (7); 1.036 s |

Whole l2cap-tester (`logs/full-*.log`):

| image | today | 2026-11-02 |
|---|---|---|
| v7.3.4 + pair + `5874f8d03268` | **111 of 111 passed** (all 8 SCI cases pass) | v7.3.1: 111 of 111 |
| v7.3.4 + pair alone | stalls at "L2CAP LE Client - SCI Fast Mode" ("test timed out", kernel log "Invalid response length for 0x20a3" once), run killed at 300 s | v7.3.1: stalls in the same case |
| v6.18.63 + pair | 93 passed, 18 failed (all "Set PHY") | 93 / 18 |
| v6.12.117 + pair | 79 passed, 32 not passed (one of them timed out: "BR/EDR Client PIN Code Change Sec - Success") | 79 / 31 + 1 timed out |
| v6.6.162 + pair | 79 passed, 32 not passed (same one timed out) | 79 / 31 + 1 |

Kernel-report scan (`kernel-report-scan.py`): all patched runs "clean" (no lockdep, KASAN or hung-task report); base runs `hung-task=7`. Build warnings in `net/bluetooth`: `logs/btwarn-*.log` (empty = none). Not rerun today: the plain-tag whole-tester runs (they cannot finish: the case hangs), so "all other non-passes are pre-existing on the plain tag" still rests on the 2026-11-01 pooled verdicts; the tester config has hung-task detection only (no separate lockdep/KASAN build) - as before.

Answer to the open questions: 7.3.y, 6.18.y, 6.12.y and 6.6.y all have the bug today (hang without the pair on each tip). The pair applies as it is to 7.3.4; the three backports apply and pass on 6.18.63, 6.12.117 and 6.6.162. 6.1.y/5.15.y/5.10.y: the dossier's finding stands (hang with `enable_ecred`, since v6.3), the pair does not apply, not covered, not retested.

## 4. checkpatch and other local checks (measured, `logs/checks.log`)

checkpatch.pl from the v7.3.4 tree: upstream `608e0b7a675b2`: 0 errors, 1 warning (commit message has "syzkaller", as before), 132 lines; `32d86e048d8ef`: 0 errors, 1 warning "Unknown commit id 'ab4eedb790ca'" (an artefact of the depth-1 tree; on 2026-11-02 in a full tree: 0 warnings), 88 lines; `5874f8d03268`: same artefact for `2f8784cfe8a9`. Each line's patch 1: 1 error (the `[ Upstream commit ... ]` line stable prescribes) + the syzkaller warning, 130 lines; patch 2: the same one error + the artefact, 88 (6.18.y) or 81 lines (6.12.y, 6.6.y). Same findings as 2026-11-02 and 2026-10-28. mail-lint: clean for both new requests and the three new covers (`logs/mail-lint-new.log`). Subjects: 63 and 76 columns including "Subject: ".

`ci-local.sh --kernel` was **not rerun**: it works in `cache/linux` (a worktree there), which this lane must not write to. What it checked on 2026-11-02 is covered here as far as possible: am on the tag (section 2, PASS), checkpatch (above), SubjectPrefix and VerifySignedoff are unchanged by the files (patches byte-identical); gitlint (title 82/82/81 > 80 with the stable-line prefix) and VerifyFixes (`ab4eedb790ca` present as a backport on 6.12.y and 6.6.y, not as ancestor) are properties of the unchanged files and are expected to repeat. Rerun it from the main session if the exact CI output is wanted.

## 5. Follow-ups F-33 to F-39, F-85, F-91

| id | status today |
|---|---|
| F-33 drop 7.2.y | done on 11-02; 7.2.y is EOL (7.2.15); the new mails name 7.3.y only |
| F-34 both commits in v7.4-rc1, one batch, newest line first | commits in v7.4-rc1 re-verified today (section 1). The batch order (newest line first) is the sender's: nothing to write |
| F-35 one sentence on `dc1ddc65f06d` | in the request and the covers; its "the case passes with and without it" is now re-measured on v7.3.4 (1.040 s) |
| F-36 `Fixes:` origin sentence | decided on 11-02 (one neutral sentence kept); kept; operator may still delete it |
| F-37 non-pass breakdown to one sentence | done on 11-02; unchanged |
| F-38 shorten mail 1's subject | done (63 columns) |
| F-39 recheck queues and newest tags on the send day | done for today (section 1); **must be repeated on the actual send day** |
| F-85 rerun checkpatch and local CI | checkpatch rerun (section 4); local CI not rerun (reason above) |
| F-91 drop the patch-id identity claim | no identity claim in the mails (grep over `mail/`: none); the history documents named on 11-02 (README line 6, log.md, send/README.md, experiments/results-send-2026-10-28.md) are outside this lane and still need it |

## 6. New mail text (new files; the old ones are kept in `send-20261102/`)

`mail/request-v4-20261114.eml` (7.3.y request: v7.3.4 in place of v7.3.1), `mail/request-sci-7.3.y-20261114.eml` (v7.3.4, queue check time 2026-11-14 01:21 UTC), `mail/6.18.y|6.12.y|6.6.y/0000-cover-letter-20261114.patch` (tag names v6.18.63, v6.12.117, v6.6.162; `base-commit` of each tag; counts unchanged) and the unchanged patches 0001/0002 beside them. The old 6.1.y/5.15.y/5.10.y paragraph keeps the earlier test tags (v6.1.190, v5.15.223, v5.10.272) because those lines were not retested.
Differences from the 11-02 text are only the release numbers and dates, plus the removal of "in v7.3.1" from the `dc1ddc65f06d` sentence in the request (it now reads as a general statement, which the 11-02 note said held at all four tags and today's v7.3.4 `l2cap_ecred_rsp_defer()` matches by source).
```

---

## 8. CO-22 — two ASUS QCA ROME entries for stable (a request, no patch)

**The request.** Mainline has two btusb device-table entries for ASUS laptops with a QCA ROME
controller, `d54601f21faf` and `cfa67a1dbfd9`; no stable branch has them (checked 2026-11-14).
Without an entry btusb does no QCA setup, so the controller keeps its ROM firmware; that was the
condition under which this project's own QCA9377 hung on wideband-speech calls until its entry
(`dc16388d45ec`) reached stable. Whether these two models show the same hang is not known. On
today's tips (2026-11-14) both cherry-pick cleanly to 7.3.4, 6.18.63, 6.12.117, 6.6.162, 6.1.192,
5.15.225 and 5.10.274 (into `btusb.c`: git follows mainline's 7.4 rename), and `btusb.o` builds
with the same W=1 warnings as unpatched (none, except 6.6.y's known `btmtk.h` ones, present
unpatched too). The mail asks the stable team to take them; it names the entries' authors in Cc.
A related new ID patch posted on 2026-11-12 (0cf3:e303) is not mentioned: it is not merged and
carries its own `Cc: stable`.

**Questions for you.** Whether the request reads as justified for device-ID additions (which
stable rules allow), and its wording.

**`contributions/research-2026-11-01/qca-ids/refresh-20261114/mail/stable-request-asus-rome-v3.eml`** (SHA-256 `f390ba39ffa577d99cfd22aa1a62028fb282ecbad597362e3dde29f31eece06e`)

```text
From: Iaroslav Voitovych <yaroslav.voytovych@gmail.com>
To: stable@vger.kernel.org
Cc: Quentin Strydom <qstrydom0@gmail.com>, Konstantin Nazarov <qwertyuiopyyy@gmail.com>, Marcel Holtmann <marcel@holtmann.org>, Luiz Augusto von Dentz <luiz.dentz@gmail.com>, linux-bluetooth@vger.kernel.org
Subject: Please backport d54601f21faf and cfa67a1dbfd9 (btusb: ASUS QCA Rome IDs) to stable

Hello,

please consider these two commits, in this order, for linux-7.3.y,
linux-6.18.y, linux-6.12.y, linux-6.6.y, linux-6.1.y, linux-5.15.y and
linux-5.10.y:

  d54601f21faf ("Bluetooth: btusb: add ASUS 0b05:1868 to QCA Rome
  quirks")
  cfa67a1dbfd9 ("Bluetooth: btusb: add ASUS 0b05:1825 to QCA Rome
  quirks")

Both are in mainline since v7.4-rc1 and carry no Cc: stable tag.
Together they add two device IDs at the head of the btusb QCA ROME
block:

	{ USB_DEVICE(0x0b05, 0x1825), .driver_info = BTUSB_QCA_ROME |
						     BTUSB_WIDEBAND_SPEECH },
	{ USB_DEVICE(0x0b05, 0x1868), .driver_info = BTUSB_QCA_ROME |
						     BTUSB_WIDEBAND_SPEECH },

Without an entry these ASUS controllers match only the generic
Bluetooth class entry, btusb_setup_qca() never runs, and they stay on
their ROM firmware. Both commit messages report repeated "unexpected
event for opcode 0x2005" during LE scanning on that firmware. With the
entry the events stop (both commits), and d54601f21faf records the
driver loading qca/rampatch_usb_00000302.bin and
qca/nvm_usb_00000302.bin. I do not have these devices; the runtime
results are the authors'.

None of the seven trees has either ID, and neither commit is in a
stable release or in the stable queue (checked 2026-11-14). On each
tree's current tip (7.3.4, 6.18.63, 6.12.117, 6.6.162, 6.1.192,
5.15.225, 5.10.274) both commits cherry-pick cleanly with -x, and
btusb.o builds with them (x86_64 defconfig, BT=m, BT_HCIBTUSB=m, W=1)
with no new warning. In mainline the driver was split in 7.4 and these
two commits touch drivers/bluetooth/btusb_main.c; on the stable lines
git's rename detection applies them to drivers/bluetooth/btusb.c. On
6.6.162 the W=1 build of btusb.o stops on four unused-function errors
from btmtk.h, with or without these commits; with -Werror off the
warning set is identical.

The same kind of entry, dc16388d45ec ("Bluetooth: btusb: Add IMC
Networks QCA9377 to quirks table"), was queued for 7.2.y down to
5.10.y in October after a similar request.

Thank you,
Iaroslav Voitovych
```

**`contributions/research-2026-11-01/qca-ids/refresh-20261114/CHECKS.md`** (SHA-256 `16d46882e219222fc1242ffcb58049af5e73b1174b34ddc2ef2626871f0e3482`)

```markdown
# CO-22 refresh: the ASUS ROME pair against today's stable tips, 2026-11-14 (UTC)

Work area: `/root/exp/agent-work/lane5-status-stable-20261114/co22/` (scripts `asus.sh`, `run-all.sh`; logs in `logs/`; mail in `mail/`; hashes in `SHA256SUMS`). Nothing was sent; the project tree was not written to. Trees: depth-1 fetches of the stable tags and depth-2 fetches of the two mainline commits from the GitHub mirrors (`../k-fetch.sh`, `../k-fetch2.sh`).

## 1. Facts

| what | value | source |
|---|---|---|
| the pair | `d54601f21faf1ab5728e98e2102c3f738be0c177` "Bluetooth: btusb: add ASUS 0b05:1868 to QCA Rome quirks" (committed 2026-10-14 18:38:17 UTC), `cfa67a1dbfd9425044f6eef037a114b2d108f436` "... 0b05:1825 ..." (18:38:20 UTC); in v7.4-rc1 and master; in mainline they touch `drivers/bluetooth/btusb_main.c` (the 7.4 split) | `gh api`, 2026-11-14 |
| in a stable release or queue | no: neither ID in the `btusb.c` history of v7.3.4, v6.18.63, v6.12.117, v6.6.162, v6.1.192 (newest 15 commits each, back to Aug/Sep); `grep -c` of both IDs in the tag's `btusb.c`: 0 and 0 for every tag (first line of each `logs/pick-<tag>.log`); `stable-queue-check.sh bluetooth-btusb-add-asus-0b05`: not in queue for 7.3, 6.18, 6.12, 6.6, 6.1 (2026-11-14 01:05 UTC). 5.15 and 5.10 queues were not checked today (11-02: not in queue) | status check files |
| tips today | 7.3.4 (11-10), 6.18.63 (11-10), 6.12.117 (11-10), 6.6.162 (11-06), 6.1.192 (11-06), 5.15.225 (11-06), 5.10.274 (11-06) | kernel.org `releases.json`, 00:40Z |

## 2. Cherry-pick and btusb.o (measured; `logs/pick-<tag>.log`, `logs/build-btusb-<tag>-{base,pair}.log`)

`git cherry-pick -x d54601f21faf cfa67a1dbfd9` onto the tag, in that order, in its own worktree; `btusb.o` built before (base) and after (pair) with x86_64 defconfig + `BT=m`, `BT_HCIBTUSB=m` (+ `BT_BREDR`, `BT_LE`, `USB`, `NET`, `INET`, `RFKILL`), `make W=1 drivers/bluetooth/btusb.o`:

| tag | cherry-pick | base btusb.o | pair btusb.o | warning sets |
|---|---|---|---|---|
| v7.3.4 | clean (rc=0; "Auto-merging drivers/bluetooth/btusb.c" - the rename is followed) | built, 0 warnings | built, 0 warnings | identical |
| v6.18.63 | clean | built, 0 | built, 0 | identical |
| v6.12.117 | clean | built, 0 | built, 0 | identical |
| v6.6.162 | clean | **fails** with W=1 (rc=2): four `-Werror=unused-function` errors from `btmtk.h`, on the plain tag too (`logs/build-btusb-v6.6.162-base-with-werror.log`, `-pair-with-werror.log`) | same failure | with `CONFIG_WERROR` off (`NOWERROR=1`): both build, 4 warnings each, **identical** (`logs/pick-v6.6.162.log`) |
| v6.1.192 | clean | built, 0 | built, 0 | identical |
| v5.15.225 | clean | built, 0 | built, 0 | identical |
| v5.10.274 | clean | built, 0 | built, 0 | identical |

After the pick each `btusb.c` has both IDs once and the diffstat is 4 insertions in `btusb.c` (`logs/pick-<tag>.log`). The tool used: the host's gcc (as in the 2026-11-01 run, same tsv result "OK" for all lines). Results agree with `research-2026-11-01/qca-ids/stable-cherry-pick-asus.tsv` (7.3.1, 6.18.60, 6.12.115, 6.6.161, 6.1.191 clean); 5.15 and 5.10 are new in this table and also clean. The 6.6 W=1 failure is the known btmtk `-Werror` issue of that line (a separate report draft exists: `drafts/btmtk-6.6-werror-report.eml`); it does not come from the pair.

## 3. Request v3 (`mail/stable-request-asus-rome-v3.eml`, new; v2 kept)

Differences from v2: the seven tips named above (7.3.4 ... 5.10.274); "neither commit is in a stable release or in the stable queue (checked 2026-11-14)"; one sentence on the 7.4 file split and git's rename detection (the cherry-picks land in `btusb.c`); one sentence on the 6.6.162 W=1 failure being independent of the commits. mail-lint: clean. The send-day recheck of the queues is still owed (F-39 style): re-run `stable-queue-check.sh bluetooth-btusb-add-asus-0b05 7.3 6.18 6.12 6.6 6.1 5.15 5.10` and look at the tips.

## 4. Daan Bouwman's patch, patchwork 14976888 (0cf3:e303, Surface Laptop 3 AMD)

What it is (read from `raw/pw-14976888.json` of the status check): `[PATCH] Bluetooth: btusb: Add QCA Rome support for Surface Laptop 3 AMD (0cf3:e303)`, 2026-11-12 15:24 UTC, state `new` at 2026-11-14 ~03:06 UTC, only the CI bot has commented (21:23 UTC). One hunk in `drivers/bluetooth/btusb_main.c`, two lines: `0cf3:e303` with `BTUSB_QCA_ROME | BTUSB_WIDEBAND_SPEECH`, placed after `0cf3:e301`. The author reports the device as QCA6174, shows the `lsusb`-style device listing, the rampatch/NVM 0x302 files loading, and says he tested on v7.2.15: stock btusb shows "unexpected event for opcode 0x2005", patched shows none. It carries `Cc: stable@vger.kernel.org` itself. It is not in bluetooth-next (btusb history, 2026-11-14 01:10 UTC) or mainline.

Answer: **ID survey only; not in the request.**
- It is not merged; a stable request may only name mainline commits. Once it is merged it carries its own `Cc: stable`, so the stable team will take it without a request from us; adding it would only double the thread.
- The ID is already in the survey as a candidate (`candidate-computers.tsv`: `0cf3:e303`, Surface Laptop 3; `linuxhw-bt-ids.tsv`; `dmesg-evidence.tsv`). The patch turns that candidate into a confirmed one by an independent author's device report. Record it in the survey with the patchwork ID.
- The owners' call mail (`drafts/owners-call-qca-rome-ids.eml`, line 30) still lists `0cf3:e303`: that line should go (the patch exists), and the mail's count of open candidates drops by one. This is a draft edit for the main session to decide.
- Not "nowhere": it supports the first paragraph of the request's argument (more ROME IDs missing from the table, the same symptom) and the survey's count; and it is a second 2026 patch of the same shape that the maintainers accepted without objection so far (the ASUS pair, merged 10-14), which suggests the owners' mail may get a quick answer. (inferred)
- Its text carries a tool note in the "Notes" block; nothing of it is copied into our files.

## 5. Not done / limits

Only `btusb.o` was built (as asked); no module was loaded and no device test was possible (the devices are the authors'). The 6.6 W=1 failure needs `CONFIG_WERROR=n` to build the object. 5.15/5.10 queue state was last checked 2026-11-02. A send-day recheck is owed.
```

---

## 9. CO-21 — btusb picks alternate setting 0 while a SCO link is up

**The defect** (`Fixes: baac6276c0a9`). `btusb_notify()` takes the air mode from the one link
whose state changed and picks the USB alternate setting from it. With two SCO links, one going
down switches the other to alt 0, and a single-link race does the same (seen twice on the laptop,
2026-09-02). **The design** (two patches, now on bluetooth-next `da3cc02587c6`): the core keeps the air
mode of each SCO link that came up (from its Synchronous Connection Complete event), and btusb's
worker derives the setting from the links that are up; notify only schedules it. An earlier
single-patch candidate was judged not ready by an outside review (a failed second setup still
sends the link-up notification); this design answers that.

**Tested** (2026-11-14, on the rebased pair): real btusb in a QEMU guest against an emulated
controller through usbip, five scenarios (two links, either one going down first; mSBC and CVSD;
the single-link race), two runs each: unpatched 0 of 10, patched 10 of 10; a 20-scenario model of
the worker (11-01). The bot's checks: builds and all 11 testers pass, tester results identical to
the base side; only the three Signed-off-by checks fail. Patch 2's subject is now 65 characters.
Patch 1 changes `struct hci_conn`, so `bluetooth.ko` and btusb must be rebuilt together.

**Questions for you.** The design itself: is a per-link air mode in the core acceptable, or should
btusb track it alone? The counting helper's locking. `Cc: stable`: patch 2 cannot build without
patch 1, so a stable tag would have to cover both.

**`contributions/CO-21-btusb-sco-alt-setting/send-20261114/cover-letter.txt`** (SHA-256 `081023850715ada81bcba3a0bdbce3aae19a880c86ba5f7744c51ab49aadb9ee`)

```text
Subject: [PATCH 0/2] Bluetooth: btusb: Pick the SCO alternate setting from the links that are up

btusb chooses the isochronous alternate setting from the last SCO
notification, not from the SCO links that exist. When one of two SCO
links goes down, the remaining link is moved to alternate setting 0,
which has no isochronous bandwidth. A SCO connection is also counted
from the start of its setup: if another connection is added or removed
while it is being set up, the notification of the link coming up is
ignored.

 1: keep the air mode of a SCO link that came up in the connection and
    add a helper that counts the links that are up by air mode.
 2: let btusb_work() select the alternate setting from those counts.

Patch 2 needs patch 1.

Tested with a userspace controller attached over usbip to a QEMU guest
(the real btusb and core): five scenarios (two mSBC links with either
one hung up first, two CVSD links, and a single link set up while another
connection is added and removed, for mSBC and for CVSD). Unpatched, the
setting is wrong at some point in all five; with the series all five
pass, in two runs each.

The series applies on bluetooth-next without conflicts. The existing
sco-tester results are the same with and without it.
```

**`contributions/CO-21-btusb-sco-alt-setting/send-20261114/0001-Bluetooth-Keep-the-air-mode-of-SCO-links-that-came-u.patch`** (SHA-256 `2a32bab6cf0b0c994745a27e144d1bf425c21cc562626a1de877c67e168ec5c8`)

```diff
From b3081ed5919f046c579809afc699b771efb2e2bc Mon Sep 17 00:00:00 2001
From: Iaroslav Voitovych <yaroslav.voytovych@gmail.com>
Date: Sun, 1 Nov 2026 18:33:56 +0100
Subject: [PATCH 1/2] Bluetooth: Keep the air mode of SCO links that came up

The air mode of a synchronous link is passed to the driver as
HCI_NOTIFY_ENABLE_SCO_CVSD or HCI_NOTIFY_ENABLE_SCO_TRANSP and not kept.
conn->setting is the voice setting the host asked for, which is not
always the air mode of the link: it is left unset for an incoming
connection, which is accepted with the setting of its socket, and
hci_connect_sco() overwrites it for an existing connection, also one
whose link is up.

Keep in the connection the air mode reported by Synchronous Connection
Complete, and for a SCO link that completes with Connection Complete
the one its notification already assumes. Add hci_conn_sco_up_num() to
count the SCO links that are up by air mode, so that a driver can
configure itself from the links that exist instead of from the last
notification.
---
 include/net/bluetooth/hci.h      |  6 ++++++
 include/net/bluetooth/hci_core.h | 25 +++++++++++++++++++++++++
 net/bluetooth/hci_event.c        |  2 ++
 3 files changed, 33 insertions(+)

diff --git a/include/net/bluetooth/hci.h b/include/net/bluetooth/hci.h
index efb85c781e4e9..4a21721411689 100644
--- a/include/net/bluetooth/hci.h
+++ b/include/net/bluetooth/hci.h
@@ -2898,6 +2898,12 @@ struct hci_ev_sync_conn_complete {
 	__u8     air_mode;
 } __packed;
 
+/* Air_Mode of HCI_Synchronous_Connection_Complete */
+#define HCI_AIR_MODE_ULAW	0x00
+#define HCI_AIR_MODE_ALAW	0x01
+#define HCI_AIR_MODE_CVSD	0x02
+#define HCI_AIR_MODE_TRANSP	0x03
+
 #define HCI_EV_SYNC_CONN_CHANGED	0x2d
 struct hci_ev_sync_conn_changed {
 	__u8     status;
diff --git a/include/net/bluetooth/hci_core.h b/include/net/bluetooth/hci_core.h
index 6e07bf206e4ad..5380aa39dac97 100644
--- a/include/net/bluetooth/hci_core.h
+++ b/include/net/bluetooth/hci_core.h
@@ -778,6 +778,7 @@ struct hci_conn {
 	__u16		disc_timeout;
 	__u16		conn_timeout;
 	__u16		setting;
+	__u8		air_mode;
 	__u16		auth_payload_timeout;
 	__u16		le_conn_min_interval;
 	__u16		le_conn_max_interval;
@@ -1149,6 +1150,30 @@ static inline unsigned int hci_conn_num(struct hci_dev *hdev, __u8 type)
 	}
 }
 
+/* Number of SCO and eSCO links that are up, carry their data over HCI and
+ * use the given air mode (HCI_AIR_MODE_*)
+ */
+static inline unsigned int hci_conn_sco_up_num(struct hci_dev *hdev,
+					       __u8 air_mode)
+{
+	struct hci_conn_hash *h = &hdev->conn_hash;
+	struct hci_conn *c;
+	unsigned int num = 0;
+
+	rcu_read_lock();
+
+	list_for_each_entry_rcu(c, &h->list, list) {
+		if ((c->type == SCO_LINK || c->type == ESCO_LINK) &&
+		    c->state == BT_CONNECTED && !c->codec.data_path &&
+		    c->air_mode == air_mode)
+			num++;
+	}
+
+	rcu_read_unlock();
+
+	return num;
+}
+
 static inline unsigned int hci_conn_count(struct hci_dev *hdev)
 {
 	struct hci_conn_hash *c = &hdev->conn_hash;
diff --git a/net/bluetooth/hci_event.c b/net/bluetooth/hci_event.c
index 419a7e6748507..4ea66f6aa7120 100644
--- a/net/bluetooth/hci_event.c
+++ b/net/bluetooth/hci_event.c
@@ -3432,6 +3432,7 @@ static void hci_conn_complete_evt(struct hci_dev *hdev, void *data,
 	} else if (ev->link_type == SCO_LINK) {
 		switch (conn->setting & SCO_AIRMODE_MASK) {
 		case SCO_AIRMODE_CVSD:
+			conn->air_mode = HCI_AIR_MODE_CVSD;
 			if (hdev->notify)
 				hdev->notify(hdev, HCI_NOTIFY_ENABLE_SCO_CVSD);
 			break;
@@ -5624,6 +5625,7 @@ static void hci_sync_conn_complete_evt(struct hci_dev *hdev, void *data,
 
 		conn->state  = BT_CONNECTED;
 		conn->type   = ev->link_type;
+		conn->air_mode = ev->air_mode;
 
 		hci_debugfs_create_conn(conn);
 		hci_conn_add_sysfs(conn);
-- 
2.43.0

```

**`contributions/CO-21-btusb-sco-alt-setting/send-20261114/0002-Bluetooth-btusb-Pick-the-SCO-alt-setting-from-links-.patch`** (SHA-256 `c6619e69a92ceba902f2053d1d3830b957279cc439a3921423379e01e43b4626`)

```diff
From 18500f5259e29f7114e4cb63a5762ee7cc90c53e Mon Sep 17 00:00:00 2001
From: Iaroslav Voitovych <yaroslav.voytovych@gmail.com>
Date: Sun, 1 Nov 2026 18:33:58 +0100
Subject: [PATCH 2/2] Bluetooth: btusb: Pick the SCO alt setting from links
 that are up

btusb_notify() takes the air mode from whichever notification changed
the number of SCO connections, and btusb_work() selects alternate
setting 0, which has no isochronous bandwidth, for anything that is
neither CVSD nor transparent:

- When one of two SCO links goes down, HCI_NOTIFY_DISABLE_SCO becomes
  the air mode, and the link that stays up is moved to alternate
  setting 0.
- A SCO connection is counted from the start of its setup. When another
  connection is added or removed meanwhile, HCI_NOTIFY_CONN_ADD or
  HCI_NOTIFY_CONN_DEL becomes the air mode, and the notification of the
  link coming up is ignored, as the count does not change.
- The link-up notification is also sent for a setup that failed, so a
  failed transparent setup can move a CVSD link that is up to the
  transparent setting.
- With a CVSD and a transparent link up, the setting is that of the
  last notification.

Select the alternate setting in btusb_work() from the SCO links that
are up when it runs: the CVSD table for CVSD links, the transparent
setting when a transparent link is up, and no isochronous transfers
when no link is up. The notifications only schedule the work, so
notifications that come before it runs are all taken into account.

Fixes: baac6276c0a9 ("Bluetooth: btusb: handle mSBC audio over USB Endpoints")
---
 drivers/bluetooth/btusb_main.c | 26 ++++++++++++++++----------
 1 file changed, 16 insertions(+), 10 deletions(-)

diff --git a/drivers/bluetooth/btusb_main.c b/drivers/bluetooth/btusb_main.c
index 95398e2ca098e..4e017a9cd9555 100644
--- a/drivers/bluetooth/btusb_main.c
+++ b/drivers/bluetooth/btusb_main.c
@@ -1069,8 +1069,6 @@ struct btusb_data {
 	__u8 cmdreq;
 	__u8 proto;
 
-	unsigned int sco_num;
-	unsigned int air_mode;
 	bool usb_alt6_packet_flow;
 	int isoc_altsetting;
 	int suspend_count;
@@ -2475,10 +2473,13 @@ static void btusb_notify(struct hci_dev *hdev, unsigned int evt)
 
 	BT_DBG("%s evt %d", hdev->name, evt);
 
-	if (hci_conn_num(hdev, SCO_LINK) != data->sco_num) {
-		data->sco_num = hci_conn_num(hdev, SCO_LINK);
-		data->air_mode = evt;
+	/* btusb_work() reads the SCO links that are up when it runs */
+	switch (evt) {
+	case HCI_NOTIFY_ENABLE_SCO_CVSD:
+	case HCI_NOTIFY_ENABLE_SCO_TRANSP:
+	case HCI_NOTIFY_DISABLE_SCO:
 		schedule_work(&data->work);
+		break;
 	}
 }
 
@@ -2587,6 +2588,7 @@ static void btusb_work(struct work_struct *work)
 {
 	struct btusb_data *data = container_of(work, struct btusb_data, work);
 	struct hci_dev *hdev = data->hdev;
+	unsigned int cvsd, transp;
 	int new_alts = 0;
 	int err;
 
@@ -2597,7 +2599,11 @@ static void btusb_work(struct work_struct *work)
 	if (data->proto == BTUSB_PROTO_H4)
 		return;
 
-	if (data->sco_num > 0) {
+	/* Pick the alternate setting from the SCO links that are up */
+	cvsd = hci_conn_sco_up_num(hdev, HCI_AIR_MODE_CVSD);
+	transp = hci_conn_sco_up_num(hdev, HCI_AIR_MODE_TRANSP);
+
+	if (cvsd || transp) {
 		if (!test_bit(BTUSB_DID_ISO_RESUME, &data->flags)) {
 			err = usb_autopm_get_interface(data->isoc ? data->isoc : data->intf);
 			if (err < 0) {
@@ -2609,18 +2615,18 @@ static void btusb_work(struct work_struct *work)
 			set_bit(BTUSB_DID_ISO_RESUME, &data->flags);
 		}
 
-		if (data->air_mode == HCI_NOTIFY_ENABLE_SCO_CVSD) {
+		if (!transp) {
 			if (hdev->voice_setting & 0x0020) {
 				static const int alts[3] = { 2, 4, 5 };
 				unsigned int sco_idx;
 
-				sco_idx = min_t(unsigned int, data->sco_num - 1,
+				sco_idx = min_t(unsigned int, cvsd - 1,
 						ARRAY_SIZE(alts) - 1);
 				new_alts = alts[sco_idx];
 			} else {
-				new_alts = data->sco_num;
+				new_alts = cvsd;
 			}
-		} else if (data->air_mode == HCI_NOTIFY_ENABLE_SCO_TRANSP) {
+		} else {
 			/* Bluetooth USB spec recommends alt 6 (63 bytes), but
 			 * many adapters do not support it.  Alt 1 appears to
 			 * work for all adapters that do not have alt 6, and
-- 
2.43.0

```

**`contributions/CO-21-btusb-sco-alt-setting/send-20261114/CHECKS.md`** (SHA-256 `720a211066a03b3d3483478ed395e81f7154507c52eec5b651e7c0471a106a43`)

````markdown
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
````

---

## 10. CO-20 — btusb logs the data of a just-closed SCO link as corruption

**The defect.** After a SCO link's Disconnection Complete, the controller can still deliver a few
packets for its handle. btusb drops them, but logs "corrupted SCO packet" and counts them in
`err_rx`, the same message and counter as real corruption and allocation failure, so every hung-up
call looks like a link error (on the laptop, 25 of 32 such lines fell within 0.5 s of a
disconnect). Patch 1 reports receive failures by cause; patch 2 logs data for a just-closed link at
debug level and does not count it as an error. No `Fixes:`. Mainline's separate newline fix for the
same message is `f51ee3bb5fbe`.

**Tested** (2026-11-14, real btusb in a QEMU guest, emulated controller): 20 calls hung up with
data in flight, 3 runs: unpatched 17, 19 and 24 "corrupted SCO packet" lines, patched none (the
residue at debug level). Five packets for a handle that never was a link: unpatched counted as
corrupted, patched reported as an unknown handle and not as corrupted. Limitation (in patch 2's
message): with two links up, data of the closed link that follows a packet of the remaining one is
still reported. The bot's checks: only the Signed-off-by checks fail; it selects no tester for a
btusb-only change.

**Questions for you.** Whether the classification belongs in btusb or in the core's SCO receive
path; whether the debug-level line is worth keeping at all.

**`contributions/CO-20-sco-unknown-handle-messages/send-20261114/cover-letter.txt`** (SHA-256 `165af202fc66230cec2d3179452a712a8e14148849511eadf9b18a1836dd9238`)

```text
Subject: [PATCH 0/2] Bluetooth: btusb: Do not report the end of a SCO call as corruption

At the end of most SCO and eSCO calls the controller still delivers
data it queued before the Disconnection Complete. btusb rejects it,
because the connection is gone, with the same "corrupted SCO packet"
error as for real corruption, and counts it in err_rx. On one laptop
155 of 181 closed links had receive data after the Disconnection
Complete (up to 33.6 ms), and 25 of 32 "corrupted SCO packet" lines
fell within 0.5 s of one.

 1: btusb_recv_isoc() returns a distinct error for an allocation
    failure, a header whose length does not fit, and a header whose
    handle is not a live connection; each gets its own message, the
    last naming the handle, and the two new ones are rate limited.
 2: data for the handle of the link that has just closed is logged at
    debug level and not counted in err_rx. Any other unknown handle,
    which is how a misaligned fragment after a lost isochronous frame
    shows, stays an error and is counted.

Tested with a userspace controller attached over usbip to a QEMU guest
(the real btusb and core). In three runs of 20 calls with data in flight
at the hang-up, the unpatched kernel logged "corrupted SCO packet" 17,
19 and 24 times and the series none, with 15 to 18 debug lines. With
two links up and five packets injected for a handle that never was a
link, the unpatched kernel logged 6 or 7 "corrupted SCO packet" and the
series 5 to 7 "unknown handle dropped" and none of the former; the
excess over five is data of the link that closed first, which patch 2
documents as still reported.
```

**`contributions/CO-20-sco-unknown-handle-messages/send-20261114/0001-Bluetooth-btusb-Report-SCO-receive-failures-by-cause.patch`** (SHA-256 `cc00b6ef028c6f3b1b96f87e2a8c28481a3daeca1d713d2ceb8926a3db93272c`)

```diff
From 627f4c5328a61ae7c33a694b07417d48f6b24e23 Mon Sep 17 00:00:00 2001
From: Iaroslav Voitovych <yaroslav.voytovych@gmail.com>
Date: Sat, 14 Nov 2026 03:31:36 +0100
Subject: [PATCH 1/2] Bluetooth: btusb: Report SCO receive failures by cause

btusb_isoc_complete() logs "corrupted SCO packet" whenever
btusb_recv_isoc() fails, but btusb_recv_isoc() fails in three different
cases: no memory for a new packet, a header whose length does not fit
the buffer, and a header whose handle is not a live SCO or eSCO
connection. The last one is the common case. It is how a continuation
fragment taken for a header after a lost isochronous frame is caught,
but it also catches the data that controllers deliver for a link the
host has just deleted, which happens at the end of most calls. All
three print the same line, so the log cannot tell a hang-up from data
loss, and the rejected handle is not shown.

Return a distinct error for each case. Keep "corrupted SCO packet" for
the length check, and give allocation failure and the unknown handle
messages of their own, the latter naming the handle. Rate-limit the two
new messages: an isochronous URB completes every millisecond.

All three still count in err_rx. Allocation failures count there on the
interrupt and bulk paths too. An unknown handle cannot be told apart
from a misaligned fragment here, and it is the check that catches one:
bt_skb_alloc(HCI_MAX_SCO_SIZE) leaves at least 252 bytes of tailroom
after the header, so the length check can reject only a dlen of 253 to
255.
---
 drivers/bluetooth/btusb_main.c | 36 +++++++++++++++++++++++++++-------
 1 file changed, 29 insertions(+), 7 deletions(-)

diff --git a/drivers/bluetooth/btusb_main.c b/drivers/bluetooth/btusb_main.c
index 95398e2ca098e..3e69091001567 100644
--- a/drivers/bluetooth/btusb_main.c
+++ b/drivers/bluetooth/btusb_main.c
@@ -1545,7 +1545,12 @@ static bool btusb_validate_sco_handle(struct hci_dev *hdev,
 	}
 }
 
-static int btusb_recv_isoc(struct btusb_data *data, void *buffer, int count)
+/* Returns 0, -ENOMEM when no buffer could be allocated, -EILSEQ for a header
+ * whose length does not fit, or -ENOENT for a header whose handle is not a
+ * live SCO or eSCO connection; the rejected handle is then stored in *handle.
+ */
+static int btusb_recv_isoc(struct btusb_data *data, void *buffer, int count,
+			   u16 *handle)
 {
 	struct sk_buff *skb;
 	unsigned long flags;
@@ -1581,14 +1586,22 @@ static int btusb_recv_isoc(struct btusb_data *data, void *buffer, int count)
 
 			hci_skb_expect(skb) = hdr->dlen;
 
-			if (skb_tailroom(skb) < hci_skb_expect(skb) ||
-			    !btusb_validate_sco_handle(data->hdev, hdr)) {
+			if (skb_tailroom(skb) < hci_skb_expect(skb)) {
 				kfree_skb(skb);
 				skb = NULL;
 
 				err = -EILSEQ;
 				break;
 			}
+
+			if (!btusb_validate_sco_handle(data->hdev, hdr)) {
+				*handle = hci_handle(__le16_to_cpu(hdr->handle));
+				kfree_skb(skb);
+				skb = NULL;
+
+				err = -ENOENT;
+				break;
+			}
 		}
 
 		if (!hci_skb_expect(skb)) {
@@ -1821,6 +1834,7 @@ static void btusb_isoc_complete(struct urb *urb)
 {
 	struct hci_dev *hdev = urb->context;
 	struct btusb_data *data = hci_get_drvdata(hdev);
+	u16 handle;
 	int i, err;
 
 	BT_DBG("%s urb %p status %d count %d", hdev->name, urb, urb->status,
@@ -1839,11 +1853,19 @@ static void btusb_isoc_complete(struct urb *urb)
 
 			hdev->stat.byte_rx += length;
 
-			if (btusb_recv_isoc(data, urb->transfer_buffer + offset,
-					    length) < 0) {
+			err = btusb_recv_isoc(data, urb->transfer_buffer + offset,
+					      length, &handle);
+			if (!err)
+				continue;
+
+			if (err == -ENOMEM)
+				bt_dev_err_ratelimited(hdev, "no memory for SCO packet");
+			else if (err == -ENOENT)
+				bt_dev_err_ratelimited(hdev, "SCO packet for unknown handle %u dropped",
+						       handle);
+			else
 				bt_dev_err(hdev, "corrupted SCO packet");
-				hdev->stat.err_rx++;
-			}
+			hdev->stat.err_rx++;
 		}
 	} else if (urb->status == -ENOENT) {
 		/* Avoid suspend failed when usb_kill_urb */
-- 
2.43.0

```

**`contributions/CO-20-sco-unknown-handle-messages/send-20261114/0002-Bluetooth-btusb-Log-SCO-data-for-a-just-closed-link-.patch`** (SHA-256 `ed885c0b6ad0ba896f03edcddfe97a92ec80d10ca25dbc350f5a675bc91aad42`)

```diff
From b40e722f699e3343cf03458548dfaedf823f08f1 Mon Sep 17 00:00:00 2001
From: Iaroslav Voitovych <yaroslav.voytovych@gmail.com>
Date: Sat, 14 Nov 2026 03:31:44 +0100
Subject: [PATCH 2/2] Bluetooth: btusb: Log SCO data for a just closed link at
 debug level

When a SCO or eSCO link is disconnected, the controller can still
deliver data that it queued before the Disconnection Complete. Once
hci_conn_del() has removed the connection from the hash, and until the
notification that stops the isochronous URBs has been handled, such data
reaches btusb_recv_isoc() with a handle that btusb_validate_sco_handle()
no longer finds. It is then logged as an unknown handle and counted in
err_rx, at the end of most calls.

Remember the handle of the last SCO header that validated. A header
whose handle is no longer live but equals that handle is data for the
link that has just closed: log it at debug level and do not count it in
err_rx. Any other unknown handle, most likely a continuation fragment
taken for a header after a lost isochronous frame, stays an error and is
counted.

The remembered handle is protected by rxlock, like the reassembly
state. It is forgotten when the reassembly state is, on an alternate
setting change and in btusb_free_frags(), and when the last SCO link is
gone and the isochronous URBs have been killed, so that it cannot match
a later misaligned fragment. Only a misaligned fragment in the short
window after its own link closed, whose first two bytes give that
link's handle, is still taken for residue. With two links up, data of
the closed link that comes after a packet of the remaining one is still
reported as an unknown handle.
---
 drivers/bluetooth/btusb_main.c | 42 ++++++++++++++++++++++++++++++----
 1 file changed, 38 insertions(+), 4 deletions(-)

diff --git a/drivers/bluetooth/btusb_main.c b/drivers/bluetooth/btusb_main.c
index 3e69091001567..12dc6bb3ade1e 100644
--- a/drivers/bluetooth/btusb_main.c
+++ b/drivers/bluetooth/btusb_main.c
@@ -1055,6 +1055,10 @@ struct btusb_data {
 	struct sk_buff *sco_skb;
 	struct sk_buff *rx_skb;
 
+	/* Handle of the last SCO header that validated, under rxlock */
+	u16 sco_last_handle;
+	bool sco_last_valid;
+
 	struct usb_endpoint_descriptor *intr_ep;
 	struct usb_endpoint_descriptor *bulk_tx_ep;
 	struct usb_endpoint_descriptor *bulk_rx_ep;
@@ -1299,6 +1303,7 @@ static inline void btusb_free_frags(struct btusb_data *data)
 
 	dev_kfree_skb_irq(data->sco_skb);
 	data->sco_skb = NULL;
+	data->sco_last_valid = false;
 
 	/* rx_skb may hold an ERR_PTR from a previous h4_recv_skb() call */
 	if (!IS_ERR(data->rx_skb))
@@ -1546,14 +1551,18 @@ static bool btusb_validate_sco_handle(struct hci_dev *hdev,
 }
 
 /* Returns 0, -ENOMEM when no buffer could be allocated, -EILSEQ for a header
- * whose length does not fit, or -ENOENT for a header whose handle is not a
- * live SCO or eSCO connection; the rejected handle is then stored in *handle.
+ * whose length does not fit, -ENOTCONN for a header whose handle is no longer
+ * live but is the handle of the last header that validated, which is data
+ * for a link that has just been deleted, or -ENOENT for any other header
+ * whose handle is not a live SCO or eSCO connection. For -ENOTCONN and
+ * -ENOENT the rejected handle is stored in *handle.
  */
 static int btusb_recv_isoc(struct btusb_data *data, void *buffer, int count,
 			   u16 *handle)
 {
 	struct sk_buff *skb;
 	unsigned long flags;
+	u16 h;
 	int err = 0;
 
 	spin_lock_irqsave(&data->rxlock, flags);
@@ -1594,14 +1603,23 @@ static int btusb_recv_isoc(struct btusb_data *data, void *buffer, int count,
 				break;
 			}
 
+			h = hci_handle(__le16_to_cpu(hdr->handle));
+
 			if (!btusb_validate_sco_handle(data->hdev, hdr)) {
-				*handle = hci_handle(__le16_to_cpu(hdr->handle));
+				*handle = h;
 				kfree_skb(skb);
 				skb = NULL;
 
-				err = -ENOENT;
+				if (data->sco_last_valid &&
+				    h == data->sco_last_handle)
+					err = -ENOTCONN;
+				else
+					err = -ENOENT;
 				break;
 			}
+
+			data->sco_last_handle = h;
+			data->sco_last_valid = true;
 		}
 
 		if (!hci_skb_expect(skb)) {
@@ -1858,6 +1876,12 @@ static void btusb_isoc_complete(struct urb *urb)
 			if (!err)
 				continue;
 
+			if (err == -ENOTCONN) {
+				bt_dev_dbg(hdev, "SCO packet for closed handle %u dropped",
+					   handle);
+				continue;
+			}
+
 			if (err == -ENOMEM)
 				bt_dev_err_ratelimited(hdev, "no memory for SCO packet");
 			else if (err == -ENOENT)
@@ -2570,6 +2594,7 @@ static int btusb_switch_alt_setting(struct hci_dev *hdev, int new_alts)
 		spin_lock_irqsave(&data->rxlock, flags);
 		dev_kfree_skb_irq(data->sco_skb);
 		data->sco_skb = NULL;
+		data->sco_last_valid = false;
 		spin_unlock_irqrestore(&data->rxlock, flags);
 
 		err = __set_isoc_interface(hdev, new_alts);
@@ -2665,8 +2690,17 @@ static void btusb_work(struct work_struct *work)
 		if (btusb_switch_alt_setting(hdev, new_alts) < 0)
 			bt_dev_err(hdev, "set USB alt:(%d) failed!", new_alts);
 	} else {
+		unsigned long flags;
+
 		usb_kill_anchored_urbs(&data->isoc_anchor);
 
+		/* No more SCO data can arrive: forget the last handle so that
+		 * a later misaligned fragment is not taken for its data.
+		 */
+		spin_lock_irqsave(&data->rxlock, flags);
+		data->sco_last_valid = false;
+		spin_unlock_irqrestore(&data->rxlock, flags);
+
 		if (test_and_clear_bit(BTUSB_ISOC_RUNNING, &data->flags))
 			__set_isoc_interface(hdev, 0);
 
-- 
2.43.0

```

**`contributions/CO-20-sco-unknown-handle-messages/send-20261114/CHECKS.md`** (SHA-256 `48770b7a8d246eba0a9bbe35b432df78f447e78237e9589fc994db7c93ae502f`)

````markdown
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
````

---

## 11. CO-43, the rest (for review, not yet to send) — btusb when a resume fails

**What it is.** The other btusb fixes from BT-17's emulation, as one series on top of item 2 (E):
A (item 3), then B2 (the HCI command timeout no longer waits 5 s on a resume that never comes,
and still resets a wedged controller), D v2 (after a runtime reset-resume, queue a reset so btusb
is rebound; BT-18), BT-24's fix (a failed resume drops the deferred URBs under `txlock`) and BT-25's
fix (the skb of a dropped deferred URB is freed). B2 needs D: alone it leaves a recovering device
dead.

**Tested** (QEMU, emulated `13d3:3503` that fails its resume): with the whole series, the runtime
matrix (dead device, recovering device, power-off-started resume, dropped command, wedged
controller, 30 healthy cycles; 3 runs each) 18 of 18; unpatched, the recovering-after-power-off
case is dead 3 of 3 and the dead device blocks the HCI workqueue for 5.4 s. BT-25: kmemleak finds
leaked HCI command skbs in 11 of 12 fault runs without the fix, none with it. **Not tested:** the
system-suspend path, which `vhci_hcd` cannot exercise; D v2 queues its reset only inside a runtime
resume, and that the system path is unchanged rests on reading `drivers/usb/core/driver.c`.

**Questions for you.** D v2's `RPM_RESUMING` test as the way to tell a runtime reset-resume from a
system one; whether D belongs in btusb at all, or BT-18 is the USB core's to fix (a question to
linux-usb is drafted); B2's handling of the command credit.

**`contributions/CO-43-btusb-runtime-resume-failure/send-series-20261114/0000-cover-letter.patch`** (SHA-256 `eaedfc9a4a11fe1de6e6ae5a9159c207804ccbe049fb51ab0505232da8e716fc`)

```diff
From a2fda18e5f156d765b0e396f8e457916b97ee0ae Mon Sep 17 00:00:00 2001
From: Iaroslav Voitovych <yaroslav.voytovych@gmail.com>
Date: Sat, 14 Nov 2026 03:50:00 +0100
Subject: [PATCH 0/5] Bluetooth: btusb: A device that does not resume

This series applies on top of "Bluetooth: btusb: Anchor a deferred URB
under txlock" (bluetooth-next da3cc02587c6 plus that patch).

A QCA9377 (13d3:3503) that is runtime-suspended and does not answer
when it is resumed leaves the HCI workqueue blocked for more than five
seconds, logs nothing about the failed resume, and, when the USB
core's reset-resume brings the device back, leaves Bluetooth dead.
Two more problems sit on the failure path of btusb_resume() and in the
code that discards deferred URBs. Reproduced with an emulated
controller attached over usbip in a QEMU guest (KASAN, lockdep, four
CPUs); why the controller stopped answering (firmware, platform power
or the host's xHCI) is not addressed here.

 1: log the failed resume of the waker.
 2: do not block the HCI workqueue in the command timeout while the
    device resumes, and keep the reset for a command that did reach
    the controller.
 3: add a reset_resume callback that rebinds btusb after a runtime
    reset-resume.
 4: drop the deferred URBs and clear BTUSB_SUSPENDING under txlock on
    a failed resume, so that no URB stays parked.
 5: free the skb and the setup packet of a deferred URB that is
    discarded instead of sent.

Patch 2 depends on patch 3. Without the rebinding that patch 3 adds,
a device that answers after the core's reset-resume stays bound and
is never resumed (0 of 3 runs recovered with patch 2 alone; unpatched,
the reset that btusb_reset() queued after the wait is what rebound
it). Please apply them together. Patches 4 and 5 are independent of
2 and 3 in effect; 4 can only be exercised once 2 is applied, because
without it the command credit does not return before the failed
resume's path has ended.

Emulation, three runs of each; the unpatched kernel, then the series:

  dead device (core disconnects it): command credit restored after
    5.38 s, then 0.001 s
  device that answers after the reset-resume: back and usable 3 of 3,
    then 3 of 3
  resume started by powering hci0 off: 0 of 3 (the dead state above),
    then 3 of 3
  command whose event is dropped, device autosuspended before the
    timeout: reset, then reset; also for a controller that stays
    silent until it is reset
  30 healthy suspend and resume cycles: no failure, no failure
  failed resume or discard with a command deferred (fault injected
    in the driver for the test): 1 to 4 kmemleak objects per run
    (skbs and setup packets), then none in 12 of 12 runs
  deferred anchor after a failed resume with a second sender in the
    window (injected delay): parked URB in 3 of 3, then none in 3
    of 3

No kernel report in any run. Not tested: the system suspend and resume
path (the emulated device cannot take part in a system sleep); patch 3
queues the reset only while the device's runtime PM status is
RPM_RESUMING, which the PM core sets only in rpm_resume(), before the
runtime_resume callback; this was checked in the source only.

Iaroslav Voitovych (5):
  Bluetooth: btusb: Report a failed runtime resume for deferred data
  Bluetooth: btusb: Don't wait for a resume in the HCI command timeout
  Bluetooth: btusb: Recover after a runtime reset-resume
  Bluetooth: btusb: Drop deferred URBs under txlock on a failed resume
  Bluetooth: btusb: Free the skb of a deferred URB that is discarded

 drivers/bluetooth/btusb_main.c | 148 +++++++++++++++++++++++++++++-----
 1 file changed, 131 insertions(+), 17 deletions(-)

--
2.43.0

```

**`contributions/CO-43-btusb-runtime-resume-failure/send-series-20261114/0002-Bluetooth-btusb-Don-t-wait-for-a-resume-in-the-HCI-c.patch`** (SHA-256 `7c83d379dcd4dfd4600c827d6809a10f58f2a77265a37f6168319d23b1be0eca`)

```diff
From 55141d8369a62cfbcc323b549dcfedf02c15bfab Mon Sep 17 00:00:00 2001
From: Iaroslav Voitovych <yaroslav.voytovych@gmail.com>
Date: Fri, 13 Nov 2026 18:50:17 +0100
Subject: [PATCH 2/5] Bluetooth: btusb: Don't wait for a resume in the HCI
 command timeout

hci_cmd_timeout() calls hdev->reset() on the ordered HCI workqueue and
restores the command credit only when it returns. btusb_reset() first
takes a runtime PM reference with usb_autopm_get_interface(). If the
command timed out because the device is still resuming, that call
waits for the resume to end. When the device does not answer, the USB
core spends more than five seconds on it (the GET_STATUS timeout, then
a reset-resume and its retries), and the HCI workqueue, including RX
and TX work, is blocked all that time.

A command that is parked on the deferred anchor never reached the
controller, and the failed resume belongs to the USB core: it resets
the device and disconnects it if that fails too. A command whose
transfer completed is different: the controller did not answer it, and
the reset is the recovery for that, even if the device has
autosuspended since.

Mark a command that is parked on the deferred anchor with
BTUSB_CMD_DEFERRED, set and cleared under txlock where the anchor is
filled and drained. btusb_reset() then returns at once when the flag
is set. Otherwise it queues a work item, which takes the runtime PM
reference, where waiting is harmless, and resets the device as before.
The work is cancelled in btusb_disconnect() once hci_unregister_dev()
has stopped the HCI workqueues, before BTUSB_RESET is examined and the
data is freed.

Two things change for the device:

- The command credit is restored at once, so each command queued while
  the device resumes times out on its own, about two seconds apart,
  instead of one timeout blocking the queue.

- btusb_reset() no longer resets a device that is resuming. When the
  USB core's reset-resume succeeds, that second reset used to be what
  unbound and rebound btusb: btusb has no reset_resume callback, and
  the core does not rebind after a runtime resume. Without
  "Bluetooth: btusb: Recover after a runtime reset-resume" such a
  device stays bound but is never resumed, and Bluetooth stays dead.
  This patch depends on that one.

Seen with an emulated QCA9377 (13d3:3503) in a QEMU guest: the credit
came back within a few milliseconds instead of after 5.4 s; a command
whose event was dropped, with the device autosuspended before the
timeout, was still reset, and so was a controller that stayed silent
until it was reset; with the dependency above missing, a device that
answered again after the reset-resume stayed dead in 3 of 3 runs.
---
 drivers/bluetooth/btusb_main.c | 50 ++++++++++++++++++++++++++++++----
 1 file changed, 45 insertions(+), 5 deletions(-)

diff --git a/drivers/bluetooth/btusb_main.c b/drivers/bluetooth/btusb_main.c
index aefee17e9b431..879461fb606f4 100644
--- a/drivers/bluetooth/btusb_main.c
+++ b/drivers/bluetooth/btusb_main.c
@@ -1016,6 +1016,7 @@ struct btqca_data {
 #define BTUSB_HW_SSR_ACTIVE	17
 #define BTUSB_WAKEUP_BROKEN	18
 #define BTUSB_RESET		19
+#define BTUSB_CMD_DEFERRED	20
 
 #define BTUSB_PROTO_LEGACY	0x00
 #define BTUSB_PROTO_H4		0x01
@@ -1034,6 +1035,7 @@ struct btusb_data {
 	int intr_interval;
 	struct work_struct  work;
 	struct work_struct  waker;
+	struct work_struct  reset_work;
 	struct delayed_work rx_work;
 
 	struct sk_buff_head acl_q;
@@ -1092,12 +1094,13 @@ struct btusb_data {
 	struct dentry *force_poll_sync_dentry;
 };
 
-static void btusb_reset(struct hci_dev *hdev)
+static void btusb_reset_work(struct work_struct *work)
 {
-	struct btusb_data *data;
+	struct btusb_data *data = container_of(work, struct btusb_data,
+					       reset_work);
+	struct hci_dev *hdev = data->hdev;
 	int err;
 
-	data = hci_get_drvdata(hdev);
 	err = usb_autopm_get_interface(data->intf);
 	if (err) {
 		bt_dev_err(hdev, "Failed usb_autopm_get_interface: %d", err);
@@ -1111,6 +1114,28 @@ static void btusb_reset(struct hci_dev *hdev)
 	usb_queue_reset_device(data->intf);
 }
 
+static void btusb_reset(struct hci_dev *hdev)
+{
+	struct btusb_data *data = hci_get_drvdata(hdev);
+	unsigned long flags;
+	bool deferred;
+
+	/* A command that is still deferred never reached the device, which
+	 * is being resumed. The USB core owns that failure, and waiting for
+	 * the resume here would block the HCI workqueue.
+	 */
+	spin_lock_irqsave(&data->txlock, flags);
+	deferred = test_bit(BTUSB_CMD_DEFERRED, &data->flags);
+	spin_unlock_irqrestore(&data->txlock, flags);
+
+	if (deferred) {
+		bt_dev_warn(hdev, "Command not sent; not resetting");
+		return;
+	}
+
+	schedule_work(&data->reset_work);
+}
+
 static void btusb_intel_reset(struct hci_dev *hdev)
 {
 	struct btusb_data *data = hci_get_drvdata(hdev);
@@ -2236,6 +2261,9 @@ static int btusb_close(struct hci_dev *hdev)
 
 failed:
 	usb_scuttle_anchored_urbs(&data->deferred);
+	spin_lock_irq(&data->txlock);
+	clear_bit(BTUSB_CMD_DEFERRED, &data->flags);
+	spin_unlock_irq(&data->txlock);
 	return 0;
 }
 
@@ -2397,10 +2425,13 @@ static int submit_or_queue_tx_urb(struct hci_dev *hdev, struct urb *urb)
 	 */
 	spin_lock_irqsave(&data->txlock, flags);
 	suspending = test_bit(BTUSB_SUSPENDING, &data->flags);
-	if (!suspending)
+	if (!suspending) {
 		data->tx_in_flight++;
-	else
+	} else {
 		usb_anchor_urb(urb, &data->deferred);
+		if (hci_skb_pkt_type((struct sk_buff *)urb->context) == HCI_COMMAND_PKT)
+			set_bit(BTUSB_CMD_DEFERRED, &data->flags);
+	}
 	spin_unlock_irqrestore(&data->txlock, flags);
 
 	if (!suspending)
@@ -4485,6 +4516,7 @@ static int btusb_probe(struct usb_interface *intf,
 
 	INIT_WORK(&data->work, btusb_work);
 	INIT_WORK(&data->waker, btusb_waker);
+	INIT_WORK(&data->reset_work, btusb_reset_work);
 	INIT_DELAYED_WORK(&data->rx_work, btusb_rx_work);
 
 	skb_queue_head_init(&data->acl_q);
@@ -4892,6 +4924,11 @@ static void btusb_disconnect(struct usb_interface *intf)
 
 	hci_unregister_dev(hdev);
 
+	/* No new reset can be scheduled once the HCI workqueues are gone; wait
+	 * for a pending one before BTUSB_RESET is examined and data is freed.
+	 */
+	cancel_work_sync(&data->reset_work);
+
 	if (data->oob_wake_irq) {
 		device_init_wakeup(&data->udev->dev, false);
 		free_irq(data->oob_wake_irq, data);
@@ -5024,6 +5061,8 @@ static void play_deferred(struct btusb_data *data)
 		kfree(urb->setup_packet);
 		usb_free_urb(urb);
 	}
+
+	clear_bit(BTUSB_CMD_DEFERRED, &data->flags);
 }
 
 static int btusb_resume(struct usb_interface *intf)
@@ -5086,6 +5125,7 @@ static int btusb_resume(struct usb_interface *intf)
 	usb_scuttle_anchored_urbs(&data->deferred);
 done:
 	spin_lock_irq(&data->txlock);
+	clear_bit(BTUSB_CMD_DEFERRED, &data->flags);
 	clear_bit(BTUSB_SUSPENDING, &data->flags);
 	spin_unlock_irq(&data->txlock);
 
-- 
2.43.0

```

**`contributions/CO-43-btusb-runtime-resume-failure/send-series-20261114/0003-Bluetooth-btusb-Recover-after-a-runtime-reset-resume.patch`** (SHA-256 `e87b5ac3870013b3b66a71e17909831d0d3fa0462ef34cce27af1b1526772727`)

```diff
From c3ab199341d6fcf4b045fa99a9d42c45a48a35d7 Mon Sep 17 00:00:00 2001
From: Iaroslav Voitovych <yaroslav.voytovych@gmail.com>
Date: Sat, 14 Nov 2026 01:49:17 +0100
Subject: [PATCH 3/5] Bluetooth: btusb: Recover after a runtime reset-resume

When a runtime resume fails and USB persist is enabled, the USB core
resets the device (a reset-resume). btusb has no reset_resume
callback, so usb_resume_interface() only marks its interfaces for
rebinding. Marked interfaces are rebound after a system resume
(usb_resume_complete()) and after usb_reset_device(), but not after a
runtime resume. btusb therefore stays bound without ever being
resumed: BTUSB_SUSPENDING stays set, its suspend count is off by one,
and every URB it sends from then on is parked on the deferred anchor.
The controller answers USB requests, but Bluetooth is dead until the
device is unplugged or the machine rebooted.

With an emulated QCA9377 (13d3:3503) that answered again only after
the USB reset, closing hci0 (which runtime-resumes the device) left it
in that state: the next power-on failed with HCI Reset timeouts that
never reached the device.

Add a reset_resume callback that resumes as usual and, after a runtime
resume, queues a USB reset. btusb has no pre_reset and post_reset
callbacks, so the core then unbinds and rebinds it, and the controller,
which the reset may have cleared, is set up again.

The reset is queued even if btusb_resume() failed, because
usb_resume_both() ignores its result. usb_lock_device_for_reset()
refuses a device that is suspended, and the work then drops the
request without a message, so take the runtime PM reference that
btusb_reset() takes, guarded by BTUSB_RESET; btusb_disconnect()
releases it after the rebinding.

The system resume path is meant to stay as it is: the callback queues
the reset only while the device's runtime PM status is RPM_RESUMING.
The PM core sets that status in rpm_resume() before it calls the
runtime_resume callback, and during a system sleep runtime PM is
disabled from device_suspend() on; the USB core sets the status to
active only after usb_resume_both() has returned. That path was not
tested, as the emulated device cannot take part in a system sleep.
---
 drivers/bluetooth/btusb_main.c | 49 ++++++++++++++++++++++++++++++++++
 1 file changed, 49 insertions(+)

diff --git a/drivers/bluetooth/btusb_main.c b/drivers/bluetooth/btusb_main.c
index 879461fb606f4..15c705584ec4a 100644
--- a/drivers/bluetooth/btusb_main.c
+++ b/drivers/bluetooth/btusb_main.c
@@ -5132,6 +5132,54 @@ static int btusb_resume(struct usb_interface *intf)
 	return err;
 }
 
+/* True while the USB core runs a runtime resume of the device. A system resume
+ * cannot be told from the callback's arguments, but the PM core sets the
+ * status to RPM_RESUMING only in rpm_resume(), before the runtime_resume
+ * callback, and the USB core sets it to active only after a system resume.
+ */
+static bool btusb_runtime_resuming(struct usb_device *udev)
+{
+#ifdef CONFIG_PM
+	return udev->dev.power.runtime_status == RPM_RESUMING;
+#else
+	return false;
+#endif
+}
+
+static int btusb_reset_resume(struct usb_interface *intf)
+{
+	struct btusb_data *data = usb_get_intfdata(intf);
+	int err;
+
+	BT_DBG("intf %p", intf);
+
+	err = btusb_resume(intf);
+
+	/* The USB core reset the device to resume it. Without this callback it
+	 * only marks the interfaces for rebinding, which it does after a
+	 * system resume but not after a runtime resume: then btusb stays bound
+	 * and is never resumed, with BTUSB_SUSPENDING set and every later URB
+	 * parked on the deferred anchor.
+	 *
+	 * After a runtime resume, queue a USB reset: btusb has no pre_reset
+	 * and post_reset callbacks, so the core unbinds and rebinds it, and
+	 * the controller, whose state the reset may have cleared, is set up
+	 * again. Keep a runtime PM reference until then, as btusb_reset() does:
+	 * the core drops a queued reset for a device that has suspended again.
+	 * btusb_disconnect() releases it.
+	 *
+	 * Do this even if btusb_resume() failed: usb_resume_both() ignores its
+	 * result, so this is the only recovery left.
+	 */
+	if (intf == data->intf && btusb_runtime_resuming(data->udev) &&
+	    !test_and_set_bit(BTUSB_RESET, &data->flags)) {
+		usb_autopm_get_interface_no_resume(intf);
+		usb_queue_reset_device(intf);
+	}
+
+	return err;
+}
+
 #ifdef CONFIG_DEV_COREDUMP
 static void btusb_coredump(struct device *dev)
 {
@@ -5149,6 +5197,7 @@ static struct usb_driver btusb_driver = {
 	.disconnect	= btusb_disconnect,
 	.suspend	= pm_ptr(btusb_suspend),
 	.resume		= pm_ptr(btusb_resume),
+	.reset_resume	= pm_ptr(btusb_reset_resume),
 	.id_table	= btusb_table,
 	.supports_autosuspend = 1,
 	.disable_hub_initiated_lpm = 1,
-- 
2.43.0

```

**`contributions/CO-43-btusb-runtime-resume-failure/send-series-20261114/0004-Bluetooth-btusb-Drop-deferred-URBs-under-txlock-on-a.patch`** (SHA-256 `b3d77d13f6a9621dd5ea334dec3dfe9d0f0faa90f1f6e9e5e87c2d3df9e07369`)

```diff
From b9e27960ea89b5f74c49ce1c713afdc8bfd9e94c Mon Sep 17 00:00:00 2001
From: Iaroslav Voitovych <yaroslav.voytovych@gmail.com>
Date: Sat, 14 Nov 2026 02:40:50 +0100
Subject: [PATCH 4/5] Bluetooth: btusb: Drop deferred URBs under txlock on a
 failed resume

When btusb_resume() cannot submit the interrupt or bulk URB, it
scuttles the deferred anchor without txlock and only then clears
BTUSB_SUSPENDING under it. A sender that takes txlock in between still
sees the flag, anchors its URB on data->deferred and schedules the
waker, which finds an active device and does nothing. The URB stays
parked until the next suspend and resume, and an HCI command in it
times out.

Do both under txlock, so that a sender either anchors its URB before
the scuttle, and the URB is dropped with the others, or sees the flag
cleared and submits it. btusb_resume() already takes the anchor's lock
inside txlock, so the lock order does not change.

The two failure branches now share the label that ends a resume with
HCI closed, and scuttle only when an error was returned.

Fixes: 7bee549e197c ("Bluetooth: Add USB autosuspend support to btusb driver")
---
 drivers/bluetooth/btusb_main.c | 12 ++++++++----
 1 file changed, 8 insertions(+), 4 deletions(-)

diff --git a/drivers/bluetooth/btusb_main.c b/drivers/bluetooth/btusb_main.c
index 15c705584ec4a..3ae266821cca9 100644
--- a/drivers/bluetooth/btusb_main.c
+++ b/drivers/bluetooth/btusb_main.c
@@ -5089,7 +5089,7 @@ static int btusb_resume(struct usb_interface *intf)
 		err = btusb_submit_intr_urb(hdev, GFP_NOIO);
 		if (err < 0) {
 			clear_bit(BTUSB_INTR_RUNNING, &data->flags);
-			goto failed;
+			goto done;
 		}
 	}
 
@@ -5097,7 +5097,7 @@ static int btusb_resume(struct usb_interface *intf)
 		err = btusb_submit_bulk_urb(hdev, GFP_NOIO);
 		if (err < 0) {
 			clear_bit(BTUSB_BULK_RUNNING, &data->flags);
-			goto failed;
+			goto done;
 		}
 
 		btusb_submit_bulk_urb(hdev, GFP_NOIO);
@@ -5121,10 +5121,14 @@ static int btusb_resume(struct usb_interface *intf)
 
 	return 0;
 
-failed:
-	usb_scuttle_anchored_urbs(&data->deferred);
 done:
 	spin_lock_irq(&data->txlock);
+	/* Drop the deferred URBs and clear BTUSB_SUSPENDING in one critical
+	 * section: a sender that anchored a URB after the scuttle but before
+	 * the flag was cleared would leave it parked until the next resume.
+	 */
+	if (err)
+		usb_scuttle_anchored_urbs(&data->deferred);
 	clear_bit(BTUSB_CMD_DEFERRED, &data->flags);
 	clear_bit(BTUSB_SUSPENDING, &data->flags);
 	spin_unlock_irq(&data->txlock);
-- 
2.43.0

```

**`contributions/CO-43-btusb-runtime-resume-failure/send-series-20261114/0005-Bluetooth-btusb-Free-the-skb-of-a-deferred-URB-that-.patch`** (SHA-256 `9e5bd839faab1d8cdf19ffaa8000b1fa5b44aeb5d8c2f74c3690f2fa54eac943`)

```diff
From a2fda18e5f156d765b0e396f8e457916b97ee0ae Mon Sep 17 00:00:00 2001
From: Iaroslav Voitovych <yaroslav.voytovych@gmail.com>
Date: Sat, 14 Nov 2026 02:41:13 +0100
Subject: [PATCH 5/5] Bluetooth: btusb: Free the skb of a deferred URB that is
 discarded

A URB parked on data->deferred owns the skb it carries (urb->context)
and, for an HCI command, its setup packet. Both are freed by
btusb_tx_complete(), which does not run for a URB that is discarded
instead of sent. The four places that discard one free neither, or
only the setup packet:

- btusb_close() and the failure path of btusb_resume() call
  usb_scuttle_anchored_urbs(), which only unanchors the URBs;
- play_deferred() frees the URB and the setup packet when a submission
  fails and for the URBs left after that, but not the skb.

With an emulated device that stopped answering, a command deferred
across a close or a failed resume left a skb and an 8-byte setup packet
reported by kmemleak each time.

Free the skb and the setup packet with the URB at all four places.
This runs under txlock with interrupts off in two of them, so use
dev_kfree_skb_any().

Fixes: 7bee549e197c ("Bluetooth: Add USB autosuspend support to btusb driver")
Fixes: 19cfe912c37b ("Bluetooth: btusb: Fix memory leak in play_deferred")
---
 drivers/bluetooth/btusb_main.c | 32 ++++++++++++++++++++++++--------
 1 file changed, 24 insertions(+), 8 deletions(-)

diff --git a/drivers/bluetooth/btusb_main.c b/drivers/bluetooth/btusb_main.c
index 3ae266821cca9..f8843ea96faf0 100644
--- a/drivers/bluetooth/btusb_main.c
+++ b/drivers/bluetooth/btusb_main.c
@@ -2125,6 +2125,26 @@ static void btusb_tx_complete(struct urb *urb)
 	kfree_skb(skb);
 }
 
+/* Free a deferred URB that will not be sent. btusb_tx_complete() would free
+ * the setup packet and the skb, but it does not run for such a URB. This can
+ * be called with txlock held and interrupts off.
+ */
+static void btusb_free_deferred_urb(struct urb *urb)
+{
+	kfree(urb->setup_packet);
+	dev_kfree_skb_any(urb->context);
+	usb_free_urb(urb);
+}
+
+/* Free all deferred URBs without sending them. */
+static void btusb_discard_deferred(struct btusb_data *data)
+{
+	struct urb *urb;
+
+	while ((urb = usb_get_from_anchor(&data->deferred)))
+		btusb_free_deferred_urb(urb);
+}
+
 static void btusb_isoc_tx_complete(struct urb *urb)
 {
 	struct sk_buff *skb = urb->context;
@@ -2260,7 +2280,7 @@ static int btusb_close(struct hci_dev *hdev)
 	usb_autopm_put_interface(data->intf);
 
 failed:
-	usb_scuttle_anchored_urbs(&data->deferred);
+	btusb_discard_deferred(data);
 	spin_lock_irq(&data->txlock);
 	clear_bit(BTUSB_CMD_DEFERRED, &data->flags);
 	spin_unlock_irq(&data->txlock);
@@ -5046,9 +5066,8 @@ static void play_deferred(struct btusb_data *data)
 			if (err != -EPERM && err != -ENODEV)
 				BT_ERR("%s urb %p submission failed (%d)",
 				       data->hdev->name, urb, -err);
-			kfree(urb->setup_packet);
 			usb_unanchor_urb(urb);
-			usb_free_urb(urb);
+			btusb_free_deferred_urb(urb);
 			break;
 		}
 
@@ -5057,10 +5076,7 @@ static void play_deferred(struct btusb_data *data)
 	}
 
 	/* Cleanup the rest deferred urbs. */
-	while ((urb = usb_get_from_anchor(&data->deferred))) {
-		kfree(urb->setup_packet);
-		usb_free_urb(urb);
-	}
+	btusb_discard_deferred(data);
 
 	clear_bit(BTUSB_CMD_DEFERRED, &data->flags);
 }
@@ -5128,7 +5144,7 @@ static int btusb_resume(struct usb_interface *intf)
 	 * the flag was cleared would leave it parked until the next resume.
 	 */
 	if (err)
-		usb_scuttle_anchored_urbs(&data->deferred);
+		btusb_discard_deferred(data);
 	clear_bit(BTUSB_CMD_DEFERRED, &data->flags);
 	clear_bit(BTUSB_SUSPENDING, &data->flags);
 	spin_unlock_irq(&data->txlock);
-- 
2.43.0

```

---

*End of document. Repository: <https://github.com/ivoitovych/qca9377-bt-hang>; every file above is at the path given, in the commit that added this document.*
