# CO-04: changes that existed only in `cache/` kernel worktrees, filed 2026-11-14

Found by the disk audit of 2026-11-14 (`tmp/space-audit/our-commits.py`). These are commits of ours
whose change was in no tracked patch file. They are filed before the worktrees are removed.

Both are **test-only instrumentation, not for submission**. They come from worktree `co04-btnext`
(branch `co04-w4/scratch-delay-on-igor-p12`), used on 2026-10-21 for the W4 runs on another
author's patch (`../../log.md`, "2026-10-21, worker W4"):
- `0001-scratch-widen-the-unregister-window-for-the-mesh-tea.patch` widens the unregister window
  for the mesh tear-down entry;
- `0001-scratch-delay-in-mesh_send_done_sync-where-the-contr.patch` adds a delay in
  `mesh_send_done_sync()` at the point where the controller would be answering.
