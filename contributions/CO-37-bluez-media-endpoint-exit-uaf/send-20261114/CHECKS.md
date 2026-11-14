# CO-37 checks (2026-11-14)

Master used: `20ffd285b58facfd1f2478d159a5f941b09d5be1` (2026-11-12; contains 5.88, so U24's `7e3212fa233e` is in it).
Series base before: `14bd6ab65` (the six mails of 2026-11-02, `contributions/CO-37-.../work/patches/master-final-6-20261102/`, read only).
Work: `/root/exp/agent-work/lane4-bluez-20261114/co37/` (clone `bluez/`, branches `co37` = six patches, `co37-indep` = series B below).
Clock: harness times are host-local (UTC+1). Kernel for the guests: bluetooth-next `da3cc0258` + `doc/tester.config` (the 11-02 run used `47d4d9f67e92`). Image `bluez-action-ci:c7d077f185cd`; ASan+UBSan build (`bootstrap-configure --disable-lsan --enable-asan --enable-ubsan`, as the bot's TestFunctional). -j4.

## 1. Upstream since 2026-11-02 (and since the series base 14bd6ab65)

- **Exit paths unchanged (measured):** `git diff 14bd6ab65 20ffd285b58f -- profiles/audio/media.c` is empty. `a2dp.c` gained `confirm_cb()` handling of a previous link's channel (`efabf8db4c`) and `avdtp.c` `avdtp_check_disconnected()`; `transport.c` gained BAP link handling (`37371e8532`, `f72ff35595`). None touches `a2dp_reconfig()`, `a2dp_remove_sep()`, `release_endpoint()`, `path_free()` or A2DP transport suspend (diffs read).
- **No equivalent posted (patchwork, subjects):** `fetched/patchwork-recent-since-2026-10-25-filtered.txt`. Nothing for the reconfigure-during-Close use-after-free, the deferred-removal read, the duplicate Release or the exit ordering.
- **Pending, near our code:** Jinwang Li, "[v3] avdtp: Fix use-after-free in connection_lost", patchwork 14943182, state `new` (touches `avdtp.c connection_lost()` only, `fetched/pw-14943182.json`). Luiz Augusto von Dentz's transport owner hand-over series (14973707 and following, state `new`, `transport.c`) is pending and could touch the transport release path that U23's chain runs through (inferred, not read in full).
- **Bastien Nocera's RFC 14568134** (2026-05-12): still `new` (`fetched/pw-14568134.json`).
- **New: a field report with the 1b signature.** bluez issue #2616, "bluetoothd segfaults in media_endpoint_remove/queue_remove during A2DP transport suspend" (opened 2026-10-01, Fedora 44, bluez `5.87+1.git8750129efca8`, i.e. after `7482aceece70`), backtrace `queue_remove <- media_endpoint_remove <- a2dp_unregister_sep <- transport_a2dp_suspend <- service_filter` (quoted from the issue, `fetched/gh-issue-2616.json`); 8/8 and 6+ times, bluez-alsa as the client. **Closed 2026-11-10 by the stale bot, with no fix and no maintainer comment** (4 comments, 3 by the reporter; `fetched/gh-issue-2616-comments.json`). Same top frames as our `media.c:321` chain (inferred: no ASan, no line numbers in the report). Also checked: #2605 (A2DP discovery finalization, `discover_cb`, `a2dp.c:501`, open) is a different path.
- **Fix 7e3212fa233e (U24):** in master and in the 5.88 tag (`git tag --contains`: 5.88). It was never part of the master series.

## 2. Rebase

`git am --3way` of the six mails onto 20ffd285b: mails 1, 3, 4, 5 apply unchanged (their `+/-` lines identical to the 11-02 files, `diff` against them shows only the header and index lines); mail 2 and mail 6 conflicted in `test/functional/test_a2dp.py` and `doc/functional-a2dp.rst` with `2ee9c3a504` (Luiz, 2026-10-30, "test: Cover A2DP reconnection with a pending disconnection": new `vm_signal_bluetoothd()` helper, `import subprocess`, new doc section). Resolved by keeping both (adjacent additions and imports). Mail 2's context lines moved; nothing else changed. Author lines now `Iaroslav Voitovych <yaroslav.voytovych@gmail.com>` (the 11-02 mails had a placeholder), subject prefix is the default (`[PATCH n/6]`; set `format.subjectprefix "PATCH BlueZ"` when sending).
The 11-02 files with the placeholder author stay in the work area (`patches-placeholder-author/`).

Subjects (columns; `scripts/subj-stats.py`): 62 `a2dp: Fix use-after-free when switching endpoints during Close`; 55 `test: Cover A2DP endpoint switch while Close is pending`; 64 `media: Fix use-after-free of app removing a locked A2DP endpoint`; 50 `media: Fix sending Release twice to A2DP endpoints`; 64 `media: Fix use-after-free releasing endpoints on adapter removal`; 60 `test: Cover A2DP endpoint release with an acquired transport`.

## 3. Reproducers and tests, master vs the series (measured)

Runs of `test/functional/test_a2dp.py -k ...` in QEMU guests (`scripts/tree.sh`, `scripts/lane.sh`); raw logs under `runs/<tree>/` (build trees included) (`*.results`, per-run `.log` and `.debug.log`), summary `logs/results-summary.txt`. Trees: **master** = 20ffd285b; **series** = master + the six patches; **seriesB** = master + mails 3, 4, 5 + a standalone test (below).

| question | master | series |
|---|---|---|
| the two exit tests (app leaves the bus with an acquired transport; bluetoothd loses the bus), 10 runs | **10/10 fail**, ASan top frame `media_endpoint_remove media.c:321` in every run (6 reports per run) | **0/10**, no ASan report |
| the same, tests from the series' own test file on master binaries | 10/10 fail, `media.c:321` (`runs/masterS/`) | |
| Release count on SIGTERM (`test_a2dp_release_on_exit[app|endpoint]`), 10 runs | **10/10 fail**: `[endpoint]` `assert 2 == 1`; `[app]` passes | **0/10** |
| CO-23's `test_a2dp_reconfigure_during_close`, 5 runs | **5/5 fail**, `a2dp_reconfig a2dp.c:2173` | **0/5** |
| whole `test_a2dp.py`, 2 runs | 2/2 fail (the three new tests error and fail with the ASan reports, plus `[endpoint]`); upstream's own 5 tests and `release_on_exit[app]` pass | 2/2: all 10 tests pass |
| `make check` | 41 pass, 1 skip, 0 fail | 41 pass, 1 skip, 0 fail |
| build warnings (`-Werror` build) | 0 | 0 |

The dossier's counts on 14bd6ab65 (10/10 to 0/10, `make check` 41 + 1 skip) hold on 20ffd285b. The two exit tests were run 10 times on each side as before.

**Series B (CO-37 without CO-23; the answer to D13):** master + mails 3, 4, 5 apply cleanly (`git am --3way`, no conflict). Mail 6 does not apply without mail 2 (textual conflict in the same two files), so a standalone version of mail 6 was made: mail 6 minus the host plugin `PausedBluetoothd`, `import logging` and the `test_a2dp_reconfigure_during_close` doc/test of mail 2 (`patches-series-B-standalone/`, four patches; the test code is otherwise byte-identical to mail 6). Results on the series B binaries: the exit tests **0/10** failing (`runs/seriesB/`); the same tests on master binaries **10/10 fail** at `media.c:321`; `make check` 41 + 1 skip, 0 warnings. The bot was not run on series B.

## 4. The bot's checks, locally (scripts/bot-ci.sh; both sides)

`scripts/bot-ci-local.sh --space user --base 20ffd285b... --tree co37/bluez --kernel-image bzImage-btnext-da3cc0258 <six mails>`, image `bluez-action-ci:c7d077f185cd`, ELL `002b32d7c091`. Exit 0. Logs: `logs/bot-co37/` (`summary.txt`, `patched/`, `base/`).

| check | patched (master + six) | base (master) |
|---|---|---|
| CheckPatch | PASS (0 errors, 0 warnings on all six) | not run on base |
| GitLint | PASS (all six) | not run |
| BuildEll, BluezMake, MakeCheck, MakeDistcheck, CheckValgrind, CheckSmatch, bluezmakeextell | PASS | PASS |
| TestFunctional | PASS, `58 passed, 1 skipped, 11 deselected` | PASS, `53 passed, 1 skipped, 11 deselected` |
| IncrementalBuild | PASS | not run |
| ScanBuild | PASS | PASS (the bot's base ScanBuild compares the patched tree with itself) |

53 to 58: the five new tests (reconfigure-during-close, app exit, bus-loss exit, Release count app and endpoint). The 11-02 run was 48 to 53; the base grew by five tests upstream since. No CheckValgrind flake this time (it flaked on CO-39's base side).
The bot was not run on series B (`patches-series-B-standalone/`).

Load note: the bot, builds and guests ran before the low-priority rule of 11-14 (nice 10, ionice 2/7); the bot's tree was lowered while running. Nothing was started after the rule.

## 5. Not done
- The 5.72 backport (`5.72-3-20261102/`) was not re-tested (task is master); U27 is not covered by anything and was not rerun.
- U25 and U26 (the adjacent states) were not rerun; `media.c` is unchanged, so nothing changed by source, but there is no run from today.
- The reviewers' F-51 fixture changes (plugin `job` instead of the `/proc` scan, precise bus-daemon kill) were not made; both jobs are exposed by pytest-bluezenv (`host_plugins.py`: `_Dbus.job` line 207, `Bluetoothd.job` line 299), so it can be done (inferred).
