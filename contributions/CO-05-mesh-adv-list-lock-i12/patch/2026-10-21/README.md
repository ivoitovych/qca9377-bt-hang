# CO-05 — the patches, for outside review (not a send package yet)

**Two kernel patches, not sent, and not ready to send:** this page asks for the outside review that
CO-05 still lacks. The checks listed under "Not done yet" come after it.

- [`0001-Bluetooth-MGMT-Take-hdev-lock-in-mesh_send_sync.patch`](0001-Bluetooth-MGMT-Take-hdev-lock-in-mesh_send_sync.patch)
  — `mesh_send_sync()` changes the advertising-instance list (`hci_add_adv_instance()`) without
  `hdev->lock`, which the list's functions require. It takes the lock for the list change and the
  list walks, and never holds it across an HCI command. `Fixes: b338d91703fa`.
- [`0002-Bluetooth-MGMT-Stop-mesh_send_sync-when-it-cannot-ad.patch`](0002-Bluetooth-MGMT-Stop-mesh_send_sync-when-it-cannot-ad.patch)
  — when `hci_add_adv_instance()` fails, the function went on and scheduled an instance that was
  never added; it now returns the error at once. Kept separate: no client-visible change, and 1/2
  stays small.

Base: bluetooth-next `27731ba09195` (2026-10-21). They apply to today's `47d4d9f67e92` with 2-line
offsets (`scripts/series-backport-check.sh`, 2026-10-28). Nobody else has posted a fix for this.

## Evidence (`../experiments/results-2026-10-21.md`, `../log.md`)
- With `lockdep_assert_held(&hdev->lock)` added to the add and remove functions, the mesh path
  fires three warnings on the unpatched tree, none with the patches.
- KCSAN on 4-CPU guests: races on the list between Add Advertising (locked) and
  `mesh_send_sync()` (unlocked) in 5 of 45 boots unpatched, 0 patched.
- mgmt-tester (503 cases) and mesh-tester verdicts unchanged; no new lockdep report.
- No KASAN report or corruption was ever shown: the case for the fix is the lock contract
  (`hci_core.c`, since `d2609b345ebf`) and the races, not observed damage.

## Not done yet
`scripts/kernel-preflight.sh` (checkpatch `--strict`, `W=1 -Werror`, sparse) and
`scripts/bot-ci-local.sh` on today's base; a regenerated pair on today's base; a cover letter; the
recipients from `get_maintainer.pl`. The other three unlocked callers (ISO broadcast, Set LE off,
the advertising timeout) are separate patches, not part of this pair.

## Questions for reviewers
1. Is the locking right: `hdev->lock` taken after `req_lock`, released before any command wait,
   and no `adv_info *` kept across the unlock (the instance number is copied instead)?
2. Should 2/2 be folded into 1/2, or stay separate?
3. Does the pair conflict with the other pending mesh fixes on patchwork (14831271, 14864878,
   14880941, 14888791)?
4. Is the evidence enough without observed damage, or should a stronger reproducer come first?
