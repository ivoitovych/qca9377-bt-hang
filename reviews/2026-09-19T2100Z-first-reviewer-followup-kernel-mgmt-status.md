# The first reviewer's follow-up on the kernel finding — 2026-09-19T21:00Z

*(Kept on the branch `kernel/mgmt-flush-status` with the finding it discusses until
2026-10-09, when it was ported to `main`.)*

**Source.** The first independent reviewer of the BlueZ patches
(`2026-09-18T0700Z-third-party-bluez-patch-review.md`), shown the kernel-side finding by the
operator, verified it against public kernel source and replied. Reproduced verbatim below.

**What it settles and what it adds.**

- **Confirms the mechanism from the source alone**, independently of the capture: the
  fallback in `cmd_complete_rsp()` reads byte 0 of `struct cmd_lookup`, which is `match.sk`,
  NULL in `__mgmt_power_off()`, so the status sent is `0x00`. Names the same introducing
  commit, `f53e1c9c726d`, and the same one-expression fix. States the evidentiary
  distinction correctly: the kernel mechanism and its provenance are verified; the capture
  (`EX-044`) is not publicly available and is taken as reported.
- **Corrects the exposure statement.** "Every kernel since v6.12" was the mainline lineage.
  `f53e1c9c726d` was backported; the reviewer verified the 6.1.120 stable review and current
  6.1. Verified here the same evening against the stable mirror: `v6.1.119` has the correct
  form; `v6.1.120`, `linux-6.1.y`, `linux-6.6.y`, `linux-6.12.y` and `master` carry the
  fault. **Adopted:** the patch now carries `Cc: stable@vger.kernel.org` and a paragraph
  naming the affected trees; `patches/kernel/README.md` has the table.
- **Asks that the message say the data contract changed in `f53e1c9c726d` and the fallback
  did not.** It already does, in the paragraph beginning "commit f53e1c9c726d … changed the
  callers' data from &status to &match … but left the fall-through passing data unchanged."
- **Withdraws the index-fallback hypothesis in full**, agreeing with our verification and
  with the second and third reviewers.
- **Asks for a build against current bluetooth-next and one stable branch before sending.**
  Built here against the running kernel's headers from `v7.0` (patched and unpatched). A
  build against bluetooth-next and a stable branch is not done; recorded as owed in the
  README's status table.
- **Asks that the BlueZ patches not wait** for the kernel patch. Agreed; that is the
  operator's call and the record says so.

```console
$ gh api -H 'Accept: application/vnd.github.raw' 'repos/gregkh/linux/contents/net/bluetooth/mgmt.c?ref=v6.1.119' \
    | grep -n -A14 '^static void cmd_complete_rsp' | grep -E 'u8 \*status = data|cmd_lookup|cmd_status_rsp\(cmd, data\)'
1461-		u8 *status = data;
1469-	cmd_status_rsp(cmd, data);
$ … ?ref=linux-6.1.y …
1446-	struct cmd_lookup *match = data;
1458-	cmd_status_rsp(cmd, data);
$ … ?ref=linux-6.6.y …
1457-	struct cmd_lookup *match = data;
1469-	cmd_status_rsp(cmd, data);
$ … ?ref=linux-6.12.y …
1464-	struct cmd_lookup *match = data;
1476-	cmd_status_rsp(cmd, data);
```

## The follow-up

Reproduced verbatim from the operator's paste of 2026-09-19, except one timing line above the
reply, omitted.

---

You were right to poke me. I was hung up on the search path, but I've now independently checked the important part, and the maintainer's new analysis materially strengthens the case.

The biggest finding is this: the newly identified kernel bug is real, and the mechanism is almost embarrassingly exact. In current Linux net/bluetooth/mgmt.c, __mgmt_power_off() constructs:

struct cmd_lookup match = { NULL, hdev };
...
match.mgmt_status = MGMT_STATUS_NOT_POWERED;
mgmt_pending_foreach(0, hdev, true, cmd_complete_rsp, &match);

cmd_complete_rsp() correctly treats data as struct cmd_lookup * when a command has a cmd_complete callback. But for the fallback case it does:

cmd_status_rsp(cmd, data);

and cmd_status_rsp() does:

u8 *status = data;
mgmt_cmd_status(..., *status);

So it reads byte 0 of struct cmd_lookup, not match.mgmt_status. Byte 0 belongs to match.sk, which was initialized to NULL. Therefore the value read is 0x00, i.e. MGMT_STATUS_SUCCESS. That is exactly capable of generating the anomalous successful Command Status with no reply parameters that kills unpatched BlueZ 0001. Current bluetooth-next still contains this code. 

Even better, I verified the provenance. The mistake was introduced by upstream commit f53e1c9c726d83092167f2226f32bd3b73f26c21, Bluetooth: MGMT: Fix possible crash on mgmt_index_removed, authored September 12, 2024. Before that change, cmd_complete_rsp() received a pointer to an actual u8 status; the commit changed its argument to struct cmd_lookup *match, updated the cmd_complete branch to use match->mgmt_status, but left the fallback as cmd_status_rsp(cmd, data). That is the precise regression. 

So the obvious one-expression repair is indeed:

cmd_status_rsp(cmd, &match->mgmt_status);

and Fixes: f53e1c9c726d ("Bluetooth: MGMT: Fix possible crash on mgmt_index_removed") is the correct provenance.

There is, however, one correction I would make to the maintainer's recap. The statement that the bug is "in every kernel since v6.12" is true about the mainline lineage, but it understates the stable exposure. f53e1c9c726d was backported. I verified the exact faulty transformation in the 6.1.120 stable review, and current 6.1 source still contains the bad fallback. The original fix was also backported into other stable lines around 6.6.55, 6.10.14 and 6.11.3. So the kernel submission should explicitly expect stable backports rather than present this as merely a 6.12+ problem. 

That also changes my interpretation of patch 0001 in a useful way. We now have three layers:

1. The controller/HCI failure or power-down situation initiates the sequence.

2. Linux MGMT corrupts the intended NOT_POWERED completion into a Success Command Status with no payload.

3. BlueZ receives status == SUCCESS, length == 0, param == NULL; with discovery_list == NULL, it dereferences rp->type before its existing length check.

That causal chain is internally coherent all the way from kernel source to the BlueZ fault. The earlier hypothesis from my review about an opcode mismatch/index-only fallback should be considered fully withdrawn. The 0x0023 label error caused it, and the corrected record disposes of it.

The revised 0001 patch message at 000977a is also substantially better. I checked the actual current patch. It now correctly identifies 0x0023 as Start Discovery, identifies the reply as the MGMT_EV_CMD_STATUS path, gives the last-client → send → Command Status → callback → SIGSEGV timeline, and deliberately leaves the kernel cause out of the BlueZ commit message. That last choice is good: the BlueZ patch should stand independently and should not depend on an unsubmitted kernel patch.

I also rechecked 0002. The commit-reference formatting change is appropriate:

commit 125a2e237e7c ("...")
commit 90a600895d80 ("...")

and it doesn't alter the substance of the patch. I see no new objection to 0002.

There is one evidentiary distinction I want to preserve. I have independently verified the kernel source bug and its introducing commit. I have also verified the revised public BlueZ patches. I have not independently examined the maintainer's unpushed local kernel branch, its decoder, or the newly correlated btsnoop evidence, because by definition they are not publicly available to me. So I can say the kernel mechanism fits the reported capture exactly, but I cannot independently attest to the capture itself yet.

My updated technical conclusion is therefore:

BlueZ 0001: ready to submit.

BlueZ 0002: ready to submit.

Keep them independent, as the maintainer proposes.

The kernel patch is a genuine third patch/finding, but it belongs to the Linux Bluetooth kernel tree, not the BlueZ series.

The kernel patch should use Fixes: f53e1c9c726d... and Cc: stable@vger.kernel.org.

Before sending the kernel patch, I would want at least a build of net/bluetooth/ against current bluetooth-next/Linux; ideally also apply/build against one representative stable branch because this regression was backported.

Do not delay the two BlueZ patches waiting for the kernel patch. 0001 fixes a real userspace robustness defect even after the kernel defect is corrected: BlueZ should not dereference a one-byte response structure before establishing that the response contains that byte.

One more interesting consequence: the discovery of the kernel bug actually makes 0001 stronger as an upstream submission, not weaker. It changes the story from "some unexplained kernel/controller condition somehow produced an empty successful response" to "we have a reproducible API-boundary robustness flaw in BlueZ, and we have independently identified an actual Linux MGMT regression capable of producing exactly that malformed semantic combination." The BlueZ fix remains appropriately narrow and does not attempt to compensate for the kernel beyond refusing to crash.

So at this point I agree with the maintainer's proposed direction, with the stable-range correction above: send 0001 and 0002 now; separately finish, compile-test and send the kernel fix.

The kernel finding is significant enough that I would also update the eventual kernel commit message to mention that cmd_complete_rsp() changed its data contract in f53e1c9c726d, but the fallback call was not changed with it. That explains the bug in about three lines and makes the patch almost self-proving.
