# Review request, round 4: v3, the series reordered for stable (CO-02)

Nothing is sent without the project author's word, and there is no external deadline.

The rechecks of `0824c49` (`reviews/2026-10-22-rechecks-of-0824c49.md`) found no code problem.
Reviewer 6 showed that the hold fix carried the refusal's lines as context, so stable could not
apply it alone on 6.6 and 6.12, where only it is needed. **v3** puts the hold fix first. The
final code is unchanged. Strict apply checks on the current stable heads, and a build-and-test
run on 6.12.114, confirm the reorder.

## What to read
Links are relative, so they stay at the commit you opened this file from.
1. The mails: [`patch/v3/kernel/`](patch/v3/kernel/) and [`patch/v3/bluez/`](patch/v3/bluez/).
2. The evidence, with the per-line table and the 6.12 results:
   [`experiments/results-2026-10-22-v3.md`](experiments/results-2026-10-22-v3.md).
3. What each recheck point led to: the last entry of [`log.md`](log.md).

## What we ask
1. **The order and the cover letter's stable paragraph:** are they right?
2. **The planned stable tags:** `Cc: stable@vger.kernel.org # 6.6.x` on patch 1 (6.1 has the CVE
   fix but not the bug, and the hold fix does not apply there); a plain `Cc: stable` on patches 2
   and 3, which their `Fixes: e6720779ae61` limits to 6.13 and later.
3. **The BlueZ test changes:** the During case also accepts EBUSY (kernels before 6.13);
   Connect Twice checks the teardown order and status; the one-line rebase offer below `---`.
4. **Anything that should stop the send.**

Still running when this was written: build-and-test on 6.6.160 (hold fix), and on 6.18.58 and
7.2.12 (all three, with the parked race). The results will be added to the evidence file.

Please answer in any form.
