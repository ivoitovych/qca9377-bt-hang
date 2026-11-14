# CO-20 notes (2026-11-14)

## Patch 1: standalone mail

`0001-Bluetooth-btusb-Report-SCO-receive-failures-by-cause.patch`, on bluetooth-next `da3cc02587c6`,
no cover letter, no Signed-off-by (the sender adds his own). It does not depend on patch 2; its message
says nothing about it. Tested alone in `CHECKS.md`.

## Patch 2: held

Patch 2 ("Log SCO data for a just closed link at debug level") is not sent and not changed. The reviewers
(R2, R3, R7) agree the "handle equals the last header that validated" test is a guess. Two ways forward,
not implemented here:

1. **A bounded record of recently closed handles from the core.** `hci_conn_del()` (or the code that
   handles Disconnection Complete) would remember the handles of SCO/eSCO links closed in the last few
   tens of milliseconds, in a small fixed-size ring on `struct hci_dev`, with a timestamp for each.
   btusb would ask the core "was this handle closed within the last N ms" instead of guessing from the
   last header. This answers R7's case (A and B transparent, A closes, B quiet on the same setting: A's
   handle stays "remembered" for ever with the heuristic, so a malformed frame that decodes to A's handle
   is excluded from `err_rx`; with a timed ring it stops matching after N ms). It also covers two links up:
   data of any link that closed is recognised, not only of the one that happened to be last. Costs: a new
   core field and accessor, a lock for the ring (hdev->lock or a small spinlock, taken from the URB
   completion path), a choice of N (the laptop captures showed up to 33.6 ms), and a core change for a
   driver log line, which maintainers may not want.
2. **Call it a heuristic and keep `err_rx` as it is.** Patch 2 would change: the message and the comment
   say it is a heuristic, not proof of provenance; the data is logged at debug level but still counted in
   `err_rx` (so `hciconfig` error counts do not change), or not logged at all. Sent as RFC or after
   patch 1 has been reviewed. Costs: the counter keeps counting the normal end of every call.

Not decided here. R3 suggested RFC labelling for either variant.
