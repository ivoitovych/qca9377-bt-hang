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
| 5 | calls and microphone use; links go down after hang-up | 36 SCO links on the boot on three headsets (15 MOMENTUM 4, 9 earbuds, 12 Shure), and every one closed: in the capture, each successful Synchronous Connect Complete is followed by the host's Disconnect and a Disconnection Complete for the same handle with status 0x00, no setup failed and the capture has no gap (`EX-074`, from 2026-10-26). Some of these links were closed by a codec switch rather than a hang-up. The Shure's 81-minute link, held by the Sound panel's meter, is included. The kernel log agrees: 36 Disconnects answered, 0 command timeouts (`EX-073`). That ledger's "answered" line has neither the handle nor the event's status, so until 2026-10-26 this row rested on weaker evidence than it claimed. The "unknown connection handle" / "corrupted SCO packet" lines at hang-ups also appear on the previous, unpatched boot, so they predate the series (`CO-20`); their rates were not compared | `EX-074`, `EX-073` |
| 6 | a day of normal use: no BT-1 symptom, no kernel warning | the whole boot, more than 1.5 days at the time of the search: no `WARNING`, `BUG`, `refcount`, `use-after-free`, `Call Trace`, `tx timeout` or `Oops` line. This is the absence of the searched diagnostics, not a log without errors (the SCO lines of run 5 are error level); and an extra hold would be silent here, which is why run 5's closures matter | `EX-072` |

## What this run did not exercise, and why
(Corrected 2026-10-26 after the reviews of `ee52148`. This section was titled "What the hardware
does not reach", and it said patch 3's window opens only with the debug park. Both overstated it.)
- **Patch 1 (the hold on a reused connection, "Connect Twice"):** its new branch runs when a
  `connect()` reuses a SCO connection whose link is up. In this run every connect either got a new
  link or was refused by patch 2 first, so the branch was not exercised. No `EBUSY` refusal appears
  on the boot (`scripts/user-journal.sh --since "2026-10-23 11:04:40" -g "Device or resource busy|EBUSY"`:
  no entries). That shows no refusal was seen; it does not prove that no second connect ever came.
  The case is covered in the emulator: 3 of 3 on UP, SMP and KCSAN (bluetooth-next) and on Ubuntu's
  code (`-hw-prep.md` §2). It **can** be reached on the laptop, with a test program that opens two
  SCO sockets to one headset. That was not done; it is the operator's decision.
- **Patch 3 (the race with a disconnect worker already running):** its wait and second check run
  on every `hci_connect_sco()` call, so here they ran on all 36 connects with no stall. The race
  itself exists in the ordinary kernel: a worker that has seen no holder but not yet set
  `abort_reason`. Its window is too short to hit on demand. The debug-only park lengthens it to make
  it reproducible (`race-park-2026-10-22.md`), so the refusal on that path is shown in the emulator
  only, as for any race fix.

## What the user hears (`U17`)
The series makes the kernel tell the truth, and PipeWire 1.0.5 reacts to the truth with three
connects within 80 µs, all before the old link is gone. The nodes go to error; WirePlumber
suspends them as idle 5.004 s later, and the stream still linked to the sink runs it again, which
acquires the transport, and that connect succeeds (`EX-068`). This is with a stream playing; with
none, the next sound got its link at once (22:00:46). In the earlier reproduction without the series
(7.0.0-34, 2026-09-29: a historical observation, not a same-build control), the same switch on
these earbuds gave a socket reported connected with no link. No link followed at all: GNOME's test
sounds, new streams started 3, 2 and 26 s after the two failed switches (02:30:47, 02:31:14,
02:31:38), were silent with no Setup Synchronous Connection. What ended the first silence was the
next codec change, at 02:30:59; how the second ended is not recorded (`U7` in `docs/issues.md`,
`EX-060`). *Corrected 2026-10-26 (reviewer 6):* this said "silence until the stream was restarted",
which the record does not show. So: **a gap of about 5 s instead of no link at all**, on the earbuds;
no change on the other two headsets. PipeWire's own source already
expects this error for "a SCO connect done too soon after previous close" (`bluez5-dbus.c:275-283`
on master). Shorter recovery needs a PipeWire retry that waits for the old link, or a kernel that
defers the connect (`patch/kernel-rfc-defer/`), which changes `connect()` semantics; both are
separate from this series.

## Not covered
- The control module on hardware (run 0), patch 1's case on hardware, and patch 3's race on
  hardware (above).
- What the series fixes is the path seen here: a `connect()` that attaches to a SCO connection
  already committed to teardown. A `connect()` that comes before the disconnect worker has started
  still keeps the live link, unchanged by the series (patch 3's message says so).
- KCSAN on Ubuntu's code (`-hw-prep.md`).
