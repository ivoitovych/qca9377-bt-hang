# Pause state: CO-18, CO-20, CO-21 research (paused 2026-11-01 about 01:35 local)

Nothing was sent or posted. The laptop's Bluetooth was not touched: I only read journals,
archived captures and source. Two read-only background jobs were still running when I
paused (see "Running at pause").

## Done: CO-20 (SCO error messages at hang-up) is explained

The messages are benign. They are data that arrives after the link closes, and the host's
teardown drops it.

- **Capture analysis (CO-02 boot `257d1599`, 2026-10-23 to 10-29).**
  - 63 links were found. 119 SCO RX packets sit after their handle's Disconnection Complete
    in capture order, and the journal has exactly 119 "unknown connection handle" lines.
  - Every one of these packets arrived 0 to 10 ms after the Disconnection Complete. None came
    without a link closing just before it.
  - Across all archived captures from 10-19 21:53 to 10-30 10:55 (122 links), all 220 such
    packets came within 20 ms of their link's close.
  - Files: `out/orphans-boot-257d1599.txt`, `out/orphans-archive-20261019-20261030.txt`.
- **"Late by seconds or minutes" is a journald timestamp effect, not a kernel event.**
  - The kernel's own printk time (`_SOURCE_MONOTONIC_TIMESTAMP`) puts the "late" line within
    µs of its siblings.
  - Example: the handle 12 line stamped 13:27:12 was printed at monotonic 7602.529083, 9 µs
    after the line before it. It was received 950 s later, when the next kernel message came.
  - In that boot, 30 of 134 lines were received more than 1 s late (maximum 950 s).
  - Files: `out/journal-sco-err-257d1599.json`, `out/journal-vs-links-257d1599.txt`.
- **All "corrupted SCO packet" lines fall in the teardown window.**
  - Each comes 5 to 9 ms after `hci_conn_del()` begins and before btusb's DISABLE
    notification ("hci0 evt 6").
  - Counted: CO-02 boot 8 of 8 events, d479d374 3/3, e672b454 2/2, and the U8 session
    (09-29, boot 855a927e) 10/10 lines.
  - Files: `out/corrupted-context-*.txt`, `out/export-context-u8-855a927e.txt`.
- **Mechanism in source** (bluetooth-next `42b8c2d72926`, the tree before my edits).
  - `btusb_main.c:1818-1845` handles isoc URB completion. `btusb_recv_isoc` at 1546-1600
    calls `btusb_validate_sco_handle` (1518-1544), which looks up the handle at URB time.
  - In the core, `sco.c:1572-1584` returns `-ENOENT`, and `hci_core.c:4049-4052` then logs
    the rate-limited "unknown connection handle".
  - `hci_conn_del` (`hci_conn.c:1292-1366`) calls `hci_conn_hash_del`, which does
    `list_del_rcu` + `synchronize_rcu` (`hci_core.h:1070-1077`). That opens the
    "corrupted" window.
  - The DISABLE notification is sent from `hci_conn_cleanup` at `hci_conn.c:160`.
  - Ubuntu `-42` matches: `hci_core.h:1046-1051`, `hci_conn.c:1197/1212/1267`,
    `btusb.c:1717`, `hci_core.c:3905`.
- **Fix:** none needed functionally. At most a log-level discussion, and "corrupted SCO
  packet" also flags real isoc loss (the v7.2 Intel 9260 regression thread), so demoting it
  has a cost.

## Done: CO-18 / U8 is not a kernel defect

- **The host sent good audio to the earbuds.** The U8 links (09-29 02:30:27 h19 and
  02:30:59 h20, boot 855a927e, E1 with firmware loaded) carried valid mSBC TX with real
  signal during the test sounds:
  - 159 frames with signal at 02:30:39 to 02:30:41 and 159 at 02:31:01 to 02:31:05;
  - H2 headers and syncword correct;
  - the only bad frames are the last 30 to 34, which are all zeros;
  - RX (the earbuds' microphone) is valid and complete.
- **Setup parameters are the standard mSBC set:** latency 0x000d, retransmission 0x02,
  packet type 0x0380, Tesco 12, window 4.
- **On E3, earbuds links on 10-23 and 10-24** have 100% valid TX frames, and the 06:11 and
  06:12 links carry signal in every frame. Whether that sound was heard is not recorded.
- **Records now wrong.** `docs/issues.md` U8 says "corrupted SCO packet ×6 during the
  earbuds' mSBC links". All are at teardown.
- Files: `out/msbc-u8-20260929*.txt`, `out/msbc-earbuds-e3-20261023.txt`,
  `out/orphans-u8-20260929-params.txt`.

## Done: CO-21 is confirmed, plus a new single-link variant

- **CO-21 itself (one of two links goes down).** At bluetooth-next `42b8c2d72926`:
  - `btusb_notify` (2470-2481) stores `air_mode = evt` for any event that comes with a
    change in the SCO count.
  - `btusb_work` (2584-2652) then picks alt 0 while a link remains.
  - On 13d3:3503, alt 0 has max packet 0 (descriptors in the message of `dc16388d45ec`).
    The USB core refuses those URBs with -EMSGSIZE (`drivers/usb/core/urb.c:436-443`).
    So every TX frame gives "urb ... submission failed (90)" plus "sending frame failed
    (-90)" (`hci_core.c:3166-3168`), and RX stops.
- **New single-headset variant.** Any non-SCO notification (evt 1 CONN_ADD, 2 CONN_DEL,
  3 VOICE_SETTING) that comes while a SCO setup is pending makes btusb adopt the count with
  that event as its air mode, which selects alt 0. The link's own ENABLE is then ignored,
  because the count no longer changes.
  - Real instance on the laptop: 2026-09-02 19:29:43 to 19:29:50, boot c128a59a (stock
    era).
  - A SCO setup was pending, ACL handle 3 was deleted (evt 2), and then "set USB alt:(0)
    failed!" appeared. That line can only come from the `sco_num > 0` branch.
  - The same boot also had two SCO hci_conns from two devices at 19:29:13.
  - File: `out/export-context-c128a59a-0902.txt`.
- **Introduced by** `baac6276c0a9f` (v5.8, 2020-04-03).
- **Upstream coverage.** Hitalo Souza's patch 6 (patchwork 14875454, still `new`) covers
  only the "failed second setup" case. Nothing upstream covers the 2→1 case or the race;
  patchwork searches for corrupted, unknown connection, notify and altsetting found nothing.
- **Never two simultaneous SCO links** in 133 captured links (09-29 and 10-19 to 10-30).
  The 9 "others-live" rows on 10-23 are a reboot artefact; the script now resets on New
  Index.
- **No trace of the alt-0 flood in any boot.** Not one "submission failed (90)" or
  "sending frame failed" line in any archived boot or the current one
  (`out/archive-grep-co21-signature.txt`).
- **Candidate fix, never installed.**
  - Diffs: `out/candidate-btusb-notify-ubuntu-7.0.0-42.diff` and
    `out/candidate-btusb-notify-bluetooth-next-42b8c2d72926.diff`. The worktree
    `linux-btnext` carries the edit.
  - Build: both sides build clean with W=1 against the 7.0.0-42 headers
    (`out/build-42-*.txt`; `.ko` files under `build-42/`, never loaded).
  - Model test: `scripts/notify-model/` copies the real `btusb_notify`/`btusb_work` code
    into a user-space model with 7 scenarios.
    - Original code: a link ends up on alt 0 in S2, S3, S4, S5 and S6, and S7 leaves an
      mSBC link on alt 2.
    - Candidate: no link on alt 0 and correct alts
      (`out/notify-model-orig.txt` vs `out/notify-model-patched.txt`).
  - Known limit: with mixed air modes the candidate keeps the last ENABLE's air mode. A
    complete fix needs the core to keep a per-connection air mode.
- **Other numbers.**
  - SCO setup window: about 30 to 200 ms (from the captures).
  - Read Buffer Size: SCO MTU 50 × 8.
- **QEMU:** not run. vhci has no notify callback, and there is no isochronous USB
  Bluetooth model, so it cannot show the effect. The source, the model and the 09-02
  journal settle the logic.

## Upstream state (2026-11-01)

- **Trees.** bluetooth-next tip `42b8c2d72926` (10-30). Mainline `c339f4010dea` (10-28,
  v7.4 merge window), which contains the btusb split `be58267a34ae5` (09-13).
- **btusb changes.** No change to the notify/work logic except `129fa608b6ad0` (03-25,
  clamps the CVSD alt index; already in -42).
- **Core changes.** `79a2d4678ba90` (2025-11-15, in for-net-2025-11-21) and `816fb1590a4c8`
  (09-26, in mainline and 7.3.y) touch the receive path. The "unknown connection handle"
  message remains after both.
- **List threads to note.**
  - v7.2 Intel 9260 regression, 10-21: "corrupted"/"unknown handle" floods, possibly xHCI.
  - MT7925 sentinel handle 0x0E00, 10-31.
  - Neither is our case.

## Running at pause (read-only; leave them, check output)

- `out/notify-race-all-boots.txt`: `scripts/notify-race-scan.py` over all 67 exports plus
  the current boot. It prints only at the end. Check: `grep -E "HIT|TOTAL|without alt"`.
  FINISHED during the pause (exit 0); not yet read.
- `out/archive-grep-sco-messages.txt`: per-boot counts of the two messages, for the era
  table. Check: `grep "match(es)"`. FINISHED during the pause (exit 0); not yet read.
- Completion shows as END lines in `progress.log`.

## Resumed 2026-11-01: scan results read

- Race scan: 281 pending SCO setups and 251 transparent ENABLE notifications across 68
  boots, with 2 race hits. Both are 2026-09-02, stock era, on a wedged controller (19:29:43
  in c128a59a, 19:39:41 in d0bc81b5). None is in the E1/E3 era. No transparent ENABLE was
  missing its alt search, so no mSBC link was ever seen running on alt 0.
- Message counts: 726 lines in the archived boots, 149 of them "corrupted SCO packet".
  The message is present in the stock era too (26 lines before 09-26, for example 09-02
  15:47:16 ×10).
- The final report was delivered in the session's final message.

## Next steps on resume (before reading the scans)

1. Read both outputs above. Count race HITs in the E3 era and any "ENABLE-TRANSP without
   alt search". Build the era table of message counts (stock / E1 / E3).
2. Optional: confirm the dossier's 10-20 11:55:51 and 10-21 00:12:37 lines are journald
   delays. Use `scripts/export-sco-context.py` on the archived boot holding 10-20, which
   the grep output names.
3. Write the final report: findings per item, a table, and the files to keep.
   - CO-20: close as explained and benign; no patch.
   - CO-18: drop as a kernel item. Fold U8's kernel line into CO-20. U8 stays open on the
     earbuds side; the operator check is a test sound in mSBC on E3.
   - CO-21: proceed, extended to the single-link race. The candidate patch needs an outside
     review and the upstream CI first. The hardware test (two headsets, or the race) is the
     operator's call.
4. Records now wrong:
   - `docs/issues.md` U8 ("×6 during the links");
   - the CO-20 dossier's "late by minutes" and "4 to 6 s late" readings;
   - the STATUS U8 row's next step;
   - the contributions index row for CO-21, which is not yet aware of the race.
