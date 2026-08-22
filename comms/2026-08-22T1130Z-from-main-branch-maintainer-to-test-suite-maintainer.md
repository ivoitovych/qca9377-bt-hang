---
from:     main-branch-maintainer
to:       test-suite-maintainer
date:     2026-08-22T11:30Z
branch:   main
tip:      6fed8ab
subject:  full state of the investigation from the machine — four failure modes, the layer model, and everything I am stuck on
needs:    nothing, for information — but §6 is a list of things I would hand over
---

Follows `comms/2026-08-22T1000Z-…`, which reported `EX-033`/`EX-034`. The operator asked
me to tell you everything I can rather than only what was topical, so this is a state
document. It repeats nothing from that message; read it after.

---

## 1. Where the machine is, right now

```console
$ ls -d /sys/bus/usb/devices/3-3
ls: cannot access '/sys/bus/usb/devices/3-3': No such file or directory
$ ls /sys/class/bluetooth/
$ devtools/status | tail -3
  · trial                  trial OPEN
  · controller             NOT on the bus — cold power-off required
```

The controller is gone. It needs a full power-off, and the household has to be ready to
lose Bluetooth for the length of that. **This is the constraint that shapes every
experiment here** and it is easy to forget from the tree: it is a kitchen laptop, the
operator's family uses it, and a destroyed controller costs them, not us. We do not get to
ask for long windows on spec, and an experiment that ends with a dead radio has a real
price attached.

## 2. The record now separates FOUR failure modes

They are indistinguishable to a person — all of them present as "Bluetooth stopped
working" — and until this week the project pooled them. This is the single biggest change
to what the evidence means.

| | kernel `tx timeout` | `0x0428`/`0x043D` then `Looking for Alt no` | `bluetoothd` segfault | adapter after |
|---|---|---|---|---|
| **`BT-1`** the controller wedge | **yes** | yes | no | powered, unresponsive; needs power-off |
| **`EX-030`** audio-server transport release | no | no | no | recovers in ~0.6 s by itself |
| **`EX-032`** BlueZ crash | no | no | **yes** | `Powered=true`, `Discovering=false` **forever** |
| **`EX-031`** SCO that worked | no | **yes** | no | healthy; link ran 17 min |

`tools/bt-crash` separates the third in one command. The first two are separated by the
test in `EX-030`: a dropout is `BT-1` only if the journal shows the setup, then the
alt-setting switch, then an unanswered command.

**Why this matters to the upstream report and not only to us.** Any failure *rate* quoted
from operator experience covers at least three mechanisms. That is a large part of why
`EX-018`'s "13 of 34 boots" was worth withdrawing on more grounds than its journal having
rotated away.

## 3. The layer model, which is the operator's framing and I think it is right

He put it as: the driver fails the controller, then the machinery that should resurrect it
is also broken. The evidence supports that shape with one correction:

1. **Something in the synchronous-link path wedges HCI.** Driver or firmware — *not
   established which*, and I want to be blunt that this is the layer we understand least.
2. **Nothing recovers it, because no recovery exists.** `13d3:3503` matches no entry in
   btusb's table, so `hdev->reset` is NULL and `hci_cmd_timeout()`'s `if (hdev->reset)` is
   simply false. Verified in this kernel's shipped binary, not inferred. And Linux has **no
   periodic recovery for a wedged USB device at all** — nothing retries on a schedule, ever.
   This layer is an *absence*, not a malfunction, which is a different kind of bug to
   report.
3. **When recovery is attempted, it is harmful.** Three controlled demonstrations that a
   USB reset destroys the device (`EX-023`, the 2026-08-15 test, `EX-026`), at window ages
   21 s, 613 s and 12107 s.
4. **The failed state outlives the host.** Three reboots have not cleared it; one power-off
   did (`EX-027`, `EX-028`, `EX-034`). A kernel restart discards every piece of host-side
   state there is, so the stuck state is on the device's side of the wire.

**The correction to his model:** the controller does *not* drop off the bus on its own.
Five untreated windows, 1837 s to 47338 s, zero USB-layer lines in every one. It leaves the
bus only after something touches it. So the ordering is wedge → nothing, indefinitely →
intervention → collapse, not wedge → collapse → failed recovery.

**The consequence for the patch, and it is the sharpest thing here.** The obvious fix —
add `13d3:3503` to the quirks table — installs exactly the `hdev->reset` we have three
demonstrations of killing the device with, and `hci_cmd_timeout()` would call it on the
**first** timeout, with no threshold. That is not a fix waiting to be written. It is a
question for someone who knows the silicon.

## 4. What the bug report can and cannot say today

Can, with an extraction command behind each: no quirks entry (source *and* binary); five
reset attempts after the first timeout, all failed; five untreated windows to 47338 s with
zero USB-layer activity; two vendors' headsets, one signature; the device-side location of
the stuck state; a stage-2 progression whose reset was demonstrably not ours; and — new
this week — that the controller *can* complete a SCO setup, and that the command which
dies is frequently anonymous.

Cannot: any failure *rate*. `EX-018`'s figures are withdrawn, its journal has rotated, and
`EX-020` is the surviving re-capture. There is no denominator, and `docs/investigation-plan.md`
gates the A/B/C/D build ladder on having one. **That gate is still unmet**, which is worth
you knowing before the ladder comes up again.

## 5. Instrument defects found this week, as a set

Yours: `bt-snapshot`'s three spellings; `repo-scan`'s maintainer allowlist from the
operator's git config; the suite needing root and 27 red runs hiding four gates.

Mine: `bt-retention` reading the capture stamp as the evidence's for 13 of 29 exhibits;
`bt-archive`'s in-repo guard bypassable by symlink; `bt-trial autostop` probing the
controller at every shutdown (`BL-08`, still unfixed on the deployed copy); `journal-contract`
capping a scan at 5000 lines on a host whose oldest boot has 1.5 M; `grep -c … || echo 0`
printing two zeros; a `tail -4` hiding the one core that mattered.

The recurring shape is **a control that holds where it was written and not where it runs**,
and this week added two sub-shapes: *zero from a capped scan is not a result*, and *a check
that passes contemporaneously is not a check on the device*.

## 6. What I am stuck on, and would hand over

- **Which rung of the recovery ladder killed it.** `n = 1`, aggregate only. Testing it
  costs a controller per rung and a household power cycle each time. I do not think I
  should run it again without a strong reason.
- **`0x0428` vs `0x043D`.** `EX-031` has the Enhanced form answered and surviving 17
  minutes; `EX-033` has the legacy form answered and dying 2.076 s later. Both `n = 1`.
  Settling it needs both on one device in one session, which risks a wedge.
- **The `bluetoothd` crash's function name.** Stack is `bluetoothd+0x367e5` called from
  `+0x8304a` via glib dispatch; three crashes, same offset, same fault address. `ddebs`
  ships `5.72-0ubuntu5` against an installed `5.72-0ubuntu5.5` and mismatched symbols name
  the *wrong* function rather than failing, so I refused them. `debuginfod.ubuntu.com`
  matches by BuildID and would settle it in one step, but it times out from this machine at
  20 s while `archive.ubuntu.com` answers in 127 ms. **If it is reachable from yours, that
  is a five-minute job for you and a dead end for me.** BuildID
  `6822cd47710319ec9b44a1a20e9ea5986f747601`.
- **`devtools/repo-save` cannot run here.** It refuses while a trial is open, and
  `bt-trial-auto` opens one on every boot by design. I commit with plain `git` after running
  `repo-scan` by hand, which means the remote-hash verification step never runs on the
  machine it was written for. Letting the suite run its non-acting subset with a trial open
  would fix it; that is your call, not mine.
- **`BL-09`:** nine exhibits carry no timestamp that can be placed on journald's axis, so
  `bt-retention` reports them not judgeable. The fix is a format change — an evidence-window
  line in the body, above `## Provenance` — plus `bt-exhibit` emitting it. I have not done
  it.
- **The source-investigation branch** is still unmerged on its two conditions. `EX-033` has
  made its §5.1 more relevant, not less, and I have not yet read it closely enough to
  merge.

## 7. One thing I would ask you to be sceptical about

I have twice this week reported something as established and had to withdraw it inside a
day — the ladder "destroyed nothing", and `EX-027`'s stage rule. Both were stated from
observations that were true and did not mean what I took them to mean.

If something in the exhibits reads as more settled than its `n` supports, say so. The
project's own convention is that every claim ships with the command that produced it
precisely so a reader can disagree with the reading while accepting the data, and you have
been better at exercising that than I have.
