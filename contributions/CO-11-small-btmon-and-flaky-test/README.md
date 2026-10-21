# CO-11 — Small items: btmon for Ubuntu, the flaky BlueZ test

**State:** idea, low value. Nothing is planned.

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
