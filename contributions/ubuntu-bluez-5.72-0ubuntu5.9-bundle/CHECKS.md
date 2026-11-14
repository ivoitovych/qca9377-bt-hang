# bluez 5.72-0ubuntu5.9 bundle: checks, 2026-11-14 (UTC)

Work area: `/root/exp/agent-work/lane5-status-stable-20261114/bluez-572-bundle/`. Nothing was filed, sent or installed on the host; every build and test ran in docker containers or QEMU/KVM guests started inside them (`co03-noble-build:1`, `co03-noble-vm:1`, `bluez-action-ci:60348956fc7b`; only `/dev/kvm` was passed in). Scripts: `bin/`; logs: `logs/`; per-run raw files stay beside their scripts (`l2runs/`, `co40/runs/`, `exit/*/`, `btmon-live/out/`, `btmon-replay/out/`). Hashes: `SHA256SUMS`.
Marks: **measured** = a command ran and its log is named; **from source** = read from a file; **inferred** = reasoning from those.

## 1. The base (measured)

`logs/noble-versions.txt` (Launchpad `getPublishedSources`, 2026-11-14 03:12 UTC): the newest bluez source in noble is `5.72-0ubuntu5.8` (Updates 2026-10-21 06:52, Security 2026-10-13 19:55); no `5.72-0ubuntu5.9` or other upload in noble-proposed. Source files from Launchpad (`logs/src-sha256.txt`); byte-identical to the copies the CO-03 work used. `5.72-0ubuntu5.9` is free.

## 2. The ten patches and their order (measured: `logs/apply-series.log`, `logs/fresh-bundle.log`, `bin/dep3-check.py`)

Series (appended after `regression-a2dp-sep-cache.patch`, which ends 5.72-0ubuntu5.8's series):

| # | patch (`debian/patches/`) | bug | origin |
|---|---|---|---|
| 1 | `monitor-Fix-crash-due-to-negative-max_len.patch` | btmon | upstream `fdbfe0018f6f` (5.80) |
| 2 | `monitor-clamp-max_len-in-print_packet.patch` | btmon | upstream `dca0f10fd560` (master) |
| 3 | `adapter-clear-discovery_found-list-before-discovery_cleanup.patch` | U24 | upstream `7e3212fa233e` (5.88) |
| 4 | `media-Unlink-endpoints-from-their-application-on-removal.patch` | U23 | backport of the endpoint half of upstream `7482aceece70` |
| 5 | `media-Fix-sending-Release-twice-to-A2DP-endpoints.patch` | U23 | written for this update (no upstream commit) |
| 6 | `media-Fix-use-after-free-releasing-endpoints-on-adapter-removal.patch` | U23 | written for this update (no upstream commit) |
| 7 | `transport-Add-transport_a2dp_get_stream-helper.patch` | U12 | upstream `3d9900eb754d`, helper part (5.79) |
| 8 | `transport-don-t-disconnect-A2DP-if-canceling-Acquire-with-Release.patch` | U12 | upstream `a14d59725ef3` (5.80), A2DP_OPS hunk by hand |
| 9 | `a2dp-don-t-change-setup-sep-when-it-is-reconfiguring.patch` | U12 | upstream `664a5d3785a1` (5.80) |
| 10 | `a2dp-Fix-connection-error-message.patch` | refused/unknown | upstream `a6ac17f0e393` (5.78) |

- `quilt pop -a; quilt push -a --fuzz=0`: all 44 patches (34 of 5.8 + 10) apply; the new ones with offsets at most 16 lines (the only offsets: patch 1 at -8, 2 at -115, 3 at +16, 10 at -18 lines; 4 to 9 with none). No conflict between any two of the four dossiers' changes. Files touched: `monitor/packet.c` (1, 2), `src/adapter.c` (3), `profiles/audio/media.c` (4, 5, 6: stacked, 5 and 6 need 4), `profiles/audio/transport.c` (7, 8: 8 needs 7), `profiles/audio/a2dp.c` (9, 10).
- `dpkg-source -x` of the new source package (`mk-trees.sh`, `logs/fresh-bundle.log`) applies the series cleanly; `dpkg-buildpackage -S` succeeds (`logs/src-pkg.log`); `deliver/bluez_5.72-0ubuntu5.8_5.72-0ubuntu5.9.debdiff` touches 12 files: `debian/changelog`, `debian/patches/series` and the ten patches.
- DEP-3 (`bin/dep3-check.py`): all ten have Description, Author, Origin, Bug-Ubuntu (placeholders `<LP-U12>`, `<LP-BTMON>`, `<LP-U23>`, `<LP-U24>`, `<LP-REFUSED>`), Last-Update and Applied-Upstream or Forwarded (`no` for the two written-for-this-update patches, `not-needed` for upstream commits).
- The two BT-7 crash fixes of CO-03's five-patch build (`a734b06059cb`, `0bed9886cff3`) are **not** in the bundle: the final CO-03 candidate left them out, and they were never exercised by a test. `patch --dry-run` shows they apply on top of the bundle (`co03-02` with offset 1 line), so adding them is a one-line change to the series; not built, not tested here.
- The changelog trailer and the three written-for-this-update patches' DEP-3 `Author:` name the operator (in the work area a placeholder address; set to his own on copy into the repository, 2026-11-14). The sponsor's upload adds its own signature; the date in the trailer is set at upload.

## 3. Package build and BlueZ's own tests (measured)

Noble container, `DEB_BUILD_OPTIONS=parallel=4 dpkg-buildpackage -b -us -uc` for base and bundle (`logs/pkg-build-*.log`): exit 0 both. The package disables `dh_auto_test` (`debian/rules`: `override_dh_auto_test: # disable`), so BlueZ's unit tests were run as CO-03 did, with `make check` in the built trees (`logs/pkg-check-*.log`): base 30 of 32 pass, bundle 30 of 32 pass, the same two fail on both (`unit/test-mesh-crypto`, `unit/test-vcp`). Compiler warnings: 12 and 12 in the package builds, 1 and 1 in the ASan builds, the same lines (`logs/warnings-diff.txt`; the one difference is which unresolved plugin symbol `dpkg-shlibdeps` names first for `sixaxis.so`, not a compiler warning of the patches). Debs: `deliver/debs/` (bluez, libbluetooth3, bluetooth), hashes in `SHA256SUMS`.

## 4. Each dossier's decisive test, base 5.72-0ubuntu5.8 against the bundle

Same setups as the dossiers; the trees under test were unpacked from the two source packages (`mk-trees.sh`), the builds are `bin/asan-build.sh` (CO-03's configure line, ASan and UBSan) and, for the installed-package run, the `.deb`s themselves.

| claim | dossier count | base | bundle | evidence |
|---|---|---|---|---|
| **U12** trigger T201 to T207 (Release() during a pending Acquire(), against a remote that answers or ignores ABORT, same turn and +87 ms), 10 runs each, ASan builds, QEMU guests, emulated controllers | 0/70 to 70/70 | A2DP lost 70/70, ABORT sent 70/70, later Acquire with media 0/70, Acquire reply "none" 70/70 | A2DP lost 0/70, ABORT 0/70, later Acquire with media 70/70, Acquire reply `org.bluez.Error.Failed` 70/70, 0 sanitizer reports | `l2runs/base-l2rates`, `l2runs/bundle-l2rates` (`bin/l2-summary.py`); pytest 70 failed vs 70 passed |
| U12 whole L2 suite (35 collected, once) | 13 leak tests flip, nothing else changes | 14 failed, 19 passed, 2 skipped | 33 passed, 2 skipped | `l2runs/base-l2*`, `bundle-l2*` (`bin/l2-compare.py`): the 14 changed outcomes are T201 to T207, T223, T224, T241, T246, T247, T252 and the reconfigure companion R252; no test changed in the other direction; the two skips are the installed-package tests, which need their image |
| U12 L1 harness (transport.c with stubs, ASan/UBSan, 35 tests) | 27 pass 8 fail, then 35/35 | 27 pass, 8 fail (as expected) | 35 pass, 0 fail | `logs/l1-base-58.log`, `logs/l1-bundle.log`; the runner's verify mode accepts both; the base judged against the fixed expectations fails (negative control) |
| U12 installed packages (`.deb`s in Ubuntu 24.04 guests with Noble's PipeWire 1.0.5 and WirePlumber 0.4.17): R300 identity, T201 trigger, T220 normal Acquire/Release control, R310 profile "off" during START | 3 runs each | T201 lost 3/3 (ABORT sent, A2DP lost at 1.8 to 2.6 s); R310 lost 3/3 (2.8 to 3.8 s); R300 and T220 pass | R300 and T220 pass 3/3, T201 passes 3/3 (no ABORT, A2DP kept, later Acquire with media); R310: 12 runs in three batches (3, 3, 6), 7 reached the trigger and in all 7 A2DP was kept; 5 did not reach it ("no Release while REQUESTING") and count neither way. The running `bluetoothd` is the packaged file (R300: md5 equals dpkg's) | `l2runs/inst-stock`, `inst-bundle`, `inst-bundle-r310`, `inst-bundle-r310b` |
| **CO-40** refused instead of unknown (host0 asks a peer that answers Authentication Complete 0x05, ACL held open): `br-connection-refused` vs `-unknown` | 10/10, 10/10; control (no ACL) 5/5 unknown on both | `br-connection-unknown` 10/10; control `unknown` 5/5 | `br-connection-refused` 10/10 (all with "Connection refused (111)" in the AVDTP log); control `unknown` 5/5 | `co40/runs/*` (`bin/co40-summary.py`) |
| **U23** bluetoothd exit with an acquired A2DP transport, ten runs, CO-37's harness (master's functional tests driving the 5.72 bluetoothd, ASan) | 10/10 fail, then 0/10 | 10/10 fail, 3 ASan reports each, first `heap-use-after-free profiles/audio/media.c:300 in clear_endpoint` | 0/10, 0 reports | `exit/e572base/exit-rate*`, `exit/e572bundle/exit-rate*` |
| **U24** bluetoothd exit while discovering, ten runs | 10/10 fail, then 0/10 | 10/10 fail, first `heap-use-after-free src/device.c:6167 in device_set_rssi_with_delta` | 0/10, 0 reports | `exit/e572base/disc-rate*`, `exit/e572bundle/disc-rate*` |
| **btmon** replay of the two captures, 3 option sets, widths 10, 40, 60, 79, 80, 81, 82, 100, 200, 3000, 5000 and piped (72 cells) | stock aborts, patched never | exit 134 ("buffer overflow detected") in 32 of 72 cells: widths 10, 40, 60, 79, 80, 3000, 5000 and piped | exit 0 in all 72 cells | `btmon-replay/out/results.tsv` (`bin/replay-summary.py`) |
| btmon, nothing else changed | 16 of 18 identical, 2 differ | where both exit 0 (40 cells): 38 byte-identical; 2 differ: `priv-open`, `-T`, 81 and 82 columns (the privileged Open label) | | same |
| btmon live (pty on the monitor socket of a guest with an emulated controller, `comm[pid]` prefix), scenarios "real" and "long", widths 60, 80, 100, 120, 200, piped, 5 runs per cell | stock aborts, both fixes 0 | 134 x5 in the cells "long" at 60, 80 and piped and "real" at 60: 20 aborts in 60 runs (the other cells 0) | 0 aborts in 60 runs | `btmon-live/out/live-bundle/results.tsv` (`scripts/summarize.py`) |

Nothing else changed: the BlueZ unit tests, warnings, the whole L2 suite and the btmon matrix show no difference outside the stated ones.

## 5. Things that did not go as planned (kept for the record)

- The first source-package attempt ran in the build tree and stopped on generated files (`obexd/src/org.bluez.obex.service`); the clean tree afterwards had no `config.h` and no `configure` helpers, so the L1 harness, the ASan builds and the btmon live job were redone from trees unpacked from the finished source packages. Both L1 runs and all later tests used those.
- The first btmon live job failed in seconds (the bundle's `btmon` had been removed by that clean); it was rerun with the binaries saved by the replay step (`btmon-replay/inputs.sha256`).
- The first R310 run on the bundle had one of three runs without the trigger ("no Release while REQUESTING (run does not test U12)"): PipeWire's timing did not always land the profile switch during START. These runs do not count either way; see section 4 for the counts of valid runs.

## 6. Not done / limits

- Emulated controllers and a modelled headset; no real headset, no laptop, nothing installed on the host. The packaged binaries were exercised for U12 only (installed images); U23, U24 and CO-40 ran on ASan builds of the same source, btmon on binaries built by `dpkg-buildpackage`.
- U23 and U24 use the master functional harness with master's tools driving the 5.72 bluetoothd (as CO-37 did); the exit reports are ASan-only, there is no non-sanitizer symptom to count.
- No test of the bundle on 5.72's own `make check` beyond the unit suite; no PipeWire/WirePlumber test of U23 or CO-40.
- The BT-7 patches are not in the bundle and were not built.
- The three newer Ubuntu series (26.04, 26.10, 27.04) were not touched: btmon has debdiffs from 2026-11-02, the others have none (BUNDLE.md, open points).
- No `lintian`, no autopkgtest, no sbuild/PPA build.
