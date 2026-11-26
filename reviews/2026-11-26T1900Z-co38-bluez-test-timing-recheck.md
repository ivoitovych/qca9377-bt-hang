# The BlueZ test for a sent Bluetooth MGMT fix: send it now, or after the fix is applied? (2026-11-26)

## What we ask

The kernel fix was sent today and is on the list. Its companion BlueZ test is ready but not sent. In the last
rounds, most reviewers preferred **sending the test only once the kernel fix is in bluetooth-next**, and we adopted
that plan.

We now propose to change it and **send the test now**, as its own BlueZ mail that names the kernel patch. The
change rests on new evidence about how the maintainers themselves handle this; section 2 has it, each item checked.
This document asks you to judge that change. You may have agreed with the earlier plan, and that is exactly why we
ask.

Everything needed is here, with no repository links. Both patches are copied byte for byte: the kernel patch as
sent, and the BlueZ test as it would be sent, each from its `Date:` line on.

**Please check:**
1. **The timing (section 3):** send now, or keep waiting until the fix is in bluetooth-next? Why?
2. **The BlueZ test's notes below `---` (section 5):** right for a test posted before the fix is applied?
3. **Anything in the BlueZ patch** that is false or that a maintainer would reject.

## 1. Where things stand

- **The kernel patch** is "[PATCH] Bluetooth: MGMT: Fix Read Advertising Features hiding instances".
  - **Sent:** 2026-11-26 16:19:33 UTC to linux-bluetooth, Cc Marcel Holtmann, Luiz Augusto von Dentz, Brian Gix
    and stable.
  - **Received:** on lore with the body byte-identical to the file sent; in patchwork as 15026726, state "new",
    CI checks not yet reported.
  - **Lore:** https://lore.kernel.org/linux-bluetooth/20261126161933.923041-1-yaroslav.voytovych@gmail.com/
- **The BlueZ test** is "[PATCH BlueZ] mgmt-tester: Test a lone advertising instance 2".
  - **Diff:** unchanged since the earlier rounds; patch-id `70a4873086000186e05d1bbe88d65a75bc3b9e18`.
  - **State:** it applies to BlueZ master `79162c108911`, fetched today, and carries the real lore link.
  - **Checks:** the linux-bluetooth CI's own BlueZ checks, run locally on it, all pass on both sides.
  - **Dry run:** to linux-bluetooth only; "Result: OK".
- **What the test does:** it adds only advertising instance 2 and expects Read Advertising Features to list it. It
  fails on kernels with the bug (6.1 and later) until the fix is in, and passes with it. In QEMU it failed 3/3
  without the fix and passed 3/3 with it on eight kernel trees.

## 2. The evidence behind the change (each item checked against the primary source)

1. **The Bluetooth maintainer posts such tests himself, before his kernel change is applied.**
   - **The series:** on 2026-11-25 Luiz Augusto von Dentz posted "[PATCH BlueZ v4 0/6] Add tests for security of
     deferred setup" to linux-bluetooth, for his own kernel series, which is still in review.
   - **The cover letter:** "The following tests depend on the kernel series "[PATCH v7 0/4] L2CAP: Fix channels being
     established with insufficient security" and fail without it". It then lists five tests.
   - **Checked:** read in the linux-bluetooth archive.
2. **BlueZ's own checks do not run the kernel testers, by design.** BlueZ commit `bed6e3602` (Luiz Augusto von
   Dentz, 2026-09-08), "test: functional: exclude kernel testers from make check", says the kernel testers "exercise
   the kernel rather than BlueZ userspace and should not gate a userspace release".
   - So posting a tester case that fails on unfixed kernels does not turn the BlueZ patch's own CI red.
   - Our local run of that CI on this test: every check passes.
3. **Where a failing case can show, and when.** The kernel patches' CI runs mgmt-tester from BlueZ master. A new case
   that needs an unapplied fix therefore fails in other people's kernel CI runs. That happens only **after the test
   is applied to BlueZ** and only **until the fix is in the kernel tree that CI tests**.
   - The maintainer applies both, so the order is in his hands, and it varies.
   - In Tobias Wilken's pair ("Return RFKILLED for Set Powered on a blocked controller" and its mgmt-tester case),
     the test was applied 9 minutes after the fix, by the patchwork application notices.
   - In Kyle Pepper's pair (a host-resolved RPA scan fix and its test), both were applied on 2026-10-14, the test
     about 5 hours before the fix.
   - So a short window of red CI for others has happened before, and was accepted.
4. **How common each order is.** In a survey of 11 kernel-fix and BlueZ-test pairs (2025-11 to 2026-11):
   - the test was posted the same day as the kernel patch, as its own BlueZ thread, in 7;
   - in 2, it was posted after the kernel fix was applied;
   - BlueZ applied the test before the kernel fix in 7 pairs, from hours to weeks earlier.
   - No maintainer objection to a test that fails on unfixed kernels was found.
5. **The kernel documents and the separate repository.**
   - `Documentation/process/5.Posting.rst` asks for tests "as a separate member of your series", and netdev's
     maintainer guide asks that selftests go in the same series as the fix. Both are about tests in the kernel
     tree.
   - A BlueZ tester case lives in another repository. For that case, netdev's guide describes the kernel and
     userspace changes being posted as separate threads.
   - netdev also asks that a test not land in a tree before its fix. Here that is the maintainer's application
     order, which the test's note addresses.

**One claim from the research that prompted this was wrong, and is not used.** It said Kyle Pepper's test "remained
unapplied". It is in BlueZ master, applied the day his kernel fix was; only its CI pull request was closed.

## 3. The change, and why

| | Earlier plan | Proposed now |
|---|---|---|
| When the test is posted | once the fix is in bluetooth-next | now, as its own BlueZ mail |
| What it says | names the kernel patch | the same, with the lore link and a note on when it will pass |
| Who decides when it is applied | — | the maintainer, as always; the note tells him it passes once the fix is in |
| Risk of red CI for others | none | only if it is applied before the fix lands, which the note asks against |

**Why change:**
- **It is how the maintainer works:** item 1 is his own practice, this week.
- **He reviews the pair together:** the fix and the test that shows it, now, rather than days apart.
- **The test cannot be forgotten** once the fix is applied.
- **The earlier reason was red CI,** and it is answered by the note and the maintainer's control over the order.
  Posting the test does not cause it (item 2).

**The cost of the change:** if the maintainer applies the test before the fix, other kernel patches' mgmt-tester
results show one failing case until the fix lands. Item 3 shows both orders. The note below `---` asks for the fix
first, and keeping the test back until the fix is applied removes the cost entirely. That is the alternative to
weigh.

## 4. The kernel patch, as sent (for context)

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

## 5. The BlueZ test, as it would be sent

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

## 6. How to answer

```text
Timing: send now / wait until the fix is in bluetooth-next, and why
BlueZ notes below ---: fine / change to ...
Anything false or rejectable in the BlueZ patch: ...
Checked myself / taken from this document: ...
```
