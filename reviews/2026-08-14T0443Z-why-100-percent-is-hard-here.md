# Why 100% coverage is hard in this project, and what a hard cut would take

**Written** 2026-08-14T04:43Z · **Covers** the tree at `331e7a2` · **Opened by** the
question "in other projects I reached 100% easily; why is this one hard?"

**Verdict.** The premise is right and the diagnosis is not what it looks like. Three
different things were being added together under one percentage, and only one of them is
a testing problem. Separating them moved the measured figure from 71.0% to 84.0% without
writing a single test, and made a real 100% target arguable for the first time.

---

## 1. The short answer

In a project where 100% comes easily, three conditions usually hold:

| | typical project | this project |
|---|---|---|
| Unit of measurement | the language's own statements, via an instrumented runtime | **bash commands, via `xtrace`** |
| Unit of code | functions returning values | **programs with side effects on a live machine** |
| Languages measured | one | **two — and only one was being counted** |

None of those held here, and each contributed a different kind of impossibility.

---

## 2. What was actually in the 1648 uncovered lines

Measured, not estimated, at the point the question was asked:

| Category | Lines | Is 100% reachable? |
|---|---|---|
| Bodies of embedded awk/sed programs | 302 | **Not by this instrument.** bash traces *commands*; a 180-line awk program is one command |
| Files that RUN the suite (`coverage`, `check`, `assert-test-catches`, `verify.sh`, …) | ~310 | **No.** Measuring them needs a second harness measuring the first |
| The suite's own `bad "…"` failure branches | 72 | **Only by failing the suite** |
| `install.sh` / `uninstall.sh` `--apply` | 206 | Only via the CI-gated system round trip |
| Capture daemons' foreground loops | 102 | Needs a run-one-iteration seam |
| **Ordinary tool branches** | **~550** | **Yes — and this was the only real gap** |

So roughly a third of what the number was calling "untested" was **unmeasurable by
construction**, and the tool had no way to say so. A percentage cannot distinguish
"nobody tested this" from "this instrument cannot see this", and those two demand
completely different responses.

---

## 3. The four things that were missing

### 3.1 A list of the uncovered lines

`devtools/coverage` printed a ranking of files. It never printed **which lines**.

That is the single biggest reason this felt hard. Every mature coverage tool prints the
missing lines; a ranking is the more comfortable output and the less useful one, because
a ranking improves when you test whatever is cheapest, and a line list does not. Three
sessions of this effort ran by *guessing* which tool was untested and reading it.

`--uncovered` now prints them, generated from the same two tables the ratio is computed
from so the detail cannot contradict the summary. Its first use on `bt-status` named 20
lines — four verdict branches, one hardcoded path, one message. **None of it was hard. It
was invisible.**

### 3.2 Coverage of the second language

Half this project's logic is awk, and awk is where it computes its **answers**: interval
arithmetic, timeout clustering, per-boot counts, the trial summary, the capture
comparison. `devtools/coverage` could only ever report how many times a library was
*loaded*.

`gawk --profile` writes the program back out with an execution count against every
statement it ran and nothing against the rest. `devtools/awk-coverage` puts an `awk` shim
on `PATH`, runs the suite through it, and reads 884 profiles back: **1534 statements, 105
distinct programs.**

The first thing it said was the finding of this whole session. `tools/bt-actions`'
classifier was at 39%, and the branches that had never executed were:

```
"USB descriptor read FAILED — device not answering USB core"
"USB device NOT ACCEPTING ADDRESS"
"xHCI setup device command TIMEOUT"
the AVDTP Abort/Start timeouts, the HFP and A2DP connect refusals
```

That is **stage 2** — the controller leaving the USB bus, the part of the bug the kernel
log barely records and the part the report turns on. The rules existed; nothing had ever
run them. **A pattern that does not match is not a wrong answer, it is silence**: the
reconstructed timeline would simply not have contained the most important event in the
capture, and nothing would have looked wrong. That is precisely the "flaw in the result"
this work exists to prevent, and no amount of shell coverage would ever have found it.

The classifier is now at 172/172 against a fixture carrying one line per rule.

### 3.3 A denominator containing only reachable lines

Three constructs were being counted that bash can never report:

- **standalone `case` labels** — the pattern is not a command; only the body is traced;
- **bodies of multi-line embedded programs** — one command, one trace line;
- lines of multi-line constructs generally.

Which line of a multi-line construct *is* traced turned out to be construct-dependent —
a pipeline reports where it starts, a command substitution and a bare simple command
report where they close. Two attempts to state that rule in advance were both wrong.

### 3.4 A mechanism that makes a hard cut mean something

A floor of 65% says "some of this is untested and we have agreed not to say which". A
floor of 100% against an explicit list says "every line is either executed or listed with
a reason a reviewer can reject". `devtools/coverage-exclude` is that list. Three entry
forms — whole file, line range, and `path:/regex/` matching by line *shape* — and **every
entry carries a reason; an entry without one aborts the run.**

**The guard that makes it safe to grant a floor to:** an excluded line that the suite
*actually executed* aborts the run. That line left the denominator while staying in the
numerator, which flatters the total in the one direction nobody checks.

It earned itself immediately, rejecting **six** of my own entries as I wrote them — a
whole-file entry for `tests/run-tests` that would have removed 1200 executed lines, and
five ranges that got the traced-line convention backwards. The file now says so rather
than claiming a rule: *the useful property is not that the derivation was right, it is
that a wrong range cannot survive one run.*

---

## 4. Where it stands

| | at the question | now |
|---|---|---|
| Shell coverage | 71.0% of 5217 | **84.0%** of 4520 |
| awk statement coverage | *not measured* | **88.2%** (1353/1534) |
| Invariants | 334 | **370** |
| Files at 0 uncovered lines | — | `bt-status`, `bt-postmortem`, and the `bt-actions` classifier |
| CI floors | 65% shell | **80% shell + 85% awk** |

The denominator shrank by 697 lines and every one of them is named in a reviewed file
with a reason.

---

## 5. What a real 100% would take, honestly

Of the 897 lines still uncovered:

| Block | Lines | What it needs |
|---|---|---|
| `install.sh` / `uninstall.sh` `--apply` | 206 | A `DESTDIR`-style seam, or teaching `devtools/coverage` to include the gated round trip when `BT_SYSTEM_TEST=1`. **The second is better** — the code IS covered, by a test CI runs; the measurement simply excludes it |
| `tests/run-tests` non-`bad` lines | 120 | Sections skipped behind capability guards (mawk, absent tools). Reachable, individually |
| `tools/bt-trial` | 117 | The trial lifecycle; needs the evidence sandbox extended to the full state machine |
| `bin/bt-trace` / `bin/bt-usbmon` | 102 | A run-one-iteration seam for the capture loops. `--check` reached the setup and retention; the supervision loop needs its own |
| `bin/bt-hang-watchdog` | 38 | Escalation paths beyond the two scenarios driven |
| `devtools/repo-validate` | 48 | Per-validator failure cases, against scratch repos |
| Long tail across ~25 tools | ~266 | Ordinary branches. Cheap now that `--uncovered` names them |

**My recommendation, in order:**

1. **Fold the gated round trip into the measurement** rather than seaming `install.sh`.
   206 lines is the largest single block and the code is already tested; changing the most
   safety-critical script in the repository to raise a number is the wrong trade.
2. **Work the long tail with `--uncovered`.** ~266 lines across 25 tools, now that the
   list exists. This is where "no flaw in the result" actually lives — they are verdict
   and refusal branches.
3. **Extract the remaining inline awk to `tools/lib/*.awk`**, as was already done for
   `phase.awk`. That converts exclusion ranges into library files with fixture cases and
   real statement coverage, and shrinks the exclusion list rather than growing it.
4. **Then, and only then, raise the floors to 100%** with whatever remains enumerated.

**One caution.** A 100% floor creates pressure to widen the exclusion list, and the
self-check cannot stop that — it only stops the list from hiding *executed* code. Nothing
mechanical can stop someone excusing code that ought to be tested, which is why every
entry has to argue and why the exclusion count is printed next to every total. The list
staying short is a review responsibility, not a tooling one.

---

## 6. The thing worth remembering

Two coverage tools now measure this repository, and they disagreed about the most
important file in it. `devtools/coverage` said `tools/bt-actions` was the worst-covered
file in the tree at 16.4%. It was 85% covered. `devtools/awk-coverage` said the classifier
inside it was at 39%, and the missing branches were the ones that recognise the controller
leaving the USB bus.

**One number was wrong and comfortable; the other was right and alarming.** The project
had been reading the comfortable one for three sessions — not because anyone was careless,
but because a single percentage over a codebase written in two languages cannot be
anything else.
