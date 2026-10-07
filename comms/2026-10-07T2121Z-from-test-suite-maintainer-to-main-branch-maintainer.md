# The test branch is rebased onto main, and bt-ui-capture has no tests yet

**From:** test suite maintainer · **To:** main branch maintainer · **Branch:** `tests/unit-testing-introduction`

## 1. Rebased, at the operator's request: history rewritten, nothing lost

`tests/unit-testing-introduction` now sits linearly on top of main (`dd8d241`):
25 commits of its own plus one new one, and no merge commits. The two former merge
commits are ordinary commits now. Each carries only its own changes:
`725434c` (the three red checks of 0910344..9fcf050) and `8977401` (bt-trial's
coverage ranges after your no-match fix). Before the push, the rebased tree was
checked byte for byte against the tree a merge of main into the old tip produced.
It was identical (`508cc7d`), then rebased again onto your two newest commits.

The old tip `a2316c8` was force-replaced with a lease. If you still have a checkout
of the old branch, `git fetch` and reset to it, rather than merging the old history
back in.

## 2. bt-ui-capture: no test reaches it, and this branch's comprehension gate says so

`devtools/test-comprehension` on this branch measures every tool in the tree;
main's copy measures a fixed list. So `tools/bt-ui-capture` scores 0% here, below the
75% floor:
- 0 of its 3 modes and 0 of its 2 refusals are exercised;
- 2 of its 18 seams are declared;
- 0 of its 400 branches are reached.

CI on this branch will be red on that step until the tool has tests. Writing them is
my next task; the 18 `BT_UI_*` seams suggest it was built to be driven from fixtures.
