# CO-38 — MGMT Read Advertising Features hides advertising instances

**What:** `read_adv_features()` (net/bluetooth/mgmt.c) means to hide only the mesh instance,
numbered one past the controller's advertising sets, but compares each instance number with the
*number of instances* (`adv_instance_cnt`) instead of the *number of sets*
(`le_num_of_adv_sets`). With instances 1 and 2 added and instance 1 removed (for example by its
timeout), instance 2 is no longer listed. From `b338d91703fa` (2022); present from 6.1.y to
bluetooth-next. Found 2026-11-01 by CO-12's tests.

**State (2026-11-02): ready to send, not sent.**

- Kernel: one-line fix, `send-20261102/0001-Bluetooth-MGMT-Fix-Read-Advertising-Features-hiding-.patch`,
  on public bluetooth-next `42b8c2d72926` (`base-commit` set). checkpatch `--strict`: 0/0/0. No
  `Cc: stable` yet: the operator's decision (review follow-up D12; reviewers favour it).
  The From line carries a placeholder; the operator's own identity goes in at send.
- BlueZ: `send-20261102/bluez/`, `[PATCH BlueZ 0/3]` on master `14bd6ab65`: 16 new cases (15
  mgmt-tester, 1 mesh-tester); no research-only cases; no Signed-off-by (BlueZ takes none);
  three subjects of 51, 56 and 57 columns (decision D9).
- Measured (QEMU, KASAN + lockdep, 3 runs each, no CO-12 clamp on either kernel): mgmt-tester
  "Add" cases 119/128 on the plain tip, 120/128 with the fix alone; the only change is
  "Add Ext Advertising - Instance 2 listed alone", fail 3/3 → pass 3/3; the 8 duration cases
  fail on both until CO-12's fix; mesh-tester 8/10 on both (the two known "Send cancel"
  failures). All 12 guest logs clean. BlueZ bot checks pass (one TestFunctional flake in
  `test_bluetoothctl_pair_bredr`, passed on re-run). Details: `send-20261102/RESULTS.md`.

**Open:** `Cc: stable` (D12). The BlueZ series carries 8 cases that fail until the CO-12
duration fix lands, and CO-12 may go out as an RFC (D5): send the series now with the cover's
explanation, or hold the timeout cases until CO-12 is settled and send the listing case alone.
The operator decides and runs the sends.

**Work area** (local; raw logs, SHA256SUMS): `/root/exp/agent-work/co38-ready-20261102/`;
earlier: `/root/exp/agent-work/co12-rework-20261101/`.
