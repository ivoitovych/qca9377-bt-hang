# Source investigation task — `BT-17`: an idle QCA9377 Bluetooth controller never came back from USB runtime suspend, was reset off the bus, and returned only after a power-off (2026-11-12)

*The brief for outside reviewers, written 2026-11-13T00:03Z. It is self-contained: every log
line, capture decode, sysfs value and source fragment the questions rest on is quoted below,
with the command that produced it. No other file, link or earlier brief is needed.*

## What is asked

A **source-code investigation** of the code behind one incident, `BT-17`, on the laptop
described below. The kernel log (with Bluetooth and btusb debug output on), an HCI capture and
the Bluetooth daemon's debug log are recorded and quoted here. What is missing is the code, read
at the versions that ran: which function, which state and which ordering produced what we saw,
and **which code fragments could take part in the failure**.

Please **check out the code and read it**; do not rely on this brief alone. For each item, tell
us:
- which code participates (tree, version or commit, file, function, line);
- what in that code explains the observation, and what does not;
- how sure you are, and what would falsify your reading;
- **the history:** the commit that introduced the behaviour (`git log -S` / `git blame`), its
  stated reason, and whether a later commit on mainline changed it;
- reports of the same failure by others (kernel mailing lists, bug trackers, distribution bug
  reports), with the device, platform and kernel they name;
- what a fix would look like, and where it belongs (btusb, btqca, the Bluetooth core, the USB
  core, the xHCI driver, the controller's firmware, or the platform);
- the one experiment that would decide it.

**Findings that contradict this brief are as welcome as ones that support it.** "I read X and it
cannot be the cause" is a result. If the code shows a defect we have not listed, tell us.

### How much this rests on

- **One occurrence.** Enough to direct a code review, not enough to prove a cause.
- **What we have:** the full kernel log of the failing boot, with dynamic debug on for
  `hci_core.c`, `hci_sync.c`, `hci_conn.c` and `btusb.c` (btusb's per-packet functions off);
  the HCI capture; bluetoothd's debug log; sysfs values; the trial history of the same setup.
- **What we do not have:** USB core debug (`drivers/usb/core/hub.c` and `driver.c` `dev_dbg`
  lines were off), xHCI debug or trace events, `usbmon`. So no line shows *why* a reset was
  issued or what the controller did on the wire.

## The machine: exactly what ran

- **Kernel:** Ubuntu `7.0.0-42-generic`, package `linux-image-7.0.0-42-generic
  7.0.0-42.42~24.04.1` (mainline v7.0 plus the `linux-hwe-7.0` `7.0.0-42.42~24.04.1` delta).
  We read `drivers/bluetooth/` and `net/bluetooth/` in the patched Ubuntu tree; line numbers
  below for those files are that tree's. `drivers/usb/` and `drivers/base/power/` were read in
  **mainline v7.0**; we did not check whether the Ubuntu delta touches them.
- **btusb:** Ubuntu's `7.0.0-42` `btusb.c` plus one line, the upstream device-table entry
  `dc16388d45ec` for this controller, built out of tree (hence the taint lines below):

  ```c
  	{ USB_DEVICE(0x13d3, 0x3503), .driver_info = BTUSB_QCA_ROME |
  						     BTUSB_WIDEBAND_SPEECH },
  ```

  Nothing else in btusb differs from Ubuntu's. Before this entry the controller was bound by the
  generic class match, so it ran without `BTUSB_QCA_ROME` and without its firmware patch.
- **Controller:** Qualcomm QCA9377 ("ROME"), USB `13d3:3503` (IMC Networks), BR/EDR and LE. It
  is the Bluetooth half of an M.2 combo card; the Wi-Fi half is `ath10k_pci` on PCIe
  `0000:02:00.0` and kept working throughout.
  - The firmware patch loads normally: `QCA: patch rome 0x302 build 0x3e8, firmware rome 0x302
    build 0x111`.
  - Files: `qca/rampatch_usb_00000302.bin` and `qca/nvm_usb_00000302.bin`, from package
    `linux-firmware-qualcomm-wireless 20240318.git3b128b60-0ubuntu3.1`.
  - SHA-256 of the installed `.zst` files: `d768b822e74b3454f21ceeb22e3fbe587f6268957fec8a21d5695088afacc682`
    (rampatch) and `19510791fa65ca7604c7a7160e656861ef0864fa07f608199adb28cd474a5e1c` (NVM).
  - No reset GPIO (`BT_EN`) is exposed to btusb.
- **Platform:** AMD Ryzen 7 5825U. DMI vendor and product are `Default string`, so none of
  btusb's DMI tables match.
- **USB host and topology:** `lspci -nn -s 03:00.4`:

  ```
  03:00.4 USB controller [0c03]: Advanced Micro Devices, Inc. [AMD] Renoir/Cezanne USB 3.1 [1022:1639]
  ```

  The controller is `usb 3-3`, port 3 of root hub `usb3` (xHCI `0000:03:00.4`): a **direct
  child of the SoC's root hub**, at full speed.
- **Runtime PM:** `CONFIG_BT_HCIBTUSB_AUTOSUSPEND=y`, with no `enable_autosuspend` override
  and no udev rule.
- **USB device attributes.** They were read on 2026-11-12 22:57 in the boot after recovery
  (kernel `7.0.0-43`, Ubuntu's own btusb, which carries the same entry). The failing boot had the
  same Kconfig and no override, but its values were not read.

  `grep -r . /sys/bus/usb/devices/3-3/power/persist /sys/bus/usb/devices/3-3/power/wakeup /sys/bus/usb/devices/3-3/power/control /sys/bus/usb/devices/3-3/power/autosuspend_delay_ms /sys/bus/usb/devices/3-3/power/runtime_status /sys/bus/usb/devices/3-3/bmAttributes /sys/bus/usb/devices/3-3/quirks /sys/bus/usb/devices/3-3/speed /sys/bus/usb/devices/3-3/version /sys/bus/usb/devices/3-3/avoid_reset_quirk /sys/bus/usb/devices/3-3/power/usb2_hardware_lpm /sys/bus/usb/devices/3-3:1.0/supports_autosuspend`
  (the `usb2_hardware_lpm` file does not exist for this device):

  ```
  /sys/bus/usb/devices/3-3/power/wakeup:disabled
  /sys/bus/usb/devices/3-3/power/control:auto
  /sys/bus/usb/devices/3-3/quirks:0x0
  /sys/bus/usb/devices/3-3/power/autosuspend_delay_ms:2000
  /sys/bus/usb/devices/3-3/power/persist:1
  /sys/bus/usb/devices/3-3/power/runtime_status:suspended
  /sys/bus/usb/devices/3-3/speed:12
  /sys/bus/usb/devices/3-3/bmAttributes:e0
  /sys/bus/usb/devices/3-3/version: 1.10
  /sys/bus/usb/devices/3-3:1.0/supports_autosuspend:1
  /sys/bus/usb/devices/3-3/avoid_reset_quirk:0
  ```

  - `bmAttributes 0xe0`: self-powered, and remote wakeup supported.
  - `persist 1`: the USB core may retry a failed resume as a reset-resume.
  - `quirks 0x0`: neither `USB_QUIRK_RESET` nor `USB_QUIRK_RESET_RESUME`.
  - `wakeup disabled` is the *system*-wakeup policy. It does not stop remote wakeup during
    runtime suspend.
  - On that later boot the idle controller was runtime-suspended for 145,431 ms of the first
    ~158,500 ms (`runtime_suspended_time`).
- **Bluetooth daemon:** BlueZ `bluetoothd -d`, a local build of Ubuntu's `5.72-0ubuntu5.5`
  source with two later upstream crash fixes. It only sends MGMT commands here; nothing in it is
  expected to matter beyond being the trigger.
- **Dynamic debug in the failing boot:**
  - `bluetooth.ko`: `file hci_core.c +p; file hci_sync.c +p; file hci_conn.c +p`.
  - `btusb.c`: `+p`, then `-p` for the per-packet functions: `btusb_send_frame` and the URB
    completion handlers.
  - So `btusb_suspend()`, `btusb_resume()`, `btusb_disconnect()`, `btusb_open()` and the
    `btusb_submit_*_urb()` functions print. `drivers/usb/` printed only its default-level
    messages.

**Not in question:**
- The device-table entry itself. Without it this controller ran its ROM firmware and hung on the
  first HCI command after a transparent (mSBC) SCO stream started; only a power-off recovered it.
  The entry fixed that: 74 test links with 0 timeouts, then eight boots of daily use with no
  timeout (E9).
- **This incident had no SCO link, no ACL link and no discovery.**

## The incident (all times 2026-11-12, CET)

Wall-clock times are the journal's. The journal logged `Time jumped backwards, rotating` at
18:00:45, inside the idle interval, so intervals across it are taken from the kernel's
monotonic timestamps (`[s]`, second column), read with `journalctl -b 0895606911384479be9cbd6a7f726000 _TRANSPORT=kernel -o short-monotonic`.

| wall clock | monotonic | event |
|---|---|---|
| 18:00:13.25 | | `usb 3-3` enumerates (`13d3:3503`); btusb (out of tree) binds |
| 18:00:13.74 | 2.778 | `using rampatch file`; patch rome 0x302 build 0x3e8 |
| 18:00:19.51 | 8.555 | **device suspend** (btusb debug: interface 1, then interface 0), before bluetoothd opens hci0 |
| 18:00:26.58 | 15.621 | **device resume** (interface 0, then 1): bluetoothd opens hci0 |
| 18:00:26.846 | 15.889 | last HCI event from the controller (`Command Complete`, Write EIR, capture frame #120) |
| 18:00:28.857 | 17.900 | **device suspend**, 2.011 s after the last activity (`autosuspend_delay_ms` 2000). HCI is open, so `needs_remote_wakeup = 1` |
| | | 160.8 s with no kernel line for the controller. No remote-wakeup resume |
| 18:03:08.290 | | the user logs in (gdm). The greeter's audio session exits, and bluetoothd removes profile UUIDs (MGMT `Remove UUID`) |
| 18:03:08.827 | 178.731 | the kernel sends **HCI Write Class of Device (0x0c24)** to the driver (capture frame #121; `cmd_cnt 1 cmd queued 1`) |
| | | **no `btusb_resume()` line follows, ever** |
| 18:03:10.869 | 180.772 | `command 0x0c24 tx timeout` (2.041 s after the send). `hci_cmd_timeout()` calls `hdev->reset` |
| 18:03:12.918 | 182.820 | second `Opcode 0x0c24 failed: -110`: a queued command that was never sent times out |
| 18:03:14.120 | 184.023 | **first `usb 3-3: reset full-speed USB device number 2 using xhci_hcd`**: 5.291 s after the send, 3.251 s after the HCI timeout. No `Resetting usb device.` line, before or after |
| 18:03:14.24–16.18 | 184.0–186.1 | three more resets; `device descriptor read/64, error -71`; `Device not responding to setup address`; xHCI `unexpected setup address command completion code 0x11`; `WARN: invalid context state for evaluate context command`; `device not accepting address 2, error -22` |
| 18:03:16.18 | 186.083045 | `usb 3-3: USB disconnect, device number 2` |
| 18:03:16.18 | 186.083044 | `Bluetooth: hci0: Failed usb_autopm_get_interface: -16` (1 µs *before* the disconnect line, on the monotonic clock) |
| 18:03:16.18 | 186.083056 | `hci0 cmd_cnt 1 cmd queued 3`: the command credit is restored, and frame #122 goes to a device that is gone |
| 18:03:17.02 | 186.9 | MGMT `Index Removed`; hci0 unregistered |
| 18:03:17.13–19.46 | 187.0–189.4 | re-enumeration fails (`-71`, no response to SET_ADDRESS); `usb usb3-port3: attempt power cycle` (188.042); `unable to enumerate USB device` (189.363) |
| 18:07:21 | | warm reboot |
| 18:08:03 | | next boot: port 3-3 fails to enumerate at once (`-71`). Wi-Fi on the same card works |
| 22:46:44 → 22:55:08 | | power-off for ~8.4 min, then power-on: the controller enumerates, loads its patch, and works |

## The evidence, verbatim

Bluetooth addresses are replaced by `<addr>`. The host name is `n` and the user is `i`. Each
block gives the command that produced it. The excerpt commands use `-b -1`, which was the
failing boot when they were run. That boot's ID is `0895606911384479be9cbd6a7f726000`.

### E1. btusb suspend/resume prints in the failing boot (raw lines)

`grep -n "kernel: intf \|USB disconnect\|name hci0 bus"` over the boot's full kernel log
(`journalctl -b -1 _TRANSPORT=kernel -o short-precise`):

```
1128:Nov 12 18:00:19.512568 n kernel: intf 000000003dea1427
1129:Nov 12 18:00:19.512624 n kernel: intf 0000000095c0721a
1195:Nov 12 18:00:26.577645 n kernel: intf 0000000095c0721a
1196:Nov 12 18:00:26.577840 n kernel: intf 000000003dea1427
1822:Nov 12 18:00:28.856623 n kernel: intf 000000003dea1427
1823:Nov 12 18:00:28.856750 n kernel: intf 0000000095c0721a
1888:Nov 12 18:03:16.181629 n kernel: usb 3-3: USB disconnect, device number 2
1892:Nov 12 18:03:16.181920 n kernel: intf 0000000095c0721a
1893:Nov 12 18:03:16.181935 n kernel: 00000000570e87a2 name hci0 bus 1
1913:Nov 12 18:03:17.022465 n kernel: intf 000000003dea1427
```

- `intf %p` is `BT_DBG("intf %p", intf)` in `btusb_suspend()`, `btusb_resume()` and
  `btusb_disconnect()`.
- `0000000095c0721a` is interface 0. After the USB disconnect, `btusb_disconnect()` prints it
  first, right before `hci_unregister_dev()` (`… name hci0 bus 1`).
- The USB core suspends interfaces from the highest number down and resumes them from 0 up. So
  "1 then 0" is a device suspend, and "0 then 1" is a device resume.

The full kernel log around the last suspend: nothing for the controller in between.

```
Nov 12 18:00:26.846554 n kernel: opcode 0x0c52 status 0x00
Nov 12 18:00:26.846576 n kernel: hci0: result 0x00
Nov 12 18:00:26.846600 n kernel: hci0: end: err 0
Nov 12 18:00:28.856623 n kernel: intf 000000003dea1427
Nov 12 18:00:28.856750 n kernel: intf 0000000095c0721a
Nov 12 18:00:45.457586 n systemd-journald[475]: Time jumped backwards, rotating.
Nov 12 18:03:08.818452 n kernel: rfkill: input handler enabled
Nov 12 18:03:08.827366 n kernel: 0
Nov 12 18:03:08.827402 n kernel: hci0: 
Nov 12 18:03:08.827426 n kernel: hci0: entry 0000000037d8f7a5
Nov 12 18:03:08.827442 n kernel: hci0: 
Nov 12 18:03:08.827453 n kernel: hci0: Opcode 0x0c24
Nov 12 18:03:08.827465 n kernel: hci0: opcode 0x0c24 plen 3
Nov 12 18:03:08.827476 n kernel: hci0: skb len 6
Nov 12 18:03:08.827490 n kernel: hci0: length 1
Nov 12 18:03:08.827502 n kernel: hci0 cmd_cnt 1 cmd queued 1
Nov 12 18:03:08.827513 n kernel: hci0: skb 000000003cdd38d2
```

### E2. The same, as device-level cycles, failing boot and the boot before

The prints are grouped by time (lines < 10 ms apart) and classified as described in E1.
`suspend-cycles.py <kernel log>` on the failing boot `08956069`:

```
18:00:19.512568 device suspend
18:00:26.577645 device resume  (was suspended 7.065 s)
18:00:28.856623 device suspend
18:03:16.181629 other: USB-DISCONNECT primary
18:03:17.022465 other: 000000003dea1427
OPEN: device suspended since 18:00:28.856623, no device resume follows
primary interface 0000000095c0721a; completed device suspend/resume cycles 1; longest suspend 7.065 s
```

The previous boot, `7e87eae0`: same kernel, same btusb, same firmware. It ran 15:49–17:52 and
ended with a power-off. A headset session ran at 17:49–17:52; the `other:` lines there are
interface 1 alone, around SCO.

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

**So the same setup resumed from suspends of 49 and 71 minutes two hours earlier.** A long idle
is not enough by itself; the failure is intermittent.

### E3. Kernel, the failure window (whole window, blank debug lines dropped)

`journalctl -b -1 _TRANSPORT=kernel --no-pager -o short-precise --since "2026-11-12 18:03:08.8" --until "2026-11-12 18:03:20"`:

```
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

The same key lines on the kernel's monotonic clock
(`journalctl -b 0895606911384479be9cbd6a7f726000 _TRANSPORT=kernel --no-pager -o short-monotonic -g "intf |opcode 0x0c52 status|cmd_cnt 1 cmd queued 3|tx timeout|failed: -110|reset full-speed|USB disconnect|Failed usb_autopm|unable to enumerate|attempt power cycle|rampatch"`;
the last nine `0x0c52` lines of the start-up shown as one):

```
[    2.777836] n kernel: Bluetooth: hci0: using rampatch file: qca/rampatch_usb_00000302.bin
[    8.555338] n kernel: intf 000000003dea1427
[    8.555350] n kernel: intf 0000000095c0721a
[   15.620673] n kernel: intf 0000000095c0721a
[   15.620691] n kernel: intf 000000003dea1427
 … nine more "opcode 0x0c52 status 0x00", 15.838324 to 15.883325 …
[   15.889321] n kernel: opcode 0x0c52 status 0x00
[   17.899481] n kernel: intf 000000003dea1427
[   17.899902] n kernel: intf 0000000095c0721a
[  180.772008] n kernel: Bluetooth: hci0: command 0x0c24 tx timeout
[  180.772016] n kernel: Bluetooth: hci0: Opcode 0x0c24 failed: -110
[  182.819816] n kernel: Bluetooth: hci0: Opcode 0x0c24 failed: -110
[  184.022630] n kernel: usb 3-3: reset full-speed USB device number 2 using xhci_hcd
[  184.579135] n kernel: usb 3-3: reset full-speed USB device number 2 using xhci_hcd
[  184.866996] n kernel: Bluetooth: hci0: Opcode 0x0c24 failed: -110
[  185.140952] n kernel: usb 3-3: reset full-speed USB device number 2 using xhci_hcd
[  185.666858] n kernel: usb 3-3: reset full-speed USB device number 2 using xhci_hcd
[  186.083045] n kernel: usb 3-3: USB disconnect, device number 2
[  186.083044] n kernel: Bluetooth: hci0: Failed usb_autopm_get_interface: -16
[  186.083056] n kernel: hci0 cmd_cnt 1 cmd queued 3
[  186.083260] n kernel: intf 0000000095c0721a
[  186.914544] n kernel: Bluetooth: hci0: Opcode 0x0c24 failed: -110
[  186.923725] n kernel: intf 000000003dea1427
[  188.042418] n kernel: usb usb3-port3: attempt power cycle
[  189.362540] n kernel: usb usb3-port3: unable to enumerate USB device
```

And the send of frame #121:
`journalctl -b 0895606911384479be9cbd6a7f726000 _TRANSPORT=kernel --no-pager -o short-monotonic -g "cmd_cnt|Time jumped|rfkill: input handler" -n 6`:

```
[  430.934917] n kernel: rfkill: input handler enabled
[  186.083056] n kernel: hci0 cmd_cnt 1 cmd queued 3
[  179.752307] n kernel: rfkill: input handler disabled
[  178.731163] n kernel: hci0 cmd_cnt 1 cmd queued 1
[  178.722098] n kernel: rfkill: input handler enabled
[   35.363980] n systemd-journald[475]: Time jumped backwards, rotating.
```

### E4. Kernel, the last answered commands before the idle

`journalctl -b -1 _TRANSPORT=kernel --no-pager -o short-precise --since "2026-11-12 18:00:26.84" --until "2026-11-12 18:00:26.85"`:

```
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

The same command, Write Class of Device (`0x0c24`), was answered in 2.8 ms here, while the
device was active.

### E5. Kernel, the failing boot's start-up (controller lines)

`journalctl -b -1 _TRANSPORT=kernel --no-pager -o short-precise`, lines matching
`13d3|btusb|Bluetooth:|usb 3-3|usb3-port3|xhci_hcd|ath10k_pci .*firmware ver|rfkill`, debug noise
dropped, up to the idle:

```
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
Nov 12 18:00:13.253085 n kernel: usb 3-3: new full-speed USB device number 2 using xhci_hcd
Nov 12 18:00:13.253995 n kernel: usb 3-3: New USB device found, idVendor=13d3, idProduct=3503, bcdDevice= 0.01
Nov 12 18:00:13.254187 n kernel: usb 3-3: New USB device strings: Mfr=0, Product=0, SerialNumber=0
Nov 12 18:00:13.626565 n kernel: Bluetooth: Core ver 2.22
Nov 12 18:00:13.722559 n kernel: btusb: loading out-of-tree module taints kernel.
Nov 12 18:00:13.722627 n kernel: btusb: module verification failed: signature and/or required key missing - tainting kernel
Nov 12 18:00:13.726559 n kernel: usbcore: registered new interface driver btusb
Nov 12 18:00:13.735075 n kernel: Bluetooth: hci0: using rampatch file: qca/rampatch_usb_00000302.bin
Nov 12 18:00:13.735115 n kernel: Bluetooth: hci0: QCA: patch rome 0x302 build 0x3e8, firmware rome 0x302 build 0x111
Nov 12 18:00:13.950923 n kernel: ath10k_pci 0000:02:00.0: firmware ver WLAN.TF.2.1-00021-QCARMSWP-1 api 6 features wowlan,ignore-otp crc32 42e41877
Nov 12 18:00:14.108557 n kernel: Bluetooth: hci0: using NVM file: qca/nvm_usb_00000302.bin
Nov 12 18:00:14.136558 n kernel: Bluetooth: hci0: HCI Enhanced Setup Synchronous Connection command is advertised, but not supported.
Nov 12 18:00:19.671631 n kernel: rfkill: input handler disabled
Nov 12 18:00:26.452580 n kernel: Bluetooth: MGMT ver 1.23
Nov 12 18:00:26.479602 n kernel: Bluetooth: RFCOMM ver 1.11
Nov 12 18:03:08.818452 n kernel: rfkill: input handler enabled
Nov 12 18:03:09.849362 n kernel: rfkill: input handler disabled
Nov 12 18:03:10.869409 n kernel: Bluetooth: hci0: command 0x0c24 tx timeout
```

(Lines for other USB devices and the remaining Bluetooth socket-layer start-up lines are left out
of this block; E3 has the failure itself.)

### E6. HCI capture decode, from the last answered command to the index removal

`btmon -T --columns=200 -r hci-20261112-180017.btsnoop`, frames #119 to `Delete Index`. The
capture is the monitor socket, so it shows what the kernel sent to the driver, not what reached
the wire. The A2DP endpoint lines are bluetoothd log lines carried in the capture.

```
< HCI Command: Write Extended Inquiry Response (0x03|0x0052) plen 241        #119 [hci0] 2026-11-12 18:00:26.842657
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
> HCI Event: Command Complete (0x0e) plen 4                                  #120 [hci0] 2026-11-12 18:00:26.845565
      Write Extended Inquiry Response (0x03|0x0052) ncmd 1
        Status: Success (0x00)
@ MGMT Event: Command Complete (0x0001) plen 6                         {0x0001} [hci0] 2026-11-12 18:00:26.845592
      Add UUID (0x0010) plen 3
        Status: Success (0x00)
        Class: 0x6c010c
= bluetoothd: Endpoint unregistered: sender=:1.38 path=/MediaEndpoint/A2DPSource/ldac            2026-11-12 18:03:08.819688
  … 18 more "Endpoint unregistered: sender=:1.38" lines (the greeter's audio session), 18:03:08.820180 to .826166 …
@ MGMT Command: Remove UUID (0x0011) plen 16                           {0x0001} [hci0] 2026-11-12 18:03:08.826934
        UUID: Handsfree Audio Gateway
< HCI Command: Write Class of Device (0x03|0x0024) plen 3                    #121 [hci0] 2026-11-12 18:03:08.827012
        Class: 0x2c010c
= bluetoothd: Endpoint registered: sender=:1.85 path=/MediaEndpoint/A2DPSource/ldac              2026-11-12 18:03:08.924538
  … 18 more "Endpoint registered: sender=:1.85" lines (the user's audio session), to 18:03:08.926597 …
@ MGMT Event: Command Complete (0x0001) plen 6                         {0x0001} [hci0] 2026-11-12 18:03:10.868450
      Remove UUID (0x0011) plen 3
        Status: Authentication Failed (0x05)
        Class: 0x6c010c
= bluetoothd: Failed to remove UUID: Authentication Failed (0x05)                         [hci0] 2026-11-12 18:03:10.868522
@ MGMT Command: Remove UUID (0x0011) plen 16                           {0x0001} [hci0] 2026-11-12 18:03:10.868546
        UUID: Handsfree
@ MGMT Event: Command Complete (0x0001) plen 6                         {0x0001} [hci0] 2026-11-12 18:03:12.916872
      Remove UUID (0x0011) plen 3
        Status: Authentication Failed (0x05)
= bluetoothd: Failed to remove UUID: Authentication Failed (0x05)                         [hci0] 2026-11-12 18:03:12.916972
@ MGMT Command: Remove UUID (0x0011) plen 16                           {0x0001} [hci0] 2026-11-12 18:03:12.917026
        UUID: Audio Sink
@ MGMT Event: Command Complete (0x0001) plen 6                         {0x0001} [hci0] 2026-11-12 18:03:14.964424
      Remove UUID (0x0011) plen 3
        Status: Authentication Failed (0x05)
= bluetoothd: Failed to remove UUID: Authentication Failed (0x05)                         [hci0] 2026-11-12 18:03:14.964474
@ MGMT Command: Remove UUID (0x0011) plen 16                           {0x0001} [hci0] 2026-11-12 18:03:14.964495
        UUID: Audio Source
< HCI Command: Write Class of Device (0x03|0x0024) plen 3                    #122 [hci0] 2026-11-12 18:03:16.180812
        Class: 0x0c010c
@ MGMT Event: Command Complete (0x0001) plen 6                         {0x0001} [hci0] 2026-11-12 18:03:17.012480
      Remove UUID (0x0011) plen 3
        Status: Authentication Failed (0x05)
@ MGMT Command: Add UUID (0x0010) plen 17                              {0x0001} [hci0] 2026-11-12 18:03:17.012608
        UUID: Handsfree Audio Gateway
@ MGMT Event: Command Status (0x0002) plen 3                           {0x0001} [hci0] 2026-11-12 18:03:17.012622
      Add UUID (0x0010)
        Status: Invalid Index (0x11)
  … three more Add UUID → Invalid Index (0x11) …
@ MGMT Event: Class Of Device Changed (0x0007) plen 3                  {0x0001} [hci0] 2026-11-12 18:03:17.021409
        Class: 0x000000
@ MGMT Event: New Settings (0x0006) plen 4                             {0x0001} [hci0] 2026-11-12 18:03:17.021434
        Current settings: 0x00400ac0
= Close Index: <addr>                                                           [hci0] 2026-11-12 18:03:17.021440
@ MGMT Event: Index Removed (0x0005) plen 0                            {0x0001} [hci0] 2026-11-12 18:03:17.021445
= Delete Index: <addr>                                                          [hci0] 2026-11-12 18:03:17.021450
```

(Columns narrowed, and the class-of-device bit lists and repeated endpoint lines condensed as
marked. Nothing else is omitted.)

- No HCI event of any kind arrives after #120.
- Only two commands reach the driver: #121, and #122 after the credit is restored.
- The capture's timestamps run 0.5–1.1 ms earlier than the kernel's printk lines for the same
  sends (#121 18:03:08.827012 against `skb …` at .827513; #122 18:03:16.180812 against
  .181900). We take that to be a clock-source difference, not an ordering.

### E7. bluetoothd and login, the trigger window

`journalctl -b -1 --no-pager -o short-precise --since "2026-11-12 18:03:08" --until "2026-11-12 18:03:18" -t bluetoothd -t "gdm-password]" -t systemd-logind`,
lines matching login, mgmt, failures and adapter removal (the run of `remove_uuid` lines at
18:03:17.02 shortened):

```
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
  … three more Add UUID → Invalid Index …
Nov 12 18:03:17.021423 n bluetoothd[2852]: src/shared/mgmt.c:can_read_data() [0x0000] event 0x0007
Nov 12 18:03:17.021479 n bluetoothd[2852]: src/shared/mgmt.c:can_read_data() [0x0000] event 0x0006
Nov 12 18:03:17.021550 n bluetoothd[2852]: src/shared/mgmt.c:can_read_data() [0x0000] event 0x0005
Nov 12 18:03:17.021558 n bluetoothd[2852]: src/adapter.c:index_removed() index 0
  … nine "remove_uuid() sending remove uuid command for index 0", 18:03:17.022471 to .025320 …
Nov 12 18:03:17.025395 n bluetoothd[2852]: src/adapter.c:adapter_free() 0x64258fee93c0
```

### E8. The boots around it: how they ended, and the next boot

`journalctl -b <boot> --no-pager -o short-precise -t systemd-logind`, lines matching
`will (power off|reboot)|powering down|rebooting`:

Boot `7e87eae0` (before), run as `-b -2`:

```
Nov 12 17:52:26.583655 n systemd-logind[1386]: The system will power off now!
Nov 12 17:52:26.609529 n systemd-logind[1386]: System is powering down.
```

Boot `08956069` (failing), run as `-b -1`:

```
Nov 12 18:07:21.044796 n systemd-logind[1390]: The system will reboot now!
Nov 12 18:07:21.070813 n systemd-logind[1390]: System is rebooting.
```

The next boot `b314ca88`, after the warm reboot:
`journalctl -b 0 _TRANSPORT=kernel --no-pager -o short-precise`, lines matching
`usb 3-3|usb3-port3|Bluetooth: Core|ath10k_pci .*firmware ver`:

```
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

After the power-off (boot `46cc4812`, 22:55, kernel `7.0.0-43`, Ubuntu's own btusb), the
controller enumerated, loaded `patch rome 0x302 build 0x3e8`, and bluetoothd reported one
controller.

### E9. Trial history of the same setup

Our trial log, one row per boot of the patched driver
(`E3`). Only the relevant columns are kept here (`timestamp` = boot end, `duration_s`,
`timeouts`, `usb_present`, `kernel`, `prev_shutdown`, `perturbed`):

```
2026-10-18T17:03:54+02:00  #1  419657 s  timeouts 0  usb yes  7.0.0-38  prev unknown   none
2026-10-23T09:34:50+02:00  #2  300842 s  timeouts 0  usb yes  7.0.0-38  prev unknown   none
2026-10-30T19:52:04+01:00  #3    1752 s  timeouts 0  usb yes  7.0.0-42  prev unknown   none
2026-11-06T15:47:16+01:00  #4   72829 s  timeouts 0  usb yes  7.0.0-42  prev poweroff  none
2026-11-10T16:06:50+01:00  #5   55746 s  timeouts 0  usb yes  7.0.0-42  prev poweroff  none
2026-11-11T10:52:16+01:00  #6   37141 s  timeouts 0  usb yes  7.0.0-42  prev poweroff  none
2026-11-12T15:48:39+01:00  #7   74983 s  timeouts 0  usb yes  7.0.0-42  prev poweroff  none
2026-11-12T17:52:46+01:00  #8    7393 s  timeouts 0  usb yes  7.0.0-42  prev poweroff  none
2026-11-12T18:07:42+01:00  #9     424 s  timeouts 1  usb no   7.0.0-42  prev poweroff  usb_reset
```

- Rows #1–#8 add up to 970,343 s (11.2 days) of patched-driver uptime with no timeout. Then
  this.
- `autosusp=Y` (runtime autosuspend on) in every row.
- How many device-level suspend/resume cycles those boots contain has not been counted yet. E2
  shows 8 in boot #8 alone.

## Our reading of the code

### Path 1 — a command to a suspended device starts a resume, and the resume never finishes

btusb `7.0.0-42`, `drivers/bluetooth/btusb.c`.

`submit_or_queue_tx_urb()`, l.2232–2252: while `BTUSB_SUSPENDING` is set, the URB is parked on
`data->deferred` and the waker is scheduled.

```c
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
```

`btusb_waker()`, l.2478–2487: its error is silent.

```c
	err = usb_autopm_get_interface(data->intf);
	if (err < 0)
		return;

	usb_autopm_put_interface(data->intf);
```

`btusb_resume()`, l.4726: its first statement is `BT_DBG("intf %p", intf);`. That line never
appears after 18:00:28.857 (E1), so **the driver's resume callback was never called**: the
device-level resume did not succeed.

The USB core, mainline v7.0, `drivers/usb/core/hub.c`. `usb_port_resume()` (l.3793) clears the
port's suspend and sleeps `USB_RESUME_TIMEOUT` and then 10 ms. It then calls
`check_port_resume_type()`, then `finish_port_resume()` (l.3631):

```c
	if (udev->reset_resume) {
 retry_reset_resume:
		if (udev->quirks & USB_QUIRK_RESET)
			status = -ENODEV;
		else
			status = usb_reset_and_verify_device(udev);
	}

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
```

- `usb_get_std_status()` → `usb_get_status()` (`message.c:1182`) → `usb_control_msg(…,
  USB_CTRL_GET_TIMEOUT)`, with `USB_CTRL_GET_TIMEOUT` = 5000 ms (`include/linux/usb.h:1934`).
- `usb_reset_and_verify_device()` → `hub_port_init()` prints `reset full-speed USB device
  number 2 using xhci_hcd`.
- On failure `usb_port_resume()` calls `hub_port_logical_disconnect()`, then `USB disconnect`.
- Every intermediate message in this path is `dev_dbg`, which was off.

**Our hypothesis H1:**
1. #121 at 178.731 went to the deferred anchor of a suspended device, and the waker started a
   resume.
2. The controller did not answer the GET_STATUS after resume signalling. The request timed out
   after 5 s.
3. `persist_enabled` = 1, so the core retried as a reset-resume. That is the first reset at
   184.023, **5.291 s** after the send: 5.000 s of timeout plus ≥ 50 ms of resume delays plus
   scheduling.
4. The reset-resume and its retries failed (`-71`, no SET_ADDRESS response, xHCI completion code
   0x11), and the core disconnected the device at 186.083.

H1 also explains why there is no `Resetting usb device.` line: nothing in btusb issued that
reset.

**Not explained by our reading:** about 0.24 s of the 5.291 s. Does the xHCI driver's USB2
port-resume path (`xhci-hub.c`, ClearPortFeature `USB_PORT_FEAT_SUSPEND`) or
`wait_for_connected()` add that, or is there a second wait?

### Path 2 — the HCI timeout's reset blocks for 5.3 s behind the failing resume and then gives up

`net/bluetooth/hci_core.c:1462-1482`, `hci_cmd_timeout()`:

```c
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
```

The device-table entry gives `BTUSB_QCA_ROME`, and probe sets `hdev->reset = btusb_qca_reset`
(`btusb.c:4400-4407`):

```c
	if (id->driver_info & BTUSB_QCA_ROME) {
		data->setup_on_usb = btusb_setup_qca;
		hdev->shutdown = btusb_shutdown_qca;
		hdev->set_bdaddr = btusb_set_bdaddr_ath3012;
		hdev->reset = btusb_qca_reset;
		hci_set_quirk(hdev, HCI_QUIRK_SIMULTANEOUS_DISCOVERY);
		btusb_check_needs_reset_resume(intf);
	}
```

`btusb_qca_reset()` (l.1173–1207) has no reset GPIO here, so it calls `btusb_reset()`
(l.1032–1050):

```c
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
```

Both messages are `bt_dev_err`, so neither depends on debug settings. The only other site that
prints `Failed usb_autopm_get_interface` is `btusb_mtk_reset()` (l.2905), which does not apply.

Runtime PM, mainline v7.0 `drivers/base/power/runtime.c`, `rpm_resume()`, l.911–920. A caller
that finds the device `RPM_RESUMING` waits, and an interface whose parent fails to become active
returns `-EBUSY`:

```c
		if (!parent->power.disable_depth &&
		    !parent->power.ignore_children) {
			rpm_resume(parent, 0);
			if (parent->power.runtime_status != RPM_ACTIVE)
				retval = -EBUSY;
		}
```

**Our hypothesis H2:**
1. At 180.772, `hci_cmd_timeout()` → `btusb_qca_reset()` → `btusb_reset()` →
   `usb_autopm_get_interface()` found the device's resume (H1) already in progress, and waited.
2. When that resume failed, the wait ended with `-EBUSY`: `Failed usb_autopm_get_interface: -16`
   at 186.083044, within 1 µs of the `USB disconnect` line.
3. `hci_cmd_timeout()` was blocked for those 5.311 s, so the command credit was restored only
   then (`cmd_cnt 1 cmd queued 3` at 186.083056). Frame #122 then went to a device that was
   already gone.
4. The two sync commands queued in between timed out unsent (E3, E6).

If H1 and H2 hold, btusb's own reset never ran: the `hdev->reset` path is a bystander here. The
USB core's reset-resume is what reset the controller.

### Path 3 — the remote-wakeup quirk that exists for exactly this symptom, for two MediaTek chips on Ryzen

`btusb_suspend()` (l.4622) and its comment, in the `7.0.0-42` tree:

```c
	/*
	 * It is reported that remote wakeup events could sometimes cause some
	 * adapters completely unresponsive. Resetting the xHCI root hub doesn't
	 * help at all, and recovering from such a state needs a power cycle.
	 * Since disabling remote wakeup simply causes the USB core to gate
	 * runtime autosuspend as well due to needs_remote_wakeup == 1, let's do
	 * this ourselves to make our life easier. The interface can be safely
	 * autosuspended as long as remote wakeup is disabled, i.e., after
	 * closing the HCI device.
	 * …
	 */
	if (PMSG_IS_AUTO(message) &&
	    ((test_bit(BTUSB_WAKEUP_BROKEN, &data->flags) && data->intf->needs_remote_wakeup) ||
	     hci_conn_count(data->hdev) || hci_discovery_active(data->hdev)))
		return -EBUSY;
```

`BTUSB_WAKEUP_BROKEN` is set in one place only, `btusb_mtk_setup()` (l.3022), for MT7922 and
MT7925:

```c
		if (platform_is_ryzen() && is_direct_child_of_root_hub(data->udev))
			set_bit(BTUSB_WAKEUP_BROKEN, &data->flags);
```

Here `platform_is_ryzen()` is `boot_cpu_has(X86_FEATURE_ZEN)`, and
`is_direct_child_of_root_hub()` is `udev->parent == udev->bus->root_hub`. It came in with
mainline `dcaf83ead130` ("Bluetooth: Properly disable remote wakeup for MT7922/MT7925 on Ryzen
platform", Rong Zhang; `Fixes: e31d761628ad` "Bluetooth: btmtk: Disable remote wakeup for
MT7922/MT7925"). We found it in linux-7.2.y as `8691bcc502226`, and it is in Ubuntu's `7.0.0-42`
tree. Its message says:
- "a remote wakeup could cause MT7922/MT7925's btusb interface completely unresponsive.
  Resetting the xHCI root hub doesn't help at all, and recovering from such a state needs a
  power cycle";
- "All reports seen to be relevant to Ryzen-based laptops";
- the quirk is limited to "direct children of Ryzen platforms's root hubs for the time being".

This laptop is a Ryzen (Zen 3, Cezanne). The Bluetooth controller is a direct child of the
SoC's xHCI root hub. It was runtime-suspended with remote wakeup armed (HCI open), and after
the failure neither resets, a port power cycle nor a warm reboot brought it back; only a
power-off did. We saw no remote-wakeup *event*, though: the resume was host-initiated (H1). So
the match is with the symptom and the platform, not with the trigger.

**Our hypothesis H3:** the condition behind `dcaf83ead130` is not specific to MediaTek. It is the
Ryzen root hub together with a remote-wakeup-armed runtime suspend, and QCA9377 (at least
`13d3:3503`) is affected too. If so, the fix belongs in btusb: set `BTUSB_WAKEUP_BROKEN` for this
device (or for QCA ROME) on the same platform condition. That gives the same `-EBUSY` on runtime
suspend while HCI is open. **This is a candidate, not a finding.** One occurrence on one laptop
cannot establish it.

### Path 4 — the older QCA ROME resume history in the same file

`btusb.c:900-927`, and `btusb_check_needs_reset_resume()` (l.3958), which ROME probe calls:

```c
/* The Bluetooth USB module build into some devices needs to be reset on resume,
 * this is a problem with the platform (likely shutting off all power) not with
 * the module itself. So we use a DMI list to match known broken platforms.
 */
static const struct dmi_system_id btusb_needs_reset_resume_table[] = {
	/* Dell OptiPlex 3060 (QCA ROME device 0cf3:e007) */
	/* Dell XPS 9360 (QCA ROME device 0cf3:e300) */
	/* Dell Inspiron 5565 (QCA ROME device 0cf3:e009) */
	…
};

static void btusb_check_needs_reset_resume(struct usb_interface *intf)
{
	if (dmi_check_system(btusb_needs_reset_resume_table))
		interface_to_usbdev(intf)->quirks |= USB_QUIRK_RESET_RESUME;
}
```

This laptop matches none of them (DMI `Default string`).

## The items, in priority order

### 1. Where did the first USB reset come from? (H1)

- Is H1 right: a host-initiated runtime resume (`btusb_waker()` or any `usb_autopm_get_*`),
  whose GET_STATUS in `finish_port_resume()` timed out, retried as a reset-resume?
  - What else, in v7.0 plus Ubuntu's delta, can issue a reset of a runtime-suspended device and
    log `reset full-speed USB device …` with no other message at default log level?
  - Candidates we can name: `hub_wq`'s `port_event()` and `hub_port_connect_change()` paths
    (a port change, a remote-wakeup change, an "EMI" re-enable), and `usb_reset_device()` from
    another caller. Which of them would have printed something at the default level?
- Account for 5.291 s between the send and the first reset. In the xHCI USB2 port-resume path on
  this AMD host, which waits apply, and how long are they?
- Was it a resume at all? Could the controller have signalled a remote wakeup that started the
  resume instead? Would that path print anything at default level?
- What do `device descriptor read/64, error -71`, `Device not responding to setup address`,
  xHCI `completion code 0x11` and `WARN: invalid context state for evaluate context command`
  tell about the device's state? Is any of them a defect of the xHCI driver's error handling
  rather than a consequence?
- Is it plausible that a device which does not answer after resume signalling stays wedged
  through port resets and a port power cycle, but not through a platform power-off? On this
  laptop the M.2 card's Bluetooth power may not follow the root hub port's power.

### 2. The HCI timeout's reset behind a failing resume (H2)

- Confirm or refute H2: `btusb_reset()` waiting in `usb_autopm_get_interface()` for 5.3 s, and
  `-EBUSY` from `rpm_resume()`'s parent check (or another site) once the resume failed.
- `hci_cmd_timeout()` runs on `hdev->workqueue`, and the command credit stays 0 until
  `hdev->reset` returns. Is a blocking reset in this work item intended? What else is stuck
  behind it?
- For QCA ROME without a reset GPIO, is `hdev->reset = btusb_qca_reset` on the **first**
  timeout a good policy? On this laptop, in two controlled tests in 2026-08 (ROM firmware, before
  the device-table entry), a USB reset issued to a controller that had stopped answering drove it
  off the bus in the same way. When was `btusb_qca_reset()` introduced for ROME, and why?
- If the device was not suspended (that is, H1 is wrong), btusb's reset would have logged
  `Resetting usb device.` at 180.772. Is there any path in which `usb_autopm_get_interface()`
  blocks here for another reason?

### 3. Does the Ryzen remote-wakeup quirk apply to this controller? (H3)

- Read `dcaf83ead130` and `e31d761628ad` and the discussion behind them. What exactly was
  observed on MT7922/MT7925: a remote wakeup during runtime suspend, or a host resume? Was the
  Bluetooth device a direct child of an AMD SoC root hub, with which xHCI PCI IDs? Was anything
  ever found on the xHCI side?
- Search for reports of **Qualcomm/Atheros USB Bluetooth (QCA9377, QCA6174, ROME, any
  `BTUSB_QCA_ROME` ID) disappearing after idle or after resume on Ryzen laptops** that only a
  power-off fixes. Also any device on AMD Renoir/Cezanne/Barcelo `1022:1639`. Give the kernel
  versions and whether `enable_autosuspend=0` or `power/control=on` made it go away.
- Are there other drivers or quirks for "remote wakeup during runtime suspend breaks the device
  on AMD root hubs" (USB core quirks, `xhci-pci.c` quirks for AMD, `usb_quirk_list`)?
- If the quirk should cover more devices: per device ID, all of `BTUSB_QCA_ROME`, or all btusb
  devices on Ryzen root hubs? Is there a way to tell that the root hub is on the SoC (the commit
  calls it "too intrusive")? What would maintainers accept?
- The older QCA ROME resume history (Path 4): which commits added and later narrowed the
  reset-on-resume handling for ROME, and what failed when it applied to all ROME devices? Does
  any of it bear on runtime resume, as opposed to system resume?

### 4. The controller side

- Does btqca/btusb's QCA setup (`btusb_setup_qca()`, rampatch and NVM download) configure any
  controller-side low-power, sleep or USB-suspend behaviour, for example an NVM tag for deep
  sleep or remote wakeup? Could the patched firmware's handling of USB suspend differ from the
  ROM firmware's? Before the device-table entry, runtime autosuspend applied to the ROM firmware
  as well.
- Is there any software path to recover a QCA ROME USB controller in this state without a power
  cycle: a vendor command, a Wi-Fi-side (`ath10k`) reset of the combo card, an ACPI method?

### 5. Smaller items seen on the way

- **A misleading MGMT status.** The kernel answered the timed-out `Remove UUID` with
  `Authentication Failed (0x05)` four times (E6, E7). `net/bluetooth/mgmt.c:286-310`,
  `mgmt_errno_status()`:

  ```c
  	case -ETIMEDOUT:
  		return MGMT_STATUS_AUTH_FAILED;
  ```

  When and why was `-ETIMEDOUT` mapped to `AUTH_FAILED`, and is `MGMT_STATUS_TIMEOUT` or
  `MGMT_STATUS_FAILED` meant for a command timeout? Is the mapping still there on mainline?
- **A queued command sent to a gone device** (#122 at 186.083, after the credit was restored):
  harmless, or worth a check in `hci_cmd_timeout()`?

### 6. Anything else

Anything else in this path that the code shows and we have not named.

## What we would like back

1. **Per item:**
   - the participating code (tree, version or commit, file, function, line), read in the
     versions that ran;
   - your reading, how sure you are, and its falsifier;
   - the introducing commit and its reason, and any later change on mainline;
   - other people's reports of the same failure;
   - where a fix belongs;
   - the experiment you would run first.
2. **Items 1 and 2:** a yes or no on H1 and H2, with the code lines that decide it.
3. **Item 3:** your judgment of H3, the reports you found, and what a quirk patch would have to
   show to be accepted.
4. **Experiments,** within the constraints below. Candidates we see:
   - turning on `dev_dbg` for `drivers/usb/core/hub.c` and `driver.c` (and xHCI trace events)
     on the running system, so a recurrence shows `retry with reset-resume` and `gone after usb
     resume? status …`;
   - counting device suspend/resume cycles across all earlier boots, to get a failure rate;
   - an A/B over several weeks, with `power/control` set to `on` for `3-3`, or `btusb
     enable_autosuspend=0`;
   - reproducing on a QEMU guest or another machine is unlikely to help here: tell us if you
     disagree.
5. **Anything else** the code shows that we have not listed.

## Constraints

- The laptop is in daily use. A dead controller needs a full power-off to recover. Experiments
  on it are short, or passive (logging only).
- Do not propose unloading, reloading or rebinding `btusb` or `bluetooth.ko` on the running
  system. On this laptop a reload has killed even a healthy controller, and recovery needed a
  power-off.
- Do not propose issuing USB resets or port power cycles to the controller on purpose.
- The laptop now runs Ubuntu `7.0.0-43` with Ubuntu's own btusb, which carries the same
  device-table entry, so the same conditions apply. The same dynamic debug is on.
- Nothing is sent upstream on the strength of a review alone. Each finding is checked against the
  source and our logs first.
