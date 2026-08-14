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
