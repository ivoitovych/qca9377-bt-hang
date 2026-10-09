# BlueZ shared/mgmt fix: second review round (2026-10-07 evening)

Reviewed: `36d3f2f` (REVIEW-REQUEST of 2026-10-07, series `ca5412447`/`b94779c29` on
`4dc15be8e`). Reviewers 2 and 3. Nothing has been sent.

Result: series on `cache/bluez-standalone-mgmt-leak`, branch
`standalone/shared-mgmt-notify-leak-on-d84171e6c`, on BlueZ master `d84171e6c`:

* `559b1a787` shared/mgmt: Fix notify leak in mgmt_unregister() (code unchanged)
* `821fa0976` unit/test-mgmt: Test unregistering from callbacks (tests revised)

Exported to `patches/mesh-tester/bluez-shared-mgmt-notify-leak-on-d84171e6c/`.
Earlier states are kept on `standalone/shared-mgmt-notify-leak-2026-10-07` and
`keep/shared-mgmt-notify-leak-on-d84171e6c-3522bea03`.

## Findings and actions

| # | Finding (reviewer) | Checked | Action |
|---|---|---|---|
| 1 | "Unregistering an entry already marked removed still fails" hides a change: an id marked by `mgmt_unregister_all()`/`_index()` while notifying returned `true` before and `false` now (2, 3) | Verified: unpatched `mgmt_unregister()` finds the marked entry with `queue_remove_if()` and returns `true`; the run with the return check removed (below) shows it | message now states both facts separately |
| 2 | Before `872729a91632`, `_all()`/`_index()` removed at once, so the new `false` restores the old semantics (2) | Verified: `git show 872729a91632 -- src/shared/mgmt.c` (both switched from `queue_remove_all()` to marking while `in_notify`) | "as it did before those functions deferred removal" |
| 3 | Shorten the tester paragraph (2, 3) | Agreed | one sentence; numbers kept here |
| 4 | Test 5 checks destruction only after `mgmt_unref()` in teardown, so teardown could supply it (3) | Verified (`unregister_all_from_cb` quit inside the callback; final check after `execute_context()`) | every case now ends in an idle callback that checks destruction before teardown; callbacks still dispatching check that nothing is destroyed yet |
| 5 | `g_assert_true()`/`g_assert_false()` need GLib 2.38; `configure.ac:85` requires 2.36 (3) | Verified | `g_assert_cmpint(…, ==, true/false)`, as the file already does for `write()` |
| 6 | Test 5's unpatched failure stops at the return-value check, so it shows nothing after it (3) | Measured with an uncommitted variant without that check: `/mgmt/unregister/5` → `AddressSanitizer: heap-use-after-free` (`d84-unfixed-diag-no-return-check-unregister-5.log`) | recorded; the committed test keeps the check |
| 7 | userchan-tester's `index_removed_callback()` also unregisters while notifying (3) | Verified (`tools/userchan-tester.c:113-125`) and measured (below) | added to the runs and to the message |
| 8 | Rebase on master `d84171e6c` (2, 3) | 7 new commits; none touches `mgmt.c`, `queue.c`, `test-mgmt.c` (`git diff --stat 4dc15be8e origin/master -- …` lists only `tools/mgmt-tester.c`) | rebased, everything rerun |
| 9 | Test subject 62 chars; HACKING prefers 50 (2, 3) | Agreed | `unit/test-mgmt: Test unregistering from callbacks` (49) |
| 10 | `pre-send-check.sh` reads only the first line of a folded Subject and checks each patch alone (3) | Verified | fixed on main `e2a6995`: unfolds, applies the series in order |
| 11 | Subject could name both symptoms (2, optional) | — | kept: reviewer 3 prefers it as is |

Also new: master `d84171e6c` is our a2dp v2, applied on top of v1, so master checks
`setup->stream` twice. Recorded on main (`dd8d241`, `patches/bluez/README.md`) with an unsent
cleanup patch.

## Unit cases (`unit-mgmt-run.sh`, one process per case)

| case | unfixed `mgmt.c` (master) | first version (`bdd3acd51`) | fix (`559b1a787`) |
|---|---|---|---|
| 9 existing | PASS | PASS | PASS |
| unregister/3 | FAIL `test-mgmt.c:473:unregister_check_idle: assertion failed (test->destroyed[i] == test->removed[i]): (0 == 1)` | FAIL `test-mgmt.c:485 … (mgmt_unregister(mgmt, test->id[n]) == false): (1 == 0)` | PASS |
| unregister/4 | FAIL `AddressSanitizer: heap-use-after-free` | FAIL `test-mgmt.c:485 …` | PASS |
| unregister/5 | FAIL `test-mgmt.c:531 … (mgmt_unregister(mgmt, test->id[2]) == false): (1 == 0)` | FAIL `test-mgmt.c:485 …` | PASS |
| unregister/6 | PASS | PASS | PASS |

Logs `d84-unfixed-*`, `d84-first-version-*`, `d84-fixed-*` in
`tmp/mesh-tester-ci/logs/unit-mgmt-2026-10-07/`.

## Testers in QEMU, full allocation stacks (`runs-bluez-standalone-d84171e6c.sh`)

Guest kernel `bzImage-val-btnext-control` (`036d4119079a`); launcher test-runner; each tester run
through `asan-fullstack.sh` (`ASAN_OPTIONS=fast_unwind_on_malloc=0:malloc_context_size=30`) so
that leak records carry the whole call chain. Binaries: `bin-unfixed-d84171e6c` (mgmt.c blob
`f56bcee14`) and `bin-fixed-on-d84171e6c` (blob `f5aeecf3f`), both built at `d84171e6c`.

| tester | result, unfixed and fixed | verdicts | leaks, unfixed | leaks, fixed |
|---|---|---|---|---|
| mgmt-tester | `Total: 506, Passed: 502 (99.2%), Failed: 4` both | `cases with different verdicts: 0` | `SUMMARY: … 9240 byte(s) leaked in 233 allocation(s).` | `… 120 byte(s) leaked in 5 allocation(s).` |
| mesh-tester | `Total: 10, Passed: 8 (80.0%), Failed: 2` both (Send cancel 1/2 timeouts) | `cases with different verdicts: 0` | `… 120 byte(s) leaked in 3 allocation(s).` | none |
| userchan-tester | `Total: 4, Passed: 4 (100.0%)` both | `cases with different verdicts: 0` | `… 80 byte(s) leaked in 2 allocation(s).` | none |

`leak-stacks.py` (allocating function after the allocator wrappers):

* mgmt-tester unfixed: `mgmt_register (src/shared/mgmt.c:974): 21 record(s), 9120 byte(s) in 228
  object(s)` and `btdev_add_hook (emulator/btdev.c:8891): 2 record(s), 120 byte(s) in 5
  object(s)`; fixed: only the `btdev_add_hook` line.
* mesh-tester unfixed: `mgmt_register (src/shared/mgmt.c:974): 1 record(s), 120 byte(s) in 3
  object(s)`; fixed: none.
* userchan-tester unfixed: `mgmt_register (src/shared/mgmt.c:974): 1 record(s), 80 byte(s) in 2
  object(s)`; fixed: none.

The attribution to `mgmt_register()` is now **direct** (full stacks), not inferred from size.
The 4 mgmt-tester failures (`Add Ext Advertising - Success 5 (Set Adv off override)`, three
`(Global Adv)` cases) are identical with and without the fix; not investigated.
`splat-check.sh`: mesh and userchan logs `clean`; mgmt logs only mgmt-tester's own `command
0x0405 tx timeout` ×2 in both.

## Build, lint, check

* `make -j16 check` at `821fa0976` (`make-check-821fa0976.log`): `# TOTAL: 42`, `# PASS:  41`,
  `# SKIP:  1`, `# FAIL:  0`, `# ERROR: 0`; no compiler warnings.
* `bluez-lint.sh`: checkpatch `0 errors, 0 warnings` (35 and 227 lines); gitlint `PASS` both.
* `pre-send-check.sh` (revised): origin/master `d84171e6c`; both apply in order; `OK to send`.
* Author dates reset (`git rebase --ignore-date origin/master`); `git diff --stat 3522bea03
  HEAD` empty: the code is the code that was tested.
* Checksums: `logs-bluez-d84171e6c-SHA256SUMS` (85 entries, `all entries OK`).
