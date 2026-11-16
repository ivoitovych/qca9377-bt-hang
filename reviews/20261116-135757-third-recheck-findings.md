> **Findings-only copy, made 2026-11-16.** This page keeps the findings, ids, severities,
> `file:line` references, verdicts and tables of the reviewer's page of the same name; it is not
> the original. Sections that describe how the review was organised are left out, and a line that
> quoted or described the working arrangement (the review's "P-01 class") is replaced by one
> marker line. The original pages are on the reviewer's branch: the review at commit `162d3b9`,
> the first recheck at `3f8e8f6`, the second at `50bd289` and the third at `17f8ac6` (which also
> carries the final wording of the second). Line numbers in the text are those of the tree the
> reviewer read, not of this copy.

# The project review: the maintainer's commit `d331c8e9` verified

- **Written:** 2026-11-16T13:57Z (UTC). It follows
  [`review-second-recheck-of-comprehensive-project-review-20261116-132247.md`](review-second-recheck-of-comprehensive-project-review-20261116-132247.md);
  ids A-01 to A-03, B-01 to B-10 and the item numbers of "What is left" are from that page.
- **Verified:** `main` at `d331c8e9` (2026-11-16 14:39 +0100), one commit after `bbec102f`,
  11 files: "Public text keeps findings, not how the work is done". Read by the lead reviewer
  alone; nothing was run.

## 1. Result

The commit answers section 3.1 of the previous page (the working arrangement in the text) and
nothing else. What it claims is true on the files. It is a forward measure, by the author's
decision recorded in `devtools/repo-scan` ("older text is a separate decision (operator,
2026-11-16)"), so the older text stays, and the removed text stays in the history.

| item | verdict | detail |
|---|---|---|
| A-01, the two stored messages | **fixed at the tip; still in history** | `reviews/2026-11-16T0000Z-project-review-recheck-reaction-verbatim.md` is deleted and replaced by `…-reaction-findings.md`; the 11-15 file is renamed `…-reaction-findings.md` and its closing offer left out. Neither new file has the lines named in A-01 (`git grep` for the four phrases on the tip: no hit in `reviews/`). The old files are in the commits `d6a8053a` to `bbec102f` of `main` and can be read from any clone with `git show`; removing them from there is a history rewrite, which the commit did not do |
| A-02, the builder's word list | **fixed** | `contributions/CO-46-…/build-review-package.py` no longer names products or the work area; it reads a private list (`../private-config/publish-wording.txt` beside the checkout, or `BT_PRIVATE_WORDING`) and exits 2, "NOT CHECKED", when the list cannot be read |
| the refusal pattern on the save path (item 2) | **done, with three limits** | `devtools/repo-scan` refuses added lines that match the private list, at save time and at push. See 2.1 |
| A-03, `HISTORY.md` | **partly** | the chapters of 11-13 to 11-16 are reworded (ten lines), and one bullet inside a moved block, marked as the only edit there. See 2.2 for what remains |
| the home path in the new session notes | **partly** | two of three places changed to `~`; `evidence/sessions/20261116-002107-shure-paired-in-handsfree-no-codec-row/NOTES.md:46-48` still has `/home/i/…` and the owner columns `i i` |
| the elapsed-time line in the CO-46 reviewer file | **fixed** | removed, and the file's head says so |
| `reviews/README.md` | **confirmed** | the renamed files are indexed |

## 2. What is left of section 3.1

### 2.1 The new scan check

- It applies to staged additions and to pushed lines only, "never to `--all`". CI runs
  `devtools/repo-scan . --all` (`.github/workflows/checks.yml:168`), so CI does not run it, by
  design, and has no list anyway.
- Where the list is absent the check prints "private wording list not on this machine — that
  check was not run" and passes; under `--quiet` it prints nothing. The comment above it says
  it "does not pass silently". The protection therefore exists on the one machine that has the
  private file; a second maintainer's clone, or a fresh clone, saves and pushes unchecked.
- No test came with it (`git diff --stat bbec102f d331c8e9 -- tests` is empty). The project's
  own rule is that a new check is first seen to fail (`BRIEF.md` §8a); the suite's seam
  `BT_PRIVATE_WORDING` would allow a scratch list with one harmless word.
- `contributions/review-2026-11-02/build/build.py:27-30` and `followups-build.py:13` still carry
  the older public word list (P-03 of the review).

### 2.2 Text that is still on the tip (older text; the author's separate decision)

- [wording of the P-01 class omitted]
- [wording of the P-01 class omitted]
- The four places with a product name or a tool's own path: `contributions/CO-25-qualcomm-rom-report/log.md:273`,
  `scripts/user-audio-streams.sh:11`, `docs/STATUS.md:122`,
  `reviews/2026-10-28T0300Z-documentation-alignment.md:33`.
- `comms/2026-11-15T2010Z-from-test-suite-maintainer-relayed-by-operator.md` (N-01): unchanged;
  about fifty first-person lines of running commentary.
- The work-area path: 2,713 files (2,716 at the review). `/home/i/`: 36 lines under `docs/` and
  `results/`.

### 2.3 This branch

The pages of this review name and quote the same wording in order to point at it, and the
branch is public under a name the environment gave it. The previous page quoted two lines of
the stored message; they are taken out with this commit, and remain in the branch's two earlier
commits. When the maintainer has taken what is needed from these pages, deleting the branch
removes all of it from the public repository; the author decides when.

## 3. Everything else

Not touched by `d331c8e9`: items 4 to 24 of "What is left" on the previous page stand as
written there (the outside-review document's checksum, the CO-35, CO-02, CO-43, CO-38, CO-11,
CO-23 and CO-46 package items, `tools/verify-restored.sh:128`, the other code items, the
document lines, the tests, and the three things to confirm on a machine or a full clone).
