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
| `baseline.tsv` | Per-boot failure counts across 34 boots (2026-05-31 → 08-10): **287 timeouts, 13 of 34 boots hung, zero resets**. "Hung" here means ≥1 command timeout. EX-003 counts 18 such boots — same criterion, different (later) retention window; the two totals are not comparable and neither corrects the other |

<!-- REVIEWED-KEEP 2026-08-15T1752Z §7: keep the 34-vs-18 incomparability note in
the baseline.tsv row above (two retention windows, neither corrects the other) and
the synthetic-line correction below — both are the disclosures that make these
numbers quotable at all. -->

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
6. across 34 boots and four kernel versions: 287 command timeouts, **zero** reset attempts

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

`sessions/latest` is a symlink to the most recently collected session (host-local, not
committed). Use it rather than retyping a timestamp — twice a write-up was saved to a
guessed directory name that was one second off, silently creating a new directory
holding only `NOTES.md` while the evidence sat elsewhere.

### The sessions so far

*(This table lists the first four; later sessions — the threshold-missed and
no-early-signal hangs of 2026-08-11, and the 2026-08-13 stock trials — follow the same
layout and carry their own NOTES.)*

| Session | What it shows |
|---|---|
| `20260810-072445-first-real-hang` | reset **+20 s** after the first HCI timeout — **failed** |
| `20260811-002156-early-mode-SUCCESS` | reset **before** any timeout, on the bluetoothd signal — **recovered**; no `tx timeout` occurred at all |
| `20260811-060910-mode-change-hang` | reset **+11 s** — **failed**; and the bluetoothd signal arrived **+133 s**, i.e. no early-warning window existed |
| `20260810-065803-observability-selftest` | tooling self-check, no hardware event |

Read together: every reset after the first HCI timeout has failed, the only one issued
before a timeout succeeded, and the early warning that made that possible is **not
always present**.

`20260810-072445-first-real-hang` predates the full session layout — it was collected
by hand before `bt-evidence` existed, so it has no `MANIFEST.txt` and no
state-before/after captures. That is when it was collected, not data loss; the
journal and capture files it does hold are complete for what was gathered.

### ⚠️ How these sessions were produced

**Ad-hoc, not to a procedure.** The operator's Bluetooth activity was arbitrary —
connecting and disconnecting devices, toggling modes, playing and interrupting audio —
with no fixed sequence and no record of the exact actions.

So the `Trigger:` line in each `NOTES.md` is an **inference from the logs**, or the
operator's rough recollection. The sessions are **not matched pairs**: a difference
between two of them may be a difference in unrecorded input rather than in mechanism.

What survives this, because it does not depend on knowing the trigger: the controller's
*response* — reset outcomes, stage-1 durations, whether a warning preceded the stall.
Those are measured in every session regardless of what provoked it.

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

**Budget:** rotation 128 MB, retention 400 files, plus a hard floor — capture prunes,
then stops, rather than let free space fall below 15 GB. (The count is generous on
purpose: btmon aborts force early rotations, so files average ~2 MB; the floor is the
real bound. An earlier 30-file/10 GB setting is what rotated away a session under
investigation.)

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
