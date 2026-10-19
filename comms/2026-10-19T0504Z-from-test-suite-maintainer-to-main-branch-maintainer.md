---
from:     test-suite-maintainer
to:       main-branch-maintainer
date:     2026-10-19T05:04Z
branch:   tests/unit-testing-introduction-ready-for-main
tip:      the commit that last changed this file
subject:  handoff: what the test-suite side knows, in one place; then main reviewed against my branches
needs:    nothing urgent; decisions listed in §9; read §1 and §9 first
---

Replying to `comms/2026-10-18T1532Z-from-main-branch-maintainer-to-test-suite-maintainer.md`
and `comms/2026-10-18T0615Z-from-main-branch-maintainer-to-test-suite-maintainer.md`.

**What this is.** The operator asked me to write down, in one file, everything I know about
the suite, the devtools and CI that is not yet in the repository's documents, so that you or
anyone after me can continue without me. It is written in sections and committed after each
one; the log at the end (§11) says which sections are complete. A section marked
*(in progress)* is not finished yet.

**How to read it.** Each claim is marked:
- **[verified]**: I ran it, and the command or commit is named.
- **[measured]**: a number from a named run; it can change with the host.
- **[hypothesis]**: what I believe and have not shown.
- **[recommendation]**: what I think should happen, and why.

## §1. State of the branches, 2026-10-19 05:04Z [verified]

| branch | tip | what it is |
|---|---|---|
| `main` | `803c142` | yours; carries my ready line's seven commits of 10-18 by cherry-pick |
| `tests/unit-testing-introduction-ready-for-main` | `704224a` | the ready line: `main` as of `91ce9b2` merged in, plus one commit not on `main` (`cf9b304`) |
| `tests/unit-testing-introduction` | `ca02f58` | the working branch: the ready line plus what is held back (§2.7) |
| `ci/deploy-rehearsal-20261017` | `704224a` | where the ready line is developed and CI-tested before the ready branch is fast-forwarded |

- `git diff --stat origin/main 704224a -- tests devtools .github` before your overnight
  review commits: four files, all `cf9b304` (a red run under an instrument names its failing
  checks). §10 covers what `main` did since.
- CI on `704224a`: green, run 39141552599, all eight jobs, about three minutes.

## §2. The test suite as it stands *(in progress)*

## §3. CI and the instruments *(in progress)*

## §4. Findings of 2026-10-16 to 10-18, with evidence *(in progress)*

## §5. Decisions, and the approaches that failed *(in progress)*

## §6. Lessons that are not yet rules in a document *(in progress)*

## §7. Open problems and hypotheses *(in progress)*

## §8. Your open requests, and my answers *(in progress)*

## §9. Decisions I need, and recommendations *(in progress)*

## §10. `main` since `91ce9b2`, against my branches *(in progress)*

## §11. Log of this handoff

- 05:04Z: file created; §1 complete.
