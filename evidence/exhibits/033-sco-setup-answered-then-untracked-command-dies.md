# EX-033 — sco-setup-answered-then-untracked-command-dies

**Claim.** The controller **answered** `0x0428 Setup Synchronous Connection` in 72.8 ms,
allocated handle `0x0004`, completed the USB alternate-setting switch — and then a
*different* command died 2.076 s later, logged in the **bare** form
`command tx timeout` with no opcode. An untreated window of **35113.4 s (9 h 45 m)**
followed, with zero USB-layer lines and zero interventions.

**Relevance.** Two things the record did not have.

`BT-1` has been stated as "`0x0428` is submitted and never answered". **Here it was
answered**, and the fault arrived on the next command instead. That is the directly
observed version of what the source investigation deduced indirectly from `EX-006`'s
`cmd_cnt` behaviour, and it changes what the trigger claim can say.

And the bare spelling is the diagnostic: the kernel omits the opcode when `hdev->req_skb`
is NULL, i.e. **the command that died is not the one `hci_cmd_sync` was tracking**. The
failing command is anonymous *by construction*, which is why naming a single triggering
opcode has never quite worked.

## Extraction method

Re-runnable as-is on the affected machine, while boot `56afa828` is retained:

```console
$ journalctl -k -b 0 --since '2026-08-22 01:31:10.40' --until '2026-08-22 01:31:12.60' --no-pager -o short-iso-precise | grep -E 'opcode 0x0428|handle 0x0004|evt 5|Looking for Alt no|tx timeout'; journalctl -k -b 0 --since '2026-08-22 01:31:12' --no-pager | grep -cE 'usb 3-3|xhci_hcd|USB disconnect'; journalctl -b 0 --since '2026-08-22 01:31:12' --no-pager | grep -cE 'deregistering interface driver btusb|Resetting usb device|reset (full|high|low)-speed USB device|name hci[0-9]+ blocked 1'
```

## Output

Verbatim, 8 line(s), exit status 0.

```
2026-08-22T01:31:10.402706+02:00 n kernel: hci0 opcode 0x0428 plen 17
2026-08-22T01:31:10.475497+02:00 n kernel: hci0: hcon 0000000021eee082 handle 0x0004
2026-08-22T01:31:10.475608+02:00 n kernel: hci0 evt 5
2026-08-22T01:31:10.475637+02:00 n kernel: Looking for Alt no :6
2026-08-22T01:31:10.475661+02:00 n kernel: Looking for Alt no :3
2026-08-22T01:31:12.551489+02:00 n kernel: Bluetooth: hci0: command tx timeout
0
0
```

The two zeros are the window: **no USB-layer line and no intervention** between the fault
and this capture, 35113.4 s later.

## The sequence

```
01:31:10.402706  hci0 opcode 0x0428 plen 17           SCO setup submitted
                 ┃ 72.791 ms
01:31:10.475497  hcon … handle 0x0004                 ← ANSWERED. A handle was allocated.
01:31:10.475608  hci0 evt 5                           Synchronous Connection Complete
01:31:10.475637  Looking for Alt no :6 / :3           btusb switches USB alt-setting
                 ┃ 2.076 s
01:31:12.551489  command tx timeout                   ← bare form: no opcode
01:31:19.9…      len 27 mtu 9  (repeatedly)           SCO data still flowing afterwards
                 ┃
                 ┃  35113.4 s — 9 h 45 m
                 ┃  22 command timeouts. 0 USB-layer lines. 0 interventions.
```

## Against the previous statement of the trigger

| | earlier instrumented failures | this one |
|---|---|---|
| `0x0428` submitted | ✔ | ✔ |
| controller answered it | **no** — never answered | **yes, in 72.8 ms**, handle `0x0004` |
| `Looking for Alt no` | ✔ | ✔ |
| what timed out | a named command (`0x0406`, `0x0c1a`, `0x041f`) | **an unnamed one** — bare `command tx timeout` |
| SCO→first timeout | 4.1–55.2 s | **2.076 s** |

**2.076 s is a new floor**, below the previous 4.138 s.

## What the bare form means, and why it matters

The kernel prints the opcode from `hdev->req_skb`. When that pointer is NULL it prints
`command tx timeout` with nothing between "command" and "tx". So the bare form is not a
formatting quirk — it says **the command that timed out was not the one the synchronous
request machinery was tracking**.

That reframes a question this project has asked repeatedly. The trigger has been sought as
a *named opcode*, and the search kept producing a distribution rather than a constant
(4.1 s, 7.6 s, 16.2 s, 55.2 s, 155.8 s). If the dying command is frequently anonymous,
some of that spread is the search looking for the wrong object.

⚠️ **This also means the count has been wrong wherever the bare form was excluded.**
`tools/bt-snapshot` matched `command 0x[0-9a-f]+ tx timeout` at three sites until
`1795735`. On this window the *first* timeout is the bare form, so the old pattern would
have anchored the window at `01:32:22` instead of `01:31:12` — reporting it **70 s
shorter** than it was. The defect was found by the Test Suite Maintainer before this
window occurred; this is its first real case.

## Reading

**What this establishes.** The controller can complete a legacy SCO setup — it answered
`0x0428` and allocated a handle. So `BT-1` is not "this controller cannot do
`0x0428`". Something after the setup, on the alternate-setting-switched interface, kills
an untracked command.

**What it does not establish.** Whether the alt-setting switch causes it. `EX-030` records
the switch firing with nothing following, and `EX-031` records `0x043D` answered with the
switch and 17 minutes of healthy SCO afterwards. So the switch alone is not sufficient, and
`n = 1` for the answered-then-died shape.

**The untreated window is the fifth**, and it changes nothing about the duration argument,
which `EX-016` settled at 4332 s and `EX-029` closed at 47338 s. It is recorded as another
instance, not as another record — the marginal value of a longer window is now nil, and the
operator was right to say so.

**Terminator.** Ends in a deliberate recovery attempt, recorded separately.

## Provenance

| field | value |
|---|---|
| captured | `2026-08-22T11:16:27+02:00` |
| kernel | `7.0.0-29-generic` — corrected 2026-08-23; this exhibit was hand-written and copied `7.0.0-28-generic` forward from `EX-029` without checking. Boot `56afa828` ran `-29`, verified from its own `Linux version` line |
| device | `13d3:3503` QCA9377 (ROME) |
| exit status | `0` |
| redacted | `no` |
| session | `evidence/sessions/20260822-111627-untreated-window-9h-then-recovery-attempt` |
