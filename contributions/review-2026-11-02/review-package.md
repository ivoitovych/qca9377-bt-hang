---
title: Bluetooth Submissions Review
subtitle: Every package that is ready to send or ready for review, explained in full — state of 2026-11-02
---

# How to use this document

This document is complete in itself. It contains no links and refers to no repository, file or
web page that you would need to open. For each item it gives the background, the cause as read
in the source (with short excerpts and `file:line` at a named tree or commit), the change, the
**complete text of every patch or mail**, the tests with their exact numbers, what is not known,
and the questions we would like answered.

**What we ask of you, for each item:**

1. Is it technically correct: the code, the tests, and every claim in the commit message or mail?
2. Is anything missing that a maintainer or a stable/distribution reviewer would ask for?
3. Is it ready to send, nearly ready, or far from it, and why?
4. Is there anything to cut?

Each item ends with a list of specific questions. Answers that point to a line, a commit or a
test are the most useful to us.

**How claims are marked.** *Measured* means we ran it and give the count (for example "10 of
10 runs"). *From source* means read in the code, with the tree and `file:line`. *Inferred* means
reasoned from the two, not shown. Where something is not known, the item says so.

**Nothing in this document has been sent** unless its "At a glance" table says so. Every
patch is shown exactly as it currently stands in the draft, with its trailers as stored; the
submitter confirms them at send time. Other authors' patches are used exactly as posted and are
credited by author, subject, date and patchwork number.

**Device addresses** are replaced by pseudonyms or left out. Email addresses and message IDs
are left out; people are named.

# The setting in one page

All of this work started from one laptop and its everyday Bluetooth use: calls on headsets,
music on speakers and earbuds, on Ubuntu 24.04.

- **The controller.** A Qualcomm QCA9377, USB ID `13d3:3503` (IMC Networks).
- **The original fault (BT-1, solved, not by us).** On a transparent (mSBC, wideband speech)
  SCO link, btusb uses USB alternate setting 1. On this controller, the first HCI command after
  the audio stream started got no reply, and only a power-off recovered the controller (12
  such deaths recorded). The cause was that `13d3:3503` was missing from btusb's device table,
  so the controller ran its ROM firmware. The upstream table entry `dc16388d45ec` (Tibor Harcsa)
  gives it `BTUSB_QCA_ROME`, which loads Qualcomm's rampatch and NVM (`QCA: patch rome 0x302
  build 0x3e8` in the kernel log). With that entry, 74 call links in two trial series had no
  timeouts. A later trial, which also carried a test build of an unrelated SCO change (CO-02),
  recorded 63 links, 63 hang-ups answered, 0 timeouts; it is kept apart from the 74. What the ROM
  firmware does wrong is not known and not claimed (see CO-25).
- **Everything else in this document** was found on the way. Each item is a separate defect
  with its own evidence: kernel SCO and btusb handling, MGMT mesh and advertising, a stable-line
  hang, BlueZ's daemon and tools, Ubuntu's packages, and PipeWire/WirePlumber.

**Test environments.** Kernel changes are tested in QEMU guests with the kernel's own testers
(`sco-tester`, `mgmt-tester`, `mesh-tester`, `l2cap-tester`, `iso-tester` and others from BlueZ,
on an emulated controller), with lockdep, KASAN and KCSAN builds where stated. BlueZ changes are
tested with BlueZ's own unit and functional tests, under AddressSanitizer where stated, and with
BlueZ's continuous-integration checks run locally on the base and on base plus the patch. Ubuntu
packages are built and tested in Ubuntu 24.04 containers or VMs. PipeWire changes are tested in
PipeWire's own VM test setup. Real-hardware tests on the laptop are marked as such.

# Glossary

| term | meaning |
|---|---|
| SCO / eSCO | the Bluetooth synchronous link that carries call audio |
| CVSD | narrowband call audio (air mode `0x02` in HCI) |
| mSBC, transparent | wideband call audio; the controller passes the data through unchanged (air mode `0x03`) |
| air mode | the voice coding a SCO link was set up with, reported by the controller in the Synchronous Connection Complete event |
| alt setting | the USB alternate setting of btusb's isochronous interface; it sets the USB bandwidth for SCO audio; 0 means no bandwidth |
| HCI | the host–controller interface (commands, events, data) |
| MGMT | the kernel's Bluetooth management interface used by bluetoothd |
| mesh send | the MGMT command that sends a Bluetooth mesh packet through an advertising set |
| advertising set / instance | one of the controller's extended-advertising slots |
| ECRED | L2CAP Enhanced Credit Based Flow Control mode |
| HFP / HSP | the hands-free and headset profiles used for calls |
| A2DP / AVDTP | the music profile and its stream protocol |
| bluetoothd | BlueZ's daemon |
| btmon | BlueZ's HCI monitor and trace decoder |
| SRU | an Ubuntu stable-release update (a fixed package for a released Ubuntu version) |
| debdiff | the difference between two Debian source packages, as filed with an SRU |
| KASAN / KCSAN / lockdep | the kernel's memory-error, data-race and lock-order checkers |
| Sashiko | an automated patch reviewer that comments on linux-bluetooth patches |

# The items

| # | item | target | state on 2026-11-02 | what is asked |
|---|---|---|---|---|
| 1 | CO-25 — the reply to Qualcomm about the ROM firmware | kernel list (Qualcomm) | report sent 10-29; reply v3 drafted, not sent | review the reply text |
| 2 | CO-04 — Fix use-after-free in `mesh_send_sync()` | kernel | patch ready, not sent | full review before sending |
| 3 | CO-38 — Read Advertising Features hides higher instances | kernel | one-line fix and tester case, not sent | full review |
| 4 | CO-12 — extended-advertising duration overflow | kernel | clamp fix drafted, not sent | review the fix and its limit |
| 5 | CO-05 + CO-26 — mesh advertising list locking | kernel | superseded in part by another author's patch; follow-up only | is a follow-up wanted, and in what shape |
| 6 | CO-02 — a new SCO connect reuses the closing link | kernel; BlueZ test | v7 sent 10-27; v8 fold prepared; air-mode mismatch patch tested, not sent | review v8 and the mismatch patch |
| 7 | CO-21 — btusb alternate setting with two SCO links | kernel / btusb | redesign written, never loaded | outside review before anything else |
| 8 | CO-30 — defer a SCO connect until the aborting link is gone | kernel (RFC) | prototype; waiting on CO-02 | short look only |
| 9 | CO-35 — L2CAP ECRED deferred-accept hang on stable lines | stable kernel | backport series ready, not sent | review the backports |
| 10 | CO-22 — QCA ROME USB IDs missing from btusb | kernel, stable | survey done; stable request waits for v7.4-rc1 | review the request and the ID list |
| 11 | CO-23 + CO-37 — two bluetoothd memory-lifetime fixes | BlueZ; Ubuntu 5.72 | six mails ready (Release fix added 11-02), not sent | full review |
| 12 | CO-03 — U12, Ubuntu 24.04 BlueZ backport | Ubuntu | built and VM-tested; laptop test pending | review the backport and bug text |
| 13 | CO-11a — Ubuntu 24.04 btmon abort | Ubuntu | debdiff ready; live-capture test done (both fixes needed) | review the debdiff and route |
| 14 | CO-19 — U1, PipeWire Hands-free codec line | Ubuntu | debdiff approved; laptop test is the gate | review the hand-port |
| 15 | CO-36 — PipeWire HFP volume resend after link release | PipeWire | evidence package; report to be written by the submitter | review the evidence |
| 16 | CO-32 — Ubuntu WirePlumber patch kills the input meter | Ubuntu | one-line fix; laptop test pending | review the fix |

Three pieces of work finished while this document was being put together and are included with
their results: the CO-02 air-mode mismatch-check patch, the CO-11a live btmon test, and the
CO-37 fix for a doubled `MediaEndpoint1.Release` (a sixth mail in that series).

# Not in this document

- **Open research questions** (unexplained behaviour that needs more investigation before any
  patch) go into a separate research brief.
- **Laptop-only tests that send nothing** (the speaker codec test, the earbuds mSBC check, the
  switch-on-connect drop-in, the btusb logging variants) are not submissions.
- **Items waiting on someone else:** the abandoned-setup SCO series of another author (no v4
  yet), the review reply on another author's mesh power-off fix, and the Tested-by for the
  flaky BlueZ functional test (blocked on test hardware access).
- **Already sent or merged and only being tracked:** the Tested-by on stable 6.6.160-rc2, and the
  BlueZ ioctl-tester duplicate-name fix, applied upstream as `3e5b0da969c2`.

# The items in detail

## CO-25 — BT-1's ROM firmware: the report to Qualcomm (sent) and the reply draft (not sent)

### At a glance

| | |
|---|---|
| Subject | The laptop's QCA9377 (USB 13d3:3503) on its ROM firmware stops answering HCI commands once a transparent (mSBC) SCO link streams |
| Report | **SENT** to linux-bluetooth on 2026-10-29 at 02:33 (+0100), seven recipients: To linux-bluetooth; Cc Marcel Holtmann, Luiz Augusto von Dentz, Zijun Hu, Shuai Zhang, Bartosz Golaszewski, Tibor Harcsa |
| Reply received | Zijun Hu (Qualcomm), 2026-10-29 18:42 (+0800), the same day; nothing further as of 2026-11-02 |
| Our reply | Draft v3, **not sent; waiting for the submitter's word** |
| Asked of the reviewer | Is draft v3 right in tone and content; is the erratum question reasonable; anything wrong in the facts |

### Background

The kernel side is already fixed upstream by `dc16388d45ec` (Tibor Harcsa, "Bluetooth: btusb: Add IMC Networks QCA9377 to quirks table", authored 2026-06-29; not our commit). It adds USB ID 13d3:3503 to btusb's quirks table with `BTUSB_QCA_ROME | BTUSB_WIDEBAND_SPEECH`, so btusb runs `btusb_setup_qca()` and loads the rampatch and NVM. Its commit message cites BLE scanning failing with `unexpected event for opcode 0x2005` without the entry. It was released in 7.2.10, 6.18.56, 6.12.113 and 6.6.160 (2026-10-21) and is in the 6.1, 5.15 and 5.10 release candidates of 2026-10-17 (project records). The report asked what the ROM firmware does wrong, which is not known, and asked how ROME-based USB IDs can be identified (see CO-22).

### What is known and what is not

**Known, measured** (the laptop's QCA9377, USB 13d3:3503):

- **12 controller deaths on ROM firmware.** With stock btusb (no entry for 13d3:3503), on Ubuntu 7.0.0-29, -30, -31 and -34 kernels, with three headset models from three vendors: in twelve recorded failures the first HCI command issued after a transparent (mSBC) SCO link came up got no reply, and later commands timed out. Setup Synchronous Connection (0x0428) was answered and the link streamed. The first command after link-up timed out about 2 s after it was issued; where the delay from link-up was recorded it was 34 ms to 9.65 s. The command was 0x0406 Disconnect in six, 0x0c1a Write Scan Enable in one, and the bare "command tx timeout" in five. In one failure two USB `GET_DESCRIPTOR` control transfers timed out with -110 while the device stayed enumerated; in another, left alone for 12 h 34 min, it stayed enumerated and silent with every later command timing out. Removing power recovered the controller; a warm reboot did not always.
- **USB side.** The device has isochronous alternate settings 1-5 (wMaxPacketSize 9/17/25/33/49) and no alt 6. On the transparent links recorded, btusb selected alt 1 (read live from sysfs); the captures show each 27-byte SCO buffer sent as three 9-byte USB packets.
- **With the QCA setup path** (`qca/rampatch_usb_00000302.bin` and `qca/nvm_usb_00000302.bin`): before setup the controller reports ROM 0x302, build 0x111, status 0x20 (neither QCA_PATCH_UPDATED nor QCA_SYSCFG_UPDATED set); both loads return 0; afterwards patch 0x3e8, status 0xe0. The kernel log line is `QCA: patch rome 0x302 build 0x3e8, firmware rome 0x302 build 0x111`.
- **74 links with 0 command timeouts in the E1 and E3 trials**: 50 mSBC (still on alt 1, with the legacy 0x0428, because `btusb_setup_qca()` sets `HCI_QUIRK_BROKEN_ENHANCED_SETUP_SYNC_CONN`) and 24 CVSD. 58 of them (E1: 43 mSBC and 15 CVSD, three boots, two headset models) ran on a diagnostic build that gave the ID `BTUSB_QCA_ROME` without `BTUSB_WIDEBAND_SPEECH` and without the reset callback, so no reset could have hidden a timeout; 16 (E3: 7 mSBC and 9 CVSD, two headsets, including the headset of the quoted failure) ran with the exact `dc16388d45ec` entry.
- **The E3 #3 journal ledger**: a later trial with the exact upstream entry, 2026-10-23 to 2026-10-29, recovered from the journal because its results row was lost at a shutdown: 63 links, 63 hang-ups answered, 0 timeouts (the longest, an mSBC link, 35,105 s). That run carried an additional test module for a different change, so it is kept apart from the 74 and was not in the report as sent (the report says 74).
- **Firmware provenance.** Both runs loaded the files from Ubuntu's linux-firmware snapshot 3b128b60 (package `20240318.git3b128b60-0ubuntu2.29` for E1 and the start of E3; since split into `linux-firmware-qualcomm-wireless 20240318.git3b128b60-0ubuntu3.1`, the same upstream snapshot; later boots report the same patch build 0x3e8). The earlier package is no longer on the machine, so the files were not compared byte for byte with those now installed.
- **A different symptom on another ID.** Edgard Lopes's unmerged July submission for 0b05:1825 reported SCO/eSCO audio broken on the bare ROM firmware ("corrupted SCO packet", no HFP/HSP microphone). The report states this as a different symptom.

**Not known.** What goes wrong inside the controller. Whether the command causes the hang or only finds it (not decidable from the host side). Whether the rampatch, the NVM, or BTUSB_QCA_ROME's other host-side effects (shutdown handler, set_bdaddr, the simultaneous-discovery quirk, the reset-resume check; all kept by the diagnostic build) account for the cure: the evidence does not separate them. The failure rate on ROM firmware: there is no count of ROM-firmware links that did not fail, and the report says so. Whether this is a known erratum.

**Source facts used in the reply** **[source]**: the controller answers `QCA_GET_TARGET_VERSION` with `rom_version 0x00000302`, and mainline `btusb_main.c` (line 3616) has `{ 0x00000302, 28, 4, 16 }, /* Rome 3.2 */` in `qca_devices_table`. btusb lists three QCA9377 modules as `BTUSB_QCA_ROME`: 04ca:3015 (commit `0a03f98b98c20`, "from a QCA9377 board"), 0cf3:e500 (`0324d19cb9980`, "from a QCA9377 board") and 13d3:3503 (`dc16388d45ec`, "IMC Networks Qualcomm Atheros QCA9377 Bluetooth controller"). The kernel's UART driver maps `qcom,qca9377-bt` (no `.data`) to `QCA_ROME` (`hci_qca.c`, lines 2785 and 2423-2426 on mainline). linux-firmware's WHENCE lists `rampatch_usb_00000302.bin` and `nvm_usb_00000302.bin` under "btqca - Qualcomm Atheros Bluetooth support for QCA61x4 USB chips" (lines 5037-5052 at commit `bda6ecc`).

### The mails

Three items: the report as sent, Zijun Hu's reply, and our reply draft v3. The report went through ten outside review rounds before the send; its facts were each checked against logs and exhibits.

**Zijun Hu's reply**, Thu 29 Oct 2026 18:42 +0800, to us and the list, with our recipients in copy, quoting our two questions, in full:

> QCA9377 is not ROME(QCA6174A), btusb driver does not support it, linux-firmware repo also does not have firmware it.
>
> See table @qca_devices_table for supported controllers from ROME.

That is Qualcomm's product view. It does not by itself contradict the kernel facts above (the module name versus what the controller reports, the three QCA9377 IDs already marked ROME in btusb, the files that load), but it differs from them in wording, and the reply draft asks about exactly that.

**Reply draft history.** The first draft (2026-10-29) identified the Bluetooth part as a Rome 3.2 (QCA6174A) core and cited `dc16388d45ec` for "QCA9377 is the module's name"; an outside reviewer found that `dc16388d45ec` calls it "the IMC Networks Qualcomm Atheros QCA9377 Bluetooth controller", so the claim was wrong and the draft was replaced. v2 (2026-11-01) acknowledged his point and asked "Is that acceptable to Qualcomm for these QCA9377 modules?" v3 is below.

**What changed from v2, and why:**

1. The opening no longer restates "QCA9377 is not a ROME part" as an agreed fact; it acknowledges his classification and the missing QCA9377-specific USB firmware image (outside reviewers).
2. "Is that acceptable to Qualcomm?" became a technical question about the intended initialization and firmware for the three QCA9377 IDs (outside reviewers).
3. The measurements are stated to come from 13d3:3503 only; the other two IDs come from the driver table (an outside reviewer).
4. One wording edit on 2026-11-02 (an outside reviewer; checked in btusb): the kernel's own line is `QCA: patch rome 0x... build 0x..., firmware rome 0x... build 0x...`, where "build" is the patch-version field. The v2 text said "patch version" in one place and "ROM build 0x111" in another; the erratum paragraph now uses one name for the field throughout ("patch version 0x111"). The report as sent said "build 0x111"; the reply uses the clearer name.

Recipients and threading are unchanged from v2: it replies to his message (In-Reply-To and References set), To Zijun Hu and linux-bluetooth; Cc Marcel Holtmann, Luiz Augusto von Dentz, Shuai Zhang, Bartosz Golaszewski, Tibor Harcsa (seven in all, as for the report).

### The mails, verbatim

#### The report as sent (2026-10-29)

Headers: To linux-bluetooth; Cc Marcel Holtmann, Luiz Augusto von Dentz, Zijun Hu, Shuai Zhang, Bartosz Golaszewski, Tibor Harcsa. The sent body is byte-identical to the list archive's stored copy (SHA-256 compared). The mail ends with a link to a page of kernel log extracts with the commands that produced them; the link is replaced here by a note.

```text
Subject: [REPORT] btusb: QCA9377 13d3:3503 on ROM firmware: HCI hang
 during mSBC SCO

Hi,

A report with two questions, mainly for Qualcomm; not a patch. For
13d3:3503 the kernel side is already fixed: dc16388d45ec ("Bluetooth:
btusb: Add IMC Networks QCA9377 to quirks table") is in v7.3 and in
stable releases, so I am not asking for another fix for this ID. The
entry was sent for BLE-scan errors; in my tests it also avoided the
controller-wide hang below.

Summary
-------
Without a btusb entry this QCA9377 runs its ROM firmware (ROM 0x302,
build 0x111). In twelve recorded failures, the first HCI command
issued after a transparent (mSBC) SCO link came up got no reply, and
later commands timed out too. With the QCA setup path, which loads
qca/rampatch_usb_00000302.bin and qca/nvm_usb_00000302.bin, 74 SCO
links logged no command timeout. What goes wrong inside the
controller I do not know.

Questions
---------
1. Is this known for ROME ROM 0x302 build 0x111? Is there an erratum,
   an affected ROM range, or a rampatch/NVM revision that addresses
   it?

2. Is there a list of ROME-based USB IDs, or a reliable way to
   identify such adapters, that could be compared with btusb's table?
   This year three were added one at a time, each after a user ran
   into the 0x2005 BLE-scan errors: 13d3:3503 (dc16388d45ec),
   0b05:1868 (d54601f21faf) and 0b05:1825 (cfa67a1dbfd9). An
   earlier, unmerged submission for 0b05:1825 (2026-07-21) also
   reported SCO audio broken on the ROM firmware ("corrupted SCO
   packet", no HFP microphone).

On the ROM firmware
-------------------
The device has isochronous alternate settings 1-5 (wMaxPacketSize
9/17/25/33/49) and no alt 6. On the transparent links recorded here
btusb selected alt 1 (read live from sysfs), and the captures show
each 27-byte SCO buffer sent as three 9-byte USB packets. Setup
Synchronous Connection (0x0428) is answered and the link streams.
One of the twelve failures (kernel log, Bluetooth dynamic debug on;
"evt 5" is HCI_NOTIFY_ENABLE_SCO_TRANSP in btusb_notify()):

  02:09:36.646940 hci0 opcode 0x0428 plen 17
  02:09:36.718906 hci0 evt 5
  02:09:44.049893 hci0: handle 0x06 reason 0x13
  02:09:44.049956 hci0: Opcode 0x0406
  02:09:46.067797 Bluetooth: hci0: command 0x0406 tx timeout

Here the stream ran about 7.3 s before the Disconnect. In all twelve
failures the first command after link-up timed out about 2 s after
it was issued; where the delay from link-up is recorded, it was
34 ms to 9.65 s. The command was 0x0406 Disconnect in six, 0x0c1a
Write Scan Enable in one, the bare "command tx timeout" in five.
Whether the command causes the hang or only finds it, I cannot tell
from the host side.

No later command was answered. In one failure I probed the USB side:
two GET_DESCRIPTOR transfers timed out with -110 while the device
stayed enumerated. Removing power recovered the controller; a warm
reboot did not always.

The twelve were on Ubuntu 7.0.0-29, -30, -31 and -34 kernels with
stock btusb and three headset models from three vendors. I have no
count of ROM-firmware links that did not fail, so no failure rate.

With the QCA setup path
-----------------------
Before setup the controller reports ROM 0x302, build 0x111 and a
status with neither QCA_PATCH_UPDATED nor QCA_SYSCFG_UPDATED set, so
btusb_setup_qca() loads both files; both loads return 0, and a later
version read reports patch build 0x3e8. On the same laptop, across
the same three headset models, 74 SCO links then logged no command
timeout: 50 mSBC, still on alt 1 with the legacy 0x0428
(btusb_setup_qca() sets HCI_QUIRK_BROKEN_ENHANCED_SETUP_SYNC_CONN),
and 24 CVSD. Of these,

  58 ran on a diagnostic build giving this ID BTUSB_QCA_ROME without
     BTUSB_WIDEBAND_SPEECH and without the reset callback, so no
     reset could have hidden a timeout;
  16 ran with the exact dc16388d45ec entry.

This does not separate the rampatch from the NVM. Nor does it
separate the firmware from BTUSB_QCA_ROME's other host-side effects,
which the diagnostic build kept: the shutdown handler, set_bdaddr,
the simultaneous-discovery quirk and the reset-resume check.

For anyone searching the archive with a similar failure on a QCA
ROME USB controller: check whether its USB ID selects btusb's QCA
setup path and whether the rampatch and NVM load.

Kernel log extracts, with the commands that produced them:
[link to the extraction page omitted in this document]

Thanks,
Iaroslav Voitovych
```

A point flagged for the reviewer: the sent text says "across the same three headset models" for the 74 links, while the exhibit records list two headset models each for the 58 E1 links and the 16 E3 links. If the union of the two sets is three models the sentence stands; this was not re-verified here (see open points).

#### Our reply, draft v3 (NOT SENT), with the one recommended edit applied

It replies to Zijun Hu's message (threading headers set, dropped here). To Zijun Hu and linux-bluetooth; Cc Marcel Holtmann, Luiz Augusto von Dentz, Shuai Zhang, Bartosz Golaszewski, Tibor Harcsa.

```text
Subject: Re: [REPORT] btusb: QCA9377 13d3:3503 on ROM firmware: HCI hang
 during mSBC SCO

On Thu, 29 Oct 2026 at 18:42 +0800, Zijun Hu wrote:
> QCA9377 is not ROME(QCA6174A), btusb driver does not support it,
> linux-firmware repo also does not have firmware it.
>
> See table @qca_devices_table for supported controllers from ROME.

Thank you for clarifying Qualcomm's classification of QCA9377 and the
absence of a QCA9377-specific USB firmware image in linux-firmware.

The kernel side is what I am unsure about. btusb lists three QCA9377
modules with BTUSB_QCA_ROME: 04ca:3015, 0cf3:e500 and 13d3:3503. I can
measure only 13d3:3503: its ROM reports rom_version 0x00000302, so
btusb_setup_qca() loads qca/rampatch_usb_00000302.bin and
qca/nvm_usb_00000302.bin, the files linux-firmware lists for QCA61x4
USB chips, and the patch version reads 0x3e8 afterwards (0x111 before).

Is this the intended initialization and firmware for these three
QCA9377 IDs? If not, what should they use instead?

And separately: is there a known erratum affecting transparent (mSBC)
SCO in the ROM firmware that reports patch version 0x111? On its ROM
firmware the controller stopped answering HCI commands once such a
link was streaming.

Thanks,
Iaroslav Voitovych
```

### Tests and results

All numbers are in the sections above and are **[measured]** on the laptop's QCA9377 (13d3:3503), unless marked.

| item | value |
|---|---|
| Controller deaths on ROM firmware | 12 (Ubuntu 7.0.0-29, -30, -31, -34; three headset models, three vendors) |
| First command after link-up timing out | after about 2 s in all 12; delay from link-up 34 ms to 9.65 s where recorded |
| Commands that died | 0x0406 Disconnect (6), 0x0c1a Write Scan Enable (1), unnamed "command tx timeout" (5) |
| USB probe | in one failure two GET_DESCRIPTOR transfers timed out (-110), device still enumerated; another failure left alone for 12 h 34 min: still enumerated, USB layer silent, every later command timed out |
| Recovery | removing power; a warm reboot did not always |
| Links with the QCA setup path in E1 + E3 | 74: 50 mSBC + 24 CVSD; 58 (E1) on the diagnostic build, 16 (E3) with the exact `dc16388d45ec` entry; 0 command timeouts |
| E3 #3 journal ledger (not in the report) | 63 links, 63 hang-ups answered, 0 timeouts, 2026-10-23 to 2026-10-29; ran with an additional unrelated test module; stands apart from the 74 |
| Firmware | before setup: ROM 0x302, patch 0x111, status 0x20; after: patch 0x3e8, status 0xe0; both loads return 0 |

### Not known, not claimed

- No cause inside the controller is claimed. At the host level: with the entry the hang did not recur in 74 links (and in the 63-link ledger).
- No failure rate on ROM firmware (no count of non-failing ROM-firmware links).
- The 74 and the 63 are one laptop, one controller, a few headsets; not a population statement. "Users are covered" was cut from the report as too broad.
- The rampatch is not separated from the NVM, nor from BTUSB_QCA_ROME's other host-side effects.
- Whether Qualcomm has an erratum for this ROM version is unknown; Qualcomm may not answer an erratum question on a public list, so silence says nothing.
- Qualcomm's classification (QCA9377 is not ROME) and the kernel's (three QCA9377 IDs marked ROME; files for ROM 0x302 load and work on one of them) are both stated and not reconciled; the reply asks about it.
- 13d3:3504 was dropped from the report after a reviewer found it is a Broadcom part. A paragraph on "197 versus 202 supported commands" was cut as misleading.

### Open points and questions for the reviewer

1. Does draft v3 ask the right questions? Is "Is this the intended initialization and firmware for these three QCA9377 IDs?" better asked of the btusb maintainers than of Qualcomm, and is it reasonable to send it as a reply on the same thread?
2. Is the erratum question, with "patch version 0x111" used for the field the kernel prints as `build`, understandable to Qualcomm engineers? (The sent report said "ROM 0x302, build 0x111".)
3. Should a reply be sent at all if Qualcomm is unlikely to answer on the list? The alternative is one reminder to the report after three weeks, as planned if nothing came.
4. The sent report says "across the same three headset models" for the 74 links, while the exhibit records show two models each for E1 and E3 (see above). Is a correction needed in the next mail?
5. Is "in stable releases" accurate enough for `dc16388d45ec`, given that the older lines were release candidates when it was written?

### Route and next step

Reply draft v3 is written; mail-lint and the header check against Zijun Hu's message pass (reply-all covers the same seven recipients). **Not sent; waiting for the submitter's word.** If yes: the one-paragraph edit shown above is already in the text, a dry run checks the recipient list as for the original report, and the submitter sends it. If nothing comes within three weeks of the report (about 2026-11-19), one reply to our own mail. No hardware test is needed before replying.

## CO-04 — Bluetooth: MGMT: Fix use-after-free in mesh_send_sync()

### At a glance

| | |
|---|---|
| Target | net/bluetooth/mgmt.c. The patch is written against bluetooth-next 1081a6ef8f1e0. mgmt.c at the 2026-11-01 tip differs only by an unrelated hunk at line 8177, so it should still apply (inferred; a git am on the newer tip was not run). |
| Report it answers | syzbot: "KASAN: slab-use-after-free Read in mesh_send_sync". Open. One crash on 2026-10-03; a retest on 2026-10-17 on an upstream commit still reports it. |
| State on 2026-11-02 | One patch, written and tested, not sent. The list bot's checks pass when run locally (details below). |
| Asked of the reviewer | Is the hand-over under hdev->lock complete? Is the lock order acceptable? Questions are in the second-to-last section. |

### Background

Conventions. "Measured" means a number from a run we made, with the setup named. "From source" means a quotation or reading of a named tree and file:line. "Inferred" means reasoning that no run or quotation backs. "bluetooth-next 1081a6ef8f1e0" is bluetooth-next as fetched on 2026-10-29. "bluetooth-next 42b8c2d729268" is bluetooth-next as fetched on 2026-11-01. Between those two commits net/bluetooth/mgmt.c differs only in one unrelated hunk around line 8177, in load_conn_param() (measured with git diff of the two commits).

Test setup common to all items: QEMU/KVM guests (4 CPUs for CO-04 and CO-05), BlueZ test-runner, BlueZ's emulated controller, kernel configs from BlueZ's tester.config, with KASAN and lockdep where stated. No result in this section comes from a physical controller.

MGMT Mesh Send (`mesh_send()` in net/bluetooth/mgmt.c) allocates a `struct mgmt_mesh_tx` and links it on `hdev->mesh_pending`. If `HCI_MESH_SENDING` is clear, it queues `mesh_send_sync()` on the cmd_sync worker for that entry. When the start succeeds, a delayed work (`mesh_send_done`) later queues `mesh_send_done_sync()`. That function completes the transmission and hands over to the next pending one through `mesh_next()`. `HCI_MESH_SENDING` means "a start is queued or a transmission is on air".

`hci_cmd_sync_queue()` does not look for an existing entry with the same data pointer. `hci_cmd_sync_queue_once()` does, but it is not used here (from source, hci_sync.c around line 753).

### Root cause

All quotations are from bluetooth-next 1081a6ef8f1e0, net/bluetooth/mgmt.c.

`mesh_send()` tests the flag under `hdev->lock`, which it takes at line 2522 (from source):

```c
2535	sending = hci_dev_test_flag(hdev, HCI_MESH_SENDING);
2536	mesh_tx = mgmt_mesh_add(sk, hdev, send, len);
2538	if (!mesh_tx)
2539		err = -ENOMEM;
2540	else if (!sending)
2541		err = hci_cmd_sync_queue(hdev, mesh_send_sync, mesh_tx,
2542					 mesh_send_start_complete);
```

The worker side clears the flag without `hdev->lock`. Only then does it complete the finished request, and `mesh_next()` follows as the destroy callback (from source):

```c
1098 static int mesh_send_done_sync(struct hci_dev *hdev, void *data)
1099 {
1100	struct mgmt_mesh_tx *mesh_tx;
1102	hci_dev_clear_flag(hdev, HCI_MESH_SENDING);
1103	if (list_empty(&hdev->adv_instances))
1104		hci_disable_advertising_sync(hdev);
1105	mesh_tx = mgmt_mesh_next(hdev, NULL);
1107	if (mesh_tx)
1108		mesh_send_complete(hdev, mesh_tx, false);
```

```c
1115 static void mesh_next(struct hci_dev *hdev, void *data, int err)
1117	struct mgmt_mesh_tx *mesh_tx = mgmt_mesh_next(hdev, NULL);
...
1122	err = hci_cmd_sync_queue(hdev, mesh_send_sync, mesh_tx,
1123				 mesh_send_start_complete);
```

The failed-start path in `mesh_send_start_complete()` does the same, again without `hdev->lock` (from source):

```c
2316	if (mgmt_err) {
2317		hci_dev_clear_flag(hdev, HCI_MESH_SENDING);
2318		/* Send Complete Error Code for handle */
2319		mesh_send_complete(hdev, mesh_tx, false);
2320		if (err != -ECANCELED)
2321			mesh_next(hdev, NULL, 0);
```

The sequence below is inferred from the quotations and not reproduced. After the worker clears the flag and before `mesh_next()` queues the head, a concurrent `mesh_send()` sees the flag clear. It queues a start for the entry it has just added. If that entry is the head of `hdev->mesh_pending`, `mesh_next()` then queues a second start for the same pointer. If the first start fails, `mesh_send_start_complete()` frees the entry through `mesh_send_complete()` and `mgmt_mesh_remove()`, and the second start reads the freed object. If the first start succeeds instead, the same packet is started twice.

Consistency with syzbot's report (from the report text and source):
- The object is allocated in `mesh_send()` through `mgmt_mesh_add()`, freed in `mesh_send_start_complete()` on the `hci_cmd_sync_work` worker, and read by `mesh_send_sync()` on the same worker.
- The read is 59 bytes into a 96-byte object.
- The `struct mgmt_mesh_tx` layout (net/bluetooth/mgmt_util.h) is: list at 0–15, index 16, param_len 24, sk 32, handle 40, instance 41, param from 42. The `struct mgmt_cp_mesh_send` layout is: addr 6, type 1, instant 8, delay 2, cnt 1.
- With that layout, offset 59 is `param + 17`, which is `send->cnt`. That is the first field `mesh_send_sync()` reads (`duration = send->cnt * INTERVAL_TO_MS(...)`, mgmt.c:2343).
- syzbot's retest of 2026-10-17 shows the start failing with `Opcode 0x2008 failed: -110` just before the report.

Where `-ECANCELED` comes from (from source in hci_sync.c of the time; inferred for the in-flight cases):
- `mesh_send_start_complete()` is called with `-ECANCELED` only from `_hci_cmd_sync_cancel_entry()`.
- Its callers (`hci_cmd_sync_clear()`, `hci_cmd_sync_cancel_entry()`, `hci_cmd_sync_dequeue()`, the create-connection cancels) all hold `hdev->cmd_sync_work_lock`.
- The in-flight `hci_cmd_sync_cancel(hdev, ECANCELED)` calls are guarded to a connection's own create command, so `mesh_send_sync()` does not return `-ECANCELED` itself.
- MGMT takes `hdev->lock` and then calls `hci_cmd_sync_queue()`, which takes `cmd_sync_work_lock`. Taking `hdev->lock` inside the callback on `-ECANCELED` would invert that order.

### The change

- `mesh_next(hdev)` becomes a plain function called with `hdev->lock` held (`lockdep_assert_held`).
  - It queues the start of the head and sets `HCI_MESH_SENDING`, or clears the flag when nothing is pending.
  - A head whose start cannot be queued, for example `-ENETDOWN` after power off, is completed and the next one is tried. The old code completed only the head and left the rest pending (question 2 below).
- `mesh_send_done_sync()` sends its HCI command first, then takes `hdev->lock`, completes the head and calls `mesh_next()`.
  - It no longer clears the flag first and has no destroy callback.
  - As a result `hci_cmd_sync_clear()` no longer reaches `hci_cmd_sync_queue()` through `mesh_next()` at unregister.
- `mesh_send_start_complete()`:
  - On `-ECANCELED` it only completes the request, as before, without `hdev->lock`. From `send_cancel()` the lock is already held.
  - On any other error it takes `hdev->lock`, completes the request and hands over through `mesh_next()`.
- `send_cancel()` holds `hdev->lock` throughout. It hands over when it dequeued a queued start or found the flag clear (the old condition).
- Lock order used: req_lock, then hdev->lock, then (unregister_lock, cmd_sync_work_lock). This is the order `mesh_send()` and `hci_clear_adv_sync()` already use (from source). Nothing takes `hdev->lock` under `cmd_sync_work_lock`, and no HCI command is sent under `hdev->lock`.

An earlier proposal for the same report exists (patchwork 14888791, 2026-10-14).
- It does not apply on top of this patch.
- Applied alone to bluetooth-next 1081a6ef8f1e0 and run in the same guests, it produced a lockdep "possible circular locking dependency" report in 8 of 12 boots of the power-off test set. Base and this patch gave 0 of 12.
- The report names `hdev->lock` taken in `mesh_send_start_complete()` while `hdev->cmd_sync_work_lock` is held by `hci_cmd_sync_clear()`.
- An earlier run of the same test on bluetooth-next 27731ba09195 gave 9 of 12.

Cen Zhang's patch 14927631 (2026-10-30, "Bluetooth: hci_sync: Fix remaining advertising instance UAFs", pending) changes the same area in one respect.
- In `mesh_send_sync()` it takes `hdev->lock` around `hci_add_adv_instance()`. It also takes the lock in many other places in hci_sync.c.
- Its mgmt.c hunks touch `mesh_send_sync()` (around line 2341), `adv_expire_sync()` and `set_advertising_complete()`.
- This patch's hunks are in `mesh_send_done_sync()` and `mesh_next()`, in `mesh_send_start_complete()`, and in `send_cancel()`.
- Its mgmt.c pre-image blob (3cb4f9ece83cb) is the same as this patch's, and we recorded on 2026-11-01 that this patch still applies on top of 14927631. A git am of the pair was not re-run for this document. Without 14927631 the patch applies to bluetooth-next 1081a6ef8f1e0 as shown.

### The patches, verbatim

One patch. Replacements made for this document are in square brackets: the author, syzbot and stable-list addresses, and three list URLs. The URLs are replaced by patchwork numbers. Nothing else differs from the stored text.

```diff
Date: Thu, 29 Oct 2026 11:51:17 +0100
Subject: [PATCH] Bluetooth: MGMT: Fix use-after-free in mesh_send_sync()

mesh_send() tests HCI_MESH_SENDING under hdev->lock and, when it is
clear, queues mesh_send_sync() for the request it has just added.
mesh_send_start_complete(), after a failed start, and
mesh_send_done_sync() clear the flag without hdev->lock and only then
complete the finished request and call mesh_next(), which queues
mesh_send_sync() for the head of hdev->mesh_pending. A Mesh Send that
runs in between sees the flag clear and queues a start for its new
request. When that request is the head, mesh_next() queues a second
start for the same mgmt_mesh_tx, as hci_cmd_sync_queue() does not
check for duplicates. If the first start fails,
mesh_send_start_complete() frees the request and the second start
reads it:

  BUG: KASAN: slab-use-after-free in mesh_send_sync+0x3de/0x440
  Read of size 1 at addr ffff88804e2ea83b by task kworker/u34:4/5875
  Workqueue: hci0 hci_cmd_sync_work
  ...
  Freed by task 5875:
   kfree+0x22b/0x6d0 mm/slub.c:6802
   mesh_send_complete net/bluetooth/mgmt.c:1090 [inline]
   mesh_send_start_complete+0x1a1/0x210 net/bluetooth/mgmt.c:2314
   hci_cmd_sync_work+0x20a/0x4c0 net/bluetooth/hci_sync.c:338

The byte read, 59 bytes into the 96-byte object, is send->cnt. When
the first start succeeds instead, the same packet is started twice.

Keep the flag set until the decision to start the next request or to
go idle has been made, and make that decision under hdev->lock, the
lock mesh_send() tests the flag under. mesh_next() now runs with
hdev->lock held and either queues the start of the head or clears the
flag when nothing is pending. It is called from mesh_send_done_sync()
itself, after a failed start, and from send_cancel(), which also takes
hdev->lock and hands over when it dequeued the queued start or found
mesh sending idle.

hdev->lock is not taken under cmd_sync_work_lock: hci_cmd_sync_dequeue()
and hci_cmd_sync_clear() call mesh_send_start_complete() with
-ECANCELED while holding it, and MGMT calls hci_cmd_sync_queue(), which
takes it, with hdev->lock held. On -ECANCELED the callback therefore
only completes the request, as before; from send_cancel() hdev->lock
is already held. mesh_send_done_sync() no longer has a destroy
callback, so hci_cmd_sync_clear() no longer calls hci_cmd_sync_queue()
through mesh_next() at unregister. hdev->lock is not held across any
HCI command.

Fixes: b338d91703fa ("Bluetooth: Implement support for Mesh")
Reported-by: syzbot [bug "KASAN: slab-use-after-free Read in mesh_send_sync", id f20755f37da70df33a16; address removed]
Closes: [syzbot bug "KASAN: slab-use-after-free Read in mesh_send_sync"; URL removed]
Cc: stable [the stable list; address removed]
Signed-off-by: Iaroslav Voitovych
---
An earlier proposal for this report, [patchwork 14888791; URL removed]
takes hdev->lock in mesh_next() and mesh_send_start_complete(), which
hci_cmd_sync_clear() calls with cmd_sync_work_lock held, while MGMT
holds hdev->lock when it calls hci_cmd_sync_queue(); lockdep reports
that order inversion. Here hdev->lock is taken only where
cmd_sync_work_lock is not held.

This conflicts textually with the pending "Bluetooth: MGMT: protect
hdev->mesh_pending with hdev->lock",
[Baul Lee, v2 2/3, 2026-08-07, patchwork 14736727 (inferred from the sequence 14736726-8); URL removed]
which uses the same -ECANCELED rule but still clears the flag before
the hand-over and no longer applies to bluetooth-next, and with
"Bluetooth: mgmt: handle mesh send completion queue failure",
[Jiale Yao, patchwork 14864878; URL removed]
which calls mesh_next() with its old arguments.

Not tested with syzbot's reproducer; the analysis is from the report
and the source. Tested on bluetooth-next 1081a6ef8f1e0 in a 4 CPU QEMU
guest with BlueZ's emulated controller, KASAN and lockdep:
mgmt-tester (515 cases) and mesh-tester (10) pass with the patch, and
a set of mesh transmit tests (queueing, cancel, power off, socket
close, controller removal; 48 boots per kernel) gives the same results
with and without it, apart from timing-dependent cases that also vary
between unpatched runs. No lockdep, KASAN or WARNING report, so the
new lockdep_assert_held() did not fire; KCSAN, 20 boots, reported
nothing in the changed functions.

 net/bluetooth/mgmt.c | 96 +++++++++++++++++++++++++++++++-------------
 1 file changed, 68 insertions(+), 28 deletions(-)

diff --git a/net/bluetooth/mgmt.c b/net/bluetooth/mgmt.c
index 3cb4f9ece83cb..0d78bd65f2239 100644
--- a/net/bluetooth/mgmt.c
+++ b/net/bluetooth/mgmt.c
@@ -1095,37 +1095,53 @@ static void mesh_send_complete(struct hci_dev *hdev,
 	mgmt_mesh_remove(mesh_tx);
 }
 
-static int mesh_send_done_sync(struct hci_dev *hdev, void *data)
+static int mesh_send_sync(struct hci_dev *hdev, void *data);
+static void mesh_send_start_complete(struct hci_dev *hdev, void *data, int err);
+
+/* Queue the start of the oldest pending transmission, or mark mesh
+ * sending idle when nothing is pending. Called with hdev->lock held by
+ * whoever is done with the current transmission. HCI_MESH_SENDING stays
+ * set from the moment a start is queued until this hand-over, so
+ * mesh_send(), which tests the flag under the same lock, cannot queue a
+ * start of its own for an entry that is handed over here as well.
+ */
+static void mesh_next(struct hci_dev *hdev)
 {
 	struct mgmt_mesh_tx *mesh_tx;
 
-	hci_dev_clear_flag(hdev, HCI_MESH_SENDING);
-	if (list_empty(&hdev->adv_instances))
-		hci_disable_advertising_sync(hdev);
-	mesh_tx = mgmt_mesh_next(hdev, NULL);
+	lockdep_assert_held(&hdev->lock);
+
+	while ((mesh_tx = mgmt_mesh_next(hdev, NULL))) {
+		if (!hci_cmd_sync_queue(hdev, mesh_send_sync, mesh_tx,
+					mesh_send_start_complete)) {
+			hci_dev_set_flag(hdev, HCI_MESH_SENDING);
+			return;
+		}
 
-	if (mesh_tx)
 		mesh_send_complete(hdev, mesh_tx, false);
+	}
 
-	return 0;
+	hci_dev_clear_flag(hdev, HCI_MESH_SENDING);
 }
 
-static int mesh_send_sync(struct hci_dev *hdev, void *data);
-static void mesh_send_start_complete(struct hci_dev *hdev, void *data, int err);
-static void mesh_next(struct hci_dev *hdev, void *data, int err)
+static int mesh_send_done_sync(struct hci_dev *hdev, void *data)
 {
-	struct mgmt_mesh_tx *mesh_tx = mgmt_mesh_next(hdev, NULL);
+	struct mgmt_mesh_tx *mesh_tx;
 
-	if (!mesh_tx)
-		return;
+	if (list_empty(&hdev->adv_instances))
+		hci_disable_advertising_sync(hdev);
 
-	err = hci_cmd_sync_queue(hdev, mesh_send_sync, mesh_tx,
-				 mesh_send_start_complete);
+	hci_dev_lock(hdev);
 
-	if (err < 0)
+	mesh_tx = mgmt_mesh_next(hdev, NULL);
+	if (mesh_tx)
 		mesh_send_complete(hdev, mesh_tx, false);
-	else
-		hci_dev_set_flag(hdev, HCI_MESH_SENDING);
+
+	mesh_next(hdev);
+
+	hci_dev_unlock(hdev);
+
+	return 0;
 }
 
 static void mesh_send_done(struct work_struct *work)
@@ -1136,7 +1152,7 @@ static void mesh_send_done(struct work_struct *work)
 	if (!hci_dev_test_flag(hdev, HCI_MESH_SENDING))
 		return;
 
-	hci_cmd_sync_queue(hdev, mesh_send_done_sync, NULL, mesh_next);
+	hci_cmd_sync_queue(hdev, mesh_send_done_sync, NULL, NULL);
 }
 
 static void mgmt_init_hdev(struct sock *sk, struct hci_dev *hdev)
@@ -2314,11 +2330,22 @@ static void mesh_send_start_complete(struct hci_dev *hdev, void *data, int err)
 	/* Report any errors here, but don't report completion */
 
 	if (mgmt_err) {
-		hci_dev_clear_flag(hdev, HCI_MESH_SENDING);
+		/* -ECANCELED: the start was dequeued before it ran, by
+		 * send_cancel() or by hci_cmd_sync_clear(), both with
+		 * cmd_sync_work_lock held. hdev->lock must not be taken
+		 * under it; send_cancel() holds it already and hands over
+		 * itself.
+		 */
+		if (err == -ECANCELED) {
+			mesh_send_complete(hdev, mesh_tx, false);
+			return;
+		}
+
+		hci_dev_lock(hdev);
 		/* Send Complete Error Code for handle */
 		mesh_send_complete(hdev, mesh_tx, false);
-		if (err != -ECANCELED)
-			mesh_next(hdev, NULL, 0);
+		mesh_next(hdev);
+		hci_dev_unlock(hdev);
 		return;
 	}
 
@@ -2423,14 +2450,19 @@ static int send_cancel(struct hci_dev *hdev, void *data)
 	struct mgmt_pending_cmd *cmd = data;
 	struct mgmt_cp_mesh_send_cancel *cancel = (void *)cmd->param;
 	struct mgmt_mesh_tx *mesh_tx;
+	bool dequeued = false;
+
+	hci_dev_lock(hdev);
 
 	if (!cancel->handle) {
 		do {
 			mesh_tx = mgmt_mesh_next(hdev, cmd->sk);
 
 			if (mesh_tx) {
-				if (!hci_cmd_sync_dequeue(hdev, mesh_send_sync,
-							  mesh_tx, NULL))
+				if (hci_cmd_sync_dequeue(hdev, mesh_send_sync,
+							 mesh_tx, NULL))
+					dequeued = true;
+				else
 					mesh_send_complete(hdev, mesh_tx, false);
 			}
 		} while (mesh_tx);
@@ -2438,8 +2470,10 @@ static int send_cancel(struct hci_dev *hdev, void *data)
 		mesh_tx = mgmt_mesh_find(hdev, cancel->handle);
 
 		if (mesh_tx && mesh_tx->sk == cmd->sk) {
-			if (!hci_cmd_sync_dequeue(hdev, mesh_send_sync,
-						  mesh_tx, NULL))
+			if (hci_cmd_sync_dequeue(hdev, mesh_send_sync,
+						 mesh_tx, NULL))
+				dequeued = true;
+			else
 				mesh_send_complete(hdev, mesh_tx, false);
 		}
 	}
@@ -2447,8 +2481,14 @@ static int send_cancel(struct hci_dev *hdev, void *data)
 	mgmt_cmd_complete(cmd->sk, hdev->id, MGMT_OP_MESH_SEND_CANCEL,
 			  0, NULL, 0);
 
-	if (!hci_dev_test_flag(hdev, HCI_MESH_SENDING))
-		mesh_next(hdev, NULL, 0);
+	/* A dequeued start was the next transmission and nobody else will
+	 * hand over for it. A cancelled transmission that is already on air
+	 * is handed over by mesh_send_done_sync().
+	 */
+	if (dequeued || !hci_dev_test_flag(hdev, HCI_MESH_SENDING))
+		mesh_next(hdev);
+
+	hci_dev_unlock(hdev);
 
 	return 0;
 }

base-commit: 1081a6ef8f1e0661fd52eb3f878691b0b96cdff9
-- 
2.43.0
```

### Tests and results

No reproducer was used; the fix rests on source analysis, syzbot's report text, lock assertions, and the unmodified testers on base against base plus fix.

What the runs show, and what they do not:
- They show that the fix's locking holds on every test path (lockdep, with the new `lockdep_assert_held()` in `mesh_next()`).
- They show that the fix changes no tester verdict and adds no KASAN or KCSAN report.
- They show that the fix lacks the lock-order inversion of the earlier proposal.
- They do not show that the use-after-free is gone. That rests on the reading above.

All figures are measured: QEMU, 4 CPUs, BlueZ emulated controller, bluetooth-next 1081a6ef8f1e0. The images were:
- base, with KASAN and lockdep;
- base plus this patch;
- base plus this patch plus CO-05's two superseded patches;
- base plus patchwork 14888791 as posted, for comparison only;
- KCSAN builds of the first three.

| set | boots per image | base | + this patch | + this patch and the CO-05 pair | + 14888791 |
|---|---|---|---|---|---|
| BlueZ master mesh-tester (10 cases), 3 runs | 3 | 8/10 | 8/10 | 8/10 | not run |
| local mesh transmit tests, power-off set (10 cases): lockdep "circular locking" reports | 12 | 0 | 0 | 0 | 8 |
| device-removal set (6 cases) | 12 | 72/72 case runs | 72/72 | 72/72 | 72/72 |
| device-removal sweep (14 cases) | 5 | 70/70 | 70/70 | 70/70 | not run |
| socket-close set (4 cases) | 5 | 20/20 | 20/20 | 20/20 | not run |
| any KASAN, WARNING, BUG or hung-task report, any boot of any set | all | 0 | 0 | 0 | 0 |

- Every line for the patched images reads: lockdep circular 0, KASAN 0, WARNING 0, BUG 0, KCSAN 0, hung task 0. `lockdep_assert_held()` reports as a WARNING, so "WARNING 0" means the new assertion never fired. `mesh_next()` runs after every completed transmission.
- Case pass rates differ between images only in power-off timing sweeps ("off at deadline 70/75/80 ms", "backlog 2 off 300 ms"). Those also vary among runs of the unpatched base; one case was 1/3 on base and 3/3 patched in different runs.
- Several cases of the local set fail identically on every kernel, patched or not, because they were written for a different design.
- The earlier proposal, patchwork 14888791 on 1081a6ef8f1e0, gave lockdep "possible circular locking dependency" in 8 of 12 boots. Quoted: `trying to acquire lock: (&hdev->lock){+.+.}-{4:4}, at: mesh_send_start_complete+0x12c/0x1f0` and `but task is already holding lock: (&hdev->cmd_sync_work_lock){+.+.}-{4:4}, at: hci_cmd_sync_clear+0xdc/0x360`.
- KCSAN, 20 boots per image:
  - This patch alone: reports naming mesh or advertising code in 3 boots. All were in the unlocked `hci_add_adv_instance()` call from `mesh_send_sync()`, which is CO-05's subject and untouched by this patch.
  - With the CO-05 pair: 1 boot, in `hci_add_adv_instance / hci_find_adv_instance`, not mesh-own.
  - No report in any of 130 KCSAN boots names `mesh_send_done_sync`, `mesh_next`, `mesh_send_start_complete`, `send_cancel` or `mgmt_mesh_*`.
- Which runs reach which paths is inferred from case names and code. No function trace was taken on these paths.
  - Hand-over or go-idle in `mesh_send_done_sync()`: every completed transmission.
  - `-ECANCELED` from `hci_cmd_sync_dequeue()` under `send_cancel()`'s lock: the cancel set ("cancel held start", "cancel queued").
  - `-ECANCELED` from `hci_cmd_sync_clear()` at removal: the removal set ("with backlog").
  - The queue-failure loop in `mesh_next()` (`-ENETDOWN` after power off): the power-off set.
  - `send_cancel()` hand-over when the flag is clear: the cancel set.
  - The error branch of `mesh_send_start_complete()` with its locked hand-over: not driven by these runs, read in the diff only.
- Submission checks (measured, local):
  - checkpatch reports 0 errors, 0 warnings, 0 checks.
  - The W=1 -Werror build is clean.
  - No new sparse finding.
  - The list bot's own checks, run locally on the final mail, all pass: CheckPatch, VerifyFixes, VerifySignedoff, GitLint, SubjectPrefix, BuildKernel, CheckAllWarning, CheckSparse, BuildKernel32, CheckKernelLLVM, TestRunnerSetup, TestRunner_mgmt-tester (515 of 515), TestRunner_mesh-tester (10 of 10), IncrementalBuild.
  - GitLint failed once on an 89-column quoted line. The file:line suffix of the BUG line was dropped and the checks were re-run.
  - The bot's base-side run was not completed, so there is no base/patched difference to attribute.

### Not known, not claimed

- No run shows that the use-after-free no longer happens. The sequence in "Root cause" is inferred from syzbot's report and the source.
- No run shows that the double start (the same packet started twice when the first start succeeds) is gone, other than the reading of the code.
- `-ECANCELED` from `hci_cmd_sync_clear()` at removal still completes queued starts without `hdev->lock`, as in the base code. The patch removes the lock-order half of that problem (the destroy callback queuing work under `cmd_sync_work_lock`), not the unlocked completion.
- `mesh_send_done_sync()` completes the head of the list, which need not be the request that was on air (a cancelled active request, or an entry left behind by another path). Unchanged.
- `mesh_send_done()` ignores a failed `hci_cmd_sync_queue()`. Unchanged.
- Whether the patch also covers the read of freed memory inside `mesh_send_start_complete()` itself, a separate read path from the one in syzbot's report, has not been re-checked in source yet.
- A read of a freed entry in `mesh_send()`'s `mgmt_cmd_complete()` is argued from the diff only: the free in the start-error branch is now under `hdev->lock`, which `mesh_send()` holds. No run shows it.
- Not tested on hardware.
- `Closes:` points at syzbot's bug, but syzbot has not tested the patch.

### Open points and questions for the reviewer

1. Is the hand-over under `hdev->lock` complete? Can any path still queue a second `mesh_send_sync()` for one `mgmt_mesh_tx`, or free one whose start is queued?
2. `mesh_next()` now completes every pending request whose start cannot be queued (for example after power off), where the old code completed only the head. Keep this, or keep the old behaviour and leave the rest pending?
3. `-ECANCELED` from `hci_cmd_sync_clear()` still completes the request without `hdev->lock`, as before. Is that acceptable for a stable fix, with a drain under the lock as later work?
4. The notes below the `---` line describe the earlier proposal (patchwork 14888791) and the textual conflicts with two other pending patches in technical terms only. Are the length and tone right, or should they go?
5. `Closes:` for a report that syzbot has not tested against this patch: keep it, or use `Link:` instead?
6. Open option, for the submitter's decision: add a `Link:` to Baul Lee's public report of 2026-08-07 of the same crash pattern on the `mesh_send()` path.
   - The report is the KASAN trace "slab-use-after-free in mgmt_cmd_complete ... mesh_send_start_complete" that accompanies his series (the patch "Bluetooth: MGMT: protect hdev->mesh_pending with hdev->lock").
   - The `Link:` would come with one sentence saying the fix closes that path too.
   - That answers the maintainer's likely question ("one Closes: for a fix that closes two defects").
   - The wording of that report comes from our recorded notes; its full text was not re-read for this document.
   - Whether the sentence is justified depends on the unchecked point above.
7. If both patches are accepted, does the order of this patch and Cen Zhang's 14927631 matter to the maintainers?

### Route and next step

State on 2026-11-02: written, tested locally, not sent.
- The patch is to be sent by its author to the Bluetooth maintainers (Marcel Holtmann, Luiz Augusto von Dentz) and the linux-bluetooth and linux-kernel lists. The syzbot report's address goes on Cc, as usual for a syzbot fix. `Cc: stable` stays a tag, not a recipient.
- get_maintainer also names Brian Gix (the blamed Fixes commit). Whether to add him is open.
- This patch is independent of the earlier proposal and is sent as a standalone patch.
- Next steps: collect the answers to the questions above, apply them, rebase on the then-current bluetooth-next, re-run the list bot's checks, then send.

---

## CO-38 — Bluetooth: MGMT: Fix Read Advertising Features hiding instances

### At a glance

| | |
|---|---|
| Target | net/bluetooth/mgmt.c, `read_adv_features()` |
| State on 2026-11-02 | One-line fix written and tested with a new mgmt-tester case. Not sent. Found by CO-12's tests. No earlier patch found by subject search. |
| Asked of the reviewer | Is the comparison against `le_num_of_adv_sets` right, as the comment says? Is it fine as a stand-alone patch? |

### Background

MGMT Read Advertising Features returns the list of instance numbers. Instance numbers above the controller's number of advertising sets (`le_num_of_adv_sets`) are internal. Since the mesh commit b338d91703fa (2022), the mesh packet's instance is numbered `le_num_of_adv_sets + 1` and must not be reported. The function is meant to skip exactly those.

### Root cause

bluetooth-next 1081a6ef8f1e0, net/bluetooth/mgmt.c:8860-8872 (from source). The same lines are at 8862-8863 in the mainline commit cbbddb6b08cc we compared against.

```c
	rp->num_instances = hdev->adv_instance_cnt;

	instance = rp->instance;
	list_for_each_entry(adv_instance, &hdev->adv_instances, list) {
		/* Only instances 1-le_num_of_adv_sets are externally visible */
		if (adv_instance->instance <= hdev->adv_instance_cnt) {
			*instance = adv_instance->instance;
			instance++;
		} else {
			rp->num_instances--;
			rp_len--;
		}
	}
```

The comment says "1-le_num_of_adv_sets", but the comparison is with `adv_instance_cnt`, the number of instances currently present. The two agree only while the instance numbers are exactly 1 to n.

With instances 1 and 2 added and instance 1 removed (for example by its timeout), `adv_instance_cnt` is 1. Instance 2 is then left out of the reply, with no Advertising Removed event for it. The code is from b338d91703fa, present from 6.1.y to bluetooth-next.

### The change

Compare with `hdev->le_num_of_adv_sets`, as the comment says. One line.

### The patches, verbatim

Fix. The author address was removed; otherwise as stored. The stored base-commit is the CO-12 patch A commit in our test stack. The mgmt.c blob it applies to is the one of bluetooth-next 42b8c2d729268, so it does not depend on patch A.

```diff
Date: Sun, 1 Nov 2026 18:52:36 +0100
Subject: [PATCH] Bluetooth: MGMT: Fix Read Advertising Features hiding
 instances

read_adv_features() means to hide only the mesh instance, which is
numbered one past the controller's advertising sets, but it compares
each instance number with the number of instances instead of the number
of sets. Whenever the instance numbers are not 1 to n, an instance is
left out: with instances 1 and 2 added and instance 1 removed, for
example after its timeout, instance 2 is no longer reported.

Compare with le_num_of_adv_sets, as the comment says.

Fixes: b338d91703fa ("Bluetooth: Implement support for Mesh")
Signed-off-by: Iaroslav Voitovych
---
 net/bluetooth/mgmt.c | 2 +-
 1 file changed, 1 insertion(+), 1 deletion(-)

diff --git a/net/bluetooth/mgmt.c b/net/bluetooth/mgmt.c
index cf5256f4a89e6..f948ebb657df6 100644
--- a/net/bluetooth/mgmt.c
+++ b/net/bluetooth/mgmt.c
@@ -8866,7 +8866,7 @@ static int read_adv_features(struct sock *sk, struct hci_dev *hdev,
 	instance = rp->instance;
 	list_for_each_entry(adv_instance, &hdev->adv_instances, list) {
 		/* Only instances 1-le_num_of_adv_sets are externally visible */
-		if (adv_instance->instance <= hdev->adv_instance_cnt) {
+		if (adv_instance->instance <= hdev->le_num_of_adv_sets) {
 			*instance = adv_instance->instance;
 			instance++;
 		} else {

base-commit: 16f25111268b63f74a4a4418f801afa2cbb8babd
-- 
2.43.0
```

Its mgmt-tester case, as a BlueZ patch (BlueZ list, not the kernel list). It uses the timeout-test machinery of the preceding patch in the same BlueZ series, "mgmt-tester: Add extended advertising timeout tests". In that machinery each entry is `{ instance, timeout in seconds, expected Duration, removal expected }`, and at `check_ms` the checker verifies presence or removal. Author address removed.

```diff
Date: Sun, 1 Nov 2026 18:52:17 +0100
Subject: [PATCH 4/4] mgmt-tester: Add test for listing a remaining instance 2

Add instances 1 and 2 on an extended advertising controller, let
instance 1 expire after 1 s, and check that Read Advertising Features
still lists instance 2.
---
 tools/mgmt-tester.c | 20 ++++++++++++++++++++
 1 file changed, 20 insertions(+)

diff --git a/tools/mgmt-tester.c b/tools/mgmt-tester.c
index b44302af8..f4451fdbc 100644
--- a/tools/mgmt-tester.c
+++ b/tools/mgmt-tester.c
@@ -14400,6 +14400,23 @@ static const struct generic_data add_ext_adv_timeout_two_66_1 = {
 	.adv_timeout = &adv_timeout_two_66_1,
 };
 
+/* Once instance 1 has expired, instance 2 is the only instance left and
+ * Read Advertising Features still has to list it.
+ */
+static const struct adv_timeout_test adv_timeout_list_2 = {
+	.inst = {
+		{ 0x01, 1, 100, true },
+		{ 0x02, 0, 0, false },
+	},
+	.num_inst = 2,
+	.check_ms = 2500,
+};
+
+static const struct generic_data add_ext_adv_timeout_list_2 = {
+	.setup_settings = settings_powered_le,
+	.adv_timeout = &adv_timeout_list_2,
+};
+
 /* Research only, not for submission: wait for the removal of long
  * instances (about 66 s and 656 s).
  */
@@ -16165,6 +16182,9 @@ int main(int argc, char *argv[])
 	test_bredrle50_full("Add Ext Advertising - Timeout 66 s and 1 s",
 					&add_ext_adv_timeout_two_66_1, NULL,
 					test_add_adv_timeout, 5);
+	test_bredrle50_full("Add Ext Advertising - Instance 2 listed alone",
+					&add_ext_adv_timeout_list_2, NULL,
+					test_add_adv_timeout, 5);
 
 	/* Research only, not for submission */
 	test_bredrle50_full("LongAdvA-65 - Timeout 65 s (expires)",
-- 
2.43.0
```

(The "Research only" comments in this patch's context lines refer to local long-running cases that are not part of any proposed series.)

### Tests and results

Measured, QEMU, three runs per image, 128 mgmt-tester "Add" cases (113 older, 15 new; this is one of the new):
- base: 119/128. The new case "Instance 2 listed alone" fails (2.5 s), with the log message "Instance 2 missing before its timeout".
- clamp (CO-12 patch A) without this fix: 127/128. The new case is the one failure.
- clamp plus this fix: 128/128 in all three runs. The new case passes.
- Cen Zhang's series alone, and either order of series and clamp, without this fix: the new case fails (single run).
- The 10 mesh-tester cases: 8/10 on all images, unchanged.
- checkpatch --strict is clean. The fix applies to the 7.3.y, 6.18.y, 6.12.y, 6.6.y and 6.1.y trees (apply check only, not built or run there).

### Not known, not claimed

- The case runs on an extended-advertising emulator. A controller without extended advertising uses the same list code, but that configuration was not run.
- Whether any client depends on the current, wrong listing is not known.
- The absence of a prior patch is established by a subject search only.
- The Advertising Removed event that is not sent for the dropped instance is not addressed by this patch.
- Line numbers differ between trees (see Root cause).

### Open points and questions for the reviewer

1. Is a stand-alone fix with `Fixes: b338d91703fa` appropriate, and should it carry a stable tag? The stored message has none. It applies to 7.3.y through 6.1.y.
2. Should the missing Advertising Removed event for the dropped instance be treated as a separate issue?
3. Is the BlueZ test case acceptable as it is?

### Route and next step

Not sent.
- Next: the reviewer's answers.
- Then the fix goes to the kernel list as a stand-alone patch, with the stable decision made.
- The tester case goes to the BlueZ list after the BlueZ timeout-test patch it depends on.

## CO-12 — Bluetooth: hci_sync: Fix extended advertising duration overflow (M-2)

### At a glance

| | |
|---|---|
| Target | net/bluetooth/hci_sync.c, `hci_enable_ext_advertising_sync()` |
| State on 2026-11-02 | Reproduced in QEMU. A clamp patch is written in several forms: on bluetooth-next 42b8c2d729268, on top of Cen Zhang's series, for stable 7.3.y, and for stable 5.x. A BlueZ test series is written. Nothing is sent. The commit message names three possible designs and asks which is wanted. |
| Asked of the reviewer | Clamp (this patch), reject with Invalid Parameters, or a per-instance host deadline? And how to order against 14927631, which touches the same lines? |

### Background

MGMT Add Advertising and Add Extended Advertising Parameters carry an instance timeout in seconds (`__le16 timeout`, mgmt.h), so up to 65535 s. For controllers with extended advertising, the kernel passes the timeout to the controller as the `Duration` of LE Set Extended Advertising Enable. That is a 16-bit field in 10 ms units, at most 0xffff = 655.35 s. The kernel removes the instance when the controller ends the set.

Legacy advertising uses a host timer in `hci_schedule_adv_instance_sync()` and is not affected. bluetoothd runs the Timeout property of an advertisement on its own timer and leaves the MGMT timeout at 0, so it is not affected. Other MGMT clients that pass a timeout, such as `btmgmt add-adv -t`, are.

### Root cause

bluetooth-next 42b8c2d729268, net/bluetooth/hci_sync.c:1701-1707 (from source):

```c
	if (adv && adv->timeout) {
		u16 duration = adv->mesh ? adv->timeout :
					   adv->timeout * MSEC_PER_SEC;

		/* Time = N * 10 ms */
		set->duration = cpu_to_le16(duration / 10);
	}
```

For non-mesh instances `adv->timeout` is a `u16` in seconds. The mesh case, whose timeout is already in milliseconds, was fixed by Pauli Virtanen's 87a49b610708 ("Bluetooth: hci_sync: fix mesh adv timeout units", in the rebased bluetooth-next as 8a8d51eeedeb, now in mainline).

The product `timeout * 1000` is stored in a `u16`, so every timeout above 65 s wraps modulo 65536 ms. The arithmetic below is derived; measured values follow it.

| timeout | 1000 x timeout mod 65536 (ms) | Duration sent (10 ms units) |
|---|---|---|
| 65 s | 65000 | 6500 (correct) |
| 66 s | 464 | 46 (460 ms) |
| 655 s | 65176 | 6517 (65.17 s) |
| 656 s | 640 | 64 |
| 6357 s | 8 | 0 (read as "no limit") |
| 8192 s | 0 | 0 (no limit; instance never removed) |
| 65535 s | 64536 | 6453 |

- The conversion has been done this way since 10bbffa3e88e ("Bluetooth: Fix using advertising instance duration as timeout"). Per the commit message, f16a491c65d9 later changed only the guard.
- MGMT Add Advertising has no timeout cap. It checks only "powered" and "busy" (from source in an earlier tree, mgmt.c around 9108-9121).
- The field cannot hold more than 655.35 s, so a wider type alone cannot fix timeouts above that.

### The change

Compute the duration in a `u32` and limit the encoded value to 0xffff. Timeouts up to 655 s are then passed exactly. Longer timeouts end after 655.35 s instead of the requested time, which is a mitigation, not a full fix, and the commit message says so. Mesh instances are unchanged.

The notes below the `---` name three ways to handle timeouts above 655 s: clamp (this patch), reject with Invalid Parameters, or a per-instance host deadline.

Conflict with Cen Zhang's series (patchwork series 1197214): 14927631 "Bluetooth: hci_sync: Fix remaining advertising instance UAFs" 1/2 and 14927632 "Bluetooth: hci_core: Initialize advertising RPA work only once" 2/2, both pending.
- 14927631 rewrites `hci_enable_ext_advertising_sync()`. The duration is computed under `hdev->lock` into a `u16 duration = 0` at the top of the function. The later line becomes `set->duration = cpu_to_le16(duration / 10);`.
- Measured on 2026-11-01:
  - The clamp does not apply by plain git am on top of the series, and conflicts on that hunk with a three-way merge.
  - Applying the series on top of the clamp conflicts in the same hunk.
  - Resolved by hand, both orders give identical trees (git diff --stat between the two result branches is empty).
- Patch B below is the form for use on top of the series.
- The series alone does not fix the overflow: 9 of the new cases fail with the series alone, as on base.

### The patches, verbatim

Patch A, on bluetooth-next 42b8c2d729268. The author address was removed; nothing else differs from the stored text.

```diff
Date: Sun, 1 Nov 2026 01:17:27 +0100
Subject: [PATCH] Bluetooth: hci_sync: Fix extended advertising duration
 overflow

hci_enable_ext_advertising_sync() passes the instance timeout to the
controller as the Duration of LE Set Extended Advertising Enable. The
timeout comes from MGMT Add Advertising or Add Extended Advertising
Parameters in seconds, but it is converted to milliseconds in a u16, so
every timeout above 65 s wraps:

 - 66 s is sent as a Duration of 46 (460 ms), and the instance is
   removed after less than half a second
 - 655 s is sent as 6517 (65.17 s)
 - timeouts congruent to 0 or 6357 modulo 8192, 8192 s among them, are
   sent as 0, which the controller reads as no limit, so the instance
   is never removed

The conversion has been done this way since commit 10bbffa3e88e
("Bluetooth: Fix using advertising instance duration as timeout").

Compute the duration in a u32 and limit the encoded value to 0xffff.
Timeouts of up to 655 s are now passed exactly. The Duration field
cannot express more than 655.35 s, so an instance with a longer
timeout now ends after 655.35 s instead of the requested time. Mesh
instances, whose timeout is already in milliseconds, are unchanged.

bluetoothd is not affected: it runs the Timeout property of an
advertisement on its own timer and leaves the MGMT timeout at 0. Other
MGMT clients that pass a timeout, such as btmgmt add-adv -t, are.

Fixes: 10bbffa3e88e ("Bluetooth: Fix using advertising instance duration as timeout")
Signed-off-by: Iaroslav Voitovych
---
There are three ways to handle a timeout above 655 s on a controller
that uses extended advertising:

 1. Clamp it, as this patch does: the instance ends after 655.35 s.
 2. Reject it with Invalid Parameters. The MGMT timeout then always
    holds, but a request that is accepted today becomes an error.
 3. Keep a host deadline per instance and remove the instance when it
    expires. The existing expiry work serves legacy advertising, which
    advertises one instance at a time, so this needs a timer for each
    instance.

This patch takes 1 as the smallest change that stops the wrap; I can
rework it to 2 or 3 if either is preferred.

 net/bluetooth/hci_sync.c | 6 +++---
 1 file changed, 3 insertions(+), 3 deletions(-)

diff --git a/net/bluetooth/hci_sync.c b/net/bluetooth/hci_sync.c
index 9d829c20c3160..d4359653937c6 100644
--- a/net/bluetooth/hci_sync.c
+++ b/net/bluetooth/hci_sync.c
@@ -1699,11 +1699,11 @@ int hci_enable_ext_advertising_sync(struct hci_dev *hdev, u8 instance)
 	 * scheduling it.
 	 */
 	if (adv && adv->timeout) {
-		u16 duration = adv->mesh ? adv->timeout :
+		u32 duration = adv->mesh ? adv->timeout :
 					   adv->timeout * MSEC_PER_SEC;
 
-		/* Time = N * 10 ms */
-		set->duration = cpu_to_le16(duration / 10);
+		/* Time = N * 10 ms, at most 0xffff (655.35 s) */
+		set->duration = cpu_to_le16(min_t(u32, duration / 10, U16_MAX));
 	}
 
 	/* Track which instance owns the advertising set since the handle

base-commit: 42b8c2d729268a65a2d98064e8dc59ff53646b14
-- 
2.43.0
```

Patch B, the same fix on top of Cen Zhang's series. The base is be1c77fc4bcc0, which is bluetooth-next 42b8c2d729268 with the two series patches applied. Same author-address removal.

```diff
Date: Sun, 1 Nov 2026 01:17:27 +0100
Subject: [PATCH] Bluetooth: hci_sync: Fix extended advertising duration
 overflow

hci_enable_ext_advertising_sync() passes the instance timeout to the
controller as the Duration of LE Set Extended Advertising Enable. The
timeout comes from MGMT Add Advertising or Add Extended Advertising
Parameters in seconds, but it is converted to milliseconds in a u16, so
every timeout above 65 s wraps:

 - 66 s is sent as a Duration of 46 (460 ms), and the instance is
   removed after less than half a second
 - 655 s is sent as 6517 (65.17 s)
 - timeouts congruent to 0 or 6357 modulo 8192, 8192 s among them, are
   sent as 0, which the controller reads as no limit, so the instance
   is never removed

The conversion has been done this way since commit 10bbffa3e88e
("Bluetooth: Fix using advertising instance duration as timeout").

Compute the duration in a u32 and limit the encoded value to 0xffff.
Timeouts of up to 655 s are now passed exactly. The Duration field
cannot express more than 655.35 s, so an instance with a longer
timeout now ends after 655.35 s instead of the requested time. Mesh
instances, whose timeout is already in milliseconds, are unchanged.

bluetoothd is not affected: it runs the Timeout property of an
advertisement on its own timer and leaves the MGMT timeout at 0. Other
MGMT clients that pass a timeout, such as btmgmt add-adv -t, are.

Fixes: 10bbffa3e88e ("Bluetooth: Fix using advertising instance duration as timeout")
Signed-off-by: Iaroslav Voitovych
---
There are three ways to handle a timeout above 655 s on a controller
that uses extended advertising:

 1. Clamp it, as this patch does: the instance ends after 655.35 s.
 2. Reject it with Invalid Parameters. The MGMT timeout then always
    holds, but a request that is accepted today becomes an error.
 3. Keep a host deadline per instance and remove the instance when it
    expires. The existing expiry work serves legacy advertising, which
    advertises one instance at a time, so this needs a timer for each
    instance.

This patch takes 1 as the smallest change that stops the wrap; I can
rework it to 2 or 3 if either is preferred.

 net/bluetooth/hci_sync.c | 6 +++---
 1 file changed, 3 insertions(+), 3 deletions(-)

diff --git a/net/bluetooth/hci_sync.c b/net/bluetooth/hci_sync.c
index 3cff7f4da1822..b44248302c8cb 100644
--- a/net/bluetooth/hci_sync.c
+++ b/net/bluetooth/hci_sync.c
@@ -1697,7 +1697,7 @@ int hci_enable_ext_advertising_sync(struct hci_dev *hdev, u8 instance)
 	struct hci_cp_ext_adv_set *set;
 	u8 data[sizeof(*cp) + sizeof(*set) * 1];
 	u8 handle = instance;
-	u16 duration = 0;
+	u32 duration = 0;
 
 	if (instance > 0) {
 		struct adv_info *adv;
@@ -1737,8 +1737,8 @@ int hci_enable_ext_advertising_sync(struct hci_dev *hdev, u8 instance)
 
 	set->handle = handle;
 
-	/* Time = N * 10 ms */
-	set->duration = cpu_to_le16(duration / 10);
+	/* Time = N * 10 ms, at most 0xffff (655.35 s) */
+	set->duration = cpu_to_le16(min_t(u32, duration / 10, U16_MAX));
 
 	/* Track which instance owns the advertising set since the handle
 	 * alone is ambiguous when instances share handle 0x00, see

base-commit: be1c77fc4bcc06e18b38699bf83edd8916e5f883
-- 
2.43.0
```

Two more forms exist and are not reproduced.
- A stable 7.3.y form. It has no mesh ternary, because 7.3.y predates 8a8d51eeedeb. It reads `u32 duration = adv->timeout * MSEC_PER_SEC;` plus the same `min_t` line. It applies to 7.3.y, 6.18.y, 6.12.y, 6.6.y and 6.1.y and builds with W=1 on 7.3.y.
- A separate form for 5.15.y and 5.10.y, where the code is in `__hci_req_enable_ext_advertising()` (hci_request.c). It applies and builds on 5.15.y.

checkpatch --strict is clean on all four forms (0 errors, 0 warnings, 0 checks).

### Tests and results

Measured in QEMU with BlueZ's emulated extended-advertising controller. The tests are mgmt-tester built from BlueZ master plus a local test series that is not yet sent. The series adds 15 new "Add Ext Advertising" rows, one of them the CO-38 listing case, and one new mesh-tester case ("Mesh - Send (Ext Adv Duration)").

Each timeout case:
- reads the Duration the emulator receives;
- checks that the instance is still listed at 2 to 5.5 s;
- where removal is due, checks that Advertising Removed arrives between Duration x 10 ms minus 50 ms and plus 1000 ms.

Images, three runs each unless stated: base (bluetooth-next 42b8c2d729268); clamp (patch A); clamp plus the CO-38 fix; the series alone; the series with the clamp in each order.

First reproduction (earlier set of 22 "AdvDur" cases): a 66 s timeout ends after 463 ms. 6357 s and 8192 s give Duration 0 and the instance is never removed.

Duration the emulator received in the later logs:

| timeout | base | clamp |
|---|---|---|
| 66 s | 46 (460 ms) | 6600 |
| 655 s | 6517 | 65500 |
| 656 s | 64 | 65535 |
| 6357 s | 0 | 65535 |
| 8192 s | 0 | 65535 |
| 65535 s | 6453 | 65535 |

Pass/fail by image:

| case ("Add Ext Advertising - ...") | base | clamp | clamp + CO-38 fix | series alone | series and clamp, either order |
|---|---|---|---|---|---|
| Timeout 1 s (expires); 0 s; 65 s | pass | pass | pass | pass | pass |
| Timeout 66 s; 655 s; 656 s; 6357 s; 8192 s; 65535 s (6 cases) | fail | pass | pass | fail | pass |
| Timeout 1 s (Params) | pass | pass | pass | pass | pass |
| Timeout 66 s (Params) | fail | pass | pass | fail | pass |
| Timeout replaced; Timeout 1 s and 2 s | pass | pass | pass | pass | pass |
| Timeout 66 s and 1 s | fail | pass | pass | fail | pass |
| Instance 2 listed alone (CO-38) | fail | fail | pass | fail | fail |

Totals over the 128 "Add" cases of mgmt-tester (113 older, 15 new):

| image | result | runs |
|---|---|---|
| base | 119/128 (9 fail) | 3 of 3 |
| clamp | 127/128 (the one failure is the CO-38 listing case) | 3 of 3 |
| clamp + CO-38 fix | 128/128 | 3 of 3 |
| series alone | 119/128 | 1 run |
| series then clamp | 127/128 | 1 run |
| clamp then series | 127/128 | 1 run |

- The 10 mesh-tester cases give 8/10 on every image in every run. The two failing cases ("Send cancel - 1" and "Send cancel - 2") fail on base too and are unrelated.
- None of the 59 test logs contains a kernel report (KASAN, lockdep, WARNING, BUG).
- Real expiry was measured with separate long-running cases that are not for submission, one run each. With the clamp, removal came 65001, 66001, 655004 and 655354 ms after the enable, for timeouts of 65, 66, 655 and 656 s.

### Not known, not claimed

- Above 655 s the instance now ends at 655.35 s, not at the requested time. The patch is a mitigation. Which design is wanted is the question.
- Tested only on BlueZ's emulated controller, which times out at Duration x 10 ms. A real controller may differ, for example in how it ends a set at Duration 0xffff.
- The 7.3.y and 5.x forms were applied and built, not run.
- Legacy (non-extended) advertising and periodic advertising were not changed and not tested for this.
- The rework log counts "15 new mgmt cases" before the CO-38 listing case was added, while the final table has 15 rows including it. That count is not reconciled. The pass/fail table is from the final run logs.
- No record shows preflight or the list bot's checks run on the 2026-11-01 forms. Only checkpatch is recorded.

### Open points and questions for the reviewer

1. Clamp, reject (`MGMT_STATUS_INVALID_PARAMS` above 655 s), or a per-instance host deadline? The clamp is the smallest change. Rejecting turns accepted requests into errors. The host deadline is the only form in which the MGMT timeout always holds, at the cost of one timer per instance.
2. Is the documented 655.35 s limit acceptable for stable?
3. Ordering against 14927631: should this wait for it, or go first? The textual conflict exists in both orders. Patches A and B resolve it.
4. Is it fine to keep the `adv->mesh ?` ternary in the clamped line? Patch A keeps it. The 7.3.y form has none.

### Route and next step

Not sent. The commit message already names the three options.
- Next: the reviewer's answer on the design.
- Then preflight and the list bot's checks on the chosen form.
- Then send patch A or B depending on the state of 14927631.
- The BlueZ tester series goes separately to the BlueZ list.

---

## CO-05 + CO-26 — Mesh advertising list changed without hdev->lock; mesh_send_sync() loses a failed add

### At a glance

| | |
|---|---|
| Target | net/bluetooth/mgmt.c, `mesh_send_sync()` |
| State on 2026-11-02 | A send package of 2026-10-29 was written and tested, never sent. It is two patches and a cover letter, on bluetooth-next 1081a6ef8f1e0. It is superseded in part by Cen Zhang's patchwork 14927631 (2026-10-30, pending). That patch takes `hdev->lock` around `hci_add_adv_instance()` in `mesh_send_sync()` and, in our runs, removes all seven lock-assertion warnings and all the scheduler race reports. Our patch 1/2 no longer applies on top of it. A small follow-up remains. The 2026-10-29 patches below are SUPERSEDED, NOT TO BE SENT AS THEY ARE. |
| Asked of the reviewer | Is the follow-up (described below, no patch text yet) the right remainder on top of 14927631? |

### Background

`mesh_send_sync()` runs on the cmd_sync worker, which holds `req_lock` but not `hdev->lock`. It adds the mesh packet's advertising instance with `hci_add_adv_instance()`. The function's contract is stated in bluetooth-next 1081a6ef8f1e0, hci_core.c:1775 (from source): `/* This function requires the caller holds hdev->lock */`. That contract dates from commit d2609b345ebf (2015). Add Advertising runs in MGMT socket context and changes the same list and counters under `hdev->lock`. The mesh call has been unlocked since b338d91703fa (2022).

### Root cause

bluetooth-next 1081a6ef8f1e0, net/bluetooth/mgmt.c (from source):

```c
2339	if (hdev->le_num_of_adv_sets <= hdev->adv_instance_cnt)
2340		return MGMT_STATUS_BUSY;
2342	timeout = 1000;
2343	duration = send->cnt * INTERVAL_TO_MS(hdev->le_adv_max_interval);
2344	adv = hci_add_adv_instance(hdev, instance, 0, ...
...
2353	if (!IS_ERR(adv))
2354		mesh_tx->instance = instance;
2355	else
2356		err = PTR_ERR(adv);
...
2378	if (instance)
2379		return hci_schedule_adv_instance_sync(hdev, instance, true);
2381	return err;
```

There are two separate issues.

1. (CO-05) The capacity check at 2339, the add at 2344 and the walk through `hci_get_next_instance()` run without `hdev->lock`. Measured on this base:
   - With a test-only `lockdep_assert_held(&hdev->lock)` added to `hci_add_adv_instance()`, mesh-tester warned 3 times from `mesh_send_sync()`.
   - KCSAN on a 4-CPU guest reported data races between Add Advertising (locked) and `mesh_send_sync()` (unlocked). The reader was the capacity check, e.g. `BUG: KCSAN: data-race in hci_add_adv_instance / mesh_send_sync`.
   - No damage was shown: no KASAN report and no list corruption.
2. (CO-26) When `hci_add_adv_instance()` fails, the error is kept in `err` and the function carries on. It reaches `hci_schedule_adv_instance_sync()` for an instance that was never added, so `mesh_send_start_complete()` sees `-ENOENT` instead of the real error. User space gets the same Mesh Packet Complete event either way, because the status is used only as a condition in `mesh_send_start_complete()` (from source). This is an error-path cleanup, not a visible change.

The capacity check at 2339 can be stale but cannot over-fill the table. `hci_add_adv_instance()` checks again under the caller's lock (hci_core.c:1791): `if (hdev->adv_instance_cnt >= hdev->le_num_of_adv_sets || ...) return ERR_PTR(-EOVERFLOW);`. A stale check therefore causes an early BUSY or a failed locked add, not an overflow (from source analysis; a measured capacity test is not planned).

### The change

State after 14927631 (from the patch as posted): its hunk in `mesh_send_sync()` adds `hci_dev_lock(hdev)` after the `duration = ...` line, before the `hci_add_adv_instance()` call. It adds `hci_dev_unlock(hdev)` after the `cur_adv_instance` block, before `hci_schedule_adv_instance_sync()`. It covers the add and the walk, but not the capacity check at 2339, and the failed-add handling is unchanged.

What remains is a follow-up based on Cen Zhang's patch, saying so. It is not yet written as patch text:
- Move the lock so it also covers the capacity check at mgmt.c:2339, and unlock before the early `MGMT_STATUS_BUSY` return.
- Return the add's error directly (`return PTR_ERR(adv)` after unlocking) instead of carrying on to `hci_schedule_adv_instance_sync()`. This is CO-26, and the 2/2 hunk below is the model.

Of the 2026-10-29 pair, 1/2 is replaced by 14927631. 2/2 stays as the follow-up's second half.

### The patches, verbatim

SUPERSEDED, NOT TO BE SENT AS THEY ARE. Kept for reference. Replacements for this document are in square brackets (author address; one list URL).

Three other callers that change the advertising list without `hdev->lock` were deliberately not part of this series: ISO broadcast, Set LE off and the advertising timeout. 14927631 covers them too.

Cover letter:

```diff
Date: Thu, 29 Oct 2026 13:36:21 +0100
Subject: [PATCH 0/2] Bluetooth: MGMT: mesh_send_sync() and the advertising list

mesh_send_sync() adds the mesh packet's advertising instance with
hci_add_adv_instance() without hdev->lock, which that function
requires, and reads the instance count and walks the instance list
unlocked while Add Advertising changes them under the lock (1/2). When
the add fails, it carries on and schedules an instance that was never
added (2/2).

Notes:
- 1/2 takes hdev->lock after req_lock, as hci_clear_adv_sync() and
  hci_remove_adv_sync() do, and drops it before
  hci_schedule_adv_instance_sync(), which sends HCI commands. That
  function still looks the instance up without the lock; it is shared
  with other callers and is left alone here.
- The same lock was part of an earlier patch that was withdrawn:
  [Hui Peng, patchwork 14831256, 2026-09-19; URL removed]
- Three other callers change the advertising list without hdev->lock
  (ISO broadcast, Set LE off and the advertising timeout); they are
  not part of this series.
- The lifetime of the mgmt_mesh_tx that mesh_send_sync() reads is a
  separate fix, "Bluetooth: MGMT: Fix use-after-free in
  mesh_send_sync()"; the two apply in either order.

Tested on bluetooth-next 1081a6ef8f1e0 in a 4 CPU QEMU guest with
BlueZ's emulated controller, KASAN and lockdep. With
lockdep_assert_held(&hdev->lock) added to hci_add_adv_instance() for
the test only, mesh-tester warned three times from mesh_send_sync()
without the series and not with it. KCSAN, 45 boots each, of a test
that adds and removes an advertising instance on one socket while
another socket sends mesh packets: without the series, one boot
reported races in mesh_send_sync() itself and three in
hci_schedule_adv_instance_sync() called from it; with the series, none
in mesh_send_sync(), and one boot reported a race below
hci_start_adv_sync(), which the series does not change. mgmt-tester
(515 cases) and mesh-tester (10) pass with the series; no lockdep,
KASAN or WARNING report.

Iaroslav Voitovych (2):
  Bluetooth: MGMT: Take hdev->lock in mesh_send_sync()
  Bluetooth: MGMT: Stop mesh_send_sync() when it cannot add the instance

 net/bluetooth/mgmt.c | 21 ++++++++++++++-------
 1 file changed, 14 insertions(+), 7 deletions(-)


base-commit: 1081a6ef8f1e0661fd52eb3f878691b0b96cdff9
-- 
2.43.0
```

Patch 1/2:

```diff
Date: Wed, 21 Oct 2026 07:43:46 +0200
Subject: [PATCH 1/2] Bluetooth: MGMT: Take hdev->lock in mesh_send_sync()

mesh_send_sync() runs on the cmd_sync worker, which holds req_lock but
not hdev->lock. It adds the packet's advertising instance with
hci_add_adv_instance(), which requires hdev->lock, and it reads
hdev->adv_instance_cnt, hdev->cur_adv_instance and
hdev->adv_instance_timeout and walks hdev->adv_instances through
hci_get_next_instance() without it.

Add Advertising changes the same list and counters under hdev->lock from
the MGMT socket, so on SMP the two can run at the same time. KCSAN
reports it, for example:

  BUG: KCSAN: data-race in hci_add_adv_instance / mesh_send_sync

  write to 0xffffa29c413d5dc0 of 4 bytes by task 61 on cpu 1:
   hci_add_adv_instance+0x463/0x490
   add_advertising+0x3e7/0x6b0
   hci_sock_sendmsg+0x924/0xfb0
  read to 0xffffa29c413d5dc0 of 4 bytes by task 70 on cpu 2:
   mesh_send_sync+0x3e/0x1c0
   hci_cmd_sync_work+0x172/0x230
  value changed: 0x00000001 -> 0x00000002

The reader there is the capacity check, so the check and the add are
not atomic with respect to Add Advertising either.

Take hdev->lock after the worker has taken req_lock, the order
hci_clear_adv_sync() and hci_remove_adv_sync() already use, around the
capacity check, the add and the list walk. Drop it before
hci_schedule_adv_instance_sync(), which sends HCI commands and must not
run under hdev->lock; only the instance number is carried across the
unlock, never the adv_info pointer.

hci_schedule_adv_instance_sync() looks the instance up without the lock
itself. It is shared with other callers and is not changed here.

Fixes: b338d91703fa ("Bluetooth: Implement support for Mesh")
Signed-off-by: Iaroslav Voitovych
---
 net/bluetooth/mgmt.c | 8 +++++++-
 1 file changed, 7 insertions(+), 1 deletion(-)

diff --git a/net/bluetooth/mgmt.c b/net/bluetooth/mgmt.c
index 3cb4f9ece83cb..8f7f3cdb2eebc 100644
--- a/net/bluetooth/mgmt.c
+++ b/net/bluetooth/mgmt.c
@@ -2336,8 +2336,12 @@ static int mesh_send_sync(struct hci_dev *hdev, void *data)
 	u16 timeout, duration;
 	int err = 0;
 
-	if (hdev->le_num_of_adv_sets <= hdev->adv_instance_cnt)
+	hci_dev_lock(hdev);
+
+	if (hdev->le_num_of_adv_sets <= hdev->adv_instance_cnt) {
+		hci_dev_unlock(hdev);
 		return MGMT_STATUS_BUSY;
+	}
 
 	timeout = 1000;
 	duration = send->cnt * INTERVAL_TO_MS(hdev->le_adv_max_interval);
@@ -2375,6 +2379,8 @@ static int mesh_send_sync(struct hci_dev *hdev, void *data)
 		instance = 0;
 	}
 
+	hci_dev_unlock(hdev);
+
 	if (instance)
 		return hci_schedule_adv_instance_sync(hdev, instance, true);
 
-- 
2.43.0
```

Patch 2/2 (CO-26):

```diff
Date: Wed, 21 Oct 2026 07:43:50 +0200
Subject: [PATCH 2/2] Bluetooth: MGMT: Stop mesh_send_sync() when it cannot add
 the instance

When hci_add_adv_instance() fails, mesh_send_sync() keeps the error in
err and carries on. It then returns the result of
hci_schedule_adv_instance_sync() for an instance that was never added,
and the original error is lost.

Return the error at once instead. hci_schedule_adv_instance_sync() is no
longer called for a missing instance and mesh_send_start_complete()
gets the real error.

With a failing allocation injected into hci_add_adv_instance() for the
first Mesh Send, as seen in a kprobe trace of bluetooth-next
1081a6ef8f1e0:

  before: hci_add_adv_instance -> -ENOMEM, then
          hci_schedule_adv_instance_sync(instance 6) -> -ENOENT,
          mesh_send_sync -> -2, mesh_send_start_complete(err=-2)
  after:  hci_add_adv_instance -> -ENOMEM,
          mesh_send_sync -> -12, mesh_send_start_complete(err=-12)

User space gets the same Mesh Packet Complete event in both cases, so
this is a cleanup of the error path and not a change in what a client
sees.

Fixes: b338d91703fa ("Bluetooth: Implement support for Mesh")
Signed-off-by: Iaroslav Voitovych
---
 net/bluetooth/mgmt.c | 13 +++++++------
 1 file changed, 7 insertions(+), 6 deletions(-)

diff --git a/net/bluetooth/mgmt.c b/net/bluetooth/mgmt.c
index 8f7f3cdb2eebc..e11925b707d5f 100644
--- a/net/bluetooth/mgmt.c
+++ b/net/bluetooth/mgmt.c
@@ -2334,7 +2334,6 @@ static int mesh_send_sync(struct hci_dev *hdev, void *data)
 	struct adv_info *adv, *next_instance;
 	u8 instance = hdev->le_num_of_adv_sets + 1;
 	u16 timeout, duration;
-	int err = 0;
 
 	hci_dev_lock(hdev);
 
@@ -2354,10 +2353,12 @@ static int mesh_send_sync(struct hci_dev *hdev, void *data)
 				   hdev->le_adv_max_interval,
 				   mesh_tx->handle);
 
-	if (!IS_ERR(adv))
-		mesh_tx->instance = instance;
-	else
-		err = PTR_ERR(adv);
+	if (IS_ERR(adv)) {
+		hci_dev_unlock(hdev);
+		return PTR_ERR(adv);
+	}
+
+	mesh_tx->instance = instance;
 
 	if (hdev->cur_adv_instance == instance) {
 		/* If the currently advertised instance is being changed then
@@ -2384,7 +2385,7 @@ static int mesh_send_sync(struct hci_dev *hdev, void *data)
 	if (instance)
 		return hci_schedule_adv_instance_sync(hdev, instance, true);
 
-	return err;
+	return 0;
 }
 
 static void send_count(struct mgmt_mesh_tx *mesh_tx, void *data)
-- 
2.43.0
```

### Tests and results

Measured on bluetooth-next 1081a6ef8f1e0, 4-CPU QEMU guests, BlueZ's emulated controller, for the 2026-10-29 pair only. They do not apply to a tree that has 14927631.

| check | base | with 1/2 and 2/2 |
|---|---|---|
| lock-assertion warnings from `mesh_send_sync()` (test-only `lockdep_assert_held()` in `hci_add_adv_instance()`), BlueZ master mesh-tester | 3 | 0 |
| the same assertion, mgmt-tester `-s Advertising` (other callers: advertising timeout, Set LE off, ISO broadcast) | 4 | 4 (other callers, untouched) |
| KCSAN, 45 boots of a test adding and removing an instance on one socket while another sends mesh packets: boots with a report naming advertising or mesh code | 4 | 1 |
| of those, in `mesh_send_sync()` or the add/walk called from it | 1 | 0 |
| of those, below `hci_schedule_adv_instance_sync()` / `hci_start_adv_sync()` (untouched) | 3 | 1 |
| BlueZ master mesh-tester, 3 runs | 8/10 each | 8/10 each |
| lockdep / KASAN / WARNING / BUG reports, every KASAN+lockdep boot (48 per image) | 0 | 0 |
| the list bot's mgmt-tester and mesh-tester, patched side | not run on base | 515/515 and 10/10 |

- 2/2's trace, in its message, was taken with a failing allocation injected into `hci_add_adv_instance()` for the first Mesh Send. Tester verdicts were identical with and without 2/2.
- No test exercised the early `MGMT_STATUS_BUSY` return of 1/2. It needs all advertising sets in use before a mesh packet starts, and no tester case does that. The path only unlocks and returns (read in the diff).
- Preflight (checkpatch, W=1 -Werror, sparse) is clean. The list bot's checks pass on the patched side.
- With 14927631 applied, our runs show all seven lock-assertion warnings gone (3 in the mesh-tester plus 4 in the `-s Advertising` run) and all scheduler race reports gone. This was recorded on 2026-11-01. The raw runs were not re-read for this document.
- A measured capacity test is not planned. The follow-up rests on source analysis.

### Not known, not claimed

- No damage from the unlocked add was ever shown: no KASAN report and no list corruption. The finding is a violated documented contract plus reported data races.
- The text of the follow-up on top of 14927631 does not exist yet.
- Whether 2/2 as stored applies on top of 14927631 was not checked. 1/2 does not apply, and 2/2 is stacked on 1/2, so it would need a rebase (inferred).
- `hci_schedule_adv_instance_sync()` still reads advertising state without the lock in the 2026-10-29 pair. 14927631 changes that function.
- Whether the stale capacity check has any effect beyond an early BUSY or a failed locked add is not measured.

### Open points and questions for the reviewer

1. Direction: drop 1/2 in favour of 14927631 and send only the follow-up (lock covers the capacity check; the add's error returned directly)? Or let 14927631 settle first and see whether anything remains?
2. The early return uses `MGMT_STATUS_BUSY`, a different value space from the `-errno` the callback otherwise sees. It takes the same branch in `mesh_send_start_complete()` and nothing reaches user space. Our view is that this is not worth a patch. Do you agree?
3. For 2/2: is a `Fixes:` tag appropriate for an error-path cleanup with no visible effect?

### Route and next step

The 2026-10-29 pair will not be sent. The follow-up will be based on 14927631 and will say so, or it will wait for it. Next steps:
- Write the follow-up on a tree that has 14927631.
- Apply the reviewer's answers.
- Compare the unmodified testers on base-with-14927631 against the same plus the follow-up.
- Send it as a separate small patch.

Timing depends on what the maintainers do with 14927631, which was still "new" on patchwork on 2026-11-01.

---

## CO-02 — a new SCO connect reuses the closing link

### At a glance

| Field | Content |
|---|---|
| Target | linux-bluetooth, `net/bluetooth/hci_conn.c` (three patches, `Cc: stable` on all three) and BlueZ `tools/sco-tester.c` (one test patch). Base of the posting: bluetooth-next 47d4d9f67e92. |
| State on 2026-11-02 | v7 sent 2026-10-27 (kernel series: cover + 3 patches, patchwork 14919266 to 14919268; BlueZ test: patchwork 14919269). The list's CI bot passed the kernel series (24 of 24 checks) and the BlueZ test (all PASS except the expected CheckSmatch note). No reply from a person as of 2026-11-02. Sashiko (the list's automated reviewer) marked patch 2 "fail, max severity high". A v8 that folds patch 3 into patch 2 is prepared, not sent. A newly measured behaviour (a reused live link keeps the closed socket's air mode) is not covered by v7. A separate mismatch-check patch is written and tested in QEMU (shown below), not sent. |
| Asked of the reviewer | (1) Is folding patch 3 into patch 2 the right answer to Sashiko, or should the three stay separate with a note for the stable maintainers? (2) The air-mode mismatch on reuse: what should happen, and where should the check live? (3) Is refusing with -ECONNABORTED right, or should the kernel defer (see CO-30)? (4) Are the remaining Sashiko notes (patch 1 fall-through, plain `abort_reason` readers) wanted in this series or separately? |

### Background

Conventions for all three items in this document. "Measured" means a number from a run, with the setup named. "From source" means read in the named tree at the named commit, with file and line. "Inferred" means reasoning that was not run. "bluetooth-next 47d4d9f67e92" is the base the CO-02 v7 series was sent against; "bluetooth-next 42b8c2d72926" is the tip of 2026-10-30, used for CO-21 and CO-30. Mail header lines that carry addresses (From, To, Cc, message identifiers) are dropped from the patch texts; where a trailer carried an address only the name is kept, and the stable tag is written "Cc: stable" (in the sent mail it was the stable list's address). All QEMU runs used BlueZ's emulator (hciemu/vhci) with the BlueZ testers, with KASAN, lockdep, DEBUG_ATOMIC_SLEEP and 4 virtual CPUs unless stated.

HFP (hands-free voice) over Bluetooth uses a SCO or eSCO link. When the voice codec changes during a call (for example CVSD to mSBC), PipeWire closes the old SCO socket and immediately opens a new one to the same headset. The headset's reply to the codec-change command (AT+BCS) can arrive before the Disconnection Complete event of the old link.

The user-visible symptom: after the codec change the new socket reports a successful connect(), but no new SCO link exists, and the call audio stays silent. Measured on the laptop (QCA9377 controller, PipeWire 1.0.5) in HCI captures of 2026-10-03: on three earbuds codec changes the headset answered 16 to 30 ms after the Disconnect while the old link's Disconnection Complete arrived 177 to 205 ms after it, and no Setup Synchronous Connection was sent. On a second headset the old link was gone in 39 to 46 ms, before the connect; a fresh connection was made and the setup was sent. That second headset is the working control. A separate earlier reproduction on Ubuntu kernel 7.0.0-34, before any patch, showed the same codec change producing no Setup Synchronous Connection, and sounds started 2 to 26 seconds later were still silent (a historical observation, not a same-build control).

PipeWire 1.0.5 takes the socket as ready. Its only retry is for an immediate ECONNABORTED from connect(); a later error closes the socket and sets the transport idle, with no new connect (read from PipeWire's source).

### Root cause

All excerpts are bluetooth-next 47d4d9f67e92, before any patch of the series.

1. `hci_connect_sco()` looks up an existing connection by type and address only, and sends a setup only if that connection is BT_OPEN or BT_CLOSED (`net/bluetooth/hci_conn.c:1905-1936`):

```c
	sco = hci_conn_hash_lookup_ba(hdev, type, dst);
	if (!sco) {
		sco = hci_conn_add_unset(hdev, type, dst, 0, HCI_ROLE_MASTER);
		...
	}

	link = hci_conn_link(acl, sco);
	if (!link) {
		hci_conn_drop(acl);
		hci_conn_drop(sco);
		return ERR_PTR(-ENOLINK);
	}

	sco->setting = setting;
	sco->codec = *codec;

	if (acl->state == BT_CONNECTED &&
	    (sco->state == BT_OPEN || sco->state == BT_CLOSED)) {
```

2. Closing the old socket drops its hold; `hci_conn_timeout()` (disc_work, zero delay for SCO) then calls `hci_abort_conn()`, which sets `abort_reason` and queues the Disconnect, but leaves the state BT_CONNECTED until the Disconnection Complete (`hci_conn.c:3253-3266`, `:641-661`):

```c
int hci_abort_conn(struct hci_conn *conn, u8 reason)
{
	...
	/* If abort_reason has already been set it means the connection is
	 * already being aborted so don't attempt to overwrite it.
	 */
	if (conn->abort_reason)
		return 0;
	...
	conn->abort_reason = reason;
```

3. A new connect() in that interval finds the old connection (BT_CONNECTED, so no setup is sent). `sco_connect()` then marks the new socket connected at once (`net/bluetooth/sco.c:417-419`: `if (hcon->state == BT_CONNECTED) { ... sk->sk_state = BT_CONNECTED; }`). When the old link's Disconnection Complete arrives, the new socket is closed with ECONNABORTED (reason 0x16).

4. Why this became visible: before commit e6720779ae61 ("Bluetooth: SCO: Use kref to track lifetime of sco_conn") the closed socket stayed attached until that event, so the second socket was rejected with EBUSY by `sco_chan_add()`. Since that commit the closed socket is detached at once and the new socket takes its place (commit message of patch 2; inferred from the commit's diff, not bisected).

5. A second defect found on the way (patch 1). `hci_conn_link()` returns the existing link without taking a hold (`hci_conn.c:1872-1873`: `if (conn->link) return conn->link;`), while `sco_connect()` drops a hold on every exit including the `sco_chan_add()` failure (`sco.c:403-409`, `hci_conn_drop(hcon)` on error). A second connect() to a peer whose link is up therefore gets EBUSY (correct) but also consumes the first socket's hold, and `hci_conn_timeout()` then disconnects the working link. Measured on the unpatched kernel: 3 of 3 runs showed EBUSY, a Disconnect, and the first socket's SO_ERROR 103.

6. A race remains after the abort_reason check (patch 3). `hci_conn_hold()` uses `cancel_delayed_work()`, which does not wait for a work item already running (`include/net/bluetooth/hci_core.h:1744-1752`). `hci_conn_timeout()` reads `refcnt` without `hdev->lock` and, after seeing no holder, calls `hci_abort_conn()` (`hci_conn.c:645-661`). A connect() can read `abort_reason == 0` and take its hold between those two steps.

### The change

Three patches (a fourth mail is the BlueZ test).

1. Hold fix: when the SCO connection already has a link, take a hold for the caller and drop the extra ACL hold; keep the `hci_conn_link()` path for connections without a link. Follows the CIS fix e06d549fcd4a. Placed first so it applies alone on 6.6.y and 6.12.y. Fixes 8a5b0135d4a5, `Cc: stable # 6.6.x`.
2. Refusal: if `abort_reason` is set, drop the ACL hold and return -ECONNABORTED at once. `READ_ONCE()` on the check and `WRITE_ONCE()` on the write in `hci_abort_conn()`. Fixes e6720779ae61, `Cc: stable`.
3. Synchronization: after the caller's hold is taken, wait for a running `hci_conn_timeout()` with `cancel_delayed_work_sync(&sco->disc_work)` and check `abort_reason` again; on a set reason, drop the hold and return -ECONNABORTED. The wait is safe under `hdev->lock` because for SCO `hci_conn_timeout()` does not take it (`hci_proto_disconn_ind()` returns a constant and `hci_abort_conn()` only queues the Disconnect); `hci_conn_del()` already waits for `disc_work` with the lock held (`hci_conn.c:1300`). Fixes e6720779ae61, `Cc: stable`.

The BlueZ test adds three sco-tester cases: "eSCO CVSD - Reconnect After Disconnect", "eSCO CVSD - Reconnect During Disconnect" (the emulator holds back the Disconnection Complete until the second connect() has returned), and "eSCO CVSD - Connect Twice".

Prepared v8: patch 3 folded into patch 2 (two patches). The code equals v7 except one extra `READ_ONCE()` on the second `abort_reason` read.

A refused connect() gives PipeWire 1.0.5 an immediate error, but its retries come within 130 microseconds, long before the old link is gone (typically tens to hundreds of milliseconds), so they fail too; audio returns when WirePlumber suspends the failed node and the next connect finds no old link. Measured on the laptop with a stream playing: audio returned about 5 seconds after a refused switch. Before the series: no link followed at all.

### The patches, verbatim

The cover letter and the three kernel patches as sent on 2026-10-27, then the BlueZ test as sent, then the prepared v8 fold. The "From" lines are dropped; the link to the other series in the cover letter is replaced by its patchwork number; the stable list address is shown by name.

#### v7 cover letter, as sent

```diff
Date: Tue, 27 Oct 2026 17:27:14 +0100
Subject: [PATCH 0/3] Bluetooth: hci_conn: fix SCO connection reuse

An HFP codec change can leave a headset silent. The new SCO socket
reports a successful connect(), but no new SCO link is established.

PipeWire closes the old SCO socket and immediately connects another
to the same headset. If the headset replies to AT+BCS before the old
link's Disconnection Complete arrives, hci_connect_sco() reuses the
connection being torn down.

That connection remains BT_CONNECTED while its Disconnect is pending.
No Setup Synchronous Connection is sent, yet the new socket reports
success. When the old link's Disconnection Complete arrives, the new
socket is closed with ECONNABORTED.

This series fixes three related problems.

Patch 1 corrects hold ownership when reusing a SCO connection whose
link is still up. A second connect() correctly returns EBUSY, but
also drops the first socket's hold and disconnects its working link.
Give the second caller its own hold and release the extra ACL hold,
following the CIS fix e06d549fcd4a. EBUSY remains the result, but
the existing link survives.

Patch 2 prevents reuse of a connection already committed to
teardown. If abort_reason is set, return -ECONNABORTED immediately
instead of handing the dying connection to a new socket.

Patch 3 closes the remaining race before abort_reason is set. A
running hci_conn_timeout() may already have observed that no holder
remains when a new connect() takes a hold. Wait for that worker and
check abort_reason again before using the connection.

A connect() arriving before the worker starts cancels the pending
disconnect with the hold patch 1 gives it, and keeps the live link.
Patches 2 and 3 leave that case unchanged.

Testing

The series was tested on bluetooth-next 27731ba09195 in QEMU with
BlueZ's emulator, on uniprocessor, SMP and KCSAN kernels, with
lockdep enabled. The accompanying BlueZ patch adds three sco-tester
cases:

  "Reconnect After Disconnect"
  "Reconnect During Disconnect"
  "Connect Twice"

"Reconnect During Disconnect" and "Connect Twice" fail without the
series on the uniprocessor and SMP kernels, and pass with it in three
runs each on the uniprocessor, SMP and KCSAN kernels. "Reconnect
After Disconnect" passes with and without the series. In the full
sco-tester, iso-tester, l2cap-tester and mgmt-tester runs, the only
other differences were two mgmt-tester cases that timed out
intermittently on SMP. Neither involves SCO, and one also timed out
without the series.

Patch 3's race was reproduced by a debug-only change that pauses
hci_conn_timeout() after it observes no holder; the change widens
the window and is not part of this series. Both host-initiated and
remote-initiated SCO links were tested. With patches 1 and 2 alone,
the new socket is still reported connected and then aborted. With
patch 3, connect() returns -ECONNABORTED.

The series also applies unchanged to bluetooth-next 47d4d9f67e92,
the base of this posting. On that base, sco-tester passes all 33
cases with the series; without it, only "Reconnect During
Disconnect" and "Connect Twice" fail. The other testers were not
rerun on this base.

Hardware testing

The series was also run on the QCA9377 laptop where the bug was
found, with PipeWire 1.0.5 and three headsets. The laptop ran
Ubuntu 24.04's 7.0.0-38 kernel with its Bluetooth module rebuilt
with abd93c85c8667, 816fb1590a4c and this series; the two
prerequisites are explained below.

Over more than a day and a half of ordinary use, from 23 to 25
October, three codec changes on earbuds that reply to AT+BCS before
the old link's Disconnection Complete returned ECONNABORTED instead
of reporting a connected socket without a link. On two other
headsets, which reply after that event, all eight codec changes
established a new link.

All 36 SCO links in the HCI capture of those days ended with a
successful Disconnection Complete for their handle, and no HCI
command timeout was logged. A search of the boot's kernel log found
no WARNING, BUG, Oops, Call Trace, refcount or use-after-free
report. Its only error-level lines are "SCO packet for unknown
connection handle" and "corrupted SCO packet", which this
controller also logs without the series.

Patch 1's case was tested separately on 26 October. While a
headset's eSCO link carried audio, three attempts to connect a
second SCO socket to the same headset each returned EBUSY at once.
The HCI capture shows no new setup or disconnect during the
attempts, and SCO packets kept flowing in both directions.

Patch 3's race was not reproduced on hardware; it is covered by the
emulator test described above.

Remaining codec-switch delay

The series stops connect() from succeeding on a connection already
being torn down. It does not, by itself, make PipeWire's codec
change seamless.

PipeWire 1.0.5 retries ECONNABORTED at once, while the old link is
still being disconnected, so those retries fail too. With a stream
playing on the laptop, audio returned about five seconds later,
when WirePlumber suspended the failed nodes and the next connect
established a new link.

In an earlier reproduction without the series, on Ubuntu 7.0.0-34,
the same codec change produced no Setup Synchronous Connection, and
sounds started 2 to 26 seconds later were still silent. That was a
historical observation, not a same-build control.

A separate prototype defers the new connect until the old link has
been torn down. It lets the retry succeed in the emulator tests but
has not been run on hardware. It builds on this series and changes
connect() semantics, so I can post it as an RFC if that approach is
preferred.

Related work

The series is independent of Hitalo Souza's pending SCO setup
series (patchwork series 1181908) and applies with or without it.

Jeremy Dean Clifton's pending "hci_core: Fix queuing disc_work while
workqueue is drained" (syzbot's "WARNING in hci_connect_sco") is on
the same path but does not overlap: it changes hci_conn_drop() in
hci_core.h.

Stable and downstream kernels

For stable, patch 1 applies alone on 6.6.y and 6.12.y, which have
the 8a5b0135d4a5 backport and the reuse path but not e6720779ae61.
Patches 2 and 3 apply on top of it on 6.18.y and 7.2.y. Each of
those heads was built and run with sco-tester without and with the
patches it needs: the cases for its bugs fail without them and pass
with them. 6.1.y has no reuse path, hence the "# 6.6.x" on patch 1.

Trees with e6720779ae61 but without 816fb1590a4c, such as Ubuntu
24.04's 7.0 kernel, need these two commits first:

  abd93c85c8667 ("Bluetooth: SCO: give the socket its own sco_conn
                 reference")
  816fb1590a4c ("Bluetooth: SCO: serialise sco_conn lifetime against
                sco_recv_scodata()")

Without them, sco_connect() does not put the sco_conn reference that
sco_conn_add() took when sco_chan_add() fails with EBUSY, and that
reference holds the hci_conn: once patch 1 stops the disconnect, the
SCO link stays up after both sockets are closed. On Ubuntu
7.0.0-38's Bluetooth sources with those two commits, "Reconnect
During Disconnect" and "Connect Twice" fail without the series and
pass with it, uniprocessor and SMP.

Iaroslav Voitovych (3):
  Bluetooth: hci_conn: hold a reused SCO connection for its caller
  Bluetooth: hci_conn: don't reuse an aborting SCO connection
  Bluetooth: hci_conn: synchronize with SCO disconnect work before reuse

 net/bluetooth/hci_conn.c | 36 ++++++++++++++++++++++++++++++++----
 1 file changed, 32 insertions(+), 4 deletions(-)


base-commit: 47d4d9f67e92d56ef3965f2727f9c98a5a611368
-- 
2.43.0
```

#### v7 patch 1 of 3, as sent

```diff
Date: Wed, 21 Oct 2026 05:47:33 +0200
Subject: [PATCH 1/3] Bluetooth: hci_conn: hold a reused SCO connection for its
 caller

Connecting a second SCO socket to a device whose link is already
in use correctly fails with EBUSY, but also disconnects the first
socket's working link.

hci_connect_sco() must return a connection with a hold owned by
its caller. sco_connect() drops that hold when it no longer needs
it, including when sco_chan_add() fails.

For a new link, hci_conn_link() takes the required SCO hold.
Since commit 06149746e720 ("Bluetooth: hci_conn: Add support for
linking multiple hcon"), a connection whose link already exists
is returned without one: hci_connect_sco() hands the reused SCO
connection back without a caller hold, while keeping the extra
ACL hold that hci_connect_acl() took for the link.

Commit 8a5b0135d4a5 ("Bluetooth: SCO: fix race conditions in
sco_sock_connect()") added the drop on sco_chan_add() failure.
When the second socket gets EBUSY, that drop consumes the first
socket's hold. hci_conn_timeout() then finds no holder and
disconnects the link.

When the SCO connection already has a link, take a hold for the
caller and drop the extra ACL hold, which the existing link
already owns. Keep the hci_conn_link() path for connections that
do not yet have a link.

This follows the ownership correction made for CIS by
commit e06d549fcd4a ("Bluetooth: hci_conn: fix CIS hold ownership
on reuse"). The second connect() still fails with EBUSY, but no
longer disconnects the first socket's link.

Fixes: 8a5b0135d4a5 ("Bluetooth: SCO: fix race conditions in sco_sock_connect()")
Cc: stable # 6.6.x
Signed-off-by: Iaroslav Voitovych
---
 net/bluetooth/hci_conn.c | 17 +++++++++++++----
 1 file changed, 13 insertions(+), 4 deletions(-)

diff --git a/net/bluetooth/hci_conn.c b/net/bluetooth/hci_conn.c
index b007f623b2ecc..7a55aaf197138 100644
--- a/net/bluetooth/hci_conn.c
+++ b/net/bluetooth/hci_conn.c
@@ -1911,11 +1911,20 @@ struct hci_conn *hci_connect_sco(struct hci_dev *hdev, int type, bdaddr_t *dst,
 		}
 	}
 
-	link = hci_conn_link(acl, sco);
-	if (!link) {
+	if (sco->link) {
+		/* The existing link already owns the hold on the ACL, and the
+		 * caller needs its own hold on the SCO connection, which
+		 * hci_conn_link() only takes for a new link.
+		 */
 		hci_conn_drop(acl);
-		hci_conn_drop(sco);
-		return ERR_PTR(-ENOLINK);
+		hci_conn_hold(sco);
+	} else {
+		link = hci_conn_link(acl, sco);
+		if (!link) {
+			hci_conn_drop(acl);
+			hci_conn_drop(sco);
+			return ERR_PTR(-ENOLINK);
+		}
 	}
 
 	sco->setting = setting;
-- 
2.43.0
```

#### v7 patch 2 of 3, as sent

```diff
Date: Wed, 21 Oct 2026 05:29:28 +0200
Subject: [PATCH 2/3] Bluetooth: hci_conn: don't reuse an aborting SCO
 connection

A new SCO socket can report a successful connect() to a link that
is already being disconnected. No new link is established, and the
socket is closed with ECONNABORTED when the old link's
Disconnection Complete arrives. PipeWire hits this when it closes
and reconnects a SCO socket during an HFP codec change.

hci_connect_sco() looks up an existing connection by type and
address. It sends Setup Synchronous Connection only when that
connection is BT_OPEN or BT_CLOSED.

An aborting connection is neither: hci_abort_conn() sets
abort_reason and queues the Disconnect, but leaves the state
BT_CONNECTED until the Disconnection Complete. A new connect in
that interval therefore reuses the old connection without sending
a setup command.

Before commit e6720779ae61 ("Bluetooth: SCO: Use kref to track
lifetime of sco_conn"), the closed socket stayed attached in
BT_DISCONN until that event, so sco_chan_add() rejected the new
socket with EBUSY. Since that commit, the closed socket is
detached at once, and the new socket takes its place: sco_connect()
reports it connected, and the Disconnection Complete then closes
it with ECONNABORTED.

Reject a connection whose abort_reason is set with -ECONNABORTED,
and drop the ACL hold that hci_connect_acl() took. The caller
learns at once, with the error the socket would otherwise get
later, and can connect again once the old link is gone.

hci_connect_sco() runs under hdev->lock, but hci_conn_timeout()
sets abort_reason through hci_abort_conn() without it. Use
READ_ONCE() for the new check and WRITE_ONCE() for that write.

Fixes: e6720779ae61 ("Bluetooth: SCO: Use kref to track lifetime of sco_conn")
Cc: stable
Signed-off-by: Iaroslav Voitovych
---
 net/bluetooth/hci_conn.c | 10 +++++++++-
 1 file changed, 9 insertions(+), 1 deletion(-)

diff --git a/net/bluetooth/hci_conn.c b/net/bluetooth/hci_conn.c
index 7a55aaf197138..6b92fd0177857 100644
--- a/net/bluetooth/hci_conn.c
+++ b/net/bluetooth/hci_conn.c
@@ -1909,6 +1909,14 @@ struct hci_conn *hci_connect_sco(struct hci_dev *hdev, int type, bdaddr_t *dst,
 			hci_conn_drop(acl);
 			return sco;
 		}
+	} else if (READ_ONCE(sco->abort_reason)) {
+		/* The connection is being disconnected and stays BT_CONNECTED
+		 * until the Disconnection Complete event, so no setup would
+		 * be sent for it and it would be closed under the new socket
+		 * as soon as the event arrives.
+		 */
+		hci_conn_drop(acl);
+		return ERR_PTR(-ECONNABORTED);
 	}
 
 	if (sco->link) {
@@ -3272,7 +3280,7 @@ int hci_abort_conn(struct hci_conn *conn, u8 reason)
 
 	bt_dev_dbg(hdev, "handle 0x%2.2x reason 0x%2.2x", conn->handle, reason);
 
-	conn->abort_reason = reason;
+	WRITE_ONCE(conn->abort_reason, reason);
 
 	/* Cancel the connect attempt. A return of 0 means the create command
 	 * was still queued and got dequeued, so there is nothing to disconnect.
-- 
2.43.0
```

#### v7 patch 3 of 3, as sent

```diff
Date: Thu, 22 Oct 2026 13:49:56 +0200
Subject: [PATCH 3/3] Bluetooth: hci_conn: synchronize with SCO disconnect work
 before reuse

Checking abort_reason before reusing a SCO connection does not
close the race with a disconnect worker that is already running:
connect() can still report success just before that worker aborts
the connection.

hci_conn_hold() uses cancel_delayed_work(), which cancels pending
work but does not wait for work already running.
hci_conn_timeout() reads refcnt without hdev->lock and, after
seeing no holder, calls hci_abort_conn(), which sets abort_reason.

A new connect() can check abort_reason and take its hold between
those two steps. It then gets a connection that the worker is
about to abort, and the Disconnection Complete closes the new
socket with ECONNABORTED. This applies both to a connection whose
link exists and to one the remote device set up, which gets its
link from hci_conn_link() here.

After taking the hold, wait for a running hci_conn_timeout() with
cancel_delayed_work_sync() and check abort_reason again. If the
worker has aborted the connection, drop the caller's hold and
return -ECONNABORTED.

The wait is safe under hdev->lock. For a SCO connection,
hci_conn_timeout() does not take that lock: hci_proto_disconn_ind()
returns a constant, and hci_abort_conn() only queues the
Disconnect. hci_conn_del() already waits for disc_work with
hdev->lock held. For a new connection the work has never been
queued, so nothing is waited for.

Once the wait returns, the work has finished and cannot be queued
again while the caller's hold is taken, so the second check does
not race with it. If the connection had no link before, the link
hci_conn_link() just made stays with the aborting connection and
is released with its ACL hold by hci_conn_del(), as for any linked
SCO connection.

A connect() that comes before the work has started at all still
cancels it with its hold and keeps the live link, as it does
without this patch; that case is not changed here.

Reproduced by delaying hci_conn_timeout() after it has seen no
holder (a debug-only change, not part of this patch), for a link
set up by the host and for one set up by the remote device:
without this patch connect() returns 0 and the socket is then
closed with ECONNABORTED; with it, connect() fails with
-ECONNABORTED.

Fixes: e6720779ae61 ("Bluetooth: SCO: Use kref to track lifetime of sco_conn")
Cc: stable
Signed-off-by: Iaroslav Voitovych
---
 net/bluetooth/hci_conn.c | 11 +++++++++++
 1 file changed, 11 insertions(+)

diff --git a/net/bluetooth/hci_conn.c b/net/bluetooth/hci_conn.c
index 6b92fd0177857..c1c8d2b29e3c0 100644
--- a/net/bluetooth/hci_conn.c
+++ b/net/bluetooth/hci_conn.c
@@ -1935,6 +1935,17 @@ struct hci_conn *hci_connect_sco(struct hci_dev *hdev, int type, bdaddr_t *dst,
 		}
 	}
 
+	/* Taking the hold cannot stop a hci_conn_timeout() that is already
+	 * running: it may have seen no holder and be about to abort the
+	 * connection. It does not take hdev->lock, so wait for it and check
+	 * abort_reason again.
+	 */
+	cancel_delayed_work_sync(&sco->disc_work);
+	if (sco->abort_reason) {
+		hci_conn_drop(sco);
+		return ERR_PTR(-ECONNABORTED);
+	}
+
 	sco->setting = setting;
 	sco->codec = *codec;
 
-- 
2.43.0
```

#### BlueZ test patch (v7 time), as sent

The posting asked that it be applied after the kernel series is in bluetooth-next. It no longer applies to BlueZ master since the tester series that moved the testers to the mainloop landed (BlueZ commit e37f17751, 2026-10-29); a ported v2 is prepared (see "Tests and results") and not sent.

```diff
Date: Thu, 22 Oct 2026 05:06:33 +0200
Subject: [PATCH BlueZ] tools/sco-tester: Add SCO reconnect tests

Add three tests where a second socket connects to the peer of a SCO
link:

- "eSCO CVSD - Reconnect After Disconnect": the first link is gone when
  the second socket connects. It shall get a link of its own: connect()
  in progress, its own Setup Synchronous Connection and Synchronous
  Connection Complete, and the link stays up.

- "eSCO CVSD - Reconnect During Disconnect": the emulator processes the
  Disconnect of the first link as usual, but the Disconnection Complete
  event is held back until the second connect() has returned. The
  connect() shall fail with ECONNABORTED or EBUSY, or the second socket
  shall get a link of its own as above once the event is delivered. A
  socket reported connected without a link fails the test.

- "eSCO CVSD - Connect Twice": connect() on a second socket while the
  link is up shall fail with EBUSY and leave the link alone: no
  Disconnect, the first socket still connected. Closing both sockets
  shall disconnect the SCO link and then the ACL link.

For a new link the tests check its own Setup Synchronous Connection
and Synchronous Connection Complete as well as the socket, so a link
of its own is told apart from reuse of the old connection even when
the controller reuses the same handle.
---
"Reconnect During Disconnect" and "Connect Twice" fail on current
bluetooth-next and pass with the kernel series "[PATCH 0/3] Bluetooth:
hci_conn: fix SCO connection reuse", sent to this list alongside
(link to its cover letter omitted here).

Please apply this after that series is in bluetooth-next; until then
the two cases fail there. The During case accepts more than one
outcome on purpose (an immediate ECONNABORTED or EBUSY, or a new link
of its own), so that it stays valid on kernels before 6.13, which
answer EBUSY, and if the kernel later defers such a connect instead of
refusing it.

This is against current master; if the series moving the testers to
the mainloop lands first, I will rebase it onto that.

 tools/sco-tester.c | 567 ++++++++++++++++++++++++++++++++++++++++++++-
 1 file changed, 566 insertions(+), 1 deletion(-)

diff --git a/tools/sco-tester.c b/tools/sco-tester.c
index fca99a91c..8149d4dcf 100644
--- a/tools/sco-tester.c
+++ b/tools/sco-tester.c
@@ -27,6 +27,8 @@
 #include "monitor/bt.h"
 #include "emulator/bthost.h"
 #include "emulator/hciemu.h"
+#include "emulator/vhci.h"
+#include "emulator/btdev.h"
 
 #include "src/shared/tester.h"
 #include "src/shared/mgmt.h"
@@ -50,6 +52,27 @@ struct test_data {
 	uint16_t acl_handle;
 	uint16_t handle;
 	struct tx_tstamp_data tx_ts;
+
+	/* State of the reconnect tests */
+	int sk2;
+	unsigned int io2_id;
+	unsigned int timer_id;
+	bool done;
+	bool disc_held;
+	bool disc_released;
+	bool closing;
+	bool sco_gone;
+	struct bt_hci_evt_disconnect_complete held_evt;
+	unsigned int sync_complete;
+	unsigned int setup_cmds;
+	unsigned int disc_cmds;
+};
+
+enum reconnect_mode {
+	RECONNECT_NONE,
+	RECONNECT_AFTER,	/* Connect again once the first link is gone */
+	RECONNECT_DURING,	/* ... while the completion is held */
+	CONNECT_TWICE,		/* Connect again while the first link is up */
 };
 
 struct sco_client_data {
@@ -78,6 +101,9 @@ struct sco_client_data {
 
 	/* Defer setup when accepting SCO connections */
 	bool defer;
+
+	/* A second socket connects to the same peer, see the modes above */
+	enum reconnect_mode reconnect;
 };
 
 static void print_debug(const char *str, void *user_data)
@@ -250,6 +276,36 @@ static void test_pre_setup(const void *test_data)
 static void test_post_teardown(const void *test_data)
 {
 	struct test_data *data = tester_get_data();
+	const struct sco_client_data *scodata = data->test_data;
+
+	/*
+	 * The reconnect tests own their first socket (its channel does not
+	 * close it), so a test that timed out may have left it open.
+	 */
+	if (scodata && scodata->reconnect && data->sk >= 0) {
+		if (data->io_id) {
+			g_source_remove(data->io_id);
+			data->io_id = 0;
+		}
+
+		close(data->sk);
+		data->sk = -1;
+	}
+
+	if (data->timer_id) {
+		g_source_remove(data->timer_id);
+		data->timer_id = 0;
+	}
+
+	if (data->io2_id) {
+		g_source_remove(data->io2_id);
+		data->io2_id = 0;
+	}
+
+	if (data->sk2 >= 0) {
+		close(data->sk2);
+		data->sk2 = -1;
+	}
 
 	hciemu_unref(data->hciemu);
 	data->hciemu = NULL;
@@ -269,13 +325,14 @@ static void test_data_free(void *test_data)
 					_disable_sco_flowctl, _timeout) \
 	do { \
 		struct test_data *user; \
-		user = malloc(sizeof(struct test_data)); \
+		user = calloc(1, sizeof(struct test_data)); \
 		if (!user) \
 			break; \
 		user->hciemu_type = HCIEMU_TYPE_BREDRLE; \
 		user->io_id = 0; \
 		user->err_io_id = 0; \
 		user->sk = -1; \
+		user->sk2 = -1; \
 		user->test_data = data; \
 		user->step = 0; \
 		user->disable_esco = _disable_esco; \
@@ -329,6 +386,18 @@ static const struct sco_client_data connect_failure_reset = {
 	.expect_err = ECONNRESET
 };
 
+static const struct sco_client_data reconnect_after = {
+	.reconnect = RECONNECT_AFTER,
+};
+
+static const struct sco_client_data reconnect_during = {
+	.reconnect = RECONNECT_DURING,
+};
+
+static const struct sco_client_data connect_twice = {
+	.reconnect = CONNECT_TWICE,
+};
+
 const uint8_t data[] = {0, 1, 2, 3, 4, 5, 6, 7, 8};
 
 static const struct sco_client_data connect_recv_success = {
@@ -1309,6 +1378,490 @@ static void test_connect_acl_disc(const void *test_data)
 	test_connect(test_data);
 }
 
+#define RECONNECT_DELAY_MS	100	/* host handles the last event */
+#define RECONNECT_QUIET_MS	500	/* nothing more shall happen */
+#define RECONNECT_LINK_MS	3000	/* a link or a disconnect shall come */
+#define RECONNECT_ACL_MS	5000	/* the idle ACL link shall go */
+
+static void reconnect_end(struct test_data *data, bool ok)
+{
+	if (data->done)
+		return;
+
+	data->done = true;
+
+	/* The first socket is still open if the test ended early */
+	if (data->io_id) {
+		g_source_remove(data->io_id);
+		data->io_id = 0;
+	}
+
+	if (data->sk >= 0) {
+		close(data->sk);
+		data->sk = -1;
+	}
+
+	if (!ok)
+		tester_warn("Setup commands %u, Disconnect commands %u, "
+				"Synchronous Connection Complete %u",
+				data->setup_cmds, data->disc_cmds,
+				data->sync_complete);
+
+	if (ok)
+		tester_test_passed();
+	else
+		tester_test_failed();
+}
+
+static int sock_error(int sk)
+{
+	int err = 0;
+	socklen_t len = sizeof(err);
+
+	if (getsockopt(sk, SOL_SOCKET, SO_ERROR, &err, &len) < 0)
+		return errno;
+
+	return err;
+}
+
+static short sock_poll(int sk)
+{
+	struct pollfd pfd = { .fd = sk, .events = POLLOUT };
+
+	if (poll(&pfd, 1, 0) < 0)
+		return -1;
+
+	return pfd.revents;
+}
+
+static bool sock_connected(int sk, const char *name)
+{
+	short revents = sock_poll(sk);
+	int err = sock_error(sk);
+
+	if (!err && revents > 0 && (revents & POLLOUT) &&
+				!(revents & (POLLERR | POLLHUP)))
+		return true;
+
+	tester_warn("The %s socket is not connected: %s (%d), poll 0x%04x",
+					name, strerror(err), err, revents);
+	return false;
+}
+
+static bool io_connected(GIOCondition cond, int sk, const char *name)
+{
+	if ((cond & G_IO_OUT) && !(cond & (G_IO_ERR | G_IO_HUP)))
+		return sock_connected(sk, name);
+
+	tester_warn("The %s socket failed: condition 0x%x, %s", name, cond,
+						strerror(sock_error(sk)));
+	return false;
+}
+
+static void reconnect_arm(struct test_data *data, guint ms, GSourceFunc func)
+{
+	if (data->timer_id)
+		g_source_remove(data->timer_id);
+
+	data->timer_id = g_timeout_add(ms, func, NULL);
+}
+
+static gboolean reconnect_deadline(gpointer user_data)
+{
+	struct test_data *data = tester_get_data();
+
+	data->timer_id = 0;
+
+	tester_warn("Timed out waiting for the next link event");
+	reconnect_end(data, false);
+
+	return FALSE;
+}
+
+static bool hook_reconnect_sync(const void *buf, uint16_t len, void *user_data)
+{
+	struct test_data *data = tester_get_data();
+	const struct bt_hci_evt_sync_conn_complete *evt = buf;
+
+	if (len < sizeof(*evt) || data->done)
+		return true;
+
+	if (evt->status) {
+		tester_print("Synchronous Connection Complete failed: "
+					"status 0x%02x", evt->status);
+		return true;
+	}
+
+	data->sync_complete++;
+	if (data->sync_complete == 1)
+		data->handle = le16_to_cpu(evt->handle);
+
+	tester_print("Synchronous Connection Complete #%u: handle %u, "
+			"status 0x%02x", data->sync_complete,
+			le16_to_cpu(evt->handle), evt->status);
+
+	return true;
+}
+
+static bool hook_reconnect_acl(const void *buf, uint16_t len, void *user_data)
+{
+	struct test_data *data = tester_get_data();
+	const struct bt_hci_evt_conn_complete *evt = buf;
+
+	if (len >= sizeof(*evt) && !evt->status)
+		data->acl_handle = le16_to_cpu(evt->handle);
+
+	return true;
+}
+
+static void hook_reconnect_cmd(uint16_t opcode, const void *buf, uint8_t len,
+							void *user_data)
+{
+	struct test_data *data = user_data;
+	const struct sco_client_data *scodata = data->test_data;
+	const struct bt_hci_cmd_disconnect *cmd = buf;
+
+	if (opcode == BT_HCI_CMD_SETUP_SYNC_CONN ||
+			opcode == BT_HCI_CMD_ENHANCED_SETUP_SYNC_CONN) {
+		data->setup_cmds++;
+		tester_print("Setup Synchronous Connection #%u",
+							data->setup_cmds);
+	}
+
+	if (opcode != BT_HCI_CMD_DISCONNECT || len < sizeof(*cmd) ||
+			data->sync_complete < 1 ||
+			le16_to_cpu(cmd->handle) != data->handle)
+		return;
+
+	data->disc_cmds++;
+	tester_print("Disconnect for the first link, handle %u",
+							data->handle);
+
+	if (scodata->reconnect == CONNECT_TWICE && !data->closing) {
+		tester_warn("The first link is disconnected while its socket "
+				"is open");
+		reconnect_end(data, false);
+	}
+}
+
+static gboolean reconnect_connect2(gpointer user_data);
+
+static bool hook_reconnect_disc(const void *buf, uint16_t len, void *user_data)
+{
+	struct test_data *data = tester_get_data();
+	const struct sco_client_data *scodata = data->test_data;
+	const struct bt_hci_evt_disconnect_complete *evt = buf;
+
+	if (len < sizeof(*evt) || data->done)
+		return true;
+
+	tester_print("Disconnection Complete: handle %u, reason 0x%02x",
+				le16_to_cpu(evt->handle), evt->reason);
+
+	if (le16_to_cpu(evt->handle) == data->acl_handle) {
+		/* The ACL link, once nothing needs it, after the SCO link */
+		if (scodata->reconnect == CONNECT_TWICE && data->closing)
+			reconnect_end(data, data->disc_cmds == 1 &&
+						data->sco_gone && !evt->status);
+		return true;
+	}
+
+	if (le16_to_cpu(evt->handle) != data->handle)
+		return true;
+
+	if (scodata->reconnect == CONNECT_TWICE && data->closing)
+		data->sco_gone = !evt->status;
+
+	if (data->disc_released)
+		return true;
+
+	if (scodata->reconnect == RECONNECT_DURING) {
+		/*
+		 * The emulator has torn the link down; only the event to
+		 * the host is held back.
+		 */
+		data->held_evt = *evt;
+		data->disc_held = true;
+		reconnect_arm(data, 0, reconnect_connect2);
+		tester_print("Holding back the Disconnection Complete");
+		return false;
+	}
+
+	if (scodata->reconnect == RECONNECT_AFTER) {
+		data->disc_released = true;
+		reconnect_arm(data, RECONNECT_DELAY_MS, reconnect_connect2);
+	}
+
+	return true;
+}
+
+static void reconnect_release(struct test_data *data)
+{
+	struct btdev *btdev = vhci_get_btdev(hciemu_get_vhci(data->hciemu));
+
+	data->disc_released = true;
+
+	tester_print("Delivering the held Disconnection Complete");
+	if (btdev_send_event(btdev, BT_HCI_EVT_DISCONNECT_COMPLETE,
+				&data->held_evt, sizeof(data->held_evt))) {
+		tester_warn("Failed to deliver the Disconnection Complete");
+		reconnect_end(data, false);
+	}
+}
+
+static gboolean reconnect_quiet(gpointer user_data)
+{
+	struct test_data *data = tester_get_data();
+	const struct sco_client_data *scodata = data->test_data;
+
+	data->timer_id = 0;
+
+	if (scodata->reconnect == CONNECT_TWICE) {
+		if (!sock_connected(data->sk, "first") || data->disc_cmds) {
+			reconnect_end(data, false);
+			return FALSE;
+		}
+
+		/*
+		 * Both sockets closed: the SCO link and then the ACL link
+		 * shall go.
+		 */
+		tester_print("First link still up, closing both sockets");
+		data->closing = true;
+		close(data->sk2);
+		data->sk2 = -1;
+		close(data->sk);
+		data->sk = -1;
+		reconnect_arm(data, RECONNECT_ACL_MS, reconnect_deadline);
+		return FALSE;
+	}
+
+	/* The connect was refused: no link of its own */
+	if (data->setup_cmds != 1 || data->sync_complete != 1 ||
+						data->disc_cmds != 1) {
+		tester_warn("Unexpected commands after the refused connect");
+		reconnect_end(data, false);
+		return FALSE;
+	}
+
+	reconnect_end(data, true);
+	return FALSE;
+}
+
+static gboolean reconnect_stable(gpointer user_data)
+{
+	struct test_data *data = tester_get_data();
+
+	data->timer_id = 0;
+
+	reconnect_end(data, sock_connected(data->sk2, "second") &&
+						data->disc_cmds == 1);
+	return FALSE;
+}
+
+static gboolean reconnect_linked(GIOChannel *io, GIOCondition cond,
+							gpointer user_data)
+{
+	struct test_data *data = tester_get_data();
+
+	data->io2_id = 0;
+
+	if (!io_connected(cond, data->sk2, "second")) {
+		reconnect_end(data, false);
+		return FALSE;
+	}
+
+	/*
+	 * The first link is gone, so the controller reuses its handle: the
+	 * second link is told apart by its own setup and its own completion,
+	 * after the Disconnection Complete of the first.
+	 */
+	if (data->setup_cmds != 2 || data->sync_complete != 2 ||
+						data->disc_cmds != 1) {
+		tester_warn("Second socket connected without a link of its "
+				"own");
+		reconnect_end(data, false);
+		return FALSE;
+	}
+
+	if (!data->disc_released) {
+		tester_warn("Second link before the first one is gone");
+		reconnect_end(data, false);
+		return FALSE;
+	}
+
+	/* The second link shall stay up */
+	reconnect_arm(data, RECONNECT_QUIET_MS, reconnect_stable);
+	return FALSE;
+}
+
+static gboolean reconnect_connect2(gpointer user_data)
+{
+	struct test_data *data = tester_get_data();
+	const struct sco_client_data *scodata = data->test_data;
+	const uint8_t *client_bdaddr;
+	struct sockaddr_sco addr;
+	GIOChannel *io;
+	int ret, err;
+
+	data->timer_id = 0;
+
+	if (data->done)
+		return FALSE;
+
+	if (data->sync_complete != 1 || data->setup_cmds != 1) {
+		tester_warn("The first link was not set up as expected");
+		reconnect_end(data, false);
+		return FALSE;
+	}
+
+	if (scodata->reconnect == RECONNECT_DURING &&
+			(!data->disc_held || data->disc_cmds != 1)) {
+		tester_warn("The Disconnection Complete was not held");
+		reconnect_end(data, false);
+		return FALSE;
+	}
+
+	client_bdaddr = hciemu_get_client_bdaddr(data->hciemu);
+	data->sk2 = create_sco_sock(data);
+	if (!client_bdaddr || data->sk2 < 0) {
+		reconnect_end(data, false);
+		return FALSE;
+	}
+
+	memset(&addr, 0, sizeof(addr));
+	addr.sco_family = AF_BLUETOOTH;
+	bacpy(&addr.sco_bdaddr, (void *) client_bdaddr);
+
+	ret = connect(data->sk2, (struct sockaddr *) &addr, sizeof(addr));
+	err = ret < 0 ? errno : 0;
+
+	tester_print("Second connect() returned %d (%s)", ret, strerror(err));
+
+	if (scodata->reconnect == CONNECT_TWICE) {
+		if (ret >= 0 || err != EBUSY) {
+			tester_warn("Expected EBUSY from the second connect()");
+			reconnect_end(data, false);
+			return FALSE;
+		}
+
+		reconnect_arm(data, RECONNECT_QUIET_MS, reconnect_quiet);
+		return FALSE;
+	}
+
+	if (scodata->reconnect == RECONNECT_DURING &&
+				(err == ECONNABORTED || err == EBUSY)) {
+		/* Refused: the caller can connect again later */
+		reconnect_release(data);
+		reconnect_arm(data, RECONNECT_QUIET_MS, reconnect_quiet);
+		return FALSE;
+	}
+
+	if (ret >= 0) {
+		tester_warn("Connected at once, without a link of its own");
+		reconnect_end(data, false);
+		return FALSE;
+	}
+
+	if (err != EINPROGRESS) {
+		tester_warn("Unexpected connect() error: %s", strerror(err));
+		reconnect_end(data, false);
+		return FALSE;
+	}
+
+	/* Connecting: the new link shall come, after the first one is gone */
+	io = g_io_channel_unix_new(data->sk2);
+	g_io_channel_set_close_on_unref(io, FALSE);
+	data->io2_id = g_io_add_watch(io, G_IO_OUT | G_IO_ERR | G_IO_HUP,
+						reconnect_linked, NULL);
+	g_io_channel_unref(io);
+
+	reconnect_arm(data, RECONNECT_LINK_MS, reconnect_deadline);
+
+	if (scodata->reconnect == RECONNECT_DURING)
+		reconnect_release(data);
+
+	return FALSE;
+}
+
+static gboolean reconnect_first_connected(GIOChannel *io, GIOCondition cond,
+							gpointer user_data)
+{
+	struct test_data *data = tester_get_data();
+	const struct sco_client_data *scodata = data->test_data;
+
+	data->io_id = 0;
+
+	if (!io_connected(cond, data->sk, "first")) {
+		reconnect_end(data, false);
+		return FALSE;
+	}
+
+	if (data->sync_complete != 1 || data->setup_cmds != 1) {
+		tester_warn("The first link was not set up as expected");
+		reconnect_end(data, false);
+		return FALSE;
+	}
+
+	if (scodata->reconnect == CONNECT_TWICE) {
+		tester_print("First socket connected");
+		reconnect_connect2(NULL);
+		return FALSE;
+	}
+
+	tester_print("First socket connected, closing it");
+	close(data->sk);
+	data->sk = -1;
+
+	/* The Disconnection Complete is the next step */
+	reconnect_arm(data, RECONNECT_LINK_MS, reconnect_deadline);
+
+	return FALSE;
+}
+
+static void test_reconnect(const void *test_data)
+{
+	struct test_data *data = tester_get_data();
+	GIOChannel *io;
+	int sk;
+
+	hciemu_add_hook(data->hciemu, HCIEMU_HOOK_POST_EVT,
+					BT_HCI_EVT_CONN_COMPLETE,
+					hook_reconnect_acl, NULL);
+	hciemu_add_hook(data->hciemu, HCIEMU_HOOK_POST_EVT,
+					BT_HCI_EVT_SYNC_CONN_COMPLETE,
+					hook_reconnect_sync, NULL);
+	hciemu_add_hook(data->hciemu, HCIEMU_HOOK_POST_EVT,
+					BT_HCI_EVT_DISCONNECT_COMPLETE,
+					hook_reconnect_disc, NULL);
+	hciemu_add_central_post_command_hook(data->hciemu,
+					hook_reconnect_cmd, data);
+
+	sk = create_sco_sock(data);
+	if (sk < 0) {
+		tester_test_failed();
+		return;
+	}
+
+	if (connect_sco_sock(data, sk) < 0) {
+		close(sk);
+		tester_test_failed();
+		return;
+	}
+
+	data->sk = sk;
+
+	io = g_io_channel_unix_new(sk);
+	g_io_channel_set_close_on_unref(io, FALSE);
+
+	data->io_id = g_io_add_watch(io, G_IO_OUT | G_IO_ERR | G_IO_HUP,
+					reconnect_first_connected, NULL);
+
+	g_io_channel_unref(io);
+
+	tester_print("Connect in progress");
+}
+
 static void test_sco_ethtool_get_ts_info(const void *test_data)
 {
 	struct test_data *data = tester_get_data();
@@ -1526,6 +2079,18 @@ int main(int argc, char *argv[])
 					&connect_failure_reset, setup_powered,
 					test_connect_acl_disc);
 
+	test_sco_full("eSCO CVSD - Reconnect After Disconnect",
+					&reconnect_after, setup_powered,
+					test_reconnect, false, false, false, 5);
+
+	test_sco_full("eSCO CVSD - Reconnect During Disconnect",
+					&reconnect_during, setup_powered,
+					test_reconnect, false, false, false, 5);
+
+	test_sco_full("eSCO CVSD - Connect Twice",
+					&connect_twice, setup_powered,
+					test_reconnect, false, false, false, 8);
+
 	test_sco_11("SCO CVSD 1.1 - Success", &connect_success, setup_powered,
 							test_connect);
 
-- 
2.43.0
```

#### Prepared v8 (patches 2 and 3 folded), not sent

Patch 1 of v8 is the v7 patch 1 text above unchanged, except the subject prefix "[PATCH v8 1/2]" and a base-commit line (47d4d9f67e92d56ef3965f2727f9c98a5a611368) at the end. It is repeated in full so the pair can be read as one.

```diff
Date: Wed, 21 Oct 2026 05:47:33 +0200
Subject: [PATCH v8 1/2] Bluetooth: hci_conn: hold a reused SCO connection for
 its caller

Connecting a second SCO socket to a device whose link is already
in use correctly fails with EBUSY, but also disconnects the first
socket's working link.

hci_connect_sco() must return a connection with a hold owned by
its caller. sco_connect() drops that hold when it no longer needs
it, including when sco_chan_add() fails.

For a new link, hci_conn_link() takes the required SCO hold.
Since commit 06149746e720 ("Bluetooth: hci_conn: Add support for
linking multiple hcon"), a connection whose link already exists
is returned without one: hci_connect_sco() hands the reused SCO
connection back without a caller hold, while keeping the extra
ACL hold that hci_connect_acl() took for the link.

Commit 8a5b0135d4a5 ("Bluetooth: SCO: fix race conditions in
sco_sock_connect()") added the drop on sco_chan_add() failure.
When the second socket gets EBUSY, that drop consumes the first
socket's hold. hci_conn_timeout() then finds no holder and
disconnects the link.

When the SCO connection already has a link, take a hold for the
caller and drop the extra ACL hold, which the existing link
already owns. Keep the hci_conn_link() path for connections that
do not yet have a link.

This follows the ownership correction made for CIS by
commit e06d549fcd4a ("Bluetooth: hci_conn: fix CIS hold ownership
on reuse"). The second connect() still fails with EBUSY, but no
longer disconnects the first socket's link.

Fixes: 8a5b0135d4a5 ("Bluetooth: SCO: fix race conditions in sco_sock_connect()")
Cc: stable # 6.6.x
Signed-off-by: Iaroslav Voitovych
---
 net/bluetooth/hci_conn.c | 17 +++++++++++++----
 1 file changed, 13 insertions(+), 4 deletions(-)

diff --git a/net/bluetooth/hci_conn.c b/net/bluetooth/hci_conn.c
index b007f623b2ecc..7a55aaf197138 100644
--- a/net/bluetooth/hci_conn.c
+++ b/net/bluetooth/hci_conn.c
@@ -1911,11 +1911,20 @@ struct hci_conn *hci_connect_sco(struct hci_dev *hdev, int type, bdaddr_t *dst,
 		}
 	}
 
-	link = hci_conn_link(acl, sco);
-	if (!link) {
+	if (sco->link) {
+		/* The existing link already owns the hold on the ACL, and the
+		 * caller needs its own hold on the SCO connection, which
+		 * hci_conn_link() only takes for a new link.
+		 */
 		hci_conn_drop(acl);
-		hci_conn_drop(sco);
-		return ERR_PTR(-ENOLINK);
+		hci_conn_hold(sco);
+	} else {
+		link = hci_conn_link(acl, sco);
+		if (!link) {
+			hci_conn_drop(acl);
+			hci_conn_drop(sco);
+			return ERR_PTR(-ENOLINK);
+		}
 	}
 
 	sco->setting = setting;

base-commit: 47d4d9f67e92d56ef3965f2727f9c98a5a611368
-- 
2.43.0
```

```diff
Date: Wed, 21 Oct 2026 05:29:28 +0200
Subject: [PATCH v8 2/2] Bluetooth: hci_conn: don't reuse an aborting SCO
 connection

A new SCO socket can report a successful connect() to a link that
is already being disconnected. No new link is established, and the
socket is closed with ECONNABORTED when the old link's
Disconnection Complete arrives. PipeWire hits this when it closes
and reconnects a SCO socket during an HFP codec change.

hci_connect_sco() looks up an existing connection by type and
address. It sends Setup Synchronous Connection only when that
connection is BT_OPEN or BT_CLOSED.

An aborting connection is neither: hci_abort_conn() sets
abort_reason and queues the Disconnect, but leaves the state
BT_CONNECTED until the Disconnection Complete. A new connect in
that interval therefore reuses the old connection without sending
a setup command.

Before commit e6720779ae61 ("Bluetooth: SCO: Use kref to track
lifetime of sco_conn"), the closed socket stayed attached in
BT_DISCONN until that event, so sco_chan_add() rejected the new
socket with EBUSY. Since that commit, the closed socket is
detached at once, and the new socket takes its place: sco_connect()
reports it connected, and the Disconnection Complete then closes
it with ECONNABORTED.

Reject a connection whose abort_reason is set with -ECONNABORTED.
The caller learns at once, with the error the socket would
otherwise get later, and can connect again once the old link is
gone.

Checking abort_reason at the lookup alone leaves a race with a
disconnect worker that is already running. hci_conn_hold() uses
cancel_delayed_work(), which does not wait for running work, and
hci_conn_timeout() reads refcnt without hdev->lock and, after
seeing no holder, calls hci_abort_conn(), which sets abort_reason.
A connect() can check abort_reason and take its hold between those
two steps. This applies both to a connection whose link exists and
to one the remote device set up, which gets its link from
hci_conn_link() here. So abort_reason is checked twice:

- at the lookup; the ACL hold that hci_connect_acl() took is
  dropped;
- after the caller's hold is taken and a running hci_conn_timeout()
  has been waited for with cancel_delayed_work_sync(); the caller's
  hold is dropped.

The wait is safe under hdev->lock. For a SCO connection,
hci_conn_timeout() does not take that lock: hci_proto_disconn_ind()
returns a constant, and hci_abort_conn() only queues the
Disconnect. hci_conn_del() already waits for disc_work with
hdev->lock held. For a new connection the work has never been
queued, so nothing is waited for. Once the wait returns, the work
has finished and cannot be queued again while the caller's hold is
taken, so the second check does not race with it. If the connection
had no link before, the link hci_conn_link() just made stays with
the aborting connection and is released with its ACL hold by
hci_conn_del(), as for any linked SCO connection.

hci_connect_sco() runs under hdev->lock, but hci_conn_timeout()
sets abort_reason through hci_abort_conn() without it. Use
READ_ONCE() for both checks and WRITE_ONCE() for that write.

A connect() that comes before the work has started at all cancels
it with its hold and keeps the live link; that case is not changed
here.

Reproduced in the emulator by holding back the Disconnection
Complete, and, for the worker race, by delaying hci_conn_timeout()
after it has seen no holder (a debug-only change, not part of this
patch), for a link set up by the host and for one set up by the
remote device: without this patch connect() returns 0 and the
socket is then closed with ECONNABORTED; with it, connect() fails
with -ECONNABORTED.

Fixes: e6720779ae61 ("Bluetooth: SCO: Use kref to track lifetime of sco_conn")
Cc: stable
Signed-off-by: Iaroslav Voitovych
---
 net/bluetooth/hci_conn.c | 21 ++++++++++++++++++++-
 1 file changed, 20 insertions(+), 1 deletion(-)

diff --git a/net/bluetooth/hci_conn.c b/net/bluetooth/hci_conn.c
index 7a55aaf197138..7f3f7a4f859b7 100644
--- a/net/bluetooth/hci_conn.c
+++ b/net/bluetooth/hci_conn.c
@@ -1909,6 +1909,14 @@ struct hci_conn *hci_connect_sco(struct hci_dev *hdev, int type, bdaddr_t *dst,
 			hci_conn_drop(acl);
 			return sco;
 		}
+	} else if (READ_ONCE(sco->abort_reason)) {
+		/* The connection is being disconnected and stays BT_CONNECTED
+		 * until the Disconnection Complete event, so no setup would
+		 * be sent for it and it would be closed under the new socket
+		 * as soon as the event arrives.
+		 */
+		hci_conn_drop(acl);
+		return ERR_PTR(-ECONNABORTED);
 	}
 
 	if (sco->link) {
@@ -1927,6 +1935,17 @@ struct hci_conn *hci_connect_sco(struct hci_dev *hdev, int type, bdaddr_t *dst,
 		}
 	}
 
+	/* Taking the hold cannot stop a hci_conn_timeout() that is already
+	 * running: it may have seen no holder and be about to abort the
+	 * connection. It does not take hdev->lock, so wait for it and check
+	 * abort_reason again.
+	 */
+	cancel_delayed_work_sync(&sco->disc_work);
+	if (READ_ONCE(sco->abort_reason)) {
+		hci_conn_drop(sco);
+		return ERR_PTR(-ECONNABORTED);
+	}
+
 	sco->setting = setting;
 	sco->codec = *codec;
 
@@ -3272,7 +3291,7 @@ int hci_abort_conn(struct hci_conn *conn, u8 reason)
 
 	bt_dev_dbg(hdev, "handle 0x%2.2x reason 0x%2.2x", conn->handle, reason);
 
-	conn->abort_reason = reason;
+	WRITE_ONCE(conn->abort_reason, reason);
 
 	/* Cancel the connect attempt. A return of 0 means the create command
 	 * was still queued and got dequeued, so there is nothing to disconnect.
-- 
2.43.0
```

### Tests and results

**The v7 series as sent (measured, from the cover letter and the bot run).**

- QEMU with BlueZ's emulator on bluetooth-next 27731ba09195: uniprocessor, SMP and KCSAN kernels, lockdep on. "Reconnect During Disconnect" and "Connect Twice" fail without the series and pass with it in three runs each on the three kernels. "Reconnect After Disconnect" passes with and without. In the full sco-tester, iso-tester, l2cap-tester and mgmt-tester runs the only other differences were two mgmt-tester cases that timed out intermittently on SMP (neither involves SCO; one also timed out without the series).
- Earlier two-patch draft, 2026-10-21 (measured, same method): "Reconnect During Disconnect" passed 0 of 5 on an unpatched uniprocessor kernel, 0 of 10 on unpatched SMP with 4 CPUs, 0 of 5 on unpatched KCSAN SMP; the draft passed 5 of 5, 10 of 10 and 5 of 5. In full runs of that draft on the uniprocessor kernel: sco-tester 31/32 unpatched against 32/32 patched, iso-tester 141/141, l2cap-tester 111/111, mgmt-tester 514/514; KCSAN reported three items, none in `sco.c` or `hci_conn.c`.
- On the posting's base 47d4d9f67e92: sco-tester passes 33 of 33 with the series; without it 31 of 33 (the two cases above fail). Other testers were not rerun on that base.
- Stable lines: patch 1 alone on 6.6.y and 6.12.y; patches 1 to 3 on 6.18.y and 7.2.y; each head built and run with sco-tester without and with the patches it needs; the cases for its bugs fail without them and pass with them.
- Ubuntu 7.0.0-38 Bluetooth sources with abd93c85c8667 and 816fb1590a4c added: the two cases fail without and pass with the series, uniprocessor and SMP.
- The patch 3 race was reproduced with a debug-only change that pauses `hci_conn_timeout()` after it observed no holder, for a host-initiated and a remote-initiated link: with patches 1 and 2 alone connect() returns 0 and the socket is then aborted; with patch 3, connect() returns -ECONNABORTED.
- The list's CI bot: 24 of 24 checks `success` on the kernel series; the BlueZ test all PASS except CheckSmatch WARNING (the expected `bluetooth.h` "array of flexible structures" lines that come with `tools/sco-tester.c`).
- Laptop (QCA9377, PipeWire 1.0.5, three headsets, Ubuntu 7.0.0-38 module rebuilt with the series and its two prerequisites), 23 to 25 October 2026: three earbuds codec switches (the headset replies before the old link's event) each returned ECONNABORTED instead of a falsely connected socket; eight switches on two other headsets (reply after the event) each got a new link. All 36 SCO links in the HCI capture ended with a successful Disconnection Complete for their handle; no HCI command timeout; no WARNING, BUG, Oops, Call Trace, refcount or use-after-free report in the boot's kernel log. Patch 1's case, 26 October: while a headset's eSCO link carried audio, three attempts to connect a second socket each returned EBUSY at once; the capture shows no new setup or disconnect and SCO packets kept flowing both ways. Patch 3's race was not reproduced on hardware.

**Sashiko findings (runs of 2026-10-27 and 2026-10-29).**

- The instance whose result the maintainers' patchwork shows (`sashiko-nipa`, finished 2026-10-29 17:57 UTC): patch 1 success, patch 3 success, patch 2 "fail, Sashiko found issues (max severity: high)".
  - High, on patch 2: it reads `abort_reason` before taking its hold. A `hci_conn_timeout()` already running in a kworker can read `refcnt == 0`; `hci_connect_sco()` can then read `abort_reason == 0`, take the hold and return the connection before `hci_abort_conn()` sets the reason; the new socket is then closed by the Disconnection Complete. Sashiko notes that patch 3 (`cancel_delayed_work_sync()` after the hold, then a second `abort_reason` check) closes exactly this interleaving, and asks whether 3 should be folded into 2 or the two kept together for stable, since 2 carries `Cc: stable`.
  - Low: besides the new `READ_ONCE()`, `abort_reason` is still read plainly in `hci_abort_conn()`'s guard, `hci_conn_set_handle()`, `abort_conn_sync()`, the `hci_conn_cleanup_child()` call site and `iso.c`; KCSAN may report these against the new `WRITE_ONCE()`. It suggests a separate patch.
  - The review is on Sashiko's site only (that instance did not mail it).
- The public instance (patchset reviewed 2026-10-27 16:52 UTC): patches 2 and 3 "No issues found". Patch 1: High. If the second socket connects while the first link is still BT_OPEN, falling through overwrites `sco->setting` and `codec` and may queue a duplicate setup; it asks whether the `sco->link` branch should return early, as `hci_connect_cis()` does. The first instance lists the same overwrite as pre-existing, Medium.
- Reading of these (inferred, from source): the high finding concerns the split of the series, not the series as a whole; with patches 1 to 3 applied the interleaving is closed by patch 3. The concrete risk is stable taking patch 2 without patch 3. The patch 1 note is pre-existing: `hci_conn_link()` returns the existing link at `hci_conn.c:1872-1873`; a duplicate setup is possible only on the enhanced-setup path (the state stays BT_OPEN until the queued work runs, `hci_conn.c:484`) and not on the legacy path (`hci_conn.c:418` sets BT_CONNECT at once). Sashiko's duplicate-setup point was not reproduced: 16 runs of the "right after the first connect" case.

**v8 preparation (measured, QEMU/KVM, 4 CPUs, KASAN, lockdep, DEBUG_ATOMIC_SLEEP; kernel base 47d4d9f67e92, BlueZ master 14bd6ab65).**

- BlueZ test v2, ported to the mainloop sco-tester (e37f17751): `git am` clean on master 14bd6ab65; AddressSanitizer/UBSan `-Werror` build; checkpatch 0 errors, 0 warnings; the bot's gitlint passes; no line over 80 columns. One change: `malloc()` to `calloc()` for the test data.
- Full sco-tester, 3 runs each: base 31 of 33 (Reconnect During Disconnect and Connect Twice fail 3 of 3); v7, the fold, and two experimental variants (below) 33 of 33 in all 3 runs. The parked-worker race case passes 2 of 2 in each of 3 runs on v7, the fold, and variant (b). Every tester log clean (no oops, KASAN, lockdep reports).
- The fold: code equal to v7 except the one added `READ_ONCE()`; checkpatch `--strict` clean.

**The parameter overwrite (measured, QEMU; the point Sashiko raised on patch 1).** On the reuse branch `sco->setting` and `sco->codec` are written (`hci_connect_sco()` assigns them after `hci_conn_link()`) before `sco_chan_add()` refuses the second socket with EBUSY. First socket CVSD, second socket BT_VOICE 0x0003 or BT_CODEC mSBC:

- first link already up: no effect, 4 of 4 on each path (legacy and enhanced setup);
- first link's ACL still being set up: the setup goes out with the second socket's values (legacy voice 0x0003 / air mode 0x03; enhanced coding 0x03, or 0x05 plus two Configure Data Path), 4 of 4 on each path;
- first setup answered with a retryable error (0x1f, injected): the retry carries the second socket's values, 4 of 4 on legacy; on the enhanced path 2 of 4, in the other 2 the first socket never connected, cause not established;
- same-parameter controls: no effect. On the unmodified kernel the first link is torn down anyway, but the overwrite also shows in the ACL-pending and retry legacy cases, so it predates the series.
- From source only: BT_VOICE does not validate its value (`sco.c:1050-1057`); a refused socket with an air mode other than CVSD or transparent would make cleanup skip btusb's disable notification (the emulator has no notify hook, so not measurable).
- Two experimental variants were built and are not proposed. (b): store the parameters only on a new link; it removes the overwrite but when the first socket closes and a second connects before the disconnect worker runs, the second can get a link with the closed socket's parameters (2 of 6 runs). (c): store only when the caller is the connection's only holder (decided by reference count); no overwrite in any refused case (3 of 3).

**The close-and-reuse measurement of 2026-11-01 (measured, QEMU).** Method, with no kernel change and no test-only kernel build: closing a socket queues `disc_work` with zero delay; `hci_conn_timeout()` sets `abort_reason`; `hci_connect_sco()` reuses only while it is still 0. Holding back the Disconnection Complete cannot reach that window (`abort_reason` is set before any HCI traffic). The tester instead restricts unbound workqueues to CPU 1 (the workqueue cpumask in sysfs), pins itself there as SCHED_FIFO and does close(sk1) then connect(sk2) back to back. The pin was confirmed in 160 of 160 pinned runs (4 log lines per log, 40 logs). Classification: REUSED = the second socket's handle equals the first link's and no setup follows the swap (live cases), or the same single SCO entry before and after (pending cases); FRESH = a new setup after the swap (0 runs); REFUSED = ECONNABORTED. Four kernels, 10 runs per case: unmodified base, v7, the fold, variant (c).

| Case (10 runs each) | base | v7 | fold | (c) |
|---|---|---|---|---|
| live link, pinned, same parameters: reused | 10 | 10 | 10 | 10 |
| live link, pinned, second asks transparent: reused | 10 | 10 | 10 | 10 |
| live link, unpinned (plain close then connect), same parameters: reused / refused | 10 / 0 | 8 / 2 | 10 / 0 | 7 / 3 |
| pending link, pinned, enhanced setup: reused | 10 | 10 | 10 | 10 |
| pending link, pinned, legacy setup: reused | 10 | 10 | 10 | 10 |

- Holds balance (the tester's "holds balance" invariant passes): v7, fold and (c) 150 of 150 runs (3 kernels x 5 close-and-reuse configurations x 10 runs); 44 of 44 guest logs without WARN, refcount or KASAN reports (kmemleak was not built in). On the unmodified kernel the reused link is disconnected while the second socket is open and the ACL link is still listed at the end: 50 of 50 runs (5 configurations x 10).
- Pending cases: on v7, the fold and (c) the setup carries the second socket's parameters (0x0003, air mode 0x03), 10 of 10 each; on base no link is made.
- Unchanged "close then reopen" cases (btmon running, so not comparable with the earlier counts): enhanced path refused 10 of 10 on v7, the fold and (c), while on base the second connect is accepted but the socket is not connected, 10 of 10; legacy path v7 7 refused + 3 link, fold 8 + 2, (c) 10 refused, base accepted-not-connected 10 of 10.
- Refused sockets never changed the link's parameters (55 of 55 runs); no setup was sent twice (280 of 280 runs).
- Side observation (cause inferred, not investigated): in every legacy "close then reopen" refusal a Setup Synchronous Connection with the first socket's CVSD settings goes out for the connection being aborted and is answered with status 0x02.

**New finding: a reused live link keeps the closed socket's air mode (measured, QEMU, 2026-11-01).** When the second socket asks for transparent voice (BT_VOICE 0x0003, mSBC) and `hci_connect_sco()` hands it the closed socket's live CVSD link, no new setup is sent and the socket stays on CVSD: the tester logs "air mode of the second's link 0x02 (want 0x03)". This occurred in 10 of 10 runs on each of the four kernels (40 of 40 logs; the pinned live-link transparent case in the table above). Units for the combined count quoted elsewhere: 150 of 150 runs = 3 kernels x 5 close-and-reuse configurations x 10 runs, which is the balance of holds, not the air mode. Behaviour per kernel: on the unmodified kernel the link is dropped while the second socket is open (a visible failure); on v7, the fold and (c) the link stays up in CVSD although the socket asked for transparent (a silent wrong result). Variant (c) does not fix it (inferred from its code: it stores 0x0003 into the connection without a new setup). Without pinning, a plain close-then-connect of a live link also mostly reuses it (base 10 of 10, v7 8 of 10, fold 10 of 10, (c) 7 of 10), so the reuse is not only a lab timing.

**The mismatch check, written as its own patch (2026-11-02; not sent).** Rule: right after the lookup in `hci_connect_sco()`, a connection that is `BT_CONNECTED` and whose stored voice setting or codec differs from the request is refused with -ECONNABORTED. The ACL hold is dropped and no hold is taken on the SCO connection, so the old link's pending disconnect goes ahead and a retry gets a new link set up with its own parameters. It compares the stored request, not the completion's Air_Mode: a reuse sends no setup, so no completion arrives to compare, and Hitalo Souza's abandoned-setup path is left to a separate change. It applies with the same patch-id on bluetooth-next 47d4d9f67e92 and on top of v7, and also on 42b8c2d72926. checkpatch `--strict` gives 0 errors, 0 warnings, 0 checks; the W=1 and sparse builds of `hci_conn.o` are clean.

```diff
Date: Mon, 2 Nov 2026 07:50:52 +0100
Subject: [PATCH] Bluetooth: hci_conn: don't reuse a SCO link with other
 parameters

hci_connect_sco() looks up an existing SCO connection by type and
address, and sends a setup command only when that connection is
BT_OPEN or BT_CLOSED. Since commit 10c62ddc6f03 ("Bluetooth:
Parameters for outgoing SCO connections"), each connect carries its
own voice setting, and later also a codec, but neither is compared
with the connection that is found: both are only stored into it.

A connection that is already BT_CONNECTED is not set up again, so a
socket that asked for other parameters is given a link that keeps
running with the old ones. This happens when a SCO socket is closed
and another is connected to the same device before the closed link's
disconnect work has run, as on an HFP codec change: a socket asking
for BT_VOICE_TRANSPARENT is reported connected on the closed socket's
CVSD link, and no setup command is sent.

Refuse a connected link whose voice setting or codec differs from the
requested ones with -ECONNABORTED, before taking any hold on it, so
that a disconnect it is waiting for goes ahead. The caller can
connect again, and gets a new link set up with its own parameters
once the old one is gone. A connection that is not connected yet is
still set up with the parameters stored here.

A link set up by the remote device carries no setting from a local
connect, so it is not reused either. A connect to a device whose link
is still in use with other parameters now fails here, with
-ECONNABORTED instead of -EBUSY from sco_chan_add(), and no longer
overwrites that link's stored parameters.

Fixes: 10c62ddc6f03 ("Bluetooth: Parameters for outgoing SCO connections")
---
 net/bluetooth/hci_conn.c | 12 ++++++++++++
 1 file changed, 12 insertions(+)

diff --git a/net/bluetooth/hci_conn.c b/net/bluetooth/hci_conn.c
index b007f623b..4195e8a50 100644
--- a/net/bluetooth/hci_conn.c
+++ b/net/bluetooth/hci_conn.c
@@ -1903,6 +1903,18 @@ struct hci_conn *hci_connect_sco(struct hci_dev *hdev, int type, bdaddr_t *dst,
 		return acl;
 
 	sco = hci_conn_hash_lookup_ba(hdev, type, dst);
+	if (sco && sco->state == BT_CONNECTED &&
+	    (sco->setting != setting ||
+	     memcmp(&sco->codec, codec, sizeof(*codec)))) {
+		/* A connected link keeps the voice setting and codec it was
+		 * set up with: no setup is sent for it here. Do not hand it
+		 * to a caller that asked for other ones; the caller can
+		 * connect again once the link is gone.
+		 */
+		hci_conn_drop(acl);
+		return ERR_PTR(-ECONNABORTED);
+	}
+
 	if (!sco) {
 		sco = hci_conn_add_unset(hdev, type, dst, 0, HCI_ROLE_MASTER);
 		if (IS_ERR(sco)) {
-- 
2.43.0
```

Results **[measured]**, QEMU, 4-CPU guests with KASAN and lockdep, 10 runs per case on each of four kernels (base, v7, base + this patch, v7 + this patch):

| case | base | v7 | base + patch | v7 + patch |
|---|---|---|---|---|
| live link, pinned, CVSD then transparent and transparent then CVSD, enhanced and legacy setup | connected on the old air mode, 10/10 | connected on the old air mode, 10/10 | refused, then a fresh link with the requested air mode, 10/10 | the same, 10/10 |
| the same, unpinned | wrong 10/10 | wrong 3 to 5 of 10, the rest refused then fresh | refused then fresh, 10/10 | refused then fresh, 10/10 |
| live link, same mode | reused, then dropped under the open socket | reused, kept | as base | reused, kept |
| link set up by the remote device, then a local connect, same mode | reused | reused | refused once, then fresh | refused once, then fresh |
| link set up by the remote device, then a local connect, other mode | wrong 10/10 | wrong 10/10 | refused then fresh 10/10 | refused then fresh 10/10 |

- Over 315 mismatched runs on the patched kernels, no socket was connected with a wrong air mode.
- Every refused retry succeeded within 1 or 2 attempts, connected after a median of 27 to 36 ms in the emulator (maximum 186 ms). On hardware the floor would be the old link's disconnect round trip (39 to 205 ms in the 2026-10-03 captures; inferred).
- A connect to a link still in use by an open socket with other parameters now gets -ECONNABORTED instead of -EBUSY; on base it no longer tears down the first socket's link (0/10 to 10/10 kept).
- sco-tester with the CO-02 cases, 3 runs each: base and base + patch 31/33 (the same two known failures), v7 and v7 + patch 33/33. iso-tester: 141/141 in most runs on both sides, with one timeout and one stall on each side, in code that cannot reach `hci_connect_sco()` (cause not found).
- No WARN, BUG, KASAN, lockdep, refcount, UBSAN, RCU-stall or hung-task report in any guest log. The only call traces are the guest's out-of-memory killer taking the sanitizer build of btmon in the small (255 MB) guests.
- Not tested on the laptop.

Questions on this patch: -ECONNABORTED (as v7 already returns for the same closing link a moment later) or -EBUSY? For a link set up by the remote device, accept the one-time refusal, or store the completion's Air_Mode in a new field and compare only that? Compare the full voice setting and codec (as now; for example 0x0060 against 0x0063 is refused) or only the air-mode bits? A fourth patch in v8, or a separate patch? Is `Cc: stable` wanted?

### Not known, not claimed

- Whether a real sound server ever closes a CVSD socket and opens a transparent one fast enough to hit the mismatch. It is not observed on hardware. The cover letter of Hitalo Souza's v3 series (6 patches, 2026-10-08, patchwork series 1181908) names PipeWire recreating the HFP transport after a codec negotiation (close, then connect at once) as the real trigger of the cases in his series, and our case needs the same close-then-connect. Plausible, not observed.
- The mismatch is not a regression introduced by v7: `hci_connect_sco()` hands back a connected link by address without comparing the requested voice setting, which predates the series. v7 changes the outcome: the old kernel drops the link (visible failure), v7 keeps it with the wrong setting (silent).
- That patch 2 or 3 is needed on every stable line is not claimed for lines other than those named in the cover letter (6.6.y, 6.12.y, 6.18.y, 7.2.y); 6.1.y has no reuse path.
- Hardware: patch 3's race and the reuse branch (pinned) were not exercised on the laptop; the live-link reuse mismatch was not tested on hardware.
- Real-hardware behaviour of a mismatch refusal: not applicable yet; no patch exists.
- Whether Sashiko's patch-2 "high" is a real risk in a tree where patches 1 to 3 go in together: by reading, no; the risk is stable taking patch 2 alone.
- Not checked: PulseAudio's and oFono's handling of an immediate ECONNABORTED.

### Open points and questions for the reviewer

1. Series shape. Sashiko asks to fold patch 3 into patch 2 or to keep them together for stable. A v8 with the fold (two patches, shown above) is prepared. Question: is the fold the right shape, or should the three patches stay separate with a note that 2 and 3 belong together for stable?
2. Mismatch handling. A completion event's Air_Mode is the one place that sees both this case and the abandoned-setup case in Hitalo Souza's series (his cover letter says the Air_Mode would show a change between CVSD and transparent data, "but the series does not act on it"). Design idea, not tested: compare the air mode of the reused connection with the one the new socket asked for, and refuse the reuse on a difference. Questions: where should the check live (in `hci_connect_sco()` before the hold, or in `sco_connect()`)? What should an incompatible reuse do: refuse with -ECONNABORTED (so the caller retries once the old link is gone), refuse with another errno, or disconnect and set up a new link? Changing a stored setting cannot renegotiate a link that is already up, so the fix has to define the incompatible case. A compatible reuse must not fail; a refusal that leaves every retry stuck would still fail the caller.
3. Test conditions the author intends: same mode reused; a mismatch in both directions (CVSD to transparent and back); a pending setup; an aborted setup; a completed one; teardown ordering; and a successful reconnect after an incompatible reuse is refused. Are other cases wanted?
4. Patch 1 fall-through (Sashiko, public instance): should the `sco->link` branch return early as `hci_connect_cis()` does, or is the overwrite of `setting`/`codec` to be handled as a separate pre-existing fix? Measured above: the overwrite carries the second socket's values into a pending setup or retry; refusal with EBUSY does not undo it.
5. Plain readers of `abort_reason` (Sashiko's low note): wanted as a separate patch, or left alone?
6. Whether -ECONNABORTED at connect() is the right contract, given PipeWire 1.0.5 retries immediately (see CO-30 for the alternative that waits).
7. The BlueZ test needs the port to the mainloop API (prepared, v2). It is meant to be applied after the kernel series.

**Open decision (the author's, not yet taken).** How to handle the mismatch finding, given that v7 makes it more visible. Options: a short factual note on the v7 thread now; a fix folded into v8; a separate follow-up patch; wait for a human reply. Outside reviewers differed. The recommendation now: write the mismatch check as its own patch (applies on the unmodified tree and on top of v7 alike), test it in the emulator with the conditions in point 3, and send it as a standalone patch with a short note on the v7 thread pointing to it; if v7 looks about to be applied before that patch is ready, send a short factual reply on its own (it would state: the behaviour also happens on the unmodified kernel; the series changes how long the link stays up; it was measured in QEMU; it is not seen with a real sound server). It would not say "do not apply": v7 still fixes the same-parameter reuse. v8 itself is to be sent only when a human replies, or as a ping after two or three weeks of silence.

### Route and next step

- v7 is on the list; waiting for a human reply. No reply on any of the four mails as of 2026-11-02. bluetooth-next moved on 2026-10-30 (42b8c2d72926) without the series and without changes to `hci_conn.c`, `sco.c` or `hci_core.h` since the posting's base, so v7 still applies as sent.
- Prepared and not sent: v8 (the fold), BlueZ test v2 (mainloop port), and the mismatch-check patch (tested in QEMU).
- Other pending work on the same path that does not overlap: Cen Zhang's "Bluetooth: hci_conn: Initialize the device before hash insertion" (patchwork 14912235; the series applies after it with 2-line offsets) and Jeremy Dean Clifton's "Bluetooth: hci_core: Fix queuing disc_work while workqueue is drained" (patchwork 14903178; no textual overlap).

---

## CO-21 — btusb with two SCO links: one going down switches the other to alternate setting 0

### At a glance

| Field | Content |
|---|---|
| Target | `drivers/bluetooth/btusb.c` (`btusb_notify()`, `btusb_work()`; the file is `btusb_main.c` in bluetooth-next 42b8c2d72926) and a small core patch in `include/net/bluetooth/hci_core.h`, `hci.h`, `net/bluetooth/hci_event.c`. |
| State on 2026-11-02 | Redesign of two patches written against bluetooth-next 42b8c2d72926. Builds with 0 warnings, checkpatch clean. Never loaded on hardware, never run on a kernel (only a scripted model). Nothing sent. The first candidate fix (btusb only) was found incomplete by an outside review on 2026-11-01. |
| Asked of the reviewer | A read of the redesign: is deriving the setting from the links that are up the right shape; is the mixed-link rule right; is the timing argument sound; should the core field be `air_mode` or something else. Also: how to coordinate with Hitalo Souza's pending patch 6/6, which touches the same notification. |

### Background

A Bluetooth USB controller carries voice (SCO/eSCO) data over an isochronous USB endpoint. The endpoint's bandwidth is chosen by the USB alternate setting of the isochronous interface. btusb switches it when the core notifies it (`hdev->notify`) about SCO connections: one alternate setting per number of CVSD links, and a different one for transparent (mSBC) links. Alternate setting 0 of the isochronous interface has no isochronous bandwidth on this device (inferred from the Bluetooth USB transport rules and the existing code, which uses alternate 0 as the "stopped" setting), so a call that is moved to alternate setting 0 is silent.

User-visible symptom (from source and a model; not observed as a silent call on the laptop): with two calls up, ending one moves the other to alternate setting 0 and the remaining call goes silent. A second, single-link variant: a connection change in the window while one call's setup is pending can make btusb pick alternate setting 0 for the call that then comes up.

Evidence from the laptop (measured): the trigger of the single-link kind appears twice in its journal (2026-09-02, stock kernel era; those links never came up). In 281 pending SCO setups over 68 boots no link ever ran on alternate setting 0. No silent call from this cause has been seen.

### Root cause

From source, bluetooth-next 42b8c2d72926.

`btusb_notify()` takes the air mode from whichever event changed the SCO count, and `btusb_work()` falls back to alternate setting 0 for anything that is neither CVSD nor transparent (`drivers/bluetooth/btusb_main.c:2470-2480` and `:2598-2639`):

```c
static void btusb_notify(struct hci_dev *hdev, unsigned int evt)
{
	struct btusb_data *data = hci_get_drvdata(hdev);

	BT_DBG("%s evt %d", hdev->name, evt);

	if (hci_conn_num(hdev, SCO_LINK) != data->sco_num) {
		data->sco_num = hci_conn_num(hdev, SCO_LINK);
		data->air_mode = evt;
		schedule_work(&data->work);
	...
	if (data->sco_num > 0) {
	...
		if (data->air_mode == HCI_NOTIFY_ENABLE_SCO_CVSD) {
		...
		} else if (data->air_mode == HCI_NOTIFY_ENABLE_SCO_TRANSP) {
```

(`new_alts` starts at 0 and stays 0 when the air mode is neither; `btusb_switch_alt_setting(hdev, new_alts)` follows at `:2641`.)

Two links, one goes down: `hci_conn_cleanup()` notifies `HCI_NOTIFY_DISABLE_SCO` for a SCO link whose `conn->setting` air mode is CVSD or transparent (`net/bluetooth/hci_conn.c:155-161`). The count falls from 2 to 1, so `btusb_notify()` stores `HCI_NOTIFY_DISABLE_SCO` as the air mode; the remaining link is then switched to alternate setting 0.

Single link: a SCO connection is counted from the start of its setup (`hci_conn_hash` add), so any other connection added or removed in that window (a `HCI_NOTIFY_CONN_ADD` or `HCI_NOTIFY_CONN_DEL`) changes `hci_conn_num()` and makes btusb store that event as the air mode. When the link comes up the count is unchanged, so its own `ENABLE_SCO_*` notification is ignored, and the link would run on alternate setting 0.

A failed setup also notifies (`net/bluetooth/hci_event.c:5265-5274`, `hci_sync_conn_complete_evt()`):

```c
	if (conn->codec.data_path == 0 && hdev->notify) {
		switch (ev->air_mode) {
		case 0x02:
			hdev->notify(hdev, HCI_NOTIFY_ENABLE_SCO_CVSD);
			break;
		case 0x03:
			hdev->notify(hdev, HCI_NOTIFY_ENABLE_SCO_TRANSP);
			break;
		}
	}
```

This runs whatever the status of the event, so a failed second setup is reported as a link coming up. Hitalo Souza's patch 6/6 of his v3 series ("Bluetooth: hci_event: Notify the driver only of SCO links that came up", 2026-10-08, patchwork 14875454) adds a status check to that condition; the series is still `new` on patchwork, no v4, the only reply on its cover letter is a maintainer's of 2026-10-09 saying that the automated reviewer flags more problems. His cover letter names the case this item also addresses: btusb can still stop audio "when a SCO link that was up goes down while another one stays up; that is not changed here".

The first btusb-only candidate fix (a link-up always applies its air mode; a link-down keeps the mode while other links remain) was reviewed on 2026-11-01 and found not sufficient: it keeps the last link-up's mode with mixed codecs, and the failed-setup notification above can put a surviving CVSD call on the transparent setting.

### The change

Two patches, against bluetooth-next 42b8c2d72926.

1. Core: each SCO link remembers the air mode it came up with. A new field `conn->air_mode`, set from the Air_Mode of the Synchronous Connection Complete event of a link that came up, and, for a SCO link that completes with Connection Complete, the CVSD mode the existing notification already assumes. Named constants `HCI_AIR_MODE_*` for the four Air_Mode values. A helper `hci_conn_sco_up_num()` counts the SCO/eSCO links that are connected, carry their data over HCI (`codec.data_path == 0`) and have a given air mode. The event's air mode is used, not `conn->setting`: `conn->setting` is written only for outgoing setups, is not stored on a deferred accept, and is overwritten by a second `connect()` on a live link before that fails with EBUSY (the same path as the CO-02 air-mode finding).
2. btusb: `btusb_work()` picks the alternate setting from the links that are up when it runs: CVSD links use the existing table, any transparent link selects the transparent setting, no link up stops the isochronous transfers. `btusb_notify()` only schedules the work, for the three SCO enable/disable events, and no longer keeps `sco_num` or `air_mode`. `Fixes: baac6276c0a9`.

### The patches, verbatim

Written against bluetooth-next 42b8c2d72926; not sent. Mail header lines with addresses are dropped.

#### Patch 1 of 2

```diff
Date: Sun, 1 Nov 2026 18:33:56 +0100
Subject: [PATCH 1/2] Bluetooth: Keep the air mode of SCO links that came up

The air mode of a synchronous link is passed to the driver as
HCI_NOTIFY_ENABLE_SCO_CVSD or HCI_NOTIFY_ENABLE_SCO_TRANSP and not kept.
conn->setting is the voice setting the host asked for, which is not
always the air mode of the link: it is left unset for an incoming
connection, which is accepted with the setting of its socket, and
hci_connect_sco() overwrites it for an existing connection, also one
whose link is up.

Keep in the connection the air mode reported by Synchronous Connection
Complete, and for a SCO link that completes with Connection Complete
the one its notification already assumes. Add hci_conn_sco_up_num() to
count the SCO links that are up by air mode, so that a driver can
configure itself from the links that exist instead of from the last
notification.

Signed-off-by: Iaroslav Voitovych
---
 include/net/bluetooth/hci.h      |  6 ++++++
 include/net/bluetooth/hci_core.h | 25 +++++++++++++++++++++++++
 net/bluetooth/hci_event.c        |  2 ++
 3 files changed, 33 insertions(+)

diff --git a/include/net/bluetooth/hci.h b/include/net/bluetooth/hci.h
index 1c992e87534d7..419d756b5d21b 100644
--- a/include/net/bluetooth/hci.h
+++ b/include/net/bluetooth/hci.h
@@ -2762,6 +2762,12 @@ struct hci_ev_sync_conn_complete {
 	__u8     air_mode;
 } __packed;
 
+/* Air_Mode of HCI_Synchronous_Connection_Complete */
+#define HCI_AIR_MODE_ULAW	0x00
+#define HCI_AIR_MODE_ALAW	0x01
+#define HCI_AIR_MODE_CVSD	0x02
+#define HCI_AIR_MODE_TRANSP	0x03
+
 #define HCI_EV_SYNC_CONN_CHANGED	0x2d
 struct hci_ev_sync_conn_changed {
 	__u8     status;
diff --git a/include/net/bluetooth/hci_core.h b/include/net/bluetooth/hci_core.h
index 9d5d3ab4a075e..36cfa06894867 100644
--- a/include/net/bluetooth/hci_core.h
+++ b/include/net/bluetooth/hci_core.h
@@ -762,6 +762,7 @@ struct hci_conn {
 	__u16		disc_timeout;
 	__u16		conn_timeout;
 	__u16		setting;
+	__u8		air_mode;
 	__u16		auth_payload_timeout;
 	__u16		le_conn_min_interval;
 	__u16		le_conn_max_interval;
@@ -1132,6 +1133,30 @@ static inline unsigned int hci_conn_num(struct hci_dev *hdev, __u8 type)
 	}
 }
 
+/* Number of SCO and eSCO links that are up, carry their data over HCI and
+ * use the given air mode (HCI_AIR_MODE_*)
+ */
+static inline unsigned int hci_conn_sco_up_num(struct hci_dev *hdev,
+					       __u8 air_mode)
+{
+	struct hci_conn_hash *h = &hdev->conn_hash;
+	struct hci_conn *c;
+	unsigned int num = 0;
+
+	rcu_read_lock();
+
+	list_for_each_entry_rcu(c, &h->list, list) {
+		if ((c->type == SCO_LINK || c->type == ESCO_LINK) &&
+		    c->state == BT_CONNECTED && !c->codec.data_path &&
+		    c->air_mode == air_mode)
+			num++;
+	}
+
+	rcu_read_unlock();
+
+	return num;
+}
+
 static inline unsigned int hci_conn_count(struct hci_dev *hdev)
 {
 	struct hci_conn_hash *c = &hdev->conn_hash;
diff --git a/net/bluetooth/hci_event.c b/net/bluetooth/hci_event.c
index d05934fef4d99..9237d05557ca2 100644
--- a/net/bluetooth/hci_event.c
+++ b/net/bluetooth/hci_event.c
@@ -3366,6 +3366,7 @@ static void hci_conn_complete_evt(struct hci_dev *hdev, void *data,
 	} else if (ev->link_type == SCO_LINK) {
 		switch (conn->setting & SCO_AIRMODE_MASK) {
 		case SCO_AIRMODE_CVSD:
+			conn->air_mode = HCI_AIR_MODE_CVSD;
 			if (hdev->notify)
 				hdev->notify(hdev, HCI_NOTIFY_ENABLE_SCO_CVSD);
 			break;
@@ -5232,6 +5233,7 @@ static void hci_sync_conn_complete_evt(struct hci_dev *hdev, void *data,
 
 		conn->state  = BT_CONNECTED;
 		conn->type   = ev->link_type;
+		conn->air_mode = ev->air_mode;
 
 		hci_debugfs_create_conn(conn);
 		hci_conn_add_sysfs(conn);

base-commit: 42b8c2d729268a65a2d98064e8dc59ff53646b14
-- 
2.43.0
```

#### Patch 2 of 2

```diff
Date: Sun, 1 Nov 2026 18:33:58 +0100
Subject: [PATCH 2/2] Bluetooth: btusb: Pick the SCO alternate setting from the
 links that are up

btusb_notify() takes the air mode from whichever notification changed
the number of SCO connections, and btusb_work() selects alternate
setting 0, which has no isochronous bandwidth, for anything that is
neither CVSD nor transparent:

- When one of two SCO links goes down, HCI_NOTIFY_DISABLE_SCO becomes
  the air mode, and the link that stays up is moved to alternate
  setting 0.
- A SCO connection is counted from the start of its setup. When another
  connection is added or removed meanwhile, HCI_NOTIFY_CONN_ADD or
  HCI_NOTIFY_CONN_DEL becomes the air mode, and the notification of the
  link coming up is ignored, as the count does not change.
- The link-up notification is also sent for a setup that failed, so a
  failed transparent setup can move a CVSD link that is up to the
  transparent setting.
- With a CVSD and a transparent link up, the setting is that of the
  last notification.

Select the alternate setting in btusb_work() from the SCO links that
are up when it runs: the CVSD table for CVSD links, the transparent
setting when a transparent link is up, and no isochronous transfers
when no link is up. The notifications only schedule the work, so
notifications that come before it runs are all taken into account.

Fixes: baac6276c0a9 ("Bluetooth: btusb: handle mSBC audio over USB Endpoints")
Signed-off-by: Iaroslav Voitovych
---
 drivers/bluetooth/btusb_main.c | 26 ++++++++++++++++----------
 1 file changed, 16 insertions(+), 10 deletions(-)

diff --git a/drivers/bluetooth/btusb_main.c b/drivers/bluetooth/btusb_main.c
index 92a78a7e60396..26c18cf238fa6 100644
--- a/drivers/bluetooth/btusb_main.c
+++ b/drivers/bluetooth/btusb_main.c
@@ -1069,8 +1069,6 @@ struct btusb_data {
 	__u8 cmdreq;
 	__u8 proto;
 
-	unsigned int sco_num;
-	unsigned int air_mode;
 	bool usb_alt6_packet_flow;
 	int isoc_altsetting;
 	int suspend_count;
@@ -2473,10 +2471,13 @@ static void btusb_notify(struct hci_dev *hdev, unsigned int evt)
 
 	BT_DBG("%s evt %d", hdev->name, evt);
 
-	if (hci_conn_num(hdev, SCO_LINK) != data->sco_num) {
-		data->sco_num = hci_conn_num(hdev, SCO_LINK);
-		data->air_mode = evt;
+	/* btusb_work() reads the SCO links that are up when it runs */
+	switch (evt) {
+	case HCI_NOTIFY_ENABLE_SCO_CVSD:
+	case HCI_NOTIFY_ENABLE_SCO_TRANSP:
+	case HCI_NOTIFY_DISABLE_SCO:
 		schedule_work(&data->work);
+		break;
 	}
 }
 
@@ -2585,6 +2586,7 @@ static void btusb_work(struct work_struct *work)
 {
 	struct btusb_data *data = container_of(work, struct btusb_data, work);
 	struct hci_dev *hdev = data->hdev;
+	unsigned int cvsd, transp;
 	int new_alts = 0;
 	int err;
 
@@ -2595,7 +2597,11 @@ static void btusb_work(struct work_struct *work)
 	if (data->proto == BTUSB_PROTO_H4)
 		return;
 
-	if (data->sco_num > 0) {
+	/* Pick the alternate setting from the SCO links that are up */
+	cvsd = hci_conn_sco_up_num(hdev, HCI_AIR_MODE_CVSD);
+	transp = hci_conn_sco_up_num(hdev, HCI_AIR_MODE_TRANSP);
+
+	if (cvsd || transp) {
 		if (!test_bit(BTUSB_DID_ISO_RESUME, &data->flags)) {
 			err = usb_autopm_get_interface(data->isoc ? data->isoc : data->intf);
 			if (err < 0) {
@@ -2607,18 +2613,18 @@ static void btusb_work(struct work_struct *work)
 			set_bit(BTUSB_DID_ISO_RESUME, &data->flags);
 		}
 
-		if (data->air_mode == HCI_NOTIFY_ENABLE_SCO_CVSD) {
+		if (!transp) {
 			if (hdev->voice_setting & 0x0020) {
 				static const int alts[3] = { 2, 4, 5 };
 				unsigned int sco_idx;
 
-				sco_idx = min_t(unsigned int, data->sco_num - 1,
+				sco_idx = min_t(unsigned int, cvsd - 1,
 						ARRAY_SIZE(alts) - 1);
 				new_alts = alts[sco_idx];
 			} else {
-				new_alts = data->sco_num;
+				new_alts = cvsd;
 			}
-		} else if (data->air_mode == HCI_NOTIFY_ENABLE_SCO_TRANSP) {
+		} else {
 			/* Bluetooth USB spec recommends alt 6 (63 bytes), but
 			 * many adapters do not support it.  Alt 1 appears to
 			 * work for all adapters that do not have alt 6, and
-- 
2.43.0
```

### Tests and results

**Build and style (measured).** `checkpatch --strict` run in the tree: 0 errors, 0 warnings, 0 checks on both patches (63 and 65 lines checked). Built against bluetooth-next 42b8c2d72926 with the patches (x86_64 and i386, `CONFIG_BT=m`, `CONFIG_BT_HCIBTUSB=m`, W=1): `make` returned 0, 0 warnings, for the base tree and the patched tree alike. A variant of patch 2 adapted to the file name and context of Ubuntu 7.0.0-42's `btusb.c`, with patch 1, also builds (make returned 0).

**The scripted model (measured, 20 scenarios).** What it is: the model extracts `btusb_notify()` and `btusb_work()` verbatim from each variant's source file (and `hci_conn_sco_up_num()` for the redesign) and links them to stubs and a scripted copy of the core's behaviour: the order in which bluetooth-next 42b8c2d72926 changes a connection and calls `hdev->notify()` (hash add and `sco_num++` without a notification for SCO; Synchronous Connection Complete sets BT_CONNECTED or BT_CLOSED and then notifies from the event's Air_Mode, also on failure; `hci_conn_del()` removes from the hash, then cleanup notifies DISABLE_SCO when the connection's setting is CVSD or transparent). A scheduled work that is already pending does nothing (coalescing); in some scenarios the work is held back until after several notifications. After each step the model compares the USB alternate setting btusb chose with a "truth" computed from the links actually up and the air mode actually on air: any transparent link gives alternate setting 1 (no alternate 6 on the modelled device), n CVSD links give the table entry for n, no link gives alternate setting 0 and no isochronous transfers. This is a model of the code's sequencing, not a kernel run. The truth rule for mixed links ("transparent wins") is the same rule the redesign uses, so the redesign's 20 of 20 on the mixed scenarios shows consistency with that rule, not that the rule is right for hardware.

Results (right of 20; "+6/6" means with Hitalo Souza's status check applied):

| Variant | Right |
|---|---|
| original (bluetooth-next 42b8c2d72926) | 5 of 20 |
| original + 6/6 | 7 of 20 |
| first candidate (btusb only) | 16 of 20 (fails S8, S10, S12b, S17) |
| first candidate + 6/6 | 17 of 20 (fails S10, S12b, S17) |
| redesign, with or without 6/6 | 20 of 20 |
| redesign keyed on `conn->setting` instead of the event's air mode | 17 of 20 (fails S11b, S16, S17) |

The 20 scenarios: S1 one mSBC link; S2 one mSBC link, ACL/LE deleted while its setup is pending; S3 one CVSD link, ACL/LE added while its setup is pending; S4 two CVSD links, first down then second; S5 two mSBC links, first down then second; S6 mSBC up, second mSBC setup fails (air mode transparent in the event); S7 CVSD up, mSBC setup pending when CVSD goes down, then up; S8 CVSD up, transparent second setup fails, cleanup; S9 CVSD + transparent up, CVSD removed first; S10 CVSD + transparent up, transparent removed first; S11 setup started, cancelled, started again at once; S11b CVSD setup cancelled, transparent setup at once, the abandoned CVSD setup completes on it; S12 two CVSD links come up before the worker runs; S12b CVSD and transparent links come up before the worker runs; S13 CVSD down then transparent up before the worker runs; S14 mSBC link ends while a second setup is pending, that setup fails; S15a two CVSD links, hang up the second then the first; S15b the same with two mSBC links; S16 incoming mSBC link (deferred accept, `conn->setting` left 0); S17 mSBC up, a second `connect()` overwrites its `conn->setting`, second headset CVSD. In S7 and S13 the original and the first candidate also show a benign step where the stream keeps running with no link up. Each failure of the first candidate also has a wrong step that does not depend on it.

**Timing argument (from source, checked).** There is one work item (`data->work`), not two workers. The notifications only schedule it. A work item never runs twice at once, and a notification arriving during a run queues one more run. Each run counts the links that are up at that moment. So the last run always comes after the last notification. The order of events supports this: when a link goes down, `hci_conn_del()` removes it from the connection list with `hci_conn_hash_del()` (`net/bluetooth/hci_conn.c:1307`; that function does `list_del_rcu()` and `synchronize_rcu()`, `hci_core.h:1076-1077`) before `hci_conn_cleanup()` (called at `hci_conn.c:1362`) sends the "SCO down" notification. When a link comes up, its state and air mode are set before the "SCO up" notification (`hci_event.c`; the patch 1 hunk sits before the notify call). A failed setup never reaches BT_CONNECTED and is not counted.

### Not known, not claimed

- Never loaded on hardware and never run in a kernel, QEMU or otherwise. btusb cannot be exercised in QEMU (the emulator has no USB isochronous path). Only the scripted model and a build check exist. No USB capture exists for the redesign.
- Whether the surviving call keeps enough USB bandwidth and stays audible when the other call ends, on the real controller: open. No silent call from this cause has been seen on the laptop; the trigger appears twice in its journal.
- Whether "any transparent link wins" is the right rule for a CVSD link alongside a transparent link. It is a chosen rule, not a hardware fact. With mixed links the alternate setting for the transparent link carries enough bandwidth only if the controller accepts it for both; not measured.
- That the 20 scenarios are exhaustive: they cover combinations of link states, not every interleaving of events relative to the work item. The ordering argument above is from reading source, not an exhaustive model.
- A failed `usb_set_interface()` is handled as before (the error is logged; the redesign does not retry and was not re-examined).
- Behaviour of the redesign with SCO over a non-HCI data path (`codec.data_path != 0`): such links are excluded from the count, same as the existing notification excludes them.
- Stable lines and Ubuntu: the redesign has only been built for bluetooth-next and for Ubuntu 7.0.0-42's tree. Not tried elsewhere.

### Open points and questions for the reviewer

1. Is deriving the alternate setting from the links that are up (counted when the work runs) the right design, compared with keeping per-link state in btusb? The core patch adds a field to `struct hci_conn` and a helper in `hci_core.h`; a driver-only alternative would need per-link information the driver does not have.
2. Naming and placement: `conn->air_mode`, `hci_conn_sco_up_num()`, `HCI_AIR_MODE_*`. Is a different spelling or place preferred? `HCI_AIR_MODE_ULAW` and `HCI_AIR_MODE_ALAW` are defined but unused.
3. Mixed-link rule (transparent wins as soon as any transparent link is up): is this the right choice for a CVSD link that stays up alongside a transparent one? What do other controllers or drivers do?
4. Ordering not exhaustively modelled. The reasoning that the last run follows the last notification rests on the single work item and on `hci_conn_del()` removing from the hash before the notification. Is there an ordering the reviewer sees where the work counts a link that is already gone, or misses one that has just come up?
5. Failed `usb_set_interface()` is handled as before. Is a retry or a fallback expected?
6. The failed-setup notification (`hci_event.c:5265-5274` sends link-up whatever the status) is made harmless for btusb by counting only BT_CONNECTED links, but other drivers using `hdev->notify` still receive it. Hitalo Souza's 6/6 changes that notification (status check). Our redesign does not need his patch and works with or without it (20 of 20 either way). Should the core notification also change, and by whose patch?
7. Backport: `Fixes: baac6276c0a9` names the commit that added mSBC over USB endpoints. Is that the right base, and is a stable tag wanted on patch 1 (a new field and helper) at all?

**Draft question to Hitalo Souza (not sent).** A reply to his patch 6/6, which touches the same notification:

```text
Hi Hitalo,

Do you plan to resend this patch, alone or in a v4 of the series?

I am preparing a btusb fix for the case you identified in your v3
cover letter, where one SCO link goes down while another stays up:
btusb then moves the remaining link to alternate setting 0. It selects the alternate setting from the SCO
links that are up, so it does not depend on this patch, but both
concern the same notification and I would like them to fit together.

Thanks,
Iaroslav
```

There is no optional sentence about carrying his patch in our series, and none is intended: the redesign does not need it. The wording "the case you identified in your v3 cover letter" comes from a check against his cover letter, which names this case itself.

**Open decision (the author's, not yet taken).** Whether to post that question at all. Recommendation: not yet. The list's CI runs only after a public send, so it cannot come before a first contact; a review of the redesign by outside reviewers (this document) comes first, then the choice between posting the short question and simply citing his patch and the remaining case in the cover letter of our series. If he does not answer, cite his series and go ahead. A laptop test of the redesign needs `bluetooth.ko` and `btusb.ko` built and installed together, because the core patch changes a structure; that test is not started.

### Route and next step

1. Outside review of the redesign (this document).
2. The list CI bot's checks run locally on the base and on base plus the two patches (not yet done for this redesign).
3. Decide on the note to Hitalo Souza (see above), then send the two patches as a series, with the sends run by the author himself.
4. Optional, with the author's word: a laptop run of the redesign with two headsets in hands-free, hanging up one, with a USB capture; this needs the new `bluetooth.ko` and `btusb.ko` together and a cold boot.

---

## CO-30 — defer a SCO connect until the aborting link is gone (RFC prototype)

### At a glance

| Field | Content |
|---|---|
| Target | `net/bluetooth/sco.c`, one patch marked RFC, built on CO-02 v7 (it needs the `-ECONNABORTED` refusal that v7's patch 2 adds). |
| State on 2026-11-02 | Prototype, tested in QEMU only. Applies cleanly (`git am`) on bluetooth-next 42b8c2d72926 with CO-02 v7 on top. Not posted. Waiting. |
| Asked of the reviewer | A view on the approach in principle: refuse with -ECONNABORTED (CO-02) or defer the connect() and complete it asynchronously (this RFC). Not a request to review the code line by line. |

### Background

CO-02 makes a connect() to a connection that is being torn down fail at once with -ECONNABORTED. PipeWire 1.0.5, which closes and reconnects the SCO socket on an HFP codec change, retries ECONNABORTED twice immediately (a retry loop it has had since 2021), within microseconds. The old link's Disconnection Complete arrives tens to hundreds of milliseconds later, so both retries fail too. Measured on the laptop with CO-02 applied and a stream playing: audio returned about 5 seconds after the refused switch, when WirePlumber suspended the failed node and the next connect found no old link. Before CO-02 no link followed at all.

### Root cause

The refusal is correct but does not let an immediate retry succeed. The prototype relies on this ordering, which was checked from source on bluetooth-next 42b8c2d72926 with CO-02 v7: the cmd_sync queue's `hci_disconnect_sync()` waits for `HCI_EV_DISCONN_COMPLETE` (`net/bluetooth/hci_sync.c:5990-5994`), and the event handler runs before the sync waiter is woken (`net/bluetooth/hci_event.c:8133`, then `:8141`). The abort of the old link is queued on that queue first; a connect queued behind it therefore runs after the old `hci_conn` is gone and finds no connection to reuse.

### The change

When `hci_connect_sco()` reports -ECONNABORTED, `sco_connect()` leaves the socket in BT_CONNECT (as for a link being set up) and queues the connect on the cmd_sync queue behind the abort. connect() returns -EINPROGRESS for a non-blocking socket; the socket becomes writable when the new link is up, or reports the error if it is not. If the socket is closed meanwhile, the queued connect does nothing. If the controller is closed or unregistered before it ran, the socket is failed with ENETDOWN. It changes the contract of connect(): the wait includes the old link's teardown, up to `HCI_CMD_TIMEOUT` (2 seconds) before it fails cleanly.

It does not cover: a reuse that happens before `hci_conn_timeout()` starts (the old link's codec is kept; this is the CO-02 mismatch finding), and a link torn down with no `hci_conn` (another series' case).

### The patches, verbatim

188 lines; shown in full.

```diff
Date: Wed, 21 Oct 2026 05:37:33 +0200
Subject: [PATCH RFC] Bluetooth: SCO: defer a connect until the link being
 aborted is gone

hci_connect_sco() now refuses a connection that is being aborted with
-ECONNABORTED. A socket that connects right after the previous one was
closed, as PipeWire does when the HFP codec changes during a call, still
fails then: the Disconnection Complete of the old link comes tens to
hundreds of milliseconds after the connect, and PipeWire's only retry is
two further connects without any delay.

When hci_connect_sco() reports that, leave the socket in BT_CONNECT, as
for a link being set up, and queue the connect on the cmd_sync queue.
The abort of the old link is queued there ahead of it and returns only
after the Disconnection Complete was handled, so the connect then finds
no connection to reuse and sets up a new link. connect() returns
-EINPROGRESS for a non-blocking socket, and the socket becomes writable
when the new link is up or reports the error when it is not.

If the socket is closed meanwhile the queued connect does nothing. If
the controller is closed or unregistered before it ran, the socket is
failed with ENETDOWN.

Signed-off-by: Iaroslav Voitovych
---
 net/bluetooth/sco.c | 115 +++++++++++++++++++++++++++++++++++++++++++-
 1 file changed, 113 insertions(+), 2 deletions(-)

diff --git a/net/bluetooth/sco.c b/net/bluetooth/sco.c
index 8be48ca9f4c5..288ebe12daed 100644
--- a/net/bluetooth/sco.c
+++ b/net/bluetooth/sco.c
@@ -333,7 +333,12 @@ static int sco_chan_add(struct sco_conn *conn, struct sock *sk,
 	return err;
 }
 
-static int sco_connect(struct sock *sk)
+static int sco_connect_defer(struct sock *sk, struct hci_dev *hdev);
+
+/* @deferred: the connect was deferred until the previous link to the device
+ * was gone, the socket is in BT_CONNECT and has no hci_conn yet.
+ */
+static int __sco_connect(struct sock *sk, bool deferred)
 {
 	struct sco_conn *conn;
 	struct hci_conn *hcon;
@@ -377,6 +382,12 @@ static int sco_connect(struct sock *sk)
 			       READ_ONCE(sk->sk_sndtimeo));
 	if (IS_ERR(hcon)) {
 		err = PTR_ERR(hcon);
+
+		/* The link to this device is being disconnected: connect once
+		 * it is gone instead of failing.
+		 */
+		if (err == -ECONNABORTED && !deferred)
+			err = sco_connect_defer(sk, hdev);
 		goto unlock;
 	}
 
@@ -392,7 +403,8 @@ static int sco_connect(struct sock *sk)
 	/* Recheck state after reacquiring the socket lock, as another
 	 * thread may have changed it (e.g., closed the socket).
 	 */
-	if (sk->sk_state != BT_OPEN && sk->sk_state != BT_BOUND) {
+	if (deferred ? (sk->sk_state != BT_CONNECT || sco_pi(sk)->conn) :
+	    (sk->sk_state != BT_OPEN && sk->sk_state != BT_BOUND)) {
 		release_sock(sk);
 		sco_conn_put(conn);
 		hci_conn_drop(hcon);
@@ -417,6 +429,8 @@ static int sco_connect(struct sock *sk)
 	if (hcon->state == BT_CONNECTED) {
 		sco_sock_clear_timer(sk);
 		sk->sk_state = BT_CONNECTED;
+		if (deferred)
+			sk->sk_state_change(sk);
 	} else {
 		sk->sk_state = BT_CONNECT;
 		sco_sock_set_timer(sk, READ_ONCE(sk->sk_sndtimeo));
@@ -430,6 +444,103 @@ static int sco_connect(struct sock *sk)
 	return err;
 }
 
+struct sco_defer {
+	struct sock *sk;
+};
+
+static void sco_connect_fail(struct sock *sk, int err)
+{
+	lock_sock(sk);
+	if (sk->sk_state == BT_CONNECT && !sco_pi(sk)->conn) {
+		sk->sk_state = BT_CLOSED;
+		sk->sk_err = -err;
+		sk->sk_state_change(sk);
+		sock_set_flag(sk, SOCK_ZAPPED);
+	}
+	release_sock(sk);
+}
+
+/* Runs on the cmd_sync queue, behind the abort of the previous link: by now
+ * its Disconnection Complete event has been handled and the hci_conn is gone.
+ */
+static int sco_connect_sync(struct hci_dev *hdev, void *data)
+{
+	struct sco_defer *d = data;
+	struct sock *sk = d->sk;
+	int err;
+
+	/* Nothing to do if the socket was closed meanwhile */
+	lock_sock(sk);
+	if (sk->sk_state != BT_CONNECT || sco_pi(sk)->conn) {
+		release_sock(sk);
+		return 0;
+	}
+	release_sock(sk);
+
+	err = __sco_connect(sk, true);
+	if (err)
+		sco_connect_fail(sk, err);
+
+	return err;
+}
+
+static void sco_connect_destroy(struct hci_dev *hdev, void *data, int err)
+{
+	struct sco_defer *d = data;
+
+	/* Dropped without running, e.g. the controller was closed */
+	if (err == -ECANCELED)
+		sco_connect_fail(d->sk, -ENETDOWN);
+
+	sock_put(d->sk);
+	kfree(d);
+}
+
+/* Called with hdev locked. The socket waits in BT_CONNECT, as for a link being
+ * set up, and sco_connect_sync() makes the connection.
+ */
+static int sco_connect_defer(struct sock *sk, struct hci_dev *hdev)
+{
+	struct sco_defer *d;
+	int state, err;
+
+	d = kzalloc_obj(struct sco_defer);
+	if (!d)
+		return -ENOMEM;
+
+	lock_sock(sk);
+	state = sk->sk_state;
+	if (state != BT_OPEN && state != BT_BOUND) {
+		release_sock(sk);
+		kfree(d);
+		return -EBADFD;
+	}
+	sk->sk_state = BT_CONNECT;
+	release_sock(sk);
+
+	sock_hold(sk);
+	d->sk = sk;
+
+	err = hci_cmd_sync_queue(hdev, sco_connect_sync, d,
+				 sco_connect_destroy);
+	if (err) {
+		sock_put(sk);
+		kfree(d);
+
+		lock_sock(sk);
+		if (sk->sk_state == BT_CONNECT)
+			sk->sk_state = state;
+		release_sock(sk);
+	}
+
+	return err;
+}
+
+static int sco_connect(struct sock *sk)
+{
+	return __sco_connect(sk, false);
+}
+
 static int sco_send_frame(struct sock *sk, struct sk_buff *skb,
 			  const struct sockcm_cookie *sockc)
 {
-- 
2.43.0
```

### Tests and results

All measured in QEMU with BlueZ's emulator; no hardware.

- The PipeWire-style retry case (a new socket plus two immediate retries after an ECONNABORTED, emulating PipeWire 1.0.5's loop). First measurement (2026-10-21, an earlier kernel): unpatched fail 3 of 3; refuse fail 3 of 3; refuse + hold fail 3 of 3; deferral pass 3 of 3 (uniprocessor) and 3 of 3 (SMP). Repeat on 2026-11-01 at the bluetooth-next tip (7ac22ae8fa1b, 7.3.0-rc6) with CO-02 v7 alone: the retry case "Reconnect During Disconnect Retry" Failed in 3 of 3 runs (ECONNABORTED); with the RFC on top of v7 (98bc5ffb5088) Passed in 3 of 3 runs.
- sco-tester (33 cases): 33 of 33 in each of 3 runs on the tip with v7 alone, and 33 of 33 in each of 3 runs with the RFC on top. The two experimental cases for a socket close and a power-off while a deferred connect is pending ("Exp Close Pending", "Exp Poweroff Pending") passed in one run each on the RFC kernel. No kernel report in any of these logs.
- The first prototype (2026-10-21) also passed the Reconnect During Disconnect and After Disconnect cases on a uniprocessor kernel (3 of 3), an SMP kernel with 4 CPUs (10 of 10) and a KCSAN SMP kernel (5 of 5). checkpatch `--strict` clean, W=1 `-Werror` clean, sparse `C=2` no new findings, at that date.

### Not known, not claimed

- Not run on hardware.
- The destroy-callback failure branch (the queued item dropped without running) is untested beyond the poweroff case above.
- What WirePlumber and PipeWire do on seeing EINPROGRESS where they previously saw ECONNABORTED: not checked in a real stack.
- PulseAudio's and oFono's handling of the changed contract: not checked.
- Interaction with the mismatch finding of CO-02 (a reuse before `hci_conn_timeout()` starts keeps the old link's air mode): the deferral does not address it.
- Whether a connect() that can wait up to the command timeout (2 s) is acceptable for a blocking socket: a design question.

### Open points and questions for the reviewer

1. Is changing connect() semantics acceptable (EINPROGRESS plus a wait, instead of a fast -ECONNABORTED that userspace must retry)? Or should this be left to userspace (a PipeWire-side retry that waits for the old link)?
2. If acceptable, is the cmd_sync queue the right place to order the connect behind the abort, or should `sco_connect()` wait on the hci_conn state in another way?
3. Should this be an RFC series on top of CO-02 or folded into it?

### Route and next step

Waiting. First, the maintainers' answer to CO-02 (including its Sashiko findings and the BlueZ test port); then, if there is interest, posting the RFC as the question in the CO-02 cover letter already offers. The alternative route, a PipeWire-side retry that waits for the old link, is a separate item.

## CO-35 — The L2CAP ECRED deferred-accept hang on the stable lines (7.3.y, 7.2.y, 6.18.y, 6.12.y, 6.6.y)

### At a glance

| | |
|---|---|
| Problem | BlueZ's l2cap-tester case "L2CAP Ext-Flowctl Server - Accept 2 Close 1" never finishes on stable kernels: a socket-lock self-deadlock in the deferred ECRED accept path |
| Fix in mainline | Pauli Virtanen, two commits, authored 2026-08-29: `608e0b7a675b2` "Bluetooth: L2CAP: add l2cap_chan_close_unlocked() and locking helpers" (the helpers) and `32d86e048d8ef` "Bluetooth: L2CAP: hold conn->lock for __l2cap_ecred_conn_rsp_defer" (the fix, `Fixes: ab4eedb790ca`). In mainline since the 7.4 merge window; neither carries `Cc: stable`; neither was in any stable queue when last checked (2026-10-28 20:34 UTC) |
| Package | One request for 7.3.y and 7.2.y (both commits as they are, in order); three series `[PATCH 6.18.y 0/2]`, `[PATCH 6.12.y 0/2]`, `[PATCH 6.6.y 0/2]` (cover letter plus two backported patches each). A second small request for 7.3.y only: `5874f8d03268` (an unrelated SCI stall, tracked as BT-15) |
| State on 2026-11-02 | Send package ready for review. **Nothing sent.** |
| Not covered | 6.1.y, 5.15.y, 5.10.y hang too once ECRED is enabled; the pair does not apply there and no fix exists |
| Asked of the reviewer | Whether the packaging (option 2 for 7.x, option 3 series for 6.18/6.12/6.6), the size exception, the backport adaptations and the cause statement are acceptable; the open points below |

### Background

The l2cap-tester case "L2CAP Ext-Flowctl Server - Accept 2 Close 1" opens a deferred-setup ECRED (Enhanced Credit Based Mode) listening socket, connects two channels in one request, accepts and closes the first, then reads from the second to trigger the deferred response. On the stable kernels below the case stops after the line "Accept deferred setup" and never finishes. The BlueZ commit that added the test (Pauli Virtanen, 2026-09-02) says "This triggers deadlock on some kernel versions". On bluetooth-next the case passes.

Stable kernels that hang with the plain tree **[measured]**, case run alone, 180 s limit, QEMU/KVM with 4 vCPUs, BlueZ `doc/tester.config` plus `CONFIG_DETECT_HUNG_TASK=y` (20 s) for the 2026-11-01 round:

| tag | plain | with the series (7.x: the upstream pair) |
|---|---|---|
| v7.3.1 | hang | pass in 1.119 s |
| v7.2.14 | hang | pass in 1.068 s |
| v6.18.60 | hang | pass in 1.126 s |
| v6.12.115 | hang | pass in 1.078 s |
| v6.6.161 | hang | pass in 1.402 s |

Every plain hang produced 5 to 7 hung-task reports, each naming the socket lock held from `l2cap_sock_recvmsg` and, as a nested subclass `/1`, awaited in `l2cap_sock_teardown_cb` **[measured]**. Earlier rounds (2026-10-28) gave the same verdicts on v7.3, 7.2.12/7.2.13, 6.18.58/6.18.59, 6.12.114 and 6.6.160.

Newest tags as of 2026-11-01: 7.3.1, 7.2.14 (the kernel.org release list of 2026-11-01 shows 7.2.15 and marks 7.2 end of life; see open points), 6.18.60, 6.12.115, 6.6.161, 6.1.191, 5.15.224, 5.10.273.

### Root cause

What the hung-task detector shows **[measured]** (plain v7.3, 2026-10-28; the same on plain v6.1.190 with ECRED enabled):

```text
INFO: task l2cap-tester:38 blocked for more than 20 seconds.
locks held by l2cap-tester/38: 2
 #0: (sk_lock-AF_BLUETOOTH-BTPROTO_L2CAP){+.+.}-{0:0}, at: l2cap_sock_recvmsg+0x5d/0x770
 #1: (sk_lock-AF_BLUETOOTH-BTPROTO_L2CAP/1){+.+.}-{0:0}, at: l2cap_sock_teardown_cb+0x10a/0x370
```

Both lines carry the same lock address in the log (omitted here). The task holds a socket's lock from `l2cap_sock_recvmsg()` and waits for the same lock in `l2cap_sock_teardown_cb()`. The second acquisition is a nested subclass (`lock_sock_nested(sk, atomic_read(&chan->nesting))`), which is why lockdep, enabled in these images, reports no recursive locking. No stack trace was printed, only the lock list.

The path **[source]**, tree v7.3.1:

```c
/* net/bluetooth/l2cap_sock.c, l2cap_sock_recvmsg(), lines 1259-1266 */
	lock_sock(sk);

	if (sk->sk_state == BT_CONNECT2 && test_bit(BT_SK_DEFER_SETUP,
						    &bt_sk(sk)->flags)) {
		if (pi->chan->mode == L2CAP_MODE_EXT_FLOWCTL) {
			sk->sk_state = BT_CONNECTED;
			pi->chan->state = BT_CONNECTED;
			__l2cap_ecred_conn_rsp_defer(pi->chan);
```

`__l2cap_ecred_conn_rsp_defer()` is therefore called with the socket lock held. It walks every channel of the request (v7.3.1, `net/bluetooth/l2cap_core.c` line 3961, `__l2cap_chan_list_id(conn, id, l2cap_ecred_rsp_defer, &data)`) and the per-channel callback does:

```c
/* net/bluetooth/l2cap_core.c, l2cap_ecred_rsp_defer(), lines 3925-3929, tree v7.3.1 */
	/* Include all channels pending with the same ident */
	if (!rsp->pdu.rsp.result)
		rsp_flex->dcid[rsp->count++] = cpu_to_le16(chan->scid);
	else
		l2cap_chan_del(chan, ECONNRESET);
```

When the first channel of the request was already closed, the response becomes a refusal (`result` non-zero), so `l2cap_chan_del()` runs on each channel of the request, including the caller's own **[inferred]** (the refusal branch was not instrumented). `l2cap_chan_del()` calls `chan->ops->teardown(chan, err)` (`l2cap_core.c` line 691), which is `l2cap_sock_teardown_cb()`, which takes the socket lock again:

```c
/* net/bluetooth/l2cap_sock.c, l2cap_sock_teardown_cb(), line 1731, tree v7.3.1 */
	lock_sock_nested(sk, atomic_read(&chan->nesting));
```

This is a self-deadlock on one socket's lock. Its age **[source]**: the `l2cap_chan_del()` in the defer callback is absent in v6.2 and present in v6.3 (`net/bluetooth/l2cap_core.c` line 3981 of v6.3); it comes from `9aa9d9473f15` "Bluetooth: L2CAP: Fix responding with wrong PDU type" (first in v6.3-rc4), backported as `c357e28b01c4c` (v6.1.22), `c35fd1b9b90a2` (v5.15.105) and `fce0e47e9ec5a` (v5.10.177); the backport identities are from the project log and were not re-verified here. That is why 6.1.y, 5.15.y and 5.10.y hang too once ECRED is on. (An earlier internal note said v5.7; that was wrong and is corrected.)

Relation to the commit named in `Fixes:`: `ab4eedb790ca` ("Bluetooth: L2CAP: Fix corrupted list in hci_chan_del") is in 7.3.y, 7.2.y and 6.18.y, and in 6.12.y and 6.6.y as `f87271d21dd4e` and `efc30877bd4bc`. It is **not** in 6.1.y, 5.15.y or 5.10.y, yet those hang. So the hang is not caused by that commit; `32d86e048d8ef` cures it as a side effect of moving the defer handling into a helper that releases the socket lock first. The mails name `ab4eedb790ca` only because it is upstream's `Fixes:` target.

How the fix was found **[measured]**: a bisect of bluetooth-next between v7.2 (hangs) and `47d4d9f67e92` (passes), limited to `net/bluetooth` and `include/net/bluetooth` (187 commits), with an unrelated SCI stall worked around by applying `5874f8d03268` at each step. Steps: `024e05f73a4c` hang, `c4154fc34772` pass, `c0bb764fc082` hang, `6098ed784e2c` pass, `df5175dfcf48` hang, `889dfdde79e2` pass, `115e6a21c88a` pass, `32d86e048d8e` pass; the first commit without the hang is `32d86e048d8ef`. `dc1ddc65f06df` alone ("take lock for l2cap_chan_del in l2cap_ecred_rsp_defer") does not fix it on 7.2.13. (A first bisect, without the workaround, ended at `5874f8d03268`; its runs filtered on the first word of the case name, ran the whole suite and stopped earlier in "L2CAP LE Client - SCI Fast Mode"; that result was discarded.) The bisect is not cited in the mails.

### The change

**Upstream commits (used as posted).**

1. `608e0b7a675b2` adds `l2cap_chan_lock_conn()` (take `chan->lock`; if `chan->conn` is set take a reference and `conn->lock`, retrying around the lock-order race), the macro `l2cap_chan_unlock_conn()`, and `l2cap_chan_close_unlocked()`; it renames `l2cap_chan_close()` to a static `__l2cap_chan_close()` and switches the callers that already hold the locks to it. Size: the pair is 3 files, 121 insertions and 25 deletions when cherry-picked onto v7.3 **[measured]**; checkpatch counts patch 1 at 130 lines.
2. `32d86e048d8ef` moves the defer handling out of `l2cap_sock_recvmsg()` into a new `l2cap_sock_defer()`, which does a fast-path state check under the socket lock, then `l2cap_chan_lock_conn()`, re-takes the socket lock, and calls the `__l2cap_*_conn_rsp_defer()` function only after `release_sock(sk)`. Lock order: `l2cap_conn::lock`, then `l2cap_chan::lock`, then the socket. This removes the self-deadlock.

These are patches 2 and 7 of Pauli Virtanen's 16-patch series "Bluetooth: L2CAP: fix and annotate l2cap_conn::chan_l locking" (linux-bluetooth, 2026-08-29). All 16 are in mainline and none is on a stable line; eight carry a `Fixes:` tag. The mails say the other patches are not needed for this case and were not tested. One of them, `dc1ddc65f06d` (patch 10), is named in the mails and not requested: on v7.3.1 the pair alone passes the case, and the pair plus `dc1ddc65f06d` also passes it (1.025 s) **[measured]**. Whether other patches of the series fix other real problems on the stable lines was not examined.

**Packaging, by the stable rules** (`Documentation/process/stable-kernel-rules.rst`, unchanged between v7.2.13 and v7.3): option 2 ("ask the stable team to pick up a patch already mainlined") for 7.3.y and 7.2.y, where both commits cherry-pick cleanly; option 3 (a patch "equivalent to a change already mainlined") for the lines where they do not, each patch with a `[ Upstream commit <sha> ]` line, a `[ backport: ... ]` note for the deviation, and the backporter's sign-off last. Cover letters carry the shared facts once.

**Adaptations versus the mainline commits** (the code is otherwise identical, and trees built from them equal the tested commits). Corrected 2026-11-02: the `git patch-id` equals upstream's only where nothing was adapted. Measured with `git patch-id --stable`: patch 2 on 6.18.y equals upstream `32d86e048d8ef`; patch 1 on all three lines (annotations removed) and patch 2 on 6.12.y and 6.6.y (no `MSG_ERRQUEUE` lines) differ, as their adaptations require. What is equal is each regenerated 2026-11-01 patch and its 2026-10-28 predecessor:

| line | patch 1 | patch 2 |
|---|---|---|
| 7.3.y, 7.2.y | none: cherry-pick as is (clean on v7.3.1 and v7.2.14) | none |
| 6.18.y | three context-analysis annotations removed because 6.18 lacks them; code unchanged. Hunks apply with offsets only (e.g. `l2cap_check_encryption()` at line 7697) | none (offsets only) |
| 6.12.y | the same three annotations removed; `l2cap_check_encryption()` hunk at line 7680 | `l2cap_sock_recvmsg()` in 6.12 has no `MSG_ERRQUEUE` block, so the three lines `if (unlikely(flags & MSG_ERRQUEUE)) return sock_recv_errqueue(...);` that upstream carries into the new `l2cap_sock_recvmsg()` are absent; `l2cap_sock_defer()` and its call are as upstream |
| 6.6.y | the same annotations removed; hunk at line 7627; `l2cap_chan_connect()` has no `timeout` argument in this tree, visible only in unchanged context | as 6.12: no `MSG_ERRQUEUE` lines |

The three annotations dropped are these lines of the upstream patch 1 **[source]** (commit `608e0b7a675b2`):

```diff
+void l2cap_chan_close_unlocked(struct l2cap_chan *chan, int reason)
+	__must_not_hold(&chan->lock);
...
+bool l2cap_chan_lock_conn(struct l2cap_chan *chan)
+	__acquires(&chan->lock) __cond_acquires(true, &chan->conn->lock);
...
+bool l2cap_chan_lock_conn(struct l2cap_chan *chan)
+	__context_unsafe(/* conditional locking */)
```

In the backports the first becomes a plain declaration, the second keeps only `__acquires(&chan->lock);`, and the third (in `l2cap_core.c`) is dropped. Reason: on 6.18 the unchanged pair does not build (`expected declaration specifiers before '__must_not_hold'` and `macro "__cond_acquires" passed 2 arguments, but takes just 1`) **[measured]**, because 6.18 and older lack the context-analysis annotations that 7.x has. Diffstats: upstream pair on v7.3: 121 insertions / 25 deletions; the 6.18 series 119 / 25; the 6.12 and 6.6 series 116 / 22.

The cherry-pick check on the older bases **[measured]**: on v6.12.114 and v6.6.160 patch 2 conflicts in `l2cap_sock.c` hunk 1 (the missing `MSG_ERRQUEUE` block); on v6.1.190, v5.15.223 and v5.10.272 it conflicts too, and patch 1 would not build there since `struct l2cap_conn` has `chan_lock` and no `lock` **[inferred]** (not built).

A smaller change was examined: the two helpers patch 2 needs plus the unchanged `l2cap_sock_defer()` come to 118 changed lines (148 with context). An ECRED-only sketch (about 82 changed lines, 102 with context) leaves the LE and BR/EDR defer branches without `conn->lock`, so its locking differs from upstream; on v7.3.1 plus `5874f8d03268` it passes the case and the whole suite 111 of 111. It is not proposed; the upstream form is requested whole.

### The patches, verbatim

Recipients of all mails (decided, not yet used): the stable list; Cc Pauli Virtanen (author of both commits), Marcel Holtmann and Luiz Augusto von Dentz (Bluetooth maintainers), and linux-bluetooth. Mails 3 to 5 are each one thread: the cover letter, then the two patches as replies to it. The `Link:` line of patch 1 in the original points at a syzkaller report page; the URL is replaced by a note.

#### Mail 1 of 5: request for 7.3.y and 7.2.y (option 2)

```text
Subject: Please backport 608e0b7a675b and 32d86e048d8e (Bluetooth: L2CAP) to 7.3.y and 7.2.y

Hello,

please apply these two mainline commits to 7.3.y and 7.2.y, in this
order:

  608e0b7a675b2affbbf38167cad0fa63d8e064f7
  ("Bluetooth: L2CAP: add l2cap_chan_close_unlocked() and locking
  helpers")

  32d86e048d8efedb7aa6cbbd3c36c3c435401c92
  ("Bluetooth: L2CAP: hold conn->lock for
  __l2cap_ecred_conn_rsp_defer")

The second fixes ab4eedb790ca ("Bluetooth: L2CAP: Fix corrupted list in
hci_chan_del"), which both lines have. It calls l2cap_chan_lock_conn()
and l2cap_chan_unlock_conn(), which only the first adds; the first is
longer than the 100 lines the stable rules allow, and I am asking for
it whole as it was merged. Both are in mainline since the 7.4 merge
window and carry no Cc: stable tag. They are patches 2 and 7 of the
series "Bluetooth: L2CAP: fix and annotate l2cap_conn::chan_l locking";
the other patches are not needed for the problem below and were not
tested here. One of them, dc1ddc65f06d ("Bluetooth: L2CAP: take lock
for l2cap_chan_del in l2cap_ecred_rsp_defer"), takes the locks of the
sibling channels; I am not asking for it, because the case below
passes without it (it also passes with it added on v7.3.1).

Without them, BlueZ's l2cap-tester case "L2CAP Ext-Flowctl Server -
Accept 2 Close 1" (a deferred ECRED accept of two channels, the first
accepted and closed before the second) never finishes on v7.3.1 and
v7.2.14: the test stops after "Accept deferred setup". With
CONFIG_DETECT_HUNG_TASK enabled on v7.3.1, the tester's task is
reported blocked holding its socket's lock from l2cap_sock_recvmsg()
while waiting for the same lock in l2cap_sock_teardown_cb() (taken
nested, so lockdep stays silent). 32d86e048d8e releases the socket
lock before __l2cap_ecred_conn_rsp_defer() is called.

Both commits cherry-pick cleanly onto v7.3.1 and v7.2.14. Tested in
QEMU/KVM (4 vCPUs) with BlueZ's doc/tester.config: with the two
commits the case passes on both, and on v7.2.14 the whole l2cap-tester
passes 111 of 111; without them the case never finishes. No lockdep or
KASAN report.

On v7.3.1 the whole l2cap-tester stalls earlier, in an SCI case that
has nothing to do with these commits; I am asking for its fix in a
separate mail.

6.18.y, 6.12.y and 6.6.y hang on the same case and need small
adjustments; backports for them follow as separate series.

6.1.y, 5.15.y and 5.10.y do not have ab4eedb790ca, and ECRED is off
there unless the bluetooth module parameter enable_ecred is set. With
it set, the case never finishes on v6.1.190, v5.15.223 and v5.10.272
either, and on v6.1.190 the hung-task detector shows the same two
socket locks. The two commits do not apply to those lines, so this
request does not cover them.

Thanks,
Iaroslav
```

#### Mail 2 of 5: request for 7.3.y only (option 2)

Recipients: the stable list; Cc Luiz Augusto von Dentz, Marcel Holtmann, linux-bluetooth.

```text
Subject: Please backport 5874f8d03268 (Bluetooth: Fix the LE Read Connection Interval response layout) to 7.3.y

Hello,

please apply this mainline commit to 7.3.y:

  5874f8d03268d34189c6c12c56586b64d26a8bcc
  ("Bluetooth: Fix the LE Read Connection Interval response layout")

It fixes 2f8784cfe8a9 ("Bluetooth: Add support for Shorter Connection
Interval (SCI) feature"), which v7.3.1 has and v7.2.14 does not, so
7.3.y is the only stable line concerned. The commit is in mainline
since the 7.4 merge window, carries a Fixes: tag, and is not in
queue-7.3 of the stable-queue tree (checked 2026-11-01 09:45 UTC).

Without it, on v7.3.1 BlueZ's l2cap-tester stalls in the case "L2CAP LE
Client - SCI Fast Mode", which times out with "Invalid response length
for 0x20a3" in the kernel log, and the run does not get past it. The
commit cherry-picks cleanly onto v7.3.1. Tested in QEMU/KVM (4 vCPUs)
with BlueZ's doc/tester.config: with it applied, the eight SCI cases
pass, and with it and the two L2CAP commits from my other mail applied,
the whole l2cap-tester passes 111 of 111 on v7.3.1.

Thanks,
Iaroslav
```

#### Mails 3 to 5: the three backport series

##### 6.18.y, cover letter

```text
Date: Sun, 1 Nov 2026 10:42:49 +0100
Subject: [PATCH 6.18.y 0/2] Bluetooth: L2CAP: fix the deferred ECRED accept hang

Hello,

this is a backport to 6.18.y of two mainline commits by Pauli Virtanen,
in this order:

  608e0b7a675b ("Bluetooth: L2CAP: add l2cap_chan_close_unlocked() and
  locking helpers")
  32d86e048d8e ("Bluetooth: L2CAP: hold conn->lock for
  __l2cap_ecred_conn_rsp_defer")

The second fixes ab4eedb790ca ("Bluetooth: L2CAP: Fix corrupted list in
hci_chan_del"), which 6.18.y has. It calls l2cap_chan_lock_conn() and
l2cap_chan_unlock_conn(), which only the first adds; the first is
longer than the 100 lines the stable rules allow, and is sent whole as
it was merged. Neither carries Cc: stable. They are patches 2 and 7 of
the series "Bluetooth: L2CAP: fix and annotate l2cap_conn::chan_l
locking"; the other patches are not needed for the problem below and
were not tested here. One of them, dc1ddc65f06d ("Bluetooth: L2CAP:
take lock for l2cap_chan_del in l2cap_ecred_rsp_defer"), takes the
locks of the sibling channels; it is not requested, because the case
below passes without it.

Without them, BlueZ's l2cap-tester case "L2CAP Ext-Flowctl Server -
Accept 2 Close 1" never finishes on v6.18.60: the test stops after
"Accept deferred setup". With CONFIG_DETECT_HUNG_TASK enabled, the
tester's task is reported blocked holding its socket's lock from
l2cap_sock_recvmsg() and waiting for the same lock in
l2cap_sock_teardown_cb(); patch 2 releases the socket lock before
__l2cap_ecred_conn_rsp_defer().

The commits do not build on 6.18.y as they are. Deviations:
- patch 1: the context-analysis annotations 6.18.y lacks are dropped
  (__must_not_hold, the __cond_acquires on l2cap_chan_lock_conn(),
  __context_unsafe); the code is unchanged;
- patch 2: none.

Tested on v6.18.60 in QEMU/KVM (4 vCPUs) with BlueZ's
doc/tester.config: with the series the case passes, and the whole
l2cap-tester ends with 93 of 111 passed; each of the 18 failing cases
(the BT_PHY cases: setsockopt(BT_PHY) fails with ENOPROTOOPT there)
also fails on plain v6.18.60. Without the series the case never
finishes. No lockdep or KASAN report with the series.

The two commits are requested for 7.3.y and 7.2.y as they are, in a
separate mail; backports for 6.12.y and 6.6.y are separate series.

Thanks,
Iaroslav

Pauli Virtanen (2):
  Bluetooth: L2CAP: add l2cap_chan_close_unlocked() and locking helpers
  Bluetooth: L2CAP: hold conn->lock for __l2cap_ecred_conn_rsp_defer

 include/net/bluetooth/l2cap.h | 16 +++++++++
 net/bluetooth/l2cap_core.c    | 60 ++++++++++++++++++++++++++++++---
 net/bluetooth/l2cap_sock.c    | 68 ++++++++++++++++++++++++-----------
 3 files changed, 119 insertions(+), 25 deletions(-)


base-commit: f45ed76d6791cf72ff1265ee93511175bbbc2f18
-- 
2.43.0
```

##### 6.18.y, patch 1/2

```diff
Date: Sat, 29 Aug 2026 17:19:57 +0300
Subject: [PATCH 6.18.y 1/2] Bluetooth: L2CAP: add l2cap_chan_close_unlocked()
 and locking helpers

[ Upstream commit 608e0b7a675b2affbbf38167cad0fa63d8e064f7 ]

l2cap_chan_close() requires holding chan->lock and chan->conn->lock if
associated chan->conn exists, to guard eg. conn->chan_l. Taking the
locks with right ordering requires handling a race condition.

Add helper function l2cap_chan_(un)lock_conn that do the locking right.

Add l2cap_chan_close_unlocked() that does not require locks to be held,
as all callsites do this lock -> close -> unlock pattern.

Link: [syzkaller report link omitted in this document]
Signed-off-by: Pauli Virtanen
Signed-off-by: Luiz Augusto von Dentz
[ backport: dropped the context-analysis annotations 6.18 lacks
  (__must_not_hold, __cond_acquires, __context_unsafe); code
  unchanged ]
Signed-off-by: Iaroslav Voitovych
---
 include/net/bluetooth/l2cap.h | 16 ++++++++++
 net/bluetooth/l2cap_core.c    | 60 ++++++++++++++++++++++++++++++++---
 2 files changed, 71 insertions(+), 5 deletions(-)

diff --git a/include/net/bluetooth/l2cap.h b/include/net/bluetooth/l2cap.h
index 2f7c367d68ce4..18c6990cd5f9c 100644
--- a/include/net/bluetooth/l2cap.h
+++ b/include/net/bluetooth/l2cap.h
@@ -963,6 +963,7 @@ int l2cap_add_scid(struct l2cap_chan *chan,  __u16 scid);
 
 struct l2cap_chan *l2cap_chan_create(void);
 void l2cap_chan_close(struct l2cap_chan *chan, int reason);
+void l2cap_chan_close_unlocked(struct l2cap_chan *chan, int reason);
 int l2cap_chan_connect(struct l2cap_chan *chan, __le16 psm, u16 cid,
 		       bdaddr_t *dst, u8 dst_type, u16 timeout);
 int l2cap_chan_reconfigure(struct l2cap_chan *chan, __u16 mtu);
@@ -988,4 +989,19 @@ void l2cap_conn_put(struct l2cap_conn *conn);
 int l2cap_register_user(struct l2cap_conn *conn, struct l2cap_user *user);
 void l2cap_unregister_user(struct l2cap_conn *conn, struct l2cap_user *user);
 
+bool l2cap_chan_lock_conn(struct l2cap_chan *chan)
+	__acquires(&chan->lock);
+
+/* Release macro for l2cap_chan_lock_conn, so context analysis understands it */
+#define l2cap_chan_unlock_conn(chan, conn_locked)			\
+	({								\
+		struct l2cap_chan *__chan = (chan);			\
+		struct l2cap_conn *__conn = __chan->conn;		\
+		l2cap_chan_unlock(__chan);				\
+		if (conn_locked) {					\
+			mutex_unlock(&__conn->lock);			\
+			l2cap_conn_put(__conn);				\
+		}							\
+	})
+
 #endif /* __L2CAP_H */
diff --git a/net/bluetooth/l2cap_core.c b/net/bluetooth/l2cap_core.c
index 462667a6e6ac2..4a92c6a7a08a9 100644
--- a/net/bluetooth/l2cap_core.c
+++ b/net/bluetooth/l2cap_core.c
@@ -62,6 +62,7 @@ static void l2cap_tx(struct l2cap_chan *chan, struct l2cap_ctrl *control,
 static void l2cap_retrans_timeout(struct work_struct *work);
 static void l2cap_monitor_timeout(struct work_struct *work);
 static void l2cap_ack_timeout(struct work_struct *work);
+static void __l2cap_chan_close(struct l2cap_chan *chan, int reason);
 
 static inline u8 bdaddr_type(u8 link_type, u8 bdaddr_type)
 {
@@ -433,7 +434,7 @@ static void l2cap_chan_timeout(struct work_struct *work)
 	else
 		reason = ETIMEDOUT;
 
-	l2cap_chan_close(chan, reason);
+	__l2cap_chan_close(chan, reason);
 
 	chan->ops->close(chan);
 
@@ -842,7 +843,7 @@ static void l2cap_chan_connect_reject(struct l2cap_chan *chan)
 	l2cap_send_cmd(conn, chan->ident, L2CAP_CONN_RSP, sizeof(rsp), &rsp);
 }
 
-void l2cap_chan_close(struct l2cap_chan *chan, int reason)
+static void __l2cap_chan_close(struct l2cap_chan *chan, int reason)
 {
 	struct l2cap_conn *conn = chan->conn;
 
@@ -891,8 +892,57 @@ void l2cap_chan_close(struct l2cap_chan *chan, int reason)
 		break;
 	}
 }
+
+void l2cap_chan_close(struct l2cap_chan *chan, int reason)
+{
+	__l2cap_chan_close(chan, reason);
+}
 EXPORT_SYMBOL(l2cap_chan_close);
 
+/* Take chan->lock. If chan->conn is non-NULL, take new reference on it, take
+ * chan->conn->lock, and return true. Otherwise return false.
+ */
+bool l2cap_chan_lock_conn(struct l2cap_chan *chan)
+{
+	/* Handle conn->lock > chan->lock ordering + race on chan->conn */
+	for (;;) {
+		struct l2cap_conn *conn;
+
+		l2cap_chan_lock(chan);
+		conn = chan->conn;
+		if (conn)
+			l2cap_conn_get(conn);
+		l2cap_chan_unlock(chan);
+
+		if (conn)
+			mutex_lock(&conn->lock);
+
+		l2cap_chan_lock(chan);
+
+		if (chan->conn != conn) {
+			l2cap_chan_unlock(chan);
+			if (conn) {
+				mutex_unlock(&conn->lock);
+				l2cap_conn_put(conn);
+			}
+			schedule();
+			continue;
+		}
+
+		return chan->conn;
+	}
+}
+
+void l2cap_chan_close_unlocked(struct l2cap_chan *chan, int reason)
+{
+	bool have_conn;
+
+	have_conn = l2cap_chan_lock_conn(chan);
+	__l2cap_chan_close(chan, reason);
+	l2cap_chan_unlock_conn(chan, have_conn);
+}
+EXPORT_SYMBOL(l2cap_chan_close_unlocked);
+
 static inline u8 l2cap_get_auth_type(struct l2cap_chan *chan)
 {
 	switch (chan->chan_type) {
@@ -1583,7 +1633,7 @@ static void l2cap_conn_start(struct l2cap_conn *conn)
 			if (!l2cap_mode_supported(chan->mode, conn->feat_mask)
 			    && test_bit(CONF_STATE2_DEVICE,
 					&chan->conf_state)) {
-				l2cap_chan_close(chan, ECONNRESET);
+				__l2cap_chan_close(chan, ECONNRESET);
 				l2cap_chan_unlock(chan);
 				continue;
 			}
@@ -1591,7 +1641,7 @@ static void l2cap_conn_start(struct l2cap_conn *conn)
 			if (l2cap_check_enc_key_size(conn->hcon, chan))
 				l2cap_start_connection(chan);
 			else
-				l2cap_chan_close(chan, ECONNREFUSED);
+				__l2cap_chan_close(chan, ECONNREFUSED);
 
 		} else if (chan->state == BT_CONNECT2) {
 			struct l2cap_conn_rsp rsp;
@@ -7647,7 +7697,7 @@ static inline void l2cap_check_encryption(struct l2cap_chan *chan, u8 encrypt)
 			__set_chan_timer(chan, L2CAP_ENC_TIMEOUT);
 		} else if (chan->sec_level == BT_SECURITY_HIGH ||
 			   chan->sec_level == BT_SECURITY_FIPS)
-			l2cap_chan_close(chan, ECONNREFUSED);
+			__l2cap_chan_close(chan, ECONNREFUSED);
 	} else {
 		if (chan->sec_level == BT_SECURITY_MEDIUM)
 			__clear_chan_timer(chan);
-- 
2.43.0
```

##### 6.18.y, patch 2/2

```diff
Date: Sat, 29 Aug 2026 17:20:02 +0300
Subject: [PATCH 6.18.y 2/2] Bluetooth: L2CAP: hold conn->lock for
 __l2cap_ecred_conn_rsp_defer

[ Upstream commit 32d86e048d8efedb7aa6cbbd3c36c3c435401c92 ]

__l2cap_ecred_conn_rsp_defer() > __l2cap_chan_list_id() accesses
conn->chan_l which is guarded by conn->lock. The lock fails to be held
when calling from l2cap_sock.c.

Fix by using l2cap_chan_conn_lock(), and taking the locks in required
order l2cap_conn::lock > l2cap_chan::lock > sk.  Leave fast path with
sk->sk_state precheck.  Move the L2CAP defer handling to
l2cap_sock_defer().

The code should also take l2cap_chan_lock() for sibling channels, but
that needs separate fix due to lock nesting.

Fixes: ab4eedb790ca ("Bluetooth: L2CAP: Fix corrupted list in hci_chan_del")
Signed-off-by: Pauli Virtanen
Signed-off-by: Luiz Augusto von Dentz
Signed-off-by: Iaroslav Voitovych
---
 net/bluetooth/l2cap_sock.c | 68 +++++++++++++++++++++++++++-----------
 1 file changed, 48 insertions(+), 20 deletions(-)

diff --git a/net/bluetooth/l2cap_sock.c b/net/bluetooth/l2cap_sock.c
index e78866e02bfc2..9dfd4d088a67b 100644
--- a/net/bluetooth/l2cap_sock.c
+++ b/net/bluetooth/l2cap_sock.c
@@ -1220,40 +1220,68 @@ static void l2cap_publish_rx_avail(struct l2cap_chan *chan)
 		l2cap_chan_rx_avail(chan, -1);
 }
 
-static int l2cap_sock_recvmsg(struct socket *sock, struct msghdr *msg,
-			      size_t len, int flags)
+static int l2cap_sock_defer(struct sock *sk)
 {
-	struct sock *sk = sock->sk;
-	struct l2cap_pinfo *pi = l2cap_pi(sk);
-	int err;
+	struct l2cap_chan *chan = l2cap_pi(sk)->chan;
+	bool have_conn;
+	int err = 0;
 
-	if (unlikely(flags & MSG_ERRQUEUE))
-		return sock_recv_errqueue(sk, msg, len, SOL_BLUETOOTH,
-					  BT_SCM_ERROR);
+	/* Fast path check */
+	lock_sock(sk);
+	if (sk->sk_state != BT_CONNECT2) {
+		release_sock(sk);
+		return 0;
+	}
+	release_sock(sk);
 
+	have_conn = l2cap_chan_lock_conn(chan);
 	lock_sock(sk);
 
 	if (sk->sk_state == BT_CONNECT2 && test_bit(BT_SK_DEFER_SETUP,
 						    &bt_sk(sk)->flags)) {
-		if (pi->chan->mode == L2CAP_MODE_EXT_FLOWCTL) {
+		err = 1;
+
+		if (!have_conn) {
+			release_sock(sk);
+			err = -ENOTCONN;
+		} else if (chan->mode == L2CAP_MODE_EXT_FLOWCTL) {
 			sk->sk_state = BT_CONNECTED;
-			pi->chan->state = BT_CONNECTED;
-			__l2cap_ecred_conn_rsp_defer(pi->chan);
-		} else if (bdaddr_type_is_le(pi->chan->src_type)) {
+			chan->state = BT_CONNECTED;
+			release_sock(sk);
+			__l2cap_ecred_conn_rsp_defer(chan);
+		} else if (bdaddr_type_is_le(chan->src_type)) {
 			sk->sk_state = BT_CONNECTED;
-			pi->chan->state = BT_CONNECTED;
-			__l2cap_le_connect_rsp_defer(pi->chan);
+			chan->state = BT_CONNECTED;
+			release_sock(sk);
+			__l2cap_le_connect_rsp_defer(chan);
 		} else {
 			sk->sk_state = BT_CONFIG;
-			pi->chan->state = BT_CONFIG;
-			__l2cap_connect_rsp_defer(pi->chan);
+			chan->state = BT_CONFIG;
+			release_sock(sk);
+			__l2cap_connect_rsp_defer(chan);
 		}
-
-		err = 0;
-		goto done;
+	} else {
+		release_sock(sk);
 	}
 
-	release_sock(sk);
+	l2cap_chan_unlock_conn(chan, have_conn);
+	return err;
+}
+
+static int l2cap_sock_recvmsg(struct socket *sock, struct msghdr *msg,
+			      size_t len, int flags)
+{
+	struct sock *sk = sock->sk;
+	struct l2cap_pinfo *pi = l2cap_pi(sk);
+	int err;
+
+	if (unlikely(flags & MSG_ERRQUEUE))
+		return sock_recv_errqueue(sk, msg, len, SOL_BLUETOOTH,
+					  BT_SCM_ERROR);
+
+	err = l2cap_sock_defer(sk);
+	if (err)
+		return err < 0 ? err : 0;
 
 	if (sock->type == SOCK_STREAM)
 		err = bt_sock_stream_recvmsg(sock, msg, len, flags);
-- 
2.43.0
```

##### 6.12.y, cover letter

```text
Date: Sun, 1 Nov 2026 10:33:53 +0100
Subject: [PATCH 6.12.y 0/2] Bluetooth: L2CAP: fix the deferred ECRED accept hang

Hello,

this is a backport to 6.12.y of two mainline commits by Pauli Virtanen,
in this order:

  608e0b7a675b ("Bluetooth: L2CAP: add l2cap_chan_close_unlocked() and
  locking helpers")
  32d86e048d8e ("Bluetooth: L2CAP: hold conn->lock for
  __l2cap_ecred_conn_rsp_defer")

The second fixes ab4eedb790ca ("Bluetooth: L2CAP: Fix corrupted list in
hci_chan_del"), which 6.12.y has as f87271d21dd4. It calls
l2cap_chan_lock_conn() and l2cap_chan_unlock_conn(), which only the
first adds; the first is longer than the 100 lines the stable rules
allow, and is sent whole as it was merged. Neither carries Cc: stable.
They are patches 2 and 7 of the series "Bluetooth: L2CAP: fix and
annotate l2cap_conn::chan_l locking"; the other patches are not needed
for the problem below and were not tested here. One of them,
dc1ddc65f06d ("Bluetooth: L2CAP: take lock for l2cap_chan_del in
l2cap_ecred_rsp_defer"), takes the locks of the sibling channels; it is
not requested, because the case below passes without it.

Without them, BlueZ's l2cap-tester case "L2CAP Ext-Flowctl Server -
Accept 2 Close 1" never finishes on v6.12.115: the test stops after
"Accept deferred setup". With CONFIG_DETECT_HUNG_TASK enabled, the
tester's task is reported blocked holding its socket's lock from
l2cap_sock_recvmsg() and waiting for the same lock in
l2cap_sock_teardown_cb(); patch 2 releases the socket lock before
__l2cap_ecred_conn_rsp_defer().

On 6.12.y patch 1 does not build and patch 2 does not apply as they
are. Deviations:
- patch 1: the context-analysis annotations 6.12.y lacks are dropped
  (__must_not_hold, the __cond_acquires on l2cap_chan_lock_conn(),
  __context_unsafe); the code is unchanged;
- patch 2: l2cap_sock_recvmsg() in 6.12.y has no MSG_ERRQUEUE block,
  so the three MSG_ERRQUEUE lines that precede the new
  l2cap_sock_defer() call upstream are absent; l2cap_sock_defer() and
  its call are as upstream.

Tested on v6.12.115 in QEMU/KVM (4 vCPUs) with BlueZ's
doc/tester.config: with the series the case passes, and the whole
l2cap-tester ends with 79 of 111 passed; each of the 32 cases that
fail or time out also does so on plain v6.12.115 (26 PHY cases, 3 TX
timestamping, 2 ethtool and one BR/EDR PIN code case that times out).
Without the series the case never finishes. No lockdep or KASAN report
with the series.

The two commits are requested for 7.3.y and 7.2.y as they are, in a
separate mail; backports for 6.18.y and 6.6.y are separate series.

Thanks,
Iaroslav

Pauli Virtanen (2):
  Bluetooth: L2CAP: add l2cap_chan_close_unlocked() and locking helpers
  Bluetooth: L2CAP: hold conn->lock for __l2cap_ecred_conn_rsp_defer

 include/net/bluetooth/l2cap.h | 16 +++++++++
 net/bluetooth/l2cap_core.c    | 60 ++++++++++++++++++++++++++++++---
 net/bluetooth/l2cap_sock.c    | 62 +++++++++++++++++++++++++----------
 3 files changed, 116 insertions(+), 22 deletions(-)


base-commit: 03bae623ec326c2738198739625832aab0eb120a
-- 
2.43.0
```

##### 6.12.y, patch 1/2

```diff
Date: Sat, 29 Aug 2026 17:19:57 +0300
Subject: [PATCH 6.12.y 1/2] Bluetooth: L2CAP: add l2cap_chan_close_unlocked()
 and locking helpers

[ Upstream commit 608e0b7a675b2affbbf38167cad0fa63d8e064f7 ]

l2cap_chan_close() requires holding chan->lock and chan->conn->lock if
associated chan->conn exists, to guard eg. conn->chan_l. Taking the
locks with right ordering requires handling a race condition.

Add helper function l2cap_chan_(un)lock_conn that do the locking right.

Add l2cap_chan_close_unlocked() that does not require locks to be held,
as all callsites do this lock -> close -> unlock pattern.

Link: [syzkaller report link omitted in this document]
Signed-off-by: Pauli Virtanen
Signed-off-by: Luiz Augusto von Dentz
[ backport: dropped the context-analysis annotations 6.12 lacks
  (__must_not_hold, __cond_acquires, __context_unsafe); code
  unchanged ]
Signed-off-by: Iaroslav Voitovych
---
 include/net/bluetooth/l2cap.h | 16 ++++++++++
 net/bluetooth/l2cap_core.c    | 60 ++++++++++++++++++++++++++++++++---
 2 files changed, 71 insertions(+), 5 deletions(-)

diff --git a/include/net/bluetooth/l2cap.h b/include/net/bluetooth/l2cap.h
index f5f91373022f0..2b13f26444d69 100644
--- a/include/net/bluetooth/l2cap.h
+++ b/include/net/bluetooth/l2cap.h
@@ -963,6 +963,7 @@ int l2cap_add_scid(struct l2cap_chan *chan,  __u16 scid);
 
 struct l2cap_chan *l2cap_chan_create(void);
 void l2cap_chan_close(struct l2cap_chan *chan, int reason);
+void l2cap_chan_close_unlocked(struct l2cap_chan *chan, int reason);
 int l2cap_chan_connect(struct l2cap_chan *chan, __le16 psm, u16 cid,
 		       bdaddr_t *dst, u8 dst_type, u16 timeout);
 int l2cap_chan_reconfigure(struct l2cap_chan *chan, __u16 mtu);
@@ -987,4 +988,19 @@ void l2cap_conn_put(struct l2cap_conn *conn);
 int l2cap_register_user(struct l2cap_conn *conn, struct l2cap_user *user);
 void l2cap_unregister_user(struct l2cap_conn *conn, struct l2cap_user *user);
 
+bool l2cap_chan_lock_conn(struct l2cap_chan *chan)
+	__acquires(&chan->lock);
+
+/* Release macro for l2cap_chan_lock_conn, so context analysis understands it */
+#define l2cap_chan_unlock_conn(chan, conn_locked)			\
+	({								\
+		struct l2cap_chan *__chan = (chan);			\
+		struct l2cap_conn *__conn = __chan->conn;		\
+		l2cap_chan_unlock(__chan);				\
+		if (conn_locked) {					\
+			mutex_unlock(&__conn->lock);			\
+			l2cap_conn_put(__conn);				\
+		}							\
+	})
+
 #endif /* __L2CAP_H */
diff --git a/net/bluetooth/l2cap_core.c b/net/bluetooth/l2cap_core.c
index 894fcd779bd03..02fb2bdb65689 100644
--- a/net/bluetooth/l2cap_core.c
+++ b/net/bluetooth/l2cap_core.c
@@ -62,6 +62,7 @@ static void l2cap_tx(struct l2cap_chan *chan, struct l2cap_ctrl *control,
 static void l2cap_retrans_timeout(struct work_struct *work);
 static void l2cap_monitor_timeout(struct work_struct *work);
 static void l2cap_ack_timeout(struct work_struct *work);
+static void __l2cap_chan_close(struct l2cap_chan *chan, int reason);
 
 static inline u8 bdaddr_type(u8 link_type, u8 bdaddr_type)
 {
@@ -433,7 +434,7 @@ static void l2cap_chan_timeout(struct work_struct *work)
 	else
 		reason = ETIMEDOUT;
 
-	l2cap_chan_close(chan, reason);
+	__l2cap_chan_close(chan, reason);
 
 	chan->ops->close(chan);
 
@@ -842,7 +843,7 @@ static void l2cap_chan_connect_reject(struct l2cap_chan *chan)
 	l2cap_send_cmd(conn, chan->ident, L2CAP_CONN_RSP, sizeof(rsp), &rsp);
 }
 
-void l2cap_chan_close(struct l2cap_chan *chan, int reason)
+static void __l2cap_chan_close(struct l2cap_chan *chan, int reason)
 {
 	struct l2cap_conn *conn = chan->conn;
 
@@ -891,8 +892,57 @@ void l2cap_chan_close(struct l2cap_chan *chan, int reason)
 		break;
 	}
 }
+
+void l2cap_chan_close(struct l2cap_chan *chan, int reason)
+{
+	__l2cap_chan_close(chan, reason);
+}
 EXPORT_SYMBOL(l2cap_chan_close);
 
+/* Take chan->lock. If chan->conn is non-NULL, take new reference on it, take
+ * chan->conn->lock, and return true. Otherwise return false.
+ */
+bool l2cap_chan_lock_conn(struct l2cap_chan *chan)
+{
+	/* Handle conn->lock > chan->lock ordering + race on chan->conn */
+	for (;;) {
+		struct l2cap_conn *conn;
+
+		l2cap_chan_lock(chan);
+		conn = chan->conn;
+		if (conn)
+			l2cap_conn_get(conn);
+		l2cap_chan_unlock(chan);
+
+		if (conn)
+			mutex_lock(&conn->lock);
+
+		l2cap_chan_lock(chan);
+
+		if (chan->conn != conn) {
+			l2cap_chan_unlock(chan);
+			if (conn) {
+				mutex_unlock(&conn->lock);
+				l2cap_conn_put(conn);
+			}
+			schedule();
+			continue;
+		}
+
+		return chan->conn;
+	}
+}
+
+void l2cap_chan_close_unlocked(struct l2cap_chan *chan, int reason)
+{
+	bool have_conn;
+
+	have_conn = l2cap_chan_lock_conn(chan);
+	__l2cap_chan_close(chan, reason);
+	l2cap_chan_unlock_conn(chan, have_conn);
+}
+EXPORT_SYMBOL(l2cap_chan_close_unlocked);
+
 static inline u8 l2cap_get_auth_type(struct l2cap_chan *chan)
 {
 	switch (chan->chan_type) {
@@ -1583,7 +1633,7 @@ static void l2cap_conn_start(struct l2cap_conn *conn)
 			if (!l2cap_mode_supported(chan->mode, conn->feat_mask)
 			    && test_bit(CONF_STATE2_DEVICE,
 					&chan->conf_state)) {
-				l2cap_chan_close(chan, ECONNRESET);
+				__l2cap_chan_close(chan, ECONNRESET);
 				l2cap_chan_unlock(chan);
 				continue;
 			}
@@ -1591,7 +1641,7 @@ static void l2cap_conn_start(struct l2cap_conn *conn)
 			if (l2cap_check_enc_key_size(conn->hcon, chan))
 				l2cap_start_connection(chan);
 			else
-				l2cap_chan_close(chan, ECONNREFUSED);
+				__l2cap_chan_close(chan, ECONNREFUSED);
 
 		} else if (chan->state == BT_CONNECT2) {
 			struct l2cap_conn_rsp rsp;
@@ -7630,7 +7680,7 @@ static inline void l2cap_check_encryption(struct l2cap_chan *chan, u8 encrypt)
 			__set_chan_timer(chan, L2CAP_ENC_TIMEOUT);
 		} else if (chan->sec_level == BT_SECURITY_HIGH ||
 			   chan->sec_level == BT_SECURITY_FIPS)
-			l2cap_chan_close(chan, ECONNREFUSED);
+			__l2cap_chan_close(chan, ECONNREFUSED);
 	} else {
 		if (chan->sec_level == BT_SECURITY_MEDIUM)
 			__clear_chan_timer(chan);
-- 
2.43.0
```

##### 6.12.y, patch 2/2

```diff
Date: Sat, 29 Aug 2026 17:20:02 +0300
Subject: [PATCH 6.12.y 2/2] Bluetooth: L2CAP: hold conn->lock for
 __l2cap_ecred_conn_rsp_defer

[ Upstream commit 32d86e048d8efedb7aa6cbbd3c36c3c435401c92 ]

__l2cap_ecred_conn_rsp_defer() > __l2cap_chan_list_id() accesses
conn->chan_l which is guarded by conn->lock. The lock fails to be held
when calling from l2cap_sock.c.

Fix by using l2cap_chan_conn_lock(), and taking the locks in required
order l2cap_conn::lock > l2cap_chan::lock > sk.  Leave fast path with
sk->sk_state precheck.  Move the L2CAP defer handling to
l2cap_sock_defer().

The code should also take l2cap_chan_lock() for sibling channels, but
that needs separate fix due to lock nesting.

Fixes: ab4eedb790ca ("Bluetooth: L2CAP: Fix corrupted list in hci_chan_del")
Signed-off-by: Pauli Virtanen
Signed-off-by: Luiz Augusto von Dentz
[ backport: 6.12 has no MSG_ERRQUEUE handling in
  l2cap_sock_recvmsg(), so the hunk is adapted to its context and
  the new l2cap_sock_defer() call replaces the old inline defer
  block; no other change ]
Signed-off-by: Iaroslav Voitovych
---
 net/bluetooth/l2cap_sock.c | 62 +++++++++++++++++++++++++++-----------
 1 file changed, 45 insertions(+), 17 deletions(-)

diff --git a/net/bluetooth/l2cap_sock.c b/net/bluetooth/l2cap_sock.c
index f08512a57ab58..9b4f0a3319aa1 100644
--- a/net/bluetooth/l2cap_sock.c
+++ b/net/bluetooth/l2cap_sock.c
@@ -1224,36 +1224,64 @@ static void l2cap_publish_rx_avail(struct l2cap_chan *chan)
 		l2cap_chan_rx_avail(chan, -1);
 }
 
-static int l2cap_sock_recvmsg(struct socket *sock, struct msghdr *msg,
-			      size_t len, int flags)
+static int l2cap_sock_defer(struct sock *sk)
 {
-	struct sock *sk = sock->sk;
-	struct l2cap_pinfo *pi = l2cap_pi(sk);
-	int err;
+	struct l2cap_chan *chan = l2cap_pi(sk)->chan;
+	bool have_conn;
+	int err = 0;
 
+	/* Fast path check */
+	lock_sock(sk);
+	if (sk->sk_state != BT_CONNECT2) {
+		release_sock(sk);
+		return 0;
+	}
+	release_sock(sk);
+
+	have_conn = l2cap_chan_lock_conn(chan);
 	lock_sock(sk);
 
 	if (sk->sk_state == BT_CONNECT2 && test_bit(BT_SK_DEFER_SETUP,
 						    &bt_sk(sk)->flags)) {
-		if (pi->chan->mode == L2CAP_MODE_EXT_FLOWCTL) {
+		err = 1;
+
+		if (!have_conn) {
+			release_sock(sk);
+			err = -ENOTCONN;
+		} else if (chan->mode == L2CAP_MODE_EXT_FLOWCTL) {
 			sk->sk_state = BT_CONNECTED;
-			pi->chan->state = BT_CONNECTED;
-			__l2cap_ecred_conn_rsp_defer(pi->chan);
-		} else if (bdaddr_type_is_le(pi->chan->src_type)) {
+			chan->state = BT_CONNECTED;
+			release_sock(sk);
+			__l2cap_ecred_conn_rsp_defer(chan);
+		} else if (bdaddr_type_is_le(chan->src_type)) {
 			sk->sk_state = BT_CONNECTED;
-			pi->chan->state = BT_CONNECTED;
-			__l2cap_le_connect_rsp_defer(pi->chan);
+			chan->state = BT_CONNECTED;
+			release_sock(sk);
+			__l2cap_le_connect_rsp_defer(chan);
 		} else {
 			sk->sk_state = BT_CONFIG;
-			pi->chan->state = BT_CONFIG;
-			__l2cap_connect_rsp_defer(pi->chan);
+			chan->state = BT_CONFIG;
+			release_sock(sk);
+			__l2cap_connect_rsp_defer(chan);
 		}
-
-		err = 0;
-		goto done;
+	} else {
+		release_sock(sk);
 	}
 
-	release_sock(sk);
+	l2cap_chan_unlock_conn(chan, have_conn);
+	return err;
+}
+
+static int l2cap_sock_recvmsg(struct socket *sock, struct msghdr *msg,
+			      size_t len, int flags)
+{
+	struct sock *sk = sock->sk;
+	struct l2cap_pinfo *pi = l2cap_pi(sk);
+	int err;
+
+	err = l2cap_sock_defer(sk);
+	if (err)
+		return err < 0 ? err : 0;
 
 	if (sock->type == SOCK_STREAM)
 		err = bt_sock_stream_recvmsg(sock, msg, len, flags);
-- 
2.43.0
```

##### 6.6.y, cover letter

```text
Date: Sun, 1 Nov 2026 10:33:42 +0100
Subject: [PATCH 6.6.y 0/2] Bluetooth: L2CAP: fix the deferred ECRED accept hang

Hello,

this is a backport to 6.6.y of two mainline commits by Pauli Virtanen,
in this order:

  608e0b7a675b ("Bluetooth: L2CAP: add l2cap_chan_close_unlocked() and
  locking helpers")
  32d86e048d8e ("Bluetooth: L2CAP: hold conn->lock for
  __l2cap_ecred_conn_rsp_defer")

The second fixes ab4eedb790ca ("Bluetooth: L2CAP: Fix corrupted list in
hci_chan_del"), which 6.6.y has as efc30877bd4b. It calls
l2cap_chan_lock_conn() and l2cap_chan_unlock_conn(), which only the
first adds; the first is longer than the 100 lines the stable rules
allow, and is sent whole as it was merged. Neither carries Cc: stable.
They are patches 2 and 7 of the series "Bluetooth: L2CAP: fix and
annotate l2cap_conn::chan_l locking"; the other patches are not needed
for the problem below and were not tested here. One of them,
dc1ddc65f06d ("Bluetooth: L2CAP: take lock for l2cap_chan_del in
l2cap_ecred_rsp_defer"), takes the locks of the sibling channels; it is
not requested, because the case below passes without it.

Without them, BlueZ's l2cap-tester case "L2CAP Ext-Flowctl Server -
Accept 2 Close 1" never finishes on v6.6.161: the test stops after
"Accept deferred setup". With CONFIG_DETECT_HUNG_TASK enabled, the
tester's task is reported blocked holding its socket's lock from
l2cap_sock_recvmsg() and waiting for the same lock in
l2cap_sock_teardown_cb(); patch 2 releases the socket lock before
__l2cap_ecred_conn_rsp_defer().

On 6.6.y patch 1 does not build and patch 2 does not apply as they
are. Deviations:
- patch 1: the context-analysis annotations 6.6.y lacks are dropped
  (__must_not_hold, the __cond_acquires on l2cap_chan_lock_conn(),
  __context_unsafe); the code is unchanged;
- patch 2: l2cap_sock_recvmsg() in 6.6.y has no MSG_ERRQUEUE block,
  so the three MSG_ERRQUEUE lines that precede the new
  l2cap_sock_defer() call upstream are absent; l2cap_sock_defer() and
  its call are as upstream.

Tested on v6.6.161 in QEMU/KVM (4 vCPUs) with BlueZ's
doc/tester.config: with the series the case passes, and the whole
l2cap-tester ends with 79 of 111 passed; each of the 32 cases that
fail or time out also does so on plain v6.6.161 (26 PHY cases, 3 TX
timestamping, 2 ethtool and one BR/EDR PIN code case that times out).
Without the series the case never finishes. No lockdep or KASAN report
with the series.

The two commits are requested for 7.3.y and 7.2.y as they are, in a
separate mail; backports for 6.18.y and 6.12.y are separate series.

Thanks,
Iaroslav

Pauli Virtanen (2):
  Bluetooth: L2CAP: add l2cap_chan_close_unlocked() and locking helpers
  Bluetooth: L2CAP: hold conn->lock for __l2cap_ecred_conn_rsp_defer

 include/net/bluetooth/l2cap.h | 16 +++++++++
 net/bluetooth/l2cap_core.c    | 60 ++++++++++++++++++++++++++++++---
 net/bluetooth/l2cap_sock.c    | 62 +++++++++++++++++++++++++----------
 3 files changed, 116 insertions(+), 22 deletions(-)


base-commit: b5a1dc3ad4822c6edfb53429e9a3759c9b0ac2be
-- 
2.43.0
```

##### 6.6.y, patch 1/2

```diff
Date: Sat, 29 Aug 2026 17:19:57 +0300
Subject: [PATCH 6.6.y 1/2] Bluetooth: L2CAP: add l2cap_chan_close_unlocked()
 and locking helpers

[ Upstream commit 608e0b7a675b2affbbf38167cad0fa63d8e064f7 ]

l2cap_chan_close() requires holding chan->lock and chan->conn->lock if
associated chan->conn exists, to guard eg. conn->chan_l. Taking the
locks with right ordering requires handling a race condition.

Add helper function l2cap_chan_(un)lock_conn that do the locking right.

Add l2cap_chan_close_unlocked() that does not require locks to be held,
as all callsites do this lock -> close -> unlock pattern.

Link: [syzkaller report link omitted in this document]
Signed-off-by: Pauli Virtanen
Signed-off-by: Luiz Augusto von Dentz
[ backport: dropped the context-analysis annotations 6.6 lacks
  (__must_not_hold, __cond_acquires, __context_unsafe); code
  unchanged ]
Signed-off-by: Iaroslav Voitovych
---
 include/net/bluetooth/l2cap.h | 16 ++++++++++
 net/bluetooth/l2cap_core.c    | 60 ++++++++++++++++++++++++++++++++---
 2 files changed, 71 insertions(+), 5 deletions(-)

diff --git a/include/net/bluetooth/l2cap.h b/include/net/bluetooth/l2cap.h
index 767df6d832c81..775aad5bd990a 100644
--- a/include/net/bluetooth/l2cap.h
+++ b/include/net/bluetooth/l2cap.h
@@ -957,6 +957,7 @@ int l2cap_add_scid(struct l2cap_chan *chan,  __u16 scid);
 
 struct l2cap_chan *l2cap_chan_create(void);
 void l2cap_chan_close(struct l2cap_chan *chan, int reason);
+void l2cap_chan_close_unlocked(struct l2cap_chan *chan, int reason);
 int l2cap_chan_connect(struct l2cap_chan *chan, __le16 psm, u16 cid,
 		       bdaddr_t *dst, u8 dst_type);
 int l2cap_chan_reconfigure(struct l2cap_chan *chan, __u16 mtu);
@@ -985,4 +986,19 @@ void l2cap_conn_put(struct l2cap_conn *conn);
 int l2cap_register_user(struct l2cap_conn *conn, struct l2cap_user *user);
 void l2cap_unregister_user(struct l2cap_conn *conn, struct l2cap_user *user);
 
+bool l2cap_chan_lock_conn(struct l2cap_chan *chan)
+	__acquires(&chan->lock);
+
+/* Release macro for l2cap_chan_lock_conn, so context analysis understands it */
+#define l2cap_chan_unlock_conn(chan, conn_locked)			\
+	({								\
+		struct l2cap_chan *__chan = (chan);			\
+		struct l2cap_conn *__conn = __chan->conn;		\
+		l2cap_chan_unlock(__chan);				\
+		if (conn_locked) {					\
+			mutex_unlock(&__conn->lock);			\
+			l2cap_conn_put(__conn);				\
+		}							\
+	})
+
 #endif /* __L2CAP_H */
diff --git a/net/bluetooth/l2cap_core.c b/net/bluetooth/l2cap_core.c
index 94fddc456ac57..8ceb27abc125c 100644
--- a/net/bluetooth/l2cap_core.c
+++ b/net/bluetooth/l2cap_core.c
@@ -62,6 +62,7 @@ static void l2cap_tx(struct l2cap_chan *chan, struct l2cap_ctrl *control,
 static void l2cap_retrans_timeout(struct work_struct *work);
 static void l2cap_monitor_timeout(struct work_struct *work);
 static void l2cap_ack_timeout(struct work_struct *work);
+static void __l2cap_chan_close(struct l2cap_chan *chan, int reason);
 
 static inline u8 bdaddr_type(u8 link_type, u8 bdaddr_type)
 {
@@ -433,7 +434,7 @@ static void l2cap_chan_timeout(struct work_struct *work)
 	else
 		reason = ETIMEDOUT;
 
-	l2cap_chan_close(chan, reason);
+	__l2cap_chan_close(chan, reason);
 
 	chan->ops->close(chan);
 
@@ -842,7 +843,7 @@ static void l2cap_chan_connect_reject(struct l2cap_chan *chan)
 	l2cap_send_cmd(conn, chan->ident, L2CAP_CONN_RSP, sizeof(rsp), &rsp);
 }
 
-void l2cap_chan_close(struct l2cap_chan *chan, int reason)
+static void __l2cap_chan_close(struct l2cap_chan *chan, int reason)
 {
 	struct l2cap_conn *conn = chan->conn;
 
@@ -891,8 +892,57 @@ void l2cap_chan_close(struct l2cap_chan *chan, int reason)
 		break;
 	}
 }
+
+void l2cap_chan_close(struct l2cap_chan *chan, int reason)
+{
+	__l2cap_chan_close(chan, reason);
+}
 EXPORT_SYMBOL(l2cap_chan_close);
 
+/* Take chan->lock. If chan->conn is non-NULL, take new reference on it, take
+ * chan->conn->lock, and return true. Otherwise return false.
+ */
+bool l2cap_chan_lock_conn(struct l2cap_chan *chan)
+{
+	/* Handle conn->lock > chan->lock ordering + race on chan->conn */
+	for (;;) {
+		struct l2cap_conn *conn;
+
+		l2cap_chan_lock(chan);
+		conn = chan->conn;
+		if (conn)
+			l2cap_conn_get(conn);
+		l2cap_chan_unlock(chan);
+
+		if (conn)
+			mutex_lock(&conn->lock);
+
+		l2cap_chan_lock(chan);
+
+		if (chan->conn != conn) {
+			l2cap_chan_unlock(chan);
+			if (conn) {
+				mutex_unlock(&conn->lock);
+				l2cap_conn_put(conn);
+			}
+			schedule();
+			continue;
+		}
+
+		return chan->conn;
+	}
+}
+
+void l2cap_chan_close_unlocked(struct l2cap_chan *chan, int reason)
+{
+	bool have_conn;
+
+	have_conn = l2cap_chan_lock_conn(chan);
+	__l2cap_chan_close(chan, reason);
+	l2cap_chan_unlock_conn(chan, have_conn);
+}
+EXPORT_SYMBOL(l2cap_chan_close_unlocked);
+
 static inline u8 l2cap_get_auth_type(struct l2cap_chan *chan)
 {
 	switch (chan->chan_type) {
@@ -1568,7 +1618,7 @@ static void l2cap_conn_start(struct l2cap_conn *conn)
 			if (!l2cap_mode_supported(chan->mode, conn->feat_mask)
 			    && test_bit(CONF_STATE2_DEVICE,
 					&chan->conf_state)) {
-				l2cap_chan_close(chan, ECONNRESET);
+				__l2cap_chan_close(chan, ECONNRESET);
 				l2cap_chan_unlock(chan);
 				continue;
 			}
@@ -1576,7 +1626,7 @@ static void l2cap_conn_start(struct l2cap_conn *conn)
 			if (l2cap_check_enc_key_size(conn->hcon, chan))
 				l2cap_start_connection(chan);
 			else
-				l2cap_chan_close(chan, ECONNREFUSED);
+				__l2cap_chan_close(chan, ECONNREFUSED);
 
 		} else if (chan->state == BT_CONNECT2) {
 			struct l2cap_conn_rsp rsp;
@@ -7577,7 +7627,7 @@ static inline void l2cap_check_encryption(struct l2cap_chan *chan, u8 encrypt)
 			__set_chan_timer(chan, L2CAP_ENC_TIMEOUT);
 		} else if (chan->sec_level == BT_SECURITY_HIGH ||
 			   chan->sec_level == BT_SECURITY_FIPS)
-			l2cap_chan_close(chan, ECONNREFUSED);
+			__l2cap_chan_close(chan, ECONNREFUSED);
 	} else {
 		if (chan->sec_level == BT_SECURITY_MEDIUM)
 			__clear_chan_timer(chan);
-- 
2.43.0
```

##### 6.6.y, patch 2/2

```diff
Date: Sat, 29 Aug 2026 17:20:02 +0300
Subject: [PATCH 6.6.y 2/2] Bluetooth: L2CAP: hold conn->lock for
 __l2cap_ecred_conn_rsp_defer

[ Upstream commit 32d86e048d8efedb7aa6cbbd3c36c3c435401c92 ]

__l2cap_ecred_conn_rsp_defer() > __l2cap_chan_list_id() accesses
conn->chan_l which is guarded by conn->lock. The lock fails to be held
when calling from l2cap_sock.c.

Fix by using l2cap_chan_conn_lock(), and taking the locks in required
order l2cap_conn::lock > l2cap_chan::lock > sk.  Leave fast path with
sk->sk_state precheck.  Move the L2CAP defer handling to
l2cap_sock_defer().

The code should also take l2cap_chan_lock() for sibling channels, but
that needs separate fix due to lock nesting.

Fixes: ab4eedb790ca ("Bluetooth: L2CAP: Fix corrupted list in hci_chan_del")
Signed-off-by: Pauli Virtanen
Signed-off-by: Luiz Augusto von Dentz
[ backport: 6.6 has no MSG_ERRQUEUE handling in
  l2cap_sock_recvmsg(), so the hunk is adapted to its context and
  the new l2cap_sock_defer() call replaces the old inline defer
  block; no other change ]
Signed-off-by: Iaroslav Voitovych
---
 net/bluetooth/l2cap_sock.c | 62 +++++++++++++++++++++++++++-----------
 1 file changed, 45 insertions(+), 17 deletions(-)

diff --git a/net/bluetooth/l2cap_sock.c b/net/bluetooth/l2cap_sock.c
index 7d2e59e97c2c1..a7531477a4521 100644
--- a/net/bluetooth/l2cap_sock.c
+++ b/net/bluetooth/l2cap_sock.c
@@ -1208,36 +1208,64 @@ static void l2cap_publish_rx_avail(struct l2cap_chan *chan)
 		l2cap_chan_rx_avail(chan, -1);
 }
 
-static int l2cap_sock_recvmsg(struct socket *sock, struct msghdr *msg,
-			      size_t len, int flags)
+static int l2cap_sock_defer(struct sock *sk)
 {
-	struct sock *sk = sock->sk;
-	struct l2cap_pinfo *pi = l2cap_pi(sk);
-	int err;
+	struct l2cap_chan *chan = l2cap_pi(sk)->chan;
+	bool have_conn;
+	int err = 0;
 
+	/* Fast path check */
+	lock_sock(sk);
+	if (sk->sk_state != BT_CONNECT2) {
+		release_sock(sk);
+		return 0;
+	}
+	release_sock(sk);
+
+	have_conn = l2cap_chan_lock_conn(chan);
 	lock_sock(sk);
 
 	if (sk->sk_state == BT_CONNECT2 && test_bit(BT_SK_DEFER_SETUP,
 						    &bt_sk(sk)->flags)) {
-		if (pi->chan->mode == L2CAP_MODE_EXT_FLOWCTL) {
+		err = 1;
+
+		if (!have_conn) {
+			release_sock(sk);
+			err = -ENOTCONN;
+		} else if (chan->mode == L2CAP_MODE_EXT_FLOWCTL) {
 			sk->sk_state = BT_CONNECTED;
-			pi->chan->state = BT_CONNECTED;
-			__l2cap_ecred_conn_rsp_defer(pi->chan);
-		} else if (bdaddr_type_is_le(pi->chan->src_type)) {
+			chan->state = BT_CONNECTED;
+			release_sock(sk);
+			__l2cap_ecred_conn_rsp_defer(chan);
+		} else if (bdaddr_type_is_le(chan->src_type)) {
 			sk->sk_state = BT_CONNECTED;
-			pi->chan->state = BT_CONNECTED;
-			__l2cap_le_connect_rsp_defer(pi->chan);
+			chan->state = BT_CONNECTED;
+			release_sock(sk);
+			__l2cap_le_connect_rsp_defer(chan);
 		} else {
 			sk->sk_state = BT_CONFIG;
-			pi->chan->state = BT_CONFIG;
-			__l2cap_connect_rsp_defer(pi->chan);
+			chan->state = BT_CONFIG;
+			release_sock(sk);
+			__l2cap_connect_rsp_defer(chan);
 		}
-
-		err = 0;
-		goto done;
+	} else {
+		release_sock(sk);
 	}
 
-	release_sock(sk);
+	l2cap_chan_unlock_conn(chan, have_conn);
+	return err;
+}
+
+static int l2cap_sock_recvmsg(struct socket *sock, struct msghdr *msg,
+			      size_t len, int flags)
+{
+	struct sock *sk = sock->sk;
+	struct l2cap_pinfo *pi = l2cap_pi(sk);
+	int err;
+
+	err = l2cap_sock_defer(sk);
+	if (err)
+		return err < 0 ? err : 0;
 
 	if (sock->type == SOCK_STREAM)
 		err = bt_sock_stream_recvmsg(sock, msg, len, flags);
-- 
2.43.0
```

### Tests and results

All runs: QEMU/KVM, 4 vCPUs, BlueZ's `doc/tester.config` kernels (KASAN and lockdep on). Case = "L2CAP Ext-Flowctl Server - Accept 2 Close 1" run alone by its exact name, 180 s limit. The test runner passes its arguments through `sh -c`, so a multi-word `-s` name reaches the tester as its first word; the case is therefore run through a wrapper that supplies the exact name, and the guest log shows `Total: 1` **[measured]**.

**Round of 2026-11-01 (new stable tags; `CONFIG_DETECT_HUNG_TASK=y`, 20 s)** **[measured]**:

| tag | plain | with series (7.x: the pair) | full l2cap-tester with the series |
|---|---|---|---|
| v7.3.1 | hang | pass 1.119 s | the pair alone stalls in "L2CAP LE Client - SCI Fast Mode" as its base does; the pair plus `5874f8d03268`: 111 of 111 |
| v7.2.14 | hang | pass 1.068 s | 111 of 111 |
| v6.18.60 | hang | pass 1.126 s | 93 of 111; the 18 failures are the BT_PHY cases (`setsockopt(BT_PHY)` fails with ENOPROTOOPT) |
| v6.12.115 | hang | pass 1.078 s | 79 of 111; 32 non-pass: 26 PHY, 3 TX timestamping, 2 ethtool, 1 PIN-code timeout |
| v6.6.161 | hang | pass 1.402 s | 79 of 111; the same 32-case breakdown |

How "no regression" was judged: a full plain run stops at the hang, so the plain verdicts were pooled from one-word filter reruns (102 cases per tag). In every tag no case that passes on the plain base fails with the series (compared by case name, not by failure text). All non-passes are features the trees lack or a known unrelated limit; the 6.12 total rose from 33 to 79 between 6.12.114 and 6.12.115 because the `getsockopt` dispatch fix `4b26b1d3a94cc` was released in 6.12.115. Also on v7.3.1: plain base plus `5874f8d03268` still hangs in the case; the pair plus `dc1ddc65f06d` passes it, so `dc1ddc65f06d` is not needed (v7.3.1 only).

**Round of 2026-10-28 (older tags)** **[measured]**: 7.2.13 plus the pair: the case passes in 0.009 s and the whole l2cap-tester passes 111 of 111, kernel log clean. v7.3: the case alone hangs on plain v7.3 and passes with the pair (1.018 s); the whole suite on v7.3 stalls in "L2CAP LE Client - SCI Fast Mode" (kernel log `Invalid response length for 0x20a3`, opcode LE Read Connection Interval), with or without the pair, with identical verdicts for the 41 cases before it. With `5874f8d03268` applied to both sides: the plain tree passes the 95 cases it reaches and then hangs in the target case; the pair tree passes 110 of 110 (filtered on "L2CAP") and, unfiltered, 111 of 111. v6.18.59, v6.12.114, v6.6.160: the case hangs plain and passes with the backport; full-suite totals 93, 33 (before the 6.12 `getsockopt` fix) and 79 of 111, every failing case also failing on the plain base, matched by name (18 of 18, 78 of 78, 32 of 32 against the tester's own totals).

**Older lines** **[measured]** (plain tags, 2026-10-28): v6.1.190, v5.15.223 and v5.10.272 lack `ab4eedb790ca`; ECRED is off by default before v6.2 (`bool enable_ecred;` as a module parameter, `net/bluetooth/l2cap_core.c` line 46 on 6.1, line 48 on 5.15 and 5.10). As the test runner leaves them, the case fails at once ("Can't set mode: Protocol not available"). With `echo 1 > /sys/module/bluetooth/parameters/enable_ecred` in the guest the case never finishes on all three, while the other Ext-Flowctl cases behave identically on the three (10 passed, 6 failed each; the failures are PHY and Defer-limit cases, not the target). On v6.1.190 with the hung-task detector the same two socket-lock lines appear (7 reports). The commits do not apply there. No hung-task diagnostic was run on 5.15 and 5.10; their deadlock is **[inferred]** from the same code and the case hanging.

**Checks of the mails** **[measured]** on the 2026-10-28 versions of the series: `checkpatch.pl` (v7.3) gives one error per patch on the `[ Upstream commit <sha> ]` line (the form `stable-kernel-rules.rst` prescribes) and, on patch 1, upstream's own warning about a syzkaller `Link:` near `Fixes:`; the local CI script's `git am` check passes on each tag; a GitLint title-length warning of 82/81 > 80 on patch 1 (the upstream subject plus the stable prefix); VerifyFixes passes on 6.18.y and warns on 6.12.y and 6.6.y (the fixed commit is there as a backport, not an ancestor). **Pending:** checkpatch and the local CI were **not rerun** on the regenerated 2026-11-01 files (new bases and offsets; the patch-ids equal those of the 2026-10-28 versions). The mail-lint check on the new files is clean. `git apply --check` of all three series and the upstream pair on the 2026-10-30 tags (v7.3.1, v7.2.14, v6.18.60, v6.12.115, v6.6.161) passed with offsets only.

### Not known, not claimed

- The mechanism is read from the source plus the lock list; no stack trace was captured, and the refusal branch in `l2cap_ecred_rsp_defer()` was not instrumented. It is **[inferred]**.
- Whether the other 14 patches of Pauli Virtanen's series matter for the stable lines was not examined; only the pair, and the pair plus `dc1ddc65f06d` on v7.3.1, were tested.
- No fix exists for 6.1.y, 5.15.y and 5.10.y; whether the self-deadlock is reachable by real ECRED users there (ECRED is off by default before v6.2) is not known.
- Real-world frequency of the hang with real peers is not known; the evidence is the BlueZ tester only.
- The raw QEMU logs and comparison scripts are held by the author and are not part of this document; the numbers are from the author's records of them.
- Stable-queue status of the pair was last checked on 2026-10-28 20:34 UTC; `5874f8d03268` in queue-7.3 on 2026-11-01 09:45 UTC. Neither was rechecked on 2026-11-02.
- The size rule is not met (patch 1 is about 130 lines as checkpatch counts it); the request asks for an exception and says so.

### Open points and questions for the reviewer

1. **Size exception.** Is requesting the whole 130-line helper commit acceptable, or is a smaller variant preferred? The ECRED-only sketch (about 82 changed lines) is not equivalent in locking (the LE and BR/EDR defer branches would stay without `conn->lock`).
2. **7.2.y.** The kernel.org release list of 2026-11-01 shows 7.2.15 as the last 7.2.y release (end of life). Mail 1 still asks for 7.2.y and names v7.2.14; it is to be reworded to 7.3.y alone before sending.
3. **Timing and tag.** Both commits carry no `Cc: stable`; they are in mainline for the 7.4 merge window and no 7.4-rc1 exists yet. Is it right to ask now, or wait for rc1 and the automatic `Fixes:` pickup (patch 2 carries `Fixes: ab4eedb790ca`; patch 1 carries none and would not be picked automatically)?
4. **`Fixes:` accuracy.** Upstream's `Fixes: ab4eedb790ca` does not describe the hang (lines without that commit hang too; the self-deadlock path dates from v6.3). The mails keep upstream's tag unchanged and describe the symptom separately. Is that the right framing?
5. **`dc1ddc65f06d`** (lock for sibling channels in `l2cap_ecred_rsp_defer`): is leaving it out correct for stable, given that patch 2's message says the sibling channels also need locking "but that needs separate fix"? The case passes without it.
6. **Cause statement.** Is the self-deadlock description (socket lock held across `__l2cap_ecred_conn_rsp_defer()` and re-taken via `l2cap_chan_del()` to `l2cap_sock_teardown_cb()`) right, given that it is inferred from the source and the lock list?
7. **6.1.y, 5.15.y, 5.10.y.** Should a fix be built (the socket-side change adapted to `conn->chan_lock`), or are the lines out of scope because ECRED is disabled by default there?
8. **Packaging.** Cover letters on two-patch stable series: wanted or not? Is the backporter's sign-off after the `[ backport: ]` note in the expected place?
9. **`5874f8d03268`** (SCI response layout): a separate 7.3.y request (Mail 2), or leave it to the automatic `Fixes:` pickup?

### Route and next step

State: the five mails are drafted and mail-linted; nothing is sent. Route: (1) this review; (2) the submitter decides and sends everything himself, adding his own sign-off, after dry runs that check the recipient list; (3) order: the 7.3.y/7.2.y request first, then the series newest line first, so that no older line is requested before the newer ones; (4) before sending: rerun checkpatch and the local CI on the 2026-11-01 files, recheck the stable queue and the newest tags, resolve open point 2. Afterwards: watch the stable queues; rerun the case on the next tags.

## CO-22 — Other QCA ROME USB IDs missing from btusb's device table; the two ASUS entries missing from stable

### At a glance

| | |
|---|---|
| Subject | Qualcomm ROME-family Bluetooth controllers matched only by btusb's generic class entry stay on their ROM firmware (no rampatch, no NVM) |
| Findings | 10 likely ROME USB IDs without an entry (survey of a hardware-probe snapshot of May 2023 plus Launchpad); none of 27 probe logs that enumerate them has a QCA setup line; control IDs show it in 8 of 8. Two ASUS ROME entries (`0b05:1868`, `0b05:1825`) are in mainline and in no stable branch |
| State on 2026-11-02 | Two mails drafted and mail-linted: a stable request (the ASUS pair) and a list mail to owners. **Nothing sent.** v7.4-rc1 has since been tagged (checked 2026-11-02, tag `bc71431221f5`); before sending, check that both commits are in it |
| Asked of the reviewer | Is the stable request right in content and timing; is the owners' call good practice (data before any entry patch); are the evidence and the wording sound |

### Background

btusb's `quirks_table` marks Qualcomm ROME controllers with `BTUSB_QCA_ROME`. For such a device `btusb_setup_qca()` runs at setup and loads the rampatch and NVM from linux-firmware. A ROME USB ID absent from the table binds through the generic Bluetooth class entry; then no QCA setup runs and the controller stays on its ROM firmware. The symptom named in the upstream commits that added three such IDs this year is the repeating kernel line `unexpected event for opcode 0x2005` during LE scanning. For `13d3:3503` (dc16388d45ec, Tibor Harcsa, 2026-06-29, "Bluetooth: btusb: Add IMC Networks QCA9377 to quirks table") the message reads: "This device requires Qualcomm Rome firmware and wideband speech support to function properly; otherwise, BLE scanning fails with HCI unexpected event opcode 0x2005 errors." The same ID's ROM-firmware behaviour in SCO audio is the subject of CO-25 below.

The mainline table at commit `cbbddb6b08cc` (2026-10-31; `drivers/bluetooth/btusb_main.c` is a pure rename of `btusb.c` and is identical in bluetooth-next `42b8c2d72926`) has 22 `BTUSB_QCA_ROME` entries **[source]**: 0b05:1825, 0b05:1868, 0cf3:535b, 0cf3:e007, 0cf3:e009, 0cf3:e010, 0cf3:e300, 0cf3:e301, 0cf3:e360, 0cf3:e500, 0489:e092, 0489:e09f, 0489:e0a2, 04ca:3011, 04ca:3015, 04ca:3016, 04ca:301a, 04ca:3021, 13d3:3491, 13d3:3496, 13d3:3501, 13d3:3503. (0cf3:3004 was ROME briefly in 2018 and was reverted; `BTUSB_ATH3012` IDs run `btusb_setup_qca()` too, so only IDs with no entry at all miss the setup.)

### Root cause

(Here: how the candidates were found and what is known.)

**Data sources.** The public hardware-probe data (a GitHub mirror of the probe snapshot of May 2023: 473 Bluetooth USB IDs, 157,282 device rows; the project's own web site was unreachable from the author's host) and Launchpad bug reports (170 bugs extracted). For each USB ID without a btusb or ath3k entry, the QCA Wi-Fi chip in the same probe's PCI list was counted. Candidates: no entry, bcdDevice 0.01, QCA9377 or QCA6174 Wi-Fi in the same probe.

**What is read from the data** **[measured/source]**: the pairing (same probe, QCA9377/QCA6174 PCI Wi-Fi), bcdDevice 0.01, and for 3641:0902 the alternate settings, which match those of 13d3:3503. **What is inferred:** that these are ROME controllers. The Wi-Fi chip name says little about the Bluetooth core (CO-25 shows Qualcomm describing QCA9377 as "not ROME" while the kernel table carries three QCA9377 IDs as ROME).

**The dmesg check** (the probe site's kernel logs, May 2023 snapshot) **[measured]**: a "QCA setup marker" is the line `QCA: patch rome` or the enhanced-setup quirk line.

| ID | logs | enumerating the device | with QCA setup marker | with `0x2005` |
|---|---|---|---|---|
| 0489:e09c | 3 | 2 | 0 | 0 |
| 0489:e0a3 | 3 | 3 | 0 | 0 |
| 04ca:301c | 3 | 3 | 0 | 0 (a Launchpad report has it) |
| 04ca:301f | 3 | 3 | 0 | 0 |
| 0cf3:e302 | 3 | 3 | 0 | 0 |
| 0cf3:e303 | 3 | 3 | 0 | 0 |
| 13d3:3500 | 3 | 3 | 0 | 0 |
| 13d3:3506 | 3 | 3 | 0 | 2 (probes 345734b3fd, 18 lines; 6104ee1f65, 1 line) |
| 3641:0902 | 5 | 4 | 0 | 1 (probe d8d42d690f, 4 lines) |
| 13d3:3513 | 1 | 0 | 0 | 0 |
| controls 04ca:3015 / 0cf3:e300 / 0cf3:e009 | 3 / 3 / 3 | 3 / 3 / 2 | 3 / 3 / 2 | 0 |

Candidates: 0 of 27 enumerating logs with a QCA setup marker. Controls: 8 of 8. Five further single-probe IDs (10ab:9802, 04c5:14de, 04ca:3019, 0489:e0a4, 13d3:3519) appeared with QCA6174 Wi-Fi; they were not log-checked and are not in the candidate list. A "works" status on the probe site means only that btusb bound; it does not show that the QCA firmware loaded.

### The change

No kernel change is proposed for the ten candidate IDs. An entry patch without an owner's `/sys/kernel/debug/usb/devices` output would go against the norm: of 73 ID-adding btusb commits since 2025-01-01, 62 carry such a dump, and on the 13d3:3503 v1 Luiz Augusto von Dentz wrote (2026-06-29) "Need the contents of /sys/kernel/debug/usb/devices", and later "Respin the patch with this information included." **[source: list archive]**. So the plan is two mails:

1. **A stable request for the two ASUS entries**, once v7.4-rc1 is tagged (the draft says "in mainline since v7.4-rc1"; no such tag existed on 2026-11-01; the commits reached mainline through `for-net-next-2026-10-14` in the 7.4 merge window). `d54601f21faf` (Quentin Strydom, authored 2026-09-28) and `cfa67a1dbfd9` (Konstantin Nazarov, authored 2026-10-01) each add two lines at the head of the ROME block; neither carries `Cc: stable`; neither is in any stable branch (checked on 7.3.1, 7.2.y, 6.18.y, 6.12.y, 6.6.y, 6.1.y; no ASUS 0b05 patch in any stable queue, with a positive control).
2. **One list mail to owners of the ten candidate machines**, asking for the device block from `/sys/kernel/debug/usb/devices`, the output of `dmesg | grep -i -e qca -e 0x2005`, kernel version and model, and offering a way to test an entry without live re-probing.

The mainline commits as merged **[source]**: `d54601f21faf` says that with the quirk applied "btusb loads: qca/rampatch_usb_00000302.bin and qca/nvm_usb_00000302.bin and the unexpected LE Set Random Address completion events are no longer observed", with "Tested-on: ASUS USB 0b05:1868, QCA Rome 0x302". `cfa67a1dbfd9` says "After patching bluetooth is working fine, no unexpected events in log", with "Tested-on: Qualcomm Atheros QCA6174 SoC integrated in motherboard ASUS Z170I PRO GAMING, USB device id: 0b05:1825". An earlier, unmerged submission for 0b05:1825 (Edgard Lopes, 2026-07-21) reported SCO/eSCO audio broken on "its bare ROM firmware" ("corrupted SCO packet", no HFP/HSP microphone); the list's bot answered that it no longer applied and there was no v2. A 2020 user report also had HSP/HFP failing on 0b05:1825.

### The mails, verbatim

#### Mail A: stable request for the ASUS pair (drafted, not sent)

Recipients: the stable list; Cc Quentin Strydom and Konstantin Nazarov (the authors), Marcel Holtmann, Luiz Augusto von Dentz, linux-bluetooth.

```text
Subject: Please backport d54601f21faf and cfa67a1dbfd9 (btusb: ASUS QCA Rome IDs) to stable

Hello,

please consider for linux-7.3.y, linux-6.18.y, linux-6.12.y,
linux-6.6.y, linux-6.1.y, linux-5.15.y and linux-5.10.y, in this
order:

  d54601f21faf ("Bluetooth: btusb: add ASUS 0b05:1868 to QCA Rome
  quirks")
  cfa67a1dbfd9 ("Bluetooth: btusb: add ASUS 0b05:1825 to QCA Rome
  quirks")

Both are in mainline since v7.4-rc1 and carry no Cc: stable tag.
Together they add two device IDs at the head of the btusb QCA ROME
block:

	{ USB_DEVICE(0x0b05, 0x1825), .driver_info = BTUSB_QCA_ROME |
						     BTUSB_WIDEBAND_SPEECH },
	{ USB_DEVICE(0x0b05, 0x1868), .driver_info = BTUSB_QCA_ROME |
						     BTUSB_WIDEBAND_SPEECH },

Without an entry these ASUS controllers match only the generic
Bluetooth class entry, btusb_setup_qca() never runs, and they stay on
their ROM firmware. Both commit messages report repeated "unexpected
event for opcode 0x2005" during LE scanning on that firmware. With the
entry the events stop (both commits), and d54601f21faf records the
driver loading qca/rampatch_usb_00000302.bin and
qca/nvm_usb_00000302.bin. I do not have these devices; the runtime
results are the authors'.

None of the seven trees has either ID. On each tree's current tip
(7.3.1, 6.18.60, 6.12.115, 6.6.161, 6.1.191, 5.15.224, 5.10.273) both
commits cherry-pick cleanly with -x, and drivers/bluetooth/btusb.o
builds with them (x86_64 defconfig, BT=m, BT_HCIBTUSB=m, W=1) with no
new warning. (On 6.6.161 that configuration needs -Wno-error with or
without the two commits, because of a separate btmtk.h issue.)

The same kind of entry, dc16388d45ec ("Bluetooth: btusb: Add IMC
Networks QCA9377 to quirks table"), was queued for 7.2.y down to
5.10.y in October after a request like this one.

Thank you,
Iaroslav Voitovych
```

Notes: the sentence that `dc16388d45ec` "was queued ... after a request like this one" is the draft's own statement. The project records show it released in 7.2.10, 6.18.56, 6.12.113 and 6.6.160 (2026-10-21) and present in the 6.1, 5.15 and 5.10 release candidates of 2026-10-17; whether each queueing followed a request was not re-verified here. The draft lists 7.3.y first and omits 7.2.y (marked end of life on 2026-11-01); the earlier cherry-pick survey did include 7.2.y (clean on 7.2.14).

#### Mail B: owners' call on linux-bluetooth (drafted, not sent)

The draft's URLs (hardware-probe pages and Launchpad bugs) are replaced below by "probe <id>" and "Launchpad bug <number>", the identifiers inside them; the draft carries the full links.

```text
Subject: btusb: QCA ROME controllers without a quirks entry - owners wanted

Hello,

The ten USB IDs below appear to belong to Qualcomm ROME Bluetooth
controllers: each shows bcdDevice 0.01 and sits in machines whose
Wi-Fi is a QCA9377 or QCA6174. None of them has a btusb entry in
mainline or in bluetooth-next (42b8c2d72926). Without one, btusb binds
the controller through the generic Bluetooth class match,
btusb_setup_qca() never runs, and the controller stays on its ROM
firmware. 0b05:1868 and 0b05:1825 were the same case and were fixed by
adding entries (d54601f21faf, cfa67a1dbfd9).

An entry needs data from a real device, so I am asking owners of these
machines for it. The machines are from the public hardware-probe data
(snapshot of May 2023) and from Launchpad:

  ID         machines                            Wi-Fi    links
  0489:e09c  Acer Aspire E5-573G/E5-574G; HP 15  QCA9377  [1]
  3641:0902  Lenovo IdeaPad 320/330, B320;       QCA9377  [2][3]
             LG 22V280
  0cf3:e302  Microsoft Surface Go                QCA6174  [4]
  0489:e0a3  Acer Aspire E5-575G, F5-573G, Spin  QCA9377  [5][6]
  04ca:301c  ASUS VivoBook X512F*, X540*         QCA9377  [7]
  13d3:3500  ASUS X406UA(R), TP203NA             QCA9377  [8]
  04ca:301f  RedmiBook 13/14/16                  QCA6174  [9]
  13d3:3506  ASUS X442U*, X441MA, E402YA         QCA9377  [10]
  0cf3:e303  Microsoft Surface Laptop 3          QCA6174  [11]
  13d3:3513  BBEN G16                            QCA9377  -

None of the kernel logs I could read for these IDs (27 probe logs
that show the device, and three Launchpad reports) has a QCA setup
line; logs of listed IDs from the same source (04ca:3015, 0cf3:e300,
0cf3:e009) show it in 8 of 8. 3641:0902, 04ca:301c and
13d3:3506 also log "unexpected event for opcode 0x2005", as
0b05:1825/1868 did. A "works" status on the hardware-probe site means
only that btusb bound to the device, not that the QCA firmware was
loaded.

If you have one of these machines, please reply with:

 1. the device's block from /sys/kernel/debug/usb/devices (as root,
    with debugfs mounted): the block whose Vendor= and ProdID= match;
 2. the output of
      dmesg | grep -i -e qca -e 0x2005
    after some use of Bluetooth (a scan for devices is enough);
 3. the kernel version (uname -r) and the machine model.

How to read item 2. Today, without an entry, there is no "QCA:" line,
and LE scanning may log
  Bluetooth: hci0: unexpected event for opcode 0x2005
With an entry, a ROME controller logs lines like these (the
"Bluetooth: hci0: " prefix left out; the numbers depend on the chip):
  using rampatch file: qca/rampatch_usb_00000302.bin
  QCA: patch rome 0x302 build 0x3e8, firmware rome 0x302 build 0x111
  using NVM file: qca/nvm_usb_00000302.bin
and the 0x2005 errors stop.

If you want to test an entry: please do not unload and reload btusb
on a running system (rmmod/modprobe, unbind/bind or new_id). On a
QCA9377 here a live re-probe left the controller unresponsive until
power was removed. Instead, add the line below to the "QCA ROME
chipset" block of quirks_table in drivers/bluetooth/btusb.c
(btusb_main.c from 7.4 on), build btusb.ko for the kernel you run,
copy it to /lib/modules/<release>/updates/, run depmod -a, then power
the machine off and on and send items 1-3 again. To undo: delete the
file, run depmod -a, power off and on. With Secure Boot the module has
to be signed with a key the kernel accepts.

	{ USB_DEVICE(0x0489, 0xe09c), .driver_info = BTUSB_QCA_ROME |
						     BTUSB_WIDEBAND_SPEECH },

(with your own vendor and product ID).

[1] probe 31de2e546e
[2] probe d8d42d690f
[3] Launchpad bug 2015005
[4] probe e2f309bb08
[5] probe ba43497e32
[6] Launchpad bug 1815467 (its lsusb attachment is linked in the draft)
[7] Launchpad bug 2080638 - the ID and the 0x2005 lines are in its
    attachments: CurrentDmesg.txt, Lsusb.txt, Lsusb-v.txt
[8] probe 729e2e0d41
[9] probe d1e515a491
[10] probe 345734b3fd
[11] probe 88ea27e220

Thank you,
Iaroslav Voitovych
```

### The candidate table, with evidence per ID

Counts are from the May 2023 probe snapshot (probe = one submitted hardware report; computers = distinct machines). Verdict wording is the survey's own. None of the ten IDs is in mainline (`cbbddb6b08cc`) or bluetooth-next (`42b8c2d72926`), and no patch for any of them was posted since 2026-06-01 (127 btusb patches on patchwork checked; no subject names a candidate ID).

| ID | machines | Wi-Fi in same probe | probes / computers / models | newest kernel in data | logs: device / QCA setup / `0x2005` | owner observation | verdict |
|---|---|---|---|---|---|---|---|
| 0489:e09c | Acer Aspire E5-573(G)/E5-574(G) and others; HP Laptop 15-bw0xx | QCA9377 | 68 / 42 / 13 | 5.19.2 | 2 / 0 / 0 | none | likely missing Qualcomm setup |
| 3641:0902 | Lenovo IdeaPad 320/330, B320-14IKB, B330; LG 22V280; Dell Inspiron 5458 | QCA9377 | 63 / 43 / 12 | 6.0.12 (probe); 5.15.0-69 (Launchpad 2015005, 2023-04) | 4 + 1 report / 0 / 0x2005 x4 in one probe log (attribution to this device from the probe's lsusb, inferred) | none; vendor 0x3641 is not in usb.ids; iManufacturer/iProduct 0 | likely missing Qualcomm setup |
| 0cf3:e302 | Microsoft Surface Go | QCA6174 | 51 / 37 / 1 | 6.2.6 | 3 / 0 / 0 | none | likely missing Qualcomm setup |
| 0489:e0a3 | Acer Aspire E5-575(G), F5-573(G), Spin SP315-51, others | QCA9377 | 50 / 33 / 14 | 6.2.0 (probe); 4.18.0-10 (Launchpad 1815467, 2019) | 3 + 1 report / 0 / 0 | Launchpad 1815467 (Acer Spin 5 SP513-52N): Bluetooth mouse not found on several distributions, works on Windows/Android (quoted); link to the missing entry inferred | confirmed malfunction (owner's observation; cause inferred) |
| 04ca:301c | ASUS VivoBook X512F*, X540*, X540NA | QCA9377 | 39 / 26 / 6 | 6.8.0-44 (Launchpad 2080638, 2024-09) | 3 + 1 report / 0 / 1 (Launchpad report; only Bluetooth device in its lsusb, attribution inferred) | Launchpad 2080638 (ASUS X512FB, Ubuntu 24.04): Bluetooth off after every reboot, works after reloading modules and restarting the service (quoted); link inferred | confirmed malfunction (owner's observation; cause inferred) |
| 13d3:3500 | ASUS X406UA(R), TP203NA(S), TS10 | QCA9377 | 33 / 19 / 5 | 5.19.0 | 3 / 0 / 0 | none | likely missing Qualcomm setup |
| 04ca:301f | RedmiBook 13 R, 14-APCS, 14 II, 16 | QCA6174 | 18 / 12 / 4 | 5.15.16 | 3 / 0 / 0 | none | likely missing Qualcomm setup |
| 13d3:3506 | ASUS X442U*, VivoBook X441MA, E402YA | QCA9377 | 11 / 9 / 6 | 6.1.12 | 3 / 0 / 2 (probe 345734b3fd 18 lines, 6104ee1f65 1 line) | none | likely missing Qualcomm setup |
| 0cf3:e303 | Microsoft Surface Laptop 3 | QCA6174 | 9 / 6 / 1 | 5.17.9 | 3 / 0 / 0 | none | likely missing Qualcomm setup |
| 13d3:3513 | BBEN G16 | QCA9377 | 6 / 2 / 2 | 5.19.4 | 0 / 0 / 0 (no usable log) | none | confirmed missing entry (no usable log) |

Among the 170 Launchpad bugs extracted, only 04ca:301c is a QCA Bluetooth ID unlisted in btusb's table.

### Tests and results

Cherry-pick and build matrix **[measured]** (2026-11-01; gcc 13.3.0; each line's current tip; `drivers/bluetooth/btusb.o`, x86_64 defconfig, `CONFIG_BT=m`, `CONFIG_BT_HCIBTUSB=m`, W=1; "control" = the tip without the two commits, "picked" = with them via `git cherry-pick -x`, d54601f21faf then cfa67a1dbfd9; on 7.3.y the file is `btusb_main.c`, a pure rename that the cherry-pick follows). Columns "-Werror / without / warnings" give the build result with `CONFIG_WERROR`, without it, and the number of warnings.

| line | tip | pick | both entries present | control | picked | new warnings |
|---|---|---|---|---|---|---|
| 7.3.y | 7.3.1 (79a907609d53d) | clean | 2 | OK / OK / 0 | OK / OK / 0 | 0 |
| 6.18.y | 6.18.60 (f45ed76d6791c) | clean | 2 | OK / OK / 0 | OK / OK / 0 | 0 |
| 6.12.y | 6.12.115 (03bae623ec326) | clean | 2 | OK / OK / 0 | OK / OK / 0 | 0 |
| 6.6.y | 6.6.161 (b5a1dc3ad4822) | clean | 2 | **FAILED** / OK / 4 | **FAILED** / OK / 4 | 0 |
| 6.1.y | 6.1.191 (08889840163eb) | clean | 2 | OK / OK / 0 | OK / OK / 0 | 0 |
| 5.15.y | 5.15.224 (700e62ea909a7) | clean | 2 | OK / OK / 0 | OK / OK / 0 | 0 |
| 5.10.y | 5.10.273 (f23b568f7597f) | clean | 2 | OK / OK / 0 | OK / OK / 0 | 0 |

An earlier cherry-pick-only survey (no build) also showed clean picks on 7.2.y (7.2.14) down to 6.1.y. No device was available, so no runtime test of either entry was made here: the runtime results are the commit authors'.

**6.6.y build break found by the matrix (not caused by the ASUS commits)** **[measured]**: with `CONFIG_BT_HCIBTUSB=m`, MTK support off and `CONFIG_WERROR=y`, `drivers/bluetooth/btusb.o` fails to build on 6.6.161 with or without the two commits, even without W=1:

```text
drivers/bluetooth/btmtk.h:232:13: error: 'btmtk_fw_get_filename' defined but not used [-Werror=unused-function]
drivers/bluetooth/btmtk.h:221:12: error: 'btmtk_register_coredump' defined but not used [-Werror=unused-function]
drivers/bluetooth/btmtk.h:211:12: error: 'btmtk_setup_firmware' defined but not used [-Werror=unused-function]
drivers/bluetooth/btmtk.h:205:12: error: 'btmtk_setup_firmware_79xx' defined but not used [-Werror=unused-function]
```

The stub functions in `btmtk.h` are non-inline `static`. Bisect: v6.6.141 builds, v6.6.142 fails; introduced by `b748250d778e` (the 6.6 backport of `00f993fdec06`, "Stable-dep-of dd1dda6b8d6e"). The mainline fix is `23e88450bb04` ("Bluetooth: btmtk: Mark all stub functions as inline"); it is not in 6.6.y, conflicts on a cherry-pick onto 6.6.161, and is not in queue-6.6. Whether this was already reported on the stable list is **unchecked** (the list archive search was refused with HTTP 403). The stable request therefore mentions that 6.6.161 needs `-Wno-error`. A local backport of the inline-stub fix for 6.6.y was prepared on a side branch and is not part of this request.

Other checks: a stable-queue search for any 0b05 ASUS patch found none queued on any line (positive control: other Bluetooth patches were found). Both draft mails pass the local mail-lint.

### Not known, not claimed

- That the ten candidate IDs are ROME controllers is inferred from Wi-Fi pairing and descriptors. The ROM-firmware signature (no `QCA:` line, `0x2005` errors) was found in logs for 3641:0902 (one probe log), 13d3:3506 (two logs) and 04ca:301c (one Launchpad report) only; for the others the absence of a QCA line is the only signal.
- The probe data is from May 2023; the logs predate current kernels. Whether newer kernels behave differently for these IDs is not known.
- The PCI Wi-Fi chip is a proxy; the Bluetooth core of a "QCA9377"-named module need not match btusb's ROME protocol (see CO-25).
- No ASUS or candidate device was available for a runtime test.
- Whether anyone has already reported the 6.6.y `btmtk.h` break is unchecked.
- The stable-queue facts are as of 2026-11-01.

### Open points and questions for the reviewer

1. Stable request timing: send only after v7.4-rc1 is tagged, so "in mainline since v7.4-rc1" is true; or earlier with "in mainline (7.4 merge window)"?
2. Is an ID-only entry request, with the commit authors' Tested-on as the only runtime evidence, acceptable to the stable team (the draft cites the `dc16388d45ec` precedent)?
3. Should the 6.6.y `btmtk.h` build break be reported or fixed first, and by whom? It blocks `-Werror` builds of btusb on 6.6.y, with or without the ASUS entries.
4. Owners' mail: is the instruction not to unload and reload btusb on a running system sound advice for a list mail? It rests on one observation (a live re-probe of a QCA9377 left the controller unresponsive until power was removed).
5. Is it right to name third-party machines from probe data on the list? (Models and USB IDs only.)
6. Should the singleton IDs (10ab:9802, 04c5:14de, 04ca:3019, 0489:e0a4, 13d3:3519) be log-checked and added?
7. Is the wording "appear to belong to Qualcomm ROME controllers" right, given the inference above?

### Route and next step

(1) This review. (2) After v7.4-rc1 is tagged: rerun the matrix on the then-current tips, then the submitter sends mail A. (3) Mail B to linux-bluetooth when the submitter decides. (4) For each owner who answers with a device block and a successful test, an entry patch for that ID, with their output in the commit message, by the usual route. Nothing is sent; the sends are the submitter's.

## CO-23 + CO-37 — two bluetoothd memory-lifetime fixes, six mails stacked on BlueZ master

### At a glance

| | |
|---|---|
| Target | BlueZ master (six mails, base 14bd6ab65). Ubuntu 24.04 `bluez 5.72-0ubuntu5.8`: backports of the endpoint fix (two patches) and of the adapter-teardown fix (one patch). |
| Defects | **A**: `a2dp_reconfig()` writes to a freed `struct a2dp_setup` (CO-23; project tag U22). **B**: `clear_endpoint()` and `media_endpoint_remove()` read freed memory at bluetoothd exit, or when the sound server leaves the bus with an A2DP endpoint registered (CO-37; U23). **C**: `discovery_cleanup()` at adapter teardown reads freed devices (U24; fixed upstream by 7e3212fa233e, not yet released; only the 5.72 backport is ours). |
| State on 2026-11-02 | Mails written, reproduced under AddressSanitizer, CI-bot checks pass on the exact mails. Not sent. The duplicate Release (open point a) is fixed by a sixth mail (2026-11-02). |
| Asked of the reviewer | (1) Review the six mails and the three 5.72 patches. (2) Answer the questions in "Open points". (3) Say whether the commit messages meet BlueZ's rules (items flagged below). |

### Background

**Reading conventions.**
- Each claim is marked **[measured]** (with the numbers), **[source]** (tree or tag, commit, `file:line`) or **[inferred]**.
- The BlueZ trees quoted are master at commit 14bd6ab65f4a647302edbd6df27f6faa91bee8a8 (`git describe`: 5.87-455-g14bd6ab65, committed 2026-10-29) and the 5.72 tag. Where Ubuntu's tree differs, "Ubuntu 5.72-0ubuntu5.8" is named.
- Patches and debdiffs are reproduced verbatim, copied from the stored files by script, except for three edits: the mbox `From <sha>` line and the `From:` header of mails are dropped; `Name <address>` is written `Name`; URLs are replaced by `[URL omitted]`.
- All tests ran in QEMU guests with emulated controllers (btvirt), or in containers, with AddressSanitizer and UBSan builds where stated. No real Bluetooth hardware was used for any number below.
- The tester kernel was bluetooth-next 47d4d9f67e92 with BlueZ's `doc/tester.config`.
- The CI bot's own checks were run locally in the bot's container image (action-ci 60348956fc7b), not by the bot itself.

**BlueZ pieces involved.**
- `bluetoothd` has an A2DP profile (`profiles/audio/a2dp.c`, AVDTP in `avdtp.c`) and a media plugin (`profiles/audio/media.c`, `transport.c`).
- A sound server such as PipeWire registers A2DP endpoints with `org.bluez.Media1.RegisterApplication` (older clients use `RegisterEndpoint`).
- Each endpoint owns a stream end point (SEP) in the A2DP server. When a remote device connects, a `MediaTransport1` object is created. A client `Acquire()`s it. That locks the SEP's stream.
- `org.bluez.MediaEndpoint1.SetConfiguration` on a *remote* endpoint object (`a2dp.c: set_configuration()`) makes bluetoothd reconfigure the stream, switching the local endpoint. A running stream is closed first with AVDTP Close, or aborted with AVDTP Abort.

**How defect A was found.** `bluetoothd` on the project's laptop crashed on 2026-09-08 at 10:23:43 with a bad `free()` ("segfault at fffffffffffffff9", `free((void *)1)`). A codec-switch `SetConfiguration` had arrived while an AVDTP Close was pending. The core file is gone. The daemon's debug log of the crashed process and the binary remain. The log shows the same sequence as the reproduction below, and offset 80 of the 112-byte `struct a2dp_setup` matches the binary's store `movl $0x1,0x50(%rbx)`. **[measured, log and disassembly]**

**How defects B and C were found.** AddressSanitizer builds of Ubuntu's 5.72 reported both at bluetoothd exit while running another backport's VM tests. They were then reproduced on master. They were not seen on the laptop, whose build has no AddressSanitizer. The reports appear only when bluetoothd exits without powering the adapter off first. This is the case when it loses the system bus: in every occurrence the log had just printed "Disconnected from D-Bus. Exiting." On SIGTERM it powers the adapter off first (`src/main.c:1485`, `adapter_shutdown()`), and no report appears. **[measured on 4 occurrences and on the reproductions, source]**

**Upstream state, searched 2026-10-29 and 2026-11-01.**
- Defect A: no fix and no report in BlueZ master, patchwork or the linux-bluetooth archive.
- Defect B: no fix and no list patch.
- A related RFC by Bastien Nocera (patchwork 14568134, 2026-05-12, state "new", unreviewed) guards `release_endpoint()`'s final `media_endpoint_remove()` with a `g_slist_find()`. It applies as posted and CO-37 applies on top of it. The RFC alone fails both CO-37 tests 10/10 (`media.c:321`). RFC plus CO-37 passes 10/10. The RFC's guard comes after the failing reads **[measured, source]**. Whether his reported crash is the same chain is not established; his report has no AddressSanitizer output.
- Defect C: fixed on master by 7e3212fa233e ("adapter: clear discovery_found list before discovery_cleanup()", Pauli Virtanen, 2026-09-04). It is in no release tag; the newest tag is 5.87 (2026-07-03).
- The read that CO-37's fix 1 repairs was introduced by 7482aceece70 ("profiles/audio: fix UAF on external media service teardown", Frédéric Danis, 2026-07-15). It is in no release tag. Fedora's 5.87-4 package carries it inside a bundled patch **[checked in Fedora's packaging history]**. 5.72 has no `endpoint->app` at all, so the read does not exist there.

**Who can trigger them (from source only; nothing was run as a non-root user; all guest runs were root).**
- BlueZ's shipped D-Bus policy (`src/bluetooth.conf`, 14bd6ab65 and 5.72 alike) has a `<policy context="default">` containing `<allow send_destination="org.bluez"/>`. Any local user may therefore call `org.bluez`.
- The `Media1` handlers (`register_app()`, `register_endpoint()` and the others in `profiles/audio/media.c`) and `Device1.DisconnectProfile` (`src/device.c: disconnect_profile()`) contain no authorization check. `git grep g_dbus_register_security` finds no call under `src/`, `profiles/` or `plugins/` at 14bd6ab65, so no privilege table is installed for gdbus's `check_privilege()`.
- Defect A additionally needs a paired remote device that leaves the AVDTP Close unanswered, and a caller that owns a registered local endpoint. `set_configuration()` looks the local endpoint up by the caller's bus name and object path (`a2dp.c:2215`, `find_sep(... sender, path)`). **[source]**
- Defect B needs a streaming client whose transport is acquired, and either that client leaving the bus or bluetoothd losing the bus. **[source and measured in guests]**

### Root cause

#### Defect A (CO-23): `a2dp_reconfig()`, master 14bd6ab65, `profiles/audio/a2dp.c`

```c
/* a2dp.c:2162-2175 */
			err = avdtp_close(chan->session, stream->stream, FALSE);
			if (err < 0) {
				err = avdtp_abort(chan->session,
							stream->stream);
				if (err < 0) {
					error("avdtp_abort: %s",
							strerror(-err));
					goto fail;
				}
			}

			setup->reconfigure = TRUE;

			return 0;
```

The sequence **[source; confirmed by the AddressSanitizer log and the debug log, measured]**:

1. `a2dp_reconfig()` takes the setup (`a2dp_setup_get()`, a new one with reference count 1 when none exists) and adds its own callback `reconfig_cb`.
2. `avdtp_close()` refuses with "rejecting since close is already initiated" (`avdtp.c:3733`), because a Close sent by the local side is already pending.
3. `avdtp_abort()` sets the stream ABORTING. Since the pending request belongs to this stream, it calls `cancel_request(session, ECANCELED)`:

```c
/* avdtp.c:3788-3791 */
	avdtp_stream_set_state(stream, AVDTP_STATE_ABORTING);

	if (session->req && stream == session->req->stream)
		return cancel_request(session, ECANCELED);
```

4. `cancel_request()` calls `close_cfm()` with an error. `close_cfm()` calls `finalize_config()`, which runs `reconfig_cb` (the D-Bus error reply) and then `setup_cb_free()`:

```c
/* a2dp.c:333-343 */
static void setup_cb_free(struct a2dp_setup_cb *cb)
{
	struct a2dp_setup *setup = cb->setup;

	if (cb->source_id)
		g_source_remove(cb->source_id);

	setup->cb = g_slist_remove(setup->cb, cb);
	setup_unref(cb->setup);
	g_free(cb);
}
```

5. If the setup was created for this request, that `setup_unref()` drops the last reference and the setup is freed. Back in `a2dp_reconfig()`, `setup->reconfigure = TRUE;` (line 2173) writes into freed memory. AddressSanitizer: WRITE of size 4, 80 bytes inside a 112-byte region, freed in `setup_cb_free` (`a2dp.c:341`), allocated in `setup_new` (`a2dp.c:269`) via `a2dp_setup_get` (`a2dp.c:530`).

A second ending of the same chain **[source]**: if `cancel_request()` cannot send the Abort it returns the error. `avdtp_abort()` returns it, and `a2dp_reconfig()` goes to `fail:`:

```c
/* a2dp.c:2190-2192 */
fail:
	setup_cb_free(cb_data);
	return err;
```

At that point `finalize_config()` has already freed `cb_data`. The callback is freed twice, and `set_configuration()` replies to the D-Bus call a second time (`a2dp.c:2233-2238`). No ordinary test can make the Abort send fail while the signalling channel still looks connected, so this ending is covered by reading only.

Introduced by 5071fadb97b8 ("a2dp: Try aborting when switching endpoints", Luiz Augusto von Dentz, 2019-05-03, first in 5.51). Before it `a2dp_reconfig()` called only `avdtp_close()`, which completes nothing synchronously. Every release since, including Ubuntu 24.04's 5.72, has it.

#### Defect B (CO-37): endpoint removal deferred while the stream is locked

Master 14bd6ab65, `profiles/audio/media.c` and `a2dp.c`:

```c
/* media.c:308-323 (fix 1 moves the "if (endpoint->app)" block above the A2DP return) */
static void media_endpoint_remove(void *data)
{
	struct media_endpoint *endpoint = data;
	struct media_adapter *adapter = endpoint->adapter;

#ifdef HAVE_A2DP
	if (endpoint->sep) {
		a2dp_remove_sep(endpoint->sep);
		return;
	}
#endif

	if (endpoint->app) {
		queue_remove(endpoint->app->endpoints, endpoint);
		endpoint->app = NULL;
	}
```

```c
/* a2dp.c:3061-3064, end of a2dp_remove_sep() */
	if (queue_find(sep->streams, match_locked, NULL))
		return;

	a2dp_unregister_sep(sep);
```

```c
/* a2dp.c:3586-3590, in a2dp_sep_unlock() */
	/* Unregister sep if it was removed */
	if (g_slist_find(l, sep) == NULL) {
		a2dp_unregister_sep(sep);
		return TRUE;
	}
```

```c
/* media.c:3801-3814 */
static void path_free(void *data)
{
	struct media_adapter *adapter = data;
	GSList *l;

	queue_destroy(adapter->apps, app_free);

	for (l = adapter->endpoints; l;) {
		struct media_endpoint *endpoint	= l->data;

		l = g_slist_next(l);

		release_endpoint(endpoint);
	}
```

```c
/* media.c:408-414 */
static void clear_endpoint(struct media_endpoint *endpoint)
{
	media_endpoint_cancel_all(endpoint);

	while (endpoint->transports != NULL)
		clear_configuration(endpoint, endpoint->transports->data);
}
```

Mechanism **[source; the AddressSanitizer stacks agree, measured]**:

- A stream is locked by `transport_a2dp_resume()` (`transport.c:586`), that is, by an acquired transport. `a2dp_remove_sep()` takes the SEP off the server's list but returns without unregistering it while a stream is locked. The removal is deferred and the endpoint stays in `adapter->endpoints`.
- **B1, first read (master only, `media.c:321`).** 7482aceece70 added `endpoint->app` and unlinks it in `media_endpoint_remove()`, but after the A2DP early return. A deferred removal therefore leaves `endpoint->app` pointing to an application that `app_free()` then frees (`media.c:3119`). When the transport is released later, unlocking the stream unregisters the SEP and calls `media_endpoint_remove()` again, which reads `endpoint->app->endpoints`.
  - It happens at runtime: the sound server leaves the bus while its transport is acquired. The app's disconnect watch frees the app. The owner's disconnect watch releases the transport. The stream is unlocked and the SEP unregistered (use stack `media_endpoint_remove <- a2dp_unregister_sep <- a2dp_sep_unlock <- transport_a2dp_suspend <- service_filter`).
  - It also happens at exit, in step 6 below.
  - Another test campaign met the same read once in about 150 shutdowns, at BlueZ ebbb4ee31ad7 (`media.c:312`, the same statement before later line shifts). Both fixes apply to that commit (`git apply --check`, offsets -9 and -94).
- **B2, second read (`media.c:412`, also 5.72 `media.c:300`).** At exit `main()` runs `plugin_cleanup()` before `adapter_cleanup()` (`src/main.c:1717`, `:1723`), so the media driver is unloaded while devices and connections still exist: `a2dp_exit()` -> `unload_driver` -> `media_server_remove` -> `media_unregister` -> `g_dbus_unregister_interface` -> `path_free()`. The steps that follow:
  1. `path_free()` frees the applications first. That removes their endpoints, but the removal of a locked A2DP endpoint is deferred as above.
  2. `path_free()` then calls `release_endpoint()` on that endpoint. With the client still connected it calls `clear_endpoint()`.
  3. `clear_endpoint()`'s loop destroys the transport. `media_transport_free()` -> `media_transport_remove_owner()` -> `transport_a2dp_suspend()` -> `a2dp_sep_unlock()` (`transport.c:1802-1803`, `:401`, `:363`, `:469`).
  4. `a2dp_sep_unlock()` finds the SEP no longer on the list and calls `a2dp_unregister_sep()` (`a2dp.c:3587-3589`). Its destroy callback `a2dp_destroy_endpoint()` (`a2dp.c:2892-2893`, `media.c:801-807`) calls `release_endpoint()` again, which ends in `media_endpoint_remove()` with `sep == NULL` and frees the endpoint (`media.c:335`).
  5. Back in the outer `clear_endpoint()`, the loop condition reads `endpoint->transports` of the freed endpoint. AddressSanitizer: READ of size 8, 168 bytes inside a 184-byte region on master (`media.c:412`); on 5.72, 144 bytes inside a 152-byte region (`media.c:300`).
- On master B1 fires first on the same exit path. With fix 1 alone, the exit case reports exactly B2 (10/10, see Tests).

`path_free()`'s order comes from ee0f3c03fb1d ("media: Fix UnregisterApplication", 2021-06-23, first in 5.60), which put `queue_destroy(adapter->apps, app_free)` in front of the endpoint loop.

#### Defect C (adapter teardown, upstream-fixed)

5.72 `src/adapter.c`: `adapter_remove()` removes (and frees) every device, then calls `discovery_cleanup()` (`adapter.c:1721`), which walks `adapter->discovery_found` with `invalidate_rssi_and_tx_power()`. The devices are already freed when a discovery was running at exit. With SIGTERM, `adapter_stop()` runs `discovery_cleanup()` at power-off and clears the list first, so it too needs the no-power-off exit. 7e3212fa233e frees the list in `adapter_remove()` before `discovery_cleanup()`. On 5.72 the test reports `src/device.c:6161 in device_set_rssi_with_delta` (Ubuntu's tree: `device.c:6167`, the same line): READ of size 1, 645 bytes inside a 680-byte region, allocated in `device_new` and freed in `remove_interface`.

### The change

**CO-23, mail 1.** `a2dp_reconfig()` holds an extra reference to the setup across `avdtp_close()` and `avdtp_abort()`, in the same way `a2dp_cancel()` does, sets `reconfigure` and drops the reference. If `avdtp_abort()` fails, the callback is looked up by its id in the setup (new helper `setup_cb_find()`). It is freed and the error returned only if it is still there. Otherwise the request was completed and replied to already, and 0 is returned.

Alternatives considered and why not **[source; measured]**:
- *Setting `reconfigure` before the calls*, as `a2dp_config()` does (`a2dp.c:3354`, `3384`), removes the write after the free. It does not remove the second ending: a failed Abort send still frees the callback twice.
- *Leaving `reconfigure` set when the request was completed synchronously* is what the code did for a setup that survives (shared with another pending request): `abort_cfm()` drops a reference whenever `reconfigure` is not set (`a2dp.c:1744-1748`), a reference this path never handed it, so clearing the flag would unbalance the count.
- *Adding the callback only after the calls* would change which request the cancelled Close completes, and make the reply depend on the Abort's outcome.

**CO-23, mail 2.** Functional test `test_a2dp_reconfigure_during_close`. A host plugin stops the peripheral's `bluetoothd` with SIGSTOP so that a Close from the source stays pending. The source runs `disconnect <addr> <A2DP Sink UUID>` and then `endpoint.config` twice. The first switch aborts the stream and cancels the Close. The second, with the Abort pending, gets -EINVAL from both calls (the fix's other branch). The peripheral is resumed (SIGCONT, at the latest on teardown, even if the test fails). Once the link is down, the source reconnects and a transport must appear again.

**CO-37, mail 3 (fix 1).** In `media_endpoint_remove()`, the unlink from the endpoint's application is done before the A2DP early return. A deferred removal then no longer leaves a pointer to an application that may be freed. In `app_free()` the queue is already detached by `queue_destroy()`, so the `queue_remove()` is a no-op there.

**CO-37, mail 4 (fix 2).** `path_free()` releases the endpoints first, then frees the applications. `release_endpoint()` then clears the transports while the SEP is still on the server's list, so `a2dp_sep_unlock()` only unlocks. `media_endpoint_remove()` -> `a2dp_remove_sep()` finds the stream unlocked and unregisters the SEP, whose destroy callback frees the endpoint after the outer `clear_endpoint()` has returned. `app_free()` then finds only endpoints it still owns.

Alternatives considered for B **[source]**:
- *Bastien Nocera's membership check in `release_endpoint()`*: does not cover the read in `clear_endpoint()`.
- *Clearing all transports before `app_free()` (an extra loop)*: would clear endpoints whose client already left (`watch == 0`, which `release_endpoint()` deliberately skips) and could free those inside the new loop.
- *Clearing the transports in `media_endpoint_remove()` so removal is never deferred*: changes `UnregisterEndpoint` / `UnregisterApplication` semantics at runtime for a transport in use; not minimal.

**CO-37, mail 5 (tests).** A host plugin `MediaApp` registers an A2DP Source endpoint (SBC) through `RegisterApplication` on its own bus connection, as PipeWire does, and acquires the transport it is configured with. Two tests:
- `test_a2dp_app_exit_with_acquired_transport`: the plugin closes its bus connection; the test expects `[DEL] Transport`, then SIGTERM and exit status 0.
- `test_a2dp_exit_with_acquired_transport`: the system `dbus-daemon` of the guest is killed with SIGKILL, so bluetoothd exits on losing the bus without powering off. Exit status must be 0. The test then removes the bus socket SIGKILL left behind, because otherwise the next test on a reused guest takes its new bus daemon as ready before it listens.

With SIGTERM alone the exit test passes on master (the adapter is powered off first). Stopping the bus daemon with SIGTERM makes the bus announce the application's departure first, which reaches B1 at runtime instead of the exit path, hence the separate runtime test and SIGKILL for the exit test.

**5.72 backports (Ubuntu 24.04), three patches, shown below:**
- *Endpoint half of 7482aceece70.* It adds `struct media_app *app` to `struct media_endpoint`, sets it in `app_register_endpoint()` and unlinks it in `media_endpoint_remove()`, placed before the A2DP return as in fix 1. It is a prerequisite: once `path_free()` releases the endpoints first, `app_free()` must not find the released endpoints in its queue. Fix 2 alone is wrong on 5.72, because 5.72's `media_endpoint_remove()` does not unlink endpoints from `app->endpoints`, so `app_free()` would remove endpoints `release_endpoint()` already freed. Fix 1 itself is not needed on 5.72.
- *Fix 2 unchanged* (context line numbers differ).
- *7e3212fa233e with a trivial conflict resolved* (5.72 has `g_slist_free(adapter->load_keys)` between the context lines; both blocks are kept). It applies to Ubuntu's 5.72-0ubuntu5.8 tree with offset +16.
- All three apply to Ubuntu's `5.72-0ubuntu5.8` tree (`media.c` offset -8, `adapter.c` +16).

### The patches, verbatim

Six mails in sending order, on BlueZ master 14bd6ab65, as they stand after the 2026-11-02 Release fix. Mails 1 and 2 are CO-23; mails 3 to 6 are CO-37. Subjects carry the series numbering as stored; address lines are dropped. No mail carries Signed-off-by (BlueZ takes none).

**Mail 1 of 6 (CO-23): the fix**

```diff
Date: Thu, 29 Oct 2026 12:01:04 +0100
Subject: [PATCH BlueZ 1/6] a2dp: Fix use-after-free when switching endpoints
 during Close

If SetConfiguration is called on a remote endpoint while a Close sent by
the local side is still pending, a2dp_reconfig() gets -EINVAL from
avdtp_close() and calls avdtp_abort(), which cancels the pending Close
with cancel_request(). That calls close_cfm() with an error, and
finalize_config() completes the request and drops the reference held
by its callback. When the setup was created for this request, that
was the last reference and the setup is freed, then a2dp_reconfig()
sets setup->reconfigure on it:

  ERROR: AddressSanitizer: heap-use-after-free
  WRITE of size 4
    #0 a2dp_reconfig profiles/audio/a2dp.c:2173
    #1 set_configuration profiles/audio/a2dp.c:2233
    #2 process_message gdbus/object.c:293
  0x7be28ade7570 is located 80 bytes inside of 112-byte region
  freed by thread T0 here:
    #1 setup_cb_free profiles/audio/a2dp.c:341
  previously allocated by thread T0 here:
    #2 setup_new profiles/audio/a2dp.c:269
    #3 a2dp_setup_get profiles/audio/a2dp.c:530

Hold a reference to the setup across the calls. If avdtp_abort() then
fails, which happens when the Abort cannot be sent after the Close was
canceled, the request may already be completed and replied to, so it
is neither freed nor failed a second time.

Fixes: 5071fadb97b8 ("a2dp: Try aborting when switching endpoints")
---
 profiles/audio/a2dp.c | 32 +++++++++++++++++++++++++++++++-
 1 file changed, 31 insertions(+), 1 deletion(-)

diff --git a/profiles/audio/a2dp.c b/profiles/audio/a2dp.c
index cb1b3a980..3ef191dc2 100644
--- a/profiles/audio/a2dp.c
+++ b/profiles/audio/a2dp.c
@@ -330,6 +330,21 @@ static struct a2dp_setup_cb *setup_cb_add(struct a2dp_setup *setup)
 	return cb;
 }
 
+static struct a2dp_setup_cb *setup_cb_find(struct a2dp_setup *setup,
+							unsigned int id)
+{
+	GSList *l;
+
+	for (l = setup->cb; l != NULL; l = l->next) {
+		struct a2dp_setup_cb *cb = l->data;
+
+		if (cb->id == id)
+			return cb;
+	}
+
+	return NULL;
+}
+
 static void setup_cb_free(struct a2dp_setup_cb *cb)
 {
 	struct a2dp_setup *setup = cb->setup;
@@ -2114,6 +2129,7 @@ static int a2dp_reconfig(struct a2dp_channel *chan, const char *sender,
 	struct a2dp_setup *setup;
 	struct a2dp_stream *stream;
 	struct a2dp_setup_cb *cb_data;
+	unsigned int id;
 	GSList *l;
 	int err;
 
@@ -2159,6 +2175,13 @@ static int a2dp_reconfig(struct a2dp_channel *chan, const char *sender,
 			if (!avdtp_has_stream(chan->session, stream->stream))
 				continue;
 
+			/* If a Close is pending avdtp_abort() cancels it and
+			 * close_cfm() completes this request, which may drop
+			 * the last reference to setup before returning.
+			 */
+			setup_ref(setup);
+			id = cb_data->id;
+
 			err = avdtp_close(chan->session, stream->stream, FALSE);
 			if (err < 0) {
 				err = avdtp_abort(chan->session,
@@ -2166,11 +2189,18 @@ static int a2dp_reconfig(struct a2dp_channel *chan, const char *sender,
 				if (err < 0) {
 					error("avdtp_abort: %s",
 							strerror(-err));
-					goto fail;
+					/* Unless already completed */
+					if (setup_cb_find(setup, id))
+						setup_cb_free(cb_data);
+					else
+						err = 0;
+					setup_unref(setup);
+					return err;
 				}
 			}
 
 			setup->reconfigure = TRUE;
+			setup_unref(setup);
 
 			return 0;
 		}

base-commit: 14bd6ab65f4a647302edbd6df27f6faa91bee8a8
-- 
2.43.0
```

**Mail 2 of 6 (CO-23): the test**

```diff
Date: Thu, 29 Oct 2026 12:01:06 +0100
Subject: [PATCH BlueZ 2/6] test: Cover A2DP endpoint switch while Close is
 pending

Add test_a2dp_reconfigure_during_close, where the peripheral's
bluetoothd is stopped so that a Close sent by the source is left
pending, and the source then switches endpoints with SetConfiguration,
which aborts the stream and cancels the Close. That call must fail, as
must a second one made while the Abort is pending, and the stream be
configured again on reconnection, made once the link is down, as a
connection attempted while it goes down can be refused.

A host plugin stops the bluetoothd it started and resumes it, at the
latest on teardown, so that a failing run leaves no stopped bluetoothd
behind.

Built with AddressSanitizer, bluetoothd on the source reports a
heap-use-after-free in a2dp_reconfig() without the previous patch.
---
 doc/functional-a2dp.rst      | 34 +++++++++++++
 test/functional/test_a2dp.py | 99 +++++++++++++++++++++++++++++++++++-
 2 files changed, 132 insertions(+), 1 deletion(-)

diff --git a/doc/functional-a2dp.rst b/doc/functional-a2dp.rst
index f38a458bb..84b4c8251 100644
--- a/doc/functional-a2dp.rst
+++ b/doc/functional-a2dp.rst
@@ -134,3 +134,37 @@ test_a2dp_disconnect_during_setconf[accept|reject]
 	``auto_config()``. A late ``yes`` used to also leave the stale
 	transport registered, failing the next connection with
 	``Resource temporarily unavailable``.
+
+test_a2dp_reconfigure_during_close
+----------------------------------
+
+:Setup: As above, with the transport already created. A host plugin
+	on the peripheral stops and resumes its `bluetoothd`, and resumes
+	it on teardown if the test ends while it is stopped.
+
+:Steps:
+	1. Peripheral: stop `bluetoothd` with ``SIGSTOP``, so that it
+	   answers no AVDTP request.
+	2. Central: ``disconnect <peripheral bdaddr> <A2DP Sink UUID>``,
+	   which sends a Close that is left pending.
+	3. Central: ``endpoint.config <remote endpoint>
+	   /local/endpoint/ep0 MQ_STEREO_44_1``.
+	4. Central: the same ``endpoint.config`` again.
+	5. Peripheral: resume `bluetoothd` with ``SIGCONT``.
+	6. Central: once the link is down, ``connect <peripheral bdaddr>``.
+
+:Expected:
+	2. ``Attempting to disconnect``.
+	3. ``Failed to config endpoint: org.bluez.Error.Failed``: switching
+	   endpoints aborts the stream, which cancels the pending Close and
+	   completes the request with an error.
+	4. ``Failed to config endpoint: org.bluez.Error.Failed``: with the
+	   Abort pending the stream can be neither closed nor aborted.
+	5. The transport is removed (``[DEL] Transport``), then the link
+	   goes down (``Connected: no``).
+	6. A transport appears again, and ``Connection successful``.
+
+:Notes: Regression test for a use-after-free in `bluetoothd` on the
+	central: completing the request freed its setup before
+	``a2dp_reconfig()`` set ``reconfigure`` on it, which
+	AddressSanitizer reports (`bootstrap-configure` enables it).
diff --git a/test/functional/test_a2dp.py b/test/functional/test_a2dp.py
index 12348ea05..4ac61492b 100644
--- a/test/functional/test_a2dp.py
+++ b/test/functional/test_a2dp.py
@@ -4,9 +4,19 @@
 Tests for A2DP using bluetoothctl in VM instances
 """
 
+import logging
+import signal
+
 import pytest
 
-from pytest_bluezenv import Bluetoothd, Pexpect, find_exe, host_config
+from pytest_bluezenv import (
+    Bluetoothd,
+    HostPlugin,
+    Pexpect,
+    find_exe,
+    host_config,
+    wait_until,
+)
 from pytest_bluezenv.utils import bluez_src_dir
 
 pytestmark = [pytest.mark.vm]
@@ -200,3 +210,90 @@ def test_a2dp_disconnect_during_setconf(hosts, reply):
     sink.send("yes\n")
     source.expect("Connection successful")
     source.expect(TRANSPORT_RE)
+
+
+class PausedBluetoothd(HostPlugin):
+    """
+    Host plugin stopping the bluetoothd of the host with SIGSTOP, so
+    that it answers no request, and resuming it with SIGCONT, at the
+    latest on teardown.
+    """
+
+    name = "paused_bluetoothd"
+    depends = [Bluetoothd()]
+
+    def setup(self, impl):
+        self.log = logging.getLogger(self.name)
+        self.job = impl.plugins["bluetoothd"].job
+        self.stopped = False
+
+    def _state(self):
+        with open(f"/proc/{self.job.pid}/stat") as f:
+            return f.read().rsplit(")", 1)[1].split()[0]
+
+    def stop(self):
+        self.log.info(f"Stop bluetoothd {self.job.pid}")
+        self.job.send_signal(signal.SIGSTOP)
+        self.stopped = True
+        wait_until(lambda: self._state() == "T")
+
+    def resume(self):
+        if not self.stopped:
+            return
+
+        self.stopped = False
+        if self.job.poll() is not None:
+            return
+
+        self.log.info(f"Resume bluetoothd {self.job.pid}")
+        self.job.send_signal(signal.SIGCONT)
+        wait_until(lambda: self._state() != "T")
+
+    def teardown(self):
+        self.resume()
+
+
+a2dp_paused_host_config = host_config(
+    [Bluetoothd(), Pexpect()],
+    [Bluetoothd(), Pexpect(), PausedBluetoothd()],
+)
+
+
+@a2dp_paused_host_config
+def test_a2dp_reconfigure_during_close(a2dp_hosts):
+    host0, host1, source, sink = a2dp_hosts
+
+    _, m = source.expect(TRANSPORT_RE)
+    transport = m[0].decode("utf-8")
+    remote_sep = transport.rsplit("/", 1)[0]
+
+    # Stop the peripheral so the Close sent next is left pending
+    host1.paused_bluetoothd.stop()
+
+    try:
+        source.send(f"disconnect {host1.bdaddr} {A2DP_SINK_UUID}\n")
+        source.expect("Attempting to disconnect")
+
+        # Switching endpoints while the Close is pending aborts the
+        # stream, which cancels the Close and completes the request
+        source.send(
+            f"endpoint.config {remote_sep} /local/endpoint/ep0 MQ_STEREO_44_1\n"
+        )
+        source.expect("Failed to config endpoint: org.bluez.Error.Failed")
+
+        # Switching again while the Abort is pending can neither close
+        # nor abort the stream
+        source.send(
+            f"endpoint.config {remote_sep} /local/endpoint/ep0 MQ_STEREO_44_1\n"
+        )
+        source.expect("Failed to config endpoint: org.bluez.Error.Failed")
+    finally:
+        host1.paused_bluetoothd.resume()
+
+    # bluetoothd is still alive and the stream can be configured again,
+    # once the link is down: connecting while it goes down can be refused
+    source.expect(rf"DEL\S*\] Transport {transport}")
+    source.expect(f"Device {host1.bdaddr.upper()} Connected: no")
+    source.send(f"connect {host1.bdaddr}\n")
+    source.expect(TRANSPORT_RE)
+    source.expect("Connection successful")
-- 
2.43.0
```

**Mail 3 of 6 (CO-37): fix 1**

```diff
Date: Sat, 31 Oct 2026 23:10:39 +0100
Subject: [PATCH BlueZ 3/6] media: Fix use-after-free of app removing a locked
 A2DP endpoint

If the stream of an A2DP endpoint is locked by an acquired transport,
media_endpoint_remove() returns once a2dp_remove_sep() has deferred the
removal, without unlinking the endpoint from its application. When the
application goes away, app_free() then frees it while the endpoint
still points to it, and once the transport is released, unlocking the
stream unregisters the SEP and removes the endpoint again, which reads
the freed application:

 ERROR: AddressSanitizer: heap-use-after-free
 READ of size 8 thread T0
     #0 media_endpoint_remove profiles/audio/media.c:321
     #1 a2dp_unregister_sep profiles/audio/a2dp.c:2893
     #2 a2dp_sep_unlock profiles/audio/a2dp.c:3588
     #3 transport_a2dp_suspend profiles/audio/transport.c:469
     #4 service_filter gdbus/watch.c:493

This happens when a sound server leaves the bus while streaming, and
on exit, where path_free() frees the applications first.

Unlink the endpoint from its application before removing its SEP.

Fixes: 7482aceece70 ("profiles/audio: fix UAF on external media service teardown")
---
 profiles/audio/media.c | 10 +++++-----
 1 file changed, 5 insertions(+), 5 deletions(-)

diff --git a/profiles/audio/media.c b/profiles/audio/media.c
index 34ff251c7..3d2f26661 100644
--- a/profiles/audio/media.c
+++ b/profiles/audio/media.c
@@ -310,6 +310,11 @@ static void media_endpoint_remove(void *data)
 	struct media_endpoint *endpoint = data;
 	struct media_adapter *adapter = endpoint->adapter;
 
+	if (endpoint->app) {
+		queue_remove(endpoint->app->endpoints, endpoint);
+		endpoint->app = NULL;
+	}
+
 #ifdef HAVE_A2DP
 	if (endpoint->sep) {
 		a2dp_remove_sep(endpoint->sep);
@@ -317,11 +322,6 @@ static void media_endpoint_remove(void *data)
 	}
 #endif
 
-	if (endpoint->app) {
-		queue_remove(endpoint->app->endpoints, endpoint);
-		endpoint->app = NULL;
-	}
-
 	info("Endpoint unregistered: sender=%s path=%s", endpoint->sender,
 			endpoint->path);
 
-- 
2.43.0
```

**Mail 4 of 6 (CO-37): the Release fix (added 2026-11-02)**

```diff
Date: Mon, 2 Nov 2026 07:46:27 +0100
Subject: [PATCH BlueZ 4/6] media: Fix sending Release twice to A2DP endpoints

release_endpoint() sends Release to the endpoint and then removes it.
For an A2DP endpoint this unregisters its SEP, whose destroy callback
calls release_endpoint() again, which sends a second Release. This
happens to every A2DP endpoint that path_free() releases, on adapter
removal and on exit.

Mark the endpoint as released once Release is sent.

Fixes: bd3ca4fdf463 ("Fix possible invalid read/free on media.c")
---
 profiles/audio/media.c | 10 ++++++++--
 1 file changed, 8 insertions(+), 2 deletions(-)

diff --git a/profiles/audio/media.c b/profiles/audio/media.c
index 3d2f26661..5e72fc292 100644
--- a/profiles/audio/media.c
+++ b/profiles/audio/media.c
@@ -138,6 +138,7 @@ struct media_endpoint {
 	guint			hs_watch;
 	guint			ag_watch;
 	guint			watch;
+	bool			released;
 	GSList			*requests;
 	struct media_adapter	*adapter;
 	struct media_app	*app;
@@ -654,8 +655,8 @@ static void release_endpoint(struct media_endpoint *endpoint)
 
 	DBG("sender=%s path=%s", endpoint->sender, endpoint->path);
 
-	/* already exit */
-	if (endpoint->watch == 0)
+	/* already exit or released */
+	if (endpoint->watch == 0 || endpoint->released)
 		goto done;
 
 	clear_endpoint(endpoint);
@@ -670,6 +671,11 @@ static void release_endpoint(struct media_endpoint *endpoint)
 
 	g_dbus_send_message(btd_get_dbus_connection(), msg);
 
+	/* Removing the A2DP SEP below releases the endpoint again from its
+	 * destroy callback.
+	 */
+	endpoint->released = true;
+
 done:
 	media_endpoint_remove(endpoint);
 }
-- 
2.43.0
```

**Mail 5 of 6 (CO-37): fix 2**

```diff
Date: Sat, 31 Oct 2026 23:10:58 +0100
Subject: [PATCH BlueZ 5/6] media: Fix use-after-free releasing endpoints on
 adapter removal

path_free() frees the applications before releasing the endpoints.
Freeing an application removes its endpoints, and removing an A2DP
endpoint whose stream is locked by an acquired transport is deferred
by a2dp_remove_sep(), so the endpoint stays in the adapter's list.
release_endpoint() then clears its transports, which unlocks the
stream; a2dp_sep_unlock() unregisters the SEP as it was removed, and
its destroy callback releases and frees the endpoint while
clear_endpoint() is still iterating over its transports:

 ERROR: AddressSanitizer: heap-use-after-free
 READ of size 8 thread T0
     #0 clear_endpoint profiles/audio/media.c:412
     #1 release_endpoint profiles/audio/media.c:661
     #2 path_free profiles/audio/media.c:3813
     #3 remove_interface gdbus/object.c:742
     #4 g_dbus_unregister_interface gdbus/object.c:1499
     #5 unload_driver src/adapter.c:8027
     #7 a2dp_exit profiles/audio/a2dp.c:3912
     #8 plugin_cleanup src/plugin.c:251
     #9 main src/main.c:1717
 freed by thread T0 here:
     #1 media_endpoint_remove profiles/audio/media.c:335

This is reached when bluetoothd exits without powering the adapter off
first, e.g. on losing the bus, while a sound server streams.

Release the endpoints first, so that their transports are cleared
while their SEPs are still registered and the removal is not deferred.

Fixes: ee0f3c03fb1d ("media: Fix UnregisterApplication")
---
 profiles/audio/media.c | 10 ++++++++--
 1 file changed, 8 insertions(+), 2 deletions(-)

diff --git a/profiles/audio/media.c b/profiles/audio/media.c
index 5e72fc292..f32ccc699 100644
--- a/profiles/audio/media.c
+++ b/profiles/audio/media.c
@@ -3809,8 +3809,12 @@ static void path_free(void *data)
 	struct media_adapter *adapter = data;
 	GSList *l;
 
-	queue_destroy(adapter->apps, app_free);
-
+	/* Release the endpoints before freeing the applications, which
+	 * removes them: the removal of an A2DP endpoint whose stream is
+	 * locked by a transport is deferred, and release_endpoint() would
+	 * then unlock it while clearing the transports, freeing the
+	 * endpoint it is still using.
+	 */
 	for (l = adapter->endpoints; l;) {
 		struct media_endpoint *endpoint	= l->data;
 
@@ -3819,6 +3823,8 @@ static void path_free(void *data)
 		release_endpoint(endpoint);
 	}
 
+	queue_destroy(adapter->apps, app_free);
+
 	for (l = adapter->players; l;) {
 		struct local_player *mp = l->data;
 
-- 
2.43.0
```

**Mail 6 of 6 (CO-37): the tests, final form (now also counting Releases)**

```diff
Date: Sat, 31 Oct 2026 23:08:18 +0100
Subject: [PATCH BlueZ 6/6] test: Cover A2DP endpoint release with an acquired
 transport

Add a host plugin registering an A2DP Source endpoint, with
RegisterApplication as sound servers do or with RegisterEndpoint, and
tests releasing it:
- when the application leaves the bus while its acquired transport
  locks the stream;
- when bluetoothd loses the bus and exits without powering the adapter
  off, with the stream locked;
- when bluetoothd exits on SIGTERM, where the endpoint must receive
  Release once.

Built with AddressSanitizer, bluetoothd reports a heap-use-after-free
in the first two without the fixes for them, and an endpoint
registered with RegisterEndpoint receives Release twice without
"media: Fix sending Release twice to A2DP endpoints".
---
 doc/functional-a2dp.rst      |  64 ++++++++
 test/functional/test_a2dp.py | 284 +++++++++++++++++++++++++++++++++++
 2 files changed, 348 insertions(+)

diff --git a/doc/functional-a2dp.rst b/doc/functional-a2dp.rst
index 84b4c8251..d747edfd8 100644
--- a/doc/functional-a2dp.rst
+++ b/doc/functional-a2dp.rst
@@ -168,3 +168,67 @@ test_a2dp_reconfigure_during_close
 	central: completing the request freed its setup before
 	``a2dp_reconfig()`` set ``reconfigure`` on it, which
 	AddressSanitizer reports (`bootstrap-configure` enables it).
+
+test_a2dp_app_exit_with_acquired_transport
+------------------------------------------
+
+:Setup: As above, except that the A2DP Source endpoint of the central
+	is registered with ``org.bluez.Media1.RegisterApplication`` by a
+	host plugin on its own bus connection, as sound servers do, and the
+	central uses `bluetoothctl` only to pair and connect.
+
+:Steps:
+	1. Pair, trust and connect as above.
+	2. The plugin acquires the transport its endpoint is configured
+	   with, which locks the stream.
+	3. The plugin closes its bus connection, without unregistering the
+	   application or releasing the transport.
+	4. Stop `bluetoothd` on the central with ``SIGTERM``.
+
+:Expected:
+	1. ``Connection successful``, and ``SetConfiguration`` on the
+	   plugin's endpoint.
+	2. ``Acquire`` replies with a file descriptor.
+	3. The transport is removed (``[DEL] Transport``).
+	4. `bluetoothd` exits with status 0.
+
+:Notes: Regression test for a use-after-free in `bluetoothd`: the
+	endpoint, whose removal was deferred while its stream was locked,
+	still pointed to its freed application when the transport was
+	released.
+
+test_a2dp_exit_with_acquired_transport
+--------------------------------------
+
+:Setup: As ``test_a2dp_app_exit_with_acquired_transport``.
+
+:Steps:
+	1. Pair, trust, connect and acquire the transport as above.
+	2. Kill the system bus daemon of the central with ``SIGKILL``.
+
+:Expected: `bluetoothd` exits with status 0.
+
+:Notes: Regression test for a use-after-free in `bluetoothd` on exit.
+	Losing the bus makes `bluetoothd` exit without powering the adapter
+	off, so the stream is still locked when the endpoints are
+	released; with ``SIGTERM`` the adapter is powered off first and
+	this is not reached. Killing
+	the bus daemon also keeps it from announcing that the application
+	left, which would release the endpoint before `bluetoothd` exits.
+
+test_a2dp_release_on_exit[app|endpoint]
+---------------------------------------
+
+:Setup: One host, with the host plugin of
+	``test_a2dp_app_exit_with_acquired_transport`` registering its
+	endpoint with ``RegisterApplication`` (``app``) or
+	``org.bluez.Media1.RegisterEndpoint`` (``endpoint``).
+
+:Steps: Stop `bluetoothd` with ``SIGTERM``.
+
+:Expected:
+	1. `bluetoothd` exits with status 0.
+	2. The endpoint receives ``Release`` once.
+
+:Notes: Regression test for ``Release`` sent twice to an A2DP endpoint
+	when `bluetoothd` releases it: removing its SEP released it again.
diff --git a/test/functional/test_a2dp.py b/test/functional/test_a2dp.py
index 4ac61492b..f7017c79f 100644
--- a/test/functional/test_a2dp.py
+++ b/test/functional/test_a2dp.py
@@ -5,8 +5,12 @@ Tests for A2DP using bluetoothctl in VM instances
 """
 
 import logging
+import os
 import signal
+import time
 
+import dbus
+import dbus.service
 import pytest
 
 from pytest_bluezenv import (
@@ -14,7 +18,10 @@ from pytest_bluezenv import (
     HostPlugin,
     Pexpect,
     find_exe,
+    get_dbus,
     host_config,
+    mainloop_wrap,
+    parametrized_host_config,
     wait_until,
 )
 from pytest_bluezenv.utils import bluez_src_dir
@@ -297,3 +304,280 @@ def test_a2dp_reconfigure_during_close(a2dp_hosts):
     source.send(f"connect {host1.bdaddr}\n")
     source.expect(TRANSPORT_RE)
     source.expect("Connection successful")
+
+
+MEDIA_INTERFACE = "org.bluez.Media1"
+MEDIA_ENDPOINT_INTERFACE = "org.bluez.MediaEndpoint1"
+MEDIA_TRANSPORT_INTERFACE = "org.bluez.MediaTransport1"
+OBJECT_MANAGER_INTERFACE = "org.freedesktop.DBus.ObjectManager"
+
+MEDIA_APP_PATH = "/test/media_app"
+
+# SBC: all channel modes, frequencies, block lengths and subbands,
+# bitpool 2 to 64
+SBC_CAPABILITIES = [0xFF, 0xFF, 2, 64]
+
+# SBC: joint stereo, 44.1 kHz, 16 blocks, 8 subbands, loudness,
+# bitpool 2 to 32
+SBC_CONFIGURATION = [0x21, 0x15, 2, 32]
+
+
+class MediaEndpoint(dbus.service.Object):
+    """
+    org.bluez.MediaEndpoint1 accepting any configuration, with SBC
+    """
+
+    def __init__(self, bus, path, owner):
+        self.owner = owner
+        self.path = dbus.ObjectPath(path)
+        super().__init__(bus, path)
+
+    def properties(self):
+        return {
+            "UUID": dbus.String(A2DP_SOURCE_UUID),
+            "Codec": dbus.Byte(0x00),
+            "Capabilities": dbus.Array(SBC_CAPABILITIES, signature="y"),
+        }
+
+    @dbus.service.method(
+        MEDIA_ENDPOINT_INTERFACE, in_signature="ay", out_signature="ay"
+    )
+    def SelectConfiguration(self, capabilities):
+        return dbus.Array(SBC_CONFIGURATION, signature="y")
+
+    @dbus.service.method(MEDIA_ENDPOINT_INTERFACE, in_signature="oa{sv}")
+    def SetConfiguration(self, transport, properties):
+        self.owner.transport = str(transport)
+
+    @dbus.service.method(MEDIA_ENDPOINT_INTERFACE, in_signature="o")
+    def ClearConfiguration(self, transport):
+        pass
+
+    @dbus.service.method(MEDIA_ENDPOINT_INTERFACE)
+    def Release(self):
+        self.owner.releases += 1
+
+
+class MediaApplication(dbus.service.Object):
+    """
+    Object manager exposing the endpoints to RegisterApplication
+    """
+
+    def __init__(self, bus, path, endpoint):
+        self.endpoint = endpoint
+        super().__init__(bus, path)
+
+    @dbus.service.method(OBJECT_MANAGER_INTERFACE, out_signature="a{oa{sa{sv}}}")
+    def GetManagedObjects(self):
+        return {
+            self.endpoint.path: {MEDIA_ENDPOINT_INTERFACE: self.endpoint.properties()}
+        }
+
+
+class MediaApp(HostPlugin):
+    """
+    Host plugin registering an A2DP Source endpoint with SBC through
+    org.bluez.Media1.RegisterApplication, as sound servers do, or with
+    RegisterEndpoint ("endpoint"), and acquiring the transport it is
+    configured with.
+    """
+
+    name = "media_app"
+    depends = [Bluetoothd()]
+
+    def __init__(self, register="application"):
+        self.register = register
+
+    def setup(self, impl):
+        self.transport = None
+        self.fd = None
+        self.result = None
+        self.releases = 0
+
+        self._register()
+        wait_until(lambda: self.result is not None)
+        if self.result is not True:
+            raise RuntimeError(f"Register {self.register}: {self.result}")
+
+    def teardown(self):
+        if self.fd is not None:
+            os.close(self.fd)
+
+    def _done(self, *a):
+        self.result = True
+
+    def _error(self, err):
+        self.result = str(err)
+
+    @mainloop_wrap
+    def _register(self):
+        self.bus = get_dbus(private=True)
+        self.endpoint = MediaEndpoint(self.bus, MEDIA_APP_PATH + "/ep0", self)
+
+        media = dbus.Interface(
+            self.bus.get_object("org.bluez", "/org/bluez/hci0"), MEDIA_INTERFACE
+        )
+
+        if self.register == "endpoint":
+            media.RegisterEndpoint(
+                self.endpoint.path,
+                dbus.Dictionary(self.endpoint.properties(), signature="sv"),
+                reply_handler=self._done,
+                error_handler=self._error,
+            )
+            return
+
+        self.app = MediaApplication(self.bus, MEDIA_APP_PATH, self.endpoint)
+        media.RegisterApplication(
+            dbus.ObjectPath(MEDIA_APP_PATH),
+            dbus.Dictionary({}, signature="sv"),
+            reply_handler=self._done,
+            error_handler=self._error,
+        )
+
+    def get_transport(self):
+        return self.transport
+
+    def get_releases(self):
+        return self.releases
+
+    def acquire(self):
+        """
+        Acquire the transport, and return True or the error
+        """
+        self.result = None
+        self._acquire()
+        wait_until(lambda: self.result is not None)
+        return self.result
+
+    def _acquired(self, fd, imtu, omtu):
+        self.fd = fd.take()
+        self.result = True
+
+    @mainloop_wrap
+    def _acquire(self):
+        transport = dbus.Interface(
+            self.bus.get_object("org.bluez", self.transport),
+            MEDIA_TRANSPORT_INTERFACE,
+        )
+        transport.Acquire(reply_handler=self._acquired, error_handler=self._error)
+
+    @mainloop_wrap
+    def exit(self):
+        """
+        Leave the bus without unregistering or releasing anything, as the
+        sound server does when it exits or crashes
+        """
+        self.bus.close()
+
+
+def find_pid(comm):
+    for pid in os.listdir("/proc"):
+        if not pid.isdigit():
+            continue
+
+        try:
+            with open(f"/proc/{pid}/comm") as f:
+                if f.read().strip() == comm:
+                    return int(pid)
+        except OSError:
+            continue
+
+    return None
+
+
+def stop_bluetoothd(how):
+    """
+    Make the bluetoothd of the host this runs on exit, and return its
+    exit code: with SIGTERM, or by killing the system bus daemon, so that
+    it exits as soon as it loses the bus, without powering off.
+    """
+    pid = find_pid("bluetoothd")
+
+    if how == "sigterm":
+        os.kill(pid, signal.SIGTERM)
+    else:
+        os.kill(find_pid("dbus-daemon"), signal.SIGKILL)
+
+    _, status = os.waitpid(pid, 0)
+
+    if how != "sigterm":
+        # Remove the socket left behind, or the bus daemon of the next
+        # test on this host is taken as ready before it listens
+        address = os.environ["DBUS_SYSTEM_BUS_ADDRESS"]
+        os.unlink(address.removeprefix("unix:path="))
+
+    return os.waitstatus_to_exitcode(status)
+
+
+media_app_host_config = host_config(
+    [Bluetoothd(), Pexpect(), MediaApp()],
+    [Bluetoothd(), Pexpect()],
+)
+
+
+def acquire_media_app_transport(host0, host1):
+    """
+    Connect A2DP from the media application of host0 to the bluetoothctl
+    endpoint of host1, and acquire the transport, which locks the stream.
+    """
+    source = host0.pexpect.spawn([find_exe("client", "bluetoothctl")])
+    source.send("power on\n")
+    source.expect("Changing power on succeeded")
+
+    sink = start_bluetoothctl(host1, "a2dp-sink-sbc.bt")
+
+    pair(host0, source, host1, sink)
+
+    source.send(f"connect {host1.bdaddr}\n")
+    source.expect("Connection successful")
+
+    wait_until(lambda: host0.media_app.get_transport() is not None)
+    assert host0.media_app.acquire() is True
+
+    return source, sink
+
+
+@media_app_host_config
+def test_a2dp_app_exit_with_acquired_transport(hosts):
+    host0, host1 = hosts
+
+    source, sink = acquire_media_app_transport(host0, host1)
+    transport = host0.media_app.get_transport()
+
+    host0.media_app.exit()
+
+    # The endpoint is released, and its transport with it
+    source.expect(rf"DEL\S*\] Transport {transport}")
+
+    assert host0.call(stop_bluetoothd, "sigterm") == 0
+
+
+@media_app_host_config
+def test_a2dp_exit_with_acquired_transport(hosts):
+    host0, host1 = hosts
+
+    acquire_media_app_transport(host0, host1)
+
+    assert host0.call(stop_bluetoothd, "bus") == 0
+
+
+media_release_host_config = parametrized_host_config(
+    [
+        ([Bluetoothd(), MediaApp()],),
+        ([Bluetoothd(), MediaApp("endpoint")],),
+    ],
+    ids=["app", "endpoint"],
+)
+
+
+@media_release_host_config
+def test_a2dp_release_on_exit(hosts):
+    (host0,) = hosts
+
+    assert host0.call(stop_bluetoothd, "sigterm") == 0
+
+    # Let a second Release, sent right after the first, arrive too
+    wait_until(lambda: host0.media_app.get_releases() > 0)
+    time.sleep(1)
+    assert host0.media_app.get_releases() == 1
-- 
2.43.0
```

**5.72 backport, patch 1 of 3: endpoint half of 7482aceece70**

```diff
Date: Sat, 31 Oct 2026 23:11:38 +0100
Subject: [PATCH BlueZ 5.72 1/2] media: Unlink endpoints from their application
 on removal

Backport for 5.72 of the endpoint part of upstream commit 7482aceece70
("profiles/audio: fix UAF on external media service teardown"), with
the unlinking done before the A2DP SEP is removed, as in "media: Fix
use-after-free of app when removing a locked A2DP endpoint".

Needed by "media: Fix use-after-free releasing endpoints on adapter
removal": once path_free() releases the endpoints before freeing the
applications, app_free() must not find the released endpoints in its
queue.
---
 profiles/audio/media.c | 8 ++++++++
 1 file changed, 8 insertions(+)

diff --git a/profiles/audio/media.c b/profiles/audio/media.c
index 1faa1c289..56c6774e1 100644
--- a/profiles/audio/media.c
+++ b/profiles/audio/media.c
@@ -105,6 +105,7 @@ struct media_endpoint {
 	guint			watch;
 	GSList			*requests;
 	struct media_adapter	*adapter;
+	struct media_app	*app;
 	GSList			*transports;
 };
 
@@ -221,6 +222,11 @@ static void media_endpoint_remove(void *data)
 	struct media_endpoint *endpoint = data;
 	struct media_adapter *adapter = endpoint->adapter;
 
+	if (endpoint->app) {
+		queue_remove(endpoint->app->endpoints, endpoint);
+		endpoint->app = NULL;
+	}
+
 	if (endpoint->sep) {
 		a2dp_remove_sep(endpoint->sep);
 		return;
@@ -2853,6 +2859,8 @@ static void app_register_endpoint(void *data, void *user_data)
 		return;
 	}
 
+	endpoint->app = app;
+
 	queue_push_tail(app->endpoints, endpoint);
 
 	return;
-- 
2.43.0

```

**5.72 backport, patch 2 of 3: fix 2 (same change as mail 4, 5.72 context)**

```diff
Date: Sat, 31 Oct 2026 23:10:58 +0100
Subject: [PATCH BlueZ 5.72 2/2] media: Fix use-after-free releasing endpoints
 on adapter removal

path_free() frees the applications before releasing the endpoints.
Freeing an application removes its endpoints, and removing an A2DP
endpoint whose stream is locked by an acquired transport is deferred
by a2dp_remove_sep(), so the endpoint stays in the adapter's list.
release_endpoint() then clears its transports, which unlocks the
stream; a2dp_sep_unlock() unregisters the SEP as it was removed, and
its destroy callback releases and frees the endpoint while
clear_endpoint() is still iterating over its transports:

 ERROR: AddressSanitizer: heap-use-after-free
 READ of size 8 thread T0
     #0 clear_endpoint profiles/audio/media.c:300
     #1 release_endpoint profiles/audio/media.c:566
     #2 path_free profiles/audio/media.c:3276
     #3 remove_interface gdbus/object.c:660
     #4 g_dbus_unregister_interface gdbus/object.c:1394
     #5 unload_driver src/adapter.c:7590
     #6 g_slist_foreach
     #7 a2dp_exit profiles/audio/a2dp.c:3575
     #8 plugin_cleanup src/plugin.c:217
     #9 main src/main.c:1456

This is reached when bluetoothd exits without powering the adapter off
first, e.g. on losing the bus, while a sound server streams.

Release the endpoints first, so that their transports are cleared
while their SEPs are still registered and the removal is not deferred.

Fixes: ee0f3c03fb1d ("media: Fix UnregisterApplication")
---
 profiles/audio/media.c | 10 ++++++++--
 1 file changed, 8 insertions(+), 2 deletions(-)

diff --git a/profiles/audio/media.c b/profiles/audio/media.c
index 56c6774e1..943c9a58a 100644
--- a/profiles/audio/media.c
+++ b/profiles/audio/media.c
@@ -3274,8 +3274,12 @@ static void path_free(void *data)
 	struct media_adapter *adapter = data;
 	GSList *l;
 
-	queue_destroy(adapter->apps, app_free);
-
+	/* Release the endpoints before freeing the applications, which
+	 * removes them: the removal of an A2DP endpoint whose stream is
+	 * locked by a transport is deferred, and release_endpoint() would
+	 * then unlock it while clearing the transports, freeing the
+	 * endpoint it is still using.
+	 */
 	for (l = adapter->endpoints; l;) {
 		struct media_endpoint *endpoint	= l->data;
 
@@ -3284,6 +3288,8 @@ static void path_free(void *data)
 		release_endpoint(endpoint);
 	}
 
+	queue_destroy(adapter->apps, app_free);
+
 	for (l = adapter->players; l;) {
 		struct media_player *mp = l->data;
 
-- 
2.43.0

```

**5.72 backport, patch 3 of 3: adapter-teardown fix (upstream 7e3212fa233e by Pauli Virtanen, conflict resolved, otherwise as posted)**

```diff
Date: Fri, 4 Sep 2026 00:50:33 +0300
Subject: [PATCH BlueZ 5.72] adapter: clear discovery_found list before
 discovery_cleanup()

discovery_cleanup() tries to reset RSSI of devices in
adapter->discovery_found list.  When called from adapter_remove(), the
list contains only stale pointers as devices have been already freed,
leading to UAF.

Fix by freeing the discovery_found list in adapter_remove().

Fixes AddressSanitizer: heap-use-after-free
READ of size 1 at 0x7d5b585e033d thread T0
    #0 0x000000772b1a in device_set_rssi_with_delta src/device.c:7121
    #1 0x000000772daa in device_set_rssi src/device.c:7150
    #2 0x0000006aa808 in invalidate_rssi_and_tx_power src/adapter.c:1732
    #3 0x7feb5a35557f in g_slist_foreach (/lib64/libglib-2.0.so.0+0x6257f)
    #4 0x7feb5a355b56 in g_slist_free_full (/lib64/libglib-2.0.so.0+0x62b56)
    #5 0x0000006f67d2 in discovery_cleanup src/adapter.c:1747
    #6 0x0000006f904f in adapter_remove src/adapter.c:7219
    #7 0x0000006f9de2 in adapter_cleanup src/adapter.c:11165
    #8 0x000000418ca9 in main src/main.c:1719

freed by thread T0 here:
    #0 0x7feb5a5434cf in free.part.0 (/lib64/libasan.so.8+0xee4cf)
    #1 0x7feb5a337bb4 in g_free (/lib64/libglib-2.0.so.0+0x44bb4)
    #2 0x0000007519d7 in device_free src/device.c:963

previously allocated by thread T0 here:
    #0 0x7feb5a54424f in calloc (/lib64/libasan.so.8+0xef24f)
    #1 0x000000751fee in device_new src/device.c:4963

(cherry picked from commit 7e3212fa233edbdcfd69f93e2a7418819172c599)
---
 src/adapter.c | 3 +++
 1 file changed, 3 insertions(+)

diff --git a/src/adapter.c b/src/adapter.c
index 022390f0d..a93d607de 100644
--- a/src/adapter.c
+++ b/src/adapter.c
@@ -6959,6 +6959,9 @@ static void adapter_remove(struct btd_adapter *adapter)
 	g_slist_free(adapter->load_keys);
 	adapter->load_keys = NULL;
 
+	g_slist_free(adapter->discovery_found);
+	adapter->discovery_found = NULL;
+
 	discovery_cleanup(adapter, 0);
 
 	unload_drivers(adapter);
-- 
2.43.0

```

### Tests and results

All numbers **[measured]** in QEMU guests, builds with `bootstrap-configure --disable-lsan --enable-asan --enable-ubsan` (the CI bot's TestFunctional flags). Ten-run tables are separate pytest sessions on emulated controllers. The host's Bluetooth was not touched.

#### CO-23 (defect A), final test version

| tree | runs | result |
|---|---|---|
| master 14bd6ab65 + test | 5 | **5/5 fail**: `heap-use-after-free profiles/audio/a2dp.c:2173 in a2dp_reconfig`, WRITE of size 4, 80 bytes inside a 112-byte region, freed in `setup_cb_free` (`a2dp.c:341`) |
| master + fix + test | 15 (5 + 10) | **15/15 pass**, no sanitizer report |

- An earlier version of the test (reconnecting immediately) failed 2 of 20 runs on the *patched* tree without a sanitizer report: a connection attempted while the link goes down can be refused. That is why the final test waits for `Connected: no` before reconnecting. The final version has 0 failures in 15.
- On master 82667d713949 the first reproduction showed the debug log sequence line for line: `setup_ref() ref=1`, `avdtp_close: rejecting since close is already initiated`, `OPEN -> ABORTING`, `Close: Operation canceled (125)`, `close_cfm()`, `setup_unref() ref=0`, `setup_free()`.
- With the fix, the first switch shows `setup_ref() ref=1`, `ref=2`, ..., `setup_unref() ref=1`, `ref=0`, `setup_free()` after the store. The second switch logs `send_request() Unable to send requests while aborting`, `a2dp_reconfig() avdtp_abort: Invalid argument`, and exactly one `org.bluez.Error.Failed` reply. That exercises the fix's "still pending, so free and fail once" branch. The first switch takes the "completed already" branch.
- `make check` (ASan/UBSan build): 42 total, 41 pass, 1 skip (`unit/test-mesh-crypto`), 0 fail, on both master + test and master + fix + test. No unit test covers `profiles/audio/a2dp.c`.

#### CO-37 (defect B): ten runs each on master 14bd6ab65 (tests from the unstacked version)

| tree | test | failing runs | sanitizer report |
|---|---|---|---|
| master + test | app exit | 10/10 | `media.c:321 in media_endpoint_remove`, main loop |
| | bluetoothd exit | 10/10 | `media.c:321 in media_endpoint_remove`, exit path |
| master + fix 1 + test | bluetoothd exit | 10/10 | `media.c:412 in clear_endpoint` (B2 itself) |
| master + fixes 1 and 2 + tests | app exit | **0/10** | none |
| | bluetoothd exit | **0/10** | none |
| 5.72 + harness | bluetoothd exit | 10/10 | `media.c:300 in clear_endpoint` |
| 5.72 + backport (2 patches) + harness | bluetoothd exit | **0/10** | none |
| 5.72 and 5.72 + backport | app exit | 0/10 both | none (B1 is not in 5.72) |

With the final tests, master: 10/10 runs failing, 20 reports, all `media.c:321 in media_endpoint_remove`. Master + both fixes: 0/10.

#### Defect C (7e3212fa233e)

| tree | failing runs | report |
|---|---|---|
| master | 0/10 | none |
| master with 7e3212fa233e reverted | 10/10 | `src/device.c:7349 in device_set_rssi_with_delta` |
| 5.72 | 10/10 | `src/device.c:6161 in device_set_rssi_with_delta` |
| 5.72 + the backport | 0/10 | none |

#### The earlier five-mail stack (2026-11-01, before the Release fix; CO-23 then CO-37, base 14bd6ab65)

- Test patches: CO-23's and CO-37's each apply to 14bd6ab65 alone but conflict when stacked in either order (`test/functional/test_a2dp.py`, `doc/functional-a2dp.rst`). CO-37's mail 5 is the rebased form on top of CO-23's mail 2. The fixes' patch-ids are unchanged by the rebase.
- Stacked tree runs, 10 runs each:
  - base + both tests: all three new tests fail 10/10 (`a2dp.c:2173`, `media.c:321` twice);
  - base + both series: 10/10 pass for each;
  - the whole `test_a2dp.py` (7 test cases): base 3 fail / 4 pass, patched 7/7, twice each.
- `make check`: 41 pass, 1 skip, both sides.
- The functional suite (64 tests including kernel testers; before the stacking): base 60 passed, 3 failed, 4 errors, 1 skipped; base + series 62 passed, 1 failed, 2 errors, 1 skipped. The difference is exactly the two new tests (fail on base by design). The remaining failures are the same on both sides: `l2cap-tester` aborts in the guest with `heap-use-after-free src/shared/timeout-mainloop.c:33 in timeout_callback`. That is a candidate of its own and was not investigated.
- Build: 0 warnings under `-Werror`, both sides.

#### The CI bot's own checks on the earlier five mails (run locally in the bot's image; the six final mails: every check passes on both sides, TestFunctional 48 -> 53)

- Base: all PASS (BuildEll, BluezMake, MakeCheck, MakeDistcheck, CheckValgrind, CheckSmatch, bluezmakeextell, TestFunctional, ScanBuild).
- Base + five mails: CheckPatch, BuildEll, BluezMake, MakeCheck, MakeDistcheck, CheckSmatch, bluezmakeextell, TestFunctional (passed count 48 -> 51), IncrementalBuild and ScanBuild PASS.
  - GitLint failed on mail 3's original subject (81 > 80 columns). With the retitled subject CheckPatch and GitLint PASS (rerun of those two checks).
  - CheckValgrind failed once with an abort of `unit/test-bap` under load. The rerun of the same five mails passed (224.80 s).
- CheckPatch is the bot's (`checkpatch.pl --ignore UNKNOWN_COMMIT_ID`): 0 errors, 0 warnings on all five.

#### Applicability to other trees

- Fixes 1 and 2 apply to BlueZ ebbb4ee31ad7 (offsets -9 and -94).
- The three 5.72 patches apply to Ubuntu's `5.72-0ubuntu5.8` tree, both unmodified and with the U12 backport of CO-03 (`media.c` offset -8, `adapter.c` +16).
- 5.72 builds with the backports with the same 40 compiler warnings as without (all pre-existing, from the image's newer compiler, built with `CFLAGS=-Wno-error`), none in `media.c` or `adapter.c`.
- The 5.72 functional runs used master's test harness and master's test tools (`btvirt`, `bluetoothctl`, `btmgmt`, `test-runner`) driving 5.72's `bluetoothd`, one pytest session per test (5.72 cannot pair twice in reused guests).

### Not known, not claimed

- Whether CO-37's three mails apply and pass **without** CO-23's two. Not yet checked. The stacked mail 5 does not apply without CO-23's mail 2 (test file context). The earlier unstacked CO-37 series on master 14bd6ab65 did apply and passed the numbers above.
- Behaviour on real hardware. Everything ran on emulated controllers. The laptop crash was not reproduced on hardware.
- The ending of defect A where the Abort cannot be sent after the Close was cancelled (covered by reading only). A setup shared with another pending request when the Close is cancelled (not constructed; the fix leaves that behaviour as it was).
- Whether a build without sanitizers survives the CO-23 case. A run meant as a no-sanitizer control also reported the use-after-free, because `bootstrap-configure` enables the sanitizers itself.
- That the Ubuntu 5.72 package, built with these patches, behaves like the source builds above. No Ubuntu package was built with the CO-37 patches.
- That nothing else is wrong in the exit path. Both fixes keep calling `Release()` to the endpoint's client; see open point (a).
- Whether Ubuntu's 26.04, 26.10 and 27.04 packages carry the same path ordering, 7482aceece70 or 7e3212fa233e. Not checked. 7482aceece70 is dated after the 5.87 tag, so no release contains it.
- Everything about non-root reachability above is from reading source. Nothing was run as an ordinary user.
- The ASan runs used root in the guests and a stopped, resumed or killed peer. They show memory behaviour, not effects outside the daemon.

### Open points and questions for the reviewer

**Open points to state.**

(a) **MediaEndpoint1.Release is sent twice.** The settling runs (adapter removed with no transport) show that unmodified master already sends `MediaEndpoint1.Release` twice to an endpoint registered through `RegisterEndpoint` and once to an application endpoint. With CO-37's two fixes both kinds get it twice (3/3 runs each). The inferred cause is the reordered `path_free()`, with the nested `release_endpoint()` through the SEP destroy callback (`media.c:671`, then `:674` -> `a2dp.c:3064` -> `:2893` -> `media.c:806` -> `:671`; **[inferred from source, the counts are measured]**). **Resolved 2026-11-02, by a separate patch.** Cause **[source]**: `release_endpoint()` (`media.c:651-675`) is the only sender of `MediaEndpoint1.Release`. It sends Release, then `media_endpoint_remove()` -> `a2dp_remove_sep()` -> `a2dp_unregister_sep()` -> the SEP's destroy callback `a2dp_destroy_endpoint()` (`media.c:801-806`) -> `release_endpoint()` again, with the watch still set: a second Release. On master `path_free()` takes this double path only for `RegisterEndpoint` endpoints, because applications are freed first; fix 2's reorder sends application endpoints down it too. The path dates from `bd3ca4fdf463` ("Fix possible invalid read/free on media.c", 2011; inferred from that commit's source, not run on 2011 code). 5.72 has the same structure.

The fix is a `released` flag in `struct media_endpoint`: `release_endpoint()` skips the clear and the Release once it is set. It is placed as its own patch before fix 2 (fixes 1 and 2 keep their patch-ids), so the series becomes six mails: CO-23 fix, CO-23 test, fix 1, **this patch**, fix 2, and the test mail, which now also counts Releases (`test_a2dp_release_on_exit[app|endpoint]`). A folded variant (fix 2 with the flag, both `Fixes:` tags) gives an identical end state. Dropping the disconnect watch after Release was not chosen: it would stop U26's later client-exit path from reaching the endpoint (inferred, not run).

The new patch is mail 4 of 6 above; the test mail in its final form is mail 6 of 6.

Results **[measured]** (ASan and UBSan builds, QEMU guests). Releases received per endpoint, on adapter removal / on SIGTERM:

| tree | RegisterEndpoint | RegisterApplication | Unregister (control) |
|---|---|---|---|
| master | 2 / 2 | 1 / 1 | 1 |
| master + the five earlier mails | 2 / 2 | 2 / 2 | 1 |
| master + the six final mails | 1 / 1 | 1 / 1 | 1 |
| 5.72 | 2 / 2 | 1 / 1 | 1 |
| 5.72 + backport | 2 / 2 | 2 / 2 | 1 |
| 5.72 + backport + the flag | 1 / 1 | 1 / 1 | 1 |

- Six final mails: the CO-37 tests 0 of 10 failing, the Release-count test 0 of 10, CO-23's test 0 of 5. U25 and U26 unchanged (3 of 3 each, same signatures). `make check` unchanged. With leak checking on, 8 of 8 cases clean.
- The CI bot's checks, run locally on the six mails: every check passes on both sides; TestFunctional 48 on base, 53 with the series (the five new tests).
- Without CO-23: fixes 1 and 2 apply on master alone; the stacked test mail does not (it needs CO-23's test file), the original unstacked test does, and the CO-37 tests then fail 0 of 10, also with the Release fix.
- Message points still to fix before sending: fix 2's AddressSanitizer trace skips frame #6; the 5.72 backport's first patch cites fix 1's old title.
- **Found on the way, 5.72 only, not fixed:** an endpoint removed while another client holds its transport, then the stream goes idle (peer disconnect, or the power-off on SIGTERM): heap-use-after-free in `clear_endpoint` (`media.c:300`), 2 of 2 and 3 of 3 runs on 5.72, 5.72 + backport, and with the flag. Master leaks in that case instead of crashing. The 5.72 backport does not cover this path.

(b) **Dependence on CO-23.** Not yet checked whether CO-37's three mails apply and pass without CO-23's two (see "Not known").

(c) **Related defects D and E (U25, U26), not in this series.**
- *D (U25)*: an A2DP endpoint is removed while another bus client holds its transport; that client then calls `Release` on the transport. ASan reports `SEGV profiles/audio/a2dp.c:3566 in a2dp_sep_unlock` (NULL `sep`) while bluetoothd is running. With CO-37's two fixes every run of all four variants (legacy endpoint or application; unregister or client exit) fails (6 or 7 runs each, the same statement at `a2dp.c:3596`). Master alone fails three of four variants (the fourth hits the `media.c:321` read first). On 5.72 `a2dp.c:3254` fails 5/5. **[measured; needs no exit]**
- *E (U26)*: after such a removal, an adapter removal and then the endpoint's client leaving the bus about 1 s later, ASan reports a heap-use-after-free in `a2dp_remove_sep` (`a2dp.c:3042` on master) reading the A2DP server freed by the adapter removal. 10/10 test calls on unmodified master (and on master with CO-37's fixes). **[measured]**
- A timer-based fix (unregister the removed SEP from a zero timeout) was tried and **rejected**: it keeps E, it never unregisters the SEP in the bus-loss and adapter cases (0/120 in rate runs), and it leaks the endpoint and SEP under LeakSanitizer. An amended timer version has a use-after-free of its own (`sep_removed`, `a2dp.c:657`, 3 of 240 test calls).
- Clearing the endpoint's transports before removing the SEP was clean in every measurement: no sanitizer report, no leak, 200/200 adjacent test calls pass with one assertion relaxed. By design it destroys another client's acquired transport when the endpoint goes, which reverses commit 1636fb014 (2011). That is a **design question for the maintainers**, not part of this series.

(d) **Reporting route.** The choice between the mailing list and BlueZ's private GitHub advisory is the submitter's decision; no assessment is offered here.
- *Route A, linux-bluetooth mailing list, ordinary patch process.* Maintainers see the patches and tests at once.
- *Route B, a draft security advisory in BlueZ's GitHub repository.*
- BlueZ's `SECURITY.md` (added 2026-08-26, commit 79918b87d), as written:

> "Please report all suspected vulnerabilities by filing a draft security advisory at [BlueZ's GitHub security advisories page], containing as many details as possible, including the version affected, and any ways to reproduce or fix the problem."
>
> "Do not report suspected vulnerabilities through public channels, such as the linux-bluetooth mailing-list or GitHub issues, until they have been disclosed as described below."
>
> "BlueZ is maintained by volunteers, and reports are handled on a best effort basis, with no guaranteed response time. If you have not received any acknowledgment after two weeks, please add a comment to the draft advisory rather than escalating to a public channel."
>
> "All security advisories filed through GitHub will be embargoed until either a fix is available in the main BlueZ repository (...), or it has been made public by a third-party."
>
> "Similarly, Denial-of-Service issues will only be considered as security issues if they can be triggered without human intervention, or set up on the BlueZ side, otherwise please report those problems as bugs using the normal process."

The file also has sections on CVE numbering, distribution pre-notification, severity and non-disclosure agreements that are not reproduced here.

**Questions for the reviewer.**

1. *CO-23 shape.* Is "hold a reference plus a callback lookup by id" the right shape, or would you prefer a smaller change (only the reference, which leaves the double free on a failed Abort send; or setting `reconfigure` before the calls)? The alternatives are listed under "The change". Should the failed-Abort-send part be a separate patch from the use-after-free fix?
2. *Test technique.* Is stopping the peer's `bluetoothd` with SIGSTOP through a host plugin acceptable in BlueZ's functional suite? No existing case does it. It is the only deterministic way found to keep a Close unanswered. The plugin resumes the daemon on teardown even if the test fails.
3. *CO-37 fix 1.* Is unlinking from the application before the A2DP early return the preferred place, or should the deferred removal path handle the application pointer (for instance in `a2dp_destroy_endpoint()`)?
4. *CO-37 fix 2.* Is reordering `path_free()` acceptable given open point (a), or is there a preferred way to avoid the second `Release()`?
5. *Second exit test.* Killing the guest's system `dbus-daemon` with SIGKILL and removing the stale socket in the test: acceptable, or is there a cleaner way to make bluetoothd exit without powering off?
6. *Series shape.* One stack of six mails (mail 6 needs mail 2's file context; CO-37's fixes apply and pass without CO-23, measured 2026-11-02) or two series with CO-37 sent after CO-23 lands?
7. *Fixes: target.* Fix 1 carries `Fixes: 7482aceece70`, a commit in no release tag. Is that the right trailer, or should the series cite the release that has the behaviour?
8. *Ubuntu 5.72.* Is it right to carry the endpoint half of 7482aceece70 as a prerequisite in the 5.72 backport (the alternative is to let fix 2 alone through, which is wrong there)? And for Ubuntu's stable-update rule, since 7e3212fa233e and 7482aceece70 are in no release, how should the backport request be framed for the newer releases?
9. *Commit-message rules.* BlueZ's `HACKING` (no `Signed-off-by` lines; 50/72 formatting; header limited to 50 characters; description wrapped at 72 except quoted debug-tool output) and its maintainer guidelines (messages clean, 72 characters per line, verbatim logs exempt). Items in the five messages that may break them:
   - *Subjects* are about 55 to 65 characters (computed by hand), above the 50 of `HACKING` item 5 and within the CI bot's 80.
   - *CO-23 mail 1* names six functions of the call chain (`a2dp_reconfig`, `avdtp_close`, `avdtp_abort`, `cancel_request`, `close_cfm`, `finalize_config`). This is the cause, but it may read as a touched-function list.
   - *CO-23 mail 2*, second paragraph (how the host plugin works) and the clause "made once the link is down, as a connection attempted while it goes down can be refused", describe how the test was built. The clause traces to a flaky earlier test version.
   - *CO-23 mail 1*, last paragraph: it carries two changes (the reference, and the failed-Abort handling) in one message.
   - *CO-37 mail 5* describes what the patch adds (the plugin, two tests), not only why. Its `doc/functional-a2dp.rst` text has an odd re-wrap ("Killing" at a line end).
   - *`Fixes:` lines* in mails 3 and 4 exceed 72 characters (the bot's GitLint exempts `Fixes:`).
   - *Mail 4's code comment* repeats the reasoning of the message.
   - None of the five carries `Signed-off-by`, a gerrit `Change-Id` or any narrative of abandoned attempts that I found.

### Route and next step

- **State.** Six mails and three 5.72 patches written (the Release fix added 2026-11-02, open point a). The CI-bot checks on the six mails pass on both sides. Before sending: the two message fixes named under (a), a fresh CI-bot run on the day of sending.
- **Sending.** The sender is the author, who sends from his own account and adds nothing to the patches (BlueZ takes no `Signed-off-by`). The mails are prepared and checked with a dry run (recipient list) before any send. The route (list or advisory) is the submitter's decision, see open point (d).
- **Ubuntu.** The 5.72 backports (endpoint fix as two patches, adapter-teardown fix as one) could travel with the U12 backport (CO-03) in one package on the submitter's word. No Launchpad bug exists for them yet.

---

## CO-03 — Ubuntu 24.04 BlueZ 5.72 backport of a14d59725 ("Release during pending Acquire disconnects A2DP")

### At a glance

| | |
|---|---|
| Target | Ubuntu 24.04 (noble) `bluez 5.72-0ubuntu5.8` (noble-updates 2026-10-21, noble-security 2026-10-13; newest on 2026-10-31); proposed version `5.72-0ubuntu5.9`. |
| Upstream fix | a14d59725ef3 "transport: don't disconnect A2DP if canceling Acquire() with Release()" (Pauli Virtanen, 2024-11-02), first in BlueZ 5.80. |
| State on 2026-11-02 | Backported as three patches, built, tested in containers and QEMU guests with emulated controllers (trigger lost A2DP 0/70 -> kept 70/70; nothing else changed). Not installed anywhere, not filed. |
| Gate | The submitter's own test on the laptop with the Sennheiser MOMENTUM 4 headset (trigger with an application opening the microphone, then an HCI capture). |
| Asked of the reviewer | (1) Review the three debian patches and the draft SRU text (reproduced below). (2) Answer the open question on the companion 664a5d3785a1. (3) Say what the Ubuntu "later releases first" rule implies here. |

### Background

An application opening the microphone of a Bluetooth headset just as A2DP playback starts makes WirePlumber 0.4.17 (Ubuntu 24.04's session manager, with PipeWire 1.0.5) switch the headset to its hands-free profile. That releases the A2DP transport while bluetoothd's `Acquire` (AVDTP START) is still pending. BlueZ 5.72 turns that `Release()` into an AVDTP ABORT. A headset that answers ABORT loses its A2DP profile connection at once; one that does not (seen with the MOMENTUM 4) loses the whole AVDTP session after the 2 s abort timeout. Nothing reconnects A2DP; only the hands-free profile remains until the headset is reconnected. The pending `Acquire()` is never answered.

Observed on the laptop **[measured]**:
- 2026-10-19 19:33:58, HCI capture: the Abort 42 ms after the Start, the Start accepted, the Abort never answered, the channels closed 2.285 s later, an mSBC eSCO link set up with Success meanwhile.
- 2026-10-31 13:42:16: Abort 87.5 ms after the Start, never answered, A2DP gone at 13:42:18.96 and not back by 14:55.

### Root cause

Ubuntu 5.72-0ubuntu5.8, `profiles/audio/transport.c` **[source]**:

```c
/* release(), lines 745-754 */
	if (owner->pending) {
		const char *member;

		member = dbus_message_get_member(owner->pending->msg);
		/* Cancel Acquire request if that exist */
		if (g_str_equal(member, "Acquire"))
			media_owner_remove(owner);
		else
			return btd_error_in_progress(msg);
	}
```

```c
/* media_owner_remove(), lines 267-275 */
	if (req->id && transport->ops && transport->ops->cancel)
		transport->ops->cancel(transport, req->id);

	owner->pending = NULL;
	if (req->msg)
		dbus_message_unref(req->msg);

	g_free(req);
```

`transport_a2dp_cancel()` (line 487) calls `a2dp_cancel(id)`. In `a2dp.c`, `a2dp_cancel()` frees the setup's callback and, when no callback remains, calls `avdtp_abort(setup->session, setup->stream)` ("aborting setup"). The cancelled `Acquire()` is dropped without a D-Bus reply (`media_owner_remove()` frees the request unanswered; every unmodified run shows `Acquire reply: none`).

The upstream fix's own message: "Release() during pending Acquire() first sends error reply to the Acquire. Then it waits for START to complete, then sends SUSPEND, and after that completes, then it replies."

The daemon log of an occurrence **[measured]**:

```text
media_owner_add() Owner :1.81 Request Acquire
media_owner_remove() Owner :1.81 Request Acquire
a2dp_cancel() aborting setup
cancel_request() Start: Operation canceled (125)
session_cb() Transaction label doesn't match
cancel_request() Abort: Connection timed out (110)
connection_lost() Disconnected from <headset>
profile a2dp-sink state changed: connected -> disconnected (0)
```

### The change

Three patches on top of `5.72-0ubuntu5.8`:

1. **`transport_a2dp_get_stream()` helper** from 3d9900eb754d (Arkadiusz Bokowy). The upstream fix calls it and has it as context in a second hunk. Only the helper and its use in `a2dp_resume_complete()` are taken. The rest of 3d9900eb754d (when the `Delay` property exists, `avdtp_stream_has_delay_reporting()`, the A2DP `get_stream` op) changes D-Bus behaviour and is left out.
2. **a14d59725ef3** itself. Five of six hunks apply with offsets -8 to -48. The `A2DP_OPS` macro hunk was wired by hand: 5.72's macro has no `_set_delay` argument and no A2DP `get_stream` op, so only `transport_a2dp_remove_owner` is wired in as the `remove_owner` op.
3. **664a5d3785a1** "a2dp: don't change setup sep when it is reconfiguring" (Pauli Virtanen), posted one second after a14d59725 in the same series. a14d59725 adds a new caller of `a2dp_suspend()` (`a2dp_cancel_resume_cb()` runs after START completes, and its comment says it can run while a `SetConfiguration()` is reconfiguring). Without 664a5d3785a1 that call would set `setup->sep` and `setup->stream` to the old SEP in the middle of the reconfiguration.

A function-by-function comparison of the result with upstream a14d59725 found every function the fix adds or changes identical (`a2dp_suspend_complete`, `transport_a2dp_suspend`, `a2dp_cancel_resume_cb`, `a2dp_resume_complete`, `transport_a2dp_resume`, `transport_a2dp_cancel`, `transport_a2dp_remove_owner`, `media_owner_remove`, `media_transport_remove_owner`, `acquire`). `release()` differs only by a debug line upstream has. `media_owner_free()` differs by 47da1efdc584 (not taken).

**Companions audited and not taken [source]:**
- aa118e965b02 "a2dp: Don't wait to reconfigure" (Luiz von Dentz, four days later, not in the series): replaces the 500 ms `RECONFIGURE_TIMEOUT` with an idle callback. It is a behaviour change for reconfiguration timing; nothing in a14d59725 depends on it.
- 47da1efdc584 "transport: Unset transport owner before owner free": for BAP broadcast, where `acquire()` sets the owner before resuming. In 5.72 every A2DP path that frees an owner either never set it as the transport's owner or cleared it first.
- 87ad4c66b934 "transport: fix crash when freeing transport": fixes a use-after-free of `remote_endpoint` introduced by c26389c46 (ASHA, after 5.72). 5.72 never frees `remote_endpoint`; the bug does not exist there.

**BT-7.** An earlier five-patch internal build also carried two crash fixes of the project's own (a734b06059cb "adapter: Fix crash on short start discovery reply" and 0bed9886cff3 "a2dp: Fix crash on NULL stream in transport_cb"). They are not in the three-patch candidate: Ubuntu's later series do not carry them either, so the "fixed in later releases first" condition is not met for them.

### The patches, verbatim

The debdiff `5.72-0ubuntu5.8` -> `5.72-0ubuntu5.9` of the three-patch candidate: the changelog entry, the three debian patches with DEP-3 headers, and the `series` change.

```diff
diff -Nru bluez-5.72/debian/changelog bluez-5.72/debian/changelog
--- bluez-5.72/debian/changelog	2026-10-13 10:28:01.000000000 +0000
+++ bluez-5.72/debian/changelog	2026-11-01 09:03:39.000000000 +0000
@@ -1,3 +1,15 @@
+bluez (5.72-0ubuntu5.9) UNRELEASED; urgency=medium
+
+  * Fix A2DP being disconnected when Release() cancels a pending
+    Acquire(); the cancelled Acquire() is now answered with an error.
+    Cherry-picked from upstream (BlueZ 5.80): 3d9900eb754d (helper part
+    only), a14d59725ef3 and 664a5d3785a1, as
+    d/p/transport-Add-transport_a2dp_get_stream-helper.patch,
+    d/p/transport-don-t-disconnect-A2DP-if-canceling-Acquire-with-Release.patch
+    and d/p/a2dp-don-t-change-setup-sep-when-it-is-reconfiguring.patch.
+
+ -- Iaroslav Voitovych  Sun, 01 Nov 2026 09:03:39 +0000
+
 bluez (5.72-0ubuntu5.8) noble-security; urgency=medium
 
   * SECURITY REGRESSION: loading of cached A2DP remote SEPs broken by the
diff -Nru bluez-5.72/debian/patches/a2dp-don-t-change-setup-sep-when-it-is-reconfiguring.patch bluez-5.72/debian/patches/a2dp-don-t-change-setup-sep-when-it-is-reconfiguring.patch
--- bluez-5.72/debian/patches/a2dp-don-t-change-setup-sep-when-it-is-reconfiguring.patch	1970-01-01 00:00:00.000000000 +0000
+++ bluez-5.72/debian/patches/a2dp-don-t-change-setup-sep-when-it-is-reconfiguring.patch	2026-11-01 09:03:39.000000000 +0000
@@ -0,0 +1,49 @@
+From: Pauli Virtanen
+Date: Sat, 2 Nov 2024 22:29:46 +0200
+Subject: a2dp: don't change setup sep when it is reconfiguring
+
+If a2dp_resume/a2dp_suspend are called while setup is being
+reconfigured, they make the reconfiguration use wrong SEP.  This occurs
+if transport Acquire/Release are called while reconfiguration is waiting
+for CLOSE_RSP.
+
+Fix by failing a2dp_resume/suspend early without changing the setup, if
+it is reconfiguring.
+
+Such resume/suspend calls would in any case fail, because
+avdtp_close(stream) has been done, so avdtp_suspend/resume would return
+error.
+
+(backported from commit 664a5d3785a1a57989d236b6fd649321a39451f5)
+
+Origin: upstream, [URL omitted]
+Applied-Upstream: 5.80, commit:664a5d3785a1a57989d236b6fd649321a39451f5
+Last-Update: 2026-11-01
+---
+ profiles/audio/a2dp.c | 6 ++++++
+ 1 file changed, 6 insertions(+)
+
+diff --git a/profiles/audio/a2dp.c b/profiles/audio/a2dp.c
+index 0cb8e61..10b52d6 100644
+--- a/profiles/audio/a2dp.c
++++ b/profiles/audio/a2dp.c
+@@ -3124,6 +3124,9 @@ unsigned int a2dp_resume(struct avdtp *session, struct a2dp_sep *sep,
+ 	cb_data->resume_cb = cb;
+ 	cb_data->user_data = user_data;
+ 
++	if (setup->reconfigure)
++		goto failed;
++
+ 	setup->sep = sep;
+ 	setup->stream = sep->stream;
+ 
+@@ -3182,6 +3185,9 @@ unsigned int a2dp_suspend(struct avdtp *session, struct a2dp_sep *sep,
+ 	cb_data->suspend_cb = cb;
+ 	cb_data->user_data = user_data;
+ 
++	if (setup->reconfigure)
++		goto failed;
++
+ 	setup->sep = sep;
+ 	setup->stream = sep->stream;
+ 
diff -Nru bluez-5.72/debian/patches/series bluez-5.72/debian/patches/series
--- bluez-5.72/debian/patches/series	2026-10-13 10:26:09.000000000 +0000
+++ bluez-5.72/debian/patches/series	2026-11-01 09:03:39.000000000 +0000
@@ -37,3 +37,6 @@
 CVE-2026-80186.patch
 CVE-2026-85218.patch
 regression-a2dp-sep-cache.patch
+transport-Add-transport_a2dp_get_stream-helper.patch
+transport-don-t-disconnect-A2DP-if-canceling-Acquire-with-Release.patch
+a2dp-don-t-change-setup-sep-when-it-is-reconfiguring.patch
diff -Nru bluez-5.72/debian/patches/transport-Add-transport_a2dp_get_stream-helper.patch bluez-5.72/debian/patches/transport-Add-transport_a2dp_get_stream-helper.patch
--- bluez-5.72/debian/patches/transport-Add-transport_a2dp_get_stream-helper.patch	1970-01-01 00:00:00.000000000 +0000
+++ bluez-5.72/debian/patches/transport-Add-transport_a2dp_get_stream-helper.patch	2026-11-01 09:03:39.000000000 +0000
@@ -0,0 +1,63 @@
+From: Arkadiusz Bokowy
+Date: Tue, 8 Oct 2024 22:09:26 +0200
+Subject: transport: Add transport_a2dp_get_stream() helper
+
+Look up the A2DP stream of a transport through a helper that also copes
+with an endpoint that has no SEP, and use it in a2dp_resume_complete().
+
+This is the helper part of upstream commit 3d9900eb754d ("transport:
+Delay existence based on delay reporting capability"), which the A2DP
+Acquire()/Release() fix (upstream commit a14d59725ef3) builds on.
+
+(backported from commit 3d9900eb754d277ef6abf21bed827cdc9e79ddb4)
+[Only the transport_a2dp_get_stream() helper and its use in
+a2dp_resume_complete() are taken. The delay reporting change itself
+(avdtp_stream_has_delay_reporting() in avdtp.c/avdtp.h, the new
+delay_reporting_exists(), and wiring the helper as the A2DP get_stream
+op) is left out: it changes when the Delay property exists, which is
+not part of this fix.]
+
+Origin: backport, [URL omitted]
+Applied-Upstream: 5.79, commit:3d9900eb754d277ef6abf21bed827cdc9e79ddb4
+Last-Update: 2026-11-01
+---
+ profiles/audio/transport.c | 13 +++++++++++--
+ 1 file changed, 11 insertions(+), 2 deletions(-)
+
+diff --git a/profiles/audio/transport.c b/profiles/audio/transport.c
+index a469615..7263c17 100644
+--- a/profiles/audio/transport.c
++++ b/profiles/audio/transport.c
+@@ -368,13 +368,22 @@ static gboolean media_transport_set_fd(struct media_transport *transport,
+ 	return TRUE;
+ }
+ 
++static void *transport_a2dp_get_stream(struct media_transport *transport)
++{
++	struct a2dp_sep *sep = media_endpoint_get_sep(transport->endpoint);
++
++	if (!sep)
++		return NULL;
++
++	return a2dp_sep_get_stream(sep);
++}
++
+ static void a2dp_resume_complete(struct avdtp *session, int err,
+ 							void *user_data)
+ {
+ 	struct media_owner *owner = user_data;
+ 	struct media_request *req = owner->pending;
+ 	struct media_transport *transport = owner->transport;
+-	struct a2dp_sep *sep = media_endpoint_get_sep(transport->endpoint);
+ 	struct avdtp_stream *stream;
+ 	int fd;
+ 	uint16_t imtu, omtu;
+@@ -385,7 +394,7 @@ static void a2dp_resume_complete(struct avdtp *session, int err,
+ 	if (err)
+ 		goto fail;
+ 
+-	stream = a2dp_sep_get_stream(sep);
++	stream = transport_a2dp_get_stream(transport);
+ 	if (stream == NULL)
+ 		goto fail;
+ 
diff -Nru bluez-5.72/debian/patches/transport-don-t-disconnect-A2DP-if-canceling-Acquire-with-Release.patch bluez-5.72/debian/patches/transport-don-t-disconnect-A2DP-if-canceling-Acquire-with-Release.patch
--- bluez-5.72/debian/patches/transport-don-t-disconnect-A2DP-if-canceling-Acquire-with-Release.patch	1970-01-01 00:00:00.000000000 +0000
+++ bluez-5.72/debian/patches/transport-don-t-disconnect-A2DP-if-canceling-Acquire-with-Release.patch	2026-11-01 09:03:39.000000000 +0000
@@ -0,0 +1,279 @@
+From: Pauli Virtanen
+Date: Sat, 2 Nov 2024 22:29:45 +0200
+Subject: transport: don't disconnect A2DP if canceling Acquire() with Release()
+
+User can cancel transport acquire by calling Release() while Acquire()
+is in progress. This calls a2dp_cancel() which sends AVDTP_ABORT_CMD,
+forcing AVDTP state transition to IDLE, and A2DP profile disconnects.
+
+However, Release()/Acquire() should only result to transitions between
+STREAMING/OPEN.  The expected behavior is that either these calls return
+error, or they block until the target state is reached.
+
+Fix by: Release() during pending Acquire() first sends error reply to
+the Acquire. Then it waits for START to complete, then sends SUSPEND,
+and after that completes, then it replies.
+
+This also fixes SetConfiguration() after canceled Acquire(), which
+previously did not work due to AVDTP disconnect. Now it does
+START/SUSPEND -> CLOSE -> reconfigure.
+
+(backported from commit a14d59725ef35d91b8504770046c701d0a2efe07)
+[The A2DP_OPS hunk was applied by hand: in 5.72 the macro has no
+_set_delay argument and no get_stream op for A2DP, so only the
+remove_owner op (transport_a2dp_remove_owner) is wired in; the rest of
+the macro is unchanged. The other hunks apply as they are.]
+
+Origin: backport, [URL omitted]
+Applied-Upstream: 5.80, commit:a14d59725ef35d91b8504770046c701d0a2efe07
+Last-Update: 2026-11-01
+---
+ profiles/audio/transport.c | 159 ++++++++++++++++++++++++++++++++++++---------
+ 1 file changed, 127 insertions(+), 32 deletions(-)
+
+diff --git a/profiles/audio/transport.c b/profiles/audio/transport.c
+index 7263c17..f1ec08d 100644
+--- a/profiles/audio/transport.c
++++ b/profiles/audio/transport.c
+@@ -80,6 +80,9 @@ struct a2dp_transport {
+ 	uint16_t		delay;
+ 	int8_t			volume;
+ 	guint			watch;
++	guint			resume_id;
++	gboolean		cancel_resume;
++	guint			cancel_id;
+ };
+ 
+ struct bap_transport {
+@@ -378,22 +381,110 @@ static void *transport_a2dp_get_stream(struct media_transport *transport)
+ 	return a2dp_sep_get_stream(sep);
+ }
+ 
++static void a2dp_suspend_complete(struct avdtp *session, int err,
++							void *user_data)
++{
++	struct media_owner *owner = user_data;
++	struct media_transport *transport = owner->transport;
++	struct a2dp_transport *a2dp = transport->data;
++	struct a2dp_sep *sep = media_endpoint_get_sep(transport->endpoint);
++
++	/* Release always succeeds */
++	if (owner->pending) {
++		owner->pending->id = 0;
++		media_request_reply(owner->pending, 0);
++		media_owner_remove(owner);
++	}
++
++	a2dp_sep_unlock(sep, a2dp->session);
++	transport_set_state(transport, TRANSPORT_STATE_IDLE);
++	media_transport_remove_owner(transport);
++}
++
++static guint transport_a2dp_suspend(struct media_transport *transport,
++						struct media_owner *owner)
++{
++	struct a2dp_transport *a2dp = transport->data;
++	struct media_endpoint *endpoint = transport->endpoint;
++	struct a2dp_sep *sep = media_endpoint_get_sep(endpoint);
++
++	if (owner != NULL) {
++		if (a2dp->resume_id) {
++			a2dp->cancel_resume = TRUE;
++			return a2dp->resume_id;
++		}
++
++		return a2dp_suspend(a2dp->session, sep, a2dp_suspend_complete,
++									owner);
++	}
++
++	transport_set_state(transport, TRANSPORT_STATE_IDLE);
++	a2dp_sep_unlock(sep, a2dp->session);
++
++	return 0;
++}
++
++static gboolean a2dp_cancel_resume_cb(void *user_data)
++{
++	struct media_owner *owner = user_data;
++	struct media_transport *transport = owner->transport;
++	struct a2dp_transport *a2dp = transport->data;
++	guint id;
++
++	a2dp->cancel_id = 0;
++
++	if (!owner->pending)
++		goto fail;
++
++	owner->pending->id = 0;
++
++	/* The suspend fails e.g. if stream was closed/aborted. This happens if
++	 * SetConfiguration() was called while we were waiting for the START to
++	 * complete.
++	 *
++	 * We bail out from the Release() with error in that case.
++	 */
++	id = transport_a2dp_suspend(transport, owner);
++	if (id)
++		owner->pending->id = id;
++	else
++		goto fail;
++
++	return FALSE;
++
++fail:
++	media_transport_remove_owner(transport);
++	return FALSE;
++}
++
+ static void a2dp_resume_complete(struct avdtp *session, int err,
+ 							void *user_data)
+ {
+ 	struct media_owner *owner = user_data;
+ 	struct media_request *req = owner->pending;
+ 	struct media_transport *transport = owner->transport;
++	struct a2dp_transport *a2dp = transport->data;
+ 	struct avdtp_stream *stream;
+ 	int fd;
+ 	uint16_t imtu, omtu;
+ 	gboolean ret;
+ 
++	a2dp->resume_id = 0;
++
++	if (!req)
++		goto fail;
++
+ 	req->id = 0;
+ 
+ 	if (err)
+ 		goto fail;
+ 
++	if (a2dp->cancel_resume) {
++		DBG("cancel resume");
++		a2dp->cancel_id = g_idle_add(a2dp_cancel_resume_cb, owner);
++		return;
++	}
++
+ 	stream = transport_a2dp_get_stream(transport);
+ 	if (stream == NULL)
+ 		goto fail;
+@@ -430,15 +521,20 @@ static guint transport_a2dp_resume(struct media_transport *transport,
+ 	struct a2dp_sep *sep = media_endpoint_get_sep(endpoint);
+ 	guint id;
+ 
++	if (a2dp->resume_id || a2dp->cancel_id)
++		return 0;
++
+ 	if (a2dp->session == NULL) {
+ 		a2dp->session = a2dp_avdtp_get(transport->device);
+ 		if (a2dp->session == NULL)
+ 			return 0;
+ 	}
+ 
+-	if (state_in_use(transport->state))
+-		return a2dp_resume(a2dp->session, sep, a2dp_resume_complete,
++	if (state_in_use(transport->state)) {
++		id = a2dp_resume(a2dp->session, sep, a2dp_resume_complete,
+ 									owner);
++		goto done;
++	}
+ 
+ 	if (a2dp_sep_lock(sep, a2dp->session) == FALSE)
+ 		return 0;
+@@ -453,49 +549,45 @@ static guint transport_a2dp_resume(struct media_transport *transport,
+ 	if (transport->state == TRANSPORT_STATE_IDLE)
+ 		transport_set_state(transport, TRANSPORT_STATE_REQUESTING);
+ 
++done:
++	a2dp->resume_id = id;
++	a2dp->cancel_resume = FALSE;
+ 	return id;
+ }
+ 
+-static void a2dp_suspend_complete(struct avdtp *session, int err,
+-							void *user_data)
++static void transport_a2dp_cancel(struct media_transport *transport, guint id)
+ {
+-	struct media_owner *owner = user_data;
+-	struct media_transport *transport = owner->transport;
+ 	struct a2dp_transport *a2dp = transport->data;
+-	struct a2dp_sep *sep = media_endpoint_get_sep(transport->endpoint);
+ 
+-	/* Release always succeeds */
+-	if (owner->pending) {
+-		owner->pending->id = 0;
+-		media_request_reply(owner->pending, 0);
+-		media_owner_remove(owner);
++	/* a2dp_cancel() results to ABORT->IDLE->disconnect. For START we
++	 * instead wait the operation out.
++	 */
++	if (id == a2dp->resume_id) {
++		a2dp->cancel_resume = TRUE;
++		return;
+ 	}
+ 
+-	a2dp_sep_unlock(sep, a2dp->session);
+-	transport_set_state(transport, TRANSPORT_STATE_IDLE);
+-	media_transport_remove_owner(transport);
++	a2dp_cancel(id);
+ }
+ 
+-static guint transport_a2dp_suspend(struct media_transport *transport,
+-						struct media_owner *owner)
++static void transport_a2dp_remove_owner(struct media_transport *transport,
++					struct media_owner *owner)
+ {
+ 	struct a2dp_transport *a2dp = transport->data;
+-	struct media_endpoint *endpoint = transport->endpoint;
+-	struct a2dp_sep *sep = media_endpoint_get_sep(endpoint);
+ 
+-	if (owner != NULL)
+-		return a2dp_suspend(a2dp->session, sep, a2dp_suspend_complete,
+-									owner);
++	/* Cancel any pending operations for the owner */
+ 
+-	transport_set_state(transport, TRANSPORT_STATE_IDLE);
+-	a2dp_sep_unlock(sep, a2dp->session);
++	if (a2dp->cancel_id) {
++		g_source_remove(a2dp->cancel_id);
++		a2dp->cancel_id = 0;
++	}
+ 
+-	return 0;
+-}
++	if (a2dp->resume_id) {
++		a2dp_cancel(a2dp->resume_id);
++		a2dp->resume_id = 0;
++	}
+ 
+-static void transport_a2dp_cancel(struct media_transport *transport, guint id)
+-{
+-	a2dp_cancel(id);
++	a2dp->cancel_resume = FALSE;
+ }
+ 
+ static int8_t transport_a2dp_get_volume(struct media_transport *transport)
+@@ -756,10 +848,12 @@ static DBusMessage *release(DBusConnection *conn, DBusMessage *msg,
+ 
+ 		member = dbus_message_get_member(owner->pending->msg);
+ 		/* Cancel Acquire request if that exist */
+-		if (g_str_equal(member, "Acquire"))
++		if (g_str_equal(member, "Acquire")) {
++			media_request_reply(owner->pending, ECANCELED);
+ 			media_owner_remove(owner);
+-		else
++		} else {
+ 			return btd_error_in_progress(msg);
++		}
+ 	}
+ 
+ 	transport_set_state(transport, TRANSPORT_STATE_SUSPENDING);
+@@ -1737,7 +1831,8 @@ static void *transport_bap_init(struct media_transport *transport, void *stream)
+ }
+ 
+ #define A2DP_OPS(_uuid, _init, _set_volume, _destroy) \
+-	TRANSPORT_OPS(_uuid, transport_a2dp_properties, NULL, NULL, _init, \
++	TRANSPORT_OPS(_uuid, transport_a2dp_properties, NULL, \
++			transport_a2dp_remove_owner, _init,	      \
+ 			transport_a2dp_resume, transport_a2dp_suspend, \
+ 			transport_a2dp_cancel, NULL, NULL, \
+ 			transport_a2dp_get_volume, _set_volume, \
```

### Tests and results

The test plan was written first, with each test classed **leak** (fails on unmodified 5.72, must pass with the backport), **keep** (passes on 5.72, must still pass) or **record** (outcome noted on both). It ran on the unmodified package first, then the same unchanged test files ran on the backport. V0 = `5.72-0ubuntu5.8`; V2 = V0 + the earlier five-patch build (BT-7 fixes, helper, a14d59725ef3, 664a5d3785a1). The three-patch candidate differs from V2 only by the BT-7 lines.

**Layers.**
- **L0** package build (`dpkg-buildpackage -b`), compiler warnings, `make check`, ASan/UBSan `make check`.
- **L1** BlueZ's unit tests, plus a harness that includes `transport.c` into a test program with A2DP/AVDTP/gdbus stubbed (35 tests, virtual time).
- **L2** two QEMU/KVM guests (pytest-bluezenv 0.1.9, btvirt; guest userspace Ubuntu 24.04), host0 = bluetoothd under test with a D-Bus media client, host1 = the remote with a test fixture (START answered late, ABORT never answered, and similar).
- **L3** PipeWire master and WirePlumber driving the transport as on the desktop, in a Fedora 44 guest with the same BlueZ trees built there.

**Results [measured].**

| Layer | V0 (unmodified) | V2 | Changed outcomes |
|---|---|---|---|
| L0 package build, warnings, `make check` | builds; 2 compiler warnings; 30/32 unit tests (test-vcp and test-mesh-crypto fail) | identical | none |
| L0 ASan/UBSan `make check` | 25/25 | 25/25 | none |
| L1 harness (35 tests) | 27 pass, 8 fail | 35 pass | the 8 leak tests only |
| L2 (31 tests, once) | 17 pass, 14 fail (one by a test bug, corrected, then pass) | 31 pass | the 13 leak tests only |
| L2 trigger rates (7 variants, ten runs each) | 0/70 pass (A2DP lost 70/70) | 70/70 pass | all leak |
| L3 PipeWire's own VM tests (7) | 4 pass, 3 BAP fail | same 4 pass, same 3 fail | none |
| L3 ours (profile switch during START, 11 runs; WirePlumber autoswitch) | 0/11; autoswitch fails | 11/11; autoswitch passes | the leak tests |

The trigger, ten runs per variant (remote answering ABORT or never answering, same turn or +87 ms, plain remote, START-at-once remote, roles swapped):
- Unmodified: `Acquire` never answered (10/10 per variant), one ABORT per run, A2DP lost 70/70, no later `Acquire` possible. Loss times after the Acquire: 1790 to 2826 ms with a remote that never answers ABORT (the 2 s timeout); 4.9 to 6.5 ms, or 92 to 97 ms for the +87 ms variant, with a remote that answers ABORT. So the defect is **not** limited to headsets that ignore ABORT.
- Backport: `Acquire` answered `org.bluez.Error.Failed` (70/70), ABORT 0, A2DP lost 0/70, a later `Acquire` and media 70/70, no sanitizer report.
- No other test changed outcome. Two "record" tests changed only in timing (a START never answered: the backport waits it out).

**Failure paths that do not change (both builds alike).** The owner process exiting while its `Acquire` is pending, or while its `Release` waits, still sends ABORT and loses A2DP with a silent remote. `transport_a2dp_remove_owner()` calls `a2dp_cancel(resume_id)`, as upstream does. Only `Release()` is fixed, not a client crash. A remote that never answers START: AVDTP's own 6 s request timeout aborts.

**Companion test (664a5d3785a1).** Host0 has two SBC source endpoints. During a pending START it calls `Release()` and 50 ms later `SetConfiguration()` for the other endpoint with a different configuration. Idle control 5/5 on both builds. Without 664a5d3785a1 the stream ends on the **old** endpoint with the new configuration in 5/5 runs, with one `a2dp_suspend() avdtp_suspend failed` per run. With it, 5/5 end on the requested endpoint.

**Three-patch candidate checks.**
- Each commit's patch-id equals the prepared one; `quilt push -a --fuzz=0` is clean; the patched source is identical to the git tree outside `debian/`.
- `dpkg-buildpackage -b` exit 0; `make check` 30/32 with the same list as unmodified; no new warnings.
- L2 on its ASan build: ten runs each, 70/70, all other cases as on V2, no sanitizer line.
- The binary packages were installed in QEMU guests with Noble's own PipeWire 1.0.5-1ubuntu3.3 and WirePlumber 0.4.17-1ubuntu4.1 (the running `bluetoothd` is the packaged file, md5 checked against dpkg). D-Bus client trigger: candidate 3/3 pass, stock 3/3 fail (ABORT, A2DP lost at 1932 to 2468 ms). With Noble's PipeWire/WirePlumber and the profile set to "off" during START: candidate 3/3 A2DP kept (226 to 227 packets at the remote), stock 3/3 lost (ABORT, at 2932 to 3974 ms).
- A runner defect was found and fixed along the way: the unit-harness runner exited 0 on failures; it now has a verifying mode, proven on 20 stub scenarios with 0 wrong, and a negative control (base judged against "fixed") fails as it should.

**Sanitizer reports seen at bluetoothd exit in this work** (Fedora 44 builds; Ubuntu-built ASan binaries reported nothing in any run) are the two exit defects of CO-37 above (`media.c:300 in clear_endpoint`, `device.c:6167 in device_set_rssi_with_delta`). They occur on unmodified 5.72 too and are in code this backport does not change.

### Not known, not claimed

- **Not tested on the real headset.** The MOMENTUM 4 is modelled by its timing (START accepted after about 200 ms, ABORT never answered). The `.deb` was built and its `make check` run but was not installed on any real machine. The L2 and L3 VM tests ran the same source built with ASan/UBSan; the installed-package guests used emulated controllers.
- WirePlumber 0.4.17's switch was exercised in guests only as "profile set to off" (the fixture offers no HFP), not as a real hands-free switch.
- The L3 tests used PipeWire and WirePlumber master in Fedora 44 guests, not the laptop's PipeWire 1.0.5/WirePlumber 0.4.17 (the installed-package runs used Noble's own versions).
- Launchpad bug 2056196 (noble, New) describes the headset switching A2DP to HSP for a call on another device and then disconnecting; its syslog has no debug lines and no Acquire/Release/abort trace. It neither shows nor rules out this defect.
- That the later Ubuntu series carry what they should: checked by code markers only (27.04 `tenacious` 5.87-4, with 5.87-5 in -proposed; 26.10 `stonking` 5.87-4; 26.04 `resolute` 5.85-4ubuntu0.4). All carry a14d59725 and 664a5d3785a1 (both in 5.80); none carries the BT-7 fixes.

### Open points and questions for the reviewer

1. **Is 664a5d3785a1 right to take?** For it: it is part of the same upstream series (posted one second apart); a14d59725 adds a caller (`a2dp_cancel_resume_cb()` -> `a2dp_suspend()`) that its comment says can run during a `SetConfiguration()`; measured 5/5 wrong endpoint without it and 5/5 right with it. Against: it is a separate upstream commit with its own rationale; Ubuntu's rule wants the smallest change, and the wrong-endpoint case needs a rarely used sequence (Release, then an endpoint switch inside the START window). Would a sponsor rather see it as a separate patch in the same upload, or dropped?
2. **Partial backport of 3d9900eb754d.** Only the helper is taken, because a14d59725 needs it as context and calls it. Is a hand-split of an upstream commit acceptable under Ubuntu's rules, given that the debian patch says exactly what was taken?
3. **The hand-wired `A2DP_OPS` hunk** (only `transport_a2dp_remove_owner` is wired). Is the explanation in the patch header sufficient?
4. **Packaging baseline shared with CO-11a.** Both this debdiff and the btmon debdiff (next item) change `5.72-0ubuntu5.8` into `5.72-0ubuntu5.9`. They need one shared baseline: either one of them built on the other's pending changes, or both in one upload. See CO-11a.
5. **BT-7 crash fixes** are not in the candidate (later releases do not carry them). Is that the right call, or should they travel separately?
6. **SRU text.** The draft below lacks `[Impact]`, `[Test Plan]` executable without this project's harness (a short python3-dbus script calling `Acquire()` then `Release()` in the same main-loop turn was proposed by an outside reviewer), `[Where problems could occur]` and `[Other Info]`. Are there points the sponsor wants in them?

### Route and next step

1. The submitter installs the build on the laptop and repeats the trigger with the MOMENTUM 4 headset: an application opening the microphone as A2DP playback starts. Expected: START, then SUSPEND, no ABORT, and A2DP still offered; with an HCI capture kept. This is the gate.
2. Then the Launchpad bug is filed (draft below) with the three patches, on the submitter's word. Not filed yet.
3. The 5.72 backports of CO-37 (endpoint fix, adapter-teardown fix) could ride in the same upload; and the packaging baseline is shared with CO-11a.

**Draft Launchpad bug text** (verbatim except that the sentence naming two repository paths now says "the three patches above"):

```text
Title: bluez: Release() during a pending A2DP Acquire() aborts the
stream and disconnects A2DP

Package: bluez 5.72-0ubuntu5.8 (Ubuntu 24.04)

When an application opens the microphone of a Bluetooth headset just as
A2DP playback starts, WirePlumber switches the headset to its hands-free
profile and releases the A2DP transport while bluetoothd's Acquire (AVDTP
START) is still pending. BlueZ 5.72 turns that Release() into an AVDTP
ABORT. A headset that answers ABORT loses its A2DP profile connection
immediately; a headset that does not answer it (seen with a Sennheiser
MOMENTUM 4) loses the whole AVDTP session after the 2 s abort timeout.
Nothing reconnects A2DP; only the hands-free profile remains until the
headset is reconnected. The pending Acquire() is also never answered.

bluetoothd log of an occurrence:

    media_owner_add() Owner :1.81 Request Acquire
    media_owner_remove() Owner :1.81 Request Acquire
    a2dp_cancel() aborting setup
    cancel_request() Start: Operation canceled (125)
    session_cb() Transaction label doesn't match
    cancel_request() Abort: Connection timed out (110)
    connection_lost() Disconnected from <headset>
    profile a2dp-sink state changed: connected -> disconnected (0)

Fixed upstream by commit a14d59725ef3 ("transport: don't disconnect A2DP
if canceling Acquire() with Release()", BlueZ 5.80): the Acquire() is
answered with an error, START is waited out and followed by SUSPEND.

Attached patches (DEP-3), on top of 5.72-0ubuntu5.8 (the three patches above,
and the debdiff 5.72-0ubuntu5.8 to 5.72-0ubuntu5.9):
- the transport_a2dp_get_stream() helper from 3d9900eb754d, which the fix
  calls (corrected 2026-11-01: this said "context only")
- a14d59725ef3 (the A2DP_OPS hunk adapted to 5.72)
- 664a5d3785a1 ("a2dp: don't change setup sep when it is reconfiguring",
  same upstream series): without it, a reconfiguration to another endpoint
  made while the cancelled START is pending ends on the old endpoint

Tests (corrected 2026-11-01 to the three-patch package; the earlier text
quoted the five-patch internal build):
- emulated controllers in QEMU, the candidate's source built with
  ASan/UBSan: Release() during a pending Acquire() against remotes that
  answer ABORT and that never do, ten runs each: A2DP kept 70/70 and a new
  Acquire() with audio works 70/70 (stock 5.72: lost 70/70); the other
  Acquire()/Release() orderings unchanged; no sanitizer report;
- the endpoint switch during the cancelled START: correct endpoint 5/5 with
  the third patch, wrong endpoint 5/5 without it;
- the binary packages installed in QEMU guests with Ubuntu 24.04's own
  PipeWire 1.0.5 and WirePlumber 0.4.17, the profile set to "off" during
  START: A2DP kept 3/3 (stock package: lost 3/3);
- dpkg-buildpackage; `make check` results identical to 5.72-0ubuntu5.8.

Still to write before filing (Ubuntu's SRU template): [ Impact ],
[ Test Plan ] executable without this project's harness (a short
python3-dbus script that calls Acquire() then Release() in the same
main-loop turn was proposed by an outside reviewer), [ Where problems
could occur ], [ Other Info ] (the fix is in 5.80 and therefore in every
supported release after 24.04; checked 2026-11-01: 25.04+ series carry
5.85/5.87).
```

---

## CO-11a — Ubuntu 24.04 btmon aborts with "buffer overflow detected"

### At a glance

| | |
|---|---|
| Target | Ubuntu 24.04 (noble) `bluez 5.72-0ubuntu5.8` -> `5.72-0ubuntu5.9`, package `btmon` (BlueZ's HCI monitor). |
| Upstream fixes | fdbfe0018f6f "monitor: Fix crash due to negative max_len" (Luiz Augusto von Dentz, 2025-02-18, first in BlueZ 5.80) and dca0f10fd560 "monitor: clamp max_len in print_packet" (Chad Spensky, authored 2026-08-14, committed 2026-09-10, in no release tag; reported upstream as issue 1104). |
| State on 2026-11-02 | Debdiff and Launchpad report drafted. Built and tested in a 24.04 container on replayed captures, and live on the monitor socket of a QEMU guest (852 live runs). Not filed. |
| Recommendation | One 24.04 update with both fixes, settled by the live measurements. A first-fix-only update is a fallback only, and its text must name 60 columns, and `-T` at 80 columns and piped, as still aborting. |
| Asked of the reviewer | (1) Is one update with both fixes right under Ubuntu's stable-update rules? (2) How to sequence the uploads of the second fix (27.04, 26.10, 26.04, then 24.04)? (3) How to share one packaging baseline with CO-03? |

### Background

`btmon` in Ubuntu 24.04's BlueZ 5.72 is built with `_FORTIFY_SOURCE=3` (`-D_FORTIFY_SOURCE=3` in the package's build log). Its `print_packet()` (`monitor/packet.c`) derives the `snprintf()` bound for the packet text from the terminal width, minus the length of the label, an optional extra text and the timestamp. When that width comes out negative, `snprintf(line + pos, max_len + 1, ...)` is called with a size that underflows, and the fortified `snprintf` aborts: "*** buffer overflow detected ***: terminated", SIGABRT, exit 134, with no output. The project's laptop saw its own `btmon` abort 13 times between 2026-10-23 and 2026-10-28 (`coredumpctl`), which is what reopened this item.

When `btmon` is not writing to a terminal it cuts lines at 80 columns, so scripts that pipe `btmon` output are affected.

### Root cause

From the second upstream commit's message (dca0f10fd560), quoted:

```text
    print_packet() derives the snprintf() bound for the packet text from the
    terminal width and never bounds it against the space left in line[]:

            char line[LINE_MAX], ts_str[96], pid_str[140];
            int col = num_columns();
            ...
            int max_len = col - len - extra_len - ts_len - 3;

            if (max_len <= 0) {
                    extra = NULL;
                    max_len = col - len - ts_len - 3;
            }

            n = snprintf(line + pos, max_len + 1, "%s%s",
                                            label ? ": " : "", text);

    max_len can leave range in both directions, and either aborts under
    _FORTIFY_SOURCE with "*** buffer overflow detected ***: terminated":

     - The existing max_len <= 0 recovery drops extra and recomputes, but if
       the prefix alone exceeds the column budget the result is still
       negative, and max_len + 1 then underflows when converted to size_t.
       len includes the "comm[pid]: " prefix built from struct ucred, which
       is only present when reading from the monitor socket, so this is
       reachable at ordinary widths. On a host with a large kernel.pid_max
       the pid is 7 digits, so a long process name plus a long label is
       enough and btmon dies mid-capture. Replaying the same traffic from a
       btsnoop file never reproduces it, because there is no ucred and hence
       no prefix.

     - col larger than sizeof(line) makes max_len + 1 exceed the remaining
       buffer. LINE_MAX raised the bar but did not remove it.

    A negative max_len is also used to index line[] when truncating the
    text, writing before the start of the buffer, so this is an
    out-of-bounds write and not only an abort.
```

The first fix (fdbfe0018f6f) adds the "discard the extra text if there is not enough room" recovery. The second clamps `max_len` to the space remaining in `line[]` and writes the ellipsis only when there is room for it.

**The live-capture case.** When `btmon` reads the monitor socket, each record carries a "comm[pid]: " prefix built from the sender's credentials, which a replayed btsnoop file never has. The live test below measured the consequence: with the first fix alone, live btmon aborts at ordinary widths.

Inferred from 5.72's `print_packet()`:
- The space left is `col - len - ts_len - 3`, where `len` includes "comm[pid]: ".
- The abort comes at -2 or less, which is consistent with every cell measured.
- The prefix needs the kernel to pass credentials to the monitor: kernel commit 69ae5065061c5 "Bluetooth: hci_sock: Forward credentials to monitor", first in v6.6-rc1.
- Ubuntu 24.04's systemd sets `kernel.pid_max = 4194304`, so pids reach 7 digits once the counter passes 999999.

### The change

Two upstream commits applied to 5.72 as debian patches, in this order, with DEP-3 headers (see the debdiff). Both apply to the 5.72 tag. The debdiff builds with `dpkg-buildpackage`. The package's `dh_auto_test` is disabled (`debian/rules`: `override_dh_auto_test:` with the body `# disable`), so no unit tests run during the build.

### The patches, verbatim

The debdiff `5.72-0ubuntu5.8` -> `5.72-0ubuntu5.9`: the changelog entry, the two debian patches, the `series` change. The Launchpad bug is the placeholder number XXXXXX.

```diff
diff -Nru bluez-5.72/debian/changelog bluez-5.72/debian/changelog
--- bluez-5.72/debian/changelog	2026-10-13 10:28:01.000000000 +0000
+++ bluez-5.72/debian/changelog	2026-10-28 04:41:58.000000000 +0000
@@ -1,3 +1,14 @@
+bluez (5.72-0ubuntu5.9) noble; urgency=medium
+
+  * btmon: fix abort (buffer overflow detected) in print_packet() when the
+    computed line width is negative (LP: #XXXXXX)
+    - debian/patches/monitor-Fix-crash-due-to-negative-max_len.patch:
+      upstream fdbfe0018f6f, discard the extra text when it does not fit.
+    - debian/patches/monitor-clamp-max_len-in-print_packet.patch:
+      upstream dca0f10fd560, clamp max_len to the space left in line[].
+
+ -- Iaroslav Voitovych  Wed, 28 Oct 2026 04:41:58 +0000
+
 bluez (5.72-0ubuntu5.8) noble-security; urgency=medium
 
   * SECURITY REGRESSION: loading of cached A2DP remote SEPs broken by the
diff -Nru bluez-5.72/debian/patches/monitor-Fix-crash-due-to-negative-max_len.patch bluez-5.72/debian/patches/monitor-Fix-crash-due-to-negative-max_len.patch
--- bluez-5.72/debian/patches/monitor-Fix-crash-due-to-negative-max_len.patch	1970-01-01 00:00:00.000000000 +0000
+++ bluez-5.72/debian/patches/monitor-Fix-crash-due-to-negative-max_len.patch	2026-10-28 04:41:58.000000000 +0000
@@ -0,0 +1,30 @@
+Description: monitor: Fix crash due to negative max_len
+ btmon aborts (buffer overflow detected, SIGABRT) in print_packet() when the
+ computed max_len is negative, for example when decoding a MGMT Open record
+ with a long label at 80 columns or fewer. Discard the extra text if there
+ is not enough space for the text and the label.
+Author: Luiz Augusto von Dentz
+Origin: upstream, [URL omitted]
+Bug-Ubuntu: [URL omitted]
+Forwarded: not-needed
+Last-Update: 2026-10-28
+---
+diff --git a/monitor/packet.c b/monitor/packet.c
+index 2eb50896b..b186431cf 100644
+--- a/monitor/packet.c
++++ b/monitor/packet.c
+@@ -490,6 +490,14 @@ static void print_packet(struct timeval *tv, struct ucred *cred, char ident,
+ 		int extra_len = extra ? strlen(extra) : 0;
+ 		int max_len = col - len - extra_len - ts_len - 3;
+ 
++		/* Check if there is enough space for the text and the label, if
++		 * there isn't then discard extra text since it won't fit.
++		 */
++		if (max_len <= 0) {
++			extra = NULL;
++			max_len = col - len - ts_len - 3;
++		}
++
+ 		n = snprintf(line + pos, max_len + 1, "%s%s",
+ 						label ? ": " : "", text);
+ 		if (n > max_len) {
diff -Nru bluez-5.72/debian/patches/monitor-clamp-max_len-in-print_packet.patch bluez-5.72/debian/patches/monitor-clamp-max_len-in-print_packet.patch
--- bluez-5.72/debian/patches/monitor-clamp-max_len-in-print_packet.patch	1970-01-01 00:00:00.000000000 +0000
+++ bluez-5.72/debian/patches/monitor-clamp-max_len-in-print_packet.patch	2026-10-28 04:41:58.000000000 +0000
@@ -0,0 +1,48 @@
+Description: monitor: clamp max_len in print_packet
+ print_packet() derives the snprintf() bound from the terminal width and
+ never bounds it against the space left in line[]. max_len can stay negative
+ after the recovery added by the previous patch, or exceed the buffer. Clamp
+ max_len to the space remaining in line[] and only write the ellipsis when
+ there is room for it.
+Author: Chad Spensky
+Origin: upstream, [URL omitted]
+Bug: [URL omitted]
+Bug-Ubuntu: [URL omitted]
+Forwarded: not-needed
+Last-Update: 2026-10-28
+---
+diff --git a/monitor/packet.c b/monitor/packet.c
+index f0558b656..67837b8f0 100644
+--- a/monitor/packet.c
++++ b/monitor/packet.c
+@@ -605,13 +605,26 @@ static void print_packet(struct timeval *tv, struct ucred *cred, char ident,
+ 			max_len = col - len - ts_len - 3;
+ 		}
+ 
++		/* col comes from the terminal and len includes the optional
++		 * "comm[pid]: " prefix, so max_len can still be negative
++		 * here, or larger than the space left in line[]. Both
++		 * overflow the snprintf below, and a negative value also
++		 * indexes before line[].
++		 */
++		if (max_len > (int) sizeof(line) - pos - 1)
++			max_len = (int) sizeof(line) - pos - 1;
++		if (max_len < 0)
++			max_len = 0;
++
+ 		n = snprintf(line + pos, max_len + 1, "%s%s",
+ 						label ? ": " : "", text);
+ 		if (n > max_len) {
+-			line[pos + max_len - 1] = '.';
+-			line[pos + max_len - 2] = '.';
+-			if (line[pos + max_len - 3] == ' ')
+-				line[pos + max_len - 3] = '.';
++			if (max_len >= 3) {
++				line[pos + max_len - 1] = '.';
++				line[pos + max_len - 2] = '.';
++				if (line[pos + max_len - 3] == ' ')
++					line[pos + max_len - 3] = '.';
++			}
+ 
+ 			n = max_len;
+ 		}
diff -Nru bluez-5.72/debian/patches/series bluez-5.72/debian/patches/series
--- bluez-5.72/debian/patches/series	2026-10-13 10:26:09.000000000 +0000
+++ bluez-5.72/debian/patches/series	2026-10-28 04:41:58.000000000 +0000
@@ -37,3 +37,5 @@
 CVE-2026-80186.patch
 CVE-2026-85218.patch
 regression-a2dp-sep-cache.patch
+monitor-Fix-crash-due-to-negative-max_len.patch
+monitor-clamp-max_len-in-print_packet.patch
```

**Launchpad report draft** (verbatim, with the placeholder bug number XXXXXX kept; the two URLs are replaced by "[URL omitted]" and the two references to result files are replaced, as marked):

```text
Title: [SRU] btmon aborts with "buffer overflow detected" when decoding a record at 80 columns or fewer

Bug: [URL omitted] (placeholder, bug number XXXXXX)
Package: bluez, 5.72-0ubuntu5.8 (noble-updates / noble-security)

[Impact]

btmon from Ubuntu 24.04's bluez 5.72-0ubuntu5.8 aborts with
"*** buffer overflow detected ***: terminated" (SIGABRT, exit 134) and prints nothing,
when it decodes a record whose label makes the width left for the packet text negative
(`max_len` in `print_packet()` in monitor/packet.c). Example: a "MGMT Open: bluetoothctl
(privileged)" record, read with `btmon -r file.btsnoop` when its output is not a terminal
(80 columns) or with `--columns=N`, N <= 80. Because btmon cuts lines at 80 columns when
piped, scripts that pipe btmon output are affected. Ordinary records abort it as well at
narrow widths (60 columns and fewer in our test), and both tested captures abort it at very wide
widths (`--columns=3000`). The second upstream fix names the live case too: the `comm[pid]`
prefix of a live btmon can push `max_len` negative at ordinary widths. The package is built
with _FORTIFY_SOURCE=3, which turns the bad `snprintf()` size into an abort.

Upstream fixes:
- fdbfe0018f6f ("monitor: Fix crash due to negative max_len", first in BlueZ 5.80)
- dca0f10fd560 ("monitor: clamp max_len in print_packet", master)

[Test Plan]

1. On Ubuntu 24.04 with bluez 5.72-0ubuntu5.8, create a capture holding one privileged MGMT
   Open record (a btsnoop file in the monitor format with a "bluetoothctl" privileged
   MGMT Open, as written by `mkcap.py`, attached) and run:

       TZ=UTC btmon --columns=80 -T -r priv-open.btsnoop; echo "exit $?"

   Before: "*** buffer overflow detected ***: terminated", exit 134, no output.
   The same happens at 79 columns and below, and when piped without `--columns`.
2. Install bluez 5.72-0ubuntu5.9 from -proposed and repeat for 10, 40, 60, 79, 80, 81, 82,
   100, 200, 3000 and 5000 columns and piped. After: exit 0 and the records are decoded at
   every width (long text and labels are shortened to fit).
3. Run both captures (`priv-open.btsnoop`, `lines.btsnoop`, attached) before and after at
   every width above, keep the outputs, and compare them byte for byte (`cmp`). Expected,
   as in our run: stock aborts (exit 134) at 3000 and 5000 columns as well, and on
   `lines.btsnoop` at 10, 40 and 60; where both versions run, the outputs are identical
   except the privileged Open label at 81 and 82 columns (`@ MGMT O..n (privileged) version
   1.22` becomes `@ MGMT Open: bluetoothctl`).

Result of this test in a noble container with the stock and the rebuilt package: the exit
codes and the byte-for-byte comparison are given in the results section of the review document
(the draft referred to two result files here).

[Where problems could occur]

The change touches only `print_packet()` in monitor/packet.c, i.e. how btmon formats the
line header and cuts text to the terminal width. A mistake would show as wrongly truncated
or missing text in btmon output, or a crash in btmon. Nothing in bluetoothd, libbluetooth or
the kernel is changed. The output also changes at widths where btmon did not abort: at 81
and 82 columns a long label is shortened differently. In our byte comparison, where both
versions completed, the output matched except for the privileged Open record at 81 and 82
columns. Tools that parse btmon text could see that
different truncation, and decoded lines at widths where btmon used to abort.

[Other Info]

- Affected: Ubuntu 24.04 (noble), bluez 5.72. The first fix is in BlueZ 5.80 and later. The
  second (dca0f10fd, 2026-09-10) is in no BlueZ release yet (5.87 is 2026-07-03), and the
  development release's bluez 5.87-4 (27.04; also 26.10) carries no patch to
  monitor/packet.c (its 19 Debian patches checked 2026-10-28), so the development release
  needs dca0f10fd too; this bug should target it as well.
- Upstream commits: fdbfe0018f6f216ff089c0e1db848ec8ae16585e (5.80),
  dca0f10fd560f8095493021ca2ac20236fde026e (master; upstream issue 1104).
  Both apply to the 5.72 tag in this order.
- The debdiff 5.72-0ubuntu5.8 to 5.72-0ubuntu5.9 adds the two patches with DEP-3 headers and
  a changelog entry; it builds with dpkg-buildpackage. The package's `dh_auto_test` is
  disabled (debian/rules), so no unit tests run during the build.
```

### Tests and results

**Replay in a container [measured].** All in a throw-away `ubuntu:24.04` container with no devices. The source package checksums matched the `.dsc`. The two captures were generated by a small script writing btsnoop files in the monitor format (one with a privileged "bluetoothctl" MGMT Open record, "priv-open", 3 output lines; one with ordinary records, "lines", 41 lines), with a placeholder controller address. Command: `TZ=UTC btmon [--columns=N] -T -r <capture>`; "piped" means no `--columns` and output not a terminal. btmon sha256: stock `0744f98cb0e5173fb9995fe68f4bb38ab633d4ccf90c9d504b677762ac59e5ab`, rebuilt `58d92e1a666531eb26c34fbbffd50ec8bc0639c64c44f6ef1a0a8a8f769b95eb`. The rebuilt package compiled `monitor/packet.c` with `-D_FORTIFY_SOURCE=3`.

Width matrix, exit status per capture, "privileged-Open capture / ordinary-records capture"; 134 is the abort (every 134 has stderr `*** buffer overflow detected ***: terminated`). The first-fix-only column is btmon built three ways in a noble container with the package's flags (the rebuilt stock btmon's output equals the archive binary's at the 10 of 10 widths where both exit 0).

| Terminal width | Stock | First fix only | Both fixes |
|---|---|---|---|
| 10 | 134 / 134 | 134 / 134 | 0 / 0 |
| 60 | 134 / 134 | 0 / 0 | 0 / 0 |
| 80 | 134 / 0 | 0 / 0 | 0 / 0 |
| 81, 82, 100, 250 | 0 / 0 | 0 / 0 | 0 / 0 |
| 3000, 5000 | 134 / 134 | 134 / 134 | 0 / 0 |
| piped | 134 / 0 | 0 / 0 | 0 / 0 |

The rebuilt btmon with both fixes exits 0 at every width tried; stock also aborts on the privileged-Open capture at 40 and 79 columns and on the ordinary capture at 40. Sample output of the rebuilt btmon (placeholder address omitted):

```text
$ btmon --columns=80 -T -r priv-open.btsnoop      (exit 0)
Bluetooth monitor ver 5.72
= New Index: ... (Primary,USB,hci0)  [hci0] 2026-10-17 01:04:57.000000
@ MGMT Open: bluetoothctl            {0x0001} [hci0] 2026-10-17 01:04:57.000100
$ btmon --columns=10 -T -r priv-open.btsnoop      (exit 0)
Bluetooth monitor ver 5.72
= New Index [hci0] 2026-10-17 01:04:57.000000
@ MGMT Open {0x0001} [hci0] 2026-10-17 01:04:57.000100
```

Byte-for-byte comparison of stdout, stock against both fixes: where both exit 0, the output is identical at widths 100 and 200 for the privileged-Open capture and at 79, 80, 81, 82, 100, 200 and piped for the ordinary capture. The two exceptions, both on the privileged-Open capture, where the patch shortens the long label differently:

```text
--- priv-open cols=81
< @ MGMT O..n (privileged) version 1.22  {0x0001} [hci0] 2026-10-17 01:04:57.000100
> @ MGMT Open: bluetoothctl             {0x0001} [hci0] 2026-10-17 01:04:57.000100
--- priv-open cols=82
< @ MGMT Op.. (privileged) version 1.22  {0x0001} [hci0] 2026-10-17 01:04:57.000100
> @ MGMT Open: bluetoothctl              {0x0001} [hci0] 2026-10-17 01:04:57.000100
```

**Replay, extended [measured].** 3 archived captures, options none, `-t`, `-T`, `-i hci0` and `-I`, 800 runs. The first fix alone aborts only at 10 and 3000 columns. Replay never shows the live case.

**Live capture [measured].** 24.04's btmon was rebuilt from `bluez_5.72-0ubuntu5.8` with the package's own flags (`-D_FORTIFY_SOURCE=3 -O2`, gcc 13.3.0-6ubuntu2~24.04.1) in three variants:
- stock;
- stock + fdbfe0018f6f ("first fix only");
- stock + both fixes.

Ubuntu's own btmon was the control: 0 decode differences against rebuilt stock in 132 replay cells.

Each variant ran live on the monitor socket of a QEMU guest:
- test kernel 7.2.0, with one emulated controller (btvirt) on the guest's own vhci;
- `kernel.pid_max` 4194304, with pids set to 7 digits;
- under a pty at 60/80/100/120/200 columns, and piped;
- about 6 s per run, with bluetoothd, btmgmt and hcitool traffic;
- two scenarios: real tool names, and 15-character process names.

Every abort was exit 134 with "*** buffer overflow detected ***: terminated". Counts:
- **First fix only:**
  - aborts 5 of 5 at 60 columns without options (real names and long names);
  - aborts 5 of 5 at 60 with `-t` or `-T`;
  - with `-T` and 15-character names it also aborts 5 of 5 at 80 and piped.
- **Control with 5-digit pids:** the first fix passes at 60 without options and still aborts at 60 with `-T`.
- **Guest clock moved 100000 s forward** (a btmon running about 28 hours):
  - the first fix aborts 3 of 3 at 60, and at 70 with long names;
  - stock aborts 3 of 3 at 80 and piped too.
- **Both fixes:** 0 aborts in 264 live runs (852 live runs over all variants).

### Ubuntu releases

| Release | BlueZ | First fix (fdbfe0018f6f) | Second fix (dca0f10fd560) |
|---|---|---|---|
| 24.04 (target) | 5.72 | no | no |
| 26.04 LTS | 5.85 | yes | no (needs it before 24.04) |
| 26.10 | 5.87 | yes | no (needs it before 24.04) |
| 27.04 (development) | 5.87 | yes | no (first) |

Checked by code markers in the source packages on 2026-11-01: 27.04 `tenacious` 5.87-4 (5.87-5 in -proposed), 26.10 `stonking` 5.87-4 and 26.04 `resolute` 5.85-4ubuntu0.4 carry fdbfe0018f6f and not dca0f10fd560; none of 5.87-4's 19 Debian patches touches `monitor/packet.c` (checked 2026-10-28). dca0f10fd560 is in no BlueZ release tag.

Stable-update ordering: Ubuntu's rule wants a fix in the development release first, and in every newer supported release before an older one gets it. The first fix is in all newer releases. The second fix has to go to 27.04, then 26.10 and 26.04 LTS, before 24.04: three uploads ahead of ours.

Shared baseline with CO-03: both packages change the same source package, so their uploads need one shared packaging baseline (each built on the other's pending changes, or both in one upload). Separate bug reports do not by themselves prevent a collision. The sponsor has to know about both.

### Not known, not claimed

- Live capture was measured only in a QEMU guest with an emulated controller and a 7.2.0 test kernel, with synthetic traffic from bluetoothd, btmgmt and hcitool. Not measured: live capture on real hardware, or on Ubuntu 24.04's own kernel. The credentials prefix depends on kernel 6.6 or later, per the inference above.
- The unit tests of the package are disabled; no unit-test result exists for this package build.
- The output at 81 and 82 columns on the privileged-Open capture changes (label shortened differently); other tools that parse btmon text could see it. Only two captures were compared byte for byte.
- No claim is made about how many users are affected. The update text says it "fixes the tested ordinary-width and piped cases"; it makes no claim about how many users are affected.
- What the second fix means for the out-of-bounds write the upstream message describes is not tested here beyond the aborts above.

### Open points and questions for the reviewer

1. **Both fixes together: settled by measurement.** The first fix alone still aborts live at ordinary widths (60 columns without options with 7-digit pids; `-T` at 80 columns and piped with long process names) and at 10, 3000 and 5000 columns on replay. Both fixes: 0 aborts in 264 live runs. Recommendation: one 24.04 update with both fixes. Ubuntu's rule wants the second fix in 27.04, then 26.10 and 26.04 LTS, before 24.04: three uploads ahead of ours. Does the sponsor see a faster acceptable route?
2. **Fallback.** If the full route stalls for weeks, a first-fix-only 24.04 update could go on its own. Its text would have to name 60 columns, and `-T` at 80 columns and piped, as still aborting, besides 10 and 3000/5000 columns.
3. **Shared baseline with CO-03.** Both debdiffs in this document are `5.72-0ubuntu5.8` -> `5.72-0ubuntu5.9` (CO-03's changelog says `UNRELEASED`, this one says `noble`). Which shape does the sponsor prefer: one upload with both, or one built on the other's pending changes?
4. **Targeting.** The report says the bug should target the development release as well. Is that the right way to ask for the second fix to go to 27.04 first?
5. **The 81/82-column label change.** Is an output change at widths where btmon did not abort acceptable in an SRU, given the [Where problems could occur] text?
6. **Launchpad text.** The draft above still describes the live case only through the upstream commit's wording; the live measurements are meant to go into its [Impact] and [Test Plan] before filing.

### Route and next step

1. The live test is done. No local work is required before filing.
2. Prepare the debdiff(s) and Launchpad text(s) with real version numbers, the replay matrix and the live results, decided against the shared baseline with CO-03.
3. Ask for the second fix in 27.04, 26.10 and 26.04 first.
4. File on the submitter's word (Launchpad is the submitter's).

## CO-19 — U1: the Hands-free codec line cannot be shown or changed in Ubuntu 24.04's PipeWire 1.0.5

### At a glance

| | |
|---|---|
| Target | Ubuntu 24.04 (noble) source package `pipewire`, stable-release update from `1.0.5-1ubuntu3.3` to `1.0.5-1ubuntu3.4`. PipeWire upstream is not involved: the fix exists upstream since 1.1.81 / 1.2.0. |
| State on 2026-11-02 | Code and packaging approved by outside reviewers on 2026-10-28 (final round: no blocking finding). Nothing filed, uploaded or sent. Built and unit-tested in an Ubuntu 24.04 container only; never run on a real headset. The Launchpad bug number is a placeholder (`NNNNNNN`) in three places. |
| Gate | A test on the laptop with a Bluetooth headset in Hands-free mode: install the rebuilt package pair, test, keep or roll back. Only then the bug number is obtained and the submitter files. |
| Asked of the reviewer | Is the hand-port of the HFP/HSP part of upstream `805e5cf9c` to 1.0.5 correct and sufficient; are the SRU text and the "where problems could occur" section complete; is the test plan enough; would an Ubuntu SRU reviewer insist on the full upstream series instead. |

### Background

In Hands-free (HSP/HFP) mode, PipeWire 1.0.5 offers a codec-less profile "Headset Head Unit (HSP/HFP)" beside the per-codec profiles "... codec CVSD" and "... codec mSBC" (a CVSD-only headset: the codec-less one and CVSD). GNOME Settings (Sound) lists the profiles; the codec-less one is the first line. It resolves to whichever codec the link happens to use, so on that line the user cannot see which codec is active and cannot choose one. Observed on the laptop on 2026-10-01 (marks: "the first not selectable") and reopened as a functional bug on 2026-10-28. In the A2DP case PipeWire already lists only profiles that name a codec and gives the best one the base name; upstream commit `805e5cf9c` ("bluez5: show only codec profiles also for HFP/HSP", Pauli Virtanen, 2024-01-28, one file, 21 hunks) did the same for HFP/HSP. First tag containing it: 1.1.81; 1.2.0 later. Ubuntu 26.04 (1.6.2), 26.10 and the development release 27.04 (1.6.8-1ubuntu4) contain it (measured: Launchpad query, 2026-10-28). No follow-up, `Fixes:` or revert exists for it up to upstream 1.6.10 (measured: history search of `spa/plugins/bluez5`; 11 later commits touch `bluez5-device.c` up to 1.4.0, none a correction of this change).

### Root cause

From source, PipeWire 1.0.5, `spa/plugins/bluez5/bluez5-device.c`, `build_profile()` (lines 1773 to 1791 of the unpatched file): the HSP_HFP case builds a profile for `codec == 0` as well:

```c
if (codec) {
	...
	name_and_codec = spa_aprintf("%s-%s", name, get_hfp_codec_name(hfp_codec));
	name = name_and_codec;
	desc_and_codec = spa_aprintf(_("Headset Head Unit (HSP/HFP, codec %s)"),
				get_hfp_codec_description(hfp_codec));
	desc = desc_and_codec;
	priority = 1 + hfp_codec;  /* prefer msbc over cvsd */
} else {
	desc = _("Headset Head Unit (HSP/HFP)");
	priority = 1;
}
```

The `else` branch is the codec-less profile (priority 1, lowest, but listed first by the desktop). Measured: the string `Headset Head Unit (HSP/HFP)` is present in the stock 1.0.5-1ubuntu3.3 plugin binary and absent from the rebuilt one.

A second fact matters for the port. In 1.0.5 the native backend's HSP branch creates its transport without setting `t->codec` (`backend-native.c`, `_transport_create()`, lines 202 to 235; `spa_bt_transport_create()` is a `calloc()`, `bluez5-dbus.c:2732`), so `t->codec` is 0, and `get_hfp_codec_id(0)` returns `SPA_ID_INVALID` (`bluez5-device.c:255-264`). Stock 1.0.5 hid this with an HSP special case in `emit_nodes()` (`if (t->profile == SPA_BT_PROFILE_HSP_HS) this->props.codec = 0;`, unpatched lines 1091 to 1094). Upstream `805e5cf9c` removes that special case, and upstream had added the missing initial codec first, in `f142c0a5b` ("bluez5: ensure transport->codec is set also for HSP", same author, committed together on 2024-02-03). `f142c0a5b` is not in 1.0.5 (measured: `git merge-base --is-ancestor f142c0a5b 1.0.5` exits 1). A port of `805e5cf9c` without it would leave an HSP-only headset with an invalid codec in its active profile. This was found by an outside reviewer of version 1 of the port and verified in source.

### The change

Two patches in `debian/patches`, appended to `series`:

1. `bluez5-ensure-transport-codec-is-set-also-for-HSP.patch`: upstream `f142c0a5b`, unchanged (2 lines in `backend-native.c`: `t->codec = HFP_AUDIO_CODEC_CVSD;` in `_transport_create()` and after the HSP transport is created). It applies to 1.0.5 with offsets (hunk 1 at 222, offset -1; hunk 2 at 2232, offset -68).
2. `bluez5-show-only-codec-profiles-also-for-HFP-HSP.patch`: a hand-port of the HFP/HSP part of `805e5cf9c`, one file (`spa/plugins/bluez5/bluez5-device.c`), 42 insertions, 29 deletions.

**Why a hand-port.** The upstream commit does not apply to 1.0.5: `patch --dry-run` fails 7 of 21 hunks (hunks 2, 3, 4, 6, 9, 11, 21; measured). It sits on the BAP rework (`a15416994`), LC3-SWB in HFP (`fe412784a`) and HFP cleanups (`65f594c6a`), none in 1.0.5; the file's history between 1.0.5 and 1.2.0 has seven prerequisite commits (`442a20838 7f2dd3531 eaea03c26 a15416994 70ffbaed7 fe412784a 65f594c6a`, then `805e5cf9c`). Taking them would be a large change for a stable update.

**What the port keeps from upstream** (all in `bluez5-device.c`):
- `build_profile()`, HSP_HFP: codec 0 gives no profile (the codec-less line is gone); CVSD is always listed without asking the backend (on an HSP-only device the native backend answers -ENOTSUP to every codec query, `backend_native_supports_codec`), mSBC only if supported; the best supported codec keeps the base name `headset-head-unit` and the others get `-cvsd`, as A2DP already does.
- `get_index_from_profile()`: HSP_HFP with codec 0 gives `SPA_ID_INVALID`.
- `emit_nodes()`: the HFP codec is taken from the existing transport (no codec filter on the lookup), default CVSD, so the current profile is always a listed one.
- `profiles_changed()`: the reset of the codec to 0 is removed.

**What differs from upstream, and why:**
- Left out: the A2DP/BAP transport-lookup simplification (removal of the codec argument), the `DEVICE_PROFILE_LAST` change, the rewrite of the fallback in `codec_switched()`, and the `set_profile` HFP_AG condition. They depend on the BAP/LC3-SWB commits and are not needed for the HFP/HSP behaviour.
- (a) `emit_nodes()` resets `props.codec` only in the HSP_HFP case.
- (b) The `codec_switched()` failure branch is unchanged from 1.0.5 (harmless: `emit_nodes()` recomputes the codec from the transport that exists afterwards, CVSD if none; a CVSD label with no transport does not mean a CVSD link is active).
- (c) The CVSD exemption from the support check and "mSBC is the top codec" (1.0.5 has no LC3-SWB in HFP).

These three are marked "to be reviewed" for the reviewer.

### The patches, verbatim

The debdiff as it stands (the two patch files are added in full; `series` gains two lines). Edits for this document only: the author's address removed from the `From:` line, the changelog trailer's address removed, and the `Origin:` and `Bug-Ubuntu:` header URLs replaced by the commit id and a plain `LP: #NNNNNNN` (the bug number is a placeholder).

```diff
diff -Nru pipewire-1.0.5/debian/changelog pipewire-1.0.5/debian/changelog
--- pipewire-1.0.5/debian/changelog	2026-07-08 23:47:47.000000000 +0000
+++ pipewire-1.0.5/debian/changelog	2026-10-28 05:46:17.000000000 +0000
@@ -1,3 +1,17 @@
+pipewire (1.0.5-1ubuntu3.4) noble; urgency=medium
+
+  * d/p/bluez5-ensure-transport-codec-is-set-also-for-HSP.patch:
+    Cherry-pick upstream f142c0a5b "bluez5: ensure transport->codec is
+    set also for HSP", so HSP-only headsets report CVSD; needed by the
+    next patch. (LP: #NNNNNNN)
+  * d/p/bluez5-show-only-codec-profiles-also-for-HFP-HSP.patch:
+    Backport of the HFP/HSP part of upstream 805e5cf9c "bluez5: show only
+    codec profiles also for HFP/HSP", adapted for 1.0.5. In Hands-free
+    mode the device no longer offers a codec-less "Headset Head Unit
+    (HSP/HFP)" profile beside the per-codec ones, so the codec can be
+    seen and selected in GNOME Settings. (LP: #NNNNNNN)
+ -- Iaroslav Voitovych  Wed, 28 Oct 2026 05:46:17 +0000
+
 pipewire (1.0.5-1ubuntu3.3) noble-security; urgency=medium
 
   * SECURITY UPDATE: NULL pointer dereference in RAOP module.
diff -Nru pipewire-1.0.5/debian/patches/bluez5-ensure-transport-codec-is-set-also-for-HSP.patch pipewire-1.0.5/debian/patches/bluez5-ensure-transport-codec-is-set-also-for-HSP.patch
--- pipewire-1.0.5/debian/patches/bluez5-ensure-transport-codec-is-set-also-for-HSP.patch	1970-01-01 00:00:00.000000000 +0000
+++ pipewire-1.0.5/debian/patches/bluez5-ensure-transport-codec-is-set-also-for-HSP.patch	2026-10-28 05:46:17.000000000 +0000
@@ -0,0 +1,28 @@
+From: Pauli Virtanen
+Date: Sun, 28 Jan 2024 15:33:27 +0200
+Subject: bluez5: ensure transport->codec is set also for HSP
+Origin: upstream, commit f142c0a5b0286bd8975bb67e57e0f06138e05b17
+Applied-Upstream: 1.1.81
+Bug-Ubuntu: LP: #NNNNNNN
+Last-Update: 2026-10-28
+---
+diff --git a/spa/plugins/bluez5/backend-native.c b/spa/plugins/bluez5/backend-native.c
+index daf97963f..66fcf53e0 100644
+--- a/spa/plugins/bluez5/backend-native.c
++++ b/spa/plugins/bluez5/backend-native.c
+@@ -223,6 +223,7 @@ static struct spa_bt_transport *_transport_create(struct rfcomm *rfcomm)
+ 	t->backend = &backend->this;
+ 	t->n_channels = 1;
+ 	t->channels[0] = SPA_AUDIO_CHANNEL_MONO;
++	t->codec = HFP_AUDIO_CODEC_CVSD;
+ 
+ 	td = t->user_data;
+ 	td->rfcomm = rfcomm;
+@@ -2299,6 +2300,7 @@ static DBusHandlerResult profile_new_connection(DBusConnection *conn, DBusMessag
+ 			spa_log_warn(backend->log, "can't create transport: %m");
+ 			goto fail_need_memory;
+ 		}
++		t->codec = HFP_AUDIO_CODEC_CVSD;
+ 		rfcomm->transport = t;
+ 		rfcomm->has_volume = rfcomm_volume_enabled(rfcomm);
+ 
diff -Nru pipewire-1.0.5/debian/patches/bluez5-show-only-codec-profiles-also-for-HFP-HSP.patch pipewire-1.0.5/debian/patches/bluez5-show-only-codec-profiles-also-for-HFP-HSP.patch
--- pipewire-1.0.5/debian/patches/bluez5-show-only-codec-profiles-also-for-HFP-HSP.patch	1970-01-01 00:00:00.000000000 +0000
+++ pipewire-1.0.5/debian/patches/bluez5-show-only-codec-profiles-also-for-HFP-HSP.patch	2026-10-28 05:46:17.000000000 +0000
@@ -0,0 +1,143 @@
+Description: bluez5: show only codec profiles also for HFP/HSP
+ In Hands-free mode the device offered, besides the per-codec profiles
+ ("Headset Head Unit (HSP/HFP, codec CVSD/mSBC)"), a codec-less
+ "Headset Head Unit (HSP/HFP)" profile. Desktop codec selectors (GNOME
+ Settings) show it as the first line; it resolves to whichever codec the
+ link happens to use, so the codec cannot be seen or chosen from that line.
+ .
+ Do not list the codec-less profile. The best supported codec keeps the
+ base name "headset-head-unit", as already done for A2DP, so selecting
+ that name from the command line or from saved state still works.
+ CVSD is always listed (HSP-only devices have no codec negotiation).
+ This relies on HSP transports carrying the CVSD codec, which the
+ preceding patch (upstream f142c0a5b) provides.
+ .
+ Backport of the HFP/HSP part of the upstream commit to PipeWire 1.0.5.
+ The upstream commit also removes the codec argument from the A2DP/BAP
+ transport lookups and the "fallback profile" handling; that depends on
+ the BAP rework (a15416994) and LC3-SWB (fe412784a) that 1.0.5 does not
+ have, and is not needed for the HFP/HSP behaviour, so it is left out.
+Author: Pauli Virtanen
+Origin: backport, upstream commit 805e5cf9c115e3d0498f78e9e00e3ae93178e47d
+Bug-Ubuntu: LP: #NNNNNNN
+Forwarded: not-needed
+Last-Update: 2026-10-28
+---
+This patch header follows DEP-3: [URL omitted]
+--- a/spa/plugins/bluez5/bluez5-device.c
++++ b/spa/plugins/bluez5/bluez5-device.c
+@@ -1083,22 +1083,22 @@
+ 		}
+ 		break;
+ 	case DEVICE_PROFILE_HSP_HFP:
++		this->props.codec = 0;
+ 		if (this->bt_dev->connected_profiles & SPA_BT_PROFILE_HEADSET_HEAD_UNIT) {
+-			t = find_transport(this, SPA_BT_PROFILE_HFP_HF, this->props.codec);
++			/* There is at most one HFP/HSP transport, use its codec */
++			t = find_transport(this, SPA_BT_PROFILE_HFP_HF, 0);
+ 			if (!t)
+ 				t = find_transport(this, SPA_BT_PROFILE_HSP_HS, 0);
+ 			if (t) {
+-				if (t->profile == SPA_BT_PROFILE_HSP_HS)
+-					this->props.codec = 0;
+-				else
+-					this->props.codec = get_hfp_codec_id(t->codec);
++				this->props.codec = get_hfp_codec_id(t->codec);
+ 				emit_node(this, t, DEVICE_ID_SOURCE, SPA_NAME_API_BLUEZ5_SCO_SOURCE, false);
+ 				emit_node(this, t, DEVICE_ID_SINK, SPA_NAME_API_BLUEZ5_SCO_SINK, false);
+ 			}
+ 		}
+ 
+-		if (spa_bt_device_supports_hfp_codec(this->bt_dev, get_hfp_codec(this->props.codec)) != 1)
+-			this->props.codec = 0;
++		/* HFP/HSP profiles are only listed with a codec: never leave it unset */
++		if (!this->props.codec)
++			this->props.codec = SPA_BLUETOOTH_AUDIO_CODEC_CVSD;
+ 		break;
+ 	default:
+ 		return -EINVAL;
+@@ -1311,8 +1311,6 @@
+ 			      nodes_changed);
+ 		break;
+ 	case DEVICE_PROFILE_HSP_HFP:
+-		if (spa_bt_device_supports_hfp_codec(this->bt_dev, get_hfp_codec(this->props.codec)) != 1)
+-			this->props.codec = 0;
+ 		nodes_changed = (connected_change & SPA_BT_PROFILE_HEADSET_HEAD_UNIT);
+ 		spa_log_debug(this->log, "profiles changed: HSP/HFP nodes changed: %d",
+ 			      nodes_changed);
+@@ -1497,8 +1495,9 @@
+ 		return codec + DEVICE_PROFILE_LAST;
+ 
+ 	if (profile == DEVICE_PROFILE_HSP_HFP) {
+-		if (codec == 0 || (this->bt_dev->connected_profiles & SPA_BT_PROFILE_HFP_AG))
+-			return profile;
++		/* HFP/HSP profiles are only listed with a codec */
++		if (codec == 0)
++			return SPA_ID_INVALID;
+ 
+ 		return codec + DEVICE_PROFILE_LAST;
+ 	}
+@@ -1764,31 +1763,45 @@
+ 		/* make this device profile visible only if there is a head unit */
+ 		uint32_t profile = device->connected_profiles &
+ 		      SPA_BT_PROFILE_HEADSET_HEAD_UNIT;
++		unsigned int hfp_codec = get_hfp_codec(codec);
++		unsigned int idx;
++
+ 		if (profile == 0) {
+ 			return NULL;
+ 		}
++
++		/* HFP/HSP will only enlist codec profiles */
++		if (hfp_codec == 0) {
++			errno = EINVAL;
++			return NULL;
++		}
++		if (hfp_codec != HFP_AUDIO_CODEC_CVSD &&
++				spa_bt_device_supports_hfp_codec(this->bt_dev, hfp_codec) != 1) {
++			errno = EINVAL;
++			return NULL;
++		}
++
+ 		name = spa_bt_profile_name(profile);
+ 		n_source++;
+ 		n_sink++;
+-		if (codec) {
+-			bool codec_ok = !(profile & SPA_BT_PROFILE_HEADSET_AUDIO_GATEWAY);
+-			unsigned int hfp_codec = get_hfp_codec(codec);
+-			if (spa_bt_device_supports_hfp_codec(this->bt_dev, hfp_codec) != 1)
+-				codec_ok = false;
+-			if (!codec_ok) {
+-				errno = EINVAL;
+-				return NULL;
+-			}
+-			name_and_codec = spa_aprintf("%s-%s", name, get_hfp_codec_name(hfp_codec));
++
++		name_and_codec = spa_aprintf("%s-%s", name, get_hfp_codec_name(hfp_codec));
++
++		/*
++		 * Give base name to highest priority profile, so that best codec can be
++		 * selected at command line with out knowing which codecs are actually
++		 * supported
++		 */
++		for (idx = HFP_AUDIO_CODEC_MSBC; idx > 0; --idx)
++			if (spa_bt_device_supports_hfp_codec(this->bt_dev, idx) == 1)
++				break;
++		if (hfp_codec < idx)
+ 			name = name_and_codec;
+-			desc_and_codec = spa_aprintf(_("Headset Head Unit (HSP/HFP, codec %s)"),
+-						get_hfp_codec_description(hfp_codec));
+-			desc = desc_and_codec;
+-			priority = 1 + hfp_codec;  /* prefer msbc over cvsd */
+-		} else {
+-			desc = _("Headset Head Unit (HSP/HFP)");
+-			priority = 1;
+-		}
++
++		desc_and_codec = spa_aprintf(_("Headset Head Unit (HSP/HFP, codec %s)"),
++				get_hfp_codec_description(hfp_codec));
++		desc = desc_and_codec;
++		priority = 1 + hfp_codec;  /* prefer msbc over cvsd */
+ 		break;
+ 	}
+ 	default:
diff -Nru pipewire-1.0.5/debian/patches/series pipewire-1.0.5/debian/patches/series
--- pipewire-1.0.5/debian/patches/series	2026-07-08 23:47:28.000000000 +0000
+++ pipewire-1.0.5/debian/patches/series	2026-10-28 05:46:17.000000000 +0000
@@ -35,3 +35,5 @@
 CVE-2026-14324.patch
 CVE-2026-14330-pre1.patch
 CVE-2026-14330.patch
+bluez5-ensure-transport-codec-is-set-also-for-HSP.patch
+bluez5-show-only-codec-profiles-also-for-HFP-HSP.patch
```

The changelog's first bullet says "Cherry-pick" for patch 1 (correct: it is upstream unchanged) and "Backport ... adapted for 1.0.5" for patch 2. The `Date:` line of patch 1 is upstream's author date.

**The Launchpad report draft (SRU format), verbatim** (device addresses and links removed; the bug number does not exist yet):

~~~text
Target: Launchpad, Ubuntu source package pipewire, series noble (24.04).
Title: Hands-free mode lists a codec-less "Headset Head Unit (HSP/HFP)" profile; the codec cannot be seen or changed in GNOME Settings

Fixed upstream in PipeWire 1.1.81 / 1.2.0 by commit
805e5cf9c115e3d0498f78e9e00e3ae93178e47d ("bluez5: show only codec profiles
also for HFP/HSP"), with its preceding commit f142c0a5b0286bd8975bb67e57e0f06138e05b17
("bluez5: ensure transport->codec is set also for HSP"). Ubuntu 24.04 ships
1.0.5 (1.0.5-1ubuntu3.3 in noble-updates). The development release (27.04,
pipewire 1.6.8-1ubuntu4), 26.10 (1.6.8-1ubuntu4) and 26.04 (1.6.2) contain both.

## [Impact]

With an mSBC-capable Bluetooth headset connected in Hands-free (HSP/HFP)
mode, PipeWire 1.0.5 offers three profiles for the headset (a CVSD-only
headset: two, the codec-less one and CVSD): "Headset Head Unit (HSP/HFP)"
without a codec, and "Headset Head Unit (HSP/HFP, codec CVSD)" and
"... codec mSBC". The codec-less entry is not a real choice: it resolves to
whichever codec the link happens to use. It is the first line of the
profile/codec list in GNOME Settings (Sound), so the user sees a line that
does not say which codec is in use, cannot tell the active codec, and
cannot reliably select a codec from that line (selecting it from the input
side does not stick and falls back to a codec-specific entry). The user
cannot see or change the codec in hands-free mode from the first line.

The fix lists only profiles that name a codec, as PipeWire already does for
A2DP, and gives the best supported codec the base profile name
`headset-head-unit`, so selecting that name still works.

## [Test Plan]

Hardware needed: any Bluetooth headset with a microphone that supports HFP
(ideally one that also supports mSBC, to see both codec lines).

1. On an up-to-date noble system (pipewire 1.0.5-1ubuntu3.3), connect the
   headset and switch it to Hands-free / Headset mode in Settings > Sound.
2. Record the profile list of the card:
   `pw-cli enum-params <card id> EnumProfile` (or `pactl list cards`, section
   Profiles). Expected before the fix: a profile `headset-head-unit` with
   description "Headset Head Unit (HSP/HFP)" (no codec) besides
   `headset-head-unit-cvsd` and `headset-head-unit-msbc`.
   In GNOME Settings, open the codec/profile list: the first line is the
   codec-less entry.
3. Install the pipewire packages / `libspa-0.2-bluetooth` from -proposed
   (1.0.5-1ubuntu3.4), restart the user session (or log out and in), reconnect
   the headset, switch to Hands-free again.
4. Expected after the fix: no description "Headset Head Unit (HSP/HFP)"
   without a codec in `EnumProfile`; only "Headset Head Unit (HSP/HFP, codec
   mSBC)" (name `headset-head-unit`) and "... codec CVSD" (name
   `headset-head-unit-cvsd`) on an mSBC-capable headset, only the CVSD line
   on a CVSD-only headset. The codec lines in GNOME Settings can be
   selected; the current profile (`pw-cli enum-params <id> Profile`) names
   the codec in use, and switching between the lines changes the codec
   (`pactl list cards` shows the new active profile; the SCO link is set up
   again).
5. `pactl set-card-profile <card> headset-head-unit` still selects the
   headset profile (best codec).
6. Regression checks: switch A2DP <-> Hands-free several times; CVSD <->
   mSBC both ways, checking the codec the transport really uses (PipeWire
   debug log "codec=") and not only the profile label; the microphone works
   in Hands-free; the headset survives disconnect and reconnect with
   Hands-free as the saved profile, including a profile saved before the
   update as `headset-head-unit-msbc`.

(Results of the test on the laptop to be added here before the upload to
-proposed is requested.)

## [Where problems could occur]

The change is confined to `libspa-0.2-bluetooth`: profile enumeration and
active-codec/node handling for HSP/HFP in `spa/plugins/bluez5/bluez5-device.c`,
and the initial codec of native-backend HSP transports in
`spa/plugins/bluez5/backend-native.c`; A2DP and BAP handling is unchanged.

- The profile named `headset-head-unit` now means "the best supported
  codec" instead of "no codec". Saved user state or scripts that refer to
  `headset-head-unit` keep working and select the best codec; a script that
  relied on that name meaning "any/unspecified codec" now gets mSBC where
  the headset supports it.
- On an mSBC-capable headset the mSBC profile is now named
  `headset-head-unit`; the name `headset-head-unit-msbc` is no longer
  generated. A saved setting or script that selects
  `headset-head-unit-msbc` no longer matches a profile; what the session
  manager then selects is part of the test plan (step 6).
- A headset that only supports HSP (no HFP codec negotiation) must still get
  a profile: CVSD is therefore always listed without asking the backend, and
  the first patch (f142c0a5b) gives native-backend HSP transports the CVSD
  codec, which 1.0.5 left unset. Without it the active profile of such a
  headset would carry no valid codec. A regression here would show as an
  HSP-only headset with no Hands-free profile or no audio in it.
- If a codec switch fails, PipeWire logs "failed to switch codec" and stays
  in Hands-free; the profile shows the codec of the transport present
  afterwards, or falls back to the CVSD label when no transport remains,
  which does not mean a CVSD link is active. This path is the one 1.0.5
  already has. A regression
  would show as a wrong profile line selected in the UI or a headset that
  stays on A2DP when Hands-free is chosen.
- Other desktop components (WirePlumber 0.4.x policy, GNOME Settings,
  pavucontrol) read the profile list. WirePlumber 0.4.17 (noble) picks
  profiles by index or by saved name from the list and does not refer to
  the codec-less entry; a saved name `headset-head-unit` now resolves to
  the best-codec profile. Only the test above on a real headset covers
  the whole chain.

## [Other Info]

- Upstream commit: 805e5cf9c115e3d0498f78e9e00e3ae93178e47d
  (in 1.1.81, 1.2.0 and later). No upstream follow-up commit corrects it
  (searched the history of `bluez5-device.c`, `Fixes:`/revert, up to 1.6.10).
- The upstream commit does not apply to 1.0.5 as is (7 of 21 hunks fail):
  it depends on the BAP rework (a15416994) and LC3-SWB support (fe412784a).
  The second patch is a backport of its HFP/HSP part, adapted for 1.0.5 (one
  file, 42 insertions and 29 deletions); the A2DP/BAP cleanups of the upstream
  commit are left out because they are not needed for this behaviour. The
  first patch is upstream f142c0a5b unchanged (it applies with offsets).
- Build: the package builds in a clean ubuntu:24.04 container; there is no
  unit test for the bluez5 profile list in PipeWire 1.0.5.
- Debdiff: pipewire_1.0.5-1ubuntu3.3_1.0.5-1ubuntu3.4.debdiff (attached).
- Related, separate: none filed. LP #2162010 is a different Bluetooth
  hands-free problem (AT+CCWA).
~~~

### Tests and results

All measured, in a throw-away `ubuntu:24.04` container; nothing run on a real headset.

- Source package: `1.0.5-1ubuntu3.3` fetched from Launchpad (newest in noble: Updates and Security, published 2026-07-13); the sha256 of the debian tarball (`a1650f8e...e9a3ff0`) and the orig tarball (`d5e5f3d0...b955a56`) equal the `Checksums-Sha256` of the `.dsc`. The `.dsc` signature could not be verified (no Ubuntu keyring in the container: "Can't check signature: No public key").
- Build of version 2 (both patches): exit code 0; both patches apply (patch 1 with offsets -1 and -68); 0 compiler warnings in `bluez5-device.c` or `backend-native.c`; `meson test` Ok 22, Expected Fail 0, Fail 0, Unexpected Pass 0, Skipped 0; 22 binary packages at `1.0.5-1ubuntu3.4`.
- No unit test of PipeWire 1.0.5 covers the bluez5 profile list (a search of `test` and `spa/tests` build files for "bluez5" or "bluetooth" is empty), so the 22 passing tests say nothing about this change beyond "nothing else broke at build level".
- Binary check: strings matching "Headset Head Unit" in `libspa-bluez5.so`: stock has two (`Headset Head Unit (HSP/HFP)` and `Headset Head Unit (HSP/HFP, codec %s)`), rebuilt has one (the codec form). This proves the string is gone, not the runtime behaviour.
- Dependency: `libspa-0.2-bluetooth_1.0.5-1ubuntu3.4` depends on `libspa-0.2-modules (= 1.0.5-1ubuntu3.4)`; the plugin package alone does not install (simulated: "held broken packages"). The pair does: `apt-get -s` changes exactly those two packages ("2 upgraded"), the install in the container returns 0, and the rollback to 3.3 needs `--allow-downgrades` (simulated: "2 downgraded"). The container had no PipeWire session, so this says nothing about runtime.
- Dependency check, WirePlumber 0.4.17 (noble) `policy-bluetooth.lua`: profiles are found by index or by saved name from `EnumProfile`; there is no reference to the codec-less entry; `bluez5.profile = headset-head-unit` is handled in `set_initial_hsp_hfp_profile()` and is untouched (from source).
- Outside review: six reviewers over five rounds. Round 1 found the HSP-only path (verified, led to patch 1), a wrong install plan (led to the exact-version pair procedure) and wording issues. Rounds 2 to 4: patch 1 compared with upstream by three reviewers and cherry-picked onto 1.0.5 by one; code approved; requests for the build record, hashes, dependency simulation and a step for the old saved name were done. Round 5 (final go/no-go): all six "GO" for code and packaging, no blocking finding; all six "not yet for filing" until the laptop test.

**Laptop test plan** (the gate; the laptop has 1.0.5-1ubuntu3.3; a headset in Hands-free, ideally an mSBC-capable one):

BEFORE (3.3 installed): (1) `pactl list cards`, Profiles of the headset: expect `headset-head-unit` "Headset Head Unit (HSP/HFP)" (no codec) besides `headset-head-unit-cvsd` and `-msbc`; also `pw-cli enum-params <card id> EnumProfile`. (2) GNOME Settings, Sound: screenshot of the list in Hands-free (first line codec-less). (3) Note that selecting the first line gives no codec information and does not stick.

Install: simulate first with `apt-get -s install` of the two rebuilt `.deb` (it must change only `libspa-0.2-bluetooth` and `libspa-0.2-modules`), then install the same two together, then `systemctl --user restart pipewire wireplumber pipewire-pulse` (replacing packages does not replace code already loaded). Never `--force-depends`. Rollback: `apt-get install --allow-downgrades libspa-0.2-bluetooth=1.0.5-1ubuntu3.3 libspa-0.2-modules=1.0.5-1ubuntu3.3`, then the same restart.

AFTER (3.4, services restarted, headset reconnected, Hands-free selected): (4) no entry described "Headset Head Unit (HSP/HFP)" without a codec; on an mSBC headset `headset-head-unit` described "(HSP/HFP, codec mSBC)" and `headset-head-unit-cvsd` "(... codec CVSD)"; on a CVSD-only headset one entry, `headset-head-unit`, CVSD. (5) `pw-cli enum-params <card id> Profile` names the codec in use; GNOME Settings shows it on the selected line. (6) Select each codec line: the profile changes, the SCO link is set up again with that codec, audio plays, the microphone records. (7) `pactl set-card-profile <card> headset-head-unit` selects the best codec. (8) Regression: A2DP, Hands-free, A2DP three times; disconnect and reconnect in Hands-free; start a recording application while on A2DP (the automatic switch to Hands-free) and see it end on a codec line. (8a) Before the update save an mSBC selection (`headset-head-unit-msbc`); after it, reconnect and record which profile the session manager selects for that old name and whether audio and microphone work. For CVSD and mSBC check the codec the transport really uses (`PIPEWIRE_DEBUG=spa.bluez5*:4`, "codec="), not only the label. If a codec switch fails, record the log line ("failed to switch codec") and what is shown afterwards before blaming the port. (9) Record commands and outputs.

### Not known, not claimed

- Behaviour on a real headset: not tested at all.
- HSP-only headsets: patch 1 is reasoned from source, not tested on one; not covered by the laptop test either. oFono and hsphfpd backends: not tested.
- What the session manager selects for a profile name saved before the update as `headset-head-unit-msbc` (that name is no longer generated): open, answered only by test step 8a.
- Whether the Ubuntu SRU team accepts a hand-port of this size; whether they would want the full upstream series instead.
- The `.dsc` signature was not verified.

### Open points and questions for the reviewer

1. Is the hand-port faithful for the HFP/HSP behaviour? Please check the three differences (a), (b), (c) above against the upstream commit; in particular that dropping the `HFP_AG` clause in `get_index_from_profile()` and the `set_profile` condition causes no change for an audio-gateway device in 1.0.5.
2. Is "the profile `headset-head-unit` now means the best codec; `headset-head-unit-msbc` is no longer generated" acceptable for a stable update? Is the "Where problems could occur" text enough?
3. Is patch 1 (CVSD on HSP transports) correctly justified as needed? Every other read of `t->codec` in 1.0.5 compares with mSBC or serves labels and lookups (from source), so HSP audio paths are claimed unchanged.
4. Is there a test an SRU reviewer would want besides the laptop test, given that no unit test covers the profile list?
5. Changelog: two entries, both with the same bug reference; is that the usual shape? The trailer name and date are to be confirmed by the submitter before upload.

### Route and next step

Laptop headset test (install the rebuilt pair, run the plan, keep or roll back) by the submitter; record the outputs; then obtain the Launchpad bug number (replace the placeholder in the two patch headers, the changelog and the report), attach the debdiff, and file as an SRU by the submitter. Ubuntu's development release already has both commits, so only the noble update is needed.

---

## CO-36 — U15: PipeWire's delayed HFP volume resend outlives the SCO audio link

### At a glance

| | |
|---|---|
| Target | PipeWire, `spa/plugins/bluez5/backend-native.c` (Hands-free audio-gateway role); observed on 1.0.5 (Ubuntu 24.04), reproduced on master `4cfc4711` (2026-10-30). |
| State on 2026-11-02 | Reproduced on real hardware (journal, Bluetooth HCI capture, source) and on master in PipeWire's own VM test setup. Fix variants tried locally in test builds only. Nothing filed. |
| Who writes the report | **PipeWire's contributor rules forbid tool-written issue text, merge-request text, commit messages and replies; the submitter writes and files the upstream report himself, in his own words, with original logs.** This section is therefore an evidence summary for reviewers: facts, source excerpts, reproduction, results, and candidate variants labelled as test variants. It is not a draft of the upstream report. |
| Asked of the reviewer | Is the evidence sound and the reproduction convincing; is the mechanism read correctly from the source; which lifetime should the resend have (the design question, see the open points); is anything missing before the submitter does the duplicate search and writes the report. |

### Background

Terms: "link" = the SCO/eSCO audio connection. The RFCOMM control connection (HFP's service-level connection) stays up the whole time, and HFP lets the audio gateway send `+VGS`/`+VGM` volume reports over it without an audio link (two reviewers cite HFP 1.10 section 4.29.1; the specification text was not checked here). A volume command without audio is therefore not wrong in itself; what the facts show is a resend scheduled for one audio link that is sent after that link has ended.

The effect that made it audible: the headset MOMENTUM 4 reports a microphone gain of 0 at every connect (32 of 32 connects since 2026-10-19), PipeWire stores it and sends it back as `+VGM: 0`, and the headset announces a received `+VGM: 0` as "mute on". On 2026-10-31 at 03:33 the listener heard "mute on" twice at the end of a dictation; the second came from a `+VGM: 0` sent after the link was gone. (That one "mute on" per link would remain without the late resend is a separate matter.) Nothing was measured acoustically.

Environment of the real-hardware cases: Ubuntu 24.04, kernel 7.0.0-42, PipeWire 1.0.5-1ubuntu3.3, WirePlumber 0.4.17-1ubuntu4.1 (automatic switch to Hands-free on), BlueZ 5.72-0ubuntu5.8, controller Qualcomm QCA9377, mSBC over eSCO. PipeWire logging at debug level for `spa.bluez5*` is where the `RFCOMM >>`, `acquire complete` and `released` lines come from; the HCI capture is a btsnoop host-to-controller capture decoded with btmon (not a radio capture).

### Root cause

From source, master `4cfc4711`, `spa/plugins/bluez5/backend-native.c` (the functions do the same in 1.0.5, where `sco_ready()` sends at lines 1565 to 1566, `sco_release_cb()` is at 1634, `sco_event()` at 1653 to 1669, the timer handler at 1978 to 1988):

`sco_ready()` lines 2796 to 2814 (comment shortened):

```c
	/*
	 * Send RFCOMM volume after connection is ready, and also after
	 * a timeout.
	 * ... E.g. with Sennheiser HD-250BT, the first +VGS changes the
	 * actual volume, but does not update the level in the hardware
	 * volume buttons, ...
	 */
	rfcomm_ag_sync_volume(td->rfcomm, false);
	rfcomm_ag_sync_volume(td->rfcomm, true);

	spa_bt_transport_set_state(t, SPA_BT_TRANSPORT_STATE_ACTIVE);
```

The resend was added by `d82b3d647` (Pauli Virtanen, 2022-06-16, "bluez5: backend-native: set HFP/HSP volume when connecting"; in 1.0.5). The timer (lines 3247 to 3257):

```c
static void volume_sync_timer_event(void *data, uint64_t expirations)
{
	struct rfcomm *rfcomm = data;

	volume_sync_stop_timer(rfcomm);

	if (rfcomm->transport) {
		rfcomm_ag_set_volume(rfcomm->transport, SPA_BT_VOLUME_ID_TX);
		rfcomm_ag_set_volume(rfcomm->transport, SPA_BT_VOLUME_ID_RX);
	}
}
```

with `const uint64_t timeout = 1500 * SPA_NSEC_PER_MSEC;` in `volume_sync_start_timer()` (line 3262). The handler checks only `rfcomm->transport != NULL`: the HFP transport object, which lives as long as the RFCOMM connection, not the link. `rfcomm_ag_set_volume()` (lines 3124 to 3152) checks hardware-volume support and whether the gain is active (the headset has itself reported it), not whether a link is open.

The link ends in two ways, neither stops the timer. `sco_release_cb()` (2881 to 2899): sets the transport idle, sends `+CIEV: 2,0`, calls `sco_destroy_cb()`, which closes the socket. `sco_event()` (2901 to 2933), on hang-up or error of the SCO socket:

```c
	if (source->rmask & (SPA_IO_HUP | SPA_IO_ERR)) {
		/* sco_ready() reads the socket error status in td->err */
		sco_ready(t);
		...
		if (t->fd >= 0) {
			spa_bt_transport_set_state(t, SPA_BT_TRANSPORT_STATE_IDLE);
			shutdown(t->fd, SHUT_RDWR);
			close(t->fd);
			t->fd = -1;
		}
	}
```

The timer is stopped in two places only: when a codec selection `AT+BCS=` arrives (line 1241; 904 in 1.0.5) and in the timer's own handler (`git log -S volume_sync_stop_timer` on master lists only `d82b3d647`). So when a link is released less than 1.5 s after it became ready, the second `+VGS`/`+VGM` pair goes to the headset after the audio link is gone. Also from source: `sco_ready()` sends the first pair before it sets the transport active; one timer exists per RFCOMM connection, so a new `sco_ready()` re-arms it and replaces a pending resend of an earlier link. History: `d82b3d647` armed the resend in `sco_acquire_cb()` right after waiting up to 500 ms for the new SCO socket; `2bc48e1c1` (2023-03-17, "make SCO acquire asynchronous") moved the calls to `sco_ready()`. Neither says what should happen when the link ends within 1.5 s; the code comment gives a `+VGS` reason only. As audio gateway, PipeWire marks a direction active only after the headset reports that gain, so a headset that never reports a microphone gain never gets `+VGM` (master lines 681 to 689; from source).

### The change

None is proposed by this evidence package. Five candidate behaviours were defined for testing (named V1 to V5; V0 is unmodified master):

- V1: stop the timer in `sco_release_cb()` only. Expected (reasoning, not run): fixes the release path, not the hang-up path in `sco_event()`.
- V2: the timer handler sends only when the transport state is ACTIVE. One condition. Built and tested.
- V3: stop the timer wherever a link ends: `sco_destroy_cb()`, `sco_release_cb()` and the HUP/ERR branch of `sco_event()`. Built and tested.
- V4: the late resend sends `+VGS` only (no late `+VGM`). Expected (not run): the late `+VGS` remains.
- V5: no code change; a `hw-volume-mic` device quirk for the affected headset (data, not code). Tested on master: see below.

Whether stopping the timer would undo what `d82b3d647` was for (a headset taking the first `+VGS` after a connection only partly) is the maintainers' call and is not known here.

### The patches, verbatim

These are local test variants, not submissions and not proposed changes. The diff bodies are exactly as built, against master `4cfc471123a0e041fcd6fec5887c40dbddd40325`.

V2 (test variant):

```diff
--- a/spa/plugins/bluez5/backend-native.c
+++ b/spa/plugins/bluez5/backend-native.c
@@ -3250,7 +3250,8 @@
 
 	volume_sync_stop_timer(rfcomm);
 
-	if (rfcomm->transport) {
+	if (rfcomm->transport &&
+			rfcomm->transport->state == SPA_BT_TRANSPORT_STATE_ACTIVE) {
 		rfcomm_ag_set_volume(rfcomm->transport, SPA_BT_VOLUME_ID_TX);
 		rfcomm_ag_set_volume(rfcomm->transport, SPA_BT_VOLUME_ID_RX);
 	}
```

V3 (test variant):

```diff
--- a/spa/plugins/bluez5/backend-native.c
+++ b/spa/plugins/bluez5/backend-native.c
@@ -2860,6 +2860,8 @@
 	struct transport_data *td = t->user_data;
 	struct impl *backend = SPA_CONTAINER_OF(t->backend, struct impl, this);
 
+	volume_sync_stop_timer(td->rfcomm);
+
 	if (t->sco_io) {
 		spa_bt_sco_io_destroy(t->sco_io);
 		t->sco_io = NULL;
@@ -2887,6 +2889,7 @@
 	spa_log_info(backend->log, "Transport %s released", t->path);
 
 	spa_bt_transport_set_state(t, SPA_BT_TRANSPORT_STATE_IDLE);
+	volume_sync_stop_timer(td->rfcomm);
 
 #ifdef HAVE_BLUEZ_5_BACKEND_HFP_NATIVE
 	if (!td->rfcomm->device->disable_dummy_call)
@@ -2907,6 +2910,7 @@
 	if (source->rmask & (SPA_IO_HUP | SPA_IO_ERR)) {
 		/* sco_ready() reads the socket error status in td->err */
 		sco_ready(t);
+		volume_sync_stop_timer(td->rfcomm);
 
 		if (td->err < 0) {
 			spa_log_info(backend->log, "transport %p: SCO socket error: %s (%d)",
```

V1, V4 and V5 have no diff: V1 and V4 were only described; V5 is a configuration entry.

### Tests and results

**Real hardware, journal and HCI capture** (measured; local time; full logs exist for each case):

| case | headset | what released the link | link ready to released | resend vs release |
|---|---|---|---|---|
| A, 2026-10-22 20:25:27 | MOMENTUM 4 | at connect: the session manager chose the mSBC Hands-free profile before A2DP was up, then switched to A2DP | 27.478 to 27.897 (0.42 s) | resend at 28.978: 1.081 s after "Transport ... released" |
| B, 2026-10-23 23:53:10 | Lenovo thinkplus GM2 pro | end of a dictation: session manager's switch back to A2DP | 11.274 to 12.703 (1.43 s) | resend 72 ms after "released", between HCI Disconnect and Disconnect Complete |
| C, 2026-10-31 02:58:54 | MOMENTUM 4 | same as B | 55.067 to 56.576 (1.51 s) | resend 9 ms before "released" (control; "mute on" heard once) |
| D, 2026-10-31 03:33:22 | MOMENTUM 4 | same as B | 22.469 to 23.925 (1.46 s) | resend 44 ms after "released", 38 ms after Disconnect Complete; "mute on" heard twice |

In A, B and D the PipeWire log order is: `acquire complete`, `RFCOMM >> +VGS`/`+VGM`, `Transport ... released`, `RFCOMM >> +CIEV: 2,0`, `RFCOMM >> +VGS`/`+VGM`. The HCI capture shows the same `+VGS`/`+VGM` as outgoing ACL data after the eSCO Disconnect command.

How often (heuristic): a scan over every boot in the journal (2026-10-22 to 2026-10-31) found 91 hands-free links; 11 released within 3 s of their `+CIEV: 2,1`; in 3 of those (A, B, D) the resend went out after the release, in the other 8 it went out 8 to 405 ms before. Apart from A, all 10 short links ended the same way: the session manager's switch back to A2DP 1.82 to 1.95 s after `+CIEV: 2,1`. The scan follows one link at a time from `+CIEV: 2,1` to `+CIEV: 2,0`, recognises the resend as a `+VGM` 1.45 to 1.55 s after the first one (a `+VGS`-only resend is missed), uses journal receive times, and cannot tell two headsets apart if both are connected; A, B and D were each checked by hand against the HCI capture. These counts describe one laptop's journal, not a general rate. The hang-up path (`sco_event()`) was not observed on the hardware to cause a late resend: the journal has it twice, neither with a late resend (one 14 s after link ready, one with no link in the 15 minutes before).

**Reproduction on master** `4cfc4711` in PipeWire's own Bluetooth VM tests (pytest-bluezenv 0.1.9, two VMs with emulated controllers, one running PipeWire as audio gateway and one as the headset, BlueZ `ebbb4ee31ad7` built with AddressSanitizer, kernel `v7.2` test image, WirePlumber 0.5.19; PipeWire's own CI build options with ASan and UBSan). No real Bluetooth controller is used. The test file is added next to PipeWire's `test_streaming.py`; each time is taken from the gateway's own log (one clock).

Test plan: 113 test entries by layer (build and existing tests; unit with virtual time; two-VM integration; application layer driven by the session manager's policy; real headsets only with the submitter's agreement), each marked "leak" (expected failure the fix must turn into a pass) or "keep" (must pass before and after), with eight invariants a fix must hold (no late frame after the link ended; one resend on a long link; immediate send at link start; user volume changes unchanged; headset-reported gains unchanged; codec/profile handling unchanged; nothing sent where nothing is sent today; no crash or leaked timer). Results on unmodified master:

- Link shorter than 1.5 s: **every one leaks**, at every way of ending it. AG profile switch: CVSD 10 of 10 (links 452 to 908 ms, late `+VGM` at 1501 to 1504 ms), mSBC 10 of 10, LC3-SWB 9 of 9 in window (a tenth ended at 1832 ms, clean); headset hang-up of the SCO link: CVSD 10 of 10 (97 to 743 ms), mSBC 10 of 10; hang-up near the deadline 4 of 4 (at 1158, 1355, 1424, 1499 ms; late pair 7 to 345 ms after; two hang-ups at 1579 and 1586 ms were clean); profile "off" 6 of 6; node suspend 3 of 3 when short (suspend adds 1 s: the transport is released 1000 ms after it, `TRANSPORT_RELEASE_TIMEOUT_MSEC`); 13 links of set lengths: the 8 under 1.5 s each leak, the 5 over (1528 to 2640 ms) are clean.
- The deadline counts from link start, not link end (hang-up at 1499.4 ms, late frames at 1506.5 ms).
- Long links (over 1.5 s): resend at about 1502 ms while up, nothing after; 12 of 12 out-of-window runs clean.
- A second link: if it is ready within 1.5 s of the first, the one timer is re-armed and nothing leaks between the links; if the second comes later (1649 ms in one run), the first link's resend leaves in the gap.
- Keep tests that pass on master: PipeWire's own 7 VM tests (one flake its own comment describes), `meson test` 74 of 74 (none runs `backend-native.c`), bluetoothd restart within 1.5 s (4 of 4, nothing written), codec switch after a short link (5 of 5, `AT+BCS=1` stops the timer), user volume change with and without a link (5 of 5), change while the resend is pending (6 of 6: sent 0.1 ms after the change, the later resend carries it), headset-reported gain taken (9 of 9), hardware volume off by either switch (4 of 4 each, nothing sent), the headset receives exactly what the gateway sent (150 of 150 runs, same frames and values in the same order).
- V5, measured on master: with a headset-without-`hw-volume-mic` quirk, `+VGM` is never sent (4 of 4) but the short link's late `+VGS` still leaves at 1501 to 1503 ms.
- Application layer: with the session manager's restore timeout 0, 1.0 to 2.0 s capture streams made 24 links of 60 to 1197 ms, 24 of 24 leak; with the default 4 s restore, one 10.9 to 12.6 s link per run, clean. WirePlumber 0.4.17's policy (restore 2000 ms), built against master with one compiler error demoted to a warning (not CI's flags), made 8 links of 2134 to 4614 ms in 5 runs, all clean; its minimum link was above the window.
- Unit layer (the backend source compiled into a harness with a fake loop and virtual time, so events can be placed at 1499 and 1501 ms): 49 tests; master 34 pass, 15 fail; the 15 are exactly the planned leak set (release at 100, 1499 and 0 ms; hang-up and error at 100 and 1499 ms; hang-up then release; new link at 1600 ms; link released 100 ms after a second one; ten 100 ms links; CVSD without negotiation and HSP as extras).
- Sanitizers: no report from PipeWire or WirePlumber in any run. One AddressSanitizer heap-use-after-free was reported in BlueZ's `bluetoothd` at shutdown (`profiles/audio/media.c`, 1 of about 150 gateway shutdowns); that is BlueZ, tracked separately, not part of this issue.

**Variant round (2026-11-01), local experiments only, same test files unchanged on every variant:**

- Unit layer, 3 runs per variant, byte-identical across runs: V0 34 pass / 15 fail; V2 49 of 49 pass; V3 49 of 49 pass; V2's result line equals V3's for every test. The changed outcomes are exactly the planned leak set plus the same-loop-turn case where the timer and link-ready fall in one event (on V0 the order decides: link first is clean, timer first leaks; on V2 and V3 both orders give the same timeline). Every keep test is byte-identical to V0.
- Extra gap cases (7 cases, 3 runs): incoming link pending across the deadline, outgoing connect in progress, link up and down in one event, link acquired exactly at the deadline. V0 fails 5 of 7 (the other two pass), V2 and V3 pass all. The only V2/V3 difference anywhere: after a release V2 leaves the timer armed (it fires and sends nothing), V3 disarms it.
- Two-VM layer, 3 runs per case (re-acquire cases 6 to 8 runs): short link CVSD/mSBC, hang-up, hang-up near the deadline, re-acquire first link, volume change after a short link. V0 leaks every in-window run (late `+VGM` at 1501.5 to 1555.1 ms); V2 and V3 show no late `+VGM` in any run. In the V0 run of "codec switch after a short link" 1 of 3 leaked; in V2 and V3 none, but those V2/V3 links were mostly longer than 1.5 s, so that case does not discriminate. For "volume change after a short link" V2 and V3 still show the one frame the test deliberately sends at the change (the user's change, sent at once); that is not a late resend (inferred from the test design). Unchanged: long link, bluetoothd restart, hang-up in time. The headset-side ledger had 0 mismatches. Failures that are not variant effects: the session manager ending the second link in some re-acquire runs (also on V0, 2 of 6), and a codec-switch test whose links were stretched by two VM batches running at once (normal when run alone).
- Unit and two-VM layers agree on every pair of cases both can run.
- Verdict: a tie. No test distinguishes V2 from V3 on the wire. A hypothesis from an outside reviewer: V3 stops the timer from an old transport's teardown via the shared RFCOMM object, so a late teardown of an old transport after a new link re-armed the timer would cancel the new link's legitimate resend. Checked in source on 2026-11-01 as unreachable: one RFCOMM connection has at most one transport at a time; `rfcomm_new_transport()` frees the old one synchronously before creating the new (`backend-native.c:381-385` at `4cfc4711`) and freeing runs all three V3 stop points first; the timer is armed on one transport only in `sco_ready()`, which needs a new acquire, which needs the previous release; a reconnect is a new RFCOMM with its own timer. V2's premise also holds from source: for native HFP/HSP transports `sco_ready()` is the only caller that sets ACTIVE.
- Not run on the variants: PipeWire's own 7 VM tests, the clang build, builds with a native backend disabled, a backport to 1.0.5, real headsets.

### Not known, not claimed

- Whether this is already reported or fixed in an open merge request: GitLab's bot protection refuses scripted reads, so the duplicate search (issues for "VGM", "volume sync", "mute on"; merge requests for "volume") is for the submitter in a browser. The history search finds no change to the timer since 2022.
- Whether the HD-250BT (the case named in the code comment) needs the late `+VGS`; none was available.
- Whether the headset's microphone is really silenced in a call; whether the GM2 pro announces anything; whether the case-A resend was heard.
- HSP as audio gateway: unreachable on master in the VM tests (an HSP-only headset gets only the "off" profile; inferred from `backend_native_supports_codec()` looking up the RFCOMM by `SPA_BT_PROFILE_HFP_HF` only, `backend-native.c:3205`, and `bluez5-device.c:2430` dropping a headset profile without a codec), a separate matter. The headset role (PipeWire as HF) sends no such frames (`hf_sent_ag_frames` 0 in every run).
- Two headsets at once (the emulated controller keeps one ACL link; independence rests on source: one timer per RFCOMM connection).
- oFono and hsphfpd backends: they have no such timer (from source).
- Ubuntu's own patches in `1.0.5-1ubuntu3.3` were not compared (the behaviour is on the installed package, so they do not remove it).
- The real-hardware cases are all local releases; the real-hardware effect of any variant is untested.

### Open points and questions for the reviewer

1. Which lifetime should the delayed resend have? V2 holds as long as every path to ACTIVE goes through `sco_ready()`; V3 holds as long as every link end passes one of its three stops. Which is the more natural for the maintainers, or is there a better place (for example an explicit link-generation check)?
2. Is a late `+VGS` ever wanted (V4/V5 keep it)? The test file records `+VGS` separately for every run so the question can be answered either way.
3. Would stopping the timer at release undo the purpose of `d82b3d647` (the first `+VGS` being taken partly)? Only the maintainers know.
4. Is the mechanism read correctly from the source, in particular that nothing else stops the timer and that `rfcomm->transport` stays non-NULL for the life of the RFCOMM connection?
5. Is the evidence the right kind to attach to a report (verbatim journal lines, HCI capture extracts, VM-test logs)? Is anything missing that a maintainer would ask for first (for example a reproduction recipe on a real headset)?
6. Is the heuristic scan (3 of 91) worth quoting at all, given its limits?

### Route and next step

The submitter does the duplicate search on the project's issue tracker in a browser, and if nothing exists writes and files the report in his own words, attaching verbatim logs from the cases above. Any local test of a variant on the real headsets happens only on his word, and a patch goes upstream only as his own. The upstream report will be written by the submitter himself; none is drafted here.

---

## CO-32 — U19: Ubuntu's WirePlumber patch for LP 2122640 kills the Sound panel's input meter

### At a glance

| | |
|---|---|
| Target | Ubuntu 24.04 `wireplumber` 0.4.17-1ubuntu4.1, script `policy-node.lua` (Ubuntu's patch `lp-2122640-bluetooth-audio-glitch.patch`, Antoine Lassagne, 2025-09-11; Launchpad bug 2122640, Fix Released for noble). Upstream WirePlumber is not affected (read in master, see below). |
| State on 2026-11-02 | Mechanism confirmed in the user journal, the audio-policy log and the source. The one-line fix has never been run. No Launchpad report exists. A laptop test through a user-level override is proposed and waits for the submitter's go-ahead. |
| Asked of the reviewer | Is the diagnosis right; is the one-line fix right and sufficient (and safe for the protection the patch exists for); is the test plan sound; what an Ubuntu SRU would need. |
| Related | CO-07 (GNOME Settings 46.7 input meter: GNOME 47's six-commit fix) depends on this item: on Ubuntu the GNOME fix alone would not help while the 2-second block destroys the re-targeted meter. CO-32 goes first. |

### Background

On 2026-10-24 (the Shure AONIC 50 headset; GNOME Settings' Sound panel open) after switching the headset from Hands-free to Headset (A2DP), the Input section named the laptop's internal microphone, but its level meter did not move; mute/unmute changed nothing. Choosing the internal microphone by hand while in Hands-free made its meter work; back in A2DP it was dead again. The opposite switch (A2DP to Hands-free) worked. Repeated on 2026-10-24 08:04:59 and 08:08:42, and on 2026-10-26 (meter frozen at the level shown at the switch, with the headset's microphone as input).

Ubuntu's patch for LP 2122640 exists to prevent "bluetooth profile switch to output some sound on another device during the transition" (changelog wording): during a Bluetooth profile change the headset's node disappears, and without the patch the streams briefly link to the laptop speakers.

### Root cause

Journal evidence (measured; user journal, 2026-10-24):
- 08:04:59.044924 `Bluetooth device removed, preventing non-Bluetooth devices from linking for 2 seconds`
- 08:04:59.051861 `[GNOME Settings] CREATE_RECORD_STREAM tag:478 ... source-name:53` (53 is the laptop's microphone)
- 08:04:59.734 to .753 `... target not found, reconnect:false` then `... destroy node`
- 08:04:59.754620 `[GNOME Settings]: ERROR ... tag:478 error:25 (Input/output error)`
- The same sequence at 08:08:42 (stream tag 1173). The same shape on 2026-10-29 04:46:01 (stream created at 04:46:01.18, errors 2.0 s later at 04:46:03.18).

Source: the installed `/usr/share/wireplumber/scripts/policy-node.lua`, package 0.4.17-1ubuntu4.1 (the file with Ubuntu's patch applied; line numbers are those of that file).

When a Bluetooth node is removed (lines 1021 to 1042):

```lua
linkables_om:connect("object-removed", function (om, si)
  unhandleLinkable (si)
  if isBluetooth(si) then
    -- If a bluetooth device was removed, we want to prevent linking to the default device for 2 seconds
    Log.info("Bluetooth device removed, preventing non-Bluetooth devices from linking for 2 seconds")
    ...
    -- disable rescan
    self.rescan_enabled = false
    -- re-enable rescan after 2 seconds
    self.timeout_source = Core.timeout_add (2000, function()
      self.timeout_source = nil
      self.rescan_enabled = true
      self.skip_rescan_id = nil
      scheduleRescan ()
    end)
```

A new stream whose target is not Bluetooth is skipped (lines 722 to 723 and 754 to 762):

```lua
  local skip_this_target = false
  ...
  else
    if self.rescan_enabled == false and si_target then
      -- Here, the default device connected in between a profile transition of bluetooth device
      -- We want to prevent the default device to link during the transition.
      if isBluetooth(si_target) == false then
        skip_this_target = true
      end
    end
  end
```

and then (lines 818 to 825) the stream is marked handled whether or not a link was made:

```lua
  else
    if skip_this_target == false then
      createLink (si, si_target, can_passthrough, exclusive)
    end
    si_flags[si.id].was_handled = true

    checkFollowDefault (si, si_target, has_node_defined_target)
  end
```

The Sound panel's level meter opens its stream with `PA_STREAM_DONT_MOVE` (GNOME Settings 46.7, `panels/sound/cc-level-bar.c:197`), which pipewire-pulse turns into "don't reconnect". At the next rescan (after the 2 s) the condition at lines 764 to 768, "stream has dont-reconnect and was already linked before" (`not reconnect and si_flags[si.id].was_handled`), sets `si_target = nil`; the stream then goes through "target not found" (lines 789 to 816): the client is sent an error and, because it is not reconnectable, the node is destroyed. GNOME Settings does not retry: the level bar sets no state or failure callback (`cc-level-bar.c:187-188`); it re-attaches only when the default source changes again (`cc-sound-panel.c:151-169`, `191-209`), which after a switch to A2DP it does not (from source; GNOME Settings 46.7-0ubuntu0.24.04.6). The opposite switch works because the new target is the Bluetooth source, which the patch lets through; the hand pick works because no Bluetooth removal falls in its 2 s. Inferred: any stream opened with "don't move" to a non-Bluetooth device within 2 s of a Bluetooth node's removal is lost the same way (other meters, some recorders); not tested.

Upstream check (2026-10-24 and again 2026-11-01): upstream WirePlumber master's `linking/rescan.lua` only pauses the rescan triggers and never marks an unlinked stream as handled (read in master; the upstream merge request that Ubuntu's patch is said to rewrite could not be fetched). Noble has nothing newer than 0.4.17-1ubuntu4.1; the comments on LP 2122640 report no such regression; no Launchpad or GNOME report matching was found.

### The change

One line moves: mark the stream handled only when a link was made. The skipped stream then stays unhandled, so at the end of the 2 s the rescan links it to the intended target.

### The patches, verbatim

Against the installed `policy-node.lua` of 0.4.17-1ubuntu4.1 (a one-line move; an Ubuntu SRU would carry it as a further patch on top of Ubuntu's patch):

```diff
--- a/usr/share/wireplumber/scripts/policy-node.lua
+++ b/usr/share/wireplumber/scripts/policy-node.lua
@@ -818,8 +818,8 @@
   else
     if skip_this_target == false then
       createLink (si, si_target, can_passthrough, exclusive)
+      si_flags[si.id].was_handled = true
     end
-    si_flags[si.id].was_handled = true
 
     checkFollowDefault (si, si_target, has_node_defined_target)
   end
```

Equivalent form as first drafted:

```lua
if skip_this_target == false then
  createLink (si, si_target, can_passthrough, exclusive)
  si_flags[si.id].was_handled = true
end
```

This diff was written against the installed file for this document and has not been run; the original draft was marked "inference, not run".

### Tests and results

Nothing has been run with the fix. Measured so far is only the failure (journal lines above) and the source reading. The proposed laptop test:

- Preparation: record the installed WirePlumber version the day before (it must still be 0.4.17-1ubuntu4.1); record the default output and input; a user-level copy of `policy-node.lua` with the one-line change replaces the installed script for the user's WirePlumber instance. Removing the copy restores Ubuntu's version. Exact steps for the override are prepared before the test (not yet in final form).
- First check, before judging anything: that the override really replaces the installed script and takes effect, read from WirePlumber's log at start (which script path was loaded); if it did not load, the test result is void.
- Test: with the Sound panel open and the headset's microphone as input, switch the headset Hands-free to A2DP three times; also the original 2026-09-26 sequence (the earlier "U6" report: laptop microphone selected, headset switched to A2DP, meter dead). Read the user journal for `[GNOME Settings] CREATE_RECORD_STREAM` and any `ERROR` after it, and for WirePlumber's "target not found" / "destroy node".
- Pass conditions, both required: (1) the meter works after the switch (the stream is created and survives; no "destroy node"); (2) no audio leaks to the laptop speakers during the switch (the reason the Ubuntu patch exists must still hold: play a sound through the headset and listen at the switch; check with the audio-policy log that no stream links to the laptop output during the 2 s).
- Interpretation for CO-07: if the meter now works, GNOME 47's fix is not needed for this symptom; if it still dies without a WirePlumber "destroy", the GNOME series is needed as well.
- Then undo the override completely and restore the recorded defaults, so that the next independent laptop test (a switch-on-connect configuration) starts from a clean baseline.

### Not known, not claimed

- The fix is not run; that the rescan at the end of the 2 s links the meter is inferred from the source.
- Whether the fix reopens the leak that LP 2122640 closed (only the second pass condition answers it).
- Whether recorders (not only the Sound panel's meter) are hit the same way: not tested.
- Why upstream WirePlumber does not share the problem is read from master only; the upstream change the patch derives from was not read.
- Whether `checkFollowDefault()` should also be skipped for a skipped stream: not examined beyond keeping it as is.
- GNOME 47's six commits (`215289935`, `a74bc5a84`, `bf6f72278`, `afec106a8`, `3aeb837cb`, `0da10f03a`, +68/-75 lines, Sound panel only) apply cleanly to 46.7 and after Ubuntu's 41 patches; not built; no Ubuntu update carries them. On 09-26 the old stream survived (46.7 never re-targeted: the GNOME bug); on 10-24 and 10-29 the Ubuntu patch destroyed the old stream, 46.7 re-targeted, and the patch destroyed the new one. Both fit the same code (inferred).

### Open points and questions for the reviewer

1. Is moving the `was_handled` assignment into the `if` the right and sufficient fix? Consider the skipped branch still calling `checkFollowDefault()`, and the other uses of `was_handled` in the file (lines 709, 766, 793).
2. Could a stream that stays unhandled during the 2 s be linked by some other path (for example another event before the timer) and so defeat the protection?
3. Is the leak test (listening plus policy log) adequate, or is there a better observable?
4. Is this the right shape for an Ubuntu SRU (a patch on top of the previous patch, or an amendment to it)? Does the Ubuntu WirePlumber maintainer need anything beyond the journal lines and this diff?
5. Is the diagnosis of the GNOME side (no retry) accurate enough to stand as a separate note for CO-07?

### Route and next step

The submitter decides when to run the laptop test (about 10 minutes, one user-level file, undone by removing it). After a pass on both conditions: the submitter files a Launchpad report against `wireplumber` for noble with the journal lines, the diff and the test result. CO-07 is retested afterwards (the original 09-26 sequence, not only this one) and stays tracked separately.
