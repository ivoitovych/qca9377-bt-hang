#!/usr/bin/env python3
"""Assemble the self-contained review document of the kernel patches that are ready to send.

    python3 -I scripts/kernel-review-pack/build.py <output.md>

Every patch, mail and result file is copied verbatim from the repository path it is listed
under, with that file's SHA-256, so the reviewed text is the text that would be sent. The
context paragraphs are written here; the files are not touched. Rerun after any package is
regenerated: the document then follows the files.
"""
import hashlib
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parents[2]
HERE = pathlib.Path(__file__).resolve().parent

C44 = "contributions/CO-44-mgmt-timeout-reported-as-auth-failed/send-20261113"
C43 = "contributions/CO-43-btusb-runtime-resume-failure/send-20261113"
C38R = "contributions/CO-38-read-adv-features-hidden-instances/send-20261114"
C38 = C38R + "/patch"
C04R = "contributions/CO-04-mesh-test-14888791/send-20261114"
C04 = C04R + "/patch"
C05 = "contributions/CO-05-mesh-adv-list-lock-i12/send-20261114/patch"
C35 = "contributions/CO-35-l2cap-ecred-defer-hang-stable/send-20261114/mail"
C35R = "contributions/CO-35-l2cap-ecred-defer-hang-stable/send-20261114"
C22R = "contributions/research-2026-11-01/qca-ids/refresh-20261114"
C21 = "contributions/CO-21-btusb-sco-alt-setting/send-20261114"
C20 = "contributions/CO-20-sco-unknown-handle-messages/send-20261114"
C43S = "contributions/CO-43-btusb-runtime-resume-failure/send-series-20261114"

SECTIONS = [
    ("1. CO-44 — MGMT: a timed-out command reported as Authentication Failed", """
**The defect.** When an HCI command sent from an MGMT handler gets no answer, the sync layer
returns `-ETIMEDOUT`, and `mgmt_errno_status()` has no case for it, so user space is told
`MGMT_STATUS_AUTH_FAILED` (0x05). bluetoothd then prints "Authentication Failed" for a Set
Device Class or a Set Powered that simply timed out; users and maintainers read it as a pairing
problem. The table for HCI statuses already maps the controller's own timeouts (0x08, 0x10) to
`MGMT_STATUS_TIMEOUT`, and a timed-out pairing connection already reports 0x08; the patch makes
`-ETIMEDOUT` agree. `Fixes: 161510ccf91c`.

**Tested** (bluetooth-next `da3cc02587c6`, BlueZ master): a new mgmt-tester case drops the Write
Class of Device command and expects Timeout; on the base kernel it gets 0x05 and fails, patched it
passes. Full mgmt-tester 526 + the new case: only that case changes; l2cap-tester 144/144 and
smp-tester 8/8 on both kernels. The bot's checks locally: only the three Signed-off-by checks
differ. The BlueZ test is a separate mail to BlueZ the same day; it is reproduced after the kernel
patch for context.

**Questions for you.** `Cc: stable` or not (the maintainer took two MGMT status fixes with it in
the last months; the last two changes to this function went in without it). Whether the `Link:`
to a 2022 BlueZ posting that names the symptom is useful or noise. Subject wording.
""", [
        (f"{C44}/kernel/0001-Bluetooth-MGMT-Report-a-timed-out-command-as-MGMT_ST.patch", "diff"),
        (f"{C44}/cc-stable-variant.txt", "text"),
        (f"{C44}/bluez/0001-mgmt-tester-Add-Set-Device-Class-timeout-test.patch", "diff"),
        (f"{C44}/CHECKS.md", "markdown"),
    ]),
    ("2. CO-43 E — btusb: anchor a deferred URB under `txlock`", """
**The defect** (present since `7bee549e197c`, 2009). `submit_or_queue_tx_urb()` decides under
`data->txlock` that the device is suspending and the URB must be deferred, drops the lock, and only
then anchors the URB on `data->deferred`. A resume that runs `play_deferred()` in that window
does not see it: the URB stays parked until the next suspend/resume cycle, and the HCI command in
it times out. The patch anchors it before the lock is dropped.

**Tested** (bluetooth-next `da3cc02587c6`): with a debug-only delay that widens the window and a
resume forced inside it, the unpatched kernel parked the command and timed out 3 of 3; with the
patch it was answered. Without the delay, 10 runs of 100 suspend/resume cycles on each kernel,
KASAN, lockdep and kmemleak on: no report and no parked packet on either. The bot's checks: only
the Signed-off-by checks fail. It applies and builds alone and together with item 3 in either
order.

**Questions for you.** The lock order and the teardown cases (disconnect while URBs are
deferred). `Cc: stable` or not: the hang was reproduced only with the window widened, and nobody
has reported it in the field.
""", [
        (f"{C43}/E/0001-Bluetooth-btusb-Anchor-a-deferred-URB-under-txlock.patch", "diff"),
        (f"{C43}/E/CHECKS.md", "markdown"),
    ]),
    ("3. CO-43 A — btusb: report a failed runtime resume for deferred data", """
**The defect.** `btusb_waker()` calls `usb_autopm_get_interface()` to resume the device for
deferred data and ignores a failure, so a device that does not come back leaves no trace of why
the HCI traffic stalls. The patch logs the failure, except `-EACCES` (runtime PM disabled, for
example during a system sleep transition). No `Fixes:`, no `Cc: stable`: it adds a message only.

**Tested:** in the emulator run where the device fails its resume, the new line appears at the
moment of the failure. The bot's checks: only the Signed-off-by checks fail.

**Questions for you.** Whether the message is worth having upstream at all, and its wording; the
subject ("runtime resume", since the waker's resume is a runtime one).
""", [
        (f"{C43}/A/0001-Bluetooth-btusb-Report-a-failed-runtime-resume-for-d.patch", "diff"),
        (f"{C43}/A/CHECKS.md", "markdown"),
    ]),
    ("4. CO-38 — MGMT: Read Advertising Features hides instances", """
**The defect** (from `b338d91703fa`, 2022; in 6.1.y to bluetooth-next). `read_adv_features()`
skips every instance whose number is above `hdev->adv_instance_cnt`, the count of instances,
instead of the controller's number of sets. After instance 1 is removed, instance 2 is no longer
listed, though it still advertises. Found by the tests of another item (CO-12, the
advertising-duration clamp, not in this document).

**Tested again on today's tip** (bluetooth-next `da3cc02587c6`, 2026-11-14; KASAN and lockdep,
4 CPUs): mgmt-tester's "Add" cases, 3 runs each, 119/128 unpatched → 120/128 patched; the only
change is the new case "Add Ext Advertising - Instance 2 listed alone", Failed → Passed 3 of 3
(the other 8 not-passed are the duration cases of the separate CO-12 fix, failing on both kernels);
mesh-tester 8/10 on both. The bot's kernel checks pass on both sides with identical tester
results. On the BlueZ side the bot's TestFunctional failed 2 of 3 patched runs (two different BAP
cases) and passed 2 of 2 base runs; the series touches only two tester sources, so it looks like a
flake on a loaded host, but that is not shown. A newer patch, "mgmt: drop advertising instances
the controller cannot carry" (patchwork 14976301), fixes a different bug.
""", [
        (f"{C38}/0001-Bluetooth-MGMT-Fix-Read-Advertising-Features-hiding-.patch", "diff"),
        (f"{C38}/bluez/0000-cover-letter.patch", "diff"),
        (f"{C38}/bluez/0001-mgmt-tester-Add-extended-advertising-timeout-tests.patch", "diff"),
        (f"{C38}/bluez/0002-mgmt-tester-Add-test-for-listing-a-remaining-instanc.patch", "diff"),
        (f"{C38}/bluez/0003-mesh-tester-Add-Mesh-Send-test-with-extended-adverti.patch", "diff"),
        (f"{C38R}/CHECKS.md", "markdown"),
    ]),
    ("5. CO-04 — MGMT: a use-after-free in `mesh_send_sync()`", """
**The defect** (a syzbot report; `Fixes: b338d91703fa`, `Cc: stable`). `mesh_send()` tests
`HCI_MESH_SENDING` under `hdev->lock`, but the completion paths clear it without the lock before
`mesh_next()` queues the next start, so a Mesh Send in between can queue a second start for the
same request; if the first start fails and frees it, the second reads freed memory (the patch's
message has the KASAN trace). The patch keeps the flag set until the next-or-idle decision is made
under `hdev->lock`, and takes `hdev->lock` nowhere under `cmd_sync_work_lock`.

**Tested again on today's tip** (bluetooth-next `da3cc02587c6`, 2026-11-14; the code is unchanged
since 10-29): mesh tests (power 12, unregister 12, cancel 5, close 5, an unregister sweep 35 boots
per image), no KASAN, BUG or hung-task report, verdicts unchanged; the bot's checks pass
(mgmt-tester 526/526, mesh-tester 10/10). The use-after-free itself was not reproduced. **New on
the tip:** in the unregister sweep, lockdep reports a circular dependency between
`cmd_sync_work_lock` and `unregister_lock` (`hci_cmd_sync_clear()` runs `mesh_next()`, the destroy
callback of `mesh_send_done_sync()`, which calls `hci_cmd_sync_submit()`), 2 of 35 boots
unpatched and 0 of 35 with this patch, which removes that callback; the notes below `---` say so.
A different fix for the same report is pending on the list (patchwork 14888791, now archived); in
earlier boots it showed a lock-order inversion in 8 of 12.

**Questions for you.** Whether the hand-over closes every path the syzbot trace shows; whether the
lockdep finding belongs in the commit message rather than below the `---`; whether "not
reproduced" needs saying.
""", [
        (f"{C04}/0001-Bluetooth-MGMT-Fix-use-after-free-in-mesh_send_sync.patch", "diff"),
        (f"{C04R}/CHECKS.md", "markdown"),
    ]),
    ("6. CO-05 + CO-26 — `mesh_send_sync()` and the advertising list", """
**The defects.** (1) `mesh_send_sync()` adds and removes an advertising instance without
`hdev->lock`, while other paths walk the list under it (lockdep and KCSAN warnings). (2) When the
add fails, it loses the error and schedules an instance that does not exist (`Fixes:
b338d91703fa`).

**Tested again on today's tip** (bluetooth-next `da3cc02587c6`, 2026-11-14; code unchanged since
10-29): with a test-only lock assertion, mesh-tester's warnings 3 per boot → 0; the fault
injection for (2): unpatched schedules the never-added instance, patched returns the add's error
and schedules nothing; KCSAN, 45 boots per image, showed no report in advertising or mesh code on
any kernel this time (on 10-29 the unpatched kernel had some), so there is no KCSAN before/after
today; the bot's checks pass. Another author's patch (patchwork 14927631) also takes `hdev->lock`
in `mesh_send_sync()`, among many other changes; it no longer applies to bluetooth-next.

**Questions for you.** The series order relative to item 5 (they touch the same function, and
apply in either order), and whether patch 2 belongs in the same series or alone.
""", [
        (f"{C05}/0000-cover-letter.patch", "diff"),
        (f"{C05}/0001-Bluetooth-MGMT-Take-hdev-lock-in-mesh_send_sync.patch", "diff"),
        (f"{C05}/0002-Bluetooth-MGMT-Stop-mesh_send_sync-when-it-cannot-ad.patch", "diff"),
    ]),
    ("7. CO-35 — the L2CAP ECRED deferred-accept hang, for stable", """
**The defect.** With a deferred ECRED accept, the socket lock is taken twice on the same path, a
self-deadlock present since v6.3 (`9aa9d9473f15`). Pauli Virtanen fixed it in mainline with
`608e0b7a675b` and `32d86e048d8e` (7.4 merge window), without `Cc: stable`; neither is in a stable
release or queue (checked 2026-11-14).

**This package:** a request that 7.3.y take the two commits as they are; backports of the pair for
6.18.y, 6.12.y and 6.6.y as `[PATCH <line> 0/2]` series (code changed only where the older trees
need it); and a separate request for 7.3.y to take `5874f8d03268`, without which plain v7.3 fails
l2cap-tester's SCI cases for an unrelated reason (7.3.4 still lacks it). **Tested again on today's
tips** (2026-11-14, QEMU, 4 CPUs, hung-task detector): "L2CAP Ext-Flowctl Server - Accept 2 Close
1" hangs on unpatched v7.3.4, v6.18.63, v6.12.117 and v6.6.162 (7 hung-task reports each) and
passes with the pair (1.0 to 1.2 s); the whole l2cap-tester with the pair: 7.3.4 111/111 with the
SCI fix, and on the older lines the same non-passes as on 11-02 (18 "Set PHY" cases on 6.18.y;
32 on 6.12.y and 6.6.y). An unpatched full run cannot finish there (it hangs), so that these are
not the pair's rests on the pooled case verdicts of 11-01. No lockdep, KASAN or hung-task report
patched. The
backports are byte-identical to the 11-02 ones; only the covers' release numbers changed. 6.1.y,
5.15.y and 5.10.y also carry the bug and are not covered (patch 2 conflicts there).

**Questions for you.** The backports' changes against the mainline commits (the cover letters
list them); whether the two requests should be one mail.
""", [
        (f"{C35}/request-v4-20261114.eml", "text"),
        (f"{C35}/request-sci-7.3.y-20261114.eml", "text"),
        (f"{C35}/6.18.y/0000-cover-letter-20261114.patch", "diff"),
        (f"{C35}/6.18.y/0001-Bluetooth-L2CAP-add-l2cap_chan_close_unlocked-and-lo.patch", "diff"),
        (f"{C35}/6.18.y/0002-Bluetooth-L2CAP-hold-conn-lock-for-__l2cap_ecred_con.patch", "diff"),
        (f"{C35}/6.12.y/0000-cover-letter-20261114.patch", "diff"),
        (f"{C35}/6.12.y/0001-Bluetooth-L2CAP-add-l2cap_chan_close_unlocked-and-lo.patch", "diff"),
        (f"{C35}/6.12.y/0002-Bluetooth-L2CAP-hold-conn-lock-for-__l2cap_ecred_con.patch", "diff"),
        (f"{C35}/6.6.y/0000-cover-letter-20261114.patch", "diff"),
        (f"{C35}/6.6.y/0001-Bluetooth-L2CAP-add-l2cap_chan_close_unlocked-and-lo.patch", "diff"),
        (f"{C35}/6.6.y/0002-Bluetooth-L2CAP-hold-conn-lock-for-__l2cap_ecred_con.patch", "diff"),
        (f"{C35R}/CHECKS.md", "markdown"),
    ]),
    ("8. CO-22 — two ASUS QCA ROME entries for stable (a request, no patch)", """
**The request.** Mainline has two btusb device-table entries for ASUS laptops with a QCA ROME
controller, `d54601f21faf` and `cfa67a1dbfd9`; no stable branch has them (checked 2026-11-14).
Without an entry btusb does no QCA setup, so the controller keeps its ROM firmware; that was the
condition under which this project's own QCA9377 hung on wideband-speech calls until its entry
(`dc16388d45ec`) reached stable. Whether these two models show the same hang is not known. On
today's tips (2026-11-14) both cherry-pick cleanly to 7.3.4, 6.18.63, 6.12.117, 6.6.162, 6.1.192,
5.15.225 and 5.10.274 (into `btusb.c`: git follows mainline's 7.4 rename), and `btusb.o` builds
with the same W=1 warnings as unpatched (none, except 6.6.y's known `btmtk.h` ones, present
unpatched too). The mail asks the stable team to take them; it names the entries' authors in Cc.
A related new ID patch posted on 2026-11-12 (0cf3:e303) is not mentioned: it is not merged and
carries its own `Cc: stable`.

**Questions for you.** Whether the request reads as justified for device-ID additions (which
stable rules allow), and its wording.
""", [
        (f"{C22R}/mail/stable-request-asus-rome-v3.eml", "text"),
        (f"{C22R}/CHECKS.md", "markdown"),
    ]),
    ("9. CO-21 — btusb picks alternate setting 0 while a SCO link is up", """
**The defect** (`Fixes: baac6276c0a9`). `btusb_notify()` takes the air mode from the one link
whose state changed and picks the USB alternate setting from it. With two SCO links, one going
down switches the other to alt 0, and a single-link race does the same (seen twice on the laptop,
2026-09-02). **The design** (two patches, now on bluetooth-next `da3cc02587c6`): the core keeps the air
mode of each SCO link that came up (from its Synchronous Connection Complete event), and btusb's
worker derives the setting from the links that are up; notify only schedules it. An earlier
single-patch candidate was judged not ready by an outside review (a failed second setup still
sends the link-up notification); this design answers that.

**Tested** (2026-11-14, on the rebased pair): real btusb in a QEMU guest against an emulated
controller through usbip, five scenarios (two links, either one going down first; mSBC and CVSD;
the single-link race), two runs each: unpatched 0 of 10, patched 10 of 10; a 20-scenario model of
the worker (11-01). The bot's checks: builds and all 11 testers pass, tester results identical to
the base side; only the three Signed-off-by checks fail. Patch 2's subject is now 65 characters.
Patch 1 changes `struct hci_conn`, so `bluetooth.ko` and btusb must be rebuilt together.

**Questions for you.** The design itself: is a per-link air mode in the core acceptable, or should
btusb track it alone? The counting helper's locking. `Cc: stable`: patch 2 cannot build without
patch 1, so a stable tag would have to cover both.
""", [
        (f"{C21}/cover-letter.txt", "text"),
        (f"{C21}/0001-Bluetooth-Keep-the-air-mode-of-SCO-links-that-came-u.patch", "diff"),
        (f"{C21}/0002-Bluetooth-btusb-Pick-the-SCO-alt-setting-from-links-.patch", "diff"),
        (f"{C21}/CHECKS.md", "markdown"),
    ]),
    ("10. CO-20 — btusb logs the data of a just-closed SCO link as corruption", """
**The defect.** After a SCO link's Disconnection Complete, the controller can still deliver a few
packets for its handle. btusb drops them, but logs "corrupted SCO packet" and counts them in
`err_rx`, the same message and counter as real corruption and allocation failure, so every hung-up
call looks like a link error (on the laptop, 25 of 32 such lines fell within 0.5 s of a
disconnect). Patch 1 reports receive failures by cause; patch 2 logs data for a just-closed link at
debug level and does not count it as an error. No `Fixes:`. Mainline's separate newline fix for the
same message is `f51ee3bb5fbe`.

**Tested** (2026-11-14, real btusb in a QEMU guest, emulated controller): 20 calls hung up with
data in flight, 3 runs: unpatched 17, 19 and 24 "corrupted SCO packet" lines, patched none (the
residue at debug level). Five packets for a handle that never was a link: unpatched counted as
corrupted, patched reported as an unknown handle and not as corrupted. Limitation (in patch 2's
message): with two links up, data of the closed link that follows a packet of the remaining one is
still reported. The bot's checks: only the Signed-off-by checks fail; it selects no tester for a
btusb-only change.

**Questions for you.** Whether the classification belongs in btusb or in the core's SCO receive
path; whether the debug-level line is worth keeping at all.
""", [
        (f"{C20}/cover-letter.txt", "text"),
        (f"{C20}/0001-Bluetooth-btusb-Report-SCO-receive-failures-by-cause.patch", "diff"),
        (f"{C20}/0002-Bluetooth-btusb-Log-SCO-data-for-a-just-closed-link-.patch", "diff"),
        (f"{C20}/CHECKS.md", "markdown"),
    ]),
    ("11. CO-43, the rest (for review, not yet to send) — btusb when a resume fails", """
**What it is.** The other btusb fixes from BT-17's emulation, as one series on top of item 2 (E):
A (item 3), then B2 (the HCI command timeout no longer waits 5 s on a resume that never comes,
and still resets a wedged controller), D v2 (after a runtime reset-resume, queue a reset so btusb
is rebound; BT-18), BT-24's fix (a failed resume drops the deferred URBs under `txlock`) and BT-25's
fix (the skb of a dropped deferred URB is freed). B2 needs D: alone it leaves a recovering device
dead.

**Tested** (QEMU, emulated `13d3:3503` that fails its resume): with the whole series, the runtime
matrix (dead device, recovering device, power-off-started resume, dropped command, wedged
controller, 30 healthy cycles; 3 runs each) 18 of 18; unpatched, the recovering-after-power-off
case is dead 3 of 3 and the dead device blocks the HCI workqueue for 5.4 s. BT-25: kmemleak finds
leaked HCI command skbs in 11 of 12 fault runs without the fix, none with it. **Not tested:** the
system-suspend path, which `vhci_hcd` cannot exercise; D v2 queues its reset only inside a runtime
resume, and that the system path is unchanged rests on reading `drivers/usb/core/driver.c`.

**Questions for you.** D v2's `RPM_RESUMING` test as the way to tell a runtime reset-resume from a
system one; whether D belongs in btusb at all, or BT-18 is the USB core's to fix (a question to
linux-usb is drafted); B2's handling of the command credit.
""", [
        (f"{C43S}/0000-cover-letter.patch", "diff"),
        (f"{C43S}/0002-Bluetooth-btusb-Don-t-wait-for-a-resume-in-the-HCI-c.patch", "diff"),
        (f"{C43S}/0003-Bluetooth-btusb-Recover-after-a-runtime-reset-resume.patch", "diff"),
        (f"{C43S}/0004-Bluetooth-btusb-Drop-deferred-URBs-under-txlock-on-a.patch", "diff"),
        (f"{C43S}/0005-Bluetooth-btusb-Free-the-skb-of-a-deferred-URB-that-.patch", "diff"),
    ]),
]


def fence(text: str) -> str:
    """A backtick fence longer than any backtick run in the text."""
    longest = max((len(m) for m in re.findall(r"`+", text)), default=0)
    return "`" * max(3, longest + 1)


def block(rel: str, lang: str) -> str:
    path = ROOT / rel
    data = path.read_bytes()
    text = data.decode("utf-8")
    f = fence(text)
    digest = hashlib.sha256(data).hexdigest()
    body = text if text.endswith("\n") else text + "\n"
    return f"**`{rel}`** (SHA-256 `{digest}`)\n\n{f}{lang}\n{body}{f}\n"


def main() -> int:
    if len(sys.argv) != 2:
        print(__doc__.strip(), file=sys.stderr)
        return 2
    parts = [(HERE / "intro.md").read_text()]
    for title, context, files in SECTIONS:
        parts.append(f"\n---\n\n## {title}\n{context}")
        for rel, lang in files:
            parts.append("\n" + block(rel, lang))
    parts.append("\n---\n\n*End of document. Repository: "
                 "<https://github.com/ivoitovych/qca9377-bt-hang>; every file above is at "
                 "the path given, in the commit that added this document.*\n")
    pathlib.Path(sys.argv[1]).write_text("".join(parts))
    return 0


if __name__ == "__main__":
    sys.exit(main())
