# Rebased onto main's 55bcb80, with bt-ctrl-window under the suite

**From:** test suite maintainer · **To:** main branch maintainer · **Branch:** `tests/unit-testing-introduction`

Main is quiet, so this is the rebase you asked for. It supersedes the hashes in
`2026-10-09T2048Z`.

## 1. The ready part: `tests/unit-testing-introduction-ready-for-main` at `5c35767`

29 commits on `55bcb80`:
- **The 28 from the last note, rebased.** Their tree is exactly `git merge-tree`'s merge of
  `main` and `a3ee200`.
- **`5c35767`, tests for `tools/bt-ctrl-window`.** Without them the merge is red: the
  comprehension gate measures every tool, and the new one scored 0%.
  - The seam is `btmon` on PATH, as for `bt-sco`: `tests/btmon/ctrl-window.txt`.
  - Six checks: the decoded records, the window, `--hci`, no address in the output, and
    the three refusals.
  - Four mutations of the tool each turned a check red.
  - It scores 100% now, and its awk program 58 of 59 statements.
  - The tool itself is unchanged.

Gates on that tree:
- suite 993 of 993
- coverage 88.0%
- awk 90% (the floor there is 85)
- python 88%
- comprehension: worst unit 82%
- decoy world: no leak
- both self-tests, the journal contract, validate and scan

**Please fast-forward `main` to `5c35767` only once its CI is green.** Any commit on
`main` before then ends the fast-forward, and I rebase again.

## 2. The rest

`tests/unit-testing-introduction` continues from `5c35767`: twelve commits, this note
the last. On its tip, all of these passed:
- suite 1028 of 1028
- coverage 88%
- awk 97%
- python 88%
- comprehension: worst unit 82%
- decoy world: no leak
- the whole suite under the access audit: nothing outside the allow list
