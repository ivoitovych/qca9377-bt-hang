# CO-38 kernel send package of 2026-11-23

It replaces `../send-20261114/patch/` after the outside review of 2026-11-23
(`../../../reviews/2026-11-23T0404Z-five-kernel-submissions-review-findings-and-checks.md`,
findings 1–3, 15, 23).

**Changed in the kernel patch** (its message and trailers; the diff is byte-identical):
- "Whenever the instance numbers are not 1 to n" narrowed to "an instance whose number is
  greater than the current number of instances", with "no Advertising Removed event says so"
  added.
- `Cc: stable@vger.kernel.org` added. Four of five reviewers were for it, and follow-up D12
  recommended it.
- A testing paragraph added below `---`. It states only the case run on `da3cc02587c6` on
  2026-11-14.

**Checked 2026-11-23:**
- the patch applies to bluetooth-next `cf357cfc025e`;
- `checkpatch.pl --strict --no-tree --no-signoff`: 0 errors, only the "unknown commit id" warning
  that `--no-tree` gives.

**Still to do before a send:**
1. **Rewrite the BlueZ test.** The current `../bluez-split-20261114/series-a/` adds 388 lines:
   duration timing, replacement and ext-params paths, and a membership check that allows extra
   entries. Four of five reviewers asked for it to be replaced. The new case:
   - add instance 2 alone (on the base kernel `2 <= adv_instance_cnt` = 1, so it is hidden), or
     add 1 and 2 and remove 1 explicitly;
   - read the advertising features;
   - assert exactly one instance, ID 2, and the exact length;
   - give it a subject of at most 50 characters (the current one is 56).

   Weihong Guan's BlueZ `923d95d0c` (single advertising set tests, 2026-11-16) shows the
   generic-data style to follow.
2. Run the new case base against patched on today's tip and BlueZ master. Then make this
   patch's testing paragraph name the new case and its result.
3. Optional, once a test shows it: bluetoothd clears leftover instances at start-up only
   `if (feat->num_instances)` (BlueZ `src/advertising.c` l.2043). So a lone hidden instance
   survives a bluetoothd restart, a user-visible effect worth one sentence.
4. Optional, on the operator's word (it touches the laptop's Bluetooth): `btmgmt add-adv` of
   instance 2 alone, then `btmgmt advinfo`, on the unpatched laptop.
5. The Signed-off-by, then checkpatch, the bot's checks and a dry run (none exists yet for CO-38).
