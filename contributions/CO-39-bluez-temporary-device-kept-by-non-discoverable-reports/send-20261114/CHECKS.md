# CO-39 checks (2026-11-14)

Master used: `20ffd285b58facfd1f2478d159a5f941b09d5be1` (2026-11-12), fetched from github.com/bluez/bluez 2026-11-14. Work clone `/root/exp/agent-work/lane4-bluez-20261114/bluez39`, final branch `co39g`.
Clock: summary.txt times are host-local (UTC+1); harness.log lines are UTC.

## Upstream state
- Not fixed (measured): at 20ffd285b `btd_adapter_device_found()` still calls `device_update_last_seen()` before the non-discoverable drop; `git diff a80671987 20ffd285b -- src/adapter.c` (a80671987 = the base of the 11-07 work) touches only HDT TLV defaults, and `src/device.c` only the pause/resume auto-connect refactor. `device_update_last_seen()` still restarts the temporary timer.
- No equivalent posted (measured, subjects only): `scripts/patchwork-recent.py 2026-11-01 "temporary|last.seen|non-discoverable|TemporaryTimeout|discoverable"` = 0 of 610 patches. A GitHub PR search for the topic found only an unrelated PR. A patch with a different subject would not have been seen.
- `Fixes:` proposed and present in patch 1: `def01de02593 ("device: Add timer for removing temporary devices")` (Luiz Augusto von Dentz, 2020-07-15; exists on master).

## Rebase
The v3 series (`/root/exp/agent-work/u29-t3-lifetime-patch/patch-v3/series/`) applies with `git am --3way` to 20ffd285b with no conflict; hunk offsets moved by +28 lines only. Two changes since v3: the `Fixes:` trailer was added to patch 1, and a comment was rewrapped (see CheckPatch below). Final patches: `patches/` (2 files). First draft with the 82-column comment: `patches-superseded-82col/`.
Subjects: `adapter: Don't keep temporary devices alive with non-discoverable reports`; `test: functional: add test for temporary device lifetime`.

## Decisive test (measured)
`test/functional/test_device.py::test_device_temporary_not_discoverable` (host0 `TemporaryTimeout=20`, wait up to 30 s for removal), noble VM container with its own kernel, `scripts/run-c.sh`, 7 runs per build, interleaved; the dossier's count was 6 (master) and 7 (patched).
- master: **7 of 7 fail**, all at `test_device.py:73` (the removal wait), `TimeoutError: Timeout reached`.
- master + patch: **7 of 7 pass**; after the comment rewrap (rebuilt) **3 of 3 pass** (`runs/master-patched-r2a..c`).
Summary: `logs/decisive-summary.txt`.

## make check (measured)
master 35/35, patched 35/35 (`logs/check-master-base.log`, `logs/check-master-patched.log`; the latter is the rebuilt rewrapped tree).

## Bot (scripts/bot-ci-local.sh --space user; image bluez-action-ci:c7d077f185cd, ELL 002b32d7c091) 
Output `project/tmp/bot-co39/` in the lane clone (copy into `logs/bot-co39/` when it ends).
Patched side, first draft: all PASS except **CheckPatch FAIL**: `WARNING:LONG_LINE_COMMENT: line length of 82 exceeds 80 columns` at `src/adapter.c:7801` in the comment I added. Earlier "checkpatch clean" (11-08) used the kernel script's 100-column default and missed it. Fixed by rewrapping the comment (comment-only diff, `git diff co39f co39g`). Rerun of CheckPatch and GitLint on the final mails: both PASS (`project/tmp/bot-co39-r2/`).
Patched, other checks (first draft; code identical to final): GitLint, BuildEll, BluezMake, MakeCheck, MakeDistcheck, CheckValgrind, CheckSmatch, bluezmakeextell, TestFunctional (`54 passed, 1 skipped, 11 deselected`, incl. the new test), IncrementalBuild, ScanBuild: PASS.
Base side: **still running at report time** (past TestFunctional, in ScanBuild); its result line is not in this file.

## Limits
- Source reading, not measured: with the patch a dropped non-discoverable report of an unconnected temporary device also no longer updates `last_seen`/`Connectable` state for that object (`device_update_last_seen()` since 6afb6e729, "device: Add Connectable property").
- Pair(), `FilterDiscoverable=false`: carried over from the 11-08 results, not rerun today. No-Flags case: deliberate (follows `device_is_discoverable()`).
