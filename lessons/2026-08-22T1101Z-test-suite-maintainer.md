---
from:     test-suite-maintainer
date:     2026-08-22T11:01Z
scope:    the test suite, the devtools, CI — 2026-08-13 to 2026-08-22
subject:  what the instruments taught me, most of it by being wrong
---

Ten days of work on a suite that grew from ~400 invariants to 688. What follows
is not what I built; it is what I did not know on 2026-08-13 and know now. It is
organised by the **shape** of the lesson, because the shapes recurred and the
chronology did not teach anything.

The single most useful sentence in here, if you read no further:

> **A control that holds where it was written and not where it runs is not a
> control.** Four independent instances in ten days, in four different people's
> code, including mine.

---

## 1. The recurring class: a control that holds where it was written

Not a metaphor and not a style preference. Four instances, each found the hard
way, each in code whose author had good reason to believe it worked — because on
their machine it did.

**1.1 The suite required root and never said so.** `tools/bt-mode` refuses to run
unprivileged, correctly: in production it moves files in `/etc` and stops a unit.
Under test every path it touches is a seam pointing into a temp tree, so that
refusal was the only thing between the round trip and a host without root. It ran
as root on the investigation machine and read green everywhere anyone looked. The
CI runner runs the suite as an ordinary user.

*Cost: 27 consecutive red CI runs over 45 hours, and every gate behind the first
one never executed (§3).*

**1.2 `repo-save` could not run on the machine it was written for.** It calls
`repo-validate`, which runs the suite, which refuses while a trial is open — and
`bt-trial-auto` opens a trial on every boot by design. The gate worked exactly as
designed and the workflow failed anyway. The maintainer had fallen back to plain
`git` with a manual scan, so the remote-hash verification step never ran on the
one machine that commits evidence.

**1.3 `repo-scan` asked the machine who the maintainer is.** Its email allowlist
came from `git config user.email`, which describes the *operator*, not the
repository. On a CI runner nobody is configured, so the allowlist was empty and
the gate reported the deliberately-published "Reporter contact" line in the bug
report as a leak. It now falls back to the tip commit's author — a fact about the
repository, which is what the comment beside the derivation had always claimed.

**1.4 The one that was not mine, and is the clearest.** The main branch
maintainer ran a three-rung recovery ladder on the controller and checked bus
presence, driver binding, `hci0` existence, and absence of USB-layer lines. All
four passed. They reported it harmless. Twenty minutes later the controller
failed to enumerate at the next boot and was gone.

> "No USB-layer line followed" is evidence about the moment, not about the device.

**The generalisation I would apply next time:** ask of every check, *what
environment does this assume, and is that assumption written down anywhere the
check can see?* If the answer is "it assumes the machine I am sitting at", the
check is a description of that machine.

---

## 2. The second class: a claim about the code, diverging from the code

Comments do not execute. This is obvious and I still lost days to it, because
the comments in this repository are unusually good — which is precisely what
makes them dangerous. A well-argued paragraph reads as a specification, and
nobody re-checks a specification against its implementation.

- **`bt-retention`'s header** said the provenance capture stamp must not be used
  and the timestamps in the exhibit's own output are used instead. The scan ran
  over the whole file, provenance included. Thirteen of twenty-nine exhibits were
  judged by when someone ran a command. `EX-018` reported *still verifiable* on
  the strength of a capture stamp, while the windows it describes are the ones
  the tool exists because they had already rotated away.
- **`trial-summary.awk`** said censored and unknown rows are "counted, shown, and
  excluded from the denominator". The censored half was true. The unknown half
  incremented a counter that was read nowhere — no loop, no warning, no line of
  output — so a trial whose evidence could not be read simply disappeared and the
  denominator became quietly smaller than the sample.
- **`bt-trace`'s** script default and its systemd unit disagreed (10 vs 15), so
  whoever ran the script by hand measured something the service never did.
- **`bt-trial-audit`** carried a comment saying `-n 1` was passed to a journal
  read. It was not. The read went end-to-end over every retained boot: 7 m 22 s.

**The rule:** a comment that asserts a behaviour is a *test that has not been
written*. Either write it, or write the comment as an intention rather than a
fact. `bt-snapshot` had three call sites spelling one pattern three ways under a
header explaining why the pattern matters; the header was right and two of the
three sites were wrong.

---

## 3. A gate that runs first hides the state of every gate behind it

The most transferable thing I learned, and I have now seen it at three scales.

**At the workflow scale.** `repo-validate` is step 5 of 12 and it had been
failing for 45 hours. Steps 6–12 never ran on any of those 27 runs: the coverage
floor, the awk floor, the comprehensiveness floor, the journal contract, the
system round trip, and `repo-scan --all` — the publish-safety gate that screens a
fork's pull request before anyone reads it. When step 5 finally passed, **two of
the hidden gates turned out to be red on their own**, and the publish gate failed
on its very first execution in the repository's history.

The corollary nobody says out loud: for those 45 hours the project's stated
coverage numbers, comprehensiveness floor and publish scan were **not enforced by
CI at all**. They were enforced only by whoever remembered to run `devtools/check`
locally. The numbers were true; the enforcement was not.

**At the tool scale.** `devtools/test-comprehension` reports the *worst* unit
against the floor. Two units sat at 0%, which masked every gap above zero —
closing them immediately surfaced `bt-archive` at 50% with two undriven entry
points that had been there all along.

**At the exhibit scale.** The same shape appears in the evidence: a first-order
finding that stops anyone looking at the second-order one.

**What I would do differently:** make failing gates *report* rather than
*short-circuit*, wherever the later gates are independent. A workflow that runs
all twelve and fails at the end tells you the state of the system; one that stops
at the first tells you the state of one step.

---

## 4. My own checks kept not being able to fail

This is the lesson I would most want a future me to read, because it happened
**five times in ten days** and I did not see the pattern until the fourth.

The house rule here is that a new check must be *observed to fail* against a
mutation of the thing it guards. I applied it, and it kept catching my checks
rather than the code:

| the check | why it could not fail |
|---|---|
| `[[ $report == *016-gone*GONE* ]]` | a glob spans the whole output; `GONE` appeared on a **later exhibit's line**, so misfiling the named one still passed |
| stray-number check in `bt-snapshot`'s summary | anchored on `^[[:space:]]+`; the stray line has **no** leading whitespace |
| `--summary-only` "takes no new cut" | counted capture directories, but `$STAMP` has second resolution — a re-cut in the same second lands in the **same directory** |
| "files checked ≤ files enumerated" | v1 ran against a tree with no `tests/run-tests`, so the suite step never ran; v2 reused a scratch repo padded with `.log` files, so `checked + 1` still fitted underneath |
| privilege probe | `unshare -r true` succeeding was read as *"this gives me root"*; anything that runs the command without elevating satisfies it |

**Four of the five share one root cause: the check tested something correlated
with the property, not the property.** Directory counts instead of "did it
traverse". Exit status instead of "what uid did it get". A substring anywhere
instead of a verdict on one line.

**The rule I now apply:** write the mutation *first*, or at least name it in the
comment beside the check, and then ask whether the assertion distinguishes the
mutated world from the correct one. If you cannot state what would make it fail,
it does not check anything. Every check I added after realising this carries its
mutation in the comment, and that is why they are worth something.

The corollary: **a green suite is evidence about the suite as much as about the
code.** I now treat "all N invariants hold" as a claim requiring the same
scepticism as any other claim in this project.

---

## 5. Instrumentation: measuring the thing changes what you can measure

Specific and hard-won, mostly about bash coverage. Most of this is not written
down anywhere I could find.

- **bash traces commands, not lines.** Every derived rule below came from running
  the construct under the tool's own `PS4` and reading the trace, after two
  attempts to state the rules by eye were both wrong.
- A multi-line **array literal** or quoted-string assignment is traced at its
  **closing** line; a backslash-continued assignment at its **last**; a
  **pipeline** at its **first**.
- `done < <(cmd)` **is** traced — except as the last statement of an `if`, where
  the process substitution is reported at the **`fi` below it**, which the scanner
  discards as structural. Two whole loops therefore looked uncovered while
  running on every invocation.
- An `exit N` **inside an embedded awk program** is awk leaving, not the tool
  refusing. `devtools/test-comprehension` counts refusals and used the coverage
  exclusion list to filter them — so a program body missing from that file pinned
  a unit at 50% **for a reason no amount of testing could fix**.
- **`sudo` destroys the measurement.** It works: 651 green as an unprivileged
  user with a real passwordless sudoers rule. It also resets the environment, so
  `BASH_ENV` — the entire mechanism by which coverage instruments a child — never
  arrives; and it closes non-standard descriptors, so the fd the trace is written
  to is gone. The suite passes and the traced run records **not one line** of the
  tool. `fakeroot` grants uid 0 through an `LD_PRELOAD` and keeps both.

> **A green suite over a blind instrument is worse than the red it replaces**,
> because the obvious next move is to disbelieve the instrument.

That sentence is the whole of §5.

---

## 6. Zero is the most dangerous number in this project

Two rules, one older and one learned this week.

**ENUMERATED == 0 is a refusal. CHECKED == 0 is a result.** A scan that examined
nothing must not report that nothing is wrong. Applied to derivations, to ad-hoc
queries, to capped scans, and to every new tool since. Three work-lists in the
suite were referenced *before they were defined* — `SHELL_FILES` did not exist at
all — so three checks examined an empty set and ticked.

**New this week: zero from a capped scan is not a result.** `devtools/journal-contract`
capped a scan at 5000 lines hunting a boot separator, on a host whose oldest boot
is 1.5 M kernel lines. It reported the journal contract BROKEN while journald was
behaving perfectly. The cap was a performance decision that silently became an
epistemic one.

**And the positive-control discipline that follows:** before any zero is
believed, prove the scan can see. `bt-trial-audit` runs a positive control before
it reports any count, because the hand audit that prompted it produced two
confident zeros — one from a wrong boot index, one from a journal invocation that
silently returned only the current boot.

---

## 7. Cost models I had wrong

- **Journal cost scales with the span traversed, not the lines returned.**
  `--grep` removes formatting and writing; it never removes traversal. A tool
  that filters inside `journalctl` is cheaper than one that pipes, but neither is
  cheaper than not reading the span.
- **`| tail -1` on a boot-range loop reads every boot end to end.** That is how a
  4-second audit became 7 m 22 s.
- **Process forks dominate at scale.** One symlink farm was ~1100 forks; a single
  `ln -s -t` made it one, and removed 19% of total suite runtime.
- **Waiting for a clock is both slow and a weaker assertion.** Every slow test in
  this suite was slow because it waited for time instead of a condition, and each
  was a weaker check for the same reason. 52 s → 28 s came almost entirely from
  replacing sleeps with conditions.

---

## 8. Things I asserted and had to withdraw

Included because a lessons document that lists only other people's errors is not
worth keeping.

- **I said 77 leaking `mktemp` sites had caused disk pressure on the
  investigation machine.** They had not. The maintainer checked and found zero
  accumulation. The leak was real; the consequence I attached to it was invented,
  and I stated it as observed.
- **I took full blame for a write-through hazard** that `git log -S` then showed
  was a composition of two individually safe things, one of which existed only in
  another working tree. Then the maintainer over-attributed it to themselves and I
  had to correct that too. **Attribution is a factual question**; wanting to own a
  mistake is not a reason to get it wrong.
- **I described a change as "a one-line addition"** that in fact needed a new
  environment seam and a scratch-repo fixture. The reviewer pushed back and was
  right. Estimating from the diff I imagined rather than the one that would exist.
- **I merged from a stale checkout** and silently dropped a commit that had been
  pushed minutes earlier — twelve merge-drift guards that never reached main.
  *Fetch immediately before merging, and verify containment after pushing, not
  before.* This is now the only git discipline I would call non-negotiable.

---

## 9. Process, and the two things that changed how this project runs

**Every number ships with the command that produced it.** Not a style rule — this
project has twice published a figure nobody could re-derive and had to withdraw
it publicly. The convention exists so a reader can disagree with the *reading*
while accepting the *data*. It has since caught: a withdrawn "287 timeouts across
34 boots" repeated three times in an unmerged branch, and a `+86.9 s` agreement
between two exhibits that is really usbcore's fixed retry schedule and carries no
information about the device at all.

**A message is not a merge.** `comms/` was created because three sessions were
relaying findings through a human who retyped them. Figures got rounded, caveats
got dropped, and nobody could go back and check what was said. Writing it down in
the repository fixed that — and the discipline that makes it work is that saying
"this is ready" in a message does not put it on `main`. Somebody still fetches,
runs the gates on the merge, and pushes.

The unexpected part: **the channel changed the content, not just the transport.**
Written to a named recipient who will check it, a claim gets its command attached
without anyone insisting.

---

## 10. What I would tell someone starting on this suite tomorrow

1. Run the gates as an **unprivileged user in a fresh copy of the tree** before
   believing any of them. Four of the seven had never executed in CI.
2. When you add a check, **write down the mutation that would make it fail**, in
   the comment, beside it. If you cannot, you have not added a check.
3. **Ask what environment each assertion assumes.** Root, an installed tool, a
   configured git identity, a clock with sub-second resolution, a network.
4. **A zero is a claim.** Prove the scan can see before you report one.
5. When a tool and its comment disagree, **the comment is the bug report** — and
   somebody already wrote it for you.
6. The deferred-damage question is worth asking of anything: *could the subject of
   this check be damaged in a way that only shows up at the next run?* For this
   suite the answer was yes and it was the fixtures — a test that writes into a
   fixture passes its own run, because it reads back exactly what it wrote, and
   every run afterwards measures corruption honestly and means nothing.
