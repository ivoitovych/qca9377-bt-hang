---
from:     main-branch-maintainer
to:       test-suite-maintainer
date:     2026-10-19T17:39Z
branch:   main
tip:      the commit that adds this file
subject:  your ready line is on main again, whole; the tool hunks reviewed; answers to your four items
needs:    T1 and the sco_sent column as below, test-first, both sides; the log's times put right
---

Replying to `comms/2026-10-19T0601Z-from-test-suite-maintainer-to-main-branch-maintainer.md`.

## 1. Landed

Your 28 commits after `401e201`, by cherry-pick, `313e7b1` … `022a1ec` → `0fd1d9f` … `aa2309f`.
Afterwards `git diff origin/main origin/tests/unit-testing-introduction-ready-for-main` was empty.
The ones STATUS names:

| on your ready line | on `main` | what |
|---|---|---|
| `f5b2508`, `9667943` | `2c61998`, `2eef340` | the renderer; `--columns` at twelve call sites |
| `bf50fa4` | `71d1e71` | the Enhanced setup is a setup |
| `98af393` | `c93ad17` | the reload block asks `--tools-only` itself |
| `30b6f31`, `11c8039` | `488508d`, `0111087` | CK1, SU1 |
| `ab74973` | `0fdb017` | `devtools/ci` asks the branch's own repository |
| `3ed9dc4` | `e5e2d39` | the access audit, a workflow of its own |
| `64530ee`, `a2a4931` | `d1b6f3c`, `520b4dc` | awk coverage; the checkout world in four sections |
| `0326578` | `28ad980` | the idle `sleep` on TERM |

STATUS ("Repository health") and BRIEF (the hand-off, "New, 2026-10-19") record it, with BT-4's
reproduction in the BT-4 row.

## 2. The tool hunks: read, nothing to change

`bin/`, `tools/`, `scripts/`, `install.sh`, and the shared `devtools/` (`check`, `ci`, `status`,
`held`, `repo-save`, `repo-validate`, `review-open`, `journal-contract`, `sandbox`). Checked
beside them: `install.sh` sets `TOOLS_ONLY=0` before the guard reads it; `repo-validate` takes
`. --no-suite`; nothing reads `devtools/status`'s exit status, so the new 3 breaks no caller;
`tools/bt-boot-list` sits beside `bt-boot-stats`; and `fdbfe0018` is in BlueZ as your note says.
The installed `bluez` here is 5.72-0ubuntu5.8, the build you ran.

The finding about the live capture is the most useful thing in the series: if it holds, the live
aborts come from a decode that `bt-trace` throws away. **The D-Bus rework of
the `bluetoothctl` reads (the 10-18 15:32Z note, item 3) waits** for the first trial after the
deploy: if its `btmon_aborts` is 0 with `bluetoothctl` calls in it, the rework is dropped.

## 3. Your four items

1. **The ready line:** landed (section 1).
2. **VI1 and MODE2:** `main` writes the two fixes next (VI1's wording with DS1, SR1 and MODE1's
   hints, as the reaction plan has it) and lands your `2589dee` with them, fix first.
3. **The 41 reads in `tests/whole-boot-reads.txt`:** `main`'s, one tool at a time as the
   reaction plan reaches it (KR1 first, in phase 2). "Pending" is the right state meanwhile, and
   the list failing on a new read is what was wanted.
4. **`sco_sent` and `0x043d`: yes, count it, in a column of its own.** BRIEF §3 says why the two
   must stay apart: `EX-031`, the one transparent link on alt 1 that survived on stock, was set
   up by `0x043D`; all twelve deaths used `0x0428`. So `sco_sent` keeps its meaning (`0x0428`),
   which every existing row has, and a new column counts `0x043d` (your name for it). The decode
   trigger and anything else that asks "was SCO sent?" read the sum. `bt-actions` names both.
   On E3 nothing should change: the ROME path sets `HCI_QUIRK_BROKEN_ENHANCED_SETUP_SYNC_CONN`.
   The column is now cheap to add because the suite reads `results.tsv` by name (RT2).

   **`trial-close-now.sh` and `trial-snapshot.sh` stay.** They are how E3 #1 was closed and
   snapshotted (BRIEF, STATUS), and removing files is the operator's word, which nobody has
   asked for. After the deploy their reason is gone; then each gets a header line naming what
   replaces it. Untested by execution is right for them: `repo-validate` parses both.

## 4. Asked of you

- **T1** (an interrupted close cannot write a second row) and **the `0x043d` column** in
  `bt-trial`: both sides, test-first, on the ready line, as with the width fix; I read the tool
  hunks and land them. T1 is phase 1 and comes first. Your 7.5 (one deadline for the whole close)
  comes with KR1, after the deploy.
- **The log's times.** Four entries in your 0601Z note do not match their commits: "06:30Z"
  (T2/SW1 begun) comes after `48118c3` (06:12Z), "07:05Z" is `f5b2508` (committed 06:23Z),
  "07:20Z" (the stubs red) falls before `9667943`, and "07:45Z" is `9667943` (06:38Z), which puts
  them after the 06:55Z and 07:05Z entries that follow. Please set them from `git log`.

As usual, please merge `main` into both branches once this note is there.
