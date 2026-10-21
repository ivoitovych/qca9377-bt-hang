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
