# EX-055 — e1-qca-setup-loads-rampatch-over-rom-firmware

**Claim.** With the E1 diagnostic btusb (0.8-e1: QCA ROME setup for 13d3:3503, no reset callback), boot 226965f1 on 7.0.0-34: before setup the controller runs ROM 0x302 at build 0x111 with status 0x20 (no rampatch, no NVM); btusb_setup_qca() loads qca/rampatch_usb_00000302.bin (build 0x3e8) and qca/nvm_usb_00000302.bin, both returning 0, and the second open finds status 0xe0, patch 0x3e8. The patched controller then advertises 202 supported commands including Enhanced Setup and Enhanced Accept Synchronous Connection. On the stock driver it advertised 197 without them in 149 of the 159 replies surveyed across retained captures, 200 with them in 6 (08-14 to 08-19 only), and nothing in 4 on a dead controller (scripts/supported-commands-survey.sh, 2026-09-26).

**Relevance.** All twelve alt-1 deaths ran on the stock driver, which has no entry for this ID and so never runs the QCA setup: the controller that died was running its unpatched ROM firmware. This is the variable E1 changes; whether it cures the wedge is decided only by a wideband SCO call on this build.

## Extraction method

Re-runnable as-is on the affected machine:

```console
$ uname -r; cat /sys/module/btusb/version /sys/module/btusb/srcversion; echo; journalctl -k -b 226965f1219c426a950d71e6845deb6d --no-pager -o short-iso-precise --grep 'E1:|QCA: patch|using rampatch|using NVM'; echo; COLUMNS=160 btmon -r /var/log/bt-health/capture/hci-20260926-171117.btsnoop 2>/dev/null | grep -m 4 -E 'Read Local Supported Commands \(0x04\|0x0002\) ncmd|Commands: [0-9]+ entr|Enhanced Setup Synchronous|Enhanced Accept Synchronous'
```

## Output

Verbatim, 21 line(s), exit status 0.

```
7.0.0-34-generic
0.8-e1
0FF3E900DE4D28718D8573F

2026-09-26T17:11:14.584458+02:00 n kernel: Bluetooth: (null): E1: 13d3:3503 QCA ROME setup, no reset callback
2026-09-26T17:11:14.588399+02:00 n kernel: Bluetooth: hci0: E1: before setup: rom 0x00000302 patch 0x00000111 ram 0x00000000
2026-09-26T17:11:14.592400+02:00 n kernel: Bluetooth: hci0: E1: status 0x20: rampatch will load, nvm will load
2026-09-26T17:11:14.594398+02:00 n kernel: Bluetooth: hci0: using rampatch file: qca/rampatch_usb_00000302.bin
2026-09-26T17:11:14.594432+02:00 n kernel: Bluetooth: hci0: QCA: patch rome 0x302 build 0x3e8, firmware rome 0x302 build 0x111
2026-09-26T17:11:14.690395+02:00 n kernel: Bluetooth: hci0: E1: rampatch load returned 0
2026-09-26T17:11:14.967418+02:00 n kernel: Bluetooth: hci0: E1: after rampatch: rom 0x00000302 patch 0x000003e8
2026-09-26T17:11:14.968417+02:00 n kernel: Bluetooth: hci0: using NVM file: qca/nvm_usb_00000302.bin
2026-09-26T17:11:14.996421+02:00 n kernel: Bluetooth: hci0: E1: nvm load returned 0
2026-09-26T17:11:25.877395+02:00 n kernel: Bluetooth: hci0: E1: before setup: rom 0x00000302 patch 0x000003e8 ram 0x00000000
2026-09-26T17:11:25.881418+02:00 n kernel: Bluetooth: hci0: E1: status 0xe0: rampatch already present, nvm already present
2026-09-26T17:11:25.885401+02:00 n kernel: Bluetooth: hci0: E1: after rampatch: rom 0x00000302 patch 0x000003e8

      Read Local Supported Commands (0x04|0x0002) ncmd 1
        Commands: 202 entries
          Enhanced Setup Synchronous Connection (Octet 29 - Bit 3)
          Enhanced Accept Synchronous Connection Request (Octet 29 - Bit 4)
```

**Evidence window.** `2026-09-26T17:11:14.584458+02:00` — `2026-09-26T17:11:25.877395+02:00`

## Provenance

| field | value |
|---|---|
| captured | `2026-09-26T21:45:41+02:00` |
| kernel | `7.0.0-34-generic` |
| boot id | `226965f1` |
| device | `13d3:3503` QCA9377 (ROME) |
| exit status | `0` |
| redacted | `no` |
