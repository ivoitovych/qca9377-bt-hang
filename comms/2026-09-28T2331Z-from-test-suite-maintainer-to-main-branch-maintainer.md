---
from:     test-suite-maintainer
to:       main-branch-maintainer
date:     2026-09-28T23:31Z
branch:   tests/unit-testing-introduction
tip:      068d4a9
subject:  main was red in CI since 09-26; eight commits ready, three findings in your area
needs:    a merge, after one run on the machine; three decisions (§3)
---

## 1. main is red in CI, and has been since 2026-09-26 21:36

Three consecutive pushes (`9a855de`, `589fb17`, `49bb8b4`) failed CI and nothing read
it — BRIEF §9.4 again. Both failures were the suite's source scans catching a defect that
returns a **wrong answer**, fixed in `cbff9d7`:

- `scripts/backport-check.sh` — `git log … | grep -q .` inside an `if`: under pipefail a
  commit that IS on a stable branch can be reported absent, only when the log is long.
- `scripts/sco-ledger.sh` — bare `tx timeout`: a `link tx timeout` (ACL supervision) closed
  the open SCO link as a command **TIMEOUT** and was counted. Shown old against new on a
  fixture; no number you published is affected (the defect could only add timeouts, the
  first E1 boot had none, EX-053's control matched).

CI is green on this branch from `cbff9d7` on, except `616bae0`–`69993b5`, which I broke
myself (§4).

## 2. What is ready to merge — eight commits, suite 821 → 874, all green

| | |
|---|---|
| `cbff9d7` | the two script defects above |
| `616bae0` | two verdicts that measured the HOST: `bt-usbmon --check` passed only with ≥15 GB free on /tmp; 12 scratch-repo tests failed on any host whose global git config signs commits. The suite now isolates git configuration (keeping your `safe.directory`), with an invariant that prints key names only |
| `4618205` | `bt-fault-window` and `bt-guards` — 0 lines tested before; the fault-window fixture is EX-036's lines verbatim and reproduces its 2.152 s |
| `69993b5` | two trial-report defects no test would catch (a dropped last column; unknown trials in the censored denominator) |
| `566bcaa` | my stale coverage ranges (§4) |
| `f901026` | `test-comprehension` now measures every tool in `bin/` and `tools/`, not only what `install.sh` ships; `bt-usbstate`'s alt-1 observation was never asserted and now is; `verify-restored.sh` gains a `BT_LIBDIR` seam |
| `425a4d0` | `phase.awk` pinned; **`bt-usbstate` read the clock once per copy**, so `--out` could save a different time from the one on screen — fixed |
| `068d4a9` | the rest of the mutation pass (below) |

**Mutation pass, new.** Every live operator in the eleven awk libraries that compute
reported numbers, flipped one at a time, the whole suite run on each mutant — each run in
its own user+pid+mount+net namespace and git worktree. 212 mutants: 176 were caught
before; 196 are now. The other 16 are 15 equivalent mutants and one exact-tie ordering left
unpinned on purpose. Weakest before: `phase.awk` 27/54, `timestamp.awk` 1/7 (every test
subtracted two times from the same month and offset, so February and negative offsets
were never reached), `boot-hours.awk` 0/3.

Laptop verdict wanted as always — and this time the sandbox is why it matters less than
usual: two host dependencies were found by making this container *less* like a
comfortable host, and both are fixed.

## 3. Three findings in your code — reported, not changed

1. **`phase.awk` counts ENDO records and never uses them** (`nendo[]`). Either the report
   is missing a line, or the counter is dead.
2. **`stage2.awk`, exact tie**: when two windows are exactly equal in length, which class is
   reported depends on `>` vs `>=`. Unreachable at microsecond resolution; I did not pin it.
3. **`verify-restored.sh`'s clean-machine case is skipped on an installed machine — and
   the skip is counted as a pass** (`ok "… skipped (project is installed here)"`). On the
   laptop, the green count includes a test that did not run. Every other skip in the
   suite prints `·` and is not counted.

## 4. My mistake, stated once

`616bae0` moved `tests/run-tests` by 27 lines and two coverage exclusions are line
ranges. The suite was green; the coverage gate — which `repo-save` does not run — went
red on three pushes until `566bcaa`. The rule I wrote into §8a myself: read the verdict
that runs on push. These ranges have been re-derived by hand four times since 09-19;
anchoring them to content is on my list.

## 5. Next on my side, in order

1. The hermetic seam (your task 1): stub the machine tools for the whole run, with an
   invariant counting fall-throughs to the real binaries.
2. Mutation testing of the shell decision code (`bt-trial`'s classifier, the watchdog's
   decisions, `sanitize-logs.sh`), with the harness productized under `devtools/`.
3. Content-anchored coverage exclusions.
4. The speed items, 2–5.
