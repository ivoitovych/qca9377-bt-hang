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

## 2026-10-21 — the backport recipe found (reviewer 4) and checked
- **The recipe:** apply `3d9900eb7` ("transport: Delay existence based on delay reporting
  capability") to the 5.72 worktree. Its hunks apply at small offsets.
- **Then `a14d59725`:** hunks 1 to 5 apply. Only the last fails, on the `A2DP_OPS` macro
  (`transport.c:2280`), which later gained a delay parameter.
- **So the backport is:** the `transport_a2dp_get_stream()` helper part of `3d9900eb7` (not
  its delay-reporting feature, which also touches `avdtp.c`/`.h`), all of `a14d59725`, and the
  `A2DP_OPS` line wired by hand.
- **Reviewer 3:** `a14d59725` introduces its own state; there is no semantic prerequisite.
- **Companions to audit** (reviewer 4): `664a5d3785a1` (`setup->sep` during
  reconfiguration), `aa118e965b02`, `47da1efdc584`, `87ad4c66b934`.
- **Reviewer 4's decisive test:** an AVDTP peer that delays START_RSP; Acquire then Release;
  expect an Acquire error, then START, then SUSPEND, and no ABORT; retry Acquire, and repeat
  with reconfiguration.
- **Note:** the scratch worktree `tmp/research-20261021/bluez-5.72` now has `3d9900eb7`
  applied, uncommitted.
- **Full record:** `reviews/2026-10-21T0033Z-source-investigation-reviewers-2-4.md`, RV6.

## 2026-10-31 — U12 again; backported, built and tested off the laptop
- **U12 struck again** at 13:42:16 (EX-084 to EX-088).
- **Backport:** five commits on `5.72-0ubuntu5.8`:
  - `a734b06059cb` and `0bed9886cff3` (BT-7);
  - the `transport_a2dp_get_stream()` part of `3d9900eb754d`;
  - `a14d59725ef3`, with the `A2DP_OPS` hunk wired by hand;
  - `664a5d3785a1`.

  Not taken: `aa118e965b02`, `47da1efdc584` and `87ad4c66b934`; the reasons are in
  `backport/README.md` §1. The package is `5.72-0ubuntu5.9~co03.1`, with the same warnings
  and `make check` results as base.
- **Tests:** the plan was written first and run on base, then the same files ran on the
  backport. Results:
  - the trigger (T201–T207, ten runs each): A2DP lost 70/70 on base, 0/70 on the backport;
  - the unit harness: 27 → 35 of 35;
  - the VM tests: 17 → 31 of 31;
  - PipeWire master: T310 0/11 → 11/11, and T312 fail → pass.

  Every changed outcome is a leak test.
- **New facts:**
  - 5.72 never answers the cancelled `Acquire()`.
  - A remote that answers ABORT loses A2DP within 5–7 ms. U12 is not limited to headsets
    that ignore ABORT.
  - A client exiting with its Acquire pending still sends ABORT on the backport, as it does
    upstream.
- **Seen at bluetoothd exit on both builds:** two use-after-free reports from ASan (`media.c:300`,
  `device.c:6167`), in code the backport does not touch (`backport/runs/asan-exit-reports.txt`).
  Not investigated.
- **Remains for the operator:** install on the laptop, repeat the trigger with the
  MOMENTUM 4 (T320/T321), and decide on filing (draft in `backport/README.md` §7).
