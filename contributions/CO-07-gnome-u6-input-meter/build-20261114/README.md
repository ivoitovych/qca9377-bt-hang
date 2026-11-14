# CO-07 + CO-32 built for noble (2026-11-14; nothing installed or filed)

The two halves of the Sound panel's dead input meter, as noble packages. Copied from
`/root/exp/agent-work/lane5-status-stable-20261114/task5/` (fetched pages and the build logs
left there). Both newest in noble on 2026-11-14 08:22 UTC, nothing in proposed.

- **CO-32 / U19, WirePlumber** `0.4.17-1ubuntu4.1` → `4.2`
  (`wireplumber_0.4.17-1ubuntu4.1_0.4.17-1ubuntu4.2.debdiff`, `patches/`): the one-line fix from
  `docs/issues.md` U19 — `was_handled` is set only when the stream is actually linked, inside
  `if skip_this_target == false`, after Ubuntu's own LP #2122640 patch.
- **CO-07 / U6, gnome-control-center** `1:46.7-0ubuntu0.24.04.6` → `.7`
  (`gnome-control-center_…_1-46.7-0ubuntu0.24.04.7.debdiff`, `patches-gcc/`): the six upstream
  commits (`215289935`, `a74bc5a84`, `bf6f72278`, `afec106a8`, `3aeb837cb`, `0da10f03a`, all in
  47.0) in upstream's order, which matters: they apply in that order with fuzz 0 and not in
  another. **First build of these commits.**
- **Built in noble containers, stock and patched, all four exit 0.** The packages' own meson
  tests: WirePlumber 27 of 27 OK on both; gnome-control-center 5 of 5 OK on both (none of its
  tests touches the Sound panel). Checked on copy from the build logs (`Ok: 27` ×2, `Ok: 5` ×2,
  `Fail: 0`) before they were left out.
- **Not tested functionally:** both need the laptop's real audio stack. The 5-minute check,
  with a headset that offers both profiles: install both packages; Settings → Sound with the meter
  on the laptop microphone; switch the headset Handsfree → A2DP three times; the meter should stay
  alive (and the user journal should no longer show `CREATE_RECORD_STREAM` followed within ~1 s by
  `target not found … destroy node` and `ERROR … error:25`); revert by reinstalling the stable
  versions. Per U19, the GNOME patches alone do not help on Ubuntu while WirePlumber destroys the
  meter: install both.

The changelog trailers name the operator; Launchpad numbers are placeholders. The operator
decides the laptop test and any filing.
