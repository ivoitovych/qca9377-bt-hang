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

### Outside reviews (`reviews-2026-10-28.md`): reviewer 3's HSP-only path is real; v2

- Stock 1.0.5's native HSP branch creates the transport without a codec
  (`backend-native.c:2228-2234`, `_transport_create()` at 202-235 sets none;
  `spa_bt_transport_create()` is `calloc()`, `bluez5-dbus.c:2732`), so
  `t->codec` is 0. `get_hfp_codec_id(0)` returns `SPA_ID_INVALID`
  (`bluez5-device.c:255-264`).
- Stock 1.0.5 hid this with `if (t->profile == SPA_BT_PROFILE_HSP_HS)
  this->props.codec = 0;` (pristine `bluez5-device.c:1091-1094`); our port, like
  805e5cf9c, removed it (ported line 1093 is unconditional), so the CVSD
  fallback at 1100 never ran for HSP-only headsets: `props.codec` stayed
  `SPA_ID_INVALID`. A regression we would have introduced.
- Upstream fixed it first: `f142c0a5b` "bluez5: ensure transport->codec is set
  also for HSP" (Pauli Virtanen), committed together with 805e5cf9c
  (`git log -8 805e5cf9c`: f142c0a5b, 597116bb2, 805e5cf9c, all 2024-02-03
  16:10:12). `git merge-base --is-ancestor f142c0a5b 1.0.5` → exit 1 (not in
  1.0.5). It applies to 1.0.5 with offsets (`patch --dry-run`: hunk 1 at 222,
  offset -1; hunk 2 at 2232, offset -68). Upstream 1.2.0 has the CVSD line in
  the HSP branch; current upstream passes `HFP_AUDIO_CODEC_CVSD` to
  `rfcomm_new_transport()`.
- Its effect in 1.0.5: every other read of `t->codec` compares with mSBC or
  serves labels/lookups (`grep -rn 't->codec\b\|transport->codec\b'`), so HSP
  audio paths are unchanged; the codec is reported as CVSD.
- Reviewer 3's suggested local fallback is not taken: upstream's own commit is
  the fix. v2 = f142c0a5b (unchanged, first in the series) + the port.
- Install plan (reviewers 2, 5) confirmed: `dpkg-deb -f
  libspa-0.2-bluetooth_1.0.5-1ubuntu3.4_amd64.deb Depends` → `libspa-0.2-modules
  (= 1.0.5-1ubuntu3.4), …`. The build now keeps both packages; the README
  procedure simulates with `apt-get -s` and rolls back both.
- Failed codec switch: the port keeps 1.0.5's `codec_switched()` (props.codec
  → 0, profile stays HSP/HFP, `emit_nodes()` → the transport's codec or CVSD).
  The report's "keeps the existing link" was not established; replaced by that.
- Development release (`scripts/ubuntu-series-versions.py`, Launchpad): current
  series `tenacious` 27.04, pipewire 1.6.8-1ubuntu4; 26.10 1.6.8-1ubuntu4;
  26.04 1.6.2-1ubuntu1.x. All contain both commits.
- Wording: "Cherry-pick" → "Backport … adapted for 1.0.5" (changelog); scope
  sentence names both files; README "not filed".
- The v1 build is kept in `tmp/co19-pipewire/out-v1/` (with its build log).
