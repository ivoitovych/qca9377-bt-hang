# A Linux Bluetooth MGMT fix and its BlueZ test: one recheck after the hardware run and the full suites (2026-11-26)

## What we ask

This holds the **final** kernel patch, signed, and its BlueZ test, exactly as they would be sent. Neither has been
sent. Since the last recheck request (2026-11-26 01:00 UTC), only the kernel patch's notes below `---` changed: the
fix has now run on the real hardware, and the remaining test gaps were closed. The commit message above `---`, both
diffs and the BlueZ patch are unchanged (same patch-ids). Section 2 lists every change.

Everything needed is in this file, with no repository links. Both patches are copied byte for byte from the files
that would be sent, from their `Date:` line on.

**Please check:**
1. **The changed notes (section 2):** true, and clear for a maintainer?
2. **The recipients (section 6):** linux-kernel is no longer copied. Do you agree, given the facts there?
3. **Anything still false, claimed beyond the evidence, or something a maintainer would reject,** in either patch.

Mark preferences as such. Please say what you checked yourself and what you took from this document.

## 1. Facts as stated by the author

- **Sign-off:** the kernel patch carries the author's own `Signed-off-by:` (Iaroslav Voitovych). The BlueZ patch
  carries none, by BlueZ's rule.
- **Today's tips** (2026-11-26): bluetooth-next `f57f78086ab5`; mainline v7.4-rc4; stable 7.3.6, 6.18.65, 6.12.119,
  6.6.163, 6.1.193 (none moved since 2026-11-23); BlueZ master `79162c108911`. `net/bluetooth/mgmt.c` is unchanged in
  bluetooth-next since `5063a0717aa2`, and `tools/mgmt-tester.c` in BlueZ since `1608f8361886`.
- **Patch-ids** (`git patch-id --stable`), unchanged since 2026-11-24:
  - kernel: `a15c80fa459bcaf1a3fa84e9aa447ae1372f8444`;
  - BlueZ: `70a4873086000186e05d1bbe88d65a75bc3b9e18`.
- **checkpatch** `--strict`, with the sign-off check on: "0 errors, 0 warnings, 0 checks".
- **The linux-bluetooth CI's own checks, run locally on these exact files** (the bot's code and Docker image):
  - kernel patch on bluetooth-next `f57f78086ab5`: CheckPatch, VerifyFixes, VerifySignedoff, GitLint,
    SubjectPrefix, BuildKernel, CheckAllWarning, CheckSparse, BuildKernel32, CheckKernelLLVM, TestRunnerSetup,
    TestRunner_mgmt-tester, TestRunner_mesh-tester, IncrementalBuild: all PASS. Base side (the tree checks and
    both testers on the unpatched tip): all PASS. The CI's testers come from BlueZ master, which does not yet
    have the new case, so there they show only that nothing else breaks.
  - BlueZ test on master `79162c108911`, both sides: CheckPatch, GitLint, BuildEll, BluezMake, CheckSmatch,
    bluezmakeextell, TestFunctional, IncrementalBuild, ScanBuild: all PASS (base side: the same tree checks,
    all PASS).
- **Origin:** the bug comes from `b338d91703fa` (v6.1 cycle). It is in stable 7.3, 6.18, 6.12, 6.6 and 6.1, and not
  in 5.15 or 5.10.

## 2. What changed since the 01:00 UTC request, and why

Kernel notes below `---` only:
- **The trees of the new case:** bluetooth-next `f57f78086ab5` was added beside `5063a0717aa2`. The new tip has
  Bluetooth changes in `hci_sync.c`, `hci_event.c`, `hci_conn.c` and rfcomm, none in `mgmt.c`, so both images were
  built and run again.
- **The other testers:** "In ten of the … testers … which it runs for this file, no other case that ran changed" →
  "In all eleven of the Bluetooth kernel CI's testers, including mgmt-tester and mesh-tester, which that CI runs for
  this file, no other case changed its result on any of these kernels."
  - eleven: 6lowpan-tester, missing before, ran on every image (9 of 9 cases pass, with and without the patch);
  - "which that CI runs": one reviewer's preference from the last round;
  - "no other case" without "that ran": see the next point.
- **The hangs:** "…so the cases after those hangs did not run" → "the cases after those hangs, run one at a time,
  give the same results with and without it". The 20 l2cap-tester cases after the hang (on 6.18, 6.12 and 6.6) and
  the 8 iso-tester cases (on 6.12) were run one per guest, on both images; every verdict is identical both ways.
  Some of them fail on the older stable lines, identically with and without the patch: the PHY and HDT cases,
  "Ethtool Get Ts Info", and two iso "Sync Lost" cases on 6.12 (one times out). The author's reading is that those
  kernels lack the features under test; this was not checked further.
- **Hardware:** "The patched kernel has not yet run on that hardware." → "On the same hardware, with this patch on
  Ubuntu's 7.0.0-44 kernel (whose mgmt.c is unchanged from 7.0.0-43), it lists instance 2." Section 5 has the
  details.

## 3. The kernel patch, final

```text
Date: Sat, 14 Nov 2026 01:47:30 +0100
Subject: [PATCH] Bluetooth: MGMT: Fix Read Advertising Features hiding
 instances

read_adv_features() is meant to report instances 1 to
le_num_of_adv_sets and to leave out the mesh instance, which is
numbered one past the controller's advertising sets. Instead it
compares each instance number with the number of instances, so an
instance numbered above the current number of instances is left out:
with instances 1 and 2 added and instance 1 removed, for example after
its timeout, instance 2 remains active but is no longer reported.

Compare with le_num_of_adv_sets, as the comment says.

This was found with mgmt-tester while writing tests for advertising
instances, and reproduced in QEMU with a new mgmt-tester case that adds
only instance 2: without this patch the reply lists no instance.

Fixes: b338d91703fa ("Bluetooth: Implement support for Mesh")
Cc: stable@vger.kernel.org
Signed-off-by: Iaroslav Voitovych <yaroslav.voytovych@gmail.com>
---
Tested in QEMU with a new mgmt-tester case, "Read Advertising
Features - Success 3 (Instance 2 only)", which is being submitted to
BlueZ separately. The case adds only instance 2 and expects exactly
that instance in the reply. It fails in 3 of 3 runs without this
patch and passes in 3 of 3 with it, on bluetooth-next f57f78086ab5
and 5063a0717aa2, v7.4-rc4, 7.3.6, 6.18.65, 6.12.119, 6.6.163 and
6.1.193.

In all eleven of the Bluetooth kernel CI's testers, including
mgmt-tester and mesh-tester, which that CI runs for this file, no
other case changed its result on any of these kernels. l2cap-tester
hangs on 6.18, 6.12 and 6.6, and iso-tester on 6.12, the same way with
and without this patch; the cases after those hangs, run one at a
time, give the same results with and without it. The same KASAN and
lockdep reports appear with and without it on 6.1.193, and the same
lockdep report on 6.12.119.

The bug also shows on real hardware: on a QCA9377 (USB 13d3:3503)
with Ubuntu's 7.0.0-43 kernel, Add Advertising for instance 2 alone
succeeds and the controller accepts LE Set Advertising Enable for it,
yet Read Advertising Features lists no instance. On the same hardware,
with this patch on Ubuntu's 7.0.0-44 kernel (whose mgmt.c is
unchanged from 7.0.0-43), it lists instance 2.

 net/bluetooth/mgmt.c | 2 +-
 1 file changed, 1 insertion(+), 1 deletion(-)

diff --git a/net/bluetooth/mgmt.c b/net/bluetooth/mgmt.c
index d21538634bc3..01969ab57339 100644
--- a/net/bluetooth/mgmt.c
+++ b/net/bluetooth/mgmt.c
@@ -9074,7 +9074,7 @@ static int read_adv_features(struct sock *sk, struct hci_dev *hdev,
 	instance = rp->instance;
 	list_for_each_entry(adv_instance, &hdev->adv_instances, list) {
 		/* Only instances 1-le_num_of_adv_sets are externally visible */
-		if (adv_instance->instance <= hdev->adv_instance_cnt) {
+		if (adv_instance->instance <= hdev->le_num_of_adv_sets) {
 			*instance = adv_instance->instance;
 			instance++;
 		} else {

base-commit: 5063a0717aa238f5242bf6b4abb8ddc1741ce682
-- 
2.43.0

```

## 4. The BlueZ test, final (unchanged)

`<LORE-LINK-OF-THE-KERNEL-PATCH>` is replaced with the real link before this is sent.

```text
Date: Mon, 23 Nov 2026 05:33:25 +0100
Subject: [PATCH BlueZ] mgmt-tester: Test a lone advertising instance 2

Read Advertising Features lists the advertising instances that user
space can see. Add a test that adds only instance 2 and expects the
reply to list exactly that instance.

On kernels from 6.1 on without the kernel change "Bluetooth: MGMT:
Fix Read Advertising Features hiding instances", the instance is left
out, because the kernel compares each instance number with the number
of instances instead of the number of advertising sets.
---
Kernel fix: <LORE-LINK-OF-THE-KERNEL-PATCH>

This case fails on kernels that have the bug (6.1 and later) until
that fix is in. Please apply it once the fix is in the kernel the
Bluetooth CI runs.

 tools/mgmt-tester.c | 36 +++++++++++++++++++++++++++++++++---
 1 file changed, 33 insertions(+), 3 deletions(-)

diff --git a/tools/mgmt-tester.c b/tools/mgmt-tester.c
index 18dbd3f89..212980da4 100644
--- a/tools/mgmt-tester.c
+++ b/tools/mgmt-tester.c
@@ -5183,6 +5183,22 @@ static const struct generic_data read_adv_features_success_2 = {
 	.expect_status = MGMT_STATUS_SUCCESS,
 };
 
+static const uint8_t read_adv_features_rsp_instance_2[] =  {
+	0x7f, 0xf0, 0x01, 0x00,	/* supported flags */
+	0x1f,			/* max_adv_data_len */
+	0x1f,			/* max_scan_rsp_len */
+	0x05,			/* max_instances */
+	0x01,			/* num_instances */
+	0x02,			/* instance identifiers */
+};
+
+static const struct generic_data read_adv_features_instance_2 = {
+	.send_opcode = MGMT_OP_READ_ADV_FEATURES,
+	.expect_param = read_adv_features_rsp_instance_2,
+	.expect_len = sizeof(read_adv_features_rsp_instance_2),
+	.expect_status = MGMT_STATUS_SUCCESS,
+};
+
 /* simple add advertising command */
 static const uint8_t add_advertising_param_uuid[] = {
 	0x01,			/* adv instance */
@@ -7197,17 +7213,17 @@ static void setup_add_advertising_not_powered(const void *test_data)
 						NULL, NULL);
 }
 
-static void setup_add_advertising(const void *test_data)
+static void add_advertising_instance(uint8_t instance)
 {
 	struct test_data *data = tester_get_data();
 	struct mgmt_cp_add_advertising *cp;
 	unsigned char adv_param[sizeof(*cp) + TESTER_ADD_ADV_DATA_LEN];
 	unsigned char param[] = { 0x01 };
 
-	tester_print("Adding advertising instance while powered");
+	tester_print("Adding advertising instance %u while powered", instance);
 
 	cp = (struct mgmt_cp_add_advertising *) adv_param;
-	setup_add_adv_param(cp, 1);
+	setup_add_adv_param(cp, instance);
 
 	mgmt_send(data->mgmt, MGMT_OP_SET_LE, data->mgmt_index,
 						sizeof(param), &param,
@@ -7223,6 +7239,16 @@ static void setup_add_advertising(const void *test_data)
 						NULL, NULL);
 }
 
+static void setup_add_advertising(const void *test_data)
+{
+	add_advertising_instance(1);
+}
+
+static void setup_add_advertising_2(const void *test_data)
+{
+	add_advertising_instance(2);
+}
+
 static void setup_add_advertising_connectable(const void *test_data)
 {
 	struct test_data *data = tester_get_data();
@@ -15461,6 +15487,10 @@ int main(int argc, char *argv[])
 				&read_adv_features_success_2,
 				setup_add_advertising,
 				test_command_generic);
+	test_bredrle("Read Advertising Features - Success 3 (Instance 2 only)",
+				&read_adv_features_instance_2,
+				setup_add_advertising_2,
+				test_command_generic);
 
 	test_bredrle("Add Advertising - Failure: LE off",
 					&add_advertising_fail_1,

base-commit: 1608f836188610aabeff5a3164169ebe0360e443
-- 
2.43.0

```

## 5. Testing, as reported by the author

- **QEMU/KVM,** KASAN and lockdep, BlueZ's testers on emulated controllers, kernels from BlueZ's
  `doc/tester.config` plus hung-task detection. Each kernel had a base image and a base-plus-patch image, compared
  per case.
  - **The new case:** fails 3 of 3 on base and passes 3 of 3 with the patch, on bluetooth-next `f57f78086ab5` and
    `5063a0717aa2`, v7.4-rc4, 7.3.6, 6.18.65, 6.12.119, 6.6.163 and 6.1.193.
  - **All eleven CI testers** (bnep, iso, l2cap, mgmt, rfcomm, sco, ioctl, mesh, smp, userchan, 6lowpan) on every
    image: no other case changes. On `f57f78086ab5` the only other non-passing mgmt-tester cases are the same on
    both images (a test of a separate, unsent kernel fix, and an rfkill case that does not run in the guest).
  - **The hangs** (l2cap-tester on 6.18, 6.12, 6.6; iso-tester on 6.12) are identical both ways, and the cases after
    them, run one at a time, are identical both ways.
  - **Kernel reports:** the same KASAN and lockdep reports with and without the patch on 6.1.193, the same lockdep
    report on 6.12.119; none in any of the new runs.
- **Real hardware:** a QCA9377 (USB `13d3:3503`), Ubuntu 24.04.

  | | stock 7.0.0-43, 2026-11-25 | 7.0.0-44 + this patch, 2026-11-26 |
  |---|---|---|
  | Add Advertising, instance 2 alone | status 0 | status 0 |
  | LE Set Random Address, Advertising Parameters, Advertising Enable | each status 0 | each status 0 |
  | Read Advertising Features reply | `7ff001001f1f0500`: `num_instances 0` | `7ff001001f1f050102`: `num_instances 1`, instance 2 |
  | Remove Advertising | status 0 | status 0 |
  | the controller afterwards | up, 0 errors | up, 0 errors |

  The patched run used Ubuntu's own 7.0.0-44 source for the module, built with and without the one-line change;
  the two builds differ only in that line. Ubuntu's `net/bluetooth/mgmt.c` is byte-identical in 7.0.0-43 and
  7.0.0-44, so the stock run is the "before" of the same code. The module was installed for the next boot only and
  loaded by a cold boot (never reloaded live). "Accepted" means the commands' completion status; nothing observed the
  radio.
- **Not done:** a test with a public instance and the mesh instance together.

## 6. Recipients and order

**Kernel patch, as dry-run:**
- To: linux-bluetooth;
- Cc: Marcel Holtmann, Luiz Augusto von Dentz (the maintainers), Brian Gix (author of `b338d91703fa`, at the
  address of his latest commits, 2023), and stable@vger.kernel.org, which git adds from the `Cc: stable` trailer;
- **linux-kernel@vger.kernel.org: not copied** (changed since the last request, which left it open).

**Why:**
- **Mainline changed the rule on 2026-11-13.** Commit `3a198413bb71` ("docs: submitting-patches: make LKML a list of
  last resort again", in v7.4-rc4) replaced "linux-kernel@vger.kernel.org should be used by default for all
  patches" with: "You should also normally choose at least one mailing list to receive a copy of your patch set.
  Look in the MAINTAINERS file for a subsystem-specific list … linux-kernel@vger.kernel.org functions as a list of
  last resort for patches that do not have a subsystem-specific list."
- bluetooth-next still carries the older text, which the last request quoted; two reviewers' "copy it" rested on
  that older text.
- **Practice,** measured before the change was known (linux-bluetooth, 2026-01-12 to 11-26): 73% of non-maintainer
  kernel postings copied it, the two maintainers' own never did, and the share applied was 55% with and 60% without
  (descriptive counts).

**The order:** the kernel patch first. Then the BlueZ test, with the kernel patch's lore link, either the same day
or once the fix is in bluetooth-next.

## 7. How to answer

```text
Kernel patch: send / send after changes / hold
BlueZ test:   send / send after changes / hold
Errors (false, overclaimed, or a maintainer would reject): ...
Section 2 changes: each acceptable / not, and why
linux-kernel not copied: agree / disagree, and why
Preferences (not blocking): ...
Checked myself / taken from this document: ...
```
