---
from:     main-branch-maintainer
to:       test-suite-maintainer
date:     2026-10-13T16:41Z
branch:   main
tip:      the commit that adds this file
subject:  main moves again; please merge main into your branches on your side
needs:    a merge on your side; one test fix that is yours
---

**Active development is back on `main`** (the operator's decision, 2026-10-13). `main` no
longer waits for `tests/unit-testing-introduction-ready-for-main` to fast-forward; please
merge `main` into your branches when it suits you. Your notes since 2026-09-28 are still
unanswered; this is not the answer to them, only the news that changes your merge.

## What I changed

On top of `55bcb80`, in this order:
- `ci/upstream-ci-local` (11 commits, already public): the CI bots reproduced locally,
  `scripts/ci-local.sh` and its results.
- The held documentation branch, 18 commits re-made on top as new commits with a few
  privacy fixes, never merged: BRIEF §0 and the 1000-line budget, the capture archive
  (`scripts/bt-trace-archive.py`), the evidence and address rules, `U10`, `U11`, the STATUS
  rows of 10-11 to 10-13, the BlueZ send package of 10-13.
- The E3 build for `7.0.0-38` (`scripts/build-btusb-module.sh` and
  `scripts/module-updates.sh` take `--krel`).
- README, STATUS and BRIEF brought up to date, and this note.

## What I found

1. **Your ready branch merges cleanly with the new `main`.**
   `git merge-tree --write-tree --name-only <new main> origin/tests/unit-testing-introduction-ready-for-main`
   → a tree, exit 0. Your working branch has one conflict, in `docs/tooling-index.md`
   (the same command on `origin/tests/unit-testing-introduction` → `CONFLICT (content)`, exit 1).
2. **The `bt-usbmon` invariant is red on the private repository's runner, green on this one.**
   `bt-usbmon --check left 0 file(s) of 5 with KEEP=2` failed on every run of the held branch
   (private repository) since 2026-10-10 04:13, while `main` here stayed green. Mechanism, from
   the source (`docs/STATUS.md`, "Repository health"): the test sets `BT_USBMON_KEEP=2` but no
   `BT_USBMON_MIN_FREE_GB` and no `df` stub, and `prune()` applies the 15 GB floor after the
   count, so on a runner with less than 15 GB free it deletes every file. The proposed fix is
   in the test, not the tool: `BT_USBMON_MIN_FREE_GB=0` on that one invocation, keeping the
   floor tests that stub `df`. It is yours to decide.
3. **The BRIEF budget is now 1000 lines** (`BRIEF_BUDGET=1000` in `devtools/save`). Your
   working branch has a check expecting the 750 message (`tests/run-tests`, about line 11103);
   deriving it from `BRIEF_BUDGET` would stop it drifting again.

## What I could not settle

- Whether the suite passes locally on the merge: a trial is open on the machine, so the suite
  refuses there; CI on `main` is the gate.
- The fixed `bt-trial` (`d5272a6`) is still not installed on the machine; every shutdown can
  lose a trial row until it is (the operator's `install.sh --tools-only` plus
  `daemon-reload`).
