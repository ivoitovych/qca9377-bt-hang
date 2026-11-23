# Intermediate recheck of the send packages (2026-11-23 evening): findings checked and answered

**What was reviewed.** At the operator's request, reviewers 1, 2, 3, 6 and 7 rechecked from their own earlier
reviews: an intermediate health check of `main` at `5d16a4353fd1`. Only the findings are recorded here; the full
texts are kept privately. Each claim was checked before anything changed. The reviewers' opinions are weighed,
not taken as orders.

**Overall.**
- Reviewers 2, 3, 6 and 7 confirm that every point of the previous round was applied. Reviewer 1 saw the
  earlier state and has nothing new.
- None found a code defect, and none sees a reason for another engineering round before CO-38.
- Reviewer 2 checked CI itself: `checks` green, `access-audit` red.

| # | finding (reviewers) | checked | outcome |
|---|---|---|---|
| 1 | CO-38's note names a fix "sent separately" that will not have been sent: CO-38 goes days before CO-44. Test CO-38 on an image with it alone, or say the other fix is not yet posted (6) | true | **acted on the stronger option:** the current-tips batch (below) now builds one image per patch: base, base + CO-38 only, base + CO-44 only. The notes will cite single-patch results, and the sentence goes |
| 2 | Both BlueZ tests apply to master only with offsets. CO-38's test was cut on a tree that already held CO-44's test, and CO-44's still carries the old base `20ffd285b58f` (6) | true | **fixed:** each is re-exported alone on BlueZ master `1608f8361` (2026-11-23, newer than the `1adfe662efef` the reviewer saw), with `[PATCH BlueZ]` and that `base-commit`. Patch-ids are unchanged (`70a48730…`, `21bec9e9…`). checkpatch with BlueZ's ignore list is clean |
| 3 | CO-26: `mesh_send_sync()` returns `MGMT_STATUS_BUSY`, a positive MGMT status, where an errno is expected, a few lines above the change. Decide whether to fold it in (6) | true on bluetooth-next (`mgmt.c` l.2462). `mgmt_status()` reads a positive value as an HCI status: 0x0a is "Max Number of SCO Connections", so it becomes `MGMT_STATUS_NO_RESOURCES`. The Mesh Packet Complete event carries no status, so nothing is visible | **not folded in:** CO-26 stays one change. Recorded as its own candidate one-liner (`-EBUSY`); whether to make it is the operator's call |
| 4 | CO-26 `Fixes:`: reviewers 2 and 3 prefer variant A (with `Fixes:`, no `Cc: stable`), reviewer 6 prefers B (a cleanup; a tag invites a backport for no gain) | — | the operator's decision; the split is recorded |
| 5 | `access-audit` is red. Five classes of access fall outside its allowlist: git reading `/etc/mailname`, `/etc/host.conf`, `/etc/hosts` and `/etc/resolv.conf` during a local `file://` clone, and `devtools/repo-scan` trying to read the private wording list. There are also two permission errors in temporary-directory cleanup (2, 3) | consistent with STATUS, Repository health (red since at least 11-16) | not a submission issue. To be fixed separately in the audit's allowlist and in `repo-scan`'s handling of a missing private list, with the full suite run in a container first |
| 6 | CO-22: two dates and the `btmtk.h` detail remain (6) | true | resolved by the send-day rebuild, as planned |
| 7 | Upstream "has not moved": bluetooth-next still `cf357cfc025e`, BlueZ master still `1adfe662efef` (6) | **no longer true:** fetched afterwards, bluetooth-next is at `5063a0717aa2` (15 new Bluetooth commits) and BlueZ master at `1608f8361`. New stable releases are out (7.3.6, 6.18.65, 6.12.119, 6.6.163, 6.1.193, 5.15.226, 5.10.275), and mainline is v7.4-rc4 | all testing is being redone on these tips (below), and `base-commit` lines will follow the tip on the send day |

**Testing redone on the current tips** (the operator's standard of 2026-11-23: a `Cc: stable` only after the
build and all relevant tests on every affected line, and the same suites on the development trees):
- **The patches:** CO-38 and CO-44, each alone.
- **The trees:** bluetooth-next, mainline v7.4-rc4, and 7.3.6, 6.18.65, 6.12.119, 6.6.163 and 6.1.193.
  Their `Fixes:` commits are in no 5.15 or 5.10 release.
- **The tests:** the new cases 3 times each, and all 13 BlueZ test suites, base against patched.
- **CO-43 1/3** on all seven tips, 5.15 and 5.10 included.
- **The record:** a version manifest per image, and the raw logs compressed with zstd.
