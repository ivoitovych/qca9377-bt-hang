# CO-04 — the send package (for an outside review round; nothing sent)

[`0001-Bluetooth-MGMT-Fix-use-after-free-in-mesh_send_sync.patch`](0001-Bluetooth-MGMT-Fix-use-after-free-in-mesh_send_sync.patch)
— one patch on bluetooth-next **`1081a6ef8f1e0`** (`git format-patch --base`, then the notes
inserted below `---` by hand), commit `6d7ae083f6165` on the worker's branch `mesh/co04-final-on-1081a6ef8f1e0` (the shared kernel
repository `cache/linux`).

- **Tags:** `Fixes: b338d91703fa ("Bluetooth: Implement support for Mesh")`, `Reported-by:
  syzbot+f20755f37da70df33a16@syzkaller.appspotmail.com` and `Closes:
  https://syzkaller.appspot.com/bug?extid=f20755f37da70df33a16`, as syzbot's bug page asks
  (`log.md`, 2026-10-28), `Cc: stable@vger.kernel.org` (a reported use-after-free since 6.1).
  `Closes:` is put in as the page asks; syzbot itself has not tested the patch (a `#syz test` on its
  thread needs the operator's own word).
- **Below `---`:** the earlier proposal by link with its lock-order problem in one technical
  paragraph; the textual conflicts with two pending patches; a test paragraph that says the
  reproducer was not run.
- **Independent of CO-05:** they apply in either order to the same tree; the decision and its reason
  are in `../log.md` (2026-10-29).

## Recipients (`scripts/get-maintainers.sh`, the preflight's run)

- To: Marcel Holtmann `<marcel@holtmann.org>`, Luiz Augusto von Dentz `<luiz.dentz@gmail.com>`.
- Cc: `linux-bluetooth@vger.kernel.org`, `linux-kernel@vger.kernel.org`,
  `syzbot+f20755f37da70df33a16@syzkaller.appspotmail.com` (the bug's address, as usual for a
  syzbot fix).
- `get_maintainer.pl` also names Brian Gix `<brian.gix@intel.com>` (`blamed_fixes`); the address was
  not checked; the operator decides.
- **Not** Cc'd, by the operator's decision: the author of 14888791. Nothing goes to that thread.
- Send with `git send-email --suppress-cc=bodycc` or check the dry run: the `Cc: stable` tag is not a
  recipient.

## Evidence

- Root cause and comparisons: `../experiments/comparison-2026-10-29.md`.
- Tests and checks: `../experiments/results-2026-10-29.md`.

## Questions for the reviewers

1. Is the hand-over under `hdev->lock` complete: can any path still queue a second
   `mesh_send_sync()` for one `mgmt_mesh_tx`, or free one whose start is queued?
2. `mesh_next()` now completes every pending request whose start cannot be queued (power off),
   where the old code completed only the head. Keep, or keep the old behaviour and leave the rest
   pending?
3. `-ECANCELED` from `hci_cmd_sync_clear()` still completes the request without `hdev->lock` (as
   before). Acceptable for a stable fix, with a drain under the lock as later work?
4. Is the paragraph on the earlier proposal right in tone and length?
5. `Closes:` before syzbot has tested it: keep, or add it only after a `#syz test`?
