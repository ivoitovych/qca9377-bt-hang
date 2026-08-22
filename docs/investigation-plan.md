# Investigation plan — data before code

<!-- REVIEWED-KEEP 2026-08-15T1752Z §1.8: reviewed clean in full. Worth
     preserving as-is: A1's explicit downgrade from "decisive" to
     "strong, not decisive", the A4 gate (no build before a denominator), and
     the BL-01/BL-02 backlog form — each states why it matters, what
     limitation travels with the data, and when it must be done by. -->

Agreed with the operator 2026-08-11: **collect and understand before changing anything.**
Patching the driver first would change a variable before the baseline exists, and after
fifteen phases in which "it worked for a while" meant nothing, we would not be able to
tell a fix from luck.

Ordered by risk. Everything in phases A and B is reversible and touches no code.

---

## Revision 2026-08-22 — read this before the phases below

**The phases were written on 2026-08-11 and are now eleven days and thirty-four exhibits
old.** They are left as written, because what was believed then is part of the record and
this project has been burned by silently editing claims. This section says what has changed.
Where the two disagree, this section wins.

### Items that are DONE and are not marked done

| item | status | evidence |
|---|---|---|
| **A0** ⭐ "do this first" | **done** | `hci_cmd_timeout()` calls `hdev->reset()` on the first timeout, no threshold — confirmed in Ubuntu 7.0 source at `hci_core.c:1462-1483` by `investigate-bluetooth-controller-hang-2026-08-16-2353` §4.1, and `btusb.ko` verified to export `btusb_qca_reset` by `tools/bt-verify-kernel-mechanism` |
| **A2** driver dynamic debug | **done and running** | `bt-dyndbg` is a service; 20 `btusb` and 166 `bluetooth` debug sites enabled. Every exhibit since `EX-006` depends on it |

### A3 is REFUTED — its premise was wrong

A3 rests on "the Sennheiser provokes the hang almost immediately, while the Lenovo buds run
for hours or days", called "the first controlled variable this investigation has had".

**`EX-024` shows the Lenovo failing with an identical kernel-side signature.** There is no
controlled variable. The two-headset diff can still be run, but it is no longer a
comparison of a failing device against a working one, and the reasoning that made it a ⭐
does not survive.

**What replaced it as the sharpest available comparison** is `0x0428` versus `0x043D`
(`EX-031`, `EX-033`): the legacy Setup Synchronous Connection has failed every instrumented
time, and the one Enhanced setup was answered in 64.7 ms and carried a link seventeen
minutes. That is `n = 1` on the answered side and is the comparison worth designing a
protocol around.

### ⚠️ C1 Build A is now a KNOWN-DESTRUCTIVE experiment

The ladder defines **Build A** as `hdev->reset = btusb_qca_reset` only, and the ⚠️ beside C1
warns about `btusb_setup_qca()` failing at HCI open. **That is no longer the main risk.**

Since the plan was written there are **three controlled demonstrations that a USB reset
destroys this controller** — `EX-023` (11.2 s to disconnect), the 2026-08-15 test (85.6 s),
and `EX-026` (85.6 s, and the reset was not even ours). `hci_cmd_timeout()` calls
`hdev->reset()` on the **first** timeout with no threshold.

So Build A does not "install a recovery path". It **automates the operation we have three
demonstrations of killing the device with, and fires it at +0 s instead of the 11 s or more
every manual test was late by.** It may still be the right experiment — the +0 s point is
genuinely unmeasured, and an immediate reset may behave unlike a late one — but it must be
planned as *deliberately provoking a device-destroying event*, not as a recovery trial.
Each run is expected to cost a power cycle.

### A4 is still the gate, still unmet, and is the honest bottleneck

Nothing has changed here and it is worth stating plainly: **there is no denominator.**
`EX-018`'s "13 of 34 boots" is withdrawn — its journal has rotated out and neither we nor a
reviewer can re-derive it. Every A/B/C/D comparison remains gated on A4, and A4 needs the
machine, a deterministic reproducer, and a family willing to lose Bluetooth repeatedly.

**And it is now harder than the plan assumed**, because `EX-030`, `EX-031` and `EX-032`
establish that at least four distinct failure modes present identically to an operator. A
rate collected without separating them measures a mixture. Any A4 protocol must classify by
the journal signature, not by whether Bluetooth "worked".

### The route the plan cannot see: a regression, not a rate

**This is the substantive addition.** The plan assumes one road to a patch — establish a
denominator (A4), then run the ladder (C1), then propose a fix supported by a measured
difference. That road is still blocked on A4.

There is a second road, and it opened when the source investigation dated a **regression**:
`BTUSB_USE_ALT1_FOR_WBS` was a Realtek-only opt-in through v5.11 and became an
**unconditional fallback** in v5.12 (source branch §4.5).

An upstream regression report needs a **mechanism and a commit**, not a failure rate. "This
commit changed behaviour for a class of adapters, here is the class, here is what happens"
is a complete report on its own. **That route bypasses A4 entirely**, and it is the only
one currently unblocked.

**Verified 2026-08-22, and the check that was meant to sink it confirmed it instead.**

This section first read: *§4.2 asserts alt setting 1, while every `Looking for Alt no` line
captured here says 6 then 3, with alt 1 appearing not once — so §4.5 may explain a different
fault.* That objection was **exactly backwards**, and the source says why
(`comms/2026-08-22T1106Z`):

* `BT_DBG("Looking for Alt no :%d", alt)` is at the **entry** of
  `btusb_find_altsetting()` — it logs the candidate *probed*, not the alt chosen.
* The transparent branch probes 6, then 3, and if both fail assigns `new_alts = 1` in a
  bare `else` **that calls nothing and therefore logs nothing**. So `:6` then `:3` and
  silence *is* the alt-1 signature. The absence of `:1` is what §4.2 predicts.
* The CVSD branch computes `new_alts` arithmetically and **never calls
  `btusb_find_altsetting`**. A `Looking for Alt no` line can only come from the transparent
  branch, so its presence is positive proof the device took that branch.
* `BTUSB_USE_ALT3_FOR_WBS` is set at exactly one site, inside the Realtek block.
  `13d3:3503` matches no entry, so the alt-3 test fails and alt 1 is forced.

⚠️ **And one inference of ours is withdrawn.** This document previously implied, and
`comms/2026-08-22T1320Z` stated, that `0x0428` means CVSD. **It does not.** `btusb_notify()`
takes `air_mode` from the HCI core's notify value, derived from the *air mode of the
synchronous connection*, not from the opcode. `0x0428` carries a voice-setting parameter and
can request transparent data exactly as `0x043D` can. **Legacy opcode ≠ CVSD**, and any
argument resting on that equivalence — including the `0x0428`-versus-`0x043D` comparison
proposed above as A3's replacement — must be restated in terms of air mode.

So the regression route is **live and source-verified**: this controller is placed in
isochronous alt setting 1 for wideband speech, a configuration it was never validated for,
because v5.12 turned a Realtek-only opt-in into an unconditional fallback.

### Revised order of work

1. ~~Settle §4.2~~ — **done 2026-08-22, confirmed.** See above.
2. **Name the v5.12 commit**, and confirm the unconditional fallback survives into 7.0.
   This is now the top item, and the regression report is the only unblocked route to
   upstream.
3. **Compute the exposed set** — adapters with no alt 6, not Realtek, no quirk. Turns
   "several laptops" into a list, which is what makes a maintainer act.
4. **A4**, still, because the ladder cannot run without it and no source finding removes
   the need for a measured baseline *if* the fix is ever to be validated here.
5. **Build C1's modules** (compile only) so the gate opening is not followed by a wait.

Items 1–3 and 5 need no hardware and are delegable; item 4 is the machine's and cannot be.

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

#### BL-04 addendum — which rows are affected, and how the audit was got wrong twice

**The code defect is closed** (`bt-trial` and `bt-window` now match the kernel's
`reset (full|high|low)-speed USB device`, and the operator pattern is narrowed to rfkill
lines indicating a block). **The rows written before that are not**, and are recorded here
rather than edited, on the same principle that left `EX-023`'s row missing rather than
reconstructed.

`bt-trial-audit`, which uses detectors written independently of `bt-trial`'s, reports:

```
row 2 (boot -4, 2026-08-14T21:16:56+02:00): perturbed DISAGREES
                recorded: none    journal: usb_reset (4 reset line(s))
row 3 (boot  0, 2026-08-15T21:40:46+02:00): perturbed DISAGREES
                recorded: none    journal: usb_reset (4 reset line(s))
audited 3 · disagreed 2 · unresolved 0
```

Row 1 is clean. **Two of three rows in the evidence file carry a false `perturbed=none`** —
censored windows recorded as clean observations, which would have pooled into failure-rate
denominators as though nothing had touched the controller.

**A second gate was audited and came back clean, and that is worth recording too.**
`bt1_status` is `confirmed` on all three rows, so none was ever silently dropped by the
`unknown` exclusion — a path which, until `4c1757a`, incremented a counter that nothing
ever read. "Audited, clean" is information; without it the question gets re-derived.

**Two procedural errors made while performing this audit by hand**, both of which returned
a confident `0` that read as "the row is correct":

1. **Wrong boot index.** Trial 2's boot is `-4`; it was queried as `-3`. Indices shift on
   every reboot, so counting backwards is unsafe — resolve by containment against
   `--list-boots` timestamps, which is what `bt-trial-audit` does, and why it found four
   resets where the hand count found three.
2. **`journalctl -k --since … --until …` without `-b`** returns only the **current** boot on
   this host. `tools/bt-stage2`'s header documents this exact trap; it was walked into
   anyway.

**The rule: an audit query returning zero needs a positive control before it is used** —
not before it is believed, because the belief is reasonable and the use is what causes
harm. Run the same query against a window known to be non-zero first. Here, running it
against row 3 would have returned 4 immediately and exposed the `-b` problem before it
touched row 2's answer.

This is the empty-input principle the repository already applies to enumeration
(`enumerated == 0` means something is wrong, not nothing to do), applied to an ad-hoc
query instead of a derivation.

**Why the defect survived every green suite run.** `perturbed` has three outcomes and the
suite drove one. `btusb_reload` was tested because that is the perturbation that happened
first, on 2026-08-13; `usb_reset` — the mode that corrupted two of three rows — was never
executed, while the comprehensiveness instrument reported 92%. That instrument counts modes
*reached*, not outcomes *discriminated*, and this is the clearest measurement of the gap.

**Consequence for A/B/C/D.** `perturbed` is what decides whether a row enters a denominator.
A detector reporting `none` for a reset would have made every build comparison quietly
wrong while looking entirely normal — and Build B is specifically the arm in which the
kernel issues resets.

### BL-05 — registering an incident is a manual sequence, and the machine is a kitchen laptop

Raised by the operator on 2026-08-16, immediately after `EX-026`: capturing an incident
took roughly a dozen hand-written commands over several minutes, some of them stopping for
permission prompts, while the fault window was live and the family was waiting for the
machine.

**Why this is an evidence problem and not an ergonomics one.** The cost falls entirely on
the window that is still open. Every minute spent hand-assembling greps is a minute the
operator is asked to leave a broken Bluetooth alone on a shared machine, and the pressure
to release the laptop is what ends windows early. `EX-025` and the 2026-08-16 live window
were both censored by exactly that pressure. A capture that takes ten seconds changes what
the record can contain.

**What is already there.** `bt-incident <slug> --since <time>` collects, sanitises and
files a session in one command, and it worked correctly today. What was manual around it:

- deciding `--since` by first hand-grepping for the fault's start
- the whole diagnosis — trigger, first timeout, intervention, terminator, intervals
- ruling out our own tooling as the cause (four separate queries, all negative)
- writing the exhibit, its extraction command, and re-running that command to capture
  verbatim output
- checking whether the device is still on the bus

**The shape a fix should take.** `bt-incident` already knows how to find the fault; the
diagnosis above is `bt-postmortem`'s job and it exists. The gap is that nothing chains
them, and nothing emits an exhibit skeleton with the extraction command already filled in
and already executed. A single `bt-capture-now` that runs the chain, writes the session,
drafts the exhibit and prints the timeline would remove every step above except the
judgement calls.

**The constraint that makes this delicate.** Such a tool runs *during* a live fault, so it
must be provably read-only — no probe, no `hciconfig`, no `btmgmt`, nothing that touches
the controller. The whole value of a live window is that nothing has touched it, and a
capture tool that perturbs the thing it captures is worse than the manual sequence. That
property needs a test, not a promise.

**Second-order:** the permission prompts are a symptom of commands assembled ad hoc at the
keyboard. A named tool is matched once; a hand-built pipeline is matched never. This is the
same argument that produced `tools/bt-interval` and `devtools/check`.

### BL-06 — `bt-archive` refuses a destination inside the repository, but not through a symlink

Found while assessing `ba0bed8` on 2026-08-16, and reproduced end to end rather than
argued.

`bt-archive` resolves its destination with `cd "$DEST" && pwd`, which returns the
**logical** path. If the destination is a symlink pointing inside the repository, the
comparison against `$REPO` does not match, the guard passes, and the archive is written —
physically — inside the tree:

```console
$ BT_REPO=…/symtest/repo BT_ARCHIVE_DIR=…/symtest/link tools/bt-archive -1
bt-archive — boot -1 (id c1315c25) -> …/symtest/link/boot-c1315c25.export.zst
  3 records, 4.0K on disk — read back and verified
$ ls …/symtest/repo/inside/
boot-c1315c25.export.zst
```

**Severity is set by what the file contains, not by how likely the symlink is.** A raw
`journalctl -o export` carries MAC addresses and Wi-Fi BSSIDs, and BSSIDs geolocate the
machine. This repository is public. The guard exists precisely so that nobody has to
remember; a guard that can be walked around by a symlink is a guard that has to be
remembered.

**The fix** is `pwd -P` on both ends of the comparison — `$REPO` is already physical
because it is derived through `readlink -f`, so only the destination diverges, and
`BT_REPO` supplied by hand may not be. **Not yet applied**, because the suite refuses to
run while a trial is open and a fix to a disclosure guard should not ship untested.

**The general shape, which is worth more than the instance.** This is the third control
this week that held where it was written and not where it ran, and the second whose
mechanism is a symlink. The first destroyed three system binaries by writing through links
into a directory that was also linked into. The rule then was *a directory is either linked
into or written into, never both*; the rule now is broader: **a path check that does not
resolve symlinks is not a path check.**

### BL-07 — a USB reset with no established caller

`EX-026` records a `usb 3-3: reset full-speed USB device number 2` that this project did
not issue. Ruled out with evidence: our watchdog (inactive, disabled, not installed, no
journal entries), `btusb_qca_reset` (its string `Resetting usb device` appears zero times),
driver unbind (`deregistering interface driver btusb`, zero times), and
`hci_cmd_timeout()` → `hdev->reset()` (no quirks entry matches `13d3:3503`, re-verified
against this kernel's binary).

**Why it matters.** Every prior stage-2 progression was ended by something of ours, which
is the standing objection to `EX-021` and `EX-023`. Establishing what else can reset this
device — and under what conditions — is the difference between "resets kill it" and "*our*
resets kill it".

**The one testable hypothesis, recorded as unsupported.** `power/control` was `auto` and
`/etc/udev/rules.d/50-bluetooth-no-autosuspend.rules` is **not installed on this machine**.
A runtime-suspend whose resume fails is one usbcore route to `usb_reset_device()`. No
suspend or resume line appears for `usb 3-3` in that boot, so it is unconfirmed in both
directions — usbcore's dynamic debug was not enabled.

**What would settle it:** enable dynamic debug on `usbcore`/`hub` for the resume and reset
paths before the next window, so the caller is named in the log rather than inferred from
what is absent.

### BL-08 — our own shutdown hook times out, and it corrupts the trial record doing it

Found 2026-08-16 from a photograph of the shutdown screen, which showed
`Job bt-trial-auto.service/stop running (1min 17s / 1min 40s)`. The journal confirms it on
both of that afternoon's reboots:

```
2026-08-16T15:28:29  Stopping bt-trial-auto.service …
2026-08-16T15:29:59  bt-trial-auto.service: Stopping timed out. Terminating.
2026-08-16T15:29:59  bt-trial-auto.service: Control process exited, code=killed, status=15/TERM
2026-08-16T15:29:59  bt-trial-auto.service: Failed with result 'timeout'.
2026-08-16T15:29:59  bt-trial-auto.service: Consumed 1min 20.147s CPU time, 95.6M memory peak

2026-08-16T18:44:36  Stopping bt-trial-auto.service …
2026-08-16T18:46:06  bt-trial-auto.service: Stopping timed out. Terminating.
2026-08-16T18:46:06  bt-trial-auto.service: Consumed 1min 24.224s CPU time, 95.0M memory peak
```

**It is CPU-bound, not blocked.** 1 min 24 s of CPU in 90 s of wall clock is the close path
scanning the journal, not `hci_alive` waiting on a dead controller — that call is capped at
`timeout 6`. The 90 s is `TimeoutStopSec` expiring on work that never finishes.

**Four consequences, in increasing order of seriousness.**

1. **Every shutdown costs 90 s** while a trial is open. On a shared kitchen laptop that is
   a real tax, and it is ours.
2. **The close is killed, so the row is never written** — the failure mode already known
   from the `enum_at_boot` fix, still live by another path.
3. **The state file survives the kill, so the next boot does not open a trial.**
   `autostart` exits early on `[[ -e "$CUR" ]]`, so one `trial` record silently spans
   several boots. `observational_boot` is boots-with-a-hang over total boots; merging
   boots into one row makes that denominator wrong in the same way `BL-04` did.
4. **The trial directory is reused and overwritten.** `evidence/trials/stock/trial-04/`
   was written by one trial at 03:35 and by a different trial at 18:48:14 the same day.
   The first generation exists **only because it happened to be committed** at `1f97aba`
   while working on an unrelated exhibit:

   ```console
   $ git show 1f97aba:evidence/trials/stock/trial-04/state-before.txt | head -3
   device 13d3:3503
     usb path        3-3
     power/control   auto
   $ head -3 evidence/trials/stock/trial-04/state-before.txt
   device 13d3:3503
     usb path        absent
     power/control   -
   ```

   Nothing in the tooling preserved it. **This is a priority-1 violation reached by
   accident of good luck**, and it is the reason it belongs at the top of this list.

**What the row that did get written says.** Trial 4 closed at the 18:57:33 power-off,
recording `treatment=autosusp=?,power=?` and `bt1_status=not_observed` — for a boot in
which `EX-026` documents a textbook BT-1 fault at 15:37:49. The degraded values are honest
about the controller being absent; the `not_observed` is not, and it would pool into a
denominator as a clean boot.

**The other thing the hook does, which matters for the exhibits.** `autostop` calls
`hci_alive`, and `hci_alive` runs `timeout 6 hciconfig "$h" name` — an HCI
Read_Local_Name to the controller. **When a trial is open, every shutdown touches the
device.** That bears directly on `EX-025`, whose claim is that its window was "ended by an
ordinary system shutdown rather than by anything touching the device".

`EX-025` appears to survive: its `bt-trial-auto` stop at `2026-08-15T19:23:58` completed
inside the same second with no timeout, and every close with a trial open takes 90 s — so
no trial was open and no probe was issued. That inference should be replaced with a direct
check before the exhibit is cited upstream, and **any future shutdown-censored window must
be checked for an open trial before it is called untouched.**

**What it is NOT.** It does not prevent a reboot, and it cannot affect whether a reboot
clears the controller: it runs in userspace before `reboot.target`, and clearing the
controller is a matter of VBUS, which no userspace program holds. Across all fourteen
retained boots exactly one failed to enumerate — the reboot from stage 2 in `EX-027` —
and that boot's predecessor had already had the device off the bus for over three hours.

**The fix has three parts, and none is "raise the timeout".** Bound the close path's
journal work the way `enum_at_boot` was bounded; clear the state file even when the close
is killed, so a boot is never silently merged; and derive the trial directory so a reused
number cannot overwrite an existing one.

#### BL-08 addendum — the operator's decision, and the fourth part of the fix

Offered on 2026-08-17, during the 11190 s window: move the trial state file aside before
shutdown so `autostop` exits without probing, giving that window an untouched terminator
at the cost of someone remembering to say "I'm shutting down now".

**Declined, for the reason that makes it the right call.** The operator's words:

> For the cases when it is not me who shuts down.

This is a family laptop. The person who closes the lid or holds the power button is
frequently not the person running the investigation, and a procedure that has to be
recalled *by whoever happens to be at the keyboard* is not a control at all. The 90 s cost
was accepted explicitly; the dependence on memory was not.

**That converts the hook's probe from an operational nuisance into a design defect.** So
long as `autostop` calls `hci_alive`, every shutdown of this machine touches the
controller, and the only defence is a human remembering. Every shutdown-terminated window
from here is contaminated by default, and `EX-025`'s whole value was that its terminator
was not.

**Fourth part of the fix, and it outranks the other three: `autostop` must classify
without touching the device.** Everything it needs is already readable without issuing a
command — `bt-window` decides enumerated-versus-gone from `/sys/bus/usb/devices` and
HCI-responding-versus-not from the journal's timeout lines, and touches nothing. The
`hciconfig … name` call is the only part of the close path that talks to the controller,
and it buys a classification the journal already contains.

**Deployment catch, verified rather than assumed.** The copy that runs at shutdown is
`/usr/local/bin/bt-trial`, not the tree's, and the two are byte-identical along this path:

```console
$ diff <(sed -n '/^autostop)/,/^    ;;/p' /usr/local/bin/bt-trial) <(sed -n '/^autostop)/,/^    ;;/p' tools/bt-trial) && echo "autostop path IDENTICAL in deployed and tree"
autostop path IDENTICAL in deployed and tree
```

So fixing the tree changes nothing until the fix is deployed — and deployment currently
means `install.sh --apply`, which also runs `systemctl enable --now bt-hang-watchdog`
(`install.sh:465`), the service whose USB reset has three demonstrations of destroying
this controller. **A tools-only deployment path that enables no services is a prerequisite
for shipping this fix**, and does not exist yet.

**The general rule, which the operator stated better than the backlog had:** a control
that depends on someone remembering is not a control. It is the same finding as
`bt-retention`'s warning needing someone to act on it, and as `bt-archive` archiving
nothing on its own — third instance this week, and the first where the someone is not even
a member of the project.

### BL-09 — nine exhibits cannot be placed on the journal's axis, and the fix is the format not the parser

Once `bt-retention` stopped reading the capture stamp as the evidence's (`0d3f2f9`), the
real picture on the investigation machine is:

```
  29 exhibit(s): 12 still verifiable, 8 no longer, 9 not judgeable
  4 of the 8 were settled by capture time alone — captured before any
  retained boot, so whatever they describe is older still.
```

**The number reported to the maintainer on 2026-08-16 — "20 of 25 re-derivable" — was
overstated by eight.** Those eight were judged by when someone ran the extraction command,
not by when the evidence happened. `EX-018` now reports `not judgeable`, which is correct:
its tables are bare local time and its journal is gone.

**Nine `not judgeable` is the gap worth closing**: `EX-010` through `EX-015`, `EX-018`,
`EX-019`, `EX-020`. None carries a timestamp with a UTC offset outside its provenance
block, so nothing can place them against journald's boot ranges.

#### The decision asked for: keep the blunt cut

The fix truncates each exhibit at the `## Provenance` heading, and the maintainer flagged
that as blunt — if the exhibit format ever grows an evidence-window field that lands in
that table, the tool will ignore it. Two options were offered: put such a field above the
heading, or teach the cut its name.

**Keep the cut blunt. Put the field above the heading.** The two failure directions are not
symmetric, and that asymmetry is the entire lesson of the defect just fixed:

* a blunt cut that drops a field fails to **`not judgeable`** — a missing answer, visible,
  and it prompts someone to look;
* a parser that reads named fields out of the provenance table fails to **a wrong answer** —
  it re-creates exactly the coupling that made the capture stamp masquerade as the
  evidence's, and it would do so silently.

A tool deciding which parts of the capture record to trust is the shape that caused this.
The cut should stay incapable of that.

#### What that implies, and it is work

1. **`bt-exhibit` should emit an evidence-window line in the body**, above `## Provenance`,
   carrying the first and last absolute instants the exhibit's own output covers — with
   offsets, since a bare local time is not an absolute instant.
2. **The nine existing exhibits need one added.** That is an annotation derived from each
   exhibit's own content, not a rewrite of a claim, and it should be committed as such and
   clearly marked. `EX-018` and `EX-020` may honestly stay unjudgeable, since their
   evidence is gone and no line in the file can place it.
3. **The exhibit README should state the requirement**, so the next exhibit carries it
   without anyone remembering — which is the standing rule from `BL-08`.

#### One prediction that did not hold, recorded because predictions should be checked

The fix's own notes say four of the thirteen settle by capture-time arithmetic against the
fixture, and "on the real journal it will be more, since the oldest retained boot has moved
forward". On the real journal it is **still four** — `EX-001` through `EX-004`. The other
nine were captured on or after 2026-08-12, inside the retained window, so the arithmetic
cannot settle them in either direction. Nothing is wrong with the tool; the estimate was
optimistic and the run says so.
