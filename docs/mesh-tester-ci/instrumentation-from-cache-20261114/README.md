# Mesh tester CI: a change that existed only in a `cache/` kernel worktree, filed 2026-11-14

Found by the disk audit of 2026-11-14 (`tmp/space-audit/our-commits.py`). This commit of ours
changed something that was in no tracked patch file. It is filed before the worktree is removed.

`0001-scratch-hold-hci_unregister_dev-before-the-sync-queu.patch` is **test-only instrumentation,
not for submission**. It holds `hci_unregister_dev()` before the command-sync queue is cleared, to
open the unregister window. It comes from worktree `mesh-guest` (branch
`compare/power-off-scratch-unreg-hold-b-2026-10-05`), from the 2026-10-05 research gates and
power-off comparisons (`../gates-2026-10-05.md`, `../research-review-2026-10-05.md`).
