# CO-07 — U6: GNOME input meter fix for Ubuntu

> **Note of 2026-11-16 (newer than "State: idea" below):** merged with CO-32. The six commits
> apply to GNOME Settings 46.7 and were built for noble on 2026-11-14 (`build-20261114/`, with
> CO-32's WirePlumber fix; the packages' own tests unchanged); the functional check needs the
> laptop's audio. Next: CO-32 first, then Handsfree to A2DP three times with the panel open.

> **Current state, 2026-11-12** (the index `../README.md` is the current record): **merged with
> CO-32** (2026-11-01, `../research-2026-11-01/`). GNOME Settings 46.7 does re-target the meter, and
> Ubuntu's 2-second WirePlumber patch (`U19`) then destroys it, so on Ubuntu the GNOME 47 fix alone
> would not help. CO-32 first; then the Handsfree → A2DP test with the panel open. Part of the
> headset session (`results/laptop-only-work-2026-11-11/headset-session/`).

**State:** idea. One reading is missing before a request.

**Target:** Ubuntu 24.04's `gnome-control-center` (46.7), through a Launchpad bug asking for
the upstream fix.

**Comes from:** `U6`: GNOME Settings' input level meter does not follow the selected input
device.

## The facts

- **Upstream fix:** the 2024-03-07 series `215289935`, `a74bc5a84`, `bf6f72278`, `afec106a8`,
  `3aeb837cb`, plus `0da10f03a` (all in `panels/sound/`), first in GNOME 47.0.
- **Cause in 46.7** (`cc-sound-panel.c`, `input_device_update_cb`): the input meter's stream
  is retargeted only while it holds no stream.
- **Ubuntu noble:** `1:46.7-0ubuntu0.24.04.6` in updates (2026-09-02); nothing newer.
- **Launchpad:** the only match is #1923602, which is unrelated.

## Next

1. One recorder reading with the Sound panel open. 46.7 should show one capture stream; 47
   would show two.
2. Draft the Launchpad bug quoting the six commits.
3. The operator files it.
