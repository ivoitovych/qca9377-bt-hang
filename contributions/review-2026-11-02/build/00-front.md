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
