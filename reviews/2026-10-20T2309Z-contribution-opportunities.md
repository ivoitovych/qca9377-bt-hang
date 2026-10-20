# What we can contribute next, and what is still unexplored — 2026-10-20T23:09Z

**Covers:** every issue and submission row of `docs/STATUS.md` as of 2026-10-20, the
mesh notes in `docs/mesh-tester-ci/`, the userspace items in `docs/issues.md`, and the
upstream trackers each one depends on, checked 2026-10-20 between 22:30 and 23:09 UTC.

**Verdict:** the record has three new facts and one new measurement.
- **A kernel series that fits our call-audio problems is waiting for review.** Hitalo
  Souza's "[v3 0/6] Bluetooth: Fix SCO setup failures after an abandoned setup" (sent
  2026-10-08) fixes SCO links left broken after a setup is abandoned, the area of `U7` and
  `U8`. On patchwork it is still `new`, with only the CI bot's reply.
- **A mesh kernel bug we showed in QEMU has no fix anywhere.** `I12`: `mesh_send_sync()`
  adds an advertising instance without `hdev->lock`. Igor Putko's pending patch adds the
  lock elsewhere in the mesh path, but not there.
- **Every userspace item is still open in Ubuntu 24.04:** BlueZ 5.72, PipeWire 1.0.5,
  WirePlumber 0.4.17 and GNOME Settings 46.7 are still the newest published versions.
- **New measurement:** "SCO packet for unknown connection handle" appeared at 6 of 9 call
  hang-ups of the current boot (CO-20).

This is a snapshot. The current state of each item stays in `docs/STATUS.md`, and the
action register in `reviews/README.md` tracks what was done about it. Nothing here was sent
anywhere, and the laptop was only read.

---

## How it was checked

| source | how | result |
|---|---|---|
| Patchwork | `python3 -I scripts/patchwork-state.py <id>…`; the series and cover-letter records from `https://patchwork.kernel.org/api/series/1181908/` and `…/api/covers/14157860/`; a search of the Bluetooth project for SCO patches since 2026-10-01 | answered |
| BlueZ issues | `gh api repos/bluez/bluez/issues/<n>` and `…/comments`; GitHub issue search | answered |
| BlueZ tags | `https://git.kernel.org/pub/scm/bluetooth/bluez.git/refs/tags` | answered |
| PipeWire, WirePlumber, GNOME Settings | the GitLab v4 API, without a login (issue records answer; note bodies return 401) | answered, except note texts |
| Ubuntu | Launchpad `getPublishedSources` for `bluez`, `pipewire`, `wireplumber`, `gnome-control-center` and `linux-hwe-7.0` in noble; Launchpad `searchTasks` | answered |
| bluetooth-next source | `https://git.kernel.org/pub/scm/linux/kernel/git/bluetooth/bluetooth-next.git/plain/net/bluetooth/hci_sync.c` and `include/net/bluetooth/hci_core.h` | answered |
| lore.kernel.org | Atom search and thread feeds with a `curl/8` user agent | **refused: 403 on every request** (it answered the same requests on 2026-10-20 in the morning). Mailing-list searches (other QCA9377 reports, past discussion of the unknown-handle messages, every mesh patch of September) were not done |
| The laptop, read-only | `journalctl -k -b 0 -p err --grep "unknown connection handle" -o short-iso`; `scripts/sco-ledger.sh 0` | answered (CO-20) |

---

## A. Contributions we can make now or soon

### CO-01 — Test the call-audio series "Fix SCO setup failures after an abandoned setup"

**Upstream:** Hitalo Souza, v3, 6 kernel patches (patchwork 14875449 to 14875454, sent
2026-10-08 22:26 UTC, all `new`; the bot's reply on 1/6 is the only comment), plus BlueZ
tester patches (14875435, `new`). The cover letter's account: since `a13f316e90fd`
("Bluetooth: hci_conn: Consolidate code for aborting connections"), closing a SCO socket
while its setup is pending deletes the `hci_conn`; the abandoned setup can still complete,
and then the next connection's setup is rejected, a working link is failed, or a link
stays up in the controller with no connection for it, and the controller rejects every
later setup for the device until the ACL drops.

**Why it concerns us:**
- BlueZ #2562 (open, 20 comments, last 2026-10-13) holds the reports: Intel, MediaTek and
  Realtek controllers, and the distribution thread it cites lists the QCA9377 among the
  affected ones.
- One reporter there shows "SCO packet for unknown connection handle" with "corrupted SCO
  packet", the two kernel lines of our `U8` and CO-20.
- Patch 6 changes when btusb is notified of a SCO link's air mode, the notification behind
  our `evt 5` lines (BRIEF §5). The cover letter says: "Patch 6 is not covered here, as
  hci_vhci has no notify callback." Its real-hardware run was one MediaTek adapter on the
  legacy setup command. The laptop's controller also uses the legacy command, because the
  ROME entry sets `HCI_QUIRK_BROKEN_ENHANCED_SETUP_SYNC_CONN` (BRIEF §3). So a btusb run
  here adds what no one has.

**What we would do:**
1. Apply the exact patches with `git am` on the bluetooth-next base they name
   (`97a128698d9d`), and run BlueZ's sco-tester with the author's new tests, in QEMU.
2. Only on the operator's word: build `bluetooth.ko` from Ubuntu's `-38` source with the
   series and install it through `updates/`, `depmod` and a cold boot, as for BT-8 on
   2026-09-24, never a live swap (`EX-046`). Patch 2 may need the lock adaptation that the
   cover letter describes for kernels without `024e05f73a4c`; whether `-38` has it is not
   checked yet.
3. A Tested-by on the exact patches only, after every reachable path is tested.

**Done when:** `grep -c "abandoned setup" docs/STATUS.md` → ≥1 (a submission row for our test report).

### CO-02 — Re-read `U7` against the kernel's SCO connect path

`U7` (`EX-060`): after an HFP codec switch made while a SCO link was up, PipeWire's new
connect came while the old link was still closing (the old link's Disconnection Complete
177 to 205 ms after the Disconnect), and **no Setup Synchronous Connection was ever sent**.
STATUS says that "the host-side handling is examined separately before anything is said
about it".

The new series covers a socket closed while its setup is pending. Our case is a new
connect while the previous link is being torn down. A kernel that matches the new
connection to the closing `hci_conn` would send no setup at all, which is what the capture
shows. That is an inference, not a finding. It is to be read in `sco_connect()` and
`hci_connect_sco()` (bluetooth-next) and, if it holds, reproduced with hci_vhci. Then it
becomes either a report on the series' thread (a case it does not cover) or a separate
kernel patch, and the PipeWire report changes accordingly.

**Done when:** the `U7` row in `docs/STATUS.md` names the kernel's part, confirmed or ruled out.

### CO-03 — U12: rebuild bluetoothd, then ask Ubuntu for the fix

**Upstream:** fixed by `a14d59725` (Pauli Virtanen, 2024-11-02, first in 5.80). Newest
BlueZ tag: 5.87 (2026-07-03). Ubuntu noble: `5.72-0ubuntu5.8` in security (2026-10-13),
`5.72-0ubuntu5.7` in updates (2026-10-09), nothing in proposed. Launchpad has no bug for it
(searches "A2DP abort", "Failed to restore profile": 0).

**What we would do:** build bluetoothd from `5.72-0ubuntu5.8`'s source with the two BT-7
fixes and `a14d59725`. That also brings the five CVE fixes the running build lacks (STATUS,
the machine's warnings). The operator installs it and repeats the trigger. Then a Launchpad
bug with the tested patch, on the operator's word.

**Done when:** `grep -c "a14d59725" docs/STATUS.md` shows a Launchpad bug number in the `U12` row.

### CO-04 — Mesh: test Igor Putko's 14888791 on its exact patch

**Upstream:** "Bluetooth: mgmt: Fix UAF in mesh_send_sync caused by race in mesh queue",
2026-10-14, `new`. Its comments: Hillf Danton (2026-10-15 00:38 UTC) and syzbot's
Tested-by (00:58 UTC). There is no maintainer reply. Its `mesh_send()` hunk is Hui Peng's
14831271 verbatim (`new`, where our Tested-by of 2026-10-06 is), so if it lands first, our
Tested-by is moot.

**Read here (diff from `https://patchwork.kernel.org/api/patches/14888791/`):**
- It takes `hdev->lock` in `mesh_send_done_sync()`, `mesh_next()` and
  `mesh_send_start_complete()`.
- `mesh_next()` also runs as the destroy callback of `hci_cmd_sync_clear()` at device
  removal, under `cmd_sync_work_lock`. There our gate of 2026-10-05 already had lockdep
  report a lock-order inversion (`STATE-MACHINE.md`, update block).
- So the test to run on his exact patch is our mesh reproducers plus the device-removal
  lockdep case, on a 4-CPU guest.

Nothing is claimed before that run.

**Done when:** a STATUS row records the result of that run on 14888791.

### CO-05 — Mesh: write the `I12` locking patch

`mesh_send_sync()` calls `hci_add_adv_instance()` without `hdev->lock`, which the function
requires (`hci_core.c` contract, since `d2609b345ebf`).
- **Shown in QEMU on 2026-10-05**, with `lockdep_assert_held()` added: four call paths fire
  (mesh send; ISO broadcast through `hci_add_per_instance`; Set LE off; the advertising
  timeout through `hci_clear_adv_instance_sync`).
- On a 4-CPU guest KCSAN reports races on the list in 5 of 15 boots on bluetooth-next.
- No KASAN report and no corruption were shown.
- `STATE-MACHINE.md`: "nobody has written it"; 14888791 does not touch `mesh_send_sync()`.

The mesh path gets its own patch. Per the 2026-10-05 review, the other three paths are
recorded separately, not folded into a mesh series. QEMU only.

**Done when:** `grep -c "I12" docs/STATUS.md` → ≥1 with a patch state.

### CO-06 — Mesh: the review reply on Jiale Yao's power-off fix (14864878)

**Upstream:** `new` since 2026-10-03; the only reply is the bot's, whose mesh-tester "Send
cancel" timeouts predate `87a49b610708`. There is no newer version.

**Our comparison of 2026-10-05:** his fallback runs the completion without
`req_lock`/`hdev->lock`, and a backlog of three strands a request with his fix and with our
adapted minimal fix alike.

**The reply:** a review with that evidence and no Tested-by (STATUS, mesh row). Sending it is
the operator's decision.

**Done when:** the mesh row in STATUS records the reply sent or dropped.

### CO-07 — U6: ask Ubuntu for the GNOME 47 input-meter fix

**Upstream:** fixed by `215289935`, `a74bc5a84`, `bf6f72278`, `afec106a8`, `3aeb837cb` and
`0da10f03a` (first in 47.0). Ubuntu noble: `1:46.7-0ubuntu0.24.04.6` in updates
(2026-09-02), nothing newer. Launchpad: the only match is the unrelated #1923602.

**What we would do:** one recorder reading with the Sound panel open (one capture stream
predicted on 46.7), then a Launchpad request quoting the six commits.

**Done when:** the `U6` row in STATUS carries a Launchpad bug number.

### CO-08 — U10: a PipeWire quirk entry for the Tronsmart T8

**Upstream:** `spa/plugins/bluez5/bluez-hardware.conf` on PipeWire master has no Tronsmart
entry. The form is one line, for example
`{ name = "SoundCore 2", no-features = [ sbc-xq ] },  # #pipewire-2291`.

**Blocked on** the operator's test sound on each mode, with a `bt-mark` after each
(`docs/issues.md`, `U10`, "Next"). Only that shows whether the speaker is silent on SBC-XQ.

**Done when:** the `U10` row records the test result and, if silent, the merge request.

### CO-09 — The QCA9377 entry in Ubuntu's kernel

**Ubuntu:** `linux-hwe-7.0` is `7.0.0-38.38~24.04.4` in updates and security, and
`7.0.0-39.39~24.04.1` in proposed (2026-10-01); neither carries the entry (STATUS). No
Launchpad bug mentions 13d3:3503.

**The likely route without us:** `-39`'s newest upstream-stable base is "v6.18.51, v7.2.5",
and the entry is in 7.2.10 and 6.18.56. So a later Ubuntu stable update should bring it
without a request. That is an inference from the cadence, not a promise. A request would
only make it sooner, and it is the operator's decision (BRIEF, decisions open). Until then,
E3 is rebuilt before any new kernel boots (BRIEF §0).

**Done when:** `scripts/btusb-has-device.py` reports FOUND on a stock Ubuntu btusb.

### CO-10 — Stable 6.6.160-rc2: an optional Tested-by

Responses to "[PATCH 6.6 0000/1651] 6.6.160-rc2 review" are due Thu 22 Oct 07:53:04 UTC. We
could run the BT-9 mgmt-tester case on rc2 in QEMU and reply with a Tested-by. This is
time-bound and small, and it is the operator's decision. 6.1.191 has no rc2 yet.

**Done when:** the reply is sent or the deadline passes.

### CO-11 — Low value

- **btmon's abort (`BT-4`):** the fixes `fdbfe0018` (5.80) and `dca0f10fd` (master) are not
  in Ubuntu's 5.72, and Launchpad has no bug for it. A request is possible, but our tools
  already avoid the trigger (`--columns=200`).
- **Pauli Virtanen's flaky-test fix (14879847):** `new`. We measured the flake at 7 in 26 bot
  runs (STATUS, A2 row). A Tested-by needs `scripts/functional-repeat.sh`, which has never
  completed a run here (it needs KVM and `AF_ALG`).

---

## B. Real, but more work before it is a contribution

| ID | item | where it stands upstream | what is missing |
|---|---|---|---|
| CO-12 | `M-2`, advertising timeout overflow | bluetooth-next, `hci_enable_ext_advertising_sync()`: `u16 duration = adv->mesh ? adv->timeout : adv->timeout * MSEC_PER_SEC;`, with `__u16 timeout` in `struct adv_info` (`hci_core.h:252`). So non-mesh timeouts above 65 s still truncate. Pauli Virtanen's mesh fix `8a8d51eeedeb` is in bluetooth trees, not in mainline | a QEMU reproducer (Add Advertising with a timeout of 66 s or more); then a timeout design, not a clamp (2026-10-05 review) |
| CO-13 | Mesh "Count" | a uAPI question | a question to the list, not a patch |
| CO-14 | Mesh at device removal | lockdep's inversion shown only with a scratch delay keeping the tear-down entry queued | the maintainers' direction on what an accepted transmission means when its index disappears |
| CO-15 | `U11`/`U3`, a new headset does not get the sound | WirePlumber #914 open (last activity 2026-09-25); no new issue on it since June; maintainers changed the behaviour "back and forth" (#352) | an opt-in proposal; the draft is `patches/wireplumber/2026-10-13-suggestion-default-follows-new-device.md`; the operator's decision |
| CO-16 | `U9`, no reconnect after Bluetooth off/on | BlueZ #294 closed "not planned" (2025-09-16); nearby open: #2594 (LE HID auto-connect not re-armed) | at most a narrow opt-in, with the maintainers' agreement first |
| CO-17 | `U2` (microphone volume moves by itself), `U4` (codec row disappears) | GNOME #3710 (open, last activity 2026-09-10): "Sound panel behaves incorrectly when selecting Bluetooth Handsfree device", related to U4 | one capture each with `bt-ui-capture` during a manual test |
| CO-18 | `U8`, earbuds silent in mSBC | the #2562 reports show the same kernel lines on Intel | belongs with CO-01 and CO-20 |
| CO-19 | `U1`, first handsfree entry unselectable | fixed in PipeWire 1.2 (`805e5cf9c`); noble has `1.0.5-1ubuntu3.3` | not worth a request: Ubuntu rarely takes a cosmetic fix into a stable release |

---

## C. Unexplored

### CO-20 — "SCO packet for unknown connection handle" at most call hang-ups

**Measured 2026-10-21 (local time), the current boot:**

`journalctl -k -b 0 -p err --grep "unknown connection handle" -o short-iso` → 14 lines:

| local time | handle |
|---|---|
| 2026-10-20 11:53:08 | 9 (×3) |
| 2026-10-20 11:55:45 | 10 (×2) |
| 2026-10-20 11:55:51 | 10 |
| 2026-10-20 12:42:12, 12:42:13 | 13 |
| 2026-10-20 12:52:35 | 14 |
| 2026-10-21 00:12:33, 00:12:37 | 17 |
| 2026-10-21 00:19:49 (×2), 00:19:50 | 18 |

`scripts/sco-ledger.sh 0` → 9 mSBC links on the MOMENTUM 4, 9 hang-ups answered, 0
timeouts. Adding each link's streamed seconds to its setup time puts its end at 11:53:08,
11:55:45, 12:19:36, 12:41:49, 12:42:12, 12:52:35, 23:57:09, 00:12:33 and 00:19:49.

So the messages come at the hang-up in 6 of 9 links. Two come 4 to 6 s after their link
ended (handle 10 at 11:55:51; handle 17 at 00:12:37), which a stray last packet does not
explain.

Possible readings, none tested:
- harmless data the controller delivers after the host has deleted the connection;
- or the "link left up" class of CO-01.

**Next:** read the HCI captures at those times for Disconnection Complete against the
following SCO data on the same handle.

### CO-21 — btusb with two SCO links at once

The series' cover letter: "btusb can still do that [stop the audio of another SCO
connection] when a SCO link that was up goes down while another one stays up; that is not
changed here." We have never had two SCO links at once on the laptop. This is not tested,
and not a priority unless CO-01's run shows it.

### CO-22 — Other QCA ROME USB IDs missing from btusb's table

BT-1's cause was a missing table entry, which leaves the controller on ROM firmware. Any
other QCA9377/ROME USB ID missing from the table would plausibly fail the same way. No
survey has been done. Hardware-probe databases list the USB IDs seen in the field, and the
table is `drivers/bluetooth/btusb.c`. A candidate would be offered only with a tester who
owns the device.

### CO-23 — One-off events, kept until a second instance

- The AONIC 50 connected, dropped after 3 s (reason 2, local host) and reconnected on
  2026-10-13 at 01:01:56, 01:01:58 and 01:02:04 (`docs/issues.md`, `U11`, side
  observation).
- `BT-6`: ACL data for an unknown handle, once on 2026-08-12.
- A bad `free()` in the patched bluetoothd, once on 2026-09-08 (`HISTORY.md`).

### CO-24 — U5's remaining question

Which handsfree codec WirePlumber picks for a headset with no saved choice. This needs a
device never switched to handsfree, or the operator's word to clear a saved preference.

### CO-25 — BT-1's mechanism

What the ROM firmware does wrong on alt-setting 1 is unknown and not claimed (BRIEF §4). Only
controlled runs on the laptop can find it, so it stays closed unless the operator wants
those runs.

---

## D. Nothing to do but wait

- The 6.6.160, 6.1.191, 5.15.224 and 5.10.273 releases (STATUS).
- A BlueZ release after 5.87 (newest tag 2026-07-03) for our accepted patches.
- The second affected user's retest on #1554 (last comment 2026-10-14).
- Hui Peng's thread (14831271, `new`).

## Suggested order

1. CO-01 with CO-02, because call audio is the area of daily use with open defects.
2. CO-03, because it also closes the running bluetoothd's CVE gap.
3. CO-05, which needs QEMU only.

Which to start is the operator's decision, and every send waits for the operator's word.
