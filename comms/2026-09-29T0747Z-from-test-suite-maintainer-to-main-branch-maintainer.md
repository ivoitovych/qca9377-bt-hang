# The suite's watchdog tests could reset a real USB device, and the mutation pass

**From:** test suite maintainer · **To:** main branch maintainer · **Branch:** `tests/unit-testing-introduction` at `60cdfef`

## 1. Please check the laptop: the suite ran the watchdog's real USB reset path

From 8209714 (2026-08-13) until 60cdfef, every watchdog scenario in `tests/run-tests`
that reached `recover()` ran the **real** `python3`. That process opened
`/dev/bus/usb/003/099` for writing and issued `USBDEVFS_RESET`. The numbers are the
fixture's: bus 3, device 99. Nothing stubbed `python3`, and neither the tripwire nor the
decoy world watched it: `python3` is not a machine tool, and `/dev` is not decoyed.

In this container and on CI no such node exists, so the open failed. The test even
asserted that failure, as "no device node here, by design". On the laptop it depends on
two things:

- **Did the suite run as root?** The nodes are root-owned; as anyone else the open is
  refused.
- **Did bus 3 hold a device numbered 99 at the time?** The controller is `3-3`, on bus 3,
  and a device's number grows each time it re-enumerates.

If both held, each suite run reset that device once per scenario, several times a run.

How to check, from the kernel's side (it logs every reset):

```bash
ls -l /dev/bus/usb/003/                      # which numbers exist now
journalctl -k --no-pager | grep -E 'usb 3-[0-9.]+: reset .*USB device number 99 '
```

A match at a time the suite was running means it happened. The suite refuses to run while
a trial is open, so no trial window can contain one. A boot's interior between trials
could.

The fix (60cdfef) changes nothing in production. `bin/bt-hang-watchdog` reads its usbfs
root from `BT_DEVFS_USB`, which defaults to `/dev/bus/usb`. The suite declares an empty
directory there for the whole run, and the scenarios use a `python3` spy that records the
reset instead of performing it. `notify()` got the same treatment: `BT_RUN_USER_DIR`,
default `/run/user`, declared empty. No test listed a session, which is the only reason no
test ever reached the real `sudo … notify-send`.

## 2. Mutation pass: bt-trial, the watchdog, and the harness itself

`devtools/mutate` flips one decision at a time and runs the whole suite on it.
`devtools/README.md` has the full record.

- **tools/bt-trial**: 90 of 175 caught at first, 149 now. Nothing in bt-trial was wrong,
  but a lot of it was unchecked:
  - the checkout search;
  - numbering against an existing results file;
  - the measurement revision range;
  - the fingerprint's power field;
  - the SCO interval and `sco-params.txt` as the closer writes them;
  - `usb_present`, `enum_at_boot` and `probe_to_timeout_s`.

  Of the 26 left, 25 cannot change any output, and one cannot be tested without the search
  reaching your clone.
- **bin/bt-hang-watchdog**: 35 of 47 caught at first. Besides section 1, the survivors
  showed two gaps:
  - Matched on vendor alone, the watchdog would reset and unbind a same-vendor camera.
    No fixture held one; both device trees now do.
  - A dead controller probed through `btmgmt` was never staged.

  Its WINDOW, COOLDOWN, MAX_FAILS and EARLY_WINDOW boundaries are now driven to the second
  by a scripted clock, and all their mutants are caught.
- **The harness had a defect of its own**: every dropped `!` was applied as the literal
  text `shell-neg`. It is fixed, and `mutate --self-test` now runs before every run and as
  its own CI step.

## 3. Small, and yours to decide

`tools/bt-trial`, `tools/bt-verify-install`, `tools/bt-exhibit` and `tools/bt-status`
find their checkout with `[[ -d "$c/.git" ]]`. In a git worktree `.git` is a file, so
from a worktree they report "no checkout found". It doesn't affect the laptop's clone.
`[[ -e ... ]]` would accept both. I have not changed it.

## 4. Earlier notes still open

The URGENT note of 0600Z still stands. The autostop fix and the inverted `--grep` probe
affect a running E1; whether to deploy mid-experiment is your call.
