# Issue register

This investigation began as "the Bluetooth controller hangs". It is now clear that is not
one defect. At least five distinct problems have been observed on this machine, and
filing them under a single heading has actively slowed the work: evidence for one kept
being read as evidence for another, and three hypotheses were killed only after being
mistaken for the main bug.

Each issue below is tracked separately, with its own evidence and its own reportability.
They are numbered `BT-n` so exhibits and commits can cite them.

**Independence matters for submission.** A small, deterministic, well-evidenced bug is far
more likely to be fixed than a large intermittent one, and bundling them means the weakest
member sets the pace for all. `BT-2` and `BT-4` are reportable *today*; `BT-1` is not.

---

## BT-1 — Controller stops answering HCI, then leaves the USB bus

**Status:** under investigation — the original bug, and the hardest.
**Reportable:** ❌ not yet. No quantified reproducer (`docs/pre-submission-checklist.md`).

The controller stops answering HCI commands; 45–66 s later it stops answering USB control
transfers; then it leaves the bus. Only a cold power-off recovers it — a warm reboot does
not drop the M.2 power rail.

**Current formulation — everything the evidence earns, and nothing more:**

> The controller sometimes enters a non-responsive HCI state during synchronous-audio link
> transitions; generic USB transport failure follows later rather than initiating the event.

That is deliberately a statement about *when and where*, not *why*. The failure is now
well localised in time and in subsystem behaviour, and not at all in mechanism. Anything
phrased as a mechanism is currently a hypothesis, and the register above is the place to
find out which ones have already died.

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
  nothing recovers it (`EX-005`).

Still unknown: whether a reset at +0 s helps, whether firmware download prevents it, and
what makes a given SCO operation fatal when others succeed.

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
decoding. The underlying crash is untouched and still needs a minimal reproducer and a
backtrace before it is worth filing.

`btmon -w` aborts with a core dump during capture, frequently enough that the capture
rotates on crash rather than on size. Files average ~2 MB against a 128 MB rotation
threshold. Each abort loses roughly one second of capture, logged as a gap.

This is a userspace tool bug in a *diagnostic* tool, which makes it worse than it sounds:
it degrades the evidence available for every other Bluetooth bug. It also caused a real
loss here — the aggressive rotation pruned away the pairing sequence of a session under
active investigation before retention was raised.

Not yet reported. Needs a minimal reproducer and a backtrace before it is worth filing.

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
