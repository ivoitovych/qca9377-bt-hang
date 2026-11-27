# The reaction on `main` to the review pages of 2026-11-22 and 2026-11-23, checked (2026-11-27)

**What was compared.** The eight pages written on this branch on 11-22 and 11-23 (upstream
check, foundation-documents review and its recheck, project considerations, test suites
parts 1 to 3) against `main` at `5135be27` (2026-11-27 05:49), 85 commits after the last
recheck at `418331c7`. Each claim of a fix was looked up on the tip; two sent patches were
looked up in patchwork; bluetooth-next was fetched (tip `f57f78086a`, 2026-11-24).

## 1. In one paragraph

Every page was taken in, answered in writing and acted on, and the answers are accurate
where checked. The foundation-documents findings are fixed except one left on purpose; the
considerations were weighed point by point and several were followed in practice (one item
sent alone, upstream checked by tree first); the test-suite pages became a sub-project,
`bt-test-suites/`, with a plan that adopts their first steps. The main thing done since is
real: **CO-38 was sent** on 2026-11-26 with its BlueZ test. What remains open is what the
answers themselves call the operator's decisions, plus four small points in section 5.

## 2. Page by page

| page of this branch | reaction on `main` | checked |
|---|---|---|
| upstream check, summary and detail (11-22) | copied to `main`; results already taken into the register before 11-23 | summary identical; detail differs in two lines (section 5, point 1) |
| foundation-documents review (FD-01 to FD-21) and recheck | answered in `reviews/2026-11-23T0800Z-foundation-documents-review-findings-and-checks.md`: 16 fixed, FD-15/16/17/19 already gone, FD-20 settled (both commits are ancestors of `main`), FD-10 and FD-14 noted, **FD-07 left** | `README.md`: "three failures", `btusb_main.c`, "sent, with no maintainer reply", heading now dated 2026-11-27: true. `BRIEF.md`: CO-02 bullet carries a dated correction, the stale mesh sentence is struck: true. Full paths in the hand-off: true |
| project considerations (11-23) | copied unchanged; `reviews/2026-11-27T0000Z-project-considerations-checks.md` sorts every section into done, cheap and standing, or the operator's; a companion page from inside the work and a plan of further actions follow | the "done" items are borne out by the history: CO-38 went alone, the suite logs of 11-26 went to the private archive with checksums only |
| test suites, parts 1 to 3 | moved to `bt-test-suites/design/` as a sub-project with its own `README.md`; plan steps 16 to 18 adopt part 3's first contributions | the three copies differ from the originals only in the links between them (0, 2 and 4 changed lines); the README's summary of what exists upstream and what is missing matches part 3, including its corrections |

## 3. What the reaction did well

- **Each finding was re-checked before being changed**, and the answers say where the
  review was imprecise: FD-02's date (the commit date is 11-19, not 11-18) is corrected
  against the review, not copied from it.
- **FD-09 was fixed around a block that a test holds identical**, not by breaking the test.
- **Advice was weighed, not obeyed.** The considerations page proposed limiting review
  rounds; the operator decided the opposite rule on 11-27 (rounds continue until clean, one
  patch per round) and recorded it as a decision with its reason. That is the right way to
  treat an opinion.
- **The sub-project page states its own status honestly**: "a design, not a result", counts
  textual and approximate, nothing built or run.
- **The addendum of 05:00 corrects the plan the same morning** from the registers (the shape
  of CO-02 v2, the open questions of the Ubuntu bundle) without rewriting the plan.

## 4. What is still open, by the answers' own account

- **The state block of `BRIEF.md`** is corrected line by line but not rewritten; the answer
  says so and defers it to a documentation pass. The file is 1,166 lines against a budget
  of 1,200.
- **FD-07** (the `-44` kernel in proposed) was left; since then `7.0.0-44` was installed on
  the laptop (commits of 11-26), so the sentence is now simply out of date.
- **The Ubuntu bundle is still unfiled** (plan step 11), with decisions D3, D6, C1 and C2
  before it.
- **The overtaken mesh items** (CO-04, CO-05 1/2, CO-06, CO-12, CO-14) are not yet closed
  with one line each, and no test report on the applied fix has been sent (plan step 21).
- **CO-22's stable request is held** since Qualcomm's answer of 11-26; the upstream check's
  action list had it as ready, so that entry of the 11-22 page is overtaken by events.
- **The older short list** (old `send.sh` of CO-23, keeper ownership check, scan comment)
  and the long decision lists are named in the plan (step 20) and not decided.
- **This branch and the earlier review branch**: listed in the hand-off as a decision to
  take, not taken.

## 5. Four points for the maintainer

1. **The copy of the upstream-check detail page was edited** in one place (line 41: the
   names of two tools in a quoted trailer of another author's patch were replaced by a
   description; line 426 differs as well). The index says the pages are "copied unchanged".
   The edit is reasonable; the index line should say "one quoted trailer reworded".
2. **CO-38's kernel patch shows check `pending` in patchwork** (15026726, state `new`) while
   the record says "the CI's 15 checks all success" from the mirror pull request. Both can
   be true, since the two are filled separately; the STATUS row should name which one it
   read, so that a later reader does not see a contradiction. The BlueZ test (15027599)
   shows `success`. Neither is in bluetooth-next yet; its tip predates the send.
3. **`BRIEF.md`, CO-02 bullet:** the correction of 11-23 says "that v2 plan is history"
   directly after "the fold of 2 and 3". The addendum of 11-27 says v2 *is* 1/2 plus a
   folded, non-sleeping 2/2. A reader takes the bullet to mean the fold was dropped. What is
   history is the sleeping variant and sending the mismatch patch with it. (The review's
   FD-11 had the same imprecision.)
4. **Plan step 9 still says "fold patches 2 and 3" as work to do**; the addendum says it is
   done and stored. The plan is "left as written" on purpose, but it is the page the order
   of work will be read from; one line at step 9 pointing to the addendum would do.

## 6. On the considerations page: one remark

`reviews/2026-11-27T0000Z-project-considerations-checks.md` records about eight review
rounds for CO-38 on 11-26, the last four changing only text below the cut, and then the
decision to keep rounds going until clean. The decision is the operator's and is recorded
properly. The cost side is visible in the same history: 37 of the 85 commits in these four
days are CO-38 rounds for a one-line fix. The rule as now written (one patch or one
question per round) limits the width of a round but not the number; a stated end condition
for wording below the cut would keep the rule and cap the cost.

## Limits

One pass, about an hour. Read in full: the three answer pages, the sub-project README, the
plan and the head of its addendum. Read by lookup only: `README.md`, `BRIEF.md`, the
register. Not read: the seventeen CO-38 and CO-25 review pages (they answer other
reviewers), `docs/upstream-practice.md`, the changed dossiers. The count of privacy-related
strings on `main` was not repeated in a comparable way and is not reported.

---

Complete as of 2026-11-27, not edited afterwards.
