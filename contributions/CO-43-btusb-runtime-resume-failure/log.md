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

## 2026-11-13 evening — E and A as separate send packages (nothing sent)

After the outside reviews (README, "Open before any send", item 5: E and A to send alone),
E and A were rebuilt as two single-patch packages on bluetooth-next `da3cc02587c6`
(`send-20261113/E/`, `send-20261113/A/`). E's message is limited to the successful-resume race;
A's subject now says "runtime resume". Each `CHECKS.md` records: each applies and builds alone
and with the other in either order, on bluetooth-next and bluetooth; the list bot's checks run
locally (only the Signed-off-by checks fail, for the missing line); E's stress test, 10 × 100
cycles on the unpatched and the E kernel with KASAN, lockdep and kmemleak, no report and no
parked packet, and with the debug delay parked packets only without E. Evidence copied into
`send-20261113/evidence/` on 11-14.

## 2026-11-14 — the dry runs

`git send-email --dry-run` for both, from the project checkout
(`send-20261113/dry-run-20261114/`): `Result: OK`; E six recipients (Oliver Neukum among them),
A five, as listed in each `send-commands.txt`. Still open: B (blocked by its counterexample) and
D (not as a fix); a lane is working on the harness fixes, B2 and a narrowed D (`../rd-2026-11-14.md`).

## 2026-11-14 — prior art corrected; the BT-18 question ported

- `prior-art-2026-11-13.md` §2: Poulain's rebind v2 exists (msg39123, 2014-03-11) and Alan Stern
  approved its approach ("This patch looks okay now.", msg39141); §4: Sean Rhodes's August
  rewrite and his 2026-09-17 "restore powered-off Intel adapters" v2 are one series, and the v2
  adds a `btusb_reset_resume()` that leaves BT-18 unchanged for this device but would conflict
  with D. All three pages fetched and checked today.
- The linux-usb question (11-13) is in `drafts/bt18-linux-usb-question-20261113/`. Its lore links
  were broken (lore answers "not found" for both 2014 Message-IDs); they now point at
  mail-archive.com, whose pages carry those Message-IDs.
