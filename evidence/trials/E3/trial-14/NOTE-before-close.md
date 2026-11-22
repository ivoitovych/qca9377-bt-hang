# Trial E3 #14: read this before its row

Written 2026-11-22. The trial is still open (`/run/bt-trial/current`: start 1795006086 =
2026-11-18 13:48:06 CET, n=14).

- **The label.** E3 is wrong: this boot runs the stock btusb of `7.0.0-43`
  (`../NOTE-label-E3-after-2026-11-12.md`).
- **The journal is missing from 2026-11-18 13:48 to 2026-11-20 15:03:07.** In that time
  `/usr/bin/journalctl` was a test stub and journald's files for this boot were lost. The
  persistent journal holds this boot only from 2026-11-20 15:03:07 (`journalctl --list-boots`).
- **What the closer will get wrong:**
  - The closer reads the journal "since the trial's start". That read will succeed, but it will
    cover only the part from 2026-11-20 15:03:07. So `sco_sent`, `timeouts`, `usb_lost`,
    `probes`, `btmon_aborts` and `bt1_status` will cover that part only, while looking like
    whole-boot values. Read them as "from 11-20 15:03 on".
  - `enum_at_boot` reads the first three minutes of the boot. That part is lost, so the closer
    will say `no`. Read it as **unknown**.
  - `perturbed` will very likely say `usb_reset`, but the controller (on USB `3-3`) was not
    reset. The installed closer counts a reset of **any** USB device, and devices `1-3` and `1-4`
    were reset in this boot. This is defect (b) of the 2026-11-16 incident record. Its fix, which
    counts only the controller's own port, is not installed (operator decision D-7). Check the
    reset lines' device before reading this field.
- **Risk of losing the row.** The kernel journal of this boot is large: a `__hci_sched_sco`
  debug site has logged millions of lines since 2026-11-18 (decision D-6). The installed closer
  has a 90 s stop timeout at shutdown and has lost rows that way before (E3 #11, 2026-11-13).
  `scripts/trial-snapshot.sh` keeps the record before a shutdown without closing the trial.
