# CO-02 — patch 1 on the laptop: a second SCO connect during a call, 2026-10-26

The operator's decision: "Okay, let's do the test." The laptop runs the CO-02 module (`EX-071`, boot
`257d1599…`), and the headset is the Shure AONIC 50 in Hands-free, mSBC. The Sound panel's input
meter on the Shure's microphone holds the link. The program is
`hw-connect-twice/sco-connect-twice.c` (the guard requires the eSCO link that `sco_connect()` looks
up, and the socket is bound to the adapter), built as `tmp/co02-v6send/sco-connect-twice` and run as
`tmp/co02-v6send/sco-connect-twice 0 <the Shure's address>`.

## Result: 3 of 3 — EBUSY, the call's link kept, its voice data without a gap

| run | second `connect()` | the call's link (handle 9) over 10 s | program |
|---|---|---|---|
| 1, 05:40:32.047 | -1, Device or resource busy | up at every read | PASS |
| 2, 05:42:31.944 | -1, Device or resource busy | up at every read | PASS |
| 3, 05:42:44.968 | -1, Device or resource busy | up at every read | PASS |

What settles it is the capture, not the program's table reads:
- `EX-075`: from 05:40:00 to 05:43:30 there is no Setup Synchronous Connection, no Synchronous
  Connect Complete and no Disconnect or Disconnection Complete in the HCI capture.
- `EX-076` (positive control, same file): the link was set up at 05:39:59.141 and is one link
  through all three runs; the five earlier links of that capture closed by handle with 0x00.
- `EX-077`: voice data on handle 9 from 05:40:25 to 05:43:05, about 53,300 packets each way. The
  largest gap was 11.9 ms controller-to-host and 15.6 ms host-to-controller, so no short drop that
  came back with the same handle.
- The user journal from 05:40:25 to 05:43:05 (`scripts/user-journal.sh … -g
  "error|abort|busy|suspend|acquire|release|-> running|-> idle"`) has no state change on the
  Bluetooth nodes. Its only lines are a Chrome stream going idle at 05:40:31.93, 0.1 s before run 1
  started, and suspended 10 s later: Chrome's own.
- **[operator]** run 1: "The meter is moving all the time." Runs 2 and 3: asked, not yet answered at
  this write-up; the capture's continuous data covers them.

Without patch 1, the refused connect drops the call's hold, and the call's link is disconnected
about 10 ms later (the emulator's "Connect Twice" case, failing on every unpatched kernel). That
would show in `EX-075` as a Disconnect and in `EX-077` as the data stopping.

## Verbatim output, run 1 (runs 2 and 3 are the same apart from the times)
```
2026-10-26 05:40:32.047669  call's link: handle 9, eSCO
2026-10-26 05:40:32.047721  second connect()
2026-10-26 05:40:32.047735  second connect() returned -1 (Device or resource busy)
2026-10-26 05:40:32.047755  second socket closed
2026-10-26 05:40:33.047876  + 1 s: call's link still up
…
2026-10-26 05:40:42.048826  +10 s: call's link still up
PASS: EBUSY, and the call's link (handle 9) stayed up for 10 s
```
Run 2: connect at 05:42:31.944181, EBUSY at 05:42:31.944207, ten reads up, PASS. Run 3: connect
at 05:42:44.968315, EBUSY at 05:42:44.968334, ten reads up, PASS.

## Not covered
- No unpatched control on hardware (the module swap and a cold boot, `results-2026-10-24-hardware.md`
  run 0); the "without patch 1" behaviour is the emulator's.
- One headset (the Shure), one codec (mSBC).
