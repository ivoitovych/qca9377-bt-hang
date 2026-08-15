# Comprehensiveness, not coverage — every unit, every mode

**Written** 2026-08-15T01:42Z · **Covers** the tree at `eaa9a14` · **Instrument**
[`devtools/test-comprehension`](../devtools/test-comprehension)
· **Opened by** the question "is every unit exercised in all its modes?"

**Verdict.** The premise is right and the gap is larger than the coverage number
suggests. At **90.1% line coverage**, the mean weakest-dimension score across 34
measurable units is **76%**, and four units are below 35%. One shipped tool has never
been executed at all. One is written in a language no instrument here measures. The
worst case is the clearest: `tools/bt-capdiff` is at **93% of its lines and 1 of its 5
modes**.

---

## 1. Why this is a different question

Line coverage answers *did this line run*. It cannot answer *was this unit exercised in
every mode it has*, and the two come apart badly — because most of a tool is the setup
above its dispatch, and running that once credits the file whatever verb followed.

Every defect this effort found in the last week was an **unexercised mode**, not an
unexecuted line:

| defect | line coverage at the time | what was actually missing |
|---|---|---|
| five `repo-validate` validators never ran | 48% | no scratch repo held a `.json`, `.py`, `.awk`, unit or rule |
| `bt-usbmon` dropped its gap record | 93% | no test used a fractional check interval |
| `bt-usbmon` deferred SIGTERM through its backoff | 93% | nothing signalled it *during* a restart |
| `bt-trace` idled an hour past `systemctl stop` | 100% | nothing signalled it in the floor-stopped state |
| `install.sh` wrote a udev rule into a missing directory | 94% | no install ran anywhere without `/etc` |

None is visible in a percentage. Each is visible as a mode, a boundary, or a stimulus
that nothing drove.

---

## 2. What is measured

Four dimensions per unit, derived from the unit's own source and from the trace of a real
suite run — never from a hand-written list, which is the failure this repository has hit
six times.

| | |
|---|---|
| **MODES** | top-level dispatch labels: verbs and flags. Exercised when ≥1 line of the branch was traced |
| **REFUSALS** | every `exit <non-zero>` that is real shell, not an `exit` inside an embedded awk program |
| **SEAMS** | every `BT_*` override the unit reads. Exercised when the suite sets it |
| **BRANCHES** | ordinary line coverage, carried over so one table holds both axes |

**The score is the WEAKEST dimension, not the average.** A unit whose every line ran but
whose refusals were never driven is not 75% verified; it is a unit with untested
refusals, and averaging is precisely what hides that.

### What it cannot see, stated before the numbers

**It cannot tell whether an assertion is any good.** A mode that ran under a test
asserting nothing scores identically to one checked to the letter. Only mutation shows
the difference, and `devtools/assert-test-catches` is the tool for that — spot-applied
here, not systematic.

**It cannot see combinations.** Ten verbs and four flags is forty interactions; this
counts fourteen things. Where modes interact — `install.sh --apply --no-metrics`,
`bt-dyndbg on --packets` — **the score is an upper bound**, not a measurement.

So the honest reading of any figure below is *"at most this well exercised"*.

---

## 3. The measurement

34 measurable units. Mean weakest-dimension score **76%**. Worst **0%**.

### Below 70% — the actionable set

| unit | modes | refusals | seams | branches | score |
|---|---|---|---|---|---|
| `tools/bt-window` | 0/0 | 0/1 | 3/3 | **0/45** | **0%** |
| `tools/bt-logvolume` | **1/6** | 2/3 | 1/1 | 38/53 | **16%** |
| `tools/bt-capdiff` | **1/5** | 3/3 | 3/4 | 96/103 | **20%** |
| `tools/bt-incident` | **1/3** | **1/3** | 1/1 | 59/70 | **33%** |
| `bin/bt-hang-watchdog` | — | 1/2 | **10/13** | 168/195 | 50% |
| `tools/bt-phase` | 4/4 | 2/2 | **2/4** | 36/36 | 50% |
| `tools/bt-stage2` | **2/4** | **5/8** | 3/3 | 23/35 | 50% |
| `tools/bt-env-history` | — | 1/1 | 2/2 | 21/32 | 65% |
| `bin/bt-evidence` | **4/6** | 2/3 | 7/7 | 112/124 | 66% |
| `tools/bt-boot-list` | 4/4 | **2/3** | 1/1 | 33/34 | 66% |
| `tools/bt-diagnose` | — | **2/3** | 2/2 | 99/109 | 66% |
| `tools/bt-timeline.sh` | — | 1/1 | 1/1 | 33/48 | 68% |

At the other end, eight units are at 95% or better on every dimension: `bt-mode`,
`bt-trace`, `bt-sco`, `bt-state`, `bt-status`, `bt-health-report.sh`, `bt-mark`,
`bt-health-snapshot`.

---

## 4. The four findings that matter

### 4.1 `tools/bt-window` has never been executed — 0 of 45 lines

It arrived on `main` in `be082d1` alongside EX-021, is installed to `/usr/local/bin` by
`install.sh`, and no test invokes it. This is the one result that needs no interpretation.

It also shows the two instruments answering different questions correctly: the suite is
green, coverage moved by a fraction of a point, and a whole shipped tool is unverified.
The **installer** round trip already knows about it — it is one of the 61 files staged and
one of the 63 `uninstall.sh` removes — so the *packaging* is tested and the *behaviour*
is not.

### 4.2 `bt-capdiff`: 93% of lines, 1 of 5 modes

The single best illustration of why the question was worth asking. `--since`, `--until`,
`-n` and `--help` have never been passed. The line coverage is high because the default
path is long and the flags only steer it.

`bt-capdiff` decides **whether either capture path lost traffic** — it is the tool that
says whether the evidence is complete. Its windowing flags are how anyone would narrow a
comparison to an incident, and they are untested.

### 4.3 `bin/bt-capture` is Python, and nothing measures it

207 lines, a capture daemon, and **neither instrument sees it**: `devtools/coverage`
traces bash, `devtools/awk-coverage` profiles awk. This repository is written in three
languages and instruments two.

It is worth stating plainly that the earlier report's line — *"two coverage tools now
measure this repository"* — was true and incomplete. The third language was not
overlooked in the analysis; it was invisible to it, which is the same thing.

**My own instrument made the matching mistake on its first run**, scoring `bt-capture`
100% with 0/0 in every column. Nothing was measured, so nothing could be wrong. That is
the empty-input failure again — the sixth instance — produced by the tool written to
detect unexercised code. It now refuses to score a unit it could not measure and lists it
separately.

### 4.4 Refusals are the weakest dimension overall

Across the tree, 14 refusal paths have never been driven. A refusal is where a tool
declines to answer — the most consequential branch in a project whose whole discipline is
*not producing an answer it cannot support*. `bt-stage2` alone has three untested
refusals out of eight.

Untested seams are the same shape one level down: `BT_WINDOW`, `BT_EARLY_WINDOW` and
`BT_EARLY_THRESHOLD` on the watchdog are the parameters that decide *when it intervenes*,
and no test has ever set them to anything but their defaults.

---

## 5. What to do, in order

1. **Test `bt-window`.** A shipped tool at 0% is not a coverage question.
2. **Drive every mode of the four units below 35%** — `bt-logvolume`, `bt-capdiff`,
   `bt-incident`, `bt-stage2`. Sixteen unexercised verbs and flags between them, all
   cheap: they are argument paths over fixtures that already exist.
3. **Drive the 14 untested refusals.** Each is one negative stimulus.
4. **Decide about Python.** Either instrument `bin/bt-capture` (`coverage.py` is the
   obvious answer and it is a CI step, not a rewrite) or state in the register that one
   daemon is unmeasured and why. The current situation — unmeasured and unstated — is the
   only unacceptable one.
5. **Set a floor.** `devtools/test-comprehension --min N` fails when any unit's weakest
   dimension is below N. A floor at 70 is met by everything except the six above; a floor
   at 50 is met today except for four units and would still have caught `bt-window`.

**What NOT to do:** raise the score by counting modes that were merely reached. The
dimension worth having is the one this tool cannot measure — whether the assertion behind
each exercised mode would fail if the code were wrong. That is mutation testing, and the
right next instrument after this one.

---

## 6. Does the approach make sense here

Yes, and the evidence is in the table rather than in the argument. The HDL practice —
exhaustively exercise every unit in every mode, so that what survives integration is an
integration defect and not a unit defect — maps onto this repository directly, with one
translation.

In HDL the modes are enumerable from the interface. Here they are enumerable from the
argument dispatch, the refusal paths, and the seams, which is why this analysis could be
**derived** rather than estimated — and why it found a tool nobody had run.

The difference from line coverage is not academic. **90.1% coverage and 76% mean
comprehensiveness describe the same suite**, and only the second one puts `bt-window` at
zero, `bt-capdiff` at one mode in five, and a Python daemon outside every instrument.
