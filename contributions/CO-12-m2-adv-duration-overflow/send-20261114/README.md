# CO-12 refreshed: the clamp on bluetooth-next da3cc02587c6, and the design alternative (2026-11-14; nothing sent)

Copied from `/root/exp/agent-work/lane3-mgmt-20261114/CO-12/` (the guest logs, a tester binary and
the fetched pages stay there); `CHECKS.md` has every command, `summary.txt` every count.

- **The clamp** (`patch/`, authored by the operator, no Signed-off-by): the overflow is still on
  the tip (`hci_sync.c:1747`), nothing posted on advertising duration since 10-28; the patch
  applies to bluetooth-next and bluetooth/master; checkpatch `--strict` only the missing
  Signed-off-by.
- **Measured** (QEMU, KASAN + lockdep, 4 CPUs, 3 runs each): the AdvDur research cases 9-10 of 22
  → 20 of 22 (the two still failing are the 1 s controls, whose own check looks wrong: the log
  shows Duration 100 and removal at 1018 ms; inferred); mgmt-tester's Add cases 119 → 127 with the
  clamp, 128 of 128 with the clamp and CO-38's fix; `-s Advertising` 124 of 125 on both (the same
  case times out on both); all 24 guest logs clean. No bot run yet.
- **`DESIGN.md`:** clamp now vs. a host-side deadline (a per-instance timer like `rpa_expired_cb`,
  Duration 0 to the controller, and a decision about suspend/resume), vs. rejecting long
  timeouts; how Cen Zhang's 14927631 (it keeps `u16 duration`, so it does not fix the overflow; it
  no longer applies) would interact. **The lane's recommendation:** send the clamp now with the
  655.35 s limit stated, and leave a host deadline until his v2 settles. The operator decides.

**Checked on copy:** `summary.txt` (AdvDur plain 10/9/9 of 22, clamp 20/20/20; Add clampfix
128/128/128; Advertising unchanged).
