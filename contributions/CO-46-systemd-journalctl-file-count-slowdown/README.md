# CO-46: journalctl slows in proportion to the number of journal files

**Target:** systemd (`sd-journal`, used by `journalctl` and libsystemd0).

**State (2026-11-16):**
- cause found in the source;
- upstream's fix identified and measured on the laptop and in containers;
- an Ubuntu 24.04 stable-update request drafted in [`sru-noble/`](sru-noble/README.md), with its
  review request in [`sru-noble-review-request.md`](sru-noble-review-request.md);
- packaging (DEP-3 patches, a debdiff, a test build) in preparation.

Nothing sent or filed.

## The incident that found it (2026-11-14)
`devtools/check`'s journal-contract step ran `journalctl -k -b all` and counted every boot
separator, though it needed only the first. With BT-17's dynamic debug on, it ran 7 h 44 min at
a full CPU. It read 5.4 GB from the journal files and wrote 1.29 GB of text, about 46 KB/s.
- Our part was fixed in `69d24d1`: `grep -m1`, 3.4 s, the same verdict.
- Record: `docs/STATUS.md`, "Repository health".

## Cause (v255.4)
- `real_journal_next()` compares the next entry of every open file on every step.
- `next_beyond_location()` begins with `journal_file_read_tail_timestamp()`, which begins with an
  `fstat()`; `compare_boot_ids()` reads two more tails.
- With 100 files open the installed journalctl makes 477.7 `fstat`-family calls per printed line.

## Upstream state
| commit | what | first release |
|---|---|---|
| A `99e6f682d3` | cache the tail-entry offset and file state; no `fstat()` | v256 |
| B `51b2bcf835` | report "nothing new", return early | v256 |
| C `8f8ab4bf98` | rate-limit the tail refresh | v262 |
| D `79e32e7c73` | read the clock once per sweep | unreleased |

- A and B are in every release since v256 and in Ubuntu since 24.10. They are not in noble (8.18,
  or 8.19 in -proposed), and not in upstream v255-stable.
- PR #30209 was opened during the v255 freeze ("not a v255 material").
- Neither commit has a later fix upstream.
- With A and B, the per-entry cost still grows with the number of files:
  - upstream issue #31486 (open, 2024);
  - PR #44579 (open, 2026-11-01): a cached winner and runner-up, rework requested.
- No Launchpad or Debian bug exists.

## What is measured
Host, synthetic data, lines/s:

| files | 255.4 (8.18) | + A + B | gain |
|---|---|---|---|
| 25 | 19 218 | 178 586 | 9x |
| 100 | 4 563 | 84 104 | 18x |
| 400 | 633 | 13 787 | 22x |

Host, the laptop's journal:

| files | 255.4 (8.18) | + A + B | gain |
|---|---|---|---|
| 25 | 29 194 | 201 342 | 7x |
| 100 | 11 361 | 133 097 | 12x |
| 479 | 2 292 | 56 894 | 25x |

- **Everyday queries:** `journalctl -b` is 35 times faster, 48 s against about 28 min.
- **Containers:** they make every system call dearer, so the gain there looks larger (15–77 times).
  The host's figures are the ones to quote.
- **Growth with the number of files:**
  - with A and B, the exponent is still 2.15 on synthetic data (1.50 on the real journal);
  - our priority-queue prototype on main is flat: exponent 1.13, about 205 000 to 305 000 lines/s
    at every file count;
  - the prototype is not for sending.
- **The reproducer:** `sru-noble/reproducer/`, no root, temporary directory only. Tested as an
  unprivileged user in a fresh ubuntu:24.04 container, with a before-and-after check of the system's
  log and config directories.

Where the data and scripts are (branch `research/journalctl-file-scaling`):
- `results/journalctl-file-scaling-cause-2026-11-14/`: cause, system calls, first comparison;
- `results/journalctl-file-scaling-verify-2026-11-15/`: containers, the same-output checks, the
  prototype;
- `results/journalctl-file-scaling-host-2026-11-16/`: host against container, the queries, the
  reproducer;
- `patches/systemd/journal-file-scaling/`: A and B for 255.4 (0001, 0002), C and D adapted (not
  proposed), a boot-order cache, and the priority-queue prototype.

The 2026-11-14 table (stock, 45 657 lines/s at 25 files) came from a different selection of files,
at different priorities, on an older journal. It is not directly comparable with the figures above.

## Plan
1. **The noble stable update:**
   - one Launchpad bug with a noble task;
   - a merge proposal into `ubuntu-noble`, or a debdiff for `ubuntu-sponsors`, carrying A and B;
   - after 8.19.
   - Open before review: the package build, its tests, and the same-output checks on two machine IDs
     and on a file being written.
2. **Review** by the operator's reviewers (`sru-noble-review-request.md`), then the operator files.
3. **Upstream, the remaining growth:** compare the prototype with PR #44579.
   - Open: the order across machine IDs, `-f`, and files that change while open.
   - Whether to comment with data or propose a different design is the operator's decision.
4. **On the laptop** (operator's decision): installing a patched systemd; or fewer, larger files.
   Our scripts use `--list-boots`, `-b` and `grep -m1`, so they do not read the whole journal.

## Decides
The operator decides:
- any filing, comment or send;
- any install on the laptop;
- any journald setting.
