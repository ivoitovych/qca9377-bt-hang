# Ubuntu 24.04 (noble): backport of two upstream journalctl fixes, a stable-update request

This directory is self-contained: it is everything the request needs.

**What is asked.** Add two upstream systemd commits from v256 to noble's systemd 255.4:
- `99e6f682d3627c2c06d99bb3c3756e448e8d9bd1` "sd-journal: cache last entry offset and journal file state";
- `51b2bcf8356b847e7ab778adfad930691713c7ef` "sd-journal: make journal_file_read_tail_timestamp() notify to the caller that some new journal entries added".

They remove an fstat() on every open journal file for every entry read. On a 24.04 machine they make
reading the journal 7 to 25 times faster.

## Files

| file | what |
|---|---|
| `bug-description.md` | the Launchpad bug: title and description in the stable-update template (Impact, Test Plan, Where problems could occur, Other Info) |
| `evidence.md` | the measurements: host and container, synthetic files and a real journal, everyday queries, the same-output checks |
| `reproducer/journalctl-file-scaling-repro.sh` | the reproducer: no root, nothing installed, writes only into one temporary directory |
| `reproducer/output.txt` | its reference output: stock 8.18 against the patched build, in a fresh ubuntu:24.04 container as an unprivileged user |
| `reproducer/Dockerfile`, `reproducer/inside-repro-test.sh` | how that reference run was made, with its before-and-after check of /var/log, /run/log, /etc/systemd, /tmp and /var/tmp |
| `patches/` | [OPEN: the two DEP-3 quilt patches, the changelog entry, the debdiff and the packaging-branch commit; in preparation] |

## Where it goes, and in what order

The state was checked on 2026-11-16:
- noble-updates has 255.4-1ubuntu8.18;
- noble-proposed has 8.19, which does not contain the commits;
- the development release (261.3) and 24.10 to 26.04 contain them;
- upstream's v255-stable does not.

No Launchpad or Debian bug for this exists. Upstream issue #31486 is about the remaining growth with
the number of files, not about these commits.

1. **One Launchpad bug** on `systemd (Ubuntu)`: the title and the text of `bug-description.md`. Attach
   the reproducer and `evidence.md`. Nominate it for Noble.
2. **The change itself**, one of the following:
   - a merge proposal from a branch carrying the two patches and a changelog entry
     (`LP: #<bug>`) into `~ubuntu-core-dev/ubuntu/+source/systemd:ubuntu-noble`, with
     `canonical-foundations` as reviewer. Recent noble systemd updates used this route;
   - or a debdiff attached to the bug, with `ubuntu-sponsors` subscribed.
3. **Timing:** the next upload after 8.19. If 8.19 is still in -proposed, base the change on 8.19,
   which is the packaging branch's head.
4. **After acceptance into noble-proposed:** run the bug's Test Plan on a noble machine, report the
   result in the bug, and set the tag `verification-done-noble`. The update then needs at least 7 days
   in -proposed.

Out of scope, on purpose:
- upstream's later changes in this area (8f8ab4bf98, v262; 79e32e7c73, unreleased), which are not
  in the development release;
- a change to the per-entry merge itself, which is upstream work (#31486).
