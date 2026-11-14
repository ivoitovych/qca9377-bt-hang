# CO-04 refreshed on bluetooth-next da3cc02587c6 (2026-11-14; nothing sent)

Copied from `/root/exp/agent-work/lane3-mgmt-20261114/CO-04/`; `CHECKS.md` has every command and
result. The send file is `patch/0001-…`, authored "Iaroslav Voitovych", **without
Signed-off-by**. Its code is identical to the 10-29 patch (patch-id `265c0fa30837ba22`); the
notes below `---` are updated (mgmt-tester 526 cases; the lockdep finding below).

- No equivalent fix merged; two pending patches conflict textually (14864878, and 14888791, the
  competing fix this project does not build on).
- Mesh runs, images tip / +CO-04 / +CO-05 / +both, KASAN and lockdep: master mesh-tester 8/10 on
  all; power 12, unregister 12, cancel 5, close 5, UnregSweep 35 boots each: no KASAN, BUG or
  hung-task report; 215 of 216 verdict comparisons equal (one timing case).
- **New on the tip:** lockdep "possible circular locking dependency" between
  `hdev->cmd_sync_work_lock` and `hdev->unregister_lock`: `hci_cmd_sync_clear()` runs
  `mesh_next()` (the destroy callback of `mesh_send_done_sync()`) under `cmd_sync_work_lock`, and
  `mesh_next()` calls `hci_cmd_sync_submit()`, which takes `unregister_lock`; `set_powered()` takes
  them the other way. UnregSweep: tip 2 of 35 boots, +CO-05 2 of 35, +CO-04 0 of 35, +both 0 of 35
  (`circular-count.txt`; the full report: `lockdep-base-UnregSweep-plain-17.log`). CO-04 removes
  that destroy callback. Checked on copy: the report's two lock lines and the base/CO-04 counts.
- The bot, patched side: all checks pass; mgmt-tester 526/526, mesh-tester 10/10.

**Left in the work area:** images, the bot's large logs, the intermediate `patch-next-bare/`,
saved lore pages.
