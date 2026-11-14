# BT-17 emulation and patch candidates (2026-11-13, operator away about 4 h)

Everything runs in QEMU guests; nothing touches the laptop's Bluetooth; nothing is sent.

1. Reproducer: real btusb (bluetooth-next da3cc0258) in a guest, bound through usbip to
   scripts/bt17-emu.py, an emulated 13d3:3503 (QCA ROME path, full speed, bcdUSB 1.10,
   remote wakeup). Fault: at resume N the device holds GET_STATUS (a NAKing device); after
   the host gives up, every control transfer fails -71 (as the laptop after its first reset).
   Trigger: MGMT Set Device Class after the device autosuspended (the laptop's Write Class
   of Device). USB core dyndbg on, which the laptop lacked.
2. Baselines: healthy suspend/resume cycles; a recoverable device (works again after reset).
3. Patch candidates (bluetooth-next), each run against the reproducer and the baselines:
   a. btusb: btusb_waker() reports a failed autoresume (today silent);
   b. btusb: btusb_reset() does not block the ordered HCI workqueue behind a resume;
   c. btusb: 13d3:3503 on a Ryzen root hub sets BTUSB_WAKEUP_BROKEN (mitigation, H3);
   d. MGMT: -ETIMEDOUT -> MGMT_STATUS_TIMEOUT (a separate worker, bt17-mgmt-timeout/).
4. A provoking script for the laptop (reviewer 6's step 6), written, not run.
5. Registers: issues.md / STATUS rows for the new defects, a CO dossier; commit and push.
