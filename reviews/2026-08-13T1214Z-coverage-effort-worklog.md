# Test-coverage effort — work log

**Effort started:** 2026-08-13T12:14Z
**Keyed to:** [`2026-08-13T1214Z-unit-testing-assessment.md`](2026-08-13T1214Z-unit-testing-assessment.md),
the assessment that opened this effort — the timestamp in this filename is that
report's, deliberately, so every artifact of one effort sorts together.
**Status:** open. Appended to after each action.

> ### This file is APPEND-ONLY, and that is a different rule from the one governing reports
>
> [`README.md`](README.md) says a report is never edited after it is written, because a
> timestamp in a filename is a promise the contents are fixed. A work log cannot obey
> that rule and still be a log — so it obeys the rule behind it instead: **nothing already
> written here is ever revised or deleted. New entries are added at the end.** A mistake
> recorded at 15:51 stays recorded at 15:51, with its correction appearing later in its
> own entry rather than replacing it.
>
> Reports are snapshots. The register in `README.md` is current truth. This is the
> narrative that connects them: what was done, in what order, what it cost, and what it
> found. It exists so this effort can be reviewed later by someone who was not present —
> including its wrong turns, which are the part a clean summary would lose.

**Entry format.** Time (UTC), what was done, why, what it found, commit. Findings are
called out explicitly because they are the reason to reread this.

---

## Session 1 — 2026-08-13, 10:45Z to 15:52Z

### Preliminaries — 10:45Z and before

**Branch and attribution.** Work moved to `tests/unit-testing-assessment` (the assigned
`claude/…` branch was renamed with permission; its remote ref turned out never to have
existed on GitHub). AI attribution disabled at three layers: `~/.claude/settings.json`,
a project `.claude/settings.json` (gitignored), and the repo git identity pinned to the
owner with signing off — matching the existing 40+ commits, none of which carry such a
trailer. The identity mattered most: the container's session hook had pinned git globally
to a bot author address, which no attribution setting suppresses because it is the
*author* field, not a trailer. (Writing that address into this log is what the publish
scan then refused — correctly, and the first entry in this log to be caught by a gate
this effort was auditing.)

### 10:45Z — the initial assessment · `6c0491c`

Read every tracked shell script and awk program; ran the suite and both gates.

**Finding — the premise needed correcting.** The repository already had a good test
suite: 65 invariants in 1.8 s, each encoding a defect that really shipped, plus
`assert-test-catches` (mutation testing) and `devtools/check` (one gate). The gap was
never discipline; it was *reach*.

### 11:04Z — measure instead of assert · `d0a4704`

Built `devtools/coverage`: runs the suite under `xtrace` with a `PS4` carrying
`${BASH_SOURCE}`/`${LINENO}`.

**Finding — 13.1%, and my own reading had been wrong.** I had counted four scripts as
exercised. Measurement said **two**. `bt-phase` was 0.0% of 117 lines because the suite
tested its awk body *extracted by a Python regex from its own source*, never the shipped
script. `bt-incident` was stubbed; `repo-validate` runs the suite, not the reverse.

**Finding — the tool's own failure mode reads as a finding.** `PS4` is not inherited by
child shells. An earlier revision propagated `xtrace` via exported `SHELLOPTS`, worked
intermittently, and when it failed produced an *empty trace, a green suite, and every
file at 0%*. Fixed by enabling xtrace inside `BASH_ENV`; the tool now **exits 2 rather
than reporting 0%** on an empty trace. Verified by pointing `BASH_ENV` at `/dev/null`.

### 11:35Z — implement stages 1, 2, 4 · `d016249`

Guarded `systemd-analyze` in `repo-validate` (nine false unit failures and `rc=1` on any
systemd-less runner — verified, and it had to land before CI). Added CI, `tests/README.md`,
the table-driven awk fixture harness, `tools/lib/journal.sh`, and moved `bt-phase`'s awk
to `tools/lib/phase.awk` — byte-identical output verified on both paths before deleting
the extractor. 65 → 96 invariants, 13.1% → 18.3%.

**Finding — a dead diagnostic in `bt-interval`.** `interval.awk` exits non-zero on an
unparseable timestamp, so the branch naming *which* argument was bad could never fire;
callers got "arithmetic failed". Also read stdin when awk had no input file, so it could
block.

### 12:20Z — freeze the report, make it checkable · `10404b2`

Renamed the report to carry its UTC time; established the immutability convention; gave
every recommendation an ID (`UT-01`…`UT-13`) and a verify command; added `reviews/verify.sh`.

**Finding — four of my own verify commands did not work** when first run: one pointed
`--section` at a comment rather than a printed heading, one asserted `python3` had left
`run-tests` when three legitimate uses remain, and two quoted counts that were simply
wrong (109 "call sites" were every *mention* including comments; the line count was off
by 138). Corrected at freeze time with the originals recorded. **This is why the register
is executable.**

**Finding — my seam invariant had a false positive**, found by adding `verify.sh`: it
flagged the script that *greps for* the seam in order to report adoption. The detector
fooled by its own subject matter. Scoped to `tools/` and `bin/`.

### 12:46Z — the log sanitiser · `c91267c`

Re-prioritised: classifying files by *what it takes to run them* rather than by "does it
call journalctl" showed **1219 lines (31%) needed no seam at all** — `install.sh` and
`uninstall.sh` already default to dry run; the devtools are read-only. The seam was not
first.

Picked `sanitize-logs.sh` first — highest consequence per line, since it is what keeps
Wi-Fi BSSIDs (which geolocate the machine) out of a public repo. It had zero tests.

**Finding — it does not run on Ubuntu's default awk.** mawk 1.3.4 panics on the MAC
pattern, and its error message said to install "mawk >= 1.3.4", which is what was running.

**Finding — the capability gate tested one pattern and licensed the other two.** On mawk
the IPv4 pattern matched 7 of 12 characters of a dotted quad: a *partially* redacted
address, which the final `grep -E` verification cannot see because a fragment is no longer
a whole address.

**Finding, and a reverted fix — a positive-only probe is answered correctly by accident.**
mawk treats `(X){5,}` as `(X)+`, so a real MAC still matches at the right length while
`11:22` *also* matches and would be replaced. My first fix expanded the inner intervals;
the tool then *appeared* to work while silently over-matching. **Reverted.** The gate now
probes every pattern positively *and* negatively.

### 14:35Z — merge main · `942cb26`

Main had done a full-tree review (`b9cbf9e`, `4077cec`, `383b991`). Three conflicts, each
a case where both sides were right about something different.

**Finding — main's fix, my seam, both needed.** `bt-boot-provenance`: main filtered
`--list-boots` to numeric rows (the header row reaches `$((off - 1))` as literal `IDX`);
I had routed it through `bt_journal`. My fixture had no header row, so nothing here would
have caught it — and when I added one, **my assertions still passed with the defect
present**. The real symptom was worse than the stderr message: the header becomes a row
and the next boot's gap is computed against its garbage timestamp, printing `-226800s` —
a negative inter-boot gap, in the column EX-017 argues from.

**Finding — main's new check caught my bug.** `install.sh` gained two libraries;
`uninstall.sh`'s `FILES` list never did. Sixth instance of the hand-written-list class,
caught by an invariant written for the previous five.

**UT-13 closed from the other side:** main settled the pre-existing scan hits, so
`repo-scan --all` went into CI.

### 15:19Z — dry runs, publish gates, two proposals · `7c96671`

UT-07 (12 awk fixture cases + `DEPS` support), CS-02 (install/uninstall dry runs, with a
stamp-file write detector rather than a reading of `run()`), CS-03 (publish gates driven
over scratch repos — shown to go *red* on planted leaks and, critically, **not** to block
the commit that *removes* one), CS-05 (`bt-actions` on the seam).

**Finding — a coverage-tool bug.** `install.sh` showed 0.0% while its tests visibly ran
it: the suite invokes `./install.sh`, the trace records `./install.sh`, the coverable
table says `install.sh`, and the join is a string join. It had been at 60.8% all along.

**Finding — the gate caught my own fixture.** A planted TEST-NET address failed the
full-tree scan. Resolved by allowlisting RFC 5737 documentation space — the IPv4 analogue
of the existing `example.com` rule — and using a fragment-assembled private address.

Assessed the owner's two proposals (test classes; parameterising external tools) as
`2026-08-13T1517Z-test-classes-and-mocks.md`, items `TC-01`…`TC-03`.

### 15:30Z — the watchdog · `e55142b`, floor raised `7d6b237`

`bin/bt-hang-watchdog`: **0% of 183 lines → 81.8%**. Journal fixture, fake sysfs
(`BT_SYSFS_USB`/`BT_SYSFS_DRIVERS`), and PATH stubs for `systemctl`/`hciconfig`/`sleep`
that record to a **spy log** — the decisions are testable, the actuation never is.
Thirteen scenarios including give-up, EARLY mode, and the stage-2 refusal.

**Deviation recorded:** the report proposed `tools/lib/device.sh` wrappers; PATH stubs
achieve the same substitution with a two-line production diff instead of rewriting every
action call site in the most safety-critical tool.

**Finding — a mutation run that proved nothing.** My first attempt reported both mutations
caught when *neither had applied*: I grepped a section heading that existed only as a
comment. `--section` addresses printed output. The block now prints its heading.

### 15:37Z — mock fidelity · `ea47d20`, then `def19bc`

The owner's third proposal: check the mock against the real tool in isolation.
`devtools/journal-contract` verifies each shape the fixtures claim.

**Finding — the `systemd-journal-remote` blocker, and its cause.** It silently drops any
entry without `_BOOT_ID`, reporting "Finishing after writing 0 entries" while exiting 0;
the real reason appears only at debug log level. With boot IDs supplied, committed text
becomes a real journal, real `journalctl` runs over it, and the output is byte-diffed
against the fixture grammar — in any container, CI included.

**Finding — a fixture claims a shape the real tool does not emit.** `-b all` prints
`-- Boot <id> --` only *between* boots, never before the first; the stage2 fixtures carry
a leading separator. Harmless to `stage2.awk`, now asserted rather than rediscovered.

### 15:44Z — six tools on the seam · `def19bc`

CS-06 + CS-07. Assertions are *numbers the fixture determines* (the two boots carry
different kernel versions and timeout counts, so reading the wrong boot cannot pass).

**Three self-inflicted breaks, all caught here:** a `command -v journalctl` probe the seam
invariant flagged (naming journalctl reintroduces the dependency the seam removes — it now
asks `bt_journal`); a `command -v bt_journal` "fix" that cannot see shell functions; and
my own assertion using a bare-opcode timeout pattern, rejected by the repo-wide BT-1
spelling invariant.

### 15:48Z — the system round trip · `effd411`

`tests/system-roundtrip`: install for real, verify, uninstall for real, verify nothing
survives — the README's front-page claim, which is a property of the *pair*. Gated four
ways; the investigation machine fails gate 2 even if the variable is set.

**Finding — `bt-verify-install` cannot distinguish "missing" from "correctly skipped"**
for the five btmon-conditional artifacts. Recorded, not papered over; the check now runs
only where its premise holds. The two host-dependent checks were **gated rather than
weakened** — making a container green would have produced a test that passes everywhere
and proves nothing. The environment-independent direct-inspection check is the one that
never skips.

### 15:51Z — `bt-incident` ignored its sandbox · `2fcef33`

**The most consequential finding of the effort.** Testing CS-04 meant pointing
`BT_EVIDENCE_REPO` at a temp directory; three incident directories appeared somewhere
else entirely.

```sh
REPO="${BT_EVIDENCE_REPO:-...}"
[[ -d "$REPO/evidence" ]] || REPO=/root/exp/qca9377-bt-hang
```

The second line silently discarded an **explicit** override whenever the target lacked
`evidence/` — every fresh scratch directory — and redirected the write to one machine's
hardcoded home path. `BT_EVIDENCE_REPO` *is* the mechanism house rule 4 depends on to keep
fabricated incidents out of the real evidence tree, the rule written after ten of them
accumulated there. **The override was the sandbox, and it did not hold.** It also shipped
a personal directory layout in a public repo.

The suite never caught it because it stubs `bt-incident` away entirely — correct for
safety, but **stubbing a tool protects the suite from it rather than testing it**. That is
the general lesson: every tool mocked away for safety is a tool nothing exercises.

Fixed; two deliberately separate assertions ("wrote inside the sandbox" and "wrote nowhere
else" are different claims, and the second is the one that failed), both red under
mutation. The three stray directories were removed — they were the entire contents of that
tree; nothing pre-existing was touched.

### 15:52Z — register updated · `798f829`

---

## Where session 1 left things

| | at 10:45Z | at 15:52Z |
|---|---|---|
| Coverage | 13.1% (503/3846) | **38.3%** (1692/4423) |
| Invariants | 65 | **173** |
| Zero-coverage files | 41 of 43 | 28 of 48 |
| CI | none | validate, suite, coverage floor 30, journal contract, full-tree scan, system round trip |

**Open:** CS-04's `bt-sco`/`bt-capdiff` (need `btmon`), CS-09, TC-03's provenance
comments, UT-12 (splitting `run-tests`, ~2000 lines), and raising the CI floor to 35.

**The recurring lesson, stated once.** Six of the findings above are the same shape: a
check that could not fail, a measurement whose failure mode reads as a result, a mock
that was missing a case, a tool protected from testing by being stubbed. In every one the
code had been read carefully — several carried accurate comments about that exact hazard —
and only *running* it said so.

---

## Session 2 — 2026-08-13, 18:xxZ

### Assessment of the rebase attempt · branch `…-rebase-attempt-20260813-181317-utc`

A parallel effort rebased this branch onto `origin/main` at `d8b7abe`, producing
`e9f4967`. Assessed by measurement rather than by reading the summary. **Verdict: correct
in substance, with one real regression that must be fixed before the branch is used.**

**What is right.** Linear on `origin/main`; main's three new commits (`a57a450`,
`617476d`, `d8b7abe`) fully intact with nothing of main's removed; all 11 journal seams
present; `repo-scan --all` and the journal-contract CI steps present; `system-roundtrip`,
the work log, and the `bt-incident` sandbox fix present; install/uninstall parity check
present and passing (55 destinations, both new libraries listed); register content
equivalent; coverage equivalent (39.3%, 1749/4445 here vs 1744/4435 on this branch — the
+10 denominator is main's new lines); author and committer correct, no AI attribution.
Two incidental improvements over this branch: `sh reviews/verify.sh` → `reviews/verify.sh`
(the script is bash and was being run under `sh`) and a trailing space removed.

**The regression — three assertions lost.** A static comparison of every `ok`/`bad`
message in `tests/run-tests` (296 on this branch, 292 on the rebase) isolates exactly six
message lines, i.e. three assertions, all absent from the rebase:

```
bt-boot-provenance emits one row per boot, header excluded
no negative inter-boot gap reaches the table
bt-boot-provenance runs without shell errors on stderr
```

The rebase gains main's one new assertion (`no exhibit extraction command references a
session-temporary path`). Nothing else differs — 178 − 3 + 1 = 176, which is what both
suites report when run in the same environment.

**Why it matters, demonstrated rather than argued.** The production fix (the numeric
filter) and the fixture (its header row) both survived; only the assertions are gone. So
the branch still behaves correctly while no longer *detecting* the defect. Removing the
numeric filter on the rebase branch reproduces the original bug — a junk `IDX` row and a
`-313200s` inter-boot gap, in the column EX-017 argues from — and the suite reports
**"all 176 invariants hold"**. The same mutation on this branch goes red three ways.

**Root cause, and the general lesson.** `git rebase` replays individual commits and
discards merge commits, so any conflict resolution recorded *only* in a merge commit is
lost. Merge `942cb26` carried six such resolutions. The patch-up commit `e9f4967`
("Preserve merge resolutions in test rebase") restored five of them — it touches
`bt-boot-provenance`, the provenance fixture, both READMEs and `verify.sh` — but **does
not touch `tests/run-tests` at all**, which is where the three assertions lived. The
production code and the fixture were restored; the checks that give them meaning were
not. That asymmetry is the thing to watch for whenever a merge is rebased away: a
resolution is usually a *pair* — a fix and the assertion that pins it — and restoring
only the visible half leaves a green suite over an unprotected defect.

**Fix.** Cherry-pick the three assertions from `903a908`'s `tests/run-tests` into the
rebase branch (they sit immediately after the "computes the inter-boot gap" assertion in
the `whole tools` section), then confirm the mutation goes red. Not applied here: the
rebase branch is not this session's designated branch.

### Own rebase onto `d8b7abe`, and what it proved

Backup taken first: `tests/unit-testing-assessment-backup-20260814-013523-utc`, pushed and
verified identical at `9cf2a9d`.

Before starting, the merge commit's true resolution content was extracted mechanically
with `git show --cc 942cb26` — **8 files, 56 lines belonging to neither parent**. That is
exactly what a flat rebase discards, and having it as a checklist is the difference
between the two attempts.

Six conflicts, resolved on the same principle as the original merge — keep both sides
where they are additive:

| Conflict | Resolution |
|---|---|
| `devtools/README.md` | one `check` row (main's wording) + the `coverage` row |
| `tools/bt-boot-provenance` | `bt_journal` seam **and** main's numeric filter |
| `tests/run-tests` (×2) | both test sections; second time, dropped a duplicated parity block |
| `.github/workflows/checks.yml` | journal-contract step **and** the full-tree repo-scan step |
| `tools/bt-boots` | `bt_journal` seam **and** main's `k="?"` fix |

**The rebase lost the same three assertions the other attempt lost.** That is the finding
worth recording: it is not a mistake the other context made, it is an inherent property
of flat-rebasing a branch whose merge commit carried resolutions. The assertion-set diff
caught it immediately; the checklist then showed four more losses in the same class —
the fixture header row, `uninstall.sh`'s two new libraries, the register's UT-13 row and
`verify.sh`'s UT-13 check. All restored from the backup, having first confirmed main's new
commits touched none of those four files.

Verified afterwards: assertion set a strict superset of pre-rebase (296 → 298, zero lost);
runtime invariants 178 → 179, zero lost; `repo-validate`, `repo-scan --all`, and the
journal contract all clean; register 11 verified; coverage 39.5% (1757/4453); linear on
`origin/main`; single author; no attribution strings. Decisively, re-introducing the
header-row bug now **fails 2 invariants** where the other attempt reported all green.

### Head-to-head, and adopting the other attempt's improvements

With both rebases complete, the content diff between them is four files:

| File | Difference |
|---|---|
| `tests/run-tests` | 27 lines — the three assertions they lost, which mine has |
| worklog | 92 lines — entries written after their branch was cut; not a defect |
| `reviews/README.md` | `sh reviews/verify.sh` → `reviews/verify.sh` — **their improvement** |
| `reviews/verify.sh` | a trailing space removed — **their improvement** |

The assertion sets differ in one direction only: mine is a strict superset. Their two
improvements are real — `verify.sh` is a bash script and running it under `sh` is wrong —
and are adopted here. Nothing else separates the two branches, which is the useful
conclusion: the other attempt was sound work with one systematic gap, not a flawed one.

### Correction — an assertion of mine could not fail for the reason it named

The implementer of the other rebase attempt reviewed both branches, agreed the newer one
should be the continuation point, and raised two corrections to the entries above. Both
were checked here rather than accepted. **Both are right, and the first is not a
documentation nit — it is a defect in one of my tests.**

**1. "The mutation goes red three ways" was false when written.** It went red *two* ways.
The third assertion —

```sh
rows=$(awk '$1 ~ /^-?[0-9]+$/ { n++ } END { print n + 0 }' <<<"$PROV")
[[ "$rows" == "2" ]] && ok "bt-boot-provenance emits one row per boot, header excluded"
```

— counts rows whose first field is numeric. `IDX` is not numeric, so the header row it
claims to exclude was never counted, and the count stayed 2 **with the bug present**. It
passed while asserting "header excluded". That is precisely the shape this suite exists
to eliminate: a check that cannot fail for the reason its name gives. It was written in
the same commit as the two that do work, and its passing alongside their failing is what
made "three ways" look true at a glance.

Rewritten to read the table region and require every printed row to be a boot:

```sh
tbl=$(awk '/^──/ { inb = 1; next } inb && NF == 0 { inb = 0 } inb { print }' <<<"$PROV")
rows=$(grep -c . <<<"$tbl"); nonnum=$(awk '$1 !~ /^-?[0-9]+$/ { n++ } END { print n + 0 }' <<<"$tbl")
```

With the bug re-introduced it now reports `table has 4 row(s), 2 non-numeric`, and the
mutation fails **3 of 179** invariants. The claim is true now; it was not before.

**2. The 27-line `run-tests` difference is not all assertion block.** Measured: 21
substantive lines and 6 bare-`echo`/blank spacing lines. The earlier entry's "principally
three provenance assertions" was right in emphasis and loose in arithmetic.

**Worth recording about the review itself.** This suite, its mutation testing, and its
executable register all ran green over an assertion that did nothing — for the same
reason the original defect survived: everything agreed with everything else. An outside
reader with no stake in the branch found it in one pass. That is an argument for external
review sitting alongside, not behind, the automated gates.

---

## Session 3 — 2026-08-14

Resumed after the rebase settled. `origin/main` had not advanced past `d8b7abe`, so
this session is pure coverage work: the *reporting* tools, which had 0% between them
and which are the ones whose output a person quotes when deciding what to do.

The pattern for the whole session, stated once: **each of these four tools was read
carefully before it was tested, and three of them turned out to be wrong in a way the
reading did not surface.** That is the same lesson as session 1 and it is recorded again
because it kept being true.

### `bt-status` · `0e453cb` — the verdict an operator acts on

98 lines whose entire output is a judgement about right now. Converted to `bt_journal`
plus `BT_SYSFS_USB` / `BT_SYSFS_BT` (real kernel paths by default), so a fake device
tree drives the verdicts. Asserted the three that differ in what a person does next:
stage 2 (off the bus, power cycle required), enumerated-but-no-adapter (btusb never
bound), and healthy.

**Finding — one verdict, two exit codes.** The full path had no explicit `exit` and
returned whatever the last command left behind, so a down controller exited 1;
`--brief`, which exits 0 by hand, reported 0 for the identical state. A caller writing
`bt-status && …` got different behaviour from a *display* flag. This is a report, not a
check — `bt-diagnose` is the tool with documented 0/1/2 semantics — so it now exits 0
explicitly and an invariant asserts the two modes agree.

`0.0% of 98 → 81.7% of 104`; suite 186.

### `bt-postmortem` · `d776b84` — the conclusion drawn about a hang

Four mutually exclusive verdicts, each now driven by its own fixture. Introduced the
`SEAM-ADVICE` marker: the seam invariant forbids a direct `journalctl` call in
`tools/` and `bin/`, but some lines are advice *for the operator to type*, and those
must name a real command. The marker exempts them visibly rather than by weakening the
rule.

`0.0% of 100 → 73.2% of 112`; suite 191.

### `bt-health-report.sh` · `ef8f017` — "did the fix help?"

The tool whose output settles whether the mitigation works, computed from per-boot
counts. A miscount here is a wrong claim about the one conclusion this repository
exists to reach.

The fixture makes the two boots **differ** — boot −1 carries four timeouts, boot 0
carries none — so a tool that read the wrong boot, or pooled them, cannot produce both
numbers. The assertion reads the counts out of the table *by boot id* rather than
grepping the whole output, so a right number on the wrong row still fails. That shape
is a direct consequence of the correction at the end of session 2.

**Finding 1 — `column(1)`.** Sections 4 and 5 piped through it unguarded. It lives in
`bsdextrautils` and is absent from minimal images, so `column: command not found` would
land in the middle of a report someone is reading for a verdict. Now behind `col()`,
which falls back to `cat` — the same shape as the `systemd-analyze` guard in
`repo-validate`.

**Finding 2 — self-inflicted, and worth recording as such.** My own blanket seam
replacement rewrote the closing operator advice to `bt_journal -u bt-hang-watchdog -f`.
`bt_journal` is an internal shell function; no user can run that. Caught by reading the
output rather than by any test, which is why an invariant now pins the advice line. The
line also moved out of the quoted heredoc so the `SEAM-ADVICE` marker could be a shell
comment instead of printed text — inside a quoted heredoc every character reaches the
operator, and a test-infrastructure token has no business in a report.

`0.0% of 116 → 78.0% of 123`; suite 196.

### `bt-exhibit` · `7a5b802` — the tool whose output actually ships

Exhibits are the factual material of a public kernel bug report. 134 lines, never
executed. **It needed no seam:** `BT_REPO` already parameterised the destination and
nobody had ever pointed it anywhere. That is the whole cost of testability here.

Running it found that "the output is sanitised" was true and insufficient.

**Finding 1 — a missing sanitiser was treated as safe.** A *failing* sanitiser refused
and wrote nothing; an *absent* one printed a warning on stderr and wrote the raw output
as a published exhibit. Both mean the same thing. `bt-exhibit` prints the exhibit path
on stdout precisely so it can be used in a pipeline, which is where nobody reads
stderr — the safest-looking failure was the only unsafe one. Both refuse now.

**Finding 2 — only the *output* was ever sanitised.** The extraction method is written
verbatim by design, and the ordinary way to extract evidence about one device is to
grep for it: `journalctl -u bluetooth | grep dev_de_ad_…` is the BlueZ D-Bus form that
carried the 20-address leak of 2026-08-12. An address in `--cmd`, `--claim` or `--why`
shipped untouched through the one field the format guarantees is verbatim.

This **refuses rather than redacts**, because the two guarantees are otherwise
incompatible: the document promises the command is "re-runnable as-is", and a redacted
command is not. An exhibit needing an address should match a pattern instead — better
evidence anyway, since it does not depend on one machine's hardware. Checked before
shipping the refusal: none of the 21 existing exhibits has an address in its command,
so nothing that exists is broken.

**How finding 2 surfaced, which matters more than the finding.** The redaction
assertion failed — and failed for the *wrong reason*. The output had been redacted
correctly; the original address survived in the command line above it. The same
assertion was also satisfiable by the boilerplate redaction notice, which itself
contains `AA:BB:CC:00:00:NN`; it now requires a substituted placeholder rather than the
prefix. A test that passes for the wrong reason and a test that fails for the wrong
reason are the same defect seen from two sides, and this session produced one of each.

`0.0% of 134 → 94.7% of 150`; suite 214.

### Where session 3 stands

| | end of session 2 | now |
|---|---|---|
| Coverage | 38.3% (1692/4423) | **49.9%** (2291/4591) |
| Invariants | 179 | **214** |
| Zero-coverage files | 26 of 48 | 23 of 48 |

Findings this session: 5 (one exit-code inconsistency, one missing-dependency crash,
one self-inflicted output corruption, two publish-safety holes). Production diff to get
them: roughly 60 lines, all of it guards and refusals.

### Session 3, continued — the tools that could only run on the sick machine

Group 1 was the *reporting* tools. This group is the ones that could not be tested
because running them meant doing the thing they do: verifying an installation,
verifying a restoration, diagnosing a stranger's hardware, switching the machine
between observing and protecting itself. All four needed seams; none needed logic
changed.

**`bt-verify-install` · `a1f1142` · 0% → 82.4%.** The tool whose only failure mode is a
false all-clear, and it has hit it twice: a hand-written artefact list that omitted six
tools installed on 2026-08-12, and a line-by-line parse of `install.sh` that turned every
backslash-continued call into a destination of `\`, reporting seven phantom missing
files. Both were fixed by deriving the list from `install.sh`; neither fix had a test.

Almost nothing was needed — the checkout is already an argument and the destinations come
out of *that* checkout's `install.sh`. Only `BT_UDEV_DIR` and `BT_MODE_STAMP` were added,
and only because the success path was otherwise unreachable.

The continuation bug is pinned **by consequence, not by output shape**: a destination
parsed as `\` is dropped for not being absolute, so the file is never compared and its
drift is invisible. The fixture's continued entry is made to drift and the report must
name it. Reverting the awk join fails that assertion and nothing else.

Two of the nine are negative controls. `bt-mode experiment` stops the intervening units
on purpose, and counting that as drift would tell the reader to run `install.sh --apply`,
which reverts the controlled baseline — the two tools would push the machine back and
forth, each "fixing" the other. So the suite also asserts that stopped units *are* drift
with no mode stamp, and that experiment mode does *not* exempt `bluetooth.service`.
Without those, "exempts intervening units" is satisfied by an exemption that swallows the
whole Services block.

**`verify-restored.sh` · `621917d` · 0% → 86.1%.** "Yes, the machine is back to normal" —
the one claim nobody re-checks by hand, because checking it by hand is the work this
script replaced.

The six artifacts it names literally are deliberately **not** overridable: they are the
revert contract, and a test that redirects them tests nothing. That makes the
fully-restored assertion depend on host state, so it is **gated rather than faked** — on
the investigation machine, with the project installed, "restored" is legitimately false
and the case says so out loud instead of passing.

The assertion that matters most covers the gap *between* two tools rather than inside
either: `bt-mode experiment` moves files aside to `<name>.disabled`, `uninstall.sh`
removes only the active names, so an experiment → uninstall sequence leaves every
disabled file on disk. A check testing only `-e` would call that a clean revert.

**`bt-diagnose` · `8abfd75` · 0% → 91.8%.** The standalone entry point: a stranger clones
the repo, runs this, and its answer decides whether they keep reading. Three documented
exit codes, none ever executed.

The distinction it draws *is* the project's claim — timeouts without resets is the bug,
timeouts with resets is a different problem this repository does not document. Telling a
stranger they have this bug when they do not is the worst thing the tool can do, so both
sides are asserted. The signature fixture splits 2 timeouts into boot −1 and 1 into boot
0, so the expected total of 3 proves the per-boot counts are summed; and it carries one
`link tx timeout` line — ACL supervision, a different layer — which must be excluded. The
three exit codes are additionally asserted as **one** claim, because two verdicts
collapsing onto one code is invisible in any single-scenario check.

New in the seam library: `bt_journal_available()`. "Is a journal reachable at all?"
belongs to the seam, not its callers — the seam decides where the journal comes from, so
it is the only thing that can answer whether there is one.

**`bt-mode` · `5907be5` · 0% → 98.0%.** The switch that turns the safety net off. If its
restore is incomplete the machine stays in experiment mode while everything reports
normal: watchdog off, nobody told, next hang is a cold boot.

Added `--dry-run`, which `install.sh` and `uninstall.sh` have and which this suite already
calls their contract. **Opt-in, not the default** — defaulting to a dry run would silently
turn `bt-mode experiment` into a no-op, and an operator who believes the watchdog is off
while it is still rescuing the controller collects censored trials without knowing. A
wrong answer about the mode contaminates the evidence, which is worse than no answer.

Every mutation goes through `run()` or `write_to()`, so the dry run cannot drift from
apply: they are the same call site with one branch between them.

One deliberate behaviour change: mitigation wrote `0` to `enable_autosuspend` while
printing `enable_autosuspend=N`. The kernel accepts both for a bool parameter, so nothing
was wrong — the code now writes what it says, and matches the `Y` its counterpart writes.

**The last assertion in that block is the sandbox itself.** This suite runs as root on the
machine under investigation and every bt-mode assertion runs in APPLY mode, so the block
ends by checking that no real override was moved aside. A leaked seam there disables the
watchdog on the host — the one failure that must not be discovered later. It is the same
shape as the `bt-incident` sandbox assertion, written for the same reason.

### CI floor raised 30 → 55

A ratchet, not a target: it sits below the current 58.7% so ordinary work cannot trip it,
and it rises only when a stage lands. Its job is to stop coverage falling silently as
tools grow. "Every test encodes a defect that shipped" remains the actual rule.

| | end of session 2 | after Group 1 | now |
|---|---|---|---|
| Coverage | 38.3% | 49.9% | **58.7%** (2785/4747) |
| Invariants | 179 | 214 | **250** |
| Zero-coverage files | 26 of 48 | 23 of 48 | 19 of 48 |
| Journal seam | 13 tools | 13 | 15 |

Findings across session 3: 5 in Group 1, 0 in Group 2. That asymmetry is itself worth
recording — Group 2's four tools were **correct**, and the whole cost of proving it was
parameterising paths that were hardcoded for no reason other than that nobody had needed
them otherwise. The seams are the deliverable there, not the bug list.

### Session 3, part 3 — the capture and evidence stack

Group 3 is `bin/` — the things systemd runs, which write to `/run`, `/var/log` and
debugfs. Testing them at all required deciding, for each, what a test is allowed to
touch. Every one got path seams defaulting to the real location; none had its logic
changed except where noted.

#### Correction to the `bt-state` entry — `71dc1c4`

That commit message says `bt-state --tsv` "is what bt-health-snapshot appends to
metrics.tsv". **It is not.** `bt-health-snapshot` computes its own fourteen-column row
and never calls `bt-state`. `bt-state` is called by `bt-trial` (`state-before.txt`,
`state-after.txt`), by `bt-incident` (`state-now.txt`) and by `bt-status`.

The claim about *why the column order matters* survives the correction — a reordered
row still silently reassigns every value in the per-trial evidence files — but the
consumer named was wrong, and the commit is pushed and immutable, so the correction
lives here. Checked with `grep -rn bt-state bin tools install.sh`, which is what should
have been run before writing the sentence.

#### `bt-verify-kernel-mechanism` · `692d46b` · 0% → 95.9%

Whether btusb defines `btusb_qca_reset` or `btusb_qca_cmd_timeout` decides how every
recovery experiment here is interpreted. `BT_MODULES_DIR` was the only seam needed — the
kernel release is already an argument — so a fabricated `btusb.ko` carrying chosen symbol
strings and `usb_device_id` byte sequences drives every verdict.

**Finding — the tool was blind on this machine.** `hexdump(1)` is in `bsdextrautils`, the
same package as the `column(1)` gap found in Group 1, and the redirect was silenced. With
no hexdump the hex file never appeared, every grep missed, and **all seven device IDs
printed ABSENT — including 13d3:3491, 3496 and 3501, which are genuinely in the table.**
That reads as "the comparators are missing too", the exact opposite of the argument the
section exists to make: that this device's absence is an isolated gap. The machine this
was written on has no hexdump, so it has presumably been reporting that since it was
written. Now falls back to `od(1)`, treats an empty dump as failure whatever the exit
status said, and reports UNKNOWN rather than ABSENT.

The central claim is asserted as **one pair** — comparators present *and* 3503 absent —
because "3503 absent" is evidence of an isolated gap only if the neighbours are present,
and a tool finding nothing at all satisfies half of it while meaning the opposite.

#### `bt-health-snapshot` · `3f50262` · 0% → 100%

The writer of `metrics.tsv`. Header written once, rows appended forever; a row that stops
matching the header corrupts every reading from that point on and the file cannot show it.

**A check of mine that could not fail for the reason its name gave.** "Row width matches
the header (14 columns)" was mutation-tested by deleting the last printf *argument* while
leaving its `%s`. printf emits an empty field for the missing argument, so the row still
had fourteen fields and the assertion passed a mutation that silently blanked a column.
A no-blank-field check catches that; deleting a `%s` is caught by the width check. Two
mutations, two assertions, neither sufficient alone.

#### `bt-evidence` + `bt-mark` · `15e47d3` · 0% → 92.8% / 100%

**Two more checks of mine that could not fail**, both found by asking what would turn them
red rather than by watching them pass:

1. The sandbox check was `[[ ! -e evidence/sessions/*probe-session* ]]`. `[[ -e ]]` does
   not expand globs — it tested a path containing literal asterisks, which never exists,
   so it passed unconditionally. Now counted with `find`, and proven red by planting a
   directory.
2. "Records the command's exit status, not the pipeline's" was satisfied by `$?` as well
   as `${PIPESTATUS[0]}`, because under `pipefail` they agree for a *failing* command. The
   two diverge only when the sed fails and the command did not, so that is now driven
   directly with a sed stub that copies its input and exits 1.

Three of my own assertions in one session have now been found unable to fail. That is the
argument for mutation-testing every new check rather than the interesting ones: all three
were written carefully, and all three passed.

#### `bt-dyndbg` · `2a1cb97` · 0% → 73.6%

Which debug sites are enabled is a measurement decision, not a convenience — logging on
the receive path moves the timing window under study. The selection has been wrong twice,
and both fixes are lists in the script that nothing checked.

Two production changes. `BT_DYNDBG_CTL` seams the debugfs path. And control writes now
**append**: each write is a command and debugfs has no truncate operation, so `>` and `>>`
are identical against the real target — they differ only against a regular file, where `>`
would leave just the last command of the run. Free in production, and it is what makes the
selection observable at all.

The ordering the source states in a comment — files first, then the per-packet functions
inside them — is asserted by line position in the command stream, because the reverse
order re-enables every one of them and returns silently to the 5.8 GB/h flood.

### Where session 3 stands now

| | end of session 2 | Group 1 | Group 2 | now |
|---|---|---|---|---|
| Coverage | 38.3% | 49.9% | 61.3% | **66.7%** (3287/4926) |
| Invariants | 179 | 214 | 261 | **292** |
| Zero-coverage files | 26 of 48 | 23 | 19 | 14 of 48 |
| Journal seam | 13 tools | 13 | 16 | 19 |

**Still at zero:** `bt-capdiff` and `bt-sco` (need `btmon`), `bt-trace` and `bt-usbmon`
(foreground capture daemons — they need a run-one-iteration seam, which is a design
decision, not a mechanical one), the devtools that run the suite (`coverage`, `check`,
`assert-test-catches`, `journal-contract`, `repo-save`), `reviews/verify.sh`, and
`tests/system-roundtrip`, which is CI-gated by design.

Findings across session 3: **7** — one exit-code inconsistency, two missing-dependency
blindnesses (`column`, `hexdump`, both from `bsdextrautils`), one self-inflicted output
corruption, two publish-safety holes in `bt-exhibit`, and one dry-run gap in the tool
that turns the watchdog off. Plus three of my own checks that could not fail.

### Session 3, part 4 — btmon was never the blocker

CS-04 had carried "`bt-sco`/`bt-capdiff` need btmon" as a blocker since session 1. That
was wrong, and it was wrong in a way worth naming: **the blocker was stated in terms of a
missing program rather than in terms of what the tools actually consume.** `btmon` reads
btsnoop, which is binary and cannot be committed — `sanitize-logs.sh` cannot parse binary
formats and `repo-scan` refuses it. But `btmon` *emits decoded text*, and everything that
needed testing in these two tools is text parsing. So the seam is `btmon` itself, on
`PATH`, and the fixtures are its output.

The stub deliberately ignores its arguments (bt-sco) or reads only `-r` (bt-capdiff). A
stub that asserted the full call shape would be testing the invocation rather than the
parsing, and would break the day a flag is added.

`tests/btmon/README.md` records the provenance **and the limit**, which closes the open
half of TC-03: these fixtures pin how the tools read btmon's format; they cannot pin that
the format is still what btmon emits. `devtools/journal-contract` closes that gap for the
journal by building a real journal and diffing real `journalctl` output against the
fixture grammar. The equivalent needs a committable btsnoop, which the publish rules
forbid — so the gap is **recorded rather than closed**, and it is why `--raw` exists in
both tools.

#### `bt-sco` · `e5883d4` · 0% → 59.0%

Eleven invariants. The one that matters most is the hang signature — a setup with no
completion — asserted in both directions: present on the unanswered fixture, and *absent*
on the paired one, so an ordinary capture cannot grow a warning that means nothing.

The startup supported-commands bitmap gets its own fixture, because a bare grep for
"Setup Synchronous Connection" matches it too: the controller names the command once per
adapter with no request behind it. Widening that grep fails three invariants.

**One of my assertions was wrong on the first run.** It required the second setup to fall
outside a ±2 s window — but a setup always sits inside its own window. The fixture now
carries a Number of Completed Packets event 5.6 minutes from either mark, which is a
record the bound can actually exclude.

#### `bt-capdiff` · `7276bb0` · 0% → 86.6%

**Finding — the overlap bound manufactured its own disagreement.** `lo` and `hi` came from
raw first/last timestamps on two clocks that differ by a variable scheduling delay — the
delay the matcher exists to absorb. A pair straddling a boundary had one member inside the
window and one outside, and the one inside was reported unmatched. That happened at **both
edges of every comparison**, so two perfectly agreeing captures could not report agreement
unless their boundary records aligned exactly. Now widened by the tolerance and compared
numerically via `iso_secs`.

**Finding — "Unmatched records in both directions" was printed unconditionally**, including
when every unmatched record was on one side. One-sided is the reading that matters: it says
one path missed traffic the other caught, where two-sided is usually the clock or the
decoding differing.

**And the suite caught me writing an old defect back in.** My first version of the widened
filter passed an inline awk program alongside `-f` — which awk reads as an input filename.
That is the exact trap `tests/run-tests` scans for, and the one that once made *this tool*
report perfect agreement between paths differing by 278 records. It went red on my comment
text before it could go red on my code, which is a fair description of how these invariants
earn their keep: the rule was written down as an executable check by someone who had been
bitten, and it bit the next person on the same line.

### Session 3 close

| | session 2 end | Group 1 | Group 2 | Group 3 | now |
|---|---|---|---|---|---|
| Coverage | 38.3% | 49.9% | 61.3% | 66.7% | **69.9%** (3479/4978) |
| Invariants | 179 | 214 | 261 | 292 | **310** |
| Zero-coverage files | 26 of 48 | 23 | 19 | 14 | 12 of 48 |
| Journal seam | 13 tools | 13 | 16 | 19 | 19 |
| CI floor | 30 | 30 | 55 | 55 | **65** |

**Nine findings this session**, all of them in code that had been read carefully and in
several cases carried an accurate comment about the very hazard that bit it:

| Tool | Finding |
|---|---|
| `bt-status` | one verdict, two exit codes — a *display* flag changed the code |
| `bt-health-report.sh` | `column(1)` unguarded; and my own seam pass corrupted the operator advice |
| `bt-exhibit` | a missing sanitiser was treated as safe; an address in `--cmd` shipped verbatim |
| `bt-mode` | no dry run on the tool that turns the watchdog off |
| `bt-verify-kernel-mechanism` | `hexdump` absent ⇒ every device ID reported ABSENT, including the comparators |
| `bt-capdiff` | the overlap bound invented disagreements at both edges; one-sided loss mislabelled |

Two of those — `column(1)` and `hexdump(1)` — are the **same package**, `bsdextrautils`,
absent from minimal images, silenced by a redirect, turning into wrong *content* rather
than a visible error. That is now a pattern worth grepping for rather than a coincidence.

**Four of my own assertions could not fail** for the reason their names gave: a row-width
check blind to a blank column, a sandbox check using `[[ -e ]]` with a glob, a `PIPESTATUS`
check that `$?` satisfied under `pipefail`, and a `--window` check whose excluded record
was itself a window mark. All four were written carefully; all four passed; all four were
found by asking what would turn them red. That ratio — four bad checks against nine real
findings — is the argument for mutation-testing every new assertion rather than the
interesting ones.

**Still at zero:** `bt-trace` and `bt-usbmon` (foreground capture daemons — they need a
run-one-iteration seam, which is a design decision rather than a mechanical one), the
devtools that wrap the suite (`coverage`, `check`, `assert-test-catches`,
`journal-contract`, `repo-save` — testing them from inside the suite they run is a
recursion problem, not a seam problem), `reviews/verify.sh`, and `tests/system-roundtrip`,
which is CI-gated by design.

### Session 3, part 5 — the daemons, the publish gate, and one change backed out

#### `bt-trace` / `bt-usbmon` · `a4b190c` · 0% → 38.0% / 53.1%

Both run in the foreground under systemd and never return, so nothing could run them.
Both were given `--check`: verify the prerequisites, report the resolved configuration,
run the retention pass once, exit.

**That is an operator command before it is a test seam,** which is the bar a new mode has
to clear. "The capture is not running and I do not know why" is answered by btmon's
absence, a missing debugfs mount, or a filesystem already under the floor — and each of
those is a silent exit or an *idle loop* inside a unit whose journal says only "starting".
`bt-usbmon` idles deliberately (a clean exit respawns it under `Restart=always` and fills
the journal with one line), so there was no way to ask it what it had resolved without
waiting on it.

**Finding — `bin/bt-usbmon` was tracked mode 100644.** The only script in the tree that was
not executable. `install.sh` gives it 0755 at its destination, so an installed system was
fine and nothing noticed; but `bin/bt-usbmon` from a checkout exits 126, and the README
tells a reader to clone and run these directly. It was found by writing the first test that
ever tried to run it — the first run failed with rc=126 rather than with anything about
capture. A new repo-wide invariant derives the script list from the shebang, so one added
tomorrow is covered without anyone maintaining a list.

#### `devtools/repo-save` · `c7920d8` · 0% → 83.3%

The gate that enforces **this repository's own attribution rule**, and it had never been
executed by anything. Nine invariants, all `--no-push` against a scratch repo, and the
group ends by asserting that scratch repo has no remote at all — so `--no-push` is not the
only thing standing between a test run and a push.

Each of its recorded defects is now pinned to an assertion: staging before scanning
(neutering `git add -A` fails four invariants), `-F` from a stream snapshotted before
scanning, unknown flags rejected rather than becoming the message, and the MAC check
counted rather than `| grep -qv` — under pipefail that pipeline exits non-zero exactly
when it *matches*, so a real address would have taken the clean branch.

#### A change to the measuring instrument, made and then backed out

`tools/bt-actions` reports **16.4%**, worst in the tree. That is a measurement artifact,
not a coverage gap: 179 of its 177 "coverable" lines are a single inline awk classifier,
and bash traces a multi-line command once, at its opening line. The suite does drive that
classifier from a fixture. The number says "least tested" about the file whose analysis is
pinned by a table of cases.

`devtools/coverage` already excludes here-document bodies for exactly this reason, so
excluding inline single-quoted program bodies looked like closing an inconsistency rather
than moving a goalpost. Implemented, it moved the headline 72.6% → 76.6% and `bt-actions`
16.4% → 85.3%.

**It was backed out**, because the numerator also moved: 3685 executed lines → 3679, and
the six lines could not be accounted for. Adding a guard that refuses to exclude any line
the trace shows was executed did not recover them, and a direct check of the one region
the heuristic touches showed bash traces only its first and last lines — so the six are
still unexplained.

Six lines out of 3685 is 0.16%, and the change would have improved the number. Both of
those are arguments for shipping it, and both are the wrong argument. This is the
instrument every other figure in this log is measured with; an unexplained discrepancy in
it is the same class of defect as the empty trace that once reported every file at 0% and
looked like a finding. A conservative lower bound whose bias is documented is worth more
than a tighter number with a hole in it.

So the artifact is recorded here instead: **`bt-actions` at 16.4% and `bt-trial` at 62.2%
are floors set by embedded awk, not gaps to chase.** The real remedy is the one already
applied to `phase.awk` — extract the classifier to `tools/lib/actions.awk` and give it
fixture cases — which is work, not a measurement change, and is left open.

### Session 3 final

| | session 2 end | now |
|---|---|---|
| Coverage | 38.3% (1692/4423) | **72.6%** (3685/5073) |
| Invariants | 179 | **329** |
| Zero-coverage files | 26 of 48 | **8 of 48** |
| Journal seam | 13 tools | 19 |
| CI floor | 30 | 65 |

From the opening assessment's baseline: **13.1% → 72.6%**, **65 → 329 invariants**,
**41 of 43 files at zero → 8 of 48**.

**Still at zero, and why** — all eight are the harness, not the product:
`devtools/coverage`, `devtools/check`, `devtools/assert-test-catches` and
`reviews/verify.sh` all *run the suite*, so testing them from inside it is a recursion
problem rather than a seam problem; `devtools/journal-contract` is independent but already
a CI step and would double the suite's runtime; `tests/system-roundtrip` is CI-gated by
design; and two `tests/journal/*/boot-list` files are three-line fixtures.

**Ten findings this session**, every one in code that had been read carefully, and several
carrying an accurate comment about the exact hazard that bit it. Two of them —
`column(1)` and `hexdump(1)` — are the same package, `bsdextrautils`, absent from minimal
images, silenced by a redirect, turning into wrong *content* rather than a visible error.
That is a pattern to grep for, not a coincidence.

**Four of my own assertions could not fail** for the reason their names gave, and one more
asserted something impossible. All were written carefully; all passed. Against ten real
findings, that ratio is the argument for mutation-testing every new check rather than the
interesting ones — and for the two occasions this session when the suite's own invariants
caught me: once for writing an inline awk program alongside `-f`, the exact trap that made
`bt-capdiff` report agreement between paths differing by 278 records.

---

## Session 4 — 2026-08-14 · "why is 100% hard here?"

Opened by the owner's question: other projects reach 100% easily, this one does not.
The full analysis is [its own report](2026-08-14T0443Z-why-100-percent-is-hard-here.md).
The short version is that **the premise was right and the diagnosis was not what it looked
like**: three different things were being added together under one percentage, and only
one of them was a testing problem.

### What the measurement was actually saying

Of 1648 uncovered lines: 302 were inside embedded awk programs, ~310 were in files that
*run the suite*, 72 were the suite's own `bad` branches, 206 were the installer's
`--apply` path (covered by a CI-gated test the measurement excluded), 102 were capture
loops. **Roughly a third was unmeasurable by construction, and the tool had no way to say
so.** A percentage cannot distinguish "nobody tested this" from "this instrument cannot
see this", and the two demand opposite responses.

Separating them moved the figure 71.0% → 84.0% **without writing a test.**

### The four things that were missing · `7e9e9f2` `eeef93d` `d58866f` `331e7a2`

**A list of the uncovered lines.** `devtools/coverage` printed a ranking of files and
never printed which lines. That is the single biggest reason this felt hard, and it is
why three sessions ran by guessing which tool was untested and reading it. `--uncovered`
now prints them, generated from the same two tables as the ratio so the detail cannot
contradict the summary.

**Coverage of the second language.** `devtools/awk-coverage` reads `gawk --profile`: 884
profiles from one run, 1534 statements, 105 distinct programs.

**A denominator of reachable lines only**, and **an exclusion list with reasons** that a
100% floor could stand on.

### The finding · `744b855`

`awk-coverage`'s first output was the point of the whole session. `tools/bt-actions`'
classifier stood at 39%, and the branches that had never executed were the ones that
recognise **stage 2** — `USB descriptor read FAILED`, `device NOT ACCEPTING ADDRESS`,
`xHCI setup device command TIMEOUT`, the AVDTP timeouts. The controller leaving the USB
bus is the part of this bug the kernel log barely records and the part the report turns
on. The rules existed and nothing had run them.

**A pattern that does not match is not a wrong answer, it is silence.** The reconstructed
timeline would not have contained the most important event in the capture, and nothing
would have looked wrong. Now 172/172, against a fixture carrying one line per rule.

### Four bugs in my own new tool, all the same shape

`awk-coverage` reported that classifier at **0 of 172** while its tests passed and its
output was correct. Three separate normalisations were missing, and each one made the
grouping key depend on the thing being measured: the count column; gawk's rule-number
comment (`{ # 3`), appended to rules it *executed* and omitted from those it did not; and
leading indentation, because the count column *replaces* one tab. Runs that executed and
runs that did not were filed as different programs, and only the empty ones kept the
name. A fourth was a scalar/array name clash that killed the report awk — whose stderr
went to the file holding the percentage, so the tool printed an empty table, no total,
and exit 0.

### The self-check earned itself six times

An excluded line that the suite *actually executed* aborts the run. It rejected a
whole-file entry for `tests/run-tests` (1200 executed lines would have left the
denominator while staying in the numerator) and five ranges that got the traced-line
convention backwards. Which line of a multi-line construct bash reports turns out to
depend on the construct — a pipeline reports where it starts, a command substitution and
a bare simple command report where they close — and **two attempts to state that rule in
advance were both wrong.**

The exclusion file now says so rather than claiming a rule. The useful property is not
that the derivation was right; it is that a wrong range cannot survive one run.

### And one change made and backed out, again

The instinct to fix the denominator by heuristic came back, and was refused for the same
reason as in session 3: it moved the numerator by six lines that could not be accounted
for. The explicit, reviewed, self-checked list is slower to write and is the one that can
carry a hard floor.

### Session 4 close

| | at the question | now |
|---|---|---|
| Shell coverage | 71.0% of 5217 | **84.0%** of 4520 |
| awk statements | *not measured* | **88.2%** (1353/1534) |
| Invariants | 334 | **370** |
| CI floors | 65% shell | **80% shell + 85% awk** |

`bt-status`, `bt-postmortem` and the `bt-actions` classifier are at **zero uncovered
lines** — the first files to clear a hard cut.

**The thing worth remembering.** Two coverage tools now measure this repository and they
disagreed about the most important file in it. One said `bt-actions` was the worst-covered
file in the tree; it was 85% covered. The other said the classifier inside it was at 39%,
and the missing branches were the ones that see the controller leave the bus. One number
was wrong and comfortable, the other right and alarming — and a single percentage over a
codebase written in two languages cannot be anything else.

### Session 4, continued — driving the tail with the new report

With `--uncovered` naming lines instead of ranking files, the work changed character
entirely: pick a file, read its list, write the fixture. Three files reached **zero
uncovered lines** — `bt-status`, `bt-postmortem`, `bt-health-report.sh` — plus the
`bt-actions` classifier at 172/172.

Every one of the gaps was a **verdict branch**. These are tools whose entire product is
one sentence a person reads before deciding whether to power the machine off, keep
testing, or stop trusting the run, and between them fourteen of those sentences had never
been executed.

**The two that would have been worst to get wrong**, both now pinned in *both*
directions:

- `bt-postmortem` has a branch for "the early signal arrived AFTER the first timeout, so
  BT_EARLY could not have helped in this incident". The "cmd_timeout is too late"
  hypothesis rests on a warning arriving *before* the first timeout, and this tool is what
  says whether one did. **It had only ever exercised the confirming reading.**
- `bt-status` refuses to credit a failure-free boot where no audio was exercised — "a
  clean boot proves nothing if the trigger was never attempted". Both fixtures are
  failure-free; only the verdicts differ.

**Two more findings, both the same shape as session 3's:** `bt-health-report`'s live-state
check read `/sys/class/bluetooth` and `/sys/bus/usb/devices` directly while `SYSFS_USB`
was already defined at the top of the same file — a seam added and one block missed, in
the check that outranks every counter above it. And `bt-status`'s capture-health section
had `/var/log/bt-health/trace` hardcoded, so "is the capture running?" — half of what an
operator opens the tool for — could not be tested at all.

**A correction to one of my own assertions.** "bt-status counts this boot's timeouts from
the fixture" tested that `2` appeared *anywhere* in the output, which any timestamp or
version string satisfies. It could not have failed had the count come from the host. That
is the fifth check of mine this effort has found unable to fail for the reason its name
gave.

**Two properties of the exclusion format learned by getting them wrong:**

- Testing a *copy* of a script does not register as coverage. The trace records the copy
  under an absolute temp path and `devtools/coverage` counts only repository-relative
  paths — deliberately, so a tool's installed image is never confused with its source.
  The installed-layout test is still worth having; it just cannot close the line.
- A single line must be written as a one-line **range**. `path:61` parses as `61-0` and
  matches nothing — a quiet no-op, which is the one failure an exclusion file must not
  have, because it looks exactly like an exclusion that worked.

### Where session 4 ends

| | at the question | now |
|---|---|---|
| Shell coverage | 71.0% of 5217 | **84.7%** of 4550 |
| awk statements | *not measured* | **88.2%** (1353/1534) |
| Invariants | 334 | **378** |
| Files at zero uncovered | — | `bt-status`, `bt-postmortem`, `bt-health-report.sh` |
| CI floors | 65% shell | **80% shell + 85% awk** |

From the effort's opening baseline: **13.1% → 84.7%**, **65 → 378 invariants**.

Open, in the order the report recommends: fold the CI-gated round trip into the
measurement (206 lines, and the code is already tested); work the remaining long tail with
`--uncovered`; extract the remaining inline awk to `tools/lib/` so exclusion ranges become
library files with fixture cases; then raise both floors to 100%.

### Upstream drift, merged · `11c4042`

`origin/main` advanced two commits (`d8b7abe..7a09765`) resolving six external review
findings, all about **over-interpretation**. It touched 28 files, nine of which this
branch had converted to seams.

**Merged, not rebased.** 51 commits replayed against semantic changes to the same files
is 51 chances to mis-resolve; a merge is one resolution with both sides in view. Five
conflict hunks across four files.

#### The finding that matters: two of my tests encoded the defect main removed

Main rewrote `bt-diagnose` to report a **phenotype rather than a cause** — kernel
timeout/reset/firmware lines are aggregate, unpaired and not VID:PID-scoped across boots,
so they cannot say which timeout a reset answered or whether a callback is installed for
the controller in front of you.

Two assertions written in this branch last session required the opposite:

```
"bt-diagnose clears a controller the kernel does reset"          (expected exit 0)
"bt-diagnose notes the absent firmware load (driver_info = 0)"
```

**Had upstream landed after them, they would have reported a correctness fix as a
regression.** That is a failure mode this log has not recorded before, and it arrives from
the direction nobody watches: not an untested defect, but a *tested* one. A test is a
claim about what the code should do, and writing one does not make the claim true — it
makes it durable, which is worse when the claim is wrong.

They are replaced by their negation, which is the property actually worth holding: reset
messages must **not** suppress the phenotype, and the report must draw no mechanism
conclusion from counts that cannot support one. Both are now asserted positively.

#### Everything else was the same correction in wording

Each assertion was re-anchored to what it is about rather than deleted:

| was | now |
|---|---|
| stage 1 / stage 2 | HCI non-response / USB loss |
| "EARLY RECOVERY WORKS" | "CONTROLLER ANSWERED AFTER EARLY INTERVENTION" — the intervention censors the counterfactual |
| "VERDICT: WORKING" | a count of *confirmed* post-timeout recoveries; legacy markers reported as mixed-context |
| "lower BT_THRESHOLD" after a failed intervention | removed — reset may itself alter the trajectory, so "intervene sooner" does not follow |

The five `stage2` golden files were regenerated **after** confirming every duration is
identical across the change. The numbers did not move; only the language and the new
provenance categories.

#### Two resolutions worth naming

`bt-phase` conflicted because main edited the **inline awk this branch had already
extracted** to `tools/lib/phase.awk` (UT-11). Main's null-hypothesis change — constant
hazard, not mere probe independence — is ported into the library, and main's new check is
widened to scan the library too: it greps `tools/bt-phase` for wording that no longer
lives there, and would otherwise have been a check that cannot fail for the reason its
name gives.

`bt-health-report`'s merge would have silently reverted `bt_journal` to `journalctl` on
one line, because main edited the pre-seam copy.

#### The self-check earned itself twice more

It caught the `bt-actions` exclusion ranges going stale as main's edits shifted line
numbers — and it caught `tests/run-tests` appearing three times in the coverable table,
which turned out to be **unmerged index stages**, not duplicated content. A merge is
exactly when a line-number-based exclusion list rots, and this is the run where that would
have gone unnoticed.

| | before the merge | after |
|---|---|---|
| Invariants | 378 | **388** |
| Shell coverage | 84.7% of 4550 | **84.9%** of 4618 |
| awk statements | 88.2% | **88.2%** (1386/1572) |

All gates pass: `repo-validate`, `repo-scan --all`, both coverage floors, `verify.sh`.

### Second upstream check · `c9959ea` merge, `67ae475` tests

`origin/main` advanced one commit (`7a09765..65d0241`) adding `devtools/status`, a new
110-line file. **Merged clean — no conflicts.** It answers "is everything updated,
rebuilt, logged, collected, committed, pushed?" and exists to keep one distinction
visible: **committed is not deployed.**

It arrived at 0% and took the total 84.9% → 84.0%. That is the ordinary cost of upstream
adding code to a branch whose job is measuring it, and the right response is to test the
file rather than to widen anything.

The tool states its own contract in its header — *deployment drift is reported but does
not set the exit status, because it is a fact about the machine and not a defect in the
commit* — and that is precisely what could not be checked against the real host: it needs
an installation that has drifted, and manufacturing one on the investigation machine is
the opposite of a read-only check. One seam (`BT_STATUS_REPO`), then a scratch repository
with a **real local remote** and stubbed tools inside it. The pushed-ness question is
asked of the remote via `ls-remote`, and a `file://` remote answers it offline, so no
network round trip enters the suite.

Seven invariants, one per state the tool distinguishes. Two are worth naming:

- **The unreachable remote.** Main's commit message calls the stale tracking ref the
  source of a false all-clear. In the fixture that ref still exists and still points at
  the old head — exactly that stale state — and the assertion requires the tool to say it
  could not confirm, while forbidding it to report a hash comparison it did not make.
- **The no-drift case**, asserted because the drift row is only meaningful if the tool is
  capable of *not* printing it.

`devtools/status` is now at zero uncovered lines.

| | before | after |
|---|---|---|
| Invariants | 388 | **396** |
| Shell coverage | 84.9% of 4618 | **85.1%** of 4701 |
| awk statements | 88.2% | **88.2%** |

Four files now stand at zero uncovered lines: `bt-status`, `bt-postmortem`,
`bt-health-report.sh`, `devtools/status` — plus the `bt-actions` classifier at 172/172.
