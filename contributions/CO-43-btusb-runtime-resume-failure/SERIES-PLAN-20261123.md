# CO-43: E and the BT-24/25 pair become one three-patch series (plan of 2026-11-23)

This comes from the outside review of 2026-11-23
(`../../reviews/2026-11-23T0404Z-five-kernel-submissions-review-findings-and-checks.md`,
findings 9–17). **Not done yet**; this file is the work order. The current packages
(`send-20261113/E/`, `send-bt24-bt25-20261114/`) stay until the series replaces them.

**The series, on a public base** (bluetooth-next tip, generated with `git format-patch --base=<tip>`):

| # | patch | from | changes asked |
|---|---|---|---|
| 1/3 | "Bluetooth: btusb: Free the skb of a deferred URB that is discarded" (BT-25) | `send-bt24-bt25-20261114/0002-*` | **Rebase to stand first.** It conflicts today without the race fix under it (on E and on the bare tip, 2026-11-22). Keep only `Fixes: 7bee549e197c`: `19cfe912c37b` is an incomplete 2017 repair, which added the setup-packet and URB frees and still no skb free (checked in its diff); name it in prose. Reword "runs under txlock with interrupts off in two of them" to "the resume paths run with txlock held and interrupts disabled": three of the four sites run locked, only `btusb_close()` does not (checked on the tip, `btusb_main.c` l.2238, l.5067–5070). In the close argument, say that the core's works are stopped and `HCI_RUNNING` is cleared, and that a driver-context `__hci_cmd_send()` is a lockless edge whose worst case is a parked URB, as today (R6). Add a short testing sentence to the commit. |
| 2/3 | "Bluetooth: btusb: Anchor a deferred URB under txlock" (E, BT-23) | `send-20261113/E/0001-*` | The code is unchanged. Optional: shorten the 4-line comment (R2). Add the consequence only if the widened-window logs show it: `hci_cmd_timeout()` → `hdev->reset` → `btusb_reset()` "Resetting usb device", and the parked command is sent stale at the next resume (R6). One sentence on how it was found (R7). |
| 3/3 | "Bluetooth: btusb: Drop deferred URBs under txlock on a failed resume" (BT-24) | `send-bt24-bt25-20261114/0001-*` | Soften "the waker … finds an active device" to: the sender enqueues after the only discard point for that resume, so the URB stays deferred (R3). It relies on 2/3. Add a short testing sentence. |

**Cover:** "[PATCH 0/3] Bluetooth: btusb: Fix deferred URB leaks and races" (R3), or "… Fix deferred
transmit handling" (R7). Drop the internal label "E". The current cover's `base-commit:
04b58d680611` is a local commit, in no public tree ("not our ref").

**New test (R2, R7):** two or more deferred URBs at once. ACL and ISO packets are deferred
through `submit_or_queue_tx_urb()` too, so the cleanup loop at the end of `play_deferred()` is
reachable; "the command credit allows one" described our harness, not the driver. Use a command
plus ACL, and a bulk URB with a NULL `setup_packet`. Force the first submission to fail, then
check:
- every skb and URB is freed;
- the anchor is empty;
- `tx_in_flight` is unchanged.

Name the kmemleak allocation sites, not only the counts.

**Reruns:** the existing kmemleak table, the forced windows and the stress run, on the new base
and in the new order.

**Laptop (the operator's word):** a no-regression soak with the three patches installed via
`updates/` and a cold boot. It means runtime and system suspends, commands in a loop and a
headset call. It is not an attempt to reproduce the rare race.

**`Cc: stable`:** none on 2/3 and 3/3 (four of five reviewers). For 1/3 the reviewers are split:
R3 for, R6 against, R7 for the series. That is the operator's call.

**Recipients:** `get_maintainer.pl` on the final tree. Oliver Neukum on Cc (the `Fixes:`
author).
