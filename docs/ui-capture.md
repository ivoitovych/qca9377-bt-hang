# UI capture — instrumenting a manual audio test session

`tools/bt-ui-capture` switches on, for one test session, everything that records **what
changed, who decided it, and what the screen showed** for the open desktop-audio items
(U1, U2, U4, U6, U7, U8, U9 and the "Configuration line disappears" mark in
[`issues.md`](issues.md)). Why each knob, at which source line: [`ui-capture-research.md`](ui-capture-research.md).
It never restarts PipeWire, WirePlumber, bluetoothd or the shell, never touches the
Bluetooth adapter and never installs anything.

Run it from the repository checkout as root (`sudo …/tools/bt-ui-capture …`); it is not part
of `install.sh`. The monitor units run the tool from that path, so leave the checkout where
it is until `stop`.

## Before the session

1. `sudo tools/bt-ui-capture plan` — reads the machine and prints every change; changes
   nothing. Default when no argument is given.
2. *Optional, needs a logout/login (or a boot) at a moment that suits the laptop's users:*
   `sudo tools/bt-ui-capture stage-restart` writes three drop-ins under
   `~/.config/systemd/user/` — pipewire-pulse logs every client request (who asked for a
   profile, a default device, a volume), WirePlumber logs its Bluetooth backend and policy
   decisions at debug. Nothing is restarted. After the next login,
   `sudo tools/bt-ui-capture status` must say `staged …: IN EFFECT`. Without this step the
   session still records the UI, GNOME Settings, the PipeWire daemon, the kernel and the
   buses, but not WirePlumber's or pipewire-pulse's decisions.
3. `sudo tools/bt-ui-capture start` — live: PipeWire daemon log level 3, kernel debug for
   the SCO socket (connect/teardown only), the AT-SPI recorder, the system and session bus
   monitors, launchers that start GNOME Settings with its debug domains, the audio-policy
   recorder if it is not running, and a `bt-mark`. Session directory:
   `/var/log/bt-health/ui/<UTC time>/`.
4. **Close GNOME Settings if it is open**, then open it from the quick settings (Sound or
   Bluetooth Settings). It is single-instance: an already-running copy keeps its old
   environment. `status` shows the running copy's `G_MESSAGES_DEBUG`.
5. Positive control: click one thing in Settings and run `status` — `atspi.log` must have
   grown. If it has not, the UI part is not recording; say so in the notes.

## During the session — what to do, what to mark

`bt-mark "<text>"` stamps the moment into the same timeline as everything else; type it
right after what you saw. Marks are the only record of what was *seen*, so describe the
screen, not the cause.

| item | do | mark |
|---|---|---|
| U4 | headset in handsfree, Sound panel open; when the Configuration row is missing | `bt-mark "U4 Configuration row missing (output: <device>)"` |
| mark | change the output selection; if the row blinks | `bt-mark "U4 row blinked after selecting <device>"` |
| U1 | in handsfree, pick the first line of the Configuration list (output side), play the test sound; then the same from the input side | `bt-mark "U1 first line, output: sound yes/no, list now shows <line>"` |
| U2 | switch to handsfree; when the headset announces "mute on", or the microphone icon is crossed | `bt-mark "U2 headset said mute on / slider at <n>%"` |
| U6 | Sound panel open; headset A2DP → handsfree → A2DP; tap the laptop near its microphone | `bt-mark "U6 input meter moves/still, input = <device>"` |
| U7 | *Sound panel closed*; play something to the headset in mSBC; switch to CVSD (`pactl set-card-profile <card> headset-head-unit-cvsd`); then once with nothing playing | `bt-mark "U7 msbc->cvsd with stream: sound yes/no"` |
| U8 | earbuds in mSBC, test sound | `bt-mark "U8 earbuds msbc: sound yes/no"` |
| U9 | Bluetooth off, then on, headset on and connected before; wait two minutes | `bt-mark "U9 off"`, `bt-mark "U9 on"`, `bt-mark "U9 +2 min: connected yes/no"` |

## After the session

1. `sudo tools/bt-ui-capture collect` (or `--since "<time>" --until "<time>"`) —
   `…/collect-<time>/raw/` (root-only) and `published/` (sanitised: addresses replaced by
   `AA:BB:CC:00:00:NN`, numbered per file).
2. `sudo tools/bt-ui-capture stop` — restores the PipeWire level and the kernel debug flags
   recorded at start, stops the monitors (and the recorder only if `start` started it),
   removes the launchers it wrote (only files carrying its marker line), marks the journal.
   A Settings window still open keeps its debug output until closed.
3. `sudo tools/bt-ui-capture unstage` if step 2 of "Before" was used — removes the
   drop-ins; the services keep the debug environment until their next start (logout/login).

## Reading the result

| file | shows | for |
|---|---|---|
| `raw/timeline.log` | one time-ordered journal cut: kernel (SCO socket, `hci_conn`, rfkill), bluetoothd `-d`, PipeWire daemon (node/link state changes), pipewire-pulse requests `[client] SET_CARD_PROFILE … profile:…`, WirePlumber (`RFCOMM <<`/`>>`, `enter sco_acquire_cb`, `doing connect`, `acquire failed`, `setting profile N codec:M`, route restores), GNOME Settings (Gvc: `Selected '…', moving to profile …`, `Set profiles for`, `active_sink change`), the marks, journald's `Suppressed N messages` | everything |
| `raw/userspace.json` | the same userspace lines with `GLIB_DOMAIN` (which WirePlumber script — names cut to 17 characters, e.g. `script/policy-device-rou` — or GNOME domain) and `CODE_FILE/LINE/FUNC` | which code decided |
| `raw/atspi.log` | GNOME Settings' UI: `object:state-changed:showing v1=0 … name='Configuration'` (row hidden), `selected`, `focused`, children added/removed, with milliseconds | U1, U4, U6, the mark |
| `raw/system-bus.log` | BlueZ: `Powered`, `Connected`, transport `State`/`Volume`, and every call made to BlueZ (or the absence of a `Connect`) | U9, U7 |
| `raw/session-bus.log` | GNOME Settings' own D-Bus traffic, the rfkill switch the shell drives | U9 |
| `raw/captures.txt` | the HCI capture files covering the window, with ready commands (`scripts/capture-window.sh`, `scripts/sco-switch-windows.sh`) | U7, U8, U2 (`+VGM`) |
| `journalctl -u bt-audio-policy` | profile vs routes, defaults, volumes, streams | all |

Typical questions: *U4* — find the mark, then the nearest `showing v1=0 … 'Configuration'`
in `atspi.log`, then in `timeline.log` the Gvc lines just before it (was the device's
profile list being rebuilt?). *U7* — around the switch: `RFCOMM << AT+BCS=`, `enter
sco_acquire_cb`, `doing connect`, the kernel's `sco_sock_connect`/`sco_connect` and whether
`hci_conn_add_unset` follows, against the HCI capture's Disconnection Complete. *U2* — the
`setting route on` pod (restored `channelVolumes`) and `RFCOMM >> +VGM=` next to the mark.
*U9* — `disconnect_cb() reason …` in bluetoothd's lines and no `Connect` in
`system-bus.log` after `Powered` true.

Volume and limits: monitor files rotate at 50 MiB, four kept (`BT_UI_MAX_BYTES`,
`BT_UI_KEEP`); journald keeps its defaults (10 000 messages per 30 s per service) and
`status` counts suppressions. WirePlumber's staged level silences warnings of categories
not in its list (ALSA, `wp-*`) until it is unstaged and restarted.

## Always-on light mode

For a rare case that cannot be staged (the Quick Settings Bluetooth tile that stayed grey
after a click) the full session is too heavy to leave running. `start-light` records only
what compares **what the controls drew** with **the real state**, and nothing else: no
PipeWire level, no kernel debug, no launchers, no audio-policy recorder, no drop-ins, no
`bt-mark` (it queries `bluetoothctl`; the start and stop marks go through
`logger -t bt-ui-capture`).

```
sudo tools/bt-ui-capture start-light     # three transient units, idempotent
sudo tools/bt-ui-capture status-light    # units, file sizes, last write; no root needed
sudo tools/bt-ui-capture stop-light      # stops those three units only
```

| unit | file in `/var/log/bt-ui-light/<UTC time>/` | records |
|---|---|---|
| `bt-ui-light-atspi` | `atspi.log` | GNOME Settings whole, as in a full session; **GNOME Shell** (the Quick Settings tiles) only for what shows a control's drawn state: `checked`, `pressed`, `sensitive`, `enabled`, `showing`, `selected`, `active`, `expanded`, `indeterminate`, `busy` state changes, and name/description changes of toggle buttons, buttons, menu items and a label inside one (a tile's subtitle). Dropped for the shell: any text that looks like a time of day (the clock), focus, children, selection, windows, notifications |
| | | *Registration (the one non-passive step).* GNOME Shell publishes only the event types some client registered with the AT-SPI registry, so light mode starts the recorder with `--register-shell-events`: it calls `org.a11y.atspi.Registry.RegisterEvent` for exactly the twelve types above (ten states, name, description), for as long as its connection lives. A full session's recorder does not register anything |
| `bt-ui-light-sysbus` | `system-bus.log` | every method call to `org.bluez`; every signal of the adapter object `/org/bluez/hci0` (`PropertiesChanged`: `Powered`, `Discovering`, …); the object manager's `InterfacesAdded`/`Removed` about the adapter itself. The match path is exact, so `/org/bluez/hci0/dev_*` (per-device RSSI during a scan) is not recorded |
| `bt-ui-light-sessbus` | `session-bus.log` | as in a full session: Settings' traffic and the Rfkill switch the shell drives |

Files rotate at 20 MiB with four old ones kept (`BT_UI_LIGHT_MAX_BYTES`,
`BT_UI_LIGHT_KEEP`): at most 100 MiB per file, 300 MiB in all. Each `start-light` after the
units stopped opens a new directory; `BT_UI_LIGHT_BASE` moves the base (tests). Nothing is
collected or sanitised: the files hold device names and addresses, root-readable only
(mode 0640).

**It does not survive a reboot.** The units are transient (`Restart=always` restarts them
after a crash or a new login, not after a boot) and nothing is installed. After every
reboot run `start-light` again; `status-light` says `NOTHING RUNS` when that is the case.
A full `stop` does not touch the light units and `stop-light` does not touch a full session.

Positive control: click one tile, run `status-light` — `atspi.log` and `session-bus.log`
sizes must have grown and "last line written" be a few seconds ago. If the tile click
leaves `atspi.log` unchanged, the shell is not publishing on the accessibility bus (check
`gsettings get org.gnome.desktop.interface toolkit-accessibility`; the recorder never
changes it) and only the bus logs are of use.

Reading it after the grey tile: find the click in `session-bus.log`/`system-bus.log` (the
`Powered` property change and the call that caused it), then the shell's `checked` /
`pressed` events in `atspi.log` around the same second. Drawn `checked` not following a
`Powered` change is the case being looked for.

Undo summary: `stop` for everything live, `unstage` for the drop-ins. Nothing else is left
behind except the session directory (kept: it is evidence).
