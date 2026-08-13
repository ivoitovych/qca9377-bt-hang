# Issue register

This investigation began as "the Bluetooth controller hangs". It is now clear that is not
one defect. At least six distinct problems have been observed on this machine, and
filing them under a single heading has actively slowed the work: evidence for one kept
being read as evidence for another, and three hypotheses were killed only after being
mistaken for the main bug.

Each issue below is tracked separately, with its own evidence and its own reportability.
They are numbered `BT-n` so exhibits and commits can cite them.

---

## Evidence model

Two rules govern how anything here is read. Both were bought with mistakes.

**1. An event missing from one capture path is not evidence the controller did not do it.**

There are two independent HCI capture paths (`bt-trace` via btmon, `bt-capture` decode-free),
which gives three distinct states rather than the naive two:

| | Reading |
|---|---|
| **both paths saw it** | strongly corroborated |
| **one path saw it** | *evidence* the event occurred, and a discrepancy requiring instrumentation accounting — it does **not** by itself say which observer is right |
| **neither path saw it** | possibly absent — subject to what coverage each path actually had |

The asymmetry is the point: **agreement raises confidence in the event; disagreement tells
you something about the measurement system, not which observer to believe.** Either path can
in principle omit, duplicate, misdecode or mis-frame. In the `EX-010`/`EX-011` case btmon was
identified as the losing observer only because of *additional* structure — a restart in its
own log, the chronology, an intact second path, and finally a deterministic reproducer — not
because one path showing an event settles it.

Before redundancy existed, absence in the capture silently became absence in the inferred
history. `tools/bt-capdiff` exists to make the middle row visible, and on its first run it
was the middle row that exposed the btmon crash trigger.

**2. The liveness probe is an intervention, not an observation.**

`hciconfig <dev> name` — used by `bt-state` and by `bt-health-snapshot` on a timer — injects
an HCI command/response exchange into the controller under study, and is *proven* to
deterministically abort an active btmon capture (`EX-011`). Something that demonstrably
perturbs one observer cannot be assumed inert toward the subject.

There is **no evidence** the probe contributes to BT-1, and it is not a suspect. It is
recorded so the question stays answerable: every trial now logs probe count, btmon abort
count, and the interval from the last probe to the first HCI timeout. If fatal transitions
ever cluster shortly after probes, that appears in a column. If they fall at arbitrary
distances across thousands of probes, that is negative evidence against an observer effect —
worth exactly as much.

The causal graph therefore carries one more antecedent, with its question mark intact:

```
   monitoring probe  --?-->  controller state  -->  synchronous-audio transition
                                                          |
                                                          v
                                                   HCI non-response          <-- STAGE 1, established
                                                          |
                                    +---------------------+---------------------+
                                    |                                           |
                              our reset / rebind                        left alone
                                    |                                           |
                                    v                                           v
                        observable USB errors --> device gone        still enumerated at 72 min,
                                                                     then WE ended the observation
                              (every case so far)                          (n = 1, censored)
```

The right-hand branch has been walked exactly once (`EX-016`) and never to its end, so the
arrow below it is missing on purpose. Whether one exists is the open question in BT-1.

### The five levels a timestamp has to survive

Each level below was reached by getting the one before it wrong, in this repository, on
real data. They are listed because the failures are not obvious in advance and each one
produced a confident, clean-looking, wrong number.

| Level | Question | How it was failed here |
|---|---|---|
| **1 — timestamp** | what happened, when? | day-of-month arithmetic; gaps spanning a reboot |
| **2 — provenance** | *why does this timestamp exist?* | udev- and timer-driven probes indistinguishable in one unit |
| **3 — independence** | could the measured phenomenon have caused it to exist? | probes fired by the controller's own failure events (`EX-012`) |
| **4 — exposure geometry** | are **both** boundaries of the denominator independent? | an outcome-triggered *closing* probe still lets the event pick its own interval |
| **5 — sampling unit** | are these N independent events, or N records from fewer events? | 8 `tx timeout` lines counted as 8 failures; they were 7 incidents |
| **0 — recognition** | does the filter match the event at all? | `command tx timeout` found 8 of 173 real timeouts; the kernel names the opcode (`EX-015`) |

Level 0 was added last and sits beneath the rest, because it is the one that fails
silently in the safe-looking direction: a filter that matches nothing yields a clean zero,
and a zero reads as *nothing happened* rather than as *nothing was looked at*. It was
caught only because two independently-sourced axes of the same record contradicted each
other — see `HISTORY.md`, Phase 24.


The goal is not software that usually produces the right statistic. It is software that
says **"I cannot justify this statistic from the provenance of the available data, so I
will not print it."** `bt-phase` does that: it refuses when its probe set cannot be
timer-driven, rather than reporting a number that would look better than the data
deserves. `tests/run-tests` asserts each level with a fixture built so the old behaviour
fails it, and `devtools/repo-validate` runs them — because a comment claiming an invariant
cannot be executed, and this repository has already shipped one that was false.

**Independence matters for submission.** A small, deterministic, well-evidenced bug is far
more likely to be fixed than a large intermittent one, and bundling them means the weakest
member sets the pace for all. `BT-2` and `BT-4` are reportable *today*; `BT-1` is not.

---

## BT-1 — Controller stops answering HCI, and may or may not then leave the USB bus

**Status:** under investigation — the original bug, and the hardest.
**Reportable:** ❌ not yet. No quantified reproducer (`docs/pre-submission-checklist.md`).

The controller stops answering HCI commands. It has often been observed to stop answering
USB control transfers and leave the bus some time later, after which a cold power-off
recovers it.

> **Untested assumption, flagged rather than removed.** Everywhere this project says *"a
> warm reboot does not drop the M.2 power rail and will not recover it"* — the protocol's
> step 0, `bt-mode`, `install.sh`, `EX-005`, `docs/related-reports.md` — that is hardware
> reasoning which entered the documentation as fact. No exhibit supports it. On 2026-08-13
> the controller recovered across a shutdown that reached `reboot.target`, though an
> unlogged power-off in the 98 s gap is not excluded (`EX-017`), and firmware time cannot
> tell the two apart (`EX-019`). No field in the journal witnesses the rail, so this can
> only be settled by a deliberate trial: hang the controller, warm-reboot without touching
> the power, look. That trial is **secondary** — it would consume a hang that the stage-2
> question needs first.

**Current formulation — everything the evidence earns, and nothing more:**

<!-- BT1-CURRENT-BEGIN -->
> The controller sometimes enters a non-responsive HCI state during synchronous-audio link
> transitions, while remaining USB-enumerated. Later USB collapse has so far only been
> observed after a reset, rebind or driver reload; whether it belongs to the fault's
> untreated trajectory is **unresolved**.
<!-- BT1-CURRENT-END -->

That is deliberately a statement about *when and where*, not *why*. The failure is now
well localised in time and in subsystem behaviour, and not at all in mechanism. Anything
phrased as a mechanism is currently a hypothesis, and the register above is the place to
find out which ones have already died.

### ⚠️ The two-stage model is no longer established — only stage 1 is

This section previously opened *"45–66 s later it stops answering USB control transfers"*
as settled fact. It is not. Every observation behind that figure contained one of our own
resets between the HCI timeout and the USB collapse. The watchdog was designed to recover
the controller, so it fired on exactly the boots that progressed, and it fired *first*.

The first observation with no intervention of any kind (`EX-016`, stock kernel, watchdog
off, probes off, stock power management) showed **no progression at all for 4331.99 s —
one hour twelve minutes** — and ended only because `install.sh` reloaded btusb. The only
USB-layer line in the entire window is our own driver unload.

Then the whole retained journal was checked (`EX-018`/`EX-020`, about 3.3 million kernel
lines, 22 boots). The historical classifier reported 14 stage-1 boots, zero uncensored USB
losses, nine resets and five shutdowns. A later review found that “our reset” was inferred
from absence of a recognized preceding bus error rather than positive provenance. That 9/5
breakdown is therefore pending re-capture under the positive/kernel/unknown reset categories.
No curated exhibit currently establishes an uncensored USB loss, but the whole-journal
zero must not be cited as mechanically re-verified until that re-capture is done.

Worse, the 45–66 s figure is visibly an artefact of the instrument. The short windows
cluster at 29–121 s because that is the watchdog's reaction time; the two boots where
nothing fired promptly ran **1 h 12 m** and **6 h 26 m**, enumerated and error-free
throughout. The watchdog exists to reset a failed controller, so it fires on exactly the
boots that progress, and it fires first. Averaging what follows measures our software.

So the causal picture has two live readings:

| | sequence |
|---|---|
| what was assumed | audio transition → HCI dies → 45–66 s → USB dies |
| equally consistent | audio transition → HCI dies → stays enumerated → **our reset** → USB dies |

`n=1` and right-censored, so natural progression is **not excluded** — the device may
leave the bus on its own after some interval longer than 72 minutes. What *is* excluded is
continuing to quote 45–66 s as the fault's natural trajectory.

**The four alternatives now open**, none of them eliminated:

- **A** — a reset recovers stage 1 safely if issued at the right moment;
- **B** — a reset sometimes recovers it but leaves controller state unstable;
- **C** — a reset actively pushes the controller from HCI-only failure into USB failure;
- **D** — stage 2 happens naturally anyway, and the reset timing in earlier runs was
  coincidental.

`EX-016` raises **C** substantially relative to where it stood, without proving it. It
also re-reads `EX-004` — *"an early reset recovers, then it dies again 132 s later"* —
which was filed as *the reset is not durable* and is equally consistent with *the reset
changed the trajectory*.

**The experiment that settles it** requires no new instrumentation and no new build: cold
boot into experiment mode, use the machine normally, and when BT-1 occurs **do nothing** —
no `hciconfig`, no rfkill toggle, no btusb reload, no reinstall, no mode change. Record
whether the device leaves the bus on its own, and at what interval; if the operator gives
up first, that observation is right-censored at whatever duration they tolerated. A
handful of such boots answers a question the project had considered closed for months.
`bt-stage2` reports the accumulating record, classified by what ended each window.

**The leading discriminant** — not "the remaining candidate", which is too strong — is the
request and link parameters together with the surrounding SCO state. At least five
logically distinct possibilities still live in that region:

1. the HCI request parameters themselves;
2. the negotiated SCO/eSCO link properties;
3. the ordering and timing of setup, traffic and teardown;
4. the USB interface alternate-setting transition;
5. controller state established earlier that only becomes observable during SCO operations.

Comparing the fatal runs against the survived ones must therefore compare the whole event
window, not the parameter fields — `bt-sco --window` exists for exactly that. With two
fatal and three survived observations, a parameter difference will be found whether or not
it matters, and a parameter almost never varies alone: mSBC rather than CVSD implies eSCO
rather than SCO, implies a different packet type, a different alternate setting, a
different isochronous packet size and a different teardown.

What is established:
- At onset the USB transport is **healthy** — every URB completing status 0, first error
  31.4 s later (`EX-008`). That rules out USB transport failure as the **immediate cause of
  the first HCI timeout** — stated narrowly on purpose. It does not exonerate every USB-side
  state transition involved in SCO: the alternate-setting switch btusb performs for
  isochronous bandwidth is a configuration action, not ordinary traffic, and could still
  place the controller into the state in which it later stops answering.
- Both instrumented failures involve **SCO link handling** and the USB alternate-setting
  switch btusb performs for isochronous bandwidth — setup unanswered in one case
  (`EX-006`), teardown unanswered in the other (`EX-009`). The constant is the path, not
  the opcode.
- An early reset recovers the controller but not durably (`EX-004`); once timeouts begin,
  nothing recovers it (`EX-005`). Both are observations about resets, and both are now
  ambiguous in the direction described above.
- With no intervention, the controller remained enumerated and free of any USB-level error
  for 4331.99 s after HCI went silent (`EX-016`). Right-censored by us.

Still unknown: whether a reset at +0 s helps *or harms*, whether stage 2 occurs at all
without intervention, whether firmware download prevents the fault, and what makes a given
SCO operation fatal when others succeed.

---

## BT-2 — Opening the Bluetooth panel causes a permanent 16.0 s HCI command desync

**Status:** characterised.
**Reportable:** ✅ **yes, independently, and it is the easiest thing here to report.**

Opening the GNOME Bluetooth settings panel is followed within 0.06–10 s by
`unexpected event for opcode 0x2005` (`HCI_LE_Set_Random_Address`), which then repeats at
an **exact 16.0 s cadence** for as long as the panel stays open — runs of 228, 487 and 2480
observed. Reproducible in seconds, on every boot examined (`EX-002`).

**It is not the cause of BT-1.** Cross-tabulated over 34 boots: 8 boots carried it and
never hung, 2 hung without it (`EX-003`). Both false positives and false negatives. It is a
companion symptom of the same controller, and must be reported as its own defect rather
than as evidence for BT-1.

Why it is worth reporting alone: a maintainer can reproduce it in five seconds. Nobody can
reproduce "it hangs after several hours".

---

## BT-3 — `13d3:3503` is absent from the btusb quirks table

**Status:** confirmed in upstream source and shipped binary (`EX-001`).
**Reportable:** ⚠️ the patch is trivial; the *justification* is what is missing.

The device is matched by no quirks entry, so it receives neither `hdev->reset` nor
`btusb_setup_qca()`. Its immediate ID neighbours `3491/3496/3501` carry
`BTUSB_QCA_ROME | BTUSB_WIDEBAND_SPEECH`; `3502/3503/3504` carry nothing.

This may be the cause of BT-1, or an unrelated omission that happens to be true. Adding the
ID is a three-line patch, but submitting it as a *fix* requires showing it fixes something
— which is what the A/B/C/D ladder exists to establish. See `docs/fix-proposal.md`.

Note the gap could also be deliberate: a silicon revision, a firmware architecture change,
or a vendor reason for omitting exactly those three IDs. Absence is suggestive, not proof.

### ⚠️ The expected DIRECTION of this patch is no longer clear

The quirk installs `hdev->reset`, which `hci_cmd_timeout()` calls on the **first** timeout.
The reasoning was: timeout happens → no reset callback → the controller eventually
disappears → therefore the missing callback is why it disappears.

`EX-016` breaks the last step. The controller that nobody reset did **not** disappear — it
stayed enumerated and error-free for 72 minutes, and the collapse followed our reset in
every case where a collapse was seen at all. If resetting a stage-1 QCA9377 is itself
capable of driving it off the bus, then supplying the missing callback would make the
kernel do automatically, on the first timeout, what we currently do by hand.

That is **not** a claim that the patch is harmful. Alternative **A** — a reset recovers
stage 1 safely when issued promptly, and our late hand-issued resets were simply too late —
remains fully alive, and `EX-004` (an early reset *did* recover the controller) is direct
support for it. The honest position is that the sign of the effect is unmeasured.

What this changes in practice:

- BT-3 stays a **real and interesting driver difference**, worth documenting either way.
- It is no longer described as the *likely fix* for BT-1.
- Build **B** (quirk added) must therefore be judged on more than "did it hang?" — it has
  to record whether the automatic reset recovers the controller, and whether boots under B
  reach USB absence *more* often than boots under stock-with-no-intervention.
- The stage-2 natural-history question is a **prerequisite** for reading the B result at
  all: without knowing what untreated stage 1 does, there is no baseline against which an
  automatic reset can be scored as recovery or as harm.

---

## BT-4 — `btmon` aborts repeatedly while capturing (bluez 5.72)

**Status:** ⬆️ **escalated 2026-08-12 — this blocked the investigation, it is not cosmetic.**
Mitigated by an independent capture; still not diagnosed.
**Reportable:** ✅ yes, to BlueZ — and it is entirely separate from the controller.

**Why the priority changed.** 67 aborts in a single boot. When the SCO request parameters
became the only remaining candidate for what distinguishes a fatal synchronous setup from a
survived one, the captures containing them were gone — partly to these crashes, partly to a
retention setting that was not in effect (see `changes-applied.md`). A bug in the measuring
instrument outranks a bug of equal size elsewhere, because it removes the ability to
investigate anything else.

**Mitigation, not a fix.** `bin/bt-capture` now records the same stream independently: it
reads raw frames from the kernel's HCI monitor socket and writes btsnoop **without decoding
them**, so a decoder bug cannot end the capture. btmon still runs alongside it for live
decoding.

**✅ Minimal reproducer found** (`EX-011`), which was the blocker on reporting this:

```console
$ hciconfig hci0 name     # one abort, every time
```

Triangulated: `hciconfig hci0` (ioctl only, no HCI command) does **not** abort it, and
`bluetoothctl show` (same query via MGMT) does **not** abort it. The trigger is a
command/response exchange on a **raw HCI socket** observed by the monitor — not a specific
opcode, and not merely opening the socket.

Found by `tools/bt-capdiff` comparing the two capture paths: the decode-free capture had
retained the exchange that btmon lost one second before each of its restarts. That is the
measurement-redundancy argument paying off — a discrepancy between independent capture
paths was an instrumentation finding, exactly as intended.

**Still needed before filing:** a backtrace from the aborting process, and a check against
current BlueZ (5.72 is not the latest).

### Two separate facts, which must not be merged in the report

| | |
|---|---|
| **The defect** | a raw-HCI command/response exchange reproducibly aborts an active btmon capture. One command, deterministic. This is the BlueZ-facing bug. |
| **The rate here** | 67–85 aborts per boot, because *this project's* health probe fires the trigger on a timer. This is a property of the environment, not of the defect. |

Filing "btmon crashes 80 times during normal Bluetooth operation" would have been a badly
characterised report — a reader would reasonably infer that ordinary desktop use produces
that rate. It does not. What produces it is a monitoring loop that happens to invoke the
trigger repeatedly.

### ⚠️ This project's own probes are the main cause of the crash rate

`bt-state` on every invocation, and `bt-health-snapshot` on a timer, use
`hciconfig <dev> name` as a liveness check — so the monitoring has been continuously
crashing the capture it depends on. That accounts for the bulk of the 67–85 aborts per boot.

The probe is nevertheless **kept**. It is a genuine end-to-end test: it sends a command and
waits for the controller to answer, which is exactly what detecting a wedged controller
requires. An MGMT-based probe would avoid the crash but could report "alive" from cached
daemon state while HCI is wedged — trading a capture bug for a false negative in the thing
the watchdog exists to detect.

That trade is only acceptable because `bt-capture` is now crash-immune. Before it existed,
this was a genuine self-inflicted wound.

**Treat it as a known, temporary measurement perturbation — not the final architecture.**
The trade today is: *measure controller health, knowingly sacrifice btmon continuity, retain
independent raw evidence anyway.* The ideal is a controller round-trip liveness test that
destroys neither capture path. Whether one exists is a separate problem, and it does not
block BT-1. Until then the perturbation is recorded per trial rather than assumed away.

`btmon -w` aborts with a core dump during capture, frequently enough that the capture
rotates on crash rather than on size. Files average ~2 MB against a 128 MB rotation
threshold. Each abort loses roughly one second of capture, logged as a gap.

This is a userspace tool bug in a *diagnostic* tool, which makes it worse than it sounds:
it degrades the evidence available for every other Bluetooth bug. It also caused a real
loss here — the aggressive rotation pruned away the pairing sequence of a session under
active investigation before retention was raised.

Not yet reported. The minimal reproducer now exists (below); a backtrace from the
aborting process and a check against current BlueZ are still outstanding.

---

## BT-5 — SCO link established, then carries almost no data

**Status:** observed once; unexplained.
**Reportable:** ❌ no — one observation, no mechanism, may be a symptom of BT-1.

In the failure of 2026-08-12 06:26, the SCO link came up cleanly (`handle 0x0003`, USB
alternate setting switched) and then carried **11 packets in ~30 ms and nothing for the
following 7 seconds**, before the disconnect that wedged the controller (`EX-009`). SCO at
8 kHz should carry hundreds of packets per second.

Whether this silence is a precursor to the failure or simply an idle voice channel is not
established. It is recorded because it is the kind of detail that looks meaningless until a
second instance makes it a pattern.

---

## BT-6 — Controller delivers ACL data for a connection handle the host does not know

**Status:** observed once.
**Reportable:** ❌ no — a single occurrence with no mechanism and no second instance.

```
2026-08-12T08:27:36.996046  hci0 evt 2
2026-08-12T08:27:36.996084  Bluetooth: hci0: ACL packet for unknown connection handle 1
```

The controller sent ACL data on handle 1 while the host had no such connection. That is a
host/controller **state disagreement**, and it is a different signature from the `0x2005`
desync in BT-2 — that one is a command/event mismatch, this is a data channel the host has
no record of.

Recorded rather than investigated. It may be noise, it may be a symptom of BT-1, or it may
be a third independent state-tracking defect. Deciding which needs a second instance, and
this register exists partly so a second instance is recognised as such instead of being
read as new.

Worth noting the family resemblance without leaning on it: BT-2 and BT-6 are both the host
and the controller disagreeing about state, and BT-1's failures both occur during SCO link
transitions, which are state changes. Whether that is one underlying fault or three
unrelated ones is exactly what is not yet known.

---

## On the wider claim

It is tempting — and this investigation supplies plenty of emotional support for it — to
conclude that Bluetooth on Linux is broadly unreliable in a way it is not on Windows or
Android. That belief is widely held. It should still be kept out of anything sent upstream,
for two reasons: it is not something this evidence establishes, and a maintainer reading it
will discount everything around it.

What the cross-platform comparison **does** support is narrower and much more useful:

- **Windows** drives this controller through the same silicon without failure, so hardware
  alone is not a sufficient explanation. It may still be a controller or firmware defect
  that only Linux's command sequence reaches.
- **Android runs the same Linux kernel** — the same `net/bluetooth` HCI core and the same
  `btusb` driver — but a completely different userspace stack (Fluoride, not BlueZ), and on
  most Android hardware SCO audio is routed over a dedicated PCM/I2S path to the codec
  rather than over HCI at all.

That second point is a genuine diagnostic clue rather than a complaint. If the platforms
that avoid this failure are also the platforms that avoid SCO-over-HCI/USB, and our own
evidence points at the SCO and isochronous path, those converge. It is worth stating in a
report; "Linux Bluetooth is unstable" is not.

---

## Why this class of bug goes unreported

Worth recording, because it explains why a defect that has apparently persisted for years
has so little written about it:

- **Rare per user.** A failure once a week is an annoyance, not a bug report.
- **Recovery destroys the evidence.** The only fix is a cold power-off, which is exactly
  what discards the volatile state and, without persistent logging configured in advance,
  the logs too.
- **The default logging is not sufficient to diagnose it.** Naming the command in flight at
  the moment of failure required kernel dynamic debug enabled from boot. Nothing in a
  default install would have shown it.
- **The instrumentation is more work than the bug seems to justify.** Reaching the point of
  being able to say anything precise took a watchdog, persistent metrics, HCI capture, USB
  capture, boot-spanning log analysis and roughly fifteen purpose-built tools.

None of that is an argument about Linux. It is an argument about *selection*: this class of
failure is filtered out of bug trackers by its own statistics, not by its rarity in the
field. That is a defensible point and worth making in a report — it explains why a
maintainer may never have seen it despite it being common.
