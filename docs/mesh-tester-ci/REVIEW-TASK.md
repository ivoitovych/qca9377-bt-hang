# Review task — one kernel patch, `net/bluetooth/mgmt.c`, mesh advertising

**Private until the patch is sent. Do not post, mail or comment anywhere about it.**

## What is being reviewed

One patch of 26 added / 4 removed lines, with its commit message:

- Patch: `patches/mesh-tester/0001-Bluetooth-MGMT-stop-advertising-when-a-mesh-transmission-is-done.patch`
  (this branch, `diag/mesh-tester-ci`, then in the project's private repository; the same
  path is on `main` since 2026-10-09)
- The diagnosis it rests on: `docs/mesh-tester-ci/phase1-findings.md` (§4–§7)
- The test record: `docs/mesh-tester-ci/phase2-results.md` (§3 unpatched, §4 patched, §5 verdict)
- Base tree: `bluetooth-next` at `671d566d3c3b` ("Merge branch 'bluetooth' into bluetooth-next");
  the patch is also applied on top of `bluetooth` + the already-accepted commit `86ef0f58bdec`
  without conflict.

## The claim, in four sentences

1. Since `f3cb5676e5c1` (2025-06-25), `mesh_send_done_sync()` disables advertising only when
   `hdev->adv_instances` is empty.
2. The instance a mesh packet is advertised through (`le_num_of_adv_sets + 1`, added by
   `mesh_send_sync()` with a 1000 s timeout) is itself on that list and nothing removes it
   when the transmission ends, so the condition is never true for a mesh send: no
   `LE Set Advertising Enable (0x00)` is sent and the packet stays on air for 1000 s.
3. `mesh_send_done_sync()` also completes `mgmt_mesh_next()` — the head of `mesh_pending` —
   rather than the transmission that was on air; after a Mesh Send Cancel of the in-flight
   handle, the head is the next, unsent packet, which is then reported complete.
4. The patch removes the mesh instance (under `hci_dev_lock`) before the existing check and
   completes the `mesh_tx` whose `->instance` matches. BlueZ's `tools/mesh-tester` goes from
   8/10 to 10/10 in qemu (KVM, KVM + valgrind, TCG + valgrind), `mgmt-tester` stays 501/501.

## What we ask of you — exactly this, in this order

A. **Confirm or refute each of the four sentences against the source**, citing
   `net/bluetooth/mgmt.c`, `hci_sync.c`, `hci_core.c` at `671d566d3c3b` by function and line.
   "Sentence 2 is wrong because X at line N removes the instance" is the most valuable
   possible answer.

B. **Review the patch for correctness in the kernel's own terms.** Specifically:
   1. `hci_remove_adv_instance()` is called with `hci_dev_lock` held from a `hci_cmd_sync`
      work callback. Is that the right lock and context (compare its other callers, and what
      `adv_instance_expire`'s delayed work does on the same instance)?
   2. Can `hci_remove_adv_instance()` here race with, or be made redundant by,
      `adv_timeout_expire_sync()` / `hci_clear_adv_instance_sync()` for the mesh instance?
   3. With extended advertising (`ext_adv_capable(hdev)`), is the instance used by
      `mesh_send_sync()` still `le_num_of_adv_sets + 1`, and does removing it need
      `hci_remove_ext_adv_instance_sync()` (or a disable of that adv set) rather than, or in
      addition to, the legacy disable?
   4. Completing the `mesh_tx` whose `instance` matches: can two entries in `mesh_pending`
      carry the same instance at once (`mesh_send_sync()` runs only while `HCI_MESH_SENDING`
      is clear — is that sufficient)?
   5. After a cancel, `send_cancel()` (post-`71af682ba469`) dequeues `mesh_send_sync` and
      calls `mesh_next()`; does the patched `mesh_send_done_sync()` interact badly with that
      ordering (double completion, a `mesh_tx` freed while `mesh_send_done` is pending)?
   6. The commit message: is every statement in it true of the code, and is the second
      `Fixes:` (`b338d91703fa`, the original mesh implementation) justified for the
      queue-head defect, or should the patch be split in two?
   7. `Cc: stable@vger.kernel.org`: `f3cb5676e5c1` went to stable; is this fix suitable for the
      same trees as written (it uses only functions that exist there), and should it say so?

C. **Say what you would change**, as a diff or as exact text, if anything.

D. **Say what you did not check.** A review that lists its own gaps is worth more than one
   that implies completeness.

## What we do NOT ask

- Do not re-diagnose from forum posts, search engines or memory. The diagnosis is in the two
  findings files, every claim with its command and output; the source is the arbiter.
- Do not run anything on hardware; do not run the tests yourself unless you want to (the
  record of the runs is in the phase-2 file, with commands).
- Do not comment on the CI bot, the project's history, or any other patch.
- Do not post, mail, or open issues anywhere.

## Form of the answer

A single document. For each item A1–A4, B1–B7: a verdict (**confirmed / refuted / cannot
tell from the source**), the citation (`file:function:line` at `671d566d3c3b`), and the
reasoning in a few sentences. Mark anything inferred rather than read as **inferred**. No
links to pages you did not open; no claims without a citation. If the answer to a question
is "I don't know", write that.

Author of the patch and the only attribution in this repository: Iaroslav Voitovych.
