# Launchpad report draft (Ubuntu SRU format) - NOT FILED

Target: Launchpad, Ubuntu source package `pipewire`, series noble (24.04).
Title: Hands-free mode lists a codec-less "Headset Head Unit (HSP/HFP)" profile; the codec cannot be seen or changed in GNOME Settings

Fixed upstream in PipeWire 1.1.81 / 1.2.0 by commit
805e5cf9c115e3d0498f78e9e00e3ae93178e47d ("bluez5: show only codec profiles
also for HFP/HSP"), with its preceding commit f142c0a5b0286bd8975bb67e57e0f06138e05b17
("bluez5: ensure transport->codec is set also for HSP"). Ubuntu 24.04 ships
1.0.5 (1.0.5-1ubuntu3.3 in noble-updates). The development release (27.04,
pipewire 1.6.8-1ubuntu4), 26.10 (1.6.8-1ubuntu4) and 26.04 (1.6.2) contain both.

## [Impact]

With an mSBC-capable Bluetooth headset connected in Hands-free (HSP/HFP)
mode, PipeWire 1.0.5 offers three profiles for the headset (a CVSD-only
headset: two, the codec-less one and CVSD): "Headset Head Unit (HSP/HFP)"
without a codec, and "Headset Head Unit (HSP/HFP, codec CVSD)" and
"... codec mSBC". The codec-less entry is not a real choice: it resolves to
whichever codec the link happens to use. It is the first line of the
profile/codec list in GNOME Settings (Sound), so the user sees a line that
does not say which codec is in use, cannot tell the active codec, and
cannot reliably select a codec from that line (selecting it from the input
side does not stick and falls back to a codec-specific entry). The user
cannot see or change the codec in hands-free mode from the first line.

The fix lists only profiles that name a codec, as PipeWire already does for
A2DP, and gives the best supported codec the base profile name
`headset-head-unit`, so selecting that name still works.

## [Test Plan]

Hardware needed: any Bluetooth headset with a microphone that supports HFP
(ideally one that also supports mSBC, to see both codec lines).

1. On an up-to-date noble system (pipewire 1.0.5-1ubuntu3.3), connect the
   headset and switch it to Hands-free / Headset mode in Settings > Sound.
2. Record the profile list of the card:
   `pw-cli enum-params <card id> EnumProfile` (or `pactl list cards`, section
   Profiles). Expected before the fix: a profile `headset-head-unit` with
   description "Headset Head Unit (HSP/HFP)" (no codec) besides
   `headset-head-unit-cvsd` and `headset-head-unit-msbc`.
   In GNOME Settings, open the codec/profile list: the first line is the
   codec-less entry.
3. Install the pipewire packages / `libspa-0.2-bluetooth` from -proposed
   (1.0.5-1ubuntu3.4), restart the user session (or log out and in), reconnect
   the headset, switch to Hands-free again.
4. Expected after the fix: no description "Headset Head Unit (HSP/HFP)"
   without a codec in `EnumProfile`; only "Headset Head Unit (HSP/HFP, codec
   mSBC)" (name `headset-head-unit`) and "... codec CVSD" (name
   `headset-head-unit-cvsd`) on an mSBC-capable headset, only the CVSD line
   on a CVSD-only headset. The codec lines in GNOME Settings can be
   selected; the current profile (`pw-cli enum-params <id> Profile`) names
   the codec in use, and switching between the lines changes the codec
   (`pactl list cards` shows the new active profile; the SCO link is set up
   again).
5. `pactl set-card-profile <card> headset-head-unit` still selects the
   headset profile (best codec).
6. Regression checks: switch A2DP <-> Hands-free several times; CVSD <->
   mSBC both ways, checking the codec the transport really uses (PipeWire
   debug log "codec=") and not only the profile label; the microphone works
   in Hands-free; the headset survives disconnect and reconnect with
   Hands-free as the saved profile, including a profile saved before the
   update as `headset-head-unit-msbc`.

(Results of the test on the laptop to be added here before the upload to
-proposed is requested.)

## [Where problems could occur]

The change is confined to `libspa-0.2-bluetooth`: profile enumeration and
active-codec/node handling for HSP/HFP in `spa/plugins/bluez5/bluez5-device.c`,
and the initial codec of native-backend HSP transports in
`spa/plugins/bluez5/backend-native.c`; A2DP and BAP handling is unchanged.

- The profile named `headset-head-unit` now means "the best supported
  codec" instead of "no codec". Saved user state or scripts that refer to
  `headset-head-unit` keep working and select the best codec; a script that
  relied on that name meaning "any/unspecified codec" now gets mSBC where
  the headset supports it.
- On an mSBC-capable headset the mSBC profile is now named
  `headset-head-unit`; the name `headset-head-unit-msbc` is no longer
  generated. A saved setting or script that selects
  `headset-head-unit-msbc` no longer matches a profile; what the session
  manager then selects is part of the test plan (step 6).
- A headset that only supports HSP (no HFP codec negotiation) must still get
  a profile: CVSD is therefore always listed without asking the backend, and
  the first patch (f142c0a5b) gives native-backend HSP transports the CVSD
  codec, which 1.0.5 left unset. Without it the active profile of such a
  headset would carry no valid codec. A regression here would show as an
  HSP-only headset with no Hands-free profile or no audio in it.
- If a codec switch fails, PipeWire logs "failed to switch codec" and stays
  in Hands-free; the profile shows the codec of the transport present
  afterwards, or falls back to the CVSD label when no transport remains,
  which does not mean a CVSD link is active. This path is the one 1.0.5
  already has. A regression
  would show as a wrong profile line selected in the UI or a headset that
  stays on A2DP when Hands-free is chosen.
- Other desktop components (WirePlumber 0.4.x policy, GNOME Settings,
  pavucontrol) read the profile list. WirePlumber 0.4.17 (noble) picks
  profiles by index or by saved name from the list and does not refer to
  the codec-less entry; a saved name `headset-head-unit` now resolves to
  the best-codec profile. Only the test above on a real headset covers
  the whole chain.

## [Other Info]

- Upstream commit: https://gitlab.freedesktop.org/pipewire/pipewire/-/commit/805e5cf9c115e3d0498f78e9e00e3ae93178e47d
  (in 1.1.81, 1.2.0 and later). No upstream follow-up commit corrects it
  (searched the history of `bluez5-device.c`, `Fixes:`/revert, up to 1.6.10).
- The upstream commit does not apply to 1.0.5 as is (7 of 21 hunks fail):
  it depends on the BAP rework (a15416994) and LC3-SWB support (fe412784a).
  The second patch is a backport of its HFP/HSP part, adapted for 1.0.5 (one
  file, 42 insertions and 29 deletions); the A2DP/BAP cleanups of the upstream
  commit are left out because they are not needed for this behaviour. The
  first patch is upstream f142c0a5b unchanged (it applies with offsets).
- Build: the package builds in a clean ubuntu:24.04 container; there is no
  unit test for the bluez5 profile list in PipeWire 1.0.5.
- Debdiff: `pipewire_1.0.5-1ubuntu3.3_1.0.5-1ubuntu3.4.debdiff` (attached).
- Related, separate: none filed. LP #2162010 is a different Bluetooth
  hands-free problem (AT+CCWA).
