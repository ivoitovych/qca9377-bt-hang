# EX-048 — rfkill-cycle-on-wedged-controller-usb-loss

**Claim.** Operator rfkill (airplane mode) cycle 37 min into the EX-047 untreated window: the rfkill power-off itself failed (Write Scan Enable 0x0c1a timed out, 'Error when powering off device on rfkill (-110)'); on unblock the kernel reset the USB device twice (04:02:14, 04:02:45) and the device descriptor read failed with -110 in between; the device is left enumerated as number 000 with hci0 DOWN. No Start Discovery was pending at the power-off (the last one completed at 03:25:45 with status 0x05), so no pending management command was flushed.

**Relevance.** USB loss again follows an intervention, never the untreated fault alone (BT-1 stage 2 remains unestablished as an untreated trajectory). And an rfkill cycle on a wedged controller does not by itself leave a discovery pending: it needs one in flight at that moment.

## Extraction method

Re-runnable as-is on the affected machine:

```console
$ journalctl -b --since "2026-09-24 03:25:30" --until "2026-09-24 04:03:00" --no-pager -o short-precise -g "rfkill|start_discovery_complete|Opcode 0x0c1a|Error when powering off|usb 3-3|tx timeout"; echo; lsusb -d 13d3:3503; echo; hciconfig hci0 | head -3
```

## Output

Verbatim, 33 line(s), exit status 0.

> **Redaction notice.** MAC addresses, BSSIDs, UUIDs and IPv4
> addresses were replaced with stable placeholders
> (`AA:BB:CC:00:00:NN`, `<UUID-NN>`, `<IPV4-NN>`) before publication.
> The same real value always maps to the same placeholder, so
> cross-references within the output remain readable. Nothing
> else was altered. Re-running the command locally will show the
> real addresses in these positions.

```
Sep 24 03:25:41.503435 n kernel: Bluetooth: hci0: command 0x0406 tx timeout
Sep 24 03:25:43.551460 n kernel: Bluetooth: hci0: command 0x0406 tx timeout
Sep 24 03:25:45.598601 n bluetoothd[2745]: src/adapter.c:start_discovery_complete() status 0x05
Sep 24 03:25:45.599650 n kernel: Bluetooth: hci0: command 0x0406 tx timeout
Sep 24 04:02:03.204623 n kernel: hci0: Opcode 0x0c1a
Sep 24 04:02:05.247457 n kernel: Bluetooth: hci0: command 0x0406 tx timeout
Sep 24 04:02:05.247674 n kernel: Bluetooth: hci0: Opcode 0x0c1a failed: -110
Sep 24 04:02:05.247734 n kernel: Bluetooth: hci0: Error when powering off device on rfkill (-110)
Sep 24 04:02:05.281565 n bluetoothd[2745]: src/rfkill.c:rfkill_event() RFKILL event idx 0 type 2 op 2 soft 1 hard 0
Sep 24 04:02:05.281644 n bluetoothd[2745]: src/rfkill.c:rfkill_event() RFKILL unblock for hci0
Sep 24 04:02:05.284391 n NetworkManager[1263]: <info>  [1790215325.2843] manager: rfkill: Wi-Fi now disabled by radio killswitch
Sep 24 04:02:05.293697 n systemd[1]: Starting systemd-rfkill.service - Load/Save RF Kill Switch Status...
Sep 24 04:02:05.297435 n systemd[1]: Started systemd-rfkill.service - Load/Save RF Kill Switch Status.
Sep 24 04:02:05.372532 n bluetoothd[2745]: src/rfkill.c:rfkill_event() RFKILL event idx 1 type 1 op 2 soft 1 hard 0
Sep 24 04:02:05.374328 n wpa_supplicant[1264]: rfkill: WLAN soft blocked
Sep 24 04:02:05.374342 n wpa_supplicant[1264]: rfkill: WLAN soft blocked
Sep 24 04:02:05.408781 n NetworkManager[1263]: <info>  [1790215325.4087] manager: rfkill: WWAN hardware radio set disabled
Sep 24 04:02:08.691920 n bluetoothd[2745]: src/rfkill.c:rfkill_event() RFKILL event idx 0 type 2 op 2 soft 0 hard 0
Sep 24 04:02:08.692011 n bluetoothd[2745]: src/rfkill.c:rfkill_event() RFKILL unblock for hci0
Sep 24 04:02:08.692148 n bluetoothd[2745]: src/rfkill.c:rfkill_event() RFKILL event idx 1 type 1 op 2 soft 0 hard 0
Sep 24 04:02:08.701256 n NetworkManager[1263]: <info>  [1790215328.7012] manager: rfkill: WWAN hardware radio set enabled
Sep 24 04:02:08.701699 n NetworkManager[1263]: <info>  [1790215328.7016] manager: rfkill: Wi-Fi now enabled by radio killswitch
Sep 24 04:02:13.700118 n systemd[1]: systemd-rfkill.service: Deactivated successfully.
Sep 24 04:02:14.256434 n kernel: usb 3-3: reset full-speed USB device number 2 using xhci_hcd
Sep 24 04:02:29.615525 n kernel: usb 3-3: device descriptor read/64, error -110
Sep 24 04:02:45.488457 n kernel: usb 3-3: device descriptor read/64, error -110
Sep 24 04:02:45.703469 n kernel: usb 3-3: reset full-speed USB device number 2 using xhci_hcd

Bus 003 Device 000: ID 13d3:3503 IMC Networks 

hci0:	Type: Primary  Bus: USB
	BD Address: AA:BB:CC:00:00:01  ACL MTU: 1024:8  SCO MTU: 50:8
	DOWN 
```

**Evidence window.** not placeable — this output carries no timestamp with a UTC offset. Re-run the extraction with `-o short-iso-precise` if the window matters.

## Provenance

| field | value |
|---|---|
| captured | `2026-09-24T04:03:10+02:00` |
| kernel | `7.0.0-31-generic` |
| boot id | `20fbb9a2` |
| device | `13d3:3503` QCA9377 (ROME) |
| exit status | `0` |
| redacted | `yes` |
