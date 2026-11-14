# CO-20 patch 1 alone (2026-11-14)

All five outside reviewers say patch 1 can go alone and patch 2 should wait
(`../../../reviews/2026-11-14T1400Z-kernel-patches-review-answers-checks.md` §10).

- **Patch 1** ("Report SCO receive failures by cause") is a standalone mail on bluetooth-next
  `da3cc02587c6`. Its code is unchanged from the package.
  - **rx-cycles, 3 runs** (`logs/co20.txt`, `CHECKS.md`): base logs "corrupted SCO packet" 21, 21
    and 24 times; patch 1 logs none, and "unknown handle dropped" (rate-limited) 19, 10 and 15
    times.
  - **The bot:** passes, but for the missing Signed-off-by.
- **Patch 2 is held.** `NOTES.md` records the reviewers' two options without implementing either:
  - a bounded record of recently closed handles, taken from the core;
  - or call the classification a heuristic, and keep `err_rx` as it is.
