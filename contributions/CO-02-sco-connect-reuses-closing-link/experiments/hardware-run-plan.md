# CO-02 — the run on the laptop: plan, module and evidence checklist

> ⚠️ **NOT READY — do not follow the install steps below (2026-10-23).** They name
> `tmp/co02-hw/module/series/bluetooth.ko`, built without `abd93c85c8667` + `816fb1590a4c`; on
> Ubuntu's code that build leaks on Connect Twice (`log.md`, "the laptop's kernel"). The modules
> are being rebuilt with the two commits. Also, `module-updates.sh install` checks CRCs only
> against the stock modules under `kernel/`, not E3's `updates/btusb.ko`: the dependants check is
> `tmp/co02-hw/check-dependants.sh`. This plan is rewritten when the new modules are checked.

Prepared 2026-10-23. Nothing here has been done on the laptop. Every step on the laptop is the
operator's: installing the module, the cold boot, the headsets, and every switch. Only the
operator touches the laptop's Bluetooth. The reads after the run are passive: the capture, the
journal, and `module-updates.sh status`.

## Why
The series has run only in QEMU with BlueZ's emulator. The bug was found on this laptop
(QCA9377 `13d3:3503`, E3 btusb, Ubuntu 7.0.0-38, PipeWire 1.0.5) with real headsets (`EX-060`,
U7). The run checks what the series promises on real timing, and nothing more:
- **the bug case** (Lenovo thinkplus-GM2 pro earbuds, an mSBC → CVSD switch with the SCO link up):
  no false "connected" with no setup. PipeWire's `connect()` gets `ECONNABORTED` at once, or a
  new link is set up after the old one is gone;
- **the control** (MOMENTUM 4, the same switch): still gets its new link, as in `EX-060`;
- **no regression** in ordinary calls, A2DP, reconnects, and a day of normal use, with E3 still
  in place and no kernel warnings.

It does **not** check that the codec switch now succeeds on the earbuds. PipeWire 1.0.5 retries
the refused `connect()` at once, twice, still inside the teardown, so the new codec may still be
silent there. The cover letter says so. Success here means the kernel tells the truth and breaks
nothing.

## The laptop's combination, checked first in the emulator
The laptop's kernel has the kref change `e6720779ae61` and the CVE fix `8a5b0135d4a5`, but not
`816fb1590a4c`. No stable line has that combination, and patch 1's hold had never run against it.
The emulator runs (`tmp/co02-hw/run-ubuntu38.sh`) use a full v7.0 tree with Ubuntu's Bluetooth
sources from `linux-hwe-7.0 7.0.0-38.38~24.04.4` (`cache/co02-ubuntu38`, branches
`co02-ubuntu38/base`, `/series`, `/park`). The results are in `results-2026-10-23-hw-prep.md`.

## The module
- **Source:** Ubuntu's Bluetooth sources for `7.0.0-38.38~24.04.4` (`cache/ubuntu-7.0.0-38`, made
  by `scripts/prepare-ubuntu-ksrc.sh` from the `.dsc`-checked diff), plus the v5 series
  (`patch/v5/send/kernel/0001-0003`, applied with `patch -F0`; the hunks apply with an offset).
- **Build:** `tmp/co02-hw/build-laptop-module.sh`, which calls `scripts/build-bluetooth-module.sh`
  against `/lib/modules/7.0.0-38-generic/build`. No warnings.

| build | file | srcversion | vermagic |
|---|---|---|---|
| with the series | `tmp/co02-hw/module/series/bluetooth.ko` | `35932EA01952A16899A4A9B` | `7.0.0-38-generic SMP preempt mod_unload modversions` |
| control, unpatched | `tmp/co02-hw/module/base/bluetooth.ko` | `D006A01136080C36BA12190` | same |
| stock, loaded now | `kernel/net/bluetooth/bluetooth.ko.zst` | `973EDEC17806658263CB837` | — |

- The SHA-256 sums are in each directory's `SHA256SUMS`, and `modinfo` in `modinfo.txt`.
- **Dependants:** `tmp/co02-hw/check-dependants.sh` checked all 33 installed modules that use
  `bluetooth.ko`, including E3's `updates/btusb.ko`, `rfcomm`, `bnep` and `hidp`, against the series
  build's exported CRCs. None mismatched.
- **Signing:** E3's self-built `btusb.ko` already loads, so module signing is not enforced here.
- **The srcversion differs between stock and the control build** of the same source and headers
  (the `-38` headers package and our `include/net/bluetooth` are identical). The likely reason is
  the out-of-tree build, as the tooling index notes for E3's `btusb.ko`; this is not proven.
  Run 0 below rules the build out if wanted.

## Before the run (operator)
1. **Pick a window** when the laptop's Bluetooth may be lost for a while: the rollback below needs
   a cold boot.
2. **The open trial E3 #2:** a new `bluetooth.ko` changes its conditions. Either close it first
   (`scripts/trial-close-now.sh`, passive, it writes the row; `--reopen` opens the next), or
   leave it open and note the module change in its steps log. Closing it is cleaner.
3. **The capture:** check that it runs (`bt-mode status`; the files under
   `/var/log/bt-health/capture/`).

## Install (operator)
```
sudo /root/exp/qca9377-bt-hang/scripts/module-updates.sh install /root/exp/qca9377-bt-hang/tmp/co02-hw/module/series/bluetooth.ko
sudo /root/exp/qca9377-bt-hang/scripts/module-updates.sh status
```
`install` checks the CRCs against every dependant again, copies the module to `updates/` and runs
`depmod`. Then **a cold boot**: power off, wait, power on. Never unload, reload or rebind
`bluetooth` or `btusb` on the running system (`EX-046`).

After the boot, `module-updates.sh status` must show `loaded srcversion: 35932EA01952A16899A4A9B`,
and the boot log must still show `QCA: patch rome 0x302 build 0x3e8` (E3 is unchanged).

## The runs (operator, noting the local time of each switch)
Close GNOME Settings' Sound panel between runs: its meter keeps the SCO link up.

| # | headset | what to do | expected with the series |
|---|---|---|---|
| 0 (optional) | — | the same runs with the **control** module (`module/base/`) instead, before the series | as stock, `EX-060`: on the earbuds, no setup after the switch. Rules out the build itself |
| 1 | earbuds | connect; A2DP music for a minute | plays (sanity) |
| 2 | earbuds | Handsfree, mSBC, **SCO idle**; switch to CVSD (`pactl set-card-profile <card> <cvsd profile>`, or the Sound panel); then start a stream | a Setup Synchronous Connection about 30 ms after the headset's `OK`; sound (as at 02:27:32 in `EX-060`) |
| 3 | earbuds | Handsfree, mSBC, a stream playing (**SCO up**); switch to CVSD, three times, about 30 s apart | the old link is disconnected; **no false success**: PipeWire's `connect()` fails with `ECONNABORTED` (journal) instead of "connected" with no setup. Sound may still be missing (PipeWire's retry); stopping and restarting the stream after about 1 s should set up a new link |
| 4 | MOMENTUM 4 | as 3 | the new link is set up after each switch, as in `EX-060` (no regression) |
| 5 | each | an ordinary call or microphone use (e.g. a browser test call), hang up, start again | works as before |
| 6 | — | a day of normal use | no `BT-1` symptom (no `hci0: command … tx timeout`), no kernel warnings from `bluetooth`/`btusb` |

`pactl list cards` shows the card and profile names. On PipeWire 1.0.5 the Handsfree profiles are
typically `headset-head-unit-msbc` and `headset-head-unit-cvsd`; use the names it shows.

## Evidence (read after the run; passive reads only)
For each switch, the local time noted by the operator gives the window.
- **HCI:** `scripts/sco-switch-windows.sh <capture> '<start>' '<end>' …` (the `EX-060` command)
  gives, per switch, the Disconnect, `+BCS`/`AT+BCS=`/`OK`, the Disconnection Complete and any
  Setup Synchronous Connection, in milliseconds. `scripts/capture-window.sh <capture> '<start>'
  '<end>' 'RFCOMM|[+]BCS|Synchronous|Disconnect'` gives the raw lines.
- **SCO links:** `scripts/sco-ledger.sh 0` for the boot.
- **PipeWire:** `journalctl --user -u pipewire -u wireplumber -o short-iso-precise --since '<start>'`
  to look for the `connect()` error.
- **Kernel:** `journalctl -k -b -o short-iso-precise | grep -E 'Bluetooth|hci0|WARNING|BUG'`;
  `scripts/boot-bt-summary.sh` for the boot.
- **The module:** `scripts/module-updates.sh status`.
- **An exhibit:** the next free number with the extraction commands and their exact output, as
  for `EX-060` (`evidence/exhibits/`).

## Rollback (operator)
```
sudo /root/exp/qca9377-bt-hang/scripts/module-updates.sh remove
```
Then a cold boot. `status` must show the stock srcversion `973EDEC17806658263CB837` loaded again.
This works with Bluetooth down.

## What goes into the mails afterwards
One sentence in the cover letter's testing paragraph, for example: "Also run on a QCA9377 laptop
(Ubuntu 7.0.0-38 with the series) with two headsets: on the earbuds whose AT+BCS reply comes
before the old link is gone, connect() now fails with ECONNABORTED instead of succeeding without
a link; the other headset still gets its new link." Adjust it to what the run shows. Remove the
"not yet run on hardware" sentence.
