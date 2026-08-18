# EX-031 — enhanced-sco-setup-answered-and-survived

**Claim.** The controller was given a synchronous-link setup by the **Enhanced** command
`0x043D` — not the `0x0428` every instrumented failure has used — **answered it in 64.7 ms**,
completed the USB alternate-setting switch, carried SCO traffic for roughly 17 minutes, and
was still healthy afterwards. Two `corrupted SCO packet` lines appeared during that traffic,
a kernel message this record has not previously contained.

**Relevance.** `BT-1` names `HCI_Setup_Synchronous_Connection` (`0x0428`) as the wedging
command. This is the first recorded instance of the *other* setup command reaching this
controller, and it did not wedge. If that distinction holds it narrows the defect from
"synchronous-link setup" to one specific opcode — which is a materially different bug
report, and a materially different patch. **`n = 1`, and the exhibit claims no more.**

⚠️ Peer addresses are redacted to the documented placeholder space; the real addresses
appear only in the sanitised session directory.

## Extraction method

Re-runnable as-is on the affected machine, while boot `e9399c8c` is retained:

```console
$ journalctl -k -b 0 --no-pager | grep -cE 'opcode 0x0428'; journalctl -k -b 0 --no-pager | grep -cE 'opcode 0x043d'; journalctl -k -b 0 --no-pager | grep -cE 'tx timeout'; journalctl -k -b 0 --since '2026-08-18 18:24:32.16' --until '2026-08-18 18:24:32.25' --no-pager -o short-iso-precise | grep -E 'opcode 0x043d|handle 0x0008|evt 5|Looking for Alt no|corrupted SCO packet'
```

## Output

Verbatim, 9 line(s), exit status 0.

```
0
1
0
2026-08-18T18:24:32.162650+02:00 n kernel: hci0 opcode 0x043d plen 59
2026-08-18T18:24:32.227348+02:00 n kernel: hci0: hcon 000000008928b303 handle 0x0008
2026-08-18T18:24:32.227453+02:00 n kernel: hci0 evt 5
2026-08-18T18:24:32.227495+02:00 n kernel: Looking for Alt no :6
2026-08-18T18:24:32.227554+02:00 n kernel: Looking for Alt no :3
2026-08-18T18:24:32.240341+02:00 n kernel: Bluetooth: hci0: corrupted SCO packet
```

Line 1 is **zero** occurrences of `0x0428` this boot; line 2 is **one** occurrence of
`0x043d`; line 3 is **zero** command timeouts. The positive control for those zeroes is
`EX-030`'s, re-checked here: 7537+ `opcode 0x` lines this boot with `bt-dyndbg` active and
20 enabled `btusb` debug sites, so the scan can see.

## The sequence

```
18:24:32.162650  hci0 opcode 0x043d plen 59            Enhanced Setup Synchronous Connection
                 ┃  64.698 ms
18:24:32.227348  hcon ... handle 0x0008                 ← THE CONTROLLER ANSWERED
18:24:32.227453  hci0 evt 5                             Synchronous Connection Complete
18:24:32.227495  Looking for Alt no :6
18:24:32.227554  Looking for Alt no :3                  USB alt-setting switch, as always
18:24:32.230379  len 90 mtu 9
18:24:32.240341  Bluetooth: hci0: corrupted SCO packet
18:24:32.258340  len 27 mtu 9
18:24:37.489356  Bluetooth: hci0: corrupted SCO packet
                 ┃  ~17 minutes of SCO traffic
18:41:55         wireplumber: Failure in Bluetooth audio transport .../sep7/fd12
18:41:55         avdtp.c:connection_lost() Disconnected
18:41:56         adapter.c:dev_disconnected() disconnected, reason 3
```

## Against the failing signature

| | every instrumented failure | this event |
|---|---|---|
| setup command | `0x0428` Setup Synchronous Connection | **`0x043D` Enhanced** Setup Synchronous Connection |
| controller answered it? | **no** — never answered | **yes, in 64.7 ms**, handle `0x0008` |
| `Looking for Alt no` | ✔ | ✔ |
| next command | unanswered, `tx timeout` 4.1–55.2 s later | answered; **0 timeouts this boot** |
| `setting interface failed (110)` | ✔ | absent |
| outcome | HCI non-response, window opens | link ran ~17 min, controller healthy after |

**The alternate-setting switch is not sufficient on its own.** It fired here exactly as it
does in every failure, and nothing followed it. That removes one candidate mechanism: the
`btusb` alt-setting switch alone does not wedge this controller.

## The corrupted packets, recorded not explained

`Bluetooth: hci0: corrupted SCO packet` appears twice, 5.2 s apart, alongside debug lines
reading `len 90 mtu 9` and `len 27 mtu 9`. `hciconfig` reports the controller's `SCO MTU`
as `50:8`. Three different numbers for what a SCO packet should be, and no attempt is made
here to reconcile them — the message is recorded because it is new to this record and
because it sits directly on the wideband-speech path that
`investigation-bluetooth-controller-hang-2026-08-16-2353` is reading in source.

## How it ended

Not by a controller fault. `wireplumber` reported a transport failure, BlueZ logged
`connection_lost()`, and `dev_disconnected()` recorded **reason 3** — BlueZ's code for the
remote device terminating the connection. The controller answered HCI throughout and is
still enumerated and responding at the time of writing, on the same boot.

## Reading

**What this establishes.** This controller can complete a synchronous-link setup. It did so
by the Enhanced command, promptly, and carried the link. Whatever `BT-1` is, it is not "the
QCA9377 cannot do SCO".

**The distinction worth testing.** `0x0428` and `0x043D` differ in that the Enhanced form
carries explicit coding-format parameters — the path used for wideband speech (mSBC) rather
than CVSD. Every failure in this record used the legacy command; the one Enhanced setup
succeeded. That is a hypothesis with `n = 1` on one side, and it is **not** evidence that
`0x043D` is safe.

**What would settle it.** A `0x043D` setup and a `0x0428` setup on the same device in the
same session, both instrumented. `bt-sco --window` already compares whole event windows and
has not been run across these two. If the split holds, the bug report's trigger section
narrows from "SCO/HFP setup" to a named opcode, and `docs/fix-proposal.md`'s ladder gains a
reason to care which coding format is negotiated.

**What it does not establish.** One Enhanced setup, one device, one session. It does not
show that `0x043D` cannot wedge the controller, nor that `0x0428` always does — `EX-030`
records a boot in which HFP cycled without reaching either. The corrupted-packet lines are
unexplained and may or may not belong to the same story.

## Provenance

| field | value |
|---|---|
| captured | `2026-08-18T18:44:15+02:00` |
| kernel | `7.0.0-28-generic` |
| boot id | `e9399c8c` |
| device | `13d3:3503` QCA9377 (ROME); peer `MOMENTUM 4` |
| exit status | `0` |
| redacted | `yes` — peer address replaced with a documented placeholder |
| session | `evidence/sessions/20260818-184415-enhanced-sco-answered-controller-survived` |
