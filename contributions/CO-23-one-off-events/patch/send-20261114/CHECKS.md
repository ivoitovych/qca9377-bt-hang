# CO-23 event 1 (U22): checks on 2026-11-14

`$W` = `/root/exp/agent-work/lane2-sco-20261114`. Raw logs: `$W/co23/asan/<tree>/` (pytest output
`<label>-<n>.log`, all guest output `<label>-<n>.debug.log`), bot output `$W/project/tmp/bot-co23/` (copy
in `bot/`), hashes in `SHA256SUMS`.

## 1. Upstream state (stop condition: not met, the defect is still there)

| Check | Command / source | Result |
|---|---|---|
| master tip | `git fetch https://github.com/bluez/bluez master` | `20ffd285b58f`, 2026-11-12 ("shared/gatt-client: Track pending discovery Database Hash reads") |
| the code | `git grep -n reconfigure FETCH_HEAD -- profiles/audio/a2dp.c`; `a2dp.c` lines 2162-2176 read | `avdtp_close()`/`avdtp_abort()` still run before `setup->reconfigure = TRUE;` (`a2dp.c:2173`), no reference held |
| commits to the A2DP/AVDTP files since the dossier's last check | `git log 82667d713949..FETCH_HEAD -- profiles/audio/a2dp.c avdtp.c avdtp.h` | one: `efabf8db4` 2026-10-30 "a2dp: Fix refusing the AVDTP connection of a new link" (other code) |
| a fix or report on the list | `scripts/patchwork-recent.py 2026-10-29 'a2dp\|avdtp\|reconfig\|use-after\|endpoint'` (23 of 667 patches) | none for `a2dp_reconfig()`. Nearby: "avdtp: Fix use-after-free in connection_lost" (14943182, `new`, `finalize_discovery()` moved in `connection_lost`, `fetched/patch-14943182.diff`) - a different function and file; "shared/timeout: Fix use-after-free when a timeout removes itself" (14927546, accepted) - not ours |
| BlueZ release | not looked up (no 5.88 tag in the clone's fetched range; irrelevant, the code is unchanged on master) | |

## 2. Rebase and tests

Branch `co23` in `$W/bluez` (BlueZ master `20ffd285b58f` + 2 commits): fix `08e3e4330`, test `9184e1e4f`
(mails in `mails/`, `git format-patch --subject-prefix="PATCH BlueZ" --base=20ffd285b58f`).
- Fix: same code as the 11-01 draft (`git diff --no-index` of the two mails shows only the `From` hash,
  the blob ids and `base-commit` changed).
- Test: `git am --3way` conflicted with master's new `test_a2dp_reconnect_pending_disconnect` (10-30)
  in `test_a2dp.py` (imports; the end of the file) and `doc/functional-a2dp.rst`; resolved by keeping
  both (`scripts/resolve-co23.py`). The ASan reproducer is an ordinary functional test, the same one as
  before.

Trees (built in the bot's image, flags `--disable-lsan --enable-asan --enable-ubsan`, same kernel image,
ELL `002b32d7c091` as the earlier runs; `scripts/asan-tree.sh`): `base-test` = master + test only,
`fix-test` = master + fix + test. Two QEMU guests per run.

| Run | base-test (no fix) | fix-test (fix) |
|---|---|---|
| `test_a2dp_reconfigure_during_close`, 10 runs each | **10 of 10 fail**: `1 failed, 1 error`, 3 ASan reports each; `heap-use-after-free`, WRITE of size 4 at `a2dp_reconfig profiles/audio/a2dp.c:2173` called from `set_configuration a2dp.c:2233`, freed in `setup_cb_free a2dp.c:341` (`base-test/co23-1.log`) | **10 of 10 pass**, 0 ASan reports, 25-30 s each |
| all of `test_a2dp.py` (6 cases), 1 run | 5 passed, the new case failed + error (3 ASan reports) | 6 passed, 0 reports |

Build warnings: 0 on both trees (`build.log`).

## 3. The bot's checks (`scripts/bot-ci-local.sh --space user`, `scripts/bot-co23.sh`)

Base BlueZ `20ffd285b58f`, the two mails as in `mails/` (no Signed-off-by), `--kernel-image` the p123
tester kernel of the CO-02 work. Output `project/tmp/bot-co23/`.

| Check | Patched (base + 2 mails) | Base |
|---|---|---|
| CheckPatch, GitLint | PASS, PASS | n/a (patch-level) |
| BuildEll, BluezMake, MakeCheck, MakeDistcheck, CheckValgrind, CheckSmatch, bluezmakeextell, ScanBuild | PASS | PASS |
| IncrementalBuild | PASS | n/a |
| TestFunctional | PASS: 54 passed, 1 skipped, 11 deselected (`patched/TestFunctional.log`) | PASS: 53 passed, 1 skipped, 11 deselected |

Bot summary: patched "0 test(s) not PASS", base "0 test(s) not PASS", `ALL DONE, exit 0`
(`bot/bot-co23/summary.txt`). The one more passed case on the patched side is
`test_a2dp_reconfigure_during_close` (it runs against the patched bluetoothd inside the bot's ASan
build; without patch 1 the same build reports the use-after-free, section 2). The bot's CheckPatch
is non-strict, the BlueZ one the list uses.

## 4. Not run
checkpatch `--strict` (run separately on the copy, see the dossier README); the path where the Abort cannot be sent (no
test can make that send fail); anything on the laptop; a variant of the test using master's
`vm_signal_bluetoothd()` helper (NOTES, decision 2).
