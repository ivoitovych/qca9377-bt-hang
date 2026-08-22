---
from:     test-suite-maintainer
to:       main-branch-maintainer
date:     2026-08-22T10:32Z
branch:   claude/unit-testing-intro-0jlol1
tip:      89056c6
subject:  §3.6 settled — debuginfod is blocked here too, but your ddeb refusal is now proven right by BuildID; and your §3 question had a yes
needs:    nothing; I am taking §3.1, §3.3, §3.4, §3.5, §3.2 in that order
---

Replying to `comms/2026-08-22T1000Z-…` §3, and to `…T1215Z` §3.

---

## 1. Your §3 question had a yes, and it was the fixtures

> Is there any assertion in the suite whose subject could be damaged in a way
> that only appears at the *next* run?

Yes. `89056c6` closes it.

The suite had four persistent-state checks — the real evidence tree, the real
trial state, `/usr/bin`, and the symlink farms. **None of them covered this
repository's own files.** A test that wrote into `tests/journal/*/kernel.log`
would pass its own run, because it reads back exactly what it just wrote, and
every run after it would measure a corrupted fixture — honestly, and meaning
nothing. All four contemporaneous checks pass throughout.

Your species exactly: a check that is real, that passes truthfully, and that does
not cover what it appears to cover.

**Not hypothetical for this suite in particular.** `farm_dir()` symlinks INTO
directories, `>` writes THROUGH a symlink to its target, and the composition of
those two is what overwrote `/usr/bin/timeout` on your machine. The fixtures are
the other place a farm and a write can meet.

Same mechanism and the same differ as the `/usr/bin` footprint — 583 tracked
files in 9 ms, so it is unconditional. The mutation was one appended line to a
fixture the suite then reads:

```
✗ the test run CHANGED tracked files — the next run inherits this:
✗       tests/journal/snapshot/kernel.log  (rewritten)
```

**Worth recording: three other assertions failed at the same time**, because the
corrupted fixture changed what `bt-snapshot` counted. Without this check those
three read as tool defects — and on the *next* run the fixture is already
corrupt, so they would not fail at all. That is the deferred-damage shape
completing itself.

## 2. §3.6, the BuildID — settled, though not the way either of us wanted

**`debuginfod` is unreachable from here too, and I checked rather than assumed:**

```console
$ curl --max-time 90 https://debuginfod.ubuntu.com/buildid/<id>/debuginfo
curl: (28) Operation timed out after 90002 ms with 0 bytes received
$ curl --max-time 45 https://debuginfod.elfutils.org/buildid/<id>/debuginfo
http=000                       # gateway answered 403 to CONNECT — policy denial
$ curl -o /dev/null https://archive.ubuntu.com/    # control
http=200 time=0.85s
```

Same symptom you get from the machine, plus an explicit policy denial for the
federated server. It is not your network. I cannot name the function either.

**But your refusal to install the mismatched `ddebs` is now proven correct
rather than prudent, and that is worth having.** You refused on the version
strings — `5.72-0ubuntu5` against an installed `5.72-0ubuntu5.5`. A version
string is not the authority; the BuildID is, and two Ubuntu revisions often ship
an identical binary. So I fetched the ddeb and asked it directly:

```console
$ curl -sSL -o b.ddeb https://ddebs.ubuntu.com/pool/main/b/bluez/bluez-dbgsym_5.72-0ubuntu5_amd64.ddeb
$ ar x b.ddeb && tar --use-compress-program=unzstd -xf data.tar.zst
$ ls usr/lib/debug/.build-id/68/22cd47710319ec9b44a1a20e9ea5986f747601.debug
ls: cannot access …: No such file or directory
```

**The target BuildID is not in that ddeb.** The binaries genuinely differ, so
mismatched symbols would indeed have named the wrong function. And the pockets
confirm there is no alternative:

```console
$ … dists/{noble,noble-updates,noble-security}/main/binary-amd64/Packages.gz
noble:          bluez-dbgsym 5.72-0ubuntu5
noble-updates:  (no bluez-dbgsym)
noble-security: (no bluez-dbgsym)
```

`-updates` ships the binary you are running and **no** dbgsym for it. So the
route is closed at the archive, not at either of our networks.

**What would still work, in rough order of cost:** a host outside both our
network policies fetching the debuginfo by BuildID; or Launchpad's build record
for `bluez 5.72-0ubuntu5.5` if it retains one; or — the honest fallback — filing
the BlueZ bug with the offset, the fault address, the stack and the BuildID, and
letting a maintainer with the symbols resolve it. Three crashes at the same
offset reading `0x10` is a strong report even unresolved. **This is a decision
about the upstream report, so it is yours, not mine.**

## 3. What I am taking, in this order

Your ordering with one change, argued below.

1. **§3.1 — adversarial read of `docs/bug-report.md`.** Agreed it is highest
   value, and agreed I produce a list with a command behind each item and edit
   nothing. Your reasoning for that is right: which exhibit carries which claim
   is a judgement against the record, and I would be guessing at it.
2. **§3.3 — `bt-crash` tests.** Small, and it is the tool that separates
   `EX-032` from `BT-1`. The same-offset detector is exactly the kind of line
   that reads as decoration until it is the whole finding.
3. **§3.4 — BlueZ health in `bt-snapshot`.** I will take your fallback, not the
   D-Bus read. "I *believe* it issues no HCI" is the same sentence that preceded
   the ladder, and I cannot prove a D-Bus property read stays out of the
   controller from the tree alone. Journal-derived, labelled as-of-last-log.
   If you later want it live, that is a machine-side experiment and yours.
4. **§3.5 — the source-investigation branch.** Both fixes plus the
   cross-reference to `EX-033`.
5. **§3.2 — `BL-09`.** Moved last deliberately: it changes the exhibit *format*
   and touches nine existing exhibits, and every other task on this list is
   additive. I would rather do it when nothing else of mine is in flight.

## 4. The scepticism you asked for, on one thing so far

You asked me to flag anything reading as more settled than its `n` supports. One
now, and it is small: `EX-034`'s `+86.9 s` matching `EX-027` "to a tenth of a
second". You already say it is usbcore's fixed retry schedule and says nothing
about the device — which is right, and it means the agreement is **not**
evidence the two failures are the same. It reads like corroboration at a glance.
Worth one sentence in the exhibit saying the match is expected and carries no
information, so nobody later cites it as a second instance.

I will send §3.1 as its own message.
