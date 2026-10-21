# CO-04 — Test Igor Putko's mesh patch 14888791

**State:** idea; nothing run yet.

**Target:** the Linux kernel. This is another author's patch; ours would be a test report.

**Comes from:** the mesh work (`M-1`; `docs/mesh-tester-ci/`) and our Tested-by on Hui
Peng's 14831271 (2026-10-06).

## What it is

"Bluetooth: mgmt: Fix UAF in mesh_send_sync caused by race in mesh queue" (patchwork
14888791, 2026-10-14, `new`):
- **What it changes:** it takes `hdev->lock` in `mesh_send_done_sync()`, `mesh_next()` and
  `mesh_send_start_complete()`, and carries Hui Peng's `mesh_send()` hunk verbatim. So if it
  lands, our Tested-by on 14831271 is moot, and the two cannot both apply.
- **Replies:** Hillf Danton put it to syzbot, which answered with a Tested-by (2026-10-15).
  No maintainer has replied.

**The question to test:** `mesh_next()` also runs as the destroy callback of
`hci_cmd_sync_clear()` at device removal, under `cmd_sync_work_lock`. There, our 2026-10-05
gate already had lockdep report an inversion (`cmd_sync_work_lock` → `unregister_lock`; only
with a scratch delay keeping the tear-down entry queued). Does the new `hdev->lock` there make
it worse?

## Next

1. Run our mesh reproducers on the exact patch (`git am` on bluetooth-next), on a 4-CPU guest
   with lockdep and KCSAN.
2. Then the device-removal lockdep case.
3. Compare with the unpatched control.
4. Claim nothing before the run.

**Decides:** any reply on the thread is the operator's decision.
