# BlueZ shared/mgmt leak fix: reviewer 2's findings and what was done (2026-10-07)

Reviewed: `1cd87c2` (REVIEW-REQUEST, patch `bdd3acd51`). Nothing has been sent.

Result: a two-patch series on `cache/bluez-standalone-mgmt-leak`, branch
`standalone/shared-mgmt-notify-leak-2026-10-07`:

* `ca5412447` shared/mgmt: Fix notify leak in mgmt_unregister() (revised fix)
* `b94779c29` unit/test-mgmt: Add tests for mgmt_unregister() from callbacks (new)

(The tests and builds below ran at `654205aea`/`2fdfc9729`, the same code with an earlier
message wording, kept on `keep/shared-mgmt-notify-leak-2fdfc9729`.)

Exported to `tmp/mesh-tester-ci/standalone/bluez-shared-mgmt-leak-2026-10-07/` and copied to
`patches/mesh-tester/bluez-shared-mgmt-notify-leak-2026-10-07/`. The earlier commits stay on
`standalone/shared-mgmt-notify-leak-2026-10-05` (`bdd3acd51`) and
`keep/shared-mgmt-notify-leak-1fb3fa4c5`.

## Findings and actions

| # | Finding | Checked | Action |
|---|---|---|---|
| 1 | Unpatched path loses the entry; patch repairs it | Verified (`mgmt.c` 128–136, 336–371, 995–1025 at `4dc15be8e`) | none |
| 2 | Iterator hazard: `queue_foreach()` saves `next` (queue.c:206) before the callback; unregistering the next entry frees that node in `queue_remove_if()` (queue.c:292) | **Measured**: new test `/mgmt/unregister/4` on unpatched `mgmt.c` → `ERROR: AddressSanitizer: heap-use-after-free` … `READ of size 8` … `#0 queue_foreach src/shared/queue.c:206` … `freed by thread T0 here: … #1 queue_remove_if src/shared/queue.c:292` (`unfixed-unregister-4.log`) | one sentence added to the commit message |
| 3 | Repeated unregister of the same id while notifying returns `true` twice with the patch (`false` the second time before) | **Measured**: first-version `mgmt.c` (`bdd3acd51`) fails `/mgmt/unregister/3`, `/4`, `/5` with `'mgmt_unregister(mgmt, test->id[n])' should be FALSE` (test-mgmt.c:462) | `if (!notify \|\| notify->removed) return false;` in the notifying branch; one sentence in the message |
| 4 | `mgmt_unregister_index(MGMT_INDEX_NONE)` marks every entry while notifying but matches only index-NONE entries otherwise (`mgmt.c` 161–168 vs 146–152, 1032–1038) | Verified from source | out of this patch; recorded for later (`### Later` below) |
| 5 | `Fixes: 872729a91632` | Verified by the reviewer from its diff | keep |
| 6 | Message says "40 bytes each as struct mgmt_notify", which reads as identification; the sanitizer stack names only `util_malloc()` | Agreed (validation record B3 says the attribution is inferred) | reworded: "40 bytes per object, which is the size of struct mgmt_notify on x86_64" (`struct mgmt_notify`, mgmt.c:69–77: 4+2+2+1+pad+3×8 = 40) |
| 7 | Comment style: BlueZ `doc/coding-style.rst` M2 starts multi-line comment text on the second line | Verified (coding-style.rst:76–89) | comment reformatted |
| 8 | `unit/test-mgmt.c` never calls `mgmt_unregister()` and registers no destroy callbacks | Verified (test-mgmt.c at `4dc15be8e`: only `mgmt_unregister_all`, `mgmt_unregister_index`, `mgmt_unref` from callbacks) | new test patch, fix first |
| 9 | `--disable-lsan` is not contradictory | Agreed | none |
| 10 | No "v2", no stable Cc, send to linux-bluetooth | Agreed | none |

## Is the use-after-free a vulnerability?

Inferred from source: no in-tree daemon unregisters a single entry from inside a notification.
`git grep -n "mgmt_unregister(" -- src profiles plugins mesh lib` finds only
`mesh/mesh-io-mgmt.c:462-463` (`dev_destroy()`), reached from `ctl_alert()` via
`read_info_cb()`, a command-response callback, so `in_notify` is false and the entry is freed
at once. bluetoothd uses only `mgmt_unregister_index()`/`mgmt_unregister_all()`. The callers
that do unregister from event callbacks are the testers under `tools/`. Treated as an ordinary
bug for linux-bluetooth.

## The unit tests (`2fdfc9729`)

Four cases, each registering entries with a destroy callback that asserts it runs only once:

* `/mgmt/unregister/3`: an entry unregisters itself; two events.
* `/mgmt/unregister/4`: the first entry unregisters the second; two events.
* `/mgmt/unregister/5`: an entry unregisters another, then calls `mgmt_unregister_all()`.
* `/mgmt/unregister/6`: unregister outside a notification.

They check that the unregistered entry is not notified again, that its destroy callback has not
run inside the callback but has run by the next event, that a repeated unregister returns
`false`, and that every entry is destroyed exactly once by the end.

`tmp/mesh-tester-ci/unit-mgmt-run.sh` (one process per case; logs in
`tmp/mesh-tester-ci/logs/unit-mgmt-2026-10-07/`), same ASan/UBSan build:

| case | unpatched `mgmt.c` (`4dc15be8e`) | first version (`bdd3acd51`) | revised (`654205aea`) |
|---|---|---|---|
| 9 existing cases | PASS | PASS | PASS |
| unregister/3 | FAIL `test-mgmt.c:522 … (test->destroyed[i] == test->id[i] ? 0 : 1): (0 == 1)` | FAIL `test-mgmt.c:462 … should be FALSE` | PASS |
| unregister/4 | FAIL `AddressSanitizer: heap-use-after-free` | FAIL `test-mgmt.c:462 … should be FALSE` | PASS |
| unregister/5 | FAIL `test-mgmt.c:505 … 'mgmt_unregister(mgmt, test->id[2])' should be FALSE` | FAIL `test-mgmt.c:462 … should be FALSE` | PASS |
| unregister/6 | PASS | PASS | PASS |

(The 10-07 run labels are `unfixed`, `first-version` and `fixed`. The `*-env.txt` files hold
the tree HEAD and the `mgmt.c` blob each run used.)

## Build, lint, check (`make check` at `2fdfc9729`; lint and pre-send on the final export)

* No compiler warnings in `make unit/test-mgmt`.
* `bluez-lint.sh`: checkpatch `0 errors, 0 warnings` (35 and 203 lines checked); gitlint
  `PASS no violations` for both patches.
* `make -j16 check` (`make-check-2fdfc9729.log`): `# TOTAL: 42`, `# PASS:  41`,
  `# SKIP:  1`, `# FAIL:  0`, `# ERROR: 0`, the same as `bdd3acd51` (validation B4).
* `scripts/pre-send-check.sh cache/bluez-upstream …`: origin/master `f8f352d13`; both patches
  `applies to origin/master: yes`; `OK to send`.

## Testers in QEMU (`runs-bluez-standalone-2026-10-07.sh`)

The B3 procedure of 2026-10-05, repeated: guest kernel `bzImage-val-btnext-control`
(`036d4119079a`), launcher `cache/bluez-upstream/tools/test-runner`, one VM at a time.
`bin-unpatched` is the 10-05 build of `4dc15be8e`. `bin-revised-2026-10-07` was built at
`654205aea`; `standalone-bin-snapshot.sh` checked that the working-tree `mgmt.c` was that
commit's (blob `f5aeecf3f3e7`) and that the binaries were newer than it.

| run | result | LeakSanitizer |
|---|---|---|
| `std-mgmt-unpatched` 05:19:08 to 05:20:02 | `Total: 503, Passed: 503 (100.0%), Failed: 0` | `Direct leak of 9080 byte(s) in 227 object(s)` … `util_malloc src/shared/util.c:46`; `Direct leak of 120 byte(s) in 5 object(s)` … `btdev_add_hook emulator/btdev.c:8916`; `SUMMARY: AddressSanitizer: 9200 byte(s) leaked in 232 allocation(s).` |
| `std-mgmt-revised` 05:20:02 to 05:20:53 | `Total: 503, Passed: 503 (100.0%), Failed: 0` | only the `btdev_add_hook` record; `SUMMARY: AddressSanitizer: 120 byte(s) leaked in 5 allocation(s).` |
| `std-mesh-unpatched` 05:20:53 to 05:21:00 | `Total: 10, Passed: 8 (80.0%), Failed: 2` (`Mesh - Send cancel - 1/2` `Timed out`) | `Direct leak of 120 byte(s) in 3 object(s)` … `util_malloc src/shared/util.c:46` |
| `std-mesh-revised` 05:21:00 to 05:21:07 | the same, the same two cases | none |

* `compare-verdicts.py`: mgmt-tester `cases with different verdicts: 0` (503/503 both);
  mesh-tester `cases with different verdicts: 0`, `not-passed sets identical: True (A 2, B 2)`.
* `splat-check.sh`: mesh logs `clean`. mgmt logs show only mgmt-tester's own
  `command 0x0405 tx timeout`, 2 unpatched and 1 revised (on 10-05: 2 and 2). Nothing else.
* The numbers in the commit message are unchanged by the revision.

The commits were reworded twice after the runs (message only; `git diff 2fdfc9729 b94779c29`
is empty). The final series is `ca5412447` and `b94779c29`; `make check` ran at `2fdfc9729`
(the same tree). Checksums: `logs-bluez-2026-10-07-SHA256SUMS` (63 entries, `all entries OK`).

## Later

* `mgmt_unregister_index(mgmt, MGMT_INDEX_NONE)` selects differently inside and outside a
  notification (finding 4). Check whether anything calls it with `MGMT_INDEX_NONE` before
  proposing anything.
* `in_notify` is a flag, not a depth: a nested dispatch on the same `struct mgmt` would clear it
  early. The reviewer found no reachable case; not pursued.
