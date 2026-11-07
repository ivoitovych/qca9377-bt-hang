# CO-01 — Test the abandoned-setup SCO series

**State:** idea; nothing run yet.

**Target:** the Linux kernel. This is another author's series; ours would be a test report and
possibly a Tested-by.

**Comes from:** our call-audio items (`U7`, `U8`) and BlueZ #2562. One reporter there lists
the QCA9377 among the affected controllers.

## What it is

Hitalo Souza's "[v3 0/6] Bluetooth: Fix SCO setup failures after an abandoned setup" (sent
2026-10-08, base bluetooth-next `97a128698d9d`):
- **The fix:** since `a13f316e90fd`, closing a SCO socket while its setup is pending deletes
  the `hci_conn`. A setup that completes anyway can break the next connection, or leave a
  link up in the controller. The series fixes that.
- **State:** all six patches are `new` on patchwork; the only reply is the CI bot's, on 1/6.
  The BlueZ tester patches (14875435 and its companion) are `new` too.
- **Patch 6** changes when btusb is told about a SCO link. Its cover letter says it was not
  tested ("hci_vhci has no notify callback"). The only real hardware run was a MediaTek
  adapter on the legacy setup command. The laptop also uses the legacy command, because the
  ROME entry sets `HCI_QUIRK_BROKEN_ENHANCED_SETUP_SYNC_CONN`, so a btusb run here adds
  something.
- **The series does not cover U7**; that is CO-02.

## Next

1. **QEMU:** the exact patches with `git am` on their base, BlueZ's sco-tester with the
   author's new tests, with and without the series.
2. **Ubuntu `-38`:** does it carry `024e05f73a4c`? If not, patch 2 needs the lock adaptation
   the cover letter describes.
3. **Only on the operator's word:** a `bluetooth.ko` built from `-38` with the series,
   installed through `updates/` and a cold boot (never a live swap, `EX-046`).
   - Reviewer 1: a meaningful hardware Tested-by needs two concurrent SCO links (or rapid
     setup and teardown), btusb's dynamic debug of the alt choice, and a capture.

**Decides:** a laptop run and any Tested-by are the operator's decision.
