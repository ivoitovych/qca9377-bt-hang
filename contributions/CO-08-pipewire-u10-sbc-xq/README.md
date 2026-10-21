# CO-08 — U10: PipeWire quirk for the Tronsmart T8

**State:** blocked on the operator's marked test.

**Target:** PipeWire, as one line in `spa/plugins/bluez5/bluez-hardware.conf`, if the speaker
cannot play SBC-XQ.

**Comes from:** `U10`: the T8 is reported silent on SBC-XQ and audible on plain SBC.

## The facts

- **What the speaker advertises:** three SBC endpoints, every channel mode, bitpool 2 to 53.
- **Both configurations are accepted and stream** (Set Configuration, Open and Start
  accepted):
  - plain SBC: 48 kHz joint stereo, bitpool 53, 357 kb/s;
  - SBC-XQ: 48 kHz Dual Channel, bitpool 39, 504 kb/s.
- **Only the Settings test sounds carried signal** (`scripts/sbc-frame-levels.py`). Chrome's
  playback was encoded silence on both, so only the test sounds can decide.
- **The silence itself is the operator's account,** not yet confirmed by a marked test.
- **PipeWire master's quirk list has no Tronsmart entry.** The form, for example:
  `{ name = "SoundCore 2", no-features = [ sbc-xq ] },  # #pipewire-2291`.

## Next

1. **The operator:** the Settings test sound on each mode, with a `bt-mark` after each.
2. If SBC-XQ is silent, separate the channel mode from the bitrate: Dual Channel at a low
   bitpool, and joint stereo at a high one. Reviewer 1 suggested the same with the exact
   accepted parameters.
3. Read how PipeWire's maintainers took earlier quirk entries, and what evidence they asked
   for.
4. Then a merge request with the entry and the evidence.
