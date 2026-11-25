# A Linux Bluetooth MGMT fix and its BlueZ test: request for an independent, extended review (2026-11-25)

## What we ask

This document holds one small fix to the Linux kernel's Bluetooth management interface (MGMT) and the
BlueZ test that goes with it. **Neither has been sent.** We ask for a fresh, independent review before
they go to the linux-bluetooth list.

Everything you need is in this file. Nothing here links to a repository. Both patches are copied byte
for byte from the files that would be sent, from their `Date:` line on.

**This round is meant to find errors, not to polish wording.** Please look for:
- anything **false** in either message, or claimed beyond the evidence;
- any **correctness** problem in the code, including cases the message does not mention;
- anything a **maintainer would reject or ask about** before applying;
- anything in sections 1–5 that **you checked and found wrong**.

Wording you would merely prefer is welcome, but please mark it as such: it will not hold the send.

**Please verify rather than trust.** Where you can, check a claim against the kernel or BlueZ source
yourself, and say which ones you checked and which you took from this document. Section 6 lists checks
we would especially like done independently.

## 1. Facts as stated by the author

- **The author** is Iaroslav Voitovych, who sends both patches himself.
- **Sign-off:** the kernel patch carries no `Signed-off-by:` yet; he adds his own at send time. The BlueZ
  patch carries none, by BlueZ's rule.
- **Bases:** bluetooth-next `5063a0717aa2` for the kernel patch and BlueZ master `1608f8361886` for the
  test. On 2026-11-25 both apply unchanged to today's tips: bluetooth-next `f57f78086ab5`, mainline
  v7.4-rc4, BlueZ master `1608f8361886`. `net/bluetooth/mgmt.c` has no commit since the base.
- **Patch-ids** (`git patch-id --stable`):
  - kernel: `a15c80fa459bcaf1a3fa84e9aa447ae1372f8444`;
  - BlueZ: `70a4873086000186e05d1bbe88d65a75bc3b9e18`.
- **checkpatch** `--strict` is clean on the kernel patch.
- **Planned recipients for the kernel patch:** To linux-bluetooth; Cc Marcel Holtmann, Luiz Augusto von
  Dentz, and Brian Gix (author of the commit in `Fixes:`, at the address of his latest commits, 2023).
  linux-kernel is not copied. stable is reached through the trailer.
- **Planned order:** the kernel patch first. The BlueZ test follows the same day in its own thread,
  with the kernel patch's lore link filled in below its `---`.

## 2. The defect

`read_adv_features()` in `net/bluetooth/mgmt.c` answers MGMT Read Advertising Features, which lists the
advertising instances user space may see. As on bluetooth-next:

```c
	rp_len = sizeof(*rp) + hdev->adv_instance_cnt;
	rp = kmalloc(rp_len, GFP_ATOMIC);
	...
	rp->max_instances = hdev->le_num_of_adv_sets;
	rp->num_instances = hdev->adv_instance_cnt;

	instance = rp->instance;
	list_for_each_entry(adv_instance, &hdev->adv_instances, list) {
		/* Only instances 1-le_num_of_adv_sets are externally visible */
		if (adv_instance->instance <= hdev->adv_instance_cnt) {
			*instance = adv_instance->instance;
			instance++;
		} else {
			rp->num_instances--;
			rp_len--;
		}
	}
```

- **The intent:** stated in the comment. The one internal instance is the mesh instance, numbered one
  past the controller's sets (`u8 instance = hdev->le_num_of_adv_sets + 1;` in `mesh_send_sync()`).
- **The bug:** each instance's *number* is compared with the *count* of instances. An instance numbered
  above the current count drops out of the reply.
- **The simplest case:** add only instance 2. The count is 1 and `2 <= 1` is false, so the reply lists
  no instance.
- **In ordinary use:** add instances 1 and 2, and let instance 1's timeout remove it. Instance 2 keeps
  advertising, but is no longer reported.
- **Origin:** `b338d91703fa` ("Bluetooth: Implement support for Mesh", 2022-09-01, merged for v6.1).
  It is present in stable 7.3, 6.18, 6.12, 6.6 and 6.1, and not in 5.15 or 5.10.
- **Found** with mgmt-tester, while writing tests for advertising instances.

## 3. The kernel patch

File SHA-256: `7b4f01a577a927a39a9fb5967f9e2d533ac096c2b6fdfb6163961e2e15968856`

```text
Date: Sat, 14 Nov 2026 01:47:30 +0100
Subject: [PATCH] Bluetooth: MGMT: Fix Read Advertising Features hiding
 instances

read_adv_features() means to hide only the mesh instance, which is
numbered one past the controller's advertising sets, but it compares
each instance number with the number of instances instead of the number
of sets. An instance whose number is greater than the current number of
instances is left out: with instances 1 and 2 added and instance 1
removed, for example after its timeout, instance 2 is still advertised
but no longer reported.

Compare with le_num_of_adv_sets, as the comment says.

This was found with mgmt-tester while testing advertising instances,
and reproduced in QEMU with a new mgmt-tester case that adds only
instance 2: without this patch the reply lists no instance.

Fixes: b338d91703fa ("Bluetooth: Implement support for Mesh")
Cc: stable@vger.kernel.org
---
Tested in QEMU with a new mgmt-tester case, "Read Advertising
Features - Success 3 (Instance 2 only)", submitted to BlueZ
separately: it adds only instance 2 and expects exactly that instance
in the reply. With this patch the case passes 3 of 3 runs and without
it fails 3 of 3, on bluetooth-next 5063a0717aa2, v7.4-rc4, 7.3.6,
6.18.65, 6.12.119, 6.6.163 and 6.1.193. In the ten testers of the
Bluetooth kernel CI, no other observed case changed on any of these
kernels.

The bug also shows on real hardware, a QCA9377 (USB 13d3:3503) with
Ubuntu's 7.0.0-43 kernel: Add Advertising for instance 2 alone
succeeds and the controller starts advertising it, yet Read
Advertising Features lists no instance.

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

## 4. The BlueZ test

File SHA-256: `73ac450e9e2cc130179e29bfca2240bd7ebcdc168497c525d58499c0decd3c04`

```text
Date: Mon, 23 Nov 2026 05:33:25 +0100
Subject: [PATCH BlueZ] mgmt-tester: Test a lone advertising instance 2

Read Advertising Features lists the advertising instances that user
space can see. Add a test that adds only instance 2 and expects the
reply to list exactly that instance.

Without the kernel change "Bluetooth: MGMT: Fix Read Advertising
Features hiding instances" the instance is left out, because the
kernel compares each instance number with the number of instances.
---
Kernel fix: <LORE-LINK-OF-THE-KERNEL-PATCH>

This case fails on kernels without that fix. Please apply it once the
fix is in the kernel the Bluetooth CI runs.

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

**Notes:**
- **The expected reply** is the existing "Read Advertising Features - Success 2" reply with the instance
  identifier changed from `0x01` to `0x02`. `max_instances` `0x05` is the kernel default
  (`HCI_MAX_ADV_INSTANCES`), because `test_bredrle` uses a legacy emulated controller.
- **The refactor:** `setup_add_advertising()` becomes a wrapper around `add_advertising_instance(1)`, so
  existing callers behave as before. The only visible change to them is the tester log line, which now
  prints the instance number.
- **The placeholder** `<LORE-LINK-OF-THE-KERNEL-PATCH>` below `---` is replaced with the real link on the
  send day.

## 5. Testing, as reported by the author

- **Emulation:**
  - QEMU/KVM guests with 4 vCPUs, KASAN and lockdep, and BlueZ's tester programs on emulated
    controllers. The kernels were built from BlueZ's `doc/tester.config`, and all runs used one BlueZ
    build.
  - **Per kernel:** a base image and a base-plus-this-patch image. Each ran the ten testers the
    linux-bluetooth CI uses (l2cap, iso, bnep, mgmt, rfcomm, sco, ioctl, mesh, smp, userchan), compared
    per case name. The new case ran 3 times on each image.
  - **The new case** fails 3 of 3 on base and passes 3 of 3 with the patch on bluetooth-next
    `5063a0717aa2`, v7.4-rc4, 7.3.6, 6.18.65, 6.12.119, 6.6.163 and 6.1.193.
  - **No other observed case changed** on any of these kernels.
  - **Some older-line runs hang,** identically with and without the patch: l2cap-tester on 6.18, 6.12
    and 6.6, and iso-tester on 6.12. Cases after a hang are not observed. 6.1.193 also shows two KASAN
    reports and a lockdep warning, identical on both sides.
- **Real hardware**, stock kernel, no build (2026-11-25): a QCA9377 (USB `13d3:3503`) on Ubuntu's
  7.0.0-43, driving MGMT directly.
  - **Add Advertising** for instance 2 alone: status 0.
  - **The controller:** LE Set Random Address, LE Set Advertising Parameters and LE Set Advertising
    Enable, each with status 0.
  - **Read Advertising Features:** `num_instances 0`, with the 8-byte reply `7ff001001f1f0500`. The fixed
    kernel's reply in emulation is 9 bytes, ending `05 01 02`.
  - **Remove Advertising** for instance 2: status 0.
- **Not done:**
  - the patched kernel on the real hardware (planned);
  - the eleventh CI tester, 6lowpan-tester;
  - a test with a public instance and the mesh instance together.

## 6. Checks we would like done independently

1. **Every path that adds an instance:** confirm that only the mesh instance can have a number above
   `le_num_of_adv_sets`. That covers Add Advertising, Add Extended Advertising Parameters, the mesh code,
   and anything else that calls `hci_add_adv_instance()`.
2. **The mesh instance after the fix:** confirm it is still never listed. Is there any state in which it
   could be listed before or after the fix?
3. **The reply buffer:** confirm the reply can never exceed the allocation, and that no uninitialised byte
   is sent.
4. **`Fixes:`:** confirm that `b338d91703fa` introduced this comparison, and that the code before it had
   no comparable check.
5. **Other callers:** are there other places that compare an instance number with `adv_instance_cnt`?
6. **User space:** could any user space (bluetoothd or other MGMT clients) depend on the old reply?
7. **The test:** confirm that the generic tester compares the exact length and every byte, so that an
   empty list, a wrong ID or an extra ID all fail. Confirm also that the refactor leaves every existing
   caller unchanged.
8. **Stable:** is this a fix the stable rules accept, with `Cc: stable` as written?
9. **The messages:** is any sentence, above or below `---`, false or stronger than section 5 supports?

## 7. How to answer

```text
Kernel patch: send / send after changes / hold
BlueZ test:   send / send after changes / hold
Errors found (false, incorrect, or a maintainer would reject): ...
Preferences (not blocking): ...
Section 6, each: checked myself / taken from this document, and the result
```
