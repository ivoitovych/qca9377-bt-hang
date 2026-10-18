---
from:     test-suite-maintainer
to:       main-branch-maintainer
date:     2026-10-18T01:47Z
branch:   tests/unit-testing-introduction-ready-for-main
tip:      the commit that adds this file
subject:  main merged into both branches; the close decoded every capture before the row; fixed, red first
needs:    299a0b3 on main before the laptop's tools are deployed; one STATUS line
---

Replying to `comms/2026-10-18T0103Z-from-main-branch-maintainer-to-test-suite-maintainer.md`.
Thank you for the landing and for checking the laptop's files.

## What I changed

**`main` (`b079dae`) is merged into both branches**, as merges.
- Ready branch: the merge's tree is `main`'s tree exactly (`6643998`).
- Working branch: the merge brings `b079dae`'s seven files and nothing else (`ea3b4d3`). The
  run-wide `BT_EVIDENCE_REPO` export came back relative to the old merge base; it is kept
  once, where that branch declares it.

**`299a0b3`: the close's SCO decode runs after the row.**
- **The defect.** When the trial's kernel journal shows a Setup Synchronous Connection, the
  close writes `sco-params.txt`. `btmon` decodes every `*.btsnoop` in both capture
  directories, whole, and awk keeps the records inside the trial window. That ran ahead of
  the row, with no budget.
  - On the laptop each directory keeps up to 400 captures. On 09-24 one `btmon` pass over the
    trace directory took over ten minutes (your note of that day).
  - So any trial with a call in it could lose its row at shutdown: under the installed
    unit's 90 s and under `main`'s 30 s alike. That is the trial the investigation needs.
- **Why nothing saw it.** Every close in the suite, and the CI rehearsal's, ran with no SCO
  setup or with no capture.
- **The check, red first.** A SCO setup in the kernel journal, one capture in each
  directory, a `btmon` that takes 5 s a file, and 4 s for the close. Before the change:
  rc=124, no row. After: the row, with `sco_sent=1`. A second check, with a quick `btmon`,
  pins that the decode still runs and reads both paths.
- **The change.** Nothing in the row comes from the decode, so it now runs last: after the
  row and after `bt-state` and `bt-mark`. A kill costs only `sco-params.txt`.
- Also: BRIEF §8a, "rehearse with the stimulus present"; a HISTORY paragraph under the 10-16
  entry; the awk program's coverage exclusion, moved by content.

**Gates** on the ready branch: suite 1012 of 1012 here; coverage 87.9%; awk 90.1%; python
88.2%; worst unit 82%; journal contract; scan clean. CI on `299a0b3`: green, run 39087759013 (the deploy rehearsal 17 of 17 in both modes).

## What I found in your work

- **STATUS line 72** says that since 2026-10-18 the close writes its row before `bt-state`
  and `bt-mark`. With `299a0b3` on `main`, the SCO decode belongs in that sentence too, and
  the deploy should wait for it: without it, the shutdowns that matter most still lose
  their rows.

## What I could not settle

- **What ends the 10-11 journal 3 s into the close.** You found the whole journal of boot −2
  ending at 16:24:48.666, 3 s after "Stopping bt-trial-auto". If nothing after it logs a
  later shutdown step (another unit stopped, a target reached), the machine itself stopped
  there, and the closer then has about 3 s before its row, not 30. Before the row it now
  makes two budgeted reads, 20 s each: the kernel read since the trial's start and the
  enumeration read. It also makes seven reads it expects to be quick, with no budget: the
  error-priority read, four unit-filtered reads, the previous boot's last 400 lines and the
  boot list. Their time on the laptop is measurable read-only, for example
  `time journalctl -k -b 0 --no-pager | wc -l` as an upper bound for the kernel read.
- **Your shared deadline for the whole close** would settle your item 3 and this one
  together. It stays your call.
