# Contributions — one dossier per possible contribution

Every possible upstream or distribution contribution gets a folder here. Its findings,
experiments, ideas, decisions and references collect in that folder, so nothing is
forgotten or lost between working sessions. The IDs come from
`reviews/2026-10-20T2309Z-contribution-opportunities.md`; new items take the next free
`CO-nn`.

**What stays where:**
- `docs/STATUS.md` remains the one page that says what is *current*.
- `docs/issues.md` remains the evidence register per issue.
- A dossier holds the working material and links to everything else.
- **Nothing is moved into a dossier.** Exhibits, patches already sent, captures and review files
  stay where they are, because mails, commits and STATUS already point at them; the dossier
  links to them.
- **Raw recordings stay in the git-ignored archive** (they carry real device addresses). A
  dossier names each one by path and, where it matters, by SHA-256.

## A dossier's layout

| file | what it holds |
|---|---|
| `README.md` | the front page: what the contribution is, where it comes from, its state, the next step and who decides it |
| `log.md` | an append-only journal: dated entries for findings, experiments, reviewer input, decisions; nothing written there is edited, corrections are new entries |
| `refs.md` | pointers: issues, exhibits, captures, reviews, upstream threads, patchwork IDs, commits |
| `experiments/` | one file per run: command, output, verdict (created with the first run) |
| `patch/`, `drafts/` | once a patch or a mail or bug draft exists |

States, in order: **idea** · **investigating** · **reproduced** · **patch written** ·
**ready to send** · **sent** · **accepted** · **released**; or **waiting** (on a person or a
date), **blocked** (on a decision), **dropped** (with the reason in `log.md`).

**Nothing in a dossier is sent anywhere without the operator's word.**

## Index

| ID | dossier | target | state | next step | decides |
|---|---|---|---|---|---|
| CO-01 | [Test the abandoned-setup SCO series](CO-01-sco-abandoned-setup-series/README.md) | kernel (another author's series) | idea | QEMU run on the exact patches | the operator, for a laptop run and any Tested-by |
| CO-02 | [A new SCO connect reuses the closing link (U7)](CO-02-sco-connect-reuses-closing-link/README.md) | kernel; BlueZ test | **sent** 2026-10-27 (v7: three kernel patches with stable tags + the BlueZ sco-tester test); the list bot: kernel series all 24 checks PASS, BlueZ test PASS but the expected smatch note; no human reply yet (10-28) | replies, sashiko-nipa; a port of the BlueZ test if Luiz Augusto von Dentz's tester series (1191414) lands first | the operator, for any reply or v2 |
| CO-03 | [U12: bluetoothd rebuild and the Ubuntu backport](CO-03-bluez-u12-backport/README.md) | Ubuntu (BlueZ 5.72) | investigating: backport recipe found and checked | backport, build, tests | the operator installs; the operator files |
| CO-04 | [Test Igor Putko's mesh patch 14888791](CO-04-mesh-test-14888791/README.md) | kernel (another author's patch) | **tested 2026-10-21: no Tested-by**, it introduces a `hdev->lock` / `cmd_sync_work_lock` inversion (lockdep, 9 of 12 boots); fixes three failed-start cases. 10-28: his patch still the only one posted; syzbot's UAF still open | **new direction (10-28):** an independent fix for syzbot's mesh_send_sync use-after-free, its own patch (reproducer, fix, tests, reviews first; `log.md`) | the operator, for the send |
| CO-05 | [Mesh I12: advertising list changed without `hdev->lock`](CO-05-mesh-adv-list-lock-i12/README.md) | kernel | **patch written** (2026-10-21), two patches with CO-26, tested; 10-28: still unfixed upstream, applies to `47d4d9f67e92` | an outside review of the written patches, `kernel-preflight.sh` and `bot-ci-local.sh` on today's base, then the operator's decision (the mesh queue is stalled: CO-06's log) | the operator, for the send |
| CO-06 | [Review reply on Jiale Yao's mesh power-off fix](CO-06-mesh-power-off-review/README.md) | kernel (another author's patch) | blocked | the operator's decision | the operator |
| CO-07 | [U6: GNOME input meter fix for Ubuntu](CO-07-gnome-u6-input-meter/README.md) | Ubuntu (GNOME Settings 46.7) | idea | one recorder reading with the Sound panel open | the operator files |
| CO-08 | [U10: PipeWire quirk for the Tronsmart T8](CO-08-pipewire-u10-sbc-xq/README.md) | PipeWire | blocked | the operator's marked test sound per mode | the operator |
| CO-09 | [The QCA9377 entry in Ubuntu's kernel](CO-09-ubuntu-kernel-qca9377-entry/README.md) | Ubuntu (kernel) | waiting; **`7.0.0-42` pending in noble-updates (10-27) lacks the entry** (base v6.18.55/v7.2.9) | E3 for `-42` before any boot into it (source prepared, `cache/ubuntu-7.0.0-42`); watch the next cycle | the operator, for holding `-42`, the E3 install and any request |
| CO-10 | [Tested-by on 6.6.160-rc2](CO-10-stable-6.6.160-rc2/README.md) | stable kernel | **sent** 2026-10-21 03:05 UTC (v6, server 250) | watch the thread and the 6.6.160 release | — |
| CO-11 | [Small items: btmon for Ubuntu, the flaky BlueZ test](CO-11-small-btmon-and-flaky-test/README.md) | Ubuntu; BlueZ | **reopened 2026-10-28 (operator):** (a) btmon abort: a Launchpad stable-update report with a tested debdiff (both upstream fixes apply to 5.72 in order; 13 aborts on the laptop since 10-23); (b) a Tested-by for Pauli Virtanen's 14879847 (the flaky functional test) | (a) **ready to file** (2026-10-28; all six reviewers GO at `e2e0e00`): the debdiff (5.72-0ubuntu5.9) and the Launchpad text in `ubuntu/` — the operator reads and files, then `XXXXXX` is replaced; (b) the harness creates no controller on the host (`harness-check-2026-10-28.md`): run it in a container given only `/dev/kvm` | the operator files (a) and decides any send |
| CO-12 | [M-2: extended-advertising duration overflow](CO-12-m2-adv-duration-overflow/README.md) | kernel | investigating: arithmetic confirmed in source | QEMU reproducer | the operator, for the send |
| CO-13 | Mesh "Count" question to the list | kernel (uAPI) | idea | — | the operator |
| CO-14 | Mesh at device removal (lock order, drain policy) | kernel | idea | maintainers' direction first | the operator |
| CO-15 | U11/U3: a new headset becomes the default (opt-in) | WirePlumber | idea; draft in `patches/wireplumber/` | — | the operator |
| CO-16 | U9: reconnect after Bluetooth off/on (narrow opt-in) | BlueZ | idea | — | the operator |
| CO-17 | U2, U4: one capture each | PipeWire/WirePlumber; GNOME | idea; U4's caching guard confirmed in 46.7 (`cc-profile-combo-box.c:96`) | captures in a manual test | the operator |
| CO-18 | U8: earbuds silent in mSBC | kernel / btusb | idea; belongs with CO-01 and CO-20 | — | — |
| CO-19 | [U1: the codec line in Hands-free](CO-19-pipewire-u1-codec-line/README.md) | Ubuntu (PipeWire 1.0.5) | **reopened 2026-10-28 (operator):** a codec the panel cannot show or change is a functional bug; fixed upstream in 1.2 (`805e5cf9c`) | **code and packaging approved** (2026-10-28; v2: upstream `f142c0a5b` + the hand-port of `805e5cf9c`; all six reviewers GO at `e2e0e00`); **the laptop headset test is the gate** (plan in the README: install the rebuilt pair, test, keep or roll back), then the bug number and the operator's filing | the operator: the test window, then files |
| CO-20 | [SCO error messages at call hang-up](CO-20-sco-unknown-handle-messages/README.md) | kernel / btusb | investigating | read the HCI captures at those hang-ups | — |
| CO-21 | btusb with two SCO links: one going down switches the other to alt 0 | kernel / btusb | confirmed in source (`btusb_notify()`/`btusb_work()`, reviews RV3) | a test with two SCO links | the operator, for a laptop run |
| CO-22 | Other QCA ROME USB IDs missing from btusb's table | kernel | idea | a survey of hardware-probe data | — |
| CO-23 | [One-off events (AONIC 50 drop, BT-6, bluetoothd bad `free()`)](CO-23-one-off-events/README.md) | BlueZ; kernel | **reopened 2026-10-28 (operator):** one occurrence is enough to look for the root cause in source | **investigated 2026-10-28:** the bad `free()` traced to a use-after-free in BlueZ `a2dp_reconfig()` (`setup->reconfigure` written after the abort path freed `setup`), still in master; a small fix drafted, not built; BT-6 a benign race (data after disconnect at power-off), 12 instants in August, not one; the AONIC 50 drop not findable without a recurrence | an ASan reproduction in BlueZ's emulator, then the fix and a BlueZ patch; correct the BT-6 records | the operator, for any send |
| CO-24 | U5: default codec for a headset with no saved choice | WirePlumber | idea | needs a fresh device or the operator's word | the operator |
| CO-25 | [BT-1's ROM firmware: a report to Qualcomm](CO-25-qualcomm-rom-report/README.md) | Qualcomm (via the kernel's QCA Bluetooth maintainers) | **reopened 2026-10-28 (operator):** report the ROM-firmware behaviour to Qualcomm, even though the host-side fix exists; ask whether other ROM-only IDs exist (ties to CO-22) | **SENT 2026-10-29 02:33 +0100** (`<20261029013350.360574-1-yaroslav.voytovych@gmail.com>`, server 250; after ten review rounds, the last unanimous GO; `send/send.sh` dry run clean, seven recipients; `drafts/report-v4.txt` after a sixth review round (seven reviewers) on usefulness and list practice and a seventh comparing them: 3502/3504 and the 197/202 sentence out, scoped claims, the timing sentence corrected, `[REPORT]` tag; evidence page `EVIDENCE.md` at a pinned commit): To linux-bluetooth, Cc the Bluetooth maintainers, Zijun Hu, Shuai Zhang, Bartosz Golaszewski, Tibor Harcsa; the operator's read and link choice, then the `.eml`, a dry run and the operator's word | the operator, for the send |
| CO-26 | `mesh_send_sync()` loses a failed add and schedules the missing instance | kernel | **patch written** as CO-05's 2/2 (fault injection before/after done; no client-visible change) | with CO-05 | the operator, for the send |
| CO-27 | [U13: a headset known only from LE advertising cannot be set up](CO-27-le-only-pairing-u13/README.md) | BlueZ; GNOME | investigating: confirmed in capture, log and source (2026-10-21); pairing mode worked; sibling report BlueZ #2700 (10-22, no reply) | an emulator reproducer; a patch per defect (U13, U18); or first a comment on #2700 with our evidence | the operator, for any send |
| CO-28 | [Tested-by on the 6.1.191, 5.15.224 and 5.10.273 stable reviews](CO-28-stable-6.1-5.15-5.10-reviews/README.md) (our backports are in them) | stable kernel | waiting: the rc1s of 10-17 still open on 10-28, no release; review mails not found (lore 403) | watch for the review mails; CO-10's method applies | the operator, for any send |
| CO-29 | U14: WirePlumber 0.4.17 forces Handsfree for any listed recording and undoes a manual A2DP choice | Ubuntu (WirePlumber 0.4.17) | confirmed in log and source; fixed upstream by the 0.5 rewrite | the operator's local override; then a Launchpad report or a minimal 0.4 patch | the operator |
| CO-30 | Defer a SCO connect until the aborting link is gone (RFC, builds on CO-02) | kernel | **prototype only** (`CO-02…/patch/kernel-rfc-defer/`, 2026-10-21, old base): changes `connect()` semantics; never reviewed, never run on hardware. Offered in CO-02's cover letter as an RFC question | the maintainers' answer to CO-02 first; if wanted: rebase on v5, its own tests (sco-tester During through a real new link), reviews, a laptop run | the operator |
| CO-31 | U17: PipeWire retries a refused SCO connect at once, so the audio returns only after WirePlumber's 5 s idle suspend | PipeWire | confirmed (mechanism, `EX-068`); not fixed in master | evidence for the operator's report (a retry that waits for the old link); PipeWire's rules: the operator writes | the operator |
| CO-32 | U19: Ubuntu's WirePlumber patch for LP #2122640 marks a skipped stream handled, so the Sound panel's input meter dies | Ubuntu (WirePlumber 0.4.17-1ubuntu4.1) | confirmed in journal and source; Ubuntu-only; one-line fix drafted in `docs/issues.md` | a laptop test in a user override (the operator's word); then the operator's Launchpad report with the patch | the operator |
| CO-33 | U20: a PipeWire quirk entry for the Shure AONIC 50 (`no-features = [ hw-volume-mic ]`) | PipeWire | confirmed (commands); headset behaviour inferred | a local test via `bluez5.hardware-database`; then the operator's entry; PipeWire's rules: the operator writes | the operator |
| CO-34 | [BT-12: ioctl-tester registers two cases under one name](CO-34-ioctl-tester-duplicate-name/README.md) | BlueZ | **sent 2026-10-28** 06:16 +0100, server 250, Message-ID `<20261028051620.3167775-1-yaroslav.voytovych@gmail.com>` | the bot's checks and replies | the operator, for the send |
| CO-35 | [BT-10: the L2CAP ECRED deferred-accept hang on the stable lines](CO-35-l2cap-ecred-defer-hang-stable/README.md) | stable kernel | **send package ready for review, nothing sent** (2026-10-28 evening): Pauli Virtanen's `32d86e048d8ef` + its helpers `608e0b7a675b2` (mainline since the 7.4 merge window, no `Cc: stable`, not queued); 7.2.13 and v7.3 with them: 111/111 (v7.3 also needs `5874f8d03268` for an unrelated SCI stall, proposed BT-15); backports for 6.18.y, 6.12.y, 6.6.y as `[PATCH <line> 0/2]` series; the hang is a socket-lock self-deadlock, present since v5.7, so 6.1.y/5.15.y/5.10.y hang too with ECRED enabled (not covered) | an outside review of `send/`; then the operator's word and the dry run | the operator, for the send |

Items without a link have no dossier yet. One is opened as soon as anything is written about
the item.
