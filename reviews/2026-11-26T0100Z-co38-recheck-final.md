# A Linux Bluetooth MGMT fix and its BlueZ test: recheck of the final files before sending (2026-11-26)

## What we ask

This holds the **final** kernel patch, signed, and its BlueZ test, exactly as they would be sent. Neither has been
sent. Both changed since the last review request (2026-11-25), in the messages only; section 2 lists every change.
The diffs are unchanged.

Everything needed is in this file, with no repository links. Both patches are copied byte for byte from the files
that would be sent, from their `Date:` line on.

**Please check:**
1. **Each changed sentence (section 2):** is it true, and is it clearer for a maintainer?
2. **Both messages, read cold:** is anything false, claimed beyond the evidence, or something a maintainer would
   ask about?
3. **The recipients and the order (section 6),** including whether to copy linux-kernel. Section 6 has facts for
   this.
4. **Anything a maintainer would reject.**

Mark preferences as such. Please also say what you checked yourself and what you took from this document.

## 1. Facts as stated by the author

- **Sign-off:** the kernel patch carries the author's own `Signed-off-by:` (Iaroslav Voitovych). The BlueZ patch
  carries none, by BlueZ's rule.
- **Today's tips** (2026-11-26):
  - bluetooth-next `f57f78086ab5`; `net/bluetooth/mgmt.c` unchanged since the base `5063a0717aa2`;
  - mainline v7.4-rc4;
  - BlueZ master `79162c108911`; `tools/mgmt-tester.c` unchanged since the base `1608f8361886`.

  Both patches apply to today's tips (`git apply --check` on an index of each tip).
- **Patch-ids** (`git patch-id --stable`), unchanged since 2026-11-24:
  - kernel: `a15c80fa459bcaf1a3fa84e9aa447ae1372f8444`;
  - BlueZ: `70a4873086000186e05d1bbe88d65a75bc3b9e18`.
- **checkpatch** `--strict`, with the sign-off check on: "0 errors, 0 warnings, 0 checks".
- **Origin:** the bug comes from `b338d91703fa` (v6.1 cycle). It is in stable 7.3, 6.18, 6.12, 6.6 and 6.1, and not
  in 5.15 or 5.10, which list every instance with no filter.

## 2. What changed since the 2026-11-25 request, and why

Kernel message, above `---` (permanent):
- **Opening:** from "means to hide only the mesh instance, …" to "is meant to report instances 1 to
  `le_num_of_adv_sets` and to leave out the mesh instance, …". An ISO broadcast source with a user-supplied BIS
  number can also take the id `le_num_of_adv_sets + 1` (`qos_set_bis()` keeps a set value, `check_bcast_qos()`
  does not bound it, and `hci_add_adv_instance()` allows up to sets + 1). So "only the mesh instance" was stronger
  than the code shows. The opening now states the range the code comment gives. Both predicates hide that id, so
  the fix is unaffected. The BIS question is a separate, unverified item.
- **The example:** "instance 2 is still advertised" became "instance 2 remains active". It claims only the kernel
  state.
- **"How found":** "while writing tests for advertising instances".

Kernel notes below `---`:
- **The test sentence:** "being submitted to BlueZ separately", since it goes out after the kernel patch.
- **The other testers:**
  - the CI lists eleven testers and runs mgmt-tester and mesh-tester for `mgmt.c`, so the text names "ten of the
    Bluetooth kernel CI's testers, including mgmt-tester and mesh-tester, which it runs for this file";
  - "no other case that ran changed its result";
  - the hangs are named: l2cap-tester on 6.18, 6.12 and 6.6, and iso-tester on 6.12, identical both ways.
- **The baseline reports:** "The same KASAN and lockdep reports appear with and without it on 6.1.193, and the
  same lockdep report on 6.12.119." A maintainer then needn't ask.
- **Hardware:**
  - "the controller accepts LE Set Advertising Enable for it" instead of "starts advertising it", because the
    evidence is the command's success, not a radio observation;
  - "The patched kernel has not yet run on that hardware", so the paragraph shows the bug, not the fix.

BlueZ message:
- **The body:** "On kernels from 6.1 on without the kernel change …", because kernels before 6.1 have no filter, so
  "without the kernel change" alone was false for them.
- **The cause** now says "instead of the number of advertising sets".
- **Below `---`:** "This case fails on kernels that have the bug (6.1 and later) until that fix is in."

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
patch and passes in 3 of 3 with it, on bluetooth-next 5063a0717aa2,
v7.4-rc4, 7.3.6, 6.18.65, 6.12.119, 6.6.163 and 6.1.193.

In ten of the Bluetooth kernel CI's testers, including mgmt-tester
and mesh-tester, which it runs for this file, no other case that ran
changed its result on any of these kernels. l2cap-tester hangs on
6.18, 6.12 and 6.6, and iso-tester on 6.12, the same way with and
without this patch, so the cases after those hangs did not run. The
same KASAN and lockdep reports appear with and without it on 6.1.193,
and the same lockdep report on 6.12.119.

The bug also shows on real hardware: on a QCA9377 (USB 13d3:3503)
with Ubuntu's 7.0.0-43 kernel, Add Advertising for instance 2 alone
succeeds and the controller accepts LE Set Advertising Enable for it,
yet Read Advertising Features lists no instance. The patched kernel
has not yet run on that hardware.

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

## 4. The BlueZ test, final

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

## 5. Testing, as reported by the author (unchanged since 2026-11-25)

- **QEMU/KVM,** KASAN and lockdep, BlueZ's testers on emulated controllers, kernels from `doc/tester.config`.
  Each kernel had a base image and a base-plus-patch image, running ten CI testers and compared per case.
  - **The new case:** fails 3 of 3 on base and passes 3 of 3 with the patch, on bluetooth-next `5063a0717aa2`,
    v7.4-rc4, 7.3.6, 6.18.65, 6.12.119, 6.6.163 and 6.1.193.
  - **No other case that ran changed.** The hangs named above are identical both ways.
- **Real hardware,** stock kernel, no build: a QCA9377 (USB `13d3:3503`) on Ubuntu 7.0.0-43.
  - Add Advertising for instance 2 alone: status 0. The controller completed LE Set Random Address, LE Set
    Advertising Parameters and LE Set Advertising Enable, each with status 0.
  - Read Advertising Features: `num_instances 0`, reply `7ff001001f1f0500`.
  - Remove Advertising: status 0.
- **Not done:** the patched kernel on the hardware (planned), 6lowpan-tester, a public-plus-mesh test.

## 6. Recipients and order

**Kernel patch, as dry-run:**
- To: linux-bluetooth;
- Cc: Marcel Holtmann, Luiz Augusto von Dentz (the maintainers), Brian Gix (author of `b338d91703fa`, at the
  address of his latest commits, 2023), and stable@vger.kernel.org, which git adds from the `Cc: stable` trailer;
- **open: linux-kernel@vger.kernel.org.**

**Facts on linux-kernel:**
- **The rules disagree.** `submitting-patches.rst`: "linux-kernel@vger.kernel.org should be used by default for all
  patches". `5.Posting.rst`: "Send a copy to the relevant mailing list, or, if nothing else applies, the
  linux-kernel list". `get_maintainer.pl` lists it, through MAINTAINERS "THE REST" (`F: *`).
- **Practice** on linux-bluetooth, 2026-01-12 to 11-26, 2,451 kernel patch postings:
  - 73% of the non-maintainers' postings copy it (1,594 of 2,171);
  - the two maintainers' own never do (0 of 280).
- **Outcome,** per distinct subject from non-maintainers: 55% applied with linux-kernel (498 of 900), 60% without
  (185 of 309). The counts are descriptive, and renamed resubmissions count as not applied.
- **No maintainer's own mail** in the period mentions LKML.
- **The author's earlier, applied MGMT fix** copied it.

**The order:** the kernel patch first. Then the BlueZ test, with the kernel patch's lore link, either the same day
or once the fix is in bluetooth-next. The second spares the CI a known failure meanwhile.

## 7. How to answer

```text
Kernel patch: send / send after changes / hold
BlueZ test:   send / send after changes / hold
Errors (false, overclaimed, or a maintainer would reject): ...
Section 2 changes: each acceptable / not, and why
linux-kernel: copy / don't, and why
Preferences (not blocking): ...
Checked myself / taken from this document: ...
```
