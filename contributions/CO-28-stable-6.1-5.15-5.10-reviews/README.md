# CO-28 — Tested-by on the 6.1.191, 5.15.224 and 5.10.273 stable reviews

**State:** waiting (on the review mails). Nothing drafted.

**Target:** the stable kernel's review threads. Ours would be a test report, as CO-10 was for
6.6.160-rc2.

**Comes from:** our stable requests. The release candidates of 2026-10-17 carry them:
- the QCA9377 entry (`dc16388d45ec`) in all three;
- BT-9's fix (`96d006ae6445`, our 6.1.y backport) and BT-8's fix (`86ef0f58bdec`) in 6.1.191-rc1.

## The facts (2026-10-28)

- **No release yet.** kernel.org's newest are 6.1.190, 5.15.223 and 5.10.272 (2026-10-15);
  `tmp/walk-20261028/releases.json`.
- **The rc1s are still open.** `scripts/stable-rc-check.sh "Bluetooth: btusb: Add IMC Networks
  QCA9377" 6.1 5.15 5.10`: IN RC as `798101df31ec6`, `986a277650a5c` and `366731d216d92`;
  the rc tips are "Linux 6.1.191-rc1", "Linux 5.15.224-rc1" and "Linux 5.10.273-rc1", all
  2026-10-17. Eleven days without a release or an rc2 is longer than usual.
- **The review mails:** not found. lore answered 403 from here, and spinics' current page of
  the stable list does not show them. Whether they were posted is not known.

## What is ready

CO-10's method: every BlueZ CI TestRunner suite on the rc and on its base in QEMU/KVM, compared
by case (`scripts/compare-tester-verdicts.py`), with a kernel-report scan
(`scripts/kernel-report-scan.py`), and the reply checked with `scripts/reply-headers-check.py`
and `scripts/mail-lint.sh`.

## Next

Watch for each review mail. If one appears, run the comparison on that rc and draft the reply.
The send is the operator's decision. If the rcs are replaced by rc2s, the same applies to those.
