# U29 in the emulator, 2026-11-07

Two experiments on the laptop's own BlueZ tree: Ubuntu `5.72-0ubuntu5.5` plus `a734b06059cb` and
`0bed9886cff3`, built from `cache/bluez-5.72-0ubuntu5.5-laptop/`. They ran in QEMU/KVM guests on
emulated `btvirt` controllers (`co03-noble-vm:1`). Nothing ran on the laptop's Bluetooth. Each
experiment was built and run by a separate worker; the checks marked **[checked]** were repeated
here against the raw runs.

The raw runs (debug logs, btmon, dbus-monitor, `.btsnoop`) are 49 MB and stay on the
investigation machine under `/root/exp/agent-work/u29-t1-a2dp-backport/runs/` and
`/root/exp/agent-work/u29-t2-temporary-lifetime/runs/`. Their checksums are the `SHA256SUMS` in
each folder here. This folder holds the scripts, the tests, the result tables, the commands and
the upstream patch, enough to repeat both experiments.

## 1. `br-connection-unknown` and upstream `a6ac17f0e393` (`u29-t1-a2dp-backport/`)

**Builds.** The laptop's tree unchanged (`a2dp.c` SHA-256 `53a7125948f2…`), and the same tree with
`a6ac17f0e393` ("a2dp: Fix connection error message", Frédéric Danis, 2024-08-21) applied by
`git am`, unedited (`src/upstream-patch/`). **[checked]** The applied commit is that author's single
`case ECONNREFUSED:` line.

**Injection.** host0 is the A2DP source under test; host1 is an A2DP sink running the unchanged
bluetoothd.
1. The two pair and trust each other.
2. host0's kernel is given an inverted copy of the key, so host1's emulated controller answers
   `Auth Complete` 0x05.
3. An SDP channel (PSM 1) holds the ACL up without authentication, as at 09:38 on the laptop.
4. A D-Bus client calls `Device1.Connect()`.

| arm | runs | reply | AVDTP socket error |
|---|---|---|---|
| unchanged, ACL held | 10 | `br-connection-unknown` 10/10 | `Connection refused (111)` |
| with `a6ac17f0e393`, ACL held | 10 | `br-connection-refused` 10/10 | `Connection refused (111)` |
| unchanged, no ACL held | 5 | `br-connection-unknown` 5/5 | `Permission denied (13)` |
| with `a6ac17f0e393`, no ACL held | 5 | `br-connection-unknown` 5/5 | `Permission denied (13)` |

**[checked]**
- The reply counts, from each arm's `runs/*/results.jsonl`.
- The `avdtp_connect_cb() … Connection refused (111)` line, in reps 0 and 9 of both held arms.
- `device_profile_connected() a2dp-sink`: `Resource temporarily unavailable (11)` unchanged,
  `Connection refused (111)` with the fix.
- Each arm ran its own build (`commands.txt`: `host0=bluez-5.72-base` / `bluez-5.72-patched`).
- The trace has the laptop's order: Create Connection, Connect Complete, PSM 1, then
  Authentication Requested, then Auth Complete 0x05.

The no-ACL rows are the other kernel path: authentication fails during link setup, and the fix
does not reach it.

**Not reproduced:** Hands-free failing first (the emulated sink offers A2DP only), a real headset
dropping its key, and Ubuntu's `7.0.0-42` kernel (the guest runs the image's CI kernel).

Run: `scripts/run.sh baseline baseline 10 hold_after_key`; `scripts/run.sh patched patched 10 hold_after_key`; the control with `none`.

## 2. The temporary device kept by non-discoverable advertising (`u29-t2-temporary-lifetime/`)

**Setup.** The device under test runs `bluetoothd -d` with an empty `main.conf`
(`TemporaryTimeout` 30 s), discovery on.
- The peer is a bare dual-mode controller with one public address for both BR/EDR and LE.
- It opens an unpaired BR/EDR SDP link, holds it for 5 s and lets it drop.
- It then advertises connectable `ADV_IND` with the given flags for 120 s (`btmgmt add-adv -d 020118`).

Arms, 3 runs each (`scripts/analyze.py` prints the full table):

| arm | advertising after the disconnect | discovery | removed after (s) |
|---|---|---|---|
| A | none | plain | 30.7, 30.8, 30.7 after the disconnect |
| B | flags 0x18, every 10 s | plain | 153.9, 41.9, 153.7 after the disconnect; 30.4, 29.8, 30.2 after the last report |
| C | flags 0x1A, every 10 s | plain | 153.7, 153.5, 153.4; RSSI emitted once |
| D | flags 0x18, every 10 s | `{Discoverable: true}` (as GNOME sets it) | 153.7, 153.5, 73.3; 30.3, 30.1, 29.9 after the last report |
| E | flags 0x18, every 10 s | `{Transport: le}` | 153.7, 153.6, 153.4; RSSI emitted on every report |
| F | flags 0x18, every 4 s | plain | 153.9, 153.6, 153.5 |

**Reading.**
- Non-discoverable reports kept the unpaired device for as long as they reached bluetoothd, and
  it went about 30 s after the last one. This is the laptop's 11:16 to 11:18 behaviour.
- With 0x18 under plain or GNOME-style discovery, `RSSI` never changed (B, D, F).
- B-1 and D-2 were removed while the peer still advertised. Only about one beat in three
  reached the scanner, because inquiry interleaves with the LE scan, and the gap went past 30 s.
  So the lifetime follows reports received, not advertising sent.
- B-0 survived a 30.03 s gap between reports, inside GLib's one-second rounding of the timer.

**[checked]**
- A-0: disconnect to `Removing device` 30.70 s.
- B-0: disconnect to removal 153.90 s; last report to removal 30.39 s.
- `RSSI` absent from B-0's and D-0's `dbus-monitor.log`, present once in C-0's.
- B-0's btmon shows `Flags: 0x18` at the device under test.
- The table regenerates from the raw runs with `scripts/analyze.py`.

**Not reproduced:** real radio (btvirt reports RSSI 127, one report per advertising enable), the
headset's other advertising fields and timing, its own inbound connect (here an SDP link from the
peer), and GNOME's display.

Run: `scripts/build.sh`; `scripts/run-arm.sh <A-F> <n>`; `scripts/run-all.sh`; `python3 -I scripts/analyze.py`.
