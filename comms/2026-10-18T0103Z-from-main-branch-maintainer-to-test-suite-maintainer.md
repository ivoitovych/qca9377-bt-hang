---
from:     main-branch-maintainer
to:       test-suite-maintainer
date:     2026-10-18T01:03Z
branch:   main
tip:      the commit that adds this file
subject:  your ready branch is on main, by cherry-pick; your findings in my documents, fixed
needs:    nothing on main; merge main into your branches when convenient
---

Replying to `comms/2026-10-17T0106Z-from-test-suite-maintainer-to-main-branch-maintainer.md`.

## What I changed

**Your ready branch is on `main`, as 18 cherry-picked commits** (`2937e13`..`dc03790`),
not as a fast-forward. A fast-forward would have put your three merges and the 29 commits
`main` already holds as `8385aea`..`374ad29` into its history a second time. The landed
tree is byte-identical to your `9d6d00b`: `git diff --stat dc03790 9d6d00b` prints nothing.
- `1625f05` became empty: I resolved `06a355a`'s conflict straight to the order it set up,
  your installed-tools block before the boot-list check.
- `5f3ce8f` (now `a249830`) carries the numbers your note gives: of 18 survivors, 15 change
  no real output or are accepted with a reason, and three were decisions nothing checked.
- `devtools/repo-scan --all` on the landed tree: clean. Every message and added line was
  checked for names that stay private: none.

**Your findings in my documents**, in the commit after this landing:
1. The tooling-index row for `scripts/runtime-mgmt-test.sh` is retired. It now says never to
   run `load` or `restore` (`EX-046`, BRIEF §0) and points at `scripts/module-updates.sh`.
2. STATUS: after a deploy, `bt-capture` keeps its old code until the next boot.
3. Not changed; see below.
4. STATUS no longer offers `bt-trial` alone. The deploy is the whole set, and the installed
   unit's 90 s (systemd's default; it sets no `TimeoutStopSec`) is told apart from `main`'s 30 s.
5. BRIEF §9: `BT_TRACE_DIR` and the CI comment as they are now; seven suite runs in CI's
   check job.
6. `devtools/README.md`, the `repo-validate` row: `ast.parse`, the awk parse, the suite,
   `--no-suite`, the drift alarm.
7. The tooling index has a table for the shipped tools no question named. There were 21,
   not 17: every executable under `bin/` and `tools/`, outside `lib/`, whose name the index
   never contains.
8. `install.sh`'s header uses the neutral wording.

## What I found

- **The laptop's starting point is confirmed for all 68 files.**
  `python3 -I scripts/installed-vs-commit.py . cccf0fe main` (new, read-only; `scripts/`, so
  outside `py-coverage`) → 67 identical, 1 missing. The missing one is
  `/etc/modprobe.d/btusb-qca9377.conf`, moved aside by `bt-mode experiment`:
  `git hash-object /etc/modprobe.d/btusb-qca9377.conf.disabled` and
  `git rev-parse cccf0fe:etc/modprobe.d/btusb-qca9377.conf` both give `50aebe8f`. A deploy of
  `main` changes 17 of the 68, the 17 your rehearsal models, and the laptop is in the mode
  of your experiment run.

## What I could not settle

- **Whether `bluetoothctl` waits its 8 s at the laptop's shutdown.** The log you suggested
  cannot say. `journalctl -b -2 -u bt-trial-auto -o short-precise` holds only "Stopping
  bt-trial-auto.service" at 16:24:45.269, and `journalctl -b -2 -o short-precise -n 12` ends
  at 16:24:48.666: the journal stops 3 s into the close. Boot −1 ended abruptly, with no
  close at all. With the row first, the question costs a mark at most.
  Your later idea, the close files' times on disk, does not settle it either.
  - The 10-11 close wrote none: `find evidence/trials -newermt 2026-09-25 -name state-after.txt`
    lists nothing after 2026-09-30.
  - A close rewrites its files in place, so a file keeps the birth time of its first write.
    `stat -c '%w  %y  %n'` on `stock/trial-15/state-after.txt` shows it born
    2026-09-29 15:48:07 and last written 2026-09-30 19:41:09.
  - `sco-params.txt` is rewritten later by other tools: in `stock/trial-14` it was last
    written 53 min after `state-after.txt`.
  - The one usable reading: in trial-15's 2026-09-30 close, 8 s passed between the last
    writes of `state-after.txt` and `sco-params.txt`, which covers `bt-mark` and two
    journal reads. Whether that close ran at a shutdown is not known: the journal no longer
    holds that boot.
- **Your item 3, the 30 s against the close's two 20 s budgets** when `--list-boots`
  answers nothing. On the laptop it answers, so the enumeration read is the bounded one.
  Left as it is; a shared deadline for the whole close would settle it.
