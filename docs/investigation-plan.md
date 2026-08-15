# Investigation plan — data before code

Agreed with the operator 2026-08-11: **collect and understand before changing anything.**
Patching the driver first would change a variable before the baseline exists, and after
fifteen phases in which "it worked for a while" meant nothing, we would not be able to
tell a fix from luck.

Ordered by risk. Everything in phases A and B is reversible and touches no code.

---

## Phase A — zero risk, no code, no rebuild

### A0. Confirm Ubuntu's own `hci_cmd_timeout()` ⭐ do this first

The whole interpretation of the recovery experiments now rests on one source fact, so do
not infer it. Upstream v7.0 `net/bluetooth/hci_core.c` reads:

```c
	if (hdev->reset)
		hdev->reset(hdev);
```

with no threshold — verified. And `tools/bt-verify-kernel-mechanism` confirms the shipped
`btusb.ko` exports `btusb_qca_reset`, not `btusb_qca_cmd_timeout`. What remains is to read
**Ubuntu's `7.0.0-28` source** and confirm it is not patched here. Requires enabling
`deb-src` and `apt-get source`; changes nothing on the running system.

### A1. Firmware identity under both operating systems — strong, not decisive

The controller reports HCI revision and LMP subversion. Read them under Linux, then under
Windows 11 on the same machine.

- **If they differ**, that is strong evidence the controller reports a different
  firmware/version state under the two systems.
- ⚠️ It does **not** establish that the difference *causes* the hang, and equal version
  fields would not prove identical binary firmware either. An earlier revision called
  this "decisive"; that was too strong.
- Costs one reboot. Changes nothing.

Linux: `hciconfig -a` / `HCI_Read_Local_Version`.
Windows: Device Manager → Bluetooth adapter → Details → *Firmware/LMP version*, or the
vendor tool.

**More direct, and QCA-specific:** `btusb_setup_qca()` asks the controller for its
Qualcomm target version and patch status before deciding whether to load the rampatch.
Getting that answer out of the device tells us far more than a version-field comparison —
and Build B in [`fix-proposal.md`](fix-proposal.md) §5a produces it as a side effect,
including if it refuses to proceed.

### A2. Driver dynamic debug

`btusb` and the Bluetooth core support runtime debug via `dyndbg` — verbose logging of
probe decisions and the stall itself, with **no rebuild and no code change**, reversible
by writing to the same file.

This is the "better logging before touching code" step. It should show exactly what
`btusb_probe()` decides for this device, and what the driver is doing when the controller
stops answering.

### A3. The two-headset comparison ⭐ best reproducer available

The operator's most useful observation: a **Sennheiser Momentum 4 provokes the hang
almost immediately**, while **Lenovo thinkplus GM2 pro buds run for hours or days** —
same host, same stack, same controller.

That is the first controlled variable this investigation has had. Capture a full HCI
trace of connecting each, and diff them. Whatever the Sennheiser does differently is
already visible in traces we are recording.

### A4. Codec / transmission-mode switching ⭐ the gate

The operator reports that changing transmission mode (HQ ↔ XQ) kills the controller
**immediately**. Independent reporters point at the same class of event — kernel bug
203535 is triggered by *pausing and playing* A2DP.

This must become a **quantified protocol**, not an anecdote:

```
cold boot
start btmon + kernel log capture      (bt-trace is already running)
bt-mark "trial N start"
connect Momentum 4
perform operation X
perform operation Y
perform operation Z
record: hang / no hang
```

Run it on **stock** first and establish a failure rate — target something like **5/5**.
Without a denominator, "the patched build ran for an hour" means nothing, and this
project has already mistaken absence of observed failure for a fix more than once.

Nothing in Phase C should be built until this exists.

---

## Phase B — still no code change

### B1. Windows-side HCI capture

Windows can log Bluetooth HCI traffic. A Momentum 4 connect + mode switch captured on
both operating systems, diffed, would show exactly where the two stacks diverge — and
whether Windows sends something Linux does not, or vice versa.

### B2. Frequency measurement of the existing mitigation

Whether `enable_autosuspend=0` reduces hang *frequency*, even though recovery never
works. Requires running with it off for a period and comparing. Lower value than A1–A4.

---

## Phase C — after A0 and A4, not necessarily after all of B

**Revised 2026-08-11.** An external review argued for bringing the builds forward, and
that is right: with the mechanism correction in hand, the A/B experiment is the sharpest
instrument available, and waiting on the remaining Phase-B items would not sharpen it.

The gating prerequisites are **A0** (confirm Ubuntu's timeout path) and **A4** (a
deterministic reproducer — without one, neither build can be evaluated).

### C1. The four-step ladder — see [`fix-proposal.md`](fix-proposal.md) §5a

**Not** a two-build A/B. `BTUSB_QCA_ROME` installs six distinct behaviours, so toggling it
wholesale would show a cure without isolating a cause:

- **A** — `hdev->reset = btusb_qca_reset` only
- **B** — A + `data->setup_on_usb = btusb_setup_qca`
- **C** — full `BTUSB_QCA_ROME`
- **D** — C + `BTUSB_WIDEBAND_SPEECH` (production candidate; held back so it cannot
  confound an audio-transition reproducer)

Each step attributes the effect to one added behaviour. Confirm
`using rampatch file: qca/rampatch_usb_00000302.bin` appears at B, and record which reset
path fires at A (`bt_en gpio` vs `Resetting usb device.`).

Note that B may bind successfully and then fail at **HCI open**, not at probe —
`setup_on_usb` runs from `btusb_open()`. An `-ENODEV` there, with the reported ROM
version, is a result worth capturing rather than a failed experiment.

⚠️ Risk, unchanged from [`fix-proposal.md`](fix-proposal.md) §4: if this module is not a
true ROME variant, `btusb_setup_qca()` may fail — at **HCI open**, not at probe (the
device stays enumerated and bound; bring-up is what fails) — and leave the machine with
**no Bluetooth**. Recoverable with `modprobe -r btusb; modprobe btusb` — no reboot — and
the test module is loaded with `insmod`, never installed.

By this point we would know what we expect it to change, which is the difference between
an experiment and a guess.

---

## Why this order

The operator's reasoning, which is correct:

> First data collection. First we should understand the situation at all, understand what
> is going on. Even before patching the driver — actually changing the logic inside — we
> may need to rebuild it with a better logging level, so we could see what is actually
> going on before we do code changes, which is high price and dangerous.

A1 and A4 are the two that could each independently transform the submission: one proves
the firmware divergence, the other supplies a deterministic reproducer. Neither requires
building anything.

---

## Backlog — instrumentation gaps, not investigation steps

Recorded so they are not rediscovered. None of these is urgent; none should be done while
a trial is open.

### BL-01 — boot provenance is recorded per trial, but not in the evidence a reader sees

`bt-trial` writes `prev_shutdown` (reboot | poweroff | halt | unknown) and `enum_at_boot`
into `results.tsv` (columns 21–22), added after `EX-017`. Two consumers do not carry it:

| where | state |
|---|---|
| `evidence/trials/results.tsv` | ✅ recorded per trial |
| `tools/bt-incident` session collections | ❌ not captured |
| `tools/lib/stage2.awk` | ❌ `shutdown` is one bucket; poweroff and reboot are not distinguished |

**Why it is worth closing.** It is the only data that can settle a claim this project
asserts in three places and has never tested: *"a warm reboot does not drop the M.2 power
rail and will not recover it"* — protocol step 0, `docs/bug-report.md`, and
`docs/fix-proposal.md`. The last two are text intended to go upstream, so the claim is
load-bearing for the submission, not internal.

It is already producing signal against that claim. Of the three boots to 2026-08-14
18:21, two ended at `reboot.target` and **the controller recovered across both** —
`bt-boot-provenance` flags these as `<- recovered across a reboot target`. The claim says
that should not happen.

Sessions are what exhibits cite. A session collected months from now records the kernel
log, the timeline and the state, and says nothing about how its boot began — so the
boundary that matters for the rail question is invisible exactly where a reader looks.

**The limitation must travel with the field, or it becomes another unearned fact.**
`prev_shutdown` records the OPERATING SYSTEM'S shutdown trajectory, not the electrical
state of the rail. A power-off performed after the OS reached `reboot.target` leaves an
identical trace — the 2026-08-13 case (`EX-017`) is exactly that ambiguity, and `EX-019`
established that firmware initialisation time cannot discriminate either. The field is
suggestive; it is never proof. Settling the rail claim needs a deliberate trial: hang the
controller, warm-reboot without touching the power, and look.

**Shape of the work.** Add the two fields to `bt-incident`'s manifest, and let
`bt-stage2` report the shutdown subtype alongside its `shutdown` bucket. Neither changes
a classification — a window ended by shutdown is right-censored whichever kind it was.
What changes is that the *next* boot's recovery becomes readable from the evidence
instead of from someone's memory.

### BL-02 — the operator action that triggers the fault is not in the exhibit that describes it

`bt-actions` reconstructs the operator trail from the journal and classifies it into four
streams — `USER` (settings panel, quick-settings toggle), `PROF` (BlueZ profile
transitions), `PLAY` (PipeWire), `CTRL`/`WDOG`. On 2026-08-14 it recovered the whole
sequence: panel opened, `Hands-Free Voice gateway` transition, `HCI cmd 0x0428`, timeout.

That trail reaches `evidence/sessions/*/timeline.txt` through `bt-incident`. It does **not**
reach the exhibits, which are built from the kernel stream alone — so the exhibit that
describes a fault triggered by a profile switch does not contain the profile switch.

**Why it is worth closing.** For an upstream report, *"switch A2DP→HFP and it dies, here
is the trace"* is a different class of claim from a timing correlation, and the operator
action is what makes it reproducible by someone else. `EX-021` states the trigger in prose
and cites the kernel line; the `USER`/`PROF` lines that corroborate the operator's account
live only in the session directory beside it.

**Shape of the work.** Let `bt-exhibit` accept a second extraction command, or let an
exhibit cite a session's `timeline.txt` range, so a single exhibit can carry both streams —
what the operator did, and what the controller did about it.

**Not urgent.** The evidence exists and is collected; this is about where a reader finds
it. Do it before the upstream submission, not before the next trial.
### BL-03 — `bt-trial abort` deletes tracked evidence without saying so

`bt-trial abort` does `rm -rf "$dir"` on the trial directory unconditionally. That is
right for its designed use — discarding a trial opened moments ago — and wrong once the
directory has been committed.

On 2026-08-15 aborting a perturbed trial deleted `evidence/trials/stock/trial-03/`, whose
`sco-params.txt`, `state-after.txt` and `state-before.txt` were tracked in `ed82166` and
were the **only surviving artifacts of the trial whose results row was lost** (see
`EX-023`). Recovered with `git checkout`, so nothing was lost — but the tool printed
`trial discarded` and said nothing about having removed files under version control.

**Why it matters beyond the one incident.** The recovery depended on the directory being
committed *and* on someone noticing. `git status` showed three ` D ` lines that would have
been swept up by the next `git add -A`, which this project runs routinely before
committing. The window between "abort" and "commit" is where the loss becomes permanent.

**Shape of the work.** Before removing, ask git whether the path is tracked
(`git ls-files --error-unmatch`), and if it is, refuse — or move aside and report — rather
than delete. The same reasoning as `bt-mode`, which moves configuration to `.disabled`
instead of editing it.

**Adjacent, same class:** `bt-trial abort` is also the only way to clear a trial the
suite refuses to run alongside, so the pressure to use it is highest exactly when a trial
has accumulated something worth keeping.

### BL-04 — the perturbation scans match our own log strings, not the kernel's

`tools/bt-trial` and `tools/bt-window` both decide whether a window was disturbed by
grepping for:

```
usb_queue_reset_device | Resetting usb device
```

`Resetting usb device` is **`bt-hang-watchdog`'s own message**. The kernel writes
something else entirely:

```
usb 3-3: reset full-speed USB device number 2 using xhci_hcd
```

So both tools detect an intervention by our watchdog and are **blind to a raw
`USBDEVFS_RESET`** — which is the operation the controlled tests use, and the one
`usb_queue_reset_device()` performs, and therefore the one `BT-3`'s proposed quirk would
make the kernel issue on every first timeout.

**Demonstrated, not inferred.** On 2026-08-15 a deliberate `USBDEVFS_RESET` was issued at
21:12:44 into an open trial. The trial row records `perturbed=none`. `bt-window` reports
`iv_tool=0`.

**And there is a second error, in the opposite direction.** `bt-window` reported
`1 operator (rfkill / Settings toggle)` for that same window. Nobody touched rfkill. The
matched line is:

```
21:12:38  bluetoothd: rfkill_event() RFKILL event idx 0 type 2 op 1 soft 0 hard 0
```

`op 1` is `RFKILL_OP_DEL` — bluetoothd *observing* the switch disappear as the device was
torn down, six seconds before the reset. A consequence, counted as a cause. `soft 0 hard 0`
says nothing was blocked.

The two errors cancelled here: the window is correctly marked CENSORED for entirely the
wrong reason. They will not cancel elsewhere — a window ended by a raw reset with no rfkill
traffic reads `✓ no intervention`, which is precisely the failure `bt-window` was rewritten
to prevent three days ago.

**Shape of the work.**

- Add `reset (full|high|low)-speed USB device` to the tooling pattern in both tools. That
  is the kernel's wording, and `tools/lib/stage2.awk` already matches it — so the same
  event is recognised by one analysis tool and missed by two others.
- Narrow the operator pattern to rfkill lines indicating a **block** (`soft 1`,
  `blocked 1`), not bare `RFKILL event`, which fires on teardown.
- The fixture is free: this boot carries a real reset at 21:12:44 and a real `op 1`
  observation at 21:12:38, six seconds apart, pinning both directions at once.

**Fourth instance of one family.** The timeout grep that matched 8 of 173 events, the
`bt-window` rfkill blind spot, the `bt-state` PATH tests, and now this — every one a
pattern derived from what *our* tools log rather than what the *kernel* logs.
