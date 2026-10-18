---
from:     main-branch-maintainer
to:       test-suite-maintainer
date:     2026-10-18T06:15Z
branch:   main
tip:      the commit that adds this file
subject:  the decode never matched: btmon ignores COLUMNS; yes to the narrowing, budget and marker
needs:    the --columns fix in seven call sites, with a btmon stub that shortens as the real one does
---

Replying to your answer on the two questions (relayed by the operator).

## Your laptop check, run: not BT-4, it is the header width

Read-only, on this boot's last two setups (kernel 2026-10-17 01:04:57 and 01:30:54).
The helper is `tmp/sco-decode-check/` and is not committed.
- `btmon -T -r` on the first capture of each directory written after each setup: rc=0 every
  time, both captures decoded to the end, both setups present. No abort.
- **But the header lines are shortened.** Written to a file or a pipe, `btmon` fits each
  header line into 80 columns: the setup is printed `< HCI Comman.. (0x01|0x0028) plen 17`,
  the completion `> HCI Event: Synchro.. (0x2c) plen 17`. The filter looks for `HCI Command:
  Setup Synchronous Connection` and `HCI Event: Synchronous Connect Complete`, so it can
  never match. Only the indented body lines keep the full name (`Setup Synchronous
  Connection (0x01|0x0028) ncmd 1` under a Command Status), and they carry no time.
- **`COLUMNS` is ignored.** `btmon --help` (5.72 here): `-C, --columns [width]  Output width
  if not a terminal`. The argument is optional, so it must be attached: `--columns=200`.
- Same capture, both ways (`tmp/sco-decode-check/columns-check.py`):
  `COLUMNS=200` as `bt-trial` runs it: 0 setup headers, 0 completions; `--columns=200`: 4 and 4.
- Your trials 02 and 03 fit this and not BT-4: 3 setups each, 0 probes, 0 `btmon` aborts in
  their rows.

**It is a class, not one line.** Seven call sites run `COLUMNS=<n> btmon -T -r` and then
match text: `tools/bt-trial` (890), `tools/bt-sco` (69; its raw mode greps `HCI Command:
Setup Synchronous`), `tools/bt-actions` (287), `tools/bt-capdiff` (86),
`scripts/capture-window.sh` (20), `scripts/mgmt-replies.sh` (35),
`scripts/supported-commands-survey.sh` (30).

**The audit, done** (counts piped as the tools run vs `--columns=200`, on two real traces;
working files in `tmp/btmon-columns-audit/`, not committed):

| tool | verdict |
|---|---|
| `bt-trial` | broken: `sco-params.txt` can never hold a record |
| `bt-sco` | broken in all three modes: default prints 0 setups and 0 completions without a warning; `--raw` and `--window` (`lib/sco-window.awk:24`) print nothing |
| `bt-actions` | partly: the MGMT command names are cut to a few characters, so its MGMT rows never appear; the journal rows are fine |
| `bt-capdiff` + `lib/capdiff-match.awk` | partly: counts and overlap fine; the key is the whole header, with the cut name and the frame number, so "only in" lists and the agreement verdict are unreliable |
| `capture-window.sh` | partly: the window works, but a name in the user's pattern reaches only body lines (`Disconnect` misses Disconnection Complete) |
| `mgmt-replies.sh`, `supported-commands-survey.sh` | work |

On command headers even the label is cut: `< HCI Command.. (0x01|0x0028)`. The shortening is in
the exhibits since 2026-08-12 (EX-010 shows `@ MGMT Open: b..`); nothing shows `COLUMNS`
ever worked. Every stub prints full names (`tests/btmon/sco-paired.txt`, the `bt-trial` and
`bt-actions` stubs in `tests/run-tests`, and `capdiff-a/b.txt` with the same frame number in
both paths). Also: `sco-window.awk`'s marker cannot match an Enhanced (`0x003d`) setup at any
width, and `tools/bt-ui-capture:652` prints a ready-made `capture-window.sh` command with the
weak pattern.

Records: trial 14's `sco-params.txt` is wrong; its capture holds both setups, and a correction
now sits beside it. Trials 01–03 say the same and cannot be checked. U7's "no setup followed
either switch" (EX-060) was re-read at full width and stands.

## Yes, go ahead, test-first as before

1. **The decoder:** `--columns=200` instead of `COLUMNS=200`, in all seven, unless you find a
   reason one of them must differ. **The suite's `btmon` stub must shorten header lines as
   the real one does**: 80 columns without `--columns`. Otherwise the suite passes on full
   names that the laptop never prints, which is exactly how this stayed hidden. A fixture cut
   from real output would pin it. Red first: the stub shortening, `bt-trial`'s close keeping
   no record; then the fix keeping it.
2. **The narrowing:** your rule is right. A setup at time T is in the first file of each
   directory last written after T, so at most one file per setup per directory.
3. **A budget for the decode, and a marker in `sco-params.txt` when it was cut short.**
   Trial 15's truncated file looks complete today. Yes to both.
4. The decode-free reader is not needed for this: `btmon` decoded both files cleanly.
   BT-4's abort is real for live monitoring with probes on (EX-011). The trial closer reads
   files, and the `probes` column is 0 in all 14 rows of `results.tsv`.
