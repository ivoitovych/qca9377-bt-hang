# System resources: what the project touches, and how the suite keeps it away

Every machine resource that this repository's code reads, writes or runs, and
for each one the mechanism that keeps the suite off the real one.

Made on 2026-10-09 in two passes:
- **What the code names.** Every code file was read: the tools, the units and
  configuration, the developer tools, the operator scripts and the suite. About
  3,000 accesses were recorded with their file and line.
- **What a run reaches.** The whole suite was run under `strace` and every file
  access, made or attempted, was classified. That trace is the authority: where
  the reading of the code and a run disagree, the run wins.

Two checks keep this file true:
- an invariant in `tests/run-tests` derives the seam list in §1 from the code,
  and fails on a seam that is missing here or not declared for the run;
- `devtools/access-audit` fails on any access a run makes that is not isolated
  or named in [`access-allowlist`](access-allowlist).

## The mechanisms, and what proves each one

| mechanism | what it isolates | proved by |
|---|---|---|
| **seams** (`BT_*`), declared for the whole run | every machine path in §1 | the access audit; the decoy world (`devtools/sandbox`) |
| **the tripwire** (`tests/machine-tools`) | every command in §2: undeclared, it answers nothing and fails the run | its canary, and the end-of-run check that no call reached it |
| **fixtures** (`BT_JOURNAL_FIXTURE`, `BT_COREDUMP_FIXTURE`, `BT_CAPTURE_SOURCE`) | the journal, core dumps, the HCI socket (§4) | the suite's journal-call invariant; `devtools/journal-contract` |
| **a staging root** (`BT_DESTDIR`) | everything `install.sh` and `uninstall.sh` write, and everything `verify-restored.sh` checks | the install tests; the suite's before-and-after fingerprint of the real paths |
| **the run's own host state** | `HOME`, `XDG_CONFIG_HOME`, git's configuration, system attributes, Python's user site, `TMPDIR`, the trial state (§3) | the access audit |
| **the namespace world** (`unshare -Urm`, tmpfs) | `bt-ui-capture`'s shipped defaults, which no seam may replace | its self-proof (tests/README.md, rule 6) |
| **the checkout world** (`unshare -Urmn`, overlay) | the checkout, its branches and remotes, and the network, for the tools that commit and push | its self-proof |
| **end-of-run checks** | the evidence tree, the real trial state, tracked files, `/usr/bin`, orphaned processes | themselves, by snapshot before and after |

## 1. Paths: every seam whose default is on the machine

All of them are declared for the whole run, in the block of `tests/run-tests`
headed *"AND THE REST OF THE MACHINE, DECLARED THE SAME WAY"* and the blocks after
it. Four are declared through the seam their default lies under:
`BT_TRACE_DIR`, `BT_CAPTURE_DIR` and `BT_USBMON_DIR` through `BT_HEALTH_DIR`, and
`BT_PROC_MODULES` through `BT_PROC`. `bt-actions`' fixture guard needs
`BT_TRACE_DIR` itself unset. A test that needs a device, a stamp or a log builds
one and points the seam at it. A test that forgets meets an empty machine.

| seam | machine default | read or written by |
|---|---|---|
| `BT_PROC` | `/proc` (boot id, uptime, environ) | bt-evidence, bt-health-snapshot, bt-exhibit, bt-logvolume, bt-ui-capture, verify-restored.sh, install.sh, uninstall.sh |
| `BT_PROC_MODULES` | `/proc/modules` | install.sh, uninstall.sh |
| `BT_SYSFS_USB` | `/sys/bus/usb/devices` | bt-hang-watchdog, bt-health-snapshot, bt-evidence, bt-mark, bt-usbmon, bt-diagnose, bt-health-report.sh, bt-mode, bt-postmortem, bt-snapshot, bt-state, bt-status, bt-trial, bt-usbstate, verify-restored.sh, install.sh |
| `BT_SYSFS_MODULE` | `/sys/module/btusb/parameters` | bt-evidence, bt-health-snapshot, bt-health-report.sh, bt-mode, bt-state, bt-trial, verify-restored.sh |
| `BT_SYSFS_BT` | `/sys/class/bluetooth` | bt-health-report.sh, bt-postmortem, bt-snapshot, bt-status |
| `BT_SYSFS_DRIVERS` | `/sys/bus/usb/drivers/usb` (unbind and bind: **an actuator**) | bt-hang-watchdog |
| `BT_DEVFS_USB` | `/dev/bus/usb` (`USBDEVFS_RESET`: **an actuator**) | bt-hang-watchdog |
| `BT_DYNDBG_CTL` | `/sys/kernel/debug/dynamic_debug/control` (written) | bt-dyndbg, bt-ui-capture |
| `BT_USBMON_DEBUGFS` | `/sys/kernel/debug/usb/usbmon` | bt-usbmon |
| `BT_MODULES_DIR` | `/lib/modules` | bt-verify-kernel-mechanism |
| `BT_RUN_USER_DIR` | `/run/user` (session buses, for notifications via sudo) | bt-hang-watchdog |
| `BT_STATE` | `/run/bt-trial` (the open trial, written) | bt-trial, install.sh |
| `BT_EVIDENCE_STATE` | `/run/bt-evidence` | bt-evidence |
| `BT_HEALTH_DIR` | `/var/log/bt-health` | bt-capture, bt-evidence, bt-trace, bt-usbmon, bt-actions, bt-capdiff, bt-health-report.sh, bt-incident, bt-sco, bt-status, bt-trial, verify-restored.sh |
| `BT_TRACE_DIR` | `$BT_HEALTH_DIR/trace` | bt-evidence, bt-trace, bt-actions, bt-capdiff, bt-incident, bt-sco, bt-status, bt-trial |
| `BT_CAPTURE_DIR` | `$BT_HEALTH_DIR/capture` | bt-capture, bt-capdiff, bt-trial |
| `BT_USBMON_DIR` | `$BT_HEALTH_DIR/usbmon` | bt-usbmon |
| `BT_METRICS` | `/var/log/bt-health/metrics.tsv` (appended) | bt-health-snapshot, bt-env-history, bt-health-report.sh |
| `BT_UI_BASE` | `/var/log/bt-health/ui` | bt-ui-capture |
| `BT_UI_CAPTURE_DIRS` | `/var/log/bt-health/capture /var/log/bt-health/trace` | bt-ui-capture |
| `BT_UI_APPDIR` | `/usr/share/applications` (launcher overrides written) | bt-ui-capture |
| `BT_SHARE_DIR` | `/usr/local/share/qca9377-bt-hang` (the install stamp) | bt-health-report.sh |
| `BT_MODE_STAMP` | `/usr/local/share/qca9377-bt-hang/mode` | install.sh, bt-mode, bt-verify-install |
| `BT_UNIT_DIR` | `/etc/systemd/system` | bt-health-report.sh |
| `BT_UDEV_DIR` | `/etc/udev/rules.d` (moved aside by bt-mode) | bt-mode, bt-verify-install |
| `BT_MODPROBE_CONF` | `/etc/modprobe.d/btusb-qca9377.conf` (moved aside by bt-mode) | bt-mode |
| `BT_SNAPSHOT_DIR` | `/var/tmp/bt-snapshots` | bt-snapshot |
| `BT_ARCHIVE_DIR` | `~/bt-journal-archive` | bt-archive, bt-backup-journal |
| `BT_EVIDENCE_REPO` | this checkout's `evidence/` (incidents written) | bt-evidence, bt-incident, bt-retention, bt-trial-audit |

Until 2026-10-09 the trace, capture and usbmon directories had their own
defaults, and `bt-incident` had the trace directory written into it. They now
derive from `BT_HEALTH_DIR`, so declaring one directory declares all four.

## 2. Commands that read or change the machine

[`machine-tools`](machine-tools) **is** the list: each command there answers from
the tripwire for the whole run, and a call nobody declared fails the run with its
caller. A test that needs one declares it with `machine_stub`, which gives a quiet,
defined machine. The families are:
- services and the session: `systemctl`, `journalctl`, `coredumpctl`, `loginctl`,
  `busctl`, `systemd-run`, `runuser`, `sudo`;
- Bluetooth: `bluetoothctl`, `btmgmt`, `btmon`, `hciconfig`, `hcitool`, `rfkill`;
- devices, modules and the kernel: `udevadm`, `lsusb`, `modprobe`, `rmmod`,
  `insmod`, `lsmod`, `depmod`, `dmesg`, `uname`, `uptime`;
- D-Bus, audio and the desktop: `dbus-send`, `gdbus`, `pw-dump`, `wpctl`, `pactl`,
  `notify-send`, `logger`;
- the network: `curl`, `wget`, `gh`, `nmcli`, `iw`, `tcpdump`.

The actuators among the project's own code are the ones the suite must never let
act:
- **`bin/bt-hang-watchdog`** resets a USB device, unbinds and rebinds it, and
  stops and starts bluetooth;
- **`install.sh` and `uninstall.sh`** reload `btusb` under `--apply`;
- **`tools/bt-mode`** disables the watchdog and moves `/etc` files aside;
- **`tools/bt-ui-capture`** starts transient root units and sets PipeWire's log
  level.

Each runs under test only against stubs and seams. The trace shows no call
reaching the real one.

## 3. Host state no seam names

| what | how the run keeps it away | since |
|---|---|---|
| the user's configuration (`~/.jq`, `~/.config/git/*`, Python's user site) | `HOME` and `XDG_CONFIG_HOME` point at an empty home of the run's own; `PYTHONNOUSERSITE=1` | 2026-10-09, found by the trace |
| git's configuration | `GIT_CONFIG_GLOBAL` (the run's own), `GIT_CONFIG_NOSYSTEM=1`, `GIT_ATTR_NOSYSTEM=1`; the host's `safe.directory` entries are copied, nothing else | 2026-09-28 / 2026-10-09 |
| temporary files | `TMPDIR` is one directory of the run's own, removed at exit | 2026-08 |
| the open-trial state | `BT_TRIAL_STATE_DIR`, declared after the refusal at the top has read the real one | 2026-10-09, found by the trace |
| installed copies of the project's tools | the PATH guard puts a recording stub first for every name `install.sh` installs | 2026-08-14 |
| the network | the checkout world runs in a network namespace; network clients are on the tripwire | 2026-10-08 |
| user identity (`/etc/passwd`, via `id`) | **allowed**: the bt-ui-capture tests resolve their fixture user's name | — |

## 4. Data read through fixtures

| resource | seam | notes |
|---|---|---|
| the journal | `BT_JOURNAL_FIXTURE` (tools/lib/journal.sh) | an invariant forbids a converted tool a direct `journalctl` |
| retained core dumps | `BT_COREDUMP_FIXTURE` (tools/lib/coredump.sh) | three fixture claims are checked against real `coredumpctl` through `real_tool`, the one sanctioned door |
| the HCI monitor socket | `BT_CAPTURE_SOURCE` | bt-capture reads frames from a file instead |

## 5. The repository's own evidence

`evidence/sessions/`, `evidence/trials/results.tsv` and the exhibits are real
evidence. The suite reads the results file and the exhibit index as data. It never
writes the tree: `BT_EVIDENCE_REPO` is declared for the run, and the last check
counts `evidence/sessions/` before and after (tests/README.md, rule 4).

## 6. Out of the suite's scope: `scripts/` and `retest/`

Operator scripts, run by hand on the investigation machine and never by the
suite. Several change the machine by design:
- `scripts/module-updates.sh` installs modules and runs `depmod`;
- `scripts/runtime-mgmt-test.sh` runs `modprobe -r`, `insmod` and `bluetoothctl
  power off`;
- `scripts/stop-own-process.sh` sends TERM;
- `scripts/fix-time-ranges.py` rewrites files in place;
- the `retest/` kit builds and runs kernels in QEMU.

The coverage instruments list them as out of scope, by name. Nothing here claims
they are isolated.

## 7. Open

- **The PATH still ends with the host's.** After the run's farms, stubs and the
  tripwire, the inherited PATH follows, with directories such as `~/.local/bin`.
  This host has a non-executable `env` there. A host binary named like a standard
  tool would win over `/usr/bin`. A declared PATH is the next step.
- **Host tool presence changes behaviour.** `bt-health-report.sh` formats with
  `column` when it exists, and `bt-archive` prefers `zstd`. The tests pass both
  ways here, but neither choice is declared.
- **The clock** is not isolated. Tests whose verdicts depend on time use fixed
  epochs. The rest read the real clock.
