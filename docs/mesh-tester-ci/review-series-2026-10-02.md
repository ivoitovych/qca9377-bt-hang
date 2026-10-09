# Private review — mesh advertising kernel series and BlueZ tests

*(An outside review as received on 2026-10-02. Its links point into the project's private
repository, where branch `diag/mesh-tester-ci` then lived; the files they name are on `main`
since 2026-10-09 under the same paths.)*

Reviewed: 2 October 2026. Repository snapshot: **14bdcfcd156fd00118fdb863dc4559e315544067**, branch `diag/mesh-tester-ci`. Patch author: Iaroslav Voitovych.

**Recommendation: do not send this revision yet.** The previous extended-advertising teardown blocker is closed for successful HCI commands. However, the new blocking teardown exposes an unsafe scheduling interval, patch 2 makes a demonstrably false statement about bluetooth-meshd, and the new tests do not reliably establish several of their advertised preconditions. These are specific revision requests, not a rejection of the two underlying fixes.

## Evidence and limits

I read both kernel patches, the cover letter, the complete BlueZ patch, phase 1–3 results, both review tasks, PHASE3-TASK, and the duration note. I independently retrieved the relevant kernel and BlueZ source files; references below use their actual line numbers, which sometimes differ from the numbers in the task.

- **K**: kernel `86ef0f58bdecdedb3a1240971c56d71b7e4ce3fc`, retrieved through the [bluetooth-next mirror](https://github.com/bluez/bluetooth-next/tree/86ef0f58bdecdedb3a1240971c56d71b7e4ce3fc).
- **N**: kernel `671d566d3c3ba4103b594b85e428bcb89a8482f5`.
- **B**: BlueZ `8b4a4176063831476bc9244d20f43b552e4b5554`.
- **P**: [private review snapshot](https://github.com/ivoitovych/qca9377-bt-hang-private/tree/14bdcfcd156fd00118fdb863dc4559e315544067).
- **T**: B plus the supplied BlueZ patch, whose mail identifies commit `51ab024b5eaecc5ce2ddd0c175e1bfc2aaa91721`. T line references are from independently applying that patch to B; that commit was not fetched as a separate upstream commit.
- **R**: P, [phase3-results.md](https://github.com/ivoitovych/qca9377-bt-hang-private/blob/14bdcfcd156fd00118fdb863dc4559e315544067/docs/mesh-tester-ci/phase3-results.md).

Independent execution: cumulative `git apply --check` followed by `git apply` on K, N and all five pinned stable snapshots; BlueZ patch application; kernel strict checkpatch and BlueZ-configured checkpatch; duration arithmetic. These were source snapshots, not full kernel Git checkouts: **this was not a cherry-pick, build, or guest-kernel run**.

The qemu, W=1, sparse and valgrind results below are the repository's recorded results. Their raw `tmp/mesh-tester-ci/run-p3-*.log` and `preflight-*.log` files are not tracked in the supplied repository tree. I read the quoted logs in R, not the unavailable full logs. No hardware was touched and nothing was posted, mailed or commented.

**“Inferred” means a conclusion derived from the cited source, not a reproduced kernel failure.**

## Findings that affect sending

### 1. Keep the mesh scheduler occupied through teardown and transfer ownership atomically

**High priority; source-derived interleaving, not reproduced here.**

Patch 1 retains the clear of `HCI_MESH_SENDING` at the beginning of `mesh_send_done_sync()`, then adds synchronous controller commands. During that wait, the syscall-side `mesh_send()` can accept another packet and observe the flag clear. It queues a start itself. After teardown, the done callback calls `mesh_next()`, which unconditionally queues the pending head again.

A concrete interleaving, starting with only A pending:

| Step | Done worker | Concurrent Mesh Send |
|---|---|---|
| 1 | Clears HCI_MESH_SENDING for A | |
| 2 | Waits for set-specific disable/remove Command Complete | |
| 3 | | Adds B; sees the flag clear; queues mesh_send_sync(B); sets the flag |
| 4 | Completes/removes A | |
| 5 | mesh_next selects B and queues mesh_send_sync(B) again | |

The queue helper does not deduplicate these entries. This contradicts the claimed single-owner scheduling invariant. If an older queued packet also exists, a newly submitted packet can instead be queued ahead of it. Further consequences depend on command/error/cancel ordering; I am **not claiming a reproduced UAF** from this particular interleaving.

Citations: K `mgmt.c:mesh_send_done_sync:1093–1105`, `mesh_next:1110–1124`, `mesh_send:2530–2552`; `hci_sync.c:hci_cmd_sync_work:305–345`, `hci_cmd_sync_submit:714–745`, `hci_cmd_sync_queue:751–761`; patch 1's added call.

The early clear predates this series. What changes here is that a successful ordinary mesh teardown now sleeps on controller commands while the flag is clear; previously the nonempty mesh instance list skipped the disable. This makes the existing weakness directly relevant to the new path.

**Exact revision request:**

> Keep HCI_MESH_SENDING asserted while the old mesh advertising instance is being disabled and removed. Serialize completion of the old owner, selection/queueing of the next owner, and the transition to idle against mesh_send() using the same ownership protocol. Moving the clear to the end of mesh_send_done_sync() alone is insufficient: mesh_next() still runs afterwards and can race a new syscall-side enqueue. Do not hold hdev->lock over synchronous HCI commands. Add a test that delays teardown Command Complete, submits a fresh Mesh Send during that interval, and verifies exactly one start per request and FIFO order.

This needs a coordinated scheduler change and a targeted test, not an unverified one-line edit. Reconcile it with the existing mesh list/lifetime work discussed under C1.

### 2. Patch 2 misdescribes bluetooth-meshd

**Definite message error.** B `mesh/mesh-io-mgmt.c:send_cmplt:225–229` is an empty callback apart from a commented-out print. It does **not** match completion events to transmissions by handle. `send_queued:505–519` stores the command-response handle for cancellation; that is different.

Replace the last two sentences of patch 2's opening paragraph with:

> The next packet can therefore leave the pending queue without being advertised, even though userspace has not cancelled it.

Also avoid describing the completion event as a delivery acknowledgement. Cancellation and start failures also produce it.

### 3. The new tests can pass without exercising their named scenario

**Definite assertion gaps; timing outcomes inferred.**

T `mesh_tx_send_callback:1838–1872` sends Cancel when the second Mesh Send acknowledgement arrives, without requiring that A has started and remains active. T `mesh_tx_cancel_active:1534–1543` expects the same handle order and total start/stop counts as `mesh_tx_two_completions:1573–1579`. If A finishes before Cancel reaches the kernel, cancelling its now-absent handle still succeeds, and the cancel-active test can pass as an ordinary two-completion test.

T `mesh_tx_hci_callback:1779–1826` counts mesh enables/removes and a disable-all command. It ignores a targeted disable of ordinary set 1, ignores clear-all advertising sets, and examines only the first entry of an extended-enable command. Read Advertising Features establishes host bookkeeping, not that set 1 remains enabled on the controller.

The coexistence setup also does not wait explicitly for Add Advertising success before declaring setup complete. Its callback only prints success.

**Required changes:** gate the scenario on explicit HCI/event state; fail if A completes before the intended active cancellation; include command acknowledgements in completion conditions; gate coexistence setup on Add Advertising; track all set entries and reject ordinary-set disable/removal/clear-all. See F2 and the small diffs below.

### 4. Correct the duration note before using it as a patch rationale

The overflow is real, but the 655-second table row is wrong:

`655000 mod 65536 = 65176`; integer division by ten gives 6517, or **65.17 seconds**, not 65 seconds.

The claim that every timeout above 65 seconds stops early is also false. For example, 8192 seconds produces zero in the controller duration field; with max-events zero, no finite controller duration is requested. A simple clamp also does not preserve a 1000-second MGMT timeout: it ends at 655.35 seconds. See E5.

## Requested item-by-item review

### A1 — Previous extended-advertising blocker

**Verdict: confirmed, for the successful removal path.**

K `hci_sync.c:hci_remove_advertising_sync:2201–2249` calls `hci_remove_adv_sync:2167–2188`; extended controllers reach `hci_remove_ext_adv_instance_sync:2031–2050`, which disables the specific set before issuing Remove Advertising Set. The host instance remains present until `hci_event.c:hci_cc_le_remove_adv_set:1480–1505` removes it under `hdev->lock`. The new MGMT guard then suppresses the internal-instance event. The legacy branch removes under the device lock and handles rescheduling.

R §3b quotes enable handle 4, disable one set handle 4, and Remove Advertising Set handle 4. It reports no disable-all command and an untouched ordinary set 1. This matches the source; I did not independently replay that trace.

For legitimate userspace instances, K `mgmt.c:add_advertising:9025` and `add_ext_adv_params:9217` reject IDs outside 1..le_num_of_adv_sets. The BIS allocation path inspected in `hci_conn.c:1655–1667` also stays below that bound. I found no legitimate userspace instance above the bound in the inspected callers. This is not a proof over arbitrary future callers or arbitrary raw-HCI manipulation.

**Change:** none to the basic disable → remove → host removal ordering. The scheduler issue in finding 1 is separate.

### B1 — bluetooth-meshd compatibility

**Verdict: refuted, for the claimed completion-handle dependency; cannot tell from the source whether any deployment benefits from accidental extra airtime.**

B `mesh/mesh-io-mgmt.c:send_cmplt:225–229` ignores the event. `send_queued:505–519` retains a handle; `send_cancel:488–502` uses it. `send_pkt:522–552` sets cnt=1, and `tx_to:555–611` schedules application retransmissions by its own timer/count. There is no explicit dependency on completing the queue head, omitting Disable, or keeping a packet advertised after its requested count.

**Inferred:** removing excessive airtime may change observed packet redundancy or delivery probability, but source inspection cannot establish an application workaround or quantify an RF effect. The queue-head fix remains justified by the lost pending request, independently of this daemon's unused event handler.

**Change:** use finding 2's exact replacement.

### B2 — Other consumers and workarounds in the wild

**Verdict: cannot tell from the source/search coverage.**

Public searches for `MGMT_OP_MESH_SEND`, “Mesh Send Cancel”, and related names returned BlueZ, Linux headers/implementations and patch discussions; no independently verified non-BlueZ application workaround was found. Broad `mesh_send` hits are not evidence of using this MGMT API. The searches do not cover private applications, unindexed code, numeric opcodes, or vendor forks.

The concrete external records inspected include [the original mesh change](https://github.com/bluez/bluetooth-next/commit/b338d91703fae6f6afd67f3f75caa3b8f36ddef3) and the [original regression patch thread](https://www.spinics.net/lists/linux-bluetooth/msg120817.html). Neither establishes a third-party dependency on the defective behavior.

**Exact compatibility wording:**

> No non-BlueZ workaround was identified in the public sources searched. Compatibility with unindexed or private MGMT clients has not been established.

Do not turn “not found” into “no other users exist.”

### B3 — Suppressing Advertising Removed

**Verdict: confirmed for the current instance-number invariant; cannot tell what an individual maintainer would prefer.**

K `mgmt.c:9025,9217` constrains ordinary Add Advertising IDs. `hci_core.c:hci_add_adv_instance:1677–1739` permits the additional internal mesh ID, and `mgmt.c:mesh_send_sync:2330–2354` uses it. The instance is already freed when the event helper runs, so that helper cannot simply dereference `adv->mesh`.

Keeping `instance > hdev->le_num_of_adv_sets` is a small, coherent fix. A mesh flag would require capturing it before freeing at every relevant removal site, or changing the helper interface. **Inferred preference:** the numeric guard is easier to backport and is reasonable while this reserved range remains the invariant; preference itself is not established evidence.

`read_adv_features:8768–8823` actually filters against `adv_instance_cnt`, not the bound named in its comment. Because the count is capacity-bounded, it still excludes the mesh ID, but it also incorrectly hides some sparse ordinary IDs. Do not present that function as a generally correct implementation of the documented visibility rule.

**Suggested shorter comment:**

```c
/* Mesh uses an internal instance above the userspace-visible range. */
if (instance > hdev->le_num_of_adv_sets)
	return;
```

I did not establish that every possible client ignores unexpected removed events; this change restores the intended visible instance namespace.

### B4 — Documented semantics

**Verdict: confirmed for stopping/completing the requested operation; refuted if phrased as proof of successful delivery.**

At B, the current document is [doc/mgmt-protocol.rst](https://github.com/bluez/bluez/blob/8b4a4176063831476bc9244d20f43b552e4b5554/doc/mgmt-protocol.rst), not the absent doc/mgmt-api.txt. Its transmit section is at 4075–4121; cancellation at 4123–4143; completion at 5469–5480.

The cancellation wording includes **“regardless of whether the packet was sent successfully”**. Completion says the request **“no longer occupies a transmit slot.”** Count controls how many transmissions are requested. Unsolicited completion/removal of an uncancelled queued packet violates the command's purpose; continuing indefinitely after its count is not the intended behavior.

**Exact wording for patch 2:**

> Complete only the pending request associated with the finished mesh instance. If cancellation has already removed that request, leave the other queued requests pending for mesh_next().

This avoids treating the event as a radio-delivery acknowledgement or asserting that an instance assignment always means airtime.

### C1 — Duplicates and prior art

**Verdict: cannot tell that no duplicate exists; confirmed relevant prior art and an earlier CI signature.**

The retrieved bluetooth-next mgmt.c history from June 2025 through current mirror tip `3b44711c52eaf62723a4a715e1b7b4e49f1595ce` contains no equivalent teardown/owner-match fix. The named base source also lacks one. Direct lore and Patchwork access did not yield a complete searchable archive, so a universal “no sent duplicate” claim is not justified.

Useful records actually opened:

- [Original 3/3, 25 June 2025](https://www.spinics.net/lists/linux-bluetooth/msg120817.html): the author explains the non-mesh-advertiser problem and expresses uncertainty about the unconditional disable. It does not account for the mesh instance keeping the list nonempty.
- [Its CI reply](https://www.spinics.net/lists/linux-bluetooth/msg120821.html): **8/10, both Send cancel cases timed out**, already in June 2025.
- [Applied reply](https://www.spinics.net/lists/linux-bluetooth/msg120834.html): records application of the original series. These inspected messages do not show a human discussion resolving the internal-instance lifetime.
- [August mesh list-locking proposal](https://lists.openwall.net/linux-kernel/2026/08/07/798): overlapping list-ownership work, not a duplicate of stopping the advertiser.
- [Related lifetime-series cover](https://lists.openwall.net/linux-kernel/2026/08/07/444): covers the syscall/worker locking mismatch and queued raw-pointer lifetime.
- [Bot PR 547](https://github.com/bluez/bluetooth-next/pull/547) was closed without a GitHub merge; that alone does not prove upstream rejection.
- [Bot PR 798](https://github.com/bluez/bluetooth-next/pull/798) was open and concerns queue-submission-failure leakage, not this teardown defect.

**Exact note to retain privately:**

> Related pending/historical mesh lifetime work must be reconciled before claiming that cmd_sync serialization protects mesh_pending against all callers. The original introducing series already produced the same two cancel timeouts in its 25 June 2025 CI report.

No third-party attribution tag should be invented from this discovery.

### C2 — 71af682ba469 and 3c742feda8fc

**Verdict: confirmed, with the scheduler qualification in finding 1.**

I read both [71af682ba469](https://github.com/bluez/bluetooth-next/commit/71af682ba4692c2ed9ace4c3d4ca462ae368c029) and [3c742feda8fc](https://github.com/bluez/bluetooth-next/commit/3c742feda8fcabf741a17bcf668b63c8f606f9c5) and their diffs. The former dequeues queued start work before freeing cancelled requests and advances on selected errors/cancels. The latter frees the cancellation command through a destroy callback. Neither restores mesh advertiser teardown or chooses the correct normal-completion owner.

For an already-running A cancelled before its done callback, the older send_cancel also removes A; selecting by instance therefore works without 71af. The callback on mesh_send_done still advances through mesh_next. That supports R §4d's **narrow dependency claim** for patch 2, not general safety of every cancellation path on old kernels.

**Change:** preserve both fixes' intent. Do not introduce device-lock acquisition into a destroy callback without accounting for its -ECANCELED invocation under cmd_sync_work_lock. Do not copy the August locking proposal unchanged onto the newer cancellation implementation.

### D1 — Checkpatch, W=1 and sparse

**Verdict: confirmed for the limited independent style run; cannot tell independently for complete build/sparse validation.**

Independent strict checkpatch initially produced only unavailable-local-history warnings. I verified the Fixes hashes and subjects through the actual commit objects, then reran with `--ignore UNKNOWN_COMMIT_ID`, also used by current action-ci:

| Patch | Errors | Warnings | Checks | Lines |
|---|---:|---:|---:|---:|
| Kernel 1/2 | 0 | 0 | 0 | 35 |
| Kernel 2/2 | 0 | 0 | 0 | 34 |
| BlueZ, its .checkpatch.conf | 0 | 0 | not enabled | 606 |

K `scripts/checkpatch.pl` lists `--subjective` and `--strict` as aliases. I also invoked `--codespell`, but no usable dictionary was available: the program explicitly reported that codespell typos would not be found. **No clean codespell claim is made.** Gitlint was not installed.

R §4a records W=1/-Werror clean and sparse base=0/patched=0 for both patches, with a positive-control check that sparse actually ran. The raw logs and full configured build trees were unavailable here.

**Change:** keep those results labelled as recorded; rerun the existing gates after substantive revisions. These limitations are not themselves the reason for the do-not-send recommendation.

### D2 — Kernel submission form

**Verdict: confirmed, apart from the factual message revisions.**

The kernel subjects use Bluetooth: MGMT:, imperative verbs and no first person. Both Fixes hashes/subjects match the retrieved objects; Cc: stable precedes Iaroslav's sign-off. Ordinary message paragraphs are wrapped; the long Fixes line is an accepted exception. The cover identifies the base and separates the two defects.

Citations: P kernel patch headers/trailers; K `Documentation/process/submitting-patches.rst:94,145–163,538–629`; `stable-kernel-rules.rst:7–29,70–100`.

**Change:** shorten the claims using B1/B4/H. Do not add Reported-by, Reviewed-by or Tested-by names without an actual applicable contribution/permission. Preserve Iaroslav's authorship.

### D3 — Kernel comment style and conventions

**Verdict: confirmed for conventions; refuted as an unconditional “on air” assertion.**

Early return in mgmt_advertising_removed and the synchronous helper call match nearby patterns. `sent` and `mesh_tx` are intelligible. The comments are long relative to the code.

K `mesh_send_sync:2350–2379` assigns mesh_tx->instance after instance creation, then can defer scheduling because another legacy instance is rotating. Thus “only the one on air carries it” is too strong; assignment identifies the request that acquired the mesh instance, including a request never actually aired.

**Suggested owner-match comment:**

```c
/*
 * Only the request that acquired the mesh instance has a nonzero
 * instance. Cancellation may already have removed that request;
 * do not complete an unrelated queued request.
 */
```

Kernels commonly put the first comment text on the opening line; the existing kernel style is not a blocker. Use this shorter text after resolving scheduler ownership.

### D4 — Patch split and ordering

**Verdict: confirmed.**

The two defects have distinct provenance: f3cb5676e5c1 changed the disable condition; b338d91703fa introduced the queue-head completion. Teardown first, owner accounting second is defensible, and both intermediate revisions are small. The event guard belongs with teardown because correct extended removal would otherwise expose the internal instance; splitting it out would produce an avoidable intermediate behavior change.

Citations: retrieved original commit diffs; P 1/2 and 2/2. The successful cumulative apply checks support the present order, not its runtime sufficiency.

**Change:** keep this split unless scheduler ownership requires a prerequisite patch. In that case make the prerequisite explicit and validate the resulting intermediate commits. No need to reverse these two merely for stylistic reasons.

### E1 — Correct teardown layer

**Verdict: confirmed.**

K `mgmt.c:remove_advertising_sync:9504–9523` uses the same helper followed by the same empty-list disable. `hci_sync.c:adv_timeout_expire_sync:543–553` uses the expiry-specific clear helper with force=false. Removing only host bookkeeping or directly using the global disable would reintroduce the earlier failure.

**Change:** retain hci_remove_advertising_sync as the lifecycle operation. The important remaining issue is scheduler ownership around it, not moving controller-specific logic into mgmt.c.

### E2 — force=true, sk=NULL, rescheduling and flags

**Verdict: confirmed for the intended helper semantics; refuted as sufficient scheduler synchronization.**

K `hci_sync.c:hci_remove_advertising_sync:2190–2249` documents force=true as removal despite remaining lifetime. Without it the 1000-second mesh instance would usually survive. The helper obtains the successor before removing the current instance and reschedules it only on the legacy path. Powered/HCI_ADVERTISING checks govern subsequent rescheduling; they are not an initial guarantee that no teardown operation is attempted.

sk=NULL is appropriate for internal teardown with no originating Remove Advertising request. The new event guard prevents the internal event being broadcast regardless of that socket choice.

**Change:** implement finding 1's exact ownership requirement. HCI cmd_sync ordering serializes queued workers; it does not serialize syscall-side mesh_send against a worker sleeping for controller completion.

### E3 — Legacy coexistence

**Verdict: confirmed as a pre-existing limitation; inferred recommendation to disclose and handle separately.**

K `mesh_send_sync:2356–2385` records the mesh instance but can set the local scheduling instance to zero while another legacy advertiser is rotating. The completion timer is nevertheless armed by `mesh_send_start_complete:2319–2322`. R's open question 1 explicitly acknowledges no mesh airtime in that case.

The series should not silently absorb a redesign of legacy multiplexing. However, the cover and test rationale must not claim successful coexistence transmission.

**Exact cover sentence:**

> The legacy coexistence case checks preservation of the ordinary advertiser only; mesh transmission while another legacy instance is rotating remains a separate pre-existing limitation.

Keep the case named around preserving the ordinary instance. Do not treat its current no-mesh-airtime behavior as a desirable API invariant.

### E4 — Where to remove; errors, power-off and close

**Verdict: refuted if the claim is that all lifetime paths are fixed.**

Removing the advertiser indiscriminately inside mesh_send_complete is wrong: queued cancellation, start failure and socket cleanup also call it, and a queued request must not tear down another request's set. Moreover, that helper is not uniformly a context in which synchronous HCI commands are safe.

K `mesh_send_sync:2339–2385` can successfully add an instance and then fail scheduling/programming it. `mesh_send_start_complete:2302–2322` frees/completes the request on error without removing that instance or arming done work. This gap predates the series. The newly added removal return value is also ignored, so an HCI disable/remove failure can leave the instance present while completion proceeds.

Normal Set Powered off calls `hci_sync.c:hci_power_off_sync:6066–6102`, including hci_clear_adv_sync(false): legacy timed instances are removed; extended clear operates on the controller sets. `hci_dev_close_sync:5536–5670` cancels advertising timers and shuts down the device; index removal cancels mesh_send_done at `mgmt.c:9795`; device release eventually clears host instances at `hci_core.c:2739`. These are distinct paths, not proof that every pending mesh request receives an orderly completion.

**Exact scope wording:**

> This series fixes normal and cancellation-driven mesh-done teardown. Recovery after advertising setup/removal failure and all pending-request behavior across power transitions are not established by these tests.

Retain cleanup in the synchronous lifecycle path. Track error cleanup separately, and add failure injection before making stronger guarantees. Simply returning a teardown error is not enough by itself: the current mesh_next callback does not use that error to repair ownership.

### E5 — Duration overflow

**Verdict: confirmed for the defect; refuted for two details and the proposed “minimal correct clamp.”**

K `hci_sync.c:hci_enable_ext_advertising_sync:1672–1676` truncates milliseconds into u16 before converting to 10-ms units. Independent arithmetic:

| Requested seconds | Truncated milliseconds | Encoded duration | Controller duration |
|---:|---:|---:|---:|
| 66 | 464 | 46 | 0.46 s |
| 120 | 54464 | 5446 | 54.46 s |
| 655 | **65176** | **6517** | **65.17 s** |
| 1000 | 16960 | 1696 | 16.96 s |
| 8192 | 0 | 0 | no finite duration requested |

B `emulator/btdev.c:cmd_set_ext_adv_enable:5695–5700` starts a duration timer only when the encoded duration is nonzero. K `hci_event.c:hci_le_ext_adv_term_evt:5998–6010` removes the instance on timeout status.

This deserves its own patch/test because ordinary advertising is affected. Calculate in wider units, but preserve the existing 16-bit-seconds MGMT contract: silently capping or newly rejecting requests above 655 seconds changes behavior. A software expiry or a properly designed remainder/rearm mechanism needs its own analysis; splitting is not automatically seamless.

**Exact replacement for the candidate-fix conclusion:**

> The intermediate u16 conversion must be removed. A wider calculation fixes representable durations, but a complete fix must also preserve MGMT timeouts beyond the controller's 655.35-second duration range. Clamping alone shortens those requests and is not a complete compatibility-preserving solution.

Keep the 66-second reproducer. Add 655, 656, 1000 and 8192 boundary cases, and correct the table. Also replace “introduced with the hci_sync conversion” with “present in hci_sync since the conversion; the expression predates it in hci_request, and its original introducing commit has not yet been identified.”

### F1 — BlueZ conventions and hygiene

**Verdict: confirmed in several respects; refuted for complete style compliance.**

test_bredrle50 and tester APIs already exist at B; using them and a larger explicit timeout is conventional. No Signed-off-by is correct for BlueZ: B `HACKING:122–123` explicitly says not to add one. Independent BlueZ-configured checkpatch passes.

However, B `doc/coding-style.rst:76–89` requires multiline comments to start text on the second line. The new patch repeatedly uses kernel-style opening-line text. HACKING:135–138 prefers a 50-character title, while the retrieved .gitlint configuration permits 72; the recorded gitlint pass therefore does not establish compliance with the stricter prose guidance.

**Exact suggested title:**

> tools/mesh-tester: Test mesh advertising lifecycle

**Example comment conversion:**

```diff
-/* Extended advertising: a mesh packet is advertised through the instance
+/*
+ * Extended advertising: a mesh packet is advertised through the instance
```

Apply that form to all newly added multiline comments. Prefer a dedicated mesh sequence-data structure over expanding generic_data with many fields if maintainers request a smaller generic harness; that is a maintainability preference, not a blocker.

### F2 — Assertions and determinism

**Verdict: refuted for the claimed comprehensive/deterministic coverage.**

T `mesh_tx_cmplt_callback:1724–1763` does verify handle order and rejects excess events during its observation window. Starts/stops are checked at settle; unexpected Advertising Removed fails. Those are useful assertions.

Missing guarantees:

1. **Active-cancel precondition:** second acknowledgement does not prove A is active. Cancel-active can degenerate into normal completion, as in finding 3.
2. **Coexistence setup barrier:** T `setup_coexist_callback:1623–1637` never completes a setup condition. The setup completion is driven separately by B `setup_bthost:964–983` and `client_cmd_complete:929–961`.
3. **Ordinary advertiser continuity:** the hook ignores targeted disable of set 1 and clear-all. Enumeration does not prove radio state.
4. **Completion ordering:** aggregate totals do not prove “A stopped before B started” or correlate differing PDUs; both sends use identical send_mesh_1 bytes.
5. **Acknowledgements:** cancel success is checked if its callback runs, but is not a required completion condition. Send acknowledgement conditions likewise should be explicit.
6. **Bounded absence:** 400 ms is a useful settle window, not proof that no later event can occur. Unpatched hidden instances can remain invisible to Read Advertising Features.
7. **Failure-path bounds:** T `mesh_tx_adv_features_callback:1667–1674` detects inconsistent length, then hexdumps rp->num_instances bytes anyway. A short malformed reply can make the diagnostic overread.
8. **Registration failure:** mgmt_register may return 0 (B `src/shared/mgmt.c:964–998`). In particular, a failed Advertising Removed subscription can make the negative assertion pass without monitoring that event.

Use distinct PDUs; record enable/disable/remove order per request; gate cancellation from observed state; reject premature completion; check registration/send return values. The old generic cancel cases and new generic ext variants still have asynchronous setup timing limitations.

**Exact test requirement:**

> A cancel-active pass requires: handle A acknowledged; A's advertising start observed; handle B acknowledged and still queued; Cancel A issued before any completion of A; successful Cancel acknowledgement; A completed once; B subsequently started and completed once. A natural completion before Cancel is a failed precondition, not a pass.

Longer timeouts or larger cnt can reduce flakiness but cannot replace this state check. For deterministic race testing, hold/release an emulator command completion at a defined point and assert the kernel state transition it forces.

Small concrete corrections are supplied below; they do not alone solve the scenario-state problem.

### F3 — CI and emulator

**Verdict: confirmed that the configuration can run these cases; refuted if presented as present automatic coverage or proof of RF counts.**

At action-ci `60348956fc7bad52a64e802f3e90f90c03ba8860`, `config.json:37–86` includes mesh-tester and maps mgmt changes to it. `ci/testrunner.py:60–65` invokes the entire tester under ASAN; `action.yml` supplies KVM access. Thus added main() registrations are exercised when the tester built by the job contains this BlueZ patch. A separate, unmerged BlueZ patch does not automatically become part of a kernel submission's CI checkout.

B `emulator/btdev.c:81,5366–5385,5610–5707,5742` supports multiple extended sets, enable/disable, duration and removal. Handle 4 is a handle identifier, not a claim to four simultaneously allocated sets; the coexistence case has two sets. These are meaningful host/controller lifecycle tests.

They do not prove exact over-the-air transmission counts or interoperability with physical controllers. Current hooks count commands, not successful radio reception. Preserve this distinction in the cover.

### G1 — Stable applicability of 1/2

**Verdict: confirmed for the five pinned snapshots; cannot tell runtime behavior on those kernels.**

The original f3cb5676e5c1 subject/content is present in the named source paths, and the historical stable records inspected include [6.1 backport 9514f361fcdf](https://cos.googlesource.com/third_party/kernel/+/9514f361fcdff6e5916385aa95539911c1de2deb) and [6.6 backport 0506547f6e3d](https://cos.googlesource.com/third_party/kernel/+/0506547f6e3d2a1db4e3967975b65f46d12e331c). R identifies 6.12 backport a99f80c88a97 and ancestry in 6.18/7.2; that historical mapping is reported, not newly proven by a complete local Git ancestry walk.

I independently fetched and applied the series to these exact snapshots:

| Line | Snapshot | 1/2 apply | 2/2 cumulative apply | Helper definition in hci_sync.c |
|---|---|---|---|---:|
| 6.1.y | 1a8763b93150 | pass | pass | 2209 |
| 6.6.y | 79643295eba1 | pass | pass | 2227 |
| 6.12.y | e2acc2211022 | pass | pass | 2205 |
| 6.18.y | 1b357ecb3213 | pass | pass | 2186 |
| 7.2.y | 9a66fdc0d7fd | pass | pass | 2191 |

All five headers/definitions accept `(struct hci_dev *, struct sock *, u8, bool)`. The checked 6.1 and other source paths have the needed removal operations. This is stronger than merely applying the mgmt.c hunk, but remains no substitute for a build or runtime test.

**Change:** retain Cc: stable after resolving finding 1 and validating the revised series. Say “applies to these snapshots”; do not say “tested on 6.1–7.2.” No claim is made about every historical release in those families.

### G2 — Stable applicability of 2/2

**Verdict: confirmed for the completion logic and appropriateness in principle.**

All five inspected snapshots still complete the pending head in mesh_send_done_sync and assign a nonzero instance to the request that creates the mesh advertiser. Original b338d91703fa contains the head-completion logic. The older cancellation path still removes the cancelled request before done runs; see C2.

This is a functional loss of an uncancelled pending packet, not a cosmetic change. It is suitable for stable once the upstream fix is correct and tested, consistent with K `stable-kernel-rules.rst:7–29`. The current successful apply results do not prove scheduler/lifetime correctness, and revised ownership changes may alter the dependency analysis.

**Exact stable validation note:**

> Both patches apply cumulatively to the listed stable snapshots, and the required teardown helper signature is present. Stable kernel builds and runtime tests have not been performed. Patch 2's owner-selection logic does not require 71af682ba469 for the already-running cancellation sequence; other cancellation/lifetime fixes remain independently necessary.

### H — Remaining maintainer-facing concerns

**Verdict: refuted for send-as-is readiness.**

The cover's essential narrative is sound, but reduce overreach:

- “75 ms after each transmission” is specific to cnt=3 and observed timing, not an API guarantee. cnt is variable and scheduling/HCI latency exists.
- “On air” overstates what assigning ->instance proves in legacy coexistence.
- Valgrind's 18/18 functional cases coexist with **seven reported errors**, and the invocation uses --error-exitcode=65. Do not imply a clean valgrind run; the record distinguishes these, the compact cover should too.
- The successful no-monitor runs do not make the original generic cancel tests deterministic. R §3a records real failures under load.
- The June 2025 CI reply is more direct evidence than a sweeping statement about every subsequent red CI status. Keep broad CI-history claims out of the commit messages.
- No unsupported third-party Reported-by/Tested-by trailers are needed.

Citations: P cover; R §§3a–3f; K `mesh_send_start_complete:2319`; B `send_cmplt:225`; the original [CI reply](https://www.spinics.net/lists/linux-bluetooth/msg120821.html).

**Exact replacement for the cover's last explanatory paragraph:**

> In the recorded runs, the series disabled and removed the mesh set after the requested mesh-done interval, while the ordinary extended-advertising set remained enabled. The cnt=3 cases use a nominal 75 ms interval. The legacy coexistence case checks preservation of the ordinary advertiser only; mesh transmission during legacy rotation remains a separate limitation. The TCG/valgrind run passed all 18 functional cases but reported seven tester-side errors, also present with the unpatched kernel. The original generic cancel cases remain load-sensitive.

After fixing the scheduling/test issues, regenerate results and replace the numerical claims with the revised runs.

## Small exact tester diffs

These are review suggestions against T, **not a complete corrected patch and not runtime-tested here**. The scenario state machine and ordinary-advertiser tracking still require the larger changes specified in F2.

### Gate coexistence setup

```diff
@@ static void setup_coexist_callback(...)
 	tester_print("Ordinary advertising instance %u added", rp->instance);
+	test_setup_condition_complete(tester_get_data());
@@ static void setup_mesh_coexist(const void *test_data)
 	struct test_data *data = tester_get_data();

+	test_add_setup_condition(data);
 	setup_enable_mesh(test_data);
```

Also check the Add Advertising mgmt_send return and fail setup on zero.

### Bound the malformed-reply diagnostic

After the existing fixed-header length/status check, before printing or inspecting instance bytes:

```c
if (length != sizeof(*rp) + rp->num_instances) {
	tester_warn("Invalid Read Advertising Features length %u", length);
	tester_test_failed();
	return;
}
```

Remove the now-redundant length clause from the later combined comparison. Only hexdump instance bytes after this check.

### Require the Cancel acknowledgement

```diff
@@ static void mesh_tx_cancel_callback(...)
-	if (status != MGMT_STATUS_SUCCESS)
+	if (status != MGMT_STATUS_SUCCESS || length) {
 		tester_test_failed();
+		return;
+	}
+
+	test_condition_complete(tester_get_data());
@@ static void mesh_tx_send_callback(...)
 	tester_print("Sending Mesh Send Cancel for handle %u", cancel.handle);

+	test_add_condition(data);
 	mgmt_send(data->mgmt, MGMT_OP_MESH_SEND_CANCEL, data->mgmt_index,
```

Check mgmt_send's return value, and similarly account for every Mesh Send reply. Reject zero notification registration IDs before issuing sends.

## What remains unverified

- No new kernel/BlueZ build, sparse run, qemu run, KASAN run, or hardware test was performed in this review environment.
- The scheduling interleaving is derived from source, not yet a captured trace.
- Full raw preflight/test logs are not in the supplied repository; only their detailed quoted record was accessible.
- Codespell and independent gitlint execution were not completed.
- Search did not establish absence of all unsent/private/unindexed clients or all sent duplicates. Direct Patchwork/lore retrieval was incomplete; mirror history and opened mailing-list archives supplied the usable evidence.
- No clean bill of health is given for all pre-existing mesh lifetime, error, power-transition or legacy multiplexing behavior.

## Final disposition

**Do not send this revision.** Retain the corrected extended-advertising teardown and two-defect split, but first resolve or experimentally disprove the scheduler interleaving; repair the active-cancel/coexistence test preconditions and assertions; remove the false bluetooth-meshd claim; correct the duration note; and rerun the relevant gates on the revised series. The existing successful runs demonstrate substantial progress, but do not cover these specific remaining failure modes.

