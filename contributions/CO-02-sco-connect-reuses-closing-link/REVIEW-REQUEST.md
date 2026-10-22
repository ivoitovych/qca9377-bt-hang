# Review request — two Linux kernel Bluetooth patches and a BlueZ test (CO-02)

Nothing is sent without the project author's word. There is no external deadline.

## What we want to send

**A kernel series to linux-bluetooth** (bluetooth-next `27731ba09195`):
1. "Bluetooth: hci_conn: don't reuse an aborting SCO connection": a SCO `connect()` to a device
   whose SCO link is being disconnected currently gets the dying connection, reports success
   without any setup, and is closed with `ECONNABORTED` a moment later. PipeWire does exactly
   this when the HFP codec changes during a call (our issue U7). The patch fails such a connect
   at once with `-ECONNABORTED`.
2. "Bluetooth: hci_conn: hold a reused SCO connection for its caller": a second `connect()` to a
   device whose SCO link is up fails with EBUSY and then disconnects the first socket's working
   link.

**A BlueZ test case** ("tools/sco-tester: Add reconnect tests"), sent separately, which
reproduces patch 1's defect in the emulator.

The cover letter also asks the maintainers whether they would prefer deferring the connect
until the old link is gone, which is what makes PipeWire 1.0.5's immediate retry succeed; that
alternative exists as an RFC prototype and is **not** part of this send.

## What to read
Links are relative, so they stay at the commit you opened this file from.
1. The final patches: [`patch/kernel-final/`](patch/kernel-final/)
2. The cover letter: [`drafts/kernel-cover-letter.txt`](drafts/kernel-cover-letter.txt)
3. The BlueZ test: [`patch/bluez/`](patch/bluez/)
4. The results, with numbers: [`experiments/results-2026-10-21.md`](experiments/results-2026-10-21.md)
   and [`experiments/results-table-2026-10-21.txt`](experiments/results-table-2026-10-21.txt)
5. The record of each step, including the pre-send checks and the correction of patch 2's
   `Fixes:` tag: [`log.md`](log.md); the plan and open decisions: [`drafts/README.md`](drafts/README.md)
6. The deferral prototype, for context: [`patch/kernel-rfc-defer/`](patch/kernel-rfc-defer/)

## What we ask of you
1. **Are the patches right?** Read `hci_connect_sco()` and `sco_connect()` on bluetooth-next.
   Is the refusal correct and complete (holds, the ACL reference, races with
   `hci_conn_timeout()` setting `abort_reason`)? Is patch 2's hold accounting right?
2. **Are the `Fixes:` tags right?** Patch 1 names `a13f316e90fd` (when `hci_abort_conn()` stopped
   setting `BT_DISCONN`); patch 2 names `8a5b0135d4a5` (when `sco_connect()` began dropping the
   hold on the `sco_chan_add()` error path), after `06149746e720` had stopped taking one on reuse.
3. **Is the testing enough** for a maintainer to accept it, and is anything missing that they
   would expect?
4. **Refuse or defer?** Should the series be sent as it is with the question in the cover
   letter, or should the deferral be the main patch?
5. **The mails:** is there anything a maintainer does not need (noise), or anything missing?
6. **The BlueZ test** fails on kernels without patch 1, which the BlueZ CI would show until the
   kernel patch lands: send it with the series, or after?

Please answer in any form.
