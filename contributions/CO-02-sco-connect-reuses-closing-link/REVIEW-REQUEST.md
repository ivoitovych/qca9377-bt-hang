# Review request, round 3: what changed after round 2 (CO-02)

Nothing is sent without the project author's word, and there is no external deadline.

In round 2 (six reviews of `4ee379d`, in `reviews/2026-10-22-round2-reviews-of-4ee379d.md`) no
reviewer asked for more investigation. One suggestion turned up a gap in patch 3, though.
Reviewer 2 proposed this sentence for its changelog: "only a connection with a link can have
pending disconnect work". That is not so. A SCO connection the remote device set up never gets a
link, and closing its accepted socket queues the disconnect work. A new connect to that device
then takes the `hci_conn_link()` branch, which patch 3 v1 did not cover. A scratch test
reproduced it (2 of 2). **Patch 3 v2** now waits after both branches.

## What to read
Links are relative, so they stay at the commit you opened this file from.
1. The mails: [`patch/v2/kernel/`](patch/v2/kernel/) (cover letter and three patches) and
   [`patch/v2/bluez/`](patch/v2/bluez/) (the test, a separate mail).
2. The evidence: [`experiments/results-2026-10-22-v2.md`](experiments/results-2026-10-22-v2.md).
3. What each round-2 point led to: the last entry of [`log.md`](log.md).

## What we ask
1. **Patch 3 v2:** it now calls `cancel_delayed_work_sync()` after both branches, and so also for
   a brand-new connection (a no-op there). Is that right, and is the error path right for the
   `hci_conn_link()` branch? On refusal it drops the caller's hold and leaves the new link to the
   ACL in place; the Disconnection Complete removes that link.
2. **The BlueZ test's new checks:** the watch condition, the stability check and the ACL handle.
3. **Anything that should stop the send.**

Please answer in any form.
