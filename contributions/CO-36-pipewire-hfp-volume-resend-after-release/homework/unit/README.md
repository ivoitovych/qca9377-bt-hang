# CO-36 L1: unit harness for the delayed volume resend

`spa/plugins/bluez5/backend-native.c`, unmodified, compiled into a test
program with the CI build's flags (ASan, UBSan, `-Og`, the same warnings),
driven by hand in **virtual time**. Implements [TEST-PLAN.md](../TEST-PLAN.md)
T101–T183 (layer L1); T190–T193 wait for the variants.

## How it works

- `test-backend-native.c` does `#include "backend-native.c"`, so the static
  functions (`sco_acquire_cb()`, `sco_event()`, `sco_release_cb()`,
  `rfcomm_event()`, `rfcomm_free()`, ...) are called directly.
- RFCOMM is a `socketpair(AF_UNIX, SOCK_STREAM)`: the AG's end is
  `rfcomm->source.fd`; the test writes the headset's `AT+...\r` commands to
  the other end and dispatches `rfcomm_event()` with `SPA_IO_IN`, then reads
  every `\r\n<frame>\r\n` the AG wrote and stamps it with the virtual time.
- Setup per test: a backend (`struct impl`), an adapter (bus not USB), a
  device with `hw_volume_profiles` = HFP HF | HSP HS, and an `rfcomm` built
  as `profile_new_connection()` builds it (L3511–L3593, without D-Bus). A
  minimal HF SLC then runs over the socketpair:
  `AT+BRSF` (remote volume control, codec negotiation), `AT+BAC=1,2`,
  `AT+CIND=?`, `AT+CIND?`, `AT+CMER=3,0,0,1`, the AG's `+BCS: 2`, `AT+BCS=2`
  (mSBC transport from `rfcomm_new_transport()`), then `AT+VGS=6`,
  `AT+VGM=15`. HSP: the transport comes from the connection itself, then the
  two reports. The clock starts at 0 after setup.
- A link: the transport's `fd` is set to one end of another socketpair
  (in place of `sco_do_connect()`'s socket), `acquire` is called, then
  `sco_event()` is dispatched with `SPA_IO_OUT`; `sco_ready()` reads
  `SO_ERROR` (0), fails `getsockopt(SOL_SCO)` and takes MTU 144, sends the
  gains and arms the resend. Release = the transport's `release`
  (`sco_release_cb()`); hang-up = `sco_event()` with `SPA_IO_HUP` or
  `SPA_IO_ERR`; RFCOMM loss = `rfcomm_event()` with `SPA_IO_HUP`.
- One child process per test, so a crash or a sanitizer report stays with
  its test; after each test the harness frees what is left and checks I8:
  no loop source, timer, timerfd, transport, device listener or file
  descriptor may remain.

## The fakes

| Fake | Where | Does |
|---|---|---|
| `spa_loop` | `fakes.c` | keeps a list of sources, sets/clears `source->loop` as the real loop does; never polls |
| `spa_loop_utils` timers | `fakes.c` | `add_timer` / `update_timer` / `destroy_source` record a one-shot deadline in virtual ns (`NULL` or 0 disarms) |
| `spa_system` | `fakes.c` | timerfds for the codec-switch timer, never real fds; `timerfd_read` returns `-EAGAIN` unless expired |
| dispatch | `fake_run_until()` | fires every timer due up to a time, earliest first, ties in arming order, setting the clock to each deadline |
| `spa_log` | `fakes.c` | stderr, errors only; `-v` for debug |
| `spa_bt_transport_create/free/set_state` | `stubs.c` | as `bluez5-dbus.c`: `free` emits `destroy` to listeners and calls the implementation's `destroy`; `set_state` emits `state_changed` and, like `transport_sync_volume()`, calls `set_volume` on entering PENDING/ACTIVE |
| codecs | `stubs.c` | mSBC and CVSD descriptors (id, kind, codec id, names only) |
| other `spa_bt_*`, telephony, upower | `stubs.c` | benign returns; no telephony object exists in the AG role |
| guards | `fakes.c` | `socket(AF_BLUETOOTH, ...)` and every libusb call abort the test; the container has no network and no devices |

## How to run

```
contributions/CO-36-pipewire-hfp-volume-resend-after-release/homework/unit/run-unit.sh
contributions/CO-36-pipewire-hfp-volume-resend-after-release/homework/unit/run-unit.sh -- -v T130   # one test, every frame and debug log
contributions/CO-36-pipewire-hfp-volume-resend-after-release/homework/unit/run-unit.sh -f <variant>/backend-native.c
```

`run-unit.sh` runs `build-and-run.sh` in `co36-pw-ci:f44` (`--network none`,
the tree and this directory read-only, no devices), builds in the
container's `/tmp`, and writes `tmp/co36/unit-run-<n>.log`. `-s <tree>`
takes another tree with `build-v0-asan/`; `-f` compiles a variant's
`backend-native.c` in place of the tree's. The log starts with the tree's
commit and the file's sha256.

## Output

One line per test: `<ID> <PASS|FAIL> <observation>`. The observation is
the timeline: markers (`up`, `rel` release, `hup`/`err` hang-up,
`rfcomm-lost`, `tfree` transport freed, `hf-...` headset command,
`user-...` user volume) and `+VGS`/`+VGM` frames, each `@<virtual ms>`;
`!` marks a frame written by a timer while no link was up (I1). The last
line lists tests whose outcome differs from the plan's master expectation
(leak = FAIL, keep = PASS).

## Result on master

`4cfc471123a0`, `backend-native.c` sha256 `bb5d4c4e...1597`, 2026-10-31:

```
T101 PASS up@0 +VGS:6@0 +VGM:15@0; resend armed yes@1500
T102 PASS up@0 +VGS:6@0
T103 PASS up@0
T104 PASS up@0 (to 2000)
T105 PASS up@0 (to 2000)
T106 PASS up@0 +VGS=6@0 +VGM=15@0
T107 PASS td->err=-88 state=-1 resend armed no; up-failed@0 (to 2000)
T108 PASS up@0 +VGS:6@0 +VGM:15@0 sco_ready@100; resend still @1500
T110 PASS up@0 +VGS:6@0 +VGM:15@0 (to 1499)
T111 PASS up@0 +VGS:6@0 +VGM:15@0 +VGS:6@1500 +VGM:15@1500
T112 PASS up@0 +VGS:6@0 +VGM:15@0 +VGS:6@1500 +VGM:15@1500 (to 10000)
T113 PASS up@0 +VGS:6@0 +VGM:15@0 user-vgs=10@1000 +VGS:10@1000 +VGS:10@1500 +VGM:15@1500
T114 PASS up@0 +VGS:6@0 +VGM:15@0 hf-vgs=9@1000 +VGS:9@1500 +VGM:15@1500
T120 FAIL 2 late: up@0 +VGS:6@0 +VGM:15@0 rel@100 +VGS:6@1500! +VGM:15@1500!
T121 FAIL 2 late: up@0 +VGS:6@0 +VGM:15@0 rel@1499 +VGS:6@1500! +VGM:15@1500!
T122 PASS up@0 +VGS:6@0 +VGM:15@0 +VGS:6@1500 +VGM:15@1500 rel@1500
T123 PASS up@0 +VGS:6@0 +VGM:15@0 +VGS:6@1500 +VGM:15@1500 rel@1501
T124 FAIL 2 late: up@0 +VGS:6@0 +VGM:15@0 rel@0 +VGS:6@1500! +VGM:15@1500!
T130 FAIL 2 late: up@0 +VGS:6@0 +VGM:15@0 hup@100 +VGS:6@1500! +VGM:15@1500!
T131 FAIL 2 late: up@0 +VGS:6@0 +VGM:15@0 hup@1499 +VGS:6@1500! +VGM:15@1500!
T132 FAIL 2 late: up@0 +VGS:6@0 +VGM:15@0 err@100 +VGS:6@1500! +VGM:15@1500!
T133 FAIL 2 late: up@0 +VGS:6@0 +VGM:15@0 hup@100 rel@200 +VGS:6@1500! +VGM:15@1500!
T140 PASS up@0 +VGS:6@0 +VGM:15@0 rfcomm-lost@100; timers left after close: 0
T141 PASS up@0 +VGS:6@0 +VGM:15@0 rfcomm-lost@1499; timers left after close: 0
T142 PASS up@0 +VGS:6@0 +VGM:15@0 tfree@100; rfcomm->transport NULL
T150 PASS up@0 +VGS:6@0 +VGM:15@0 rel@100 up@1000 +VGS:6@1000 +VGM:15@1000 +VGS:6@2500 +VGM:15@2500
T151 FAIL 2 late: up@0 +VGS:6@0 +VGM:15@0 rel@100 +VGS:6@1500! +VGM:15@1500! up@1600 +VGS:6@1600 +VGM:15@1600 +VGS:6@3100 +VGM:15@3100
T152a PASS up@0 +VGS:6@0 +VGM:15@0 rel@100 up@1500 +VGS:6@1500 +VGM:15@1500 +VGS:6@3000 +VGM:15@3000
T152b FAIL 2 late: up@0 +VGS:6@0 +VGM:15@0 rel@100 +VGS:6@1500! +VGM:15@1500! up@1500 +VGS:6@1500 +VGM:15@1500 +VGS:6@3000 +VGM:15@3000
T153 FAIL 2 late: up@0 +VGS:6@0 +VGM:15@0 rel@100 up@1000 +VGS:6@1000 +VGM:15@1000 rel@1100 +VGS:6@2500! +VGM:15@2500!
T154 FAIL 2 late: up@0 +VGS:6@0 +VGM:15@0 rel@100 up@200 +VGS:6@200 +VGM:15@200 rel@300 up@400 +VGS:6@400 +VGM:15@400 rel@500 up@600 +VGS:6@600 +VGM:15@600 rel@700 up@800 +VGS:6@800 +VGM:15@800 rel@900 up@1000 +VGS:6@1000 +VGM:15@1000 rel@1100 up@1200 +VGS:6@1200 +VGM:15@1200 rel@1300 up@1400 +VGS:6@1400 +VGM:15@1400 rel@1500 up@1600 +VGS:6@1600 +VGM:15@1600 rel@1700 up@1800 +VGS:6@1800 +VGM:15@1800 rel@1900 +VGS:6@3300! +VGM:15@3300!
T160 PASS up@0 +VGS:6@0 +VGM:15@0 hf-bcs=2@100; resend armed after BCS: no
T161 PASS up@0 +VGS:6@0 +VGM:15@0 rel@50 hf-bcs=2@100; resend armed after BCS: no
T162 PASS up@0 +VGS:6@0 +VGM:15@0 hf-bcs=2@100 up@200 +VGS:6@200 +VGM:15@200 +VGS:6@1700 +VGM:15@1700; after BCS: new transport state=0 fd=-1 requesting=0 sco-in-loop=0 err=0, old SCO source in loop: no
T163 PASS +CIEV:2,1@0 up@0 +VGS:6@0 +VGM:15@0 hf-bcs=3@100 ERROR@100; transport kept: yes; resend armed after BCS: no; link still up
T170 PASS res=0; user-vgs=10@0 +VGS:10@0
T171 PASS res=0; user-vgm=10@0 +VGM:10@0
T172 PASS res=0; up@0 +VGS:6@0 +VGM:15@0 user-vgs=10@500 +VGS:10@500
T173 PASS res=0; up@0 +VGS:6@0 +VGM:15@0 rel@100 user-vgs=10@200 +VGS:10@200
T174 PASS res=0; user-vgs=6@0
T175 PASS res=-95; user-vgm=10@0
T180 PASS OK@0; active=1 hw=7 transport active=1 volume=0.1016
T181 PASS OK@0; active=1 hw=7 transport active=1 volume=0.1016
T182 PASS up@0 +VGS:6@0 +VGM:15@0 hf-vgm=9@500 +VGS:6@1500 +VGM:9@1500
T183 PASS hf-vgs=16@0 ERROR@0 hf-vgs=-1@0 ERROR@0 hf-vgm=16@0 ERROR@0; gains kept vgs=6 vgm=15
T120c FAIL 2 late: up@0 +VGS:6@0 +VGM:15@0 rel@100 +VGS:6@1500! +VGM:15@1500!
T130c FAIL 2 late: up@0 +VGS:6@0 +VGM:15@0 hup@100 +VGS:6@1500! +VGM:15@1500!
T120h FAIL 2 late: up@0 +VGS=6@0 +VGM=15@0 rel@100 +VGS=6@1500! +VGM=15@1500!
T130h FAIL 2 late: up@0 +VGS=6@0 +VGM=15@0 hup@100 +VGS=6@1500! +VGM=15@1500!
# 49 tests: 34 PASS, 15 FAIL
# differs from TEST-PLAN.md's master outcome (leak = FAIL, keep = PASS): none
```

No sanitizer report, no I8 finding. The build prints two
`-Wmaybe-uninitialized` warnings from `rfcomm_hfp_hf()` (L2356 `idx`,
L2386 `status`; HF role, not under test).

| Group | Plan | Master |
|---|---|---|
| T101–T114 immediate send, resend on a long link | keep | all PASS |
| T120, T121, T124 release before 1.5 s | leak | FAIL: both gains at 1500 after the release |
| T122, T123 release at/after the resend | keep | PASS |
| T130–T133 hang-up (HUP, ERR, HUP then release) | leak | FAIL: both gains at 1500 after the hang-up |
| T140–T142 RFCOMM lost, transport freed | keep | PASS: timer destroyed / no transport, nothing written |
| T150 second link in time | keep | PASS |
| T151, T153, T154 second link late / short | leak | FAIL |
| T152 second link at exactly 1500 | record | ready first (a): no late frame; timer first (b): both late |
| T160–T163 codec selection | keep | PASS |
| T170–T175 user volume | keep | PASS |
| T180–T183 headset reports | keep | PASS |

Extras, not in the plan: `c` = HF without codec negotiation (CVSD
transport made at `AT+CMER`), `h` = HSP. Both leak as the mSBC case does;
the HSP resend is `+VGS=`/`+VGM=` (the L1 answer to T229's question).

Self-check: with a scratch copy of `backend-native.c` that only stops the
resend timer in `sco_release_cb()` and in `sco_event()`'s HUP/ERR branch
(run with `-f`), all 49 PASS and the summary lists exactly T120, T121,
T124, T130–T133, T151, T153, T154 as differing: the harness sees the
change, and nothing else moves.

## What it cannot show

- Whether a late frame matters to a headset (L3, real headsets).
- Real event order: the loop is not run; T152 runs both orders because
  epoll may deliver the SCO event and the timer in either order.
- `bluez5-dbus.c`: the 1 s release delay, release timer, keepalive and
  profile switching are not modelled; the tests choose when a link ends.
- D-Bus entry points: `profile_new_connection()` and
  `profile_request_disconnection()` are mirrored or not called; a variant
  that changes them is not tested here.
- Socket set-up: `sco_do_connect()`, `sco_listen_event()` and the USB ALT6
  probe are not reached (guarded); the link uses the MTU-144 fallback.
- Quirks are absent (all features on), so `broken_mic_hw_volume` is never
  set; the HF role (`rfcomm_hfp_hf()`) and telephony objects are not
  exercised.
- T107's error is `ENOTSOCK` (a pipe as the SCO fd), not a radio error;
  the code path after `td->err` is the same.

## Files

| File | |
|---|---|
| `test-backend-native.c` | the tests and the runner |
| `harness.h`, `fakes.c` | loop, timers, system, log, guards |
| `stubs.c` | the bluez5 monitor symbols `backend-native.c` links to |
| `build-and-run.sh` | builds and runs inside the image |
| `run-unit.sh` | host side: docker, log file |
