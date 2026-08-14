# The suite escaped its sandbox and closed a live trial — postmortem

**Written** 2026-08-14T13:28Z · **Fixed in** `251a6cb` · **Reported by** the maintainer,
from a run on the investigation machine

**Summary.** Running this branch's test suite on the investigation machine closed a live
2-hour trial, wrote a results row whose treatment fingerprint was fabricated by test
stubs, and ran a real `bt-incident` collection into `evidence/sessions/`. It is my
defect. The mechanism was not a missing environment override, and the invariant written
to prevent exactly this could not see it.

---

## 1. What happened

| | |
|---|---|
| 13:04 | boot opens trial `stock #2` automatically; runs clean for 2 h 03 m |
| 15:08:02 | the suite is run on the machine to measure its coverage |
| | the trial is closed, a results row written, a `bt-incident` collection created |

The row's treatment field read
`autosusp=Y,power=?,wd=late/thr?,probes=on` — `wd=late/thr?` from the suite's **stubbed
systemctl**, `power=?` from its **fake sysfs tree**. Nothing had actually started: both
services were inactive and the watchdog journal was empty. The fingerprint was
manufactured by mocks and written into the real results file.

The maintainer removed all three artifacts. No observation was lost — the journal holds
everything — but the boot's window is no longer tracked as a trial, and `bt-trial-auto`
opens one only at boot.

---

## 2. The mechanism

`bin/bt-hang-watchdog`, on the device-absent path:

```sh
if command -v bt-trial >/dev/null 2>&1; then
    bt-trial hang >/dev/null 2>&1 && log "  auto-trial closed as HANG"
fi
```

**A bare name, resolved from `PATH`.** The watchdog scenarios put a stub directory on
`PATH` for `systemctl`, `sleep` and `hciconfig`, and pass `BT_SYSFS_USB`. They never
redirected `bt-trial` — because `bt-trial` is not called by the test. **It is called by
the tool under test.** So the real `bt-trial` ran with the real `BT_STATE` and the real
`BT_REPO`, while inheriting the stubs that supplied its treatment fingerprint.

### Why the existing invariant missed it

```sh
LOOSE=$(grep -nE 'tools/bt-trial +(autostart|start|ok|hang|abort|step)\b' "$0")
```

It scans **this file** for `bt-trial` invocations. The call is not in this file. The
invariant was written against the shape of the last escape — a test calling the tool
directly — and the next one had a different shape.

### Why it was invisible on a development checkout

Nothing is installed here, so `command -v bt-trial` finds nothing, the `&&`
short-circuits, and the escape cannot occur. **The suite is green and the defect is
real.** It fires only where the tools are installed, which is the investigation machine,
which is the one place it must never fire.

---

## 3. Worse than reported

The trial sandbox stubs `bt-incident`, `hciconfig`, `journalctl` and `systemctl`. It does
**not** stub `bt-mark`, which the real `bt-trial` invokes by bare name three times per
lifecycle and which runs:

```sh
logger -t bt-mark -p user.notice "$MSG | usb=… hci=… responds=… connected=…"
```

So on the investigation machine every `trial()` call in this suite **injected
operator-action markers into the evidence journal** — nine per run, reading
`TRIAL stock #1 RESULT: survived` and similar. `bt-timeline` and `bt-actions` classify
exactly those lines as things a person did.

This was found by the fix, not by the report: with poisoned tools placed behind the guard,
the decoy log named every bare-name call the suite makes.

---

## 4. The fix

**A guard, not another stub.** Adding `bt-trial` to one stub directory fixes one scenario.
The shipped tools invoke five project tools by bare name — `bt-trial`, `bt-incident`,
`bt-mark`, `bt-state`, `bt-timeline` — any of which a future test could reach the same
way.

Every legitimate invocation in the suite uses an explicit path (`tools/bt-trial`,
`bin/bt-hang-watchdog`). **A bare name resolving during a test run is therefore an escape
by construction**, and can be intercepted rather than reasoned about case by case. The
suite now prepends a directory of recording stubs for all five, with the list **derived
from `command -v bt-*` in the sources**, so a bare-name call added tomorrow is guarded
without anyone remembering.

**And a decoy**, because without it the guard cannot be tested where it matters. Reversing
the guard's `PATH` order changed no result at all on this checkout. Poisoned tools now sit
*behind* the guard, standing in for the installed copies, so any machine reproduces the
investigation machine's arrangement. That mutation now fails three invariants on a bare
checkout.

**And the escape became a tested decision.** The watchdog *should* close the boot's
auto-trial on the hard-hang path — leaving it to the shutdown hook would record a
meaningless duration after the machine has sat dead for hours. The spy log proves the
decision was taken; the guard proves it did not reach the real tool.

---

## 5. The maintainer's other findings

| Finding | Disposition |
|---|---|
| Four `./install.sh` dry runs called bare, exiting 3 in experiment mode | **Fixed.** All routed through `install_dry()`, which sets `BT_MODE_STAMP`. A dry run's contract is "print what would happen and change nothing", and it must hold whatever mode the machine is in. The mode guard keeps its own test. |
| `[[ ! -e /root/exp/qca9377-bt-hang ]]` — a broken assertion | **Replaced.** It was wrong in both directions: vacuous on a checkout living elsewhere, and *unsatisfiable* where the repository IS that path. Now asserts the property the defect actually had — an explicit `BT_EVIDENCE_REPO` must survive a target with no `evidence/` subtree — plus a source-level scan for the fallback shape that caused it. |
| `INSTALL_STAMP` created and never used | **Not reproduced.** It is used, in the write-detection `find -newer`. Their reading was of the older tip `032f081`; on the current tip it is live. |
| `phase.awk` carrying pre-correction statistical wording | **Already fixed** in the `origin/main` merge (`11c4042`) before this report arrived. |

---

## 6. What I got wrong, stated plainly

**The invariant I wrote to prevent this was shaped like the last escape.** It enumerated
call sites in the test file, and the comment above it even says enumeration is what failed
last time — then enumerated a different thing. The general property ("no bare name may
resolve to an installed tool") was available and I did not reach for it.

**I never ran the suite anywhere it could fail.** Every measurement in this branch was
taken on a checkout with nothing installed. That is the configuration in which this class
of defect is undetectable, and I treated a green run there as evidence about all machines.
The decoy exists because of that: the hazard now has to be **constructed**, not inherited
from the environment.

**Two of my own assertions have now been found unable to fail for environmental reasons**
— this one and the `/root/exp` check — on top of the five found unable to fail for
logical reasons. The pattern is the same: a check that passes because of where it runs
rather than because of what the code does.

---

## 7. Recommendation

The suite is safe to run on the investigation machine again **after** this fix, and the
decoy makes that claim testable rather than asserted. But the honest advice remains:

**Run it in a worktree, not in the live checkout.** The guard closes the bare-name class;
it does not make the suite a read-only observer of the machine, and it never will while
the suite's job includes driving tools that act. `evidence/sessions/` is watched by the
suite itself, and that observation caught a contamination during this very fix — three
directories appeared while mutation-testing, and the count check named it.

The `bt-mark` journal injection is worth one further note: entries already written on the
investigation machine by earlier runs of this suite are indistinguishable from real
operator marks except by timestamp. They read `TRIAL <build> #<n> RESULT: <outcome>` and
cluster at suite-run times. Anyone reconstructing a timeline across 2026-08-13/14 should
know they are there.
