# bt-ui-capture is under the suite; held, save and review-open run in place; awk-coverage counted wrong

**From:** test suite maintainer · **To:** main branch maintainer · **Branch:** `tests/unit-testing-introduction`

Three commits since the rebase note: `53061c5`, `f6e8f08`, `d778af9`. Each item
below changes a file you also carry. They reach main when this branch merges.

## 1. bt-ui-capture has tests, and one change in the tool

The checks of `scripts/prove-ui-capture.sh` now run in `tests/run-tests`, against the
tool in place, with your stubs. The suite then goes further: status, the bus
monitors and their rotation, the refusals, and the tuning knobs. The comprehension
gate scores the tool 90%. Whether the standalone script stays is your call; nothing
here depends on it.

The tool change: `proc_env` read `/proc/<pid>/environ` directly. A stubbed `pgrep`
hands back a pid, and the real `/proc/<pid>` belongs to some other process. It now
reads through `BT_PROC`, as the other tools do. The default is unchanged.

The shipped defaults (`/var/log/bt-health/ui`, the dynamic-debug control file,
`/usr/share/applications`, the effective uid) run inside `unshare -Urm`, with a
tmpfs over each real path. That namespace proves itself before anything runs in it
(tests/README.md, rule 6).

## 2. devtools/held status could vouch for an origin it never reached

When `git ls-remote origin` failed, the count of its output was 0, and status
printed `origin carries no kernel/* branch ✓`. It now prints that the check was NOT
made, and exits 1. So `held status` run offline fails where it used to pass. That is
the intended change.

`held` and `devtools/save` are now driven in place, in a *checkout world*: an
overlay of the checkout over its own path, in a network namespace, with scratch
bare repositories as origin and private. Covered so far: `held status`, `sync`
(including an exhibit-index conflict and a conflict it must stop on), `edit` and
`commit`, and `save`'s refusals, warnings and commit. Nothing reaches your checkout
or GitHub; the world proves that before it runs anything.

## 3. devtools/review-open refuses an unknown option

Before, any word other than `--all` and `--counts` listed the open rows, so a typo
of `--all` answered a different question. It now exits 2 and says so.

## 4. The coverage instruments

- `devtools/coverage` dropped every absolute path as outside the checkout,
  including the checkout's own files named by full path. Those lines are credited
  now.
- `devtools/awk-coverage` had three counting errors, all making the figure low:
  - one program run by several scripts was counted once per script;
  - gawk's uncounted `BEGIN {` / `END {` headers were counted as statements that
    never ran;
  - repo-validate's parse check of each `*.awk` file over `/dev/null` was counted
    as a program of its own.

  89.8% of 1941 statements became 97.8% of 1340. The CI floor in
  `.github/workflows/checks.yml` rises from 85 to 95. `BT_SUITE` now names the
  suite it runs, so the suite can test it against a toy suite.

## 5. tests/run-tests refuses to run inside a run of itself

If `SUITE_RUN_ID` is already set, the suite exits 2 at once. Nothing you run
should notice: `--section` starts its child without the marker. A script of yours
that starts the suite from inside the suite would now stop instead of recursing.
