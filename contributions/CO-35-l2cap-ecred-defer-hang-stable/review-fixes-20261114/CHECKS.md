# Stable items from the 2026-11-14 outside review: checks (lane 4, 2026-11-14 UTC)

Work area: `/root/exp/agent-work/lane4-bluez-20261114/stable-20261114/`. Lane 5's area and the project tree were only read. Nothing was sent or posted. Builds `make -j4` under `nice -n 10 ionice -c 2 -n 7`, one at a time; one guest at a time; web reads under `nice -n 19 ionice -c 3`. Free disk stayed above 30 GB (`progress.log`); every build tree was deleted before its guests ran.

| task | document | result |
|---|---|---|
| 1. sanitizer record | `TASK1-sanitizer-record.md` | lockdep and KASAN were in the built kernels (config recreated for v6.6.162 and v7.3.4; compile logs show `lockdep.o` and `mm/kasan/*.o`). The covers are right; the 11-02 note and the 11-14 `CHECKS.md` sentence are wrong. Corrected sentences given |
| 2. deviation table | `TASK2-deviation-table.md` | per line, from `diff` of the mainline commits against the package patches: only three dropped annotations (patch 1, all three lines), plus context-only differences; patch 2 differs only where the tree lacks the `MSG_ERRQUEUE` block (6.12.y, 6.6.y) |
| 3. reduced prerequisite | `TASK3-reduced-prerequisite.md`, `reduced/<line>/` | built and tested on v6.6.162, v6.12.117, v6.18.63, v7.3.4: the case passes (1.017 to 1.074 s), the whole l2cap-tester has identical verdicts to the full pair on every case; prerequisite 69-70 diff lines against 149 |
| 4. queue refresh | `TASK4-queue-refresh.md` | not in any stable release, queue or rc of any line (13:08 to 13:42 UTC); corrected date sentence for the CO-22 mail |

## Reconfirmation of the base in this work area (v6.6.162, plain tag)

`scripts/base-line.sh v6.6.162`: same config, same runner as the reduced builds; the deferred-accept case "L2CAP Ext-Flowctl Server - Accept 2 Close 1" with a 180 s limit: `HANG (limit 180 s)`, hung-task reports 7 (`logs/summary-v6.6.162-base.txt`, `logs/case-v6.6.162-base.log`), as lane 5 measured. The other bases are lane 5's logs on the same tags (`/root/exp/agent-work/lane5-status-stable-20261114/co35/logs/summary-<tag>-base.txt`: HANG, hung-task 7 on v7.3.4, v6.18.63, v6.12.117, v6.6.162).

## Other notes

- `upstream/` has our copies of the mainline commits `608e0b7a675b`, `32d86e048d8e` and `5874f8d03268` (exported with `git format-patch` from lane 5's kernel repository). In the copy of the last one a single third-party attribution trailer line was removed (no other change) because this work area keeps no such names.
- One git clone with shared objects, `k/`, exists in this folder (`git clone --shared --no-checkout` of lane 5's repository; no checkout kept).
- The reduced patches carry no `Signed-off-by` of ours; patch 2 of the 6.x lines is the package's file with the submitter's existing `Signed-off-by`.
- Kernel images kept: `img/bzImage-<tag>-red[-sci]` and `img/bzImage-v6.6.162-base`.
- Not done: reduced pair on 6.1.y, 5.15.y, 5.10.y; the stable team's own builds; a second base build for 6.12.y, 6.18.y, 7.3.y (lane 5's logs are used).
