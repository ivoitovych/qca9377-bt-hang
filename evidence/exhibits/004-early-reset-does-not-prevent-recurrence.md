# EX-004 — early-reset-does-not-prevent-recurrence

**Claim.** A USB-level reset applied 133 s BEFORE any HCI command timeout re-enumerated the controller and brought the HCI stack back up 315 ms later. HCI non-response appeared 132 s afterward; a later watchdog intervention was then followed by USB errors and device disappearance.

**Relevance.** The first direct measurement of an early reset. It establishes only the observed sequence: the controller answered after intervention and later stopped answering HCI. It is compatible with non-durable recovery, with unrelated recurrence, or with reset altering the later trajectory. The record cannot distinguish those readings because the intervention destroyed the untreated counterfactual.

**⚠️ What this exhibit does NOT establish.** It does not test the fix, prove BT-1 was imminent when the early reset fired, or show that later USB disappearance belongs to untreated BT-1. `hdev->reset` fires at **+0 s**, while this reset landed 133 s earlier. A reset at +0 s remains untested and must be scored for possible benefit or harm. An earlier version claimed that "a reset callback alone would not have prevented this hang"; that inference is withdrawn.

The mechanism proxy is nevertheless sound, and is why this measurement is worth keeping. From v7.0 source: `hci_cmd_timeout()` calls `hdev->reset(hdev)`; for `BTUSB_QCA_ROME` that is `btusb_qca_reset()`, which with no `bt_en` GPIO falls through to `btusb_reset()` → `usb_queue_reset_device(data->intf)`. `btusb_driver` declares no `.pre_reset` or `.post_reset`, so USB core unbinds and rebinds the interface around the reset — matching the observed stack disappearance and re-registration. The watchdog therefore performed the same *kind* of reset the fix would perform, at a different *time*.

## Extraction method

Re-runnable as-is on the affected machine:

```console
$ ./tools/bt-actions --since '2026-08-12 00:09:20' --until '2026-08-12 00:14:30'
```

## Output

Verbatim, 72 line(s), exit status 0.

```
Reconstructed action timeline — boot 0
USER = operator action   STACK = BlueZ/PipeWire   CTRL = controller   WDOG = watchdog
──────────────────────────────────────────────────────────────────────────────────────
00:09:25.453  USER   opened the Bluetooth settings panel
00:09:31.353  CTRL   HCI desync: unexpected event for opcode 0x2005
00:09:36.123  STACK  HFP (hands-free) connect REFUSED by remote (111)
00:09:36.275  STACK  A2DP/AVDTP connect REFUSED by remote (111)
00:09:36.288  CTRL   HCI desync: unexpected event for opcode 0x2005
00:09:36.576  STACK  A2DP/AVDTP connect REFUSED by remote (111)
00:09:36.576  WDOG   EARLY intervention — reset BEFORE any HCI timeout
00:09:36.582  STACK  bluetoothd terminating
00:09:36.676  STACK  bluetoothd STARTED
00:09:36.963  CTRL   HCI desync: unexpected event for opcode 0x2005
00:09:37.778  CTRL   USB port reset performed
00:09:37.919  WDOG     USBDEVFS_RESET issued
00:09:38.093  CTRL   HCI stack re-registered (MGMT up)
00:09:38.200  CTRL   HCI desync: unexpected event for opcode 0x2005
00:09:46.975  WDOG     RECOVERED — controller answers again
00:09:53.355  CTRL   HCI desync: unexpected event for opcode 0x2005
                          x9 until 00:11:47.351, every ~14.2s
00:11:50.236  CTRL   HCI COMMAND TIMEOUT (opcode unknown)
                          x2 until 00:11:50.576 (burst, 0.34s apart)
00:12:09.180  CTRL   HCI COMMAND TIMEOUT 0x0406
                          x4 until 00:12:11.576 (burst, 0.80s apart)
00:12:14.350  STACK  A2DP/AVDTP Start TIMED OUT (110) — stream never began
00:12:14.351  STACK  audio transport ACQUIRE failed — sink cannot open
00:12:14.351  STACK  audio sink died (running -> error)
00:12:14.351  STACK  Bluetooth audio transport FAILED
00:12:14.351  STACK  audio sink died (running -> error)
00:12:14.430  CTRL   USB setting interface FAILED
                          x2 until 00:12:14.827 (burst, 0.40s apart)
00:12:16.347  STACK  A2DP/AVDTP Abort TIMED OUT (110) — controller not answering
                          x2 until 00:12:16.826 (burst, 0.48s apart)
00:12:18.396  CTRL   HCI COMMAND TIMEOUT 0x0406
                          x2 until 00:12:18.827 (burst, 0.43s apart)
00:12:36.635  STACK  adapter mode change REJECTED — authentication failed (0x05)
00:12:36.636  CTRL   HCI COMMAND TIMEOUT 0x0406
00:12:36.636  CTRL   opcode 0x0c3a failed -110 (timeout)
00:12:37.077  CTRL   HCI COMMAND TIMEOUT 0x0406
00:12:37.077  WDOG   threshold intervention — reset AFTER timeouts
00:12:37.083  STACK  bluetoothd terminating
00:12:38.684  CTRL   HCI COMMAND TIMEOUT 0x0406
00:12:38.684  CTRL   opcode 0x2005 failed -110 (timeout)
00:12:40.732  CTRL   HCI COMMAND TIMEOUT 0x0406
00:12:40.732  CTRL   opcode 0x200b failed -110 (timeout)
00:12:42.779  STACK  adapter mode change REJECTED — authentication failed (0x05)
00:12:42.780  CTRL   HCI COMMAND TIMEOUT 0x0406
00:12:42.780  CTRL   opcode 0x0c1a failed -110 (timeout)
00:12:44.828  CTRL   HCI COMMAND TIMEOUT 0x0406
00:12:44.828  CTRL   opcode 0x0c1a failed -110 (timeout)
00:12:44.828  CTRL   rfkill power-off FAILED (-110)
00:12:44.831  STACK  profile teardown: no matching connection
00:12:44.915  STACK  bluetoothd STARTED
00:12:44.927  STACK  adapter mode change FAILED (0x03)
00:12:51.407  CTRL   USB port reset performed
00:13:06.764  CTRL   USB descriptor read FAILED — device not answering USB core
                          x2 until 00:13:22.636, every ~15.9s
00:13:22.852  CTRL   USB port reset performed
00:13:38.508  CTRL   USB descriptor read FAILED — device not answering USB core
                          x2 until 00:13:54.380, every ~15.9s
00:13:54.596  CTRL   USB port reset performed
00:13:59.900  CTRL   xHCI setup device command TIMEOUT
                          x2 until 00:14:05.532, every ~5.6s
00:14:05.740  CTRL   USB device NOT ACCEPTING ADDRESS
00:14:05.852  CTRL   USB port reset performed
00:14:11.164  CTRL   xHCI setup device command TIMEOUT
                          x2 until 00:14:16.796, every ~5.6s
00:14:17.004  CTRL   USB device NOT ACCEPTING ADDRESS
00:14:17.007  CTRL   *** DEVICE LEFT THE USB BUS ***
00:14:17.084  WDOG     USBDEVFS_RESET FAILED
00:14:17.119  CTRL   USB re-enumeration attempt
00:14:23.088  WDOG     escalating to USB unbind/bind
```

## Provenance

| field | value |
|---|---|
| captured | `2026-08-12T00:44:06+02:00` |
| kernel | `7.0.0-28-generic` |
| boot id | `5641d159` |
| device | `13d3:3503` QCA9377 (ROME) |
| exit status | `0` |
| redacted | `no` |
