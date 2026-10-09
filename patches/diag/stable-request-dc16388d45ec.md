# Stable backport request — `dc16388d45ec` (draft v4c — **SENT 2026-10-02**)

| | |
|---|---|
| **sent** | ✅ **2026-10-02 03:25:42 +0200**, on the operator's word, `git send-email --suppress-cc=all` with explicit To/Cc, SMTP result `250`. **Message-ID `<20261002012542.473669-1-yaroslav.voytovych@gmail.com>`** — <https://lore.kernel.org/r/20261002012542.473669-1-yaroslav.voytovych@gmail.com>. To stable@; Cc the commit's author, Marcel Holtmann, Luiz Augusto von Dentz, linux-bluetooth. Body = v4c below, byte for byte (`mail-lint` clean). Same-minute checks: five tips unchanged against `EX-059`, recipients unchanged |
| first attempt | 03:2x, port 587: `Unable to initialize SMTP properly` — port 587 **timed out on this network** (IPv6 unreachable, IPv4 no answer); nothing transmitted, no AUTH. Port 465 (implicit TLS) connected and was used; the repository's `sendemail` config now says 465/ssl |
| app password | used once on the send command; the operator revokes it; `scripts/smtp-login-check.sh` confirms |
| **queued** | ✅ the stable maintainer replied: "Queued for 7.2, 6.18, 6.12, 6.6, 6.1, 5.15 and 5.10, thanks." (relayed by the operator 2026-10-03). Checked against the public stable-queue tree the same day: `scripts/stable-queue-check.sh bluetooth-btusb-add-imc-networks-qca9377 7.2 6.18 6.12 6.6 6.1 5.15 5.10` → QUEUED on all seven (`EX-061` on `main`). Five lines asked, all seven queued — including the 5.15/5.10 deliberately left out of the mail; `EX-059` had already built those two |
| next | each line's next stable release (the patch moves from `queue-<v>/` to `releases/<v>.<n>/`), then the Ubuntu kernel that carries it; nothing owed |

Per `Documentation/process/stable-kernel-rules.rst`, option 2: a mail to the stable team
naming the mainline commit, the trees, and why. Plain text, 7-bit ASCII, every body line
within 72 columns, no attachment, no patch. The sendable file is `tmp/stable-backport/request-v4.eml`
(local; it carries the addresses, which this repository does not store).

**To:** stable@vger.kernel.org
**Cc:** the commit's author (Tibor Harcsa), the Bluetooth maintainers (Marcel Holtmann, Luiz
Augusto von Dentz at his MAINTAINERS address), linux-bluetooth@vger.kernel.org — from the
commit and `scripts/get-maintainers.sh` on the day (2026-10-02: unchanged).

**Subject:** `Please backport dc16388d45ec ("Bluetooth: btusb: Add IMC Networks QCA9377 to quirks table") to stable`

---

```
Hello,

please consider for linux-7.2.y, linux-6.18.y, linux-6.12.y, linux-6.6.y
and linux-6.1.y:

  dc16388d45ec ("Bluetooth: btusb: Add IMC Networks QCA9377 to quirks
  table")

It is in mainline since v7.3-rc1 and carries no Cc: stable tag. It adds
one entry to the btusb quirks table, beside the existing 13d3:3501 entry
that carries the same flags:

	{ USB_DEVICE(0x13d3, 0x3503), .driver_info = BTUSB_QCA_ROME |
						     BTUSB_WIDEBAND_SPEECH },

None of the five trees has the ID. The commit cherry-picks onto each of
them and btusb builds with it on each (checked 2026-10-02).

Without the entry, on an IMC Networks QCA9377 (13d3:3503) in a laptop
running Ubuntu's 7.0-based kernel, the device is matched as a generic
controller, btusb_setup_qca() never runs, and it stays on its ROM
firmware. On that firmware I observed:

 - "unexpected event for opcode 0x2005" during LE scans, as the commit
   message describes;
 - after a transparent (mSBC) SCO link had streamed on USB alternate
   setting 1, the next HCI command timed out: 12 recorded instances
   across four 7.0 builds and three headset models; in the investigated
   ones the controller then stopped answering USB control transfers and
   only removing power recovered it.

With the entry (the commit applied to the 7.0.0-34 source and btusb.ko
rebuilt, nothing else changed) the driver loads
qca/rampatch_usb_00000302.bin and qca/nvm_usb_00000302.bin from
linux-firmware, and neither failure was observed in the test on the
same machine:

 - 0 "0x2005" events over the boot;
 - 16 SCO links on two headsets, including one that had wedged the
   controller before, with all 16 hang-ups answered and 0 command
   timeouts. A diagnostic build enabling only the QCA setup part of the
   entry had previously completed 58 links over three boots with all 58
   hang-ups answered and 0 command timeouts.

Runtime testing was performed on the 7.0-based kernel; the five
requested stable trees were cherry-picked and build-tested. Logs, HCI
captures and the exact commands are public, exhibits EX-055 to EX-059
at:

  https://github.com/ivoitovych/qca9377-bt-hang

Thank you,
Iaroslav Voitovych
```

---

## Facts behind each sentence (for the reviewer; not part of the mail)

| sentence | source |
|---|---|
| mainline v7.3-rc1, no `Cc: stable` | `git -C cache/linux tag --contains dc16388d45ec --list 'v*'` → `v7.3-rc1` first; `git show dc16388d45ec` body |
| the entry, byte for byte, beside `13d3:3501` with the same flags | `git show dc16388d45ec`; `grep -n -A2 'USB_DEVICE(0x13d3, 0x3501)' cache/ubuntu-7.0.0-34/drivers/bluetooth/btusb.c` (same two-line form, tab + spaces) |
| trees: 7.2.y, 6.18.y, 6.12.y, 6.6.y, 6.1.y (7.1.y EOL, 7.0.y gone; 5.15.y/5.10.y live) | `https://www.kernel.org/releases.json` fetched 2026-10-02 (`7.1.13 iseol true`; no 7.0 entry; `6.18.54`, `5.15.221`, `5.10.270` live) |
| none of the trees has the ID; the commit **cherry-picks** (`git cherry-pick --no-commit`, what the stable pickup is) onto the fresh tip of each line and btusb **builds** with it, `-Werror`, unpatched (control) and picked; the entry in the picked source | `EX-059` (`scripts/build-btusb-stable-matrix.sh dc16388d45ec`: fetch, reset each worktree to the tip, cherry-pick, build) — run of 2026-10-02 for all seven live lines; the five requested are 7.2/6.18/6.12/6.6/6.1. An earlier run of the same script with GNU `patch` (offset/fuzz, logs `tmp/btusb-matrix/`) is superseded by the cherry-pick form |
| generic match, `btusb_setup_qca()` never runs, ROM firmware | `EX-055` (`E1: before setup: rom 0x00000302 patch 0x00000111`); stock `btusb` has no `13d3:3503` entry (`EX-001`) |
| `0x2005` during LE scans | `EX-002`, `EX-003`; the commit's own message: "BLE scanning fails with HCI unexpected event opcode 0x2005 errors" |
| 12 recorded instances, four builds `-29/-30/-31/-34`, three headset models | `EX-033`, `036`, `037`, `038`, `040`, `042`, `043`, `045`, `047`, `051`, `052`, `053`; the per-exhibit tables in `README.md` and `BRIEF.md` §2. "Recorded instances", not a denominator (`EX-040` notes the missing denominator) |
| in the investigated ones: USB control transfers unanswered, power removal to recover | `EX-052` (`GET_DESCRIPTOR` → `-110`, `usb_set_interface` → `-110`), `EX-027`/`028`/`039` (warm reboot does not clear it, power-off does), `EX-046`/`EX-048` (rebind, rfkill) |
| rampatch + NVM loaded from linux-firmware | `EX-057`: `using rampatch file: qca/rampatch_usb_00000302.bin`, `patch rome 0x302 build 0x3e8, firmware rome 0x302 build 0x111`, `using NVM file: qca/nvm_usb_00000302.bin` |
| E3: 0 `0x2005`; 16 links, two headsets, one that had wedged before, 16 answered, 0 timeouts | `EX-057` (`scripts/boot-bt-summary.sh c34cfa108a144b0f9b900806cb71367e`): 7 MOMENTUM, 9 Shure (the Shure is `EX-053`'s headset); error-level grep shows no `tx timeout` and no `0x2005` (one `corrupted SCO packet` during a Shure mSBC link, one Disconnect `-107` at the rfkill power-off — neither a timeout) |
| E1 setup-only build: 58 links, three boots, same result | `EX-058` (`scripts/sco-ledger-boots.sh 226965f1… 855a927e… 8709ee7c…`): 34 + 21 + 3, 58 answered, 0 timeouts; two headset models (MOMENTUM, Lenovo) |
| runtime on 7.0 only | the only kernel this hardware runs here; other trees: cherry-picked and built (row 4). 5.15.y/5.10.y: built too but **not requested and not mentioned** — floor 6.1 by choice (both lines reach EOL in December 2026) |
| mechanical form | `scripts/mail-lint.sh tmp/stable-backport/request-v4.eml`: headers present, body within 72 columns, ASCII, no trailing whitespace |

## Send procedure (the minute of sending)

1. `scripts/stable-tips-check.sh evidence/exhibits/059-*.md stable/linux-{7.2,6.18,6.12,6.6,6.1}.y` — fetches; every line `unchanged` → `EX-059` stands; any `MOVED` → `scripts/build-btusb-stable-matrix.sh dc16388d45ec <that branch>` and a new exhibit before sending.
2. `scripts/mail-lint.sh tmp/stable-backport/request-v4.eml` → clean.
3. `scripts/get-maintainers.sh cache/full-bt-next tmp/runtime-e3/0001-….patch` → recipients unchanged (the author from the commit).
4. `git send-email` as in the dry run of 2026-10-02 (`--suppress-cc=all`, explicit `--to`/`--cc`), app password used once on that command, revoked afterwards (`scripts/smtp-login-check.sh` confirms).
5. Record the Message-ID and SMTP result here and in BRIEF.

## Review record

- 2026-10-01 outside review, round 1: trees (7.1/7.0 EOL, 6.18 missing), `-28`, "12 of 12", E1 headset count, public evidence level with the mail, length — all applied in v2.
- 2026-10-02 round 2: EX-057 relevance contradiction, boot-index selectors, two sentences — applied in v3; round 3: `bt-exhibit` provenance (capture vs evidence boots), fact-table commands — applied.
- 2026-10-02 operator's review: a hanging line, the entry wrapped inside prose, "leave those to you", the two with/without blocks unreadable — v4: 72 columns throughout, the entry as a block identical to `btusb.c`, every named tree applied **and built** (matrix script), body in four parts, plain ASCII.
