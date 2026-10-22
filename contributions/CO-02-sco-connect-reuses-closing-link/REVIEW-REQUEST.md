# Review request, round 2 — three Linux kernel Bluetooth patches and a BlueZ test (CO-02)

Nothing is sent without the project author's word. There is no external deadline.

Round 1 (six reviews of `4c82e91`, in `reviews/`) found a false-pass hole in the BlueZ test, an
unfaithful emulator teardown, no test for patch 2, and a race between `hci_conn_timeout()` and a
new connect. This package answers them; how each point was handled is in `log.md`.

## What we want to send
**A kernel series to linux-bluetooth** (bluetooth-next `27731ba09195`), `patch/v1/`:
1. "Bluetooth: hci_conn: don't reuse an aborting SCO connection": a SCO `connect()` to a device
   whose link is being disconnected reports success without any setup and is closed with
   `ECONNABORTED` a moment later (PipeWire's HFP codec switch, our issue U7). The patch refuses it
   at once. `Fixes: e6720779ae61`, found by bisect.
2. "Bluetooth: hci_conn: hold a reused SCO connection for its caller": a second `connect()` to a
   live link fails with EBUSY and then disconnects the first socket's link; the SCO half of the
   accepted CIS fix `e06d549fcd4a`. `Fixes: 8a5b0135d4a5`.
3. "Bluetooth: hci_conn: wait for a running SCO disconnect before reuse": closes the window
   before `abort_reason` is set, reproduced with a debug-only park of `hci_conn_timeout()`.

**A BlueZ test** ("tools/sco-tester: Add reconnect and connect twice tests"), sent alongside,
with the kernel dependency stated below `---`.

## What to read
Links are relative, so they stay at the commit you opened this file from.
1. The mails as they would go out: [`patch/v1/`](patch/v1/) (cover letter, three kernel patches,
   the BlueZ patch).
2. The evidence: [`experiments/results-2026-10-22.md`](experiments/results-2026-10-22.md).
3. How each round-1 point was handled: [`log.md`](log.md).

## What we ask of you
1. **Patch 3:** is waiting with `cancel_delayed_work_sync()` under `hdev->lock` in
   `hci_connect_sco()` correct and free of deadlocks (the argument is in the commit message and the
   results file)? Is there a better place for it?
2. **The `Fixes:` tags,** now backed by a bisect (patch 1, 3) and a parent/commit test (patch 2).
3. **The BlueZ test:** is its oracle strict enough now, and is it maintainable?
4. **The mails:** anything a maintainer does not need, or anything missing?
5. **Anything that should stop the send.**

Please answer in any form.
