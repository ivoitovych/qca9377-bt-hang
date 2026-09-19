# qca9377-bt-hang

**Your Bluetooth controller stops answering during hands-free audio, and only removing
power brings it back.** Qualcomm Atheros **QCA9377** (ROME), USB ID `13d3:3503`, on
Linux. An open investigation aimed at an upstream fix, run so that every claim can be
re-derived by a stranger from the command that produced it.

## Status — 2026-09-18, newest exhibit `EX-043`

> When this controller negotiates **transparent (mSBC / wideband) synchronous audio**,
> `btusb` falls back to **USB alternate setting 1** — a 9-byte isochronous endpoint — and
> sends each 27-byte SCO buffer as three 9-byte packets (`len 27 mtu 9` in the log is that
> split, not an overflow). **The first HCI command observed after the stream starts gets no
> response**; the controller then answers nothing, including USB control
> transfers, until power is removed. Reproduced **seven times across three kernels, two
> headsets, and both power configurations** (`EX-033`, `036`, `037`, `038`, `040`, `042`,
> `043`), with alternate setting 1 read directly from `sysfs` during five live wedges.

- **Established:** the sequence above; `0x0428 Setup Synchronous Connection` *is*
  answered; the stream ran 9.65 s in `EX-043` before the first command was issued, and that
  command got no response — whether the command wedged the controller or only found it
  wedged is not established; every recovery tried on an already-wedged controller failed
  (`hdev->reset` is NULL on the kernels run here — the ID entered btusb's quirks table
  upstream in `dc16388d45ec`, master 2026-08-07, not in v7.0 nor in the 6.6.y and 6.12.y
  stable heads as checked on 2026-09-19; `HCI_Reset` returns `-110`; a warm reboot does not
  clear it, a power-off does — `EX-027`/`028`/`039`; the one reset issued *before* any
  timeout did recover the controller, which then failed again 132 s later, `EX-004`).
- **Not established:** the mechanism — *how* traffic on that endpoint wedges the
  device. The fallback was introduced by **`517b693351a2`** (Trent Piepho, 2020-12-09,
  *"Always fallback to alt 1 for WBS"*, in v5.12 and not v5.11), whose own message assumes
  that adapters without alt 6 work on alt 1 (*"I have been unable to find any [adapters that
  support alt 6]"*). This part has alts 1–5 and no 6, so the fallback *applies* to it;
  whether it is *compatible* with it is the open question — a device using alt 1 does not
  falsify the author's observation. The clean control window is **v5.8–v5.11** — not "≤ v5.11": below v5.8
  alt 1 is reachable again by a different route. No kernel in that window has been run.
  Table and provenance in [`docs/missing-quirks-entry.md`](docs/missing-quirks-entry.md).
- **No kernel patch exists yet.** Two **BlueZ** patches do (below). The full current state,
  including what has been **retracted**, is [`BRIEF.md`](BRIEF.md) §1–§6; the section
  above is a dated copy of its §1 and is checked on every commit for naming the newest
  exhibit.

The earlier first-order finding — this ID matches no `btusb` quirks entry, so it gets
neither the QCA firmware setup nor a reset callback — is still true and now explains the
*absence of recovery*, not the wedge. It is kept whole, with the one-line quirks patch the
project no longer proposes, in [`docs/missing-quirks-entry.md`](docs/missing-quirks-entry.md).

## For maintainers

Two `bluetoothd` NULL dereferences, found because the record separates four failure
modes that look identical to a user (`EX-032`): [`patches/bluez/`](patches/bluez/).

| patch | subject | runtime evidence |
|---|---|---|
| `0001` | `adapter: Fix crash on short start discovery reply` | guard not yet fired; its premise (Command Status `0x00` answering Start Discovery) logged five times with clients present, and the 08-14 crash itself is reconstructed from the daemon log (`EX-041`) |
| `0002` | `a2dp: Fix crash on NULL stream in transport_cb` | **fired four times** in 19 days of ordinary use — four crashes prevented, not merely absent (`EX-041`) |

**Sent to `linux-bluetooth@vger.kernel.org` on 2026-09-19** as two independent mails
(Message-IDs in `patches/bluez/README.md`), after three independent reviews.
Both defects confirmed present in BlueZ master `c73fa2f9a`; both written to BlueZ's own
rules (no `Signed-off-by`, 50/72, `checkpatch` clean under BlueZ's `.checkpatch.conf`);
`git am` clean alone, together, in either order — re-run it with
[`patches/bluez/git-am-check.sh`](patches/bluez/git-am-check.sh). The crash sites were
resolved **from the stripped distro binary**, with the falsifier stated before a retained
core was read and then matched byte for byte:
[`reviews/2026-08-23T2340Z-ex032-crash-sites-resolved.md`](reviews/2026-08-23T2340Z-ex032-crash-sites-resolved.md).
Neither patch touches the controller fault.

**The controller fault, if you want to reproduce it:** put a transparent SCO link on
alternate setting 1 (any mSBC headset does it — `Looking for Alt no :6` then `:3` in the
`btusb` debug output), let it stream, then issue an HCI command — in both recorded cases
it was `Disconnect`; whether *any* command does it is untested. The command gets no
response and `HCI_CMD_TIMEOUT` follows (`EX-043`); whether the command wedged the
controller or found it already wedged is not established. Environment below. What is missing is the mechanism, and a kernel-side
report goes out only with a patch ready to follow it.

## The evidence

Three parallel streams, deliberately not merged:

| stream | question it answers | where it lives |
|---|---|---|
| **1. Evidence** | What actually happens, in terms a stranger can re-derive? | [`evidence/exhibits/`](evidence/exhibits/) — 43 numbered exhibits, each carrying its extraction command, verbatim output and exit status |
| **2. Workarounds** | Is there a cheap recipe a user can apply today? | [`docs/install.md`](docs/install.md) (a watchdog and a power-policy change — **experiments, and on this hardware questionable ones**), and the trial series in `evidence/trials/` |
| **3. The real fix** | What patch belongs upstream? | [`patches/bluez/`](patches/bluez/), [`docs/bug-report.md`](docs/bug-report.md), [`docs/fix-proposal.md`](docs/fix-proposal.md) |

The signature, per instance (`BRIEF.md` §2 carries the full table):

| exhibit | date | kernel | power config | `len 27 mtu 9` buffers (each sent as 3×9-byte packets) | first command after link-up | setup → fault |
|---|---|---|---|---|---|---|
| `EX-033` | 08-22 | `-29` | modified | 835 | 36 ms | 2.076 s |
| `EX-038` | 09-13 | `-31` | modified | 682 | 35 ms | 2.191 s |
| `EX-042` | 09-16 | `-31` | modified | 1595 | ~90 ms | 2.147 s |
| **`EX-043`** | **09-17** | `-31` | **original** | 910 | **9,650 ms** | **11.874 s** |
| *survival* | 09-01 | `-30` | modified | 8 | — | *lived* |

The interval is not a constant: it is *time to the first command* plus the 2 s command
timeout, which is why six fast teardowns looked like "2.15 s" until `EX-043`.

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
— the two patches). `tools/bt-crash` tells the last apart from the rest in one command;
`tools/bt-status` gives the verdict on the first.

**If your controller is different**, most of this transfers. `bt-diagnose`, `bt-state`,
`bt-boots`, `bt-crash` and `sanitize-logs.sh` work on any USB controller; every tool
takes `BT_VID`/`BT_PID`; `bt-incident` collects a hang that already happened into a
sanitised, publishable session; `bt-exhibit` captures a claim with its command and output
in one pass; the journal seam (`tools/lib/journal.sh`) lets every analysis run over a
fixture instead of a live machine. What is specific to this part: the alt-1 reading in
`bt-usbstate` and `bt-fault-window`, the `13d3:3503` defaults, and the exhibits.

**Why this class of bug goes unreported**, and why yours may not be in any tracker: it is
rare per user; the only recovery (a power-off) destroys the volatile evidence and, without
persistent logging set up in advance, the logs; default logging cannot name the command in
flight; and the instrumentation costs more than the bug seems to justify. Selection, not
rarity — `docs/issues.md` §"Why this class of bug goes unreported".

## Environment

```
Distribution : Ubuntu 24.04 LTS (noble)
Kernels      : 7.0.0-29, -30, -31-generic (the signature); 6.17.0-29/35/40, 7.0.0-28 (earlier phenotype)
BlueZ        : 5.72 (5.72-0ubuntu5.5; the patched daemon is a rebuild of that source)
Platform     : AMD Renoir/Cezanne laptop; controller on xhci_hcd, full-speed
BT device    : usb 13d3:3503 — HCI manufacturer 0x001D (Qualcomm), version 0x07 (4.2)
Companion    : ath10k_pci qca9377 hw1.1 (one combo chip)
Headsets     : Sennheiser MOMENTUM 4, Lenovo thinkplus GM2 pro (two vendors, one signature — EX-024)
```

Windows 11 on the same laptop shows no fault under deliberate repeated use. That is not
"Linux is broken": Linux drives this controller into a state that Windows does not, and
which side is at fault follows from the mechanism, not the other way round.

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

The current formulation of the fault as the issue register carries it (`docs/issues.md`,
where it is filed as `BT-1`, the project's own search handle):

<!-- BT1-CURRENT-BEGIN -->
> The controller sometimes enters a non-responsive HCI state during synchronous-audio link
> transitions, while remaining USB-enumerated. Later USB collapse has so far only been
> observed after a reset, rebind or driver reload; whether it belongs to the fault's
> untreated trajectory is **unresolved**.
<!-- BT1-CURRENT-END -->

## Repository map

<!-- One tree, one entry per path. An earlier version of this block was two
     generations merged: tests/ appeared twice and tools/lib/, exhibits/ and
     trials/ dangled below the closing entries (review 2026-08-15T1752Z §1.1). -->
```
BRIEF.md              the concentrated current state, under 500 lines, what is true / retracted / open, and the rules paid for
HISTORY.md            chronological development record, wrong turns included (36 phases)
bin/                  watchdog, capture daemons, metrics collector
systemd/ etc/         unit files; modprobe + udev + journald configuration
tools/                diagnostics, incident capture, log sanitiser
  lib/                shared awk/sh programs (timestamps, matching, reports, the journal seam)
tests/                run-tests — invariants, each anchored to a real shipped defect
devtools/             contributor tooling (check, scan, validate, coverage, ci, commit+verify)
reviews/              assessments of the repository itself; README.md there is the live action register
comms/  lessons/      messages between the maintainers; what the project cost to learn
patches/bluez/        the two BlueZ patches, their verification script and mail notes
docs/                 issues.md (issue register) · bug-report.md · fix-proposal.md · install.md ·
                      missing-quirks-entry.md · tooling-index.md · investigation-plan.md · …
evidence/
  exhibits/           numbered, self-verifying evidence exhibits (start here)
  sessions/           one directory per reproduction session, sanitised
  trials/             numbered trials and results.tsv (the denominators)
  baseline/ diagnosis/  the failing boot before any mitigation; the device-table transcripts
```

**Branches.** `main` is the record. `review/<UTC timestamp>` holds one assessment
(report first, then the reaction on `review/<timestamp>-fixes`), per the convention in
[`reviews/README.md`](reviews/README.md). `claude/unit-testing-intro-*` is the test-suite
maintainer's line. `evidence/*`, `verify/*` and `backup/*` are dated snapshots kept
because nothing here is deleted. CI (`.github/workflows/checks.yml`) runs the suite, the
coverage floors and the publish scan on every push; `devtools/ci` reads its verdict.

## Install, tools, tests

- **Install:** [`docs/install.md`](docs/install.md). On a machine you are *measuring*, use
  `sudo ./install.sh --tools-only`; `--apply` arms a watchdog whose USB reset has three
  controlled demonstrations of destroying this controller (`EX-023`, `EX-026`).
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

- a run on a kernel in the **v5.8–v5.11 window** with an mSBC headset — the untested
  prediction is that it logs `Device does not support ALT setting 6` and never takes the
  alternate-setting-1 path (below v5.8 alt 1 is reachable by another route, so "older" is
  not "cleaner");
- the same signature on **another controller** that matches no quirks entry (`bt-diagnose`,
  then `bt-fault-window` around the first timeout);
- a `btmon` capture of a transparent SCO link that **survived** a command on this part.

Messages between maintainers go in [`comms/`](comms/); every number carries the command
that produced it.

## License

GPL-2.0. See [LICENSE](LICENSE).
