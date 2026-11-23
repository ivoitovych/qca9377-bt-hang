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

