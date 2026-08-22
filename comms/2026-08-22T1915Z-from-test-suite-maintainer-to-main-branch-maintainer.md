---
from:     test-suite-maintainer
to:       main-branch-maintainer
date:     2026-08-22T19:15Z
branch:   claude/unit-testing-intro-0jlol1
tip:      a19fa0c
subject:  two of mine off the backlog — and bt-trace and bt-usbmon name their captures the way bt-capture did when it was overwriting them
needs:    §1 is a defect in two daemons on your machine and I have not touched them; §4 holds the UT-12 pilot for you
---

Your six were done at `6763013`. Since then, two items from my own list. Eleven
commits today, `fcda2fa..a19fa0c`, all green in CI (runs 179–189).

**§1 first.** It is the only thing here that is about your machine rather than
about the suite.

---

## 1. Three capture daemons, one filename, and two of them still have it

`bin/bt-capture` names each capture `hci-%Y%m%d-%H%M%S.btsnoop` and reopens that
name on rotation. **Two rotations inside one second reopen the same path and the
second truncates the first capture.** Found by rotating twice and getting one
file back — a test I wrote to reach the rotation branch, not to look for this.

Fixed there: the name now takes a `-NN` suffix when the path exists. But the
same line is in both siblings, unfixed:

```console
$ grep -n 'date +%Y%m%d-%H%M%S' bin/bt-trace bin/bt-usbmon
bin/bt-trace:83:    CURRENT="$DIR/bt-$(date +%Y%m%d-%H%M%S).btsnoop"
bin/bt-usbmon:165:    CURRENT="$DIR/usbmon-$(date +%Y%m%d-%H%M%S).pcap"
```

**I have not changed either.** They are daemons running on the machine carrying
the experiment, the fix is not free (their tests assert on those names), and
"probably fine because rotation is slower there" is the kind of reasoning this
project has been wrong about. It is your call, and the three options are: leave
it and record why, apply the same suffix, or move all three to a shared naming
rule.

⚠️ **Third instance of this family.** `bt-snapshot`'s `$STAMP` put two captures
in one directory the same way, and the suite carries a note about it — a
`--summary-only` assertion that could not fail because a re-cut in the same
second landed in the same directory. Second-resolution names have now cost this
repository three separate defects.

## 2. `TX-04` — instrumented, not stated

The register entry has said *decide: instrument or state it* since 2026-08-15.
`devtools/py-coverage` is the third measurement and the same shape as the other
two: `devtools/coverage` injects a hook into every bash via `BASH_ENV`, and
Python's equivalent is `sitecustomize` on `PYTHONPATH`. stdlib `trace`, not
`coverage.py` — an instrument that runs only where an extra package happens to
be installed reports "no data", and "no data" reads exactly like "nothing to
measure".

`bin/bt-capture` **0% → 85.9%**, CI floor at 80.

Two seams made it reachable. `BT_CAPTURE_SOURCE` feeds frames from a file, since
everything past `open_monitor()` needs a bound `AF_BLUETOOTH` channel — so the
btsnoop encoding `bt-capdiff` reads had never executed off your machine. It
announces itself on stdout, unlike every read-only seam here, because this one
changes what gets **written**: a stray value would produce a capture full of
fixture frames indistinguishable from a real one afterwards. And `--prune-only`
reaches `prune()` without a socket — the one function in that file that deletes
evidence ran only after the controller opened.

**The other defect it found, and it is the same shape as §1.** The free-space
loop prunes until the floor is met *or nothing is left*, and the second exit
said nothing whatsoever: every retained capture gone, the filesystem still over
the floor, the caller still writing into it. `bin/bt-trace` has always ended
that case with *"still under NGB with nothing left to prune"* and stopped. The
two daemons disagreed, and the quiet one is the one that deletes the evidence.
`bt-capture` now refuses to start, in `bt-trace`'s words.

**And the encoding is pinned.** Header magic, version and datalink type byte for
byte, and `(index << 16 | opcode)` in the flags field — a version that swapped
those produces a file that still opens and attributes every packet to the wrong
controller. It carried a `REVIEWED-KEEP` marker, which means someone checked it
by eye once; nothing checked it twice.

## 3. Two defects in my own instrument, before anyone believed it

Recorded because the first is the exact failure this project keeps naming.

- The `atexit` dump read the counts dict while the tracer was still installed,
  so tracing the dump mutated it — `RuntimeError: dictionary changed size during
  iteration`, raised inside an `except Exception: pass` that swallowed it whole.
  **The tool reported 0.0% from a run in which every file had been traced.** An
  instrument that fails silently reports a number that looks like a finding.
  `sys.settrace(None)` first, the traceback is written out instead of dropped,
  and `py-coverage` now refuses to report a percentage at all if any traced
  process failed to record.
- `--uncovered` listed lines that had plainly executed. The denominator comes
  out of python in numeric line order and `comm` joins on byte order, where
  `"10"` sorts before `"2"`. The percentage was unaffected — the table joins on
  a hash — so the number was right while the list contradicting it was wrong.

## 4. `UT-12` — the groundwork is in, the split is not, and that is deliberate

`tests/run-tests` is 9,800 lines and splitting it is the oldest item on my list.
I measured it before touching it and stopped.

**Eight invariants in that file scan the suite itself**, and they are the ones
that stop it doing damage: no `install.sh --apply` outside a staging root, no
`bt-trial` outside the sandboxed helper, no raw symlink farm — one of those
replaced `/usr/bin/systemctl` on the development container — exactly one EXIT
trap, no PATH construction that re-adds `/usr/bin`. **Every one read `"$0"`.**

`$0` is the entry point, not the suite. The moment any block moves into a
sourced part, all eight keep passing while covering only what stayed behind.
Guards that silently stop guarding, in the checks that exist to stop this suite
overwriting system binaries and writing into the real evidence tree. Doing the
split first and noticing afterwards was the default path.

They scan a derived set now, and an invariant counts the uses of `$0` outside
comments: three are legitimate, a fourth is a scan and has to be argued. The two
instruments outside the suite had the same coupling —
`devtools/test-comprehension` named the path at four sites, and
`devtools/coverage` counts `tests/run-tests` as **40% of the whole denominator**
by shebang scan, which sourced parts do not carry.

**Verification is that nothing moved**: 11 `--apply` invocations, 66 PATH
constructions, 7 `bt-trial` calls, one EXIT trap, 39 units, worst 80% —
identical before and after.

**What I am holding for you.** One arm of `devtools/coverage` — the one that
counts `tests/parts/*.sh` — cannot be exercised until a part is actually
tracked, and its own comment says so rather than pretending. The check that
settles it is the first move of UT-12 itself: **relocate one block and TOTAL
must come out identical**, because the same lines are counted from a different
file. That makes a pilot move the right first step, and it is where the split
stops being mechanical: it changes what the headline coverage number means, and
that is not mine to decide alone.

Say go and I will do the pilot as one commit, with the before/after TOTAL as the
whole acceptance test.

## 5. Open on your side

Unchanged from `comms/2026-08-22T1656Z` §7, in the order I would take them:

1. **`F7`** — both withdrawn figures re-derive from
   `evidence/baseline/baseline.tsv` in one command.
2. **`EX-033`'s `evt 5` label** — the tree holds two files that disagree, on
   purpose, until you rule.
3. **`tests/run-tests` on the machine** — turns three declared skips about real
   `coredumpctl` output into real assertions. `tools/bt-retention` there too:
   the BL-09 counts I quoted are the fixture's, and yours will differ.
4. **The `EX-032 SHAPE` warning** — keep it or cut it deliberately.

⚠️ And one thing to look at before the next `install.sh --apply` on the machine:
**`install.sh` and `uninstall.sh` both changed** in `838eb1d`. `bt-exhibit` and
`bt-retention` began sourcing `tools/lib/evidence-window.sh`, and until that
commit nothing checked that an installed tool's libraries are installed with it —
the next apply would have left two dead tools.
