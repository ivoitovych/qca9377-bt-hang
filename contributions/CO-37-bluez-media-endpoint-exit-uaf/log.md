# CO-37 log

Append-only. Newest last.

## 2026-10-31 — found in CO-03's runs
- **ASan at bluetoothd exit**, in the Fedora 44 ASan builds of 5.72 in CO-03's VM tests:
  - `media.c:300 in clear_endpoint`: 3 of 10 runs on base, plus 1 on the fixture's build;
    2 of 10 on the backport.
  - `device.c:6167 in device_set_rssi_with_delta`: twice.
- Registered as U23 and U24.
- **The same night, CO-36 part 2:** one `media.c:312 in media_endpoint_remove` at BlueZ
  `ebbb4ee31ad7`, 1 in about 150 shutdowns.

## 2026-11-01 — reproduced, fixed, backported (VMs only)
- **U23:** present on master `14bd6ab65`.
  - Two fixes and a functional test; 10/10 failing before, 0/10 after.
  - 5.72 reproduces it line for line; its two-patch backport gives 0/10.
  - The `ebbb4ee31ad7` case is the same defect (the read added by `7482aceece70`).
- **U24:** fixed upstream by `7e3212fa233e` (2026-09-04, not released). Master 0/10, and 10/10
  with that commit reverted; 5.72 10/10, and 0/10 with the backport.
- **Checks:** CheckPatch clean; `make check` the same on both sides; the functional suite
  changes only by the new tests.
- Nothing sent. The full logs are in `/root/exp/agent-work/exit-uaf/`.

## 2026-11-01 — review round: a wrong sha corrected
- The 5.72 backport of fix 2 (`work/patches/5.72/0002-…`) named `Fixes: ee0f3c03f6fa`, which does
  not exist (`git cat-file -t ee0f3c03f6fa` → "Not a valid object name"); the commit is
  `ee0f3c03fb1d` ("media: Fix UnregisterApplication", first in 5.60), as the master patch says.
  Corrected in the patch file. Found by an outside reviewer, checked here.
- Also confirmed by the round: CO-23's and CO-37's test patches each apply to BlueZ `14bd6ab65`
  alone but conflict when stacked, in either order (`test/functional/test_a2dp.py`,
  `doc/functional-a2dp.rst`); a coordinated rebase is owed before either is sent.
