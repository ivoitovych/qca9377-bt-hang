# CO-39 send package (2026-11-14; nothing sent; one bot run still to read)

Copied from `/root/exp/agent-work/lane4-bluez-20261114/co39/`; `CHECKS.md` (if present) and
`PROGRESS.log` have the commands and results. BlueZ master `20ffd285b58f`; `adapter.c` unchanged
in this area since `a80671987`; no equivalent patch posted since 11-01 (by subject).

- `patches/0001` "adapter: Don't keep temporary devices alive with non-discoverable reports"
  (`Fixes: def01de02593`) and `patches/0002` "test: functional: add test for temporary device
  lifetime"; the v3 series of 11-08 rebased (hunk offsets only), with the `Fixes:` trailer added
  and one comment rewrapped: the bot's CheckPatch flagged it at 82 columns (the earlier
  "checkpatch clean" used a 100-column limit); the 82-column draft is in `patches-superseded-82col/`.
- **Measured:** `test_device_temporary_not_discoverable`, 7 runs per build: master fails 7 of 7
  (`TimeoutError` at `test_device.py:73`), patched passes 7 of 7, and 3 of 3 after the rewrap
  (`logs/decisive-summary.txt`). `make check` 35/35 on both. The bot's checks, patched side: pass
  (TestFunctional 54 passed, 1 skipped, the new test included) but for that comment, fixed.
- **Still open:** the bot's base side was still running (its `summary.txt` in the work area,
  `project/tmp/bot-co39/`, ended `base: start`); read its end before sending — a base failure is
  pre-existing unless the patched side shows it too. The Pair() and private-address cases were
  not re-run today (11-08's results carry over).

**Checked on copy:** `logs/decisive-summary.txt` (7 failed, 7 passed). **Left in the work area:**
the build tree and the per-run pytest logs (they print the emulator's random addresses).
