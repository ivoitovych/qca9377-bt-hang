# Five Linux Bluetooth kernel submissions — request for an independent review before sending (2026-11-22)

## What this is, and what we ask of you

This document holds five submissions to the Linux kernel's Bluetooth subsystem. **None has been
sent.** They are the five that our own readiness rating puts at the top: their defects are
reproduced, their packages are final, and they were tested and reviewed once already. We want
an independent opinion **before** they go to the linux-bluetooth list (four of them) and the
stable team (one of them). Everything you need is in this file. You do not need any repository,
and nothing here links to one. Every patch and mail is copied verbatim; the SHA-256 under each
copy identifies the exact file.

**Please answer per item:**
1. **Verdict:** send as is · send after the changes you list · hold (and why).
2. **Correctness:** is the code right? Look at locking, lifetimes, error paths and the cases
   the message does not mention.
3. **The message:** does it claim only what the evidence shows? Is anything missing that a
   maintainer would ask for? Is anything there they would see as noise?
4. **Tags and route:** `Fixes:`, `Cc: stable`, `Link:`, the subject, the recipients, and the
   order of the sends.
5. **Testing:** is what was run enough for this kind of change? What would you want added
   before posting?

Each item also ends with its own open questions. A short answer is welcome. "Send as is" with
no comment is a useful answer too.

## Facts common to all five

- **Author and sign-off.** The author is Iaroslav Voitovych, who sends the patches himself. As
  packaged they carry **no `Signed-off-by:`**. He adds his own at send time, directly after the
  last trailer. Please do not flag its absence. The BlueZ test patches carry none by BlueZ's
  rule.
- **Bases.** The patches were made on bluetooth-next `da3cc02587c6` (2026-11-12). The BlueZ
  patches were made on BlueZ master `20ffd285b58f`.
- **Re-checked today, 2026-11-22.** All four kernel patches apply cleanly to today's
  bluetooth-next tip `cf357cfc025e` (2026-11-20). That covers item 1 alone, items 1 and 5 stacked
  in that order, and items 2 and 3. Both BlueZ test patches apply to today's BlueZ master
  `1adfe662efef`, alone and together. Each check applied the files in order into a scratch index
  of the target tree, with a negative control: applying the same patch twice fails. The changed
  lines are still present on both tips, so nobody has fixed these defects upstream in the
  meantime.
  **Not re-run on the new tips:** the builds and the test runs. Those are from the bases above.
- **How they were tested.**
  - QEMU/KVM guests with KASAN and lockdep, on 4 vCPUs.
  - BlueZ's own tester programs (`mgmt-tester`, `l2cap-tester`, `smp-tester`, `mesh-tester`) on
    emulated controllers, built with BlueZ's `doc/tester.config`.
  - For the USB driver items: the real `btusb` driver bound to an **emulated QCA9377 (USB ID
    `13d3:3503`) attached over usbip**, with fault injection and debug-only delays that exist in
    the test kernels only, never in the patches.
  - The linux-bluetooth list's CI checks (checkpatch, gitlint, builds, VerifyFixes and the tester
    runs) were run locally on the base and on the base plus the patch. The only differences are
    the three checks that fail on the missing `Signed-off-by:`.
- **Real hardware.** The author's laptop has a QCA9377 (`13d3:3503`, Bluetooth 4.2) on Ubuntu
  24.04. Items 1, 2 and 5 come from a real incident on it (2026-11-12): the controller stopped
  answering after a runtime resume. **None of the five, in its current form, has run on that
  laptop.** The defects behind items 1 and 5 cannot be produced there on demand. Item 4 concerns
  devices the author does not have.
- **The earlier review round (2026-11-14).** Five outside reviewers read all of these. Two of
  them applied every patch to its base, and two read the source at the base. **None built or ran
  anything.** Their points and what was done with them are listed per item. Item 5 was extracted
  as its own series at their request, after that round, so you are its first outside readers in
  this form.
- **Send mechanics.** Items 1 and 2 have send commands and a `git send-email` dry run with
  checked recipients. Items 3, 4 and 5 have them still to make.

---
## 1. btusb: anchor a deferred URB under txlock

**Subject:** "Bluetooth: btusb: Anchor a deferred URB under txlock" · one patch ·
`drivers/bluetooth/btusb_main.c`, `submit_or_queue_tx_urb()` ·
`Fixes: 7bee549e197c` (2009, so every stable line has the window).

**The defect.** `submit_or_queue_tx_urb()` tests `BTUSB_SUSPENDING` under `data->txlock`, drops
the lock, and only then anchors the URB on `data->deferred`. `btusb_resume()` replays the deferred
anchor and clears the flag under `txlock`. A resume that completes in between leaves the URB
anchored on an awake device. The waker it schedules finds nothing to resume, so the URB waits for
the next suspend/resume cycle, and the HCI command in it times out.

**The fix.** Anchor in the same critical section as the flag test. `btusb_resume()` already takes
the anchor's lock inside `txlock`, so the lock order does not change.

**Where it came from.** It came from an analysis of the laptop incident, a resume the device
never answered, rebuilt in emulation. This window is a separate defect that the analysis found.
It is not the incident's cause.

**Tested** (bluetooth-next `da3cc02587c6`, emulated QCA9377 over usbip, KASAN and lockdep):
- **With the window widened** by a debug-only delay and a resume forced inside it: unpatched, a
  command was parked and timed out in 3 of 3 runs; patched, it was sent at that resume.
- **Stress without the delay:** 10 runs of 100 suspend/resume cycles on each kernel, with
  concurrent senders, power cycles and disconnects. There was no lockdep, KASAN or hung-task
  report on either kernel, and no parked packet. Unpatched it also parked nothing in about 950
  normal cycles, so the race is real but narrow.
- **Bot checks:** identical to the base apart from the `Signed-off-by:` checks.

**Not tested:** real hardware.

**Earlier review (11-14):** all five reviewers said send. The stable question split: two for,
two against, because the race was seen only with the window widened.

**Questions for you.**
- **`Cc: stable` or not.** Our reading is no; we would leave it to the maintainer.
- **The lock order and the teardown cases.** For example, a disconnect while URBs are deferred.
- **Recipients.** These are what `get_maintainer.pl` gives: To Marcel Holtmann, Luiz Augusto
  von Dentz and linux-bluetooth; Cc Oliver Neukum (the `Fixes:` author, at the address the
  script prints) and linux-kernel. Is anyone missing?

**File 1.1 — the patch, as it would be mailed** (`0001-Bluetooth-btusb-Anchor-a-deferred-URB-under-txlock.patch`, SHA-256 `f314eb6b5536c040e79a70f4724b335a748ecd5042c688e6ea7eb231bfe1052d`)

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

---
## 2. MGMT: a timed-out command reported as Authentication Failed

**Subject:** "Bluetooth: MGMT: Report a timed out command as MGMT_STATUS_TIMEOUT".
- **Kernel:** one patch, a one-line change, `net/bluetooth/mgmt.c` `mgmt_errno_status()`.
  `Fixes: 161510ccf91c` (v5.17-rc1).
- **BlueZ:** a test case, "mgmt-tester: Add Set Device Class timeout test".

**The defect.**
- **What happens.** `mgmt_errno_status()` maps `-ETIMEDOUT` to `MGMT_STATUS_AUTH_FAILED`. The
  sync command path returns `-ETIMEDOUT` when the controller does not answer. So Set Powered,
  Add or Remove UUID and Set Device Class report "Authentication Failed" although no
  authentication took place.
- **Where it was seen.** On the laptop, on 2026-11-12, bluetoothd logged "Failed to remove UUID:
  Authentication Failed (0x05)" three times while the controller was not answering. That
  pointed at pairing and keys, not at the controller.
- **The rest of the code already agrees with the fix.** `mgmt_status_table[]` maps HCI 0x08
  ("Connection Timeout") and 0x10 (labelled "Host Timeout" in that table's own comments) to
  `MGMT_STATUS_TIMEOUT`. A timed-out LE connection attempt already reports 0x08.

**The fix.** Map `-ETIMEDOUT` to `MGMT_STATUS_TIMEOUT`.

**Rejected:** also mapping `-EACCES`. `bt_to_errno()` maps both 0x05 and 0x18 to EACCES, so no
single status is right for it.

**Tested** (bluetooth-next `da3cc02587c6`, BlueZ master plus the new case, QEMU):
- **The new case** drops Write Class of Device and expects Timeout. On the base kernel it gets
  0x05 and fails. Patched, it passes.
- **mgmt-tester:** 526 of 527 pass on the base, 527 of 527 patched.
- **Other testers:** l2cap-tester 144/144 and smp-tester 8/8, unchanged.
- **The one other case that sees the new status** is "Get Conn Info - Power off". It is
  `fail_tolerant` and passes either way.
- **A negative control** shows the new case fails (times out) if its hook is not reached.
- **Bot checks:** only the `Signed-off-by:` checks differ. The BlueZ bot's checks pass on both
  sides.

**Not tested:** the patched kernel on the laptop. Its trigger, a controller that stops
answering, cannot be produced there on demand.

**Earlier review (11-14):** five of five said send. Two wording points were fixed in the
reviewers' brief, not in the patch: the function does have a `case -ETIMEDOUT`, and the BlueZ
mail's lore placeholder is explained below.

**Questions for you.**
- **`Cc: stable`?** The patch as packaged has none, and its note says why: the status is visible
  to user space. The variant with it differs in two edits only:
  - the line `Cc: stable@vger.kernel.org` directly under `Fixes:`;
  - the last paragraph below `---` ("Not marked for stable, …") deleted.

  In the earlier round three reviewers were for it and one against.
- **The `Link:`** to a 2022 BlueZ posting that names the same symptom. One reviewer said drop it;
  others called it optional or useful.
- **The subject.** One reviewer offered "Bluetooth: MGMT: Report command timeouts correctly".
- **The order.** The kernel mail goes first. The BlueZ test goes the same day, after the kernel
  mail's lore link is written into it: its literal `@KERNEL_PATCH_LINK@` line is a deliberate
  placeholder that the send steps replace.
- **Recipients.** Kernel: linux-bluetooth, Marcel Holtmann, Luiz Augusto von Dentz,
  linux-kernel. BlueZ: linux-bluetooth, Luiz Augusto von Dentz.

**File 2.1 — the kernel patch, as it would be mailed** (`0001-Bluetooth-MGMT-Report-a-timed-out-command-as-MGMT_ST.patch`, SHA-256 `8a265e321fc37c1a8b3f434764826ec0ca933968a59b0dd57aacaf51c7686fd9`)

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

**File 2.2 — the BlueZ test, as it would be mailed (second, the same day)** (`0001-mgmt-tester-Add-Set-Device-Class-timeout-test.patch`, SHA-256 `f50518d35c97bc73a1c88cf422a69e7fc84c87ae25b64ad6f5b2aa66cd6f5956`)

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

---
## 3. MGMT: Read Advertising Features hides instances

**Subject:** "Bluetooth: MGMT: Fix Read Advertising Features hiding instances".
- **Kernel:** one patch, a one-line change, `net/bluetooth/mgmt.c` `read_adv_features()`.
  `Fixes: b338d91703fa` (2022), so 6.1.y onward.
- **BlueZ:** a test, "mgmt-tester: Add test for listing a remaining instance". It holds the
  helpers plus one case.

**The defect.** `read_adv_features()` means to hide only the mesh instance, which is numbered one
past the controller's advertising sets. But it compares each instance number with
`hdev->adv_instance_cnt`, the number of instances, instead of `le_num_of_adv_sets`, the number of
sets, as its own comment says. Whenever the instance numbers are not exactly 1..n, an instance
is left out. Example: add instances 1 and 2, then remove 1 (its timeout). Instance 2 is still
advertising but is no longer listed, and there is no Advertising Removed event, because it was
never removed.

**Where it came from:** the tests of another fix of ours, not part of this document.

**The fix.** Compare with `le_num_of_adv_sets`.

**Tested** (bluetooth-next `da3cc02587c6`, QEMU, KASAN, lockdep, 4 CPUs, 3 runs each):
- **The new BlueZ case** "Add Ext Advertising - Instance 2 listed alone": `mgmt-tester -p Add`
  113/114 on the base (the new case fails) and 114/114 with the patch.
- **The full "Add" group:** 119/128 → 120/128, and the only case that changes is the new one.
  The other 8 not-passed cases are the duration cases of a separate fix that is not posted. They
  fail on both kernels and are held back with that fix.
- **mesh-tester:** 8/10 on both kernels (the two known "Send cancel" failures).
- **Bot checks:** pass on both sides with identical tester results. On the BlueZ side the bot's
  functional test flakes in one BAP case on a loaded host: patched failed 2 of 8 runs, base
  1 of 7, the same case.

**Not tested:** real hardware.

**Earlier review (11-14):** five of five said send the kernel patch. Four of five asked to split
the BlueZ tests, so the duration cases are held. Two reviewers favoured `Cc: stable` for this
deterministic one-liner, and an earlier round recommended it too.

**Questions for you.**
- **`Cc: stable`?** The patch has none.
- **The BlueZ test's size** (about 390 lines, mostly helpers for advertising parameters).
  Should we strip the helper paths that this one case does not use?
- **Should the kernel patch name the test?**

**File 3.1 — the kernel patch, as it would be mailed** (`0001-Bluetooth-MGMT-Fix-Read-Advertising-Features-hiding-.patch`, SHA-256 `abe944ee82213c5954bbd3314d0c2578e78e7823585b374471a69bc15f154aa4`)

```diff
From 1fb5fb3351f9a4a9c2417452156eaf6140c4ef8d Mon Sep 17 00:00:00 2001
From: Iaroslav Voitovych <yaroslav.voytovych@gmail.com>
Date: Sat, 14 Nov 2026 01:47:30 +0100
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
---
 net/bluetooth/mgmt.c | 2 +-
 1 file changed, 1 insertion(+), 1 deletion(-)

diff --git a/net/bluetooth/mgmt.c b/net/bluetooth/mgmt.c
index 6ed3bf6f17385..5c92618a0867f 100644
--- a/net/bluetooth/mgmt.c
+++ b/net/bluetooth/mgmt.c
@@ -8889,7 +8889,7 @@ static int read_adv_features(struct sock *sk, struct hci_dev *hdev,
 	instance = rp->instance;
 	list_for_each_entry(adv_instance, &hdev->adv_instances, list) {
 		/* Only instances 1-le_num_of_adv_sets are externally visible */
-		if (adv_instance->instance <= hdev->adv_instance_cnt) {
+		if (adv_instance->instance <= hdev->le_num_of_adv_sets) {
 			*instance = adv_instance->instance;
 			instance++;
 		} else {

base-commit: da3cc02587c629420603df4395179ec82955c941
-- 
2.43.0

```

**File 3.2 — the BlueZ test, as it would be mailed** (`0001-mgmt-tester-Add-test-for-listing-a-remaining-instanc.patch`, SHA-256 `ae6579d59e061751ff387585ff4d67be162df0d7a3c1eba22072f1e53161c26c`)

```diff
From 4d7b0bd704530c68fc0bd815415070b4ae525b52 Mon Sep 17 00:00:00 2001
From: Iaroslav Voitovych <yaroslav.voytovych@gmail.com>
Date: Sat, 14 Nov 2026 14:04:21 +0100
Subject: [PATCH BlueZ] mgmt-tester: Add test for listing a remaining instance
 2

Add instances 1 and 2 on an extended advertising controller, let
instance 1 expire after 1 s, and check that Read Advertising Features
still lists instance 2. The test fails on kernels that compare the
instance number with the number of instances instead of the number of
advertising sets in read_adv_features(), and passes with
"Bluetooth: MGMT: Fix Read Advertising Features hiding instances".

The test is driven by the HCI LE Set Extended Advertising Enable
Duration seen by the emulator and by the Advertising Removed event; the
helpers that do that are added with it.
---
 tools/mgmt-tester.c | 388 ++++++++++++++++++++++++++++++++++++++++++++
 1 file changed, 388 insertions(+)

diff --git a/tools/mgmt-tester.c b/tools/mgmt-tester.c
index b7126dc36..a52f1188e 100644
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
@@ -14441,6 +14488,343 @@ static const struct generic_data eks_oppt_connect_encrypt_test = {
 	.expect_hci_param_check_func = check_encrypt_v2_opportunistic,
 };
 
+/* An extended advertising controller is given the instance timeout as the
+ * Duration of LE Set Extended Advertising Enable (N * 10 ms) and ends the
+ * set itself, after which the kernel removes the instance. Removal is
+ * expected Duration * 10 ms after the enable.
+ */
+#define ADV_TIMEOUT_EARLY_MS	50
+#define ADV_TIMEOUT_LATE_MS	1000
+
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
@@ -15808,6 +16192,10 @@ int main(int argc, char *argv[])
 					setup_add_advertising_timeout,
 					test_command_generic, 3);
 
+	test_bredrle50_full("Add Ext Advertising - Instance 2 listed alone",
+					&add_ext_adv_timeout_list_2, NULL,
+					test_add_adv_timeout, 5);
+
 	/* LE off will clear (remove) all instances. */
 	test_bredrle50("Add Ext Advertising - Success 22 (LE -> off, Remove)",
 					&add_ext_advertising_le_off,

base-commit: 20ffd285b58facfd1f2478d159a5f941b09d5be1
-- 
2.43.0

```

---
## 4. Stable request: two ASUS QCA ROME device IDs

**What it is.** A request to the stable team, not a patch of ours: "Please backport d54601f21faf
and cfa67a1dbfd9 (btusb: ASUS QCA Rome IDs) to stable", for 7.3.y down to 5.10.y.
- The commits are other authors' (Quentin Strydom and Konstantin Nazarov; both are Cc'd).
- They add `0b05:1868` and `0b05:1825` as `BTUSB_QCA_ROME | BTUSB_WIDEBAND_SPEECH`.
- Both are in mainline since v7.4-rc1, with no `Cc: stable` tag.

**Why.** It is the same failure class as the author's own controller, whose entry `dc16388d45ec`
was queued for 7.2.y down to 5.10.y in October after a similar request.
- **Without an entry**, such a controller matches only the generic Bluetooth class entry.
  `btusb_setup_qca()` never runs, and it stays on its ROM firmware.
- **On that firmware**, both commit messages report LE scanning failing with "unexpected event
  for opcode 0x2005". On the author's own controller, the ROM firmware hung the HCI channel after
  wideband (mSBC) SCO links, in 12 of 12 recorded cases.

**Verified today (2026-11-22).**
- **Queue.** Neither commit is in the stable queue of any of the seven lines (12:47 UTC). Neither
  is on the 6.18.y branch.
- **Apply.** On each line's current tip (7.3.5, 6.18.64, 6.12.118, 6.6.162, 6.1.192, 5.15.225,
  5.10.274), the two commits apply cleanly **in the order the mail gives**. Applied alone,
  `cfa67a1dbfd9` conflicts, because its context is the line `d54601f21faf` adds. In mainline both
  touch `drivers/bluetooth/btusb_main.c` (the driver was split in 7.4), and on the stable lines
  that is `drivers/bluetooth/btusb.c`. git's rename detection follows that on a cherry-pick;
  today's check renamed the path the same way.
- **Build (11-14).** On the then-current tips, `btusb.o` built with both commits with no new
  warning (W=1). 6.6.y's W=1 build stops on four `btmtk.h` errors on the plain tag too.

**Not tested:** any device. The author does not have these.

**To change before sending.** The mail still says "checked 2026-11-14 between 13:08 and
13:42 UTC" and names the tips of that day (7.3.4, 6.18.63, 6.12.117). Those become today's check
and tips (or the send day's). The text is otherwise as below.

**Earlier review (11-14):** all said send, after a fresh queue check, which is done again today.
One reviewer found the date claim overstated, and it was fixed. Two said not to add `0cf3:e303`,
which has its own posted patch (by Daan Bouwman, patchwork 14976888). It is not added.

**Questions for you.**
- **Is one mail for both commits right?** It says "in this order".
- **Is the background paragraph** (the earlier entry and the 0x2005 symptom) useful to the
  stable team, or noise?
- **The Cc list.** The two commit authors, the Bluetooth maintainers, linux-bluetooth.

**File 4.1 — the request mail (v3, before the date refresh)** (`stable-request-asus-rome-v3.eml`, SHA-256 `601891d8661004192dd3947eb64ff8232dc85e7877f040c843fd500ad393654b`)

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
stable release, in the stable queue or in a stable-rc branch of any of
the seven lines (checked 2026-11-14 between 13:08 and 13:42 UTC). On
each tree's current tip (7.3.4, 6.18.63, 6.12.117, 6.6.162, 6.1.192,
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

---
## 5. btusb: deferred URBs that a failed resume or a close discards (a two-patch series on item 1)

**Subjects:** "[PATCH 0/2] Bluetooth: btusb: Deferred URBs that a failed resume or a close
discards".
- **1/2** "Bluetooth: btusb: Drop deferred URBs under txlock on a failed resume".
  `Fixes: 7bee549e197c`.
- **2/2** "Bluetooth: btusb: Free the skb of a deferred URB that is discarded".
  `Fixes: 7bee549e197c` and `19cfe912c37b`.
- **Where:** `drivers/bluetooth/btusb_main.c`: the failure path of `btusb_resume()`,
  `btusb_close()` and `play_deferred()`.
- **It applies on top of item 1.** Patch 1 relies on item 1's anchoring under `txlock`. Checked
  today on bluetooth-next `cf357cfc025e` + item 1.

**The defects.**
1. **The failed-resume path.** `btusb_resume()` scuttles the deferred anchor without `txlock`,
   and only then clears `BTUSB_SUSPENDING` under it. A second sender that comes in between
   anchors its URB after the scuttle, on a device no longer marked suspending, and nothing sends
   it.
2. **The discard sites.** Four places discard a deferred URB: `btusb_close()`, the failure path
   of `btusb_resume()`, and two in `play_deferred()`. They free neither the skb it carries nor,
   in two of them, its setup packet.

**The fixes.**
- The scuttle and the clearing of the flag go in one `txlock` section.
- Every discard frees the skb and the setup packet.
- `btusb_close()` takes no new lock. The HCI core clears `HCI_RUNNING` and flushes its tx and
  command works before it calls the driver's close, so no sender can anchor while it drains.
  The message of patch 2 argues this.

**Tested** (emulated QCA9377 over usbip, QEMU, KASAN, lockdep, kmemleak, 4 CPUs; item 1 alone
against item 1 + this series; fault injection in the test kernel only):
- **kmemleak objects per run, three runs each, before → after:**

  | case | before | after |
  |---|---|---|
  | failed resume with a deferred command | 3, 3, 1 | 0, 0, 0 |
  | `play_deferred()` submission fails | 2, 1, 2 | 0, 0, 0 |
  | dead device, then close | 5, 3, 4 | 0, 0, 0 |
  | dead device, hci0 powered off | 2, 2, 2 | 0, 0, 0 |
  | healthy cycle | 0 | 0 |

- **The second-sender window** (a sleep in the failure path, plus a second command from a work
  item): the anchor is left non-empty in 3 of 3 runs before, and empty in 3 of 3 after.
- **Every other emulated case** gives the same result with and without the series: a dead
  device, a device that answers after a reset-resume, a dropped event with and without a wedged
  controller, and 30 healthy cycles.
- **No kernel report** in any run.

**Not covered by a reproduction:**
- the cleanup loop at the end of `play_deferred()`, which needs two deferred URBs at once, and
  the command credit allows only one;
- real hardware.

**Earlier review (11-14).** In that round these two fixes sat inside a larger five-patch series,
with two more patches that are held. Four of five reviewers asked for exactly this extraction:
rebase on item 1, drop the other patches' dependency, and send it alone. One asked to check
`btusb_close()`'s draining, which is argued in patch 2. One supported both `Fixes:` origins.
**This extracted form has not been reviewed.**

**Questions for you.**
- **Is the `btusb_close()` argument sound?**
- **Is the series too small or too large?** For example, should the leak fix go first?
- **`Cc: stable`?** Neither patch has it.
- **Should it wait** until item 1 is applied, or be sent the same day, with the cover saying it
  depends on item 1?

**File 5.1 — the cover letter** (`0000-cover-letter.patch`, SHA-256 `27c4f78030cf7ab97f68b10f137bf19d9e1b0d7e752741c5b606164b0d0871f0`)

```diff
From 684e5c0b69398708f25a1daf51d2276e4f6c99e7 Mon Sep 17 00:00:00 2001
From: Iaroslav Voitovych <yaroslav.voytovych@gmail.com>
Date: Sat, 14 Nov 2026 15:19:32 +0100
Subject: [PATCH 0/2] Bluetooth: btusb: Deferred URBs that a failed resume or a close discards

This series applies on top of "Bluetooth: btusb: Anchor a deferred URB
under txlock" (bluetooth-next da3cc02587c6 plus that patch). Patch 1
relies on submit_or_queue_tx_urb() anchoring under txlock, which that
patch adds. Nothing else is needed.

A URB that btusb defers while the device is suspended can be left
behind in two ways, both on paths that discard the deferred anchor:

 1: btusb_resume() scuttles the anchor on failure without txlock, and
    only then clears BTUSB_SUSPENDING under it. A second sender that
    comes in between anchors its URB after the scuttle, on a device
    that is no longer suspended, and nothing sends it. The scuttle
    and the clearing of the flag now happen in one txlock section.
 2: the four places that discard a deferred URB (btusb_close(), the
    failure path of btusb_resume() and two in play_deferred()) free
    neither the skb it carries nor, in two of them, its setup packet.

btusb_close() needs no more than patch 2: the HCI core clears
HCI_RUNNING and has flushed its tx and command works before it calls
the driver's close, so no sender can anchor a URB while it drains the
anchor (see the message of patch 2).

Tested with an emulated controller attached over usbip to a QEMU guest
(KASAN, lockdep, kmemleak, four CPUs), against the tree with only the
first patch ("E") and with this series on top of it. Fault injection
in the test kernel only, never in the patches: the interrupt URB
submission at resume fails; play_deferred()'s submission fails; and,
for patch 1, a sleep before the locked section of the failure path
with a second HCI command sent from a work item in the middle of it.

  kmemleak objects after two scans, per run, three runs each:
    failed resume with a command deferred:   3, 3, 1   then 0, 0, 0
    play_deferred() submission fails:        2, 1, 2   then 0, 0, 0
    dead device, then close:                 5, 3, 4   then 0, 0, 0
    dead device, hci0 powered off:           2, 2, 2   then 0, 0, 0
    healthy suspend and resume:              0         then 0
  deferred anchor after the failed resume with a second sender in
  the window: not empty in 3 of 3 runs, then empty in 3 of 3.

Runs of the other emulated cases (dead device, a device that answers
after the reset-resume, a command whose event is dropped with and
without a wedged controller, 30 healthy suspend and resume cycles; two
runs each) give the same result with and without the series; so does
the case of hci0 powered off during a resume, which fails on both
(not addressed here). No kernel report in any run.

Not covered by a reproduction: the cleanup loop at the end of
play_deferred(), which needs two deferred URBs (the command credit
allows one command at a time); it has the same change as the other
three sites.

Iaroslav Voitovych (2):
  Bluetooth: btusb: Drop deferred URBs under txlock on a failed resume
  Bluetooth: btusb: Free the skb of a deferred URB that is discarded

 drivers/bluetooth/btusb_main.c | 42 +++++++++++++++++++++++++---------
 1 file changed, 31 insertions(+), 11 deletions(-)


base-commit: 04b58d680611f226c868176f4419edd3bd73b03e
--
2.43.0

```

**File 5.2 — patch 1/2** (`0001-Bluetooth-btusb-Drop-deferred-URBs-under-txlock-on-a.patch`, SHA-256 `c80bfc0057e4d9d5e8b02a8761d2de7baf5368b5812cd7e1fe6c2981950f1378`)

```diff
From b797ce05a6acb1156a67733c3a7988b7beb9fd1a Mon Sep 17 00:00:00 2001
From: Iaroslav Voitovych <yaroslav.voytovych@gmail.com>
Date: Sat, 14 Nov 2026 02:40:50 +0100
Subject: [PATCH 1/2] Bluetooth: btusb: Drop deferred URBs under txlock on a
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
index 5f6d90d43d977..263277bf1d234 100644
--- a/drivers/bluetooth/btusb_main.c
+++ b/drivers/bluetooth/btusb_main.c
@@ -5045,7 +5045,7 @@ static int btusb_resume(struct usb_interface *intf)
 		err = btusb_submit_intr_urb(hdev, GFP_NOIO);
 		if (err < 0) {
 			clear_bit(BTUSB_INTR_RUNNING, &data->flags);
-			goto failed;
+			goto done;
 		}
 	}
 
@@ -5053,7 +5053,7 @@ static int btusb_resume(struct usb_interface *intf)
 		err = btusb_submit_bulk_urb(hdev, GFP_NOIO);
 		if (err < 0) {
 			clear_bit(BTUSB_BULK_RUNNING, &data->flags);
-			goto failed;
+			goto done;
 		}
 
 		btusb_submit_bulk_urb(hdev, GFP_NOIO);
@@ -5077,10 +5077,14 @@ static int btusb_resume(struct usb_interface *intf)
 
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
 	clear_bit(BTUSB_SUSPENDING, &data->flags);
 	spin_unlock_irq(&data->txlock);
 
-- 
2.43.0

```

**File 5.3 — patch 2/2** (`0002-Bluetooth-btusb-Free-the-skb-of-a-deferred-URB-that-.patch`, SHA-256 `3dd27572aa9e65cfc1510a828844891c1c4b36e4120b86c0bf32837e8c6e3afa`)

```diff
From 684e5c0b69398708f25a1daf51d2276e4f6c99e7 Mon Sep 17 00:00:00 2001
From: Iaroslav Voitovych <yaroslav.voytovych@gmail.com>
Date: Sat, 14 Nov 2026 02:41:13 +0100
Subject: [PATCH 2/2] Bluetooth: btusb: Free the skb of a deferred URB that is
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

btusb_close() needs no locking beyond that: the HCI core clears
HCI_RUNNING and has flushed the tx and command works before it calls
the driver's close, so hci_send_frame() refuses new frames and nothing
can anchor a URB on data->deferred while it drains the anchor. A
resume running at the same time takes URBs from the anchor with
usb_get_from_anchor() like the drain does, so each URB is freed once.

Fixes: 7bee549e197c ("Bluetooth: Add USB autosuspend support to btusb driver")
Fixes: 19cfe912c37b ("Bluetooth: btusb: Fix memory leak in play_deferred")
---
 drivers/bluetooth/btusb_main.c | 32 ++++++++++++++++++++++++--------
 1 file changed, 24 insertions(+), 8 deletions(-)

diff --git a/drivers/bluetooth/btusb_main.c b/drivers/bluetooth/btusb_main.c
index 263277bf1d234..e80b7442dee9d 100644
--- a/drivers/bluetooth/btusb_main.c
+++ b/drivers/bluetooth/btusb_main.c
@@ -2100,6 +2100,26 @@ static void btusb_tx_complete(struct urb *urb)
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
@@ -2235,7 +2255,7 @@ static int btusb_close(struct hci_dev *hdev)
 	usb_autopm_put_interface(data->intf);
 
 failed:
-	usb_scuttle_anchored_urbs(&data->deferred);
+	btusb_discard_deferred(data);
 	return 0;
 }
 
@@ -5004,9 +5024,8 @@ static void play_deferred(struct btusb_data *data)
 			if (err != -EPERM && err != -ENODEV)
 				BT_ERR("%s urb %p submission failed (%d)",
 				       data->hdev->name, urb, -err);
-			kfree(urb->setup_packet);
 			usb_unanchor_urb(urb);
-			usb_free_urb(urb);
+			btusb_free_deferred_urb(urb);
 			break;
 		}
 
@@ -5015,10 +5034,7 @@ static void play_deferred(struct btusb_data *data)
 	}
 
 	/* Cleanup the rest deferred urbs. */
-	while ((urb = usb_get_from_anchor(&data->deferred))) {
-		kfree(urb->setup_packet);
-		usb_free_urb(urb);
-	}
+	btusb_discard_deferred(data);
 }
 
 static int btusb_resume(struct usb_interface *intf)
@@ -5084,7 +5100,7 @@ static int btusb_resume(struct usb_interface *intf)
 	 * the flag was cleared would leave it parked until the next resume.
 	 */
 	if (err)
-		usb_scuttle_anchored_urbs(&data->deferred);
+		btusb_discard_deferred(data);
 	clear_bit(BTUSB_SUSPENDING, &data->flags);
 	spin_unlock_irq(&data->txlock);
 
-- 
2.43.0

```

---

## After your answers

Nothing is sent before the author has read every answer. Each point is checked against the source
and the test logs and recorded with what was done about it. Then, on the send day:
- the author adds his `Signed-off-by:`;
- the trees are re-fetched, and apply and build re-run;
- a `git send-email` dry run is checked;
- the author sends each mail himself.

Thank you for your time.
