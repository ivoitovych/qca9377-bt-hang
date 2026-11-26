# The BlueZ test for a sent Bluetooth MGMT fix: final text before sending (2026-11-26)

## What we ask

The kernel fix was sent today. Its companion BlueZ test goes next, as its own mail. In the last round (the timing
recheck), all four reviewers who answered said "send now" and found nothing false in the test. They differed only
on the two sentences below `---`. Those were rewritten from their positions; section 2 shows the change. The diff,
the commit message and the patch-id are unchanged.

Everything needed is here, with no repository links. Both patches are copied byte for byte from the files, from
their `Date:` line on: the kernel patch as sent, for context, and the BlueZ test as it would be sent.

**Please check only:** do the new notes read well and state the dependency correctly? Is anything in the BlueZ
patch false or rejectable? A short answer is enough (section 5).

## 1. Facts as stated by the author

- **The kernel patch** is "[PATCH] Bluetooth: MGMT: Fix Read Advertising Features hiding instances".
  - **Sent:** 2026-11-26 16:19:33 UTC to linux-bluetooth, Cc the two maintainers, the author of the commit in
    `Fixes:`, and stable.
  - **Received:** on lore with the body byte-identical; in patchwork as 15026726, state "new".
  - **Lore:** https://lore.kernel.org/linux-bluetooth/20261126161933.923041-1-yaroslav.voytovych@gmail.com/
- **The BlueZ test** is "[PATCH BlueZ] mgmt-tester: Test a lone advertising instance 2".
  - **Patch-id:** `70a4873086000186e05d1bbe88d65a75bc3b9e18`, unchanged since 2026-11-24.
  - **Applies** to BlueZ master `79162c108911`, fetched today. No `Signed-off-by`, by BlueZ's rule.
  - **Dry run:** to linux-bluetooth only; "Result: OK".
- **What the test does:** it adds only advertising instance 2 and expects Read Advertising Features to list exactly
  that instance (status, length and bytes are compared). The expected reply equals the existing instance-1 test's
  reply except for the last byte, `0x02`.
  - In QEMU it failed 3/3 without the kernel fix and passed 3/3 with it on eight kernel trees.
  - On a real QCA9377, the stock kernel's reply listed no instance; with the fix it listed instance 2.
- **Why now, not after the fix is applied:** the last round agreed with the evidence.
  - The Bluetooth maintainer posted a BlueZ test series on 2026-11-25 whose cover letter says its tests depend on
    his kernel series still in review and fail without it.
  - BlueZ's `make check` / `check-functional` path excludes kernel testers by design (`bed6e3602`).
  - A failing case can show only in the kernel CI's mgmt-tester run, and only once the test is applied and until
    the fix is in the tree that CI tests.
  - When to apply it is the maintainer's call; the notes say what follows from the order.

## 2. The change: the notes below `---`

```text
before:
This case fails on kernels that have the bug (6.1 and later) until
that fix is in. Please apply it once the fix is in the kernel the
Bluetooth CI runs.

after:
Without that fix this case fails, because the reply leaves out
instance 2 (kernels from 6.1 on); with it the case passes. Applying
it once the fix is in bluetooth-next keeps the kernel CI runs of
other patches green.
```

**How the reviewers' positions were combined:**
- **Reviewer 1:** fine as written.
- **Reviewer 2:** say why the order matters.
- **Reviewer 3:** state the fact and leave the order to the maintainer, as the maintainer's own series and a recent
  contributor's companion test do.
- **Reviewer 6:** "bluetooth-next" is plainer than "the kernel the Bluetooth CI runs".

So the fact comes first, then what applying it after bluetooth-next achieves, as information, not an instruction.
The line `Kernel fix: <lore link>` above it is unchanged.

**Known costs, accepted:**
- The BlueZ CI closes a pull request open for over two weeks and asks for a resend. If the test is held that long,
  it is resent once.
- If review renames the kernel fix, the test's commit message, which cites the subject, needs a v2.

## 3. The kernel patch, as sent (for context)

```text
Date: Sat, 14 Nov 2026 01:47:30 +0100
Subject: [PATCH] Bluetooth: MGMT: Fix Read Advertising Features hiding
 instances

read_adv_features() is meant to report instances 1 to
le_num_of_adv_sets and to leave out the mesh instance, which is
numbered le_num_of_adv_sets + 1. Instead it compares each instance
number with the number of instances, so an instance numbered above
the current number of instances is left out: with instances 1 and 2
added and instance 1 removed, for example after its timeout, instance
2 remains active but is no longer reported.

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

No other case in the Bluetooth kernel CI's eleven testers changed its
result on any of these kernels; the CI itself runs only mgmt-tester
and mesh-tester for this file. No test has a mesh instance present
during the read; it stays hidden because its number is
le_num_of_adv_sets + 1. l2cap-tester hangs on 6.18, 6.12 and 6.6, and
iso-tester on 6.12, the same way with and without this patch; the
cases after those hangs, run separately, give the same results with
and without it. The same KASAN and lockdep reports appear with and
without it on 6.1.193, and the same lockdep report on 6.12.119.

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

## 4. The BlueZ test, as it would be sent

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
Kernel fix: https://lore.kernel.org/linux-bluetooth/20261126161933.923041-1-yaroslav.voytovych@gmail.com/

Without that fix this case fails, because the reply leaves out
instance 2 (kernels from 6.1 on); with it the case passes. Applying
it once the fix is in bluetooth-next keeps the kernel CI runs of
other patches green.

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

## 5. How to answer

```text
BlueZ test: send / send after changes / hold
New notes: fine / change to ...
Anything false or rejectable: ...
```
