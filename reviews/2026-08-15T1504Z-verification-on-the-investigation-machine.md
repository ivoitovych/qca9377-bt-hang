# Verification of `9a11ab7` on the investigation machine

**Written:** 2026-08-15T15:04Z
**Covers:** `tests/unit-testing-assessment` at `9a11ab7`, merged onto `main` at `ed82166`
**Ran on:** the QCA9377 investigation host — bluez, systemd, udev and the project all
installed, `13d3:3503` present, experiment mode active
**Method:** full `tests/run-tests`, with the at-risk system binaries snapshotted before
and diffed after

> This report is a snapshot and is not edited after the fact. Corrections go in a later
> report; current status belongs in `reviews/README.md`.

---

## Result

| | |
|---|---|
| Invariants | **566 of 567 pass** |
| System binaries | **byte-identical** before and after the run |
| Machine | healthy — capture services active, watchdog off, controller enumerated |

The single failure is a malformed test fixture, described below. No product defect was
found by this run.

## `farm_dir()` is verified on the configuration that broke

This matters more than the pass count. Ninety minutes before this run, the previous
revision of these tests destroyed three system binaries on this host:

| binary | became | consequence |
|---|---|---|
| `/usr/bin/timeout` | 37 bytes, `exec /usr/bin/timeout "$@"` | **infinite recursion** — the suite, `apt`, and any command using `timeout` hung |
| `/usr/bin/systemctl` | 71-byte stub | service management broken |
| `/usr/bin/btmgmt` | 67-byte stub | Bluetooth probe tool broken |

Cause: a symlink farm built over a directory that the surrounding test code then wrote
into. `>` and `cp` both write **through** a symlink to its target.

`9a11ab7` separates the farm from the stub directory, so no destination is ever a symlink
at the moment something is written to it. The verification is direct rather than
inferential: the same suite, on the same host, through the same watchdog section, with
the binaries diffed before and after —

```console
$ diff /tmp/binsnap-before.txt /tmp/binsnap-after.txt && echo "IDENTICAL"
IDENTICAL
```

covering `timeout`, `systemctl`, `btmgmt`, `sleep`, `hciconfig`, `bluetoothctl`,
`udevadm` and `modprobe`.

**The ordering fix would not have earned this.** Removing named symlinks before writing
them is correct on the day it is written and silently wrong when someone adds a fourth
stub. Separating the directories removes the requirement rather than documenting it.

## The one failure: a malformed fixture, not a defect

```
✗ repo-validate said nothing about (rc=1):; a.rules
```

`tests/run-tests:6422` plants:

```
ACTION=="add", SUBSYSTEM=="usb", ATTR{idVendor}=="13d3"
```

That is **all match conditions and no action** — no `RUN+=`, no `SYMLINK+=`. `udevadm`
rejects it, correctly:

```console
$ udevadm verify a.rules
a.rules:1 The line has no effect, ignoring.
a.rules: udev rules check failed.
  Success: 0
  Fail:    1
```

So `repo-validate` behaved correctly and reported an invalid rule; the assertion expects
a ✓ or a •, gets a ✗, and fails. Adding any action term makes it pass — confirmed with
`RUN+="/bin/true"`, which `udevadm` accepts.

**Fourth instance of the same family.** It passes wherever `udevadm` is absent, because
`repo-validate` then prints `• udev … (skipped: udevadm not installed)`, which the
assertion accepts. Preceded by: the `bt-state` btmgmt fallback, the watchdog no-probe
test, and the watchdog btmgmt test — all of which passed on a bare checkout and failed
here.

The recurring shape is not "these tests are fragile". It is that **a test whose subject
is a tool's behaviour cannot be validated where the tool is missing**, and the skip path
that makes the suite portable is the same path that makes the assertion vacuous.

## What this host contributes, stated plainly

Every defect in this round surfaced here and nowhere else:

| finding | why it needs this host |
|---|---|
| staging gate ran live `systemctl enable --now` | the suite stubs those commands; only an unstubbed human run reaches it |
| three `PATH="$STUB:/usr/bin"` tests | `hciconfig`/`btmgmt` must exist to shadow the stub |
| `a.rules` fixture | `udevadm` must exist for the check to run at all |
| write-through symlink damage | `/usr/bin` must contain real binaries worth destroying |

That is the argument for continuing to verify here — and equally the argument for doing
it in a throwaway VM that reproduces the *configuration* rather than on the host carrying
the experiment. Both incidents this session were controls that held where the code was
developed and not where it ran; a VM with bluez, systemd and udev installed reproduces
the second condition without risking the first.

## Not done here, deliberately

The `a.rules` fixture is **not** fixed in this branch. Two prior attempts to repair tests
in this file from this side cost three system binaries, and the maintainer has asked to
be pulled from rather than re-fixed. One-token change; theirs to make.
