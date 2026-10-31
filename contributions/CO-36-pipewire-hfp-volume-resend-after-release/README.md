# CO-36 — PipeWire: the delayed HFP volume resend outlives the SCO audio link

**State:** reproduced (journal, HCI capture and source), 2026-10-31. Nothing is filed.

**Target:** PipeWire, `spa/plugins/bluez5/backend-native.c` (HFP audio gateway).

**Comes from:** `U15` (the MOMENTUM 4 announces "mute on" when it receives `+VGM: 0`) and `U14`
(WirePlumber 0.4.17 switches a headset to hands-free while any microphone records). On
2026-10-31 at 03:33 the operator heard "mute on" **twice** at the end of a dictation; the
second announcement came from a `+VGM: 0` sent after the SCO audio link was already closed.

**Terms.** "Link" below means the SCO/eSCO audio connection. The RFCOMM control connection
(HFP's service-level connection) stays up the whole time, and HFP lets the audio gateway send
`+VGS`/`+VGM` over it without an audio connection (two reviewers cite HFP 1.10 §4.29.1; the
specification text was not checked here). So a volume command without audio is not wrong in
itself. What these facts show is a resend scheduled *for one audio link* that is still sent
after that link has ended.

> **PipeWire's contributor rules apply** (in PipeWire's source tree, read 2026-10-31). No tool-written issue text, merge request description, commit message or
> reply to reviewers, and no automated posting. The operator writes and files the report in
> person; verbatim logs may be attached. **This folder holds evidence only:** facts, verbatim
> logs, and pointers into the code. It contains no drafted report text, and nothing here is sent
> anywhere.

## The facts

**1. What the code does** (upstream master `4cfc4711`, 2026-10-30, and the `1.0.5` tag; the
functions below do the same in both, though the file as a whole changed a lot; links below):
- When an audio link is ready, `sco_ready()` sends `+VGS`/`+VGM` at once and arms a 1.5 s
  timer to send them again (`rfcomm_ag_sync_volume(td->rfcomm, false)` then `(…, true)`).
  Added by `d82b3d647` (Pauli Virtanen, 2022-06-16, "bluez5: backend-native: set HFP/HSP volume
  when connecting"); the comment above the calls gives the reason (headsets that change their
  HFP volume during A2DP without reporting it; the Sennheiser HD-250BT).
- The timer is stopped in two places only: when a codec selection `AT+BCS=` arrives, and in the
  timer's own handler. `git log -S volume_sync_stop_timer` on master lists only `d82b3d647`.
- Releasing the link does not stop it: `sco_release_cb()` sets the transport idle, sends
  `+CIEV: 2,0` and calls `sco_destroy_cb()`, which closes the SCO socket. Neither touches the
  timer.
- A second way a link ends does not stop it either: when the SCO socket reports a hang-up or an
  error (for example the headset closes the audio link), `sco_event()` sets the transport idle
  and closes the socket itself, without `sco_release_cb()` or `sco_destroy_cb()`. 1.0.5 logs
  this as `error on SCO socket`, master as `SCO socket hangup` or `SCO socket error`. All four
  cases below are local releases; this path was not observed in them. The journal since
  2026-10-22 has it twice, neither with a late resend: 2026-10-23 00:51:09, 14 s after that
  link's `acquire complete` (the resend had gone out at 00:50:56.743), and 2026-10-22 12:05:39,
  with no `acquire complete` in the 15 minutes before it (no timer armed). (1.0.5 prints
  `strerror(errno)` there, not the socket's error, so the text after the colon,
  `Invalid or incomplete multibyte or wide character`, means nothing.)
- `sco_ready()` sends the first pair *before* it sets the transport active (master L2811–2814,
  1.0.5 L1565–1568), and `rfcomm_ag_set_volume()` also sends the user's volume changes
  (`sco_set_volume_cb()`).
- When the timer fires, its handler checks only `rfcomm->transport != NULL` (the HFP transport
  object, which lives as long as the RFCOMM connection) and calls `rfcomm_ag_set_volume()`
  for both volumes. That function checks hardware-volume support and whether the volume is
  active, not whether a link is open, then sends the `+VGS`/`+VGM` reply.
- So when a link is released less than 1.5 s after it became ready, the second pair goes to the
  headset over RFCOMM after that audio link is gone.

**2. Four cases on this laptop** (local time, CET/CEST; times from the journal and the HCI
capture; full logs in `logs/`):

| case | headset | what released the link | link ready → released | resend vs release |
|---|---|---|---|---|
| A, 2026-10-22 20:25:27 | MOMENTUM 4 | at connect: WirePlumber chose `headset-head-unit-msbc` before A2DP was up, then switched to `a2dp-sink` | 27.478 → 27.897 (0.42 s) | resend at 28.978: **1.081 s after** `Transport … released`, 1.017 s after `Disconnect Complete` |
| B, 2026-10-23 23:53:10 | Lenovo thinkplus GM2 pro | end of a dictation: WirePlumber's switch back to `a2dp-sink` | 11.274 → 12.703 (1.43 s) | resend at 12.774: **72 ms after** `released`, between `Disconnect` (12.703) and `Disconnect Complete` (12.896) |
| C, 2026-10-31 02:58:54 | MOMENTUM 4 | same as B | 55.067 → 56.576 (1.51 s) | resend at 56.567: **9 ms before** `released`; the operator heard "mute on" once |
| D, 2026-10-31 03:33:22 | MOMENTUM 4 | same as B | 22.469 → 23.925 (1.46 s) | resend at 23.969: **44 ms after** `released`, 38 ms after `Disconnect Complete` (23.931); the operator heard "mute on" twice |

In A, B and D PipeWire's own log shows the order: `acquire complete` → `RFCOMM >> +VGS`/`+VGM`
→ `Transport /org/bluez/hci0/dev_…/fdNN released` → `RFCOMM >> +CIEV: 2,0` → `RFCOMM >> +VGS`
/`+VGM` (see the `*.key-lines.txt` files). C is the control: there the resend comes just
*before* `released`. The HCI capture (host to controller, recorded on the laptop, not a radio
capture) shows the same `+VGS`/`+VGM` as outgoing ACL data after the eSCO `Disconnect`
command; in A and D also after `Disconnect Complete`, in B before it.

**3. How often.** `scripts/hfp-late-vgm-scan.py` over every boot in the journal (2026-10-22 to
2026-10-31, `logs/scan-all-boots.txt`): 91 hands-free links; 11 released within 3 s of their
`+CIEV: 2,1`; in 3 of those the resend went out after the release (A, B, D). In the other 8 it
went out 8 to 405 ms before the release. Apart from A, all 10 short links ended the same way:
WirePlumber's switch back to `a2dp-sink` (`Restoring profile of …`) 1.82 to 1.95 s after
`+CIEV: 2,1` (in B, C, D and 2026-10-31 04:01:45, the ones checked, 2.0 s after the browser
closed its recording stream). So it is a race: the resend comes
1.5 s after the link became ready, and becoming ready took 0.04 to 0.52 s.

These counts describe this laptop's journal, not a general rate, and the scan is a heuristic:
it follows one link at a time from `+CIEV: 2,1` to `+CIEV: 2,0` (so it relies on the dummy call
indicator and does not tell two headsets apart if both are connected), it recognises the
resend as a `+VGM` 1.45 to 1.55 s after the link's first one (a `+VGS`-only resend is missed),
and it uses journal receive times. A, B and D were each checked by hand against the HCI capture.

**4. What the listener hears.** The MOMENTUM 4 reports a microphone gain of 0 at every connect,
PipeWire stores it, and the headset announces a received `+VGM: 0` as "mute on" (`U15`). So with
this headset a late resend can be heard: in D the operator heard "mute on" twice, in C (resend
before release) once. Whether A was heard is not recorded, and nothing was measured
acoustically. Whether the GM2 pro (`+VGM: 9`) announces anything is not known. The late resend
itself does not depend on the headset. Removing the late resend would still leave one "mute on"
per link with this headset, from the first `+VGM: 0` (`U15`, a separate question).

## Environment

Ubuntu 24.04 · kernel `7.0.0-42-generic` · PipeWire `1.0.5-1ubuntu3.3` · WirePlumber
`0.4.17-1ubuntu4.1` (Lua policy as packaged, automatic switch to hands-free on) · BlueZ
`5.72-0ubuntu5.8` · btmon 5.72 · controller Qualcomm QCA9377 (USB `13d3:3503`), mSBC over eSCO.

Logging: a systemd drop-in sets `WIREPLUMBER_DEBUG=D:spa.bluez5,spa.bluez5.native,spa.bluez5.device,spa.bluez5.source.sco,spa.bluez5.quirks,script/*,m-default-nodes,m-default-profile,wireplumber,pw`
(and `PIPEWIRE_DEBUG=3`, `PIPEWIRE_DEBUG=mod.protocol-pulse*:3`); that is where the
`RFCOMM >>`, `acquire complete` and `released` lines come from. The HCI capture is the
project's always-on `bt-capture` (btsnoop), decoded with btmon.

## Source pointers

| what | master `4cfc4711` | `1.0.5` |
|---|---|---|
| the immediate send and the 1.5 s resend, in `sco_ready()` | [L2796–2812](https://gitlab.freedesktop.org/pipewire/pipewire/-/blob/4cfc471123a0e041fcd6fec5887c40dbddd40325/spa/plugins/bluez5/backend-native.c#L2796-2812) | [L1565–1566](https://gitlab.freedesktop.org/pipewire/pipewire/-/blob/1.0.5/spa/plugins/bluez5/backend-native.c#L1565-1566) |
| `sco_destroy_cb()` | [L2857–2879](https://gitlab.freedesktop.org/pipewire/pipewire/-/blob/4cfc471123a0e041fcd6fec5887c40dbddd40325/spa/plugins/bluez5/backend-native.c#L2857-2879) | [L1610](https://gitlab.freedesktop.org/pipewire/pipewire/-/blob/1.0.5/spa/plugins/bluez5/backend-native.c#L1610) |
| `sco_release_cb()` | [L2881–2899](https://gitlab.freedesktop.org/pipewire/pipewire/-/blob/4cfc471123a0e041fcd6fec5887c40dbddd40325/spa/plugins/bluez5/backend-native.c#L2881-2899) | [L1634](https://gitlab.freedesktop.org/pipewire/pipewire/-/blob/1.0.5/spa/plugins/bluez5/backend-native.c#L1634) |
| `sco_event()`: hang-up or error on the SCO socket | [L2901–2933](https://gitlab.freedesktop.org/pipewire/pipewire/-/blob/4cfc471123a0e041fcd6fec5887c40dbddd40325/spa/plugins/bluez5/backend-native.c#L2901-2933) | [L1653–1669](https://gitlab.freedesktop.org/pipewire/pipewire/-/blob/1.0.5/spa/plugins/bluez5/backend-native.c#L1653-1669) |
| `rfcomm_ag_set_volume()`: its checks and the send | [L3124–3152](https://gitlab.freedesktop.org/pipewire/pipewire/-/blob/4cfc471123a0e041fcd6fec5887c40dbddd40325/spa/plugins/bluez5/backend-native.c#L3124-3152) | [L1854–1882](https://gitlab.freedesktop.org/pipewire/pipewire/-/blob/1.0.5/spa/plugins/bluez5/backend-native.c#L1854-1882) |
| `volume_sync_stop_timer()` | [L3240–3245](https://gitlab.freedesktop.org/pipewire/pipewire/-/blob/4cfc471123a0e041fcd6fec5887c40dbddd40325/spa/plugins/bluez5/backend-native.c#L3240-3245) | [L1971](https://gitlab.freedesktop.org/pipewire/pipewire/-/blob/1.0.5/spa/plugins/bluez5/backend-native.c#L1971) |
| the timer's handler | [L3247–3257](https://gitlab.freedesktop.org/pipewire/pipewire/-/blob/4cfc471123a0e041fcd6fec5887c40dbddd40325/spa/plugins/bluez5/backend-native.c#L3247-3257) | [L1978–1988](https://gitlab.freedesktop.org/pipewire/pipewire/-/blob/1.0.5/spa/plugins/bluez5/backend-native.c#L1978-1988) |
| `volume_sync_start_timer()`, `rfcomm_ag_sync_volume()` | [L3259–3292](https://gitlab.freedesktop.org/pipewire/pipewire/-/blob/4cfc471123a0e041fcd6fec5887c40dbddd40325/spa/plugins/bluez5/backend-native.c#L3259-3292) | [L1990–2023](https://gitlab.freedesktop.org/pipewire/pipewire/-/blob/1.0.5/spa/plugins/bluez5/backend-native.c#L1990-2023) |
| the only other stop: on `AT+BCS=` | [L1241](https://gitlab.freedesktop.org/pipewire/pipewire/-/blob/4cfc471123a0e041fcd6fec5887c40dbddd40325/spa/plugins/bluez5/backend-native.c#L1241) | [L904](https://gitlab.freedesktop.org/pipewire/pipewire/-/blob/1.0.5/spa/plugins/bluez5/backend-native.c#L904) |
| the commit that added the resend | [`d82b3d647`](https://gitlab.freedesktop.org/pipewire/pipewire/-/commit/d82b3d64799b9994caa697e7eba4cf9b3a1e1f92) | in 1.0.5 |

## Not checked yet

- **Whether this is already reported or fixed in an open merge request.** GitLab's bot
  protection refuses scripted reads, so this needs a person in a browser: issues
  [`VGM`](https://gitlab.freedesktop.org/pipewire/pipewire/-/issues/?search=VGM&state=all),
  [`volume sync`](https://gitlab.freedesktop.org/pipewire/pipewire/-/issues/?search=volume%20sync&state=all),
  ["mute on"](https://gitlab.freedesktop.org/pipewire/pipewire/-/issues/?search=mute%20on&state=all),
  and merge requests [`volume`](https://gitlab.freedesktop.org/pipewire/pipewire/-/merge_requests?search=volume&state=all).
  The master source above was read on 2026-10-31; `git log -S` finds no change to the timer
  since 2022.
- Ubuntu's own patches in `1.0.5-1ubuntu3.3` (not compared; the behaviour above is on the
  installed package, so they do not remove it).
- A run of current master: master was read, not built or run here. PipeWire's Bluetooth issue
  template asks reporters to try master.
- The hang-up path (`sco_event()`), above.
- The HSP path and the hands-free (HF) role: only the HFP audio-gateway role was observed.
- Whether stopping the timer on release would undo what `d82b3d647` was for. Its stated case is
  the first `+VGS` after a connection being taken only partly; that is the maintainers' call.
  What the history shows: `d82b3d647` armed the resend in `sco_acquire_cb()`, right after
  waiting up to 500 ms for the new SCO socket (`wait_for_socket(sock)`), so the "connection" in
  its comment is the SCO connection; `2bc48e1c1` (Pauli Virtanen, 2023-03-17, "make SCO acquire
  asynchronous") moved the calls to `sco_ready()`. Neither commit says what should happen when
  the SCO connection ends within 1.5 s, and the comment gives a `+VGS` reason only, none for
  `+VGM`.

## Files

| file | what it is |
|---|---|
| `logs/<case>.key-lines.txt` | the lines of that case's journal matching the pattern in the file's header: PipeWire's `RFCOMM >>` replies, profile switches, `acquire complete`, `released`, the browser's streams, kernel SCO messages |
| `logs/<case>.journal.txt` | the whole journal of the window for `wireplumber`, `bluetoothd`, `pipewire`, `pipewire-pulse` and the kernel; the command is in the first line |
| `logs/<case>.capture.txt` | btmon's decode of the HCI capture for the window, only the packets matching `Synchronous Conn`, `+CIEV`, `VGS`/`VGM` and `Disconnect`; the command is in the first line |
| `logs/scan-all-boots.txt` | `scripts/hfp-late-vgm-scan.py` over every boot in the journal |
| `tools/make-raw.sh`, `tools/publish-logs.sh` | how `logs/` was made: the excerpts, then `tools/sanitize-logs.sh` |

Device addresses in `logs/` are replaced by `tools/sanitize-logs.sh` with `AA:BB:CC:00:00:NN`,
numbered separately in each file and written in colon form even where the original used
underscores (`dev_AA:BB:CC:00:00:01`, `bluez_output.AA:BB:CC:00:00:01.1`). btmon's manufacturer
note is kept for the MOMENTUM 4 ("Sonova Consumer Hearing GmbH") and removed for the GM2 pro.
The raw captures and full journals stay in the project's local archive
(`archive/incidents/20261031-momentum-mute-on-at-stop/`, `archive/hci-capture/`) and the
journal export of each boot.

## Next

1. **The operator:** the duplicate search above, in a browser.
2. **The operator:** if nothing exists, write and file the report, attaching what is useful from
   `logs/`. PipeWire's rules: own words, verbatim logs allowed, no tool-written text.
3. A local test of a fix only on the operator's word, and only as the operator's own patch if
   it goes upstream. A stop in `sco_release_cb()` alone would not cover the `sco_event()`
   hang-up path above.
