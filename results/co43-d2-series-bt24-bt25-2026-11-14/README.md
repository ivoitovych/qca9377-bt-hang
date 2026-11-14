# CO-43: D v2, the A + B2 + D series, and fixes for BT-24 and BT-25 (2026-11-14)

QEMU emulation only, as in `../co43-b2-and-runtime-d-2026-11-14/`. Copied from the work area
`/root/exp/agent-work/lane1-btusb-20261114/task2/`; the kernel tree stayed there (`lx/`,
branches `lane1-final`: the series; `lane1-ef`: E + the two fixes). Full write-up:
[`RESULTS.md`](RESULTS.md); `logs/SHA256SUMS` is relative to `logs/`.

- **D v2** queues its reset only while the device's runtime PM status is `RPM_RESUMING`, that
  is, inside a runtime resume. A system resume calls the driver before the core marks the device
  active (`usb_resume()`: `usb_resume_both()` at `drivers/usb/core/driver.c:1672`,
  `pm_runtime_set_active()` at `:1675`, at bluetooth-next `da3cc02587c6`), and a device already
  runtime-suspended at system sleep is skipped by `usb_suspend_both()` (`:1425-1427`), so v1's
  hole (such a device queued the reset at system resume) is closed **by reading**; the system path
  is still not testable on `vhci_hcd`. Runtime matrix 18/18, delayed-reset test 3/3. Open by
  reading: a runtime resume racing the system-resume callback after runtime PM is re-enabled.
- **The series** (`patches/series/`): cover letter, A, B2 (message reworded: the rebinding comes
  from btusb's reset or D, each queued command now times out separately, B2 needs D), D v2;
  checkpatch `--strict` only the missing Signed-off-by. **B2 does not apply on top of E** (both
  change `submit_or_queue_tx_urb()`); if E is merged first, B2 needs a rebase.
- **BT-25** (`patches/on-E/0002-…`): free the skb and setup packet at all four discard sites.
  kmemleak, E alone vs E + fixes, 3 runs each: failed resume with a deferred command 2, 1, 1 → 0,
  0, 0; submit failure in `play_deferred()` 1, 2, 0 → 0, 0, 0; dead device then close 4, 3, 2 →
  0, 0, 0; dead device then power-off 1, 1, 3 → 0, 0, 0; healthy 0 → 0.
- **BT-24** (`patches/on-E/0001-…`): drop the deferred URBs and clear `BTUSB_SUSPENDING` in one
  `txlock` section on a failed resume. Not reachable on E alone (the command credit returns only
  after `btusb_reset()`); on the B2 tree, unfixed: an URB left parked 3/3, fixed: none 3/3. The
  second command still fails (0x05) on both: the fix stops the parking, not the failure.

**Checked on copy (2026-11-14):** the leaked objects in the baseline runs are skbs allocated for
HCI commands (`e-kml-dbg-k-dead-1.log`: `__alloc_skb` ← `hci_cmd_sync_alloc` ←
`hci_update_class_sync`), which is what BT-25's fix frees; the fixed run of the same scenario
reports "0 unreferenced objects". The BT-24 pair: `deferred_anchor_after_failure=NOT empty` ×3
unfixed, `=empty` ×3 fixed (`logs/summary-bt24-b2tree.txt`). The two source lines D v2 rests on,
read at `da3cc02587c6`.

**Changed on copy:** `harness/metrics.py` given its executable bit; `harness/chain-bt24.sh` line
4, a wait on a session-temporary file, replaced by a comment saying what it waited for.
