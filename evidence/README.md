# Evidence

Durable, sanitised record of what was observed, what was done, and what happened —
the factual base a kernel patch has to stand on.

Journald rotates. Terminal scrollback dies with the window. A claim in a bug report
without an attached transcript is an assertion, not evidence. Everything here is
committed so it survives both.

```
evidence/
  baseline/    the failing boot, before any mitigation existed
  diagnosis/   reproducible command transcripts proving the root cause
  sessions/    one directory per reproduction session
```

---

## `baseline/` — the state we started from

| File | What it is |
|---|---|
| `kernel-boot0.sanitized.log` | Full kernel log of the boot that hung (2026-08-08 → 08-10) |
| `bluetoothd-boot0.sanitized.log` | Matching bluetoothd log, incl. the AVDTP teardown that triggered it |
| `baseline.tsv` | Per-boot failure counts across 12 boots: **102 timeouts, 6 of 12 boots hung** |

Captured at 02:54 on 2026-08-10, *before* the three synthetic `tx timeout` lines were
injected at 03:07 to test watchdog detection. The 22 timeouts in this log are all
genuine hardware events. Anything re-collected from the live journal of that boot will
contain 25 and must be corrected for.

## `diagnosis/` — why we believe what we believe

`root-cause-evidence.txt` is a transcript of commands anyone can re-run on an affected
machine, establishing in order:

1. the device is `13d3:3503`, HCI manufacturer `0x001D` (Qualcomm), version `0x07` (BT 4.2)
2. its companion Wi-Fi half is `ath10k_pci: qca9377` — one combo chip
3. the reset handler and QCA firmware paths **are** compiled into the shipped `btusb.ko`
4. the ID is **absent** from that binary's tables — byte-scan validated against a known ID
5. it is absent from upstream `btusb.c` too, which carries 78 other `0x13d3` entries
6. across 12 boots: 102 command timeouts, **zero** reset attempts

Points 3 and 4 together are the argument: the code exists, it simply never runs for
this device.

## `sessions/` — reproduction attempts

One directory per session, created by `bt-evidence`:

```
sessions/20260810-071500-mid-stream-teardown/
  MANIFEST.txt      machine-readable summary (counts, duration, kernel)
  NOTES.md          goal / method / result — written by you
  commands.log      every command run via `bt-evidence cmd`, with output
  state-before.txt  device, params, services, counters at session start
  state-after.txt   the same at session end
  kernel.log        kernel lines filtered to hci/usb/btusb
  bluetoothd.log    bluetoothd, minus endpoint-registration noise
  watchdog.log      what the watchdog saw and decided
  timeline.txt      all streams merged chronologically
  hci-captures.txt  which btsnoop files cover the window (referenced, not copied)
```

A session that produces **no** hang is still evidence: it records how hard the trigger
was to hit and how close the watchdog came to firing.

### Using it

```bash
bt-evidence start mid-stream-teardown
bt-evidence note "connecting MOMENTUM 4"
bt-evidence cmd bluetoothctl connect AA:BB:CC:DD:EE:FF
bt-evidence note "playing audio, about to power headset off mid-stream"
# … do the thing by hand …
bt-evidence stop
```

Then edit `NOTES.md`. The transcript records what happened; only you can record what it
meant.

---

## ⚠️ HCI captures are deliberately not here

`bt-trace` writes btsnoop captures to `/var/log/bt-health/trace/`. They are **not**
collected into sessions and are gitignored, because they contain device addresses,
device names, pairing exchanges and audio payload — and `tools/sanitize-logs.sh` parses
text, not binary formats.

Sessions record *which* captures cover their window. Inspect one with:

```bash
btmon -r /var/log/bt-health/trace/bt-YYYYmmdd-HHMMSS.btsnoop
```

If you attach a capture to a bug report, review it first. There is no automated scrubber
for btsnoop.

**Budget:** 128 MB × 30 ≈ 3.8 GB, plus a hard floor — capture prunes, then stops, rather
than let free space fall below 10 GB.

---

## Sanitisation

Every text file here has been through `tools/sanitize-logs.sh`: MAC addresses and BSSIDs
(colon *or* dash separated), UUIDs and IPv4 addresses become deterministic placeholders,
consistent within a file so cross-references stay readable.

The Wi-Fi AP BSSID matters most — public geolocation databases index BSSIDs, so
publishing one can reveal where the machine physically is.

Verify any file before attaching it elsewhere:

```bash
grep -nEi '([0-9a-f]{2}[:-]){5}[0-9a-f]{2}' <file>   # expect only AA:BB:CC:* / 11:11:11:*
```
