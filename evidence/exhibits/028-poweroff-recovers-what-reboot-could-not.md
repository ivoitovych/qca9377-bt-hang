# EX-028 — poweroff-recovers-what-reboot-could-not

**Claim.** From the same stage-2 state, eleven minutes apart, a `reboot.target` transition
left the controller unenumerable and a `poweroff.target` transition brought it back in
1.020 s. Both terminators are journal lines, not accounts.

**Relevance.** `EX-027` established that the wedge survives a host reboot and stated
explicitly that it could not say whether removing power clears it — no logged power
removal existed on either side of that pair. This supplies one, against the same failed
state, and closes the question in the direction the record could not previously support.

## Extraction method

Re-runnable as-is on the affected machine, while boots `60ddb417`, `ea26d5d0` and
`7dd5d642` are retained:

```console
$ journalctl -b -2 --no-pager -o short-iso | grep -E 'Reached target (reboot|poweroff)' | tail -1; journalctl -k -b -1 --no-pager -o short-monotonic | grep -E 'New USB device found, idVendor=13d3|unable to enumerate' | head -1; echo '---'; journalctl -b -1 --no-pager -o short-iso | grep -E 'Reached target (reboot|poweroff)' | tail -1; journalctl -k -b 0 --no-pager -o short-monotonic | grep -E 'New USB device found, idVendor=13d3|unable to enumerate' | head -1
```

## Output

Verbatim, 5 line(s), exit status 0.

```
2026-08-16T18:46:06+02:00 n systemd[1]: Reached target reboot.target - System Reboot.
[   86.861877] n kernel: usb usb3-port3: unable to enumerate USB device
---
2026-08-16T18:57:34+02:00 n systemd[1]: Reached target poweroff.target - System Power Off.
[    1.020310] n kernel: usb 3-3: New USB device found, idVendor=13d3, idProduct=3503, bcdDevice= 0.01
```

## The three transitions, in order

| # | at | systemd target | controller going in | next boot |
|---|---|---|---|---|
| 1 | 15:29:59 | `reboot.target` | **stage 1** — enumerated, HCI silent | enumerates at `+1.107 s` |
| 2 | 18:46:06 | `reboot.target` | **stage 2** — off the bus | **fails**: `unable to enumerate` at `+86.9 s` |
| 3 | 18:57:34 | `poweroff.target` | **stage 2** — off the bus | enumerates at `+1.020 s` |

Rows 2 and 3 are the controlled comparison: the same failed state going in, eleven
minutes apart, on the same kernel and the same machine, differing in the transition and
in nothing else the journal records. Row 1 is what `EX-027` paired against row 2 and is
kept here because it shows the stage-1 case behaving like the power-off case.

## State after the power-off

```
/sys/bus/usb/devices/3-3   exists
/sys/class/bluetooth/      hci0
rfkill                     0: hci0: Bluetooth — soft no, hard no
hci0                       UP RUNNING PSCAN   commands:105  errors:0  sco:0
bluetooth.service          active
```

## Reading

**What this establishes.** Removing power clears the wedge; restarting the kernel does
not. Taken with `EX-027`, the failed state is on the device's side of the wire and it is
cleared by loss of power rather than by any host-side reinitialisation — the driver being
reloaded, the HCI device destroyed and recreated, and xHCI re-initialised all failed to
touch it, and dropping VBUS did.

**Why the pairing is worth more than either half.** A single recovery after a power-off
would be consistent with the device having recovered on its own over eleven minutes. What
excludes that is row 2: the device had already been given a full kernel restart, 116 s of
downtime and four addressing attempts from the same failed state, and stayed dead. The
difference between the rows is the transition, and the journal names both.

**`n = 1` on each row.** The contrast is direct and both terminators are logged, which is
stronger than the record had this morning, but it is one instance of each. In particular
this does not establish *how long* power must be removed — the gap here was 126 s of
wall-clock between the poweroff line and the next boot, and nothing distinguishes what
part of that mattered.

**What it retires.** `EX-022`'s power-button-hold recovery was the only prior instance and
rested on the operator's account for the power removal itself, with only the enumeration
afterwards evidenced. That claim no longer needs the account: this exhibit carries the
same conclusion with `poweroff.target` in the journal.

**Practical consequence, which is not a fix.** After a stage-2 collapse the recovery is a
full power-off; a reboot wastes several minutes and returns the machine in the same broken
state. That is worth knowing on a shared machine and it changes nothing about the
underlying defect.

## Provenance

| field | value |
|---|---|
| captured | `2026-08-16T19:02:07+02:00` |
| kernel | `7.0.0-28-generic` |
| boot id | `7dd5d642` |
| device | `13d3:3503` QCA9377 (ROME) |
| exit status | `0` |
| redacted | `no` |
| session | `evidence/sessions/20260816-190207-poweroff-recovers-from-stage2-20260816` |
| closes | the question `EX-027` left open |
