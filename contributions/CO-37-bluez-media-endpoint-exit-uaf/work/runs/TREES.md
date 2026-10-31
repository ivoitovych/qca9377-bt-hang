# Run trees

Each `runs/<name>/src` is a clone of `../repo`; `commits.txt` lists what was
built. Where a test file was replaced after the build (Python only, no C
change, so the build stays valid), it is noted here.

| tree | built from | after the build |
|---|---|---|
| base-t0 | master 14bd6ab65 + first test draft | `test/functional/test_a2dp.py` from e4694315f; `test/functional/test_exit_discovery.py` added from 17e1a36cc (23:09); both final at 00:01:42 (below) |
| disc-revert | master 14bd6ab65 + revert of 7e3212fa2 (1dbce15de) + first discovery test draft | `test/functional/test_exit_discovery.py` from 17e1a36cc |
| fix1 | master + 3c8e880f8 (fix 1, final) + e4694315f (test) | — |
| fix12 | master + 3c8e880f8 + 9f40136a4 + e4694315f + 17e1a36cc | both test files final at 00:01:42 (below) |
| v572 | 5.72 + 03b684514 (master's test/functional, pytest.ini, client/scripts) | `make CFLAGS="-g -O2 -Wno-error"` (remake), as 5.72 does not build under -Werror with the image's compiler; master's test tools (below) |
| v572fix | 5.72 + 03b684514 + c72936943, 99e56936b (backport) + 11d09e35b (7e3212fa2 backport) | as v572 |

`repo-ebbb4ee/` (beside `repo/`) is not a run tree: a worktree at
ebbb4ee31ad7, used only for `git apply --check`.

v572 and v572fix: master's `emulator/btvirt`, `client/bluetoothctl`,
`tools/btmgmt`, `tools/test-runner` copied in from base-t0 by
`scripts/use-master-tools.sh` (inside the container), 5.72's kept as
`*.5.72`; listed with hashes in their `commits.txt`.

base-t0 and fix12 got the final test files (1a1d7376a, 7c0926ecf) at
00:01:42 (`scripts/update-tests.sh`, noted in `commits.txt`); the runs
labelled `suite2` and `final-rate` used them, all earlier ones the
versions before (which left the bus socket behind after the kill).

Commit identities: 9f40136a4 and the final 5534b2688 (fix 2) have the
same diff and differ only in the message (`git -C repo diff --stat
9f40136a4 5534b2688` prints nothing). The final test 1a1d7376a differs
from e4694315f only by the socket cleanup in `stop_bluetoothd()` and by
`doc/functional-a2dp.rst`.

`base-t0/probe-1.*` ran the first draft (variants `sigterm`, and `dbus` =
dbus-daemon stopped with SIGTERM); `base-t0/probe2-1.*` the two-test
version; `v572/probe*` the attempts until the harness ran on 5.72
(probe 1 to 4: 5.72's btvirt and test-runner too old; probe 5: pairing
fails on the second test of a session; probe 6: the exit test alone).
