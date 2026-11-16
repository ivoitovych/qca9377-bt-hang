# 4G: how many journal files does a default noble desktop accumulate?

Short answer: at defaults the journal directory is held at about **100 files in total** (active and archived files, system
and per-user together) by `SystemMaxFiles=100`; the size limits alone would keep it far lower (about 8 to 32 full-size
files). A typical single-user desktop sits well below the ceiling, roughly **10 to 40 files**; reaching **50 to 100**
needs many small files, which come from sources other than size (many users, unclean shutdowns, hash-table rotation,
restarts, manual rotation) or from raised limits. Values below are read from the systemd 255.4-1ubuntu8.19 source
(`<work dir>/pkg/x819/s`, the unpatched tree of the stock package) and its man page; the file-count ranges are estimates
from those rules plus the public reports listed at the end, not a measurement of a population of installs.

## What the code does (255.4)

| setting | default | source |
|---|---|---|
| `SystemMaxUse=` | 10% of the file system, clamped to 1 MiB .. 4 GiB | `journal-file.c` (`journal_default_metrics`: `fs_size / 10`, `MAX_USE_UPPER` = 4 GiB) |
| `SystemKeepFree=` | 5% of the file system, at most 4 GiB | same function (`KEEP_FREE_UPPER`) |
| `SystemMaxFileSize=` | `SystemMaxUse / 8`, at most 128 MiB | same (`MAX_SIZE_UPPER` = 128 MiB) |
| `SystemMaxFiles=` | 100 | `DEFAULT_N_MAX_FILES`; man page: "only archived files are deleted to reduce the number of files ... active files will stay around" |
| `MaxFileSec=` | 1 month | `journald-server.c:68` (`DEFAULT_MAX_FILE_USEC`) |
| `MaxRetentionSec=` | 0 (off) | man page |
| `SplitMode=` | `uid`: one `user-<uid>.journal` per login user with an own file, in the same directory | man page |

How the limit counts (`journal-vacuum.c`, `journal_directory_vacuum`, called per directory `/var/log/journal/<machine id>`):
a file whose name has no `@<seqnum id>-<seqnum>-<realtime>` suffix is an active file and is counted in `n_active_files`
and never deleted; each archived `*@....journal` (and each disposed `*.journal~`) is a candidate; the oldest candidate is
deleted while `n_active_files + remaining candidates > n_max_files` (or the size or retention limit is exceeded). So the total
settles at **100 when vacuuming has run**, and can exceed it only by active files that cannot be deleted. User files and
system files share that one budget. Vacuuming runs when journald rotates, not continuously.

Consequence for file counts at the size limits: on a file system of 40 GB or more `SystemMaxUse` is 4 GiB and files are
128 MiB at most, so a journal that rotates only because files fill up holds about 32 files; on a 20 GB file system 2 GiB
and about 16 files; on 8 GB about 800 MiB and 8 files. The 100-file ceiling is therefore reached only when files are
rotated well before they are full.

## What makes files small (more files for the same space)

* **Time**: `MaxFileSec=1month` rotates each active file monthly (a system file and each user file). A machine used for a
  year without other causes: about 12 files per uid.
* **Unclean shutdown**: a file still marked online at the next start is renamed to `*.journal~` (`journal_file_dispose`, the
  rename in `journal-file.c` around line 4398) and a new one is started. Each power loss or hard reset leaves one.
* **Hash-table fill**: journald rotates a file when its data hash table is 75% full ("Data hash table ... has a fill level at
  75.0 ... suggesting rotation", "Journal header limits reached ... rotating"), long before 128 MiB for log-heavy small-entry
  workloads; the public 2024 report below shows 17 MB and 58 MB files from this.
* **Restarts and upgrades**: a journald restart onto a file with an older header can rotate (`header out-of-date`); manual
  `journalctl --rotate` (used by log-collecting tools) adds one each time.
* **Users**: `SplitMode=uid` gives every uid with journal traffic its own file(s); a single-user desktop has `user-1000` plus
  occasionally others (display manager, guest); a shared server can have hundreds (below).

Estimated range for a default single-user noble desktop: a system file and one user file active, plus archives from monthly
rotation and from any unclean shutdowns: typically 5 to 40 files after a year; with frequent crashes or hard resets, or heavy
log volume that fills the hash table early, 50 to the 100 ceiling is plausible. Our model sets of 25, 50 and 100 files
(Part 3) therefore represent a lived-in or crash-prone default install; 150 files is above what defaults allow.

## The test laptop is not a default install

Its journal directory held 492 files, but its journald configuration is non-default (`SystemMaxFiles=1000`,
`SystemMaxUse=16G`, `SystemKeepFree=20G`, set for an investigation). At defaults its ceiling would be about 100 files.
Its file count is therefore not evidence of what an unmodified install reaches.

## Public data on real counts (read-only web reads; the pages are kept as text in the work directory, not committed)

| source | what it shows |
|---|---|
| systemd-devel, "Empty journal files consume space", 2024-02-01 (https://lists.freedesktop.org/archives/systemd-devel/2024-February/049980.html) | a server with 1044 `user-*.journal` files, 8.1 GB of archived plus active journals, a 17 MB active system file rotating on hash-table fill; the many-users case (limit settings not shown) |
| systemd-devel, "slowness reading persistent journal", 2025-05-06/07 (https://lists.freedesktop.org/archives/systemd-devel/2025-May/051391.html) | systemd 254 on SLES with fewer than 20 files; `strace -c`: 41,230,003 `fstat` calls, 99.94% of syscall time (64 s), i.e. the per-line file walk the 2024 commits address, at under 20 files |
| systemd-devel, "How to scale journald correctly?", 2018-07 (https://lists.freedesktop.org/archives/systemd-devel/2018-July/041042.html) | an operator raised `SystemMaxFileSize=20G` to limit the number of files, because journalctl scales with the file count (maintainer: "O(n) where n is the number of split out files") |
| systemd-devel, "Why is journalctl -b so slow?", 2020-11 (https://lists.freedesktop.org/archives/systemd-devel/2020-November/045619.html) | a user asks about slow `journalctl -b` and the file count; no figure |
| `journald.conf(5)` of 255 (`journald-conf-man`) | the semantics above |

No Launchpad, Debian or GitHub report with a count for an unmodified Ubuntu desktop was found in the reads made here; the
range above is derived from the rules, and the two server reports show that 20 to 1000+ files occur in practice.

## Reading for the SRU

The slowdown is already visible below 20 files (2025 report). A default desktop's files cluster in the 10 to 40 range and can
reach 100; the benefit grows with the file count, so the bug matters at the sizes defaults produce, and the 100-file
ceiling is what bounds the worst case on an unmodified install.
