# U1–U6 against upstream PipeWire / WirePlumber — source research (2026-09-27)

Scope: `docs/issues.md`, section "U1–U4 — userspace audio problems seen during the E1 tests".
The installed stack is PipeWire 1.0.5 and WirePlumber 0.4.17 (Ubuntu 24.04 packages). This
note compares it with upstream `master` as cloned on 2026-09-26/27:

| repo | local clone | HEAD | `git describe` |
|---|---|---|---|
| PipeWire | `cache/pipewire-upstream` (blobless) | `662fe053ac6226e014b908167b89ac15abd84ef7` (2026-09-25) | `1.6.0-1216-g662fe053a` |
| WirePlumber | `cache/wireplumber-upstream` (blobless) | `251d7424df15b4516ae17b4cc1181f9043150427` (2026-09-25) | `0.5.17-30-g251d742` |

Nothing on the running system was read or changed for this note. Every point below is either
**VERIFIED** (source text or tracker record quoted, with the command that shows it) or
**INFERRED/UNVERIFIED** (reasoning, not yet tested on this machine).

Commands were run as `git -C <clone> …`. Tracker records come from the GitLab REST API
(`curl -s -A "git/2.43" https://gitlab.freedesktop.org/api/v4/projects/<proj>/issues/<n>`).
The HTML pages are behind a bot check and do not load for scripted fetches; the API does.
Issue comments (`/notes`) came back empty without a login, so only titles, states and
descriptions are quoted.

---

## Before filing anything: upstream contribution rules

**VERIFIED.** PipeWire's contribution guidance (`c74b645a7`, 2026-09-04) says, among other
things:

> Original logs MUST be included. Do not speculate on root causes, except to help user to
> provide necessary evidence as attachments.

It also warns that maintainers may ban people who break its rules. Consequence: a PipeWire
report carries the original logs and states what was observed; this note supplies the
evidence (logs, commands, code pointers). The same should be assumed for WirePlumber, which is
in the same GitLab group and has its own guidance (`7f70594`, `6838194`, 2026-08-15); read
both again before filing anything.

---

## U1 — the plain "Headset Head Unit (HSP/HFP)" entry, and routes naming profile #3 / #2

### VERIFIED — what index 3 is in 1.0.5

1.0.5's profile enum (`git show 1.0.5:spa/plugins/bluez5/bluez5-device.c`, lines 53–60):

```
DEVICE_PROFILE_OFF = 0, DEVICE_PROFILE_AG = 1, DEVICE_PROFILE_A2DP = 2,
DEVICE_PROFILE_HSP_HFP = 3, DEVICE_PROFILE_BAP = 4, DEVICE_PROFILE_LAST = DEVICE_PROFILE_BAP,
```

Profile indexes 0–4 are the bare profiles. A codec variant's index is `codec + DEVICE_PROFILE_LAST`
(`get_profile_from_index`, `get_index_from_profile`, lines 1454–1507). Codec ids come from
`git show 1.0.5:spa/include/spa/param/bluetooth/audio.h`: `CVSD = 0x100`, `MSBC` next. So:

- #3 = HSP/HFP with codec 0 (the "codecless" entry);
- #260 = 0x100 + 4 = CVSD;
- #261 = 0x101 + 4 = mSBC.

`build_profile`, `case DEVICE_PROFILE_HSP_HFP` (lines 1762–1792):

```
} else {
    desc = _("Headset Head Unit (HSP/HFP)");
    priority = 1;
}
```

The codec variants get `priority = 1 + hfp_codec;  /* prefer msbc over cvsd */`. That gives
priority 1/2/3 for generic/CVSD/mSBC, which matches the `EnumProfile` priorities in issues.md U5.

### VERIFIED — selecting #3 cannot stick in 1.0.5

`set_profile` (lines 1156–1235) is called with profile 3 and codec 0. The codec-switch branch
needs `get_hfp_codec(codec)` to be non-zero, so it is skipped and `emit_nodes` runs. In
`emit_nodes`, `case DEVICE_PROFILE_HSP_HFP` (lines 1085–1101):

```
t = find_transport(this, SPA_BT_PROFILE_HFP_HF, this->props.codec);
...
    this->props.codec = get_hfp_codec_id(t->codec);
```

The active codec is set back to that of the existing SCO transport. The reported active
profile is `get_index_from_profile(HSP_HFP, codec)`, which is 260 or 261 again. Picking the
generic entry therefore re-emits the nodes (the transports are released first, line 1175) and
then reports whichever codec the headset link already uses. That is exactly the operator's
"does not stick and falls back to a codec-specific entry". It is designed behaviour of the
codecless entry, not a malfunction.

### VERIFIED — upstream removed the generic entry (fixed from 1.2.0)

Commit `805e5cf9c115e3d0498f78e9e00e3ae93178e47d`, 2024-01-28, "bluez5: show only codec profiles
also for HFP/HSP":

> Don't show a "codecless" profile for HFP, similarly as we do for A2DP. […] There's also no
> need for "fallback profile", we always just emit nodes for the transport we find.

- `git tag --contains 805e5cf9c`: first tag `1.1.81`, then `1.2.0` onward. No 1.0.x tag.
- `git show <tag>:spa/plugins/bluez5/bluez5-device.c | grep -c 'desc = _("Headset Head Unit (HSP/HFP)");'`
  gives 1.0.5 → `1`, 1.0.9 → `1`, 1.2.0 → `0`.

Current `master` (`bluez5-device.c:2403–2436`) has the comments `/* Only list codec profiles */`
and "Give base name to highest priority profile, so that best codec can be selected at command
line with out knowing which codecs are actually supported". Upstream, `headset-head-unit` is now
the name of the best-codec profile itself, not a separate entry.

### VERIFIED — route `profile` = 3 (HFP) / 2 (A2DP) is the internal enum, not a profile index

In both 1.0.5 and `master`, the active routes are built with `build_route(this, &b, id,
result.index, this->profile)` (1.0.5 line 2289, `master` line 2990). The route's
`SPA_PARAM_ROUTE_profile` is written from that argument (1.0.5 line 2110, `master` line 2811).
`this->profile` is the enum value: 3 = HSP_HFP, 2 = A2DP in 1.0.5. It is not the profile index
(261, 10).

The ALSA device does it differently: `spa/plugins/alsa/alsa-acp-device.c:621` passes
`card->active_profile_index`. The bluez5 plugin is therefore inconsistent with ACP. The mismatch
issues.md recorded in both modes (HFP 261 vs 3, A2DP #10 vs #2) comes from this and nothing
else.

It has no consumer in the paths that matter here:
- `git grep -n "ROUTE_profile\b" HEAD -- src/` finds nothing.
- `module-protocol-pulse/collect.c:402–411` parses index, direction, name, description,
  priority, available, info, devices and **profiles**, but not `profile`.
- WirePlumber does not read it either.

So it cannot be what hides GNOME's Configuration row (U4). That supports the "⚠️ Weakened, 23:10"
note in issues.md.

The A2DP index #10 decodes to codec id 6 in the 1.0.5 enum (`SBC=1 … APTX=5, APTX_HD=6`),
i.e. aptX HD. That is **INFERRED** from the index. The profile's name in `EnumProfile` would
confirm it.

### INFERRED/UNVERIFIED

- "Selected for output it gives no sound": not explained by the code read. The code does show
  that selecting #3 releases the transports and re-emits the nodes. That fits the five SCO
  teardown/setup cycles at 22:07, but why output then stays silent is open. It would need a
  PipeWire debug log (`SPA_DEBUG`/`PIPEWIRE_DEBUG` for `spa.bluez5*`) at the moment of the pick.
- Because the entry no longer exists in ≥1.2.0, a "no sound on the generic entry" report
  against 1.0.5 would very likely be closed as fixed upstream. The generic entry is not worth
  reporting.
- The route `profile` enum/index inconsistency is a small, real, cosmetic defect in
  `master`. A patch would pass the active profile *index*
  (`get_index_from_profile(this, this->profile, this->props.codec)`) to `build_route`, the way
  ACP does. Its only visible effect is on tools that print the field (`pw-cli enum-params …
  Route`, our `bt-audio-policy.py`). Low value; optional.

### Existing tracker items (VERIFIED titles/state via API)
- pipewire#2015 "Cannot choose headset-head-unit-cvsd profile in Gnome audio settings for
  WH-CH510 bluetooth headset", closed, 2022-01-12. This is the same family (GNOME ↔ HFP
  codec profiles), not a duplicate.
- pipewire#953 "Switching profiles using pactl stops working after headset-head-unit was set",
  closed, 2021-03-23.
- Nothing open found that matches U1.

**Assessment U1:** designed behaviour in 1.0.5, and the generic entry was removed upstream in
1.2.0. **Not reportable.** At most, a small optional patch for the route `profile` field.

---

## U2 — source volume ↔ HFP microphone gain; "mute on"

### VERIFIED — the mapping (unchanged 1.0.5 → master)

PipeWire acts as the Audio Gateway (AG). The headset (HF) *sends* `AT+VGM=<g>`. PipeWire
*sends* `+VGM:<g>` (HFP) or `+VGM=<g>` (HSP). `g` runs from 0 to 15 (`SPA_BT_VOLUME_HS_MAX 15`,
`defs.h:640`).

1. **Headset → source volume.** In `backend-native.c` (`master` 1380–1388, 1.0.5 1047–1051):

   ```
   } else if (sscanf(buf, "AT+VGM=%u", &gain) == 1) {
       if (gain <= SPA_BT_VOLUME_HS_MAX) {
           if (!rfcomm->broken_mic_hw_volume)
               rfcomm_emit_volume_changed(rfcomm, SPA_BT_VOLUME_ID_RX, gain);
   ```

   `rfcomm_emit_volume_changed` (`master` 676–706) stores `spa_bt_volume_hw_to_linear(g, 15)` on
   the transport. `bluez5-device.c` `volume_changed` → `node_update_volume_from_transport`
   (1.0.5 385–427) copies it to the source node and marks it for saving:

   ```
   /*
    * Consider volume changes from the headset as requested
    * by the user, and to be saved by the SM.
    */
   node->save = true;
   ```

   **So yes: a headset's `AT+VGM` report changes the source volume, and the session manager
   stores it as if the user had chosen it.**

2. **Source volume → headset.** `sco_set_volume_cb` (`master` 3152–3173) runs
   `value = spa_bt_volume_linear_to_hw(volume, 15)`, then `rfcomm_ag_set_volume` sends
   `+VGM: %d`. On SCO connect it also sends both gains immediately and again after 1.5 s
   (`rfcomm_ag_sync_volume(…, false)` / `(…, true)`, `master` 2806–2807). Per the comment there,
   this is because headsets change levels while in A2DP without reporting them.

3. **Scale** (`defs.h` 798–817): `hw = round(cbrt(linear) * 15)`, `linear = (hw/15)^3`.
   `wpctl` shows cubic volume, which is `hw/15`. A value that came from the headset is
   therefore always a multiple of 1/15 in `wpctl`: 0.00, 0.07, 0.13, 0.20, 0.27, 0.33 …

4. **Per-device opt-out.** The quirk feature `hw-volume-mic` ("Functional HSP/HFP microphone
   volume support", `bluez-hardware.conf:14`) sets `broken_mic_hw_volume`, and then `AT+VGM` is
   ignored (`backend-native.c:3581–3587`). It was added in `9d38d375d20` (2021-06-21, "bluez5:
   add and use quirk for broken mic HW volume"). The only entry is `{ name = "Air 1 Plus",
   no-features = [ hw-volume-mic ] }`. There is no Sennheiser or MOMENTUM entry in 1.0.5 or
   `master` (`grep -i "momentum\|sennheiser" bluez-hardware.conf` → none).

5. **No later change.** `git log 1.0.5..HEAD -i -E --grep="VGM|mic(rophone)? (hw |hardware )?volume|hw.volume|hfp.*volume|volume.*hfp" -- spa/plugins/bluez5`
   lists only BAP volume work, HFP-HF (PipeWire as headset) volume (`1af1fc846`) and a
   `hw-volume` quirk for a Mackie speaker (`755aa967b`). Nothing changes the AG-side microphone
   gain path.

### INFERRED — applied to the three readings in issues.md
- 0.27 ≈ 4/15 (0.267) and 0.00 = 0/15 both fit a headset report (`AT+VGM=4`, `AT+VGM=0`) or a
  restore.
- **0.08 (route linear 0.000482) does not fit.** For a mono SCO source, a headset report sets
  the node volume to exactly `(g/15)^3`. The two nearest values are `(1/15)^3 = 0.000296` and
  `(2/15)^3 = 0.00237`. So the 22:55:59 value was **not** written by an `AT+VGM` report alone.
  It was written from software: a slider, WirePlumber's route-volume restore, or a client.
  PipeWire would then have sent `+VGM: 1` (`round(0.0784*15)=1`) to the headset.
- "Mute on": plausibly the headset's own announcement on receiving `+VGM: 0` (or `: 1`). This
  would happen after 0.00 was restored from WirePlumber's saved route volume on the HFP switch
  and pushed out by `rfcomm_ag_sync_volume`. It is equally possible that the headset sent
  `AT+VGM=0` itself; the code path in (1) would then save 0 as the "user" volume, and the value
  would come back on every later switch. **The RFCOMM capture at a switch decides which.** Look
  for the direction: `AT+VGM=` from the headset vs `+VGM:` from the host.

### Existing tracker items
- **pipewire#678 "Adjusting Bluetooth microphone hardware volume", opened 2021-02-05, still
  open.** Its description reports that headsets send `AT+VGM=XX` on startup, that the value
  persists across reconnects, and that on the headsets tried "the VGM value [does not]
  actually affect the volume of the recorded audio". This is the right existing thread for U2
  facts.
- Nothing found that matches "source volume forced to 0 / headset announces mute" (searched:
  `microphone volume HFP`, `bluetooth microphone mute`).

**Assessment U2:** the volume ↔ gain coupling is **deliberate design**, unchanged in `master`.
Two outcomes are possible:
- (a) If the capture shows the headset sending `AT+VGM=0` (or a low value) that PipeWire then
  keeps, the upstream fix is a quirk entry (`no-features = [ hw-volume-mic ]` for this headset).
  That is a one-line `bluez-hardware.conf` patch, and it needs the RFCOMM log as its evidence.
- (b) If the capture shows only host-sent `+VGM:` values, the cause is a stored low source volume
  (WirePlumber route state, or GNOME's slider). That is not a PipeWire bug.

What a report or patch needs: the btmon/RFCOMM excerpt with `AT+VGM`/`+VGM` and timestamps, the
`wpctl get-volume` before and after, and the WirePlumber route-state line for the handsfree input
route (read-only).

---

## U3 — default source stays on the internal microphone in handsfree

### VERIFIED — 0.4.17 behaviour

`git grep -n -B30 -A20 "prio += 20000 \* (N_PREV_CONFIGS + 1);" 0.4.17 -- modules/module-default-nodes.c`
(lines 287–315):

```
gint prio = prio_str ? atoi (prio_str) : -1;          /* priority.session */
...
if (name && def->config_value && g_strcmp0 (name, def->config_value) == 0) {
  prio += 20000 * (N_PREV_CONFIGS + 1);
} else if (name) {
  for (gint i = 0; i < N_PREV_CONFIGS; ++i) {
    ...
      prio += (N_PREV_CONFIGS - i) * 20000;
```

The *configured* default gets the largest bonus. A previously configured node gets less, and a
never-chosen node gets only `priority.session`. With the internal microphone configured, 2009 +
20000·(N+1) beats the headset's 2010 (+ at most N·20000 if it is in history). **The configured
default wins by design.** `priority.session` only breaks ties among nodes the user never chose.

### VERIFIED — 0.5 / master: same principle, recently made stricter

- `src/scripts/default-nodes/find-selected-default-node.lua:54–55`: the configured node gets
  `priority = 30000 + priority`.
- `src/scripts/default-nodes/state-default-nodes.lua:45–47` (history): `local priority = 20001 - i`,
  with the comment "priority.session is deliberately left out so that it cannot override the
  user's history".
- That last change is `481ecffb1c0fdb35f873df1e330b0c97c5f8d6c4`, 2026-09-21, "default-nodes:
  Rank stored nodes by stack position only", "See #1005". It is after 0.5.17, so not yet in a
  release.

Upstream is moving towards "the user's explicit choices always win". This is the opposite of
what U3's proposed report asks for.

### VERIFIED — what changed in 0.5 for Bluetooth microphones

WirePlumber NEWS (0.4.90, `NEWS.rst:791–795`):

> Bluetooth auto-switching is now implemented with a virtual source node. When an application
> links to it, the actual device switches to the HSP/HFP profile.

0.5.14 (`NEWS.rst:200–206`): the loopback source is "always created when a device supports both
A2DP and HSP/HFP", and was fixed so that users can set it "as default nodes" (#898, !792).

`src/scripts/monitors/bluez/create-loopback-node.lua:45–53` creates
`node.name = bluez_input.<dev>`, `media.class = Audio/Source`, `priority.session = 2010`. From
0.5.14 on, the headset microphone therefore exists as a selectable default source **even while
the headset is in A2DP**. Choosing it once makes it the configured default, and any capture then
switches the headset to HFP. On 0.4.17 the headset source only exists while in HFP, so it can
only be chosen after the switch. The U3 [log] entry shows the later choice then persisted.

### VERIFIED — existing setting that does what the operator asks

PipeWire's pulse layer has `module-switch-on-connect`:
- 1.0.5: `src/modules/module-protocol-pulse/modules/module-switch-on-connect.c`.
- `master`: `pulse-module-switch-on-connect.c`.
- It is commented out in `pipewire-pulse.conf.in:65` in 1.0.5:
  `#{ cmd = "load-module" args = "module-switch-on-connect" }`.

When a new sink or source node appears, it writes that node into `default.configured.audio.sink`
or `.source` (`master` lines 139–158). It skips internal PCI/ISA devices except HDMI sinks
(lines 116–123), a blocklist regex (default `hdmi`), and virtual nodes. An HFP switch creates a
new `bluez_input…` node, so this module would make the headset microphone the configured
default at each switch. **UNVERIFIED on this machine**: enabling it changes the operator's
configuration and saved defaults, so it is the operator's decision.

### Existing tracker items (VERIFIED via API)
- wireplumber#914 "Manual device selection in KDE tray permanently overrides WirePlumber
  priority configuration", **open**, 2026-02-16. It calls the behaviour "technically consistent,
  but highly confusing from a user perspective … no visible indication in the GUI that a
  persistent override has been set". This is the closest existing discussion; U3 is the same
  mechanism seen from GNOME with a Bluetooth headset.
- wireplumber#62 / #248 "Wrong device selected after reboot with new device connected", open
  since 2021-10-02 (label `area::device-management`). This is the opposite complaint (the new
  device wins) and shows the tension.
- wireplumber#1005 "Wrong fallback device selected when Bluetooth disconnects", closed
  2026-09-23, label `type::suggestion-request`. It led to `481ecff`.
- wireplumber#626 "Not able to use default microphone input when A2DP bluetooth headset
  connected since v0.5.0", closed 2024-03-27 (a loopback-era side effect, since fixed).

**Assessment U3:** **deliberate design** in 0.4.17 and in `master`, with no WirePlumber setting
for "a newly activated handsfree device takes the input". Options:
- (a) Use `module-switch-on-connect` (exists today).
- (b) On 0.5.14+, pick the headset's `bluez_input` once.
- (c) File a *suggestion*, not a bug: comment on wireplumber#914 or open a
  `type::suggestion-request`, arguing that choosing a handsfree *output* in a desktop panel
  should also select its microphone. That may equally belong to GNOME Settings, which sets
  only the sink when the user picks "Handsfree".

A report needs the [operator] part confirmed (a short consented recording), `wpctl status`
showing the "Default Configured Devices" block, and the `default-nodes` state lines (read-only).
It carries the original logs (see the rules above).

---

## U5 — which handsfree codec a switch lands on

### VERIFIED — 0.4.17 (`src/scripts/policy-bluetooth.lua`)

- State: `State("policy-bluetooth")`, key `saved-headset-profile:<device.name>`. It is enabled by
  default (`policy.lua.d/10-default-policy.lua:29 ["use-persistent-storage"] = true`, `:32
  ["media-role.use-headset-profile"] = true`).
- **When it saves:** only in `restoreProfile()`, i.e. when the last Communication stream ends.
  It saves the HFP profile that is current *at that moment*
  (`Log.info("Setting saved headset profile to: " .. cur_profile_name)`). A codec the user
  picked by hand during a call is saved the same way.
- **When it switches:** `switchProfile()` runs when a stream with `media.role = Communication`
  (or an app in `media-role.applications`) runs while the default sink is a `bluez_output.`
  node. It uses the saved headset profile if one exists, else
  `highestPrioProfileWithInputRoute()`, the highest `EnumProfile` priority among profiles
  listed by an Input route.
- **Default when nothing is saved:** with the 1.0.5 priorities (generic 1, CVSD 2, mSBC 3), that
  is **mSBC** whenever the headset negotiated mSBC support. No A2DP profile is listed on the
  input route unless the codec is duplex (1.0.5 `profile_direction_mask`).
- Separately, 0.4.17 `policy-device-profile` stores the device profile in `default-profile`, but
  only for `save = true` changes. The pulse layer always sets `save = true` on a user profile
  change: `pulse-server.c:4648 SPA_PARAM_PROFILE_save, SPA_POD_Bool(true)` in 1.0.5.
- The autoswitch sets profiles *without* `save`. So `save false` at 22:04 means the CVSD profile
  was set by the policy or by PipeWire itself (initial profile / codec fallback), not by a click
  in GNOME Settings. `save true` later means a user action through the pulse layer.

### VERIFIED — master (`src/scripts/device/autoswitch-bluetooth-profile.lua`)

- State renamed to `State ("bluetooth-autoswitch")` (line 607). **0.4 saved headset profiles are
  not carried over.**
- `device_profile_changed_hook` (558–602) saves *every* change to a headset profile, persisted
  only if `cur_profile.save` (line 587: `saveHeadsetProfile (device, cur_profile.name,
  cur_profile.save)`).
- `switchDeviceToHeadsetProfile` (148–196) uses the saved profile if it is still a headset
  profile, else `highestPrioHeadsetProfile`.
- Trigger: a client linking to the always-present BT loopback source, not a role or app
  allow-list.
- PipeWire `master` HFP priority: `priority = 1 + this->supported_codec_count - prio`
  (`bluez5-device.c:2434`), where `prio` is the position in the codec preference order. The
  best codec (LC3-SWB > mSBC > CVSD, when supported) gets the highest priority and the bare
  name `headset-head-unit`.
- There is also a new `bluetooth.profile-preference` setting (default `quality`,
  `wireplumber.conf:962–967`). It applies to A2DP auto profiles, not HFP.
- Relevant commits: `6a9e977` (2025-09-10, "Refactor and fix issues with saved profiles", first
  in 0.5.13), `2023807` (2026-03-18, "Ensure the saved profile is headset/non-headset before
  switching/restoring"), `2a519c7` (2026-09-11, "Cancel restore when headset is applied").

### INFERRED
- The 22:04 CVSD (`save` false) was either a saved-headset-profile of `-cvsd` applied by the
  autoswitch, or PipeWire's own fallback when the codec setup did not complete. `master`
  `backend-native.c:3303–3319` retries `+BCS` with the best codec, then "Failure, try falling
  back to CVSD". The first is consistent with the operator's revised reading ("picks what was
  last used"). A journal line from WirePlumber (`Setting profile of … to: …`) at the switch
  would tell them apart.
- With no saved entry, both 0.4.17 and `master` pick the highest-priority HFP codec. That is
  mSBC here, if the headset advertised it in `AT+BAC`. The "Open" test in issues.md would
  confirm this, but the code already predicts it. It can be run only with the operator's
  consent, since it removes a saved preference.

### Existing tracker items
- wireplumber#965 "autoswitch overrides user-selected HFP/HSP profile after capture ends",
  closed 2026-07-02, `type::suggestion-request`.
- wireplumber#1002 "Bluetooth autoswitch is overwritten by EnumProfile-triggered profile
  selection", closed.
- wireplumber#932 "HSP/HFP profile autoswitching fails in 0.5.14", closed.
- Nothing matching "picks the worst codec" was found. Consistent with the operator's withdrawal.

**Assessment U5:** **deliberate design** (sticky per-device choice, best codec by default), and
consistent between 0.4.17 and `master`. **Not reportable** unless a device with no saved entry
lands on CVSD while mSBC is supported. That would need the WirePlumber journal line, `EnumProfile`
output and the `AT+BAC`/`+BCS` exchange.

---

## U4 and U6 — PipeWire/WirePlumber involvement only

- **U4 (VERIFIED):** the route `profile` mismatch comes from the bluez5 plugin (see U1). It is
  not read by the pulse layer that GNOME talks to, so it cannot hide the Configuration row. The
  pulse layer does pass each port's `profiles` list (`collect.c:411`). In 1.0.5 the HFP ports
  list [3, 260, 261]; from 1.2.0 on, only codec profiles. The rest of U4 is GNOME Settings /
  libgnome-volume-control. No PipeWire change is indicated.
- **U6 (INFERRED):** the level meter stream sitting on "monitor of MOMENTUM 4" is a
  GNOME-created capture stream. The pulse layer turns `PA_STREAM_DONT_MOVE` into
  `PW_STREAM_FLAG_DONT_RECONNECT` (1.0.5 `pulse-server.c:1795/2064`), and WirePlumber 0.4.17
  `policy-node.lua:734` does not move such streams ("dont-reconnect, not moving"). Whether
  GNOME's stream uses that flag is not checked. The likely owner is GNOME, not PipeWire.

---

## Summary table

| item | code path (master) | changed after 1.0.5 / 0.4.17? | matching upstream issue | verdict |
|---|---|---|---|---|
| U1 generic entry | `bluez5-device.c` `build_profile`/`set_profile` | **removed** in `805e5cf9c` (1.2.0) | pw#2015, pw#953 (closed, related) | design in 1.0.5; fixed upstream; don't report |
| U1 route profile 3/2 | `build_route(..., this->profile)` | no (still enum) | none found | cosmetic inconsistency; optional small patch |
| U2 mic gain | `backend-native.c` AT+VGM / `sco_set_volume_cb`; `node_update_volume_from_transport` | no | **pw#678 (open)** | design; quirk patch only if capture shows headset-sent `AT+VGM=0` |
| U3 default source | WP `find-selected-default-node.lua`, `state-default-nodes.lua` | principle same; `481ecff` makes history stricter | **wp#914 (open)**, wp#62 (open), wp#1005 | design; suggestion, not bug; `module-switch-on-connect` exists |
| U5 HFP codec on switch | WP `autoswitch-bluetooth-profile.lua` | reworked (0.5.13+); state file renamed | wp#965, wp#1002 (closed) | design; default = best codec |
