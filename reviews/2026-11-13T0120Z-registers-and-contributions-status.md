# The registers, the bugs and the contributions: where each one stands (2026-11-13 01:20 UTC)

This is a snapshot for the minute in its name. The current record is still `docs/STATUS.md`
(each upstream state), `docs/issues.md` (each bug's evidence) and `contributions/README.md`
(one dossier per contribution). This report reads all three and checks upstream live. It follows
the two reports of 2026-11-12 (`2026-11-12T1508Z-upstream-contributions-status.md`,
`2026-11-12T1537Z-all-contributions-explained.md`) and corrects one finding of the first; see §4.3.

**Checked live for this report (2026-11-13, 00:40–01:20 UTC):**
- **Patchwork:** every pending patch of ours and the watched patches of other authors
  (`scripts/patchwork-state.py`).
- **The linux-bluetooth archive:** the newest 1,500 mails, newest from 2026-11-12, read with
  `scripts/lore-git-replies.py --since 2026-11-01`. It covers every Message-ID in
  `docs/sent-mails.tsv`.
- **Kernel trees:**
  - kernel.org's release list;
  - the Bluetooth commits in stable 7.3.4 and the `net/socket.c` commits in 6.12.117 (GitHub mirror);
  - bluetooth-next at `98bab74158b0` (2026-11-12): its commits since 11-01, and `read_adv_features()` in its `mgmt.c`;
  - mainline, for whether `dc16388d45ec` is in v7.3-rc1 and in v7.2 (`gh api compare`).
- **BlueZ:** master at `20ffd285b` (2026-11-11), searched for reverts of, follow-ups to, or later
  changes in our commits; issues #1554 and #2700.
- **Distributions:**
  - **Ubuntu:**
    - the source changelogs of `linux-hwe-7.0` `7.0.0-43.43~24.04.1` and `linux` `6.8.0-149.149` (changelogs.ubuntu.com);
    - `apt-cache madison`;
    - Launchpad's published BlueZ sources.
  - **Debian:** sources.debian.org.
  - **Fedora:** mdapi.
  - **Arch:** archlinux.org's package JSON.
- **The laptop:** `uname -r`, `modinfo -n btusb`, `/sys/module/btusb/taint`. These are reads only.

**Not re-read today:**
- **The gvfs MRs and issues.** GNOME's GitLab now answers this machine's API calls and pages with
  HTTP 406, so their row is as read on 2026-11-12 15:08 UTC.
- **syzbot's mesh bug,** as of 2026-11-01.
- **The automated review site (Sashiko),** as of 2026-11-01.
- **Release lines of items released before 11-01.** Released code does not go back.

---

## How to read the tables

- **Severity:** what the bug costs a user.
  - **High:** Bluetooth, audio or the daemon is lost until a reconnect, restart or power-off, or there is a crash or memory-safety bug.
  - **Medium:** wrong behaviour that has a workaround.
  - **Low:** tests, diagnostics, log noise or wording.
- **Priority** (for this project):
  - **1:** do next.
  - **2:** after the 1s.
  - **3:** when convenient, or never.
- **Value:** what the contribution gives people other than this laptop's user.
  - **High:** a crash, hang or loss of function fixed for every user of a common component.
  - **Medium:** a real fix with a narrower audience, or a fix to a test or tool many developers use.
  - **Low:** cleanup or wording.
- **Technical readiness:** idea → evidence → reproduced → draft → tested → final.
- **Submission readiness:**
  - **sent:** it is upstream.
  - **ready:** the package is final, and the operator's word is the only gate.
  - **review round:** one more outside review first.
  - **work:** work remains before a send.
  - **n/a:** nothing to submit.
- **Stage** (the lifecycle in STATUS): idea · investigating · reproduced · patch written · ready ·
  sent · accepted · released · in stable · delivered downstream · closed.

The judgements (Severity, Priority, Value) are this report's own, made from the evidence in the
registers. Everything else is a fact from a register or from a live check.

---

## 1. The tables

### 1.1 Every contribution

#### Accepted, released and propagated (ours, or our request for another author's commit)

| # | Contribution | Bugs | Upstream | Stage today | Severity | Value | Propagated to (forward) | Brought back to (backward) |
|---|---|---|---|---|---|---|---|---|
| A1 | `Bluetooth: MGMT: Fix status of pending commands flushed on power off` (ours, `86ef0f58bdec`) | BT-8 (cause of BT-7 site 1) | kernel | released in v7.3; in stable | High | High | Ubuntu 24.04 HWE `7.0.0-43` and GA `6.8.0-149`; Fedora 43 (7.3.4); Debian sid (7.3.4), forky (7.2.15), trixie-backports (7.2.12); Arch (7.2.15) | 7.2.11, 6.18.57, 6.12.113, 6.6.160, 6.1.191; not 5.15/5.10 (never queued) |
| A2 | `adapter: Fix crash on short start discovery reply` (`a734b06059cb`) | BT-7 | BlueZ | released 5.88 | High | High | Arch 5.88; Fedora rawhide 5.88 (F43: in updates-testing); Debian sid/forky 5.88; Ubuntu development series 5.88 | none upstream (BlueZ has no stable branches); Ubuntu 24.04 (5.72) only through CO-03 |
| A3 | `a2dp: Fix crash on NULL stream in transport_cb` (`0bed9886cff3`, + v2 `d84171e6cd68`) | BT-7 | BlueZ | released 5.88 | High | High | as A2 | as A2 |
| A4 | `shared/mgmt: Fix notify leak in mgmt_unregister()` + unit test (`ae23df052290`, `6f5eeb402d3b`) | M-3 | BlueZ | released 5.88 | Medium | Medium | as A2 | none |
| A5 | `emulator: Free hooks in btdev_destroy` (`8da7e648a9fb`) | (found by A6) | BlueZ | released 5.88 | Low | Low | as A2 | none |
| A6 | `mgmt-tester: Add simultaneous discovery stop tests`, three patches (`f3344d20d`, `2942883d2`, `49a70562f`) | BT-9 (regression test) | BlueZ | released 5.88 | Low | Medium (guards a kernel fix) | as A2 | none |
| A7 | `a2dp: Remove duplicate check in transport_cb` (`b79d4a887`) | (cleans up A3) | BlueZ | released 5.88 | Low | Low | as A2 | none |
| A8 | `emulator: Avoid variable length array in send_cmd` (`7bc9684dc`) | (CI noise) | BlueZ | released 5.88 | Low | Low | as A2 | none |
| A9 | `ioctl-tester: Fix name of the 3-DH packet type test` (`3e5b0da969c2`) | BT-12 (CO-34) | BlueZ | released 5.88 | Low | Low | as A2 | none |
| A10 | Stable request for `dc16388d45ec`, the QCA9377 `13d3:3503` entry (another author's commit) | BT-1, BT-2, BT-3 | stable | in every live stable line | High | High | mainline v7.3-rc1; Ubuntu `7.0.0-43` (now running on the laptop) and `6.8.0-149`; Fedora 43; Debian sid/forky/trixie-backports; Arch | 7.2.10, 6.18.56, 6.12.113, 6.6.160, 6.1.191, 5.15.224, 5.10.273 |
| A11 | Stable backports of `96d006ae6445` (another author's fix) to 6.12/6.6/6.1 | BT-9 | stable | released on all three | High | High | Ubuntu GA `6.8.0-149` carries it through its v6.12.113 picks; Ubuntu HWE had it from 6.18.40 | 6.12.113, 6.6.160, 6.1.191 (the three lines that lacked it) |
| A12 | Tested-by on 6.6.160-rc2 (CO-10) | BT-8, BT-9 visible | stable | done; released 10-21 | — | Medium | — | — |
| A13 | Comment on BlueZ issue #1554 pointing to the BT-9 fix | BT-9 | BlueZ tracker | posted 10-09 | — | Medium | — | — |

#### Sent, not accepted: waiting

| # | Contribution | Bugs | Upstream | Sent | Waiting | State now | Severity | Priority | Value | Next |
|---|---|---|---|---|---|---|---|---|---|---|
| S1 | **CO-02** `[PATCH 0/3] Bluetooth: hci_conn: fix SCO connection reuse` + BlueZ `tools/sco-tester: Add SCO reconnect tests` | U7 (and BT-13, U17 nearby) | kernel + BlueZ | 10-27 | 17 days | all four `new`; **no human reply**; the CI closed both mirror pull requests and **mailed (BlueZ test) that the series must be resent to be considered**; an automated review rated patch 2 "fail" alone | High | **1** | High | v2: fold 2+3, port the test, resend (decisions D1/D2) |
| S2 | **CO-25** `[REPORT] btusb: QCA9377 13d3:3503 on ROM firmware …` | BT-1 (root, firmware side) | kernel list / Qualcomm | 10-29 | 15 days since Qualcomm's answer | Qualcomm replied the same day, misreading the device; **our reply v4 unsent**; nothing else on the thread | High (for ROM-only IDs) | 2 | Medium | send the short reply, or let it rest |
| S3 | **X1** gvfs !368, !369, issues #893, #894 | X1 | gvfs | 11-07 | 6 days | open, no comment (as read 11-12) | Medium | 2 | Medium | wait; a ping around 11-28 |
| S4 | Tested-by on another author's mesh_tx leak patch (14831271) | M-1 area | kernel | 10-06 | 38 days (patch: 55) | his patch still `new` | Medium | 3 | Medium | nothing owed |

#### Ready to send: the operator's word is the gate

| # | Contribution | Bugs | Upstream | Severity | Priority | Value | Technical | Submission | What is left |
|---|---|---|---|---|---|---|---|---|---|
| R1 | **CO-35** stable request for `32d86e048d8ef` + `608e0b7a675b2` (another author's) → 7.3.y | BT-10 (BT-15 noted) | stable | Medium | 2 | Medium | final | ready* | *rerun checkpatch and the local CI; not taken by the stable team on its own (absent from 7.3.4) |
| R2 | **CO-22** stable request for two ASUS ROME entries (`cfa67a1dbfd9`, `d54601f21faf`) + a 6.6.y build report | same class as BT-1 | stable | Medium | 2 | High (other laptops) | final (v2) | ready | send; absent from 7.3.4 |
| R3 | **CO-38** `read_adv_features()` hides instances above the instance count | (found by CO-12) | kernel | Low–Medium | 2 | Medium | final + tester case | ready* | *the bug is still at today's tip; a new advertising-set series (11-11, another author) touches nearby code: re-check that it applies |
| R4 | **CO-04** fix for syzbot's mesh_send_sync use-after-free | M-1 area | kernel | High | 2 | High | final, 48 boots clean | review round | competes with 14888791 (still `new`) |
| R5 | **CO-05 + CO-26** mesh advertising list without the lock; lost failed add | M-1 area | kernel | Medium | 3 | Medium | final | review round | may conflict with 14927631 (still `new`) |
| R6 | **CO-37** BlueZ use-after-frees at exit (U23, U24) + 5.72 backport | U23, U24 (U25–U27 found) | BlueZ + Ubuntu | Medium | 2 | Medium | six mails, bot checks pass | ready* | *route decision D3/D13 (one series or two) |
| R7 | **CO-23** BlueZ `a2dp_reconfig()` use-after-free | U22 | BlueZ | High | 2 | High | fix + package | ready | `a2dp.c` unchanged upstream since 11-05 |
| R8 | **CO-11 (a)** Ubuntu SRU: btmon aborts | BT-4 (U28 nearby) | Ubuntu | Medium | 2 | Medium | tested debdiff | ready | the operator files on Launchpad |
| R9 | **CO-03** Ubuntu SRU: bluetoothd loses A2DP + the BT-7 fixes | U12, BT-7 | Ubuntu | High | **1** | High (every 24.04 user) | built, VM 70/70 → 0/70 | work | the laptop test with the MOMENTUM 4 |
| R10 | **CO-19** Ubuntu SRU: PipeWire's codec line in Hands-free | U1 | Ubuntu | Medium | 2 | Medium | built | work | laptop test through the private plugin path (not its two-package plan) |
| R11 | **CO-40** Ubuntu: backport `a6ac17f0e393` ("refused", not "unknown") | U29 | Ubuntu | Low–Medium | 3 | Low–Medium | QEMU-tested | ready | bundle with R8/R9 or file alone |

#### In progress: work remains before a send

| # | Contribution | Bugs | Upstream | Severity | Priority | Value | Technical | What is left |
|---|---|---|---|---|---|---|---|---|
| P1 | **CO-39** BlueZ: non-discoverable reports keep a temporary device alive | U29 | BlueZ | Medium | 2 | Medium | v2 + test (6/6 fail → 7/7 pass) | the bot's CI result (started 11-08, not recorded), readiness summary |
| P2 | **CO-21** btusb: one SCO link going down switches the other to alt 0 | (two-headset audio; a single-link race too) | kernel | Medium–High | 2 | Medium | guest test 0/5 → 5/5 | outside review, bot CI, title fix |
| P3 | **CO-20** btusb: teardown data logged as "corrupted SCO packet" | U8 (kernel part) | kernel | Low | 3 | Low | prototype 22 → 0 | patch and message |
| P4 | **CO-30** RFC: defer a SCO connect until the aborting link is gone | U17 | kernel | Medium | 3 | Medium | prototype | after CO-02's answer |
| P5 | **CO-27** BlueZ: LE-only headset cannot be set up; "Connected" with no audio | U13, U18 | BlueZ | Medium | 2 | Medium | patch candidates | emulator reproducer; #2700 (sibling report) still has no reply |
| P6 | **CO-12** extended-advertising duration overflow | M-2 | kernel | Low–Medium | 3 | Low–Medium | draft clamp | design decision; conflicts with 14927631 |
| P7 | **CO-36** PipeWire: HFP volume resend outlives the link | U15 | PipeWire | Medium | 2 | Medium | reproduced, evidence ready | the operator writes the report |
| P8 | **CO-31** PipeWire: immediate SCO connect retry → 5 s silence | U17 | PipeWire | Medium | 3 | Medium | evidence | the operator writes |
| P9 | **CO-33** PipeWire quirk entries (MOMENTUM 4, Shure AONIC 50) | U15, U20 | PipeWire | High (MOMENTUM 4 microphone silent) | **1** | Medium | entries known | local test, then the operator writes |
| P10 | **CO-32** (+ CO-07) Ubuntu WirePlumber: input meter dies | U19, U6 | Ubuntu | Medium | 2 | Medium | one-line fix drafted | laptop test, then the operator files |
| P11 | **CO-29** Ubuntu WirePlumber 0.4.17 forces Handsfree | U14 | Ubuntu | Medium | 3 | Low–Medium | none | local override first |
| P12 | **CO-08** PipeWire: Tronsmart T8 silent on SBC-XQ | U10 | PipeWire | Low–Medium | 3 | Low | evidence | the decisive A-B test |
| P13 | **CO-42** gnome-bluetooth: a failed setup shows nothing | U29, U13 | GNOME | Medium | 2 | Medium | reproduced, comment drafted | the operator posts on !137 or #18 |
| P14 | **CO-41** BlueZ emulator ignores the refusal reason | (test gap for CO-42) | BlueZ | Low | 3 | Low | idea, one line | patch + tester case |
| P15 | **BT-17 source review** (no CO id yet) | BT-17 | kernel (USB core / btusb), possibly a quirk | High | **1** | High if confirmed | brief out to outside reviewers | their findings; a recurrence with USB core debug |

#### Possible future (blocked, ideas, or registered only)

| # | Item | Bugs | Upstream | Severity | Priority | Why it waits |
|---|---|---|---|---|---|---|
| F1 | BT-16: controller starts "already patched" (8 candidate defects) | BT-16 | kernel, GNOME | High | **1** | cause unknown; needs the status byte at a failing boot |
| F2 | BT-13: `hci_connect_sco()` drops a hold it never took | BT-13 | kernel | Low | 3 | after CO-02 |
| F3 | U16: a failed Connect stops device search for good | U16 | BlueZ, GNOME | Medium | 2 | reproducer; another author's kernel commit `60b10121db60` ("MGMT: Fix discovery stuck after a failed Stop Discovery", bluetooth-next 11-02) is nearby and not yet compared |
| F4 | U28: btmon overflow at ≥ 2048 columns | U28 | BlueZ | Low | 3 | not reproduced with the binary |
| F5 | U30: PipeWire sends out-of-range HFP gains | U30 | PipeWire | Low–Medium | 3 | first trace only |
| F6 | U31: gsd-media-keys assertions | U31 | GNOME | Low | 3 | no visible effect |
| F7 | CO-13 mesh "Count"; CO-14 mesh at device removal | M-1 area | kernel | Low / Medium | 3 | after CO-04/05 |
| F8 | CO-06 review reply on another author's mesh power-off fix | M-1 area | kernel | Medium | 3 | that patch is idle (still `new`) |
| F9 | CO-01 test another author's SCO series | U7 area | kernel | Medium | 3 | no v4 upstream |
| F10 | CO-15, CO-16, CO-17 | U11/U3, U9, U2/U4 | WirePlumber, BlueZ, GNOME | Low–Medium | 3 | by design upstream, or a short test |
| F11 | X2–X4 gvfs cdda | X2, X3, X4 | gvfs | Low | 3 | after !368/!369 |
| F12 | BT-15: SCI fix `5874f8d03268` into 7.3.y | BT-15 | stable | Low | 3 | not in 7.3.4; watch |
| F13 | U25, U26, U27: more A2DP endpoint teardown use-after-frees | U25–U27 | BlueZ | Medium | 3 | with or after CO-37 |
| F14 | U21: no codec row after a re-pair | U21 | GNOME / WirePlumber | Medium | 3 | evidence only |

#### Closed

| # | Item | How it ended |
|---|---|---|
| C1 | CO-09 the entry in Ubuntu's kernel | Ubuntu's own `7.0.0-43` carries it. It is in noble-updates and noble-security, and since the 11-12 power-off **the laptop runs it with its stock btusb** (`modinfo -n btusb` → `/lib/modules/7.0.0-43-generic/kernel/…`, empty taint) |
| C2 | CO-10, CO-34 | done (A12, A9) |
| C3 | CO-18 earbuds silent in mSBC (U8) | not a kernel defect; the earbuds' side |
| C4 | CO-24 default codec (U5) | answered from source |
| C5 | CO-28 Tested-by on 6.1/5.15/5.10 | deadlines passed; released with our backports |

### 1.2 Every bug in the registers

"Contribution" names the row in §1.1. Upstream state is as of this report.

| Bug | What | Component | Severity | State | Upstream | Contribution | Priority |
|---|---|---|---|---|---|---|---|
| BT-1 | Controller stops answering after a transparent SCO stream starts | QCA ROM firmware / btusb table | High | confirmed cause; fixed | `dc16388d45ec`, all stable lines, Ubuntu `-43` | A10, S2, R2 (other IDs), C1 | done |
| BT-2 | Opening the panel causes a 16 s HCI desync | (same cause as BT-1) | Medium | fixed with BT-1 | as BT-1 | A10 | done |
| BT-3 | `13d3:3503` absent from btusb's table | btusb | — | superseded into BT-1 | as BT-1 | A10 | — |
| BT-4 | btmon aborts while capturing | BlueZ 5.72 | Medium | fixed upstream, not in 24.04 | two upstream fixes | R8 | 2 |
| BT-5 | SCO link carries almost no data | — | — | superseded | — | — | — |
| BT-6 | ACL data for an unknown handle | kernel / controller | Low | observed; benign race | — | — | — |
| BT-7 | bluetoothd NULL dereference at two sites | BlueZ | High | released 5.88 | A2, A3 | A2, A3, A7; R9 for 24.04 | done (Ubuntu: 1) |
| BT-8 | Flushed MGMT commands get a status read from the wrong object | kernel MGMT | High | in stable; in Ubuntu | A1 | A1 | done |
| BT-9 | Simultaneous discovery never stops; scans refused Busy | kernel | High | in stable; in Ubuntu | `96d006ae6445` + A11 | A11, A6, A13 | done |
| BT-10 | l2cap-tester ECRED deferred-accept hang | kernel L2CAP | Medium | fixed in mainline, not in stable | `32d86e048d8ef` | R1 | 2 |
| BT-11 | KASAN use-after-free in `iso_conn_hold_unless_zero` | kernel ISO (Ubuntu's code) | Medium | apparently fixed upstream | candidates named, not identified | — | 3 |
| BT-12 | ioctl-tester: two cases under one name | BlueZ test | Low | released 5.88 | A9 | A9 | done |
| BT-13 | `hci_connect_sco()` drops a hold it never took | kernel | Low | confirmed in source | — | F2 | 3 |
| BT-14 | 6.12.114: every L2CAP `getsockopt()` fails | stable 6.12.y | Medium | fixed by another author | `4b26b1d3a94c` on 6.12.y (10-30) | — | done |
| BT-15 | 7.3: l2cap-tester SCI stall | stable 7.3.y | Low | fixed in mainline only | not in 7.3.4 | F12 | 3 |
| BT-16 | Controller starts "already patched"; no Bluetooth all boot | QCA start-up / btusb | High | observed twice; cause unknown | — | F1 | **1** |
| BT-17 | Idle controller never resumed from runtime suspend; reset off the bus | QCA9377 + USB runtime PM on Ryzen; reset path | High | observed once; hypotheses H1–H3 | candidate relation: `dcaf83ead130` | P15 | **1** |
| M-1 | Mesh transmission never stops advertising; done path completes the wrong request | kernel MGMT | Medium | patch written (v3), split | other authors' four fixes all `new` | R4, R5, S4, F7, F8 | 2 |
| M-2 | Advertising duration overflows above 65 s | kernel hci_sync | Low–Medium | confirmed | — | P6, R3 | 3 |
| M-3 | `mgmt_unregister()` from a callback leaks / use-after-free | BlueZ | Medium | released 5.88 | A4 | A4 | done |
| U1 | First codec line in Hands-free unselectable | PipeWire 1.0.5 | Medium | fixed upstream 1.2 | `805e5cf9c` | R10 | 2 |
| U2 | Volume oddities after a profile switch | WirePlumber / headset | Low | explained (MOMENTUM 4: U15) | — | F10 | 3 |
| U3 | Profile priority comparison | WirePlumber | — | design | — | — | — |
| U4 | Codec row disappears | GNOME Settings 46.7 | Low–Medium | observed | no fix for 46 | F10 | 3 |
| U5 | Hands-free picks CVSD | — | — | withdrawn | — | C4 | — |
| U6 | Input meter does not follow the input | GNOME Settings 46 | Medium | fixed in GNOME 47 | six commits | P10 (with CO-32) | 2 |
| U7 | New SCO link after a codec switch never set up | kernel (and PipeWire) | High | confirmed race; fix sent | — | S1, P4, F9 | **1** |
| U8 | Earbuds silent in mSBC; "corrupted SCO packet" | earbuds; btusb log | Low | earbuds' side | — | C3, P3 | 3 |
| U9 | No reconnect after rfkill off/on | BlueZ policy | Low | design | #294 closed | F10 | 3 |
| U10 | Tronsmart T8 silent on SBC-XQ | PipeWire / speaker | Low–Medium | observed | — | P12 | 3 |
| U11 | New headset does not get the sound | WirePlumber | Low–Medium | by design | — | F10 | 3 |
| U12 | An app opening the microphone loses A2DP | BlueZ 5.72 | High | fixed upstream 5.80, not in 24.04 | — | R9 | **1** |
| U13 | LE-only headset cannot be set up | BlueZ; GNOME | Medium | confirmed; not fixed | #2700 open, no reply | P5, P13 | 2 |
| U14 | Headset forced into Handsfree by any recording | WirePlumber 0.4.17 | Medium | fixed by the 0.5 rewrite | — | P11 | 3 |
| U15 | MOMENTUM 4 "mute on"; microphone silent | PipeWire hw volume + headset | High | confirmed | — | P7, P9 | **1** |
| U16 | Device search stops after a failed Connect | BlueZ 5.72 | Medium | traced in source | — | F3 | 2 |
| U17 | 5 s silence after a refused SCO connect | PipeWire / WirePlumber (with CO-02) | Medium | confirmed | — | P4, P8 | 3 |
| U18 | LE-paired headset "Connected" with no audio | BlueZ | Medium | confirmed | — | P5 | 2 |
| U19 | Sound panel's input meter dies after Handsfree | Ubuntu WirePlumber patch | Medium | confirmed; Ubuntu-only | — | P10 | 2 |
| U20 | Shure's input slider has no effect | PipeWire / headset | Medium | registered | — | P9 | 2 |
| U21 | No codec row after a re-pair | GNOME / WirePlumber | Medium | observed | — | F14 | 3 |
| U22 | bluetoothd bad `free()` in `a2dp_reconfig()` | BlueZ | High | confirmed; not fixed upstream | — | R7 | 2 |
| U23 | Use-after-free in `clear_endpoint` at exit | BlueZ | Medium | confirmed on master | — | R6 | 2 |
| U24 | Use-after-free in `device_set_rssi_with_delta` at exit | BlueZ | Medium | fixed upstream, unreleased | `7e3212fa233e` | R6 (5.72 backport) | 2 |
| U25 | SEGV in `a2dp_sep_unlock` | BlueZ | Medium | found; not fixed | — | F13 | 3 |
| U26 | Use-after-free in `a2dp_remove_sep` | BlueZ | Medium | found; not fixed | — | F13 | 3 |
| U27 | 5.72-only `clear_endpoint` use-after-free | BlueZ 5.72 | Medium | found; not covered by CO-37 | — | F13 | 3 |
| U28 | btmon can still overflow at ≥ 2048 columns | BlueZ | Low | source reading | — | F4 | 3 |
| U29 | Headset forgot the key; setup clicks did nothing | headset; gnome-bluetooth; BlueZ | Medium | traced; four candidates | `a6ac17f0e393` (one part) | P1, R11, P13, P14 | 2 |
| U30 | Out-of-range HFP gains | PipeWire | Low–Medium | observed | — | F5 | 3 |
| U31 | gsd-media-keys assertions | libgnome-volume-control | Low | observed | — | F6 | 3 |
| X1 | Audio CD stalls every 16 s; invalid track names | gvfs | Medium | sent | !368, !369 open | S3 | 2 |
| X2 | GError leaks | gvfs | Low | confirmed | — | F11 | 3 |
| X3 | Tracks assumed numbered from 1 | gvfs | Low | hypothesis | — | F11 | 3 |
| X4 | Failed seek ignored | gvfs | Low | observed (injection) | — | F11 | 3 |

### 1.3 Counts

| | Count |
|---|---|
| Accepted and released, ours | 1 kernel commit (A1); 12 BlueZ commits (A2–A9: A3 and A4 two each, A6 three; yesterday's "eleven" was one short) |
| Accepted, our request for other authors' commits | 2 stable requests (A10: 7 lines; A11: 3 lines) |
| Reports and comments, done | 2 (A12, A13) |
| Sent and waiting | 4 (S1–S4); S1 now needs a resend |
| Ready, the operator's word only | 7 (R2, R3, R7, R8, R11, and R1/R6 after small steps) |
| Ready but blocked by a review round or a laptop test | 4 (R4, R5, R9, R10) |
| In progress | 15 (P1–P15) |
| Possible future | 14 (F1–F14) |
| Bugs registered | 17 BT, 3 M, 31 U, 4 X = 55; 14 need nothing more upstream (8 fixed, 2 superseded, 1 withdrawn, 3 by design) |

---

## 2. The overall picture

**What was delivered, and where it is now.**
- **The laptop's original hang (BT-1) is fixed by another author's device-table entry.** Our
  stable request carried it to every maintained kernel line within a month.
- **Ubuntu now ships it in both 24.04 kernels.** This is new since yesterday:
  - the HWE `7.0.0-43`, through v7.2.10;
  - the GA `6.8.0-149`, through its v6.12.113 picks.
- **The laptop has run Ubuntu's own kernel since the power-off of 11-12**, with the stock btusb.
  The locally built module (E3) is no longer loaded.
- **Our one kernel commit (A1, BT-8) is in the same two Ubuntu kernels, and the BT-9 discovery fix
  is in the GA kernel.** That kernel got the BT-9 fix only because our backport put it into
  6.12.113.
- **All twelve of our BlueZ commits are in BlueZ 5.88** (11-05). Five days later it is in Arch, Fedora
  rawhide (F43 testing), Debian unstable/testing and Ubuntu's development series.
- **What has not got them:**
  - Ubuntu 24.04 (BlueZ 5.72) and 26.04 (5.85);
  - Debian 13 (BlueZ 5.82; kernel 6.12.107, six stable releases before the fixes) and Debian 12 (kernel 6.1.176).
- **For 24.04, CO-03 is the route.** It also carries the U12 fix that matters most here.

**Nobody has discussed the accepted work since it was applied.**
- No mail on the list answers any of our accepted patches after the maintainers' "applied" notes.
- No commit in mainline or BlueZ master reverts them or names them in a `Fixes:` tag.
- The only later change to our code is the maintainer's conversion of A4's test file to the
  tester framework (10-08), with cases unchanged.

**What is hanging.**
- **CO-02, the one substantive kernel series still out.** It has had no human reply in 17 days.
  New today: the CI's bot mailed on 11-12 00:36 UTC that the BlueZ test's mirror pull request
  was closed after two weeks and that "it must be resent … so that it is picked up again". This
  settles what yesterday's report left open: the closures were a two-week staleness rule, not a
  query failure.
  - The series is still `new` in patchwork, but in practice it now needs a resend.
  - The natural resend is the v2 already planned: patches 2 and 3 folded, which also answers the
    automated review, and the test ported.
- **CO-25.** Our clarifying reply to Qualcomm has been ready for 15 days.
- **The gvfs MRs.** Six days without a comment, which is normal there.

**Where the remaining value is.** Ordered by what it does for users, not by how ready it is:
1. **U12/CO-03 and U15/CO-33 hurt this laptop's daily use now.**
   - U12: A2DP is lost whenever an app opens the microphone.
   - U15: the MOMENTUM 4's microphone sends silence.
   - Both are fixes for every Ubuntu 24.04 user of these paths.
2. **BT-16 and BT-17, the two new controller losses, both on the patched firmware.**
   - **BT-17:** the outside source review now under way is the next step, and USB core debug at
     a recurrence would decide its hypotheses.
   - **BT-16:** needs one failing boot with the status byte recorded.
3. **CO-02 v2.** The largest pending kernel change; a race fix for silent call audio.
4. **Ready packages that are cheap to send and likely to be taken.**
   - CO-22, CO-38 and CO-35: stable requests and a one-line fix.
   - CO-23 and CO-37: BlueZ use-after-frees with reproducers.
   - CO-11a: the btmon SRU.
5. **Mesh (CO-04/05/26).** Correct and tested, but upstream's mesh queue is stalled: four other
   authors' fixes have waited 30–55 days with no maintainer reply.

**How the bugs connect.** Most items descend from a few roots:
1. **BT-1's fix.**
   - It exposed BT-9, so the stable backports and BlueZ's regression test followed.
   - BT-8 caused BT-7's first crash site.
   - CO-25 and CO-22 follow BT-1's firmware cause outward.
   - BT-16 and BT-17 happen only with the fix's patched-firmware path. BT-17's reset path is set
     by the same ROME flag.
2. **The SCO-reuse race (U7).**
   - It gave CO-02.
   - Reviewing CO-02 found BT-13.
   - CO-02 then exposed U17 (PipeWire's retry timing), hence CO-30 and CO-31.
3. **The mesh investigation.**
   - It gave M-1, M-2 and M-3: A4 was sent, CO-04, CO-05 and CO-26 are ready.
   - Testing M-2 found CO-38.
4. **The audio stack's daily-use failures.** U12, U14, U15, U19 and U20 are each a separate
   component (BlueZ, WirePlumber, PipeWire, Ubuntu's patch, the headset), but they show up
   together around one action: starting dictation or a call on a headset.

---

## 3. Each item in detail

### 3.1 Accepted work: forward propagation, backward propagation, discussion

**A1: our kernel commit (BT-8).**
- **What it fixes.** When the adapter powers off, the kernel answers every pending management
  command. Since `f53e1c9c726d` it read the status from the wrong object, so each got "Success".
  bluetoothd 5.72 then read a reply that was not there and crashed (BT-7's first site).
- **Into mainline.** Applied to bluetooth-next on 09-29; released in v7.3, first in v7.3-rc7.
- **Backward, into stable.** Its `Cc: stable` brought it into 7.2.11, 6.18.57 and 6.12.113
  (10-15), 6.6.160 (10-21) and 6.1.191 (10-30). The stable team never queued 5.15 and 5.10.
- **Forward, into Ubuntu.** Both Ubuntu 24.04 kernels list it in their changelogs:
  - `7.0.0-43` at line 137, from "Upstream stable to v6.18.57, v7.2.11";
  - `6.8.0-149` at line 439, from its "v6.6.159, v6.12.113" picks.
- **Into other distributions.**
  - Fedora 43 (7.3.4), Debian sid (7.3.4), forky (7.2.15) and trixie-backports (7.2.12), and Arch
    (7.2.15) all carry it.
  - Debian 13's own kernel (6.12.107) and Debian 12's (6.1.176) do not yet.
- **Discussion:**
  - no reply on the thread after it was applied;
  - no `Fixes:` tag naming it in mainline (GitHub commit search for the hash: the commit itself only);
  - no revert.

**A2, A3, A7: the two bluetoothd crashes (BT-7) and their cleanup.**
- Applied 09-21 (A2, A3) and 10-19 (A7). Released in BlueZ 5.88 (tagged 11-05).
- **Forward:**
  - Arch 5.88-1 (11-10);
  - Fedora rawhide 5.88-2.fc46, and F43 5.88-1 in updates-testing;
  - Debian sid and forky 5.88-1;
  - Ubuntu's development series 5.88-1 (published 11-07).
- **Not reached:**
  - Ubuntu 24.04 (5.72-0ubuntu5.8), 25.10 (5.83) and 26.04 (5.85-4ubuntu0.4, with 0ubuntu0.5 in proposed);
  - Debian 13 (5.82).
- **Backward:** BlueZ has no stable branches, so a backport means a distribution update. For
  24.04 that is CO-03, which carries A2 and A3 with U12's fix.
- **Discussion.** None. A3 was applied twice (v1 and v2), and A7 removed the duplicate.

**A4: `mgmt_unregister()` (M-3).** Applied unchanged 10-08. The maintainer then moved its unit
test to the tester framework (`866b0b8b1`), with the same cases. Released in 5.88, with the same
reach as A2. No follow-up.

**A5, A6: BT-9's regression test, and the leak it exposed.** Applied 10-12. Released in 5.88. They
guard BT-9's kernel fix in BlueZ's own CI. No follow-up.

**A8, A9: two small fixes.** A8 removes the emulator array that made the CI warn on every
emulator patch. A9 fixes the duplicate test name. Applied 10-19 and 10-28. Released in 5.88.

**A10: the QCA9377 entry `dc16388d45ec` (another author's commit, our stable request).**
- **Mainline.** In v7.3-rc1, not in v7.2 (checked today).
- **Backward.** Our request of 10-02 was queued the same day for seven lines and released in all
  of them: 7.2.10, 6.18.56, 6.12.113, 6.6.160, 6.1.191, 5.15.224, 5.10.273.
- **Forward, Ubuntu.** `7.0.0-43` changelog line 415, from v7.2.10. `6.8.0-149` line 35. Both are in
  noble-updates and noble-security.
- **Forward, this laptop.** Since 11-12 it runs `7.0.0-43-generic` with that kernel's own btusb, so
  CO-09 has closed in practice. Whether the E3 tooling is now retired is the operator's call.
- **Forward, other distributions.** Fedora, Arch and Debian sid/forky/backports carry it. Debian
  13 (6.12.107) and 12 (6.1.176) do not yet.
- **Discussion.** None after the queue reply.
- **Related, sent separately.** CO-25 asks Qualcomm about the firmware itself (S2).

**A11: BT-9's fix on 6.12, 6.6 and 6.1.**
- Released in 6.12.113, 6.6.160 and 6.1.191.
- Ubuntu's GA `6.8.0-149` lists it (changelog line 367) through its 6.12.113 picks, which carry
  our backport. Ubuntu's HWE kernel had it earlier from 6.18.40.
- It matters because A10 sets the quirk that exposes BT-9: without A11, A10 would have traded
  one fault for another on those lines.

**A12, A13.** A12 was a test report and needs no answer. On A13, BlueZ issue #1554, the second
affected user last wrote 10-14 ("will check"); nothing since.

### 3.2 Sent and hanging

**S1: CO-02, SCO connection reuse (U7).**
- **The fault.** After a codec switch during a call, the kernel hands the new voice connection the
  old one, which is still being torn down. The audio goes silent: 3 of 3 times on the Lenovo
  earbuds, never on slower headsets.
- **The series.** Three kernel patches with `Cc: stable`, plus a BlueZ sco-tester test.
- **Patchwork today.** 14919266–68 and 14919269 are all `new`, with comments from the bot only.
- **The list.** The only reply since 11-01 is the CI's mail of 11-12 00:36 UTC on the BlueZ test:
  the series "was never applied", its pull request #2724 "has been closed", and "if the change
  should still be considered, it must be resent". The kernel series' pull request #1009 was
  closed 38 minutes earlier, and no such mail for it is in the archive.
- **Technical state:**
  - The kernel series still applies to bluetooth-next: `hci_conn.c` and `hci_core.h` have no
    commit after `c9644a9257d1`, where yesterday's three-way check passed.
  - The BlueZ test needs a port to the converted sco-tester (`e37f17751`, 10-29).
  - The automated review's "fail" on patch 2 alone stands. Folding patches 2 and 3 answers it.
  - An air-mode mismatch check is written and tested as a separate patch.
- **Submission readiness: work.** v2 = the fold + the port + a shorter cover letter, then the
  local CI on base and base+v2, then the operator's word (decisions D1, D2).
- **Value: High.** Silent call audio on fast-answering headsets, on every kernel since the reuse
  path was added.

**S2: CO-25, the report to Qualcomm.**
- Sent 10-29. Zijun Hu (Qualcomm) answered the same day that QCA9377 is not ROME and that btusb does
  not support it. The laptop's boot log, btusb's table and linux-firmware show the opposite.
- Our reply v4, which quotes the kernel's own `QCA: patch rome 0x302 build 0x3e8` line, has been
  ready since 11-02. Nothing else has come on the thread.
- **Relation to BT-17.** The new BT-17 evidence is another reason a Qualcomm contact could help:
  an idle ROME controller that did not wake. It is not part of the drafted reply, and adding it
  is a choice for the operator.

**S3: X1, gvfs.** As read 11-12 15:08 UTC: !368 and !369 open, `MERGEABLE`, pipelines passed, no
comment, no reviewer; issues #893 and #894 open. It has been six days. A ping around 11-28 is
reasonable.

**S4: the Tested-by on Hui Peng's mesh_tx leak patch.**
- His patch (14831271, 09-19) is still `new`.
- So are the other authors' mesh fixes:
  - Jiale Yao 14864878 (10-03);
  - Cen Zhang 14880941 (10-12) and 14927631 (10-30);
  - Igor Putko 14888791 (10-14).
- Nothing is owed. This stall is the context for R4 and R5.

### 3.3 Ready packages

**R1 CO-35 (BT-10).**
- **The bug.** An L2CAP socket deadlocks on its own lock in a deferred ECRED accept. It has been
  present since v6.3.
- **The fix.** Pauli Virtanen fixed it in mainline (7.4 merge window) with no `Cc: stable`.
- **Stable today.** Absent from 7.3.4, so a request is still needed (7.3.y only; 7.2.y has ended).
- **To do before the send:** a checkpatch run and the local CI.

**R2 CO-22.**
- **The request.** The two ASUS ROME entries are in mainline and in no stable branch, and still
  absent from 7.3.4.
- **The package.** Request v2 plus a 6.6.y build report are ready.
- **Value: High.** Same class as BT-1, for other laptops. A second mail asking owners of ten
  likely ROME IDs for data is also drafted.

**R3 CO-38.**
- **The bug.** `read_adv_features()` still compares each instance number with
  `adv_instance_cnt` at today's tip (`mgmt.c:8892` at `98bab74158b0`).
- **New upstream since the package was made.** Weihong Guan's advertising-set series (11-11: `hci_free_adv_instance()`, removal by handle) changes nearby code.
- **Before sending:** re-apply and re-run its tester case.

**R4 CO-04, R5 CO-05 + CO-26: mesh.**
- Final packages on `1081a6ef8f1e0`.
- Each needs one outside review round, and a decision on how to send into a queue where four
  other fixes wait.
- CO-04 competes with 14888791. That patch's lock inversion showed in 8 of 12 boots here.

**R6 CO-37 (U23, U24).** Six mails; bot checks pass. Open: one series or two, and the 5.72 route.

**R7 CO-23 (U22).** A daemon crash seen on the laptop (09-08), reproduced under ASan. `a2dp.c`
is unchanged on master since 11-05, so the fix still applies as written.

**R8 CO-11a (BT-4).** The btmon SRU needs both upstream fixes. The debdiff and the Launchpad text
are ready. The operator files.

**R9 CO-03 (U12 + BT-7).**
- **The package.** Built and VM-tested: 70 of 70 losses become 0 of 70.
- **The gate.** The laptop test with the MOMENTUM 4, in the ~2-hour headset session checklist.
- **Value.** The highest of the Ubuntu items.

**R10 CO-19 (U1).** Built. It must be tested through the private plugin path: its two-package
install plan would remove ten audio packages.

**R11 CO-40.** Small; best bundled with R8/R9.

### 3.4 In progress

These rows are unchanged from yesterday's explanations, apart from the notes below.

**P1 CO-39.** The bot CI run's result still has to be recorded. `src/adapter.c` is unchanged
upstream since 5.88, so the patch base holds.

**P5 CO-27.** The sibling report BlueZ #2700 is still open with 0 comments (last update 10-22).

**P15 BT-17, new.**
- **The incident.** On 11-12 at 18:00:28 the idle controller was runtime-suspended. At the login
  at 18:03:08 the first command found it not resumed. The USB core's reset-resume (H1) and
  btusb's own reset (H2) then drove it off the bus, and only the power-off recovered it.
- **The candidate.** Mainline `dcaf83ead130` applies a wakeup quirk to MediaTek chips on Ryzen
  laptops whose Bluetooth sits directly on the root hub. This laptop is that platform with a QCA
  chip (H3).
- **The review.** A self-contained source-review brief (`2026-11-13T0003Z-bt17-source-investigation-task.md`)
  is out to outside reviewers.
- **The possible outcomes:**
  - an extension of that quirk to QCA ROME;
  - a btusb/USB core patch;
  - a report.
- **Which of them is decided by:** the review's findings and one recurrence with USB core debug
  on (the operator's call).
- **On the platform it now runs:** a recurrence on `7.0.0-43` with the stock btusb would also
  show that E3 played no part.

### 3.5 Bugs without a contribution yet, and their relations

- **BT-16** (twice in 12 boots on E3) and **BT-17** (once in nine trials) are the two open
  controller losses. Both happen on the patched-firmware path that BT-1's fix enables. Both
  are High and priority 1.
  - BT-16 is a start-up fault: the controller claims a patch already loaded.
  - BT-17 is an idle-wakeup fault.
  - Nothing yet links the two beyond the device and the patched firmware path.
- **U16** (device search stops after a failed Connect) has its cause traced in BlueZ's discovery
  bookkeeping. Another author's kernel commit `60b10121db60` (bluetooth-next, 11-02, "MGMT: Fix
  discovery stuck after a failed Stop Discovery") is in the same area. Whether it covers any of
  U16 has not been checked; that comparison is the next step.
- **BT-11** (an ISO use-after-free on Ubuntu's code) appears fixed upstream. The fixing commit is
  not yet identified, and identifying it would make an Ubuntu backport candidate.
- **U25–U27** grew out of the CO-37 work and wait for it.

---

## 4. Since yesterday's reports (2026-11-12 15:08 and 15:37 UTC)

1. **BT-17 registered and investigated.**
   - The controller was runtime-suspended and never resumed.
   - Hypotheses H1–H3, with the Ryzen quirk as candidate.
   - The review brief is out (`1057d2e`).
2. **Ubuntu delivery.**
   - Both 24.04 kernels, `7.0.0-43` and `6.8.0-149`, carry A1, A10 and the BT-9 fix (`7.0.0-43`'s
     came from 6.18.40, not our backport).
   - The laptop now runs `7.0.0-43` with its stock btusb.
3. **The CI's pull-request closures explained (this corrects yesterday's §3).**
   - The bot's mail of 11-12 00:36 UTC states the rule: a series picked up more than two weeks
     ago and never applied has its pull request closed and "must be resent".
   - Yesterday's report read the CI's code as closing only series that patchwork no longer lists
     as `new`, and left the cause open. The mail settles it.
   - The kernel series' pull request was closed by the same sweep.
4. **BlueZ 5.88 reached** Arch, Fedora rawhide and F43 testing, Debian sid/forky, and Ubuntu's
   development series.
5. **Stable releases of 11-06 and 11-10** (7.3.4, 6.18.63, 6.12.117, 6.6.162, 6.1.192, 5.15.225,
   5.10.274).
   - None of our pending stable items arrived on its own: CO-35's pair, CO-22's pair and BT-15's
     fix are all absent from 7.3.4.
   - BT-14's fix is on 6.12.y (another author's).
6. **bluetooth-next moved to `98bab74158b0`** (about 55 commits since 11-01, none ours).
   - CO-38's bug is still there.
   - A new advertising-set series touches R3/R5/P6's area.
7. **This repository's CI.** It was red on the last three pushes because
   `results/incident-2026-11-12-1803/tools/excerpts.py` was not executable. That is fixed in the
   commit that adds this report.

## 5. Decisions waiting for the operator

1. **CO-02:** prepare and send v2. The CI now requires a resend in any case.
2. **CO-25:** send the drafted reply v4, or let it rest.
3. **The headset session** (~2 h): CO-03 (priority 1), CO-33 (priority 1), CO-19, CO-32/07, CO-08.
4. **The cheap, likely sends:** CO-22, CO-38 (after a re-apply), CO-35 (after checkpatch and CI),
   CO-23, CO-11a.
5. **BT-17:** USB core dynamic debug for the next occurrence, and whether to apply the autosuspend
   mitigation meanwhile.
6. **E3:** whether to retire it formally, now that the laptop runs Ubuntu's own kernel with the
   entry.
7. **A regular check:** the commands in this report's header, run at the start of each session.
   It would have caught the CI's resend mail a day earlier.
