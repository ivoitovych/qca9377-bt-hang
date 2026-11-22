# Trial E3 #13: the boot's journal is lost

Written 2026-11-22. The row is `13`, dated 2026-11-16T18:49:29+01:00.

- **The boot.** It began 2026-11-16 at about 18:48 and was shut down after 72 s. The label E3 is
  wrong: this boot ran the stock btusb of `7.0.0-43` (`../NOTE-label-E3-after-2026-11-12.md`).
- **What went wrong.** From 2026-11-16 12:21:45 until 2026-11-20, `/usr/bin/journalctl` was a
  test stub written there by mistake by a test run. As a result:
  - this boot's persistent journal was not kept: `journalctl --list-boots` has no boot between
    `a033d9d8` (which ended 18:45:48) and the boot that began 2026-11-18 13:48;
  - the row's journal fields were read through the stub.
- **Field by field:**
  - `bt1_status`, `prev_shutdown` and `perturbed` say `unknown`. That is correct: the closer saw
    that it could not read the journal.
  - `sco_sent`, `timeouts` and `usb_lost` say `0`, and `enum_at_boot` says `no`. Read these as
    **unknown, not zero**: they were counted from an empty read.
  - `responds_after` (`no`), `usb_present` (`yes`), `trial_result` and `duration_s` were read
    live at the close, not from the journal, and stand.
- **The row cannot be recomputed from the journal.** The text logs that rsyslog kept for this
  window (`/var/log/kern.log*`) may still hold the kernel lines. Copying them before they rotate
  away is the operator's decision D-4.
