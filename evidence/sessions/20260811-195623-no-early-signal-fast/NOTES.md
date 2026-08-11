# Incident: no early signal at all, two minutes into a fresh boot

**When:** 2026-08-11 19:51:20 – 19:53:19 CEST
**Boot:** 19:49 (cold power-off immediately before)
**Kernel:** 7.0.0-28-generic
**Config:** `BT_EARLY=1`, **`BT_EARLY_THRESHOLD=1`** (lowered after the previous incident)
**Outcome:** ❌ stage 2, off the bus, cold power-off required

---

## The result

This was the first test of `BT_EARLY_THRESHOLD=1` — the setting introduced precisely
because the previous hang produced exactly one early signal against a threshold of two.

**It could not be tested. There were zero early signals.**

```
19:49     cold boot; controller healthy, verified responding at 19:50
19:51:20  first HCI command timeout      ← no bluetoothd warning of any kind
19:51:36  watchdog intervened   (+16 s)  → USBDEVFS_RESET failed
19:52:09  first USB failure     (+49 s)
19:53:19  device left the bus  (+119 s)
```

bluetoothd logged nothing but routine startup messages before the failure. The stall
began at HCI with no precursor at the audio layer.

## The "no early warning" signature is not rare

| # | Date | Log signature (inferred, not a controlled trigger) | Early lead | Early fired | Outcome |
|---|---|---|---|---|---|
| 1 | 08-10 07:24 | audio teardown | −52 s | n/a (not built yet) | ❌ |
| 2 | 08-10 ~19:00 | audio teardown | ≥2 signals | ✅ | ✅ **recovered** |
| 3 | 08-11 06:06 | connect/disconnect + mode changes | **+133 s** | ✗ nothing to fire on | ❌ |
| 4 | 08-11 19:39 | "a few manipulations" | −7 s | ✗ threshold was 2 | ❌ |
| 5 | 08-11 19:51 | fresh boot, light use | **none at all** | ✗ nothing to fire on | ❌ |

Two of five incidents had **no** usable early warning. `BT_EARLY` is not a general
mitigation; on this evidence it addresses roughly the audio-teardown subset only.

⚠️ The "signature" column is read out of the logs, not from a recorded procedure — the
operator's Bluetooth activity was ad-hoc throughout. These rows are not matched pairs,
and a difference between them may be a difference in unrecorded input rather than in
mechanism.

## What is now very well supported

**Five for five, every reset issued after the first HCI timeout has failed** — at +11 s,
+16 s, +20 s, +33 s, and the original +20 s. The intervention latency has ranged over a
factor of three with no effect on the outcome.

Stage 1 durations: 45 s, 49 s, 53 s, 66 s. Consistently under 70 seconds, and the reset
always lands comfortably inside that window — yet never works.

That is the strongest statement this project can make:

> Once the controller has missed its first HCI command, a USB reset does not bring it
> back, regardless of how quickly it is issued. `hdev->cmd_timeout` fires strictly after
> that point, so it cannot be the mechanism that saves this device.

## Also notable

The controller hung **two minutes into a freshly power-cycled boot** with only ~76
audio/profile events. Whatever the trigger is, it does not require prolonged use or
accumulated state.

## Honest status of the workaround

- `BT_EARLY` recovered the controller once, and could not act in two of five incidents.
- The late trigger has never once succeeded.
- Net effect for a user: the hang still happens and still requires a power-off.

The project's value is now the *characterisation*, not the workaround.

## Files

`MANIFEST.txt`, `watchdog.log`, `kernel.log`, `bluetoothd.log`, `timeline.txt`,
`hci-captures.txt`, `state-now.txt`.
