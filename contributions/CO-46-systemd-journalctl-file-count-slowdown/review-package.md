# Review request: an Ubuntu 24.04 stable-update request for two journalctl commits

Below is a request to Ubuntu, not yet filed, to add two upstream systemd commits from v256 to noble's
systemd 255.4. They remove an fstat() on every open journal file for every entry read. The request
consists of:
- the bug text (stable-update template);
- the measurements;
- a reproducer and its reference output;
- the two quilt patches, the debdiff against 8.19, and the same change as a packaging-branch commit.

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
   - an archived file that is vacuumed (unlinked) while a reader has it open. Before, the per-entry
     fstat() saw that and returned -EIDRM, which the callers ignore or treat as "no answer"; after,
     the mapped header is read. Upstream later changed this area (101b8633c2, "recover iteration over
     vacuumed files", 2026) without naming these commits.
3. **The two patches on 255.4.** Do you see a correctness problem? Are there upstream commits that
   these two need on 255.4 but that are not included? PR #30209 had four more:
   - bd1af1d5fb SD_JOURNAL_ASSUME_IMMUTABLE;
   - f7f062bf9f, its use;
   - cb2b0326ee, Hashmap to array;
   - 63d2c7554e, logs-show reads the timestamp only when needed.
4. **The Test Plan.** Can a verifier who did not write it follow it on an ordinary noble machine? Is
   the "same output" step (a hash of `-o export` over the archived files with `--until`) sound, or can
   archived files change between the two runs?
5. **The numbers.** Is any figure or comparison misleading? Is the statement about default installs
   right: `SystemMaxFiles=100`, so up to about 100 archived files plus the active ones? Should the
   container figures be dropped entirely?
6. **The route.** Is a merge proposal against `ubuntu-noble` or a debdiff for `ubuntu-sponsors` the
   better first step for an outside contributor? Should it wait until 8.19 is released?

   The test build ran in a container, where two unrelated tests fail with and without the patches.
   Is a build in a Launchpad PPA, on all architectures, expected before the request?
7. **Length and tone.** What can be cut without losing the case?

Below are the files, each under its path.


## `README.md`

```
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
| `patches/debian-patches/` | the two commits as quilt patches, headed like the other cherry-picks in noble's series; added at its end |
| `patches/systemd_255.4-1ubuntu8.19_to_8.20.debdiff` | the debdiff against 8.19: the changelog entry, the two patches, `series` |
| `patches/ubuntu-noble-branch-commit.patch` | the same change as one commit on the packaging branch `ubuntu-noble` (head `e9f476fd65`, "Release systemd 255.4-1ubuntu8.19"), for a merge proposal |

`NNNNNNN` stands for the Launchpad bug number. `<AUTHOR-NAME> <AUTHOR-EMAIL>` stands for whoever
submits. Both are filled in, and the patch files renamed, once the bug exists.

**Test build.** The source package builds with `dpkg-source -b`, and `quilt push -a` applies all 99
patches on 8.19 with no fuzz. The binary build was amd64 only, in an ubuntu:24.04 container:
 - with the tests, every journal test passes;
 - test-fd-util and test-capability fail, and they fail on unpatched 8.19 in the same container too;
 - 1 229 tests pass and 25 are skipped, as they need a booted system.

The packages were then built without tests, installed over 8.18 in a fresh container, and tested
there; see `evidence.md` §5.

No build was made on other architectures or in a PPA, and the autopkgtests were not run.

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
```


## `bug-description.md`

```
# Launchpad bug: title and description

Package: systemd (Ubuntu). Series task: Noble. Tag: `noble`.

**Title:**
journalctl is 7-25 times slower than needed on journals with many files (fixed upstream in v256)

---

[ Impact ]

On noble's systemd 255.4, reading the journal costs one fstat() on every open journal file for each
entry printed. `journal_file_read_tail_timestamp()` re-checks each file's tail through fstat() and the
file's mtime on every step of the merge across files. With 100 journal files open, journalctl makes
about 478 system calls per printed line. This also affects every other reader that uses the same
sd-journal code.

Upstream fixed the system calls in v256 with two commits from https://github.com/systemd/systemd/pull/30209:

 - 99e6f682d3627c2c06d99bb3c3756e448e8d9bd1 "sd-journal: cache last entry offset and journal file state"
 - 51b2bcf8356b847e7ab778adfad930691713c7ef "sd-journal: make journal_file_read_tail_timestamp() notify to
   the caller that some new journal entries added"

The file's state and tail-entry offset are read from the header, which is always mapped, instead of
calling fstat(). An archived file whose tail has been read is not checked again. With the two commits
the system calls per printed line fall from about 478 to 0.1 (100 files).

Both commits are in every upstream release since v256, and in Ubuntu since 24.10. They are not in
noble, in noble-proposed (8.19) or in upstream's v255-stable. They apply to 255.4-1ubuntu8.18
unchanged.

Measured on a 24.04.5 machine (Ryzen 7 5825U, NVMe, ext4), with the binaries run on the host, not in a
container. "lines/s" is journalctl's output rate. "Synthetic" means archived files of 2 000 entries
each. "Real" means the newest K files of that machine's own journal, read with --file=. Median of 3
runs.

  files   synthetic, 8.18 -> patched   real journal, 8.18 -> patched
     25      19 218 ->  178 586 ( 9x)       29 194 -> 201 342 ( 7x)
     50       8 269 ->  123 012 (15x)       19 438 -> 190 355 (10x)
    100       4 563 ->   84 104 (18x)       11 361 -> 133 097 (12x)
    200       1 395 ->   34 043 (24x)        5 847 -> 119 474 (20x)
    400         633 ->   13 787 (22x)        2 885 ->  71 685 (25x)

Everyday queries on the same machine (479 files):

 - `journalctl -b` printed 4.5 million lines in 48 s patched. The 8.18 binary managed 2 678 lines/s,
   about 28 minutes for the same output. `journalctl -k -b` was 54 s against about 33 minutes.
 - `journalctl -g <word>` over the newest 25 files took 42.8 s with 8.18 and 2.3 s patched.
 - The cheaper queries gained less, because they read few entries: `-n 100` 0.32 -> 0.10 s,
   `-u <unit>` 0.29 -> 0.07 s, `--list-boots` 0.18 -> 0.15 s.

That machine's journal is larger than the default (SystemMaxUse=16G, SystemMaxFiles=1000). A default
install keeps up to 100 archived files (SystemMaxFiles=100), plus the active system and user files. The
25 to 100 rows are the range a default install reaches.

An independent report against upstream in 2023 measured about 10 times from caching the same tail
timestamps: https://github.com/systemd/systemd/pull/29366. The remaining cost per entry still grows
with the number of files; that is a separate upstream topic, not part of this request:
https://github.com/systemd/systemd/issues/31486.

[ Test Plan ]

The reproducer is attached (journalctl-file-scaling-repro.sh). It needs no root and installs nothing.
It writes synthetic journal files into one `mktemp -d` directory, using systemd-journal-remote
without a daemon. It reads them only with `journalctl --directory=`, removes the directory at the end,
and never touches /var/log/journal or journald. Each run takes a few minutes.

1. Install `systemd-journal-remote`, if it is not installed. Run
   `./journalctl-file-scaling-repro.sh /usr/bin/journalctl` and keep the output.
2. Upgrade systemd and its binary packages from noble-proposed. Run the same command again.
3. Expected: from K = 50 upward, the patched lines/s is at least 5 times the 8.18 figure. In the
   attached reference run (a fresh ubuntu:24.04 container, unprivileged user), K = 100 went from 1 411
   to 89 837 lines/s.
4. Same output: before the upgrade, run
   `journalctl --file='/var/log/journal/*/system@*.journal' -o export --until '<a time before the test>' | sha256sum`.
   After the upgrade, run it again; the hash must be the same. Archived files do not change.
   Also run `journalctl --list-boots`, before and after; it must give the same list.
5. Files being written: `journalctl -f` in one terminal and `logger sru-test-$RANDOM` in another.
   The line must appear at once. Also check that `journalctl -b`, `journalctl -b -1` and
   `journalctl -u systemd-journald` show the same entries as before the upgrade.
6. The systemd autopkgtests pass.

[ Where problems could occur ]

The change is in how sd-journal decides that a file's newest entry (timestamp and boot ID) must be
read again.
 - Before: whenever the file's mtime changed, found through fstat().
 - After: when the tail-entry offset or the file's state in the header changes. An archived file is
   read once.

If that decision were wrong for a file still being written, the newest timestamp kept for a boot
would be stale. compare_boot_ids() uses those timestamps to order entries from different boots, so the
visible effect would be entries from different boots in the wrong order when files are merged. It
could also make `-b` or `--list-boots` pick the wrong boot, or `-f` show new entries late. Archived
files cannot change, so the risk is limited to the active system and user journal files. Test plan
steps 4 and 5 cover these cases.

The second commit adds one new error: -EBADMSG, when a file's tail entry sits at the same offset as
before but its data differs (a file rewritten in place). compare_boot_ids() treats any error as "no
answer" and falls back to comparing realtime timestamps; the other callers ignore the result. So
such a file would at worst be ordered by realtime, as entries from different machines already are.

The library code is shared: libsystemd0 gets the same change as journalctl. Other programs that read
the journal through sd-journal take the same path.

Both commits have been in upstream releases since v256 (June 2024), and in Ubuntu since 24.10. There
is no later upstream commit that fixes or reverts them: no Fixes: line refers to them, and
`git log --grep` on either hash finds only the commits themselves.

The only journal patch in 8.19 (lp2088163-sd-journal-use-stat_verify_linked.patch) changes how
journal_file_fstat() tests for a deleted file. It still returns -EIDRM for such a file, so it does
not depend on the fstat() calls these commits remove.

[ Other Info ]

 - PR #30209 was opened during the v255 release freeze, and its description says "this is not a v255
   material". It also contains four commits that are not proposed here:
    - bd1af1d5fb and f7f062bf9f, a new SD_JOURNAL_ASSUME_IMMUTABLE flag and its use;
    - cb2b0326ee, internal data structure changes;
    - 63d2c7554e, an output path change.
   The two proposed commits do not depend on them.
    - They apply to 255.4-1ubuntu8.19 without fuzz.
    - The package builds.
    - All journal unit tests of the package build pass (test-journal, -interleaving, -enum, -verify,
      -flush, -file, test-mmap-cache).
    - In a container build, test-fd-util and test-capability failed, and they fail the same way on
      unpatched 8.19 in that container.
 - Two later upstream changes in this area are not proposed either: 8f8ab4bf98 (rate-limited tail
   refresh, v262) and 79e32e7c73 (not yet released). They are not in the development release, and on
   255.4 they gave no measurable gain on top of the two commits.
 - The development release already has the fix (261.3), as do 25.04, 25.10 and 26.04.
 - Measured on that machine, in a container as well, the gains looked larger (15-77 times), because a
   container makes each system call dearer. The figures above are the host's.
```


## `evidence.md`

````
# Measurements: journalctl on noble with and without the two v256 commits

Everything here was measured on one machine in November 2026. Only numbers are given. The journal
contents are not shared, but the raw per-run records can be provided on request.

## Machine and method

| item | value |
|---|---|
| machine | Ubuntu 24.04.5, AMD Ryzen 7 5825U (8 cores, 16 threads), 30 GB RAM, NVMe, ext4 |
| installed systemd | 255.4-1ubuntu8.18 |
| its journal | 479 files, 15.9 GB; journald settings not the default: `SystemMaxUse=16G`, `SystemMaxFiles=1000` |
| binaries | **8.18**: the 255.4-1ubuntu8.18 source package (`dpkg-source -x`, all Ubuntu patches) built with meson, release mode. **patched**: the same tree plus 99e6f682d3 and 51b2bcf835 applied with `patch -p1`. Run from a build directory with their own libsystemd-shared. Nothing was installed |
| where | on the host, outside any container. Each run under `nice -n 19` and `ionice -c 3`, one at a time; other work ran on the machine, so absolute rates carry some noise |
| synthetic journals | K archived files of 2 000 entries each, 5 files per boot, one machine ID, written by systemd-journal-remote |
| real journal | the newest K files of the machine's journal, passed as `--file=`, read only |
| one run | `journalctl -o short --no-pager` on the K files, stopped after the first 200 000 lines or 45 s (synthetic), or 300 000 lines or 60 s (real). Lines/s is lines over wall time; median of 3 runs |

## 1. Output rate against the number of files (host)

Lines per second.

**Synthetic files**

| files | 8.18 | patched | patched / 8.18 |
|---|---|---|---|
| 25 | 19 218 | 178 586 | 9.3 |
| 50 | 8 269 | 123 012 | 14.9 |
| 100 | 4 563 | 84 104 | 18.4 |
| 200 | 1 395 | 34 043 | 24.4 |
| 400 | 633 | 13 787 | 21.8 |
| 800 | 308 | 5 603 | 18.2 |

**The machine's own journal (newest K files)**

| files | 8.18 | patched | patched / 8.18 |
|---|---|---|---|
| 25 | 29 194 | 201 342 | 6.9 |
| 50 | 19 438 | 190 355 | 9.8 |
| 100 | 11 361 | 133 097 | 11.7 |
| 200 | 5 847 | 119 474 | 20.4 |
| 400 | 2 885 | 71 685 | 24.8 |
| 479 (all) | 2 292 | 56 894 | 24.8 |

**System calls.** In a separate run on synthetic files at K = 100, strace counted 477.8 system calls
per printed line for 8.18 and 0.1 for the patched build. Almost all of 8.18's calls are fstat().

**Growth.** Fit time ∝ K^b for K ≥ 50, where 2 means quadratic and 1 linear:

| | synthetic | real journal |
|---|---|---|
| 8.18 | 2.23 | 1.95 |
| patched | 2.15 | 1.50 |

The backport removes the system calls, not the per-file comparison. Each entry still compares the
current position of every open file, so the cost still grows with the number of files. This is
upstream issue #31486 and is not part of this request.

## 2. Everyday queries (host, the machine's journal, 479 files)

Each query was capped at 120 s and run twice; the median is shown. The journal is live and grows
during the runs, so where a cap was hit, rates are compared, not line counts.

| query | 8.18 | patched | gain |
|---|---|---|---|
| `journalctl -b` | capped at 120 s, 2 678 lines/s | 4.5 M lines in 48.2 s (94 000 lines/s) | 35x (rate); 8.18 would need about 28 min |
| `journalctl -k -b` | capped, 2 568 lines/s | 5.0 M lines in 53.9 s | 36x (rate); about 33 min |
| `journalctl -b -1` | capped | capped | 27x (rate) |
| `journalctl --since "1 day ago"` | capped | capped | 27x (rate) |
| `journalctl -g <rare word>`, newest 25 files | 42.8 s | 2.33 s | 18x |
| `journalctl -u systemd-logind.service` | 0.29 s | 0.07 s | 4.3x |
| `journalctl -n 100` | 0.32 s | 0.10 s | 3.2x |
| `journalctl --list-boots` | 0.18 s | 0.15 s | 1.2x |

- Queries that walk entries in order across files gain most: `-b`, `-k -b`, `--since`, `-g` and
  export.
- Queries that use the indexes or read only file tails gain less: `-u`, `-n` and `--list-boots`.

The same queries on 800 synthetic files:

| query | 8.18 | patched | gain |
|---|---|---|---|
| `-b`, 10 000 entries | 7.07 s | 0.22 s | 33x |
| `-k -b`, 10 000 entries | 6.81 s | 0.21 s | 32x |
| `--list-boots` | 4.35 s | 0.56 s | 7.7x |
| `-n 100` | 0.52 s | 0.11 s | 4.7x |

## 3. The same runs in a container

These figures are for comparison only. On the same machine, inside a container, 8.18 ran 2 to 5 times
slower than on the host, while the patched build ran at the same speed. A container makes each
system call dearer, and 8.18 makes about 478 of them per line. The gains therefore look larger in a
container, so the host figures above are the ones to quote.

| files | synthetic 8.18 / patched | gain | real journal 8.18 / patched | gain |
|---|---|---|---|---|
| 25 | 6 843 / 177 319 | 25.9x | 14 714 / 227 017 | 15.4x |
| 100 | 899 / 68 729 | 76.5x | 4 493 / 146 994 | 32.7x |
| 400 | 229 / 13 471 | 58.8x | 1 251 / 77 419 | 61.9x |

## 4. The reproducer (fresh ubuntu:24.04 container, unprivileged user, network off)

The script and its test are in `reproducer/`. The output below is `reproducer/output.txt`:
1 000 entries per file, at most 100 000 lines or 40 s per run, median of 3 runs.

```
stock /usr/bin/journalctl (255.4-1ubuntu8.18)
     K      lines    seconds      lines/s       us/entry
    25      25004       2.92         8564          116.8
    50      50009      12.79         3910          255.7
   100      56432      40.01         1411          708.9
   200      21737      40.01          543         1840.4
   400      10576      40.01          264         3782.9
exponent: 2.30

255.4-1ubuntu8.18 + 99e6f682d3 + 51b2bcf835
     K      lines    seconds      lines/s       us/entry
    25      25004       0.12       207589            4.8
    50      50009       0.35       140990            7.1
   100     100000       1.11        89837           11.1
   200     100000       2.94        34043           29.4
   400     100000       6.68        14962           66.8
exponent: 2.11
```

**Safety check of that test.** It records path, type, size and mtime of everything under /var/log,
/run/log and /etc/systemd, and of the contents of /tmp and /var/tmp, before and after both runs:
52 entries, identical. No temporary directory was left behind.

## 5. Same output

The patched build printed byte-identical `-o export` output to 8.18 in 36 comparisons on synthetic
data and 2 on the machine's own journal.

**Synthetic data** came in two sets: 25 archived files in sequence, and archived files whose time
ranges interleave. Each set was read with:
 - everything, forward and with `-r`;
 - `-n 500`, `-k`, a `_BOOT_ID=` match and `-b -3`;
 - `--since`/`--until`, and `-r --since`;
 - `--reverse -n 3000` and `--lines=+3000`;
 - `--cursor` and `--after-cursor`, forward and reverse, at two positions.

**The machine's journal:** the newest 25 files, the first 600 000 export lines, forward and with `-r`.

**The built package (255.4-1ubuntu8.20 test build of 8.19 plus the two commits),** installed over
8.18 in a fresh ubuntu:24.04 container, was compared with stock 8.18 and stock 8.19 on four synthetic
sets:
 - plain archived files;
 - 12 boots whose files overlap in time;
 - two machine IDs;
 - the reproducer's files.

Each set was read with 14 kinds of query, 112 comparisons in all, and all were identical.

**A file still being written,** fed through systemd-journal-remote while `journalctl -f` read it with
8.18, 8.19 and the patched build. The followed output was identical (21 643 entries), and so was the
final read (24 500).

`journalctl --verify` on the reproducer's 400 files reported no failure. With the installed patched
package, the reproducer gave 189 958 lines/s at 25 files and 11 567 at 400.

Not tested: entries arriving through a running journald, because the container has no systemd as
PID 1. Step 5 of the bug's Test Plan covers that on a real machine.
````


## `reproducer/journalctl-file-scaling-repro.sh`

```
#!/bin/bash
# journalctl-file-scaling-repro.sh JOURNALCTL [K...]
#
# Does journalctl's cost per entry grow with the number of journal files it has open?
# Prints a table of lines/s against the number of files K, and the exponent b of
# (time to read everything) ~ K^b: b close to 2 means the read time grows with the square
# of the journal's size, close to 1 means it grows in proportion.
#
# Safe to run anywhere:
#   * needs no root; installs nothing; does not touch the system journal, /var/log/journal or journald;
#   * writes only inside one directory made with mktemp -d (removed at the end);
#   * reads only with `journalctl --directory=<that directory>/...`;
#   * the journal files are written by systemd-journal-remote from an export stream into that
#     directory (package systemd-journal-remote; its path can be given in REMOTE).
#
# JOURNALCTL is the binary to test, so two can be compared without installing either:
#   archive's:        ./journalctl-file-scaling-repro.sh /usr/bin/journalctl
#   a patched build:  ninja -C build journalctl      # in a systemd source tree, nothing is installed
#                     ./journalctl-file-scaling-repro.sh /path/to/tree/build/journalctl
#   A binary from a build tree finds its libsystemd-shared-*.so in its own directory or in
#   <its directory>/src/shared; this script puts those on LD_LIBRARY_PATH for that one process only.
#
# K defaults to "25 50 100 200 400". Environment: ENTRIES (entries per file, default 1000),
# LINES (stop after this many lines, default 100000), SECS (per run, default 40), RUNS (default 3,
# the median is used), REMOTE (path of systemd-journal-remote), REMOTE_LIBDIR (where its
# libsystemd-shared is, if it is not installed).
set -u

jc=${1:?usage: $0 JOURNALCTL [K...]}
shift
KS=${*:-25 50 100 200 400}
ENTRIES=${ENTRIES:-1000}; LINES=${LINES:-100000}; SECS=${SECS:-40}; RUNS=${RUNS:-3}

jc=$(readlink -f "$jc") || exit 1
[ -x "$jc" ] || { echo "not an executable: $jc" >&2; exit 1; }

remote=${REMOTE:-}
if [ -z "$remote" ]; then
    for c in /usr/lib/systemd/systemd-journal-remote /lib/systemd/systemd-journal-remote "$(command -v systemd-journal-remote)"; do
        [ -n "$c" ] && [ -x "$c" ] && { remote=$c; break; }
    done
fi
[ -n "$remote" ] || { echo "systemd-journal-remote not found. Install the package systemd-journal-remote, or set REMOTE=<path> (and REMOTE_LIBDIR=<dir with libsystemd-shared>)." >&2; exit 1; }

tmp=$(mktemp -d "${TMPDIR:-/tmp}/journalctl-scaling.XXXXXX") || exit 1
case $tmp in /*/journalctl-scaling.*) ;; *) echo "unexpected temp dir $tmp" >&2; exit 1 ;; esac
trap 'rm -rf -- "$tmp"' EXIT
mkdir "$tmp/all"

maxk=0; for k in $KS; do [ "$k" -gt "$maxk" ] && maxk=$k; done

jcdir=$(dirname "$jc")
export LD_LIBRARY_PATH="$jcdir:$jcdir/src/shared${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
remote_ld=${REMOTE_LIBDIR:+$REMOTE_LIBDIR:}${LD_LIBRARY_PATH:-}

echo "journalctl under test: $jc ($(LD_LIBRARY_PATH=$LD_LIBRARY_PATH "$jc" --version | head -n 1))"
echo "journal files are written under: $tmp (removed at the end); the system journal is not read or written"
echo "writing $maxk files of $ENTRIES entries each, archived, 5 files per boot ..."

# One export-format stream per file: consecutive time slices, a new boot every 5 files, one machine ID.
realtime=1700000000000000; seq=0
for ((i = 0; i < maxk; i++)); do
    b=$((i / 5))
    f=$(printf '%s/all/system@%05d.journal' "$tmp" "$i")
    awk -v rt="$realtime" -v n="$ENTRIES" -v i="$i" -v b="$b" -v seq="$seq" -v newboot=$((i % 5 == 0)) 'BEGIN {
        if (newboot) rt += 60000000
        mono = 5000000 + (i % 5) * n * 2000
        boot = sprintf("%08x", b) "b007b007b007b007b007b007"
        for (e = 0; e < n; e++) {
            rt += 2000; mono += 2000; seq++
            printf "__REALTIME_TIMESTAMP=%d\n__MONOTONIC_TIMESTAMP=%d\n_BOOT_ID=%s\n_MACHINE_ID=0123456789abcdef0123456789abcdef\n", rt, mono, boot
            printf "_HOSTNAME=repro\n_TRANSPORT=kernel\nSYSLOG_IDENTIFIER=kernel\nPRIORITY=6\nMESSAGE=synthetic line %d in file %d boot %d\n\n", seq, i, b
        }
    }' > "$tmp/stream" || exit 1
    # advance the clock exactly as the awk program did
    [ $((i % 5)) -eq 0 ] && realtime=$((realtime + 60000000))
    realtime=$((realtime + ENTRIES * 2000)); seq=$((seq + ENTRIES))
    LD_LIBRARY_PATH=$remote_ld "$remote" --output="$f" - < "$tmp/stream" > /dev/null 2> "$tmp/err" \
        || { echo "systemd-journal-remote failed on file $i:" >&2; cat "$tmp/err" >&2; exit 1; }
    printf '\002' | dd of="$f" bs=1 seek=16 conv=notrunc 2> /dev/null    # header state: ARCHIVED, as rotated files are
done
rm -f "$tmp/stream"

printf '\n%6s %10s %10s %12s %14s\n' K lines seconds lines/s us/entry
xs=(); ys=()
for k in $KS; do
    mkdir "$tmp/set$k"
    for f in $(ls "$tmp"/all/*.journal | sort | head -n "$k"); do ln "$f" "$tmp/set$k/"; done
    rates=()
    for ((r = 0; r < RUNS; r++)); do
        t0=$(date +%s.%N)
        n=$(timeout "$SECS" "$jc" --directory="$tmp/set$k" -o short --no-pager 2> /dev/null | head -n "$LINES" | wc -l)
        t1=$(date +%s.%N)
        rates+=("$(awk -v n="$n" -v a="$t0" -v b="$t1" 'BEGIN { printf "%.3f %d %.3f", n / (b - a), n, b - a }')")
    done
    med=$(printf '%s\n' "${rates[@]}" | sort -g | awk '{ r[NR] = $0 } END { print r[int((NR + 1) / 2)] }')
    set -- $med
    printf '%6d %10d %10.2f %12.0f %14.1f\n' "$k" "$2" "$3" "$1" "$(awk -v r="$1" 'BEGIN { printf "%.1f", 1e6 / r }')"
    [ "$k" -ge 50 ] && { xs+=("$k"); ys+=("$1"); }
done

# exponent: slope of log(cost per entry) against log(K) over K >= 50, plus 1 (N is proportional to K)
if [ "${#xs[@]}" -ge 2 ]; then
    paste <(printf '%s\n' "${xs[@]}") <(printf '%s\n' "${ys[@]}") | awk '
        { x = log($1); y = log(1 / $2); sx += x; sy += y; sxx += x * x; sxy += x * y; n++ }
        END { s = (n * sxy - sx * sy) / (n * sxx - sx * sx)
              printf "\nexponent b of (time to read everything) ~ K^b, K >= 50: %.2f   (2 = quadratic, 1 = linear)\n", 1 + s }'
fi
```


## `reproducer/output.txt`

```
uid=1001(tester) gid=1001(tester) groups=1001(tester)
journal directories present before: ls: cannot access '/run/log/journal': No such file or directory /var/log/journal 

################ /usr/bin/journalctl
journalctl under test: /usr/bin/journalctl (systemd 255 (255.4-1ubuntu8.18))
journal files are written under: /tmp/journalctl-scaling.FJwoVA (removed at the end); the system journal is not read or written
writing 400 files of 1000 entries each, archived, 5 files per boot ...

     K      lines    seconds      lines/s       us/entry
    25      25004       2.92         8564          116.8
    50      50009      12.79         3910          255.7
   100      56432      40.01         1411          708.9
   200      21737      40.01          543         1840.4
   400      10576      40.01          264         3782.9

exponent b of (time to read everything) ~ K^b, K >= 50: 2.30   (2 = quadratic, 1 = linear)

################ /bins/b/journalctl
journalctl under test: /bins/b/journalctl (systemd 255 (255))
journal files are written under: /tmp/journalctl-scaling.Wawm3m (removed at the end); the system journal is not read or written
writing 400 files of 1000 entries each, archived, 5 files per boot ...

     K      lines    seconds      lines/s       us/entry
    25      25004       0.12       207589            4.8
    50      50009       0.35       140990            7.1
   100     100000       1.11        89837           11.1
   200     100000       2.94        34043           29.4
   400     100000       6.68        14962           66.8

exponent b of (time to read everything) ~ K^b, K >= 50: 2.11   (2 = quadratic, 1 = linear)

################ safety check: /var/log, /run/log, /etc/systemd, /tmp, /var/tmp before and after
identical: 52 entries (path type size mtime), no difference
journal directories present after: ls: cannot access '/run/log/journal': No such file or directory /var/log/journal 
leftover scaling directories in /tmp: 0
```


## `reproducer/Dockerfile`

```
FROM ubuntu:24.04
# A fresh Ubuntu 24.04 with only what a maintainer would have: the archive's systemd (journalctl) and the
# package that provides systemd-journal-remote. Nothing else is added; the test runs as an unprivileged user.
RUN apt-get update -qq && apt-get install -y -qq systemd systemd-journal-remote && rm -rf /var/lib/apt/lists/*
RUN useradd -m tester
USER tester
WORKDIR /home/tester
```


## `reproducer/inside-repro-test.sh`

```
#!/bin/bash
# Runs INSIDE the test container as the unprivileged user "tester".
#   inside-repro-test.sh BINARY...   : the script is run once per binary, with a snapshot of the places that
#   must not change taken before and after.
snap() {
    # path, type, size, mtime of everything below these directories, and of the directories themselves
    for d in /var/log /run/log /etc/systemd; do
        [ -e "$d" ] && find "$d" -xdev -printf '%p %y %s %T@\n' 2>/dev/null
    done
    # /tmp and /var/tmp: the scratch directory the script makes (and removes) lives directly in /tmp, which
    # changes /tmp's own mtime; so list what is inside, not the directories' own mtimes
    for d in /tmp /var/tmp; do
        [ -e "$d" ] && find "$d" -xdev -mindepth 1 -printf '%p %y %s %T@\n' 2>/dev/null
    done
}
id
echo "journal directories present before: $(ls -d /var/log/journal /run/log/journal 2>&1 | tr '\n' ' ')"
snap > /tmp/.snap-before
for jc in "$@"; do
    echo
    echo "################ $jc"
    /repro/journalctl-file-scaling-repro.sh "$jc"
done
snap > /tmp/.snap-after
echo
echo "################ safety check: /var/log, /run/log, /etc/systemd, /tmp, /var/tmp before and after"
if diff <(grep -v '^/tmp/.snap' /tmp/.snap-before) <(grep -v '^/tmp/.snap' /tmp/.snap-after) > /tmp/.snap-diff; then
    echo "identical: $(grep -vc '^/tmp/.snap' /tmp/.snap-before) entries (path type size mtime), no difference"
else
    echo "DIFFERENT:"; cat /tmp/.snap-diff
fi
echo "journal directories present after: $(ls -d /var/log/journal /run/log/journal 2>&1 | tr '\n' ' ')"
echo "leftover scaling directories in /tmp: $(ls -d /tmp/journalctl-scaling.* 2>/dev/null | wc -l)"
```


## `patches/debian-patches/lpNNNNNNN-sd-journal-cache-last-entry-offset-and-journal-file-state.patch`

```diff
From: Yu Watanabe <watanabe.yu+github@gmail.com>
Date: Wed, 3 Jan 2024 04:27:59 +0900
Subject: sd-journal: cache last entry offset and journal file state
Origin: upstream, https://github.com/systemd/systemd/commit/99e6f682d3627c2c06d99bb3c3756e448e8d9bd1
Bug: https://github.com/systemd/systemd/issues/31486
Bug-Ubuntu: https://bugs.launchpad.net/ubuntu/+source/systemd/+bug/NNNNNNN

When the offset of the last entry object (or last object for journal
files generated by an old journald) is not changed, the timestamps
should be updated by journal_file_read_tail_timestamp() are unchanged.
So, we can drop to call fstat() in the function.

As, the journal header is always mapped, so we can read the offset and
journal file state without calling fstat.
Still, when the last entry offset is changed, we may need to call fstat()
to read the entry object. But, hopefully the number of fstat() call
can be reduced.

(cherry picked from commit 99e6f682d3627c2c06d99bb3c3756e448e8d9bd1)
---
diff --git a/src/libsystemd/sd-journal/journal-file.c b/src/libsystemd/sd-journal/journal-file.c
index 64bf8ef9af..8039b2aaf9 100644
--- a/src/libsystemd/sd-journal/journal-file.c
+++ b/src/libsystemd/sd-journal/journal-file.c
@@ -2244,7 +2244,6 @@ static int journal_file_link_entry(
         f->header->tail_entry_monotonic = o->entry.monotonic;
         if (JOURNAL_HEADER_CONTAINS(f->header, tail_entry_offset))
                 f->header->tail_entry_offset = htole64(offset);
-        f->newest_mtime = 0; /* we have a new tail entry now, explicitly invalidate newest boot id/timestamp info */
 
         /* Link up the items */
         for (uint64_t i = 0; i < n_items; i++) {
diff --git a/src/libsystemd/sd-journal/journal-file.h b/src/libsystemd/sd-journal/journal-file.h
index 81fafb9bec..6b378a2039 100644
--- a/src/libsystemd/sd-journal/journal-file.h
+++ b/src/libsystemd/sd-journal/journal-file.h
@@ -129,7 +129,8 @@ typedef struct JournalFile {
         uint64_t newest_monotonic_usec;
         uint64_t newest_realtime_usec;
         unsigned newest_boot_id_prioq_idx;
-        usec_t newest_mtime;
+        uint64_t newest_entry_offset;
+        uint8_t newest_state;
 } JournalFile;
 
 typedef enum JournalFileFlags {
diff --git a/src/libsystemd/sd-journal/sd-journal.c b/src/libsystemd/sd-journal/sd-journal.c
index 5a8c8a8579..d7136d250e 100644
--- a/src/libsystemd/sd-journal/sd-journal.c
+++ b/src/libsystemd/sd-journal/sd-journal.c
@@ -2428,11 +2428,10 @@ static int journal_file_read_tail_timestamp(sd_journal *j, JournalFile *f) {
 
         /* Tries to read the timestamp of the most recently written entry. */
 
-        r = journal_file_fstat(f);
-        if (r < 0)
-                return r;
-        if (f->newest_mtime == timespec_load(&f->last_stat.st_mtim))
-                return 0; /* mtime didn't change since last time, don't bother */
+        if (f->header->state == f->newest_state &&
+            f->header->state == STATE_ARCHIVED &&
+            f->newest_entry_offset != 0)
+                return 0; /* We have already read archived file. */
 
         if (JOURNAL_HEADER_CONTAINS(f->header, tail_entry_offset)) {
                 offset = le64toh(READ_NOW(f->header->tail_entry_offset));
@@ -2443,6 +2442,8 @@ static int journal_file_read_tail_timestamp(sd_journal *j, JournalFile *f) {
         }
         if (offset == 0)
                 return -ENODATA; /* not a single object/entry, hence no tail timestamp */
+        if (offset == f->newest_entry_offset)
+                return 0; /* No new entry is added after we read last time. */
 
         /* Move to the last object in the journal file, in the hope it is an entry (which it usually will
          * be). If we lack the "tail_entry_offset" field in the header, we specify the type as OBJECT_UNUSED
@@ -2452,6 +2453,7 @@ static int journal_file_read_tail_timestamp(sd_journal *j, JournalFile *f) {
         if (r < 0) {
                 log_debug_errno(r, "Failed to move to last object in journal file, ignoring: %m");
                 o = NULL;
+                offset = 0;
         }
         if (o && o->object.type == OBJECT_ENTRY) {
                 /* Yay, last object is an entry, let's use the data. */
@@ -2469,10 +2471,11 @@ static int journal_file_read_tail_timestamp(sd_journal *j, JournalFile *f) {
                         mo = le64toh(f->header->tail_entry_monotonic);
                         rt = le64toh(f->header->tail_entry_realtime);
                         id = f->header->tail_entry_boot_id;
+                        offset = UINT64_MAX;
                 } else {
                         /* Otherwise let's find the last entry manually (this possibly means traversing the
                          * chain of entry arrays, till the end */
-                        r = journal_file_next_entry(f, 0, DIRECTION_UP, &o, NULL);
+                        r = journal_file_next_entry(f, 0, DIRECTION_UP, &o, offset == 0 ? &offset : NULL);
                         if (r < 0)
                                 return r;
                         if (r == 0)
@@ -2494,7 +2497,8 @@ static int journal_file_read_tail_timestamp(sd_journal *j, JournalFile *f) {
         f->newest_monotonic_usec = mo;
         f->newest_realtime_usec = rt;
         f->newest_machine_id = f->header->machine_id;
-        f->newest_mtime = timespec_load(&f->last_stat.st_mtim);
+        f->newest_entry_offset = offset;
+        f->newest_state = f->header->state;
 
         r = journal_file_reshuffle_newest_by_boot_id(j, f);
         if (r < 0)
```


## `patches/debian-patches/lpNNNNNNN-sd-journal-make-journal_file_read_tail_timestamp-notify-to-the-caller.patch`

```diff
From: Yu Watanabe <watanabe.yu+github@gmail.com>
Date: Wed, 3 Jan 2024 04:28:03 +0900
Subject: sd-journal: make journal_file_read_tail_timestamp() notify to the caller that some new journal entries added
Origin: upstream, https://github.com/systemd/systemd/commit/51b2bcf8356b847e7ab778adfad930691713c7ef
Bug: https://github.com/systemd/systemd/issues/31486
Bug-Ubuntu: https://bugs.launchpad.net/ubuntu/+source/systemd/+bug/NNNNNNN

Tiny optimization for journal_file_find_newest_for_boot_id().

(cherry picked from commit 51b2bcf8356b847e7ab778adfad930691713c7ef)
---
diff --git a/src/libsystemd/sd-journal/sd-journal.c b/src/libsystemd/sd-journal/sd-journal.c
index d7136d250e..f082f3f6f9 100644
--- a/src/libsystemd/sd-journal/sd-journal.c
+++ b/src/libsystemd/sd-journal/sd-journal.c
@@ -449,6 +449,11 @@ static int journal_file_find_newest_for_boot_id(
                 r = journal_file_read_tail_timestamp(j, f);
                 if (r < 0)
                         return log_debug_errno(r, "Failed to read tail timestamp while trying to find newest journal file for boot ID %s.", SD_ID128_TO_STRING(id));
+                if (r == 0) {
+                        /* No new entry found. */
+                        *ret = f;
+                        return 0;
+                }
 
                 /* Refreshing the timestamp we read might have reshuffled the prioq, hence let's check the
                  * prioq again and only use the information once we reached an equilibrium or hit a limit */
@@ -2490,6 +2495,17 @@ static int journal_file_read_tail_timestamp(sd_journal *j, JournalFile *f) {
         if (mo > rt) /* monotonic clock is further ahead than realtime? that's weird, refuse to use the data */
                 return -ENODATA;
 
+        if (offset == f->newest_entry_offset) {
+                /* Cached data and the current one should be equivalent. */
+                if (!sd_id128_equal(f->newest_machine_id, f->header->machine_id) ||
+                    !sd_id128_equal(f->newest_boot_id, id) ||
+                    f->newest_monotonic_usec != mo ||
+                    f->newest_realtime_usec != rt)
+                        return -EBADMSG;
+
+                return 0; /* No new entry is added after we read last time. */
+        }
+
         if (!sd_id128_equal(f->newest_boot_id, id))
                 journal_file_unlink_newest_by_boot_id(j, f);
 
@@ -2504,7 +2520,7 @@ static int journal_file_read_tail_timestamp(sd_journal *j, JournalFile *f) {
         if (r < 0)
                 return r;
 
-        return 0;
+        return 1; /* Updated. */
 }
 
 _public_ int sd_journal_get_realtime_usec(sd_journal *j, uint64_t *ret) {
```


## `patches/systemd_255.4-1ubuntu8.19_to_8.20.debdiff`

```diff
diff -Nru systemd-255.4/debian/changelog systemd-255.4/debian/changelog
--- systemd-255.4/debian/changelog	2026-10-15 15:58:12.000000000 +0000
+++ systemd-255.4/debian/changelog	2026-11-16 02:58:44.000000000 +0000
@@ -1,3 +1,14 @@
+systemd (255.4-1ubuntu8.20) UNRELEASED; urgency=medium
+
+  * Fix journalctl being very slow on journals with many files (LP: #NNNNNNN)
+    - d/p/lpNNNNNNN-sd-journal-cache-last-entry-offset-and-journal-file-state.patch,
+      d/p/lpNNNNNNN-sd-journal-make-journal_file_read_tail_timestamp-notify-to-the-caller.patch:
+      Cherry-pick upstream commits 99e6f682d3 and 51b2bcf835 (v256): stop
+      sd-journal from calling fstat() on every open journal file for every
+      entry it returns.
+
+ -- <AUTHOR-NAME> <AUTHOR-EMAIL>  Mon, 16 Nov 2026 09:00:00 +0000
+
 systemd (255.4-1ubuntu8.19) noble; urgency=medium
 
   [ Seyeong Kim ]
diff -Nru systemd-255.4/debian/patches/lpNNNNNNN-sd-journal-cache-last-entry-offset-and-journal-file-state.patch systemd-255.4/debian/patches/lpNNNNNNN-sd-journal-cache-last-entry-offset-and-journal-file-state.patch
--- systemd-255.4/debian/patches/lpNNNNNNN-sd-journal-cache-last-entry-offset-and-journal-file-state.patch	1970-01-01 00:00:00.000000000 +0000
+++ systemd-255.4/debian/patches/lpNNNNNNN-sd-journal-cache-last-entry-offset-and-journal-file-state.patch	2026-11-16 02:58:44.000000000 +0000
@@ -0,0 +1,106 @@
+From: Yu Watanabe <watanabe.yu+github@gmail.com>
+Date: Wed, 3 Jan 2024 04:27:59 +0900
+Subject: sd-journal: cache last entry offset and journal file state
+Origin: upstream, https://github.com/systemd/systemd/commit/99e6f682d3627c2c06d99bb3c3756e448e8d9bd1
+Bug: https://github.com/systemd/systemd/issues/31486
+Bug-Ubuntu: https://bugs.launchpad.net/ubuntu/+source/systemd/+bug/NNNNNNN
+
+When the offset of the last entry object (or last object for journal
+files generated by an old journald) is not changed, the timestamps
+should be updated by journal_file_read_tail_timestamp() are unchanged.
+So, we can drop to call fstat() in the function.
+
+As, the journal header is always mapped, so we can read the offset and
+journal file state without calling fstat.
+Still, when the last entry offset is changed, we may need to call fstat()
+to read the entry object. But, hopefully the number of fstat() call
+can be reduced.
+
+(cherry picked from commit 99e6f682d3627c2c06d99bb3c3756e448e8d9bd1)
+---
+diff --git a/src/libsystemd/sd-journal/journal-file.c b/src/libsystemd/sd-journal/journal-file.c
+index 64bf8ef9af..8039b2aaf9 100644
+--- a/src/libsystemd/sd-journal/journal-file.c
++++ b/src/libsystemd/sd-journal/journal-file.c
+@@ -2244,7 +2244,6 @@ static int journal_file_link_entry(
+         f->header->tail_entry_monotonic = o->entry.monotonic;
+         if (JOURNAL_HEADER_CONTAINS(f->header, tail_entry_offset))
+                 f->header->tail_entry_offset = htole64(offset);
+-        f->newest_mtime = 0; /* we have a new tail entry now, explicitly invalidate newest boot id/timestamp info */
+ 
+         /* Link up the items */
+         for (uint64_t i = 0; i < n_items; i++) {
+diff --git a/src/libsystemd/sd-journal/journal-file.h b/src/libsystemd/sd-journal/journal-file.h
+index 81fafb9bec..6b378a2039 100644
+--- a/src/libsystemd/sd-journal/journal-file.h
++++ b/src/libsystemd/sd-journal/journal-file.h
+@@ -129,7 +129,8 @@ typedef struct JournalFile {
+         uint64_t newest_monotonic_usec;
+         uint64_t newest_realtime_usec;
+         unsigned newest_boot_id_prioq_idx;
+-        usec_t newest_mtime;
++        uint64_t newest_entry_offset;
++        uint8_t newest_state;
+ } JournalFile;
+ 
+ typedef enum JournalFileFlags {
+diff --git a/src/libsystemd/sd-journal/sd-journal.c b/src/libsystemd/sd-journal/sd-journal.c
+index 5a8c8a8579..d7136d250e 100644
+--- a/src/libsystemd/sd-journal/sd-journal.c
++++ b/src/libsystemd/sd-journal/sd-journal.c
+@@ -2428,11 +2428,10 @@ static int journal_file_read_tail_timestamp(sd_journal *j, JournalFile *f) {
+ 
+         /* Tries to read the timestamp of the most recently written entry. */
+ 
+-        r = journal_file_fstat(f);
+-        if (r < 0)
+-                return r;
+-        if (f->newest_mtime == timespec_load(&f->last_stat.st_mtim))
+-                return 0; /* mtime didn't change since last time, don't bother */
++        if (f->header->state == f->newest_state &&
++            f->header->state == STATE_ARCHIVED &&
++            f->newest_entry_offset != 0)
++                return 0; /* We have already read archived file. */
+ 
+         if (JOURNAL_HEADER_CONTAINS(f->header, tail_entry_offset)) {
+                 offset = le64toh(READ_NOW(f->header->tail_entry_offset));
+@@ -2443,6 +2442,8 @@ static int journal_file_read_tail_timestamp(sd_journal *j, JournalFile *f) {
+         }
+         if (offset == 0)
+                 return -ENODATA; /* not a single object/entry, hence no tail timestamp */
++        if (offset == f->newest_entry_offset)
++                return 0; /* No new entry is added after we read last time. */
+ 
+         /* Move to the last object in the journal file, in the hope it is an entry (which it usually will
+          * be). If we lack the "tail_entry_offset" field in the header, we specify the type as OBJECT_UNUSED
+@@ -2452,6 +2453,7 @@ static int journal_file_read_tail_timestamp(sd_journal *j, JournalFile *f) {
+         if (r < 0) {
+                 log_debug_errno(r, "Failed to move to last object in journal file, ignoring: %m");
+                 o = NULL;
++                offset = 0;
+         }
+         if (o && o->object.type == OBJECT_ENTRY) {
+                 /* Yay, last object is an entry, let's use the data. */
+@@ -2469,10 +2471,11 @@ static int journal_file_read_tail_timestamp(sd_journal *j, JournalFile *f) {
+                         mo = le64toh(f->header->tail_entry_monotonic);
+                         rt = le64toh(f->header->tail_entry_realtime);
+                         id = f->header->tail_entry_boot_id;
++                        offset = UINT64_MAX;
+                 } else {
+                         /* Otherwise let's find the last entry manually (this possibly means traversing the
+                          * chain of entry arrays, till the end */
+-                        r = journal_file_next_entry(f, 0, DIRECTION_UP, &o, NULL);
++                        r = journal_file_next_entry(f, 0, DIRECTION_UP, &o, offset == 0 ? &offset : NULL);
+                         if (r < 0)
+                                 return r;
+                         if (r == 0)
+@@ -2494,7 +2497,8 @@ static int journal_file_read_tail_timestamp(sd_journal *j, JournalFile *f) {
+         f->newest_monotonic_usec = mo;
+         f->newest_realtime_usec = rt;
+         f->newest_machine_id = f->header->machine_id;
+-        f->newest_mtime = timespec_load(&f->last_stat.st_mtim);
++        f->newest_entry_offset = offset;
++        f->newest_state = f->header->state;
+ 
+         r = journal_file_reshuffle_newest_by_boot_id(j, f);
+         if (r < 0)
diff -Nru systemd-255.4/debian/patches/lpNNNNNNN-sd-journal-make-journal_file_read_tail_timestamp-notify-to-the-caller.patch systemd-255.4/debian/patches/lpNNNNNNN-sd-journal-make-journal_file_read_tail_timestamp-notify-to-the-caller.patch
--- systemd-255.4/debian/patches/lpNNNNNNN-sd-journal-make-journal_file_read_tail_timestamp-notify-to-the-caller.patch	1970-01-01 00:00:00.000000000 +0000
+++ systemd-255.4/debian/patches/lpNNNNNNN-sd-journal-make-journal_file_read_tail_timestamp-notify-to-the-caller.patch	2026-11-16 02:58:44.000000000 +0000
@@ -0,0 +1,54 @@
+From: Yu Watanabe <watanabe.yu+github@gmail.com>
+Date: Wed, 3 Jan 2024 04:28:03 +0900
+Subject: sd-journal: make journal_file_read_tail_timestamp() notify to the caller that some new journal entries added
+Origin: upstream, https://github.com/systemd/systemd/commit/51b2bcf8356b847e7ab778adfad930691713c7ef
+Bug: https://github.com/systemd/systemd/issues/31486
+Bug-Ubuntu: https://bugs.launchpad.net/ubuntu/+source/systemd/+bug/NNNNNNN
+
+Tiny optimization for journal_file_find_newest_for_boot_id().
+
+(cherry picked from commit 51b2bcf8356b847e7ab778adfad930691713c7ef)
+---
+diff --git a/src/libsystemd/sd-journal/sd-journal.c b/src/libsystemd/sd-journal/sd-journal.c
+index d7136d250e..f082f3f6f9 100644
+--- a/src/libsystemd/sd-journal/sd-journal.c
++++ b/src/libsystemd/sd-journal/sd-journal.c
+@@ -449,6 +449,11 @@ static int journal_file_find_newest_for_boot_id(
+                 r = journal_file_read_tail_timestamp(j, f);
+                 if (r < 0)
+                         return log_debug_errno(r, "Failed to read tail timestamp while trying to find newest journal file for boot ID %s.", SD_ID128_TO_STRING(id));
++                if (r == 0) {
++                        /* No new entry found. */
++                        *ret = f;
++                        return 0;
++                }
+ 
+                 /* Refreshing the timestamp we read might have reshuffled the prioq, hence let's check the
+                  * prioq again and only use the information once we reached an equilibrium or hit a limit */
+@@ -2490,6 +2495,17 @@ static int journal_file_read_tail_timestamp(sd_journal *j, JournalFile *f) {
+         if (mo > rt) /* monotonic clock is further ahead than realtime? that's weird, refuse to use the data */
+                 return -ENODATA;
+ 
++        if (offset == f->newest_entry_offset) {
++                /* Cached data and the current one should be equivalent. */
++                if (!sd_id128_equal(f->newest_machine_id, f->header->machine_id) ||
++                    !sd_id128_equal(f->newest_boot_id, id) ||
++                    f->newest_monotonic_usec != mo ||
++                    f->newest_realtime_usec != rt)
++                        return -EBADMSG;
++
++                return 0; /* No new entry is added after we read last time. */
++        }
++
+         if (!sd_id128_equal(f->newest_boot_id, id))
+                 journal_file_unlink_newest_by_boot_id(j, f);
+ 
+@@ -2504,7 +2520,7 @@ static int journal_file_read_tail_timestamp(sd_journal *j, JournalFile *f) {
+         if (r < 0)
+                 return r;
+ 
+-        return 0;
++        return 1; /* Updated. */
+ }
+ 
+ _public_ int sd_journal_get_realtime_usec(sd_journal *j, uint64_t *ret) {
diff -Nru systemd-255.4/debian/patches/series systemd-255.4/debian/patches/series
--- systemd-255.4/debian/patches/series	2026-10-15 15:55:02.000000000 +0000
+++ systemd-255.4/debian/patches/series	2026-11-16 02:58:44.000000000 +0000
@@ -95,3 +95,5 @@
 lp2088163-journal-file-util-use-the-file-descriptor-of-journal-file.patch
 lp2088163-journal-file-util-use-COPY_VERIFY_LINKED.patch
 lp2088163-test-add-test-cases-for-journal-corruption-on-btrfs.patch
+lpNNNNNNN-sd-journal-cache-last-entry-offset-and-journal-file-state.patch
+lpNNNNNNN-sd-journal-make-journal_file_read_tail_timestamp-notify-to-the-caller.patch
```


## `patches/ubuntu-noble-branch-commit.patch`

```diff
From caf74770891561d1e264ab2937a9a91562181c28 Mon Sep 17 00:00:00 2001
From: <AUTHOR-NAME> <AUTHOR-EMAIL>
Date: Mon, 16 Nov 2026 09:00:00 +0000
Subject: [PATCH] d/p/lpNNNNNNN-*: cherry-pick two upstream fixes for
 journalctl on many journal files (LP: #NNNNNNN)

Upstream commits 99e6f682d3 and 51b2bcf835 (v256) stop sd-journal from
calling fstat() on every open journal file for every entry it returns.
Reading a journal that spans many files was slow in proportion to the
number of files; with these two patches the system calls are gone.

Bug: https://github.com/systemd/systemd/issues/31486
---
 debian/changelog                              |  11 ++
 ...-entry-offset-and-journal-file-state.patch | 106 ++++++++++++++++++
 ..._tail_timestamp-notify-to-the-caller.patch |  54 +++++++++
 debian/patches/series                         |   2 +
 4 files changed, 173 insertions(+)
 create mode 100644 debian/patches/lpNNNNNNN-sd-journal-cache-last-entry-offset-and-journal-file-state.patch
 create mode 100644 debian/patches/lpNNNNNNN-sd-journal-make-journal_file_read_tail_timestamp-notify-to-the-caller.patch

diff --git a/debian/changelog b/debian/changelog
index 824c7d3b20..27f8c17d23 100644
--- a/debian/changelog
+++ b/debian/changelog
@@ -1,3 +1,14 @@
+systemd (255.4-1ubuntu8.20) UNRELEASED; urgency=medium
+
+  * Fix journalctl being very slow on journals with many files (LP: #NNNNNNN)
+    - d/p/lpNNNNNNN-sd-journal-cache-last-entry-offset-and-journal-file-state.patch,
+      d/p/lpNNNNNNN-sd-journal-make-journal_file_read_tail_timestamp-notify-to-the-caller.patch:
+      Cherry-pick upstream commits 99e6f682d3 and 51b2bcf835 (v256): stop
+      sd-journal from calling fstat() on every open journal file for every
+      entry it returns.
+
+ -- <AUTHOR-NAME> <AUTHOR-EMAIL>  Mon, 16 Nov 2026 09:00:00 +0000
+
 systemd (255.4-1ubuntu8.19) noble; urgency=medium
 
   [ Seyeong Kim ]
diff --git a/debian/patches/lpNNNNNNN-sd-journal-cache-last-entry-offset-and-journal-file-state.patch b/debian/patches/lpNNNNNNN-sd-journal-cache-last-entry-offset-and-journal-file-state.patch
new file mode 100644
index 0000000000..3b1785a92f
--- /dev/null
+++ b/debian/patches/lpNNNNNNN-sd-journal-cache-last-entry-offset-and-journal-file-state.patch
@@ -0,0 +1,106 @@
+From: Yu Watanabe <watanabe.yu+github@gmail.com>
+Date: Wed, 3 Jan 2024 04:27:59 +0900
+Subject: sd-journal: cache last entry offset and journal file state
+Origin: upstream, https://github.com/systemd/systemd/commit/99e6f682d3627c2c06d99bb3c3756e448e8d9bd1
+Bug: https://github.com/systemd/systemd/issues/31486
+Bug-Ubuntu: https://bugs.launchpad.net/ubuntu/+source/systemd/+bug/NNNNNNN
+
+When the offset of the last entry object (or last object for journal
+files generated by an old journald) is not changed, the timestamps
+should be updated by journal_file_read_tail_timestamp() are unchanged.
+So, we can drop to call fstat() in the function.
+
+As, the journal header is always mapped, so we can read the offset and
+journal file state without calling fstat.
+Still, when the last entry offset is changed, we may need to call fstat()
+to read the entry object. But, hopefully the number of fstat() call
+can be reduced.
+
+(cherry picked from commit 99e6f682d3627c2c06d99bb3c3756e448e8d9bd1)
+---
+diff --git a/src/libsystemd/sd-journal/journal-file.c b/src/libsystemd/sd-journal/journal-file.c
+index 64bf8ef9af..8039b2aaf9 100644
+--- a/src/libsystemd/sd-journal/journal-file.c
++++ b/src/libsystemd/sd-journal/journal-file.c
+@@ -2244,7 +2244,6 @@ static int journal_file_link_entry(
+         f->header->tail_entry_monotonic = o->entry.monotonic;
+         if (JOURNAL_HEADER_CONTAINS(f->header, tail_entry_offset))
+                 f->header->tail_entry_offset = htole64(offset);
+-        f->newest_mtime = 0; /* we have a new tail entry now, explicitly invalidate newest boot id/timestamp info */
+ 
+         /* Link up the items */
+         for (uint64_t i = 0; i < n_items; i++) {
+diff --git a/src/libsystemd/sd-journal/journal-file.h b/src/libsystemd/sd-journal/journal-file.h
+index 81fafb9bec..6b378a2039 100644
+--- a/src/libsystemd/sd-journal/journal-file.h
++++ b/src/libsystemd/sd-journal/journal-file.h
+@@ -129,7 +129,8 @@ typedef struct JournalFile {
+         uint64_t newest_monotonic_usec;
+         uint64_t newest_realtime_usec;
+         unsigned newest_boot_id_prioq_idx;
+-        usec_t newest_mtime;
++        uint64_t newest_entry_offset;
++        uint8_t newest_state;
+ } JournalFile;
+ 
+ typedef enum JournalFileFlags {
+diff --git a/src/libsystemd/sd-journal/sd-journal.c b/src/libsystemd/sd-journal/sd-journal.c
+index 5a8c8a8579..d7136d250e 100644
+--- a/src/libsystemd/sd-journal/sd-journal.c
++++ b/src/libsystemd/sd-journal/sd-journal.c
+@@ -2428,11 +2428,10 @@ static int journal_file_read_tail_timestamp(sd_journal *j, JournalFile *f) {
+ 
+         /* Tries to read the timestamp of the most recently written entry. */
+ 
+-        r = journal_file_fstat(f);
+-        if (r < 0)
+-                return r;
+-        if (f->newest_mtime == timespec_load(&f->last_stat.st_mtim))
+-                return 0; /* mtime didn't change since last time, don't bother */
++        if (f->header->state == f->newest_state &&
++            f->header->state == STATE_ARCHIVED &&
++            f->newest_entry_offset != 0)
++                return 0; /* We have already read archived file. */
+ 
+         if (JOURNAL_HEADER_CONTAINS(f->header, tail_entry_offset)) {
+                 offset = le64toh(READ_NOW(f->header->tail_entry_offset));
+@@ -2443,6 +2442,8 @@ static int journal_file_read_tail_timestamp(sd_journal *j, JournalFile *f) {
+         }
+         if (offset == 0)
+                 return -ENODATA; /* not a single object/entry, hence no tail timestamp */
++        if (offset == f->newest_entry_offset)
++                return 0; /* No new entry is added after we read last time. */
+ 
+         /* Move to the last object in the journal file, in the hope it is an entry (which it usually will
+          * be). If we lack the "tail_entry_offset" field in the header, we specify the type as OBJECT_UNUSED
+@@ -2452,6 +2453,7 @@ static int journal_file_read_tail_timestamp(sd_journal *j, JournalFile *f) {
+         if (r < 0) {
+                 log_debug_errno(r, "Failed to move to last object in journal file, ignoring: %m");
+                 o = NULL;
++                offset = 0;
+         }
+         if (o && o->object.type == OBJECT_ENTRY) {
+                 /* Yay, last object is an entry, let's use the data. */
+@@ -2469,10 +2471,11 @@ static int journal_file_read_tail_timestamp(sd_journal *j, JournalFile *f) {
+                         mo = le64toh(f->header->tail_entry_monotonic);
+                         rt = le64toh(f->header->tail_entry_realtime);
+                         id = f->header->tail_entry_boot_id;
++                        offset = UINT64_MAX;
+                 } else {
+                         /* Otherwise let's find the last entry manually (this possibly means traversing the
+                          * chain of entry arrays, till the end */
+-                        r = journal_file_next_entry(f, 0, DIRECTION_UP, &o, NULL);
++                        r = journal_file_next_entry(f, 0, DIRECTION_UP, &o, offset == 0 ? &offset : NULL);
+                         if (r < 0)
+                                 return r;
+                         if (r == 0)
+@@ -2494,7 +2497,8 @@ static int journal_file_read_tail_timestamp(sd_journal *j, JournalFile *f) {
+         f->newest_monotonic_usec = mo;
+         f->newest_realtime_usec = rt;
+         f->newest_machine_id = f->header->machine_id;
+-        f->newest_mtime = timespec_load(&f->last_stat.st_mtim);
++        f->newest_entry_offset = offset;
++        f->newest_state = f->header->state;
+ 
+         r = journal_file_reshuffle_newest_by_boot_id(j, f);
+         if (r < 0)
diff --git a/debian/patches/lpNNNNNNN-sd-journal-make-journal_file_read_tail_timestamp-notify-to-the-caller.patch b/debian/patches/lpNNNNNNN-sd-journal-make-journal_file_read_tail_timestamp-notify-to-the-caller.patch
new file mode 100644
index 0000000000..5de4509f9f
--- /dev/null
+++ b/debian/patches/lpNNNNNNN-sd-journal-make-journal_file_read_tail_timestamp-notify-to-the-caller.patch
@@ -0,0 +1,54 @@
+From: Yu Watanabe <watanabe.yu+github@gmail.com>
+Date: Wed, 3 Jan 2024 04:28:03 +0900
+Subject: sd-journal: make journal_file_read_tail_timestamp() notify to the caller that some new journal entries added
+Origin: upstream, https://github.com/systemd/systemd/commit/51b2bcf8356b847e7ab778adfad930691713c7ef
+Bug: https://github.com/systemd/systemd/issues/31486
+Bug-Ubuntu: https://bugs.launchpad.net/ubuntu/+source/systemd/+bug/NNNNNNN
+
+Tiny optimization for journal_file_find_newest_for_boot_id().
+
+(cherry picked from commit 51b2bcf8356b847e7ab778adfad930691713c7ef)
+---
+diff --git a/src/libsystemd/sd-journal/sd-journal.c b/src/libsystemd/sd-journal/sd-journal.c
+index d7136d250e..f082f3f6f9 100644
+--- a/src/libsystemd/sd-journal/sd-journal.c
++++ b/src/libsystemd/sd-journal/sd-journal.c
+@@ -449,6 +449,11 @@ static int journal_file_find_newest_for_boot_id(
+                 r = journal_file_read_tail_timestamp(j, f);
+                 if (r < 0)
+                         return log_debug_errno(r, "Failed to read tail timestamp while trying to find newest journal file for boot ID %s.", SD_ID128_TO_STRING(id));
++                if (r == 0) {
++                        /* No new entry found. */
++                        *ret = f;
++                        return 0;
++                }
+ 
+                 /* Refreshing the timestamp we read might have reshuffled the prioq, hence let's check the
+                  * prioq again and only use the information once we reached an equilibrium or hit a limit */
+@@ -2490,6 +2495,17 @@ static int journal_file_read_tail_timestamp(sd_journal *j, JournalFile *f) {
+         if (mo > rt) /* monotonic clock is further ahead than realtime? that's weird, refuse to use the data */
+                 return -ENODATA;
+ 
++        if (offset == f->newest_entry_offset) {
++                /* Cached data and the current one should be equivalent. */
++                if (!sd_id128_equal(f->newest_machine_id, f->header->machine_id) ||
++                    !sd_id128_equal(f->newest_boot_id, id) ||
++                    f->newest_monotonic_usec != mo ||
++                    f->newest_realtime_usec != rt)
++                        return -EBADMSG;
++
++                return 0; /* No new entry is added after we read last time. */
++        }
++
+         if (!sd_id128_equal(f->newest_boot_id, id))
+                 journal_file_unlink_newest_by_boot_id(j, f);
+ 
+@@ -2504,7 +2520,7 @@ static int journal_file_read_tail_timestamp(sd_journal *j, JournalFile *f) {
+         if (r < 0)
+                 return r;
+ 
+-        return 0;
++        return 1; /* Updated. */
+ }
+ 
+ _public_ int sd_journal_get_realtime_usec(sd_journal *j, uint64_t *ret) {
diff --git a/debian/patches/series b/debian/patches/series
index 4f24859f04..2ca3cca832 100644
--- a/debian/patches/series
+++ b/debian/patches/series
@@ -95,3 +95,5 @@ lp2088163-copy-introduce-COPY_VERIFY_LINKED-flag.patch
 lp2088163-journal-file-util-use-the-file-descriptor-of-journal-file.patch
 lp2088163-journal-file-util-use-COPY_VERIFY_LINKED.patch
 lp2088163-test-add-test-cases-for-journal-corruption-on-btrfs.patch
+lpNNNNNNN-sd-journal-cache-last-entry-offset-and-journal-file-state.patch
+lpNNNNNNN-sd-journal-make-journal_file_read_tail_timestamp-notify-to-the-caller.patch
-- 
2.43.0
```
