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
2. If SBC-XQ is silent, separate the channel mode from the bitrate: Dual 26 against Stereo 52
   (channel mode at equal bitrate) and Dual 26 against Dual 39 (bitrate). Not a joint-stereo
   504 kb/s stream: it would exceed the speaker's advertised bitpool 53 (`log.md`, RV8; this item
   said "joint stereo at a high one" until 2026-10-28).
3. Read how PipeWire's maintainers took earlier quirk entries, and what evidence they asked
   for.
4. Then a merge request with the entry and the evidence.
