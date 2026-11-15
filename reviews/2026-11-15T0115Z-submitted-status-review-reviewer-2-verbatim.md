# Submitted contributions status — outside reviewer 2's answer

*Received 2026-11-15 in answer to `2026-11-15T0115Z-submitted-contributions-status.md` (at `48c147a`).
The text is kept as received, except for the reviewer's tooling marks, which
`scripts/review-text-clean.py` removes. What we checked, point by point, is in
`2026-11-15T0300Z-submitted-status-review-checks.md`.*

---

# **Review — Upstream contribution status, 15 November 2026**

**Verdict: The investigation is substantially sound, but I would not approve the proposed CO-02 v2 for immediate submission without additional technical review.**

The maintainer has done valuable work here. I verified the committed status report, inspected the prepared CO-02 v2 kernel patches and their test documentation, and checked relevant upstream discussions.

My assessment separates three questions:

- **Status investigation:** Good. The report distinguishes upstream acceptance, automated feedback, human responses, and outstanding work much more clearly than before.
- **Technical preparation:** Considerably improved. Folding the abort and synchronization fixes addresses the automated review's central objection. The testing is also more substantial than the summary initially suggests.
- **Submission strategy:** Needs adjustment. There are remaining concurrency concerns, a known neighboring bug, and a risk of sending patches with dependencies that upstream has not accepted.

## **1. CO-02: the central finding**

Priority: High — review before resending

The revised two-patch series is a better design than v1:

| Patch                   | Purpose                                                            | Assessment                                                              |
| ----------------------- | ------------------------------------------------------------------ | ----------------------------------------------------------------------- |
| v2 1/2                  | Restore correct SCO hold ownership                                 | Strong, focused fix                                                     |
| v2 2/2                  | Reject aborting connections and synchronize with disconnect work   | Justified fix, but concurrency concerns remain                          |
| Separate mismatch patch | Prevent a second socket from overwriting existing voice parameters | Valid independent defect, but dependent on the preceding implementation |

The test evidence is meaningful. With the two-patch series, all 33 relevant `sco-tester` cases pass, compared with 31 on the unpatched kernel, across three runs. The additional parameter-mismatch cases pass only after the third patch. The preparation also reports successful `mgmt-tester`, `iso-tester`, and extensive `l2cap-tester` testing.

These are useful regression results, not merely speculative emulator demonstrations.

However, there are two issues I would examine before resending.

### **Finding A — A possible lock cycle remains unresolved**

The second patch introduces:

```
cancel_delayed_work_sync(&sco->disc_work);
```

inside `hci_connect_sco()`, called while `hdev->lock` is held.

The accompanying investigation identifies a possible dependency cycle:

```
Thread A:
  holds hdev->lock
    waits for sco->disc_work

Disconnect worker:
  waits for cmd_sync_work_lock

Thread B (controller teardown):
  holds cmd_sync_work_lock
    waits for hdev->lock
```

The maintainer argues that the same lock ordering already exists in `hci_conn_del()`. That is a useful observation, but **an existing lock-ordering risk is not proof that adding another blocking site is safe**.

The analysis establishes a plausible cycle, not a demonstrated deadlock. I would require either a stronger reachability argument excluding the cycle or a targeted test before approving this as a stable-worthy correction.

### **Finding B — Wentao Liang's patch is more than a textual conflict**

I independently inspected Wentao Liang's November 4 submission.

His patch identifies a concrete failure path where a newly created SCO connection has no hold, `hci_conn_link()` fails, and the existing error handling calls `hci_conn_drop(sco)`. That can underflow the hold counter and leave a connection retained.

The CO-02 v2 patch 1 still contains that error path, although it restructures the surrounding code.

This matters because the conflict is not merely overlapping lines: it involves a valid cleanup issue in precisely the code CO-02 is modifying.

I would have the maintainer prepare and test a combined variant against Wentao's change now, rather than simply waiting to see whose patch merges first. That does not mean taking ownership of the other author's fix; the overlap and attribution should be handled explicitly.

Sources: [Wentao Liang's SCO patch](https://lore-kernel.gnuweeb.org/linux-bluetooth/20261104022807.1484114-1-vulab@iscas.ac.cn/); [Original CO-02 kernel CI pull request](https://github.com/bluez/bluetooth-next/pull/1009).

## **2. Additional issues in the CO-02 v2 preparation**

### **The**`abort_reason`**audit is incomplete**

The patch introduces `WRITE_ONCE()` for `conn->abort_reason` and `READ_ONCE()` at the two new checks.

However, the accompanying audit identifies an existing ordinary read at the beginning of `hci_abort_conn()`.

I would apply the prepared `abort-reason-readonce.diff`, or obtain a clear justification for leaving that read unannotated. This is a small consistency improvement in a patch whose correctness depends on concurrent access to that field.

It does not, by itself, make the complete concurrency protocol safe.

### **Stable backport dependencies need explicit treatment**

Patch 1 can be applied to older stable trees independently. Patch 2 cannot: it uses the hold ownership behavior introduced by patch 1.

That means a stable maintainer must not backport patch 2 in isolation, even if its `Fixes:` tag identifies an affected release.

The cover letter should explicitly identify this dependency for stable backporters.

### **The third patch should remain separate for now**

The mismatch patch addresses a genuine defect. The tests show that a second socket can overwrite the first socket's requested voice setting while still receiving `EBUSY`.

Nevertheless, its current patch file applies on top of the CO-02 v2 series. It is a separate defect, **not yet a standalone patch against upstream**.

I would keep it prepared, but wait until the underlying connection-reuse series is accepted or at least receives a substantive review.

The two corresponding BlueZ tests should follow the kernel changes they require, ideally once the appropriate kernel implementation is available to their CI environment.

## **3. CO-25: I would answer Qualcomm**

Priority: High — communication task

I read the prepared `reply-1-zijun-hu-v4.eml`.

It is technically reasonable and respectfully written.

Its strongest feature is the distinction between the chip classification and the actual Linux driver behavior.

The reply establishes that `btusb` currently handles the specified USB IDs using `BTUSB_QCA_ROME`, that the measured controller loads particular firmware files, and that the kernel reports a particular ROM/firmware version combination.

It then asks Qualcomm whether this is intended and whether a known firmware erratum could explain the SCO hang.

That is a legitimate technical question, not an attempt to argue about marketing classifications.

**My recommendation is to send the reply after your approval.**

I would not leave this thread unanswered merely because Qualcomm's first answer challenged the original classification.

Seventeen days is not disastrous in kernel development. But having a prepared technical clarification sitting unsent creates unnecessary delay.

No reply has been sent as part of my review.

## **4. The interpretation of upstream behavior needs more care**

### **Automated reviews are influential, but not necessarily a formal gate**

I verified an example from November 12: Luiz Augusto von Dentz explicitly directed Jens Willmer to Sashiko's findings on his pending btusb patch.

So the report is correct that maintainers are actively referring authors to automated review results.

But the stronger claim that an unanswered Sashiko finding is blocking CO-02 remains a hypothesis.

There is no human response to CO-02 establishing that as the reason for its lack of acceptance.

I would change the report's classification from an established blocker to a **probable review obstacle**.

Likewise, neither the 22% versus 15% acceptance statistics nor the objection to another author's large submission batch demonstrates that smaller patches are inherently more likely to be accepted.

Those observations are useful for planning, but should not be treated as causal evidence.

### **One kernel submission at a time is too restrictive as an absolute rule**

If CO-02 remains unanswered for another month, it would be counterproductive to freeze every independent contribution.

I would distinguish between avoiding a submission flood and waiting for acceptance before doing anything else.

A reasonable approach is to keep only one complex series under active revision, while allowing an occasional small, independent, well-tested patch into upstream review.

This makes CO-44 or CO-38 reasonable candidates without making CO-02 disappear from the active queue.

## **5. Review of the other contributions**

| Contribution           | My assessment                                                                                                                    |
| ---------------------- | -------------------------------------------------------------------------------------------------------------------------------- |
| **CO-25**              | Respond to Qualcomm; the draft is ready for your decision                                                                        |
| **CO-04 / mesh**       | An outstanding syzbot UAF deserves technical attention; do not hold indefinitely just because other mesh submissions are pending |
| **Hui Peng Tested-by** | No action required; the original patch dates to September 19, explaining the reported 57 days                                    |
| **gvfs !368 / !369**   | Waiting is appropriate; eight days without a review is not yet unusual                                                           |
| **BlueZ #1554**        | Leave open and observe; no new action unless additional reproducible evidence appears                                            |
| **CO-43**              | Keep D v2 held; compare B2's eventual integration against Jens Willmer's pending suspend changes                                 |
| **Stable 6.6.160**     | Completed; exclude from the active pending-work total                                                                            |

For CO-43, Jens Willmer's patch has a concrete Realtek hardware reproducer and a maintainer response. This is worth monitoring independently of whether its exact proposed implementation is eventually accepted.

There is also a small reporting problem: the committed status table contains rows split across physical Markdown lines. Those should be corrected so the table renders reliably. I would separate *waiting for maintainer review*, *waiting for our action*, *monitoring*, and *completed* rather than placing them under the broad description of seven unaccepted contributions.

## **6. Recommended course of action**

**First: finish the CO-02 concurrency review.**

Resolve or convincingly bound the possible `cancel_delayed_work_sync()` lock cycle, complete the `abort_reason` audit, and test integration with the neighboring SCO cleanup patch.

**Second: close the CO-25 communication gap.**

Send the prepared technical clarification if you approve it. There is no need to wait for CO-02.

**Third: resend CO-02 as v2 after the checks pass.**

Prefer the two-patch layout, document the dependency and evidence clearly, add the required author-approved `Signed-off-by`, and rerun the current upstream CI. Keep the parameter-mismatch change separate.

**Fourth: resume small independent submissions at a controlled pace.**

CO-44 or CO-38 may be appropriate, provided their own technical review is complete. Give automated review findings prompt attention without treating every automated observation as automatically correct.

## **Final assessment**

I would rate the work in two separate dimensions:

Status investigation

# **8.5/10**

Clear chronology, useful cross-project checks, good acknowledgment of invalid preliminary results

Submission readiness

# **6.5/10**

Strong test preparation, but important concurrency and integration questions remain

There is one broader conclusion I want to emphasize.

**The original CO-02 submission was not necessarily a bad contribution. It was a technically substantial contribution packaged in a way that made evaluation unnecessarily difficult.**

Patch 1 has a straightforward ownership argument. Patch 2 has a genuine observed failure and a plausible synchronization correction. The tester provides meaningful evidence distinguishing behavior before and after the patches.

Those are real strengths.

The problem is that complicated lifetime management, concurrent work cancellation, and multiple independent defects were presented together, with one incomplete intermediate fix. Splitting the work correctly and answering the automated review is therefore a significant improvement.

I would not abandon CO-02. I would also not rush it merely because it has already been pending for 19 days.

The most important result of this review is that **CO-02 is worth pursuing, but the remaining concurrency question deserves stronger scrutiny than its current submission plan gives it.**

The upstream-status report is available in the verified [November 15 review at commit 48c147a](https://github.com/ivoitovych/qca9377-bt-hang/blob/48c147a/reviews/2026-11-15T0115Z-submitted-contributions-status.md).

I independently verified the available GitHub and mailing-list evidence and inspected the prepared patch files. I did not rerun the kernel tests or independently retrieve all Patchwork and GNOME GitLab status records, so those portions of the status assessment still rely on the maintainer's recorded checks.
