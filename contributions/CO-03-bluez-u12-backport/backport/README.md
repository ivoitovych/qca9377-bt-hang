# CO-03: Ubuntu 24.04 BlueZ 5.72, Release() during a pending A2DP Acquire()

Backport of upstream BlueZ `a14d59725` ("transport: don't disconnect A2DP
if canceling Acquire() with Release()", first in 5.80) to Ubuntu 24.04's
`bluez 5.72-0ubuntu5.8`, with the two BT-7 crash fixes, built as an Ubuntu
package and tested in containers and QEMU/KVM guests with emulated
controllers. Nothing was installed on the laptop, sent or filed.

The test plan, with the per-test results of both builds side by side, is
[`TEST-PLAN.md`](TEST-PLAN.md).

**Where things are.** The work was done in `/root/exp/agent-work/co03/`,
and its scripts use that path. This folder is the record:
- the documents, scripts, tests, patches and build logs;
- the test fixture as a patch (`test-fixture-patch/`);
- each run's `results.jsonl` and the summary logs in `runs/`;
- the sanitizer reports of section 3, cut from the full logs
  (`runs/asan-exit-reports.txt`).

The full `runs/*/pytest.log` and `runs/*.stdout.log` files (15 MB each at
most), the build trees, the packages and the core files stay in the work
area (section 8). A `runs/…/pytest.log` named below is in the work area.

## 1. What was backported, and why each piece

Base: `bluez_5.72-0ubuntu5.8` (noble-security and noble-updates, the
newest noble version on 2026-10-31):

```console
$ /root/exp/agent-work/co03/scripts/noble-versions.py bluez
noble 5.72-0ubuntu5.8 Updates 2026-10-21T06:52:19.803814+00:00
noble 5.72-0ubuntu5.8 Security 2026-10-13T19:55:24.540698+00:00
noble 5.72-0ubuntu5 Release 2024-04-07T11:27:12.669730+00:00
```

Branch `co03/u12-backport` of `src/bluez` (on `noble-5.72-0ubuntu5.8`, the
unpacked source package with Ubuntu's patches applied), one commit per
upstream change, original author and date, each ending with
"(backported from commit …)":

| # | Commit (upstream) | Author | What it does here | Taken because |
|---|---|---|---|---|
| 1 | `a734b06059cb` adapter: Fix crash on short start discovery reply | Iaroslav Voitovych | `src/adapter.c`, +6 | BT-7 (laptop's build carries it); applies with offset −40 |
| 2 | `0bed9886cff3` a2dp: Fix crash on NULL stream in transport_cb | Iaroslav Voitovych | `profiles/audio/a2dp.c`, +5 | BT-7; applies with offset −218. (Upstream applied the same check twice, `d84171e6cd68`, and removed the copy in `b79d4a887`; only one copy is taken.) |
| 3 | `3d9900eb754d`, helper part only: `transport_a2dp_get_stream()` | Arkadiusz Bokowy | `transport.c`: the helper, used in `a2dp_resume_complete()` | `a14d59725`'s second hunk has it as context and calls it; without it that hunk does not apply. The rest of `3d9900eb754d` (delay-reporting existence of the `Delay` property, `avdtp_stream_has_delay_reporting()`, the `get_stream` op for A2DP) changes D-Bus behaviour and is left out. |
| 4 | `a14d59725ef3` transport: don't disconnect A2DP if canceling Acquire() with Release() | Pauli Virtanen | `transport.c`: `resume_id`/`cancel_resume`/`cancel_id`, `transport_a2dp_remove_owner()`, the deferred SUSPEND, the `ECANCELED` reply | the fix. Hunks 1–5 apply (offsets −8 to −48); the `A2DP_OPS` hunk wired by hand: 5.72's macro has no `_set_delay` argument and no A2DP `get_stream`, so only `transport_a2dp_remove_owner` goes in as the `remove_owner` op. |
| 5 | `664a5d3785a1` a2dp: don't change setup sep when it is reconfiguring | Pauli Virtanen | `a2dp.c`: `a2dp_resume()`/`a2dp_suspend()` fail early if `setup->reconfigure` | posted with #4 (1 s apart, same series); #4 adds a new caller of `a2dp_suspend()`: `a2dp_cancel_resume_cb()` runs after START completes, and the comment there says it can run while a `SetConfiguration()` is reconfiguring. Without #5 that call would set `setup->sep`/`setup->stream` to the old SEP in the middle of the reconfiguration. |

Companions audited and **not** taken:

- `aa118e965b02` a2dp: Don't wait to reconfigure (Luiz von Dentz, 4 days
  after #4/#5, not in their series): replaces the 500 ms
  `RECONFIGURE_TIMEOUT` with an idle callback. A behaviour change for
  reconfiguration timing; nothing in #4 depends on it.
- `47da1efdc584` transport: Unset transport owner before owner free: makes
  `media_owner_free()` clear `transport->owner`. In 5.72 every A2DP path
  that frees an owner either never set it as the transport's owner
  (`acquire()`/`try_acquire()` failure paths, `transport.c` L651–653 and
  L684–686 of V0) or cleared it first (`media_transport_remove_owner()`,
  L343); #4 adds no other `media_owner_free()` caller. The commit is for
  BAP broadcast, where `acquire()` sets the owner before resuming.
- `87ad4c66b934` transport: fix crash when freeing transport: fixes a
  use-after-free of `remote_endpoint` introduced by `c26389c46` (ASHA,
  after 5.72: `git log -S"g_free(transport->remote_endpoint)"` finds only
  that commit). 5.72 never frees `remote_endpoint`; the bug does not exist
  there.

Function-by-function comparison of the result with upstream `a14d59725`
(`scripts/func-diff.py`): every function the fix adds or changes
(`a2dp_suspend_complete`, `transport_a2dp_suspend`, `a2dp_cancel_resume_cb`,
`a2dp_resume_complete`, `transport_a2dp_resume`, `transport_a2dp_cancel`,
`transport_a2dp_remove_owner`, `media_owner_remove`,
`media_transport_remove_owner`, `acquire`) is identical; `release()`
differs only by a debug line upstream has; `media_owner_free()` by
`47da1efdc584` (above).

Outputs:
- git branch `co03/u12-backport` in `src/bluez` (also `co03/bt7-only`,
  the first two commits; `co03/test-fixture-sink`, the test-only remote,
  never part of the backport)
- `format-patch/0001…0005-*.patch` (`git format-patch`)
- `debian-patches/co03-01…05-*.patch` (DEP-3: Description, Author, Origin,
  Applied-Upstream, Last-Update; no Bug-Upstream: none known; Bug-Ubuntu
  to be added once a bug exists)
- packaging tree `pkg/backport/bluez-5.72-0ubuntu5.8` (series entries,
  changelog `5.72-0ubuntu5.9~co03.1 UNRELEASED`) and its `.deb`s in
  `pkg/backport/`

## 2. Results (details and every test: `TEST-PLAN.md`)

V0 = `5.72-0ubuntu5.8` unmodified; V2 = V0 + the five commits above. The
whole plan ran on V0 first; the same unchanged test files then ran on V2.

| Layer | V0 | V2 | Changed outcomes |
|---|---|---|---|
| L0 package build, warnings, `make check` | builds; 2 compiler warnings; 30/32 unit tests (test-vcp, test-mesh-crypto fail) | identical | none |
| L0 ASan/UBSan `make check` | 25/25 | 25/25 | none |
| L1 harness (`transport.c` with stubs, 35 tests) | 27 pass, 8 fail | 35 pass | the 8 leak tests only |
| L2 VMs (31 tests, once) | 17 pass, 14 fail (T251 failed by a test bug, corrected and re-run: pass) | 31 pass | the 13 leak tests only |
| L2 trigger rates (T201–T207, 10 each) | 0/70 pass | 70/70 pass | all leak |
| L3 PipeWire's own VM tests (7) | 4 pass, 3 BAP fail | the same 4 pass, the same 3 fail | none |
| L3 ours (T310 ×11, T311, T312) | T310 0/11, T311 pass, T312 fail | T310 11/11, T311 pass, T312 pass | T310, T312 (leak) |

The trigger, ten runs each per build (`runs/v*-l2rates/results.jsonl`):

| test | build | remote | runs | Acquire reply | Release reply | ABORT sent | A2DP lost (ms after Acquire) | later Acquire + media | sanitizer |
|---|---|---|---|---|---|---|---|---|---|
| T201 Release same turn | V0 | silent | 10 | none ×10 | ok ×10 | 1 ×10 | 10/10 (1790–2736) | 0/10 | 0 |
| T202 Release +87 ms | V0 | silent | 10 | none ×10 | ok ×10 | 1 ×10 | 10/10 (1866–2826) | 0/10 | 0 |
| T203 same turn | V0 | slow | 10 | none ×10 | ok ×10 | 1 ×10 | 10/10 (4.9–6.5) | 0/10 | 0 |
| T204 +87 ms | V0 | slow | 10 | none ×10 | ok ×10 | 1 ×10 | 10/10 (92–97) | 0/10 | 0 |
| T205 same turn | V0 | plain | 10 | none ×10 | ok ×10 | 1 ×10 | 10/10 (5.3–6.1) | 0/10 | 0 |
| T206 same turn | V0 | silent0 | 10 | none ×10 | ok ×10 | 1 ×10 | 10/10 (1846–2562) | 0/10 | 0 |
| T207 sink role | V0 | silent | 10 | none ×10 | ok ×10 | 1 ×10 | 10/10 (1840–2634) | 0/10 | 0 |
| T201–T207 | V2 | as above | 70 | `org.bluez.Error.Failed` ×70 | ok ×70 | 0 ×70 | 0/70 | 70/70 | 0 |

Remotes (host1, a test fixture): silent = START answered after 200 ms,
ABORT never (the MOMENTUM 4 of EX-063/EX-084); slow = START after 200 ms,
ABORT answered; plain = stock; silent0 = START at once, ABORT never.

What this shows:
- V0 reproduces U12 every time: ABORT, the Acquire never answered, then
  with a silent remote `Abort: Connection timed out` and A2DP disconnected
  ~2 s later, the same chain as EX-085. **With a remote that answers
  ABORT, V0 loses A2DP too, within 5–7 ms** (`abort_cfm`, stream IDLE,
  `a2dp-sink state changed: connected -> disconnected`, AVRCP dropped by
  the policy). U12 is not limited to headsets that ignore ABORT.
- V2: no ABORT, the Acquire answered `Failed` ("Operation canceled"),
  START waited out, SUSPEND, Release answered; A2DP kept; a new Acquire
  works and media reaches the remote, 70 of 70.
- With PipeWire and WirePlumber master (L3): a profile switch to
  hands-free while START is pending (T310) loses A2DP 11/11 on V0, 0/11 on
  V2; WirePlumber's own autoswitch on a capture stream (T312) the same.

Failure paths that do not change (recorded, both builds alike):
- The owner process **exiting** while its Acquire is pending (T248) or
  while its Release waits (T249) still sends ABORT and loses A2DP with a
  silent remote, on V2 as on V0: `transport_a2dp_remove_owner()` calls
  `a2dp_cancel(a2dp->resume_id)` (V2 `profiles/audio/transport.c:586`),
  as upstream does. Only `Release()` is fixed, not a client crash.
- A remote that never answers START (T242–T244): AVDTP's own 6 s request
  timeout aborts; A2DP lost on both builds, later on V2 (it waits START
  out).
- Owner exit while Release waits for SUSPEND (T250): ABORT of the SUSPEND,
  lost after ~81 ms, both builds.

## 3. Findings outside the backport

- **5.72 drops the cancelled `Acquire()` without any D-Bus reply**
  (V0 `profiles/audio/transport.c:749–751`: `media_owner_remove()` frees
  the request unanswered); the caller waits for its own D-Bus timeout.
  Every V0 run of the trigger shows `Acquire reply: none`. Fixed by #4.
- **ASan at bluetoothd exit, both builds** (Fedora 44 ASan builds of the
  same trees; the Ubuntu ASan builds reported nothing in any run):
  - `heap-use-after-free profiles/audio/media.c:300 in clear_endpoint`,
    exit path `a2dp_exit` → `unload_driver` → `path_free`
    (`media.c:3276`) → `release_endpoint` (`media.c:566`); freed in
    `a2dp_unregister_sep` (`a2dp.c:2618` on V0, `:2623` on V2, the BT-7
    lines). Ten runs of T311 on V0 (`runs/exitcheck-base-t311x10/pytest.log`):
    3 reports from host0 (V0) and 1 from host1 (the fixture build, V0 plus
    the fixture). V2: 2 of 10 runs of T310, host0
    (`runs/v2-l3rates/pytest.log`); 0 in 10 runs of T311
    (`runs/exitcheck-backport-t311x10/pytest.log`); summary
    `runs/exitcheck.log`.
  - `heap-use-after-free src/device.c:6167 in device_set_rssi_with_delta`,
    exit path `adapter_cleanup` → `discovery_cleanup` (`adapter.c:1721`) →
    `invalidate_rssi_and_tx_power` (`adapter.c:1706`). V0:
    `runs/l3-smoke2/pytest.log`; V2: `runs/v2-l3pw-test_pipewire_a2dp/pytest.log`.
  Both appear only at test teardown, after the in-test checks; neither file
  path is touched by the backport. Not investigated further.
- **bluetoothctl 5.72 built with ASan aborts at exit**:
  heap-use-after-free via `client/player.c:561` (`print_media` →
  `bt_shell_printf` from `player_remove_submenu`)
  (`logs/finding-bluetoothctl-5.72-exit-uaf.txt`). The L2 guests therefore
  use a plain build of the tools (`build/tools`); the L3 guests use the
  ASan tools and leave core files of it in `pw/`.
- **Reused guests and 5.72:** after one test, the next `Pair()` fails with
  `AlreadyExists` ("Already Paired (0x13)" from the kernel); the tests drop
  the stale link key with `btmgmt unpair` first. PipeWire's own tests are
  run one session each for that reason. Not investigated.
- `unit/test-avdtp` tests `android/avdtp.c`, not `profiles/audio/`; no
  BlueZ 5.72 unit test compiles `transport.c`, `a2dp.c` or `avdtp.c`
  (`Makefile.am` L572–574), hence the L1 harness.

## 4. Limits

- Emulated controllers (btvirt) and a fixture remote; the real MOMENTUM 4
  is modelled by its timing (START after ~200 ms, ABORT never answered),
  not tested.
- L3 uses PipeWire and WirePlumber master in Fedora 44 guests, not the
  laptop's PipeWire 1.0.5 / WirePlumber 0.4.17; T310's window is widened
  to 1 s because PipeWire under ASan is slower in the guest.
- The Ubuntu `.deb` was built and its `make check` run; the `.deb` itself
  was not installed anywhere. The VM tests ran the same source built with
  ASan/UBSan, not the packaged binary.
- `664a5d3785a1`'s reconfiguration path (T252) passes on V2, but no build
  of #4 without #5 was run to show the wrong-SEP case it prevents.
- BT-7 (#1, #2) is in V2 but not exercised by any test here (their crash
  paths need a controller that stops answering); V1 (BT-7 only) was not
  run because V0 → V2 changed nothing outside the leak set.

## 5. What remains for real hardware (the operator's decision)

1. Install `pkg/backport/bluez_5.72-0ubuntu5.9~co03.1_amd64.deb` (and the
   matching `libbluetooth3`, `bluetooth` if wanted) in place of the
   project's own bluetoothd, or build that tree's `src/bluetoothd`.
2. Repeat the trigger with the MOMENTUM 4: an application opening the
   microphone as A2DP playback starts (T320), and keep the HCI capture:
   expected START, then SUSPEND, no ABORT (T321), A2DP still offered.
3. Decide the Launchpad filing (draft below).

## 6. Rebuild everything

All commands from the host, one per line; each script runs its work in a
container (`co03-noble-build:1`, `co03-noble-vm:1`, `co36-pw-ci:f44`).

```console
$ docker build -t co03-noble-build:1 /root/exp/agent-work/co03/docker/noble-build
$ docker build -t co03-noble-vm:1 /root/exp/agent-work/co03/docker/noble-vm
$ /root/exp/agent-work/co03/scripts/fetch-source.sh 5.72-0ubuntu5.8
$ /root/exp/agent-work/co03/scripts/make-tree.sh
$ /root/exp/agent-work/co03/scripts/export-upstream.sh
  (then the commits as in section 1: backport-step.sh, backport-commit.sh,
   commit-with-msg.sh; the hand edits are described in the commit notes)
$ python3 -I /root/exp/agent-work/co03/scripts/make-debian-patches.py /root/exp/agent-work/co03/src/bluez noble-5.72-0ubuntu5.8 co03/u12-backport /root/exp/agent-work/co03/debian-patches
$ /root/exp/agent-work/co03/scripts/make-pkg-trees.sh
$ /root/exp/agent-work/co03/scripts/build-pkgs.sh
$ /root/exp/agent-work/co03/scripts/check-am.sh
$ /root/exp/agent-work/co03/scripts/build-asan-all.sh
$ /root/exp/agent-work/co03/scripts/build-asan.sh sink nocheck
$ /root/exp/agent-work/co03/scripts/build-f44.sh base backport sink
$ /root/exp/agent-work/co03/scripts/build-tools.sh
$ /root/exp/agent-work/co03/scripts/plan-l2.sh base v0
$ /root/exp/agent-work/co03/scripts/plan-l3.sh base v0
$ /root/exp/agent-work/co03/scripts/plan-l2.sh backport v2
$ /root/exp/agent-work/co03/scripts/plan-l3.sh backport v2
$ /root/exp/agent-work/co03/scripts/exit-uaf-check.sh
$ python3 -I /root/exp/agent-work/co03/scripts/summarize.py /root/exp/agent-work/co03/runs/v0-l2rates/results.jsonl /root/exp/agent-work/co03/runs/v2-l2rates/results.jsonl
```

The worktrees `build/{base,backport,sink,tools}` and
`build-f44/{base,backport,sink,tools}` come from
`git -C src/bluez worktree add --detach <dir> <branch>` (base
`noble-5.72-0ubuntu5.8`, backport `co03/u12-backport`, sink
`co03/test-fixture-sink`, tools `noble-5.72-0ubuntu5.8`). `pw/` is a copy
of the CO-36 PipeWire tree with its build `build-v0-asan`.

## 7. Draft Launchpad bug (for the operator to edit)

**Title:** bluez: Release() during a pending A2DP Acquire() aborts the
stream and disconnects A2DP

**Package:** bluez 5.72-0ubuntu5.8 (Ubuntu 24.04)

When an application opens the microphone of a Bluetooth headset just as
A2DP playback starts, WirePlumber switches the headset to its hands-free
profile and releases the A2DP transport while bluetoothd's Acquire (AVDTP
START) is still pending. BlueZ 5.72 turns that Release() into an AVDTP
ABORT. A headset that answers ABORT loses its A2DP profile connection
immediately; a headset that does not answer it (seen with a Sennheiser
MOMENTUM 4) loses the whole AVDTP session after the 2 s abort timeout.
Nothing reconnects A2DP; only the hands-free profile remains until the
headset is reconnected. The pending Acquire() is also never answered.

bluetoothd log of an occurrence:

    media_owner_add() Owner :1.81 Request Acquire
    media_owner_remove() Owner :1.81 Request Acquire
    a2dp_cancel() aborting setup
    cancel_request() Start: Operation canceled (125)
    session_cb() Transaction label doesn't match
    cancel_request() Abort: Connection timed out (110)
    connection_lost() Disconnected from <headset>
    profile a2dp-sink state changed: connected -> disconnected (0)

Fixed upstream by commit a14d59725ef3 ("transport: don't disconnect A2DP
if canceling Acquire() with Release()", BlueZ 5.80): the Acquire() is
answered with an error, START is waited out and followed by SUSPEND.

Attached patches (DEP-3), on top of 5.72-0ubuntu5.8:
- the transport_a2dp_get_stream() helper from 3d9900eb754d (context only)
- a14d59725ef3 (the A2DP_OPS hunk adapted to 5.72)
- 664a5d3785a1 ("a2dp: don't change setup sep when it is reconfiguring",
  same upstream series)

Tests (emulated controllers in QEMU, the patched source built with
ASan/UBSan): Release() during a pending Acquire(), against remotes that
answer ABORT and that never do, ten runs each: A2DP lost 70/70 before,
0/70 after; a new Acquire() and audio work 70/70 after. Normal
Acquire()/Release() orderings, refusals, disconnects during a pending
Acquire() and PipeWire's own Bluetooth VM tests give the same results
before and after. The package builds with dpkg-buildpackage and its unit
tests are unchanged.

## 8. Files

To keep (small, written here): `README.md`, `TEST-PLAN.md`, `scripts/`,
`tests/`, `docker/noble-build/Dockerfile`, `docker/noble-vm/Dockerfile`,
`format-patch/`, `debian-patches/`, `upstream-patches/`, `logs/`,
`runs/*/results.jsonl`, `runs/*.log`, `runs/*/pytest.log`,
`runs/*.stdout.log`; the branches `co03/u12-backport`, `co03/bt7-only`,
`co03/test-fixture-sink` and tag `import/5.72-0ubuntu5.8` in `src/bluez`.

Bulk (local only, rebuildable): `src/archive/` (source package, 2.4 MB),
`src/bluez` working tree, `build/` (1.4 GB) and `build-f44/` (954 MB):
eight configured worktrees with objects; `pw/` (9.1 GB: the 648 MB copy of
the CO-36 PipeWire tree plus 132 core files of the L3 guests, 124 of
bluetoothctl's exit abort and 8 of bluetoothd, one per ASan report of
section 3, written 15:44, 16:21, 16:30, 16:34, 16:43, 16:46, 16:47, 16:48
local time); `pkg/` (2.3 GB, two
packaging trees with build products and `.deb`s;
`pkg/backport-superseded-origin-headers/` is the first backport tree,
superseded only because two DEP-3 `Origin:` fields said "backport"
instead of "upstream"; same code), `docker/noble-vm/bzImage` and
`docker/noble-vm/pytest_bluezenv-0.1.9/` (copies), `tmp/am-check/` (the
T004 clone, 32 MB), `runs/*/*.core` (bluetoothctl core files of the
debugging runs `smoke1`, `smoke2`, `base-r1`; `runs/` is 988 MB in all).

Superseded or debugging runs, kept: `runs/smoke1`, `runs/smoke2`,
`runs/base-r1` (pairing bug in the test), `runs/base-r1b` (before the
guest-clock fix), `runs/l3-smoke1` to `l3-smoke3` (before the L3 timing
rework); `logs/*superseded-origin-headers*` (first backport package build).
