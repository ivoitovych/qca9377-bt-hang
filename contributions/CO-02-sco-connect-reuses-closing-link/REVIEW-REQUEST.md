# Review request: three Linux kernel Bluetooth patches and a BlueZ test (CO-02)

Nothing is sent without the project author's word. There is no deadline.

**What we ask:** review the mails below as if you were seeing them for the first time, and look
for defects of any kind and size: in the code, the reasoning, the commit messages, the tags, the
test, the evidence, the send procedure, or anything a maintainer would object to. A finding that
turns out to be wrong costs little; a defect that reaches the mailing list costs much more. Please
form your own view from the mails and the code before you read the earlier reviews or the log.

## What would be sent
Two packages hold the same code and differ only in the prose. One of them will be sent; the
author has not chosen yet.
- **v7 candidate,** [`patch/v7-candidate/send/`](patch/v7-candidate/send/): the messages
  reworked to read quickly (symptom first, short paragraphs, headed sections in the cover). Its
  [`README.md`](patch/v7-candidate/send/README.md) says where each change came from and what was
  not taken.
- **v6,** [`patch/v6/send/`](patch/v6/send/): the earlier wording.

Each package has, to linux-bluetooth, on bluetooth-next `47d4d9f67e92`, in `kernel/`:
- `0000-cover-letter.patch`: "[PATCH 0/3] Bluetooth: hci_conn: fix SCO connection reuse".
- `0001-…`: "Bluetooth: hci_conn: hold a reused SCO connection for its caller"
  (`Fixes: 8a5b0135d4a5`, `Cc: stable@vger.kernel.org # 6.6.x`).
- `0002-…`: "Bluetooth: hci_conn: don't reuse an aborting SCO connection"
  (`Fixes: e6720779ae61`, `Cc: stable@vger.kernel.org`).
- `0003-…`: "Bluetooth: hci_conn: synchronize with SCO disconnect work before reuse"
  (`Fixes: e6720779ae61`, `Cc: stable@vger.kernel.org`).

And, to linux-bluetooth, on BlueZ master `b0bf49270d44` (v7; v6's is on `a0580dad5655`), in
`bluez/`: "[PATCH BlueZ]
tools/sco-tester: Add SCO reconnect tests". Two of its cases fail until the kernel series is
applied. Its notes below `---` say so, ask that it be applied after the series is in
bluetooth-next, and link the series on lore. That link exists only once the series is sent, so
the mail carries the placeholder `@KERNEL_SERIES_LINK@` until then.

How and in what order the two are sent: [`send-tools/README.md`](send-tools/README.md), with the
scripts [`send.sh`](send-tools/send.sh) and [`fill-bluez-link.sh`](send-tools/fill-bluez-link.sh).
Recipients: [`patch/v6/send/README.md`](patch/v6/send/README.md).

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
   BlueZ's style and the conventions of `sco-tester`? Is it maintainable? Is the way it depends
   on the kernel series (the same-day send, the request to apply it after, the lore link) what
   these maintainers expect?
6. **The hardware claims:** the cover reports runs on a laptop (patch 1's case run there; patch
   3's race emulator-only). Does the evidence support each sentence, and nothing more?
7. **v7 against v6:** is anything in v7 less true or less precise than v6? Which would you send,
   and why?
8. **The send procedure:** can `send.sh` or `fill-bluez-link.sh` send the wrong mail, the wrong
   recipients, or a mail with the placeholder still in it?
9. **Recipients and form:** anyone missing or wrong; anything in the mails a maintainer would not
   want; anything missing that they would need.

## Material
- **Evidence for the mails:**
  - the emulator matrix: [`experiments/results-2026-10-22-v4.md`](experiments/results-2026-10-22-v4.md),
    with the stable check in [`results-2026-10-22-v3.md`](experiments/results-2026-10-22-v3.md);
  - the BlueZ test's teardown fix and its rerun on the current heads:
    [`results-2026-10-26-bluez-v6.md`](experiments/results-2026-10-26-bluez-v6.md);
  - the laptop runs: [`results-2026-10-24-hardware.md`](experiments/results-2026-10-24-hardware.md),
    and patch 1's case on the laptop:
    [`results-2026-10-26-hw-connect-twice.md`](experiments/results-2026-10-26-hw-connect-twice.md),
    with its program in [`experiments/hw-connect-twice/`](experiments/hw-connect-twice/);
  - the exhibits, each with its command and output, in
    [`evidence/exhibits/`](../../evidence/exhibits/): `EX-068` to `EX-077` for the laptop, and
    `EX-078` to `EX-083` for the proof that v7's code is the code that was tested (v3, v4, v6,
    and the laptop's module).
- **The tools behind those proofs:** [`scripts/patch-code-compare.py`](../../scripts/patch-code-compare.py),
  [`scripts/change-code-compare.sh`](../../scripts/change-code-compare.sh),
  [`scripts/sco-link-closure.py`](../../scripts/sco-link-closure.py),
  [`scripts/sco-data-gaps.py`](../../scripts/sco-data-gaps.py).
- **The sources at the bases:**
  `https://git.kernel.org/pub/scm/linux/kernel/git/bluetooth/bluetooth-next.git` at
  `47d4d9f67e92`, and `https://git.kernel.org/pub/scm/bluetooth/bluez.git` at `b0bf49270d44`.
- **For after you have your own view:** earlier reviews ([`reviews/`](reviews/)) and the working
  log ([`log.md`](log.md)); the 26 October rounds are summarised in the log.

Please answer in any form. Links are relative, so they stay at the commit you opened this file
from.
