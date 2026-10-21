# CO-03 log

Append-only. Newest last.

## 2026-10-19 — U12 registered
- **19:33:58:** Chrome opened the microphone while A2DP was starting on the MOMENTUM 4.
  WirePlumber switched to Handsfree and released the transport mid-Start, and BlueZ 5.72
  sent an AVDTP Abort that the headset never answered. A2DP stayed gone until a reconnect
  (`EX-063`, `EX-064`).
- **The fix:** `a14d59725`, upstream since 5.80.
- **Found the same day:** the running bluetoothd lacks Ubuntu's October CVE fixes.

## 2026-10-20 — upstream and Ubuntu checked
- **Launchpad:** noble is at `5.72-0ubuntu5.8` (security) and `5.7` (updates).
- **Bug searches** ("A2DP abort", "Failed to restore profile"): no results.
- **BlueZ:** no tag newer than 5.87.

## 2026-10-21 — the fix does not apply to 5.72
- **Reviewer 1 said so** without naming what conflicts.
- **Checked:** `git format-patch -1 a14d59725`, then `git apply --check -v` on a 5.72
  worktree (`tmp/research-20261021/bluez-5.72`). Hunk 1 applies at −8; hunk 2 fails at
  `transport.c:394`.
- **The range:** `git log --oneline 5.72..a14d59725~1 -- profiles/audio/transport.c` lists
  24 commits.
- **Full record:** `reviews/2026-10-21T0009Z-source-investigation-reviewer-1.md`, SI4.

## 2026-10-21 — dossier opened
