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

