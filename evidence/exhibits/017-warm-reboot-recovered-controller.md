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

Filled in with `bt-boot-provenance`, which reads all six rows in two seconds:

| transition | shutdown target | gap | firmware | controller after |
|---|---|---|---|---|
| −5 → −4 | `poweroff.target` | 25 s | 3.922 s | enumerated |
| −4 → −3 | `poweroff.target` | 22 s | 3.914 s | enumerated |
| −3 → −2 | `poweroff.target` | 34 s | 3.910 s | enumerated |
| −2 → −1 | `poweroff.target` | 61 s | 3.909 s | enumerated |
| −1 → 0 | **`reboot.target`** | **98 s** | 4.020 s | **enumerated** |

## CORRECTION to an earlier reading of this exhibit

The first version of this analysis described the 22–34 s gaps as "warm reboots
on record" and argued that 98 s was three to four times longer, so the machine
had probably been powered off. **Every one of those rows is a `poweroff.target`
shutdown.** There is no warm reboot anywhere in the retained history to compare
against.

The gap argument therefore runs the other way, and not far: 98 s is *longer*
than this operator's usual power-off-and-back-on turnaround of 22–61 s, which
says nothing useful about whether power was applied during it. The comparison
class was wrong, so the conclusion drawn from it was worthless — an error the
`bt-boot-provenance` table makes hard to repeat, because the shutdown target is
now printed beside every gap instead of being assumed.

## What this does and does not establish

**Does not establish** that a warm reboot recovers the controller. The operator
reports the action as "rebooted or power-cycled, which one is unknown", and a
power-off performed *after* the OS reached `reboot.target` leaves exactly this
trace. Nothing in the journal distinguishes the two.

Firmware initialisation time was checked as a possible independent witness — a
cold start might re-initialise more than a warm one — and it does not
discriminate on this machine (`EX-019`).

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
controller enumerated at the start of the current boot, and `bt-boot-provenance`
prints the same across every retained boot.

**Read that field as shutdown-target provenance, not power-cycle provenance.**
It records the operating system's shutdown trajectory. Reaching `reboot.target`
does not prove power stayed applied afterwards — this very exhibit is the case
where it may not have. The field cannot retrospectively determine electrical
power loss, and no field in the journal can.

What it *does* do is accumulate the ordinary cases honestly. If a boot preceded
by `reboot.target`, with no operator intervention in between, is followed by a
recovered controller, that is the observation the protocol's step 0 claims is
impossible — and it will be sitting in a column rather than in someone's memory.

## Provenance

| field | value |
|---|---|
| captured | `2026-08-13T11:38:05+02:00` |
| kernel | `7.0.0-28-generic` |
| boot id | `d6d9b2dc` |
| device | `13d3:3503` QCA9377 (ROME) |
| exit status | `0` |
| redacted | `no` |
