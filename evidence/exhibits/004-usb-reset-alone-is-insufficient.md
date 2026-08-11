# EX-004 — usb-reset-alone-is-insufficient

**Claim.** A USB-level reset applied BEFORE any HCI command timeout does re-enumerate the controller and bring the HCI stack back up, but does not clear the controller's fault: the same desync recurs 107 ms later and the controller hangs completely 132 s afterwards.

**Relevance.** This is the first direct measurement of an EARLY reset, previously untested. It matters because btusb_qca_reset() falls back to usb_queue_reset_device() when no bt_en GPIO is present, which is the same class of operation performed here. The measurement therefore indicates that adding a reset callback alone would not have prevented this hang, and isolates the untested remaining variable: re-running btusb_setup_qca() to redownload rampatch and NVM firmware on re-enumeration, which a device outside the quirks table never does.

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
