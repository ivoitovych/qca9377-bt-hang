# The BlueZ test for a sent Bluetooth MGMT fix: the text as it will be sent (2026-11-26)

## What we ask

This is the BlueZ test exactly as it will be sent, after the last read. In that read all four reviewers said "send"
and found nothing false. Two small wording points in the notes below `---` were applied; section 2 shows them. The
diff, the commit message and the patch-id are unchanged.

Everything needed is here, with no repository links. Both patches are copied byte for byte from the files, from
their `Date:` line on: the kernel patch as sent, for context, and the BlueZ test as it will be sent.

**Please check only:** does the final paragraph read well? Is anything false or rejectable? One line is enough
(section 5).

## 1. Facts as stated by the author

- **The kernel patch** is "[PATCH] Bluetooth: MGMT: Fix Read Advertising Features hiding instances".
  - **Sent:** 2026-11-26 16:19:33 UTC to linux-bluetooth, Cc the maintainers, the author of the `Fixes:` commit,
    and stable.
  - **Received:** on lore with the body byte-identical; in patchwork as 15026726; mirrored by the CI as pull 1233,
    checks still to report.
  - **Lore:** https://lore.kernel.org/linux-bluetooth/20261126161933.923041-1-yaroslav.voytovych@gmail.com/
  - **Not yet applied:** bluetooth-next is still `f57f78086ab5`, checked 22:25 UTC.
- **The BlueZ test** is "[PATCH BlueZ] mgmt-tester: Test a lone advertising instance 2".
  - **Patch-id:** `70a4873086000186e05d1bbe88d65a75bc3b9e18`, unchanged since 2026-11-24.
  - **Applies** to BlueZ master `79162c108911`, fetched 22:25 UTC. No `Signed-off-by`, by BlueZ's rule.
  - **Dry run:** to linux-bluetooth only; "Result: OK".
- **The pairing is written in both mails:**
  - the test's commit message names the kernel change by its subject;
  - its notes give the kernel mail's lore link;
  - the kernel patch's notes name the test case and say it "is being submitted to BlueZ separately".
- **Why it is sent now** (decided in the timing recheck, four reviewers): the maintainer posts BlueZ tests that
  fail until his own kernel series lands, and BlueZ's `make check` / `check-functional` path excludes kernel
  testers. A failing case can show only in the kernel CI, once the test is applied and until the fix is there.

## 2. The final notes below `---`

```text
before (last read):
Without that fix this case fails, because the reply leaves out
instance 2 (kernels from 6.1 on); with it the case passes. Applying
it once the fix is in bluetooth-next keeps the kernel CI runs of
other patches green.

now:
Without that fix this case fails, because the reply leaves out
instance 2 (kernels from 6.1 on); with it the case passes. Applying
this test once the fix is in bluetooth-next avoids a known failure
in the kernel CI runs of other patches.
```

- **"avoids a known failure" replaces "keeps … green"** (two reviewers). The test can only avoid adding its own
  expected failure; it cannot promise anything about other patches' CI.
- **"this test" replaces "it"** (one reviewer). "it" meant the fix in the sentence before.

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

## 4. The BlueZ test, as it will be sent

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
this test once the fix is in bluetooth-next avoids a known failure
in the kernel CI runs of other patches.

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
BlueZ test: send / hold
Final notes: fine / change to ...
Anything false or rejectable: ...
```
