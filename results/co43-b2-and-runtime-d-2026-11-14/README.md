# CO-43: B2 and a runtime-only D, on a fixed harness (2026-11-14)

QEMU emulation only (real btusb on bluetooth-next, an emulated `13d3:3503` through usbip;
KASAN, lockdep). Nothing ran on the laptop. Copied from the work area
`/root/exp/agent-work/lane1-btusb-20261114/task1/`; the kernel tree and images stayed there
(`lx/`, branches `lane1-ab2`, `lane1-ab2d-dbg`, `lane1-ab2dn-dbg`). The full write-up is
[`RESULTS.md`](RESULTS.md); `logs/SHA256SUMS` is relative to `logs/`.

**In short:**
- **The harness** now recovers the device on a reset (not on unlink), judges recovery by a
  command round trip, and fails the run on any failed case; each fix was broken and seen to give
  the wrong verdict, then restored (`RESULTS.md` §1).
- **B2** ("Don't wait for a resume in the HCI command timeout", `patches/0002-…`) removes BT-19's
  workqueue block (5.380 s on the unpatched kernel's dead device, `base-a-dead-1`; 0.002 s with
  B2) and, unlike B, keeps the reset a wedged-but-awake controller needs (`dropcmd-wedge` 3/3).
  **Alone it loses the recovering device** (0/3): the unpatched kernel recovers it only through
  BT-19's second reset. So B2 goes with D, or with a USB core answer to BT-18.
- **D, narrowed** (`patches/0003-…Recover-after-a-runtime-reset-resume`): the reset is queued
  only after a runtime suspend and holds a PM reference. Runtime path 18/18 (six scenarios × 3).
  With a debug-only 3 s delay on the queued reset, the earlier wide D lost the reset 3/3 (one USB
  reset, no rebinding) and the narrowed D got it 3/3 (two resets, rebinding).
- **Not shown:** the system-suspend path (`vhci_hcd` refuses system suspend with a device
  attached). From the source, a device already runtime-suspended at system sleep keeps the
  "auto" flag, so its reset-resume at system resume would still queue the reset: the narrowed D
  does not yet leave the system path unchanged (`RESULTS.md` §3).

**Checked on copy (2026-11-14):** the delayed-reset pair in the raw logs. `ab2d-dbg-d-delay-1`:
one `reset … USB device` line, `hci0_removed=False`, `FAIL bt17`; `ab2dn-dbg-d-delay-1`: two,
`hci0_removed=True`, `PASS bt17`. In the wide-D run the final class write still returned `0x00`:
Bluetooth worked, but without the reset and rebinding D is meant to give, which is what the run
judges (`--expect-rebind`).

**Changed on copy:** `harness/metrics.py` given its executable bit (it has a shebang; the work
area had it 0644, and the suite requires the bit). Nothing else in the folder differs from the
work area.
