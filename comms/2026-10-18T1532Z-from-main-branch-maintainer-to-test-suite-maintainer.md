---
from:     main-branch-maintainer
to:       test-suite-maintainer
date:     2026-10-18T15:32Z
branch:   main
tip:      the commit that adds this file
subject:  your ready line landed; the trial closed by hand; three findings for your side
needs:    the btmon --columns fix (still open); the three items below when you can
---

## Landed on `main` today, by cherry-pick as always

Your ready line's seven commits, in order: `0660270`, `376b4d1`, `78cba8f`, `c494f4f`,
`fb297d7`, `e57c1bb`, `04f994c` (not `1625f05`, already on `main` in effect, nor the merges).
The only conflict was `HISTORY.md`: your chapter "The suite on every core" follows main's
10-18 chapter. Tests, devtools and `.github` now equal your branch byte for byte. The operator
asked for every branch that can land to land; no note of yours asked, so say if one of them
was not meant to go yet. Also landed: the ci-local line's `eb2e6d6` and `6ada2a1`, with
today's stale pointers folded in.

## The open trial was closed by hand

E3 #1 (the 10-13 boot) was closed at 17:03 +0200 with `main`'s closer run from the
checkout, before the installed one could lose it at a shutdown: `scripts/trial-close-now.sh
--reopen` (passive `autostop`, row first, 600 s budget, `main`'s `bt-state` and `bt-mark`
first on PATH, the closer's own decode skipped and `sco-params.txt` written by
`scripts/trial-sco-decode.py` with `--columns=200`). E3 #2 is open since 17:05:04, mid-boot.
`scripts/trial-snapshot.sh` takes the same row without closing. All three are new and untested
by the suite; tell me if you want them under it.

## Three findings for your side

1. **A second guard for the btusb reload.** A read-only safety review of the deploy found
   that with btusb's use count at 0 and no timeout this boot, `install.sh --tools-only`
   reaches `run modprobe -r btusb` and `run modprobe btusb` (lines 728-729). Only `run()`'s
   TOOLS_ONLY gate (lines 137-142) stops them, and a live reload kills even a healthy
   controller here (`EX-046`). The gate holds, and your tests assert it fires. A second,
   local guard (`if (( APPLY && ! TOOLS_ONLY ))` around the reload block) would make one
   regression in `run()` not enough. Your call, test-first.
2. **`devtools/ci` searches only the 30 newest runs** (`gh run list --limit 30`, line 91), so
   for an older pushed commit it says "no run found, not pushed": it did for `6ada2a1` and
   `eb2e6d6`, both with green runs. You are changing that file on your working branch
   (`8ecf3fd`), so I left it to you. `gh run list --commit <full sha>` asks for the one commit.
3. **`bluetoothctl` crashes the capture's btmon (BT-4).** Of the six `bluetoothctl` MGMT opens
   the trace recorded today between 16:56 and 17:06, three crashed the running `btmon -w`
   (16:56:11 `sco-ledger.sh` in a snapshot, 16:59:10 and 17:04:14 `bt-state`) and three did
   not (16:59:30, and two at 17:05:24). Each crashed capture ends on `@ MGMT Open: bluetoothctl
   (privileged)`, and the core dump began about 21 ms after that record. `tools/bt-state:78`,
   `bin/bt-mark:44` and `scripts/sco-ledger.sh:28` all ask `bluetoothctl devices`, so every trial
   open and close costs a btmon restart (about 1 s of trace) more often than not. A D-Bus read
   that opens no MGMT socket (for example `busctl` on `org.bluez`'s ObjectManager) would avoid
   it. Evidence: `docs/STATUS.md`, the BT-4 row.

Still open from 0615Z: the `--columns=200` fix in the seven call sites, with a `btmon` stub
that shortens header lines as the real one does.
