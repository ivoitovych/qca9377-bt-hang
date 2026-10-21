# CO-20 log

Append-only. Newest last.

## 2026-10-13 — first noted
Three "SCO packet for unknown connection handle" lines on 2026-10-13, 02:01 to 02:51, were
noted in STATUS while reading the abrupt stop. Not followed up.

## 2026-10-21 — measured
- **Command:** `journalctl -k -b 0 -p err --grep "unknown connection handle" -o short-iso` gave
  14 lines:

  | time | handle |
  |---|---|
  | 2026-10-20 11:53:08 | 9 (×3) |
  | 2026-10-20 11:55:45 | 10 (×2) |
  | 2026-10-20 11:55:51 | 10 |
  | 2026-10-20 12:42:12, 12:42:13 | 13 |
  | 2026-10-20 12:52:35 | 14 |
  | 2026-10-21 00:12:33, 00:12:37 | 17 |
  | 2026-10-21 00:19:49 (×2), 00:19:50 | 18 |

- **Command:** `scripts/sco-ledger.sh 0` gave 9 links, 9 hang-ups answered, 0 timeouts.
- **The comparison:** setup time plus streamed seconds puts the ends at 11:53:08, 11:55:45,
  12:19:36, 12:41:49, 12:42:12, 12:52:35, 23:57:09, 00:12:33 and 00:19:49.
- **The result:** 6 of 9 hang-ups carry the message. Two lines come 4 to 6 s late.
- **Elsewhere:** BlueZ #2562 shows the same message on an Intel AX211, with "corrupted SCO
  packet".

## 2026-10-21 — source read; reviewer 1 checked
- **The source:** both messages located, and `btusb_validate_sco_handle()` read.
- **Reviewer 1** said "residual URBs" and "reassembly failures explain silence". The first
  does not explain seconds, and the second is one reading among others.
- **Full record:** `reviews/2026-10-21T0009Z-source-investigation-reviewer-1.md`, SI2.

## 2026-10-21 — dossier opened

## 2026-10-21 — reviewers 2, 3 and 4
- **All agree:** "unknown handle" means the connection existed when btusb took the packet and
  was gone when it was handled. "Corrupted" also fires for data of a deleted connection.
  Queued URBs do not explain 4 to 6 s.
- **Reviewer 3:** the corrupted packets are on the microphone side (controller → host), so
  they do not by themselves explain silent playback.
- **Reviewer 4:** PipeWire 1.0.5's `sco_start_source()` waits for the first received packet
  before sending. Not read here.
- **The next run, as all suggest:** one hang-up with btusb dynamic debug, usbmon and btmon,
  timing the Disconnection Complete, btusb's switch to alt 0 and each late packet. This is a
  laptop run, so it is the operator's decision.
- **Full record:** `reviews/2026-10-21T0033Z-source-investigation-reviewers-2-4.md`, RV2.
