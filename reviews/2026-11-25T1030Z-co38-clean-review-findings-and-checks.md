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

**Preferences (first recorded, not applied, per the stop rule; then weighed again when the operator opened the round to polishing):**
1. **Base on `bluetooth.git` for v7.4 instead of v7.5.** As before, the maintainer picks the tree. The
   patch applies there too.
2. **One sentence on bluetoothd's restart clean-up.** The earlier round's five reviewers advised leaving it
   out.
3. **Below `---`, say the l2cap and iso hangs and the 6.1 reports were identical with and without the
   patch,** so that "no other observed case changed" is not over-read. **Applied** with reviewer 2 (F5). Not
   applied: 1 and 2.

## Reviewer 2

**Verdict:** kernel patch, send after limited verification and minor corrections; BlueZ test, ready subject to
its kernel dependency. **No defect in either diff.** Its abstract model of the two predicates (16,368
configurations) found no assertion failure. Its reconstructed kernel patch-id matches `a15c80fa`.

**The operator relaxed the stop rule for this round (2026-11-25):** this round is for polishing, so
preferences are weighed on their merits too.

| # | finding | check here | decision |
|---|---|---|---|
| F1 | A second path to the id N+1: ISO broadcast with a supplied BIS number reaches `hci_add_adv_instance()`, which allows N+1. So "means to hide only the mesh instance" is not fully established | right: `qos_set_bis()` picks 1..N-1 itself (`hci_conn.c:1722`), but a supplied value goes to the same allocator, which allows N+1 (`hci_core.c`). Both predicates hide N+1, so the fix newly hides or shows nothing there | **opening reworded** to the range the comment states: "means to report instances 1 to le_num_of_adv_sets, leaving out the mesh instance, …" |
| F2 | `le_num_of_adv_sets` can change in a device's lifetime | it is written only from the controller's Read Number of Supported Advertising Sets at LE init (`hci_event.c:1958`). The mesh instance exists only while powered, after that read, with a 1 s timeout (`mesh_send_sync()`). A change under a live mesh instance needs a controller that reports a different count on a later power-on | recorded; no change |
| F3 | "the controller starts advertising it": the evidence is a successful command, not a radio observation | right | "the controller accepts LE Set Advertising Enable for it" |
| F4 | "submitted to BlueZ separately" reads as done, but the kernel mail goes first | right | "being submitted to BlueZ separately" |
| F5 | Name the hangs, so "no other observed case changed" is not over-read (also reviewer 1) | right | "Some suites hang on the older ones, identically with and without this patch." |
| — | "still advertised" → "still configured" | in the timeout example, instance 2 *is* still advertised by the kernel. That is the harm | kept |
| — | Send the BlueZ test only once the kernel fix is in the CI kernel (slight preference) | both orders have precedent | the operator's call; the note below `---` covers same-day sending |
| — | Mesh + public instance test; ISO BIS boundary; power-cycle lifecycle | bounded above | the mesh test stays a follow-up |

After the edits, checkpatch `--strict` is clean (one too-long line was rewrapped), the patch-id is still
`a15c80fa`, and the patch applies to bluetooth-next `f57f78086ab5`.

## Reviewer 3

**Verdict:** kernel patch, send after changes; BlueZ test, hold until the kernel fix is in the CI kernel, then send
after changes. **No defect in either diff.**

| # | finding | check here | decision |
|---|---|---|---|
| F2 | "hide only the mesh instance" is false: the ISO/BIS path can take N+1 | same as reviewer 2's F1, already applied | done; the BIS question registered as **BT-29** (`docs/issues.md`), kept out of this patch |
| F8 | BlueZ: "Without the kernel change … the instance is left out" and "fails on kernels without that fix" are false for kernels before 6.1, which have no filter | **right**: v5.15 copies every instance (`mgmt.c:7509-7513`) | body: "On kernels from 6.1 on without the kernel change …"; below `---`: "fails on kernels that have the bug (6.1 and later) until that fix is in" |
| F9 | "starts advertising" beyond the evidence | already applied | done |
| F10 | "still advertised" → "remains active" | third reviewer to ask; the polishing round allows it | "instance 2 remains active but is no longer reported" |
| F11 | "no other completed case differed" | sharper than "no other case changed" next to a sentence on hangs | "no other case that ran changed its result" |
| — | Double space before the brace | matches the neighbouring arrays (`mgmt-tester.c:5170`) | kept |
| — | Send the BlueZ test only after the kernel fix is applied (reviewers 2 and 3); the precedent `923d95d0c2fb` was sent after its kernel fixes were in | spares the maintainer a known red CI run | **recommended to the operator**: the kernel patch first, the BlueZ test once applied, with the lore link and the commit ID |

checkpatch `--strict` is clean, the patch-ids are unchanged (`a15c80fa`, `70a48730`), and both apply to today's tips.

## Reviewer 6

**Verdict:** kernel patch, send after one change below `---`; BlueZ test, send. **No defect in either diff.**
- **Its own runs** on bluetooth-next `f57f78086ab5` in QEMU, without KASAN or lockdep:
  - the new case: 0/3 before, 3/3 after;
  - full mgmt-tester: the only difference is this case;
  - mesh-tester: unchanged.
- **Three local experiments,** each listing the same instances before and after the fix:
  - the commit message's timeout example: nothing listed before, 2 after;
  - instance 2 with a mesh send in flight: 2 listed, mesh hidden, both ways;
  - mesh only: nothing listed, both ways.

| # | finding | check here | decision |
|---|---|---|---|
| 1 | "In the ten testers of the Bluetooth kernel CI": the CI lists eleven, and for `mgmt.c` it runs mgmt-tester and mesh-tester | **right**: our own register says the CI picks testers by file (mgmt.c → mgmt + mesh), and we ran ten | "In ten of the Bluetooth kernel CI's testers, including mgmt-tester and mesh-tester, which it runs for this file, …" |
| 2 | The BIS path can take sets + 1 | as reviewers 2 and 3 | BT-29 |
| 3 | Attribution | the operator's decision of 2026-09-24 | no change |
| 4 | bluetoothd restart sentence (optional, confirm first) | earlier advice: leave out | not taken |
| 5 | Cc linux-kernel (`get_maintainer.pl` lists it) | reviewers 1, 2 and 7 of 11-24 advised omitting it | the operator's call; omitted for now |

**After the operator's sign-off (2026-11-25):**
- one `Signed-off-by:` line, after `Cc: stable`;
- `checkpatch --strict` with the sign-off check on: "0 errors, 0 warnings, 0 checks … ready for submission";
- the patch-id is unchanged;
- the dry run of the exact send gives 5 `RCPT TO`: the list, the three named, and stable from the trailer.

## Reviewer 7 (of the 11-25 text, answered 11-26)

**Verdict:** kernel patch, send after message corrections; BlueZ test, send after small corrections. **No defect in
either diff.**
- **Its own checks:**
  - patch-ids match;
  - the patch applies to the trees and stable tags named, and to `bluetooth.git` `77bc0f253ff9` and mainline master;
  - the patched `mgmt.c` and the tester compile;
  - `mgmt-tester -l` lists the new case;
  - the extracted `read_adv_features()`, run under ASan and UBSan: 35,175 cases, no fixed-function mismatch.
- **Not run by it:** QEMU and the hardware.

| finding | check here | decision |
|---|---|---|
| "Only mesh" too strong (BIS path) | fixed on 11-25 | done; BT-29 |
| Unsigned draft not clean under plain strict checkpatch | true of that draft | the signed file now passes `checkpatch --strict` with the sign-off check, in a full kernel tree: 0/0/0 |
| BlueZ "kernels without that fix" | fixed on 11-25 | done |
| BlueZ tip moved to `79162c108911` | right; `mgmt-tester.c` unchanged | the recheck document states it |
| Keep test limits below `---`: hangs, unobserved cases, baseline reports, hardware gap | hangs and unrun cases were already named. The baseline reports are in our evidence: KASAN and lockdep on 6.1.193, lockdep on 6.12.119, identical both ways (`report-diff.txt`) | **added** both clauses: the reports, and "The patched kernel has not yet run on that hardware." |
| A new subject ("Report sparse advertising instances") and a rewritten body leading with the failure | the current text has passed two review rounds; the subject is named by the BlueZ message | **offered to the operator**, not applied |
| BlueZ registration CHECK (continuation alignment) | matches the neighbouring registrations | kept |
| Attribution | the operator's decision of 2026-09-24 | no change |
| linux-kernel "not a prerequisite" | R-7 measured | the operator's call |

After the edits: checkpatch `--strict` (sign-off on) 0/0/0; no prose line over 72; patch-id `a15c80fa`; the dry run
gives 6 recipients with linux-kernel.
