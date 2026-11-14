# CO-46: journalctl slows in proportion to the number of journal files

**Target:** systemd (`sd-journal`, used by `journalctl`). **State:** measured on the laptop and
recorded (2026-11-14); not yet checked against systemd main, not reproduced in a VM, the cause not
read in the source. Nothing sent. **Priority:** below the Bluetooth items, but it bears on this
project's own work. The project's checks and the operator's journal reads run on a 17 GB
journal, and one such read slowed the desktop for a morning.

## The incident that found it (2026-11-14)
`devtools/check`'s journal-contract step ran `journalctl -k -b all` and counted every boot
separator, though it needed only the first. With BT-17's dynamic debug on, it ran 7 h 44 min at
a full CPU. It read 5.4 GB from the journal files and wrote 1.29 GB of text, about 46 KB/s.
- Our part was fixed in `69d24d1`: `grep -m1`, 3.4 s, the same verdict.
- Record: `docs/STATUS.md`, "Repository health".

## What is measured
`results/journalctl-file-scaling-2026-11-14/` has the scripts and the exact output. The machine
runs systemd 255 (`255.4-1ubuntu8.18`) with 553 files. The newest K files are passed as
`--file=`; IO pressure stayed at 0, so the runs were CPU-bound.

| files | lines/s |
|---|---|
| 1 | 196 451 |
| 25 | 45 657 |
| 50 | 24 313 |
| 100 | 12 984 |
| 200 | 6 003 |
| 400 | 898 |
| 553 | 703 |

- **From 25 to 200 files the rate halves each time the file count doubles.** So the cost of each
  entry is proportional to the number of files open. Rotation adds files as the journal grows,
  so the total cost grows with the square of the journal size. A merge of sorted files should
  cost about entries × log(files).
- **Past 200 files it falls faster still.** One untested hypothesis: a fixed-size mmap cache that
  thrashes.
- `-o cat` is no faster, so the time goes on choosing the next entry, not on formatting it.

## R&D left, in order
1. **Source:** read `real_journal_next()` / `next_beyond_location()` in `sd-journal.c` on v255
   and on systemd main. Does the per-entry step visit every file? Has main changed it (a
   priority queue or cached locations)? Also look at the mmap cache's limits for the second
   effect.
2. **Upstream search:** systemd's GitHub issues and pull requests on journalctl being slow with
   many files. If it is already fixed, the result is a backport request for Ubuntu 24.04's 255
   (the project's rule for bugs fixed upstream).
3. **Reproduce in a VM, without the laptop's journal:**
   - generate synthetic journals with a small `SystemMaxFileSize=`, at K = 25, 50, 100, 200, 400
     and 800 files of the same size;
   - measure lines/s on v255 and on a build of main.
   - The curve is the report's evidence. It needs no private data.
4. **If main still behaves this way:**
   - a report with the reproducer;
   - a patch if the fix is local, for example a heap keyed by each file's next entry;
   - systemd's contribution rules apply, read first.
5. **Meanwhile, on the laptop (the operator's decision):** fewer, larger files
   (`SystemMaxFileSize=`), or a `MaxRetentionSec=`. Our scripts use `--list-boots`, `-b` and
   `grep -m1` so they do not read the whole journal.

## Decides
The operator: when to start it (a lane, at low priority), any journald setting on the laptop, and
any report or send.
