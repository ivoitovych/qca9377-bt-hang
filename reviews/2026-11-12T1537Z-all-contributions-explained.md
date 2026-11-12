# Every contribution, past, present and possible, explained (2026-11-12 15:37 UTC)

A snapshot for reading and thinking, valid at the minute in its name. Upstream states were read
live at 15:03–15:08 UTC the same day
([the status check](https://github.com/ivoitovych/qca9377-bt-hang/blob/main/reviews/2026-11-12T1508Z-upstream-contributions-status.md));
everything else comes from the project's registers, reconciled the same afternoon. The current
record stays [docs/STATUS.md](https://github.com/ivoitovych/qca9377-bt-hang/blob/main/docs/STATUS.md)
and the [contributions index](https://github.com/ivoitovych/qca9377-bt-hang/blob/main/contributions/README.md).

**How to read the tables.** Three columns are judgements, not measurements, made for this report:
- **Severity** — what the defect costs a user: **High** = Bluetooth, audio or the daemon lost
  until a restart or power-off, or a crash; **Medium** = wrong behaviour with a workaround;
  **Low** = test infrastructure, diagnostics, wording.
- **Chance** — of being accepted upstream as it stands: **High / Medium / Low**, with the reason
  in the text. For items already accepted the column says *done*.
- **Priority** — **1** do next, **2** after the 1s, **3** when convenient or never.

The other columns are facts from the records: **Stage** (idea → investigating → reproduced →
patch written → ready → sent → accepted → released), **Patch** (none / draft / tested / final),
**Review** (outside reviews done before sending, and upstream review after), **Obstacle / next**.

---

## 1. Tables

### 1.1 Accepted upstream (ours)

| # | Contribution | Upstream | Severity | Stage | Upstream ID | Sent → applied |
|---|---|---|---|---|---|---|
| A1 | MGMT: pending commands flushed at power-off get the right status (BT-8) | Linux kernel | High (crashed bluetoothd) | released: v7.3; stable 7.2.11, 6.18.57, 6.12.113, 6.6.160, 6.1.191 | `86ef0f58bdec` | 09-24 → 09-29 |
| A2 | adapter: crash on a short Start Discovery reply (BT-7) | BlueZ | High (daemon crash) | released 5.88 | `a734b06059cb` | 09-19 → 09-21 |
| A3 | a2dp: crash on a NULL stream in transport_cb (BT-7) | BlueZ | High (daemon crash) | released 5.88 | `0bed9886cff3` (+ v2 `d84171e6cd68`) | 09-19 → 09-21 |
| A4 | shared/mgmt: notify leak / use-after-free in mgmt_unregister() + unit test (M-3) | BlueZ | Medium (leak; crash for callers that hit it) | released 5.88 | `ae23df052290`, `6f5eeb402d3b` | 10-08 → 10-08 |
| A5 | emulator: free hooks in btdev_destroy | BlueZ | Low (test leak) | released 5.88 | `8da7e648a9fb` | 10-10 → 10-12 |
| A6 | mgmt-tester: simultaneous-discovery stop tests (3 patches; BT-9's regression test) | BlueZ | Low (test) | released 5.88 | `f3344d20d904`, `2942883d2738`, `49a70562f0bf` | 10-10 → 10-12 |
| A7 | a2dp: remove the duplicate check (cleanup of A3's double apply) | BlueZ | Low | released 5.88 | `b79d4a887` | 10-18 → 10-19 |
| A8 | emulator: avoid a variable-length array in send_cmd | BlueZ | Low (CI noise) | released 5.88 | `7bc9684dc` | 10-18 → 10-19 |
| A9 | ioctl-tester: fix the 3-DH test's name (BT-12, CO-34) | BlueZ | Low (test) | released 5.88 | `3e5b0da969c2` | 10-28 → 10-28 |
| A10 | Stable request: the QCA9377 device-table entry `dc16388d45ec` (BT-1; another author's commit) | Linux stable | High (the original hang) | released in every live line: 7.2.10, 6.18.56, 6.12.113, 6.6.160, 6.1.191, 5.15.224, 5.10.273 | request mail | 10-02 → queued 10-02 |
| A11 | Stable backports of `96d006ae6445` (BT-9; another author's fix) to 6.12, 6.6, 6.1 | Linux stable | High (scanning refused until power-off) | released 6.12.113, 6.6.160, 6.1.191 | three mails | 10-10 → queued 10-11 |
| A12 | Tested-by on 6.6.160-rc2 (CO-10) | Linux stable | — (a test report) | done; 6.6.160 released | mail | 10-21 |
| A13 | Comment on BlueZ issue #1554 pointing to the BT-9 fix | BlueZ tracker | — | posted; another user answered 10-14 | comment | 10-09 |

### 1.2 Sent, not yet accepted

| # | Contribution | Upstream | Severity | Chance | Priority | Stage | Patch | Review | Obstacle / next |
|---|---|---|---|---|---|---|---|---|---|
| S1 | **CO-02** SCO connection reuse: 3 kernel patches + BlueZ test (U7) | kernel + BlueZ | High (silent call audio after a codec switch on some headsets) | Medium | **1** | sent 10-27, no human reply in 16 days | final v1; v2 owed | 6 outside reviews; automated review: patch 2 incomplete alone | v2: fold 2 and 3, port the BlueZ test, shorter cover |
| S2 | **CO-25** report to Qualcomm on the ROM firmware hang | kernel list (Qualcomm) | High (root of BT-1, already fixed host-side) | — (a report) | **1** | sent 10-29; Qualcomm answered 10-29 and misread it | reply v4 ready | 10 rounds before send; reply reviewed | send or drop our reply |
| S3 | **X1** gvfs audio-CD fixes: !368 (stalls every 16 s) and !369 (invalid tracks), issues #893/#894 | gvfs (GNOME) | Medium (CD playback unusable) | Medium-High | 2 | sent 11-07, no comments | final; pipelines pass | 7 reviewers | wait; ping around 11-28 |
| S4 | Tested-by on Hui Peng's mesh_tx leak patch | kernel | Medium | depends on that author | 3 | sent 10-06; his patch still `new` | — | — | nothing owed |

### 1.3 Ready to send, not sent (the operator's word is the gate)

| # | Contribution | Upstream | Severity | Chance | Priority | Patch | Review | Obstacle / next |
|---|---|---|---|---|---|---|---|---|
| R1 | **CO-35** stable request: L2CAP ECRED deferred-accept hang (BT-10) → 7.3.y | stable | Medium (hang in a tester; real ECRED users) | High | 2 | final package | outside review asked | rerun checkpatch and local CI, then send |
| R2 | **CO-22** stable request: two ASUS ROME device-table entries + a 6.6.y build report | stable | Medium (same class as BT-1 for other laptops) | High | 2 | request v2 | outside review | send |
| R3 | **CO-38** MGMT Read Advertising Features hides instances | kernel | Low-Medium | High (one line, a test) | 2 | final + tester case | outside review | send |
| R4 | **CO-04** independent fix for syzbot's mesh_send_sync use-after-free | kernel | High (kernel memory safety) | Medium (competes with another author's patch) | 2 | final; 48 boots per image clean | needs outside review round | review, then decide vs. 14888791 |
| R5 | **CO-05 + CO-26** mesh advertising list without the lock; lost failed add | kernel | Medium | Medium (mesh queue stalled upstream) | 3 | final (2 patches) | needs outside review round | may conflict with another author's 14927631 |
| R6 | **CO-37** BlueZ use-after-frees at exit (U23/U24) + 5.72 backport | BlueZ + Ubuntu | Medium (crash at shutdown) | High | 2 | six mails, bot checks pass | reviewed 11-02 | route decision (D3, D13) |
| R7 | **CO-23** BlueZ a2dp_reconfig use-after-free (U22) | BlueZ | High (daemon crash, seen 09-08) | High | 2 | fix + package | — | the operator's word on the route |
| R8 | **CO-11 (a)** Ubuntu stable update: btmon aborts (BT-4) | Ubuntu (Launchpad) | Medium (diagnostic tool dies) | High | 2 | debdiff, tested | 6 reviewers GO | the operator files |
| R9 | **CO-03** Ubuntu stable update: bluetoothd loses A2DP (U12) + BT-7 fixes | Ubuntu | High (headphones mode gone until reconnect) | High | **1** | built, VM-tested 70/70 → 0/70 | reviewed | laptop test with the MOMENTUM 4, then file |
| R10 | **CO-19** Ubuntu stable update: PipeWire codec line (U1) | Ubuntu | Medium | Medium | 2 | built | 6 reviewers GO | laptop test (install route changed 11-11) |
| R11 | **CO-40** Ubuntu: backport `a6ac17f0e393` ("refused" instead of "unknown") | Ubuntu | Low-Medium | Medium | 3 | tested in QEMU | — | bundle with R8/R9 or file alone |

### 1.4 In progress (work remains before a send)

| # | Contribution | Upstream | Severity | Chance | Priority | Stage | Obstacle / next |
|---|---|---|---|---|---|---|---|
| P1 | **CO-39** BlueZ: non-discoverable reports keep a temporary device alive (U29) | BlueZ | Medium | Medium-High | 2 | patch v2 + test | the bot's CI run (started 11-08, result not recorded), readiness summary |
| P2 | **CO-21** btusb: one of two SCO links going down switches the other to alt 0 | kernel | Medium-High (audio on a second headset) | Medium | 2 | tested in a guest, 0/5 → 5/5 | outside review, bot CI, title fix; laptop run optional |
| P3 | **CO-20** btusb: teardown data logged as "corrupted SCO packet" | kernel | Low (log noise) | Medium | 3 | prototype clears 22 → 0 in a guest | patch and message; newline fix backport |
| P4 | **CO-30** RFC: defer a SCO connect until the aborting link is gone | kernel | Medium | Low-Medium (an RFC) | 3 | prototype | after CO-02's answer |
| P5 | **CO-27** BlueZ: LE-only headset cannot be set up (U13), "Connected" with no audio (U18) | BlueZ | Medium | Medium | 2 | investigating, patch candidates | emulator reproducer, patches |
| P6 | **CO-12** kernel: extended-advertising duration overflow (M-2) | kernel | Low-Medium | Medium | 3 | draft clamp | design decision; conflicts with another author's patch |
| P7 | **CO-36** PipeWire: HFP volume resend outlives the link (U15) | PipeWire | Medium (false "mute on") | High (clear mechanism) | 2 | evidence ready | the operator writes the report (PipeWire's rules) |
| P8 | **CO-31** PipeWire: immediate SCO connect retry gives 5 s silence (U17) | PipeWire | Medium | Medium | 3 | evidence | the operator writes |
| P9 | **CO-33** PipeWire quirk entries: Shure AONIC 50 (U20), MOMENTUM 4 (U15) | PipeWire | High for the MOMENTUM 4 (microphone silent) | High (one-line table entries) | **1** | entries known | local test, then the operator writes |
| P10 | **CO-32** Ubuntu WirePlumber: input meter dies after a switch (U19), with CO-07 | Ubuntu | Medium | Medium | 2 | one-line fix drafted | laptop test, then the operator files |
| P11 | **CO-29** Ubuntu WirePlumber 0.4.17 forces Handsfree for any recording (U14) | Ubuntu | Medium | Low-Medium (fixed by a rewrite upstream) | 3 | none | local override first |
| P12 | **CO-08** PipeWire: Tronsmart T8 silent on SBC-XQ (U10) | PipeWire | Low-Medium | Medium | 3 | — | the decisive A-B test |
| P13 | **CO-42** gnome-bluetooth: a failed setup shows nothing (U29, U13) | GNOME | Medium | Medium (an open MR exists) | 2 | evidence, comment drafted | the operator posts on !137 or #18 |
| P14 | **CO-41** BlueZ emulator ignores the refusal reason | BlueZ | Low (test) | High | 3 | idea, one line | patch with a tester case |

### 1.5 Possible future (ideas, blocked, or registered only)

| # | Item | Upstream | Severity | Priority | Why it waits |
|---|---|---|---|---|---|
| F1 | BT-16: controller starts "already patched"; Bluetooth gone for the boot (8 candidates) | kernel, GNOME | High (twice in 12 boots) | **1** | cause unknown; needs the log-line module's record |
| F2 | BT-13: `hci_connect_sco()` drops a hold it never took | kernel | Low (cold path) | 3 | after CO-02 lands |
| F3 | U16: a failed Connect stops device search for good | BlueZ, gnome-bluetooth | Medium | 2 | reproducer, then patch |
| F4 | U28: btmon can still overflow at ≥2048 columns | BlueZ | Low | 3 | not reproduced with the binary |
| F5 | U30: PipeWire sends out-of-range HFP gains (127) | PipeWire | Low-Medium | 3 | first trace only |
| F6 | U31: gsd-media-keys assertions | GNOME | Low | 3 | no visible effect |
| F7 | CO-13 mesh "Count" question; CO-14 mesh at device removal | kernel | Low / Medium | 3 | after CO-04/05 |
| F8 | CO-06 review reply on another author's mesh power-off fix | kernel | Medium | 3 | blocked: that patch is idle |
| F9 | CO-01 test another author's SCO series | kernel | Medium | 3 | stalled upstream, no v4 |
| F10 | CO-15 new headset becomes the default (configuration note); CO-16 reconnect after Bluetooth off/on; CO-17 one capture for U4 | WirePlumber, BlueZ, GNOME | Low-Medium | 3 | by design upstream, or a short test |
| F11 | X2–X4: gvfs CD backend leaks, track numbering, ignored seek | gvfs | Low | 3 | after !368/!369 are answered |
| F12 | BT-15: SCI fix `5874f8d03268` into 7.3.y | stable | Low | 3 | the stable team's own selection, watch |

### 1.6 Closed

| # | Item | How it ended |
|---|---|---|
| C1 | CO-09 the entry in Ubuntu's kernel | Ubuntu's own `7.0.0-43` carries it (in noble-updates/-security, 11-12) |
| C2 | CO-10, CO-34 | done (A12, A9) |
| C3 | CO-18 earbuds silent in mSBC (U8) | not a kernel defect: valid audio reaches the earbuds; their side |
| C4 | CO-24 default codec (U5) | answered from source: the best codec is picked |
| C5 | CO-28 Tested-by on 6.1/5.15/5.10 reviews | deadlines passed; released with our backports in them |

---

## 2. Each one explained

Links go to GitHub. "Dossier" is the contribution's own folder with its log, experiments and
patches.

### 2.1 Accepted

**A1 — the kernel's wrong status at power-off (BT-8).** When the adapter powers off while
management commands are still pending, the kernel answers them all. An earlier change
(`f53e1c9c726d`) started passing a different structure to the answering function, which kept reading it as a status byte,
so every flushed command got "Success" (`0x00`). bluetoothd 5.72 trusted a "Success" for a Start
Discovery that never ran, read a reply that was not there, and crashed (BT-7's first site). Our
patch makes the kernel send the status the caller set (Not Powered / Invalid Index). Reproduced
with a virtual controller, applied unchanged, now in every maintained kernel line. This is the
project's one kernel commit. Evidence:
[patches/kernel](https://github.com/ivoitovych/qca9377-bt-hang/tree/main/patches/kernel);
upstream [86ef0f58bdec](https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git/commit/?id=86ef0f58bdec).

**A2, A3 — two bluetoothd crashes (BT-7).** On this laptop bluetoothd died twice in ways that
look to a user exactly like a dead controller: the adapter stays powered and never scans again.
The crash sites were found from the stripped Ubuntu binary and a core file. A2: the daemon read a
Start Discovery reply before checking its length (the kernel's wrong reply in A1 triggered it).
A3: when an audio transport was accepted asynchronously, its stream could already be gone; the
guard fired four times in nineteen days of ordinary use. Both applied within two days; a v2 of A3
was applied on top by mistake, which A7 cleaned up. Released in BlueZ 5.88; Ubuntu 24.04 still
ships 5.72, which is why R9 exists.
[patches/bluez](https://github.com/ivoitovych/qca9377-bt-hang/blob/main/patches/bluez/README.md).

**A4 — mgmt_unregister() from a callback (M-3).** Found while running BlueZ's testers under
AddressSanitizer during the mesh work: unregistering a notification from inside its own callback
leaked it, and unregistering the next one freed memory the list walk was still using (the same
crash fixed for a sibling function in 2015). New unit tests fail without the fix; 233 leaked
allocations in the testers go to 0. Applied the same day, unchanged.
[patches/bluez/shared-mgmt](https://github.com/ivoitovych/qca9377-bt-hang/blob/main/patches/bluez/shared-mgmt/README.md).

**A5, A6 — a regression test for BT-9, and a leak it exposed.** BT-9 is a kernel race in which
simultaneous discovery never stops and every later scan is refused "Busy" until a power-off; it
left this laptop unable to scan for days. To prove our stable backports (A11) work, a
deterministic BlueZ test was written that forces the race through the emulator; it fails without
the fix and passes with it. Writing it exposed an emulator leak (A5). Both applied in two days.
[patches/kernel/bt9-stable](https://github.com/ivoitovych/qca9377-bt-hang/blob/main/patches/kernel/bt9-stable/README.md).

**A7, A8 — two cleanups.** A7 removes the second copy of A3's check. A8 removes a variable-length
array that made BlueZ's CI post a static-analysis warning on every patch touching the emulator.
[patches/bluez/send-2026-10-18](https://github.com/ivoitovych/qca9377-bt-hang/blob/main/patches/bluez/send-2026-10-18/README.md).

**A9 — a test registered twice under one name (BT-12, CO-34).** BlueZ's ioctl-tester registered
the 3-DH packet-type test under the 2-DH test's name, so its failure would be reported as the
other's. Found when our verdict-comparison tool refused the duplicate. One line, applied the same
day. [dossier](https://github.com/ivoitovych/qca9377-bt-hang/blob/main/contributions/CO-34-ioctl-tester-duplicate-name/README.md).

**A10 — the fix for this laptop's original hang, brought to older kernels (BT-1).** The
controller (USB ID 13d3:3503) was missing from btusb's device table, so Linux ran it on its ROM
firmware; on that firmware the first command after a wideband (mSBC) call stream started got no
answer, and only a power-off brought it back (12 recorded deaths). Another author had already
added the entry upstream for a different symptom. Our part: proving it is the cause (E1/E3: 74
calls, 0 timeouts), checking it applies and builds on every stable line, and the request. The
stable team queued it the same day for seven lines; all are released. Ubuntu's own `7.0.0-43`
now carries it. [The diagnosis](https://github.com/ivoitovych/qca9377-bt-hang/blob/main/docs/missing-quirks-entry.md);
[STATUS](https://github.com/ivoitovych/qca9377-bt-hang/blob/main/docs/STATUS.md).

**A11 — the discovery race on 6.12, 6.6, 6.1 (BT-9).** A10 gives this device a quirk that
exposes BT-9 on exactly the lines where BT-9's fix was missing, so without A11, A10 would have
traded one fault for another there. Backported with one adaptation, each tested with A6's test.
Released on all three.

**A12, A13 — test report and a pointer.** A12: every BlueZ tester suite run on 6.6.160-rc2 and its
base, compared case by case; the release went out the same day.
[dossier](https://github.com/ivoitovych/qca9377-bt-hang/blob/main/contributions/CO-10-stable-6.6.160-rc2/README.md).
A13: [a comment](https://github.com/bluez/bluez/issues/1554#issuecomment-6089903035) showing that
another user's capture has BT-9's event order and naming the fix.

### 2.2 Sent, waiting

**S1 — CO-02, a new call connection handed a dying one (U7).** When a headset's codec is switched
during a call, the audio server closes the voice link and immediately asks for a new one. The
kernel can hand the new request the old link, which is still being torn down, report it
connected, and then close it; the audio goes silent. On the Lenovo earbuds this happened 3 of 3
times; on headsets that answer more slowly it never does. The series: (1) hold the reused link
for its new user, (2) refuse to reuse a link being aborted, (3) wait for a running disconnect
before reuse; plus a BlueZ test. Tested in QEMU on every affected stable line and on the laptop
for six days with three headsets. **State:** no maintainer reply in 16 days. An automated
reviewer rated patch 2 incomplete on its own (patch 3 closes the gap), so the natural next posting
is a v2 that folds them, which also makes it easier to review. The BlueZ test must be ported to
a test framework that changed on 10-29. The mirror pull requests the CI closed on 11-11/12 were
its bot's housekeeping, not a review. **Why Medium chance:** a correct but non-trivial race fix in
connection handling, sent while the maintainers are busy; other authors' fixes in this area also
wait for weeks.
[dossier](https://github.com/ivoitovych/qca9377-bt-hang/blob/main/contributions/CO-02-sco-connect-reuses-closing-link/README.md);
[lore](https://lore.kernel.org/linux-bluetooth/20261027165009.2401154-1-yaroslav.voytovych@gmail.com/).

**S2 — CO-25, telling Qualcomm what their ROM does.** The host-side fix exists (A10), but the ROM
firmware's hang itself was never reported, and other laptops with ROM-only IDs may still hit it.
The report asked two questions: is it a known erratum, and is there a list of affected IDs. A
Qualcomm engineer replied the same day that QCA9377 is "not ROME" and unsupported by btusb; the
laptop's own boot log, btusb's table and the firmware files contradict that. Our short reply
(v4) quotes the kernel's own line and asks what the intended initialization is. **Next:** send
it, or let the thread rest; the host fix does not depend on it.
[dossier](https://github.com/ivoitovych/qca9377-bt-hang/blob/main/contributions/CO-25-qualcomm-rom-report/README.md).

**S3 — X1, audio CDs pausing every 16 seconds (off-topic).** GNOME's CD backend reads through
libcdio-paranoia, whose cache model refills 16 s of audio in one blocking ~3 s call; the player
runs dry each time. !368 uses the 150-sector cache model GStreamer already uses (19 → 0
underflows on the laptop). A second defect found on the way, invalid track names opening the wrong
track or hanging, is !369. Both pipelines pass; no comment after five days, which is normal for
GNOME. [dossier](https://github.com/ivoitovych/qca9377-bt-hang/blob/main/contributions/X1-gvfs-cdda-readahead/README.md);
[!368](https://gitlab.gnome.org/GNOME/gvfs/-/merge_requests/368),
[!369](https://gitlab.gnome.org/GNOME/gvfs/-/merge_requests/369).

**S4 — Tested-by on another author's mesh leak fix.** His patch had not been reproduced; we
reproduced the leak without fault injection and showed the patch fixes it. It waits on him and
the maintainers. [retest](https://github.com/ivoitovych/qca9377-bt-hang/blob/main/retest/mesh-tx-leak/REPORT.md).

### 2.3 Ready to send

**R1 — CO-35, an L2CAP hang in every released kernel (BT-10).** A socket deadlocks on its own
lock when a deferred ECRED connection is accepted and closed in a certain order (the path dates
from v6.3). Another author fixed it in mainline without asking for stable. With his two commits
the full l2cap-tester passes 111/111 on 7.3. The request is for 7.3.y (7.2.y has ended). High
chance: a clean, tested request for existing mainline commits.
[dossier](https://github.com/ivoitovych/qca9377-bt-hang/blob/main/contributions/CO-35-l2cap-ecred-defer-hang-stable/README.md).

**R2 — CO-22, more laptops like this one.** Two ASUS ROME device-table entries are in mainline
and no stable branch; a survey found about ten more likely ROME IDs with no entry. The request
covers the two; owners of the others could be asked for data. Same class of fix as A10, so high
chance. [research](https://github.com/ivoitovych/qca9377-bt-hang/tree/main/contributions/research-2026-11-01).

**R3 — CO-38, an advertising instance hidden from the listing.** The kernel's advertising
listing compares instance numbers with the instance count instead of the maximum, so after
instance 1 is removed, instance 2 vanishes from the list. One-line fix plus a test case, found by
CO-12's tests. [dossier](https://github.com/ivoitovych/qca9377-bt-hang/blob/main/contributions/CO-38-read-adv-features-hidden-instances/README.md).

**R4 — CO-04, syzbot's mesh use-after-free.** A kernel memory-safety bug syzbot reports. Another
author's patch exists, but in our tests it shows a lock-order inversion in 8 of 12 boots; ours
hands over under the device lock and showed no lockdep or KASAN report in 48 boots per image. Not
reproduced on hardware (no mesh use here). Medium chance because it competes with a pending patch.
[dossier](https://github.com/ivoitovych/qca9377-bt-hang/blob/main/contributions/CO-04-mesh-test-14888791/README.md).

**R5 — CO-05 and CO-26, mesh advertising list changed without its lock.** Two patches: take the
lock, and stop scheduling an instance whose add failed. Warnings 3 → 0. The mesh queue upstream
is stalled (four other authors' fixes idle), and another author's pending patch may conflict.
[dossier](https://github.com/ivoitovych/qca9377-bt-hang/blob/main/contributions/CO-05-mesh-adv-list-lock-i12/README.md).

**R6 — CO-37, bluetoothd crashes at exit with a sound server running (U23, U24).** When
bluetoothd stops while an audio endpoint is registered, it reads freed memory. U23 is present on
master; U24 is fixed upstream but not released. Six mails, tested 10/10 → 0/10, plus a 5.72
backport for Ubuntu. Open: whether to send one or two series.
[dossier](https://github.com/ivoitovych/qca9377-bt-hang/blob/main/contributions/CO-37-bluez-media-endpoint-exit-uaf/README.md).

**R7 — CO-23, the 09-08 bluetoothd crash (U22).** A codec switch arriving while an audio stream is
closing makes `a2dp_reconfig()` write to a freed setup; it crashed the daemon on 09-08.
Reproduced under AddressSanitizer on master; fix ready.
[dossier](https://github.com/ivoitovych/qca9377-bt-hang/blob/main/contributions/CO-23-one-off-events/README.md).

**R8 — CO-11 (a), btmon aborting on Ubuntu (BT-4).** BlueZ's capture tool aborts on long lines;
two upstream fixes exist, and both are needed (one alone still aborts live). The Ubuntu
stable-update package and text are ready; Launchpad filing is the operator's.
[dossier](https://github.com/ivoitovych/qca9377-bt-hang/blob/main/contributions/CO-11-small-btmon-and-flaky-test/README.md).

**R9 — CO-03, headphones mode lost when an app opens the microphone (U12).** If a program opens
the microphone just as A2DP starts, bluetoothd aborts the start, the headset ignores the abort,
and A2DP is torn down; only hands-free remains until reconnect. Nine occurrences here. Fixed
upstream in BlueZ 5.80, not in Ubuntu's 5.72. The rebuilt package (also carrying A2/A3 and
October's security fixes) goes from 70/70 losses to 0/70 in VMs. The laptop test with the
MOMENTUM 4 is the gate. **Priority 1** because it affects daily use here.
[dossier](https://github.com/ivoitovych/qca9377-bt-hang/blob/main/contributions/CO-03-bluez-u12-backport/README.md).

**R10 — CO-19, the hands-free codec line (U1).** PipeWire 1.0.5 offers a codec-less hands-free
entry the panel cannot use; fixed upstream in 1.2. A rebuilt package is ready; the 11-11
rehearsal found its install plan would remove ten audio packages, so it is tested through a
private plugin path instead.
[dossier](https://github.com/ivoitovych/qca9377-bt-hang/blob/main/contributions/CO-19-pipewire-u1-codec-line/README.md).

**R11 — CO-40, "refused" instead of "unknown" (U29).** When a headset has forgotten the laptop,
BlueZ 5.72 reports "br-connection-unknown"; upstream `a6ac17f0e393` makes it "refused". Small
Ubuntu backport, tested in QEMU.
[dossier](https://github.com/ivoitovych/qca9377-bt-hang/blob/main/contributions/CO-40-ubuntu-bluez-a2dp-connection-refused-backport/README.md).

### 2.4 In progress

**P1 — CO-39, a "Not set up" row that cannot be set up (U29).** A headset that is not in pairing
mode still advertises; BlueZ refreshes its temporary entry on every such advertisement, so the
panel offers it for minutes and every click fails. The patch stops non-discoverable reports from
refreshing an unconnected temporary device; v2 adds a functional test (fails 6/6 on master,
passes 7/7). The bot's CI run started 11-08; its result was never recorded.
[dossier](https://github.com/ivoitovych/qca9377-bt-hang/blob/main/contributions/CO-39-bluez-temporary-device-kept-by-non-discoverable-reports/README.md).

**P2 — CO-21, two headsets, one goes away, the other loses its audio path.** btusb keeps one USB
alternate setting for all voice links; when one of two links closes, it switches the shared
setting as if none were left. Real btusb was run against a simulated controller in a guest:
unpatched fails 5 of 5 scenarios, patched passes 5 of 5. Needs an outside review, the bot's CI
and a one-character title fix.
[dossier](https://github.com/ivoitovych/qca9377-bt-hang/blob/main/contributions/CO-21-btusb-sco-alt-setting/README.md).

**P3 — CO-20, "corrupted SCO packet" at every hang-up.** The controller sends a little audio
after reporting the link closed; btusb logs it as corruption and counts it as an error. Harmless,
but it hides real errors. The prototype classifies it and clears 22 lines to 0 in a guest.
[dossier](https://github.com/ivoitovych/qca9377-bt-hang/blob/main/contributions/CO-20-sco-unknown-handle-messages/README.md).

**P4 — CO-30, wait instead of refuse.** With CO-02 the kernel refuses a connect that arrives
during teardown, and PipeWire's recovery then takes 5 s (U17). The RFC makes the kernel wait for
the old link to go. Waits for the maintainers' view of CO-02.

**P5 — CO-27, LE-only headsets (U13, U18).** A headset that advertises on LE with an empty flags
field is treated as LE-only, so pairing goes over LE and fails, or "connects" with no audio. Two
BlueZ patch candidates; an emulator reproducer first.
[dossier](https://github.com/ivoitovych/qca9377-bt-hang/blob/main/contributions/CO-27-le-only-pairing-u13/README.md).

**P6 — CO-12, advertising timeouts above 65 s (M-2).** A 16-bit duration overflows: a 66 s
timeout ends after 463 ms. A clamp is drafted; whether to clamp or redesign is a decision, and
another author's patch touches the same code.
[dossier](https://github.com/ivoitovych/qca9377-bt-hang/blob/main/contributions/CO-12-m2-adv-duration-overflow/README.md).

**P7, P8 — two PipeWire reports the operator writes (U15, U17).** P7: PipeWire re-sends the
headset's volumes 1.5 s after a call link starts, even when the link has already closed, which
makes the MOMENTUM 4 announce "mute on" after a dictation; reproduced in PipeWire's own tests.
P8: PipeWire retries a refused voice connect three times within a fraction of a millisecond, so
only a 5 s idle timer brings audio back. PipeWire's rules require the operator's own words.
[CO-36 dossier](https://github.com/ivoitovych/qca9377-bt-hang/blob/main/contributions/CO-36-pipewire-hfp-volume-resend-after-release/README.md).

**P9 — CO-33, the MOMENTUM 4's silent microphone (U15) and the Shure's ignored gain (U20).** The
MOMENTUM 4 reports its microphone gain as 0 at every connect, PipeWire sends 0 back, and the
headset mutes: the recordings show the microphone sending digital silence on every link since
10-20, so callers likely hear nothing. The Shure ignores every gain step except 0, which silences
it. PipeWire's fix for such headsets is a one-line table entry (`no-features = [ hw-volume-mic ]`);
it can be tested locally first. **Priority 1** because it breaks calls on this laptop now.
[issues, U15](https://github.com/ivoitovych/qca9377-bt-hang/blob/main/docs/issues.md).

**P10, P11 — Ubuntu's WirePlumber (U19, U14).** P10: an Ubuntu-only patch marks a stream as
handled when it was not linked, so the Sound panel's input meter dies after leaving hands-free; a
one-line fix is drafted. P11: WirePlumber 0.4.17 switches a headset to hands-free whenever any
listed app records from any microphone, and undoes manual choices; upstream rewrote this in 0.5.

**P12 — CO-08, a speaker silent on SBC-XQ (U10).** PipeWire offers a higher-bitrate SBC mode the
Tronsmart T8 accepts but may not play. A 10-minute test decides; then a quirk entry.
[dossier](https://github.com/ivoitovych/qca9377-bt-hang/blob/main/contributions/CO-08-pipewire-u10-sbc-xq/README.md).

**P13, P14 — saying why pairing failed (U29, U13).** gnome-bluetooth shows nothing when setup
fails (`//FIXME show an error?` since 2009); an open MR covers two of three cases, and our tests
show the third and two side effects. P14: BlueZ's emulator ignores the refusal reason, so no test
can reach that third case.
[CO-42](https://github.com/ivoitovych/qca9377-bt-hang/blob/main/contributions/CO-42-gnome-bluetooth-silent-pairing-failure/README.md),
[CO-41](https://github.com/ivoitovych/qca9377-bt-hang/blob/main/contributions/CO-41-bluez-emulator-io-cap-negative-reply-reason/README.md).

### 2.5 Possible future

**F1 — BT-16, the controller starts "already patched".** Twice in twelve boots the controller
came up claiming its firmware patch was loaded, so btusb skipped it; two LE commands then
failed, setup stopped half-way, and Bluetooth was gone for the whole boot (bluetoothd saw no
controller; GNOME said "Turned Off"). A power-off recovered it. Eight candidate defects are
listed: btusb trusting the claim, no log of the patch state, the kernel abandoning the controller
silently on one optional command, a USB disconnect at start-up, GNOME's misleading panel and
silent switch, and our own monitoring raising no alert. None can be sent until the status byte is
recorded at a failing boot. [issues, BT-16](https://github.com/ivoitovych/qca9377-bt-hang/blob/main/docs/issues.md).

**F2–F12** are recorded in [docs/issues.md](https://github.com/ivoitovych/qca9377-bt-hang/blob/main/docs/issues.md)
and the [contributions index](https://github.com/ivoitovych/qca9377-bt-hang/blob/main/contributions/README.md);
each waits for the reason in its table row. F3 (U16, device search stopping after a failed
Connect) is the most user-visible of them: the cause is traced in BlueZ's discovery bookkeeping,
and a patch candidate is written down.

---

## 3. What this adds up to

- **Delivered:** one kernel fix, eleven BlueZ commits, two stable requests that reached every
  maintained kernel line. Every accepted item was small and single-purpose and was applied within
  0 to 5 days.
- **Waiting on others:** one kernel series (CO-02) and one report thread (CO-25) on the kernel
  list, two gvfs MRs.
- **Waiting on the operator's word:** eleven packages ready to send or file (section 1.3).
- **The three that matter most for this laptop today:** the MOMENTUM 4's silent microphone (P9),
  A2DP lost when an app opens the microphone (R9), and BT-16 (F1).
