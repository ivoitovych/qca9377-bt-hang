# Which kernel patch to send first: five outside rankings, and our checks (2026-11-22)

**What these answers are.** Reviewers 1, 2, 3, 6 and 7 of the 11-14 round answered a second
question about the same document, `2026-11-14T0300Z-kernel-patches-ready-to-send-for-outside-review.md`.
The question was not "is it correct" but "which patch is the easiest first submission":
- small and obvious;
- little for a busy maintainer to hold in mind;
- no side work.

Each reviewer built a weighted scoring model and ranked the items. The answers were relayed by the
operator on 2026-11-22. They predate that day's upstream changes (`2026-11-22T1240Z-kernel-contributions-readiness.md`,
§1). The full texts are stored privately. This file keeps their findings and checks each one
against the state on 2026-11-22.

They are opinions to weigh, not verdicts. None of the five built or ran anything.

## 1. The rankings in one table

Each reviewer's own score (their scale), and their rank in brackets. "—" means the reviewer did
not score that unit.

| unit | R1 (1–10) | R2 (/100) | R3 (/100) | R6 (/100) | R7 (/100) |
|---|---|---|---|---|---|
| CO-38 kernel (Read Advertising Features) | 7.48 (5) | **96.2 (1)** | **98.8 (1)** | **90 (1)** | **98 (1)** |
| CO-44 kernel (timeout status) | **9.02 (2)** | 91.7 (2) | 97.4 (2) | 84 (2) | 93 (2) |
| CO-43 A (log a failed resume) | **9.05 (1)** | 85.3 (7) | 90.5 (4) | 71 (4) | 79 |
| CO-43 E (anchor under txlock) | 8.52 (3) | 87.4 (5) | 87.1 (5) | 62 (6) | 89 (3) |
| CO-22 (ASUS IDs, stable request) | 8.16 (4) | 86.5 (6) | 94.2 (3) | 83 (3) | 92 |
| CO-26 alone (stop on a failed add) | — | 89.7 (3) | 85.5 (7) | — | 77 |
| BT-25 alone (deferred skb leak) | — | 76.1 | 79.2 as packaged, **~92 if standalone** | 65 | 79 |
| CO-35 SCI request (7.3.y) | — | 87.7 (4) | — | — | 87 |
| CO-04 (mesh use-after-free) | 5.10 | 56.2 | 62.0 | 32 | 61 |

**Agreement.**
- Four of five put **CO-38's kernel patch first**, and all five put **CO-44 in the top two**.
  Reviewer 1 alone starts with A; it ranks CO-38 fifth for its tester bundle.
- All five keep the mesh items (CO-04, CO-05), CO-02 v2, CO-21, CO-35's ECRED backports and the
  held CO-43 patches out of the first wave.
- All five treat the stable requests (CO-22, the SCI fix) as a **separate channel** that does not
  load the Bluetooth maintainers.

## 2. Findings, each checked on 2026-11-22

| # | finding (reviewers) | check | state now |
|---|---|---|---|
| 1 | **Send CO-38's kernel fix alone**; hold or shrink the BlueZ test. Reviewer 6 said hold the 558-line test series; reviewer 7 said extract only the helpers its case needs (R2, R3, R6, R7). | The split was done on 11-14. Series A is the helpers plus the one case, with no duration cases. It is still a 478-line file, about 388 lines added. | **Open, actionable.** Send the kernel patch alone; the BlueZ test follows separately, and a smaller helper set is worth making (also asked in the 15:13Z document). |
| 2 | **Trim CO-44's notes below `---`** (R6, R7). Drop "if it was deliberate, please say" (R6, R7) and the `Link:` (R6). Keep the user-visible change statement. Reviewer 7: with plain prose its score rises from 93 to 97. | The packaged patch still has all five note paragraphs, about 235 words, and the `Link:` trailer. | **Open, actionable.** Text only; the dry run must be redone after the edit. |
| 3 | **CO-26 as its own patch** is an excellent early candidate once regenerated without CO-05 (R2, R3). | **Checked in today's code.** bluetooth-next `cf357cfc025e`'s `mesh_send_sync()` now takes `hdev->lock` itself, from the maintainer's `1d7a52778858`. So CO-05 1/2 is in the tree in substance. The failed-add path is unchanged: `err = PTR_ERR(adv)` is set, and the never-added mesh instance is still passed to `hci_schedule_adv_instance_sync()`, whose result replaces `err`. CO-26's 2/2 applies to today's tip **alone**. | **New candidate.** Regenerate CO-26 as a standalone patch on the tip, with a message that no longer depends on 1/2, then rerun its fault injection. Not re-tested today. |
| 4 | **BT-25 (the skb leak) standalone** becomes a first-tier patch, about 92 (R3; R6, R7 "repackage"). | Today's apply check: the leak fix **conflicts** without the BT-24 fix under it, on E and on the bare tip. | **Needs regeneration**, not only reordering. Alternatively, send the pair with the leak fix first (the 15:13Z document asks the same). |
| 5 | **A's message reverses the order of events**; correct it (R7). | Done on 11-14 (`A-review-fixes-20261114/`, reviewer 7's wording) and rate-limited. | Closed. A's dry run must be redone on the replaced file. |
| 6 | **CO-38's BlueZ case depends on the 506-line duration patch** (R7). | Fixed by the 11-14 split; series A no longer contains duration cases. | Closed (see 1 for the size). |
| 7 | **CO-35: keep the SCI request separate from ECRED; refresh the queues** (R2, R7). | Today all three commits are queued for 7.3 by the stable team itself (`queue-7.3`). | **Moot** for 7.3.y. The ECRED backports to 6.18.y, 6.12.y and 6.6.y remain. |
| 8 | **CO-22: refresh or qualify the queue claim** (R7). | Done today. Nothing is queued on any of the seven lines. The pair applies in its order to all seven current tips. | **Open:** the mail's date sentence and tip list are to be updated on the send day. |
| 9 | **CO-02 1/3 (the hold fix) is strong on its own**, but keep the series context (R3, R7). R7 scores the sleeping 2/3 as "ready in reviewed series". | Since 11-15 the sleeping 2/2 is withdrawn (it deadlocks with debug delays); v2 is 1/2 + a non-sleeping 2/2. | R7's "ready" for 2/3 is **out of date**. Keeping the hold fix inside v2 still holds. |
| 10 | **CO-04 is not a first patch** (all). | The maintainer's `1d7a52778858` (accepted 11-18) covers its ground. | **Superseded until re-tested** on the new tip. |
| 11 | **Pace: one small, complete patch at a time, several days apart**; not a batch (R3, R6, R7; also reviewer 6 on 11-14: lead with CO-44 and CO-38). The silence on CO-02 since 10-27 is not a rejection. The kernel's process documentation expects two to three weeks for a review and at least a week before a resend (R2, R6). | Consistent with the project's measured practice (`2026-09-22T1700Z-kernel-bluetooth-workflow-as-practised.md`: acceptance is usually silent). | Adopted as advice; the order is the operator's. |
| 12 | **Separate importance from queue order**: the valuable, heavy items (CO-02 v2, CO-04, CO-21, CO-35) go after a few accepted small ones (R2, R3, R6). | — | Advice. |

**Where they differ.**
- **A first or A fourth.** Reviewer 1 puts A first. It is the smallest patch and only adds a
  message. The others rank it lower, because "do we need this log?" is a fair question. Reviewer 7
  scored the old text, which has since been corrected.
- **E's place.** It is third for reviewers 1 and 7. Reviewer 6 puts it sixth: understanding it
  takes a concurrency proof.
- **CO-22 in the first wave or beside it.** It is easy for all five, but goes to a different
  audience.

## 3. What this changes

The readiness report of 12:40Z measured how much work is done. These rankings measure how easy
each patch is for a maintainer to take in. The two agree on the top:

| order (from the reviewers' consensus) | readiness 12:40Z | what is left before sending |
|---|---|---|
| 1. CO-38 kernel patch, alone | 83 | send commands and a dry run; the `Cc: stable` decision (D12 recommended it) |
| 2. CO-44 kernel patch, notes trimmed (then its BlueZ test the same day) | 89 | trim the notes; a new dry run; `Cc: stable`, `Link:` |
| beside: CO-22 stable request | 80 | the date and tip sentence; send commands and a dry run |
| 3. CO-43 A or E | 77 / 89 | A: a new dry run. E: ready (its dry run is to be redone after the Signed-off-by) |
| next: CO-26 standalone | new | regenerate on the tip, message, fault injection, bot checks |
| next: the BT-24/25 pair, or BT-25 regenerated alone | 80 | the operator's choice; send commands and a dry run |

Nothing was changed in any package, and nothing was sent.
