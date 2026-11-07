# CO-21: btusb picks USB alternate setting 0 while a SCO link is up

**State (2026-11-01):** confirmed in source and by a model test; a candidate fix compiles and
passes the model; never loaded, not sent. **Outside review the same day: not ready.** The core
sends the link-up notification also for a failed setup (`hci_event.c:5257-5278` at
`42b8c2d72926`), so the candidate alone puts a surviving CVSD call on the transparent setting
after a failed mSBC second setup; and it keeps the last link-up's mode with mixed codecs
(`../research-2026-11-01/README.md`, CO-21 revised row).

**Redesign (2026-11-01, evening; local, not sent, never loaded):** the alternate setting is
derived from the SCO links that are up. Two patches on bluetooth-next `42b8c2d72926`
(`/root/exp/agent-work/co21-redesign-20261101/patches-v0/`, checkpatch `--strict` clean, W=1
builds x86_64 and i386 with 0 warnings):
1. core: a `conn->air_mode` field set from the Synchronous Connection Complete event of a link
   that came up, and a helper counting the up SCO links per air mode (+33 lines);
2. btusb: the worker picks the setting from those counts (CVSD only: the existing table; any
   transparent: the transparent setting; none: stop), notify only schedules it (+16/−10,
   `Fixes: baac6276c0a9`).

The event's air mode is used, not `conn->setting`: `conn->setting` is written only for
outgoing setups, not stored on deferred accept, and overwritten by a second `connect()` on a
live link before it fails with EBUSY (the same path as CO-02's wrong-voice reuse).

**Extended model, 20 scenarios** (failed second setup, mixed codecs either order, coalesced
notifications, cancel and retry, incoming link, overwritten setting; `out/model2-v1-summary.txt`):

| variant | right |
|---|---|
| original | 5/20 |
| original + Hitalo Souza's 6/6 | 7/20 |
| candidate | 16/20 |
| candidate + 6/6 | 17/20 |
| redesign (with or without 6/6) | 20/20 |
| redesign keyed on `conn->setting` | 17/20 |

"Any transparent link wins" is a chosen rule, not a measured hardware fact; each failure of the
candidate also has a wrong step that does not depend on it.

**Upstream state of 6/6** (patchwork API, 2026-11-01): still `new`; the only human reply on the
series is the maintainer's on the cover letter (2026-10-09: Sashiko flags more problems); no v4;
nothing of it in bluetooth-next. The redesign does not need it. A short note asking whether it
will be resent is drafted in the work area; posting it is the operator's decision.

**Laptop test, if wanted:** the new field changes the connection struct, so `bluetooth.ko` and
`btusb.ko` must be built and installed together (`updates/` + `depmod` + a cold boot).

**Target:** Linux kernel, `drivers/bluetooth/btusb.c` (`btusb_notify()`, `btusb_work()`).

**The defect** [source, bluetooth-next `42b8c2d72926`]: `btusb_notify()` takes the air mode from
whatever event changed the SCO count, and `btusb_work()` falls back to alt 0 for anything that is
not CVSD or transparent. Alt 0 has no isochronous bandwidth on this device.
- **Two SCO links:** when one goes down, the other is switched to alt 0. This is the case
  recorded in the reviews (RV3).
- **One SCO link (new):** a SCO connection is counted from the start of its setup. Any other
  connection added or removed in that window makes btusb pick alt 0. When the link comes up the
  count is unchanged, so its own notification is ignored, and the link would run on alt 0.

**Evidence:**
- Two races of the single-link kind in the journal (2026-09-02, stock era; the links never came
  up). In 281 pending setups over 68 boots, no link ever ran on alt 0.
- A model test replays the real code: alt 0 in 5 of 7 scenarios.
- Full record in [`../research-2026-11-01/`](../research-2026-11-01/README.md) and its
  `btusb/` folder (`scripts/notify-model/`, `out/notify-model-*.txt`).

**Candidate fix:** [`candidate-2026-11-01/`](candidate-2026-11-01/), as diffs for Ubuntu
`7.0.0-42` and for bluetooth-next.
- What it changes: btusb ignores events that are not about SCO; a link-up always applies its
  air mode; a link-down keeps the mode while other links remain; streaming starts only once a
  link is up.
- Results: it compiles cleanly (W=1) on both; all 7 model scenarios give the right alt.
- Limit: with mixed air modes it keeps the last link-up's mode. A complete fix would need the
  core to remember each link's mode, which is a design question for the maintainers.

**Related upstream:** Hitalo Souza's patch 6/6, patchwork 14875454 (2026-10-08, pending), fixes
one of the 7 scenarios. Ours complements it.

**Next:**
1. An outside review.
2. The list bot's CI locally, on base and on base plus the patch.
3. Optionally, a laptop run (the operator's word): two headsets in handsfree, hang up one.

Sending is the operator's decision.
