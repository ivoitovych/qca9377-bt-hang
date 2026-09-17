# Fixes for the front-door review 2026-09-17T2251Z — every finding dispositioned

**Covers:** the tree at `0f25bea` (`origin/main`), the base of `review/2026-09-17T2251Z`;
the fixes land on `review/2026-09-17T2251Z-fixes`, which contains the review and the
fixes together, as `review/2026-08-15T1752Z-fixes` did for the first review.

**What this document is.** One entry per finding, `FD-01`..`FD-25`, every severity
including `[GOOD]`, with a disposition: **fixed** (changed on this branch, commit named),
**recorded** (a decision written down, nothing to change), **kept** (a `[GOOD]` practice
left as it is), **declined** (deliberately not done, with the reason). Gates run on the
finished branch are at the end.

**The shape of the fixes.** Nothing was deleted. Two sections of the old README moved
whole into `docs/install.md` and `docs/missing-quirks-entry.md` with a banner saying when
and why, their `REVIEWED-KEEP` markers intact; the README, the issue register, the patches
README and the bug report were rewritten or reordered from material that already existed
in `BRIEF.md`, `patches/bluez/README.md` and the exhibits. The suite's three gates on these
files (the canonical BT-1 paragraph in three documents, no retired reset assertions, no
bare project labels in outward-facing prose) all hold.

## Catalogue

| ID | Sev | File | Finding (short) | Disposition | Where |
|---|---|---|---|---|---|
| FD-01 | HIGH | README | 660 of 746 lines disowned; retired model in the present tense | **fixed** | `b07a4ef` — README rewritten to §7.1 (231 lines); Install/watchdog/`BT_EARLY` → `docs/install.md`; quirks-entry sections and the retired patch → `docs/missing-quirks-entry.md`, each with a dated banner |
| FD-02 | HIGH | README | no block for a maintainer arriving from a patch | **fixed** | `b07a4ef` — "For maintainers": subjects, runtime evidence (EX-041), verification, crash-site link, reproduction shape |
| FD-03 | HIGH | README | Status table contradicts BRIEF and itself | **fixed** | `b07a4ef` — the table is gone; Status is a dated copy of BRIEF §1 with an established / not-established split; no hand-kept third version |
| FD-04 | MED | README | reuse stated once, at line 647; no "different controller / different symptom" | **fixed** | `b07a4ef` — "Is this your problem?": the four failure modes, what transfers, what is part-specific |
| FD-05 | MED | README | no branch map, CI, register | **fixed** | `b07a4ef` — "Branches" paragraph under the repository map; CI and `devtools/ci`; `reviews/README.md` named as the live register |
| FD-06 | MED | README | retired numbers load-bearing (287/34, kernel table, lead-time table) | **fixed** | `b07a4ef` — the page carries only BRIEF §2 numbers; the historical figures live in `docs/install.md` and `docs/missing-quirks-entry.md` under their banners |
| FD-07 | LOW | README | `issues.md` labelled authoritative and stale in one page; Contributing asks for the retired model | **fixed** | `b07a4ef` — one label ("issue register"); Contributing asks for a ≤ v5.11 run, another alt-1 controller, a survived capture |
| FD-08 | GOOD | README | lines 1–60, layout tree, publishing-logs reason, tests block | **kept** | the three-stream table, the tree (extended), the sanitiser paragraph and the no-numbers comment are in the new page verbatim or near it |
| FD-09 | MED | BRIEF / README | README delegates to an internal document | **fixed** | `b07a4ef` — README carries its own dated copy of §1–§3/§6; BRIEF's header says it is internal and where the public summary is; `devtools/save` now warns when README's Status does not name the newest exhibit (same rule as BRIEF's) |
| FD-10 | LOW | BRIEF | four stale counts | **fixed** | `b07a4ef` — 43 exhibits, 7 deaths / 1 survival, 36 phases; the header trimmed to stay at 200 non-blank lines |
| FD-11 | GOOD | BRIEF | §1–§3, §5, §6 | **kept** | unchanged; copied, not moved |
| FD-12 | HIGH | patches | the mails carry no way back to the record | **fixed** | `b07a4ef`/`139deb5` — `patches/bluez/mail-notes/0001.txt`, `0002.txt` (≤ 72 cols); "The note below the `---` line" in the README with the `--annotate` step and the three never-s |
| FD-13 | MED | patches | quoted verification script not tracked | **fixed** | `b07a4ef` — `patches/bluez/git-am-check.sh` (worktree; each alone, both, either order; body-truncation check; no `Signed-off-by`; 50/72); README quotes the tracked path; row in `docs/tooling-index.md`. ⚠️ Written to reproduce the six PASS lines the README recorded; it has not been run against a BlueZ checkout from this container (no clone here) — run it once on the machine before the mails go |
| FD-14 | MED | patches | README in the project's order, not the reader's | **fixed** | `139deb5` — environment + runtime table first, then runtime evidence, verification, upstream status, prior art, how to send, conventions; the mechanism caveat and the two "an earlier revision said" passages under "Notes from the route" at the end. No sentence rewritten |
| FD-15 | LOW | patches | which build the firings come from | **fixed** | `139deb5` — the environment table's "runtime" row |
| FD-16 | GOOD | patches | both commit messages; conventions; two invocations | **kept** | patch files untouched |
| FD-17 | HIGH | bug report | argues for the fix its body argues against; no alt-1 | **fixed** | `139deb5` — rewritten around BRIEF §1–§3: signature table, `sysfs` reading, no software recovery, untreated windows, the reset-destroys-it result stated as the reason the quirks entry is not proposed |
| FD-18 | HIGH | bug report | two blocking banners, one on a retired hypothesis | **fixed** | `139deb5` — one gate: goes out only with a patch ready to follow (BRIEF §7) |
| FD-19 | MED | bug report | 7.6–16.2 s, "Regression: No", kernel list | **fixed** | `139deb5` — the seven measured intervals with their anchor; regression candidate v5.11→v5.12; the three signature kernels named, the earlier ones as "earlier phenotype" |
| FD-20 | MED | bug report | revision history in a document meant to leave | **fixed** | `139deb5` — no "earlier revision" passages except the one sentence in the header saying which draft this supersedes; the `REVIEWED-KEEP §1.5` marker kept with the Windows framing it guards |
| FD-21 | GOOD | bug report | Windows framing, caveat, two-headset table, EX-034 bullet, environment block, baseline command | **kept** | all in the rewrite except the baseline command (the 287/34 figures are pre-signature and no longer load-bearing; `evidence/baseline/baseline.tsv` still reproduces them and README does not quote them) |
| FD-22 | HIGH | issues.md | stops at EX-021; no alt-1, no crash entry | **fixed** | `139deb5` — "Current state — 2026-09-18" at the top with the entry-by-entry changes; BT-1 status line; BT-7 (the `bluetoothd` crashes, reportable, with runtime evidence). The existing BT-1 body is kept as the record of how the question was framed; the update says which parts have since been answered |
| FD-23 | MED | issues.md | BT-3 "may be the cause"; BT-5 open | **fixed** | `139deb5` — BT-3 status: consequence for recovery, patch not proposed; BT-5 superseded by EX-043 |
| FD-24 | MED | issues.md | the two user-facing passages buried | **fixed** | `b07a4ef` — "Why this class of bug goes unreported" summarised in README with a pointer; the Windows/Android reading folded into README's Environment paragraph |
| FD-25 | GOOD | issues.md | evidence model; A–D framing; the settling experiment | **kept** | unchanged; the update above says the experiment was run |

## Notes on two decisions

**`docs/issues.md` intro still says "at least six distinct problems".** Left as written:
the sentence is about why the register exists, the count is now seven, and the entry list
below it is the count. Changing prose that a future reader will check against the entries
is what R2-10-class findings are made of; the entries are the truth.

**`docs/missing-quirks-entry.md` keeps the retired one-line patch and its
`REVIEWED-KEEP` hedge.** The marker's reason ("the two claims that stop this section
overselling the patch") still applies wherever the section lives; a future edit that
removed the hedges would be caught by the same grep. The banner at the top says the patch
is not proposed.

## Gates, on the finished branch

| gate | result |
|---|---|
| `tests/run-tests` | **all 777 invariants hold** — including the three on these files: canonical BT-1 paragraph identical in README, bug report, fix proposal; no retired reset assertions; no bare project labels in README or the fix proposal; none at all in the bug report |
| `devtools/repo-validate . --no-suite` | all syntax checks passed (91 of 739 checkable) |
| `devtools/repo-scan . --all` | clean |
| `devtools/coverage --min 80` | see the line appended below after the run |
| README links | every relative link resolves |
| BRIEF budget | 200 non-blank lines |
