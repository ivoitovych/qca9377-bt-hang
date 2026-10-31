# CO-36 test plan: what a fix must keep, and what it must change

Goal: before any fix variant is judged, a test suite that describes
today's behaviour of the HFP/HSP audio-gateway volume code, run on
unmodified master, so that each variant is judged by the **difference**
it makes: the leak gone, nothing else changed.

Each test has an ID, its layer, what it checks, and what master does
today (**leak** = the expected failure the fix must turn into a pass;
**keep** = must pass before and after). "Status" is `done` (written and
run on master), `todo`, or `operator` (needs the operator's word: real
headsets on the laptop).

Source lines are master `4cfc4711`, `spa/plugins/bluez5/backend-native.c`
unless another file is named.

## What the code does today (the model the tests check)

- One RFCOMM connection (`struct rfcomm`) per headset; it outlives any
  number of audio links. `rfcomm->transport` is the HFP/HSP transport;
  it is replaced on every codec selection (`AT+BCS=` → `rfcomm_new_transport()`,
  L1233–1264) and freed with the RFCOMM connection (`rfcomm_free()`, L483).
- An audio link starts in `sco_ready()` (L2725): the AG sends `+VGS` and
  `+VGM` at once (L2811) and arms one per-RFCOMM timer for 1.5 s
  (L2812, `volume_sync_start_timer()`, L3259).
- The timer is stopped only on `AT+BCS=` (L1241) and when it fires
  (L3251); destroyed in `rfcomm_free()` (L499). It fires if
  `rfcomm->transport` is non-NULL, whatever the link's state (L3253).
- A link ends three ways: the AG releases it (`sco_release_cb()`, L2881,
  called at once on a profile switch or after the generic 1 s delay,
  `bluez5-dbus.c` L3672), the headset or the radio drops it (`sco_event()`
  HUP/ERR, L2907), or the RFCOMM connection goes (`rfcomm_free()`).
- `rfcomm_ag_set_volume()` (L3124) sends a gain only when hardware volume
  is on for the profile, the remote is a headset, it advertised remote
  volume control (HFP) and **has itself reported that gain** (`volumes[id].active`,
  set in `rfcomm_emit_volume_changed()`, L687). It also serves user volume
  changes (`sco_set_volume_cb()`, L3157), with or without a link.

## Invariants a fix must hold

- **I1** No `+VGS`/`+VGM` from a link's delayed resend after that link
  ended (variant V4 relaxes this to `+VGM` only).
- **I2** A link that lasts past 1.5 s gets exactly one resend of each
  active gain, while it is up.
- **I3** Every link start sends each active gain once, at once.
- **I4** A user volume change reaches the headset with or without an
  audio link, exactly as today.
- **I5** Gains the headset reports (`AT+VGS=`/`AT+VGM=`) are taken as today.
- **I6** Codec selection, profile switching and A2DP/BAP are unchanged.
- **I7** Nothing is sent in roles and profiles that send nothing today
  (HF role, hardware volume off, no remote volume control).
- **I8** No crash, sanitizer report, leaked timer or descriptor, whatever
  the order of link end, RFCOMM end and timer.

## Layers

| Layer | What it runs | Time control | Where |
|---|---|---|---|
| L0 build and existing tests | compile matrix, PipeWire's own unit tests (`meson test`), PipeWire's own VM tests | — | CI image |
| L1 unit | `backend-native.c` compiled into a harness with a fake loop whose timers we fire by hand, a socketpair as RFCOMM, a fake transport layer | **virtual**: exact ms, no jitter | CI image, our harness |
| L2 integration | two VMs (pytest-bluezenv, emulated controllers), PipeWire AG and HF | real clock, timing measured from logs | CI image + KVM |
| L3 application | WirePlumber's own policy (autoswitch, restore) driving the links, capture streams like a call app | real clock | VMs; real headsets on the laptop only on the operator's word |

L1 is the only layer that can place an event at 1499 ms and at 1501 ms
on purpose; L2 shows the real stack; L3 shows what a user meets.

## L0: build and existing tests

- T001 Build master with CI's `bluez_tests` options (ASan, UBSan). done; keep
- T002 Build each variant with the same options, no new warnings. todo
- T003 Build each variant with clang (`-Werror` where CI uses it). todo
- T004 Build with `-Dbluez5-backend-hfp-native=disabled` and with `-Dbluez5-backend-hsp-native=disabled` (the timer code sits partly under `HAVE_BLUEZ_5_BACKEND_HFP_NATIVE`; a variant must build in both). todo
- T005 PipeWire's `meson test` unit suite (CI's `build_on_fedora` options) on master. done (co36): 74 of 74 OK; none of them runs `backend-native.c`; keep
- T006 The same on each variant. todo; keep
- T007 PipeWire's 7 VM tests on master. done (run 3): pass; keep
- T008 The same on each variant, 3 runs each (flake rate, not one run). todo; keep
- T009 Each variant backported to `1.0.5`, builds (the laptop's version, Ubuntu's SRU path). todo
- T010 Diff size and touched functions per variant, for review cost. todo

## L1: unit (virtual time)

Harness: `backend-native.c` included into a test program; a fake
`spa_loop_utils` whose `add_timer`/`update_timer` record the deadline and
whose clock the test advances; RFCOMM is one end of a socketpair, the
test reads what the AG writes; the SCO socket is a socketpair end too;
`spa_bt_transport_*`, `spa_bt_device_*` and telephony calls are stubs
that record calls. Status of the whole layer: todo.

Link start and the immediate send:
- T101 Link ready, both gains active: `+VGS`, `+VGM` written at t=0, in that order. keep
- T102 Only speaker gain active: only `+VGS` at t=0. keep
- T103 No gain active: nothing written at t=0. keep
- T104 Hardware volume off for the profile: nothing written. keep
- T105 Remote did not advertise volume control: nothing written. keep
- T106 HSP headset: `+VGS=`/`+VGM=` (HSP format) instead of `+VGS: `. keep
- T107 Link ready with an error (`td->err`): no send, no timer. keep
- T108 `sco_ready()` called again with `requesting` false (the HUP path's call): no send, no timer. keep

The resend on a long link:
- T110 Link up, advance to 1499 ms: nothing more. keep
- T111 Advance to 1500 ms: `+VGS`, `+VGM` once each. keep
- T112 Advance to 10 s: nothing more (one-shot). keep
- T113 Gain changed by the user at 1000 ms: the resend at 1500 ms carries the new value. keep
- T114 Headset reports a new gain at 1000 ms: the resend carries it. keep

The leak, the AG's release:
- T120 Release at 100 ms, advance to 1500 ms: master writes `+VGS`, `+VGM`. leak
- T121 Release at 1499 ms: master writes both at 1500 ms. leak
- T122 Release at 1500 ms exactly, after the timer: one resend, before the release. keep
- T123 Release at 1501 ms: resend at 1500 ms while up, nothing after. keep
- T124 Release at 0 ms (same loop iteration as ready). leak

The leak, the headset's hang-up (`sco_event()` HUP):
- T130 HUP at 100 ms: master writes both at 1500 ms. leak
- T131 HUP at 1499 ms. leak
- T132 ERR instead of HUP at 100 ms. leak
- T133 HUP then the AG's release at 200 ms (both paths, one link). leak

The RFCOMM connection ends:
- T140 RFCOMM closed at 100 ms: timer destroyed, nothing written, no use after free (ASan). keep
- T141 RFCOMM closed at 1499 ms. keep
- T142 Transport freed (device profile disconnected) at 100 ms, RFCOMM kept: `rfcomm->transport` NULL, nothing written at 1500 ms. keep

A new link before the deadline:
- T150 Link 1 at 0, released at 100, link 2 ready at 1000: one resend at 2500 (link 2's), none at 1500. keep
- T151 Link 2 ready at 1600: master sends link 1's resend at 1500 into the gap. leak
- T152 Link 2 ready at exactly 1500 (same loop turn as the timer). record which wins
- T153 Link 2 ready at 1000 and released at 1100: master sends link 2's resend at 2500 after it ended. leak
- T154 Ten links of 100 ms, 200 ms apart: master sends one resend after the last. leak

Codec selection:
- T160 `AT+BCS=` at 100 ms while a link is up: timer stopped, nothing at 1500. keep
- T161 `AT+BCS=` at 100 ms after the link ended: timer stopped, nothing at 1500. keep
- T162 `AT+BCS=` replaces the transport: the old transport's link state does not leak into the new one. keep
- T163 Codec switch failure (unsupported codec): timer stopped, as today. keep

User volume changes (`sco_set_volume_cb()`):
- T170 No link, user changes speaker volume: `+VGS` written at once. keep
- T171 No link, user changes microphone volume: `+VGM` written at once. keep
- T172 Link up: change written at once. keep
- T173 Link ended 100 ms ago, resend pending: the user's change written at once. keep
- T174 Same value as the stored one: nothing written. keep
- T175 Gain not active: `-ENOTSUP`, nothing written. keep

Headset reports:
- T180 `AT+VGS=7` with no link: gain stored, marked active, `OK`. keep
- T181 `AT+VGM=7` with no link. keep
- T182 Report during a link, then the resend: carries the reported value. keep
- T183 Out-of-range report (16, -1): handled as today. keep

Variant-specific expectations (filled per variant once chosen):
- T190 V1 (stop in `sco_release_cb()` only): T120–T124 pass, T130–T133 still leak. expected
- T191 V2/V3 (no late frames): all leak tests pass; every keep test unchanged. expected
- T192 V4 (no late `+VGM`): late `+VGS` remains in T120–T154; `+VGM` gone. expected
- T193 Every variant: T113, T170–T175 unchanged (user volume path untouched). expected

## L2: integration (two VMs)

Existing, run on master (`tests/test_co36_hfp_volume_resend.py`):
- T201 Short link, CVSD, AG releases by profile switch. done: leak
- T202 Short link, mSBC. done: leak
- T203 Headset hangs up SCO (HCI Disconnect from the HF VM), RFCOMM kept. done: leak
- T204 Long link, CVSD: resend while up, nothing after. done: keep
- T205 Stream stop, profile kept: link ends after ~6.4 s, resend while up. done: keep (records the delay)
- T206 Second link within 1.5 s. done: keep when the second link is in time; leak when it is late (run 5)

To add:
- T210 Short link, LC3-SWB (the plain `headset-head-unit` profile with every codec on). todo
- T211 Long link, mSBC. todo; keep
- T212 Long link, LC3-SWB. done (co36): keep, pass
- T213 Remote hang-up, mSBC. todo
- T214 Remote hang-up at 1.4 s (close to the deadline). done (co36): leak, 4 of 4 hang-ups at 1158–1499 ms; the late pair left 7–344 ms after the hang-up
- T215 AG release by `pw-cli` node suspend instead of a profile switch. done (co36, `t215` and `t215f`): the release comes 1 s after the suspend (`TRANSPORT_RELEASE_TIMEOUT_MSEC`); 3 of 9 links ended before 1.5 s (1344, 1399, 1443 ms) and all 3 leaked; the 6 longer ones (1610–3881 ms) were clean
- T216 Link released by turning the device's profile "off". done (co36): leak, 6 of 6 links under 1.5 s
- T217 RFCOMM dropped by the headset (`bluetoothctl disconnect` on the HF) within 1.5 s: no frame, no crash (ASan). todo; keep
- T218 AG disconnects the device within 1.5 s. todo; keep
- T219 bluetoothd restart on the AG within 1.5 s (`BluetoothdWithRestart`). done (co36): keep, pass (transport destroyed, nothing written)
- T220 Codec switch (msbc → cvsd profile) within 1.5 s of link up: the BCS stop, no late frame on master. todo; keep
- T221 Codec switch after a short link ended, before 1.5 s. done (co36): keep, pass 5 of 5 (`AT+BCS=1` at 915–1414 ms stopped the timer)
- T222 Ten short links in a row: count of late frames per link. todo
- T223 Link durations swept: 100, 300, 600, 900, 1200, 1400, 1600, 2000 ms (sleep then switch; actual duration from the log). todo
- T224 Each short-link test 10 times: leak rate (expect 10/10 on master). done (co36): see results; every link that ended before 1.5 s leaked
- T225 User volume change (`pw-cli` on the HFP node) with no link: `+VGS` reaches the HF, the HF's PipeWire applies it. done (co36, as `t225r`, through the device's Route param): keep, pass
- T226 User volume change during a link. done (co36, in `t225r`): keep, pass
- T227 User volume change right after a short link (resend pending): sent at once. done (co36, as `t227r`, Route param, link ended by the headset): keep, pass 6 of 6
- T228 HF changes its volume (`AT+VGS=`) after a short link: the AG takes it. done (co36, as `t228r` and `t228w`, through the HF's telephony D-Bus service): keep, pass
- T229 HSP: AG `hsp_ag`, HS `hsp_hs`, short link: master leaks `+VGS=` too? todo
- T230 HSP long link: resend while up. blocked (co36): the HSP device offers only "off" on master (see results)
- T231 PipeWire as HF (roles swapped): the HF sends no `+VGS`/`+VGM` ever (it sends `AT+` commands). todo; keep
- T232 AG with hardware volume off (`bluez5.hw-volume` without the HFP profile): nothing sent on any link. done (co36, as `t232p`): keep, pass.  Run p0-6's T232 set `bluez5.enable-hw-volume = false`, which is T239's switch
- T233 HF's received gains: the HF PipeWire logs each `+VGS`/`+VGM` it gets; count matches what the AG sent (no loss, no duplicates). done (co36): 150 of 150 single-headset test runs, same frames and values in the same order on both sides, late frames included
- T234 Two headsets (three VMs), short link on one, long on the other: timers independent. blocked (co36): in pytest-bluezenv's emulated controllers the AG kept only one ACL link at a time (the first headset dropped the moment the second connected; HFP to the second then timed out, -110), 3 attempts; independence rests on source (one timer per `struct rfcomm`, L206)
- T235 A2DP streaming after a short HFP link: unaffected (`test_pipewire_a2dp` style check after T201). todo; keep
- T236 Every L2 test with UBSan/ASan reports scanned: none. done (co36): none from PipeWire or WirePlumber in any run; one from bluetoothd (BlueZ `ebbb4ee31ad7`, heap-use-after-free in `media_endpoint_remove`, `profiles/audio/media.c:312`, at shutdown), 1 of about 150 AG shutdowns, not CO-36's code
- T237 Time from link end to the late frame on master: always resend deadline minus link duration (proves the timer, not chance). done (runs 1–5)
- T238 Headset without the `hw-volume-mic` feature (a `bluez5.features.device` rule, `bluez-hardware.conf`): its `AT+VGM=` is ignored (`broken_mic_hw_volume`, L733/L1387), so `+VGM` is never active and never sent, on any link. done (co36): keep, pass; the short link's late `+VGS` still leaves (variant V5's expected result)
- T239 Hardware volume off through `bluez5.enable-hw-volume = false` (`quirks.c` L230): nothing sent (same check as T232, the other switch). done (co36): keep, pass

## L3: application (WirePlumber policy)

In the VMs:
- T301 Capture stream (`pw-record`) on the AG's Bluetooth loopback source with autoswitch on: switch to HFP, link up. todo; keep
- T302 Stop the capture: profile restored after `bluetooth.autoswitch-restore-timeout` (4000 ms on master); link length and late frames recorded. todo
- T303 Capture started and stopped within 500 ms (before the switch delay): no link or a short one; record. todo
- T304 Capture stopped, restarted within the restore timeout: no restore, one link. todo; keep
- T305 Restore timeout set to 0 (a user setting): short links, late frames on master. todo
- T306 A call app's pattern: playback and capture together, end together. done (co36): restore 4 s, 6 links 5905–6092 ms, clean; restore 0, 6 links 1837–2089 ms, clean; the 0.8 s calls made no link (12 of 12)
- T307 Several short captures in a row (an app probing the microphone). done (co36, 1.0–2.0 s captures, 6 runs each): restore 4 s, one 10.9–12.6 s link per run, clean; restore 0, 24 links of 60–1197 ms, **24 of 24 leak**
- T308 WirePlumber 0.4.17's policy in the VM, if it builds against master (the laptop's policy): restore after 2000 ms. done (co36): 0.4.17 does not build against master with CI's flags (one `-Wincompatible-pointer-types` error, `wp/node.c:634`); built with that error demoted to a warning, its policy made 8 links in 5 runs, 2134–4614 ms, all clean

On the laptop, only on the operator's word, in short windows, each
recorded against the open trial:
- T320 MOMENTUM 4, master-equivalent 1.0.5 (as installed): reproduce "mute on" with a short link. operator
- T321 MOMENTUM 4, each variant: "mute on" heard or not; late frames in the HCI capture. operator
- T322 MOMENTUM 4, V4 against V2: which late frame triggers "mute on" (`+VGM` alone, or `+VGS`). operator
- T323 GM2 pro, the same. operator
- T324 Long call (minutes): volume steps on the headset stay in sync, each variant. operator
- T325 User changes volume in GNOME during A2DP after a call: headset follows, each variant. operator
- T326 Headset volume buttons after a short link: GNOME follows, each variant. operator

## Consistency across variants

Variants, for reference (the operator chooses which are built):
V0 master; V1 stop the timer in `sco_release_cb()` only; V2 the timer
handler sends nothing unless the transport's link is active; V3 stop the
timer wherever a link ends (`sco_release_cb()`, `sco_destroy_cb()`,
`sco_event()` HUP/ERR); V4 the late resend sends `+VGS` only; V5 no code
change: a `hw-volume-mic` device quirk for the affected headset (data,
not code; removes `+VGM` for that headset always, also during calls).

- T401 One results table: every test above × V0–V4, expected vs observed. todo
- T402 For each variant, the set of changed outcomes equals its intended set (I1 or I1-for-`+VGM`), nothing else. todo
- T403 The same test file runs unchanged on every variant (no per-variant test edits). todo
- T404 L1 and L2 agree on every case both can run (T120 ↔ T201, T130 ↔ T203, T151 ↔ T206 late). todo

## Results on master (2026-10-31)

Master `4cfc4711`, unmodified. **As planned** = leak tests fail and keep
tests pass; any other outcome is listed.

L1 (`unit/`, 49 tests incl. 4 extras, results in `unit/README.md` and
`results/phase0/unit-run-master.log`): all as planned; 34 PASS, 15 FAIL.
No sanitizer report, nothing left over after any test. Extras: CVSD
without codec negotiation and HSP leak as mSBC does.

L2/L3 (`tests/test_co36_hfp_volume_resend.py`, runs p0-1 to p0-8,
`results/phase0/run-p0-*-results.jsonl`):

| Test | Master | Note |
|---|---|---|
| T201 short link, CVSD | leak, 8 of 8 attempts | late frames at 1500–1505 ms |
| T202 short link, mSBC | leak, 2 of 2 | |
| T210 short link, LC3-SWB | leak, 4 of 4 | HF received the late pair (`hf_received`) |
| T203 / T213 headset hang-up, CVSD / mSBC | leak, 6 of 6 / 2 of 2 | `sco_event()` path |
| T204 / T211 long link, CVSD / mSBC | keep: pass | resend at ~1502 ms while up |
| T205 stream stop | keep: pass | link ends at 6.4 s |
| T206 second link | pass when in time (1465 ms); leak in the gap when late (1649 ms) | timing, as L1 T150/T151 |
| T217 headset drops the connection | keep: pass | no frame, no crash |
| T218 AG drops the connection | keep: pass | ended at 64 ms; timer freed with RFCOMM |
| T220 codec switch within 1.5 s | keep: pass | `AT+BCS=` stops the timer |
| T222/T223 13 links of set length, 2 attempts | 8 links under 1.5 s: each leaks both frames; 5 over (1528–2640 ms): all clean; same in both attempts | boundary at the 1.5 s deadline, not chance |
| T229 HSP | blocked | the VM's HSP device offers only `off`; L1 T120h/T130h cover HSP; cause found in part 2 (T230) |
| T232 hardware volume off | keep: pass | `hw-volume-profiles:00000000`, nothing sent. **Correction (part 2):** this run set `bluez5.enable-hw-volume = false`, which is T239's switch; T232 as planned is `t232p` below |
| T235 A2DP after a short link | keep: pass | |
| T225/T227 user volume | method invalid (superseded by part 2: `t225r`, `t227r`) | node `Props` never reach hardware volume; L1 T170–T175 cover it |
| T228 headset changes its volume | method invalid (superseded by part 2: `t228r`, `t228w`) | no HF node at that point |
| T231 HF sends no AG frames | keep: pass, every L2 test | `hf_sent_ag_frames` 0 throughout |
| T301/T302/T304 capture through the policy | keep: pass | one 9.5 s link, resend while up |
| T303/T307 0.2–0.6 s captures | no link at all | the policy's 500 ms switch delay |
| T305 restore timeout 0 | **leak, 2 of 2** | the policy itself ended the link at 48–54 ms |

### Part 2 (agent-work/co36, 2026-10-31 22:50:06 to 23:50:12 CET)

Same master, same image, same build options; `--reruns 0`, so every
attempt is one record; `CO36_REPEAT=n` gives n runs on fresh VMs.
"In window" = the link ended before 1.5 s and no new link came before
the deadline; runs outside it are counted apart, never as passes.
Evidence paths are under `agent-work/co36/`; per-run lines in
`results/summary-all.txt`, ranges in `results/ranges-all.txt`.

| Test | Class | Master | Rate | Evidence |
|---|---|---|---|---|
| T005 `meson test`, CI `build_on_fedora` options | keep | pass | 74 of 74 OK; none runs `backend-native.c` | `logs/t005-meson-test.log`, `results/t005-testlog.txt` |
| T201 short link, CVSD (T224) | leak | leak | 10 of 10; links 452–908 ms, late `+VGM` 1501–1504 ms | `results/r05-t224-x10-results.jsonl` |
| T202 short link, mSBC (T224) | leak | leak | 10 of 10; links 468–900 ms | same |
| T203 hang-up, CVSD (T224) | leak | leak | 10 of 10; links 97–743 ms | same |
| T210 short link, LC3-SWB (T224) | leak | leak | 9 of 9 in window; 1 run ended at 1832 ms, resend while up, clean | same |
| T213 hang-up, mSBC (T224) | leak | leak | 10 of 10; links 193–532 ms | same |
| T212 long link, LC3-SWB | keep | pass | 5 of 5; resend at 1500.5–1502.0 ms while up (links 4573–5904 ms) | `results/r01-*`, `r02-*`, `r09-*` |
| T214 hang-up near the deadline | leak | leak | 4 of 4 in window (hang-up at 1158, 1355, 1424, 1499 ms; late pair 7–345 ms after it); 2 hang-ups at 1579/1586 ms: resend while up, clean | `results/r02-*`, `r04-*` |
| T215 suspend instead of a profile switch (`t215`, `t215f`) | leak when short | leak | release comes 1 s after the suspend; 3 of 9 links ended before 1.5 s (1344, 1399, 1443 ms): 3 of 3 leak; 6 longer (1610–3881 ms): clean | `results/r02-*`, `r04-*`, `r09-*` |
| T216 profile "off" | leak | leak | 6 of 6 in window (474–784 ms); 1 at 1606 ms clean | `results/r01-*`, `r02-*`, `r04-*` |
| T219 bluetoothd restart on the AG within 1.5 s | keep | pass | 4 of 4; transport destroyed 64–439 ms after link up, nothing written after, PipeWire alive | `results/r02-*`, `r09-*` |
| T221 codec switch after a short link | keep | pass | 5 of 5 in window (`AT+BCS=1` at 915–1414 ms); 1 run outside (link 1639 ms; the test failed on it, design fixed, see RESULTS.md) | `results/r02-*`, `r04-*` |
| T225/T226 user volume through the Route param (`t225r`) | keep | pass | 5 of 5: no link `+VGS: 10` and `+VGM: 10`, during a link `+VGS: 13`, each 0.0–0.3 ms after `node_set_volume`; the HF took every value | `results/r01-*`, `r02-*`, `r09-*` |
| T227 user change while the resend is pending (`t227r`) | keep | pass | 6 of 6 in window (change at 734–1443 ms): `+VGS: 10` 0.1 ms after the change; the late resend that follows carries 10 | `results/r02-*`, `r04-*` |
| T228 headset changes its gain (`t228r`, `t228w`) | keep | pass | 9 of 9: `AT+VGS=9` taken, `OK`, stored; 8 in window: the late `+VGS` carries 9 | `results/r02-*`, `r04-*`, `r09-*` |
| T230 HSP long link | keep | blocked | HSP connected (profiles `00000020`) but the device offers only `off` | `results/r02-all-once-results.jsonl` (`t230_hsp_long`) |
| T232 `bluez5.hw-volume = [ a2dp_sink ]` (`t232p`) | keep | pass | 4 of 4: `hw-volume-profiles:00000004`, no `+VGS`/`+VGM` on a short or a long link | `results/r02-*`, `r09-*` |
| T233 HF received what the AG sent | keep | pass | 150 of 150 single-headset runs: identical sequences with values | `results/summary-all.txt` (ledger) |
| T234 two headsets | — | blocked | the emulated AG kept one ACL at a time (3 attempts) | `results/r02-*`, `r07-*`, `r07b-*` |
| T236 sanitizer scan | keep | pass for PipeWire | 0 reports from PipeWire/WirePlumber; 1 bluetoothd heap-use-after-free at shutdown (BlueZ, not CO-36) | `results/t236-scan-all.txt` |
| T238 headset without `hw-volume-mic` | keep | pass | 4 of 4: `+VGM` never sent; `+VGS` sent as usual, **including late after a short link** | `results/r02-*`, `r09-*` |
| T239 `bluez5.enable-hw-volume = false` | keep | pass | 4 of 4: `hw-volume-profiles:00000000`, nothing sent | `results/r02-*`, `r09-*` |
| T306 call app, restore 4 s / restore 0 | record | clean | 6 + 6 links, 5905–6092 / 1837–2089 ms, all clean; 0.8 s calls: no link | `results/r02-*`, `r08-*` |
| T307 1.0–2.0 s captures, restore 4 s | record | clean | one 10.9–12.6 s link per run, 6 of 6 clean | same |
| T307 1.0–2.0 s captures, restore 0 | record | **leak** | 24 of 24 links (60–1197 ms) leak | same |
| T308 WirePlumber 0.4.17 policy | record | clean | builds only with `-Wno-error=incompatible-pointer-types`; 8 links in 5 runs, 2134–4614 ms, all clean | `logs/t308-build*.log`, `results/r06b-*` |

## Not covered, and why

- Headsets that need the late `+VGS` (the HD-250BT named in the code
  comment): none here. The one question left for the maintainers.
- Other HFP AG implementations (oFono, hsphfpd backends): they do not
  use this timer (`backend-ofono.c`, `backend-hsphfpd.c` have none).
- Kernel and controller behaviour: the VMs' controllers are emulated; the
  laptop's captures cover the real radio.
- HSP as AG (T229, T230): on master an HSP-only headset gets no
  `headset-head-unit` profile in the VMs (log: r02 `t230_hsp_long`,
  profiles `00000020` connected, EnumProfile only `off`).  Inferred from
  source: `backend_native_supports_codec()` looks up the RFCOMM by
  `SPA_BT_PROFILE_HFP_HF` only (`backend-native.c:3205`), so CVSD is
  "not supported" for an HSP connection, and `bluez5-device.c:2430` lists
  no HSP/HFP profile without a codec.  The lookup dates from `5f7afe588`
  (2023-09-24).  L1 T120h/T130h remain the HSP coverage.
- Two headsets (T234): pytest-bluezenv's emulated AG controller dropped
  the first headset's ACL link when the second connected (logs r07,
  r07b), so two simultaneous RFCOMM connections were not reachable.
- WirePlumber 0.4.17 with master (T308): built with one compiler error
  demoted to a warning (not CI's flags); its config is Lua, so the
  harness differs from PipeWire's own (`PipeWire04` in the test file).
