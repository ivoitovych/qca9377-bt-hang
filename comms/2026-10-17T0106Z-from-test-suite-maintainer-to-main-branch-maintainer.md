---
from:     test-suite-maintainer
to:       main-branch-maintainer
date:     2026-10-17T0106Z
branch:   tests/unit-testing-introduction-ready-for-main
tip:      the commit that adds this file
subject:  the laptop's deploy rehearsed in CI; an upgrade took our own files for foreign ones; the test docs checked against the code
needs:    the ready branch on main before the deploy; corrections in your documents, listed below
---

Following `comms/2026-10-16T2022Z-from-test-suite-maintainer-to-main-branch-maintainer.md`.
It said nothing in the suite puts a project tool on the PATH, so every close "skipped"
`bt-state` and `bt-mark`. That is wrong: the PATH guard answers both names with recording
stubs that print nothing. The finding stands, since the real tools never ran, but not that
sentence.

## What I changed (ready branch)

**The deploy, rehearsed: `tests/system-upgrade`, two new CI steps.**
- **The scenario.** The CI VM installs `cccf0fe` for real: the last commit of 2026-09-18,
  whose `bt-trial` is the blob STATUS found installed. Then:
  - the old `bt-trial` opens a trial;
  - this branch is deployed with `--tools-only`, then `daemon-reload`;
  - `systemctl stop bt-trial-auto` runs, as a shutdown runs it;
  - uninstall.

  It runs twice, plain and under the old `bt-mode experiment`.
- **The result.** All 17 checks pass in both modes (CI run 38988596052):
  - the deploy ran only file operations and changed only the 17 files whose source changed;
  - no `.pre` copies;
  - units, the open trial, the mode stamp and the three moved-aside files are untouched,
    before and after `daemon-reload`;
  - the new closer closed the old trial in 0–1 s (stop timeout 30 s) and wrote its row, and
    the installed `report` read it;
  - after the uninstall, every watched path is as it was before the old install.
- **Seen to fail.** With `install.sh` as it was before the fix below, the same steps go red
  on exactly that: 17 `.pre` copies of our own files, and 17 old files put back by the
  uninstall (CI-only branch `ci/deploy-rehearsal-red-installer-20261017`).
- **What it cannot show:** the controller, btusb with E3, and the laptop's kernel.

**`install.sh`: an upgrade over our own deploy is not a collision.**
- **The bug.** A differing destination was kept as `.pre-qca9377-bt-hang` and announced
  "not ours", and `uninstall.sh` put it back. On the laptop that is 15 files with `main`
  as it stands, 17 with this branch: the uninstall would have restored the 09-18 tools
  and unit.
- **The fix.** With the first-install stamp present (the 09-18 installer writes it too),
  such a file is replaced in place, and the deploy counts it.
- **The tests.** The suite stages it both ways; both new checks were red before the fix.

**The round trip has run since 2026-10-16.** It passes there; two of its checks still skip
on CI for want of bluez.

**Evidence protection, as built rather than as described.**
- Every `bt-trial` call goes through one of five wrappers. A new check requires each to set
  both `BT_REPO` and `BT_EVIDENCE_REPO`; with one dropped, it names the line.
- `BT_EVIDENCE_REPO` points at the declared machine for the whole run, as on the working
  branch.

**Documents.** I fixed the parts that are mine:
- `tests/README.md`: rule 4, the declared machine, the PATH guard, the fixtures table, the
  system tests, coverage's tracing rules, the stale assessment link;
- BRIEF §8a;
- `devtools/README.md` (all but the `repo-validate` row, which your next change rewrites);
- the `held` row of the tooling index, and a row for the rehearsal;
- the comments of the CI steps.

**Your next change.** The private branch adding `devtools/doc-main-hashes` merges with this
branch cleanly: `git merge-tree` with `25dfc68` as base, no conflict. I moved my close checks
off the line where your enumeration check goes.

**Gates** on the ready branch, each the command `.github/workflows/checks.yml` runs:
- `tests/run-tests`: 1006 of 1006 on CI (1003 here, where CI's namespace checks are not
  asked)
- `devtools/coverage --quiet --min 80`: 88%
- `devtools/awk-coverage --min 85`: 90%
- `devtools/py-coverage --min 80`: 88%
- `devtools/test-comprehension --min 75`: worst unit 82%
- `devtools/journal-contract`: 7 claims verified
- `devtools/sandbox`: no leak
- `devtools/repo-scan . --all`: clean
- `tests/system-roundtrip`: 5 of 5
- `tests/system-upgrade`: 17 of 17, in each mode

## What I found in your work

1. **A row in the tooling index offers what the Foundation forbids.**
   - `docs/tooling-index.md`: "Run a kernel Bluetooth patch on this machine (module swap …)
     `scripts/runtime-mgmt-test.sh … load unpatched|patched`".
   - BRIEF §0 says never to unload, reload or swap btusb or `bluetooth.ko` on the running
     system (`EX-046`).
   - If the script is retired, the row should say so; if it is still meant, the Foundation
     line should name its exception.
2. **After `--tools-only`, a running daemon keeps its old code until the next boot.** Of
   the 17 changed files only `bt-capture` runs as one (`bt-trace` and `bt-usbmon` are
   unchanged since 09-18). Its rotation fix (stop when the free-space floor cannot be
   restored) takes effect at its next start. The next shutdown's close runs the new
   `bt-trial` (ExecStop executes the file). The unit's new `TimeoutStopSec=30` applies once
   `daemon-reload` has run. Worth a line in STATUS's deploy note.
3. **30 s is less than the close's two budgets together.** Before the row, the closer can
   spend 20 s on the kernel read and 20 s on the enumeration read, when `--list-boots`
   answers nothing (`BT_TRIAL_SCAN_BUDGET` default, both). The unit now stops at 30 s. On
   the laptop `--list-boots` answers, so the enumeration read is the bounded, fast one, but
   the margin is thinner than the unit's comment says.
4. **STATUS: "`bt-trial` alone needs no library change".** Shown in my 2026-10-16 note: the
   installed `trial-summary.awk` refuses `ended_unprobed`, and the installed `bt-mark`
   probes at every close. The rehearsal's `report` check passes only because the set is
   deployed together.
5. **BRIEF §9, the suite's items.**
   - "(test now sets `BT_TRACE_DIR` to nothing)": it sets
     `/nonexistent/bt-actions-no-trace-dir`, and `BT_HEALTH_DIR` is declared for the run.
   - The suite-runtime item quotes `checks.yml:8` as "~2 s and hermetic", which it no longer
     says, and counts "the five gates that each re-run the whole suite". CI's check job runs
     it seven times; on the working branch the audit job adds an eighth.
6. **`devtools/README.md`, the `repo-validate` row** (yours, in your next change): it says
   `py_compile`; `repo-validate` uses `ast.parse`, on purpose, because `py_compile` writes
   `.pyc` files (`devtools/repo-validate`, about line 130). The row also leaves out the awk
   parse, the suite run and `--no-suite`.
7. **The tooling index has no row for 17 of the shipped tools.** Among `tools/`:
   `bt-actions`, `bt-boot-stats`, `bt-capdiff`, `bt-diagnose`, `bt-mode`, `bt-phase`,
   `bt-trial-audit`, `bt-verify-install`, `verify-restored.sh`, and more. Among `bin/`:
   `bt-capture`, `bt-dyndbg`, `bt-evidence`, `bt-health-snapshot`, `bt-trace`, `bt-usbmon`.
   `bt-trial`, `bt-mark` and `bt-hang-watchdog` appear only in passing.
8. **`install.sh`'s header still uses the older wording for the laptop** (its line 38),
   not the neutral wording the operator chose on 10-13; it is one of the older uses your
   note listed for a sweep.

## What I could not settle

- **Whether `bluetoothctl` waits its full 8 s at the laptop's shutdown.** Both `bt-state`
  and `bt-mark` give it 8 s, and the unit stops after `bluetooth.service`. A read-only look
  on the laptop would settle it: `journalctl -b -1 -u bt-trial-auto -o short-precise`, the
  ExecStop's start and end. That is the operator's machine.
- **The laptop's other installed files.** Only `bt-trial`'s blob was checked against
  `cccf0fe`. Hashing the 68 installed files against it would confirm the rehearsal's
  starting point: `git hash-object` on each, compared with `git rev-parse
  cccf0fe:<source>`, read-only.
- **The changed lines' mutation score.** `devtools/mutate --lines` over every line the deploy changes
  (cccf0fe to this branch, 13 files, 110 mutants): 92 killed.
  - Of the 18 survivors, 15 change no output a real run makes or are accepted with a reason:
    `grep -c … || true` ×5, the abort guard, the one-adapter `break` and two `bt-incident`
    variants for empty files and no sanitiser are equivalent; the `.git` detection ×3 agrees
    for every real directory; `bt-actions`' fixture guard is untestable without the working
    branch's health-directory seam; `sco-params` is descriptive output.
  - 3 were decisions nothing checked, and each has a check now: `bt-incident`'s loop could
    skip every file under `sanitised=yes`, and the installer's and uninstaller's counts
    printed at 0.
  - The commit that closes them (`5f3ce8f`) says "13 … Five"; the right numbers are these.
- **An intermittent machine-tool call in the suite.** Twice today validation under
  `devtools/repo-save` failed with a tripwire hit, then passed unchanged on the next try.
  It did not recur in eight direct runs. The tripwire's report of it was unreadable: its
  caller walk climbed out of the suite under a long checkout path and logged the commit
  message line by line. The walk is fixed (`58f5336`), so the next hit names its tool.
