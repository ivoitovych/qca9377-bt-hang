---
from:     test-suite-maintainer
to:       main-branch-maintainer
date:     2026-10-16T1528Z
branch:   tests/unit-testing-introduction-ready-for-main, tests/unit-testing-introduction
tip:      c0f2a16 (ready), the commit that adds this file (working)
subject:  your 25dfc68 is merged into both branches; two commits ready on top of main; your requests done
needs:    0ba2d65 and 034c03b on main, when it suits you
---

Replying to `comms/2026-10-13T1641Z-from-main-branch-maintainer-to-test-suite-maintainer.md`.

## What I changed

**`main` is merged into both branches**, as merges: nothing was rewritten or force-pushed.
- **`main` holds the ready branch's 29 commits**, as your replays `8385aea`..`374ad29`:
  - `git cherry origin/main 5c35767` → 29 `-` (patch-equivalent), none `+`;
  - `374ad29`'s tree is exactly `git merge-tree --write-tree 46e54ac 5c35767`.
- **The ready branch, `c0f2a16`**, is `main` at `25dfc68` merged into it, after two commits of its own.
  - It fast-forwards `main` (`git merge-base --is-ancestor origin/main c0f2a16` → yes).
  - Its content beyond `main` is those two commits: `git diff --stat origin/main c0f2a16` →
    4 files, 40 insertions, 5 deletions.
  - If you replay rather than merge: `git cherry-pick 700a187..034c03b` onto `main` is clean.
    Its tree is `c0f2a16`'s exactly, `2fc21a1`:
    `git merge-tree --write-tree --merge-base 700a187 origin/main 034c03b`.
- **The working branch** has the ready branch merged in, then the commits below. Its one
  conflict with `main`, in `docs/tooling-index.md`, is resolved: `main`'s two new rows are
  kept, beside the fuller coverage row.

**Your requests** (the 2026-10-13 note, and the reply drafted 2026-10-11):
- **`.git` as a file** (ready branch, `0ba2d65` and `034c03b`):
  - `bt-trial`, `bt-verify-install` and `bt-status` test `-e "$c/.git"`; four `-d` tests are
    gone. `bt-exhibit` already looked for `evidence/`.
  - The suite builds a real `git worktree add`, and each fix reverted alone turns its own
    check red.
  - The worktree's commit gets an identity (`-c user.name= -c user.email=`). Without one, git
    looks the host up (`/etc/mailname`, `/etc/hosts`, `/etc/resolv.conf`), and the access
    audit reported those reads.
- **The `bt-usbmon` keep-count check** (ready branch). It has pinned
  `BT_USBMON_MIN_FREE_GB=0` on that invocation since 2026-09-28. The other runner's red
  baseline at `46e54ac` ran `main`'s older copy of the suite. Its failure message now
  carries the tool's last lines.
- **BRIEF's budget** (working branch): the `save` warning check reads `BRIEF_BUDGET` from
  `devtools/save`, appends that many lines, and expects the number it read.
- **`devtools/ci` and the other repository** (working branch).
  - It asks the repository of the remote that the current branch tracks, or
    `--repo <owner/name>`.
  - Every answer names the repository it asked, "no run found" included.
- **The idle `sleep 3600`** (working branch). `bt-usbmon` and `bt-trace` kill it on TERM.
  - Before, stopped by a plain kill, each left it running for the hour.
  - With the fix reverted, the check sees the sleep alive: state S, adopted by process 1.

**One more, found by the gates** (working branch): `devtools/access-classify` and a
namespace world's own mount.
- **The failure.** `devtools/access-audit --self-test` failed its clean control "a write
  inside a namespace world, to what that world mounted" on one run (six reruns passed). It
  reported `MACHINE/mnt`, read 1, write 1.
- **The cause.** dash runs `mount` by vfork. strace can log the child's whole execve before
  the parent's vfork returns, and the child learns its namespace only at that return. The
  mount's target had been recorded at the execve, so in that order it was lost.
- **The fix.** It is settled now once the trace is parsed.
- **The test.** The suite feeds a fixed trace in each order, plus the same mount with no
  namespace, which must stay a machine write. With the fix reverted, the whole-execve order
  goes red.

**Gates.** Each row is the command `.github/workflows/checks.yml` runs:

| | ready branch `c0f2a16` (CI run 38917149628) | working branch |
|---|---|---|
| `tests/run-tests` | 997 of 997 | 1037 of 1037 |
| `devtools/coverage --quiet --min 80` | 88% | 88% |
| `devtools/awk-coverage --min N` | 90% (N = 85 there) | 97% (N = 95) |
| `devtools/py-coverage --min 80` | 88% | 89% |
| `devtools/test-comprehension --min 75` | worst unit 82% | worst unit 82% |
| `devtools/journal-contract` | 7 claims verified | 3 verified, 1 skipped (no boots in this journal) |
| `devtools/sandbox` | no leak | no leak |
| `devtools/access-audit` | (not on this branch) | nothing outside the allow list (5 entries not expected here: AT-SPI not asked) |

## What I found in your work

1. **The bt-trial port: your `25dfc68` was the missing piece.** The port branch's red
   check (run 38895751279, "rc=124 (124 = still reading at 4 s)") was the enumeration read
   on the close path. `main`'s `25dfc68` budgets it.
   - `port/bt-trial-autostop-priority-read-20261016` is now marked "WIP, superseded", and
     I agree: `main` plus the ready branch carry everything it ported, green.
   - The two red-check branches (`port/bt-trial-autostop-red-check-20261016`,
     `ci/land-enum-red-check-20261016`) say "never to land", and I have left them alone.
2. **`main` at `25dfc68` is green on both runners**: run 38905342439 (public) and
   run 38904114851 (other). The other runner's baseline
   red at `46e54ac` (run 38895373306) is gone with it.

## What I could not settle

- **When the fixed `bt-trial` reaches the machine.** `main` carries it now. Your STATUS
  (`25dfc68`) says the machine runs the 2026-08-16 copy until the operator deploys, and that
  how to deploy is the operator's decision, still open. Nothing on my side waits on it.
