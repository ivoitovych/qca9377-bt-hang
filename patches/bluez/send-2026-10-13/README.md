# Two BlueZ patches, prepared 2026-10-13. NOT SENT in this form (superseded)

**Superseded 2026-10-18 by [`../send-2026-10-18/`](../send-2026-10-18/README.md)**: A1 retitled
without `Fixes:`, A2 rewritten with `newa()`, both re-tested on master `fa6ba5502`. Kept as
the record of the first version and its tests.

Both are on BlueZ master `9dc7e4096` (fetched 2026-10-13), one mail each, unrelated to each
other. Sending is the operator's decision; an outside review recommended sending both, A2 after
the fix below.

| file | what | commit |
|---|---|---|
| `0001-a2dp-Remove-duplicate-stream-check-in-transport_cb.patch` | **A1.** `transport_cb()` checks `setup->stream` twice, because our v1 (`0bed9886cff3`) and the redundant v2 (`d84171e6cd68`) were both applied. Removes the second copy (5 lines) | `ddc71e8b3`, branch `send/a1-a2dp-cleanup-20261013` in `cache/bluez-send-20261013` |
| `0001-emulator-Avoid-variable-length-array-in-send_cmd.patch` | **A2.** `send_cmd()` is called with one or two iovec entries. A fixed array plus `assert(iovlen > 0 && iovlen <= SEND_CMD_IOV_MAX)` replace the variable length array that smatch reports on every patch touching `btdev.c` | `694d9cba1`, branch `send/a2-btdev-vla-20261013` |
| `TEST-REPORT.md` | builds, unit tests, smatch, the clang analyzer, 11 emulator testers in QEMU (two rounds), and A2's positive control | — |

**History of A2.** The first version (2026-10-10, on `ci/upstream-ci-local`) returned
silently when given too many entries, and did not cover zero entries. An outside review
(2026-10-13) flagged both. A second round noted that `util_debug()` prints nothing without a
callback.

**Why `assert()`:**
- `src/shared` uses `assert()` for internal invariants (`gatt-client.c`);
- BlueZ never defines `NDEBUG`;
- in a test emulator, a broken caller should stop the test at the mistake.

Both current callers pass constants, so the compiler removes the check today; it guards future
callers. The positive control shows it aborts for 3 entries and for 0.

**A1's message** was first shortened, then corrected: checkpatch requires
`commit <sha> ("<title>")` for commit references (`ERROR:GIT_COMMIT_ID`).

**Checks on the final files:**
- `scripts/pre-send-check.sh`: both apply, "OK to send".
- checkpatch with BlueZ's config: 0 errors, 0 warnings for both.
- gitlint with BlueZ's config: PASS for both.

**Before sending:**
- rerun `pre-send-check.sh` on the day (master moves);
- `scripts/mail-lint.sh` on the mails;
- send each mail separately to linux-bluetooth@vger.kernel.org;
- no `Signed-off-by` (BlueZ);
- no reply on the old v2 threads.
