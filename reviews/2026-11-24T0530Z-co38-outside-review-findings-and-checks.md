# CO-38 outside review: five answers, checked (2026-11-24)

**The request:** `2026-11-24T0448Z-co38-for-outside-review.md`. Reviewers 1, 2, 3, 6 and 7 answered. The
full texts are kept privately; findings only here. They are opinions to weigh.

**Verdicts:**
- **Kernel patch:** send as is (1, 2, 3) or after one wording change (6, 7).
- **BlueZ test:** send (2, 6, 7), or send with a note on the merge order (1, 3).
- **Code:** no reviewer asked for a change in either diff.
- **What the reviewers checked themselves:**
  - the predicate against all three add paths, the mesh numbering and the buffer arithmetic;
  - that the blocks apply, with matching patch-ids (6, 7);
  - that `b338d91703fa` introduced the comparison (6, 7);
  - that an unfixed kernel fails the test on length, 8 bytes against 9 (6).

## Findings, checks and decisions

| # | finding | who | check | decision |
|---|---|---|---|---|
| 1 | "and no Advertising Removed event says so" collides with the event that *is* emitted, for instance 1, when its timeout clears it | 6, 7 (2) | right: `hci_sync.c:2307`, `:2429` and `:2453` emit `mgmt_advertising_removed()` for the removed instance | clause dropped; the sentence ends "but no longer reported." Reviewer 1 would keep it |
| 2 | "With this patch alone" hints at a second patch the reader has not seen | 6 | right | "alone" dropped |
| 3 | "sent to BlueZ separately" is wrong in tense, since the kernel mail goes first | 7 | right | "submitted to BlueZ separately" |
| 4 | "no other case changed": some suites hung on older lines, so only the observed cases can be compared | 7 | right: the 6.18, 6.12 and 6.6 l2cap runs and the 6.12 iso run stop at a hang, identically on both sides | "no other observed case changed" |
| 5 | The BlueZ mail should carry the kernel patch's lore link, and ask that the test be applied once the CI kernel has the fix. Below `---` (2, 3, 6, 7) or in the body (1) | all 5 | fits R-6 and the CI fact (mgmt-tester runs from BlueZ master) | added below `---`, with a placeholder `<LORE-LINK-OF-THE-KERNEL-PATCH>` to fill on the send day |
| 6 | Recipients: To linux-bluetooth, Cc Marcel Holtmann and Luiz Augusto von Dentz; omit linux-kernel | 1, 2, 7 (3, 6: optional) | `submitting-patches.rst`: LKML is the fallback when there is no subsystem list | linux-kernel omitted |
| 7 | Brian Gix (author of `b338d91703fa`): Cc him (2, 7), if the address is live (3, 6), optional (1) | 1–7 | his last kernel commit is 2023-03-06, with a gmail address; the address `get_maintainer.pl` gives is the older Intel one. No post to the list in our archive since | **the operator's call**: the gmail address, or none |
| 8 | Keep `Cc: stable` | all 5 | the address-type revert broke bluetoothd by rejecting commands it sent; this only lists IDs Add Advertising already accepts (1, 7) | kept |
| 9 | Leave the bluetoothd restart consequence out | all 5 | — | left out |
| 10 | Keep the parameterized setup helper | all 5 | — | kept |
| 11 | "instance 2 is still advertised" → "remains configured" | 3 (7 similar) | with instance 1 gone, instance 2 *is* the one being advertised, so "still advertised" is true | kept |
| 12 | Rewrite the body around the lone-instance example | 7 | others keep the structure (1, 3, 6); the body already gives the lone case in its third paragraph | not taken |
| 13 | Tag the kernel mail `[PATCH bluetooth]` and base it on the `bluetooth` fixes tree, so it can make 7.4 | 1 | not linux-bluetooth practice. The list archive since 2026-09-01 has **no** mail tagged `[PATCH bluetooth`; the kernel patches there are tagged `[PATCH]`, `[PATCH vN]` or `[PATCH n/m]` (`git log --since=2026-09-01 -i -E --grep='^\[PATCH bluetooth'` on the archive: no output). The maintainer picks the tree. (A first draft of this row cited commit subjects, which cannot show the mail's tag, because `git am` strips it.) | not taken; the maintainer decides the tree |
| 14 | Double space before the brace in `read_adv_features_rsp_instance_2[] =  {` | 3 | the neighbouring arrays in `mgmt-tester.c` use the same double space (`read_adv_features_rsp_2[] =  {`, l.5170) | kept, to match the file |
| 15 | A mesh-boundary test (a public and the mesh instance together) would cover the else branch | 1, 3, 6 | right: no run exercises it | **later**, not before the send (follow-up) |
| 16 | The old code could expose the mesh instance when all sets plus mesh exist | 3 (conditional) | unreachable: `mesh_send_sync()` adds the mesh instance only while the count is below the number of sets (6) | nothing to claim |
| 17 | Two slips in the review document: "duration" for timeout, and the source of the 5 instances | 2, 6, 7 | right: `HCI_MAX_ADV_INSTANCES` = 5 (`hci_core.h:277`) | corrected in the document's closing section |

**After the changes:**
- The kernel patch-id is unchanged (`a15c80fa459b`), checkpatch `--strict` is clean, and the patch applies to
  bluetooth-next `ffb95458a0f7`.
- The BlueZ patch-id is unchanged (`70a487308600`), and the patch applies to BlueZ master `1608f8361886`.
- The new file SHA-256s are `2468299c…` for the kernel patch and `73ac450e…` for the BlueZ patch.
