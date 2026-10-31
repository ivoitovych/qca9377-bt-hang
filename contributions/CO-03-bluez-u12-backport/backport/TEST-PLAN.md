# CO-03 test plan: what the backport must change, and what it must keep

Goal: a test suite that describes how Ubuntu 24.04's BlueZ (`5.72-0ubuntu5.8`)
handles the A2DP transport's `Acquire()`/`Release()` today, run on the
unmodified package first, so that the backport (upstream `a14d59725` and its
companions) is judged by the **difference** it makes: the U12 leak gone,
nothing else changed.

Each test has an ID, its layer, what it checks and its class:
**leak** = fails on unmodified 5.72, the backport must make it pass;
**keep** = passes on 5.72, must still pass; **record** = outcome written
down on both builds, compared, no pass/fail of its own beyond the stated
invariant (crash-free, every call answered). The classes were fixed before
the backport was run.

Builds compared: **V0** = `5.72-0ubuntu5.8` unmodified (branch
`noble-5.72-0ubuntu5.8`); **V2** = V0 + the BT-7 crash fixes + the U12
backport (branch `co03/u12-backport`). **V1** = V0 + BT-7 only
(`co03/bt7-only`) is run only if V0 and V2 differ outside the leak set,
to place the difference.

## What the code does today (the model the tests check)

`profiles/audio/transport.c` of 5.72-0ubuntu5.8 (V0 line numbers):

- `Acquire()` (`acquire()`, L625) on an idle transport locks the SEP and
  calls `a2dp_resume()` (`transport_a2dp_resume()`, L416), which sends
  AVDTP START; the D-Bus reply waits for `a2dp_resume_complete()` (L371).
- `Release()` (`release()`, L731) while that `Acquire()` is pending calls
  `media_owner_remove()` (L750), which calls `transport_a2dp_cancel()` →
  `a2dp_cancel()` (L487–490). `a2dp_cancel()` (`a2dp.c`, L3218) removes the
  last callback of the setup and calls `avdtp_abort()`: **AVDTP ABORT**.
  The pending `Acquire()` is dropped **without a D-Bus reply**.
- A remote that answers ABORT takes the stream to IDLE; a remote that does
  not lets `ABORT_TIMEOUT` (2 s, `avdtp.c` L78) expire, and
  `cancel_request()` ends the AVDTP session: `connection_lost()`, A2DP
  disconnected (EX-085: `Abort: Connection timed out (110)`, then
  `a2dp-sink state changed: connected -> disconnected`).
- Upstream `a14d59725` instead answers the `Acquire()` with an error,
  waits for START to complete, sends SUSPEND, then answers `Release()`;
  `transport_a2dp_remove_owner()` cancels what is left when the owner goes.

## Invariants

- **I1** A `Release()` during a pending `Acquire()` does not end the A2DP
  connection (no `a2dp-sink`/`a2dp-source` "connected -> disconnected", the
  transport object stays), whether or not the remote answers ABORT.
- **I2** After it, a new `Acquire()` succeeds and media packets reach the
  remote.
- **I3** The cancelled `Acquire()` gets a D-Bus answer (an error).
- **I4** No AVDTP ABORT is sent for a START cancelled by `Release()`; the
  START is waited out, then SUSPEND; `Release()` answers after that.
- **I5** Normal orderings are unchanged: Acquire→Release, remote start and
  suspend, `TryAcquire()`, the refusals (`NotAuthorized`, `InProgress`,
  `NotAvailable`).
- **I6** Device disconnect, remote disconnect, owner exit and reconfigure
  during any pending operation: every D-Bus call answered, no crash, the
  device usable after reconnecting.
- **I7** Other uses are unchanged: PipeWire's A2DP, HFP and BAP streaming,
  its profile switches, bluetoothd restart.
- **I8** No ASan/UBSan report; no new compiler warning.
- **I9** The package builds from the source package with the patches as
  `debian/patches` entries (DEP-3 headers); BlueZ's own unit tests unchanged.

## Layers

| Layer | What it runs | Time control | Where |
|---|---|---|---|
| L0 build and existing suites | `dpkg-buildpackage -b`, warnings, `make check` (package configuration and ASan/UBSan) | — | `ubuntu:24.04` container (`co03-noble-build:1`) |
| L1 unit | BlueZ's own unit tests; our harness: `transport.c` included into a test program, A2DP/AVDTP/gdbus stubbed, each START/SUSPEND completed by hand | **virtual**: any order | same container, ASan/UBSan |
| L2 integration | two QEMU/KVM guests (pytest-bluezenv 0.1.9, btvirt), host0 = bluetoothd under test with a D-Bus media client, host1 = the remote with a test fixture | real clock, from logs | `co03-noble-vm:1` (Ubuntu 24.04 userspace in the guests) |
| L3 application | PipeWire master and WirePlumber driving the transport as on the desktop | real clock | PipeWire's CI image `co36-pw-ci:f44` (Fedora 44 userspace), the same BlueZ trees built there |

The host1 fixture (branch `co03/test-fixture-sink`, never part of the
backport) makes the remote answer START late, never answer ABORT or START,
reject START or answer SUSPEND late, chosen per test by environment
variables (`co03_fixture_cmd()` in its `profiles/audio/avdtp.c`). Modes:
`silent` = START after 200 ms, ABORT never answered (the MOMENTUM 4 of
EX-063/EX-084: START accepted after 195/257 ms, ABORT unanswered);
`slow` = START after 200 ms, ABORT answered; `plain` = stock;
`silent0` = START at once, ABORT never answered; `slowsusp` = SUSPEND
after 300 ms; `reject` = START rejected; `nostart` = START never
answered; `nostart_silent` = neither START nor ABORT answered;
`slow1000` = START after 1 s, ABORT never answered; `slow300` = START
after 300 ms.

Why a D-Bus client and not PipeWire for L2: the client places `Release()`
at a chosen time after `Acquire()` (same main-loop turn, 87 ms), so every
run takes the same path; PipeWire's own timing decides that in L3.

## L0: builds and existing suites

- T001 `dpkg-buildpackage -b -us -uc` of V0's source package. keep
- T002 The same with the five `debian/patches/co03-*` entries applied (V2). keep
- T003 `quilt push -a` applies the series with the new entries, no fuzz. keep
- T004 `git format-patch` series applies with `git am` to a fresh import of V0. keep
- T005 Compiler warnings of the package build: V2 adds none (normalised diff of `warning:` lines). keep
- T006 ASan/UBSan build of bluetoothd (V0, V2, fixture). keep
- T007 Warnings of the ASan builds: V2 adds none. keep
- T008 The backport touches only `profiles/audio/transport.c` and `profiles/audio/a2dp.c` (plus `src/adapter.c` for BT-7). keep
- T009 `make check` in the package build tree: same results on V0 and V2. keep
- T010 `make check` in the ASan/UBSan tree: same results, no sanitizer report. keep
- T011 DEP-3 header fields present in every new patch (Description, Author, Origin, Applied-Upstream, Last-Update). keep

## L1: unit

BlueZ's own suites (`make check`, package configuration; one test per
binary; V0 baseline recorded in the results). None of them compiles
`profiles/audio/transport.c`, `a2dp.c` or `avdtp.c`
(`unit/test-avdtp` tests `android/avdtp.c`; `Makefile.am` L572–574), so
they cannot see the backport; they guard against build-level breakage only.

- T101–T132 the 32 binaries: test-hfp, test-gdbus-client, test-gobex-header,
  test-gobex-packet, test-gobex, test-gobex-apparam, test-lib, test-hog,
  test-gattrib, test-micp, test-bass, test-midi, test-mesh-crypto,
  test-tester, test-eir, test-uuid, test-textfile, test-crc, test-crypto,
  test-ecc, test-queue, test-mgmt, test-uhid, test-avctp, test-sdp,
  test-ringbuf, test-gobex-transfer, test-avdtp, test-avrcp, test-gatt,
  test-bap, test-vcp. keep (same outcome on V0 and V2)

Our harness (`tests/l1/test-co03-transport.c`, the tree's `transport.c`
included; same file for every tree):

Normal order and refusals:
- U101 Acquire on idle: START requested, sep locked, no reply yet. keep
- U102 START completes: Acquire answered with the fd, state active. keep
- U103 START fails: Acquire error, owner gone, unlocked. keep
- U104 Release while active: SUSPEND, reply after it, idle, no cancel. keep
- U105 SUSPEND fails: Release still succeeds. keep
- U106 Two Acquire/Release cycles. keep
- U107 Acquire while acquired (same owner): NotAuthorized. keep
- U108 Acquire while acquired (other client): NotAuthorized. keep
- U109 Release by a non-owner: NotAuthorized, still active. keep
- U110 Release with no owner: NotAuthorized. keep
- U111 `a2dp_resume()` refuses: Acquire NotAuthorized, unlocked. keep
- U112 TryAcquire on idle: NotAvailable. keep
- U113 Remote start (sink PLAYING), then TryAcquire. keep
- U114 Release during a pending TryAcquire: InProgress, no cancel. keep
- U115 Remote suspend while active: owner removed, idle, unlocked. keep
- U116 Second Release and an Acquire while suspending: InProgress, NotAuthorized. keep
- U117 Owner exits while active: suspended, no cancel. keep
- U118 Owner exits while Release waits for SUSPEND: the SUSPEND cancelled, as before. keep
- U119 Stream gone when START completes: Acquire fails. keep

Release during a pending Acquire (U12):
- U120 No `a2dp_cancel()` (no ABORT). **leak** (I4)
- U121 The cancelled Acquire is answered with an error. **leak** (I3)
- U122 Release waits for START, then SUSPEND, then answers; idle, unlocked. **leak** (I4)
- U123 Afterwards a new Acquire starts and succeeds, no cancel. **leak** (I2)
- U124 Acquire while the cancelled START is pending: refused. keep
- U125 START fails while Release waits: Release answered, owner gone, no ABORT. **leak** (I4)
- U126 START ok but SUSPEND cannot start: Release answered, owner gone. **leak** (I6)
- U127 Owner exits during a pending Acquire (no Release): START cancelled (ABORT), as before. keep
- U128 Owner exits while Release waits for the cancelled START: nothing left active. keep
- U129 Owner exits between START done and the deferred SUSPEND (idle callback): no use after free, no SUSPEND. keep
- U130 Transport destroyed during a pending Acquire: START cancelled, no use after free. keep
- U131 Transport destroyed while Release waits. keep
- U132 Transport destroyed before the deferred SUSPEND: no use after free. keep
- U133 Two cancel cycles back to back, then a normal one, no cancel. **leak** (I4)
- U134 Every D-Bus call of the U12 sequence answered exactly once. **leak** (I3)
- U135 Remote suspend while Release waits: owner gone, no crash. keep
- U136 The whole harness under ASan/UBSan: no report. keep (I8)

## L2: integration (two VMs)

`tests/l2/test_co03_a2dp.py`; host0 = build under test, host1 = fixture.
Each test records one JSON line per run (`runs/<run>/results.jsonl`).

The trigger, `Release()` during a pending `Acquire()` (checks I1–I4, I8):
- T201 `silent` sink, Release in the same main-loop turn. **leak**
- T202 `silent` sink, Release 87 ms after Acquire (EX-084's gap). **leak**
- T203 `slow` sink (answers ABORT), same turn. **leak** (expected from the upstream commit message: "A2DP profile disconnects"; to be checked)
- T204 `slow` sink, 87 ms. **leak** (same)
- T205 `plain` sink, same turn: the race as it falls. **leak** if the Release lands before START completes; recorded either way
- T206 `silent0` sink (START at once, ABORT never answered), same turn. **leak**
- T207 Roles swapped (host0 is the sink and sends START), `silent` remote. **leak**
- T208 Rates: T201, T202, T203, T204, T205, T206, T207 ten times each, per build. leak tests: 10/10 fail on V0, 10/10 pass on V2

Normal orderings (I5, I8):
- T220 Acquire, media flows to host1, Release; twice. keep
- T221 `silent` sink, Release only after the Acquire completed: no ABORT, A2DP kept. keep
- T222 Two Acquire/Release cycles back to back. keep
- T223 (Acquire, Release at once) twice, `slow` sink, then a probe. **leak** (I1, I2)
- T224 The same with the `silent` sink. **leak**
- T225 Release while suspending (`slowsusp`): second Release InProgress, Acquire NotAuthorized, first Release ok. keep
- T226 Refusals: Release with no owner, TryAcquire on idle, Acquire twice, Release by another client. keep
- T227 The remote releases its side while host0 streams: host0 idle, A2DP kept, new Acquire works. keep
- T228 20 Acquire/Release cycles in normal order. keep
- T229 MediaTransport1 property set of both transports (identical across builds). keep
- T230 Roles swapped, normal order: host0 (sink) acquires and reads the remote's media. keep

Failure paths (I6, I8; outcome recorded):
- T240 `reject`: Acquire alone, START rejected: Acquire error, A2DP kept. keep
- T241 `reject`, Release during pending: A2DP kept, Release answered. record (→ **leak**, see "Reclassified")
- T242 `nostart`: Acquire alone, START never answered (AVDTP's 6 s timeout). record
- T243 `nostart`, Release at once: Release answered. record (expected change: V2 waits the START out, timing differs)
- T244 `nostart_silent`, Release at once: A2DP lost on every build (AVDTP gives up), timing recorded. record
- T245 host0 disconnects the device while Acquire waits (`slow1000`): calls answered, reconnect works. keep
- T246 The same with Release already waiting. keep (→ **leak**, see "Reclassified")
- T247 The remote disconnects while Release waits. keep (→ **leak**, see "Reclassified")
- T248 Owner exits while Acquire waits (`silent`). record (code reading: both builds cancel the START, ABORT, A2DP lost)
- T249 Owner exits while Release waits for the cancelled START (`silent`). record
- T250 Owner exits while Release of an active stream waits for SUSPEND (`slowsusp`). record
- T251 Reconfigure (remote SEP `SetConfiguration()`) while idle: new transport works. keep
- T252 Reconfigure while Release waits for a START answered after 300 ms (the `664a5d3785a1` path). record; invariant: calls answered, A2DP usable after (→ **leak**, see "Reclassified")
- T260 Every L2 test: no ASan/UBSan line in either guest's bluetoothd log. keep (I8)

## L3: application (PipeWire, WirePlumber)

PipeWire master `build-v0-asan` (the CO-36 build, unchanged) with
WirePlumber master, in PipeWire's CI image; both guests run the build under
test unless stated.

PipeWire's own VM tests (`test/bluezenv/test_streaming.py`), I7:
- T301 `test_pipewire_a2dp`. keep
- T302 `test_pipewire_profile_switch` (play, switch to HFP and back three times). keep
- T303 `test_pipewire_hfp`. keep
- T304 `test_pipewire_bluez_restart`. keep
- T305 `test_pipewire_bap_ucast`. keep (5.72's outcome recorded; judge the difference)
- T306 `test_pipewire_bap_bcast`. keep (same)
- T307 `test_pipewire_bap_profile_switch`. keep (same)

The desktop trigger (ours, `tests/l3/test_co03_pw.py`, host1 = fixture):
- T310 `slow1000` remote (START answered after 1 s, ABORT never): play, then switch the profile to `headset-head-unit` 0.8 s later (pw-cli, index looked up beforehand); then back to `a2dp-sink` and play: A2DP profile still offered and audio reaches host1. **leak**. Window widened from the headset's ~0.2 s to 1 s because PipeWire under ASan in the guest takes ~0.4-0.6 s from pw-play to the Acquire (first V0 smoke runs); whether the Release landed while START was pending is read from host0's log (`REQUESTING -> SUSPENDING`) and recorded per run.
- T311 The same with the `plain` remote. record
- T312 WirePlumber's autoswitch (policy on): a capture stream on host0's Bluetooth source opened right after playback starts (`slow1000` remote); the capture ends after 3 s, the policy restores A2DP; then play: profile offered, audio flows. **leak** (if the switch lands while START is pending; recorded)
- T313 Rate: T310 ten times per build. leak: fails on V0 in most runs, passes on V2 in all

On the laptop, only on the operator's word (not run here):
- T320 MOMENTUM 4: an application opening the microphone as A2DP starts; A2DP kept (V2 installed). operator
- T321 The capture of T320 shows no ABORT, START then SUSPEND. operator

## Consistency

- T401 One results table: every test, V0 and V2 side by side.
- T402 The set of changed outcomes equals the leak set; anything else is listed and explained.
- T403 The same test files run unchanged on every build.
- T404 L1 and L2 agree where both can run (U120 ↔ T201–T207 ABORT; U121 ↔ I3; U123 ↔ I2).

## Reclassified after the first V0 run (before any backport run)

The first full L2 run on V0 (`runs/base-r1b`, a debugging run of the
test code) showed four tests whose class was wrong: each of them contains a
`Release()` during a pending `Acquire()`, so V0 fails them through the U12
path itself, not through what the test was written for:

- T241 (`reject`, Release during pending): record → **leak**. V0: ABORT
  sent, the sink answers it, `a2dp-sink` disconnected 5.8 ms after the
  Acquire (I1).
- T246, T247 (disconnect while Release waits): keep → **leak**. V0: the
  cancelled `Acquire()` is never answered (I3); the rest passes.
- T252 (reconfigure while Release waits): record → **leak**. V0: the
  `Acquire()` is never answered (I3).

The test code was also fixed after that run, without changing what any
test checks: pairing drops a stale kernel link key first (the reused
guests kept it, and `Pair()` failed with AlreadyExists), and log windows
start at a guest timestamp instead of the tester's clock. The official V0
run is `runs/v0-l2*` with the fixed code.

One more test-code correction after the official V0 run (`runs/v0-l2`),
before any backport run: T251 (reconfigure while idle) failed on V0
because it counted the `a2dp-sink` "connected -> disconnected" that every
reconfigure produces (the stream goes IDLE before the new configuration;
7.2 ms after the call) as a lost connection. T251 now records that line
and fails only on a sanitizer report or a failed probe on the new
transport; re-run on V0 as `runs/v0-l2-t251fix`.

## Results on V0 (unmodified 5.72-0ubuntu5.8), recorded before any V2 run

Runs: L1 `logs/l1-base.log`; L2 `runs/v0-l2` (all, once),
`runs/v0-l2rates` (T201–T207, ten each), `runs/v0-l2-t251fix`; L3
`runs/v0-l3pw-*` (PipeWire's own), `runs/v0-l3`, `runs/v0-l3rates`;
BlueZ suites `logs/pkg-check-base.log`, `logs/asan-check-base.log`.

- **L1 harness:** 27 pass, 8 fail; the 8 failures are exactly the leak set
  (U120, U121, U122, U123, U125, U126, U133, U134); every keep test
  passes; no ASan/UBSan report.
- **L1 BlueZ suites, package configuration:** 30 of 32 pass; `test-vcp`
  (`tester.c:949 assertion failed (len == iov->iov_len): (5 == 7)`) and
  `test-mesh-crypto` ("Crypto packet encrypt … FAIL") fail on V0. ASan
  configuration (mesh off): 25 of 25 pass, `test-vcp` included.
- **L2 leak tests, V0:** T201, T202, T203, T204, T205, T206, T207 each
  fail **10 of 10** (plus 1 of 1 in `v0-l2`): the `Acquire()` never
  answered, one ABORT, A2DP lost, no later Acquire possible. Loss after the
  Acquire: silent remote 1790–2826 ms (the 2 s ABORT timeout), ABORT-answering
  remote 4.9–6.5 ms (same turn) or 92–97 ms (Release at 87 ms): with a
  remote that answers ABORT, 5.72 drops `a2dp-sink` at once
  (`abort_cfm` → stream IDLE → `a2dp-sink state changed: connected ->
  disconnected`, then AVRCP by the policy; AVDTP closes 1 s later). T223,
  T224, T241, T246, T247, T252 fail (once each) the same way.
- **L2 keep tests, V0:** all pass (T220–T222, T225–T230, T240, T245,
  T251 after its correction).
- **L2 record tests, V0:** T242 START never answered: AVDTP's own 6 s
  timeout aborts, A2DP lost at 6300 ms; T243 (+ Release): ABORT at once,
  lost at 7.2 ms; T244: lost at 1940 ms; T248 owner exits during the
  pending Acquire: ABORT, lost at 2381 ms; T249: lost at 2485 ms; T250
  owner exits while Release waits for SUSPEND: ABORT, lost at 80.6 ms.
- **L2 sanitizers, V0:** no ASan/UBSan line in any bluetoothd log.
- **L3 PipeWire's own tests, V0:** a2dp, profile_switch, hfp,
  bluez_restart pass; bap_ucast, bap_bcast, bap_profile_switch fail
  (RPC timeout / "pipewire devices not seen"; 5.72's BAP).
- **L3 ours, V0:** T310 fails 10 of 10 (+1): the Release lands while
  REQUESTING in 10 of 10, one ABORT each, A2DP lost 2763–3739 ms after
  playback starts, `a2dp-sink` no longer offered. T312 (WirePlumber's
  autoswitch) fails: same chain, lost at 3177 ms. T311 (stock remote)
  passes: there the Release came after START completed (no REQUESTING →
  SUSPENDING).

## Results: V0 and V2 side by side

V2 runs: L1 `logs/l1-backport.log`; L2 `runs/v2-l2`, `runs/v2-l2rates`
(70 lines in `results.jsonl`; its `stdout.log` stops at 16:38 from
buffering, the run ended at 16:48 per `pytest.log`, whose 70 "call"
stage lines all read PASSED; the measurements below are from
`results.jsonl`); L3 `runs/v2-l3pw-*`, `runs/v2-l3`,
`runs/v2-l3rates`; package `logs/pkg-build-backport.log`,
`logs/pkg-check-backport.log`; ASan `logs/asan-*-backport.log`.

"pass n/m" = test passed n of m runs. Leak = intended to change.

### L0

| ID | Check | V0 | V2 | Changed |
|---|---|---|---|---|
| T001/T002 | `dpkg-buildpackage -b -us -uc` | exit 0, 11 `.deb` + 7 `.ddeb` | exit 0, the same set as `5.72-0ubuntu5.9~co03.1` | no |
| T003 | `quilt push -a`, new entries | — | applied, no offset/fuzz (`logs/make-pkg-trees-backport.log`) | — |
| T004 | `git am` of `format-patch/` on a fresh import | — | 5 commits, tree identical to the branch (`logs/t004-git-am.log`) | — |
| T005 | package build warnings (normalised) | 2 compiler warnings | the same 2, none new (`logs/t005-warnings-pkg.txt`) | no |
| T006 | ASan/UBSan builds (noble, Fedora 44) | built | built | no |
| T007 | ASan build warnings | noble 1, F44 4 | the same (`logs/t007-warnings-*.txt`) | no |
| T008 | files touched | — | `transport.c`, `a2dp.c`, `src/adapter.c` (155+/34−) | — |
| T009 | `make check`, package configuration | 30/32 (test-vcp, test-mesh-crypto fail) | identical list (`logs/t009-*.txt`, `diff` empty) | no |
| T010 | `make check`, ASan/UBSan | 25/25 | 25/25 | no |
| T011 | DEP-3 fields | — | 5/5 OK (`scripts/check-dep3.py`) | — |

### L1

| ID | V0 | V2 | Class | Changed |
|---|---|---|---|---|
| T101–T132 BlueZ suites (32 binaries) | as T009/T010 | as T009/T010 | keep | no |
| U101–U119 | pass (19/19) | pass (19/19) | keep | no |
| U120, U121, U122, U123 | fail | pass | leak | **yes, intended** |
| U124 | pass | pass | keep | no |
| U125, U126 | fail | pass | leak | **yes, intended** |
| U127–U132 | pass | pass | keep | no |
| U133, U134 | fail | pass | leak | **yes, intended** |
| U135 | pass | pass | keep | no |
| U136 sanitizers | no report | no report | keep | no |
| total | 27 pass, 8 fail | 35 pass | | 8 changed = the 8 leak tests |

### L2

| ID | Remote | V0 | V2 | Class | Changed |
|---|---|---|---|---|---|
| T201 | silent, same turn | pass 0/11 | pass 11/11 | leak | **yes** |
| T202 | silent, +87 ms | pass 0/11 | pass 11/11 | leak | **yes** |
| T203 | slow, same turn | pass 0/11 | pass 11/11 | leak | **yes** |
| T204 | slow, +87 ms | pass 0/11 | pass 11/11 | leak | **yes** |
| T205 | plain, same turn | pass 0/11 | pass 11/11 | leak | **yes** |
| T206 | silent0, same turn | pass 0/11 | pass 11/11 | leak | **yes** |
| T207 | sink role, silent | pass 0/11 | pass 11/11 | leak | **yes** |
| T220 | plain | pass | pass | keep | no |
| T221 | silent, Release after START | pass | pass | keep | no |
| T222 | plain | pass | pass | keep | no |
| T223 | slow, 2 cancel cycles | fail | pass | leak | **yes** |
| T224 | silent, 2 cancel cycles | fail | pass | leak | **yes** |
| T225 | slowsusp | pass | pass | keep | no |
| T226 | plain, refusals | pass | pass | keep | no |
| T227 | plain, remote suspends | pass | pass | keep | no |
| T228 | plain, 20 cycles | pass | pass | keep | no |
| T229 | plain, properties | pass | pass | keep | no |
| T230 | sink role, plain | pass | pass | keep | no |
| T240 | reject | pass | pass | keep | no |
| T241 | reject + Release | fail (lost 5.6 ms) | pass (Release answered `Failed`, A2DP kept) | leak (reclassified) | **yes** |
| T242 | nostart | pass (lost 6300 ms) | pass (lost 6444 ms) | record | no |
| T243 | nostart + Release | pass (ABORT at once, lost 7.2 ms; Release `ok`) | pass (START waited out, lost 6288 ms; Release `Failed`) | record, change expected | timing only |
| T244 | nostart_silent + Release | pass (lost 1940 ms) | pass (lost 8600 ms) | record | timing only |
| T245 | disconnect during Acquire | pass | pass | keep | no |
| T246 | disconnect while Release waits | fail (Acquire unanswered) | pass | leak (reclassified) | **yes** |
| T247 | remote disconnect while Release waits | fail (Acquire unanswered) | pass | leak (reclassified) | **yes** |
| T248 | owner exits during Acquire, silent | pass (ABORT, lost 2381 ms) | pass (ABORT, lost 1810 ms) | record | no |
| T249 | owner exits while Release waits, silent | pass (lost 2485 ms) | pass (ABORT, lost 2500 ms) | record | no |
| T250 | owner exits while Release waits for SUSPEND | pass (ABORT, lost 80.6 ms) | pass (ABORT, lost 80.7 ms) | record | no |
| T251 | reconfigure idle | fail in `v0-l2` (test bug), pass in `v0-l2-t251fix` | pass | keep | no (after the correction) |
| T252 | reconfigure while Release waits | fail (Acquire unanswered) | pass | leak (reclassified) | **yes** |
| T260 | sanitizer lines in guests' bluetoothd logs, whole L2 | none | none | keep | no |

Rates of the trigger (`runs/v*-l2rates/results.jsonl`, ten runs per
test and build, `scripts/summarize.py`):

| test | build | remote | runs | Acquire reply | Release reply | ABORT sent | A2DP lost (ms after Acquire) | later Acquire + media | sanitizer |
|---|---|---|---|---|---|---|---|---|---|
| t201 | V0 | silent | 10 | none ×10 | ok ×10 | 1 ×10 | 10/10 (1790.0–2736.4) | 0/10 | 0 |
| t202 | V0 | silent | 10 | none ×10 | ok ×10 | 1 ×10 | 10/10 (1865.6–2826.3) | 0/10 | 0 |
| t203 | V0 | slow | 10 | none ×10 | ok ×10 | 1 ×10 | 10/10 (4.9–6.5) | 0/10 | 0 |
| t204 | V0 | slow | 10 | none ×10 | ok ×10 | 1 ×10 | 10/10 (92.1–97.4) | 0/10 | 0 |
| t205 | V0 | plain | 10 | none ×10 | ok ×10 | 1 ×10 | 10/10 (5.3–6.1) | 0/10 | 0 |
| t206 | V0 | silent0 | 10 | none ×10 | ok ×10 | 1 ×10 | 10/10 (1846.3–2562.0) | 0/10 | 0 |
| t207 | V0 | silent | 10 | none ×10 | ok ×10 | 1 ×10 | 10/10 (1839.9–2633.6) | 0/10 | 0 |
| t201 | V2 | silent | 10 | org.bluez.Error.Failed ×10 | ok ×10 | 0 ×10 | 0/10 | 10/10 | 0 |
| t202 | V2 | silent | 10 | org.bluez.Error.Failed ×10 | ok ×10 | 0 ×10 | 0/10 | 10/10 | 0 |
| t203 | V2 | slow | 10 | org.bluez.Error.Failed ×10 | ok ×10 | 0 ×10 | 0/10 | 10/10 | 0 |
| t204 | V2 | slow | 10 | org.bluez.Error.Failed ×10 | ok ×10 | 0 ×10 | 0/10 | 10/10 | 0 |
| t205 | V2 | plain | 10 | org.bluez.Error.Failed ×10 | ok ×10 | 0 ×10 | 0/10 | 10/10 | 0 |
| t206 | V2 | silent0 | 10 | org.bluez.Error.Failed ×10 | ok ×10 | 0 ×10 | 0/10 | 10/10 | 0 |
| t207 | V2 | silent | 10 | org.bluez.Error.Failed ×10 | ok ×10 | 0 ×10 | 0/10 | 10/10 | 0 |

### L3

| ID | V0 | V2 | Class | Changed |
|---|---|---|---|---|
| T301 test_pipewire_a2dp | pass | pass | keep | no |
| T302 test_pipewire_profile_switch | pass | pass | keep | no |
| T303 test_pipewire_hfp | pass | pass | keep | no |
| T304 test_pipewire_bluez_restart | pass | pass | keep | no |
| T305 test_pipewire_bap_ucast | fail (RPC timeout) | fail (same) | keep | no |
| T306 test_pipewire_bap_bcast | fail ("pipewire devices not seen") | fail (same) | keep | no |
| T307 test_pipewire_bap_profile_switch | fail (RPC timeout) | fail (same) | keep | no |
| T310/T313 switch during START | pass 0/11; Release while REQUESTING 11/11; ABORT 11/11; A2DP lost 11/11 | pass 11/11; Release while REQUESTING 11/11; ABORT 0; lost 0; audio after 11/11 | leak | **yes** |
| T311 stock remote | pass (Release after START) | pass | record | no |
| T312 WirePlumber autoswitch | fail (ABORT, lost 3177 ms) | pass (Release while REQUESTING, no ABORT, audio after) | leak | **yes** |

### T402: the set of changed outcomes

V0 → V2 changed exactly: U120, U121, U122, U123, U125, U126, U133, U134
(L1); T201–T207 (all 77 runs), T223, T224, T241, T246, T247, T252 (L2);
T310 (11 runs), T312 (L3). All are leak tests; no keep test changed. Two
record tests changed only in timing, as the plan expected for the waited-out
START (T243, T244). T251 is not a change: it failed only in `v0-l2`,
before its correction (see "Reclassified"), and passes on V0 and V2 since.

### Sanitizer reports at bluetoothd exit (separate finding, not from the backport)

`scripts/find-sanitizer.sh` over every `runs/*/pytest.log` (the guests'
bluetoothd output, including test teardown, which the in-test checks do
not cover). Only the Fedora 44 builds (L3) reported; the Ubuntu builds
(L2) reported nothing in any run.

| Report | Where | Build | Evidence |
|---|---|---|---|
| `heap-use-after-free profiles/audio/media.c:300 in clear_endpoint` | bluetoothd exit: `main` → `plugin_cleanup` → `a2dp_exit` → `unload_driver` → `g_dbus_unregister_interface` → `path_free` (`media.c:3276`) → `release_endpoint` (`media.c:566`) → `clear_endpoint`; freed in `a2dp_unregister_sep` (`a2dp.c:2618` on V0, `:2623` on V2); allocated in `media_endpoint_create` (`media.c:1463`) | V0, 10 runs of T311 (`runs/exitcheck-base-t311x10/pytest.log`): host0 (V0) at 15:43:26, 15:46:18, 15:46:54 UTC; host1 (the fixture build, V0 plus the fixture) at 15:48:05 UTC. V2: 2 of 10 runs of T310 (`runs/v2-l3rates/pytest.log`, 15:30:50, 15:34:29 UTC); 0 of 10 runs of T311 (`runs/exitcheck-backport-t311x10/pytest.log`) | `runs/exitcheck.log` |
| `heap-use-after-free src/device.c:6167 in device_set_rssi_with_delta` | bluetoothd exit: `main` → `adapter_cleanup` → `adapter_remove` → `discovery_cleanup` (`adapter.c:1721`) → `invalidate_rssi_and_tx_power` (`adapter.c:1706`); device freed in `remove_interface` (`gdbus/object.c:660`) | V0: `runs/l3-smoke2/pytest.log` (14:44:04 UTC). V2: `runs/v2-l3pw-test_pipewire_a2dp/pytest.log` (15:21:21 UTC) | |

Both are in code the backport does not change, and both occur on V0.
