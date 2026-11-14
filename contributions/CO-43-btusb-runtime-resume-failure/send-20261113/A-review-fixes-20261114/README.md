# CO-43 A after the 2026-11-14 outside review

This patch replaces `../A/0001-…` for the send
(`../../../../reviews/2026-11-14T1400Z-kernel-patches-review-answers-checks.md` §3):
- **The message** gives the order of events as measured: the HCI command times out while the waker
  is still waiting, and the failed resume is logged when the PM request returns. This is reviewer
  7's wording. It replaces "then ends in a command timeout two seconds later", which had the order
  reversed.
- **The new line** is rate-limited with `bt_dev_err_ratelimited()` (reviewers 6 and 7).
- **Emulator, dead device:**
  - the base kernel logs no "Failed to resume device for deferred data" line;
  - the patched kernel logs two, both `-16`;
  - in the patched run, `command 0x0c24 tx timeout` comes at 10.09 s, then the line at 15.24 s
    (`CHECKS.md`; checked on copy in the raw guest log).
- **Bot:** GitLint flagged an over-long line in the test note below `---`. It is rewrapped, and
  the bot was not run again.
