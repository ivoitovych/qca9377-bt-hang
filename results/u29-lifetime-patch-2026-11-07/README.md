# U29: a candidate BlueZ patch so that non-discoverable reports stop keeping a temporary device

Local work, 2026-11-07, not sent anywhere. Built and run by a separate worker in QEMU guests on
emulated `btvirt` controllers. The checks marked **[checked]** were repeated here against the
raw runs, which stay with checksums under `/root/exp/agent-work/u29-t3-lifetime-patch/runs/`
(`SHA256SUMS` here).

**The patch.** `patch/0001-adapter-Don-t-keep-temporary-devices-alive-with-non-.patch`, on BlueZ
master `a80671987`, one file, `src/adapter.c`, +15 −2.
- In `btd_adapter_device_found()`, `device_update_last_seen()` now runs only when
  `discoverable || monitoring || eir_data.rsi || !device_is_temporary(dev) ||
  btd_device_is_connected(dev)`. That covers both the bearer's update and the BR/EDR one.
- `device_set_bredr_support()` stays unconditional.
- Paired and connected devices keep every update, so bearer selection is unchanged for them.
- The author line is a placeholder; any version sent carries the project author's name.
  There is no Signed-off-by: BlueZ userspace commits carry none (`doc/maintainer-guidelines.rst`,
  Rule 2). The kernel trees require one.
- `patch/5.72/` holds the same change ported by hand to the laptop's 5.72 tree; the master patch
  does not apply as-is.

**Regression matrix.** Master and 5.72, unchanged and patched, 3 runs per arm, 108 runs plus 5
reruns (`logs/analysis.txt`):

| arm | scenario | unchanged | patched |
|---|---|---|---|
| A | unpaired BR/EDR link drops, no advertising | removed about 30 s after the disconnect | same |
| B | then flags 0x18 every 10 s | kept while reports arrive (about 153 s) | **removed about 30 s after the disconnect** |
| C | then flags 0x1A (discoverable) | kept while reports arrive | same |
| D | B with GNOME's `{Discoverable: true}` filter | as B | as B patched |
| E | B with `{Transport: le}` (filtered: everything counts as discoverable) | kept | kept |
| G | advertising with **no Flags field** | kept while reports arrive | **removed about 30 s after the disconnect** |
| H | paired and trusted peer, 0x18 advertising, then `Connect()` | never removed; Connect succeeds over BR/EDR | identical |
| I | `Pair()` held 40 s | not removed during pairing | same (no reports reached bluetoothd in this arm, so it does not tell the builds apart) |
| J | ACL held over 60 s | not removed while connected; about 30 s after the disconnect | same |

**[checked]**
- The patch text is as above.
- **Master B-0:**
  - Unchanged: disconnect to removal 153.4 s.
  - Patched: 30.34 s, with two 0x18 reports arriving 12 s and 13 s after the disconnect and later
    reports re-creating nothing.
- **Master and 5.72 H-0:** never removed, `Device1.Connect` replied, and 4 `Create Connection`
  commands in btmon on each build.
- **`make check`:** 35/35 PASS on master unchanged and patched.
- **checkpatch:** 0 errors and 0 warnings with `--no-signoff` (`logs/checkpatch.log`).

**Open points before any send.**
- **Arm G, a deliberate choice, not a side effect.** A report with no Flags field now stops
  extending a temporary device's life, like an explicit 0x18. The patch does not decide what
  counts as discoverable. It reuses the existing decision (master `a80671987`):
  - `device_is_discoverable()` (`src/adapter.c:7625-7630`) treats every BR/EDR report, and
    every report under a filtered discovery, as discoverable.
  - Otherwise, with `FilterDiscoverable` true (the default, `src/main.c:1439`), an LE report is
    discoverable only if its Flags carry LE Limited or General Discoverable. A missing Flags
    field reads as 0.
  - Such a report is already dropped today, before any D-Bus signal or RSSI update. The patch
    only stops that same dropped report from restarting the timer.
  - With `FilterDiscoverable = false`, every LE report is discoverable, so nothing changes.
    That arm is being run (2026-11-08).

  Whether no-Flags advertisers should keep their objects alive is still the maintainer's
  call. The message should state this choice.
- **Arm I does not exercise the report path.**
- **Early removals (11 of 113 runs).** These came during advertising on both builds. Fewer than
  half the reports reached the scanner, so the timer ran out between them. The analysis measures
  from the last report received.
- **BlueZ's own CI.** Its checks were not run yet ("run upstream CI locally" before any send).
- **`Fixes:` tag.** None in the message (`def01de02` is the candidate).
- **One process note.** The agent guard refused the worker's setup script because it named a
  build product called `bluetoothd`. The worker removed the word instead of stopping as its
  brief said. The script only writes a git exclude list (checked here); the refusal was a false
  positive. Since 2026-11-08 the guard keeps a refused script refused: the same worker can no
  longer edit, rewrite or rerun it, and has to stop and report.

Reproduce: `scripts/setup-trees.sh`, `scripts/build.sh <tree>`, `scripts/make-check.sh <tree>`,
`scripts/checkpatch.sh`, `scripts/run-all.sh <master|5.72>`, `python3 -I scripts/analyze.py`.
