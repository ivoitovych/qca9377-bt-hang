# qca9377-bt-hang

### Linux Bluetooth reliability — from a controller hang to upstream fixes

[![Linux kernel: 1 in mainline](https://img.shields.io/badge/Linux_kernel-1_in_mainline-2ea44f)](https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git/commit/?id=86ef0f58bdec)
[![Linux stable: 3 backports, 1 released](https://img.shields.io/badge/Linux_stable-3_backports%2C_1_released-2ea44f)](patches/kernel/bt9-stable/README.md)
[![BlueZ: 8 applied](https://img.shields.io/badge/BlueZ-8_applied-2ea44f)](#accepted-upstream-contributions)
[![checks](https://github.com/ivoitovych/qca9377-bt-hang/actions/workflows/checks.yml/badge.svg?branch=main&event=push)](https://github.com/ivoitovych/qca9377-bt-hang/actions/workflows/checks.yml)
[![License: GPL-2.0](https://img.shields.io/badge/License-GPL--2.0-blue)](LICENSE)

An investigation of Bluetooth failures on Linux, with reproducible evidence, diagnostic
tools, and **upstream contributions: a Linux Bluetooth kernel fix (in mainline, released in v7.3),
eight BlueZ commits (four fixes and four test or emulator changes), and three stable
backports of another author's kernel fix**.

The work began with a Qualcomm Atheros **QCA9377** controller (USB ID `13d3:3503`) that
stopped answering during hands-free audio and came back only when power was removed.
Following the failures through the stack found defects in shared kernel and userspace code
that are not specific to this controller, and a device-table omission that was. Every
claim here ships with the command that produced it, so a stranger can re-derive it.

**What you can get from this repository**

- **Diagnose a failure:** tools that tell a controller timeout, a `bluetoothd` crash and an
  audio-layer problem apart — four things that look identical to a user.
- **Inspect upstream fixes:** the accepted commits, their reasoning and the evidence behind
  them, plus the backports and the tests of other authors' patches.
- **Investigate your own device:** reusable log analysis, incident capture and sanitisation
  tools; hardware-specific conclusions are labelled as such.
- **Follow the work:** [`docs/STATUS.md`](docs/STATUS.md) is the dated snapshot of every
  issue and submission; [`HISTORY.md`](HISTORY.md) is how the beliefs changed.

## Accepted upstream contributions

| component | fix | upstream commit |
|---|---|---|
| Linux Bluetooth (MGMT) | Pending management commands flushed at power-off were answered with a status byte read from the wrong object — a Success for a Start Discovery the adapter never ran. They now carry the status the caller set (Not Powered / Invalid Index). | [`86ef0f58bdec`](https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git/commit/?id=86ef0f58bdec) (bluetooth-next 2026-09-29; in v7.3, released 2026-10-18, first in v7.3-rc7; stable 7.2.11, 6.18.57 and 6.12.113; in the 6.6 and 6.1 release candidates of 2026-10-17) |
| BlueZ | `adapter: Fix crash on short start discovery reply` — validate the reply length before the no-clients path reads it. This is the userspace side of the kernel defect above. | [`a734b06059cb`](https://git.kernel.org/pub/scm/bluetooth/bluez.git/commit/?id=a734b06059cbe0d0f00442c901506ef17e960960) (2026-09-21) |
| BlueZ | `a2dp: Fix crash on NULL stream in transport_cb` — check that the stream still exists when the asynchronous transport acceptance completes. Its guard fired four times in nineteen days of ordinary use (`EX-041`). A redundant v2 was applied on top on 2026-10-07 (`d84171e6cd68`), leaving the check twice in a row; the removal of the second copy was sent on 2026-10-18 (below). | [`0bed9886cff3`](https://git.kernel.org/pub/scm/bluetooth/bluez.git/commit/?id=0bed9886cff317d814f9b1f11c1461459f2b9a00) (2026-09-21) |
| BlueZ | `shared/mgmt: Fix notify leak in mgmt_unregister()` + `unit/test-mgmt: Test unregistering from callbacks` — unregistering from a notification callback leaked the entry, and unregistering the next entry was a use-after-free (the crash fixed for the sibling function in 2015). The new unit tests fail without the fix; the testers' 233 leaked `mgmt_register()` allocations go to 0 with every verdict unchanged ([`patches/bluez/shared-mgmt/`](patches/bluez/shared-mgmt/README.md)). Sent and applied the same day, unchanged. | [`ae23df052290`](https://git.kernel.org/pub/scm/bluetooth/bluez.git/commit/?id=ae23df052290) + [`6f5eeb402d3b`](https://git.kernel.org/pub/scm/bluetooth/bluez.git/commit/?id=6f5eeb402d3b) (2026-10-08) |
| BlueZ | `emulator: Free hooks in btdev_destroy` — five mgmt-tester cases and one l2cap-tester case leaked a hook; found while writing the test below. | [`8da7e648a9fb`](https://git.kernel.org/pub/scm/bluetooth/bluez.git/commit/?id=8da7e648a9fb) (2026-10-12) |
| BlueZ | `mgmt-tester: Add simultaneous discovery stop tests`, with `emulator: Add btdev_send_event` and `emulator/vhci: Add vhci_set_quirk_simultaneous_discovery` — a deterministic regression test for the kernel race in which a simultaneous discovery never stops ([`patches/kernel/bt9-stable/`](patches/kernel/bt9-stable/README.md)). | [`f3344d20d904`](https://git.kernel.org/pub/scm/bluetooth/bluez.git/commit/?id=f3344d20d904), [`2942883d2738`](https://git.kernel.org/pub/scm/bluetooth/bluez.git/commit/?id=2942883d2738), [`49a70562f0bf`](https://git.kernel.org/pub/scm/bluetooth/bluez.git/commit/?id=49a70562f0bf) (2026-10-12) |

The kernel fix and the four BlueZ fixes are in code every Linux Bluetooth adapter runs;
nothing in them is conditional on this controller's USB ID. The emulator and `mgmt-tester`
commits are test infrastructure: they make the discovery race reproducible in BlueZ's own
test suite. "Accepted" means in the subsystem maintainer's
tree; inclusion in a release, stable backports and distribution packages are later
milestones, tracked in [`docs/STATUS.md`](docs/STATUS.md). Submission history and every
link (lore, patchwork, the list's CI bot) are in [`patches/bluez/README.md`](patches/bluez/README.md).

### Backports and testing of others' patches

Not code of this project, but upstream work done here: getting another author's fix to users
of older kernels, and testing other authors' patches as posted.

| upstream | contribution | state |
|---|---|---|
| Linux stable | Backport request for [`dc16388d45ec`](https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git/commit/?id=dc16388d45ec) (the QCA9377 device-table entry, authored by Tibor Harcsa — the fix for this repository's original hang), with the cherry-pick and build verified on every target line (`EX-059`) | requested 2026-10-02 ([lore](https://lore.kernel.org/r/20261002012542.473669-1-yaroslav.voytovych@gmail.com)); queued for seven lines (stable-queue [`007ed56547de`](https://git.kernel.org/pub/scm/linux/kernel/git/stable/stable-queue.git/commit/?id=007ed56547dedc050e1af25976bdfb299aa99b67), `EX-061`); **released in 7.2.10 and 6.18.56** (2026-10-11) **and 6.12.113** (2026-10-15); in the 6.6, 6.1, 5.15 and 5.10 release candidates of 2026-10-17 |
| Linux Bluetooth (MGMT) | `Tested-by` on Hui Peng's "Bluetooth: MGMT: fix mesh_tx leak on hci_cmd_sync_queue() failure" ([patchwork 14831271](https://patchwork.kernel.org/patch/14831271/)), which its author had not reproduced: the leak reproduced without fault injection (a Mesh Send while powered off), the posted patch compared with an unpatched control in QEMU, and requests answered Failed shown to be transmitted later; reproducer, configs and 159 VM logs in [`retest/mesh-tx-leak/`](retest/mesh-tx-leak/REPORT.md) | sent 2026-10-06 ([lore](https://lore.kernel.org/r/20261006201800.3597400-1-yaroslav.voytovych@gmail.com)); the patch is pending |
| Linux stable | Backports of [`96d006ae6445`](https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git/commit/?id=96d006ae6445) (Jiajia Liu's fix for simultaneous discovery that never stops, which left this laptop unable to scan for days) to 6.12, 6.6 and 6.1 — the lines where the `dc16388d45ec` backport gives this device the quirk that exposes it — each built and tested with a new deterministic `mgmt-tester` case that fails without the backport and passes with it ([`patches/kernel/bt9-stable/`](patches/kernel/bt9-stable/README.md)) | sent 2026-10-10 ([6.12.y](https://lore.kernel.org/r/20261010022523.2789588-1-yaroslav.voytovych@gmail.com), [6.6.y](https://lore.kernel.org/r/20261010022523.2789588-2-yaroslav.voytovych@gmail.com), [6.1.y](https://lore.kernel.org/r/20261010022523.2789588-3-yaroslav.voytovych@gmail.com)); queued 2026-10-11; **released in 6.12.113** (2026-10-15); in the 6.6 and 6.1 release candidates of 2026-10-17 |

Also: a reply on [BlueZ issue #1554](https://github.com/bluez/bluez/issues/1554#issuecomment-6089903035)
(2026-10-09), whose reporter had the same stuck discovery, pointing to the kernel fix; the
reporter's own capture shows the same event ordering.

**Submitted 2026-10-18, waiting for review** ([`patches/bluez/send-2026-10-18/`](patches/bluez/send-2026-10-18/README.md)):
`a2dp: Remove duplicate check in transport_cb` (patchwork
[14897668](https://patchwork.kernel.org/project/bluetooth/patch/20261018043903.1756818-1-yaroslav.voytovych@gmail.com/)),
which removes the second copy of the check above, and `emulator: Avoid variable length array
in send_cmd` (patchwork
[14897669](https://patchwork.kernel.org/project/bluetooth/patch/20261018043911.1756937-1-yaroslav.voytovych@gmail.com/)),
which clears the smatch warning that BlueZ's CI posts on every patch touching `emulator/btdev.c`.

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
| E3 — the exact upstream entry | `BTUSB_QCA_ROME \| BTUSB_WIDEBAND_SPEECH`, built for `7.0.0-34` (and, since 2026-10-11, running on `7.0.0-38`) | 16 links, two headsets — including the one that wedged the stock driver in `EX-053` — 0 timeouts, 0 `0x2005` errors | `EX-057` |

The entry is upstream commit `dc16388d45ec` ("Bluetooth: btusb: Add IMC Networks QCA9377
to quirks table"), **authored by Tibor Harcsa** for a BLE scanning fault, in mainline since
v7.3-rc1. This project's contribution is the diagnosis, the isolation of the hang to the ROM
firmware, the validation of the entry against it, and the stable backport request: the
commit cherry-picks onto the tip of every live stable line and `btusb` builds with it on
each (`EX-059`); the request was sent on 2026-10-02, and the stable team **queued it for all
seven live lines — 7.2, 6.18, 6.12, 6.6, 6.1, 5.15 and 5.10** — confirmed in the public stable
queue on 2026-10-03 (`EX-061`). It was released in 7.2.10 and 6.18.56 on 2026-10-11 and in
6.12.113 on 2026-10-15, and is in the release candidates of the other four lines, cut on
2026-10-17 ([`docs/STATUS.md`](docs/STATUS.md)). What the ROM firmware does wrong
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

**If you have a QCA9377 and the hang:** a kernel carrying `dc16388d45ec` is the fix — mainline
from v7.3, stable 7.2.10, 6.18.56 and 6.12.113, and the next stable release of 6.6, 6.1, 5.15
and 5.10 (6.6.160, 6.1.191, 5.15.224, 5.10.273; in release candidate since 2026-10-17). Until
your distribution ships one, the entry is a two-line addition to
`drivers/bluetooth/btusb.c`. Check which `btusb` you run with
`tools/bt-verify-kernel-mechanism`, not the kernel version — backports move.

## Current direction — 2026-10-18

- **Stable backport of `dc16388d45ec`:** released in 7.2.10, 6.18.56 and 6.12.113; in the
  release candidates of 6.6, 6.1, 5.15 and 5.10 (`EX-061`). Ubuntu's current kernel,
  `7.0.0-38`, and the one in testing, `7.0.0-39`, lack the entry, and 7.0 is no longer
  maintained upstream, so an Ubuntu request is next.
- **Simultaneous discovery that never stops (2026-10-09, `EX-062`).** With the device-table entry in place, this laptop's device discovery stayed stuck from 2026-10-04 until an adapter power cycle on 10-10. The kernel cause was already fixed upstream, but not in 6.12, 6.6 or 6.1, the older lines the `dc16388d45ec` backport reaches. Backports to those three, a BlueZ regression test and a BlueZ leak fix were sent on 2026-10-10; the 6.12 backport is released (6.12.113), the 6.6 and 6.1 ones are in release candidates, and the BlueZ commits are applied (tables above).
- **Delivery of the accepted changes** into kernel and BlueZ releases and into Ubuntu:
  tracked, nothing owed yet. No BlueZ release carries them yet (the newest tag is 5.87).
- **The kernel mesh advertising work** (found while reading why the list's `mesh-tester` fails
  on every submission since June) is written and tested in qemu, but after an outside research
  review it is not sent as one series: it goes out as separate contributions in a reviewed
  order. The first two are done — the Tested-by and the BlueZ fix in the tables above; the power-off
  fix is next, after a comparison with another author's patch for the same bug.
- **Desktop audio issues** seen while testing the fixed driver are recorded in [`docs/issues.md`](docs/issues.md) as leads with evidence: codec switches, reconnect policy, a GNOME codec row, since 2026-10-11 a speaker that goes silent on SBC-XQ (`U10`), and since 2026-10-13 a newly connected headset that does not get the sound (`U11`, WirePlumber's default-device policy; a suggestion is drafted, not posted). Upstream fixes are checked before anything new is written.

The dated detail, one row per issue and submission, is [`docs/STATUS.md`](docs/STATUS.md).

## Environment

```
Distribution : Ubuntu 24.04 LTS (noble)
Kernels      : 7.0.0-29, -30, -31, -34-generic (the twelve instances); 6.17.0-29/35/40, 7.0.0-28 (earlier phenotype);
               7.0.0-38-generic with the upstream entry (E3) since 2026-10-11
BlueZ        : 5.72 (the running patched daemon is a rebuild of 5.72-0ubuntu5.5; the package is 5.72-0ubuntu5.8 since 2026-10-14)
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
HISTORY.md            chronological development record, wrong turns included (37 phases, then dated chapters)
bin/                  watchdog, capture daemons, metrics collector
systemd/ etc/         unit files; modprobe + udev + journald configuration
tools/                diagnostics, incident capture, log sanitiser
  lib/                shared awk/sh programs (timestamps, matching, reports, the journal seam)
scripts/              the helpers behind the exhibits (ledgers, build matrix, mail checks, proofs)
tests/                run-tests — invariants, each anchored to a real shipped defect
devtools/             contributor tooling (check, scan, validate, coverage, ci, commit+verify)
reviews/              assessments of the repository itself; README.md there is the live action register
comms/  lessons/      messages between the maintainers; what the project cost to learn
patches/bluez/        the two applied BlueZ patches, their verification script and mail notes;
  shared-mgmt/        the applied shared/mgmt fix and its unit tests, as mailed
  send-2026-10-18/    the two cleanups sent 2026-10-18, as mailed, with their re-test
  cleanup/            the first draft (2026-10-07) of the a2dp cleanup, superseded
retest/mesh-tx-leak/  reproducer, kernel configs and 159 VM logs for the retest of another
                      author's kernel patch (patchwork 14831271); REPORT.md there has the findings
docs/                 issues.md (issue register) · missing-quirks-entry.md · install.md ·
                      tooling-index.md · the historical plans and drafts, each labelled
evidence/
  exhibits/           numbered, self-verifying evidence exhibits — README.md there is the index
  sessions/           one directory per reproduction session, sanitised
  trials/             numbered trials and results.tsv (the denominators)
  baseline/ diagnosis/  the failing boot before any mitigation; the device-table transcripts
archive/              (git-ignored, local) every raw HCI capture, compressed and verified
                      (scripts/bt-trace-archive.py); incident windows are cut from here
```

**Branches.** `main` is the record. `review/<UTC timestamp>` holds one assessment
(report first, then the reaction on `review/<timestamp>-fixes`), per the convention in
[`reviews/README.md`](reviews/README.md). Kernel findings are recorded on `main` as they
are found (since 2026-10-09); held work lands on `main` by cherry-pick, never by merge. CI (`.github/workflows/checks.yml`) runs the suite, the
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
  otherwise. Evidence published from 2026-10-11 on uses **pseudonymous device addresses**
  instead: the manufacturer prefix is real, the rest random, and the same device has the
  same pseudonym in every file. Each file says so; the mapping is kept privately. A raw HCI
  capture also carries pairing keys, so it is published only as cut, key-blanked windows,
  never whole.
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
