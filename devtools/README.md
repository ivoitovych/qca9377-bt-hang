# devtools

Tooling for **contributing to this repository**, not for diagnosing Bluetooth.

If you came here because your controller hangs, you want
[`tools/`](../tools/) and the [README](../README.md) instead — nothing in this
directory touches Bluetooth.

| Script | Purpose |
|---|---|
| `check [--quick]` | **The one command to run before committing** — syntax, invariants, drift, install state |
| `repo-scan <dir> [--all]` | Refuse-to-publish scan: MAC addresses, BSSIDs, UUIDs, IPv4, **email addresses**, AI attribution, binary captures |
| `repo-validate <dir>` | `bash -n`, `systemd-analyze verify`, `udevadm verify`, `jq`, `py_compile` over every tracked file |
| `repo-save <dir> "<msg>"` | validate → scan → commit → push → **verify the remote hash actually matches** |
| `check [--quick]` | the one pre-commit command: repo-validate (incl. tests) + a full-tree scan + install state |
| `coverage [--min N]` | How much of the shell this repo ships does `tests/run-tests` actually execute |
| `assert-test-catches <file> <line> <substr>` | prove a suite invariant actually fails when violated |

```bash
./devtools/check
./devtools/repo-validate .
./devtools/repo-scan . --all
./devtools/repo-save . "commit message"
./devtools/repo-save . -F message.txt --no-push
./devtools/coverage
./devtools/coverage --quiet --min 15
```

## Knowing whether a test is worth anything

Two of these answer questions a green test suite cannot.

`assert-test-catches` breaks a thing on purpose and asserts the suite goes red. A test
that has never been observed to fail is evidence that the test ran, not that the
invariant holds — this repository has shipped several checks that could not fail, and
each printed a tick.

`coverage` answers the other one: how much of the code has ever been *run*. It executes
the suite under `xtrace` and records every line bash actually reached. When first
measured, 41 of 43 tracked shell scripts had **zero** executed lines and the total was
13.1% — with `tests/run-tests` and `tools/bt-trial` the only two files contributing
anything. See [the unit-testing assessment](../reviews/2026-08-13T1214Z-unit-testing-assessment.md)
for what that means and what to do about it.

The figures are a deliberate **lower bound** — multi-line commands are traced once, at
their first line — so the tool is for ranking files and watching a trend, not for quoting
an exact percentage. If instrumentation fails it exits 2 rather than reporting 0%, because
a silent "everything is uncovered" reads like a finding.

## Why these exist

This repository publishes **logs**. Kernel logs contain the Wi-Fi access point BSSID,
which public geolocation databases index — publishing one can reveal where a machine
physically is. They also contain device addresses, device names and filesystem UUIDs.

`repo-scan` is the last line of defence before that data leaves the machine. It knows
which placeholders are legitimate (`AA:BB:CC:*`, `11:11:11:*`, and the documented test
vectors used by `tools/sanitize-logs.sh`) and fails on anything else.

Deliberate allowlists, so the gate stays usable rather than being routinely bypassed:

- **Bluetooth SIG base UUIDs** (`0000xxxx-0000-1000-8000-00805f9b34fb`) are public
  constants that appear in every `bluetoothd` log this project publishes. Filesystem and
  machine UUIDs are still caught.
- **MAC separator form is normalised**, so the documented placeholders are accepted
  written either `AA:BB:CC:…` or `AA-BB-CC-…`.
- **Email**: the committer's own address (from `git config user.email`), public kernel
  mailing lists, and `example.com` are allowed; anything else fails.
- **Default mode scans added lines only.** Scanning the whole staged diff meant a commit
  that *removed* a leaked secret still matched it on the `-` lines — so the tool blocked
  the one commit it exists to enable.

`repo-save` also scans the **commit message**, which `repo-scan` cannot see. A
`Co-Authored-By` trailer lives in neither a file nor a diff, so the likeliest vector for
the thing being screened for previously sat outside the screen entirely.

`repo-save` refuses to commit if validation or the scan fails, then confirms the remote
hash equals the local one. That last step is the one most often skipped by hand, and it
is the only thing that proves a push actually landed.

## Notes

- Read-only except `repo-save`, which is the only one that writes or pushes.
- Non-zero exit on failure, so they compose.
- They take the target directory as an argument — no hardcoded paths.
- **Not installed** by `install.sh`. They are useless to end users and would only
  clutter `/usr/local/bin`.

These previously lived outside the repository, in a separate untracked-by-anything
directory. That meant they existed on exactly one machine and were backed up nowhere —
the same argument that motivated publishing this project in the first place.
