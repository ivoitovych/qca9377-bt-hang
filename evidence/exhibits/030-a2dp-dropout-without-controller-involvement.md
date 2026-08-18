# EX-030 — a2dp-dropout-without-controller-involvement

**Claim.** An audible playback dropout on a **third** device — `Tronsmart T8`, named from
the journal — in which the controller was never involved. The A2DP stream cycled
`STREAMING → OPEN → CLOSING → IDLE → CONFIGURED → OPEN → STREAMING` in **602 ms**, driven
by the audio server releasing the transport. Zero HCI SCO setups, zero disconnect commands,
zero USB alternate-setting switches and zero command timeouts this boot — against a
positive control of 7537 opcode lines.

**Relevance.** This is a **negative control the record did not have**. Every dropout in
this investigation until now was the controller wedging. Here the same *class* of event —
a profile transition on an audio device, with the GNOME Bluetooth panel open, which
`EX-002` shows drives this controller into desync — occurred and the controller stayed
healthy. It establishes that "the audio cut out" is not diagnostic of `BT-1` on this
machine, and gives the fault a boundary it previously lacked.

⚠️ Device addresses are redacted to the documented placeholder space; the real address
appears only in the sanitised session directory. `AA:BB:CC:00:00:01` below is one device.

## Extraction method

Re-runnable as-is on the affected machine, while boot `e9399c8c` is retained. The four
counts come first because they are the claim; the stream cycle follows.

```console
$ journalctl -k -b 0 --no-pager | grep -cE 'opcode 0x'; journalctl -k -b 0 --no-pager | grep -cE 'opcode 0x0428'; journalctl -k -b 0 --no-pager | grep -cE 'Looking for Alt no'; journalctl -k -b 0 --no-pager | grep -cE 'tx timeout'; journalctl -b 0 --since '2026-08-17 17:37:47.5' --until '2026-08-17 17:37:48.3' --no-pager -o short-iso-precise | grep -E 'SUSPEND request succeeded|stream state changed|SINK_STATE_CONNECTED -> SINK_STATE_PLAYING'
```

## Output

Verbatim, 13 line(s), exit status 0. Device address redacted.

```
7537
0
0
0
2026-08-17T17:37:47.614345+02:00 n bluetoothd[2862]: profiles/audio/avdtp.c:avdtp_parse_resp() SUSPEND request succeeded
2026-08-17T17:37:47.614354+02:00 n bluetoothd[2862]: profiles/audio/avdtp.c:avdtp_sep_set_state() stream state changed: STREAMING -> OPEN
2026-08-17T17:37:47.620392+02:00 n bluetoothd[2862]: profiles/audio/avdtp.c:avdtp_sep_set_state() stream state changed: OPEN -> CLOSING
2026-08-17T17:37:47.620449+02:00 n bluetoothd[2862]: profiles/audio/avdtp.c:avdtp_sep_set_state() stream state changed: CLOSING -> IDLE
2026-08-17T17:37:48.144737+02:00 n bluetoothd[2862]: profiles/audio/avdtp.c:avdtp_sep_set_state() stream state changed: IDLE -> CONFIGURED
2026-08-17T17:37:48.166704+02:00 n bluetoothd[2862]: profiles/audio/avdtp.c:avdtp_sep_set_state() stream state changed: CONFIGURED -> OPEN
2026-08-17T17:37:48.192520+02:00 n bluetoothd[2862]: profiles/audio/avdtp.c:avdtp_sep_set_state() stream state changed: OPEN -> STREAMING
2026-08-17T17:37:48.192531+02:00 n bluetoothd[2862]: profiles/audio/sink.c:sink_set_state() State changed /org/bluez/hci0/dev_AA_BB_CC_00_00_01: SINK_STATE_CONNECTED -> SINK_STATE_PLAYING
```

**Line 1 is the positive control and it is load-bearing.** Lines 2–4 are zero, and a zero
from a scan is not a result until something proves the scan can see. 7537 `opcode 0x` lines
this boot, `bt-dyndbg` active, and 20 enabled `btusb` debug sites in
`/sys/kernel/debug/dynamic_debug/control` establish that the absent lines are absent from
the machine rather than from the logging.

## The sequence

```
17:36:39      app-gnome-gnome-bluetooth-panel-54212.scope   Settings panel opened
17:37:19.870  input: Tronsmart T8 (AVRCP) as .../input22    device present
17:37:22      HFP gateway  connected -> disconnected
              ┃
17:37:47.590  wireplumber (owner :1.86) issues Release on the media transport
17:37:47.614  AVDTP SUSPEND request succeeded               ← the peer answered
17:37:47.620  stream OPEN -> CLOSING -> IDLE                ← profiles torn down
17:37:48.144  stream IDLE -> CONFIGURED
17:37:48.174  input: Tronsmart T8 (AVRCP) as .../input23    re-registered
17:37:48.192  stream OPEN -> STREAMING                      ← playback resumed
              ┃   602 ms end to end
17:37:50.27   HFP gateway  connecting -> connected
17:37:50.38   wireplumber: RFCOMM receive command but modem not available: AT+BTRH?
17:37:50.40   wireplumber: RFCOMM receive command but modem not available: AT+CCWA=1
```

## The ACL link never dropped

The kernel's connection object is the same before, during and after:

```
17:37:19.848  hcon 0000000053bde63f
17:37:22.269  hcon 0000000053bde63f
17:37:48.151  hcon 0000000053bde63f
17:37:50.270  hcon 0000000053bde63f
```

A baseband link that dropped and re-established would be a different `hcon`. The same
pointer throughout means the disconnect and reconnect happened **above** the ACL link, at
L2CAP/AVDTP, over a connection that stayed up the whole time. Consistent with the zero
count for `opcode 0x0406`: no Disconnect was ever commanded.

## Reading

**What happened.** `wireplumber` released the A2DP transport; BlueZ suspended the stream,
its policy plugin disconnected the now-idle profiles, and playback re-established itself
602 ms later. The initiator was the **audio server**, not the controller and not the
peripheral. "The connection was lost" is the right description of what was heard and the
wrong description of what occurred — nothing was lost.

**Why it is worth an exhibit.** Three of this investigation's ingredients were present at
once and produced nothing: a profile transition on an audio device, an HFP gateway
connect/disconnect cycle, and the GNOME Bluetooth panel open — the panel `EX-002` shows
deterministically drives this controller into HCI desync. The controller answered
throughout. **The fault needs more than these to fire**, and specifically it did not reach
`0x0428 Setup Synchronous Connection`, which is the boundary every instrumented failure has
crossed.

**The distinguishing test, stated so it can be reused.** A dropout is `BT-1` only if the
journal shows `opcode 0x0428` followed by `Looking for Alt no` and then an unanswered
command. This event has none of the three. An operator cannot tell the two apart by ear,
and until now the record offered nothing that said so.

**What it does not establish.** One occurrence, one device, one panel session. It does not
show that HFP cycling is *safe* on this controller — `EX-026` has an HFP-adjacent sequence
killing it within seconds — only that this particular transition did not reach the
triggering command. Nor does it explain why `wireplumber` released the transport; the
journal records the release, not its cause.

**A third device, for the peripheral-specificity question.** `EX-024` established the fault
on two vendors. This exhibit adds `Tronsmart T8` to the *devices exercised* on this
machine, but it is **not** a third reproduction — the fault did not occur here. It is
recorded so the device list is not read as a list of failures.

## Provenance

| field | value |
|---|---|
| captured | `2026-08-17T17:54:14+02:00` |
| kernel | `7.0.0-28-generic` |
| boot id | `e9399c8c` |
| device | `13d3:3503` QCA9377 (ROME); peer `Tronsmart T8` |
| exit status | `0` |
| redacted | `yes` — peer address replaced with a documented placeholder |
| session | `evidence/sessions/20260817-175414-tronsmart-a2dp-dropout-controller-survived` |
