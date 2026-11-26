# CO-38 recheck after the hardware run: findings and checks (2026-11-26)

The request was `2026-11-26T0800Z-co38-recheck-after-hardware.md`. Reviewers 1, 2, 3 and 6 answered; reviewer 7's
answer may follow. Their full texts are kept privately; this page holds the points, what was checked, and what was
done. Reviewers' points are opinions, weighed against the code and the record.

## Verdicts

| | Reviewer 1 | Reviewer 2 | Reviewer 3 | Reviewer 6 |
|---|---|---|---|---|
| Kernel patch | send | send | send | send after changes (notes) |
| BlueZ test | hold until the fix is in the CI kernel | send after coordination | send; slight preference to wait | send after changes |
| Errors | none | none | none | nothing false; one overclaim by implication |
| linux-kernel not copied | agree | agree | agree | agree (checked with `get_maintainer.pl` on both trees) |

No reviewer found a defect in either diff.

## Points, checks and decisions

1. **The tester sentence is hard to read** (all four).
   - **Problem:** "including mgmt-tester and mesh-tester, which that CI runs for this file" can read as "the CI runs
     all eleven for this file".
   - **Reviewer 2's rewrite is not used.** "Across the eleven testers that the Bluetooth kernel CI runs for mgmt.c"
     is false: the CI runs mgmt-tester and mesh-tester for this file (the bot's own list: only
     `TestRunner_mgmt-tester` and `TestRunner_mesh-tester`).
   - **Done:** two plain statements: "No other case in the Bluetooth kernel CI's eleven testers changed its result
     on any of these kernels; of those, the CI runs mgmt-tester and mesh-tester for this file."
2. **Mesh coverage is implied but absent** (reviewer 6; reviewers 1 to 3 call a mesh test unnecessary).
   - **Checked:** `tools/mesh-tester.c` never sends Read Advertising Features, so no test reads the list while a mesh
     instance exists.
   - **Done:** the notes now say so, with why it stays hidden: "No test has a mesh instance present during the read;
     it stays hidden because its number is le_num_of_adv_sets + 1."
3. **"numbered one past the controller's advertising sets" is inexact** (reviewers 2 and 6).
   - **Checked:** `le_num_of_adv_sets` is the controller's count only with extended advertising; otherwise it is the
     default `HCI_MAX_ADV_INSTANCES` (5). The QCA9377 of the hardware run is such a controller: its reply says
     `max_instances 5`.
   - **Done:** the commit message now says "which is numbered le_num_of_adv_sets + 1". This is the one change above
     `---`. The code and patch-id are unchanged.
4. **The hang, KASAN and lockdep sentences** (reviewer 6: drop them as noise; reviewers 1 to 3 accept them).
   - **Kept.** They tell a maintainer who runs these lines what to expect, and the earlier round asked for exactly
     that.
   - Those reports are registered on their own (BT-26, BT-27, BT-28) for separate mails.
5. **bluetoothd consequence** (reviewer 6).
   - **Checked:** `src/advertising.c:2042-2044` at BlueZ `79162c108911` clears leftover instances at start-up only
     when `num_instances` is non-zero, so a lone instance 2 left from a previous run is not cleared.
   - **Not added** to the message. Reviewer 6 asks for it only after it is seen on hardware, which needs a bluetoothd
     restart on the laptop (the operator's call).
6. **The hardware wording** (reviewer 2: "completes successfully" would be more literal). Kept: "the controller
   accepts LE Set Advertising Enable" already claims only the command status, which all four accept.
7. **BlueZ subject and data names** (reviewer 6: other test commits start with "Add"; `_rsp_3`/`_success_3` would
   match the neighbours).
   - **Not changed now:** preferences, and reviewers 2 and 3 say to retain both.
   - **To decide** before the BlueZ send, which waits anyway (point 8).
8. **BlueZ timing.** Reviewers 1 and 3 prefer, and reviewer 2 suggests, sending the test once the fix is in the
   kernel the BlueZ CI runs. Reviewer 6 would send the same day. **Recommendation: wait**, so the CI is never red
   on a case the tree cannot yet pass. The operator decides.
9. **Dates.** `3a198413bb71` was authored on 2026-11-13 and committed on 2026-11-17 (`git log`: Andrew Morton).
   The records now say both.
10. **Brian Gix's address** (reviewer 2). Reviewer 6 checked it against his latest commits, as the recipients file
    records.

## After the changes (2026-11-26, about 16:00 UTC)

- **checkpatch** `--strict` with the sign-off check: 0 errors, 0 warnings, 0 checks. Every line is within 72
  columns except the diff's own hunk header.
- **Patch-ids:** kernel `a15c80fa459bcaf1a3fa84e9aa447ae1372f8444`, BlueZ `70a4873086000186e05d1bbe88d65a75bc3b9e18`.
  Both unchanged.
- **Applies** to bluetooth-next `f57f78086ab5`, still the tip after a fresh fetch; the BlueZ test applies to master
  `79162c108911`.
- **Dry run** (`git send-email --dry-run`, from the project checkout):
  - "Result: OK";
  - RCPT TO linux-bluetooth, Marcel Holtmann, Luiz Augusto von Dentz, Brian Gix, and stable, the last added from
    the `Cc: stable` trailer;
  - no linux-kernel.
