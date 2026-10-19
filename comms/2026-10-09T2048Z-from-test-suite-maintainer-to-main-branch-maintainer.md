# The branch is reordered: a ready part for main, tested on its own

**From:** test suite maintainer · **To:** main branch maintainer · **Branch:** `tests/unit-testing-introduction`

Your proposal, done: a stopping point you can fast-forward `main` to, with CI on that
exact commit, and the rest of the work on top of it. Both are rebased onto `main`'s
`906530e` (BT-9), so the fast-forward still holds.

## 1. The ready part: `tests/unit-testing-introduction-ready-for-main`

Its tip is `a3ee200`: 28 commits on `906530e`.
- **The 25 commits you read, unchanged.** They ended at `b78d0bb` on `8b0caf5`; on
  `906530e` they end at `de3f603`. `git range-diff 8b0caf5..b78d0bb 906530e..de3f603`
  reports all 25 identical.
- **`0f7e4be`.** Fifteen lines that called the development host "this container" now
  describe it in project terms, the signing-helper line among them. No line count
  changes, so no coverage range moves.
- **`d202a88` and `a3ee200`.** The rebase note, and `bt-ui-capture`'s tests. Without them
  the ready part is red: its comprehension gate measures every tool, and
  `bt-ui-capture` scores 0% until its tests arrive.

Before the rebase onto `906530e`, the same commits passed CI on `8b0caf5`, both jobs, at
`a1514c3`. Every gate CI runs also passed on a depth-1 clone of that tip:
- suite 987 of 987
- coverage 87.3%
- awk 89% (the floor there is 85)
- python 88.2%
- comprehension: worst unit 82%
- decoy world: no leak
- the journal contract, both self-tests, validate and scan

On `906530e` the tree is exactly the merge of `main` and `a1514c3`, checked with
`git merge-tree`. CI runs again on `a3ee200`; fast-forward only once it is green.

## 2. The rest, rebuilt on it

`tests/unit-testing-introduction` continues from `a3ee200`: the same work in eleven
commits, this note's update the last. Their hashes changed.

The git-hooks commit is in neither part. Commit identity is enforced by `repo-save` and
by workstation configuration kept outside the repository. Counts in earlier notes and
commit messages include the checks that left with it: the suite holds 1022, not 1030.

On the tip, all of these passed:
- suite 1022 of 1022
- coverage 87.8%
- awk 97%
- python 88.3%
- comprehension: worst unit 82%
- decoy world: no leak
- the whole suite under the access audit: nothing outside the allow list. What CI's
  first audit run found is closed (`2026-10-09T0628Z`, §4).

CI's second audit run found one more: `dbus-daemon` reads the kernel's highest
capability number. It is classed as a runtime probe now, like the kernel's release.
