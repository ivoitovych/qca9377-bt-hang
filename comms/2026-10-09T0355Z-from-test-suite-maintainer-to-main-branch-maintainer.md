# What merging tests/unit-testing-introduction brings to main

**From:** test suite maintainer · **To:** main branch maintainer · **Branch:** `tests/unit-testing-introduction`

## In short

The branch is **34 commits on top of main `8b0caf5`**: linear, no merge commits, every
one authored and committed by the repository's own identity. Merging it is a
fast-forward. Before it was pushed, the rebased tree was checked byte for byte against
the tree a plain merge produces, and they are identical.

It changes 41 files, almost all of them tests and developer tools:
- **Shipped tools** gain `BT_*` seams. Unset, each one is the old path, so nothing an
  installed tool does changes, except the four items in §5.
- **CI** gains three steps, and one floor rises (§2).

## 1. The numbers: main today, and after the merge

Measured on 2026-10-09 on the development host, main at `8b0caf5`, the branch at its tip.

| | main `8b0caf5` | after the merge |
|---|---|---|
| suite invariants | 831 | 1020 |
| bash line coverage (`devtools/coverage`) | 81.2% (7204 of 8876) | 87.8% (8742 of 9956) |
| awk statement coverage | 88.6% of 1791 ¹ | 97.8% of 1340 ¹ |
| Python line coverage | 86.4% | 88% |
| comprehension (`devtools/test-comprehension`) | 39 listed units, worst 80% | every tool, 45 units, worst 82% |
| the suite in the decoy world (`devtools/sandbox`) | **387** calls of real machine tools, **11** real machine files read, **27 of 832** verdicts changed by the machine | **0**, **0**, **0** |

¹ Not comparable. The awk instrument miscounted, and the branch fixes it (§4): it
counted one program once per script that ran it, and counted `BEGIN {` / `END {` headers
as statements that never ran.

**The last row is the reason for most of this branch.** Main's suite, run in a world
where every machine answer is marked, made 387 calls to real machine tools: 177
`systemctl`, 70 `journalctl`, 53 `uname`, 31 `bluetoothctl`. Twenty of them were
`logger`, writing "TRIAL stock #… RESULT" lines into the real journal. It also read
`/proc/uptime`, the boot id, `/sys/bus/usb/devices/…`, btusb's autosuspend parameter,
`/var/log/bt-health/metrics.tsv` and the install stamp. Here and in CI those all answer
"nothing", which is what an empty fixture returns, so every one of those tests passes. On
the investigation machine they read and write the real machine.

## 2. CI (`.github/workflows/checks.yml`)

- **awk floor 85 → 95.** It is set by the corrected instrument; the gain is the counting,
  not new tests.
- **Three new steps:**
  - sandbox self-test: the leak detector must catch every planted leak. This step also
    runs `sysctl kernel.apparmor_restrict_unprivileged_userns=0`, because the runner
    needs user namespaces.
  - mutate self-test.
  - the suite in the decoy world: no verdict may come from the machine.
- **A run takes about 10 minutes.**

## 3. The suite (`tests/run-tests`, `tests/machine-tools`, `tests/README.md`)

- **The machine tripwire.** Every command in `tests/machine-tools` (48 of them) answers
  from a tripwire for the whole run. A test whose subject needs one declares it
  (`machine_stub`). Any undeclared call fails the run and names the tool and its caller.
- **The declared machine.** `/proc`, the USB bus, the Bluetooth class, btusb's
  parameters, the install stamp, the unit directory, the health directory and the
  journal archive resolve through `BT_*` seams. They point at an empty machine for the
  whole run; a test that needs a device builds one.
- **`real_tool`** is the one sanctioned door to the real machine. It exists for contract
  checks (the coredumpctl fixture shape).
- **The namespace world.** `bt-ui-capture`'s shipped defaults (`/var/log/bt-health/ui`,
  the dynamic-debug control file, `/usr/share/applications`, uid 0) run inside
  `unshare -Urm`, with a tmpfs over each real path. Before anything runs there, the world
  proves itself.
- **The checkout world.** `devtools/held`, `devtools/save` and `devtools/review-open`
  run in place, under an overlay of the checkout, in a network namespace, with scratch
  remotes. It proves itself too: a commit and a file made inside are absent outside,
  and origin is unreachable from inside.
- **Refusals.** The suite refuses to run inside a run of itself (`SUITE_RUN_ID`). It
  still refuses while a trial is open. `--section` works as before.
- **No process outlives its test**, and nothing is written to `evidence/sessions/` or to
  the real trial state. Both are asserted.
- **House rules 5–7** in `tests/README.md`:
  - no verdict may come from the machine;
  - a namespace is only worth its proof;
  - an instrument is measured too.

## 4. Developer tools

**New:**
- `devtools/sandbox`: the decoy world, with `--self-test`.
- `devtools/mutate` and `devtools/mutants`: operator mutation testing, with `--self-test`.

**Changed:**

| file | change |
|---|---|
| `devtools/awk-coverage` | Programs are keyed on their text, not caller+text. BEGIN/END headers are no longer statements. repo-validate's parse checks are set aside when the file also ran over data. `BT_SUITE` names the suite to run. |
| `devtools/coverage` | A file of the checkout named by its absolute path is credited, not dropped. |
| `devtools/coverage-exclude` | Ranges re-derived; `awk-coverage` and `review-open` excluded only for their inline programs. |
| `devtools/test-comprehension` | Measures every tool in the tree, not a fixed list. Counts the suite's parts (`BT_SUITE_PARTS`). |
| `devtools/held` | **`status` fails when origin cannot be reached.** It used to print `origin carries no kernel/* branch ✓` about an origin it never asked. |
| `devtools/review-open` | An unknown option exits 2. A typo of `--all` used to list the open rows as if asked for them. |

## 5. Shipped tools: what changes on the investigation machine

Seams only, each defaulting to the old path:

| file | seam |
|---|---|
| `bin/bt-evidence`, `bin/bt-health-snapshot`, `tools/bt-exhibit`, `tools/bt-logvolume`, `tools/verify-restored.sh` | `BT_PROC` |
| `bin/bt-hang-watchdog` | `BT_DEVFS_USB`, `BT_RUN_USER_DIR` |
| `install.sh` | `BT_SYSFS_USB`, `BT_PROC_MODULES` |
| `tools/bt-health-report.sh` | `BT_SHARE_DIR`, `BT_UNIT_DIR` |
| `tools/bt-snapshot` | `BT_SYSFS_BT` |
| `tools/bt-ui-capture` | `BT_PROC` |
| `tools/verify-restored.sh` | `BT_LIBDIR` |

**Behaviour changes, each found by a test:**

- **`tools/bt-trial`.** The closer's timeout count reads the error-priority index
  (`journalctl -k -p err`). It asks `journalctl --help` only when it needs to. Its seam
  `BT_SYSFS_MODULE` now names the parameters directory.
- **`tools/bt-phase`.** It runs the `bt-boot-list` beside it, falling back to
  `/usr/local/bin`; it used to be the other way round. Installed, those are the same
  file. From a checkout, it no longer runs whatever was last deployed.
- **`uninstall.sh`.** It checks for btusb in `/proc/modules` by exact name, instead of
  `lsmod | grep -c ^btusb`.
- **`tools/bt-usbstate`** stamps the time once, so the `--out` copy carries the same time
  as the screen. **`bin/bt-health-snapshot`** writes `-` when `uname` gives nothing,
  instead of an empty field.

## 6. What to do after merging

- **Expect `devtools/held status` to fail when offline.** That is intended.
- **Nothing to reinstall on the machine.** The seams default to the paths it already
  uses. `install.sh` and `uninstall.sh` change only as listed in §5.

## 7. Being worked on next, on this branch

- A suite aimed at isolation itself:
  - an inventory of every system resource the tools touch, each with a mock that is not
    a system file;
  - a trace of every open, read and write a test run makes;
  - a test that fails on any access outside the mocks and the run's own scratch space.
- Coverage of the remaining low spots.

Further notes will follow in this directory.
