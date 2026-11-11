# The number 5 was opened twice

**Second use, the row in `results.tsv`** (boot `1bbf9aea`, 2026-11-10 00:37:20 to 16:06:50): the
row's `failed` / `responds_after no` is the installed closer's probe after bluetoothd had powered
the adapter off (kernel log 16:06:30; "controller does NOT respond" 16:06:31). Bluetooth worked all
boot: rampatch and NVM loaded at 00:37:20 to 00:37:21, no SCO link, no command timeout, no kernel
error. `sco_sent` 0, `timeouts` 0 and `usb_lost` 0 are right.

**First use, no row** (boot `045caff5`, 2026-11-06 15:51:34 to 2026-11-09 17:30:28, 265,134 s): the
close was killed by the unit's 90 s stop timeout at 17:31:58 (`journalctl -b -2 -u bt-trial-auto`
as read on 2026-11-11). From the journal: 25 Setup Synchronous Connection requests, no command
timeout, no `USB disconnect`, Bluetooth working throughout. Source:
`/root/bt-journal-archive/boot-045caff5.export.zst`;
`results/laptop-only-work-2026-11-11/bt16-and-trials/D-trial-records.md`.

Both come from the closer installed on 2026-09-18, not from the controller.
