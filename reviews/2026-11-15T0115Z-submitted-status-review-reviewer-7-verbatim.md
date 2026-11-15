# Submitted contributions status — outside reviewer 7's answer

*Received 2026-11-15 in answer to `2026-11-15T0115Z-submitted-contributions-status.md` (at `48c147a`).
The text is kept as received, except for the reviewer's tooling marks, which
`scripts/review-text-clean.py` removes. What we checked, point by point, is in
`2026-11-15T0300Z-submitted-status-review-checks.md`.*

---

**I would revise this report before using it to authorize CO-02’s resend.** Its proposed two-patch layout is reasonable, but it understates an unresolved locking concern and overstates both the weakness of the testing and what explains the upstream silence.

I read the [report at `48c147a`](https://github.com/ivoitovych/qca9377-bt-hang/blob/48c147a/reviews/2026-11-15T0115Z-submitted-contributions-status.md), the prepared patches, supporting audits, and relevant upstream source at `da3cc02587c6`. I also confirmed that [mirror PR #1009](https://github.com/bluez/bluetooth-next/pull/1009) closed on November 11. Patchwork was inaccessible through my web tool, so I have not independently confirmed every live status or rerun the conflict tests.

**1. The most important omission is the unresolved locking argument.**

The [supporting audit](https://github.com/ivoitovych/qca9377-bt-hang/blob/48c147a/contributions/CO-02-sco-connect-reuses-closing-link/send-v2-review-fixes-20261114/cancel-sync-analysis.txt) describes this possible cycle:

| Execution path | Holds | Waits for |
|---|---|---|
| New SCO connect | `hdev->lock` | Running `disc_work` |
| Disconnect worker | — | `cmd_sync_work_lock` |
| Command cleanup callback | `cmd_sync_work_lock` | `hdev->lock` |

The relevant source supports these individual edges: `hci_cmd_sync_clear()` invokes destruction callbacks under `cmd_sync_work_lock`, and `add_ext_adv_params_complete()` takes `hdev->lock`.

However, the audit also contains an error: **`add_device_complete()` takes that lock only when `!err`**, so cancellation with `-ECANCELED` does not establish the claimed edge through that callback.

This needs a corrected reachability analysis. “`hci_conn_del()` already waits under the same lock” does **not** establish that another wait, in a different lifecycle phase, is safe. Nor does clean lockdep output settle a sequence the tests never exercised.

I am **not declaring a reproduced deadlock**. I am saying the evidence does not justify the patch message’s unconditional “The wait is safe.” Resolve this before treating the folded patch as ready to send.

**2. “Patch 1 was not exercised on the laptop” is factually wrong.**

The repository contains a [hardware test dated October 26](https://github.com/ivoitovych/qca9377-bt-hang/blob/48c147a/contributions/CO-02-sco-connect-reuses-closing-link/experiments/results-2026-10-26-hw-connect-twice.md):

- Three second-connect attempts returned `EBUSY`.
- The original Shure link stayed connected.
- Captured voice traffic continued without interruption.

The limitation is **no unpatched hardware control**, not no hardware testing. The accurate description is: *failure reproduced in the emulator; corrected behavior also exercised on hardware.*

That materially weakens the report’s “strong patch versus weak patches” narrative.

**3. The dependency conclusion is mostly right, but “separate” needs qualification.**

Reading the patches and base source supports keeping the prepared hold fix before the folded abort fix: the latter’s new failure path drops a caller-owned SCO hold that the former establishes for reuse.

But the prepared mismatch patch explicitly says it applies **on top of the pair**, and its hunk includes their new abort check. Therefore:

- It addresses a separate defect.
- It can be submitted in a separate thread.
- **The prepared patch is not independently applicable to the untouched base.**

Also, layout (b) does not repeat v1’s principal mistake: it already folds old patches 2 and 3. Its remaining drawback is adding another defect to the series. Those are different criticisms.

**4. Emulator testing and a kernel-dependent regression test are not inherently packaging mistakes.**

A debug delay can expose a valid production interleaving. The important question is whether it only widens an existing window or creates behavior the production kernel cannot reach.

Likewise, a regression test failing before its kernel fix is expected. The BlueZ framework change required a refresh; it does not establish that submitting the test alongside the kernel work was wrong.

Stable eligibility needs an individual justification. The stable rules require a real, tested fix and reject merely theoretical races; they do not impose a blanket requirement for physical-hardware reproduction. [The Linux Kernel documentation](https://docs.kernel.org/process/stable-kernel-rules.html)

**5. The explanations for upstream silence need softer wording.**

Several statements turn observations into conclusions:

| Report’s statement | What the evidence supports |
|---|---|
| Sashiko’s finding stalled the series | An actionable finding remained unanswered; its effect on maintainer attention is unknown |
| Maintainers are not taking mesh fixes | Several remain pending; the report itself identifies two accepted fixes |
| gvfs is waiting only for reviewer time | No review is visible; the reason is unknown |
| Single patches fare better | This snapshot counts revisions and differently aged submissions; it does not estimate eventual acceptance probability |
| Twelve tested packages would look like an untested flood | A large batch creates review load; equivalence to that criticized batch is speculation |

The November observations also do not establish a newly introduced automated-review gate: Luiz explicitly directed another SCO author to Sashiko findings on **October 7**. That supports responding to automated findings, without establishing why your series has received no human reply. [lore-kernel.gnuweeb.org](https://lore-kernel.gnuweeb.org/linux-bluetooth/CABBYNZK9Oy2iL5PosxRy1KPup0PgYDfPUxeHemjYjKyAUu4%2B=Q@mail.gmail.com/T/)

There are smaller accounting problems too: “seven submitted-but-not-accepted contributions” includes a completed stable-testing contribution, reports, and issue comments. Those do not share a meaningful acceptance state.

**My recommended course:**

1. **Correct and resolve the SCO locking analysis first.** Keep the unexplained debug-kernel hangs visible as unresolved evidence, without attributing them to the patches.
2. **Retain layout (a) provisionally:** hold fix plus complete abort/race fix, with the mismatch change separately identified and its dependency explicit.
3. **Explain the substantive resolution of Sashiko’s concern**, including why synchronization is safe—not merely that two commits were folded.
4. **Pace new submissions without requiring a human reply before every next one.** Otherwise an unanswered patch can indefinitely block unrelated, ready fixes.
5. **Keep CO-25 as a separate decision.** Sending a concise, evidence-backed clarification remains reasonable; this review does not authorize sending it.

The report identifies useful maintenance work. What it has **not** established is that CO-02 stalled because it combined “weak” emulator evidence with “strong” hardware evidence.
