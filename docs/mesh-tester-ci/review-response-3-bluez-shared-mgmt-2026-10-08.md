# BlueZ shared/mgmt fix: reviewer 1's findings (2026-10-08)

Reviewed: `000f99a` (series `559b1a787`/`821fa0976` on BlueZ master `d84171e6c`). Nothing has
been sent.

Result on `standalone/shared-mgmt-notify-leak-on-d84171e6c`: `d418103ef` (fix) and
`1ca5067ee` (tests), exported to `patches/mesh-tester/bluez-shared-mgmt-notify-leak-on-d84171e6c/`.
The reviewed state is kept on `keep/shared-mgmt-notify-leak-on-d84171e6c-821fa0976`.
`git diff 821fa0976 1ca5067ee`: comments in `unit/test-mgmt.c` only; `mgmt.c` unchanged.

## Findings and actions

| # | Finding | Checked | Action |
|---|---|---|---|
| 1 | Paragraph 1 mixes the leak and the use-after-free; unregistering the current entry is leak-only (`next` already saved) | Verified (queue.c:203–208) | split: leak paragraph, then use-after-free paragraph for the next entry |
| 2 | Name the use-after-free as the crash `872729a91632` fixed for `mgmt_unregister_index()` | Verified: that commit's own trace is `queue_foreach` reading a node freed by `queue_remove_if` via `mgmt_unregister_index()`; it kept `queue_remove_if()` in `mgmt_unregister()` | added, in checkpatch's `commit <sha> ("<title>")` form |
| 3 | State the return-value change directly rather than as pre-2015 history | Agreed | "For an entry marked by mgmt_unregister_index() or mgmt_unregister_all() it used to return true, take the entry off the list and leak it." The reviewer's draft ("unregistering it again returns false instead of taking it off the list") would have reintroduced the inaccuracy the second round removed (a repeated single unregister already returned false); not used |
| 4 | Tester sentence ungrammatical; add a trimmed ASan stack | Sentence was grammatical but awkward; reworded | trimmed userchan-tester record (4 frames, from `run-userchan-tester-unfixed.log`) |
| 5 | Patch 2 message is an assertion list; say what fails without the fix | Agreed | rewritten. The reviewer's draft said "the others leak", which is wrong for the unregister-all case (it fails on the return value; see review-response-2 finding 6); the message states each case's failure |
| 6 | Comments: the contract above `struct unregister_test`, one per `called[]`, and why `unregister_all_from_cb()` schedules the idle check itself | Agreed | added (comments only) |
| 7 | Code comment in `mgmt.c` naming the same deferral as `mgmt_unregister_index()` | — | not done: the message says it, and `mgmt.c` stays as reviewed and tested |
| 8 | Send a cover letter | — | not done: HACKING asks for one for features; reviewers 2 and 3 advised against for this series |

## Checks at `1ca5067ee`

* `unit-mgmt-run.sh`: `r1-fixed` all 13 PASS; `r1-unfixed`: unregister/3 FAIL
  `test-mgmt.c:478:unregister_check_idle … (0 == 1)`, unregister/4 FAIL
  `AddressSanitizer: heap-use-after-free`, unregister/5 FAIL `test-mgmt.c:536 … (1 == 0)`, the
  other 10 PASS.
* `make -j16 check`: `# TOTAL: 42`, `# PASS:  41`, `# SKIP:  1`, `# FAIL:  0`, `# ERROR: 0`.
* `bluez-lint.sh`: checkpatch `0 errors, 0 warnings` (35 and 238 lines); gitlint `PASS` both.
* `pre-send-check.sh`: origin/master `d84171e6c`; both apply in order; `OK to send`.
* Tester runs: not repeated; `mgmt.c` and the tester binaries are unchanged from
  `review-response-2` (blob `f5aeecf3f`).
