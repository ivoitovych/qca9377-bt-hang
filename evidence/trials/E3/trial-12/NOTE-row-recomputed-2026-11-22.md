# Trial E3 #12: the row's journal fields, recomputed from the boot's own journal

Written 2026-11-22. The row is `12`, dated 2026-11-16T18:45:47+01:00, on boot `a033d9d8`
(2026-11-15 09:45:49 to 2026-11-16 18:45:48).

**Why.** The row was closed at 18:45:47 on 2026-11-16, while `/usr/bin/journalctl` was a test stub
(12:21:45 on 11-16 until 11-20). So every field the closer reads from the journal came from an empty
read. The boot's own journal was not damaged: it is in the persistent journal, and it was archived
on 2026-11-21 01:09 as `/root/bt-journal-archive/boot-a033d9d8.export.zst`.

**How.** `tmp/trial-recompute/export-counts.sh` decompresses that export, and
`export-counts.py` applies the installed closer's patterns to it (`/usr/local/bin/bt-trial` lines
406-592 and 763-872, read 2026-11-22):
- the window is from the trial's start minus 5 s (2026-11-15 09:45:58, epoch 1794732358) to the
  close (epoch 1794851148);
- `-k` means kernel transport;
- `-u` means the unit's own lines and systemd's lines about it;
- `enum_at_boot` uses the boot's first 180 s.

It read 13,894,342 entries. That is the same number `systemd-journal-remote` wrote from the export,
so the export was read whole. Nothing was written. Output:

```
entries_read=13894342
sco_sent=2
timeouts=0
usb_lost=0
n_reload=0
n_reset_installed_rule=0
watchdog_lines=0
early_int=0
any_int=0
probes=0
btmon_aborts=3
boot_first_entry_us=1794732349362768
n_enum_first_180s=1
--- reset lines (any device):
--- timeout lines:
```

| field | in the row (stub) | recomputed | note |
|---|---|---|---|
| `bt1_status` | `unknown` | `not_observed` | journal readable, 0 timeouts; watchdog off (`wd=off`, no watchdog lines) |
| `sco_sent` | 0 | **2** | two SCO setups (`opcode 0x0428`), both without a timeout |
| `timeouts` | 0 | 0 | |
| `usb_lost` | 0 | 0 | |
| `probes` | 0 | 0 | probes off (`probes=off`) |
| `btmon_aborts` | 0 | **3** | three `btmon exited` lines from `bt-trace` |
| `prev_shutdown` | `unknown` | `unknown` by the closer's rule | the previous boot `af3f9840` has no "Reached target reboot/poweroff/halt" line: its journal ends at 09:44:53, mid-shutdown. The same file has `systemd-logind[1389]: System is rebooting.` at 09:44:53, so the boot most likely began with a **reboot** (another rule than the closer's) |
| `enum_at_boot` | `no` | **yes** | the controller enumerated in the first 180 s |
| `perturbed` | `unknown` | **none** | no btusb reload, and no reset line of any USB device |
| `treatment` | as written | as written | no PERTURBED prefix is due |

**Stand as written.** `responds_after` (`no`), `usb_present` (`yes`) and `trial_result` (`failed`)
were read live at the close, not from the journal. So did `duration_s` (118778). The label `E3` is
wrong: the boot ran the stock btusb of `7.0.0-43` (`../NOTE-label-E3-after-2026-11-12.md`).

The row in `results.tsv` is left as the closer wrote it. This note is the correction.
