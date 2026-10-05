# Desktop audio / UI bugs — deciding code, upstream state, and what to log (2026-10-05)

Read-only research behind `tools/bt-ui-capture` and [`ui-capture.md`](ui-capture.md), for
the unfixed userspace items of [`issues.md`](issues.md) §U1–U9 (U1, U2, U4, U6, U7, U8, U9,
the operator's mark "the Configuration line disappears for a moment"; U3 briefly; U5 is
withdrawn). Installed versions [quoted, `dpkg-query -W …`, 2026-10-05]: `pipewire`
`1.0.5-1ubuntu3.3`, `wireplumber` `0.4.17-1ubuntu4.1`, `gnome-control-center`
`1:46.7-0ubuntu0.24.04.6` (gvc `91f3f41`, [`userspace-upstream-check-2026-10-03.md`](userspace-upstream-check-2026-10-03.md)
§U6.3), `bluez` `5.72-0ubuntu5.5` (running the locally patched build), `libgtk-4-1`
`4.14.5+ds-0ubuntu0.10`, `at-spi2-core` `2.52.0-1build1`, kernel `7.0.0-34`.

Every statement is marked **[quoted]** (command and output, or URL and text, trimmed only
where marked `…`), **[inferred]** (this reading of quoted material) or **[not found]** (with
the bound of the search). Source line numbers are at the installed version: PipeWire tag
`1.0.5`, WirePlumber tag `0.4.17`, GNOME Settings tag `46.7`, gvc `91f3f41`, BlueZ the running
build's tree (`/var/cache/bt-investigation/bluez-build/bluez-5.72`, the Ubuntu 5.72 source plus
this project's two patches) and tag `5.72`, kernel Ubuntu `7.0.0-34` (`cache/ubuntu-7.0.0-34`).
Clones used: `cache/pipewire-upstream`, `cache/wireplumber-upstream`,
`cache/gnome-control-center-upstream`, `cache/libgnome-volume-control-upstream`,
`/var/cache/bt-investigation/bluez` (read-only), `cache/linux` (log only). Tracker searches
went through the public JSON APIs (GitLab freedesktop/GNOME, Launchpad, GitHub via `gh`,
patchwork); the raw answers are kept under `tmp/ui-capture/upstream/` (not tracked).
Nothing on the machine was changed; the only command run against the live session that is
not a plain read is `tools/bt-ui-capture plan` (a dry run, verified to change nothing by
`scripts/prove-ui-capture.sh`).

---

## 0. Facts every section below relies on

**0.1 PipeWire's Bluetooth backend runs inside WirePlumber.** [quoted]
`git -C cache/wireplumber-upstream show 0.4.17:src/scripts/monitors/bluez.lua`, lines 303–313:
```
  -- create the node; bluez requires "local" nodes, i.e. ones that run in
  -- the same process as the spa device, for several reasons
  …
    local node = LocalNode("adapter", properties)
```
and the live journal [quoted, `journalctl _SYSTEMD_USER_UNIT=wireplumber.service -n 5`]:
```
2026-10-05T01:28:57.494251+02:00 n wireplumber[3292]: RFCOMM receive command but modem not available: AT+BTRH?
```
— a `spa.bluez5.native` message (`backend-native.c:1112`) logged by the `wireplumber`
process. **So `spa.bluez5*` verbosity is WirePlumber's, not PipeWire's** [inferred].

**0.2 WirePlumber 0.4.17 cannot change its log level at runtime.** [quoted]
`git -C cache/wireplumber-upstream grep -n "wp_log_set_level" 0.4.17` → `lib/wp/wp.c:35`
(`wp_init()`: `wp_log_set_level (g_getenv ("WIREPLUMBER_DEBUG"))`), `lib/wp/core.c:296` (at
core construction, the config's `log.level` — `2` in `/usr/share/wireplumber/*.conf` — only
when `WIREPLUMBER_DEBUG` is unset) and `src/tools/wpexec.c:256`: all at start-up, nothing
listens for a change. Runtime changes arrived with
[wireplumber!574](https://gitlab.freedesktop.org/pipewire/wireplumber/-/merge_requests/574)
"m-log-settings: add module for changing log level at runtime", merged 2023-12-24 ("Allows
changing log level at runtime with wpctl"), first in 0.4.81/0.4.82 (the 0.5 series); the 0.4
port !573 was closed unmerged [quoted, tracker search files
`tmp/ui-capture/upstream/raw/items/wp_m_574.json` and the commit-to-tag lookup]. One level
applies to all enabled categories, and **an unlisted category is silenced at every level,
warnings included** [quoted, `lib/wp/log.c`: `if (cf.log_level > enabled_level) return
G_LOG_WRITER_UNHANDLED; … if (!is_category_enabled(cf.log_domain)) return
G_LOG_WRITER_UNHANDLED;`]. Lua scripts log under `script/<first 17 characters of the file
name>` [quoted, `modules/module-lua-scripting/api/api.c:323-325`], e.g.
`script/policy-device-pro`.

**0.3 PipeWire 1.0.5's runtime level is the daemon's only.** [quoted]
`git show 1.0.5:src/pipewire/settings.c`, `metadata_property()`:
```
	if (spa_streq(key, "log.level")) {
		v = value ? atoi(value) : 3;
		pw_log_set_level(v);
```
and the live metadata [quoted, `runuser -u i -- env XDG_RUNTIME_DIR=/run/user/1000 pw-metadata -n settings`]:
```
Found "settings" metadata 31
update: id:0 key:'log.level' value:'2' type:''
```
Every `pw_context` creates its own "settings" metadata (`context.c:368 pw_settings_expose`),
but a client's is registered in its own process [inferred]: `pw-metadata -n settings 0
log.level N` reaches the `pipewire` daemon and neither `pipewire-pulse` nor `wireplumber`.
`pipewire-pulse` has no runtime log message either [quoted, `git grep -n "pipewire-pulse:"
1.0.5 -- src/modules/module-protocol-pulse` → only `malloc-info` and `malloc-trim`]. The
protocol dump topic (`conn.protocol-native`) is fixed at module load
(`module-protocol-native.c:1714 debug_messages = mod_topic_connection->level >= …`), so a
runtime level change does not start message dumps [quoted]. At level 3 the daemon logs
node state transitions `(%s-%u) %s -> %s` (`impl-node.c:412`), link state and creation
(`impl-link.c:189`, `:1429`), XRuns (`impl-node.c:1922`) [quoted, `git grep -n pw_log_info
1.0.5 -- src/pipewire/impl-link.c src/pipewire/impl-node.c`].

**0.4 pipewire-pulse logs each client request at info, with its arguments** — e.g.
`pulse-server.c:4622` `"[%s] %s tag:%u index:%u name:%s profile:%s"` (set-card-profile),
`:4666` set-default-sink/source, `:2936` set-*-volume (index and name, not the value),
`:3000` mute, `:3057` port [quoted, `git grep -n 'pw_log_info("\[%s\] %s tag' 1.0.5 --
src/modules/module-protocol-pulse/pulse-server.c`]. Topics `mod.protocol-pulse`,
`conn.protocol-pulse` (`module-protocol-pulse.c:336-340`). Only through `PIPEWIRE_DEBUG` at
process start (`pipewire.c parse_pw_debug_env`, format `<glob>:<level>,…`; `conn.*` is set
to 0 whenever `PIPEWIRE_DEBUG` is set) [quoted].

**0.5 GNOME Settings logs only under named domains.** [quoted] `panels/meson.build:39`
`'-DG_LOG_DOMAIN="cc-@0@-panel"'` (so `cc-sound-panel`); gvc `meson.build:74`
`c_args = ['-DG_LOG_DOMAIN="Gvc"']`. GLib 2.80 matches `G_MESSAGES_DEBUG` as a
**space-separated** list [quoted, GLib 2.80.0 `glib/gmessages.c:2630-2647 domain_found()`,
fetched from the GitHub mirror]. GNOME Settings is launched by the shell from desktop files
(`gnome-sound-panel.desktop` `Exec=gnome-control-center sound`, no `DBusActivatable`) or by
D-Bus (`/usr/share/dbus-1/services/org.gnome.Settings.service`
`Exec=/usr/bin/gnome-control-center`) [quoted, `grep -H "^Exec\|DBusActivatable" …`]; the
running copy (pid 22314, since 2026-10-01) sits in
`app-gnome-gnome\x2dbluetooth\x2dpanel-22314.scope` with stdout/stderr on a socket and has
logged nothing to the journal [quoted, `/proc/22314/cgroup`, `ls -la /proc/22314/fd/2`,
`journalctl _PID=22314` → `-- No entries --`]. It is single-instance (GtkApplication), so a
new environment applies only after it is closed [inferred].

**0.6 GTK 4.14 publishes UI state on the accessibility bus without being asked.** [quoted]
GTK 4.14.5 `gtk/a11y/gtkatspicontext.c` (GitHub mirror), every emitter is
```
static void
emit_state_changed (GtkAtSpiContext *self, const char *name, gboolean enabled)
{
  if (self->connection == NULL)
    return;
  g_dbus_connection_emit_signal (self->connection, NULL, self->context_path,
                                 "org.a11y.atspi.Event.Object", "StateChanged", …
```
with "showing"/"visible" emitted on hide/show (`:950-951`), "selected", "focused",
"sensitive", `ChildrenChanged`, `SelectionChanged`, `PropertyChange` (accessible-name),
window activate/deactivate. No listener check exists in 4.14.5 [quoted, `grep -n
"GetRegisteredEvents"` on the source and `grep -a -o` on `/usr/lib/x86_64-linux-gnu/libgtk-4.so.1`:
no match]. On this session accessibility is **off** and GNOME Settings is **still connected**
to the accessibility bus [quoted]:
```
$ runuser -u i -- env XDG_RUNTIME_DIR=/run/user/1000 gsettings get org.gnome.desktop.interface toolkit-accessibility
false
$ runuser -u i -- env XDG_RUNTIME_DIR=/run/user/1000 busctl --user get-property org.a11y.Bus /org/a11y/bus org.a11y.Status IsEnabled ScreenReaderEnabled
b false
b false
$ runuser -u i -- env XDG_RUNTIME_DIR=/run/user/1000 busctl --address=unix:path=/run/user/1000/at-spi/bus list --no-pager
…
:1.16                      22314 gnome-control-c i    :1.16      …
…
org.a11y.atspi.Registry    3661 at-spi2-registr i    :1.1       …
```
(trimmed after the CONNECTION column: the UNIT column names the user manager in a form the
publication scan reads as an address)
**So a passive listener on that bus records GNOME Settings' UI changes and nothing has to
be enabled** [inferred]. Enabling `toolkit-accessibility` is not needed; it would load the
AT-SPI bridge into GTK 3 apps and the shell and make Chrome build its accessibility tree
(CPU and memory for the whole session) [inferred], and it is not done. python3-pyatspi is
not installed; `gir1.2-atspi-2.0` and `python3-gi` are [quoted, `dpkg-query -W`] — the
recorder uses Gio directly and never registers with the AT-SPI registry
(`scripts/bt-ui-atspi.py`).

**0.7 What is already logged.** [quoted]
`bluetoothd` runs `/usr/local/libexec/bluetooth/bluetoothd -d` (`pgrep -a -f bluetoothd`;
`systemctl cat bluetooth.service` shows `10-debug.conf` and `20-patched-bluetoothd.conf`).
Kernel dynamic debug: `hci_conn.c` connection sites on (`hci_sco_setup`, `hci_add_sco`,
`hci_setup_sync_conn`, `hci_conn_add_unset`, `hci_conn_del` … `=p`), every `sco.c` site off
(`sco_sock_connect =_`, `sco_connect =_`, `sco_conn_del =_` …) [quoted, `grep -E
"net/bluetooth/(sco|hci_conn)\.c:" /sys/kernel/debug/dynamic_debug/control`]. Two HCI
recorders run (`bt-capture` → `/var/log/bt-health/capture/hci-*.btsnoop`, `bt-trace` →
`btmon -w /var/log/bt-health/trace/bt-*.btsnoop`; the file names carry the local start
time — inferred from `bt-20261005-012858.btsnoop` last written `2026-10-05T01:29:04` local)
and the audio-policy recorder runs as the transient system unit `bt-audio-policy` since
2026-10-01 00:18:56 [quoted, `systemctl status bt-audio-policy`]. Journald: persistent,
`SystemMaxUse=16G`, `SystemKeepFree=20G`, rate limits at the defaults
(`RateLimitIntervalSec=30s`, `RateLimitBurst=10000`, per service) [quoted,
`systemd-analyze cat-config systemd/journald.conf`].

---

## U1 — the first (codec-less) line of the handsfree profile list

**Deciding code.**
- PipeWire offers the generic entry: `spa/plugins/bluez5/bluez5-device.c:build_profile()`
  1762–1792, `codec == 0` → `desc = _("Headset Head Unit (HSP/HFP)"); priority = 1;` [quoted].
- Selecting it: `impl_set_param()` 2547–2553 logs `"%p: setting profile %d codec:%d save:%d"`
  at debug, then `set_profile()` 1156–1235: the same profile with a different codec passes
  the early return (1167–1171), so `emit_remove_nodes()` (1173) and
  **`spa_bt_device_release_transports()` (1175) close the live SCO link**; `get_hfp_codec(0)`
  is 0, so no codec negotiation (1208); `props.codec = 0; emit_nodes(this);` (1222–1224);
  `emit_nodes()` then takes the existing transport and **re-assigns `props.codec =
  get_hfp_codec_id(t->codec)`** (1085–1094) [quoted]. The active profile index is therefore
  the codec-specific one again (`get_index_from_profile()` 1499–1503) [inferred] — "does not
  stick and falls back to a codec-specific entry" (issues.md U1 [operator]) is the code's
  behaviour.
- On the GNOME side: `cc-profile-combo-box.c:profile_changed_cb()` 34–52 calls
  `gvc_mixer_control_change_profile_on_selected_device()` (gvc `gvc-mixer-control.c` 540–577,
  which logs `"Selected '%s', moving to profile '%s' on card '%s' on stream id %i"`), and
  `gvc_mixer_ui_device_get_best_profile()` (`gvc-mixer-ui-device.c` 471–555, logs
  `"Candidate for profile switching"`) [quoted].
- **"Selected for output it gives no sound"** [operator]: the selection releases the
  transport (closing the SCO socket) and the re-emitted nodes acquire the same transport
  straight away, so the new `connect()` is issued while the old link is being torn down —
  the situation of U7 [inferred, to be confirmed by the capture: `sco_sock_release` /
  `__sco_sock_close` then `sco_sock_connect` within milliseconds, and whether a `Setup
  Synchronous Connection` follows].

**Upstream.**
- **Fixed in PipeWire 1.2**: [pipewire!1869](https://gitlab.freedesktop.org/pipewire/pipewire/-/merge_requests/1869)
  "bluez5: show only codec profiles also for HFP/HSP", merged 2024-02-03: "Don't show a
  "codecless" profile for HFP, similarly as we do for A2DP" [quoted,
  `tmp/ui-capture/upstream/raw/items/pw_m_1869.json`]; commit `805e5cf9c` (2024-01-28), first
  tags `1.1.81 … 1.2.0`, in no `1.0.x` [quoted, `git -C cache/pipewire-upstream tag --contains
  805e5cf9c115 --list "1.[012].*"`]. At 1.2.0 `build_profile()` reads `/* HFP will only
  enlist codec profiles */ if (codec == 0) return NULL;` [quoted, `git archive 1.2.0`].
- Not in Ubuntu's 1.0.5 [quoted, `https://changelogs.ubuntu.com/changelogs/pool/main/p/pipewire/pipewire_1.0.5-1ubuntu3.3/changelog`:
  the noble entries are v4l2/video (LP: #2131647, #2061687), duplicated samples after silence
  (LP: #2100497), two CVE fixes, MIDI SysEx (LP: #2067338); none touches `spa/plugins/bluez5`].
- Related GNOME reports: gnome-control-center#2361 "Regression with introduction of sound
  output configuration for bluetooth devices" (closed 2023-02-21: "three different options
  for the same profile"), #1417 (open, 2021) [quoted, tracker files]. No report against
  PipeWire 1.0 of the codec-less line itself [not found; searched pipewire issues
  "headset-head-unit" (26 hits), "headset head unit" (50), "HSP/HFP profile codec" (28),
  "codecless" (1), MRs "codecless" (5); Launchpad gnome-control-center "headset head unit" (0)].

**What the capture shows.** pipewire-pulse info: `[GNOME Settings] SET_CARD_PROFILE …
profile:headset-head-unit` (staged); Gvc debug: "Selected …, moving to profile …"
(G_MESSAGES_DEBUG, next Settings start); WirePlumber debug: "setting profile 3 codec:0",
"remove nodes", transport state changes, "enter sco_acquire_cb", "doing connect", "acquire
failed"/"acquire complete" (staged); recorder: Profile 261 → … → 261; AT-SPI: the selected
line of the popover and the combo's state; kernel `sco.c` (runtime) and HCI capture: the
release/connect timing.

**Patch plan.** None needed in PipeWire (the decision inputs are logged at debug). The GNOME
side's choice is logged by gvc; the optional GNOME patch (§Task 4) adds the profile picked
and whether the list was rebuilt.

---

## U2 — handsfree microphone volume 0.00 / 0.27 / 0.08, "mute on"

**Deciding code.**
- The headset reports its microphone gain: `backend-native.c:rfcomm_hfp_ag()` 1047–1053
  `AT+VGM=%u` → `rfcomm_emit_volume_changed(rfcomm, SPA_BT_VOLUME_ID_RX, gain)` (394–418,
  debug `"volume changed %d"`) → `bluez5-device.c:volume_changed()` /
  `node_update_volume_from_transport()` (385–428) [quoted].
- PipeWire pushes the source volume to the headset: after each SCO acquire `sco_ready()`
  calls `rfcomm_ag_sync_volume(td->rfcomm, false)` and again after 1.5 s (1565–1566,
  2010–2023) → `rfcomm_ag_set_volume()` (1855–1885) sends `+VGM=<hw>`; a node volume set
  goes through `sco_set_volume_cb()` (1887–1908), `hw = lround(cbrt(v) * 15)`
  (`defs.h:728-736`) [quoted]. This is the "+VGS/+VGM twice, 1.5 s apart" of the U7 capture
  [inferred].
- WirePlumber restores a saved route volume whenever a route becomes active:
  `policy-device-routes.lua:handleDevice()` 426–435 → `restoreRoute()` 133–199 (debug
  `"setting route on"` with the param, so the restored value is printed), and saves on change
  (`saveRouteProps()` 107–131; info `"storing route props for"`) [quoted].
- **The saved value** [quoted, `grep -n "hf-input:\|hf-output:" /home/i/.local/state/wireplumber/default-routes`,
  read only; the card's address replaced here by `<card>`]:
  ```
  99:bluez_card.<card>:input:headset-hf-input:channelVolumes=0.00048244695062749;
  ```
  — linear 0.000482, cubic 0.078: the "0.08 … route linear volume 0.000482" recorded for
  U2 at 22:55:59 (issues.md). Today's recorder shows the same step at node creation
  [quoted, `systemctl status bt-audio-policy`]:
  `2026-10-05T00:09:08+0200 change node[MOMENTUM 4 Audio/Source] volume: 0.0 mute=False -> 0.08 mute=False`.
- [inferred] The 0.08 is not set by anyone at each switch: it is WirePlumber restoring a
  value saved at some earlier moment, then sent to the headset as `+VGM=1`
  (`lround(cbrt(0.000482)·15) = 1`); a 0.00 sends `+VGM=0`, which a headset may announce as
  "mute on". What wrote 0.000482 into the state file is not on record.

**Upstream.** pipewire#678 "Adjusting Bluetooth microphone hardware volume" (open, 2021: "on
none of the headsets does the VGM value actually affect the volume of the recorded audio");
pipewire#2062 (closed 2022) shows `+VGM` driving the source volume [quoted, tracker files].
No report of a handsfree source restored to ~0 [not found; searched pipewire issues "hfp
microphone volume" (8), "VGM" (3), "AT+VGM" (3), "hardware volume hfp" (8), "microphone
volume 0" (50), "source volume reset" (9); wireplumber "bluetooth microphone volume" (8),
"source volume" (44)].

**What the capture shows.** Who changed the volume, to what, when: WirePlumber debug
(`script/policy-device-rou`, the route pod with `channelVolumes`), spa.bluez5.native debug
(`RFCOMM << AT+VGM=`, `RFCOMM >> +VGM=`), pipewire-pulse info (a client's
set-source-volume), the recorder (the value), the HCI capture (the RFCOMM bytes, already
recorded), AT-SPI (the slider's and the mute icon's state). Patch: none needed.

---

## U3 (cheap) — the saved default source outranks the headset

WirePlumber's `module-default-nodes` (`m-default-nodes`) and `policy-node.lua` decide;
Ubuntu's `lp-2122640-bluetooth-audio-glitch.patch` adds a 2 s window after a Bluetooth node
disappears during which streams are not linked to non-Bluetooth devices [quoted, `diff -u
<0.4.17 policy-node.lua> /usr/share/wireplumber/scripts/policy-node.lua` and the Ubuntu
changelog `wireplumber (0.4.17-1ubuntu4.1)` "(LP: #2122640)"]. Upstream: LP#1970185 "20.04
does not remember preferred bluetooth headset microphone" (Confirmed), gnome-control-center#3800
(open, output side), wireplumber#314 (USB) [quoted, tracker files]. Captured by the staged
WirePlumber debug (`m-default-nodes`, `script/policy-node`) and the recorder.

## U5 (withdrawn) — note only

`policy-device-profile.lua` re-applies the stored default profile on every `EnumProfile`
change: `self.active_profiles` is only ever read or cleared, never filled [quoted, `grep -n
active_profiles` → lines 12, 64–65, 188–193, 243], by design since
`d7f1710` "policy-device-profile: always consider the stored default profile when
re-evaluating" (2022-04-25, "Fixes: #179") [quoted]. Its info lines ("Found default profile
… ", "Setting profile … on …") are in the staged WirePlumber set.

---

## U4 and "the Configuration line disappears for a moment"

**Deciding code (GNOME Settings 46.7, all [quoted]).**
- The row exists only while the combo holds more than one profile, decided **only on gvc's
  active-*-update signal**: `cc-sound-panel.c:output_device_update_cb()` 171–189
  ```
  device = cc_device_combo_box_get_device (self->output_device_combo_box);
  cc_profile_combo_box_set_device (self->output_profile_combo_box, self->mixer_control, device);
  has_multi_profiles = (cc_profile_combo_box_get_profile_count (self->output_profile_combo_box) > 1);
  gtk_widget_set_visible (GTK_WIDGET (self->output_profile_row), has_multi_profiles);
  ```
  (input side 191–209).
- The profile list is **not rebuilt while the device object is the same**:
  `cc-profile-combo-box.c:cc_profile_combo_box_set_device()` 96–97
  `if (device == self->device) return;`.
- gvc `91f3f41` updates a device's profile list in place on every card change
  (`gvc-mixer-control.c:update_card()` 2528–2651 → `update_ui_device_on_port_changed()`
  1982–2039 → `gvc_mixer_ui_device_set_profiles()`; `gvc-mixer-ui-device.c` 431–461, debug
  "Set profiles for", "Adding profile to combobox"), introduced by
  [libgnome-volume-control!25](https://gitlab.gnome.org/GNOME/libgnome-volume-control/-/merge_requests/25)
  "Update card profiles and ports when they change" (merged 2024-03-12; the MR's head `sha`
  is `91f3f41490666a526ed78af744507d7ee1134323` — exactly the gvc GNOME Settings 46.7 ships)
  [quoted, tracker file `gvc_m_25.json`]; `git log -8 91f3f41` lists `82fed08`
  "mixer-control: Update card, ui-device, and port profiles on changes" and `10a3c0a`
  "mixer-control: Support adding and removing card-ports after card was added" just below it
  [quoted; that they belong to the MR is inferred from the subjects].
- active-output-update is emitted by `_set_default_sink()` 1086–1093 (debug "active_sink
  change"), `on_default_sink_port_notify()` 1015–1036 and `gvc_mixer_control_change_output()`
  621/654/661; the device combo box handles it first (`cc_device_combo_box_set_mixer_control()`
  is called at `cc-sound-panel.c:355-356`, the panel connects its own handler at 357–366) and
  ignores an id it has no row for (`cc-device-combo-box.c:active_device_update_cb()` 111–118).
- [inferred] Hence: if the signal arrives while the selected device's port lists ≤ 1 profile
  (mid-switch, while gvc rebuilds the card) the row is hidden, and later card updates of the
  same device neither emit the signal nor rebuild the list — the row stays hidden until a
  different device is selected ("returns after switching the output device away and back",
  issues.md U4 [operator]); a short disappearance on selection is the same evaluation at an
  intermediate state. The panel logs none of these decisions.

**Upstream.** gnome-control-center#1033 "no profile combo box if there is only one profile"
(closed 2020, by design); #3710 "Sound panel behaves incorrectly when selecting Bluetooth
Handsfree device" (open, 2026-03-17, 50.rc: "'Input' section will populate correctly for a
second or two, before the system reverts"); #3715 (open, 2026-03-31: crash, "the stream's
port list is transiently empty"); libgnome-volume-control#38 (open, 2026: "the stream can be
in a transient state where `stream->priv->ports` is NULL"); gnome-control-center!3211/!3213
(GNOME 49, fix #3506 "'Output Device' & 'Configuration' automatically changed to first
option"); libgnome-volume-control!27 (draft, open) [quoted, tracker files]. No report of the
row missing in handsfree mode [not found; searched gnome-control-center issues "profile combo"
(2), "Configuration row" (16), "Configuration missing" (17), "profile list" (31), "handsfree"
(6), "flicker sound" (0); MRs "sound profile" (8)]. Not fixed for 46 [inferred: none of the
above is in a 46.x tag].

**What the capture shows.** AT-SPI: `object:state-changed:showing` / `visible` on the row
named "Configuration" with millisecond times, the selected device line, focus; Gvc debug
(next Settings start): "Updating card", "Set profiles for", "Adding profile to combobox",
"active_sink change", "Removing UIDevice"; the recorder: profile and routes at that moment;
pipewire-pulse info: the requests Settings made. **Logs cannot show** the panel's own
decision (which device the combo returned, the profile count, the early return) — that is
the GNOME patch below.

---

## U6 — the input level meter does not follow the active input

**Deciding code**, fix and Ubuntu state: [`userspace-upstream-check-2026-10-03.md`](userspace-upstream-check-2026-10-03.md)
§U6 (`cc-sound-panel.c:input_device_update_cb()` 191–209, the `== NULL` guard at 205).
**New since then** [quoted, tracker files `gcc_m_2350.json`, `gcc_m_2617.json`, `gcc_m_2363.json`]:
the series was merged as
[gnome-control-center!2350](https://gitlab.gnome.org/GNOME/gnome-control-center/-/merge_requests/2350)
"sound: Improve edge cases and fix bugs with the input/output selection" (Jonas Dreßler,
opened 2024-03-07, merged 2024-03-12: "fixes a few bugs with the input/output switcher,
especially for bluetooth headsets"); the follow-up `0da10f03a` is !2617 (merged 2024-05-26,
closes #3070); !2363 fixes a double `gvc_mixer_control_open()` the series introduced
(`4afd08e23`, also first in 47). First tag 47.alpha. No Launchpad bug for noble [not found;
searched gnome-control-center "input level" (4), "microphone level" (4), "level meter" (0),
"sound input" (34); LP#1923602 "Sound 'Output' level shows input level" (Triaged, 2021) is
older and different].

**What the capture shows** (the SRU test case): the recorder's `capture[GNOME Settings]`
lines (one stream on 46.7 predicted, two on 47); pipewire-pulse info: Settings'
`CREATE_RECORD_STREAM` requests and their targets; daemon info (runtime): the links
`(link) (node) -> (node)`; AT-SPI: which input row is selected. The optional GNOME patch adds
whether the meter's stream was replaced or kept. An SRU request should cite !2350 and !2617.

---

## U7 — no new SCO link after an HFP codec switch under a live link

**Deciding code** (PipeWire 1.0.5 and kernel 7.0.0-34): [`userspace-upstream-check-2026-10-03.md`](userspace-upstream-check-2026-10-03.md)
§U7.3 and `EX-060`; line numbers re-checked on `cache/ubuntu-7.0.0-34` [quoted]:
`hci_conn.c:hci_connect_sco()` 1758, lookup 1771, the `BT_OPEN || BT_CLOSED` condition 1791,
`hci_sco_setup()` 1801; `sco.c:sco_connect()` 310 (`hci_connect_sco` at 349),
`sco_sock_connect()` 670, `sco_conn_del()` 254, `__sco_sock_close()` 542.

**Upstream, new since 2026-10-03** [quoted, tracker files]:
- [pipewire#5506](https://gitlab.freedesktop.org/pipewire/pipewire/-/work_items/5506)
  "bluez5: HFP microphone dies after the first use when the headset sends AT+BCC during eSCO
  setup (patch)", opened 2026-10-03: the `AT+BCS=` handler "re-creates the transport and
  emits `codec_switched` even though the confirmed codec is the one already in use; both
  close the SCO socket mid-connect and leave an orphaned eSCO link"; "the PipeWire side of
  bluez/bluez#2562". Open, patch attached, not merged.
- [bluez/bluez#2562](https://github.com/bluez/bluez/issues/2562) "SCO: rejected duplicate
  Enhanced Setup Synchronous Connection makes hci_setup_sync_conn_status() delete the
  successful eSCO conn", open since 2026-09-22: PipeWire "tears the transport down **while its
  SCO connect is still in flight**".
- [inferred] Same code path as U7 (transport freed and re-created in the `AT+BCS=` handler,
  SCO connect overlapping a teardown) with a different ordering: those reports have a
  connect in flight when the socket is closed; U7 has a connect issued before the old link's
  Disconnection Complete. The U7 report should cite both and say how it differs.
- Also open: pipewire#5476 (handsfree fails on the second call), #5498 (daemon stops after
  repeated transport errors); #5467 closed 2026-09-30 (different mechanism, as recorded).
  Kernel patchwork: no patch about a connect reusing a closing `hci_conn` [not found;
  searched "sco_connect" (6), "hci_connect_sco" (0), "BT_DISCONN" (1, L2CAP),
  "Disconnection Complete" (0), "eSCO" (17)].

**What the capture shows.** PipeWire's side is already logged at debug in 1.0.5 —
`"transport %p: enter sco_acquire_cb"` (1580), `"enter sco_do_connect, codec=%u"` (1428),
`"doing connect"` (1445), `"connect(): %s"` (1452), `"ready"` (1487), `"acquire failed: %s
(%d)"` (1541), `"acquire complete, read_mtu=%u"` (1547), `"Transport %s released"` (info,
1640), `RFCOMM <<`/`>>` (1351, 307) [quoted] — all `spa.bluez5.native`, i.e. WirePlumber's
staged debug. The kernel's side needs the `sco.c` sites the runtime step enables:
`sco_sock_connect`, `sco_connect` (prints both addresses), `sco_conn_add`, `sco_chan_del`,
`sco_conn_del` (with `err`), `__sco_sock_close`, `sco_connect_cfm`/`sco_disconn_cfm`; with
`hci_conn.c` (already on) the absence of `hci_conn_add_unset` after `sco_connect` marks a reused
dying connection [inferred; the working switch is the positive control]. The HCI capture
gives the air side. Patch: none needed.

---

## U8 — earbuds silent in mSBC; "corrupted SCO packet"

**Deciding code (kernel 7.0.0-34, all [quoted]).** `btusb.c:btusb_isoc_complete()`
1644–1671 logs `"corrupted SCO packet"` (1668) when `btusb_recv_isoc()` (1372–) returns
`-EILSEQ`, which it does when the reassembled header's length exceeds the skb's tailroom
**or** its handle is not a live SCO/eSCO connection (1408–1415, `btusb_validate_sco_handle()`
1344–1370, whose comment reads "USB isochronous transfers are not designed to be reliable and
may lose fragments. When this happens, the next first fragment encountered might actually be a
continuation fragment."). **It is the receive (microphone) direction only**; the silent
earbuds are the transmit direction [inferred]. PipeWire's mSBC side: `sco-source.c` logs
`"missing mSBC packet: %u != %u"` (info, 467) and `"sbc_decode failed"` (warn, 483); its
transport choice `"bluez-monitor/hardware.conf: msbc:%d msbc-alt1:%d"` (info,
`backend-native.c:635`) [quoted]. The earbuds' decoding is not observable from the host.

**Upstream** [quoted, tracker files]: bluez/bluez#2545 (MT7921 `13d3:3563`, "SCO microphone
becomes silent after A2DP/HFP profile changes", "corrupted SCO packet", closed 2026-09-25, no
fix stated); patchwork 14033330 "btusb: Reset altsetting when no SCO connection" (new,
2025-03-31); kernel bugzilla 215576 "HSP/HFP mSBC profile broken with QCA6174" (2022, handled
elsewhere). Nothing for these earbuds [not found; pipewire "msbc no sound" (34), "mSBC silent"
(3), "msbc earbuds" (3); patchwork "corrupted SCO" (0), "SCO packet" (25)].

**What the capture shows.** WirePlumber staged info/warn (`spa.bluez5.source.sco`: missing
packets, decode failures — whether the microphone side breaks in mSBC);
`spa.bluez5.native` info (the mSBC/alt-1 decision at connection); kernel `sco.c` (runtime);
the HCI capture's SCO data (already recorded). **Logs cannot show which btusb check drops a
fragment** — that is the btusb patch below; and nothing on the host shows what the earbuds
decode — the transmit payload has to be checked offline in the existing capture (the 60-byte
mSBC frames, H2 header `01 08/38/c8/f8`, SBC syncword `ad`) [inferred method; not done here].

---

## U9 — no reconnect after Bluetooth off → on

**Deciding code (BlueZ).** `plugins/policy.c:disconnect_cb()` — tag 5.72 at 743 (comment
"Only attempt reconnect for the following reasons" at 749), running build 804–846: reconnect
only for `MGMT_DEV_DISCONN_TIMEOUT` and `MGMT_DEV_DISCONN_LOCAL_HOST_SUSPEND`; with `-d` it
logs `"reason %u"` and, when it does reconnect, `"Device %s identified for
auto-reconnection"` [quoted, `grep -n` on both trees]. **Unchanged on BlueZ master**
(`c73fa2f9a`, `5.87-78`): `disconnect_cb` at 908, the same condition at 919–920 [quoted,
`git -C /var/cache/bt-investigation/bluez grep -n … HEAD -- plugins/policy.c`]. Nothing runs
on adapter power-on for known audio devices [inferred: the policy plugin's adapter driver has
only `probe` and `resume`, 891–905].
Why rfkill is not a "timeout": kernel `d77433cdd252` "Bluetooth: Disconnect connected devices
before rfkilling adapter" (2024-01-07; first tag `v6.9-rc1`) — "This leads to connected
devices remaining in connected state and the bluetooth connection eventually timing out after
rfkilling an adapter. Use the rfkill hook in the HCI driver to go through the full power-off
sequence (including stopping scans and disconnecting devices)" [quoted, `git -C cache/linux
log --all --grep=…`, `tag --contains`, patchwork 13512955]. [inferred] Before 6.9 an rfkill
looked like link loss and BlueZ reconnected; since then it is a local disconnect and it does
not. The resume path came from patchwork 11777437 "policy: Reconnect audio on controller
resume" (2020) [quoted].

**Upstream discussion** [quoted, tracker files]: LP#1494242 "Try to auto connect devices when
user enables bluetooth" (Won't Fix; 2015/2018); wireplumber#846 "Audio bluetooth device not
reconnecting automatically after reboot" (closed 2026-08-24, area::other-project; Ubuntu
24.04, WirePlumber 0.4.17; BlueZ "said that they don't have this kind of feature"); BlueZ
GitHub #752 (closed stale), #2594 (LE HID, open). No patch adds power-on reconnection [not
found; patchwork "ReconnectUUIDs" (0), "reconnect" (35), "rfkill" (22); BlueZ GitHub
"reconnect" (50), "rfkill" (50)].

**What the capture shows.** Already: rfkill events and bluetoothd `-d` (`disconnect_cb()
reason …`). Added: the system-bus monitor (adapter `Powered`, device `Connected`, and every
method call to BlueZ — a `Connect` after power-on, or none) and the session-bus monitor (the
gnome-settings-daemon rfkill switch the quick settings drive). Patch: none (the decision is a
fixed condition that is already logged).

---

## Task 2 — the knobs, verified at the installed versions

| knob | exact setting | when it applies | volume (estimate) | serves | undo |
|---|---|---|---|---|---|
| PipeWire daemon level | `pw-metadata -n settings 0 log.level 3` (as the user) | **live** | node/link transitions, XRuns: tens of lines per stream start/stop | U6, U7, U1 timing | `pw-metadata -n settings 0 log.level 2` (the recorded value) |
| sco.c dynamic debug | `module bluetooth func <f> +p` for 16 connection-level functions | **live** | ~10–20 lines per SCO link (per-packet functions excluded) | U7, U1, U8 | `… -p` for those recorded as off |
| GNOME Settings debug | `G_MESSAGES_DEBUG="cc-sound-panel Gvc"` via user overrides of `gnome-sound-panel.desktop`, `gnome-bluetooth-panel.desktop`, `org.gnome.Settings.desktop` (`~/.local/share/applications/`) and `org.gnome.Settings.service` (`~/.local/share/dbus-1/services/`) | **next time Settings starts** (close the running one) | Gvc logs every sink/source/card update: hundreds of lines per profile switch | U1, U4, U6, the mark | delete the four files (marker-checked) |
| AT-SPI recorder | Gio listener on the user's accessibility bus (`org.a11y.Bus.GetAddress`), GNOME Settings only, no registry registration | **live** | a few lines per UI change; BoundsChanged/caret not subscribed | U1, U4, U6, the mark | stop the unit |
| System bus | `dbus-monitor --system "sender='org.bluez'" "destination='org.bluez'"` | **live** | per connection/profile/volume event | U9, U7 context | stop the unit |
| Session bus | `dbus-monitor --session` for `org.gnome.Settings` and the gsd rfkill object | **live** | low | U9 | stop the unit |
| pipewire-pulse requests | `PIPEWIRE_DEBUG="mod.protocol-pulse*:3"` in `pipewire-pulse.service.d/` | **restart** (next login/boot) | every client request incl. GNOME Shell's: estimate hundreds per minute of UI use | U1, U2, U4, U6 | delete the drop-in; next restart |
| WirePlumber + Bluetooth backend | `WIREPLUMBER_DEBUG="D:spa.bluez5,spa.bluez5.native,spa.bluez5.device,spa.bluez5.source.sco,spa.bluez5.quirks,script/*,m-default-nodes,m-default-profile,wireplumber,pw"` | **restart** | per switch some hundreds; `spa.bluez5.sink.sco` excluded (debug per graph cycle, `sco-sink.c:602`). **Cost: warnings of unlisted categories (ALSA, wp-*) are not logged while it is in effect** | U1, U2, U3, U5, U7, U8 | delete the drop-in; next restart |
| PipeWire daemon at start | `PIPEWIRE_DEBUG=3` in `pipewire.service.d/` | **restart** | as the live level | keeps the live level across a re-login | delete the drop-in |
| bluetoothd | `-d` | already on | — | U9 | — |
| HCI captures, recorder, kernel hci_conn.c | — | already on | — | all | — |
| toolkit-accessibility | **not changed** (not needed with GTK 4.14) | — | — | — | — |

Journald rate limits apply per service (`RateLimitIntervalSec=30s`, `RateLimitBurst=10000`
by default, not changed here, scaled by free disk space by journald itself);
`bt-ui-capture status` counts journald's "Suppressed N messages" notices. The monitors do not
use the journal: their files are capped (50 MiB × 4 each by default).

---

## Task 4 — where logs are not enough: two debug patches (plans, nothing built)

### 4.1 GNOME Settings 46.7 — the sound panel's own decisions (U4, the mark, U1, U6)

File: [`ui-capture-patches/gnome-control-center-46.7-sound-panel-debug.patch`](ui-capture-patches/gnome-control-center-46.7-sound-panel-debug.patch).
`g_debug()` only, under the existing `cc-sound-panel` domain: in `output_device_update_cb()` /
`input_device_update_cb()` (signal id, the device the combo returned, the profile count, row
shown/hidden, meter stream replaced/kept), `output/input_device_changed_cb()`,
`cc_profile_combo_box_set_device()` (the early return and the rebuilt list) and
`profile_changed_cb()`. Checked: `patch --dry-run -p1` against the 46.7 tree → `checking
file panels/sound/cc-sound-panel.c`, `checking file panels/sound/cc-profile-combo-box.c` (no
reject) [quoted].

Rebuild path (operator's decision; **not on the family laptop if avoidable**):
1. On a separate Ubuntu 24.04 machine, VM or container: `apt-get source
   gnome-control-center=1:46.7-0ubuntu0.24.04.6` (deb-src enabled), `apt-get build-dep
   gnome-control-center` (many -dev packages — the reason to keep it off the laptop).
2. `patch -p1 --dry-run < …debug.patch` against the Ubuntu tree (it carries two feature
   patches in `panels/sound`), then apply; `dpkg-buildpackage -b -uc -us` or
   `meson setup _build && ninja -C _build`.
3. Copy only the built `gnome-control-center` binary to `/opt/bt-ui-gcc/` on the laptop; do
   **not** install the .deb. Same version, so the system's data files, schemas and gvc match.
4. Close Settings; run `G_MESSAGES_DEBUG="cc-sound-panel Gvc" /opt/bt-ui-gcc/gnome-control-center
   sound` for the test. Revert: `rm -r /opt/bt-ui-gcc`. Nothing in the package database changes.

### 4.2 btusb (Ubuntu 7.0.0-34) — which check drops an SCO fragment (U8)

File: [`ui-capture-patches/btusb-7.0.0-34-recv-isoc-debug.patch`](ui-capture-patches/btusb-7.0.0-34-recv-isoc-debug.patch).
One `bt_dev_dbg()` on the `-EILSEQ` branch of `btusb_recv_isoc()` (handle, dlen, tailroom,
whether the handle is live); a dynamic-debug site, off until `module btusb func
btusb_recv_isoc +p`, evaluated only on the error path. Checked: `patch --dry-run -p1 -d
cache/ubuntu-7.0.0-34` → `checking file drivers/bluetooth/btusb.c` [quoted].

Rebuild path: `scripts/build-btusb-module.sh --ksrc cache/ubuntu-7.0.0-34 <patch>` (builds
only), installed for the next cold boot with `scripts/module-updates.sh --module btusb install
<ko>`, reverted with `… remove`. **Conflict:** `updates/btusb.ko` is trial E3's treatment (the
exact upstream device-table entry); a debug build must carry that entry too, and installing it
changes the trial — so only after E3 #1 closes, on the operator's word.

### Not patched, with the reason
PipeWire and WirePlumber: every decision point needed is logged at debug in 1.0.5/0.4.17
(sections U1, U2, U7, U8); only the level is missing, and the staged environment provides it.
`pipewire-pulse` logs set-volume requests without the value; the recorder supplies the value
at the same moment, so no patch. BlueZ: the U9 decision is a fixed condition already logged
with `-d`.

---

## Open, not done here

- `shellcheck` is not installed on this machine (`dpkg-query -W shellcheck` → `no packages
  found`; no binary on PATH or under `/root/exp`, `/opt`, `/usr/local`): the tool is checked
  with `bash -n`, and executed end to end by `scripts/prove-ui-capture.sh` (67 checks), not
  linted.
- The mSBC payload check of the earbuds' captured frames (U8) and the reading of the U2
  state-file history are analysis tasks, not logging.
- Comments on tracker issues were not read (the GitLab notes endpoint answers 401 without a
  login; issue descriptions only).
