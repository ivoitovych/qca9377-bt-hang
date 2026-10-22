# CO-02 — from-scratch reviews of `d7b011d` (reviewers 1 to 4)

*Received 2026-10-22. Kept as received, except for the reviewers' tooling marks, which
`scripts/review-text-clean.py` removes, and the page-layout markup and citation codes in the texts
of reviewers 2 to 4. Reviewers 5 and 6 had not answered when this was recorded. What each point
led to: `../log.md`, entry "from-scratch review of d7b011d".*

---

---

## Reviewer 1

**This is a high-quality, well-prepared submission candidate that is useful, follows kernel and Bluetooth community practices closely, and is designed to minimize extra work for maintainers.**

### Overall usefulness and impact
The series addresses a real, reproducible race/window in SCO connection handling that affects users. When a SCO socket is closed and a new one connects to the same peer before the Disconnection Complete arrives, `hci_connect_sco()` reuses the dying connection by type+address only. The new socket reports success without a Setup Synchronous Connection being sent, then gets closed with `ECONNABORTED` when the event arrives. PipeWire does exactly this on HFP codec switches during a call; with headsets that answer `AT+BCS` quickly, the new codec never gets a link (matching the original U7/EX-060 observations).

A second related defect is fixed: a second `connect()` to a live SCO link fails with `EBUSY` (correct) but drops the hold of the socket that owns the link, causing the first link to be disconnected via `hci_conn_timeout()`. A third patch closes a narrow timeout race where an already-running `hci_conn_timeout()` worker that saw no holder can still abort a connection a new connect has just taken.

The cover letter is honest that the series makes `connect()` report reality promptly but does not by itself make PipeWire’s immediate retry succeed (the retry still lands in the window). It offers a deferral prototype as a possible RFC if maintainers prefer that semantics. This is the right level of honesty for a core networking subsystem used by millions of devices.

### Adherence to written rules, style, and form
- **Format**: Proper `git format-patch --cover-letter` series with a clear cover, sequential patches, and a separate BlueZ test mail. Subjects are precise and descriptive.
- **Commit messages**: Excellent structure. They state the symptom, the historical cause (with specific commits), the current code behavior, the proposed change, and the result. Sentences are checkable against the code and history. This is the opposite of “a bag of forensics.”
- **Tags**: `Fixes:` tags point to the introducing commits (`8a5b0135d4a5` for the hold issue; `e6720779ae61` for the reuse-after-kref change). `Cc: stable@vger.kernel.org` (with a `# 6.6.x` note on the first patch) is justified by the stable-line analysis. `Signed-off-by` is present.
- **Coding style**: Small, focused changes confined to `hci_conn.c`. Comments explain the non-obvious refcount and race handling. Evidence reports `checkpatch --strict` clean (0/0/0) and BlueZ CI (am/checkpatch/gitlint) passing.
- **Recipients and process**: linux-bluetooth, with copies to the relevant maintainers (Marcel Holtmann, Luiz Augusto von Dentz) and authors of the related commits, plus a note about Hitalo Souza’s pending series. Order (kernel first, BlueZ test same day) and dry-run notes are sensible. Independence from other pending work is stated.

This matches the expectations visible in recent linux-bluetooth traffic: clear problem statements, proper `Fixes:` tags, testing notes, and no unnecessary churn.

### Clarity for a busy (or tired) maintainer
The prose is unusually clear and well-structured. The cover letter opens with the user-visible failure, explains the three patches in order, describes testing, states what the series does *not* fix, and explains stable applicability. Individual messages follow a consistent “what happens → why → what we change → result” pattern. A maintainer can understand the intent, the history, and the limits without having to reverse-engineer the patches or dig through long logs first. The “grandma with a hangover” bar is essentially met.

### Testing and homework done on the contributor side
This is a strength. Evidence (results-2026-10-22-v3.md and prior rounds) shows:
- New `sco-tester` cases (“Reconnect During Disconnect”, “Reconnect After Disconnect”, “Connect Twice”) that fail on unpatched bluetooth-next and pass with the series (3/3 on UP, SMP, and KCSAN).
- Full `sco-tester`, `iso-tester`, `l2cap-tester`, and `mgmt-tester` results unchanged aside from the fixed cases.
- Explicit checks on stable heads (6.1, 6.6, 6.12, 6.18, 7.2) for which patches apply and which bugs exist; the hold fix alone is sufficient and works on 6.6/6.12; all three are needed and work on 6.18/7.2.
- Reproduction of the timeout race with a debug-only park of `hci_conn_timeout()`, then confirmation that patch 3 refuses the connect.
- Clean kernel-report-scan logs, checkpatch, and CI results.
- The BlueZ test is written to accept multiple valid outcomes (`ECONNABORTED`, `EBUSY`, or a new link) so it remains meaningful across kernel versions and does not false-pass or false-fail.

Emulator-based testing is the established practice for BlueZ/kernel Bluetooth logic; original hardware traces from the issue provide additional grounding. The contributor has done the investigation, the multi-version application checks, the regression testing, and the documentation of limits.

### Correctness considerations and residual risks
From the patches and messages:
- Refcounting follows the precedent of the accepted CIS fix (`e06d549fcd4a`): when reusing an existing link, drop the redundant ACL hold and take a caller hold on the SCO connection. Error paths drop appropriately.
- The abort_reason check and the later `cancel_delayed_work_sync` + recheck close the windows described. The message notes that for SCO the timeout worker does not take `hdev->lock` (it only queues the Disconnect) and that `hci_conn_del` already waits under the lock, so the sync cancel is expected to be safe.
- Paths for new, linked, and remote-initiated connections are considered; the test covers the practical cases.

Minor points a careful maintainer might still probe (but that the material already tries to answer):
- Exact locking context of `hci_connect_sco()` vs. the sync cancel (the tests and the SCO-specific explanation reduce the risk, but a one-line confirmation in the message or a comment is already present).
- Whether any other caller of `hci_connect_sco()` is affected (the series and cover focus on the SCO socket path).
- Preferred semantics: immediate `-ECONNABORTED` vs. deferral. The cover letter surfaces this cleanly and offers an RFC, so maintainers can decide without extra investigation.

These are normal review questions, not signs of incomplete homework.

### Comparison to recent Bluetooth practice and rejection patterns
Recent accepted patches in the area emphasize precise commit messages, correct `Fixes:` tags, testing notes (often with the BlueZ testers), and minimal changes. Common rejection or revision reasons include incomplete history, missing testing, style nits, incorrect stable applicability, or behavior changes that are not justified or documented. This series avoids the usual pitfalls: history is explicit, testing is extensive and multi-config, style is clean, stable applicability is pre-checked and explained, and the semantic change is documented with an alternative offered.

### Bottom line
- **Useful?** Yes. It fixes a real user-visible race and a related refcount bug that can tear down a working link, with clear benefit for Bluetooth audio reliability.
- **Follows written and unwritten rules/practices?** Yes, closely—form, style, tags, testing, honesty about limits, and recipient choices all align with kernel and linux-bluetooth expectations.
- **Creates extra work for maintainers?** Minimal. The prose is clear, the evidence is organized, the limits are stated, the stable matrix is pre-done, and the tests are provided. Maintainers still need to review the logic and locking (as always), but they should not need to rediscover the bug, the history, the stable applicability, or basic regression behavior.
- **Quality bar for something used by millions?** High, and this candidate meets it.

Before any send, the only practical remaining steps noted in the material itself are a final check of upstream heads and whether the BlueZ tester mainloop series has landed (in which case the test should be rebased). The series as packaged at d7b011d is in good shape for the mailing list.

---

## Reviewer 2

# Independent review — CO-02: Linux Bluetooth SCO connection reuse

Changes requested before submission. Candidate d7b011d · 22 October 2026

## 1. Executive verdict

This is a worthwhile Linux contribution addressing real, user-visible defects. The kernel patch series is technically promising, unusually well documented, and supported by meaningful regression evidence. However, I would not send the complete candidate unchanged.

I have independently inspected the four outgoing kernel emails, the BlueZ test patch, the review request, the evidence summary, and the mailing instructions. I also compared the affected functions against upstream Linux and BlueZ source and checked the current kernel contribution documentation.

My assessment is that the most substantial remaining risks concern test maintainability, the interpretation of the regression evidence, synchronization guarantees, and an important current submission-policy requirement.

Assessment by area (independent judgment): Value to Linux users: High. Problem diagnosis: Strong. Kernel patch design: Promising. Commit-message quality: Strong. Regression evidence: Strong, not exhaustive. Stable-backport preparation: Well prepared. BlueZ test maintainability: Needs attention. Overall submission readiness: Conditional.

These are qualitative review estimates, not measured quality scores or a prediction of maintainer acceptance.

### The actual problem is important

The existing behavior can produce two especially undesirable outcomes:

1. A second SCO connection attempt can interfere with an already established SCO connection because of incorrect hold accounting.
2. A new SCO socket can apparently connect successfully while actually being attached to a connection undergoing teardown, then fail when that teardown completes.

This is not merely a Bluetooth diagnostic oddity. It can disrupt headset audio, particularly around HFP codec renegotiation.

The proposed series tackles distinct parts of that problem rather than implementing a large speculative redesign. That is an appropriate direction for a kernel bug fix.

The review must distinguish three outcomes:

- The code fixes the reported failure: substantial evidence supports this.
- The code is safe in all relevant concurrency and ownership scenarios: not yet independently established.
- The code completely repairs the PipeWire codec-switch experience: the cover letter correctly says it does not.

That last distinction is especially valuable. The submission does not promise an end-user repair beyond what the code actually achieves.

## 2. Findings by severity

| Priority    | Finding                                                                        | Assessment                    |
| ----------- | ------------------------------------------------------------------------------ | ----------------------------- |
| High        | Current `Assisted-by:` attribution requirement needs resolving                 | Submission compliance         |
| Medium–high | BlueZ test adds 534 lines for three scenarios                                  | Maintenance burden            |
| Medium      | Patch 3 relies on synchronization and lock-order assumptions                   | Requires precise verification |
| Medium      | Test oracles do not prove every event and link invariant                       | Test strengthening            |
| Medium      | Stable backports are evidenced by the dossier, not independently executed here | Verification boundary         |
| Low–medium  | Cover letter is unusually detailed                                             | Editorial refinement          |
| Low         | No physical Bluetooth controller tested                                        | Acceptable if disclosed       |

The first issue is a definite current process concern. The other items range from specific weaknesses to outstanding validation requirements; they are not all established functional defects.

## 3. Detailed technical review

### Finding 1 — Patch 1: SCO connection reference ownership

Strong design, subject to lifetime verification

The first patch is:

`Bluetooth: hci_conn: hold a reused SCO connection for its caller`

This is probably the strongest of the three patches.

The fundamental distinction is between an existing link's reference and the reference owed to the current caller.

The patch changes the logic from always invoking `hci_conn_link()` to explicitly handling an already-linked SCO connection:

```
if (sco->link) {
    hci_conn_drop(acl);
    hci_conn_hold(sco);
} else {
    link = hci_conn_link(acl, sco);
    if (!link) {
        hci_conn_drop(acl);
        hci_conn_drop(sco);
        return ERR_PTR(-ENOLINK);
    }
}
```

Why this is a good approach: it repairs the apparent ownership mismatch at the function that returns the connection. It avoids asking each caller to compensate for inconsistent ownership semantics.

The analogy with the previous CIS ownership correction, `e06d549fcd4a`, strengthens the case because this is a comparable resource-lifetime problem in an adjacent part of the subsystem.

The evidence reports that the failing `Connect Twice` case is repaired on both 6.6.160 and 6.12.114, and that the relevant test also passes with patch 1 alone against the development kernel.

Those comparisons are particularly persuasive because the old kernels exercise a different SCO socket ownership model.

Outstanding verification: the code review still needs an explicit reference-accounting table for creation, existing-link reuse, link failure, socket attachment failure, and socket destruction. I did not independently prove every balancing operation against the exact development tree.

### Finding 2 — Patch 2: refusing an aborting connection

Well-motivated fix

The second patch rejects an SCO connection whose `abort_reason` is already set.

```
} else if (sco->abort_reason) {
    hci_conn_drop(acl);
    return ERR_PTR(-ECONNABORTED);
}
```

I like several things about this change.

First, it does not invent a new connection state. Second, it prevents an immediately misleading success rather than waiting for a later failure. Third, it handles the temporary ACL reference explicitly.

The commit message explains a subtle point effectively: a connection undergoing teardown may remain `BT_CONNECTED` until the Disconnection Complete event arrives.

That distinction matters because the HCI connection state alone does not tell the entire story.

The principal limitation is that this check by itself does not prevent a concurrent timeout worker from beginning an abort immediately after the check. Patch 3 addresses precisely that problem.

My assessment: patch 2 is justified and appropriately scoped. I would retain it as a separate commit.

### Finding 3 — Patch 3: synchronization with the disconnect worker

Needs a formal concurrency argument

This is the most concurrency-sensitive part of the series.

The patch adds:

```
cancel_delayed_work_sync(&sco->disc_work);

if (sco->abort_reason) {
    hci_conn_drop(sco);
    return ERR_PTR(-ECONNABORTED);
}
```

The underlying reasoning is sound: `cancel_delayed_work()` prevents pending work from running but does not necessarily wait for work already executing.

Waiting for an already-running worker before trusting `abort_reason` is an understandable solution.

However, `cancel_delayed_work_sync()` is a synchronization primitive with potentially important lock-order consequences.

The critical claim is that `hci_conn_timeout()` does not require `hdev->lock` on the relevant SCO execution paths, even though `hci_connect_sco()` is called while that lock is held.

I verified that the upstream timeout-worker structure is consistent with the argument: it reads the reference count and, when appropriate, invokes `hci_abort_conn()` through the disconnect-reason helper. I have not fully verified the complete transitive call graph of that helper and its queueing operations at the pinned base.

To eliminate doubt, I would require a compact review record covering:

| Question                                                            | Required evidence                        |
| ------------------------------------------------------------------- | ---------------------------------------- |
| Can the worker reacquire `hdev->lock`?                              | Complete relevant call-chain inspection  |
| Can work completion depend on an HCI callback blocked by that lock? | Queue and callback dependency analysis   |
| Can connection deletion race with the wait?                         | Lifetime and serialization proof         |
| Can the worker reschedule itself?                                   | Inspect work scheduling and cancellation |
| Is the SCO reference held until the synchronous wait completes?     | Explicit ownership trace                 |

The reported parked-worker test is strong evidence that the intended race exists and that the fix handles it in the tested configuration.

It is not a substitute for the lock-order proof.

Classification: an unresolved verification requirement, not a demonstrated deadlock.

## 4. The BlueZ regression test

This is the portion I would improve most before submission.

The test patch introduces three meaningful scenarios:

- `Reconnect After Disconnect`
- `Reconnect During Disconnect`
- `Connect Twice`

Together, they cover useful distinctions between normal reconnection, overlapping teardown, and contention with an existing live socket.

The important strength is that the tests inspect controller activity rather than relying exclusively on the result of `connect()`.

In particular, they distinguish a new connection from accidental reuse by tracking Setup Synchronous Connection commands and Synchronous Connection Complete events.

That is the correct general approach.

### The maintenance concern

The proposed implementation changes 535 lines in `tools/sco-tester.c`, including additional test state, hooks, timers, socket monitoring and custom event manipulation.

That is a lot of additional infrastructure for three scenarios.

A maintainer could reasonably ask whether this functionality can reuse existing helpers, be made smaller, or be divided into preparatory infrastructure and actual regression cases.

I would not demand an arbitrary reduction to 100 or 200 lines. A rigorous emulator test sometimes needs substantial machinery.

But the submission should make the size defensible.

### Specific test issues

1\. Event status validation. The `hook_reconnect_sync()` implementation increments the Synchronous Connection Complete count without rejecting a nonzero status. Other conditions and socket-state checks provide some protection, but an explicit successful-completion invariant would make the oracle stronger.

2\. Event ordering. The test stores a first connection handle and counts subsequent events. It should explicitly establish which connection each event represents, particularly where the emulator reuses a handle.

3\. State cleanup. The new test has a second socket, multiple GLib event sources, and timers. The post-teardown cleanup is reasonable, but cancellation and callbacks should be audited against every early-failure branch.

4\. A passing refusal is not necessarily the complete product behavior. `Reconnect During Disconnect` intentionally accepts either a meaningful refusal or a genuinely new link. This is a reasonable regression contract for the kernel behavior under test. It should not be presented as proof that codec switching succeeds.

5\. Mutation testing would be valuable. Make controlled, test-only changes that violate individual invariants and verify that the tests fail. Examples include suppressing the second setup command, disconnecting the first socket unexpectedly, or reporting success without a valid second link.

The evidence already includes strong negative controls: unpatched kernels fail the targeted cases and patched kernels pass. Mutation tests would increase confidence that the tests are not accidentally permissive.

My preference is to keep the three scenarios, but reconsider how much new shared infrastructure they require.

## 5. Testing and stable kernels

The supplied results are substantially better than a typical assertion that a patch was compiled and tested.

Results reported by the submitted evidence, not independently re-executed in this review

| Kernel         | Unpatched result              | Patched result                        |
| -------------- | ----------------------------- | ------------------------------------- |
| 6.1.190        | Reuse path absent             | No backport proposed                  |
| 6.6.160        | Connect Twice fails 3/3       | Passes 3/3 with patch 1               |
| 6.12.114       | Connect Twice fails 3/3       | Passes 3/3 with patch 1               |
| 6.18.58        | Both target cases fail 3/3    | Both pass with series                 |
| 7.2.12         | Both target cases fail 3/3    | Both pass with series                 |
| bluetooth-next | Target regressions reproduced | Reported passing on UP, SMP and KCSAN |

The reported full-suite results and unchanged unrelated tester results provide additional reassurance.

I also appreciate that the evidence explicitly invalidates the initial `git apply` experiment because Git silently skipped paths. Reporting a failed verification method and replacing it with a proper one is good engineering practice.

The stable strategy appears coherent with the documented differences between kernel lines. Current stable rules support version-qualified stable trailers and dependency information. They also require changes to land upstream before stable inclusion and to be sufficiently small, justified and tested. (The Linux Kernel documentation)

One small improvement: use the stable cover-letter explanation for why each line needs a different subset, rather than reproducing the entire verification matrix. The existing paragraph is close to the right level.

The main remaining gaps are independent reproduction of the recorded commands and logs, physical-controller validation, and deeper memory-safety and concurrency coverage. The fact that no physical hardware was used is clearly disclosed and is not, by itself, grounds to reject a well-designed emulator regression fix.

## 6. Compliance issue: AI-assisted development attribution

This is an important finding that does not arise from the Bluetooth code itself.

The current Linux kernel submission documentation contains specific guidance for advanced coding tools and AI assistance.

It says that qualifying assistance should be acknowledged using an `Assisted-by:` trailer, with the documented format beginning:

```
Assisted-by: LLM
```

The separate AI Coding Assistants document also distinguishes the human contributor's `Signed-off-by:` certification from automated assistance. (The Linux Kernel documentation)

I cannot determine the correct trailer solely from the supplied patch history: that depends on what tools actually contributed to developing the patches, rather than merely reviewing them afterward.

If qualifying tools contributed, the current candidate appears to lack an acknowledgement expected by the documented process. This needs to be resolved before submission.

This is not a suggestion to attribute the authorship of your engineering work to an AI system. Human responsibility, the DCO and authorship remain separate matters. Nor does it require listing every model or conversational exchange.

It is a matter of complying with the upstream project's current disclosure conventions.

## 7. Prose and maintainer experience

The kernel patch descriptions are generally strong.

In particular, they explain not only what changes but why the old behavior is incorrect, when the defect became observable, and how the proposed fix addresses it.

The `Fixes:` trailers appear logically matched to the two distinct regressions, although I have not completed a full historical ancestry audit for each affected stable branch.

The cover letter has a particularly good feature: it explicitly acknowledges that the series does not fully solve the PipeWire retry problem.

I would preserve that paragraph.

I would make only limited editorial changes:

- Put the user-visible symptom and the main cause at the beginning.
- Keep each patch description focused on the bug fixed by that patch.
- Avoid repeating the full experimental story in the cover letter.
- Prefer a few well-selected test results to a catalogue of every run.
- Keep the optional deferred-connect RFC clearly separated from the present fix.

The important principle is that a maintainer should understand the failure and the correction without opening the evidence repository. Your current kernel emails largely meet that standard.

The Linux submission guide explicitly encourages self-contained explanations of the problem, user impact, implementation and testing. The current organization is broadly consistent with that guidance. (The Linux Kernel documentation)

## 8. Upstream precedent and rejection analysis

I located a relevant set of 25 upstream commits through GitHub commit search, including:

- [SCO socket ownership/lifetime precedent](https://github.com/torvalds/linux/commit/816fb1590a4c8cf8d05cd076057616be02e276f0)
- [Earlier SCO race correction](https://github.com/torvalds/linux/commit/8a5b0135d4a5d9683203a3d9a12a711ccec5936b)
- [Additional upstream Bluetooth change](https://github.com/torvalds/linux/commit/c5c4e1701059324914873f9e8e65c57ebd96ac96)

The search establishes useful candidates for comparison but is not equivalent to inspecting several dozen mailing-list discussions.

In particular, I did not complete the requested systematic sample of accepted and rejected submissions with individual maintainer explanations. Git commit history shows what was merged, but it cannot by itself explain which proposed alternatives were rejected or why.

I therefore cannot claim that this review has exhaustively established the current unwritten culture or catalogued several dozen actual rejection reasons.

The closest documented risks visible in this candidate are excessive regression-test complexity, incomplete proof of synchronization safety, and compliance with submission metadata requirements.

## 9. Recommended disposition

Kernel patch 1: Retain. A focused ownership correction with good regression evidence.

Kernel patch 2: Retain. An appropriately narrow rejection of a connection already being aborted.

Kernel patch 3: Verify further. A plausible race fix that warrants explicit lock and worker-dependency verification.

BlueZ test: Refine. Valuable regression coverage whose size and event oracles deserve further attention.

Submission emails: Minor revisions. Good overall structure; resolve attribution requirements and keep the cover concise.

### Final judgment

I would continue with this contribution, preserve the three-patch decomposition, and hold submission pending the remaining verification and compliance work.

Nothing I inspected demonstrates that this patch series is intrinsically harmful, badly conceived, or contrary to the interests of Linux users. Its purpose is sound, the changes are relatively small, and its negative-control testing is especially useful.

It also demonstrates a welcome concern for downstream kernels rather than assuming that behavior on the newest development tree is sufficient.

But the level of assurance you asked for is higher than simply finding no obvious defect. This review did not execute the patches, reproduce their results, formally establish every lifetime and locking invariant, or complete the requested large comparative study of mailing-list acceptances and rejections.

Consequently, I cannot give the candidate an unconditional technical sign-off.

My overall verdict is:

Useful contribution, credible implementation, strong preparation, with specific unfinished review obligations.

The work should not be thrown away or substantially redesigned on the evidence available. It should be finished with particular attention to patch 3's synchronization argument, the BlueZ test's maintainability and oracle strength, and the current upstream submission rules.

No repository files were changed, no review was committed, and nothing was sent.

---

## Reviewer 3

# Independent review — CO-02, Linux Bluetooth SCO connection reuse

Review target: `d7b011d76ba65f7a119521cc5d5eebb28f13a29e` · 22 October 2026

## 1. Preliminary engineering verdict

The contribution addresses real defects and has a credible technical justification. It is not merely a cosmetic cleanup or a speculative improvement. The proposed changes concern SCO connection lifetime, reference ownership, and a race between reconnection and disconnection.

Three aspects make this work particularly relevant to Linux users:

- A second SCO connection attempt must not accidentally disconnect another socket's working audio connection.
- A successful `connect()` must not falsely represent an already-dying SCO connection as a usable connection.
- Reconnection must not resurrect a connection whose asynchronous disconnect worker has already committed to aborting it.

The first two problems have straightforward user-visible consequences. The third is a legitimate concurrency problem, although its correctness argument deserves especially careful scrutiny.

Importantly, the series does not solve the complete PipeWire codec-switch problem. It corrects kernel behavior but can still leave an immediate PipeWire retry unsuccessful. The cover letter acknowledges this explicitly. That is good engineering discipline: the submission does not promise a complete end-to-end repair that it cannot demonstrate.

I would nevertheless distinguish a demonstrated improvement from a fully established absence of regressions. The evidence supports the former. The latter requires additional scrutiny, especially around concurrent teardown and the regression-test implementation.

## 2. Kernel code review: the three patches

I inspected the exact outgoing diffs against the referenced `bluetooth-next` base, including the relevant surrounding implementation in `hci_conn.c`, `sco.c`, `hci_sync.c` and `hci_core.h`.

| Patch                                      | Technical assessment                                                                                                                                               | Remaining concern                                                                  |
| ------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------ | ---------------------------------------------------------------------------------- |
| 1/3 — Hold a reused SCO connection         | Correct ownership model. The extra caller receives an operational hold without taking ownership of the pre-existing parent link.                                   | No definite correctness defect found.                                              |
| 2/3 — Reject an aborting SCO connection    | Correctly distinguishes an HCI connection still present in the hash from one that is usable for a new socket.                                                      | The selected `ECONNABORTED` behavior should remain explicitly documented.          |
| 3/3 — Wait for a running disconnect worker | Necessary to close the race that remains after simply checking `abort_reason`. The synchronization approach is supported by the source and debug-park experiments. | One error-path lifecycle detail deserves stronger justification before submission. |

### Patch 1: reference ownership

This patch solves a particularly important problem: `hci_conn_link()` does not acquire an additional operational hold when it returns an existing link.

The caller of `hci_connect_sco()` nevertheless proceeds as though it has obtained a connection reference that it can later release.

That mismatch can allow a failed second socket connection to release a hold still needed by the first socket, initiating an unwanted disconnection.

The new code is consistent with the surrounding ownership model:

```
if (sco->link) {
    hci_conn_drop(acl);
    hci_conn_hold(sco);
} else {
    link = hci_conn_link(acl, sco);
    ...
}
```

I found particularly good precedent in the accepted Bluetooth change [Bluetooth: ISO: balance the parent hold in hci_bind_bis()](https://github.com/bluez/bluetooth-next/commit/4c94557dd02569efa6c1072a0439addaef9a5224). That commit deals with the same distinction between an object-lifetime reference and an operational connection hold, and explains how existing holds are transferred through `hci_conn_link()`.

This is exactly the kind of neighboring accepted change that supports the reasoning behind patch 1.

Verdict: technically sound, appropriate for upstream, and demonstrably useful.

### Patch 2: rejecting a dying connection

A connection object can remain in the hash while its disconnection is already committed. Its `state` may still be `BT_CONNECTED`, but its `abort_reason` is nonzero.

The patch prevents a second socket from attaching to that already-aborting connection.

That is a sensible rule. The distinction between object exists and connection can still be used is essential here.

Returning `-ECONNABORTED` also has a defensible meaning: the connection selected for reuse has already entered abort processing.

One detail worth acknowledging in the commit message is that this is an immediate failure rather than transparent reconnection. Applications that want a fresh connection must retry after the old link has been removed.

That distinction is important for PipeWire developers reading the patch.

Verdict: sound, with no concrete regression identified.

### Patch 3: synchronous cancellation

This is the most delicate change.

The race is real because `hci_conn_timeout()` can observe a zero reference count and start executing before another thread takes a fresh hold.

A simple `hci_conn_hold()` cannot reverse work that has already passed that decision.

The new synchronization:

```
cancel_delayed_work_sync(&sco->disc_work);

if (sco->abort_reason) {
    hci_conn_drop(sco);
    return ERR_PTR(-ECONNABORTED);
}
```

is designed to wait until the old worker has either completed or been canceled, then determine whether the connection remains reusable.

I traced the timeout worker into `hci_abort_conn()`, then through the command synchronization path. The immediate worker path does not require `hdev->lock`. The existing `hci_conn_del()` code also performs synchronous delayed-work cancellation, providing useful local precedent.

The debug-only parked-worker reproducer is especially persuasive. On the older candidate, a new socket could connect successfully and subsequently be aborted by the worker. With the current synchronization, the second connection waits for the worker and returns an error instead.

Both incoming and outgoing connection cases were included.

I did not establish a lock inversion or deadlock in the proposed implementation. That is a meaningful positive result, but not a formal proof covering every possible kernel callback or teardown context.

## 3. Specific findings requiring attention

These are the findings I would return to the project maintainer. I separate verified issues from potential concerns.

Finding 1 — BlueZ regression test can leave its first socket open on failure

Severity: moderate · Confirmed from the proposed test source

The new teardown logic closes `data->sk2`, but it does not close `data->sk`.

On successful execution, the relevant test paths explicitly close the first socket. On early failure, however, `reconnect_end(data, false)` may run while `data->sk` remains valid.

For example, `CONNECT_TWICE` can fail while the first socket is still active. The test then enters teardown without closing that socket.

That risks a file-descriptor leak and unwanted effects on subsequent tests within the same process.

Recommendation: Add failure-safe cleanup of the first socket for the new reconnect cases, taking care not to alter the existing tests' ownership assumptions. Then deliberately force an early failure and confirm that both sockets and all GLib sources are released.

Finding 2 — Patch 3's abort-after-link path needs an explicit ownership explanation

Severity: moderate · Potential lifecycle concern, not a proven leak

For an incoming, previously unlinked SCO connection, `hci_conn_link()` can create a parent-child link before `cancel_delayed_work_sync()` completes.

If the worker sets `abort_reason`, the caller drops its SCO hold and returns `-ECONNABORTED`, but the newly created link remains attached.

The ordinary disconnection cleanup should eventually release that link and its parent references. However, this creates an error path in which connection-link state is established even though the connection attempt ultimately fails.

Recommendation: Trace and document exactly who releases that link, including controller disconnect failure, device power-off and controller unregister cases. If existing teardown guarantees cleanup, a concise justification is sufficient. Otherwise, consider whether the check-and-link ordering or explicit unwind should change.

I would not change this code merely on suspicion; the ownership chain needs to be proven first.

Finding 3 — The BlueZ attribution rule must be checked before posting

Severity: process compliance · Conditional on how the contribution was developed

BlueZ's actual [AI Coding Assistants guidance](https://github.com/bluez/bluez/blob/7bc9684dc9e4/doc/coding-assistants.rst) says contributions developed with AI assistance should carry an `Assisted-by:` trailer and explicitly requires it in its AI-assisted bug-fixing procedure.

The proposed BlueZ patch has no such trailer.

Whether this applies depends on the tools' actual role in discovering, writing or fixing the contributed code. Merely conducting this external review is not, by itself, proof of how the patch was authored.

Recommendation: Check the project's development history against that written requirement. If it applies, follow BlueZ's documented attribution convention before sending. This is distinct from the kernel's `Signed-off-by` rules.

Finding 4 — Strengthen the test's success assertions

Severity: low to moderate · Test robustness

The new HCI callback increments `sync_complete` for every structurally valid Synchronous Connection Complete event, including events whose HCI status reports failure.

I recommend asserting successful status when counting events that establish the expected connection, and checking the expected handle where applicable.

The 500 ms stability window is reasonable for a focused regression test but does not demonstrate long-term connection stability. It should not be described as such.

There is also an adjacent pre-existing behavior worth recognizing: `hci_connect_sco()` updates `sco->setting` and `sco->codec` before the higher-level `sco_chan_add()` may reject a second socket with `EBUSY`.

That was already possible in the base code. The current series does not introduce it. I would not expand this submission to solve it without a separate reproducer and justification, but I would avoid saying that a rejected second connect cannot modify any state of the existing connection.

## 4. Testing assessment

The evidence package is significantly more rigorous than a simple compile-and-smoke-test submission.

Results below are reported by the project's evidence files. I inspected the implementation and evidence but did not personally execute these kernel builds or QEMU runs.

| Kernel           | Unpatched result            | Patched result                                       | Assessment               |
| ---------------- | --------------------------- | ---------------------------------------------------- | ------------------------ |
| 6.1.190          | Reuse defect not applicable | No patch required                                    | Correctly excluded       |
| 6.6.160          | Connect Twice fails 3/3     | Passes 3/3 with patch 1                              | Strong backport evidence |
| 6.12.114         | Connect Twice fails 3/3     | Passes 3/3 with patch 1                              | Strong backport evidence |
| 6.18.58          | During and Twice fail       | All three targeted cases pass                        | Strong evidence          |
| 7.2.12           | During and Twice fail       | All three targeted cases pass                        | Strong evidence          |
| `bluetooth-next` | Targeted defects reproduced | 27/27 focused runs pass across UP, SMP and KCSAN SMP | Strong evidence          |

The cited stable versions are genuine releases published on or before 22 October 2026. (kernel.org)

A notable strength is that the testing does not simply declare an entire suite green. On 6.6 and 6.12, the full SCO suite improves from 28/33 to 29/33, with the remaining failures present in both the unpatched and patched runs. The evidence says this explicitly instead of presenting them as successes.

Similarly, the earlier SMP management-suite flakiness was compared against the unpatched kernel; it was not silently excluded.

The test methodology contains three useful layers:

1. Behavioral regression tests: real socket operations driven against an emulated Bluetooth controller.
2. Differential tests: the same scenarios fail on the relevant base kernel and pass after the fix.
3. Deterministic race amplification: a debug-only kernel modification forces the timeout-worker interleaving and verifies patch 3.

This third layer is valuable because ordinary timing-sensitive tests frequently miss precisely the races they are intended to prevent.

The evidence also reports successful kernel patch checks, BlueZ patch checks and compilation, plus KASAN, lockdep and KCSAN-oriented configurations. I did not independently verify the raw logs, since those are retained on the development machine rather than exposed with the GitHub review package.

### Remaining testing gaps

A physical-controller test would improve confidence, particularly for real HFP/HSP operation and controller-dependent disconnect behavior. However, it should not be treated as a mandatory requirement for a kernel-core concurrency fix that can be reproduced deterministically with an emulator.

A more useful immediate improvement would be a reproducible public test recipe and representative sanitized logs for the parked-worker race. This allows future contributors to validate or extend the test without needing private development artifacts.

I would also run one intentional failure-path test of the BlueZ tester itself to validate Finding 1, and one controller-shutdown experiment targeting Finding 2.

## 5. Comparison with established upstream practice

I examined the recent Bluetooth commit history, including approximately two dozen selected commit records and particularly relevant accepted fixes from the current development line.

The most useful comparisons are these:

| Upstream precedent                                                                                                                                                         | What it demonstrates                                                                     |
| -------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------- |
| [ISO: balance the parent hold](https://github.com/bluez/bluetooth-next/commit/4c94557dd02569efa6c1072a0439addaef9a5224)                             | Explain precisely which reference is owned and transferred.                              |
| [hci_conn: Lock parent access during enhanced SCO setup](https://github.com/bluez/bluetooth-next/commit/024e05f73a4c1263d031614bc36700ec135eecb4)   | Describe the competing workers and the dangerous interleaving explicitly.                |
| [SCO: serialise sco_conn lifetime against receive](https://github.com/bluez/bluetooth-next/commit/816fb1590a4c8cf8d05cd076057616be02e276f0)         | Distinguish strong references, weak back-pointers and serialization.                     |
| [SCO: Fix a race condition in sco_sock_timeout()](https://github.com/bluez/bluetooth-next/commit/0f8a5dcc66648b6e1458a9f3ba4c5a0463a228fc)          | Treat synchronous work cancellation and lock ordering as first-class correctness issues. |
| [hci_core: Serialize SCO and ISO scheduling with teardown](https://github.com/bluez/bluetooth-next/commit/848a7a91c7f03675d3bd8db6f7721cbf9cb50e21) | Give the use-after-free mechanism and relevant concurrency evidence.                     |
| [SCO: Fix data-race on sco_pi fields in sco_connect](https://github.com/bluez/bluetooth-next/commit/4847c5bca22227100ae69e96af86618b6fd2671f)       | Use concrete KCSAN observations and avoid solving unrelated problems in the same patch.  |

The proposed CO-02 series is consistent with these examples in its scope, ownership reasoning and approach to concurrency.

I also checked several real maintainer discussions in which patches were challenged or revised. These are not all formally rejected submissions, and I would not misclassify them as such.

For example, reviewers challenged a proposed Bluetooth quirk because it applied to too many devices without adequate testing or a reproducible justification. (Linux Kernel) Another review questioned silently hiding invalid controller packets rather than preserving useful diagnostics. (Linux Bluetooth) A separate L2CAP contributor split two issues after review instead of combining them into a single defensive change. (Linux Kernel)

These examples reinforce three norms that CO-02 mostly follows: limit the scope, show the actual defect, and do not conceal observable failure.

I did not complete a verified survey of several dozen formally rejected Bluetooth patches. That would require tracking the final disposition of individual mailing-list threads and distinguishing rejection from revision, deferral or supersession. The comparison above supports a cultural assessment, not an exhaustive rejection-rate analysis.

## 6. Written submission rules

The kernel documents place particular importance on a self-contained explanation of the user-visible problem, its cause, the remedy and how the proposed change can be evaluated. They also favor small logical changes, relevant recipients and independently understandable commit descriptions. (The Linux Kernel documentation)

The series generally follows these requirements.

Kernel patch structure and trailers: The three kernel patches contain appropriate `Fixes:` and `Signed-off-by:` trailers. The use of `Cc: stable@vger.kernel.org # 6.6.x` on patch 1 is appropriate because the documented stable convention means consideration starting from that version, rather than on older trees where the relevant reuse path is absent. (The Linux Kernel documentation)

BlueZ submission: I verified that BlueZ's own [maintainer guidelines](https://github.com/bluez/bluez/blob/7bc9684dc9e4/doc/maintainer-guidelines.rst) explicitly prohibit `Signed-off-by` trailers in userspace BlueZ commits while requiring them for kernel commits. The BlueZ mail is correct on that point.

Recipients: The reported `get_maintainer.pl` selection and copied Bluetooth maintainers are reasonable. The separate kernel series and BlueZ userspace test email are consistent with the practice of keeping patches for different repositories separately reviewable.

Commit prose: The three kernel descriptions are relatively concise and communicate the key mechanisms clearly. They are substantially better than dumping raw forensic observations into the commit logs.

One improvement I recommend is that each individual kernel commit should state its relevant validation, not rely exclusively on the cover letter. Commit messages survive after the original email thread becomes difficult to locate. In particular, patch 3 should say plainly that the race was reproduced using an instrumented timeout worker, that this instrumentation is not part of the submission, and what the resulting behavior was. That is relevant information for future stable-tree maintainers.

The current netdev guidance also stresses explaining discovery, verification and user-visible behavior in bug-fix commit messages, rather than expecting reviewers to infer those details from external logs. (The Linux Kernel documentation)

## 7. Maintainer effort and presentation

This is an unusually small kernel diff for the amount of investigation behind it. That is a favorable trade-off: maintainers would receive three short logical code changes, rather than a large restructuring of SCO ownership.

The test patch, however, is much larger: approximately 535 changed lines.

That size is not automatically inappropriate. An asynchronous socket test using an HCI emulator needs state transitions, timers, hooks and cleanup. Still, it increases the amount of code BlueZ maintainers must review.

The test would become easier to accept if its resource ownership were completely explicit, and if the three cases shared common lifecycle helpers without introducing unnecessary complexity.

For the kernel cover letter, I would retain the current organization. The prose makes a clear distinction between what the series repairs and the PipeWire behavior it does not yet solve.

I would not paste large test transcripts into the patch emails. A short reproducer/result statement and a link to the detailed evidence are better for a busy maintainer.

## 8. Recommended disposition

Review verdict: revise the package before sending. Kernel implementation: favorable technical assessment. Complete kernel + BlueZ submission: minor revisions recommended.

My remaining conditions are:

- Fix the BlueZ regression tester's first-socket cleanup on early failure and test that cleanup deliberately.
- Prove or document the parent-link ownership path when patch 3 refuses a connection after creating a link.
- Strengthen the HCI completion assertions in the BlueZ test.
- Add concise per-patch validation details, particularly the non-submitted debug instrumentation used to verify patch 3.
- Resolve BlueZ's documented `Assisted-by` requirement according to the actual development provenance, if applicable.

I do not recommend redesigning the entire kernel solution based on what I found. In particular, I found no established reason to remove the synchronous work cancellation or combine all three kernel changes into a single patch.

I also would not require yet another broad stable build matrix before addressing the identified issues. The current matrix already provides good evidence. The remaining work is more targeted.

The two upstream bases were confirmed at the exact revisions used by the package when checked: `bluetooth-next` at `27731ba09195` and BlueZ at `7bc9684dc9e4`.

## 9. Final judgment

The contribution has legitimate user value. Its author has taken the important step of turning an observed malfunction into separate, explainable defects and then supplying regression tests that distinguish broken and corrected behavior.

Its overall design is consistent with established Linux Bluetooth development practice. Its testing is stronger than what is typically possible for an ordinary one-off bug report.

At the same time, the new BlueZ failure-path cleanup issue is a concrete defect in the proposed test code, and the kernel link-ownership concern deserves to be resolved rather than dismissed by a reassuring review.

My recommendation is to retain the kernel design, make the targeted corrections, and then submit the revised package. That would better satisfy the objective you established: not merely produce a patch that appears to work, but give maintainers an understandable, independently verifiable contribution without avoidable extra work.

No files were modified, no review was committed, and no email or patch was sent as part of this review.

---

## Reviewer 4

# Comprehensive pre-submission review of the SCO reconnect Linux and BlueZ patch series

## Executive verdict

I reviewed the submission candidate pinned to `d7b011d76ba65f7a119521cc5d5eebb28f13a29e`, including the kernel cover letter and three kernel patches, the BlueZ `sco-tester` patch, the recorded test evidence, the sending instructions, the relevant current Bluetooth kernel code, current BlueZ test infrastructure, the real-device evidence in the repository, the immediately analogous accepted CIS fix, current subsystem history, and the kernel's written submission/stable rules.

**My overall judgment is favorable, but I would not send exactly the `d7b011d` version yet.** The contribution is solving a real and worthwhile kernel correctness problem; its basic design is conservative; patch 1 has an unusually strong accepted precedent; patches 2 and 3 address a genuine teardown/reuse race rather than papering over a userspace symptom; the BlueZ tests are substantial and adversarial rather than merely happy-path tests; and the evidence package is far stronger than what many small kernel fixes arrive with.

There is, however, **one concurrency question I consider important enough to close before submission**: patch 2 adds a pre-synchronization read of `sco->abort_reason`, while the delayed disconnect worker can enter `hci_abort_conn()` outside `hdev->lock` and set that field. Patch 3 fixes the *functional timing race* by synchronizing with `disc_work` and checking again afterward, but the earlier plain read deserves an explicit Linux-memory-model/KCSAN audit rather than an assumption that “it is only a byte, therefore it is fine.” The present KCSAN runs are good evidence but are not themselves a proof that every lockless access pairing is sanctioned.

My send-readiness assessment is therefore:

| Component | Assessment | Send now? |
|---|---|---|
| Kernel patch 1, SCO hold ownership | **Technically very strong**; exact CIS precedent exists | After minor terminology cleanup |
| Kernel patch 2, reject aborting SCO | **Right behavior and right scope**, but participates in the unresolved `abort_reason` synchronization question | **Not yet** |
| Kernel patch 3, synchronize with disconnect work | **Conceptually strong and appears to close the actual race**; subject/message can be made more exact | After concurrency audit |
| Kernel cover letter | **Good, unusually honest and useful**; can be made shorter and more neutral in two places | Minor revision |
| BlueZ reconnect tests | **Useful and well designed**; they test properties rather than one implementation | Essentially ready, subject to final current-tree rebase |
| Evidence/testing package | **Strong**; branch coverage is particularly good | Improve reproducibility and, ideally, one hardware validation |

So the important distinction is: **I am not recommending a redesign of the fix. I am recommending one final concurrency audit plus editorial tightening before mail is sent.**

The series is also useful even though it deliberately does **not** make the complete PipeWire HFP codec-switch scenario succeed. Returning a truthful failure rather than allowing a new socket to inherit a connection already committed to teardown is a kernel correctness improvement in its own right. The cover letter is commendably explicit about that limitation instead of claiming end-to-end success it does not provide.

## Technical correctness and kernel semantics

### The ownership bug in patch 1 is convincing

This is the strongest part of the series.

At the candidate base, `hci_connect_sco()` obtains an ACL connection with a connection hold and then either finds an existing SCO connection or allocates one. `hci_conn_link()` takes the SCO connection hold when it creates a new parent-child link, but an already-linked connection is a different path: the existing link is returned rather than creating another ownership unit for the new caller.

That distinction matters because the Bluetooth connection API deliberately separates two concepts. `hci_conn_get()`/`put()` protect the lifetime of the `struct hci_conn` object, while `hci_conn_hold()`/`drop()` are connection holds that keep the underlying connection alive. `hci_conn_hold()` increments that hold count and performs a non-synchronous cancellation of `disc_work`; `hci_conn_drop()` can schedule disconnect work when the last hold disappears.

The SCO socket code assumes that `hci_connect_sco()` has returned a caller-owned hold. `sco_connect()` calls `sco_chan_add()`, and if that fails—for example because another socket already occupies the SCO connection—the error path drops the hold returned by `hci_connect_sco()`. A successfully attached socket separately owns a connection hold of its own.

That makes the candidate diagnosis coherent: when the reused path failed to acquire a fresh caller hold, the second caller's cleanup could drop a hold that actually belonged to the existing relationship. Patch 1's treatment—

> drop the redundant ACL hold and explicitly take a hold on the reused SCO connection

—is the right shape for restoring the function's caller-ownership contract.

More importantly, this is not merely an interpretation invented for this submission. An almost structurally identical bug was already fixed and accepted for CIS connections in commit `e06d549fcd4a`, where reuse of an existing CIS similarly had to preserve the caller's connection-hold ownership rather than behave as though a newly created link had supplied it. That accepted analogue is exceptionally persuasive evidence that patch 1 follows the Bluetooth maintainers' own model rather than introducing a novel ownership convention.

I would therefore rate patch 1 **very high confidence**.

The one editorial change I strongly recommend is terminology. The commit message currently sometimes calls this a “reference.” Because this code has both object-lifetime references and connection holds, “reference” forces a tired reviewer to stop and ask which reference class is meant. The kernel API itself distinguishes them. Use **“connection hold”** consistently throughout patch 1.

For example, instead of wording equivalent to:

> the existing link does not give the caller a fresh reference

prefer:

> the existing-link path does not give the caller its own connection hold.

And instead of:

> drop the returned reference

say:

> drop the caller-owned connection hold returned by `hci_connect_sco()`.

That is a small edit with a disproportionate reduction in reviewer cognitive load.

### Patch 2 uses the right semantic boundary

Patch 2 rejects an SCO connection whose `abort_reason` is already set rather than handing that connection to another socket.

The important thing is what the patch **doesn't** do. It does not reject every SCO connection whose state merely looks unusual, does not add a sleep/retry policy, does not manufacture a second connection, and does not modify HCI command sequencing globally. It keys the decision to the stack's own marker that teardown has already been initiated. That is a much more precise predicate than something broad such as “state is not exactly `BT_CONNECTED`.”

This precision matters because the problematic interval is real. The old SCO `hci_conn` can remain present while controller-side disconnection is outstanding. Real-device traces in the repository show HFP codec changes where the headset's codec reply arrives only 16–30 ms after the Disconnect command while Disconnection Complete does not arrive until roughly 177–205 ms after the command. On another headset, Disconnection Complete arrives first and the subsequent setup proceeds normally. In other words, there is an actual device-dependent timing window in which userspace can ask for the next SCO connection while the previous controller link is still being torn down.

Current PipeWire code also shows why this is not a contrived API sequence: when replacing an HFP transport, `rfcomm_new_transport()` frees an existing transport before constructing the replacement transport.

Returning `-ECONNABORTED` for “you have reached a connection whose teardown is already committed” is consequently defensible. It tells the caller that the connection it found is not a usable live resource. Importantly, the candidate does not turn that error into a kernel retry policy; it leaves that larger behavioral decision outside this narrow lifetime fix.

I would keep that narrow scope.

### Patch 3 closes a real race that patch 2 alone cannot close

The key underlying primitive is significant: `hci_conn_hold()` uses `cancel_delayed_work()`, not `cancel_delayed_work_sync()`. Therefore it prevents pending disconnect work from starting, but it cannot rewind work that is already executing.

`hci_conn_timeout()` can already have observed a zero hold count and moved forward into aborting the connection before a new connect takes its hold.

This gives exactly the race described in patch 3:

1. disconnect work starts;
2. it observes no remaining holders;
3. a new connect arrives and `hci_conn_hold()` cannot cancel the already-running callback;
4. the new path can initially observe an apparently reusable connection;
5. the old worker commits the abort;
6. the newly attached caller has inherited a connection that is going away.

Patch 2's first `abort_reason` check cannot by itself close that interval because at the instant of that first check the worker may not have written the abort reason yet. Patch 3's synchronous rendezvous with `disc_work`, followed by another `abort_reason` check, is therefore doing necessary work rather than merely duplicating patch 2.

There is also useful precedent inside the same lifecycle: `hci_conn_del()` already synchronizes with the connection's delayed disconnect work before destroying the connection.

The deadlock question deserves special attention because the candidate calls `cancel_delayed_work_sync()` while the SCO socket connect path holds `hdev->lock`. In the SCO/ESCO case, however, `hci_proto_disconn_ind()` does not invoke the ACL/LE protocol-specific disconnect callback; for those non-ACL/non-LE link types it produces the disconnect indication directly. The abort path then schedules the connection-abort operation rather than requiring the timeout callback itself to complete controller disconnection under the same lock.

That makes the proposed synchronization much less suspicious than a generic “sync-cancel arbitrary Bluetooth work while holding `hdev->lock`” would be. I do **not** see evidence here of a lock-cycle that makes patch 3 fundamentally wrong.

I would nevertheless change its subject. The current:

> `Bluetooth: hci_conn: wait for a running SCO disconnect before reuse`

can be read as “wait until the HCI disconnection completes and then reuse,” which is not what the patch does. It synchronizes with the **disconnect work callback**, discovers that an abort was committed, and returns an error.

A more exact subject is:

> `Bluetooth: hci_conn: synchronize with SCO disconnect work before reuse`

or:

> `Bluetooth: hci_conn: avoid racing SCO disconnect work on reuse`

That removes an entire possible misreading before the reviewer even opens the diff.

### The unresolved `abort_reason` access is the pre-send technical gate

This is the one point where I would pause the send.

The existing timeout worker can call `hci_abort_conn()` after observing the hold count reach zero. `hci_abort_conn()` uses `abort_reason` as the marker that the abort has already been initiated. Patch 2 adds a plain `sco->abort_reason` read on the reuse path before patch 3 performs its synchronous rendezvous with `disc_work`.

Functionally, patch 3's post-synchronization test is excellent: it catches the worker that won the race. But from a kernel concurrency-review standpoint, I would explicitly answer a second question before sending:

**What serialization makes every new plain read of `abort_reason` race-free against every writer?**

If the answer is “all relevant writers except this delayed-work case are serialized by `hdev->lock`, and `cancel_delayed_work_sync()` establishes the necessary ordering before the final read,” then the code should preferably be arranged so that the relevant decision is made after that synchronization point.

If there really is an intended lockless read/write pair, then the correct treatment should be decided deliberately—potentially `READ_ONCE()`/`WRITE_ONCE()`, potentially a different ordering, potentially combining patches 2 and 3—not by adding one `READ_ONCE()` mechanically to silence a concern. The correct solution depends on auditing all `abort_reason` writers and readers.

This is why I would not call the current version “absolutely ready.” It may turn out that no code change is needed after the complete audit, but this is exactly the class of question a Bluetooth maintainer should **not** have to discover and investigate for the contributor.

One attractive simplification worth considering during that audit is whether patches 2 and 3 can be expressed as one robust “reuse gate”:

> obtain the required caller hold → synchronize with teardown work → decide from the now-stable abort state whether reuse is legal.

I would not make that structural change blindly, because an already-set `abort_reason` can have origins other than this particular delayed worker. But it is worth checking whether that formulation eliminates both the functional race and the questionable pre-sync access without introducing another path.

## Testing, evidence, and regression risk

The test work is a major strength of this submission.

The candidate evidence says the series was exercised on the current Bluetooth-next base `27731ba09195`, including UP, SMP and KCSAN configurations; all three new SCO reconnect tests pass with the complete series; the full `sco-tester` run passes on the complete current series; and the unpatched tree demonstrates the intended failures rather than merely showing that the patched tree happens to pass.

That last point is particularly important. A regression test is much more persuasive when it has demonstrated all four relevant states:

| State | Expected evidentiary value |
|---|---|
| Old kernel, regression test | Fails for the intended reason |
| Partial fix | Exposes which defect remains |
| Full fix | Passes |
| Broader existing suite | Does not reveal collateral regression |

The evidence records exactly that sort of discrimination: patch 1 alone fixes the “connect twice/live link ownership” case while the teardown-race case remains, whereas the full series fixes both. This makes it harder for a reviewer to suspect that one broad behavioral change merely happened to make three tests green.

The stable-line work is also unusually useful. The evidence records investigation/testing against 6.1.190, 6.6.160, 6.12.114, 6.18.58 and 7.2.12, with patch 1 relevant back to 6.6 while the later teardown-reuse pieces become relevant on newer lines. It also records actual before/after test behavior on multiple stable kernels rather than deciding stable eligibility solely from `git describe --contains`.

That supports the candidate's stable trailers and its choice not to pretend that every patch belongs on every supported stable branch. Linux's stable documentation explicitly expects a stable candidate to fix a real correctness problem, be appropriately constrained in risk, and be tested; `Cc: stable@vger.kernel.org` with version guidance is a standard submission mechanism.

The BlueZ patch is also better than a simple “connect, disconnect, connect, expect success” test. Its three cases distinguish:

- reconnect after teardown has completed;
- reconnect while teardown is still incomplete;
- a second connection attempt while the existing SCO link remains genuinely live.

The “during disconnect” case deliberately allows the kernel either to reject the immediate second operation or to form a genuinely new connection only after the old one is completed; what it refuses to accept is a false immediate “connected” result without a corresponding new setup. That is the right kind of test because it specifies an **invariant** rather than permanently encoding one particular implementation strategy.

The test patch does add substantial state-machine code—about five hundred lines—but those lines service three closely related scenarios and shared emulator machinery. I would **not split it merely to make individual diffs smaller**. Splitting shared helpers from each test could make the reviewer reconstruct the intended invariant across more messages and patches. Here, cohesion is more valuable than an artificially low line count.

The candidate also records final `checkpatch` success, BlueZ CI success, patch application checks, subject/gitlint checks, `get_maintainer.pl`, and `git send-email --dry-run` recipient/threading validation. This aligns well with the kernel submission guidance to test the changes, use the subsystem's recipient information, check patch formatting, make each patch understandable in its own right, and keep a series logically structured.

There are nevertheless three ways I would strengthen the evidence before pressing Send.

First, the v3 evidence explicitly says its raw execution logs/scripts are not all committed. That does **not** make the kernel patch unacceptable—the mailing list should not receive a warehouse of test artifacts—but it prevents another engineer from fully auditing every summarized result from the public repository alone. Since this project already maintains an evidence tree, preserving the exact small scripts and raw test summaries that produced the v3 table would make the work substantially more reproducible without burdening the actual patch email.

Second, the real-device evidence proves that the timing window occurs on real Bluetooth hardware, but the v3 kernel validation itself is principally emulator-based. Given the candidate's own statement that this series alone does not make the PipeWire codec-switch workflow succeed, the correct hardware acceptance criterion is **not** “microphone switching now works.” A useful patched-hardware check would instead verify:

- the second socket is not falsely reported connected to the dying SCO link;
- the established link is not accidentally destroyed by another caller's hold cleanup;
- the immediate overlapping request receives the expected failure;
- once Disconnection Complete has arrived, a subsequent ordinary connection can create a new SCO/eSCO link.

That would directly test what these patches promise and nothing they do not promise.

Third, for the extremely high confidence bar you requested, I would add one targeted static/build pass around the touched kernel code—particularly sparse or the subsystem's equivalent `C=1` build—and more than a token number of KCSAN repetitions around the deliberately widened race window. The kernel's own submission checklist recommends relevant configuration/build/static-analysis coverage in addition to runtime testing. This is not because the diff is architecture-sensitive; it is because patch 3 is explicitly about synchronization, so concurrency tooling has unusually high marginal value here.

## Submission rules, stable tags, recipients, and subsystem culture

### Written Linux rules

The series is fundamentally following the written kernel submission model.

The kernel documentation asks commit messages to explain what is wrong and why the change is needed rather than merely restating the diff; bug fixes should identify the introducing change where possible; patches in a series should remain logically coherent; patches should be tested; formatting should be checked; and recipient selection should follow the subsystem's maintainership information.

All three kernel commits have independent technical explanations and `Fixes:` trailers rather than relying on the cover letter to preserve essential history. That is important because the cover letter is review context, not the permanent commit message that future `git log` readers will necessarily see. The candidate gets this right.

The stable mapping is also thoughtful rather than indiscriminate. Patch 1 names a minimum stable line, while patches 2 and 3 use their later `Fixes:` ancestry and general stable Cc. The evidence then checks actual branch applicability.

I would retain those stable trailers unless the final concurrency restructuring changes commit boundaries.

### Recipients and sending form

The proposed kernel recipients include the Linux Bluetooth list, the principal Bluetooth maintainers, authors/participants connected with the introducing or analogous changes, and stable through trailers. The BlueZ patch is separately addressed to the Linux Bluetooth list and BlueZ maintainer. The package records that `get_maintainer.pl` and a `git send-email --dry-run` were used.

Current BlueZ repository configuration itself specifies `Linux Bluetooth <linux-bluetooth@vger.kernel.org>` as the series destination and uses the `bluez` send prefix, so the userspace test patch's destination and `[PATCH BlueZ]` form fit the project's current tooling.

The BlueZ tree also configures a 72-character title limit through gitlint, and the candidate records its local BlueZ CI/gitlint checks as passing.

I would follow the candidate's plan to send the kernel series first and the BlueZ test patch separately rather than trying to construct a cross-project pseudo-series. They are reviewed and merged through different trees even though the mailing-list audience overlaps.

### The unwritten Bluetooth style is a good match

The strongest cultural evidence is the accepted CIS analogue mentioned above. It shows that maintainers have very recently accepted essentially the same ownership reasoning for another Bluetooth connection type.

I also examined the current recent `net/bluetooth` history. Representative Bluetooth fixes merged on October 20, 2026 use exactly the style you are aiming for: detailed causal explanation, concrete controller behavior, before/after evidence, explicit discussion of what the patch intentionally does not solve, interactions with neighboring state, `Fixes:` tags, stable Cc, and substantial hardware/runtime evidence.

That is useful because it answers an important style question: **your candidate is not “too serious” or “too evidence-heavy” for this subsystem.** Current accepted Bluetooth fixes can be quite detailed when the state machine requires that detail.

The discipline is not “make the message short at any cost.” It is closer to:

> make every sentence earn the reviewer's attention.

The candidate is already mostly there.

I cannot honestly claim that I completed the other half of your requested empirical exercise—**a defensible sample of a few dozen formally rejected recent SCO/HCI-connection submissions from primary mailing-list records**. The accepted-history sample was straightforward to inspect through the current tree; “rejected” kernel patches are much less cleanly classified because many mailing-list submissions become v2/v3, are superseded, receive change requests, or simply do not get applied rather than receiving a formal rejection marker. I therefore will not invent a “30 rejected patches” dataset and pretend it was reviewed.

That is a limitation of this research result, and it means I cannot certify your requested “few dozen rejected patches” criterion as completed. What I **can** certify is that the candidate satisfies the principal failure modes that the official process documentation is designed to prevent—unclear motivation, unexplained behavior change, missing regression ancestry, untested code, poor series structure, missing recipients, and patches whose permanent commit messages depend on cover-letter context.

## Prose and maintainer cognitive load

The prose is already much better than the “bag of forensics” failure mode you described. The causal chain is visible, the individual patches have distinct responsibilities, and the cover says what remains unfixed.

I would still make it even easier on the proverbial hung-over maintainer.

### Put the invariant before the history

The single sentence a reviewer should understand first is roughly:

> `hci_connect_sco()` must never return a caller-owned usable connection hold for an SCO connection whose teardown has already been committed.

Then the three patches become obvious:

> Patch 1 repairs caller hold ownership on the reused-live-link path.
> Patch 2 rejects a connection already marked for abort.
> Patch 3 closes the race with disconnect work that has started but has not marked the abort yet.

That mental model is simpler than forcing the reader to derive the invariant by following commits and socket behavior in chronological order. The current cover contains all of this information, but the invariant could be made more prominent.

### Avoid assigning policy ownership that the patch does not need to settle

The cover's limitation discussion is excellent in substance, but language equivalent to:

> retry/defer policy belongs above this socket-side lifetime fix

is stronger than necessary. It invites a reviewer to debate layer ownership even though the proposed patches do not need that debate resolved.

I would instead say:

> This series intentionally does not add retry or deferred-connect semantics. In the observed PipeWire codec-switch sequence, the immediate second connect therefore fails while the old SCO link is still being torn down.

That states exactly what this series does and does not do without asking the maintainer to endorse a broader architecture statement.

Likewise, instead of:

> This is exactly what PipeWire does...

I prefer:

> This sequence is exercised by PipeWire during an HFP codec change...

The latter is just as informative while avoiding an unnecessarily universal claim. The repository's PipeWire and hardware evidence is sufficient to support the narrower formulation.

### Make patch 1's vocabulary mechanically precise

As noted earlier, replace every ambiguous “reference” with either:

- **object lifetime reference** for `hci_conn_get()`/`put()`, or
- **connection hold** for `hci_conn_hold()`/`drop()`.

The kernel header makes that distinction explicit.

This is exactly the sort of edit that helps a tired reviewer: there is then no need to maintain a private translation table while reading the explanation.

### Make patch 3's synchronization target explicit

I recommend this subject:

> **Bluetooth: hci_conn: synchronize with SCO disconnect work before reuse**

And a core explanation shaped roughly like:

> `hci_conn_hold()` cancels pending `disc_work`, but the cancellation is not synchronous. The work may therefore already have observed a zero hold count and be running `hci_abort_conn()` when a new SCO connect reuses the connection.
>
> After acquiring the caller's hold, synchronize with `disc_work` and check `abort_reason` again. If the worker committed the abort, reject the reuse with `-ECONNABORTED`.

That is nearly impossible to misread. It says what runs, what the race is, what provides synchronization, and what happens when the other side wins.

### Keep the limitation section

Do **not** remove the statement that the series alone does not make the PipeWire codec-switch scenario succeed. That honesty is a feature, not a weakness.

A maintainer can then approve a small kernel invariant fix without having to wonder whether the submitter is quietly depending on an unreviewed deferred-connect semantics change. The current cover even records that a deferred prototype was explored rather than smuggling that behavior into the proposed fix.

I would only compress the prototype detail. One or two sentences are enough.

### A tighter cover-letter shape

I would structure the cover approximately this way:

> Closing an SCO socket can leave its `hci_conn` present until Disconnection Complete. If another connect to the same peer arrives in that interval, `hci_connect_sco()` can find and reuse the closing connection.
>
> Two problems follow. First, the reused-link path does not currently acquire the caller-owned connection hold expected by `sco_connect()`, so cleanup of a second failed socket can consume another holder's hold. Second, a connection whose disconnect has already been committed can be returned to the new socket as though it were usable.
>
> Patch 1 restores the caller-owned hold when a live SCO connection is reused. Patches 2 and 3 reject reuse once teardown is committed and synchronize with already-running disconnect work so that the decision cannot race that work.
>
> The latter case occurs during HFP codec switching when the replacement SCO connect is issued before the previous link's Disconnection Complete event.
>
> This series intentionally does not add retry/deferred-connect semantics. The overlapping connect therefore receives `ECONNABORTED`; a later connect after teardown can establish a new link.
>
> The series was tested on bluetooth-next with the BlueZ reconnect tests under UP, SMP and KCSAN configurations, and its stable applicability was checked against the listed supported branches. [Then give the compact results.]

That version makes the first screen of the email answer, in order:

**what invariant is broken → why → what each patch does → real trigger → what is intentionally not fixed → evidence.**

That is exactly the order a busy maintainer wants.

## Community value and scope

This contribution is useful to Linux, but it should be described in proportionate terms.

It is not a sweeping Bluetooth redesign. It corrects ownership and teardown semantics in a narrow SCO connection path and adds tests that preserve those semantics. Patch 1 modifies an ownership inconsistency with a direct accepted CIS analogue; patches 2 and 3 prevent callers from receiving a connection already committed to teardown; the userspace tests encode behavior at the socket/HCI boundary rather than a particular vendor workaround.

That is precisely the kind of kernel contribution that can have value beyond the original QCA9377 investigation. The real trigger depends on timing between host teardown, controller Disconnection Complete, and the next SCO connect, and the repository's hardware evidence demonstrates different timing behavior across headsets. The kernel code being fixed is generic Bluetooth core code rather than a QCA9377-specific driver workaround.

At the same time, the submission correctly avoids claiming that it solves every HFP/SCO problem. There are adjacent lifecycle failures in the ecosystem—for example, an open BlueZ issue describes a different duplicate Enhanced Setup Synchronous Connection failure in which a rejected new setup can affect an already established eSCO connection—but that is a distinct bug chain and should not be recruited as proof that this series fixes it.

I would keep that separation very strict. Do not inflate the cover with “also possibly fixes issue X/Y/Z” unless a test actually demonstrates it. A small patch whose exact guarantee is known is more valuable to maintainers than a patch advertised as curing an entire Bluetooth symptom family.

Likewise, I would make no security claim, no “all Bluetooth users” claim, and no assertion that the contribution itself restores PipeWire codec switching. The strongest honest statement is simpler:

> **It repairs generic SCO lifetime semantics that can be exercised by real userspace and real controller timing, and it supplies regression tests for those semantics.**

That is enough.

## Pre-send gate and final recommendation

I would use the following gate before allowing this series onto `linux-bluetooth`.

**Must resolve before sending:** audit every relevant `abort_reason` access and establish why patch 2's pre-sync read is correctly serialized, or restructure the patch so that the reuse decision is made after an appropriate synchronization point. Do not leave this discovery to Luiz, Marcel, or another reviewer. The candidate's entire purpose is to repair a race, so its own data-access synchronization must be beyond doubt.

**Strongly recommended before sending:** change patch 1's “reference” terminology to “connection hold”; rename patch 3 so that it says it synchronizes with disconnect *work*, not that it waits for controller disconnection; soften the two unnecessary architectural claims in the cover; preserve the v3 raw/reproducibility artifacts; and run one final targeted sparse/static build plus a stronger KCSAN repetition around the parked-race test. The kernel submission checklist explicitly favors doing relevant testing and static checking on the contributor side.

**Very valuable if the hardware is still available:** boot the final patched candidate on the affected QCA9377 machine and validate the narrow contract the kernel patches actually promise. Do not require the entire PipeWire codec-switch workflow to magically succeed; verify absence of false connection reuse, correct overlapping-connect failure, preservation of a genuinely live connection in the “connect twice” case, and successful fresh setup after teardown completes. The existing traces already establish that the real-hardware timing window exists.

**No change needed:** keep the three logical concerns separated unless the `abort_reason` audit shows that patches 2 and 3 are cleaner as one synchronization fix; keep the BlueZ three-case test together; keep the stable applicability information; keep the explicit limitation that retry/defer semantics are outside the submitted series; and keep kernel and BlueZ submissions as separate mail series.

The final assessment is therefore:

**The contribution is worth making. The underlying bug analysis is credible. Patch 1 is exceptionally well supported. The design direction of patches 2 and 3 is conservative and appropriate. The tests are meaningfully better than a superficial reproducer, the stable investigation is strong, and the prose is already substantially above ordinary patch-submission quality. This is not a bad or gratuitous submission that would merely transfer investigative labor to the maintainers.**

**But the exact `d7b011d` candidate is not the version I would send.** I would first close the `abort_reason` concurrency question and make the small prose corrections above. After that, assuming the audit does not reveal another synchronization requirement, I would regard the kernel series as a strong and useful Linux Bluetooth submission rather than an experiment that maintainers are being asked to finish for you.
