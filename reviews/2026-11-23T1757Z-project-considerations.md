# Considerations on the project as a whole (2026-11-23)

**What this is.** The reviewer's opinion, after the whole-project review of 2026-11-15, its
five rechecks, the upstream check of 2026-11-22 and the foundation-documents review of
2026-11-23. It is written from what those readings left in mind, with almost no new reading.
It is therefore **opinion with reasons, not findings with line numbers**: where a statement
rests on something that was checked, the earlier page that holds the check is the source;
where it is a judgement, it says so. Nothing here was run.

**How to read it.** Section 1 is the overview. Sections 2 to 8 take one subject each:
documents, the contribution pipeline, code and tools, tests, evidence, the way the work is
organised, and the direction. Section 9 is a short list of what I would do first. Sections
were appended one at a time; the last line of the file says whether it is complete.

## 1. Overview

**What the project is good at.** Three things stand out, and they are rarer than the code.

1. *It finds real defects and proves them.* The original hang was traced to its cause; one
   kernel fix and eleven BlueZ commits are released; three stable backports of another
   author's fix are released; the items still in preparation (CO-38, CO-44, the btusb series,
   CO-02) each have a reproducer that fails before and passes after. When the review looked
   for a contribution whose evidence did not hold, it did not find one.
2. *It corrects itself in the open.* Retractions are kept (`BRIEF.md` §5). When a review said
   something was wrong, the answer on `main` was a check on the file and then a fix or a
   reasoned "wrong", within hours, five rounds in a row. Where the reviewer was wrong, the
   record says so too, and it was right each time.
3. *It does the receiving side's work for them.* Stable lines built one by one, the list's
   own CI run locally on base and on base plus the patch, other authors credited by name.
   This is the right instinct and it is why what was sent was applied unchanged.

**Where it loses the most.** Not in the code. In three places:

1. *The same fact is written in many places and corrected in one.* Almost every finding of
   the review that mattered was of this kind, and each recheck found new instances created by
   the fixes of the round before.
2. *Preparation outruns sending.* Between 2026-10-28 and 2026-11-23 nothing was sent, while
   about fifteen packages were prepared, reviewed, re-prepared and re-reviewed. In that time
   five of them were overtaken by other people's applied fixes.
3. *The record is very large for what it has to carry.* About 140 MB and 7,000 files, most
   of it machine output; foundation documents of a megabyte that a reader is told to read
   first. The size is itself a cause of the first problem.

The rest of this page is about those three, and about smaller things on the way.

## 2. The documents

**The pattern.** The project has a rule for this and it is a good one: "`docs/STATUS.md` is
the one page that says what is current; do not add a second 'current' paragraph anywhere
else". In practice a current state is kept in at least these places: the README's direction
block, two blocks in `BRIEF.md` (the state block and the hand-off), the top paragraph and the
rows of `docs/STATUS.md`, the stacked "current state" blocks of `docs/issues.md`, the "What to
send" table and the index rows of `contributions/README.md`, every dossier's front page, and
dated working pages such as `rd-2026-11-14.md`. Each is corrected by inserting a dated note
into an existing sentence. After five rounds the pages are accurate where they were touched
and stale one paragraph away, and the notes themselves ("corrected 2026-11-15: this cell
still said …") have become a large part of the text.

**What I would change.**

1. *One fact, one home, and the other places point.* Decide for each kind of fact where it
   lives: the state of a submission in its STATUS row; which directory to send from in the
   "What to send" table; the machine in STATUS's machine section; what an issue is in
   `docs/issues.md`. Every other page names the place and does not restate the value. The
   README's direction block would then be five lines of prose and links; a dossier's front
   page would say what the contribution *is* (which does not change) and link to its row for
   its state (which does).
2. *Replace, do not annotate.* The hand-off block of 2026-11-23 is the proof: one rewrite
   removed six findings that four rounds of in-place corrections had not. The history of a
   sentence belongs in `git log` and, where the change of belief matters, in `HISTORY.md`. A
   row that carries three "corrected on" clauses is harder to read than the mistake was.
3. *Make the state block of `BRIEF.md` go.* The file says it is not the current snapshot and
   carries a snapshot of 2026-10-28 with corrections of six later dates. The foundation
   bullets, the rules and their reasons, and the retractions are what only this file has;
   they are about a third of it. The rest is STATUS's job.
4. *Give rows a fixed shape.* A STATUS row today is a paragraph of up to several thousand
   characters holding the whole history of the item. A row that fits on a screen (what it is,
   state, date of the state, next step, where the detail is) can be checked by a script and
   read by a person; the history goes to the dossier's log, which is append-only already.
5. *Generate what can be generated.* The exhibits index is generated from the exhibits and
   it is the one register that the review found consistent 97 times out of 97. The "What to
   send" table already has a checker. The same idea would serve the STATUS rows' dates and
   the contribution index: a small file of facts per item, and pages built from it. The
   project already writes this kind of script well.
6. *Write identifiers in full where they will be copied.* The rule exists; the newest
   hand-off elides directory names again. A check on added lines for an ellipsis inside a
   code span would end the argument.

**Size.** `HISTORY.md` is 418 kB, `docs/issues.md` 243 kB, `docs/STATUS.md` 186 kB. The
instruction "read this first, every time" is not followed by anyone who has a morning's
work to do, and a document that is not read drifts. I would set a size for the pages that
must be read (the README, the foundation part of `BRIEF.md`, a STATUS of short rows) and let
everything else be reference that is searched, not read.

**What is good and should stay.** The retraction table. The rules with their reasons. The
dated, never-edited review files. The exhibits. The practice of saying "not checked" and
"inferred". The habit of keeping a wrong statement visible as wrong. None of these needs to
be given up to get shorter pages.

## 3. The contribution pipeline

**What the numbers say.** Sent and accepted: one kernel fix, eleven BlueZ commits, three
backports, a stable request, two test reports, one vendor report, two gvfs changes. All but
the gvfs changes and CO-02 date from before 2026-10-29. Since then: about fifteen packages
made ready, at least four rounds of outside review on them, several regenerations, and no
send. In the same four weeks the maintainer of the subsystem fixed the mesh path himself and
another author fixed the advertising overflow; five of our packages became unnecessary.

**My reading of it.** The standard the project sets itself (no homework left for the
maintainers) is right. What has grown around it is a loop in which a package is never
finished, because each review round finds something, each fix needs a new round, and the
tree moves underneath meanwhile. Two things follow.

- *A small correct patch sent today is worth more to upstream than a perfect one in three
  weeks.* The patches that were applied unchanged (the BlueZ crash fixes, the `shared/mgmt`
  fix, the cleanups, the test-name fix) were all small, each with one claim and one test.
  That is the form that worked. CO-38 and CO-44 are of that form and have been ready, in
  substance, since 2026-11-14.
- *Being overtaken is not a failure of the work.* The mesh harnesses now test the
  maintainer's fix; that is a real contribution if it is reported as a test result. But it
  is also a signal: where others are already working on a path, the useful act is an early
  message ("we reproduce this, here is the reproducer, are you working on it?"), not a
  finished series a month later.

**What I would change.**

1. *One queue, one item in flight, a date.* The new hand-off has the queue. I would add to
   each entry the date by which it goes or the reason it does not, so that "ready" cannot
   last a month.
2. *Limit the review rounds before a send to one, and fix what it finds without a second.*
   The outside rounds found real things (the lock cycle in CO-02 v2, the rebind break in
   the btusb series). They also produce, each time, a longer list of wording points. After
   the first round the remaining risk is small and the list's own reviewers and CI are a
   review too; that is what they are for.
3. *Decide the open decisions.* D1 to D14 of 2026-11-02 are still open and gate sends. A
   decision that has been open for three weeks is a decision not to send; it is better made
   explicitly.
4. *Split by size.* Kernel one-liners with a tester case go alone and first. Series that
   touch locking (CO-02, the btusb resume path) go as RFC early, with the reproducer, and
   let the maintainers say which shape they want. This is also the polite order: it asks a
   small question before presenting a large answer.
5. *Check upstream at the start of work on an item and on the day of sending, by tree, not
   by patchwork state.* The project wrote this rule down on 2026-11-23. I would make it the
   first line of every dossier's log entry for the day.
6. *Count what reached users.* The project tracks delivery well for what it sent. The
   Ubuntu upload is the nearest thing to a user of this laptop: every fix in it is released
   upstream, the development release has them, Launchpad has no bug for any, and the bundle
   has been built since 2026-11-14. Filing it is the highest value per hour of anything on
   the list, in my judgement.

## 4. Code and tools

**The state.** About 240 shell, awk and Python files. The tools under `tools/` and `bin/`
are careful: probes are opt-in, the journal is read through one seam, the dangerous actions
have guards. The review's code findings were of three kinds, and all three are instructive.

1. *A clean answer from a check that could not look.* A boot that could not be read printed
   "0 timeouts"; an unreadable journal window "agreed"; a gate exited 0 when its tool was
   missing. The project's own rule names this ("ENUMERATED == 0 is a refusal"), and the fixes
   of the two rounds were good. The lesson I would keep: this defect does not come from
   carelessness, it comes from shell. A pipeline's status, a `grep` that finds nothing, a
   command substitution: each has a quiet failure that reads as zero.
2. *An unsafe action left reachable.* `uninstall.sh` reloaded the driver; the module-swap
   script still ran. Both are fixed. They were reachable because the safety rule lived in
   `BRIEF.md` and not in the code. A rule that matters should be a refusal in the program;
   prose is for the reason.
3. *Text about the code that the code had left behind.* Headers, usage ranges printed with
   `sed -n '2,18p'`, comments naming old behaviour. Small, many, and each one a place where a
   reader learns the wrong thing.

**What I would change.**

1. *Move the larger tools to Python.* `tools/bt-trial` is about 70 kB of bash and
   `tests/run-tests` is 925 kB of bash in one file. The three kinds of defect above are far
   rarer in a language with exceptions, real return values and a test framework. The project
   already writes good Python in `scripts/`. I would not rewrite everything; I would stop
   adding to the large shell files and port the two or three that carry the evidence
   (`bt-trial`, the SCO ledger, the archive tools).
2. *One exit-code convention, stated once and tested once.* 0 measured and clean, 1 measured
   and found, 2 could not measure. Many scripts now follow it after the fixes; a single
   helper and a single test over every script would keep it so.
3. *Print usage from one function, not from a line range of the header.* A third of the
   Low findings were a `sed` range that had gone stale.
4. *Fewer scripts.* `scripts/` holds about 125 files, many written for one day's question.
   The project's rule is to promote a script that is used twice and it is not followed. I
   would sort them into "kept and tested" and "the record of one run", and move the second
   kind beside the result it produced. A reader could then tell which ones are tools.
5. *No machine paths in tracked code.* Fixed in most places in the last rounds; a check on
   added lines would keep it fixed.

## 5. Tests

**The state.** The suite is the most unusual part of the project: every check is tied to a
defect that really shipped, the machine's commands are replaced by tripwires, CI runs it in
a decoy world that fails on any touch of the real system, and there is a mutation tool. The
rule "a new check must be observed to fail" is the right rule and the project applies it
more than most.

**What it costs.** One bash file of about 16,000 lines. The review found some thirty
assertions that could not fail, in a suite whose first rule is that they must be able to;
that is a low rate, and it is also what a file of that size produces. CI was red for days
four times, each time unread, each time because the suite refuses to run locally while a
trial is open, which on this machine is nearly always.

**What I would change.**

1. *Split the file by tool.* One test file per tool, beside the tool, run by the same
   runner. The parallel sections already are that split in all but name.
2. *Make the suite runnable while a trial is open.* The refusal protects the live trial,
   rightly. A container (the project built `devtools/ci-container` on 2026-11-22) or a
   separate worktree as the *default* way to run it would remove the cause of the red weeks.
   A check that cannot be run at the moment of committing is run by CI or by nobody.
3. *Make red CI loud.* The lesson is recorded four times ("a red badge nobody reads is the
   same as no CI"). I would have the save command refuse the next commit while the last
   push's run is red or unread, with one explicit override.
4. *Test the patches as the suite tests the tools.* The contributions have excellent
   one-off test records (the VM matrices, the kmemleak sweeps). They are run by hand per
   package and their scripts carry one machine's paths. One harness, in the repository,
   that takes a kernel tree and a patch directory and produces the base-against-patched
   table would turn a day of regeneration into a command, and it is the piece that would
   shorten the pipeline of section 3 most.

## 6. Evidence

**The state.** The exhibits are the best-kept part: a claim, the command, the output, the
exit status, whether it was redacted; 97 of them, an index generated from them, corrections
kept. The trials table is the weakest: numbers reused, rows lost at shutdowns, nine of
eleven later rows reading `failed` for a reason that is the closer's and not the
controller's.

**Considerations.**

1. *The result that matters is settled and small.* Twelve failures on the ROM firmware,
   none in 74 links with the firmware loaded, the entry upstream and in every stable line
   and in Ubuntu. The trial machinery was built to settle that question; it has. I would
   close the trial series with a short final note and stop the automatic trials, rather
   than repair a mechanism whose question is answered. What still needs watching (the
   start-up failure, the resume failure) is better served by the incident tool, which
   collects what happened after the fact and does not depend on a clean shutdown.
2. *Raw output in git.* About 130 MB of logs are tracked. The rule is that the incident
   window goes into git and bulk does not; the dossiers of November went past it (two of
   them hold 18 MB each of run logs). They are also where the paths of one machine live in
   thousands of files. A dossier needs the summary table, the script, and a checksum list
   of the logs; the logs can live where the capture archive lives.
3. *Checksum files that do not verify.* Several packages list files that are not in the
   tree. A checksum list is a promise; either the files are there or the list should say
   "kept elsewhere" per line.

