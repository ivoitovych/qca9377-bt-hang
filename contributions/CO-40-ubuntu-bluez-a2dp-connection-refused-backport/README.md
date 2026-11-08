# CO-40 — Ubuntu BlueZ 5.72: backport `a6ac17f0e393` so a refused A2DP connect says "refused" (U29)

**What:** when a headset has dropped the laptop's key, Connect fails in GNOME as
`br-connection-unknown`. The kernel refuses the A2DP channel with `ECONNREFUSED`. 5.72's
`error_to_errno()` (`profiles/audio/a2dp.c`) turns that into `-EAGAIN`, which has no name in
`src/error.c`.

Upstream fixed this in `a6ac17f0e393` ("a2dp: Fix connection error message", Frédéric Danis,
2024-08-21, first in 5.78): one `case ECONNREFUSED:`, giving `br-connection-refused`. It is not
in Ubuntu 24.04's 5.72.

**State (2026-11-07): tested in QEMU, not filed.**
- The laptop's 5.72 tree was built unchanged and with the upstream commit applied unedited.
- **Baseline:** `br-connection-unknown` in 10 of 10 runs.
- **Patched:** `br-connection-refused` in 10 of 10 runs.
- **No-ACL control:** "unknown" in 5 of 5 runs on both builds (`EACCES`, a different path).

**Limit:** it still does not tell the user "the headset forgot the key". No errno fix on this
path can, because the HCI status reaches no socket.

**Next:** bundle with the other 5.72 candidates (CO-03, CO-11a, CO-37) in one Ubuntu stable
update, or file it alone. The operator files.

**Decides:** the operator.

**Refs:**
- `docs/issues.md` U29;
- `results/u29-emulator-2026-11-07/` §1, with the raw runs in
  `/root/exp/agent-work/u29-t1-a2dp-backport/`;
- the second reviewer's report `reviews/2026-11-07T1341Z-u29-source-investigation-reviewer-2-verbatim.md`.
