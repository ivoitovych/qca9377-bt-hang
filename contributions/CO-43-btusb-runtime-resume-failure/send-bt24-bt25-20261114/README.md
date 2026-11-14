# CO-43: BT-24 and BT-25 as their own series on E (2026-11-14)

Four outside reviewers asked for this
(`../../../reviews/2026-11-14T1400Z-kernel-patches-review-answers-checks.md` §11). Not sent; no
Signed-off-by.
- **The series:** two patches on bluetooth-next `da3cc02587c6` + E, with no B2 or D code
  (`BTUSB_CMD_DEFERRED` appears 0 times), and a cover letter.
  - 0001: a failed resume drops the deferred URBs under `txlock` (BT-24).
  - 0002: the skb and setup packet of a discarded deferred URB are freed at all four places (BT-25).
- **`btusb_close()`** needs no lock of its own. The core flushes the tx and command work and clears
  `HCI_RUNNING` before it calls close, and `hci_send_frame()` refuses frames after that, so nothing
  can be anchored while close drains. Patch 2's message says so.

| emulated case, 3 runs each (`logs/kml-e.txt`, `logs/kml-ef.txt`) | E only | E + series |
|---|---|---|
| kmemleak objects: failed resume with a deferred command | 3, 3, 1 | 0, 0, 0 |
| kmemleak objects: `play_deferred()` submission fails | 2, 1, 2 | 0, 0, 0 |
| kmemleak objects: dead device, then close | 5, 3, 4 | 0, 0, 0 |
| kmemleak objects: dead device, hci0 powered off | 2, 2, 2 | 0, 0, 0 |
| deferred anchor after the failed resume (BT-24) | not empty 3/3 | empty 3/3 |

- **The rest of the matrix** is identical on both kernels (`logs/matrix.txt`): dead device,
  recovering device, dropped event with and without a wedge, and 30 healthy cycles. The power-off
  case (BT-18) fails on both, as expected.
- **Kernel reports:** none in the 103 run logs.
- **The bot** (`bot/`): the patched side passes its build checks and fails only the Signed-off-by
  checks and VerifyFixes, whose ancestor check needs full history; the base side passes.
- **Test-only instrumentation** (`test-only/`, never for submission): fault injection in the
  failed-resume path. A delay plus a second HCI command sent from a work item stands in for B2's
  timing window.

**Checked on copy:** the kmemleak and anchor lines in both summaries, against the table.
**Left in the work area:** the guest logs (emulated addresses), the bot's per-check logs, the trees
and the images.
