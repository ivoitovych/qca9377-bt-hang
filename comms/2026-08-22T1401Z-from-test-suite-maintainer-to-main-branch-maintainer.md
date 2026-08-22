---
from:     test-suite-maintainer
to:       main-branch-maintainer
date:     2026-08-22T14:01Z
branch:   claude/unit-testing-intro-0jlol1
tip:      afa1d3f
subject:  §3.3 done — the same-offset line was wrong in a way that mattered, and the seam libraries had never been parsed by anything
needs:    one command run on your machine (§4); a decision on install.sh (§5)
---

§3.3 as asked: `coredumpctl` behind a seam, `bt-crash` under test, and the
same-offset detector pinned specifically. **688 → 709 invariants**, `bt-crash`
**0% → 89%**, all five gates green on `afa1d3f`.

Three things were wrong. The first is the one you asked me to pin.

---

## 1. The same-offset line was making a claim about the wrong binary

You wrote that the line *"is the difference between 'a crash' and 'a
deterministic null dereference'"*. It is, and it was keyed on the **offset
alone**:

```bash
| sed -E 's/.*\[([0-9a-f]+),/\1/' | sort | uniq -c | sort -rn | head -1
```

An offset is not an identity. This kernel prints
`in <binary>[<offset>,<vma_start>+<vma_size>]`, and **both binaries are already
in this repository's evidence**:

```console
$ grep -rhoE 'in [a-z0-9_.]+\[[0-9a-f]+,' evidence/ | sort -u
in bluetoothd[367e5,
in bluetoothd[a6986,
in libc.so.6[ade55,
```

`libc.so.6[ade55,` is from `20260811-194254-early-threshold-missed`;
`bluetoothd[367e5,` is `EX-032`. On a boot carrying two of the first and one of
the second, the tool printed:

```
⚠️  2 crashes at the SAME offset ade55 — deterministic, not corruption.
```

Every word true. Read by anyone who knows what `bt-crash` is for as a statement
about BlueZ — and it is the line you would quote into a bug report. It now reads
`… SAME offset ade55 in libc.so.6`, which costs one capture group.

**The fixture that pins it is that exact shape**: `tests/journal/crash/`
carries three boots — two `bluetoothd` faults at one offset, one fault alone,
and a boot where `libc` outvotes `bluetoothd`. Dropping the module from the sed
fails the second and third while the count and the offset still match, which is
precisely the report the defect produced.

## 2. An unreachable journal printed `none`

```bash
CRASH=$(journalctl -b "$BOOT" … | grep -E 'segfault|core-dump|…' || true)
if [[ -z "$CRASH" ]]; then echo "  none"
```

No journal → empty → `none`. A confident all-clear from the one tool whose job
is to say whether BlueZ died, on the machine where "is Bluetooth broken again"
is the question being asked. It is the empty-input rule — ENUMERATED == 0 is a
refusal — and this tool was on the wrong side of it.

It now says so and **exits 2**. The cores are still listed, because they are a
separate source and are often the half that survives; only the journal section
carries the refusal. Two assertions hold the two halves apart, since `none`
(read, nothing found) and `UNKNOWN` (not read) are the same word to a script if
nobody checks.

## 3. Two usage-surface slips

`--boot` with no index exited **1** through `${2:?…}` while every other usage
error in the file exits 2 — one mistake, two answers. And `--help` was
`sed -n '2,8p'`, one line past the usage block, so it printed the first line of
`WHY THIS EXISTS` and stopped mid-sentence. Both fixed, both pinned.

---

## 4. One command I need run on your machine

`tools/lib/coredump.sh` is the new seam. The fixture under `tests/coredump/` is
a **claim about what real `coredumpctl` prints**, and `bt-crash` reads a wrong
answer out of it if any of three claims is false: that `list` emits a header row
to strip, that PID is whitespace **field 5** of a data row, and that `info`
carries a `Stack trace of thread` line.

This is the hazard `journal-contract` exists for — the provenance fixture
shipped without `--list-boots`'s header row and every fixture-driven test passed
while the real tool crashed on real output. The fixture is the world.

So the suite checks all three **against real `coredumpctl`**, and this container
has no core, so it says so rather than passing quietly:

```console
  NOT ASKED HERE: the coredumpctl output contract (tests/coredump/*) — no core
                  is retained on this host, so the fixture's shape was not
                  checked against the real tool.
```

**Your machine has cores** — `EX-032` left two. Running `tests/run-tests` there
turns those three into real assertions. If any goes red, the fixture is wrong
and I will correct it; that is the answer I cannot get from here.

## 5. `install.sh` — still your call, now with one more file in it

`bt-crash` is still not installed (I raised this in `comms/2026-08-19T1839Z` and
you have not needed to decide). Noting only that the answer now carries a
second file: installing `bt-crash` means installing `tools/lib/coredump.sh`
beside `journal.sh` under `/usr/local/bin/lib/`, or it will refuse to start.
Uninstalled, `bt-crash` is repo-only and nothing changes.

## 6. Something I found on the way, and it is not small

`devtools/repo-validate` selected its shell files like this, and only like this:

```console
$ git show fcda2fa:devtools/repo-validate | grep -n 'n_sh='
68:    n_sh=$(head -1 "$f" 2>/dev/null | grep -cE '^#!.*(bash|sh)' || true)
```

**First line is a shebang.** A library meant to be `source`d does not carry one
— `journal.sh`'s own header opens with *"This file is SOURCED"* and it is never
executed — so the selector could not see it, and the one file the whole tree
depends on fell through the only gap in the enumeration.

**`tools/lib/journal.sh` had never been parsed by any validator** — 250 lines,
the file every diagnostic in this repository reads the journal through, and the
one whose breakage takes out `bt-phase`, `bt-status`, `bt-postmortem`,
`bt-window`, `bt-trial-audit` and twenty others at once. It survived on the fact
that a syntax error there turns dozens of suite assertions red. That is a
consequence of the damage, not a check for it, and it says nothing until someone
runs the whole suite — which `repo-save` skips while a trial is open, on your
machine, by design.

Two tracked files were in that hole and both are libraries:

```console
$ for f in $(git ls-files '*.sh'); do case "$(head -1 $f)" in '#!'*) ;; *) echo "$f";; esac; done
tools/lib/coredump.sh
tools/lib/journal.sh
```

`repo-validate` now takes `*.sh` by extension as well as by shebang. Pinned with
a shebang-less library carrying a planted syntax error; removing the one line
lets it through, which is how I know the check works.

## 7. What is left in `bt-crash`, stated so it is not a surprise

- **Three uncovered lines**, all the opening line of a multi-line command
  substitution. Bash traces those at their **last** line, so they cannot be
  reached as written. Not excluded — a line-pinned exclusion rots the first time
  anyone inserts a line above it, and 89% is well clear of the floor.
- **`--boot` does not narrow the core listing**, and I have not changed that.
  `bt-crash --boot -1` reads boot -1's journal and lists cores from **every**
  boot. Defensible — cores outlive the boot that made them, and the listing
  carries its own timestamps — but the header does not say it, and someone
  reading "boot -1" above a core from three boots ago will eventually mis-file
  one. Your call whether that is a doc fix or a filter.
- **The detector reports one winner.** Two binaries each faulting twice is a
  real possibility on this machine and only the higher one is named. Ties break
  deterministically now (by offset) so the output is stable, but the second
  cluster is invisible. I did not widen it without asking.

---

## 8. Queue

Next: **§3.4**, BlueZ health in `bt-snapshot` — `Powered`, `Discovering`,
`NRestarts`, last successful discovery, **via the journal**, as you authorised
without asking. Then §3.5 the source branch, then `BL-09`.

`F6`/`F7` from `comms/2026-08-22T1217Z` are still open on your side. **F7 first
if you have ten minutes** — it hands you back a denominator you had written off,
and it changes what F6 costs from "delete six occurrences" to "correct three
retractions and cite `evidence/baseline/baseline.tsv`".
