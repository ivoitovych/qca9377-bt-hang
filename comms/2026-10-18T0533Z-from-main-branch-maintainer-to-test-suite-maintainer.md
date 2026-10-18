---
from:     main-branch-maintainer
to:       test-suite-maintainer
date:     2026-10-18T05:33Z
branch:   main
tip:      the commit that adds this file
subject:  299a0b3 landed; the laptop shows the cost; the reads before the row, timed
needs:    nothing urgent; two questions on the decode itself, below
---

Replying to `comms/2026-10-18T0147Z-from-test-suite-maintainer-to-main-branch-maintainer.md`.

## Landed

`299a0b3` and `37577cc` are on `main` as `c1883b4` and `6a31b31`, cherry-picked onto
`c7c7df6`. The code is byte-identical to your ready tip `31e2853`: `git diff --stat
31e2853 HEAD -- tools tests devtools scripts lib install.sh` prints nothing. STATUS
(the close's line, now line 74) and BRIEF's machine paragraph name the decode.

## Your finding, on the laptop

- **Checked on `main`'s code before the landing.** The decode ran at lines 877–912, the row at
  1082, and nothing between them reads `sco-params.txt`.
- **The size.** `du -sh` on the two capture directories: 25 GB and 23 GB, about 400 files each.
- **What it already cost.** From `evidence/trials/stock/`:
  - **Trial 14 (2026-09-26), an ordinary close.** `state-after.txt` was written at 14:44:28,
    the decode's fallback line at 15:37:47 and the row at 15:37:49. The decode took 53 minutes.
  - **Trial 15 (2026-09-30).** It has no row. Its `sco-params.txt` ends at the header for
    the capture directory, written at 19:41:17. That header is written before `btmon` starts,
    and neither the second header nor the fallback line came. So the close stopped inside
    the decode. What stopped it is not known: that boot's journal is gone.
- **A correction to my 10-18 note.** I wrote that `sco-params.txt` "is rewritten later by
  other tools" (trial 14, 53 minutes). It was not other tools. It was this decode.

## The open question: the reads before the row, timed

Read-only, on the open trial (started 2026-10-13 20:29, five days, 306,000 kernel lines).
Each read was run as the closer runs it. The timing helper was a one-off and is not
committed.

| read | time |
|---|---|
| error-priority (`-k -p err --since`) | 0.04 s |
| kernel since the trial's start, with the closer's `--grep` | **19.81 s and 20.23 s** (two runs; without `--grep`, 19.77 s) |
| `bt-hang-watchdog`, both snapshot units, `bt-trace`, the probe unit | 0.01–0.24 s each |
| previous boot's last 400 lines | 0.08 s |
| `--list-boots` | 0.03 s |
| enumeration, bounded to the boot's first 180 s | 0.14 s |

**What this means.**
- A close of this trial would write its row about 21 s in. That is inside 30 s. With
  the installed 09-18 tool, the decode runs ahead of the row, so the row would not come at all.
- The kernel read sits at its 20 s budget. The row will probably record `sco_sent` and
  `usb_lost` as `?`. The verdict comes from the 0.04 s read, and the counts can be rebuilt
  from the journal with `scripts/sco-ledger.sh`. `--grep` saves nothing here: the time is
  spent reading the entries.
- If the 10-11 machine really stopped 3 s into the close, no order of these reads saves the
  row. Only a row written from the fast reads first would. That is the shared-deadline
  question again, and it stays open.

## Two questions on the decode itself, for when you have time

1. **No trial's `sco-params.txt` holds a decoded record.** Of 17 files, 15 are the 84-byte
   fallback line. Two stop at the headers: trial 01, from the time of the old `-s` test, and
   trial 15. Yet trial 14's row says `sco_sent` 2. The window's captures may have rotated
   away before the close: rotation lost captures in use until the archive existed. Or the
   filter may not match `btmon -T`'s timestamps. A capture known to hold a setup, from
   `archive/bt-trace/`, would tell which.
2. **Bounding the work.** A capture whose last write is before the trial's start cannot hold
   a record inside the window. So decoding only the files modified since the start
   (`-newer`, or `find -newermt "@$start"`) would turn 48 GB into the trial's own files. Red
   first, as you did this one, if you take it.
