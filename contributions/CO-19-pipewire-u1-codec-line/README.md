# CO-19 - PipeWire U1: codec line in Hands-free mode (Ubuntu 24.04 stable update)

State: **prepared, not filed** (2026-10-28). Nothing committed, pushed, uploaded or sent.

Problem (`docs/issues.md` U1): in Hands-free mode PipeWire 1.0.5 offers a
codec-less profile "Headset Head Unit (HSP/HFP)" beside the codec profiles; it
is the first line in GNOME Settings, so the codec cannot be seen or changed
there. Fixed upstream by 805e5cf9c in 1.1.81 / 1.2.0.
Scope: Ubuntu's Launchpad only. PipeWire upstream is not involved (it forbids
tool-written merge requests and issues).

## Result in one block

- Backport: HFP/HSP part of 805e5cf9c, hand-adapted, one file
  (`spa/plugins/bluez5/bluez5-device.c`), 42 insertions, 29 deletions.
  The upstream commit does not apply to 1.0.5 (7 of 21 hunks fail: needs the BAP
  rework and LC3-SWB commits). No follow-up commit exists upstream.
- Package: pipewire `1.0.5-1ubuntu3.3` (current noble-updates/security) ->
  `1.0.5-1ubuntu3.4`; patch `debian/patches/bluez5-show-only-codec-profiles-also-for-HFP-HSP.patch`
  (DEP-3, Origin = upstream commit, `Bug-Ubuntu: .../NNNNNNN` placeholder).
- Build in ubuntu:24.04 container: success; meson test 22 ok / 0 fail; the
  plugin binary no longer contains the codec-less description. No unit test
  covers the bluez5 profile list.
- Still to do: laptop test (below), a Launchpad bug number in 3 places
  (`NNNNNNN` in the patch header, the changelog and `lp-report.md`),
  review by the operator, then file (SRU: bug + debdiff attached).

## Files

- `lp-report.md` - Launchpad text in SRU format (draft).
- `pipewire_1.0.5-1ubuntu3.3_1.0.5-1ubuntu3.4.debdiff` - the debdiff
  (changelog + patch + series). Note: it still contains the `NNNNNNN` placeholder.
- `results-2026-10-28.md` - commands and outputs. The full build log (1.6 MB) is kept locally as `tmp/co19-pipewire/build.log`, not in git.
- `log.md` - decisions and open points.
- Built packages (not in this folder): `/root/exp/qca9377-bt-hang/tmp/co19-pipewire/out/`
  (`libspa-0.2-bluetooth_1.0.5-1ubuntu3.4_amd64.deb`, `.dsc`, `.debian.tar.xz`);
  all 22 .deb were in the container only. Scripts and sources in
  `/root/exp/qca9377-bt-hang/tmp/co19-pipewire/`.

## What the laptop must show (test plan for the operator)

Needs a headset in Hands-free mode (the Shure AONIC 50 or the MOMENTUM 4 would
do; one with mSBC shows both lines). The laptop has 1.0.5-1ubuntu3.3.
Only the plugin changed, so only `libspa-0.2-bluetooth` needs installing
(`/root/exp/qca9377-bt-hang/tmp/co19-pipewire/out/libspa-0.2-bluetooth_1.0.5-1ubuntu3.4_amd64.deb`),
then `systemctl --user restart pipewire wireplumber pipewire-pulse`.
Reinstall 1.0.5-1ubuntu3.3 to go back. This touches the laptop's audio, so
it is the operator's step.

BEFORE (with 3.3 installed), headset connected and switched to Hands-free:
1. `pactl list cards` (card section of the headset), Profiles list. Expect an
   entry named `headset-head-unit` described "Headset Head Unit (HSP/HFP)"
   (no codec) plus `headset-head-unit-cvsd` and `headset-head-unit-msbc`.
   Also `pw-cli enum-params <card id> EnumProfile` for the same list.
2. GNOME Settings > Sound: screenshot of the codec/profile list in Hands-free
   (first line = the codec-less one).
3. Note U1's behaviour: selecting the first line gives no codec information /
   does not stick.

AFTER (with 3.4 installed, session services restarted, headset reconnected,
Hands-free selected):
4. `pactl list cards`: no entry described "Headset Head Unit (HSP/HFP)" without
   a codec. On an mSBC-capable headset: `headset-head-unit` described
   "(HSP/HFP, codec mSBC)" and `headset-head-unit-cvsd` "(... codec CVSD)".
   On a CVSD-only headset: one entry, `headset-head-unit`, codec CVSD.
5. `pw-cli enum-params <card id> Profile` (current profile) names the codec in
   use; GNOME Settings shows it on the selected line.
6. Select each codec line in GNOME Settings: the profile changes, the SCO link
   is set up again with that codec (journal: `journalctl --user -u pipewire`,
   `bluetoothctl`/btmon not required), audio plays, microphone records.
7. `pactl set-card-profile <card> headset-head-unit` selects the best codec.
8. Regression: A2DP -> Hands-free -> A2DP three times; disconnect and reconnect
   in Hands-free; start a recording application while on A2DP (U14 path) and
   see the switch to Hands-free end on a codec line.
9. Record the outputs as `results-<date>.md` here (commands and outputs).

Not covered even by that test: HSP-only headsets, oFono and hsphfpd backends.

## Risks to weigh before filing

- Name semantics: `headset-head-unit` now = best codec (matches A2DP).
- Hand adaptation of upstream; reviewers may ask for the full upstream
  series instead (larger, includes BAP rework). Reasons for the small version
  are in `results-2026-10-28.md` section 2/3.
- The `Author:` in the DEP-3 header is the upstream author (Pauli Virtanen);
  the changelog trailer uses the operator's name and the gmail address - to be
  confirmed by the operator before upload.
