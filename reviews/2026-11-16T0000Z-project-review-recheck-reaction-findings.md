# The whole-project review of 2026-11-15: the findings of the reviewer's recheck

*Received 2026-11-16 (relayed by the operator). The reviewer of the whole-project review
(`162d3b9`) rechecked every finding on `main` at `a8d0eb45` and wrote the result to a separate
branch as commit `3f8e8f62` (two files: the recheck summary and a detailed companion). This page
keeps the findings of the message that came with it (2026-11-16: public files keep a review's
content, not its running commentary). What we checked, point by point, is in
`2026-11-16T0000Z-project-review-recheck-checks.md`.*

---

Every finding was looked up again on `main` at `a8d0eb45`, 26 commits after the review; files
were read, and nothing was run except the read-only `scripts/send-table-check.py`.

## Result

| severity | fixed | partly | not addressed | waits for the operator's decision |
|---|---|---|---|---|
| High (15) | 7 | 5 | 0 | 3 |
| Medium (49) | 13 | 16 | 19 | 1 |
| Low (19) | 7 | 5 | 7 | 0 |
| **all (83)** | **27** | **26** | **26** | **4** |

Two corrections to the review itself: the pinned commit in the Tested-by mail does exist (the
review's clone was too shallow), and the `<AUTHOR-EMAIL>` placeholder was in 20 files, not 17.

- **What to send:** solved in the main. One table names each package's directory, a script checks it, and replaced directories are marked. Still open:
  - The index rows below the table and `contributions/rd-2026-11-14.md` still name the replaced directories.
  - The CO-35 row points at a directory that lacks the request, covers and backports.
  - The CO-02 candidate has a three-patch cover for a two-patch series.
- **Unsafe code:** `uninstall.sh`, `runtime-mgmt-test.sh` and the option loops are fixed. The archive guard still misses one case: an older archive made with a different compressor is deleted without a record count.
- **Clean answers without looking:** about half fixed (identity gate, SCO ledger, `bt-diagnose`, trial reports, mail check). About fifteen scripts and twenty-three test assertions are unchanged.
- **Drift between documents:** `README.md`, the named STATUS rows and the BRIEF table now agree. The dossier front pages, `docs/issues.md` sections, `patches/*/README.md`, `reviews/README.md`, `HISTORY.md` and the exhibits index were not touched. BRIEF now contradicts itself in four new places.
- **Wording of the review's section 3.2:** unchanged, recorded on `main` as waiting for the operator's decision. One more such file was committed since (`comms/2026-11-15T2010Z-…`). No scan pattern exists yet.

Eleven new items came with the fixes, none high. The ones worth acting on first:

- **SCO ledger:** it probably now reports a boot with no calls as unreadable and fails the multi-boot count. This is from reading the code; it needs one run on the laptop to confirm.
- **Module-swap test:** a new test calls `runtime-mgmt-test.sh load` for real and relies on the refusal it is testing.
- **Identity test switch:** the test switch for the identity gate still has gaps (it ignores `pushurl`, and passes in another local clone).

The recheck has a numbered list of what is left, in suggested order, with file and line for
each item, and a section comparing it with the record on `main`. Line numbers are those of
`a8d0eb45`.
