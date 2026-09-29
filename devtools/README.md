# devtools

Tooling for **contributing to this repository**, not for diagnosing Bluetooth.

If you came here because your controller hangs, you want
[`tools/`](../tools/) and the [README](../README.md) instead — nothing in this
directory touches Bluetooth.

| Script | Purpose |
|---|---|
| `check [--quick]` | the one pre-commit command: repo-validate (incl. tests) + a full-tree scan + install state |
| `repo-scan <dir> [--all]` | Refuse-to-publish scan: MAC addresses, BSSIDs, UUIDs, IPv4, **email addresses**, tool attribution, binary captures |
| `repo-validate <dir>` | `bash -n`, `systemd-analyze verify`, `udevadm verify`, `jq`, `py_compile` over every tracked file |
| `repo-save <dir> "<msg>"` | validate → scan → commit → push → **verify the remote hash actually matches** |
| `coverage [--min N]` | How much of the shell this repo ships does `tests/run-tests` actually execute |
| `assert-test-catches <file> <line> <substr>` | prove a suite invariant actually fails when violated |
| `journal-contract` | do the journal fixtures still match the shapes the REAL journalctl emits |
| `sandbox [--self-test] [-- cmd]` | run the suite in a **decoy world** and list every place it reached for the real machine |

```bash
./devtools/check
./devtools/repo-validate .
./devtools/repo-scan . --all
./devtools/repo-save . "commit message"
./devtools/repo-save . -F message.txt --no-push
./devtools/coverage
./devtools/coverage --quiet --min 30
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

## Knowing whether a test used its fixtures or the machine

A third question a green suite cannot answer: did the test get its answer from the
fixture it was given, or from the machine it happened to run on? On a machine with no
Bluetooth, no journal and nothing installed — this container, CI — the real machine
returns *nothing*, which is exactly what an empty fixture returns. A test that reads the
real journal passes there for the wrong reason, and on the investigation laptop it reads
the laptop's real history, runs slowly, and can misreport.

A leak is only visible where the real world and the mock **disagree**. `sandbox` builds a
world that disagrees with every fixture — every machine tool, every installed file of this
project, the USB tree under `/sys`, the boot id, `/var/log/bt-health`, `/var/lib/bluetooth`
— each answering with a per-run marker `DECOY-<nonce>`, in fresh user, pid, mount, network
and UTS namespaces, with every real directory under a throwaway overlay. Four detectors:

| | fires when | how |
|---|---|---|
| CALL | a machine tool was run | each decoy logs its path, argv and caller |
| DATA | decoy data was consumed | the marker appears in the output |
| READ | a decoy file was read, even if nothing of it was printed | planted with an access time in 2001; the first read moves it |
| WRITE | a real directory was written | the overlay's upper layer is the diff; the real tree is never touched |

`sandbox --self-test` plants a leak for every detector and every decoy and fails if any
goes unseen; each isolation probe first proves on the host that the thing it must fail to
reach is reachable there, or says it cannot be verified. Each of its mechanisms was
disabled in turn, and each time the self-test went red.

The world is built as namespace-root; the command itself runs as **the caller**, in a
nested user namespace with no capabilities — the uid the suite really runs as, and one
that cannot unmount a decoy. A call tagged by the suite's `real_tool()` — its one
sanctioned door, for checking a fixture's shape against the real tool — is listed
apart and not counted.

The first full run (2026-09-29) found 312 machine-tool calls per suite run — among them
20 `logger` calls writing trial lines into the real journal and 6 runs of an *installed*
`bt-boot-list` — reads of the host's USB tree, btusb parameter, boot id and install stamp,
12 tests whose verdict depended on the machine, and a test creating `~/bt-journal-archive`.
All fixed the same day (tests/README.md, rule 5); CI now runs the suite in the decoy world
and fails on any leak.

It needs unprivileged user namespaces: this container and CI have them; Ubuntu 24.04's
AppArmor refuses them to ordinary users, so on the laptop it exits 3 — nothing measured,
never a pass.

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
