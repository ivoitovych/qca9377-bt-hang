# CO-37 log

Append-only. Newest last.

## 2026-10-31 — found in CO-03's runs
- **ASan at bluetoothd exit**, in the Fedora 44 ASan builds of 5.72 in CO-03's VM tests:
  - `media.c:300 in clear_endpoint`: 3 of 10 runs on base, plus 1 on the fixture's build;
    2 of 10 on the backport.
  - `device.c:6167 in device_set_rssi_with_delta`: twice.
- Registered as U23 and U24.
- **The same night, CO-36 part 2:** one `media.c:312 in media_endpoint_remove` at BlueZ
  `ebbb4ee31ad7`, 1 in about 150 shutdowns.

## 2026-11-01 — reproduced, fixed, backported (VMs only)
- **U23:** present on master `14bd6ab65`.
  - Two fixes and a functional test; 10/10 failing before, 0/10 after.
  - 5.72 reproduces it line for line; its two-patch backport gives 0/10.
  - The `ebbb4ee31ad7` case is the same defect (the read added by `7482aceece70`).
- **U24:** fixed upstream by `7e3212fa233e` (2026-09-04, not released). Master 0/10, and 10/10
  with that commit reverted; 5.72 10/10, and 0/10 with the backport.
- **Checks:** CheckPatch clean; `make check` the same on both sides; the functional suite
  changes only by the new tests.
- Nothing sent. The full logs are in `/root/exp/agent-work/exit-uaf/`.

## 2026-11-01 — review round: a wrong sha corrected
- The 5.72 backport of fix 2 (`work/patches/5.72/0002-…`) named `Fixes: ee0f3c03f6fa`, which does
  not exist (`git cat-file -t ee0f3c03f6fa` → "Not a valid object name"); the commit is
  `ee0f3c03fb1d` ("media: Fix UnregisterApplication", first in 5.60), as the master patch says.
  Corrected in the patch file. Found by an outside reviewer, checked here.
- Also confirmed by the round: CO-23's and CO-37's test patches each apply to BlueZ `14bd6ab65`
  alone but conflict when stacked, in either order (`test/functional/test_a2dp.py`,
  `doc/functional-a2dp.rst`); a coordinated rebase is owed before either is sent.

## 2026-11-01 — rebased on CO-23, adjacent states tested, a new crash (U25)
ASan builds in the bot's image and QEMU guests, 10:08 to 12:31; nothing sent; this machine's
Bluetooth untouched. Everything is in `work/review-20261101/`: `results/totals.txt` (every run),
`results/facts.txt` (source facts with commands and output), `results/TREES.md`, the bot's
summaries, the local tests as patches, the proposals, the scripts. Raw logs stay local in
`/root/exp/agent-work/co23-co37-review-20261101/` (7.6 GB, including about 2.3 GB of zstd-compressed
cores).
- **Rebase:** `work/patches/master-stacked-20261101/` on BlueZ `14bd6ab65` after CO-23's two mails;
  the fixes' patch-ids unchanged; only the test's context and imports changed. Fix 1 retitled
  "media: Fix use-after-free of app removing a locked A2DP endpoint": the bot's GitLint failed the
  original (81 > 80); the original-title set is kept in `original-title/`. Patch 3 no longer applies
  without CO-23's test patch: send CO-37 after CO-23 lands, or all five as one series.
- **Stacked runs:** base + both tests, 3/3 runs fail (`a2dp.c:2173`, `media.c:321`); base + both
  series 3/3 pass; whole `test_a2dp.py` 3 fail / 4 pass on base, 7/7 patched, twice each.
  `make check` 41 pass, 1 skip, both sides.
- **Bot's checks on the exact five mails:** as in CO-23's log (all PASS but the title, now fixed,
  and one CheckValgrind abort of `unit/test-bap` under load, PASS on rerun); TestFunctional 48 → 51.
- **Adjacent state (another client holds the transport through a second bus connection, the
  endpoint is removed; 12 variants, 10 runs each):**

  | variant | base | fix 1 | fixes 1+2 |
  |---|---|---|---|
  | unregister (legacy endpoint), then bus loss | 10/10 `media.c:412` | 10/10 `:412` | **10/10 `:412`** |
  | unregister (application), then bus loss | 10/10 `media.c:321` | 10/10 `:412` | **10/10 `:412`** |
  | unregister (legacy endpoint), then adapter removal | 0/10 | 1/10 `:412` | 0/10 |
  | unregister (application), then adapter removal | 0/10 | 1/10 `:412` | **1/10 `:412`** |
  | every SIGTERM and every owning-client-exit variant | 0/10 | 0/10 | 0/10 |

  The series does not cover a removed-but-held endpoint at bus loss. Adapter removal was done by
  detaching hci0's line discipline in the guest.
- **U25, new:** after the removal, the other client calls `Release` → `SEGV a2dp.c:3566 in
  a2dp_sep_unlock` (NULL `sep`), every run of all four variants with the fixes (6 or 7 each), three
  of four on base; 5.72 `a2dp.c:3254`, 5/5. Chain in STATUS U25. While running; needs no exit.
- **Proposals (local experiments, not in the series, unreviewed):** a `media.c` release from idle
  only moved the crash to `a2dp.c:350 setup_cb_free` (4/4); `a2dp.c`, unregistering a removed SEP
  from a zero timeout cancelled on server teardown, gave 0 failures in all 20 variants (2 to 5 runs
  each), the A2DP file 2/2, `make check` clean, no build warnings. It leaks removed SEPs still pending
  at server teardown. Neither had 10-run rates.
- **Bastien Nocera's RFC (patchwork 14568134):** applies as posted; CO-37 applies on top. RFC alone
  10/10 fail in both CO-37 tests (`media.c:321`); RFC + CO-37 10/10 pass. Its `g_slist_find` guard
  in `release_endpoint` comes after the failing reads.
- **Fedora:** 5.87-3 is the 2026-07-15 mass rebuild (only Patch1, `0001-adapter-Fix-crash-on-
  dev_disconnected.patch`); 5.87-4 (2026-07-17, `ab04c8e31d7a`) carries `7482aceece70` inside
  `5.87-bug-fixes-1.patch` (line 1114). An outside review's "5.87-3, 2026-07-17" means 5.87-4.
- **Disk:** the ASan cores filled the root filesystem's user space at about 11:27; nothing was
  deleted; 233 cores were compressed in place (each verified) and the remaining crashing batches
  were capped. Free space afterwards about 21 GB.

## 2026-11-01 (evening) — who owns an a2dp_sep: source reading of the U25 proposal
Source only, master `14bd6ab65f4a`; nothing built or run. Work area (local):
`/root/exp/agent-work/audio-ownership-20261101/`.
- **The proposal's passes are partly leaks.** Read from the existing debug logs
  (`adapter-order.py`, read-only): in the proposal's bus-loss runs no "SEP … unregistered" line
  appears at all, where the stacked tree unregisters and then crashes. In the adapter-removal runs
  the AVDTP connection is lost before `adapter_remove()` and no SEP is unregistered on either tree,
  so the 9/10 adapter-removal passes with both fixes were passes because the SEP leaked.
- **Master leaks a SEP removed while locked** when its client then leaves the bus
  (`release_endpoint` skips `clear_endpoint`, `media.c:658-659`) or the locked stream goes idle
  (the unlock returns at `a2dp.c:3571-3573` before the removed-SEP check at 3586). What remains
  is then destroyed with a NULL destructor in `a2dp_server_unregister()` (`a2dp.c:2916`).
  Inferred, not run: in the proposal a later bus exit of such a client after adapter removal reads
  the freed server in `a2dp_remove_sep()`.
- **Proposal details (source):** a SEP is tracked even when `timeout_add()` fails; SEPs pending at
  server teardown are never unregistered; on master a zero timeout is an idle source (`3bce4ad01`,
  2026-10-21), on 5.72 a default-priority timeout, so the re-lock window differs.
- **Side finding, inferred:** on master, `path_free` appears to send `MediaEndpoint1.Release` twice
  to an unlocked A2DP endpoint (`media.c:671`, then 674 → `a2dp.c:3064` → 2893 → `media.c:806` →
  671). Not measured.
- **Alternatives drafted (local experiments, applied nowhere):** amendments to the timer
  proposal; and a timer-free rule, clearing the endpoint's transports before removing the SEP,
  which removes the removed-but-registered state but destroys another client's acquired transport
  when the endpoint goes, reversing `1636fb014` (2011). Neither has run.
- **Settling runs listed** (CO-37 harness): client exit after adapter removal; leak detection on
  (`asan-tree.sh` builds with `--disable-lsan`, so no run so far could show a leak); stream-idle
  while held; the duplicate Release count.

## 2026-11-01 (night) — the settling runs
QEMU guests, 16:46:53 to 18:49:05; work area (local, raw logs, compressed cores, SHA256SUMS)
`/root/exp/agent-work/u25-settle-20261101/`. Trees: master `14bd6ab65`, `stk-fix12` (CO-37's
two fixes), `prop4` (the timer proposal), L1 (prop4 with amendments), L2 (stk-fix12 with the
transports cleared before the SEP is removed). Nothing sent.
- **A new bug on master (U26):** endpoint removed while another client holds its transport,
  adapter removed, then the endpoint's client leaves the bus: heap-use-after-free in
  `a2dp_remove_sep` (`a2dp.c:3042` on master) reading the A2DP server freed by the adapter
  removal. 10/10 test calls on master, stk-fix12 and prop4; 0/10 on L1 and L2 (checked: 10
  matches per debug log on master, `runs/q1-stk-base/`).
- **The timer proposal is rejected:** besides U26 it never unregisters the SEP in the bus-loss
  and adapter cases (0/120 in the rate runs) and leaks the endpoint and SEP (LeakSanitizer).
- **L1 (amended timer) has a use-after-free of its own:** `sep_removed` (`a2dp.c:657`) reads the
  freed server when the adapter is removed before the connection is lost (2 of 20 and 1 of 220
  test calls, exactly the runs with that order).
- **L2 (clear before remove) is clean in every measurement:** no ASan report, no leak, no "still
  locked" state (the warning is compiled in and appears in no log), the SEP unregistered in every
  case; the two CO-37 tests pass 10/10; 200/200 adjacent test calls pass once the "transport
  stays after removal" assertion is relaxed. Its cost is by design: another client's acquired
  transport is destroyed when the endpoint goes, reversing `1636fb014` (2011). That is a design
  question for the maintainers.
- **Duplicate Release, and our series widens it:** on adapter removal with no transport, master
  sends `MediaEndpoint1.Release` twice to a RegisterEndpoint endpoint and once to an application
  endpoint (3/3 each); with CO-37's two fixes both kinds get it twice (3/3). The reordered
  `path_free` in our fix is the inferred cause. To be fixed before CO-37 is sent.
- **Leaks:** with leak checking actually on, stk-fix12 and prop4 leak the endpoint, the SEP and
  the AVDTP SEP behind a 16-byte list node (`media_endpoint_create`, `media.c:1759`) in the
  client-exit-after-adapter-removal case (6/6); L2 leaks nothing.
- **Correction:** "no run so far could show a leak" was right, but not because of the build flag:
  the `--enable-lsan` and `--disable-lsan` binaries have identical code; the test harness sets
  `leak_check_at_exit=0` in the guest. The leak variant turns it on for bluetoothd only.
- **Stream-idle leak confirmed** (5 runs each): after the peer disconnects while another client
  holds the transport, master, stk-fix12 and prop4 never unregister the SEP; L1 and L2 do.

## 2026-11-02 — the duplicate Release: cause, a separate fix, the six-mail series (nothing sent)
Work area (local, raw logs, cores, SHA256SUMS, 5008 files): `/root/exp/agent-work/co37-release-20261102/`.
- **Cause (from source, master `14bd6ab65`):** `release_endpoint()` (`media.c:651-675`) is the only
  sender of `MediaEndpoint1.Release`. It sends Release, then `media_endpoint_remove()` ->
  `a2dp_remove_sep()` -> `a2dp_unregister_sep()` -> the SEP's destroy callback
  `a2dp_destroy_endpoint()` (`media.c:801-806`) -> `release_endpoint()` again, with the watch still
  set: a second Release. On master `path_free()` reaches this double path only for RegisterEndpoint
  endpoints (applications are freed first); our fix 2's reorder sends application endpoints down it
  too. The path is from `bd3ca4fdf463` (2011; inferred from that commit's source, not run). 5.72 has
  the same structure.
- **Fix:** a `released` flag in `struct media_endpoint`; `release_endpoint()` skips the clear and the
  Release once it is set (8 insertions, 2 deletions). Not "drop the watch after Release": that would
  stop U26's client-exit path from reaching the endpoint (inferred, not run). Placed as a separate
  patch before fix 2, `Fixes: bd3ca4fdf463`; fixes 1 and 2 keep their patch-ids. A folded variant
  (fix 2 with the flag) gives an identical end state.
- **Measured** (ASan+UBSan, QEMU; Releases per endpoint on adapter removal / SIGTERM): master
  RegisterEndpoint 2/2, application 1/1; master + the five earlier mails 2/2 and 2/2; final six-mail
  series 1/1 and 1/1; the same pattern on 5.72, 5.72 + backport, and 5.72 + backport + the flag
  (1/1). Final series: CO-37 tests 0/10 failing, the new Release-count test 0/10, CO-23's test 0/5;
  U25 and U26 unchanged (3/3 each, same signatures). `make check` unchanged. Leak check on: final
  series 8/8 cases clean.
- **The bot's CI, run locally on the six final mails:** every check passes on both sides;
  TestFunctional 48 on base, 53 with the series (the five new tests).
- **Final mails** (`work/patches/master-final-6-20261102/`, no Signed-off-by, author address a
  placeholder): CO-23 fix, CO-23 test, fix 1, the Release fix, fix 2, the test (now also counting
  Releases: `test_a2dp_release_on_exit[app|endpoint]`). 5.72 backport: `work/patches/5.72-3-20261102/`
  (applies to `5.72-0ubuntu5.8`).
- **Independence:** fixes 1 and 2 apply on master without CO-23; the stacked test does not (it
  needs CO-23's newer test file), the original unstacked test does: CO-37 tests 0/10 failing
  without CO-23, also with the Release fix.
- **Message points still to fix:** the test message's "without the first patch ... the second" is
  wrong with the Release fix inserted (replacement drafted); fix 2's ASan trace skips frame #6; the
  5.72 backport 0001 cites fix 1's old title. CO-23's `patch/send/` package is stale (the stacked
  test applies only on `send-20261101-draft/0002`).
- **New, 5.72 only, not fixed (to register):** an endpoint removed while another client holds its
  transport, then the stream goes idle (peer disconnect, or the power-off on SIGTERM):
  heap-use-after-free in `clear_endpoint` (`media.c:300`, the signature of CO-03's original report),
  2/2 and 3/3 runs on 5.72, 5.72 + backport, and with the flag; master leaks there instead of
  crashing. The 5.72 backport does not cover this path.
- **BlueZ and Signed-off-by:** `doc/maintainer-guidelines.rst:59-61` says bluez.git commits "shall not
  contain Signed-off-by".
