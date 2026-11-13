# BT-16, third occurrence — boot `680c448c`, 2026-11-13 10:41 (`7.0.0-43`, stock btusb)

Journal and file reads only; the controller was not touched. Each `.txt` here starts with the
command that produced it (`tmp/shutdown-20261113/bt16-third-excerpts.sh`); `SHA256SUMS` covers them.

**The sequence:**
- **10:35:16:** the operator's power-off (a normal `systemctl poweroff` of boot `46cc4812`).
- **10:36:47:** that boot's last entry. The installed trial closer ran into its 90 s stop timeout
  and was killed, so trial E3 #11 (opened 2026-11-12 22:55:12) got no results row
  (`shutdown-before-trial-unit.txt`).
- **About 4 min 46 s off.**
- **10:41:33, boot `680c448c` (`kernel-boot-680c448c.txt`):**
  - `usb 3-3` 13d3:3503 enumerated as device 2;
  - btusb ran the setup with **no `using rampatch file` and no `QCA: patch rome` line**;
  - `usb 3-3: USB disconnect, device number 2` at 10:41:33.939;
  - `Opcode 0x200f failed: -71` 2 ms later, during the disconnect;
  - re-enumerated as device 4; `using NVM file`, still no rampatch line;
  - `unexpected cc 0x202f length: 1 < 9`, `Opcode 0x202f failed: -38`.
- **bluetoothd** 10:41:46: `Number of controllers: 0` (`bluetoothd-boot-680c448c.txt`). Its HCI
  capture is 8,775 bytes (`capture-files.txt`). No Bluetooth for that boot.
- **10:42:26:** the operator's power-off from the desktop. That boot's trial opened as "E3 #11"
  again (the number of the trial that had lost its row) and closed with a 49 s row
  (`shutdown-of-680c448c-trial-unit.txt`).
- **11:24:15, boot `af3f9840` (the control):** the rampatch loaded (`patch rome 0x302 build
  0x3e8`), no disconnect (`kernel-boot-af3f9840-control.txt`).

**What is new against the first two occurrences:**
- the first on `7.0.0-43` with the **stock** btusb (`btusb-module.txt`: no module in `updates/`),
  so the out-of-tree E3 module is not a condition;
- an off-time of about 5 minutes. The 11-11 note found that 74 s, 4 min and 13 min off had not
  kept the patch; this one did, so the off-time does not decide it;
- a failure during the disconnect (`0x200f`, `-71`) instead of `0x2007` (11-05) or none (11-11);
- recovered by a power-off of about 41 minutes (10:42:48 to 11:24:15).

The raw capture of the boot stays local (`/var/log/bt-health/capture/hci-20261113-104137.btsnoop`,
archived to `archive/hci-capture/`); it holds the controller's address.
