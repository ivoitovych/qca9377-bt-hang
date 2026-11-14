# CO-37: the master series brought to BlueZ master of 2026-11-14

**Six mails, BlueZ, not sent, no Signed-off-by.** The 11-02 series
(`../work/patches/master-final-6-20261102/`) rebased on master `20ffd285b58f` (2026-11-12):
- `patches/0001`–`0002`: CO-23's fix and test (U22). They are byte-identical in `git patch-id
  --stable` to `../../CO-23-one-off-events/patch/send-20261114/mails/`.
- `patches/0003`–`0005`: the three `media.c` fixes (U23: the deferred-removal read, the duplicate
  Release, the release order at adapter removal).
- `patches/0006`: their test.

`patches-series-B-standalone/` holds the same three fixes with a version of the test that applies
without CO-23. It answers D13 (one series or two). The bot was not run on it.

## State on 2026-11-14 (`CHECKS.md` §1)
- **Not fixed upstream.** `media.c` is byte-identical to the series' old base `14bd6ab65`. No
  equivalent is on patchwork since 10-25.
- **A field report with the same top frames:** BlueZ issue #2616, opened 2026-10-01. It shows
  `media_endpoint_remove` ← `a2dp_unregister_sep` ← `transport_a2dp_suspend` on Fedora's 5.87
  snapshot, 6 to 8 crashes, with bluez-alsa as the client. The stale bot closed it on 11-10 with
  no fix. That it is the same defect is inferred: the report has no line numbers.
- U24's fix `7e3212fa233e` is in master and in 5.88.

## What was run (`CHECKS.md` §3–4, tallies in `results/` and `logs/results-summary.txt`)

| ASan/UBSan, QEMU guests, kernel bluetooth-next `da3cc0258` | master | master + six |
|---|---|---|
| the two exit tests, 10 runs | 10/10 fail, `media_endpoint_remove media.c:321` | 0/10 |
| Release count (`[endpoint]` gets 2), 10 runs | 10/10 fail | 0/10 |
| CO-23's reconfigure test, 5 runs | 5/5 fail, `a2dp.c:2173` | 0/5 |
| whole `test_a2dp.py`, 2 runs | 2/2 fail | 2/2 all 10 pass |
| `make check`; build warnings | 41 pass, 1 skip; 0 | 41 pass, 1 skip; 0 |
| series B: the exit tests, 10 runs | — | 0/10 |

The bot's checks (`scripts/bot-ci-local.sh --space user`) gave exit 0, with every check PASS on
both sides. CheckPatch and GitLint pass on all six mails. TestFunctional went from 53 to 58
passed: the five new tests.

**Checked on copy (2026-11-14):**
- the results summary: every tally above;
- the raw guest log of master's exit-test run 1: `heap-use-after-free`, top frame
  `media_endpoint_remove profiles/audio/media.c:321`;
- the series' exit-test logs: 0 ASan reports;
- the bot summary (`ALL DONE, exit 0`) and both TestFunctional counts (58 and 53 passed);
- `git patch-id --stable` of mails 1 and 2 against CO-23's mails: equal;
- checkpatch `--no-tree --max-line-length=80` on all six mails: nothing beyond "Missing
  Signed-off-by" and "Unknown commit id" for BlueZ hashes.

**Changed on copy:** two lines of `CHECKS.md`. Line 20 now says the old placeholder-author mails
stay in the work area; line 58 is reworded.

**Left in the work area:** the guest and pytest logs, the bot's per-check logs (emulated
addresses), the fetched pages, the clone and build trees, and the 11-02 mails with a placeholder
author. `SHA256SUMS` covers this copy.

## Decisions for the operator (`NOTES-FOR-OPERATOR.md`)
- **D3, the route:** the list, or BlueZ's `SECURITY.md` draft advisory. CO-23 has the same
  question.
- **D13:** one series of six, or CO-23's two plus series B's four.
- **D9:** the subject lengths (50 to 64 columns; 255 of master's last 500 subjects exceed 50).
- **F-51:** whether mail 6 should reuse master's `vm_signal_bluetoothd()` helper instead of the
  host plugin.

Not run today: U25, U26 and U27 (5.72 only), and the 5.72 backport. `media.c` is unchanged and
`a2dp.c`'s changes do not touch these paths, as read from the source.
