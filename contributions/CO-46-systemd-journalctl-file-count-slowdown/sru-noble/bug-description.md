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
