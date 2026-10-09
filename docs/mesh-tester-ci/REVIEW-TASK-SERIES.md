# Review task — the mesh advertising series, before it goes to the maintainers

**Private until sent. Do not post, mail or comment anywhere about it.** The purpose of
this review is to spare the Bluetooth maintainers work: whatever they would find, we want
found here first. Please be adversarial.

## What is being reviewed

On this branch (`diag/mesh-tester-ci`, then in the project's private repository; the same
paths are on `main` since 2026-10-09):

- `patches/mesh-tester/series/0001-Bluetooth-MGMT-remove-the-mesh-advertising-instance-.patch`
- `patches/mesh-tester/series/0002-Bluetooth-MGMT-complete-the-mesh-transmission-that-w.patch`
- `patches/mesh-tester/series/0000-cover-letter.patch`
- `patches/mesh-tester/series/bluez-0001-tools-mesh-tester-Add-extended-advertising-and-send-sequence-tests.patch`
  (BlueZ, separate submission)
- `docs/mesh-tester-ci/phase3-results.md` — design, every run with its command and output,
  §4d stable reasoning, "Open questions"
- `docs/mesh-tester-ci/duration-overflow-note.md` — a separate finding, not in the series
- Earlier: `phase1-findings.md`, `phase2-results.md`, `REVIEW-TASK.md` and the previous
  review's findings as summarised in `PHASE3-TASK.md` §"What the review found".

Base: `bluetooth/master` **86ef0f58bdec**; applies with `git am` on `bluetooth-next`
`671d566d3c3b`; dry-applies to stable 6.1.y–7.2.y.

## The previous round's blocker — confirm it is closed

The first version removed the host-side instance before the extended-advertising removal
sequence, so on an ext-adv controller no `LE Remove Advertising Set` was sent. The series
now goes through `hci_remove_advertising_sync()` (hci_sync.c:2201) → `hci_remove_adv_sync()`
→ `hci_remove_ext_adv_instance_sync()`; the instance is removed by
`hci_cc_le_remove_adv_set()` on Command Complete, whose `mgmt_advertising_removed()` call
now returns early for the internal instance. **A1.** Confirm from the source and the quoted
wire trace (§3b of the results: `0x2039 {0x00, 1 set, handle}`, then `0x203c`, no global
disable) that both paths are correct, and that nothing else calls
`mgmt_advertising_removed()` for a legitimate instance numbered above `le_num_of_adv_sets`.

## Perspectives — please take every one

**B. Userspace and compatibility.**
1. `bluetooth-meshd` (BlueZ `mesh/`): read how it consumes `MGMT_EV_MESH_PACKET_CMPLT`
   and the handles. Does any of its logic depend on the *old* behaviour — the queue head
   being completed, the packet staying on air after its count, the absence of a disable?
   Could a daemon that "works today" work because of the bug?
2. Any other user of the mesh MGMT commands in the wild (search: `MGMT_OP_MESH_SEND`,
   `mesh_send`, "Mesh Send Cancel", projects outside BlueZ)? Could an application have a
   workaround that the fix breaks?
3. `MGMT_EV_ADVERTISING_REMOVED` suppression: is there any client that enumerates
   instances above `le_num_of_adv_sets` or that counts Advertising Removed events? Is
   `> le_num_of_adv_sets` the right test, or should the kernel mark the instance (there is
   an unused `adv->mesh` field, `hci_core.c:1720`) and test that? Which would a maintainer
   prefer, and why?
4. Does `doc/mgmt-api.txt` (BlueZ) describe the semantics the series restores? Quote it.
   Does the series change any documented behaviour?

**C. Duplicates and prior art.**
1. Is there a patch, sent or applied, that addresses either defect: search patchwork
   (`project=bluetooth`), the `bluetooth`/`bluetooth-next` logs since `f3cb5676e5c1`,
   lore (the `mesh_send`, `mesh_send_done_sync`, `adv_instances` threads), and the
   `f3cb5676e5c1` thread itself — did its author or reviewers discuss the mesh instance?
2. `71af682ba469` and `3c742feda8fc` (2026) touch this path: does the series conflict with
   their intent, and is §4d's claim that 2/2 does not depend on `71af682ba469` right?

**D. Kernel rules, style and tradition.**
1. `scripts/checkpatch.pl --strict` on each patch (done: 0/0/0 — please re-run and look at
   `--codespell` and `--subjective` too); W=1 and sparse (done; please read the logs).
2. Subject prefixes (`Bluetooth: MGMT:`), `Fixes:` format and hashes, `Cc: stable` placement,
   sign-off, 72-column bodies, imperative mood, no first person in the subject, cover letter
   form; `Documentation/process/submitting-patches.rst` and `stable-kernel-rules.rst`.
3. Comment style and placement in `net/bluetooth/mgmt.c`; does the series match how the
   surrounding code is written (naming, early returns, the `hci_*_sync` conventions)?
4. Is a two-patch series the right split, in this order? Should 2/2 come first? Should the
   `mgmt_advertising_removed()` hunk be its own patch?

**E. Architecture and philosophy.**
1. Is `hci_remove_advertising_sync()` the right layer for MGMT's mesh code to call, or does
   the subsystem expect mesh teardown to stay inside `mgmt.c` / use `hci_disable_*`
   primitives? Compare with how `remove_advertising()` and `adv_timeout_expire_sync()` do it.
2. `force = true` and `sk = NULL` in that call: consequences (the `force` branch, the
   `next` rescheduling for legacy, `hdev_is_powered`/`HCI_ADVERTISING` checks).
3. Legacy coexistence (results §"Open questions" 1): the mesh packet is never aired when an
   ordinary instance is rotating on a single-set controller — pre-existing. Should the
   series mention it, fix it, or leave it? What would the maintainers expect?
4. Would a maintainer rather see the instance removed in `mesh_send_complete()` (per
   transmission) than in `mesh_send_done_sync()`? Any path where the instance is left
   behind (errors in `mesh_send_sync()`, power-off with a transmission pending,
   `hci_dev_close`)?
5. The `u16 duration` overflow note: is the analysis right, is it worth a patch of its own,
   and would it interact with this series?

**F. The BlueZ tester patch.**
1. Conventions of `tools/*-tester.c` (naming, `test_bredrle50` use, `tester_*` API,
   timeouts); does it follow `HACKING`/the existing style; gitlint and BlueZ checkpatch.
2. Do the new cases assert what they claim (handles, counts, absence of the event)? Could
   they pass for the wrong reason? Are they deterministic (the results note the two
   original cancel cases are load-sensitive)?
3. Will the bot's current configuration run them (ASAN tester, KVM)? Any emulator (`btvirt`)
   limitation that makes a BREDRLE50 case meaningless?

**G. Stable.**
1. For 1/2: `f3cb5676e5c1` is in which stable lines; does 1/2 apply and make sense in each
   (the `hci_remove_advertising_sync()` signature across versions)?
2. For 2/2: which lines have `b338d91703fa`'s code in the form 2/2 patches; is a `Cc: stable`
   appropriate for a semantics fix of this kind?

**H. Everything else.** Anything a maintainer would say — tone, length, claims in the
messages that overreach ("every kernel patch since June fails" vs the measured signature),
the cover letter, missing `Reported-by`/`Tested-by` conventions, whether the CI history
belongs in the message at all.

## What we do not ask

- No re-diagnosis from memory; the source and the quoted traces are the arbiter.
- No runs on hardware. Running the testers in qemu is welcome if you can; the commands are
  in the results file.
- No posting, mailing, or issues anywhere.

## Form of the answer

One document. For each item A1, B1–B4, C1–C2, D1–D4, E1–E5, F1–F3, G1–G2, H: a verdict
(**confirmed / refuted / cannot tell from the source / not applicable**), the citation
(`file:function:line` at the named commit, or the URL for a list/tracker item), the
reasoning in a few sentences, and — where you would change something — the exact text or
diff. Mark anything inferred rather than read as **inferred**; "I don't know" is an answer.
End with: *send as is / send with these changes / do not send*, and why.

Author of the patches and the only attribution in this repository: Iaroslav Voitovych.
