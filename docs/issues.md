# Issue register

This investigation began as "the Bluetooth controller hangs". It is now clear that is not
one defect. Over twenty distinct problems have been observed on this machine by 2026-10-11
(nine `BT`, three `M`, ten `U`, one unexplained `bluetoothd` core), and
filing them under a single heading has actively slowed the work: evidence for one kept
being read as evidence for another, and three hypotheses were killed only after being
mistaken for the main bug.

Each issue below is tracked separately, with its own evidence and its own reportability.
They are numbered `BT-n` so exhibits and commits can cite them.

---

## Current state — 2026-10-11 (what changed since the 2026-10-09 state below)

- **BT-9: everything sent 2026-10-10.** Stable backports of `96d006ae6445` went to 6.12, 6.6 and 6.1, each tested with a new deterministic `mgmt-tester` case that fails without the backport. Also sent: the BlueZ test series and the emulator leak fix the testers exposed. The laptop's own stuck discovery had already ended on 10-10 at 15:02, at the operator's adapter power cycle (corrected 2026-10-14; `docs/STATUS.md`); the reboot into `7.0.0-38` on 10-11 brought the kernel that carries the fix.
- **U10 (new, 2026-10-11):** a speaker silent on SBC-XQ (section below, with the userspace items).
- **U11 (new, 2026-10-13):** a headset that has just connected does not get the sound; WirePlumber's history of earlier choices outranks it (section below).
- **The machine** runs `7.0.0-38` with the upstream entry (E3) since 2026-10-11; QCA firmware loaded.

## Current state — 2026-10-09 (what changed since the 2026-10-03 state below)

- **BT-9 (new, 2026-10-09, kernel)** — when a simultaneous-discovery cycle's Inquiry
  Complete lands inside the LE scan-off, the kernel never stops discovery and refuses every
  later scan until a suspend or power-off; twice in this boot, stuck since 2026-10-04 10:26:11
  (section below, `EX-062`). Already fixed upstream (`96d006ae6445`), but not in 6.12, 6.6 or
  6.1, where the `dc16388d45ec` backport will give this device the quirk.

- **M-1 is not sent as one series.** An outside research review (10-05) found that the mesh
  transmit path has never had one ownership model and that other 2026 work is fixing other
  pieces of it; the patches are being split into separate contributions (`STATUS.md`).
  Findings from that work were kept private until each had its patch; since 2026-10-09 kernel
  findings are recorded here as they are found, and that work is being ported to `main`.
- **M-3 (new, BlueZ `shared/mgmt`)** — `mgmt_unregister()` from a notification callback
  leaked the entry, and unregistering the next entry was a use-after-free. Fix and unit tests
  sent and applied 2026-10-08 (section below).
- **BT-7's a2dp fix is in BlueZ master twice.** The redundant v2 was applied on 2026-10-07 on
  top of v1, so the stream is checked twice in a row; harmless, and a one-line cleanup is
  prepared (`patches/bluez/README.md`).

## Current state — 2026-10-03

The lifecycle of every issue, with its component, evidence maturity, state and next action,
is one table in [`STATUS.md`](STATUS.md) — the only page that says what is *current*. This
register keeps each issue's evidence, reasoning and falsifiers. What changed since the
2026-09-18 state below:

- **BT-1 is explained and remedied.** The missing `btusb` device-table entry left the
  controller on its ROM firmware; on that firmware the first HCI command after a transparent
  SCO stream died in all twelve instances. With the QCA firmware the entry loads, 58 + 16 SCO
  links on three headset models closed with every hang-up answered and 0 timeouts
  (`EX-055`–`EX-058`). The entry is upstream (`dc16388d45ec`, Tibor Harcsa, v7.3-rc1); a
  stable backport request was sent 2026-10-02 and queued by the stable team for seven lines
  (7.2, 6.18, 6.12, 6.6, 6.1, 5.15, 5.10) on 2026-10-03 (`EX-061`); since released in 7.2.10,
  6.18.56 and 6.12.113, and in the other four lines' release candidates of 2026-10-17
  (`docs/STATUS.md`). What the ROM firmware does
  wrong is not claimed.
- **BT-3 is therefore the cause of BT-1, not only its missing recovery** — the opposite of
  the 09-18 reading below, which is kept as written.
- **BT-7 is fixed upstream** (two BlueZ patches applied 2026-09-21).
- **BT-8 (new)** — the kernel-side source of the reply that crashed `bluetoothd` in BT-7's
  first site: pending management commands flushed at power-off were answered with a status
  byte read from the wrong object. Fixed upstream (`86ef0f58bdec`, 2026-09-29).
- **M-1, M-2 (new, kernel mesh advertising)** — found while reading why the list's CI fails
  `mesh-tester` on every patch since June: the mesh instance keeps advertising after its
  count, the done path completes the wrong request, and a scheduler window starts a packet
  twice (M-1, three patches under outside review); a `u16 duration` overflow for timeouts
  above 65 s (M-2, note only). Both are developed on a private branch until sent; this
  register records the facts.
- **U1–U9** — the userspace audio items are listed in their own section below, each tagged
  [log] / [operator] / [inference]; `STATUS.md` carries their lifecycle states (U5 withdrawn,
  U6 fixed upstream in GNOME 47, U7 and U9 confirmed, the rest observed).

## Current state — 2026-09-18 (front-door review `FD-22`) — superseded above, kept as written

This register was written while the fault was localised in time and not in mechanism, and
its entries below still read that way. Since `EX-033` (08-22) the wedge has been located in
one path, reproduced seven times across three kernels, two headsets and both power
configurations (`EX-033`, `036`, `037`, `038`, `040`, `042`, `043`): the controller
negotiates transparent (mSBC) SCO, `btusb` falls back to **USB alternate setting 1** (a
9-byte isochronous endpoint) and sends each 27-byte buffer as three 9-byte packets, and
**the first HCI command observed after that stream starts gets no response** (whether it
causes the wedge or discovers it is not established — `DR-03`). Alternate setting 1 has been
read from `sysfs` during five live wedges. `BRIEF.md` §1–§5 is the authoritative statement,
with every retraction; this file remains the register of the *distinct defects* and of what
each is worth reporting as.

What this update changes below, entry by entry:

- **BT-1** — the "experiment that settles it" (leave the wedged controller alone) has been
  run four times: 3 h 22 m (`EX-023`), 2 h 28 m (`EX-025`), 13 h 9 m (`EX-029`) and
  11 h 12 m (`EX-042`), every one with **zero** USB-layer lines. A natural USB collapse has
  never been observed; the canonical paragraph stands. Of the five candidate discriminants
  listed under "the leading discriminant", the fourth — the alternate-setting transition —
  together with the traffic that follows it is the one the seven instances share.
- **BT-3** — true of the kernels run here, no longer a candidate *cause*, and ⚠️ **closed
  upstream on 2026-08-07 by `dc16388d45ec`** (master; not in v7.0 or a stable line yet): it
  explained why nothing recovered the controller (`hdev->reset` NULL), not why it wedges.
  The setup/reset path that entry installs is untested here; `docs/missing-quirks-entry.md`
  keeps the argument whole.
- **BT-5** — superseded: `EX-043` shows the same link streaming for 9.65 s unharmed until a
  command is sent. The near-silence in `EX-009` was an idle link, not a precursor.
- **BT-7** (new) — the two `bluetoothd` crashes of `EX-032`, resolved to source and fixed
  in `patches/bluez/`; reportable now, and the only entry here with runtime evidence that
  its fix works.

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
                        observable USB errors --> device gone        still enumerated, USB layer
                                                                     SILENT, then WE ended it
                              (every case so far)                        (n = 2, both censored)
```

The right-hand branch has been walked twice — `EX-016` (72 min, ended by our `install.sh`
reloading btusb) and `EX-021` (30 m 36 s, ended by an operator rfkill toggle) — and never
to its end, so the arrow below it is missing on purpose. Whether one exists is the open
question in BT-1.

**`EX-021` is the sharpest instance and adds a timing that the graph cannot draw.** The
controller sat in the right-hand branch for 30 m 36 s with **not one bus-level line**, and
the USB collapse began **12.8 s after the operator's rfkill power-off attempt** — the
first thing to touch the device in that entire window. Across fifteen windows, a USB
collapse has never once begun before something touched the controller. That is not proof
of causation; it is the complete absence of the counterexample that would refute it.

### The six levels (0–5) a timestamp has to survive

Each level below was reached by getting the one before it wrong, in this repository, on
real data. (The section long said "five levels" while its own table held six rows —
level 0 was added last and sits beneath the rest; the heading now counts what the table
counts. Review 2026-08-15T1752Z §1.3.) They are listed because the failures are not obvious in advance and each one
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

**Status:** under investigation — the original bug, and the hardest. **Located** in the
transparent-SCO alternate-setting path since `EX-033`; see "Current state" above and
`BRIEF.md` §1. Mechanism open.
**Reportable:** ❌ not yet — a kernel-side report should come with a patch, or it asks the
maintainers to do the investigation (`bug-report.md`). The reproduction shape is exact: alt 1,
stream, issue a command.

The controller stops answering HCI commands. It has often been observed to stop answering
USB control transfers and leave the bus some time later, after which a cold power-off
recovers it.

> **Untested assumption, flagged rather than removed.** Everywhere this project says *"a
> warm reboot does not drop the M.2 power rail and will not recover it"* — the protocol's
> step 0, `bt-mode`, `install.sh`, `EX-005`, `docs/related-reports.md`, and
> `docs/investigation.md` §8 (which states it with a ✅, under that file's
> historical-chronology banner) — that is hardware
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
<!-- REVIEWED-KEEP 2026-08-15T1752Z §1.3: the paragraph above deliberately
     refuses to cite this register's own headline zero as re-verified until the
     reset-provenance re-capture lands. Do not "tidy" the hedge away. -->

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

**Status:** characterised; **covered upstream by `dc16388d45ec`**, whose message says that
without the entry "BLE scanning fails with HCI unexpected event opcode 0x2005 errors"
(`git show -s dc16388d45ec`). On E3: none in either `-38` boot
(`journalctl -k -b 0 --grep "unexpected event for opcode 0x2005"` and `-b -1`: "No entries",
2026-10-17).
**Reportable:** no longer separately (2026-10-17). It was rated "yes, independently, the easiest thing
here to report" before the upstream commit was found to name it.

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

## BT-3 — `13d3:3503` was absent from the btusb quirks table (added upstream 2026-08-07)

**Update 2026-09-19 (`DR-01`):** upstream commit `dc16388d45ec`, "Bluetooth: btusb: Add IMC
Networks QCA9377 to quirks table" (Tibor Harcsa; authored 2026-06-29, committed 2026-08-07),
adds `{ USB_DEVICE(0x13d3, 0x3503), .driver_info = BTUSB_QCA_ROME | BTUSB_WIDEBAND_SPEECH }`.
Its stated reason is a **BLE scanning failure**, not this fault. Present in master; absent
from `v7.0` (the running kernel's base) and from `linux-6.6.y` and `linux-6.12.y` as of
2026-09-19. Its descriptor dump lists alternate settings 1–5 (9/17/25/33/49 bytes), no 6 —
the same device shape observed here. A kernel carrying it runs `btusb_setup_qca()` and has
a reset callback; **neither has been tested on this machine**. Everything below describes
the kernels that were run.

**Status:** confirmed in upstream source and shipped binary (`EX-001`). **Since 2026-09-18
read as a consequence for recovery, not a candidate cause** — the wedge is located
elsewhere (see "Current state"), and this entry explains why no software recovers it.
**Reportable:** ⚠️ the patch is trivial and is **not proposed**: the reset it installs
drove the already-wedged device off the USB bus, recoverable only by removing power, in two controlled tests (`EX-023`, the 2026-08-15 boot).

The device is matched by no quirks entry, so it receives neither `hdev->reset` nor
`btusb_setup_qca()`. Its immediate ID neighbours `3491/3496/3501` carry
`BTUSB_QCA_ROME | BTUSB_WIDEBAND_SPEECH`; `3502/3503/3504` carry nothing.

This may be the cause of BT-1, or an unrelated omission that happens to be true. Adding the
ID is a three-line patch, but submitting it as a *fix* requires showing it fixes something
— which is what the A/B/C/D ladder exists to establish. See `docs/fix-proposal.md`.

Note the gap could also be deliberate: a silicon revision, a firmware architecture change,
or a vendor reason for omitting exactly those three IDs. Absence is suggestive, not proof.

<!-- REVIEWED-KEEP 2026-08-15T1752Z §1.3: BT-3 argues BOTH directions — the
     deliberate-omission alternative above and the unmeasured-sign caution
     below. Edits that trim either half turn this register entry into
     advocacy for the patch. -->

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

*(An earlier trailing paragraph repeated the "still needed before filing" list from
above and pointed at the reproducer as "below" when it is above — two generations of
this section imperfectly merged; removed, review 2026-08-15T1752Z §1.3. The filing
blockers are stated once, under "Minimal reproducer found".)*

---

## BT-5 — SCO link established, then carries almost no data

**Status:** **superseded 2026-09-18.** `EX-043` shows the same kind of link streaming 910
frames over 9.65 s with no command in flight (command-path health unmeasured); the silence recorded here was an
idle link, not a precursor. Kept for the record.
**Reportable:** ❌ no.

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

## BT-7 — `bluetoothd` dereferences NULL twice, at two sites, on this controller

**Status 2026-09-22: fixed upstream.** Both patches applied to BlueZ master on 2026-09-21 —
[`a734b0605`](https://git.kernel.org/pub/scm/bluetooth/bluez.git/commit/?id=a734b06059cbe0d0f00442c901506ef17e960960)
(adapter) and
[`0bed9886c`](https://git.kernel.org/pub/scm/bluetooth/bluez.git/commit/?id=0bed9886cff317d814f9b1f11c1461459f2b9a00)
(a2dp); no release tag carries them yet. Links to the mails, patchwork entries and the
bot's pull requests: `patches/bluez/README.md`, status table.

**Status (history):** resolved to source and fixed — `patches/bluez/0001` (`src/adapter.c`,
`start_discovery_complete()` reads the reply above its own length check) and `0002`
(`profiles/audio/a2dp.c`, `transport_cb()` passes a NULL `setup->stream` on). Crash sites
named from the stripped distro binary and confirmed against a retained core
(`reviews/2026-08-23T2340Z-ex032-crash-sites-resolved.md`); both defects present in BlueZ
master `c73fa2f9a`.
**Reportable:** ✅ **yes — the patches are the report** (BlueZ takes patches by mail and
needs no bug filed). `0002`'s guard has fired four times in 19 days of use (`EX-041`);
`0001`'s premise was logged five times with clients present and its guard has not fired; the 08-14 crash itself is reconstructed from the daemon log (`EX-041`, correction of 09-18).

Found only because this register separates the failure modes: a `bluetoothd` crash leaves
the adapter powered and never scanning again (`EX-032`), which to a user is "Bluetooth
stopped working" exactly as the controller wedge is. `tools/bt-crash` tells them apart.
Neither patch touches the controller fault; the wedge has occurred with both installed.

---

## BT-8 — Pending management commands flushed at power-off are answered with the wrong status

**Status 2026-10-03: fixed upstream.** `Bluetooth: MGMT: Fix status of pending commands
flushed on power off` is
[`86ef0f58bdec`](https://github.com/bluez/bluetooth-next/commit/86ef0f58bdecdedb3a1240971c56d71b7e4ce3fc)
on `bluetooth-next` (applied 2026-09-29 as sent; `Cc: stable`); not yet in a mainline release.

**What it is.** `cmd_complete_rsp()` falls through to `cmd_status_rsp(cmd, data)` for a
pending command without a completion callback, and that reads `data` as a `u8 *` — since
`f53e1c9c726d` the callers pass a `struct cmd_lookup`, so the status sent is the first byte
of the lookup's socket pointer, not the status the caller set. In `mgmt_index_removed()` and
`__mgmt_power_off()` that byte is `0x00`: Success, for a command the adapter never ran.

**How it was found.** This is the kernel-side source of the reply in BT-7's first site: a
Start Discovery pending when the adapter powered off was answered with Command Status
`0x00` and no parameters, and `bluetoothd` 5.72 crashed on the zero-length success
(`EX-032`, `EX-041`). BlueZ patch `0001` guards the daemon; this fix makes the kernel say
Not Powered. Reproduced and tested with a virtual controller (`hci_vhci`): power off held in
`Write Scan Enable` while a Start Discovery is submitted — status `0x00` before, `0x0f`
(Not Powered) after. Developed and reviewed on a private branch until sent; ported to
`main` on 2026-10-09: the patch, its review record and the reproducer in `patches/kernel/`,
`EX-044`, `EX-049`, `EX-050`, `tools/bt-ctrl-window`.

**Reportable:** ✅ sent 2026-09-24 and applied. Not specific to this controller.

---

## M-3 — `mgmt_unregister()` from a notification callback leaks, or frees the next node

**Status 2026-10-08: accepted.** Sent 05:41 +0200 (`patches/bluez/shared-mgmt/`, patchwork
14873331 / 14873330). Applied to BlueZ master the same day by Luiz Augusto von Dentz as
`ae23df052290` and `6f5eeb402d3b`. `git range-diff` against the sent commits shows both
identical (`=`). He then converted `unit/test-mgmt` to the tester framework (`866b0b8b1`);
the six unregister cases and their expected counts are unchanged there.

**What it is.** In BlueZ `src/shared/mgmt.c`, `mgmt_unregister()` took the entry off
`notify_list` with `queue_remove_if()` even while `process_notify()` was walking the list,
and only marked it removed; the walk's cleanup frees removed entries still on the list, so
this one leaked and its destroy callback never ran. Unregistering the *next* entry freed the
queue node `queue_foreach()` had already saved — a use-after-free, the same crash
`872729a91632` fixed for `mgmt_unregister_index()` in 2015.

**How it was found.** In the mesh work, the testers run under ASan report leaked
`mgmt_register()` allocations: 228 in mgmt-tester, 3 in mesh-tester, 2 in userchan-tester, all
0 with the fix, every tester verdict unchanged. A unit reproducer in `unit/test-mgmt` fails
without the fix (leak, use-after-free, wrong return value) and passes with it.

**Reportable:** ✅ sent 2026-10-08. `bluetoothd` does not reach the use-after-free (it
unregisters by index or all); the in-tree callers that leak are the testers. Not specific to
this controller.

---

## BT-9 — Simultaneous discovery can end without the kernel ever stopping it; every later scan is refused Busy

**Status 2026-10-09: already fixed upstream; missing from the 6.12, 6.6 and 6.1 stable
lines, which the `dc16388d45ec` backport is about to expose.** `EX-062`.

**Upstream.** Jiajia Liu found the same race on an Intel AX201 and fixed it: "Bluetooth:
hci_event: fix simultaneous discovery stuck in FINDING", mainline `96d006ae6445`
(2026-06-02, applied by Luiz Augusto von Dentz; `Fixes: 8ffde2a73f2c`, v6.1-rc1). The fix
sets `DISCOVERY_STOPPED` in the scan-off's Command Complete handler when inquiry has already
finished. It is in v7.2-rc1 and later, v7.1.5+ and v6.18.40+, and in Ubuntu's
`7.0.0-38` (changelog, "upstream stable patchset 2026-08-20"); it is **not** in v6.12.112,
v6.6.158, v6.1.189 or v7.0.14, which all have the racy code (checked with `git grep` at those
tags, 2026-10-09). 5.10 and 5.15 predate the race. In 6.12, 6.6 and 6.1 the upstream patch
does not apply as is (`hci_test_quirk()` does not exist there). The laptop's `7.0.0-34` has
the race; `-38` has the fix but not the 13d3:3503 entry. The same race is visible in the
capture attached to BlueZ issue #1554 (2025-09, open); a reply pointing to the fix was posted
there on 2026-10-09 (`docs/STATUS.md`).

**Why it matters here.** `dc16388d45ec`, whose stable backport this project requested, gives
13d3:3503 the quirk on 6.12, 6.6 and 6.1, where the fix is missing. On those lines the race is
already possible for adapters whose drivers set the quirk (among them Intel and Realtek),
whenever they run combined BR/EDR and LE discovery and the Inquiry Complete lands inside the
scan-off; how often that happens depends on timing (here: 2 cycles in about 14,700).

**Backport and test, 2026-10-10** ([`patches/kernel/bt9-stable/`](../patches/kernel/bt9-stable/README.md)):
`96d006ae6445` backported to v6.12.112, v6.6.158 and v6.1.189 (one adaptation: the quirk test).
A new `mgmt-tester` case forces the race deterministically in qemu, through the emulator and the
kernel's existing `quirk_simultaneous_discovery` debugfs switch: it fails with Busy on all three
lines and on bluetooth-next with the fix reverted, and passes with the fix and with each
backport; the normal-order control passes everywhere. **Stable request sent 2026-10-10 04:25
+0200** (three mails); the BlueZ emulator leak fix and the BlueZ test series sent to
linux-bluetooth 05:18 +0200, each its own submission (`docs/STATUS.md`). **Next:** replies.

**What it is.** With `HCI_QUIRK_SIMULTANEOUS_DISCOVERY`, a BR/EDR+LE discovery runs LE active
scanning and a 10.24 s Inquiry together, and arms the `le_scan_disable` timer for the same
10.24 s. Two paths end the cycle, and each one leaves `DISCOVERY_STOPPED` to the other in one
case:
- `le_scan_disable()` (`net/bluetooth/hci_sync.c`) queues the LE scan-off and, while
  `HCI_INQUIRY` is still set, returns without stopping: "BR/EDR inquiry will stop discovery
  when finished";
- `hci_inquiry_complete_evt()` (`net/bluetooth/hci_event.c`) does not stop while `HCI_LE_SCAN`
  is set — and that flag is cleared only by the scan-off's Command Complete.

When the Inquiry Complete arrives between the timer's scan-off command and that command's
Command Complete, neither path stops discovery. `start_discovery_internal()`
(`net/bluetooth/mgmt.c`) then answers every Start Discovery with Busy, without sending any HCI
command, until a system suspend or an adapter power-off resets the state. Restarting
`bluetoothd` does not clear it.

**How it was found.** On 2026-10-09 the Settings Bluetooth page showed no scanning spinner —
until now always a sign of a dead controller. The controller was healthy; the kernel had
refused every scan since 2026-10-04 10:26:11, where the timer's scan-off (10:26:11.625144)
went out 0.55 ms before the Inquiry Complete (.625697) and 2.6 ms before its own Command
Complete (.627698). The boot's traces show one earlier case, 2026-10-01 03:51:27, stuck for
8 h 18 min until a suspend cleared it, unnoticed. A call was up during the second cycle, not
the first, so it is not required. GNOME Settings and Chrome both kept getting "Operation
already in progress".

**Why only now.** The quirk comes with `BTUSB_QCA_ROME`, which `dc16388d45ec` gives this
device — build E3 on this laptop. Without it the device ran interleaved discovery, where the
timer starts the Inquiry instead of racing it. The race itself is in core code and applies to
every adapter that sets the quirk.

**Reportable:** no new report — fixed upstream; the contribution is the stable backport. Not
specific to this controller.

---

## U1–U10 — userspace audio problems seen during the E1/E3 tests (2026-09-26 →)

| id | one line | state (`STATUS.md`) |
|---|---|---|
| U1 | first codec/profile line unselectable in handsfree mode (GNOME Settings) | observed |
| U2 | volume display/route oddities after a profile switch | observed |
| U3 | profile priority comparison (WirePlumber, design) | observed, not a defect |
| U4 | GNOME codec row shows a profile/route mismatch | observed, lead weakened |
| U5 | handsfree picks CVSD over mSBC | withdrawn by the operator |
| U6 | input meter reads the headset monitor | confirmed; fixed upstream in GNOME 47 |
| U7 | PipeWire skips the SCO setup after a codec switch under an active link | confirmed on one device |
| U8 | earbuds silent in mSBC; `corrupted SCO packet` | observed |
| U9 | no reconnect after rfkill off/on (BlueZ policy) | confirmed, by design |
| U10 | Tronsmart T8 silent on SBC-XQ, audible on SBC (2026-10-11) | observed; the deciding question is open |
| U11 | a newly connected headset does not become the output (2026-10-13) | confirmed in the log and the source; by design |
| U12 | a microphone opened while A2DP is starting loses A2DP; only Handsfree remains (2026-10-19) | confirmed in the capture, the logs and the source; fixed upstream in BlueZ 5.80 |
| U13 | a headset known only from its LE advertising cannot be set up: every click pairs over LE, the headset refuses, GNOME shows nothing (2026-10-21) | confirmed in the capture, the log and the source; not fixed upstream |
| U14 | a Bluetooth headset is forced into Handsfree while an application records from any microphone, and a manual return to A2DP is undone when the recording ends (2026-10-21) | confirmed in the log and the source (WirePlumber 0.4.17); fixed upstream by the 0.5 rewrite |
| U15 | the MOMENTUM 4 says "mute on" at every hands-free start: it reports a microphone gain of 0 at connect, and PipeWire sends that 0 back as `+VGM: 0` (2026-10-23) | mechanism confirmed in the log, the capture and the state; no upstream quirk entry for this headset |
| U16 | after a failed Connect from GNOME Settings, its device search stops for good: the "searching" spinner is gone and no new device appears until Bluetooth is switched off and on (2026-10-23; same pattern 2026-10-11) | confirmed in the bluetoothd debug log, the system bus record and the source (BlueZ 5.72); not fixed in BlueZ master, no duplicate found |
| U17 | after an HFP codec switch whose SCO connect is refused (the CO-02 kernel), the headset is silent for 5 s: PipeWire's retries are immediate and all fail, and only WirePlumber's 5 s idle-suspend of the failed node starts the audio again (2026-10-24) | confirmed in the logs, the HCI capture and the source; not fixed in PipeWire or WirePlumber master, no duplicate found |
| U18 | a headset paired over LE shows "Connected" in GNOME Settings with no audio: Connect resolves its BR/EDR services, then answers success without connecting any, because a connected LE service (GAP, Battery) counts as "one connected" (2026-10-24, Shure AONIC 50) | confirmed in the bluetoothd debug log, the system bus record, the HCI capture and the source (BlueZ 5.72; master the same) |
| U19 | after a headset leaves Handsfree for A2DP, GNOME Settings' Sound panel shows the laptop's microphone as the input but its level meter stays dead: the meter's new stream is destroyed by Ubuntu's 2-second Bluetooth-transition patch in WirePlumber, and the panel never retries (2026-10-24, Shure AONIC 50, twice) | confirmed in the journal, the audio policy log and the source; Ubuntu-only (LP #2122640's patch), upstream WirePlumber not affected |
| U20 | in Handsfree the Shure AONIC 50's input volume slider has no effect on the signal: PipeWire sends `+VGM` 15…0 because the headset announced remote volume control, and the level does not change (2026-10-24) | observed by the operator, the `+VGM` commands confirmed in the HCI capture; headset behaviour inferred |

The entries below appear in the order they were written (U6 before U5, U9 before U8).

**Status:** leads, not findings. Each item mixes what was **measured** with what the operator
**reported** from the UI or by ear; every statement below carries its source:
**[log]** — read from `wpctl`/`pw-cli`, the kernel log or sysfs at the time;
**[operator]** — the operator's account, not independently confirmed;
**[inference]** — reasoning from the two, to be tested.
**Reportable:** only after the [operator] parts are confirmed — to PipeWire/WirePlumber or
GNOME Settings, **not** as kernel or controller defects: the SCO links of that session were
all set up and hung up cleanly **[log]** (`EX-056`).

**Automatic record since 2026-09-26 23:02:** `scripts/bt-audio-policy.py` logs every change of
profile vs routes (`MATCH`/`MISMATCH`), default sink/source, volumes/mute and capture
streams to the journal (`journalctl -u bt-audio-policy`) — the [log] side of U1–U5 now
accumulates from ordinary use; the operator marks a UI moment with `bt-mark`.
Snapshot commands (as the desktop user): `wpctl status`; `wpctl inspect @DEFAULT_AUDIO_SOURCE@`;
`pw-cli enum-params <device-id> EnumProfile` and `… Profile`. PipeWire 1.0.5, WirePlumber
0.4.17, GNOME Settings 46.7, BlueZ 5.72 (Ubuntu 24.04 packages, `dpkg-query`; corrected
2026-09-26 — an earlier line said WirePlumber 1.0.5). Headset: `MOMENTUM 4` as the node name **[log]**
(Sennheiser **[operator]**).

- **U1 — the plain "Headset Head Unit (HSP/HFP)" entry.**
  **[log]** PipeWire offers a generic `headset-head-unit` profile (index 3) beside
  `headset-head-unit-cvsd` (260) and `-msbc` (261); at 22:07 the kernel log shows five SCO
  links torn down and set up again within 20 s, all answered.
  **[operator]** selected for output it gives no sound; selected from the input side it does
  not stick and falls back to a codec-specific entry.
  **[inference]** the generic entry is an automatic choice that resolves to CVSD/mSBC, offered
  by the UI as if selectable. **To confirm:** the minute of one output-side attempt, then
  whether any `opcode 0x0428` appears at that minute.
- **U2 — "mute on" after switching to handsfree.**
  **[log]** at 22:04 the headset's handsfree source was at volume **0.00**; at a later check
  the same evening (after 22:07, exact time not recorded) it read 0.27.
  **[operator]** the headset announced "mute on".
  **[inference]** HFP carries source volume to the headset as microphone gain, and gain 0 is
  announced as mute. **To confirm:** the RFCOMM `AT+VGM` value in the capture at the switch.
  **[log] 22:55:59:** source volume **0.08** (`wpctl get-volume`), **not muted** (no
  `[MUTED]`; route `mute` false), route linear volume 0.000482 — so the volume moved
  0.00 → 0.27 → 0.08 over the evening **with no recorded user action** for the last two.
  **[screenshot]** the panel draws a crossed microphone at that level — it reads as muted
  while the stream is not. **[inference]** something other than the user sets it —
  possibly the headset reporting its microphone gain over HFP (`+VGM`); the capture can say.
- **U3 — calls use the laptop's internal microphone.**
  **[log]** at 22:04 WirePlumber's *configured* default source was the internal analog input,
  and Chrome played to the headset in handsfree mode while its input stream read the internal
  microphone (`SN6140 Analog`). Later the configured default was the headset input
  (`bluez_input…`, codec `msbc`), and a GNOME Settings capture stream was active from the
  headset source — so choosing it in the UI rewrites the saved default, and the headset
  source carries a live stream.
  **[operator]** the headset microphone picks up sound (level meter moving).
  **[inference]** a default-policy problem, not a broken microphone: the saved choice
  outranks the newly connected headset. Not measured: whether the stream carries sound rather
  than silence (that needs a short recording — only with the operator's consent).
  **Proposed report (operator's position, 2026-09-26):** selecting a handsfree device should
  make its microphone the input too — that is what the user is choosing, and what phones do;
  keeping the laptop's internal microphone is counterintuitive, whatever the reason for it.
  **[log]** the headset source carries `priority.session` 2010 and the internal microphone
  (`alsa_input…analog-stereo`) 2009 (`wpctl inspect`, 2026-09-26) — the headset ranks higher,
  yet the saved *configured* default wins. **Before filing:** search
  WirePlumber's tracker for the existing discussion and any setting (the behaviour may be
  deliberate), and confirm the [operator] part above with a measured recording; target
  WirePlumber, with GNOME Settings as a possible second party (it writes the saved default).
- **U4 — the Codec ("Configuration") dropdown disappears from GNOME Settings.**
  **[log]** at 22:04:36 PipeWire offered all eight profiles for the device (off, three
  handsfree, four A2DP), all available, active `headset-head-unit-cvsd`.
  **[operator]** at that moment the dropdown was missing, and it returns after switching the
  output device away and back.
  **[inference]** GNOME Settings does not refresh its profile list; the data was there.
  **Second capture, 22:55:59.** **[screenshot]** (`tmp/ui-screenshots/2026-09-26T2255-…png`,
  local, sha256 `b08cab16…`): output and input both "Handsfree — MOMENTUM 4", **no
  Configuration row**, input slider at the far left with a crossed microphone icon.
  **[log]** at that moment: all eight profiles offered and available; active profile
  `headset-head-unit-msbc` (index **261**), `save` true; but both active **routes**
  (`headset-hf-input`, `headset-hf-output`, `pw-cli enum-params <dev> Route`) report
  `profile` **3** — the plain `headset-head-unit` entry — with `profiles` [3, 260, 261].
  **[inference]** the panel may hide the Configuration row when the active profile (261)
  differs from the profile its active port claims (3); the same mismatch may be why the plain
  entry "does not stick" (U1). Sharper than "does not refresh", still to be confirmed in the
  panel's source (libgnome-volume-control / the PulseAudio-compatibility layer).
  ⚠️ **Weakened, 23:10:** `bt-audio-policy.py` shows the same kind of mismatch in **A2DP** mode
  too (active `a2dp-sink#10`, route claims #2) — routes appear to name the base profile of a
  codec variant as a rule. So the mismatch is probably PipeWire's normal representation, not
  the cause; U4 stays "panel does not refresh" until the recorder shows a state that differs
  at the moments the dropdown is missing (mark them with `bt-mark`).
  **2026-10-21, a new trigger (Shure AONIC 50):** **[operator]** 07:14, no Configuration row
  for the Shure. **[log]** Since 06:48:03 every profile change was WirePlumber's own (`U14`'s
  auto-switch and its "restores": 06:48:03, 06:49:37, 07:00:09, 07:08:17), each
  `setting profile 3 codec:257` (the plain `headset-head-unit` index with mSBC as a codec
  parameter); earlier, after the operator picked the mSBC entry in GNOME Settings itself, the row
  showed "mSBC". Consistent with the panel not refreshing when the profile is changed behind it
  (`cc_profile_combo_box_set_device()` returns early for an unchanged device, GNOME 46.7
  `cc-profile-combo-box.c:96`, `CO-17`); not yet shown that this is the only cause.
- **U6 — GNOME Settings' input level meter shows nothing for the internal microphone.**
  **[operator]** 23:10: internal microphone selected in the panel, loud sounds, the input
  level indicator does not move; with the headset's handsfree microphone it does.
  **[log]** 23:10:17 (`bt-audio-policy.py --once`): the headset in A2DP (no microphone); the
  *actual* default source is the internal microphone (volume 0.53, not muted) while the
  *configured* one is still the headset input, which does not exist in A2DP; the **only**
  capture stream GNOME Settings holds reads **"monitor of MOMENTUM 4"** — the headset's
  output monitor, not the internal microphone. ALSA mixer (`amixer -c 1 contents`): `Capture
  Switch` on, `Capture Volume` 80/80, `Internal Mic Boost` 3/3.
  **[inference]** the meter is attached to the wrong node: after the switch the panel keeps
  a stream on the headset's monitor and never opens one on the new default source, so it
  cannot show the internal microphone. Not measured: that the internal microphone carries
  sound (needs a short recording, only with consent).
  **[source, 2026-10-03]** located upstream: in GNOME Settings 46.7 the input meter's stream
  is re-targeted from gvc's active-input signal only while the slider holds no stream
  (`panels/sound/cc-sound-panel.c`, `input_device_update_cb`), so once it held the headset's
  handsfree source it is never moved to the internal microphone; and the single capture
  stream the recorder saw is most plausibly the *output* meter on the headset's sink monitor,
  with the input meter holding nothing. Fixed upstream by the 2024-03-07 series
  `215289935`, `a74bc5a84`, `bf6f72278`, `afec106a8`, `3aeb837cb` plus `0da10f03a` (all
  `panels/sound/`, first release 47.0; 46.7 and 47.0 ship the same gvc); not in any Ubuntu
  24.04 revision through `1:46.7-0ubuntu0.24.04.6`. Full check with commands:
  [`userspace-upstream-check-2026-10-03.md`](userspace-upstream-check-2026-10-03.md). Next: one
  recorder reading with the panel open (one capture stream predicted on 46.7, two on 47),
  then a Launchpad SRU request quoting the six commits.
- **U5 — switching to handsfree picks the lowest-quality codec** *(first impression;
  withdrawn by the operator the same evening — see the correction below)*.
  **[log]** PipeWire ranks the handsfree profiles `headset-head-unit` 1, `-cvsd` 2, `-msbc` 3
  (`EnumProfile` priorities). At 22:04:36 the active profile was `headset-head-unit-cvsd`
  with `save` **false**; at a later reading, after the operator chose mSBC, it was
  `headset-head-unit-msbc` with `save` **true**. CVSD is narrowband (8 kHz) and mSBC
  wideband (16 kHz) by the HFP specification.
  **[operator]** selecting handsfree in the UI lands on CVSD, and the sound is very poor.
  ⚠️ **Operator's correction, 22:28 the same evening:** after switching handsfree ↔ headset
  several more times, *"it seems like the better codec is being selected"* — the operator
  withdrew the first impression and asked for it to be recorded, as the reason reports need
  logs. **[log]** 22:21–22:26: 15 SCO links, 10 mSBC (`evt 5`) and 5 CVSD (`evt 4`) — the log
  cannot tell automatic choices from explicit picks; active afterwards: `-msbc`, `save` true.
  **[log] the mechanism** — WirePlumber's state (`~/.local/state/wireplumber/`, read-only):
  `policy-bluetooth` keeps a per-device `saved-headset-profile`, and `default-profile` the
  device's profile; for this headset both read `headset-head-unit-msbc` at 22:28 (other
  paired devices: `-msbc` for most, `-cvsd` for one, `a2dp-sink` for several). A handsfree
  switch restores the profile last used on that device.
  **[inference] revised:** not "handsfree picks the worst codec" but "handsfree picks what
  was last used on this device"; the CVSD at 22:04 was presumably that device's saved choice
  at the time (the files keep no history). **Open, and the only reportable part:** what the
  policy picks for a device with **no** saved profile — needs a device never switched to
  handsfree before, or its saved entry removed (operator's decision: it changes saved
  preferences), then one switch and the log.

- **U7 — after an HFP codec switch made while a SCO link is up, no new SCO link is set up
  (silence in the new codec).** Found 2026-09-29 with Lenovo `联想thinkplus-GM2 pro` earbuds
  under E1; the operator's report was "Test sound does not play".
  **[log]** the sound stream exists and is routed: `bt-audio-policy` logs
  `playback-node[gnome-control-center]: Mono target=- role=Test` and
  `playback[gnome-control-center]: 联想thinkplus-GM2 pro` at 02:30:40, :47, 02:31:03, :14, :38.
  **[log]** the HCI capture (`scripts/capture-window.sh <capture> "2026-09-29 02:30:40"
  "2026-09-29 02:31:45" 'RFCOMM|[+]BCS|Synchronous|Disconnect'`), three codec switches in a row:

  | time | switch | SCO up at the time? | RFCOMM | HCI |
  |---|---|---|---|---|
  | 02:30:44.995 | mSBC → CVSD | **yes** (mSBC handle 19) | `+BCS: 1` → `AT+BCS=1` → `OK` → `+CIEV: 2,1` → `+VGS`/`+VGM` (twice, 1.5 s apart) | **`Disconnect` of handle 19, then no `Setup Synchronous Connection` at all** |
  | 02:30:59.743 | CVSD → mSBC | no | `+BCS: 2` → `AT+BCS=2` → `OK` → `+CIEV: 2,1` | `Setup Synchronous Connection` 30 ms after `OK` → eSCO **Transparent**, handle 20 |
  | 02:31:12.238 | mSBC → CVSD | **yes** (handle 20) | as the first | **`Disconnect`, then nothing** |

  and the reference switch at 02:27:32 (mSBC → CVSD with **no** SCO up, the previous link having
  ended at 02:26:55): `+BCS: 1` → `AT+BCS=1` → `OK` → `+CIEV: 2,1` → `Setup Synchronous
  Connection` at +30 ms → eSCO **CVSD** handle 18, 171 s of audio.
  **[log]** the kernel's SCO socket debug is off (`sco.c` has no `=p` in
  `dynamic_debug/control`), so the absence of a `connect()` attempt is read from the HCI
  capture, not the kernel log. **[operator]** the mono test sound was heard in CVSD at ~02:27:3x
  (link 18 up) and not at 02:30:47 / 02:31:14 / 02:31:38 (no link).
  **[inference]** PipeWire 1.0.5's native HFP backend sets the new SCO up as part of the codec
  switch (30 ms after the headset's `OK`), and skips that step when the switch had to tear an
  existing SCO down first — the disconnect and the negotiation overlap (`Disconnect` completes
  between `+BCS:` and `AT+BCS=`). A later acquire by a stream does not recover it: the test
  stream and the panel's meter both linked and no setup followed. **Not a controller or kernel
  defect**: no HCI command was issued for it to fail.
  ⚠️ **Corrected 2026-10-21:** the sentence above is wrong about the kernel. The kernel is what
  issues no command. `hci_connect_sco()` hands a new connect the old eSCO connection while its
  Disconnect is pending (that connection stays `BT_CONNECTED` until the Disconnection Complete),
  sends no setup, and `sco_connect()` marks the new socket connected at once; the completion then
  closes it with `ECONNABORTED`, and PipeWire 1.0.5 does not retry. Source reading by four outside
  reviewers, checked here: `reviews/2026-10-21T0033Z-source-investigation-reviewers-2-4.md`, RV1;
  the work: `contributions/CO-02-sco-connect-reuses-closing-link/`. Still to be shown by a
  reproducer. **To confirm:** with the Sound panel
  closed (its meter keeps the SCO up), switch codec by `pactl set-card-profile` once with the
  SCO idle and once while a stream plays; and read PipeWire master's `backend-native.c` codec
  switch path (`rfcomm_hfp_ag_set_codec` and what follows `AT+BCS`) for a fix after 1.0.5.
  Reportable to PipeWire once confirmed, with this capture excerpt.
  **[log] 2026-10-01, E3 boot, MOMENTUM 4:** two mSBC → CVSD switches made with the mSBC link
  up (00:54:45, 00:55:27) both got their CVSD link within 0.2 s (`sco-ledger.sh 0`). So the
  skipped setup is **not** universal; on the earbuds the headset's `AT+BCS=` reply arrived
  after the old link's `Disconnect` had completed — the MOMENTUM's ordering at those two
  switches is the comparison to read next (`capture-window.sh`). Device-dependent timing in
  PipeWire's switch path, still a PipeWire matter.
  **[log] 2026-10-03 — the comparison, read from the retained captures (`EX-060`,
  `scripts/sco-switch-windows.sh`).** The "`Disconnect` completes between `+BCS:` and
  `AT+BCS=`" above was the *Command Status* of the Disconnect; the *Disconnection Complete
  event*, which is when the old link is actually gone, comes much later on the earbuds:

  | switch | `Disconnect` status | headset `AT+BCS=` | AG `OK` | old link's Disconnection Complete | `Setup Synchronous Connection` |
  |---|---|---|---|---|---|
  | earbuds 02:30:44.996 | +2 ms | **+16 ms** | +17 ms | **+177 ms** (handle 19) | none |
  | earbuds 02:31:12.238 | +3 ms | **+30 ms** | +30 ms | **+205 ms** (handle 20) | none |
  | MOMENTUM 00:54:45.331 | +5 ms | +67 ms | +67 ms | **+39 ms** (handle 3) | +91 ms (24 ms after `OK`) |
  | MOMENTUM 00:55:27.444 | +5 ms | +75 ms | +75 ms | **+46 ms** (handle 7) | +101 ms (26 ms after `OK`) |

  So the one thing that separates failure from success is whether the old link's
  Disconnection Complete has arrived **before** the headset answers: the MOMENTUM takes
  ~70 ms to reply and its link is gone in ~40 ms; the earbuds reply in 16–30 ms and their link
  takes ~200 ms to go. PipeWire's new node is acquired, and its SCO `connect()` issued, about
  25–30 ms after `OK` in the working cases — on the earbuds that moment falls **inside** the
  old link's teardown, and no `Setup Synchronous Connection` ever follows.
  **[inference]** the earlier reading "PipeWire skips the setup" was wrong in mechanism: PipeWire
  does the same thing every time (free the old transport, create the new one, let the first
  acquiring node call `connect()`); what differs is that on the earbuds that `connect()` is
  issued for a peer whose previous SCO link is still being torn down, and nothing retries once
  the teardown completes. PipeWire master (`702a11de5`, 2026-09-28) keeps the same design; no
  commit since 1.0.5 addresses it, and the nearest tracker item (#5467, fixed 2026-09-30) is a
  different mechanism ([`userspace-upstream-check-2026-10-03.md`](userspace-upstream-check-2026-10-03.md)
  §U7). Reportable to PipeWire now, with this table and the exhibit: a connect issued during
  the previous link's teardown is never retried. How the host handles a SCO connect that
  overlaps the previous link's teardown is examined separately before anything is said about it.
- **U9 — after Bluetooth off → on, the headset is not reconnected.** Marked by the operator
  01:02:31 ("the headset is on my head, why not connect to it?").
  **[log]** 01:00:03 rfkill soft-block (`RFKILL event … soft 1`), the MOMENTUM disconnected
  with `reason 21`, `plugins/policy.c:disconnect_cb() reason 21`; 01:00:06 unblock and `Set
  Powered`; no connection attempt by anyone in the next 2.5 min (`bluetoothd` log,
  `bt-audio-policy`: no device). **[log]** BlueZ 5.72 `plugins/policy.c:743` reconnects only
  for `MGMT_DEV_DISCONN_TIMEOUT` and `LOCAL_HOST_SUSPEND` (link loss and system suspend); a
  disconnect caused by the local adapter being switched off is not one of them, and nothing in
  BlueZ or the desktop connects known audio devices when the adapter comes back.
  **[inference]** a policy gap, not a fault: phones reconnect the last audio device when
  Bluetooth is re-enabled; BlueZ leaves it to the headset, which did not page us. Possible
  suggestion to BlueZ (policy plugin: on power-on, attempt the devices that were connected at
  power-off) — check the tracker first for a prior decision.
- **U4/U1, operator marks 2026-10-01:** 00:25:51 "the Configuration line disappears for a
  moment when you change the selection" — consistent with U4's mechanism (the row is hidden
  while the combo row's device object is swapped, then re-evaluated). 00:59:41 "three lines in
  the dropbox, the first not selectable" — U1 as shipped in PipeWire 1.0.5 (the codecless entry;
  removed upstream in 1.2). Both [operator], both explained by the source already read.
- **U8 — mSBC on the Lenovo earbuds: link up, data flowing, nothing audible** *(lead)*.
  **[log]** at 02:30:40 and 02:31:03 the test stream was linked to the earbuds' sink while an
  mSBC (Transparent) eSCO link was up and carrying host TX (`len 27 mtu 9` buffers: 5,761 on
  link 02:30:27, 4,211 on 02:30:59) and RX; the kernel logged `corrupted SCO packet` ×6 during
  the earbuds' mSBC links and once at teardown of handle 20; the same message appeared on the
  first E1 boot with the MOMENTUM (21:53:23, an mSBC link) and not on the last stock boot (whose
  mSBC links lived under 10 s). **[operator]** nothing heard in mSBC; CVSD (when its link exists)
  audible. **[inference]** either the earbuds do not decode what this host sends over alt 1
  (framing / the 3×9-byte split), or the corrupted-packet path drops the RX side; the two are
  separable by whether the *microphone* side works in mSBC. **To confirm:** the MOMENTUM's test
  sound in mSBC on this boot (if audible there, U8 is earbud-specific); then E3 with both.
  **[operator] 2026-10-01, E3 boot, MOMENTUM 4:** "all checked modes are audible now, in both
  headset and handsfree modes" (A2DP; handsfree mSBC and CVSD) — the only exception being U1's
  unselectable first line. **[log]** the same session: 7 SCO links (2 mSBC, 5 CVSD), 7 hang-ups
  answered, 0 timeouts, and no `0x2005` or `tx timeout` on the boot; no `corrupted SCO packet`
  during the MOMENTUM session — one appeared later that boot during a Shure mSBC link
  (03:01:19, `EX-057`), so the message is not earbud-specific either.
  So mSBC audio on this host is fine with the MOMENTUM under the exact upstream entry; U8 is
  earbud-specific unless the earbuds also go silent on E3 — that test is next.
- **U10 — Tronsmart T8 silent on SBC-XQ, audible on plain SBC** *(observed, 2026-10-11)*.

  **What was seen and sent:**
  - **[operator]** 2026-10-11 around 00:35: choosing SBC-XQ in GNOME Settings silences the speaker, and switching back to SBC brings sound back.
  - **[log]** BlueZ's cached endpoint record for the T8 lists three SBC endpoints and no other codec. Each takes every channel mode, Dual Channel included, at bitpool 2 to 53.
  - **[log]** Both configurations are accepted and stream: Set Configuration, Open and Start are all answered with accept.
    - Plain SBC: 48 kHz joint stereo at bitpool 53, 119-byte frames, 357 kb/s.
    - SBC-XQ: 48 kHz Dual Channel at bitpool 39, 168-byte frames, 504 kb/s.

    So the speaker neither refuses the configuration nor fails to start the stream.
  - **[log]** `scripts/sbc-frame-levels.py` reads each SBC frame's scale factors in the captures. A frame with all of them zero is encoded silence.
    - Real signal was sent only during the Settings test sounds. On SBC-XQ that includes 00:34:43 to 00:34:47, 00:35:04 to 00:35:08 and 00:38:51 to 00:38:54 (858 Dual Channel frames).
    - Chrome's playback carried only encoded silence, both on SBC (00:40:19 to 00:50:20) and on SBC-XQ (00:51:56 to 00:52:29).

    So Chrome's audio never reached the link. Only the test sounds can decide the question.

  **Why SBC-XQ is offered at all:**
  - **[log]** The speaker advertises Dual Channel and bitpool 53, and PipeWire builds SBC-XQ from exactly those two. BlueZ passes the capabilities through, and the desktop shows what PipeWire offers.
  - **[log]** This is not new to the project. `EX-030` (2026-08-17), an A2DP dropout on the same speaker, has bluetoothd configuring the `sbc_xq` endpoint.

  **Readings:**
  - **[inference]** If the SBC-XQ test sounds were silent, the speaker accepts a configuration it cannot play. Either Dual Channel or 504 kb/s is the limit; a forum report of a Windows driver going silent above about 354 kb/s (relayed by an outside reviewer, not checked here) points at the rate.
  - **[inference]** Bluetooth audio has no feedback path, so the host cannot notice either way. PipeWire's per-device quirk list (`no-features = [ sbc-xq ]` in `bluez-hardware.conf`) is how such devices are handled today.
  - An outside reviewer's investigation (2026-10-11) proposed the same decoder limit. Its claim that the T8 offers AAC is not supported by this unit's cached record.

  **Next:**
  1. The operator plays only the Settings test sound on each mode, with a `bt-mark` after each.
  2. Separate Dual Channel from the bitrate: Dual at a low bitpool, joint stereo at a high one.
  3. Read PipeWire's decision path: when it offers SBC-XQ, who added it and why, and how the quirk entries came in.

  **Evidence:** HCI captures `bt-20261011-001745` to `bt-20261011-004946`, kept in `archive/bt-trace/` (git-ignored; real addresses inside).

- **U11 — a headset that has just connected does not get the sound** *(confirmed in the log and the source, 2026-10-13; by design)*.

  **What happened:**
  - **[operator]** Shortly before 01:07 on 2026-10-13, the operator switched the MOMENTUM 4 off and the Shure AONIC 50 on. The AONIC 50 connected, but the sound stayed on the laptop. GNOME Settings showed it connected, not selected.
  - **[operator] The position:** connecting a headset means you want the sound there. You should not need to remember settings for it. Anything else is counterintuitive, whatever its reason. The operator has met this many times, and it is an annoyance every time.

  **[log] The timeline,** from WirePlumber's own debug log in the desktop user's journal (WirePlumber 0.4.17). Node names are written with the device name in place of the address.
  - **00:53:44:** the MOMENTUM 4 connects. At 00:53:48 it gets `a2dp-sink`. From 00:54:26 every stream gets `default target picked: bluez_output.<MOMENTUM 4>.1`.
  - **01:01:00.89:** the MOMENTUM 4 disconnects. From 01:01:00.686 the picks read `default target picked: alsa_output.pci-0000_03_00.6.analog-stereo (52)`, the laptop's own output.
  - **01:01:56:** the AONIC 50 connects. It drops at 01:01:58 and connects again at 01:02:04.26.
  - **01:02:04.79:** `Setting profile a2dp-sink on bluez_card.<AONIC 50>` (LDAC), and the node `bluez_output.<AONIC 50>.1` is created. So the Bluetooth side worked: the output existed.
  - **01:02:09 to 01:06:58:** every stream picks the laptop's output: GNOME Settings at 01:02:09 and 01:02:10, Mutter at 01:02:52, Chrome at 01:03:30 and 01:06:53.
  - **No explicit choice was made tonight.** This boot's journal holds a single `SET_DEFAULT_SINK`: GNOME Settings choosing the MOMENTUM 4 on 10-11 at 16:31:06, 3 s after Settings opened. It has no stream move at all. WirePlumber's state file `~/.local/state/wireplumber/default-nodes` was last written on 10-11 at 16:31:07.

  **[source] The rule.** WirePlumber 0.4.17, `modules/module-default-nodes.c`, `find_best_media_class_node()`. Each available output scores its `priority.session`, plus a bonus:
  - **+340,000** (`20000 * (N_PREV_CONFIGS + 1)`) if it is the configured default;
  - otherwise **+(16 − i) × 20,000** if it is at position *i* in the stack of earlier choices (`N_PREV_CONFIGS` 16).

  A newly connected output gets nothing for being new.

  **[log] The stack in the state file:** the configured default and position 0 are the MOMENTUM 4; position 1 is the laptop's output; position 2 is another Bluetooth output; position 3 is the AONIC 50; seven more follow.
  - With the MOMENTUM 4 gone, the laptop's output scores +300,000 and the AONIC 50 +260,000.
  - Session priorities are in the low thousands: U3 measured the two sources at 2010 and 2009. The two sinks were not measured tonight. A 40,000 gap decides either way.
  - **Positive control, in the same log:** the MOMENTUM 4 did become the output at 00:54, because it was the configured default.

  **Whose decision.** WirePlumber's, made on purpose.
  - Commit `7a1b48b7` (Pauli Virtanen, 2022-07-11), "prioritize previous configured defaults", gives the reason: "The node priorities are difficult to configure for users, and are not necessarily meaningful for them."
  - Master (local tree of 2026-09-25, `src/scripts/default-nodes/state-default-nodes.lua`) keeps the rule and makes it stricter: "the position in the stack alone decides; priority.session is deliberately left out so that it cannot override the user's history". The setting `node.restore-default-targets` turns the whole history off; it does not make a new device win.
  - **What the operator expected exists, but is off.** PipeWire's PulseAudio-compatible `module-switch-on-connect` (Pauli Virtanen, 2021-07-23; in 1.0.5) sets every newly connected non-internal output or input as the configured default. Ubuntu ships it commented out: `/usr/share/pipewire/pipewire-pulse.conf` line 65. Its own description calls it a compatibility module, needed "only when some applications try to manage the default sinks/sources themselves".

  **Readings:**
  - **[inference]** The laptop's output ranks above the AONIC 50 because it was chosen after the AONIC 50's last choice. When that happened, and whether by hand, is before this boot and not on record.
  - **[inference]** This is U3's rule (the microphone side), now on the output side, with the source and the numbers. U3's proposed report (2026-09-26) is the same position: choosing or connecting a headset should move the sound to it.
  - **Side observation [log]:** the AONIC 50 connected, dropped after 3 s, and connected again (01:01:56, 01:01:58, 01:02:04). Not read further.

  **Not recorded:** `bt-audio-policy` and `bt-ui-atspi` have been down since the 10-11 reboot. So there is no per-change policy line, and the UI clicks are not on record. WirePlumber's debug log carries the decisions.

  **Update, 2026-10-13, after the outside research** (checked claim by claim in `reviews/2026-10-13T0200Z-u11-outside-research.md`):
  - **[log]** At 01:11:04 GNOME Settings set the AONIC 50 as the output (`SET_DEFAULT_SINK tag:30`). It is now at the top of the stack, so the next MOMENTUM 4 to AONIC 50 change will not repeat U11. A reproduction starts by copying the state file.
  - **[source]** A fallback is not saved as a choice. In 0.4.17 the stack changes only when a client writes `default.configured.audio.*`. WirePlumber's own fallback writes `default.audio.sink`, which leaves the stack alone. So the laptop's place above the AONIC 50 comes from an earlier explicit write. What the stack lacks is "this device was just connected".
  - **[log]** When that earlier write happened cannot be found: `SET_DEFAULT_SINK` has been logged only since the 10-11 reboot, and the 60 archived boots have none. The last archived boot has 4,517 audio-stack lines and no `protocol-pulse` lines, which is the control.
  - **[source] The upstream record** (official tracker, quotes in `reviews/2026-10-13T0200Z-u11-outside-research-web-sources.md`):
    - #352 (2022, closed as intended): a maintainer said "wireplumber prefers to stick to your selection", and "We have changed this behaviour back and forth in the past because some people want it this way and some others don't."
    - #1005, MR !902 and `481ecff`, then #1036: in 0.5.18, "When the current default goes away, it falls back to the most recent one in that list that's still available."
    - #914 is open, with no maintainer comment: a panel selection "permanently overrides" priorities.
    - #83, #221, #463, #629 and #840 complain the other way, about unwanted automatic switches.
  - KDE's "switch on connect by default" (bug 392103) ended RESOLVED WONTFIX in 2025.
  - **[log] BlueZ side, read while drafting** (`journalctl -u bluetooth.service --since "2026-10-13 00:53:00" --until "2026-10-13 01:03:00" -g <both addresses>`):
    - The AONIC 50 was already connected before 00:53. It disconnected at 00:54:08.852 with reason 3 (remote), i.e. switched off after the MOMENTUM 4 connected at 00:53:44. WirePlumber's `Setting profile a2dp-sink on bluez_card.<AONIC 50>` at 00:54:08.359 belongs to that disconnect.
    - At 01:01:58.979 the new link dropped with reason 2 (local host), logged twice.
    - At 01:02:03.395, `connect_profiles() … (all), client :1.347`: a D-Bus client asked for the connection that succeeded at 01:02:04.26. Which client (a click in GNOME's Bluetooth menu, or automatic) is not recorded.
  - **Draft suggestion** (opt-in "a newly connected device becomes the default"; not posted): `patches/wireplumber/2026-10-13-suggestion-default-follows-new-device.md`.

  **Next:**
  1. ~~Search WirePlumber's tracker.~~ Done (above). A proposal has to be opt-in, and has to say how it avoids the unwanted-switch cases.
  2. Decide the proposal with the operator, for example: a device that connects ranks first until the user chooses something else after it.
  3. Whether to enable `module-switch-on-connect` on this laptop is the operator's choice. It would make every new non-internal device take over, inputs included.

  **Evidence:** the desktop user's journal for this boot (WirePlumber at debug level), kept by `bt-journal-backup`; the state file read on 2026-10-13. Extraction:
  - `journalctl _UID=1000 --since "2026-10-13 00:40" --until "2026-10-13 01:08" -o short-iso-precise`, then grep for `default target picked`, `Setting profile` and `Connected=`;
  - `journalctl _UID=1000 -b --grep "SET_DEFAULT_SINK|SET_DEFAULT_SOURCE|MOVE_SINK_INPUT"`: one line;
  - `journalctl _UID=1000 -b --grep "changed 'default.configured.audio.sink'"`: one line;
  - `git show 0.4.17:modules/module-default-nodes.c` and `git show -s 7a1b48b7` in a WirePlumber tree.

- **U12 — an application opening the microphone while A2DP is starting loses A2DP until the headset reconnects; only Handsfree remains** *(confirmed in the HCI capture, the logs and the source, 2026-10-19; fixed upstream in BlueZ 5.80, not in Ubuntu 24.04)*.

  **What happened** (local time):
  - **[operator]** At 19:43 GNOME Settings offered only "Handsfree - MOMENTUM 4" as output; the headphones (A2DP) entry was gone. The screenshot is kept with the raw evidence.
  - **[log] The chain** (`EX-064`): at 19:33:58.577 Google Chrome opens a playback stream, and at .636 bluetoothd resumes the MOMENTUM 4's A2DP transport for it, sending AVDTP Start (`EX-063`). At .674 Chrome opens a microphone stream. At .676 WirePlumber switches the headset from `a2dp-sink` to `headset-head-unit-msbc`, and at .678 it releases the A2DP transport while the Start is pending. bluetoothd's `a2dp_cancel()` aborts the setup: AVDTP Abort at .678, 42 ms after the Start.
  - **[log] Over the air** (`EX-063`): the headset accepts the Start at .831, which bluetoothd drops ("Transaction label doesn't match"), and never answers the Abort. At 19:34:00.963 the Abort times out, and bluetoothd closes the A2DP signalling channel and two more: A2DP and AVRCP are gone, HFP stays connected.
  - **[log]** At 19:34:07.109, the microphone stream gone, WirePlumber logs "Failed to restore profile". Nothing reconnected A2DP: at 19:50 PipeWire and bluetoothd still had the headset in Handsfree only.
  - **[log] Not the controller:** the mSBC eSCO link set up at 19:33:58.815 completed with Success at 19:33:59.028, two more followed at 19:40:56 and 19:41:11, and the kernel log has no error and no command timeout from 18:00 on. The HCI trace is continuous across the failure (`gaps.log`: size rotations only).

  **[source] The cause.** In BlueZ 5.72's `profiles/audio/transport.c`, a `Release()` during a pending `Acquire()` reaches `transport_a2dp_cancel()`, which calls `a2dp_cancel()`: an AVDTP Abort. Upstream `a14d59725` (Pauli Virtanen, 2024-11-02, "transport: don't disconnect A2DP if canceling Acquire() with Release()", first in 5.80) describes the result: "forcing AVDTP state transition to IDLE, and A2DP profile disconnects". Its fix answers the Acquire with an error, waits for the Start to complete, then suspends. Here the headset's silence made the disconnect certain, through the 2 s timeout.
  - The running bluetoothd is this project's build (`20-patched-bluetoothd.conf`, `/usr/local/libexec/bluetooth/bluetoothd`, built 2026-08-25 from 5.72-0ubuntu5.5's source with the two BT-7 fixes). Its `transport.c` keeps the old path (line 487, no `cancel_resume`).
  - Ubuntu's changelog through 5.72-0ubuntu5.8 (`/usr/share/doc/bluez/changelog.Debian.gz`) has no entry for it.
  - **[source] WirePlumber's part is by design:** 0.4.17 moves a Bluetooth headset to its headset profile while an application records, and restores the earlier profile afterwards. The switch only produces the Release at the moment a Start is pending.

  **Next** (the contribution is a backport request):
  1. Build our bluetoothd from 5.72-0ubuntu5.8's source, which also brings the October security fixes the running build lacks (STATUS, the machine's warnings), with the BT-7 fixes and `a14d59725`.
  2. The operator installs it and repeats the trigger: an application opening the microphone just as A2DP starts.
  3. A Launchpad bug for Ubuntu 24.04 with the tested patch, on the operator's word.

  **Evidence:** `EX-063`, `EX-064`. Raw and unfiltered, on this machine only: `archive/incidents/20261019-a2dp-lost/`, which holds the day's HCI and USB captures, every journal file, the live state at 19:50 and the configuration (README there).

- **U13 — a headset that bluetoothd knows only from its LE advertising cannot be set up from GNOME Settings: every click pairs over LE, the headset refuses, and nothing is shown** *(confirmed in the HCI capture, the log and the source, 2026-10-21; not fixed upstream)*.

  **What happened** (local time, 2026-10-21):
  - **[operator]** The Shure AONIC 50 (a public address with Shure's prefix, `00:0E:DD`) was listed in GNOME Settings' Bluetooth panel as "Not set up". Each click turned "Not set up" into a spinner for a fraction of a second, then back. About a dozen clicks.
  - **[log] Thirteen pairing attempts, 06:20:39 to 06:23:10, all over LE:** `grep -c "Requesting bonding for <the Shure>"` on the day's bluetoothd journal → 13. Each is `adapter_bonding_attempt() … type 1` (LE public), then `pair_device_complete() Authentication Failed (0x05)` and `device_bonding_failed() status 5`, in about 0.2 s.
  - **[capture] The headset refuses LE pairing outright** (`scripts/capture-window.sh` on `bt-20261021-013411.btsnoop`, 06:20:38 to 06:20:40): `MGMT Command: Pair Device … LE Address`, `LE Create Connection`, `LE Enhanced Connection Complete: Success`, our `SMP: Pairing Request` (Bonding, MITM, SC) at 06:20:39.599, the headset's **`SMP: Pairing Failed … Reason: Pairing not supported (0x05)`** at .820, `Pair Device … Status: Authentication Failed (0x05)`, Disconnect. In the saved window 06:20:30 to 06:21:10: 9 Pairing Requests, 9 "Pairing not supported".
  - **[capture] Its advertising hides its BR/EDR side:** the AONIC 50 sends connectable `ADV_IND` with **`Flags: 0x00`** and its name; the scan response carries TX power and Shure's company data. For comparison, the MOMENTUM 4 in the same second sends `Flags: 0x18` (Simultaneous LE and BR/EDR, Controller and Host).
  - **[state] bluetoothd knew it as LE only:** its storage `info` file (read about 06:25) said `AddressType=public`, `SupportedTechnologies=LE;`, no `[LinkKey]`; `busctl get-property … Device1` gave no `Class` (that comes only from a BR/EDR inquiry), `Paired false`. The device directory was created at 06:20; the entry expired at 06:30:41.
  - **[log] The earlier pairing was already gone before 2026-10-20:** the AONIC 50 worked over BR/EDR on 2026-10-13 (`U11`). Its two removals on 2026-10-20 (08:48:53, 17:32:41) are each 30 s after it was last seen, the temporary-device expiry of an unpaired entry. When the bond was lost is not on record here.

  **[source] Why every click goes to LE** (BlueZ 5.72, the running base; same in master):
  - `Pair()` (`src/device.c:3032-3037`): with neither bearer bonded, the bearer is `select_conn_bearer()`, which returns the LE address type when the device is known on LE only (`:2510-2511`).
  - The BR/EDR side is learnt from LE advertising only through the Flags: `if (bdaddr_type != BDADDR_BREDR && eir_data.flags && !(eir_data.flags & EIR_BREDR_UNSUP)) device_set_bredr_support(dev)` (`src/adapter.c:7277-7279`). **A Flags field of `0x00` counts as no Flags at all**, because `eir_data` cannot tell the two apart. Yet `0x00` has the "BR/EDR Not Supported" bit clear, i.e. the headset does not deny BR/EDR. Master still reads it this way (`src/adapter.c:7696-7697` at upstream `master`; last changed by Philipp Dunkel, 2026-07-17, to public addresses only; the `flags &&` test from Luiz Augusto von Dentz, 2016).
  - `PreferredBearer` (Luiz Augusto von Dentz, 2025-02-26, first in BlueZ 5.80) does not help: master exposes it only for a device known on both bearers (`device_prefer_bearer_str()`, `src/device.c:391-393`).
  - Listing a device whose Flags say "not discoverable" is by design: with a discovery filter set, 5.72 treats every report as discoverable (`device_is_discoverable()`, `src/adapter.c:7141-7142`); GNOME's `Discoverable` filter field makes the adapter discoverable while scanning, it does not filter results.

  **Three parts, three owners:**
  1. **The headset** advertises connectable LE with Flags `0x00` under its public BR/EDR address, and answers LE pairing with "Pairing not supported". Shure's firmware.
  2. **BlueZ** reads Flags `0x00` as no information, so it never learns the BR/EDR side from the advertising, and it has no fallback when LE pairing is refused as not supported. A patch candidate: track whether the Flags field was present, and treat a present Flags without "BR/EDR Not Supported" as BR/EDR support (then `select_conn_bearer()` prefers BR/EDR for equal times, `:2513-2516`). The risk to weigh: LE-only devices that send Flags `0x00`.
  3. **GNOME Settings** shows no error for a failed `Pair()`: the row returns to "Not set up" with nothing said. Not yet read in source (GNOME 46.7 / gnome-bluetooth).

  **Workaround, confirmed 06:40:** the operator put the headset into its pairing mode (off, then a long press: "Bluetooth pairing mode"). At 06:40:14 bluetoothd learnt its BR/EDR services; at 06:40:44 the click paired over BR/EDR (`adapter_bonding_attempt() … type 0`, `new_link_key_callback() … type 4`, `bonding_attempt_complete() … type 0 status 0x0`); HFP, A2DP and AVRCP connected at 06:40:45 to :46. Before that, at 06:37:49, the headset itself connected over BR/EDR and dropped after 4 s (reason 3), and three more clicks at 06:38:03 to 06:39:10 still went over LE and failed: the list showed it before its pairing mode was on. **[operator]** It was listed, and clickable to no effect, while not in pairing mode: what a user does not expect.

  **Evidence:** raw and unfiltered, on this machine only: `archive/incidents/20261021-shure-le-pair/` (the bluetoothd journal 06:00 to 06:40, the whole journal 06:15 to 06:40, the decoded capture 06:20:30 to 06:21:10, a copy of the capture file, BlueZ's cache entry, `SHA256SUMS`; saved by `tmp/incident-20261021-shure/save-raw.sh`; the `info` file had expired by then, its content is quoted above). Dossier: `contributions/CO-27-le-only-pairing-u13/`.

- **U14 — a Bluetooth headset is forced into Handsfree while an application on WirePlumber's list records from any microphone, the laptop's own included; a manual return to A2DP is undone when the recording ends, and the wrong profile is saved for next time** *(confirmed in the log and the source, 2026-10-21; WirePlumber 0.4.17, Ubuntu 24.04; fixed upstream by the 0.5 rewrite)*.

  **What happened** (local time, 2026-10-21, the Shure AONIC 50 just paired, see `U13`; Chrome's dictation input open the whole time):
  - **[log] Handsfree 85 ms after connecting, for a recording from the laptop's microphone.** `Google Chrome input` had been open since 06:35:20, linked to the built-in microphone (`link Google Chrome input <-> alsa_input.pci-0000_03_00.6.analog-stereo`). At 06:40:45.955 WirePlumber set `a2dp-sink`; at 06:40:46.040 `Setting profile of 'Shure AONIC 50' from: a2dp-sink to: headset-head-unit-msbc`.
  - **[operator] The hiss came with the Sound page:** at 06:40:59 GNOME Settings' Sound panel opened its input meter (`restore values from Input/Audio:application.id:org.gnome.VolumeControl`), which runs the Handsfree source and so the SCO link; its background noise was audible from that moment, and the panel showed Handsfree, mono, with no codec row. (The meter on the headset source is `U6`; the missing codec row belongs with `U4`; the Handsfree line without a codec, silent in the sound test, is `U1`.)
  - **[operator]** A2DP chosen by hand: LDAC, stereo, clean; SBC clean; Handsfree mSBC and CVSD audible (CVSD clearly worse); the hiss present only while in Handsfree.
  - **[log] A manual choice undone:** at 06:45:36, with the headset in Handsfree, Chrome's input appeared again: `Current profile has input route, not switching`. At 06:47:41 the operator chose A2DP. Chrome's dictation ended; at 06:48:03.637 `Setting saved headset profile to: a2dp-sink`, then `Restoring profile of 'Shure AONIC 50' from: a2dp-sink to: headset-head-unit-msbc`. **[operator]** "the background noise reappeared … no matter I switched manually to headset before it".
  - **[log] And again:** 06:48:28.949 `Current profile has input route, not switching`; 06:49:37.115 `Restoring profile … from: headset-head-unit-msbc to: headset-head-unit-msbc`. While dictation runs with the headset in Handsfree, it stays in Handsfree.
  - **[state] The wrong profile persists:** `~/.local/state/wireplumber/policy-bluetooth` (`use-persistent-storage = true`) holds `a2dp-sink` as the saved headset profile of three other headsets, a profile without a microphone: their next call would "switch" to it.

  **[source] Why** (`/usr/share/wireplumber/scripts/policy-bluetooth.lua`, 0.4.17; config `policy.lua.d/10-default-policy.lua`: `media-role.use-headset-profile = true`, `media-role.applications` lists `"Google Chrome input"`, `"Firefox"` and others):
  1. `checkStreamStatus()` asks only whether the stream is from a listed application (or has `media.role` Communication) and whether the **default sink** is Bluetooth; it never asks whether the stream records from the Bluetooth source. Any listed recording forces the headset into Handsfree.
  2. `switchProfile()` calls `saveLastProfile(device, cur_profile_name)`, which marks the device switched, **before** `if hasProfileInputRoute(device, index) then … "not switching"`. A recording that starts while the headset is already in Handsfree records Handsfree as the profile to restore, without switching.
  3. `restoreProfile()`, 2 s after the last such stream ends, saves the **current** profile as the headset profile (`saveHeadsetProfile`, persisted) and restores the recorded one, so a manual A2DP choice made in between is both reverted and stored as the "headset profile".

  **Upstream:** WirePlumber master (`src/scripts/device/autoswitch-bluetooth-profile.lua`, 0.5 series, cached at `fcc8d79`, 2026-10-16) switches only when a capture stream is linked to the Bluetooth loopback source, records the profile on every change, discards a saved headset profile without a headset input route, restores only from a headset profile, and cancels a pending restore on an explicit headset choice ("Explicit headset (pactl/settings) must not be reverted by a restore timer armed when the previous capture stream closed."). Not in Ubuntu 24.04 (0.4.17).

  **Workaround [inference, the operator's choice]:** a user override that empties `media-role.applications` or sets `media-role.use-headset-profile = false` (then a call needs the profile chosen by hand); and clearing the three wrong `a2dp-sink` entries in the state file.

  **Evidence:** raw and unfiltered, on this machine only: `archive/incidents/20261021-shure-autoswitch/` (the WirePlumber, bluetoothd and full journals 06:30 to 06:55, the state files, the installed script and config, `SHA256SUMS`; saved by `tmp/incident-20261021-shure/save-raw-autoswitch.sh`).

- **U15 — the MOMENTUM 4 says "mute on" at every hands-free start and "mute off" when it ends, with nothing muted on the desktop** *(mechanism confirmed in the log, the HCI capture and the saved state, 2026-10-23; PipeWire 1.0.5 / WirePlumber 0.4.17; whether the microphone is really silenced in a call is not yet checked)*.

  **What happened** (local time, 2026-10-23; the operator wearing the MOMENTUM 4, dictating into a transcription input; "many times already"):
  - **[operator]** "mute on" in the headset when dictation starts, "mute off" when it ends; no mute set for the headset or the Handsfree profile in the settings. A manual switch to Handsfree also gave "mute on"; dictation started after that gave nothing.
  - **[log] Each "mute on" is a hands-free start.** WirePlumber switched the headset from `a2dp-sink` to `headset-head-unit-msbc` at 02:26:18, 02:32:03, 02:35:33 and 02:57:30 (dictation, `U14`'s automatic switch) and back at 02:27:11, 02:32:54, 02:37:04 and 02:57:38; at 02:58:49 `Current profile has input route, not switching` (the manual Handsfree already set).
  - **[capture] The laptop tells the headset its microphone gain is 0.** About 23 ms after each eSCO link came up (02:26:18.545, 02:32:03.757, 02:35:33.212, 02:57:30.666, and 02:58:22.338 for the manual switch) the laptop sent `+VGS: 9` and `+VGM: 0` on the HFP RFCOMM channel, and both again 1.5 s later (`EX-066`).
  - **[state]** `~/.local/state/wireplumber/default-routes` holds `channelVolumes=0.0` for both of the MOMENTUM's hands-free inputs (`headset-hf-input`, `bluetooth-hf-input`); `wpctl status` shows its source at `vol: 0.00`, not muted.
  - **[log] The zero comes from the headset.** At every hands-free connect the MOMENTUM itself reports `AT+VGS=09` (or `12`) and `AT+VGM=00`, and PipeWire logs `volume changed 0`: 32 of 32 connects the journal holds (2026-10-19 to 2026-10-23), never another microphone gain; the Shure AONIC 50 reports `AT+VGM=15` (`EX-065`).

  **[source] Why** (PipeWire master `662fe053a`, `spa/plugins/bluez5/backend-native.c`; 1.0.5's copy not yet compared): the gateway takes a headset's `AT+VGM=<n>` as the microphone volume (`rfcomm_emit_volume_changed(…, SPA_BT_VOLUME_ID_RX, gain)`, l.1380–1383) unless the device lacks the `hw-volume-mic` feature (`broken_mic_hw_volume`, set from the quirk table at l.3584); WirePlumber saves the route volume; at a hands-free start `rfcomm_ag_set_volume()` sends the volume as `+VGM: <n>` when it is marked active (l.3119–3137, called at l.3249–3250 and 3280–3281). The MOMENTUM reports 0 and announces a received `+VGM: 0` as mute. **[inference]** With the quirk the report is ignored; whether the microphone volume then stays inactive, so that no `+VGM` is sent at all, is not traced yet. Upstream has a per-device switch for such headsets: `bluez-hardware.conf` lists one, `{ name = "Air 1 Plus", no-features = [ hw-volume-mic ] }` (`9d38d375d`, 2021: "Some headsets emit AT+VGM even though +VGM commands do not actually adjust the recording volume"); no MOMENTUM 4 entry on master (`662fe053a`, 2026-09-04). Same mechanism as `U2`'s unexplained saved microphone volume.

  **[source] The second send is deliberate.** `sco_start_source()` calls `rfcomm_ag_sync_volume()` at once and again after 1.5 s (l.2791–2807, `d82b3d647`, 2022-06-16, in 1.0.5): some headsets change their HFP volume during A2DP without reporting it, and some take the first `+VGS` after a connect only partly (Sennheiser HD-250BT). The reasoning is about the speaker volume; the microphone gain is resent with it. One `+VGM: 0` is enough for the announcement, so dropping the repeat would not fix U15. `sco_set_volume_cb()` skips a value the headset already has (l.3168); the connect-time sync does not.

  **[source] How a headset's microphone volume is detected.** HFP's supported-features bit 4 (`SPA_BT_HFP_HF_FEATURE_REMOTE_VOLUME_CONTROL`, `defs.h:275`) covers the speaker and the microphone together; there is no microphone-only bit. Both PipeWire and PulseAudio treat a headset's own `AT+VGM` report as the sign that its microphone gain works (PipeWire: `volumes[id].active` is set only by a report, l.676–684; PulseAudio `!528`, 2021: "these `AT+VG[MS]` commands are also used to determine support for it"). Without a report, the volume is applied in software and no `+VGM` is sent. Headsets that report a gain that does nothing are known since PipeWire issue `#678` (2021-02-05, still open: "on none of the headsets does the VGM value actually affect the volume of the recorded audio"); the quirk table is the answer upstream chose. The MOMENTUM reports a gain of 0, which the protocol allows (0–15), so the detection takes it at its word. **[state]** The Tronsmart T8 speaker (`U10`) also advertises Hands-Free (UUID `0x111e`; class `0x240404`: Audio/Video, wearable headset; BlueZ's stored record, read 2026-10-23); it made no hands-free connection in the journal since 2026-10-19, so whether it reports a microphone gain is not known.

  **Open:** is the microphone really silenced while "mute on" (a test call or a recording through the MOMENTUM; if so, the other side of every call hears nothing)? Does `+VGM: 15` give "mute off"?

  **Fix options [the operator's choice]:** a local quirk override (WirePlumber's `bluez5.hardware-database` property with the stock table plus `{ name = "MOMENTUM 4", no-features = [ hw-volume-mic ] }`), which stops the stored 0 (and, to be checked, the `+VGM`); a one-off volume reset (undone at the next connect, when the headset reports 0 again); then the same one-line entry upstream in PipeWire. **PipeWire's contributor rules** (`CLAUDE.md` in its tree, read 2026-10-23): no tool-written merge request descriptions, commit messages, issue text or replies to reviewers, and no automated posting; the operator writes and submits it, and evidence gathered with tools (verbatim logs) may be attached. This project gathers the evidence only.

  **Evidence:** `EX-065`, `EX-066`; raw on this machine only: `archive/incidents/20261023-momentum-mic-gain-zero/` (the user journal around the connect and the sessions, every gain line the journal holds, the state files, `wpctl status`, the captures' gain packets, `SHA256SUMS`; saved by `tmp/incident-20261023-momentum/save.sh`).

- **U16 — after a failed Connect from GNOME Settings, its device search stops for good** *(confirmed in the bluetoothd debug log, the system bus record and the source, 2026-10-23; BlueZ 5.72, this project's build; GNOME Settings 46.7; not fixed in BlueZ master `a0580dad5`, no duplicate found)*.

  **What happened** (local time, 2026-10-23; the Lenovo `联想thinkplus-GM2 pro` earbuds were connected to another device, a phone, so they could not answer):
  - **[operator]** 21:53:32 a click on the earbuds in the Bluetooth panel: a spinner, then nothing; at 21:54:28 no "searching" spinner in the panel any more; Bluetooth off at 21:54:59 and on at 21:55:17 brought the search back.
  - **[log] The connect and the stop are sent together** (`journalctl -u bluetooth`, debug on): 21:53:32.744031 `stop_discovery() sender :1.207` (GNOME Settings), at once `connect_profiles() …/dev_<earbuds> (all), client :1.207`, and MGMT command `0x0007` (Set Connectable) is sent at .744300. **No `0x0024` (Stop Discovery) is sent yet**: BlueZ's `shared/mgmt.c` sends one command at a time, and the kernel answers Set Connectable only after the connection attempt ends.
  - **[log] Five seconds later the connect fails, and the client restarts its search into the gap:** 21:53:37.873568 `connect_failed_callback() … status 4` (Page Timeout); `resume_discovery()`, `trigger_start_discovery()`; at .883635 `set_discovery_filter() sender :1.207`, at .884120 `start_discovery() sender :1.207`. Set Connectable completes at .894140.
  - **[log] Then the stale stop lands and removes the client:** .903192 MGMT `0x0024` sent, .906124 complete, `stop_discovery_complete() status 0x00`, `discovery_remove() owner :1.207`, `discovering_callback() hci0 type 7 discovering 0`. No discovery until the power cycle: 21:55:18.290614 `start_discovery() sender :1.207`, `discovering 1` at .308847.
  - **[log] The same exchange on 2026-10-11 00:26:54, same earbuds** (the system bus monitor of `bt-ui-capture`, `system-bus.log` lines 70600–70630; that monitor was not running at 21:53 on 10-23): `StopDiscovery` and `Device1.Connect` sent 20 µs apart; `Connect` → `org.bluez.Error.Failed "br-connection-page-timeout"` 5.15 s later; `SetDiscoveryFilter` → ok; **`StartDiscovery` → `org.bluez.Error.InProgress`**; then the pending **`StopDiscovery` → `org.bluez.Error.InProgress`** as well, 22 ms later.

  **[source] Why** (BlueZ 5.72, `src/adapter.c`):
  1. `discovery_stop()` (l.2423) leaves the client in `discovery_list` while its MGMT Stop Discovery is pending (`adapter->client = client`, `-EINPROGRESS`, l.2453–2459).
  2. A `StartDiscovery` from that client in the meantime finds itself still listed and is refused (`get_discovery_client()` → `btd_error_busy()`, l.2512–2519; D-Bus `org.bluez.Error.InProgress`).
  3. When the stale stop completes, `stop_discovery_complete()` (l.2145) removes the client (`discovery_remove()`, l.2153–2155) and marks the adapter not discovering. The client's new request is gone and nothing restarts it.
  4. The window is as long as the MGMT command ahead of the stop takes: here the 5 s of a paging attempt to a headset that does not answer. A connect to a reachable device ends in well under a second, which is why this is rare.

  **[inference] Three owners, to be confirmed:** BlueZ (a start from the client whose stop is still pending could cancel or follow the stop, instead of being refused and then dropped); GNOME Settings / gnome-bluetooth (it does not wait for the `StopDiscovery` reply before `Connect`, does not retry an `InProgress` start, and shows no message); the kernel only in holding Set Connectable for the length of the page, which is its documented serialisation, not a defect.

  **Workaround:** Bluetooth off and on in the panel.

  **Upstream check, 2026-10-24: not fixed, no duplicate found.**
  - **BlueZ master `a0580dad5` (2026-10-23) has the same logic.** `discovery_remove`, `discovery_complete`, `stop_discovery_complete`, `discovery_stop`, `start_discovery` and `stop_discovery` are textually identical to 5.72's (`tmp/u16-dup-check/cmp.sh`). In master: `start_discovery()` `if (is_discovering) return btd_error_busy(msg);` l.2562; `discovery_stop()` `return -EINPROGRESS;` l.2503; a second `StopDiscovery` while one is pending is refused at l.2944 (`if (client->msg)`), which is the `InProgress` reply seen on 2026-10-11.
  - **The nearest earlier fix is a different trigger:** `8486b4cd2` (Luiz Augusto von Dentz, 2020-05-28, "adapter: Fix not removing client from discovery list") removes the client when a *start* fails; it is in 5.72. The 2020 list thread it answered: https://www.spinics.net/lists/linux-bluetooth/msg85293.html.
  - **Trackers (web search, read only):** BlueZ issue #1554 (this project's report; InProgress on restart, a kernel simultaneous-discovery race, no Connect involved) and #343 (the kernel rejects the stop) are related, not the same; client-side InProgress reports (bluer #47, bleak #1036, Home Assistant #76186 and #76544) are different. No hit on GNOME's GitLab, Launchpad or lore for this sequence [inference: by web search only].
  - **gnome-bluetooth 46.2 (the 46.x line Ubuntu 24.04 ships; master the same):** `lib/bluetooth-settings-widget.c:1049` and `:1077-1080` turn setup mode off just before `setup_device`/`connect_service`; `lib/bluetooth-client.c:1241-1250` turns that into an `adapter1_call_stop_discovery` without waiting for its reply; after the connect, setup mode on → `SetDiscoveryFilter` + `StartDiscovery` (`~1197-1210`); `start_discovery_cb` (`~1165-1182`) only logs an error with `g_debug`, sets `discovery_started = FALSE` and does not retry.

  **Patch candidates:** BlueZ: drop the client from `discovery_list` as soon as its stop is queued, or let a start from a client whose stop is pending cancel or follow that stop. gnome-bluetooth: wait for the `StopDiscovery` reply before `Connect`, or retry a start refused `InProgress`.

  **Next:** a reproducer on the laptop (the operator: earbuds off in their closed case, the panel searching, a click on them, is the spinner still there 10 s later?) and in the emulator (a connect to an absent address while discovering); then the BlueZ patch.

  **Evidence:** raw on this machine only: `archive/incidents/20261024-earbuds-discovery-and-sco-gap/` (`journal-bluetoothd-2152-2156.txt`, `system-bus-20261011-002654.txt`, `system-bus-discovery-calls.txt`, `capture-connect-2153.txt`, the user journal 21:52–21:59, `SHA256SUMS`; saved by `tmp/incident-20261024-earbuds/save.sh`; real addresses inside).

- **U17 — after an HFP codec switch whose SCO connect is refused, the headset is silent for 5 s** *(confirmed in the logs, the HCI capture and the source, 2026-10-24; on the CO-02 kernel; PipeWire 1.0.5 / WirePlumber 0.4.17; not fixed in PipeWire master `73974598f` or WirePlumber master `ce5d858`, no duplicate found)*.

  **What happened** (local time; the Lenovo earbuds, A2DP → Handsfree, YouTube playing):
  - **[operator]** 2026-10-24 06:12:22 mSBC → CVSD: "No sound. Oh, sound appeared at 6:12:31." 06:12:47 CVSD → mSBC: "Big delay. The sound returned in mSBC. About three seconds of delay." A third refusal on 2026-10-23 at 22:00:33 (mSBC → CVSD) with no stream playing: the next link came with the test sound, `Setup Synchronous Connection` at 22:00:46.198849.
  - **[capture] The headset answers before the old link is gone, which is `U7`'s ordering** (`scripts/sco-switch-windows.sh` on `hci-20261023-233436.btsnoop`):

    | switch | AG `+BCS:` + Disconnect | headset `AT+BCS=` | old link's Disconnect Complete (after `+BCS:`) | new `Setup Synchronous Connection` | new link up |
    |---|---|---|---|---|---|
    | 06:12:22 mSBC → CVSD | .298580 / .298592 (handle 5) | .324563 | .491861 (+193 ms) | 06:12:27.350650 | .386887, CVSD, handle 6 |
    | 06:12:47 CVSD → mSBC | .690751 / .690774 (handle 6) | .714559 | .886915 (+196 ms) | 06:12:52.743599 | .786897, Transparent, handle 7 |

  - **[log] The kernel refuses the connect, PipeWire retries at once, and the node fails** (`scripts/user-journal.sh`, WirePlumber debug): 06:12:22.340902 `sco_do_connect, codec=1`; .340952 `connect(): Software caused connection abort. Remaining retry:1`, .340996 `Remaining retry:0`, .341032 `connect(): Software caused connection abort` — three attempts in 130 µs, all 151 ms before the old link's Disconnection Complete; `state changed 0 -> -1`, `Failure in Bluetooth audio transport`; pipewire: `bluez_output… running -> error (Received error event)`.
  - **[log] The audio comes back only through the idle timer:** 06:12:27.344984 WirePlumber `was idle for a while; suspending ...` for both nodes; `error -> suspended`; .350496 `sco_acquire_cb`, `sco_do_connect`; .399865 `ready`, `acquire complete`. The same at 06:12:47.735 → 06:12:52.739 → link at .786897. **5.004 s each time.**
  - **[log] History:** the journal (from 2026-10-20) holds only these three refused connects (22:00:33, 06:12:22, 06:12:47), all on the boot with the CO-02 module (`journal-user-abort-history.txt`).

  **[source] Why:**
  1. PipeWire's `sco_do_connect()` (`spa/plugins/bluez5/backend-native.c`, master `662fe053a` l.2677–2688) retries a connect that fails with `ECONNABORTED` twice, **immediately**, with no wait. The retry was added for this very situation: `d439b7cdd` (Huang-Huang Bao, 2021-03-22), "When I enforing HFP codec switching between HFP profiles, it has a chance of being aborted by ECONNABORTED. Seems a retry is sufficient for work around it."
  2. On failure the transport goes to error and the node to `error`. WirePlumber 0.4.17 `suspend-node.lua` starts its idle timer on `idle` **or `error`** (`session.suspend-timeout-seconds`, default 5) and then sends `Suspend`; the suspended node is started again by the stream still linked to it, which acquires and connects afresh, by then after the old link is gone.
  3. Before the CO-02 series the kernel did not refuse: it handed the connect the closing link and reported success with no link behind it (`U7`, `EX-060`), and no link followed at all: on 2026-09-29 new test sounds started 3, 2 and 26 s after the failed switches stayed silent, and the next codec change ended the first silence (corrected 2026-10-26: this said "silence until the stream was restarted by hand", which the record does not show). The series turns that into a refusal, and PipeWire's existing recovery turns the refusal into a 5 s gap. Shorter needs one of: a retry in PipeWire that waits for the old link's teardown (it knows it has just closed it), or a kernel that queues the new connect until the Disconnection Complete instead of refusing.

  **Why it matters for CO-02:** the cover letter must say that on the earbuds the user gets the audio back after about 5 s rather than never; the maintainers may prefer the kernel to wait. To be weighed before the series is sent.

  **Upstream check, 2026-10-24: not fixed, no duplicate found.**
  - **PipeWire master `73974598f` still retries at once:** `sco_do_connect()` has the same `for (int retry = 2;;)` loop with `continue` on `ECONNABORTED` and no wait; 1.0.5 has it at `backend-native.c:1447`. `git log -S ECONNABORTED -- spa/plugins/bluez5` gives only `d439b7cdd` (above) and `5a22d0bfc` (Pauli Virtanen, 2021-01-04, "bluez5: delay SCO transport releases in case they get reacquired").
  - **PipeWire already knows the error means "too soon after the previous close"**, and handles it for a different case only. Master `spa/plugins/bluez5/bluez5-dbus.c:275-283`: "SCO socket connect may fail with ECONNABORTED if it is done too soon after previous close. To avoid this in cases where nodes are toggled between stopped/started rapidly, postpone release until the transport has remained unused for a time." (`TRANSPORT_RELEASE_TIMEOUT_MSEC 1000`). A codec switch frees the old transport and creates a new one, so that delay does not apply. The same error for the same cause is therefore not new with the CO-02 series: the series makes the kernel return it in one more case, on the first `connect()`.
  - **No commit since 1.0.5 touches the retry or the codec-switch timing** (about 90 commits to `backend-native.c`, judged by subject). The #5467 fix (`d80b80602`, `b7246d0d5`, September 2026) concerns error counting on A2DP↔HFP switches, a different path (`userspace-upstream-check-2026-10-03.md`).
  - **WirePlumber master `ce5d858` still suspends `error` nodes on the timer:** `src/scripts/node/suspend-node.lua:131` `if new_state == "idle" or new_state == "error" then`. Its only error recovery (`monitorNodeError`, `439143e`, 2026-10-19) is for ALSA.
  - **Trackers:** PipeWire's GitLab refused automated reads (an "Access Denied" bot check), so it was searched through a web search only: #1817 (ETIMEDOUT), #2783, #2896 and #1827 are different. PulseAudio MR !622 "bluetooth: Try to reconnect SCO" is the same scenario in PulseAudio (a connect right after a disconnect occasionally fails), related. No kernel patch or thread on a SCO connect arriving while the previous SCO to the same peer is disconnecting [inference: by web search only].

  **Next:** PipeWire's tracker read by the operator in a browser (the bot check blocks tools); a PipeWire change that waits for the old link, or retries `ECONNABORTED` after a short delay instead of at once, is the operator's to write and submit, with verbatim logs attached (`pipewire-contribution-rules`); the kernel side in `hci_connect_sco()`: whether waiting for the Disconnection Complete is feasible; then the same switch on the MOMENTUM 4 as the control (it answers after its old link is gone, so no refusal is expected).

  **Control, the Shure AONIC 50 on the same boot (2026-10-24, `sco-switch-windows.sh` on `hci-20261024-062043.btsnoop`):** mSBC → CVSD at 06:36:44 and CVSD → mSBC at 06:37:03; the old link's Disconnection Complete came **before** the headset's `AT+BCS=` (.394622 vs .424559; .384621 vs .426581), and `Setup Synchronous Connection` followed the AG's `OK` by 31 ms and 23 ms (links up at .548701 CVSD and 06:37:03.530667 Transparent); no refusal in the journal. **[operator]** "Switches fast." The third headset to take the fresh path.

  **Evidence:** raw on this machine only: `archive/incidents/20261024-earbuds-discovery-and-sco-gap/` (`capture-switches-0611-0613.txt`, `capture-switch-2200.txt`, `journal-user-0607-0614.txt`, `journal-user-2200.txt`, `journal-user-abort-history.txt`, `wireplumber-suspend-node.lua.txt`, `SHA256SUMS`; saved by `tmp/incident-20261024-earbuds/save.sh`; real addresses inside); the Shure control in `archive/incidents/20261024-shure-le-connected-no-audio/capture-switches-0636-0637.txt`.

- **U18 — a headset paired over LE shows "Connected" in GNOME Settings, with no audio and no entry in the sound settings** *(confirmed in the bluetoothd debug log, the system bus record, the HCI capture and the source, 2026-10-24; BlueZ 5.72, this project's build; the same code in master `a0580dad5`; no duplicate found, BlueZ #2037 possibly the same)*. A sequel of `U13`: the same first step (a device known on LE only is paired over LE), this time with the headset in its pairing mode, where it accepts LE pairing.

  **What happened** (local time, 2026-10-24; the Shure AONIC 50 in its pairing mode):
  - **[operator]** 06:27:29 a click on the Shure in the Bluetooth panel; the panel said "Connected" (06:28:12), the headset announced nothing ("usually Shure is staying connected"); the Sound panel had no Shure (06:28:46, 06:30:19), the sound stayed on the laptop's speakers. Connection off and on in the device page: "connected" again, still no sound, no Shure in the Sound panel. Forget at 06:30:48; a long press into pairing mode; at 06:31:53 the Shure listed as "Not set up"; one click, "connected" announced by the headset, LDAC.
  - **[log] Paired over LE** (`journalctl -u bluetooth`, debug on): 06:27:33.589223 `adapter_bonding_attempt() … type 1` (LE public); `LE Create Connection` at .723590 (capture); SMP Pairing Request with `LinkKey` in both key distributions, the headset's Pairing Response keeps `LinkKey` (.083718); LE encryption at 06:27:35.388; `new_link_key_callback() … type 7` (a BR/EDR key derived from the LE pairing) and `bonding_attempt_complete() … type 1 status 0x0` at 06:27:35.49; GATT `gap-profile` and `batt-profile` **connected** at .665.
  - **[log] Connect looks up the audio services, then connects none:** system bus: `Device1.Pair` → ok at 06:27:35.672060; `Device1.Connect` at .672332. bluetoothd: `connect_profiles() … (all), client :1.292`, `Resolving services` at .672424; the capture: BR/EDR `Create Connection` at .672596, `Connect Complete` 06:27:36.849665, an SDP search answered with Audio Sink (`0x110b`), A/V Remote Control, Remote Control Target, **Handsfree (`0x111e`)** and two Serial Port records by .983568. bluetoothd: `device_svc_resolved() … err 0` at 06:27:37.026961; **`Connect` → method return at 06:27:37.027484**; the next bluetoothd line is GNOME's `set_discovery_filter()` at .029043 — no second `connect_profiles()`, no HFP or A2DP connect. The SDP channel closed at 06:27:39.2 and the idle BR/EDR link was dropped at 06:27:41.376 (`Disconnect`, reason "Remote User Terminated"; `dev_disconnected() … reason 2`). The LE link stayed: GNOME's "Connected".
  - **[capture] The off/on toggle worked on LE only:** off: LE `Disconnect` 06:29:35.199976; on: `LE Create Connection` 06:29:55.822138, `gap-profile`/`batt-profile` connected at 06:29:56.37; no BR/EDR connection.
  - **[log] The working pairing went over BR/EDR:** after the Forget, the headset in pairing mode was found by inquiry (`a2dp_sink_probe()` and Hands-Free probes at 06:31:44.94, from its BR/EDR data), so the click paired with `type 0` (06:32:01.841094), `new_link_key_callback() … type 4`, then HFP connected at 06:32:03.449 and A2DP at .753.

  **[source] Why** (BlueZ 5.72 `src/device.c`; master `a0580dad5` the same, `dev_connect()` at l.2892–2912):
  1. After the SDP search, `browse_request_complete()` (l.2756) calls `dev_connect()` again for the pending `Connect` (l.2810–2811).
  2. `dev_connect()` (l.2523): with the BR/EDR link up, "Check if services have been resolved and there is at least one connected before switching to connect LE": `if (dev->bredr_state.svc_resolved && find_service_with_state(dev->services, BTD_SERVICE_STATE_CONNECTED)) bdaddr_type = dev->bdaddr_type;` (l.2529–2537). `find_service_with_state()` searches **all** the device's services. The LE GATT services `gap-profile` and `batt-profile` were connected, so the check passes and the bearer becomes the device's LE address type although no BR/EDR service is connected.
  3. Then `if (dev->le_state.connected) return dbus_message_new_method_return(msg);` (l.2548–2549): success, nothing connected.
  **[inference]** The branch is read from the absence of a second `connect_profiles()` debug line, which the BR/EDR path prints first (l.2414); the other routes to the same return need the BR/EDR link down or unknown, and the capture shows it up from 06:27:36.85 to 06:27:41.38.

  **Owners:** BlueZ (the check should ask for a connected *BR/EDR* service, or `Connect` should not report success with no BR/EDR profile connected when the device offers audio); `U13`'s LE-first pairing choice (the Flags `0x00` reading) is what put the headset on LE in the first place. GNOME shows "Connected" because BlueZ's `Connected` is true for the LE link; it has no way to see that the audio is missing.

  **Workaround:** Forget, then pair again with the headset in pairing mode and the panel searching, so that it is found over BR/EDR first (worked at 06:32:01).

  **Upstream check, 2026-10-24: not fixed, no duplicate found.**
  - **Origin of the check:** `aa0b1a0c1` (Luiz Augusto von Dentz, 2016-08-12, "core/device: Fix not connecting services properly"): "Device.Connect shall check if the service discovery is pending or no service have been connected yet before switching to LE otherwise these services may never be connected." Its case is a BR/EDR device whose BR/EDR services are not connected yet; connected LE services were not considered.
  - **Master `a0580dad5` keeps it** (`src/device.c:2901-2911`, then `if (dev->le_state.connected) return dbus_message_new_method_return(msg);` at l.2925), and the same pattern a second time in `device_connect_profiles` (l.2855-2860: no pending profile, services refreshed, any connected service → success). `find_service_with_state()` (l.367) has no bearer argument. Later changes to this region (`03240630b` PreferredBearer, `6d8260cf6`, `1c2ec2990` and others) do not change the check (judged by reading the current code; not every diff read).
  - **PreferredBearer does not avoid it:** it is applied in `select_conn_bearer()` (l.2915), which `dev_connect()` reaches only when the BR/EDR link is down; here the SDP link is up when `dev_connect()` runs again [inference from the code].
  - **The fix has what it needs:** profiles declare their bearer (`src/profile.h:15-17`, `BTD_PROFILE_BEARER_ANY/LE/BREDR`), GAP and Battery as LE (`profiles/gap/gas.c:353`, `profiles/battery/battery.c:329`), A2DP and AVRCP as BR/EDR (`profiles/audio/a2dp.c:3852`, `:3872`, `avrcp.c:4915`, `:4999`), and `device_remove_pending_services()` already filters by it (`device.c:8560-8563`).
  - **Trackers (web search, read only):** BlueZ #2037 (a Sony WH-1000XM6, `Connected: yes` and `LE.Connected: yes` with no audio card; closed as stale 2026-10-01, no root cause) is possibly this bug, unconfirmed; #2700 (a neckband paired over LE only, then "br-connection-key-missing") is related, a different failure. lore returned 403; Launchpad and GNOME's GitLab not searched.

  **Patch candidate:** count only services whose profile bearer is not LE in the two checks (`dev_connect()` and `device_connect_profiles()`), e.g. a bearer argument for `find_service_with_state()`; a test in the emulator (a dual-mode device with a connected LE GATT service, then `Connect`); together with `U13`'s Flags patch. #2037 is worth a comment from the operator once the patch exists.

  **Evidence:** raw on this machine only: `archive/incidents/20261024-shure-le-connected-no-audio/` (`journal-bluetoothd-0626-0633.txt`, `system-bus-pair-connect-062733.txt`, `capture-pair-062733.txt`, `capture-toggle-0629.txt`, `capture-pair-063201.txt`, the user journal 06:26–06:38, `SHA256SUMS`; saved by `tmp/incident-20261024-shure/save.sh`; real addresses inside).

- **U19 — after a headset leaves Handsfree for A2DP, the Sound panel's input meter stays dead on the laptop's microphone** *(observed by the operator; confirmed in the user journal, the audio policy log and the source, 2026-10-24; caused by Ubuntu's patch `lp-2122640-bluetooth-audio-glitch.patch` in WirePlumber 0.4.17-1ubuntu4.1, not in upstream WirePlumber; GNOME Settings 46.7-0ubuntu0.24.04.6, PipeWire 1.0.5)*.

  **What happened** (local time, 2026-10-24; the Shure AONIC 50; GNOME Settings' Sound panel open):
  - **[operator]** After the switch from Hands-free to Headset (A2DP) the Input section showed the laptop's internal microphone, but its level meter did not move while the operator spoke or made loud sounds; mute and unmute changed nothing. Back in Hands-free the meter worked on the Shure's microphone; choosing the internal microphone by hand while in Hands-free made its meter work, and it followed the input volume. Back to Headset: dead again ("It appears a bug … Once again").
  - **[log] The panel opens no capture on the new default source** (`journalctl -u bt-audio-policy`; `capture[GNOME Settings]` lists the sources the panel's streams record from):
    - 08:04:59 GNOME Settings' capture `Shure AONIC 50` → none; `default audio.source` `Shure AONIC 50` → `bluez_input.<the Shure>.0` → the laptop's microphone (`Family 17h/19h HD Audio Controller Analog Stereo`); profile `headset-head-unit-msbc` → `a2dp-sink`; 08:05:00 capture → `monitor of Shure AONIC 50` only (the output meter). No capture on the laptop's microphone. (The middle value is the recorder's: `scripts/bt-audio-policy.py:71-74` prints a node's raw name once the node is gone; the default itself did not pass through a removed node.)
    - 08:07:07 (in Hands-free, the input picked by hand): capture → `Family …; Family …; monitor of Shure AONIC 50`: the meter is attached.
    - 08:08:42 the same as 08:04:59.
  - **[log] The opposite direction works:** 08:03:51–52, A2DP → Hands-free, default source the laptop's microphone → `Shure AONIC 50`, capture none → `Shure AONIC 50; monitor of Shure AONIC 50`: the meter followed the new default.
  - **[log] The panel does open the meter; WirePlumber destroys it** (`archive/…/journal-user-0755-0812.txt`, lines 28294–29305):
    - 08:04:59.044924 `Bluetooth device removed, preventing non-Bluetooth devices from linking for 2 seconds`;
    - 08:04:59.051861 `[GNOME Settings] CREATE_RECORD_STREAM tag:478 … source-name:53` (53 is the laptop's microphone, the index the hand pick at 08:07 used);
    - 08:04:59.734–.753 `... target not found, reconnect:false` / `... destroy node`;
    - 08:04:59.754620 `[GNOME Settings]: ERROR … tag:478 error:25 (Input/output error)`.
    - 08:08:42 the same (window .030108, the meter as tag 1173, destroyed from .051).

  **[source] Why** (installed `/usr/share/wireplumber/scripts/policy-node.lua`, 0.4.17-1ubuntu4.1):
  1. When a Bluetooth node is removed, Ubuntu's patch disables linking of non-Bluetooth targets for 2 s (l.1024–1042; changelog: "Prevent bluetooth profile switch to output some sound on another device during the transition (LP: #2122640)").
  2. A new stream whose target is not Bluetooth gets `skip_this_target = true` (l.755–760): no link, nothing logged.
  3. `si_flags[si.id].was_handled = true` is still set (l.822), although nothing was linked.
  4. The level bar opens its stream with `PA_STREAM_DONT_MOVE` (GNOME Settings 46.7 `panels/sound/cc-level-bar.c:197`), which pipewire-pulse makes "don't reconnect"; at the next rescan "dont-reconnect and was already linked" drops the target (l.766–768), and the stream is told "target not found" and destroyed (l.789–816).
  5. GNOME Settings does not retry: the level bar sets no state or failure callback (`cc-level-bar.c:187-188`); it re-attaches only when the default source changes again (`cc-sound-panel.c:151-169`, `191-209`), which after a switch to A2DP it does not.
  The opposite switch works because the new target is the Bluetooth source, which the patch lets through; the hand pick works because no Bluetooth removal falls in its 2 s.
  **[inference]** Any stream opened with "don't move" to a non-Bluetooth device within 2 s of a Bluetooth node's removal is lost the same way (other level meters, some recorders).

  **Owner:** Ubuntu's WirePlumber package (`d/p/lp-2122640-bluetooth-audio-glitch.patch`, Antoine Lassagne, 2025-09-11; LP #2122640, Fix Released for Noble). Upstream WirePlumber is not affected: its master (`src/scripts/linking/rescan.lua`) only pauses the rescan triggers and never marks an unlinked stream as handled [read in master; MR 655, which the patch is said to rewrite, could not be fetched].

  **Impact:** the panel names a working microphone as the input and shows no signal from it, so a user concludes that the microphone is broken. Whether an application recording at that moment gets the laptop's microphone was not tested.

  **Patch candidate (an Ubuntu SRU):** set `was_handled` only when a link was made:
  ```lua
  if skip_this_target == false then
    createLink (si, si_target, can_passthrough, exclusive)
    si_flags[si.id].was_handled = true
  end
  ```
  so that the rescan at the end of the 2 s links the meter [inference, not run]. Optional, GNOME side: the level bar could retry when its stream fails (unchanged on gnome-control-center main).

  **Upstream check, 2026-10-24:** Noble has nothing newer than 0.4.17-1ubuntu4.1; LP #2122640's comments report no such regression; no Launchpad or GNOME report matches. Related, not the same: gnome-control-center #1550 (the panel not refreshed when devices change elsewhere), WirePlumber #682 (a 0.5.4 crash at a profile switch).

  **Again, 2026-10-26 [operator]:** Hands-free → Headset with the Shure's microphone as the input: the meter froze at the level it showed at the switch (05:34:04, 05:36:16). At 05:32:25 the input was already the internal microphone before the switch, and the meter kept working. This agrees with the traced cause: only a meter stream attached to the Bluetooth source is destroyed when that source goes. Not yet read in the journal for these times.

  **Next:** a test on the laptop (the patched line in a user override of `policy-node.lua`, then the Hands-free → A2DP switch; the operator's decision); whether a recording application loses its stream the same way; then a Launchpad report with the patch, the operator's.

  **Evidence:** raw on this machine only: `archive/incidents/20261024-shure-mic-meter-and-vgm/` (`audio-policy-0755-0812.txt`, `atspi-0755-0812.txt`, the user and bluetoothd journals 07:55–08:12, `SHA256SUMS`; saved by `tmp/incident-20261024-shure-mic/save.sh`; real addresses inside).

- **U20 — the Shure AONIC 50's microphone ignores the input volume in Hands-free** *(observed by the operator, the commands confirmed in the HCI capture, 2026-10-24; PipeWire 1.0.5; the headset's behaviour inferred)*. Related to `U15` (the MOMENTUM 4's microphone gain of 0 at connect): the same hardware-volume path.

  **What happened:**
  - **[operator]** In Hands-free the Input volume slider of the Shure was moved over its whole range; the level meter showed "exactly the same" whatever the level. At 0 the panel showed the muted sign; unmuting brought the meter back.
  - **[log]** `node[Shure AONIC 50 Audio/Source] volume` 0.87 → 0.36 → 1.0 → 0.07 → 1.0 → 0.0 → 0.25, 08:04:05–08:04:43 (`journalctl -u bt-audio-policy`).
  - **[capture] Every move went to the headset as hardware gain:** `+VGM: 13` with the link setup (08:03:51.928), then `+VGM: 12` … `5` (08:04:05.27–.67), `6` … `15` (08:04:08.50–.71), `14` … `1` (08:04:16.57–17.06), `2` … `15` (08:04:24.96–25.09), `14` … `0` (08:04:27.89–28.06), `4` (08:04:43.00) (`scripts/capture-window.sh … 'VGM|VGS|…'`).
  - **[capture] The headset asks for it:** at the service level connection, 06:32:03.463558, the Shure sent `AT+BRSF=955` (binary `11 1011 1011`: bit 4, "remote volume control", is set) and `AT+VGM=15` at .719573.
  - **[inference]** PipeWire applies no software gain when the headset takes the gain, so the meter shows what the headset sends; with the gain from 15 to 0 the meter did not change, so the Shure does not apply `+VGM` to its microphone. Not ruled out: an automatic gain in the headset that hides it.

  **Owners:** the headset's firmware (it announces remote volume control and ignores the microphone gain); on the laptop, PipeWire's per-device quirk table (`bluez-hardware.conf`) is the place for such a headset (software gain for the Handsfree source). Under PipeWire's rules a report or entry is the operator's to write.

  **Workaround:** set the recording level in the application.

  **Upstream check, 2026-10-24: no quirk entry for this headset, no report found.**
  - **[source] PipeWire 1.0.5** (master `73974598f` the same logic): `AT+BRSF` bit 4 sets `has_volume` for speaker and microphone together (`spa/plugins/bluez5/backend-native.c:793`; master l.1124); the headset's own `AT+VGM=n` makes the microphone gain active (l.1047–1063 → 401–403), unless the device has the quirk that clears `hw-volume-mic` (`broken_mic_hw_volume`, l.1049, set at l.2271–2277, which logs "microphone HW volume disabled by quirk"); a slider move becomes `+VGM: n` (l.1887–1908, 1854–1885); with the gain active the software volume of the mono source is 1.0 (`bluez5-device.c:2363–2369`).
  - **[log]** WirePlumber at the connect (06:32:01–03): `device quirks:00000000`, `hw-volume-profiles:000000fc` (Handsfree included); no "disabled by quirk" line (`scripts/user-journal.sh --since "2026-10-24 06:31:50" --until "2026-10-24 06:32:15" -g "quirks:|hw-volume-profiles|AT\+VGM|disabled by quirk"`).
  - **The table:** the installed `/usr/share/spa-0.2/bluez5/bluez-hardware.conf` has one `hw-volume-mic` entry, `{ name = "Air 1 Plus", no-features = [ hw-volume-mic ] },` (l.30), none for Shure or `00:0e:dd`; master the same. That entry came with `9d38d375d` (2021): "Some headsets emit AT+VGM even though +VGM commands do not actually adjust the recording volume" — this case.
  - **Trackers (PipeWire GitLab, read only):** no issue names the AONIC 50; #678 (open, "Adjusting Bluetooth microphone hardware volume": "on none of the headsets does the VGM value actually affect the volume of the recorded audio") is the same class, where the quirk came from.
  - **Candidate entry** (the operator's to submit, under PipeWire's rules): `{ name = "Shure AONIC 50", no-features = [ hw-volume-mic ] },` — matched on the BlueZ `Name`; with it the slider becomes software gain [inference from the code, not run]. A local test is possible through WirePlumber 0.4.17's `bluez5.hardware-database` property, which replaces the whole table (the copy must keep the adapter section: this laptop's adapter has quirk `00000004`). The test would also rule out an automatic gain in the headset.
  - **Speaker side:** the Shure also reported `AT+VGS=06`, so the Handsfree output volume is hardware volume too; whether it honours `+VGS` needs a listening test.

  **Evidence:** as `U19` (`capture-vgm-0803-0804.txt`, `capture-slc-063203.txt`, `audio-policy-0755-0812.txt`).

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
