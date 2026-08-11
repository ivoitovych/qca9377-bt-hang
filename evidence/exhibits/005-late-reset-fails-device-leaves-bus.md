# EX-005 — late-reset-fails-device-leaves-bus

**Claim.** Once HCI command timeouts have begun, no software recovery succeeds: USBDEVFS_RESET fails, USB unbind/bind fails, and the device leaves the USB bus entirely, after which only a cold power-off restores it.

**Relevance.** Establishes the recovery deadline. The reset must land inside the window between the first HCI timeout and the first USB-level failure; after that the controller stops answering the USB core itself and no amount of re-enumeration helps. A warm reboot does not recover it because it does not drop the M.2 power rail.

## Extraction method

Re-runnable as-is on the affected machine:

```console
$ journalctl -u bt-hang-watchdog -b 0 --no-pager -o short-iso-precise | grep -E 'intervening|Recovering|USBDEVFS|escalating|RECOVERED|RECOVERY FAILED'; echo '--- kernel side ---'; journalctl -k -b 0 --no-pager -o short-iso-precise | grep -E 'descriptor read|not accepting address|USB disconnect' | head -12
```

## Output

Verbatim, 21 line(s), exit status 0.

```
2026-08-12T00:09:36.578415+02:00 n bt-hang-watchdog[1241]: Recovering Bluetooth controller at 3-3 ...
2026-08-12T00:09:37.919154+02:00 n bt-hang-watchdog[1241]:   USBDEVFS_RESET issued
2026-08-12T00:09:46.975624+02:00 n bt-hang-watchdog[1241]:   RECOVERED — controller is responding again
2026-08-12T00:12:37.077604+02:00 n bt-hang-watchdog[1241]: Detected 6 controller timeouts within 60s — intervening.
2026-08-12T00:12:37.079098+02:00 n bt-hang-watchdog[1241]: Recovering Bluetooth controller at 3-3 ...
2026-08-12T00:14:17.084590+02:00 n bt-hang-watchdog[1241]:   USBDEVFS_RESET failed
2026-08-12T00:14:23.088140+02:00 n bt-hang-watchdog[1241]:   escalating to USB unbind/bind
2026-08-12T00:14:35.100641+02:00 n bt-hang-watchdog[1241]:   RECOVERY FAILED — controller still unresponsive
--- kernel side ---
2026-08-12T00:13:06.764322+02:00 n kernel: usb 3-3: device descriptor read/64, error -110
2026-08-12T00:13:22.636330+02:00 n kernel: usb 3-3: device descriptor read/64, error -110
2026-08-12T00:13:38.508323+02:00 n kernel: usb 3-3: device descriptor read/64, error -110
2026-08-12T00:13:54.380289+02:00 n kernel: usb 3-3: device descriptor read/64, error -110
2026-08-12T00:14:05.740318+02:00 n kernel: usb 3-3: device not accepting address 2, error -62
2026-08-12T00:14:17.004274+02:00 n kernel: usb 3-3: device not accepting address 2, error -62
2026-08-12T00:14:17.007271+02:00 n kernel: usb 3-3: USB disconnect, device number 2
2026-08-12T00:14:32.780325+02:00 n kernel: usb 3-3: device descriptor read/64, error -110
2026-08-12T00:14:48.652322+02:00 n kernel: usb 3-3: device descriptor read/64, error -110
2026-08-12T00:15:04.524304+02:00 n kernel: usb 3-3: device descriptor read/64, error -110
2026-08-12T00:15:20.396300+02:00 n kernel: usb 3-3: device descriptor read/64, error -110
2026-08-12T00:15:31.756335+02:00 n kernel: usb 3-3: device not accepting address 6, error -62
```

## Provenance

| field | value |
|---|---|
| captured | `2026-08-12T00:44:14+02:00` |
| kernel | `7.0.0-28-generic` |
| boot id | `5641d159` |
| device | `13d3:3503` QCA9377 (ROME) |
| exit status | `0` |
| redacted | `no` |
