# CO-43 three-patch series of 2026-11-23

This is the work order `../SERIES-PLAN-20261123.md`, carried out. It will replace `../send-20261113/E/` and
`../send-bt24-bt25-20261114/` once its tests are rerun. Until then those packages stay as they are.

**Base:** bluetooth-next `cf357cfc025e`, a public commit. The export has `base-commit:` set to it, and the
local-only `04b58d680611` is gone.

| # | patch | was | message changes |
|---|---|---|---|
| 1/3 | Free the skb of a deferred URB that is discarded | `send-bt24-bt25-20261114/0002` (BT-25) | Rebased to stand first: the resume failure path keeps its unlocked `failed:` label, and its scuttle becomes `btusb_discard_deferred()`. Only `Fixes: 7bee549e197c`; `19cfe912c37b` is named in prose as the 2017 repair that left the skb out. The lock sentence now reads "play_deferred() runs with txlock held and interrupts disabled". In this order that is the only locked site: the failure path's discard is unlocked until 3/3. The close argument was checked on the tip's `hci_sync.c`: `hci_dev_close_sync()` flushes `tx_work` and `rx_work` (l.6245–6246) and drains the workqueue (l.6287); `hci_dev_drop_last_cmd_req_and_close()` clears `HCI_RUNNING` (l.6049) before `hdev->close()` (l.6053). The message also names the driver-context direct send as a lockless edge whose worst case is a parked URB, as today. |
| 2/3 | Anchor a deferred URB under txlock | `send-20261113/E/0001` (E, BT-23) | Code and message unchanged. The consequence (reset, stale send) goes in only if the widened-window rerun shows it. |
| 3/3 | Drop deferred URBs under txlock on a failed resume | `send-bt24-bt25-20261114/0001` (BT-24) | "the waker … finds an active device" softened to: the sender anchors after the only point where this resume drops deferred URBs. It says it relies on 2/3. On top of 1/3 the locked section calls `btusb_discard_deferred()`, and the message says that it may run with interrupts disabled. |

**Cover:** "[PATCH 0/3] Bluetooth: btusb: Fix deferred URB leaks and races" (R3's title). The label "E" is gone.

**Checked 2026-11-23:**
- **Same code as before.** Applying the old three patches in the old order (E, BT-24, BT-25) on `cf357cfc025e`
  gives the same `btusb_main.c` as this series. The only difference is one comment word, "drop" for "scuttle",
  because the scuttle call is gone.
- **checkpatch:** `checkpatch.pl --strict --no-tree --no-signoff` on each patch gives 0 errors, and only the
  "unknown commit id" warning that `--no-tree` gives for `7bee549e197c`.
- **W=1 builds** of `drivers/bluetooth/` (tester config) at the base and after each patch: all succeed,
  `btusb_main.c` is compiled at each step, and no warning comes from it. The full bzImage of the series also
  builds. Script: `tmp/kernel-queue-20261123/build-co43-steps.sh` (machine-local).

**Still to do:**
1. **Reruns** on the new base and in the new order, and the multi-URB test of the plan. These are running.
2. **Testing text:** one testing sentence per patch below `---`, and the cover's testing paragraph.
3. **Recipients:** `get_maintainer.pl` on the final tree, with Oliver Neukum on Cc as the `Fixes:` author.
4. **Send day:** the operator's Signed-off-by, checkpatch, the bot checks and a dry run.
5. **Operator's call:** `Cc: stable` on 1/3, where the reviewers are split. There is none on 2/3 and 3/3.
6. **Laptop soak:** only on the operator's word.
