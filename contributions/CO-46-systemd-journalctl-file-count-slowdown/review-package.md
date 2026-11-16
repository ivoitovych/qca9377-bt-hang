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


## `README.md`

```
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
```


## `bug-description.md`

```
# Launchpad bug: title and description

Package: systemd (Ubuntu). Series task: Noble. Tag: `noble`.

**Title:**
journalctl performs excessive per-file stat calls when reading multi-file journals

---

[ Impact ]

On noble's systemd 255.4, reading the journal costs fstat() calls on every open journal file for each
entry printed. `journal_file_read_tail_timestamp()` re-checks each file's tail through fstat() and the
file's mtime on every step of the merge across files. With 100 journal files open, a measured
`journalctl` made 540 to 560 fstat-family system calls per printed line. Every other reader that uses
the same sd-journal code is affected too.

The effect is that retrieving a journal for diagnosis becomes slow. A completed example on a host (not
a container), 100 archived files of a synthetic journal modelled on a default install (system and user
files; 4.2 million lines), `journalctl -b all`: 907.8 s with 255.4-1ubuntu8.19 and 83.8 s with the same
package plus the two commits below. The same query on system files only (4.8 million lines) took
1098.3 s and 93.1 s. Nothing was cut short and no figure is projected:

  files   mixed 8.19 -> patched          system only 8.19 -> patched
     25    42.9 s ->  8.3 s ( 5.1x)       54.6 s -> 10.5 s ( 5.2x)
     50   195.4 s -> 24.2 s ( 8.1x)      249.6 s -> 30.2 s ( 8.3x)
    100   907.8 s -> 83.8 s (10.8x)     1098.3 s -> 93.1 s (11.8x)

At 100 files, apport's `journalctl --quiet -b -a --system` took 23.6 s against 2.9 s, and sos's
`journalctl --no-pager --reverse`, cut at its 100 MB limit, 220 s against 19.6 s (233.8 s on system
files only, against sos's own 300 s command limit). One run per figure.

Upstream fixed the system calls in v256 with two commits from https://github.com/systemd/systemd/pull/30209:

 - 99e6f682d3627c2c06d99bb3c3756e448e8d9bd1 "sd-journal: cache last entry offset and journal file state"
 - 51b2bcf8356b847e7ab778adfad930691713c7ef "sd-journal: make journal_file_read_tail_timestamp() notify to
   the caller that some new journal entries added"

The file's state and tail-entry offset are read from the header, which is always mapped, instead of
calling fstat(). An archived file whose tail has been read is not checked again. Under `strace -c -f`
with 100 files, printing 3 000 or 30 000 lines, 8.19 made 540 to 560 fstat-family calls per printed
line (16.2 to 16.8 million in 30 000 lines); the patched package made 355 in total, whatever the number of
lines printed.

Both commits are in every upstream release since v256, and in Ubuntu since 24.10. They are not in
noble, in noble-proposed (8.19) or in upstream's v255-stable. They apply to 255.4-1ubuntu8.18 and to
8.19 unchanged.

Additional evidence, a machine whose own settings keep 479 files (`SystemMaxUse=16G`,
`SystemMaxFiles=1000`): `journalctl -b` printed 4.5 million lines in 48 s patched; the 8.18 binary was
capped at 120 s at 2 678 lines/s, and the time it would need, about 28 minutes, is an estimate from that
rate. Measured rates for 25 to 800 files are in the evidence attachment.

File counts. `SystemMaxFiles=100` limits the total number of journal files in a directory, active
files included; only archived files can be deleted to meet it. The default size limits would on their
own keep about 8 to 32 full-size files; a directory approaches 100 files through many small files
(unclean shutdowns, monthly rotation, hash-table rotation, many users). The 25, 50 and 100 file rows are
a relevant range under the default limit, not what every installation reaches (derivation and public
reports in the evidence attachment).

Upstream issue https://github.com/systemd/systemd/issues/31486 describes a broader scaling problem with
the number of files; these two commits do not fix it, they remove the system calls only. An independent
2023 report measured about 10 times from caching the same tail timestamps:
https://github.com/systemd/systemd/pull/29366.

[ Test Plan ]

The reproducer is attached (journalctl-file-scaling-repro.sh). It needs no root and installs nothing.
It writes synthetic journal files into one `mktemp -d` directory, using systemd-journal-remote
without a daemon. It reads them only with `journalctl --directory=`, removes the directory at the end,
and never touches /var/log/journal or journald. Each run takes a few minutes.

1. Install `systemd-journal-remote` and `strace`, if they are not installed. Run
   `./journalctl-file-scaling-repro.sh /usr/bin/journalctl` and keep the output.
2. Upgrade systemd and its binary packages from noble-proposed. Run the same command again.
3. Expected: the patched lines/s is several times the 8.19 figure from K = 50 upward (in the attached
   reference run, K = 100 went from 1 411 to 89 837 lines/s; absolute figures differ between machines).
   The structural check does not depend on the machine: copy 100 journal files as in step 4, run
   `strace -c -f -o /tmp/s.txt journalctl --directory=<copies> --no-pager -o cat -n 3000 > /dev/null`
   before and after the upgrade, and compare the fstat, newfstatat and statx counts in /tmp/s.txt. They
   fall from about 1.6 million to a few hundred.
4. Same output, on a frozen dataset. Make independent copies of a fixed set of archived files, once:
   `mkdir ~/frozen && cp -- $(ls /var/log/journal/*/system@*.journal | head -n 25) ~/frozen/`
   (copies, not hard links; vacuuming can deallocate an original), then `cd ~/frozen && sha256sum *.journal > files.sha256`.
   Before the upgrade run `./compare-frozen.sh ~/frozen before.tsv`, after it `./compare-frozen.sh ~/frozen after.tsv`
   (attached). The script runs `-o export` forward and reversed, `--list-boots`, `-b`, `-k -b` and `-n 100`
   on that directory only, and exits non-zero if a query failed or printed nothing; `diff before.tsv
   after.tsv` must print nothing, and `sha256sum -c files.sha256` must still pass.
5. Files being written. Run `journalctl -f -o cat` in one terminal. In another run
   `tag=sru-test-$(date +%s); for i in $(seq 1 2000); do logger -t "$tag" "n=$i"; done; sudo journalctl --rotate`
   (a new tag for each run, so the run before the upgrade does not count).
   Every line must appear at once, and afterwards `journalctl -o cat -t "$tag" | sort | uniq -c | awk '$1 != 1'` must print
   nothing and `journalctl -o cat -t "$tag" | wc -l` must print 2000. Also check that `journalctl -b` and `journalctl -b -1`
   show the same entries as before the upgrade.
6. The systemd autopkgtests: pending. No result exists yet; the results will be added to this bug.

[ Where problems could occur ]

The change is in how sd-journal decides that a file's newest entry (timestamp and boot ID) must be
read again.
 - Before: whenever the file's mtime changed, found through fstat().
 - After: when the tail-entry offset or the file's state in the header changes. An archived file is
   read once.

If that decision were wrong for a file still being written, the newest timestamp kept for a boot
would be stale. compare_boot_ids() uses those timestamps to order entries from different boots, so the
visible effect would be entries from different boots in the wrong order when files are merged. It
could also make `-b` or `--list-boots` pick the wrong boot, or `-f` show new entries late. This was
tested on the exact packages (8.19 against 8.19 plus the two commits; evidence sections 1 and 2): a
booted noble guest with journald writing two numbered streams of 24 000 lines through size rotations and
`journalctl --rotate`, read by a concurrent `journalctl -f` and a later full read, showed no omission,
duplicate or reordering in either build; files in the older format (no `tail_entry_offset`, written by
systemd 249) read identically and the fallback branch was seen to run; imported and merged journals (five
fixtures varying the header machine ID and the entry `_MACHINE_ID`) read identically; frozen copies of 4
fixtures gave identical output in 36 comparisons.

Archived files can disappear or change while a reader has them open: v255.4's vacuum calls
unlinkat_deallocate(), which unlinks a file and then hole-punches or truncates it. The per-entry
fstat() of 8.19 was not a complete barrier against that either, but the patched code detects a change
at a different moment, so this was measured rather than argued. On disposable fixtures, 16 archived
files, with a reader (journalctl forward, reverse and following, and a small sd-journal program,
forward and reverse) consuming slowly while files were removed by plain unlink, by hole punching and by
truncation, in about 1 400 runs:
 - plain unlink: no error and no lost entry in either build;
 - a file ahead of the reader hole-punched or truncated: `journalctl` exits 1 with "Failed to iterate
   through journal: Bad message" in both 8.19 and the patched build (for example, forward with a
   truncated next file: 20 of 26 runs stock, 18 of 26 patched);
 - a truncated file that a reader has mapped: a program using sd-journal without a SIGBUS handler is
   killed by SIGBUS, in both builds at similar rates (17 of 56 runs stock, 21 of 56 patched; not
   significantly different, p = 0.55). The library does not install the handler; `journalctl` and
   journald do, and `journalctl` was not killed in any run.
No cell differed between 8.19 and the patched build at p < 0.05. Upstream commit 101b8633c2 ("journal:
recover iteration over vacuumed files", 2026) handles failures after an entry was already selected; it
is not part of these two commits, it is not included in this request, and neither build tested here has
it. These tests are on synthetic fixtures of 16 files; they show no difference, not the absence of the
failures that both builds share.

The second commit adds one new error, -EBADMSG. It is returned in one place, after the tail entry has
been read by a fallback path (the header offset could not be used, or the header's own tail timestamp was
used) and the offset found equals the cached one but the cached boot ID, timestamps or machine ID differ.
In the ordinary path, where the header's tail-entry offset equals the cached one, the function returns
earlier and never reads the entry, so a tail entry rewritten at the same offset is not detected there.
compare_boot_ids() treats any error as "no answer" and falls back to comparing realtime timestamps; the
other callers ignore the result.

The library code is shared: libsystemd0 gets the same change as journalctl. Other programs that read
the journal through sd-journal take the same path.

Both commits have been in upstream releases since v256 (June 2024), and in Ubuntu since 24.10. No
follow-up that these commits require was identified in the inspected upstream history (commit
messages searched for the hashes and for Fixes: trailers, and the later changes to the file read). That
search cannot prove none exists. Later changes that touch the area are listed separately under Other Info.

The only journal patch in 8.19 (lp2088163-sd-journal-use-stat_verify_linked.patch) changes how
journal_file_fstat() tests for a deleted file and still returns -EIDRM for it. That does not show that
a deletion is noticed at the same time as before; the measurements above are what covers that.

[ Other Info ]

 - PR #30209 was opened during the v255 release freeze, and its description says "this is not a v255
   material". It also contains four commits that are not proposed here:
    - bd1af1d5fb and f7f062bf9f, a new SD_JOURNAL_ASSUME_IMMUTABLE flag and its use;
    - cb2b0326ee, internal data structure changes;
    - 63d2c7554e, an output path change.
   No dependency of the two proposed commits on them was found. The two commits are consecutive in the PR.
    - They apply to 255.4-1ubuntu8.19 without fuzz.
    - The package builds.
    - All journal unit tests of the package build pass (test-journal, -interleaving, -enum, -verify,
      -flush, -file, test-mmap-cache).
    - In a container build, test-fd-util and test-capability failed, and they fail the same way on
      unpatched 8.19 in that container.
    - A build in a Launchpad PPA on all architectures has not been made yet; the autopkgtests have not
      been run. Both are pending.
 - Later upstream changes in this area that are not proposed:
    - 8f8ab4bf98 (rate-limited tail refresh, v262) and 79e32e7c73 (not yet released): they gave no
      measurable gain on top of the two commits on 255.4.
    - 101b8633c2 (recover iteration over vacuumed files): see Where problems could occur.
    - ae940730c6, "sd-journal: prefer machine ID from the tail entry" (v262). Journals imported with
      systemd-journal-remote carry the receiving machine's ID in the file header and the originating
      machine's ID in the entries; compare_boot_ids() then treats them as one machine and groups entries
      by boot instead of interleaving them by time. The defect exists in 255.4 without these commits
      and the patched build gives the same order as 8.19 (checked on fixtures that vary the header ID and
      the entry ID), so these commits neither cause nor fix it. It is not included: it changes the
      ordering of existing output, which is a separate decision from this fix.
 - The development release already has the fix (261.3), as do 25.04, 25.10 and 26.04.
 - Measured in a container, the 8.19 baseline was slower than on the host and the gains looked larger; the
   cause was not isolated. Those figures are in the evidence attachment as reproducibility information
   only; the figures in Impact are the host's.
```


## `evidence.md`

````
# Measurements: journalctl on noble with and without the two v256 commits

Everything here was measured in November 2026. Only numbers are given; journal messages are not
shared. Raw records (commands, termination conditions, per-run rows) are in the branch
`research/journalctl-file-scaling` of the repository this request was prepared in, under the paths
named for each section. "Stock" is 255.4-1ubuntu8.19 from noble-proposed (downloaded; hashes in
`results/journalctl-noble-sru-verification-2026-11-16/scripts/PACKAGES.txt`); "patched" is the exact
test packages built from 8.19 plus 99e6f682d3 and 51b2bcf835 (version 255.4-1ubuntu8.20, same file). Where
an older section below used 8.18, it says so.

## 1. Headline: completed host runs on frozen copies (stock 8.19 against patched)

Path: `results/journalctl-noble-sru-verification-2026-11-16/4F-host-headline-numbers/` (`README.md`,
raw rows `4F.tsv`, scripts `host-4F.sh`, `prep-4F.py`).

| item | value |
|---|---|
| where | the host itself, no container; the unpacked packages run with `LD_LIBRARY_PATH`, nothing installed |
| data | independent copies (`cp`) of a synthetic journal modelled on a default noble install: `mixed-N` = the N newest files of system and user files together, `sys-N` = the N newest system files; N = 25, 50, 100 |
| load | one run at a time, `nice -n 19 ionice -c 3`; one run per query and build |
| termination | each query ended by itself; cap 7200 s per run, 300 s for the sos commands (sos's own limit); no cap was hit; exit status 141 is SIGPIPE from the 100 MB cut |

`journalctl -b all` (full read), wall seconds:

| files | mixed stock | mixed patched | x | system-only stock | system-only patched | x | lines (mixed / system) |
|---|---|---|---|---|---|---|---|
| 25 | 42.85 | 8.33 | 5.1 | 54.56 | 10.51 | 5.2 | 1 038 001 / 1 200 002 |
| 50 | 195.39 | 24.24 | 8.1 | 249.61 | 30.17 | 8.3 | 2 094 003 / 2 400 004 |
| 100 | 907.79 | 83.75 | 10.8 | 1098.30 | 93.11 | 11.8 | 4 188 006 / 4 800 009 |

Other queries at 100 files (wall seconds, stock / patched): `-b` mixed 47.45 / 6.54, system 37.53 / 4.64;
`-k -b all` mixed 20.22 / 3.92, system 43.87 / 7.90; apport's `--quiet -b -a --system` mixed 23.61 / 2.91,
system 36.58 / 3.39; sos's `--no-pager --reverse` (first 100 MB) mixed 220.20 / 19.59, system 233.77 /
19.63; sos's `--boot --reverse` mixed 48.78 / 7.13, system 37.87 / 4.34; `--boot -1 --reverse` mixed
48.66 / 7.62, system 37.87 / 4.40. `--disk-usage` and `--list-boots` take under 0.5 s in both builds and
are not claimed to gain: ten alternating runs per build of `--list-boots` (`4F-listboots.tsv`) gave
sys-100 0.081 s stock, 0.076 s patched, and a first single run that looked slower patched was a cold-cache
effect. Output line or byte counts were equal for every pair; all exit statuses as expected.

**Structural check** (`strace -c -f`, host, 100 files, `-o cat -n N`; `4F-strace.tsv`, `strace/`):

| set | build | lines printed | fstat-family calls | all system calls | fstat-family per printed line |
|---|---|---|---|---|---|
| sys-100 | stock | 3 000 | 1 680 174 | 1 682 527 | 560 |
| sys-100 | stock | 30 000 | 16 800 174 | 16 803 407 | 560 |
| sys-100 | patched | 3 000 | 355 | 2 708 | 0 |
| sys-100 | patched | 30 000 | 355 | 3 588 | 0 |
| mixed-100 | stock | 3 000 | 1 620 185 | 1 625 711 | 540 |
| mixed-100 | stock | 30 000 | 16 200 185 | 16 255 759 | 540 |
| mixed-100 | patched | 3 000 | 355 | 5 881 | 0 |
| mixed-100 | patched | 30 000 | 355 | 55 929 | 0 |

(fstat family: fstat, newfstatat, statx, fstatfs.) A time ratio is a property of one machine; this count
is not.

## 2. Equivalence and safety checks on the exact packages (stock 8.19 against patched)

Each comparison checks that both journalctl runs exit 0, that the output is not empty where output is
expected, and then compares sha256. Paths are under `results/journalctl-noble-sru-verification-2026-11-16/`.

| check | path | result |
|---|---|---|
| frozen copies: 4 fixtures (30 + 30 synthetic files, a 25-file system+user model, 12 archived files of a real journal), 9 queries each: `-o export` forward and `-r`, `--list-boots`, `-b`, `-k -b`, `-u`, `-n 100`, `-n 100 -r`, `-o export -n 100` | `4A-frozen-dataset-equivalence/` (names and sha256 of the copies in `FIXTURE-SHA256.txt`; the real-journal copies were deleted afterwards) | 36 of 36 identical |
| booted noble guest (QEMU/KVM, noble cloud image), journald writing and rotating (`SystemMaxFileSize=1M`, three `journalctl --rotate` per phase), two numbered streams of 24 000 lines (system service and user session), concurrent `journalctl -f` and a later full read; stock phase, then the patched packages installed over it | `4C-booted-noble-vm/` | every number once and in order in both readers, in both phases (8 of 8 stream/reader results); `journalctl --verify` 38 of 38 and 76 of 76 files; final static journal identical in `-o export`, `-o export -r`, `-o cat -a` |
| older format: 12 files written by systemd 249 (header_size 256, no `tail_entry_offset`), a mixed set (6 old, 6 new) and a new-format set; 7 queries each | `4D-old-journal-format/` | 21 of 21 identical; under a debugger the patched build called `journal_file_read_tail_timestamp` with header_size 256 on every call for the old files (264 calls), 96 old and 168 new for the mixed set |
| imported and merged journals: 3 originating machines, 6 boots with overlapping ranges, 24 files; 5 fixtures that vary the header machine ID (one receiver ID, the entries' IDs, unrelated IDs per file, swapped IDs) and the entry `_MACHINE_ID`; 9 queries each | `4E-imported-merged-journals/` | 45 of 45 identical |
| archived files removed under an open reader | `4B-archived-files-under-open-reader/` | section 3 |

**The "two machine IDs" fixture.** The fixture named `twomachines` that was used earlier (section 6)
varied only the entries' `_MACHINE_ID` (two values); every file header carried the one ID the
writer, systemd-journal-remote, gives it (receiver ID; measured: 1 distinct header ID, 2 distinct entry IDs,
40 files). It therefore did not exercise the case of different header IDs. The 4E fixtures do, and
document for each fixture how many distinct header IDs and entry IDs it holds.

**Order against the true order (4E).** `-o cat` output was compared with the entries' realtime order.
Where one header ID covers several entry machine IDs (the shape journal-remote produces), stock 8.19 does
not print the true order (5 adjacent inversions among 9 600 entries, longest displacement 1 999) and the
patched build prints exactly the same sequence. All other 4E fixtures print the true order in both. This
is the ordering defect that upstream ae940730c6 (v262) fixes; it exists without the two commits, and
ae940730c6 was deliberately not added. Equal output proves equivalence, not correct ordering.

## 3. Archived files removed while a reader has them open

Path: `4B-archived-files-under-open-reader/` (`README.md`, raw rows `4B.tsv`, `4B3.tsv`, `4B4.tsv`,
statistics `4B-stats.txt`, scripts `run4B.py`, `reader.c`, `inside-4B*.sh`).

Method: a fixture of 16 archived files (600 entries each), freshly copied for every run (own inodes);
a reader consumes slowly and, after a random number of entries (K), the victim files are removed. Readers:
`journalctl -o export` forward, with `-r`, and `-f`; and a small sd-journal program (forward, backward),
each linked against the build's own libsystemd. Removals: `unlink`; the deallocation of
`unlinkat_deallocate()` of v255 (open for writing, unlink, hole-punch with KEEP_SIZE); `truncate` (unlink,
then truncate to 0, the fallback of `unlinkat_deallocate()`). Victims: the file being read, the next one,
the one after that, the previous one. About 1 400 runs in all; one run ends when the reader exits or after
30 s without output (4 s for the follower).

| case | stock 8.19 | patched |
|---|---|---|
| `unlink`, any victim, any reader | exit 0, no lost entry | same |
| `journalctl -o export`, next file hole-punched (`dealloc`) | 22 of 26 runs exit 1, "Failed to iterate through journal: Bad message" | 20 of 26 |
| `journalctl -o export`, next file truncated | 20 of 26 exit 1 (same message) | 18 of 26 |
| `journalctl -o export -r`, next file truncated | 22 of 26 | 19 of 26 |
| sd-journal program, forward, current file truncated | 17 of 56 killed by SIGBUS | 21 of 56 (p = 0.55) |
| sd-journal program, backward, current file truncated | 10 of 26 | 4 of 26 (p = 0.12) |
| every other cell | no cell differs at p < 0.05 (Fisher exact test on failure counts, `4B-stats.txt`) | |

A first pass with six runs per cell had shown the forward program case as 0 of 6 failures for stock and 3 of 6
for patched; 56 runs per build showed it was timing. The failure there is the process killed by SIGBUS
(exit status -7): under gdb the patched build stops in `journal_file_read_tail_timestamp` at the read of the
mapped header (`sd-journal.c:2413` of the test source); the stock fault is in an unresolved function of
libsystemd (its debug symbols were not fetched). The library does not install a SIGBUS handler;
`journalctl` and journald do, and `journalctl` was not killed by SIGBUS in any run. Upstream 101b8633c2 is not
included in either build and was not tested. The `jc-follow` rows compare exit behaviour only: the harness stops
that reader after 4 s without output, so its entry counts are not complete in either build.

## 4. File counts at the default limits

Path: `4G-file-counts-at-defaults/README.md`. From the 255.4 source: `SystemMaxUse` 10% of the file system,
clamped to 1 MiB to 4 GiB (`journal-file.c`); `SystemMaxFileSize` that divided by 8, at most 128 MiB;
`SystemMaxFiles` 100, counted in `journal_directory_vacuum()` as `left = n_active_files + n_list - i`, so active
files count and only archived files are deleted; `MaxFileSec` one month; `SplitMode=uid`. At the size limits
alone a journal holds about 8 to 32 full-size files. The estimate that a default single-user desktop holds
roughly 10 to 40 files, and that 50 to 100 need many small files (unclean shutdowns, monthly rotation, hash-table
rotation, other users), is an estimate from those rules and public reports, not a measured population.
Public reports read: a server with 1 044 `user-*.journal` files (systemd-devel, 2024-02-01), a systemd 254
system with fewer than 20 files making 41 million fstat calls (2025-05), and a user raising
`SystemMaxFileSize=20G` to limit the number of files (2018-07). No count for an unmodified Ubuntu desktop was
found. The 479-file machine of sections 5 and 6 reaches its count through its own settings.

## 5. Earlier measurements: output rate and everyday queries (8.18 and patched, host)

These were made before the exact 8.19 packages existed, with 8.18 built from source, patched by applying the
two commits; they are kept as additional evidence. Records: `results/journalctl-file-scaling-host-2026-11-16/`
(`data/host-synthetic-summary.txt`, `data/host-real-summary.txt`, `data/queries-host.tsv`,
`data/queries-summary.txt`) and `results/journalctl-file-scaling-cause-2026-11-14/data/rates.tsv`.

| item | value |
|---|---|
| machine | Ubuntu 24.04.5, AMD Ryzen 7 5825U (8 cores, 16 threads), 30 GB RAM, NVMe, ext4 |
| installed systemd | 255.4-1ubuntu8.18 |
| its journal | 479 files, 15.9 GB; journald settings not the default: `SystemMaxUse=16G`, `SystemMaxFiles=1000` |
| binaries | **8.18**: the 255.4-1ubuntu8.18 source package built with meson, release mode. **patched**: the same tree plus the two commits. Run from a build directory with their own libsystemd-shared. Nothing was installed |
| synthetic journals | K archived files of 2 000 entries each, 5 files per boot, one machine ID, written by systemd-journal-remote |
| real journal | the newest K files of the machine's journal, passed as `--file=`, read only |
| one rate | `journalctl -o short --no-pager` on the K files, stopped after the first 200 000 lines or 45 s (synthetic), or 300 000 lines or 60 s (real); lines per second is lines over wall time; median of 3 runs. These are rates over a prefix of the output, not times for a complete read |

Lines per second:

| files | synthetic 8.18 | patched | x | real journal 8.18 | patched | x |
|---|---|---|---|---|---|---|
| 25 | 19 218 | 178 586 | 9.3 | 29 194 | 201 342 | 6.9 |
| 50 | 8 269 | 123 012 | 14.9 | 19 438 | 190 355 | 9.8 |
| 100 | 4 563 | 84 104 | 18.4 | 11 361 | 133 097 | 11.7 |
| 200 | 1 395 | 34 043 | 24.4 | 5 847 | 119 474 | 20.4 |
| 400 | 633 | 13 787 | 21.8 | 2 885 | 71 685 | 24.8 |
| 800 / 479 (all) | 308 | 5 603 | 18.2 | 2 292 | 56 894 | 24.8 |

The remaining cost per entry still grows with the number of files after the two commits, because each entry
still compares the position of every open file. That is the broader topic of upstream issue 31486 and is not
part of this request. (Earlier drafts fitted time against K with exponents; those fits come from capped or
prefix runs, are estimates, and are not used in the argument. The reference output of the reproducer
(section 7) still prints such an "exponent" line; read it the same way.)

Everyday queries on the 479-file machine (each capped at 120 s, run twice, median):

| query | 8.18 | patched |
|---|---|---|
| `journalctl -b` | capped at 120 s, 2 678 lines/s | 4.5 M lines in 48.2 s. The time 8.18 would need, about 28 min, is an estimate from its rate |
| `journalctl -k -b` | capped, 2 568 lines/s | 5.0 M lines in 53.9 s; estimate for 8.18 about 33 min |
| `journalctl -g <rare word>`, newest 25 files | 42.8 s | 2.33 s |
| `journalctl -u systemd-logind.service` | 0.29 s | 0.07 s |
| `journalctl -n 100` | 0.32 s | 0.10 s |
| `journalctl --list-boots` | 0.18 s | 0.15 s |

The journal is live and grew between runs, so `-b` and `-k -b` print different numbers of lines and the
two lines above should not be compared with each other; the headline in section 1 uses one frozen set. On
800 synthetic files: `-b` (10 000 entries) 7.07 s against 0.22 s, `--list-boots` 4.35 s against 0.56 s,
`-n 100` 0.52 s against 0.11 s.

## 6. Earlier same-output checks (8.18, 8.19, patched)

Records: `results/journalctl-file-scaling-verify-2026-11-15/` and `results/journalctl-sru-packaging-2026-11-16/`.
The patched build printed byte-identical `-o export` output to 8.18 in 36 comparisons on synthetic data and 2
on the machine's own journal (the newest 25 files, the first 600 000 export lines, forward and with `-r`).
Synthetic sets: 25 archived files in sequence, and archived files whose time ranges interleave; each read
forward and with `-r`, with `-n 500`, `-k`, a `_BOOT_ID=` match, `-b -3`, `--since`/`--until`, `-r --since`,
`--reverse -n 3000`, `--lines=+3000`, and `--cursor` and `--after-cursor`, forward and reverse, at two positions.
The built package (255.4-1ubuntu8.20) installed over 8.18 in a fresh ubuntu:24.04 container was compared with
stock 8.18 and stock 8.19 on four synthetic sets (plain, 12 overlapping boots, `twomachines` and the
reproducer's files), 14 kinds of query, 112 comparisons, all identical. A file still being written, fed
through systemd-journal-remote while `journalctl -f` read it, gave identical followed output (21 643 entries)
and final read (24 500). These do not replace section 2's checks on active journald, the archived-file
lifecycle, the older format and imported journals.

## 7. The same runs in a container (reproducibility information only)

On the same machine inside a container 8.18 ran 2 to 5 times slower than on the host while the patched build
ran at the same speed, so the gains look larger there (15 to 77 times). The cause of the slower baseline in
that container setup was not isolated, and these figures are not used in the Impact.

| files | synthetic 8.18 / patched | x | real journal 8.18 / patched | x |
|---|---|---|---|---|
| 25 | 6 843 / 177 319 | 25.9 | 14 714 / 227 017 | 15.4 |
| 100 | 899 / 68 729 | 76.5 | 4 493 / 146 994 | 32.7 |
| 400 | 229 / 13 471 | 58.8 | 1 251 / 77 419 | 61.9 |

**The reproducer (fresh ubuntu:24.04 container, unprivileged user, network off).** The script and its test
are in `reproducer/`; the output below is `reproducer/output.txt`: 1 000 entries per file, at most 100 000
lines or 40 s per run, median of 3 runs. Termination: the lines limit or the time limit, whichever comes
first; the "exponent" lines are fits to those capped runs, estimates, not measurements of a complete read.

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
52 entries, identical. No temporary directory was left behind. `journalctl --verify` on the reproducer's
400 files reported no failure. With the installed patched package, the reproducer gave 189 958 lines/s at 25
files and 11 567 at 400.

`reproducer/compare-frozen.sh` (new) is the frozen-dataset comparison of the Test Plan; it was tested on a
30-file synthetic directory with stock 8.19 and the patched build: identical output files, exit 0.
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


## `SHA256SUMS`

```
158ab063581416404e5091cc49f097ecf71cd6e409a099018609187ed93993af  ./README.md
049bba91ff1f2a92c3f9776c5b43c455b654e34596d91d4e9e26c2b34022ea0e  ./bug-description.md
7a2a322dd1257a2014cd5caad97c9c1df5f19c736c31d16701eef2e4aa36ebec  ./evidence.md
8c8e6852f9b1657ed30ecc7d12f0a0f10b5b52db3f190a8b2feb1a69a2df0c86  ./patches/debian-patches/lpNNNNNNN-sd-journal-cache-last-entry-offset-and-journal-file-state.patch
895f825a5b3bf3915a300fbc6ce3d193ac5098781977c64a25a7124d61ae12a5  ./patches/debian-patches/lpNNNNNNN-sd-journal-make-journal_file_read_tail_timestamp-notify-to-the-caller.patch
0927d12d0651cdeb2c887d29fb0776f5e52bf43004b48602a9ce829e54c78bf0  ./patches/systemd_255.4-1ubuntu8.19_to_8.20.debdiff
de55f2fabf99c22fe7c631087792ab6080512c24a1240c4b77747e37f73e8614  ./patches/ubuntu-noble-branch-commit.patch
0914194a4e6fae27ac5141f668fab19809721e7992ce5d825bf20c20d37232ef  ./reproducer/Dockerfile
6731e57ca2c9b37c21dd76a2a2eb4e01197ec52580c93d2afd2f75f0bcc65354  ./reproducer/compare-frozen.sh
a2e3ed13d90a66165a4a1de2fbf492cdc13afb20aaabdfa1368026274480c73e  ./reproducer/inside-repro-test.sh
c766375aee694fa50538e6e28e4c520cb0dae20ab8f9457ccf6504e0708b0d79  ./reproducer/journalctl-file-scaling-repro.sh
bf12c9b5e0a88c8d57c51fdbe019106220428e1b83013ae0de8ec3760fcb281a  ./reproducer/output.txt
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


## `reproducer/compare-frozen.sh`

```
#!/bin/bash
# compare-frozen.sh DIR OUT [JOURNALCTL]
#
# Runs a fixed list of read-only queries with JOURNALCTL (default: journalctl) on the journal files in DIR and
# writes one tab-separated line per query to OUT:
#   query, exit status, lines, bytes, sha256 of the output
# DIR must be a directory of independent COPIES of archived journal files (cp, not hard links), made once and
# used for both runs, so that rotation and vacuuming of the live journal cannot change the input. Run the
# script before and after the upgrade with the same DIR and compare the two OUT files with diff; they must be
# identical, and the script exits non-zero if any query failed or printed nothing (a pair of failed or empty
# exports would otherwise hash the same).
#
# Termination: every query ends when journalctl finishes; each is limited to CAP seconds (default 7200), exit
# status 124 meaning the limit was hit. Nothing is written outside OUT and a private temporary file.
set -u
DIR=${1:?usage: compare-frozen.sh DIR OUT [JOURNALCTL]}
OUT=${2:?usage: compare-frozen.sh DIR OUT [JOURNALCTL]}
JC=${3:-journalctl}
CAP=${CAP:-7200}
tmp=$(mktemp)
trap 'rm -f "$tmp"' EXIT
newest_boot=$($JC --directory="$DIR" --no-pager --list-boots 2> /dev/null | tail -n 1 | awk '{ print $2 }')
bad=0
: > "$OUT"
run() {
    local name=$1; shift
    local rc lines bytes sha
    timeout "$CAP" $JC --directory="$DIR" --no-pager "$@" > "$tmp" 2> /dev/null
    rc=$?
    lines=$(wc -l < "$tmp")
    bytes=$(wc -c < "$tmp")
    sha=$(sha256sum < "$tmp" | cut -c1-64)
    printf '%s\t%s\t%s\t%s\t%s\n' "$name" "$rc" "$lines" "$bytes" "$sha" >> "$OUT"
    if [ "$rc" -ne 0 ] || [ "$bytes" -eq 0 ]; then
        echo "INVALID: '$name' exit status $rc, $bytes bytes" >&2
        bad=1
    fi
}
run "-o export" -o export
run "-o export -r" -o export -r
run "--list-boots" --list-boots
run "-b newest boot" --boot="$newest_boot"
run "-k -b newest boot" -k --boot="$newest_boot"
run "-n 100" -n 100
run "-n 100 -r" -n 100 -r
run "-o export -n 100" -o export -n 100
exit $bad
```
