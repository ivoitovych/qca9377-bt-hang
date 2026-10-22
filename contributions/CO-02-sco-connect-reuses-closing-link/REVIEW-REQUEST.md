# Review request: three Linux kernel Bluetooth patches and a BlueZ test (CO-02)

Nothing is sent without the project author's word. There is no deadline.

**What we ask:** review the mails below as if you were seeing them for the first time, and look
for defects of any kind and size: in the code, the reasoning, the commit messages, the tags, the
test, the evidence, or anything a maintainer would object to. A finding that turns out to be
wrong costs little; a defect that reaches the mailing list costs much more. Please form your own
view from the mails and the code before you read the earlier reviews or the log.

## What would be sent
To linux-bluetooth, base bluetooth-next `27731ba09195`, the files in
[`patch/v3/send/kernel/`](patch/v3/send/kernel/):
- `0000-cover-letter.patch`: "[PATCH 0/3] Bluetooth: hci_conn: fix SCO connection reuse".
- `0001-…`: "Bluetooth: hci_conn: hold a reused SCO connection for its caller"
  (`Fixes: 8a5b0135d4a5`, `Cc: stable@vger.kernel.org # 6.6.x`).
- `0002-…`: "Bluetooth: hci_conn: don't reuse an aborting SCO connection"
  (`Fixes: e6720779ae61`, `Cc: stable@vger.kernel.org`).
- `0003-…`: "Bluetooth: hci_conn: wait for a running SCO disconnect before reuse"
  (`Fixes: e6720779ae61`, `Cc: stable@vger.kernel.org`).

Separately, to linux-bluetooth, base BlueZ master `7bc9684dc9e4`:
[`patch/v3/send/bluez/`](patch/v3/send/bluez/), "[PATCH BlueZ] tools/sco-tester: Add SCO
reconnect tests".

Recipients and order: [`patch/v3/send/README.md`](patch/v3/send/README.md).

## Questions you may find useful (not a limit)
1. **Correctness:** is every path through `hci_connect_sco()` after the series right? Consider
   new, linked and unlinked (remote-initiated) connections; the error paths; the reference
   counts on the SCO and the ACL connection; the locking, and what `cancel_delayed_work_sync()`
   under `hdev->lock` could wait for; incoming connections in `BT_CONNECT`/`BT_CONNECT2`; and the
   callers other than `sco_connect()`, if any.
2. **What the series does not fix,** and whether the mails say so honestly.
3. **The commit messages:** is every statement true and checkable against the code and the
   history? Are the `Fixes:` commits the right ones?
4. **Stable:** are the tags right for 6.1, 6.6, 6.12, 6.18 and 7.2 as they are today? Is the
   cover letter's stable paragraph correct, and is it needed?
5. **The BlueZ test:** can it pass on a broken kernel, or fail on a correct one? Is it within
   BlueZ's style and the conventions of `sco-tester`? Is it maintainable?
6. **The evidence:** does it support every claim in the mails? Is anything overstated?
7. **Recipients and form:** anyone missing or wrong; anything in the mails a maintainer would not
   want; anything missing that they would need.

## Material
- The evidence for the current mails:
  [`experiments/results-2026-10-22-v3.md`](experiments/results-2026-10-22-v3.md). Earlier
  evidence: [`results-2026-10-22-v2.md`](experiments/results-2026-10-22-v2.md) and the
  parked-worker race transcript
  [`race-park-2026-10-22.md`](experiments/race-park-2026-10-22.md).
- The kernel source at the base:
  `https://git.kernel.org/pub/scm/linux/kernel/git/bluetooth/bluetooth-next.git` at
  `27731ba09195`.
- Earlier reviews ([`reviews/`](reviews/)) and the working log ([`log.md`](log.md)), for after you
  have your own view.

Please answer in any form. Links are relative, so they stay at the commit you opened this file
from.
