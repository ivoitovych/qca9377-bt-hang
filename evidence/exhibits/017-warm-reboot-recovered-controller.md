# EX-017 — warm-reboot-recovered-controller

**Claim.** The controller recovered across a shutdown that reached reboot.target, not poweroff.target. The protocol's step 0 asserts a warm reboot cannot recover it, and that assertion has never been tested against a case where one was tried.

**Relevance.** If a warm reboot recovers the controller, the recovery procedure is cheaper than believed AND the M.2-rail explanation for stage 2 is wrong. The 98 s gap is longer than any warm reboot on record (22-34 s) and longer than the confirmed power cycle (61 s), so an unlogged power-off during the window is not excluded.

## Extraction method

Re-runnable as-is on the affected machine:

```console
$ journalctl -b -1 --no-pager 2>/dev/null | grep -E 'Reached target (reboot|poweroff|halt)'; journalctl -b -2 --no-pager 2>/dev/null | grep -E 'Reached target (reboot|poweroff|halt)'; journalctl --list-boots --no-pager | tail -6; journalctl -k -b 0 --no-pager -o short-iso-precise | grep -m1 'idVendor=13d3'
```

## Output

Verbatim, 9 line(s), exit status 0.

```
Aug 13 09:17:32 n systemd[1]: Reached target reboot.target - System Reboot.
Aug 13 02:59:13 n systemd[1]: Reached target poweroff.target - System Power Off.
 -5 5641d159a3184eb7b19963ab54f41609 Tue 2026-08-11 22:26:00 CEST Wed 2026-08-12 04:40:05 CEST
 -4 c1315c2514304928b7cbadbe9547716b Wed 2026-08-12 04:40:30 CEST Wed 2026-08-12 05:38:46 CEST
 -3 7ab863880c354c24b9e275773bc4aa70 Wed 2026-08-12 05:39:08 CEST Wed 2026-08-12 08:17:04 CEST
 -2 d28ebac23a004bbea5a2e4fd740bda27 Wed 2026-08-12 08:17:38 CEST Thu 2026-08-13 02:59:13 CEST
 -1 e3f66b3e9bed461096d591e91b54a388 Thu 2026-08-13 03:00:14 CEST Thu 2026-08-13 09:17:32 CEST
  0 d6d9b2dcebca4b0e9bad28b962fedb3e Thu 2026-08-13 09:19:10 CEST Thu 2026-08-13 11:38:03 CEST
2026-08-13T09:19:10.111759+02:00 n kernel: usb 3-3: New USB device found, idVendor=13d3, idProduct=3503, bcdDevice= 0.01
```

## Reading

At the end of boot `-1` the controller was off the bus and unrecoverable: it had
logged five HCI command timeouts, then a `USB disconnect` at 06:28:13, and
`lsusb` showed nothing. At 09:19:10 in boot `0` it enumerated normally as
`13d3:3503`.

Between those two facts the system reached **`reboot.target`**, not
`poweroff.target`. The boot before it, which the operator confirmed as a
power-off/power-on, reached `poweroff.target` — so the two are distinguishable
in the log, and this one is recorded as a reboot.

| transition | shutdown target | gap | controller after |
|---|---|---|---|
| −5 → −4 | (not checked) | 25 s | — |
| −4 → −3 | (not checked) | 22 s | — |
| −3 → −2 | (not checked) | 34 s | — |
| −2 → −1 | `poweroff.target` | 61 s | recovered |
| −1 → 0 | **`reboot.target`** | **98 s** | **recovered** |

## What this does and does not establish

**Does not establish** that a warm reboot recovers the controller. The 98 s gap
is three to four times the warm reboots on record and longer than the confirmed
power cycle, so the machine plausibly spent that window powered off — the
operator reports the action as "rebooted or power-cycled, which one is unknown",
and a power-off performed *after* the OS reached `reboot.target` leaves exactly
this trace.

**Does establish** that the claim was never tested. `bt-trial protocol` step 0
states that a warm reboot "does not drop the M.2 power rail and will not recover
it", and the register repeats it. No exhibit supports it. It is a plausible
hardware inference that entered the documentation as fact, and this is the first
observation that even bears on it.

If a warm reboot does recover the controller, two things follow: the recovery
procedure is far cheaper than the protocol demands, and the M.2-rail account of
why cold power-off is required is wrong — which matters, because that account is
part of how stage 2 is explained.

## What was changed as a result

`bt-trial` now records the previous boot's shutdown target and whether the
controller enumerated at the start of the current boot, so the question is
answered by accumulation instead of by recall. The next time the controller dies
and the machine is restarted, the log will say which kind of restart it was
without anyone having to remember.

## Provenance

| field | value |
|---|---|
| captured | `2026-08-13T11:38:05+02:00` |
| kernel | `7.0.0-28-generic` |
| boot id | `d6d9b2dc` |
| device | `13d3:3503` QCA9377 (ROME) |
| exit status | `0` |
| redacted | `no` |
