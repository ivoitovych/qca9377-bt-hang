# BlueZ `shared/mgmt` notify leak — sent 2026-10-08, awaiting the maintainer

| | |
|---|---|
| **status** | **submitted** 2026-10-08 05:41:01 to 05:41:02 +0200, To linux-bluetooth only, two patches threaded, no cover letter |
| 1/2 | [`0001-shared-mgmt-Fix-notify-leak-in-mgmt_unregister.patch`](0001-shared-mgmt-Fix-notify-leak-in-mgmt_unregister.patch) — `src/shared/mgmt.c`, +17/−7 · [lore](https://lore.kernel.org/r/20261008034102.707451-1-yaroslav.voytovych@gmail.com) · [patchwork 14873331](https://patchwork.kernel.org/patch/14873331/) |
| 2/2 | [`0002-unit-test-mgmt-Test-unregistering-from-callbacks.patch`](0002-unit-test-mgmt-Test-unregistering-from-callbacks.patch) — `unit/test-mgmt.c`, +225 · [lore](https://lore.kernel.org/r/20261008034102.707451-2-yaroslav.voytovych@gmail.com) · [patchwork 14873330](https://patchwork.kernel.org/patch/14873330/) |
| base | BlueZ master `d84171e6cd68` (`base-commit:` in 1/2); `scripts/pre-send-check.sh` OK minutes before sending |
| next | the list's CI bot on patchwork; `git log origin/master --grep="mgmt_unregister"` after about two days; no resend for lint |

The two files here are byte-identical to what was mailed.

## The defect

`mgmt_unregister()` called from a notification callback took the entry off `notify_list`
with `queue_remove_if()` and only marked it removed. `process_notify()` frees removed entries
still on the list once its walk is done, so this one leaked and its destroy callback never
ran. If the callback unregistered the *next* entry, it was also a use-after-free:
`queue_foreach()` had already saved that entry's queue node (`queue.c` 203–208), and
`queue_remove_if()` frees it (`queue.c` 292) — the crash `872729a91632` fixed in 2015 for
`mgmt_unregister_index()`, never fixed for `mgmt_unregister()`. The fix leaves the entry on
the list while notifying, as the other two unregister functions do; an entry already marked
removed now returns `false`.

Found during the mesh work, in the testers' ASan leak reports; `bluetoothd` itself
unregisters only with `mgmt_unregister_index()` and `mgmt_unregister_all()`, and no in-tree code unregisters a *different* entry
from one, so the use-after-free is not reachable in the tree (not a vulnerability; inferred
from `git grep "mgmt_unregister("` at the base).

## What was measured (base `d84171e6c`, the project's run logs)

| check | without the fix | with the fix |
|---|---|---|
| `unit/test-mgmt`, 13 cases, ASan | `/mgmt/unregister/3` fails (entry never destroyed), `/4` heap-use-after-free in `queue_foreach()` (`queue.c:206`), `/5` fails (`true` for an entry already marked removed); the other 10 pass | 13/13 pass |
| `make check` | — | 42 total, 41 pass, 1 skip, 0 fail |
| leaked `mgmt_register()` allocations (`mgmt.c:974`), full ASan stacks, testers in QEMU | mgmt-tester 228, mesh-tester 3, userchan-tester 2 | 0, 0, 0 |
| testers' verdicts | mgmt-tester 502/506, mesh-tester 8/10, userchan-tester 4/4 | identical, case by case (the failures predate the fix) |
| checkpatch (BlueZ `.checkpatch.conf`), gitlint (BlueZ `.gitlint`) | — | 0 errors, 0 warnings; no violations |
| clang static analyzer on both files | — | no report (the base files have none either) |

The run logs, their SHA256SUMS and the four outside review rounds are on the project's private
branch, kept with the rest of the mesh work; this directory records the facts.

## How it was shaped

Four outside reviews before sending, each verified against the source before acting:
the first draft returned `true` for an entry already marked removed and had no tests; unit
tests were added that fail without the fix for the stated reasons; the messages were rewritten
for one reading; a clang analyzer report in the new test (which the bot's ScanBuild would have
posted as a warning) was removed by keeping the expected counts in the test struct; and a
bulleted case list was put back into prose after measuring accepted history (lists appear in
1–2 % of BlueZ commit bodies before 2026, and small test additions are prose).
