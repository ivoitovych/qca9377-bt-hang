# Review task — the mesh advertising series, revision 2, before it goes to the maintainers

**Private until sent. Do not post, mail or comment anywhere about it.** The purpose of this
review is to spare the Bluetooth maintainers work: whatever they would find, we want found
here first. Please be adversarial. The previous round (`review-series-2026-10-02.md`) found
a real blocker; this round asks you to confirm it is closed and to break the fix.

## What is being reviewed

On this branch (`diag/mesh-tester-ci`, then in the project's private repository; the same
paths are on `main` since 2026-10-09), directory
`patches/mesh-tester/series-v2/`:

- `0001-Bluetooth-MGMT-hand-mesh-transmissions-over-under-hd.patch` — **new**: the ownership
  protocol for `HCI_MESH_SENDING` (prerequisite for the other two)
- `0002-Bluetooth-MGMT-remove-the-mesh-advertising-instance-.patch` — the tear-down through
  `hci_remove_advertising_sync()` (was 1/2)
- `0003-Bluetooth-MGMT-complete-the-mesh-transmission-that-o.patch` — complete the owner of
  the instance (was 2/2)
- `0000-cover-letter.patch`
- `bluez/0001-tools-mesh-tester-Test-mesh-advertising-lifecycle.patch` (BlueZ, separate
  submission; replaces the phase-3 tester patch)
- `docs/mesh-tester-ci/phase4-results.md` — the design of v2, the reproduction of the race on
  the phase-3 series (§3a), every run with command and output, hygiene, stable (§4d)
- `docs/mesh-tester-ci/duration-overflow-note-v2.md` — corrected, still not in the series
- Earlier: `phase3-results.md`, `review-series-2026-10-02.md` (your previous round),
  `PHASE4-TASK.md` (what was asked after it).

Base: `bluetooth/master` **86ef0f58bdec**; applies with `git am` on `bluetooth-next`
(results §4e); the three patches apply cumulatively to the current linux-7.2.y, 6.18.y,
6.12.y, 6.6.y and 6.1.y tips **after `71af682ba469`**, which 1/3 names as a stable
prerequisite (§4d). No stable kernel was built or run.

Everything upstream is quoted at a commit; the two upstream commits the stable check needed
are `71af682ba469` and `3c742feda8fc` (not copied into the branch).

## The previous round's four findings — confirm each is closed

**A1. Scheduler ownership (your blocker).** Reproduced before fixing: with the phase-3 series a
Mesh Send landing while `mesh_send_done_sync()` waits for the controller is started twice
(results §3a, both emulators; the tester's hold case forces it by holding the tear-down
command in `btdev`). 1/3's protocol: `HCI_MESH_SENDING` is set when a start is queued and
cleared only in `mesh_next()`, which runs under `hdev->lock` and only when nothing is pending;
`mesh_send()` tests the flag under the same lock; `mesh_send_done_sync()` does its controller
commands first, then takes `hdev->lock`, completes the owner, calls `mesh_next()`; a failed
start takes the same path; `send_cancel()` takes `hdev->lock` around the dequeues and calls
`mesh_next()` exactly when it dequeued a queued start; the `-ECANCELED` destroy callback
(under `cmd_sync_work_lock`) only completes its request. Please:

1. Read the protocol against every reader and writer of the flag at `86ef0f58bdec` + v2 and
   state whether any path can (a) start one `mesh_tx` twice, (b) start a later `mesh_tx`
   before an earlier one, (c) leave the flag set with nothing queued, running or on air, or
   (d) clear it while something is. For (c), the paths we know of and have **not** fixed are
   listed in results §"Open" 3; say whether 1/3 makes any of them worse than before.
2. Lock order: `hdev->lock` → `cmd_sync_work_lock` in `send_cancel()` (via
   `hci_cmd_sync_dequeue()`). Find any path that takes them the other way round. Lockdep was
   silent in every run (results §3); say whether the runs could have exercised the inversion.
3. The `-ECANCELED` path. Before v2, `mesh_send_start_complete()` cleared the flag on **any**
   error, including the dequeue by `hci_cmd_sync_clear()` at unregister. v2 does not: it
   completes the request and leaves the hand-over to whoever dequeued. `HCI_MESH_SENDING`
   is not among `hci_dev_clear_volatile_flags()`, and `__mgmt_power_off()` does not touch
   `mesh_pending`. [Corrected 2026-10-04 after the review of 2026-10-03, finding 4; the
   earlier sentence claimed a prompt `-ENETDOWN`, which was wrong:] Power-off does not dequeue
   already accepted mesh starts through hci_cmd_sync_clear(). The worker may execute them
   after close. Their internal synchronous HCI path has no general down-device guard
   guaranteeing -ENETDOWN. The resulting timeout/error and scheduler recovery behavior has
   not been established by the recorded tests. (Phase 5 tested it: `phase5-results.md` §D.)
   Please confirm that reading from the source
   (`hci_dev_close_sync()`, `hci_cmd_sync_work()`, `__hci_cmd_sync_sk()`), and say whether
   there is any dequeue with `-ECANCELED` of a mesh start **other than** `send_cancel()` and
   unregister. The cover letter disclaims power transitions; tell us if that disclaimer is
   doing too much work.
4. `mesh_next()` loops over `mgmt_mesh_next(hdev, NULL)` completing each `mesh_tx` whose
   start cannot be queued. Any way that loop fails to terminate, or completes a `mesh_tx`
   belonging to a socket that has meanwhile closed (`mgmt_cleanup()` removes a socket's
   `mesh_tx` without `hdev->lock` — pre-existing; does v2 widen it)?

**A2. The bluetooth-meshd sentences** are gone from 3/3; `doc/mgmt-protocol.rst` is quoted
instead. Confirm the quotations are exact at BlueZ `8b4a41760` (or current master) and that
nothing in 3/3's message still claims anything about the daemon.

**A3. The tester.** Each case now gates on observed state (results §2); the hold case is the
deterministic lever for the race. Check: can any new case still pass without its scenario?
Is the hold case deterministic, or does it depend on timing the emulator does not promise?
Does the hook see every advertising-set entry (your F2 list: targeted disable of set 1,
clear-all, the ordinary set)? Return values checked; diagnostic bounded; distinct PDUs per
request; BlueZ comment style; subject ≤ 50 characters?

**A4. The duration note** is `duration-overflow-note-v2.md`: table (655 → 65.17 s; 656, 1000,
8192 added), the "above 65 s" sentence, the clamp conclusion, the provenance sentence. Check
the arithmetic again and whether the note now says only what the source supports.

## Perspectives — please take every one again, against v2

**B. Userspace and compatibility.** B1–B4 as in the previous task, now for three patches.
Specifically for 1/3: does any userspace observe the ordering change (a Send that previously
started at once, when the flag was clear during a tear-down, is now queued behind the
tear-down and started by `mesh_next()`)? Is the Mesh Send reply (`MGMT_OP_MESH_SEND`
complete with the handle) unchanged in timing and content?

**C. Duplicates and prior art.** Search again (patchwork `project=bluetooth`, lore, the
`bluetooth`/`bluetooth-next` logs since 2026-10-02) for anything touching `mesh_send`,
`mesh_next`, `HCI_MESH_SENDING`, `send_cancel`. Does 1/3 duplicate or contradict the intent
of `71af682ba469` (dequeue on cancel) or `3c742feda8fc` (free the cancel command)?

**D. Kernel rules, style and tradition.** D1–D4 as before, now for three patches: checkpatch
`--strict --codespell` (done, 0/0/0 — re-run), W=1, sparse (logs quoted in §4f); subject
and `Fixes:` lines; the two `Cc: stable` lines of 1/3 (the prerequisite form from
`stable-kernel-rules.rst` — is the syntax exactly right, and should 2/3 and 3/3 carry the
same prerequisite line?); the three-patch split and order; the comment at the flag in
`hci.h` and the block comment above `mesh_next()` — too long for the subsystem's taste?

**E. Architecture and philosophy.** E1–E5 as before, plus: is a flag-plus-lock protocol what
the maintainers would want here, or would they rather see the mesh queue driven entirely from
`hci_cmd_sync` ordering (one work item per transmission, no flag)? Is there precedent in
`net/bluetooth` for "state flag cleared only under the lock the reader tests under"? Would
a maintainer ask for the hand-over to live in `hci_sync.c` rather than `mgmt.c`?

**F. The BlueZ tester patch.** F1–F3 as before; the bot runs the ASAN tester under KVM — does
the hold case rely on anything the emulator build in CI lacks?

**G. Stable.** 1/3 `Fixes: b338d91703fa` with a prerequisite; 2/3 `Fixes: f3cb5676e5c1`; 3/3
`Fixes: b338d91703fa`. For each line 6.1.y–7.2.y: does the three-patch set apply **and make
sense** (the `hci_remove_advertising_sync()` signature, `send_cancel()`'s shape before and
after `71af682ba469`)? Is asking stable to take `71af682ba469` first reasonable, or should
the operator send a separate request for it?

**H. Everything else.** The cover letter: every number in it against results §3; claims that
overreach; tone; length; whether "no stable kernel was built or run" belongs in the cover or
only in the record.

## What we do not ask

- No re-diagnosis from memory; the source and the quoted traces are the arbiter.
- No runs on hardware. Running the testers in qemu is welcome; the commands are in the
  results file.
- No posting, mailing, or issues anywhere.

## Form of the answer

One document. For each item A1.1–A1.4, A2, A3, A4, B, C, D, E, F, G, H: a verdict
(**confirmed / refuted / cannot tell from the source / not applicable**), the citation
(`file:function:line` at the named commit, or the URL for a list/tracker item), the reasoning
in a few sentences, and — where you would change something — the exact text or diff. Mark
anything inferred rather than read as **inferred**; "I don't know" is an answer. End with:
*send as is / send with these changes / do not send*, and why.

Author of the patches and the only attribution in this repository: Iaroslav Voitovych.
