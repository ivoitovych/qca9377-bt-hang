# CO-08 log

Append-only. Newest last.

## 2026-08-17 — first contact
`EX-030`, an A2DP dropout on the same speaker: bluetoothd configured the `sbc_xq` endpoint.

## 2026-10-11 — observed
Around 00:35 the operator reported SBC-XQ silent and SBC audible. The captures from 00:17
to 00:57 show both configurations accepted, and signal sent on SBC-XQ only during the test
sounds (858 Dual Channel frames). An outside reviewer proposed a decoder limit.

## 2026-10-20 — upstream checked
- **PipeWire master's `bluez-hardware.conf`:** no Tronsmart or T8 entry.
- **Issues:** the only Tronsmart issue (#1935, 2021) is a USB headset.

## 2026-10-21 — reviewer 1
Suggested comparing the exact accepted configuration with a joint-stereo control of similar
bitrate, the same idea as our next step 2. Nothing new on the code.

## 2026-10-21 — dossier opened

## 2026-10-21 — reviewers 2, 3 and 4: a better test
- **Reviewer 4's equal-bitrate pairs,** at 48 kHz, 16 blocks, 8 subbands (arithmetic checked
  by the SBC frame-length formula):

  | configuration | frame | bitrate |
  |---|---|---|
  | Dual Channel, bitpool 26 | 116 bytes | 348 kb/s |
  | Stereo, bitpool 52 | 116 bytes | 348 kb/s |
  | Joint Stereo, bitpool 51 | 115 bytes | 345 kb/s |
  | Dual Channel, bitpool 39 | 168 bytes | 504 kb/s |

- **The test:** Dual 26 against Stereo 52 separates channel mode at equal bitrate; Dual 26
  against Dual 39 separates bitrate. Do not ask for a joint-stereo 504 kb/s stream: it would
  exceed the speaker's advertised bitpool 53.
- **Quirk precedent:** the Motorola entries came with `966fbd5a2176` (issue #1590), per
  reviewer 4.
- **Reviewer 2:** a possible inverted bitpool range in `codec_select_config()`, a separate
  unit-test candidate. Not checked.
- **Full record:** `reviews/2026-10-21T0033Z-source-investigation-reviewers-2-4.md`, RV8.
