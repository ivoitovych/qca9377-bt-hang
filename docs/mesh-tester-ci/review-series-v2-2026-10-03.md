# Private review: mesh advertising series v2

*(An outside review as received on 2026-10-03. Its links point into the project's private
repository, where branch `diag/mesh-tester-ci` then lived; the files they name are on `main`
since 2026-10-09 under the same paths.)*

Reviewed 3 October 2026. Patch author: Iaroslav Voitovych. Nothing posted, mailed, commented, committed or pushed.

**Recommendation: do not send this revision yet.** The original teardown race is addressed on the successful, live-device path, and the revised tests are substantially stronger. However, an unhandled initial queue failure breaks the new ownership invariant: the complete v2 series can subsequently schedule a request that it already rejected. The active-cancel test can still accept natural completion. The power-off argument contains a source-level error. There is also an unresolved transmission-count problem that matters directly to userspace compatibility.

These are bounded findings with specific next steps. They do not mean that the project is misguided, or that every existing Bluetooth defect must be fixed in this series.

## Evidence and execution boundaries

Source references below use these keys:

| Key | Exact source |
|---|---|
| P | [Private repository snapshot 64952dfaa68d2d0784a7a2be8fc1e1c383808aa8](https://github.com/ivoitovych/qca9377-bt-hang-private/tree/64952dfaa68d2d0784a7a2be8fc1e1c383808aa8), branch `diag/mesh-tester-ci` |
| R | P, [`docs/mesh-tester-ci/phase4-results.md`](https://github.com/ivoitovych/qca9377-bt-hang-private/blob/64952dfaa68d2d0784a7a2be8fc1e1c383808aa8/docs/mesh-tester-ci/phase4-results.md) |
| K | [Kernel 86ef0f58bdecdedb3a1240971c56d71b7e4ce3fc](https://github.com/torvalds/linux/tree/86ef0f58bdecdedb3a1240971c56d71b7e4ce3fc) |
| V | K plus the three supplied patches, identifying final commit `988f5c0f7476c2330ad2014a9780e8c092d4e6fb` |
| B | [BlueZ ae69dcddd](https://github.com/bluez/bluez/tree/ae69dcddd), the tester's stated upstream base |
| B0 | [BlueZ 8b4a41760](https://github.com/bluez/bluez/tree/8b4a41760), requested protocol-quotation reference |
| T | B plus the supplied tester patch, identifying commit `1ba13eff83fc287713efb1849b168a49b6753db4` |
| N | [bluetooth-next mirror 036d4119079a757c9d1b4d35205c7c467f0018fb](https://github.com/bluez/bluetooth-next/tree/036d4119079a757c9d1b4d35205c7c467f0018fb), observed during this review |

V and T were reconstructed from source files and patches, not fetched as complete Git commits. Their resulting Git blob hashes match the patch index hashes: V `mgmt.c` = `c4cbb5763bdeb76e6634483222a2dc9d8eebf1f8`, V `hci.h` = `a0294ff050be43a664ccb751f68e3e67ab8ebb80`, T `mesh-tester.c` = `90226bbdf0e3c3989a21649485e15557ab428c6e`. The private input blob hashes were checked against P's tree.

I read the complete three kernel patches, cover, tester patch, duration note, phase-4 results, phase-4 task, previous review and previous series review task. I retrieved the kernel's top-level `net/bluetooth/*.c` files, relevant headers, BlueZ tester/emulator/client code, submission documentation, named upstream changes and five stable source snapshots. I did not independently re-audit every earlier project issue or every driver beneath `drivers/bluetooth`.

**Executed independently:** patch application; kernel strict checkpatch with a real codespell dictionary; BlueZ-configured checkpatch; cumulative no-fuzz stable application; exhaustive duration arithmetic over all positive u16 timeouts; and an extracted-function C fault harness, with a cleanup control variant. The harness uses the unchanged V bodies of `mesh_send()`, `mesh_next()`, `mesh_send_done_sync()` and `mesh_send_complete()`, with explicitly stubbed surroundings.

**Not executed here:** a full kernel or BlueZ build, W=1 kernel build, sparse, gitlint executable, QEMU, KVM, real hardware, radio capture or stable-kernel boot. QEMU and `/dev/kvm` were unavailable in this environment. The private tree does not contain the full `run-p4-*.log`, `preflight-v2-*.log` or kernel-build logs: R supplies quoted extracts, not independently inspectable raw runs. Its quoted 25/25, 501/501 and other runtime results remain the author's recorded evidence.

**Inferred** identifies a conclusion from source or a described interleaving, not a reproduced kernel failure. A successful stub harness is identified separately and is not presented as a kernel reproduction.

## Findings requiring action

### 1. Initial enqueue failure invalidates the ownership invariant

**Confirmed in source and in the extracted-function harness; kernel reproduction outstanding.** V `mgmt.c:mesh_send:2596–2617`, `mesh_send_done_sync:1139–1154`, `mesh_next:1105–1117`; K `mgmt_util.c:mgmt_mesh_add:408–430`, `mgmt_mesh_remove:433–438`; K `hci_sync.c:hci_cmd_sync_submit:714–745`.

The initial `hci_cmd_sync_queue()` is attempted only when `sending == false`. If allocation of its work entry fails, `mesh_tx` is already on `mesh_pending`, but the error cleanup removes it only when `sending == true`. Consequently it survives the Failed reply, and the flag remains clear. This directly contradicts the new comment that a clear flag implies no pending requests.

With the full series, the consequence is more than an inaccurate comment:

| Step | Pending requests | Action |
|---|---|---|
| Submit A; fail allocation of its start work | A | Failed reply; flag clear; no queued start |
| Submit B; queue allocation succeeds | A, B | B is acknowledged and started despite older A |
| B's done work executes | A, B → A | Patch 3 correctly identifies and completes B |
| `mesh_next()` runs | A | The previously rejected A is queued for transmission |

The harness produced:

```text
v2
status=5
after rejected A: pending=1 flag=0
reply handle=2
start handle=2
complete handle=2
CONFIRMED IN STUB HARNESS: rejected A is scheduled after successful B
start handle=1
complete handle=1
cleanup
status=5
after rejected A: pending=0 flag=0
reply handle=2
start handle=2
complete handle=2
PASS: cleanup prevents rejected A from being scheduled
```

`status=5` is the harness's symbolic Failed value, not a captured MGMT wire status. The successful control changes only the erroneous cleanup condition. ASAN and UBSAN were enabled; LeakSanitizer had to be disabled because the environment blocks its process inspection. No kernel locking, allocator, controller or workqueue was emulated faithfully by this harness.

The underlying cleanup bug is pre-existing. **Inferred difference:** the old head-completion logic would remove rejected A at B's first completion and could start B again; V's owner completion instead leaves rejected A eligible to start. Neither behavior is acceptable. Calling the cleanup bug pre-existing does not make it a valid assumption for V's proof.

Required effective change, preferably as a prerequisite coordinated with the already published cleanup patch rather than a duplicate submission:

```diff
@@ static int mesh_send(...)
-		if (mesh_tx) {
-			if (sending)
-				mgmt_mesh_remove(mesh_tx);
-		}
+		if (mesh_tx)
+			mgmt_mesh_remove(mesh_tx);
```

A [19 September public patch](https://lkml.iu.edu/2609.2/10074.html) already proposes this cleanup. Its acceptance status was not established; the erroneous condition remains in K and the retrieved N mesh code. Do not silently import another author's patch under a new sole-author attribution. Refer to or arrange the dependency with its existing provenance.

### 2. HCI command lifecycle is not transmission-count correctness

**Confirmed mismatch in source; actual packet counts and hardware consequences are inferred and unmeasured.** K `hci_core.c:hci_alloc_dev_priv:2450–2451`; V `mgmt.c:mesh_send_sync:2386–2394`, `mesh_send_start_complete:2369–2371`; K `hci_sync.c:hci_setup_ext_adv_instance_sync:1450–1458`, `hci_enable_ext_advertising_sync:1649–1670`; B `emulator/btdev.c:cmd_set_ext_adv_params:5404–5423`, `cmd_set_ext_adv_enable:5684–5699`; B0 `doc/mgmt-protocol.rst:4107–4116`.

The ordinary default advertising interval is `0x0800 × 0.625 ms = 1280 ms`. Mesh passes those intervals into its advertising instance. Its completion timer independently uses `Count × 25 ms`: 75 ms for the test's Count=3. The extended-enable command does not use Count as the controller's maximum advertising-event count; that field remains zero.

The extended emulator broadcasts once immediately on enable and schedules subsequent broadcasts at the configured interval. **Inferred:** with the default interval and prompt successful teardown, a 75-ms lifetime permits the initial broadcast but ends before the next 1280-ms broadcast, let alone a third. The new tester records one HCI enable as a start; it neither counts these broadcasts nor requires reception by a second controller.

The 25-ms calculation predates V. However, patch 2 makes its deadline actually stop advertising, so it can expose that existing mismatch as reduced retransmission. This is precisely the sort of interaction relevant to the user's compatibility concern. It is not enough to show that Disable arrived when the old timer expired.

Required next evidence: a receiver-enabled extended-emulator test with duplicate filtering disabled and distinct PDUs, for Count=1 and Count=3 at both default and explicitly configured intervals. Record enable/disable timestamps and receiver observations. Decide whether correcting the interval/count relationship is a prerequisite or a separately justified limitation. Do not claim full restoration of the Count contract before that decision. Legacy emulator behavior is different—it reports on enable rather than modeling periodic radio events—and cannot establish radio count.

Exact interim wording for the cover and results:

> The tests verify command ordering, ownership and teardown at the existing Count × 25 ms host deadline. They do not establish the requested number of advertising events or receiver delivery. The relationship between that deadline and the configured advertising interval requires separate validation.

### 3. Active-cancel still has a false-positive execution

**Refuted: not every passing case proves its named scenario. Inferred interleaving, not a new VM run.** T `tools/mesh-tester.c:mesh_tx_cancel_active:1621–1630`, `mesh_tx_two_completions:1667–1674`, `mesh_tx_check_cancel:2016–2048`, `mesh_tx_cmplt_callback:1888–1959`, `mesh_tx_cancel_callback:1994–2010`.

The gate establishes that A was observed started, B acknowledged and not observed started, and no completion observed when Cancel is issued. It then sets `mesh_tx_cancel_sent`. Once that boolean is set, the test no longer rejects B starting before Cancel takes effect. A can finish naturally before the kernel processes Cancel; cancelling an absent handle still succeeds. A natural A-then-B sequence has exactly the same completion order, start order and teardown count as this active-cancel case. `mesh_tx_cancel_acked` is recorded but is not a causal assertion about A's cancellation.

A delayed tester/socket dispatch can therefore produce a pass without active cancellation. The queued-cancel and cancel-all expectations distinguish more failure cases, but do not rescue this case.

Exact replacement test requirement:

> Force Cancel(A) to be queued before A's completion timer can run. One possible control is to hold A's initial enable response, acknowledge B, enqueue Cancel(A), prove that enqueue with an appropriate kernel trace or an independently verified MGMT dispatch barrier, and only then release A's enable response. Assert A's cancellation, B's single subsequent start, and one completion per acknowledged handle. Do not equate setting a userspace “sent” boolean with kernel cancellation.

This is a test-design specification, not an untested drop-in patch. In particular, a barrier must not sit behind a serialized MGMT client's outstanding Cancel reply and deadlock the hold. The chosen client API and barrier must be validated.

### 4. Power-off does not imply the cited immediate `-ENETDOWN`

**Refuted for that exact claim.** K `hci_sync.c:hci_cmd_sync_work:305–345`, `hci_req_sync_run:113–145`, `__hci_cmd_sync_sk:156–217`, `hci_cmd_sync_queue:751–761`, `hci_dev_close_sync:5536–5683`; V `mgmt.c:mesh_send_sync:2374–2425`.

Ordinary close does not clear the queued sync-work list, and the worker only stops draining it for `HCI_UNREGISTER`. Those parts of A1.3 are correct. But an already accepted start invokes the internal `__hci_cmd_sync_*` path. That path does not check HCI_RUNNING/HCI_UP and return `-ENETDOWN`; the guard in `hci_cmd_sync_queue()` checks new enqueues, not execution of previously accepted entries. The public `hci_cmd_sync()` guard also is not the function used here.

A queued start can reach other errors or command timeout; the claimed prompt failure/drain is not proved. This does not itself prove a newly introduced shutdown regression, but it invalidates the proposed source argument.

Exact replacement for the review-task/results explanation:

> Power-off does not dequeue already accepted mesh starts through hci_cmd_sync_clear(). The worker may execute them after close. Their internal synchronous HCI path has no general down-device guard guaranteeing -ENETDOWN. The resulting timeout/error and scheduler recovery behavior has not been established by the recorded tests.

### 5. The corrected duration note still misses zero after division

**Confirmed table arithmetic; incomplete zero-duration characterization.** K `hci_sync.c:hci_enable_ext_advertising_sync:1666–1670`; P `docs/mesh-tester-ci/duration-overflow-note-v2.md`.

For positive u16 timeouts, the encoded field is `((timeout * 1000) % 65536) // 10`. Because the remainder is a multiple of 8, both remainder 0 **and remainder 8** encode zero. An exhaustive calculation found 15 positive inputs, not just the seven positive multiples of 8192:

```text
6357, 8192, 14549, 16384, 22741, 24576, 30933, 32768,
39125, 40960, 47317, 49152, 55509, 57344, 63701
```

All listed v2 table values are correct. Add this row:

| requested seconds | milliseconds | modulo 65536 | encoded Duration | meaning |
|---|---|---|---|---|
| 6357 | 6,357,000 | 8 | 0 | no finite controller duration |

Exact replacement paragraph:

> For a positive u16 timeout, Duration is zero when timeout is congruent to either 0 or 6357 modulo 8192. These cases leave no finite controller duration when Max_Extended_Advertising_Events is also zero. No independent extended-advertising expiry is armed by hci_schedule_adv_instance_sync(); an explicit disable/removal, mesh-done work or another lifecycle action may nevertheless end the set.

The clamp conclusion is correct. The original introducing commit remains unidentified in the evidence reviewed. A future host-timer implementation could legitimately encode Duration=0, so the proposed 8192-s test must validate expiry through a controllable clock or other behavioral oracle, not prohibit zero Duration bytes. A four-second negative observation cannot prove an 8192-second expiry.

## Requested item-by-item verdicts

### A1.1 — Every flag path and scheduler ownership

**Verdict: refuted as an unconditional invariant; confirmed for the original successful-path teardown interleaving.** Citations: V `mgmt.c:mesh_next:1105–1117`, `mesh_send_done_sync:1120–1157`, `mesh_send_done:1159–1168`, `mesh_send_start_complete:2342–2372`, `send_cancel:2465–2511`, `mesh_send:2554–2626`; K `mgmt.c:mgmt_cleanup:10913–10930` and `mgmt_util.c:378–438`.

At V, the explicit flag setter is the successful `mesh_send()` path; the explicit clearer is `mesh_next()`; `mesh_send_done()` reads it without the mutex as an atomic work guard. That unlocked read does not select a new owner. On the live, intact-list path, done/error/cancel handover is serialized against `mesh_send()`, and the old clear-before-teardown window is closed.

| Requested property | Assessment |
|---|---|
| (a) Same request started twice | No duplicate-start path found within the corrected normal protocol. Socket lifetime races prevent a universal safety proof. |
| (b) Later request starts before an earlier pending request | Counterexample in finding 1: an initial failed enqueue leaves older A pending, and B starts first. |
| (c) Flag set with no queued/running/on-air owner | Still possible after done-work enqueue failure; socket cleanup can remove pending requests without repairing ownership. Unregister may leave the flag set on a dying device. These are not all new defects. |
| (d) Flag cleared while an owner remains | Not found on successful paths. A failed start/removal can leave controller state behind while the software scheduler goes idle; successful scheduling invariants do not prove controller cleanup. |

The new loop improves draining when later queue attempts fail. It does not repair initial enqueue failure. R's “Open 3” is therefore not a complete list of exceptions needed by the proof. Apply finding 1 and state the live-device/error assumptions explicitly. After that fix, adding `lockdep_assert_held(&hdev->lock);` inside `mesh_next()` is a useful executable statement of its caller contract.

### A1.2 — Lock order and what lockdep covered

**Verdict: confirmed for the inspected mesh call chains; cannot tell from the recorded runs that the risky dequeue branch was exercised.** K `hci_sync.c:hci_cmd_sync_work:319–340`, `_hci_cmd_sync_cancel_entry:650–659`, `hci_cmd_sync_clear:661–674`, `hci_cmd_sync_dequeue:880–894`; V `mgmt.c:send_cancel:2465–2508`, `mesh_send_start_complete:2352–2366`; R §3h.

Normal work and its destroy callback execute after `cmd_sync_work_lock` is released, under `req_lock`. The mesh `-ECANCELED` callback does not acquire `hdev->lock`, avoiding the obvious reverse acquisition during dequeue/clear. `mesh_next()` queues after `hci_cmd_sync_dequeue()` releases its mutex. I found no reversed acquisition introduced by this mesh change in those chains. This is not an exhaustive deadlock proof over every exported API, transport driver and unrelated callback.

The gated “cancel queued” case cancels B while A has already started. B is then on `mesh_pending`, but its `mesh_send_sync` entry has not yet been queued; `hci_cmd_sync_dequeue()` should return false in that scenario. Therefore R's assertion that these runs included successful dequeue of a queued start is not established by the named case. The generic legacy tests might reach it incidentally, but no branch evidence is supplied.

Exact record correction:

> No lockdep report was recorded in these runs. Successful dequeue of a queued mesh_send_sync entry, the -ECANCELED callback under cmd_sync_work_lock, and unregister with such an entry require explicit branch evidence or dedicated tests.

A focused missing case can hold A's teardown, enqueue Cancel(B) while B is pending, then release teardown: `mesh_next()` queues B's start behind the already queued cancel work. Prove the order and successful dequeue in the trace; add a later accepted request to verify handover.

### A1.3 — Cancellation, unregister and power transitions

**Verdict: partly confirmed; refuted for guaranteed `-ENETDOWN`.** Citations: finding 4; K `hci_core.c:hci_unregister_dev:2666–2703`, `hci_core.h:hci_dev_clear_volatile_flags:861–869`, `mgmt.c:__mgmt_power_off:9821 onward`.

`HCI_MESH_SENDING` is not a volatile flag. `__mgmt_power_off()` handles `mgmt_pending`, not `mesh_pending`. The inspected top-level Bluetooth callers select mesh starts for dequeue in `send_cancel()` or clear the backlog at unregister. The other inspected pointer-matching dequeues target connection or MGMT-command objects. The generic exported cancellation APIs could be used elsewhere; I did not prove absence across all external modules.

Leaving the flag set on an unregistered, dying hdev is not evidence of a reusable controller becoming stuck. By contrast, power-off/reopen is reusable state and needs its own test. The cover's limited testing disclaimer is appropriate; it must not be used to turn the incorrect down-device explanation into a proof that V is harmless across power transitions. Correct the explanation as in finding 4 and test queued, active and teardown-held power-off/reopen separately.

### A1.4 — Loop termination and socket close

**Verdict: confirmed termination for a valid, exclusively manipulated finite list; refuted if interpreted as lifetime safety.** V `mgmt.c:mesh_next:1105–1117`; K `mgmt_util.c:mgmt_mesh_next:378–390`, `mgmt_mesh_remove:433–438`; K `mgmt.c:mgmt_cleanup:10913–10930`, `hci_sock.c:hci_sock_release:910 onward`.

Each failed enqueue removes the selected element; successful enqueue returns; an empty list clears the flag. New normal submissions cannot extend the loop while its mutex is held. Socket close does not honor that mutex, so it can free an element that the loop or queued work still holds. This race predates V. The new drain loop can visit more entries in one error episode, increasing the work exposed to an unsynchronized closer; no quantified increase or new race reproduction was established.

Do not fix this by merely inserting a sleeping hdev mutex inside `mgmt_cleanup()`'s existing `hci_dev_list_lock` read-side critical section. Device iteration, list exclusion and work-item lifetime need a coordinated design. The published locking/lifetime series in C is relevant, but is not automatically a drop-in prerequisite. Keep this as an explicit residual risk and perform a differential close-race test before claiming non-regression.

### A2 — Daemon claims and protocol quotations

**Verdict: confirmed.** P patch 3 message; B0 `doc/mgmt-protocol.rst:4136–4137,5476–5477`; B `mesh/mesh-io-mgmt.c:send_cmplt:225–229`.

The two quotations match the protocol text after normalizing line wrapping. Patch 3 no longer claims that bluetooth-meshd matches completion handles. The event describes release of a transmit slot, not receiver delivery; the cancellation text explicitly allows unsuccessful transmission. No further change to those quotations is required.

### A3 — Revised tester assertions

**Verdict: confirmed for most repairs; refuted for complete scenario proof.** T `tools/mesh-tester.c:setup_mesh_coexist:1758–1773`, `mesh_tx_adv_features_callback:1775–1812`, `mesh_tx_hci_callback:2152–2244`, `mesh_tx_hold_hook:2256–2292`, `test_mesh_tx:2294–2341`, `test_post_teardown:122–142`; B `emulator/btdev.c:process_cmd:8720–8758`.

The new lifecycle code checks its registration/send returns, bounds the variable reply before inspecting it, uses distinct PDUs, gates coexistence setup on Add Advertising, and walks every extended-enable set entry. It detects targeted disable of ordinary set 1, disable-all, removal of set 1, clear-all, and legacy disable. The first teardown is withheld before processing and replayed only after request 2's reply. The hold therefore controls the relevant interleaving; it is not merely a sleep-based probability test. It remains bounded by the kernel command timeout and is not immune to arbitrary VM starvation.

The active-cancel false-positive remains (finding 3). Ordinary-set preservation is a command-level observation during a finite window, not proof of received advertisements. The hook counts command requests, not every controller success status. Existing setup helpers still contain unchecked sends; R should say the *new lifecycle operations* are checked, not every return in the entire tester. The 400-ms settle interval cannot exclude events at arbitrary later times.

BlueZ comment form and the 50-character subject are correct. Keep the hold and the repaired bounds/return checks; add causal cancellation and queue-dequeue evidence.

### A4 — Duration note

**Verdict: confirmed for the requested table corrections and rejection of clamping alone; refuted as a complete zero-duration analysis.** See finding 5 and its exact replacement. The “nothing else ends it” wording must be scoped to absence of an independent expiry timer, not all lifecycle actions. Provenance before the hci_sync conversion remains unverified here.

### B — Userspace compatibility and “don't break userland”

**Verdict: confirmed unchanged command/reply layout and immediate-acceptance structure; cannot tell that every real workload is compatible.** V `mgmt.c:mesh_send:2554–2626`; B `mesh/mesh-io-mgmt.c:send_queued:505–519`, `send_pkt:522–552`, `tx_to:555–611`; B0 `doc/mgmt-protocol.rst:4075–4143,5469–5480`; K `mgmt.c:add_advertising:9025`, `add_ext_adv_params:9217`, `read_adv_features:8768–8823`.

B1: the inspected mesh daemon ignores the completion event, retains the Send response's handle for cancellation, requests Count=1 and schedules its own retransmissions. No explicit workaround for duplicate starts or completing the wrong queue head was found. That does not establish that real deployments never benefit accidentally from the old extra airtime.

B2: public searches for the MGMT identifier, command name and workaround combinations did not establish an independent non-BlueZ application workaround. They do not cover private clients, unindexed forks or code using numeric opcodes. Testing “all userland in existence” is neither feasible nor what a credible compatibility statement should claim.

B3: ordinary instance creation is bounded by `le_num_of_adv_sets`; mesh uses the reserved value above it. Suppressing removal events for that internal namespace is coherent. Testing `adv->mesh` inside the event helper is not a trivial replacement: some callers have already removed the object. The existing `read_adv_features()` implementation has its own sparse-ID filtering weakness—it uses instance count in its filter—so do not generalize its behavior into proof that enumeration is perfect. No new defect in the event guard was found for the inspected namespace.

B4: Send still replies from its syscall-side acceptance path with one handle byte, before HCI completion. V does not intentionally defer the reply until radio transmission. Literal timing is not identical: mutex contention and removal of the old illegal parallel enqueue can change latency. For an arrival during teardown, ordered later start is expected serialization, not a change to reply format. Finding 1 nevertheless gives an error-path behavior that must be fixed, and finding 2 leaves an observable airtime/count question.

The kernel's [regression policy](https://docs.kernel.org/process/handling-regressions.html) concerns working workloads, including reliance on behavior developers may regard as defective. Documentation supports the intended semantics but is not a substitute for investigating a reported regression. The appropriate argument is bounded: unchanged ABI, identified clients, restored ownership, preserved unrelated advertising, measured timing/delivery, and an explicit rollback response to new regressions.

Exact compatibility statement:

> No dependency on the old queue-head completion behavior was found in the inspected BlueZ client. Public searches did not establish a non-BlueZ workaround. Compatibility with private clients and dependence on accidental extra airtime remain unestablished; the tests currently validate HCI lifecycle rather than requested radio-event count.

### C — Duplicates, prior art and current history

**Verdict: confirmed relevant prior art; cannot tell that no sent duplicate exists.** The named [`71af682ba469`](https://github.com/torvalds/linux/commit/71af682ba4692c2ed9ace4c3d4ca462ae368c029) removes queued work before freeing its request and advances after cancel/errors. [`3c742feda8fc`](https://github.com/torvalds/linux/commit/3c742feda8fcabf741a17bcf668b63c8f606f9c5) releases the cancel command through a destroy callback. V retains those purposes and the latter's cleanup; it changes the scheduler ownership mechanism rather than undoing either fix.

Additional public proposals requiring reconciliation:

| Public source | Relevance; limit |
|---|---|
| [7 August locking proposal, revision 2](https://lists.openwall.net/linux-kernel/2026/08/07/798) | Overlaps worker-side mesh list locking and discusses the canceled-callback lock-order problem. A proposal, not proof of current merged behavior. |
| [7 August request-reference proposal, revision 2](https://lists.openwall.net/linux-kernel/2026/08/07/800) | Addresses raw request-pointer lifetime. It explicitly allows a canceled queued send to execute, so it must not be adopted blindly as equivalent to the later dequeue semantics. |
| [19 September initial enqueue cleanup](https://lkml.iu.edu/2609.2/10074.html) | Directly relevant to finding 1's missing prerequisite. The author's record says inspection/compile testing, not a successful fault-injection reproduction. |

The [25 June 2025 original regression patch](https://www.spinics.net/lists/linux-bluetooth/msg120817.html) sought to preserve other LE advertising. Its [CI response](https://www.spinics.net/lists/linux-bluetooth/msg120821.html) already reports the two mesh cancel timeouts. That is a concrete historical signal; it does not explain why each reviewer or maintainer acted as they did.

The retrieved mirror's commits dated since 2 October contain driver/RFCOMM changes and a merge, not a mesh ownership fix. The merge's Bluetooth-side parent is `08e90633377f1b2567ab5ad6810b74c552246a07`; its dated history was inspected too. N's mesh code still lacks this series and retains the initial-enqueue cleanup error. Direct kernel.org log, lore query and Patchwork API retrieval were unsuccessful; Patchwork search was robots-blocked. Mirror history plus indexed archives is incomplete evidence for outstanding submissions. Record that limitation and perform a final upstream refresh at send time.

### D — Kernel rules, lint, messages and patch split

**Verdict: confirmed static style and stable-tag syntax; cannot independently confirm the recorded kernel builds/sparse runs.** K `Documentation/process/stable-kernel-rules.rst:85–120`, `Documentation/process/submitting-patches.rst`; P three kernel patches; R §4a–4f.

Independent final checkpatch results:

```text
1/3: 0 errors, 0 warnings, 0 checks, 168 lines checked
2/3: 0 errors, 0 warnings, 0 checks, 31 lines checked
3/3: 0 errors, 0 warnings, 0 checks, 19 lines checked
```

Command: `perl scripts/checkpatch.pl --no-tree --strict --codespell --codespellfile ../dictionary.txt --ignore UNKNOWN_COMMIT_ID <patches>` from the local kernel source directory. The dictionary was fetched from codespell's actual dictionary blob `c96eede3ce47aad7fd0e13df67f102433d8fe824`. Local history was incomplete, hence the explicit unknown-ID exception; the named Fixes hashes/titles were separately checked against upstream commit records. Earlier attempts without a usable dictionary/repository context were not counted as successful verification.

Prefixes, imperative subjects, Fixes trailers and kernel signoffs are appropriate. Unfolded kernel subjects fit the normal title guidance. The prerequisite Cc line followed by a version Cc line is exactly the documented form. Patches within the same stable-tagged series need not list each other; duplicating `71af682ba469` on 2/3 and 3/3 is not required. Adding the missing cleanup dependency changes the prerequisite plan and must be reflected before sending.

Keeping scheduler ownership before teardown is necessary for safe intermediate commits. Owner matching remains independently understandable. The initial-enqueue cleanup belongs before the ownership proof, preferably using the existing proposal. Long comments are not a correctness violation; shorten repeated prose after the protocol is correct, and retain the lock/ownership reason.

R quotes W=1 with `-Werror` and no new sparse findings for each kernel patch. I read those quotations, not the underlying logs or a newly reproduced build. Checkpatch passing is not a concurrency or compatibility verdict.

### E — Architecture, intent and historical explanation

**Verdict: confirmed suitability of the existing removal layer; inferred preference for a small protocol repair; cannot tell what a maintainer will prefer.** K `hci_sync.c:hci_remove_advertising_sync:2201–2242`, `hci_remove_adv_sync:2167–2188`, `hci_remove_ext_adv_instance_sync:2030–2049`; K `hci_event.c:hci_cc_le_remove_adv_set:1479–1506`; V `mgmt.c:mesh_send_done_sync:1120–1157`.

E1–E2: the common removal helper is preferable to deleting host bookkeeping before controller removal. `force=true` removes the finite internal instance without waiting for its artificial remaining lifetime. `sk=NULL` is appropriate for internally driven cleanup rather than a user Remove Advertising command. Extended removal targets the set; legacy removal can reschedule an ordinary instance. The function's powered/global-advertising guards and return errors matter; none proves controller cleanup after an ignored failure.

E3–E4: moving removal into every `mesh_send_complete()` would be wrong: completing a queued request must not tear down the active owner's instance, and the completion helper also runs in contexts unsuitable for synchronous controller commands. Keep teardown at the owner boundary. Legacy coexistence, setup/removal failure, socket close and power transitions need explicit handling or limitations. The claim that a failed-removal instance “is reused by the next one” is too strong: capacity checks or another failure can prevent reuse.

Exact replacement for that part of patch 2's comment:

```c
/* Account for the request even if teardown fails. Recovery of a
 * residual advertising instance is not handled here.
 */
```

E5: keep the duration overflow as a separate change with a solution for the full u16-second contract. Correct its note as in A4. Also distinguish that overflow from finding 2's Count/deadline mismatch; they are different defects.

The existing command worker serializes command functions; it does not by itself own the entire transmission interval after a start function returns. Replacing the flag with one work item per transmission would require a design for the interval, cancellation, controller events and object lifetime. Holding the worker asleep for the whole interval would also delay unrelated management commands. **Inferred recommendation:** fix the current invariant and lifetime boundaries first, rather than adding a scheduler redesign to a stable fix.

There is local precedent for locking flags and their associated state together: K `mgmt.c:discov_off:1063–1076` changes discovery state/flags under `hdev->lock`; K `hci_sync.c:create_le_conn_complete:7307 onward` avoids taking that lock on canceled destruction. Scheduling MGMT requests in `mgmt.c` while using controller primitives in `hci_sync.c` is consistent with their responsibilities. Moving mesh handover into `hci_sync.c` is not required by a rule I found.

The original [mesh implementation](https://github.com/torvalds/linux/commit/b338d91703fae6f6afd67f3f75caa3b8f36ddef3) describes queued outbound packets, handles, cancellation and completion events. Subsequent source contains incomplete connections between that design and advertising scheduling—for example, the `adv->mesh` timing comment is not backed by a corresponding scheduling-unit branch in the inspected code. That supports investigation of incomplete implementation. It does **not** establish that a maintainer disappeared, lacked competence or intentionally ignored a defect. I found no evidence supporting such a personal explanation.

### F — BlueZ integration and emulator validity

**Verdict: confirmed required hook code is built into mesh-tester; refuted if the result is presented as full radio or cancellation coverage.** B `Makefile.tools:tools_mesh_tester_SOURCES:135–141`, `emulator/btdev.c:process_cmd:8720–8758`, `emulator/hciemu.c:receive_btdev:209–237`; T functions cited in A3; B `HACKING:Submitting patches`, `doc/coding-style.rst:M2`, `doc/tester.config`.

The tester links the needed btdev/hciemu code; the hold is not dependent on the standalone btvirt server. Re-injecting H4 uses an existing emulator entry point, and deleting the hook during teardown is sensible. ASAN/KVM do not inherently remove that capability. This establishes build-source availability, not successful execution in every live CI environment.

Independent BlueZ-configured checkpatch: **0 errors, 0 warnings, 1078 lines checked**, with codespell. The subject is 50 characters. A full gitlint executable run was not performed here. BlueZ explicitly forbids Signed-off-by trailers; the actual tester patch correctly omits one. R's sentence that every patch, “kernel and BlueZ,” carries Signed-off-by is false. Replace it with:

> The kernel patches carry Iaroslav Voitovych's Signed-off-by. The BlueZ patch identifies the same author in its From header and omits Signed-off-by, as BlueZ requires.

F2/F3 limitations: see findings 2–3 and A1.2. The new gate observes HCI commands, not all successful controller state changes or radio reception. A separate receiver and fault-injection layer is needed.

### G — Stable application and meaning

**Verdict: confirmed no-fuzz source application after the prerequisite at the five recorded snapshots; cannot tell runtime safety on those kernels.** Independent application used `patch --batch --fuzz=0 -p1`: first the upstream `71af682ba469` diff, then the three kernel patches. This was neither `git cherry-pick` nor `git am`, and no stable image was built or run.

| Stable line | Recorded commit tested | Application | `hci_remove_advertising_sync()` line |
|---|---|---|---|
| 7.2.y | `9a66fdc0d7fd` | all four diffs apply, offsets only | 2191 |
| 6.18.y | `1b357ecb3213` | all four diffs apply, offsets only | 2186 |
| 6.12.y | `e2acc2211022` | all four diffs apply, offsets only | 2205 |
| 6.6.y | `79643295eba1` | all four diffs apply, offsets only | 2227 |
| 6.1.y | `1a8763b93150` | all four diffs apply, offsets only | 2209 |

Sources: corresponding [`gregkh/linux`](https://github.com/gregkh/linux) commit snapshots, `net/bluetooth/mgmt.c`, `net/bluetooth/hci_sync.c`, `include/net/bluetooth/hci.h`. These are the recorded snapshots, not a claim that those branches have not advanced.

All five inspected helper signatures take `(struct hci_dev *, struct sock *, u8, bool)`. Their removal/legacy rescheduling structure and the cancel-destroy structure support the proposed use; after `71af682ba469`, `send_cancel()` has the expected dequeue form. This is stronger than a hunk-only observation, but is still a focused source check rather than a complete stable semantic audit. The initial cleanup error also remains relevant on these snapshots.

The documented prerequisite mechanism is reasonable. A separate stable request is an operational option if needed after upstream acceptance, not something that must be sent now. Include all actual dependencies in the final plan and exercise at least the oldest materially different stable baseline plus the intended distribution baseline. Clean text application alone is insufficient to claim stable validation.

### H — Cover, evidence claims and remaining presentation

**Verdict: confirmed most numerical transcription; changes required to the surrounding claims.** P cover; R §§3a–3i,4f,Summary,Open.

| Cover claim | What the record supports |
|---|---|
| 10/25 unpatched; 25/25 patched | R §§3d,3h; final tester used in §3h |
| 5/20 unpatched; 20/20 patched under TCG/valgrind | R §§3f,3g; unpatched comparison used the earlier tester with two subsequently repaired hook leaks |
| 60/60 repeated cancellation/hold cases | 5×10 cancel plus 5×2 hold in §3i |
| 501/501 mgmt-tester | R §3e |
| seven tester-side valgrind errors | R §3g; not a clean valgrind run |
| Count=3 nominal 75 ms | Existing host timer, not proof of three advertising events |
| two starts of B without prerequisite | Recorded phase-3 series hold trace in §3a, not a literal application of patches 2/3 and 3/3 alone onto K |

Keep “no stable kernel was built or run” in the cover because it directly qualifies its stable claim. Replace “With only the tear-down applied (patches 2 and 3 without patch 1)” with:

> On the previous two-patch teardown/owner-matching revision, the hold test observed the second request started twice. The v2 ownership prerequisite prevents that interleaving in the recorded runs.

Do not describe the entire path as ending after its requested Count until finding 2 is settled. Add the precise testing-scope statement above. Correct the Signed-off-by record and successful-dequeue coverage claim. “Microseconds” is a plausible scale, not a measured upper bound; use “the interval between clearing the flag and handover” unless a measurement is supplied.

The cover is long but understandable. Correctness, dependent fixes and evidence qualifications matter more than aggressively shortening it. Preserve only genuine author/test/review trailers; do not invent Tested-by or Reviewed-by credit. Public-source citations in this private review are evidence, not additions to the patches' authorship.

## Risk map and the tests that would reduce each risk

Severity here describes possible impact, not a measured probability. “Pre-existing” does not imply irrelevant; the key question is whether the revised code depends on, exposes or worsens it.

| Failure class | Affected workload | Impact and evidence | Most useful next test |
|---|---|---|---|
| Rejected request later transmitted | MGMT mesh clients retrying after allocation failure | Incorrect protocol action; source + stub-harness confirmation | Fail the first sync-work allocation after mesh request allocation; retry; assert no start/event for the rejected request |
| Wrong start/completion owner | Multi-request mesh send/cancel | Packet loss, duplicates, queue starvation; original race recorded, normal v2 path improved | Existing hold case plus deterministic active cancel and successful queued-start dequeue |
| Deadline shorter than advertising interval | Mesh retransmissions and receivers relying on Count | Reduced redundancy/delivery; source mismatch, RF outcome unmeasured | Receiver-based Count=1/3 tests with default/configured intervals; later real-controller capture |
| Ordinary advertiser interrupted | BLE peripherals/beacons sharing an adapter with mesh | Lost discoverability or beaconing; command-level coexistence tests present | Keep receiver observing ordinary set while mesh starts/cancels; cover sparse IDs and multiple sets |
| Socket close during queued/running work | Daemon exit, restart, crash; multiple MGMT clients | Pre-existing raw-pointer/list lifetime hazards; potential kernel fault and controller-wide blockage | Controlled close at enqueue, setup, teardown and handover with KASAN/KCSAN and lockdep; compare K and V |
| Power-off/unregister | Adapter power cycling, suspend-related transitions, unplug | Stale scheduler, delayed recovery, teardown hangs; not established by present record | Held-command power-off/reopen and unregister, with a subsequent Send and bounded completion |
| HCI setup/remove error or timeout | Controllers that reject or lose commands | Residual advertising instance, stuck capacity, delayed other MGMT work | Inject failures at setup, enable, disable, remove; verify next request and ordinary advertising |
| Stable semantic differences | Older deployed kernels | Backport builds/runs differ despite clean application | Exact dependency sequence, W=1 build and targeted VM runs on selected stable baselines |

The directly changed surface is mesh management and advertising bookkeeping; ordinary audio, keyboards and networking are not directly rewritten. **Inferred worst-case secondary impact:** a Bluetooth memory-safety bug or deadlock can affect other uses of the same controller, and a kernel fault can destabilize the host. There is no evidence here of firmware flashing, persistent hardware damage or direct disk corruption. A host crash can still lose unsaved work. This is a reason for isolated VM fault testing, not a claim that these patches will damage hardware.

## Proposed submission gate

1. Resolve the initial-enqueue cleanup dependency and run the failing-allocation case on a real guest kernel. Require the request to be absent from Read Mesh Features after the Failed reply, and require later accepted traffic to progress without transmitting it.
2. Add causal active-cancel and actual queued-start-dequeue tests. Require branch evidence, one completion per accepted handle, and continued progress of the next request. Test two sockets so ownership/cancel scoping is exercised.
3. Investigate the Count/deadline mismatch with a receiver-enabled emulator. Resolve the dependency/scope decision before asserting userspace compatibility. Neither 25/25 command tests nor a preserved ABI settles airtime behavior.
4. Correct the power-off explanation; run queued-start, active-owner and held-teardown power-off/reopen, and unregister-with-backlog. Require bounded completion and a working subsequent Send after reopen.
5. Run differential socket-close and HCI-error tests under KASAN/lockdep; use KCSAN for list/lifetime concurrency where available. Existing defects may remain separately scoped only with an explicit non-regression assessment, not a claim that the mutex protects all paths.
6. Rerun the affected mesh/mgmt suites and W=1/sparse on the final combined dependency sequence. Retain full logs with kernel/config/tester IDs. Build and boot selected stable baselines before describing stable behavior as tested.

Real hardware was deliberately not touched. Before broad deployment, use a test adapter and independent receiver for actual packet timing/count and coexistence, then exercise the relevant legacy QCA setup and an extended-advertising controller. An emulator cannot validate USB transport quirks, controller firmware scheduling or RF loss. That hardware campaign can be a deployment gate distinct from upstream review, but the current count/deadline question already has useful emulator-level work available.

The common-sense assessment is that this project has reached a real subsystem boundary: list lifetime, workqueue lifetime, scheduler ownership and controller state are separate obligations. The current tests prove useful pieces of that boundary, but some claims combine them too broadly. A small set of targeted failure/interleaving tests will add more confidence than hundreds of repetitions of successful-path cases.

## Reproducible extracted-function check

Save the following as `check-mesh-queue.py` in an empty scratch directory. Supply `mgmt.c` from K with all three v2 patches applied. Python 3 and GCC with ASAN/UBSAN are required. This deliberately stubs allocation, locking, work scheduling, controller commands and replies; it tests the specific queue-cleanup control flow, not kernel concurrency. It writes two C files and two executables in the working directory.

```sh
ASAN_OPTIONS=detect_leaks=0 python3 check-mesh-queue.py /path/to/patched/net/bluetooth/mgmt.c
```

```python
from pathlib import Path
import subprocess
import sys

source = Path(sys.argv[1]).read_text()
def function(signature):
    start = source.index(signature)
    brace = source.index('{', start)
    depth = 1
    end = brace + 1
    while depth:
        depth += (source[end] == '{') - (source[end] == '}')
        end += 1
    return source[start:end]

prelude = r'''
#include <assert.h>
#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <errno.h>
typedef uint8_t u8; typedef uint16_t u16;
struct sock { int dummy; };
struct list_head { struct list_head *next, *prev; };
struct mgmt_mesh_tx { struct list_head list; struct sock *sk; u8 handle, instance; };
struct mgmt_cp_mesh_send { u8 adv_data_len; u8 adv_data[]; };
struct mgmt_rp_mesh_read_features { u8 max_handles, used_handles; };
struct hci_dev { struct list_head mesh_pending, adv_instances; int id, le_num_of_adv_sets; bool flag; unsigned ref; };
#define MESH_HANDLES_MAX 3
#define HCI_MESH_SENDING 1
#define HCI_MESH_EXPERIMENTAL 2
#define HCI_LE_ENABLED 3
#define MGMT_OP_MESH_SEND 0x59
#define MGMT_STATUS_NOT_SUPPORTED 1
#define MGMT_STATUS_REJECTED 2
#define MGMT_STATUS_INVALID_PARAMS 3
#define MGMT_STATUS_BUSY 4
#define MGMT_STATUS_FAILED 5
#define MGMT_EV_MESH_PACKET_CMPLT 0x32
#define struct_size(p,m,n) (sizeof(*(p))+(n))
#define bt_dev_err(...) ((void)0)
#define entry(p) ((struct mgmt_mesh_tx *)((char *)(p)-offsetof(struct mgmt_mesh_tx,list)))
#define list_for_each_entry(p,h,m) for(p=entry((h)->next); &(p)->m != (h); p=entry((p)->m.next))
static void init(struct list_head *h) { h->next=h->prev=h; }
static bool list_empty(struct list_head *h) { return h->next==h; }
static bool lmp_le_capable(struct hci_dev *h) { (void)h; return true; }
static bool hci_dev_test_flag(struct hci_dev *h,int f) { return f==1?h->flag:true; }
static void hci_dev_set_flag(struct hci_dev *h,int f) { (void)f; h->flag=true; }
static void hci_dev_clear_flag(struct hci_dev *h,int f) { (void)f; h->flag=false; }
static void hci_dev_lock(struct hci_dev *h) { (void)h; }
static void hci_dev_unlock(struct hci_dev *h) { (void)h; }
static int hci_disable_advertising_sync(struct hci_dev *h) { (void)h; return 0; }
static int hci_remove_advertising_sync(struct hci_dev *h,void *s,u8 i,bool f) { (void)h;(void)s;(void)i;(void)f;return 0; }
static int statuses, replies, events, fail_queue;
static struct mgmt_mesh_tx *queued;
static int mgmt_cmd_status(struct sock *s,int id,int op,int status) { (void)s;(void)id;(void)op; statuses++; printf("status=%d\n",status); return 0; }
static int mgmt_cmd_complete(struct sock *s,int id,int op,int status,void *p,int n) { (void)s;(void)id;(void)op;(void)status;(void)n; replies++; printf("reply handle=%u\n",*(u8 *)p); return 0; }
static void mgmt_event(int ev,struct hci_dev *h,void *p,int n,void *s) { (void)ev;(void)h;(void)n;(void)s; events++; printf("complete handle=%u\n",*(u8 *)p); }
static struct mgmt_mesh_tx *mgmt_mesh_add(struct sock *s,struct hci_dev *h,void *d,u16 len) {
 (void)d;(void)len; struct mgmt_mesh_tx *m=calloc(1,sizeof(*m)); assert(m); m->sk=s; m->handle=++h->ref;
 m->list.prev=h->mesh_pending.prev; m->list.next=&h->mesh_pending; h->mesh_pending.prev->next=&m->list; h->mesh_pending.prev=&m->list; return m;
}
static void mgmt_mesh_remove(struct mgmt_mesh_tx *m) { m->list.prev->next=m->list.next; m->list.next->prev=m->list.prev; free(m); }
static struct mgmt_mesh_tx *mgmt_mesh_next(struct hci_dev *h,struct sock *s) { struct mgmt_mesh_tx *m; list_for_each_entry(m,&h->mesh_pending,list) if(!s||m->sk==s) return m; return NULL; }
static void mgmt_mesh_foreach(struct hci_dev *h,void (*cb)(struct mgmt_mesh_tx *,void *),void *d,struct sock *s) { struct mgmt_mesh_tx *m; list_for_each_entry(m,&h->mesh_pending,list) if(!s||m->sk==s) cb(m,d); }
static void send_count(struct mgmt_mesh_tx *m,void *d) { (void)m; ((struct mgmt_rp_mesh_read_features *)d)->used_handles++; }
static int mesh_send_sync(struct hci_dev *h,void *d) { struct mgmt_mesh_tx *m=d; m->instance=h->le_num_of_adv_sets+1; printf("start handle=%u\n",m->handle); return 0; }
static void mesh_send_start_complete(struct hci_dev *h,void *d,int e) { (void)h;(void)d;(void)e; }
static int hci_cmd_sync_queue(struct hci_dev *h,int (*fn)(struct hci_dev *,void *),void *d,void (*cb)(struct hci_dev *,void *,int)) {
 (void)h;(void)fn;(void)cb; if(fail_queue) { fail_queue--; return -ENOMEM; } assert(!queued); queued=d; return 0;
}
'''
functions = '\n\n'.join(function(s) for s in [
    'static void mesh_send_complete(', 'static void mesh_next(struct hci_dev *hdev)\n',
    'static int mesh_send_done_sync(', 'static int mesh_send(struct sock *'])
main = r'''
int main(void) {
 struct hci_dev h={.le_num_of_adv_sets=3}; struct sock sk={0}; u8 packet[]={1,0x42};
 init(&h.mesh_pending); init(&h.adv_instances);
 fail_queue=1; mesh_send(&sk,&h,packet,sizeof(packet));
 assert(statuses==1 && replies==0 && !queued && !h.flag);
 printf("after rejected A: pending=%d flag=%d\n",!list_empty(&h.mesh_pending),h.flag);
 mesh_send(&sk,&h,packet,sizeof(packet));
 assert(queued && queued->handle==2);
 struct mgmt_mesh_tx *m=queued; queued=NULL; mesh_send_sync(&h,m); mesh_send_done_sync(&h,NULL);
#ifdef EXPECT_CLEANUP
 assert(!queued && list_empty(&h.mesh_pending) && !h.flag && events==1);
 puts("PASS: cleanup prevents rejected A from being scheduled");
#else
 assert(queued && queued->handle==1 && events==1);
 puts("CONFIRMED IN STUB HARNESS: rejected A is scheduled after successful B");
 m=queued; queued=NULL; mesh_send_sync(&h,m); mesh_send_done_sync(&h,NULL);
 assert(list_empty(&h.mesh_pending) && !h.flag);
#endif
 return 0;
}
'''
old = '\t\tif (mesh_tx) {\n\t\t\tif (sending)\n\t\t\t\tmgmt_mesh_remove(mesh_tx);\n\t\t}'
new = '\t\tif (mesh_tx)\n\t\t\tmgmt_mesh_remove(mesh_tx);'
assert old in functions
for mode in ['v2','cleanup']:
    text = prelude + (functions if mode=='v2' else functions.replace(old,new)) + main
    path=Path('extracted-'+mode+'.c'); path.write_text(text)
    exe=path.with_suffix('')
    subprocess.run(['gcc','-std=gnu11','-Wall','-Wextra','-Werror','-Wno-unused-parameter','-fsanitize=address,undefined','-g',str(path),'-o',str(exe)]+(['-DEXPECT_CLEANUP'] if mode=='cleanup' else []),check=True)
    print(mode,flush=True)
    subprocess.run([str(exe.resolve())],check=True)
```

## Final disposition

**Do not send this revision.** Retain the successful-path ownership fix, common teardown helper and owner matching. First repair the missing initial-enqueue cleanup assumption, make cancellation/dequeue tests prove their scenarios, resolve the Count/deadline compatibility question, and correct/test the power-transition argument. Correct the duration note and evidence-record errors as specified. No universal userland safety claim is justified, and no such claim is needed for a well-scoped, adequately tested submission.
