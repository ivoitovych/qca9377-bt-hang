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

## Phase 9 — The first real hang, and the claim it broke (07:24 – 07:30)

The user reproduced the failure by hand, manipulating a headset. It was the first hang
with the watchdog armed, verbose logging on, and an HCI trace running — and it tested the
single proposition everything else rested on.

**The watchdog worked.** Detected at 3 timeouts in 20 seconds; intervened 33 seconds
before the first USB-level failure. Not too slow.

**The USB reset failed.** The controller did not recover and left the bus 123 seconds
after the first timeout.

```
07:24:45  first HCI command timeout
07:25:05  watchdog intervened                 (+20 s)
07:25:23  usb 3-3: reset ... device number 2  (+38 s)
07:25:38  device descriptor read/64, -110     (+53 s)   <- stage 2 begins
07:26:48  USB disconnect                      (+123 s)
```

`btusb_qca_cmd_timeout()` calls `usb_queue_reset_device()` — the same operation, via the
same kernel path, that had just failed. **So the proposed patch would most likely not
have prevented this hang.** The finding that the device is unmatched by btusb's quirks
table still stands, verified three ways; what collapsed was the claimed *benefit* of
fixing it. Corrected in README, the bug report and the fix proposal, which now
distinguish "no handler is installed" (established) from "installing one would help"
(not established, and contradicted once).

Two further assumptions fell in the same session:

- **Stage 1 lasted 53 seconds, not ~6 hours.** The earlier figure measured how long an
  *untouched* controller stayed enumerated while idle — not how long it stays
  recoverable. Conflating those was a mistake, and it made the failure look far more
  leisurely than it is.
- **The trigger is not A2DP-specific.** The capture — which began one second after the
  first timeout — shows hundreds of `SCO Data TX` packets (HFP voice), then
  `Start Discovery` returning `Authentication Failed (0x05)`, a `Disconnect`, and
  `Set Powered: Disabled`. The common factor is an audio stream torn down while active.
  That `Authentication Failed` status also appears in the original logs, and now reads as
  a symptom of the stalling controller rather than a real authentication problem.

Every piece of instrumentation built in Phase 7 earned its place here: the verbose
watchdog showed `1/3 → 2/3 → 3/3` then the intervention; cooldown suppression logging
distinguished "ignored the next 14 timeouts" from "rate-limited"; and only the HCI
capture revealed the SCO detail. `bt-incident` and `bt-postmortem` were written during
this phase, after collecting the incident by hand made it obvious they should exist.

---

## Phase 10 — The early reset works (2026-08-10 18:56 → 08-11 00:21)

`BT_EARLY=1` was armed after the previous phase, watching bluetoothd for audio-teardown
failures instead of waiting for the kernel's `tx timeout`. Several reboots later —
including time spent in Windows — a 5 h 21 m boot with 145 audio/profile events produced
the result:

```
EARLY intervention: 2 audio-teardown failure(s) in 90s — resetting BEFORE any HCI timeout.
  EARLY recovery SUCCEEDED
```

**Zero `tx timeout` events for the entire boot.** The reset did not merely recover the
controller after a stall — it stopped the stall reaching the state `cmd_timeout` watches
for. That hook would never have fired.

Together with Phase 9 this gives a controlled pair on the same hardware, same trigger,
same operation (`USBDEVFS_RESET`), differing only in *when*:

| Reset issued | Result |
|---|---|
| 20 s after the first HCI timeout — where `cmd_timeout` acts | ❌ chip left the bus, cold power-off |
| before any HCI timeout, on the bluetoothd signal | ✅ recovered |

**So the headline finding changed.** It is no longer "a device ID is missing from
btusb". It is: *there is a window in which this controller is recoverable, it closes
before the first HCI command times out, and no kernel hook fires inside it.* The signal
that opens it lives at the bluetoothd/AVDTP layer, which may be exactly why.

The missing device ID is still real and still worth fixing — it is just **correct but
insufficient**, and presenting it as the fix would have misled maintainers. The bug
report was rewritten around the timing boundary, with the device ID demoted to finding 1
of 2.

Discipline note: this is stated as a hypothesis with evidence, not a result. **n = 1 in
each direction**, the two hangs may not have been equally severe, and the cooldown
suppressed three further early interventions whose necessity is unknown.

Two tooling bugs surfaced while writing this up, both of the same shape — counters that
matched only the old code path:

- `bt-incident` reported `wd_interventions=0` beside `wd_recovered=1`, because it counted
  the string `intervening` (late mode) and missed `EARLY intervention`.
- `bt-postmortem` had the same blind spot, and would have printed the late-mode verdict
  for an early-mode recovery.

`bt-status` was written this phase, after a third "check what we have by now" request was
answered with yet another ad-hoc command block. It reports **usage alongside failures**,
because "no hang" is meaningless if Bluetooth was never exercised — the trap that boots
-3, -2 and -1 would otherwise have set.

---

## Phase 11 — A second failure path, with no early warning (2026-08-11 06:06)

Provoked deliberately, this time by **repeated connect/disconnect cycles and mode
changes** rather than a mid-stream audio teardown. The result contradicted part of
Phase 10:

```
06:06:25  first HCI command timeout       <- the failure starts here
06:06:36  watchdog intervened     (+11 s)
06:07:09  first USB-level failure (+45 s)
06:08:19  device left the bus    (+115 s)
06:08:38  first EARLY signal     (+133 s) <- arrives two minutes too late
```

`BT_EARLY` could not have helped: bluetoothd gave no warning until long after the
controller was gone. **There are at least two distinct failure paths**, and watching
bluetoothd only covers the teardown-triggered one.

What the incident *strengthened* is the core claim. The reset here was issued **+11 s**
after the first timeout — about as fast as a log-driven watchdog can react — and still
failed. Every reset after the first HCI timeout has now failed, three for three, while
the only reset issued before one succeeded. The recoverable window closes at or before
the moment `hdev->cmd_timeout` becomes eligible to fire.

### The tooling reported the opposite of reality

Both diagnostic tools said the controller was fine while it was off the bus:

- **`bt-postmortem` mixed two incidents.** `grep -m1` over an 11-hour boot picked up the
  previous evening's *successful* recovery and printed `RECOVERED VIA EARLY INTERVENTION`
  with a delta of **−40065 s**. It now clusters timeouts into incidents (gap > 600 s),
  analyses only the most recent, and scopes every timestamp and count to that window.
- **`bt-status` had the same masking flaw** — cumulative per-boot counters meant one
  early success made the whole boot look healthy.

Both now check live state — is there an `hci` node, is the device on the bus — *before*
interpreting any counter. A tool that confidently reports success during a failure is
worse than no tool, and this is the second time in the project that aggregate counting
produced a confidently wrong answer.

---

## Phase 12 — The window can be 7 seconds wide (2026-08-11 19:39)

Reproduced after a cold power-off, with "a few manipulations". This time the
early-warning window **existed** — and the watchdog still missed it, for a reason that
was purely a tuning choice:

```
19:39:48  early signal: avdtp.c:cancel_request() Abort
          early window: 1/2 in last 90s     <- threshold was 2; never reached
19:39:55  first HCI command timeout          (+7 s)
19:40:28  watchdog intervened (LATE)        (+33 s)  -> reset failed
19:42:11  device left the bus              (+136 s)
```

Exactly one usable signal, seven seconds ahead, against a threshold of two.

Lead times measured so far: **−52 s**, enough-for-two, **none at all (+133 s)**, **−7 s**.
A threshold of 2 is unusable against a 7-second window carrying one signal.

`BT_EARLY_THRESHOLD` default lowered from 2 to **1**. The precision data supports it —
`cancel_request() Abort` 4/4, `Suspend` 2/2, `avdtp_connect_cb` 5/5 occurrences fell in
boots that hung — but the cost is real and was accepted deliberately: a false positive
now resets a working controller and drops live connections. The alternative is a
guaranteed power-off, which is worse.

The core claim is unchanged and slightly stronger: **four for four**, every reset after
the first HCI timeout has failed (+11 s, +20 s, +33 s, and the original). What this adds
is a bound on the window — as little as **7 seconds** — which constrains how slow *any*
recovery mechanism can be, a kernel hook included.

---

## Phase 13 — Threshold 1 armed, and no signal arrived (2026-08-11 19:51)

The first test of `BT_EARLY_THRESHOLD=1` never happened: the controller hung **two
minutes into a freshly power-cycled boot**, with light use and **zero** early signals.
bluetoothd logged nothing but routine startup before the stall.

```
19:49     cold boot; healthy and verified responding at 19:50
19:51:20  first HCI command timeout      <- no precursor of any kind
19:51:36  watchdog intervened  (+16 s)   -> reset failed
19:53:19  device left the bus (+119 s)
```

That makes **two of five** instrumented hangs with no usable early warning. `BT_EARLY`
is not a general mitigation — it covers roughly the audio-teardown subset.

What the incident does do is push the central result close to unambiguous:

> **Five for five**, a reset issued after the first HCI timeout has failed — at +11 s,
> +16 s, +20 s, +20 s and +33 s. A factor of three in latency, no difference in outcome,
> and every one of those resets landed inside the 45–66 s window in which the device
> still answered USB.

Stage 1 has now been measured at 45, 49, 53 and 66 seconds. The reset is never late in
wall-clock terms. It is late in *state* terms: whatever the controller loses, it has
already lost by the time it misses its first command.

### Honest status of the workaround

- the early trigger recovered the controller **once**
- it could not act in two of five incidents
- the late trigger has **never** succeeded

For a user, the hang still happens and still needs a power-off. The project's value has
shifted decisively from the workaround to the characterisation.

---

## Phase 14 — A methodological correction (2026-08-11)

The operator disclosed that the reproductions were **not a controlled procedure**:
Bluetooth actions were ad-hoc and essentially arbitrary — connecting, disconnecting,
toggling modes, starting and interrupting audio — with no fixed sequence and no record
of the exact steps.

This matters, because several claims had been written as though the inputs were known.

**Corrected in README, bug report, fix proposal and evidence/README:**

- Trigger attributions ("provoked by a mid-stream teardown", "by connect/disconnect and
  mode changes") are **inferences read backwards out of bluetoothd's logs**, not
  descriptions of a script that was followed.
- The "two distinct failure paths" framing was overstated. What was actually observed is
  **two distinct log signatures**. Whether they are different mechanisms — or the same
  mechanism reached by different unrecorded inputs — is not established.
- The incidents are **not matched pairs**, so differences between them cannot carry the
  weight of a controlled comparison.
- The bug report's `Reproducer` section became "What provokes it (approximate)", since
  no deterministic reproducer exists.

**What survives untouched**, because none of it depends on knowing the trigger — all of
it describes the controller's *response*:

- the device is matched by no entry in btusb's quirks table (source and binary)
- 287 command timeouts across 34 boots, zero reset attempts
- **five for five, every reset after the first HCI timeout failed** (+11 s … +33 s)
- stage 1 measured at 45–66 s in every instrumented case

That distinction — between what the operator did (unknown) and how the controller
responded (measured) — is what keeps the central finding intact. It was worth stating
before a maintainer inferred a rigour that was not there.

---

## Phase 15 — "It works on Windows", and a non-sequitur exposed (2026-08-11)

The operator pushed back on the suggestion that the QCA9377 is simply a weak part to be
replaced, with an argument that settles it: **the same silicon in the same laptop never
faults under Windows**, and the same behaviour has recurred across several laptops over
years. If the chip can run indefinitely under one OS, the hardware is not the
explanation.

That forced a re-reading of our own evidence, and exposed a bad inference.

`BTUSB_QCA_ROME` installs **two** things: the `cmd_timeout` reset handler, *and*
`btusb_setup_qca()`, which downloads `rampatch_usb_*.bin` and `nvm_usb_*.bin` to the
controller. Phases 9–13 disproved the value of the first — five for five, a reset after
the first HCI timeout fails. **The project then concluded the patch would not help. That
does not follow.** The second was never tested. One is recovery; the other is prevention.

"No QCA firmware ever loaded" had been sitting in the evidence since the second hour,
recorded as *corroboration that the device is unmatched*. Nobody asked the next question:
**what is the controller running instead?** Its factory ROM firmware — on every Linux
boot, for the life of the machine. Windows loads Qualcomm's patch, which is most of what
the vendor driver package is.

So the two operating systems are not running the same firmware on the same silicon, and
the stall may be a ROM-firmware defect the rampatch fixes. Written up in
`docs/firmware-hypothesis.md`; the bug report now carries a do-not-submit banner until
this resolves.

Also newly reported, and the most useful reproduction data so far: **failure rate is
device-dependent.** A Sennheiser headset provokes the hang almost immediately; a Lenovo
one runs for hours or days. That is the first controlled variable this investigation has
had, after fifteen phases of arbitrary activity.

The methodological decision, at the operator's insistence and correctly: **collect data
before changing code.** Read the firmware identifiers under both OSes, enable driver
dynamic debug, compare the two headsets — all zero-risk — and only then consider building
a patched module.

---

## Phase 16 — External review: the kernel mechanism was documented wrong (2026-08-11)

A reviewer reading the repository against current upstream source found that the whole
project had been describing the wrong mechanism, and that the error had propagated into
its central conclusion.

**What the repository claimed:** `BTUSB_QCA_ROME` installs
`hdev->cmd_timeout = btusb_qca_cmd_timeout`, which waits for **five consecutive** command
timeouts before resetting.

**What v7.0 actually does** — verified verbatim from `net/bluetooth/hci_core.c`:

```c
static void hci_cmd_timeout(struct work_struct *work)
{
	...
	bt_dev_err(hdev, "command 0x%4.4x tx timeout", opcode);
	hci_cmd_sync_cancel_sync(hdev, ETIMEDOUT);
	...
	if (hdev->reset)
		hdev->reset(hdev);
	...
}
```

No counter, no threshold. And `btusb` installs `hdev->reset = btusb_qca_reset`, not a
`cmd_timeout` handler. Confirmed independently against the shipped binary by a new tool,
`tools/bt-verify-kernel-mechanism`:

```
btusb_qca_cmd_timeout  absent
btusb_qca_reset        PRESENT
```

### Why this mattered so much

Every recovery experiment fired a userspace reset **+11 s to +33 s** after the first
timeout. Under the real mechanism a patched kernel resets at **+0 s**, in the same call
frame that emits the log line the watchdog reacts to.

> **The five failed late resets never tested the patch.** They tested a reset eleven or
> more seconds late. Given the window closes sharply, that difference may be decisive.

So the conclusion "adding the device ID would not have helped" was wrong — and the ID is
interesting again for **two independent reasons**: firmware initialisation (prevention)
and immediate reset (recovery).

The irony is worth recording: Phase 15 corrected one reasoning error while carrying
another one forward inside the correction.

### Other corrections from the same review

- `USBDEVFS_RESET` and `usb_queue_reset_device()` were described as "the same operation
  through the same kernel path". Too strong — the former goes via `proc_resetdevice()` →
  `usb_reset_device()`, the latter queues a reset on the interface. Same machinery,
  different timing and context; a useful proxy, not an equivalent.
- The cross-vendor claim ("not specific to this chip or vendor", "the underlying fault
  has been open since 2019 across vendors") overstated causation from a shared symptom.
  `command tx timeout` is an endpoint symptom, like "disk I/O timeout". Reworded to
  *same failure phenotype, useful prior art*.
- Investigation-plan A1 was called "decisive". Differing HCI/LMP version fields would be
  strong evidence of differing firmware state, but would not establish causation, and
  equal fields would not prove identical binary firmware. Downgraded, with a note that
  `btusb_setup_qca()`'s own ROM-version query is the more direct probe.

### And a better experiment

The reviewer proposed splitting the build in two, which is sharper than what was planned:

- **A: reset only** — install `hdev->reset`, no firmware setup
- **B: full `BTUSB_QCA_ROME`** — reset callback *and* `btusb_setup_qca()`

A fixing it means immediate recovery was the missing piece; A hanging but B fixing it
means firmware initialisation is the cause; both hanging points before the first timeout.
And B refusing to probe is itself informative, since the QCA setup path queries the
controller's ROM version before deciding to load firmware.

Adopted in `fix-proposal.md` §5a. Also noted: `qca_read_soc_version` and the ROM-version
strings are **absent** from the shipped `btusb.ko`, which is worth understanding before
assuming the firmware path would engage.

### Verification discipline

The reviewer explicitly asked not to be treated as the sole source of truth, and was
taken at their word: every claim was checked against upstream source and against this
machine's own binary before the repository was changed.

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
- **A confident diagnosis is not a validated fix.** The missing device ID was real and
  verified three ways. The inference that adding it would help was neither — and the
  first direct test contradicted it.
- **Check what a number actually measures.** "Stage 1 lasts 6 hours" was true of an idle,
  untouched controller and false of a recoverable window. The same figure, two different
  quantities.
- **A failed experiment is a direction, not a dead end.** The late reset failing was the
  most useful result of the project: it reframed the question from *"which device ID is
  missing?"* to *"when does the recoverable window close?"* — and that question had a
  better answer.
- **Report usage next to failures.** Three consecutive clean boots meant nothing, because
  Bluetooth had barely been used. A metric that cannot distinguish "it worked" from "it
  was never tried" invites exactly the wrong conclusion.
- **Scope an analysis to one incident.** Aggregating a whole boot let an evening success
  mask a morning failure, twice, in two different tools. Always check live state before
  interpreting a counter.
- **One reproduction is one failure path.** The early-warning window looked general after
  a single success; a differently-provoked hang had no such window at all. Vary the
  trigger before generalising.
- **Read the mechanism from source before reasoning about it.** Fifteen phases were built
  on a remembered API (`hdev->cmd_timeout`, five-timeout threshold) that v7.0 does not
  use. One `grep` of the shipped module would have caught it on day one, and the error
  silently invalidated the project's headline conclusion.
- **A correction can carry a second error forward.** Phase 15 fixed the recovery/
  prevention conflation while still assuming the wrong timeout mechanism — so the
  "corrected" conclusion was also wrong.
- **Distinguish phenotype from cause.** `command tx timeout` is an endpoint symptom;
  shared symptoms across vendors are prior art, not evidence of a shared root cause.
- **Disproving one mechanism does not disprove the change that carries it.** Adding the
  device ID does two things; five phases were spent refuting one of them, and the
  conclusion "the patch would not help" was drawn without testing the other.
- **"It works on the other OS" is decisive evidence about the hardware.** It was
  mentioned early and under-weighted for fifteen phases, during which the investigation
  drifted toward blaming the chip.
- **Know whether the input was controlled before comparing outputs.** Five incidents were
  written up as though their triggers were known, when they were reconstructed from logs
  of unrecorded, arbitrary activity. Claims about the *controller's response* survived;
  claims about *which trigger causes which behaviour* did not.
