# The two "HANG" trial verdicts of 10-30 and 11-06 — check of 2026-11-07

Journal, file and source reads only; nothing sent to the controller.

## Trial E3 #4 (boot 7323fc85, 2026-11-05 19:33:05 → 11-06 15:47:16)

1. The closer's "controller does NOT respond" (15:46:58) came **after** `bluetoothd` ran
   `adapter_shutdown()` and `bluetooth.service` stopped (15:46:57), so by itself it proves nothing:
   the probe is `hciconfig hci0 name` (`/usr/local/bin/bt-trial:111-123`).
   `journalctl -b -1 -o short-iso --since "2026-11-06 15:44:30" --until "2026-11-06 15:47:20" --grep ...`
2. But the boot had no working Bluetooth from the start:
   - its HCI capture `/var/log/bt-health/capture/hci-20261105-193308.btsnoop` is 11,599 bytes for
     ~20 h (other boots: 64 MB per 15–20 min);
   - `btmon -t -r <it>`: `New Index … hci0` 19:33:08.500; bluetoothd's
     `Read Controller Index List` at 19:33:17.681 → **`Controllers: 0`**; then only an
     `hciconfig` RAW open/close at 19:38:16; nothing else to the end.
3. Kernel, that boot (`journalctl -b -1 -k --since "2026-11-05 19:33:00" --until "2026-11-05 19:34:00"`):
   no `using rampatch file` / `QCA: patch rome` line; `HCI Enhanced Setup … advertised, but not
   supported`; `unexpected cc 0x2007 length: 1 < 2`; `Opcode 0x2007 failed: -38`;
   **`usb 3-3: USB disconnect, device number 2`**; re-enumerated as device 4; `using NVM file:
   qca/nvm_usb_00000302.bin` (still no rampatch line); `unexpected cc 0x202f length: 1 < 9`;
   `Opcode 0x202f failed: -38`.
   Healthy boot for comparison (`-b 0`, 2026-11-06 15:51:22): `using rampatch file:
   qca/rampatch_usb_00000302.bin`, `QCA: patch rome 0x302 build 0x3e8, firmware rome 0x302 build
   0x111`, `using NVM file`, no disconnect, no failed opcode.
4. Source (`cache/ubuntu-7.0.0-42/drivers/bluetooth/btusb.c:3745-3790`, `btusb_setup_qca`): the
   rampatch is loaded only if the controller's `QCA_CHECK_STATUS` lacks `QCA_PATCH_UPDATED`
   (`:3783`); the NVM only if it lacks `QCA_SYSCFG_UPDATED`. So in the failing boot the controller
   reported **the patch already present** at both enumerations, and the NVM absent at the second.
   The previous shutdown was a power-off (`prev_shutdown poweroff`).
5. The end of the boot: GNOME Settings' Bluetooth panel opened 15:45:46; `gsd-rfkill` sent
   "change all" events and the kernel logged 19 `name hci0 blocked 0` between 15:45:49 and
   15:46:14; the panel reopened 15:46:11; power-off requested 15:46:57. Consistent with the
   operator trying to switch Bluetooth on and getting nothing (not confirmed with the operator).

## Every boot since 10-22 (`boot-setup-scan.sh -7 … 0`, journal only)

`using rampatch file` + `QCA: patch rome 0x302 build 0x3e8, firmware rome 0x302 build 0x111` at
boots -6 (10-23), -5 (10-30 04:31), -4 (10-30 19:22), -3 (10-30 20:05), -2 (10-31 21:23) and 0
(11-06 15:51), with no disconnect and no failed opcode; boot -7 has no kernel entries in the
journal any more. **Only boot -1 (11-05 19:33) shows the failure.** The boot before it ended
with a clean power-off (11-04 13:53:31, "The system will power off now!"); the machine was off
about 30 hours.

## Trial E3 #3 (boot 46cb5188, 10-30 19:22 → 19:52): the verdict is an artefact

`journalctl -b -4 -u bt-trial-auto -u bluetooth --since "2026-10-30 19:50:00"`: A2DP was
suspended and released normally at 19:50:58 (the controller answering); power-off 19:51:44;
`adapter_shutdown()` and `bluetooth.service` stopped 19:51:44; the closer's probe 19:51:45 →
"controller does NOT respond" → "HANG after 1752s". The rampatch had loaded at boot.

## Why both verdicts say HANG

The **installed** `/usr/local/bin/bt-trial` still probes with `hciconfig hci0 name` at
`autostop`, and the installed unit orders it `Before=bluetooth.service`, so at shutdown it is
stopped *after* bluetoothd, which has powered the adapter off: the probe cannot succeed. The
repository's closer has been passive since 2026-09-19 (journal: an HCI command timeout since the
trial opened → hang; nothing sent; `systemd/bt-trial-auto.service` comment), and its
`tools/lib/trial-summary.awk:95` knows `ended_unprobed`, whose absence in the installed summary
made both reports fail ("unrecognised trial_result \"ended_unprobed\" on line 16"). The
installed tools are 29 files behind (`devtools/check`, 11-07); STATUS has warned of this since
10-18. Under the passive closer trial 3 would be `ended_unprobed` (no timeout). So would trial 4:
**neither closer notices a boot in which the adapter never became available.**

## Conclusions

- E3 #3: not a hang. E3 #4: not a hang either, but a real failure of another kind: the
  controller came up reporting its patch already loaded, failed two LE commands, dropped off USB
  once, and bluetoothd had no usable adapter for the whole boot (registered as BT-16).
- One boot in seven since 10-23. Not seen before in this project's records as far as checked
  here (not searched beyond these boots).

## Open

- Why a controller reports `QCA_PATCH_UPDATED` after ~30 h powered off: standby power through
  S5 keeping the chip's RAM, or a wrong status read. Not established.
- The trial tools on the machine are the old ones: deploying the current ones is the operator's
  word (`install.sh --tools-only`, then `bt-mode status`, `docs/install.md`).
- What the controller's state was: a patch "present" after a power-off suggests the chip kept
  power through S5 (USB standby power), or a status read wrongly. Not established.
- Not a SCO-path event: no SCO link in either trial.
