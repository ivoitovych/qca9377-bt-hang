# CO-25 log

## 2026-10-28 - draft v1

### How the recipients were found

- `cache/linux` is a sparse blob:none clone: `scripts/` is not checked out, and
  its working-tree `btusb.c` predates the split (on `origin/master` the file is
  `drivers/bluetooth/btusb_main.c`).
- `scripts/get_maintainer.pl` was read with `git -C cache/linux show
  origin/master:scripts/get_maintainer.pl` into the session scratchpad, its
  `$lk_path` set to a stub tree there (the empty top-level directories and files
  it checks for, `MAINTAINERS` symlinked to `cache/linux/MAINTAINERS`). Nothing
  in `cache/linux` was changed.
- Command, per file: `perl gm.pl --no-git --no-git-fallback --rolestats -f
  <stub>/drivers/bluetooth/<file>`. Output, btqca.c:

      Bartosz Golaszewski <brgl@kernel.org> (maintainer:QUALCOMM BLUETOOTH DRIVER)
      Marcel Holtmann <marcel@holtmann.org> (maintainer:BLUETOOTH DRIVERS)
      Luiz Augusto von Dentz <luiz.dentz@gmail.com> (maintainer:BLUETOOTH DRIVERS)
      linux-arm-msm@vger.kernel.org (open list:QUALCOMM BLUETOOTH DRIVER)
      linux-bluetooth@vger.kernel.org (open list:BLUETOOTH DRIVERS)
      linux-kernel@vger.kernel.org (open list)

  btusb.c: Holtmann, von Dentz, linux-bluetooth, linux-kernel.
- The working-tree MAINTAINERS was compared with `origin/master`'s: the
  QUALCOMM BLUETOOTH DRIVER and BLUETOOTH DRIVERS sections carry the same
  maintainers, lists and `drivers/bluetooth/btqca.[ch]` pattern
  (`git -C cache/linux grep -n -A9 "^QUALCOMM BLUETOOTH DRIVER" origin/master
  -- MAINTAINERS`).
- `--no-git` was used, so no history-derived names are in the list above; the
  history candidates are in the README, from `git log origin/master --
  drivers/bluetooth/btqca.c` and `btusb.c`.

### Claims and exhibits (for the reviewers' page)

| # | claim in the draft | source |
|---|---|---|
| C1 | QCA9377, USB 13d3:3503, IMC Networks; interface 1 has alt settings 1 to 5 with 9/17/25/33/49 bytes, no alt 6 | commit `dc16388d45ec` (message); BRIEF section 1 |
| C2 | before `dc16388d45ec` btusb had no entry for the ID, the controller ran ROM firmware | EX-001; EX-055 (ROM `0x302` build `0x111`, status `0x20`) |
| C3 | log line `QCA: patch rome 0x302 build 0x3e8, firmware rome 0x302 build 0x111` | EX-055 (journal line 2026-09-26T17:11:14.594432) |
| C4 | status byte read by `btusb_setup_qca()` before loading is `0x20`, rampatch and NVM both to load | EX-055 (`E1: status 0x20: rampatch will load, nvm will load`) |
| C5 | transparent air mode on alt 1, 9-byte endpoint, 27-byte buffer as three packets | EX-037 (680 x `len 27 mtu 9`), EX-045, EX-051..053; `sysfs` read of `bAlternateSetting 1`, `wMaxPacketSize 0009` in EX-045, EX-053, EX-054 |
| C6 | `0x0428` answered, link up, first later command times out after 2 s | EX-033, EX-036, EX-043, EX-045, EX-053 |
| C7 | named dying command: `0x0406` in six instances, `0x0c1a` in one; the others are the bare form without an opcode | BRIEF section 2 table: `0x0406` in EX-036, 043, 045, 047, 052, 053; `0x0c1a` in EX-051; EX-033, 037, 038, 040, 042 bare |
| C8 | first command 34 ms to 9.65 s after link-up | BRIEF section 2 table (EX-033..EX-053); 9.65 s is EX-043 |
| C9 | controller answers nothing afterwards; USB `GET_DESCRIPTOR` times out (-110); stays enumerated | EX-008, EX-016, EX-054; EX-052 (two `GET_DESCRIPTOR` timeouts) |
| C10 | a power-off recovered it; a reboot did not always | EX-028 (power-off recovered, reboot did not); EX-027, EX-034 (reboot failed); EX-017 (one reboot recovered) |
| C11 | 12 instances, four kernel builds, three headset models | BRIEF section 2 (kernels `-29`, `-30`, `-31`, `-34`; EX-033..EX-053); EX-024, EX-053 (headsets) |
| C12 | E1: 58 links over three boots, QCA setup only, 0 timeouts | EX-058 (and EX-056) |
| C13 | E3: 16 links on one boot, exact entry, 0 timeouts | EX-057 |
| C14 | every Disconnect answered in those runs | EX-056, EX-057, EX-058 |
| C15 | the entry has been released in stable kernels | EX-061 (queued for seven lines); BRIEF section 0 (released in 7.2.10, 6.18.56, 6.12.113, 6.6.160) |
| C16 | the reset callback does not run in a clean boot | `patches/diag/README.md` (E3 section: "the reset callback only fires on a timeout") |
| C17 | not known: what the ROM does wrong; other air modes, alt settings, revisions not tested; no failure rate | BRIEF section 0 Foundation and section 4; no exhibit counts ROM-firmware links that survived |
| C18 | Read Local Supported Commands: 197 in 149 of 159 replies on the stock driver; 202 with Enhanced Setup and Enhanced Accept after the rampatch | EX-055 |
| C19 | btusb lists 13d3:3491, 3496, 3501 as `BTUSB_QCA_ROME`; 3502 and 3504 appear nowhere; 3503 added | `git -C cache/linux grep -n -E "0x13d3, 0x350[0-9]\|0x13d3, 0x349" origin/master -- drivers/bluetooth/btusb_main.c` (3491, 3496, 3501, 3503, plus 3490 ATH3012, 3494 Realtek) |
| C20 | kernels "Ubuntu 7.0.0-29 to 7.0.0-34" | BRIEF section 2 table |

Not in the draft, on purpose: the speculation about the cause, the Enhanced Setup
quirk (`BTUSB_QCA_ROME` sets `HCI_QUIRK_BROKEN_ENHANCED_SETUP_SYNC_CONN`, so legacy
`0x0428` stays in use with the firmware loaded; `patches/diag/README.md`), the
later E3 links on `-38` (not exhibits), headset and vendor names, device addresses.

### Checks made

- `awk 'length > 72'` on the draft: no output. ASCII only.
- No AI tool names, no private-repository mentions, no addresses of devices.
- Not checked: whether `get_maintainer.pl` on a full tree would list more
  (it would add history-derived names without `--no-git`); the draft's Cc is
  deliberately MAINTAINERS only.

## 2026-10-28 — v2 after the outside reviews (`reviews-2026-10-28.md`)

`drafts/report-v2.txt` (66 lines against v1's 82; `awk 'length > 72'`: none; ASCII only).
Item by item:
1. ID sentence: 3491, 3496, 3501 and 3503 listed; 3502/3504 asked about, "we do not know
   whether … are ROME devices at all" (C19). Moved to question 1.
2. Cc Zijun Hu (`zijun.hu@oss.qualcomm.com`, published upstream, in the public-address list).
   This departs from v1's "MAINTAINERS only" Cc on purpose: the questions are firmware ones.
3. Evidence wording, each checked here:
   - air modes: `grep -c -E "^2026-.* msbc +[0-9]"` on EX-058 → 43, EX-057 → 7; `cvsd` → 15
     and 9: 50 mSBC + 24 CVSD (reviewer 4's split, confirmed). "Other air modes not tested"
     dropped; the counts are stated.
   - "every Disconnect was answered" → "logged no HCI command timeout" (the ledger's
     "hang-ups answered 58/16" stays true, but EX-057's rfkill Disconnect answered `-107`
     makes the shorter claim the safe one).
   - "the QCA setup path (qca/rampatch_usb_00000302.bin and qca/nvm_usb_00000302.bin)", not
     "the rampatch".
4. Inline excerpt: EX-053's five kernel lines (lines 38-46 of the exhibit), host prefix
   removed, date dropped; "evt 5" glossed as btusb_notify()'s transparent-SCO value
   (`HCI_NOTIFY_ENABLE_SCO_TRANSP`). The control-transfer timeout is EX-052's (lines 37-38),
   stated in prose, not in the excerpt: EX-053 has none and `tools/bt-fault-window` printed no
   setup lines for EX-052's boot.
5. Shorter: alternate-setting listing gone; "what we do not know" two sentences; 197/202 one
   sentence; the ID question first.
6. Signed "Iaroslav Voitovych", as on the kernel commits. Laptop model: not added.
Not sent; the operator's yes is needed.
