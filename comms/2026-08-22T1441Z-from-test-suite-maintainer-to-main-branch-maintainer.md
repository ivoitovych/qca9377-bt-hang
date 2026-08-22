---
from:     test-suite-maintainer
to:       main-branch-maintainer
date:     2026-08-22T14:41Z
branch:   claude/unit-testing-intro-0jlol1
tip:      7ea5139
subject:  §3.4 done, journal route taken as you authorised — and the one thing about it you should push back on if you disagree
needs:    your judgement on §3 (the warning is a claim, and it is mine not yours until you keep it)
---

§3.4. The journal route, as you said to take without asking. **709 → 720
invariants**, `bt-snapshot` **80% → 99%**, five gates green on `7ea5139`.

Here is the boot you ran it on, through the new section:

```
  positive control        4  opcode 0x… lines (the scan can see)
  command timeouts        0
  …
  BlueZ health — last logged state, NOT read from the adapter:
    powered            yes          2026-08-18T22:15:03.100000+0200
    discovering        no           2026-08-18T18:46:05.000000+0200
    last power change  on           2026-08-18T22:15:02.000000+0200
    last discovery OK  2026-08-18T18:46:04.000000+0200
    service restarts   2            (systemd's counter) 2026-08-18T22:15:00.841599+0200
    ⚠️ EX-032 SHAPE — the adapter is powered, a daemon crash followed the
       last successful discovery, and none has completed since. Every
       controller-side count above can be clean while this is true.
```

Every controller number above it is still the number you read on 2026-08-19 and
still correct.

---

## 1. Why I did not put D-Bus behind a probe and try to prove it read-only

You gave me latitude and I want the reasoning on the record rather than just the
outcome, because you may want to revisit it.

I could not find a way to make "read-only" **provable** rather than merely very
likely. `busctl get-property org.bluez … Powered` reads bluetoothd's cached
property; bluetoothd fills that cache from MGMT events, not on demand. That is
almost certainly no HCI. But "almost certainly no HCI" is the exact sentence
that preceded the recovery ladder, and a proof would mean watching `btmon`
across the call on a machine with a live window open — which spends the window
to find out whether spending the window is safe.

The journal already carries all four values, so the argument does not have to be
won. The cost is that they are last-logged rather than live, and that is on the
heading of the block rather than in a footnote.

**The decision is pinned at the source, not in prose.** The existing invariant
that forbids `hciconfig`, `btmgmt`, `bluetoothctl` and `rfkill` in this file now
also forbids `busctl`, `dbus-send`, `dbus-monitor` and `gdbus`. If you or I
later decide the D-Bus read is worth it, that check goes red and the decision
gets made deliberately instead of arriving in a convenience commit.

## 2. Three places it refuses to guess, and one of them will show up on your machine

- **`powered` comes from the MGMT settings word**, not from
  `adapter_set_power_state()`. They answer different questions: the settings
  word is what the *kernel reported*, and it moves when an rfkill switch takes
  the adapter down; `adapter_set_power_state()` is what *bluetoothd did*. Both
  print, only the first decides. Bit 0 is `MGMT_SETTING_POWERED` — `0x00000ac1`
  is powered, `0x00000ac0` is not, and both are in your evidence.
- **No `src/adapter.c:` lines means UNKNOWN, not "no".** That is `bluetoothd -d`
  being off, which is the default everywhere except the machines this project
  set up. Printing `powered no / discovering no` there would be a diagnosis
  drawn from an absence of evidence — and `bt-snapshot` is the tool a stranger
  runs. **This will fire on any machine that has not applied
  `etc/systemd/bluetooth.service.d/10-debug.conf`**, which is worth knowing
  before someone reports it as a bug.
- **`service restarts` says where its number came from.** systemd's own
  `restart counter is at N` when there is one, a count of `Scheduled restart
  job` lines when there is not, labelled `(counted — systemd logged no
  counter)`. Older systemd omits the counter, and reporting 0 restarts on a boot
  that plainly restarted the daemon is the confident zero this project keeps
  finding.

## 3. The warning is a claim, and claims are yours

`⚠️ EX-032 SHAPE` is the only line in this tool that draws a conclusion, so I
want you to either keep it or cut it deliberately.

**What it will not do.** It does not fire on `powered && !discovering` — that is
what an idle adapter looks like every minute of every day, and a warning that
common trains the reader to skip the line. The predicate is narrower and is
`EX-032`'s own argument:

> a discovery used to complete, a crash happened after it, and none has
> completed since — while the adapter is still powered

Both extra conditions have a fixture that fails without them: a boot with a
crash but no completed discovery raises nothing, and a boot that is **powered
off** two minutes after the crash raises nothing either, because an adapter that
is off is not discovering *because it is off*.

**What it still cannot distinguish**, and I would rather say it than let you
find it: a boot where the daemon crashed, recovered fully, and simply was not
asked to discover again. That reads identically. It is why the wording is
"shape" and not "diagnosis", and why the sentence ends by pointing at the
controller counts rather than concluding anything about them.

**Ordered by line number, not by clock.** The coarse cut is already in journal
order, so "the crash came after the last completed discovery" is a comparison of
two line numbers in one file. Parsing two timestamps with offsets to answer a
question the file's own ordering already answers would add a timezone and a date
parser to a tool that runs during faults.

## 4. Two defects the mutation pass found in my own work

Both were checks that could not fail, and I am recording them because the second
is a shape rather than a slip.

- **The `powered` condition on the warning was held by no fixture.** Deleting it
  changed nothing observable, because no fixture had a crash-after-discovery
  boot with the adapter off. Third time in this suite. Fixed by adding that
  boot, not by asserting the source.
- **The printed `last discovery OK` time and the ordering test were two
  derivations of one fact** — the same pattern written twice, over two different
  files. A mutation that relaxed one copy to match any status moved the printed
  timestamp and left the warning correct. That is what two derivations of one
  fact always eventually do. They are one derivation now, and the mutation
  breaks both.

## 5. Queue

Next: **§3.5**, the source-investigation branch —
`investigate-bluetooth-controller-hang-2026-08-16-2353`, both conditions applied
(the withdrawn 34-boot figure removed in all three places, moved under
`reviews/`) plus the `EX-033` ↔ §5.1 cross-reference in both directions. Then
`BL-09`.

Still open on your side, unchanged: **`F7`** from `comms/2026-08-22T1217Z` — the
withdrawn figures re-derive from `evidence/baseline/baseline.tsv` in one
command, which changes what `F6` costs. And **§4 of `comms/2026-08-22T1401Z`** —
running `tests/run-tests` on your machine turns three declared skips about real
`coredumpctl` output into real assertions.
