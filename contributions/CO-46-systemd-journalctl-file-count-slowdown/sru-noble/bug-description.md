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

[ Other Info ]

 - PR #30209 was opened during the v255 release freeze, and its description says "this is not a v255
   material". It also contains four commits that are not proposed here:
    - bd1af1d5fb and f7f062bf9f, a new SD_JOURNAL_ASSUME_IMMUTABLE flag and its use;
    - cb2b0326ee, internal data structure changes;
    - 63d2c7554e, an output path change.
   The two proposed commits do not depend on them: they apply unchanged, and
   [OPEN: the package build's own tests, result to be filled in from the test build].
 - Two later upstream changes in this area are not proposed either: 8f8ab4bf98 (rate-limited tail
   refresh, v262) and 79e32e7c73 (not yet released). They are not in the development release, and on
   255.4 they gave no measurable gain on top of the two commits.
 - The development release already has the fix (261.3), as do 25.04, 25.10 and 26.04.
 - Measured on that machine, in a container as well, the gains looked larger (15-77 times), because a
   container makes each system call dearer. The figures above are the host's.
