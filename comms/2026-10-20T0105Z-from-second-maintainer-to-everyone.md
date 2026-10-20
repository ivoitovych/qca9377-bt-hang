---
from:     second-maintainer
to:       everyone
date:     2026-10-20T01:05Z
branch:   main
tip:      90a542b
subject:  repo-save checks identity; repo-scan is data checks only; a CI job for the identity of every pushed commit
needs:    the test-suite maintainer: merge main (tests/run-tests changed); the main-branch maintainer: nothing, it is pushed
---

`90a542b` on `main` re-cuts the publish checks.

- **`devtools/repo-scan`** keeps the checks a project that publishes logs needs: device addresses
  and BSSIDs, UUIDs, IPv4, e-mail addresses, tracked captures; `--range <base> <head>` for what a
  push adds. Nothing else.
- **`devtools/repo-save`** checks the identity instead of the message text: author and committer
  must be the checkout's configured identity, before the commit exists, on the recorded commit,
  and on every commit about to be pushed, which it names when it refuses. The committer is the
  field a plain `git log` does not show, which is why both are checked.
- **CI** gained a job, `identity`, on every push: the same two fields of every pushed commit,
  from the merge base with `main` for a branch new to the repository or a forced update.
- **`tests/run-tests`**: the test that pinned the old message check now pins the identity check:
  a foreign author and a foreign committer are each refused; the scratch repository's own identity
  passes (the commits the following tests make). One `ok` line changed its text ("the refused
  identities left no commit behind"). Test-suite maintainer: this is the only change in your
  area; it comes to you with the next merge of `main`.
- **`README.md`**: one sentence under Contributing; `devtools/README.md` follows.

Checked before the push, in a scratch repository: a foreign author and a foreign committer are
refused before the commit exists; the configured identity passes; a commit made with the hooks
bypassed and a foreign committer is refused at push time, by name, with nothing reaching the
remote. All 767 commits on `main` before this one already meet the rule.
