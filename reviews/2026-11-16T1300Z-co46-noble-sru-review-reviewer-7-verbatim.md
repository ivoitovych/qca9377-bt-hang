# CO-46 noble stable-update request: reviewer 7's answer

*Received 2026-11-16 ~13:00 UTC, relayed by the operator. The package reviewed is
`contributions/CO-46-systemd-journalctl-file-count-slowdown/review-package.md` (main `229eb8c`).
Kept as received. What we checked, point by point, will be in
`2026-11-16T1300Z-co46-noble-sru-review-checks.md`.*

---

Worked for 3m 1s

Verdict: this is worth pursuing as a Noble SRU, but I would revise the request before calling it upload-ready. I found no demonstrated correctness defect in the two-commit selection. The main weaknesses are the verification procedure, several overstated safety claims, and the presentation of the measurements.

I reviewed the supplied package, upstream commits and relevant v255.4 code. I did not independently rebuild the Ubuntu packages or reproduce the reported timings.

1. The output-equivalence test is not reliable as written.

   Test Plan step 4 repeats a glob over the live journal directory. Between runs, rotation can add files and vacuuming can remove files. --until fixes a timestamp boundary; it does not fix the input file set. Likewise, live --list-boots output can legitimately change.

   There is also a false-pass possibility: without checking journalctl's exit status, two failed or partial exports can produce matching hashes.

   Change: make independent copies of a fixed set of archived files into a test directory, record their filenames and checksums, and use that directory for both versions. Use copies, not hard links: vacuuming can deallocate the original inode. Require successful exports and nonempty expected output before comparing hashes. Compare --list-boots on that same frozen dataset.

2. The archived-file safety argument needs correction and a targeted test.

   The statement "Archived files cannot change, so the risk is limited to the active system and user journal files" is too strong. v255.4's vacuum implementation calls unlinkat_deallocate(). An already-open reader can therefore encounter more than a missing pathname.

   The later vacuum-recovery commit 101b8633c2 specifically handles failures after an entry has already been selected.

   This does not establish that your backport introduces that bug or requires that later commit. The old per-entry fstat() was not a complete race barrier either. However, removing it changes when deletion is detected, so dismissing the interaction is unjustified.

   Change: compare unpatched 8.19 against 8.19 plus these two commits while a reader is open and archived files are vacuumed. Exercise ordinary unlinking and deallocation/truncation, forward and reverse iteration. Record errors and whether iteration continues through surviving files. Run this on disposable fixtures or a VM.

   The stat_verify_linked() patch still checking for deletion does not resolve this question: a check's continued existence does not establish that it is reached at the same time.

3. The two-commit scope looks appropriate, but the dependency claim needs narrower wording.

   Upstream PR #30209 contains these as its first two consecutive commits. The second directly follows the first. The immutable flag, its callers, the container change and output optimization come afterward. I found no dependency requiring those four later commits for the proposed pair.

   Two explanations should nevertheless change:

   - -EBADMSG: this is not a general detector for a tail entry rewritten at the same offset. The earlier offset-equality check already returns before reading the entry in the ordinary path. The later consistency check matters when fallback processing has recovered or substituted an offset. Describe that actual control flow.
   - "No later upstream commit fixes them": searching commit messages for hashes and Fixes: trailers cannot prove this. State that no required follow-up was identified in the inspected history, and document relevant later changes separately.

   There is another relevant follow-up missing from the discussion: ae940730c6, "prefer machine ID from the tail entry". It fixes remote-journal ordering because imported files can have the receiver's machine ID in their headers while entries contain the originating machines' IDs.

   That defect predates your proposed changes, so I would not automatically add the fix. But document whether the "two machine IDs" fixture varies header IDs, entry _MACHINE_ID fields, or both. Merely changing exported _MACHINE_ID values does not establish coverage of the different-header-machine ordering branch. Matching the old output proves equivalence, not necessarily correct ordering.

4. The performance evidence is persuasive, but some claims exceed what was measured.

   Claim or measurement	Assessment and change

   Host throughput improvements	Keep these as the main evidence. They make a strong case.
   "28 minutes" and "33 minutes"	These are extrapolations from capped runs. Keep them explicitly labelled estimates, or replace them with completed measurements on a frozen subset.
   -b produces 4.5 million lines, -k -b produces 5 million	A growing journal can explain this, as disclosed, but the comparison invites questions. Use one frozen input set for headline results.
   "A container makes each system call dearer"	Unsupported as a general causal claim. Say the baseline was slower in this container setup; the cause was not isolated.
   Fitted complexity exponents	These infer full-read cost from capped or prefix throughput. They are not measurements of complete-read scaling. Remove them from the SRU argument or label them explicitly as estimates.
   "At least 5×" verification threshold	Reasonable as an observed expectation, but not a universal requirement across machines. Pair timing with a structural check that the per-file/per-entry syscall pattern disappears.


   Also publish the non-sensitive raw timing and syscall-summary records, including exact commands and termination conditions. They need not contain journal messages.

   Keep container results in the evidence attachment as reproducibility information. They should not compete with the host measurements in [Impact].

5. The default-file-count statement is slightly wrong.

   SystemMaxFiles=100 limits the total number of journal files counted by that vacuum operation, including active files. Only archived files are eligible for deletion, which can prevent enforcement of the limit. It does not mean an allowance of 100 archived files plus active files.

   This is explicit in both the v255.4 documentation and the vacuum calculation:

   left = n_active_files + n_list - i;

   Change: describe 25–100 files as a relevant range within the default file-count limit, without implying that a typical installation necessarily accumulates that many. Disk-space and retention limits also matter.

6. The impact can justify consideration, but acceptance is not automatic.

   Ubuntu's policy gives examples of high-impact bugs; it does not categorically exclude performance bugs. However, the "obviously safe application fix" provision is a poor argument here because the change reaches shared journal-reading code in a critical infrastructure package. Frame this as materially impaired log retrieval and diagnosis.

   Your strongest evidence is a concrete diagnostic task becoming practical again—not the largest multiplier.

   Change: lead with one completed, reproducible host example, then the 25/50/100-file results, the syscall mechanism, and the narrow upstream fix. Keep the customized 479-file machine as additional evidence. Not finding a previous performance-only systemd SRU is not evidence that this one is ineligible.

   Before upload readiness, I would want this focused coverage:

   Area	Evidence needed

   Active journald	A booted Noble system; uniquely numbered messages observed through append and rotation, checking omissions and duplicates
   Archived-file lifecycle	The vacuum/deallocation comparison described above
   Older journal format	A valid fixture lacking tail_entry_offset, exercising its fallback path
   Imported and merged journals	Explicit header/entry machine-ID distinctions and overlapping boot ranges
   Exact proposed package	Performance and correctness comparison against unpatched 8.19, with build/test logs


   The reported remote-writer follow test and export comparisons are useful. They do not replace these particular cases.

7. The submission route is sound; simplify it and avoid unnecessary prerequisites.

   Both a debdiff and a merge proposal are supported routes. The standard SRU instructions direct outside contributors to request ubuntu-sponsors involvement for either route; requesting a package-maintainer review can accompany that.

   My recommendation is:

   - File one corrected Launchpad bug and attach the evidence and reproducer.
   - Use one primary patch-review route. A debdiff is sufficient; a packaging-branch MP is convenient if that is the maintainers' established workflow.
   - Do not wait for 8.19's release merely to open the bug or request review. Coordinate the eventual upload with the pending update and recheck the base version.
   - An all-architecture PPA build is useful evidence, not a universal prerequisite to filing the request. A successful build with tests enabled in a suitable Noble environment would strengthen this substantially. Preserve the stock-versus-patched evidence for the two container failures.
   - Describe autopkgtests as pending until actual results exist.

   I confirmed the 8.19 acceptance announcement, but could not independently confirm its current publication status through Launchpad.

For length and tone: shorten the bug body, retain the detailed evidence attachment, and use a neutral title such as "journalctl performs excessive per-file stat calls when reading multi-file journals." Avoid implying that issue #31486 is completely fixed; it describes a broader scaling problem.

My disposition: request changes to the verification and risk sections; retain the two-patch scope provisionally. The performance benefit merits a maintainer discussion. The outstanding work is to make the safety case as convincing as the speed measurements.
