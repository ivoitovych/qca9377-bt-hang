# Phase 3 — make the mesh fix correct for extended advertising, split it, test both paths

**Private until sent.** Follows `phase1-findings.md`, `phase2-results.md` and the outside
review of 2026-10-02, whose findings were checked here against the source and hold.

## What the review found, verified in the tree (`bluetooth-next` 671d566d3c3b)

1. **Extended advertising is not handled (blocker).** The kernel removes an advertising set
   as: disable the set → `HCI_OP_LE_REMOVE_ADV_SET` → on Command Complete
   `hci_cc_le_remove_adv_set()` takes `hdev->lock`, calls `hci_remove_adv_instance()` and
   emits `mgmt_advertising_removed()` (`hci_event.c:1467-1492`). Our patch calls
   `hci_remove_adv_instance()` *first*; `hci_remove_ext_adv_instance_sync()` then fails
   `-EINVAL` at `hci_find_adv_instance()` (`hci_sync.c:2044`), so no set is removed, and
   when another advertiser exists `list_empty()` is false and nothing disables the mesh set.
   `hci_disable_advertising_sync()` on an ext-adv controller disables **all** sets (instance
   `0x00`, `hci_sync.c:2278`) — acceptable only when the mesh set is alone.
2. **Nothing hides the mesh instance from MGMT.** `adv->mesh` is set (`hci_core.c:1720`) and
   read nowhere; `mgmt_advertising_removed()` (`mgmt.c:1288`) emits for any instance. A fix
   that goes through the ordinary ext-adv removal would announce the internal mesh instance
   to userspace as `MGMT_EV_ADVERTISING_REMOVED` — a new event userspace never saw.
3. **"1000 seconds" is legacy-only.** On the ext-adv path `u16 duration = adv->timeout *
   MSEC_PER_SEC` (`hci_sync.c:1673`) truncates 1,000,000 to 16,960 → `duration/10` = 1696 →
   the controller stops the set after 16.96 s. A separate defect; not for this series, but
   the commit message must not claim 1000 s generally.
4. **Coverage gap.** Every mesh test uses `HCIEMU_TYPE_BREDRLE` (legacy); the
   `test_bredrle50` macro (`tools/mesh-tester.c:521`) exists and is used by no test. The
   10/10 result says nothing about extended advertising.
5. **Two bugs, two provenances** → a two-patch series: 1/2 teardown (`Fixes: f3cb5676e5c1`,
   `Cc: stable`), 2/2 completion of the transmission on air (`Fixes: b338d91703fa`; its
   stable range to be reasoned separately — it may depend on `71af682ba469`'s cancellation
   state machine).
6. Locking (B1), the expiry-work race (B2), the instance-match completion (B4) and the
   interaction with `71af682ba469` on current mainline (B5) were reviewed and hold; keep
   them, and add a comment at the match explaining why the instance identifies the sent
   request (every send uses the same instance number; only the one on air carries it).

## The work

**A. Patch 1/2 — stop the mesh advertiser correctly on both paths.** Design the teardown so
that, when a mesh transmission is done (count exhausted or cancelled):
- legacy: remove the mesh instance from `adv_instances`, then disable advertising only if
  no other instance remains (the current patch);
- extended: disable the mesh set specifically and remove it with
  `HCI_OP_LE_REMOVE_ADV_SET`, **without** `MGMT_EV_ADVERTISING_REMOVED` — e.g. a core helper
  that removes an internal instance (one with `adv->mesh`) and suppresses the event in
  `hci_cc_le_remove_adv_set()` / `hci_remove_adv_sync()` when `adv->mesh` is set, or an
  explicit internal-set lifecycle; choose the smallest change that a maintainer would
  accept, and say in the message why the event is suppressed;
- other advertisers keep running in both cases (the coexistence `f3cb5676e5c1` protected).

**B. Patch 2/2 — complete the transmission that was on air** (the `->instance` match), with
the comment from item 6, and a commit message that states the MGMT semantics it restores
(handle of the transmitted packet; cancel of the in-flight handle must not complete the
next, unsent one).

**C. Tests, in BlueZ `tools/mesh-tester.c` (a BlueZ patch of its own, to go with the series
or just after):**
- the existing Send / Send cancel cases duplicated as `test_bredrle50` variants;
- a coexistence case: an ordinary advertising instance active, a mesh send completes, the
  mesh set stops/is removed, the ordinary instance remains (on both emulator types);
- queue semantics: two sends, cancel the active one; two sends, cancel the queued one;
  cancel-all; a normal first completion then the second send — asserting the **handles** in
  the completion events, not only pass/fail;
- assert that no `MGMT_EV_ADVERTISING_REMOVED` arrives for the mesh instance.

**D. Runs** (qemu only, as in phase 2): unpatched and patched, `mesh-tester` on BREDRLE and
BREDRLE50, KVM and TCG+valgrind, ASAN tester; full `mgmt-tester`; repeated runs (≥5) of the
cancel cases to exercise timer ordering. Record in `phase3-results.md` after every step.

**E. Hygiene:** base the series on the **`bluetooth`** fixes tree (`cache/linux` remote
`bluetooth`), then check it applies and behaves on `bluetooth-next`; checkpatch `--strict`,
W=1, sparse (`scripts/kernel-preflight.sh` on a full tree with HEAD = the patch); recipients
by `scripts/get-maintainers.sh`. Commit messages narrow: "on the legacy advertising path
the stale instance stays scheduled for 1000 s"; "every kernel patch on the list since
2026-06-01 carries the same 8/10 signature" (not "every red check").

**F. The duration overflow** (item 3): write it up as a separate finding with its own
reproducer plan; do not fold it into the series.

## Constraints (unchanged)

Never touch the host's Bluetooth or kernel; everything under `cache/` and
`tmp/mesh-tester-ci/`; post nothing; author
Iaroslav Voitovych <yaroslav.voytovych@gmail.com>.
