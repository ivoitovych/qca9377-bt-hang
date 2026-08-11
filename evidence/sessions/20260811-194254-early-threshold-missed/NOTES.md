# Incident: the early window existed, but the threshold was too high to use it

**When:** 2026-08-11 19:39:48 – 19:42:11 CEST
**Kernel:** 7.0.0-28-generic
**Preceded by:** a cold power-off, so the controller started healthy
**Reported activity:** (ad-hoc, not a procedure) "a few manipulations"
**Config:** `BT_EARLY=1`, `BT_EARLY_THRESHOLD=2`, `BT_EARLY_WINDOW=90`
**Outcome:** ❌ stage 2, off the bus, cold power-off required

---

## The finding: a tuning failure, not a mechanism failure

An early-warning window **did** exist — but only one signal arrived in it, and the
threshold demanded two.

```
19:39:48  early signal: avdtp.c:cancel_request() Abort
          early window: 1/2 in last 90s        ← never reached the threshold
19:39:55  first HCI command timeout             (+7 s)
19:40:28  watchdog intervened (LATE trigger)   (+33 s)  → USBDEVFS_RESET failed
19:41:01  first USB-level failure              (+66 s)
19:42:11  device left the bus                 (+136 s)
19:42:29  second early signal                 (+154 s)  ← far too late
```

The one usable signal came **7 seconds** before the first timeout. `BT_EARLY_THRESHOLD=2`
meant nothing happened. The late trigger then did what it has done every time: fired
after the timeout and failed.

## Lead time is highly variable

| Incident | Trigger | Early-warning lead | Early fired? | Outcome |
|---|---|---|---|---|
| 2026-08-10 07:24 | audio teardown | **−52 s** | no (mode not yet built) | ❌ late reset failed |
| 2026-08-10 ~19:00 | audio teardown | sufficient, ≥2 signals | **yes** | ✅ **recovered** |
| 2026-08-11 06:06 | connect/disconnect + mode changes | **+133 s** (none) | no — nothing to fire on | ❌ |
| 2026-08-11 19:39 | "a few manipulations" | **−7 s** | no — 1 signal, threshold 2 | ❌ |

Lead time observed: 52 s, "enough", none, 7 s. A threshold of 2 is unusable when the
window is 7 seconds wide and only one signal appears in it.

## Action taken

`BT_EARLY_THRESHOLD` lowered from 2 to **1**: act on the first audio-teardown failure.

Justification from the precision data (occurrences overall vs. occurrences in boots that
hung, measured over 12 boots): `cancel_request() Abort` **4/4**, `Suspend` **2/2**,
`avdtp_connect_cb` **5/5**. A single `Abort` has not once appeared in a boot that stayed
healthy, so treating it as sufficient is defensible.

⚠️ **Cost:** a false positive now resets a working controller and drops live connections.
That is a real regression in normal use, accepted deliberately because every late reset
has failed — the choice is between an occasional spurious reset and a guaranteed
power-off.

## What this does NOT change

The core claim is untouched and slightly strengthened: **every reset issued after the
first HCI timeout has failed**, now four for four (+20 s, +11 s, +33 s, and the original).
The recoverable window closes at or before the first timeout.

What this incident adds is that the window can be as short as **7 seconds**, which sets
a hard bound on how slow any recovery mechanism can afford to be — including a kernel
one.

## Files

`MANIFEST.txt`, `watchdog.log`, `kernel.log`, `bluetoothd.log`, `timeline.txt`,
`hci-captures.txt`, `state-now.txt`.
