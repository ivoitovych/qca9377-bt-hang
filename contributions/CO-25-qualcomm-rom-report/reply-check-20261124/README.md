# CO-25 reply to Zijun Hu: verification on 2026-11-24

**What was checked:** every factual sentence of `../drafts/reply-1-zijun-hu-v4.eml` (the 11-02 draft) and of v5
(v4 plus one sentence), against the trees, linux-firmware and the laptop's records as of 2026-11-24 ~03:30 UTC.
Then the mail itself. Nothing was sent.

**Trees read:**
- mainline `b6a9fa34ce41` (2026-11-22);
- bluetooth-next `ffb95458a0f7` (2026-11-23), both fetched today;
- linux-firmware `main` at `9a364ea4` (2026-11-23), its `WHENCE` fetched today.

Source facts: `check-source.sh` → `check-source.out`.

## The claims, one by one

| sentence in the reply | check | result |
|---|---|---|
| quote of his mail | his mail from lore's git archive (`tmp/lore-messages/bf27c4e0-…eml`, machine-local) | identical text |
| "the absence of a QCA9377-specific USB firmware image in linux-firmware" | `WHENCE` at `9a364ea4` | right for USB only. *Corrected 2026-11-24 after review:* WHENCE does not name QCA9377 under btqca, but linux-firmware `619d33958d72` (2020, "QCA: Add Bluetooth firmware for QCA9377") added `qca/rampatch_00230302.bin` and `qca/nvm_00230302.bin` for the serial-attached part (WHENCE l.5297, l.5301). So "no QCA9377 Bluetooth firmware" is false; v9 no longer concedes it |
| "btusb lists three QCA9377 modules with BTUSB_QCA_ROME: 04ca:3015, 0cf3:e500 and 13d3:3503" | `check-source.out` §1, both trees (`btusb_main.c:293`, `:303`, `:317`) and the commits naming QCA9377 (`0a03f98b98c2`, `0324d19cb998`, `dc16388d45ec`) | right; no other btusb ID's commit names QCA9377 |
| "its ROM reports rom_version 0x00000302" | EX-055 (09-26, before setup: "rom 0x00000302 patch 0x00000111"); stock boot `af3f9840` of 11-13 (`results/bt16-third-2026-11-13/kernel-boot-af3f9840-control.txt`) | right |
| "btusb_setup_qca() loads qca/rampatch_usb_00000302.bin and qca/nvm_usb_00000302.bin" | §4: names built as `qca/rampatch_usb_%08x.bin` and `qca/nvm_usb_%08x[_board].bin`; the subdirectory and the board suffix apply only with the multi-NVM flag. The 11-13 stock boot loaded exactly these two names | right |
| "the files linux-firmware lists for QCA61x4 USB chips" | `WHENCE` l.5182 "btqca - … QCA61x4 USB chips", l.5194, l.5196 | right |
| the quoted kernel line `QCA: patch rome 0x302 build 0x3e8, firmware rome 0x302 build 0x111` | format string `btusb_main.c:3806` (args: rampatch's rom/build, then the controller's rom/build); the 11-13 boot line, verbatim | right; "firmware … build 0x111" is the controller's own ROM build, read before patching |
| "rome 0x302 build 0x111 … stopped answering HCI commands once such a link was streaming" | the sent report and BT-1's twelve failures (`EX-033`…`EX-053`) | right, as the report says |
| v5 only: "74 SCO links (50 of them mSBC) ran without a command timeout … On the ROM firmware alone, twelve failed" | the sent report, lines 27–28 and 84–87 ("50 mSBC … and 24 CVSD") | right; it restates the report |

## Checked and not affecting the reply

- **Zijun Hu's `3efdadae3a25` (11-02, first in v7.4-rc3; in no stable line).** It fixes the Transport_Unit_Size
  of Enhanced Setup Synchronous Connection on the HCI data path. It does not touch this controller:
  `btusb_setup_qca()` sets `HCI_QUIRK_BROKEN_ENHANCED_SETUP_SYNC_CONN` (`btusb_main.c:3974`), so the legacy
  command is used, as the report says. On ROM firmware the command is not even advertised (EX-055). Not a new
  bug for us; not mentioned in the reply.
- **Later activity:** no other reply on the thread (the 3441-mail scan of today). No btusb commit since has
  changed these IDs or the QCA setup.

## The mail

- `scripts/mail-lint.sh`: clean, for v4 and v5.
- `scripts/reply-headers-check.py <reply> <original>`: all PASS for both. In-Reply-To and References name his
  Message-ID, the subject is "Re:" plus his subject, and reply-all gives 7 recipients, his From, To and Cc.
- **Recipients:** MAINTAINERS names Bartosz Golaszewski for the Qualcomm Bluetooth driver; he is in Cc. Shuai
  Zhang is still active in `btqca`/`hci_qca` (11-10). Nobody is added.
- **`git send-email --dry-run --confirm=never --suppress-cc=self --suppress-cc=body`** from the project
  checkout: "Result: OK" for both, with 7 `RCPT TO` lines equal to his recipients.

## v4 or v5

v5 adds one sentence after the kernel line, restating the report's outcome. Without it, the question "is this the
intended initialization?" reads as if the ROME setup were in doubt. It is the setup with which this device stops
failing, and the sentence keeps that fact beside the question. The choice and the send are the operator's.

## Not done

- Today's boot was not read: the ring buffer has rotated, and `journalctl -k -b 0` was still running after 15
  min (CO-46's slowdown). The 11-13 stock boot stands in.
- No outside review of v5's one new sentence.
