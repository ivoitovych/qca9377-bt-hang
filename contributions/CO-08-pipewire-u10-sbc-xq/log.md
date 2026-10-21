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
