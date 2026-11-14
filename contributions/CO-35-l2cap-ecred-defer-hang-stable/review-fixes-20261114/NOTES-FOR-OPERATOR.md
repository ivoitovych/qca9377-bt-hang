# Notes for the operator: CO-35 and CO-22 stable items (2026-11-14)

1. **Sanitizer sentence.** No change needed in the covers ("No lockdep or KASAN report"): the kernels had both. Fix the two internal records (`send-20261102/results.md:157`, `send-20261114/CHECKS.md` section 3) with the sentence in `TASK1-sanitizer-record.md`.
2. **CO-35 choice (yours).** Two options, both tested on all four lines with the same result:
   - the full prerequisite `608e0b7a675b` with the exception request (the package as it is), or
   - the reduced prerequisite in `reduced/<line>/0001-...` (49-50 changed lines against 78/149) plus the unchanged patch 2. It is not a mainline commit, so the 7.3.y request would carry it as a patch. Add your own `Signed-off-by` to patch 1 at send time; patch 1 carries the upstream author and sign-off chain only.
   The deviation table (`TASK2-deviation-table.md`) is ready for the covers.
3. **CO-22 mail.** Replace the date sentence with the one in `TASK4-queue-refresh.md`. Redo the check on the send day; the rc branches are ahead of the releases, so a release round is in progress (without our commits).
4. **Not usable:** cgit's subject search on git.kernel.org gave 0 for known subjects; do not rely on it (the file-content checks are in `TASK4-queue-refresh.md`).
