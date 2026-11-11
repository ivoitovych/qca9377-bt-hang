# D. Trial records since 2026-11-05: what happened per boot, and a proposed note

`evidence/trials/results.tsv` was not edited. Everything here is read from the journal and the trial directories.
Marks as before.

## Boots (from `journalctl --list-boots`; ids are the real ones, `045caff5` is right, the "046caff5" of the task text is a typo)

| index | boot id | first entry | last entry | trial number opened by `bt-trial-auto` |
|---|---|---|---|---|
| -3 | `7323fc85d3e64f3380bde588818c46ed` | 2026-11-05 19:33:05 | 2026-11-06 15:47:16 | E3 #4 (opened 11-05 19:33, row exists) |
| -2 | `045caff551104648900621801d2a9e82` | 2026-11-06 15:51:22 | 2026-11-09 17:31:59 | E3 #5, opened 15:51:34 |
| -1 | `1bbf9aeabb9545d68b380f4811e6a32f` | 2026-11-10 00:37:20 | 2026-11-10 16:06:50 | **E3 #5 again**, opened 00:37:33 |
| 0 | `e68d6d906ecd41169164b85c1f33dad7` | 2026-11-11 00:32:45 | (running) | E3 #6, opened 00:32:58 |

`results.tsv`, last three rows [measured]: trial 3 (2026-10-30T19:52:04, 1752 s), trial 4 (2026-11-06T15:47:16, 72829 s,
`usb_lost` 1), trial 5 (2026-11-10T16:06:50, 55746 s, `usb_lost` 0); all `failed`, `responds_after no`, `sco_sent 0`,
`timeouts 0`. `git status`: `results.tsv` modified (trial 5's row is uncommitted), `E3/trial-05/sco-params.txt` and
`state-after.txt` untracked, `E3/trial-06/` untracked.

## Per boot

### 7323fc85 (11-05 19:33 to 11-06 15:47), trial 4
- Bluetooth: **did not work at all** (BT-16: patch already loaded, LE commands failed, USB drop, index never visible).
- Closer's verdict: "HANG after 72829s". Same mechanism as the 11-07 check in part: the probe ran after bluetoothd's
  adapter shutdown; but here the boot really had no Bluetooth, which no closer notices.
- Lost: nothing of the row; its wording ("HANG", "cold power-off required") is wrong, "failed"/`usb_lost 1` is right
  (one real USB drop, at start-up, not a stream-related loss).

### 045caff5 (11-06 15:51 to 11-09 17:31), first "E3 #5"
- Bluetooth: **worked**. `using rampatch file` / `QCA: patch rome 0x302 build 0x3e8` at 15:51:22; kernel
  `-p err` lines are only `SCO packet for unknown connection handle N` (benign, 11-07 to 11-09) and two `corrupted SCO packet`
  (11-09 10:33:41); **no command timeout**.
- SCO setups counted from the journal: `journalctl -k -b -2 --no-pager -o short-iso --grep "opcode 0x0428|opcode 0x043d|command( 0x[0-9a-f]+)? tx timeout|opcode 0x0406 status"`
  gives 25 lines `hci0 opcode 0x0428 plen 17` (8 on 11-07, 7 on 11-08, 10 on 11-09), no `0x043d`, no `tx timeout`.
  34 `opcode 0x0406 status 0x00` lines (disconnects answered). [measured; counted by eye from that output]
- Suspend: "The system will suspend now!" 11-07 18:16:05; the stream-using SCO links continued after it
  (20:19, 20:34, 20:38, 20:40). [measured]
- Closer: `journalctl -b -2 -u bt-trial-auto`: "Stopping" 17:30:28 (logind "will power off now!" 17:30:27); **"Stopping timed
  out. Terminating." at 17:31:58**, `Control process exited, code=killed, status=15/TERM`, `Failed with result 'timeout'`,
  `Consumed 1min 29.873s CPU time`. No "controller does NOT respond", no verdict, no row, no `state-after.txt`.
  Mechanism: the **installed** (pre-2026-09-19) closer reads the whole kernel log without a budget and, because
  the trial saw SCO setups, decodes the captures before writing the row (`docs/STATUS.md` lines 202-208 [quoted]); on a three-day boot
  it used the 90 s the unit allows. This is the 10-11, 10-13 and 10-19 loss pattern, not the 11-07 probe artefact
  (the probe never ran).
- Lost: the row of that trial (duration 15:51:34 to 17:30:28 = 3 d 1 h 38 m 54 s = 265,134 s), its `state-after`, its
  `sco-params`. Recoverable from the journal and the exports: 25 SCO setups, 0 timeouts (above).
  The trial number 5 was then **issued again** to the next boot, and `E3/trial-05/` holds the second use's files
  (its `state-before.txt` and empty `steps.log` are older and tracked; `state-after.txt`/`sco-params.txt` are from the 11-10 close).

### 1bbf9aea (11-10 00:37 to 16:06), second "E3 #5" (row 20)
- Bluetooth: **worked**. Rampatch 00:37:20.709, NVM 00:37:21.083; no kernel `-p err` entry; no SCO setup at all
  (`journalctl -k -b -1 --grep "opcode 0x0428|opcode 0x043d|..."` → "No entries"); bluetoothd (`_COMM=bluetoothd -p warning`)
  shows a remote hands-free gateway device connecting and dropping at 01:04, 09:09 to 09:09:36, 10:23, 11:11 (SDP read
  "Host is down", "Device is already marked as connected"), so the adapter was in use; the HCI log has connects, scans and a
  disconnect at 09:09 to 09:10 (kernel opcode lines). [measured; the remote device's kind is not known]
- Closer: "Stopping" 16:06:30; **"controller does NOT respond" 16:06:31**; summary lines at 16:06:50; "Trial E3 #5: HANG after
  55746s", "cold power-off required before the next trial"; then `trial-summary: unrecognised trial_result "ended_unprobed" on line 16`
  and `denominator report FAILED`; unit failed. Why: the same as the 11-07 check. The kernel log at 16:06:30 shows
  a burst of HCI commands ending in `0x0c03` (Reset) (consistent with bluetoothd's adapter-off; [inferred]); the closer's
  probe (`hciconfig hci0 name`, `bt-trial` lines 111-123 [quoted README]) came one second later, so it could not succeed. Under the passive closer this boot would be `ended_unprobed`.
- The row (`failed`, `responds_after no`) is therefore wrong about the controller; right about `sco_sent 0`, `timeouts 0`,
  `usb_lost 0`.

### e68d6d90 (11-11 00:32 on)
- Bluetooth: working so far (rampatch 00:32:45, NVM 00:32:46, HCI commands from 00:32:58; `bt-trial-auto`: "E3 #6 opened at boot"
  00:32:58). Nothing to judge until it ends. The tracked/untracked state: `E3/trial-06/` new, untracked.

## What was lost, in one place

| item | state |
|---|---|
| E3 #5 (first, boot 045caff5) row | **lost**; facts recoverable (25 SCO setups, 0 timeouts, 3 d 1 h 38 m) |
| E3 #5 (second, boot 1bbf9aea) row | written, wrong verdict (probe artefact); number 5 duplicated |
| E3 #4 row | written; "HANG" wrong, "failed"/`usb_lost 1` right; the boot's real fault is BT-16 |
| E3 #3 row (10-30) | written; "HANG" is the same artefact (checked 11-07) |
| the denominator report | refuses on every row since the first `ended_unprobed` (line 16) |

## Proposed note text (for the maintainers to place; nothing was edited)

For a note beside trial 5's row in `evidence/trials/E3/trial-05/` (second use of the number):

> Trial "E3 #5" of 2026-11-10 (boot 1bbf9aea, 00:37:20 to 16:06:50): the row's `failed` / `responds_after no` is the
> closer's probe after bluetoothd had powered the adapter off (kernel log 16:06:30; probe 16:06:31). Bluetooth worked
> all boot: rampatch and NVM loaded at 00:37:20-21, no SCO link, no command timeout, no kernel error. The number 5 was
> opened twice: first on 2026-11-06 15:51:34 (boot 045caff5), whose close was killed by the unit's 90 s stop timeout at
> 2026-11-09 17:31:58, so that trial has no row; its facts from the journal: 3 d 1 h 38 m 54 s, 25 Setup Synchronous
> Connection requests, no command timeout, Bluetooth working throughout. The second use took the same directory.

For a row-less record of the first use, kept apart from `results.tsv` (as with the 10-23 trial's note):

> E3 #5 (first), boot 045caff5, 2026-11-06 15:51:34 to 2026-11-09 17:30:28: 25 SCO setup requests, 0 command timeouts,
> `usb_lost` 0 (no `USB disconnect` in the boot), no row because `bt-trial-auto`'s stop was killed after 90 s.
> Source: `journalctl -k -b -2` (command in this report's D file), export `/root/bt-journal-archive/boot-045caff5.export.zst`.

(The claim `usb_lost` 0 for 045caff5 is [not checked in this pass]; the archive grep for `usb 3-3: USB disconnect` found
only the start-up pattern, and none for that boot: `A-archive-boots.tsv` row `045caff5`: disconnect_within_180s 0,
disconnect_later 0. [measured])

## Same-mechanism summary

- 11-07 check's mechanism (probe after adapter-off): trial 3, trial 4 (partly), trial 5 second use.
- Different mechanism (stop killed by timeout, no verdict, no row): first E3 #5.
- Neither closer notices a boot without a working adapter (trial 4's real fault).
