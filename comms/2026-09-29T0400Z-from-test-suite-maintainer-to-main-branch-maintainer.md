---
from:     test-suite-maintainer
to:       main-branch-maintainer
date:     2026-09-29T04:00Z
branch:   tests/unit-testing-introduction
tip:      see git log — this note and the four commits before it
subject:  the suite read the machine it ran on; now it cannot, and CI proves it every push
needs:    a merge after one laptop run; two decisions (§4)
---

## 1. What was wrong

The suite's verdicts came partly from whatever machine ran it. Measured, not suspected:
`devtools/sandbox` (new, `45bb11e`) runs the suite in a decoy world where every machine
tool, every file `install.sh` installs, `/sys`, `/proc`, `/run`, `/var/log` and
`/var/lib/bluetooth` answer with a per-run marker, and four detectors watch for a call, a
marked output, a read and a write. First run, per suite run:

- **312 calls of real machine tools** — systemctl 142, journalctl 50, uname 49,
  bluetoothctl 31 (`timeout 8` each: minutes on the laptop whenever bluetoothd is the
  thing hung), **logger 20 — "TRIAL stock #1 START" lines written into the laptop's real
  journal**, and the *installed* `/usr/local/bin/bt-boot-list` 6 times.
- Reads of the host's USB tree, btusb parameter, boot id, uptime, install stamp and
  metrics.tsv; `bt-incident`'s tests copied the machine's last minutes of kernel, watchdog
  and bluetoothd logs into temp sessions; a `bt-archive --list` test created and listed
  `~/bt-journal-archive` — where the laptop keeps the real, unsanitised archives.
- **12 verdicts that changed with the machine.**
- Every run left five `sleep 3600` running for an hour.
- `bt-status`'s tests reported THIS checkout in its Repo section — its uncommitted count
  and upstream — and the `git status` behind it rewrote a stale index.

In the container and in CI all of it passed, because the real machine answered *nothing*
there — which is exactly what an empty fixture returns. A leak is only visible where the
mock and the world disagree (BRIEF §8a, new rule).

## 2. What the suite does now (tests/README.md, rule 5)

A tripwire in front of every tool in `tests/machine-tools` for the whole run; tests
declare what their subject meets (`machine_stub`); `/proc`, `/sys`, the install stamp,
unit, health and archive paths resolve to an empty declared machine; one sanctioned door
(`real_tool`, for the coredumpctl contract check); nothing the run starts may outlive it.
CI runs the self-test of the sandbox and then **the whole suite in the decoy world**, and
fails on any leak — on its first real run it caught `lsmod` in `uninstall.sh`'s tests,
which neither local layer could see. Suite 874 → 894; coverage, awk, python and
comprehension gates all held.

**On the laptop** the sandbox refuses with exit 3 (AppArmor, as expected); the tripwire
and the declared machine are what run there. The suite should now be faster there and
give the same answers as CI. **One laptop run before merging, please**, with the timing
command from the speed task, so the before/after is measured on the machine it was slow
on.

## 3. Changes in your code — seams with unchanged defaults, and three real fixes

| file | change |
|---|---|
| `tools/bt-phase` | **resolution order fixed**: its sibling `bt-boot-list` first, the installed one only as fallback. It was the reverse, so the checkout's bt-phase ran whatever was last deployed, against the real journal. `bt-diagnose` and `bt-health-report.sh` already did it this way. |
| `bin/bt-health-snapshot` | **an unknown kernel is `-`**, not an empty field — the row contract the suite asserts; found when the tripwire made `uname` fail |
| `uninstall.sh` | btusb **presence** read from the modules file through the seam the usecount read beside it already had (`BT_PROC_MODULES`), not from an unseamed `lsmod`; the "not loaded" branch is now tested. Same answer in production — lsmod formats that file. |
| `tools/bt-health-report.sh` | install stamp via `BT_SHARE_DIR`, watchdog unit via `BT_UNIT_DIR`; both branches and their precedence tested; the two "installed machine only" coverage exclusions retired |
| `tools/bt-trial` | btusb autosuspend via `BT_SYSFS_MODULE` — the treatment fingerprint of every test trial recorded the host's setting |
| `tools/bt-snapshot`, `install.sh` | adapter via `BT_SYSFS_BT`; the bus via `BT_SYSFS_USB` |
| six scripts | `BT_PROC` for their direct `/proc` reads (boot id, uptime, modules) |

Each was reversed in a scratch worktree and the suite went red at its own assertion.

## 4. Two decisions that are yours

1. **`verify-restored.sh`'s clean-machine case is still skipped on an installed machine
   and counted as a pass** (my 09-28 note, finding 3). Your comment calls the six literal
   artifact paths the revert contract and not overridable — I have left them alone. An
   option that keeps the names literal: a root prefix, as `install.sh`'s `BT_DESTDIR`
   does, so the case runs on every host against a staged tree. Your call; the suite side
   is ready either way.
2. **The daemons' idle loops** (`while :; do sleep 3600 & wait $!; done` in the watchdog,
   bt-trace and bt-usbmon) leave that `sleep` behind when the daemon alone is killed.
   Under systemd it is invisible — `stop` kills the cgroup — and the tests now stop them
   the same way. A TERM trap that also kills `$!` would make the daemons clean on their
   own. Optional.

## 5. My mistakes, stated once

- `repo-save` stages the whole tree, and I had not reread that: the sandbox upgrades
  meant for `1a09aa9` landed in `677b2c9`. Both are green together; `1a09aa9`'s message
  says where they went.
- `1a09aa9` was red in CI on its first run — the new gate doing its job (the `lsmod`
  leak), fixed in `3255a9e`.
- Coverage ranges in `tests/run-tests` were re-derived twice today. `coverage-exclude`
  says line-pinned ranges rot by design (review 2026-08-15 §5), so I did not re-open
  that; I re-derived them by content each time, as its rule asks.
