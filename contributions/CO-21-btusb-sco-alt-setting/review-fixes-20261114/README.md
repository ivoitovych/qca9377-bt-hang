# CO-21 after the 2026-11-14 outside review

These patches replace `../send-20261114/` for the send
(`../../../reviews/2026-11-14T1400Z-kernel-patches-review-answers-checks.md` §9).
- **Air mode first:** `conn->air_mode` is set before `conn->state = BT_CONNECTED` in
  `hci_sync_conn_complete_evt()` (reviewers 6 and 7).
- **One snapshot:** `hci_conn_sco_up_num(hdev, &cvsd, &transp)` counts both modes in one pass,
  with `lockdep_assert_held(&hdev->lock)`. `btusb_work()` takes `hdev->lock` only around that call
  and releases it before any USB call (reviewers 2 and 7).
  - **Lock order:** `btusb_notify()` only schedules the work, and `btusb_close()` and
    `btusb_suspend()` are not called with `hdev->lock` held.
  - Lockdep reported nothing in any run. KCSAN was not run.
- **Results:**
  - **The five usbip scenarios:** base 0/10, patched 10/10 (`logs/co21.txt`).
  - **Reviewer 7's interleaving,** opened by a debug delay between the counts (`test-only/`), 3 runs
    each (`logs/trans2.txt`): base and the earlier two-count version pick alt 0 with a CVSD link up
    in 3 of 3 runs, the one-pass version in 0 of 3.
  - **The bot:** all 11 testers pass on both sides (`bot/compare-*.txt`). CheckSparse gives a
    WARNING whose output is the same on the base.
- **Open: mixed CVSD and transparent links** (reviewers 2 and 7):
  - The patched worker picks alt 1 for a mixed pair.
  - The USB transport's SCO alternate-setting table gives alt 1 9 bytes per frame, one 8-bit
    channel. A 16-bit CVSD link needs about 16.
  - btusb's own comment ties alt 1 to mSBC.
  - The cover letter asks the question instead of coding a policy.
  - The emulator cannot judge real audio quality.
- **Sources:**
  - an older Bluetooth Core Specification text (the copy openly reachable), the USB transport's SCO
    alternate-setting table. The
    alt 6 row is second-hand, from kernel commits;
  - mainline `baac6276c0a9` ("Bluetooth: btusb: handle mSBC audio over USB endpoints"), quoted in
    `sources/`.
  - The specification PDF and one third-party page stay in the work area.
