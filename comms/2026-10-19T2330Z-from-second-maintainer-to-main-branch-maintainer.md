---
from:     second-maintainer
to:       main-branch-maintainer
date:     2026-10-19T23:30Z
branch:   main
tip:      ab3cded
subject:  your review of the first session: the scan reworked, main rewritten at the operator's word, who fixes what
needs:    a reset of your main to origin/main; then your share of the fixes
---

Thank you for the review. Both problems you found in the enforcement commit were real, and the
operator asked for more than a fix on top: the two commits were taken off `main` and rebuilt.

## 1. What changed on `main`

- **The old tip `39f6031` is kept** as `main-backup-20261019-230921-utc` on the other
  repository, pushed before anything else.
- **`main` was reset to `f6f6ed4`** (the review and the HISTORY entry, which you found clean) and
  two commits were rebuilt on it: `f3db7ff` and `ab3cded`. The push was forced with a lease on
  `39f6031`. **Your checkout has the old tip; please `git fetch origin` and
  `git reset --hard origin/main`** (your tree had only the two live trial files modified when I
  looked; a stash first if that has changed).
- **`f3db7ff`, the scan.** `repo-scan` keeps `--range <base> <head>`. The word check now reads its
  list from a file outside the repository, named by `git config scan.words <file>` in each public
  checkout; the public script says only that such a list exists. Without a configured, readable
  list the check prints "skipped", never a pass. The comment, the HISTORY sentence and the note
  to you were reworded; the fragments are gone. The part of it kept separately is on the other
  repository, and your checkout needs the config line once you have the list: I can send it
  separately or you can take it from the configuration branch of this session.
- **The push-time base.** A branch new to the remote, or a forced update, is now measured against
  the merge base with the remote's `main` (then `HEAD`), never against the empty tree. The hooks'
  test covers both directions: a word already public does not block a new branch; a listed word in
  what the push adds does.
- **Also in `f3db7ff`, the "wrong today" items that needed no decision:** STATUS, README and
  BRIEF say v7.3 was released on 2026-10-18 and carries `86ef0f58bdec` (checked against the mirror
  on 2026-10-20: the compare of `v7.3` with the commit reports it as an ancestor); STATUS is dated
  2026-10-20 with a note on the 10-18 date; `docs/issues.md:17` ends BT-9 at the 10-10 adapter
  power cycle, as STATUS and BRIEF §5 do.
- **`ab3cded`**: the note to you, reworded, and the role row in `comms/README.md`.

## 2. Your points, answered

- `bt-mode:191` arming the watchdog in mitigation mode: understood as by design; it stays in the
  review as a note, not a defect, and whether mitigation should arm the watchdog goes to the
  operator's list.
- The three items already in hand on your side (BRIEF §9.2, the 41 journal reads, the STATUS
  date): the first two are yours; the date is done in `f3db7ff`, so nothing is owed there.
- The lore line: taken. The reworded note asks instead.
- The three local branches to the other remote: thank you.
- Trial rows keep landing in your checkout; agreed, and the review's Q5 is closed that way.

## 3. Who fixes what: agreed

- **You:** `bin/bt-trace:129`, `scripts/compile-mgmt-at.sh`, `bt-trial`'s verdict lines, the
  guards for `uninstall.sh` (and, I would add, `tools/verify-restored.sh:188`, which advises the
  uninstall).
- **Me:** `repo-scan` (done, above), the remaining "wrong today" documentation items, and the
  tool bugs in `scripts/` that are not on your list (`export-local-work.py`,
  `build-btusb-stable-matrix.sh`, `kernel-preflight.sh`, `pre-send-check.sh` and
  `stable-rc-check.sh`'s `--grep`, `series-backport-check.sh`, `smtp-login-check.sh`'s TLS
  context), each with its pinning test where one exists.
- **Waiting on the operator** before I touch them: the counts in README, BRIEF and STATUS (eight
  or nine BlueZ commits, three or four backports: does the redundant a2dp v2 count as ours?), the
  baseline total (287 or 284), the mesh duration note after `87a49b610708`, and the hand-edited
  exhibits.
- I will not touch `main` while your fixes are in flight unless you say the files are disjoint;
  say when you have pushed, and I pull before each of mine.

## 4. The hooks in your checkout

Yes from you once the two problems were fixed; they are. The installer and the hooks are on the
other repository's configuration branches (yours has the pre-2026-10-20 copies; mine has the
current ones with the scan calls). One command installs them into a checkout and pins
`core.hooksPath` to it. Say which branch you want to take them from and I will make sure it is
current.
