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

## 2026-10-29 — v3 after the sixth review round (`reviews-2026-10-28.md`, round 6)

`drafts/report-v3.txt`, from reviewer 6's proposed text as the operator relayed it, with the
other reviewers' corrections; every changed claim checked here:

| claim in v3 | check |
|---|---|
| entry in v7.3, 7.2.10, 6.18.56, 6.12.113, 6.6.160; 6.1/5.15/5.10 in release candidates | `curl -s https://www.kernel.org/releases.json` (2026-10-29): 6.1.190, 5.15.223, 5.10.272 newest, all dated 10-15, before the 10-17 candidates; the released versions as in C15 |
| 0b05:1868 `d54601f21faf`, 0b05:1825 `cfa67a1dbfd9`, both for the `0x2005` BLE-scan errors | `git -C cache/linux show --no-patch --format=%B cfa67a1dbfd9 d54601f21faf` (both messages quote `unexpected event for opcode 0x2005`; 1825 is "QCA6174 … ASUS Z170I PRO GAMING", 1868 "QCA Rome 0x302") |
| 3502/3504 not mentioned | 3504 is Broadcom BCM4371C2 (public Broadcom firmware list); `git -C cache/linux grep -n "0x13d3, 0xff" origin/master -- drivers/bluetooth/btusb_main.c` → the 13d3 Broadcom vendor match |
| E1: `BTUSB_QCA_ROME` only, no `BTUSB_WIDEBAND_SPEECH`, no reset callback | `grep -n "^+" patches/diag/btusb-e1-qca-rome-setup-no-reset.patch` |
| status with neither `QCA_PATCH_UPDATED` nor `QCA_SYSCFG_UPDATED` | EX-055 (`status 0x20: rampatch will load, nvm will load`); `QCA_PATCH_UPDATED 0x80` in `btusb_main.c` |
| same three headset models | EX-024 + EX-053 (MOMENTUM 4, thinkplus-GM2 pro, AONIC 50); E1 used MOMENTUM 4 and GM2 pro (EX-058), E3 MOMENTUM 4 and AONIC 50 (EX-057) |
| stream ran about 7.3 s before the Disconnect | EX-053: link up 02:09:36.719, Disconnect 02:09:44.050 |
| USB probe in one failure | EX-052 (two `GET_DESCRIPTOR`, `-110`) |
| recipients | `git -C cache/linux grep -n -A8 "^QUALCOMM BLUETOOTH DRIVER" origin/master -- MAINTAINERS`; `btusb_setup_qca()` at `btusb_main.c:3900`, no `btqca.h` include; addresses from `git log` (Harcsa: `dc16388d45ec`; Shuai Zhang: `82855073c108` and four more) |

`awk 'length > 72'`: none; no non-ASCII. The evidence link is a placeholder for
`EVIDENCE.md` at the commit pinned on the day of the send.

**Exhibit provenance, all exhibits (reviewer 7's EX-052 finding).** 46 exhibits carried the
pre-2026-10-02 single `| boot id |` row, which `bt-exhibit` filled with the boot at capture time.
`scripts/exhibit-relabel-boot-id.py --write` turned each into `| capture boot id |`
plus `| evidence boot ids |`, the latter from the 32-hex ids in the exhibit's own `$` command
lines, or "none named by the command" when it selects boots by index (`-b -1`), exactly as
`bt-exhibit` writes them now. Rows with a note after the id (EX-029, 034, 038, 040, 042, 043)
were written by hand, already say which boot they mean, and were left alone. History check:
the only earlier changes to such rows are EX-038's hand correction (`92ef01c`) and
EX-057/058 (`b12144a`). `git diff -U0` shows no other line changed. EX-052 now reads
capture `e90c9c57`, evidence `5ee9ab78`.

**The desktop captures behind EX-055's survey are gone.** `/var/log/bt-health/capture` now
starts at `hci-20261010-193534`; the installed `bt-capture` keeps the newest 400 files
(`--keep`, default 400) and deletes the oldest, and 386 were present on 10-29. No copy of the
August files is on the disk (`find / -xdev -name "hci-202608*"`: none). So reviewer 6's test
(Read Local Version Information in a 197-command boot, a 200-command boot and an E1 boot) cannot
be run. The survey's own output is kept:
`results/supported-commands-survey-2026-09-26/supported-commands-survey.tsv` (copied from
`tmp/`, same SHA-256 `b735467d…`; 149 × 197, 6 × 200, 4 × 0, 33 × 202). A safe test remains for
later, but not the one first written here: a missing "QCA: patch rome" line after a warm reboot
from Windows would not prove anything (setup may not have run, or failed earlier; reviewer 4,
round 7). It needs positive readings: a build that logs the status byte and versions before
setup, as E1 did (`status 0x20` cold; `0xe0` would mean a patch already present), on a warm
reboot straight from Windows and, as the control, on a cold boot. Even then it shows today's
behaviour, not what happened in August. The operator's call; not needed for the report.

**The next files to go, archived.** `scripts/bt-trace-archive.py` took only `bt-*` names; it
now reads `BT_TRACE_PREFIX` (default `bt-`), and its proof has three more checks (hci-* ignored
by default, archived with the prefix, nothing deleted): 17 of 17 pass. The wrapper
`scripts/desktop-capture-archive.sh --once-limit 40` archived `hci-20261010-193534` to
`hci-20261011-121614` into `archive/hci-capture/`: "archived 40 (2560 MB -> 897.4 MB), skipped
0, failed 0, pending 345; archive 0.88 GB of 3 GB"; `MANIFEST.tsv` 40 rows; the capture
directory still holds 386 files. The rest is the operator's decision (STATUS).

## 2026-10-29 — v4 after the seventh review round (`reviews-2026-10-28.md`, round 7)

`drafts/report-v4.txt`; checks for what changed:

| change | check |
|---|---|
| "first command after link-up timed out, 34 ms to 9.65 s after it" was wrong: the range is when the command was issued | BRIEF section 2 table ("first cmd after link-up" 34 ms to 9,650 ms); command to timeout 2.018 to 2.053 s where given (EX-045, 047, 051, 052, 053) |
| summary bounded to the twelve recorded failures; "answers nothing until power is removed" dropped (a reboot recovered it once, EX-017) | C10 |
| "same alt 1 and 0x0428" only for the 50 mSBC links | CVSD takes another alternate setting |
| load confirmed by return codes and a later version read, not by the loader's "QCA: patch" line | EX-055 lines 29-35 (`rampatch load returned 0`, `after rampatch: … patch 0x000003e8`, `nvm load returned 0`) |
| E1's remaining confounders named | `btusb_main.c` 4648-4655: `BTUSB_QCA_ROME` also sets `hdev->shutdown`, `set_bdaddr`, `HCI_QUIRK_SIMULTANEOUS_DISCOVERY`, the reset-resume check; E1 removed only `hdev->reset` |
| 0b05:1825's July submission | read 2026-10-29 (the thread on a public list archive): Edgard Lopes, 2026-07-21, "[PATCH] Bluetooth: btusb: Add ID 0b05:1825 for ASUS QCA ROME adapter": "leaving the device running its bare ROM firmware. In that state SCO/eSCO audio is broken", "corrupted SCO packet", "HFP/HSP microphone input never works"; the list's bot answered that it no longer applied; no v2. A different symptom from ours, stated as such |
| opening: stable versions out (they age), "which is worse" out | — |
| archive sentence narrowed to "check whether its USB ID selects the QCA setup path and whether the files load" | — |

`awk 'length > 72'`: none; no non-ASCII. The evidence link is pinned to `0632d42052eb` (the commit with the final `EVIDENCE.md`; the URL answers 200); it is the one line over 72 columns.

**Firmware provenance** (reviewers 4, 6), now in `EVIDENCE.md`: `dpkg -S` gives
`linux-firmware-qualcomm-wireless` `20240318.git3b128b60-0ubuntu3.1`; `/var/log/dpkg.log*`
shows that package installed 2026-10-01 13:50:58, when `linux-firmware` went from
`0ubuntu2.29` (installed 08-15) to the split `0ubuntu3.1`. E1 (09-26) and E3 (boot from
10-01 00:13:20, EX-057) therefore loaded `0ubuntu2.29`'s files; that package is not cached, so
the hashes recorded are of the files installed now, with that caveat.
