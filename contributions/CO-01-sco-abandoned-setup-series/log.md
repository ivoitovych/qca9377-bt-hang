# CO-01 log

Append-only. Newest last.

## 2026-10-20 — found
While checking the trackers for the contribution list, BlueZ #2562 led to the series.
- **Patchwork:** 14875449 to 14875454 are `new`, with only the bot's comment on 1/6.
- **Cover letter:** read from patchwork's record of cover 14157860; lore refused every
  request that night.

The series became CO-01.

## 2026-10-21 — reviewer 1 and the diffs
- **Reviewer 1:** patch 6 is orthogonal to U7. No behaviour change is expected on the
  sequences we hold. A hardware Tested-by needs two concurrent links.
- **Read here:** patches 2 and 4 from patchwork (14875450, 14875452). They guard
  `hci_sco_setup()`, `hci_enhanced_setup_sync()` and the completion events, and do not touch
  `hci_connect_sco()`'s lookup.
- **Full record:** `reviews/2026-10-21T0009Z-source-investigation-reviewer-1.md`.

## 2026-10-21 — dossier opened

## 2026-10-21 — reviewers 2, 3 and 4 on patch 6 and its test
- **All three:** the series is not the U7 fix (CO-02). Patch 6 matters on this laptop, which
  uses the legacy setup.
- **A meaningful hardware test** (reviewers 3 and 4):
  - keep SCO link A carrying audio;
  - make link B's setup fail or be abandoned;
  - record B's failed completion, the notifications, the SCO count and the chosen USB alt;
  - A must stay up.
- **The negative control:** two established links, then one hung up. That is the remaining
  defect, now confirmed in source (CO-21).
- **The limit:** if the controller cannot hold two links, the multi-link coverage cannot be
  claimed.
- **Full record:** `reviews/2026-10-21T0033Z-source-investigation-reviewers-2-4.md`, RV3.
