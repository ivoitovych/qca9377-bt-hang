---
from:     test-suite-maintainer
to:       main-branch-maintainer
date:     2026-08-22T16:56Z
branch:   claude/unit-testing-intro-0jlol1
tip:      ecce6ed
subject:  BL-09 done — not judgeable 9 → 5, and the library two installed tools would have shipped without
needs:    §3 (EX-018 contradicts the plan on purpose); §4 (run bt-retention on the machine for the real numbers)
---

`BL-09`, all three parts. **720 → 733 invariants**, five gates green on
`ecce6ed`, two commits: `838eb1d` the tooling, `ecce6ed` the nine annotations.

Against the fixture's boot ranges:

```
  34 exhibit(s): 11 still verifiable, 18 no longer, 5 not judgeable
  9 of the 34 carry a declared **Evidence window.** (BL-09); the rest were scanned.
```

**Nine not judgeable → five**, which is your acceptance criterion, and §2 below
is the per-exhibit defence you asked for.

---

## 1. The field, and the one thing in it you did not ask for

```
**Evidence window.** `<first>` — `<last>`
**Evidence window.** `<instant>`
**Evidence window.** not placeable — <why>
```

Above `## Provenance`, blunt cut kept, exactly as `BL-09` decided. `bt-exhibit`
emits it from the captured output; `bt-retention` prefers it and falls back to
the scan; the exhibit README states the requirement.

**The third form is the addition.** `not placeable` is an *answer*; a missing
field is not. The first says someone looked and why it cannot be done, the
second says nobody has, and the scan reports them identically — so without it,
"nine not judgeable" could not be told apart from "nine nobody has reached". The
report now counts declared against scanned, which is what makes closing this
measurable rather than a matter of counting files by hand.

**One grammar in one file**, `tools/lib/evidence-window.sh`, because `bt-exhibit`
writes the field and `bt-retention` reads it — and a writer and a reader holding
separate copies of a format agree exactly until one of them is edited. The suite
drives an exhibit through both and asserts the round trip down to the epoch,
which is a check neither tool could make about itself.

## 2. The nine, per exhibit

**Placeable — four.**

| exhibit | derived from | inference required |
|---|---|---|
| `EX-014` | `stat`'s own output: `2026-08-10 05:28:01.153543462 +0200` | **none** — already absolute, only rewritten to `T`-separated form |
| `EX-015` | the extraction command's own `--since` / `--until` | offset from its `captured` stamp, 15 min later the same day |
| `EX-010` | the three decoded events, bare local time | offset from its `captured` stamp, 108 s later the same day |
| `EX-018` | the `first HCI timeout` column, `2026-07-25 03:25` → `2026-08-13 05:14` | offset from its `captured` stamp; both ends inside the same CEST period |

**Not placeable — five, each for a different reason.**

| exhibit | why |
|---|---|
| `EX-011` | the output is two counts and neither is a time |
| `EX-012` | addressed by boot **index** (`bt-phase -b -2`), which moves every boot |
| `EX-013` | whole dates, no times — see below |
| `EX-019` | the captured command exited 127; the output is `command not found` |
| `EX-020` | a summary over 22 boots that names none of them |

**`EX-013` is the one I want you to check my reasoning on.** Its table runs
`2026-07-16` to `2026-08-13` in whole dates. Placing it means choosing an instant
inside the first day, and the two obvious choices fail in **opposite**
directions: the start of the day can report retained evidence as gone, and the
end of it can report gone evidence as checkable. Your tool's header names the
first as *"the one answer this tool must never invent"*. Neither is safe, so it
declares that it cannot be placed — which is precisely what the third form is
for. If you would rather have a guess with the direction stated, say so and it is
one line.

## 3. `EX-018` contradicts the plan, deliberately

`docs/investigation-plan.md` says `EX-018` and `EX-020` *"may honestly stay
unjudgeable, since no line in the file can place evidence that is gone"*.

`EX-020` stays. **`EX-018` does not, and I think the plan is wrong about it.**
Its stage-1 table has a `first HCI timeout` column — that *is* a line in the file
that places the evidence — and placing it gives the stronger version of the same
fact:

```
  018-no-natural-stage2-ever-observed    GONE   declared window opens 2026-07-25T03:25:00+02:00
```

**GONE rather than not judgeable.** Same conclusion, derived instead of assumed,
and it is the exhibit this whole tool was written because of. The annotation
states the contradiction at the point of the change rather than leaving you to
find it. Revert it if you disagree; nothing else depends on it.

## 4. The numbers above are the fixture's, and yours will differ

The counts come from `tests/journal/retention`, whose oldest boot begins
2026-08-12 — chosen months ago to mirror the machine. **Your machine's answer is
the one that matters and I cannot get it from here:**

```console
$ tools/bt-retention
```

I expect `5 not judgeable` to hold (it depends only on the files) and the
verifiable/gone split to have moved, since more boots have rotated since the
fixture was written.

## 5. A defect this found in one commit, and it was not in BL-09

`install.sh` has said in prose, beside `journal.sh`, that *"a tool that sources a
file it did not ship fails at run time on the installed machine while passing
every check in the checkout"*. **Nothing enforced it.**

`bt-exhibit` and `bt-retention` are both installed. Both began sourcing
`tools/lib/evidence-window.sh`. Every check in the tree stayed green, and the
next `install.sh --apply` on your machine would have left **two dead tools** —
the exhibit writer and the retention reporter, both failing at startup, on the
machine that is the only place they matter.

Both sides are derived now: the installed tools from `install.sh`'s own
`install_file` lines, the libraries from each tool's own `source` lines. A
hand-written pairing is the thing that failed. Scoped to installed tools on
purpose — `bt-crash` sources `coredump.sh` and is deliberately not installed, so
requiring its library would be requiring the shipping of something nothing ships.

⚠️ **`install.sh` and `uninstall.sh` both changed.** Worth an eye before the next
apply on the machine.

## 6. Two of my own checks could not fail

Recorded because the second is a shape, not a slip.

- **`bt-retention`'s preference branch was held by no fixture.** No committed
  exhibit carried a declared window yet, so deleting the entire `bt_ew_read`
  block left the suite green. Fixed with three fixtures whose declared windows
  *disagree* with what the scan would say, so the two answers are distinguishable
  per exhibit rather than in aggregate.
- **A fixture named `043-declared-below` made its own assertion vacuous.** The
  check was "the report line must not contain `declared`" — and it always did,
  because the exhibit's *name* was in the line being searched. Every fixture
  there is now named for what it tests rather than for the word the tool prints.

And one defect in the field itself, found by writing the annotations: a
`not placeable` reason is prose, and prose may quote a date — three of the nine
do. Without a guard the declaration says "cannot be placed" and the reader places
it anyway, from a stamp inside the explanation of why it cannot. That is the
capture stamp masquerading as the evidence's, one layer up, in the mechanism
built to stop it. `bt_ew_earliest` now refuses a `not placeable` payload before
it looks at any stamp.

## 7. Your six are done

`§3.1` adversarial read · `§3.2` `BL-09` · `§3.3` `bt-crash` · `§3.4` BlueZ health
· `§3.5` the source branch · `§3.6` was the BuildID, which
`comms/2026-08-22T1106Z` §3 reported I cannot reach from this network.

**Open on your side, in the order I would take them:**

1. **`F7`** (`comms/2026-08-22T1217Z`) — both withdrawn figures re-derive from
   `evidence/baseline/baseline.tsv` in one command. It changes what `F6` costs
   and hands you back a denominator. §3 of `comms/2026-08-22T1530Z` depends on it.
2. **`EX-033`'s `evt 5` label** (`comms/2026-08-22T1530Z` §1) — it reads
   *Synchronous Connection Complete*; the line is `btusb_notify`'s and `5` is
   `HCI_NOTIFY_ENABLE_SCO_TRANSP`. The tree currently holds two files that
   disagree, on purpose, until you rule.
3. **`tests/run-tests` on the machine** — turns three declared skips about real
   `coredumpctl` output into real assertions.
4. **The `EX-032 SHAPE` warning** (`comms/2026-08-22T1441Z` §3) — the only line
   in `bt-snapshot` that draws a conclusion. Keep it or cut it deliberately.

Unless you redirect me, I will take the longest-standing item on my own list
next: **`UT-12`**, splitting `tests/run-tests`. It is now 9,753 lines and the
largest file in the repository, and every block I have added this week has made
the next one harder to place.
