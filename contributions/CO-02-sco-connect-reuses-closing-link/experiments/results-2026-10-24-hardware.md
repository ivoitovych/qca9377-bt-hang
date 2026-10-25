# CO-02 — results, 2026-10-23 to 2026-10-25: the run on the laptop

## What ran
- **The laptop:** QCA9377 (`13d3:3503`, E3's `updates/btusb.ko`), Ubuntu 24.04, `7.0.0-38-generic`,
  PipeWire 1.0.5, WirePlumber 0.4.17-1ubuntu4.1, BlueZ 5.72 (this project's build).
- **The module:** `tmp/co02-hw/module/full` (`results-2026-10-23-hw-prep.md` §3): Ubuntu 7.0.0-38's
  Bluetooth + `abd93c85c8667` + `816fb1590a4c` + v5, tree `with816-series` `ff077afb28e8`,
  srcversion `0D084A056A9EEFB98E8F331`, installed into `updates/` with `depmod` and loaded by a cold
  boot on the operator's word: boot `257d1599…`, up since 2026-10-23
  11:04:40 and still running at this write-up (EX-071).
- **Headsets:** the Lenovo thinkplus GM2 Pro earbuds (they answer `AT+BCS` before the old link is
  gone: the case the series changes), the Sennheiser MOMENTUM 4 and the Shure AONIC 50 (they answer
  after it: the no-regression controls). Switches were made by the operator in GNOME Settings' Sound
  panel, with the local time noted aloud; the HCI capture, the user journal (WirePlumber debug on)
  and the audio policy recorder ran throughout.

## Results against the plan (`hardware-run-plan.md`)
| # | plan | result | evidence |
|---|---|---|---|
| 0 | the same runs on the control module (`module/pre`) | **not run** (optional in the plan): it needs a module swap and a cold boot on the family laptop. The "before" is the unpatched kernel's own record, `EX-060` (7.0.0-34, 2026-09-29: no setup after either earbuds switch), and the emulator control (`results-2026-10-23-hw-prep.md` §2: the two prerequisite commits alone fail both bug cases 3/3) | — |
| 1 | earbuds, A2DP music | plays (2026-10-24 06:07–06:11, operator) | operator's account |
| 2–3 | earbuds, mSBC ↔ CVSD | **3 of 3 switches refused, none falsely connected**: the reply before the old link's Disconnection Complete, no setup on the dying link, `connect()` → `ECONNABORTED` (first try and PipeWire's two immediate retries). With a stream playing a new link followed 4.86 s after the Disconnection Complete (06:12:27.350650, 06:12:52.743599); with none, at the next sound (22:00:46) | `EX-067`, `EX-068`, `EX-069` |
| 4 | MOMENTUM 4, as 3 | 2 of 2 switches: a new link each time, no refusal | `EX-070`, `EX-069` |
| (extra) | Shure AONIC 50, as 3 | 6 of 6 switches: a new link each time, no refusal | `EX-070`, `EX-069` |
| 5 | calls and microphone use; links go down after hang-up | 36 SCO links on the boot on three headsets, 36 hang-ups answered, 0 timeouts (the Shure's 81-minute link held by the Sound panel's meter included). The "unknown connection handle" / "corrupted SCO packet" lines at hang-ups appear on the previous, unpatched boot in the same way (`CO-20`) | `EX-073` |
| 6 | a day of normal use: no BT-1 symptom, no kernel warning | the whole boot, more than 1.5 days: no `WARNING`, `BUG`, `refcount`, `use-after-free`, `Call Trace`, `tx timeout` or `Oops` line | `EX-072` |

## What the hardware does not reach, and why
- **Patch 1 (the hold on a reused connection, "Connect Twice"):** it acts when a second `connect()`
  comes while the first socket's link is up. Nothing on this desktop does that: no `EBUSY` refusal on
  the boot (`scripts/user-journal.sh --since "2026-10-23 11:04:40" -g "Device or resource busy|EBUSY"`:
  no entries). It is covered in the emulator, 3 of 3 on UP, SMP and KCSAN (bluetooth-next) and on
  Ubuntu's code (`-hw-prep.md` §2). Reaching it on the laptop needs a test program that opens two SCO
  sockets to one headset; not done.
- **Patch 3 (the race with a disconnect worker already running):** a window of microseconds that
  only the debug-only park opens on demand (`race-park-2026-10-22.md`); emulator only, as for any
  race fix.

## What the user hears (`U17`)
The series makes the kernel tell the truth, and PipeWire 1.0.5 reacts to the truth with three
connects within 80 µs, all before the old link is gone; the nodes go to error and WirePlumber's
idle suspend restarts them 5.004 s later, when the connect succeeds (`EX-068`). On the unpatched
kernel the same switch on these earbuds gave a socket reported connected with no link and silence
until the stream was restarted (`U7`, `EX-060`). So: **silence for about 5 s instead of until a
restart**, on the earbuds; no change on the other two headsets. PipeWire's own source already
expects this error for "a SCO connect done too soon after previous close" (`bluez5-dbus.c:275-283`
on master). Shorter recovery needs a PipeWire retry that waits for the old link, or a kernel that
defers the connect (`patch/kernel-rfc-defer/`), which changes `connect()` semantics; both are
separate from this series.

## Not covered
- The control module on hardware (run 0), and patches 1 and 3 on hardware (above).
- KCSAN on Ubuntu's code (`-hw-prep.md`).
