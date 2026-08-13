# How to improve test coverage — a re-prioritisation

**Written:** 2026-08-13T12:44Z
**Covers:** the tree at `10404b2`
**Supersedes:** the Stage 3 priority in
[`2026-08-13T1214Z-unit-testing-assessment.md`](2026-08-13T1214Z-unit-testing-assessment.md) §5
**Status of items below:** [`reviews/README.md`](README.md), IDs `CS-nn`

> The earlier assessment said the journal seam was "the unlock" and projected
> 13% → ~29% from converting journal-reading tools. **That priority was wrong.**
> Not incorrect about the seam's value — incorrect about it being first. The
> largest bucket of untested code needs no seam, no refactor, and no new
> abstraction at all. This report measures the difference and re-orders the work.

---

## 1. The mistake in the earlier plan

The earlier report classified untested files by one axis: do they call `journalctl`?
That put the seam at the centre of the plan. Classifying by **what it would actually take
to run each file under test** gives a different answer:

| Category | Lines | Files | What it needs |
|---|---:|---:|---|
| **A — nothing** | **1219** | 15 | already has a dry-run mode, an env override, or is a pure transform |
| B — the journal seam | 460 | 8 | `bt_journal`, then a fixture |
| C — journal + device seams | 1031 | 11 | also sysfs / systemctl / hciconfig stubs |
| D — genuinely hardware-bound | 305 | 5 | only refusal and argument paths are reachable |

**Category A is 31% of the shipped shell and needs no production change.** It is bigger
than the journal-seam bucket by a factor of 2.6, and it was invisible in the earlier
analysis because "calls journalctl" is not the same question as "can this be tested".

Three examples of what was hiding there:

- **`install.sh` (255 lines) and `uninstall.sh` (144)** — the two largest untested files
  in the repository — **already default to a dry run**. `run()` echoes `would run: …` and
  executes nothing; the root check sits inside the `APPLY` branch. Both complete in under
  10 ms as an ordinary user and write nothing. 399 lines, one invocation each.
  *Caveat:* on a machine whose journal contains an HCI timeout, the dry run sleeps 10 s
  twice by design. A test must control the journal — which is an argument for converting
  `install.sh` to the seam, but for determinism, not reachability.
- **The devtools (365 lines)** — `repo-scan`, `repo-validate`, `repo-save`, `coverage`,
  `check` — are read-only and take a target directory as an argument. They can be run
  against a scratch git repository today.
- **`tools/sanitize-logs.sh` (89 lines)** — a pure file-to-file text transform, the most
  unit-testable shape there is.

## 2. What trying to test one file found

`sanitize-logs.sh` was picked first — not because it is the most lines, but because it is
the highest consequence per line. It is what stops a Wi-Fi BSSID reaching a public
repository, and a BSSID is indexed by public geolocation databases, so a miss discloses
where the machine physically is. The repository already has one instance on record: 20
unsanitised addresses reached a public commit on 2026-08-12.

It had **zero** coverage. Writing the first test found three things.

### 2.1 The tool does not run on the default awk of most Linux distributions

Ubuntu and Debian ship **mawk** as `awk`. On mawk 1.3.4 the tool aborts:

```
REcompile() - panic:  values still on machine stack for [0-9a-fA-F]{2}([:_-][0-9a-fA-F]{2}){5,}
FAIL: this awk does not support ERE interval expressions correctly.
      Install gawk (or mawk >= 1.3.4) and retry.
```

The advice was wrong: this **is** mawk 1.3.4. Anyone following it would install what they
already had. The gate failed closed, which is the right direction, but the tool was
unusable on the commonest Linux awk and its own diagnosis pointed the wrong way.

### 2.2 The capability gate tested one pattern and licensed the other two

It probed the MAC pattern only. On mawk the IPv4 pattern `([0-9]{1,3}\.){3}[0-9]{1,3}`
matches **7 of the 12 characters** of a dotted quad — so an address would be *partially*
replaced, and the final `grep -E` verification cannot see a fragment that is no longer a
whole address.

This is the failure the file's own header block warns about, in the same file, about a
different layer: *"verification only tested the forms the substituter already knew — the
identical failure this comment block was originally written to warn about."* It was live
in the engine check.

### 2.3 A positive-only probe is answered correctly by accident

The important one, and the reason the first fix attempt was wrong.

mawk treats an interval applied to a **group** as `+`. So `(X){5,}` still matches a full
MAC greedily, at exactly the right length — the probe passes — while `11:22`, two hex
pairs and not an address, **also matches** and would be replaced with a fake address.
Redaction breaks in both directions at once, and neither is visible in the output.

The first attempt expanded the inner intervals (`X{2}` → `XX`), which stops the panic.
The tool then *appeared* to work on mawk — and was quietly over-matching. That change was
reverted. **An engine that cannot express the patterns must be refused, not accommodated.**

The gate now probes each pattern **both ways**: a string that must match at an exact
length, and a string that must not match at all. The negative probes are what catch a
degraded engine.

## 3. Changes made

| | |
|---|---|
| `tools/sanitize-logs.sh` | gate rewritten: all three patterns, positive **and** negative probes; accurate diagnosis naming gawk |
| `tests/run-tests` | 8 new invariants — redaction of all four address forms, preservation of `127.0.0.1`/`0.0.0.0`, placeholder determinism, short-hex-run safety, plus refusal paths |
| `.github/workflows/checks.yml` | installs gawk, so the redaction assertions run in CI instead of skipping every time |

Coverage: `sanitize-logs.sh` 0.0% → **39.3%**; total **18.3% → 19.5%**.

The 39.3% is honest rather than disappointing: on an incapable awk the transform body is
unreachable by construction, so the untested remainder is the redaction passes themselves,
which CI now covers on gawk. The suite reports 108 invariants on gawk and 100 on mawk, and
**says which path it took** — the skip is printed, never silent.

### The fixture is built from the placeholder space

A fixture for a redaction tool has to look like the data it redacts, and the first draft
used realistic addresses — which `devtools/repo-scan` then refused to publish, correctly.
Rather than widen the gate to admit the test, the fixture uses only prefixes `repo-scan`
already allows: `11:11:11`, `de:ad:be`, `00:11:22`, the nil UUID, the broadcast address.
Realistic in form, publishable, and no exemption added.

## 4. The re-ordered plan

Each item has an ID and a verify command; status lives in [`README.md`](README.md).

### Do first — no production change (category A, 1219 lines)

| ID | Item | Lines | Why it is cheap |
|---|---|---:|---|
| CS-01 | `sanitize-logs.sh` | 89 | **done** — pure transform, highest consequence |
| CS-02 | `install.sh` + `uninstall.sh` dry run | 399 | already non-destructive and non-root; one invocation each |
| CS-03 | devtools against a scratch repo | 365 | read-only, already take a directory argument |
| CS-04 | `bt-capdiff`, `bt-sco`, `bt-context`, `bt-incident` | 315 | already have `BT_*` directory overrides |

### Then — the journal seam (category B, 460 lines)

| ID | Item | Lines |
|---|---|---:|
| CS-05 | `bt-actions` | 167 |
| CS-06 | `bt-logvolume`, `bt-boot-stats`, `bt-timeline.sh` | 153 |
| CS-07 | `bt-env-history`, `bt-boot-list`, `bt-boots` | 93 |

`bt-actions` is the single best seam target: 167 lines, journal-only, no device access.

### Then — device seams (category C, 1031 lines)

CS-08. Needs a second seam for sysfs and one for `hciconfig`/`systemctl`, on the model of
`journal.sh`. `bin/bt-hang-watchdog` (183 lines, still 0%, still deciding whether to
intervene on a live controller) is the reason to do it and the hardest case.

### Probably never — category D (305 lines)

CS-09. `bt-mode`, `bt-trace`, `bt-usbmon`, `bt-verify-install`, `bt-mark` bind to real
hardware and root. Their argument parsing and refusal paths are worth testing; the rest is
not worth the stubs it would take. Say so rather than leaving them looking neglected.

### Realistic ceiling

A + B fully covered at the ~60% a fixture-driven characterisation test typically reaches
puts the total near **45%**, without touching category C. That is a better target than the
earlier report's ~29%, and it arrives sooner because most of it needs no refactor.

## 5. What this says about the method

The earlier report's priority was wrong because it classified files by a property of their
source (`grep -c journalctl`) rather than by the question actually being asked (what would
it take to run this under test). The correction cost one measurement.

The `sanitize-logs.sh` findings came from *attempting* to test, not from reading — the
tool had been read closely enough to carry three paragraphs of accurate commentary about
this exact class of bug, and the bug was in the check those paragraphs describe. That is
the argument for coverage stated as plainly as this repository can state it: the code was
understood, documented, and wrong, and only running it said so.
