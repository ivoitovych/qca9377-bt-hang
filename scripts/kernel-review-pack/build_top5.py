#!/usr/bin/env python3
"""Build the self-contained review document for the five most ready kernel submissions.

    python3 -I scripts/kernel-review-pack/build_top5.py <output.md>

For outside reviewers who do not know this repository: the document names no repository path
and links to nothing of ours. Every patch and mail is copied verbatim, with its SHA-256, so the
reviewed text is the text that would be sent. The context is written here. Rerun after any
package is regenerated.
"""
import hashlib
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parents[2]
C = "contributions/"
E = C + "CO-43-btusb-runtime-resume-failure/send-20261113/E/0001-Bluetooth-btusb-Anchor-a-deferred-URB-under-txlock.patch"
K44 = C + "CO-44-mgmt-timeout-reported-as-auth-failed/send-20261113/kernel/0001-Bluetooth-MGMT-Report-a-timed-out-command-as-MGMT_ST.patch"
B44 = C + "CO-44-mgmt-timeout-reported-as-auth-failed/send-20261113/bluez/0001-mgmt-tester-Add-Set-Device-Class-timeout-test.patch"
K38 = C + "CO-38-read-adv-features-hidden-instances/send-20261114/patch/0001-Bluetooth-MGMT-Fix-Read-Advertising-Features-hiding-.patch"
B38 = C + "CO-38-read-adv-features-hidden-instances/bluez-split-20261114/series-a/0001-mgmt-tester-Add-test-for-listing-a-remaining-instanc.patch"
M22 = C + "research-2026-11-01/qca-ids/refresh-20261114/mail/stable-request-asus-rome-v3.eml"
P24 = C + "CO-43-btusb-runtime-resume-failure/send-bt24-bt25-20261114/"
P24C = P24 + "0000-cover-letter.patch"
P241 = P24 + "0001-Bluetooth-btusb-Drop-deferred-URBs-under-txlock-on-a.patch"
P242 = P24 + "0002-Bluetooth-btusb-Free-the-skb-of-a-deferred-URB-that-.patch"

INTRO = """# Five Linux Bluetooth kernel submissions — request for an independent review before sending (2026-11-22)

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
"""

ITEMS = [
    ("1. btusb: anchor a deferred URB under txlock", """
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
""", [(E, "diff", "the patch, as it would be mailed")]),

    ("2. MGMT: a timed-out command reported as Authentication Failed", """
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
""", [(K44, "diff", "the kernel patch, as it would be mailed"),
      (B44, "diff", "the BlueZ test, as it would be mailed (second, the same day)")]),

    ("3. MGMT: Read Advertising Features hides instances", """
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
""", [(K38, "diff", "the kernel patch, as it would be mailed"),
      (B38, "diff", "the BlueZ test, as it would be mailed")]),

    ("4. Stable request: two ASUS QCA ROME device IDs", """
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
""", [(M22, "text", "the request mail (v3, before the date refresh)")]),

    ("5. btusb: deferred URBs that a failed resume or a close discards (a two-patch series on item 1)", """
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
""", [(P24C, "diff", "the cover letter"), (P241, "diff", "patch 1/2"), (P242, "diff", "patch 2/2")]),
]

OUTRO = """
## After your answers

Nothing is sent before the author has read every answer. Each point is checked against the source
and the test logs and recorded with what was done about it. Then, on the send day:
- the author adds his `Signed-off-by:`;
- the trees are re-fetched, and apply and build re-run;
- a `git send-email` dry run is checked;
- the author sends each mail himself.

Thank you for your time.
"""


def fence(text):
    n = 3
    while "`" * n in text:
        n += 1
    return "`" * n


def embed(rel, lang, label, num):
    data = (ROOT / rel).read_bytes()
    text = data.decode("utf-8")
    f = fence(text)
    name = pathlib.Path(rel).name
    return (f"**File {num} — {label}** (`{name}`, SHA-256 `{hashlib.sha256(data).hexdigest()}`)\n\n"
            f"{f}{lang}\n{text}{'' if text.endswith(chr(10)) else chr(10)}{f}\n\n")


def main():
    if len(sys.argv) != 2:
        print(__doc__, file=sys.stderr)
        return 2
    parts = [INTRO]
    for i, (title, body, files) in enumerate(ITEMS, 1):
        parts.append(f"## {title}\n{body}\n")
        for j, (rel, lang, label) in enumerate(files, 1):
            parts.append(embed(rel, lang, label, f"{i}.{j}"))
        parts.append("---\n")
    parts.append(OUTRO)
    out = "".join(parts)
    for leak in ("contributions/", "github.com", "qca9377-bt-hang", "OPERATOR", "dossier"):
        assert leak not in out, f"a repository path, link or internal name leaked: {leak}"
    pathlib.Path(sys.argv[1]).write_text(out)
    return 0


if __name__ == "__main__":
    sys.exit(main())
