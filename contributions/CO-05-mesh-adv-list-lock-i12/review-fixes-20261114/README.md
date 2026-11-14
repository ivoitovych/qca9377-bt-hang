# CO-05 + CO-26: the 2026-11-14 outside review answered

`../../../reviews/2026-11-14T1400Z-kernel-patches-review-answers-checks.md` §6 holds the review
points.

- **The cover** (`cover-body.txt` and both variants' `0000`) now says the series fixes the mesh
  insertion and capacity-check race, not the lifetime of every advertising instance.
- **CO-26 (patch 0002)** calls itself "a cleanup of the error path", and reviewer 6 notes that its
  `Fixes:` tag invites an automatic stable backport. There are two variants, with identical code;
  0001 and the cover are the same in both:
  - `variant-A-with-fixes/` keeps `Fixes: b338d91703fa`;
  - `variant-B-without-fixes/` drops it.
  
  The operator chooses.
- The test trace in the message is refreshed to `da3cc02587c6`. checkpatch is clean apart from the
  missing Signed-off-by.

**Changed on copy:** `mk-variant.py`, the one-off script that made the variants, stays in the work
area: it carries a placeholder address.
