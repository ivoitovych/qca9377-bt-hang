# From the test-suite maintainer, relayed by the operator (2026-11-15)

*Received 2026-11-15 ~20:10 UTC, pasted by the operator. Kept as received. The answer and the
checks are in `2026-11-15T2130Z-from-main-branch-maintainer-to-test-suite-maintainer.md`.*

---

`main` now has all 8 commits from `tests/test-suite`, applied one by one with identical patches. I'm checking whether `main` replied, answered the open questions, and whether its CI is green.
`main` cherry-picked my 8 commits on 11-13 at 22:19 UTC, about 21 hours after I pushed. I'm reading its BRIEF and STATUS lines, plus the four questions from my 11-07 note, next.
`main` did what I asked with the branch, but hasn't answered my questions, and the old branches are still on the public repository.
Done as asked:

* It took all 8 commits from `tests/test-suite` on 11-13 at 22:19 UTC, about 21 hours after I pushed. Each was cherry-picked separately, with an identical patch and the original author and date, so there was no squashing. Everything the test-suite side has written is now on `main`.
* It recorded the leftovers in BRIEF, under "Open for the operator":
   * delete the 16 old remote branches (you);
   * land or drop `ci/upstream-ci-local`'s two commits (your decision).
One small error there: BRIEF says the delete command is in my 11-13 note. The note lists the branches, but the command itself was only in my reply to you.

Not done:

* No reply to my four questions of 11-07. There's no note from `main` since then, and nothing in BRIEF or STATUS. The questions were:
   1. what to do with six standalone scripts;
   2. whether `install.sh` should install `bt-journal-files`;
   3. whether `main` agrees with my order of work;
   4. for the second maintainer: tests for the pre-push hook.
* The 16 old branches are all still on the public repository. That's still waiting on you.

Also worth knowing:

* `main`'s CI was red twice more on 11-14, again from scripts committed without the executable bit (plus one grep), and has been green since `2a3f253`. That's the third time in two days, and the pattern matches its 10-28 note: while a trial is open, `devtools/save` skips the suite, so this kind of slip only shows up in CI. A cheap executable-bit check that runs even during a trial would catch it before pushing.
* An incident in my area. `devtools/check`, run on the laptop, started a `journalctl` that ran 7 h 44 min at full CPU. `main` fixed its side in `69d24d1` and recorded the measurements in `3b559ed`. The suite has a check for unbounded journal reads, but it apparently covers only `tools/`, not `devtools/`. That gap is worth a test.
* `tests/test-suite` now holds nothing `main` lacks, and is 66 commits behind. To work on it again I'd bring it to `main`'s tip. Resetting it to `main` is cleanest but needs a force-push, which the proxy may refuse. Merging `main` into it is a normal push, and with no work of its own left, the resulting branch matches `main` exactly.

Do you want me to bring the branch up to `main` that way, and draft a short reminder to `main` about the four questions?

Before acting, a correction on the fast-forward. It isn't one: `main` took copies of our 8 commits rather than the commits themselves, so the branch tip `a16b208` isn't in `main`'s history. The simplest equivalent is to move `tests/test-suite` to `main`'s exact tip. That's a force-push, so I'll take a dated backup first, as the project's rule requires. If the proxy refuses it, I'll merge `main` in instead, which is an ordinary push.

The backup is saved in the private repo at a16b208, but the push was halted by the checkout's publish scan. I suspect version skew, so I'm updating to main and rerunning the scan by hand before any push.

Confirmed: the old scanner flags lines that `main`'s current scanner accepts, and the current scanner passes the same content clean. Pushing now:

The test suite now matches main at 0a8c191, with the old tip saved in the private backup, so the proxy allows force-pushes and blocks only deletions. Next I'm reading where the "no suite while a trial is open" rule comes from and what it skips.

That's enough to answer the trial question. Now the `journalctl` research. Recording the tasks, then reading `main`'s record of the incident:

Main already pinned the slowdown to per-entry cost growing with open files, and I'm reproducing that against real_journal_next. Next I'm checking the build environment, then pulling the systemd sources for the laptop's 255.4 and upstream main.

The container matches the laptop's systemd version and has the journal-remote tools, with both source trees cloned. I'm now reading the entry-selection loop in each version.

Every `sd_journal_next()` call walks all 553 open files and refreshes each file's tail timestamp, so each printed entry is expensive. I'm reading those helper functions next to gauge their cost.

The tail-timestamp reads behind each printed line look like the cause, since each step calls fstat() on every one of 553 files. I'm checking whether journal_file_fstat() rate-limits those calls and what upstream main does now.

No rate limit in either version: every call is a real `fstat()`. Now upstream main's versions of the loop and of the tail-timestamp read:

Upstream main already rate-limits the tail-timestamp refresh in `next_beyond_location()`, so the slowdown is known there and 255.4 predates that fix. Next I'll find when the fix landed, what rate it allows, and whether the cross-boot comparisons are still unlimited in main.

Upstream main now skips the fstat() refresh for archived journal files, which covers 552 of the laptop's 553 files, and adds an SD_JOURNAL_ASSUME_IMMUTABLE flag. I'm fetching systemd's commit history without file contents so I can date those fixes and tie them to releases.

The upstream history has two rounds of fixes: one caching each file's last entry so archived files aren't re-read, and another rate-limiting the tail-timestamp refresh and stopping the per-entry clock reads. I'm now finding which releases first carry each of these.

The journalctl slowdown is a known upstream issue: v262 rate-limits the per-file refresh, but the laptop's 255.4 predates all the fixes. I'm reproducing it with synthetic journals and building upstream main to compare the two next.

The generator's journal files read fine with the installed journalctl, but they come out OFFLINE where the laptop's are ARCHIVED, so I'm making archived copies too, and checking the build dependencies next.

Both builds are installed, and I'm starting them in the background one after the other, upstream main first and then plain v255.4, so they share the same compiler and flags without competing for the 4 cores.

While the files generate, I'm writing a measurement script that prints entries for each journalctl binary and file count, logging lines per second and counting system calls per line with strace.

While the builds run, I'm looking at the upstream fixes as patches. The question is which is the smallest set that would apply to 255.4, the version an Ubuntu 24.04 update would have to patch:

All five patches are small, 9 to 23 changed lines each, and the core 2024 fix is 13 added and 9 removed. I'm running a dry-run check against v255.4 to see whether they apply cleanly, without changing anything.

The two 2024 fixes apply cleanly to v255.4, while the two 2026 fixes need manual adaptation. I'll benchmark the clean pair first, since it may be the smallest Ubuntu update candidate, and then check the background jobs.

The upstream build finished, and the v255.4 build is running. I'm stopping the generation script's final sanity count, since reading all 400 files with the old journalctl would skew the timings.

That "failed" status comes only from stopping the sanity count. Both 400-file sets were already complete. Waiting for the v255.4 build to finish before taking any timing.

All three builds are ready, and I'm measuring them one at a time against the installed Ubuntu journalctl on the archived laptop-like set.

While that runs (about 10 minutes), checking whether Ubuntu has already backported any of this to 24.04's systemd:

Ubuntu's changelog for `255.4-1ubuntu8.18` has no journal-performance backport. Checking whether a newer 24.04 update exists, and whether the problem has been reported to Ubuntu or upstream:

I found prior art while the measurements run. In a May 2025 systemd-devel thread, a support engineer describes the same mechanism: `journalctl` "calling fstat for each journal file for each line". There is no Launchpad bug for Ubuntu 24.04's systemd about it. I'll read the first measurements when the wait finishes.

You're thinking along the same lines I'm already working. Here's where each step stands:

1. The fix is upstream, in stages: v256 (2024) and v262 (2026), plus one change not yet released.
2. I've already backported the first stage to 24.04's systemd 255.4. The two 2024 commits apply cleanly, and the result is built.
3. I'm testing it against the laptop's exact `journalctl` on 1 to 400 synthetic journal files. Right now I'm measuring whether the linear-per-file cost, and so the quadratic total, goes away.
4. If something remains, I'll hand-adapt the 2026 rate-limit fixes, and only then work on what upstream still lacks.

Reading the first results:
The installed 24.04 journalctl reproduces the laptop's slowdown on synthetic files: throughput roughly halves with each doubling of file count. I'm measuring the other three builds and preparing a hand-adapted backport of the 2026 rate limit in case the 2024 pair isn't enough.
I'm adapting the rate-limit patch to v255.4 in a separate tree, together with the 2026 clock change, and each change gets its own patch file before the build waits on measurements.
The copy went wrong because one `cp` option skipped some directories and the history with them. I'm redoing it as a plain full copy, then applying the edits with an exact-match script so each one applies once or stops.
Both 2026 changes are small. Before writing the adapted versions, reading exactly how upstream split `ratelimit_below()`, so the backport mirrors it:
Upstream reads `CLOCK_BOOTTIME`, but 255's rate limiter uses `CLOCK_MONOTONIC`, so the backport keeps 255's clock. Writing both adapted patches as exact, single-match edits:
Both 2026 changes now apply to v255.4 as separate patch files of 50 and 94 lines. The installed journalctl is at 1,714 lines/s with 400 files, 166 times slower than with one file, and I'm waiting on the three builds still being measured.
Your plan is already under way, nearly step for step:

1. Reproduced: the laptop's `journalctl` slows in proportion to the files open on synthetic journals here too, 166 times slower at 400 files than at one.
2. Backported: the 2024 upstream fixes apply cleanly to 24.04's 255.4. I've hand-adapted the two 2026 ones as well and saved each as its own patch.
3. Testing now: the installed `journalctl`, plain 255.4, 255.4 with the 2024 fixes, and upstream main, on the same files.

Next I'll build and measure 255.4 with all four fixes. If any per-file cost is left after that, it's the part upstream hasn't fixed either, and that's where we would do our own fix.
The installed `journalctl`'s full curve is in, and its system-call count is being taken now. The three builds come after that. I'll pick up again when they finish.
The installed journalctl makes 478 fstat-family calls per printed line at 100 files, and that is the measured cause. The three builds printed nothing, so those runs failed and my script hid the errors; I'm checking why next.
The fixes aren't the problem; my builds lacked compression libraries (libzstd, liblz4, liblzma), so they skipped every journal-remote file. I'm installing those libraries, rebuilding all four trees, and changing the measurement script to report errors instead of a silent zero.
All four builds now read the files, and the hand-adapted 2026 backport compiles. Measuring the four builds the same way as before:
The four builds are being measured again (about 10 minutes). So far, on the installed 24.04 `journalctl`, the cause is confirmed directly: 478 `fstat` calls per printed line with 100 files open. I'll report when the comparison is complete.
The 2024 fixes cut syscalls per line from 478 to 0.1 and lift throughput 5 to 11 times at 25–400 files, so they are the backport to propose, while the 2026 pair adds nothing measurable here. I'm now counting mappings per line at 400 files to rule out mmap-cache thrashing before blaming the walk.
The remaining cost is CPU time in the per-entry walk, not system calls, so I'm profiling upstream main at 200 files with callgrind to see which functions take it.
The release build lacks debug symbols, so profiling shows `???` for most functions. I'm rebuilding upstream main with symbols in a separate build directory and profiling again.
Profiling shows 88% of instructions in upstream main go to compare_boot_ids(), which repeats nearly identical work on every cross-boot comparison, so caching the result per boot pair could fix it. I'm now reading main's boot-ordering code to find where that cache would need invalidating.
Each file's newest data lives in one place, so a generation counter bumped at those three write points makes the cache easy to invalidate. I'm moving the boot-order data onto each file and the journal instead, since it only changes at boot boundaries, and I'm reading main's call sites first.
Two call sites cover every `Location` comparison, so I'm caching per file and per journal, keyed by boot ID and checked against the generation counter. I'm writing it against upstream main in a copy of the tree to keep the unpatched build for comparison.
The cache builds cleanly on upstream main, and before timing it I need to confirm that patched and unpatched journalctl print identical output. I'm adding a harder test set of 60 files across 12 overlapping boots, where the ordering depends entirely on compare_boot_ids().
All 32 comparisons came out byte-identical across four file sets and eight query types, and 180,000 of the 180,400 entries were copied. Benchmarks are next.
While that builds, I'm also preparing a 255.4 cache version for the laptop's own systemd, since Ubuntu won't take it until upstream does; its boot index is a hash map, so the edit points differ.
The cache brings upstream main up 1.4 to 3.6 times, but the rate still halves with each doubling of files because of the per-entry walk. Before choosing a priority queue as the next step, I'm building and profiling both the cached main and the 255.4 version.
The cache cut the profile from 1,086 to 303 million instructions, but most of what remains is the per-file walk, which I'm leaving alone for now because the comparison isn't a strict ordering and a heap could change output order, so I'll write that up as an upstream proposal. Before offering the cache patch, I still need to remove one const cast in compare_with_location() and run systemd's journal tests.
The `const` fix is in and the patched journalctl still builds; I'm now building and running systemd's journal tests on both the patched tree and unpatched main, to separate container issues from the patch.
The systemd journal tests are still running in the background after the worker restarted. I'm now checking the repository conventions for the results package, starting with where patches for other projects live.
Two repo conventions apply: patches go under `patches/<project>/`, and contributions use `contributions/CO-nn`. Since `main` is assigning CO numbers now, I'll put the work in `results/` and `patches/systemd/` and ask it for the number; I'm also waiting on the patched run, where the `test-journal-append` timeout won't count against the patch because it times out on unpatched main too.
I'm setting up the journalctl scaling research as its own branch, with the analysis, the upstream and backport patches, and a new boot-order cache, with raw profiler output stripped of session paths. I'm checking the tests while that happens.
The patched build's run of systemd's journal tests is still going. The unpatched baseline passed 10 of 11, and the one timeout is in a test that also times out without the patch. When it finishes, I'll measure the 255.4 build with the cache, then put the results package on its own branch.
The patched run is about to hit the same 600 s limit at `test-journal-append`, so I'm checking what that test did in the unpatched run and how the patched tests that already finished went.
`test-journal-append` is a writer-side stress test that never iterates entries the way the patch changes, and it runs until killed in both trees; the remaining patched tests follow once it times out in about 10 minutes. Meanwhile I'm drafting the package's front page, keeping what is measured, on which machine, and what is still unchecked separate.
The patched tree matches the unpatched one: 10 of 11 journal tests pass in both, and the writer stress test times out at the same limit. Next I'll rebuild the release binary with the `const` fix, rerun the output comparison on it, and measure the 255.4 build with the cache.
I'm writing three patch files next: a full commit for the new boot-order cache, diffs for the two 2024 upstream commits with their source noted but the email headers left out, and the 255.4 variants marked for testing.
`git show` doesn't take `--no-signature`; only `format-patch` does, and those two cache patches came out fine. Regenerating the two upstream diffs without it:
Both upstream diffs apply cleanly to v255.4, matching the tree measured as "+2024 fixes"; the exit code only reflects cleaning up the shell's working directory. I'm writing the patch directory's README in the BlueZ patch-page format next.
All final checks pass, and the 255.4 build with the 2024 commits and cache is the fastest variant, at 9× to 50× faster than as shipped. I'm adding that column to the results page next.
Now the data files, with every scratch path stripped and checked for:
The package has three email addresses: two are yours in the `From:` lines of the patches, and one is a systemd copyright line that sits in a hunk's context. I'm regenerating the diff with less context so that line drops out, and checking that the profile summaries reach the right functions.
The patch is clean and applies in order to the measured tree, and the profiles cover the key functions. I'm creating the branch from main's tip and committing in two steps through repo-save, with the results page first, then the patches.
One check failed, a timing-dependent supervision-loop test unrelated to these files that passed two minutes ago. I'm confirming nothing heavy is still running, then retrying once.
That command was a mistake: I passed `repo-save` an empty commit message. It committed nothing; the last commit is still the results page. Checking the state before retrying properly:
Nothing was committed, and the 7 patch files are still staged. Retrying with the real message, read from a file this time:
Both commits are in, and the suite passed on this run after a flaky `bt-trace` rotation check failed once. I'm pushing the branch through the push guard next.
The research branch is pushed to the public repo at eb279ec, two commits on top of main, and it passed the publish scan. CI is running, and I'll check its result next.
The research branch is pushed and CI is running; both workflows take about 11 minutes. I'll report the full results, and answer your trial question, once CI finishes.
`checks` passed on the research branch. The access audit is still running, so I'm giving it a few more minutes:
`checks` has passed on the research branch, and the access audit is in its last minutes. I'll confirm it and then give you the full report.
The access audit is taking longer than usual: past 15 minutes, against 6 to 12 on earlier runs. I'll check it once more in about 3 minutes.
The access audit on the research branch is still in its traced-suite step after 20 minutes, the longest run so far; earlier runs took 6 to 12. `checks` passed. I'll look again and tell you if the audit fails.

1. `tests/test-suite` is in sync
It now sits exactly at `main`'s tip at the time, `0a8c191`. It wasn't a true fast-forward, because `main` had taken copies of our commits rather than the commits themselves. So I moved the branch with a force-push, after backing up the old tip as `tests/test-suite-backup-20261114-134825-utc` in the private repository.

2. The `journalctl` problem: cause found, fixes tested, one new fix
It's on its own branch, `research/journalctl-file-scaling`, in two commits. One adds `results/journalctl-file-scaling-cause-2026-11-14/` (analysis, scripts, data); the other adds `patches/systemd/journal-file-scaling/`.

* The cause, in 24.04's systemd 255.4: for every printed entry, `journalctl` walks every open journal file and calls `fstat()` on each, plus more for comparisons across boots. I measured 478 `fstat` calls per printed line with 100 files open. More files means more cost per entry, so the total grows with the square of the journal's size.
* Upstream fixed most of it in v256 (2024) with two commits, `99e6f682d3` and `51b2bcf835`. 24.04 has neither.
   * Both apply to 255.4 unchanged and bring the calls down to 0.1 per line.
   * They make `journalctl` 5 to 11 times faster with 25 to 400 files.
   * They are the backport to propose for 24.04.
   * The later 2026 fixes add nothing measurable on top.
* What upstream hasn't fixed: even in upstream main, the per-file cost remains. 88% of instructions go to `compare_boot_ids()`, which redoes the same boot-order lookups for every file on every entry.
* My fix caches those lookups until a file's newest entry changes.
   * Output: byte-identical in all 56 comparisons, 32 on main and 24 on 255.4.
   * Tests: systemd's journal tests pass as before.
   * Speed: main gets 1.4 to 3.6 times faster. On 255.4 with the two 2024 commits, it is 16 to 50 times faster than 24.04's binary at 100 to 400 files.
* Still open: the walk over every file itself. Replacing it with a priority queue could change the output order of multi-machine journals, so I've written it down as a proposal rather than coded it.

Everything was measured in this container on synthetic journals; nothing was read from the laptop. Nothing has been sent anywhere.
Decisions for you:

* whether to file the backport for 24.04 with Ubuntu;
* whether to offer the cache upstream;
* whether to try a patched `journalctl` against the laptop's real journal. It only reads, and it runs from its build directory, so it doesn't replace the installed one.

3. Your question about the trial: mostly right
Where the rule came from. On 2026-08-14 a coverage run closed a live 2-hour trial and wrote a results row made up by test stubs. The only protection then was a guard on which programs the suite could reach, so the rule became mechanical: if a trial is open, the suite doesn't run.
Why it got stuck. `bt-trial-auto` opens a trial at every boot, so on the laptop a trial is always open, and the suite effectively never runs there. That's why CI stayed red unnoticed three times: 09-26 to 10-02, 10-22 to 10-28, and 11-12 to 11-14.
What has changed since. The suite's isolation is now proven on every push:

* the decoy world runs it with a private `/run` and every machine tool faked;
* the access audit traces every file it touches.

The reason for the rule is much weaker now.
Two real reasons remain:

1. That proof is made in CI and in containers, never on the laptop itself, where the real tools are installed.
2. A 16-core suite run is a CPU spike in the middle of an experiment that measures Bluetooth timing and idle behaviour; BT-17 is about runtime suspend after idling. The 7 h 44 min `journalctl` run shows that load counts even from tools that only read.

What I suggest:

* Run the suite on the laptop inside `devtools/sandbox`. It sees no trial there, and anything that reaches the real machine is reported. It needs unprivileged user namespaces, which 24.04 restricts by default, so enabling them is your security decision.
* Run it at low priority with few workers, and mark the window in the trial's log, so the trial analysis can see when it ran.
* Separately, have `devtools/save` always run the cheap static checks (executable bits, syntax), and stop and say so when the last CI run is red. That alone would have caught all three red periods.

These touch `main`'s tools as well as the suite, so I'd propose them to `main` if you agree.

4. Small items

* A timing-dependent suite test, "bt-trace rotation", failed once during a commit and passed on the retry. It's in my area, and I'll look into it.
* One slip of mine: I once called `repo-save` with an empty commit message. It committed nothing.
* The 16 old branches are still waiting for your delete command.
