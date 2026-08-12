# EX-007 — autonomous-profile-switch-triggers-hang

**Claim (CORRECTED — see the refutation below).** The hang requires no operator action at the moment it occurs. In this incident BlueZ issued `HCI_Setup_Synchronous_Connection` 36 ms after the A2DP transport went idle, and **the controller never answered it**. What is established is the *consequence*; the claim originally made here about the *cause* of that command has been refuted.

**Relevance.** This explains why the failure appeared random and why it resisted deliberate reproduction — the operator kept it alive by interacting with it, and it died 77 s after they stopped, when a video ended. It also unifies every previously unexplained symptom: the hands-free/mono fallback, the recurring 'setting interface failed' (btusb changing the USB alternate setting to allocate isochronous bandwidth for SCO), and the AVDTP-teardown early-warning signature. It yields a minimal reproducer: play audio to a headset, stop it, wait.

## ⚠️ Refuted on 2026-08-12, one boot later

The original claim — that the A2DP transport reaching IDLE causes PipeWire to switch to
HFP and issue SCO setup — **does not hold**. In the following boot the transport reached
IDLE at least five times (05:49:03, 05:49:07, 05:49:16, 05:51:33, 05:53:37) and **no SCO
setup followed any of them**. The controller survived.

A second candidate, that the GNOME Settings Sound panel being the active PipeWire client
is the trigger, also fails the same test: that boot logged 15 `[GNOME Settings]` client
entries and two Bluetooth-panel launches, again with no SCO setup.

So the 36 ms adjacency was real but not causal, and the trigger for the SCO setup remains
**unidentified**. This is the same error the project has now made four times: converting a
temporal adjacency into a causal claim without checking how often the antecedent occurs
without the consequent.

**What survives, and it is the part that matters upstream:** `HCI_Setup_Synchronous_Connection`
(0x0428) was issued exactly once across every boot examined, and that single occurrence was
never answered, and the controller's failure began at that boundary. ("Began at that
boundary" rather than "was caused by it": with a single observation, 0x0428 may be the
trigger, or merely the first command to expose a state that was already broken.)
Whatever prompted BlueZ to send it is a
userspace scheduling detail; a controller that stops responding to a standard HCI command
is a driver/firmware defect regardless of what caused the command to be sent.

**Consequence for testing.** Waiting for the trigger to recur by chance is now known to be
unreliable. The command should be provoked deliberately instead — forcing the HFP profile
issues SCO setup directly:

```console
$ pactl set-card-profile bluez_card.<ADDR> headset-head-unit
```

or the equivalent profile change in Settings → Sound, which is step 4 of the trial protocol
and is the step that most needs running.

## Extraction method

Re-runnable as-is on the affected machine:

```console
$ journalctl -b 0 --since '2026-08-12 04:59:00' --until '2026-08-12 05:00:20' --no-pager -o short-iso-precise -u bluetooth | grep -E 'media_player_set_status|transport_set_state|sink_set_state|avdtp_sep_set_state' | tail -6; echo; echo '--- kernel side ---'; journalctl -k -b 0 --since '2026-08-12 05:00:16' --until '2026-08-12 05:00:19' --no-pager -o short-iso-precise | grep -iE 'opcode 0x0428|command tx timeout'
```

## Output

Verbatim, 9 line(s), exit status 0.

```
2026-08-12T04:59:01.460742+02:00 n bluetoothd[8257]: profiles/audio/player.c:media_player_set_status() stopped
2026-08-12T05:00:16.521027+02:00 n bluetoothd[8257]: profiles/audio/transport.c:transport_set_state() State changed /org/bluez/hci0/dev_AA:BB:CC:00:00:01/sep7/fd8: TRANSPORT_STATE_ACTIVE -> TRANSPORT_STATE_SUSPENDING
2026-08-12T05:00:16.559856+02:00 n bluetoothd[8257]: profiles/audio/avdtp.c:avdtp_sep_set_state() stream state changed: STREAMING -> OPEN
2026-08-12T05:00:16.559870+02:00 n bluetoothd[8257]: profiles/audio/sink.c:sink_set_state() State changed /org/bluez/hci0/dev_AA:BB:CC:00:00:01: SINK_STATE_PLAYING -> SINK_STATE_CONNECTED
2026-08-12T05:00:16.559980+02:00 n bluetoothd[8257]: profiles/audio/transport.c:transport_set_state() State changed /org/bluez/hci0/dev_AA:BB:CC:00:00:01/sep7/fd8: TRANSPORT_STATE_SUSPENDING -> TRANSPORT_STATE_IDLE

--- kernel side ---
2026-08-12T05:00:16.595818+02:00 n kernel: hci0 opcode 0x0428 plen 17
2026-08-12T05:00:18.764738+02:00 n kernel: Bluetooth: hci0: command tx timeout
```

## Provenance

| field | value |
|---|---|
| captured | `2026-08-12T05:24:36+02:00` |
| kernel | `7.0.0-28-generic` |
| boot id | `c1315c25` |
| device | `13d3:3503` QCA9377 (ROME) |
| exit status | `0` |
| redacted | `no` |
