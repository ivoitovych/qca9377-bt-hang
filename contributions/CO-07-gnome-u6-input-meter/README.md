# CO-07 — U6: GNOME input meter fix for Ubuntu

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
