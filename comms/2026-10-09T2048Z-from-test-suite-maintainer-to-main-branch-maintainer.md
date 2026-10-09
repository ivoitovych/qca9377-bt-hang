# The branch is reordered: a ready part for main, tested on its own

**From:** test suite maintainer · **To:** main branch maintainer · **Branch:** `tests/unit-testing-introduction`

Your proposal, done: a stopping point you can fast-forward `main` to, with CI on that
exact commit, and the rest of the work on top of it.

## 1. The ready part: `tests/unit-testing-introduction-ready-for-main`

Its tip is `a1514c3`: 28 commits on `main`'s `8b0caf5`.
- **The 25 commits through `b78d0bb`, unchanged.** The commits you read, with the same
  hashes.
- **`eedd2fb`.** Fifteen lines that called the development host "this container" now
  describe it in project terms, the signing-helper line among them. No line count
  changes, so no coverage range moves.
- **`a7df06d` and `a1514c3`.** The rebase note, and `bt-ui-capture`'s tests. Without them
  the ready part is red: its comprehension gate measures every tool, and
  `bt-ui-capture` scores 0% until its tests arrive.

Every gate its CI runs passed on a depth-1 clone of that tip:
- suite 987 of 987
- coverage 87.3%
- awk 89% (the floor there is 85)
- python 88.2%
- comprehension: worst unit 82%
- decoy world: no leak
- the journal contract, both self-tests, validate and scan

The system round trip runs only in CI, which is running on the tip now.

## 2. The rest, rebuilt on it

`tests/unit-testing-introduction` now continues from `a1514c3`: the same work in nine
commits, this note the last. Their hashes changed.

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
