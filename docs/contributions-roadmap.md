# Contribution roadmap (as of 2026-09-26)

*Written on the private branch `plan/contributions` on 2026-09-26 and ported to `main` on
2026-10-09 unchanged in substance; the current state of every item is `docs/STATUS.md`.*

One row per defect this project has found or met: the upstream project, how the defect is
known, whether current upstream already fixes it, and what the contribution would be.
Nothing goes to a list without the operator's word.

Evidence tags as in `docs/issues.md`: **[log]** measured (log, capture, API, sysfs),
**[operator]** the operator's account, **[inference]** reasoning still to be tested.

Started 2026-09-26. Installed: kernel `7.0.0-34-generic` (Ubuntu HWE), BlueZ 5.72,
PipeWire 1.0.5, WirePlumber 0.4.17, GNOME Settings 46.7.

## Summary

| ID | Defect | Project | Known by | Fixed upstream? | Contribution | Next step |
|---|---|---|---|---|---|---|
| BT-1 | Controller wedges on the first command after a wideband SCO stream on alt 1 | Linux (btusb) | [log] 12/12 deaths stock; 0 timeouts in 33 hang-ups on E1 | **Yes, mainline only**: `dc16388d45ec`, v7.3-rc1; in no stable line | Stable backport request | **E3 = the exact upstream entry**, then the request (§1) |
| BT-2 | LE `unexpected event for opcode 0x2005`, 16.0 s cadence | Linux (btusb) | [log] every stock boot examined; 0 on the E1 boot | **Same commit**: its message names exactly these errors | Part of the BT-1 request | Confirm 0 on E3 |
| BT-3 | `13d3:3503` missing from the btusb table | Linux (btusb) | [log] source + binary | Yes, `dc16388d45ec` | Same request | none |
| MGMT | Flushed pending commands answered `0x00` instead of NOT_POWERED/INVALID_INDEX | Linux (mgmt) | [log] EX-044 | No | **Patch sent 2026-09-24**; CI 13/14 (the bot's standing failure) | Watch; ping ~2026-10-01 if silent |
| BT-4 | btmon aborts during capture (`hciconfig hci0 name` reproduces) | BlueZ | [log] EX-011; one abort in the 09-26 survey run too | *pending research* | *pending* | *pending* |
| BT-7 | bluetoothd NULL dereferences (adapter, a2dp) | BlueZ | [log] EX-041 | **Yes**: `a734b0605`, `0bed9886c` (ours, applied 2026-09-21) | Done | Watch for the release tag |
| BZ-free | bluetoothd bad `free()` under `g_main_loop_run`, 09-08, patched binary | BlueZ | [log] one core | unknown | none yet: one occurrence, no mechanism | Keep the core; wait for a second |
| U1 | Plain "Headset Head Unit (HSP/HFP)" entry gives no sound / does not stick | PipeWire | [log] + [operator] | *pending research* | *pending* | *pending* |
| U2 | Headset microphone volume moves with no user action (0.00 → 0.27 → 0.08) | PipeWire / BlueZ HFP | [log] values; cause [inference] | *pending research* | *pending* | `AT+VGM` in the capture |
| U3 | Handsfree headset's microphone does not become the default input | WirePlumber | [log] configured default wins over priority 2010 > 2009 | *pending research* | Report (operator's position) | *pending* |
| U4 | Codec ("Configuration") row disappears in GNOME Settings | GNOME Settings | [operator] + screenshot; [log] data present | *pending research* | *pending* | `bt-mark` at the next disappearance |
| U5 | Handsfree picks the last-used codec per device | WirePlumber | [log] state files | n/a: **withdrawn** as a defect by the operator | none | Open only: a device with no saved profile |
| U6 | Input level meter stays on the old stream (monitor of the headset) | GNOME Settings | [log] capture stream on the monitor node | *pending research* | *pending* | *pending* |
| alt-1 | `517b693351a2` falls back to alt 1 for WBS on a part without alt 6 | Linux (btusb) | [log] on ROM firmware only | n/a | **Probably none**: with firmware loaded alt 1 carried 15,273+ buffers cleanly (EX-056) | Decide after E3 |

## 1. BT-1 / BT-2 / BT-3: the stable backport of `dc16388d45ec`

**What upstream has.** `dc16388d45ec` "Bluetooth: btusb: Add IMC Networks QCA9377 to quirks
table" (authored 2026-06-29, committed 2026-08-07) adds
`{ USB_DEVICE(0x13d3, 0x3503), .driver_info = BTUSB_QCA_ROME | BTUSB_WIDEBAND_SPEECH }`.
Stated reason: BLE scanning fails with `unexpected event opcode 0x2005`, which is our BT-2.
No `Cc: stable`, no `Fixes:`. First tag: v7.3-rc1.

**Where it is not** [log] (`scripts/backport-check.sh dc16388d45ec`, 2026-09-26):

| stable line | state |
|---|---|
| 7.2.y, 7.1.y, 7.0.y | absent; applies cleanly |
| 6.12.y, 6.6.y, 6.1.y | absent; applies with fuzz 1 |

So every distribution kernel with this chip runs it on bare ROM firmware (ROM `0x302`,
build `0x111`) unless its vendor carries the entry.

**What has been tested, and the gap.** E1 (`diag/btusb-e1`) is **not** the upstream entry:
- E1 omits `BTUSB_WIDEBAND_SPEECH`, to keep wideband behaving as it did in the failures;
- E1 omits the reset-on-timeout callback (`btusb_qca_reset`), so a failure and its
  treatment never land in the same trial.

E1 shows the firmware setup is what matters [log]: rampatch `0x3e8` + NVM loaded, 202
commands advertised (stock 197), 34 SCO links, 33 hang-ups answered, 0 timeouts (EX-055,
EX-056, `scripts/sco-ledger.sh 0`); 32 rfkill power cycles in 40 s at 23:06, every one set
up cleanly with the firmware still resident. But a backport request names the upstream
commit, and it must have run on this machine as written.

**E3 (next kernel step).** Build `btusb.ko` for `7.0.0-34` with exactly `dc16388d45ec`
(`scripts/build-btusb-module.sh --ksrc cache/ubuntu-7.0.0-34 <patch>`), install to
`updates/`, cold boot. Pass: `/sys/module/btusb/version` is `0.8`, firmware loaded, same
wideband hard test, `sco-ledger` 0 timeouts, 0 `0x2005` errors. The reset callback is present
but only fires on a timeout, so a clean E3 never exercises it; say so in the request.
One boot at the operator's convenience; no long window.

**The request** (stable-kernel-rules option 2, to `stable@vger.kernel.org`, Cc
`linux-bluetooth`): the commit id, the lines (7.0.y and older lines it applies to), and why:
controller wedges on wideband SCO without the firmware, measured before/after on 7.0.
Tested only on 7.0; the 6.x lines apply with fuzz and are untested at runtime.

**Open question for the request:** should it also ask for the lines below 7.0? Upstream
stable takes "applies and fixes a real bug"; a note that only 7.0 was run is enough.

## 2. MGMT: flushed commands answered as success

Held branch `kernel/mgmt-flush-status` (private). Sent 2026-09-24 19:11 after four
external reviews; the list's CI passed 13 of 14 (its standing `mesh-tester` failure).
No action until about 2026-10-01; then a polite ping on the thread if there is no reply.

## 3. BlueZ

*BT-4 (btmon): pending the research note `tmp/roadmap-research/bluez-btmon.md`.*

BT-7: both patches applied to master 2026-09-21; nothing owed.

BZ-free: one crash, no mechanism. Not a contribution until a second instance or a
mechanism.

## 4. PipeWire and WirePlumber (U1, U2, U3, U5)

*Pending the research note `tmp/roadmap-research/pipewire-wireplumber.md`.*

## 5. GNOME Settings (U4, U6)

*Pending the research note `tmp/roadmap-research/gnome-settings.md`.*

## 6. Order of work

1. **E3**, the exact upstream entry, one boot; then the stable request (highest reach: every
   distribution kernel with this chip).
2. MGMT: wait, ping around 2026-10-01.
3. Userspace items whose upstream check comes back "still present": confirm the [operator]
   parts with logs first, then one report or patch at a time.
