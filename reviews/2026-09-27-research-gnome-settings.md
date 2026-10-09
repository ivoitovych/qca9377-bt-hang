# GNOME Settings Sound panel: U4 (Configuration row) and U6 (input meter), against upstream code

Research date: 2026-09-27. Scope: items U1, U4 and U6 in `docs/issues.md`. This note is based on
reading the source and the upstream issue trackers. Nothing was run against the desktop or the
audio services. The one exception is a read-only `journalctl` query, quoted in §3.4.

## 0. Sources and versions

| What | Where | Revision |
|---|---|---|
| gnome-control-center, upstream `main` | `cache/gnome-control-center-upstream` (shallow clone plus release tags) | `5996c254` (2026-09-26); latest tag `51.0` |
| gnome-control-center as installed | tag `46.7` in the same clone | Ubuntu `1:46.7-0ubuntu0.24.04.6`. Its changelog lists no sound-panel SRU patches since 46.3 (see §0.1) |
| libgnome-volume-control (gvc) | `cache/libgnome-volume-control-upstream` | `0a4eda0` (2026-05-15) |
| gvc bundled with 46.7, 47.0, 49.0 | submodule `subprojects/gvc` | `91f3f41` (2024-02-29) |
| gvc bundled with 50.0, 51.0, main | submodule `subprojects/gvc` | `d2442f4` (2026-02-06) |
| PipeWire | `cache/pipewire-upstream`, tag `1.0.5` | matches the installed 1.0.5 |

Commands used (one per line, all read-only):

```
git -C cache/gnome-control-center-upstream ls-tree 46.7 subprojects/gvc
  -> 160000 commit 91f3f41490666a526ed78af744507d7ee1134323	subprojects/gvc
git -C cache/gnome-control-center-upstream ls-tree 50.0 subprojects/gvc
  -> 160000 commit d2442f455844e5292cb4a74ffc66ecc8d7595a9f	subprojects/gvc
git -C cache/gnome-control-center-upstream ls-tree 49.0 subprojects/gvc
  -> 160000 commit 91f3f41490666a526ed78af744507d7ee1134323	subprojects/gvc
```

### 0.1 Ubuntu package

`zgrep -n "^gnome-control-center (" /usr/share/doc/gnome-control-center/changelog.Debian.gz`
lists the entries 46.7-0ubuntu0.24.04.6 … .1, 46.5, 46.4 and 46.3. Their texts cover
fingerprint, enterprise login, remote desktop and accessibility. `zgrep -i "sound|gvc|level|profile"`
finds sound patches only in older entries: over-amplification (`u/sound-Allow-volume-to-be-set-above-100.patch`)
and the sound-theme button. Neither touches the meter or the profile row.
**Caveat:** this check reads the changelog, not the patch set of the source package.

---

## 1. U4 — the output "Configuration" row

### 1.1 VERIFIED: what decides whether the row is shown

**Installed 46.7** — `panels/sound/cc-sound-panel.c`, `output_device_update_cb()` (line 172 onwards).
The input side, `input_device_update_cb()` at line 192, is the same:

```c
device = cc_device_combo_box_get_device (self->output_device_combo_box);
cc_profile_combo_box_set_device (self->output_profile_combo_box, self->mixer_control, device);
has_multi_profiles = (cc_profile_combo_box_get_profile_count (self->output_profile_combo_box) > 1);
gtk_widget_set_visible (GTK_WIDGET (self->output_profile_row), has_multi_profiles);
```

The row is `output_profile_row`, labelled `_Configuration` (`cc-sound-panel.ui:84` at 46.7).

**Upstream main (51.0)** — `cc-sound-panel.c:121` `output_device_update_cb()` has the same logic.
The widget is renamed `CcProfileComboRow`, and line 133 reads
`has_multi_profiles = (cc_profile_combo_row_get_profile_count (...) > 1)`.

Three properties of this code, all read directly from it:

1. **The row's visibility is computed in one place only.** That place is the handler of gvc's
   `active-output-update` signal (`active-input-update` for input). Nothing recomputes it
   when the card's profiles or ports change.
2. **The list is a snapshot, and it is not rebuilt for the same device.**
   `cc_profile_combo_box_set_device()` (46.7, `cc-profile-combo-box.c:88`, early return at line
   96) and `cc_profile_combo_row_set_device()` (main, `cc-profile-combo-row.c:177`, early
   return at line 183) both begin with `if (device == self->device) return;`. If gvc emits
   `active-output-update` again for the same `GvcMixerUIDevice`, the list store is not
   rebuilt, and `get_profile_count()` returns the old count.
3. **The count is `gvc_mixer_ui_device_get_profiles(device)`**, as filtered by gvc (§1.2). The
   row is hidden when that count is ≤ 1 at the moment of the snapshot.

Switching the output device away and back makes the combo row hold a different
`GvcMixerUIDevice` and then the original one again. That passes the early return, rebuilds
the list and re-evaluates `> 1`. **This matches the operator's recovery step in U4.**

Unchanged in every release checked. Command:
`git show <tag>:panels/sound/cc-profile-combo-row.c` (for 47.0, `cc-profile-combo-box.c`),
piped to `grep -c "if (device == self->device)"` → `1` for 47.0, 48.0, 49.0, 50.0 and 51.0.

### 1.2 VERIFIED: how gvc maps PulseAudio card profiles and ports to the list

The code is in `gvc-mixer-control.c` (both 91f3f41 and main):

- `update_card()` builds the card's profile list from `pa_card_info.profiles2`. For each card
  port it calls `determine_profiles_for_port()`, which intersects the port's own `profiles`
  list with the card's profiles, matching by name. **Yes — each port lists its profiles, and
  the UI device of that port gets only those.**
- `update_ui_device_on_port_added()` creates one `GvcMixerUIDevice` per card port and calls
  `gvc_mixer_ui_device_set_profiles (uidevice, port->profiles)`.
- `update_ui_device_on_port_changed()` (added by gvc `82fed08`, "Update card, ui-device, and
  port profiles on changes", 2024-03-07, which is in 91f3f41) recomputes `card_port->profiles`
  and calls `gvc_mixer_ui_device_set_profiles()` again. It emits `OUTPUT_ADDED` or
  `OUTPUT_REMOVED` only when the port's *availability* flips. **No signal tells consumers
  that the profile list changed** (see `gvc-mixer-ui-device.c`, `gvc_mixer_ui_device_set_profiles()`
  at line 431: no notify or emit).
- `gvc_mixer_ui_device_set_profiles()` → `add_canonical_names_of_profiles()` removes the
  opposite-direction part of the name (`input:`/`output:`) and removes duplicates by the result. It also
  skips profiles with `n_sinks == 0 && n_sources == 0`. Bluetooth profile names
  (`headset-head-unit`, `-cvsd`, `-msbc`) contain no `input:`/`output:` prefix, so all three
  remain.
- The active entry is chosen by `gvc_mixer_ui_device_get_active_profile()`. That function uses
  the card's active profile name, matched by canonical name, not by index.

### 1.3 VERIFIED: the "route #3 versus active #261" difference cannot reach gvc

- PipeWire 1.0.5 `spa/plugins/bluez5/bluez5-device.c`:
  - `SPA_PARAM_Route` is built as `build_route(this, &b, id, result.index, this->profile)`
    (lines 2285–2297).
  - The route's `profile` field is written from that argument (lines 2109–2112).
    `this->profile` is the base profile enum (`DEVICE_PROFILE_A2DP = 2`,
    `DEVICE_PROFILE_HSP_HFP = 3`), not the codec-variant index.
  - The codec-variant index is `codec + DEVICE_PROFILE_LAST` (`get_index_from_profile()`, line
    1491).
  - So a route claiming 3 while the active profile is 261 (HFP/mSBC) is how PipeWire
    represents this. The same holds for 2 versus 10 in A2DP. **This confirms the ⚠️ 23:10
    weakening in issues.md.**
- `EnumRoute` for the hf-output route (port 3) lists `profiles` by iterating
  `get_profile_from_index()`. It keeps only HSP/HFP entries that pass `validate_profile()`
  (lines 2025–2049). This gives the observed `[3, 260, 261]`.
- pipewire-pulse 1.0.5 `collect.c`, `collect_port_info()` (lines 361–410), reads only
  `SPA_PARAM_EnumRoute`. It attaches a route to a sink or source when
  `array_contains(pi->profiles, …, card_info->active_profile)`, which for this headset is
  261 ∈ [3, 260, 261]. Command:
  `git -C cache/pipewire-upstream grep -n "SPA_PARAM_ROUTE_profile\b\|SPA_PARAM_ROUTE_profile," 1.0.5 -- src/modules/module-protocol-pulse/`
  → **no output**. The pulse layer never reads the Route `profile` field, so gvc never
  sees the value 3.

### 1.4 INFERRED: what could hide the row in the U4 situation

In steady HFP state, the "Handsfree" output UI device (port `headset-hf-output`) should carry 3
profiles, and the row should be visible. The row is hidden only if the port's profile
list had ≤ 1 usable entry **at the moment of the last `active-output-update` that
brought a new device into the combo row**. Later growth of the list (§1.2, silent
`set_profiles`) is never picked up, because of §1.1 points 1 and 2.

Plausible sources of such a transient, none of them measured:

- (a) HFP codec profiles appear late. `validate_profile()` depends on the connected profiles
  and on codec support, so for a moment the route may list only `[3]`.
- (b) During a profile switch, the card change reaches gvc after the new sink.
- (c) The UI device was created from the stream rather than from the port. Such a device has
  no card, so its count is 0. `sync_devices()` creates one when a stream has no ports; see
  also gvc issue #48 for port-less Bluetooth streams.

The code proves the mechanism "row state is frozen until the device object changes". It does
not prove which transient happened on this machine.

**Test that would decide it:** at the next moment the row is missing (mark it with `bt-mark`),
record the card's port-to-profile lists as pipewire-pulse exposes them (`pactl list cards`, as
the desktop user). Also record the history of those lists around the preceding output switch.
If the list for `headset-hf-output` already has 3 entries at that moment, the cause is the
stale snapshot, and the question is only which earlier state was ≤ 1.

### 1.5 U1: plain "Headset Head Unit" (verified parts and inference)

- VERIFIED (PipeWire 1.0.5, `get_index_from_profile()`, line 1491): for
  `DEVICE_PROFILE_HSP_HFP`, the index reported is `3` only when `codec == 0` or when the
  device is an HFP AG. Otherwise it is `codec + DEVICE_PROFILE_LAST` (260/261).
- VERIFIED (gvc `gvc_mixer_control_change_profile_on_selected_device()` →
  `gvc_mixer_ui_device_get_best_profile()`): selecting the entry asks for the card
  profile `headset-head-unit` by name.
- INFERRED: PipeWire then picks a codec, and the active profile turns into `-cvsd` or `-msbc`.
  So "does not stick" is PipeWire exposing an automatic choice as a selectable
  profile, and GNOME Settings listing it unfiltered. This is not a GNOME Settings state bug.
  The profile list is also frozen per §1.1, so the dropdown may keep showing the stale
  choice until the device changes.

---

## 2. U6 — input level meter

### 2.1 VERIFIED: how the meter stream is opened

`panels/sound/cc-level-bar.c`, `cc_level_bar_set_stream()` (46.7 line 145; main line 138):

- It closes the previous `pa_stream` and creates a "Peak detect" stream (float32, 25 Hz,
  `application.id = org.gnome.VolumeControl`).
- It calls `pa_stream_connect_record (…, device = "%u" of gvc_mixer_stream_get_index (stream), …, PA_STREAM_DONT_MOVE | PA_STREAM_PEAK_DETECT | PA_STREAM_ADJUST_LATENCY)`
  (46.7 line 197; main line 190).
- No `pa_stream_set_state_callback` is installed in either version. Command:
  `git grep -n "set_state_callback" 46.7 -- panels/sound/` and the same for `origin/main` → no hits.
  If the server kills the stream, the widget does not notice and does not reconnect.

Two meters exist. `set_output_stream()` calls it with the **default sink**, and
`set_input_stream()` calls it with the **default source**.

**pipewire-pulse turns a record request for a *sink* index into that sink's monitor.**
In 1.0.5 `pulse-server.c`, `find_device()` (lines 2473–2549), a numeric name with `!sink`
sets `allow_monitor = true`, and the selector is `pw_manager_object_is_source_or_monitor`.
**The "monitor of MOMENTUM 4" capture stream is therefore the panel's *output* meter,
working as designed.** It is not an input meter pointing at the wrong node. The inference in
issues.md U6 ("the panel keeps a stream on the headset's monitor") should be
restated: *the input meter has no stream at all*.

**DONT_MOVE is honoured.** In 1.0.5 `pulse-server.c:2064`, `PW_STREAM_FLAG_DONT_RECONNECT` is set
on capture streams with DONT_MOVE. The `remove-capture-dont-move` quirk is applied only to
`firefox` (`pipewire-pulse.conf.in:149–152`). When the headset's HFP source disappears, the
input meter's stream therefore ends. It is not moved to the internal microphone.

### 2.2 VERIFIED: when the input meter is re-targeted, 46.7 compared with upstream

**46.7** (installed), `cc-sound-panel.c`:

- `input_device_update_cb()` (line 192, on gvc `active-input-update`) re-targets only if
  `cc_volume_slider_get_stream (self->input_volume_slider) == NULL` (line 205).
  `CcVolumeSlider` keeps a `g_object_ref` of its stream (`cc-volume-slider.c:262 onward`) and never
  drops it when the stream is removed. So after the first stream has been set, **this path never
  re-targets the meter**.
- The only other path is `input_device_changed_cb()` (line 152). It is connected to the device combo
  box's `changed` signal (`cc-sound-panel.ui:275`) and calls `set_input_stream()`. The combo
  box emits `changed` from gvc events only through `active_device_update_cb()`
  (`cc-device-combo-box.c:111`), which calls `gtk_combo_box_set_active_iter()` **if the id is
  in its model**. GTK emits `changed` only if the active row actually changes.
- In the gvc at 46.7 (91f3f41), `remove_stream()` → `_set_default_source (control, NULL)` emits
  only `default-source-changed`, not `active-input-update`. `_set_default_source(stream)`
  emits `active-input-update` only when `gvc_mixer_control_lookup_device_from_stream()` finds
  a device. Otherwise it logs `g_warning ("Can't find input for stream-id %d")`.

So on 46.7 the input meter is rebuilt after its source vanishes only if (i) gvc emits
`active-input-update` for the new default source, (ii) the combo model contains that
device, and (iii) it differs from the combo's current active row. **If any of these
fails, the meter stays dead**: its killed stream is never replaced, as §2.1 notes (no state callback).

**Upstream changes (all in 47.alpha and later; none in 46.x).** Command:
`git show <tag>:panels/sound/cc-sound-panel.c | grep -c "cc_volume_slider_get_stream (self->input_volume_slider) == NULL"`
→ 46.7: 1, 46.8: 1, 47.alpha/47.0/48.0/49.0/50.0: 0.

| Commit | Date | Author | Effect |
|---|---|---|---|
| `bf6f7227` "sound: Update active-device UI on signals from gvc, not on combo box changes" | 2024-03-07 | Jonas Dreßler | Meter and visibility are set in `*_device_update_cb` on every gvc signal; the `volume_slider == NULL` guard is replaced by `if (device)`. Message: *"fixes a few bugs where the stream for the input/output meter wouldn't get updated properly on active device changes."* |
| `3aeb837c` "sound: Set input/output meter stream to NULL when there's no active device" | 2024-03-07 | Jonas Dreßler | The meter is always reset, including to NULL |
| `afec106a` "sound: Unset active entry on the device comboBox when there's no active device" | 2024-03-07 | Jonas Dreßler | Message names this exact case: *"When the bluetooth profile gets changed from handset (input+output) to headphone (output only), the input device remains available, but there's no more active-input-device anymore."* |
| `a74bc5a8` "sound: Block our own signal handlers while updating the active-device combo box" | 2024-03-07 | Jonas Dreßler | Stops the recursive `change_input/output()` |
| `98875970` "sound: Refactor and fix device selection" | 2025-07-27 | Matthijs Velsink | Selection handled inside `CcDeviceComboRow` (49.0); Fixes #3506 |
| gvc `52d0c7a`, `cd6c3c8`, `05c9f28`, `8bf60ee`, `3984af0`, `b9d0b12`, `20784b5`, `3e68238`, `d2442f4` | 2026-01/02 | Guido Günther, Alynx Zhou | Bluetooth stream-id and port handling for PipeWire ≥ 1.5.84 (issues gvc #34, #39, #40; pipewire#5053); `active-*-update` is now emitted only from the server's view; in 50.0 and later |

Upstream main (`cc-sound-panel.c:143`, `input_device_update_cb()`) now calls
`set_input_stream (self, stream)` unconditionally on every `active-input-update`. **Two gaps
remain on main:** there is still no state callback in `CcLevelBar`, and re-targeting still
depends on gvc emitting `active-input-update`. In gvc main, `_set_default_source()` still
skips the emit when `lookup_device_from_stream()` fails (`gvc-mixer-control.c` lines 910–980).

### 2.3 VERIFIED ([log]): the recorder shows the input meter dying without being replaced

`journalctl --no-pager -o short-iso --since "2026-09-26 21:00" -g "control-center|GNOME Settings|Gvc|gvc"`
(excerpt; "capture[GNOME Settings]" lines are from `bt-audio-policy.py`, and each lists the capture
streams GNOME Settings holds):

```
23:08:51 change capture[GNOME Settings]: - -> MOMENTUM 4; monitor of MOMENTUM 4; monitor of MOMENTUM 4
23:10:08 change capture[GNOME Settings]: MOMENTUM 4; monitor of MOMENTUM 4; monitor of MOMENTUM 4 -> monitor of MOMENTUM 4
23:10:08 change capture[GNOME Settings]: monitor of MOMENTUM 4 -> -
23:10:08 pipewire-pulse[2816]: mod.protocol-pulse: client 0x6078c3bc6120 [GNOME Settings]: ERROR command:-1 (invalid) tag:4294967295 error:25 (Input/output error)
23:10:08 pipewire-pulse[2816]: … [GNOME Settings]: ERROR command:-1 (invalid) tag:210 error:25 (Input/output error)
23:10:08 pipewire-pulse[2816]: … [GNOME Settings]: ERROR command:-1 (invalid) tag:212 error:25 (Input/output error)
23:10:09 change capture[GNOME Settings]: - -> monitor of MOMENTUM 4
23:12:30 change capture[GNOME Settings]: monitor of MOMENTUM 4 -> -
23:12:31 change capture[GNOME Settings]: - -> MOMENTUM 4; monitor of MOMENTUM 4; monitor of MOMENTUM 4
00:37:52 change capture[GNOME Settings]: monitor of MOMENTUM 4 -> -
00:37:53 change capture[GNOME Settings]: - -> monitor of MOMENTUM 4
```

What the log shows:

- At the handsfree→A2DP switch (23:10:08), every GNOME Settings capture stream ends.
  pipewire-pulse logs I/O errors for that client at the same second (reading these as "stream
  killed" is an inference).
- One second later only one monitor stream comes back. On the input side, nothing is opened
  on the internal microphone, now or at any later point in the log.
- In handsfree (23:08:51, 23:12:31), a stream on the headset source ("MOMENTUM 4") exists,
  meaning the input meter works there.
- The pattern repeats at 00:37:52–53.

This agrees with §2.1 and §2.2: the output meter is rebuilt and the input meter is not.

Open detail: handsfree shows **two** "monitor of MOMENTUM 4" streams. One is the output
meter. The second is unexplained (the Volume Levels page or the output test window are
candidates). Not investigated.

### 2.4 UNVERIFIED: which of conditions (i)–(iii) failed on 46.7

The code allows three failure points (§2.2), and the log cannot tell them apart. The gvc
warning `Can't find input for stream-id` would identify case (i). No GNOME Settings stderr
reaches the journal on this machine: `journalctl --since "2026-09-26 21:00" -F SYSLOG_IDENTIFIER`
lists no `gnome-control-center` or `org.gnome.Settings*` identifier. So its absence proves
nothing.

**Test that would decide it** (operator's call; it touches only a new Settings instance, not
the audio services): quit Settings, then start it from a terminal as the desktop user with
`G_MESSAGES_DEBUG=all gnome-control-center sound`. Do one handsfree→A2DP switch and keep the
output. Look for `Can't find input for stream-id` and for `active_sink change` or
`lookup-device-from-stream` lines at the switch.

---

## 3. Existing upstream issues (fetched 2026-09-27 via the GitLab REST API)

Commands used:
`curl -s -o <scratch>/x.json "https://gitlab.gnome.org/api/v4/projects/GNOME%2Fgnome-control-center/issues?search=<term>&in=title&per_page=100"`
with the terms profile, level, microphone and headset, a full-text search for "bluetooth sound",
and the full gvc issue list. None of the issues found matches U4 or U6 exactly.

### 3.1 gnome-control-center

| # | State | Title | Relevance |
|---|---|---|---|
| [#1317](https://gitlab.gnome.org/GNOME/gnome-control-center/-/issues/1317) | open (2021) | Changing microphone to "Bluetooth headset" changes audio profile to HSP/HFP, but this is not reflected in the UI | **Closest to U4**: the profile row is stale after a Bluetooth profile change; *"Going to a different settings tab and going back to Sound shows that HSP profile is used."* Same snapshot mechanism as §1.1 |
| [#3710](https://gitlab.gnome.org/GNOME/gnome-control-center/-/issues/3710) | open, "Needs Information" (2026-03, 50.rc) | Sound panel behaves incorrectly when selecting Bluetooth Handsfree device | Handsfree selection reverts on the first try; the Output section shows stale stereo state (a U1-like and stale-state class) |
| [#1550](https://gitlab.gnome.org/GNOME/gnome-control-center/-/issues/1550) | closed 2022-03 | Sound: Panel needs to get updated when audio devices change | Earlier generation of the same class |
| [#3736](https://gitlab.gnome.org/GNOME/gnome-control-center/-/issues/3736) | open (2026-04, 50.1) | In "Volume Levels", recording input stream monitor is assigned to "System Sounds" playback vumeter | Meter targeting is wrong; commit `4fbedb92` says "Fixes" this issue, but it is still open |
| [#1324](https://gitlab.gnome.org/GNOME/gnome-control-center/-/issues/1324) | open (2021) | Sound "Output" level shows input level | Meter targeting confusion |
| [#3451](https://gitlab.gnome.org/GNOME/gnome-control-center/-/issues/3451) | open (2025, 48.1) | PipeWire Digital surround 5.1 AC3 profile hidden until activated externally … | A profile missing from the row until an external change (ALSA, not Bluetooth) |
| [#3800](https://gitlab.gnome.org/GNOME/gnome-control-center/-/issues/3800) | open (2026-08) | Sound panel pins the fallback output device by rewriting `default.configured.audio.sink` on device removal | Not U4 or U6, but directly relevant to **U3** (Settings rewriting the configured default) |
| [#3506](https://gitlab.gnome.org/GNOME/gnome-control-center/-/issues/3506) | fixed by `47face1f` and `98875970` (49.0) | (profile and device selection broken after the AdwComboRow port) | Regression inside 48/49; not present in 46.7 |

### 3.2 libgnome-volume-control

| # | State | Title | Relevance |
|---|---|---|---|
| [#48](https://gitlab.gnome.org/GNOME/libgnome-volume-control/-/issues/48) | open (2026-09-10) | Sound panel stays on "No Input Devices" when the default source is WirePlumber's port-less Bluetooth loopback (A2DP) | Same failure class as U6 case (i): `_set_default_source()` cannot find a UI device, so `active-input-update` is not emitted and the panel never updates. That report is for WirePlumber 0.5's loopback source; this machine runs WirePlumber 0.4.17, which (to my knowledge, unverified) has no such loopback |
| [#38](https://gitlab.gnome.org/GNOME/libgnome-volume-control/-/issues/38) | open | mixer-stream: handle portless streams during profile transitions | Bluetooth A2DP↔HFP transients with port-less streams |
| [#19](https://gitlab.gnome.org/GNOME/libgnome-volume-control/-/issues/19) | open (2022) | Incorrect devices displayed for the current audio profile? | Background |
| #23, #9 | closed by `82fed08` | crashes in `gvc_mixer_card_get_profile` / `…get_active_profile` | Background for §1.2 |

I found no issue about "Configuration row disappears / profile combo hidden for Bluetooth
Handsfree", and none about "input level meter dead after Bluetooth profile switch". Both
searches used title and full-text search terms; GitLab search is not exhaustive.

---

## 4. Assessment

### U4 — Configuration row missing in handsfree

- **Classification:** bug in GNOME Settings (stale UI state), not design. By the code, the row's
  visibility and contents are a snapshot taken when the combo row's device *object* changes.
  gvc updates the UI device's profile list silently, and the panel never re-reads it
  (§1.1, §1.2). The profile/route index difference is PipeWire's normal representation and
  never reaches gvc (§1.3).
- **Fixed upstream?** No. The early return and the single evaluation point are unchanged
  through 51.0 and main. The nearest open report is #1317.
- **Still to prove on this machine:** the transient state with ≤ 1 profile (§1.4, a/b/c).
- **What a patch would touch:**
  1. gvc: emit a signal, or a `notify::profiles` on `GvcMixerUIDevice`, from
     `gvc_mixer_ui_device_set_profiles()` or `update_ui_device_on_port_changed()`. The same
     applies to the card's active-profile change.
  2. gnome-control-center `cc-profile-combo-row.c`: drop or relax the
     `device == self->device` early return (rebuild the list when the profile list or
     active profile changes), and re-evaluate `has_multi_profiles` in
     `cc-sound-panel.c` (`output_device_update_cb` / `input_device_update_cb`) on that
     signal.

  A panel-only fix (always rebuild on `active-*-update`) would help only if gvc emits that
  signal after the profile-list change. It does not always do so.

### U6 — input meter silent after handsfree→A2DP

- **Classification:** bug. The "monitor of MOMENTUM 4" stream is the output meter, as
  designed (§2.1). The actual defect is that the input meter's stream is killed along with the
  headset source and never replaced (§2.3, log).
- **Fixed upstream?** Largely, for the path on the installed version. 46.7's re-target guard
  (`volume_slider == NULL`) was removed in 47.alpha (`bf6f7227`, `3aeb837c`, with
  `afec106a` covering this exact Bluetooth case). 46.8 still has the guard, so it is **not
  fixed in any 46.x**, and Ubuntu 24.04 ships 46.7.
- **Remaining upstream gap:** main still has no `pa_stream` state callback in
  `CcLevelBar`, and still depends on gvc emitting `active-input-update`, which gvc #48 shows can
  fail.
- **What a patch would touch:**
  1. For Ubuntu 24.04: an SRU backport of `bf6f7227` and `3aeb837c` (and probably `a74bc5a8`
     and `afec106a`, which were written as one series) to 46.7. That is a
     Launchpad matter, not an upstream report.
  2. For upstream: `cc-level-bar.c` should install `pa_stream_set_state_callback()`. On
     `PA_STREAM_FAILED` or `TERMINATED`, clear the stream and let the panel re-target it, or
     re-target itself to the current default source. Separately, gvc `_set_default_source()`
     should emit `active-input-update` even when no UI device is found (#48).
- **Before filing:** run the §2.4 debug capture to find which condition failed, and test
  47 or later (for example a newer GNOME live image) to show the behaviour is gone there.

### Side finding (INFERRED; not related to this machine's version)

Commit `4fbedb92` ("sound: Set pa_stream sink monitor for input rows", 2026-06-02, in 51.0)
calls `pa_stream_set_monitor_stream (level_stream, gvc_mixer_stream_get_id (stream))` for
every `CC_STREAM_TYPE_INPUT` meter, **including the main panel's input meter on a source**.
`gvc_mixer_stream_get_id()` returns a client-local serial (`gvc-mixer-stream.c:37`,
`stream_serial`, set at line 815), not the server index (`gvc_mixer_stream_get_index()`).
pipewire-pulse replaces the capture target with that number (`pulse-server.c:2066–2067`,
`source_index = direct_on_input_idx`). This looks like it can point the 51.0 input meter
at an unrelated object. It has not been tested here; if confirmed, it would be worth a
separate upstream report.
