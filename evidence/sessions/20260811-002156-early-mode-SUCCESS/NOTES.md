# Incident: early-mode recovery SUCCEEDED

> ⚠️ **CORRECTION BANNER — added 2026-08-13, text below kept as the record.**
> "What it means for the kernel" below claims `hdev->cmd_timeout` is
> "architecturally too late" and the quirks-table entry "correct but
> insufficient". Both rested on the wrong mechanism: v7.0 installs
> `hdev->reset`, which fires at **+0 s** with no threshold — a point no
> experiment (including this one) has occupied. The measured result stands —
> a pre-timeout reset recovered the controller and every post-timeout
> userspace reset failed — but the inference about the patch is **withdrawn**.
> See `docs/fix-proposal.md` §3a and `docs/issues.md` BT-3.


**Boot:** 2026-08-10 18:56 → 2026-08-11 00:21 (5 h 21 m, still up)
**Kernel:** 7.0.0-28-generic
**Mode:** `BT_EARLY=1`, threshold 2 in 90 s
**Outcome:** ✅ **the controller was recovered before any HCI command timed out**

---

## Why this is the most important session in the project

It is the positive control for the experiment that failed on 2026-08-10.

| Trigger | Fires when | Result |
|---|---|---|
| `tx timeout` (what `cmd_timeout` uses) | controller already stopped answering | ❌ **failed** — chip lost, cold power-off required |
| audio-teardown failure (`BT_EARLY`) | before any HCI timeout | ✅ **recovered** |

Same hardware, same trigger, same reset operation (`USBDEVFS_RESET`). The only
difference is **when** it was issued.

## What happened

```
EARLY intervention: 2 audio-teardown failure(s) in 90s — resetting BEFORE any HCI timeout.
  EARLY recovery SUCCEEDED — this is the result that matters
EARLY threshold reached (2/2) but suppressed by cooldown (169s remaining)
EARLY threshold reached (3/2) but suppressed by cooldown (137s remaining)
EARLY threshold reached (4/2) but suppressed by cooldown (131s remaining)
```

Counts for the boot:

| | |
|---|---|
| early signals seen | 6 |
| early interventions | 1 |
| → recovered | **1** |
| HCI command timeouts | **0** |
| reset failures | 0 |
| hard hangs | 0 |
| audio/profile events | 145 |

**Zero `tx timeout` events all boot.** The early reset did not merely recover the
controller after a stall — it prevented the stall from ever reaching the stage the
kernel would have noticed. `cmd_timeout` would never have fired at all.

## Bluetooth was genuinely exercised

A clean boot proves nothing if the trigger was never attempted. This boot logged **145
audio/profile events** and 4 connections to the Lenovo thinkplus GM2 pro. The failure
path was entered — the watchdog saw 6 audio-teardown failures — and was interrupted.

## What it means for the kernel

`hdev->cmd_timeout` is **architecturally too late** for this failure mode. It fires only
after HCI commands begin timing out, and by that point the controller is already past
recovery — demonstrated on 2026-08-10, when a reset 20 s after the first timeout (and
33 s before any USB failure) did not work.

So adding `13d3:3503` to btusb's quirks table would be **correct but insufficient**. The
device genuinely receives no vendor quirks, and that is worth fixing. But it would not
have prevented this hang, and saying so would mislead maintainers.

The useful finding for `linux-bluetooth` is the *timing boundary*: there is a window,
before the first HCI timeout, in which a USB reset still works — and no existing kernel
hook fires inside it. The signal that opens the window is bluetoothd-level (AVDTP/SCO
teardown failure), not kernel-level, which may be why no such hook exists.

## Caveats — do not overstate this

- **n = 1.** One successful early recovery against one failed late recovery.
- The cooldown suppressed 3 further interventions, so we cannot tell whether those
  would also have been needed or would have been spurious.
- It is not established that the *same* severity of stall occurred in both cases. The
  08-10 hang may simply have been worse from the outset.
- A false positive resets a healthy controller; precision was estimated from 12 boots,
  not measured against a large sample.

More reproductions are needed before this is stated as fact upstream.

## Files

`MANIFEST.txt`, `watchdog.log`, `kernel.log`, `bluetoothd.log`, `timeline.txt`,
`hci-captures.txt` (30 btsnoop files, 44 recorded capture gaps).
