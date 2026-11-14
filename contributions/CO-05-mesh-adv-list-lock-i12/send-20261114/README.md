# CO-05 + CO-26 refreshed on bluetooth-next da3cc02587c6 (2026-11-14; nothing sent)

Copied from `/root/exp/agent-work/lane3-mgmt-20261114/CO-05-26/`; `CHECKS.md` has every command
and result. The send files are `patch/0000` to `0002` (cover letter and two patches), authored
"Iaroslav Voitovych", **without Signed-off-by**. The code is identical to 10-29; the cover letter
is rewritten with today's numbers and one fact about Cen Zhang's overlapping patch (14927631: it
also takes `hdev->lock` in `mesh_send_sync()`, no longer applies to bluetooth-next; if it lands,
1/2 becomes redundant).

- With a test-only `lockdep_assert_held()` in `hci_add_adv_instance()`: mesh-tester warnings 3 per
  boot without the series, 0 with it; the other callers' 4 warnings unchanged, as on 10-29.
- CO-26 fault injection (first mesh add fails with -ENOMEM): base returns -2 after scheduling a
  never-added instance; patched returns -12 and schedules nothing.
- KCSAN, 45 boots per image: no report in advertising or mesh code on any image, base included;
  the 10-29 base reports (4 of 45) did not reproduce, so today shows no before/after (the cover
  letter says so).
- The bot, patched side: all checks pass; mgmt-tester 526/526, mesh-tester 10/10.

**Left in the work area:** images, the bot's large logs, the intermediate `patch-next-bare/`, and
the saved patchwork and lore copies of other people's postings.
