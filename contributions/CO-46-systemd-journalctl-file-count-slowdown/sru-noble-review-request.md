# Review request: an Ubuntu 24.04 stable-update request for two journalctl commits

Below is a request to Ubuntu, not yet filed, to add two upstream systemd commits from v256 to noble's
systemd 255.4. They remove an fstat() on every open journal file for every entry read. The request
consists of:
- the bug text (stable-update template);
- the measurements;
- a reproducer and its reference output;
- the two quilt patches, the debdiff against 8.19, and the same change as a packaging-branch commit.

This is the second revision: the title is neutral, the Test Plan uses a frozen dataset, and the safety
section rests on measurements of the exact packages.

Please review it as the Ubuntu SRU team and the systemd package maintainers would. Hard objections
first, then weaker ones. For each point, say what to change.

## Questions

1. **Does the Impact justify a stable update?**
   - The policy says: "Stable release updates will, in general, only be issued in order to fix
     high-impact bugs." Source: https://documentation.ubuntu.com/project/SRU/reference/requirements/
   - Its "other safe cases" require changes that "affect an application rather than critical
     infrastructure packages"; systemd may count as such a package.
   - Performance is not mentioned.
   - We found no performance-only systemd update in jammy (249.11-0ubuntu3.x) or in noble so far.

   What would the SRU team object to, and what argument or data is missing?
2. **Where problems could occur.** Is anything missing or wrong? In particular:
   - journal files from an older journald, without the `tail_entry_offset` header field;
   - files written while being read (`-f`, the active system and user files);
   - files from systemd-journal-remote;
   - `--merge`, `--file=` on another machine's files, and journal namespaces;
   - libsystemd0 consumers other than journalctl;
   - the new `-EBADMSG` path of the second commit;
   - an archived file that is vacuumed (unlinked, then hole-punched or truncated) while a reader has it
     open. Before, the per-entry fstat() saw that and returned -EIDRM, which the callers ignore or treat
     as "no answer"; after, the mapped header is read. This was measured on disposable fixtures in about
     1 400 runs (bug text, Where problems could occur): both builds behave alike. Upstream later changed
     this area (101b8633c2, "recover iteration over vacuumed files", 2026) without naming these commits;
     it is not included;
   - imported journals whose header machine ID differs from the entries' (upstream ae940730c6 fixes an
     ordering defect there that exists without these commits; not included).
3. **The two patches on 255.4.** Do you see a correctness problem? Are there upstream commits that
   these two need on 255.4 but that are not included? PR #30209 had four more:
   - bd1af1d5fb SD_JOURNAL_ASSUME_IMMUTABLE;
   - f7f062bf9f, its use;
   - cb2b0326ee, Hashmap to array;
   - 63d2c7554e, logs-show reads the timestamp only when needed.
4. **The Test Plan.** Can a verifier who did not write it follow it on an ordinary noble machine? The
   "same output" step now runs on a directory of copies made once (`compare-frozen.sh`), checks exit
   statuses and non-empty output, and compares hashes; is that sound?
5. **The numbers.** The headline is now completed host runs on frozen copies, with a system-call count.
   Is any figure or comparison still misleading? The file-count statement now reads: `SystemMaxFiles=100`
   counts active and archived files together, and the size limits alone keep about 8 to 32 full files;
   is that right? The container figures are kept in the evidence only, as reproducibility information.
6. **The route.** One route is now proposed: a debdiff for `ubuntu-sponsors`, not waiting for 8.19's
   release, with the PPA build and the autopkgtests marked pending. Is that the better first step for an
   outside contributor?

   The test build ran in a container, where two unrelated tests fail with and without the patches.
   Is a build in a Launchpad PPA, on all architectures, expected before the request?
7. **Length and tone.** What can be cut without losing the case?

Below are the files, each under its path.
