# CO-36 homework: reproduce, then test fix variants

Before asking the maintainers which lifetime the delayed volume resend
should have, reproduce the problem on current master in PipeWire's own
Bluetooth VM tests, then run every candidate fix through the same tests.

- [`TEST-PLAN.md`](TEST-PLAN.md): the whole suite by layer, the invariants,
  the variants, and every test's result on master.
- [`unit/`](unit/README.md): the L1 harness (virtual time).
- [`tests/`](tests/test_co36_hfp_volume_resend.py): the L2/L3 VM tests.

## Setup

Everything runs in a local rebuild of PipeWire CI's `bluez_tests` image,
on this machine, with KVM.

| Part | Version | Source |
|---|---|---|
| PipeWire | master `4cfc471123a0` (2026-10-30) | `cache/co36-pw-master` (worktree of `cache/pipewire-upstream`) |
| WirePlumber | `4ab992fa` (0.5.19), as the `subprojects/wireplumber` checkout | CI uses `master` at build time; pinned here so every variant gets the same one |
| BlueZ | `ebbb4ee31ad7`, built with ASan/UBSan | CI's `BLUEZ_COMMIT`, by CI's own `setup-fedora-container.sh` |
| pytest-bluezenv | 0.1.9 | CI's `PYTEST_BLUEZENV_VERSION` |
| VM kernel | `bzImage-v7.2-cfgc2208dd3` (release 2026-09-15.1 of `pv/bluez-test-functional-kernel`) | CI's `BLUEZENV_BZIMAGE` |
| Image | Fedora 44, CI's package list | [`ci/Dockerfile`](ci/Dockerfile) |
| Build | CI's `bluez_tests` options: ASan + UBSan, `-Ddebug=true -Doptimization=g` | [`ci/bluez-tests-inside.sh`](ci/bluez-tests-inside.sh) |

Isolation from the machine's own Bluetooth:

- The VMs' controllers come from `btvirt --server=<tmpdir>`, a user-space
  emulator joined to each VM over Unix sockets (pytest-bluezenv
  `env.py`, `_start_btvirt`).
- pytest-bluezenv hands a real USB controller to a VM only for a test
  marked `hw=True` or with `--force-usb` (`plugin.py`, `_vm_impl`); no
  PipeWire test sets either, and the runner never passes the option.
- The container gets `/dev/kvm` and no other device: no `/dev/bus/usb`,
  not privileged ([`ci/bluez-tests.sh`](ci/bluez-tests.sh)).

## How to run

```
docker build -t co36-pw-ci:f44 contributions/CO-36-pipewire-hfp-volume-resend-after-release/homework/ci
contributions/CO-36-pipewire-hfp-volume-resend-after-release/homework/ci/bluez-tests.sh <pipewire tree> <build dir name> [pytest args]
```

The runner mounts [`tests/test_co36_hfp_volume_resend.py`](tests/test_co36_hfp_volume_resend.py)
into the tree's `test/bluezenv/`, next to PipeWire's `test_streaming.py`,
and the tests append what they saw to `<tree>/<build dir name>-co36-results.jsonl`.

## The tests

All three use the existing `a2dp_hfp_ag_host` / `a2dp_hfp_hf_host`
pair: host0 is the AG, host1 the HF, both PipeWire. PipeWire's HF reports
`AT+VGS`/`AT+VGM` when the SLC comes up, so the AG has both gains active
and sends `+VGS`/`+VGM` on every link. Every time is taken from host0's
own WirePlumber log, one clock.

- `test_co36_short_link`: the AG ends the link within 1.5 s by switching
  the profile to A2DP (`spa_bt_device_release_transports()`, released at
  once; a stopped stream would hold the transport 1 s longer). Fails if
  `+VGM` leaves after `sco_release_cb()`.
- `test_co36_remote_hangup`: host1 sends HCI Disconnect (reason 0x13) for
  its SCO/eSCO handle; RFCOMM stays up. The AG sees a hang-up in
  `sco_event()`, not a release. Fails if `+VGM` leaves after it.
- `test_co36_long_link`: the control. The link lasts 4 s; the resend
  must leave while it is up, and nothing after it ends.
- `test_co36_short_link_msbc`: the short link on the mSBC profile.
- `test_co36_stream_stop`: the stream ends at once, the profile stays;
  waits for the actual release.
- `test_co36_reacquire`: a second link right after the first; nothing may
  leave between them, and the second link gets its own resend.

The two short tests skip, never pass, when the link did not end before
1.5 s, when no immediate `+VGS`/`+VGM` was sent (hardware gain inactive),
or, for the hang-up, when a new link re-armed the timer before the
deadline. The assertion is on `+VGM` only; `+VGS` is recorded for every
run, since whether a late `+VGS` is wanted is the open question.

## Phase 0: unmodified master

Runs of 2026-10-31, build `build-v0-asan`. pytest reruns a failure once,
so each failing test ran twice.

Run 1: PipeWire's two HFP tests and the short and long link. Run 2: the
three CO-36 tests. Run 3: the whole `test/bluezenv` suite, as CI runs it.

| Test | Link ended (ms after `acquire complete`) | `+VGS`/`+VGM` after the link ended | Result |
|---|---|---|---|
| short link | 631, 530 (run 1); 595, 703 (run 2); 492, 876 (run 3) | both, at 1501–1505 ms, every time | FAILED, all runs |
| remote hang-up | 184, 112 (run 2); 287, 406 (run 3) | both, at 1500–1503 ms, every time | FAILED, all runs |
| long link | 4969 (run 1), 4620 (run 2), 4877 (run 3) | none; the resend left at 1502–1503 ms while the link was up | PASSED, all runs |
| PipeWire's own 7 (`test_streaming.py`) | | | PASSED (run 3; `test_pipewire_bap_bcast` on its rerun, a flake its own comment describes) |

Run 3's summary line: `2 failed, 8 passed, 3 rerun in 274.63s (0:04:34)`.

Every link of runs 1–3 was **CVSD**: `pw_set_profile("headset-head-unit")`
matches by prefix and took `headset-head-unit-cvsd`, the first listed
(`RFCOMM << AT+BCS=1` on host0 before each link). The laptop's links were
mSBC; see runs 4–5.

## Phase 0, more cases on master (runs 4–5)

Same build, same master. Each test records the codec the HF confirmed
(`AT+BCS=`; 1 CVSD, 2 mSBC).

| Test | Codec | Link ended | Frames after the link ended | Result |
|---|---|---|---|---|
| short link (run 4) | CVSD | 667, 534 ms | both, 1501–1504 ms | FAILED |
| remote hang-up (run 4) | CVSD | 473, 170 ms | both, 1503 ms | FAILED |
| long link (run 4) | CVSD | 4744 ms | none; resend at 1503 ms while up | PASSED |
| short link, mSBC (run 5; `headset-head-unit-msbc`) | mSBC | 701, 626 ms | both, 1501–1504 ms | FAILED |
| stream stop (run 5): the stream ends, the profile stays | mSBC | **6417 ms** | none; resend at 1504 ms while up | SKIPPED (link not short) |
| new link within 1.5 s (run 4) | CVSD | 539 ms, second link up at 1465 ms | none between the links; second link's resend at 1502 ms while up | PASSED |
| new link (run 5) | CVSD | 766 ms, second link up at **1649 ms** | **both, at 1503 ms, between the links**; second link's resend at 1503 ms while up | SKIPPED (second link after 1.5 s) |

What these add:

- mSBC leaks exactly as CVSD does.
- A stream that just stops does not make a short link: the transport is
  released only after the node is suspended for idling and the generic
  release delay (`bluez5-dbus.c`, `TRANSPORT_RELEASE_TIMEOUT_MSEC` 1000),
  6.4 s here. A short link needs something that ends it at once: a profile
  switch, or the headset hanging up.
- WirePlumber's own switch back to A2DP after recording stops waits 2000 ms
  in 0.4.17 (`policy-bluetooth.lua`, `profile_restore_timeout_msec`) and
  4000 ms in master (`bluetooth.autoswitch-restore-timeout`), so with
  either, a link shorter than 1.5 s means the audio link opened late in the
  hands-free period. Whether that is what happened on the laptop is in its
  journal and not checked here.
- A new link re-arms the one timer, so a resend pending from the old link
  is replaced only if the new link is ready before it fires. If the new
  link comes later than 1.5 s after the old one, the old link's resend
  leaves in the gap between them (run 5), the same leak.
- In the AG configuration, `bluez5.codecs = [ sbc msbc ]` did not stop the
  CVSD profile from being picked (run 4 tried it; the helper is kept,
  unused, in the test file).

The hang-up run, host0's lines (run 2, second attempt):

```
D 12:46:13.653198  spa.bluez5.native ../spa/plugins/bluez5/backend-native.c:2793:sco_ready: transport 0x7d18314dca80: acquire complete, read_mtu=72, write_mtu=72
D 12:46:13.653207  spa.bluez5.native ../spa/plugins/bluez5/backend-native.c:636:rfcomm_send_reply: RFCOMM >> +VGS: 6
D 12:46:13.653216  spa.bluez5.native ../spa/plugins/bluez5/backend-native.c:636:rfcomm_send_reply: RFCOMM >> +VGM: 15
D 12:46:13.764767  spa.bluez5.native ../spa/plugins/bluez5/backend-native.c:2915:sco_event: transport 0x7d18314dca80: SCO socket hangup
D 12:46:15.155803  spa.bluez5.native ../spa/plugins/bluez5/backend-native.c:636:rfcomm_send_reply: RFCOMM >> +VGS: 6
D 12:46:15.155854  spa.bluez5.native ../spa/plugins/bluez5/backend-native.c:636:rfcomm_send_reply: RFCOMM >> +VGM: 15
```

So both paths that end a link, the AG's release and the headset's
hang-up, leave the resend armed on master; a fix in `sco_release_cb()`
alone would not cover the second.

Run 1's `while_active` times in its results file are 500 ms short (they
were counted from the end of the immediate window); fixed before run 2.
The raw log lines in the same file give the true times.

Per-test results, with each link's log lines verbatim:
[`results/phase0/`](results/phase0/). The whole pytest output of each run
(build, both VMs' logs) is kept locally in `tmp/co36/`, not here: it
passes the repository's address scan, but the scan refuses its public
constants (BlueZ experimental-feature and MIDI UUIDs, library versions
read as IPv4 addresses, translation file names read as emails).
