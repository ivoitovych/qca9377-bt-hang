# A Linux Bluetooth MGMT fix and its BlueZ test: final recheck after the last round (2026-11-26)

## What we ask

This holds the **final** kernel patch, signed, and its BlueZ test, exactly as they would be sent. Neither has been
sent. In the last round (the 08:00 UTC request), four reviewers answered "send" for the kernel patch and found no
defect in either diff. Two texts of the kernel patch changed after that, in response; nothing else did. Section 2
lists both changes.

Everything needed is in this file, with no repository links. Both patches are copied byte for byte from the files
that would be sent, from their `Date:` line on.

**Please check only:**
1. **The two changes (section 2):** true, clearer, and nothing a maintainer would object to?
2. **Anything else** in either patch that is false or that a maintainer would reject.

A short answer is enough (section 6).

## 1. Facts as stated by the author

- **Sign-off:** the kernel patch carries the author's own `Signed-off-by:` (Iaroslav Voitovych). The BlueZ patch
  carries none, by BlueZ's rule.
- **Tips** (2026-11-26, fetched again at 16:00 UTC): bluetooth-next `f57f78086ab5`; mainline v7.4-rc4; BlueZ master
  `79162c108911`. Both patches apply (`git apply --check` on an index of each tip).
- **Patch-ids** (`git patch-id --stable`), unchanged since 2026-11-24:
  - kernel: `a15c80fa459bcaf1a3fa84e9aa447ae1372f8444`;
  - BlueZ: `70a4873086000186e05d1bbe88d65a75bc3b9e18`.
- **checkpatch** `--strict`, with the sign-off check on: "0 errors, 0 warnings, 0 checks".
- **Recipients, from the dry run:** To linux-bluetooth; Cc Marcel Holtmann, Luiz Augusto von Dentz, Brian Gix
  (author of `b338d91703fa`), and stable@vger.kernel.org from the `Cc: stable` trailer. linux-kernel is not copied:
  mainline's `Documentation/process/submitting-patches.rst` now makes it the list of last resort where a subsystem
  list exists (`3a198413bb71`, authored 2026-11-13, committed 2026-11-17, in v7.4-rc4). All four reviewers agreed.
- **Testing:** unchanged since the last request.
  - QEMU: the new case fails 3/3 without and passes 3/3 with the patch on bluetooth-next `f57f78086ab5` and
    `5063a0717aa2`, v7.4-rc4, 7.3.6, 6.18.65, 6.12.119, 6.6.163, 6.1.193. No other case in the CI's eleven testers
    changes.
  - The linux-bluetooth CI's own checks, run locally on the files: all PASS, both patches, both sides.
  - Hardware: on a QCA9377, the stock kernel lists no instance; with the patch, it lists instance 2.

## 2. The two changes since the last round, and why

**Change 1: commit message, above `---` (permanent).**

```text
before:  numbered one past the controller's advertising sets. Instead it
after:   numbered le_num_of_adv_sets + 1. Instead it
```

Two reviewers noted that "the controller's advertising sets" is inexact. `le_num_of_adv_sets` is the controller's
set count only with extended advertising. Otherwise it is the default `HCI_MAX_ADV_INSTANCES` (5), as on the
QCA9377 of the hardware run (`max_instances 5`). The new wording names the exact value that `mesh_send_sync()` uses.

**Change 2: the tester paragraph, below `---`.**

```text
before:
In all eleven of the Bluetooth kernel CI's testers, including
mgmt-tester and mesh-tester, which that CI runs for this file, no
other case changed its result on any of these kernels. l2cap-tester
...

after:
No other case in the Bluetooth kernel CI's eleven testers changed its
result on any of these kernels; of those, the CI runs mgmt-tester and
mesh-tester for this file. No test has a mesh instance present during
the read; it stays hidden because its number is le_num_of_adv_sets + 1.
l2cap-tester
...
```

The rest of that paragraph (the hangs, and the KASAN and lockdep reports) is unchanged.
- **The first sentence:** all four reviewers found the relative clause hard to read; it could be taken as "the CI
  runs all eleven for this file". The CI runs only mgmt-tester and mesh-tester for `mgmt.c`. One proposed rewrite
  ("the eleven testers that the Bluetooth kernel CI runs for mgmt.c") would have said exactly that, which is false,
  so it was not used.
- **The new sentence:** naming mesh-tester could be read as if the mesh exclusion had been exercised. Checked:
  `tools/mesh-tester.c` never sends Read Advertising Features, so no test reads the list with a mesh instance
  present. The sentence says that, and why the mesh instance stays hidden. All four reviewers judged a mesh test
  unnecessary.

**Considered and not changed:**
- **The hang, KASAN and lockdep sentences.** One reviewer would drop them; three accept them, and they tell a
  maintainer who runs these lines what to expect.
- **bluetoothd's consequence.** At start-up, bluetoothd clears leftover instances only when `num_instances` is
  non-zero (`src/advertising.c`). This is seen in the source, not yet on hardware, so it is not in the message.
- **"remains active" and "accepts LE Set Advertising Enable".** Kept; they claim only kernel state and command
  status.
- **The BlueZ patch:** unchanged. It goes once the kernel fix is in the kernel the BlueZ CI runs, so that CI is
  never red on a case the tree cannot pass. Three of the four reviewers prefer or suggest this.

## 3. The kernel patch, final

```text
Date: Sat, 14 Nov 2026 01:47:30 +0100
Subject: [PATCH] Bluetooth: MGMT: Fix Read Advertising Features hiding
 instances

read_adv_features() is meant to report instances 1 to
le_num_of_adv_sets and to leave out the mesh instance, which is
numbered le_num_of_adv_sets + 1. Instead it
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

No other case in the Bluetooth kernel CI's eleven testers changed its
result on any of these kernels; of those, the CI runs mgmt-tester and
mesh-tester for this file. No test has a mesh instance present during
the read; it stays hidden because its number is le_num_of_adv_sets + 1.
l2cap-tester hangs on 6.18, 6.12 and 6.6, and iso-tester on 6.12, the
same way with and without this patch; the cases after those hangs, run
one at a time, give the same results with and without it. The same
KASAN and lockdep reports appear with and without it on 6.1.193, and
the same lockdep report on 6.12.119.

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

## 5. Order

The kernel patch first. The BlueZ test follows, with the kernel patch's lore link, once the fix is in bluetooth-next.

## 6. How to answer

```text
Kernel patch: send / send after changes / hold
Change 1 (commit message): acceptable / not, and why
Change 2 (tester paragraph): acceptable / not, and why
Anything else false or rejectable: ...
Checked myself / taken from this document: ...
```
