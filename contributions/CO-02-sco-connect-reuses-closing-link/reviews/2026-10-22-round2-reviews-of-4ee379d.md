# CO-02 — outside reviews 1 to 6 of the package at `4ee379d` (round 2)

*Received 2026-10-22, after round 1 (`2026-10-22-reviews-of-4c82e91.md`,
`2026-10-22-reviews-5-6-of-4c82e91.md`). Kept as received, except for the reviewers' tooling
marks, which `scripts/review-text-clean.py` removes. What each point led to: `../log.md`.*

---

---

## Reviewer 1

**The updated 3-patch series is ready for the second review round and remains high-quality work.** Round-1 feedback has been addressed correctly: a real residual race is closed by a small third patch, the `Fixes:` tags are now backed by a bisect, the BlueZ test is stricter and covers all three patches, and the evidence has been re-checked. The series continues to help rather than burden maintainers.

### What changed and why it improves the contribution
The package is now a three-patch series (`patch/v1/`, base `27731ba09195`):

1. **Patch 1** (refuse aborting SCO): unchanged in code, but the `Fixes:` tag is corrected to `e6720779ae61` (v6.13). A bisect established that the “false success at once” behaviour starts at that commit; before it the second connect simply received `EBUSY`.
2. **Patch 2** (hold on reuse): message rewritten around the ownership contract and the accepted CIS precedent `e06d549fcd4a`. `Fixes:` remains `8a5b0135d4a5`.
3. **Patch 3** (new, 11 lines): after taking the hold on a reused link, `cancel_delayed_work_sync(&sco->disc_work)` and re-check `abort_reason`. This closes the window in which `hci_conn_timeout()` has already observed `refcnt == 0` (and will call `hci_abort_conn()`) but `abort_reason` is not yet set. The race was reproduced by parking the timeout work after it saw zero holders; with only patches 1+2 the new connect still reported success and was later killed. With patch 3 it waits and then refuses cleanly with `-ECONNABORTED`.

The deadlock argument is sound and matches existing mainline practice: for SCO, `hci_conn_timeout()` does not take `hdev->lock`, and `hci_conn_del()` already waits for `disc_work` under that lock. The check is not widened to `refcnt == 0`, correctly avoiding the case of an incoming SCO that sits at zero in `BT_CONNECT`.

The BlueZ test was reworked with a stricter oracle, normal emulator teardown, a new “Connect Twice” case for patch 2, and BlueZ comment style. The kernel dependency is stated under `---`.

### Evidence (re-checked)
- Focused cases (After / During / Connect Twice): 27/27 pass across 1-CPU, 4-CPU and KCSAN kernels.
- Unpatched base fails both bug cases, as expected.
- Full suites (sco, iso, l2cap, mgmt) give identical results with and without the series; the nine mgmt failures on 4-CPU are the same as the unpatched SMP baseline.
- All 26 guest logs are clean and booted the intended kernel.
- `checkpatch --strict` is clean (0/0/0) on all three patches.
- The residual race and the bisect results are documented in the results file.

### Recheck against the criteria
1. **Correctness:** Patch 3 is the right place and the right minimal fix for the observed race. The wait cannot deadlock for the reasons stated. Patches 1 and 2 remain correct. The updated `Fixes:` tags are now evidence-backed.
2. **Testing:** Sufficient and improved. The stricter oracle, the Connect Twice case, the parked-worker reproduction of the residual race, and the full-suite comparison close the holes identified in round 1.
3. **Form and consumability:** Cover letter is clear, states the three fixes, the test results, and the open deferral question. Subjects and tags are clean. The review request asks the right questions for round 2.
4. **Help vs. noise:** Still pure help. The third patch is small and well-justified; the cover letter does not force maintainers to evaluate a large semantic alternative. Offering the deferral only as a possible RFC remains appropriate.
5. **Open decisions:** The recommendations (Cc Hitalo Souza, Aldo Ariel Panzardo and Pauli Virtanen; `Cc: stable` at least on patch 2; send the BlueZ test the same day after the kernel series) are reasonable and low-cost. The ELL and permission items remain internal.

**Recommendation:** Proceed with review round 2. The series is correct, well-tested, honestly scoped, and helpful. Nothing in the update reduces its quality; the addition of patch 3 and the corrected `Fixes:` tags make it stronger. Once the remaining send decisions are made, it can go out.

---

## Reviewer 2

I rechecked the **actual round-2 package at `4ee379d1...`**, including all three kernel mails, the complete 485-line BlueZ test patch, the cover letter, the new results document, and the current `bluetooth-next` source around the lifetime/workqueue paths. I also rechecked the upstream precedents and current submission rules.

## Updated verdict

**The two technical blockers from round 1 are fixed. I do not find a remaining kernel-code correctness blocker in this v1 series.**

This is now materially stronger than the previous package. Patch 3 is not merely defensive: you deterministically proved the race, proved patches 1+2 leave it open, and proved patch 3 closes precisely that interleaving. The BlueZ test is also now a real regression suite rather than a permissive reproducer.

My status would be:

| Area | Round 1 | Round 2 |
|---|---|---|
| Patch 1 | strong, race incomplete | **ready** |
| Patch 2 | very strong | **ready** |
| timeout/hold race | blocker | **reproduced and fixed by patch 3** |
| Patch 3 locking | unresolved | **looks correct** |
| BlueZ oracle | definite false-pass | **fixed** |
| BlueZ emulator fidelity | questionable | **fixed** |
| Patch 2 regression test | missing | **added** |
| `Fixes:` history | partly inferred | **empirically established** |
| Regression evidence | excellent | **excellent+** |
| Maintainer consumability | good | **very good** |
| Overall | do not send unchanged | **technically send-ready** |

I have **three small pre-send changes/rechecks**, one of which may be process-required depending on how the patches were created. None requires changing the kernel code.

### Patch 3 now convinces me

The critical sequence from round 1 really exists:

```text
hci_conn_timeout()             new connect()

reads refcnt == 0

                               finds existing SCO
                               abort_reason == 0
                               takes new hold

continues despite new hold
sets abort_reason
queues abort
```

Your parked-worker experiment is exactly the right way to prove this. It is much stronger than hoping KCSAN happens to hit a tiny timing window.

More importantly, the proposed synchronization is in the right order:

```text
drop redundant ACL hold
take SCO hold
cancel_delayed_work_sync(disc_work)
recheck abort_reason
```

Taking the hold **before** waiting is important: it prevents an ordinary not-yet-running timeout from becoming valid again while you synchronize with one that was already running.

I traced the callback further this time. For SCO/eSCO, `hci_conn_timeout()` calls `hci_proto_disconn_ind()`, which simply supplies the constant remote-user-termination reason; it does not enter L2CAP or take `hdev->lock`. `hci_abort_conn()` publishes `abort_reason` and goes into command-sync plumbing, but that plumbing does not hold `hdev->lock` while the delayed-work callback needs it. The command-sync worker also releases `cmd_sync_work_lock` before executing its queued callback. So I do **not** see a lock cycle with the `hdev->lock` held by `hci_connect_sco()`.

The existing `hci_conn_del()` doing a synchronous wait for `disc_work` while connection teardown is serialized under the same device locking is useful corroboration. Your commit-message statement is therefore supportable, rather than merely “lockdep didn't complain.”

I also investigated a subtler question: **why synchronize only inside `if (sco->link)`?** At first that looked potentially incomplete, because `hci_conn_link()` itself still takes a hold using only the nonsynchronous `cancel_delayed_work()`.

For the affected outgoing SCO lifetime, however, the restriction is justified. A newly created SCO enters the hash at refcount 0 with no disconnect work queued. Its first operational hold is taken by `hci_conn_link()`, which simultaneously installs the link. A zero-delay `disc_work` arising from later dropping that ownership therefore implies that this connection has had a link. Unlink/delete removes that link while synchronously disabling the work and deleting the hash entry under the serialized teardown path. I don't see a normal reachable “existing unlinked SCO + previously scheduled disconnect worker” state that escapes patch 3.

**I would add one sentence about that invariant to patch 3's changelog**, because otherwise a maintainer can reasonably ask the same question:

> The reused connection can only have pending disconnect work after its link has acquired and later dropped a hold, so the synchronization is limited to the existing-link path.

That's reviewer-time reduction, not a code correction.

### The BlueZ test is now good

The false-positive problem I found last time is gone.

`Reconnect After Disconnect` can no longer pass from an arbitrary refusal. It requires `EINPROGRESS` followed by the second Setup Synchronous Connection and second completion.

`Reconnect During Disconnect` accepts exactly the two semantics that are sensible for a long-lived regression test:

- `ECONNABORTED`, with no phantom second link; or
- deferred/in-progress connection followed by an actual independent link.

An immediate successful `connect()` with no independent link is explicitly rejected.

`Connect Twice` is also a good test of patch 2 rather than merely another symptom test: it requires **exactly EBUSY**, verifies that no Disconnect occurs while the first socket remains open, verifies that the first socket is still connected after a quiet interval, and then checks teardown after closing the sockets.

Changing the event interception to `POST_EVT` was also the right repair. You are now withholding delivery to the host **after the emulator has performed its normal controller-side teardown**, instead of accidentally changing the controller's internal semantics to create the desired scenario.

This is a much more maintainable upstream test.

The 485-line size initially looks large for three tests, but after reading it I don't see gratuitous machinery that makes it obviously unsuitable. Most of the size is the stateful controller/socket orchestration required to assert what actually happened, rather than sleeps followed by “did it crash?” checks.

### The `Fixes:` work is now unusually solid

The move from `a13f316e90fd` to **`e6720779ae61` for patches 1 and 3 is justified**. You did what I would want before putting a historical claim permanently into the kernel log: you ran the current reproducer against the history and bisected the behavioral transition.

That is stronger than source archaeology alone. And looking at `e6720779ae61` itself makes the result plausible: that commit substantially changed SCO connection/socket lifetime and removed the older close path in which a connected socket explicitly dropped the HCI connection and moved through the disconnect state.

Patch 2's `Fixes: 8a5b0135d4a5` also remains the correct choice for the **collateral disconnect** being fixed. You correctly stopped claiming that the preceding state was perfect: before `8a5...`, your test finds a different ownership/leak behavior, while `8a5...` is where the new error-path `hci_conn_drop()` turns the missing caller hold into destruction of the first socket's live link.

That is disciplined `Fixes:` reasoning: the changelog describes the bug *this patch actually fixes*, rather than pretending all prior ownership history was clean.

And the analogy to Aldo Panzardo's accepted CIS repair is exceptionally strong. That upstream fix explicitly addresses the same `hci_conn_link()` property—an existing link is returned without acquiring another child hold—and preserves caller ownership while dropping the redundant parent hold. It also went to stable and has already been backported to several stable lines. [Openwall](https://lists.openwall.net/linux-kernel/2026/09/15/2710)

### The testing is enough

I would not ask you for another hundred normal repetitions.

The important evidence is qualitative rather than merely numerical:

**unpatched** gives `After=pass`, `During=fail`, `Connect Twice=fail`; **patch 1 alone** gives `After=pass`, `During=pass`, `Connect Twice=fail`; and **the complete series** gives all three passing. That is an excellent patch-to-test mapping.

Then you have 27/27 focused runs over UP, SMP4 and KCSAN SMP4; identical full-suite verdict sets between patched and baseline; the exact same nine SMP mgmt failures; all 26 final guest logs scanned clean; intended-kernel provenance; and the deterministic artificial race test for the path that ordinary repetition would be particularly bad at exercising.

That is the kind of evidence that **saves maintainer time**. It answers “does it really fix the claimed thing?”, “does each patch matter?”, “did the new synchronization introduce obvious locking damage?”, and “are unrelated tester failures yours?” before the reviewer has to ask.

The testing level is comparable in spirit to Hitalo Souza's nearby v3 series, which also combines targeted emulation, debug kernels, broad tester coverage, static analysis and explicit unchanged failures. [Openwall](https://lists.openwall.net/linux-kernel/2026/10/08/2216)

Hardware testing would still be nice, but I would no longer call it even mildly necessary before submission. The actual original hardware observations established the user-visible scenario, while the kernel mechanism now has deterministic emulator tests. Also, the refusal policy deliberately does **not** make PipeWire 1.0.5's immediate retries succeed end-to-end, so a real-headset test could misleadingly look “still broken” despite the kernel correctness bug being fixed.

### The cover letter is now very good

The previous problem—making the maintainers choose between your submitted fix and an alternative architecture—is gone.

The current structure is appropriate: “these three patches fix incorrect behavior; separately, a deferral policy could improve PipeWire's behavior, and I can post that as an RFC if wanted.”

That is much easier to consume than “would you prefer something fundamentally different?”

The Hitalo paragraph is also now correct. His v3 is genuinely adjacent but tackles a different abandoned-setup mechanism; his series is still an active relevant discussion, and Luiz has engaged with it. [Openwall](https://lists.openwall.net/linux-kernel/2026/10/08/2216) Saying yours is independent and applies with or without it conveys exactly what the maintainer needs to know.

I would **not add the dossier links, raw logs, run counts beyond what is already there, reviewer history, or experimental branches to the mail**. The dossier is excellent precisely because the maintainer doesn't have to consume it.

One tiny language polish: I would change

> `a hci_conn_timeout() that already saw no holder`

to

> `an hci_conn_timeout() worker that already saw no holder`

but that's editorial only.

## I found one BlueZ process nit that I would fix

The new BlueZ subject is:

`tools/sco-tester: Add reconnect and connect twice tests`

That is **55 characters**.

BlueZ's current `HACKING` still explicitly documents the 50/72 convention and says the header should be limited to 50 characters. Their current `.gitlint` configuration is looser at 72, which explains why your GitLint check passes, but for the “follow both the bot and the written house rules” standard you asked me to apply, I would use the stricter documented form.

For example:

`tools/sco-tester: Add SCO reconnect tests`

is concise, accurate enough for all three cases, and under 50.

This is a **small message-only fix**, not a reason for another test campaign.

## `Cc: stable`: I would now choose yes

Patch 2 is the clearest case. It is a small correctness repair, its triggering commit is in released kernels, the bug can tear down a working connection, and its exact CIS ownership analogue carried `Cc: stable`. [Openwall](https://lists.openwall.net/linux-kernel/2026/09/15/2710)

After the race work, I would also classify **patches 1 and 3 together as stable candidates**. They fix a user-visible regression empirically bisected to `e6720779ae61`; they are small; the failure is deterministic; and patch 3 is necessary to make patch 1 race-complete.

So my preference is actually:

**`Cc: stable@vger.kernel.org` on all three kernel patches.**

The `Fixes:` tags tell the stable machinery which versions are potentially affected, but current kernel submission documentation explicitly says `Fixes:` does not replace the stable Cc for a stable candidate. The stable line belongs in the trailer/sign-off area, not in the email recipient list. [Linux Kernel Documentation](https://docs.kernel.org/process/submitting-patches.html)

That does **not** mean you need to prepare manual stable backports now. Stable maintainers decide which supported trees can take the upstream changes; the stable documentation also provides mechanisms for dependencies or version-specific adjustments when needed. [Linux Kernel Archives](https://cdn.kernel.org/doc/html/latest/process/stable-kernel-rules.html)

### Recipients

I agree with **all three** proposed extra Ccs.

Hitalo Souza is directly appropriate because he has a pending series in the same SCO-abort state machine and you explicitly tested compatibility with it.

Aldo Ariel Panzardo is particularly valuable for **patch 2**, because he authored the accepted CIS counterpart and recent SCO lifetime work. He can very quickly tell whether your ownership interpretation matches the intended model.

Pauli Virtanen is also useful rather than decorative: this crosses the kernel/PipeWire Bluetooth boundary and your cover explicitly discusses PipeWire behavior.

I would let the **final `scripts/get_maintainer.pl` run on the actual three formatted patches** determine the basic To/Cc set, then retain those three additional domain-relevant people if they are not already returned. Current kernel guidance explicitly recommends using both MAINTAINERS/history and `get_maintainer.pl`; it also warns against unrelated Cc noise. [Linux Kernel Documentation](https://docs.kernel.org/process/submitting-patches.html)

I would not keep expanding the Cc list merely because somebody touched one of the historical commits.

### BlueZ timing

I still prefer your current plan: **send the kernel `[PATCH 0/3]` first, then the separate `[PATCH BlueZ]` mail the same day.**

The BlueZ message now clearly states below `---` that two tests intentionally fail on current `bluetooth-next` and identifies the dependent kernel series. That makes the failure understandable rather than mysterious CI breakage.

There is also useful precedent in Hitalo's current work for delivering kernel changes together with tests that specifically exercise behavior unavailable on the old kernel. [Openwall](https://lists.openwall.net/linux-kernel/2026/10/08/2216)

Sending the kernel mail first gives the BlueZ mail something that already exists in the archive for reviewers to find.

## One current process requirement needs your attention

The formatted patches I inspected have your `Signed-off-by`, but no `Assisted-by` trailers.

Current Linux submission documentation now says that **if an advanced coding tool was used in the creation of the patch**, its use needs to be acknowledged with `Assisted-by:` and says omission may impede acceptance. [Linux Kernel Documentation](https://docs.kernel.org/process/submitting-patches.html)

BlueZ's current `doc/coding-assistants.rst`, which I re-read, likewise asks for an `Assisted-by: AGENT_NAME:MODEL_VERSION ...` trailer when such assistance contributed to development. BlueZ still correctly does **not** want `Signed-off-by`, so your BlueZ mail is right on that part.

This is conditional on the actual provenance of these patches. If the tools involved only reviewed code you independently wrote, don't invent an attribution. **If an advanced coding assistant materially created or modified the code/test/commit text, then I would treat the appropriate `Assisted-by` trailers as a pre-send compliance requirement, not an optional social choice.**

Hitalo's current series is a directly relevant contemporary example: his cover explicitly says an AI assistant helped prepare the patches and tests and points to his `Assisted-by` tags. [Openwall](https://lists.openwall.net/linux-kernel/2026/10/08/2216)

### ELL and permission cleanups

I would **remove the accidentally installed ELL files from `/usr`**. They are not package-owned, BlueZ does not require installing ELL system-wide for this development setup, and retaining them merely makes future experimental provenance less clean. Fix `ci-local` to use its private prefix so it cannot happen again.

After removal, I would run one lightweight BlueZ build/check sufficient to demonstrate that nothing secretly depended on `/usr/lib/libell*`; there is no reason to rerun the kernel matrix because of it.

The permission cleanups A and B are **not CO-02 blockers**. Keep them separate from this upstream series. Fix them as project hygiene, but don't let unrelated local tooling changes cause one more cycle of touching an already validated kernel series.

## Final recommendation

At `4ee379d`, **I would no longer request another technical review round as a prerequisite to sending**. The prior reviewers found real weaknesses; you tested them rather than arguing them away, discovered that the race was genuinely reproducible, added the missing patch, corrected the regression suite, bisected the historical cause, and revalidated the resulting series.

Before the actual `git send-email`, I would do only this one final checklist:

1. Add the one-sentence explanation of why patch 3 synchronizes only the existing-link path; shorten the BlueZ subject to ≤50; add accurate `Assisted-by` trailers if the current kernel/BlueZ rules apply; decide and add `Cc: stable`—my recommendation is all three kernel patches.
2. Remove accidental ELL installation and do a lightweight BlueZ sanity build.
3. Re-run `get_maintainer.pl`, `checkpatch`, BlueZ GitLint/checkpatch, and `git am` on the **actual final mails** after those message/trailer edits.
4. Fetch immediately before sending and verify that `bluetooth-next/master` has not moved or acquired conflicting SCO work. At my check, the official `bluetooth-next` `master` is still your base `27731ba09195`, so **there is no rebase needed right now**.
5. Send kernel series first; send the BlueZ test immediately afterward as its separate `[PATCH BlueZ]` message.

With those final process details handled, I would grade CO-02 as **top-quality upstream work**. More importantly, I think it now satisfies the practical test behind that phrase: a busy Bluetooth maintainer can understand the bugs from the mails, inspect only **32 added kernel lines**, see exact regression tests for each behavior, and does not have to redo your archaeology or discover your races for you. That is contribution work that reduces upstream workload rather than transferring your debugging burden to them.

---

## Reviewer 3

# CO-02 — Second-round independent review

Revision: [`4ee379d`](https://github.com/ivoitovych/qca9377-bt-hang/commit/4ee379d1fbcddf7e0da9388fef1f59a30787b8e0) Date: October 22, 2026 Scope: Three kernel patches, revised BlueZ tests, cover letter, and updated evidence.

## 1. What has improved

This is a substantial technical improvement over the first submission, not merely an editorial revision.

The most important development is that the previously suspected race was reproduced under a controlled interleaving, and a dedicated third patch was developed for it. That converts an unresolved concurrency concern into a specific, testable fix.

I also verified the upstream history for the revised attribution:

- `e6720779ae61` is the SCO `kref` lifetime change. The recorded bisect gives a credible reason to use it for patches 1 and 3 rather than the earlier `a13f316e90fd`.
- `8a5b0135d4a5` introduced the relevant error-path `hci_conn_drop()`, making it the appropriate historical reference for patch 2.
- `e06d549fcd4a` is a genuine accepted CIS ownership fix whose treatment of reused links closely parallels the proposed SCO correction.

The reported testing is also significantly stronger.

| Verification                  | Round 2 result                                    |
| ----------------------------- | ------------------------------------------------- |
| Targeted tests                | 27/27 passed                                      |
| Unpatched regression controls | Both defects reproduced                           |
| Full SCO suite                | 33/33                                             |
| Full ISO suite                | 141/141                                           |
| Full L2CAP suite              | 111/111                                           |
| SMP MGMT suite                | 505/514, same nine failures on the unpatched base |
| Guest kernel logs             | 26/26 reported clean                              |
| Kernel checkpatch             | 0 errors, 0 warnings, 0 checks                    |

These are results documented by the project; I have inspected the reports and source patches, but have not independently executed the kernels or inspected the private raw test logs.

The strongest evidence is not the number of successful repetitions. It is the combination of negative controls, targeted fault injection, explicit state assertions, and comparison against an unmodified baseline.

That is exactly the kind of evidence that helps maintainers evaluate a concurrency fix efficiently.

## 2. Patch 3 — Concurrency and deadlock review

No demonstrated blocker

I checked the new `cancel_delayed_work_sync()` approach against `hci_conn.c`, `hci_sync.c`, `sco.c`, and `hci_core.h` at the exact base `27731ba09195`.

The important sequence is:

1. `sco_connect()` enters with `hdev->lock` held.
2. `hci_connect_sco()` finds an existing linked SCO connection.
3. Patch 2 acquires the missing SCO hold.
4. Patch 3 waits for any already-running `disc_work`.
5. It rechecks `abort_reason` and returns `-ECONNABORTED` if the disconnect worker committed to aborting the connection.

That ordering is logical.

The workqueue behavior supports the proposed synchronization:

- `hci_conn_timeout()` does not directly acquire `hdev->lock` for SCO.
- `hci_proto_disconn_ind()` returns a constant for SCO rather than entering L2CAP's disconnect logic.
- `hci_abort_conn()` records the abort and schedules command processing; it does not synchronously wait for that command's completion on this path.
- `hci_conn_del()` already uses synchronous cancellation of the same delayed work.

I therefore do not see a deadlock in the examined SCO execution path.

This is not a formal proof covering every possible interaction, and the reported KCSAN runs are not a substitute for lock-order verification. But the new patch is well motivated and considerably stronger than simply checking `refcnt == 0`.

One small improvement would be to make the commit message explicitly state that the synchronous wait is safe because SCO's timeout callback only schedules the later asynchronous disconnect operation, rather than executing it under the device mutex.

I would retain patch 3 as a separate commit. It fixes a distinct, reproducible race and deserves its own explanation.

## 3. The revised BlueZ test

One assertion still worth fixing

The new test fixes the two biggest problems from round 1.

First, its result criteria are much stricter. Reconnect After Disconnect now requires a real connection to be established. Reconnect During Disconnect accepts `ECONNABORTED` or a verifiably separate connection setup, not arbitrary errors.

Second, the event interception is now faithful to the emulator's own teardown. Moving the interception to the post-event hook allows normal controller-side connection removal before delaying delivery to the host. This removes my previous objection.

The Connect Twice test is also a meaningful addition. It verifies `EBUSY`, preservation of the first socket, and eventual release of the SCO and ACL links.

### Remaining assertion issue

In `reconnect_linked()`, the test registers a watch for:

`G_IO_OUT | G_IO_ERR | G_IO_HUP`

But the callback does not inspect its `cond` argument. It tests `SO_ERROR` and the setup/completion counts.

That is much better than the old oracle, but I would additionally reject error or hangup conditions and explicitly require the expected writable/connected condition.

Otherwise, an unusual sequence in which the connection completes and immediately closes may be reported as successful if `SO_ERROR` happens to be zero when examined.

A brief subsequent stability check would make the assertion stronger still, although I would treat that as optional.

This is a small, localized fix, not a reason to redesign the 485-line test.

## 4. Commit history and stable backports

I confirm that the revised `Fixes:` tags are defensible.

There is, however, an important distinction between identifying the introducing commit and providing a stable-backportable patch series.

Patch 3 depends on the code introduced by patches 1 and 2. Patch 2's published diff also depends on context introduced by patch 1.

Therefore, adding `Cc: stable@vger.kernel.org` to patch 2 alone is not sufficient to establish a safe backport plan.

The kernel stable documentation supports identifying prerequisites and says that patches in a series already marked for stable inclusion need not list one another separately.




My recommendation is to evaluate the three commits as a dependency chain, determine the oldest affected supported kernel lines, and mark the applicable fixes consistently for stable consideration. Do not assume that all three apply unchanged to every supported stable series.

This is particularly important because patch 1's identified regression begins in v6.13, while patch 2's harmful error-path behavior was introduced later.

## 5. Two submission-quality matters still open

### A. BlueZ's AI-assisted contribution guidance

I verified `AGENTS.md` at the pinned BlueZ revision `7bc9684dc9e4`.

It requests an `Assisted-by` trailer for AI-assisted contributions, including the assisting tool and model version.

The BlueZ patch currently has no such trailer.

That is a real discrepancy with the receiving project's written guidance, regardless of what its automated style checks accept.

Because attribution is also a privacy and authorship decision, I would not modify that trailer without your approval. But I cannot certify the current BlueZ mail as fully compliant with the documented guidance.

The kernel's `Signed-off-by` requirements and the BlueZ project's trailer conventions must be handled separately.

### B. Outgoing package layout

The `patch/v1/` directory currently contains two files beginning `0001-`: one kernel patch and one BlueZ patch.

That is not itself a code defect, but an indiscriminate `*.patch` send command could accidentally mix the two series.

I recommend separating them into `kernel/` and `bluez/` subdirectories, or preparing a verified, explicit send manifest.

Also, the dossier's top-level README retains its old opening description of a two-patch series, even though the current-package section correctly points to three patches. Updating those first paragraphs would eliminate the remaining documentation ambiguity.

## 6. Outstanding decisions

| Decision               | Recommendation                                                                      |
| ---------------------- | ----------------------------------------------------------------------------------- |
| Cc Hitalo Souza        | Yes. Closely related active SCO work                                                |
| Cc Aldo Ariel Panzardo | Yes. Directly relevant accepted ownership precedent                                 |
| Cc Pauli Virtanen      | Reasonable, optional. Valuable PipeWire perspective, especially on the cover letter |
| `Cc: stable`           | Yes, after assessing the three-patch dependency chain                               |
| BlueZ test timing      | Same day, separately, after the kernel series                                       |
| Deferral RFC           | Keep the brief offer, without sending the prototype yet                             |
| ELL files in `/usr`    | Remove verified local-install artifacts and fix the build prefix                    |
| Permission cleanup A   | Approve in principle, after confirming the 42 rules are obsolete                    |
| Permission cleanup B   | Approve selectively, not as a blanket wildcard permission                           |

For permission cleanup B, I particularly recommend caution with allowing execution throughout `contributions/*/experiments/*`. That is a broad permission over a directory containing executable research artifacts. Prefer narrowly scoped commands. The `cache/sparse/sparse` and `clang --analyze` permissions can be considered individually.

The ELL removal and permission changes are local machine-maintenance decisions. They should not appear in upstream mail and are not technical prerequisites for accepting the kernel patches.

## 7. Current upstream compatibility

I checked the repository heads:

Kernel bluetooth-next

`27731ba09195`

Matches base

BlueZ master

`7bc9684dc9e4`

Matches tested base

Both remain at the revisions identified in the dossier at the time of this check. This eliminates an otherwise common cause of last-minute upstream submission trouble.

## 8. Final verdict

Technically strong — minor send preparation remains

My verdict has improved substantially from round 1.

I no longer consider the disconnect-worker race an unresolved technical blocker. The recorded experiment demonstrates it, the additional patch addresses the demonstrated mechanism, and my review of the pinned source supports the synchronization argument.

The kernel series is now in a condition where I would be comfortable recommending it for upstream review, subject to the final send checks.

I recommend resolving the remaining BlueZ event-condition assertion, complying with or explicitly resolving BlueZ's attribution guidance, clarifying the stable backport dependencies, and separating the outgoing mail packages.

These are comparatively small tasks. They should not require another extensive kernel investigation.

There is one substantive limitation that must remain clear: the series prevents incorrect SCO behavior, but it does not by itself restore the immediate PipeWire 1.0.5 codec-switch retry. The cover letter states this appropriately. The more ambitious deferral implementation can be discussed separately.

Most importantly, the contribution now looks like work intended to make a maintainer's job easier: a well-defined problem, small kernel corrections, controlled negative and positive experiments, historical evidence, and tests corresponding to the distinct failure modes.

That is the right direction for a high-quality Linux Bluetooth contribution.

No repository changes or external submissions were made during this second review.

---

## Reviewer 4

## CO-02 — second-round review (`4ee379d`)

I have retrieved the actual three kernel patches, cover letter, review request, and results document from the pinned commit.

This is a substantial improvement over `4c82e91`. The second round addresses the most serious objections raised previously: it adds a dedicated test for patch 2, tightens the BlueZ test's success conditions, identifies the regression commit through bisecting, and adds patch 3 for the independently reproduced timeout race.

The evidence is also much more useful to an upstream reviewer:

- 27/27 focused runs pass across UP, 4-CPU SMP, and KCSAN configurations.
- The unpatched base fails both regression cases; the reconnect-after-teardown control passes.
- The full-suite comparison reports identical outcomes with and without the series, including the same nine SMP `mgmt-tester` failures.
- The results document records 26 clean guest logs and the tested kernel identity.

These are findings from the committed results document, not an independent rerun of its QEMU tests.

The crucial remaining question is whether patch 3's synchronous cancellation is safe in the complete kernel workqueue and locking context. That deserves a source-level check before treating the package as ready to send.

## 1. Kernel correctness: the most important findings

I compared the three outgoing diffs against the source at the exact stated base, `bluetooth-next` commit `27731ba09195`, rather than relying only on the newer mainline code.

Strong

Patch 1 — reject reuse of an aborting SCO connection

The mechanism matches the code. `hci_connect_sco()` looks up an existing connection by type and address, while `hci_abort_conn()` sets `abort_reason` without immediately changing the connection from `BT_CONNECTED`. Returning `-ECONNABORTED` prevents the false successful connection.

The revised `Fixes: e6720779ae61` is materially better supported by the bisect. I also verified the identified upstream commit and its actual changes.

Strong

Patch 2 — restore the caller's SCO hold

The reference-accounting argument is convincing. On an existing link, `hci_conn_link()` returns without taking a new SCO hold. Meanwhile, `sco_connect()` expects a caller-owned hold and drops it on its relevant paths.

The patch supplies that missing hold and releases the redundant ACL hold. I verified that `8a5b0135d4a5` introduced the relevant error-path drop, and that accepted commit `e06d549fcd4a` provides a close CIS precedent.

Plausible

Patch 3 — synchronize with the running timeout worker

This is the correct class of fix for the race you found. `hci_conn_hold()` only calls `cancel_delayed_work()`, which cannot stop a callback that is already running. The new code calls `cancel_delayed_work_sync()` and checks `abort_reason` again before returning the reused connection.

Importantly, the exact-base SCO timeout path does not directly acquire `hdev->lock`. For SCO/eSCO, `hci_proto_disconn_ind()` returns a constant, and `hci_abort_conn()` schedules the disconnect operation rather than waiting for it to finish. I found no immediate lock inversion in that path. The existing `hci_conn_del()` path also synchronously waits for this work.

This is a positive source-level assessment, not a formal proof covering every possible indirect lock dependency.

Relevant upstream source: [hci_conn.c at the exact base](https://github.com/bluez/bluetooth-next/blob/27731ba091954eccddb2657053b590d2113e8d98/net/bluetooth/hci_conn.c); [accepted CIS ownership fix](https://github.com/bluez/bluetooth-next/commit/e06d549fcd4a0ba381ed67ddf1ab3c7a6ca4314c).

### One concurrency concern remains worth checking

The first `sco->abort_reason` read added by patch 1 is performed while `hci_conn_timeout()` can write that field without `hdev->lock`.

Patch 3 addresses the behavioral race: after synchronous cancellation, it makes the decision using the completed worker's state. But the first read is still an unsynchronized ordinary C access.

I would specifically ask the reviewer whether `READ_ONCE()` is appropriate at that first read, and whether the writer needs corresponding treatment. I would not broaden the condition to `refcnt == 0`; the earlier reviewers' warning about legitimate incoming SCO states remains valid.

This is a medium-severity concurrency-review question, not evidence that the new algorithm fails.

## 2. BlueZ regression test

I read the actual 485-line addition to `tools/sco-tester.c`, including its three new cases and the event-hook logic.

The prior weaknesses are substantially corrected. The test no longer considers an arbitrary immediate error a pass, and it distinguishes a genuinely new connection from a socket that merely claims to be connected. The new Connect Twice case also directly exercises the failure patch 2 is meant to prevent.

I independently checked the BlueZ emulator implementation. Its post-event hook can suppress delivery of Disconnection Complete after the emulator has processed the disconnection. The subsequent `btdev_send_event()` call is a valid way to deliver the held event. That supports your claim that the controller-side teardown is now faithful.

Two smaller review points remain:

- Test size and maintainability: 485 added lines for three scenarios is a meaningful ongoing maintenance commitment. The cases share enough machinery that I would not automatically split the patch, but the reviewer should check whether the helper state and timer handling are as simple as possible.
- ACL teardown assertion: in Connect Twice, the test treats a Disconnection Complete for a handle other than the SCO handle as the ACL teardown. In this isolated emulator scenario that is probably sound, but checking against the known ACL handle, if available, would make the test's final assertion stricter.

Neither point invalidates the reported results.

### A submission-policy issue that is still unresolved

The current BlueZ [AGENTS.md](https://github.com/bluez/bluez/blob/master/AGENTS.md) explicitly requests an `Assisted-by:` trailer when AI tools contribute to development. Its bug-fixing procedure also directs AI-assisted work to include that tag.

The outgoing BlueZ patch contains no such trailer. Given the development workflow described in the dossier, I cannot certify compliance with that written guidance as it stands. The human author remains responsible for the code, and the question is specifically whether this contribution falls within that attribution requirement.

This is separate from kernel `Signed-off-by:` rules. BlueZ's [maintainer guidelines](https://github.com/bluez/bluez/blob/master/doc/maintainer-guidelines.rst) explicitly say not to use `Signed-off-by:` in the BlueZ userspace tree.

## 3. Outstanding findings, ranked

| Severity            | Finding                                                                                                                         | Recommendation                                                                          |
| ------------------- | ------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------- |
| High — BlueZ policy | `Assisted-by:` requirement may apply to the AI-assisted test contribution                                                       | Resolve compliance before sending the BlueZ patch                                       |
| Medium              | Initial `abort_reason` read races with a write outside `hdev->lock`                                                             | Review `READ_ONCE()` and synchronization semantics                                      |
| Medium              | Patch 3's synchronous cancellation is supported by source reasoning, but indirect lock interactions are not exhaustively proven | Keep the deterministic race experiment; a lockdep-enabled run would strengthen evidence |
| Medium              | The original PipeWire codec-switch failure is not fully fixed by refusal                                                        | Keep that limitation explicit                                                           |
| Low                 | BlueZ test assumes a non-SCO disconnect event is the ACL teardown                                                               | Tighten the handle assertion where practical                                            |
| Low                 | README's opening paragraph still describes the superseded two-patch package                                                     | Make `patch/v1/` unambiguously authoritative                                            |
| Evidence limit      | Raw QEMU logs and the scratch race-injection code remain on the development host                                                | Preserve them and make the deterministic procedure readily reproducible for reviewers   |

There is an important distinction in the fourth row. The kernel fix has independent value even though PipeWire 1.0.5's immediate retry still fails. It replaces a false successful connection with an accurate error and protects an already established connection from collateral teardown. The deferral prototype addresses a different question: how to make the codec-switch workflow succeed end to end.

I would not make acceptance of this kernel correctness fix depend on accepting the larger deferral design.

## 4. Decisions I recommend

| Open decision                 | Recommendation                                                                                                                                                   |
| ----------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Cc Hitalo Souza               | Yes, particularly for the BlueZ test and its overlap with the pending SCO work                                                                                   |
| Cc Aldo Ariel Panzardo        | Yes, especially patch 2; he authored the closely related accepted CIS fix                                                                                        |
| Cc Pauli Virtanen             | Yes on the cover-letter/userspace discussion; less reason to include him on every kernel patch                                                                   |
| `Cc: stable`                  | Add to patch 2, which repairs an observable regression caused by a previous fix. Assess patches 1 and 3 together for stable handling, documenting dependencies   |
| BlueZ test timing             | Separate BlueZ email immediately after the kernel series, with its kernel dependency explicit                                                                    |
| Deferral paragraph            | Keep a short explanation of the alternative, but don't make the final cover letter ask maintainers to design the fix                                             |
| ELL installation under `/usr` | Separate machine-hygiene work; remove only after inventorying the installed files and ensuring they aren't used, then fix the build tool to use a private prefix |
| Permission cleanups A/B       | Separate from the submission unless they affect actual patch contents or test execution; their precise scope is not established in the reviewed package          |

The stable recommendation is supported by the kernel's [stable-kernel rules](https://www.kernel.org/doc/html/latest/process/stable-kernel-rules.html). Adding the tag is not simply a courtesy copy: it asks for stable consideration once the patch is merged, so dependencies must be reliable.

## 5. One cover-letter adjustment

The cover letter is now concise and largely decision-ready. I would improve the testing paragraph by explicitly stating the remaining baseline detail:

> On the 4-CPU kernel, `mgmt-tester` passes 505/514 tests both with and without the series; the same nine cases fail in both configurations.

That is more informative than an unqualified statement that all other suites are unchanged, and it preempts questions about the nine failures.

I would also state the difference between the correctness fix and the end-to-end codec-switch fix in one clear sentence, so reviewers do not have to infer it from the deferral discussion.

## Final verdict

Kernel series: ready for upstream review after a focused final pre-send check.

BlueZ regression test: technically much improved, but its attribution-policy question needs resolution before I would call the submission fully compliant.

I no longer see the four major technical objections from round 1 as unaddressed. The mechanism is credible, the third patch is supported by a deterministic race reproduction, the reference accounting is aligned with upstream precedent, and the BlueZ test now protects both observable defects.

I still would not claim to have proved concurrency correctness or independently repeated the 27 runs; that would overstate this review.

But in terms of usefulness to a busy maintainer, this now looks like a genuinely serious, well-prepared contribution. The public kernel diff is only 36 changed lines, the defect is explained, the old behavior is reproduced, and the adjacent subsystems have been regression-tested. The remaining work is small and specific rather than another investigation cycle.

No repository files were changed and nothing was sent.

---

## Reviewer 5

**The revision resolves the substantive first-round findings. My updated verdict is: the three kernel patches are ready for upstream review; the BlueZ test is substantially improved, with one small defensive check still worth adding.**

I reviewed the actual files pinned to [`4ee379d`](https://github.com/ivoitovych/qca9377-bt-hang/tree/4ee379d1fbcddf7e0da9388fef1f59a30787b8e0/contributions/CO-02-sco-connect-reuses-closing-link/patch/v1), the updated evidence and log, the kernel call paths, and the `e6720779ae61` diff. I did not rerun QEMU or inspect the raw logs stored on your development host. My conclusions distinguish source verification from your reported measurements.

**The earlier findings**

| Finding | Round-two assessment |
|---|---|
| Any immediate connection error could pass | **Fixed.** During accepts `ECONNABORTED`; After requires establishment; unexpected errors fail. |
| Emulator teardown was skipped | **Fixed.** The `POST_EVT` hook suppresses delivery while normal emulator cleanup continues. |
| Patch 2 lacked a submitted regression test | **Fixed.** Connect Twice checks `EBUSY`, preservation of the first connection, and eventual cleanup. |
| Timeout worker could abort a newly reused link | **Addressed by patch 3**, with a convincing reported deterministic reproduction. |
| Regression history was inferred incorrectly | **Corrected.** The bisect and historical diff support `e6720779ae61`. |
| Superseded drafts could be mistaken for final patches | **Mostly fixed.** The current package is clearly identified, though the README’s opening paragraph remains stale. |
| Test results were described too broadly | **Improved.** The evidence now identifies the matching nine SMP management failures. |

**Patch 3: the synchronization is appropriate on this base**

I traced beyond the statement that the timeout worker does not take `hdev->lock`:

- For SCO/eSCO, `hci_proto_disconn_ind()` returns a constant.
- `hci_cancel_connect_sync()` takes its default return for these connection types.
- When called from `disc_work`, `hci_cmd_sync_run_once()` queues the abort; it does not execute the abort synchronously on that worker.
- The command worker releases its queue lock before executing callbacks.
- `hci_conn_del()` already synchronously disables the same delayed work during teardown.

Taking the SCO hold **before** waiting is important. It prevents a worker that has not yet made its zero-count decision from deciding to disconnect. Waiting handles the worker that already made that decision; the subsequent `abort_reason` check detects its result. Dropping the acquired SCO hold on refusal balances the new error path.

**I found no new deadlock in that reviewed path.** This is stronger than relying solely on the existing teardown precedent. I would describe it as safe for the audited SCO/eSCO path on this base, rather than making an unrestricted “cannot deadlock” claim about future changes.

The deterministic parked-worker experiment is exactly the evidence the first review needed. Ordinary repeated tests would not have been an adequate substitute.

**The corrected `Fixes:` tags are better supported**

I need to correct my previous review: **my endorsement of `a13f316e90fd` was too confident.** Removing the `BT_DISCONN` assignment did not establish when a replacement socket could actually attach and report success.

The [`e6720779ae61` diff](https://github.com/bluez/bluetooth-next/commit/e6720779ae61) changes SCO connection lifetime and close handling in a way consistent with your bisect result. The new patch-1 explanation records the relevant behavioural distinction: previously `EBUSY`, subsequently false success.

I support:

- **Patches 1 and 3:** `e6720779ae61`, for the false-success regression described.
- **Patch 2:** `8a5b0135d4a5`, for the duplicate-connect error path disconnecting the owner.

Patch 3’s attribution is supported by the shared attachment mechanism and history; the evidence describes a bisect of the ordinary reconnect defect, not a separate bisect of the parked-worker case. That distinction does not make the tag inappropriate.

**One remaining BlueZ test improvement**

In `reconnect_linked()`, the watch subscribes to:

```c
G_IO_OUT | G_IO_ERR | G_IO_HUP
```

but the callback ignores `cond`. It checks `SO_ERROR` and command/event counters, then declares success.

I recommend explicitly requiring writable readiness and rejecting error/hangup conditions. Apply the same principle to `reconnect_first_connected()`.

This is **defensive strengthening**, not another demonstrated reproduction of the original false-pass bug. `SO_ERROR == 0` alone is not a general guarantee that the callback represents a healthy connected socket.

The rest of the test now expresses the intended scenarios much more precisely. In particular, not requiring different numerical handles is correct: the emulator can reuse a handle after teardown.

**The evidence is sufficient for submission, with clear limits**

The reported results now cover the meaningful distinctions:

- Unpatched failures for both bug cases.
- Patch 1 alone leaving Connect Twice broken.
- The complete series passing all three cases.
- UP, SMP and KCSAN configurations.
- A deterministic test specifically distinguishing patches 1–2 from patches 1–3.
- Matching SMP management-test failure identities, rather than merely matching totals.

I would **not demand another arbitrary batch of management-test runs** before submission. You have addressed the concrete concern by comparing the failing cases.

Two wording points remain:

1. Your hand-off says the full suites have the same results with and without the series. Strictly, the new SCO bug cases change from fail to pass. The cover letter’s word **“otherwise”** correctly handles this.
2. The README still begins with the old two-patch/20-run summary. Replace that opening with the current three-patch status; retain the earlier results as history.

The 26-log clean result should remain explicitly scoped to the final runs. The project log separately records earlier KCSAN reports outside SCO. There is no contradiction if those scopes stay clear.

Raw logs and the debug race instrumentation remain local. Making a small reproducibility bundle available would improve independent auditing, but I would not make publication of hundreds of logs a prerequisite for these small fixes.

**Submission decisions**

| Item | Recommendation |
|---|---|
| Cc Hitalo, Aldo and Pauli | **Yes.** Each has a specific technical connection to this work. |
| `Cc: stable` on patch 2 | **Yes.** It fixes a demonstrated regression affecting an existing connection. |
| Stable handling of patches 1 and 3 | Consider them together, documenting patch 3’s dependency on patch 2’s hold accounting. Do not assume identical applicability to every older tree. |
| BlueZ timing | **Same day, after the kernel series**, as a separate thread with the dependency note already present. |
| Deferral prototype | Keep it as the optional follow-up described in the cover letter. |
| ELL and permission cleanups | Separate local work; not upstream submission blockers. |

Stable guidance explicitly provides for dependency information and backports needing adjustments. A `Fixes:` tag identifies history; it does not establish that a patch can safely be cherry-picked into every affected tree. [The Linux Kernel documentation](https://docs.kernel.org/process/stable-kernel-rules.html)

The previously identified BlueZ attribution-guidance mismatch remains unchanged; the new package has not resolved that policy point. I have made no attribution changes or external submissions.

**I would now support sending the kernel series for maintainer review.** Add the small callback-condition checks to the BlueZ test, refresh the README opening, and retain the explicit limitation that this fixes kernel connection handling but does not by itself restore PipeWire 1.0.5’s codec-switch recovery. The remaining work is focused finishing work, not another redesign or broad testing campaign.

---

## Reviewer 6

Pulling `4ee379d` and reading the v1 series, especially patch 3 and the new `Fixes:` history.
Round 2 holds up. I re-applied the three patches on `27731ba09195` (`git am` clean, `checkpatch --strict` 0/0/0 ×3), applied the BlueZ patch on master `7bc9684`, and traced every claim in patch 3 and the new `Fixes:` history through the tree. Nothing stops the send. Three small edits, then go.
Verified

* Patch 3 is correct and cannot deadlock. For SCO, `hci_conn_timeout()` → `hci_proto_disconn_ind()` returns a constant; `hci_abort_conn()` → `hci_cancel_connect_sync()` returns `-ENOENT` for SCO, then `hci_cmd_sync_run_once()` takes only `unregister_lock`/`cmd_sync_work_lock` and queues (it runs inline only from `cmd_sync_work`, which this isn't). No `hdev->lock` anywhere on that path. `hci_conn_del()` already does `disable_delayed_work_sync(&conn->disc_work)` under `hdev->lock` (line 1300), so the lockdep dependency exists in-tree. Hold-then-`cancel_sync`-then-recheck is the right order: a worker that hasn't started is cancelled by the hold; one past its refcnt read is waited for and has set `abort_reason` by the time the wait returns.
* `Fixes: e6720779ae61` is right, and it's Luiz's own commit. I pulled v6.12's `__sco_sock_close()`: for `BT_CONNECTED` it set `BT_DISCONN`, dropped the hcon and kept `conn->sk` until the Disconnection Complete — so a second connect hit `sco_chan_add()`'s `conn->sk` check and got EBUSY. `e6720779ae61` removed exactly that block. Your bisect result matches the diff.
* Patch 2's message now states the contract (caller owns one reference, always), cites `e06d549fcd4a`, and says EBUSY stays. Good.
* BlueZ test: `POST_EVT` hook returning false suppresses the event in `send_event()`; your later `btdev_send_event()` re-runs the hook with `disc_released` set and passes. The oracle is strict now; Connect Twice fails on base for the right reason (Disconnect while the socket is open) and also catches the leaked ACL hold via the 3 s deadline. The note under `---` is correctly placed and will be stripped by `git am`.

Fix before sending

1. The BlueZ mail's diffstat was hand-edited: `tools/sco-tester.c | 486++++…` (no space before the pluses). `git am` doesn't care; a human notices. Regenerate with `git format-patch` and re-insert the note below `---`.
2. Patch 1, one clause. "Before commit e6720779ae61 such a connect() failed with EBUSY" — add why: the closed socket stayed attached to the connection in `BT_DISCONN` until the Disconnection Complete, so `sco_chan_add()` refused the second one. Luiz wrote that commit; one clause lets him see at once that the tag is right, rather than wondering whether you bisected into a merge.
3. `Cc: stable@vger.kernel.org` on patch 2. None of the three carries it. Patch 2 is a refcount imbalance that kills a live link, triggered by a CVE fix that's been backported everywhere; the CIS precedent carried the tag. The maintainer can drop it; he can't add it for you after the fact without a resend.

Have ready (don't pre-empt in the mail)

* The residual window patch 3 doesn't close. Between `close()` (refcnt → 0, `disc_work` queued) and the worker starting, a new connect finds no `abort_reason`, patch 2's hold cancels the pending work, and the new socket adopts the old link as-is — old air parameters, no renegotiation. Pre-6.13 that was EBUSY too. Reachable only if the workqueue is delayed; PipeWire's gap is the AT+BCS round trip, ≥16 ms. A refcnt-after-hold check would close it, but only `hci_conn_timeout()` reads `refcnt` directly in-tree — new idiom, untested. Keep patch 3 as is; if Pauli raises it (he knows the codec-switch flow), say what I just said and offer a follow-up.
* "Why SCO-only / why not in `hci_conn_hold()`?" — `hci_conn_hold()` is called from non-sleeping contexts; ACL/LE reuse has the same TOCTOU with a different consequence; out of scope.
* "Squash 3 into 1?" — possible ask. Either is fine; separate is better for bisect since 3 adds a sleeping call under `hdev->lock`.

Nits (your call)

* Connect Twice: 3000 ms deadline vs 2000 ms ACL `disc_timeout` leaves ~1 s on a loaded CI box. 5000 fits the 8 s case timeout.
* Comments: the test now mixes 3 bare `/*` openers with 7 `/* text` ones; the file's majority is `/* text`. BlueZ has both; nobody will block on it.
* Two `CHECK:SPACING` on `(void *) client_bdaddr` match the existing file. Ignore.

Send decisions: Cc all three (Hitalo, Panzardo, Pauli), stable on patch 2, BlueZ mail same day after the series — your recommendations are right. ELL in `/usr` and the permission clean-ups have no bearing on the mails; do them after.
Sources:

* [e6720779ae61 — Bluetooth: SCO: Use kref to track lifetime of sco_conn](https://code.amethyst.name/public-mirrors/linux/commit/e6720779ae61)
* [v6.12 net/bluetooth/sco.c](https://github.com/torvalds/linux/blob/v6.12/net/bluetooth/sco.c)
* [Cen Zhang, [PATCH v2] Bluetooth: SCO: fix race conditions in sco_sock_connect()](https://lkml.iu.edu/2603.3/06696.html)
* bluetooth-next `27731ba09195` and BlueZ master `7bc9684` read from the [bluez/bluetooth-next](https://github.com/bluez/bluetooth-next) and [bluez/bluez](https://github.com/bluez/bluez) mirrors.
