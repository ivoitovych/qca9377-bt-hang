# CO-38 clean, extended review: answers, checked (2026-11-25)

**The request:** `2026-11-25T0930Z-co38-clean-extended-review.md`. It holds no earlier verdicts, and its
stop rule is that only errors hold the send: false claims, incorrect code, or what a maintainer would
reject. Preferences are recorded here and not applied. The full texts are kept privately; findings only.

## Reviewer 1

**Verdict:** kernel patch send, BlueZ test send. **Errors found: none.**

All nine checks of section 6 were done against the trees: bluetooth-next `f57f78086ab5`, `bluetooth.git`
`77bc0f253ff9`, mainline, the stable tags, and BlueZ `1608f8361886`. The pass counts and the laptop session
were taken as reported. No `checkpatch` was run.

**What it adds, checked here where marked:**
- **Before the bug:** the loop copied every instance with no filter. *Checked:* v5.15 `mgmt.c:7509-7513`.
- **The bug is also in `bluetooth.git` `77bc0f253ff9`,** and the same diff applies, with a line offset, from
  v6.1.193 upward. Not to v5.15.
- **A second creator of the id `le_num_of_adv_sets + 1`:** `hci_start_per_adv_sync()` → `hci_add_per_instance()`
  with the BIS index. *Checked:* the call is at `hci_sync.c:2072`. The old and the new comparison hide that
  id alike, so the patch does not newly hide anything.
- **A behaviour change that matches the comment:** instances added while `le_num_of_adv_sets` is still the
  default 5, then a controller that reports fewer sets, are no longer all listed. That is not the bug fixed
  here, and not a reason to compare with the count.
- **Practice:** a close analogue, "Bluetooth: MGMT: Retain the selected legacy advertising schedule ID", was
  applied the day it was sent, with `Fixes:`, `Cc: stable` and test notes below `---`. "Unsuccessful" on
  this list usually means superseded or unanswered, rarely rejected.

**Preferences (recorded, not applied, per the stop rule):**
1. **Base on `bluetooth.git` for v7.4 instead of v7.5.** As before, the maintainer picks the tree. The
   patch applies there too.
2. **One sentence on bluetoothd's restart clean-up.** The earlier round's five reviewers advised leaving it
   out.
3. **Below `---`, say the l2cap and iso hangs and the 6.1 reports were identical with and without the
   patch,** so that "no other observed case changed" is not over-read. Cheap and accurate; the operator's
   call.
