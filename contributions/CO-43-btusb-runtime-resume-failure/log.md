# CO-43 log

## 2026-11-13 — the emulation, the defects, the five candidates (operator away; nothing sent)

1. **Harness.** `results/bt17-emulation-2026-11-13/harness/`.
   - The CO-21 usbip emulator, extended into `bt17-emu.py`: 13d3:3503 identity, the QCA vendor
     requests, suspend/resume accounting, a fault at a chosen resume.
   - Guest kernel: bluetooth-next `da3cc0258`, `CONFIG_BT_HCIBTUSB_AUTOSUSPEND=y`.
2. **Reproduction** (`results/bt17-emulation-2026-11-13/logs/runs/base-bt17-2.log`). The laptop's kernel sequence, step by step. The
   added USB core debug shows `usb auto-resume` (host-initiated), `finish resume`, `retry with
   reset-resume`, four resets, `gone after usb resume? status -19`, then the disconnect.
3. **BT-19 seen** (`base-recover-1`). With a device that answers again after the reset-resume,
   the blocked `btusb_reset()` printed `Resetting usb device.` after the rebinding and reset it
   a second time.
4. **First B** (skip whenever `BTUSB_SUSPENDING`): fixed the stall, but in `recover` left btusb
   stale. The rebinding on the unpatched kernel came only from that second reset. Found BT-18:
   the USB core never rebinds after a runtime reset-resume.
5. **BT-18 confirmed on the unpatched kernel** (`base-close-recover-1`). With the resume started by
   a power-off, power-on fails: HCI Reset `-110`, never sent.
6. **B refined** (skip only while the interface is not runtime-active). **D written** (a
   `reset_resume` that resumes and queues a reset).
7. **Matrices**, 5 rounds × 3 fault scenarios + 50 cycles, base and A+B+D, with KASAN and
   lockdep: no kernel reports; numbers in the results README.
8. **C on a guest with the host's CPU** (`-cpu host`, "AMD Ryzen 7 5825U"): the device no longer
   autosuspends with hci0 up.
9. **D's system-resume path is not testable here.** `vhci_hcd` refuses system suspend with a
   device attached (`platform_pm_suspend returns -16`).
10. **BT-23 reproduced** with a debug-only 400 ms delay and a forced resume: unpatched 3/3
    parked, E 2/2 answered. **E written.**
11. **Final series** A, B, D, E, C on branch `bt17-final` of the worktree; exported to `patch/`.
