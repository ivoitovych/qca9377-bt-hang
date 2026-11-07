# CO-19 - PipeWire U1: codec line in Hands-free mode (Ubuntu 24.04 stable update)

State: **prepared, not filed** (2026-10-28). Nothing filed, uploaded or sent.
v2 (2026-10-28, after the outside reviews in `reviews-2026-10-28.md`): adds
upstream f142c0a5b as a first patch (HSP transports get the CVSD codec; without
it an HSP-only headset's active profile had an invalid codec under our port).

Problem (`docs/issues.md` U1): in Hands-free mode PipeWire 1.0.5 offers a
codec-less profile "Headset Head Unit (HSP/HFP)" beside the codec profiles; it
is the first line in GNOME Settings, so the codec cannot be seen or changed
there. Fixed upstream by 805e5cf9c in 1.1.81 / 1.2.0.
Scope: Ubuntu's Launchpad only. PipeWire upstream is not involved (it forbids
tool-written merge requests and issues).

## Result in one block

- Patch 1: upstream f142c0a5b ("ensure transport->codec is set also for HSP",
  `backend-native.c`, 2 lines), unchanged; it precedes 805e5cf9c upstream and
  was missing from v1.
- Patch 2: backport of the HFP/HSP part of 805e5cf9c, adapted for 1.0.5, one
  file (`spa/plugins/bluez5/bluez5-device.c`), 42 insertions, 29 deletions.
  The upstream commit does not apply to 1.0.5 (7 of 21 hunks fail: needs the BAP
  rework and LC3-SWB commits). No later fix of it exists upstream.
- Package: pipewire `1.0.5-1ubuntu3.3` (current noble-updates/security) ->
  `1.0.5-1ubuntu3.4`; patches `debian/patches/bluez5-ensure-transport-codec-is-set-also-for-HSP.patch`
  and `debian/patches/bluez5-show-only-codec-profiles-also-for-HFP-HSP.patch`
  (DEP-3, Origin = upstream commit, `Bug-Ubuntu: .../NNNNNNN` placeholder).
- Ubuntu's development release is 27.04 (pipewire 1.6.8-1ubuntu4): it has both
  commits (Launchpad query `scripts/ubuntu-series-versions.py`, 2026-10-28).
- Build in ubuntu:24.04 container, v1 and again v2 (both patches applied;
  `results-2026-10-28.md` §5a): success; meson test 22 ok / 0 fail; the
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
Only the plugin changed, but `libspa-0.2-bluetooth` depends on
`libspa-0.2-modules (= 1.0.5-1ubuntu3.4)` exactly (`dpkg-deb -f … Depends`), so
both rebuilt packages go in together, from
`/root/exp/qca9377-bt-hang/tmp/co19-pipewire/out/`:
simulate first with `apt-get -s install ./libspa-0.2-bluetooth_1.0.5-1ubuntu3.4_amd64.deb ./libspa-0.2-modules_1.0.5-1ubuntu3.4_amd64.deb`
(it must change only those two packages), then install the same way without
`-s`, then `systemctl --user restart pipewire wireplumber pipewire-pulse`.
Never `--force-depends`. To go back, reinstall both at `1.0.5-1ubuntu3.3`
(`apt-get install --allow-downgrades libspa-0.2-bluetooth=1.0.5-1ubuntu3.3 libspa-0.2-modules=1.0.5-1ubuntu3.3`;
without `--allow-downgrades` apt refuses), then the same
`systemctl --user restart pipewire wireplumber pipewire-pulse` (or log out and in): replacing the
packages does not replace code already loaded. The procedure was run in a noble container
(install executed, upgrade and rollback simulated; `results-2026-10-28.md` §5b).
This touches the laptop's audio, so it is the operator's step.

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
8a. Before the update, save an mSBC selection (`headset-head-unit-msbc`);
   after it, reconnect and record which profile the session manager selects
   when restoring that old name (it is no longer generated: the mSBC profile
   is now `headset-head-unit`), and whether audio and microphone work.
   For CVSD <-> mSBC check the codec the transport really uses
   (`PIPEWIRE_DEBUG=spa.bluez5*:4` journal, "codec="), not only the label.
   If a codec switch fails, record the log line ("failed to switch codec")
   and what is shown afterwards, before blaming the port.
9. Record the outputs as `results-<date>.md` here (commands and outputs).

Not covered even by that test: HSP-only headsets (patch 1 is reasoned from the
source, not tested on one), oFono and hsphfpd backends.

## Risks to weigh before filing

- Name semantics: `headset-head-unit` now = best codec (matches A2DP).
- Hand adaptation of upstream; reviewers may ask for the full upstream
  series instead (larger, includes BAP rework). Reasons for the small version
  are in `results-2026-10-28.md` section 2/3.
- The `Author:` in the DEP-3 header is the upstream author (Pauli Virtanen);
  the changelog trailer uses the operator's name and the gmail address - to be
  confirmed by the operator before upload.
