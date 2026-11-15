# Incident: shure-paired-in-handsfree-no-codec-row

**Collected:** 2026-11-16T00:34:23+01:00 (window: 2026-11-16 00:14), boot `a033d9d8`, `7.0.0-43`
stock. Registered as the second occurrence of `U21` (`docs/STATUS.md`, `docs/issues.md`), with
a note under `U4`.

**Addresses.** The Shure AONIC 50 appears as `AA:BB:CC:00:00:01`
(`AA_BB_CC_00_00_01` in PipeWire names). The outputs below were copied with that one substitution
and are otherwise verbatim.

## What was being done
The operator had forgotten the Shure AONIC 50 earlier and paired it again from GNOME Settings
at 00:15:43. It came up as Output and Input "Handsfree - Shure AONIC 50", and the Sound panel
showed no Configuration (codec/profile) row. The operator's screenshot (00:16:06) is kept local
and is not in the repository.

## What happened

### bluetoothd: A2DP was there (`bluetoothd.log`, this directory)
- HFP connected at 00:15:45.121.
- A2DP was configured (LDAC, `SelectConfiguration`/`SetConfiguration` on
  `/MediaEndpoint/A2DPSource/ldac`) and its stream was OPEN at 00:15:45.439.

### WirePlumber chose Handsfree from its stored default
```
$ journalctl --since "2026-11-16 00:14" --no-pager -o short-iso-precise _COMM=wireplumber _COMM=pipewire _COMM=pipewire-pulse
2026-11-16T00:15:45.406455+01:00 n wireplumber[2871]: initial profile off
2026-11-16T00:15:45.412439+01:00 n wireplumber[2871]: Found default profile headset-head-unit-msbc for bluez_card.AA_BB_CC_00_00_01
2026-11-16T00:15:45.412453+01:00 n wireplumber[2871]: Setting profile headset-head-unit-msbc on bluez_card.AA_BB_CC_00_00_01
2026-11-16T00:15:45.412804+01:00 n wireplumber[2871]: 0x599abbb2ad88: setting profile 3 codec:257 save:0
```
- These are 4 of the window's lines (248 KB in all).
- A search of the window for `Chrome|RecordStream|Stream/Input|input route|not switching|saved headset profile|Restoring profile|default profile`
  between 00:15:00 and 00:16:59 matched only the "Found default profile" line.
- So no application was recording, there was no auto-switch (`U14`), and no new
  "saved headset profile" was written.

### The stored state (read-only)
```
$ grep -rn "AA_BB_CC_00_00_01" /home/i/.local/state/wireplumber/   (run with the real address)
/home/i/.local/state/wireplumber/policy-bluetooth:2:saved-headset-profile:bluez_card.AA_BB_CC_00_00_01=headset-head-unit-msbc
/home/i/.local/state/wireplumber/default-profile:6:bluez_card.AA_BB_CC_00_00_01=headset-head-unit-msbc
```
(`default-routes` and `default-nodes` also hold the Shure's entries.)
```
$ ls -la --time-style=full-iso /home/i/.local/state/wireplumber/
-rw-rw-r-- 1 i i   233 2026-10-26 05:40:00.030041679 +0100 default-profile
-rw-rw-r-- 1 i i   720 2026-11-15 03:06:26.330025765 +0100 policy-bluetooth
```
- `journalctl --since "2026-10-26 05:38" --until "2026-10-26 05:41" _COMM=wireplumber --grep "setting profile|Setting profile|save:1|default profile|autoswitch|switch"` returned `-- No entries --`.
- When the Shure's entry was written is therefore not known. The file is rewritten as a whole on
  any device's change.

### The card offered choices (00:24)
```
$ scripts/user-pw-dump.sh tmp/incident-20261116-0015/pw-dump-0024.json
$ python3 -I scripts/pw-card-routes.py tmp/incident-20261116-0015/pw-dump-0024.json
device 71: Shure AONIC 50
  active profile: 261 headset-head-unit-msbc
  profile   0 off                                available=yes priority=0
  profile   3 headset-head-unit                  available=yes priority=1
  profile   5 a2dp-sink-sbc                      available=yes priority=18
  profile   6 a2dp-sink-sbc_xq                   available=yes priority=17
  profile   9 a2dp-sink-aptx                     available=yes priority=19
  profile  10 a2dp-sink-aptx_hd                  available=yes priority=20
  profile  11 a2dp-sink                          available=yes priority=21
  profile 260 headset-head-unit-cvsd             available=yes priority=2
  profile 261 headset-head-unit-msbc             available=yes priority=3
  active route: 2 headset-hf-input Input device=0 available=yes
  active route: 3 headset-hf-output Output device=1 available=yes
  route   1 headset-output         Output  available=yes profiles=[5, 6, 9, 10, 11] devices=[1] desc='Headset'
  route   2 headset-hf-input       Input   available=yes profiles=[3, 260, 261] devices=[0] desc='Handsfree'
  route   3 headset-hf-output      Output  available=yes profiles=[3, 260, 261] devices=[1] desc='Handsfree'
```
The PipeWire graph itself holds addresses and stays local.

### Policy view and who held the microphone (00:19–00:24)
```
$ python3 -I scripts/bt-audio-policy.py --user i --once
… bt-device[Shure AONIC 50] profile = headset-head-unit-msbc#261 save=False
… bt-device[Shure AONIC 50] profile-route = MISMATCH active #261 routes [3]
… capture[GNOME Settings] = Shure AONIC 50; monitor of Shure AONIC 50
$ scripts/user-audio-streams.sh
card Shure AONIC 50: active profile headset-head-unit-msbc
stream 72: Stream/Input/Audio  app='GNOME Settings'  name='Peak detect'  pid=5181  state=running  target=bluez_output.AA_BB_CC_00_00_01.1  linked to bluez_output.AA_BB_CC_00_00_01.1
stream 79: Stream/Input/Audio  app='GNOME Settings'  name='Peak detect'  pid=5181  state=running  target=bluez_input.AA_BB_CC_00_00_01.0  linked to bluez_input.AA_BB_CC_00_00_01.0
$ ps -o pid,lstart,args -p 5181
   5181 Sun Nov 15 09:47:43 2026 gnome-control-center bluetooth
```

### Controller
`MANIFEST.txt`: 0 command timeouts, 0 USB disconnects, no watchdog action. The controller was not
involved.

### Kept local, not committed
`kernel.log` (6.3 MB) and `timeline.txt` (5.4 MB) of this collection are almost all kernel
dynamic-debug lines, which play no part in a desktop audio-policy incident. They are in the
laptop's `tmp/incident-20261116-0015/`:
- sha256 `8b5f2e93431e62f6fd6e48f30d8328c3ea4921a45221a465e54c3ed1c1bddea5` `kernel.log`
- sha256 `a9036408c879227d9c7c34fce118a39c92396095dee907cddc49cda1fc9b33c6` `timeline.txt`

## What it means
Two separate defects, both seen before (`U21`, 2026-10-29):

- **(a) A forgotten headset is restored to its old profile.** WirePlumber keeps the profile last
  saved for a device, keyed by a card name built from its address. Forgetting the device in
  BlueZ does not clear it, so a freshly paired headset starts in Handsfree, which is not the
  profile WirePlumber would otherwise choose. On 10-29 an application was recording and could
  explain the Handsfree start; this time nothing was. This is now observed, not inferred.
  - Not yet known: who should clear the entry (BlueZ's removal signal, WirePlumber or GNOME's
    Forget), and whether WirePlumber 0.5 does.
- **(b) The Configuration row is missing** although the card offers five A2DP and three
  hands-free profiles. This rules out `U4`'s 11-13 candidate "no A2DP profile".
  - **Still open:** the active route naming the base profile (3 while 261 is active), or the
    panel missing the profile change at connect. The device was new to a Settings process that
    was already running, and the profile went off → `headset-head-unit-msbc` in 6 ms.
  - Next: read libgnome-volume-control's row logic against this state.
