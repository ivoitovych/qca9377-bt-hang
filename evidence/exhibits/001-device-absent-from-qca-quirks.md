# EX-001 — device-absent-from-qca-quirks

**Claim.** USB ID 13d3:3503 is matched by no entry in the btusb quirks table, so it receives neither the QCA firmware setup path nor a hdev->reset callback, while its immediate ID neighbours 3491/3496/3501 do.

**Relevance.** This is the defect being reported. Without BTUSB_QCA_ROME the device never runs btusb_setup_qca(), so no rampatch or NVM firmware is downloaded, and hdev->reset is left NULL so hci_cmd_timeout() has no recovery action to invoke.

## Extraction method

Re-runnable as-is on the affected machine:

```console
$ /usr/local/bin/bt-verify-kernel-mechanism
```

## Output

Verbatim, 33 line(s), exit status 0.

```
btusb reset mechanism — kernel 7.0.0-28-generic
─────────────────────────────────────────────────────────────
  module: /lib/modules/7.0.0-28-generic/kernel/drivers/bluetooth/btusb.ko (180737 bytes uncompressed)

1. Which QCA reset symbol is present?
  ✓ btusb_qca_cmd_timeout  absent
  ✓ btusb_qca_reset        PRESENT  (hdev->reset path)

  => hdev->reset mechanism. hci_cmd_timeout() calls it on the
     FIRST command timeout — no 5-timeout threshold.
     A userspace reset issued seconds later is NOT an equivalent test.

2. Supporting strings
  ✓ Resetting usb device
  ✓ rampatch
  ✓ nvm_usb
  ✓ using rampatch file
  ✓ btqca.ko present as a separate module (expected)

3. IMC Networks (13d3) device IDs in this binary
  usb_device_id is little-endian: 13d3:XXYY -> bytes d3 13 YY XX
  Vendor classification is from upstream v7.0 btusb.c, NOT inferred from the binary:
  ✓ 13d3:3491  present   BTUSB_QCA_ROME | BTUSB_WIDEBAND_SPEECH
  ✓ 13d3:3496  present   BTUSB_QCA_ROME | BTUSB_WIDEBAND_SPEECH
  ✓ 13d3:3501  present   BTUSB_QCA_ROME | BTUSB_WIDEBAND_SPEECH
  ✗ 13d3:3502  ABSENT    not in upstream
  ✗ 13d3:3503  ABSENT    not in upstream  <-- THIS DEVICE
  ✗ 13d3:3504  ABSENT    not in upstream
  ✓ 13d3:3563  present   BTUSB_MEDIATEK — different silicon, NOT a QCA comparator

  3491/3496/3501 are genuine QCA ROME comparators. 3563 is MediaTek: 13d3 is
  IMC Networks, an ODM shipping modules built around several vendors' silicon,
  so numerical proximity alone proves nothing about a device's family.
```

## Provenance

| field | value |
|---|---|
| captured | `2026-08-12T00:42:51+02:00` |
| kernel | `7.0.0-28-generic` |
| boot id | `5641d159` |
| device | `13d3:3503` QCA9377 (ROME) |
| exit status | `0` |
| redacted | `no` |
