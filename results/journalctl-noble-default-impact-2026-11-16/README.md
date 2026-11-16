# What the 2024 journalctl fix changes on a default Ubuntu 24.04 install (2026-11-16)

Part 3 of three. Purpose: show what stops working, and what keeps working, when a stock noble `systemd`
(`255.4-1ubuntu8.18`) reads a journal that spans many files, against the same `journalctl` with the two 2024 upstream
commits (the `255.4-1ubuntu8.20` test build of the packaging work in
`../journalctl-sru-packaging-2026-11-16/`). Tools that read the journal for the user (`systemctl status`, apport, sos)
are included.

## 1. Setup

| item | value |
|---|---|
| machine | the laptop (16 cores); a container each time: a fresh `ubuntu:24.04` image, `--cpus=2`, `nice -n 19` and `ionice -c 3`, one container at a time; another experiment was running on the machine |
| stock | the archive's `systemd 255.4-1ubuntu8.18`, **installed** with `apt`, as on any default install: `/usr/bin/journalctl` |
| patched | the `255.4-1ubuntu8.20` test debs (`systemd`, `libsystemd-shared`) **unpacked, not installed**, run with `LD_LIBRARY_PATH` pointing at them |
| who runs the commands | the image's unprivileged user `ubuntu` (uid 1000), in the groups `adm` and `systemd-journal`, as a desktop user is |
| where the journal is | the dataset's directory, bind-mounted **read-only** at `/var/log/journal/<machine id>`, and `/etc/machine-id` set to match, so that the commands run exactly as on a system, without `--directory`; no host journal is mounted |
| timing | bash `time` around the whole pipeline: wall time, and CPU time = user + system; every run is one process at one core, so CPU is about the wall time; output goes to a line or byte counter, never kept |
| caps | 600 s per command, 300 s for the sos commands (sos's own limit); a stock run that hits the cap is marked, and its total is projected from the lines it had printed |
| runs | 3 runs for the short queries, 1 for the long ones |

**The container makes system calls dearer than the bare host does** (an earlier page measured stock `journalctl` at 2 to 5
times the host's speed in the same container, and the patched build at the same speed in both). The stock figures below
are therefore pessimistic by that factor; the patched ones are not. The ratios are the container's, not the host's.

## 2. The synthetic journal, and why it looks like a desktop's

Written by `scripts/make-noble-default.py` with `systemd-journal-remote` from export streams; deterministic (seeded).
It is a model, not a copy of any machine's journal, and nothing in it comes from the laptop's journal.

| | |
|---|---|
| system files | **100 archived files of 40 MiB (4.0 GB)**: 10 boots, 10 files per boot, 48 000 entries each (4.8 million entries) |
| user files | **50 archived `user-1000@...` files (1.6 GB)**: 5 per boot, 30 000 entries each (1.5 million), covering the same hours |
| time | 10 boots, one about every 6 days, each up for 5.5 days; a system file holds a 13-hour slice of its boot, a user file a 26-hour slice, so the time ranges of system and user files **overlap**, and a reader merging them meets their entries interleaved, as on a desktop |
| entries | journald-style: the trusted fields (`_BOOT_ID`, `_MACHINE_ID`, `_HOSTNAME`, `_TRANSPORT`, `_PID`, `_UID`, `_COMM`, `_EXE`, `_CMDLINE`, `_SYSTEMD_UNIT`/`_SYSTEMD_USER_UNIT`, `_SYSTEMD_SLICE`, `PRIORITY`, `SYSLOG_IDENTIFIER`, ...), a message of 5 to 26 words, a few percent kernel lines (`_TRANSPORT=kernel`); about 840 bytes per entry in the file, 12 system units and 7 user units |
| one machine ID, one boot ID per boot, monotonic time rising across the files of a boot | the newest boot carries the container's own boot ID (the container shares the host kernel's), so `-b` and `-b -1` mean on this journal what they mean on a real system |
| subsets | the newest K files by time, as hard links of the same files: mixed (system and user together) 25, 50 and all 150 files (9, 17 and 50 user files: about a third); **system only** 25, 50 and all 100 files |
| state | all files ARCHIVED, as rotated files are |

**Why this shape.** The laptop's own journal directory has 492 files for 20.2 GB (41 MB per file on average), of which
319 are `system*.journal` and 173 (35 %) are `user-*.journal` (counts and sizes only, read from the directory listing); the dataset uses 40 MB files, 100 of them for journald's 4 GB cap on
`SystemMaxUse=`, and a third as many user files. **One thing it is not: pure journald defaults.** With its defaults
journald caps one file at an eighth of `SystemMaxUse=` (512 MiB for 4 GiB), so a default install fills its cap with about
8 system files, not 100. A journal reaches 100 files through other causes (rotations at reboot or on a size
or time limit, vacuuming, a small `SystemMaxFileSize=`), as the laptop's evidently has; this part of the work was asked
to model the laptop's shape, so the file counts here are the laptop's, not a claim about fresh installs. The 25 and 50 file sets
show where on the curve a smaller install falls.

## 3. The tools, and what they run

From the sources in noble (`data/tools-research.txt`).
- **`systemctl status <unit>`** shows the last lines of the unit's log. It cannot run in this container: it prints
  "System has not been booted with systemd as init system (PID 1). Can't operate." So its log tail is reproduced by
  `journalctl -u cron.service -n 10 --no-pager`, which asks for the same matches and the same last 10 entries; that is
  what it is, not `systemctl` itself.
- **apport 2.28.3** (`apport/hookutils.py`) runs two journal commands, both with no timeout (`subprocess.run` without one),
  and only if `/run/systemd/system` exists (it does on a booted system; not in this container, so the commands were run directly):
  `attach_journal_errors()` runs `journalctl --priority=warning -b --lines=1000` (or `--since=@T --until=@T` around a crash time),
  and `recent_syslog()`, used by package hooks, runs `journalctl --quiet -b -a --system` and filters the output in Python (the
  filtering is not measured).
- **sos 4.11.2** (`sos/report/plugins/logs.py`, `systemd.py`, `__init__.py`) runs `journalctl --disk-usage`, `journalctl --list-boots`, and three
  collections through `add_journal()`: `journalctl --no-pager --reverse` (the whole journal), `journalctl --no-pager --boot --reverse`
  and `journalctl --no-pager --boot -1 --reverse`, each limited to **100 MB** of output (`journal_size`, default 100), with a
  **command timeout of 300 s** (`TIMEOUT_DEFAULT = 300`) and a plugin timeout of 300 s. The 100 MB limit is applied here as
  `head -c 104857600`, which stops the reader as sos does when it reaches its size limit (approximated; the effect of
  sos's own reading is not measured).

## 4. Results

Medians. "Stock" is the installed 8.18, "patched" the 8.20 test build. Speed-ups are stock wall time over patched wall
time; where stock hit its cap the speed-up is projected from the lines it had printed (marked) or a lower bound.
`data/noble-results.tsv` has every run; `data/noble-summary.txt` the same as plain text.

#### mixed-25

| query | stock wall | stock CPU | patched wall | patched CPU | speed-up | lines or bytes |
|---|---|---|---|---|---|---|
| `--list-boots` | 0.01 s | 0.01 s | 0.01 s | 0.01 s | - | 3 lines |
| `-u cron.service -n 10` (what `systemctl status` shows) | 0.01 s | 0.01 s | 0.01 s | 0.01 s | - | 10 lines |
| `-b` (the newest boot) | 59.9 s | 60.0 s | 6.12 s | 6.30 s | 9.8x | 630,000 lines |
| `-b -1` | 26.9 s | 27.0 s | 3.91 s | 4.03 s | 6.9x | 408,000 lines |
| `-k -b all` | 2.90 s | 2.91 s | 0.29 s | 0.30 s | 9.9x | 30,553 lines |
| `-b all` (whole journal) | 109.7 s | 110.0 s | 11.5 s | 11.8 s | 9.5x | 1,038,001 lines |
| apport: `--priority=warning -b --lines=1000` | 0.13 s | 0.13 s | 0.03 s | 0.03 s | - | 1,000 lines |
| apport: `--quiet -b -a --system` | 17.9 s | 18.0 s | 3.09 s | 3.20 s | 5.8x | 480,000 lines |
| sos: `--disk-usage` | 0.01 s | 0.01 s | 0.01 s | 0.01 s | - | 1 lines |
| sos: `--list-boots` | 0.01 s | 0.01 s | 0.01 s | 0.01 s | - | 3 lines |
| sos: `--no-pager --reverse`, first 100 MB | 81.3 s | 81.8 s | 7.13 s | 7.47 s | 11.4x | 104,857,600 bytes |
| sos: `--no-pager --boot --reverse`, first 100 MB | 33.7 s | 34.1 s | 5.62 s | 5.94 s | 6.0x | 104,857,600 bytes |
| sos: `--no-pager --boot -1 --reverse`, first 100 MB | 22.3 s | 22.5 s | 3.58 s | 3.79 s | 6.2x | 69,854,630 bytes |

#### mixed-50

| query | stock wall | stock CPU | patched wall | patched CPU | speed-up | lines or bytes |
|---|---|---|---|---|---|---|
| `--list-boots` | 0.02 s | 0.02 s | 0.02 s | 0.02 s | - | 5 lines |
| `-u cron.service -n 10` (what `systemctl status` shows) | 0.02 s | 0.02 s | 0.02 s | 0.02 s | - | 10 lines |
| `-b` (the newest boot) | 64.7 s | 64.9 s | 4.89 s | 5.04 s | 13.2x | 630,000 lines |
| `-b -1` | 64.3 s | 64.5 s | 5.06 s | 5.20 s | 12.7x | 630,000 lines |
| `-k -b all` | 11.9 s | 11.9 s | 0.62 s | 0.63 s | 19.2x | 62,993 lines |
| `-b all` (whole journal) | 8.8 min | 8.8 min | 25.1 s | 25.6 s | 21.1x | 2,094,003 lines |
| apport: `--priority=warning -b --lines=1000` | 0.23 s | 0.23 s | 0.03 s | 0.03 s | - | 1,000 lines |
| apport: `--quiet -b -a --system` | 34.7 s | 34.8 s | 2.83 s | 2.93 s | 12.2x | 480,000 lines |
| sos: `--disk-usage` | 0.01 s | 0.01 s | 0.01 s | 0.01 s | - | 1 lines |
| sos: `--list-boots` | 0.02 s | 0.03 s | 0.02 s | 0.02 s | - | 5 lines |
| sos: `--no-pager --reverse`, first 100 MB | 4.0 min | 4.0 min | 9.76 s | 10.1 s | 24.4x | 104,857,600 bytes |
| sos: `--no-pager --boot --reverse`, first 100 MB | 61.7 s | 62.2 s | 4.93 s | 5.19 s | 12.5x | 104,857,600 bytes |
| sos: `--no-pager --boot -1 --reverse`, first 100 MB | 64.2 s | 64.6 s | 4.98 s | 5.25 s | 12.9x | 104,857,600 bytes |

#### sys-25

| query | stock wall | stock CPU | patched wall | patched CPU | speed-up | lines or bytes |
|---|---|---|---|---|---|---|
| `--list-boots` | 0.01 s | 0.01 s | 0.01 s | 0.01 s | - | 4 lines |
| `-u cron.service -n 10` (what `systemctl status` shows) | 0.01 s | 0.02 s | 0.01 s | 0.01 s | - | 10 lines |
| `-b` (the newest boot) | 27.9 s | 28.1 s | 3.46 s | 3.56 s | 8.1x | 480,000 lines |
| `-b -1` | 28.0 s | 28.2 s | 3.53 s | 3.64 s | 7.9x | 480,000 lines |
| `-k -b all` | 5.70 s | 5.71 s | 0.49 s | 0.50 s | 11.7x | 47,697 lines |
| `-b all` (whole journal) | 2.5 min | 2.6 min | 12.9 s | 13.2 s | 11.9x | 1,200,002 lines |
| apport: `--priority=warning -b --lines=1000` | 0.12 s | 0.12 s | 0.04 s | 0.03 s | - | 1,000 lines |
| apport: `--quiet -b -a --system` | 28.8 s | 29.0 s | 3.34 s | 3.46 s | 8.6x | 480,000 lines |
| sos: `--disk-usage` | 0.01 s | 0.01 s | 0.01 s | 0.01 s | - | 1 lines |
| sos: `--list-boots` | 0.01 s | 0.01 s | 0.02 s | 0.02 s | - | 4 lines |
| sos: `--no-pager --reverse`, first 100 MB | 98.0 s | 98.5 s | 7.05 s | 7.36 s | 13.9x | 104,857,600 bytes |
| sos: `--no-pager --boot --reverse`, first 100 MB | 29.6 s | 29.9 s | 4.01 s | 4.23 s | 7.4x | 81,675,309 bytes |
| sos: `--no-pager --boot -1 --reverse`, first 100 MB | 27.3 s | 27.6 s | 4.01 s | 4.24 s | 6.8x | 81,666,085 bytes |

#### sys-50

| query | stock wall | stock CPU | patched wall | patched CPU | speed-up | lines or bytes |
|---|---|---|---|---|---|---|
| `--list-boots` | 0.03 s | 0.03 s | 0.03 s | 0.03 s | - | 6 lines |
| `-u cron.service -n 10` (what `systemctl status` shows) | 0.02 s | 0.02 s | 0.02 s | 0.02 s | - | 10 lines |
| `-b` (the newest boot) | 45.6 s | 45.8 s | 4.11 s | 4.22 s | 11.1x | 480,000 lines |
| `-b -1` | 47.7 s | 47.9 s | 4.62 s | 4.76 s | 10.3x | 480,000 lines |
| `-k -b all` | 25.1 s | 25.2 s | 1.87 s | 1.49 s | 13.4x | 95,837 lines |
| `-b all` (whole journal) | 10.0 min (cap), about 10.1 min projected | 10.0 min | 33.8 s | 34.3 s | 18x projected | 2,400,004 lines |
| apport: `--priority=warning -b --lines=1000` | 0.23 s | 0.21 s | 0.06 s | 0.04 s | 4.1x | 1,000 lines |
| apport: `--quiet -b -a --system` | 47.0 s | 47.2 s | 3.03 s | 3.14 s | 15.5x | 480,000 lines |
| sos: `--disk-usage` | 0.01 s | 0.01 s | 0.01 s | 0.01 s | - | 1 lines |
| sos: `--list-boots` | 0.03 s | 0.03 s | 0.03 s | 0.03 s | - | 6 lines |
| sos: `--no-pager --reverse`, first 100 MB | 4.6 min | 4.6 min | 10.4 s | 10.7 s | 26.7x | 104,857,600 bytes |
| sos: `--no-pager --boot --reverse`, first 100 MB | 63.9 s | 64.4 s | 4.10 s | 4.32 s | 15.6x | 81,675,309 bytes |
| sos: `--no-pager --boot -1 --reverse`, first 100 MB | 65.8 s | 66.2 s | 3.90 s | 4.12 s | 16.8x | 81,666,085 bytes |

#### mixed-150

| query | stock wall | stock CPU | patched wall | patched CPU | speed-up | lines or bytes |
|---|---|---|---|---|---|---|
| `--list-boots` | 0.13 s | 0.13 s | 0.22 s | 0.21 s | 0.6x | 11 lines |
| `-u cron.service -n 10` (what `systemctl status` shows) | 0.05 s | 0.05 s | 0.08 s | 0.08 s | 0.6x | 10 lines |
| `-b` (the newest boot) | 3.0 min | 3.0 min | 16.7 s | 16.9 s | 10.8x | 630,000 lines |
| `-b -1` | 2.9 min | 2.9 min | 11.0 s | 11.2 s | 16.0x | 630,000 lines |
| `-k -b all` | 2.0 min | 2.0 min | 7.14 s | 5.87 s | 17.1x | 191,997 lines |
| `-b all` (whole journal) | 10.0 min (cap), about 2.4 h projected | 10.0 min | 3.4 min | 3.4 min | 42x projected | 6,300,009 lines |
| apport: `--priority=warning -b --lines=1000` | 0.58 s | 0.57 s | 0.30 s | 0.13 s | 1.9x | 1,000 lines |
| apport: `--quiet -b -a --system` | 86.6 s | 86.7 s | 4.92 s | 5.07 s | 17.6x | 480,000 lines |
| sos: `--disk-usage` | 0.01 s | 0.01 s | 0.02 s | 0.02 s | - | 1 lines |
| sos: `--list-boots` | 0.11 s | 0.11 s | 0.19 s | 0.16 s | 0.6x | 11 lines |
| sos: `--no-pager --reverse`, first 100 MB | 5.0 min (cap) | 5.0 min | 34.3 s | 34.9 s | >9x (timed out at 40 MB of 105 MB) | 104,857,600 bytes |
| sos: `--no-pager --boot --reverse`, first 100 MB | 2.8 min | 2.8 min | 7.57 s | 7.81 s | 22.1x | 104,857,600 bytes |
| sos: `--no-pager --boot -1 --reverse`, first 100 MB | 2.8 min | 2.9 min | 7.54 s | 7.77 s | 22.7x | 104,857,600 bytes |

#### sys-100

| query | stock wall | stock CPU | patched wall | patched CPU | speed-up | lines or bytes |
|---|---|---|---|---|---|---|
| `--list-boots` | 0.11 s | 0.11 s | 0.07 s | 0.07 s | 1.4x | 11 lines |
| `-u cron.service -n 10` (what `systemctl status` shows) | 0.04 s | 0.04 s | 0.03 s | 0.03 s | - | 10 lines |
| `-b` (the newest boot) | 87.1 s | 87.2 s | 3.65 s | 3.75 s | 23.9x | 480,000 lines |
| `-b -1` | 88.9 s | 89.1 s | 3.81 s | 3.92 s | 23.3x | 480,000 lines |
| `-k -b all` | 101.1 s | 100.1 s | 3.68 s | 3.47 s | 27.5x | 191,997 lines |
| `-b all` (whole journal) | 10.0 min (cap), about 1.1 h projected | 9.9 min | 84.7 s | 85.7 s | 47x projected | 4,800,009 lines |
| apport: `--priority=warning -b --lines=1000` | 0.45 s | 0.40 s | 0.05 s | 0.05 s | 8.8x | 1,000 lines |
| apport: `--quiet -b -a --system` | 84.1 s | 84.3 s | 2.93 s | 3.02 s | 28.7x | 480,000 lines |
| sos: `--disk-usage` | 0.01 s | 0.01 s | 0.01 s | 0.01 s | - | 1 lines |
| sos: `--list-boots` | 0.08 s | 0.08 s | 0.07 s | 0.07 s | 1.2x | 11 lines |
| sos: `--no-pager --reverse`, first 100 MB | 5.0 min (cap) | 5.0 min | 18.0 s | 18.3 s | >17x (timed out at 61 MB of 105 MB) | 104,857,600 bytes |
| sos: `--no-pager --boot --reverse`, first 100 MB | 84.8 s | 85.1 s | 4.08 s | 4.30 s | 20.8x | 81,675,309 bytes |
| sos: `--no-pager --boot -1 --reverse`, first 100 MB | 85.6 s | 85.9 s | 4.13 s | 4.36 s | 20.7x | 81,666,085 bytes |

### Reading the tables

**What stops working on stock.** The commands that read many entries become slow in proportion to the number of files, and
then stop being usable:
- **A whole-journal read** (`journalctl -b all`, a bare `journalctl` into a pipe): stock takes 110 s at 25 mixed files,
  8.8 minutes at 50, and does not finish in the 10-minute cap at 100 system files (about 1.1 hours projected) or 150 mixed files (about
  2.4 hours projected, from 737 lines per second); patched takes 11.5 s, 25 s, 85 s and 3.4 minutes.
- **sos's full-journal collection** (`journalctl --no-pager --reverse`, first 100 MB): stock needs 81 s at 25 mixed files,
  238 s at 50 (278 s at 50 system files), and **hits sos's own 300 s command timeout** at 100 system files (61 MB of the
  100 MB collected) and at 150 mixed files (40 MB); patched collects the 100 MB in 7 to 34 s. sos's logs plugin has a plugin timeout of
  300 s as well (`plugin_timeout`), against stock's 300 + 85 + 86 s (100 system files) or 300 + 167 + 171 s (150 mixed) for its three
  journal collections run one after another; I did not run sos itself, so what it does with that is not shown.
- **apport's `recent_syslog()`** (`--quiet -b -a --system`, no timeout): 18 s at 25 mixed files to 87 s at 150; the
  command itself does not time out, but every package hook that calls it waits that long (the Python filtering comes on top).

**What keeps working.** The commands that need few entries do not care about the number of files, stock or patched:
`--list-boots` (0.01 to 0.13 s), `-u cron.service -n 10` (what `systemctl status` shows: 0.01 to 0.05 s), apport's
`--priority=warning -b --lines=1000` (0.1 to 0.6 s), sos's `--disk-usage`. At 150 files stock is even a little faster than
patched on the three tiniest queries (0.13 against 0.22 s for `--list-boots`): the patched build always ran first in each
container, so it paid for the cold file cache; not a property of the patch.

**The speed-up** is 6 to 29 times for what finishes, and larger where stock hit the cap. For the whole-journal read:
9.5 times at 25 mixed files, 21 at 50, 42 projected at 150; 12 times at 25 system files, 47 projected at 100. In this container; on the bare host the
stock figures are 2 to 5 times lower, so the host's speed-ups are smaller (an earlier page: 7 to 25 times).

### Surprises

1. **The patched build is not flat either.** A whole read takes 11.5 s for 1.04 million entries at 25 mixed files (90 000 lines per
   second), 25 s for 2.1 million at 50 (83 000), 85 s for 4.8 million at 100 system files (57 000) and **205 s for 6.3 million
   at 150 mixed files (31 000)**. The per-entry cost still grows with the number of files: the remaining O(files) walk per
   entry that the rest of this work is about (the sets differ in more than the file count, so this is a trend, not a fit). The backport
   turns hours into minutes here, not into seconds.
2. **A stock `-b` of the newest boot is still slow:** 87 s for 480 000 lines at 100 system files (5 500 lines per second),
   3 minutes for 630 000 at 150 mixed files (3 500).
3. **Stock is dominated by system time**: the CPU columns are user + system, and the stock `-b` at 25 mixed files is 19 s user and
   40 s system (the TSV has them apart). That is the `fstat()` storm of the first page, here in a container where system calls are dearer.

### What was not done

- **`systemctl status` itself and sos itself were not run** (no running systemd in the container; sos not installed): their commands were.
- **The Python filtering in apport and the packaging of sos's output are not measured,** only the `journalctl` commands.
- **Each long query ran once** (the short ones three times); the runs are minutes to an hour long and the machine was shared.
- **Pure-defaults journals** (8 files for 4 GiB) were not modelled; see section 2. A smaller install falls on the 25 or 50 file rows.
- **No live (online) journal files** in the dataset, only archived ones; a running journald's current files are not modelled.
- **The 8.20 binary is the test build,** not an archive upload.

### Commands

`<work dir>` is the scratch directory; the scripts use `$WORKDIR`.
```console
$ <work dir>/bin/dk.sh inside-gen-noble.sh              # the dataset and its subsets (needs ~6 GB; free space was checked first)
$ <work dir>/bin/run-noble.sh mixed-25 mixed-50 sys-25 sys-50 mixed-150 sys-100   # one container per set, one after another
$ python3 -I <work dir>/bin/noble-md.py <work dir>/noble-results.tsv              # these tables
```
`inside-noble-root.sh` installs the archive's systemd, unpacks the test debs, sets the machine ID and runs `noble-user-part.sh`
as uid 1000, which times each command. `make-noble-default.py --calibrate N` measured the file size per entry (840 bytes).

| file | what |
|---|---|
| `data/noble-results.tsv` | every run (columns: set, who, query, run, exit status, wall s, user s, system s, lines or bytes, capped) |
| `data/noble-summary.txt`, `data/noble-*.out` | plain-text summary; the set facts each container printed |
| `data/tools-research.txt` | the apport and sos source search |
| `scripts/` | the generator, the container scripts, the analysis |
