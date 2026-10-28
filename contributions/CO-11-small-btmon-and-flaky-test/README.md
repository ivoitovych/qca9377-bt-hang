# CO-11 — Small items: btmon for Ubuntu, the flaky BlueZ test

**State (2026-10-28, reopened by the operator):**
- **(a) btmon for Ubuntu: ready to file.** The Launchpad report `ubuntu/lp-report.md` and the
  debdiff `ubuntu/bluez_5.72-0ubuntu5.8_5.72-0ubuntu5.9.debdiff`, approved by all six outside
  reviewers in the final go/no-go round at `e2e0e00` (`ubuntu/reviews-2026-10-28.md`). The
  operator files the bug (with a task for the development series), attaches the captures and
  `tests/btmon/real/mkcap.py` with the commands; then `XXXXXX` is replaced with the bug number
  and the debdiff attached for sponsorship.
- **(b) the Tested-by for 14879847:** not started on a working harness (below).

The sections below are the original notes (when this was rated low value).

## btmon's abort in Ubuntu's 5.72 (`BT-4`)

- **The fixes:** `fdbfe0018` ("monitor: Fix crash due to negative max_len", first in 5.80) and
  `dca0f10fd` ("monitor: clamp max_len in print_packet", master).
- **In Ubuntu 24.04:** neither fix is there, and Launchpad has no bug.
- **Low value:** our own tools now avoid the trigger with `btmon --columns=200` (`2eef340`).
- **A request is possible.** btmon is a debugging tool, so its value to Ubuntu users is small.

## Pauli Virtanen's fix for the flaky functional test (14879847)

- **What it fixes:** "test: functional: retry pairable when Busy", `new` since 2026-10-10.
  It is the cause of `test_bluetoothctl_pair_bredr[hosts15-vm2]` failing on about 7 in 26 bot
  runs (STATUS, A2 row).
- **What a Tested-by would need:** `scripts/functional-repeat.sh`, which has never completed a
  run here (it needs `/dev/kvm` and the `AF_ALG` interface).
