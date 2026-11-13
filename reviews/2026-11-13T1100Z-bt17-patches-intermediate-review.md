# Intermediate review: btusb resume-failure patches (CO-43) and the MGMT timeout status (CO-44)

**Date:** 2026-11-13. **State:** patch candidates, tested in emulation, **not sent anywhere**.
**Base:** bluetooth-next `da3cc0258` ("Bluetooth: hci_vhci: Report write readiness with queued
input", 2026-11-12) for the kernel; BlueZ master `20ffd285b` for the test.

This document is meant to be complete on its own. Everything a reviewer needs is in it: the
incident, the defects, every patch in full, the unpatched code they change, the emulator that
tested them, the results and the logs. Nothing has to be fetched. The project's repository is
<https://github.com/ivoitovych/qca9377-bt-hang>; paths below are relative to it.

## 1. What we ask of you

Please review the seven patches in section 5 for **correctness first**: locking, runtime PM and
USB core semantics, races, and paths we did not test. Then judge whether each one is ready for
the linux-bluetooth list, and whether the series order and split are right. Specific questions:

1. **Patch 2 (B), `btusb_reset()`:** the skip condition is `test_bit(BTUSB_SUSPENDING) &&
   !pm_runtime_active(&intf->dev)`.
   - Is reading the runtime PM status without the PM lock sound here (the HCI workqueue,
     racing with the USB core's resume)?
   - Which states can pass the check and still block in `usb_autopm_get_interface()`?
   - Is "a reset-resumed device whose interface is active although `btusb_resume()` never ran"
     the only case where the old reset is still wanted?
   - Known wording issue: the message's last line says "while BTUSB_SUSPENDING is set". The
     code also requires the interface not to be runtime-active. The line will be corrected
     before any send.
2. **Patch 3 (D), `btusb_reset_resume()`:** it calls `btusb_resume()` and then
   `usb_queue_reset_device()` on the primary interface, so the core unbinds and rebinds btusb.
   - Is queueing a reset from inside a reset-resume callback safe, for runtime and system
     resume? Think of the core's `usb_lock_device_for_reset()`, the interface's `needs_binding`
     state, and a disconnect racing the queued work.
   - **Its known cost:** at a **system** resume, the devices that were already reset-resumed and
     rebound get one more USB reset. That covers `btusb_needs_reset_resume_table` and every
     Realtek device with wakeup disabled (`btusb_suspend()` sets `reset_resume` for them). We
     could not test system suspend in emulation (section 7).
   - Would you rather queue the reset only for a runtime resume? Or is the right fix in the USB
     core instead (rebinding marked interfaces after a runtime resume too)?
3. **Patch 1 (A), `btusb_waker()`:** it logs a failed resume except `-EACCES` (runtime PM
   disabled during a system sleep transition). Is that the right exception, and is the log
   level right?
4. **Patch 4 (E), `submit_or_queue_tx_urb()`:** it anchors the deferred URB inside the `txlock`
   section instead of after it.
   - Is calling `usb_anchor_urb()` under `spin_lock_irqsave(&data->txlock)` acceptable?
   - Does `btusb_resume()`'s `play_deferred()` path still see every URB exactly once?
5. **Patch 5 (C), RFC:** it disables runtime suspend of `13d3:3503` on Ryzen when it hangs
   directly off a root hub, with the condition of `dcaf83ead130` (MT7922/MT7925).
   - It rests on one occurrence. Is it justified to post as an RFC, or only after a
     recurrence with USB core debug?
6. **CO-44, the MGMT patch:** `mgmt_errno_status()` maps `-ETIMEDOUT` to `MGMT_STATUS_AUTH_FAILED`.
   - Do you know of any user-space code, BlueZ or other, that relies on 0x05 for a timed-out
     command?
   - Is `Fixes: 161510ccf91c` the right tag, and should it go to stable?
7. **The tests:** which failure path did we miss?
   - Where does the emulator (section 8) differ from a real QCA ROME on an AMD xHCI in ways that
     matter for these patches?

Please mark each finding with its patch number and a severity: blocker, should-fix or nit.
Where you can, also say whether you checked it against the source or are reasoning from the
text.

## 2. The incident in brief (BT-17)

- **The machine:** a laptop with a Qualcomm QCA9377 Bluetooth controller, USB ID `13d3:3503`
  (IMC Networks), on the AMD xHCI of a Ryzen 7 5825U.
- **The kernels:** Ubuntu `7.0.0-42`, with btusb built with `CONFIG_BT_HCIBTUSB_AUTOSUSPEND=y`.
  The device's entry gives it `BTUSB_QCA_ROME`, so `hdev->reset` is `btusb_qca_reset()`.
- **The sequence, 2026-11-12:**
  1. 18:00:28: the idle controller was runtime-suspended.
  2. 18:03, at the user's desktop login: the kernel's Write Class of Device (`0x0c24`) got no
     answer, and `command 0x0c24 tx timeout` followed.
  3. Five seconds later: USB resets of the port. They failed with `-71`, and the device left
     the bus.
  4. It stayed off through a reboot and came back only after a power-off.
  5. bluetoothd logged "Authentication Failed (0x05)" for MGMT commands that had simply timed
     out.
- **Outside reviews of the source** (five, recorded in the repository) agreed:
  - the first USB reset came from the USB core's reset-resume, after a 5 s GET_STATUS timeout
    in `finish_port_resume()`;
  - btusb's own reset (`btusb_reset()` from `hci_cmd_timeout()`) blocked behind that resume
    and never ran.
- **An emulation reproduced this kernel sequence step by step** (section 7). Real btusb in a
  QEMU guest drove an emulated `13d3:3503` that stops answering at a resume.
- **Not addressed here:** why the chip stopped answering (firmware, platform power or the AMD
  host). No patch here claims to fix that.

The incident's own evidence (excerpts of the laptop's kernel log, with every command used) is
in section 3.

## 3.–10. Contents

3. The incident's evidence (laptop)
4. The defects (the issue register's entries BT-17 to BT-23)
5. The patches, in full
6. The unpatched code they change (bluetooth-next `da3cc0258`)
7. The emulation: method, results and the matrix summaries
8. The emulator and harness source, in full
9. Representative test logs (kernel lines)
10. The dossiers (CO-43, CO-44): state, CI results and open items

## 3. The incident's evidence (laptop, 2026-11-12)
*(verbatim: `results/incident-2026-11-12-1803/README.md`)*
### Incident 2026-11-12 18:03 — HCI command timeout on patched firmware, controller off the USB bus (BT-17)

Recorded 2026-11-12 ~22:00 CET. Only journal, sysfs, package-database and capture-file reads were used. The controller, btusb, bluetooth.ko and bluetoothd were not touched. Addresses are omitted.

#### Boots involved

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

#### The failing boot (`08956069`, `7.0.0-42` with E3)

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

#### The current boot (`b314ca88`): the controller is not on the bus

- `lsusb` lists no `13d3:3503`.
- `ls /sys/class/bluetooth` is empty.
- `/sys/module/btusb` is absent (btusb is not loaded).
- `journalctl -b 0 -k -g "usb 3-3"` shows `device descriptor read/64, error -71` four times at 18:08:03.
- The Wi-Fi function of the same card works (`ath10k_pci … firmware ver WLAN.TF.2.1-00021-QCARMSWP-1` at 18:08:04).

A warm reboot does not remove power from the controller. On this machine only a power-off has recovered it so far (BRIEF §0; BT-16 on 11-05 and 11-12; tonight 17:52).

#### Where the USB reset comes from (source reading, Ubuntu `7.0.0-42`)

- `net/bluetooth/hci_core.c:1462-1481` (`hci_cmd_timeout()`): it logs `command 0x%4.4x tx timeout`, cancels the sync command with `ETIMEDOUT`, and then calls `hdev->reset(hdev)` **on the first timeout**.
- `drivers/bluetooth/btusb.c:4402-4408`: for `BTUSB_QCA_ROME`, the flag that `dc16388d45ec` gives 13d3:3503, it sets `hdev->reset = btusb_qca_reset`.
- `btusb_qca_reset()` (`btusb.c:1175-1207`): without a reset GPIO it calls `btusb_reset()` (`btusb.c:1034-1051`). That function calls `usb_autopm_get_interface()`; on failure it logs `Failed usb_autopm_get_interface: %d`, otherwise `Resetting usb device.`, and then `usb_queue_reset_device()`.
- Tonight's `Failed usb_autopm_get_interface: -16` (18:03:16.18) shows that this path was entered at least once, at a time when the device was already failing to re-address.
- **Not established:** what issued the first USB reset at 18:03:14.12. `Resetting usb device.` appears nowhere in the boot's journal, and no "suppressed" or "missed" kernel-message line was found for 18:03:08–20.
- Before the entry (ROM firmware, stock btusb) the generic btusb path had no `hdev->reset`. BRIEF §0 records two controlled tests in which a USB reset drove a wedged controller off the bus (`EX-023`, the 2026-08-15 boot).

#### History: first HCI timeout with the patch loaded

`evidence/trials/results.tsv`:
- E3 rows #1–#8 (2026-10-18 to 2026-11-12 17:52) all have `timeouts 0`.
- Every earlier row with timeouts > 0 is `build stock` (ROM firmware, BT-1).
- Row #9 is the first E3 row with a timeout.
- BRIEF §0: E1 and E3 ran 74 links with 0 timeouts.

#### Side findings

- **mgmt status for a timeout.** The kernel answered the timed-out `Remove UUID` with mgmt status `0x05` ("Authentication Failed"), and bluetoothd logged that text. This is the kernel's errno-to-mgmt mapping for `-ETIMEDOUT`, a misleading status for a timeout. The mapping has not yet been read in source; it is a candidate, not a defect row.
- **Trial tool `usb_lost` counts every USB disconnect, not the controller's.** E3 #6 (boot `e68d6d90`, 11-11) has `usb_lost 82`. `journalctl -b -4 _TRANSPORT=kernel -g "usb 3-3|USB disconnect"` shows only ports `3-2` and `4-2` (another device plugged and unplugged), and none on `3-3`.
- **The raw-capture archive timer is not running.** `systemctl list-timers --all bt-trace-archive.timer` gives `0 timers listed`. The four capture files of boots `08956069` and `b314ca88` were therefore copied by hand (with `cp -p`) to `tmp/incident-20261112-1803/captures/`. That location is local only: the captures carry addresses.

#### Committed excerpts (this directory)

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

#### Full logs (local, git-ignored)

Path: `archive/incidents/20261112-bt17-controller-off-bus/`, about 8 MB, written by `tools/collect.sh` (2026-11-12 22:44), with `SHA256SUMS`. It holds:

- `journal/`: for boots `7e87eae0` (before), `08956069` (failing) and `b314ca88` (current), the whole journal, the kernel-only log and the bluetooth unit log (`short-precise`), plus `-o export` (`.zst`, every field, for later filtering).
- `captures/`: every HCI capture of both capture paths since 11-12 15:48 (`.zst`).
- `machine/`: lsusb, the sysfs state of USB port 3 and of rfkill, kernels and packages, `apt-history.log`, the disabled btusb/udev configs, the unit file, timers, the btusb Kconfig and `results.tsv`.

It is not committed: it carries addresses and full session logs.

#### Not done (needs the operator)

- Recovery by a full power-off.
- The installed kernel default is now `7.0.0-43`. It was installed by the updater at 21:48:14 (`/var/log/apt/history.log`), and its stock btusb carries the entry:
  - `scripts/btusb-has-device.py /lib/modules/7.0.0-43-generic/kernel/drivers/bluetooth/btusb.ko.zst` → `FOUND 13d3:3503 x1`;
  - control `0cf3 e300` → `FOUND 0cf3:e300 x1`.
#### `results/incident-2026-11-12-1803/excerpt-boot-1-btusb-suspend-cycles.txt`
```
18:00:19.512568 device suspend
18:00:26.577645 device resume  (was suspended 7.065 s)
18:00:28.856623 device suspend
18:03:16.181629 other: USB-DISCONNECT primary
18:03:17.022465 other: 000000003dea1427
OPEN: device suspended since 18:00:28.856623, no device resume follows
primary interface 0000000095c0721a; completed device suspend/resume cycles 1; longest suspend 7.065 s
```
#### `results/incident-2026-11-12-1803/excerpt-boot-1-end.txt`
```
# command: journalctl -b -1 --no-pager -o short-precise -t systemd-logind
# filter: how the boot ended
# Bluetooth addresses replaced by <addr>
Nov 12 18:07:21.044796 n systemd-logind[1390]: The system will reboot now!
Nov 12 18:07:21.070813 n systemd-logind[1390]: System is rebooting.
```
#### `results/incident-2026-11-12-1803/excerpt-boot-1-hci-capture-decode.txt`
```
# command: btmon -T --columns=200 -r /root/exp/qca9377-bt-hang/tmp/incident-20261112-1803/captures/hci-20261112-180017.btsnoop
# filter: frames #119 to Delete Index
# Bluetooth addresses replaced by <addr>
< HCI Command: Write Extended Inquiry Response (0x03|0x0052) plen 241                                                                                            #119 [hci0] 2026-11-12 18:00:26.842657
        FEC: Not required (0x00)
        Name (complete): n
        TX power: 6 dBm
        Device ID: USB Implementer's Forum assigned (0x0002)
          Vendor: Linux Foundation (0x1d6b)
          Product: 0x0246
          Version: 5.4.8 (0x0548)
        16-bit Service UUIDs (complete): 9 entries
          Generic Access Profile (0x1800)
          Generic Attribute Profile (0x1801)
          Device Information (0x180a)
          A/V Remote Control (0x110e)
          A/V Remote Control Target (0x110c)
          Handsfree Audio Gateway (0x111f)
          Handsfree (0x111e)
          Audio Source (0x110a)
          Audio Sink (0x110b)
> HCI Event: Command Complete (0x0e) plen 4                                                                                                                      #120 [hci0] 2026-11-12 18:00:26.845565
      Write Extended Inquiry Response (0x03|0x0052) ncmd 1
        Status: Success (0x00)
@ MGMT Event: Command Complete (0x0001) plen 6                                                                                                               {0x0001} [hci0] 2026-11-12 18:00:26.845592
      Add UUID (0x0010) plen 3
        Status: Success (0x00)
        Class: 0x6c010c
          Major class: Computer (desktop, notebook, PDA, organizers)
          Minor class: Laptop
          Rendering (Printing, Speaker)
          Capturing (Scanner, Microphone)
          Audio (Speaker, Microphone, Headset)
          Telephony (Cordless telephony, Modem, Headset)
= bluetoothd: Endpoint unregistered: sender=:1.38 path=/MediaEndpoint/A2DPSource/ldac                                                                                        2026-11-12 18:03:08.819688
= bluetoothd: Endpoint unregistered: sender=:1.38 path=/MediaEndpoint/A2DPSink/aptx_hd                                                                                       2026-11-12 18:03:08.820180
= bluetoothd: Endpoint unregistered: sender=:1.38 path=/MediaEndpoint/A2DPSource/aptx_hd                                                                                     2026-11-12 18:03:08.820536
= bluetoothd: Endpoint unregistered: sender=:1.38 path=/MediaEndpoint/A2DPSink/aptx                                                                                          2026-11-12 18:03:08.820842
= bluetoothd: Endpoint unregistered: sender=:1.38 path=/MediaEndpoint/A2DPSource/aptx                                                                                        2026-11-12 18:03:08.821157
= bluetoothd: Endpoint unregistered: sender=:1.38 path=/MediaEndpoint/A2DPSink/sbc                                                                                           2026-11-12 18:03:08.821471
= bluetoothd: Endpoint unregistered: sender=:1.38 path=/MediaEndpoint/A2DPSource/sbc                                                                                         2026-11-12 18:03:08.821772
= bluetoothd: Endpoint unregistered: sender=:1.38 path=/MediaEndpoint/A2DPSink/sbc_xq                                                                                        2026-11-12 18:03:08.822154
= bluetoothd: Endpoint unregistered: sender=:1.38 path=/MediaEndpoint/A2DPSource/sbc_xq                                                                                      2026-11-12 18:03:08.822655
= bluetoothd: Endpoint unregistered: sender=:1.38 path=/MediaEndpoint/A2DPSource/aptx_ll_1                                                                                   2026-11-12 18:03:08.822927
= bluetoothd: Endpoint unregistered: sender=:1.38 path=/MediaEndpoint/A2DPSource/aptx_ll_0                                                                                   2026-11-12 18:03:08.823167
= bluetoothd: Endpoint unregistered: sender=:1.38 path=/MediaEndpoint/A2DPSource/aptx_ll_duplex_1                                                                            2026-11-12 18:03:08.823432
= bluetoothd: Endpoint unregistered: sender=:1.38 path=/MediaEndpoint/A2DPSource/aptx_ll_duplex_0                                                                            2026-11-12 18:03:08.823705
= bluetoothd: Endpoint unregistered: sender=:1.38 path=/MediaEndpoint/A2DPSource/faststream                                                                                  2026-11-12 18:03:08.824160
= bluetoothd: Endpoint unregistered: sender=:1.38 path=/MediaEndpoint/A2DPSource/faststream_duplex                                                                           2026-11-12 18:03:08.824509
= bluetoothd: Endpoint unregistered: sender=:1.38 path=/MediaEndpoint/A2DPSink/opus_05                                                                                       2026-11-12 18:03:08.824787
= bluetoothd: Endpoint unregistered: sender=:1.38 path=/MediaEndpoint/A2DPSource/opus_05                                                                                     2026-11-12 18:03:08.825028
= bluetoothd: Endpoint unregistered: sender=:1.38 path=/MediaEndpoint/A2DPSink/opus_05_duplex                                                                                2026-11-12 18:03:08.825571
= bluetoothd: Endpoint unregistered: sender=:1.38 path=/MediaEndpoint/A2DPSource/opus_05_duplex                                                                              2026-11-12 18:03:08.826166
@ MGMT Command: Remove UUID (0x0011) plen 16                                                                                                                 {0x0001} [hci0] 2026-11-12 18:03:08.826934
        UUID: Handsfree Audio Gateway
< HCI Command: Write Class of Device (0x03|0x0024) plen 3                                                                                                        #121 [hci0] 2026-11-12 18:03:08.827012
        Class: 0x2c010c
          Major class: Computer (desktop, notebook, PDA, organizers)
          Minor class: Laptop
          Rendering (Printing, Speaker)
          Capturing (Scanner, Microphone)
          Audio (Speaker, Microphone, Headset)
= bluetoothd: Endpoint registered: sender=:1.85 path=/MediaEndpoint/A2DPSource/ldac                                                                                          2026-11-12 18:03:08.924538
= bluetoothd: Endpoint registered: sender=:1.85 path=/MediaEndpoint/A2DPSink/aptx_hd                                                                                         2026-11-12 18:03:08.924741
= bluetoothd: Endpoint registered: sender=:1.85 path=/MediaEndpoint/A2DPSource/aptx_hd                                                                                       2026-11-12 18:03:08.924874
= bluetoothd: Endpoint registered: sender=:1.85 path=/MediaEndpoint/A2DPSink/aptx                                                                                            2026-11-12 18:03:08.925010
= bluetoothd: Endpoint registered: sender=:1.85 path=/MediaEndpoint/A2DPSource/aptx                                                                                          2026-11-12 18:03:08.925141
= bluetoothd: Endpoint registered: sender=:1.85 path=/MediaEndpoint/A2DPSink/sbc                                                                                             2026-11-12 18:03:08.925264
= bluetoothd: Endpoint registered: sender=:1.85 path=/MediaEndpoint/A2DPSource/sbc                                                                                           2026-11-12 18:03:08.925389
= bluetoothd: Endpoint registered: sender=:1.85 path=/MediaEndpoint/A2DPSink/sbc_xq                                                                                          2026-11-12 18:03:08.925518
= bluetoothd: Endpoint registered: sender=:1.85 path=/MediaEndpoint/A2DPSource/sbc_xq                                                                                        2026-11-12 18:03:08.925610
= bluetoothd: Endpoint registered: sender=:1.85 path=/MediaEndpoint/A2DPSource/aptx_ll_1                                                                                     2026-11-12 18:03:08.925710
= bluetoothd: Endpoint registered: sender=:1.85 path=/MediaEndpoint/A2DPSource/aptx_ll_0                                                                                     2026-11-12 18:03:08.925804
= bluetoothd: Endpoint registered: sender=:1.85 path=/MediaEndpoint/A2DPSource/aptx_ll_duplex_1                                                                              2026-11-12 18:03:08.925883
= bluetoothd: Endpoint registered: sender=:1.85 path=/MediaEndpoint/A2DPSource/aptx_ll_duplex_0                                                                              2026-11-12 18:03:08.925974
= bluetoothd: Endpoint registered: sender=:1.85 path=/MediaEndpoint/A2DPSource/faststream                                                                                    2026-11-12 18:03:08.926062
= bluetoothd: Endpoint registered: sender=:1.85 path=/MediaEndpoint/A2DPSource/faststream_duplex                                                                             2026-11-12 18:03:08.926159
= bluetoothd: Endpoint registered: sender=:1.85 path=/MediaEndpoint/A2DPSink/opus_05                                                                                         2026-11-12 18:03:08.926243
= bluetoothd: Endpoint registered: sender=:1.85 path=/MediaEndpoint/A2DPSource/opus_05                                                                                       2026-11-12 18:03:08.926388
= bluetoothd: Endpoint registered: sender=:1.85 path=/MediaEndpoint/A2DPSink/opus_05_duplex                                                                                  2026-11-12 18:03:08.926508
= bluetoothd: Endpoint registered: sender=:1.85 path=/MediaEndpoint/A2DPSource/opus_05_duplex                                                                                2026-11-12 18:03:08.926597
@ MGMT Event: Command Complete (0x0001) plen 6                                                                                                               {0x0001} [hci0] 2026-11-12 18:03:10.868450
      Remove UUID (0x0011) plen 3
        Status: Authentication Failed (0x05)
        Class: 0x6c010c
          Major class: Computer (desktop, notebook, PDA, organizers)
          Minor class: Laptop
          Rendering (Printing, Speaker)
          Capturing (Scanner, Microphone)
          Audio (Speaker, Microphone, Headset)
          Telephony (Cordless telephony, Modem, Headset)
= bluetoothd: Failed to remove UUID: Authentication Failed (0x05)                                                                                                     [hci0] 2026-11-12 18:03:10.868522
@ MGMT Command: Remove UUID (0x0011) plen 16                                                                                                                 {0x0001} [hci0] 2026-11-12 18:03:10.868546
        UUID: Handsfree
@ MGMT Event: Command Complete (0x0001) plen 6                                                                                                               {0x0001} [hci0] 2026-11-12 18:03:12.916872
      Remove UUID (0x0011) plen 3
        Status: Authentication Failed (0x05)
        Class: 0x6c010c
          Major class: Computer (desktop, notebook, PDA, organizers)
          Minor class: Laptop
          Rendering (Printing, Speaker)
          Capturing (Scanner, Microphone)
          Audio (Speaker, Microphone, Headset)
          Telephony (Cordless telephony, Modem, Headset)
= bluetoothd: Failed to remove UUID: Authentication Failed (0x05)                                                                                                     [hci0] 2026-11-12 18:03:12.916972
@ MGMT Command: Remove UUID (0x0011) plen 16                                                                                                                 {0x0001} [hci0] 2026-11-12 18:03:12.917026
        UUID: Audio Sink
@ MGMT Event: Command Complete (0x0001) plen 6                                                                                                               {0x0001} [hci0] 2026-11-12 18:03:14.964424
      Remove UUID (0x0011) plen 3
        Status: Authentication Failed (0x05)
        Class: 0x6c010c
          Major class: Computer (desktop, notebook, PDA, organizers)
          Minor class: Laptop
          Rendering (Printing, Speaker)
          Capturing (Scanner, Microphone)
          Audio (Speaker, Microphone, Headset)
          Telephony (Cordless telephony, Modem, Headset)
= bluetoothd: Failed to remove UUID: Authentication Failed (0x05)                                                                                                     [hci0] 2026-11-12 18:03:14.964474
@ MGMT Command: Remove UUID (0x0011) plen 16                                                                                                                 {0x0001} [hci0] 2026-11-12 18:03:14.964495
        UUID: Audio Source
< HCI Command: Write Class of Device (0x03|0x0024) plen 3                                                                                                        #122 [hci0] 2026-11-12 18:03:16.180812
        Class: 0x0c010c
          Major class: Computer (desktop, notebook, PDA, organizers)
          Minor class: Laptop
          Rendering (Printing, Speaker)
          Capturing (Scanner, Microphone)
@ MGMT Event: Command Complete (0x0001) plen 6                                                                                                               {0x0001} [hci0] 2026-11-12 18:03:17.012480
      Remove UUID (0x0011) plen 3
        Status: Authentication Failed (0x05)
        Class: 0x6c010c
          Major class: Computer (desktop, notebook, PDA, organizers)
          Minor class: Laptop
          Rendering (Printing, Speaker)
          Capturing (Scanner, Microphone)
          Audio (Speaker, Microphone, Headset)
          Telephony (Cordless telephony, Modem, Headset)
@ MGMT Command: Add UUID (0x0010) plen 17                                                                                                                    {0x0001} [hci0] 2026-11-12 18:03:17.012608
        UUID: Handsfree Audio Gateway
        Service class: 0x40
@ MGMT Event: Command Status (0x0002) plen 3                                                                                                                 {0x0001} [hci0] 2026-11-12 18:03:17.012622
      Add UUID (0x0010)
        Status: Invalid Index (0x11)
@ MGMT Command: Add UUID (0x0010) plen 17                                                                                                                    {0x0001} [hci0] 2026-11-12 18:03:17.012688
        UUID: Handsfree
        Service class: 0x20
@ MGMT Event: Command Status (0x0002) plen 3                                                                                                                 {0x0001} [hci0] 2026-11-12 18:03:17.012696
      Add UUID (0x0010)
        Status: Invalid Index (0x11)
@ MGMT Command: Add UUID (0x0010) plen 17                                                                                                                    {0x0001} [hci0] 2026-11-12 18:03:17.012784
        UUID: Audio Source
        Service class: 0x08
@ MGMT Event: Command Status (0x0002) plen 3                                                                                                                 {0x0001} [hci0] 2026-11-12 18:03:17.012790
      Add UUID (0x0010)
        Status: Invalid Index (0x11)
@ MGMT Command: Add UUID (0x0010) plen 17                                                                                                                    {0x0001} [hci0] 2026-11-12 18:03:17.012886
        UUID: Audio Sink
        Service class: 0x04
@ MGMT Event: Command Status (0x0002) plen 3                                                                                                                 {0x0001} [hci0] 2026-11-12 18:03:17.012893
      Add UUID (0x0010)
        Status: Invalid Index (0x11)
@ MGMT Event: Class Of Device Changed (0x0007) plen 3                                                                                                        {0x0001} [hci0] 2026-11-12 18:03:17.021409
        Class: 0x000000
          Major class: Miscellaneous
          Minor class: 0x00
@ MGMT Event: New Settings (0x0006) plen 4                                                                                                                   {0x0001} [hci0] 2026-11-12 18:03:17.021434
        Current settings: 0x00400ac0
          Secure Simple Pairing
          BR/EDR
          Low Energy
          Secure Connections
          Unknown settings (0x00400000)
= Close Index: <addr>                                                                                                                                      [hci0] 2026-11-12 18:03:17.021440
@ MGMT Event: Index Removed (0x0005) plen 0                                                                                                                  {0x0001} [hci0] 2026-11-12 18:03:17.021445
= Delete Index: <addr>                                                                                                                                     [hci0] 2026-11-12 18:03:17.021450
```
#### `results/incident-2026-11-12-1803/excerpt-boot-1-kernel-controller.txt`
```
# command: journalctl -b -1 _TRANSPORT=kernel --no-pager -o short-precise
# filter: lines matching 13d3|btusb|Bluetooth:|usb 3-3|usb3-port3|xhci_hcd|ath10k_pci .*firmware ver|rfkill, dynamic-debug noise dropped
# Bluetooth addresses replaced by <addr>
Nov 12 18:00:13.219177 n kernel: ACPI: Reserving SSDT table memory at [mem 0xcc138000-0xcc13d353]
Nov 12 18:00:13.245702 n kernel: xhci_hcd 0000:03:00.3: xHCI Host Controller
Nov 12 18:00:13.245826 n kernel: xhci_hcd 0000:03:00.3: new USB bus registered, assigned bus number 1
Nov 12 18:00:13.245948 n kernel: xhci_hcd 0000:03:00.3: hcc params 0x0268ffe5 hci version 0x110 quirks 0x0000020000000010
Nov 12 18:00:13.246070 n kernel: xhci_hcd 0000:03:00.3: xHCI Host Controller
Nov 12 18:00:13.246183 n kernel: xhci_hcd 0000:03:00.3: new USB bus registered, assigned bus number 2
Nov 12 18:00:13.246295 n kernel: xhci_hcd 0000:03:00.3: Host supports USB 3.1 Enhanced SuperSpeed
Nov 12 18:00:13.248506 n kernel: xhci_hcd 0000:03:00.4: xHCI Host Controller
Nov 12 18:00:13.248622 n kernel: xhci_hcd 0000:03:00.4: new USB bus registered, assigned bus number 3
Nov 12 18:00:13.248731 n kernel: xhci_hcd 0000:03:00.4: hcc params 0x0268ffe5 hci version 0x110 quirks 0x0000020000000010
Nov 12 18:00:13.248840 n kernel: xhci_hcd 0000:03:00.4: xHCI Host Controller
Nov 12 18:00:13.248954 n kernel: xhci_hcd 0000:03:00.4: new USB bus registered, assigned bus number 4
Nov 12 18:00:13.249065 n kernel: xhci_hcd 0000:03:00.4: Host supports USB 3.1 Enhanced SuperSpeed
Nov 12 18:00:13.252930 n kernel: usb 1-1: new high-speed USB device number 2 using xhci_hcd
Nov 12 18:00:13.253085 n kernel: usb 3-3: new full-speed USB device number 2 using xhci_hcd
Nov 12 18:00:13.253995 n kernel: usb 3-3: New USB device found, idVendor=13d3, idProduct=3503, bcdDevice= 0.01
Nov 12 18:00:13.254187 n kernel: usb 3-3: New USB device strings: Mfr=0, Product=0, SerialNumber=0
Nov 12 18:00:13.254368 n kernel: usb 1-2: new full-speed USB device number 3 using xhci_hcd
Nov 12 18:00:13.254551 n kernel: usb 3-4: new full-speed USB device number 3 using xhci_hcd
Nov 12 18:00:13.256588 n kernel: usb 1-3: new high-speed USB device number 4 using xhci_hcd
Nov 12 18:00:13.257430 n kernel: usb 1-4: new high-speed USB device number 5 using xhci_hcd
Nov 12 18:00:13.626565 n kernel: Bluetooth: Core ver 2.22
Nov 12 18:00:13.626705 n kernel: Bluetooth: HCI device and connection manager initialized
Nov 12 18:00:13.626717 n kernel: Bluetooth: HCI socket layer initialized
Nov 12 18:00:13.626729 n kernel: Bluetooth: L2CAP socket layer initialized
Nov 12 18:00:13.626750 n kernel: Bluetooth: SCO socket layer initialized
Nov 12 18:00:13.722559 n kernel: btusb: loading out-of-tree module taints kernel.
Nov 12 18:00:13.722627 n kernel: btusb: module verification failed: signature and/or required key missing - tainting kernel
Nov 12 18:00:13.726559 n kernel: usbcore: registered new interface driver btusb
Nov 12 18:00:13.735075 n kernel: Bluetooth: hci0: using rampatch file: qca/rampatch_usb_00000302.bin
Nov 12 18:00:13.735115 n kernel: Bluetooth: hci0: QCA: patch rome 0x302 build 0x3e8, firmware rome 0x302 build 0x111
Nov 12 18:00:13.950923 n kernel: ath10k_pci 0000:02:00.0: firmware ver WLAN.TF.2.1-00021-QCARMSWP-1 api 6 features wowlan,ignore-otp crc32 42e41877
Nov 12 18:00:14.108557 n kernel: Bluetooth: hci0: using NVM file: qca/nvm_usb_00000302.bin
Nov 12 18:00:14.136558 n kernel: Bluetooth: hci0: HCI Enhanced Setup Synchronous Connection command is advertised, but not supported.
Nov 12 18:00:19.671631 n kernel: rfkill: input handler disabled
Nov 12 18:00:26.450550 n kernel: Bluetooth: BNEP (Ethernet Emulation) ver 1.3
Nov 12 18:00:26.450592 n kernel: Bluetooth: BNEP filters: protocol multicast
Nov 12 18:00:26.450608 n kernel: Bluetooth: BNEP socket layer initialized
Nov 12 18:00:26.452580 n kernel: Bluetooth: MGMT ver 1.23
Nov 12 18:00:26.479579 n kernel: Bluetooth: RFCOMM TTY layer initialized
Nov 12 18:00:26.479593 n kernel: Bluetooth: RFCOMM socket layer initialized
Nov 12 18:00:26.479602 n kernel: Bluetooth: RFCOMM ver 1.11
Nov 12 18:03:08.818452 n kernel: rfkill: input handler enabled
Nov 12 18:03:09.849362 n kernel: rfkill: input handler disabled
Nov 12 18:03:10.869409 n kernel: Bluetooth: hci0: command 0x0c24 tx timeout
Nov 12 18:03:10.869436 n kernel: Bluetooth: hci0: Opcode 0x0c24 failed: -110
Nov 12 18:03:12.917800 n kernel: Bluetooth: hci0: Opcode 0x0c24 failed: -110
Nov 12 18:03:14.120456 n kernel: usb 3-3: reset full-speed USB device number 2 using xhci_hcd
Nov 12 18:03:14.240422 n kernel: usb 3-3: device descriptor read/64, error -71
Nov 12 18:03:14.461482 n kernel: usb 3-3: device descriptor read/64, error -71
Nov 12 18:03:14.677408 n kernel: usb 3-3: reset full-speed USB device number 2 using xhci_hcd
Nov 12 18:03:14.797392 n kernel: usb 3-3: device descriptor read/64, error -71
Nov 12 18:03:14.965410 n kernel: Bluetooth: hci0: Opcode 0x0c24 failed: -110
Nov 12 18:03:15.022363 n kernel: usb 3-3: device descriptor read/64, error -71
Nov 12 18:03:15.239370 n kernel: usb 3-3: reset full-speed USB device number 2 using xhci_hcd
Nov 12 18:03:15.239698 n kernel: usb 3-3: Device not responding to setup address.
Nov 12 18:03:15.445377 n kernel: usb 3-3: Device not responding to setup address.
Nov 12 18:03:15.653410 n kernel: usb 3-3: device not accepting address 2, error -71
Nov 12 18:03:15.653967 n kernel: usb 3-3: WARN: invalid context state for evaluate context command.
Nov 12 18:03:15.765397 n kernel: usb 3-3: reset full-speed USB device number 2 using xhci_hcd
Nov 12 18:03:15.765808 n kernel: xhci_hcd 0000:03:00.4: ERROR: unexpected setup address command completion code 0x11.
Nov 12 18:03:15.973397 n kernel: xhci_hcd 0000:03:00.4: ERROR: unexpected setup address command completion code 0x11.
Nov 12 18:03:16.181035 n kernel: usb 3-3: device not accepting address 2, error -22
Nov 12 18:03:16.181629 n kernel: usb 3-3: USB disconnect, device number 2
Nov 12 18:03:16.181854 n kernel: Bluetooth: hci0: Failed usb_autopm_get_interface: -16
Nov 12 18:03:17.013432 n kernel: Bluetooth: hci0: Opcode 0x0c24 failed: -110
Nov 12 18:03:17.134363 n kernel: usb 3-3: new full-speed USB device number 4 using xhci_hcd
Nov 12 18:03:17.254365 n kernel: usb 3-3: device descriptor read/64, error -71
Nov 12 18:03:17.476389 n kernel: usb 3-3: device descriptor read/64, error -71
Nov 12 18:03:17.693377 n kernel: usb 3-3: new full-speed USB device number 5 using xhci_hcd
Nov 12 18:03:17.812399 n kernel: usb 3-3: device descriptor read/64, error -71
Nov 12 18:03:18.036390 n kernel: usb 3-3: device descriptor read/64, error -71
Nov 12 18:03:18.141380 n kernel: usb usb3-port3: attempt power cycle
Nov 12 18:03:18.520387 n kernel: usb 3-3: new full-speed USB device number 6 using xhci_hcd
Nov 12 18:03:18.520494 n kernel: usb 3-3: Device not responding to setup address.
Nov 12 18:03:18.725401 n kernel: usb 3-3: Device not responding to setup address.
Nov 12 18:03:18.934454 n kernel: usb 3-3: device not accepting address 6, error -71
Nov 12 18:03:18.934629 n kernel: usb 3-3: WARN: invalid context state for evaluate context command.
Nov 12 18:03:19.046373 n kernel: usb 3-3: new full-speed USB device number 7 using xhci_hcd
Nov 12 18:03:19.046461 n kernel: usb 3-3: Device not responding to setup address.
Nov 12 18:03:19.253374 n kernel: usb 3-3: Device not responding to setup address.
Nov 12 18:03:19.461415 n kernel: usb 3-3: device not accepting address 7, error -71
Nov 12 18:03:19.461549 n kernel: usb 3-3: WARN: invalid context state for evaluate context command.
Nov 12 18:03:19.461579 n kernel: usb usb3-port3: unable to enumerate USB device
Nov 12 18:07:21.060364 n kernel: rfkill: input handler enabled
```
#### `results/incident-2026-11-12-1803/excerpt-boot-1-kernel-failure-window.txt`
```
# command: journalctl -b -1 _TRANSPORT=kernel --no-pager -o short-precise --since 2026-11-12 18:03:08.8 --until 2026-11-12 18:03:20
# filter: whole window, blank debug lines dropped
# Bluetooth addresses replaced by <addr>
Nov 12 18:03:08.818452 n kernel: rfkill: input handler enabled
Nov 12 18:03:08.827426 n kernel: hci0: entry 0000000037d8f7a5
Nov 12 18:03:08.827453 n kernel: hci0: Opcode 0x0c24
Nov 12 18:03:08.827465 n kernel: hci0: opcode 0x0c24 plen 3
Nov 12 18:03:08.827476 n kernel: hci0: skb len 6
Nov 12 18:03:08.827490 n kernel: hci0: length 1
Nov 12 18:03:08.827502 n kernel: hci0 cmd_cnt 1 cmd queued 1
Nov 12 18:03:08.827513 n kernel: hci0: skb 000000003cdd38d2
Nov 12 18:03:09.849362 n kernel: rfkill: input handler disabled
Nov 12 18:03:10.869363 n kernel: hci0: end: err -110
Nov 12 18:03:10.869409 n kernel: Bluetooth: hci0: command 0x0c24 tx timeout
Nov 12 18:03:10.869421 n kernel: hci0: err 0x6e
Nov 12 18:03:10.869436 n kernel: Bluetooth: hci0: Opcode 0x0c24 failed: -110
Nov 12 18:03:10.869485 n kernel: hci0: entry 00000000c59aa9e0
Nov 12 18:03:10.869513 n kernel: hci0: Opcode 0x0c24
Nov 12 18:03:10.869521 n kernel: hci0: opcode 0x0c24 plen 3
Nov 12 18:03:10.869530 n kernel: hci0: skb len 6
Nov 12 18:03:10.869544 n kernel: hci0: length 1
Nov 12 18:03:12.917759 n kernel: hci0: end: err -110
Nov 12 18:03:12.917800 n kernel: Bluetooth: hci0: Opcode 0x0c24 failed: -110
Nov 12 18:03:12.917933 n kernel: hci0: entry 00000000662ca84f
Nov 12 18:03:12.917994 n kernel: hci0: Opcode 0x0c24
Nov 12 18:03:12.918018 n kernel: hci0: opcode 0x0c24 plen 3
Nov 12 18:03:12.918049 n kernel: hci0: skb len 6
Nov 12 18:03:12.918073 n kernel: hci0: length 1
Nov 12 18:03:14.120456 n kernel: usb 3-3: reset full-speed USB device number 2 using xhci_hcd
Nov 12 18:03:14.240422 n kernel: usb 3-3: device descriptor read/64, error -71
Nov 12 18:03:14.461482 n kernel: usb 3-3: device descriptor read/64, error -71
Nov 12 18:03:14.677408 n kernel: usb 3-3: reset full-speed USB device number 2 using xhci_hcd
Nov 12 18:03:14.797392 n kernel: usb 3-3: device descriptor read/64, error -71
Nov 12 18:03:14.965371 n kernel: hci0: end: err -110
Nov 12 18:03:14.965410 n kernel: Bluetooth: hci0: Opcode 0x0c24 failed: -110
Nov 12 18:03:14.965451 n kernel: hci0: entry 0000000033ee80d4
Nov 12 18:03:14.965470 n kernel: hci0: Opcode 0x0c24
Nov 12 18:03:14.965480 n kernel: hci0: opcode 0x0c24 plen 3
Nov 12 18:03:14.965489 n kernel: hci0: skb len 6
Nov 12 18:03:14.965499 n kernel: hci0: length 1
Nov 12 18:03:15.022363 n kernel: usb 3-3: device descriptor read/64, error -71
Nov 12 18:03:15.037362 n kernel: warning: `ThreadPoolForeg' uses wireless extensions which will stop working for Wi-Fi 7 hardware; use nl80211
Nov 12 18:03:15.239370 n kernel: usb 3-3: reset full-speed USB device number 2 using xhci_hcd
Nov 12 18:03:15.239698 n kernel: usb 3-3: Device not responding to setup address.
Nov 12 18:03:15.445377 n kernel: usb 3-3: Device not responding to setup address.
Nov 12 18:03:15.653410 n kernel: usb 3-3: device not accepting address 2, error -71
Nov 12 18:03:15.653967 n kernel: usb 3-3: WARN: invalid context state for evaluate context command.
Nov 12 18:03:15.765397 n kernel: usb 3-3: reset full-speed USB device number 2 using xhci_hcd
Nov 12 18:03:15.765808 n kernel: xhci_hcd 0000:03:00.4: ERROR: unexpected setup address command completion code 0x11.
Nov 12 18:03:15.973397 n kernel: xhci_hcd 0000:03:00.4: ERROR: unexpected setup address command completion code 0x11.
Nov 12 18:03:16.181035 n kernel: usb 3-3: device not accepting address 2, error -22
Nov 12 18:03:16.181629 n kernel: usb 3-3: USB disconnect, device number 2
Nov 12 18:03:16.181854 n kernel: Bluetooth: hci0: Failed usb_autopm_get_interface: -16
Nov 12 18:03:16.181879 n kernel: hci0 cmd_cnt 1 cmd queued 3
Nov 12 18:03:16.181900 n kernel: hci0: skb 000000005c7c77da
Nov 12 18:03:16.181920 n kernel: intf 0000000095c0721a
Nov 12 18:03:16.181935 n kernel: 00000000570e87a2 name hci0 bus 1
Nov 12 18:03:17.013401 n kernel: hci0: end: err -110
Nov 12 18:03:17.013432 n kernel: Bluetooth: hci0: Opcode 0x0c24 failed: -110
Nov 12 18:03:17.013454 n kernel: hci0 00000000570e87a2
Nov 12 18:03:17.022358 n kernel: hci0: err 0x13
Nov 12 18:03:17.022384 n kernel: hci0: cancelling interleave scan
Nov 12 18:03:17.022397 n kernel: All LE pending actions cleared
Nov 12 18:03:17.022409 n kernel: hdev hci0
Nov 12 18:03:17.022465 n kernel: intf 000000003dea1427
Nov 12 18:03:17.022477 n kernel: All LE connection parameters were removed
Nov 12 18:03:17.134363 n kernel: usb 3-3: new full-speed USB device number 4 using xhci_hcd
Nov 12 18:03:17.254365 n kernel: usb 3-3: device descriptor read/64, error -71
Nov 12 18:03:17.476389 n kernel: usb 3-3: device descriptor read/64, error -71
Nov 12 18:03:17.693377 n kernel: usb 3-3: new full-speed USB device number 5 using xhci_hcd
Nov 12 18:03:17.812399 n kernel: usb 3-3: device descriptor read/64, error -71
Nov 12 18:03:18.036390 n kernel: usb 3-3: device descriptor read/64, error -71
Nov 12 18:03:18.141380 n kernel: usb usb3-port3: attempt power cycle
Nov 12 18:03:18.520387 n kernel: usb 3-3: new full-speed USB device number 6 using xhci_hcd
Nov 12 18:03:18.520494 n kernel: usb 3-3: Device not responding to setup address.
Nov 12 18:03:18.725401 n kernel: usb 3-3: Device not responding to setup address.
Nov 12 18:03:18.934454 n kernel: usb 3-3: device not accepting address 6, error -71
Nov 12 18:03:18.934629 n kernel: usb 3-3: WARN: invalid context state for evaluate context command.
Nov 12 18:03:19.046373 n kernel: usb 3-3: new full-speed USB device number 7 using xhci_hcd
Nov 12 18:03:19.046461 n kernel: usb 3-3: Device not responding to setup address.
Nov 12 18:03:19.253374 n kernel: usb 3-3: Device not responding to setup address.
Nov 12 18:03:19.461415 n kernel: usb 3-3: device not accepting address 7, error -71
Nov 12 18:03:19.461549 n kernel: usb 3-3: WARN: invalid context state for evaluate context command.
Nov 12 18:03:19.461579 n kernel: usb usb3-port3: unable to enumerate USB device
```
#### `results/incident-2026-11-12-1803/excerpt-boot-1-kernel-last-good-window.txt`
```
# command: journalctl -b -1 _TRANSPORT=kernel --no-pager -o short-precise --since 2026-11-12 18:00:26.84 --until 2026-11-12 18:00:26.85
# filter: whole window, blank debug lines dropped
# Bluetooth addresses replaced by <addr>
Nov 12 18:00:26.840559 n kernel: opcode 0x0c52 status 0x00
Nov 12 18:00:26.840581 n kernel: hci0: result 0x00
Nov 12 18:00:26.840594 n kernel: hci0: end: err 0
Nov 12 18:00:26.840641 n kernel: hci0: entry 00000000eb3fd545
Nov 12 18:00:26.840667 n kernel: hci0: Opcode 0x0c24
Nov 12 18:00:26.840679 n kernel: hci0: opcode 0x0c24 plen 3
Nov 12 18:00:26.840692 n kernel: hci0: skb len 6
Nov 12 18:00:26.840704 n kernel: hci0: length 1
Nov 12 18:00:26.840717 n kernel: hci0 cmd_cnt 1 cmd queued 1
Nov 12 18:00:26.840729 n kernel: hci0: skb 00000000ebd3a5d2
Nov 12 18:00:26.843555 n kernel: opcode 0x0c24 status 0x00
Nov 12 18:00:26.843577 n kernel: hci0: result 0x00
Nov 12 18:00:26.843590 n kernel: hci0: end: err 0
Nov 12 18:00:26.843624 n kernel: hci0: Opcode 0x0c52
Nov 12 18:00:26.843637 n kernel: hci0: opcode 0x0c52 plen 241
Nov 12 18:00:26.843654 n kernel: hci0: skb len 244
Nov 12 18:00:26.843672 n kernel: hci0: length 1
Nov 12 18:00:26.843684 n kernel: hci0 cmd_cnt 1 cmd queued 1
Nov 12 18:00:26.843702 n kernel: hci0: skb 00000000a90cfc59
Nov 12 18:00:26.846554 n kernel: opcode 0x0c52 status 0x00
Nov 12 18:00:26.846576 n kernel: hci0: result 0x00
Nov 12 18:00:26.846600 n kernel: hci0: end: err 0
```
#### `results/incident-2026-11-12-1803/excerpt-boot-1-userspace-trigger.txt`
```
# command: journalctl -b -1 --no-pager -o short-precise --since 2026-11-12 18:03:08 --until 2026-11-12 18:03:18 -t bluetoothd -t gdm-password] -t systemd-logind
# filter: login, mgmt commands, failures, adapter removal
# Bluetooth addresses replaced by <addr>
Nov 12 18:03:08.289670 n gdm-password][3154]: pam_unix(gdm-password:session): session opened for user i(uid=1000) by i(uid=0)
Nov 12 18:03:08.300873 n systemd-logind[1390]: New session 2 of user i.
Nov 12 18:03:08.819506 n bluetoothd[2852]: src/adapter.c:remove_uuid() sending remove uuid command for index 0
Nov 12 18:03:08.819596 n bluetoothd[2852]: src/adapter.c:remove_uuid() sending remove uuid command for index 0
Nov 12 18:03:08.819669 n bluetoothd[2852]: Endpoint unregistered: sender=:1.38 path=/MediaEndpoint/A2DPSource/ldac
Nov 12 18:03:08.825517 n bluetoothd[2852]: src/adapter.c:remove_uuid() sending remove uuid command for index 0
Nov 12 18:03:08.826112 n bluetoothd[2852]: src/adapter.c:remove_uuid() sending remove uuid command for index 0
Nov 12 18:03:08.826956 n bluetoothd[2852]: src/shared/mgmt.c:send_request() [0x0000] command 0x0011
Nov 12 18:03:08.922327 n bluetoothd[2852]: src/adapter.c:add_uuid() sending add uuid command for index 0
Nov 12 18:03:08.922653 n bluetoothd[2852]: src/adapter.c:add_uuid() sending add uuid command for index 0
Nov 12 18:03:08.924480 n bluetoothd[2852]: src/adapter.c:add_uuid() sending add uuid command for index 0
Nov 12 18:03:08.924725 n bluetoothd[2852]: src/adapter.c:add_uuid() sending add uuid command for index 0
Nov 12 18:03:10.868464 n bluetoothd[2852]: src/shared/mgmt.c:can_read_data() [0x0000] command 0x0011 complete: 0x05
Nov 12 18:03:10.868485 n bluetoothd[2852]: Failed to remove UUID: Authentication Failed (0x05)
Nov 12 18:03:10.868557 n bluetoothd[2852]: src/shared/mgmt.c:send_request() [0x0000] command 0x0011
Nov 12 18:03:12.916897 n bluetoothd[2852]: src/shared/mgmt.c:can_read_data() [0x0000] command 0x0011 complete: 0x05
Nov 12 18:03:12.916932 n bluetoothd[2852]: Failed to remove UUID: Authentication Failed (0x05)
Nov 12 18:03:12.917027 n bluetoothd[2852]: src/shared/mgmt.c:send_request() [0x0000] command 0x0011
Nov 12 18:03:14.964440 n bluetoothd[2852]: src/shared/mgmt.c:can_read_data() [0x0000] command 0x0011 complete: 0x05
Nov 12 18:03:14.964456 n bluetoothd[2852]: Failed to remove UUID: Authentication Failed (0x05)
Nov 12 18:03:14.964501 n bluetoothd[2852]: src/shared/mgmt.c:send_request() [0x0000] command 0x0011
Nov 12 18:03:17.012496 n bluetoothd[2852]: src/shared/mgmt.c:can_read_data() [0x0000] command 0x0011 complete: 0x05
Nov 12 18:03:17.012521 n bluetoothd[2852]: Failed to remove UUID: Authentication Failed (0x05)
Nov 12 18:03:17.012596 n bluetoothd[2852]: src/shared/mgmt.c:send_request() [0x0000] command 0x0010
Nov 12 18:03:17.012637 n bluetoothd[2852]: src/shared/mgmt.c:can_read_data() [0x0000] command 0x10 status: 0x11
Nov 12 18:03:17.012650 n bluetoothd[2852]: Failed to add UUID: Invalid Index (0x11)
Nov 12 18:03:17.012696 n bluetoothd[2852]: src/shared/mgmt.c:send_request() [0x0000] command 0x0010
Nov 12 18:03:17.012739 n bluetoothd[2852]: src/shared/mgmt.c:can_read_data() [0x0000] command 0x10 status: 0x11
Nov 12 18:03:17.012747 n bluetoothd[2852]: Failed to add UUID: Invalid Index (0x11)
Nov 12 18:03:17.012793 n bluetoothd[2852]: src/shared/mgmt.c:send_request() [0x0000] command 0x0010
Nov 12 18:03:17.012829 n bluetoothd[2852]: src/shared/mgmt.c:can_read_data() [0x0000] command 0x10 status: 0x11
Nov 12 18:03:17.012843 n bluetoothd[2852]: Failed to add UUID: Invalid Index (0x11)
Nov 12 18:03:17.012898 n bluetoothd[2852]: src/shared/mgmt.c:send_request() [0x0000] command 0x0010
Nov 12 18:03:17.012927 n bluetoothd[2852]: src/shared/mgmt.c:can_read_data() [0x0000] command 0x10 status: 0x11
Nov 12 18:03:17.012935 n bluetoothd[2852]: Failed to add UUID: Invalid Index (0x11)
Nov 12 18:03:17.021423 n bluetoothd[2852]: src/shared/mgmt.c:can_read_data() [0x0000] event 0x0007
Nov 12 18:03:17.021479 n bluetoothd[2852]: src/shared/mgmt.c:can_read_data() [0x0000] event 0x0006
Nov 12 18:03:17.021550 n bluetoothd[2852]: src/shared/mgmt.c:can_read_data() [0x0000] event 0x0005
Nov 12 18:03:17.021558 n bluetoothd[2852]: src/adapter.c:index_removed() index 0
Nov 12 18:03:17.022471 n bluetoothd[2852]: src/adapter.c:remove_uuid() sending remove uuid command for index 0
Nov 12 18:03:17.022538 n bluetoothd[2852]: src/adapter.c:remove_uuid() sending remove uuid command for index 0
Nov 12 18:03:17.025020 n bluetoothd[2852]: src/adapter.c:remove_uuid() sending remove uuid command for index 0
Nov 12 18:03:17.025063 n bluetoothd[2852]: src/adapter.c:remove_uuid() sending remove uuid command for index 0
Nov 12 18:03:17.025122 n bluetoothd[2852]: src/adapter.c:remove_uuid() sending remove uuid command for index 0
Nov 12 18:03:17.025157 n bluetoothd[2852]: src/adapter.c:remove_uuid() sending remove uuid command for index 0
Nov 12 18:03:17.025267 n bluetoothd[2852]: src/adapter.c:remove_uuid() sending remove uuid command for index 0
Nov 12 18:03:17.025294 n bluetoothd[2852]: src/adapter.c:remove_uuid() sending remove uuid command for index 0
Nov 12 18:03:17.025320 n bluetoothd[2852]: src/adapter.c:remove_uuid() sending remove uuid command for index 0
Nov 12 18:03:17.025395 n bluetoothd[2852]: src/adapter.c:adapter_free() 0x64258fee93c0
```
#### `results/incident-2026-11-12-1803/excerpt-boot-2-btusb-suspend-cycles.txt`
```
15:49:15.238004 device suspend
15:49:22.539007 device resume  (was suspended 7.301 s)
15:49:25.051013 device suspend
16:38:35.081070 device resume  (was suspended 2950.030 s)
16:38:40.059077 device suspend
17:49:29.780108 device resume  (was suspended 4249.721 s)
17:49:35.200080 device suspend
17:49:49.138040 device resume  (was suspended 13.938 s)
17:49:56.556088 other: 00000000677ab743
17:49:59.056012 other: 00000000677ab743
17:50:03.227060 other: 00000000677ab743
17:50:07.213047 device suspend
17:50:14.055060 device resume  (was suspended 6.842 s)
17:50:22.466062 other: 00000000677ab743
17:50:24.953011 other: 00000000677ab743
17:50:31.187015 device suspend
17:50:32.344033 device resume  (was suspended 1.157 s)
17:50:37.158014 other: 00000000677ab743
17:50:39.651057 other: 00000000677ab743
17:50:42.151018 other: 00000000677ab743
17:50:44.411015 other: 00000000677ab743
17:50:49.100009 device suspend
17:51:34.938012 device resume  (was suspended 45.838 s)
17:51:39.930020 other: 00000000677ab743
17:51:47.248022 other: 00000000677ab743
17:51:49.748023 other: 00000000677ab743
17:51:52.129018 other: 00000000677ab743
17:51:54.512046 other: 00000000677ab743
17:51:59.206010 other: 00000000677ab743
17:52:01.226014 other: 00000000677ab743
17:52:03.726010 other: 00000000677ab743
17:52:07.842018 device suspend
17:52:08.397015 device resume  (was suspended 0.555 s)
17:52:14.953053 other: 00000000677ab743
17:52:16.967021 other: 00000000677ab743
17:52:19.420067 other: 00000000677ab743
17:52:21.453094 other: 00000000677ab743
17:52:23.953026 other: 00000000677ab743
17:52:26.043080 other: 00000000677ab743
17:52:29.339082 device suspend
OPEN: device suspended since 17:52:29.339082, no device resume follows
primary interface 0000000045009c60; completed device suspend/resume cycles 8; longest suspend 4249.721 s
```
#### `results/incident-2026-11-12-1803/excerpt-boot-2-end.txt`
```
# command: journalctl -b -2 --no-pager -o short-precise -t systemd-logind
# filter: how the boot ended
# Bluetooth addresses replaced by <addr>
Nov 12 17:52:26.583655 n systemd-logind[1386]: The system will power off now!
Nov 12 17:52:26.609529 n systemd-logind[1386]: System is powering down.
```
#### `results/incident-2026-11-12-1803/excerpt-boot0-kernel-no-controller.txt`
```
# command: journalctl -b 0 _TRANSPORT=kernel --no-pager -o short-precise
# filter: port 3-3, Bluetooth core, Wi-Fi firmware line
# Bluetooth addresses replaced by <addr>
Nov 12 18:08:03.845136 n kernel: usb 3-3: new full-speed USB device number 2 using xhci_hcd
Nov 12 18:08:03.845350 n kernel: usb 3-3: device descriptor read/64, error -71
Nov 12 18:08:03.847035 n kernel: usb 3-3: device descriptor read/64, error -71
Nov 12 18:08:03.847759 n kernel: usb 3-3: new full-speed USB device number 3 using xhci_hcd
Nov 12 18:08:03.848529 n kernel: usb 3-3: device descriptor read/64, error -71
Nov 12 18:08:03.848730 n kernel: usb 3-3: device descriptor read/64, error -71
Nov 12 18:08:03.849415 n kernel: usb usb3-port3: attempt power cycle
Nov 12 18:08:03.850229 n kernel: usb 3-3: new full-speed USB device number 4 using xhci_hcd
Nov 12 18:08:03.850242 n kernel: usb 3-3: Device not responding to setup address.
Nov 12 18:08:03.850255 n kernel: usb 3-3: Device not responding to setup address.
Nov 12 18:08:03.850267 n kernel: usb 3-3: device not accepting address 4, error -71
Nov 12 18:08:03.850279 n kernel: usb 3-3: WARN: invalid context state for evaluate context command.
Nov 12 18:08:03.850292 n kernel: usb 3-3: new full-speed USB device number 5 using xhci_hcd
Nov 12 18:08:03.850304 n kernel: usb 3-3: Device not responding to setup address.
Nov 12 18:08:03.850592 n kernel: usb 3-3: Device not responding to setup address.
Nov 12 18:08:03.850850 n kernel: usb 3-3: device not accepting address 5, error -71
Nov 12 18:08:03.850863 n kernel: usb 3-3: WARN: invalid context state for evaluate context command.
Nov 12 18:08:03.850870 n kernel: usb usb3-port3: unable to enumerate USB device
Nov 12 18:08:04.575496 n kernel: ath10k_pci 0000:02:00.0: firmware ver WLAN.TF.2.1-00021-QCARMSWP-1 api 6 features wowlan,ignore-otp crc32 42e41877
Nov 12 18:08:07.713134 n kernel: Bluetooth: Core ver 2.22
```
#### `results/incident-2026-11-12-1803/excerpt-port-3-3-resets-journal-archive.txt`
```
# Every reset, power cycle and disconnect of USB port 3-3 (the Bluetooth controller) in the archived boot journals
# Command (run 2026-11-13 ~03:35 CET):
#   python3 -I scripts/journal-archive-grep.py 'usb 3-3: reset|usb3-port3: attempt power cycle|usb 3-3: USB disconnect' ~/bt-journal-archive/boot-*.export.zst
# 76 archived boots, 2026-08-12 to 2026-11-12 (the archive keeps a boot only after it ends, and
# journald may have dropped the start of a long boot before then).
# Reading:
# - Every reset sequence before BT-17 falls in 2026-08-12 to 2026-08-16 and on 2026-09-24
#   04:02, all on the stock btusb (ROM firmware), the BT-1 period, before the device-table
#   entry was in use (09-24 is the controller wedged by death 9 and the rfkill cycle after it,
#   EX-047 and EX-048).
# - No reset of 3-3 appears between 2026-09-24 04:04 and 2026-11-12 18:03:14 (BT-17).
# - The disconnects of 2026-11-05 19:33:05 and 2026-11-11 18:58:34 are the BT-16 start-ups.
# - The shape differs. In each earlier sequence the four resets are about 31, 32 and 11 s
#   apart, with the power cycle about 64 s after the disconnect. In BT-17 the four resets fall
#   within 18:03:14 to 18:03:15, and the power cycle comes 2 s after the disconnect.
# Output verbatim:
boot-0343c15d.export.zst: 0 match(es)
boot-045caff5.export.zst: 0 match(es)
  2026-11-12 18:03:14  usb 3-3: reset full-speed USB device number 2 using xhci_hcd
  2026-11-12 18:03:14  usb 3-3: reset full-speed USB device number 2 using xhci_hcd
  2026-11-12 18:03:15  usb 3-3: reset full-speed USB device number 2 using xhci_hcd
  2026-11-12 18:03:15  usb 3-3: reset full-speed USB device number 2 using xhci_hcd
  2026-11-12 18:03:16  usb 3-3: USB disconnect, device number 2
  2026-11-12 18:03:18  usb usb3-port3: attempt power cycle
boot-08956069.export.zst: 6 match(es)
boot-17cfdfc4.export.zst: 0 match(es)
boot-197f351e.export.zst: 0 match(es)
boot-1bbf9aea.export.zst: 0 match(es)
  2026-09-24 04:02:14  usb 3-3: reset full-speed USB device number 2 using xhci_hcd
  2026-09-24 04:02:45  usb 3-3: reset full-speed USB device number 2 using xhci_hcd
  2026-09-24 04:03:17  usb 3-3: reset full-speed USB device number 2 using xhci_hcd
  2026-09-24 04:03:28  usb 3-3: reset full-speed USB device number 2 using xhci_hcd
  2026-09-24 04:03:39  usb 3-3: USB disconnect, device number 2
  2026-09-24 04:04:43  usb usb3-port3: attempt power cycle
boot-20fbb9a2.export.zst: 6 match(es)
boot-226965f1.export.zst: 0 match(es)
boot-247c23c4.export.zst: 0 match(es)
boot-257d1599.export.zst: 0 match(es)
boot-262af9f0.export.zst: 0 match(es)
  2026-08-15 05:00:17  usb 3-3: reset full-speed USB device number 2 using xhci_hcd
  2026-08-15 05:00:48  usb 3-3: reset full-speed USB device number 2 using xhci_hcd
  2026-08-15 05:01:20  usb 3-3: reset full-speed USB device number 2 using xhci_hcd
  2026-08-15 05:01:31  usb 3-3: reset full-speed USB device number 2 using xhci_hcd
  2026-08-15 05:01:43  usb 3-3: USB disconnect, device number 2
  2026-08-15 05:02:46  usb usb3-port3: attempt power cycle
boot-30bf5509.export.zst: 6 match(es)
boot-3caa9acf.export.zst: 0 match(es)
boot-3e8809d5.export.zst: 0 match(es)
boot-46cb5188.export.zst: 0 match(es)
boot-482d2579.export.zst: 0 match(es)
boot-49067785.export.zst: 0 match(es)
boot-4e50c3f3.export.zst: 0 match(es)
  2026-08-14 13:04:53  usb 3-3: USB disconnect, device number 2
boot-54b5b306.export.zst: 1 match(es)
boot-56afa828.export.zst: 0 match(es)
boot-5b6803e6.export.zst: 0 match(es)
  2026-11-11 18:58:34  usb 3-3: USB disconnect, device number 2
boot-5e459fa0.export.zst: 1 match(es)
boot-5ee9ab78.export.zst: 0 match(es)
  2026-08-16 15:38:15  usb 3-3: reset full-speed USB device number 2 using xhci_hcd
  2026-08-16 15:38:46  usb 3-3: reset full-speed USB device number 2 using xhci_hcd
  2026-08-16 15:39:18  usb 3-3: reset full-speed USB device number 2 using xhci_hcd
  2026-08-16 15:39:29  usb 3-3: reset full-speed USB device number 2 using xhci_hcd
  2026-08-16 15:39:40  usb 3-3: USB disconnect, device number 2
  2026-08-16 15:40:44  usb usb3-port3: attempt power cycle
boot-60ddb417.export.zst: 6 match(es)
boot-7098fa06.export.zst: 0 match(es)
  2026-11-05 19:33:05  usb 3-3: USB disconnect, device number 2
boot-7323fc85.export.zst: 1 match(es)
boot-7345fa45.export.zst: 0 match(es)
boot-738e228b.export.zst: 0 match(es)
  2026-08-12 05:47:25  usb 3-3: reset full-speed USB device number 2 using xhci_hcd
  2026-08-12 05:51:43  usb 3-3: reset full-speed USB device number 2 using xhci_hcd
  2026-08-12 06:25:18  usb 3-3: reset full-speed USB device number 2 using xhci_hcd
  2026-08-12 06:28:36  usb 3-3: reset full-speed USB device number 2 using xhci_hcd
  2026-08-12 06:29:07  usb 3-3: reset full-speed USB device number 2 using xhci_hcd
  2026-08-12 06:29:39  usb 3-3: reset full-speed USB device number 2 using xhci_hcd
  2026-08-12 06:29:50  usb 3-3: reset full-speed USB device number 2 using xhci_hcd
  2026-08-12 06:30:01  usb 3-3: USB disconnect, device number 2
  2026-08-12 06:31:05  usb usb3-port3: attempt power cycle
boot-7ab86388.export.zst: 9 match(es)
boot-7dd5d642.export.zst: 0 match(es)
boot-7e63226d.export.zst: 0 match(es)
boot-7e87eae0.export.zst: 0 match(es)
boot-7ff777a6.export.zst: 0 match(es)
boot-855a927e.export.zst: 0 match(es)
boot-85cab7e8.export.zst: 0 match(es)
boot-8709ee7c.export.zst: 0 match(es)
boot-8c329da6.export.zst: 0 match(es)
  2026-08-15 21:12:44  usb 3-3: reset full-speed USB device number 2 using xhci_hcd
  2026-08-15 21:13:15  usb 3-3: reset full-speed USB device number 2 using xhci_hcd
  2026-08-15 21:13:47  usb 3-3: reset full-speed USB device number 2 using xhci_hcd
  2026-08-15 21:13:58  usb 3-3: reset full-speed USB device number 2 using xhci_hcd
  2026-08-15 21:14:09  usb 3-3: USB disconnect, device number 2
  2026-08-15 21:15:13  usb usb3-port3: attempt power cycle
boot-95d14e7a.export.zst: 6 match(es)
boot-97510325.export.zst: 0 match(es)
  2026-08-14 21:03:35  usb 3-3: reset full-speed USB device number 2 using xhci_hcd
  2026-08-14 21:04:07  usb 3-3: reset full-speed USB device number 2 using xhci_hcd
  2026-08-14 21:04:39  usb 3-3: reset full-speed USB device number 2 using xhci_hcd
  2026-08-14 21:04:50  usb 3-3: reset full-speed USB device number 2 using xhci_hcd
  2026-08-14 21:05:01  usb 3-3: USB disconnect, device number 2
  2026-08-14 21:06:04  usb usb3-port3: attempt power cycle
boot-9d973714.export.zst: 6 match(es)
boot-a840c7c0.export.zst: 0 match(es)
boot-aa947d1b.export.zst: 0 match(es)
boot-aab68152.export.zst: 0 match(es)
boot-afd71c7b.export.zst: 0 match(es)
  2026-11-12 18:08:03  usb usb3-port3: attempt power cycle
boot-b314ca88.export.zst: 1 match(es)
boot-b60dba2a.export.zst: 0 match(es)
  2026-08-22 11:41:11  usb usb3-port3: attempt power cycle
boot-b8e9a9fb.export.zst: 1 match(es)
boot-be19fc39.export.zst: 0 match(es)
boot-bf0f9804.export.zst: 0 match(es)
boot-c07704d5.export.zst: 0 match(es)
boot-c128a59a.export.zst: 0 match(es)
boot-c34cfa10.export.zst: 0 match(es)
boot-c383d535.export.zst: 0 match(es)
boot-c707a1a7.export.zst: 0 match(es)
boot-c8342e9b.export.zst: 0 match(es)
boot-cc59ae05.export.zst: 0 match(es)
boot-cfcc2da9.export.zst: 0 match(es)
boot-d0bc81b5.export.zst: 0 match(es)
  2026-08-12 08:27:38  usb 3-3: reset full-speed USB device number 2 using xhci_hcd
  2026-08-12 08:54:56  usb 3-3: reset full-speed USB device number 2 using xhci_hcd
  2026-08-12 08:58:54  usb 3-3: reset full-speed USB device number 2 using xhci_hcd
  2026-08-12 10:07:31  usb 3-3: reset full-speed USB device number 2 using xhci_hcd
  2026-08-12 14:15:37  usb 3-3: reset full-speed USB device number 2 using xhci_hcd
  2026-08-12 14:49:47  usb 3-3: reset full-speed USB device number 2 using xhci_hcd
  2026-08-12 15:17:51  usb 3-3: reset full-speed USB device number 2 using xhci_hcd
  2026-08-12 15:36:18  usb 3-3: reset full-speed USB device number 2 using xhci_hcd
  2026-08-12 16:22:51  usb 3-3: reset full-speed USB device number 2 using xhci_hcd
  2026-08-12 18:06:33  usb 3-3: reset full-speed USB device number 2 using xhci_hcd
  2026-08-12 22:14:24  usb 3-3: reset full-speed USB device number 2 using xhci_hcd
  2026-08-12 23:05:50  usb 3-3: reset full-speed USB device number 2 using xhci_hcd
boot-d28ebac2.export.zst: 12 match(es)
boot-d479d374.export.zst: 0 match(es)
boot-d55ebbba.export.zst: 0 match(es)
boot-d6d9b2dc.export.zst: 0 match(es)
  2026-08-13 06:26:47  usb 3-3: reset full-speed USB device number 2 using xhci_hcd
  2026-08-13 06:27:19  usb 3-3: reset full-speed USB device number 2 using xhci_hcd
  2026-08-13 06:27:51  usb 3-3: reset full-speed USB device number 2 using xhci_hcd
  2026-08-13 06:28:02  usb 3-3: reset full-speed USB device number 2 using xhci_hcd
  2026-08-13 06:28:13  usb 3-3: USB disconnect, device number 2
  2026-08-13 06:29:16  usb usb3-port3: attempt power cycle
boot-e3f66b3e.export.zst: 6 match(es)
boot-e672b454.export.zst: 0 match(es)
boot-e68d6d90.export.zst: 0 match(es)
boot-e792fe5f.export.zst: 0 match(es)
boot-e8152eae.export.zst: 0 match(es)
boot-e90c9c57.export.zst: 0 match(es)
  2026-08-17 11:17:38  usb 3-3: USB disconnect, device number 2
boot-e9399c8c.export.zst: 1 match(es)
  2026-08-16 18:48:02  usb usb3-port3: attempt power cycle
boot-ea26d5d0.export.zst: 1 match(es)
boot-eb117101.export.zst: 0 match(es)
boot-eddd1961.export.zst: 0 match(es)
boot-ef992099.export.zst: 0 match(es)
boot-f5de8066.export.zst: 0 match(es)
boot-f759ae02.export.zst: 0 match(es)
boot-f7e60123.export.zst: 0 match(es)
total: 70

[exited with code 0]
```
#### `results/incident-2026-11-12-1803/excerpt-port-3-3-resets-system-journal.txt`
```
# Every reset, power cycle and disconnect of USB port 3-3 (the Bluetooth controller) in the system journal
# Command (run 2026-11-13, finished ~03:30 CET):
#   journalctl _TRANSPORT=kernel --no-pager -o short-iso -g "usb 3-3: reset|usb3-port3: attempt power cycle|usb 3-3: USB disconnect" --since 2026-10-18
# The journal's oldest entry is 2026-10-22 11:32:06 (boot d479d374, the first of 15 boots in
# `journalctl --list-boots`), so this covers 2026-10-22 11:32 to 2026-11-13 03:27. journalctl
# prints no header for the first boot it reads (d479d374, no match).
# Reading: the only resets of 3-3 are BT-17's (boot 08956069, 2026-11-12 18:03). The two
# earlier disconnects are the BT-16 start-ups (boots 7323fc85 and 5e459fa0, each within two
# seconds of the boot's first journal entry). Output verbatim:
-- Boot 257d1599532e4cad941b5bb6178bb630 --
-- Boot 738e228bafbb448fb9fce135b81d500f --
-- Boot 46cb518810bb4927951068dc67ca6285 --
-- Boot e672b4545c844ab88758175b455f8906 --
-- Boot be19fc3924484f019317ebbaf4ff023b --
-- Boot 7323fc85d3e64f3380bde588818c46ed --
2026-11-05T19:33:05+01:00 n kernel: usb 3-3: USB disconnect, device number 2
-- Boot 045caff551104648900621801d2a9e82 --
-- Boot 1bbf9aeabb9545d68b380f4811e6a32f --
-- Boot e68d6d906ecd41169164b85c1f33dad7 --
-- Boot 5e459fa0b07241279e8c525593afb2b8 --
2026-11-11T18:58:34+01:00 n kernel: usb 3-3: USB disconnect, device number 2
-- Boot 7e87eae097cd4352b8963ddae2c4e3d4 --
-- Boot 0895606911384479be9cbd6a7f726000 --
2026-11-12T18:03:14+01:00 n kernel: usb 3-3: reset full-speed USB device number 2 using xhci_hcd
2026-11-12T18:03:14+01:00 n kernel: usb 3-3: reset full-speed USB device number 2 using xhci_hcd
2026-11-12T18:03:15+01:00 n kernel: usb 3-3: reset full-speed USB device number 2 using xhci_hcd
2026-11-12T18:03:15+01:00 n kernel: usb 3-3: reset full-speed USB device number 2 using xhci_hcd
2026-11-12T18:03:16+01:00 n kernel: usb 3-3: USB disconnect, device number 2
2026-11-12T18:03:18+01:00 n kernel: usb usb3-port3: attempt power cycle
-- Boot b314ca88f6a24949ae9e0ce1d624e820 --
2026-11-12T18:08:03+01:00 n kernel: usb usb3-port3: attempt power cycle
-- Boot 46cc4812abd1459d87df126ae80fbfac --
```

## 4. The defects (issue register, BT-17 to BT-23)
*(verbatim: `docs/issues.md`, from BT-17 to the end of BT-23)*
### BT-17 — With the patch loaded, an idle controller ignored its next command, was reset off the USB bus, and stayed off until a power-off

**Status 2026-11-12: observed once (boot `08956069`, 2026-11-12 18:03); cause not established.**
Evidence, with every command and its output: [`results/incident-2026-11-12-1803/`](../results/incident-2026-11-12-1803/README.md). That directory has eight focused log excerpts (kernel, userspace, HCI capture decode; addresses replaced). The full journals of the three boots (text and export format) and every capture are kept locally in the git-ignored `archive/incidents/20261112-bt17-controller-off-bus/` (with `SHA256SUMS`).

- **What:** boot `08956069`, `7.0.0-42` with E3, the first boot after a 7.5 min power-off.
  - Start-up was normal (`QCA: patch rome 0x302 build 0x3e8`, no start-up disconnect), so this is **not BT-16**.
  - The controller then sat idle for 161.98 s, with no ACL or SCO link.
  - At the operator's login (18:03:08) bluetoothd removed the greeter's profile UUIDs. The kernel's `Write Class of Device` (`0x0c24`) got **no event of any kind** (capture: last event #120 at 18:00:26.845).
  - `command 0x0c24 tx timeout` at 18:03:10.87.
  - USB resets from 18:03:14.12 failed with `-71`, and the device disconnected at 18:03:16.18. Re-enumeration failed, ending in `unable to enumerate USB device` (18:03:19).
  - The 18:07 **reboot** did not bring it back: in boot `b314ca88` the device is not on the bus (`error -71` at enumeration), while the card's Wi-Fi works.
- **Like BT-1 in shape, unlike it in conditions.** As in BT-1, the first command after a change got no reply, the controller left the bus after a reset, and only a power-off recovers it (BRIEF §0). Unlike BT-1:
  - the patch was loaded (BT-1's cause was the ROM firmware, fixed by `dc16388d45ec`);
  - no SCO stream existed;
  - the change was 162 s of idle.

  It is the first timeout in nine E3 trials and 74 E1/E3 links (`evidence/trials/results.tsv`, E3 #9). So the device-table fix does not cover it, and it gets its own row.
- **The reset path (source, Ubuntu `7.0.0-42`):**
  - `hci_cmd_timeout()` calls `hdev->reset` on the **first** timeout (`net/bluetooth/hci_core.c:1477`).
  - `BTUSB_QCA_ROME` sets `hdev->reset = btusb_qca_reset` (`drivers/bluetooth/btusb.c:4406`).
  - Without a reset GPIO that becomes `btusb_reset()`: `usb_queue_reset_device()` (`btusb.c:1034-1051`).
  - `Failed usb_autopm_get_interface: -16` at 18:03:16.18 shows the path was entered.
  - **Not established:** what issued the first USB reset at 18:03:14.12. `Resetting usb device.` is not in the journal.
  - If it was the kernel's own reset, the same entry that fixed BT-1 also makes the kernel apply, automatically, the action that drove a wedged controller here off the bus in two controlled tests (`EX-023`, the 2026-08-15 boot). That is an inference to test, not a finding.
- **Candidates (not traced, not rows):**
  1. Whether runtime autosuspend was involved. `CONFIG_BT_HCIBTUSB_AUTOSUSPEND=y` and no override is installed (`/etc/modprobe.d/btusb-qca9377.conf.disabled`). The 162 s idle and the first command after it fit a failed resume, but btusb debug output was off, so no record shows whether the device was suspended. The earlier "autosuspend mitigation" claim for BT-1 is retracted (BRIEF §5); that retraction is about ROM firmware and does not decide this case.
  2. The reset-on-first-timeout policy for ROME controllers without a reset GPIO.
  3. The kernel's mgmt status `0x05` "Authentication Failed" for a command that timed out (`-ETIMEDOUT` mapping; check in source).
  4. *This project's trial tool:* `usb_lost` counts every USB disconnect on the machine (E3 #6: 82, all on ports `3-2`/`4-2`, none on `3-3`).
- **Falsifiers / next:**
  - Recurrence on `7.0.0-43` (its stock btusb carries the entry; E3 is not used there).
  - Whether a recurrence follows an idle period again.
  - Whether `power/runtime_status` of the controller's USB device reads `suspended` during idle (a sysfs read, safe).
  - Whether the first reset carries `Resetting usb device.` with btusb debug on.
- **Recovery:** full power-off. **Reportable:** not yet; one occurrence.
- **2026-11-12 22:57, after the power-off** (boot `46cc4812`, `7.0.0-43`, stock btusb, off ~8.4 min since 22:46:44):
  - The controller is back: `QCA: patch rome 0x302 build 0x3e8`, `hci0`, bluetoothd `Number of controllers: 1`.
  - The loaded btusb srcversion is `4B2BD2C14BA4918C28E7208`, equal to `modinfo -F srcversion` of `-43`'s stock `btusb.ko.zst`, and there is no out-of-tree taint line.
  - **The idle controller is runtime-suspended.** `/sys/bus/usb/devices/3-3/power/`: `control auto`, `autosuspend_delay_ms 2000`, `runtime_status suspended`, `runtime_suspended_time 145431` of ~158,500 ms.
  - So every idle period suspends it, and the first command after one resumes it. That fits candidate 1 and is not proof: the same was presumably true on every earlier E3 boot (same Kconfig, no override). Next: whether a recurrence again follows a suspend, which needs btusb debug or a runtime-PM trace.
- **2026-11-13, read from the archived full kernel log (btusb debug was on, from `bt-dyndbg`; the earlier "debug off" line above is wrong):**
  - **The controller was runtime-suspended when the command was sent, and it never resumed.** btusb's `intf %p` prints (`btusb_suspend()`/`btusb_resume()`) show a device suspend at 18:00:28.857, 2.011 s after the last answer, and no `btusb_resume()` before the disconnect at 18:03:16. Monotonic times: suspended 160.83 s; command sent at 178.731; first USB reset at 184.023, 5.291 s later.
  - Excerpts: `results/incident-2026-11-12-1803/excerpt-boot-1-btusb-suspend-cycles.txt` and `excerpt-boot-2-btusb-suspend-cycles.txt`, written by `tools/suspend-cycles.py`. The boot before (`7e87eae0`, same setup) resumed 8 times, including after suspends of 2,950 s and 4,250 s.
  - **Source reading (hypotheses, not findings):**
    - H1: the first reset is the USB core's reset-resume. `finish_port_resume()` retries a failed post-resume GET_STATUS (5,000 ms timeout) as a reset-resume, since `persist` is 1. That would explain why btusb's `Resetting usb device.` (`bt_dev_err`) never appears.
    - H2: `hci_cmd_timeout()` → `btusb_reset()` waited 5.3 s in `usb_autopm_get_interface()` behind that resume, then got `-EBUSY` (`rpm_resume()`'s parent check), so the command credit came back only at 186.083.
  - **Candidate H3:** mainline `dcaf83ead130` sets `BTUSB_WAKEUP_BROKEN` (no runtime suspend with remote wakeup armed) for MT7922/MT7925 on Ryzen root hubs. It describes the same symptom: unresponsive, resetting the root hub does not help, only a power cycle recovers. This laptop is a Ryzen 7 5825U, and the controller is a direct child of the SoC root hub (`1022:1639`). It is not traced as ours yet.
  - `mgmt_errno_status()` maps `-ETIMEDOUT` to `MGMT_STATUS_AUTH_FAILED` (`mgmt.c:299`): candidate 3 is confirmed in source.
  - Outside source review requested: `reviews/2026-11-13T0003Z-bt17-source-investigation-task.md`.
- **2026-11-13, the outside reviews** (five answers, `reviews/2026-11-13T02*`–`T04*-bt17-source-investigation-reviewer-*-verbatim.md`, each with our checks in its header):
  - **H2 holds**, by all five. The log alone proves it: no `cmd_cnt` line between 18:03:08.8 and 18:03:16.2 although three commands were queued on the ordered HCI workqueue (sixth review).
  - **H1 is the best fit**, by all five. With the xHCI driver's own 40 ms resume drive and the port reset (60 ms) and its recovery (50 ms) that precede the `reset full-speed` line, the fixed waits come to 5,200 ms of the 5,291 ms; about 91 ms is left for scheduling. Open: who started the resume (host or a remote wakeup), and which branch issued the reset.
  - **H3 is a candidate for an A/B test, not a finding**, by all five.
  - **Corrections to our brief:**
    - frame #122 never reached the hardware: `BTUSB_SUSPENDING` was still set, so btusb parked it on the deferred anchor;
    - the capture proves only core send attempts (the monitor copy precedes the `HCI_RUNNING` test);
    - a missing `btusb_resume()` print alone does not prove a failed resume; the failed reset-resume and the disconnect do.
  - **New, verified:** a queued xHCI fix matches the tail of our log (BT-22).
- **2026-11-13, reproduced in emulation** (`results/bt17-emulation-2026-11-13/`):
  - Setup: real btusb (bluetooth-next `da3cc0258`) in a QEMU guest, bound through usbip to an emulated `13d3:3503` (QCA ROME path, full speed, remote wakeup). It stops answering at a chosen resume: GET_STATUS held, then `-71` after the host gives up.
  - **The laptop's sequence comes out step by step, with the USB core debug lines the laptop lacked:**
    - `usb auto-resume`, `finish resume`, `tx timeout` at +2.05 s;
    - MGMT status `0x05` for the class write;
    - `retry with reset-resume`, first `reset full-speed` at +5.38 s (laptop: +5.29 s);
    - four resets, `gone after usb resume?`, `USB disconnect` at +7.43 s (laptop: +7.35 s);
    - `Failed usb_autopm_get_interface: -16` 2 ms later; no `Resetting usb device.`
  - So H1 and H2 hold for this kernel's code when a device stops answering after a host-initiated runtime resume. What made the real controller stop answering is not addressed by this; it needs a recurrence on the laptop.
  - **Found with it:** BT-18, BT-19, BT-20 (btusb) and BT-21 (MGMT); BT-23 reproduced with a widened window; patch candidates in CO-43 (five) and CO-44.

---

### BT-18 — After a successful runtime reset-resume, btusb is never resumed and Bluetooth stays dead

**Status 2026-11-13: reproduced in emulation; fix candidate CO-43 D; not seen on the laptop (there the reset-resume failed).**
- **What:** when a runtime resume fails and USB persist is on, the USB core resets the device. btusb has no `reset_resume` callback, so `usb_resume_interface()` only marks its interfaces for rebinding (`no reset_resume for driver btusb?`). The core rebinds marked interfaces only after a system resume (`usb_resume_complete()`) or a `usb_reset_device()`, not after a runtime resume (`drivers/usb/core/driver.c`, bluetooth-next `da3cc0258`).
- **Effect:** btusb stays bound and is never resumed. `BTUSB_SUSPENDING` stays set and the suspend count is off by one, so every URB is parked on the deferred anchor. The controller answers USB requests, yet Bluetooth is dead until unplug or reboot.
- **Reproduced** (`close-recover` scenario):
  - the resume is started by powering hci0 off (`btusb_close()` takes a PM reference), the device answers again after the reset-resume;
  - the next power-on fails: HCI Reset `0x0c03` `-110` twice, never sent, MGMT status `0x05`;
  - when the resume is started by a command instead, btusb's own reset from the command timeout rebinds it by accident (BT-19).
- **Fix candidate:** CO-43 D, a `reset_resume` that resumes and queues a reset, so the core rebinds btusb and the controller is set up again.

### BT-19 — `btusb_reset()` blocks the HCI workqueue behind a failing resume, and resets a reset-resumed device again

**Status 2026-11-13: in the laptop's log (H2) and reproduced in emulation; fix candidate CO-43 B.**
- **What:**
  - `hci_cmd_timeout()` calls `hdev->reset` on the ordered `hdev->workqueue` before it restores the credit. `btusb_reset()` first calls `usb_autopm_get_interface()`, which waits for the resume in progress.
  - The command that timed out never reached the controller (still on the deferred anchor).
- **Effect:**
  - the HCI workqueue (cmd, RX, TX work) is blocked 5.3 s on the laptop, 5.4 s in emulation;
  - when the reset-resume succeeds, the waiting reset then resets the device once more (`Resetting usb device.` after the rebinding).
- **Fix candidate:** CO-43 B. Don't reset while `BTUSB_SUSPENDING` is set and the interface is not runtime-active; if it is active although btusb was not resumed (BT-18 without D), reset as before.

### BT-20 — `btusb_waker()` swallows a failed resume

**Status 2026-11-13: in source; shown in emulation; fix candidate CO-43 A.**
- **What:** the waker returns on a failed `usb_autopm_get_interface()` without a message (bluetooth-next `btusb_main.c:2656`, from `7bee549e197c`, 2009). At the default log level the only trace of a failed resume is the HCI timeout two seconds later, which points at the controller.
- **Fix candidate:** CO-43 A, log the error (except `-EACCES`, a system sleep transition).

### BT-21 — MGMT reports a command timeout as "Authentication Failed"

**Status 2026-11-13: in the laptop's log (bluetoothd: "Failed to remove UUID: Authentication Failed (0x05)") and reproduced; fix candidate CO-44.**
- **What:** `mgmt_errno_status()` maps `-ETIMEDOUT` to `MGMT_STATUS_AUTH_FAILED`, since `161510ccf91c` (2021-10-27), with no stated reason. `MGMT_STATUS_TIMEOUT` (0x08) exists.
- **Reproduced:** a new mgmt-tester case, whose emulated controller never answers Write Class of Device, fails on bluetooth-next with 0x05 and passes with the one-line fix. The other 526 mgmt-tester cases, l2cap-tester (144) and smp-tester (8) are unchanged (`agent-work/bt17-mgmt-timeout/`, logs with SHA256SUMS).
- **Audit:** pairing paths use the HCI status table, not this function, so they are unaffected. bluetoothd only logs the text for the sync-queued commands; nothing in BlueZ depends on 0x05 for a timeout.

### BT-22 — xHCI: ep0 maxpacket update on a slot left Enabled (another author's fix, queued)

**Status 2026-11-13: in the laptop's log (the BT-17 tail); fixed by another author, queued by the xHCI maintainer on 2026-11-09; not ours.**
- **What:** after an Address Device transaction error the slot is left Enabled. `xhci_check_ep0_maxpacket()` then issues Evaluate Context on it (`WARN: invalid context state for evaluate context command`, harmless) and corrupts the input context, so the next Address Device is refused with Parameter Error (`completion code 0x11`).
- **The fix:** "[PATCH] usb: xhci: Fix ep0 maxpacket update on enabled slots", Michal Pecio, 2026-11-09, `<20261109112846.04bfeb0f.michal.pecio@gmail.com>`; "Added to queue" by Mathias Nyman the same day.
- **On the laptop:** the code it fixes is in v7.0 and in Ubuntu's `-42` (no hunk there). Our log has the sequence for the full-speed device at 18:03:15.65–15.97. It made the reset retries fail in a messier way; it did not cause the loss: the device had already failed a descriptor read, and the next boot's fresh xHCI could not read it either.
- **Next:** watch for it in mainline and stable; an Ubuntu backport candidate.

### BT-23 — btusb: a URB can be parked on the deferred anchor after the resume that would send it

**Status 2026-11-13: race from source (seventh review), reproduced in emulation with the window widened by a debug-only delay; fix candidate CO-43 E; not BT-17.**
- **Reproduced:** `bt23` scenario, with a 400 ms delay after the decision (debug-only module parameter) and a resume forced meanwhile (`power/control=on`):
  - unpatched: btusb's resume ran, the command was parked after it, and the class write timed out after 2.02 s with MGMT 0x05, 3 of 3;
  - with E: answered after the 0.40 s delay, 2 of 2;
  - 20 healthy cycles on the E kernel: 20 of 20, latency unchanged.
- Without the delay the window is a few instructions wide. How often it occurs on real hardware is unknown.
- **What:** `submit_or_queue_tx_urb()` reads `BTUSB_SUSPENDING` under `txlock`, releases the lock, and only then anchors the URB on `deferred`. `btusb_resume()` drains `deferred` and clears the flag under `txlock`. A resume completing in between leaves the URB parked while the device is active, until the next suspend/resume cycle.
- **Fix candidate:** CO-43 E, "Bluetooth: btusb: Anchor a deferred URB under txlock": the anchoring moves into the decision's critical section. The lock order is unchanged: `btusb_resume()` already takes the anchor's lock inside `txlock`.

## 5. The patches, in full
Applied in this order on bluetooth-next `da3cc0258`. No Signed-off-by yet: the author adds his own when sending. The file in the tree is `drivers/bluetooth/btusb_main.c` (bluetooth-next splits btusb; Ubuntu's `7.0.0-42` still has one `btusb.c`, and all five apply to it with line offsets only).
### CO-43 (btusb)
#### `contributions/CO-43-btusb-runtime-resume-failure/patch/0001-Bluetooth-btusb-Report-a-failed-resume-for-deferred-.patch`
```diff
From 71a90d1a16699a9422c5289a280fe4202211c3dc Mon Sep 17 00:00:00 2001
From: Iaroslav Voitovych <yaroslav.voytovych@gmail.com>
Date: Fri, 13 Nov 2026 04:24:55 +0100
Subject: [PATCH 1/5] Bluetooth: btusb: Report a failed resume for deferred
 data

When data is sent while the device is runtime suspended,
submit_or_queue_tx_urb() anchors the URB on data->deferred and
btusb_waker() resumes the device. If that resume fails, the waker
returns without a word and the URB stays deferred, so the only trace
at the default log level is the HCI command timeout two seconds later,
which points at the controller rather than at the resume.

This happened with an idle QCA9377 (13d3:3503) that did not answer the
GET_STATUS after a runtime resume: the log showed "command 0x0c24 tx
timeout" and USB resets, and nothing that said the resume had failed.

Log the error, except -EACCES: then runtime PM is disabled for a
system sleep transition, and btusb_resume() sends the deferred data
when it ends.
---
 drivers/bluetooth/btusb_main.c | 9 ++++++++-
 1 file changed, 8 insertions(+), 1 deletion(-)

diff --git a/drivers/bluetooth/btusb_main.c b/drivers/bluetooth/btusb_main.c
index 95398e2ca..a7d36e84a 100644
--- a/drivers/bluetooth/btusb_main.c
+++ b/drivers/bluetooth/btusb_main.c
@@ -2659,8 +2659,15 @@ static void btusb_waker(struct work_struct *work)
 	int err;
 
 	err = usb_autopm_get_interface(data->intf);
-	if (err < 0)
+	if (err < 0) {
+		/* -EACCES: runtime PM is disabled for a system sleep transition,
+		 * and btusb_resume() sends the deferred data when it ends.
+		 */
+		if (err != -EACCES)
+			bt_dev_err(data->hdev, "Failed to resume device for deferred data: %d",
+				   err);
 		return;
+	}
 
 	usb_autopm_put_interface(data->intf);
 }
```
#### `contributions/CO-43-btusb-runtime-resume-failure/patch/0002-Bluetooth-btusb-Don-t-reset-a-device-that-has-not-re.patch`
```diff
From 64775948647a7f234060996cb063139f767fd6ef Mon Sep 17 00:00:00 2001
From: Iaroslav Voitovych <yaroslav.voytovych@gmail.com>
Date: Fri, 13 Nov 2026 04:25:10 +0100
Subject: [PATCH 2/5] Bluetooth: btusb: Don't reset a device that has not
 resumed

hci_cmd_timeout() calls hdev->reset() on the ordered HCI workqueue and
restores the command credit only when it returns. btusb_reset() first
takes a runtime PM reference with usb_autopm_get_interface(). If the
command timed out because the device is still resuming, that call
waits for the resume to end. When the device does not answer, the USB
core spends more than five seconds on it (the GET_STATUS timeout, then
a reset-resume and its retries), and the HCI workqueue, including RX
and TX work, is blocked all that time.

The command that timed out never reached the controller: btusb sets
BTUSB_SUSPENDING at suspend and clears it only in btusb_resume(), and
while it is set submit_or_queue_tx_urb() parks every URB on the
deferred anchor. A failed resume is already handled by the USB core,
which tries a reset-resume and disconnects the device if that fails
too. If the reset-resume succeeds, the core rebinds the interface,
because btusb has no reset_resume callback, and the reset queued here
then resets the device a second time.

Both were seen with an emulated QCA9377 (13d3:3503) whose GET_STATUS
after a runtime resume was never answered, as on a laptop where that
controller was lost: "Failed usb_autopm_get_interface: -16" was
logged 5.4 s after the command timeout, at the disconnect; with a
device that came back after the reset-resume, "Resetting usb device."
followed the rebinding and reset it again.

So don't reset, and don't wait, while BTUSB_SUSPENDING is set.
---
 drivers/bluetooth/btusb_main.c | 17 +++++++++++++++++
 1 file changed, 17 insertions(+)

diff --git a/drivers/bluetooth/btusb_main.c b/drivers/bluetooth/btusb_main.c
index a7d36e84a..9c66ab5d8 100644
--- a/drivers/bluetooth/btusb_main.c
+++ b/drivers/bluetooth/btusb_main.c
@@ -1098,6 +1098,23 @@ static void btusb_reset(struct hci_dev *hdev)
 	int err;
 
 	data = hci_get_drvdata(hdev);
+
+	/* The device has not finished its resume, so the command that timed
+	 * out is still waiting on the deferred anchor and never reached the
+	 * controller. A resume that fails is handled by the USB core (a
+	 * reset-resume, then a disconnect), and resetting from here would
+	 * first block the HCI workqueue until that resume has ended.
+	 *
+	 * If the interface is active although btusb_resume() never ran, the
+	 * device was reset-resumed and btusb was not called back: then the
+	 * reset below, which unbinds and rebinds btusb, is what recovers it.
+	 */
+	if (test_bit(BTUSB_SUSPENDING, &data->flags) &&
+	    !pm_runtime_active(&data->intf->dev)) {
+		bt_dev_err(hdev, "Device not resumed; not resetting");
+		return;
+	}
+
 	err = usb_autopm_get_interface(data->intf);
 	if (err) {
 		bt_dev_err(hdev, "Failed usb_autopm_get_interface: %d", err);
```
#### `contributions/CO-43-btusb-runtime-resume-failure/patch/0003-Bluetooth-btusb-Recover-after-a-reset-resume.patch`
```diff
From 7d94e97d0a0b216380cc78a4faef70a005bc4a6b Mon Sep 17 00:00:00 2001
From: Iaroslav Voitovych <yaroslav.voytovych@gmail.com>
Date: Fri, 13 Nov 2026 05:05:15 +0100
Subject: [PATCH 3/5] Bluetooth: btusb: Recover after a reset-resume

When a runtime resume fails and USB persist is enabled, the USB core
resets the device (a reset-resume). btusb has no reset_resume
callback, so usb_resume_interface() only marks its interfaces for
rebinding. Marked interfaces are rebound after a system resume
(usb_resume_complete()) and after usb_reset_device(), but not after a
runtime resume. btusb therefore stays bound without ever being
resumed: BTUSB_SUSPENDING stays set, its suspend count is off by one,
and every URB it sends from then on is parked on the deferred anchor.
The controller answers USB requests, but Bluetooth is dead until the
device is unplugged or the machine rebooted.

With an emulated QCA9377 (13d3:3503) that answered its GET_STATUS only
after the reset-resume, closing hci0 (which runtime-resumes the
device) left it in that state: the next power-on failed with HCI Reset
timeouts that never reached the device. When the resume was started
by a command, btusb_reset() from the command timeout happened to
recover it, by resetting the device once more.

Add a reset_resume callback that resumes as usual and queues a USB
reset. With no pre_reset and post_reset callbacks, the core then
unbinds and rebinds btusb, so the controller, which the reset may have
cleared, is set up again.

At a system resume, a reset-resume was already followed by a rebinding
(usb_resume_complete()): for the devices of
btusb_needs_reset_resume_table, and for Realtek devices, whose
btusb_suspend() sets reset_resume when wakeup is disabled. With this
change those are rebound by the queued reset instead, that is after
one more USB reset. That path was not tested: the emulated device
cannot take part in a system sleep.
---
 drivers/bluetooth/btusb_main.c | 26 ++++++++++++++++++++++++++
 1 file changed, 26 insertions(+)

diff --git a/drivers/bluetooth/btusb_main.c b/drivers/bluetooth/btusb_main.c
index 9c66ab5d8..4d2f4e136 100644
--- a/drivers/bluetooth/btusb_main.c
+++ b/drivers/bluetooth/btusb_main.c
@@ -5106,6 +5106,31 @@ static int btusb_resume(struct usb_interface *intf)
 	return err;
 }
 
+static int btusb_reset_resume(struct usb_interface *intf)
+{
+	struct btusb_data *data = usb_get_intfdata(intf);
+	int err;
+
+	BT_DBG("intf %p", intf);
+
+	/* The USB core reset the device to resume it. Without this callback
+	 * it marks the interfaces for rebinding, but it rebinds them only
+	 * after a system resume: after a runtime resume btusb stayed bound
+	 * and was never resumed, with BTUSB_SUSPENDING set and every later
+	 * URB parked on the deferred anchor.
+	 *
+	 * Resume as usual, then queue a USB reset: btusb has no pre_reset
+	 * and post_reset callbacks, so the core unbinds and rebinds it, and
+	 * the controller, whose state the reset may have cleared, is set up
+	 * again.
+	 */
+	err = btusb_resume(intf);
+	if (intf == data->intf)
+		usb_queue_reset_device(intf);
+
+	return err;
+}
+
 #ifdef CONFIG_DEV_COREDUMP
 static void btusb_coredump(struct device *dev)
 {
@@ -5123,6 +5148,7 @@ static struct usb_driver btusb_driver = {
 	.disconnect	= btusb_disconnect,
 	.suspend	= pm_ptr(btusb_suspend),
 	.resume		= pm_ptr(btusb_resume),
+	.reset_resume	= pm_ptr(btusb_reset_resume),
 	.id_table	= btusb_table,
 	.supports_autosuspend = 1,
 	.disable_hub_initiated_lpm = 1,
```
#### `contributions/CO-43-btusb-runtime-resume-failure/patch/0004-Bluetooth-btusb-Anchor-a-deferred-URB-under-txlock.patch`
```diff
From 3fef237b910df782f6940d7c9770fdf33bbbd758 Mon Sep 17 00:00:00 2001
From: Iaroslav Voitovych <yaroslav.voytovych@gmail.com>
Date: Fri, 13 Nov 2026 04:42:06 +0100
Subject: [PATCH 4/5] Bluetooth: btusb: Anchor a deferred URB under txlock

submit_or_queue_tx_urb() reads BTUSB_SUSPENDING under txlock, drops
the lock, and only then anchors the URB on data->deferred.
btusb_resume() sends the deferred URBs and clears BTUSB_SUSPENDING
under txlock. If the resume completes in between, the URB is anchored
after the drain: it is not sent, and the waker it schedules finds the
device active and does nothing. The URB then waits for the next
suspend and resume, and an HCI command in it times out.

Anchor the URB in the same critical section as the decision.
btusb_resume() takes the anchor's lock inside txlock as well
(play_deferred() under txlock), so the lock order does not change.

Seen with a delay inserted after the decision and a resume forced
meanwhile: a command was parked on an active device and timed out;
with this change it was sent at that resume.
---
 drivers/bluetooth/btusb_main.c | 7 ++++++-
 1 file changed, 6 insertions(+), 1 deletion(-)

diff --git a/drivers/bluetooth/btusb_main.c b/drivers/bluetooth/btusb_main.c
index 4d2f4e136..1c1cbf6bb 100644
--- a/drivers/bluetooth/btusb_main.c
+++ b/drivers/bluetooth/btusb_main.c
@@ -2408,16 +2408,21 @@ static int submit_or_queue_tx_urb(struct hci_dev *hdev, struct urb *urb)
 	unsigned long flags;
 	bool suspending;
 
+	/* Decide and anchor under txlock: btusb_resume() sends the deferred
+	 * URBs and clears BTUSB_SUSPENDING under the same lock, so a URB
+	 * anchored after that would wait for the next resume.
+	 */
 	spin_lock_irqsave(&data->txlock, flags);
 	suspending = test_bit(BTUSB_SUSPENDING, &data->flags);
 	if (!suspending)
 		data->tx_in_flight++;
+	else
+		usb_anchor_urb(urb, &data->deferred);
 	spin_unlock_irqrestore(&data->txlock, flags);
 
 	if (!suspending)
 		return submit_tx_urb(hdev, urb);
 
-	usb_anchor_urb(urb, &data->deferred);
 	schedule_work(&data->waker);
 
 	usb_free_urb(urb);
```
#### `contributions/CO-43-btusb-runtime-resume-failure/patch/0005-Bluetooth-btusb-Disable-runtime-suspend-of-QCA9377-1.patch`
```diff
From c85b3899eb7b2dd9daa2cfa287e675911cd78607 Mon Sep 17 00:00:00 2001
From: Iaroslav Voitovych <yaroslav.voytovych@gmail.com>
Date: Fri, 13 Nov 2026 04:30:55 +0100
Subject: [PATCH 5/5] Bluetooth: btusb: Disable runtime suspend of QCA9377
 13d3:3503 on Ryzen

RFC, not for merging as is: one occurrence on one laptop.

On a laptop with a Ryzen 7 5825U, an IMC Networks QCA9377 (13d3:3503),
a direct child of the SoC's xHCI root hub (1022:1639), was runtime
suspended for 160 s with the HCI device open and no connection. The
next command started a resume; the device did not answer its
GET_STATUS, the USB core's reset-resume failed, the device was
disconnected, and it stayed off the bus through a reboot. Only a power
cycle brought it back. The device had come back from eight runtime
suspends, of up to 71 minutes, in the boot before.

That is the failure that commit dcaf83ead130 ("Bluetooth: Properly
disable remote wakeup for MT7922/MT7925 on Ryzen platform") describes
for two MediaTek devices on Ryzen root hubs, though there the resume
was started by a remote wakeup. Apply the same condition to this device:
no runtime suspend while the HCI device is open with remote wakeup
armed, on a Ryzen platform, when it is a direct child of a root hub.

The cost is the device's runtime suspend while Bluetooth is on.
---
 drivers/bluetooth/btusb_main.c | 11 +++++++++++
 1 file changed, 11 insertions(+)

diff --git a/drivers/bluetooth/btusb_main.c b/drivers/bluetooth/btusb_main.c
index 1c1cbf6bb..2aae27d84 100644
--- a/drivers/bluetooth/btusb_main.c
+++ b/drivers/bluetooth/btusb_main.c
@@ -4683,6 +4683,17 @@ static int btusb_probe(struct usb_interface *intf,
 		hdev->reset = btusb_qca_reset;
 		hci_set_quirk(hdev, HCI_QUIRK_SIMULTANEOUS_DISCOVERY);
 		btusb_check_needs_reset_resume(intf);
+
+		/* An idle IMC Networks QCA9377 (13d3:3503) attached to a Ryzen
+		 * root hub failed to answer after a runtime resume, and only a
+		 * power cycle brought it back, as reported for MT7922/MT7925
+		 * in btusb_mtk_setup(). Keep it out of runtime suspend while
+		 * the HCI device is open.
+		 */
+		if (id->idVendor == 0x13d3 && id->idProduct == 0x3503 &&
+		    platform_is_ryzen() &&
+		    is_direct_child_of_root_hub(interface_to_usbdev(intf)))
+			set_bit(BTUSB_WAKEUP_BROKEN, &data->flags);
 	}
 
 	if (id->driver_info & BTUSB_QCA_WCN6855) {
```
### CO-44 (MGMT, and its BlueZ test)
#### `contributions/CO-44-mgmt-timeout-reported-as-auth-failed/patch/0001-Bluetooth-MGMT-Report-a-timed-out-command-as-MGMT_ST.patch`
```diff
From 0c5ea70d6182733c0c8e8f24e21f23c196217c93 Mon Sep 17 00:00:00 2001
From: Iaroslav Voitovych <yaroslav.voytovych@gmail.com>
Date: Fri, 13 Nov 2026 04:19:58 +0100
Subject: [PATCH] Bluetooth: MGMT: Report a timed out command as
 MGMT_STATUS_TIMEOUT

mgmt_errno_status() maps -ETIMEDOUT to MGMT_STATUS_AUTH_FAILED. The
-ETIMEDOUT comes from the HCI command layer when the controller does not
answer a command in time (__hci_cmd_sync_sk() and hci_cmd_timeout()), or
when the controller itself reports a connection timeout status, so no
authentication is involved.

As a result, when the controller stops responding, user space is told
that authentication failed. For example, a Write Class of Device that
times out during Add UUID or Remove UUID completes with 0x05 and
bluetoothd logs "Failed to remove UUID: Authentication Failed (0x05)".
This sends anyone reading the log to look at pairing and keys instead of
at the controller.

MGMT_STATUS_TIMEOUT (0x08) already exists and is what the HCI status
table in this file returns for Connection Timeout, Host Timeout and
Directed Advertising Timeout. Return it for -ETIMEDOUT as well.

Fixes: 161510ccf91c ("Bluetooth: hci_sync: Make use of hci_cmd_sync_queue set 1")
---
 net/bluetooth/mgmt.c | 2 +-
 1 file changed, 1 insertion(+), 1 deletion(-)

diff --git a/net/bluetooth/mgmt.c b/net/bluetooth/mgmt.c
index 6ed3bf6f1..0056e3484 100644
--- a/net/bluetooth/mgmt.c
+++ b/net/bluetooth/mgmt.c
@@ -295,7 +295,7 @@ static u8 mgmt_errno_status(int err)
 	case -EBUSY:
 		return MGMT_STATUS_BUSY;
 	case -ETIMEDOUT:
-		return MGMT_STATUS_AUTH_FAILED;
+		return MGMT_STATUS_TIMEOUT;
 	case -ENOMEM:
 		return MGMT_STATUS_NO_RESOURCES;
 	case -EISCONN:
```
#### `contributions/CO-44-mgmt-timeout-reported-as-auth-failed/patch/0001-mgmt-tester-Add-Set-Device-Class-timeout-test.patch`
```diff
From a23bf35d0f96a24e6a4a346b28d330897aeee849 Mon Sep 17 00:00:00 2001
From: Iaroslav Voitovych <yaroslav.voytovych@gmail.com>
Date: Fri, 13 Nov 2026 05:07:23 +0100
Subject: [PATCH BlueZ] mgmt-tester: Add Set Device Class timeout test

The emulated controller never answers Write Class of Device, so the
kernel's HCI command times out. Set Device Class shall then complete
with Timeout. Without the kernel change "Bluetooth: MGMT: Report a
timed out command as MGMT_STATUS_TIMEOUT" it completes with
Authentication Failed, which is what mgmt_errno_status() returns for
-ETIMEDOUT.
---
 tools/mgmt-tester.c | 34 ++++++++++++++++++++++++++++++++++
 1 file changed, 34 insertions(+)

diff --git a/tools/mgmt-tester.c b/tools/mgmt-tester.c
index b7126dc36..4132003fd 100644
--- a/tools/mgmt-tester.c
+++ b/tools/mgmt-tester.c
@@ -2493,6 +2493,16 @@ static const struct generic_data set_dev_class_invalid_param_test_1 = {
 	.expect_status = MGMT_STATUS_INVALID_PARAMS,
 };
 
+static const struct generic_data set_dev_class_timeout_test_1 = {
+	.setup_settings = settings_powered,
+	.send_opcode = MGMT_OP_SET_DEV_CLASS,
+	.send_param = set_dev_class_valid_param,
+	.send_len = sizeof(set_dev_class_valid_param),
+	.expect_status = MGMT_STATUS_TIMEOUT,
+	.expect_param = set_dev_class_zero_rsp,
+	.expect_len = sizeof(set_dev_class_zero_rsp),
+};
+
 static const char add_spp_uuid_param[] = {
 			0xfb, 0x34, 0x9b, 0x5f, 0x80, 0x00, 0x00, 0x80,
 			0x00, 0x10, 0x00, 0x00, 0x01, 0x11, 0x00, 0x00,
@@ -12703,6 +12713,27 @@ static bool hook_delay_cmd(const void *data, uint16_t len, void *user_data)
 	return true;
 }
 
+static bool hook_drop_cmd(const void *data, uint16_t len, void *user_data)
+{
+	tester_print("Dropping HCI command, no response from emulator");
+	return false;
+}
+
+static void test_set_dev_class_timeout(const void *test_data)
+{
+	struct test_data *data = tester_get_data();
+
+	/* The controller never answers Write Class of Device, so the
+	 * kernel's HCI command times out and the MGMT command shall
+	 * complete with Timeout rather than Authentication Failed.
+	 */
+	hciemu_add_hook(data->hciemu, HCIEMU_HOOK_PRE_CMD,
+					BT_HCI_CMD_WRITE_CLASS_OF_DEV,
+					hook_drop_cmd, NULL);
+
+	test_command_generic(test_data);
+}
+
 static void test_add_remove_device_nowait(const void *test_data)
 {
 	struct test_data *data = tester_get_data();
@@ -14926,6 +14957,9 @@ int main(int argc, char *argv[])
 	test_bredrle("Set Device Class - Invalid parameters 1",
 				&set_dev_class_invalid_param_test_1,
 				NULL, test_command_generic);
+	test_bredrle_full("Set Device Class - Timeout 1",
+				&set_dev_class_timeout_test_1,
+				NULL, test_set_dev_class_timeout, 5);
 
 	test_bredrle("Add UUID - UUID-16 1",
 				&add_uuid16_test_1,
```
#### `contributions/CO-44-mgmt-timeout-reported-as-auth-failed/patch/bluez-mgmt-tester-set-dev-class-timeout.diff`
```diff
diff --git a/tools/mgmt-tester.c b/tools/mgmt-tester.c
index b7126dc36..4132003fd 100644
--- a/tools/mgmt-tester.c
+++ b/tools/mgmt-tester.c
@@ -2493,6 +2493,16 @@ static const struct generic_data set_dev_class_invalid_param_test_1 = {
 	.expect_status = MGMT_STATUS_INVALID_PARAMS,
 };
 
+static const struct generic_data set_dev_class_timeout_test_1 = {
+	.setup_settings = settings_powered,
+	.send_opcode = MGMT_OP_SET_DEV_CLASS,
+	.send_param = set_dev_class_valid_param,
+	.send_len = sizeof(set_dev_class_valid_param),
+	.expect_status = MGMT_STATUS_TIMEOUT,
+	.expect_param = set_dev_class_zero_rsp,
+	.expect_len = sizeof(set_dev_class_zero_rsp),
+};
+
 static const char add_spp_uuid_param[] = {
 			0xfb, 0x34, 0x9b, 0x5f, 0x80, 0x00, 0x00, 0x80,
 			0x00, 0x10, 0x00, 0x00, 0x01, 0x11, 0x00, 0x00,
@@ -12703,6 +12713,27 @@ static bool hook_delay_cmd(const void *data, uint16_t len, void *user_data)
 	return true;
 }
 
+static bool hook_drop_cmd(const void *data, uint16_t len, void *user_data)
+{
+	tester_print("Dropping HCI command, no response from emulator");
+	return false;
+}
+
+static void test_set_dev_class_timeout(const void *test_data)
+{
+	struct test_data *data = tester_get_data();
+
+	/* The controller never answers Write Class of Device, so the
+	 * kernel's HCI command times out and the MGMT command shall
+	 * complete with Timeout rather than Authentication Failed.
+	 */
+	hciemu_add_hook(data->hciemu, HCIEMU_HOOK_PRE_CMD,
+					BT_HCI_CMD_WRITE_CLASS_OF_DEV,
+					hook_drop_cmd, NULL);
+
+	test_command_generic(test_data);
+}
+
 static void test_add_remove_device_nowait(const void *test_data)
 {
 	struct test_data *data = tester_get_data();
@@ -14926,6 +14957,9 @@ int main(int argc, char *argv[])
 	test_bredrle("Set Device Class - Invalid parameters 1",
 				&set_dev_class_invalid_param_test_1,
 				NULL, test_command_generic);
+	test_bredrle_full("Set Device Class - Timeout 1",
+				&set_dev_class_timeout_test_1,
+				NULL, test_set_dev_class_timeout, 5);
 
 	test_bredrle("Add UUID - UUID-16 1",
 				&add_uuid16_test_1,
```
### Test tool only, not a candidate
#### `results/bt17-emulation-2026-11-13/patches/debug-only/0001-DEBUG-ONLY-btusb-bt23_delay_ms-widens-the-window-aft.patch`
```diff
From bd55bec1d356bec086740fbb514b7fa228256964 Mon Sep 17 00:00:00 2001
From: Iaroslav Voitovych <yaroslav.voytovych@gmail.com>
Date: Fri, 13 Nov 2026 04:42:21 +0100
Subject: [PATCH] DEBUG ONLY: btusb: bt23_delay_ms widens the window after the
 suspend decision

---
 drivers/bluetooth/btusb_main.c | 7 +++++++
 1 file changed, 7 insertions(+)

diff --git a/drivers/bluetooth/btusb_main.c b/drivers/bluetooth/btusb_main.c
index 5f6d90d43..bcd978102 100644
--- a/drivers/bluetooth/btusb_main.c
+++ b/drivers/bluetooth/btusb_main.c
@@ -36,6 +36,9 @@
 static bool disable_scofix;
 static bool force_scofix;
 static bool enable_autosuspend = IS_ENABLED(CONFIG_BT_HCIBTUSB_AUTOSUSPEND);
+/* DEBUG ONLY (BT-23 test) */
+static unsigned int bt23_delay_ms;
+module_param(bt23_delay_ms, uint, 0644);
 static bool enable_poll_sync = IS_ENABLED(CONFIG_BT_HCIBTUSB_POLL_SYNC);
 static bool reset = true;
 
@@ -2403,6 +2406,10 @@ static int submit_or_queue_tx_urb(struct hci_dev *hdev, struct urb *urb)
 		usb_anchor_urb(urb, &data->deferred);
 	spin_unlock_irqrestore(&data->txlock, flags);
 
+	/* DEBUG ONLY (BT-23 test): widen the window after the decision */
+	if (suspending && bt23_delay_ms)
+		mdelay(bt23_delay_ms);
+
 	if (!suspending)
 		return submit_tx_urb(hdev, urb);
 
```

## 6. The unpatched code they change (bluetooth-next `da3cc0258`)
Extracted with `git show da3cc0258:<path>`; each definition whole.
#### `drivers/bluetooth/btusb_main.c`: `btusb_reset` (from line 1095)
```c
static void btusb_reset(struct hci_dev *hdev)
{
	struct btusb_data *data;
	int err;

	data = hci_get_drvdata(hdev);
	err = usb_autopm_get_interface(data->intf);
	if (err) {
		bt_dev_err(hdev, "Failed usb_autopm_get_interface: %d", err);
		return;
	}

	if (test_and_set_bit(BTUSB_RESET, &data->flags))
		usb_autopm_put_interface_no_suspend(data->intf);

	bt_dev_err(hdev, "Resetting usb device.");
	usb_queue_reset_device(data->intf);
}
```
#### `drivers/bluetooth/btusb_main.c`: `btusb_qca_reset` (from line 1236)
```c
static void btusb_qca_reset(struct hci_dev *hdev)
{
	struct btusb_data *data = hci_get_drvdata(hdev);
	struct gpio_desc *reset_gpio = data->reset_gpio;

	if (test_bit(BTUSB_HW_SSR_ACTIVE, &data->flags)) {
		bt_dev_info(hdev, "Ramdump in progress, defer reset");
		return;
	}

	if (reset_gpio) {
		bt_dev_err(hdev, "Reset qca device via bt_en gpio");

		/* Toggle the hard reset line. The qca bt device is going to
		 * yank itself off the USB and then replug. The cleanup is handled
		 * correctly on the way out (standard USB disconnect), and the new
		 * device is detected cleanly and bound to the driver again like
		 * it should be.
		 */
		if (test_and_set_bit(BTUSB_HW_RESET_ACTIVE, &data->flags)) {
			bt_dev_err(hdev, "last reset failed? Not resetting again");
			return;
		}

		gpiod_set_value_cansleep(reset_gpio, 0);
		msleep(200);
		gpiod_set_value_cansleep(reset_gpio, 1);

		return;
	}

	btusb_reset(hdev);
}
```
#### `drivers/bluetooth/btusb_main.c`: `submit_or_queue_tx_urb` (from line 2388)
```c
static int submit_or_queue_tx_urb(struct hci_dev *hdev, struct urb *urb)
{
	struct btusb_data *data = hci_get_drvdata(hdev);
	unsigned long flags;
	bool suspending;

	spin_lock_irqsave(&data->txlock, flags);
	suspending = test_bit(BTUSB_SUSPENDING, &data->flags);
	if (!suspending)
		data->tx_in_flight++;
	spin_unlock_irqrestore(&data->txlock, flags);

	if (!suspending)
		return submit_tx_urb(hdev, urb);

	usb_anchor_urb(urb, &data->deferred);
	schedule_work(&data->waker);

	usb_free_urb(urb);
	return 0;
}
```
#### `drivers/bluetooth/btusb_main.c`: `btusb_waker` (from line 2656)
```c
static void btusb_waker(struct work_struct *work)
{
	struct btusb_data *data = container_of(work, struct btusb_data, waker);
	int err;

	err = usb_autopm_get_interface(data->intf);
	if (err < 0)
		return;

	usb_autopm_put_interface(data->intf);
}
```
#### `drivers/bluetooth/btusb_main.c`: `play_deferred` (from line 4989)
```c
static void play_deferred(struct btusb_data *data)
{
	struct urb *urb;
	int err;

	while ((urb = usb_get_from_anchor(&data->deferred))) {
		usb_anchor_urb(urb, &data->tx_anchor);

		err = usb_submit_urb(urb, GFP_ATOMIC);
		if (err < 0) {
			if (err != -EPERM && err != -ENODEV)
				BT_ERR("%s urb %p submission failed (%d)",
				       data->hdev->name, urb, -err);
			kfree(urb->setup_packet);
			usb_unanchor_urb(urb);
			usb_free_urb(urb);
			break;
		}

		data->tx_in_flight++;
		usb_free_urb(urb);
	}

	/* Cleanup the rest deferred urbs. */
	while ((urb = usb_get_from_anchor(&data->deferred))) {
		kfree(urb->setup_packet);
		usb_free_urb(urb);
	}
}
```
#### `drivers/bluetooth/btusb_main.c`: `btusb_suspend` (from line 4915)
```c
static int btusb_suspend(struct usb_interface *intf, pm_message_t message)
{
	struct btusb_data *data = usb_get_intfdata(intf);

	BT_DBG("intf %p", intf);

	/*
	 * It is reported that remote wakeup events could sometimes cause some
	 * adapters completely unresponsive. Resetting the xHCI root hub doesn't
	 * help at all, and recovering from such a state needs a power cycle.
	 * Since disabling remote wakeup simply causes the USB core to gate
	 * runtime autosuspend as well due to needs_remote_wakeup == 1, let's do
	 * this ourselves to make our life easier. The interface can be safely
	 * autosuspended as long as remote wakeup is disabled, i.e., after
	 * closing the HCI device.
	 *
	 * Don't auto-suspend if there are connections or discovery in progress.
	 *
	 * External suspend calls shall never fail. Specifically, a device with
	 * broken remote wakeup may still take the advantage of remote wakeup in
	 * order to wake up the system from sleep if userspace has enabled it as
	 * a wakeup source.
	 */
	if (PMSG_IS_AUTO(message) &&
	    ((test_bit(BTUSB_WAKEUP_BROKEN, &data->flags) && data->intf->needs_remote_wakeup) ||
	     hci_conn_count(data->hdev) || hci_discovery_active(data->hdev)))
		return -EBUSY;

	if (data->suspend_count++)
		return 0;

	spin_lock_irq(&data->txlock);
	if (!(PMSG_IS_AUTO(message) && data->tx_in_flight)) {
		set_bit(BTUSB_SUSPENDING, &data->flags);
		spin_unlock_irq(&data->txlock);
	} else {
		spin_unlock_irq(&data->txlock);
		data->suspend_count--;
		return -EBUSY;
	}

	cancel_work_sync(&data->work);

	if (data->suspend)
		data->suspend(data->hdev);

	btusb_stop_traffic(data);
	usb_kill_anchored_urbs(&data->tx_anchor);

	if (data->oob_wake_irq && device_may_wakeup(&data->udev->dev)) {
		set_bit(BTUSB_OOB_WAKE_ENABLED, &data->flags);
		enable_irq_wake(data->oob_wake_irq);
		enable_irq(data->oob_wake_irq);
	}

	/* For global suspend, Realtek devices lose the loaded fw
	 * in them. But for autosuspend, firmware should remain.
	 * Actually, it depends on whether the usb host sends
	 * set feature (enable wakeup) or not.
	 */
	if (test_bit(BTUSB_WAKEUP_AUTOSUSPEND, &data->flags)) {
		if (PMSG_IS_AUTO(message) &&
		    device_can_wakeup(&data->udev->dev))
			data->udev->do_remote_wakeup = 1;
		else if (!PMSG_IS_AUTO(message) &&
			 !device_may_wakeup(&data->udev->dev)) {
			data->udev->do_remote_wakeup = 0;
			data->udev->reset_resume = 1;
		}
	}

	return 0;
}
```
#### `drivers/bluetooth/btusb_main.c`: `btusb_resume` (from line 5019)
```c
static int btusb_resume(struct usb_interface *intf)
{
	struct btusb_data *data = usb_get_intfdata(intf);
	struct hci_dev *hdev = data->hdev;
	int err = 0;

	BT_DBG("intf %p", intf);

	if (--data->suspend_count)
		return 0;

	/* Disable only if not already disabled (keep it balanced) */
	if (test_and_clear_bit(BTUSB_OOB_WAKE_ENABLED, &data->flags)) {
		disable_irq(data->oob_wake_irq);
		disable_irq_wake(data->oob_wake_irq);
	}

	if (!test_bit(HCI_RUNNING, &hdev->flags))
		goto done;

	if (test_bit(BTUSB_INTR_RUNNING, &data->flags)) {
		err = btusb_submit_intr_urb(hdev, GFP_NOIO);
		if (err < 0) {
			clear_bit(BTUSB_INTR_RUNNING, &data->flags);
			goto failed;
		}
	}

	if (test_bit(BTUSB_BULK_RUNNING, &data->flags)) {
		err = btusb_submit_bulk_urb(hdev, GFP_NOIO);
		if (err < 0) {
			clear_bit(BTUSB_BULK_RUNNING, &data->flags);
			goto failed;
		}

		btusb_submit_bulk_urb(hdev, GFP_NOIO);
	}

	if (test_bit(BTUSB_ISOC_RUNNING, &data->flags)) {
		if (btusb_submit_isoc_urb(hdev, GFP_NOIO) < 0)
			clear_bit(BTUSB_ISOC_RUNNING, &data->flags);
		else
			btusb_submit_isoc_urb(hdev, GFP_NOIO);
	}

	if (data->resume)
		data->resume(hdev);

	spin_lock_irq(&data->txlock);
	play_deferred(data);
	clear_bit(BTUSB_SUSPENDING, &data->flags);
	spin_unlock_irq(&data->txlock);
	schedule_work(&data->work);

	return 0;

failed:
	usb_scuttle_anchored_urbs(&data->deferred);
done:
	spin_lock_irq(&data->txlock);
	clear_bit(BTUSB_SUSPENDING, &data->flags);
	spin_unlock_irq(&data->txlock);

	return err;
}
```
#### `drivers/bluetooth/btusb_main.c`: `btusb_driver` (from line 5096)
```c
static struct usb_driver btusb_driver = {
	.name		= "btusb",
	.probe		= btusb_probe,
	.disconnect	= btusb_disconnect,
	.suspend	= pm_ptr(btusb_suspend),
	.resume		= pm_ptr(btusb_resume),
	.id_table	= btusb_table,
	.supports_autosuspend = 1,
	.disable_hub_initiated_lpm = 1,

#ifdef CONFIG_DEV_COREDUMP
	.driver = {
		.coredump = btusb_coredump,
	},
#endif
};
```
#### `net/bluetooth/hci_core.c`: `hci_cmd_timeout` (from line 1525)
```c
/* HCI command timer function */
static void hci_cmd_timeout(struct work_struct *work)
{
	struct hci_dev *hdev = container_of(work, struct hci_dev,
					    cmd_timer.work);

	if (hdev->req_skb) {
		u16 opcode = hci_skb_opcode(hdev->req_skb);

		bt_dev_err(hdev, "command 0x%4.4x tx timeout", opcode);

		hci_cmd_sync_cancel_sync(hdev, ETIMEDOUT);
	} else {
		bt_dev_err(hdev, "command tx timeout");
	}

	if (hdev->reset)
		hdev->reset(hdev);

	atomic_set(&hdev->cmd_cnt, 1);
	queue_work(hdev->workqueue, &hdev->cmd_work);
}
```
#### `net/bluetooth/mgmt.c`: `mgmt_errno_status` (from line 284)
```c
static u8 mgmt_errno_status(int err)
{
	switch (err) {
	case 0:
		return MGMT_STATUS_SUCCESS;
	case -EPERM:
		return MGMT_STATUS_REJECTED;
	case -EINVAL:
		return MGMT_STATUS_INVALID_PARAMS;
	case -EOPNOTSUPP:
		return MGMT_STATUS_NOT_SUPPORTED;
	case -EBUSY:
		return MGMT_STATUS_BUSY;
	case -ETIMEDOUT:
		return MGMT_STATUS_AUTH_FAILED;
	case -ENOMEM:
		return MGMT_STATUS_NO_RESOURCES;
	case -EISCONN:
		return MGMT_STATUS_ALREADY_CONNECTED;
	case -ENOTCONN:
		return MGMT_STATUS_DISCONNECTED;
	case -ECANCELED:
		return MGMT_STATUS_CANCELLED;
	case -ERFKILL:
		return MGMT_STATUS_RFKILLED;
	}

	return MGMT_STATUS_FAILED;
}
```
#### `net/bluetooth/mgmt.c`: `mgmt_status` (from line 314)
```c
static u8 mgmt_status(int err)
{
	if (err < 0)
		return mgmt_errno_status(err);

	if (err < ARRAY_SIZE(mgmt_status_table))
		return mgmt_status_table[err];

	return MGMT_STATUS_FAILED;
}
```
#### `drivers/usb/core/driver.c`: `usb_resume_interface` (from line 1337)
```c
static int usb_resume_interface(struct usb_device *udev,
		struct usb_interface *intf, pm_message_t msg, int reset_resume)
{
	struct usb_driver	*driver;
	int			status = 0;

	if (udev->state == USB_STATE_NOTATTACHED)
		goto done;

	/* Don't let autoresume interfere with unbinding */
	if (intf->condition == USB_INTERFACE_UNBINDING)
		goto done;

	/* Can't resume it if it doesn't have a driver. */
	if (intf->condition == USB_INTERFACE_UNBOUND) {

		/* Carry out a deferred switch to altsetting 0 */
		if (intf->needs_altsetting0 && !intf->dev.power.is_prepared) {
			usb_set_interface(udev, intf->altsetting[0].
					desc.bInterfaceNumber, 0);
			intf->needs_altsetting0 = 0;
		}
		goto done;
	}

	/* Don't resume if the interface is marked for rebinding */
	if (intf->needs_binding)
		goto done;
	driver = to_usb_driver(intf->dev.driver);

	if (reset_resume) {
		if (driver->reset_resume) {
			status = driver->reset_resume(intf);
			if (status)
				dev_err(&intf->dev, "%s error %d\n",
						"reset_resume", status);
		} else {
			intf->needs_binding = 1;
			dev_dbg(&intf->dev, "no reset_resume for driver %s?\n",
					driver->name);
		}
	} else {
		status = driver->resume(intf);
		if (status)
			dev_err(&intf->dev, "resume error %d\n", status);
	}

done:
	dev_vdbg(&intf->dev, "%s: status %d\n", __func__, status);

	/* Later we will unbind the driver and/or reprobe, if necessary */
	return status;
}
```
#### `drivers/usb/core/driver.c`: `usb_resume_complete` (from line 1646)
```c
/* The device lock is held by the PM core */
int usb_resume_complete(struct device *dev)
{
	struct usb_device *udev = to_usb_device(dev);

	/* For PM complete calls, all we do is rebind interfaces
	 * whose needs_binding flag is set
	 */
	if (udev->state != USB_STATE_NOTATTACHED)
		rebind_marked_interfaces(udev);
	return 0;
}
```
#### `drivers/usb/core/driver.c`: `unbind_marked_interfaces` (from line 1144)
```c
/*
 * Unbind drivers for @udev's marked interfaces.  These interfaces have
 * the needs_binding flag set, for example by usb_resume_interface().
 *
 * The caller must hold @udev's device lock.
 */
static void unbind_marked_interfaces(struct usb_device *udev)
{
	struct usb_host_config	*config;
	int			i;
	struct usb_interface	*intf;

	config = udev->actconfig;
	if (config) {
		for (i = 0; i < config->desc.bNumInterfaces; ++i) {
			intf = config->interface[i];
			if (intf->dev.driver && intf->needs_binding)
				usb_forced_unbind_intf(intf);
		}
	}
}
```
#### `drivers/usb/core/driver.c`: `rebind_marked_interfaces` (from line 1191)
```c
/*
 * Rebind drivers to @udev's marked interfaces.  These interfaces have
 * the needs_binding flag set.
 *
 * The caller must hold @udev's device lock.
 */
static void rebind_marked_interfaces(struct usb_device *udev)
{
	struct usb_host_config	*config;
	int			i;
	struct usb_interface	*intf;

	config = udev->actconfig;
	if (config) {
		for (i = 0; i < config->desc.bNumInterfaces; ++i) {
			intf = config->interface[i];
			if (intf->needs_binding)
				usb_rebind_intf(intf);
		}
	}
}
```
#### `drivers/usb/core/hub.c`: `finish_port_resume` (from line 3638)
```c
/*
 * If the USB "suspend" state is in use (rather than "global suspend"),
 * many devices will be individually taken out of suspend state using
 * special "resume" signaling.  This routine kicks in shortly after
 * hardware resume signaling is finished, either because of selective
 * resume (by host) or remote wakeup (by device) ... now see what changed
 * in the tree that's rooted at this device.
 *
 * If @udev->reset_resume is set then the device is reset before the
 * status check is done.
 */
static int finish_port_resume(struct usb_device *udev)
{
	int	status = 0;
	u16	devstatus = 0;

	/* caller owns the udev device lock */
	dev_dbg(&udev->dev, "%s\n",
		udev->reset_resume ? "finish reset-resume" : "finish resume");

	/* usb ch9 identifies four variants of SUSPENDED, based on what
	 * state the device resumes to.  Linux currently won't see the
	 * first two on the host side; they'd be inside hub_port_init()
	 * during many timeouts, but hub_wq can't suspend until later.
	 */
	usb_set_device_state(udev, udev->actconfig
			? USB_STATE_CONFIGURED
			: USB_STATE_ADDRESS);

	/* 10.5.4.5 says not to reset a suspended port if the attached
	 * device is enabled for remote wakeup.  Hence the reset
	 * operation is carried out here, after the port has been
	 * resumed.
	 */
	if (udev->reset_resume) {
		/*
		 * If the device morphs or switches modes when it is reset,
		 * we don't want to perform a reset-resume.  We'll fail the
		 * resume, which will cause a logical disconnect, and then
		 * the device will be rediscovered.
		 */
 retry_reset_resume:
		if (udev->quirks & USB_QUIRK_RESET)
			status = -ENODEV;
		else
			status = usb_reset_and_verify_device(udev);
	}

	/* 10.5.4.5 says be sure devices in the tree are still there.
	 * For now let's assume the device didn't go crazy on resume,
	 * and device drivers will know about any resume quirks.
	 */
	if (status == 0) {
		devstatus = 0;
		status = usb_get_std_status(udev, USB_RECIP_DEVICE, 0, &devstatus);

		/* If a normal resume failed, try doing a reset-resume */
		if (status && !udev->reset_resume && udev->persist_enabled) {
			dev_dbg(&udev->dev, "retry with reset-resume\n");
			udev->reset_resume = 1;
			goto retry_reset_resume;
		}
	}

	if (status) {
		dev_dbg(&udev->dev, "gone after usb resume? status %d\n",
				status);
	/*
	 * There are a few quirky devices which violate the standard
	 * by claiming to have remote wakeup enabled after a reset,
	 * which crash if the feature is cleared, hence check for
	 * udev->reset_resume
	 */
	} else if (udev->actconfig && !udev->reset_resume) {
		if (udev->speed < USB_SPEED_SUPER) {
			if (devstatus & (1 << USB_DEVICE_REMOTE_WAKEUP))
				status = usb_disable_remote_wakeup(udev);
		} else {
			status = usb_get_std_status(udev, USB_RECIP_INTERFACE, 0,
					&devstatus);
			if (!status && devstatus & (USB_INTRF_STAT_FUNC_RW_CAP
					| USB_INTRF_STAT_FUNC_RW))
				status = usb_disable_remote_wakeup(udev);
		}

		if (status)
			dev_dbg(&udev->dev,
				"disable remote wakeup, status %d\n",
				status);
		status = 0;
	}
	return status;
}
```
#### `drivers/usb/core/hub.c`: `usb_reset_device` (from line 6341)
```c
/**
 * usb_reset_device - warn interface drivers and perform a USB port reset
 * @udev: device to reset (not in NOTATTACHED state)
 *
 * Warns all drivers bound to registered interfaces (using their pre_reset
 * method), performs the port reset, and then lets the drivers know that
 * the reset is over (using their post_reset method).
 *
 * Return: The same as for usb_reset_and_verify_device().
 * However, if a reset is already in progress (for instance, if a
 * driver doesn't have pre_reset() or post_reset() callbacks, and while
 * being unbound or re-bound during the ongoing reset its disconnect()
 * or probe() routine tries to perform a second, nested reset), the
 * routine returns -EINPROGRESS.
 *
 * Note:
 * The caller must own the device lock.  For example, it's safe to use
 * this from a driver probe() routine after downloading new firmware.
 * For calls that might not occur during probe(), drivers should lock
 * the device using usb_lock_device_for_reset().
 *
 * If an interface is currently being probed or disconnected, we assume
 * its driver knows how to handle resets.  For all other interfaces,
 * if the driver doesn't have pre_reset and post_reset methods then
 * we attempt to unbind it and rebind afterward.
 */
int usb_reset_device(struct usb_device *udev)
{
	int ret;
	int i;
	unsigned int noio_flag;
	struct usb_port *port_dev;
	struct usb_host_config *config = udev->actconfig;
	struct usb_hub *hub = usb_hub_to_struct_hub(udev->parent);

	if (udev->state == USB_STATE_NOTATTACHED) {
		dev_dbg(&udev->dev, "device reset not allowed in state %d\n",
				udev->state);
		return -EINVAL;
	}

	if (!udev->parent) {
		/* this requires hcd-specific logic; see ohci_restart() */
		dev_dbg(&udev->dev, "%s for root hub!\n", __func__);
		return -EISDIR;
	}

	if (udev->reset_in_progress)
		return -EINPROGRESS;
	udev->reset_in_progress = 1;

	port_dev = hub->ports[udev->portnum - 1];

	/*
	 * Don't allocate memory with GFP_KERNEL in current
	 * context to avoid possible deadlock if usb mass
	 * storage interface or usbnet interface(iSCSI case)
	 * is included in current configuration. The easist
	 * approach is to do it for every device reset,
	 * because the device 'memalloc_noio' flag may have
	 * not been set before reseting the usb device.
	 */
	noio_flag = memalloc_noio_save();

	/* Prevent autosuspend during the reset */
	usb_autoresume_device(udev);

	if (config) {
		for (i = 0; i < config->desc.bNumInterfaces; ++i) {
			struct usb_interface *cintf = config->interface[i];
			struct usb_driver *drv;
			int unbind = 0;

			if (cintf->dev.driver) {
				drv = to_usb_driver(cintf->dev.driver);
				if (drv->pre_reset && drv->post_reset)
					unbind = (drv->pre_reset)(cintf);
				else if (cintf->condition ==
						USB_INTERFACE_BOUND)
					unbind = 1;
				if (unbind)
					usb_forced_unbind_intf(cintf);
			}
		}
	}

	usb_lock_port(port_dev);
	ret = usb_reset_and_verify_device(udev);
	usb_unlock_port(port_dev);

	if (config) {
		for (i = config->desc.bNumInterfaces - 1; i >= 0; --i) {
			struct usb_interface *cintf = config->interface[i];
			struct usb_driver *drv;
			int rebind = cintf->needs_binding;

			if (!rebind && cintf->dev.driver) {
				drv = to_usb_driver(cintf->dev.driver);
				if (drv->post_reset)
					rebind = (drv->post_reset)(cintf);
				else if (cintf->condition ==
						USB_INTERFACE_BOUND)
					rebind = 1;
				if (rebind)
					cintf->needs_binding = 1;
			}
		}

		/* If the reset failed, hub_wq will unbind drivers later */
		if (ret == 0)
			usb_unbind_and_rebind_marked_interfaces(udev);
	}

	usb_autosuspend_device(udev);
	memalloc_noio_restore(noio_flag);
	udev->reset_in_progress = 0;
	return ret;
}
```
#### `drivers/usb/core/hub.c`: `usb_queue_reset_device` (from line 6462)
```c
/**
 * usb_queue_reset_device - Reset a USB device from an atomic context
 * @iface: USB interface belonging to the device to reset
 *
 * This function can be used to reset a USB device from an atomic
 * context, where usb_reset_device() won't work (as it blocks).
 *
 * Doing a reset via this method is functionally equivalent to calling
 * usb_reset_device(), except for the fact that it is delayed to a
 * workqueue. This means that any drivers bound to other interfaces
 * might be unbound, as well as users from usbfs in user space.
 *
 * Corner cases:
 *
 * - Scheduling two resets at the same time from two different drivers
 *   attached to two different interfaces of the same device is
 *   possible; depending on how the driver attached to each interface
 *   handles ->pre_reset(), the second reset might happen or not.
 *
 * - If the reset is delayed so long that the interface is unbound from
 *   its driver, the reset will be skipped.
 *
 * - This function can be called during .probe().  It can also be called
 *   during .disconnect(), but doing so is pointless because the reset
 *   will not occur.  If you really want to reset the device during
 *   .disconnect(), call usb_reset_device() directly -- but watch out
 *   for nested unbinding issues!
 */
void usb_queue_reset_device(struct usb_interface *iface)
{
	if (schedule_work(&iface->reset_ws))
		usb_get_intf(iface);
}
```
#### `drivers/usb/core/message.c`: `__usb_queue_reset_device` (from line 1958)
```c
/*
 * Internal function to queue a device reset
 * See usb_queue_reset_device() for more details
 */
static void __usb_queue_reset_device(struct work_struct *ws)
{
	int rc;
	struct usb_interface *iface =
		container_of(ws, struct usb_interface, reset_ws);
	struct usb_device *udev = interface_to_usbdev(iface);

	rc = usb_lock_device_for_reset(udev, iface);
	if (rc >= 0) {
		usb_reset_device(udev);
		usb_unlock_device(udev);
	}
	usb_put_intf(iface);	/* Undo _get_ in usb_queue_reset_device() */
}
```

## 7. The emulation: method and results
*(verbatim: `results/bt17-emulation-2026-11-13/README.md`)*
### BT-17 in emulation: the kernel's side of the incident, reproduced, and four btusb candidates (2026-11-13)

Everything here ran in QEMU guests on the investigation machine. Nothing touched the laptop's
Bluetooth, and nothing was sent anywhere.

#### What it is

- **The kernel:** bluetooth-next `da3cc0258` (2026-11-12), with:
  - BlueZ's tester config plus SMP 4, KASAN, lockdep and dynamic debug;
  - usbip's virtual host controller;
  - `CONFIG_BT_HCIBTUSB_AUTOSUSPEND=y` (as on the laptop).
- **The device: real btusb against an emulated controller,** `harness/bt17-emu.py`, run
  inside the guest. It speaks usbip to `vhci_hcd`, so the kernel sees a USB device:
  - **Identity:** `13d3:3503`, bcdUSB 1.10, full speed, remote wakeup in bmAttributes, class
    e0/01/01, the laptop's endpoint layout. So btusb takes the `BTUSB_QCA_ROME` path:
    `btusb_setup_qca()`, `hdev->reset = btusb_qca_reset`.
  - **QCA vendor requests:** version ROM `0x302` / patch `0x3e8`; status `0xc0` (patch and NVM
    loaded), so no download.
  - **HCI:** answers the init sequence and every later command.
  - **Accounting:** counts device suspends (SET_FEATURE remote wakeup) and resumes (the next
    GET_STATUS).
- **The fault, `--fail-at N`:** at the N-th resume the device does not answer its GET_STATUS
  and holds every later request (a device that NAKs). When the host gives up (unlink), the
  device is "dead": every control transfer fails `-71`. With `--recover` it is healthy again
  instead (a device that a reset brings back).
- **The triggers:**
  - MGMT Set Device Class after the runtime autosuspend (`bt17`, the laptop's Write Class of
    Device at login);
  - MGMT Set Powered off (`close-recover`, btusb's close takes a PM reference);
  - a healthy loop (`cycles`).
- **Debug on:** USB core `hub.c` and `driver.c`, plus btusb's suspend, resume and disconnect,
  and the HCI command worker.

**What it can and cannot show:**
- **Can:** what the kernel does when a device stops answering after a runtime resume, on the
  same code path as the laptop's: the ROME reset hook, autosuspend, persist.
- **Cannot:**
  - why the QCA chip stopped answering;
  - what the AMD xHCI did. vhci handles port reset and SET_ADDRESS itself, so the xHCI
    errors of the laptop's tail (BT-22) do not appear here.

#### The reproduction (unpatched kernel)

`logs/runs/base-bt17-2.log`. Times are from the moment the command reached btusb (the
`cmd_cnt` line). The laptop's are from `results/incident-2026-11-12-1803/`.

| | laptop (18:03, monotonic) | emulation |
|---|---|---|
| command handed to btusb | 178.731 | 16.229 |
| `usb auto-resume` (who started it) | not logged | +0.001 |
| `finish resume` (GET_STATUS sent) | not logged | +0.061 |
| `command 0x0c24 tx timeout` | +2.041 | +2.051 |
| MGMT Set Device Class / Remove UUID status | 0x05 | 0x05 |
| `retry with reset-resume` | not logged | +5.260 |
| first `reset full-speed` | +5.291 | +5.384 |
| four resets, then `gone after usb resume?` | resets only | yes |
| `USB disconnect` | +7.352 | +7.434 |
| `Failed usb_autopm_get_interface: -16` | +7.352 | +7.437 |
| `Resetting usb device.` | never | never |
| btusb `intf` prints | 2 at suspend, none at resume, 2 at disconnect | the same |

So H1 and H2 (the outside reviews) hold on this code, for a host-initiated resume of a device
that stops answering:
- the first reset is the USB core's reset-resume after a 5 s GET_STATUS;
- btusb's reset waits behind it and never runs.

#### Defects found with it (registered in `docs/issues.md`)

- **BT-18:** after a *successful* runtime reset-resume, btusb is never resumed (no
  `reset_resume` callback; the core rebinds marked interfaces only after a system resume or a
  `usb_reset_device()`). Bluetooth stays dead with a healthy device. Reproduced by
  `close-recover` (unpatched: power-on fails, HCI Reset `-110` twice, MGMT 0x05).
- **BT-19:** `btusb_reset()` blocks the ordered HCI workqueue 5.4 s behind the failing resume.
  When the reset-resume succeeds, it then resets the device a second time
  (`Resetting usb device.` after the rebinding, `recover` scenario).
- **BT-20:** `btusb_waker()` swallows the failed resume.
- **BT-21:** the MGMT 0x05 for a timeout (CO-44, tested separately with mgmt-tester).

#### The candidates (`patches/`, CO-43), in series order

1. **A**, "Bluetooth: btusb: Report a failed resume for deferred data" (BT-20).
2. **B**, "Bluetooth: btusb: Don't reset a device that has not resumed" (BT-19): no wait and
   no reset while `BTUSB_SUSPENDING` is set and the interface is not runtime-active.
3. **D**, "Bluetooth: btusb: Recover after a reset-resume" (BT-18): a `reset_resume`
   callback that resumes and queues a reset, so the core rebinds btusb.
4. **E**, "Bluetooth: btusb: Anchor a deferred URB under txlock" (BT-23).
5. **C**, RFC, "Bluetooth: btusb: Disable runtime suspend of QCA9377 13d3:3503 on Ryzen"
   (H3): the `BTUSB_WAKEUP_BROKEN` condition of `dcaf83ead130` for this one device.

`patches/debug-only/` holds the delay used to widen BT-23's window; it is a test tool, not a
candidate.

checkpatch `--strict --no-tree`: each reports only the missing Signed-off-by (the operator
adds his own), plus for patch 5 the no-tree commit-id warning and two CamelCase notes on the
USB core's own field names.

#### Results

QEMU, 4 CPUs, KASAN and lockdep; the emulated device fails at its first resume. One guest per
run. Every log is in `logs/runs/` (named `<kernel>-<label>.log`, with `SHA256SUMS`); matrix
summaries are `logs/runs/matrix-*.txt`; each kernel's build record (commit, modified files,
key config) is `logs/bzImage-<kernel>.commit`.

| scenario | unpatched (`base`) | A+B+D (`abd`) | final series A,B,D,E,C (`final`) |
|---|---|---|---|
| dead device, resume started by a class write (`bt17`) | 5/5: the laptop's sequence; `hci_cmd_timeout()` blocked 5.4 s; `Failed usb_autopm_get_interface: -16` at the disconnect | 5/5: `Device not resumed; not resetting`, credit back at once; `Failed to resume device for deferred data: -16`; the core disconnects | 3/3 as A+B+D |
| device that answers again after the reset-resume, started by a class write (`recover`) | 5/5 hci0 back, through `btusb_reset()`'s second reset (`Resetting usb device.` in every run, BT-19) | 5/5 back through D's rebinding; no reset from btusb | 3/3 back |
| the same, started by powering hci0 off (`close-recover`) | **0/5**: Bluetooth dead afterwards (BT-18) | 5/5 works | 3/3 works |
| healthy suspend/resume cycles with a class write each | 50/50, median 0.062 s | 50/50, median 0.064 s | 50/50, median 0.063 s |
| dead device, guest with the host's CPU (Ryzen 7 5825U) | fails as above | — | the device no longer autosuspends with hci0 up (C); the fault never arises |
| the same with C, guest CPU not Zen (`abdc`) | — | — | as A+B+D (C does not apply) |
| BT-23, window widened to 400 ms by a debug-only delay, resume forced inside it (`bt23`) | 3/3: parked on an active device, timed out after 2.02 s, MGMT 0x05 | — | E: 2/2 answered after 0.40 s; 20/20 healthy cycles |
| system suspend (`pm_test=devices`, freeze) | not testable here. `vhci_hcd` refuses system suspend with a device attached (`platform_pm_suspend returns -16`), both kernels. A second emulator on Raw Gadget and `dummy_hcd` (`harness/rg-emu.py`, `*-rg-*` logs, `SHA256SUMS-raw-gadget`) works before the sleep, but the freezer stops the user-space gadget during the resume ("device is not running") | | |

Kernel reports (`BUG:`, `WARNING:`, KASAN, lockdep, hung task) in any run: none.

**The laptop tool `scripts/bt17-provoke.py`, run unchanged in a guest:**
- healthy device: 18 cycles, 18 answered;
- device failing at resume 4: "FAILURE at cycle 4", with the device's runtime status
  `resuming` in its record.

Its first version had a 14-byte HCI filter, which the kernel refuses (EINVAL; `struct
hci_ufilter` is 16 bytes with padding). The emulator caught it; fixed before any laptop use.

#### Rerunning

- `harness/build-guest-kernel.sh <tag>` builds from a bluetooth-next worktree.
- `harness/run-guest.sh <tag> <label> <scenario> [--fail-at N] [--recover]` runs one guest;
  `harness/run-guest-hostcpu.sh` passes `-cpu host`, so the guest sees the Ryzen.
- `harness/run-matrix.sh <tag> <first> <last>` runs the repeat matrix.

Paths in the scripts are those of the work directory `/root/exp/agent-work/bt17-emu-20261113/`.
#### `results/bt17-emulation-2026-11-13/logs/runs/matrix-abd-1-5.txt`
```
abd dead 1: Bluetooth: hci0: Device not resumed; not resetting
abd dead 1: Bluetooth: hci0: Device not resumed; not resetting
abd dead 1: Bluetooth: hci0: Device not resumed; not resetting
abd dead 1: Bluetooth: hci0: Failed to resume device for deferred data: -16
abd dead 1: Bluetooth: hci0: Failed to resume device for deferred data: -16
abd dead 1:   10.680 [mono  13.451170] RESULT bt17 fail_at=1 recover=False class-write-status=0x05 hci0_removed=True
abd dead 1: [32m[    8.268068] [0m[33mBluetooth: [0m[31mhci0: Device not resumed; not resetting[0m
abd dead 1: [32m[   10.284033] [0m[33mBluetooth: [0m[31mhci0: Device not resumed; not resetting[0m
abd dead 1: [32m[   12.331694] [0m[33mBluetooth: [0m[31mhci0: Device not resumed; not resetting[0m
abd dead 1: [32m[   13.391644] [0m[33mBluetooth: [0m[31mhci0: Failed to resume device for deferred data: -16[0m
abd dead 1: [32m[   13.392040] [0m[33mBluetooth: [0m[31mhci0: Failed to resume device for deferred data: -16[0m
abd recover 1: Bluetooth: hci0: Device not resumed; not resetting
abd recover 1: Bluetooth: hci0: Device not resumed; not resetting
abd recover 1:    9.393 [mono  12.132162] RESULT bt17 fail_at=1 recover=True class-write-status=0x05 hci0_removed=True
abd recover 1: [32m[    8.230243] [0m[33mBluetooth: [0m[31mhci0: Device not resumed; not resetting[0m
abd recover 1: [32m[   10.246233] [0m[33mBluetooth: [0m[31mhci0: Device not resumed; not resetting[0m
abd close 1:   10.144 [mono  12.880485] RESULT close-recover bluetooth_works_after=True
abd dead 2: Bluetooth: hci0: Device not resumed; not resetting
abd dead 2: Bluetooth: hci0: Device not resumed; not resetting
abd dead 2: Bluetooth: hci0: Device not resumed; not resetting
abd dead 2: Bluetooth: hci0: Failed to resume device for deferred data: -16
abd dead 2: Bluetooth: hci0: Failed to resume device for deferred data: -16
abd dead 2:   10.724 [mono  13.457241] RESULT bt17 fail_at=1 recover=False class-write-status=0x05 hci0_removed=True
abd dead 2: [32m[    8.226039] [0m[33mBluetooth: [0m[31mhci0: Device not resumed; not resetting[0m
abd dead 2: [32m[   10.273426] [0m[33mBluetooth: [0m[31mhci0: Device not resumed; not resetting[0m
abd dead 2: [32m[   12.289306] [0m[33mBluetooth: [0m[31mhci0: Device not resumed; not resetting[0m
abd dead 2: [32m[   13.385454] [0m[33mBluetooth: [0m[31mhci0: Failed to resume device for deferred data: -16[0m
abd dead 2: [32m[   13.385807] [0m[33mBluetooth: [0m[31mhci0: Failed to resume device for deferred data: -16[0m
abd recover 2:  Device not resumed; not resetting
abd recover 2: Bluetooth: hci0: Device not resumed; not resetting
abd recover 2:    9.319 [mono  12.098821] RESULT bt17 fail_at=1 recover=True class-write-status=0x05 hci0_removed=True
abd recover 2: [32m[    8.289223] [0m[33mBluetooth: [0m[31mhci0: Device not resumed; not resetting[0m
abd recover 2: [32m[   10.335517] [0m[33mBluetooth: [0m[31mhci0: Device not resumed; not resetting[0m
abd close 2:   10.127 [mono  12.870739] RESULT close-recover bluetooth_works_after=True
abd dead 3: Bluetooth: hci0: Device not resumed; not resetting
abd dead 3: Bluetooth: hci0: Device not resumed; not resetting
abd dead 3: Bluetooth: hci0: Device not resumed; not resetting
abd dead 3: Bluetooth: hci0: Failed to resume device for deferred data: -16
abd dead 3: Bluetooth: hci0: Failed to resume device for deferred data: -16
abd dead 3:   10.740 [mono  13.475695] RESULT bt17 fail_at=1 recover=False class-write-status=0x05 hci0_removed=True
abd dead 3: [32m[    8.224842] [0m[33mBluetooth: [0m[31mhci0: Device not resumed; not resetting[0m
abd dead 3: [32m[   10.240571] [0m[33mBluetooth: [0m[31mhci0: Device not resumed; not resetting[0m
abd dead 3: [32m[   12.257141] [0m[33mBluetooth: [0m[31mhci0: Device not resumed; not resetting[0m
abd dead 3: [32m[   13.392736] [0m[33mBluetooth: [0m[31mhci0: Failed to resume device for deferred data: -16[0m
abd dead 3: [32m[   13.393238] [0m[33mBluetooth: [0m[31mhci0: Failed to resume device for deferred data: -16[0m
abd recover 3: Bluetooth: hci0: Device not resumed; not resetting
abd recover 3: Bluetooth: hci0: Device not resumed; not resetting
abd recover 3:    9.370 [mono  12.117332] RESULT bt17 fail_at=1 recover=True class-write-status=0x05 hci0_removed=True
abd recover 3: [32m[    8.259522] [0m[33mBluetooth: [0m[31mhci0: Device not resumed; not resetting[0m
abd recover 3: [32m[   10.275276] [0m[33mBluetooth: [0m[31mhci0: Device not resumed; not resetting[0m
abd close 3:   10.124 [mono  12.872791] RESULT close-recover bluetooth_works_after=True
abd dead 4: Bluetooth: hci0: Device not resumed; not resetting
abd dead 4: Bluetooth: hci0: Device not resumed; not resetting
abd dead 4: Bluetooth: hci0: Device not resumed; not resetting
abd dead 4: Bluetooth: hci0: Failed to resume device for deferred data: -16
abd dead 4: Bluetooth: hci0: Failed to resume device for deferred data: -16
abd dead 4:   10.452 [mono  13.169441] RESULT bt17 fail_at=1 recover=False class-write-status=0x05 hci0_removed=True
abd dead 4: [32m[    8.224536] [0m[33mBluetooth: [0m[31mhci0: Device not resumed; not resetting[0m
abd dead 4: [32m[   10.272676] [0m[33mBluetooth: [0m[31mhci0: Device not resumed; not resetting[0m
abd dead 4: [32m[   12.320674] [0m[33mBluetooth: [0m[31mhci0: Device not resumed; not resetting[0m
abd dead 4: [32m[   13.124229] [0m[33mBluetooth: [0m[31mhci0: Failed to resume device for deferred data: -16[0m
abd dead 4: [32m[   13.124646] [0m[33mBluetooth: [0m[31mhci0: Failed to resume device for deferred data: -16[0m
abd recover 4: Bluetooth: hci0: Device not resumed; not resetting
abd recover 4: Bluetooth: hci0: Device not resumed; not resetting
abd recover 4:    9.388 [mono  12.103978] RESULT bt17 fail_at=1 recover=True class-write-status=0x05 hci0_removed=True
abd recover 4: [32m[    8.225743] [0m[33mBluetooth: [0m[31mhci0: Device not resumed; not resetting[0m
abd recover 4: [32m[   10.241584] [0m[33mBluetooth: [0m[31mhci0: Device not resumed; not resetting[0m
abd close 4:   10.084 [mono  12.848380] RESULT close-recover bluetooth_works_after=True
abd dead 5: Bluetooth: hci0: Device not resumed; not resetting
abd dead 5: Bluetooth: hci0: Device not resumed; not resetting
abd dead 5: Bluetooth: hci0: Device not resumed; not resetting
abd dead 5: Bluetooth: hci0: Failed to resume device for deferred data: -16
abd dead 5: Bluetooth: hci0: Failed to resume device for deferred data: -16
abd dead 5:   10.756 [mono  13.509776] RESULT bt17 fail_at=1 recover=False class-write-status=0x05 hci0_removed=True
abd dead 5: [32m[    8.263813] [0m[33mBluetooth: [0m[31mhci0: Device not resumed; not resetting[0m
abd dead 5: [32m[   10.311638] [0m[33mBluetooth: [0m[31mhci0: Device not resumed; not resetting[0m
abd dead 5: [32m[   12.359760] [0m[33mBluetooth: [0m[31mhci0: Device not resumed; not resetting[0m
abd dead 5: [32m[   13.468192] [0m[33mBluetooth: [0m[31mhci0: Failed to resume device for deferred data: -16[0m
abd dead 5: [32m[   13.468637] [0m[33mBluetooth: [0m[31mhci0: Failed to resume device for deferred data: -16[0m
abd recover 5: Bluetooth: hci0: Device not resumed; not resetting
abd recover 5: Bluetooth: hci0: Device not resumed; not resetting
abd recover 5:    9.357 [mono  12.106603] RESULT bt17 fail_at=1 recover=True class-write-status=0x05 hci0_removed=True
abd recover 5: [32m[    8.259680] [0m[33mBluetooth: [0m[31mhci0: Device not resumed; not resetting[0m
abd recover 5: [32m[   10.307516] [0m[33mBluetooth: [0m[31mhci0: Device not resumed; not resetting[0m
abd close 5:   10.139 [mono  12.862753] RESULT close-recover bluetooth_works_after=True
abd cycles50:  108.521 [mono 111.272644] class write latency after a suspend: n=50 min 0.058 median 0.064 max 0.131 s
abd cycles50:  108.521 [mono 111.272949] RESULT cycles n=50 failures=0
```
#### `results/bt17-emulation-2026-11-13/logs/runs/matrix-base-1-5.txt`
```
base dead 1: Bluetooth: hci0: Failed usb_autopm_get_interface: -16
base dead 1:   10.793 [mono  13.532697] RESULT bt17 fail_at=1 recover=False class-write-status=0x05 hci0_removed=True
base dead 1: [32m[   13.450911] [0m[33mBluetooth: [0m[31mhci0: Failed usb_autopm_get_interface: -16[0m
base recover 1: Bluetooth: hci0: Resetting usb device.
base recover 1:    9.381 [mono  12.111181] RESULT bt17 fail_at=1 recover=True class-write-status=0x05 hci0_removed=True
base recover 1: [32m[   11.781578] [0m[33mBluetooth: [0m[31mhci0: Resetting usb device.[0m
base close 1:   16.682 [mono  19.435717] RESULT close-recover bluetooth_works_after=False
base dead 2: Bluetooth: hci0: Failed usb_autopm_get_interface: -16
base dead 2:   10.708 [mono  13.452755] RESULT bt17 fail_at=1 recover=False class-write-status=0x05 hci0_removed=True
base dead 2: [32m[   13.378368] [0m[33mBluetooth: [0m[31mhci0: Failed usb_autopm_get_interface: -16[0m
base recover 2: Bluetooth: hci0: Resetting usb device.
base recover 2:    9.344 [mono  12.116315] RESULT bt17 fail_at=1 recover=True class-write-status=0x05 hci0_removed=True
base recover 2: [32m[   11.783104] [0m[33mBluetooth: [0m[31mhci0: Resetting usb device.[0m
base close 2:   16.721 [mono  19.497472] RESULT close-recover bluetooth_works_after=False
base dead 3: Bluetooth: hci0: Failed usb_autopm_get_interface: -16
base dead 3:   10.683 [mono  13.471819] RESULT bt17 fail_at=1 recover=False class-write-status=0x05 hci0_removed=True
base dead 3: [32m[   13.392676] [0m[33mBluetooth: [0m[31mhci0: Failed usb_autopm_get_interface: -16[0m
base recover 3: Bluetooth: hci0: Resetting usb device.
base recover 3:    9.397 [mono  12.107285] RESULT bt17 fail_at=1 recover=True class-write-status=0x05 hci0_removed=True
base recover 3: [32m[   11.779949] [0m[33mBluetooth: [0m[31mhci0: Resetting usb device.[0m
base close 3:   16.729 [mono  19.500630] RESULT close-recover bluetooth_works_after=False
base dead 4: Bluetooth: hci0: Failed usb_autopm_get_interface: -16
base dead 4:   10.739 [mono  13.473863] RESULT bt17 fail_at=1 recover=False class-write-status=0x05 hci0_removed=True
base dead 4: [32m[   13.420752] [0m[33mBluetooth: [0m[31mhci0: Failed usb_autopm_get_interface: -16[0m
base recover 4: Bluetooth: hci0: Resetting usb device.
base recover 4:    9.378 [mono  12.131390] RESULT bt17 fail_at=1 recover=True class-write-status=0x05 hci0_removed=True
base recover 4: [32m[   11.797465] [0m[33mBluetooth: [0m[31mhci0: Resetting usb device.[0m
base close 4:   16.665 [mono  19.438284] RESULT close-recover bluetooth_works_after=False
base dead 5: Bluetooth: hci0: Failed usb_autopm_get_interface: -16
base dead 5:   10.670 [mono  13.441795] RESULT bt17 fail_at=1 recover=False class-write-status=0x05 hci0_removed=True
base dead 5: [32m[   13.381475] [0m[33mBluetooth: [0m[31mhci0: Failed usb_autopm_get_interface: -16[0m
base recover 5: Bluetooth: hci0: Resetting usb device.
base recover 5:    9.387 [mono  12.113944] RESULT bt17 fail_at=1 recover=True class-write-status=0x05 hci0_removed=True
base recover 5: [32m[   11.787573] [0m[33mBluetooth: [0m[31mhci0: Resetting usb device.[0m
base close 5:   16.680 [mono  19.441516] RESULT close-recover bluetooth_works_after=False
base cycles50:  108.327 [mono 111.040649] class write latency after a suspend: n=50 min 0.060 median 0.062 max 0.098 s
base cycles50:  108.328 [mono 111.041716] RESULT cycles n=50 failures=0
```
#### `results/bt17-emulation-2026-11-13/logs/runs/matrix-final-1-3.txt`
```
final dead 1: Bluetooth: hci0: Device not resumed; not resetting
final dead 1: Bluetooth: hci0: Device not resumed; not resetting
final dead 1: Bluetooth: hci0: Device not resumed; not resetting
final dead 1: Bluetooth: hci0: Failed to resume device for deferred data: -16
final dead 1: Bluetooth: hci0: Failed to resume device for deferred data: -16
final dead 1:   10.754 [mono  13.505078] RESULT bt17 fail_at=1 recover=False class-write-status=0x05 hci0_removed=True
final dead 1: [32m[    8.270395] [0m[33mBluetooth: [0m[31mhci0: Device not resumed; not resetting[0m
final dead 1: [32m[   10.289035] [0m[33mBluetooth: [0m[31mhci0: Device not resumed; not resetting[0m
final dead 1: [32m[   12.302244] [0m[33mBluetooth: [0m[31mhci0: Device not resumed; not resetting[0m
final dead 1: [32m[   13.466586] [0m[33mBluetooth: [0m[31mhci0: Failed to resume device for deferred data: -16[0m
final dead 1: [32m[   13.467026] [0m[33mBluetooth: [0m[31mhci0: Failed to resume device for deferred data: -16[0m
final recover 1: Bluetooth: hci0: Device not resumed; not resetting
final recover 1: Bluetooth: hci0: Device not resumed; not resetting
final recover 1:    9.355 [mono  12.108769] RESULT bt17 fail_at=1 recover=True class-write-status=0x05 hci0_removed=True
final recover 1: [32m[    8.257959] [0m[33mBluetooth: [0m[31mhci0: Device not resumed; not resetting[0m
final recover 1: [32m[   10.273934] [0m[33mBluetooth: [0m[31mhci0: Device not resumed; not resetting[0m
final close 1:   10.113 [mono  12.893444] RESULT close-recover bluetooth_works_after=True
final dead 2: Bluetooth: hci0: Device not resumed; not resetting
final dead 2: Bluetooth: hci0: Device not resumed; not resetting
final dead 2: Bluetooth: hci0: Device not resumed; not resetting
final dead 2: Bluetooth: hci0: Failed to resume device for deferred data: -16
final dead 2: Bluetooth: hci0: Failed to resume device for deferred data: -16
final dead 2:   10.434 [mono  13.129775] RESULT bt17 fail_at=1 recover=False class-write-status=0x05 hci0_removed=True
final dead 2: [32m[    8.185901] [0m[33mBluetooth: [0m[31mhci0: Device not resumed; not resetting[0m
final dead 2: [32m[   10.222942] [0m[33mBluetooth: [0m[31mhci0: Device not resumed; not resetting[0m
final dead 2: [32m[   12.227746] [0m[33mBluetooth: [0m[31mhci0: Device not resumed; not resetting[0m
final dead 2: [32m[   13.055706] [0m[33mBluetooth: [0m[31mhci0: Failed to resume device for deferred data: -16[0m
final dead 2: [32m[   13.056331] [0m[33mBluetooth: [0m[31mhci0: Failed to resume device for deferred data: -16[0m
final recover 2: Bluetooth: hci0: Device not resumed; not resetting
final recover 2: Bluetooth: hci0: Device not resumed; not resetting
final recover 2:    9.128 [mono  11.849867] RESULT bt17 fail_at=1 recover=True class-write-status=0x05 hci0_removed=True
final recover 2: [32m[    8.237191] [0m[33mBluetooth: [0m[31mhci0: Device not resumed; not resetting[0m
final recover 2: [32m[   10.253315] [0m[33mBluetooth: [0m[31mhci0: Device not resumed; not resetting[0m
final close 2:   10.130 [mono  12.853797] RESULT close-recover bluetooth_works_after=True
final dead 3: Bluetooth: hci0: Device not resumed; not resetting
final dead 3: Bluetooth: hci0: Device not resumed; not resetting
final dead 3: Bluetooth: hci0: Device not resumed; not resetting
final dead 3: Bluetooth: hci0: Failed to resume device for deferred data: -16
final dead 3: Bluetooth: hci0: Failed to resume device for deferred data: -16
final dead 3:   10.496 [mono  13.200593] RESULT bt17 fail_at=1 recover=False class-write-status=0x05 hci0_removed=True
final dead 3: [32m[    8.198334] [0m[33mBluetooth: [0m[31mhci0: Device not resumed; not resetting[0m
final dead 3: [32m[   10.246461] [0m[33mBluetooth: [0m[31mhci0: Device not resumed; not resetting[0m
final dead 3: [32m[   12.262159] [0m[33mBluetooth: [0m[31mhci0: Device not resumed; not resetting[0m
final dead 3: [32m[   13.150988] [0m[33mBluetooth: [0m[31mhci0: Failed to resume device for deferred data: -16[0m
final dead 3: [32m[   13.151402] [0m[33mBluetooth: [0m[31mhci0: Failed to resume device for deferred data: -16[0m
final recover 3: Bluetooth: hci0: Device not resumed; not resetting
final recover 3: Bluetooth: hci0: Device not resumed; not resetting
final recover 3:    9.356 [mono  12.132998] RESULT bt17 fail_at=1 recover=True class-write-status=0x05 hci0_removed=True
final recover 3: [32m[    8.278902] [0m[33mBluetooth: [0m[31mhci0: Device not resumed; not resetting[0m
final recover 3: [32m[   10.326222] [0m[33mBluetooth: [0m[31mhci0: Device not resumed; not resetting[0m
final close 3:   10.132 [mono  12.873336] RESULT close-recover bluetooth_works_after=True
final cycles50:  106.315 [mono 109.071103] class write latency after a suspend: n=50 min 0.060 median 0.063 max 0.068 s
final cycles50:  106.316 [mono 109.071581] RESULT cycles n=50 failures=0
```

## 8. The emulator and harness source, in full
#### `results/bt17-emulation-2026-11-13/harness/PLAN.md`
```markdown
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
```
#### `results/bt17-emulation-2026-11-13/harness/bt17-emu.py`
```python
#!/usr/bin/env python3
"""bt17-emu.py - an emulated QCA9377 Bluetooth controller (13d3:3503) for the BT-17 incident,
attached through the kernel's usbip vhci_hcd so that the real btusb binds to it in a QEMU guest.

Derived from results/laptop-only-work-2026-11-11/.../usbip-bt-emu.py (CO-21). What is new:
  * the laptop's identity: 13d3:3503, bcdUSB 1.10, full speed, remote wakeup in
    bmAttributes, so btusb takes the BTUSB_QCA_ROME path (hdev->reset = btusb_qca_reset);
  * the two QCA vendor requests of btusb_setup_qca(): QCA_GET_TARGET_VERSION answers
    ROM 0x302 / patch 0x3e8, QCA_CHECK_STATUS answers 0xc0 (patch and NVM already loaded),
    so no firmware download is attempted;
  * suspend/resume accounting: a SET_FEATURE(DEVICE_REMOTE_WAKEUP) marks a device suspend,
    the next device GET_STATUS marks the resume check (finish_port_resume());
  * a fault, --fail-at N: at the N-th resume the device stops answering. Its GET_STATUS and
    every later request are held (a device that NAKs). When the host gives up on a held URB
    (unlink), the device turns 'dead': every control transfer then fails with -71 (EPROTO),
    as the laptop's controller did after its first reset. --recover makes it healthy again
    instead (a device that a reset brings back);
  * a driver for the incident: MGMT Set Powered, wait for the runtime autosuspend, then
    MGMT Set Device Class (the kernel writes the Class of Device, as at the laptop's login),
    MGMT events logged with their status, the kernel log and the USB core debug lines
    collected at the end.
It emulates the device only: nothing here is measured on the laptop.

Usage: bt17-emu.py <scenario> [--fail-at N] [--recover] [--cycles N] [--hold-hci]
Scenarios: bt17 (fault at a resume, then the class write), cycles (healthy suspend/resume
cycles with a class write each), up (bring-up only).
"""
import ctypes
import os
import socket
import struct
import sys
import threading
import time
from collections import deque

T0 = time.time()
LOG_LOCK = threading.Lock()


def mono():
    return time.clock_gettime(time.CLOCK_MONOTONIC)


def log(msg):
    with LOG_LOCK:
        print("%8.3f [mono %10.6f] %s" % (time.time() - T0, mono(), msg), flush=True)


def arg(name, default=None):
    if name in sys.argv:
        i = sys.argv.index(name)
        return sys.argv[i + 1]
    return default


# ---------------------------------------------------------------- descriptors
def ep(addr, attr, mps, ival):
    return struct.pack("<BBBBHB", 7, 5, addr, attr, mps, ival)


def iface(num, alt, neps):
    return struct.pack("<BBBBBBBBB", 9, 4, num, alt, neps, 0xE0, 1, 1, 0)


def config_desc():
    body = iface(0, 0, 3) + ep(0x81, 3, 16, 1) + ep(0x82, 2, 64, 0) + ep(0x02, 2, 64, 0)
    for alt, mps in enumerate((0, 9, 17, 25, 33, 49)):
        body += iface(1, alt, 2) + ep(0x83, 1, mps, 1) + ep(0x03, 1, mps, 1)
    total = 9 + len(body)
    # bmAttributes 0xe0: self-powered and remote wakeup, as the laptop's controller
    return struct.pack("<BBHBBBBB", 9, 2, total, 2, 1, 0, 0xE0, 50) + body


# bcdUSB 1.10, class e0/01/01, ep0 64, 13d3:3503, bcdDevice 0.01
DEV_DESC = struct.pack("<BBHBBBBHHHBBBB", 18, 1, 0x0110, 0xE0, 1, 1, 64,
                       0x13D3, 0x3503, 0x0001, 0, 0, 0, 1)

# struct qca_version: rom_version, patch_version, ram_version, chip_id, platform_id, flag, rsvd
QCA_VERSION = struct.pack("<IIIBBH4s", 0x00000302, 0x000003E8, 0x00000302, 0, 0, 0, b"\0" * 4)

BDADDR = bytes([0x00, 0x00, 0x00, 0x77, 0x17, 0x00])
FEATURES = bytes([0xFF, 0xFF, 0x8F, 0xFE, 0x9B, 0xF9, 0x00, 0x00])


class Emu:
    def __init__(self, fail_at=0, recover=False, hold_hci=False):
        self.lock = threading.Lock()
        self.intr_pending = deque()
        self.intr_out = bytearray()
        self.unknown = set()
        self.sock = None
        self.running = True
        self.fail_at = fail_at
        self.recover = recover
        self.hold_hci = hold_hci
        self.state = "healthy"          # healthy | wedged | dead
        self.suspended = False
        self.suspends = 0
        self.resumes = 0
        self.held = {}                   # seq -> description
        self.events = []                 # (mono, what)
        self.hci_cmds = []               # (mono, opcode)

    def note(self, what):
        self.events.append((mono(), what))
        log("EMU " + what)

    # -- usbip
    def attach(self):
        base = "/sys/devices/platform/vhci_hcd.0"
        kfd, self.sock = socket.socketpair()
        with open(base + "/attach", "w") as f:
            f.write("0 %d %d 2" % (kfd.fileno(), (1 << 16) | 2))   # full speed
        log("attached to vhci_hcd port 0")
        self.kfd = kfd
        threading.Thread(target=self.loop, daemon=True).start()

    def recvn(self, n):
        b = b""
        while len(b) < n:
            c = self.sock.recv(n - len(b))
            if not c:
                raise EOFError
            b += c
        return b

    def send(self, data):
        with self.lock:
            self.sock.sendall(data)

    def ret_submit(self, seq, status=0, actual=0, data=b""):
        h = struct.pack(">IIIII", 3, seq, 0, 0, 0)
        h += struct.pack(">iiiii", status, actual, 0, 0, 0)
        h += b"\0" * 8
        self.send(h + data)

    def ret_unlink(self, seq, status):
        self.send(struct.pack(">IIIII", 4, seq, 0, 0, 0) + struct.pack(">i", status) + b"\0" * 24)

    def loop(self):
        try:
            while self.running:
                hdr = self.recvn(48)
                cmd, seq, devid, direction, epn = struct.unpack(">IIIII", hdr[:20])
                u = hdr[20:]
                if cmd == 1:
                    flags, buflen, start, nump, ival = struct.unpack(">IiiiI", u[:20])
                    setup = u[20:28]
                    data = b""
                    if direction == 0 and buflen > 0:
                        data = self.recvn(buflen)
                    if nump > 0:
                        self.recvn(16 * nump)
                    self.submit(seq, direction, epn, buflen, setup, data)
                elif cmd == 2:
                    self.unlink(seq, struct.unpack(">I", u[:4])[0])
                else:
                    log("unknown usbip command %d" % cmd)
        except (EOFError, OSError) as e:
            log("usbip socket ended: %r" % (e,))

    def unlink(self, seq, victim):
        hit = False
        with self.lock:
            for item in list(self.intr_pending):
                if item[0] == victim:
                    self.intr_pending.remove(item)
                    hit = True
        if victim in self.held:
            what = self.held.pop(victim)
            hit = True
            self.note("host gave up on held %s (unlink)" % what)
            if self.state == "wedged":
                if self.recover:
                    self.state = "healthy"
                    self.note("device recovers (--recover)")
                else:
                    self.state = "dead"
                    self.note("device dead: control transfers now fail -71")
        self.ret_unlink(seq, -104 if hit else 0)

    def submit(self, seq, direction, epn, buflen, setup, data):
        if epn == 0:
            self.control(seq, direction, buflen, setup, data)
        elif epn == 1 and direction == 1:
            with self.lock:
                self.intr_pending.append((seq, buflen))
            self.pump()
        elif epn == 2 and direction == 1:
            pass                                    # bulk IN: kept pending
        elif epn == 2 and direction == 0:
            if self.state == "healthy":
                self.ret_submit(seq, 0, buflen)
            elif self.state == "dead":
                self.ret_submit(seq, -71, 0)
            else:
                self.held[seq] = "bulk OUT"
        elif epn == 3:
            self.ret_submit(seq, -71 if self.state != "healthy" else 0, 0)
        else:
            self.ret_submit(seq, -32, 0)

    def control(self, seq, direction, buflen, setup, data):
        bm, br, wv, wi, wl = struct.unpack("<BBHHH", setup)
        desc = "control %02x %02x %04x %04x %04x" % (bm, br, wv, wi, wl)
        if self.state == "dead":
            self.note("%s -> -71 (dead)" % desc)
            self.ret_submit(seq, -71, 0)
            return
        if self.state == "wedged":
            self.held[seq] = desc
            self.note("%s held (wedged)" % desc)
            return
        if bm == 0x80 and br == 0 and getattr(self, "arm_status", False):   # armed (system sleep)
            self.arm_status = False
            self.resumes += 1
            self.state = "wedged"
            self.held[seq] = "GET_STATUS (armed)"
            self.note("armed GET_STATUS held, device wedged")
            return
        if bm == 0x80 and br == 0 and self.suspended:          # resume check
            self.resumes += 1
            self.suspended = False
            if self.fail_at and self.resumes == self.fail_at:
                self.state = "wedged"
                self.held[seq] = "GET_STATUS of resume #%d" % self.resumes
                self.note("resume #%d: GET_STATUS held, device wedged" % self.resumes)
                return
            self.note("resume #%d: GET_STATUS answered" % self.resumes)
        if bm == 0x80 and br == 6:
            t = wv >> 8
            d = DEV_DESC if t == 1 else config_desc() if t == 2 else None
            if d is None:
                self.ret_submit(seq, -32, 0)
                return
            d = d[:wl]
            self.ret_submit(seq, 0, len(d), d)
        elif bm == 0x00 and br == 9:
            self.ret_submit(seq, 0, 0)
        elif bm == 0x01 and br == 11:
            self.ret_submit(seq, 0, 0)
        elif bm == 0x00 and br == 3 and wv == 1:               # SET_FEATURE(REMOTE_WAKEUP)
            self.suspends += 1
            self.suspended = True
            self.note("suspend #%d (SET_FEATURE remote wakeup)" % self.suspends)
            self.ret_submit(seq, 0, 0)
        elif bm == 0x00 and br == 1 and wv == 1:               # CLEAR_FEATURE(REMOTE_WAKEUP)
            self.ret_submit(seq, 0, 0)
        elif bm & 0x60 == 0 and br in (1, 3):
            self.ret_submit(seq, 0, 0)
        elif bm == 0x80 and br == 0:
            self.ret_submit(seq, 0, 2, b"\x03\x00")            # self-powered, remote wakeup on
        elif bm == 0x80 and br == 8:
            self.ret_submit(seq, 0, 1, b"\x01")
        elif bm == 0x81 and br == 10:
            self.ret_submit(seq, 0, 1, b"\x00")
        elif bm == 0xC0 and br == 0x09:                        # QCA_GET_TARGET_VERSION
            self.ret_submit(seq, 0, min(wl, len(QCA_VERSION)), QCA_VERSION[:wl])
        elif bm == 0xC0 and br == 0x05:                        # QCA_CHECK_STATUS
            self.ret_submit(seq, 0, 1, b"\xc0")
        elif bm == 0x20 and br == 0:                           # HCI command
            op, plen = struct.unpack("<HB", data[:3])
            self.hci_cmds.append((mono(), op))
            if self.hold_hci and self.suspends and self.resumes >= self.fail_at > 0:
                self.held[seq] = "HCI 0x%04x" % op
                return
            self.ret_submit(seq, 0, len(data))
            self.hci_cmd(op, data[3:3 + plen])
        else:
            log("%s not handled" % desc)
            self.ret_submit(seq, -32, 0)

    # -- events
    def event(self, code, params):
        with self.lock:
            self.intr_out += bytes([code, len(params)]) + params
        self.pump()

    def pump(self):
        while True:
            with self.lock:
                if self.state != "healthy" or not self.intr_pending or not self.intr_out:
                    return
                seq, buflen = self.intr_pending.popleft()
                chunk = bytes(self.intr_out[:min(buflen, 16)])
                del self.intr_out[:len(chunk)]
            self.ret_submit(seq, 0, len(chunk), chunk)

    def cc(self, op, ret=b"\0"):
        self.event(0x0E, struct.pack("<BH", 1, op) + ret)

    def hci_cmd(self, op, p):
        log("HCI cmd 0x%04x %s" % (op, p.hex()))
        if op == 0x1001:
            self.cc(op, struct.pack("<BBHBHH", 0, 6, 0x0302, 6, 0x0045, 0x0302))  # QCA, 4.0
        elif op == 0x1002:
            cmds = bytearray(64)
            cmds[9] = 0x04
            self.cc(op, b"\0" + bytes(cmds))
        elif op == 0x1003:
            self.cc(op, b"\0" + FEATURES)
        elif op == 0x1005:
            self.cc(op, struct.pack("<BHBHH", 0, 1021, 64, 8, 8))
        elif op == 0x1009:
            self.cc(op, b"\0" + BDADDR)
        elif op == 0x0C23:
            self.cc(op, b"\0\0\0\0")
        elif op == 0x0C14:
            self.cc(op, b"\0" + b"bt17-emu".ljust(248, b"\0"))
        elif op == 0x0C25:
            self.cc(op, struct.pack("<BH", 0, 0x0060))
        elif op == 0x0C38:
            self.cc(op, b"\0\x01")
        elif op == 0x0C39:
            self.cc(op, b"\0\x01\x33\x8B\x9E")
        else:
            if op not in self.unknown:
                self.unknown.add(op)
                log("HCI command 0x%04x: generic Command Complete" % op)
            self.cc(op)


# ---------------------------------------------------------------- MGMT (control channel)
AF_BLUETOOTH, BTPROTO_HCI = 31, 1
HCI_CHANNEL_CONTROL, HCI_DEV_NONE = 3, 0xFFFF
MGMT_EV = {1: "Command Complete", 2: "Command Status", 4: "Index Added", 5: "Index Removed",
           6: "New Settings", 7: "Class Of Device Changed"}


class Mgmt:
    def __init__(self):
        libc = ctypes.CDLL(None, use_errno=True)
        self.fd = libc.socket(AF_BLUETOOTH, socket.SOCK_RAW | socket.SOCK_CLOEXEC, BTPROTO_HCI)
        if self.fd < 0:
            raise OSError(ctypes.get_errno(), "mgmt socket")
        addr = struct.pack("<HHH", AF_BLUETOOTH, HCI_DEV_NONE, HCI_CHANNEL_CONTROL)
        if libc.bind(self.fd, addr, len(addr)) < 0:
            raise OSError(ctypes.get_errno(), "mgmt bind")
        self.replies = []        # (mono, event, opcode, status, index)
        threading.Thread(target=self.reader, daemon=True).start()

    def send(self, op, index, params=b""):
        log("MGMT send opcode 0x%04x index %d params %s" % (op, index, params.hex()))
        os.write(self.fd, struct.pack("<HHH", op, index, len(params)) + params)

    def reader(self):
        while True:
            try:
                b = os.read(self.fd, 1024)
            except OSError as e:
                log("mgmt read ended: %r" % (e,))
                return
            ev, index, ln = struct.unpack("<HHH", b[:6])
            p = b[6:6 + ln]
            name = MGMT_EV.get(ev, "event 0x%04x" % ev)
            if ev in (1, 2):
                op, st = struct.unpack("<HB", p[:3])
                self.replies.append((mono(), ev, op, st, index))
                log("MGMT %s opcode 0x%04x status 0x%02x index %d" % (name, op, st, index))
            else:
                self.replies.append((mono(), ev, None, None, index))
                log("MGMT %s index %d %s" % (name, index, p.hex()))

    def wait_reply(self, op, timeout):
        t = time.time()
        while time.time() - t < timeout:
            for r in self.replies:
                if r[2] == op and r[1] in (1, 2):
                    self.replies.remove(r)
                    return r
            time.sleep(0.02)
        return None


# ---------------------------------------------------------------- the guest side
def usb_dev():
    base = "/sys/bus/usb/devices"
    for d in sorted(os.listdir(base)):
        p = os.path.join(base, d, "idVendor")
        try:
            if open(p).read().strip() == "13d3":
                return os.path.join(base, d)
        except OSError:
            pass
    return None


def rd(path):
    try:
        return open(path).read().strip()
    except OSError as e:
        return "<%s>" % e.strerror


def power_state(dev):
    return {k: rd(os.path.join(dev, "power", k)) for k in
            ("control", "runtime_status", "autosuspend_delay_ms", "persist", "wakeup")}


def wait_for(cond, timeout, step=0.05):
    t = time.time()
    while time.time() - t < timeout:
        if cond():
            return True
        time.sleep(step)
    return False


def dyndbg(lines):
    try:
        with open("/sys/kernel/debug/dynamic_debug/control", "w") as f:
            for l in lines:
                f.write(l + "\n")
        log("dyndbg: " + " | ".join(lines))
    except OSError as e:
        log("dyndbg failed: %r" % (e,))


def kmsg_mark(text):
    try:
        with open("/dev/kmsg", "w") as f:
            f.write("bt17-emu: %s\n" % text)
    except OSError:
        pass


def bring_up(emu, m):
    if not wait_for(lambda: os.path.exists("/sys/class/bluetooth/hci0"), 20):
        log("no hci0: btusb did not bind")
        os.system("dmesg | tail -n 60")
        sys.exit(2)
    log("hci0 present")
    # Set Powered only after the MGMT index exists (status 0x11 Invalid Index before it), and
    # before the kernel's 2 s auto-off closes the device again
    wait_for(lambda: any(r[1] == 4 for r in m.replies), 10)
    for attempt in range(20):
        m.send(0x0005, 0, b"\x01")                # Set Powered
        r = m.wait_reply(0x0005, 15)
        log("Set Powered reply: %s" % (r,))
        if r and r[3] == 0:
            break
        time.sleep(0.2)
    dev = usb_dev()
    log("usb device %s power %s" % (dev, power_state(dev)))
    return dev


def wait_suspended(dev, timeout=15):
    ok = wait_for(lambda: rd(os.path.join(dev, "power", "runtime_status")) == "suspended", timeout)
    log("runtime_status %s after waiting (ok=%s)" % (rd(os.path.join(dev, "power", "runtime_status")), ok))
    return ok


def class_write(m, minor):
    """MGMT Set Device Class: major 1 (Computer), minor varies, so the class really changes"""
    t = mono()
    kmsg_mark("Set Device Class minor %d sent at mono %.6f" % (minor, t))
    m.send(0x000E, 0, bytes([1, minor]))
    return t


def scenario_bt17(emu, m, dev):
    res = {}
    if not wait_suspended(dev):
        log("RESULT bt17 SKIP device never autosuspended")
        return
    time.sleep(1.0)
    t_send = class_write(m, 0x0C)
    r = m.wait_reply(0x000E, 25)
    res["reply"] = r
    log("Set Device Class reply after %.3f s: %s" % ((r[0] - t_send) if r else -1, r))
    # what bluetoothd would do next on the laptop: more class writes (Remove UUID)
    for minor in (0x04, 0x08):
        t2 = class_write(m, minor)
        r2 = m.wait_reply(0x000E, 6)
        log("follow-up class write minor %d reply after %.3f s: %s" % (minor, (r2[0] - t2) if r2 else -1, r2))
    gone = wait_for(lambda: not os.path.exists("/sys/class/bluetooth/hci0"), 25)
    log("hci0 removed: %s; usb device now %s" % (gone, usb_dev()))
    back = wait_for(lambda: os.path.exists("/sys/class/bluetooth/hci0"), 15) if emu.recover else False
    if emu.recover:
        log("hci0 back after recovery: %s" % back)
    log("EMU suspends %d resumes %d state %s held %s" % (emu.suspends, emu.resumes, emu.state, list(emu.held.values())))
    st = ("0x%02x" % r[3]) if r else "none"
    log("RESULT bt17 fail_at=%d recover=%s class-write-status=%s hci0_removed=%s" % (emu.fail_at, emu.recover, st, gone))


def scenario_close_recover(emu, m, dev):
    """the resume that fails is started by closing hci0 (MGMT Set Powered off: btusb_close()
    takes a runtime PM reference), not by a command; the device comes back after the
    reset-resume (--recover). Then power on again and write the class: does Bluetooth work?"""
    if not wait_suspended(dev):
        log("RESULT close-recover SKIP device never autosuspended")
        return
    time.sleep(1.0)
    t = mono()
    kmsg_mark("Set Powered off sent at mono %.6f" % t)
    m.send(0x0005, 0, b"\x00")
    r = m.wait_reply(0x0005, 25)
    log("Set Powered off reply after %.3f s: %s" % ((r[0] - t) if r else -1, r))
    wait_for(lambda: emu.state == "healthy" and emu.resumes >= 1, 15)
    time.sleep(1.0)
    log("power after recovery: %s" % power_state(usb_dev() or dev))
    t = mono()
    kmsg_mark("Set Powered on sent at mono %.6f" % t)
    m.send(0x0005, 0, b"\x01")
    r = m.wait_reply(0x0005, 30)
    log("Set Powered on reply after %.3f s: %s" % ((r[0] - t) if r else -1, r))
    ok = False
    if r and r[3] == 0:
        t = class_write(m, 0x10)
        r2 = m.wait_reply(0x000E, 10)
        log("class write after recovery: %.3f s %s" % ((r2[0] - t) if r2 else -1, r2))
        ok = bool(r2 and r2[3] == 0)
    log("EMU suspends %d resumes %d state %s" % (emu.suspends, emu.resumes, emu.state))
    log("RESULT close-recover bluetooth_works_after=%s" % ok)


def scenario_sysfreeze(emu, m, dev, fault):
    """a system sleep transition (pm_test=devices, freeze: devices suspended, 5 s, resumed),
    with the device kept runtime-active before it; with fault, the GET_STATUS of the system
    resume is held (and --recover makes the device answer after the reset-resume). Then:
    does Bluetooth work?"""
    with open(os.path.join(dev, "power", "control"), "w") as f:
        f.write("on")
    time.sleep(0.5)
    log("power before sleep: %s" % power_state(dev))
    emu.arm_status = fault
    with open("/sys/power/pm_test", "w") as f:
        f.write("devices")
    t = mono()
    kmsg_mark("freeze (pm_test devices) at mono %.6f" % t)
    try:
        with open("/sys/power/state", "w") as f:
            f.write("freeze")
    except OSError as e:
        log("freeze write: %r" % (e,))
    log("back from freeze after %.3f s" % (mono() - t))
    ok_hci = wait_for(lambda: os.path.exists("/sys/class/bluetooth/hci0"), 20)
    time.sleep(2.0)
    ok = False
    if ok_hci:
        for attempt in range(10):
            m.send(0x0005, 0, b"\x01")
            r = m.wait_reply(0x0005, 15)
            log("Set Powered after resume: %s" % (r,))
            if r and r[3] == 0:
                break
            time.sleep(0.5)
        t = class_write(m, 0x14)
        r2 = m.wait_reply(0x000E, 10)
        log("class write after resume: %.3f s %s" % ((r2[0] - t) if r2 else -1, r2))
        ok = bool(r2 and r2[3] == 0)
    log("EMU suspends %d resumes %d state %s" % (emu.suspends, emu.resumes, emu.state))
    log("RESULT sysfreeze fault=%s recover=%s hci0=%s bluetooth_works_after=%s" % (fault, emu.recover, ok_hci, ok))


def scenario_bt23(emu, m, dev, delay_ms):
    """BT-23: a resume that completes between btusb's suspend decision and its anchoring of
    the URB. A debug-only module parameter (bt23_delay_ms) widens that window; the resume is
    forced meanwhile by writing power/control=on. Is the command answered?"""
    if not wait_suspended(dev):
        log("RESULT bt23 SKIP device never autosuspended")
        return
    time.sleep(0.5)
    p = "/sys/module/btusb/parameters/bt23_delay_ms"
    with open(p, "w") as f:
        f.write(str(delay_ms))
    log("bt23_delay_ms = %s" % rd(p))
    box = {}

    def go():
        box["t"] = class_write(m, 0x18)
    th = threading.Thread(target=go)
    th.start()
    time.sleep(0.1)
    t = mono()
    with open(os.path.join(dev, "power", "control"), "w") as f:
        f.write("on")
    log("power/control=on written (resume forced) in %.3f s; runtime_status %s" %
        (mono() - t, rd(os.path.join(dev, "power", "runtime_status"))))
    th.join()
    r = m.wait_reply(0x000E, 8)
    with open(p, "w") as f:
        f.write("0")
    lat = (r[0] - box["t"]) if r else -1
    log("class write reply after %.3f s: %s" % (lat, r))
    st = ("0x%02x" % r[3]) if r else "none"
    log("EMU suspends %d resumes %d state %s" % (emu.suspends, emu.resumes, emu.state))
    log("RESULT bt23 delay=%d status=%s latency=%.3f" % (delay_ms, st, lat))


def scenario_cycles(emu, m, dev, n):
    lat = []
    bad = 0
    for i in range(n):
        if not wait_suspended(dev):
            log("cycle %d: not suspended" % i)
            bad += 1
            continue
        t = class_write(m, (i % 3 + 1) * 4)
        r = m.wait_reply(0x000E, 10)
        if r is None or r[3] != 0:
            bad += 1
            log("cycle %d: reply %s" % (i, r))
        else:
            lat.append(r[0] - t)
    if lat:
        lat.sort()
        log("class write latency after a suspend: n=%d min %.3f median %.3f max %.3f s" %
            (len(lat), lat[0], lat[len(lat) // 2], lat[-1]))
    log("EMU suspends %d resumes %d state %s" % (emu.suspends, emu.resumes, emu.state))
    log("RESULT cycles n=%d failures=%d" % (n, bad))


def main():
    sc = sys.argv[1]
    emu = Emu(fail_at=int(arg("--fail-at", "0")), recover="--recover" in sys.argv,
              hold_hci="--hold-hci" in sys.argv)
    # USB core resume/reset path (what the laptop lacked), btusb's PM callbacks and the HCI
    # command worker's credit line (what the laptop had), nothing per packet
    dyndbg(["file drivers/usb/core/hub.c +p", "file drivers/usb/core/driver.c +p",
            "func btusb_suspend +p", "func btusb_resume +p", "func btusb_disconnect +p",
            "func btusb_waker +p", "func hci_cmd_work +p", "func hci_cmd_timeout +p"])
    m = Mgmt()
    emu.attach()
    dev = bring_up(emu, m)
    try:
        if sc == "bt17":
            scenario_bt17(emu, m, dev)
        elif sc == "provoke":
            # the laptop tool, run unchanged against the emulated device
            import subprocess
            p = subprocess.run(["python3", "-I", "/root/exp/qca9377-bt-hang/scripts/bt17-provoke.py",
                                "--yes", "--interval", "3", "--hours", arg("--provoke-hours", "0.01"),
                                "--log", "/tmp/bt17-provoke"], capture_output=True, text=True)
            for line in (p.stdout + p.stderr).splitlines():
                log("PROVOKE " + line)
            log("EMU suspends %d resumes %d state %s" % (emu.suspends, emu.resumes, emu.state))
            log("RESULT provoke exit=%d failure_seen=%s" % (p.returncode, "FAILURE" in p.stdout))
        elif sc == "close-recover":
            scenario_close_recover(emu, m, dev)
        elif sc == "bt23":
            scenario_bt23(emu, m, dev, int(arg("--delay", "400")))
        elif sc == "sysfreeze":
            scenario_sysfreeze(emu, m, dev, "--fault" in sys.argv)
        elif sc == "cycles":
            scenario_cycles(emu, m, dev, int(arg("--cycles", "10")))
        elif sc == "up":
            log("RESULT up ok")
        else:
            sys.exit("unknown scenario")
    except Exception as e:
        log("scenario raised %r" % (e,))
    log("unhandled HCI opcodes: %s" % sorted("0x%04x" % o for o in emu.unknown))
    log("---- kernel log ----")
    os.system("dmesg")


if __name__ == "__main__":
    main()
```
#### `results/bt17-emulation-2026-11-13/harness/build-guest-kernel.sh`
```sh
#!/bin/bash
# build-guest-kernel.sh <tag>
# Builds the BT-17 guest kernel from the worktree ../linux (whatever patches are applied
# now) into build/kobj (incremental), copies the image to img/bzImage-<tag>, the config to
# img/config-<tag>, and records HEAD and the modified files in img/bzImage-<tag>.commit.
set -u
w=/root/exp/agent-work/bt17-emu-20261113
t=$w/linux
obj=$w/build/kobj
tag=${1:?usage}
mkdir -p "$obj" "$w/img"
if [ ! -e "$obj/.config" ]; then
	cp /root/exp/agent-work/co20-diag-20261101/img/config-base "$obj/.config" || exit 2
	cat "$w/scripts/frag-bt17.config" >>"$obj/.config"
fi
make -C "$t" O="$obj" ARCH=x86_64 olddefconfig || exit 1
make -C "$t" O="$obj" ARCH=x86_64 -j14 bzImage
rc=$?
echo "make rc=$rc"
[ $rc -eq 0 ] || exit 1
cp "$obj/arch/x86/boot/bzImage" "$w/img/bzImage-$tag"
cp "$obj/.config" "$w/img/config-$tag"
{
	git -C "$t" log -1 --format='%H %s'
	git -C "$t" status --short
	git -C "$t" diff --stat
	grep -E "^CONFIG_(SMP|NR_CPUS|KASAN|PROVE_LOCKING|DYNAMIC_DEBUG|BT_HCIBTUSB|BT_HCIBTUSB_AUTOSUSPEND|USBIP_VHCI_HCD|USB_MON|USB_DUMMY_HCD|USB_RAW_GADGET)=" "$obj/.config"
} >"$w/img/bzImage-$tag.commit"
sha256sum "$w/img/bzImage-$tag"
```
#### `results/bt17-emulation-2026-11-13/harness/frag-bt17.config`
```
# BT-17 guest: appended to the co20-diag guest config (BlueZ tester.config + SMP + dynamic debug)
# usbip virtual host controller, so that the real btusb binds to a userspace device
CONFIG_USBIP_CORE=y
CONFIG_USBIP_VHCI_HCD=y
CONFIG_USBIP_VHCI_HC_PORTS=8
CONFIG_USBIP_VHCI_NR_HCS=1
CONFIG_USB_ANNOUNCE_NEW_DEVICES=y
# as on the laptop: btusb enables runtime autosuspend at probe
CONFIG_BT_HCIBTUSB_AUTOSUSPEND=y
# passive USB capture inside the guest
CONFIG_USB_MON=y
# for a later remote-wakeup variant: a gadget-side device on a dummy host controller
CONFIG_USB_GADGET=y
CONFIG_USB_DUMMY_HCD=y
CONFIG_USB_RAW_GADGET=y
```
#### `results/bt17-emulation-2026-11-13/harness/qemu-smp-hostcpu.sh`
```sh
#!/bin/bash
# qemu-smp-hostcpu.sh - as tmp/mesh-tester-ci/qemu-smp.sh (drops "acpi=off pci=noacpi noapic"
# from -append, adds -smp), and adds "-cpu host" at the end, so that on this Ryzen host the
# guest kernel sees X86_FEATURE_ZEN (btusb's platform_is_ryzen()).
set -u
args=()
for a in "$@"; do
	case "$a" in
	console=hvc0*)
		a="${a/ acpi=off pci=noacpi noapic/}"
		;;
	esac
	args+=("$a")
done
exec /usr/bin/qemu-system-x86_64 "${args[@]}" -smp "${QEMU_SMP:-4}" -cpu host
```
#### `results/bt17-emulation-2026-11-13/harness/rg-emu.py`
```python
#!/usr/bin/env python3
"""rg-emu.py - the emulated 13d3:3503 of bt17-emu.py on a second bus: USB Raw Gadget on
dummy_hcd (both in the guest kernel), for what usbip cannot do. vhci_hcd refuses system
suspend while a device is attached; dummy_hcd suspends once its root hub has.

Scenario sysfreeze [--reset-resume]: a system sleep transition (pm_test=devices, freeze) of
the running controller. With --reset-resume the device is given USB_QUIRK_RESET_RESUME
(usbcore.quirks "13d3:3503:b") before it enumerates, as btusb_check_needs_reset_resume() gives
the QCA ROME devices of its DMI table: the USB core then resets it at every resume. That is the
system-resume path CO-43 D changes. Then: does Bluetooth work?

Usage: rg-emu.py sysfreeze [--reset-resume]
"""
import ctypes
import fcntl
import os
import queue
import socket
import struct
import sys
import threading
import time

T0 = time.time()
LOCK = threading.Lock()


def mono():
    return time.clock_gettime(time.CLOCK_MONOTONIC)


def log(msg):
    with LOCK:
        print("%8.3f [mono %10.6f] %s" % (time.time() - T0, mono(), msg), flush=True)


def _ioc(d, nr, size):
    return (d << 30) | (size << 16) | (ord("U") << 8) | nr


RAW_INIT = _ioc(1, 0, 257)
RAW_RUN = _ioc(0, 1, 0)
RAW_EVENT_FETCH = _ioc(2, 2, 8)
RAW_EP0_WRITE = _ioc(1, 3, 8)
RAW_EP0_READ = _ioc(3, 4, 8)
RAW_EP_ENABLE = _ioc(1, 5, 9)
RAW_EP_WRITE = _ioc(1, 7, 8)
RAW_CONFIGURE = _ioc(0, 9, 0)
RAW_VBUS_DRAW = _ioc(1, 10, 4)
RAW_EP0_STALL = _ioc(0, 12, 0)
EV = {1: "CONNECT", 2: "CONTROL", 3: "SUSPEND", 4: "RESUME", 5: "RESET", 6: "DISCONNECT"}

# dummy_udc's fixed endpoints: ep1in-bulk, ep2out-bulk, ep3in-iso, ep4out-iso, ep5in-int
EP_INT_IN, EP_BULK_IN, EP_BULK_OUT, EP_ISO_IN, EP_ISO_OUT = 0x85, 0x81, 0x02, 0x83, 0x04


def epd(addr, attr, mps, ival):
    return struct.pack("<BBBBHB", 7, 5, addr, attr, mps, ival)


def iface(num, alt, neps):
    return struct.pack("<BBBBBBBBB", 9, 4, num, alt, neps, 0xE0, 1, 1, 0)


def config_desc():
    body = iface(0, 0, 3) + epd(EP_INT_IN, 3, 16, 1) + epd(EP_BULK_IN, 2, 64, 0) + epd(EP_BULK_OUT, 2, 64, 0)
    for alt, mps in enumerate((0, 9, 17, 25, 33, 49)):
        body += iface(1, alt, 2) + epd(EP_ISO_IN, 1, mps, 1) + epd(EP_ISO_OUT, 1, mps, 1)
    return struct.pack("<BBHBBBBB", 9, 2, 9 + len(body), 2, 1, 0, 0xE0, 50) + body


DEV_DESC = struct.pack("<BBHBBBBHHHBBBB", 18, 1, 0x0110, 0xE0, 1, 1, 64,
                       0x13D3, 0x3503, 0x0001, 0, 0, 0, 1)
QCA_VERSION = struct.pack("<IIIBBH4s", 0x302, 0x3E8, 0x302, 0, 0, 0, b"\0" * 4)
FEATURES = bytes([0xFF, 0xFF, 0x8F, 0xFE, 0x9B, 0xF9, 0x00, 0x00])
BDADDR = bytes([0x00, 0x00, 0x00, 0x77, 0x17, 0x01])


class Gadget:
    def __init__(self):
        self.fd = os.open("/dev/raw-gadget", os.O_RDWR)
        init = b"dummy_udc".ljust(128, b"\0") + b"dummy_udc.0".ljust(128, b"\0") + bytes([2])
        fcntl.ioctl(self.fd, RAW_INIT, init)
        fcntl.ioctl(self.fd, RAW_RUN, 0)
        self.ep_int = None
        self.events = queue.Queue()
        self.counts = {}
        self.configured = False
        threading.Thread(target=self.ep0_loop, daemon=True).start()
        threading.Thread(target=self.int_writer, daemon=True).start()

    def count(self, k):
        self.counts[k] = self.counts.get(k, 0) + 1

    def ep0_write(self, data):
        buf = bytearray(struct.pack("<HHI", 0, 0, len(data)) + data)
        return fcntl.ioctl(self.fd, RAW_EP0_WRITE, buf, True)

    def ep0_read(self, n):
        buf = bytearray(struct.pack("<HHI", 0, 0, n) + b"\0" * n)
        r = fcntl.ioctl(self.fd, RAW_EP0_READ, buf, True)
        return bytes(buf[8:8 + n]), r

    def stall(self):
        fcntl.ioctl(self.fd, RAW_EP0_STALL, 0)

    def ep0_loop(self):
        while True:
            buf = bytearray(struct.pack("<II", 0, 8) + b"\0" * 8)
            try:
                fcntl.ioctl(self.fd, RAW_EVENT_FETCH, buf, True)
            except OSError as e:
                log("event fetch ended: %r" % (e,))
                return
            typ, ln = struct.unpack("<II", buf[:8])
            name = EV.get(typ, str(typ))
            if typ != 2:
                self.count(name)
                log("GADGET event %s" % name)
                continue
            try:
                self.control(bytes(buf[8:16]))
            except OSError as e:
                log("control handling: %r" % (e,))

    def control(self, setup):
        bm, br, wv, wi, wl = struct.unpack("<BBHHH", setup)
        if bm == 0x80 and br == 6:
            t = wv >> 8
            d = DEV_DESC if t == 1 else config_desc() if t == 2 else None
            if d is None:
                self.stall()
                return
            self.ep0_write(d[:wl])
        elif bm == 0x00 and br == 9:                     # SET_CONFIGURATION
            if not self.configured:
                # a mutable buffer, so that ioctl() returns the handle, not the buffer
                self.ep_int = fcntl.ioctl(self.fd, RAW_EP_ENABLE,
                                          bytearray(epd(EP_INT_IN, 3, 16, 1) + b"\0\0"), True)
                fcntl.ioctl(self.fd, RAW_EP_ENABLE, bytearray(epd(EP_BULK_IN, 2, 64, 0) + b"\0\0"), True)
                fcntl.ioctl(self.fd, RAW_EP_ENABLE, bytearray(epd(EP_BULK_OUT, 2, 64, 0) + b"\0\0"), True)
                fcntl.ioctl(self.fd, RAW_CONFIGURE, 0)
                fcntl.ioctl(self.fd, RAW_VBUS_DRAW, 50)
                self.configured = True
                log("GADGET configured, interrupt endpoint handle %d" % self.ep_int)
            self.ep0_read(0)
        elif bm == 0xC0 and br == 0x09:
            self.ep0_write(QCA_VERSION[:wl])
        elif bm == 0xC0 and br == 0x05:
            self.ep0_write(b"\xc0")
        elif bm == 0x20 and br == 0:                     # HCI command
            data, _ = self.ep0_read(wl)
            op, plen = struct.unpack("<HB", data[:3])
            self.hci(op)
        elif bm & 0x80:
            self.ep0_write(b"\0" * min(wl, 2))
        else:                                            # SET_INTERFACE, features: acknowledge
            self.ep0_read(0)

    def event(self, code, params):
        self.events.put(bytes([code, len(params)]) + params)

    def int_writer(self):
        while True:
            ev = self.events.get()
            while self.ep_int is None:
                time.sleep(0.01)
            for i in range(0, len(ev), 16):
                chunk = ev[i:i + 16]
                buf = bytearray(struct.pack("<HHI", self.ep_int, 0, len(chunk)) + chunk)
                try:
                    fcntl.ioctl(self.fd, RAW_EP_WRITE, buf, True)
                except OSError as e:
                    log("interrupt write: %r" % (e,))
                    break

    def cc(self, op, ret=b"\0"):
        self.event(0x0E, struct.pack("<BH", 1, op) + ret)

    def hci(self, op):
        self.count("hci 0x%04x" % op)
        if op == 0x1001:
            self.cc(op, struct.pack("<BBHBHH", 0, 6, 0x0302, 6, 0x0045, 0x0302))
        elif op == 0x1002:
            c = bytearray(64)
            c[9] = 0x04
            self.cc(op, b"\0" + bytes(c))
        elif op == 0x1003:
            self.cc(op, b"\0" + FEATURES)
        elif op == 0x1005:
            self.cc(op, struct.pack("<BHBHH", 0, 1021, 64, 8, 8))
        elif op == 0x1009:
            self.cc(op, b"\0" + BDADDR)
        elif op == 0x0C23:
            self.cc(op, b"\0\0\0\0")
        elif op == 0x0C14:
            self.cc(op, b"\0" + b"rg-emu".ljust(248, b"\0"))
        elif op == 0x0C25:
            self.cc(op, struct.pack("<BH", 0, 0x0060))
        elif op == 0x0C38:
            self.cc(op, b"\0\x01")
        elif op == 0x0C39:
            self.cc(op, b"\0\x01\x33\x8B\x9E")
        else:
            self.cc(op)


# ---------------------------------------------------------------- MGMT, as in bt17-emu.py
class Mgmt:
    def __init__(self):
        libc = ctypes.CDLL(None, use_errno=True)
        self.fd = libc.socket(31, socket.SOCK_RAW | socket.SOCK_CLOEXEC, 1)
        addr = struct.pack("<HHH", 31, 0xFFFF, 3)
        if libc.bind(self.fd, addr, len(addr)) < 0:
            raise OSError(ctypes.get_errno(), "mgmt bind")
        self.replies = []
        threading.Thread(target=self.reader, daemon=True).start()

    def send(self, op, index, params=b""):
        os.write(self.fd, struct.pack("<HHH", op, index, len(params)) + params)

    def reader(self):
        while True:
            b = os.read(self.fd, 1024)
            ev, index, ln = struct.unpack("<HHH", b[:6])
            p = b[6:6 + ln]
            if ev in (1, 2):
                op, st = struct.unpack("<HB", p[:3])
                self.replies.append((mono(), ev, op, st, index))
                log("MGMT reply opcode 0x%04x status 0x%02x index %d" % (op, st, index))
            else:
                self.replies.append((mono(), ev, None, None, index))
                log("MGMT event 0x%04x index %d" % (ev, index))

    def wait(self, op, timeout):
        t = time.time()
        while time.time() - t < timeout:
            for r in self.replies:
                if r[2] == op:
                    self.replies.remove(r)
                    return r
            time.sleep(0.02)
        return None


def wait_for(cond, timeout):
    t = time.time()
    while time.time() - t < timeout:
        if cond():
            return True
        time.sleep(0.05)
    return False


def power_on(m):
    for _ in range(20):
        m.send(0x0005, 0, b"\x01")
        r = m.wait(0x0005, 10)
        if r and r[3] == 0:
            return True
        time.sleep(0.3)
    return False


def class_ok(m, minor):
    m.send(0x000E, 0, bytes([1, minor]))
    r = m.wait(0x000E, 8)
    log("class write minor %d: %s" % (minor, r))
    return bool(r and r[3] == 0)


def main():
    rr = "--reset-resume" in sys.argv
    with open("/sys/kernel/debug/dynamic_debug/control", "w") as f:
        for l in ("file drivers/usb/core/hub.c +p", "file drivers/usb/core/driver.c +p",
                  "func btusb_suspend +p", "func btusb_resume +p", "func btusb_reset_resume +p",
                  "func btusb_disconnect +p", "func btusb_probe +p"):
            f.write(l + "\n")
    if rr:
        with open("/sys/module/usbcore/parameters/quirks", "w") as f:
            f.write("13d3:3503:b")
        log("usbcore quirks: %s" % open("/sys/module/usbcore/parameters/quirks").read().strip())
    m = Mgmt()
    g = Gadget()
    if not wait_for(lambda: os.path.exists("/sys/class/bluetooth/hci0"), 20):
        log("no hci0")
        os.system("dmesg | tail -n 80")
        sys.exit(2)
    time.sleep(0.5)
    ok0 = power_on(m) and class_ok(m, 0x0C)
    log("before sleep: bluetooth works=%s" % ok0)
    with open("/sys/power/pm_test", "w") as f:
        f.write("devices")
    t = mono()
    try:
        with open("/sys/power/state", "w") as f:
            f.write("freeze")
    except OSError as e:
        log("freeze write: %r" % (e,))
    log("back from freeze after %.3f s; gadget events %s" % (mono() - t, g.counts))
    time.sleep(3.0)
    present = wait_for(lambda: os.path.exists("/sys/class/bluetooth/hci0"), 15)
    time.sleep(1.0)
    ok1 = present and power_on(m) and class_ok(m, 0x10)
    log("gadget events %s" % {k: v for k, v in g.counts.items() if not k.startswith("hci")})
    log("RESULT rg-sysfreeze reset_resume_quirk=%s before=%s after=%s slept=%.1f" %
        (rr, ok0, ok1, 0))
    os.system("dmesg")


if __name__ == "__main__":
    main()
```
#### `results/bt17-emulation-2026-11-13/harness/run-guest-hostcpu.sh`
```sh
#!/bin/bash
# run-guest-hostcpu.sh <same arguments as run-guest.sh>: the guest gets the host's CPU model
# (a Ryzen here), so that btusb's platform_is_ryzen() is true in the guest.
export HOSTCPU=1
exec /root/exp/agent-work/bt17-emu-20261113/scripts/run-guest.sh "$@"
```
#### `results/bt17-emulation-2026-11-13/harness/run-guest-rg.sh`
```sh
#!/bin/bash
# run-guest-rg.sh <kernel tag> <run label> [rg-emu.py args...]
# As run-guest.sh, with scripts/rg-emu.py (Raw Gadget on dummy_hcd) as the guest's command.
set -u
ulimit -c 0
w=/root/exp/agent-work/bt17-emu-20261113
tr=/root/exp/agent-work/co20-diag-20261101/bin/test-runner-r3
q=/root/exp/qca9377-bt-hang/tmp/mesh-tester-ci/qemu-smp.sh
tag=${1:?usage}
label=${2:?usage}
shift 2
log=$w/logs/$tag-rg-$label.log
[ -e "$log" ] && { echo "exists: $log"; exit 2; }
echo "start $(date '+%F %T') kernel $tag label rg-$label args $*" >"$log"
sha256sum "$w/img/bzImage-$tag" "$w/scripts/rg-emu.py" >>"$log"
timeout 300 "$tr" -q "$q" -k "$w/img/bzImage-$tag" -- python3 -I "$w/scripts/rg-emu.py" "$@" >>"$log" 2>&1
echo "exit=$? end $(date '+%F %T')" >>"$log"
grep -a -E "RESULT|GADGET event|before sleep|back from freeze|no reset_resume|reset_resume|Resetting usb|reset full-speed|USB disconnect|failed to suspend|Traceback|Error|no hci0" "$log"
```
#### `results/bt17-emulation-2026-11-13/harness/run-guest.sh`
```sh
#!/bin/bash
# run-guest.sh <kernel tag> <run label> <scenario> [emulator args...]
# One QEMU/KVM guest (4 CPUs, the project's qemu-smp.sh wrapper, BlueZ's test-runner with the
# host's root as the guest's root) running scripts/bt17-emu.py <scenario> [args] as its command.
# Log: logs/<tag>-<label>.log (refuses to overwrite); the RESULT and key kernel lines printed.
set -u
ulimit -c 0
w=/root/exp/agent-work/bt17-emu-20261113
tr=/root/exp/agent-work/co20-diag-20261101/bin/test-runner-r3
q=/root/exp/qca9377-bt-hang/tmp/mesh-tester-ci/qemu-smp.sh
# HOSTCPU=1: the guest gets the host's CPU model (a Ryzen here), for the platform quirk
[ "${HOSTCPU:-0}" = 1 ] && q=$w/scripts/qemu-smp-hostcpu.sh
tag=${1:?usage}
label=${2:?usage}
shift 2
mkdir -p "$w/logs"
log=$w/logs/$tag-$label.log
[ -e "$log" ] && { echo "exists: $log"; exit 2; }
echo "start $(date '+%F %T') kernel $tag label $label args $* cpus ${QEMU_SMP:-4}" >"$log"
sha256sum "$w/img/bzImage-$tag" "$w/scripts/bt17-emu.py" >>"$log"
timeout 300 "$tr" -q "$q" -k "$w/img/bzImage-$tag" -- python3 -I "$w/scripts/bt17-emu.py" "$@" >>"$log" 2>&1
echo "exit=$? end $(date '+%F %T')" >>"$log"
grep -a -E "RESULT|EMU |MGMT (Command|Index)|command( 0x[0-9a-f]+)? tx timeout|Failed usb_autopm|Resetting usb|reset-resume|reset full-speed|USB disconnect|descriptor read|can't resume|gone after|failed: -110|btusb_waker|autoresume" "$log"
```
#### `results/bt17-emulation-2026-11-13/harness/run-matrix.sh`
```sh
#!/bin/bash
# run-matrix.sh <kernel tag> <first run number> <last run number>
# For each run number: the BT-17 fault (dead device), the command-started resume of a
# device that recovers, the close-started resume of a device that recovers; one guest each,
# sequentially, through run-guest.sh. Then one long healthy run (50 cycles).
# Summary: logs/matrix-<tag>-<first>-<last>.txt (the RESULT lines).
set -u
w=/root/exp/agent-work/bt17-emu-20261113
tag=${1:?usage}
a=${2:?usage}
b=${3:?usage}
out=$w/logs/matrix-$tag-$a-$b.txt
: >"$out"
for n in $(seq "$a" "$b"); do
	for sc in "dead bt17 --fail-at 1" "recover bt17 --fail-at 1 --recover" "close close-recover --fail-at 1 --recover"; do
		set -- $sc
		label=$1
		shift
		"$w/scripts/run-guest.sh" "$tag" "m-$label-$n" "$@" >/dev/null
		grep -a -h -E "RESULT|Failed usb_autopm|not resumed|Failed to resume|Resetting usb|BUG:|WARNING:|KASAN|possible circular" "$w/logs/$tag-m-$label-$n.log" |
			sed "s/^/$tag $label $n: /" >>"$out"
	done
done
"$w/scripts/run-guest.sh" "$tag" "m-cycles50-$a" cycles --cycles 50 >/dev/null
grep -a -h -E "RESULT|latency|BUG:|WARNING:|KASAN" "$w/logs/$tag-m-cycles50-$a.log" | sed "s/^/$tag cycles50: /" >>"$out"
echo "matrix $tag $a-$b done: $out"
```
#### `scripts/bt17-provoke.py`
```python
#!/usr/bin/env python3
"""bt17-provoke.py - drive many runtime suspend/resume cycles of the laptop's Bluetooth
controller (USB 13d3:3503) to measure how often a host-initiated resume fails (BT-17).

FOR THE OPERATOR ONLY. It talks to the real controller. If BT-17 reproduces, Bluetooth is
gone until a full power-off. Run it only when that is acceptable, with no headset in use,
and preferably after scripts/bt17-arm-usb-debug.sh --usbmon, so that a failure is recorded
in full.

What it does, per cycle:
  1. waits until the controller's USB device is runtime-suspended (power/runtime_status),
     which btusb's 2 s autosuspend delay brings about when nothing is sent;
  2. sends one harmless read command, HCI Read Local Name (0x0c14), on a raw HCI socket:
     the command wakes the device through btusb_waker(), as Write Class of Device did at
     the incident;
  3. waits up to 3 s for its Command Complete and records the latency.
It stops at the first command without an answer, saves the kernel log tail and the sysfs
power state next to its log, and prints what to do next (nothing: leave the machine as is
for the record, then power it off).

It sends no reset, writes nothing to sysfs, loads or unloads nothing. Device addresses are
never read or printed.

Usage (root): bt17-provoke.py --yes [--interval 6] [--hours 1] [--log DIR]
"""
import ctypes
import os
import socket
import struct
import subprocess
import sys
import time

AF_BLUETOOTH, BTPROTO_HCI, SOL_HCI, HCI_FILTER = 31, 1, 0, 2
HCI_CHANNEL_RAW = 0
OP_READ_LOCAL_NAME = 0x0C14


def arg(name, default):
    if name in sys.argv:
        return sys.argv[sys.argv.index(name) + 1]
    return default


def usb_dev():
    base = "/sys/bus/usb/devices"
    for d in sorted(os.listdir(base)):
        try:
            if open(os.path.join(base, d, "idVendor")).read().strip() == "13d3" and \
               open(os.path.join(base, d, "idProduct")).read().strip() == "3503":
                return os.path.join(base, d)
        except OSError:
            pass
    return None


def rd(p):
    try:
        return open(p).read().strip()
    except OSError as e:
        return "<%s>" % e.strerror


def raw_socket(dev_id=0):
    libc = ctypes.CDLL(None, use_errno=True)
    fd = libc.socket(AF_BLUETOOTH, socket.SOCK_RAW | socket.SOCK_CLOEXEC, BTPROTO_HCI)
    if fd < 0:
        raise OSError(ctypes.get_errno(), "socket")
    addr = struct.pack("<HHH", AF_BLUETOOTH, dev_id, HCI_CHANNEL_RAW)
    if libc.bind(fd, addr, len(addr)) < 0:
        raise OSError(ctypes.get_errno(), "bind")
    s = socket.socket(fileno=fd)
    # receive HCI events only (type 4), every event code; struct hci_ufilter is 16 bytes
    # with its padding, and the kernel refuses a shorter option (EINVAL)
    flt = struct.pack("<IIIHxx", 1 << 4, 0xFFFFFFFF, 0xFFFFFFFF, 0)
    s.setsockopt(SOL_HCI, HCI_FILTER, flt)
    return s


def command(s, op, timeout=3.0):
    s.send(struct.pack("<BHB", 1, op, 0))
    t0 = time.monotonic()
    s.settimeout(0.2)
    while time.monotonic() - t0 < timeout:
        try:
            b = s.recv(300)
        except socket.timeout:
            continue
        if len(b) >= 6 and b[0] == 4 and b[1] == 0x0E and struct.unpack("<H", b[4:6])[0] == op:
            return time.monotonic() - t0, b[6]
    return None, None


def main():
    if "--yes" not in sys.argv:
        print(__doc__)
        sys.exit("refusing without --yes (see the warning above)")
    interval = float(arg("--interval", "6"))
    hours = float(arg("--hours", "1"))
    logdir = arg("--log", "/var/log/bt-health/bt17-provoke")
    os.makedirs(logdir, exist_ok=True)
    stamp = time.strftime("%Y%m%d-%H%M%S")
    logf = open(os.path.join(logdir, "provoke-%s.log" % stamp), "w")

    def log(msg):
        line = "%s %s" % (time.strftime("%H:%M:%S"), msg)
        print(line, flush=True)
        logf.write(line + "\n")
        logf.flush()

    dev = usb_dev()
    if not dev:
        sys.exit("no 13d3:3503 on USB")
    pw = {k: rd(os.path.join(dev, "power", k)) for k in
          ("control", "autosuspend_delay_ms", "runtime_status", "persist")}
    log("device %s power %s" % (dev, pw))
    if pw["control"] != "auto":
        sys.exit("power/control is %s: the device cannot runtime-suspend, nothing to test" % pw["control"])
    if not os.path.exists("/sys/class/bluetooth/hci0"):
        sys.exit("no hci0")
    s = raw_socket(0)
    end = time.monotonic() + hours * 3600
    n = 0
    lat = []
    while time.monotonic() < end:
        t = time.monotonic()
        while rd(os.path.join(dev, "power", "runtime_status")) != "suspended" and time.monotonic() - t < 10:
            time.sleep(0.05)
        st = rd(os.path.join(dev, "power", "runtime_status"))
        if st != "suspended":
            log("cycle %d: device %s after 10 s (something keeps it awake); waiting" % (n, st))
            time.sleep(interval)
            continue
        d, status = command(s, OP_READ_LOCAL_NAME)
        n += 1
        if d is None:
            log("FAILURE at cycle %d: Read Local Name got no answer in 3 s" % n)
            with open(os.path.join(logdir, "provoke-%s-dmesg.txt" % stamp), "w") as f:
                f.write(subprocess.run(["dmesg", "-T"], capture_output=True, text=True).stdout[-200000:])
            log("power now %s" % {k: rd(os.path.join(dev, "power", k)) for k in
                                 ("control", "runtime_status")} if os.path.exists(dev) else "device gone")
            log("leave the machine as it is until the evidence is collected, then power it off")
            break
        lat.append(d)
        if n % 50 == 0:
            ls = sorted(lat)
            log("%d cycles, latency median %.3f s max %.3f s" % (n, ls[len(ls) // 2], ls[-1]))
        time.sleep(max(0.0, interval - (time.monotonic() - t)))
    log("done: %d cycles, %d answered" % (n, len(lat)))


if __name__ == "__main__":
    main()
```
#### `scripts/bt17-arm-usb-debug.sh`
```sh
#!/bin/bash
# bt17-arm-usb-debug.sh [--usbmon] [--off]
#
# BT-17: make the next natural loss of the Bluetooth controller (USB 3-3, 13d3:3503)
# decisive, without touching the controller. Run as root, by the operator only.
#
#   (no option)  turn on USB core dynamic debug for the resume/reset path
#                (drivers/usb/core/hub.c and driver.c): "usb auto-resume" or
#                "usb wakeup-resume" (who started the resume), "Waited Nms for CONNECT",
#                "finish resume", "retry with reset-resume", "gone after usb resume?".
#                These are kernel log lines only; nothing is sent to any device.
#   --usbmon     also start a bounded capture of USB bus 3's traffic (usbmon text,
#                in 50 MB parts under /var/log/bt-health/usbmon/; split's one-digit suffix
#                stops the capture after ten parts, 500 MB), to see
#                whether the GET_STATUS after a resume was answered at all.
#                Needs the usbmon module (loading it touches neither btusb nor bluetooth.ko).
#   --off        turn the debug lines off again and stop the capture.
#
# What it does not do: no reset, no rebind, no module reload, no sysfs power write.
# The lines it enables are low-volume except during USB enumeration; the capture of bus 3
# carries the HCI traffic of the controller, which includes device addresses: it stays
# local (/var/log/bt-health is never published).
set -u
ctl=/sys/kernel/debug/dynamic_debug/control
dir=/var/log/bt-health/usbmon
if [ "${1:-}" = "--off" ]; then
	echo 'file drivers/usb/core/hub.c -p' >"$ctl"
	echo 'file drivers/usb/core/driver.c -p' >"$ctl"
	pkill -f "bt17-usbmon-capture" && echo "usbmon capture stopped"
	echo "USB core debug off"
	exit 0
fi
[ -w "$ctl" ] || { echo "needs root and debugfs ($ctl)"; exit 2; }
echo 'file drivers/usb/core/hub.c +p' >"$ctl"
echo 'file drivers/usb/core/driver.c +p' >"$ctl"
echo "USB core debug on: $(grep -c -E 'drivers/usb/core/(hub|driver)\.c.*=p' "$ctl") sites"
if [ "${1:-}" = "--usbmon" ]; then
	modprobe usbmon || exit 1
	mkdir -p "$dir"
	# bus number of the controller's root hub (3 on this laptop): read from sysfs
	bus=$(cat /sys/bus/usb/devices/3-3/busnum 2>/dev/null || echo 3)
	nohup bash -c "exec -a bt17-usbmon-capture sh -c 'cat /sys/kernel/debug/usb/usbmon/${bus}u | split -b 50M -d -a 1 - $dir/bus${bus}-\$(date +%Y%m%d-%H%M%S)-'" \
		>/dev/null 2>&1 &
	echo "usbmon capture of bus $bus started into $dir (stop with --off; prune old parts by hand)"
fi
```

## 9. Representative test logs (kernel lines)
Full logs: `results/bt17-emulation-2026-11-13/logs/runs/` with `SHA256SUMS`.
#### `results/bt17-emulation-2026-11-13/logs/runs/base-bt17-2.log`
Lines matching `RESULT|SCENARIO|step|usb 2-1|usb 1-1|btusb|Bluetooth|hci0: |tx timeout|reset|resume|suspend|disconnect|Resetting|PM: |BUG|WARNING|platform_pm|raw-gadget|not running|status 0x`, without `cmd_cnt|dyndbg:|Calibrating`, colour codes removed. 
```
Bluetooth: hci0: HCI Enhanced Setup Synchronous Connection command is advertised, but not supported.
   0.807 [mono  13.101513] MGMT Command Complete opcode 0x0005 status 0x00 index 0
   0.841 [mono  13.135961] usb device /sys/bus/usb/devices/2-1 power {'control': 'auto', 'runtime_status': 'active', 'autosuspend_delay_ms': '2000', 'persist': '1', 'wakeup': 'disabled'}
   2.843 [mono  15.137187] EMU suspend #1 (SET_FEATURE remote wakeup)
   2.893 [mono  15.187231] runtime_status suspended after waiting (ok=True)
   3.988 [mono  16.282614] EMU resume #1: GET_STATUS held, device wedged
Bluetooth: hci0: command 0x0c24 tx timeout
Bluetooth: hci0: Opcode 0x0c24 failed: -110
   5.991 [mono  18.286049] MGMT Command Complete opcode 0x000e status 0x05 index 0
Bluetooth: hci0: Opcode 0x0c24 failed: -110
   8.079 [mono  20.373778] MGMT Command Complete opcode 0x000e status 0x05 index 0
   9.183 [mono  21.477207] EMU host gave up on held GET_STATUS of resume #1 (unlink)
usb 2-1: device descriptor read/64, error -71
usb 2-1: device descriptor read/64, error -71
usb 2-1: device descriptor read/64, error -71
Bluetooth: hci0: Opcode 0x0c24 failed: -110
  10.153 [mono  22.447520] MGMT Command Complete opcode 0x000e status 0x05 index 0
usb 2-1: device descriptor read/64, error -71
usb 2-1: device descriptor read/8, error -71
usb 2-1: device descriptor read/8, error -71
usb 2-1: device descriptor read/8, error -71
usb 2-1: device descriptor read/8, error -71
Bluetooth: hci0: Failed usb_autopm_get_interface: -16
  11.440 [mono  23.734375] EMU suspends 1 resumes 1 state dead held []
  11.449 [mono  23.743564] RESULT bt17 fail_at=1 recover=False class-write-status=0x05 hci0_removed=True
usb 2-1: device descriptor read/64, error -71
usb 2-1: device descriptor read/64, error -71
[    0.371107] smpboot: CPU0: AMD QEMU Virtual CPU version 2.5+ (family: 0xf, model: 0x6b, stepping: 0x1)
[    0.492367] thermal_sys: Registered thermal governor 'step_wise'
[    0.826459] ACPI: PM: (supports S0 S3 S5)
[    1.205541] Bluetooth: Core ver 2.22
[    1.205671] Bluetooth: HCI device and connection manager initialized
[    1.205723] Bluetooth: HCI socket layer initialized
[    1.205758] Bluetooth: L2CAP socket layer initialized
[    1.205861] Bluetooth: SCO socket layer initialized
usb 2-1: device descriptor read/64, error -71
[    2.451727] Bluetooth: HCI UART driver ver 2.3
[    2.451747] Bluetooth: HCI UART protocol H4 registered
[    2.451753] Bluetooth: HCI UART protocol BCSP registered
[    2.451846] Bluetooth: HCI UART protocol LL registered
[    2.451851] Bluetooth: HCI UART protocol ATH3K registered
[    2.451937] Bluetooth: HCI UART protocol Three-wire (H5) registered
[    2.452019] Bluetooth: HCI UART protocol QCA registered
[    2.452023] Bluetooth: HCI UART protocol AG6XX registered
[    2.452102] Bluetooth: HCI UART protocol Marvell registered
[    2.452180] Bluetooth: HCI UART protocol AML registered
[    2.452734] usbcore: registered new interface driver btusb
[    2.466507] Bluetooth: RFCOMM socket layer initialized
[    2.466590] Bluetooth: RFCOMM ver 1.11
[    2.466630] Bluetooth: BNEP (Ethernet Emulation) ver 1.3
[    2.466652] Bluetooth: BNEP socket layer initialized
[    2.466658] Bluetooth: HIDP (Human Interface Emulation) ver 1.2
[    2.466675] Bluetooth: HIDP socket layer initialized
[   12.413515] usb usb2: usb wakeup-resume
[   12.413614] hub 2-0:1.0: hub_resume
[   12.648275] usb 2-1: new full-speed USB device number 2 using vhci_hcd
[   12.801832] usb 2-1: SetAddress Request (2) to port 0
[   12.818372] usb 2-1: New USB device found: idVendor=13d3, idProduct=3503, bcdDevice=0.01
[   12.828610] usb 2-1: udev 2, busnum 2, minor = 129
[   12.829553] usb 2-1: New USB device strings: Mfr=0, Product=0, SerialNumber=0
[   12.832978] usb 2-1: usb_probe_device
[   12.840281] btusb 2-1:1.0: usb_probe_interface
[   12.844581] btusb 2-1:1.0: usb_probe_interface - got id
[   12.856190] Bluetooth: hci0: HCI Enhanced Setup Synchronous Connection command is advertised, but not supported.
[   13.083843] Bluetooth: MGMT ver 1.23
[   15.159350] usb 2-1: usb auto-suspend, wakeup 1
[   15.174841] hub 2-0:1.0: hub_suspend
[   16.229051] hub 2-0:1.0: hub_resume
[   16.230214] usb 2-1: usb auto-resume
[   16.289472] usb 2-1: Waited 0ms for CONNECT
[   16.289501] usb 2-1: finish resume
[   18.280124] Bluetooth: hci0: command 0x0c24 tx timeout
[   18.283870] Bluetooth: hci0: Opcode 0x0c24 failed: -110
[   20.373559] Bluetooth: hci0: Opcode 0x0c24 failed: -110
[   21.488880] usb 2-1: retry with reset-resume
[   21.612566] usb 2-1: reset full-speed USB device number 2 using vhci_hcd
[   21.759963] usb 2-1: device descriptor read/64, error -71
[   22.015684] usb 2-1: device descriptor read/64, error -71
[   22.243500] usb 2-1: reset full-speed USB device number 2 using vhci_hcd
[   22.391495] usb 2-1: device descriptor read/64, error -71
[   22.447647] Bluetooth: hci0: Opcode 0x0c24 failed: -110
[   22.659118] usb 2-1: device descriptor read/64, error -71
[   22.930850] usb 2-1: reset full-speed USB device number 2 using vhci_hcd
[   22.930950] usb 2-1: SetAddress Request (2) to port 0
[   22.971776] usb 2-1: device descriptor read/8, error -71
[   23.112688] usb 2-1: device descriptor read/8, error -71
[   23.366501] usb 2-1: reset full-speed USB device number 2 using vhci_hcd
[   23.366636] usb 2-1: SetAddress Request (2) to port 0
[   23.400683] usb 2-1: device descriptor read/8, error -71
[   23.554054] usb 2-1: device descriptor read/8, error -71
[   23.662345] usb usb2-port1: logical disconnect
[   23.662661] usb 2-1: gone after usb resume? status -19
[   23.662672] usb 2-1: can't resume, status -19
[   23.662678] usb usb2-port1: logical disconnect
[   23.662996] usb 2-1: USB disconnect, device number 2
[   23.663005] usb 2-1: unregistering device
[   23.665259] Bluetooth: hci0: Failed usb_autopm_get_interface: -16
[   23.858151] usb 2-1: new full-speed USB device number 3 using vhci_hcd
[   24.021781] usb 2-1: device descriptor read/64, error -71
[   24.329820] usb 2-1: device descriptor read/64, error -71
[   24.653457] usb 2-1: new full-speed USB device number 4 using vhci_hcd
[   25.356528] usb 2-1: device descriptor read/64, error -71
usb 2-1: enqueue for inactive port 0
usb 2-1: enqueue for inactive port 0
```
#### `results/bt17-emulation-2026-11-13/logs/runs/final-m-dead-1.log`
Lines matching `RESULT|SCENARIO|step|usb 2-1|usb 1-1|btusb|Bluetooth|hci0: |tx timeout|reset|resume|suspend|disconnect|Resetting|PM: |BUG|WARNING|platform_pm|raw-gadget|not running|status 0x`, without `cmd_cnt|dyndbg:|Calibrating`, colour codes removed. 
```
Bluetooth: hci0: HCI Enhanced Setup Synchronous Connection command is advertised, but not supported.
   0.425 [mono   3.175943] MGMT Command Complete opcode 0x0005 status 0x00 index 0
   0.451 [mono   3.202635] usb device /sys/bus/usb/devices/2-1 power {'control': 'auto', 'runtime_status': 'active', 'autosuspend_delay_ms': '2000', 'persist': '1', 'wakeup': 'disabled'}
   2.429 [mono   5.180645] EMU suspend #1 (SET_FEATURE remote wakeup)
   2.481 [mono   5.232246] runtime_status suspended after waiting (ok=True)
   3.548 [mono   6.299191] EMU resume #1: GET_STATUS held, device wedged
Bluetooth: hci0: Opcode 0x0c24 failed: -110
   5.515 [mono   8.266012] MGMT Command Complete opcode 0x000e status 0x05 index 0
Bluetooth: hci0: command 0x0c24 tx timeout
Bluetooth: hci0: Device not resumed; not resetting
Bluetooth: hci0: Opcode 0x0c24 failed: -110
   7.531 [mono  10.282067] MGMT Command Complete opcode 0x000e status 0x05 index 0
Bluetooth: hci0: command 0x0c24 tx timeout
Bluetooth: hci0: Device not resumed; not resetting
   8.780 [mono  11.531138] EMU host gave up on held GET_STATUS of resume #1 (unlink)
usb 2-1: device descriptor read/64, error -71
usb 2-1: device descriptor read/64, error -71
Bluetooth: hci0: Opcode 0x0c24 failed: -110
   9.547 [mono  12.297980] MGMT Command Complete opcode 0x000e status 0x05 index 0
Bluetooth: hci0: command 0x0c24 tx timeout
Bluetooth: hci0: Device not resumed; not resetting
usb 2-1: device descriptor read/64, error -71
usb 2-1: device descriptor read/64, error -71
usb 2-1: device descriptor read/8, error -71
usb 2-1: device descriptor read/8, error -71
usb 2-1: device descriptor read/8, error -71
usb 2-1: device descriptor read/8, error -71
Bluetooth: hci0: Failed to resume device for deferred data: -16
Bluetooth: hci0: Failed to resume device for deferred data: -16
  10.754 [mono  13.504962] EMU suspends 1 resumes 1 state dead held []
  10.754 [mono  13.505078] RESULT bt17 fail_at=1 recover=False class-write-status=0x05 hci0_removed=True
[    0.181856] smpboot: CPU0: AMD QEMU Virtual CPU version 2.5+ (family: 0xf, model: 0x6b, stepping: 0x1)
[    0.200347] thermal_sys: Registered thermal governor 'step_wise'
[    0.254657] ACPI: PM: (supports S0 S3 S5)
[    0.357373] Bluetooth: Core ver 2.22
[    0.357414] Bluetooth: HCI device and connection manager initialized
[    0.357433] Bluetooth: HCI socket layer initialized
[    0.357444] Bluetooth: L2CAP socket layer initialized
[    0.357469] Bluetooth: SCO socket layer initialized
[    0.646510] Bluetooth: HCI UART driver ver 2.3
[    0.646518] Bluetooth: HCI UART protocol H4 registered
[    0.646521] Bluetooth: HCI UART protocol BCSP registered
[    0.646576] Bluetooth: HCI UART protocol LL registered
[    0.646579] Bluetooth: HCI UART protocol ATH3K registered
[    0.646651] Bluetooth: HCI UART protocol Three-wire (H5) registered
[    0.646701] Bluetooth: HCI UART protocol QCA registered
[    0.646704] Bluetooth: HCI UART protocol AG6XX registered
[    0.646763] Bluetooth: HCI UART protocol Marvell registered
[    0.646813] Bluetooth: HCI UART protocol AML registered
[    0.647123] usbcore: registered new interface driver btusb
[    0.650686] Bluetooth: RFCOMM socket layer initialized
[    0.650731] Bluetooth: RFCOMM ver 1.11
[    0.650755] Bluetooth: BNEP (Ethernet Emulation) ver 1.3
[    0.650791] Bluetooth: BNEP socket layer initialized
[    0.650796] Bluetooth: HIDP (Human Interface Emulation) ver 1.2
[    0.650803] Bluetooth: HIDP socket layer initialized
[    2.762096] usb usb2: usb wakeup-resume
[    2.762139] hub 2-0:1.0: hub_resume
[    2.986714] usb 2-1: new full-speed USB device number 2 using vhci_hcd
[    3.106910] usb 2-1: SetAddress Request (2) to port 0
[    3.123523] usb 2-1: New USB device found: idVendor=13d3, idProduct=3503, bcdDevice=0.01
[    3.124419] usb 2-1: udev 2, busnum 2, minor = 129
[    3.124429] usb 2-1: New USB device strings: Mfr=0, Product=0, SerialNumber=0
[    3.125415] usb 2-1: usb_probe_device
[    3.126436] btusb 2-1:1.0: usb_probe_interface
[    3.126445] btusb 2-1:1.0: usb_probe_interface - got id
[    3.129906] Bluetooth: hci0: HCI Enhanced Setup Synchronous Connection command is advertised, but not supported.
[    3.178005] Bluetooth: MGMT ver 1.23
[    5.184522] usb 2-1: usb auto-suspend, wakeup 1
[    5.202362] hub 2-0:1.0: hub_suspend
[    6.240219] hub 2-0:1.0: hub_resume
[    6.241061] usb 2-1: usb auto-resume
[    6.302156] usb 2-1: Waited 0ms for CONNECT
[    6.302171] usb 2-1: finish resume
[    8.269005] Bluetooth: hci0: Opcode 0x0c24 failed: -110
[    8.270237] Bluetooth: hci0: command 0x0c24 tx timeout
[    8.270395] Bluetooth: hci0: Device not resumed; not resetting
[   10.284992] Bluetooth: hci0: Opcode 0x0c24 failed: -110
[   10.286188] Bluetooth: hci0: command 0x0c24 tx timeout
[   10.289035] Bluetooth: hci0: Device not resumed; not resetting
[   11.535315] usb 2-1: retry with reset-resume
[   11.662513] usb 2-1: reset full-speed USB device number 2 using vhci_hcd
[   11.790190] usb 2-1: device descriptor read/64, error -71
[   12.026142] usb 2-1: device descriptor read/64, error -71
[   12.254171] usb 2-1: reset full-speed USB device number 2 using vhci_hcd
[   12.300980] Bluetooth: hci0: Opcode 0x0c24 failed: -110
[   12.302129] Bluetooth: hci0: command 0x0c24 tx timeout
[   12.302244] Bluetooth: hci0: Device not resumed; not resetting
[   12.378136] usb 2-1: device descriptor read/64, error -71
[   12.610462] usb 2-1: device descriptor read/64, error -71
[   12.846174] usb 2-1: reset full-speed USB device number 2 using vhci_hcd
[   12.846227] usb 2-1: SetAddress Request (2) to port 0
[   12.863892] usb 2-1: device descriptor read/8, error -71
[   12.987949] usb 2-1: device descriptor read/8, error -71
[   13.218140] usb 2-1: reset full-speed USB device number 2 using vhci_hcd
[   13.218194] usb 2-1: SetAddress Request (2) to port 0
[   13.235909] usb 2-1: device descriptor read/8, error -71
[   13.359578] usb 2-1: device descriptor read/8, error -71
[   13.466279] usb usb2-port1: logical disconnect
[   13.466380] usb 2-1: gone after usb resume? status -19
[   13.466387] usb 2-1: can't resume, status -19
[   13.466392] usb usb2-port1: logical disconnect
[   13.466586] Bluetooth: hci0: Failed to resume device for deferred data: -16
[   13.467026] Bluetooth: hci0: Failed to resume device for deferred data: -16
[   13.467386] usb 2-1: USB disconnect, device number 2
[   13.467393] usb 2-1: unregistering device
[   13.618113] usb 2-1: new full-speed USB device number 3 using vhci_hcd
```
#### `results/bt17-emulation-2026-11-13/logs/runs/base-m-recover-1.log`
Lines matching `RESULT|SCENARIO|step|usb 2-1|usb 1-1|btusb|Bluetooth|hci0: |tx timeout|reset|resume|suspend|disconnect|Resetting|PM: |BUG|WARNING|platform_pm|raw-gadget|not running|status 0x`, without `cmd_cnt|dyndbg:|Calibrating`, colour codes removed. 
```
Bluetooth: hci0: HCI Enhanced Setup Synchronous Connection command is advertised, but not supported.
   0.439 [mono   3.169306] MGMT Command Complete opcode 0x0005 status 0x00 index 0
   0.467 [mono   3.196502] usb device /sys/bus/usb/devices/2-1 power {'control': 'auto', 'runtime_status': 'active', 'autosuspend_delay_ms': '2000', 'persist': '1', 'wakeup': 'disabled'}
   2.443 [mono   5.172986] EMU suspend #1 (SET_FEATURE remote wakeup)
   2.497 [mono   5.226857] runtime_status suspended after waiting (ok=True)
   3.563 [mono   6.293467] EMU resume #1: GET_STATUS held, device wedged
Bluetooth: hci0: Opcode 0x0c24 failed: -110
Bluetooth: hci0: command 0x0c24 tx timeout
   5.531 [mono   8.260876] MGMT Command Complete opcode 0x000e status 0x05 index 0
Bluetooth: hci0: Opcode 0x0c24 failed: -110
   7.548 [mono  10.277605] MGMT Command Complete opcode 0x000e status 0x05 index 0
   8.795 [mono  11.525129] EMU host gave up on held GET_STATUS of resume #1 (unlink)
Bluetooth: hci0: Resetting usb device.
Bluetooth: hci0: Opcode 0x0c24 failed: -19
   9.054 [mono  11.783877] MGMT Command Complete opcode 0x000e status 0x03 index 0
Bluetooth: hci0: HCI Enhanced Setup Synchronous Connection command is advertised, but not supported.
   9.381 [mono  12.111010] EMU suspends 1 resumes 1 state healthy held []
   9.381 [mono  12.111181] RESULT bt17 fail_at=1 recover=True class-write-status=0x05 hci0_removed=True
[    0.167747] smpboot: CPU0: AMD QEMU Virtual CPU version 2.5+ (family: 0xf, model: 0x6b, stepping: 0x1)
[    0.187455] thermal_sys: Registered thermal governor 'step_wise'
[    0.247162] ACPI: PM: (supports S0 S3 S5)
[    0.340862] Bluetooth: Core ver 2.22
[    0.340862] Bluetooth: HCI device and connection manager initialized
[    0.340862] Bluetooth: HCI socket layer initialized
[    0.340862] Bluetooth: L2CAP socket layer initialized
[    0.340862] Bluetooth: SCO socket layer initialized
[    0.627188] Bluetooth: HCI UART driver ver 2.3
[    0.627193] Bluetooth: HCI UART protocol H4 registered
[    0.627195] Bluetooth: HCI UART protocol BCSP registered
[    0.627241] Bluetooth: HCI UART protocol LL registered
[    0.627243] Bluetooth: HCI UART protocol ATH3K registered
[    0.627281] Bluetooth: HCI UART protocol Three-wire (H5) registered
[    0.627323] Bluetooth: HCI UART protocol QCA registered
[    0.627326] Bluetooth: HCI UART protocol AG6XX registered
[    0.627363] Bluetooth: HCI UART protocol Marvell registered
[    0.627407] Bluetooth: HCI UART protocol AML registered
[    0.627650] usbcore: registered new interface driver btusb
[    0.631261] Bluetooth: RFCOMM socket layer initialized
[    0.631282] Bluetooth: RFCOMM ver 1.11
[    0.631293] Bluetooth: BNEP (Ethernet Emulation) ver 1.3
[    0.631334] Bluetooth: BNEP socket layer initialized
[    0.631336] Bluetooth: HIDP (Human Interface Emulation) ver 1.2
[    0.631342] Bluetooth: HIDP socket layer initialized
[    2.746512] usb usb2: usb wakeup-resume
[    2.746710] hub 2-0:1.0: hub_resume
[    2.982737] usb 2-1: new full-speed USB device number 2 using vhci_hcd
[    3.110747] usb 2-1: SetAddress Request (2) to port 0
[    3.127320] usb 2-1: New USB device found: idVendor=13d3, idProduct=3503, bcdDevice=0.01
[    3.128219] usb 2-1: udev 2, busnum 2, minor = 129
[    3.128228] usb 2-1: New USB device strings: Mfr=0, Product=0, SerialNumber=0
[    3.129106] usb 2-1: usb_probe_device
[    3.129984] btusb 2-1:1.0: usb_probe_interface
[    3.129993] btusb 2-1:1.0: usb_probe_interface - got id
[    3.133094] Bluetooth: hci0: HCI Enhanced Setup Synchronous Connection command is advertised, but not supported.
[    3.166764] Bluetooth: MGMT ver 1.23
[    5.172792] usb 2-1: usb auto-suspend, wakeup 1
[    5.191117] hub 2-0:1.0: hub_suspend
[    6.230638] hub 2-0:1.0: hub_resume
[    6.231284] usb 2-1: usb auto-resume
[    6.292224] usb 2-1: Waited 0ms for CONNECT
[    6.292237] usb 2-1: finish resume
[    8.259199] Bluetooth: hci0: Opcode 0x0c24 failed: -110
[    8.260365] Bluetooth: hci0: command 0x0c24 tx timeout
[   10.276308] Bluetooth: hci0: Opcode 0x0c24 failed: -110
[   11.524963] usb 2-1: retry with reset-resume
[   11.645283] usb 2-1: reset full-speed USB device number 2 using vhci_hcd
[   11.764233] usb 2-1: SetAddress Request (2) to port 0
[   11.781533] btusb 2-1:1.0: no reset_resume for driver btusb?
[   11.781542] btusb 2-1:1.1: no reset_resume for driver btusb?
[   11.781578] Bluetooth: hci0: Resetting usb device.
[   11.781998] btusb 2-1:1.0: forced unbind
[   11.782733] Bluetooth: hci0: Opcode 0x0c24 failed: -19
[   11.932044] usb 2-1: reset full-speed USB device number 2 using vhci_hcd
[   12.051068] usb 2-1: SetAddress Request (2) to port 0
[   12.068371] btusb 2-1:1.0: usb_probe_interface
[   12.068388] btusb 2-1:1.0: usb_probe_interface - got id
[   12.070933] Bluetooth: hci0: HCI Enhanced Setup Synchronous Connection command is advertised, but not supported.
```
#### `results/bt17-emulation-2026-11-13/logs/runs/final-m-recover-1.log`
Lines matching `RESULT|SCENARIO|step|usb 2-1|usb 1-1|btusb|Bluetooth|hci0: |tx timeout|reset|resume|suspend|disconnect|Resetting|PM: |BUG|WARNING|platform_pm|raw-gadget|not running|status 0x`, without `cmd_cnt|dyndbg:|Calibrating`, colour codes removed. 
```
Bluetooth: hci0:   0.374 [mono   3.127263] hci0 present HCI Enhanced Setup Synchronous 
   0.428 [mono   3.181853] MGMT Command Complete opcode 0x0005 status 0x00 index 0
   0.454 [mono   3.207563] usb device /sys/bus/usb/devices/2-1 power {'control': 'auto', 'runtime_status': 'active', 'autosuspend_delay_ms': '2000', 'persist': '1', 'wakeup': 'disabled'}
   2.432 [mono   5.185114] EMU suspend #1 (SET_FEATURE remote wakeup)
   2.483 [mono   5.236470] runtime_status suspended after waiting (ok=True)
   3.549 [mono   6.302510] EMU resume #1: GET_STATUS held, device wedged
Bluetooth: hci0: command 0x0c24 tx timeout
Bluetooth: hci0: Device not resumed; not resetting
Bluetooth: hci0: Opcode 0x0c24 failed: -110
   5.505 [mono   8.258554] MGMT Command Complete opcode 0x000e status 0x05 index 0
Bluetooth: hci0: command 0x0c24 tx timeout
Bluetooth: hci0: Device not resumed; not resetting
Bluetooth: hci0: Opcode 0x0c24 failed: -110
   7.521 [mono  10.274615] MGMT Command Complete opcode 0x000e status 0x05 index 0
   8.768 [mono  11.521829] EMU host gave up on held GET_STATUS of resume #1 (unlink)
Bluetooth: hci0: urb ffff88800278f800 failed to resubmit (2)
Bluetooth: hci0: Opcode 0x0c24 failed: -19
   9.029 [mono  11.782332] MGMT Command Complete opcode 0x000e status 0x03 index 0
Bluetooth: hci0: HCI Enhanced Setup Synchronous Connection command is advertised, but not supported.
   9.355 [mono  12.108665] EMU suspends 1 resumes 1 state healthy held []
   9.355 [mono  12.108769] RESULT bt17 fail_at=1 recover=True class-write-status=0x05 hci0_removed=True
[    0.173235] smpboot: CPU0: AMD QEMU Virtual CPU version 2.5+ (family: 0xf, model: 0x6b, stepping: 0x1)
[    0.191151] thermal_sys: Registered thermal governor 'step_wise'
[    0.250645] ACPI: PM: (supports S0 S3 S5)
[    0.348519] Bluetooth: Core ver 2.22
[    0.348561] Bluetooth: HCI device and connection manager initialized
[    0.348578] Bluetooth: HCI socket layer initialized
[    0.348584] Bluetooth: L2CAP socket layer initialized
[    0.348607] Bluetooth: SCO socket layer initialized
[    0.635266] Bluetooth: HCI UART driver ver 2.3
[    0.635270] Bluetooth: HCI UART protocol H4 registered
[    0.635273] Bluetooth: HCI UART protocol BCSP registered
[    0.635328] Bluetooth: HCI UART protocol LL registered
[    0.635330] Bluetooth: HCI UART protocol ATH3K registered
[    0.635383] Bluetooth: HCI UART protocol Three-wire (H5) registered
[    0.635421] Bluetooth: HCI UART protocol QCA registered
[    0.635423] Bluetooth: HCI UART protocol AG6XX registered
[    0.635463] Bluetooth: HCI UART protocol Marvell registered
[    0.635501] Bluetooth: HCI UART protocol AML registered
[    0.635744] usbcore: registered new interface driver btusb
[    0.637842] Bluetooth: RFCOMM socket layer initialized
[    0.637859] Bluetooth: RFCOMM ver 1.11
[    0.637871] Bluetooth: BNEP (Ethernet Emulation) ver 1.3
[    0.637880] Bluetooth: BNEP socket layer initialized
[    0.637882] Bluetooth: HIDP (Human Interface Emulation) ver 1.2
[    0.637888] Bluetooth: HIDP socket layer initialized
[    2.761716] usb usb2: usb wakeup-resume
[    2.761756] hub 2-0:1.0: hub_resume
[    2.986994] usb 2-1: new full-speed USB device number 2 using vhci_hcd
[    3.106978] usb 2-1: SetAddress Request (2) to port 0
[    3.123296] usb 2-1: New USB device found: idVendor=13d3, idProduct=3503, bcdDevice=0.01
[    3.123723] usb 2-1: udev 2, busnum 2, minor = 129
[    3.123729] usb 2-1: New USB device strings: Mfr=0, Product=0, SerialNumber=0
[    3.124409] usb 2-1: usb_probe_device
[    3.125000] btusb 2-1:1.0: usb_probe_interface
[    3.125005] btusb 2-1:1.0: usb_probe_interface - got id
[    3.127088] Bluetooth: hci0: HCI Enhanced Setup Synchronous Connection command is advertised, but not supported.
[    3.180251] Bluetooth: MGMT ver 1.23
[    5.185594] usb 2-1: usb auto-suspend, wakeup 1
[    5.202112] hub 2-0:1.0: hub_suspend
[    6.242792] hub 2-0:1.0: hub_resume
[    6.244086] usb 2-1: usb auto-resume
[    6.301803] usb 2-1: Waited 0ms for CONNECT
[    6.301825] usb 2-1: finish resume
[    8.257597] Bluetooth: hci0: command 0x0c24 tx timeout
[    8.257959] Bluetooth: hci0: Device not resumed; not resetting
[    8.257981] Bluetooth: hci0: Opcode 0x0c24 failed: -110
[   10.273452] Bluetooth: hci0: command 0x0c24 tx timeout
[   10.273934] Bluetooth: hci0: Device not resumed; not resetting
[   10.273987] Bluetooth: hci0: Opcode 0x0c24 failed: -110
[   11.522349] usb 2-1: retry with reset-resume
[   11.641932] usb 2-1: reset full-speed USB device number 2 using vhci_hcd
[   11.761466] usb 2-1: SetAddress Request (2) to port 0
[   11.780121] btusb 2-1:1.0: forced unbind
[   11.781107] Bluetooth: hci0: urb ffff88800278f800 failed to resubmit (2)
[   11.781892] Bluetooth: hci0: Opcode 0x0c24 failed: -19
[   11.933861] usb 2-1: reset full-speed USB device number 2 using vhci_hcd
[   12.053453] usb 2-1: SetAddress Request (2) to port 0
[   12.071269] btusb 2-1:1.0: usb_probe_interface
[   12.071282] btusb 2-1:1.0: usb_probe_interface - got id
[   12.074772] Bluetooth: hci0: HCI Enhanced Setup Synchronous Connection command is advertised, but not supported.
```
#### `results/bt17-emulation-2026-11-13/logs/runs/base-m-close-1.log`
Lines matching `RESULT|SCENARIO|step|usb 2-1|usb 1-1|btusb|Bluetooth|hci0: |tx timeout|reset|resume|suspend|disconnect|Resetting|PM: |BUG|WARNING|platform_pm|raw-gadget|not running|status 0x`, without `cmd_cnt|dyndbg:|Calibrating`, colour codes removed. 
```
Bluetooth: hci0: HCI Enhanced Setup Synchronous Connection command is advertised, but not supported.
   0.427 [mono   3.180928] MGMT Command Complete opcode 0x0005 status 0x00 index 0
   0.460 [mono   3.213236] usb device /sys/bus/usb/devices/2-1 power {'control': 'auto', 'runtime_status': 'active', 'autosuspend_delay_ms': '2000', 'persist': '1', 'wakeup': 'disabled'}
   2.438 [mono   5.191854] EMU suspend #1 (SET_FEATURE remote wakeup)
   2.490 [mono   5.243436] runtime_status suspended after waiting (ok=True)
   3.564 [mono   6.318075] EMU resume #1: GET_STATUS held, device wedged
   8.772 [mono  11.525985] EMU host gave up on held GET_STATUS of resume #1 (unlink)
  11.031 [mono  13.784365] EMU suspend #2 (SET_FEATURE remote wakeup)
Bluetooth: hci0: Opcode 0x0c03 failed: -110
Bluetooth: hci0: HCI reset during shutdown failed
  13.643 [mono  16.396211] MGMT Command Complete opcode 0x0005 status 0x00 index 0
  13.703 [mono  16.456791] EMU resume #2: GET_STATUS answered
  14.663 [mono  17.416899] power after recovery: {'control': 'auto', 'runtime_status': 'active', 'autosuspend_delay_ms': '2000', 'persist': '1', 'wakeup': 'disabled'}
Bluetooth: hci0: Opcode 0x0c03 failed: -110
  16.676 [mono  19.429756] MGMT Command Status opcode 0x0005 status 0x05 index 0
  16.682 [mono  19.435437] EMU suspends 2 resumes 2 state healthy
  16.682 [mono  19.435717] RESULT close-recover bluetooth_works_after=False
[    0.167369] smpboot: CPU0: AMD QEMU Virtual CPU version 2.5+ (family: 0xf, model: 0x6b, stepping: 0x1)
[    0.192947] thermal_sys: Registered thermal governor 'step_wise'
[    0.252011] ACPI: PM: (supports S0 S3 S5)
[    0.345257] Bluetooth: Core ver 2.22
[    0.345297] Bluetooth: HCI device and connection manager initialized
[    0.345312] Bluetooth: HCI socket layer initialized
[    0.345319] Bluetooth: L2CAP socket layer initialized
[    0.345343] Bluetooth: SCO socket layer initialized
[    0.627089] Bluetooth: HCI UART driver ver 2.3
[    0.627095] Bluetooth: HCI UART protocol H4 registered
[    0.627097] Bluetooth: HCI UART protocol BCSP registered
[    0.627150] Bluetooth: HCI UART protocol LL registered
[    0.627152] Bluetooth: HCI UART protocol ATH3K registered
[    0.627191] Bluetooth: HCI UART protocol Three-wire (H5) registered
[    0.627232] Bluetooth: HCI UART protocol QCA registered
[    0.627234] Bluetooth: HCI UART protocol AG6XX registered
[    0.627272] Bluetooth: HCI UART protocol Marvell registered
[    0.627311] Bluetooth: HCI UART protocol AML registered
[    0.627580] usbcore: registered new interface driver btusb
[    0.632185] Bluetooth: RFCOMM socket layer initialized
[    0.632238] Bluetooth: RFCOMM ver 1.11
[    0.632290] Bluetooth: BNEP (Ethernet Emulation) ver 1.3
[    0.632304] Bluetooth: BNEP socket layer initialized
[    0.632307] Bluetooth: HIDP (Human Interface Emulation) ver 1.2
[    0.632315] Bluetooth: HIDP socket layer initialized
[    2.760710] usb usb2: usb wakeup-resume
[    2.760758] hub 2-0:1.0: hub_resume
[    2.994007] usb 2-1: new full-speed USB device number 2 using vhci_hcd
[    3.122037] usb 2-1: SetAddress Request (2) to port 0
[    3.138645] usb 2-1: New USB device found: idVendor=13d3, idProduct=3503, bcdDevice=0.01
[    3.139566] usb 2-1: udev 2, busnum 2, minor = 129
[    3.139575] usb 2-1: New USB device strings: Mfr=0, Product=0, SerialNumber=0
[    3.140427] usb 2-1: usb_probe_device
[    3.141290] btusb 2-1:1.0: usb_probe_interface
[    3.141299] btusb 2-1:1.0: usb_probe_interface - got id
[    3.144683] Bluetooth: hci0: HCI Enhanced Setup Synchronous Connection command is advertised, but not supported.
[    3.178785] Bluetooth: MGMT ver 1.23
[    5.191615] usb 2-1: usb auto-suspend, wakeup 1
[    5.208943] hub 2-0:1.0: hub_suspend
[    6.255252] hub 2-0:1.0: hub_resume
[    6.256233] usb 2-1: usb auto-resume
[    6.316562] usb 2-1: Waited 0ms for CONNECT
[    6.316575] usb 2-1: finish resume
[   11.525929] usb 2-1: retry with reset-resume
[   11.645386] usb 2-1: reset full-speed USB device number 2 using vhci_hcd
[   11.764790] usb 2-1: SetAddress Request (2) to port 0
[   11.782534] btusb 2-1:1.0: no reset_resume for driver btusb?
[   11.782545] btusb 2-1:1.1: no reset_resume for driver btusb?
[   13.784208] usb 2-1: usb auto-suspend, wakeup 1
[   13.799042] hub 2-0:1.0: hub_suspend
[   16.387289] Bluetooth: hci0: Opcode 0x0c03 failed: -110
[   16.387781] Bluetooth: hci0: HCI reset during shutdown failed
[   16.395699] hub 2-0:1.0: hub_resume
[   16.396845] usb 2-1: usb auto-resume
[   16.455302] usb 2-1: Waited 0ms for CONNECT
[   16.455315] usb 2-1: finish resume
[   19.427408] Bluetooth: hci0: Opcode 0x0c03 failed: -110
```
#### `results/bt17-emulation-2026-11-13/logs/runs/final-m-close-1.log`
Lines matching `RESULT|SCENARIO|step|usb 2-1|usb 1-1|btusb|Bluetooth|hci0: |tx timeout|reset|resume|suspend|disconnect|Resetting|PM: |BUG|WARNING|platform_pm|raw-gadget|not running|status 0x`, without `cmd_cnt|dyndbg:|Calibrating`, colour codes removed. 
```
Bluetooth: hci0: HCI Enhanced Setup Synchronous Connection command is advertised, but not supported.
   0.428 [mono   3.207957] MGMT Command Complete opcode 0x0005 status 0x00 index 0
   0.451 [mono   3.231637] usb device /sys/bus/usb/devices/2-1 power {'control': 'auto', 'runtime_status': 'active', 'autosuspend_delay_ms': '2000', 'persist': '1', 'wakeup': 'disabled'}
   2.430 [mono   5.210519] EMU suspend #1 (SET_FEATURE remote wakeup)
   2.481 [mono   5.261245] runtime_status suspended after waiting (ok=True)
   3.551 [mono   6.330950] EMU resume #1: GET_STATUS held, device wedged
   8.754 [mono  11.533792] EMU host gave up on held GET_STATUS of resume #1 (unlink)
Bluetooth: hci0: urb ffff8880013bdd00 failed to resubmit (2)
Bluetooth: hci0: Opcode 0x0c03 failed: -19
Bluetooth: hci0: HCI reset during shutdown failed
   9.043 [mono  11.823583] MGMT Command Complete opcode 0x0005 status 0x00 index 0
Bluetooth: hci0: HCI Enhanced Setup Synchronous Connection command is advertised, but not supported.
  10.066 [mono  12.845938] power after recovery: {'control': 'auto', 'runtime_status': 'active', 'autosuspend_delay_ms': '2000', 'persist': '1', 'wakeup': 'disabled'}
  10.068 [mono  12.848204] MGMT Command Complete opcode 0x0005 status 0x00 index 0
  10.091 [mono  12.871329] MGMT Command Complete opcode 0x000e status 0x00 index 0
  10.113 [mono  12.893041] EMU suspends 1 resumes 1 state healthy
  10.113 [mono  12.893444] RESULT close-recover bluetooth_works_after=True
[    0.181834] smpboot: CPU0: AMD QEMU Virtual CPU version 2.5+ (family: 0xf, model: 0x6b, stepping: 0x1)
[    0.198914] thermal_sys: Registered thermal governor 'step_wise'
[    0.250339] ACPI: PM: (supports S0 S3 S5)
[    0.350471] Bluetooth: Core ver 2.22
[    0.350515] Bluetooth: HCI device and connection manager initialized
[    0.350531] Bluetooth: HCI socket layer initialized
[    0.350538] Bluetooth: L2CAP socket layer initialized
[    0.350562] Bluetooth: SCO socket layer initialized
[    0.649257] Bluetooth: HCI UART driver ver 2.3
[    0.649263] Bluetooth: HCI UART protocol H4 registered
[    0.649266] Bluetooth: HCI UART protocol BCSP registered
[    0.649310] Bluetooth: HCI UART protocol LL registered
[    0.649312] Bluetooth: HCI UART protocol ATH3K registered
[    0.649359] Bluetooth: HCI UART protocol Three-wire (H5) registered
[    0.649407] Bluetooth: HCI UART protocol QCA registered
[    0.649409] Bluetooth: HCI UART protocol AG6XX registered
[    0.649447] Bluetooth: HCI UART protocol Marvell registered
[    0.649484] Bluetooth: HCI UART protocol AML registered
[    0.649723] usbcore: registered new interface driver btusb
[    0.651839] Bluetooth: RFCOMM socket layer initialized
[    0.651857] Bluetooth: RFCOMM ver 1.11
[    0.651869] Bluetooth: BNEP (Ethernet Emulation) ver 1.3
[    0.651916] Bluetooth: BNEP socket layer initialized
[    0.651918] Bluetooth: HIDP (Human Interface Emulation) ver 1.2
[    0.651924] Bluetooth: HIDP socket layer initialized
[    2.790074] usb usb2: usb wakeup-resume
[    2.790123] hub 2-0:1.0: hub_resume
[    3.018710] usb 2-1: new full-speed USB device number 2 using vhci_hcd
[    3.142826] usb 2-1: SetAddress Request (2) to port 0
[    3.158986] usb 2-1: New USB device found: idVendor=13d3, idProduct=3503, bcdDevice=0.01
[    3.159442] usb 2-1: udev 2, busnum 2, minor = 129
[    3.159449] usb 2-1: New USB device strings: Mfr=0, Product=0, SerialNumber=0
[    3.160207] usb 2-1: usb_probe_device
[    3.160825] btusb 2-1:1.0: usb_probe_interface
[    3.160830] btusb 2-1:1.0: usb_probe_interface - got id
[    3.163191] Bluetooth: hci0: HCI Enhanced Setup Synchronous Connection command is advertised, but not supported.
[    3.207801] Bluetooth: MGMT ver 1.23
[    5.213292] usb 2-1: usb auto-suspend, wakeup 1
[    5.229814] hub 2-0:1.0: hub_suspend
[    6.275128] hub 2-0:1.0: hub_resume
[    6.276086] usb 2-1: usb auto-resume
[    6.332461] usb 2-1: Waited 0ms for CONNECT
[    6.332483] usb 2-1: finish resume
[   11.536884] usb 2-1: retry with reset-resume
[   11.664186] usb 2-1: reset full-speed USB device number 2 using vhci_hcd
[   11.792123] usb 2-1: SetAddress Request (2) to port 0
[   11.810853] btusb 2-1:1.0: forced unbind
[   11.811639] Bluetooth: hci0: urb ffff8880013bdd00 failed to resubmit (2)
[   11.812379] Bluetooth: hci0: Opcode 0x0c03 failed: -19
[   11.812675] Bluetooth: hci0: HCI reset during shutdown failed
[   11.960078] usb 2-1: reset full-speed USB device number 2 using vhci_hcd
[   12.087709] usb 2-1: SetAddress Request (2) to port 0
[   12.105771] btusb 2-1:1.0: usb_probe_interface
[   12.105780] btusb 2-1:1.0: usb_probe_interface - got id
[   12.108247] Bluetooth: hci0: HCI Enhanced Setup Synchronous Connection command is advertised, but not supported.
[   12.849050] Bluetooth: MGMT ver 1.23
```
#### `results/bt17-emulation-2026-11-13/logs/runs/bt23-race-bt23-1.log`
Lines matching `RESULT|SCENARIO|step|usb 2-1|usb 1-1|btusb|Bluetooth|hci0: |tx timeout|reset|resume|suspend|disconnect|Resetting|PM: |BUG|WARNING|platform_pm|raw-gadget|not running|status 0x`, without `cmd_cnt|dyndbg:|Calibrating`, colour codes removed. 
```
Bluetooth: hci0: HCI Enhanced Setup Synchronous Connection command is advertised, but not supported.
   0.428 [mono   3.168580] MGMT Command Complete opcode 0x0005 status 0x00 index 0
   0.453 [mono   3.193939] usb device /sys/bus/usb/devices/2-1 power {'control': 'auto', 'runtime_status': 'active', 'autosuspend_delay_ms': '2000', 'persist': '1', 'wakeup': 'disabled'}
   2.431 [mono   5.171729] EMU suspend #1 (SET_FEATURE remote wakeup)
   2.482 [mono   5.223227] runtime_status suspended after waiting (ok=True)
   3.150 [mono   5.890929] EMU resume #1: GET_STATUS answered
   3.151 [mono   5.891981] power/control=on written (resume forced) in 0.061 s; runtime_status active
Bluetooth: hci0: Opcode 0x0c24 failed: -110
   5.009 [mono   7.750307] MGMT Command Complete opcode 0x000e status 0x05 index 0
   5.019 [mono   7.759651] EMU suspends 1 resumes 1 state healthy
   5.019 [mono   7.760028] RESULT bt23 delay=400 status=0x05 latency=2.022
[    0.174578] smpboot: CPU0: AMD QEMU Virtual CPU version 2.5+ (family: 0xf, model: 0x6b, stepping: 0x1)
[    0.191719] thermal_sys: Registered thermal governor 'step_wise'
[    0.243916] ACPI: PM: (supports S0 S3 S5)
[    0.343619] Bluetooth: Core ver 2.22
[    0.343660] Bluetooth: HCI device and connection manager initialized
[    0.343677] Bluetooth: HCI socket layer initialized
[    0.343683] Bluetooth: L2CAP socket layer initialized
[    0.343707] Bluetooth: SCO socket layer initialized
[    0.628357] Bluetooth: HCI UART driver ver 2.3
[    0.628363] Bluetooth: HCI UART protocol H4 registered
[    0.628366] Bluetooth: HCI UART protocol BCSP registered
[    0.628411] Bluetooth: HCI UART protocol LL registered
[    0.628413] Bluetooth: HCI UART protocol ATH3K registered
[    0.628460] Bluetooth: HCI UART protocol Three-wire (H5) registered
[    0.628498] Bluetooth: HCI UART protocol QCA registered
[    0.628501] Bluetooth: HCI UART protocol AG6XX registered
[    0.628539] Bluetooth: HCI UART protocol Marvell registered
[    0.628577] Bluetooth: HCI UART protocol AML registered
[    0.628816] usbcore: registered new interface driver btusb
[    0.630882] Bluetooth: RFCOMM socket layer initialized
[    0.630910] Bluetooth: RFCOMM ver 1.11
[    0.630924] Bluetooth: BNEP (Ethernet Emulation) ver 1.3
[    0.630942] Bluetooth: BNEP socket layer initialized
[    0.630946] Bluetooth: HIDP (Human Interface Emulation) ver 1.2
[    0.630959] Bluetooth: HIDP socket layer initialized
[    2.748925] usb usb2: usb wakeup-resume
[    2.748968] hub 2-0:1.0: hub_resume
[    2.969793] usb 2-1: new full-speed USB device number 2 using vhci_hcd
[    3.089815] usb 2-1: SetAddress Request (2) to port 0
[    3.106254] usb 2-1: New USB device found: idVendor=13d3, idProduct=3503, bcdDevice=0.01
[    3.106760] usb 2-1: udev 2, busnum 2, minor = 129
[    3.106767] usb 2-1: New USB device strings: Mfr=0, Product=0, SerialNumber=0
[    3.107479] usb 2-1: usb_probe_device
[    3.108097] btusb 2-1:1.0: usb_probe_interface
[    3.108101] btusb 2-1:1.0: usb_probe_interface - got id
[    3.110226] Bluetooth: hci0: HCI Enhanced Setup Synchronous Connection command is advertised, but not supported.
[    3.166135] Bluetooth: MGMT ver 1.23
[    5.171398] usb 2-1: usb auto-suspend, wakeup 1
[    5.189078] hub 2-0:1.0: hub_suspend
[    5.830158] hub 2-0:1.0: hub_resume
[    5.831250] usb 2-1: usb auto-resume
[    5.889655] usb 2-1: Waited 0ms for CONNECT
[    5.889666] usb 2-1: finish resume
[    7.748902] Bluetooth: hci0: Opcode 0x0c24 failed: -110
```
#### `results/bt17-emulation-2026-11-13/logs/runs/bt23-fix-bt23-1.log`
Lines matching `RESULT|SCENARIO|step|usb 2-1|usb 1-1|btusb|Bluetooth|hci0: |tx timeout|reset|resume|suspend|disconnect|Resetting|PM: |BUG|WARNING|platform_pm|raw-gadget|not running|status 0x`, without `cmd_cnt|dyndbg:|Calibrating`, colour codes removed. 
```
Bluetooth: hci0: HCI Enhanced Setup Synchronous Connection command is advertised, but not supported.
   0.426 [mono   3.235546] MGMT Command Complete opcode 0x0005 status 0x00 index 0
   0.452 [mono   3.262060] usb device /sys/bus/usb/devices/2-1 power {'control': 'auto', 'runtime_status': 'active', 'autosuspend_delay_ms': '2000', 'persist': '1', 'wakeup': 'disabled'}
   2.428 [mono   5.238211] EMU suspend #1 (SET_FEATURE remote wakeup)
   2.480 [mono   5.289990] runtime_status suspended after waiting (ok=True)
   3.147 [mono   5.956510] EMU resume #1: GET_STATUS answered
   3.148 [mono   5.957549] power/control=on written (resume forced) in 0.060 s; runtime_status active
   3.387 [mono   6.196738] MGMT Command Complete opcode 0x000e status 0x00 index 0
   3.407 [mono   6.216896] EMU suspends 1 resumes 1 state healthy
   3.407 [mono   6.216997] RESULT bt23 delay=400 status=0x00 latency=0.402
[    0.167236] smpboot: CPU0: AMD QEMU Virtual CPU version 2.5+ (family: 0xf, model: 0x6b, stepping: 0x1)
[    0.195500] thermal_sys: Registered thermal governor 'step_wise'
[    0.249766] ACPI: PM: (supports S0 S3 S5)
[    0.351398] Bluetooth: Core ver 2.22
[    0.351449] Bluetooth: HCI device and connection manager initialized
[    0.351466] Bluetooth: HCI socket layer initialized
[    0.351472] Bluetooth: L2CAP socket layer initialized
[    0.351496] Bluetooth: SCO socket layer initialized
[    0.638683] Bluetooth: HCI UART driver ver 2.3
[    0.638688] Bluetooth: HCI UART protocol H4 registered
[    0.638690] Bluetooth: HCI UART protocol BCSP registered
[    0.638733] Bluetooth: HCI UART protocol LL registered
[    0.638735] Bluetooth: HCI UART protocol ATH3K registered
[    0.638781] Bluetooth: HCI UART protocol Three-wire (H5) registered
[    0.638819] Bluetooth: HCI UART protocol QCA registered
[    0.638822] Bluetooth: HCI UART protocol AG6XX registered
[    0.638859] Bluetooth: HCI UART protocol Marvell registered
[    0.638896] Bluetooth: HCI UART protocol AML registered
[    0.639127] usbcore: registered new interface driver btusb
[    0.641231] Bluetooth: RFCOMM socket layer initialized
[    0.641257] Bluetooth: RFCOMM ver 1.11
[    0.641271] Bluetooth: BNEP (Ethernet Emulation) ver 1.3
[    0.641281] Bluetooth: BNEP socket layer initialized
[    0.641283] Bluetooth: HIDP (Human Interface Emulation) ver 1.2
[    0.641292] Bluetooth: HIDP socket layer initialized
[    2.816643] usb usb2: usb wakeup-resume
[    2.816683] hub 2-0:1.0: hub_resume
[    3.040606] usb 2-1: new full-speed USB device number 2 using vhci_hcd
[    3.164618] usb 2-1: SetAddress Request (2) to port 0
[    3.181357] usb 2-1: New USB device found: idVendor=13d3, idProduct=3503, bcdDevice=0.01
[    3.181826] usb 2-1: udev 2, busnum 2, minor = 129
[    3.181833] usb 2-1: New USB device strings: Mfr=0, Product=0, SerialNumber=0
[    3.182777] usb 2-1: usb_probe_device
[    3.183609] btusb 2-1:1.0: usb_probe_interface
[    3.183619] btusb 2-1:1.0: usb_probe_interface - got id
[    3.186859] Bluetooth: hci0: HCI Enhanced Setup Synchronous Connection command is advertised, but not supported.
[    3.233350] Bluetooth: MGMT ver 1.23
[    5.237727] usb 2-1: usb auto-suspend, wakeup 1
[    5.251486] hub 2-0:1.0: hub_suspend
[    5.896855] hub 2-0:1.0: hub_resume
[    5.897515] usb 2-1: usb auto-resume
[    5.955363] usb 2-1: Waited 0ms for CONNECT
[    5.955373] usb 2-1: finish resume
```
#### `results/bt17-emulation-2026-11-13/logs/runs/final-ryzen-bt17-1.log`
Lines matching `RESULT|SCENARIO|step|usb 2-1|usb 1-1|btusb|Bluetooth|hci0: |tx timeout|reset|resume|suspend|disconnect|Resetting|PM: |BUG|WARNING|platform_pm|raw-gadget|not running|status 0x`, without `cmd_cnt|dyndbg:|Calibrating`, colour codes removed. 
```
Bluetooth: hci0: HCI Enhanced Setup Synchronous Connection command is advertised, but not supported.
   0.433 [mono   2.596572] MGMT Command Complete opcode 0x0005 status 0x00 index 0
   0.460 [mono   2.623481] usb device /sys/bus/usb/devices/2-1 power {'control': 'auto', 'runtime_status': 'active', 'autosuspend_delay_ms': '2000', 'persist': '1', 'wakeup': 'disabled'}
  15.491 [mono  17.654094] RESULT bt17 SKIP device never autosuspended
[    0.074405] smpboot: CPU0: AMD Ryzen 7 5825U with Radeon Graphics (family: 0x19, model: 0x50, stepping: 0x0)
[    0.099264] thermal_sys: Registered thermal governor 'step_wise'
[    0.200706] ACPI: PM: (supports S0 S3 S5)
[    0.371455] Bluetooth: Core ver 2.22
[    0.371526] Bluetooth: HCI device and connection manager initialized
[    0.371553] Bluetooth: HCI socket layer initialized
[    0.371565] Bluetooth: L2CAP socket layer initialized
[    0.371608] Bluetooth: SCO socket layer initialized
[    0.793311] Bluetooth: HCI UART driver ver 2.3
[    0.793320] Bluetooth: HCI UART protocol H4 registered
[    0.793326] Bluetooth: HCI UART protocol BCSP registered
[    0.793438] Bluetooth: HCI UART protocol LL registered
[    0.793443] Bluetooth: HCI UART protocol ATH3K registered
[    0.793581] Bluetooth: HCI UART protocol Three-wire (H5) registered
[    0.793663] Bluetooth: HCI UART protocol QCA registered
[    0.793667] Bluetooth: HCI UART protocol AG6XX registered
[    0.793779] Bluetooth: HCI UART protocol Marvell registered
[    0.793861] Bluetooth: HCI UART protocol AML registered
[    0.794720] usbcore: registered new interface driver btusb
[    0.799562] Bluetooth: RFCOMM socket layer initialized
[    0.799588] Bluetooth: RFCOMM ver 1.11
[    0.799611] Bluetooth: BNEP (Ethernet Emulation) ver 1.3
[    0.799683] Bluetooth: BNEP socket layer initialized
[    0.799687] Bluetooth: HIDP (Human Interface Emulation) ver 1.2
[    0.799699] Bluetooth: HIDP socket layer initialized
[    2.174562] usb usb2: usb wakeup-resume
[    2.174627] hub 2-0:1.0: hub_resume
[    2.396671] usb 2-1: new full-speed USB device number 2 using vhci_hcd
[    2.517621] usb 2-1: SetAddress Request (2) to port 0
[    2.533350] usb 2-1: New USB device found: idVendor=13d3, idProduct=3503, bcdDevice=0.01
[    2.534062] usb 2-1: udev 2, busnum 2, minor = 129
[    2.534070] usb 2-1: New USB device strings: Mfr=0, Product=0, SerialNumber=0
[    2.535143] usb 2-1: usb_probe_device
[    2.536037] btusb 2-1:1.0: usb_probe_interface
[    2.536044] btusb 2-1:1.0: usb_probe_interface - got id
[    2.539382] Bluetooth: hci0: HCI Enhanced Setup Synchronous Connection command is advertised, but not supported.
[    2.593422] Bluetooth: MGMT ver 1.23
```
#### `results/bt17-emulation-2026-11-13/logs/runs/base-pm-sysfreeze-plain-1.log`
Lines matching `RESULT|SCENARIO|step|usb 2-1|usb 1-1|btusb|Bluetooth|hci0: |tx timeout|reset|resume|suspend|disconnect|Resetting|PM: |BUG|WARNING|platform_pm|raw-gadget|not running|status 0x`, without `cmd_cnt|dyndbg:|Calibrating`, colour codes removed. 
```
Bluetooth: hci0: HCI Enhanced Setup Synchronous Connection command is advertised, but not supported.
   0.428 [mono   3.298483] MGMT Command Complete opcode 0x0005 status 0x00 index 0
   0.453 [mono   3.323637] usb device /sys/bus/usb/devices/2-1 power {'control': 'auto', 'runtime_status': 'active', 'autosuspend_delay_ms': '2000', 'persist': '1', 'wakeup': 'disabled'}
   0.955 [mono   3.825334] power before sleep: {'control': 'on', 'runtime_status': 'active', 'autosuspend_delay_ms': '2000', 'persist': '1', 'wakeup': 'disabled'}
usb usb2-port1: device 2-1 not suspended yet
vhci_hcd vhci_hcd.0: PM: dpm_run_callback(): platform_pm_suspend returns -16
vhci_hcd vhci_hcd.0: PM: failed to suspend: error -16
PM: Some devices failed to suspend, or early wake event detected
usb usb2-port1: device 2-1 not suspended yet
vhci_hcd vhci_hcd.0: PM: dpm_run_callback(): platform_pm_suspend returns -16
vhci_hcd vhci_hcd.0: PM: failed to suspend: error -16
PM: Some devices failed to suspend, or early wake event detected
   3.445 [mono   6.315280] MGMT Command Complete opcode 0x0005 status 0x00 index 0
   3.467 [mono   6.337814] Set Powered after resume: (6.315271151, 1, 5, 0, 0)
   3.470 [mono   6.340249] MGMT Command Complete opcode 0x000e status 0x00 index 0
   3.491 [mono   6.361880] class write after resume: 0.002 s (6.340245027, 1, 14, 0, 0)
   3.492 [mono   6.362391] EMU suspends 0 resumes 0 state healthy
   3.492 [mono   6.362637] RESULT sysfreeze fault=False recover=False hci0=True bluetooth_works_after=True
[    0.183617] smpboot: CPU0: AMD QEMU Virtual CPU version 2.5+ (family: 0xf, model: 0x6b, stepping: 0x1)
[    0.205360] thermal_sys: Registered thermal governor 'step_wise'
[    0.272648] ACPI: PM: (supports S0 S3 S5)
[    0.390888] Bluetooth: Core ver 2.22
[    0.390943] Bluetooth: HCI device and connection manager initialized
[    0.390965] Bluetooth: HCI socket layer initialized
[    0.390972] Bluetooth: L2CAP socket layer initialized
[    0.390999] Bluetooth: SCO socket layer initialized
[    0.725782] Bluetooth: HCI UART driver ver 2.3
[    0.725791] Bluetooth: HCI UART protocol H4 registered
[    0.725795] Bluetooth: HCI UART protocol BCSP registered
[    0.725863] Bluetooth: HCI UART protocol LL registered
[    0.725866] Bluetooth: HCI UART protocol ATH3K registered
[    0.725923] Bluetooth: HCI UART protocol Three-wire (H5) registered
[    0.725982] Bluetooth: HCI UART protocol QCA registered
[    0.725985] Bluetooth: HCI UART protocol AG6XX registered
[    0.726038] Bluetooth: HCI UART protocol Marvell registered
[    0.726093] Bluetooth: HCI UART protocol AML registered
[    0.726616] usbcore: registered new interface driver btusb
[    0.732116] Bluetooth: RFCOMM socket layer initialized
[    0.732152] Bluetooth: RFCOMM ver 1.11
[    0.732166] Bluetooth: BNEP (Ethernet Emulation) ver 1.3
[    0.732213] Bluetooth: BNEP socket layer initialized
[    0.732217] Bluetooth: HIDP (Human Interface Emulation) ver 1.2
[    0.732228] Bluetooth: HIDP socket layer initialized
[    2.877978] usb usb2: usb wakeup-resume
[    2.878019] hub 2-0:1.0: hub_resume
[    3.104272] usb 2-1: new full-speed USB device number 2 using vhci_hcd
[    3.228140] usb 2-1: SetAddress Request (2) to port 0
[    3.244497] usb 2-1: New USB device found: idVendor=13d3, idProduct=3503, bcdDevice=0.01
[    3.244950] usb 2-1: udev 2, busnum 2, minor = 129
[    3.244957] usb 2-1: New USB device strings: Mfr=0, Product=0, SerialNumber=0
[    3.245677] usb 2-1: usb_probe_device
[    3.246362] btusb 2-1:1.0: usb_probe_interface
[    3.246367] btusb 2-1:1.0: usb_probe_interface - got id
[    3.248775] Bluetooth: hci0: HCI Enhanced Setup Synchronous Connection command is advertised, but not supported.
[    3.296773] Bluetooth: MGMT ver 1.23
[    3.826111] PM: suspend entry (s2idle)
[    3.836154] printk: Suspending console(s) (use no_console_suspend to debug)
[    3.838975] hub 3-0:1.0: hub_resume
[    3.838978] usb usb2-port1: device 2-1 not suspended yet
[    3.838986] hub 2-0:1.0: hub_suspend
[    3.839189] hub 1-0:1.0: hub_resume
[    3.839412] hub 1-0:1.0: hub_suspend
[    3.863929] hub 3-0:1.0: hub_suspend
[    3.864404] vhci_hcd vhci_hcd.0: We have 1 active connection. Do not suspend.
[    3.864415] vhci_hcd vhci_hcd.0: PM: dpm_run_callback(): platform_pm_suspend returns -16
[    3.864465] vhci_hcd vhci_hcd.0: PM: failed to suspend: error -16
[    3.864827] PM: Some devices failed to suspend, or early wake event detected
[    3.866347] hub 1-0:1.0: hub_resume
[    3.866588] hub 3-0:1.0: hub_resume
[    3.880094] hub 2-0:1.0: hub_resume
[    3.893949] hub 1-0:1.0: hub_suspend
[    3.895023] PM: suspend exit
[    3.895644] PM: suspend entry (s2idle)
[    3.901564] printk: Suspending console(s) (use no_console_suspend to debug)
[    3.904021] hub 3-0:1.0: hub_suspend
[    3.904021] usb usb2-port1: device 2-1 not suspended yet
[    3.904033] hub 2-0:1.0: hub_suspend
[    3.904054] hub 1-0:1.0: hub_resume
[    3.904207] hub 1-0:1.0: hub_suspend
[    4.281069] vhci_hcd vhci_hcd.0: We have 1 active connection. Do not suspend.
[    4.281081] vhci_hcd vhci_hcd.0: PM: dpm_run_callback(): platform_pm_suspend returns -16
[    4.281095] vhci_hcd vhci_hcd.0: PM: failed to suspend: error -16
[    4.281452] PM: Some devices failed to suspend, or early wake event detected
[    4.283258] hub 1-0:1.0: hub_resume
[    4.283635] hub 3-0:1.0: hub_resume
[    4.295281] hub 2-0:1.0: hub_resume
[    4.311017] hub 1-0:1.0: hub_suspend
[    4.312022] PM: suspend exit
[    4.432691] hub 3-0:1.0: hub_suspend
```
#### `results/bt17-emulation-2026-11-13/logs/runs/base-pm-rg-plain-2.log`
Lines matching `RESULT|SCENARIO|step|usb 2-1|usb 1-1|btusb|Bluetooth|hci0: |tx timeout|reset|resume|suspend|disconnect|Resetting|PM: |BUG|WARNING|platform_pm|raw-gadget|not running|status 0x`, without `cmd_cnt|dyndbg:|Calibrating`, colour codes removed. 
```
Bluetooth: hci0: HCI Enhanced Setup Synchronous Connection command is advertised, but not supported.
   0.969 [mono   4.465959] MGMT reply opcode 0x0005 status 0x00 index 0
   0.981 [mono   4.477960] MGMT reply opcode 0x000e status 0x00 index 0
usb 1-1: device descriptor read/64, error -32
usb 1-1: device descriptor read/64, error -32
usb 1-1: device descriptor read/64, error -32
usb 1-1: device descriptor read/64, error -32
raw-gadget.0 gadget.0: failed to queue reset event
raw-gadget.0 gadget.0: failed to queue resume event
raw-gadget.0 gadget.0: ignoring, device is not running
raw-gadget.0 gadget.0: ignoring, device is not running
raw-gadget.0 gadget.0: ignoring, device is not running
usb 1-1: device descriptor read/8, error -32
raw-gadget.0 gadget.0: ignoring, device is not running
raw-gadget.0 gadget.0: ignoring, device is not running
raw-gadget.0 gadget.0: ignoring, device is not running
usb 1-1: device descriptor read/8, error -32
raw-gadget.0 gadget.0: failed to queue suspend event
raw-gadget.0 gadget.0: failed to queue reset event
raw-gadget.0 gadget.0: failed to queue resume event
raw-gadget.0 gadget.0: ignoring, device is not running
raw-gadget.0 gadget.0: ignoring, device is not running
raw-gadget.0 gadget.0: ignoring, device is not running
usb 1-1: device descriptor read/8, error -32
raw-gadget.0 gadget.0: ignoring, device is not running
raw-gadget.0 gadget.0: ignoring, device is not running
raw-gadget.0 gadget.0: ignoring, device is not running
usb 1-1: device descriptor read/8, error -32
raw-gadget.0 gadget.0: failed to queue suspend event
Bluetooth: hci0: Opcode 0x0c01 failed: -19
raw-gadget.0 gadget.0: failed to queue reset event
raw-gadget.0 gadget.0: failed to queue resume event
raw-gadget.0 gadget.0: ignoring, device is not running
raw-gadget.0 gadget.0: ignoring, device is not running
raw-gadget.0 gadget.0: ignoring, device is not running
raw-gadget.0 gadget.0: failed to queue reset event
raw-gadget.0 gadget.0: failed to queue resume event
usb 1-1: device descriptor read/64, error -32
raw-gadget.0 gadget.0: ignoring, device is not running
raw-gadget.0 gadget.0: ignoring, device is not running
raw-gadget.0 gadget.0: ignoring, device is not running
raw-gadget.0 gadget.0: failed to queue reset event
raw-gadget.0 gadget.0: failed to queue resume event
usb 1-1: device descriptor read/64, error -32
raw-gadget.0 gadget.0: failed to queue suspend event
raw-gadget.0 gadget.0: failed to queue reset event
raw-gadget.0 gadget.0: failed to queue resume event
raw-gadget.0 gadget.0: ignoring, device is not running
raw-gadget.0 gadget.0: ignoring, device is not running
raw-gadget.0 gadget.0: ignoring, device is not running
raw-gadget.0 gadget.0: failed to queue reset event
raw-gadget.0 gadget.0: failed to queue resume event
usb 1-1: device descriptor read/64, error -32
raw-gadget.0 gadget.0: ignoring, device is not running
raw-gadget.0 gadget.0: ignoring, device is not running
raw-gadget.0 gadget.0: ignoring, device is not running
raw-gadget.0 gadget.0: failed to queue reset event
raw-gadget.0 gadget.0: failed to queue resume event
usb 1-1: device descriptor read/64, error -32
raw-gadget.0 gadget.0: failed to queue suspend event
raw-gadget.0 gadget.0: failed to queue disconnect event
raw-gadget.0 gadget.0: failed to queue reset event
raw-gadget.0 gadget.0: failed to queue resume event
raw-gadget.0 gadget.0: failed to queue reset event
raw-gadget.0 gadget.0: failed to queue resume event
raw-gadget.0 gadget.0: ignoring, device is not running
raw-gadget.0 gadget.0: ignoring, device is not running
raw-gadget.0 gadget.0: ignoring, device is not running
usb 1-1: device descriptor read/8, error -32
raw-gadget.0 gadget.0: ignoring, device is not running
raw-gadget.0 gadget.0: ignoring, device is not running
raw-gadget.0 gadget.0: ignoring, device is not running
usb 1-1: device descriptor read/8, error -32
raw-gadget.0 gadget.0: failed to queue suspend event
raw-gadget.0 gadget.0: failed to queue reset event
raw-gadget.0 gadget.0: failed to queue resume event
raw-gadget.0 gadget.0: ignoring, device is not running
raw-gadget.0 gadget.0: ignoring, device is not running
raw-gadget.0 gadget.0: ignoring, device is not running
usb 1-1: device descriptor read/8, error -32
raw-gadget.0 gadget.0: ignoring, device is not running
raw-gadget.0 gadget.0: ignoring, device is not running
raw-gadget.0 gadget.0: ignoring, device is not running
usb 1-1: device descriptor read/8, error -32
raw-gadget.0 gadget.0: failed to queue suspend event
```

## 10. The dossiers: state, CI results and open items
*(verbatim: `contributions/CO-43-btusb-runtime-resume-failure/README.md`)*
### CO-43 — btusb: a device that fails, or needs a reset, to resume (BT-18, BT-19, BT-20; BT-17)

**Where it comes from:** BT-17 (2026-11-12 18:03). The laptop's idle QCA9377 (`13d3:3503`)
was runtime-suspended, and the next command started a resume that the device never answered.
The outside reviews (`reviews/2026-11-13T02*`–`T04*-bt17-*`) agree on how the kernel then
behaved. An emulation reproduces it step by step and found three btusb defects on the way
(`results/bt17-emulation-2026-11-13/`):

- **BT-20:** `btusb_waker()` swallows the failed resume.
- **BT-19:** `btusb_reset()`, called by the command timeout:
  - blocks the ordered HCI workqueue behind the failing resume (5.3 s on the laptop, 5.4 s in
    emulation);
  - when the reset-resume succeeds, resets the device a second time.
- **BT-18:** after a *successful* runtime reset-resume, btusb is never resumed: no
  `reset_resume` callback, and the USB core does not rebind after a runtime resume. Bluetooth
  stays dead with a healthy device.

None of the three made the controller stop answering. That cause (firmware, platform power,
or the AMD host) is not addressed by any patch here and needs a recurrence on the laptop with
USB core debug.

**State (2026-11-13): five patches written on bluetooth-next `da3cc0258` and tested in
emulation; nothing sent.** Patches in `patch/`, in this order, without Signed-off-by (the
operator adds his own). checkpatch `--strict --no-tree` reports only the missing Signed-off-by,
plus on patch 5 an unknown commit id (no tree) and two CamelCase notes for the USB core's own
`idVendor`/`idProduct`.

| # | subject | fixes | for upstream? |
|---|---|---|---|
| 1 (A) | Bluetooth: btusb: Report a failed resume for deferred data | BT-20 | yes, small |
| 2 (B) | Bluetooth: btusb: Don't reset a device that has not resumed | BT-19 | yes |
| 3 (D) | Bluetooth: btusb: Recover after a reset-resume | BT-18 | yes, after a system-suspend test |
| 4 (E) | Bluetooth: btusb: Anchor a deferred URB under txlock | BT-23 | yes, small |
| 5 (C) | Bluetooth: btusb: Disable runtime suspend of QCA9377 13d3:3503 on Ryzen | BT-17 H3 | **RFC only**: one occurrence |

**Measured** (QEMU, 4 CPUs, KASAN and lockdep; the emulated device fails at its first resume;
`results/bt17-emulation-2026-11-13/README.md`, "Results"): see that table. In short:
- **unpatched:**
  - dead device: the laptop's sequence;
  - recovering device: back only through `btusb_reset()`'s second reset (BT-19);
  - power-off-started resume: Bluetooth dead, 5 of 5;
- **A+B+D:**
  - dead device: no stall, no reset, the failed resume logged;
  - recovering device: back, 5 of 5;
  - power-off-started resume: back, 5 of 5;
  - healthy cycles unchanged;
- **C** on a guest that sees the laptop's Ryzen CPU: the device no longer suspends while
  hci0 is up, so the fault does not occur; on a non-Ryzen guest C changes nothing.
- **E**, with a debug-only delay that widens BT-23's window and a resume forced inside it:
  - unpatched: parked and timed out, 3 of 3;
  - with E: answered, 2 of 2.

**Ubuntu:** all five apply, in order, to Ubuntu `7.0.0-42`'s single `drivers/bluetooth/btusb.c`
with line offsets only (`tmp/bt17-review/ubuntu-port-check.sh`, a dry run on a copy). A test
module for the laptop's `-43` would need `-43`'s btusb source and the operator's word to install.

**The list's CI bot, run locally** (`scripts/bot-ci-local.sh`, patches 1–4, the RFC left out;
`tmp/bot-ci-local/co43-20261113/`):
- every build and static check passes: BuildKernel, BuildKernel32, CheckAllWarning,
  CheckSparse, CheckKernelLLVM, IncrementalBuild, SubjectPrefix, VerifyFixes, TestRunnerSetup;
- CheckPatch, VerifySignedoff and GitLint fail only for the missing Signed-off-by;
- the base side (`da3cc0258`) passes its six tree checks too;
- the bot's file mapping selects no tester for a btusb-only change. The emulation above is
  what exercises the code.

**Open before any send:**
1. **D changes the system-resume path** of every btusb device that is reset-resumed at a
   system resume. That is one USB reset more, before a rebinding they already got.
   - **Affected:** the devices of `btusb_needs_reset_resume_table`, and **all Realtek
     devices** with wakeup disabled (`btusb_suspend()` sets `reset_resume` for them,
     `BTUSB_WAKEUP_AUTOSUSPEND`). The second group is the wider one.
   - **Narrower variant to weigh:** queue the reset only for a runtime resume. This harness cannot test it: `vhci_hcd`
   refuses system suspend while a device is attached (`platform_pm_suspend returns -16`,
   `results/bt17-emulation-2026-11-13/logs/runs/*-pm-sysfreeze-*`). A second emulator on
   Raw Gadget and `dummy_hcd` (`harness/rg-emu.py`) brings btusb up and works before the
   sleep, but it cannot take part in a system resume: the freezer stops the user-space
   gadget until the devices have resumed. raw-gadget then leaves its running state
   ("device is not running"), and the re-enumeration fails (`logs/runs/base-pm-rg-plain-2.log`).
   Next: an in-kernel gadget function for this device, or a real QCA ROME on a spare machine
   with a DMI-table quirk set through `usbcore.quirks=13d3:3503:b`.
2. B makes each queued command time out on its own while the device resumes (three `tx
   timeout` lines in emulation instead of one blocked one). Acceptable, but the maintainers may
   prefer the core not to restore credit then.
3. The bot's CI on base and base + series (`scripts/bot-ci-local.sh`); an outside review.
4. C waits for evidence (a recurrence with USB core debug, an A/B with `power/control=on`).

**Decides:** the operator, for any send.
*(verbatim: `contributions/CO-44-mgmt-timeout-reported-as-auth-failed/README.md`)*
### CO-44 — MGMT: a command timeout is reported as "Authentication Failed" (BT-21)

**What:** `mgmt_errno_status()` (`net/bluetooth/mgmt.c`) maps `-ETIMEDOUT` to
`MGMT_STATUS_AUTH_FAILED` (0x05). At the laptop's BT-17 incident (2026-11-12 18:03), the
controller did not answer the kernel's Write Class of Device, and bluetoothd logged "Failed to
remove UUID: Authentication Failed (0x05)" three times, although no authentication took
place (`results/incident-2026-11-12-1803/`). `MGMT_STATUS_TIMEOUT` (0x08) exists, and the
HCI-status table in the same file already uses it for Connection Timeout, Host Timeout and
Directed Advertising Timeout.

- **Origin:** `161510ccf91c` ("Bluetooth: hci_sync: Make use of hci_cmd_sync_queue set 1",
  Luiz Augusto von Dentz, 2021-10-27, v5.17-rc1) added the errno table with this entry and
  gives no reason for it (third outside review of BT-17, checked with `git show`).
- **Present in:** bluetooth-next `da3cc0258` (2026-11-12) and Ubuntu's `7.0.0-42`/`-43`.

**State (2026-11-13): patch written and tested in QEMU; nothing sent.**

- **The patch:** `patch/0001-Bluetooth-MGMT-Report-a-timed-out-command-as-MGMT_ST.patch`,
  one line, `Fixes: 161510ccf91c`. No Signed-off-by: the operator adds his own.
  checkpatch `--strict --no-tree`: only the missing Signed-off-by, and "Unknown commit id"
  because it ran without a tree.
- **The test:** `patch/0001-mgmt-tester-Add-Set-Device-Class-timeout-test.patch` (`[PATCH BlueZ]`
  on master `20ffd285b`; the same change as `patch/bluez-mgmt-tester-set-dev-class-timeout.diff`), a new mgmt-tester case,
  "Set Device Class - Timeout 1". Its emulated controller drops Write Class of Device (a
  `HCIEMU_HOOK_PRE_CMD` hook returning false, `emulator/btdev.c:8742-8744`). It expects
  `MGMT_STATUS_TIMEOUT`.
- **Measured** (BlueZ `doc/tester.config` kernels, base `da3cc0258` and patched):

  | tester | base | patched |
  |---|---|---|
  | new case | fails: "Unexpected status got Authentication Failed (0x05) expected Timeout (0x08)" | passes (2.050 s) |
  | mgmt-tester, all 527 | 526 passed, 1 failed (the new case) | 527 passed |
  | l2cap-tester | 144 passed | 144 passed |
  | smp-tester | 8 passed | 8 passed |

- **Reach of the change** (an audit of every path into `mgmt_errno_status()`):
  - The sync-queued MGMT commands (Set Powered, Set Device Class, Add/Remove UUID,
    Discovery, Advertising, …) get 0x08 instead of 0x05 when the controller does not answer.
    bluetoothd only logs the text for them (`mgmt_errstr()`).
  - Pairing paths take positive HCI statuses through the HCI table, not this function, so
    they are unchanged; the seven `AUTH_FAILED` expectations in mgmt-tester (pairing
    rejects) still pass.
  - BlueZ already treats 0x08 as a timeout (`src/device.c:3493` maps it to
    "AuthenticationTimeout").
  - A grep of BlueZ's `src`, `profiles`, `plugins` and `tools/btmgmt.c` found nothing that
    depends on 0x05 for a timeout.
- **One other case changes status, with the same verdict:** mgmt-tester "Get Conn Info -
  Power off".
  - The kernel's Read RSSI (`0x1405`) times out during the power-off, and Get Connection
    Information is answered `0x05` on base, `0x08` patched.
  - The test expects `0x0f` Not Powered, logs "Unexpected status got 5 expected 15" (base) or
    "got 8 expected 15" (patched), and **passes anyway**: this test only logs a wrong status.
  - So the patch changes this case too, and the test cannot tell. That is by design: the case
    is declared `fail_tolerant = true` (`tools/mgmt-tester.c`, `get_conn_info_power_off_test`),
    since the emulated controller is powered off under the pending Read RSSI. Not a defect
    signal.
  - With the patch, the reply there reads "Timeout" instead of "Authentication Failed",
    which is the more accurate of the two.
- **Logs:** `logs/excerpt.txt` (the new case's lines and every tester's totals, with each full
  log's SHA-256). The full logs stay local in `agent-work/bt17-mgmt-timeout/logs/` with
  `SHA256SUMS`: they carry the emulated controllers' addresses, which the publishing scan
  cannot tell from real ones.
- **Seen on the way, not fixed:** `unpair_device_complete()` (`mgmt.c:3134`) passes the
  raw negative `err` to `cmd_complete` instead of `mgmt_status(err)`; not traced.

**The list's CI bot, run locally on the kernel patch** (`tmp/bot-ci-local/co44-20261113/`):
- **Passes:** BuildKernel, BuildKernel32, CheckAllWarning, CheckSparse, CheckKernelLLVM,
  IncrementalBuild, SubjectPrefix, TestRunnerSetup.
- **Testers:** `TestRunner_mgmt-tester` passes on both sides, with identical not-passed
  sets (the bot's BlueZ master, without our new case). The kernel-report scan is clean.
- **CheckPatch, VerifySignedoff, GitLint:** fail only for the missing Signed-off-by.
- **VerifyFixes:**
  - first "Target SHA1 does not exist": an artifact of the runner's history limit (2023);
  - rerun with history from 2021-06 (`co44-verifyfixes-20261113/`): only "empty lines
    surround the Fixes tag", because `Fixes:` is the message's last line. The operator's
    Signed-off-by goes directly under it.
- **The base side's one non-pass,** `Mesh - Send cancel - 1`, failed once on the unpatched
  base and passed patched: unrelated to this change (mesh, M-1).

**The list's CI bot, run locally on the BlueZ test** (`--space user`, master `20ffd285b`, the
patched kernel image; `tmp/bot-ci-local/co44-bluez-20261113/`): every check passes on both
sides, 0 not PASS. Patched: CheckPatch, GitLint, BuildEll, BluezMake, CheckSmatch,
bluezmakeextell, TestFunctional, IncrementalBuild, ScanBuild. Base: the same six tree checks.
The bot's user-space checks do not run mgmt-tester; the new case's runs are the table above.

**Next:**
- the kernel patch and the BlueZ test as two sends, the test noting that it needs the kernel fix;
- the operator's word for both.

**Decides:** the operator, for the send.
#### `contributions/CO-44-mgmt-timeout-reported-as-auth-failed/logs/excerpt.txt`
```
# CO-44: decisive lines of the tester runs (full logs local: /root/exp/agent-work/bt17-mgmt-timeout/logs, SHA256SUMS there)
# grep -a -E 'Set Device Class - Timeout 1|Unexpected status|^Total:' <log>, ANSI colours removed

== mgmt-newcase-base.log (sha256 cb22562ea00468a4...)
Set Device Class - Timeout 1 - init
Set Device Class - Timeout 1 - setup
Set Device Class - Timeout 1 - setup complete
Set Device Class - Timeout 1 - run
  Unexpected status got Authentication Failed (0x05) expected Timeout (0x08)
Set Device Class - Timeout 1 - test failed
Set Device Class - Timeout 1 - teardown
Set Device Class - Timeout 1 - teardown complete
Set Device Class - Timeout 1 - done
Set Device Class - Timeout 1                         Failed       2.045 seconds
Total: 168, Passed: 167 (99.4%), Failed: 1, Not Run: 0

== mgmt-newcase-patched.log (sha256 b663c7f202b479c1...)
Set Device Class - Timeout 1 - init
Set Device Class - Timeout 1 - setup
Set Device Class - Timeout 1 - setup complete
Set Device Class - Timeout 1 - run
Set Device Class - Timeout 1 - test passed
Set Device Class - Timeout 1 - teardown
Set Device Class - Timeout 1 - teardown complete
Set Device Class - Timeout 1 - done
Set Device Class - Timeout 1                         Passed       2.050 seconds
Total: 168, Passed: 168 (100.0%), Failed: 0, Not Run: 0

== mgmt-full-base.log (sha256 45bf4f89ca0e383e...)
Set Device Class - Timeout 1 - init
Set Device Class - Timeout 1 - setup
Set Device Class - Timeout 1 - setup complete
Set Device Class - Timeout 1 - run
  Unexpected status got Authentication Failed (0x05) expected Timeout (0x08)
Set Device Class - Timeout 1 - test failed
Set Device Class - Timeout 1 - teardown
Set Device Class - Timeout 1 - teardown complete
Set Device Class - Timeout 1 - done
  Unexpected status got 15 expected 14
  Unexpected status got 5 expected 15
Set Device Class - Timeout 1                         Failed       2.039 seconds
Total: 527, Passed: 526 (99.8%), Failed: 1, Not Run: 0

== mgmt-full-patched.log (sha256 04c57d5cf1576d83...)
Set Device Class - Timeout 1 - init
Set Device Class - Timeout 1 - setup
Set Device Class - Timeout 1 - setup complete
Set Device Class - Timeout 1 - run
Set Device Class - Timeout 1 - test passed
Set Device Class - Timeout 1 - teardown
Set Device Class - Timeout 1 - teardown complete
Set Device Class - Timeout 1 - done
  Unexpected status got 15 expected 14
  Unexpected status got 8 expected 15
Set Device Class - Timeout 1                         Passed       2.037 seconds
Total: 527, Passed: 527 (100.0%), Failed: 0, Not Run: 0

== l2cap-full-base.log (sha256 8fd555d0826fc9ef...)
Total: 144, Passed: 144 (100.0%), Failed: 0, Not Run: 0

== l2cap-full-patched.log (sha256 c54436e3e0478a91...)
Total: 144, Passed: 144 (100.0%), Failed: 0, Not Run: 0

== smp-full-base.log (sha256 3c538f19ecd13469...)
Total: 8, Passed: 8 (100.0%), Failed: 0, Not Run: 0

== smp-full-patched.log (sha256 16f1e22339454850...)
Total: 8, Passed: 8 (100.0%), Failed: 0, Not Run: 0
```
#### `tmp/bot-ci-local/co43-20261113/summary.txt (the list's CI bot, run locally)`
```
2026-11-13 03:47:11 image bluez-action-ci:60348956fc7b: action-ci 60348956fc7bad52a64e802f3e90f90c03ba8860; base FROM ghcr.io/pv/bluez-ci-image:latest@sha256:8d31a3fca8392a6ef194c8c21d05637a619c02d6f94820fdf50be7b7b8c0a191
2026-11-13 03:47:12 space kernel; base da3cc02587c629420603df4395179ec82955c941 (Bluetooth: hci_vhci: Report write readiness with queued input); BlueZ 20ffd285b58facfd1f2478d159a5f941b09d5be1; ELL 002b32d7c091993c5036956bf92d2444aca1c799
2026-11-13 03:47:12 mail contributions/CO-43-btusb-runtime-resume-failure/patch/0001-Bluetooth-btusb-Report-a-failed-resume-for-deferred-.patch
2026-11-13 03:47:12 mail contributions/CO-43-btusb-runtime-resume-failure/patch/0002-Bluetooth-btusb-Don-t-reset-a-device-that-has-not-re.patch
2026-11-13 03:47:12 mail contributions/CO-43-btusb-runtime-resume-failure/patch/0003-Bluetooth-btusb-Recover-after-a-reset-resume.patch
2026-11-13 03:47:12 mail contributions/CO-43-btusb-runtime-resume-failure/patch/0004-Bluetooth-btusb-Anchor-a-deferred-URB-under-txlock.patch
2026-11-13 03:47:12 patched: blobless clone of bluetooth-next since 2023-01-01
2026-11-13 03:50:31 patched: start
2026-11-13 04:03:22 patched: done, 3 test(s) not PASS
Test Summary:
CheckPatch                    FAIL      768.77 seconds
VerifyFixes                   PASS      0.02 seconds
VerifySignedoff               FAIL      767.26 seconds
GitLint                       FAIL      767.11 seconds
SubjectPrefix                 PASS      0.00 seconds
BuildKernel                   PASS      22.03 seconds
CheckAllWarning               PASS      27.54 seconds
CheckSparse                   PASS      28.11 seconds
BuildKernel32                 PASS      23.32 seconds
CheckKernelLLVM               PASS      25.50 seconds
TestRunnerSetup               PASS      586.48 seconds
IncrementalBuild              PASS      31.63 seconds

Details
##############################
Test: CheckPatch - FAIL
Desc: Run checkpatch.pl script
Output:
[1/5] Bluetooth: btusb: Report a failed resume for deferred data
ERROR: Missing Signed-off-by: line(s)

total: 1 errors, 0 warnings, 16 lines checked

NOTE: For some of the reported defects, checkpatch may be able to
      mechanically convert to the typical style using --fix or --fix-inplace.

/root/exp/qca9377-bt-hang/tmp/bot-ci-local/co43-20261113/work/patched/patch/1001.patch has style problems, please review.

NOTE: Ignored message types: UNKNOWN_COMMIT_ID

NOTE: If any of the errors are false positives, please report
      them to the maintainer, see CHECKPATCH in MAINTAINERS.


[2/5] Bluetooth: btusb: Don't reset a device that has not resumed
ERROR: Missing Signed-off-by: line(s)

total: 1 errors, 0 warnings, 23 lines checked

NOTE: For some of the reported defects, checkpatch may be able to
      mechanically convert to the typical style using --fix or --fix-inplace.

/root/exp/qca9377-bt-hang/tmp/bot-ci-local/co43-20261113/work/patched/patch/1002.patch has style problems, please review.

NOTE: Ignored message types: UNKNOWN_COMMIT_ID

NOTE: If any of the errors are false positives, please report
      them to the maintainer, see CHECKPATCH in MAINTAINERS.


[3/5] Bluetooth: btusb: Recover after a reset-resume
ERROR: Missing Signed-off-by: line(s)

total: 1 errors, 0 warnings, 38 lines checked

NOTE: For some of the reported defects, checkpatch may be able to
      mechanically convert to the typical style using --fix or --fix-inplace.

/root/exp/qca9377-bt-hang/tmp/bot-ci-local/co43-20261113/work/patched/patch/1003.patch has style problems, please review.

NOTE: Ignored message types: UNKNOWN_COMMIT_ID

NOTE: If any of the errors are false positives, please report
      them to the maintainer, see CHECKPATCH in MAINTAINERS.


[4/5] Bluetooth: btusb: Anchor a deferred URB under txlock
ERROR: Missing Signed-off-by: line(s)

total: 1 errors, 0 warnings, 22 lines checked

NOTE: For some of the reported defects, checkpatch may be able to
      mechanically convert to the typical style using --fix or --fix-inplace.

/root/exp/qca9377-bt-hang/tmp/bot-ci-local/co43-20261113/work/patched/patch/1004.patch has style problems, please review.

NOTE: Ignored message types: UNKNOWN_COMMIT_ID

NOTE: If any of the errors are false positives, please report
      them to the maintainer, see CHECKPATCH in MAINTAINERS.


##############################
Test: VerifySignedoff - FAIL
Desc: Verify Signed-off-by chain
Output:
Commit e82996798c7b ("Bluetooth: btusb: Anchor a deferred URB under txlock")
	author Signed-off-by missing
	committer Signed-off-by missing
	author email:    yaroslav.voytovych@gmail.com
	committer email: yaroslav.voytovych@gmail.com
	

Commit b5fba05f15af ("Bluetooth: btusb: Recover after a reset-resume")
	author Signed-off-by missing
	committer Signed-off-by missing
	author email:    yaroslav.voytovych@gmail.com
	committer email: yaroslav.voytovych@gmail.com
	

Commit 4c79c3470499 ("Bluetooth: btusb: Don't reset a device that has not resumed")
	author Signed-off-by missing
	committer Signed-off-by missing
	author email:    yaroslav.voytovych@gmail.com
	committer email: yaroslav.voytovych@gmail.com
	

Commit 63ece9695a27 ("Bluetooth: btusb: Report a failed resume for deferred data")
	author Signed-off-by missing
	committer Signed-off-by missing
	author email:    yaroslav.voytovych@gmail.com
	committer email: yaroslav.voytovych@gmail.com
	

Errors in tree with Signed-off-by, please fix!

##############################
Test: GitLint - FAIL
Desc: Run gitlint
Output:
[1/5] Bluetooth: btusb: Report a failed resume for deferred data

1: CC1 Body does not contain a 'Signed-off-by' line
[2/5] Bluetooth: btusb: Don't reset a device that has not resumed

1: CC1 Body does not contain a 'Signed-off-by' line
[3/5] Bluetooth: btusb: Recover after a reset-resume

1: CC1 Body does not contain a 'Signed-off-by' line
[4/5] Bluetooth: btusb: Anchor a deferred URB under txlock

1: CC1 Body does not contain a 'Signed-off-by' line
2026-11-13 04:03:40 base: start
2026-11-13 04:16:03 base: done, 0 test(s) not PASS
Test Summary:
BuildKernel                   PASS      25.32 seconds
CheckAllWarning               PASS      29.17 seconds
CheckSparse                   PASS      32.02 seconds
BuildKernel32                 PASS      26.38 seconds
CheckKernelLLVM               PASS      28.79 seconds
TestRunnerSetup               PASS      579.41 seconds

2026-11-13 04:16:03 NOT CLEAN: patched: 3 test(s) not PASS (a WARNING counts; compare with the base before judging)
2026-11-13 04:16:03 ALL DONE, exit 1
```
#### `tmp/bot-ci-local/co44-20261113/summary.txt (the list's CI bot, run locally)`
```
2026-11-13 04:16:21 image bluez-action-ci:60348956fc7b: action-ci 60348956fc7bad52a64e802f3e90f90c03ba8860; base FROM ghcr.io/pv/bluez-ci-image:latest@sha256:8d31a3fca8392a6ef194c8c21d05637a619c02d6f94820fdf50be7b7b8c0a191
2026-11-13 04:16:22 space kernel; base da3cc02587c629420603df4395179ec82955c941 (Bluetooth: hci_vhci: Report write readiness with queued input); BlueZ 20ffd285b58facfd1f2478d159a5f941b09d5be1; ELL 002b32d7c091993c5036956bf92d2444aca1c799
2026-11-13 04:16:22 mail contributions/CO-44-mgmt-timeout-reported-as-auth-failed/patch/0001-Bluetooth-MGMT-Report-a-timed-out-command-as-MGMT_ST.patch
2026-11-13 04:16:22 patched: blobless clone of bluetooth-next since 2023-01-01
2026-11-13 04:19:35 patched: start
2026-11-13 04:33:31 patched: done, 4 test(s) not PASS
Test Summary:
CheckPatch                    FAIL      833.99 seconds
VerifyFixes                   FAIL      833.61 seconds
VerifySignedoff               FAIL      833.59 seconds
GitLint                       FAIL      833.54 seconds
SubjectPrefix                 PASS      0.00 seconds
BuildKernel                   PASS      21.93 seconds
CheckAllWarning               PASS      26.09 seconds
CheckSparse                   PASS      29.82 seconds
BuildKernel32                 PASS      25.22 seconds
CheckKernelLLVM               PASS      26.51 seconds
TestRunnerSetup               PASS      573.89 seconds
TestRunner_mgmt-tester        PASS      82.21 seconds
TestRunner_mesh-tester        PASS      4.93 seconds
IncrementalBuild              PASS      20.61 seconds

Details
##############################
Test: CheckPatch - FAIL
Desc: Run checkpatch.pl script
Output:
Bluetooth: MGMT: Report a timed out command as MGMT_STATUS_TIMEOUT
ERROR: Missing Signed-off-by: line(s)

total: 1 errors, 0 warnings, 0 checks, 8 lines checked

NOTE: For some of the reported defects, checkpatch may be able to
      mechanically convert to the typical style using --fix or --fix-inplace.

/root/exp/qca9377-bt-hang/tmp/bot-ci-local/co44-20261113/work/patched/patch/1001.patch has style problems, please review.

NOTE: Ignored message types: UNKNOWN_COMMIT_ID

NOTE: If any of the errors are false positives, please report
      them to the maintainer, see CHECKPATCH in MAINTAINERS.


##############################
Test: VerifyFixes - FAIL
Desc: Verify Fixes tag format and validity
Output:
Commit: a4188a21bbf ("Bluetooth: MGMT: Report a timed out command as MGMT_STATUS_TIMEOUT")
	Fixes tag: Fixes: 161510ccf91c ("Bluetooth: hci_sync: Make use of hci_cmd_sync_queue set 1")
	Has these problem(s):
		- Target SHA1 does not exist

##############################
Test: VerifySignedoff - FAIL
Desc: Verify Signed-off-by chain
Output:
Commit a4188a21bbfd ("Bluetooth: MGMT: Report a timed out command as MGMT_STATUS_TIMEOUT")
	author Signed-off-by missing
	committer Signed-off-by missing
	author email:    yaroslav.voytovych@gmail.com
	committer email: yaroslav.voytovych@gmail.com
	

Errors in tree with Signed-off-by, please fix!

##############################
Test: GitLint - FAIL
Desc: Run gitlint
Output:
Bluetooth: MGMT: Report a timed out command as MGMT_STATUS_TIMEOUT

1: CC1 Body does not contain a 'Signed-off-by' line
2026-11-13 04:33:48 base: start
2026-11-13 04:47:23 base: done, 1 test(s) not PASS
Test Summary:
BuildKernel                   PASS      22.90 seconds
CheckAllWarning               PASS      28.06 seconds
CheckSparse                   PASS      30.84 seconds
BuildKernel32                 PASS      25.93 seconds
CheckKernelLLVM               PASS      26.61 seconds
TestRunnerSetup               PASS      574.54 seconds
TestRunner_mgmt-tester        PASS      82.13 seconds
TestRunner_mesh-tester        FAIL      3.91 seconds

Details
##############################
Test: TestRunner_mesh-tester - FAIL
Desc: Run mesh-tester with test-runner
Output:
Total: 10, Passed: 9 (90.0%), Failed: 1, Not Run: 0

Failed Test Cases
Mesh - Send cancel - 1                               Failed       0.016 seconds
2026-11-13 04:47:23 TestRunner_mesh-tester: not-passed sets identical: False (A 1, B 0)
2026-11-13 04:47:23 TestRunner_mgmt-tester: not-passed sets identical: True (A 0, B 0)
2026-11-13 04:47:23 kernel-report-scan exit 0 (kernel-report-scan.txt)
2026-11-13 04:47:23 NOT CLEAN: patched: 4 test(s) not PASS (a WARNING counts; compare with the base before judging)
2026-11-13 04:47:23 NOT CLEAN: base: 1 test(s) not PASS (a WARNING counts; compare with the base before judging)
2026-11-13 04:47:23 ALL DONE, exit 1
```
#### `tmp/bot-ci-local/co44-verifyfixes-20261113/summary.txt (the list's CI bot, run locally)`
```
2026-11-13 04:48:15 image bluez-action-ci:60348956fc7b: action-ci 60348956fc7bad52a64e802f3e90f90c03ba8860; base FROM ghcr.io/pv/bluez-ci-image:latest@sha256:8d31a3fca8392a6ef194c8c21d05637a619c02d6f94820fdf50be7b7b8c0a191
2026-11-13 04:48:16 space kernel; base da3cc02587c629420603df4395179ec82955c941 (Bluetooth: hci_vhci: Report write readiness with queued input); BlueZ 20ffd285b58facfd1f2478d159a5f941b09d5be1; ELL 002b32d7c091993c5036956bf92d2444aca1c799
2026-11-13 04:48:16 mail contributions/CO-44-mgmt-timeout-reported-as-auth-failed/patch/0001-Bluetooth-MGMT-Report-a-timed-out-command-as-MGMT_ST.patch
2026-11-13 04:48:16 patched: blobless clone of bluetooth-next since 2021-06-01
2026-11-13 04:52:17 patched: start
2026-11-13 04:52:26 patched: done, 1 test(s) not PASS
Test Summary:
VerifyFixes                   FAIL      8.70 seconds

Details
##############################
Test: VerifyFixes - FAIL
Desc: Verify Fixes tag format and validity
Output:
Commit: c3d1ac74e2c ("Bluetooth: MGMT: Report a timed out command as MGMT_STATUS_TIMEOUT")
	Fixes tag: Fixes: 161510ccf91c ("Bluetooth: hci_sync: Make use of hci_cmd_sync_queue set 1")
	Has these problem(s):
		- empty lines surround the Fixes tag

2026-11-13 04:52:26 NOT CLEAN: patched: 1 test(s) not PASS (a WARNING counts; compare with the base before judging)
2026-11-13 04:52:26 ALL DONE, exit 1
```
#### `tmp/bot-ci-local/co44-bluez-20261113/summary.txt (the list's CI bot, run locally)`
```
2026-11-13 04:54:47 image bluez-action-ci:60348956fc7b: action-ci 60348956fc7bad52a64e802f3e90f90c03ba8860; base FROM ghcr.io/pv/bluez-ci-image:latest@sha256:8d31a3fca8392a6ef194c8c21d05637a619c02d6f94820fdf50be7b7b8c0a191
2026-11-13 04:54:48 space user; base 20ffd285b58facfd1f2478d159a5f941b09d5be1 (shared/gatt-client: Track pending discovery Database Hash reads); ELL 002b32d7c091993c5036956bf92d2444aca1c799; kernel image tmp/bot-ci-local/co44-kernel/bzImage-patched
2026-11-13 04:54:48 mail contributions/CO-44-mgmt-timeout-reported-as-auth-failed/patch/0001-mgmt-tester-Add-Set-Device-Class-timeout-test.patch
2026-11-13 04:54:49 patched: start
2026-11-13 05:31:21 patched: done, 0 test(s) not PASS
Test Summary:
CheckPatch                    PASS      0.15 seconds
GitLint                       PASS      0.11 seconds
BuildEll                      PASS      15.80 seconds
BluezMake                     PASS      214.03 seconds
CheckSmatch                   PASS      257.03 seconds
bluezmakeextell               PASS      79.30 seconds
TestFunctional                PASS      571.79 seconds
IncrementalBuild              PASS      220.27 seconds
ScanBuild                     PASS      830.41 seconds

2026-11-13 05:31:22 base: start
2026-11-13 06:04:22 base: done, 0 test(s) not PASS
Test Summary:
BuildEll                      PASS      17.62 seconds
BluezMake                     PASS      236.78 seconds
CheckSmatch                   PASS      256.14 seconds
bluezmakeextell               PASS      79.35 seconds
TestFunctional                PASS      568.80 seconds
ScanBuild                     PASS      819.41 seconds

2026-11-13 06:04:22 ALL DONE, exit 0
```
