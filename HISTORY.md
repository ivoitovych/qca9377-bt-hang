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
>
> *(Superseded, kept as written: the "~6 hours" conflation is corrected in
> Phase 9, "decaying into stage 2" is reclassified as censored-by-us in
> Phases 24–26, and the M.2-rail claim is demoted to an untested inference —
> EX-017/EX-019, `docs/issues.md` BT-1.)*

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
*(That mechanism description is wrong and is corrected in Phase 16: v7.0 installs
`hdev->reset`, fired on the FIRST timeout with no threshold. Kept as written because
this is the model the next thirteen phases were reasoned under.)*
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
  deliberately. *(Both claims superseded: `USBDEVFS_RESET` is a proxy, not the same
  path — Phase 16 — and the kernel has no 5-timeout threshold — Phases 16–17.)*
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

A code review of the whole project returned **14 findings**, all fixed in `4c4047d`
*(a hash from the pre-publication working repository; it does not exist in this
repository's rewritten history — verified 2026-08-15)*. The two that mattered:

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

## Current state — as of the end of Phase 8, 2026-08-10 07:40 — ⚠️ SUPERSEDED

> ⚠️ This table is a snapshot from the morning of 2026-08-10, kept in
> chronological place. Nearly every row was overturned by later phases:
> the "root cause" was demoted to an established driver difference with an
> unestablished benefit (Phases 9, 16), five hangs followed the power-off,
> and the mechanism description was corrected twice (Phases 16–17). For
> current claims use `docs/issues.md`. A section titled "current state"
> is exactly what a searcher lands on, which is why this banner exists
> (review 2026-08-15T1752Z §1.2).

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

## Phase 17 — Second review pass: the A/B experiment could not have isolated anything

The same reviewer (GPT 5.6 Sol) re-read the repository against current upstream source
after the Phase-16 corrections landed, and found one substantive design flaw plus several
factual errors. All verified locally before acting.

### The design flaw: `BTUSB_QCA_ROME` is six behaviours, not two

The A/B pair adopted in Phase 16 assumed the flag means "reset callback + firmware setup".
It does not. `btusb_probe()` installs:

```c
data->setup_on_usb  = btusb_setup_qca;
hdev->shutdown      = btusb_shutdown_qca;
hdev->set_bdaddr    = btusb_set_bdaddr_ath3012;
hdev->reset         = btusb_qca_reset;
HCI_QUIRK_SIMULTANEOUS_DISCOVERY;
btusb_check_needs_reset_resume(intf);
```

So the planned inference — *"A hangs, B fixes it → firmware is the cause"* — was invalid.
It would only have licensed *"something in the QCA ROME path fixes it"*. A cure, not a
cause.

Replaced with a four-step ladder (`fix-proposal.md` §5a): **A** reset only, **B** reset +
`setup_on_usb`, **C** full `BTUSB_QCA_ROME`, **D** production candidate adding
`BTUSB_WIDEBAND_SPEECH`. WBS is deliberately held back to D, because it changes advertised
HFP wideband capability and the reproducer is built on audio profile and mode transitions —
introducing it earlier would confound the thing being measured.

### My `qca_read_soc_version` concern was a red herring

Phase 16 flagged that symbol as absent from `btusb.ko` and suggested it was "worth
understanding before assuming the firmware path would engage". It lives in `btqca.c`,
built as a **separate `btqca.ko`** under `CONFIG_BT_QCA` — verified: the module is right
there in `/lib/modules/.../bluetooth/`. `btusb_setup_qca()` has its own independent USB
mechanism (`QCA_GET_TARGET_VERSION` → `qca_devices_table` → `QCA_CHECK_STATUS`). The
concern was groundless and has been removed.

Related: `strings btusb.ko` was also used to look for "ROM version" labels. Those are C
comments; they never survive compilation. Both checks are gone from
`tools/bt-verify-kernel-mechanism`.

### `13d3:3563` is MediaTek, not a QCA comparator

The "neighbouring IDs" evidence listed `3491`, `3496`, `3501` and `3563` together.
Verified against upstream v7.0: the first three are
`BTUSB_QCA_ROME | BTUSB_WIDEBAND_SPEECH`; **`3563` is `BTUSB_MEDIATEK`**. It has been
removed from the argument and is now cited for the opposite point — `13d3` is IMC
Networks, an ODM shipping modules around several vendors' silicon, so numerical proximity
alone proves nothing about a device's family.

### "Refuses to probe" was the wrong description

`setup_on_usb` is not run during USB probe. `btusb_open()` calls it when the HCI device is
opened, before HCI URBs start. If `btusb_setup_qca()` finds an unsupported ROM version and
returns `-ENODEV`, the USB device stays bound to `btusb` and it is *HCI open/setup* that
fails. Reworded — the distinction matters when reading logs that clearly show a successful
probe.

### Stale mechanism text still contradicting the correction

Phase 16 did not purge everything. `fix-proposal.md` still described
`hdev->cmd_timeout = btusb_qca_cmd_timeout` and "5 consecutive timeouts", still expected
`Multiple cmd timeouts seen. Resetting usb device.` in its validation section, and the
README still said "threshold is 3 rather than the kernel's 5". A maintainer would have
met the corrected mechanism at the top and the disproven one five minutes later. Purged.

### Two more over-claims softened

- *"the controller runs factory ROM firmware on every boot"* → what is established is
  that **no rampatch/NVM download happens through that path**. What state the firmware is
  actually in is exactly what build B's version queries would reveal.
- *"`errors:0` means USB is perfectly healthy"* → **no errors in those HCI counters**.
  USB health is established separately, from USB-level evidence.

### One useful instrumentation note

`btusb_qca_reset()` has two paths: toggle a `bt_en` GPIO if present, else fall back to
`btusb_reset()` → `usb_queue_reset_device()`. Build A must record **which** ran —
`Reset qca device via bt_en gpio` or `Resetting usb device.` — because that determines
whether it is even comparable to the earlier `USBDEVFS_RESET` attempts.

### Standing lesson

Two review passes have now found errors that invalidated conclusions, both times in the
mechanism rather than the measurements. The measurements have held up throughout; the
model built on top of them has not. Read the source, then reason.

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
- **Kernel work is hostile to reasoning from names.** `cmd_timeout`,
  `qca_read_soc_version`, "ROME quirk", "USB reset" — each is descriptive enough that a
  plausible mental model forms automatically, and ten lines of real source then destroy
  it. The rule that would have prevented both review findings, applied mechanically:
  > whenever an inference depends on *"function X probably does Y"* — **read X**;
  > whenever it depends on *"flag X probably enables Y"* — **enumerate every branch
  > that tests X**.
- **A flag is not its headline behaviour.** `BTUSB_QCA_ROME` reads like "QCA quirks" but
  installs six separate things. An experiment that toggles it isolates nothing; it takes
  one build per behaviour to attribute a cause.
- **Absence in a binary proves nothing until you know where the symbol lives.**
  `qca_read_soc_version` is in a different module; C comments never survive compilation.
  Two "findings" evaporated on that basis.
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

---

## Phase 18 — reconstruct the session from logs, not from memory

The operator returned from a Windows session, re-paired the headset there, and came back
to Linux to find the device would not connect. The recovery attempt — forget the device,
re-pair, power-cycle the headset — ended with the headset appearing as *hands-free /
mono* rather than as a stereo audio device, and the controller died shortly after.

The account was necessarily approximate: nobody types a log while debugging. The
operator's suggestion was to stop relying on recollection and **reconstruct the sequence
from the logs themselves** — the factual record, with timestamps. That produced
`tools/bt-actions`.

**What the reconstruction found immediately.** Opening the GNOME Bluetooth settings panel
is followed, within 0.06–10 s, by an HCI command-pipeline desync
(`unexpected event for opcode 0x2005`, `HCI_LE_Set_Random_Address`), which then repeats at
an **exact 16.0 s cadence** for as long as the panel stays open — runs of 228, 487 and
2480 repeats were recorded. This holds on every boot examined. After months of
"it hangs eventually", this is the project's first *deterministic, seconds-to-reproduce*
misbehaviour, and it explains the original reported symptom — "the ring is not rolling in
the Bluetooth settings" — as the scanning cycle that drives it.

**And what kept it honest.** The obvious next step was to call it the cause. Instead
`tools/bt-boot-stats` cross-tabulated the signature against the hang over all 34 boots:

|  | hung | did not hang |
|---|---|---|
| desync present | 16 | **8** |
| desync absent | **2** | 8 |

Eight boots carried the signature and never hung — one with 6250 occurrences across 45
hours. Two hung with none. Both false positives and false negatives: a **companion
symptom, not a cause**, and it must be offered upstream as exactly that.

**The measurement that reshaped the fix.** This incident contained the first EARLY reset
ever captured — the watchdog fired 134 s *before* any HCI timeout. It worked, in the
narrow sense: the device re-enumerated and the HCI stack re-registered 315 ms later. Then
the same desync recurred **107 ms after that**, and the controller hung completely 132 s
later and left the bus.

**⚠️ This paragraph originally overreached and has been corrected.** What it first said was
that "a reset callback alone would not have prevented this hang", and that firmware reload
was therefore "the one remaining untested variable". Both claims are withdrawn. The
corrected reading follows; the reasoning error is dissected below because it is the third
instance of one species.

What the early reset licenses, exactly:

> A USB reset at 00:09:37 did not permanently prevent a *different* failure from
> developing 133 s later.

What it does **not** license:

> A USB reset at 00:11:50 — the first HCI command timeout — would have failed to recover
> the controller.

Those are different experiments, and Build A is the second one. `hdev->reset` is reached
from the command-timeout path; it fires at **+0 s**, synchronously with the log line. The
watchdog's reset landed 133 s *earlier*, at a moment when no timeout had occurred and
`hdev->reset` would not have been called at all. **Build A remains untested and stays in
the ladder.**

**A wrong aside, corrected.** While making the above correction, the claim was made that
v6.12's `btusb_reset()` — which opens `if (hdev->reset) { hdev->reset(hdev); return; }` —
"would recurse for a QCA device". It would not. v6.12 has QCA ROME table entries but
installs `hdev->cmd_timeout = btusb_qca_cmd_timeout`, and **nothing in v6.12's `btusb.c`
assigns `hdev->reset` at all** — the only occurrences are that read. So the delegation
never fired for any btusb device and there was no QCA recursion path. The accurate
statement is: *v6.12's `btusb_reset()` contained a delegation that would be recursive if a
reset callback re-entered it; QCA ROME did not use such a callback there. v7.0 removes the
delegation and adds the QCA reset callback.*

This is the fourth instance of the same species, made **while correcting the third** — a
code path inferred from a structure without checking whether the assignment that would
activate it exists. Reading the function was not enough; the rule needs the second half:
whenever an inference depends on *"this callback would be X"* — **grep for the assignment**.

The mechanism verification does hold, and is worth keeping. Read from v7.0 source:
`hci_cmd_timeout()` calls `hdev->reset(hdev)`; for a `BTUSB_QCA_ROME` device that is
`btusb_qca_reset()`, which with no `bt_en` GPIO falls through to `btusb_reset()` and
`usb_queue_reset_device(data->intf)`. `btusb_driver` defines no `.pre_reset` or
`.post_reset`, so USB core unbinds and rebinds the interface around the reset — which is
precisely the stack disappearance and re-registration the log shows. So the watchdog's
`USBDEVFS_RESET` is a sound proxy for the **kind** of reset Build A requests. It is not a
proxy for **when** Build A requests it, and this project has already demonstrated that
timing is decisive: five late resets failed and one early one succeeded.

Corrected conclusion: *the successful early reset shows that a USB reset does not
permanently eliminate the controller's tendency to fail — after recovering, it entered the
fatal failure again. That raises the QCA initialisation/firmware hypothesis from a
footnote to a strong prevention candidate. It does not eliminate first-timeout recovery,
because that point remains unoccupied by any experiment.*

**How the error was made.** The chain was: reset → desync returns 107 ms later → eventual
hang → therefore reset-only cannot work. That chain runs entirely through the desync — and
this same phase had just established, with 8 false positives and 2 false negatives, that
the desync is neither necessary nor sufficient for the hang. The argument quietly promoted
the desync back to a causal marker in the paragraph immediately after demoting it. Worse,
the resulting claim contradicted `docs/fix-proposal.md`, which had it right and was left
untouched — so the repository asserted both readings at once for one commit.

**Evidence discipline.** At the operator's suggestion, factual material for the bug report
is now captured as numbered **exhibits** (`evidence/exhibits/`, `tools/bt-exhibit`), each
carrying its claim, the exact extraction command, that command's verbatim output, and the
relevance. The tool runs the command and writes both in one pass — a maintainer cannot
verify a summary, but can re-run a command, and that only means something if the command
shown provably produced the output shown. Hand-pasting the two separately lets them drift.

### Lessons added

- **Reconstruct the session from logs before writing down what happened.** The operator's
  account had the *shape* right and the *order* wrong; the logs had both. Anything
  destined for a bug report should be derived from the record, not from recall.
- **A signature that is dramatic in a failing run may be present in every passing one.**
  Cross-tabulate against non-failures before believing any correlation. The desync looked
  like the answer for about ten minutes.
- **A deterministic minor bug beats a random major one, for reporting purposes.** A
  maintainer can reproduce the panel-triggered desync in seconds; nobody can reproduce
  "it hangs after several hours".
- **An intervention at time T tells you nothing about the same intervention at time T+133s
  — least of all in a bug you have already shown to be timing-sensitive.** The early reset
  was read as a test of Build A. It is not; Build A fires at the first HCI timeout, which
  had not happened yet. A proxy for the *kind* of operation is not a proxy for its
  *position in time*.
- **A demoted marker cannot be used in the very next argument.** Having proved the desync
  is neither necessary nor sufficient for the hang, the next paragraph used "the desync
  came back" as evidence that the hang was inevitable. If a signal is not causal, it
  cannot carry a causal inference three sentences later.
- **Check a new conclusion against the documents that already disagree with it.**
  `docs/fix-proposal.md` stated the correct position throughout and was never consulted
  while `HISTORY.md` was being written to contradict it. A contradiction inside one
  repository is cheaper to find than one found by a maintainer.
- **A document is not corrected until its residues are.** `fix-proposal.md` still carried
  text from at least three superseded models of the bug — `13d3:3563` cited as a QCA
  neighbour, "carries factory ROM firmware forever", `BTUSB_WIDEBAND_SPEECH` listed as one
  of the things `BTUSB_QCA_ROME` installs, `btusb_setup_qca()` failing "during probe", and
  a claim that dropping WBS "isolates the recovery behaviour". Each had been corrected
  *somewhere else* in the repository, which is what made them invisible: the correction
  felt done. Corrections must be applied by grepping the whole tree for the wrong claim,
  not by writing the right one in the nearest paragraph.
- **A statistic from uncontrolled use is not a baseline.** The decision tree opened with
  "stock fails (established: 13 of 34 boots)" while A4 simultaneously said no quantified
  reproducer exists. Both were in the same document. An observational incidence rate and a
  controlled failure rate under a fixed protocol are different numbers and only one can be
  a denominator.
- **Scope discipline is part of the evidence.** §7 proposed a default `hdev->reset` for all
  unmatched Bluetooth devices as "cheap and carries little risk" — an assertion about every
  controller Linux supports, drawn from one device. It is now explicitly excluded from the
  first submission. A three-line device-ID fix with strong evidence should not be carried
  into review alongside a core-behaviour change with none.
- **The interval between a successful recovery and the next failure is the most
  informative window available, and it has never been instrumented.** 00:09:38 to 00:11:50:
  the controller was demonstrably *not* poisoned at the start of it and demonstrably dead
  at the end. With `usbmon`, `bluetoothd -d` and 214 dynamic-debug sites now live, the next
  reproduction can show what crosses that gap — which is more informative than watching the
  death again.
- **Timestamps must carry their date.** Sorting a merged timeline on time-of-day silently
  reordered a session that straddled midnight, hiding the first hour. This is the third
  distinct timestamp bug in the project.
- **Check the units of a fraction.** `journalctl` prints microseconds; treating them as
  milliseconds inflated every computed cadence by 1000× and briefly produced "every 340
  seconds" for events 0.34 s apart.

### Phase 18a — the logging upgrade that destroyed evidence

Acting on the operator's question about whether enough logging was enabled, four sources
were added: kernel dynamic debug on `btusb`/`hci_core`/`hci_sync`/`hci_conn` (214 sites,
deliberately excluding the 364 per-packet sites in `hci_event.c` and `l2cap_core.c`, which
would flood the log *and* perturb the timing being measured), `bluetoothd -d`, a `usbmon`
pcap capture of the USB transport, and a raised journal size cap.

The journal drop-in also set `MaxRetentionSec=1month`, intended as a generous bound. It is
not a bound. journald applied it on restart and permanently deleted every boot before
2026-07-12 — **34 boots of hang history reduced to 18**, in a change whose sole purpose was
to retain more. The files are gone; there is no recovery.

The dataset survived only because `EX-003` had been generated nine minutes earlier and
contains the full 34-boot table inline. The exhibit has been annotated to say it is no
longer re-runnable, since it now makes a claim the machine can no longer reproduce.

- **A size cap and an age cap are opposite instructions.** `SystemMaxUse` discards
  oldest-first *only when the cap is reached*. `MaxRetentionSec` discards *immediately and
  unconditionally* on the next restart. Reaching for both because each sounds like a limit
  is how a retention increase becomes a deletion.
- **Verify what a config change did, not just that it applied.** The journal shrinking from
  770 MB to 416 MB was visible in the very next command; it was noticed only because the
  disk-usage figure happened to be printed. A change intended to grow storage should have
  been checked by counting boots before and after.
- **Evidence captured is evidence kept; evidence regenerable is evidence at risk.** The
  exhibit convention was adopted an hour before it saved this dataset. Anything that
  matters should be captured now, not left as a command to re-run later — the machine
  it runs against is the thing under investigation, and it changes.

---

## Phase 19 — the SCO path, and three hypotheses killed in one night

Dynamic debug from boot made it possible, for the first time, to name the command in
flight when the controller stopped answering. Two failures were captured, and they say
different things.

**Failure 1 (05:00:16).** `HCI_Setup_Synchronous_Connection` (0x0428, the SCO/eSCO link
setup for HFP) was submitted 36 ms after the A2DP transport went idle, was never answered,
and timed out 2.169 s later. It was the only 0x0428 in that entire boot. Recorded as
`EX-006`, `EX-007`.

**Failure 2 (06:26:25).** The same command was answered **within 2 ms**. The link reached
`handle 0x0003`, btusb switched the USB alternate setting (`Looking for Alt no :6 / :3`),
and the link came up cleanly. What went unanswered was the **Disconnect (0x0406)** tearing
it down seven seconds later. Recorded as `EX-009`.

So the constant across both is **not an opcode**. Setup went unanswered once, teardown the
other time. What they share is SCO link handling and the USB alternate-setting switch btusb
performs to obtain isochronous bandwidth — the same path that produces the
`setting interface failed (110)` line recurring since the earliest logs. The target moved
from "a specific HCI command" to **the SCO/isochronous path in btusb**.

**And a third measurement that constrains the mechanism.** At the moment HCI stopped
answering, every URB was completing with status 0; the first non-zero URB status came
**31.4 s later** and descriptor-read failures later still (`EX-008`). The onset is not a
transport wedge. The device keeps servicing USB while refusing to answer HCI, and the USB
collapse is downstream. Stated narrowly — and the narrow form is the defensible one — this
rules out **USB transport failure as the immediate cause of the first HCI timeout**. It does
not exonerate the USB side entirely: an alternate-setting transition is a configuration
action rather than ordinary traffic, and could still leave the controller in the state that
later stops answering.

### Three hypotheses killed

Each looked compelling, and each died to the same test — *how often does the antecedent
occur without the consequent?*

| Hypothesis | Killed by |
|---|---|
| The 16.0 s desync causes the hang | 8 boots had it and never hung; 2 hung without it |
| Playback stopping triggers the hang | Transport reached IDLE ≥5 times in one boot, no SCO setup followed |
| GNOME Settings being the active client triggers it | 15 client entries and two panel opens in that same boot, still nothing |

### Lessons added

- **The same reasoning error four times means the rule was never mechanised.** Every one
  was a temporal adjacency promoted to a causal claim. Noticing the pattern did not stop
  it; only building the 2×2 into `bt-trial` did, so the question is asked automatically
  rather than remembered.
- **A trial must record the stimulus, not only the outcome.** A 20-minute survival that
  never provoked SCO setup was indistinguishable in the results file from a survival that
  did. Those are different rows of the table and the difference is the whole experiment.
- **Check what a count measures before narrating it.** "Audio flowed for 7 seconds" was
  written from the gap between setup and teardown; the packet count says 11 packets in
  30 ms, then silence. SCO at 8 kHz carries hundreds per second. The seven seconds were
  seven seconds of *nothing* — a different fact, and possibly a more interesting one.
- **A verifier derived by hand will drift; derive it from the thing it verifies.**
  `bt-verify-install` reported "running system matches the checkout" over a hand-written
  list that had gone six tools stale — a false all-clear, worse than no check. Both its
  artefact list and its unit list are now parsed from `install.sh`. On the first run of the
  fixed version it immediately found a genuinely drifted binary.
- **Log verbosity has a cost that must itself be measured.** Enabling per-packet debug
  produced 1.56 M kernel lines in 16 minutes — 5.8 GB/h, enough to exhaust the journal cap
  in under three hours and rotate away the evidence it existed to preserve. "File" was the
  wrong granularity: volume tracks a call site's position in the data path, not which file
  it lives in.

---

## Phase 20 — the instrumentation fails, three ways

A session with the Lenovo earbuds produced the most informative result so far and then
demonstrated that the apparatus could not record it.

**The result.** Three synchronous-link setups were issued and the controller survived all
three. That fills the cell of the 2×2 that had been empty and **refutes the simplest
reading of the two failures**: SCO setup alone does not hang this controller.

| | hung | survived |
|---|---|---|
| SCO setup requested | 2 | **3** |
| no SCO setup | 0 | several |

Whatever distinguishes the fatal cases must therefore be in the *parameters* of the
request — voice setting, packet type, maximum latency, retransmission effort — which exist
only in the btsnoop capture and never in the kernel log.

**Failure 1: the captures were gone.** `btmon` had aborted **67 times** in that boot
(`BT-4`), and the retained files covering the relevant window had been rotated away. BT-4
stopped being a nuisance the moment it destroyed the only copy of the data the
investigation now depends on.

**Failure 2: a retention fix that never took effect.** `bin/bt-trace`'s `KEEP` default had
been raised 30 → 400 days earlier, and `changes-applied.md` recorded it as done. But
`bt-trace.service` sets `BT_TRACE_KEEP=30` explicitly, silently overriding the default. The
service kept 30 files the entire time while the documentation claimed 400. **Changing a
default is worthless when the caller sets the variable**, and the documentation asserted a
state that was never true.

**Failure 3: no trial was ever open.** The structured SCO fields added to `bt-trial` — which
exist precisely to record whether the stimulus was applied — captured nothing on all three
occasions a hang occurred, because opening a trial required the operator to type a command.
The operator pointed out why that could never work: Bluetooth starts with the system and
begins scanning before anyone can reach a terminal, and the environment holds discoverable
devices that cannot be switched off. A manually opened trial had already missed the window.

### What was built in response

- `bin/bt-capture` — a decode-free HCI capture. The crash is in btmon's *decoder*, so this
  reads raw frames from the kernel monitor socket and writes btsnoop without parsing any of
  them. Verified readable by `btmon -r`. Runs alongside btmon rather than replacing it.
- `tools/bt-sco` — pairs each setup request with its completion and prints decoded
  parameters, the comparison that now matters.
- `tools/bt-logvolume` — answers "what is filling the log" as a tool rather than a
  retyped pipeline.
- `bt-trial-auto.service` — **every boot is a trial**, opened before `bluetooth.service`,
  closed by the watchdog on a hang or by systemd at shutdown.

### Lessons added

- **A fix to a default is not a fix if the caller overrides it.** Verify the value in
  effect, not the value in the source. The same evidence was lost twice, and the second
  loss happened under a documented "fix".
- **Instrumentation that requires a human to arm it will be unarmed when it matters.**
  Three hangs, three times no trial open. The apparatus must default to recording.
- **A diagnostic tool's own bugs are load-bearing.** `BT-4` was filed as a low-priority
  annoyance in a tool nobody was investigating; it then became the sole reason a finding
  could not be pursued. Bugs in the measuring instrument outrank bugs of equal size
  elsewhere.
- **Record what the experiment measures, not what it was hoped to measure.** Auto-opened
  trials record `survived`, never `ok`, because they say only that the machine did not
  hang — not that any protocol was carried out. The denominator they build is
  observational and is labelled that way in the code, the README and the register.

---

## What actually changed, in method rather than findings

Two shifts did more for this investigation than any single measurement.

### Negative evidence became first-class data

For most of this project, observations that failed to reproduce the bug were treated as
wasted runs. They are the opposite: they are the only thing that kills a hypothesis.

| Observation | Formerly | Now |
|---|---|---|
| 3 synchronous setups survived | an unhelpful session | the control group — proves setup is not sufficient |
| 8 boots with the desync, no hang | noise | destroys the desync-causes-it hypothesis |
| 5 IDLE transitions, no SCO | nothing happened | refutes the playback-stop trigger |
| GNOME Settings active, no SCO | nothing happened | refutes the settings-panel trigger |

Every hypothesis this project has killed died to a *non-event*. The 2×2 in `bt-trial` and
the cross-tab in `bt-boot-stats` exist because counting non-events had to stop depending on
anyone remembering to.

### The instrumentation stopped requiring a human

While trials had to be armed by hand, the probability of observing a failure was entangled
with whether anyone had armed the instrumentation — and rare failures are precisely the ones
that arrive when nobody is watching. Three hangs occurred with no trial open. That is
selection bias by construction, not bad luck.

Auto-trials remove the human from the arming path, so ordinary use generates observations.

<!-- REVIEWED-KEEP 2026-08-15T1752Z §1.2: the lesson->invariant loop described
     below (2x2 into bt-trial, awk -f grep into run-tests, provenance from unit
     names) is the repository's most transferable practice. Future lessons
     should keep landing as machinery, not only as prose in this file. -->
### And corrections belong in the machinery, not in the notes

The repeated failure of this project was converting temporal adjacency into cause. Writing
that down as a lesson did not stop it happening a fourth time. What stopped it was building
the check into the tools: `bt-trial` now asks "was the stimulus applied?" automatically, and
`bt-sco --window` shows the surrounding path rather than the isolated fields, because

> **Compare paths, not fields.**

With synchronous audio the variables are structurally entangled — mSBC implies eSCO implies
a packet type implies an alternate setting implies a teardown path — so a five-row dataset
can manufacture extremely persuasive nonsense from a single field comparison. A note saying
"be careful" would be forgotten in the excitement of the next failure. A tool that presents
the path instead of the field changes what is seen in the first place.

---

## Phase 21 — the instrument finds the instrument's bug, then nearly fools everyone

Two capture paths now record the same HCI stream: `bt-trace` (btmon, decoding as it writes)
and `bt-capture` (raw frames, never parsed). That redundancy was built for crash tolerance
and turned out to be a **discovery mechanism**.

**`bt-capdiff` compares them.** On its first run the decode-free path was found to hold an
HCI exchange that btmon had lost one second before each of its restarts. That pointed
straight at the trigger, and BT-4 went from *"aborts ~70 times per boot for unknown
reasons"* to a one-line reproducer:

```console
$ hciconfig hci0 name        # one btmon abort, every time
```

Triangulated rather than assumed — and the first explanation was wrong:

| Probe | HCI command? | Socket | Aborts |
|---|---|---|---|
| `hciconfig hci0 name` | yes | raw HCI | 3/3 |
| `hciconfig hci0 version` | yes | raw HCI | 3/3 |
| `hciconfig hci0` | no, ioctl only | raw HCI | 0/3 |
| `bluetoothctl show` | yes, via MGMT | D-Bus | 0/3 |

So neither a specific opcode nor merely opening the socket: a **command/response exchange
on a raw HCI socket**, observed by the monitor.

**And this project's own probes cause most of the aborts.** `bt-state` and
`bt-health-snapshot` use `hciconfig <dev> name` as a liveness check. The monitoring was
continuously crashing the capture it depends on. The probe is kept — it is a genuine
end-to-end test, and an MGMT alternative could report "alive" from cached daemon state
while HCI is wedged — but it is now recorded as a **known measurement perturbation** rather
than assumed inert.

### The near-miss that matters most

Recording the probe as an intervention meant asking whether failures cluster near probes.
`bt-phase` normalises each failure by the probe gap containing it. First run:

```
mean phase 0.084   (0.5 expected under independence)
6 of 8 failures inside the first 10% of their gap
```

That is the sort of number that becomes a working theory. It was **outcome-dependent
sampling**: a udev rule fires the same probe on bluetooth and USB add/remove — exactly the
events a failing controller generates — so probes cluster around incidents *because the
incident causes them*. The tell was in the gap lengths, 2.7 s and 6.8 s, against a
15-minute timer.

The statistic was computed correctly. The tool's warning fired as designed. **The input was
invalid.**

### Lessons added

- **An exposure denominator must be built from events whose timing is independent of the
  outcome, its precursors, and ideally any shared cause.** "Not caused by the outcome" is
  not sufficient: a probe triggered by audio activity would share an ancestor with
  synchronous-link transitions and manufacture clustering without any reverse causation at
  all.
- **Both boundaries of an interval are part of the denominator.** Excluding endogenous
  probes as *antecedents* is not enough; an outcome-triggered *closing* boundary still lets
  the event choose the interval it is measured inside.
- **Record why a measurement event exists, not only when.** Provenance now comes from unit
  name — `bt-health-snapshot.service` (timer, exogenous) versus
  `bt-health-snapshot-event.service` (udev, endogenous) — instead of being guessed from
  inter-probe spacing.
- **A tool that cannot verify its own preconditions should refuse, not report.** Provenance
  exists only for data recorded after the split, so older boots would present as entirely
  exogenous. `bt-phase` now checks the claim against the known timer period and refuses when
  it fails, because a clean-looking number from a contaminated baseline is worse than no
  number.
- **Absence of evidence is not evidence of independence.** After correction one event
  remained placeable. What vanished was the dramatic *evidence for* clustering — not a
  demonstration that none exists.
- **Disagreement between observers is a fact about the instruments, not a verdict on which
  is right.** btmon was convicted only through additional structure: a restart in its own
  log, the chronology, an intact second path, and finally a deterministic reproducer.

---

## Phase 22 — a repository review finds the prose ahead of the machinery

An external review read the repository at `fd24995` rather than the reports about it, and
found that **the documented discipline was not enforced by the code**. The prose said the
phase analysis was "restricted to exogenous timer-driven probes"; the implementation kept
probes 600 seconds apart and called that exogeneity. Spacing is not provenance. That is the
lesson of `EX-012` failing to be implemented inside the tool written to teach it.

Nine further defects followed from reading the code rather than the summaries:

| | Defect | Consequence |
|---|---|---|
| `bt-phase` | counted timeout **lines**, not incidents | one hang emits a burst; n was inflated and the events were not independent. Validated: **8 lines were 7 incidents** |
| `bt-phase` | timestamps ignored year and month; boots concatenated | a "probe gap" could span a reboot |
| `bt-trial` | no `trial_type` column | an observational hang and a controlled hang pooled into one failure rate — corrupting the exact gate A/B/C/D depends on |
| `bt-trial` | paired the *first* SCO setup with the *first* timeout | with ten profile switches those can be unrelated events |
| `bt-trial` | `sco-params.txt` unscoped and single-path | a trial's "parameters" could contain other boots' requests, read only from the capture path known to lose them |
| `bt-trial` | probe count presented as all interventions | its own `hci_alive()` and every `bt-state` call are uncounted; it is a lower bound |
| `bt-sco` | `--window` discarded the date | a window near midnight splices unrelated days — in the tool built to compare *paths* |
| `bt-capdiff` | claimed "independent" captures | they share the kernel monitor socket and the offline decoder |
| all metrics | `grep -c "intervening"` | misses `EARLY intervention:` entirely — every early intervention has been absent from the metrics since `BT_EARLY` existed. Six call sites |

### Lessons added

- **Review the artefact, not the account of it.** Every one of these was invisible in the
  commit messages, which described the intended behaviour accurately. The gap was between
  intent and implementation, and only reading the implementation could find it.
- **A tool that teaches a lesson must obey it.** `bt-phase` existed to prevent an
  invalid denominator and built one.
- **When a comparison will not come clean, stop tuning it.** `bt-capdiff` still reports
  ~1400 unmatched records after excluding per-attach bookkeeping. The temptation is to keep
  excluding categories until the number looks right; that is fitting the instrument to the
  desired answer. It now refuses to give a verdict and states the three known reasons two
  recordings of one stream legitimately differ.
- **Raising precision can expose a defect that coarseness was hiding.** Comparing capture
  paths on `HH:MM:SS` looked plausible. Comparing on full timestamps revealed the two paths
  do not share a clock at all — `bt-capture` stamps at userspace receive time, btmon at
  kernel time. That is now documented at the point the timestamp is written.

---

## Phase 23 — a fix that silently disabled itself

A second repository review found five defects. Four were straightforward; the fifth was a
**false agreement**, and repairing it produced the most instructive bug in the project.

**The reported defect.** `bt-capdiff`'s matcher asked, for each record, "is there ANY
counterpart with this descriptor within tolerance?" — without consuming the match. Two
records could both claim the same single counterpart, both directions report zero
unmatched, and the tool announce that the paths agree while the multiplicity was 2 to 1.
It could only ever manufacture agreement, never the conservative refusal, but agreement is
the one verdict the tool exists to give.

**The repair, and its own defect.** Matching was made consumptive, and the civil-date
arithmetic — which three tools had grown separate, subtly different copies of — was shared
as `tools/lib/timestamp.awk`, loaded with `awk -f`. Verifying with `BT_CAPDIFF_TOL=0`,
which cannot possibly match anything, reported:

```
only in btmon        0   (no match within 0s)
only in decode-free  0   (no match within 0s)
```

`awk -f lib.awk 'program' input` **does not run `'program'`**. With `-f` present awk takes
the program only from the `-f` files and treats the positional string as an *input
filename*. No error, no output. The matcher never ran; the output files were created empty
by a later `touch`; and `bt-capdiff` reported perfect agreement between paths differing by
278 records. The same trap had silently disabled both of `bt-trial`'s interval
computations.

**Why the test did not catch it.** `tests/run-tests` extracted a *copy* of the matcher and
ran it with `-f`. The copy worked. The shipped invocation loaded nothing. The test also
contained a case — "1-against-1 matches cleanly" — that passed *vacuously* with no program
loaded at all; only the 2-against-1 case had the power to fail.

### Lessons added

- **A shared-library refactor can disable the thing it refactors.** Nothing about
  `awk -f lib.awk 'program'` looks wrong, it passes every syntax check, and it fails
  silently. `tests/run-tests` now greps for the pattern across all tools.
- **Test the artefact the tool actually runs, not a copy of it.** Extracting logic into a
  fixture tests the extraction. The capdiff test now drives `tools/lib/capdiff-match.awk`
  directly, which is the file the tool loads.
- **A test that cannot fail is not a test.** "1-against-1 matches cleanly" asserts zero
  unmatched, which an empty program satisfies perfectly. Every assertion needs a fixture on
  which the wrong behaviour produces the wrong answer.
- **Verify a fix with an input that must break it.** The consumptive matcher looked correct
  and the counts looked plausible. Setting the tolerance to zero — where everything must
  mismatch — is what exposed that no matching was happening at all.
- **A schema change breaks positional access somewhere you did not look.** Adding
  `trial_type` shifted `build` from field 2 to field 3. The report was guarded by
  header-name lookup; `next_trial_no` was not, and would have restarted trial numbering at
  1 and overwritten an existing trial directory. A later review found a *third* consumer
  still reading `$5` for outcome — and that block additionally contained an awk syntax
  error, so it had never executed at all. The rule is now enforced by permuting the header
  in a fixture and requiring the report to be byte-identical.

### The drift detector is an alarm, not a proof

Reviewed and found half-wired: it counted `install.sh` and `uninstall.sh` as code but
excluded them from the timestamp comparison, so a change to either was *described* as a
code change in the warning while being unable to raise it. `etc/`, `tests/` and `devtools/`
were watched by neither — though a udev rule under `etc/` can change measurement
provenance, which is exactly what `EX-012` turned on.

One path list now serves both, and the test suite asserts there is only one. But two limits
are inherent and are now stated in the source:

- it compares timestamps, so it can establish *"code changed after docs"* and never the
  converse — an unrelated documentation edit clears the condition without documenting
  anything;
- documentation can be current in one place and stale in another. At `1990a45` the README
  opened with the correct cautious framing while its Status table still named a triggering
  command that had already been refuted. The detector said nothing, correctly.

### No single mechanism makes a repository trustworthy

The sequence of this project's own quality work reads:

> understand what the code should do → write comments saying so → write tests proving
> specific invariants → make validation run them → warn when implementation and record
> move apart

And after all of it, a separate report block still violated a schema rule implemented
correctly thirty lines above. That is not a failure of the approach; it is the shape of the
answer. Trust comes from **overlapping checks that fail differently**:

| Check | Catches |
|---|---|
| exhibits carrying their own extraction command | reasoning that outran the evidence |
| a second capture path | acquisition loss |
| `tests/run-tests` | algorithms that compute the wrong thing |
| adversarial fixtures (2-vs-1, tolerance zero) | tests that cannot fail |
| external repository review | integration — code that never runs, prose ahead of machinery |
| documentation-drift warning | the written record falling behind |

Each is weak alone. So far most serious defects here have been caught by one mechanism
rather than several — and often not the one that seemed designed for them. That is a
description of where the coverage currently is, not a property to be proud of: the goal is
for a future defect to be caught by **more than one** independent check, because that is
what makes a miss unlikely rather than lucky.

### Correctness has layers, and a check at one does not establish the next

The dead cross-tab is the clearest case this project has produced:

1. the file contained the correct methodological comment;
2. one report block implemented it;
3. another violated it with `$5`;
4. that violation did not matter at runtime —
5. because the whole block was an awk parse error;
6. which did not make the parent command fail;
7. so the report looked fine while omitting an entire section;
8. and a permutation test now catches both the omission and the positional read.

Reading upward: **algorithm → implementation → invocation → execution → interpretation**,
with **host-language representation** underneath all of it — correct awk becomes invalid
shell simply by being embedded badly, which an apostrophe in a comment demonstrated.

Two invariants follow, and they are separate:

- **semantic** — fields are addressed by meaning, not position. Enforced by permuting the
  header and requiring byte-identical output.
- **execution** — the analysis actually ran. Enforced by making every evidence-producing
  command fatal to its caller, and tested by removing the program and by breaking it.
- **admissibility** — the input can justify the calculation. Resolving columns by name is
  only half a guarantee: if a required name is *absent*, awk turns the lookup into field 0
  and computes plausible nonsense while exiting successfully. A missing `outcome` made the
  SCO cross-tab classify every row as survived. Required columns are now a precondition,
  unrecognised `outcome` values are fatal rather than folded into "not hung", and `END` is
  guarded — awk runs it even after `exit`, so a naive refusal prints the very table it is
  refusing to stand behind, and the table is what a human reads.

The endpoint that follows: **a trustworthy analysis does not merely prove that its program
ran; it proves the program received data from which its claimed result is defined.**

`bt-trial` deliberately does not use `set -e`: it probes things allowed to fail, and
errexit's semantics are treacherous. So the analysis commands are made explicitly fatal
instead, which is narrower and does not depend on shell subtleties.

### When a constraint must be remembered, change the representation

The apostrophe incident produced a comment saying *"this comment cannot contain an
apostrophe"*. That is a fragile constraint documented rather than removed. The report
programs now live in `tools/lib/*.awk`, which ends the class outright:

| | Inline shell string | File |
|---|---|---|
| comment punctuation | can terminate the program | irrelevant |
| syntax checking | impossible | `repo-validate` parses every `.awk` |
| exit status | swallowed by the enclosing command | directly observable |
| what tests exercise | a copy | the file production loads |

The same move had already paid off for `capdiff-match.awk`. Doing it once and not
generalising is how the second instance survived.

## Phase 24 — the first uncensored baseline, and the pattern that nearly erased it

The machine was cold-booted into experiment mode — no watchdog, no health probes, USB
autosuspend restored to `Y`, radio `power/control=auto` — and driven to failure. This is
the first observation in the project's history where nothing of ours intervened between
the stimulus and the outcome.

What the journal holds for that trial:

```
05:14:16.715  hci0 opcode 0x0428 plen 17          SCO/eSCO setup
05:14:30.461  Bluetooth: hci0: command 0x0406 tx timeout
05:14:35.710  Bluetooth: hci0: setting interface failed (110)
```

13.746 s from synchronous-link setup to the first unanswered command; five command
timeouts in all; **no `USB disconnect` for the remaining 4 m 48 s of the boot.**

`bt-trial` recorded it as `bt1_status=not_observed`, `timeouts=0`.

### The defect

`hci_cmd_timeout()` names the opcode whenever it has one. The classifier grepped for the
literal `command tx timeout`, which the kernel emits only when it cannot. Across the 23
retained boots *(retention rolls — the denominator was 34 before the Phase-18a deletion,
18 just after, and shrinks as boots age out; each phase's count is correct at its own
date and none should be "corrected" into agreement with another)*:

| pattern | matches | what it is |
|---|---:|---|
| `command tx timeout` | 8 | the rare unnamed form — what the code looked for |
| `command 0x…… tx timeout` | 165 | the normal form — invisible to it |
| `link tx timeout` | 7 | ACL supervision, a different layer |
| `tx timeout` | 180 | all three, conflated |

The shipped pattern found 8 of 173 real command timeouts: a 95% undercount. Seven other
tools used the bare form and therefore over-counted by folding in the link timeouts. Ten
call sites across nine files, each with its own literal, disagreeing in both directions
against the same journal.

### Why the trial was still recorded as a failure

Because the two axes have independent sources. `bt1_status` reads the journal;
`trial_result` reads the controller through `hci_alive()`. The journal axis said
`not_observed` while the controller axis said `failed`, and a controller cannot be both
untroubled and dead. The contradiction is what exposed the pattern.

A single-outcome schema — the design this project started with — would have written
`survived` and been believed. **The two-axis ontology was introduced to keep intervention
from being scored as recovery; it turned out to also be an error detector, because two
independent measurements of the same object can disagree and one measurement cannot.**

### Why the repetition was policed instead of removed

The obvious fix is one shared definition. These ten call sites ship to three directories
and two run from udev, so a shared file buys a load-order problem in exchange for the
duplication. The literal stays duplicated and `tests/run-tests` now rejects any
grep-family call in `tools/`, `bin/` or `devtools/` that spells it differently. The
constraint is enforced where it can be enforced cheaply rather than designed away
expensively — the opposite call from the `.awk` extraction one phase earlier, and for the
opposite reason.

### A test suite that only passed while the hardware was healthy

Fixing the pattern turned four lifecycle invariants red — for an unrelated reason.
`hci_alive()` reads the live device tree, so every `ok` closure in the tests had been
asserting against whatever the machine's real controller was doing. With the radio dead
— the exact state the project exists to study — all four reclassified to `failed`.

They had been passing because the controller happened to be up when they were written.
`bt-trial` now takes its sysfs root from `BT_SYSFS_USB`, and the tests supply a fabricated
device and their own `hciconfig`. The verdict is an input.

**A test suite that cannot run while the fault is present cannot report on the fault.**

### What is now believed, and what is not

Believed: with no watchdog, the controller reached stage 1 and stayed there — enumerated,
no USB-level error at all — for **4331.99 s, one hour twelve minutes** (`EX-016`). Every
previously documented progression to stage 2 within 45–66 s had one of our resets in
between. This window had none and showed no progression.

The observation is **right-censored, by us**. `install.sh --apply` was run to deploy the
pattern fix above; it reloads btusb, and the only USB-layer line in the entire 72 minutes
is that unload. Everything after — descriptor read errors, `device not accepting address`,
`USB disconnect` — followed our own action.

The mode guard in `install.sh` had asked the right question and got the right answer: the
tools being installed were passive. It was guarding the treatment and not the *installer*,
which resets the device regardless of what it carries. Corrected: the force path now
detects a boot that has already logged an HCI timeout and warns that continuing ends a
stage-1 measurement.

**A guard that checks what is being delivered will not notice what the delivery does.**

Not believed yet: that the reset *causes* the progression to stage 2. n=1, censored, and
the alternative — that stage 2 arrives on its own after some interval longer than 72
minutes — is not excluded. The trial that tests it is a boot left strictly alone until
the device leaves the bus or the operator stops.

## Phase 25 — the instrument was the measurement

Phase 24 closed on a single striking observation: one boot, 72 minutes in stage 1, no
progression, censored by our own `install.sh`. `bt-stage2` was written to ask the same
question of the whole retained journal — 3,283,493 kernel lines, 22 boots — because one
observation is an anecdote and the tool to check the rest did not exist.

**Fourteen boots reached stage 1. Zero progressed to stage 2 uncensored.**

Nine were ended by one of our resets. Five by shutdown. The project has never once
watched this controller leave the USB bus on its own.

| first HCI timeout | window | ended by |
|---|---:|---|
| 2026-07-25 03:25 | 5 h 33 m | shutdown |
| 2026-08-09 20:20 | **6 h 26 m** | our reset |
| 2026-08-10 07:24 | 37.75 s | our reset |
| 2026-08-11 06:06 | 29.30 s | our reset |
| 2026-08-12 06:26 | 121.65 s | our reset |
| 2026-08-13 05:14 | **1 h 12 m** | our btusb unload |

(Eight further rows in `EX-018`.)

### The 45–66 s was our own latency

The short windows cluster at 29–121 s because that is how fast the watchdog reacts. The
two boots where nothing fired promptly ran 1 h 12 m and 6 h 26 m — enumerated, no USB
error, throughout both. The figure quoted for months as the fault's timing was a property
of `bt-hang-watchdog`.

This is outcome-dependent sampling arriving through a door the project had already locked
twice. `bt-phase` was built because probes fired by the controller's own failure events
cannot bound an exposure interval. The five-levels table has an entry for it. And the
watchdog — the most obviously outcome-triggered thing on the machine, whose entire purpose
is to act when the controller fails — sat outside that analysis because it was categorised
as *treatment*, not as *measurement*.

**Nothing that acts on the subject is outside the measurement.** A recovery mechanism is an
observer with a hand on the apparatus, and its reaction time is a sampling rule.

### Every rule this project has, restated

The three defects of Phase 24 and 25 are one defect at three altitudes:

| | the filter | the finding |
|---|---|---|
| **grep** | `command tx timeout` | matched 8 of 173 events; a clean zero read as *nothing happened* |
| **test suite** | `hci_alive()` on the live radio | passed only while the hardware was healthy |
| **watchdog** | reset on failure | ended every stage-1 window before it could be observed |

Each is an instrument that stops the thing it is measuring, or fails to see it, in a way
that produces a plausible number rather than an error. None announced itself. Each was
found by a contradiction between two independent views — journal against controller,
short windows against long ones — and none would have been found by looking harder at
either view alone.

### What is now true of BT-1

Stage 1 is established: the controller stops answering HCI during synchronous-audio link
transitions, while remaining USB-enumerated.

Stage 2 is **unresolved**. Not refuted — fourteen censored observations exclude nothing
beyond their own durations, and the longest says only that stage 1 can last at least six
and a half hours. But the sequence "HCI dies, then USB dies" has never been observed
without us in the middle of it.

### And BT-3 is no longer pointed in a known direction

The missing `13d3:3503` quirk installs `hdev->reset`, which `hci_cmd_timeout()` calls on
the **first** timeout. The argument for it was: no reset callback, therefore the controller
eventually disappears. The last step is gone. Supplying the callback would make the kernel
do automatically, on the first timeout, the thing we currently do by hand — and the thing
we do by hand is the only event ever observed to precede a stage-2 collapse.

That does not make the patch harmful. `EX-004` — an early reset *did* recover the
controller — supports the opposite reading, that a prompt reset is a genuine fix and our
hand-issued ones were simply late. The honest statement is that the sign of the effect is
unmeasured, and that build B cannot be scored until untreated stage 1 has a baseline.

**The project spent months trying to find what causes the failure. It has just discovered
it did not know what the failure is.**

### Postscript: the sweep that was supposed to be repo-wide

The `grep -q` fix above shipped with an invariant scanning `tools bin devtools` — a
hand-written list. A reviewer checked the commit and found `install.sh` still holding two
instances, one of them the `failed_this_boot` guard whose only purpose is to stop a btusb
reload from destroying a stage-1 observation. Against a journal of millions of lines — the
size at which the producer is certainly still writing when `grep -q` exits — that guard
would have reported *safe to reload* in exactly the state it exists to protect.

So the defect was not the six pipelines. It was the fourth hand-written path list in this
repository:

| where | the list | what it missed |
|---|---|---|
| `bt-verify-install` | installed artefacts | six tools, reported as a clean system |
| `repo-validate` | knowledge paths, twice | count and timestamp could disagree |
| `run-tests` | `tools bin devtools` | `install.sh`, twice over |

Each was corrected by deriving the set instead: from `install.sh`'s own calls, from one
shared array, and now from every git-tracked file carrying a shell shebang — 42 of them,
against the three directories named before.

**A list that must be remembered will eventually not be.** The rule this repository keeps
rediscovering is that the enumeration is the bug, not the entries.

## Phase 26 — half an hour of nothing, and twelve seconds of something

The machine was cold-booted into the frozen baseline — stock kernel, watchdog off, probes
off, Ubuntu power defaults, tooling deployed and verified in sync — and the operator used
Bluetooth normally. Switching the headset from A2DP to hands-free killed the controller.

It was not the first action of the session, and that matters for reproduction. `bt-actions`
recovers the preceding exposure from the journal — the Settings panel opened at 20:30:25, a
quick-settings Bluetooth OFF at 20:30:30 and ON at 20:30:36, profiles reconnecting, audio
playing and stopping. The controller answered normally throughout, up to and including
20:32:19. Whoever reproduces this should expect to warm it up, not to kill it on the first
switch.

```
20:32:14.329  hci0 opcode 0x0428 plen 17          the profile switch
20:32:21.903  command 0x0406 tx timeout           7.574 s later, no answer
              ┃
              ┃   30 m 36 s   not one USB-layer line. no intervention of any kind.
              ┃
21:02:58      operator opened the Bluetooth settings panel
21:03:23      name hci0 blocked 1                 rfkill toggle OFF
              ┃   12.8 s
21:03:35.809  usb 3-3: reset full-speed USB device   first USB event of the window
21:04:50      device not accepting address 2, error -62 — gone
```

### What this settles, and what it does not

`EX-018` established that no uncensored progression to USB loss had ever been observed —
fourteen windows, every one ended by an intervention or a shutdown before any USB event.
The objection to reading anything into that was fair: absence of the observation is not
evidence about what the observation would have shown.

This window answers the objection in the only way it can be answered. **Half an hour of
untreated stage 1 produced nothing at all** — no reset, no bus error, no disconnect, not a
single line at the USB layer — and the collapse began **12.8 seconds** after the first
thing to touch the device.

It does not prove causation. The reset at 21:03:35 carries no origin in the log, and
`bt-stage2` classifies it `unknown-reset`, which is correct. What it does is retire the
45–66 s figure completely: that number is now **24× smaller** than an untreated window
that showed no progression whatever, and it was always our watchdog's reaction time
wearing the fault's clothes.

Across fifteen windows, a USB collapse has never begun before something touched the
controller. That is not a proof; it is the continued absence of the counterexample.

### The trigger is now operator-attributable

The operator reported switching to hands-free and the log agrees: `0x0428` — Setup
Synchronous Connection — at the moment described, with the teardown unanswered 7.6 s
later. Identical in shape to `EX-016` (`0x0428` → `0x0406 tx timeout`, 13.7 s). For an
upstream report, *"switch A2DP→HFP and it dies, here is the trace"* is a different class of
claim from a timing correlation.

### Two defects the observation found in our own instruments

**`bt-window` reported `✓ no intervention` after the toggle.** It was written during this
window to report on it, and its intervention scan covered watchdog markers, btusb unloads
and USB resets — not rfkill, not operator actions. A window that had just been intervened
upon read as clean, and kept reading clean after the device left the bus. The scan now
counts tooling and operator interventions separately and names which occurred.

**A stage-2 trial excluded itself from its own statistics.** `env_fingerprint` reads
`power/control` from the device's sysfs directory; when the controller leaves the bus that
directory is gone and the field reads `?`. The endpoint comparison saw `power=auto` →
`power=?` as a treatment change and prefixed the row `CHANGED:` — which excludes it from
every rate. So a trial was dropped from the failure statistics **because** it reached
stage 2, and the trials that mattered most were the ones being discarded. A treatment is
what a trial RAN UNDER; a field becoming unreadable at close is a fact about the device's
presence, already recorded in `usb_present`.

Both are the house pattern: an instrument whose silence reads as a finding. The first was
introduced *during* the observation it was built to watch.

## Phase 27 — a second headset, a second reset, and the instruments still wrong the same way

Two days that produced the project's decisive evidence and, alongside it, four more
defects in the tools measuring it — every one an instance of a shape already named here.

### The evidence

**A different headset.** Every instrumented failure until now was the Sennheiser Momentum 4,
the device the protocol was written around. On 2026-08-15 the operator provoked it with
Lenovo earbuds:

```
21:02:15.017  hci0 opcode 0x0428 plen 17        Setup Synchronous Connection
21:02:15.050  Looking for Alt no :6 / :3        USB alt-setting switch
21:02:31.230  command 0x0406 tx timeout         unanswered, 16.2 s later
21:02:36.671  setting interface failed (110)
```

Identical signature, different peripheral. A reviewer's first objection to a
Sennheiser-only record was always going to be peripheral specificity, and that objection is
now answered with data rather than argument. The claim moves from *this headset breaks my
adapter* to **synchronous-link setup breaks this adapter**.

The SCO-to-timeout interval across four instrumented instances is **7.6–16.2 s** — a
distribution, not a constant. Quoting a single figure is how the 45–66 s error was made.

**A second controlled reset, at a wildly different window age.**

| | untreated before reset | reset → USB disconnect |
|---|---:|---:|
| `EX-023` | 12107 s (3 h 22 m) | **11.2 s** |
| 2026-08-15 | 613 s (10 m) | **85.6 s** |

Both killed the device. That was the open question for `BT-3`: whether the reset is lethal
only to a long-stale controller. It is not. The *outcome* is invariant; the *duration* is
not — the second took four kernel reset attempts with descriptor-read errors between them
before the bus gave up. Any report must say **seconds to minutes**, never a constant.

**And a fourth untreated window, censored the cleanest way yet:** 8883.7 s (2 h 28 m) with
zero USB-layer lines and zero interventions, ended by an ordinary shutdown rather than by
anything touching the device. Four windows now — 12107 s, 8884 s, 4332 s, 1837 s — all
showing no progression while untouched.

### The instruments, wrong in the same direction four more times

**The perturbation detectors matched our own log strings, not the kernel's.** Both
`bt-trial` and `bt-window` decided whether a window was disturbed by grepping
`Resetting usb device` — which is `bt-hang-watchdog`'s message. The kernel writes
`usb 3-3: reset full-speed USB device number 2 using xhci_hcd`. So both were blind to a raw
`USBDEVFS_RESET`: the operation the controlled tests use, the one
`usb_queue_reset_device()` performs, and the one `BT-3`'s proposed quirk would have the
kernel issue on every first timeout.

`bt-window` carried the opposite error beside it, counting `RFKILL event … op 1` — bluetoothd
*observing* the switch disappear during teardown — as an operator action. **The two
cancelled**, so a window reported CENSORED for entirely the wrong reason. Two errors that
cancel are worse than one that doesn't, because nothing prompts anyone to look.

**Two of three evidence rows were wrong.** Auditing `results.tsv` against the journal found
rows 2 and 3 recording `perturbed=none` for windows containing four kernel resets each.
Censored windows entering the record as clean observations — two thirds of the file. The
rows were left as written and the defect recorded in `BL-04`, on the same principle that
left `EX-023`'s row missing rather than reconstructed.

**`bt-trial-audit` was built so that audit is re-runnable rather than remembered**, and its
load-bearing decision is that it does *not* share `bt-trial`'s detectors. An audit built on
the same regex can only agree with itself; importing the pattern would have confirmed all
three rows as correct. Independent detectors reached the same answer, and resolved a boot
by containment where the hand count had miscounted backwards.

**Journal cost scales with the span traversed, not the lines matched.** Three instances in
one day. `bt-window` timed out at the moment a window became interesting — five scans, two
unbounded — and was fixed by counting from the fault forward. The audit then took 7 m 22 s,
and `--grep` server-side filtering barely helped, because filtering removes formatting, not
traversal. The real cost was a setup loop running `tail -1` over every retained boot:
`tail` cannot know it has the last line until the stream ends, so it read every boot end to
end before a single row was examined. Removing it: **7 m 22 s → 2.136 s**, same conclusions.

The measurement that pinned it was `sys > user` — kernel-side reading and decompression
rather than userspace matching. The reading was right and the location was wrong; the cost
was in setup, not in the window reads, which had been bounded all along. **A wrong comment
was what hid it** — the loop carried a note claiming `-n 1` made the read cheap, and `-n 1`
was never passed. A comment that answers the question which would have found the bug is
worse than no comment.

### Two system binaries destroyed, and the rule that came out of it

Fixing a test that could not achieve "tool absent" — `PATH="$STUB:/usr/bin"` where
`hciconfig` lives in `/usr/bin` — a symlink farm was built over a directory the surrounding
test code then wrote into. `>` and `cp` write **through** a symlink. Three binaries went:

| binary | became |
|---|---|
| `/usr/bin/timeout` | 37 bytes, `exec /usr/bin/timeout "$@"` — infinite recursion |
| `/usr/bin/systemctl` | 71-byte stub |
| `/usr/bin/btmgmt` | 67-byte stub |

The recursion is why the suite appeared to hang; it was wedged, not slow. All three were
restored from packages. Neither half was wrong alone: the stub write created an ordinary
file in a plain directory, and the farm linked into a directory nothing wrote to. **The
composition was fatal.** So the rule is not "don't name stubs after real binaries", which is
unenforceable, but **a directory is either linked into or written into, never both** — now
structural, with farms and stubs in separate directories.

### What the pattern has become

Every defect in this phase is the same statement in a different costume: **a control
that holds where the code is developed and not where it runs.** The staging guard lived in
the test rather than the tool, so it protected every run except a human's. The farm was
safe on a container with no bluez and fatal on a machine with real binaries. The journal
tools were correct on fixtures where span and match count are both tiny.

Six such defects surfaced in a week, and every one needed this host. That is the argument
for verifying here — and equally the argument for a throwaway VM that reproduces the
*configuration* without carrying the experiment. With one refinement earned this week: the
VM must also be **loaded**, because one of the six was a race the container always won.

---

## Phase 28 — thirteen hours of nothing, and the tool that spoiled the ending

The strongest evidence this project has produced arrived because nobody was looking at the
machine, and the same two days exposed our own instrumentation as a source of intervention
rather than a witness to it.

### The evidence

**Thirteen hours untouched.** On 2026-08-16 at 21:42:44 the controller stopped answering
HCI. It was found the next morning by a stopped spinner in the GNOME Bluetooth panel:

```
21:42:44.918919  command 0x041f tx timeout          fault
                 47338.1 s — 303 command timeouts
                 0 USB-layer lines.  0 interventions.
10:51:43         name hci0 blocked 1                shutdown begins
```

**47338.1 s — 13 h 8 m 58 s — is 3.9× the previous ceiling** (`EX-029`). Both zeroes are
counted extractions, not summaries. Every earlier long window ended in something we or the
operator did, which was the standing objection to all of them; this one ended because a
family needed the laptop. The unattended interval is the one thing the record could not
manufacture. The retired "45–66 s to USB collapse" is now wrong by three orders of
magnitude.

**A stage 2 that was not ours.** On 2026-08-16 at 15:37 a household member pressed the
Bluetooth button, then pressed it again when nothing happened. The account was half wrong
in a way only the journal could settle: the controller had stopped answering **6.092 s
before** the button was touched, in the familiar `0x0428` signature. What followed the
*unblock* was a USB reset — and the watchdog was inactive, disabled, **not installed**, with
no journal entries. `btusb_qca_reset`'s string appears zero times; no driver unbind; no
quirks entry to install `hdev->reset`. Four candidates ruled out with evidence rather than
assertion (`EX-026`). The caller remains unestablished and is recorded as such in `BL-07`.

**Where the wedge lives.** Two `reboot.target` transitions, three hours apart, opposite
outcomes: from stage 1 the controller returned in 1.107 s; from stage 2 it did not return
at all, the port detecting a device it could not address (`EX-027`). Eleven minutes later a
`poweroff.target` from that same state brought it back in 1.020 s (`EX-028`). Both
terminators are journal lines. A kernel restart discards every piece of host state there
is and changed nothing; dropping VBUS did. **The failed state is on the device's side of
the wire.**

`EX-027` was written stating plainly that it could not say whether power removal helps,
because no logged power removal existed on either side of its pair. `EX-028` closed that
eleven minutes later. The open-question paragraph was annotated rather than rewritten —
what it was honest to claim at the time is part of the record.

### The instrument, again

**Our shutdown hook is an intervention.** `bt-trial autostop` calls `hci_alive`, which runs
`timeout 6 hciconfig hci0 name` — an HCI command issued to the controller at every
shutdown while a trial is open. `EX-029`'s thirteen clean hours are followed by exactly
that probe. It also times out: 90 s of `TimeoutStopSec` consumed by CPU-bound journal
scanning, killed by SIGTERM, the row never written, the state file surviving so the next
boot silently joins the same trial, and the trial directory reused and overwritten. The
first generation of `trial-04/` exists **only because it happened to be committed** while
working on an unrelated exhibit (`BL-08`).

The workaround offered was to move the state file aside before shutdown. The operator
declined it, and the reason is the finding:

> For the cases when it is not me who shuts down.

This is a family laptop. A procedure recalled by whoever happens to be at the keyboard is
not a control, and that converts the probe from an operational cost into a design defect:
`autostop` must classify from the journal it already reads. **A shutdown-censored window on
this machine can no longer be called untouched without checking whether a trial was open**
— `EX-025` included.

**Evidence has a half-life set by our own verbosity.** Dynamic debug writes roughly a
million lines an hour into a 16 GB ring, so the instrumentation that makes a boot worth
keeping is what evicts the boots before it. Eight exhibits' source journals are already
gone. `bt-retention` makes that visible and `bt-archive` acts on it — and `bt-archive`'s
"never write inside the repository" guard turned out to be bypassable through a symlink,
because it compared logical paths. Reproduced end to end before it was fixed, and fixed on
both ends rather than the one reported (`BL-06`).

`bt-retention` still judges 13 of 29 exhibits by their **capture** timestamp rather than
their evidence's, because the extraction reads the provenance table when the body carries
no offset — the exact error its own header documents avoiding. `EX-018` therefore reports
`retained` when its journal is the one everybody agrees is gone.

### The shapes

Four defects this phase, all previously named:

* **A control that holds where it was written and not where it runs** — `journal-contract`
  read the first 5000 lines of `-b all` hunting a boot separator, on a host whose oldest
  boot carries 1,586,655 kernel lines. Its inverse is new and worth keeping: elsewhere an
  unbounded read was too slow; here a bounded one was too short, and **zero from a capped
  scan is not a result.**
* **A path check that does not resolve symlinks is not a path check** — second defect this
  week whose mechanism is a symlink; the first destroyed three system binaries.
* **A control that depends on someone remembering is not a control** — third instance, and
  the first where the someone is not part of the project.
* **A tool that reports on the world by asking the world a question changes it** — the
  shutdown probe, and the reason `bt-capture-now` (`BL-05`) must be provably read-only
  before it is written.

### What is not done

The four exhibits of this phase reached `docs/bug-report.md` only at the end of it, and
the two figures that rested on `EX-018` — 287 timeouts across 34 boots, 13 of 34 boots
hung — are withdrawn rather than restated, because the journal behind them is gone. The
watchdog is still not installed, deliberately: enabling it means `install.sh --apply`, and
its USB reset now has three demonstrations of destroying this controller. A tools-only
deployment path that enables no services does not exist yet, and until it does the fixes
in the tree cannot reach the machine that has the hardware.

---

## Phase 29 — four failure modes, a written channel, and the week the instruments caught up

Phase 28 ended with a complaint: every fix was stuck in the tree because the only way to
deploy them also armed a watchdog that destroys this controller. This phase unsticks that,
and in the process the record stops being about one fault and starts being about four.

### The evidence

**A dropout that was not the controller.** On 2026-08-17 an audible playback drop on a
third device — `Tronsmart T8`, named from the journal — turned out to be `wireplumber`
releasing the A2DP transport. The stream cycled
`STREAMING → OPEN → CLOSING → IDLE → CONFIGURED → OPEN → STREAMING` in **602 ms**, and the
ACL link never dropped: `hcon 0000000053bde63f` is the same object before, during and
after, so the disconnect happened *above* the link (`EX-030`).

Three of this investigation's ingredients were present at once — a profile transition, an
HFP cycle, and the GNOME Bluetooth panel open, the panel `EX-002` shows drives this
controller into desync — and nothing happened. **That is the negative control the record
never had**, and it produced a reusable test: a dropout is `BT-1` only if the journal shows
`0x0428`, then `Looking for Alt no`, then an unanswered command.

**The controller can do SCO.** On 2026-08-18 it **answered** an *Enhanced* Setup
Synchronous Connection (`0x043D`) in 64.7 ms, completed the alt-setting switch, and carried
the link ~17 minutes before the remote ended it (`EX-031`). Every instrumented failure until
then had used the legacy `0x0428`. `n = 1`, but if the split is real the bug report narrows
from "SCO setup wedges this controller" to a named opcode — and it lands squarely on the
wideband-speech path the source investigation was already reading.

**A third failure mode, and the first that is not the controller.** `bluetoothd` 5.72
segfaulted three times at the **same offset reading the same address** —
`bluetoothd[367e5]`, fault address `0x10`, three distinct processes across four hours and
thirteen. `systemd-coredump`, installed for exactly this, kept the core:

```
#0  bluetoothd + 0x367e5
#1  bluetoothd + 0x8304a
#2  libglib-2.0.so.0 + 0x5d45e
#4  g_main_loop_run
```

Two of the three crashes follow a discovery operation within two seconds. Afterwards the
adapter stays `Powered=true` and the daemon stays `active (running)` while discovery is
permanently dead — **every surface check reads healthy** (`EX-032`). A service restart fixes
it and lasts about twelve hours.

**The trigger claim was wrong in a specific way.** On 2026-08-22, `0x0428` was submitted and
**answered** in 72.8 ms, handle `0x0004` allocated, alt-setting switched — and 2.076 s later
a *different* command died, logged as the bare `command tx timeout` with no opcode
(`EX-033`). The kernel prints the opcode from `hdev->req_skb`; bare means that pointer was
NULL, so **the command that died was not the one `hci_cmd_sync` was tracking**. It is
anonymous by construction.

That reframes a question asked here for weeks. The trigger has been hunted as a *named
opcode*, and the hunt kept yielding a distribution rather than a constant — 4.1 s, 7.6 s,
16.2 s, 55.2 s, 155.8 s. If the dying command is often anonymous, part of that spread is the
search looking for the wrong object.

**And the intervention claim was too broad.** The standing sentence was "a USB collapse has
never begun before something touched the controller", which reads as though touching it is
what causes collapse. A deliberate recovery ladder run at the end of `EX-033`'s window —
daemon restart, `hciconfig down/up`, full `modprobe -r btusb` and reload — recovered nothing
and **destroyed nothing**: zero USB-layer lines across all three rungs, device still bound,
`hci0` recreated. What causes stage 2 is specifically a **USB-level reset**, not
intervention in general. It also stands as a counter-instance to `EX-016`, whose collapse
followed a btusb reload; that was `n = 1`.

### The instruments finally caught up

**Assessment stopped costing a fault window.** The operator named the design: one coarse cut
that throws nothing away, then every fine filter for free. `tools/bt-snapshot` does one
journal traversal — 11 s against ~108k lines — where the same assessment had been ten to
fifteen separate invocations, each re-traversing, each prompting, while a live window burned
and a family waited for the laptop.

**Evidence stopped evaporating.** The operator's objection was blunt and correct: "I don't
understand at all how we could work with evidence which just disappears right on the plain
sight." The answer was *not* a bigger quota — `SystemMaxUse=16G` was not even binding, at
2.2 G with 70 G free. `tools/bt-backup-journal` archives every retained boot, each exported
and **read back and counted** before it is filed: 15 of 15, 313 MB. On a daily timer with
`Persistent=true`, because a plain daily timer skips exactly the runs that fall while a
family laptop is off.

**`install.sh --tools-only`.** The unblocker. Deny-by-default on the same allowlist as
staging: only `install`/`rm`/`rmdir`/`mkdir` run, everything else is announced and skipped.
Verified under a staging root first — 14 system commands blocked, `enable --now
bt-hang-watchdog` among them — then live: `31 in sync, 29 drifted, 6 not installed` →
**69 artifacts in sync**, watchdog still inactive and disabled, controller still at 0
timeouts.

**`tools/bt-crash`**, after a hand-typed `tail -4` hid the one core that mattered and
produced a false "no core was kept". **`devtools/branch-status`**, after the same branch
audit was hand-assembled three times and got wrong twice — "ahead by N" is not "carries N
commits of work", and `git cherry` compares by patch-id, which is the honest counter.

### `comms/`, and a message worth the whole exchange

The Test Suite Maintainer opened a written channel so messages stop being retyped through
the operator, and its first message reported that **CI had been red for 45 hours across 27
consecutive runs** — `tools/bt-mode` refuses to run unprivileged, correctly, and the CI
runner is not root. Because `repo-validate` is step 1, all 27 runs stopped there, and these
never executed: the coverage floor, the awk floor, the comprehensiveness floor, the journal
contract, the system round trip, and `repo-scan --all` — the publish-safety gate standing
behind ~7,000 lines of session logs already pushed to a public repository.

**The finding to keep is theirs: a gate that runs first hides the state of every gate behind
it.**

They also found that `bt-snapshot` spelled the timeout pattern three ways, all requiring an
opcode, while the kernel emits the bare form when `hdev->req_skb` is NULL — and `FIRST_TMO`
is the anchor every interval in the summary is measured from. Four days later `EX-033`'s
*first* timeout was the bare form: the old pattern would have reported that window **70 s
shorter than it was**. A defect found from the tree, confirmed by the machine.

And `bt-retention` was judging **13 of 29 exhibits by their capture stamp** rather than
their evidence's, because the scan read the provenance table when the body carried no
offset — the exact error its own header documents avoiding. `EX-018` reported `retained`
while its journal is the one everybody agrees is gone. Corrected picture: **12 verifiable, 8
gone, 9 not judgeable**. The number this project had been quoting was overstated by eight.

### The shapes

* **A control that depends on someone remembering is not a control.** The operator's
  sentence, and the sharpest formulation anyone has produced here. Offered a workaround that
  required saying "I'm shutting down now", he declined it: *"For the cases when it is not me
  who shuts down."* This is a family laptop. That converted `bt-trial autostop`'s HCI probe
  from an operational cost into a design defect.
* **A gate that runs first hides the state of every gate behind it.**
* **A path check that does not resolve symlinks is not a path check** — `bt-archive`'s
  in-repo refusal was bypassable through a symlink, reproduced end to end before it was
  fixed, and fixed on both ends rather than the one reported.
* **Zero from a capped scan is not a result** — and its converse, that a zero needs a
  positive control before it is used. `bt-snapshot` now prints the control first and says in
  words that every count below is uninterpretable without it.

### What is not done

The README was rewritten this phase because it described the wrong project — it opened as
though this were a watchdog project. It is an attempt to **fix** this, in three deliberately
unmerged streams: evidence, workarounds, and the upstream patch. The fault is very likely
multi-layered, and the layers are now nameable: a wedge whose origin is unknown; an
**absence** of recovery, since `13d3:3503` matches no quirks entry so `hci_cmd_timeout()`
has no `hdev->reset` to call and Linux has no periodic USB recovery at all; a recovery path
that is **harmful** when present; and a state that survives a host reboot and clears only on
loss of power.

`docs/tooling-index.md` exists now because the same avoidable permission prompts recurred
every session, and the operator diagnosed why: after a context reset the knowledge of which
helpers exist is gone, so the pipeline gets hand-typed again — and hand-typed pipelines have
been *wrong* where the tool is not.

Still open: `bt-snapshot` and `bt-backup-journal` have no tests, which the Test Suite
Maintainer offered to write and will; the `0x0428` versus `0x043D` split is `n = 1` on the
answered side and needs both on one device in one session; the `bluetoothd` crash has a
stack but no function name, because `ddebs` ships `5.72-0ubuntu5` against an installed
`5.72-0ubuntu5.5` and mismatched symbols name the *wrong* function rather than failing,
while `debuginfod.ubuntu.com` is unreachable from this machine; and `devtools/repo-save`
cannot run here at all, because it refuses while a trial is open and `bt-trial-auto` opens
one on every boot by design — the same shape as the 45 hours, one layer down.

### Phase 29 addendum — the reboot that failed, twenty minutes after this was written

The phase above was written at 11:32 and the recovery ladder it describes was reported as
"three rungs, none recovered it, **none destroyed it**". By 11:41 that second half was
false, and the correction is worth more than the original claim.

The ladder ended `EX-033`'s window and left the controller in stage 1 by every definition
this record uses — on the bus, `btusb` bound to `3-3:1.0` and `3-3:1.1`, `hci0` present,
**zero USB-layer lines** across the 35113 s window and across the ladder itself. The
operator then took a hot reboot, which `EX-027` predicts recovers a stage-1 controller at
`+1.107 s`.

It did not come back:

```
+0.813 s   usb 3-3: new full-speed USB device number 2
+16.6 s    device descriptor read/64, error -110      (×4, to +64 s)
+64.3 s    usb usb3-port3: attempt power cycle
+86.9 s    usb usb3-port3: unable to enumerate USB device
```

**`EX-034`.** Two corrections fall out of it.

`EX-027` had paired two `reboot.target` transitions and concluded the controller's *stage*
going in was the variable — stage 1 recovered, stage 2 did not. This is a reboot from stage
1 that failed at `+86.9 s`, the same figure to a tenth of a second as the stage-2 case,
which is usbcore's fixed retry schedule and says nothing about the device. That
generalisation is withdrawn. `EX-028` is untouched: it compared reboot against power-off
from the *same* stage-2 state.

And the ladder's own report was wrong in the direction that matters. Twenty minutes passed
between the last rung and the first sign of harm, and the sign appeared only when the host
tried to enumerate from scratch.

**The shape is new and it indicts the method, not one tool.** Every safety check this
project runs during an intervention is a *contemporaneous* one: bus presence, driver
binding, `hci0` existence, absence of USB-layer lines. All four passed. The damage surfaced
at a boundary none of them watch. **"No USB-layer line followed" is evidence about the
moment, not about the device** — and that sentence should be read back over every
intervention this record has called harmless.

What it does not establish is which rung did it, or whether the reboot was needed to expose
it. Three interventions ran in sequence and only the aggregate was tested. The failed
`hciconfig hci0 up` (`-110`) is the most suspicious, since `HCI_Reset` is the one rung that
asks the controller to reinitialise — recorded as a hypothesis, not a claim.

---

## Phase 30 — the phase that audited itself, and produced the first patches

Two things happened at once. The project produced its **first upstream-ready patches** — and
an audit of its own claims found that a striking number of them were wrong. Both belong to
the same story: the patches exist *because* the audit happened.

Almost every correction below is against something the main-branch maintainer wrote. That is
recorded plainly rather than softened, because the record's value is that it can be checked,
and a phase in which six claims were withdrawn is evidence the checking works.

### Six claims withdrawn, all of them ours

**1. The alt-1 objection was backwards.** `EX-033`'s captures show `Looking for Alt no :6`
then `:3`, and never `:1`. That was raised as possibly sinking the source investigation's
central finding. The source says the opposite: the line is a `BT_DBG` at the *entry* of
`btusb_find_altsetting()`, so it logs the candidate **probed**; alt 1 is the bare `else`,
which calls nothing and therefore **logs nothing**. And the CVSD branch computes its alt
arithmetically without ever calling that function — so a `Looking for Alt no` line can only
come from the transparent branch. The absence of `:1` is what the finding predicts, and the
captures are its strongest confirmation.

**2. `0x0428` does not mean CVSD.** Stated in the plan and in `comms`. `btusb_notify()` takes
`air_mode` from the HCI core's notify value, derived from the *air mode of the connection*,
not from the opcode; `0x0428` carries a voice-setting parameter and can request transparent
data exactly as `0x043D` can.

**3. `hci0 evt 5` is not "Synchronous Connection Complete".** It is
`HCI_NOTIFY_ENABLE_SCO_TRANSP`, from `BT_DBG("%s evt %d", …)` in `btusb_notify()`. This one
*strengthened* the record: `EX-033`'s three captured lines are now the **complete alt-1
chain observed on the machine** — `evt 5` selects the transparent branch, `:6` and `:3` are
the probes, the silence is `new_alts = 1`. The alt-1 finding no longer rests on source
reading alone.

It also killed the `0x0428`-versus-`0x043D` comparison proposed as `A3`'s replacement:
`EX-031`'s *surviving* link was transparent too, so that pair cannot be a
CVSD-versus-wideband comparison. What differs is the setup command, not the air mode.

**4. The denominator was over-withdrawn, and that cost the project a gate.** The report said
"287 command timeouts across 34 boots" and "13 of 34" *"cannot be re-derived by a reviewer or
by us"*. False. The **journal** rotated; the per-boot table derived from it has been
committed since 2026-08-10 and reproduces both figures exactly. The correct status is the one
this project already gives captured output — **re-derivable from the repository, not
re-verifiable against the machine**. A4 had been described as the bottleneck for a week;
part of that bottleneck was self-inflicted.

**5. Five exhibits recorded the wrong kernel.** `EX-030`–`EX-034` all said
`7.0.0-28-generic`. The machine ran `-28` to 2026-08-17, `-29` on 08-19 and 08-21, and `-30`
from 08-22. `tools/bt-exhibit` reads `uname -r` correctly; those five were hand-written and
the value was copied forward from `EX-029`.

**6. And that cost `EX-034` its central attribution.** Its reboot crossed `-29` → `-30`,
while `EX-027`, the exhibit it contradicts, ran entirely under `-28`. The stage-1 comparison
therefore spans **three kernel versions**, and the recovery ladder is no longer the only
recorded difference between the two stage-1 reboots. `EX-027`'s stage rule stays withdrawn —
a stage-1 reboot did fail — but the *cause* is open.

### The first patches, and a method worth keeping

`EX-032`'s two crash sites were resolved **without debug symbols**, which had looked
impossible: Ubuntu never published an amd64 `bluez-dbgsym` for `5.72-0ubuntu5.5` — it exists
for arm64, armhf, ppc64el, riscv64 and s390x, every architecture except the one almost
everybody runs. Substituting the `-0ubuntu5` symbols was **measured rather than assumed**:
93.585% of the executable segment differs between the two builds.

What worked instead was `.eh_frame` for exact function boundaries and PLT call fingerprints
matched against the other build:

```
#0  avdtp_stream_set_transport()  profiles/audio/avdtp.c:3225  stream == NULL
#1  transport_cb()                profiles/audio/a2dp.c:2448   +0x367e5
#2  accept_cb()                   btio/btio.c:202              +0x8304a
    start_discovery_complete()    src/adapter.c:1845           param == NULL
```

**The identification was then falsified against the coredump**, on a prediction it could
have failed: that `%r13` held NULL and the faulting instruction was `mov 0x10(%r13),%rdi`.

```
r13   0x0
=> 0x635d944b47e5:	mov    0x10(%r13),%rdi
```

Byte for byte. The kernel's `segfault at 10` is the `0x10` displacement off a NULL base — a
consequence rather than a coincidence. A method that predicts a register value and an
instruction encoding it never saw, and is right, is worth citing in the submission.

**Both defects are still live in master** (`5.87-78-gc73fa2f`), checked against a fresh
clone: `start_discovery_complete()` still dereferences `rp` above its own length check, and
`transport_cb()` still passes `setup->stream` unchecked into a callee that does not guard it
either. Two patches, apply-clean and compile-clean, verified to apply against master
independently.

⚠️ **`lore.kernel.org` is 403 from both environments**, so "not fixed in master" is
established and "never reported" is **not**. The submission says so rather than claiming
novelty.

### The infrastructure that made the audit possible

**`comms/`** matured from a convention into the project's working surface — twenty messages,
both directions, and most of the corrections above came through it.

**The external cache** (`docs/external-cache.md`) exists because availability is a property
of *who is asking*, not of a file. `launchpad.net` answers from the investigation machine in
0.24 s and is blocked from the test-suite maintainer's; `github.com` and `lore.kernel.org`
are blocked from theirs and reachable here; `debuginfod` is blocked from both. The `-28`
Ubuntu kernel delta — superseded and gone from `archive.ubuntu.com` — and the BlueZ tree are
now cached and verified against publisher checksums.

**`BL-09`** took unjudgeable exhibits from nine to five by annotating them from their own
content: 137 insertions, **zero deletions**, no claim and no captured output touched.
`EX-018` had been expected to stay unjudgeable; its stage-1 table's first column places it,
and the answer is **GONE** — a stronger statement of the same fact, derived rather than
assumed.

**`bt-snapshot` gained the BlueZ health block** it needed on 2026-08-19, when it reported
"controller on bus, 0 timeouts" while Bluetooth had been dead for two and a half hours.
Taken from the journal and labelled as last-logged state, so it stays safe to run inside an
untreated window.

### The shape

Every correction in this phase has one form: **an observation that was true, read as meaning
something it did not mean.** `:6` then `:3` was true. `evt 5` was true. The journal had
rotated. Five exhibits did say `-28`.

The lesson the phase adds to the register is about *reading*, not about measurement:

> A true observation constrains the world less than it appears to. What it rules out is
> whatever it is inconsistent with — and that is usually a smaller set than the one reading
> that first comes to mind.

Which is the same reason the alt-1 objection inverted so cleanly: the absence of a log line
was read as absence of the behaviour, when it was the behaviour's signature.

---

## Phase 31 — "blocked" is not one thing, and the operator opened a browser

A short phase with one lesson, learned twice simultaneously by two people who could not see
each other doing it, and closed by the one person who had the tool neither of them did.

### The patches were finished except for one sentence

`EX-032`'s two defects were confirmed live in master, both patches applied clean, both crash
sites were resolved without symbols and falsified against the coredump. The only thing
outstanding was a clause both patches carried:

> I have not been able to search the list archives, so this is "not fixed in master" rather
> than a claim that it has never been reported.

The operator read it and objected on a ground neither maintainer had considered:

> How can I claim that I can access it? That I am submitting the patch from a prison or
> whatever?

**He signs those patches.** A sentence saying the archives could not be searched reads, to
a BlueZ maintainer, as the *submitter* admitting he did not do basic homework. The
limitation belonged to two sandboxes, not to him, and had no business in his commit message.
That is a category of defect this record had not named: **a limitation of the tooling
exported into a third party's view of the operator's work.**

### The same mistake, twice, from opposite sides

Both maintainers had written "blocked" into a document after reading a status code and
stopping there.

**The test-suite maintainer** recorded `github.com` as "403 at the proxy". The response
*body* said otherwise — it was that session's per-repository authorisation gate — and `git`
over the same host had worked the entire time. **BlueZ master had been reachable
throughout.**

**The main-branch maintainer** recorded `lore.kernel.org` as unreachable from a `curl` 403.
It was a **user-agent block**:

```
default-UA  http=403
browser-UA  http=200
```

and behind that a proof-of-work interstitial titled *"Making sure you're not a bot!"*, which
needs JavaScript — so installing a text browser would not have helped either, and the
instinct to try one was right about the question and wrong about the answer.

Two different failures — an authorisation gate and a bot filter — with one shape: **neither
of us read the response body before writing the conclusion down.**

The resulting table in `docs/source-access.md` now distinguishes four cases that look
identical from a status code and have completely different answers: a CONNECT tunnel refused
(no request is ever sent, so user-agent is irrelevant), an HTTP status from a server that
did answer (read the body), a different protocol to the same host being open, and a UA block
in front of a JS challenge.

### What a browser settled in under a minute

The operator opened both searches himself and sent the saved pages.

* **`start_discovery_complete`** — ~300 hits, 207 distinct subjects, **none** reporting this
  crash. The only NULL-dereference threads returned are kernel-side
  `Bluetooth: mgmt: fix hdev->discovery.uuids` patches: different layer, different pointer.
* **`avdtp_stream_set_transport`** — 32 hits, none reporting this call path.

**And one hit made patch 2 materially stronger.** The closest prior work is `90a600895`,
*"avdtp: Handle case where remote send L2CAP connect ahead of Open"* (Luiz Augusto von
Dentz, 2020-09-22) — precisely the scenario in which a transport channel arrives at an
unexpected point in the sequence. Checked against the tree, it changed **only**
`profiles/audio/avdtp.c`, and left `transport_cb()` in `a2dp.c` handing `setup->stream` over
unchecked.

So the maintainer has already accepted a fix for this *scenario* in the neighbouring file.
That argument is better than anything either maintainer produced unaided, and it came from a
search both had declared impossible.

### The shape

Phase 30's lesson was about reading observations. This one is about reading *failures*, and
it is the same error one level down:

> **"It failed" is not a diagnosis.** A status code is an observation; the cause is a
> separate question, and there are at least four causes that produce the same code and
> demand different responses.

And the operator's half, which is the part that actually recovers the situation:

> **When something is blocked for the assistant and trivial for the operator, ask him.** Two
> links and thirty seconds of his time beat any amount of working around it — and a caveat
> in a deliverable is not a workaround, it is a defect exported to a third party.

Both patches now state what was searched and what was found, with the near misses named, and
carry no caveat about access at all. They are finished and wait only on the operator's word.

---

## Phase 32 — the patches ran, and the fault reproduced under them

The phase where the project stopped arguing about the patches and put them on the machine —
and then, hours later, got the fault it had been unable to provoke for a week.

### The patches went from static argument to a running daemon

They had applied, compiled and matched a coredump. **No patched binary had ever executed
anywhere.** The operator asked for that gap to be closed and it was, deliberately against
the machine's *own* version rather than upstream master: `bluez 5.72-0ubuntu5.5` source from
the archive pool, both tarballs verified against the `.dsc`, all **31 Ubuntu patches**
applied, then ours on top — so anything observed is attributable to the two fixes and not to
a version change.

Installed to `/usr/local` with a systemd drop-in, the distro binary untouched and `dpkg -V`
clean, so reverting is deleting one file. That command is written inside the drop-in itself,
not only in a conversation.

### The filter change is the part that was easy to miss

**A patch that prevents a crash leaves no trace by default.** The daemon simply does not die,
which is indistinguishable from the bug never having occurred. Both patches log before they
bail, so the message *is* the observation — the only positive evidence a fix worked rather
than the conditions not recurring. `bt-snapshot` gained an `f-guard.log` cut, and prints the
zero case labelled `0 = no crash prevented AND none occurred`, so the ambiguity cannot be
silently read as success.

### `EX-035` — eight hours, and the trigger was never pulled

The patched daemon ran 7 h 56 m across the operator's deliberate reproduction attempts with
zero crashes, against three crashes in ~20 h unpatched. **That comparison is not evidence**
and the exhibit says so at length: no reproducer means no denominator.

Two things had to be corrected inside a single hour, both by checking rather than assuming.

A `Device or resource busy` error looked like a regression the patch had introduced — seven
occurrences since it started, zero earlier that boot or the previous one. **Widening the
search found it on the unpatched daemon** in an older boot and in six archived snapshots.
Not new.

And the operator's account reframed the run, then the logs corrected the reframing. He said
the testing pattern changed *because* the usual failure had not happened — which would make
the aggressive testing a consequence rather than a confound, and the strongest signal in the
exhibit. The logs only partly agreed: HFP connected nine times, but there were **zero**
synchronous-link setups and **zero** alternate-setting switches in the entire run. `BT-1`
needs the SCO path; the SCO path was never taken. *"Bluetooth did not die"* had a simpler
explanation than the patches — it was never asked to do the thing that kills it.

The missing SCO setup was briefly called "the most interesting thing here". It was a
**pairing problem**: the operator re-paired the device, the full profile stack reconnected,
and what reconnected was **A2DP — music**. The trigger needs hands-free audio actually in
use. Recorded as a deflation rather than quietly dropped, because what the record thought
was interesting for an hour is part of how it was got right.

### `EX-036` — and then it fired

At 17:08 the operator put the headset into hands-free mode, and the fault arrived:

```
17:08:08.550995  hci0 opcode 0x0428 plen 17        SCO setup
17:08:08.625863  hcon … handle 0x0005              ANSWERED, +74.9 ms
17:08:08.625984  hci0 evt 5                        transparent air mode
17:08:08.626011  Looking for Alt no :6  then  :3   → silence → alt 1
17:08:10.702854  command tx timeout                BARE, +2.152 s
```

**That is `EX-033` reproduced** — different peripheral (Sennheiser, not Lenovo), different
kernel (`-30`, not `-29`), three days apart. `EX-033` measured **2.076 s**; this one
**2.152 s**. Seventy-six milliseconds apart.

Two claims that rested on a single observation are now `n = 2`: **the controller answers
`0x0428`**, and **the command that dies is anonymous** — the bare spelling meaning
`hdev->req_skb` was NULL, so it was not the command `hci_cmd_sync` was tracking.

⚠️ **And that reframes the trigger interval.** The spread this project kept measuring — 4.1,
7.6, 16.2, 55.2, 155.8 s — was gathered by anchoring on whichever *named* command happened
to time out. Anchored instead on the **answered setup**, two instances agree within 76 ms.
The distribution may have been an artefact of measuring from the wrong event. `n = 2` cannot
establish that; it is enough to stop assuming the opposite.

Two later setups in the same window were **not** answered and timed out in the ordinary
named way — so the answered-then-anonymous shape belongs to the *first* setup against a
healthy controller. Future captures should anchor on the first `0x0428` of a window, not the
last.

### What the phase says about the patches: nothing, and that was predictable

Across the wedge: **0 patch guards fired, 0 daemon crashes.** `BT-1` is the controller fault
and neither BlueZ patch touches it. The patched daemon has now survived a controller wedge
without incident — worth recording, and not evidence for the patches.

They remain what they were: a static defect with crash forensics, now built and run without
regression. Still unsent, still waiting on the operator, who has said he is reviewing them
himself.

### The shape

Phase 30 was about reading observations; Phase 31 about reading failures. This one is about
**reading absences**, and it is the same error a third time:

> A quiet run is not a result. Before "it did not fail" means anything, something must show
> that it was **asked** to — and the counter that shows it has to be in the summary, or the
> question never gets asked at all.

Zero crashes meant nothing until `0x0428 legacy SCO: 0` explained why. Zero guard firings
meant nothing until the same counter explained that too.

---

## Phase 33 — the instruments were lying, and one of them was losing the evidence

A routine status check on a healthy machine. Bluetooth was fine; five of this project's
own tools were not. None of it is `BT-1`. All of it is the record about the record.

### The one that mattered

`bt-backup-journal` exists because of a sentence the operator wrote on 08-19 —
*"I don't understand at all how we could work with evidence which just disappears right on
the plain sight"* — and it had been quietly keeping **prefixes and calling them backups**.

It archived every retained boot **including the live one**. A live boot yields a prefix; the
file is named by boot id; `bt-archive` refuses to overwrite. So the prefix reads as *already
archived* for ever after. The daily timer had been reporting `21 already archived, 0
missing` over exactly that.

```
boot c8342e9b:  6199 of 40437 records     zero `opcode 0x0428` lines
```

**That is the boot `EX-035` and `EX-036` rest on.** Archived 08-24 while live, it stops
2.5 hours before the 08-25 17:08 fault it exists to preserve.

A completeness check found **nine of twenty-one** archives in the same state — one holding
**1.5%** of its boot. Every one was still on the ring. All nine were re-archived and
confirmed by a second, independent check.

⚠️ **Nothing was lost, and that was luck rather than design.** Within the same session boot
`-20` rotated off the ring. Its archive was complete, so it survived; had it been one of the
nine, those records would simply be gone and only the exhibits' greps would remain.

### Four more, all the same shape

**The read-back guard was a race against the machine.** `bt-archive` exported once to
compress and *again* to count, then compared. On a boot still being written, entries arrive
between the two exports, the counts differ, and a good archive is discarded as a *read-back
mismatch*. The timer failed exactly so at 00:20:42. The count now comes from the same bytes
the compressor received.

**And the driver threw away the reason.** `>/dev/null 2>&1` on the tool it drives, so the
failure reached the journal as the bare word `FAILED`. The cause had to be reproduced by
hand from a service log that had recorded everything except the error.

**`bt-snapshot` counted the whole machine as Bluetooth crashes** — `daemon crashes 8` on a
healthy laptop: gnome-keyring scopes, snapd, two xdg portals, and **our own
`bt-journal-backup.service`**. Zero were `bluetoothd`. The same filter also stole another
unit's restart counter, because `restart counter is at` is a phrase systemd prints for every
unit on the machine, and the reader took the last match.

**`bt-status` printed a shell error and an empty counter.** `KE: unbound variable` — the
variable was deleted when the tool stopped holding the whole kernel journal in a shell
string, and one consumer was missed. Under `set -u` the column printed *nothing*, which
reads exactly like a measured zero.

### The test that had stopped testing

The suite exercised the read-back guard by **sed-patching `bt-archive`'s pipeline from
outside**. Adding a `tee` to that pipeline made the pattern stop matching — producing a copy
identical to the real tool, still named after the guard, testing nothing. It is the same
defect as the tools it checks, one level up: a check coupled to text nobody thinks of as an
interface. Replaced with a real seam, plus an assertion that the seam is actually reached.

### The shape

Phase 32 was about reading absences. This one is about **who is doing the reading**:

> A number in a summary is a claim, and it inherits every assumption of the filter that
> produced it. `8 daemon crashes` was true of the machine and false of Bluetooth. `21 already
> archived` was true of the filesystem and false of the archive. Both passed for weeks
> because a plausible number does not look like a question.

The counters this project trusts most are the ones nobody re-derives. `bt-archive --check`
exists because *present* and *complete* had never been distinguished, and everything
downstream had been reading the first as the second.
