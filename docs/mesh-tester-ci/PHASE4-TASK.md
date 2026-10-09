# Phase 4 — revise the series after the outside review of 2026-10-02

**Private until sent.** The review is `review-series-2026-10-02.md` (same directory). Its
verdict: *do not send this revision* — the teardown design and the two-patch split stand;
four things must change. The following were checked here against the source and hold.

## Verified findings

1. **Scheduler ownership (blocker).** `mesh_send_done_sync()` clears `HCI_MESH_SENDING`
   first (`mgmt.c:1099`) and now sleeps on controller commands; `mesh_send()` reads the flag
   under `hdev->lock` and, when clear, queues `mesh_send_sync()` itself (`mgmt.c:2532-2538`);
   afterwards `mesh_next()` (the done work's destroy callback, `mgmt.c:1112-1126`) queues
   the pending head again. `hci_cmd_sync_queue()` does not deduplicate. Window: the whole
   teardown round-trip (before the series it was the microseconds between the clear and
   `mesh_next`). Consequence: the same `mesh_tx` started twice, or a newly submitted packet
   queued ahead of an older one. Not reproduced; derived from source.
2. **Patch 2/2's message is wrong about bluetooth-meshd.** `mesh/mesh-io-mgmt.c:send_cmplt()`
   (BlueZ `8b4a41760`, lines 225-229) ignores Mesh Packet Complete entirely; the daemon
   keeps the handle only for cancellation. The "bluetooth-meshd matches the event…"
   sentences must go; the fix stays justified by the lost pending request.
3. **The new tester cases can pass without their scenario.** Cancel-active issues the cancel
   on the second Send's acknowledgement without establishing that A is still active;
   coexistence setup does not gate on Add Advertising success; the HCI hook ignores a
   targeted disable of set 1 and clear-all; `mgmt_send`/`mgmt_register` return values are
   not checked; the malformed-reply diagnostic can over-read; both sends use identical PDUs.
4. **The duration note's arithmetic**: 655 s → 65,176 ms truncated → 6517 → **65.17 s** (not
   65); 8192 s → 0 → no finite duration; "every timeout above 65 s stops early" is false;
   a clamp alone would shorten MGMT timeouts above 655.35 s and is not a complete fix.
5. **Smaller:** the MGMT document is `doc/mgmt-protocol.rst` (transmit §4075-4121, cancel
   §4123-4143, completion §5469-5480 at `8b4a41760`) — quote it, and do not call the event a
   delivery acknowledgement; BlueZ `doc/coding-style.rst` wants multi-line comments to start
   on the second line, and `HACKING` prefers ≤50-character subjects; the cover must not say
   "on air" for a request that only acquired the instance, nor imply a clean valgrind run
   (18/18 functional with seven pre-existing tester findings), nor make CI-history claims
   broader than the measured signature; the original `f3cb5676e5c1` CI reply of 25 June 2025
   already showed the same two timeouts (a fact for the private record, not a trailer).
6. **Open and acknowledged**: error-path cleanup (`mesh_send_sync()` can add the instance and
   fail to schedule; `mesh_send_start_complete()` then neither removes it nor arms done
   work) and power-transition behaviour are pre-existing and outside this series; the
   messages must not claim them.

## The work

**A. Ownership protocol (patch 1/2 or a prerequisite patch).** Keep `HCI_MESH_SENDING` set
through the teardown; move the decision "is there a next packet, else go idle" under
`hdev->lock` *after* the teardown and before anything can observe the flag clear; make
`mesh_next()` and the syscall-side enqueue in `mesh_send()` use one protocol so that each
request is started exactly once and in FIFO order; never hold `hdev->lock` across a
synchronous HCI command. Reconcile with `71af682ba469`'s `send_cancel()` (which calls
`mesh_next()` when the flag is clear) and `3c742feda8fc`. Document the invariant in a
comment at the flag. If this is a separate patch, say which of the two it precedes and keep
every intermediate commit buildable and tested.

**B. Test for A.** The emulator cannot delay a Command Complete on request; find the closest
deterministic lever (an `hciemu` hook, `btdev` option, or a tester-side ordering that forces
a Send to land while teardown is in flight) and assert exactly one start per request and
FIFO order. If no deterministic lever exists, say so and provide a stress run (≥200
iterations) plus the source argument.

**C. Messages.** 2/2: replace the meshd sentences with the review's wording ("The next
packet can therefore leave the pending queue without being advertised, even though userspace
has not cancelled it."), quote `mgmt-protocol.rst`; 1/2 and the cover: the review's exact
replacements for "on air", the 75 ms (cnt=3 nominal), valgrind, CI history, legacy
coexistence scope, and the scope sentence of E4.

**D. Tester patch.** The review's F2 list and its three small diffs: gate cancel-active on
observed state (A acknowledged and started, B acknowledged and queued, cancel before any
completion of A, cancel acknowledged, A completed once, B started and completed once; natural
completion before the cancel = failed precondition); gate coexistence setup on Add
Advertising; hook all set entries and reject disable/remove/clear of the ordinary set; check
`mgmt_send`/`mgmt_register` returns; bound the diagnostic; distinct PDUs per request; BlueZ
comment style; a ≤50-character subject ("tools/mesh-tester: Test mesh advertising lifecycle").

**E. Duration note.** Correct the table (655 → 65.17 s, add 656, 1000, 8192), the "above
65 s" sentence, the clamp conclusion (the review's exact replacement), and the provenance
sentence ("present in hci_sync since the conversion; the expression predates it in
hci_request; the introducing commit not yet identified").

**F. Rerun every gate** on the revised series: mesh-tester old + new cases on BREDRLE and
BREDRLE50, KVM and TCG+valgrind, ASAN; full mgmt-tester; the repeat runs; checkpatch
`--strict --codespell` (install codespell), W=1, sparse; cumulative apply on the five stable
snapshots; `scripts/get-maintainers.sh`. Record in `phase4-results.md` after every step.

## Constraints (unchanged)

qemu only; never touch the host's Bluetooth or kernel; writes only under `cache/` and
`tmp/mesh-tester-ci/`; post nothing; author Iaroslav
Voitovych <yaroslav.voytovych@gmail.com>.
