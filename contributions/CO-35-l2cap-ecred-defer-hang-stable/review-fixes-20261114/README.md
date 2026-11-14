# CO-35: answers to the 2026-11-14 outside review

`../../../reviews/2026-11-14T1400Z-kernel-patches-review-answers-checks.md` §7 holds the review
points; this folder answers them. Nothing was sent.

1. **Sanitizers** (`TASK1-sanitizer-record.md`): the covers' "No lockdep or KASAN report" stands.
   - The kernels were built from BlueZ's `doc/tester.config`, which sets `CONFIG_PROVE_LOCKING`,
     `CONFIG_LOCKDEP` and `CONFIG_KASAN`.
   - The config was recreated with `make olddefconfig` for v6.6.162 and v7.3.4, and the four
     reduced builds' `.config` files were saved: all three options are `=y` everywhere
     (`logs/dotconfig-*`).
   - Our 11-02 note "hung-task detection only" was wrong. It is corrected in
     `../send-20261102/results.md`.
2. **Deviation table** (`TASK2-deviation-table.md`), per line, against the two mainline commits.
   - The prerequisite differs only by three dropped annotations and by context.
   - The fix differs only by offsets and the absent `MSG_ERRQUEUE` block.
   - No code line differs.
3. **The reduced prerequisite** (`TASK3-reduced-prerequisite.md`, `reduced/<line>/`), reviewer
   3's option.
   - Patch 1 carries only `l2cap_chan_lock_conn()` and `l2cap_chan_unlock_conn()`: 49-50 inserted
     lines, under the 100-line limit, against 149 diff lines for all of `608e0b7a675b`. It keeps
     the upstream author and sign-offs, with a bracketed note on what was left out.
   - Patch 2 is unchanged.
   - On v7.3.4 (with `5874f8d03268`), v6.18.63, v6.12.117 and v6.6.162, the deferred-accept case
     passes, against a hang on the plain tags.
   - The whole l2cap-tester gives the same verdict for all 111 cases as the full pair on each line
     (`logs/compare-reduced-vs-full.txt`).
   - No lockdep, KASAN or hung-task report, and no `net/bluetooth` build warning.
4. **Queue refresh** (`TASK4-queue-refresh.md`): 2026-11-14, 13:08 to 13:42 UTC. No CO-35 or
   CO-22 commit is in a release, the stable queue or a stable-rc branch of any line, and
   `5874f8d03268` is still missing from 7.3.y. Repeat the check on the day of the send.

**Checked on copy:**
- all six `.config` files show 3 of 3 options set;
- the five decisive case logs: base v6.6.162 hangs (hung-task); the reduced pair passes in about
  1 s on all four lines;
- `compare-reduced-vs-full.txt`: 0 cases differ on any line;
- the reduced patch's header and note.

**Left in the work area:** the tester logs (`logs/case-*.log`, `logs/full-*.log`: they print the emulator's addresses), whose verdict lines are in `logs/case-verdicts.txt` and `logs/full-totals.txt`;
- `fetched/` (queue pages);
- `upstream/`, a copy of a mainline commit that was edited there and so is not a faithful copy;
- the build trees and kernel images;
- the superseded first wording of the reduced patches.

**For the operator:** the full prerequisite with the exception request (the current package), or
the reduced one (this folder). The reduced 7.3.y request would carry patch 1 as a patch, since it
is not a mainline commit.
