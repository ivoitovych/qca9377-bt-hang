# Incident 2026-11-12 18:03 — HCI command timeout on patched firmware, controller off the USB bus (BT-17)

Recorded 2026-11-12 ~22:00 CET. Only journal, sysfs, package-database and capture-file reads were used. The controller, btusb, bluetooth.ko and bluetoothd were not touched. Addresses are omitted.

## Boots involved

`journalctl --list-boots --no-pager -n 6` (excerpt):

```
 -3 5e459fa0b07241279e8c525593afb2b8 Wed 2026-11-11 18:58:33 CET  Thu 2026-11-12 15:48:39 CET
 -2 7e87eae097cd4352b8963ddae2c4e3d4 Thu 2026-11-12 15:49:09 CET  Thu 2026-11-12 17:52:46 CET
 -1 0895606911384479be9cbd6a7f726000 Thu 2026-11-12 18:00:13 CET  Thu 2026-11-12 18:07:42 CET
  0 b314ca88f6a24949ae9e0ce1d624e820 Thu 2026-11-12 18:08:03 CET  Thu 2026-11-12 21:55:39 CET
```

- `7e87eae0` ended with a power-off: `systemd-logind: The system will power off now!` at 17:52:26.
  The machine was off about 7.5 min.
- `08956069` is the failing boot. It ended with a reboot (`The system will reboot now!` 18:07:21), not a power-off.
- `b314ca88` is the current boot, with no controller.

## The failing boot (`08956069`, `7.0.0-42` with E3)

Start-up was normal: the firmware patch loaded.

`journalctl -b -1 -k -g "13d3|btusb|QCA|…"`:

```
18:00:13 usb 3-3: New USB device found, idVendor=13d3, idProduct=3503, bcdDevice= 0.01
18:00:13 btusb: loading out-of-tree module taints kernel.
18:00:13 Bluetooth: hci0: using rampatch file: qca/rampatch_usb_00000302.bin
18:00:13 Bluetooth: hci0: QCA: patch rome 0x302 build 0x3e8, firmware rome 0x302 build 0x111
18:00:14 Bluetooth: hci0: using NVM file: qca/nvm_usb_00000302.bin
```

So this is **not BT-16**: the rampatch line is present and there was no start-up disconnect.

Initialization completed. The last HCI exchange before the failure was at 18:00:26.845.

`btmon -T --columns=200 -r tmp/incident-20261112-1803/captures/hci-20261112-180017.btsnoop`, lines in order:

```
< HCI Command: Write Extended Inquiry Response (0x03|0x0052) plen 241   #119 18:00:26.842657
> HCI Event: Command Complete (0x0e) plen 4                             #120 18:00:26.845565
= bluetoothd: Endpoint unregistered: sender=:1.38 path=/MediaEndpoint/A2DPSource/ldac   18:03:08.819688
  … (the greeter's audio session releases its endpoints)
@ MGMT Command: Remove UUID (0x0011) plen 16                                     18:03:08.826934
< HCI Command: Write Class of Device (0x03|0x0024) plen 3               #121 18:03:08.827012
  … no HCI event of any kind after #120 …
@ MGMT Event: Command Complete (0x0001) plen 6                                   18:03:10.868450
= bluetoothd: Failed to remove UUID: Authentication Failed (0x05)                18:03:10.868522
  (repeated at 18:03:12.92 and 18:03:14.96)
< HCI Command: Write Class of Device (0x03|0x0024) plen 3               #122 18:03:16.180812
= Close Index … 18:03:17.021440 / Delete Index 18:03:17.021450
```

- The controller was idle for **161.98 s** (18:00:26.845 → 18:03:08.827).
- No ACL or SCO link existed. The only device-related lines are profile states `disconnected -> unavailable`.
- The trigger was the user's login: a gdm session opened at 18:03:08.289. The greeter's PipeWire/WirePlumber session then exited, bluetoothd removed its profile UUIDs, and the kernel wrote the Class of Device.

What the kernel logged next. The first block is from `journalctl -b -1 _TRANSPORT=kernel -g "Resetting usb|Failed usb_autopm|tx timeout|Opcode 0x0c24 failed"`; the USB lines are from `-g "reset|usb 3-3|usb usb3|xhci"`:

```
18:03:10.869409 Bluetooth: hci0: command 0x0c24 tx timeout
18:03:10.869436 Bluetooth: hci0: Opcode 0x0c24 failed: -110
18:03:12.917800 Bluetooth: hci0: Opcode 0x0c24 failed: -110
18:03:14.120456 usb 3-3: reset full-speed USB device number 2 using xhci_hcd
18:03:14.240422 usb 3-3: device descriptor read/64, error -71
  … three more resets, "Device not responding to setup address", xhci "completion code 0x11" …
18:03:14.965410 Bluetooth: hci0: Opcode 0x0c24 failed: -110
18:03:16.181035 usb 3-3: device not accepting address 2, error -22
18:03:16.181629 usb 3-3: USB disconnect, device number 2
18:03:16.181854 Bluetooth: hci0: Failed usb_autopm_get_interface: -16
18:03:17.013432 Bluetooth: hci0: Opcode 0x0c24 failed: -110
18:03:17.134363 usb 3-3: new full-speed USB device number 4 using xhci_hcd
  … descriptor reads -71, "usb usb3-port3: attempt power cycle" 18:03:18.141380 …
18:03:19.461579 usb usb3-port3: unable to enumerate USB device
```

The trial tool's row for this boot (`evidence/trials/results.tsv`, E3 #9):

```
2026-11-12T18:07:42+01:00 … E3 PERTURBED:usb_reset:autosusp=Y,… 87e6e5b 9 v2 confirmed failed 424 0 ? 1 no no 1 …
```

That is: 1 timeout, USB lost, and a USB reset seen.

## The current boot (`b314ca88`): the controller is not on the bus

- `lsusb` lists no `13d3:3503`.
- `ls /sys/class/bluetooth` is empty.
- `/sys/module/btusb` is absent (btusb is not loaded).
- `journalctl -b 0 -k -g "usb 3-3"` shows `device descriptor read/64, error -71` four times at 18:08:03.
- The Wi-Fi function of the same card works (`ath10k_pci … firmware ver WLAN.TF.2.1-00021-QCARMSWP-1` at 18:08:04).

A warm reboot does not remove power from the controller. On this machine only a power-off has recovered it so far (BRIEF §0; BT-16 on 11-05 and 11-12; tonight 17:52).

## Where the USB reset comes from (source reading, Ubuntu `7.0.0-42`)

- `net/bluetooth/hci_core.c:1462-1481` (`hci_cmd_timeout()`): it logs `command 0x%4.4x tx timeout`, cancels the sync command with `ETIMEDOUT`, and then calls `hdev->reset(hdev)` **on the first timeout**.
- `drivers/bluetooth/btusb.c:4402-4408`: for `BTUSB_QCA_ROME`, the flag that `dc16388d45ec` gives 13d3:3503, it sets `hdev->reset = btusb_qca_reset`.
- `btusb_qca_reset()` (`btusb.c:1175-1207`): without a reset GPIO it calls `btusb_reset()` (`btusb.c:1034-1051`). That function calls `usb_autopm_get_interface()`; on failure it logs `Failed usb_autopm_get_interface: %d`, otherwise `Resetting usb device.`, and then `usb_queue_reset_device()`.
- Tonight's `Failed usb_autopm_get_interface: -16` (18:03:16.18) shows that this path was entered at least once, at a time when the device was already failing to re-address.
- **Not established:** what issued the first USB reset at 18:03:14.12. `Resetting usb device.` appears nowhere in the boot's journal, and no "suppressed" or "missed" kernel-message line was found for 18:03:08–20.
- Before the entry (ROM firmware, stock btusb) the generic btusb path had no `hdev->reset`. BRIEF §0 records two controlled tests in which a USB reset drove a wedged controller off the bus (`EX-023`, the 2026-08-15 boot).

## History: first HCI timeout with the patch loaded

`evidence/trials/results.tsv`:
- E3 rows #1–#8 (2026-10-18 to 2026-11-12 17:52) all have `timeouts 0`.
- Every earlier row with timeouts > 0 is `build stock` (ROM firmware, BT-1).
- Row #9 is the first E3 row with a timeout.
- BRIEF §0: E1 and E3 ran 74 links with 0 timeouts.

## Side findings

- **mgmt status for a timeout.** The kernel answered the timed-out `Remove UUID` with mgmt status `0x05` ("Authentication Failed"), and bluetoothd logged that text. This is the kernel's errno-to-mgmt mapping for `-ETIMEDOUT`, a misleading status for a timeout. The mapping has not yet been read in source; it is a candidate, not a defect row.
- **Trial tool `usb_lost` counts every USB disconnect, not the controller's.** E3 #6 (boot `e68d6d90`, 11-11) has `usb_lost 82`. `journalctl -b -4 _TRANSPORT=kernel -g "usb 3-3|USB disconnect"` shows only ports `3-2` and `4-2` (another device plugged and unplugged), and none on `3-3`.
- **The raw-capture archive timer is not running.** `systemctl list-timers --all bt-trace-archive.timer` gives `0 timers listed`. The four capture files of boots `08956069` and `b314ca88` were therefore copied by hand (with `cp -p`) to `tmp/incident-20261112-1803/captures/`. That location is local only: the captures carry addresses.

## Committed excerpts (this directory)

Each file starts with the exact command that produced it. Addresses are replaced by `<addr>` and dynamic-debug noise is dropped. The files were written by `tools/excerpts.py`.

| File | What |
|---|---|
| `excerpt-boot-1-kernel-controller.txt` | Failing boot, whole kernel log for the controller, USB port 3-3, xhci, rfkill |
| `excerpt-boot-1-kernel-last-good-window.txt` | 18:00:26.84–.85, the last answered commands |
| `excerpt-boot-1-kernel-failure-window.txt` | 18:03:08.8–18:03:20, the timeout, resets and disconnect, with debug lines |
| `excerpt-boot-1-userspace-trigger.txt` | The login, bluetoothd's mgmt commands and failures, the adapter's removal |
| `excerpt-boot-1-hci-capture-decode.txt` | `btmon` decode from frame #119 to `Delete Index` |
| `excerpt-boot-2-end.txt`, `excerpt-boot-1-end.txt` | How the two earlier boots ended (power-off 17:52, reboot 18:07) |
| `excerpt-boot0-kernel-no-controller.txt` | Current boot: port 3-3 does not enumerate; Wi-Fi up |
| `excerpt-boot-1-btusb-suspend-cycles.txt` | Failing boot: device-level runtime suspends and resumes from btusb's debug prints. The last suspend, at 18:00:28.857, is never followed by a resume (added 2026-11-13) |
| `excerpt-boot-2-btusb-suspend-cycles.txt` | The boot before: 8 completed suspend/resume cycles, the longest 4,250 s (added 2026-11-13) |
| `excerpt-port-3-3-resets-system-journal.txt` | Every reset, power cycle and disconnect of port 3-3 in the system journal (2026-10-22 11:32 to 11-13): the only resets are BT-17's; the two disconnects are the BT-16 start-ups (added 2026-11-13) |
| `excerpt-port-3-3-resets-journal-archive.txt` | The same search over the 76 archived boots (08-12 to 11-12): earlier reset sequences only on ROM firmware (08-12 to 08-16, 09-24), with a different spacing; none between 09-24 04:04 and BT-17 (added 2026-11-13) |

The two suspend-cycle files are the output of `python3 -I tools/suspend-cycles.py <boot>-kernel.txt`, run on the archived full kernel logs (below). The script's header gives the classification rules.

## Full logs (local, git-ignored)

Path: `archive/incidents/20261112-bt17-controller-off-bus/`, about 8 MB, written by `tools/collect.sh` (2026-11-12 22:44), with `SHA256SUMS`. It holds:

- `journal/`: for boots `7e87eae0` (before), `08956069` (failing) and `b314ca88` (current), the whole journal, the kernel-only log and the bluetooth unit log (`short-precise`), plus `-o export` (`.zst`, every field, for later filtering).
- `captures/`: every HCI capture of both capture paths since 11-12 15:48 (`.zst`).
- `machine/`: lsusb, the sysfs state of USB port 3 and of rfkill, kernels and packages, `apt-history.log`, the disabled btusb/udev configs, the unit file, timers, the btusb Kconfig and `results.tsv`.

It is not committed: it carries addresses and full session logs.

## Not done (needs the operator)

- Recovery by a full power-off.
- The installed kernel default is now `7.0.0-43`. It was installed by the updater at 21:48:14 (`/var/log/apt/history.log`), and its stock btusb carries the entry:
  - `scripts/btusb-has-device.py /lib/modules/7.0.0-43-generic/kernel/drivers/bluetooth/btusb.ko.zst` → `FOUND 13d3:3503 x1`;
  - control `0cf3 e300` → `FOUND 0cf3:e300 x1`.
