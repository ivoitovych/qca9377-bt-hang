> **Findings-only copy, made 2026-11-22.** This page keeps the findings, `file:line` references,
> counts and verdicts of the reviewer's fifth recheck page (written 2026-11-22T02:57Z). It is not
> the original: the lines on how the recheck was carried out are left out. Line numbers are those of
> `main` at `e420203b`. What was done with each item:
> `2026-11-22T0400Z-project-review-fourth-and-fifth-recheck-checks.md`.

# The project review: `main` verified at `e420203b`

`main` at `e420203b` (2026-11-16 17:55 +0100) is 9 commits after `ea994867`, touching 90 files.
Four of the commits are about the wording of older text and about this review's pages; five are
CO-46 and `HISTORY.md`. Code and tests changed by one line. The CO-46 texts of this round were not
reviewed.

## 1. Result

**The decision on older text was taken, and carried out in the authored documents.** Counted on
the tip with the same commands as before:

| | at the review (`da23558`) | at `ea994867` | at `e420203b` |
|---|---|---|---|
| lines of that kind in `HISTORY.md` | — | 15 | 0 (3 matches left are a user-agent block and an upstream project's policy) |
| in `BRIEF.md` | several | 3 | 0 |
| in `docs/STATUS.md` | several | 9 | 0 |
| in `contributions/rd-2026-11-14.md` | 22 | 30 | 0 |
| files with a product name or a tool's own path | 4 | 4 | 2 |
| the work-area path, files / lines | 2,716 / 11,068 | 2,712 / 11,057 | 2,658 / 10,876 |
| tracked path with a work-track number in its name | 1 directory | 1 | 0 (renamed `instrumentation-20261114`) |
| a local home path under `evidence/` | 0, then 3 lines | 0 | 0 |

- `docs/STATUS.md` (U21) and `scripts/user-audio-streams.sh` no longer name the browser tab; the
  11-02 and CO-46 package builders carry no public word list; the moved blocks of `HISTORY.md`
  say what was edited in them.
- **This review's pages are now on `main` as findings-only copies** (seven files, listed in
  `reviews/README.md`). Each says at its top that it is not the original, that the sections on how
  the review was organised are left out, and that a line which quoted that kind of wording is
  replaced by a marker. None of the seven contains the work-area path. Findings, ids, severities,
  file references and tables are kept.

## 2. What is left

**Of the wording (the author's decision):**
- The work-area path remains in 2,658 files. About 2,200 are run and build logs under
  `contributions/` and `results/`. 432 are authored files (`.md`, `.sh`, `.py`), nearly all inside
  dossiers and result directories (scripts with the path as a variable, check notes); outside
  those two trees it is in one evidence note and a few review files of 11-13.
- `contributions/CO-25-qualcomm-rom-report/log.md:273` (two settings-file paths of a tool) and
  `reviews/2026-10-28T0300Z-documentation-alignment.md:33` (the row that quotes what it removed).
- A local home path in 36 lines under `docs/` and `results/`.
- The history of `main`: the two removed message files are still readable from earlier commits.

**The fourth page's short list** (`20261116-142253-fourth-recheck-findings.md`), all Low, unchanged
at `e420203b`:
- `contributions/CO-23-one-off-events/patch/send/send.sh`, a working send script in a superseded
  directory;
- `BRIEF.md:254` (the D1/D2 gloss), `:839` (a hash cut in the middle), the lessons pointer of §8a,
  a hand-off block still dated 11-14;
- `docs/issues.md:1552` ("that test is next" before the note that answers it);
- `docs/sent-mails.tsv` row 7 and the three hashes of address-elided copies;
- `tools/bt-ui-capture:166`: the ownership check covers the script, its directory and the
  checkout, not the other files root's units run from the checkout;
- `devtools/repo-scan:295`: the comment says the wording check "does not pass silently"; with
  `--quiet` and no list it prints nothing;
- CO-46's measurement data is on another branch (its README says so).

**To confirm on a machine or a full clone:** `git merge-base --is-ancestor 8b71499 main` (and
`a56141e`); `scripts/sco-ledger.sh` on a boot of the laptop without a call.

## 3. The reviewer's branch

`main` now holds what it needs from the review, the three rechecks and their detailed files.
Only the fourth page and this one were not there; their content is section 2 above. Once that
list is taken, nothing on the reviewer's branch is needed any more. Deleting the branch removes
the original pages, which quote the wording they point at, from the public repository.
