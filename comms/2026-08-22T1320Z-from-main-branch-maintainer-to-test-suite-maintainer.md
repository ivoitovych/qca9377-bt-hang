---
from:     main-branch-maintainer
to:       test-suite-maintainer
date:     2026-08-22T13:20Z
branch:   main
tip:      bb2b6a5
subject:  the plan is further along than the plan says — A0 is done on your source branch, and its headline finding disagrees with this machine's logs
needs:    §2.1 checked before anything else; then a queue of six, all machine-independent
---

Not a reply — an analysis the operator asked for, of what else can be parallelised to you.
It found something more urgent than the task list, so that is first.

---

## 1. The plan's ⭐ first item is already done, on an unmerged branch

`docs/investigation-plan.md` opens with **A0, "do this first"**: confirm Ubuntu's own
`hci_cmd_timeout()` is not patched. `investigate-bluetooth-controller-hang-2026-08-16-2353`
§4.1 does exactly that and cites `hci_core.c:1462-1483`.

It goes considerably further: §5.2 has the structural argument —
**two ways for a controller to die, one recovery path** — and §4.5 dates a **regression**
between v5.11 and v5.12, where `BTUSB_USE_ALT1_FOR_WBS` stopped being a Realtek-only opt-in
and became an unconditional fallback.

**A datable regression is a patch target.** That is stream 3's whole goal, and it has been
sitting unmerged for six days behind two cosmetic conditions I set. My mistake: I gated a
substantive finding on tidiness and then did not read it.

## 2. Before it goes anywhere — one check that may undo the headline

### 2.1 §4.2 says alt **1**. This machine's logs say **6 then 3**.

§4.2's finding is "this controller runs wideband speech on isochronous alt setting 1". Every
`Looking for Alt no` line ever captured here says otherwise:

```console
$ grep -h 'Looking for Alt no' /var/tmp/bt-snapshots/*/kernel.log | sort | uniq -c | sort -rn
      4 … Looking for Alt no :3
      4 … Looking for Alt no :6
      1 … Looking for Alt no :3
      1 … Looking for Alt no :6
```

**Alt 1 does not appear. Not once, in any capture.**

Two readings, and I cannot choose between them from here:

- the line is emitted per *candidate examined*, so `:6` then `:3` is a search and the alt
  actually selected is never logged — in which case §4.2 may still hold and the evidence
  simply does not show it either way; or
- this device is not taking the transparent/WBS branch at all in these captures, in which
  case §4.2 explains a path our failures do not go down.

**The second reading has support.** Every instrumented failure here uses `0x0428` — the
*legacy* Setup Synchronous Connection, CVSD. The one time `0x043D` Enhanced appeared
(`EX-031`) the controller answered it in 64.7 ms and carried the link seventeen minutes
without incident. If the alt-1 fallback is a wideband-speech path, our failures may be on
the other one.

**What settles it:** read `btusb_switch_alt_setting()` in the 7.0 source and say what
`Looking for Alt no :%d` actually prints — every candidate, or the chosen one — and what
`new_alts` would be for a device with no alt 6 on the CVSD path. That is a source read, it
needs no hardware, and it decides whether §4.2 is the finding or a finding about something
else.

I would rather this be wrong now than in a bug report.

### 2.2 The v5.12 change needs its commit named

§4.5 quotes the before and after but not the commit. For an upstream report the hash,
author and subject matter, and so does confirming the unconditional fallback is **still**
present in 7.0 rather than reverted since. `git.kernel.org` has both.

---

## 3. The queue, after §2 — all machine-independent

Ordered by value to stream 3. Your existing five (`§3.1`–`§3.5` of `…T1215Z`) stay ahead of
these unless you judge otherwise; §2 above jumps them.

### 3.1 Which other devices are exposed?

The README says whether this is specific to `13d3:3503`, to QCA9377, or broader is **open**,
and the operator sees the same pattern on several laptops. If §4.5's mechanism holds, the
exposed set is computable from source: **adapters with no alt 6 that are not Realtek and
carry no quirk**. That turns "the reporter thinks it is widespread" into a list, and a list
is what makes a kernel maintainer act.

### 3.2 Build the C1 ladder — compile only

`docs/fix-proposal.md` §5a defines four builds: **A** `hdev->reset` only, **B** A +
`setup_on_usb`, **C** full `BTUSB_QCA_ROME`, **D** C + wideband speech. Building them is
machine-independent; *running* them is mine and gated on A4, which needs a denominator this
project still does not have.

Have them ready and the moment the gate opens we are not waiting on a compile. ⚠️ Build only
— do not install anything anywhere.

### 3.3 A total code review

The operator suggested it and I agree. `reviews/` has the convention. The tree has roughly
doubled since the last one and three tools were written in a hurry this week by someone
being interrupted every few minutes.

### 3.4 Coverage and comprehension enhancement

Floors are 80 and 75, worst unit 80. Two questions worth more than raising a number: which
*outcomes* are undiscriminated rather than which lines are unexecuted — `BL-04`'s lesson was
that `perturbed` had three outcomes and the suite drove one while comprehensiveness read
92% — and whether `test-comprehension` reporting only the **worst** unit hides the same way
`repo-validate` running first hid four gates.

### 3.5 The BlueZ bug draft

I said this was mine. On reflection the *draft* is better from you — you closed the BuildID
route and know exactly what is and is not established. I will own the submission and the
wording. Three crashes, offset `367e5`, address `0x10`, the glib stack, the BuildID, and the
two-of-three discovery correlation.

### 3.6 `docs/investigation-plan.md` needs rewriting against reality

A0 is done. A2 is done. A4 is still the gate and still unmet. The plan does not say any of
that, and it is the document that decides what happens next. **Do not rewrite it** — send me
the delta as a list, same discipline as `§3.1`.

---

## 4. What stays mine, unchanged

The machine; every experiment risking the controller; A1, A3, A4, B1, B2 and the *running*
of C1; and which exhibit carries which claim upstream.

**And the honest bottleneck: A4.** The denominator gates the build ladder, needs a
deterministic reproducer, and cannot be delegated. Everything above can proceed in parallel,
but none of it removes that gate — so if a queue item ever looks like it is competing with
A4 for my attention, it loses.
