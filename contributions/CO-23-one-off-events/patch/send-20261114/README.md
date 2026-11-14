# CO-23 event 1 (U22): the send package brought to BlueZ master of 2026-11-14

**Two mails, BlueZ, not sent.** The 11-01 package (`../send/`) ported to master `20ffd285b58f`
(2026-11-12). In this order:
1. [`mails/0001-a2dp-Fix-use-after-free-when-switching-endpoints-dur.patch`](mails/0001-a2dp-Fix-use-after-free-when-switching-endpoints-dur.patch)
   — the fix, unchanged in code from `../send/` (only the `From` hash, blob ids and `base-commit`
   differ);
2. [`mails/0002-test-Cover-A2DP-endpoint-switch-while-Close-is-pendi.patch`](mails/0002-test-Cover-A2DP-endpoint-switch-while-Close-is-pendi.patch)
   — the test, merged by hand with master's new `test_a2dp_reconnect_pending_disconnect` (10-30) in
   `test_a2dp.py` and `doc/functional-a2dp.rst`; both kept, imports merged.

Recipients, route and the reviewer questions are as in `../send/README.md`. No `Signed-off-by`: the
operator adds it when sending.

## State on 2026-11-14
- **Not fixed upstream.** `a2dp.c:2173` on master still sets `setup->reconfigure = TRUE;` after
  `avdtp_close()`/`avdtp_abort()` with no reference held. The only commit to the A2DP/AVDTP files
  since 10-29 is `efabf8db4` ("a2dp: Fix refusing the AVDTP connection of a new link"), other code.
  No competing patch or report on patchwork since 10-29; the nearest, "avdtp: Fix use-after-free in
  connection_lost" (patchwork 14943182, `new`), is a different function in `avdtp.c`.

## What was run (`CHECKS.md`, tallies in `results/`, bot reports in `bot/`)

| Run (ASan/UBSan, the bot's image, two QEMU guests) | master + test only | master + fix + test |
|---|---|---|
| `test_a2dp_reconfigure_during_close`, 10 runs | fails 10 of 10, 3 ASan reports each: `heap-use-after-free`, WRITE of size 4 in `a2dp_reconfig` `a2dp.c:2173` from `set_configuration` `a2dp.c:2233`, freed in `setup_cb_free` `a2dp.c:341` | passes 10 of 10, 0 reports |
| all of `test_a2dp.py` (6 cases), 1 run | 5 passed, the new case failed | 6 passed, 0 reports |

The bot's checks (`scripts/bot-ci-local.sh --space user`) on exactly these two mails, base vs
patched: every check PASS on both sides, exit 0; TestFunctional 53 → 54 passed (the new case),
1 skipped on both.

**Checked on copy (2026-11-14):** the 20 tallies in `results/`; the ASan report in the raw guest log
of base run 1 (use stack `a2dp_reconfig a2dp.c:2173` ← `set_configuration a2dp.c:2233`; freed by
`setup_cb_free a2dp.c:341`); the bot summary (`ALL DONE, exit 0`) and both reports; `5071fadb97b8`
(the `Fixes:` target) exists in BlueZ ("a2dp: Try aborting when switching endpoints").
checkpatch (`--no-tree`, the BlueZ list's non-strict mode) on both mails: only "Missing
Signed-off-by" (expected, added at send) and "Unknown commit id" for the BlueZ `Fixes:` hash
(no kernel tree; the hash exists in BlueZ).

**Changed on copy:** one line of `CHECKS.md` §4 reworded. Left in the work area: the guest and
pytest logs, the bot's per-check logs (emulated addresses), the fetched patchwork pages, the build
trees.

## Decisions for the operator (`NOTES-FOR-OPERATOR.md`)
1. Send or not, and the list route vs BlueZ's `SECURITY.md` private-advisory route.
2. Whether to replace the test's `PausedBluetoothd` host plugin by master's new
   `vm_signal_bluetoothd()` helper (about 40 lines less; would need its own runs).
