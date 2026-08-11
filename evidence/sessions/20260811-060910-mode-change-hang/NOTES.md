# Incident: hang with NO early-warning window

**When:** 2026-08-11 06:06:25 – 06:08:19 CEST
**Kernel:** 7.0.0-28-generic
**Reported activity:** (ad-hoc, not a procedure) repeated connect/disconnect cycles and **mode changes**
**Mode:** `BT_EARLY=1` armed, threshold 2 in 90 s
**Outcome:** ❌ stage 2, controller off the bus, cold power-off required

---

## Why this matters: it contradicts the Phase 10 hypothesis

The early-intervention result (2026-08-10 evening) rested on bluetoothd warning **52 s
before** the kernel's first `tx timeout`. This incident had **no such warning**.

```
06:06:25   first HCI command timeout          ← the failure starts HERE
06:06:36   watchdog intervened        (+11 s)
06:07:09   first USB-level failure    (+45 s)
06:08:19   device left the bus       (+115 s)
06:08:38   first EARLY signal        (+133 s) ← arrives AFTER everything
```

The audio-teardown signal (`avdtp.c:cancel_request() Abort`) arrived **133 seconds after**
the first timeout — two minutes too late to be a warning of anything. `BT_EARLY` could
not have helped here. It had nothing to trigger on until the controller was already gone.

## Two distinct log signatures (not necessarily two mechanisms)

| | Path A — audio teardown | Path B — this incident |
|---|---|---|
| Trigger | stream torn down mid-playback | repeated connect/disconnect + mode changes |
| bluetoothd warning | **52 s before** the first timeout | **133 s after** — none in time |
| Early reset possible | yes — and it worked | **no** — no signal to act on |
| Observed outcome | recovered | stage 2, power-off |

`BT_EARLY` addresses Path A only.

## What still holds

Every reset issued **after** the first HCI timeout has now failed, three for three:

| Incident | Reset issued | Result |
|---|---|---|
| 2026-08-10 07:25 | +20 s after first timeout | ❌ failed |
| 2026-08-11 06:06 | **+11 s** after first timeout | ❌ failed |
| 2026-08-10 ~19:00 | *before* any timeout | ✅ recovered |

+11 s is about as fast as a log-driven watchdog can react, and it was still too late.
This strengthens rather than weakens the core claim: **the recoverable window closes at
or before the first HCI command timeout**, which is precisely when `hdev->cmd_timeout`
becomes eligible to fire. `cmd_timeout` is structurally too late.

What it removes is the hope that watching bluetoothd is a *general* substitute. Sometimes
there is no earlier signal to watch.

## Stage 1 duration

45 s (first timeout → first USB failure). Consistent with the 53 s measured on 08-10, and
nothing like the ~6 h originally inferred from an idle controller.

## Tooling bugs this exposed

Both were reporting the opposite of reality, which is worse than reporting nothing:

- **`bt-postmortem` mixed two incidents.** It used `grep -m1` over the whole boot, so it
  picked up the *previous evening's successful* recovery and printed
  `RECOVERED VIA EARLY INTERVENTION` with a delta of **−40065 s** while the controller was
  off the bus. It now clusters timeouts into incidents (gap > 600 s) and analyses only the
  most recent, scoping every timestamp and count to that window.
- **`bt-status` had the same masking flaw** — cumulative per-boot counts meant one early
  success made the whole boot look healthy. Both tools now check live state (`hci`
  present? on the bus?) *before* interpreting any counter.

## Files

`MANIFEST.txt`, `watchdog.log`, `kernel.log`, `bluetoothd.log`, `timeline.txt`,
`trace-service.log`, `hci-captures.txt`.
