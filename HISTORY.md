# Development history

Chronological record of how this project came about, in the order things were actually
learned — including the wrong turns, because several of them changed the conclusions.

All times are CEST on **2026-08-10** unless stated otherwise. The machine had been up
since 2026-08-08 08:59, with the Bluetooth controller already hard-hung when work began.

---

## Phase 1 — Diagnosis (02:32 – 02:55)

**Starting symptom:** the GNOME Bluetooth panel spins forever. Reported as an everyday
routine: after some connect/disconnect cycles the controller stops working, and a reboot
— sometimes a full power-off — is needed.

**02:32 · The controller is alive but answers nothing.**

```
$ hciconfig -a
Can't read local name on hci0: Connection timed out (110)
hci0:   UP RUNNING PSCAN
        RX bytes:12490523 acl:2838 sco:11 events:1743003 errors:0
```

`errors:0` in both directions was the first real clue: the USB transport is perfectly
healthy, the chip simply stops producing events. That localises the fault above USB and
inside the firmware.

**02:35 · Hardware identified.** USB `13d3:3503`, HCI manufacturer `0x001D` (Qualcomm),
HCI version `0x07` (Bluetooth 4.2), companion Wi-Fi `ath10k_pci: qca9377` — the two
halves of one QCA9377 combo chip. `btmtk`/`btrtl`/`btbcm` in `lsmod` were a red herring;
`btusb` pulls all vendor helpers in regardless.

**02:38 · The trigger found in the logs.** The ordering is mechanistic:

```
20:19:59  bluetoothd: avdtp.c: Suspend: Connection timed out (110)
20:20:11  bluetoothd: avdtp.c: Abort:   Connection timed out (110)
20:20:43  kernel:     hci0: command 0x0406 tx timeout      <-- wedged
```

An A2DP stream torn down **mid-playback** — headphones powered off or walking out of
range while music plays. ~30 s later the host issues `HCI_Disconnect` (0x0406); it never
completes.

**02:40 · Ruled out, by measurement rather than assumption:** rfkill (not blocked),
suspend/resume (**zero** suspend events that entire boot — a very common theory,
definitively excluded), stuck connections (`hcitool con` empty), a dead service
(`bluetooth.service` healthy for 1 d 11 h), TLP (inactive), BlueZ misconfiguration
(stock `main.conf`).

**02:46 – 02:51 · Every recovery attempt failed.** In escalating order: driver
unbind/rebind, the kernel's own retry loop, and an xHCI port power cycle. The chip
stopped answering even `GET_DESCRIPTOR` on endpoint 0 and vanished from the bus.

The control that made this conclusive: the FocalTech fingerprint reader on the *same*
xHCI controller stayed healthy throughout. The bus was fine; the silicon was not.

> **This established the two-stage failure model that everything else rests on:**
> stage 1 (HCI dead, USB healthy — recoverable by a USB reset) decaying into
> stage 2 (USB core dead, off the bus — cold power-off only). Stage 1 had lasted
> **~6 hours** before decaying. A warm reboot does not drop the M.2 power rail, which
> is why a reboot sometimes wasn't enough.

**02:54 · Config backed up** before any change.

---

## Phase 2 — Root cause (02:55 – 03:05)

The user suggested this might be a kernel bug, having seen the same behaviour on
multiple laptops. Testing that hypothesis with the 24 kernels installed:

| Kernel | Hangs? |
|---|---|
| 6.17.0-29 | yes |
| 6.17.0-35 | yes |
| 6.17.0-40 | yes |
| 7.0.0-28 | yes |

**Not a regression.** Rolling back would not help — but the instinct was right, and
more specific than expected.

**The finding.** `btusb_qca_cmd_timeout()` USB-resets a controller after 5 consecutive
HCI command timeouts, and is installed only when `driver_info` carries `BTUSB_QCA_ROME`.
The logs say it never ran:

```
"tx timeout" events across 34 boots : 287
automatic reset attempts            :   0
```

No QCA firmware ever loaded either. Both code paths *are* compiled into the shipped
`btusb.ko` (verified with `strings`), so their absence reflects device matching, not
kernel configuration.

> **A missing one-line device ID converts a self-healing 3-second glitch into a
> power-cycle-requiring hard hang.** There was a ~6 hour window in which a USB reset
> would very likely have recovered the chip. Nothing triggered one.

**⚠️ Correction made at the time.** The first evidence offered was `modinfo btusb`
showing no `13d3` aliases. That was *insufficient*: `modinfo` exposes only
`btusb_table`, while the vendor quirks live in a separate non-exported `quirks_table`
matched via `usb_match_id()`. The conclusion survived on the behavioural evidence, but
the reasoning had to be corrected — see 06:32 for how it was finally settled.

---

## Phase 3 — Mitigation (03:07 – 03:11)

Since recovery after stage 2 is impossible, only **prevention** and **early
intervention** remain.

- **03:07 · `bt-hang-watchdog`** — reimplements the missing kernel handler in userspace:
  tails the kernel log, and after 3 timeouts in 60 s issues `USBDEVFS_RESET`, the same
  ioctl `usb_queue_reset_device()` performs. Threshold 3 rather than the kernel's 5,
  deliberately.
- **03:07 · USB autosuspend disabled** for the radio (`enable_autosuspend=0` plus a udev
  rule pinning `power/control=on`).
- **03:11 · Metrics collector** — 15-minute snapshots surviving reboots.

Detection was verified end-to-end by injecting synthetic `tx timeout` lines into
`/dev/kmsg`. **Those three fabricated lines are the only non-genuine entries in this
boot's journal** and are noted wherever counts are quoted.

*Deliberately not done:* disabling LE (`ControllerMode = bredr`) would have removed a
6250-event/boot log storm, but silently breaks BLE peripherals and the user had not
confirmed they use none.

---

## Phase 4 — Publication (03:26 – 03:44)

Repo built from the working directory, restructured, and **sanitised**.

The audit before publishing found the working directory contained the Wi-Fi **access
point BSSID** — indexed by public geolocation databases, so publishing it can reveal
where the machine physically is. Also the WLAN and controller MACs, three paired-device
MACs, and the root filesystem UUID.

`tools/sanitize-logs.sh` was written to scrub these deterministically. **It shipped with
an infinite loop on its first version** — the MAC replacement matched its own output and
the scanner rediscovered it forever. Rewritten to build output incrementally.

**03:43 · Published** as `ivoitovych/qca9377-bt-hang`.

Two decisions worth recording: the repo is public because the user wanted the work to
survive a machine that might not come back; and no AI attribution appears anywhere, at
the user's explicit request.

---

## Phase 5 — Review (05:00 – 05:32)

A code review of the whole project returned **14 findings**, all fixed in `4c4047d`.
The two that mattered:

- **The sanitiser destroyed a log used in place** (`in.log == out.log`) — `awk … > out`
  truncates before awk opens the input — *while printing "verified: no MACs remain"*.
- **Dash-separated MACs passed straight through with a false all-clear**, because
  verification grepped only the colon form it substituted. A tool whose entire purpose
  is preventing a BSSID leak was confidently green-lighting one.

Also: the documented multi-device override never worked (the unit hardcoded
`BT_VID`/`BT_PID`, overriding the script); `install.sh` printed `=== INSTALLED ===` even
when everything failed; and the before/after report used `journalctl -n1`, which returns
a boot's **last** entry rather than its first.

**05:32 · Restoration guide** (`docs/restore-original-state.md`) plus
`tools/verify-restored.sh`, after establishing that `uninstall.sh` did not cover
everything that had changed.

---

## Phase 6 — The cold power-off (06:22)

The machine was powered off and on. **The controller came back**, answering HCI commands
with `errors:0`. Two code paths that had *never executed* ran for the first time:

- the **udev rule** fired on device `add` — `power/control = on`
- the **watchdog** resolved `device present at 3-3 (hci0)` via the device's own sysfs
  path

Two bugs surfaced immediately on real hardware:

- **06:27 · The watchdog was suffocating.** `MemoryMax=64M` was a guess made without
  measuring; `journalctl -kf` mmaps the journal and sits near 45 MB. The cgroup hit its
  ceiling **21 times in three minutes** (`memory.events: max 21`), forcing reclaim and
  swap. A watchdog that gets OOM-killed under memory pressure fails exactly when needed.
  Raised to 256 MB.
- **06:29 · The before/after split was corrupting itself.** `CHANGE_EPOCH` came from the
  watchdog unit's mtime, so editing the unit at 06:26 relabelled the 06:22 boot as
  "before". Same failure shape as the `-n1` bug from review: a timestamp that does not
  mean what the comparison needs. Now anchored to a write-once install stamp.

**06:32 · The root cause was finally settled at source level**, removing the caveat
carried since Phase 2:

- `0x3503` appears **nowhere** in upstream `btusb.c` (v7.0) — which carries 78 other
  `0x13d3` entries
- the shipped `btusb.ko` contains no `d3 13 03 35` byte pair, while `d3 13 62 33`
  (13d3:3362, a known entry) *is* found, validating the scan
- 78 `13d3` entries in the binary, 78 upstream — no distro patch adds it

---

## Phase 7 — Observability (06:46 – 07:00)

Before testing could begin, an audit asked whether the logs would let a reproduction be
reconstructed. **They would not.** Five blind spots:

1. The watchdog logs only at startup and when it intervenes. "No timeouts", "two
   timeouts but never reached three", "threshold reached but suppressed by cooldown" and
   "gave up" all looked identical — silence — and the near-misses are the most
   informative states.
2. No HCI capture. dmesg says a command timed out; it cannot say what preceded it.
3. Manual test steps recorded nowhere.
4. Metrics sampled every 15 minutes against a ~30-second failure.
5. Four streams with nothing correlating them.

Added: `bt-trace` (rotating btsnoop via `btmon`), `BT_VERBOSE=1`, `bt-mark`,
`bt-timeline`, and event-driven snapshots on topology change.

Trace budget later raised to 128 MB × 30 ≈ 3.8 GB with a hard floor — capture prunes,
then stops, rather than let free space fall below 10 GB. It writes continuously on a
working machine and must never be able to fill `/`.

**Two bugs found while testing the tools**, and one of them twice:

- `bt-mark` wrote a stray `0` into the journal. `grep -c` prints `0` *and* exits 1 when
  it matches nothing, so `|| echo 0` appended a second zero.
- **The identical mistake was then reintroduced in `bt-evidence`'s manifest** and caught
  only because the output was inspected. Both now use a shared `count()` helper.
- `bt-trace` `chmod`'d captures after launching `btmon`, racing file creation and leaving
  a window at `0644`. Uses `umask 077`.

**07:00 · `bt-evidence`** — session-based collector writing sanitised transcripts,
before/after state, filtered logs and a manifest into `evidence/sessions/`.

---

## Phase 8 — Reusable tooling, and a bigger evidence base (07:00 – 07:40)

Recurring one-liners were extracted into parameterised scripts so they could be approved
once instead of retyped as novel commands each time — the practice that had already
produced two copies of the same `grep -c … || echo 0` bug.

The genuinely portable ones moved **into** the repo, since anyone hitting this bug needs
them: `bt-state`, `bt-boots`, and a new `bt-diagnose` that auto-detects any USB Bluetooth
controller and returns a verdict. Git-workflow helpers (`repo-scan`, `repo-validate`,
`repo-save`) stayed outside — useful to contributors, not to users.

**Building `bt-diagnose` exposed a latent bug and, through it, much stronger evidence.**

`journalctl --list-boots --no-legend` prints *nothing* on this systemd — the entire
listing is the legend. Three scripts had their own copy of that idiom and silently fell
back to a hardcoded range. `bt-diagnose` examined **1 boot**, found no timeouts, and
reported "signature NOT present" on a machine whose evidence lived in the previous boot.
A failure mode that produces a confident wrong answer.

Fixed by extracting `tools/bt-boot-list`, which tries JSON, then `-q`, then header-stripped
plain output, and *says so* rather than guessing if none work. With correct enumeration:

| | Before | After |
|---|---|---|
| Boots examined | 12 | **34** (back to 2026-05-31) |
| Command timeouts | 102 | **287** |
| Boots that hung | 6 of 12 | **13 of 34 (38%)** |
| Kernel versions | 3 | **4** (6.17.0-29 also affected) |
| Automatic resets | 0 | **0** |

Ten weeks, four kernel versions, 287 timeouts, not one reset attempt. Substantially
better grounds for the bug report than the original window.

---

## Current state

| | |
|---|---|
| Root cause identified | ✅ confirmed behaviourally (34 boots), in upstream source, and in the shipped binary |
| Workaround installed | ✅ watchdog + autosuspend, live and armed |
| Workaround **proven** | ❌ nothing has hung since the power-off |
| Kernel patch | ❌ written, never built or tested |

**The next milestone is the one fact the patch rests on and nobody has yet observed:
that a USB reset during stage 1 recovers the controller.** That is precisely what the
watchdog does, so proving the watchdog works *is* the evidence for the kernel fix.

A methodological tension to keep in view: the autosuspend fix *prevents* the stall, and
the watchdog can only be tested if a stall *happens*. If prevention succeeds completely,
the result is a working laptop and zero evidence for the patch — reproduction may
require temporarily re-enabling autosuspend.

---

## Recurring lessons

- **Measure before capping.** `MemoryMax=64M` and the 15-minute metrics interval were
  both guesses that turned out wrong on contact with reality.
- **A verifier must check every form it claims to cover.** The sanitiser's false
  all-clear was more dangerous than having no verifier at all.
- **`grep -c` prints 0 and exits 1.** Cost two separate bugs in one session.
- **Timestamps must mean what the comparison needs.** Twice a plausible-looking
  timestamp (`-n1`, unit mtime) silently corrupted the before/after split.
- **The premise deserves the same scrutiny as the conclusion.** The root cause was right,
  but the first evidence offered for it (`modinfo`) could not support it.
