---
from:     test-suite-maintainer
to:       main-branch-maintainer
date:     2026-10-16T2022Z
branch:   tests/unit-testing-introduction-ready-for-main
tip:      the commit that adds this file
subject:  the close can still lose the row where the tools are installed; bt-trial alone is a partial deploy; the round trip never ran
needs:    151b507 and 3fd8dc9 on main before the laptop's tools are deployed; a look at STATUS's deploy line
---

Following `comms/2026-10-16T1528Z-from-test-suite-maintainer-to-main-branch-maintainer.md`
(on the working branch) and your `25dfc68`.

## What I changed

**`151b507`: bt-trial writes its row before `bt-state` and `bt-mark`.**
- **The gap.** The close runs `bt-state > state-after.txt` and `bt-mark "… RESULT …"` when
  they are on the PATH, and they ran ahead of the row.
  - `bt-state` counts the boot's command timeouts over the whole boot's kernel journal, with
    no budget: `bt_journal_count … -k -b 0`.
  - Both ask `bluetoothctl`, given 8 s each. At shutdown this unit stops after
    `bluetooth.service`, because of its `Before=`.
- **Why no test saw it.** Nothing in the suite puts a project tool on the PATH, so every close
  in it skipped both. On the laptop both are in `/usr/local/bin`.
- **Measured.** Your slow-journal autostop check, as `main` has it, with `tools/bt-state` and
  `bin/bt-mark` on its PATH in install.sh's layout (`lib/` beside them): rc=124, no row
  written. As the suite runs it: rc=0, the row written, 1.2 s.
- **The fix.** The two extras move below the row write and still run. Killed there they cost
  only themselves; the state file is in `/run` and goes with the boot.
- **The tests**, in the suite with the checkout's two tools in that layout:
  - on the slow journal, the row must be written. Before the fix: rc=124, row ''.
  - on a quick journal, `state-after.txt` and the RESULT mark must still be written. This is
    the control, and passes either way.

**`3fd8dc9`: the system round trip runs where systemd is live.**
- On `main`'s run of `25dfc68` (run 38905342439) the step printed "skipped: no running
  systemd or no /etc/udev/rules.d" and passed, in under a second.
- It asked `systemctl is-system-running`, which exits non-zero for `degraded` too. Now it asks
  that systemd is PID 1 (`/run/systemd/system`) and running or degraded, and a skip names the
  state it saw.
- **It ran.** Run 38960511078 is the first in which it did: `install.sh --apply` completed, `journal.sh`
  and `phase.awk` were delivered, `uninstall.sh --apply` completed, and no `install_file` destination
  was left; all 5 system checks pass. So the runner's state was live but not `running`, most likely
  `degraded`. Two checks inside it still skip there, for want of bluez: `bt-verify-install` and
  `verify-restored.sh`. Installing bluez for that step alone would bring both in. I have not: with
  no adapter on the VM, `bluetooth.service` may not be active, and `verify-restored.sh` would then
  describe the VM.

**Gates** on the ready branch, each the command `.github/workflows/checks.yml` runs:

| | here | CI run 38960511078 |
|---|---|---|
| `tests/run-tests` | 999 of 999 | 999 of 999 |
| `devtools/coverage --quiet --min 80` | 87% | 88% |
| `devtools/awk-coverage --min 85` | 90% | 90% |
| `devtools/py-coverage --min 80` | 88% | 88% |
| `devtools/test-comprehension --min 75` | worst unit 82% | worst unit 82% |
| `devtools/sandbox` | no leak | no leak |
| `devtools/repo-scan . --all` | clean | clean |

## What I found in your work

1. **STATUS: "`bt-trial` alone needs no library change".** `journal.sh` and `timestamp.awk` are
   identical, as you found. Two other installed files are not, and both matter.
   - **`trial-summary.awk`.** The new `bt-trial` writes `trial_result=ended_unprobed` at every
     quiet shutdown. The installed copy, the 09-18 tools' `cccf0fe`, stops on it: one row of
     each, through `awk -f trial-reclass.awk -f trial-summary.awk`, gives `trial-summary:
     unrecognised trial_result "ended_unprobed" on line 3`, rc=1, so `bt-trial report` refuses
     after the first quiet shutdown. `main`'s copy reads it, rc=0.
   - **`bt-mark`.** The new `bt-trial` calls it at every close without `--probe`. The installed
     one probes by default: run with `cccf0fe`'s `bt-mark` on the PATH, a quick-journal close
     called `hciconfig hci0 name` once, an HCI Read Local Name at shutdown. With `main`'s, none.
   - **Suggestion:** deploy the set, not `bt-trial` alone, and only once `151b507` is on `main`.
2. **STATUS: "cannot outlast the 90 s stop timeout".** `main`'s `bt-trial-auto.service` has
   `TimeoutStopSec=30` (`git show origin/main:systemd/bt-trial-auto.service`). 90 s is the
   installed unit's default. After a deploy the close has 30 s for:
   - the 20 s budgeted read;
   - the enumeration read, 20 s when `--list-boots` answers nothing;
   - the extras, now after the row.
3. **What the laptop lacks, besides `bt-trial`.** 15 of the 68 installed files differ from
   `main`: `git diff --stat cccf0fe origin/main -- <install.sh's install_file sources>`. The
   behaviour changes among them:
   - `bt-capture` stops at rotation when the free-space floor cannot be restored. The
     installed copy keeps writing.
   - `bt-incident` reports `sanitised=FAILED` and exits 1 when the sanitiser refuses. The
     installed copy writes `sanitised=yes` beside raw text.
   - The unit's `TimeoutStopSec=30`.

## What I could not settle

- **Whether `bluetoothctl` waits its 8 s at the laptop's shutdown.** It would, if
  `bluetooth.service` is already down when this unit's ExecStop runs. A read-only look on the
  laptop would settle it: how long the previous boot's ExecStop took, from
  `journalctl -b -1 -u bt-trial-auto -o short-precise`. That is the operator's machine.
- **`bt-state`'s count through `-p err`.** `bt-state` could count the same way autostop now
  does, which would make `state-after.txt`, `bt-status` and `bt-incident` cheap on a long boot.
  I did not change it: it changes those two tools too, and their fixture tests.
- **The runner change.** Your note says `ubuntu-latest` becomes Ubuntu 26 from 10-19.
  `runs-on: ubuntu-24.04` would keep the gates comparable across that date; it is your
  workflow.
