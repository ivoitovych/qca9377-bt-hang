# CO-19 log

## 2026-10-28

- Read upstream 805e5cf9c (21 hunks, one file). Searched `bluez5-device.c`
  history up to 1.6.10 for Fixes/revert: none. The GitLab issue search for
  `headset-head-unit` shows no report about the commit (listing in
  `/root/exp/qca9377-bt-hang/tmp/co19-pipewire/issues-search.json`).
- Dry-run of the commit on 1.0.5: 7 of 21 hunks fail (BAP rework a15416994,
  LC3-SWB fe412784a, cleanups 65f594c6a missing). Decision: hand-port the
  HFP/HSP behaviour only; A2DP/BAP part left out (not needed, would pull
  the BAP series).
- Kept from the commit: no codec-less profile; base name `headset-head-unit`
  for the best codec (needed so saved state / `bluez5.profile` / the command
  line still resolve); CVSD always listed (HSP-only devices: the native
  backend answers -ENOTSUP to every codec query); current profile never has
  codec 0.
- Checked WirePlumber 0.4.17 `policy-bluetooth.lua`: no use of the codec-less
  entry.
- Source: noble-updates/security 1.0.5-1ubuntu3.3; sha256 of the debian
  tarball and orig tarball verified against the .dsc. The .dsc signature was
  not verified (no keyring in the container).
- Launchpad search (pipewire, noble) for an existing bug about the codec-less
  profile: none (LP #2162010 is another HFP problem).
- Build and tests: see `results-2026-10-28.md`. Container: ubuntu:24.04
  throw-away (`--rm`); host untouched (no packages, no audio/Bluetooth action).
- Open: Launchpad bug number; laptop test; the operator's name/address for the
  changelog trailer; whether to try the oFono/HSP-only paths.
