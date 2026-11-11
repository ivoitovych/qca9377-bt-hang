# Headset session checklist

Prepared 2026-11-11 for one short supervised session with the laptop and four headsets
(Sennheiser MOMENTUM 4, Shure AONIC 50, the Lenovo earbuds, the Tronsmart T8 speaker).
No test in this file has been run on a headset and nothing has been installed on the laptop;
the only things done on the laptop were read-only reads (package versions, process and file
hashes, journal lines). Every install and rollback below was rehearsed in throw-away containers
(Ubuntu 24.04, no devices); where a rehearsal could not show something, the text says so.

How claims are marked: **[measured]** = produced by a command whose log is kept (file named),
**[quoted]** = copied from a record or source file (file named), **[inferred]** = reasoned,
not run, **[not found]** = looked for and not there.

---

## 0. Read this first

**Who runs what.** You run every step. Commands starting with `sudo` need the root
terminal; the others run in a normal terminal of the desktop user in the graphical session
(they need that session's audio and `systemctl --user`).

**Total time.** About 2 hours with everything (116 minutes of steps plus a few minutes for
switching headsets). The core, if time is short, is about 1 hour (section 7 ranks every item).

**Four things the rehearsals changed in the earlier plans. Read them before the day.**

1. **The CO-19 plan "install the two rebuilt PipeWire packages" would have removed the
   desktop's audio.** With the laptop's package list, apt wants to remove ten packages
   (pipewire, wireplumber, pipewire-pulse, pipewire-alsa and others) because their versions
   are pinned to the old library package. **[measured]** `logs/rehearse-pwset/rehearsal.txt`
   (lines "simulate: ONLY the two packages"). The session therefore does not install PipeWire
   packages. It loads the rebuilt Bluetooth plugin into WirePlumber only, from a private
   folder, with one systemd user drop-in (section 4, block 5). The rebuilt plugin file is
   byte-identical to the one in the reviewed package **[measured]** (same SHA-256 from a second
   build, `logs/build-pipewire-all/`). A complete, consistent package set (11 packages) was also
   built and rehearsed (installs with 0 removals, rolls back byte-identically); it is kept for
   the later, permanent route and is not used on the day.
2. **Installing the new bluez package does not change which bluetoothd runs.** The running
   daemon is `/usr/local/libexec/bluetooth/bluetoothd`, started through
   `/etc/systemd/system/bluetooth.service.d/20-patched-bluetoothd.conf`; the package installs
   its daemon at `/usr/libexec/bluetooth/bluetoothd`. With the drop-in still in place, the
   install restarts the unit and the old local daemon starts again. **[measured]**
   `logs/rehearse-bluez/rehearsal.txt`, "ORDER B": effective ExecStart stays
   `/usr/local/libexec/bluetooth/bluetoothd -d` after the install. So the drop-in file is
   removed first, and the install's own restart then starts the new daemon: one restart in
   total ("ORDER A", effective ExecStart `/usr/libexec/bluetooth/bluetoothd -d`).
3. **Every bluez package install or downgrade restarts bluetooth.service, and a restart
   powers the adapter off and on.** The package's maintainer script runs
   `systemctl restart bluetooth.service` **[measured]** (stub log in the rehearsal). On
   SIGTERM the daemon calls `adapter_shutdown()`, which sends MGMT Set Powered 0 to every
   powered adapter **[quoted]** `src/main.c:1232-1241`, `src/adapter.c:10881-10905` (5.72-0ubuntu5.8
   source); the new daemon powers it on again because `AutoEnable=true` is set in
   `/etc/bluetooth/main.conf` line 322 **[quoted]** (power-on path `src/adapter.c:7865`). This is an adapter power cycle through the
   management interface. It is not a module reload and not a USB reset, and the kit has no
   step that does either. It is the one unavoidable Bluetooth action of the session, it
   happens once for the install and once more for a rollback, and it happens only with no
   headset in Handsfree (no SCO link): every headset is on A2DP or switched off first.
4. **`apt remove` or `apt purge` of bluez deletes the pairings.** The package's pre-removal
   script runs `rm -rf /var/lib/bluetooth` **[quoted]** `bluez.prerm` line 11 (checked in the
   rehearsal log). Never remove the package. All rollbacks here are downgrades or a drop-in
   restore, which do not run that code (**[measured]** rollback of both orders: all files under
   /etc, /usr and the package database identical to before).

**Hard stops.** If anything looks wrong with Bluetooth itself (no adapter, "Controllers: 0",
no headset can connect after the restart): stop the tests, do the rollback in section 5, and
use your own recovery. Nothing here reloads modules, resets the USB device or uses
bluetoothctl/btmgmt.

---

## 1. What is in the kit

Everything is under `/root/exp/agent-work/laptop-headset-session-20261111/kit`. The desktop
user cannot read `/root`, so copy it once (root terminal):

```
sudo cp -a /root/exp/agent-work/laptop-headset-session-20261111/kit /home/i/headset-kit
sudo chown -R i:i /home/i/headset-kit
```

| file | what it is | who runs it |
|---|---|---|
| `artifacts/bluez-5.72-0ubuntu5.9~co03.1/` | the new bluez package (CO-03) + SHA256SUMS | root |
| `artifacts/bluez-5.72-0ubuntu5.8-archive/` | the archive's own bluez 5.72-0ubuntu5.8 (what the laptop has now), for a rollback without network. Its file list and checksums equal the installed package's `/var/lib/dpkg/info/bluez.md5sums` **[measured]** (no diff) | root |
| `artifacts/spa-bluez5-1.0.5-1ubuntu3.4/` | the 7 rebuilt files of the Bluetooth SPA plugin (CO-19) + SHA256SUMS | via `wp-override.py` |
| `bin/wp-override.py` | installs and removes the user-level overrides (CO-19 plugin, CO-32, CO-33, CO-29, CO-15); writes only under `~/.config` and `~/.local/share/kit-session`; refuses to run as root; remove refuses if you edited the file | desktop user |
| `bin/session-state.py` | read-only snapshot: package versions, which bluetoothd runs (path and SHA-256), the drop-ins, WirePlumber's environment and mapped plugin, kit overrides | root |
| `bin/audio-ids.py` | read-only: Bluetooth cards, profile numbers, "codec-less Handsfree line present: YES/no", sink and source ids | desktop user |
| `bin/u12-trigger.sh` | the CO-03 trigger (a short playback and a recorder named like Chrome's dictation, opened `<delay>` ms later) | desktop user |
| `bin/mic-peak.py` | read-only: level per second of a WAV (is the microphone silent?) | desktop user |
| `bin/after-session.py` | read-only: turns your marks into a report (section 6) | root |
| `bin/device-ids-from-journal.py` | read-only: the exact Bluetooth name (and ids, if any) PipeWire matched on, for a quirk entry | desktop user |

Rehearsal evidence is under `/root/exp/agent-work/laptop-headset-session-20261111/logs/`
(index in section 9; checksums in `SHA256SUMS`).

---

## 2. The order at a glance

Grouped by headset, and ordered so that each change comes after every test it could confound.
The reasoning is in section 3.

| block | headset | what changes on the laptop | tests | minutes |
|---|---|---|---|---|
| 0 | none | nothing (snapshot, checks, backups) | prep | 10 |
| 1 | Tronsmart T8 | nothing | CO-08 (U10) A-B-A-B | 11 |
| 2 | MOMENTUM 4 | **bluez package + drop-in removed, one bluetooth.service restart** | CO-03 (U12) trigger and regression; then the stock-audio baselines U15, CO-17 (U4), U2, U1 | 28 |
| 3 | Lenovo earbuds | nothing | CO-18 (U8) test sound | 5 |
| 4 | Shure AONIC 50 | nothing | baselines: U21, U19, U20 | 10 |
| 5 | (Shure stays on) | **WirePlumber only: rebuilt plugin, CO-32 script, CO-33 table; one `restart wireplumber`** | prep for 6 and 7 | 6 |
| 6 | Shure AONIC 50 | (as 5) | CO-19 (U1, U21), CO-32 + CO-07 (U19, U6), CO-33 (U20) | 12 |
| 7 | MOMENTUM 4 | (as 5) | CO-33 (U15), CO-19 codec lines and saved-profile restore | 13 |
| 8 | MOMENTUM 4 | **CO-29 override; `restart wireplumber`** | CO-29 (U14) | 8 |
| 9 | any two | **CO-15 drop-in; `restart pipewire-pulse`** (optional) | CO-15 (U11) | 8 |
| 10 | none | removals as you decide | final snapshot, report | 5 |

Marks: type one `logger` line per observation. Format, always:

```
logger -t bt-mark -p user.notice "<KEY> <what you saw>"
```

`<KEY>` is the first word (U10, U12, U15, U4, U2, U1, U21, U19, U20, CO07, CO19, CO29, CO32,
CO33, CO15, U8, STEP, SESSION). It selects which journal lines section 6 shows for that mark.
This is the same tag as the project's `bt-mark` tool, but `logger` sends nothing to the
controller (the installed `bt-mark` sends an HCI Read Local Name; the CO-08 note says to avoid it).

---

## 3. Why this order (what could confound what)

- **CO-08 first (stock everything).** Its evidence is from 2026-10-11 on stock software;
  repeating it on stock software keeps the comparison honest. It touches only A2DP.
- **The bluez change before any audio-session change.** It affects A2DP transport handling
  (Release during Acquire) and nothing in the audio session's UI behaviour, so the baselines
  for CO-32/CO-33/CO-19 are taken afterwards: they then differ from their "after" runs in one
  variable only (the WirePlumber side). If the new daemon misbehaves, it shows in block 2,
  before any other test depends on it, and you roll it back there.
- **U12 needs WirePlumber's automatic Handsfree switch** (that is what releases the A2DP
  transport). So it runs before CO-29 (block 8) removes that switch.
- **Baselines before the WirePlumber change, "after" runs on the same headset in the same
  sitting.** The Shure's meter and slider results must be compared with the Shure's own
  baseline from the same hour, not with the 2026-10-24 record.
- **One WirePlumber restart for three changes (plugin, meter script, microphone table).**
  They are independent of each other (different files, different symptoms). If WirePlumber
  misbehaves after the restart, section 5 removes them one at a time.
- **CO-29 after everything that needs the switch** (U12 in block 2, U15 in block 7).
- **CO-15 last and optional**: it changes which output becomes the default and would confuse
  any test that says "the output is the headset".
- The Lenovo earbuds and the Shure sit where no software change separates a baseline from a
  later run; the earbuds' mSBC test (CO-18) is a kernel/earbud question and is unaffected by
  the audio-session changes.

---

## 4. The steps

### Block 0 - Preparation (10 minutes, no headset)

1. Close calls and recordings. Keep one browser tab ready that can play music (block 6 uses it).
2. Copy the kit (section 1).
3. Start the session record:
   ```
   logger -t bt-mark -p user.notice "SESSION start"
   ```
4. Snapshot (root terminal):
   ```
   sudo python3 -I /home/i/headset-kit/bin/session-state.py > /home/i/headset-kit/state-0-start.txt
   ```
   Expect (written from the laptop's state of 2026-11-11 00:3x, **[measured]** by running the
   same script): `bluetoothd ... exe /usr/local/libexec/bluetooth/bluetoothd`, SHA-256
   `0ec729572586e952cff52665dca9c2e0e4b43e257a177196d51e3098cc87501f`; packages bluez
   5.72-0ubuntu5.8, pipewire family 1.0.5-1ubuntu3.3, wireplumber 0.4.17-1ubuntu4.1,
   gnome-control-center 1:46.7-0ubuntu0.24.04.6; two drop-ins (10-debug.conf, 20-patched-bluetoothd.conf);
   WirePlumber's environment already holds the debug list and pipewire-pulse `PIPEWIRE_DEBUG=mod.protocol-pulse*:3`
   (so the journal already has everything the tests read; `bt-ui-capture` is not needed, see section 8).
   If any of these differ, stop and read the difference before going on.
5. Check the package files (root terminal, three lines):
   ```
   cd /home/i/headset-kit/artifacts/bluez-5.72-0ubuntu5.9~co03.1 && sha256sum -c SHA256SUMS
   cd /home/i/headset-kit/artifacts/bluez-5.72-0ubuntu5.8-archive && sha256sum -c SHA256SUMS
   cd /home/i/headset-kit/artifacts/spa-bluez5-1.0.5-1ubuntu3.4 && sha256sum -c SHA256SUMS
   ```
   Every line must say OK. For the record, the SHA-256 values are in section 9.
6. Keep the drop-in (root terminal). Both lines must print the same hash:
   ```
   sudo cp -p /etc/systemd/system/bluetooth.service.d/20-patched-bluetoothd.conf /root/20-patched-bluetoothd.conf.saved-20261111
   sudo sha256sum /etc/systemd/system/bluetooth.service.d/20-patched-bluetoothd.conf /root/20-patched-bluetoothd.conf.saved-20261111
   ```
   (The local daemon file `/usr/local/libexec/bluetooth/bluetoothd` is never touched.)
7. Simulate the install (root terminal):
   ```
   sudo apt-get -s install /home/i/headset-kit/artifacts/bluez-5.72-0ubuntu5.9~co03.1/bluez_5.72-0ubuntu5.9~co03.1_amd64.deb
   ```
   Expect exactly "1 upgraded, 0 newly installed, 0 to remove" and `Inst bluez [5.72-0ubuntu5.8] (5.72-0ubuntu5.9~co03.1 ...)`.
   **[measured]** the same line in the rehearsal. If apt lists anything to remove, stop.
8. Check both recorders are writing (the files must be modified within the last minute):
   `ls -lt /var/log/bt-health/capture` and `ls -lt /var/log/bt-health/trace`.
   Both were present on 2026-11-11 00:3x (`hci-20261111-003249.btsnoop`, `bt-20261111-003258.btsnoop`) **[measured]**.
   They are separate recorder processes; whether they survive a bluetoothd restart is
   **[inferred]** yes, check again after block 2.
9. **Controller start-up check (BT-16 watch, once per boot).** In a root terminal:
   `sudo journalctl -k -b 0 -g "QCA: patch"`. It must show `QCA: patch rome 0x302 build 0x3e8`
   (it did for the boot that began 2026-11-11 00:32:45, **[measured]**, with no Bluetooth warning besides the
   known "HCI Enhanced Setup Synchronous Connection command is advertised, but not supported"). If the line is
   missing, or `Controllers: 0` shows in the bluetooth journal, do not start the session: BRIEF section 0 (hand-off, BT-16)
   says to treat that boot as unusable for Bluetooth.
10. **A trial result you should know about.** The journal holds the mark
   `TRIAL E3 #5 RESULT: failed | usb=3-3 ctrl=auto hci=hci0 responds=no connected=0` at 2026-11-10 16:06:48
   **[measured]** (`after-session.py --list-marks --since "2026-11-07 00:00" --until "2026-11-11 02:00"`). The laptop
   restarted at 2026-11-11 00:32 and the controller is healthy now (item 9). The 11-10 entry was not investigated here
   (BRIEF 11-07 says earlier "HANG" rows of this kind came from the installed closer probing after shutdown). The
   bluetoothd restart in block 2 will also appear in whatever trial is open at that time.

### Block 1 - Tronsmart T8, CO-08 / U10 (11 minutes)

**Precondition.** Only the T8 is connected. Settings > Sound > Output = the T8. Nothing else
plays (pause or close browser tabs: on 10-11 the browser's playback reached the link as encoded
silence). Do not touch the volume slider or the T8's own volume for the whole block.

**Steps.**
1. Mark: `logger -t bt-mark -p user.notice "U10 start, slider NN percent, T8 volume untouched"` (write the slider value).
2. Run once, in a normal terminal, to get the T8's exact name for a later entry:
   `python3 -I /home/i/headset-kit/bin/device-ids-from-journal.py --since "10 minutes ago"`
   (a short range is fast; the quirk matcher is keyed on this name. For the three other headsets
   PipeWire was given **no** vendor/product ids, only the name **[measured]**
   `logs/selftest-device-ids.txt`; so a Modalias-based entry may be impossible for the T8 too.)
3. Four runs in this order. For each: set Settings > Sound > Output > **Configuration** to the line
   that says the codec, wait 3 s, play the sounds, type the mark.

   | run | Configuration line | sounds | mark text |
   |---|---|---|---|
   | 1 | codec SBC | Test: Front Left, then Front Right; then in a terminal `pw-play /usr/share/sounds/alsa/Front_Center.wav` | `U10 SBC run1: left yes/no, right yes/no, both yes/no` |
   | 2 | codec SBC-XQ | same | `U10 XQ run1: left ..., right ..., both ...` |
   | 3 | codec SBC | same | `U10 SBC run2: ...` |
   | 4 | codec SBC-XQ | same | `U10 XQ run2: ...` |

   Answer "partial" (quiet, distorted, one side) when that is what you hear; write it.
4. Leave it on SBC and mark: `U10 end`.

**Expect / reading** (from the CO-08 note, `policy/notes/CO-08.md` section 4):
SBC-XQ silent on all sounds in both runs, SBC audible in both: the entry
`no-features = [ sbc-xq ]` for the T8's name is justified. SBC-XQ one-sided: same entry. SBC-XQ
audible: U10 is withdrawn. Mixed: repeat once; still mixed: drop.

**Failure** (the test is void, not a result): the SBC lines could not be selected, the speaker
dropped mid-run, or any other sound source was playing.

**Read afterwards (read-only).** Section 6 gives the journal side. The decisive per-channel
reading needs the capture, as in the note:
`sudo python3 -I /root/exp/qca9377-bt-hang/contributions/research-2026-11-01/policy/scripts/sbc-channel-levels.py --from "YYYY-MM-DD HH:MM:SS" --to "YYYY-MM-DD HH:MM:SS" /var/log/bt-health/capture/<the newest hci-*.btsnoop>`
and, for the Set Configuration and AVRCP volume at each switch,
`sudo /root/exp/qca9377-bt-hang/scripts/capture-window.sh <same file> "<from>" "<to>" "Volume|AVRCP|AVCTP|Set Configuration|Start|Suspend|Close"`
(the times are the first and last U10 marks, from `after-session.py --list-marks`).
Switch the T8 off when done.

### Block 2 - MOMENTUM 4: bluez package (CO-03) and the stock-audio baselines (28 minutes)

**2A. Optional baseline of the failure on the old daemon (4 minutes; skip if short of time).**
Without it, a pass in 2D is still valid if the journal shows the trigger landed (see 2D); with
it you also see the failure on today's hardware.
1. MOMENTUM on, connected, Settings: Configuration = an A2DP line. Play nothing for 10 s.
2. `sh /home/i/headset-kit/bin/u12-trigger.sh 40` (it writes its own start/end marks).
3. Look: did the music path survive? Run `python3 -I /home/i/headset-kit/bin/audio-ids.py` and
   read the card's "active profile". If A2DP is gone (the card is in Handsfree or "off" and
   does not return to A2DP within 5 s), that is the failure; stop here, do not repeat. If it
   survived, wait 10 s idle and try `... 0`, then `... 90`.
4. Mark: `U12 old daemon: delay 40 ms: A2DP lost yes/no`.

**2B. Install the new bluez (5 minutes).**
Precondition: every headset is switched off or on A2DP (no Handsfree call, no SCO link); the
T8 is off. Root terminal, in this order:
```
sudo rm /etc/systemd/system/bluetooth.service.d/20-patched-bluetoothd.conf
sudo systemctl daemon-reload
sudo apt-get install -o Dpkg::Options::=--force-confold /home/i/headset-kit/artifacts/bluez-5.72-0ubuntu5.9~co03.1/bluez_5.72-0ubuntu5.9~co03.1_amd64.deb
```
- The first two lines change nothing that is running: `daemon-reload` only re-reads unit files and does not restart
  the running unit (systemd's documented behaviour, **[inferred]**, not run here; the container computed the
  effective `ExecStart` after the removal as `/usr/libexec/bluetooth/bluetoothd -d` **[measured]**).
- The third line unpacks 5.72-0ubuntu5.9~co03.1 over 5.72-0ubuntu5.8 and, in "Setting up bluez",
  restarts bluetooth.service once (headsets disconnect; the adapter powers off and on). apt may
  print a note that the download "is performed unsandboxed as root" because the file is in a
  home folder; harmless. Only bluez changes (libbluetooth3, bluez-obexd, bluez-cups stay at 5.8).
- No conffile prompt is expected: `dpkg --verify bluez libbluetooth3 bluez-obexd` printed nothing
  on the laptop today **[measured]**, and the new package's conffile list is identical to 5.8's.

Check (root terminal):
```
sudo python3 -I /home/i/headset-kit/bin/session-state.py > /home/i/headset-kit/state-1-after-bluez.txt
```
Expect: `bluetoothd ... exe /usr/libexec/bluetooth/bluetoothd`, SHA-256
`59d2ea79b4d98eb4f1e04de1d1622908a263885856cb13ea770109431f8a2453` (the packaged daemon, from the
deb), bluez `5.72-0ubuntu5.9~co03.1`, and the drop-in list shows only `10-debug.conf`
(so the daemon still runs with `-d`). Also `sudo journalctl -u bluetooth -b 0 -n 20 --no-pager`
shows the daemon starting and no error. In the rehearsal the packaged binary contains all
three marker strings of the backport: "Wrong size of start discovery return parameters"
(BT-7 fix 1), "has no stream" (BT-7 fix 2), "cancel resume" (a14d59725) **[measured]**.
Mark: `logger -t bt-mark -p user.notice "STEP bluez 5.72-0ubuntu5.9~co03.1 installed, daemon restarted"`.

**What this contains** (so the "was it worth it" question has its answer): the five October
CVE patches and the SEP-cache regression patch of 5.72-0ubuntu5.7/5.8 (series lines 33 to 39 of the
build tree) **[quoted]** `pkg/backport/bluez-5.72-0ubuntu5.8/debian/patches/series`, then BT-7
(`a734b06059cb`, `0bed9886cff3`), the helper from `3d9900eb754d`, `a14d59725ef3` and
`664a5d3785a1` (series lines 42 to 46). The running local daemon (built 2026-08-25 from
5.72-0ubuntu5.5) lacks the CVE patches **[quoted]** STATUS line 203.

**2C. Reconnect and basic check (2 minutes).** Switch the MOMENTUM on. It reconnects (A2DP).
Play music for 30 s. Mark `STEP momentum reconnected on the new daemon, music plays yes/no`.
If it does not reconnect in 60 s, switch it off and on once; if still not, section 5, step 1.

**2D. The U12 trigger on the new daemon (5 minutes).**
Precondition: MOMENTUM in A2DP, default output, nothing played for at least 10 s (WirePlumber
suspends an idle sink after about 5 s **[inferred]** from the idle timeout in its default
configuration).
Steps, three tries, 10 s apart: `sh /home/i/headset-kit/bin/u12-trigger.sh 0`, then `... 40`,
then `... 90` (40 and 87.5 ms are the delays between Start and Abort in the two real events,
`EX-063`, `EX-085`). After each, run `python3 -I /home/i/headset-kit/bin/audio-ids.py`, read the
active profile and play a sound (`pw-play /usr/share/sounds/alsa/Front_Center.wav`).
Mark after each: `U12 new daemon: delay 40 ms: A2DP kept yes/no, sound after yes/no`.
(The natural trigger also works: start playback and start dictation in Chrome within a
second, with the sink idle before.)

**Expect (pass):** A2DP stays (or returns within 5 s), the sound plays after, and the report
(section 6, `--only U12`) says: trigger landed YES, abort sent no, A2DP lost no. In the VMs the
same chain went from A2DP lost 70/70 to kept 70/70 and 3/3 with Ubuntu's own PipeWire
**[quoted]** `CO-03.../backport/README.md` sections 2 and 9.
**A try where "trigger landed" says no is void** (the Release did not fall into the pending
Start); try another delay. If after all three delays no try landed, record that and
treat U12 as not decided, not passed.
**Failure:** A2DP lost: the card is in Handsfree/off and stays there, the sound does not play,
and bluetoothd logs `a2dp_cancel() aborting setup` / `Disconnected from ...`. Then: stop, mark
`U12 FAIL`, section 5 step 1 (rollback the daemon), and keep the logs.

**2E. Regression (3 minutes).** Settings: A2DP, then Handsfree (mSBC line), then A2DP, three
times. Each time the headset must connect, play and return. Mark `STEP regression 3x ok yes/no`.

**2F. Baselines on the stock audio session (9 minutes)**, MOMENTUM connected, A2DP.
- **U15 baseline (3 min).** Switch to the Handsfree line and listen for the headset saying
  "mute on" within 3 s; wait 10 s; switch back to A2DP and listen for "mute off".
  Mark: `U15 baseline: mute-on heard yes/no at Handsfree start, mute-off heard yes/no at return`.
  Optional, 1 min: while in Handsfree, speak for 6 s and run
  `pw-record --format s16 --target <the MOMENTUM source id from audio-ids.py> /tmp/u15-mic.wav`
  (Ctrl-C after 6 s), then `python3 -I /home/i/headset-kit/bin/mic-peak.py /tmp/u15-mic.wav`
  (is the microphone silenced? an open question in U15). Mark `U15 baseline: mic peak X dBFS`.
- **U2 look (inside the same minutes).** After the switch to Handsfree, look at the Input
  slider and the microphone icon; mark `U2 baseline: input slider at NN percent, icon crossed yes/no`.
- **CO-17 / U4 (4 min).** In Handsfree on the mSBC line, Settings > Sound open and the
  Configuration row visible (if it is not visible, mark `U4 row missing (output MOMENTUM)` and
  skip the rest). Run `python3 -I /home/i/headset-kit/bin/audio-ids.py` and note the card id and the
  index of `headset-head-unit-cvsd`. Then, with the panel open:
  `wpctl set-profile <card id> <cvsd index>` and watch the row; mark
  `U4 set-profile to cvsd: row shows cvsd/still msbc/gone`; then the same back to the mSBC index;
  then click away to another Settings page and back, and mark `U4 after leaving the page: row shows ...`.
  Expect (dossier prediction, **[inferred]**): the row stays on the old value until you leave the page.
- **U1 baseline (2 min).** Still in Handsfree: count the lines in the Configuration list; select the
  first one (no codec in its name); play the test sound. Mark
  `U1 baseline: lines N, first line selected: sound yes/no, list now shows <line>`.
  `audio-ids.py` should say "codec-less Handsfree line (U1) present: YES" on this stock plugin.
Switch the MOMENTUM to A2DP and off.

### Block 3 - Lenovo earbuds, CO-18 / U8 (5 minutes)

Precondition: earbuds connected, in the ears, nothing else playing. Settings > Sound > Output =
the earbuds. Steps: Configuration = the Handsfree line that says mSBC; wait 3 s; press Test and
listen for about 10 s (both channels are the same in Handsfree; one sound is enough). Mark
`U8 earbuds mSBC test sound heard yes/no`. Then also speak for 5 s into the earbuds and mark
`U8 earbuds mSBC microphone: asked someone to listen/not tested` (optional).
Back to the A2DP line. Expect/failure: "heard yes" means U8 does not reproduce today on E3; "no"
reproduces it. Either way the kernel line was dropped as a kernel item; the earbuds' side stays open
(`contributions/research-2026-11-01/README.md`, CO-18).
Read afterwards: section 6 (`--only U8`): the number of kernel "corrupted SCO packet" lines (expected
only at teardown) and whether a profile switch to mSBC happened. For the frames themselves:
`sudo python3 -I /root/exp/qca9377-bt-hang/contributions/research-2026-11-01/btusb/scripts/msbc-check.py --from "..." --to "..." /var/log/bt-health/capture/<newest hci file>`.
Switch the earbuds off.

### Block 4 - Shure AONIC 50, baselines (10 minutes)

Precondition: the Shure connected; the kernel and daemon unchanged since block 2.
- **U21 look (1 min).** Settings > Sound: is there a "Configuration" row under Output / Input?
  Mark `U21 Shure baseline: Configuration row present yes/no, profile shown: <text>`. Run
  `python3 -I /home/i/headset-kit/bin/audio-ids.py` and keep its output in the terminal (it lists the
  card's profiles even if the row is missing; the CO-19 plan needs the "before" list).
  (A browser tab holding the Shure's microphone can explain a missing row, as on 2026-10-29: close
  recording tabs first, then mark again if the answer changes.)
- **U19 baseline (4 min), the panel's input meter.** Open Settings > Sound. Switch Configuration to the
  Handsfree line (mSBC). Input must show the Shure's microphone and the meter must move when you speak
  (control; if it does not, mark `U19 control FAILED` and stop this test). Now switch Configuration to an A2DP
  line. At once look at the Input section: it shows the laptop's microphone. Tap near the laptop's
  microphone. Mark `U19 baseline try 1: meter after the switch moves/dead`. Repeat once (try 2).
  Expected from the record: dead both times (four occurrences 2026-10-24 to 10-26).
- **U20 baseline (3 min).** Back in Handsfree with the Shure's microphone as input and the panel open,
  hum steadily and move the Input slider from the top to the bottom and back. Mark
  `U20 baseline: meter follows the slider yes/no`. Expect no (record 2026-10-24: "exactly the same").
Leave the Shure connected and in A2DP.

### Block 5 - Change the audio session: WirePlumber only (6 minutes)

Desktop-user terminal. First check what is installed and that the shipped files are the expected ones:
```
python3 -I /home/i/headset-kit/bin/wp-override.py status
```
Expect "overrides installed by this kit: none", the shipped `policy-node.lua` and
`bluez-hardware.conf` "as expected". Then:
```
python3 -I /home/i/headset-kit/bin/wp-override.py install plugin
python3 -I /home/i/headset-kit/bin/wp-override.py install meter
python3 -I /home/i/headset-kit/bin/wp-override.py install hwvol
systemctl --user daemon-reload
systemctl --user restart wireplumber
```
What each one does (all **[measured]** in `logs/rehearse-pwset/`, `logs/rehearse-u19/`,
`logs/rehearse-overrides/`):
- `plugin`: creates `~/.local/share/kit-session/spa-0.2/` (links to every stock plugin folder, the 7
  rebuilt Bluetooth files in `bluez5/`) and a systemd user drop-in
  `~/.config/systemd/user/wireplumber.service.d/91-kit-spa-plugin-dir.conf` setting `SPA_PLUGIN_DIR` for
  WirePlumber only. The existing `90-bt-ui-capture.conf` drop-in (the debug levels) is not touched.
  In the container, WirePlumber then mapped the private `libspa-bluez5.so` (SHA-256 `91892107...9573`) and the
  PipeWire daemon does not load that file at all (0 mappings).
- `meter` (CO-32): `~/.config/wireplumber/scripts/policy-node.lua` = the installed file with
  `si_flags[si.id].was_handled = true` moved inside the `if skip_this_target == false` block, plus one
  log line at the end. The helper refuses unless the installed file has the expected SHA-256
  (`2425c905...2a61`, the 0.4.17-1ubuntu4.1 file; the laptop's file matches **[measured]** today).
- `hwvol` (CO-33, U15/U20): `~/.config/wireplumber/bluetooth.lua.d/51-kit-hw-volume-mic-quirk.lua` = the
  shipped hardware table with two rules first: `{ name = "Shure AONIC 50", no-features = [ hw-volume-mic ] }`
  and `{ name = "MOMENTUM 4", no-features = [ hw-volume-mic ] }`. Both names are exactly what PipeWire logged for
  those headsets **[measured]** (`logs/selftest-device-ids.txt`: "Shure AONIC 50", "MOMENTUM 4").
  What the rule should do, from the 1.0.5 source **[quoted]** `spa/plugins/bluez5/backend-native.c:1047-1051`,
  `:394-404`, `:1863`: the headset's `AT+VGM=n` is still answered "OK" but not passed on, so the microphone volume
  never becomes "active" and no `+VGM` is sent to the headset (neither the connect-time `+VGM: 0` that makes the
  MOMENTUM say "mute on", nor slider moves for the Shure); the microphone volume is then applied in software.
  This closes the open point in `docs/issues.md` U15 ("not traced yet") by reading; the test shows whether it holds.

**What the restart does to the running audio session** (the rehearsal covered only the first sentence).
Only WirePlumber restarts: PipeWire and pipewire-pulse, and with them every application's open
streams, keep running **[measured]** in the container (processes alive and answering through the
package-install test; for a WirePlumber-only restart this is **[inferred]**). WirePlumber loses and recreates the
Bluetooth devices: a connected headset's audio stops for a few seconds, its HFP connection (owned by the
WirePlumber process) is dropped **[inferred]** from the profile-registration design, and applications
may need a moment or a reload to find their output again. **Switch the headset off and on after
the restart** so that everything connects fresh and the log shows the new quirk lines.

Check (root terminal): `sudo python3 -I /home/i/headset-kit/bin/session-state.py > /home/i/headset-kit/state-2-after-wireplumber.txt`
Expect: WirePlumber's mapped plugin is `/home/i/.local/share/kit-session/spa-0.2/bluez5/libspa-bluez5.so`,
`SPA_PLUGIN_DIR=...` in its environment, three overrides listed. Then, as the desktop user:
```
journalctl --user -b 0 -g "kit-session-override|session manager provided data" -o cat
```
Expect two lines: `kit-session-override: policy-node.lua override is loaded` and
`spa_bt_quirks_create: loading session manager provided data` **[measured]** in the rehearsal
(`logs/rehearse-u19/patched-result.txt`, `logs/rehearse-overrides/hwvol-result.txt`). **If either line
is missing, the override is not in use and every result after it is void.**
Mark: `STEP wireplumber restarted with plugin, meter script, quirk table`.
If WirePlumber does not come back or no Bluetooth device shows up within 60 s: section 5, step 2.

### Block 6 - Shure AONIC 50, after (12 minutes)

Switch the Shure off and on. It connects. (WirePlumber may restore the profile it saved earlier,
`headset-head-unit-msbc`; that name no longer exists with the rebuilt plugin. Mark what it chose:
`CO19 8a: Shure connected, profile is <name>, audio yes/no`; `audio-ids.py` shows the active profile.)
Then mark the reconnect for the reader: `CO33 Shure reconnected after the quirk table`.
- **CO-19 / U1 / U21 (4 min).** Run `python3 -I /home/i/headset-kit/bin/audio-ids.py`.
  Expect "codec-less Handsfree line (U1) present: no" and, for the Shure's mSBC profile, a description ending
  "codec mSBC". In Settings > Sound, switch to Handsfree: the Configuration row shows the codec on the selected
  line; select the mSBC line, play the test sound, then the CVSD line, play it, speak and watch the meter.
  Marks: `CO19 Shure: lines N, codec-less line gone yes/no, mSBC sound yes/no, CVSD sound yes/no, mic yes/no`
  and `U21 Shure after: Configuration row present yes/no`.
  Failure: the codec-less line is still offered; selecting a codec line fails (the journal then has
  `failed to switch codec`); no sound or no microphone in a codec line that worked at baseline.
- **CO-32 + CO-07 / U19 (5 min).** Repeat the U19 baseline procedure exactly, three tries (Handsfree with the Shure
  microphone as input and a moving meter, then an A2DP line, tap near the laptop's microphone). Marks:
  `U19 after try 1: meter moves/dead` ... try 3. Then, still in A2DP, pick the internal microphone by hand
  in the panel and mark `CO07 manual pick of the internal microphone: meter moves/dead`.
  Leak check (the reason Ubuntu's own patch exists): play music from the browser to the Shure in A2DP, switch to
  Handsfree and back once, and listen to the **laptop's speakers**. Mark `CO32 leak check: sound from the laptop speakers yes/no`.
  **Pass (both needed):** the meter moves in all three tries and the speakers stayed silent. In the container the
  stock script destroyed the meter-like stream 2 s after the Bluetooth source vanished, the patched script kept
  it and linked it, and a stream without an explicit target stayed unlinked inside the 2 s window and linked
  after it **[measured]** `logs/rehearse-u19/*-result.txt` (fake nodes; no real headset).
  **Failure:** meter dead again with `destroy node` lines (section 6 counts them); or any laptop-speaker sound.
  If the meter is dead but there is no `destroy node` line, the panel's own re-targeting is the cause: that is the
  GNOME side (CO-07), so mark it and go on.
- **CO-33 / U20 (3 min).** In Handsfree, Shure microphone as input, hum steadily and move the Input slider top to
  bottom and back. Mark `U20 after: meter follows the slider yes/no`. **Pass:** the meter follows the slider, and the
  report (`--only CO33`) shows a non-zero "device quirks word" for the Shure at the reconnect and no `+VGM` values
  sent while sliding. **Failure:** the meter is still constant while no `+VGM` is sent (then the headset applies
  an automatic gain, a new fact; mark it), or `+VGM` still goes out (the quirk did not apply).

### Block 7 - MOMENTUM 4, after (13 minutes)

Switch the Shure off. Switch the MOMENTUM on. Mark `CO33 MOMENTUM reconnected after the quirk table`.
- **CO-33 / U15 (3 min).** Same as the baseline: Handsfree line, listen 3 s for "mute on"; 10 s; back to A2DP, listen for
  "mute off". Mark `U15 after: mute-on heard yes/no, mute-off heard yes/no`. **Pass:** neither is heard, and the report
  shows no `+VGM: 0` sent at the start. Optional, 1 min: the same microphone recording and
  `mic-peak.py` as in block 2F, mark `U15 after: mic peak X dBFS` (is the microphone working
  with software gain?). **Failure:** "mute on" still heard together with `+VGM: 0` in the journal (quirk
  did not apply to this headset).
- **CO-19 (8 min), the plan's test steps 4 to 8a:**
  1. `audio-ids.py`: codec-less line gone; the mSBC profile described "(HSP/HFP, codec mSBC)"; the CVSD one
     "(... codec CVSD)". Mark `CO19 MOMENTUM: codec-less line gone yes/no`.
  2. In Handsfree select each codec line in Settings: the profile changes, audio plays, the microphone works.
     Mark `CO19 MOMENTUM: mSBC line ok yes/no, CVSD line ok yes/no`.
  3. `pactl list cards short` shows the card name; `pactl set-card-profile <card name> headset-head-unit`
     must select the best codec (mSBC). Mark `CO19 MOMENTUM: set-card-profile headset-head-unit gives <codec>`.
  4. A2DP, Handsfree, A2DP, three times; then disconnect and reconnect while in Handsfree. Mark `CO19 MOMENTUM: regression 3x ok yes/no`.
  5. Saved-profile restore (8a): switch the MOMENTUM off, on; mark which profile WirePlumber chose
     and whether audio and microphone work (`CO19 8a MOMENTUM: profile <name> audio yes/no mic yes/no`).
  **Failure:** any codec line that does not select or play, `failed to switch codec` in the journal, a reconnect
  that ends silent. Record the log line and what the panel shows afterwards before judging.
- **CO-17 repeat (optional, 2 min).** The same `wpctl set-profile` test as in 2F, with the new plugin (the row
  logic is GNOME's; only the profile list changed). Marks as before, prefix `U4 after`.

### Block 8 - CO-29 / U14: stop the automatic Handsfree switch (8 minutes, MOMENTUM)

1. **Baseline of the problem (2 min).** MOMENTUM in A2DP and the default output. Run, in a terminal:
   `pw-cat --record -P '{ application.name="Google Chrome input" }' /tmp/kit-chrome-like.wav` for 8 s (Ctrl-C). This stands in
   for the browser's dictation stream (`application.name` equals the name on WirePlumber's list, **[quoted]** `10-default-policy.lua`;
   a stream opened this way carries that name in the graph **[measured]** `logs/rehearse-trigger/trigger-result.txt`).
   Mark `U14 baseline: headset switched to Handsfree within 3 s yes/no`. Expected: yes (the record: 2026-10-21).
   (The same stream name started the switch in the U12 trigger, so this baseline also holds for block 2.)
2. Install and restart (desktop-user terminal):
   ```
   python3 -I /home/i/headset-kit/bin/wp-override.py install noswitch
   systemctl --user restart wireplumber
   ```
   Then switch the MOMENTUM off and on. `noswitch` = `bluetooth_policy.policy["media-role.applications"] = {}` in
   `~/.config/wireplumber/policy.lua.d/51-kit-no-auto-handsfree.lua`: streams with `media.role` Communication still
   switch; named applications (the browser's dictation among them) no longer do. The wider variant
   `install noswitch-all` sets `media-role.use-headset-profile = false` (no automatic switch at all); remove
   `noswitch` first. Both load without a Lua error **[measured]** (`logs/rehearse-overrides/`); the effect
   itself is **not** testable without a Bluetooth device and is what this block tests.
3. **Test (3 min).** Same command as step 1. Mark `U14 after: headset switched to Handsfree yes/no`.
   **Pass:** it stays in A2DP, the report (`--only U14`) shows 0 profile switches. **Failure:** it still switches.
   Also try the real thing once if you like: dictation in the browser for 20 s, mark `U14 after: dictation, switched yes/no`.
4. **Trade-off to decide.** With the override a call in the browser no longer moves the headset to
   its microphone profile by itself; you choose Handsfree by hand. Keep or remove: section 5.
5. The three saved `a2dp-sink` entries in WirePlumber's state file (U14) are not touched by this kit.

### Block 9 - CO-15 / U11: new headset becomes the default output (8 minutes, optional)

Precondition: no headset connected; the laptop's own speakers are the output. Desktop-user terminal:
```
python3 -I /home/i/headset-kit/bin/wp-override.py install onconnect
systemctl --user restart pipewire-pulse
pactl list modules short
```
Expect a line `module-switch-on-connect blocklist=hdmi|^alsa_|^bluez_input` **[measured]** in the
container (`logs/rehearse-overrides/rehearsal.txt`). Restarting pipewire-pulse drops the applications'
sound connections (browser audio needs a moment, maybe a reload).
Tests: (a) switch the Shure on: does the sound go to it without opening Settings? Mark `CO15 shure connected: output is the headset yes/no`.
(b) A2DP to Handsfree to A2DP: does the output stay the headset? `CO15 profile switch: output stays yes/no`.
(c) choose the laptop speakers by hand, switch the headset off and on: `CO15 deliberate speaker choice: headset took over yes/no`.
Predicted from source (**[inferred]**): (a) yes, (b) may flip because a profile switch recreates the node, (c) yes
(`only_from_unavailable` is not implemented in 1.0.5). This is the CO-15 note's untested drop-in.

### Block 10 - Close (5 minutes)

1. Decide with section 9 what stays installed; remove the rest (section 5).
2. `logger -t bt-mark -p user.notice "SESSION end"`.
3. `sudo python3 -I /home/i/headset-kit/bin/session-state.py > /home/i/headset-kit/state-9-end.txt`
4. Section 6.

---

## 5. Rollback sheet

Every action here is rehearsed (container, byte-compared against the starting state).

**1. The bluetooth daemon (the drop-in comes back; the new package may stay installed):**
```
sudo cp -p /root/20-patched-bluetoothd.conf.saved-20261111 /etc/systemd/system/bluetooth.service.d/20-patched-bluetoothd.conf
sudo systemctl daemon-reload
sudo systemctl restart bluetooth
```
Result: bluetoothd is again `/usr/local/libexec/bluetooth/bluetoothd -d` with the same SHA-256 as the start
(`0ec72957...cc87501f`; check with `session-state.py`). **[measured]** in the rehearsal: effective ExecStart returns
to the local daemon, the only files that differ from the start are the package's own. Same precaution: no headset in
Handsfree during the restart.
Optional, to return the package too (one more restart; with the drop-in in place it starts the same old daemon):
```
sudo apt-get install --allow-downgrades -o Dpkg::Options::=--force-confold /home/i/headset-kit/artifacts/bluez-5.72-0ubuntu5.8-archive/bluez_5.72-0ubuntu5.8_amd64.deb
```
**[measured]** after both steps all files under /etc, /usr and /var/lib/dpkg/info are identical to the start, in both
install orders (`logs/rehearse-bluez/rehearsal.txt`, "diff baseline vs after"). Never `apt remove` or `purge` bluez
(deletes `/var/lib/bluetooth`).

**2. The WirePlumber overrides (one at a time if you have to find the cause; riskiest first):**
```
python3 -I /home/i/headset-kit/bin/wp-override.py remove noswitch
python3 -I /home/i/headset-kit/bin/wp-override.py remove hwvol
python3 -I /home/i/headset-kit/bin/wp-override.py remove meter
python3 -I /home/i/headset-kit/bin/wp-override.py remove plugin
systemctl --user daemon-reload
systemctl --user restart wireplumber
```
(`noswitch-all` instead of `noswitch` if that was installed. A line for an override you never installed prints
`REFUSED: ... is not installed by this kit`; harmless.) `remove` also refuses if you edited the file. It leaves
`~/.config` as it was: the rehearsal removed the folders it created and left no kit file behind. If WirePlumber still
misbehaves after all four are removed: `systemctl --user restart pipewire pipewire-pulse wireplumber`, or log out and in.
After a `plugin` removal switch each headset off and on (the Bluetooth plugin is loaded again from the stock file).

**3. CO-15:** `python3 -I /home/i/headset-kit/bin/wp-override.py remove onconnect` then `systemctl --user restart pipewire-pulse`.

**When is a restart or a logout needed, and what does it do to what is playing**

| change | what must restart | effect on the running session | logout? |
|---|---|---|---|
| new bluez package, or its rollback | `bluetooth.service`, restarted by the package itself (once) | every Bluetooth link drops and the adapter is powered off and on; audio on the laptop's own speakers is unaffected **[inferred]**; headsets must reconnect | no |
| drop-in file removed or restored | nothing by itself (`daemon-reload` re-reads files) | none | no |
| plugin, meter, hwvol, noswitch overrides | `systemctl --user restart wireplumber` (plus `daemon-reload` for the plugin drop-in) | Bluetooth devices disappear and return; links are rebuilt; headset HFP dropped **[inferred]**; PipeWire and pipewire-pulse keep running | no |
| onconnect | `systemctl --user restart pipewire-pulse` | every application's connection to the sound server is dropped; browsers may need a reload **[inferred]** | no |
| PipeWire packages (not used on the day) | `systemctl --user restart pipewire pipewire-pulse wireplumber`, or log out and in | running processes keep the old code until restarted: 15, 25 and 10 mappings of replaced plugin files in the three processes after the install **[measured]** `logs/rehearse-pwset-run1/rehearsal.txt`; after the restart the `(deleted)` mapping counts were 3, 0 and 0 (the 3 in the PipeWire daemon were not identified: **[not checked]**) | not needed |
| kernel, btusb, bluetooth.ko | never, in this session | - | - |

**4. Final check:** `sudo python3 -I /home/i/headset-kit/bin/session-state.py` and compare with `state-0-start.txt`
(`diff`). The user state files WirePlumber writes (`~/.local/state/wireplumber/`: saved profiles, default sink)
change by use and are not rolled back by anything here.

**5. The PipeWire packages (not used on the day).** If you ever install the full 3.4 set (11 packages, built and rehearsed
in `logs/build-pipewire-all/debs/`), the rollback is `apt-get install --allow-downgrades <each package>=1.0.5-1ubuntu3.3`
for all 11 together (**[measured]**: byte-identical afterwards). Never only two of them.

---

## 6. After the session: read-only reading

```
sudo python3 -I /home/i/headset-kit/bin/after-session.py --session > /home/i/headset-kit/report.txt
```
It takes the range from your `SESSION start` mark to `SESSION end` (or now), lists every mark and under each one the
journal lines of the desktop user's session (WirePlumber, pipewire-pulse), bluetoothd and the kernel that belong to
that test, with addresses masked, and a one-line **summary** that answers the test's question. Because a mark is
typed after what you saw, its lines are those since the previous mark (at most 3 minutes back, `--window`) up to 3 seconds
after it; so type each mark soon after the observation and before starting the next action:

| key | the summary line says |
|---|---|
| U12, CO03 | trigger landed (Acquire cancelled within 1.5 s: YES/no), abort sent, A2DP lost |
| U19, CO32, CO07 | meter streams created, destroyed by WirePlumber, errors sent to the panel |
| U15, U20, CO33, U2 | `+VGM` values sent to the headset, `AT+VGM` values it reported, the device quirks word (non-zero = rule applied), "disabled by quirk" lines |
| U14, CO29 | profile switches by WirePlumber, restores, "not switching" |
| U8, CO18 | kernel "corrupted SCO packet" lines |
| others | the lines themselves |

Useful variants: `--only U19` (one test), `--list-marks --since "..." --until "..."`, `--max-lines 200`.
The kit's own checks of this reader, on archived 2026-10-24 data with synthetic marks, are in `logs/selftest-after-session.txt`
(it reproduced the U19 mechanism and the U20 `+VGM` sweep from the archive **[measured]**). The WirePlumber debug
output can be rate-limited by journald; if a window looks empty, `journalctl _UID=1000 -g Suppressed --since ...` shows it.

Capture-based readings (CO-08 per-channel levels, CO-18 mSBC frames, SCO setups) are the existing project scripts, named in
blocks 1 and 3. Nothing in this kit writes into the project checkout.

---

## 7. If time runs out: what to drop, ranked by value (keep the top)

| rank | item | minutes | why keep / drop |
|---|---|---|---|
| 1 | CO-03 install + 2C + 2D (block 2 without 2A, 2E, 2F) | 13 | struck the MOMENTUM twice (2026-10-19, 10-31); also puts Ubuntu's five October CVE fixes into the running daemon; the gate for the Launchpad request |
| 2 | Block 5 + block 7 CO-19 | 6 + 8 | CO-19's gate (the laptop headset test); block 5's one WirePlumber restart also carries rank 3 and 4 |
| 3 | Block 6 CO-32 + CO-07 (U19) | 5 | two contributions (Launchpad, GNOME) wait on one 5-minute test |
| 4 | CO-33 on both headsets (U20 in block 6, U15 in block 7) | 3 + 3 | one local override answers U15 and U20; upstream entry later |
| 5 | Block 1 CO-08 | 11 | the evidence for the T8 entry is a recollection; the test is cheap |
| 6 | Block 4 and 2F baselines | 10 + 9 | they make the "after" runs credible, but the records already show the failures (skip first if forced) |
| 7 | Block 8 CO-29 | 8 | local override only; trade-off decision is yours |
| 8 | CO-17 / U4, U2, U21 looks | 6 | observations, not fixes |
| 9 | Block 3 CO-18 | 5 | the kernel line is already dropped |
| 10 | Block 9 CO-15 | 8 | optional configuration note |

A one-hour core: blocks 0, 2 (B, C, D only), 5, 6 (CO-19, U19, U20 without baselines), 7 (U15 and CO-19), 10. Without
baselines a "pass" is weaker: say so in the marks.

---

## 8. Things deliberately not used

- **`bt-ui-capture start`: not needed.** The user session's WirePlumber and pipewire-pulse already run with the debug
  levels it would stage (WIREPLUMBER_DEBUG with `script/*`, `spa.bluez5.quirks`, `spa.bluez5.native`; pipewire-pulse
  `mod.protocol-pulse*:3`) **[measured]** (`/proc/<pid>/environ` of the running processes, 2026-11-11). `start` would add:
  a kernel debug setting for the SCO socket, an accessibility-event recorder for GNOME Settings, system and session bus
  monitors, launchers that start Settings with debug domains, and a `bt-mark`. Only the row-hiding timing of U4/U21
  would benefit, and your marks cover that.
- **bt-mark, bluetoothctl, btmgmt, hciconfig, rfkill, module commands:** not used; marks are `logger` lines.
- **PipeWire project rule:** nothing here is text for the PipeWire or WirePlumber projects; the kit only gathers
  evidence, and any issue, merge request or quirk entry is yours to write.

---

## 9. Evidence index, hashes, limits, decisions

### Freshness (task 1) - nothing newer, no rebase needed

Launchpad API, read only, 2026-11-11 00:11 UTC **[measured]** `logs/freshness-noble.txt`:

| package | newest in noble | the build is based on |
|---|---|---|
| bluez | 5.72-0ubuntu5.8 (updates 2026-10-21; security 2026-10-13) | 5.72-0ubuntu5.8 |
| pipewire | 1.0.5-1ubuntu3.3 (updates and security 2026-07-13) | 1.0.5-1ubuntu3.3 |
| wireplumber | 0.4.17-1ubuntu4.1 (updates 2025-10-09) | 0.4.17-1ubuntu4.1 (not rebuilt; overrides only) |
| gnome-control-center | 1:46.7-0ubuntu0.24.04.6 (updates 2026-09-02) | not rebuilt |

The laptop's installed versions (read-only `dpkg-query`, 2026-11-11) are the same four **[measured]**.

### Artifacts and SHA-256 **[measured]**

| file | SHA-256 |
|---|---|
| `bluez_5.72-0ubuntu5.9~co03.1_amd64.deb` | `ffbedfd78fcdc124a343070663bb45739e554aa750c52bd514cb527d23b40c4a` |
| its `/usr/libexec/bluetooth/bluetoothd` | `59d2ea79b4d98eb4f1e04de1d1622908a263885856cb13ea770109431f8a2453` |
| `bluez_5.72-0ubuntu5.8_amd64.deb` (archive copy for rollback) | in `artifacts/bluez-5.72-0ubuntu5.8-archive/SHA256SUMS` |
| today's running local daemon `/usr/local/libexec/bluetooth/bluetoothd` | `0ec729572586e952cff52665dca9c2e0e4b43e257a177196d51e3098cc87501f` |
| today's packaged daemon `/usr/libexec/bluetooth/bluetoothd` (5.8) | `a704df8bb1dc6178eb82ed5a6c5e3ac3e0fe14c0d343835475e72fb37fd9a43e` |
| `libspa-0.2-bluetooth_1.0.5-1ubuntu3.4_amd64.deb` (the reviewed one) | `50920b4ef4db120966228b06dc6a52c3aa720e81277a6bde9b2770e496cfefa5` |
| `libspa-0.2-modules_1.0.5-1ubuntu3.4_amd64.deb` (not used) | `57c86f1222effc952e4ca5d023c314a0ff4a02a18e29cc9024479e071317e192` |
| rebuilt `libspa-bluez5.so` (same from both builds) | `91892107712dc971796a9807f1e1a0270ba407e3364564a2c5a5c5a7b93b9573` |
| stock `libspa-bluez5.so` on the laptop (1.0.5-1ubuntu3.3) | `421baed5a6f0e15103a5d1545da7b63556c5332e5181bd0476747d2bb3ed1c3a` |
| installed `policy-node.lua` (laptop = container = expected) | `2425c90523e39b480e10a35b14dd4bcd0e2618e9d0d4ad4359a10340792e2a61` |
| installed `bluez-hardware.conf` (laptop = container = expected) | `ec7d6656cba367c4c4187c7e67ed314be1b4d9236d90dbd22731753f2bd15c63` |

Package check (task 2): the bluez 5.72-0ubuntu5.9~co03.1 build's series lists the five CVE patches and the SEP-cache
regression patch (series lines 33 to 39), then the five backport patches (lines 42 to 46): BT-7 `a734b06059cb` and
`0bed9886cff3`, the helper of `3d9900eb754d`, `a14d59725ef3`, `664a5d3785a1` **[quoted]** the series file and each patch's
`Origin:` header. The packaged daemon contains the strings added by `a734b06059cb`, `0bed9886cff3` and `a14d59725ef3` **[measured]**
(1 hit each, rehearsal "packaged binary markers"). The helper-only commit and `664a5d3785a1` add no string; their presence rests on the
patch series and on the dossier's function-by-function comparison **[quoted]** `CO-03.../backport/README.md` section 1.
The version `5.72-0ubuntu5.9~co03.1` sorts below Ubuntu's future `5.72-0ubuntu5.9`, so a later archive update
replaces it **and with the drop-in gone silently takes the two BT-7 fixes and the U12 backport away** (decision D3).

### Rehearsal logs (all under `/root/exp/agent-work/laptop-headset-session-20261111/logs/`)

| log | shows |
|---|---|
| `rehearse-bluez/rehearsal.txt` | orders A and B, the maintainer script's systemctl calls, rollback, local-file rollback, byte comparison |
| `rehearse-pwset/rehearsal.txt` | the whole 3.4 set (0 removals), the two-package problem (10 removals), running session, restart, rollback, the private plugin directory |
| `rehearse-u19/*-result.txt` | stock, patched, restored behaviour of the meter-like stream with fake nodes; helper install/remove/refusals |
| `rehearse-overrides/` | hwvol, noswitch, noswitch-all, onconnect load without errors; first attempt (`...-run1-lua-Log-error`) failed because a log call is not available in config snippets and was fixed |
| `rehearse-trigger/` | `u12-trigger.sh` runs, plays, records, cleans up in a headless session |
| `selftest-*.txt` | the reader scripts on archived or synthetic data |
| `build-pipewire-all/` | full rebuild: 22 meson tests ok, 0 fail; 22 packages |
| `host-state-readonly.txt` | the laptop's starting state, read only (packages, running daemon, drop-ins, WirePlumber environment) |
| `freshness-noble.txt` | the Launchpad query |
| `*-run1*`, `*-run2*` directories | earlier runs kept, not deleted: each was superseded because a rehearsal script (not the kit) had a fault (a config snippet used a log call that does not exist there; a checksum command ran in the wrong folder; the first PipeWire run installed the two packages alone and so removed the audio stack, which is the finding of section 0 item 1) |

### What was not tested

- Nothing on a real headset, and nothing on the laptop. The real-device behaviour of: the rebuilt plugin, the quirk
  table (`device quirks` word and the effect on `+VGM`), `noswitch`, the U12 trigger timing, the WirePlumber restart with
  Bluetooth devices connected, the HCI recorders across a bluetoothd restart.
- systemd itself: the containers had no systemd. The maintainer script's `systemctl` calls were observed through a stub,
  and the effective unit was computed with `systemd-analyze cat-config` **[measured]**; the real `systemctl restart` was not run.
- `audio-ids.py` against the live PipeWire graph (tested on a hand-made dump only).
- `systemctl --user` drop-in behaviour (`SPA_PLUGIN_DIR`) under real systemd: the container started WirePlumber with the same
  variable by hand.
- U12 with Chrome's real dictation; the trigger script is a stand-in.
- HSP-only headsets, oFono/hsphfpd (not covered by the CO-19 test either).
- F-65 (review round 2026-11-02): the guard in `emit_nodes()` is `if (!this->props.codec)`; the reviewer says it misses
  `SPA_ID_INVALID`. It is **not** applied in the rebuilt plugin (the code still reads that way **[quoted]**
  `tmp/co19-pipewire/work/pipewire-1.0.5/spa/plugins/bluez5/bluez5-device.c:1100`). With patch 1 an HFP/HSP
  transport always has a codec, so the case should not arise **[inferred]**; if the patch is changed later, the
  plugin must be rebuilt and block 7's CO-19 steps repeated.

### Blocking question (a hook refusal, quoted, as the task rules require)

While preparing the rehearsal I tried to copy the laptop's two bluetooth.service drop-ins into my work folder. The hook
refused: *"agent-isolation-guard: the command writes under a system or private path (cp -p
/etc/systemd/system/bluetooth.service.d/10-debug.conf /etc/systemd/system/). Agents work only in containers or QEMU guests
and in their own worktree under /root/exp/agent-work/. If the task truly needs this, stop and report it as a blocking
question."* I stopped that step without retrying. The rehearsal used fixtures I wrote by hand from what I had read of
those files (same `ExecStart=` lines); the decisive facts (the effective ExecStart and what the package install does) do not
depend on byte-identical copies, but a copy of the real files would have been stronger. Question: should the real files be
copied into the work folder by you, or is the hand-written fixture acceptable?

### Decisions for you

- **D1.** Run block 2 (new bluez daemon, one adapter power cycle through bluetoothd, drop-in removed) on the day? It is the
  highest-value item and the only one that changes the Bluetooth daemon.
- **D2.** Use the private-plugin route for CO-19 on the day (recommended, section 0 item 1), instead of the package set?
  The package set exists if you prefer it; it replaces the libraries of 11 packages (all PipeWire SPA plugins
  among them, rebuilt; **[measured]** 24 of the 27 files in the rebuilt `libspa-0.2-modules` differ in bytes from the
  archive's `1.0.5-1ubuntu3.3` build, although only the Bluetooth plugin's source changed, `logs/rehearse-pipewire/rehearsal.txt`).
- **D3.** After the session: keep the new daemon (CVE fixes, BT-7, U12) and decide `apt-mark hold bluez` so that an
  archive update does not silently replace it, or roll back to the local daemon.
- **D4.** Keep `hwvol` (the two headsets without microphone hardware volume) as a standing local override after the test?
- **D5.** Keep `noswitch` (named applications no longer move the headset to Handsfree), or `noswitch-all`, or neither?
- **D6.** Run block 9 (CO-15) at all?
- **D7.** Who files what afterwards stays yours: Launchpad for CO-03, CO-19, CO-32, CO-07; the PipeWire quirk entries
  (CO-08, CO-33) and any CO-15 text are yours to write under that project's rule.
