# CO-23 event 1 (U22): `a2dp_reconfig()` use-after-free, brought to 2026-11-14

Nothing is sent. The mails (`mails/`, BlueZ, no Signed-off-by, `[PATCH BlueZ 1/2]` and `2/2`, no cover
letter) are the 11-01 draft ported to BlueZ master `20ffd285b58f` (2026-11-12); author is you.
Evidence and commands: `CHECKS.md`.

## State today
- **Not fixed upstream**: `a2dp.c:2173` on master is still `setup->reconfigure = TRUE;` after the
  `avdtp_close()`/`avdtp_abort()` calls. The only commit to the A2DP/AVDTP files since the dossier's
  re-check (`82667d713949`, 10-29) is `efabf8db4` (10-30, "a2dp: Fix refusing the AVDTP connection of a
  new link", Luiz Augusto von Dentz): different code. No competing patch or report: patchwork since
  10-29 has "avdtp: Fix use-after-free in connection_lost" (Jinwang Li, 14943182, `new`), a different
  function in `avdtp.c`.
- Reproduced again on today's master (ASan, bot image, two QEMU guests): the new test fails 10 of 10
  without the fix at the same line, passes 10 of 10 with it.

## What changed in the package since 11-01
- The fix (patch 1) is **unchanged** (same code; only the `From` hash, the blob ids and `base-commit`
  differ in the mail).
- The test (patch 2) needed a manual merge: master gained `test_a2dp_reconnect_pending_disconnect`
  (10-30, "test: Cover A2DP reconnection with a pending disconnection") in the same two places of
  `test_a2dp.py` and `doc/functional-a2dp.rst`; both are kept, the imports merged (`logging`, `signal`,
  `subprocess`). Nothing else in the test changed.

## Decisions for you
1. **Send or not, and by which route.** Unchanged from the dossier: the list route vs BlueZ's
   `SECURITY.md` (private advisories) is yours. I did not look at that question again.
2. **Reuse master's `vm_signal_bluetoothd()`** (the new test's helper: `pkill -SIGSTOP/-SIGCONT -x
   bluetoothd` through `host.call()`) instead of our `PausedBluetoothd` host plugin? That would remove
   about 40 lines from patch 2, and it answers the old reviewers' question 2 ("is stopping the peer's
   bluetoothd acceptable in the functional suite?": master now does it). Not done: the plugin version
   has the 15/15 and 10/10 runs behind it; the helper variant would need its own runs (the teardown
   safety of the `finally` is the same). Say if you want it.
3. The reviewer questions of the send README (shape of the fix; subject and `Fixes:`; the split of the
   test into its own patch) stand.
4. The dossier's Ubuntu 24.04 (5.72) backport note: the defect has been there since 5.51; unchanged.

## Not done here
- The path where the Abort cannot be sent after the Close was canceled (no ordinary test makes the send
  fail): covered by reading only, as in the dossier.
- `make check` was run by the bot's MakeCheck/MakeDistcheck (see `CHECKS.md`), not separately.
- Nothing on the laptop; no non-root reachability run.

## BT-6 records (item 3: lines still wrong; I did not edit anything)
Checked in `/root/exp/qca9377-bt-hang` on 2026-11-14. Already right: `docs/STATUS.md:64` (15 lines,
benign race, CO-23's 12 instants), `docs/issues.md:19-28` (answered 11-11), `docs/issues.md:172`
("not 'observed once': 15 lines"), the `Status 2026-11-12: not once` paragraph at `docs/issues.md:612`,
`contributions/README.md:68`. **Still wrong or stale:**
1. `docs/issues.md:~617` `**Reportable:** ❌ no — a single occurrence with no mechanism and no second
   instance.` Contradicted by the line above it (15 lines) and by CO-23 (mechanism found, benign).
   Suggested: `no — a benign race (data after disconnect at power-off); only a log-level change could be
   offered, not worth sending without a user complaint (CO-23 event 2)`.
2. `docs/issues.md:~626-638` (the body after the log excerpt): "That is a host/controller **state
   disagreement**, and it is a different signature from the `0x2005` desync in BT-2", "Recorded rather
   than investigated. It may be noise, it may be a symptom of BT-1, or it may be a third independent
   state-tracking defect. Deciding which needs a second instance", and the "family resemblance"
   paragraph (BT-2, BT-6, BT-1 as state disagreements). CO-23 settled it: not a host/controller
   disagreement, not related to BT-1 or BT-2; all 12 distinct instants fall 17 to 32 ms after a
   connection was marked closed during an adapter power-off (10 of 12 by the project's watchdog on
   08-12); `hci_rx_work()` ordering plus separate USB endpoints for events and ACL data. These three
   paragraphs should be replaced by that verdict or marked as superseded.
3. The section heading `BT-6 — Controller delivers ACL data for a connection handle the host does not
   know` (`docs/issues.md:610`) states the controller as the actor; CO-23's reading is host-side
   ordering (the data frame was queued after the Disconnection Complete). Optional wording change.
4. `docs/STATUS.md:64` and `docs/issues.md:612`/`:172` say "none since **10-12**". CO-23 found no
   ACL line after **08-19** in any of the 64 archived boots (to 10-23) nor in boot 0
   (`investigation-2026-10-28.md` lines 257, 320). I found no source for "10-12" (the 11-11 grep
   output is not in `results/laptop-only-work-2026-11-11/`); if the 11-11 grep really covered boots up
   to 11-11 and found none after 08-19, the date should read "none since 08-19", otherwise it is
   unexplained. Please check against `journal-archive-grep.py`'s output before editing.
5. U22 rows (not BT-6, for completeness): `docs/STATUS.md:110` says "master re-checked 2026-10-29";
   today's re-check is 2026-11-14 at `20ffd285b58f` (still not fixed). The records that called the
   crash "unrelated"/"cleared" now carry the mechanism (`BRIEF.md:389-392`, `patches/bluez/README.md:
   260-264`, `docs/contributions-roadmap.md:25`); `BRIEF.md:341` is a different row now (the dossier's
   line number is stale). Exhibit 041 not checked.
