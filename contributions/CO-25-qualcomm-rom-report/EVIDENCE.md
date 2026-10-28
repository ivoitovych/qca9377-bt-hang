# QCA9377 13d3:3503 on ROM firmware: evidence for the report

Each exhibit gives the claim, the exact command that extracted it, and that command's
output. The exhibits were captured on the laptop as each event happened; the journals and
captures they were cut from are not all retained.

## The failure on the ROM firmware (stock btusb, no entry for 13d3:3503)

| exhibit | what it shows |
|---|---|
| [EX-053](../../evidence/exhibits/053-alt1-death-12-third-headset-shure-aonic-50.md) | The instance quoted in the report: `0x0428` answered, link up on alt 1 (`bAlternateSetting 1`, `wMaxPacketSize 0009`, read live), 7.3 s of 27-byte mSBC as three 9-byte packets, then `0x0406 Disconnect` never answered |
| [EX-054](../../evidence/exhibits/054-alt1-death-12-untreated-12h-usb-silent.md) | The same failure left alone for 12 h 34 min: still enumerated, nothing from the USB layer, every later command timed out |
| [EX-052](../../evidence/exhibits/052-alt1-death-11-first-on-kernel-7-0-0-34.md) | Two USB `GET_DESCRIPTOR` control transfers timing out (`-110`) after the HCI timeout |
| [EX-043](../../evidence/exhibits/043-first-command-into-alt1-stream-dies.md) | The stream running 9.65 s with no command in flight; the first command then issued dies |
| [EX-051](../../evidence/exhibits/051-alt1-death-10-write-scan-enable-into-alt1-stream.md) | The command that dies need not be Disconnect: `0x0c1a Write Scan Enable` |
| [EX-024](../../evidence/exhibits/024-two-headsets-one-signature.md) | The same signature with two other headset models |
| [EX-028](../../evidence/exhibits/028-poweroff-recovers-what-reboot-could-not.md) | A power-off recovered the controller where a reboot had not |

The twelve failures, with kernel, first command and timings, are tabulated in
[BRIEF.md, section 2](../../BRIEF.md#2-the-signature--n--12-four-kernels-three-peripherals-both-configurations).

## With the QCA setup path

| exhibit | what it shows |
|---|---|
| [EX-055](../../evidence/exhibits/055-e1-qca-setup-loads-rampatch-over-rom-firmware.md) | Before setup: ROM `0x302`, build `0x111`, status `0x20`; both files load (return 0); afterwards patch `0x3e8`, status `0xe0` |
| [EX-058](../../evidence/exhibits/058-e1-setup-only-58-links-three-boots.md) | 58 SCO links (43 mSBC, 15 CVSD), three boots, two headset models, on the diagnostic build: `BTUSB_QCA_ROME` only, no `BTUSB_WIDEBAND_SPEECH`, no reset callback ([patch](../../patches/diag/btusb-e1-qca-rome-setup-no-reset.patch)); 0 command timeouts |
| [EX-057](../../evidence/exhibits/057-e3-upstream-entry-16-links-two-headsets.md) | 16 SCO links (7 mSBC, 9 CVSD) with the exact `dc16388d45ec` entry, including the headset of EX-053; 0 command timeouts |

## Reading the older exhibits

The exhibit index also holds early interpretations that later evidence corrected, for example
EX-006's title ("SCO setup is the wedging command": `0x0428` is answered in every later
instance). The corrected statements and the retracted ones are in
[BRIEF.md, sections 3 to 5](../../BRIEF.md#3-settled). In provenance tables written before
2026-10-02, `capture boot id` is the boot the exhibit was captured in, which can differ from the
boot its evidence comes from (`evidence boot ids`).
