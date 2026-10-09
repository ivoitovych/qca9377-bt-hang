# Outside research and review of 2026-10-05 — kept with its verification

The answer to `RESEARCH-AND-REVIEW-TASK-2026-10-05.md`, received 2026-10-05, read at private
snapshot `b40987d`. Kept here as a summary of its findings with what was checked against the
sources the same day; the operator holds the full text.

## Its verdict

Do not send series-v3 as it stands, and do not discard it. The work has reached an
architectural boundary: the Mesh MGMT transmit path has never had one articulated ownership
model for request lifetime, controller-work serialization and advertising-object lifetime.
The other 2026 work (the February race patch, the August lifetime series, `71af682ba469`, the
September cleanup) and this project's series are pieces of the same incompletely specified
state machine.

| patch | disposition | reason |
|---|---|---|
| 1/5 hand-over under `hdev->lock` | keep the idea, rework after reconciling with the lifetime work | fixes the reproduced race; does not cover every `mesh_pending` lifetime operation (`mgmt_cleanup()`, the `-ECANCELED` destroy callback from `hci_cmd_sync_clear()`) |
| 2/5 remove the mesh instance | keep, refine | the right abstraction; use an exact predicate (`instance == le_num_of_adv_sets + 1` or a helper) instead of `> le_num_of_adv_sets`; add one error-injection case for a failed disable/remove and record the residue |
| 3/5 complete the owner | keep | correct request identity; matches the protocol's lifecycle meaning |
| 4/5 power-off | keep, submit separately | real, independent defect; `hci_cmd_sync_submit()` can still fail at unregister or on allocation |
| 5/5 Count comment | drop | would document an ABI contradiction as intended behaviour; open a Count RFC instead |

Also: the failed-enqueue cleanup stays Hui Peng's — this project's fault-injection result is
best offered as test evidence on his patch; the duration overflow stays separate and needs a
timeout design, not a clamp; stable intent waits for upstream agreement; the BlueZ work is
split (the `src/shared/mgmt.c` leak fix on its own, then emulator hooks and fault injection,
then smaller lifecycle-test patches; receiver Count cases stay observational); unregister with
a backlog is the largest adjacent hole and blocks any claim of general lifecycle correctness.

Suggested order: reconcile the lifetime baseline (the cleanup, the August series and what its
automated review found, with the maintainers); rebase the core three on that; send the
power-off fix separately; Count as an RFC; duration separately; BlueZ split; stable
validation last.

## Verified here, 2026-10-05 (quoted)

| claim | source | what it says |
|---|---|---|
| the `f3cb5676e5c1` author was tentative | lists.openwall.net/linux-kernel/2025/06/25/1237, "[PATCH 3/3] Bluetooth: MGMT: mesh_send: check instances prior disabling advertising" | "not sure whether this call is required at all, but checking the … seems to solve the …" |
| the maintainer agreed the extended-advertising disable was a bug | lists.openwall.net/netdev/2025/06/27/274, "Re: [PATCH v3] Bluetooth: HCI: Set extended advertising data synchronously" | "Status: Command Disallowed (0x0c)" … "Yeah, that is indeed a bug" |
| the February 2026 race patch and the lock question | spinics.net/lists/stable/msg912251.html, "Re: [PATCH v4 2/2] Bluetooth: mgmt: Fix race conditions in mesh handling" | "Not sure why you switched to use hdev->lock and not mgmt_pending_lock? And that is a mutex still, not a spinlock." |
| the August lifetime series removes the socket-destructor walk | lists.openwall.net/linux-kernel/2026/08/07/426, "[PATCH 1/3] Bluetooth: MGMT: remove the mesh walk from the socket destructor" | "mgmt_cleanup() cannot take hdev->lock … Remove mgmt_cleanup() and its caller." |
| … and protects `mesh_pending` with `hdev->lock`, meeting the `cmd_sync_work_lock` order | lists.openwall.net/linux-kernel/2026/08/07/427, "[PATCH 2/3] Bluetooth: MGMT: protect hdev->mesh_pending with hdev->lock" | "hci_cmd_sync_clear() runs a destroy callback under cmd_sync_work_lock" and a lockdep chain through it |
| the maintainer reported problems in that series | lists.openwall.net/linux-kernel/2026/08/07/1532, "Re: [PATCH v2 0/3] Bluetooth: MGMT: fix use-after-free of struct mgmt_mesh_tx" | the maintainer: the subsystem's automated review "found a couple of problems" |
| MGMT/D-Bus success while nothing is delivered | github.com/bluez/bluez/issues/2337 (closed) | "bluetooth-meshd silently fails to deliver mesh messages while reporting success at every layer (D-Bus, MGMT, HCI)" — LE Set Random Address Command Disallowed during advertising |
| neither the August series nor the September cleanup is merged | `git -C cache/linux log --oneline --since=2026-08-01 bluetooth-next/master -- net/bluetooth/mgmt.c net/bluetooth/mgmt_util.c` (and the same on `bluetooth/master`), after `git fetch` 2026-10-05 | mesh-related: `71af682ba469`, `3c742feda8fc` only |

Not re-checked here: the Zephyr Kconfig wording on extra retransmissions with the legacy
advertiser, and the Mesh 1.1 specification text; both are cited in the review with links.

## The reviewer's follow-up, same day

The reviewer agreed with both differences below, and made one correction and one change of
order:

- **Correction.** Phase 5 tested a locally written equivalent of Hui Peng's cleanup, not his
  posted patch. A `Tested-by:` is earned only on the exact patch, applied with `git am`, his
  authorship intact, on the tree the maintainers apply it to, through at least the targeted
  fault-injection case. Started 2026-10-05: validation of the exact patch on bluetooth-next,
  results in `tmp/mesh-tester-ci/validation-2026-10-05.md`; the reply is drafted, not sent.
- **Order.** 1 — exact-patch validation and a Tested-by reply on Hui Peng's patch (it turns one
  assumption of the scheduler invariant, "a clear `HCI_MESH_SENDING` means no rejected request
  remains", into upstream fact, and opens contact on the exact thread this work needs); 2 — the
  BlueZ `shared/mgmt` leak fix on its own; 3 — the power-off fix (4/5) as a single patch; 4 — the
  Count RFC; 5 — the core ownership series, after the cleanup and the August lifetime
  discussion settle; 6 — the duration overflow.
- **An organising document, private, not for upstream yet:** write the state machine down —
  request states, who owns a `mesh_tx`, who owns the mesh advertising instance, who may remove
  a request, who hands ownership over, the lock and context of each transition, and what
  happens on cancel, error, power-off and unregister — then map every current and historical
  patch onto the transition it repairs. The core series can then be explained as "these are the
  invariants; these transitions violate them in mainline; these patches repair exactly those".

## The reviewer on the state-machine document and the validation (same day)

- **Two findings promoted.** (1) Device removal: since `b1f24c1ab523` the `-ECANCELED` path at
  unregister is structural, not a corner; "what does an accepted mesh transmission mean when
  its index disappears" is a missing policy, answered differently by mainline, August and v3.
  (2) **I12, `mesh_send_sync()` calls `hci_add_adv_instance()` without `hdev->lock`** although
  that function requires it: a concrete locking-contract violation, not a policy question —
  reproduce it before the core series is redesigned, because the transition into slot
  ownership already happens outside the documented lock.
- **"11 of 14 invariants" is not a safety metric.** The invariants carry very different
  weights; use the matrix for comparison only.
- **Keep device removal and Count in separate threads.** Count is a uAPI question; device
  removal is lifetime and notification semantics with locking consequences. The concrete
  question: when `HCI_UNREGISTER` destroys queued mesh work, are accepted requests completed
  with Mesh Packet Complete or silently discarded, and should `mgmt_index_removed()` own a
  drain under `hdev->lock`? (The document's shape — the destroy callback leaves the request
  alone, a later deliberate drain under the right lock — is plausible; not to be implemented
  yet.)
- **The inferred lock-order inversion** (`cmd_sync_work_lock` → `unregister_lock` at device
  removal) stays a hypothesis until a VM with lockdep and a queued teardown says otherwise; if
  lockdep is silent, drop it from the argument.
- **Order unchanged** (exact cleanup validation, BlueZ leak, power-off, Count RFC, core,
  duration), with **research gates inserted before the core series**: confirm I12 → run the
  unregister lockdep case → obtain maintainer direction on unregister lifetime → then design
  P1–P3. The power-off fix stays separable (Set Powered with the device still registered is a
  different boundary from unregister).
- **A legitimate architectural question now:** should `HCI_MESH_SENDING` stay a stored boolean,
  or should ownership be explicit (an owner pointer or identity)? Not to be implemented
  speculatively.
- Assessment: cleanup + BlueZ leak approaching upstream action; power-off a mature
  independent bug; Count an isolated policy question; core better understood, not to be
  sent; unregister promoted to a first-class missing transition; advertising-list locking a
  newly exposed concrete risk.

Started 2026-10-05: the two research gates (I12 reproduction; unregister lockdep case), qemu
only, results in `tmp/mesh-tester-ci/gates-2026-10-05.md`.

## The reviewer after the gates (same day)

- Go on the three pending items: send the Tested-by reply (reply-all, it is test evidence for
  the patch), send the standalone BlueZ leak fix, and compare the other author's power-off fix
  (patchwork 14864878) with ours before sending anything for that bug — on the same base and
  cases (active transmission then power-off; a backlog; power-off, power-on, new send; cancel
  and teardown timing), deciding not on "both pass" but on whether recovery keeps the normal
  ownership and hand-over path or creates a second scheduler path. Prior: the submit approach,
  "only a prior".
- **Command serialization is not data-structure ownership**: running on the command worker
  never granted ownership of `adv_instances`; the redesign must keep the two apart. Do not fold
  the three non-mesh callers into the mesh series (scope); record them separately.
- **Wording for device removal**: "the callback structure permits a lock-order inversion during
  unregister; keeping the teardown entry queued makes lockdep report it deterministically" — not
  "a normal unplug triggers it". v3's removal of that destroy callback supports a rule: a
  destroy callback run by `hci_cmd_sync_clear()` must not do normal scheduler hand-over.
- **Four prerequisites for the core series**: the rejected-enqueue cleanup; mesh locking of the
  advertising list; a deliberate unregister drain policy; no scheduler transitions in
  command-clear callbacks. Then P1–P3 may become cleaner than v3, not v3 plus more fixes.

2026-10-05: the power-off comparison started (results `tmp/mesh-tester-ci/power-off-compare-2026-10-05.md`);
both sends prepared, linted and dry-run (envelopes checked); they wait for the operator's word.

## Where this project's view differs, for the operator

- **`Cc: stable` tags.** The subsystem tags fixes for stable as a matter of course (measured:
  61 of 300 accepted patches, `reviews/2026-09-22T1700Z-kernel-bluetooth-workflow-as-practised.md`
  on `main`); the tag asks for nothing until mainline takes the patch. Keeping the tags on the
  fix patches is normal; what should go is the five-tree text-apply claim in the cover.
- **The `-ECANCELED` path at unregister** removes a request without `hdev->lock` — true, and
  it did so before the series too (the original callback has always called
  `mesh_send_complete()` there). The series neither creates nor fixes it; the cover should say
  that precisely.
