# CO-04's message and the lockdep cycle at unregister

**Question:** is the cycle CO-04's to fix, and should CO-04's message name it?

**What is measured / quoted / inferred**

- **Quoted (the other lane's log, read only):** on the tip `da3cc02587c6` (kernel `7.3.0-gda3cc02587c6`),
  `/root/exp/agent-work/lane3-mgmt-20261114/mesh-logs/UnregSweep-plain-17.log` lines 751-790, also `-plain-28`:
  ```
  WARNING: possible circular locking dependency detected
  mesh-tester-gat/60 is trying to acquire lock:
  (&hdev->unregister_lock){+.+.}-{4:4}, at: hci_cmd_sync_submit+0x36/0x2b0
  but task is already holding lock:
  (&hdev->cmd_sync_work_lock){+.+.}-{4:4}, at: hci_cmd_sync_clear+0xdc/0x360
  -> #1 (&hdev->cmd_sync_work_lock): hci_cmd_sync_submit+0x130/0x2b0, set_powered+0x42d/0x4d0, hci_sock_sendmsg
  -> #0 (&hdev->unregister_lock): hci_cmd_sync_submit+0x36/0x2b0, mesh_next+0x84/0x130,
       hci_cmd_sync_clear+0x184/0x360, hci_unregister_dev+0x1ff/0x540, vhci_release+0x18b/0x240
  ```
  Their counts (`CO-04/circular-count.txt`): `UnregSweep` plain 2 of 35 boots (the mesh_next/unregister_lock chain
  in both), CO-04 0 of 35, CO-05 2 of 35, CO-04 + CO-05 0 of 35; the other sets 0 on every image.
- **Measured (my runs, `logs/summary-*.txt`, `harness/summarize.py`):** on the tip and on tip + CO-04, **0
  lockdep cycles in 60 boots each** (backlog 10 boots, 4 + 3 controllers each; a fine sweep of the removal time
  around the end of a transmission, 10 boots of 12 controllers, offsets 470 to 534 ms in 1 ms steps; a controller
  that stops answering and is then removed, 10 boots of 6). So my natural-timing runs did not hit it. They are not
  evidence that it is absent from the tip: the other lane's two hits are.
- **Inferred from the source (why it is rare):** the cycle needs `hci_cmd_sync_clear()` (`hci_sync.c:675`) to
  find a queued `mesh_send_done_sync` entry on `cmd_sync_work_list` and call its destroy callback, `mesh_next()`
  (`mgmt.c:1137-1145` at the tip: `hci_cmd_sync_queue(hdev, mesh_send_done_sync, NULL, mesh_next)`), which calls
  `hci_cmd_sync_queue()` and so takes `unregister_lock` under `cmd_sync_work_lock`; the opposite order is
  `hci_cmd_sync_submit()` (`:734`, `:749`). `hci_cmd_sync_clear()` first cancels the pending request and then
  `cancel_work_sync(&hdev->cmd_sync_work)` (`:680-681`): a running work item finishes the queue, so an entry is
  left for the list walk only when the work item is still *pending* (queued, not started) at that moment. A
  stuck controller does not do that (my third scenario).

**CO-04 removes it:** CO-04 gives `mesh_send_done_sync()` no destroy callback (its message says "hci_cmd_sync_clear()
no longer calls hci_cmd_sync_queue() through mesh_next() at unregister"), so the only path to
`hci_cmd_sync_queue()` from `hci_cmd_sync_clear()` is gone: 0 of 35 in the other lane's sweep against 2 of 35 on
the tip.

**Should CO-04's message name it?** Yes, in one short paragraph. Today the message names the inversion only for
the earlier proposal (which introduced it), and reads as if the tip had none; the tip has one, at unregister, with
the same two locks, and CO-04 happens to remove it. A maintainer reading "hdev->lock is not taken under
cmd_sync_work_lock" would otherwise not learn that the unchanged base already reports a cycle. Suggested wording
(no review history, facts only):

> The base also has a lock order inversion of its own, reported by lockdep when a controller is removed while a
> mesh transmission has just ended: hci_cmd_sync_clear() holds cmd_sync_work_lock and calls mesh_next() as the
> destroy callback of mesh_send_done_sync(), which takes unregister_lock in hci_cmd_sync_submit(), the order
> hci_cmd_sync_submit() takes them in the other way. With no destroy callback on mesh_send_done_sync() the
> removal path no longer queues commands.

Not for the Fixes: line: the destroy callback and `unregister_lock` come from different commits
(`b338d91703fa` for mesh, the lock from the later removal rework); the UAF's `Fixes:` stays as it is. I did not
look up the lock's commit.
