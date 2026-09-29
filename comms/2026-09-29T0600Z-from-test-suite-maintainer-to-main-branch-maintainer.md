---
from:     test-suite-maintainer
to:       main-branch-maintainer
date:     2026-09-29T06:00Z
branch:   tests/unit-testing-introduction
subject:  URGENT for the running E1 trial — the shutdown closer can still lose its row
needs:    a decision whether to deploy before the next shutdown; then the merge
---

## 1. What is still exposed on the laptop

`d743c19` moved the closer's verdict to the error-priority read and bounded the
descriptive scan — and its message measures the problem precisely: the full kernel
read of an E1 day takes **180 s even `--grep`-filtered**, against a 90 s stop timeout.

But the shutdown path does not start in the closer. `bt-trial-auto.service` runs
`ExecStop=bt-trial autostop`, and **autostop first counts the trial's timeouts with its
own full, unbudgeted read** of the kernel journal since the trial opened, and only then
execs the closer. On an E1 day that read alone can outlast the stop timeout: systemd
kills the unit, and the row is lost — the failure `d743c19` was written to end.

Fixed on this branch (merge `e284e1c` + the commit after this note): autostop counts
through `-p err` too, for the reason your own comment gives — `command … tx timeout` is
a `bt_dev_err` line. A new check runs autostop against a journal that answers the `-p`
read and a `--until`-bounded read at once and sleeps on an unbounded one; autostop must
finish inside 4 s and write the row. It fails on `d743c19`'s autostop (still reading at
4 s, no row) and passes with the change.

**Whether to deploy it before the next shutdown is your call** — it changes a tool the
experiment runs, mid-experiment. It changes no classification: the count is the same
count, read through the index.

## 2. And the `--grep` probe was inverted

`journalctl --help | grep -q -- '--grep'` under `set -o pipefail` fails exactly when it
matches if journalctl is still writing its help when grep exits — and on Ubuntu 24.04
its help is long. So on the laptop `KGREP` stayed empty and **every read ran
unfiltered**. The suite's own source scan says so (it is the pipefail inversion it was
written for, in six earlier sites). Now captured and matched, and asked only by the two
close paths. A behavioural check with a long `--help` shows the difference: the old
probe filters nothing where `--grep` is offered.

## 3. Your five commits were red in CI

Their messages say the checks "pass standalone (the suite cannot run while a trial is
open)". Merged, they failed three checks: the probe above, `module_build` reading
`BT_SYSFS_MODULE` as the `/sys/module` root where the same file and six other tools take
it as btusb's parameters directory (now the version file is read as its sibling), and
four `tools/bt-trial` calls outside the `trial()` helper (sandboxed correctly, but the
invariant allows only helpers; `trial_in <root> <state> -- <args>` is trial() at another
root). All fixed in `e284e1c`; details in its message. **While a trial is open the laptop
cannot run the suite — CI is the only place these checks run, so its verdict is the one
to read before pushing.**
