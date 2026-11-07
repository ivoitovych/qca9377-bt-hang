# CO-08 references

**Our record:**
- `docs/issues.md`, U10.
- `docs/STATUS.md`, the U10 row.
- `evidence/exhibits/030-a2dp-dropout-without-controller-involvement.md`.

**Captures** (raw, git-ignored, real addresses): `bt-20261011-001745` to `bt-20261011-004946`
in `archive/bt-trace/`. Read them with `scripts/sbc-frame-levels.py`.

**Upstream:**
- PipeWire `spa/plugins/bluez5/bluez-hardware.conf` (master), with its `no-features = [ sbc-xq ]`
  entries.
- The tree is in `cache/pipewire-upstream`.
