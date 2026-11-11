# A. BT-16 history, every boot available (read-only; journal, journal exports; nothing sent to any device)

No Bluetooth device address and no serial number appears in this file. Marks: [measured] read from a
command's output at 2026-11-11; [quoted] taken from a project document; [inferred]; [not found].

## Sources and what could not be read

- Live journal, `journalctl --list-boots` (10 boots, 2026-10-22 11:32:06 to now). [measured]
- 71 journal exports `/root/bt-journal-archive/boot-*.export.zst`, read with
  `python3 -I scripts/journal-archive-grep.py "using rampatch|QCA: patch rome|usb 3-3: USB disconnect|Opcode 0x(2007|202f) failed|unexpected cc 0x(2007|202f)|Linux version" /root/bt-journal-archive/boot-*.export.zst`.
  Raw output: `A-archive-grep-raw.txt`; one row per export: `A-archive-boots.tsv` (made by `parse-grep-output.py`).
  Earliest start line: boot `d28ebac2`, 2026-08-12 08:17:38.
- Journal-file copies (`/root/bt-journal-archive/files/`, 358 files, first copy 2026-10-23): not scanned; they hold only
  boots from 2026-10-23, all of which are in the exports or the live journal. [inferred, not checked file by file]
- BLOCKED, two steps (see the blocking questions in the report): my own whole-export scanner
  (`boot-scan.py`) was refused by the hook `agent-isolation-guard` ("script ... uses halt, reboot, shutdown, which must
  not run on the host"), and the same tool with a pattern meant to find how each archived boot ended was refused
  ("the command uses reboot"). I did not reword or work around either. Consequence: **how each archived boot ended, and
  the off-time before it, is not available for the 71 exports**; it is given only for the ten live boots (from the
  journal, with a different, plainly worded query: logind's "The system will ..." lines and each boot's last entry).
  Boots with "(start not in export)": `7ab86388`, `c34cfa10`, `d479d374` (journald had discarded their first part
  before they were exported).

## Per-class table

"Rampatch" = both `using rampatch file` and `QCA: patch rome 0x302 build 0x3e8, firmware rome 0x302 build 0x111` logged.
"Startup disconnect" = `usb 3-3: USB disconnect` within 180 s of the boot's first kernel line.

| class | boots with a logged start | rampatch loaded | "already patched" (no rampatch line, setup finished) | startup disconnect | `0x2007`/`0x202f` failed |
|---|---|---|---|---|---|
| stock (kernels -28 to -34, before 2026-09-26 17:11) | 55 (+1 whose start was rotated out) | 0 (no QCA setup runs on stock) | not observable | **2 of 55** (`54b5b306` 08-14 13:04:53, `e9399c8c` 08-17 11:17:38) | 0 |
| E1 (setup only; 09-26 to 09-29, kernel -34) | 3 (`226965f1`, `855a927e`, `8709ee7c`) | 3 | 0 | 0 | 0 |
| E3 (exact entry; 10-01 on) | 11 with a logged start (`e8152eae`, `17cfdfc4`, `257d1599`, `738e228b`, `46cb5188`, `e672b454`, `be19fc39`, `7323fc85`, `045caff5`, `1bbf9aea`, live `e68d6d90`); 2 more boots without a start (`c34cfa10`, `d479d374`) | 10 | **1 (`7323fc85`, 2026-11-05)** | 1 (the same boot) | 2 (the same boot) |
| E1 + E3 together | 14 | 13 | 1 | 1 | 1 boot |

Rate: "already patched" 1 of 11 E3 boots with a logged start (1 of 14 boots on a patching kernel); 0 of 13 other. Counts are tiny;
a rate of one in eleven is not distinguishable from one in a hundred. Stock boots cannot show the event at all: on
stock `btusb` the QCA setup does not run for this ID, so no status byte is read and nothing is logged.
[measured: `A-archive-boots.tsv`; class boundaries from `BRIEF.md` ("E1 ... 3 boots", E3 from 10-01) and the
E3 trial dirs, [quoted]]

**Has "controller reports patch already loaded" occurred before 11-05? [not found].** No archived boot of E1/E3 with a
start shows it (13 of 13 loaded the rampatch). The boots whose start is missing (`c34cfa10`: 10-01 to 10-11;
`d479d374`: 10-19 21:53 to 10-23) cannot be judged.

**New finding, stock kernels:** the same *startup disconnect* (`usb 3-3` drops and re-enumerates within a second of boot,
between `ath10k_pci 0000:02:00.0: enabling device` and `ath10k_pci ... firmware ver`) occurred on two stock boots
(command: `python3 -I scripts/journal-archive-grep.py "usb 3-3|Bluetooth: hci0: [A-Za-z]|usbcore: registered new interface driver btusb|ath10k_pci 0000:02:00.0: (firmware ver|enabling)|Linux version" /root/bt-journal-archive/boot-54b5b306.export.zst /root/bt-journal-archive/boot-e9399c8c.export.zst`):

```
2026-08-14 13:04:52  usbcore: registered new interface driver btusb
2026-08-14 13:04:52  ath10k_pci 0000:02:00.0: enabling device (0000 -> 0002)
2026-08-14 13:04:53  usb 3-3: USB disconnect, device number 2
2026-08-14 13:04:53  ath10k_pci 0000:02:00.0: firmware ver WLAN.TF.2.1-00021-QCARMSWP-1 ...
2026-08-14 13:04:53  usb 3-3: new full-speed USB device number 4 using xhci_hcd
...
2026-08-17 11:17:38  usb 3-3: USB disconnect, device number 2
2026-08-17 11:17:38  Bluetooth: hci0: Opcode 0x202a failed: -19
```

The failing E3 boot has the same order (precise times, `journalctl -b -3 -k -o short-iso-precise`): btusb registered
19:33:05.734, `ath10k_pci enabling device` 19:33:05.794, `usb 3-3: USB disconnect` 19:33:05.925, ath10k `firmware ver`
19:33:06.017, `usb 3-3: new ... number 4` 19:33:06.299. So the disconnect is not specific to the patch state or to E3;
it is a start-up event of the shared module (2 of 55 stock, 1 of 11 E3). [measured] That ath10k's chip reset causes it is
[inferred] from the order alone.

## The ten live boots (journal), with how the previous boot ended

Class E3 throughout (`7.0.0-42` from 10-30; `-38` before). Gap = previous boot's last journal entry to this boot's first.

| boot | start | kernel | rampatch / patch rome | startup disconnect | failed 0x2007/0x202f | previous boot ended | off-time before |
|---|---|---|---|---|---|---|---|
| `d479d374` | start rotated (first entry 10-22 11:32:06; real start 10-19 21:53:18 [quoted]) | -38 | not found | not found | not found | `17cfdfc4`: abrupt, 10-19 21:52:54 [quoted STATUS] | 24 s [quoted] |
| `257d1599` | 2026-10-23 11:04:43 | -38 | yes | none | none | `d479d374`: logind "The system will power off now!" 11:03:26 | 1 m 14 s |
| `738e228b` | 2026-10-30 04:31:21 | -42 | yes | none | none | `257d1599`: logind "will reboot now!" 10-29 15:20:14 (and "will suspend now!" 10-27 15:50:13 earlier in that boot) | **13 h 11 m 02 s** (reboot requested, machine back next day) |
| `46cb5188` | 2026-10-30 19:22:29 | -42 | yes | none | none | `738e228b`: "will reboot now!" 10:54:22 | 8 h 27 m 44 s |
| `e672b454` | 2026-10-30 20:05:27 | -42 | yes | none | none | `46cb5188`: "will power off now!" 19:51:44 | **13 m 23 s** |
| `be19fc39` | 2026-10-31 21:23:02 | -42 | yes | none | none | `e672b454`: **abrupt** (last lines pipewire at 21:21:59, no logind message, no shutdown sequence) | 1 m 03 s |
| `7323fc85` | 2026-11-05 19:33:05 | -42 | **no, no** | **yes** (19:33:05.925) | **yes, both** | `be19fc39`: clean: "will power off now!" 11-04 13:53:31, journal stopped 13:55:03; no suspend in that boot (no `PM: suspend` kernel line) | **29 h 38 m 02 s** |
| `045caff5` | 2026-11-06 15:51:22 | -42 | yes | none | none | `7323fc85`: "will power off now!" 15:46:57, last entry 15:47:16 | 4 m 06 s |
| `1bbf9aea` | 2026-11-10 00:37:20 | -42 | yes (rampatch 00:37:20.709, NVM 00:37:21.083) | none | none | `045caff5`: "will power off now!" 11-09 17:30:27 (and "will suspend now!" 11-07 18:16:05 earlier) | 7 h 05 m 21 s |
| `e68d6d90` (now) | 2026-11-11 00:32:45 | -42 | yes | none | none | `1bbf9aea`: "will power off now!" 11-10 16:06:29 | 8 h 25 m 55 s |

[measured] each cell from `journalctl -b N -u systemd-logind --grep "The system will"`, `journalctl --list-boots`, and
`journalctl -b N -k --grep "..."`; `-b -5` last entries from `journalctl -b -5 -n 8`.

## Archived E1 and E3 boots (before 10-22)

| boot | start | kernel | rampatch | startup disconnect | how the previous boot ended / off-time |
|---|---|---|---|---|---|
| `226965f1` (E1) | 09-26 17:11:14 | -34 | yes | none | not available (blocked step) |
| `855a927e` (E1) | 09-27 21:30:56 | -34 | yes | none | not available |
| `8709ee7c` (E1) | 09-29 15:49:03 | -34 | yes | none | not available |
| `c34cfa10` (E3 #1) | 10-01 00:13 [quoted]; start not in export | -34 | not found | not found | not available |
| `e8152eae` (E3) | 10-11 16:26:06 | -38 | yes | none | previous `c34cfa10` ended at a shutdown 10-11 16:24:45 [quoted STATUS]: 1 m 21 s |
| `17cfdfc4` (E3) | 10-13 20:29:13 | -38 | yes | none | previous abrupt 10-13 20:26:26 [quoted STATUS]: 2 m 47 s |

## Is "already patched" tied to cold start, off-time, previous-boot state or suspend?

[inferred from the table above; ten data points]
- **Previous-boot end:** after a clean power-off the controller was freshly patched at 10-23 (74 s), 10-30 20:05 (13 m),
  11-06 (4 m), 11-10 (7 h), 11-11 (8 h); the failing boot also followed a clean power-off. After reboot requests (13 h,
  8.5 h) and abrupt stops (1 m, 2 m 47 s, 24 s) it was patched fresh. So the type of the previous end does not separate.
- **Off-time:** every fresh-patch boot had an off-time from 24 s to 13 h 11 m; the failing boot's 29 h 38 m is the longest by
  a factor of 2.2. That is the only variable that separates, with one failure, so it is a candidate and not a finding.
  It also argues against a simple "power is kept in S5": 4 m and 13 m of off-time did not keep the patch.
- **Suspend:** the previous boot of the failing boot had none. Two boots with a suspend (`257d1599`, `045caff5`) were
  followed by freshly patched boots. Not tied (n = 2).
- **Cold start:** all rows are cold starts of the machine (power-off or reboot request); a warm start that keeps the
  USB controller powered cannot be told apart from the journal. [not found]
- **Same software around the failure:** since 10-30 the laptop ran `7.0.0-42` with one E3 module (srcversion in STATUS
  [quoted]); seven boots on it patched fresh (`738e228b` to `be19fc39`, `045caff5`, `1bbf9aea`, `e68d6d90`) and one did not,
  so kernel, module and firmware files did not change across the failure.
