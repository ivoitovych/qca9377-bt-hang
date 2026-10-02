# qca9377-bt-hang

### Linux Bluetooth reliability — from a controller hang to upstream fixes

[![Linux kernel: 1 accepted](https://img.shields.io/badge/Linux_kernel-1_accepted-2ea44f)](https://github.com/bluez/bluetooth-next/commit/86ef0f58bdecdedb3a1240971c56d71b7e4ce3fc)
[![BlueZ: 2 applied](https://img.shields.io/badge/BlueZ-2_applied-2ea44f)](patches/bluez/README.md)
[![checks](https://github.com/ivoitovych/qca9377-bt-hang/actions/workflows/checks.yml/badge.svg?branch=main&event=push)](https://github.com/ivoitovych/qca9377-bt-hang/actions/workflows/checks.yml)
[![License: GPL-2.0](https://img.shields.io/badge/License-GPL--2.0-blue)](LICENSE)

An investigation of Bluetooth failures on Linux, with reproducible evidence, diagnostic
tools, and **three fixes accepted upstream: one in the Linux Bluetooth kernel subsystem and
two in BlueZ**.

The work began with a Qualcomm Atheros **QCA9377** controller (USB ID `13d3:3503`) that
stopped answering during hands-free audio and came back only when power was removed.
Following the failures through the stack found defects in shared kernel and userspace code
that are not specific to this controller, and a device-table omission that was. Every
claim here ships with the command that produced it, so a stranger can re-derive it.

**What you can get from this repository**

- **Diagnose a failure:** tools that tell a controller timeout, a `bluetoothd` crash and an
  audio-layer problem apart — four things that look identical to a user.
- **Inspect upstream fixes:** the accepted commits, their reasoning and the evidence behind
  them, plus the series still under review.
- **Investigate your own device:** reusable log analysis, incident capture and sanitisation
  tools; hardware-specific conclusions are labelled as such.
- **Follow the work:** [`docs/STATUS.md`](docs/STATUS.md) is the dated snapshot of every
  issue and submission; [`HISTORY.md`](HISTORY.md) is how the beliefs changed.

## Accepted upstream contributions

| component | fix | upstream commit |
|---|---|---|
| Linux Bluetooth (MGMT) | Pending management commands flushed at power-off were answered with a status byte read from the wrong object — a Success for a Start Discovery the adapter never ran. They now carry the status the caller set (Not Powered / Invalid Index). | [`86ef0f58bdec`](https://github.com/bluez/bluetooth-next/commit/86ef0f58bdecdedb3a1240971c56d71b7e4ce3fc) (bluetooth-next, 2026-09-29) |
| BlueZ | `adapter: Fix crash on short start discovery reply` — validate the reply length before the no-clients path reads it. This is the userspace side of the kernel defect above. | [`a734b06059cb`](https://git.kernel.org/pub/scm/bluetooth/bluez.git/commit/?id=a734b06059cbe0d0f00442c901506ef17e960960) (2026-09-21) |
| BlueZ | `a2dp: Fix crash on NULL stream in transport_cb` — check that the stream still exists when the asynchronous transport acceptance completes. Its guard fired four times in nineteen days of ordinary use (`EX-041`). | [`0bed9886cff3`](https://git.kernel.org/pub/scm/bluetooth/bluez.git/commit/?id=0bed9886cff317d814f9b1f11c1461459f2b9a00) (2026-09-21) |

The three changes are in code every Linux Bluetooth adapter runs; nothing in them is
conditional on this controller's USB ID. "Accepted" means in the subsystem maintainer's
tree; inclusion in a release, stable backports and distribution packages are later
milestones, tracked in [`docs/STATUS.md`](docs/STATUS.md). Submission history and every
link (lore, patchwork, the list's CI bot) are in [`patches/bluez/README.md`](patches/bluez/README.md).

## The QCA9377 result

**The controller hang was the missing `btusb` device-table entry.** Without it `13d3:3503`
is bound as a generic adapter and runs on its ROM firmware; on that firmware the first HCI
command after a transparent (mSBC) SCO stream started got no answer, in all twelve recorded
instances, and only a power-off recovered the controller. With the entry the driver loads
the QCA firmware (`rampatch` + NVM, both in linux-firmware), and on this machine the hang
did not occur in the recorded trials:

| build | what it tested | result | record |
|---|---|---|---|
| E1 — QCA setup only | the firmware-load half of the entry, no reset callback | 58 SCO links, three boots, two headset models, every hang-up answered, 0 command timeouts | `EX-055`, `EX-056`, `EX-058` |
| E3 — the exact upstream entry | `BTUSB_QCA_ROME \| BTUSB_WIDEBAND_SPEECH`, built for `7.0.0-34` | 16 links, two headsets — including the one that wedged the stock driver in `EX-053` — 0 timeouts, 0 `0x2005` errors | `EX-057` |

The entry is upstream commit `dc16388d45ec` ("Bluetooth: btusb: Add IMC Networks QCA9377
to quirks table"), **authored by Tibor Harcsa** for a BLE scanning fault, in mainline since
v7.3-rc1 and in no stable line. This project's contribution is the diagnosis, the isolation
of the hang to the ROM firmware, the validation of the entry against it, and the stable
backport request: the commit cherry-picks onto the tip of every live stable line and
`btusb` builds with it on each (`EX-059`); the request was sent on 2026-10-02 and its
outcome is pending ([`docs/STATUS.md`](docs/STATUS.md)). What the ROM firmware does wrong
internally is not established and is not claimed. The full argument, with the September
text that first read the entry as a recovery issue rather than the cause, is
[`docs/missing-quirks-entry.md`](docs/missing-quirks-entry.md); the twelve-instance
signature table is `BRIEF.md` §2.

## Is this your problem?

One command, no installation, nothing written:

```bash
git clone https://github.com/ivoitovych/qca9377-bt-hang
cd qca9377-bt-hang
./tools/bt-diagnose
```

It shows the attached USB Bluetooth controller and scans the retained boots for HCI
command timeouts. It reports a **phenotype**, not "this bug": exit 0 = not observed in
retained history, 1 = observed, 2 = cannot determine. Only with `--probe` does it also ask
the controller whether it answers now — that sends an HCI command into whatever state the
controller is in, which is exactly what a hang you mean to observe must not receive.

**Four things look identical to a person and are not the same fault.** Bluetooth "stops
working" here has meant: the controller wedge above; an audio-server transport release with
the controller healthy (`EX-030`); a synchronous link that came up and worked (`EX-031`);
and `bluetoothd` crashing, leaving the adapter powered and never scanning again (`EX-032`
— the two BlueZ patches). `tools/bt-crash` tells the last apart from the rest in one
command; `tools/bt-status` gives the verdict on the first.

**If your controller is different**, most of this transfers. `bt-diagnose`, `bt-state`,
`bt-boots`, `bt-crash` and `sanitize-logs.sh` work on any USB controller; every tool
takes `BT_VID`/`BT_PID`; `bt-incident` collects a hang that already happened into a
sanitised, publishable session; `bt-exhibit` captures a claim with its command and output
in one pass; the journal seam (`tools/lib/journal.sh`) lets every analysis run over a
fixture instead of a live machine. Specific to this part: the alternate-setting reading in
`bt-usbstate` and `bt-fault-window`, the `13d3:3503` defaults, and the exhibits.

**If you have a QCA9377 and the hang:** a kernel carrying `dc16388d45ec` is the fix. Until
your distribution ships one, the entry is a two-line addition to `drivers/bluetooth/btusb.c`
(the exact text is in the stable request, `docs/STATUS.md`). Check which `btusb` you run
with `tools/bt-verify-kernel-mechanism`, not the kernel version — backports move.

## Current direction — 2026-10-03

- **Stable backport of `dc16388d45ec`:** requested for 7.2.y, 6.18.y, 6.12.y, 6.6.y and
  6.1.y; waiting for the stable team.
- **Delivery of the three accepted fixes** into kernel and BlueZ releases and into Ubuntu:
  tracked, nothing owed yet.
- **A mesh advertising series for the kernel** (three patches, found while reading why the
  list's `mesh-tester` fails on every submission since June) is written, tested in qemu and
  under its second outside review; it is not submitted.
- **Desktop audio issues** seen while testing the fixed driver (codec switches, reconnect
  policy, a GNOME codec row) are recorded in [`docs/issues.md`](docs/issues.md) as leads
  with evidence; upstream fixes are checked before anything new is written.

The dated detail, one row per issue and submission, is [`docs/STATUS.md`](docs/STATUS.md).

## Environment

```
Distribution : Ubuntu 24.04 LTS (noble)
Kernels      : 7.0.0-29, -30, -31, -34-generic (the twelve instances); 6.17.0-29/35/40, 7.0.0-28 (earlier phenotype)
BlueZ        : 5.72 (5.72-0ubuntu5.5; the patched daemon is a rebuild of that source)
Platform     : AMD Renoir/Cezanne laptop; controller on xhci_hcd, full-speed
BT device    : usb 13d3:3503 — HCI manufacturer 0x001D (Qualcomm), version 0x07 (4.2)
Companion    : ath10k_pci qca9377 hw1.1 (one combo chip)
Headsets     : Sennheiser MOMENTUM 4, Lenovo thinkplus GM2 pro, Shure AONIC 50 (three vendors, one signature — EX-024, EX-053)
```

Windows 11 on the same laptop shows no fault under deliberate repeated use; Windows loads
the controller's firmware, which is what the missing entry withheld on Linux.

## Method, in five rules

1. **Every claim ships with its extraction command and verbatim output**, plus exit status
   and whether it was redacted. A claim without a re-runnable derivation is not evidence.
2. **A zero needs a positive control.** A scan that saw nothing is not a scan that found
   nothing.
3. **The liveness probe is an intervention.** Inside an untreated window, `sysfs` reads
   are safe and anything that sends a command is not.
4. **Separate what the operator did from how the controller responded.** Trigger
   attributions are inferences from logs; response measurements survive that.
5. **Retractions are kept, not deleted.** `BRIEF.md` §5 lists every claim this project
   asserted and later refuted, so nobody re-asserts one.

The formulation of the controller fault as the issue register carries it (`docs/issues.md`,
where it is filed as `BT-1`, the project's own search handle):

<!-- BT1-CURRENT-BEGIN -->
> The controller sometimes enters a non-responsive HCI state during synchronous-audio link
> transitions, while remaining USB-enumerated. Later USB collapse has so far only been
> observed after a reset, rebind or driver reload; whether it belongs to the fault's
> untreated trajectory is **unresolved**.
<!-- BT1-CURRENT-END -->

## Repository map

```
README.md             this page: purpose, results, routes
docs/STATUS.md        the dated snapshot: every issue and submission, its state and next step
BRIEF.md              the maintainers' hand-off: machine state, constraints, rules paid for, retractions
HISTORY.md            chronological development record, wrong turns included (37 phases and a chapter)
bin/                  watchdog, capture daemons, metrics collector
systemd/ etc/         unit files; modprobe + udev + journald configuration
tools/                diagnostics, incident capture, log sanitiser
  lib/                shared awk/sh programs (timestamps, matching, reports, the journal seam)
scripts/              the helpers behind the exhibits (ledgers, build matrix, mail checks, proofs)
tests/                run-tests — invariants, each anchored to a real shipped defect
devtools/             contributor tooling (check, scan, validate, coverage, ci, commit+verify)
reviews/              assessments of the repository itself; README.md there is the live action register
comms/  lessons/      messages between the maintainers; what the project cost to learn
patches/bluez/        the two applied BlueZ patches, their verification script and mail notes
docs/                 issues.md (issue register) · missing-quirks-entry.md · install.md ·
                      tooling-index.md · the historical plans and drafts, each labelled
evidence/
  exhibits/           numbered, self-verifying evidence exhibits — README.md there is the index
  sessions/           one directory per reproduction session, sanitised
  trials/             numbered trials and results.tsv (the denominators)
  baseline/ diagnosis/  the failing boot before any mitigation; the device-table transcripts
```

**Branches.** `main` is the record. `review/<UTC timestamp>` holds one assessment
(report first, then the reaction on `review/<timestamp>-fixes`), per the convention in
[`reviews/README.md`](reviews/README.md). Work that must not be public before it is sent
— kernel patches and their reviews — lives on a private remote until submission and is
recorded here only by its facts. CI (`.github/workflows/checks.yml`) runs the suite, the
coverage floors and the publish scan on every push; `devtools/ci` reads its verdict.

## Install, tools, tests

- **Install:** [`docs/install.md`](docs/install.md). Passive diagnosis needs nothing
  installed. On a machine you are *measuring*, use `sudo ./install.sh --tools-only`.
  `--apply` arms an experimental watchdog whose USB reset has three controlled
  demonstrations of driving an already-wedged controller off the USB bus until power is
  removed (`EX-023`, `EX-026`) — not permanent damage, but the one state a power-off is
  then the only way out of.
- **Tools:** [`docs/tooling-index.md`](docs/tooling-index.md) — which tool answers which
  question. The standalone ones (`bt-diagnose`, `bt-state`, `bt-boots`, `bt-boot-list`,
  `sanitize-logs.sh`) need no installation.
- **Publishing logs:** kernel logs carry your Wi-Fi access point BSSID, which public
  geolocation databases index. Run `./tools/sanitize-logs.sh <log>` before attaching
  anything anywhere; it replaces MACs, BSSIDs and IPv4 addresses with deterministic
  placeholders and verifies none survived. `devtools/repo-scan` refuses to publish
  otherwise.
- **Tests:** [`tests/README.md`](tests/README.md).
  <!-- No invariant count or coverage percentage is spelled here ON PURPOSE.
       Both numbers move with nearly every commit, and this page carried
       "96 invariants" while the suite reported 386 and "18.3%" while the
       measured figure was ~87% (review 2026-08-15T1752Z §1.1). The suite and
       devtools/coverage print the current numbers; the reviews/ register
       tracks the trend. Quote those, not a snapshot pasted here. -->
  ```bash
  tests/run-tests        # every invariant encodes a defect that really shipped here
  devtools/coverage      # how much of the shipped shell the suite executes
  devtools/check         # the one command to run before committing
  ```

## Contributing

Most useful, in this order:

- **a QCA9377 (`13d3:3503`) on a kernel that carries `dc16388d45ec`** with an mSBC headset
  — `./tools/bt-diagnose`, then `scripts/sco-ledger.sh 0` after a few hands-free calls;
  the prediction is every hang-up answered and no command timeout;
- the same signature on **another controller** that matches no quirks entry (`bt-diagnose`,
  then `bt-fault-window` around the first timeout);
- a run on a kernel in the **v5.8–v5.11 window** on the stock entry-less driver — the
  untested prediction is that it logs `Device does not support ALT setting 6` and never
  takes the alternate-setting-1 path (below v5.8 that path is reachable by another route).

Messages between maintainers go in [`comms/`](comms/); every number carries the command
that produced it. Reports of evidence from other machines are welcome as issues on this
repository: a sanitised `bt-incident` session, or the output of `bt-diagnose` and
`bt-boots`, says more than a description.

## License

GPL-2.0. See [LICENSE](LICENSE).
