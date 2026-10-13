#!/usr/bin/env python3
"""sbc-frame-levels.py: is the A2DP stream in a capture carrying sound or encoded silence?

Usage: sbc-frame-levels.py [--from "YYYY-MM-DD HH:MM:SS"] [--to "..."] [--bucket N] <capture.btsnoop>...

Reads btsnoop files written by btmon (Linux monitor format, datalink 2001). For every
outgoing ACL packet whose L2CAP payload is an RTP packet carrying SBC frames (RTP v2,
then the one-byte A2DP media header, then the 0x9c sync byte), it parses each SBC frame
header and its scale factors. A frame whose scale factors are all zero is encoded
silence. One line per bucket (default 1 s, local time):

  time  config  frames  signal  max_sf  distinct

  config   e.g. 48000/JS/bp53 or 48000/DUAL/bp39 (several, comma-joined, if it changed)
  frames   SBC frames sent in the bucket
  signal   frames with at least one non-zero scale factor
  max_sf   the largest scale factor seen (0..15; 0 = silence)
  distinct how many different frame payloads (1 = the same frame repeated)

Times are taken from the capture records; nothing is decoded to audio and no address
is printed.
"""
import struct
import sys
from datetime import datetime

BTSNOOP_EPOCH_DELTA = 0x00DCDDB30F2F8000  # microseconds from 0 AD to 1970-01-01
OPCODE_ACL_TX = 4  # btmon monitor opcodes: 2 cmd, 3 event, 4 ACL TX, 5 ACL RX
FREQS = [16000, 32000, 44100, 48000]
MODES = ["MONO", "DUAL", "ST", "JS"]


def records(path):
    with open(path, "rb") as f:
        head = f.read(16)
        if head[:8] != b"btsnoop\0":
            raise SystemExit(f"{path}: not a btsnoop file")
        _version, datalink = struct.unpack(">II", head[8:16])
        if datalink != 2001:
            raise SystemExit(f"{path}: datalink {datalink}, expected 2001 (monitor)")
        while True:
            rec = f.read(24)
            if len(rec) < 24:
                return
            _orig, incl, flags, _drops, ts = struct.unpack(">IIIIq", rec)
            data = f.read(incl)
            if len(data) < incl:
                return
            yield flags & 0xFFFF, ts, data


def sbc_frames(payload):
    """Yield (config, scale_factors, frame_bytes) for each SBC frame in an RTP/A2DP payload."""
    if len(payload) < 14 or (payload[0] & 0xC0) != 0x80:
        return
    count = payload[12] & 0x0F
    pos = 13
    for _ in range(count):
        if pos + 4 > len(payload) or payload[pos] != 0x9C:
            return
        b1, bitpool = payload[pos + 1], payload[pos + 2]
        freq = FREQS[(b1 >> 6) & 3]
        blocks = [4, 8, 12, 16][(b1 >> 4) & 3]
        mode = (b1 >> 2) & 3
        subbands = 8 if b1 & 1 else 4
        channels = 1 if mode == 0 else 2
        hdr = 4
        if mode == 3:  # joint stereo: one join bit per subband
            hdr += 1 if subbands == 8 else 0
        bits = 4 * subbands * channels  # scale factors
        if mode == 3 and subbands == 4:
            bits += 4
        sf_start = pos + hdr
        sf_bytes = payload[sf_start:sf_start + (4 * subbands * channels + 7) // 8]
        sfs = []
        for byte in sf_bytes:
            sfs.extend((byte >> 4, byte & 0x0F))
        sfs = sfs[:subbands * channels]
        if mode in (0, 1):
            data_bits = blocks * channels * bitpool
        else:
            data_bits = (subbands if mode == 3 else 0) + blocks * bitpool
        length = 4 + (4 * subbands * channels) // 8 + (data_bits + 7) // 8
        if mode == 3 and subbands == 4:
            length = 4 + (4 + 4 * subbands * channels + data_bits + 7) // 8
        config = f"{freq}/{MODES[mode]}/bp{bitpool}"
        yield config, sfs, bytes(payload[pos:pos + length])
        pos += length


def main(argv):
    start = end = None
    bucket = 1
    files = []
    i = 0
    while i < len(argv):
        if argv[i] == "--from":
            start = datetime.strptime(argv[i + 1], "%Y-%m-%d %H:%M:%S"); i += 2
        elif argv[i] == "--to":
            end = datetime.strptime(argv[i + 1], "%Y-%m-%d %H:%M:%S"); i += 2
        elif argv[i] == "--bucket":
            bucket = int(argv[i + 1]); i += 2
        else:
            files.append(argv[i]); i += 1
    if not files:
        print(__doc__)
        return 2
    rows = {}
    for path in files:
        for opcode, ts, data in records(path):
            if opcode != OPCODE_ACL_TX or len(data) < 8:
                continue
            pb = (data[1] >> 4) & 0x3
            if pb == 1:  # continuation fragment
                continue
            l2len, _cid = struct.unpack("<HH", data[4:8])
            payload = data[8:8 + l2len]
            when = datetime.fromtimestamp((ts - BTSNOOP_EPOCH_DELTA) / 1e6)
            if (start and when < start) or (end and when > end):
                continue
            key = when.replace(microsecond=0)
            key = key.replace(second=key.second - key.second % bucket)
            for config, sfs, frame in sbc_frames(payload):
                row = rows.setdefault(key, {"configs": [], "frames": 0, "signal": 0, "max": 0, "distinct": set()})
                if config not in row["configs"]:
                    row["configs"].append(config)
                row["frames"] += 1
                if any(sfs):
                    row["signal"] += 1
                row["max"] = max(row["max"], max(sfs) if sfs else 0)
                row["distinct"].add(frame)
    if not rows:
        print("no SBC media frames found in the given files and window")
        return 1
    print("time                 config               frames  signal  max_sf  distinct")
    for key in sorted(rows):
        r = rows[key]
        print(f"{key:%Y-%m-%d %H:%M:%S}  {','.join(r['configs']):<20} {r['frames']:6d}  {r['signal']:6d}  {r['max']:6d}  {len(r['distinct']):8d}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
