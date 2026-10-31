# CO-36: the tests left on master, results

Work area of 2026-10-31.  PipeWire master `4cfc4711`, unmodified;
WirePlumber `4ab992fa` as the subproject (T308: 0.4.17); the homework's
CI image `co36-pw-ci:f44`; VMs from pytest-bluezenv 0.1.9 with emulated
controllers.  Every claim is marked: **log** (with the file), **source**
(`path:line` at `4cfc4711`), or **inferred**.

## Setup and deviations from the homework's runs

- Tree: a copy of `agent-work/co03/pw` (master `4cfc4711`, build
  `build-v0-asan`) into `agent-work/co36/pw`, without co03's core files
  and test mounts (`scripts/copy-tree.sh`).  No PipeWire file changed.
- Runner: `scripts/vmrun.sh` = the homework's `ci/bluez-tests.sh` with
  this area's test file mounted; results go to `results/<run>-results.jsonl`,
  every log record to `results/<run>-pytest-log.txt`, pytest's output to
  `logs/<run>.log` (`ci/bluez-tests-inside.sh`).  Containers get
  `--device /dev/kvm` only; no test uses `hw=True` or `--force-usb`.
- `--reruns 0` on every run (CI and the homework use `--reruns 1`): each
  attempt is one record, so rates count attempts.
- `CO36_REPEAT=n` runs each selected test n times, each on fresh VMs.
- Every test also writes a `ledger` record: every `+VGS`/`+VGM` the AG
  wrote and every one the HF logged as received, with values (T233), and
  any sanitizer line of the setup and call phases (T236).
- Run r01's log file used `--log-file-level DEBUG` and lacks the VMs'
  output (pytest_bluezenv logs it at level OUT = 5); from r02 on, level 1.
- Clock: run times below are the host's (CET); log lines inside the VMs
  are UTC.

## Runs

| Run | What | Outcome file |
|---|---|---|
| T005 | `meson test`, CI `build_on_fedora` options, `build-t005` | `logs/t005-meson-test.log`, `results/t005-testlog.txt` |
| r01-smoke | T212, T216, T225r once | `results/r01-smoke-*` |
| r02-all-once | every new test once | `results/r02-all-once-*` |
| r03…r03d | T308 harness tries (superseded, see T308) | `results/r03*-t308-try-*` |
| r04-timing-x5 | T214, T215f, T216, T221, T227r, T228w ×5 | `results/r04-timing-x5-*` |
| r05-t224-x10 | T201, T202, T203, T210, T213 ×10 | `results/r05-t224-x10-*` |
| r06-t308-x5 | T308 ×5, stopped after 3 (superseded, see T308) | `results/r06-t308-x5-*` |
| r06b-t308-x5 | T308 ×5 | `results/r06b-t308-x5-*` |
| r07, r07b | T234 tries | `results/r07*-t234-try-*` |
| T308 builds | WirePlumber 0.4.17 tree: CI flags; per-subproject flag; global flag | `logs/t308-build.log`, `t308-build-relaxed.log`, `t308-build-relaxed2.log` |
| r08-l3-x5 | T306, T306z, T307, T307z ×5 | `results/r08-l3-x5-*` |
| r09-more-x3 | T212, T215f, T219, T225r, T228r, T232p, T238, T239 ×3 | `results/r09-more-x3-*` |

`progress.log` has each run's start and end.  `results/summary-*.txt`
(`scripts/summarize.py`) and `results/ranges-all.txt` (`scripts/ranges.py`)
are the tables below in long form.

## Per test (master `4cfc4711`)

The full table, with rates and evidence paths, is in `TEST-PLAN.md`,
"Part 2".  In short:

- **Leak confirmed, at every link end tried** (log): AG profile switch
  (T201/T202/T210, 29 of 29 in window), headset hang-up (T203/T213, 20 of
  20; T214 near the deadline, 4 of 4), profile "off" (T216, 6 of 6), node
  suspend when the link is short enough (T215, 3 of 3), the policy with
  restore 0 (T307z, 24 of 24).  Every out-of-window run (link over 1.5 s)
  had its resend while up and nothing after: 12 of 12.
- **The deadline counts from link start, not link end** (log,
  `results/r04-timing-x5-results.jsonl`, T214 rep 2): hang-up at 1499.4 ms,
  late `+VGS`/`+VGM` at 1506.5 ms, 7 ms later.
- **Keep tests pass**: T212, T219, T221, T225/T226, T227, T228, T232, T233,
  T238, T239, T005.
- **Blocked**: T230 (HSP, see below), T234 (two headsets, emulator).
- **T308**: WirePlumber 0.4.17's policy (restore 2000 ms) made no link
  under 2.1 s in 5 runs (8 links, 2134–4614 ms), so no leak.

## Surprises, and what contradicts earlier results

1. **Phase 0's T232 was T239.**  `hw_volume_off_ag_host` in the homework
   file sets `bluez5.enable-hw-volume = false` (the quirk switch, T239),
   not `bluez5.hw-volume` without HFP (T232).  Both now run (`t232p`,
   `t239`); both pass.  (Source: the homework test file, `hw_volume_off_ag_host`.)
2. **HSP is unreachable as AG on master**, not only in the VM setup
   (log + source, inferred cause): with an HSP-only headset connected
   (`profiles 00000020`) the device offers only `off`.
   `backend_native_supports_codec()` finds the RFCOMM by
   `SPA_BT_PROFILE_HFP_HF` only (`spa/plugins/bluez5/backend-native.c:3205`),
   so CVSD is unsupported for HSP, and `bluez5-device.c:2430` drops a
   headset profile without a codec.  The lookup came with `5f7afe588`
   (2023-09-24).  HSP roles are not in PipeWire's default roles; this is
   a separate issue from CO-36.
3. **V5 (a `hw-volume-mic` quirk) does not stop the late `+VGS`** (log,
   T238, 4 of 4): `+VGM` is never sent, but the short link's late `+VGS`
   still leaves at 1501–1503 ms.
4. **What the late resend carries after a change** (log): after a user
   change it carries the new speaker gain (T227, `+VGS: 10`, 6 of 6);
   after the headset's own `AT+VGS=9` it sends 9 back (T228, 8 of 8).
   Inferred: a fix that drops the late resend loses no user or headset
   change, since the change itself already left at once (T227: 0.1 ms
   after `node_set_volume`).
5. **The suspend path adds 1 s** (log + source): a link ended by a node
   suspend is released `TRANSPORT_RELEASE_TIMEOUT_MSEC` (1000 ms,
   `bluez5-dbus.c:283`, applied at `bluez5-dbus.c:3672`) after the suspend,
   so it leaks only when the suspend comes within about 0.5 s of link up.
6. **A call app on restore 0 did not leak, probing captures did** (log):
   the 3 s calls made 1837–2089 ms links (clean), the 0.8 s calls made no
   link at all (r02: profile switched back 84 ms after it switched, before
   any SCO link), while
   1.0–2.0 s captures made 60–1197 ms links that all leaked.  Link length
   ≈ capture length − 0.92 s (inferred from the four holds of T307z).
7. **WirePlumber 0.4.17 against master** (log): does not build with the
   image's GCC (`wp/node.c:634`, `pw_node_send_command()` now takes
   `struct pw_node *`, `src/pipewire/node.h:227`; `-Wincompatible-pointer-types`
   is an error by default).  With that error demoted it builds; its
   policy then (a) picked `a2dp-sink-opus_05_duplex`, a PipeWire-only
   duplex A2DP codec, over HFP until the AG's codecs were limited, and
   (b) failed later captures with "no target node available" because
   `restore-stream.lua` restored a `bluez_input.*` target that does not
   exist in A2DP mode.  Both are harness facts, fixed in the test (see
   design fixes), not CO-36 results.
8. **A BlueZ crash at shutdown** (log, `results/r05-t224-x10-pytest-log.txt`
   line 151478; core `pw/test-bluezenv-hosts7.0-bluetoothd-1793486057-1576.core`,
   kept): AddressSanitizer heap-use-after-free in bluetoothd's
   `media_endpoint_remove` (`profiles/audio/media.c:312`) from
   `a2dp_exit` → `plugin_cleanup` at exit, during the teardown of
   `test_co36_short_link[6]`, BlueZ `ebbb4ee31ad7` (CI's commit).  1 of
   about 150 AG bluetoothd shutdowns.  Not PipeWire, not CO-36; worth its
   own entry.  `agent-work/co03/pw` holds many bluetoothd cores from
   another campaign; whether they are the same fault is not checked.
9. **Every no-link `+VGS` path works**: WirePlumber's route restore sends
   `+VGS: 6` when the HFP profile is selected, before any link (log,
   r01 `logs/r01-smoke.log` line 3110).  That is I4's path, as the plan
   expects; it is the first `VGS:6` in every ledger.

Nothing contradicts phase 0's leak/keep results; the rates are higher
now only because there are more runs.

## Design fixes made after a run (none relabels a result)

| Test | Run | What went wrong | Fix |
|---|---|---|---|
| T214 | r02 | sleep 1.2 s put the hang-up at 1586 ms, past the deadline | sleep 0.95 s from r04 on; out-of-window runs still skip |
| T215 | r02 | stream stop, then node lookup, then suspend one by one: link 3881 ms | `t215f`: node ids found before the link, all suspends at once |
| T221 | r04 rep 4 | the switch ended the link at 1639 ms; an assert made it a failure | skips when the link is not short (it was outside the window) |
| T228 | r02 | link ended at 2070 ms, `AT+VGS=9` at 3388 ms, after the resend | `t228w`: hang-up and gain change in one VM call; `t228r` kept |
| T234 | r02, r07 | one `connect` per headset, then repeated `connect` | HFP UUID named; still blocked (emulator, see TEST-PLAN) |
| T308 | r03 | WirePlumber 0.4.17 exited (logind) | `with-logind = false` |
| T308 | r03b | policy chose `opus_05_duplex`, no HFP link | AG codecs `[ sbc sbc_xq msbc lc3_swb ]` |
| T308 | r03c, r06 | captures failed: restored `bluez_input.*` target | `restore-target = false`; r06 stopped, superseded by r06b |
| T236 | scan | `\.core\b` matched every `pw.core` topic | pattern `test-bluezenv-*.core` |

## L1 and L2 agree (T404, the cases both run)

T120 ↔ T201/T216 (release before 1.5 s: leak); T131 ↔ T214 (hang-up at
1499 ms: leak); T142 ↔ T219 (transport freed: nothing sent); T160/T161 ↔
T221 (`AT+BCS=` stops the timer); T173 ↔ T227 (user change at once,
resend still pending); T114/T182 ↔ T228 (the resend carries the reported
gain).  Sources: `homework/unit/README.md` lines 95–122 and the table above.

## Evidence for the key claims (command, then its output)

Rates and ranges:

```
python3 -I /root/exp/agent-work/co36/scripts/ranges.py <results files of final-tables.sh>
```
output: `results/ranges-all.txt`, e.g.
`t214_hangup_near_deadline: n=6 short=4 leak=4 down=[1158.1..1585.6] lateVGM=[1502.4..1506.5] end_to_late=[7.1..344.7]`
and `t307z_policy_probes_restore_zero:links: n=24 short=24 leak=24 down=[60.3..1197.0] ...`.

The bluetoothd fault:

```
grep -n "host.0.0.bluetoothd     #[0-9]" /root/exp/agent-work/co36/results/r05-t224-x10-pytest-log.txt
```
first lines of output:
```
151544:22:34:17.233 OUT host.0.0.bluetoothd     #0 0x000000426236 in media_endpoint_remove profiles/audio/media.c:312
151545:22:34:17.233 OUT host.0.0.bluetoothd     #1 0x000000463684 in a2dp_unregister_sep profiles/audio/a2dp.c:2838
151546:22:34:17.233 OUT host.0.0.bluetoothd     #2 0x000000479e87 in a2dp_sep_unlock profiles/audio/a2dp.c:3533
151547:22:34:17.233 OUT host.0.0.bluetoothd     #3 0x00000043d43c in transport_a2dp_suspend profiles/audio/transport.c:465
151548:22:34:17.233 OUT host.0.0.bluetoothd     #4 0x000000442b90 in media_transport_free profiles/audio/transport.c:1790
```
(frames #16–#17: `a2dp_exit`, `plugin_cleanup`, i.e. at exit).

WirePlumber 0.4.17's build error:

```
grep -n "error:" /root/exp/agent-work/co36/logs/t308-build.log
```
output:
```
750:../subprojects/wireplumber/lib/wp/node.c:634:25: error: passing argument 1 of ‘pw_node_send_command’ from incompatible pointer type [-Wincompatible-pointer-types]
```
(the same error is line 749 of `t308-build-relaxed.log`, whose per-subproject
flag did not reach the compile line; `t308-build-relaxed2.log` line 749
has it as a warning and the build completes).

HSP offers only "off" (T230):

```
python3 -I -c "import json,sys; [print(json.dumps(json.loads(l)['devices'])) for l in open(sys.argv[1]) if '\"t230_hsp_long\"' in l]" /root/exp/agent-work/co36/results/r02-all-once-results.jsonl
```
output (shortened): `"EnumProfile": ["off"], "Profile": ["off"]`; the AG log in the same
record has `spa_bt_device_check_profiles: device ...: profiles 00000020`
and `Transport /org/bluez/hci0/dev_00_AA_01_01_00_42/fd46 available for profile /Profile/HSPAG`.

## How to rerun

```
/root/exp/agent-work/co36/scripts/copy-tree.sh
/root/exp/agent-work/co36/scripts/run-t005.sh /root/exp/agent-work/co36/logs/t005-meson-test.log
/root/exp/agent-work/co36/scripts/vmrun.sh r04-timing-x5 5 --reruns 0 -k "t214_ or t215f_ or t216_ or t221_ or t227r_ or t228w_"
/root/exp/agent-work/co36/scripts/vmrun.sh r05-t224-x10 10 --reruns 0 -k "test_co36_short_link or test_co36_remote_hangup or t210_ or t213_"
/root/exp/agent-work/co36/scripts/vmrun.sh r08-l3-x5 5 --reruns 0 -k "t306_ or t306z_ or t307_ or t307z_"
/root/exp/agent-work/co36/scripts/vmrun.sh r09-more-x3 3 --reruns 0 -k "t212_ or t219_ or t225r_ or t232p_ or t238_ or t239_ or t215f_ or t228r_"
/root/exp/agent-work/co36/scripts/vmrun.sh r02-all-once 1 --reruns 0 -k "t230_ or t234_"
/root/exp/agent-work/co36/scripts/make-wp0417-tree.sh
/root/exp/agent-work/co36/scripts/build-wp0417-relaxed2.sh /root/exp/agent-work/co36/logs/t308-build-relaxed2.log
/root/exp/agent-work/co36/scripts/vmrun-tree.sh pw-wp0417 build-wp0417-relaxed2-asan r06b-t308-x5 5 --reruns 0 -k t308_
/root/exp/agent-work/co36/scripts/final-tables.sh
```

A new run id writes new files; reusing one appends to its results file.
At most two of these at once (each runs two or three VMs).
