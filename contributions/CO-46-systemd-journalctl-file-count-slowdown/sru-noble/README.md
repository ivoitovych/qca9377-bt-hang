# Ubuntu 24.04 (noble): backport of two upstream journalctl fixes, a stable-update request

This directory is self-contained: it is everything the request needs.

**What is asked.** Add two upstream systemd commits from v256 to noble's systemd 255.4:
- `99e6f682d3627c2c06d99bb3c3756e448e8d9bd1` "sd-journal: cache last entry offset and journal file state";
- `51b2bcf8356b847e7ab778adfad930691713c7ef` "sd-journal: make journal_file_read_tail_timestamp() notify to the caller that some new journal entries added".

They remove an fstat() on every open journal file for every entry read. On the host, a full read of 100
journal files takes 83.8 s instead of 907.8 s, and the same query on 25 and 50 files is 5 to 8 times
faster (`evidence.md` section 1).

## Files

| file | what |
|---|---|
| `bug-description.md` | the Launchpad bug: title and description in the stable-update template (Impact, Test Plan, Where problems could occur, Other Info) |
| `evidence.md` | the measurements: completed host runs on frozen copies, the system-call counts, the equivalence and safety checks on the exact packages, file counts at the default limits, earlier rate measurements, container figures (reproducibility only) |
| `reproducer/journalctl-file-scaling-repro.sh` | the reproducer: no root, nothing installed, writes only into one temporary directory |
| `reproducer/compare-frozen.sh` | the frozen-dataset comparison of the Test Plan: fixed queries on a directory of copies, exit status, size and sha256 per query |
| `reproducer/output.txt` | its reference output: stock 8.18 against the patched build, in a fresh ubuntu:24.04 container as an unprivileged user |
| `reproducer/Dockerfile`, `reproducer/inside-repro-test.sh` | how that reference run was made, with its before-and-after check of /var/log, /run/log, /etc/systemd, /tmp and /var/tmp |
| `patches/debian-patches/` | the two commits as quilt patches, headed like the other cherry-picks in noble's series; added at its end |
| `patches/systemd_255.4-1ubuntu8.19_to_8.20.debdiff` | the debdiff against 8.19: the changelog entry, the two patches, `series` |
| `patches/ubuntu-noble-branch-commit.patch` | the same change as one commit on the packaging branch `ubuntu-noble` (head `e9f476fd65`, "Release systemd 255.4-1ubuntu8.19"), for a merge proposal |

`NNNNNNN` stands for the Launchpad bug number. `<AUTHOR-NAME> <AUTHOR-EMAIL>` stands for whoever
submits. Both are filled in, and the patch files renamed, once the bug exists. The
`From: <AUTHOR-NAME> <AUTHOR-EMAIL>` line of `patches/ubuntu-noble-branch-commit.patch` and the
changelog trailer of the debdiff are placeholders on purpose: the submitter's own identity goes
there, so they are not to be replaced by anyone else.

**Test build.** The source package builds with `dpkg-source -b`, and `quilt push -a` applies all 99
patches on 8.19 with no fuzz. The binary build was amd64 only, in an ubuntu:24.04 container:
 - with the tests, every journal test passes;
 - test-fd-util and test-capability fail, and they fail on unpatched 8.19 in the same container too;
 - 1 229 tests pass and 25 are skipped, as they need a booted system.

The packages were then built without tests, installed over 8.18 in a fresh container, and tested
there. The exact packages were compared with stock 8.19 on frozen copies, in a booted noble guest with
journald running, on older-format and imported journals, and with archived files removed under an open
reader; `evidence.md` sections 1 to 3 give the results and where the records are.

**Pending:** a build in a Launchpad PPA on all architectures, and the autopkgtests. Neither has been done;
the bug says so. A PPA build is useful evidence, not a prerequisite to filing.

## Where it goes, and in what order

The state was checked on 2026-11-16:
- noble-updates has 255.4-1ubuntu8.18;
- noble-proposed has 8.19, which does not contain the commits;
- the development release (261.3) and 24.10 to 26.04 contain them;
- upstream's v255-stable does not.

No Launchpad or Debian bug for this exists. Upstream issue #31486 describes a broader scaling problem
with the number of files; these commits remove the system calls only and do not fix it.

1. **One Launchpad bug** on `systemd (Ubuntu)`: the title and the text of `bug-description.md`. Attach
   the reproducer (with `compare-frozen.sh`) and `evidence.md`. Nominate it for Noble.
2. **The change itself, one route:** the debdiff attached to the bug, with `ubuntu-sponsors`
   subscribed. A merge proposal from the same two patches into
   `~ubuntu-core-dev/ubuntu/+source/systemd:ubuntu-noble` is the alternative if the maintainers prefer
   it; it is not needed as well.
3. **Timing:** the bug and the review request do not wait for 8.19's release. The upload is coordinated
   with the pending update; the base version is checked again before it, and the change rebased on
   whatever noble-updates then holds.
4. **After acceptance into noble-proposed:** run the bug's Test Plan on a noble machine, report the
   result in the bug, and set the tag `verification-done-noble`. The update then needs at least 7 days
   in -proposed.

Out of scope, on purpose:
- upstream's later changes in this area (8f8ab4bf98, v262; 79e32e7c73, unreleased), which are not
  in the development release;
- 101b8633c2 (recover iteration over vacuumed files) and ae940730c6 (prefer the machine ID from the tail
  entry, v262): separate upstream changes; neither build compared here has them, and the two commits behave
  as stock does in the cases they address (`evidence.md` sections 2 and 3);
- a change to the per-entry merge itself, which is upstream work (#31486).
