# Linux kernel Bluetooth patches ready to send: a self-contained review document

*Prepared 2026-11-14 by the project <https://github.com/ivoitovych/qca9377-bt-hang> (fixes for
the Linux Bluetooth stack found on a laptop with a QCA9377 controller, USB `13d3:3503`). Nothing
in this document has been sent. Every patch is reproduced verbatim from the file named above it,
with that file's SHA-256, so the text you review is the text that would be mailed. Most items carry
no Signed-off-by yet: the author adds it when sending. Item 7's stable backports carry the
author's Signed-off-by from their earlier preparation (with the original authors' and the
maintainer's above it); please ignore that line.*

## A. What we ask of you

You are reviewing as a kernel maintainer would, before the patches reach the list. For each item:

1. **Is the change correct?** Locking, reference counting, error paths, races with teardown
   (device removal, power-off, unregister), and behaviour on other devices than ours.
2. **Is the commit message accurate?** Every claim about the code should hold at the stated base.
   Point at any sentence that overstates what was shown, and at any missing `Fixes:` or a wrong one.
3. **Is the form right for the target tree?** Subject prefix and length, trailers, `Cc: stable`
   (where we ask you to weigh it), the text below `---`, the recipients.
4. **Is anything missing that a maintainer will ask for?** A test, a measurement, a split or a
   merge of patches, a different approach.
5. **Should any of them not be sent?** Say so plainly, with the reason.

Please answer per item, by its number below, and quote the line you mean. A short "no
objection" for an item is a useful answer too.

## B. How the patches were tested

No patch here has been run on the laptop's own controller (the laptop is in daily use, and a
dead controller there needs a power-off). Everything was tested in QEMU guests and containers:

- **The bot's checks, locally.** The linux-bluetooth list runs a CI bot on every posting
  (`github.com/bluez/action-ci`). Its own check code was run here in its own container, on the
  base tree and on base plus the patch, and only the difference was judged. A missing
  Signed-off-by fails three of its checks (CheckPatch, VerifySignedoff, GitLint); that is the
  line the author adds.
- **BlueZ's testers** (`mgmt-tester`, `l2cap-tester`, `smp-tester`, `mesh-tester`, `sco-tester`)
  in QEMU guests built from BlueZ's `doc/tester.config`, on the base and the patched kernel.
- **For btusb:** real btusb in a guest, driven by an emulated `13d3:3503` through usbip
  (`vhci_hcd`), with KASAN, lockdep and kmemleak; for races, 4-CPU guests.

Each item says which of these it had, and where the logs are in the repository.

## C. Contents

| # | item | target | patches |
|---|---|---|---|
| 1 | CO-44: a timed-out MGMT command reported as Authentication Failed | bluetooth-next | 1 (+ its BlueZ test) |
| 2 | CO-43 E: btusb anchors a deferred URB outside `txlock` | bluetooth-next | 1 |
| 3 | CO-43 A: btusb's runtime-resume waker swallows a failed resume | bluetooth-next | 1 |
| 4 | CO-38: Read Advertising Features hides instances | bluetooth-next | 1 (+ BlueZ tests) |
| 5 | CO-04: a use-after-free in `mesh_send_sync()` | bluetooth-next | 1 |
| 6 | CO-05 + CO-26: `mesh_send_sync()` without `hdev->lock`, and a lost failed add | bluetooth-next | 2 + cover letter |
| 7 | CO-35: the L2CAP ECRED deferred-accept hang, backported to stable (retested 2026-11-14) | 6.18.y, 6.12.y, 6.6.y (and a request for 7.3.y) | 2 per line + covers |
| 8 | CO-22: two ASUS QCA ROME device-table entries for stable (rechecked 2026-11-14) | stable (request only) | — |
| 9 | CO-21: btusb picks alternate setting 0 while a SCO link is up (added 2026-11-14) | bluetooth-next | 2 + cover letter |
| 10 | CO-20: btusb logs the data of a just-closed SCO link as corruption (added 2026-11-14) | bluetooth-next | 2 + cover letter |
| 11 | CO-43, the rest: btusb when a resume fails (for review; not yet to send) | bluetooth-next, on top of item 2 | 4 shown + cover letter |

Items 1 to 10 are ready to send. Item 11 is complete and tested in emulation, but one of its
paths can only be argued from the source, so it is here for review before anyone sends it.

**Not included:** CO-02's SCO series is already on the list (2026-10-27); its v2 is built and one
test result is still being explained. CO-12's advertising-duration clamp waits on a design
decision and on another author's overlapping patch.
