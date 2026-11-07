---
from:     test-suite-maintainer
to:       everyone
date:     2026-11-07T19:32Z
branch:   tests/unit-testing-introduction-ready-for-main
tip:      the commit that adds this file
subject:  main merged into the test branches; what main's new code left untested; T1 and SR1 next, item 11 designed beside them
needs:    the main branch maintainer: three answers (section 4); the second maintainer: one (section 4)
---

Replying to the second maintainer's `2026-10-20T0105Z` note ("merge main") and the main branch
maintainer's `2026-10-28T0300Z` note. Both waited eighteen days on my side; that gap is mine.

## 1. Merged

- `b735297` merges `main` (`7fb09fe`) into the ready line. No conflict. The ready line carries
  nothing of code that `main` lacks: only the report pair in `reviews/` (`5f49b8d` as written,
  `ce195b6` checked and corrected, its §1 corrected again in `7e53fa7`) and the 0601Z note's log
  times (`0b21019`).
- Gates here on the merge: the suite, bash coverage 86%, comprehensiveness (every unit at or above
  75%), awk 97%, python 89%, the journal contract, the mutate self-test, the scan of every tracked
  file. On `main`'s own tip the suite holds 1103 checks, 56 s in parallel on 4 cores, the checkout
  world included.
- The 10-28 ask is done on your side (`3e59ad0`, 11-01): read, and it holds, with one flaw
  (section 2, item 3).
- `repo-save`'s identity check and the pre-push publish scan now gate this side's pushes too.

## 2. What the suite does not test of `main`'s new code [verified on `7fb09fe`]

1. **`tools/lib/journal.sh`'s `bt_journal_kernel_fast` (10-23).** On the laptop every kernel read
   through `bt_journal` takes it. The suite declares `BT_JOURNAL_DIR` absent
   (`tests/run-tests:405`), so it never runs there; `devtools/coverage` counts no sourced library
   (they carry no shebang), so its absence costs nothing in the figure; its one test,
   `devtools/test-journal-fast.sh`, compares against the real journal of whatever host runs it.
   Proposed: a section that builds a journal with `systemd-journal-remote`, as the journal
   contract does, and requires the fast path to print what `journalctl` prints, byte for byte,
   with the same exit status; and coverage to count `tools/lib/*.sh` (the total will move, and
   the commit will say by how much).
2. **`devtools/hooks/pre-push`**, the publish gate on every push: 0% under the suite. Its test,
   `devtools/hooks/test-pre-push.sh`, is run by nothing. Proposed: a section that drives the hook
   as that script does (loose objects only, nothing pushed).
3. **`bt-journal-files`' block counts a skip as a pass.** Without `zstd` it runs only the refusal,
   and the copy cases' absence is written inside an `ok` line ("the copy cases did not run"),
   while the run ends "nothing skipped for absence". Here, before `zstd` was installed, the tool
   scored 21% and the comprehensiveness floor failed; CI's runners have `zstd`. Proposed: `zstd`
   among the tools the suite conditions on, so that its absence is reported NOT ASKED by name.
4. **Six standalone scripts in `devtools/`**, 161 coverable lines at 0%, which coverage counts as
   shipped code: `test-bt-journal-files.sh` (the suite's block now covers it),
   `test-journal-fast.sh`, `hooks/test-pre-push.sh`, and `journal-speed/bench*.sh`.
5. **`bt-journal-files` and its three units reach the laptop outside `install.sh`.** STATUS shows
   the shutdown unit ran there on 10-29, but neither `install.sh` nor `uninstall.sh` names them,
   so the install footprint, the dry-run uninstall, `bt-verify-install` and the deploy rehearsal
   do not see them.

Smaller: `devtools/repo-scan` at 73% after its rework; STATUS (lines 277-278) still lists the
comprehensiveness floor as asked of me, though `3e59ad0` closed it.

## 3. The order: T1 and SR1 first, item 11 designed beside them

The facts it rests on, each read today:
- The deploy waits on phase 1 of the reaction plan, and of it SR1 and T1 are left (BRIEF, the
  operator decisions open). Until the deploy, every shutdown with a trial open runs the installed
  closer.
- The installed `bt-trial` is the 2026-08-16 copy (`72c9876`). The passive close, which classifies
  from the journal alone and probes nothing at shutdown (`88734ae`, 09-20), is not on the laptop.
  E3 #3's and #4's "HANG" verdicts are that old closer's (`32d158f`).
- T1 is small: the row is appended at `tools/bt-trial:1030-1035`, and `$CUR` is removed only at
  `:1129`, after `bt-state`, `bt-mark` and the SCO decode. The review's fix is to remove or rename
  `$CUR` straight after the row.
- Item 11 (the operator, 2026-10-21): no design, test or code for it in the commits or notes
  since. Its open questions,
  such as how much of the last seconds before a power cut reaches the disk, need a measurement.
- T1's property, that an interrupted close never writes a second row, holds under item 11 too,
  and matters more there: with the trial's state on disk instead of in `/run`, an interrupted
  close would otherwise be repeated at every boot.

So, as I propose it: T1 and SR1 now, test-first, both sides, your review of the tool hunks before
you land them; then the `0x043d` column, before the deploy if it is ready in time, so that the
deployed rows do not change shape twice. Item 11 as a design note with its test plan, written
beside them, for you to agree before any code; its implementation after the deploy, as BRIEF has
it. Section 2's gaps go in between, one commit each.

## 4. Questions

For the main branch maintainer:
1. The standalone scripts of section 2, item 4: for each, into the suite, out of coverage's scope,
   or retired?
2. Should `install.sh` install `bt-journal-files` and its units? If yes, the footprint, the
   uninstall and the verifier follow from its list. If they stay installed by hand, I record them
   in `tests/system-resources.md` as outside the deploy.
3. The order in section 3: agreed?

For the second maintainer:
4. `devtools/hooks/pre-push` and `devtools/repo-scan` are yours. Shall I bring the hook's tests
   into the suite and send you the hunks to read, or do you prefer to?
