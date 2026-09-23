# EX-046 — btusb-reload-on-healthy-controller-hci-reset-timeout

**Claim.** Unloading and re-probing btusb on a HEALTHY controller (stock module, original configuration, 22 min after a clean cold boot) is itself fatal: the first HCI command of the re-probe, Reset 0x0c03, times out (-110) and the adapter registers as hci0 with an all-zero address, DOWN; every later re-probe (01:19:30, 01:19:58) times out the same way. No SCO, no alt-1 traffic involved. tools/bt-window does not see this state (it keys on the tx-timeout line, which this path does not print).

**Relevance.** This was the module-swap step of the kernel-patch runtime test, not a BT-1 reproduction: it shows that on this part a driver reload without a firmware setup path (no BTUSB_QCA_ROME on 7.0.0-31) can wedge a working controller on its own, which bears on why every reset/rebind recovery in the record failed, and it means the runtime test cannot swap bluetooth.ko on a live system.

## Extraction method

Re-runnable as-is on the affected machine:

```console
$ journalctl -k --since "2026-09-23 01:16:00" --until "2026-09-23 01:21:00" --no-pager -o short-precise -g "registered new interface driver btusb|deregistering interface driver btusb|Opcode 0x0c03|end: err|Bluetooth: hci0"; echo; hciconfig -a; echo; tools/bt-mode status 2>&1 | sed -n "3,6p"
```

## Output

Verbatim, 40 line(s), exit status 0.

> **Redaction notice.** MAC addresses, BSSIDs, UUIDs and IPv4
> addresses were replaced with stable placeholders
> (`AA:BB:CC:00:00:NN`, `<UUID-NN>`, `<IPV4-NN>`) before publication.
> The same real value always maps to the same placeholder, so
> cross-references within the output remain readable. Nothing
> else was altered. Re-running the command locally will show the
> real addresses in these positions.

```
Sep 23 01:16:09.343611 n kernel: hci0: end: err 0
Sep 23 01:16:09.346756 n kernel: hci0: end: err 0
Sep 23 01:16:09.348590 n kernel: Bluetooth: hci0: unexpected event for opcode 0x2005
Sep 23 01:16:09.350646 n kernel: hci0: end: err 0
Sep 23 01:16:09.353611 n kernel: hci0: end: err 0
Sep 23 01:16:20.095667 n kernel: hci0: end: err 0
Sep 23 01:16:20.098630 n kernel: hci0: end: err 0
Sep 23 01:16:20.098739 n kernel: Bluetooth: hci0: unexpected event for opcode 0x2005
Sep 23 01:16:20.101618 n kernel: hci0: end: err 0
Sep 23 01:16:20.104612 n kernel: hci0: end: err 0
Sep 23 01:16:30.848589 n kernel: hci0: end: err 0
Sep 23 01:16:30.851609 n kernel: hci0: end: err 0
Sep 23 01:16:30.853586 n kernel: Bluetooth: hci0: unexpected event for opcode 0x2005
Sep 23 01:16:30.855583 n kernel: hci0: end: err 0
Sep 23 01:16:30.858581 n kernel: hci0: end: err 0
Sep 23 01:16:34.721983 n kernel: usbcore: deregistering interface driver btusb
Sep 23 01:17:06.549777 n kernel: usbcore: registered new interface driver btusb
Sep 23 01:17:06.549856 n kernel: hci0: Opcode 0x0c03
Sep 23 01:17:08.604571 n kernel: hci0: end: err -110
Sep 23 01:17:08.604701 n kernel: Bluetooth: hci0: Opcode 0x0c03 failed: -110
Sep 23 01:19:29.851548 n kernel: usbcore: deregistering interface driver btusb
Sep 23 01:19:30.158713 n kernel: usbcore: registered new interface driver btusb
Sep 23 01:19:30.158772 n kernel: hci0: Opcode 0x0c03
Sep 23 01:19:32.220542 n kernel: hci0: end: err -110
Sep 23 01:19:32.220627 n kernel: Bluetooth: hci0: Opcode 0x0c03 failed: -110
Sep 23 01:19:58.615555 n kernel: usbcore: deregistering interface driver btusb
Sep 23 01:19:58.931531 n kernel: usbcore: registered new interface driver btusb
Sep 23 01:20:00.956599 n kernel: Bluetooth: hci0: Opcode 0x0c03 failed: -110

hci0:	Type: Primary  Bus: USB
	BD Address: AA:BB:CC:00:00:01  ACL MTU: 0:0  SCO MTU: 0:0
	DOWN 
	RX bytes:0 acl:0 sco:0 events:0 errors:0
	TX bytes:3 acl:0 sco:0 commands:1 errors:0
	Features: 0x00 0x00 0x00 0x00 0x00 0x00 0x00 0x00
	Packet type: DM1 DH1 HV1 
	Link policy: 
	Link mode: PERIPHERAL ACCEPT 


```

**Evidence window.** not placeable — this output carries no timestamp with a UTC offset. Re-run the extraction with `-o short-iso-precise` if the window matters.

## Provenance

| field | value |
|---|---|
| captured | `2026-09-23T01:22:27+02:00` |
| kernel | `7.0.0-31-generic` |
| boot id | `eb117101` |
| device | `13d3:3503` QCA9377 (ROME) |
| exit status | `0` |
| redacted | `yes` |
