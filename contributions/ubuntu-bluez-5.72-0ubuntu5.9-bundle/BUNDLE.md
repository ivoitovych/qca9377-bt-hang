# One bluez update for Ubuntu 24.04: 5.72-0ubuntu5.9

Everything here is local. Nothing was filed, uploaded or sent; the operator files the five bugs and the upload. The numbers behind each claim are in `CHECKS.md`; the debdiff is `deliver/bluez_5.72-0ubuntu5.8_5.72-0ubuntu5.9.debdiff`.

## What the upload is

`bluez 5.72-0ubuntu5.9` for noble, on top of `5.72-0ubuntu5.8` (still the newest in noble-updates and noble-security; nothing in noble-proposed; Launchpad, 2026-11-14 03:12 UTC). It adds ten quilt patches (DEP-3 headers, in `patches/` and in the debdiff) and one changelog entry that lists each with its Launchpad placeholder. The four dossiers' changes do not conflict: the series applies with `quilt push -a --fuzz=0` and `dpkg-source -x` in the order below, the package builds, BlueZ's unit tests give the same 30 of 32 as before.

| bug (text in `bugs/`) | patches | origin | what it fixes |
|---|---|---|---|
| `<LP-U12>` `01-u12-release-during-pending-acquire.md` | 7, 8, 9 | upstream, BlueZ 5.79 and 5.80 | Release() during a pending A2DP Acquire() aborts the stream and disconnects A2DP (a headset keeps no A2DP after an app opens the microphone) |
| `<LP-BTMON>` `02-btmon-abort-in-print_packet.md` | 1, 2 | upstream, 5.80 and master (in 5.88) | btmon aborts ("buffer overflow detected") at narrow or very wide widths and in a pipe |
| `<LP-U23>` `03-u23-bluetoothd-exit-media-endpoint-uaf.md` | 4, 5, 6 | patch 4 upstream part-backport (7482aceece70); 5 and 6 written for this update, **not upstream** | use-after-free in bluetoothd at exit while a sound server streams over A2DP; second Release sent to A2DP endpoints |
| `<LP-U24>` `04-u24-bluetoothd-exit-discovery-uaf.md` | 3 | upstream `7e3212fa233e`, BlueZ 5.88 | use-after-free in discovery_cleanup() at exit or adapter removal |
| `<LP-REFUSED>` `05-refused-vs-unknown-a2dp-connect-error.md` | 10 | upstream `a6ac17f0e393`, BlueZ 5.78 | a refused A2DP connect is reported as br-connection-unknown instead of br-connection-refused |

The changelog entry (`changelog-entry.txt`) closes the five placeholders; the changelog trailer address is a placeholder to replace before upload.

Series order (patches 1 to 10 after `regression-a2dp-sep-cache.patch`): btmon (1, 2), U24 (3), U23 (4, 5, 6), U12 (7, 8, 9), refused/unknown (10). Dependencies inside the series: 5 and 6 need 4, 8 needs 7; no change depends on another bug's patch.

## Left out on purpose

- The two BT-7 crash fixes of CO-03's five-patch build (`a734b06059cb` adapter, `0bed9886cff3` a2dp, both upstream in 5.88): the final CO-03 candidate left them out, they were never exercised by a test, and no Ubuntu series carries them. They apply on top of the bundle (`patch --dry-run`, one offset of one line); adding them is the operator's call (they would need their own bug and test).
- Newer series: see "SRU order" below.

## What was shown (details and commands: CHECKS.md)

Each decisive test ran on the base `5.72-0ubuntu5.8` and on the bundle, in the dossiers' setups:

- U12: trigger T201 to T207 ten times each: A2DP lost 70/70 on base, 0/70 on the bundle; the same `.deb` installed in a 24.04 guest with Noble's PipeWire 1.0.5 and WirePlumber 0.4.17: T201 lost 3/3 on base, kept 3/3 on the bundle; R310 (profile "off" during START) lost 3/3 on base, kept in all 7 runs that reached the trigger on the bundle; L1 harness 27 pass 8 fail on base, 35/35 on the bundle; the 14 failing L2 tests of the base (13 leak tests and the reconfigure companion) all pass on the bundle and nothing else changes.
- btmon: replay of the two captures at twelve widths and three option sets: base aborts in 32 of 72 cells, the bundle in none; where both run, 38 of 40 cells are byte-identical and the 2 others are the privileged Open label at 81 and 82 columns; live on the monitor socket the base aborts 20 of 60 runs, the bundle 0 of 60.
- U23: bluetoothd exit with an acquired A2DP transport, ten runs: 10/10 ASan failures on base (`media.c:300 in clear_endpoint`), 0/10 on the bundle.
- U24: bluetoothd exit while discovering, ten runs: 10/10 on base (`device.c:6167 in device_set_rssi_with_delta`), 0/10 on the bundle.
- refused/unknown: `br-connection-unknown` 10/10 on base, `br-connection-refused` 10/10 on the bundle; the control without a held ACL is `unknown` 5/5 on both.
- Nothing else changed: 30 of 32 unit tests on both with the same two failures, the same compiler warnings, the same L2 outcomes outside the leak set.

## Test plan for the SRU team (verification in -proposed)

Each bug text has its own [Test Plan]; the short version for the bundle, one session:

1. Install `bluez` and `libbluetooth3` 5.72-0ubuntu5.9 from noble-proposed; check `apt-cache policy bluez` and that the running `/usr/libexec/bluetooth/bluetoothd` belongs to the package.
2. U12: with a Bluetooth headset that offers A2DP and hands-free, on PipeWire 1.0.5 and WirePlumber 0.4.17, start audio playback and open a recording application in the same second, ten times: A2DP must stay (before: lost until the headset reconnects, sometimes). The harness version without hardware (guests with emulated controllers, `tests/l2` of CO-03, T201 and R310) needs the project's test environment and can be handed over on request.
3. btmon: `TZ=UTC btmon --columns=80 -T -r priv-open.btsnoop; echo $?` with the capture from `mkcap.py` (in the btmon bug): 0 and decoded output (before: exit 134), also piped and at 40, 60, 79, 3000 and 5000 columns.
4. refused/unknown: connect to a headset that has dropped the computer's pairing key: the error reads br-connection-refused (before: br-connection-unknown); the emulated test of the bug text shows the same without hardware.
5. U23 and U24 have only a sanitizer symptom: build `5.72-0ubuntu5.9` with `--enable-asan --enable-ubsan` and run the two functional tests of BlueZ's harness (`test_a2dp_exit_with_acquired_transport`, `test_exit_discovering` with the bus variant): no ASan report (before: reports in every run). In a normal build the visible change is that bluetoothd exits cleanly; no user-visible regression is expected.
6. Regression check: pair, connect and play audio with one A2DP headset, switch to hands-free and back, disconnect, restart `bluetooth.service`.

## Open points before filing

1. **SRU order (development release first).** Checked 2026-11-14 (`logs/later-series.txt`, `logs/changelog-*.txt`): tenacious (27.04) now has `5.88-1` (Debian sync, 2026-11-07), which includes `7e3212fa233e` and `dca0f10fd560` (both are ancestors of the upstream 5.88 tag, `gh api .../compare`; the Ubuntu source package was not unpacked), so U24 and the second btmon patch are there. U12 (5.80), the first btmon patch (5.80) and refused/unknown (5.78) were already in every later series. **Not in any later series: U23** (no upstream fix; patches 5 and 6 are ours, patch 4 is the upstream endpoint half), so the SRU team may ask for it in tenacious first, or for an upstream commit.
2. **Resolute and stonking collide with the CO-11a debdiffs.** `5.85-4ubuntu0.5` (resolute) and `5.87-4ubuntu0.1` (stonking), the very version numbers CO-11a proposed for its btmon debdiffs, were uploaded to -proposed on 2026-11-10 for another bug (mpris-proxy segfault, LP #2172906, `mpris-proxy-fix-possible-crash.patch`). The CO-11a debdiffs for those two series must be rebased and renumbered (0.6 and 0.2) on top of the proposed uploads. The tenacious debdiff (`5.87-5ubuntu1`) is obsolete: tenacious is at `5.88-1`. Noble: LP #2172906 has no noble task, so `5.72-0ubuntu5.9` is free.
3. **btmon CVE.** tenacious `5.88-1` lists "Out-of-bounds read vulnerability in the btmon tool, CVE-2026-105460". Whether it affects 5.72 and which commit fixes it was not looked up here; a security update for noble would touch `monitor/` and could conflict with patches 1 and 2.
4. **Two patches without an upstream commit** (5 and 6, `Forwarded: no`); the master version of the series is written and tested but not sent (CO-37: the route is the operator's decision). If upstream takes it first, the Origin lines should change.
5. **Launchpad numbers.** Every `Bug-Ubuntu`, changelog `LP:` and bug text carries a placeholder (`<LP-U12>`, `<LP-BTMON>`, `<LP-U23>`, `<LP-U24>`, `<LP-REFUSED>`); the bug texts reference each other by these. The five bugs need the SRU template's fields as written; the debdiff is one attachment for all five.
6. **Upload email / maintainer field.** The changelog trailer uses a placeholder address so that the package builds; replace it with the uploader's identity.
7. **Limits of the evidence:** emulated controllers and a modelled headset, ASan builds for U23, U24 and refused/unknown, no real headset and nothing installed on the laptop; the laptop test of CO-03/CO-19-style plans stays the operator's.
