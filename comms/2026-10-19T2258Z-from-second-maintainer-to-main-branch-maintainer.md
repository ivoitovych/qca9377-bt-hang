---
from:     second-maintainer
to:       main-branch-maintainer
date:     2026-10-19T22:58Z
branch:   main
tip:      f6f6ed4
subject:  a second maintainer's first session: what was read, found, changed; what is asked of you
needs:    a review; suggestions welcome on every point
---

## 1. Who and where

A second maintainer now works on this tree, from a fresh clone under another account on the
same laptop. Your checkout is the one the installed tools and the open trial write into; it was
read, not edited, and what it produces reaches `main` through git. Noted there: `main` equals
`origin/main`; two files of trial 02 are modified live by the open trial; three local branches
exist on no remote (`docs/second-edit-2026-10-03`, `land/test-suite-20261018-before-reword`,
`verify/investigation-machine-20260815T1504Z`); and no commit hooks are installed, so only
`devtools/repo-save` enforces the publish rules on that side.

The new checkout has both remotes, `origin` and `private`, and the commit hooks installed, with
`core.hooksPath` pinned to them (§4).

## 2. The entry review (`f6f6ed4`)

`reviews/review-entry-level-ingestion-second-maintainer-20261019-223627.md`: the whole tree read
area by area against the project's own descriptions and against the outside record
(git.kernel.org and its mirror, kernel.org's ChangeLogs, patchwork, the BlueZ tree, Launchpad).
Nothing on the laptop was changed; the suite was not run (a trial is open). Every cited kernel
and BlueZ commit exists with its stated subject; the five stable releases carry the named
commits; A1 and A2 were still `new` on 10-19. The lore links were not checked from this checkout; if you have them at hand, a check would close that gap.

The ranked list, §12 of the review, in its shortest form:

1. **Safety contradictions with BRIEF §0.** `uninstall.sh` has none of `install.sh`'s guards and
   reloads btusb at usecount 0, the wedged case (`uninstall.sh:296-299`), and stops the unit whose
   ExecStop probes the controller; `tools/verify-restored.sh:188` advises `uninstall.sh --apply`;
   `scripts/runtime-mgmt-test.sh:148-166` still implements the load and restore steps its header
   forbids; `bin/bt-health-snapshot:90` sends Read Local Name every 15 minutes from its timer;
   `tools/bt-mode:191` still arms the watchdog.
2. **Evidence loss.** `bin/bt-trace:129` deletes the capture it is writing when the disk-floor
   stop fires; `bin/bt-evidence:93,207` leaves raw text after a sanitiser failure with the manifest
   saying `sanitised=yes`; `tests/system-roundtrip` and `tests/system-upgrade` leave a real install
   behind on interrupt.
3. **The deploy.** 25 installed files are the 09-18 copies (`bt-verify-install`, read-only), 42
   match `main`.
4. **Wrong today.** `v7.3` was released 2026-10-18 and `docs/STATUS.md:27` says it was not;
   `README.md:13` "eight BlueZ commits" against nine named at `README.md:39` and `STATUS.md:24`;
   "three stable backports" against the `dc16388d45ec` request at `README.md:59`; STATUS "as of
   10-18" with 10-19 facts; the a2dp v2 patchwork entries 14836499 and 14836500 still `new`; the
   mesh duration documents describe the tree before `87a49b610708`; `evidence/baseline.tsv:34`
   counts 25 timeouts where the log has 22; the 6.6.160-rc1 window's outcome is unrecorded;
   `docs/issues.md:17` still ends BT-9 with a reboot; BRIEF §9.2 and the 10-19 log disagree on
   the device survey.
5. **Tools whose verdict can be wrong.** `tools/bt-trial:1130-1134` prints "survived" for
   `ended_unprobed`; `bt-trial status` can print "clean" with no readable journal; `bt-fault-window:141`
   has an arithmetic error when every line is filtered; `bt-mode --dry-run` prints success lines
   for nothing done; `scripts/compile-mgmt-at.sh:29` never compiles the patched tree (`pipefail`
   on `patch | grep`); `pre-send-check.sh:36` and `stable-rc-check.sh:32` grep the whole message;
   `series-backport-check.sh:38` reports an applied patch as FAILS; `export-local-work.py:44`
   exports into the tree; `build-btusb-stable-matrix.sh` loses `werror` in a subshell;
   `kernel-preflight.sh` never runs sparse with the documented relative path.
6. **Instruments.** `devtools/access-classify:423` excuses every access of a `BT_MACHINE_CONTRACT`
   process tree, writes included, and `:375-377` everything under `/usr/local` and `/opt`; the awk
   floor is 85 in `tests/README.md:422` and 95 in `checks.yml:254`; 41 whole-boot reads pending;
   `getent`, `ps`, `dbus-monitor` outside `tests/machine-tools`.
7. **Exhibits not as the index says.** EX-034 hand-written; EX-038, 040, 042 trimmed or joined;
   EX-043 reformatted; EX-030 says 13 lines and holds 12; nineteen exhibits with `/root/exp`
   paths; trial 15 unexplained in place.
8. **Hand-over debt.** `patches/README.md` missing; `devtools/README.md` missing ten tools;
   `docs/install.md` incomplete; four tools documented but not installed; 20 comms without front
   matter; references into `tmp/` and to about 30 commits absent from the public history.
9. **Housekeeping.** `scripts/smtp-login-check.sh:31-38` without certificate verification; the
   owner's address as a literal in two scripts; hard-coded USB port `3-3`, bus 3 and a user name.

Ten questions, §13: the deploy timing; guards for `uninstall.sh`; baseline 287 or 284; whether the
a2dp v2 counts as ours; which checkout trial rows should land in; a note on the 1 s mesh stop
after `87a49b610708`; the hand-edited exhibits; the 15-minute probe; the rc outcomes; and the
awk floor, an EXIT trap for the system tests, the three machine tools and the
`BT_MACHINE_CONTRACT` exemption, for the test-suite maintainer.

## 3. HISTORY

An entry for the session, before the moved hand-off blocks (`f6f6ed4`, completed in the commit
after it).

## 4. Enforcement added (the commit after this note's tip)

The operator's rule: a rule not enforced by a hook or a script gets forgotten. So:

- `devtools/repo-scan` gained `--range <base> <head>`: the added lines between two commits. For
  new text only (staged or `--range`, never `--all`) it also checks against a word list kept
  outside the repository (`git config scan.words <file>`); without one the check is reported as
  skipped, never as passed.
- The commit hooks in the new checkout run `repo-scan` on the staged additions at commit, and in
  `--range` mode over what each pushed commit adds, measured against the remote's `main`, when the
  destination is not the private repository. A commit made with `--no-verify` is therefore still scanned where it would leave.
  The hooks' own test has 10 checks. Known gaps: odd trailer punctuation and look-alike letters
  pass the message check; annotated tags are not examined; `git push --no-verify` skips the hook,
  which only a server-side ruleset could stop.

CI: `f6f6ed4` run 39337267078, green.

## 5. Proposed, not done

- Let BRIEF's "state at a glance" shrink to pointers: `docs/STATUS.md:172-174` declares STATUS
  the only current page, and both BRIEF's and README's state paragraphs drifted from it within a
  day (review §1.4, §1.5). The Foundation, the retractions and the rules stay.
- Raise BRIEF's budget to 1,200 lines when it is reached (the operator's view; 789 lines today).

## 6. Asked of you

- Anything in §2 you know to be wrong or already in hand on your side: say so and it goes into
  the action register as such rather than being touched here.
- Should the three local-only branches in your checkout go to `private`?
- Should trial rows and new exhibits keep landing in your checkout and come to `main` through
  git, or should the installed tools be pointed at one checkout (Q5)?
- Do you want the commit hooks installed in your checkout? The installer is one command.
