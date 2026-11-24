# One Linux Bluetooth fix and its BlueZ test — request for an independent review before sending (2026-11-24)

## What this is, and what we ask of you

This document holds one small fix to the Linux kernel's Bluetooth management interface (MGMT) and
the BlueZ test that goes with it. **Neither has been sent.** We want both to reach the
linux-bluetooth list at the highest standard we can manage, and we ask for your independent
opinion before they go.

Everything you need is in this file. You need no repository, and nothing here links to one. Both
patches are copied verbatim from the files that would be sent; the SHA-256 under each identifies
the exact file.

**Please answer:**
1. **Verdict, for each patch:** send as is · send after the changes you list · hold (and why).
2. **Correctness:** is the one-line change right? Is any case missed: the mesh instance, the reply
   buffer, other callers?
3. **The kernel message:** does it claim only what the evidence shows? Is anything missing that a
   maintainer would ask for, or anything there they would see as noise?
4. **Trailers and route:** `Fixes:`, `Cc: stable`, the subject, the recipients, and the order of the
   two sends.
5. **The test:** is it the right test, the right size, and correct for BlueZ's tester?
6. **Testing:** is what was run enough for this change? What would you want added first?

The specific questions are in section 7. A short answer is welcome, and "send as is" with no
comment is a useful answer too. Please mark what you checked yourself and what you take from this
document.

## 1. Facts you can take as given

- **The author** is Iaroslav Voitovych. He sends both patches himself.
- **Sign-off:** as packaged, the kernel patch carries **no `Signed-off-by:`**. He adds his own at
  send time, after the last trailer; please do not flag its absence. The BlueZ patch carries none,
  by BlueZ's rule (`bluez.git` commits do not contain one).
- **He has one earlier Bluetooth commit in the kernel:** an MGMT status fix applied in September
  2026, with `Cc: stable`.
- **Today's tips, read on 2026-11-24:**
  - bluetooth-next `ffb95458a0f7`;
  - mainline `v7.4-rc4`;
  - BlueZ master `1608f8361886`.

  The kernel patch applies to today's bluetooth-next, and the BlueZ patch to today's BlueZ master.
  Both were checked with `git apply --check` against an index of the tip. Neither file has changed
  upstream since the patches were made: `net/bluetooth/mgmt.c` has no new commit since
  `5063a0717aa2`, and `tools/mgmt-tester.c` none since `1608f8361`.
- **Patch-ids** (`git patch-id --stable`):
  - kernel: `a15c80fa459bcaf1a3fa84e9aa447ae1372f8444`;
  - BlueZ: `70a4873086000186e05d1bbe88d65a75bc3b9e18`.
- **checkpatch** (`--strict`) is clean on the kernel patch.

## 2. The defect

`read_adv_features()` in `net/bluetooth/mgmt.c` answers MGMT Read Advertising Features. It lists
the advertising instances user space may see. As on bluetooth-next `ffb95458a0f7`:

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

- **The intent:** the comment says it, and the mesh code agrees. Mesh sending uses the one
  internal instance numbered one past the controller's sets
  (`u8 instance = hdev->le_num_of_adv_sets + 1;`, `mgmt.c:2446`). That is the one instance to hide.
- **What it does instead:** it compares each instance's **number** with the **count** of instances
  (`adv_instance_cnt`). Any instance numbered higher than the current count drops out of the reply.
- **An example:** add instances 1 and 2, then remove instance 1, for example when its duration
  ends. Instance 2 is still being advertised, but `2 <= 1` is false, so the reply lists no
  instance, and no Advertising Removed event tells user space why.
- **The simplest reproduction:** add only instance 2. The count is 1, so the reply lists none.
- **The buffer** is sized for all instances (`adv_instance_cnt` bytes). The fix can only make the
  list longer up to that count, never past it, because each listed instance is one of the counted
  ones.
- **A user-space consequence, not shown by a test:** at start-up bluetoothd clears leftover
  instances only `if (feat->num_instances)` (BlueZ `src/advertising.c:2043`). A lone hidden
  instance would survive a bluetoothd restart. The message does not claim this.
- **Origin:** `b338d91703fa` ("Bluetooth: Implement support for Mesh", 2022-09-01, the v6.1 merge
  window).
- **Affected stable lines:** the commit is in stable 7.3, 6.18, 6.12, 6.6 and 6.1; it is not in
  5.15 or 5.10.
- **How it was found:** with mgmt-tester, while writing tests for advertising instance durations.

## 3. The kernel patch, verbatim

From the file that would be sent. The two lines above `Subject:` (the `git format-patch` "From
<hash>" line, and `From:` with the author's address) are left out here.

File SHA-256: `f91db7b314b7c3fd4aa121d5c5d125bbe4a01ea0a11ee08864161ded96dc9041`

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
but no longer reported, and no Advertising Removed event says so.

Compare with le_num_of_adv_sets, as the comment says.

This was found with mgmt-tester while testing advertising instances,
and reproduced in QEMU with a new mgmt-tester case that adds only
instance 2: without this patch the reply lists no instance.

Fixes: b338d91703fa ("Bluetooth: Implement support for Mesh")
Cc: stable@vger.kernel.org
---
Tested in QEMU with a new mgmt-tester case, "Read Advertising
Features - Success 3 (Instance 2 only)", sent to BlueZ separately: it
adds only instance 2 and expects exactly that instance in the reply.
With this patch alone the case passes 3 of 3 runs and without it
fails 3 of 3, on bluetooth-next 5063a0717aa2, v7.4-rc4, 7.3.6,
6.18.65, 6.12.119, 6.6.163 and 6.1.193. In the ten testers of the
Bluetooth kernel CI, no other case changed on any of these kernels.

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

## 4. The BlueZ test, verbatim

Also from the file that would be sent, with the same two lines above `Subject:` left out.

File SHA-256: `55783ea0c443bddc06413e87f4720e2664593e868f982615c83eee00621375f7`

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

**Notes on the test:**
- **The expected reply** is the existing "Read Advertising Features - Success 2" reply with one
  byte changed, the instance identifier, from `0x01` to `0x02`. The emulated controller offers 5
  advertising sets, hence `max_instances` `0x05`.
- **The refactor:** `setup_add_advertising()` becomes a wrapper around a new
  `add_advertising_instance(instance)`. Every existing caller still adds instance 1, as before.
- **Subject length:** 47 characters, within BlueZ's 50.
- **The tester log line:** it now prints the instance number ("Adding advertising instance 1 while
  powered"). That is the only change visible to existing tests.

## 5. How it was tested

- **The environment:** QEMU/KVM guests on 4 vCPUs, with KASAN and lockdep, and BlueZ's tester
  programs on emulated controllers. The kernels were built from BlueZ's `doc/tester.config`.
- **One BlueZ build for every run:** BlueZ master `1adfe662efef` plus the two test patches (this one
  and a test for a separate MGMT fix).
- **Differential method:**
  - For each kernel, three images: the base, base plus this patch alone, and base plus the other
    MGMT fix alone.
  - The images ran the ten testers that the linux-bluetooth CI uses (l2cap, iso, bnep, mgmt,
    rfcomm, sco, ioctl, mesh, smp, userchan), and the results were compared per case name.
  - The new case ran 3 times on each image.
- **Results:**

  | kernel | new case, base | new case, with the patch | other mgmt-tester cases changed | other testers changed |
  |---|---|---|---|---|
  | bluetooth-next `5063a0717aa2` | failed 3 of 3 | passed 3 of 3 | none | none |
  | mainline v7.4-rc4 | failed 3 of 3 | passed 3 of 3 | none | none |
  | stable 7.3.6 | failed 3 of 3 | passed 3 of 3 | none | none |
  | stable 6.18.65 | failed 3 of 3 | passed 3 of 3 | none | none |
  | stable 6.12.119 | failed 3 of 3 | passed 3 of 3 | none | none |
  | stable 6.6.163 | failed 3 of 3 | passed 3 of 3 | none | none |
  | stable 6.1.193 | failed 3 of 3 | passed 3 of 3 | none | none |

- **Pre-existing problems on the older lines,** identical with and without the patch:
  - l2cap-tester hangs in "L2CAP Ext-Flowctl Server - Accept 2 Close 1" on 6.18, 6.12 and 6.6. 7.3.6
    carries the upstream fix.
  - iso-tester hangs in "ISO Broadcaster Receiver Defer Get BASE - Success" on 6.12.
  - 6.1.193 shows two KASAN use-after-free reports (in iso-tester and sco-tester) and a lockdep
    warning.

  No kernel report differs between base and patched on any kernel.
- **Not done:**
  - the eleventh CI tester, 6lowpan-tester;
  - any run on real hardware. The author's controller (a QCA9377) is not needed to show this
    defect;
  - a test of the bluetoothd restart consequence (section 2).

## 6. What changed after an earlier review round (2026-11-23)

Five outside reviewers read an earlier version. None found a defect in the kernel diff. Changes
since:
- **The BlueZ test** was rewritten from 388 added lines to the 30-odd above. The old test coupled
  the listing bug to advertising-duration timing (50 ms early, 1000 ms late, a fixed 2.5 s check),
  and its membership check allowed extra entries. Four of five reviewers asked for a small,
  timing-free test with an exact expected reply.
- **`Cc: stable`** was added (four of five for it).
- **The kernel body** gained the sentence on how the bug was found and reproduced. The kernel's
  networking process document (`maintainer-netdev.rst`) asks bug fixes to say so, and accepted
  Bluetooth commits do it in the body.
- **The tests were rerun** on every current tree after all of them moved on 2026-11-23, with one
  image per patch.

## 7. Specific questions

1. **`Cc: stable`.** The change makes a hidden, still-advertising instance visible to user space.
   Is that a fix the stable rules want? Could any user space depend on the old, wrong reply? The
   precedent we know of: another MGMT reply correction, for address types, was reverted from
   stable after it broke bluetoothd. That change was different in kind.
2. **The restart consequence.** Should the message mention that bluetoothd's start-up clean-up
   skips a lone hidden instance, though no test shows it? Or is it better left out?
3. **The example in the message** ("for example after its timeout"). Is it clear and accurate, or
   would the plain "add only instance 2" case be the better example?
4. **Recipients.** `get_maintainer.pl` gives Marcel Holtmann, Luiz Augusto von Dentz,
   linux-bluetooth and linux-kernel, and also Brian Gix, the author of the commit in `Fixes:`, at an
   Intel address. The plan is To linux-bluetooth and Cc the two maintainers. Should Brian Gix and
   linux-kernel be copied as well?
5. **The order and the link.** The plan is to send the kernel patch first, then the BlueZ test the
   same day, once the kernel patch's lore link exists.
   - Should the BlueZ message carry that link, or only the kernel patch's title, as now?
   - Should the kernel message mention the test?
   - Is a BlueZ test for an unapplied kernel fix acceptable? The kernel CI runs mgmt-tester from
     BlueZ master, so until the fix lands the new case fails there for everyone.
6. **The BlueZ refactor.** Is wrapping `setup_add_advertising()` acceptable, or would the BlueZ
   maintainers prefer a separate setup function that duplicates the body?
7. **Anything else** a linux-bluetooth maintainer would want before applying this.

## 8. How to answer

Any form is fine. This layout helps:

```text
Kernel patch: <verdict>
BlueZ test:   <verdict>
Must change:  <list, or "nothing">
Should change: <list>
Answers to section 7: 1. ... 2. ...
What I checked myself: ...
```
