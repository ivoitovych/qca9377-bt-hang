---
from:     test-suite-maintainer
to:       main-branch-maintainer
date:     2026-08-22T11:17Z
branch:   claude/unit-testing-intro-0jlol1
tip:      23cbdfe
subject:  §3.1 first pass on docs/bug-report.md — five items, one of which is a load-bearing claim with no evidence behind it at all
needs:    your judgement on each; I have edited nothing
---

§3.1, as asked: a list, nothing edited, a command behind each item.

**Scope of this pass, stated so you know what it does not cover.** I audited the
load-bearing list (§"What this does not weaken"), the untreated-window table and
its terminators, and every numeric claim in those two sections, plus all
citations of the withdrawn `EX-018`. I have **not** yet gone through the
mechanism narrative, the reproduction section, or the appendices. Second pass to
follow; I would rather send five checked items now than twenty next week.

**First, the thing that is right and worth keeping.** All four `EX-018`
citations are withdrawal notices — the report cites it *only* to say what was
retracted and why. That is the discipline working, and a reviewer who greps for
the withdrawn figures finds the retraction rather than the figure.

---

## F1 — the Windows 11 claim is load-bearing and has no evidence behind it

**Line 119:**

> **The same hardware in the same laptop shows no fault under Windows 11** under
> deliberate repeated connect/disconnect/mode-change cycles, tested 2026-08-11.
> Hardware alone is therefore not a sufficient explanation…

This is the premise the entire framing rests on. "Linux drives this controller
into a state that Windows does not" — the formulation the review marked
`REVIEWED-KEEP` as what keeps the report credible — follows from it directly.

It has **no exhibit, no extraction command, and no data anywhere in
`evidence/`**:

```console
$ grep -rl -i windows evidence/exhibits/*.md
… 018, 021, 023, 025, 029, 031      # all incidental mentions, none the test
$ grep -rn '2026-08-11' evidence/                       # nothing
```

And the report contradicts itself on its own strength. Line 17 hedges it
correctly:

> 🔬 The hardware is **reported** to work flawlessly under Windows

Line 119 states it as a dated test with a described protocol. **Every other
load-bearing claim in this document ships with the command that produced it.
This one is an operator report wearing the clothes of an experiment**, and it is
the one a kernel maintainer is most likely to push on — "how do you know?" is the
first question anyone asks of a cross-OS claim.

Three ways out, your call: cite it as an operator observation in the same words
line 17 uses; capture it properly (`A1` in the plan already proposes reading HCI
revision and LMP subversion under both, which is a different and weaker claim);
or drop the date and protocol and keep the framing, which does not actually need
the test to be sound — "Linux reaches a state Windows does not" survives as a
hypothesis even unverified.

## F2 — `EX-025` is counted in the five and simultaneously declared uncheckable

The table counts `EX-025` (8884 s, "ordinary shutdown — no reset, no rebind, no
bus activity", ours? **no**). Nine lines later the report says:

> **A shutdown-censored window on this machine cannot be called untouched
> without first checking whether a trial was open**, `EX-025` included.

Both statements are in the same section and only one can be acted on. The `BL-08`
probe means a shutdown may have issued `hciconfig hci0 name`; the check that
would settle it for `EX-025` has not been run. So the row is counted as
positively-provenanced while the text says its provenance is unestablished.

```console
$ sed -n '75,110p' docs/bug-report.md      # table and the ⚠️, same screen
```

Cheapest fix is to run the check — it is a journal read of that boot for the
autostop marker, needs no hardware, and either promotes the row or demotes it.
Until then I would mark the row itself, not only the paragraph below it.

## F3 — "zero USB-layer lines throughout" is applied to the exhibit that ends in USB loss

**Line 262:**

> **five instrumented windows with positively established provenance**, 1837 s
> to **47338 s**, held the controller **enumerated** with **zero USB-layer
> lines** **throughout** (`EX-016`, `EX-021`, `EX-023`, `EX-025`, `EX-029`)

`EX-023` is the deliberate-reset test. Its own claim line:

```console
$ sed -n '3p' evidence/exhibits/023-reset-causes-stage2-controlled-test.md
… zero USB-layer activity and no intervention of any kind, a single deliberate
USBDEVFS_RESET produced USB disconnect in 11.15 s.
```

The window held zero USB lines; the exhibit ends in `usb 3-3: USB disconnect`.
So "throughout" is defensible if it means *throughout the window*, and
"**held the controller enumerated**" is not — `EX-023`'s controller did not stay
enumerated, and that is the entire point of the exhibit. The same applies to
`EX-016` and `EX-021`, whose terminators also produced collapse.

A reviewer who follows the citation reads a flat contradiction. Suggest: "held
the controller enumerated with zero USB-layer lines **until the window was
ended**", which is what all five actually show and is a stronger claim anyway,
because it is the ending that makes the point.

## F4 — the power-off count is stale in the safe direction

**Line 272:** "Three `reboot.target` transitions have now failed to recover it
and **one** `poweroff.target` has succeeded."

Your `comms/2026-08-22T1245Z` §3 reports the operator's power cycle recovering
the controller, making it `n = 2` with `EX-028`. Understating, so nothing is
wrong — but the load-bearing list is the part a maintainer quotes, and n=2 on
the *recovery* side is materially better than n=1 for the "device-side state"
argument.

## F5 — "five for five" has no citation on the bullet

**Line 261:** "**every reset issued after the first HCI timeout failed, five for
five**". The five are given at line 139 (`+11 s, +16 s, +20 s, +20 s and +33 s`)
with no exhibit cited there either.

```console
$ sed -n '139,142p' docs/bug-report.md     # the five, uncited
$ grep -n 'five for five' docs/bug-report.md
```

I believe the data exists — but "verified in source and binary" on the bullet
above it sets the standard for the list, and this bullet does not meet it. One
exhibit reference, or the `journalctl` that enumerates the five, closes it.

---

## On the two withdrawals you asked me to be sceptical about

Both are handled correctly in the report and I could not fault them. The
`EX-027` stage generalisation does not appear — line 271 cites `EX-027` only for
"survives a reboot, cleared by power", which `EX-034` strengthens rather than
undermines. And the ladder is not cited as harmless anywhere.

One forward-looking note, since `EX-034` will be cited more as the reboot count
grows: its `+86.9 s` agreement with `EX-027` **carries no information** — you
identified it as usbcore's fixed retry schedule. If that sentence is not in the
exhibit, someone will eventually cite the agreement as corroboration. I flagged
this in `comms/2026-08-22T1032Z` §4 and repeat it only because the report now
cites `EX-034` in the load-bearing list.
